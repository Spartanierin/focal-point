local _, FocalPoint = ...

FocalPoint.UnitFrameVisibility = FocalPoint.UnitFrameVisibility or {}
local Visibility = FocalPoint.UnitFrameVisibility

local Cast = FocalPoint.UnitFrameCastBar or {}
local Demo = FocalPoint.UnitFrameDemoEnvironment or {}
local Presence = FocalPoint.UnitFramePresence or {}
local State = FocalPoint.UnitFrameState or {}

local COMBAT_TRANSITION_TRACE_LIMIT = 100
local COMBAT_TRANSITION_SUSPICIOUS_REPORT_LIMIT = 20
local COMBAT_TRANSITION_RECENT_REPORT_LIMIT = 30
local COMBAT_TRANSITION_EVENTS = {
    PLAYER_TARGET_CHANGED = true,
    INSTANCE_ENCOUNTER_ENGAGE_UNIT = true,
    ENCOUNTER_START = true,
    UNIT_TARGET = true,
    PLAYER_REGEN_DISABLED = true,
    PLAYER_REGEN_ENABLED = true,
}
local END_STATE_INVARIANT_RECENT_LIMIT = 30
local END_STATE_INVARIANT_CHECK_LIMIT = 100
local END_STATE_INVARIANT_REPORT_LIMIT = 20
local BLOCKED_INTENT_HISTORY_LIMIT = 100
local BLOCKED_INTENT_RECENT_LIMIT = 30
local BLOCKED_INTENT_REPORT_LIMIT = 20
local END_STATE_INVARIANT_UNITS = {
    target = true,
    targettarget = true,
    focus = true,
    focustarget = true,
    boss1 = true,
    boss2 = true,
    boss3 = true,
    boss4 = true,
    boss5 = true,
    pet = true,
    companion = true,
    player = true,
}

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

local function IsCombatTransitionUnit(unit)
    return unit == "target"
        or (type(unit) == "string" and unit:match("^boss%d+$") ~= nil)
end

local function FormatTraceBool(value)
    if value == nil then
        return "nil"
    end
    return tostring(value == true)
end

local function FormatTraceNumber(value, decimals)
    local number = tonumber(value)
    if not number then
        return "nil"
    end
    return string.format("%." .. tostring(decimals or 3) .. "f", number)
end

local function FormatTraceValue(value)
    if value == nil then
        return "nil"
    end
    return tostring(value)
end

local function NormalizeTraceScopes(scopes)
    if type(scopes) ~= "table" then
        return scopes ~= nil and tostring(scopes) or "nil"
    end

    local parts = {}
    for key, enabled in pairs(scopes) do
        if enabled == true then
            parts[#parts + 1] = tostring(key)
        elseif type(key) == "number" and type(enabled) == "string" and enabled ~= "" then
            parts[#parts + 1] = enabled
        end
    end
    table.sort(parts)
    if #parts == 0 then
        return "none"
    end
    return table.concat(parts, ",")
end

local function ResolveTraceUnitExists(unit)
    if unit == "player" then
        return true
    end
    if UnitExists and type(unit) == "string" and unit ~= "" then
        return UnitExists(unit) and true or false
    end
    return false
end

local function ResolveTraceFrameShown(frame)
    if frame and frame.IsShown then
        return frame:IsShown() == true
    end
    return nil
end

local function ResolveTraceFrameAlpha(frame)
    if frame and frame.GetAlpha then
        return tonumber(frame:GetAlpha())
    end
    return nil
end

local function ResolveTraceProtected(frame)
    if frame and frame.IsProtected then
        return frame:IsProtected() == true
    end
    return false
end

local function ResolveTraceStatePhase(frame)
    local runtimeState = frame and frame.FocalPointRuntimeState
    return runtimeState and runtimeState.phase or nil
end

local function ResolveTraceMissingSince(frame)
    local runtimeState = frame and frame.FocalPointRuntimeState
    return runtimeState and runtimeState.missingSince or nil
end

local function ResolveTraceMode(frame, overrideMode)
    if type(overrideMode) == "string" and overrideMode ~= "" then
        return overrideMode
    end
    local runtimeState = frame and frame.FocalPointRuntimeState
    return runtimeState and runtimeState.mode or nil
end

local function ResolveTraceConfigEnabled(frame, config)
    config = type(config) == "table" and config or frame and frame.config or nil
    if type(config) == "table" then
        return config.enabled ~= false
    end
    return nil
end

local function ResolveTraceRootDecisionReason(frame, values)
    if type(values.rootDecisionReason) == "string" then
        return values.rootDecisionReason
    end
    local rootDecision = values.rootDecision
    if not rootDecision and values.captureRoot == true and frame and Visibility.ResolveRootDecision then
        rootDecision = Visibility.ResolveRootDecision(frame, values.rootDecisionSource or "combat-transition-trace", {
            config = values.config,
            mode = values.mode,
            modeReason = values.modeReason,
            unitPresent = values.unitPresent,
        })
    end
    return rootDecision and rootDecision.reason or nil
end

local function ResolveTraceRootActionPlanReason(frame, values)
    if type(values.rootActionPlanReason) == "string" then
        return values.rootActionPlanReason
    end
    local rootActionPlan = values.rootActionPlan
    if not rootActionPlan and values.captureRoot == true and frame and Visibility.ResolveRootActionPlan then
        rootActionPlan = Visibility.ResolveRootActionPlan(frame, {
            config = values.config,
            mode = values.mode,
            modeReason = values.modeReason,
            unitPresent = values.unitPresent,
        })
    end
    return rootActionPlan and rootActionPlan.reason or nil
end

local function ResolveTraceAbsentGuard(values)
    if values.absentGuard ~= nil then
        return values.absentGuard == true
    end
    local showDecision = values.rootShowDecision
    return showDecision
        and (
            showDecision.absentTargetGuard == true
            or showDecision.absentTargetTargetGuard == true
            or showDecision.absentFocusTargetGuard == true
            or showDecision.absentBossGuard == true
        )
        or false
end

local function IsTraceEntrySuspicious(entry)
    if not entry or entry.stage ~= "refresh-exit" then
        return false
    end
    if entry.UnitExists == true
        and entry.frameExists == true
        and (entry.shown == false or tonumber(entry.alpha) == 0)
    then
        return true
    end
    if type(entry.unit) == "string"
        and entry.unit:match("^boss%d+$")
        and entry.UnitExists == true
        and entry.unitWatchRegistered == false
        and entry.inCombat == true
    then
        return true
    end
    return false
end

local function AppendRingEntry(buffer, entry, limit)
    buffer[#buffer + 1] = entry
    while #buffer > limit do
        table.remove(buffer, 1)
    end
end

local TARGET_ROOT_PREARM_REASONS = {
    missing_unit = true,
    missing_unit_suppressed = true,
    missing_unit_protected = true,
    missing_unit_protected_suppressed = true,
    target_missing_transition = true,
}

local function ShouldPrearmTargetRoot(frame, options)
    if not (frame and frame.unit == "target") then
        return false
    end
    local reason = type(options) == "table" and options.reason or nil
    if not TARGET_ROOT_PREARM_REASONS[reason] then
        return false
    end
    local config = frame.config
    if type(config) == "table" and config.enabled == false then
        return false
    end
    if FocalPoint and (FocalPoint.framesUnlocked == true or FocalPoint.guiTestModeEnabled == true) then
        return false
    end
    return frame.Show ~= nil and not IsProtectedFrameInCombat(frame)
end

local function PrearmTargetRootIfSafe(frame, options)
    if not ShouldPrearmTargetRoot(frame, options) then
        return false
    end
    frame:Show()
    return true
end

local function HideFrameIfSafe(frame, options)
    if not (frame and frame.Hide) then
        return false
    end
    if frame.unit == "target" then
        local prearmed = PrearmTargetRootIfSafe(frame, options)
        if Visibility.RecordBlockedRootIntent then
            Visibility.RecordBlockedRootIntent(frame, {
                intent = "hide-root",
                source = "hide-if-safe",
                reason = "target-hide-suppressed",
                mode = "live",
                exists = UnitExists and UnitExists(frame.unit) or false,
                shown = frame.IsShown and frame:IsShown() or false,
                alpha = frame.GetAlpha and frame:GetAlpha() or nil,
                protected = frame.IsProtected and frame:IsProtected() or false,
                inCombat = InCombatLockdown and InCombatLockdown() or false,
                unitWatchRegistered = frame._unitWatchRegistered == true,
                targetRootPrearmed = prearmed == true,
            })
        end
        return false
    end
    if IsProtectedFrameInCombat(frame) then
        if Visibility.RecordBlockedRootIntent then
            Visibility.RecordBlockedRootIntent(frame, {
                intent = "hide-root",
                source = "hide-if-safe",
                reason = "hide-protected-combat",
                mode = "live",
                exists = UnitExists and UnitExists(frame.unit) or false,
                shown = frame.IsShown and frame:IsShown() or false,
                alpha = frame.GetAlpha and frame:GetAlpha() or nil,
                protected = true,
                inCombat = true,
                unitWatchRegistered = frame._unitWatchRegistered == true,
            })
        end
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

-- Passive read-only model for the local root-show semantics in UnitFrameRefresh.Apply.
-- This function intentionally does not call Show, Hide, SetAlpha, UnitWatch, refresh, or state mutation.
function Visibility.ResolveRootShowDecision(frame, options)
    options = type(options) == "table" and options or {}

    local unit = frame and frame.unit or nil
    local config = type(options.config) == "table" and options.config or frame and frame.config or nil
    local configEnabled = nil
    if config ~= nil then
        configEnabled = config.enabled ~= false
    end
    local protectedRoot
    if type(options.protectedRoot) == "boolean" then
        protectedRoot = options.protectedRoot
    else
        protectedRoot = frame
            and frame.IsProtected
            and frame:IsProtected()
            or false
    end
    local inCombat
    if type(options.inCombat) == "boolean" then
        inCombat = options.inCombat
    else
        inCombat = InCombatLockdown and InCombatLockdown() or false
    end
    local previewActive = FocalPoint
        and (FocalPoint.guiTestModeEnabled == true or FocalPoint.framesUnlocked == true)
        or false
    local previewOutsideCombat
    if type(options.previewOutsideCombat) == "boolean" then
        previewOutsideCombat = options.previewOutsideCombat
    else
        previewOutsideCombat = IsPreviewModeEnabled
            and IsPreviewModeEnabled()
            and not inCombat
            or false
    end
    local outsideCombat = not inCombat
    local canCallShow = frame ~= nil
        and frame.Show ~= nil
        and (not protectedRoot or previewOutsideCombat or outsideCombat)

    local mode, modeReason = options.mode, options.modeReason
    if type(mode) ~= "string" or mode == "" then
        mode, modeReason = ResolveModeReadOnly(frame)
    end

    local rootDecision = options.rootDecision
    if rootDecision == nil and frame ~= nil then
        rootDecision = Visibility.ResolveRootDecision(frame, "root-show", {
            config = config,
            mode = mode,
            modeReason = modeReason,
            unitPresent = options.unitPresent,
        })
    end

    local unitPresent
    if type(options.unitPresent) == "boolean" then
        unitPresent = options.unitPresent
    elseif unit == "player" then
        unitPresent = true
    elseif DoesUnitSeemPresent and type(unit) == "string" and unit ~= "" then
        unitPresent = DoesUnitSeemPresent(unit) == true
    elseif UnitExists and type(unit) == "string" and unit ~= "" then
        unitPresent = UnitExists(unit) and true or false
    else
        unitPresent = false
    end

    local shouldProcessFrame = true
    if Demo.ShouldProcessFrame and frame ~= nil then
        shouldProcessFrame = Demo.ShouldProcessFrame(frame) == true
    end

    local decision = {
        action = "keep",
        reason = "invalid-frame",
        shouldShow = false,
        shouldSkipShow = false,

        unit = unit,
        mode = mode,
        modeReason = modeReason,
        previewActive = previewActive == true,
        previewOutsideCombat = previewOutsideCombat == true,
        unitPresent = unitPresent == true,
        protectedRoot = protectedRoot == true,
        inCombat = inCombat == true,
        outsideCombat = outsideCombat == true,
        canCallShow = canCallShow == true,
        configEnabled = configEnabled,
        shouldProcessFrame = shouldProcessFrame == true,
        refreshApplyReached = options.refreshApplyReached ~= false,
        missingHandled = options.missingHandled == true,

        absentTargetGuard = false,
        absentTargetTargetGuard = false,
        absentFocusTargetGuard = false,
        absentDerivedGuard = false,
        absentBossGuard = false,

        rootDecisionReason = rootDecision and rootDecision.reason or nil,
        rootDecisionVisible = rootDecision and rootDecision.visible == true or false,
    }

    if not frame or type(unit) ~= "string" or unit == "" then
        return decision
    end

    if options.refreshApplyReached == false then
        decision.reason = "refresh-not-reached"
        return decision
    end

    if not config then
        decision.reason = "invalid-config"
        return decision
    end

    if options.missingHandled == true then
        decision.reason = "missing-handled-return"
        return decision
    end

    if mode == "disabled" then
        decision.reason = "demo-disabled-return"
        return decision
    end

    if config.enabled == false and not (FocalPoint and FocalPoint.framesUnlocked == true) then
        decision.reason = "disabled-live-return"
        return decision
    end

    if mode == "detailed" or mode == "placeholder" then
        if not shouldProcessFrame then
            decision.reason = "demo-filtered-return"
            return decision
        end
        if canCallShow then
            decision.action = "show"
            decision.reason = mode == "placeholder" and "preview-placeholder-show" or "preview-detailed-show"
            decision.shouldShow = true
            return decision
        end
        decision.reason = "preview-protected-combat-keep"
        return decision
    end

    local hasUnitExists = UnitExists ~= nil
    local skipShowForAbsentTarget = unit == "target"
        and not previewOutsideCombat
        and hasUnitExists
        and not UnitExists("target")
    local skipShowForAbsentTargetTarget = unit == "targettarget"
        and not previewOutsideCombat
        and hasUnitExists
        and not UnitExists("targettarget")
    local skipShowForAbsentFocusTarget = unit == "focustarget"
        and not previewOutsideCombat
        and hasUnitExists
        and not UnitExists("focustarget")
    local skipShowForAbsentBoss = unit:match("^boss%d+$") ~= nil
        and not previewOutsideCombat
        and hasUnitExists
        and not UnitExists(unit)

    decision.absentTargetGuard = skipShowForAbsentTarget == true
    decision.absentTargetTargetGuard = skipShowForAbsentTargetTarget == true
    decision.absentFocusTargetGuard = skipShowForAbsentFocusTarget == true
    decision.absentDerivedGuard = skipShowForAbsentTargetTarget == true
        or skipShowForAbsentFocusTarget == true
    decision.absentBossGuard = skipShowForAbsentBoss == true

    if skipShowForAbsentTarget then
        decision.action = "skip-show"
        decision.reason = "absent-target"
        decision.shouldSkipShow = true
        return decision
    end
    if skipShowForAbsentTargetTarget then
        decision.action = "skip-show"
        decision.reason = "absent-targettarget"
        decision.shouldSkipShow = true
        return decision
    end
    if skipShowForAbsentFocusTarget then
        decision.action = "skip-show"
        decision.reason = "absent-focustarget"
        decision.shouldSkipShow = true
        return decision
    end
    if skipShowForAbsentBoss then
        decision.action = "skip-show"
        decision.reason = "absent-boss"
        decision.shouldSkipShow = true
        return decision
    end

    if canCallShow then
        decision.action = "show"
        decision.reason = unitPresent and "live-present-show" or "live-local-show"
        decision.shouldShow = true
        return decision
    end

    decision.reason = "live-protected-combat-keep"
    return decision
end

local function ResolveConfigAlpha(frame, options)
    if type(options.configAlpha) == "number" then
        return options.configAlpha
    end

    local config = type(options.config) == "table" and options.config or frame and frame.config
    if type(config) == "table" and type(config.alpha) == "number" then
        return config.alpha
    end

    return 1
end

local function ResolveRangeMultiplier(frame, options)
    if type(options.rangeMultiplier) == "number" then
        return options.rangeMultiplier
    end

    local range = FocalPoint and FocalPoint.UnitFrameRange or nil
    if range and range.GetFadeMultiplier then
        return range.GetFadeMultiplier(frame)
    end

    return 1
end

local function IsMissingUnitAlphaGuardActive(frame)
    local unit = frame and frame.unit
    if IsPreviewModeEnabled and IsPreviewModeEnabled() then
        return false
    end
    if not (UnitExists and type(unit) == "string") then
        return false
    end

    if unit == "target" or unit == "targettarget" or unit == "focustarget" then
        return not UnitExists(unit)
    end

    if unit:match("^boss%d+$") then
        return not UnitExists(unit)
    end

    return false
end

-- Passive read-only model for future root-alpha centralization. This function
-- intentionally does not call SetAlpha, Show, Hide, UnitWatch, refresh, or state mutation.
function Visibility.ResolveRootAlphaDecision(frame, options)
    options = type(options) == "table" and options or {}

    local source = type(options.source) == "string" and options.source or "composed"
    local rootDecision = type(options.rootDecision) == "table"
        and options.rootDecision
        or Visibility.ResolveRootDecision(frame, options.visibilityReason or "root-alpha", options.visibilityOptions)
    local configAlpha = ResolveConfigAlpha(frame, options)
    local rangeMultiplier = ResolveRangeMultiplier(frame, options)
    local rangeAlpha = configAlpha * rangeMultiplier
    local missingUnitAlphaGuard
    if type(options.missingUnitAlphaGuard) == "boolean" then
        missingUnitAlphaGuard = options.missingUnitAlphaGuard
    else
        missingUnitAlphaGuard = IsMissingUnitAlphaGuardActive(frame)
    end
    local disabledLive = rootDecision and rootDecision.reason == "unit-disabled" or false
    if source == "disabled-live" and type(options.disabled) == "boolean" then
        disabledLive = options.disabled
    end
    local previewDisabled = rootDecision and rootDecision.reason == "preview-disabled" or false
    local specialMode = rootDecision and rootDecision.reason == "special-mode" or false
    local isPlaceholder = rootDecision and rootDecision.mode == "placeholder" or false
    local placeholderAlphaOverride = isPlaceholder
        and FocalPoint
        and FocalPoint.framesUnlocked == true
        and FocalPoint.guiTestModeEnabled ~= true
    local rangeDriverActive
    if type(options.rangeDriverActive) == "boolean" then
        rangeDriverActive = options.rangeDriverActive
    else
        rangeDriverActive = frame
            and frame.RangeFadeDriver
            and frame.RangeFadeDriver.IsShown
            and frame.RangeFadeDriver:IsShown()
            or false
    end
    local overrideAlpha = nil
    local winningSource = "config"
    local reason = rootDecision and rootDecision.reason or "invalid-frame"
    local writesImmediately = true
    local requiresRangeContext = false

    if source == "layout" or source == "apply-config-layout" then
        if missingUnitAlphaGuard then
            overrideAlpha = 0
            winningSource = "layout-missing-unit"
        else
            winningSource = "config"
        end
    elseif source == "range-fade" or source == "apply-range-fade" then
        if missingUnitAlphaGuard then
            overrideAlpha = 0
            winningSource = "range-missing-unit"
        elseif frame and frame.unit == "target" and frame.IsShown and frame:IsShown() and rangeDriverActive then
            writesImmediately = false
            requiresRangeContext = true
            winningSource = "range-fade-target"
        elseif rangeMultiplier ~= 1 then
            winningSource = "range-fade"
        else
            winningSource = "config"
        end
    elseif source == "range-driver" then
        if type(options.currentAlpha) == "number" then
            overrideAlpha = options.currentAlpha
        elseif frame and type(frame._rangeCurrentAlpha) == "number" then
            overrideAlpha = frame._rangeCurrentAlpha
        else
            overrideAlpha = rangeAlpha
            requiresRangeContext = true
        end
        winningSource = "range-driver"
    elseif source == "refresh-placeholder" then
        if placeholderAlphaOverride then
            overrideAlpha = 1
            winningSource = "unlock-placeholder"
        else
            writesImmediately = false
            winningSource = "no-placeholder-alpha-write"
        end
    elseif source == "demo-snapshot" then
        if previewDisabled then
            overrideAlpha = 0
            winningSource = "preview-disabled"
        else
            writesImmediately = false
            winningSource = "no-demo-alpha-write"
        end
    elseif source == "visibility" or source == "handle-missing-unit" then
        if rootDecision and rootDecision.shouldAlphaZero then
            overrideAlpha = 0
            winningSource = reason or "alpha-zero"
        else
            writesImmediately = false
            winningSource = "no-visibility-alpha-write"
        end
    elseif source == "disabled-live" then
        if disabledLive then
            overrideAlpha = 0
            winningSource = "unit-disabled"
        else
            writesImmediately = false
            winningSource = "no-disabled-live-alpha-write"
        end
    elseif source == "deactivate" then
        overrideAlpha = 0
        winningSource = "deactivated"
    elseif options.deactivated == true then
        overrideAlpha = 0
        winningSource = "deactivated"
    elseif disabledLive or previewDisabled or specialMode or (rootDecision and rootDecision.shouldAlphaZero) then
        overrideAlpha = 0
        winningSource = reason or "alpha-zero"
    elseif placeholderAlphaOverride then
        overrideAlpha = 1
        winningSource = "unlock-placeholder"
    elseif rangeMultiplier ~= 1 then
        winningSource = "range-fade"
    end

    local finalAlpha = overrideAlpha
    if finalAlpha == nil and writesImmediately then
        finalAlpha = rangeAlpha
    end

    return {
        alpha = finalAlpha,
        finalAlpha = finalAlpha,
        targetAlpha = rangeAlpha,
        baseAlpha = configAlpha,
        configAlpha = configAlpha,
        rangeMultiplier = rangeMultiplier,
        rangeAlpha = rangeAlpha,
        overrideAlpha = overrideAlpha,
        source = source,
        writesImmediately = writesImmediately,
        requiresRangeContext = requiresRangeContext,
        rangeDriverActive = rangeDriverActive,
        missingUnitAlphaGuard = missingUnitAlphaGuard,

        reason = reason,
        winningSource = winningSource,
        visibilityReason = reason,
        unit = rootDecision and rootDecision.unit or frame and frame.unit or nil,
        unitPresent = rootDecision and rootDecision.unitPresent == true or false,
        mode = rootDecision and rootDecision.mode or "live",
        modeReason = rootDecision and rootDecision.modeReason or nil,
        forceVisible = rootDecision and rootDecision.forceVisible == true or false,
        disabled = disabledLive,
        deactivated = options.deactivated == true,
        specialModeActive = rootDecision and rootDecision.specialModeActive == true or false,
        shouldForceZero = overrideAlpha == 0,

        sources = {
            config = configAlpha,
            rangeFade = rangeAlpha,
            missingUnit = rootDecision and rootDecision.reason == "missing-unit" and 0 or nil,
            specialMode = rootDecision and rootDecision.reason == "special-mode" and 0 or nil,
            previewDisabled = rootDecision and rootDecision.reason == "preview-disabled" and 0 or nil,
            unitDisabled = disabledLive and 0 or nil,
            demoDetailed = rootDecision and rootDecision.mode == "detailed" and rangeAlpha or nil,
            unlockPlaceholder = rootDecision and rootDecision.mode == "placeholder" and 1 or nil,
            deactivated = options.deactivated == true and 0 or nil,
        },
    }
end

local MAX_DECISION_DEBUG_MISMATCHES = 20
local MAX_ROOT_ACTION_PLAN_MISMATCHES = 20

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

    if not previewEnabled
        and Demo.IsFrameUnitEnabled
        and not Demo.IsFrameUnitEnabled(frame)
    then
        outcome.handled = true
        outcome.outcome = "unit-disabled"
        outcome.wouldAlphaZero = true
        outcome.wouldDisableMouse = true
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

local function ResolveUnitLostClearAction(frame, reason, context)
    context = type(context) == "table" and context or {}

    if reason == "target_missing_transition" then
        return "content-only"
    end

    local unit = context.unit or frame and frame.unit
    local protectedRoot
    if type(context.protectedRoot) == "boolean" then
        protectedRoot = context.protectedRoot
    else
        protectedRoot = frame
            and frame.IsProtected
            and frame:IsProtected()
            or false
    end

    local inCombat
    if type(context.inCombat) == "boolean" then
        inCombat = context.inCombat
    else
        inCombat = InCombatLockdown and InCombatLockdown() or false
    end

    local protectedCombatMissing = reason == "missing_unit_protected"
        and protectedRoot
        and inCombat
    local bossMissingUnit = IsBossRuntimeUnit
        and IsBossRuntimeUnit(unit)
        and (
            reason == "missing_unit"
            or reason == "missing_unit_protected"
            or reason == "missing_unit_suppressed"
            or reason == "missing_unit_protected_suppressed"
        )

    if protectedCombatMissing or bossMissingUnit then
        return "content-only"
    end

    return "hard"
end

local function BuildMissingUnitActionPlan(frame, rootDecision, branchReason, options)
    options = type(options) == "table" and options or {}
    rootDecision = type(rootDecision) == "table"
        and rootDecision
        or Visibility.ResolveRootDecision(frame, options.visibilityReason or "root-action-plan", options.visibilityOptions)

    local unit = rootDecision and rootDecision.unit or frame and frame.unit or nil
    local protectedRoot = rootDecision and rootDecision.protectedRoot == true or false
    local inCombat = rootDecision and rootDecision.inCombat == true or false
    local protectedInCombat = protectedRoot and inCombat
    local unitPresent = rootDecision and rootDecision.unitPresent == true or false
    local previewActive = rootDecision and rootDecision.previewEnabled == true or false
    local forceVisible = rootDecision and rootDecision.forceVisible == true or false
    local specialModeActive = rootDecision and rootDecision.specialModeActive == true or false
    local canHideRoot = rootDecision and rootDecision.canHideRoot == true or false
    local missingSuppressed = options.missingSuppressed
    if type(missingSuppressed) ~= "boolean" then
        missingSuppressed = IsMissingDebugSuppressed(frame)
    end

    return {
        reason = branchReason or "not-handled",
        decisionReason = rootDecision and rootDecision.reason or "invalid-frame",
        rootDecision = rootDecision,

        clearAction = "none",
        alphaAction = "keep",
        mouseAction = "keep",
        rootAction = "keep",
        stateAction = "none",
        recoveryAction = "none",

        shouldReturn = false,

        unit = unit,
        unitPresent = unitPresent,
        mode = rootDecision and rootDecision.mode or "live",
        previewActive = previewActive,
        forceVisible = forceVisible,
        specialModeActive = specialModeActive,
        protectedRoot = protectedRoot,
        inCombat = inCombat,
        canHideRoot = canHideRoot,
        missingSuppressed = missingSuppressed,
        targetTransition = false,
        suspiciousMissingTarget = false,
        protectedInCombat = protectedInCombat,
        rootActionPossible = WouldHideRoot(frame),
        stateReason = nil,
        stateClearMode = nil,
        stateUnitPresentGuard = false,
        recoveryReason = nil,
    }
end

-- Passive read-only model for the current HandleMissingUnit legacy semantics.
-- This function intentionally does not call SetAlpha, Show, Hide, SetShown,
-- mouse mutators, clear helpers, State, refresh/recovery queues, or UnitWatch.
function Visibility.ResolveRootActionPlan(frame, options)
    options = type(options) == "table" and options or {}
    if not frame then
        return nil, "invalid-frame"
    end

    local decision = type(options.rootDecision) == "table"
        and options.rootDecision
        or Visibility.ResolveRootDecision(frame, options.visibilityReason or "handle-missing-unit", options.visibilityOptions)
    local plan = BuildMissingUnitActionPlan(frame, decision, "not-handled", options)

    if decision.specialModeActive then
        plan.reason = decision.specialModeReason or "special_mode"
        plan.clearAction = ResolveUnitLostClearAction(frame, plan.reason, plan)
        plan.alphaAction = "zero"
        plan.rootAction = "hide-if-safe"
        plan.stateAction = "unit-lost"
        plan.stateReason = plan.reason
        plan.stateClearMode = plan.clearAction
        plan.stateUnitPresentGuard = true
        plan.shouldReturn = true
        return plan
    end

    if decision.previewEnabled
        and Demo.IsFrameUnitEnabled
        and not Demo.IsFrameUnitEnabled(frame)
        and not (FocalPoint and FocalPoint.framesUnlocked == true and FocalPoint.guiTestModeEnabled ~= true)
    then
        plan.reason = "preview-disabled-unit"
        plan.clearAction = "content-only"
        plan.alphaAction = "zero"
        plan.mouseAction = "disable"
        plan.rootAction = "hide-if-safe"
        plan.stateAction = "clear-missing"
        plan.shouldReturn = true
        return plan
    end

    if decision.forceVisible then
        plan.reason = "force-visible"
        plan.stateAction = "clear-missing"
        return plan
    end

    if decision.previewEnabled then
        plan.reason = "preview-active"
        plan.stateAction = "clear-missing"
        return plan
    end

    local shouldHideForMissingUnit = not decision.previewEnabled
        and frame.unit ~= "player"
        and not decision.unitPresent

    if shouldHideForMissingUnit then
        if frame.unit == "target" then
            plan.alphaAction = "zero"
        end
        if not plan.protectedInCombat then
            plan.mouseAction = "disable"
        end
    else
        plan.reason = "unit-present"
        plan.stateAction = "clear-missing"
        return plan
    end

    if shouldHideForMissingUnit and decision.protectedRoot then
        if plan.missingSuppressed then
            plan.reason = "missing_unit_protected_suppressed"
            plan.clearAction = ResolveUnitLostClearAction(frame, plan.reason, plan)
            plan.alphaAction = "zero"
            plan.rootAction = "hide-if-safe"
            plan.stateAction = "unit-lost"
            plan.stateReason = plan.reason
            plan.stateClearMode = plan.clearAction
            plan.stateUnitPresentGuard = true
            plan.shouldReturn = true
            return plan
        end

        local suspiciousMissingTarget
        if type(options.suspiciousMissingTarget) == "boolean" then
            suspiciousMissingTarget = options.suspiciousMissingTarget
        else
            suspiciousMissingTarget = ShouldTreatMissingTargetAsSuspicious
                and ShouldTreatMissingTargetAsSuspicious(frame)
                or false
        end

        plan.reason = "missing_unit_protected"
        plan.clearAction = ResolveUnitLostClearAction(frame, plan.reason, plan)
        plan.rootAction = "hide-if-safe"
        plan.stateAction = "unit-lost"
        plan.recoveryAction = suspiciousMissingTarget and "queue-refresh" or "none"
        plan.recoveryReason = suspiciousMissingTarget and "visibility" or nil
        plan.suspiciousMissingTarget = suspiciousMissingTarget
        plan.stateReason = plan.reason
        plan.stateClearMode = plan.clearAction
        plan.stateUnitPresentGuard = true
        plan.shouldReturn = true
        return plan
    end

    if shouldHideForMissingUnit and frame.unit == "target" then
        local now = tonumber(options.now) or (GetTime and GetTime() or 0)
        local missingSince = tonumber(options.missingSince or frame._missingUnitSince) or now
        local elapsedMissing = now - missingSince

        if elapsedMissing < 0.35 then
            plan.reason = "target_missing_transition"
            plan.clearAction = ResolveUnitLostClearAction(frame, plan.reason, plan)
            plan.rootAction = "hide-if-safe"
            plan.stateAction = "unit-lost"
            plan.recoveryAction = "queue-target-recovery"
            plan.recoveryReason = "target_missing_transition"
            plan.targetTransition = true
            plan.elapsedMissing = elapsedMissing
            plan.stateReason = plan.reason
            plan.stateClearMode = plan.clearAction
            plan.stateUnitPresentGuard = true
            plan.shouldReturn = true
            return plan
        end

        plan.elapsedMissing = elapsedMissing
    end

    if shouldHideForMissingUnit then
        if plan.missingSuppressed then
            plan.reason = "missing_unit_suppressed"
            plan.clearAction = ResolveUnitLostClearAction(frame, plan.reason, plan)
            plan.alphaAction = "zero"
            plan.rootAction = "hide-if-safe"
            plan.stateAction = "unit-lost"
            plan.stateReason = plan.reason
            plan.stateClearMode = plan.clearAction
            plan.stateUnitPresentGuard = true
            plan.shouldReturn = true
            return plan
        end

        plan.reason = "missing_unit"
        plan.clearAction = ResolveUnitLostClearAction(frame, plan.reason, plan)
        plan.alphaAction = "zero"
        plan.rootAction = "hide-if-safe"
        plan.stateAction = "unit-lost"
        plan.stateReason = plan.reason
        plan.stateClearMode = plan.clearAction
        plan.stateUnitPresentGuard = true
        plan.shouldReturn = true
        return plan
    end

    return plan
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
        rootActionPlanComparisons = 0,
        rootActionPlanMismatches = 0,
        rootActionPlanMismatchesByBranch = {},
        rootActionPlanMismatchesByField = {},
        rootActionPlanMismatchesByUnit = {},
        rootActionPlanMatchesByBranch = {},
        rootActionPlanRecentMismatches = {},
        rootActionPlanLastMismatch = nil,
        criticalProfileComparisons = 0,
        criticalProfileMismatches = 0,
        criticalProfileComparisonsByBranch = {},
        criticalProfileMismatchesByBranch = {},
        criticalProfileMismatchesByField = {},
        criticalProfileMatchesByProfile = {},
        criticalProfileRecentMismatches = {},
        criticalProfileLastMismatch = nil,
        rootShowDecisionComparisons = 0,
        rootShowDecisionMismatches = 0,
        rootShowDecisionMismatchesByAction = {},
        rootShowDecisionMismatchesByReason = {},
        rootShowDecisionMismatchesByField = {},
        rootShowDecisionMismatchesByUnit = {},
        rootShowDecisionComparisonsByBranch = {},
        rootShowDecisionMatchesByBranch = {},
        rootShowDecisionRecentMismatches = {},
        rootShowDecisionLastMismatch = nil,
        endStateInvariantChecks = 0,
        endStateInvariantViolations = 0,
        endStateInvariantByViolation = {},
        endStateInvariantByUnit = {},
        endStateInvariantByMode = {},
        endStateInvariantByCombat = {},
        endStateInvariantRecentChecks = {},
        endStateInvariantRecent = {},
        endStateInvariantFirstNotified = false,
        blockedIntentNextId = 1,
        blockedIntentObserved = 0,
        blockedIntentResolved = 0,
        blockedIntentExpired = 0,
        blockedIntentPolicySuppressed = 0,
        blockedIntentIgnoredNoOp = 0,
        blockedIntentStillPending = 0,
        blockedIntentOpen = {},
        blockedIntentHistory = {},
        blockedIntentRecentResolved = {},
        blockedIntentRecentExpired = {},
        blockedIntentRecentStillPending = {},
        blockedIntentByIntent = {},
        blockedIntentByUnit = {},
        blockedIntentBySource = {},
        blockedIntentByCombat = {},
        blockedIntentBySuppressedReason = {},
        blockedIntentMaxObservations = 0,
    }
    return FocalPoint.VisibilityDecisionDebug
end

local function EnsureRootActionDebugState(state)
    state.rootActionPlanComparisons = tonumber(state.rootActionPlanComparisons) or 0
    state.rootActionPlanMismatches = tonumber(state.rootActionPlanMismatches) or 0
    state.rootActionPlanMismatchesByBranch = state.rootActionPlanMismatchesByBranch or {}
    state.rootActionPlanMismatchesByField = state.rootActionPlanMismatchesByField or {}
    state.rootActionPlanMismatchesByUnit = state.rootActionPlanMismatchesByUnit or {}
    state.rootActionPlanMatchesByBranch = state.rootActionPlanMatchesByBranch or {}
    state.rootActionPlanRecentMismatches = state.rootActionPlanRecentMismatches or {}
    state.criticalProfileComparisons = tonumber(state.criticalProfileComparisons) or 0
    state.criticalProfileMismatches = tonumber(state.criticalProfileMismatches) or 0
    state.criticalProfileComparisonsByBranch = state.criticalProfileComparisonsByBranch or {}
    state.criticalProfileMismatchesByBranch = state.criticalProfileMismatchesByBranch or {}
    state.criticalProfileMismatchesByField = state.criticalProfileMismatchesByField or {}
    state.criticalProfileMatchesByProfile = state.criticalProfileMatchesByProfile or {}
    state.criticalProfileRecentMismatches = state.criticalProfileRecentMismatches or {}
    state.rootShowDecisionComparisons = tonumber(state.rootShowDecisionComparisons) or 0
    state.rootShowDecisionMismatches = tonumber(state.rootShowDecisionMismatches) or 0
    state.rootShowDecisionMismatchesByAction = state.rootShowDecisionMismatchesByAction or {}
    state.rootShowDecisionMismatchesByReason = state.rootShowDecisionMismatchesByReason or {}
    state.rootShowDecisionMismatchesByField = state.rootShowDecisionMismatchesByField or {}
    state.rootShowDecisionMismatchesByUnit = state.rootShowDecisionMismatchesByUnit or {}
    state.rootShowDecisionComparisonsByBranch = state.rootShowDecisionComparisonsByBranch or {}
    state.rootShowDecisionMatchesByBranch = state.rootShowDecisionMatchesByBranch or {}
    state.rootShowDecisionRecentMismatches = state.rootShowDecisionRecentMismatches or {}
    state.combatTransitionTrace = state.combatTransitionTrace or {}
    state.combatTransitionSuspicious = state.combatTransitionSuspicious or {}
    state.endStateInvariantChecks = tonumber(state.endStateInvariantChecks) or 0
    state.endStateInvariantViolations = tonumber(state.endStateInvariantViolations) or 0
    state.endStateInvariantByViolation = state.endStateInvariantByViolation or {}
    state.endStateInvariantByUnit = state.endStateInvariantByUnit or {}
    state.endStateInvariantByMode = state.endStateInvariantByMode or {}
    state.endStateInvariantByCombat = state.endStateInvariantByCombat or {}
    state.endStateInvariantRecentChecks = state.endStateInvariantRecentChecks or {}
    state.endStateInvariantRecent = state.endStateInvariantRecent or {}
    state.endStateInvariantFirstNotified = state.endStateInvariantFirstNotified == true
    state.blockedIntentNextId = tonumber(state.blockedIntentNextId) or 1
    state.blockedIntentObserved = tonumber(state.blockedIntentObserved) or 0
    state.blockedIntentResolved = tonumber(state.blockedIntentResolved) or 0
    state.blockedIntentExpired = tonumber(state.blockedIntentExpired) or 0
    state.blockedIntentPolicySuppressed = tonumber(state.blockedIntentPolicySuppressed) or 0
    state.blockedIntentIgnoredNoOp = tonumber(state.blockedIntentIgnoredNoOp) or 0
    state.blockedIntentStillPending = tonumber(state.blockedIntentStillPending) or 0
    state.blockedIntentOpen = state.blockedIntentOpen or {}
    state.blockedIntentHistory = state.blockedIntentHistory or {}
    state.blockedIntentRecentResolved = state.blockedIntentRecentResolved or {}
    state.blockedIntentRecentExpired = state.blockedIntentRecentExpired or {}
    state.blockedIntentRecentStillPending = state.blockedIntentRecentStillPending or {}
    state.blockedIntentByIntent = state.blockedIntentByIntent or {}
    state.blockedIntentByUnit = state.blockedIntentByUnit or {}
    state.blockedIntentBySource = state.blockedIntentBySource or {}
    state.blockedIntentByCombat = state.blockedIntentByCombat or {}
    state.blockedIntentBySuppressedReason = state.blockedIntentBySuppressedReason or {}
    state.blockedIntentMaxObservations = tonumber(state.blockedIntentMaxObservations) or 0
    return state
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
    EnsureRootActionDebugState(state)
    state.rootActionPlanComparisons = 0
    state.rootActionPlanMismatches = 0
    state.rootActionPlanMismatchesByBranch = WipeDecisionDebugMap(state.rootActionPlanMismatchesByBranch)
    state.rootActionPlanMismatchesByField = WipeDecisionDebugMap(state.rootActionPlanMismatchesByField)
    state.rootActionPlanMismatchesByUnit = WipeDecisionDebugMap(state.rootActionPlanMismatchesByUnit)
    state.rootActionPlanMatchesByBranch = WipeDecisionDebugMap(state.rootActionPlanMatchesByBranch)
    state.rootActionPlanRecentMismatches = WipeDecisionDebugMap(state.rootActionPlanRecentMismatches)
    state.rootActionPlanLastMismatch = nil
    state.criticalProfileComparisons = 0
    state.criticalProfileMismatches = 0
    state.criticalProfileComparisonsByBranch = WipeDecisionDebugMap(state.criticalProfileComparisonsByBranch)
    state.criticalProfileMismatchesByBranch = WipeDecisionDebugMap(state.criticalProfileMismatchesByBranch)
    state.criticalProfileMismatchesByField = WipeDecisionDebugMap(state.criticalProfileMismatchesByField)
    state.criticalProfileMatchesByProfile = WipeDecisionDebugMap(state.criticalProfileMatchesByProfile)
    state.criticalProfileRecentMismatches = WipeDecisionDebugMap(state.criticalProfileRecentMismatches)
    state.criticalProfileLastMismatch = nil
    state.rootShowDecisionComparisons = 0
    state.rootShowDecisionMismatches = 0
    state.rootShowDecisionMismatchesByAction = WipeDecisionDebugMap(state.rootShowDecisionMismatchesByAction)
    state.rootShowDecisionMismatchesByReason = WipeDecisionDebugMap(state.rootShowDecisionMismatchesByReason)
    state.rootShowDecisionMismatchesByField = WipeDecisionDebugMap(state.rootShowDecisionMismatchesByField)
    state.rootShowDecisionMismatchesByUnit = WipeDecisionDebugMap(state.rootShowDecisionMismatchesByUnit)
    state.rootShowDecisionComparisonsByBranch = WipeDecisionDebugMap(state.rootShowDecisionComparisonsByBranch)
    state.rootShowDecisionMatchesByBranch = WipeDecisionDebugMap(state.rootShowDecisionMatchesByBranch)
    state.rootShowDecisionRecentMismatches = WipeDecisionDebugMap(state.rootShowDecisionRecentMismatches)
    state.rootShowDecisionLastMismatch = nil
    state.combatTransitionTrace = WipeDecisionDebugMap(state.combatTransitionTrace)
    state.combatTransitionSuspicious = WipeDecisionDebugMap(state.combatTransitionSuspicious)
    state.endStateInvariantChecks = 0
    state.endStateInvariantViolations = 0
    state.endStateInvariantByViolation = WipeDecisionDebugMap(state.endStateInvariantByViolation)
    state.endStateInvariantByUnit = WipeDecisionDebugMap(state.endStateInvariantByUnit)
    state.endStateInvariantByMode = WipeDecisionDebugMap(state.endStateInvariantByMode)
    state.endStateInvariantByCombat = WipeDecisionDebugMap(state.endStateInvariantByCombat)
    state.endStateInvariantRecentChecks = WipeDecisionDebugMap(state.endStateInvariantRecentChecks)
    state.endStateInvariantRecent = WipeDecisionDebugMap(state.endStateInvariantRecent)
    state.endStateInvariantFirstNotified = false
    state.blockedIntentNextId = 1
    state.blockedIntentObserved = 0
    state.blockedIntentResolved = 0
    state.blockedIntentExpired = 0
    state.blockedIntentPolicySuppressed = 0
    state.blockedIntentIgnoredNoOp = 0
    state.blockedIntentStillPending = 0
    state.blockedIntentOpen = WipeDecisionDebugMap(state.blockedIntentOpen)
    state.blockedIntentHistory = WipeDecisionDebugMap(state.blockedIntentHistory)
    state.blockedIntentRecentResolved = WipeDecisionDebugMap(state.blockedIntentRecentResolved)
    state.blockedIntentRecentExpired = WipeDecisionDebugMap(state.blockedIntentRecentExpired)
    state.blockedIntentRecentStillPending = WipeDecisionDebugMap(state.blockedIntentRecentStillPending)
    state.blockedIntentByIntent = WipeDecisionDebugMap(state.blockedIntentByIntent)
    state.blockedIntentByUnit = WipeDecisionDebugMap(state.blockedIntentByUnit)
    state.blockedIntentBySource = WipeDecisionDebugMap(state.blockedIntentBySource)
    state.blockedIntentByCombat = WipeDecisionDebugMap(state.blockedIntentByCombat)
    state.blockedIntentBySuppressedReason = WipeDecisionDebugMap(state.blockedIntentBySuppressedReason)
    state.blockedIntentMaxObservations = 0
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

function Visibility.RecordCombatTransition(frame, event, stage, values)
    if not Visibility.IsDecisionDebugEnabled() then
        return nil
    end

    values = type(values) == "table" and values or {}
    local unit = values.unit or frame and frame.unit or nil
    if not IsCombatTransitionUnit(unit) then
        return nil
    end
    if stage == "event-received"
        and type(event) == "string"
        and event ~= ""
        and not COMBAT_TRANSITION_EVENTS[event]
    then
        return nil
    end

    local rootShowDecision = values.rootShowDecision
    local unitWatchDecision = values.unitWatchDecision
    local entry = {
        timestamp = GetTime and GetTime() or 0,
        event = event,
        stage = stage or "unknown",
        unit = unit,
        frameUnit = frame and frame.unit or nil,
        UnitExists = ResolveTraceUnitExists(unit),
        frameExists = frame ~= nil,
        shown = ResolveTraceFrameShown(frame),
        alpha = ResolveTraceFrameAlpha(frame),
        protected = ResolveTraceProtected(frame),
        inCombat = InCombatLockdown and InCombatLockdown() == true or false,
        mode = ResolveTraceMode(frame, values.mode),
        configEnabled = ResolveTraceConfigEnabled(frame, values.config),
        rootDecisionReason = ResolveTraceRootDecisionReason(frame, values),
        rootActionPlanReason = ResolveTraceRootActionPlanReason(frame, values),
        rootShowAction = values.rootShowAction or rootShowDecision and rootShowDecision.action or nil,
        rootShowReason = values.rootShowReason or rootShowDecision and rootShowDecision.reason or nil,
        absentGuard = ResolveTraceAbsentGuard(values),
        unitWatchRegistered = frame and frame._unitWatchRegistered == true or false,
        unitWatchDecisionAction = values.unitWatchDecisionAction or unitWatchDecision and unitWatchDecision.action or nil,
        unitWatchDecisionReason = values.unitWatchDecisionReason or unitWatchDecision and unitWatchDecision.reason or nil,
        refreshReason = values.refreshReason,
        refreshScopes = NormalizeTraceScopes(values.refreshScopes),
        statePhase = values.statePhase or ResolveTraceStatePhase(frame),
        missingSince = values.missingSince or ResolveTraceMissingSince(frame),
        canCallShow = values.canCallShow,
        shouldShow = values.shouldShow,
        shouldSkipShow = values.shouldSkipShow,
        showAttempted = values.showAttempted == true,
        missingHandled = values.missingHandled,
        registeredBefore = values.registeredBefore,
        registeredAfter = values.registeredAfter,
        canRegisterNow = values.canRegisterNow,
        canUnregisterNow = values.canUnregisterNow,
        eventUnit = values.eventUnit,
    }

    local state = EnsureRootActionDebugState(EnsureDecisionDebugState())
    entry.suspicious = IsTraceEntrySuspicious(entry)
    AppendRingEntry(state.combatTransitionTrace, entry, COMBAT_TRANSITION_TRACE_LIMIT)
    if entry.suspicious then
        AppendRingEntry(state.combatTransitionSuspicious, entry, COMBAT_TRANSITION_TRACE_LIMIT)
    end
    return entry
end

local function BumpCounter(map, key)
    key = tostring(key or "unknown")
    map[key] = (tonumber(map[key]) or 0) + 1
end

local function IsEndStateInvariantUnit(unit)
    return type(unit) == "string" and END_STATE_INVARIANT_UNITS[unit] == true
end

local function SafeUnitExists(unit)
    if unit == "player" then
        return true
    end
    if not (UnitExists and type(unit) == "string" and unit ~= "") then
        return false
    end
    local ok, exists = pcall(UnitExists, unit)
    return ok and exists == true or false
end

local function SafeFrameShown(frame)
    if not (frame and frame.IsShown) then
        return false
    end
    local ok, shown = pcall(frame.IsShown, frame)
    return ok and shown == true or false
end

local function SafeFrameAlpha(frame)
    if not (frame and frame.GetAlpha) then
        return nil
    end
    local ok, alpha = pcall(frame.GetAlpha, frame)
    if not ok then
        return nil
    end
    return tonumber(alpha)
end

local function IsActiveRuntimeFrame(frame)
    local unit = frame and frame.unit
    local frames = FocalPoint and FocalPoint.frames or nil
    return type(frames) == "table" and type(unit) == "string" and frames[unit] == frame
end

local function IsPooledFrame(frame)
    local unit = frame and frame.unit
    local pool = FocalPoint and FocalPoint.framePool or nil
    return type(pool) == "table" and type(unit) == "string" and pool[unit] == frame
end

local function IsConfiguredAlphaZero(config)
    return type(config) == "table" and tonumber(config.alpha) ~= nil and tonumber(config.alpha) <= 0
end

local function IsIntentionalRangeAlphaZero(frame, alphaDecision)
    if alphaDecision and alphaDecision.winningSource == "range-fade" and tonumber(alphaDecision.finalAlpha) == 0 then
        return true
    end
    if tonumber(frame and frame._rangeTargetAlpha) == 0 then
        return true
    end
    if tonumber(frame and frame._rangeCurrentAlpha) == 0
        and frame
        and frame.RangeFadeDriver
        and frame.RangeFadeDriver.IsShown
        and frame.RangeFadeDriver:IsShown()
    then
        return true
    end
    return false
end

local function IsUnitWatchResponsible(frame, unitWatchRegistered, mode, protectedRoot, inCombat)
    if unitWatchRegistered ~= true then
        return false
    end
    local UnitWatchPolicy = FocalPoint and FocalPoint.UnitFrameUnitWatchPolicy or nil
    if not (UnitWatchPolicy and UnitWatchPolicy.Resolve) then
        return false
    end

    local resolved = UnitWatchPolicy.Resolve(frame, {
        mode = mode,
        protectedRoot = protectedRoot == true,
        inCombat = inCombat == true,
        previewActive = FocalPoint and (FocalPoint.guiTestModeEnabled == true or FocalPoint.framesUnlocked == true) or false,
    })
    return resolved and resolved.shouldUse == true or false
end

local function ResolveInvariantMode(frame, context)
    context = type(context) == "table" and context or {}
    if type(context.mode) == "string" and context.mode ~= "" then
        return context.mode, context.modeReason
    end
    return ResolveModeReadOnly(frame)
end

local function GetActivePreviewExitReason(frame, mode)
    if mode ~= "live" then
        return nil
    end

    local demoDebug = frame and frame.FocalPointDemoDebug
    local exitCount = tonumber(demoDebug and demoDebug.testModeExitCount)
    if not exitCount or exitCount <= 0 then
        return nil
    end

    if tonumber(demoDebug._visibilityPreviewExitConsumedCount) == exitCount then
        return nil
    end

    return demoDebug.testModeExitReason or "unknown", exitCount
end

local function MarkPreviewExitChecked(frame, result)
    if not result or result.mode ~= "live" then
        return
    end

    local demoDebug = frame and frame.FocalPointDemoDebug
    local exitCount = tonumber(demoDebug and demoDebug.testModeExitCount)
    if not exitCount or exitCount <= 0 then
        return
    end

    demoDebug._visibilityPreviewExitConsumedCount = exitCount
end

local function BuildInvariantResult(frame, context)
    context = type(context) == "table" and context or {}
    local unit = frame and frame.unit or nil
    local config = type(context.config) == "table" and context.config or frame and frame.config or nil
    local mode, modeReason = ResolveInvariantMode(frame, context)
    local configEnabled = type(config) ~= "table" or config.enabled ~= false
    local exists = SafeUnitExists(unit)
    local shown = SafeFrameShown(frame)
    local alpha = SafeFrameAlpha(frame)
    local protectedRoot = frame and frame.IsProtected and frame:IsProtected() or false
    local inCombat = InCombatLockdown and InCombatLockdown() or false
    local unitWatchRegistered = frame and frame._unitWatchRegistered == true or false
    local unitWatchResponsible = IsUnitWatchResponsible(frame, unitWatchRegistered, mode, protectedRoot, inCombat)
    local activeRuntimeFrame = IsActiveRuntimeFrame(frame)
    local pooled = IsPooledFrame(frame)
    local previewExitReason, previewExitCount = GetActivePreviewExitReason(frame, mode)

    local rootDecision = Visibility.ResolveRootDecision and Visibility.ResolveRootDecision(frame, "end-state-invariant", {
        config = config,
        mode = mode,
        modeReason = modeReason,
        unitPresent = exists,
    }) or nil
    local rootShowDecision = Visibility.ResolveRootShowDecision and Visibility.ResolveRootShowDecision(frame, {
        config = config,
        mode = mode,
        modeReason = modeReason,
        unitPresent = exists,
        rootDecision = rootDecision,
    }) or nil
    local rootAlphaDecision = Visibility.ResolveRootAlphaDecision and Visibility.ResolveRootAlphaDecision(frame, {
        source = "end-state-invariant",
        config = config,
        rangeMultiplier = 1,
        missingUnitAlphaGuard = false,
        visibilityOptions = {
            mode = mode,
            modeReason = modeReason,
            unitPresent = exists,
        },
    }) or nil

    local result = {
        ok = true,
        violation = nil,
        unit = unit,
        mode = mode,
        modeReason = modeReason,
        exists = exists,
        shown = shown,
        alpha = alpha,
        configEnabled = configEnabled,
        configuredAlpha = type(config) == "table" and tonumber(config.alpha) or nil,
        unitWatchRegistered = unitWatchRegistered,
        unitWatchResponsible = unitWatchResponsible,
        protected = protectedRoot == true,
        inCombat = inCombat == true,
        activeRuntimeFrame = activeRuntimeFrame == true,
        pooled = pooled == true,
        rootDecisionReason = rootDecision and rootDecision.reason or nil,
        rootShowReason = rootShowDecision and rootShowDecision.reason or nil,
        rootAlphaReason = rootAlphaDecision and (rootAlphaDecision.winningSource or rootAlphaDecision.reason) or nil,
        refreshReason = context.refreshReason,
        refreshScopes = context.refreshScopes,
        checkPoint = context.checkPoint,
        previewExitCount = previewExitCount,
    }

    if not frame or not IsEndStateInvariantUnit(unit) then
        result.skipped = "out-of-scope"
        return result
    end
    if not activeRuntimeFrame or pooled then
        result.skipped = pooled and "pooled" or "inactive-frame"
        return result
    end
    if mode == "disabled" then
        result.skipped = "demo-disabled"
        return result
    end
    if mode == "placeholder" or mode == "detailed" then
        result.skipped = "preview"
        return result
    end
    if not exists and unit ~= "target" then
        result.skipped = "unit-absent"
        return result
    end

    if mode == "live" and configEnabled == false and shown == true then
        result.ok = false
        result.violation = "disabled-visible"
        return result
    end

    if mode ~= "live" or configEnabled ~= true then
        result.skipped = "not-live-enabled"
        return result
    end

    if shown == false and unitWatchResponsible == false then
        result.ok = false
        if unit == "target" then
            result.violation = "target-root-hidden-while-active"
        elseif unit == "targettarget" or unit == "focustarget" then
            result.violation = "derived-present-no-owner"
        elseif IsBossRuntimeUnit and IsBossRuntimeUnit(unit)
            and inCombat
            and protectedRoot
            and unitWatchRegistered == false
        then
            result.violation = "boss-present-no-owner"
        else
            result.violation = "live-present-hidden"
        end
        if previewExitReason then
            result.violation = "preview-exit-stale"
            result.previewExitReason = previewExitReason
            result.previewExitKind = "hidden"
        end
        return result
    end

    if unit == "target" and not exists then
        result.skipped = "target-absent-root-armed"
        return result
    end

    if alpha ~= nil and alpha <= 0 then
        if IsConfiguredAlphaZero(config) then
            result.skipped = "configured-alpha-zero"
            return result
        end
        if IsIntentionalRangeAlphaZero(frame, rootAlphaDecision) then
            result.skipped = "range-alpha-zero"
            return result
        end
        result.ok = false
        result.violation = "live-present-alpha-zero"
        if previewExitReason then
            result.violation = "preview-exit-stale"
            result.previewExitReason = previewExitReason
            result.previewExitKind = "alpha-zero"
        end
        return result
    end

    return result
end

function Visibility.EvaluateEndStateInvariant(frame, context)
    return BuildInvariantResult(frame, context)
end

function Visibility.RecordEndStateInvariant(frame, context)
    if not Visibility.IsDecisionDebugEnabled() then
        return nil
    end

    local result = Visibility.EvaluateEndStateInvariant(frame, context)
    if not result or result.skipped == "out-of-scope" then
        return result
    end

    local state = EnsureRootActionDebugState(EnsureDecisionDebugState())
    state.endStateInvariantChecks = (tonumber(state.endStateInvariantChecks) or 0) + 1
    BumpCounter(state.endStateInvariantByMode, result and result.mode or "unknown")
    BumpCounter(state.endStateInvariantByCombat, result and result.inCombat and "combat" or "no-combat")
    AppendRingEntry(state.endStateInvariantRecentChecks, {
        timestamp = GetTime and GetTime() or 0,
        unit = result.unit,
        ok = result.ok == true,
        violation = result.violation,
        skipped = result.skipped,
        mode = result.mode,
        exists = result.exists == true,
        shown = result.shown == true,
        alpha = result.alpha,
        combat = result.inCombat == true,
        refreshReason = result.refreshReason,
        checkPoint = result.checkPoint,
    }, END_STATE_INVARIANT_CHECK_LIMIT)

    if Visibility.ReconcileBlockedRootIntents then
        Visibility.ReconcileBlockedRootIntents(frame, {
            config = context and context.config,
            refreshReason = result.refreshReason,
            checkPoint = result.checkPoint,
            mode = result.mode,
            modeReason = result.modeReason,
        })
    end

    MarkPreviewExitChecked(frame, result)

    if not result or result.ok ~= false then
        return result
    end

    state.endStateInvariantViolations = (tonumber(state.endStateInvariantViolations) or 0) + 1
    BumpCounter(state.endStateInvariantByViolation, result.violation)
    BumpCounter(state.endStateInvariantByUnit, result.unit)
    AppendRingEntry(state.endStateInvariantRecent, {
        timestamp = GetTime and GetTime() or 0,
        unit = result.unit,
        violation = result.violation,
        exists = result.exists == true,
        shown = result.shown == true,
        alpha = result.alpha,
        combat = result.inCombat == true,
        protected = result.protected == true,
        mode = result.mode,
        configEnabled = result.configEnabled == true,
        configuredAlpha = result.configuredAlpha,
        unitWatchRegistered = result.unitWatchRegistered == true,
        unitWatchResponsible = result.unitWatchResponsible == true,
        rootDecisionReason = result.rootDecisionReason,
        rootShowReason = result.rootShowReason,
        rootAlphaReason = result.rootAlphaReason,
        refreshReason = result.refreshReason,
        checkPoint = result.checkPoint,
        previewExitReason = result.previewExitReason,
    }, END_STATE_INVARIANT_RECENT_LIMIT)

    if Visibility.RecordBlockedRootIntent then
        if result.violation == "live-present-alpha-zero"
            or (
                result.violation == "preview-exit-stale"
                and result.previewExitKind == "alpha-zero"
                and type(result.alpha) == "number"
                and result.alpha <= 0
            )
        then
            Visibility.RecordBlockedRootIntent(frame, {
                intent = "restore-alpha",
                source = "end-state-invariant",
                reason = result.violation,
                refreshReason = result.refreshReason,
                mode = result.mode,
                exists = result.exists,
                shown = result.shown,
                alpha = result.alpha,
                protected = result.protected,
                inCombat = result.inCombat,
                unitWatchRegistered = result.unitWatchRegistered,
                unitWatchResponsible = result.unitWatchResponsible,
                rootDecisionReason = result.rootDecisionReason,
                rootShowReason = result.rootShowReason,
                rootAlphaReason = result.rootAlphaReason,
            })
        elseif result.violation == "live-present-hidden"
            or result.violation == "derived-present-no-owner"
            or result.violation == "boss-present-no-owner"
            or (
                result.violation == "preview-exit-stale"
                and result.previewExitKind == "hidden"
            )
        then
            Visibility.RecordBlockedRootIntent(frame, {
                intent = "show-root",
                source = "end-state-invariant",
                reason = result.violation,
                refreshReason = result.refreshReason,
                mode = result.mode,
                exists = result.exists,
                shown = result.shown,
                alpha = result.alpha,
                protected = result.protected,
                inCombat = result.inCombat,
                unitWatchRegistered = result.unitWatchRegistered,
                unitWatchResponsible = result.unitWatchResponsible,
                rootDecisionReason = result.rootDecisionReason,
                rootShowReason = result.rootShowReason,
                rootAlphaReason = result.rootAlphaReason,
            })
        end
    end

    return result
end

local function BuildBlockedIntentKey(unit, intent, source)
    return table.concat({
        tostring(unit or "unknown"),
        tostring(intent or "unknown"),
        tostring(source or "unknown"),
    }, "|")
end

local function CopyBlockedIntentSnapshot(entry, stateName, extra)
    extra = type(extra) == "table" and extra or {}
    return {
        id = entry and entry.id or nil,
        timestamp = GetTime and GetTime() or 0,
        unit = entry and entry.unit or nil,
        intent = entry and entry.intent or nil,
        state = stateName,
        reason = entry and entry.reason or nil,
        source = entry and entry.source or nil,
        event = entry and entry.event or nil,
        refreshReason = extra.refreshReason or entry and entry.refreshReason or nil,
        firstSeen = entry and entry.firstSeen or nil,
        lastSeen = entry and entry.lastSeen or nil,
        observations = entry and entry.observations or 0,
        combat = extra.inCombat ~= nil and extra.inCombat == true or entry and entry.inCombat == true,
        exists = extra.exists ~= nil and extra.exists == true or entry and entry.exists == true,
        shown = extra.shown ~= nil and extra.shown == true or entry and entry.shown == true,
        alpha = extra.alpha ~= nil and extra.alpha or entry and entry.alpha or nil,
        protected = extra.protected ~= nil and extra.protected == true or entry and entry.protected == true,
        unitWatchRegistered = extra.unitWatchRegistered ~= nil
            and extra.unitWatchRegistered == true
            or entry and entry.unitWatchRegistered == true,
        unitWatchResponsible = extra.unitWatchResponsible ~= nil
            and extra.unitWatchResponsible == true
            or entry and entry.unitWatchResponsible == true,
        rootDecisionReason = extra.rootDecisionReason or entry and entry.rootDecisionReason or nil,
        rootActionReason = extra.rootActionReason or entry and entry.rootActionReason or nil,
        rootShowAction = extra.rootShowAction or entry and entry.rootShowAction or nil,
        rootShowReason = extra.rootShowReason or entry and entry.rootShowReason or nil,
        rootAlphaReason = extra.rootAlphaReason or entry and entry.rootAlphaReason or nil,
        statePhase = extra.statePhase or entry and entry.statePhase or nil,
        resolutionReason = extra.resolutionReason,
        expiredReason = extra.expiredReason,
    }
end

local function ResolveBlockedIntentFrameState(frame, context)
    context = type(context) == "table" and context or {}
    local unit = context.unit or frame and frame.unit or nil
    local mode, modeReason = ResolveInvariantMode(frame, context)
    local exists = SafeUnitExists(unit)
    local shown = SafeFrameShown(frame)
    local alpha = SafeFrameAlpha(frame)
    local protectedRoot = frame and frame.IsProtected and frame:IsProtected() or false
    local inCombat = InCombatLockdown and InCombatLockdown() or false
    local unitWatchRegistered = frame and frame._unitWatchRegistered == true or false
    local unitWatchResponsible = IsUnitWatchResponsible(frame, unitWatchRegistered, mode, protectedRoot, inCombat)
    local config = type(context.config) == "table" and context.config or frame and frame.config or nil
    local configEnabled = type(config) ~= "table" or config.enabled ~= false
    local rootDecision = Visibility.ResolveRootDecision and Visibility.ResolveRootDecision(frame, "blocked-intent", {
        config = config,
        mode = mode,
        modeReason = modeReason,
        unitPresent = exists,
    }) or nil
    local rootAlphaDecision = Visibility.ResolveRootAlphaDecision and Visibility.ResolveRootAlphaDecision(frame, {
        source = "blocked-intent",
        config = config,
        rangeMultiplier = 1,
        missingUnitAlphaGuard = false,
        visibilityOptions = {
            mode = mode,
            modeReason = modeReason,
            unitPresent = exists,
        },
    }) or nil

    return {
        unit = unit,
        mode = mode,
        modeReason = modeReason,
        exists = exists,
        shown = shown,
        alpha = alpha,
        protected = protectedRoot == true,
        inCombat = inCombat == true,
        unitWatchRegistered = unitWatchRegistered,
        unitWatchResponsible = unitWatchResponsible,
        configEnabled = configEnabled,
        activeRuntimeFrame = IsActiveRuntimeFrame(frame),
        pooled = IsPooledFrame(frame),
        rootDecisionReason = rootDecision and rootDecision.reason or nil,
        rootAlphaReason = rootAlphaDecision and (rootAlphaDecision.winningSource or rootAlphaDecision.reason) or nil,
        statePhase = ResolveTraceStatePhase(frame),
    }
end

local function IsBlockedVisibilityIntentRecovered(current)
    if not current then
        return false
    end
    if current.exists ~= true or current.configEnabled == false or current.mode ~= "live" then
        return false
    end
    if type(current.alpha) ~= "number" or current.alpha <= 0 then
        return false
    end
    return current.shown == true or current.unitWatchResponsible == true
end

local function ResolveBlockedIntentFinalState(entry, frame, context)
    local current = ResolveBlockedIntentFrameState(frame, context)

    if not current.activeRuntimeFrame or current.pooled then
        return "expired", "inactive-frame", current
    end
    if current.configEnabled == false then
        return "expired", "unit-disabled", current
    end
    if current.mode == "placeholder" or current.mode == "detailed" or current.mode == "disabled" then
        return "expired", "mode-" .. tostring(current.mode), current
    end

    if entry.intent == "show-root" then
        if current.exists ~= true then
            return "expired", "unit-absent", current
        end
        if IsBlockedVisibilityIntentRecovered(current) then
            return "resolved", current.shown and "shown-alpha-restored" or "unitwatch-responsible-alpha-restored", current
        end
    elseif entry.intent == "hide-root" then
        if current.shown == false then
            return "resolved", "hidden", current
        end
    elseif entry.intent == "register-unitwatch" then
        if current.exists ~= true then
            return "expired", "unit-absent", current
        end
        if IsBlockedVisibilityIntentRecovered(current) then
            return "resolved", "unitwatch-registered-alpha-restored", current
        end
    elseif entry.intent == "unregister-unitwatch" then
        if current.unitWatchRegistered ~= true then
            return "resolved", "unitwatch-unregistered", current
        end
    elseif entry.intent == "restore-alpha" then
        if current.exists ~= true then
            return "expired", "unit-absent", current
        end
        if type(current.alpha) == "number" and current.alpha > 0 then
            return "resolved", "alpha-restored", current
        end
    elseif entry.intent == "apply-layout" then
        if current.exists ~= true then
            return "expired", "unit-absent", current
        end
        if current.inCombat ~= true then
            return "resolved", "left-combat", current
        end
    elseif current.exists ~= true then
        return "expired", "unit-absent", current
    end

    if entry.seenRegen == true and tonumber(entry.observations) and tonumber(entry.observations) >= 2 then
        return "still-pending", "post-combat-reobserved", current
    end
    return "observed", "still-relevant", current
end

local function ResolveFrameForBlockedIntent(unit)
    local frames = FocalPoint and FocalPoint.frames or nil
    if type(frames) == "table" and type(unit) == "string" then
        return frames[unit]
    end
    return nil
end

local function FinalizeBlockedIntent(state, key, entry, finalState, reason, current)
    state.blockedIntentOpen[key] = nil
    entry.state = finalState
    entry.finalReason = reason
    entry.resolvedAt = finalState == "resolved" and (GetTime and GetTime() or 0) or entry.resolvedAt
    entry.expiredAt = finalState == "expired" and (GetTime and GetTime() or 0) or entry.expiredAt

    local snapshot = CopyBlockedIntentSnapshot(entry, finalState, {
        resolutionReason = finalState == "resolved" and reason or nil,
        expiredReason = finalState == "expired" and reason or nil,
        exists = current and current.exists,
        shown = current and current.shown,
        alpha = current and current.alpha,
        inCombat = current and current.inCombat,
        protected = current and current.protected,
        unitWatchRegistered = current and current.unitWatchRegistered,
        unitWatchResponsible = current and current.unitWatchResponsible,
        rootDecisionReason = current and current.rootDecisionReason,
        rootAlphaReason = current and current.rootAlphaReason,
        statePhase = current and current.statePhase,
    })

    if finalState == "resolved" then
        state.blockedIntentResolved = (tonumber(state.blockedIntentResolved) or 0) + 1
        AppendRingEntry(state.blockedIntentRecentResolved, snapshot, BLOCKED_INTENT_RECENT_LIMIT)
    elseif finalState == "expired" then
        state.blockedIntentExpired = (tonumber(state.blockedIntentExpired) or 0) + 1
        AppendRingEntry(state.blockedIntentRecentExpired, snapshot, BLOCKED_INTENT_RECENT_LIMIT)
    end
end

local function UpdateBlockedIntentLifecycleForUnit(state, unit, context)
    if type(state.blockedIntentOpen) ~= "table" or type(unit) ~= "string" then
        return
    end

    for key, entry in pairs(state.blockedIntentOpen) do
        if entry and entry.unit == unit then
            if context
                and (context.event == "PLAYER_REGEN_ENABLED" or context.refreshReason == "PLAYER_REGEN_ENABLED")
            then
                entry.seenRegen = true
            end
            local frame = ResolveFrameForBlockedIntent(unit)
            local finalState, reason, current = ResolveBlockedIntentFinalState(entry, frame, context)
            if finalState == "resolved" or finalState == "expired" then
                FinalizeBlockedIntent(state, key, entry, finalState, reason, current)
            elseif finalState == "still-pending" and entry.state ~= "still-pending" then
                entry.state = "still-pending"
                entry.stillPendingAt = GetTime and GetTime() or 0
                entry.stillPendingReason = reason
                state.blockedIntentStillPending = (tonumber(state.blockedIntentStillPending) or 0) + 1
                AppendRingEntry(
                    state.blockedIntentRecentStillPending,
                    CopyBlockedIntentSnapshot(entry, "still-pending", {
                        resolutionReason = reason,
                        exists = current and current.exists,
                        shown = current and current.shown,
                        alpha = current and current.alpha,
                        inCombat = current and current.inCombat,
                        protected = current and current.protected,
                        unitWatchRegistered = current and current.unitWatchRegistered,
                        unitWatchResponsible = current and current.unitWatchResponsible,
                        rootDecisionReason = current and current.rootDecisionReason,
                        rootAlphaReason = current and current.rootAlphaReason,
                        statePhase = current and current.statePhase,
                    }),
                    BLOCKED_INTENT_RECENT_LIMIT
                )
            end
        end
    end
end

local function SuppressBlockedIntentObservation(state, reason, policySuppressed)
    if policySuppressed == true then
        state.blockedIntentPolicySuppressed = (tonumber(state.blockedIntentPolicySuppressed) or 0) + 1
    else
        state.blockedIntentIgnoredNoOp = (tonumber(state.blockedIntentIgnoredNoOp) or 0) + 1
    end
    BumpCounter(state.blockedIntentBySuppressedReason, reason)
end

local function ShouldSuppressBlockedIntentObservation(unit, intent, source, reason, current)
    if intent == "hide-root" and unit == "target" and reason == "target-hide-suppressed" then
        if current and current.exists == false and type(current.alpha) == "number" and current.alpha <= 0 then
            return true, "target-hide-resolved-by-alpha", true
        end
        return true, "target-hide-policy", true
    end

    if intent == "show-root" then
        if current and current.shown == true then
            return true, "already-shown", false
        end
        if current and current.unitWatchResponsible == true then
            return true, "unitwatch-responsible", false
        end
    elseif intent == "restore-alpha" then
        if current and type(current.alpha) == "number" and current.alpha > 0 then
            return true, "alpha-already-restored", false
        end
    elseif intent == "hide-root" then
        if current and current.shown == false then
            return true, "already-hidden", false
        end
    end

    return false, nil, false
end

function Visibility.RecordBlockedRootIntent(frame, values)
    if not Visibility.IsDecisionDebugEnabled() then
        return nil
    end

    values = type(values) == "table" and values or {}
    local unit = values.unit or frame and frame.unit or nil
    if not IsEndStateInvariantUnit(unit) then
        return nil
    end

    local intent = tostring(values.intent or "")
    if intent == "" then
        return nil
    end

    local source = tostring(values.source or "unknown")
    local key = BuildBlockedIntentKey(unit, intent, source)
    local state = EnsureRootActionDebugState(EnsureDecisionDebugState())
    local now = GetTime and GetTime() or 0
    local entry = state.blockedIntentOpen[key]
    local current = ResolveBlockedIntentFrameState(frame, values)
    local shouldSuppress, suppressReason, policySuppressed = ShouldSuppressBlockedIntentObservation(
        unit,
        intent,
        source,
        values.reason,
        current
    )
    if shouldSuppress then
        SuppressBlockedIntentObservation(state, suppressReason, policySuppressed)
        UpdateBlockedIntentLifecycleForUnit(state, unit, values)
        return nil
    end

    if entry then
        entry.state = entry.state == "still-pending" and "still-pending" or "reobserved"
        entry.lastSeen = now
        entry.observations = (tonumber(entry.observations) or 0) + 1
        entry.reason = values.reason or entry.reason
        entry.event = values.event or entry.event
        entry.refreshReason = values.refreshReason or entry.refreshReason
    else
        entry = {
            id = state.blockedIntentNextId,
            key = key,
            unit = unit,
            intent = intent,
            state = "observed",
            reason = values.reason,
            source = source,
            event = values.event,
            refreshReason = values.refreshReason,
            firstSeen = now,
            lastSeen = now,
            observations = 1,
        }
        state.blockedIntentNextId = (tonumber(state.blockedIntentNextId) or 1) + 1
        state.blockedIntentOpen[key] = entry
        state.blockedIntentObserved = (tonumber(state.blockedIntentObserved) or 0) + 1
        BumpCounter(state.blockedIntentByIntent, intent)
        BumpCounter(state.blockedIntentByUnit, unit)
        BumpCounter(state.blockedIntentBySource, source)
    end

    entry.mode = values.mode or current.mode
    entry.exists = values.exists ~= nil and values.exists == true or current.exists == true
    entry.shown = values.shown ~= nil and values.shown == true or current.shown == true
    entry.alpha = values.alpha ~= nil and values.alpha or current.alpha
    entry.protected = values.protected ~= nil and values.protected == true or current.protected == true
    entry.inCombat = values.inCombat ~= nil and values.inCombat == true or current.inCombat == true
    entry.unitWatchRegistered = values.unitWatchRegistered ~= nil
        and values.unitWatchRegistered == true
        or current.unitWatchRegistered == true
    entry.unitWatchResponsible = values.unitWatchResponsible ~= nil
        and values.unitWatchResponsible == true
        or current.unitWatchResponsible == true
    entry.rootDecisionReason = values.rootDecisionReason or current.rootDecisionReason
    entry.rootActionReason = values.rootActionReason or entry.rootActionReason
    entry.rootShowAction = values.rootShowAction or entry.rootShowAction
    entry.rootShowReason = values.rootShowReason or entry.rootShowReason
    entry.rootAlphaReason = values.rootAlphaReason or current.rootAlphaReason
    entry.statePhase = values.statePhase or current.statePhase
    entry.seenRegen = entry.seenRegen
        or values.event == "PLAYER_REGEN_ENABLED"
        or values.refreshReason == "PLAYER_REGEN_ENABLED"
    state.blockedIntentMaxObservations = math.max(
        tonumber(state.blockedIntentMaxObservations) or 0,
        tonumber(entry.observations) or 0
    )
    BumpCounter(state.blockedIntentByCombat, entry.inCombat and "combat" or "no-combat")
    AppendRingEntry(state.blockedIntentHistory, CopyBlockedIntentSnapshot(entry, entry.state), BLOCKED_INTENT_HISTORY_LIMIT)

    UpdateBlockedIntentLifecycleForUnit(state, unit, values)
    return entry
end

function Visibility.ReconcileBlockedRootIntents(frame, context)
    if not Visibility.IsDecisionDebugEnabled() then
        return
    end

    local unit = frame and frame.unit or context and context.unit or nil
    if not IsEndStateInvariantUnit(unit) then
        return
    end

    local state = EnsureRootActionDebugState(EnsureDecisionDebugState())
    UpdateBlockedIntentLifecycleForUnit(state, unit, context)
end

local ROOT_SHOW_REASON_ALIASES = {
    ["live-present"] = "live-present-show",
    ["live-present-show"] = "live-present-show",
    ["live-local-show"] = "live-local-show",
    ["preview-detailed"] = "preview-detailed-show",
    ["preview-detailed-show"] = "preview-detailed-show",
    ["unlock-selected-detailed"] = "preview-detailed-show",
    ["global-demo-detailed"] = "preview-detailed-show",
    ["preview-placeholder"] = "preview-placeholder-show",
    ["preview-placeholder-show"] = "preview-placeholder-show",
    ["unlock-placeholder"] = "preview-placeholder-show",
    ["unlock-disabled-placeholder"] = "preview-placeholder-show",
    ["absent-target"] = "absent-target",
    ["absent-targettarget"] = "absent-targettarget",
    ["absent-focustarget"] = "absent-focustarget",
    ["absent-boss"] = "absent-boss",
    ["protected-combat-keep"] = "protected-combat-keep",
    ["live-protected-combat-keep"] = "protected-combat-keep",
    ["preview-protected-combat-keep"] = "protected-combat-keep",
    ["demo-disabled-return"] = "demo-disabled-return",
    ["demo-filtered-return"] = "demo-filtered-return",
    ["missing-handled-return"] = "missing-handled-return",
    ["disabled-live-return"] = "disabled-live-return",
    ["invalid-frame"] = "invalid-frame",
    ["invalid-config"] = "invalid-config",
    ["refresh-not-reached"] = "refresh-not-reached",
}

local ROOT_SHOW_BRANCH_ORDER = {
    "preview-detailed",
    "preview-placeholder",
    "live-present",
    "absent-target",
    "absent-targettarget",
    "absent-focustarget",
    "absent-boss",
    "protected-combat-keep",
    "demo-disabled-return",
    "demo-filtered-return",
}

local function NormalizeRootShowReason(reason)
    local value = tostring(reason or "unknown")
    return ROOT_SHOW_REASON_ALIASES[value] or value
end

local ROOT_SHOW_COMPARE_FIELDS = {
    { key = "action", label = "action" },
    { key = "reason", label = "reason", reason = true },
    { key = "shouldShow", label = "shouldShow", boolean = true },
    { key = "shouldSkipShow", label = "shouldSkipShow", boolean = true },
    { key = "mode", label = "mode" },
    { key = "previewActive", label = "previewActive", boolean = true },
    { key = "unitPresent", label = "unitPresent", boolean = true },
    { key = "protectedRoot", label = "protectedRoot", boolean = true },
    { key = "inCombat", label = "inCombat", boolean = true },
    { key = "absentTargetGuard", label = "absentTargetGuard", boolean = true },
    { key = "absentTargetTargetGuard", label = "absentTargetTargetGuard", boolean = true },
    { key = "absentFocusTargetGuard", label = "absentFocusTargetGuard", boolean = true },
    { key = "absentBossGuard", label = "absentBossGuard", boolean = true },
    { key = "canCallShow", label = "canCallShow", boolean = true },
    { key = "missingHandled", label = "missingHandled", boolean = true },
    { key = "refreshApplyReached", label = "refreshApplyReached", boolean = true },
}

local function NormalizeRootShowCompareValue(field, value)
    if field and field.reason == true then
        return NormalizeRootShowReason(value)
    end
    if field and field.boolean == true then
        return value == true
    end
    return value
end

local function CompareLegacyToRootShowDecision(legacy, decision)
    local mismatches = {}
    for _, field in ipairs(ROOT_SHOW_COMPARE_FIELDS) do
        local legacyValue = NormalizeRootShowCompareValue(field, legacy and legacy[field.key])
        local decisionValue = NormalizeRootShowCompareValue(field, decision and decision[field.key])
        if legacyValue ~= decisionValue then
            mismatches[#mismatches + 1] = {
                field = field.label,
                legacyValue = legacy and legacy[field.key],
                decisionValue = decision and decision[field.key],
            }
        end
    end
    return mismatches
end

local ROOT_ACTION_REASON_ALIASES = {
    ["target-missing-transition"] = "target_missing_transition",
    ["missing-target-transition"] = "target_missing_transition",
    ["preview-disabled"] = "preview_disabled",
    ["preview-disabled-unit"] = "preview_disabled",
    ["disabled-preview"] = "preview_disabled",
    ["force-visible"] = "force_visible",
    ["forced-visible"] = "force_visible",
    ["preview-active"] = "preview_active",
    ["unit-present"] = "unit_present",
    ["live-present"] = "unit_present",
    ["missing-unit"] = "missing_unit",
    ["missing_unit"] = "missing_unit",
    ["missing-unit-suppressed"] = "missing_unit_suppressed",
    ["missing_unit_suppressed"] = "missing_unit_suppressed",
    ["missing-unit-protected"] = "missing_unit_protected",
    ["missing_unit_protected"] = "missing_unit_protected",
    ["missing-unit-protected-suppressed"] = "missing_unit_protected_suppressed",
    ["missing_unit_protected_suppressed"] = "missing_unit_protected_suppressed",
    ["special-mode"] = "special_mode",
    ["special_mode"] = "special_mode",
}

local function NormalizeRootActionReason(reason, specialModeActive)
    local value = tostring(reason or "unknown")
    if specialModeActive == true then
        return "special_mode"
    end
    return ROOT_ACTION_REASON_ALIASES[value] or value
end

local function BuildLegacyRootActionTrace(frame, branch, values)
    values = type(values) == "table" and values or {}
    return {
        branch = branch or "not-handled",
        clearAction = values.clearAction or "none",
        alphaAction = values.alphaAction or "keep",
        mouseAction = values.mouseAction or "keep",
        rootAction = values.rootAction or "keep",
        stateAction = values.stateAction or "none",
        recoveryAction = values.recoveryAction or "none",
        shouldReturn = values.shouldReturn == true,
        unit = values.unit or frame and frame.unit or nil,
        unitPresent = values.unitPresent == true,
        previewActive = values.previewActive == true,
        forceVisible = values.forceVisible == true,
        specialModeActive = values.specialModeActive == true,
        protectedRoot = values.protectedRoot == true,
        inCombat = values.inCombat == true,
        missingSuppressed = values.missingSuppressed == true,
        targetTransition = values.targetTransition == true,
        suspiciousMissingTarget = values.suspiciousMissingTarget == true,
        legacyClearRequested = values.legacyClearRequested or values.clearAction or "none",
        legacyAlphaRequested = values.legacyAlphaRequested or values.alphaAction or "keep",
        legacyMouseRequested = values.legacyMouseRequested or values.mouseAction or "keep",
        legacyRootActionRequested = values.legacyRootActionRequested or values.rootAction or "keep",
        legacyStateRequested = values.legacyStateRequested or values.stateAction or "none",
        legacyRecoveryRequested = values.legacyRecoveryRequested or values.recoveryAction or "none",
        legacyCanHideRoot = values.legacyCanHideRoot == true,
        legacyProtectedInCombat = values.legacyProtectedInCombat == true,
        legacyClearMode = values.legacyClearMode or values.clearAction or "none",
        legacyRecoveryReason = values.legacyRecoveryReason,
    }
end

local function BuildLegacyRootActionTraceFromPlan(frame, plan, branch, values)
    values = type(values) == "table" and values or {}
    return BuildLegacyRootActionTrace(frame, branch, {
        clearAction = values.clearAction,
        alphaAction = values.alphaAction,
        mouseAction = values.mouseAction,
        rootAction = values.rootAction,
        stateAction = values.stateAction,
        recoveryAction = values.recoveryAction,
        shouldReturn = values.shouldReturn,
        unit = plan and plan.unit or nil,
        unitPresent = plan and plan.unitPresent == true or false,
        previewActive = plan and plan.previewActive == true or false,
        forceVisible = plan and plan.forceVisible == true or false,
        specialModeActive = plan and plan.specialModeActive == true or false,
        protectedRoot = plan and plan.protectedRoot == true or false,
        inCombat = plan and plan.inCombat == true or false,
        missingSuppressed = plan and plan.missingSuppressed == true or false,
        targetTransition = values.targetTransition or plan and plan.targetTransition == true or false,
        suspiciousMissingTarget = values.suspiciousMissingTarget or plan and plan.suspiciousMissingTarget == true or false,
        legacyClearRequested = values.legacyClearRequested,
        legacyAlphaRequested = values.legacyAlphaRequested,
        legacyMouseRequested = values.legacyMouseRequested,
        legacyRootActionRequested = values.legacyRootActionRequested,
        legacyStateRequested = values.legacyStateRequested,
        legacyRecoveryRequested = values.legacyRecoveryRequested,
        legacyCanHideRoot = values.legacyCanHideRoot or plan and plan.rootActionPossible == true or false,
        legacyProtectedInCombat = values.legacyProtectedInCombat or plan and plan.protectedInCombat == true or false,
        legacyClearMode = values.legacyClearMode,
        legacyRecoveryReason = values.legacyRecoveryReason,
    })
end

local ROOT_ACTION_COMPARE_FIELDS = {
    { key = "clearAction", label = "clearAction" },
    { key = "alphaAction", label = "alphaAction" },
    { key = "mouseAction", label = "mouseAction" },
    { key = "rootAction", label = "rootAction" },
    { key = "stateAction", label = "stateAction" },
    { key = "recoveryAction", label = "recoveryAction" },
    { key = "shouldReturn", label = "shouldReturn", boolean = true },
    { key = "unitPresent", label = "unitPresent", boolean = true },
    { key = "previewActive", label = "previewActive", boolean = true },
    { key = "forceVisible", label = "forceVisible", boolean = true },
    { key = "specialModeActive", label = "specialModeActive", boolean = true },
    { key = "protectedRoot", label = "protectedRoot", boolean = true },
    { key = "inCombat", label = "inCombat", boolean = true },
    { key = "missingSuppressed", label = "missingSuppressed", boolean = true },
    { key = "targetTransition", label = "targetTransition", boolean = true },
    { key = "suspiciousMissingTarget", label = "suspiciousMissingTarget", boolean = true },
}

local function NormalizeRootActionCompareValue(field, value)
    if field and field.boolean == true then
        return value == true
    end
    return value
end

local function CompareLegacyToRootActionPlan(legacy, plan)
    local mismatches = {}
    local legacyReason = NormalizeRootActionReason(legacy and legacy.branch, legacy and legacy.specialModeActive)
    local planReason = NormalizeRootActionReason(plan and plan.reason, plan and plan.specialModeActive)

    if legacyReason ~= planReason then
        mismatches[#mismatches + 1] = {
            field = "reason",
            legacyValue = legacy and legacy.branch,
            planValue = plan and plan.reason,
        }
    end

    for _, field in ipairs(ROOT_ACTION_COMPARE_FIELDS) do
        local legacyValue = NormalizeRootActionCompareValue(field, legacy and legacy[field.key])
        local planValue = NormalizeRootActionCompareValue(field, plan and plan[field.key])
        if legacyValue ~= planValue then
            mismatches[#mismatches + 1] = {
                field = field.label,
                legacyValue = legacyValue,
                planValue = planValue,
            }
        end
    end

    return mismatches, legacyReason, planReason
end

local CRITICAL_PROFILE_ORDER = {
    "protected-target-missing",
    "protected-target-missing-in-combat",
    "protected-boss-missing",
    "target-transition",
    "missing-suppressed",
    "normal-missing-final",
}

local CRITICAL_BRANCHES = {
    missing_unit_protected = true,
    missing_unit_protected_suppressed = true,
    target_missing_transition = true,
    missing_unit_suppressed = true,
    missing_unit = true,
}

local function IsCriticalRootActionBranch(branch)
    local normalized = NormalizeRootActionReason(branch)
    return CRITICAL_BRANCHES[normalized] == true
end

local function ResolveCriticalProfile(legacy, plan)
    local branch = NormalizeRootActionReason(legacy and legacy.branch)
    local unit = legacy and legacy.unit or plan and plan.unit
    local isBoss = IsBossRuntimeUnit and IsBossRuntimeUnit(unit) or false

    if branch == "target_missing_transition" then
        return "target-transition"
    end

    if branch == "missing_unit_protected" or branch == "missing_unit_protected_suppressed" then
        if isBoss then
            return "protected-boss-missing"
        end
        if unit == "target" and ((legacy and legacy.inCombat == true) or (plan and plan.inCombat == true)) then
            return "protected-target-missing-in-combat"
        end
        if unit == "target" then
            return "protected-target-missing"
        end
        return "protected-missing"
    end

    if branch == "missing_unit_suppressed" then
        return "missing-suppressed"
    end

    if branch == "missing_unit" then
        return "normal-missing-final"
    end

    return nil
end

local function ResolveExpectedCriticalClearMode(legacy)
    if not legacy then
        return "none"
    end
    if legacy.branch == "target_missing_transition" then
        return "content-only"
    end
    if legacy.protectedRoot and legacy.inCombat and legacy.branch == "missing_unit_protected" then
        return "content-only"
    end
    if IsBossRuntimeUnit and IsBossRuntimeUnit(legacy.unit) then
        return "content-only"
    end
    return "hard"
end

local CRITICAL_COMPARE_FIELDS = {
    { key = "clearAction", planKey = "clearAction", label = "clearAction" },
    { key = "alphaAction", planKey = "alphaAction", label = "alphaAction" },
    { key = "mouseAction", planKey = "mouseAction", label = "mouseAction" },
    { key = "rootAction", planKey = "rootAction", label = "rootAction" },
    { key = "stateAction", planKey = "stateAction", label = "stateAction" },
    { key = "recoveryAction", planKey = "recoveryAction", label = "recoveryAction" },
    { key = "shouldReturn", planKey = "shouldReturn", label = "shouldReturn", boolean = true },
    { key = "legacyClearMode", planKey = "stateClearMode", label = "clearMode" },
    { key = "legacyRecoveryReason", planKey = "recoveryReason", label = "recoveryReason" },
    { key = "legacyCanHideRoot", planKey = "rootActionPossible", label = "canHideRoot", boolean = true },
    { key = "legacyProtectedInCombat", planKey = "protectedInCombat", label = "protectedInCombat", boolean = true },
}

local function CompareCriticalProfile(legacy, plan)
    if not IsCriticalRootActionBranch(legacy and legacy.branch) then
        return nil
    end

    local mismatches = {}
    local profile = ResolveCriticalProfile(legacy, plan) or "unknown-critical"
    local expectedClearMode = ResolveExpectedCriticalClearMode(legacy)
    legacy.legacyClearMode = legacy.legacyClearMode or expectedClearMode

    if plan and plan.stateClearMode ~= nil and plan.stateClearMode ~= expectedClearMode then
        mismatches[#mismatches + 1] = {
            field = "expectedClearMode",
            legacyValue = expectedClearMode,
            planValue = plan.stateClearMode,
        }
    end

    for _, field in ipairs(CRITICAL_COMPARE_FIELDS) do
        local legacyValue = NormalizeRootActionCompareValue(field, legacy and legacy[field.key])
        local planValue = NormalizeRootActionCompareValue(field, plan and plan[field.planKey])
        if legacyValue ~= planValue then
            mismatches[#mismatches + 1] = {
                field = field.label,
                legacyValue = legacyValue,
                planValue = planValue,
            }
        end
    end

    return {
        profile = profile,
        branch = NormalizeRootActionReason(legacy and legacy.branch),
        mismatches = mismatches,
    }
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
    local legacyPreview = legacy.outcome == "preview"
    local decisionPreview = decision.mode == "detailed"
        or decision.mode == "placeholder"
        or decision.reason == "unlock-placeholder"
        or decision.reason == "demo-detailed"

    Add("missing", legacyMissing, decisionMissing)
    if not (legacyPreview and decisionPreview) then
        Add("forceVisible", legacy.forceVisible == true, decision.forceVisible == true)
    end
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

local function FormatRootActionMismatchList(entry)
    local parts = {}
    for _, mismatch in ipairs(entry and entry.mismatches or {}) do
        parts[#parts + 1] = string.format(
            "%s=%s/%s",
            tostring(mismatch.field),
            tostring(mismatch.legacyValue),
            tostring(mismatch.planValue)
        )
    end
    if #parts == 0 then
        return "none"
    end
    return table.concat(parts, ",")
end

local function AppendCriticalProfileCoverage(lines, state)
    lines[#lines + 1] = "Critical Profile coverage:"
    for _, profile in ipairs(CRITICAL_PROFILE_ORDER) do
        local count = tonumber(state.criticalProfileMatchesByProfile and state.criticalProfileMatchesByProfile[profile]) or 0
        lines[#lines + 1] = string.format("  %s: %d", profile, count)
    end
end

local function AppendRootShowBranchCoverage(lines, state)
    lines[#lines + 1] = "Root Show Decision comparisons by branch:"
    for _, branch in ipairs(ROOT_SHOW_BRANCH_ORDER) do
        local count = tonumber(state.rootShowDecisionComparisonsByBranch and state.rootShowDecisionComparisonsByBranch[branch]) or 0
        lines[#lines + 1] = string.format("  %s: %d", branch, count)
    end
end

local function FormatCriticalMismatchList(entry)
    local parts = {}
    for _, mismatch in ipairs(entry and entry.mismatches or {}) do
        parts[#parts + 1] = string.format(
            "%s=%s/%s",
            tostring(mismatch.field),
            tostring(mismatch.legacyValue),
            tostring(mismatch.planValue)
        )
    end
    if #parts == 0 then
        return "none"
    end
    return table.concat(parts, ",")
end

local function RecordRootActionPlanComparison(frame, plan, legacy)
    if not Visibility.IsDecisionDebugEnabled() then
        return
    end
    if not plan or not legacy then
        return
    end

    local state = EnsureRootActionDebugState(EnsureDecisionDebugState())
    local mismatches, legacyReason, planReason = CompareLegacyToRootActionPlan(legacy, plan)
    local unit = tostring(legacy.unit or plan.unit or "unknown")

    state.rootActionPlanComparisons = (tonumber(state.rootActionPlanComparisons) or 0) + 1

    local critical = CompareCriticalProfile(legacy, plan)
    if critical then
        state.criticalProfileComparisons = (tonumber(state.criticalProfileComparisons) or 0) + 1
        BumpCounter(state.criticalProfileComparisonsByBranch, critical.branch)
        if #critical.mismatches == 0 then
            BumpCounter(state.criticalProfileMatchesByProfile, critical.profile)
        else
            state.criticalProfileMismatches = (tonumber(state.criticalProfileMismatches) or 0) + 1
            BumpCounter(state.criticalProfileMismatchesByBranch, critical.branch)
            for _, mismatch in ipairs(critical.mismatches) do
                BumpCounter(state.criticalProfileMismatchesByField, mismatch.field)
            end

            local criticalEntry = {
                unit = unit,
                profile = critical.profile,
                branch = critical.branch,
                legacy = legacy,
                plan = plan,
                mismatches = critical.mismatches,
            }
            state.criticalProfileLastMismatch = criticalEntry
            local criticalRecent = state.criticalProfileRecentMismatches
            criticalRecent[#criticalRecent + 1] = criticalEntry
            while #criticalRecent > MAX_ROOT_ACTION_PLAN_MISMATCHES do
                table.remove(criticalRecent, 1)
            end
        end
    end

    if #mismatches == 0 then
        BumpCounter(state.rootActionPlanMatchesByBranch, legacyReason)
        return
    end

    state.rootActionPlanMismatches = (tonumber(state.rootActionPlanMismatches) or 0) + 1
    BumpCounter(state.rootActionPlanMismatchesByBranch, legacyReason .. "->" .. planReason)
    BumpCounter(state.rootActionPlanMismatchesByUnit, unit)
    for _, mismatch in ipairs(mismatches) do
        BumpCounter(state.rootActionPlanMismatchesByField, mismatch.field)
    end

    local entry = {
        unit = unit,
        legacyBranch = legacy.branch,
        planReason = plan.reason,
        legacyReason = legacyReason,
        normalizedPlanReason = planReason,
        combat = legacy.inCombat == true,
        protected = legacy.protectedRoot == true,
        preview = legacy.previewActive == true,
        missingSuppressed = legacy.missingSuppressed == true,
        targetTransition = legacy.targetTransition == true,
        legacy = legacy,
        plan = plan,
        mismatches = mismatches,
    }

    state.rootActionPlanLastMismatch = entry
    local recent = state.rootActionPlanRecentMismatches
    recent[#recent + 1] = entry
    while #recent > MAX_ROOT_ACTION_PLAN_MISMATCHES do
        table.remove(recent, 1)
    end
end

function Visibility.RecordRootShowDecisionComparison(frame, legacy, decision)
    if not Visibility.IsDecisionDebugEnabled() then
        return
    end
    if not legacy or not decision then
        return
    end

    local state = EnsureRootActionDebugState(EnsureDecisionDebugState())
    local mismatches = CompareLegacyToRootShowDecision(legacy, decision)
    local unit = tostring(legacy.unit or decision.unit or frame and frame.unit or "unknown")
    local legacyBranch = tostring(legacy.branch or legacy.reason or "unknown")
    local legacyReason = NormalizeRootShowReason(legacy.reason or legacy.branch)
    local decisionReason = NormalizeRootShowReason(decision.reason)

    state.rootShowDecisionComparisons = (tonumber(state.rootShowDecisionComparisons) or 0) + 1
    BumpCounter(state.rootShowDecisionComparisonsByBranch, legacyBranch)

    if #mismatches == 0 then
        BumpCounter(state.rootShowDecisionMatchesByBranch, legacyBranch)
        return
    end

    state.rootShowDecisionMismatches = (tonumber(state.rootShowDecisionMismatches) or 0) + 1
    BumpCounter(state.rootShowDecisionMismatchesByAction, tostring(legacy.action or "?") .. "->" .. tostring(decision.action or "?"))
    BumpCounter(state.rootShowDecisionMismatchesByReason, legacyReason .. "->" .. decisionReason)
    BumpCounter(state.rootShowDecisionMismatchesByUnit, unit)
    for _, mismatch in ipairs(mismatches) do
        BumpCounter(state.rootShowDecisionMismatchesByField, mismatch.field)
    end

    local entry = {
        unit = unit,
        legacyBranch = legacyBranch,
        legacyReason = legacy.reason,
        decisionReason = decision.reason,
        legacyAction = legacy.action,
        decisionAction = decision.action,
        legacyShow = legacy.shouldShow == true,
        decisionShow = decision.shouldShow == true,
        legacySkipShow = legacy.shouldSkipShow == true,
        decisionSkipShow = decision.shouldSkipShow == true,
        mode = decision.mode or legacy.mode,
        preview = decision.previewActive == true,
        unitPresent = decision.unitPresent == true,
        protected = decision.protectedRoot == true,
        combat = decision.inCombat == true,
        legacy = legacy,
        decision = decision,
        mismatches = mismatches,
    }

    state.rootShowDecisionLastMismatch = entry
    local recent = state.rootShowDecisionRecentMismatches
    recent[#recent + 1] = entry
    while #recent > MAX_DECISION_DEBUG_MISMATCHES do
        table.remove(recent, 1)
    end
end

local function IsRootActionPlanValue(plan, expectedReason, expected)
    if type(plan) ~= "table" or type(expected) ~= "table" then
        return false
    end

    local planReason = NormalizeRootActionReason(plan.reason, plan.specialModeActive)
    if planReason ~= expectedReason then
        return false
    end

    return plan.clearAction == expected.clearAction
        and plan.alphaAction == expected.alphaAction
        and plan.mouseAction == expected.mouseAction
        and plan.rootAction == expected.rootAction
        and plan.stateAction == expected.stateAction
        and plan.recoveryAction == expected.recoveryAction
        and plan.shouldReturn == expected.shouldReturn
end

local function IsMissingUnitProtectedActionPlanValue(plan, expected)
    if not IsRootActionPlanValue(plan, "missing_unit_protected", expected) then
        return false
    end
    if plan.stateReason ~= "missing_unit_protected" then
        return false
    end
    if plan.stateClearMode ~= expected.clearAction then
        return false
    end
    if plan.rootActionPossible ~= expected.rootActionPossible then
        return false
    end
    if plan.recoveryAction == "queue-refresh" and plan.recoveryReason ~= "visibility" then
        return false
    end
    if plan.recoveryAction ~= "none" and plan.recoveryAction ~= "queue-refresh" then
        return false
    end
    return true
end

local function ApplyRootActionPlan(frame, plan)
    if not frame or type(plan) ~= "table" then
        return false
    end
    if plan.recoveryAction ~= "none" then
        return false
    end

    if plan.stateAction == "clear-missing" then
        frame._missingUnitSince = nil
    elseif plan.stateAction == "unit-lost" then
        if State.HandleUnitLost then
            State.HandleUnitLost(frame, plan.reason or "unit_lost")
        else
            Visibility.ClearFrameVisualState(frame, plan.reason or "unit_lost")
        end
    elseif plan.stateAction ~= "none" then
        return false
    end

    if plan.clearAction == "content-only" then
        if Visibility.ClearFrameContentValuesOnly then
            Visibility.ClearFrameContentValuesOnly(frame, plan.reason)
        end
    elseif plan.clearAction == "hard" then
        -- Hard clear for unit-lost branches is performed by State.HandleUnitLost above.
    elseif plan.clearAction ~= "none" then
        return false
    end

    if plan.alphaAction == "zero" then
        if frame.SetAlpha then
            frame:SetAlpha(0)
        end
    elseif plan.alphaAction ~= "keep" then
        return false
    end

    if plan.mouseAction == "disable" then
        if frame.EnableMouse then
            frame:EnableMouse(false)
        end
        if frame.SetMouseClickEnabled then
            frame:SetMouseClickEnabled(false)
        end
    elseif plan.mouseAction ~= "keep" then
        return false
    end

    if plan.rootAction == "hide-if-safe" then
        HideFrameIfSafe(frame, {
            reason = plan.reason,
            source = "root-action-plan",
        })
    elseif plan.rootAction ~= "keep" then
        return false
    end

    return true
end

local function ApplyMissingUnitProtectedActionPlan(frame, plan)
    if not frame or type(plan) ~= "table" then
        return false
    end
    if plan.reason ~= "missing_unit_protected" then
        return false
    end
    if plan.stateAction ~= "unit-lost" or plan.stateReason ~= "missing_unit_protected" then
        return false
    end
    if plan.recoveryAction ~= "none" and plan.recoveryAction ~= "queue-refresh" then
        return false
    end
    if plan.recoveryAction == "queue-refresh" and plan.recoveryReason ~= "visibility" then
        return false
    end

    if State.HandleUnitLost then
        State.HandleUnitLost(frame, "missing_unit_protected")
    else
        Visibility.ClearFrameVisualState(frame, "missing_unit_protected")
    end

    if plan.recoveryAction == "queue-refresh" then
        Visibility.QueueRefresh(frame)
    end

    HideFrameIfSafe(frame, {
        reason = plan.reason,
        source = "missing-unit-protected-plan",
    })
    return true
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

local function FormatRootShowMismatchList(entry)
    local parts = {}
    for _, mismatch in ipairs(entry and entry.mismatches or {}) do
        parts[#parts + 1] = string.format(
            "%s=%s/%s",
            tostring(mismatch.field),
            tostring(mismatch.legacyValue),
            tostring(mismatch.decisionValue)
        )
    end
    if #parts == 0 then
        return "none"
    end
    return table.concat(parts, ",")
end

function Visibility.GetDecisionDebugStatus()
    local state = EnsureDecisionDebugState()
    EnsureRootActionDebugState(state)
    return {
        enabled = state.enabled == true,
        totalComparisons = tonumber(state.totalComparisons) or 0,
        totalMismatches = tonumber(state.totalMismatches) or 0,
        rootActionPlanComparisons = tonumber(state.rootActionPlanComparisons) or 0,
        rootActionPlanMismatches = tonumber(state.rootActionPlanMismatches) or 0,
        criticalProfileComparisons = tonumber(state.criticalProfileComparisons) or 0,
        criticalProfileMismatches = tonumber(state.criticalProfileMismatches) or 0,
        rootShowDecisionComparisons = tonumber(state.rootShowDecisionComparisons) or 0,
        rootShowDecisionMismatches = tonumber(state.rootShowDecisionMismatches) or 0,
        endStateInvariantChecks = tonumber(state.endStateInvariantChecks) or 0,
        endStateInvariantViolations = tonumber(state.endStateInvariantViolations) or 0,
        blockedIntentObserved = tonumber(state.blockedIntentObserved) or 0,
        blockedIntentResolved = tonumber(state.blockedIntentResolved) or 0,
        blockedIntentExpired = tonumber(state.blockedIntentExpired) or 0,
        blockedIntentPolicySuppressed = tonumber(state.blockedIntentPolicySuppressed) or 0,
        blockedIntentIgnoredNoOp = tonumber(state.blockedIntentIgnoredNoOp) or 0,
        blockedIntentStillPending = tonumber(state.blockedIntentStillPending) or 0,
        recentCount = #(state.recentMismatches or {}),
    }
end

local function FormatCombatTransitionEntry(entry)
    local rootShow = "nil"
    if entry.rootShowAction ~= nil or entry.rootShowReason ~= nil then
        rootShow = string.format("%s/%s", FormatTraceValue(entry.rootShowAction), FormatTraceValue(entry.rootShowReason))
    end
    local unitWatchDecision = "nil"
    if entry.unitWatchDecisionAction ~= nil or entry.unitWatchDecisionReason ~= nil then
        unitWatchDecision = string.format(
            "%s/%s",
            FormatTraceValue(entry.unitWatchDecisionAction),
            FormatTraceValue(entry.unitWatchDecisionReason)
        )
    end

    local suffix = entry.suspicious and " SUSPICIOUS" or ""
    return string.format(
        "  t=%s event=%s stage=%s unit=%s exists=%s frameExists=%s shown=%s alpha=%s protected=%s combat=%s mode=%s rootDecision=%s rootAction=%s rootShow=%s absentGuard=%s unitWatch=%s unitWatchDecision=%s refreshReason=%s refreshScopes=%s statePhase=%s missingSince=%s canCallShow=%s shouldShow=%s shouldSkipShow=%s frameUnit=%s%s",
        FormatTraceNumber(entry.timestamp, 3),
        FormatTraceValue(entry.event),
        FormatTraceValue(entry.stage),
        FormatTraceValue(entry.unit),
        FormatTraceBool(entry.UnitExists),
        FormatTraceBool(entry.frameExists),
        FormatTraceBool(entry.shown),
        FormatTraceNumber(entry.alpha, 3),
        FormatTraceBool(entry.protected),
        FormatTraceBool(entry.inCombat),
        FormatTraceValue(entry.mode),
        FormatTraceValue(entry.rootDecisionReason),
        FormatTraceValue(entry.rootActionPlanReason),
        rootShow,
        FormatTraceBool(entry.absentGuard),
        FormatTraceBool(entry.unitWatchRegistered),
        unitWatchDecision,
        FormatTraceValue(entry.refreshReason),
        FormatTraceValue(entry.refreshScopes),
        FormatTraceValue(entry.statePhase),
        FormatTraceNumber(entry.missingSince, 3),
        FormatTraceBool(entry.canCallShow),
        FormatTraceBool(entry.shouldShow),
        FormatTraceBool(entry.shouldSkipShow),
        FormatTraceValue(entry.frameUnit),
        suffix
    )
end

local function AppendRecentCombatTransitions(lines, title, entries, limit)
    lines[#lines + 1] = title
    if type(entries) ~= "table" or #entries == 0 then
        lines[#lines + 1] = "  none"
        return
    end

    local startIndex = math.max(1, #entries - limit + 1)
    for index = startIndex, #entries do
        lines[#lines + 1] = FormatCombatTransitionEntry(entries[index])
    end
end

function Visibility.BuildCombatTransitionReport()
    local state = EnsureDecisionDebugState()
    EnsureRootActionDebugState(state)
    local trace = state.combatTransitionTrace or {}
    local suspicious = state.combatTransitionSuspicious or {}
    local lines = {
        "Combat transition trace",
        string.format("Enabled: %s", tostring(state.enabled == true)),
        string.format("Entries: %d", #trace),
        string.format("Suspicious entries: %d", #suspicious),
        "",
    }

    AppendRecentCombatTransitions(
        lines,
        "Recent suspicious transitions:",
        suspicious,
        COMBAT_TRANSITION_SUSPICIOUS_REPORT_LIMIT
    )
    lines[#lines + 1] = ""
    AppendRecentCombatTransitions(
        lines,
        "Recent target/boss transitions:",
        trace,
        COMBAT_TRANSITION_RECENT_REPORT_LIMIT
    )
    return lines
end

local function FormatInvariantEntry(entry)
    return string.format(
        "  t=%s unit=%s violation=%s exists=%s shown=%s alpha=%s combat=%s protected=%s mode=%s configEnabled=%s unitWatch=%s unitWatchResponsible=%s rootDecision=%s rootShow=%s rootAlpha=%s refreshReason=%s check=%s previewExit=%s",
        FormatTraceNumber(entry and entry.timestamp, 3),
        FormatTraceValue(entry and entry.unit),
        FormatTraceValue(entry and entry.violation),
        FormatTraceBool(entry and entry.exists),
        FormatTraceBool(entry and entry.shown),
        FormatTraceNumber(entry and entry.alpha, 3),
        FormatTraceBool(entry and entry.combat),
        FormatTraceBool(entry and entry.protected),
        FormatTraceValue(entry and entry.mode),
        FormatTraceBool(entry and entry.configEnabled),
        FormatTraceBool(entry and entry.unitWatchRegistered),
        FormatTraceBool(entry and entry.unitWatchResponsible),
        FormatTraceValue(entry and entry.rootDecisionReason),
        FormatTraceValue(entry and entry.rootShowReason),
        FormatTraceValue(entry and entry.rootAlphaReason),
        FormatTraceValue(entry and entry.refreshReason),
        FormatTraceValue(entry and entry.checkPoint),
        FormatTraceValue(entry and entry.previewExitReason)
    )
end

function Visibility.BuildEndStateInvariantReport()
    local state = EnsureDecisionDebugState()
    EnsureRootActionDebugState(state)
    local checks = tonumber(state.endStateInvariantChecks) or 0
    local violations = tonumber(state.endStateInvariantViolations) or 0
    local recent = state.endStateInvariantRecent or {}
    local lines = {
        "UnitFrame End-State Invariant Report",
        string.format("enabled=%s", tostring(state.enabled == true)),
        string.format("checks=%d", checks),
        string.format("violations=%d", violations),
        "",
    }

    AppendSortedCounters(lines, "By violation:", state.endStateInvariantByViolation)
    lines[#lines + 1] = ""
    AppendSortedCounters(lines, "By unit:", state.endStateInvariantByUnit)
    lines[#lines + 1] = ""
    AppendSortedCounters(lines, "By mode:", state.endStateInvariantByMode)
    lines[#lines + 1] = ""
    AppendSortedCounters(lines, "By combat state:", state.endStateInvariantByCombat)
    lines[#lines + 1] = ""
    lines[#lines + 1] = "Recent violations:"

    if #recent == 0 then
        lines[#lines + 1] = "  none"
        return lines
    end

    local startIndex = math.max(1, #recent - END_STATE_INVARIANT_REPORT_LIMIT + 1)
    for index = startIndex, #recent do
        lines[#lines + 1] = FormatInvariantEntry(recent[index])
    end
    return lines
end

local function FormatBlockedIntentEntry(entry)
    return string.format(
        "  id=%s unit=%s intent=%s state=%s reason=%s firstSeen=%s lastSeen=%s observations=%s combat=%s exists=%s shown=%s alpha=%s unitWatch=%s unitWatchResponsible=%s rootShow=%s/%s rootDecision=%s rootAlpha=%s refreshReason=%s",
        FormatTraceValue(entry and entry.id),
        FormatTraceValue(entry and entry.unit),
        FormatTraceValue(entry and entry.intent),
        FormatTraceValue(entry and entry.state),
        FormatTraceValue(entry and entry.reason),
        FormatTraceNumber(entry and entry.firstSeen, 3),
        FormatTraceNumber(entry and entry.lastSeen, 3),
        FormatTraceValue(entry and entry.observations),
        FormatTraceBool(entry and entry.combat),
        FormatTraceBool(entry and entry.exists),
        FormatTraceBool(entry and entry.shown),
        FormatTraceNumber(entry and entry.alpha, 3),
        FormatTraceBool(entry and entry.unitWatchRegistered),
        FormatTraceBool(entry and entry.unitWatchResponsible),
        FormatTraceValue(entry and entry.rootShowAction),
        FormatTraceValue(entry and entry.rootShowReason),
        FormatTraceValue(entry and entry.rootDecisionReason),
        FormatTraceValue(entry and entry.rootAlphaReason),
        FormatTraceValue(entry and entry.refreshReason)
    )
end

local function AppendBlockedIntentEntries(lines, title, entries, limit)
    lines[#lines + 1] = title
    if type(entries) ~= "table" or next(entries) == nil then
        lines[#lines + 1] = "  none"
        return
    end

    local ordered = {}
    for _, entry in pairs(entries) do
        if type(entry) == "table" then
            ordered[#ordered + 1] = entry
        end
    end
    table.sort(ordered, function(a, b)
        local aTime = tonumber(a.lastSeen or a.timestamp) or 0
        local bTime = tonumber(b.lastSeen or b.timestamp) or 0
        if aTime == bTime then
            return tostring(a.id or "") < tostring(b.id or "")
        end
        return aTime > bTime
    end)

    local maxEntries = math.min(#ordered, tonumber(limit) or BLOCKED_INTENT_REPORT_LIMIT)
    for index = 1, maxEntries do
        lines[#lines + 1] = FormatBlockedIntentEntry(ordered[index])
    end
end

function Visibility.BuildBlockedIntentReport()
    local state = EnsureDecisionDebugState()
    EnsureRootActionDebugState(state)
    local openCount = 0
    for _, entry in pairs(state.blockedIntentOpen or {}) do
        if type(entry) == "table" then
            openCount = openCount + 1
        end
    end

    local lines = {
        "UnitFrame Blocked Intent Report",
        string.format("enabled=%s", tostring(state.enabled == true)),
        string.format("observed=%d", tonumber(state.blockedIntentObserved) or 0),
        string.format("resolved=%d", tonumber(state.blockedIntentResolved) or 0),
        string.format("expired=%d", tonumber(state.blockedIntentExpired) or 0),
        string.format("policy-suppressed=%d", tonumber(state.blockedIntentPolicySuppressed) or 0),
        string.format("ignored-no-op=%d", tonumber(state.blockedIntentIgnoredNoOp) or 0),
        string.format("still-pending=%d", tonumber(state.blockedIntentStillPending) or 0),
        string.format("open=%d", openCount),
        string.format("maxObservations=%d", tonumber(state.blockedIntentMaxObservations) or 0),
        "",
    }

    AppendSortedCounters(lines, "By intent:", state.blockedIntentByIntent)
    lines[#lines + 1] = ""
    AppendSortedCounters(lines, "By unit:", state.blockedIntentByUnit)
    lines[#lines + 1] = ""
    AppendSortedCounters(lines, "By source:", state.blockedIntentBySource)
    lines[#lines + 1] = ""
    AppendSortedCounters(lines, "By combat state:", state.blockedIntentByCombat)
    lines[#lines + 1] = ""
    AppendSortedCounters(lines, "By suppressed reason:", state.blockedIntentBySuppressedReason)
    lines[#lines + 1] = ""
    AppendBlockedIntentEntries(lines, "Open intents:", state.blockedIntentOpen, BLOCKED_INTENT_REPORT_LIMIT)
    lines[#lines + 1] = ""
    AppendBlockedIntentEntries(lines, "Recent still-pending:", state.blockedIntentRecentStillPending, BLOCKED_INTENT_RECENT_LIMIT)
    lines[#lines + 1] = ""
    AppendBlockedIntentEntries(lines, "Recent resolved:", state.blockedIntentRecentResolved, BLOCKED_INTENT_RECENT_LIMIT)
    lines[#lines + 1] = ""
    AppendBlockedIntentEntries(lines, "Recent expired:", state.blockedIntentRecentExpired, BLOCKED_INTENT_RECENT_LIMIT)
    return lines
end

function Visibility.BuildDecisionDebugReport()
    local state = EnsureDecisionDebugState()
    EnsureRootActionDebugState(state)
    local totalComparisons = tonumber(state.totalComparisons) or 0
    local totalMismatches = tonumber(state.totalMismatches) or 0
    local rootActionComparisons = tonumber(state.rootActionPlanComparisons) or 0
    local rootActionMismatches = tonumber(state.rootActionPlanMismatches) or 0
    local criticalProfileComparisons = tonumber(state.criticalProfileComparisons) or 0
    local criticalProfileMismatches = tonumber(state.criticalProfileMismatches) or 0
    local rootShowComparisons = tonumber(state.rootShowDecisionComparisons) or 0
    local rootShowMismatches = tonumber(state.rootShowDecisionMismatches) or 0
    local mismatchRate = totalComparisons > 0
        and ((totalMismatches / totalComparisons) * 100)
        or 0
    local rootActionMismatchRate = rootActionComparisons > 0
        and ((rootActionMismatches / rootActionComparisons) * 100)
        or 0
    local criticalProfileMismatchRate = criticalProfileComparisons > 0
        and ((criticalProfileMismatches / criticalProfileComparisons) * 100)
        or 0
    local rootShowMismatchRate = rootShowComparisons > 0
        and ((rootShowMismatches / rootShowComparisons) * 100)
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

    lines[#lines + 1] = ""
    lines[#lines + 1] = "Root Action Plan comparisons"
    lines[#lines + 1] = string.format("Comparisons: %d", rootActionComparisons)
    lines[#lines + 1] = string.format("Mismatches: %d", rootActionMismatches)
    lines[#lines + 1] = string.format("Mismatch rate: %.2f%%", rootActionMismatchRate)
    lines[#lines + 1] = ""
    AppendSortedCounters(lines, "Root Action Plan mismatches by branch:", state.rootActionPlanMismatchesByBranch)
    lines[#lines + 1] = ""
    AppendSortedCounters(lines, "Root Action Plan mismatches by field:", state.rootActionPlanMismatchesByField)
    lines[#lines + 1] = ""
    AppendSortedCounters(lines, "Root Action Plan mismatches by unit:", state.rootActionPlanMismatchesByUnit)
    lines[#lines + 1] = ""
    AppendSortedCounters(lines, "Root Action Plan matches by branch:", state.rootActionPlanMatchesByBranch)

    local rootLast = state.rootActionPlanLastMismatch
    lines[#lines + 1] = ""
    lines[#lines + 1] = "Last Root Action Plan mismatch:"
    if rootLast then
        lines[#lines + 1] = string.format(
            "  unit=%s legacyBranch=%s planReason=%s protected=%s combat=%s preview=%s missingSuppressed=%s targetTransition=%s suspiciousMissingTarget=%s",
            tostring(rootLast.unit),
            tostring(rootLast.legacyBranch),
            tostring(rootLast.planReason),
            tostring(rootLast.protected),
            tostring(rootLast.combat),
            tostring(rootLast.preview),
            tostring(rootLast.missingSuppressed),
            tostring(rootLast.targetTransition),
            tostring(rootLast.legacy and rootLast.legacy.suspiciousMissingTarget)
        )
        lines[#lines + 1] = string.format(
            "  legacy clear=%s alpha=%s mouse=%s root=%s state=%s recovery=%s return=%s",
            tostring(rootLast.legacy and rootLast.legacy.clearAction),
            tostring(rootLast.legacy and rootLast.legacy.alphaAction),
            tostring(rootLast.legacy and rootLast.legacy.mouseAction),
            tostring(rootLast.legacy and rootLast.legacy.rootAction),
            tostring(rootLast.legacy and rootLast.legacy.stateAction),
            tostring(rootLast.legacy and rootLast.legacy.recoveryAction),
            tostring(rootLast.legacy and rootLast.legacy.shouldReturn)
        )
        lines[#lines + 1] = string.format(
            "  plan   clear=%s alpha=%s mouse=%s root=%s state=%s recovery=%s return=%s",
            tostring(rootLast.plan and rootLast.plan.clearAction),
            tostring(rootLast.plan and rootLast.plan.alphaAction),
            tostring(rootLast.plan and rootLast.plan.mouseAction),
            tostring(rootLast.plan and rootLast.plan.rootAction),
            tostring(rootLast.plan and rootLast.plan.stateAction),
            tostring(rootLast.plan and rootLast.plan.recoveryAction),
            tostring(rootLast.plan and rootLast.plan.shouldReturn)
        )
        lines[#lines + 1] = "  comparedFields=" .. FormatRootActionMismatchList(rootLast)
    else
        lines[#lines + 1] = "  none"
    end

    lines[#lines + 1] = ""
    lines[#lines + 1] = "Critical Profile comparisons"
    lines[#lines + 1] = string.format("Comparisons: %d", criticalProfileComparisons)
    lines[#lines + 1] = string.format("Mismatches: %d", criticalProfileMismatches)
    lines[#lines + 1] = string.format("Mismatch rate: %.2f%%", criticalProfileMismatchRate)
    lines[#lines + 1] = ""
    AppendSortedCounters(lines, "Critical Profile comparisons by branch:", state.criticalProfileComparisonsByBranch)
    lines[#lines + 1] = ""
    AppendSortedCounters(lines, "Critical Profile mismatches by branch:", state.criticalProfileMismatchesByBranch)
    lines[#lines + 1] = ""
    AppendSortedCounters(lines, "Critical Profile mismatches by field:", state.criticalProfileMismatchesByField)
    lines[#lines + 1] = ""
    AppendCriticalProfileCoverage(lines, state)

    local criticalLast = state.criticalProfileLastMismatch
    lines[#lines + 1] = ""
    lines[#lines + 1] = "Last Critical Profile mismatch:"
    if criticalLast then
        lines[#lines + 1] = string.format(
            "  unit=%s profile=%s branch=%s protected=%s combat=%s clearMode=%s recovery=%s/%s",
            tostring(criticalLast.unit),
            tostring(criticalLast.profile),
            tostring(criticalLast.branch),
            tostring(criticalLast.legacy and criticalLast.legacy.protectedRoot),
            tostring(criticalLast.legacy and criticalLast.legacy.inCombat),
            tostring(criticalLast.legacy and criticalLast.legacy.legacyClearMode),
            tostring(criticalLast.legacy and criticalLast.legacy.legacyRecoveryRequested),
            tostring(criticalLast.legacy and criticalLast.legacy.legacyRecoveryReason)
        )
        lines[#lines + 1] = "  comparedFields=" .. FormatCriticalMismatchList(criticalLast)
    else
        lines[#lines + 1] = "  none"
    end

    lines[#lines + 1] = ""
    lines[#lines + 1] = "Root Show Decision comparisons"
    lines[#lines + 1] = string.format("Comparisons: %d", rootShowComparisons)
    lines[#lines + 1] = string.format("Mismatches: %d", rootShowMismatches)
    lines[#lines + 1] = string.format("Mismatch rate: %.2f%%", rootShowMismatchRate)
    lines[#lines + 1] = ""
    AppendRootShowBranchCoverage(lines, state)
    lines[#lines + 1] = ""
    AppendSortedCounters(lines, "Root Show Decision mismatches by action:", state.rootShowDecisionMismatchesByAction)
    lines[#lines + 1] = ""
    AppendSortedCounters(lines, "Root Show Decision mismatches by reason:", state.rootShowDecisionMismatchesByReason)
    lines[#lines + 1] = ""
    AppendSortedCounters(lines, "Root Show Decision mismatches by field:", state.rootShowDecisionMismatchesByField)
    lines[#lines + 1] = ""
    AppendSortedCounters(lines, "Root Show Decision mismatches by unit:", state.rootShowDecisionMismatchesByUnit)
    lines[#lines + 1] = ""
    AppendSortedCounters(lines, "Root Show Decision matches by branch:", state.rootShowDecisionMatchesByBranch)

    local rootShowLast = state.rootShowDecisionLastMismatch
    lines[#lines + 1] = ""
    lines[#lines + 1] = "Last Root Show Decision mismatch:"
    if rootShowLast then
        lines[#lines + 1] = string.format(
            "  unit=%s legacyBranch=%s decisionReason=%s legacyAction=%s decisionAction=%s legacyShow=%s decisionShow=%s mode=%s preview=%s unitPresent=%s protected=%s combat=%s",
            tostring(rootShowLast.unit),
            tostring(rootShowLast.legacyBranch),
            tostring(rootShowLast.decisionReason),
            tostring(rootShowLast.legacyAction),
            tostring(rootShowLast.decisionAction),
            tostring(rootShowLast.legacyShow),
            tostring(rootShowLast.decisionShow),
            tostring(rootShowLast.mode),
            tostring(rootShowLast.preview),
            tostring(rootShowLast.unitPresent),
            tostring(rootShowLast.protected),
            tostring(rootShowLast.combat)
        )
        lines[#lines + 1] = string.format(
            "  absent target=%s/%s targettarget=%s/%s focustarget=%s/%s boss=%s/%s",
            tostring(rootShowLast.legacy and rootShowLast.legacy.absentTargetGuard),
            tostring(rootShowLast.decision and rootShowLast.decision.absentTargetGuard),
            tostring(rootShowLast.legacy and rootShowLast.legacy.absentTargetTargetGuard),
            tostring(rootShowLast.decision and rootShowLast.decision.absentTargetTargetGuard),
            tostring(rootShowLast.legacy and rootShowLast.legacy.absentFocusTargetGuard),
            tostring(rootShowLast.decision and rootShowLast.decision.absentFocusTargetGuard),
            tostring(rootShowLast.legacy and rootShowLast.legacy.absentBossGuard),
            tostring(rootShowLast.decision and rootShowLast.decision.absentBossGuard)
        )
        lines[#lines + 1] = "  comparedFields=" .. FormatRootShowMismatchList(rootShowLast)
    else
        lines[#lines + 1] = "  none"
    end

    lines[#lines + 1] = ""
    lines[#lines + 1] = "Recent Root Show Decision mismatches:"
    local recentRootShow = state.rootShowDecisionRecentMismatches or {}
    if #recentRootShow == 0 then
        lines[#lines + 1] = "  none"
    else
        for index, entry in ipairs(recentRootShow) do
            lines[#lines + 1] = string.format(
                "  %d. unit=%s legacyBranch=%s legacyAction=%s decisionAction=%s reason=%s/%s fields=%s",
                index,
                tostring(entry.unit),
                tostring(entry.legacyBranch),
                tostring(entry.legacyAction),
                tostring(entry.decisionAction),
                tostring(entry.legacyReason),
                tostring(entry.decisionReason),
                FormatRootShowMismatchList(entry)
            )
        end
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

local function IsPendingUnitWatchVisibilityRecovery(frame)
    local unitWatchPolicy = FocalPoint and FocalPoint.UnitFrameUnitWatchPolicy or nil
    return frame
        and type(frame.unit) == "string"
        and unitWatchPolicy
        and unitWatchPolicy.ShouldUse
        and unitWatchPolicy.ShouldUse(frame) == true
        and (
            frame._focalPointPendingVisibilityIntent ~= nil
            or frame._focalPointPendingUnitWatchLiveReentry ~= nil
        )
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
    local debugEnabled = Visibility.IsDecisionDebugEnabled()
    local rootActionPlan
    local rootActionPlanResolved = false

    if debugEnabled then
        RecordDecisionDebugComparison(frame, decision)
    end
    local function ResolveRootActionPlanOnce(planOptions)
        if not rootActionPlanResolved then
            planOptions = type(planOptions) == "table" and planOptions or {}
            planOptions.rootDecision = planOptions.rootDecision or decision
            rootActionPlan = Visibility.ResolveRootActionPlan(frame, planOptions)
            rootActionPlanResolved = true
        end
        return rootActionPlan
    end
    local function RecordRootActionTrace(branch, values, planOptions)
        if not debugEnabled then
            return
        end
        local plan = ResolveRootActionPlanOnce(planOptions)
        local legacy = BuildLegacyRootActionTraceFromPlan(frame, plan, branch, values)
        RecordRootActionPlanComparison(frame, rootActionPlan, legacy)
    end

    if decision.specialModeActive then
        local expected = {
            clearAction = "hard",
            alphaAction = "zero",
            mouseAction = "keep",
            rootAction = "hide-if-safe",
            stateAction = "unit-lost",
            recoveryAction = "none",
            shouldReturn = true,
        }
        local plan = ResolveRootActionPlanOnce()
        if IsRootActionPlanValue(plan, "special_mode", expected) and ApplyRootActionPlan(frame, plan) then
            RecordRootActionTrace(decision.specialModeReason or "special_mode", {
                clearAction = ResolveUnitLostClearAction(frame, decision.specialModeReason or "special_mode", plan),
                alphaAction = "zero",
                rootAction = "hide-if-safe",
                stateAction = "unit-lost",
                shouldReturn = true,
            })
            return true
        end

        if State.HandleUnitLost then
            State.HandleUnitLost(frame, decision.specialModeReason or "special_mode")
        else
            Visibility.ClearFrameVisualState(frame, decision.specialModeReason or "special_mode")
        end
        if frame.SetAlpha then
            frame:SetAlpha(0)
        end
        HideFrameIfSafe(frame, {
            reason = decision.specialModeReason or "special_mode",
            source = "special-mode",
        })
        RecordRootActionTrace(decision.specialModeReason or "special_mode", {
            clearAction = ResolveUnitLostClearAction(frame, decision.specialModeReason or "special_mode", plan),
            alphaAction = "zero",
            rootAction = "hide-if-safe",
            stateAction = "unit-lost",
            shouldReturn = true,
        })
        return true
    end

    if decision.previewEnabled
        and Demo.IsFrameUnitEnabled
        and not Demo.IsFrameUnitEnabled(frame)
        and not (FocalPoint and FocalPoint.framesUnlocked == true and FocalPoint.guiTestModeEnabled ~= true)
    then
        local expected = {
            clearAction = "content-only",
            alphaAction = "zero",
            mouseAction = "disable",
            rootAction = "hide-if-safe",
            stateAction = "clear-missing",
            recoveryAction = "none",
            shouldReturn = true,
        }
        local plan = ResolveRootActionPlanOnce()
        if IsRootActionPlanValue(plan, "preview_disabled", expected) and ApplyRootActionPlan(frame, plan) then
            RecordRootActionTrace("preview-disabled-unit", {
                clearAction = "content-only",
                alphaAction = "zero",
                mouseAction = "disable",
                rootAction = "hide-if-safe",
                stateAction = "clear-missing",
                shouldReturn = true,
            })
            return true
        end

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
        HideFrameIfSafe(frame, {
            reason = "preview-disabled-unit",
            source = "preview-disabled-unit",
        })
        RecordRootActionTrace("preview-disabled-unit", {
            clearAction = "content-only",
            alphaAction = "zero",
            mouseAction = "disable",
            rootAction = "hide-if-safe",
            stateAction = "clear-missing",
            shouldReturn = true,
        })
        return true
    end

    if decision.forceVisible then
        local expected = {
            clearAction = "none",
            alphaAction = "keep",
            mouseAction = "keep",
            rootAction = "keep",
            stateAction = "clear-missing",
            recoveryAction = "none",
            shouldReturn = false,
        }
        local plan = ResolveRootActionPlanOnce()
        if IsRootActionPlanValue(plan, "force_visible", expected) and ApplyRootActionPlan(frame, plan) then
            RecordRootActionTrace("force-visible", {
                stateAction = "clear-missing",
                shouldReturn = false,
            })
            return false
        end

        frame._missingUnitSince = nil
        RecordRootActionTrace("force-visible", {
            stateAction = "clear-missing",
            shouldReturn = false,
        })
        return false
    end

    if decision.previewEnabled then
        frame._missingUnitSince = nil
        RecordRootActionTrace("preview-active", {
            stateAction = "clear-missing",
            shouldReturn = false,
        })
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
            HideFrameIfSafe(frame, {
                reason = "missing_unit_protected_suppressed",
                source = "missing-unit-protected-suppressed",
            })
            RecordRootActionTrace("missing_unit_protected_suppressed", {
                clearAction = ResolveUnitLostClearAction(frame, "missing_unit_protected_suppressed", rootActionPlan),
                alphaAction = "zero",
                mouseAction = protectedInCombat and "keep" or "disable",
                rootAction = "hide-if-safe",
                stateAction = "unit-lost",
                shouldReturn = true,
            }, {
                missingSuppressed = true,
            })
            return true
        end

        local suspiciousMissingTarget = ShouldTreatMissingTargetAsSuspicious(frame)

        if suspiciousMissingTarget then
            ForceDebugTarget(frame, protectedInCombat
                and "Missing target during combat: clearing content, secure root unchanged"
                or "Missing target: clearing content, secure root unchanged", "missing_target", 2.0)
        end

        local expected = {
            clearAction = ResolveUnitLostClearAction(frame, "missing_unit_protected", {
                unit = frame.unit,
                protectedRoot = protectedFrame,
                inCombat = decision.inCombat,
            }),
            alphaAction = frame.unit == "target" and "zero" or "keep",
            mouseAction = protectedInCombat and "keep" or "disable",
            rootAction = "hide-if-safe",
            stateAction = "unit-lost",
            recoveryAction = suspiciousMissingTarget and "queue-refresh" or "none",
            rootActionPossible = WouldHideRoot(frame),
            shouldReturn = true,
        }
        local plan = ResolveRootActionPlanOnce({
            missingSuppressed = false,
            suspiciousMissingTarget = suspiciousMissingTarget,
        })
        if IsMissingUnitProtectedActionPlanValue(plan, expected)
            and ApplyMissingUnitProtectedActionPlan(frame, plan)
        then
            RecordRootActionTrace("missing_unit_protected", {
                clearAction = expected.clearAction,
                alphaAction = expected.alphaAction,
                mouseAction = expected.mouseAction,
                rootAction = "hide-if-safe",
                stateAction = "unit-lost",
                recoveryAction = expected.recoveryAction,
                legacyRecoveryReason = suspiciousMissingTarget and "visibility" or nil,
                suspiciousMissingTarget = suspiciousMissingTarget,
                shouldReturn = true,
            }, {
                missingSuppressed = false,
                suspiciousMissingTarget = suspiciousMissingTarget,
            })
            return true
        end

        if State.HandleUnitLost then
            State.HandleUnitLost(frame, "missing_unit_protected")
        else
            Visibility.ClearFrameVisualState(frame, "missing_unit_protected")
        end
        if suspiciousMissingTarget then
            Visibility.QueueRefresh(frame)
        end
        HideFrameIfSafe(frame, {
            reason = "missing_unit_protected",
            source = "missing-unit-protected",
        })
        RecordRootActionTrace("missing_unit_protected", {
            clearAction = ResolveUnitLostClearAction(frame, "missing_unit_protected", rootActionPlan),
            alphaAction = frame.unit == "target" and "zero" or "keep",
            mouseAction = protectedInCombat and "keep" or "disable",
            rootAction = "hide-if-safe",
            stateAction = "unit-lost",
            recoveryAction = suspiciousMissingTarget and "queue-refresh" or "none",
            legacyRecoveryReason = suspiciousMissingTarget and "visibility" or nil,
            suspiciousMissingTarget = suspiciousMissingTarget,
            shouldReturn = true,
        }, {
            missingSuppressed = false,
            suspiciousMissingTarget = suspiciousMissingTarget,
        })
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
                HideFrameIfSafe(frame, {
                    reason = "target_missing_transition",
                    source = "target-missing-transition",
                })
                QueueTargetRecoveryRefreshes(frame, "target_missing_transition")
                RecordRootActionTrace("target_missing_transition", {
                    clearAction = "content-only",
                    alphaAction = "zero",
                    mouseAction = "disable",
                    rootAction = "hide-if-safe",
                    stateAction = "unit-lost",
                    recoveryAction = "queue-target-recovery",
                    legacyRecoveryReason = "target_missing_transition",
                    targetTransition = true,
                    shouldReturn = true,
                }, {
                    missingSince = frame._missingUnitSince,
                    now = now,
                })
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
            HideFrameIfSafe(frame, {
                reason = "missing_unit_suppressed",
                source = "missing-unit-suppressed",
            })
            RecordRootActionTrace("missing_unit_suppressed", {
                clearAction = ResolveUnitLostClearAction(frame, "missing_unit_suppressed", rootActionPlan),
                alphaAction = "zero",
                mouseAction = "disable",
                rootAction = "hide-if-safe",
                stateAction = "unit-lost",
                shouldReturn = true,
            }, {
                missingSuppressed = true,
            })
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

        local didHide = HideFrameIfSafe(frame, {
            reason = "missing_unit",
            source = "missing-unit",
        })
        if not IsMissingDebugSuppressed(frame) then
            MaybeDebugTarget(frame, didHide
                and "Target-Frame wird jetzt verborgen"
                or "Target-Inhalt wird ausgeblendet; Root bleibt fuer Combat-Recovery sichtbar")
        end
        RecordRootActionTrace("missing_unit", {
            clearAction = ResolveUnitLostClearAction(frame, "missing_unit", rootActionPlan),
            alphaAction = "zero",
            mouseAction = "disable",
            rootAction = "hide-if-safe",
            stateAction = "unit-lost",
            shouldReturn = true,
        }, {
            missingSuppressed = false,
        })
        return true
    end

    do
        local expected = {
            clearAction = "none",
            alphaAction = "keep",
            mouseAction = "keep",
            rootAction = "keep",
            stateAction = "clear-missing",
            recoveryAction = "none",
            shouldReturn = false,
        }
        local plan = ResolveRootActionPlanOnce()
        if IsRootActionPlanValue(plan, "unit_present", expected) and ApplyRootActionPlan(frame, plan) then
            RecordRootActionTrace("unit-present", {
                stateAction = "clear-missing",
                shouldReturn = false,
            })
            return false
        end
    end

    RecordRootActionTrace("unit-present", {
        stateAction = "clear-missing",
        shouldReturn = false,
    })
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

        Visibility.RecordCombatTransition(currentOwner, event, "event-received", {
            eventUnit = unit,
            refreshReason = event,
        })

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
                if inCombat and Visibility.RecordBlockedRootIntent then
                    Visibility.RecordBlockedRootIntent(currentOwner, {
                        intent = "apply-layout",
                        source = "boss-engage-event",
                        reason = "layout-scope-skipped-in-combat",
                        event = event,
                        refreshReason = event,
                        refreshScopes = scopes,
                        mode = "live",
                        exists = UnitExists and UnitExists(currentOwner.unit) or false,
                        shown = currentOwner.IsShown and currentOwner:IsShown() or false,
                        alpha = currentOwner.GetAlpha and currentOwner:GetAlpha() or nil,
                        protected = currentOwner.IsProtected and currentOwner:IsProtected() or false,
                        inCombat = true,
                        unitWatchRegistered = currentOwner._unitWatchRegistered == true,
                    })
                end
                State.QueueRefresh(currentOwner, event, scopes)
            else
                owner:Refresh(currentOwner)
            end
            return
        end
        if event == "PLAYER_REGEN_ENABLED" and IsPendingUnitWatchVisibilityRecovery(currentOwner) then
            local refreshRuntime = FocalPoint and FocalPoint.UnitFrameRefresh or nil
            local didSync = false
            if refreshRuntime and refreshRuntime.SyncLiveUnitWatchReentry then
                didSync = refreshRuntime.SyncLiveUnitWatchReentry(owner, currentOwner, "regen-live-reentry") ~= nil
            end
            if State.QueueRefresh then
                State.QueueRefresh(currentOwner, "unitwatch_visibility_recovery", {
                    "visibility",
                    "bars",
                    "texts",
                    "auras",
                    "layout",
                })
            elseif not didSync then
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
