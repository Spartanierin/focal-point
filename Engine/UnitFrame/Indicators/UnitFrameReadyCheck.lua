local _, FocalPoint = ...

FocalPoint.UnitFrameReadyCheck = FocalPoint.UnitFrameReadyCheck or {}
local ReadyCheck = FocalPoint.UnitFrameReadyCheck

local Presence = FocalPoint.UnitFramePresence or {}

local IsPreviewModeEnabled = Presence.IsPreviewModeEnabled

-- Ready check runtime keeps ready-check state evaluation and event wiring
-- isolated from the rest of the indicator logic.

function ReadyCheck.Update(owner, frame)
    if not frame or not frame.Elements or not frame.Elements.ReadyCheckIndicator then
        return
    end

    local holder = frame.Elements.ReadyCheckIndicator
    local icon = holder.Texture or holder
    local config = frame.config
    local readyCheckConfig = config and config.ReadyCheckIndicator or nil

    if not readyCheckConfig or readyCheckConfig.enabled == false then
        icon:SetTexture(nil)
        icon:Hide()
        holder:Hide()
        return
    end

    local status = frame.unit and GetReadyCheckStatus and GetReadyCheckStatus(frame.unit) or nil

    if not status and IsPreviewModeEnabled() then
        local previewMap = {
            player = "ready",
            target = "notready",
            focus = "waiting",
            pet = "ready",
        }
        status = previewMap[frame.unit] or "ready"
    end

    if status == "ready" then
        icon:SetTexture("Interface\\RaidFrame\\ReadyCheck-Ready")
    elseif status == "notready" then
        icon:SetTexture("Interface\\RaidFrame\\ReadyCheck-NotReady")
    elseif status == "waiting" then
        icon:SetTexture("Interface\\RaidFrame\\ReadyCheck-Waiting")
    else
        icon:SetTexture(nil)
        icon:Hide()
        holder:Hide()
        return
    end

    icon:SetTexCoord(0, 1, 0, 1)
    holder:Show()
    icon:Show()
end

function ReadyCheck.RegisterEvents(owner, frame)
    if not frame or frame.ReadyCheckIndicatorEventFrame then
        return
    end

    local eventFrame = CreateFrame("Frame", nil, frame)
    eventFrame.owner = frame

    eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    eventFrame:RegisterEvent("READY_CHECK")
    eventFrame:RegisterEvent("READY_CHECK_CONFIRM")
    eventFrame:RegisterEvent("READY_CHECK_FINISHED")
    eventFrame:RegisterEvent("GROUP_ROSTER_UPDATE")

    if frame.unit == "target" then
        eventFrame:RegisterEvent("PLAYER_TARGET_CHANGED")
    elseif frame.unit == "focus" then
        eventFrame:RegisterEvent("PLAYER_FOCUS_CHANGED")
    elseif frame.unit == "pet" then
        eventFrame:RegisterEvent("UNIT_PET")
    end

    eventFrame:SetScript("OnEvent", function(_, event, unit)
        local currentOwner = eventFrame.owner
        if not currentOwner or not currentOwner:IsShown() then
            return
        end

        if event == "UNIT_PET" and unit ~= "player" then
            return
        end

        C_Timer.After(0, function()
            if currentOwner and currentOwner:IsShown() then
                owner:UpdateReadyCheckIndicator(currentOwner)
            end
        end)
    end)

    frame.ReadyCheckIndicatorEventFrame = eventFrame
end
