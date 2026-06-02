local _, FocalPoint = ...

FocalPoint.UnitFrameRefresh = FocalPoint.UnitFrameRefresh or {}
local Refresh = FocalPoint.UnitFrameRefresh
local Presence = FocalPoint.UnitFramePresence or {}
local Demo = FocalPoint.UnitFrameDemoEnvironment or {}

local IsPreviewModeEnabled = Presence.IsPreviewModeEnabled

local function IsProtectedRoot(frame)
    return frame and frame.IsProtected and frame:IsProtected()
end

local function SyncPreviewUnitWatch(frame, previewOutsideCombat)
    if not frame or frame.unit == "player" then
        return
    end

    if previewOutsideCombat then
        if frame._unitWatchRegistered and UnregisterUnitWatch then
            UnregisterUnitWatch(frame)
            frame._unitWatchRegistered = false
        end
        return
    end

    if frame._unitWatchRegistered == false and RegisterUnitWatch then
        RegisterUnitWatch(frame)
        frame._unitWatchRegistered = true
    end
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

    owner:RefreshUnitBarValues(frame)
    owner:ApplyConfig(frame)
    owner:ApplyTestValues(frame)

    if owner.RefreshCastBar then
        owner:RefreshCastBar(frame)
    end
    if owner.RefreshLiveValues then
        owner:RefreshLiveValues(frame)
    end
    if owner.RefreshAuras then
        owner:RefreshAuras(frame, refreshRequest and refreshRequest.forceAuraFullScan == true)
    end
    if owner.UpdateTextElements then
        owner:UpdateTextElements(frame)
    end

    owner:ApplyRangeFade(frame)

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
end
