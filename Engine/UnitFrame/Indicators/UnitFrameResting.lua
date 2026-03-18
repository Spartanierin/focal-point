local _, FocalPoint = ...

FocalPoint.UnitFrameResting = FocalPoint.UnitFrameResting or {}
local Resting = FocalPoint.UnitFrameResting

local Presence = FocalPoint.UnitFramePresence or {}

local IsPreviewModeEnabled = Presence.IsPreviewModeEnabled

-- Resting indicator runtime keeps player-resting state evaluation and
-- event wiring isolated from the rest of the indicator logic.

function Resting.Update(owner, frame)
    if not frame or not frame.Elements or not frame.Elements.RestingIndicator then
        return
    end

    local holder = frame.Elements.RestingIndicator
    local icon = holder.Texture or holder
    local config = frame.config
    local restingConfig = config and config.RestingIndicator or nil

    if not restingConfig or restingConfig.enabled == false then
        icon:SetTexture(nil)
        icon:Hide()
        holder:Hide()
        return
    end

    local isResting = frame.unit == "player" and IsResting and IsResting()

    if IsPreviewModeEnabled() then
        isResting = frame.unit == "player"
    end

    if not isResting then
        icon:SetTexture(nil)
        icon:Hide()
        holder:Hide()
        return
    end

    icon:SetTexture("Interface\\CharacterFrame\\UI-StateIcon")
    icon:SetTexCoord(0, 0.5, 0, 0.421875)
    holder:Show()
    icon:Show()
end

function Resting.RegisterEvents(owner, frame)
    if not frame or frame.RestingIndicatorEventFrame then
        return
    end

    local eventFrame = CreateFrame("Frame", nil, frame)
    eventFrame.owner = frame

    eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    eventFrame:RegisterEvent("PLAYER_UPDATE_RESTING")

    eventFrame:SetScript("OnEvent", function()
        local currentOwner = eventFrame.owner
        if not currentOwner or not currentOwner:IsShown() then
            return
        end

        C_Timer.After(0, function()
            if currentOwner and currentOwner:IsShown() then
                owner:UpdateRestingIndicator(currentOwner)
            end
        end)
    end)

    frame.RestingIndicatorEventFrame = eventFrame
end
