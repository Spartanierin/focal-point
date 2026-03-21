local _, FocalPoint = ...

FocalPoint.UnitFrameResting = FocalPoint.UnitFrameResting or {}
local Resting = FocalPoint.UnitFrameResting

local Presence = FocalPoint.UnitFramePresence or {}
local Preview = FocalPoint.UnitFramePreview or {}
local Indicators = FocalPoint.UnitFrameIndicators or {}
local State = FocalPoint.UnitFrameState or {}

local IsPreviewModeEnabled = Presence.IsPreviewModeEnabled
local IsPreviewIndicatorVisible = Preview.IsIndicatorVisible
local HandleVisibilityTransition = Indicators.HandleVisibilityTransition

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
        HandleVisibilityTransition(owner, frame, holder, false, "_restingLayoutRefreshQueued")
        return
    end

    local isResting = frame.unit == "player" and IsResting and IsResting()

    if IsPreviewModeEnabled() then
        isResting = IsPreviewIndicatorVisible(frame, "resting")
    end

    if not isResting then
        HandleVisibilityTransition(owner, frame, holder, false, "_restingLayoutRefreshQueued")
        return
    end

    icon:SetTexture("Interface\\CharacterFrame\\UI-StateIcon")
    icon:SetTexCoord(0, 0.5, 0, 0.421875)
    HandleVisibilityTransition(owner, frame, holder, true, "_restingLayoutRefreshQueued")
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

        if State.QueueRefresh then
            State.QueueRefresh(currentOwner, "PLAYER_UPDATE_RESTING", "layout")
        else
            C_Timer.After(0, function()
                if currentOwner and currentOwner:IsShown() then
                    owner:UpdateRestingIndicator(currentOwner)
                end
            end)
        end
    end)

    frame.RestingIndicatorEventFrame = eventFrame
end
