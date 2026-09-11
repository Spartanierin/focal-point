local _, FocalPoint = ...

FocalPoint.UnitFrameReadyCheck = FocalPoint.UnitFrameReadyCheck or {}
local ReadyCheck = FocalPoint.UnitFrameReadyCheck

local Presence = FocalPoint.UnitFramePresence or {}
local Preview = FocalPoint.UnitFramePreview or {}
local Indicators = FocalPoint.UnitFrameIndicators or {}
local State = FocalPoint.UnitFrameState or {}

local IsPreviewModeEnabled = Presence.IsPreviewModeEnabled
local IsPreviewIndicatorVisible = Preview.IsIndicatorVisible
local HandleVisibilityTransition = Indicators.HandleVisibilityTransition
local HideIndicatorVisual = Indicators.HideIndicatorVisual
local ShouldRunPresenceGatedIndicator = Indicators.ShouldRunPresenceGatedIndicator

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

    if ShouldRunPresenceGatedIndicator and not ShouldRunPresenceGatedIndicator(frame, "ReadyCheckIndicator") then
        if HideIndicatorVisual then
            HideIndicatorVisual(holder)
        end
        return
    end

    if Preview.ShouldShowComponent and Preview.ShouldShowComponent("indicators", { frame = frame }) == false then
        HandleVisibilityTransition(owner, frame, holder, false, "_readyCheckLayoutRefreshQueued")
        return
    end

    local selectionPreview = Indicators.IsSelectionPreview and Indicators.IsSelectionPreview(frame, "ReadyCheckIndicator")
    if not readyCheckConfig or (readyCheckConfig.enabled == false and not selectionPreview) then
        HandleVisibilityTransition(owner, frame, holder, false, "_readyCheckLayoutRefreshQueued")
        return
    end

    local status = frame._fpUnit and GetReadyCheckStatus and GetReadyCheckStatus(frame._fpUnit) or nil

    if not status and (selectionPreview or (IsPreviewModeEnabled() and IsPreviewIndicatorVisible(frame, "readyCheck"))) then
        local previewMap = {
            player = "ready",
            target = "notready",
            focus = "waiting",
            pet = "ready",
        }
        status = previewMap[frame._fpUnit] or "ready"
    end

    if status == "ready" then
        icon:SetTexture("Interface\\RaidFrame\\ReadyCheck-Ready")
    elseif status == "notready" then
        icon:SetTexture("Interface\\RaidFrame\\ReadyCheck-NotReady")
    elseif status == "waiting" then
        icon:SetTexture("Interface\\RaidFrame\\ReadyCheck-Waiting")
    else
        HandleVisibilityTransition(owner, frame, holder, false, "_readyCheckLayoutRefreshQueued")
        return
    end

    icon:SetTexCoord(0, 1, 0, 1)
    HandleVisibilityTransition(owner, frame, holder, true, "_readyCheckLayoutRefreshQueued")
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

    if frame._fpUnit == "target" then
        eventFrame:RegisterEvent("PLAYER_TARGET_CHANGED")
    elseif frame._fpUnit == "targettarget" then
        eventFrame:RegisterEvent("PLAYER_TARGET_CHANGED")
        eventFrame:RegisterEvent("UNIT_TARGET")
    elseif frame._fpUnit == "focustarget" then
        eventFrame:RegisterEvent("PLAYER_FOCUS_CHANGED")
        eventFrame:RegisterEvent("UNIT_TARGET")
    elseif frame._fpUnit == "focus" then
        eventFrame:RegisterEvent("PLAYER_FOCUS_CHANGED")
    elseif frame._fpUnit == "pet" then
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

        if event == "UNIT_TARGET" then
            local targetOk = currentOwner._fpUnit == "targettarget" and unit == "target"
            local focusOk = currentOwner._fpUnit == "focustarget" and unit == "focus"
            if not targetOk and not focusOk then
                return
            end
        end

        if State.QueueRefresh then
            State.QueueRefresh(currentOwner, event, "layout")
        else
            C_Timer.After(0, function()
                if currentOwner and currentOwner:IsShown() then
                    owner:UpdateReadyCheckIndicator(currentOwner)
                end
            end)
        end
    end)

    frame.ReadyCheckIndicatorEventFrame = eventFrame
end
