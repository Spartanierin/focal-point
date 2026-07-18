local _, FocalPoint = ...

FocalPoint.UnitFrameRefresh = FocalPoint.UnitFrameRefresh or {}
local Refresh = FocalPoint.UnitFrameRefresh
local Presence = FocalPoint.UnitFramePresence or {}
local Demo = FocalPoint.UnitFrameDemoEnvironment or {}
local UnitWatchPolicy = FocalPoint.UnitFrameUnitWatchPolicy or {}
local Visibility = FocalPoint.UnitFrameVisibility or {}

local IsPreviewModeEnabled = Presence.IsPreviewModeEnabled
local DoesUnitSeemPresent = Presence.DoesUnitSeemPresent
local RestoreLivePresentAlpha

local function IsProtectedRoot(frame)
    return frame and frame.IsProtected and frame:IsProtected()
end

local function ResolveDecisionAlpha(decision, fallback)
    if decision
        and decision.writesImmediately == true
        and type(decision.finalAlpha) == "number"
    then
        return decision.finalAlpha
    end

    return fallback
end

local function IsVisibilityRecoveryUnit(unit)
    return UnitWatchPolicy.ShouldUse and UnitWatchPolicy.ShouldUse(unit) or false
end

local function ClearPendingVisibilityIntent(frame, reason)
    if frame and frame._focalPointPendingVisibilityIntent then
        frame._focalPointPendingVisibilityIntent = nil
        frame._focalPointPendingVisibilityClearedReason = reason or "resolved"
    end
end

local function MarkPendingUnitWatchLiveReentry(frame, reason)
    if frame and IsVisibilityRecoveryUnit(frame.unit) then
        frame._focalPointPendingUnitWatchLiveReentry = {
            reason = reason or "live-reentry",
            createdAt = GetTime and GetTime() or 0,
        }
    end
end

local function ClearPendingUnitWatchLiveReentry(frame, reason)
    if frame and frame._focalPointPendingUnitWatchLiveReentry then
        frame._focalPointPendingUnitWatchLiveReentry = nil
        frame._focalPointPendingUnitWatchLiveReentryClearedReason = reason or "resolved"
    end
end

local function IsVisibilityEndStateRecovered(frame)
    if not (frame and IsVisibilityRecoveryUnit(frame.unit)) then
        return false
    end
    if frame.config and frame.config.enabled == false then
        return false
    end
    if not (UnitExists and UnitExists(frame.unit)) then
        return false
    end
    local shown = frame.IsShown and frame:IsShown() == true or false
    local alpha = tonumber(frame.GetAlpha and frame:GetAlpha() or nil)
    local unitWatchOwned = frame._unitWatchRegistered == true
    return (shown or unitWatchOwned) and alpha ~= nil and alpha > 0
end

local function ClearRecoveredVisibilityIntent(frame, reason)
    if IsVisibilityEndStateRecovered(frame) then
        ClearPendingVisibilityIntent(frame, reason)
        return true
    end
    return false
end

local function ReconcilePendingVisibilityIntent(frame, mode)
    if not (frame and frame._focalPointPendingVisibilityIntent) then
        return
    end
    if mode ~= "live" then
        ClearPendingVisibilityIntent(frame, "mode-" .. tostring(mode or "unknown"))
        return
    end
    if frame.config and frame.config.enabled == false then
        ClearPendingVisibilityIntent(frame, "unit-disabled")
        ClearPendingUnitWatchLiveReentry(frame, "unit-disabled")
        return
    end
    if not (UnitExists and UnitExists(frame.unit)) then
        ClearPendingVisibilityIntent(frame, "unit-absent")
    end
    ClearRecoveredVisibilityIntent(frame, "end-state-recovered")
end

local function MarkPendingVisibilityIntent(frame, reason, refreshRequest, mode)
    if not (frame and IsVisibilityRecoveryUnit(frame.unit)) then
        return false
    end
    if mode ~= "live" then
        return false
    end
    if frame.config and frame.config.enabled == false then
        return false
    end
    if not (UnitExists and UnitExists(frame.unit)) then
        return false
    end
    if frame.IsShown and frame:IsShown() then
        return false
    end
    if frame._unitWatchRegistered == true then
        return false
    end
    if not (IsProtectedRoot(frame) and InCombatLockdown and InCombatLockdown()) then
        return false
    end

    frame._focalPointPendingVisibilityIntent = {
        reason = reason or "protected-combat",
        refreshReason = refreshRequest and refreshRequest.reason or "refresh",
        createdAt = GetTime and GetTime() or 0,
    }
    return true
end

RestoreLivePresentAlpha = function(owner, frame, mode)
    if not (owner and owner.ApplyRangeFade and frame and IsVisibilityRecoveryUnit(frame.unit)) then
        return false
    end
    if mode ~= "live" then
        return false
    end
    if frame.config and frame.config.enabled == false then
        return false
    end
    if not (UnitExists and UnitExists(frame.unit)) then
        return false
    end
    local alpha = tonumber(frame.GetAlpha and frame:GetAlpha() or nil)
    if alpha == nil or alpha > 0 then
        return false
    end

    owner:ApplyRangeFade(frame)
    return true
end

local function ShouldUseUnitWatch(frame)
    return UnitWatchPolicy.ShouldUse and UnitWatchPolicy.ShouldUse(frame) or false
end

local function ResolveLegacySyncAction(frame, previewOutsideCombat)
    if not frame then
        return {
            action = "none",
            reason = "invalid-frame",
        }
    end

    local shouldUse = ShouldUseUnitWatch(frame)
    local isRegisteredBefore = frame._unitWatchRegistered and true or false
    local registeredState = frame._unitWatchRegistered
    local protectedCombat = IsProtectedRoot(frame) and InCombatLockdown and InCombatLockdown()
    local legacy = {
        action = "none",
        reason = "no-action",
        unit = frame.unit,
        shouldUse = shouldUse,
        previewOutsideCombat = previewOutsideCombat == true,
        isRegisteredBefore = isRegisteredBefore,
        isRegisteredAfter = registeredState,
        protectedRoot = IsProtectedRoot(frame) == true,
        inCombat = InCombatLockdown and InCombatLockdown() or false,
    }

    if not shouldUse or previewOutsideCombat then
        if frame._unitWatchRegistered then
            if not UnregisterUnitWatch then
                legacy.action = "blocked"
                legacy.reason = "unregister-unavailable"
            elseif protectedCombat then
                legacy.action = "blocked"
                legacy.reason = "unregister-protected-combat"
            else
                legacy.action = "unregister"
                legacy.reason = shouldUse and "preview-outside-combat" or "unitwatch-not-used"
                legacy.isRegisteredAfter = false
            end
        else
            legacy.reason = shouldUse and "preview-outside-combat-not-registered" or "unitwatch-not-used"
        end
        return legacy
    end

    if frame._unitWatchRegistered ~= true then
        if RegisterUnitWatch then
            legacy.action = "register"
            legacy.reason = "unitwatch-register"
            legacy.isRegisteredAfter = true
        else
            legacy.action = "blocked"
            legacy.reason = "register-unavailable"
        end
        return legacy
    end

    if frame._unitWatchRegistered then
        legacy.action = "keep"
        legacy.reason = "already-registered"
    else
        legacy.reason = "registration-state-unknown"
    end
    return legacy
end

local function MaybeRecordUnitWatchSyncDebug(frame, previewOutsideCombat, decision)
    if not (UnitWatchPolicy.IsSyncDebugEnabled and UnitWatchPolicy.IsSyncDebugEnabled()) then
        return
    end
    if not (decision and UnitWatchPolicy.RecordSyncComparison) then
        return
    end

    local legacy = ResolveLegacySyncAction(frame, previewOutsideCombat)
    UnitWatchPolicy.RecordSyncComparison(legacy, decision)
end

local function SyncPreviewUnitWatch(frame, previewOutsideCombat)
    if not frame then
        return nil
    end

    local decision = UnitWatchPolicy.ResolveSync and UnitWatchPolicy.ResolveSync(frame, {
        previewOutsideCombat = previewOutsideCombat == true,
    }) or nil

    MaybeRecordUnitWatchSyncDebug(frame, previewOutsideCombat, decision)

    if not decision then
        return nil
    end

    if decision.action == "unregister" then
        UnregisterUnitWatch(frame)
        frame._unitWatchRegistered = false
        ClearPendingUnitWatchLiveReentry(frame, "unitwatch-unregistered")
        return decision
    end

    if decision.action == "register" then
        RegisterUnitWatch(frame)
        frame._unitWatchRegistered = true
        ClearPendingUnitWatchLiveReentry(frame, "unitwatch-registered")
        return decision
    end

    return decision
end

function Refresh.SyncLiveUnitWatchReentry(owner, frame, reason)
    if not (frame and IsVisibilityRecoveryUnit(frame.unit)) then
        return nil
    end
    if frame.config and frame.config.enabled == false then
        ClearPendingUnitWatchLiveReentry(frame, "unit-disabled")
        ClearPendingVisibilityIntent(frame, "unit-disabled")
        return nil
    end
    if FocalPoint and (FocalPoint.guiTestModeEnabled == true or FocalPoint.framesUnlocked == true) then
        return nil
    end
    if InCombatLockdown and InCombatLockdown() then
        MarkPendingUnitWatchLiveReentry(frame, reason or "live-reentry-combat")
        return nil
    end

    local decision = SyncPreviewUnitWatch(frame, false)
    if decision and decision.action == "blocked" then
        MarkPendingUnitWatchLiveReentry(frame, decision.reason or reason or "live-reentry-blocked")
        return decision
    end

    RestoreLivePresentAlpha(owner, frame, "live")
    if frame._unitWatchRegistered == true then
        ClearPendingUnitWatchLiveReentry(frame, "live-reentry-registered")
    end
    ClearRecoveredVisibilityIntent(frame, "live-reentry-recovered")
    return decision
end

local function HasScope(refreshRequest, scope)
    local scopes = refreshRequest and refreshRequest.scopes
    return type(scopes) == "table" and scopes[scope] == true
end

local function IsScopedRefresh(refreshRequest)
    local scopes = refreshRequest and refreshRequest.scopes
    return type(scopes) == "table" and next(scopes) ~= nil and refreshRequest.forceFullRefresh ~= true
end

local function IsRootShowDebugEnabled()
    return Visibility.IsDecisionDebugEnabled and Visibility.IsDecisionDebugEnabled()
end

local function ResolveRefreshUnitPresent(frame, fallback)
    if type(fallback) == "boolean" then
        return fallback
    end
    local unit = frame and frame.unit
    if unit == "player" then
        return true
    end
    if DoesUnitSeemPresent and type(unit) == "string" and unit ~= "" then
        return DoesUnitSeemPresent(unit) == true
    end
    if UnitExists and type(unit) == "string" and unit ~= "" then
        return UnitExists(unit) and true or false
    end
    return false
end

local function BuildRootShowLegacyTrace(frame, values)
    values = type(values) == "table" and values or {}
    return {
        branch = values.branch or "unknown",
        action = values.action or "keep",
        reason = values.reason or values.branch or "unknown",
        shouldShow = values.shouldShow == true,
        shouldSkipShow = values.shouldSkipShow == true,

        unit = values.unit or frame and frame.unit or nil,
        mode = values.mode,
        modeReason = values.modeReason,
        previewActive = values.previewActive == true,
        previewOutsideCombat = values.previewOutsideCombat == true,
        unitPresent = values.unitPresent == true,
        protectedRoot = values.protectedRoot == true,
        inCombat = values.inCombat == true,
        canCallShow = values.canCallShow == true,
        missingHandled = values.missingHandled == true,
        refreshApplyReached = values.refreshApplyReached ~= false,

        absentTargetGuard = values.absentTargetGuard == true,
        absentTargetTargetGuard = values.absentTargetTargetGuard == true,
        absentFocusTargetGuard = values.absentFocusTargetGuard == true,
        absentBossGuard = values.absentBossGuard == true,
    }
end

local function RecordRootShowDecisionShadow(frame, legacyValues, decisionOptions, forceResolve)
    local debugEnabled = IsRootShowDebugEnabled()
    if not debugEnabled and forceResolve ~= true then
        return nil
    end
    if not Visibility.ResolveRootShowDecision then
        return nil
    end

    decisionOptions = type(decisionOptions) == "table" and decisionOptions or {}
    local decision = Visibility.ResolveRootShowDecision(frame, decisionOptions)

    if debugEnabled and Visibility.RecordRootShowDecisionComparison then
        legacyValues = type(legacyValues) == "table" and legacyValues or {}
        local legacy = BuildRootShowLegacyTrace(frame, legacyValues)
        Visibility.RecordRootShowDecisionComparison(frame, legacy, decision)
    end

    return decision
end

local function NormalizeRootShowDecisionReason(reason)
    if reason == "live-protected-combat-keep"
        or reason == "preview-protected-combat-keep"
    then
        return "protected-combat-keep"
    end
    return reason
end

local function IsValidatedPreviewShowDecision(decision, mode, reason)
    return decision
        and decision.action == "show"
        and decision.reason == reason
        and decision.shouldShow == true
        and decision.shouldSkipShow == false
        and decision.previewActive == true
        and decision.mode == mode
        and decision.canCallShow == true
end

local function IsValidatedLivePresentShowDecision(decision)
    return decision
        and decision.action == "show"
        and decision.reason == "live-present-show"
        and decision.shouldShow == true
        and decision.shouldSkipShow == false
        and decision.previewActive == false
        and decision.unitPresent == true
        and decision.mode == "live"
        and decision.canCallShow == true
end

local function IsValidatedProtectedCombatKeepDecision(decision)
    return decision
        and decision.action == "keep"
        and NormalizeRootShowDecisionReason(decision.reason) == "protected-combat-keep"
        and decision.shouldShow == false
        and decision.shouldSkipShow == false
        and decision.protectedRoot == true
        and decision.inCombat == true
        and decision.canCallShow == false
end

local function RecordCombatTransition(frame, event, stage, values)
    if Visibility.RecordCombatTransition then
        Visibility.RecordCombatTransition(frame, event, stage, values)
    end
end

local function RecordBlockedIntent(frame, values)
    if Visibility.RecordBlockedRootIntent then
        Visibility.RecordBlockedRootIntent(frame, values)
    end
end

local function RecordBlockedUnitWatchIntent(frame, decision, refreshRequest, mode)
    if not (decision and decision.action == "blocked") then
        return
    end

    local intent = nil
    if decision.reason == "register-protected-combat" or decision.reason == "register-unavailable" then
        intent = "register-unitwatch"
    elseif decision.reason == "unregister-protected-combat" or decision.reason == "unregister-unavailable" then
        intent = "unregister-unitwatch"
    end
    if not intent then
        return
    end

    RecordBlockedIntent(frame, {
        intent = intent,
        source = "unitwatch-sync",
        reason = decision.reason,
        refreshReason = refreshRequest and refreshRequest.reason or "refresh",
        mode = mode,
        unitWatchRegistered = frame and frame._unitWatchRegistered == true,
        protected = decision.protectedRoot == true,
        inCombat = decision.inCombat == true,
    })
end

-- Refresh orchestration keeps the normal live-update path together so the
-- main unit-frame runtime only handles guards and high-level delegation.

function Refresh.Apply(owner, frame, config, refreshRequest)
    if not owner or not frame or not config then
        return
    end

    if Demo.TouchDebug then
        Demo.TouchDebug(frame, "refreshApply")
    end

    frame.config = config
    local mode, modeReason = "live", "live-no-resolve"
    if Demo.ResolveMode then
        mode, modeReason = Demo.ResolveMode(frame, "refresh")
    end
    if Demo.CommitMode then
        Demo.CommitMode(frame, mode, modeReason)
    end
    ReconcilePendingVisibilityIntent(frame, mode)

    local demoApplied = Demo.ApplyFrameSnapshot and Demo.ApplyFrameSnapshot(owner, frame, refreshRequest, mode, modeReason) or false
    if demoApplied then
        if mode == "disabled" then
            local protectedRoot = IsProtectedRoot(frame)
            local inCombat = InCombatLockdown and InCombatLockdown() or false
            local previewOutsideCombat = IsPreviewModeEnabled
                and IsPreviewModeEnabled()
                and not inCombat
                or false
            local unitPresent = ResolveRefreshUnitPresent(frame)
            RecordRootShowDecisionShadow(frame, {
                branch = "demo-disabled-return",
                action = "keep",
                reason = "demo-disabled-return",
                mode = mode,
                modeReason = modeReason,
                previewActive = FocalPoint and (FocalPoint.guiTestModeEnabled == true or FocalPoint.framesUnlocked == true) or false,
                previewOutsideCombat = previewOutsideCombat,
                unitPresent = unitPresent,
                protectedRoot = protectedRoot,
                inCombat = inCombat,
                canCallShow = frame.Show ~= nil and (not protectedRoot or previewOutsideCombat or not inCombat),
            }, {
                config = config,
                mode = mode,
                modeReason = modeReason,
                previewOutsideCombat = previewOutsideCombat,
                protectedRoot = protectedRoot,
                inCombat = inCombat,
                unitPresent = unitPresent,
            })
            if Demo.ReportDebug then
                Demo.ReportDebug(frame)
            end
            return
        end
        if Demo.ShouldProcessFrame and not Demo.ShouldProcessFrame(frame) then
            local protectedRoot = IsProtectedRoot(frame)
            local inCombat = InCombatLockdown and InCombatLockdown() or false
            local previewOutsideCombat = IsPreviewModeEnabled
                and IsPreviewModeEnabled()
                and not inCombat
                or false
            local unitPresent = ResolveRefreshUnitPresent(frame)
            RecordRootShowDecisionShadow(frame, {
                branch = "demo-filtered-return",
                action = "keep",
                reason = "demo-filtered-return",
                mode = mode,
                modeReason = modeReason,
                previewActive = FocalPoint and (FocalPoint.guiTestModeEnabled == true or FocalPoint.framesUnlocked == true) or false,
                previewOutsideCombat = previewOutsideCombat,
                unitPresent = unitPresent,
                protectedRoot = protectedRoot,
                inCombat = inCombat,
                canCallShow = frame.Show ~= nil and (not protectedRoot or previewOutsideCombat or not inCombat),
            }, {
                config = config,
                mode = mode,
                modeReason = modeReason,
                previewOutsideCombat = previewOutsideCombat,
                protectedRoot = protectedRoot,
                inCombat = inCombat,
                unitPresent = unitPresent,
            })
            if frame.Hide then
                frame:Hide()
            end
            if Demo.ReportDebug then
                Demo.ReportDebug(frame)
            end
            return
        end
        local shouldApplyConfig = Demo.ShouldApplyConfig and Demo.ShouldApplyConfig(frame, refreshRequest, mode, modeReason) or true
        if shouldApplyConfig and owner.ApplyConfig then
            if Demo.TouchDebug then
                Demo.TouchDebug(frame, "applyConfig")
            end
            owner:ApplyConfig(frame)
        end
        if Demo.ApplyRuntimePreview then
            Demo.ApplyRuntimePreview(owner, frame, refreshRequest, mode, modeReason)
        end
        if not (Demo.IsRangeFadeDisabled and Demo.IsRangeFadeDisabled()) then
            owner:ApplyRangeFade(frame)
        end
        if mode == "placeholder"
            and FocalPoint
            and FocalPoint.framesUnlocked == true
            and FocalPoint.guiTestModeEnabled ~= true
            and frame.SetAlpha
        then
            local alphaDecision = Visibility.ResolveRootAlphaDecision
                and Visibility.ResolveRootAlphaDecision(frame, {
                    source = "refresh-placeholder",
                    rangeMultiplier = 1,
                    missingUnitAlphaGuard = false,
                    visibilityOptions = {
                        mode = mode,
                        modeReason = modeReason,
                    },
                })
                or nil
            if FocalPoint.RootAlphaDebug
                and FocalPoint.RootAlphaDebug.enabled == true
                and FocalPoint.UnitFrame
                and FocalPoint.UnitFrame.RecordRootAlphaOverrideShadow
            then
                FocalPoint.UnitFrame.RecordRootAlphaOverrideShadow(frame, {
                    callsite = "refresh-placeholder",
                    reason = "unlock-placeholder",
                    alpha = 1,
                    shouldForceZero = false,
                    mode = mode,
                    modeReason = modeReason,
                    laterOverriddenByPlaceholder = true,
                }, alphaDecision)
            end
            frame:SetAlpha(ResolveDecisionAlpha(alphaDecision, 1))
        end

        local protectedRoot = IsProtectedRoot(frame)
        local previewOutsideCombat = IsPreviewModeEnabled
            and IsPreviewModeEnabled()
            and not (InCombatLockdown and InCombatLockdown())
        local outsideCombat = not (InCombatLockdown and InCombatLockdown())
        local inCombat = not outsideCombat

        local unitWatchRegisteredBefore = frame._unitWatchRegistered == true
        local unitWatchDecision = SyncPreviewUnitWatch(frame, previewOutsideCombat)
        RecordBlockedUnitWatchIntent(frame, unitWatchDecision, refreshRequest, mode)
        RecordCombatTransition(frame, refreshRequest and refreshRequest.reason or "refresh", "unitwatch-sync", {
            config = config,
            mode = mode,
            refreshReason = refreshRequest and refreshRequest.reason or nil,
            refreshScopes = refreshRequest and refreshRequest.scopes or nil,
            unitWatchDecision = unitWatchDecision,
            registeredBefore = unitWatchRegisteredBefore,
            registeredAfter = frame._unitWatchRegistered == true,
            canRegisterNow = unitWatchDecision and unitWatchDecision.canRegisterNow,
            canUnregisterNow = unitWatchDecision and unitWatchDecision.canUnregisterNow,
        })

        if not protectedRoot or previewOutsideCombat or outsideCombat then
            local unitPresent = ResolveRefreshUnitPresent(frame)
            local showDecision = RecordRootShowDecisionShadow(frame, {
                branch = mode == "placeholder" and "preview-placeholder" or "preview-detailed",
                action = "show",
                reason = mode == "placeholder" and "preview-placeholder-show" or "preview-detailed-show",
                shouldShow = true,
                mode = mode,
                modeReason = modeReason,
                previewActive = FocalPoint and (FocalPoint.guiTestModeEnabled == true or FocalPoint.framesUnlocked == true) or false,
                previewOutsideCombat = previewOutsideCombat,
                unitPresent = unitPresent,
                protectedRoot = protectedRoot,
                inCombat = inCombat,
                canCallShow = true,
            }, {
                config = config,
                mode = mode,
                modeReason = modeReason,
                previewOutsideCombat = previewOutsideCombat,
                protectedRoot = protectedRoot,
                inCombat = inCombat,
                unitPresent = unitPresent,
            }, true)
            local expectedReason = mode == "placeholder" and "preview-placeholder-show" or "preview-detailed-show"
            RecordCombatTransition(frame, refreshRequest and refreshRequest.reason or "refresh", "before-root-show", {
                config = config,
                mode = mode,
                refreshReason = refreshRequest and refreshRequest.reason or nil,
                refreshScopes = refreshRequest and refreshRequest.scopes or nil,
                rootShowDecision = showDecision,
                rootShowAction = "show",
                rootShowReason = expectedReason,
                canCallShow = true,
                shouldShow = true,
            })
            local shouldShowRoot = true
            if IsValidatedPreviewShowDecision(showDecision, mode, expectedReason) then
                shouldShowRoot = showDecision.shouldShow == true
            end
            if shouldShowRoot then
                frame:Show()
                ClearRecoveredVisibilityIntent(frame, "preview-show")
            end
            RecordCombatTransition(frame, refreshRequest and refreshRequest.reason or "refresh", "after-root-show", {
                config = config,
                mode = mode,
                refreshReason = refreshRequest and refreshRequest.reason or nil,
                refreshScopes = refreshRequest and refreshRequest.scopes or nil,
                rootShowDecision = showDecision,
                rootShowAction = "show",
                rootShowReason = expectedReason,
                canCallShow = true,
                shouldShow = shouldShowRoot == true,
                showAttempted = shouldShowRoot == true,
            })
        else
            local unitPresent = ResolveRefreshUnitPresent(frame)
            local showDecision = RecordRootShowDecisionShadow(frame, {
                branch = "protected-combat-keep",
                action = "keep",
                reason = "preview-protected-combat-keep",
                mode = mode,
                modeReason = modeReason,
                previewActive = FocalPoint and (FocalPoint.guiTestModeEnabled == true or FocalPoint.framesUnlocked == true) or false,
                previewOutsideCombat = previewOutsideCombat,
                unitPresent = unitPresent,
                protectedRoot = protectedRoot,
                inCombat = inCombat,
                canCallShow = false,
            }, {
                config = config,
                mode = mode,
                modeReason = modeReason,
                previewOutsideCombat = previewOutsideCombat,
                protectedRoot = protectedRoot,
                inCombat = inCombat,
                unitPresent = unitPresent,
            }, true)
            RecordCombatTransition(frame, refreshRequest and refreshRequest.reason or "refresh", "before-root-show", {
                config = config,
                mode = mode,
                refreshReason = refreshRequest and refreshRequest.reason or nil,
                refreshScopes = refreshRequest and refreshRequest.scopes or nil,
                rootShowDecision = showDecision,
                rootShowAction = "keep",
                rootShowReason = "preview-protected-combat-keep",
                canCallShow = false,
                shouldShow = false,
            })
            local rootShown = frame.IsShown and frame:IsShown() or false
            if unitPresent == true and protectedRoot == true and inCombat == true and rootShown == false then
                MarkPendingVisibilityIntent(frame, "preview-protected-combat-keep", refreshRequest, mode)
                RecordBlockedIntent(frame, {
                    intent = "show-root",
                    source = "root-show",
                    reason = "protected-combat",
                    refreshReason = refreshRequest and refreshRequest.reason or "refresh",
                    mode = mode,
                    exists = unitPresent == true,
                    shown = rootShown,
                    alpha = frame.GetAlpha and frame:GetAlpha() or nil,
                    protected = protectedRoot == true,
                    inCombat = inCombat == true,
                    unitWatchRegistered = frame._unitWatchRegistered == true,
                    rootShowAction = "keep",
                    rootShowReason = "preview-protected-combat-keep",
                })
            end
            if IsValidatedProtectedCombatKeepDecision(showDecision) then
                -- Decision validated the existing protected-combat keep behavior.
            else
                -- Legacy fallback: protected-combat keep also performs no root show.
            end
            RecordCombatTransition(frame, refreshRequest and refreshRequest.reason or "refresh", "after-root-show", {
                config = config,
                mode = mode,
                refreshReason = refreshRequest and refreshRequest.reason or nil,
                refreshScopes = refreshRequest and refreshRequest.scopes or nil,
                rootShowDecision = showDecision,
                rootShowAction = "keep",
                rootShowReason = "preview-protected-combat-keep",
                canCallShow = false,
                shouldShow = false,
                showAttempted = false,
            })
        end
        if Demo.ReportDebug then
            Demo.ReportDebug(frame)
        end
        return
    end

    local scopedRefresh = IsScopedRefresh(refreshRequest)
    local needsFull = not scopedRefresh
    local needsLayout = needsFull or HasScope(refreshRequest, "layout")
    local needsBars = needsFull or HasScope(refreshRequest, "bars")
    local needsTexts = needsFull or HasScope(refreshRequest, "texts")
    local needsAuras = needsFull or HasScope(refreshRequest, "auras")
    local needsCastbar = needsFull or HasScope(refreshRequest, "castbar")
    local needsVisibility = needsFull or HasScope(refreshRequest, "visibility")

    if needsBars and owner.RefreshUnitBarValues then
        owner:RefreshUnitBarValues(frame)
    end
    if needsLayout and owner.ApplyConfig then
        owner:ApplyConfig(frame)
    end
    if needsFull and owner.ApplyTestValues then
        owner:ApplyTestValues(frame)
    end

    if needsCastbar and owner.RefreshCastBar then
        owner:RefreshCastBar(frame)
    end
    if needsTexts and owner.RefreshLiveValues then
        owner:RefreshLiveValues(frame)
    end
    if needsAuras and owner.RefreshAuras then
        owner:RefreshAuras(frame, refreshRequest and refreshRequest.forceAuraFullScan == true)
    end
    if needsTexts and owner.UpdateTextElements then
        owner:UpdateTextElements(frame)
    end

    if needsVisibility and owner.ApplyRangeFade then
        owner:ApplyRangeFade(frame)
    end

    local protectedRoot = IsProtectedRoot(frame)
    local previewOutsideCombat = IsPreviewModeEnabled
        and IsPreviewModeEnabled()
        and not (InCombatLockdown and InCombatLockdown())
    local outsideCombat = not (InCombatLockdown and InCombatLockdown())
    local inCombat = not outsideCombat

    local unitWatchRegisteredBefore = frame._unitWatchRegistered == true
    local unitWatchDecision = SyncPreviewUnitWatch(frame, previewOutsideCombat)
    RestoreLivePresentAlpha(owner, frame, mode)
    RecordBlockedUnitWatchIntent(frame, unitWatchDecision, refreshRequest, mode)
    RecordCombatTransition(frame, refreshRequest and refreshRequest.reason or "refresh", "unitwatch-sync", {
        config = config,
        mode = mode,
        refreshReason = refreshRequest and refreshRequest.reason or nil,
        refreshScopes = refreshRequest and refreshRequest.scopes or nil,
        unitWatchDecision = unitWatchDecision,
        registeredBefore = unitWatchRegisteredBefore,
        registeredAfter = frame._unitWatchRegistered == true,
        canRegisterNow = unitWatchDecision and unitWatchDecision.canRegisterNow,
        canUnregisterNow = unitWatchDecision and unitWatchDecision.canUnregisterNow,
    })

    local skipShowForAbsentTarget = frame.unit == "target"
        and not previewOutsideCombat
        and UnitExists
        and not UnitExists("target")
    local skipShowForAbsentTargetTarget = frame.unit == "targettarget"
        and not previewOutsideCombat
        and UnitExists
        and not UnitExists("targettarget")
    local skipShowForAbsentFocusTarget = frame.unit == "focustarget"
        and not previewOutsideCombat
        and UnitExists
        and not UnitExists("focustarget")
    local skipShowForAbsentBoss = type(frame.unit) == "string"
        and frame.unit:match("^boss%d+$")
        and not previewOutsideCombat
        and UnitExists
        and not UnitExists(frame.unit)
    local canCallShow = not protectedRoot or previewOutsideCombat or outsideCombat
    local unitPresent = ResolveRefreshUnitPresent(frame)

    if skipShowForAbsentTarget
        or skipShowForAbsentTargetTarget
        or skipShowForAbsentFocusTarget
        or skipShowForAbsentBoss
    then
        local branch = "absent-target"
        if skipShowForAbsentTargetTarget then
            branch = "absent-targettarget"
        elseif skipShowForAbsentFocusTarget then
            branch = "absent-focustarget"
        elseif skipShowForAbsentBoss then
            branch = "absent-boss"
        end
        local showDecision = RecordRootShowDecisionShadow(frame, {
            branch = branch,
            action = "skip-show",
            reason = branch,
            shouldSkipShow = true,
            mode = mode,
            modeReason = modeReason,
            previewActive = FocalPoint and (FocalPoint.guiTestModeEnabled == true or FocalPoint.framesUnlocked == true) or false,
            previewOutsideCombat = previewOutsideCombat,
            unitPresent = unitPresent,
            protectedRoot = protectedRoot,
            inCombat = inCombat,
            canCallShow = canCallShow,
            absentTargetGuard = skipShowForAbsentTarget,
            absentTargetTargetGuard = skipShowForAbsentTargetTarget,
            absentFocusTargetGuard = skipShowForAbsentFocusTarget,
            absentBossGuard = skipShowForAbsentBoss,
        }, {
            config = config,
            mode = mode,
            modeReason = modeReason,
            previewOutsideCombat = previewOutsideCombat,
            protectedRoot = protectedRoot,
            inCombat = inCombat,
            unitPresent = unitPresent,
        })
        RecordCombatTransition(frame, refreshRequest and refreshRequest.reason or "refresh", "before-root-show", {
            config = config,
            mode = mode,
            refreshReason = refreshRequest and refreshRequest.reason or nil,
            refreshScopes = refreshRequest and refreshRequest.scopes or nil,
            rootShowDecision = showDecision,
            rootShowAction = "skip-show",
            rootShowReason = branch,
            absentGuard = true,
            canCallShow = canCallShow,
            shouldShow = false,
            shouldSkipShow = true,
        })
        RecordCombatTransition(frame, refreshRequest and refreshRequest.reason or "refresh", "after-root-show", {
            config = config,
            mode = mode,
            refreshReason = refreshRequest and refreshRequest.reason or nil,
            refreshScopes = refreshRequest and refreshRequest.scopes or nil,
            rootShowDecision = showDecision,
            rootShowAction = "skip-show",
            rootShowReason = branch,
            absentGuard = true,
            canCallShow = canCallShow,
            shouldShow = false,
            shouldSkipShow = true,
            showAttempted = false,
        })
    end

    if (not protectedRoot or previewOutsideCombat or outsideCombat)
        and not skipShowForAbsentTarget
        and not skipShowForAbsentTargetTarget
        and not skipShowForAbsentFocusTarget
        and not skipShowForAbsentBoss
    then
        local showDecision = RecordRootShowDecisionShadow(frame, {
            branch = unitPresent and "live-present" or "live-local-show",
            action = "show",
            reason = unitPresent and "live-present-show" or "live-local-show",
            shouldShow = true,
            mode = mode,
            modeReason = modeReason,
            previewActive = FocalPoint and (FocalPoint.guiTestModeEnabled == true or FocalPoint.framesUnlocked == true) or false,
            previewOutsideCombat = previewOutsideCombat,
            unitPresent = unitPresent,
            protectedRoot = protectedRoot,
            inCombat = inCombat,
            canCallShow = canCallShow,
            absentTargetGuard = skipShowForAbsentTarget,
            absentTargetTargetGuard = skipShowForAbsentTargetTarget,
            absentFocusTargetGuard = skipShowForAbsentFocusTarget,
            absentBossGuard = skipShowForAbsentBoss,
        }, {
            config = config,
            mode = mode,
            modeReason = modeReason,
            previewOutsideCombat = previewOutsideCombat,
            protectedRoot = protectedRoot,
            inCombat = inCombat,
            unitPresent = unitPresent,
        }, true)
        RecordCombatTransition(frame, refreshRequest and refreshRequest.reason or "refresh", "before-root-show", {
            config = config,
            mode = mode,
            refreshReason = refreshRequest and refreshRequest.reason or nil,
            refreshScopes = refreshRequest and refreshRequest.scopes or nil,
            rootShowDecision = showDecision,
            rootShowAction = "show",
            rootShowReason = unitPresent and "live-present-show" or "live-local-show",
            canCallShow = canCallShow,
            shouldShow = true,
        })
        local shouldShowRoot = true
        if IsValidatedLivePresentShowDecision(showDecision) then
            shouldShowRoot = showDecision.shouldShow == true
        end
        if shouldShowRoot then
            frame:Show()
            ClearRecoveredVisibilityIntent(frame, "live-show")
        end
        RecordCombatTransition(frame, refreshRequest and refreshRequest.reason or "refresh", "after-root-show", {
            config = config,
            mode = mode,
            refreshReason = refreshRequest and refreshRequest.reason or nil,
            refreshScopes = refreshRequest and refreshRequest.scopes or nil,
            rootShowDecision = showDecision,
            rootShowAction = "show",
            rootShowReason = unitPresent and "live-present-show" or "live-local-show",
            canCallShow = canCallShow,
            shouldShow = shouldShowRoot == true,
            showAttempted = shouldShowRoot == true,
        })
    elseif not skipShowForAbsentTarget
        and not skipShowForAbsentTargetTarget
        and not skipShowForAbsentFocusTarget
        and not skipShowForAbsentBoss
    then
        local showDecision = RecordRootShowDecisionShadow(frame, {
            branch = "protected-combat-keep",
            action = "keep",
            reason = "live-protected-combat-keep",
            mode = mode,
            modeReason = modeReason,
            previewActive = FocalPoint and (FocalPoint.guiTestModeEnabled == true or FocalPoint.framesUnlocked == true) or false,
            previewOutsideCombat = previewOutsideCombat,
            unitPresent = unitPresent,
            protectedRoot = protectedRoot,
            inCombat = inCombat,
            canCallShow = canCallShow,
            absentTargetGuard = skipShowForAbsentTarget,
            absentTargetTargetGuard = skipShowForAbsentTargetTarget,
            absentFocusTargetGuard = skipShowForAbsentFocusTarget,
            absentBossGuard = skipShowForAbsentBoss,
        }, {
            config = config,
            mode = mode,
            modeReason = modeReason,
            previewOutsideCombat = previewOutsideCombat,
            protectedRoot = protectedRoot,
            inCombat = inCombat,
            unitPresent = unitPresent,
        }, true)
        RecordCombatTransition(frame, refreshRequest and refreshRequest.reason or "refresh", "before-root-show", {
            config = config,
            mode = mode,
            refreshReason = refreshRequest and refreshRequest.reason or nil,
            refreshScopes = refreshRequest and refreshRequest.scopes or nil,
            rootShowDecision = showDecision,
            rootShowAction = "keep",
            rootShowReason = "live-protected-combat-keep",
            canCallShow = canCallShow,
            shouldShow = false,
        })
        local rootShown = frame.IsShown and frame:IsShown() or false
        if unitPresent == true and protectedRoot == true and inCombat == true and rootShown == false then
            MarkPendingVisibilityIntent(frame, "live-protected-combat-keep", refreshRequest, mode)
            RecordBlockedIntent(frame, {
                intent = "show-root",
                source = "root-show",
                reason = "protected-combat",
                refreshReason = refreshRequest and refreshRequest.reason or "refresh",
                mode = mode,
                exists = unitPresent == true,
                shown = rootShown,
                alpha = frame.GetAlpha and frame:GetAlpha() or nil,
                protected = protectedRoot == true,
                inCombat = inCombat == true,
                unitWatchRegistered = frame._unitWatchRegistered == true,
                rootShowAction = "keep",
                rootShowReason = "live-protected-combat-keep",
            })
        end
        if IsValidatedProtectedCombatKeepDecision(showDecision) then
            -- Decision validated the existing protected-combat keep behavior.
        else
            -- Legacy fallback: protected-combat keep also performs no root show.
        end
        ClearRecoveredVisibilityIntent(frame, "live-recovered")
        RecordCombatTransition(frame, refreshRequest and refreshRequest.reason or "refresh", "after-root-show", {
            config = config,
            mode = mode,
            refreshReason = refreshRequest and refreshRequest.reason or nil,
            refreshScopes = refreshRequest and refreshRequest.scopes or nil,
            rootShowDecision = showDecision,
            rootShowAction = "keep",
            rootShowReason = "live-protected-combat-keep",
            canCallShow = canCallShow,
            shouldShow = false,
            showAttempted = false,
        })
    end

    if Demo.ReportDebug then
        Demo.ReportDebug(frame)
    end
end
