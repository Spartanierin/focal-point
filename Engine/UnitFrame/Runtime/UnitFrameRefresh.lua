local _, FocalPoint = ...

FocalPoint.UnitFrameRefresh = FocalPoint.UnitFrameRefresh or {}
local Refresh = FocalPoint.UnitFrameRefresh

local function IsProtectedRoot(frame)
    return frame and frame.IsProtected and frame:IsProtected()
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

    if not IsProtectedRoot(frame) then
        frame:Show()
    end
end
