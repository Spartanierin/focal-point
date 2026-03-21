local _, FocalPoint = ...

FocalPoint.UnitFrameState = FocalPoint.UnitFrameState or {}
local State = FocalPoint.UnitFrameState

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

    if FocalPoint and FocalPoint.Warn then
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

    local runtimeState = State.Ensure(frame)
    if runtimeState then
        runtimeState.phase = "stale"
        runtimeState.lastReason = reason or "target_swap"
    end

    State.ResetDerivedFrameState(frame)
    State.ResetAuraRuntimeState(frame)

    local Visibility = FocalPoint.UnitFrameVisibility or {}
    if Visibility.ClearFrameVisualState then
        Visibility.ClearFrameVisualState(frame)
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
