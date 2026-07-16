local _, FocalPoint = ...

FocalPoint.UnitFrameVisibility = FocalPoint.UnitFrameVisibility or {}
local Visibility = FocalPoint.UnitFrameVisibility

local Cast = FocalPoint.UnitFrameCastBar or {}
local Demo = FocalPoint.UnitFrameDemoEnvironment or {}
local Presence = FocalPoint.UnitFramePresence or {}
local State = FocalPoint.UnitFrameState or {}

local DoesUnitSeemPresent = Presence.DoesUnitSeemPresent
local GetTargetPresenceSnapshot = Presence.GetTargetPresenceSnapshot
local MaybeDebugTarget = Presence.MaybeDebugTarget
local ForceDebugTarget = Presence.ForceDebugTarget
local IsPreviewModeEnabled = Presence.IsPreviewModeEnabled
local ShouldForceFrameVisible = Presence.ShouldForceFrameVisible
local IsBossRuntimeUnit
local ShouldTreatMissingTargetAsSuspicious

local function IsProtectedFrameInCombat(frame)
    return frame
        and frame.IsProtected
        and frame:IsProtected()
        and InCombatLockdown
        and InCombatLockdown()
end

local function HideFrameIfSafe(frame)
    if not (frame and frame.Hide) then
        return false
    end
    if frame.unit == "target" then
        return false
    end
    if IsProtectedFrameInCombat(frame) then
        return false
    end
    frame:Hide()
    return true
end

local function IsMissingDebugSuppressed(frame)
    local now = GetTime and GetTime() or 0
    if frame and frame._suppressMissingUnitDebugUntil and now <= frame._suppressMissingUnitDebugUntil then
        return true
    end
    return FocalPoint and FocalPoint._suppressMissingUnitUntil and now <= FocalPoint._suppressMissingUnitUntil
end

local function ShouldSuppressFramesForSpecialMode()
    local inPetBattle = C_PetBattles
        and C_PetBattles.IsInBattle
        and C_PetBattles.IsInBattle()
    if inPetBattle then
        return true, "pet_battle"
    end

    local hasOverrideActionBar = C_ActionBar
        and C_ActionBar.HasOverrideActionBar
        and C_ActionBar.HasOverrideActionBar()
    if hasOverrideActionBar then
        return true, "override_action_bar"
    end

    local hasVehicleActionBar = C_ActionBar
        and C_ActionBar.HasVehicleActionBar
        and C_ActionBar.HasVehicleActionBar()
    if hasVehicleActionBar then
        return true, "vehicle_action_bar"
    end

    local hasVehicleUi = UnitHasVehicleUI and UnitHasVehicleUI("player")
    if hasVehicleUi then
        return true, "vehicle_ui"
    end

    return false, nil
end

local function ResolveEditorSelectedUnit()
    local editorState = FocalPoint
        and FocalPoint.GUI
        and FocalPoint.GUI.Editor
        and FocalPoint.GUI.Editor.State
    local state = editorState and editorState.Get and editorState.Get()
    local selectedUnit = state and state.selectedUnit
    if type(selectedUnit) == "string" and selectedUnit ~= "" then
        return selectedUnit
    end
    return nil
end

local function IsSelectedEditorFrame(frame)
    if not frame or type(frame.unit) ~= "string" then
        return false
    end

    local selectedUnit = ResolveEditorSelectedUnit()
    if not selectedUnit then
        return false
    end

    if selectedUnit == "boss" then
        return frame.unit:match("^boss%d+$") ~= nil
    end

    return frame.unit == selectedUnit
end

local function ResolveModeReadOnly(frame)
    if not frame or not frame.unit then
        return "live", "live-invalid-frame"
    end

    if FocalPoint and FocalPoint.guiTestModeEnabled == true then
        if Demo.IsFrameUnitEnabled and not Demo.IsFrameUnitEnabled(frame) then
            return "disabled", "demo-disabled-unit"
        end
        return "detailed", "global-demo-detailed"
    end

    if FocalPoint and FocalPoint.framesUnlocked == true then
        if Demo.IsFrameUnitEnabled and not Demo.IsFrameUnitEnabled(frame) then
            return "placeholder", "unlock-disabled-placeholder"
        end
        if IsSelectedEditorFrame(frame) then
            return "detailed", "unlock-selected-detailed"
        end
        return "placeholder", "unlock-placeholder"
    end

    return "live", "live-no-demo"
end

function Visibility.ResolveRootDecision(frame, reason, options)
    options = type(options) == "table" and options or {}

    local unit = frame and frame.unit or nil
    local protectedRoot = frame
        and frame.IsProtected
        and frame:IsProtected()
        or false
    local inCombat = InCombatLockdown and InCombatLockdown() or false
    local canHideRoot = frame ~= nil
        and frame.Hide ~= nil
        and not (protectedRoot and inCombat)
    local previewEnabled = FocalPoint
        and (FocalPoint.guiTestModeEnabled == true or FocalPoint.framesUnlocked == true)
        or false
    local previewOutsideCombat = previewEnabled and not inCombat
    local canShowRoot = frame ~= nil
        and frame.Show ~= nil
        and (not protectedRoot or previewOutsideCombat or not inCombat)

    local decision = {
        visible = false,
        reason = "invalid-frame",
        inputReason = reason,

        unit = unit,
        unitPresent = false,

        mode = "live",
        modeReason = "invalid-frame",
        previewEnabled = previewEnabled,
        forceVisible = false,
        specialModeActive = false,
        specialModeReason = nil,

        protectedRoot = protectedRoot,
        inCombat = inCombat,
        canShowRoot = canShowRoot,
        canHideRoot = canHideRoot,
        hideSuppressedByPolicy = unit == "target",

        shouldShowRoot = false,
        shouldHideRoot = false,
        shouldSoftClear = false,
        shouldHardClear = false,
        shouldAlphaZero = false,
        shouldDisableMouse = false,
        shouldQueueRecovery = false,
        shouldNotifyUnitLost = false,
    }

    if not frame or type(unit) ~= "string" or unit == "" then
        decision.shouldDisableMouse = frame ~= nil
        return decision
    end

    local mode, modeReason = options.mode, options.modeReason
    if type(mode) ~= "string" or mode == "" then
        mode, modeReason = ResolveModeReadOnly(frame)
    end
    decision.mode = mode
    decision.modeReason = modeReason

    local unitPresent
    if type(options.unitPresent) == "boolean" then
        unitPresent = options.unitPresent
    elseif unit == "player" then
        unitPresent = true
    elseif DoesUnitSeemPresent then
        unitPresent = DoesUnitSeemPresent(unit) == true
    else
        unitPresent = UnitExists and UnitExists(unit) and true or false
    end
    decision.unitPresent = unitPresent

    local specialModeActive, specialModeReason
    if type(options.specialModeActive) == "boolean" then
        specialModeActive = options.specialModeActive
        specialModeReason = options.specialModeReason
    else
        specialModeActive, specialModeReason = ShouldSuppressFramesForSpecialMode()
    end
    decision.specialModeActive = specialModeActive == true
    decision.specialModeReason = specialModeReason

    if mode == "disabled" then
        decision.reason = "preview-disabled"
        decision.shouldSoftClear = true
        decision.shouldAlphaZero = true
        decision.shouldDisableMouse = true
        decision.shouldHideRoot = canHideRoot and not decision.hideSuppressedByPolicy
        return decision
    end

    if mode == "live" and Demo.IsFrameUnitEnabled and not Demo.IsFrameUnitEnabled(frame) then
        decision.reason = "unit-disabled"
        decision.shouldAlphaZero = true
        decision.shouldDisableMouse = true
        return decision
    end

    if decision.specialModeActive then
        decision.reason = "special-mode"
        decision.shouldHardClear = true
        decision.shouldAlphaZero = true
        decision.shouldHideRoot = canHideRoot and not decision.hideSuppressedByPolicy
        decision.shouldNotifyUnitLost = true
        return decision
    end

    if ShouldForceFrameVisible and ShouldForceFrameVisible(frame) then
        decision.visible = true
        decision.forceVisible = true
        decision.reason = "forced-visible"
        decision.shouldShowRoot = true
        return decision
    end

    if mode == "detailed" or mode == "placeholder" then
        decision.visible = true
        decision.forceVisible = true
        decision.reason = mode == "placeholder" and "unlock-placeholder" or "demo-detailed"
        decision.shouldShowRoot = true
        return decision
    end

    if Demo.ShouldProcessFrame and not Demo.ShouldProcessFrame(frame) then
        decision.reason = "demo-filtered"
        decision.shouldAlphaZero = true
        decision.shouldDisableMouse = true
        return decision
    end

    if unitPresent then
        decision.visible = true
        decision.reason = "live-present"
        decision.shouldShowRoot = true
        return decision
    end

    local protectedCombat = protectedRoot and inCombat
    local suppressed = IsMissingDebugSuppressed(frame)

    decision.shouldAlphaZero = unit == "target"
    decision.shouldDisableMouse = not protectedCombat
    decision.shouldHideRoot = canHideRoot and not decision.hideSuppressedByPolicy
    decision.shouldNotifyUnitLost = true

    if protectedRoot then
        decision.reason = suppressed and "missing-unit-protected-suppressed" or "missing-unit-protected"
        decision.shouldSoftClear = protectedCombat or IsBossRuntimeUnit(unit)
        decision.shouldHardClear = not decision.shouldSoftClear
        decision.shouldAlphaZero = decision.shouldAlphaZero or suppressed
        decision.shouldQueueRecovery = ShouldTreatMissingTargetAsSuspicious
            and ShouldTreatMissingTargetAsSuspicious(frame)
            or false
        return decision
    end

    if unit == "target" then
        local now = GetTime and GetTime() or 0
        local missingSince = frame and frame._missingUnitSince or nil
        local elapsedMissing = now - (missingSince or now)
        if elapsedMissing < 0.35 then
            decision.reason = "target-missing-transition"
            decision.shouldSoftClear = true
            decision.shouldQueueRecovery = true
            return decision
        end
    end

    decision.reason = suppressed and "missing-unit-suppressed" or "missing-unit"
    decision.shouldSoftClear = IsBossRuntimeUnit(unit)
    decision.shouldHardClear = not decision.shouldSoftClear
    decision.shouldAlphaZero = true
    return decision
end

local MAX_DECISION_DEBUG_MISMATCHES = 20

IsBossRuntimeUnit = function(unit)
    return type(unit) == "string" and unit:match("^boss%d+$") ~= nil
end

local function WouldHideRoot(frame)
    if not (frame and frame.Hide) then
        return false
    end
    if frame.unit == "target" then
        return false
    end
    if IsProtectedFrameInCombat(frame) then
        return false
    end
    return true
end

local function ResolveLegacyMissingUnitOutcome(frame)
    local unit = frame and frame.unit or nil
    local protectedRoot = frame
        and frame.IsProtected
        and frame:IsProtected()
        or false
    local inCombat = InCombatLockdown and InCombatLockdown() or false
    local previewEnabled = IsPreviewModeEnabled and IsPreviewModeEnabled() or false
    local unitPresent = unit == "player"
        or (DoesUnitSeemPresent and DoesUnitSeemPresent(unit) == true)
        or false

    local outcome = {
        handled = false,
        outcome = "not-handled",
        unit = unit,
        unitPresent = unitPresent,
        specialMode = false,
        specialModeReason = nil,
        previewEnabled = previewEnabled,
        forceVisible = false,
        protectedRoot = protectedRoot,
        inCombat = inCombat,
        wouldSoftClear = false,
        wouldHardClear = false,
        wouldAlphaZero = false,
        wouldDisableMouse = false,
        wouldHideRoot = false,
        wouldQueueRecovery = false,
        wouldNotifyUnitLost = false,
    }

    local suppressForSpecialMode, specialModeReason = ShouldSuppressFramesForSpecialMode()
    if suppressForSpecialMode then
        outcome.handled = true
        outcome.outcome = "special-mode"
        outcome.specialMode = true
        outcome.specialModeReason = specialModeReason or "special_mode"
        outcome.wouldHardClear = true
        outcome.wouldAlphaZero = true
        outcome.wouldHideRoot = WouldHideRoot(frame)
        outcome.wouldNotifyUnitLost = true
        return outcome
    end

    if previewEnabled
        and Demo.IsFrameUnitEnabled
        and not Demo.IsFrameUnitEnabled(frame)
        and not (FocalPoint and FocalPoint.framesUnlocked == true and FocalPoint.guiTestModeEnabled ~= true)
    then
        outcome.handled = true
        outcome.outcome = "preview-disabled"
        outcome.wouldSoftClear = true
        outcome.wouldAlphaZero = true
        outcome.wouldDisableMouse = true
        outcome.wouldHideRoot = WouldHideRoot(frame)
        return outcome
    end

    if ShouldForceFrameVisible and ShouldForceFrameVisible(frame) then
        outcome.outcome = "force-visible"
        outcome.forceVisible = true
        return outcome
    end

    if previewEnabled then
        outcome.outcome = "preview"
        return outcome
    end

    local shouldHideForMissingUnit = unit ~= "player" and not unitPresent
    if not shouldHideForMissingUnit then
        outcome.outcome = "present"
        return outcome
    end

    outcome.handled = true
    outcome.outcome = "missing-unit"
    outcome.wouldAlphaZero = unit == "target"
    outcome.wouldDisableMouse = not (protectedRoot and inCombat)
    outcome.wouldHideRoot = WouldHideRoot(frame)

    if protectedRoot then
        outcome.outcome = IsMissingDebugSuppressed(frame)
            and "missing-unit-protected-suppressed"
            or "missing-unit-protected"
        outcome.wouldNotifyUnitLost = true
        outcome.wouldAlphaZero = outcome.wouldAlphaZero or IsMissingDebugSuppressed(frame)
        outcome.wouldSoftClear = (protectedRoot and inCombat) or IsBossRuntimeUnit(unit)
        outcome.wouldHardClear = not outcome.wouldSoftClear
        outcome.wouldQueueRecovery = ShouldTreatMissingTargetAsSuspicious
            and ShouldTreatMissingTargetAsSuspicious(frame)
            or false
        return outcome
    end

    if unit == "target" then
        local now = GetTime and GetTime() or 0
        local missingSince = frame and frame._missingUnitSince or nil
        local elapsedMissing = now - (missingSince or now)
        if elapsedMissing < 0.35 then
            outcome.outcome = "target-missing-transition"
            outcome.wouldSoftClear = true
            outcome.wouldHardClear = false
            outcome.wouldNotifyUnitLost = true
            outcome.wouldQueueRecovery = true
            return outcome
        end
    end

    if IsMissingDebugSuppressed(frame) then
        outcome.outcome = "missing-unit-suppressed"
    end

    outcome.wouldNotifyUnitLost = true
    outcome.wouldAlphaZero = true
    outcome.wouldSoftClear = IsBossRuntimeUnit(unit)
    outcome.wouldHardClear = not outcome.wouldSoftClear
    return outcome
end

local function EnsureDecisionDebugState()
    FocalPoint.VisibilityDecisionDebug = FocalPoint.VisibilityDecisionDebug or {
        enabled = false,
        totalComparisons = 0,
        totalMismatches = 0,
        mismatchesByUnit = {},
        mismatchesByReason = {},
        mismatchesByField = {},
        matchesByUnit = {},
        recentMismatches = {},
        lastMismatch = nil,
    }
    return FocalPoint.VisibilityDecisionDebug
end

local function WipeDecisionDebugMap(map)
    if type(map) ~= "table" then
        return {}
    end
    for key in pairs(map) do
        map[key] = nil
    end
    return map
end

function Visibility.ResetDecisionDebug()
    local state = EnsureDecisionDebugState()
    state.totalComparisons = 0
    state.totalMismatches = 0
    state.mismatchesByUnit = WipeDecisionDebugMap(state.mismatchesByUnit)
    state.mismatchesByReason = WipeDecisionDebugMap(state.mismatchesByReason)
    state.mismatchesByField = WipeDecisionDebugMap(state.mismatchesByField)
    state.matchesByUnit = WipeDecisionDebugMap(state.matchesByUnit)
    state.recentMismatches = WipeDecisionDebugMap(state.recentMismatches)
    state.lastMismatch = nil
    return state
end

function Visibility.SetDecisionDebugEnabled(enabled)
    local state = EnsureDecisionDebugState()
    state.enabled = enabled == true
    return state.enabled
end

function Visibility.IsDecisionDebugEnabled()
    local state = FocalPoint and FocalPoint.VisibilityDecisionDebug
    return state and state.enabled == true or false
end

local function BumpCounter(map, key)
    key = tostring(key or "unknown")
    map[key] = (tonumber(map[key]) or 0) + 1
end

local function BuildMismatch(field, legacyValue, decisionValue)
    if legacyValue == decisionValue then
        return nil
    end
    return {
        field = field,
        legacyValue = legacyValue,
        decisionValue = decisionValue,
    }
end

local function CompareLegacyToDecision(legacy, decision)
    local mismatches = {}
    local ignoredAliasFields = {}
    local function Add(field, legacyValue, decisionValue)
        local mismatch = BuildMismatch(field, legacyValue, decisionValue)
        if mismatch then
            mismatches[#mismatches + 1] = mismatch
        end
    end
    local function Ignore(field, legacyValue, decisionValue)
        if legacyValue ~= decisionValue then
            ignoredAliasFields[#ignoredAliasFields + 1] = {
                field = field,
                legacyValue = legacyValue,
                decisionValue = decisionValue,
            }
        end
    end

    local legacyMissing = legacy.outcome == "missing-unit"
        or legacy.outcome == "missing-unit-suppressed"
        or legacy.outcome == "missing-unit-protected"
        or legacy.outcome == "missing-unit-protected-suppressed"
        or legacy.outcome == "target-missing-transition"
    local decisionMissing = decision.reason == "missing-unit"
        or decision.reason == "missing-unit-suppressed"
        or decision.reason == "missing-unit-protected"
        or decision.reason == "missing-unit-protected-suppressed"
        or decision.reason == "target-missing-transition"

    Add("missing", legacyMissing, decisionMissing)
    Add("forceVisible", legacy.forceVisible == true, decision.forceVisible == true)
    Add("specialMode", legacy.specialMode == true, decision.reason == "special-mode")
    Add("previewDisabled", legacy.outcome == "preview-disabled", decision.reason == "preview-disabled")
    Add("shouldSoftClear", legacy.wouldSoftClear == true, decision.shouldSoftClear == true)
    Add("shouldHardClear", legacy.wouldHardClear == true, decision.shouldHardClear == true)
    Add("shouldAlphaZero", legacy.wouldAlphaZero == true, decision.shouldAlphaZero == true)
    Add("shouldDisableMouse", legacy.wouldDisableMouse == true, decision.shouldDisableMouse == true)
    Add("shouldHideRoot", legacy.wouldHideRoot == true, decision.shouldHideRoot == true)
    Add("shouldQueueRecovery", legacy.wouldQueueRecovery == true, decision.shouldQueueRecovery == true)
    Add("shouldNotifyUnitLost", legacy.wouldNotifyUnitLost == true, decision.shouldNotifyUnitLost == true)

    Ignore("reason", legacy.outcome, decision.reason)

    return mismatches, ignoredAliasFields
end

local function RecordDecisionDebugComparison(frame, decision)
    if not Visibility.IsDecisionDebugEnabled() then
        return
    end
    if not decision then
        return
    end

    local state = EnsureDecisionDebugState()
    local legacy = ResolveLegacyMissingUnitOutcome(frame)
    local mismatches, ignoredAliasFields = CompareLegacyToDecision(legacy, decision)
    local unit = tostring(legacy.unit or decision.unit or "unknown")

    state.totalComparisons = (tonumber(state.totalComparisons) or 0) + 1

    if #mismatches == 0 then
        BumpCounter(state.matchesByUnit, unit)
        return
    end

    state.totalMismatches = (tonumber(state.totalMismatches) or 0) + 1
    BumpCounter(state.mismatchesByUnit, unit)
    BumpCounter(state.mismatchesByReason, tostring(legacy.outcome or "?") .. "->" .. tostring(decision.reason or "?"))

    for _, mismatch in ipairs(mismatches) do
        BumpCounter(state.mismatchesByField, mismatch.field)
    end

    local entry = {
        unit = unit,
        legacyOutcome = legacy.outcome,
        decisionReason = decision.reason,
        combat = legacy.inCombat == true,
        protected = legacy.protectedRoot == true,
        mode = decision.mode,
        modeReason = decision.modeReason,
        mismatches = mismatches,
        ignoredAliasFields = ignoredAliasFields,
    }

    state.lastMismatch = entry
    local recent = state.recentMismatches
    recent[#recent + 1] = entry
    while #recent > MAX_DECISION_DEBUG_MISMATCHES do
        table.remove(recent, 1)
    end
end

local function AppendSortedCounters(lines, title, map)
    lines[#lines + 1] = title
    local entries = {}
    for key, value in pairs(map or {}) do
        entries[#entries + 1] = { key = tostring(key), value = tonumber(value) or 0 }
    end
    table.sort(entries, function(a, b)
        if a.value == b.value then
            return a.key < b.key
        end
        return a.value > b.value
    end)
    if #entries == 0 then
        lines[#lines + 1] = "  none"
        return
    end
    for _, entry in ipairs(entries) do
        lines[#lines + 1] = string.format("  %s: %d", entry.key, entry.value)
    end
end

local function FormatMismatchList(entry)
    local parts = {}
    for _, mismatch in ipairs(entry and entry.mismatches or {}) do
        parts[#parts + 1] = string.format(
            "%s=%s/%s",
            tostring(mismatch.field),
            tostring(mismatch.legacyValue),
            tostring(mismatch.decisionValue)
        )
    end
    return table.concat(parts, ",")
end

local function FormatIgnoredAliasList(entry)
    local parts = {}
    for _, field in ipairs(entry and entry.ignoredAliasFields or {}) do
        parts[#parts + 1] = string.format(
            "%s=%s/%s",
            tostring(field.field),
            tostring(field.legacyValue),
            tostring(field.decisionValue)
        )
    end
    if #parts == 0 then
        return "none"
    end
    return table.concat(parts, ",")
end

function Visibility.GetDecisionDebugStatus()
    local state = EnsureDecisionDebugState()
    return {
        enabled = state.enabled == true,
        totalComparisons = tonumber(state.totalComparisons) or 0,
        totalMismatches = tonumber(state.totalMismatches) or 0,
        recentCount = #(state.recentMismatches or {}),
    }
end

function Visibility.BuildDecisionDebugReport()
    local state = EnsureDecisionDebugState()
    local totalComparisons = tonumber(state.totalComparisons) or 0
    local totalMismatches = tonumber(state.totalMismatches) or 0
    local mismatchRate = totalComparisons > 0
        and ((totalMismatches / totalComparisons) * 100)
        or 0
    local lines = {
        "Visibility shadow report",
        string.format("Enabled: %s", tostring(state.enabled == true)),
        string.format("Comparisons: %d", totalComparisons),
        string.format("Mismatches: %d", totalMismatches),
        string.format("Mismatch rate: %.2f%%", mismatchRate),
        "",
    }

    AppendSortedCounters(lines, "By unit:", state.mismatchesByUnit)
    lines[#lines + 1] = ""
    AppendSortedCounters(lines, "By reason:", state.mismatchesByReason)
    lines[#lines + 1] = ""
    AppendSortedCounters(lines, "By field:", state.mismatchesByField)

    local last = state.lastMismatch
    lines[#lines + 1] = ""
    lines[#lines + 1] = "Last mismatch:"
    if last then
        lines[#lines + 1] = string.format(
            "  unit=%s legacy=%s decision=%s combat=%s protected=%s mode=%s/%s",
            tostring(last.unit),
            tostring(last.legacyOutcome),
            tostring(last.decisionReason),
            tostring(last.combat),
            tostring(last.protected),
            tostring(last.mode),
            tostring(last.modeReason)
        )
        lines[#lines + 1] = "  comparedFields=" .. FormatMismatchList(last)
        lines[#lines + 1] = "  ignoredAliasFields=" .. FormatIgnoredAliasList(last)
    else
        lines[#lines + 1] = "  none"
    end

    return lines
end

local function QueueTargetRecoveryRefreshes(frame, reason)
    if not frame or frame.unit ~= "target" or not State.QueueRefresh then
        return
    end

    local now = GetTime and GetTime() or 0
    local cooldownUntil = tonumber(frame._targetRecoveryQueuedUntil) or 0
    if now <= cooldownUntil then
        return
    end

    frame._targetRecoveryQueuedUntil = now + 0.40
    local refreshReason = reason or "target_recovery"

    for _, delay in ipairs({ 0.10, 0.20, 0.35 }) do
        State.QueueRefresh(frame, refreshReason, "visibility", nil, delay)
    end
end

ShouldTreatMissingTargetAsSuspicious = function(frame)
    if not frame or frame.unit ~= "target" then
        return false
    end

    if IsProtectedFrameInCombat(frame) then
        return true
    end

    local shown = frame.IsShown and frame:IsShown() or false
    local alpha = tonumber(frame.GetAlpha and frame:GetAlpha() or 0) or 0
    local visiblyStuck = shown and alpha > 0.05

    local now = GetTime and GetTime() or 0
    local lastRelevantAt = tonumber(frame._lastTargetEventAt) or 0
    if visiblyStuck and lastRelevantAt > 0 and (now - lastRelevantAt) <= 1.0 then
        return true
    end

    local lastEvent = tostring(frame._lastVisibilityEvent or "")
    return visiblyStuck and (lastEvent == "PLAYER_TARGET_CHANGED" or lastEvent == "PLAYER_REGEN_ENABLED")
end

-- Visibility helpers handle visual cleanup and delayed refresh scheduling.

function Visibility.ClearFrameContentValuesOnly(frame, reason)
    if not frame then
        return
    end

    if frame.LiveValues then
        wipe(frame.LiveValues)
    end
    frame.TestValues = nil

    if frame.Elements then
        local health = frame.Elements.HealthBar
        if health then
            health:SetMinMaxValues(0, 1)
            health:SetValue(0)
            if health.AbsorbOverlay then
                health.AbsorbOverlay:SetMinMaxValues(0, 1)
                health.AbsorbOverlay:SetValue(0)
            end
        end

        local power = frame.Elements.PowerBar
        if power then
            power:SetMinMaxValues(0, 1)
            power:SetValue(0)
        end

        local classPower = frame.Elements.ClassPowerBar
        if classPower then
            for index = 1, #(classPower.Bars or {}) do
                local bar = classPower.Bars[index]
                if bar then
                    bar:SetMinMaxValues(0, 1)
                    bar:SetValue(0)
                end
            end
        end

        local altPower = frame.Elements.AlternativePowerBar
        if altPower then
            altPower:SetMinMaxValues(0, 1)
            altPower:SetValue(0)
        end

        local castBar = frame.Elements.CastBar
        if castBar then
            castBar.isCasting = false
            castBar.isChannel = false
            castBar.isPreview = false
            castBar.interruptState = "UNKNOWN"
            castBar.isInterruptible = false
            castBar.canKick = false
            castBar.startTime = 0
            castBar.endTime = 0
            castBar.castID = nil
            castBar.castToken = nil
            castBar:SetMinMaxValues(0, 1)
            castBar:SetValue(0)
            if Cast.ClearVisuals then
                Cast.ClearVisuals(frame)
            end
        end
    end
end

function Visibility.ClearFrameVisualState(frame, reason)
    if not frame then
        return
    end

    if frame.Texts then
        for _, textObject in pairs(frame.Texts) do
            if textObject and textObject.SetText then
                textObject:SetText("")
            end
            if textObject and textObject.Hide then
                textObject:Hide()
            end
        end
    end

    if frame.Elements then
        local health = frame.Elements.HealthBar
        if health then
            health:SetMinMaxValues(0, 1)
            health:SetValue(0)
            health:Hide()
            if health.bg then
                health.bg:Hide()
            end
        end

        local power = frame.Elements.PowerBar
        if power then
            power:SetMinMaxValues(0, 1)
            power:SetValue(0)
            power:Hide()
            if power.bg then
                power.bg:Hide()
            end
        end

        local classPower = frame.Elements.ClassPowerBar
        if classPower then
            classPower:Hide()
            for index = 1, #(classPower.Bars or {}) do
                local bar = classPower.Bars[index]
                if bar then
                    bar:SetMinMaxValues(0, 1)
                    bar:SetValue(0)
                    bar:Hide()
                    if bar.bg then
                        bar.bg:Hide()
                    end
                end
            end
        end

        local altPower = frame.Elements.AlternativePowerBar
        if altPower then
            altPower:SetMinMaxValues(0, 1)
            altPower:SetValue(0)
            altPower:Hide()
            if altPower.bg then
                altPower.bg:Hide()
            end
        end

        if frame.Elements.CastBar then
            Cast.Stop(frame)
        end

        local portrait = frame.Elements.Portrait
        if portrait then
            portrait:Hide()
            if portrait.Texture then
                portrait.Texture:SetTexture(nil)
            end
        end

        for _, key in ipairs({
            "RaidTargetIcon",
            "LeaderIcon",
            "RoleIcon",
            "CombatIndicator",
            "RestingIndicator",
            "ReadyCheckIndicator",
            "ClassificationPortraitOverlay",
            "ClassificationCrest",
        }) do
            local holder = frame.Elements[key]
            if holder then
                holder:Hide()
                local texture = holder.Texture or holder
                if texture and texture.SetTexture then
                    texture:SetTexture(nil)
                end
            end
        end
    end

    if frame.SetBackdropColor then
        frame:SetBackdropColor(0, 0, 0, 0)
    end
    if frame.SetBackdropBorderColor then
        frame:SetBackdropBorderColor(0, 0, 0, 0)
    end

    frame._rangeCurrentAlpha = 0
    frame._rangeTargetAlpha = 0
    if frame.RangeFadeDriver then
        frame.RangeFadeDriver:Hide()
    end
end

function Visibility.QueueRefresh(frame)
    if not frame then
        return
    end
    if State.QueueRefresh then
        State.QueueRefresh(frame, "visibility", "visibility", nil, 0)
        State.QueueRefresh(frame, "visibility", "visibility", nil, 0.05)
        QueueTargetRecoveryRefreshes(frame, "visibility_recovery")
        return
    end

    if FocalPoint.UnitFrame and FocalPoint.UnitFrame.Refresh then
        FocalPoint.UnitFrame:Refresh(frame)
    end
end

function Visibility.HandleMissingUnit(frame)
    if not frame then
        return false
    end

    local decision = Visibility.ResolveRootDecision(frame, "handle-missing-unit")

    if Visibility.IsDecisionDebugEnabled() then
        RecordDecisionDebugComparison(frame, decision)
    end

    if decision.specialModeActive then
        if State.HandleUnitLost then
            State.HandleUnitLost(frame, decision.specialModeReason or "special_mode")
        else
            Visibility.ClearFrameVisualState(frame, decision.specialModeReason or "special_mode")
        end
        if frame.SetAlpha then
            frame:SetAlpha(0)
        end
        HideFrameIfSafe(frame)
        return true
    end

    if decision.previewEnabled
        and Demo.IsFrameUnitEnabled
        and not Demo.IsFrameUnitEnabled(frame)
        and not (FocalPoint and FocalPoint.framesUnlocked == true and FocalPoint.guiTestModeEnabled ~= true)
    then
        frame._missingUnitSince = nil
        if Visibility.ClearFrameContentValuesOnly then
            Visibility.ClearFrameContentValuesOnly(frame, "preview-disabled-unit")
        end
        if frame.SetAlpha then
            frame:SetAlpha(0)
        end
        if frame.EnableMouse then
            frame:EnableMouse(false)
        end
        if frame.SetMouseClickEnabled then
            frame:SetMouseClickEnabled(false)
        end
        HideFrameIfSafe(frame)
        return true
    end

    if decision.forceVisible then
        frame._missingUnitSince = nil
        return false
    end

    if decision.previewEnabled then
        frame._missingUnitSince = nil
        return false
    end

    local protectedFrame = decision.protectedRoot
    local protectedInCombat = decision.protectedRoot and decision.inCombat
    local shouldHideForMissingUnit = not decision.previewEnabled
        and frame.unit ~= "player"
        and not decision.unitPresent

    if shouldHideForMissingUnit then
        if frame.unit == "target" and frame.SetAlpha then
            frame:SetAlpha(0)
        end
        if not protectedInCombat then
            if frame.EnableMouse then
                frame:EnableMouse(false)
            end
            if frame.SetMouseClickEnabled then
                frame:SetMouseClickEnabled(false)
            end
        end
    end

    if shouldHideForMissingUnit and protectedFrame then
        if IsMissingDebugSuppressed(frame) then
            if State.HandleUnitLost then
                State.HandleUnitLost(frame, "missing_unit_protected_suppressed")
            else
                Visibility.ClearFrameVisualState(frame, "missing_unit_protected_suppressed")
            end
            if frame.SetAlpha then
                frame:SetAlpha(0)
            end
            HideFrameIfSafe(frame)
            return true
        end

        local suspiciousMissingTarget = ShouldTreatMissingTargetAsSuspicious(frame)

        if suspiciousMissingTarget then
            ForceDebugTarget(frame, protectedInCombat
                and "Missing target during combat: clearing content, secure root unchanged"
                or "Missing target: clearing content, secure root unchanged", "missing_target", 2.0)
        end
        if State.HandleUnitLost then
            State.HandleUnitLost(frame, "missing_unit_protected")
        else
            Visibility.ClearFrameVisualState(frame, "missing_unit_protected")
        end
        if suspiciousMissingTarget then
            Visibility.QueueRefresh(frame)
        end
        HideFrameIfSafe(frame)
        return true
    end

    if shouldHideForMissingUnit then
        frame._missingUnitSince = frame._missingUnitSince or (GetTime and GetTime() or 0)

        if frame.unit == "target" then
            local now = GetTime and GetTime() or 0
            local elapsedMissing = now - (frame._missingUnitSince or now)
            local snapshot = GetTargetPresenceSnapshot(frame.unit)

            if not IsMissingDebugSuppressed(frame) then
                ForceDebugTarget(frame, string.format(
                    "Hide-Kandidat: event=%s exists=%s guid=%s name=%s visible=%s dead=%s dt=%.2f",
                    tostring(frame._lastVisibilityEvent or "?"),
                    tostring(snapshot.exists),
                    tostring(snapshot.guid),
                    tostring(snapshot.name),
                    tostring(snapshot.visible),
                    tostring(snapshot.dead),
                    elapsedMissing
                ), "hide_candidate", 2.0)
            end

            if elapsedMissing < 0.35 then
                if State.HandleUnitLost then
                    State.HandleUnitLost(frame, "target_missing_transition")
                else
                    Visibility.ClearFrameVisualState(frame, "target_missing_transition")
                end
                HideFrameIfSafe(frame)
                QueueTargetRecoveryRefreshes(frame, "target_missing_transition")
                return true
            end
        end
    else
        frame._missingUnitSince = nil
    end

    if shouldHideForMissingUnit then
        if IsMissingDebugSuppressed(frame) then
            if State.HandleUnitLost then
                State.HandleUnitLost(frame, "missing_unit_suppressed")
            else
                Visibility.ClearFrameVisualState(frame, "missing_unit_suppressed")
            end
            if frame.SetAlpha then
                frame:SetAlpha(0)
            end
            HideFrameIfSafe(frame)
            return true
        end

        if State.HandleUnitLost then
            State.HandleUnitLost(frame, "missing_unit")
        else
            Visibility.ClearFrameVisualState(frame, "missing_unit")
        end

        if frame.SetAlpha then
            frame:SetAlpha(0)
        end

        local didHide = HideFrameIfSafe(frame)
        if not IsMissingDebugSuppressed(frame) then
            MaybeDebugTarget(frame, didHide
                and "Target-Frame wird jetzt verborgen"
                or "Target-Inhalt wird ausgeblendet; Root bleibt fuer Combat-Recovery sichtbar")
        end
        return true
    end

    return false
end

function Visibility.RegisterEvents(owner, frame)
    if not frame or frame.VisibilityEventFrame then
        return
    end

    -- Keep the event bridge independent from the secure unit frame itself.
    -- If the unit frame is hidden or enters an odd protected state in combat,
    -- we still want target/focus/pet events to keep flowing.
    local eventFrame = CreateFrame("Frame")
    eventFrame.owner = frame
    eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    eventFrame:RegisterEvent("UNIT_HEALTH")
    eventFrame:RegisterEvent("UNIT_MAXHEALTH")
    eventFrame:RegisterEvent("UNIT_FLAGS")
    eventFrame:RegisterEvent("UNIT_NAME_UPDATE")
    eventFrame:RegisterEvent("UNIT_TARGETABLE_CHANGED")
    eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
    eventFrame:RegisterEvent("UNIT_ENTERED_VEHICLE")
    eventFrame:RegisterEvent("UNIT_EXITED_VEHICLE")
    eventFrame:RegisterEvent("UPDATE_BONUS_ACTIONBAR")
    eventFrame:RegisterEvent("UPDATE_VEHICLE_ACTIONBAR")
    eventFrame:RegisterEvent("UPDATE_OVERRIDE_ACTIONBAR")
    eventFrame:RegisterEvent("PET_BATTLE_OPENING_START")
    eventFrame:RegisterEvent("PET_BATTLE_CLOSE")

    if frame.unit == "target" then
        eventFrame:RegisterEvent("PLAYER_TARGET_CHANGED")
    elseif frame.unit == "targettarget" then
        eventFrame:RegisterEvent("PLAYER_TARGET_CHANGED")
        eventFrame:RegisterEvent("UNIT_TARGET")
    elseif frame.unit == "focustarget" then
        eventFrame:RegisterEvent("PLAYER_FOCUS_CHANGED")
        eventFrame:RegisterEvent("UNIT_TARGET")
    elseif frame.unit == "focus" then
        eventFrame:RegisterEvent("PLAYER_FOCUS_CHANGED")
    elseif frame.unit == "pet" then
        eventFrame:RegisterEvent("UNIT_PET")
    end

    if type(frame.unit) == "string" and frame.unit:match("^boss%d+$") then
        eventFrame:RegisterEvent("INSTANCE_ENCOUNTER_ENGAGE_UNIT")
    end

    eventFrame:SetScript("OnEvent", function(_, event, unit)
        local currentOwner = eventFrame.owner
        if not currentOwner then
            return
        end

        if event ~= "PLAYER_REGEN_ENABLED"
            and unit
            and unit ~= currentOwner.unit
            and not (event == "UNIT_ENTERED_VEHICLE" and unit == "player")
            and not (event == "UNIT_EXITED_VEHICLE" and unit == "player")
            and not (currentOwner.unit == "targettarget" and event == "UNIT_TARGET" and unit == "target")
            and not (currentOwner.unit == "focustarget" and event == "UNIT_TARGET" and unit == "focus")
            and not (currentOwner.unit == "pet" and event == "UNIT_PET" and unit == "player")
        then
            return
        end

        if event == "UNIT_PET" and unit ~= "player" then
            return
        end

        if (event == "PLAYER_TARGET_CHANGED" or event == "PLAYER_FOCUS_CHANGED" or event == "UNIT_PET" or event == "UNIT_TARGET")
            and State.HandleTargetSwap
        then
            State.HandleTargetSwap(currentOwner, event)
        end

        currentOwner._lastVisibilityEvent = event
        if currentOwner.unit == "target" and (event == "PLAYER_TARGET_CHANGED" or event == "PLAYER_REGEN_ENABLED") then
            currentOwner._lastTargetEventAt = GetTime and GetTime() or 0
        end
        if currentOwner.unit == "target" and event == "PLAYER_TARGET_CHANGED" then
            local snapshot = GetTargetPresenceSnapshot(currentOwner.unit)
            local shown = currentOwner.IsShown and currentOwner:IsShown() or false
            local alpha = tonumber(currentOwner.GetAlpha and currentOwner:GetAlpha() or 0) or 0
            local suspicious = not snapshot.exists
                or not snapshot.guid
                or not snapshot.name
                or not shown
                or alpha < 0.99

            if suspicious then
                ForceDebugTarget(currentOwner, string.format(
                    "Event PLAYER_TARGET_CHANGED: inCombat=%s shown=%s alpha=%.2f exists=%s guid=%s name=%s visible=%s dead=%s",
                    tostring(InCombatLockdown and InCombatLockdown() or false),
                    tostring(shown),
                    alpha,
                    tostring(snapshot.exists),
                    tostring(snapshot.guid),
                    tostring(snapshot.name),
                    tostring(snapshot.visible),
                    tostring(snapshot.dead)
                ), "event_target_changed", 0.50)
            end
        end
        if event == "INSTANCE_ENCOUNTER_ENGAGE_UNIT"
            and type(currentOwner.unit) == "string"
            and currentOwner.unit:match("^boss%d+$")
        then
            if State.QueueRefresh then
                local inCombat = InCombatLockdown and InCombatLockdown()
                local scopes = inCombat
                    and { "visibility", "bars", "texts", "auras" }
                    or { "visibility", "bars", "texts", "auras", "layout" }
                State.QueueRefresh(currentOwner, event, scopes)
            else
                owner:Refresh(currentOwner)
            end
            return
        end
        if State.QueueRefresh then
            State.QueueRefresh(currentOwner, event, "visibility")
        else
            owner:Refresh(currentOwner)
        end

        if event == "PLAYER_TARGET_CHANGED" or event == "PLAYER_FOCUS_CHANGED" or event == "UNIT_PET" or event == "UNIT_TARGET" then
            Visibility.QueueRefresh(currentOwner)
            if currentOwner.unit == "target" and event == "PLAYER_TARGET_CHANGED" then
                QueueTargetRecoveryRefreshes(currentOwner, "target_changed_recovery")
            end
        end
    end)

    frame.VisibilityEventFrame = eventFrame
end
