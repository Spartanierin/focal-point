local _, FocalPoint = ...

FocalPoint.UnitFrameRefresh = FocalPoint.UnitFrameRefresh or {}
local Refresh = FocalPoint.UnitFrameRefresh
local Presence = FocalPoint.UnitFramePresence or {}

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

function Refresh.Apply(owner, frame, config)
    if not owner or not frame or not config then
        return
    end

    frame.config = config
    owner:RefreshUnitBarValues(frame)
    owner:ApplyConfig(frame)
    owner:ApplyTestValues(frame)

    if owner.RefreshCastBar then
        owner:RefreshCastBar(frame)
    end
    if owner.RefreshLiveValues then
        owner:RefreshLiveValues(frame)
    end
    if owner.UpdateTextElements then
        owner:UpdateTextElements(frame)
    end

    owner:ApplyRangeFade(frame)

    local protectedRoot = IsProtectedRoot(frame)
    local previewOutsideCombat = IsPreviewModeEnabled
        and IsPreviewModeEnabled()
        and not (InCombatLockdown and InCombatLockdown())

    SyncPreviewUnitWatch(frame, previewOutsideCombat)

    if not protectedRoot or previewOutsideCombat then
        frame:Show()
    end
end
