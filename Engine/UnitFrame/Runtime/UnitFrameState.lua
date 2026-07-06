local _, FocalPoint = ...

FocalPoint.UnitFrameState = FocalPoint.UnitFrameState or {}
local State = FocalPoint.UnitFrameState
local Presence = FocalPoint.UnitFramePresence or {}

-- Small runtime-state kernel for controlled refresh orchestration.

local function CopyDirtyScopes(dirty)
    local copy = {}
    if type(dirty) ~= "table" then
        return copy
    end

    for key, value in pairs(dirty) do
        copy[key] = value == true
    end

    return copy
end

local function IsRuntimeDebugEnabled()
    return FocalPoint and FocalPoint.debugRuntimeState == true
end

local function ShouldEmitGuardWarnings()
    return (FocalPoint and FocalPoint.debugRuntimeState == true)
        or (FocalPoint and FocalPoint.debugDemoRuntime == true)
        or (FocalPoint and FocalPoint.debugTargetVisibility == true)
end

local function IsPreviewTraceActive()
    if not IsRuntimeDebugEnabled() then
        return false
    end
    local isPreviewModeEnabled = Presence and Presence.IsPreviewModeEnabled
    return isPreviewModeEnabled and isPreviewModeEnabled() or false
end

local function TouchDemoRefreshTrace()
    if not IsPreviewTraceActive() then
        return nil
    end

    FocalPoint._demoRefreshTrace = FocalPoint._demoRefreshTrace or {
        windowStartedAt = 0,
        queued = 0,
        committed = 0,
        reasons = {},
        scopes = {},
    }

    local trace = FocalPoint._demoRefreshTrace
    local now = GetTime and GetTime() or 0
    if trace.windowStartedAt <= 0 then
        trace.windowStartedAt = now
    end
    return trace, now
end

local function FlushDemoRefreshTraceIfNeeded()
    local trace, now = TouchDemoRefreshTrace()
    if not trace then
        return
    end

    if (now - trace.windowStartedAt) < 1.0 then
        return
    end

    if FocalPoint and FocalPoint.Debug then
        local reasonParts = {}
        for key, value in pairs(trace.reasons or {}) do
            reasonParts[#reasonParts + 1] = string.format("%s=%d", tostring(key), tonumber(value) or 0)
        end
        table.sort(reasonParts)

        local scopeParts = {}
        for key, value in pairs(trace.scopes or {}) do
            scopeParts[#scopeParts + 1] = string.format("%s=%d", tostring(key), tonumber(value) or 0)
        end
        table.sort(scopeParts)

        FocalPoint:Debug(string.format(
            "[DemoRefreshTrace] queued=%d committed=%d reasons=[%s] scopes=[%s]",
            tonumber(trace.queued) or 0,
            tonumber(trace.committed) or 0,
            table.concat(reasonParts, ","),
            table.concat(scopeParts, ",")
        ))
    end

    trace.windowStartedAt = now
    trace.queued = 0
    trace.committed = 0
    trace.reasons = {}
    trace.scopes = {}
end

local function RecordDemoRefreshQueue(reason, scope)
    local trace = TouchDemoRefreshTrace()
    if not trace then
        return
    end

    trace.queued = (trace.queued or 0) + 1
    local reasonKey = tostring(reason or "unknown")
    trace.reasons[reasonKey] = (trace.reasons[reasonKey] or 0) + 1

    if type(scope) == "string" then
        local scopeKey = scope ~= "" and scope or "unknown"
        trace.scopes[scopeKey] = (trace.scopes[scopeKey] or 0) + 1
    elseif type(scope) == "table" then
        for _, scopeEntry in ipairs(scope) do
            if type(scopeEntry) == "string" and scopeEntry ~= "" then
                trace.scopes[scopeEntry] = (trace.scopes[scopeEntry] or 0) + 1
            end
        end
    else
        trace.scopes.full = (trace.scopes.full or 0) + 1
    end

    FlushDemoRefreshTraceIfNeeded()
end

local function RecordDemoRefreshCommit()
    local trace = TouchDemoRefreshTrace()
    if not trace then
        return
    end
    trace.committed = (trace.committed or 0) + 1
    FlushDemoRefreshTraceIfNeeded()
end

local function BuildScopeText(scopeTable)
    if type(scopeTable) ~= "table" then
        return "-"
    end

    local ordered = {}
    for key, value in pairs(scopeTable) do
        if value == true then
            ordered[#ordered + 1] = tostring(key)
        end
    end

    table.sort(ordered)
    if #ordered == 0 then
        return "-"
    end

    return table.concat(ordered, ",")
end

local TARGET_COMBAT_SWAP_SCOPES = { "visibility", "bars", "texts", "auras", "castbar" }
local TARGET_COMBAT_SWAP_OPTIONS = { forceAuraFullScan = true }

local function GetFrameDebugLabel(frame)
    if not frame then
        return "frame=?"
    end

    local unit = tostring(frame.unit or "?")
    local name = frame.GetName and frame:GetName()
    if type(name) == "string" and name ~= "" then
        return string.format("%s<%s>", name, unit)
    end

    return string.format("frame<%s>", unit)
end

local function DebugTargetState(frame, label, reason)
    if not (FocalPoint and FocalPoint.debugTargetVisibility == true) then
        return
    end
    if not (frame and frame.unit == "target") then
        return
    end

    local exists = UnitExists and UnitExists("target") or false
    local guid = UnitGUID and UnitGUID("target") or nil
    local name = UnitName and UnitName("target") or nil
    local shown = frame.IsShown and frame:IsShown() or false
    local alpha = frame.GetAlpha and frame:GetAlpha() or 0
    local protected = frame.IsProtected and frame:IsProtected() or false
    local combat = InCombatLockdown and InCombatLockdown() or false

    if FocalPoint.Debug then
        FocalPoint:Debug(string.format(
            "[TargetTrace] %s reason=%s combat=%s protected=%s shown=%s alpha=%.2f exists=%s guid=%s name=%s",
            tostring(label),
            tostring(reason or "-"),
            tostring(combat),
            tostring(protected),
            tostring(shown),
            tonumber(alpha) or 0,
            tostring(exists),
            tostring(guid ~= nil),
            tostring(name ~= nil)
        ))
    end
end

local function MergeDirtyScope(dirty, scope)
    if type(dirty) ~= "table" then
        return
    end

    if type(scope) == "string" and scope ~= "" then
        dirty[scope] = true
        return
    end

    if type(scope) == "table" then
        for _, entry in ipairs(scope) do
            if type(entry) == "string" and entry ~= "" then
                dirty[entry] = true
            end
        end
        return
    end

    dirty.full = true
end

local function WipeTable(target)
    if type(target) ~= "table" then
        return {}
    end

    for key in pairs(target) do
        target[key] = nil
    end

    return target
end

function State.Ensure(frame)
    if not frame then
        return nil
    end

    frame.RuntimeState = frame.RuntimeState or {
        phase = "uninitialized",
        dirty = {},
        pendingCommit = false,
        suspended = false,
        boundUnit = frame.unit,
        commitToken = 0,
        lastCommitToken = 0,
        lastReason = nil,
        lastCommittedScopes = {},
        forceAuraFullScan = false,
        forceFullRefresh = false,
    }

    local runtimeState = frame.RuntimeState
    runtimeState.dirty = runtimeState.dirty or {}
    runtimeState.boundUnit = frame.unit
    runtimeState.lastCommittedScopes = runtimeState.lastCommittedScopes or {}
    return runtimeState
end

function State.DebugLog(frame, action, details)
    if not IsRuntimeDebugEnabled() or not FocalPoint or not FocalPoint.Debug then
        return
    end

    local label = GetFrameDebugLabel(frame)
    local suffix = (type(details) == "string" and details ~= "") and (" " .. details) or ""
    FocalPoint:Debug(string.format("Runtime %s %s%s", label, tostring(action or "?"), suffix))
end

function State.Guard(frame, key, condition, details)
    if condition then
        return true
    end

    local runtimeState = State.Ensure(frame)
    if runtimeState then
        runtimeState.guardFailures = runtimeState.guardFailures or {}
        local count = (runtimeState.guardFailures[key] or 0) + 1
        runtimeState.guardFailures[key] = count
        if count > 3 then
            return false
        end
    end

    if ShouldEmitGuardWarnings() and FocalPoint and FocalPoint.Warn then
        local label = GetFrameDebugLabel(frame)
        local suffix = (type(details) == "string" and details ~= "") and (" " .. details) or ""
        FocalPoint:Warn(string.format("Runtime-Guard %s %s%s", label, tostring(key or "?"), suffix))
    end

    return false
end

function State.SetPhase(frame, phase)
    local runtimeState = State.Ensure(frame)
    if runtimeState and type(phase) == "string" and phase ~= "" then
        runtimeState.phase = phase
    end
end

function State.ResetFrameRuntimeState(frame)
    local runtimeState = State.Ensure(frame)
    if not runtimeState then
        return nil
    end

    runtimeState.dirty = WipeTable(runtimeState.dirty)
    runtimeState.pendingCommit = false
    runtimeState.suspended = false
    runtimeState.lastReason = nil
    runtimeState.lastCommittedScopes = WipeTable(runtimeState.lastCommittedScopes)
    runtimeState.forceAuraFullScan = false
    runtimeState.forceFullRefresh = false
    runtimeState.boundUnit = frame and frame.unit or runtimeState.boundUnit
    runtimeState.phase = "empty_valid"
    runtimeState.guardFailures = WipeTable(runtimeState.guardFailures)
    State.DebugLog(frame, "reset-frame")
    return runtimeState
end

function State.ResetDerivedFrameState(frame)
    if not frame then
        return
    end

    frame.LiveValues = WipeTable(frame.LiveValues)
    -- Legacy compatibility path: frame.TestValues is still cleared here until
    -- remaining consumers are migrated to runtime/demo snapshot values.
    frame.TestValues = nil
    local TextState = FocalPoint.TextElementState or {}
    if TextState.Reset then
        TextState.Reset(frame)
    end
    State.DebugLog(frame, "reset-derived")
end

function State.ResetAuraRuntimeState(frame)
    local AuraRuntime = FocalPoint.AuraRuntime or {}
    if AuraRuntime.Reset then
        AuraRuntime.Reset(frame)
    end
    State.DebugLog(frame, "reset-auras")
end

function State.HandleUnitLost(frame, reason)
    if not frame then
        return
    end

    State.ResetFrameRuntimeState(frame)
    State.ResetDerivedFrameState(frame)
    State.ResetAuraRuntimeState(frame)

    local Visibility = FocalPoint.UnitFrameVisibility or {}
    if Visibility.ClearFrameVisualState then
        if frame.unit == "target" and UnitExists and UnitExists("target") then
            frame._missingUnitSince = nil
            frame._targetRecoveryQueuedUntil = nil
            frame._protectedMissingTargetRecoveryQueued = nil
            State.DebugLog(frame, "unit-lost-skip-existing-target", tostring(reason or "unit_lost"))
            return
        end
        if frame.unit == "targettarget" and UnitExists and UnitExists("targettarget") then
            frame._missingUnitSince = nil
            frame._targetRecoveryQueuedUntil = nil
            frame._protectedMissingTargetRecoveryQueued = nil
            State.DebugLog(frame, "unit-lost-skip-existing-targettarget", tostring(reason or "unit_lost"))
            return
        end
        if frame.unit == "focustarget" and UnitExists and UnitExists("focustarget") then
            frame._missingUnitSince = nil
            frame._targetRecoveryQueuedUntil = nil
            frame._protectedMissingTargetRecoveryQueued = nil
            State.DebugLog(frame, "unit-lost-skip-existing-focustarget", tostring(reason or "unit_lost"))
            return
        end
        Visibility.ClearFrameVisualState(frame)
    end

    local runtimeState = State.Ensure(frame)
    if runtimeState then
        runtimeState.lastReason = reason or "unit_lost"
        runtimeState.phase = "empty_valid"
    end

    State.DebugLog(frame, "unit-lost", tostring(reason or "unit_lost"))
end

function State.HandleTargetSwap(frame, reason)
    if not frame then
        return
    end

    DebugTargetState(frame, "target_swap_start", reason)
    local runtimeState = State.Ensure(frame)
    if runtimeState then
        runtimeState.phase = "stale"
        runtimeState.lastReason = reason or "target_swap"
    end

    State.ResetDerivedFrameState(frame)
    DebugTargetState(frame, "after_reset_derived", reason)
    State.ResetAuraRuntimeState(frame)
    DebugTargetState(frame, "after_reset_auras", reason)

    local Visibility = FocalPoint.UnitFrameVisibility or {}
    if Visibility.ClearFrameVisualState then
        DebugTargetState(frame, "before_clear_visual_state", reason)
        if frame.unit == "target" and InCombatLockdown and InCombatLockdown() then
            if runtimeState then
                runtimeState.phase = "stale"
                runtimeState.lastReason = reason or "target_swap"
            end
            if State.QueueRefresh then
                State.QueueRefresh(frame, "target_swap_combat_resync", TARGET_COMBAT_SWAP_SCOPES, TARGET_COMBAT_SWAP_OPTIONS, 0)
                State.QueueRefresh(frame, "target_swap_combat_resync_delayed", TARGET_COMBAT_SWAP_SCOPES, TARGET_COMBAT_SWAP_OPTIONS, 0.10)
            end
            DebugTargetState(frame, "skip_clear_in_combat", reason)
            return
        end
        if frame.unit == "target" and UnitExists and UnitExists("target") then
            frame._missingUnitSince = nil
            frame._targetRecoveryQueuedUntil = nil
            frame._protectedMissingTargetRecoveryQueued = nil
            DebugTargetState(frame, "skip_clear_existing_target", reason)
            State.DebugLog(frame, "target-swap", tostring(reason or "target_swap"))
            return
        end
        if frame.unit == "targettarget" and UnitExists and UnitExists("targettarget") then
            frame._missingUnitSince = nil
            frame._targetRecoveryQueuedUntil = nil
            frame._protectedMissingTargetRecoveryQueued = nil
            DebugTargetState(frame, "skip_clear_existing_targettarget", reason)
            State.DebugLog(frame, "target-swap", tostring(reason or "target_swap"))
            return
        end
        if frame.unit == "focustarget" and UnitExists and UnitExists("focustarget") then
            frame._missingUnitSince = nil
            frame._targetRecoveryQueuedUntil = nil
            frame._protectedMissingTargetRecoveryQueued = nil
            DebugTargetState(frame, "skip_clear_existing_focustarget", reason)
            State.DebugLog(frame, "target-swap", tostring(reason or "target_swap"))
            return
        end
        Visibility.ClearFrameVisualState(frame)
        DebugTargetState(frame, "after_clear_visual_state", reason)
    end

    State.DebugLog(frame, "target-swap", tostring(reason or "target_swap"))
end

function State.HandleUnitRebound(frame, reason, options)
    local runtimeState = State.Ensure(frame)
    if not runtimeState then
        return
    end

    runtimeState.boundUnit = frame.unit
    runtimeState.lastReason = reason or "unit_rebound"
    runtimeState.phase = "bound"
    State.DebugLog(frame, "unit-rebound", tostring(runtimeState.lastReason))

    if type(options) == "table" and options.queueRefresh then
        State.QueueRefresh(frame, runtimeState.lastReason, options.scope or "full", {
            forceAuraFullScan = options.forceAuraFullScan == true,
            forceFullRefresh = options.forceFullRefresh == true,
        })
    end
end

function State.MarkDirty(frame, reason, scope, options)
    local runtimeState = State.Ensure(frame)
    if not runtimeState then
        return nil
    end

    MergeDirtyScope(runtimeState.dirty, scope)
    runtimeState.lastReason = reason or runtimeState.lastReason

    if type(options) == "table" then
        if options.forceAuraFullScan then
            runtimeState.forceAuraFullScan = true
        end
        if options.forceFullRefresh then
            runtimeState.forceFullRefresh = true
        end
    end

    if runtimeState.phase == "uninitialized" then
        runtimeState.phase = "dirty"
    elseif runtimeState.phase ~= "suspended" then
        runtimeState.phase = "pending_refresh"
    end

    State.DebugLog(frame, "dirty", string.format("reason=%s scopes=%s", tostring(runtimeState.lastReason or "-"), BuildScopeText(runtimeState.dirty)))

    return runtimeState
end

local function ConsumeRequest(frame, runtimeState)
    runtimeState.commitToken = (runtimeState.commitToken or 0) + 1

    local request = {
        reason = runtimeState.lastReason,
        scopes = CopyDirtyScopes(runtimeState.dirty),
        forceAuraFullScan = runtimeState.forceAuraFullScan == true,
        forceFullRefresh = runtimeState.forceFullRefresh == true,
        commitToken = runtimeState.commitToken,
    }

    runtimeState.pendingCommit = false
    runtimeState.dirty = {}
    runtimeState.forceAuraFullScan = false
    runtimeState.forceFullRefresh = false
    runtimeState.phase = runtimeState.suspended and "suspended" or "committing"

    return request
end

function State.QueueRefresh(frame, reason, scope, options, delay)
    RecordDemoRefreshQueue(reason, scope)
    delay = tonumber(delay) or 0

    if delay > 0 and C_Timer and C_Timer.After then
        C_Timer.After(delay, function()
            if frame then
                State.QueueRefresh(frame, reason, scope, options, 0)
            end
        end)
        return true
    end

    local runtimeState = State.MarkDirty(frame, reason, scope, options)
    if not runtimeState then
        return false
    end

    if runtimeState.pendingCommit then
        return true
    end

    runtimeState.pendingCommit = true

    if not (C_Timer and C_Timer.After) then
        State.Commit(frame)
        return true
    end

    C_Timer.After(delay, function()
        if frame then
            State.Commit(frame)
        end
    end)

    return true
end

function State.Commit(frame)
    local runtimeState = State.Ensure(frame)
    if not runtimeState then
        return false
    end

    if runtimeState.suspended then
        runtimeState.pendingCommit = false
        runtimeState.phase = "suspended"
        State.DebugLog(frame, "commit-skipped", "reason=suspended")
        return false
    end

    if not next(runtimeState.dirty)
        and runtimeState.forceAuraFullScan ~= true
        and runtimeState.forceFullRefresh ~= true
    then
        runtimeState.pendingCommit = false
        if runtimeState.phase ~= "empty_valid" then
            runtimeState.phase = "bound"
        end
        State.DebugLog(frame, "commit-skipped", "reason=clean")
        return false
    end

    local request = ConsumeRequest(frame, runtimeState)
    State.DebugLog(frame, "commit-start", string.format("reason=%s scopes=%s token=%s", tostring(request.reason or "-"), BuildScopeText(request.scopes), tostring(request.commitToken or "?")))
    local owner = FocalPoint.UnitFrame
    if owner and owner.Refresh then
        RecordDemoRefreshCommit()
        owner:Refresh(frame, request)
    end

    runtimeState.lastCommitToken = request.commitToken
    runtimeState.lastCommittedScopes = request.scopes
    if runtimeState.phase == "committing" then
        runtimeState.phase = "bound"
    end
    State.DebugLog(frame, "commit-applied", string.format("token=%s phase=%s", tostring(request.commitToken or "?"), tostring(runtimeState.phase or "?")))

    return true
end
