local _, FocalPoint = ...

FocalPoint.UnitFrameRefresh = FocalPoint.UnitFrameRefresh or {}
local Refresh = FocalPoint.UnitFrameRefresh
local Presence = FocalPoint.UnitFramePresence or {}
local Demo = FocalPoint.UnitFrameDemoEnvironment or {}
local UnitWatchPolicy = FocalPoint.UnitFrameUnitWatchPolicy or {}

local IsPreviewModeEnabled = Presence.IsPreviewModeEnabled

local function IsProtectedRoot(frame)
    return frame and frame.IsProtected and frame:IsProtected()
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

    if frame._unitWatchRegistered == false then
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
        return
    end

    local decision = UnitWatchPolicy.ResolveSync and UnitWatchPolicy.ResolveSync(frame, {
        previewOutsideCombat = previewOutsideCombat == true,
    }) or nil

    MaybeRecordUnitWatchSyncDebug(frame, previewOutsideCombat, decision)

    if not decision then
        return
    end

    if decision.action == "unregister" then
        UnregisterUnitWatch(frame)
        frame._unitWatchRegistered = false
        return
    end

    if decision.action == "register" then
        RegisterUnitWatch(frame)
        frame._unitWatchRegistered = true
        return
    end
end

local function HasScope(refreshRequest, scope)
    local scopes = refreshRequest and refreshRequest.scopes
    return type(scopes) == "table" and scopes[scope] == true
end

local function IsScopedRefresh(refreshRequest)
    local scopes = refreshRequest and refreshRequest.scopes
    return type(scopes) == "table" and next(scopes) ~= nil and refreshRequest.forceFullRefresh ~= true
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

    local demoApplied = Demo.ApplyFrameSnapshot and Demo.ApplyFrameSnapshot(owner, frame, refreshRequest, mode, modeReason) or false
    if demoApplied then
        if mode == "disabled" then
            if Demo.ReportDebug then
                Demo.ReportDebug(frame)
            end
            return
        end
        if Demo.ShouldProcessFrame and not Demo.ShouldProcessFrame(frame) then
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
                })
            end
            frame:SetAlpha(1)
        end

        local protectedRoot = IsProtectedRoot(frame)
        local previewOutsideCombat = IsPreviewModeEnabled
            and IsPreviewModeEnabled()
            and not (InCombatLockdown and InCombatLockdown())
        local outsideCombat = not (InCombatLockdown and InCombatLockdown())

        SyncPreviewUnitWatch(frame, previewOutsideCombat)

        if not protectedRoot or previewOutsideCombat or outsideCombat then
            frame:Show()
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

    SyncPreviewUnitWatch(frame, previewOutsideCombat)

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

    if (not protectedRoot or previewOutsideCombat or outsideCombat)
        and not skipShowForAbsentTarget
        and not skipShowForAbsentTargetTarget
        and not skipShowForAbsentFocusTarget
        and not skipShowForAbsentBoss
    then
        frame:Show()
    end

    if Demo.ReportDebug then
        Demo.ReportDebug(frame)
    end
end
