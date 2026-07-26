local _, FocalPoint = ...

FocalPoint.UnitFrameCombat = FocalPoint.UnitFrameCombat or {}
local Combat = FocalPoint.UnitFrameCombat

local Presence = FocalPoint.UnitFramePresence or {}
local Preview = FocalPoint.UnitFramePreview or {}
local Indicators = FocalPoint.UnitFrameIndicators or {}
local State = FocalPoint.UnitFrameState or {}
local StatusOverlay = FocalPoint.UnitFrameStatusOverlay or {}

local IsPreviewModeEnabled = Presence.IsPreviewModeEnabled
local IsPreviewIndicatorVisible = Preview.IsIndicatorVisible
local HandleVisibilityTransition = Indicators.HandleVisibilityTransition

-- Combat indicator runtime keeps combat-state evaluation and event wiring
-- isolated from the rest of the indicator logic.

function Combat.Update(owner, frame)
    if not frame or not frame.Elements or not frame.Elements.CombatIndicator then
        return
    end

    local holder = frame.Elements.CombatIndicator
    local icon = holder.Texture or holder
    local config = frame.config
    local combatConfig = config and config.CombatIndicator or nil
    local effect = combatConfig and combatConfig.effect or "ICON"

    if Preview.ShouldShowComponent and Preview.ShouldShowComponent("indicators", { frame = frame }) == false then
        if StatusOverlay.Hide then
            StatusOverlay.Hide(holder)
        end
        HandleVisibilityTransition(owner, frame, holder, false, "_combatLayoutRefreshQueued")
        return
    end

    if not combatConfig or combatConfig.enabled == false then
        if StatusOverlay.Hide then
            StatusOverlay.Hide(holder)
        end
        HandleVisibilityTransition(owner, frame, holder, false, "_combatLayoutRefreshQueued")
        return
    end

    local inCombat = frame.unit and UnitAffectingCombat and UnitAffectingCombat(frame.unit) or false

    if IsPreviewModeEnabled() then
        inCombat = IsPreviewIndicatorVisible(frame, "combat")
    end

    if not inCombat then
        if StatusOverlay.Hide then
            StatusOverlay.Hide(holder)
        end
        HandleVisibilityTransition(owner, frame, holder, false, "_combatLayoutRefreshQueued")
        return
    end

    if effect == "FRAME_OVERLAY" then
        HandleVisibilityTransition(owner, frame, holder, true, "_combatLayoutRefreshQueued")
        if StatusOverlay.Apply then
            StatusOverlay.Apply(holder, frame, "combat")
        end
        return
    end

    if StatusOverlay.Hide then
        StatusOverlay.Hide(holder)
    end
    icon:SetAtlas("UI-HUD-UnitFrame-Player-CombatIcon", true)
    if icon.SetTexCoord then
        icon:SetTexCoord(0, 1, 0, 1)
    end
    HandleVisibilityTransition(owner, frame, holder, true, "_combatLayoutRefreshQueued")
end

function Combat.RegisterEvents(owner, frame)
    if not frame or frame.CombatIndicatorEventFrame then
        return
    end

    local eventFrame = CreateFrame("Frame", nil, frame)
    eventFrame.owner = frame

    eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    eventFrame:RegisterEvent("UNIT_FLAGS")
    eventFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
    eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")

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

    eventFrame:SetScript("OnEvent", function(_, event, unit)
        local currentOwner = eventFrame.owner
        if not currentOwner or not currentOwner:IsShown() then
            return
        end

        if event == "UNIT_FLAGS" and unit ~= currentOwner.unit then
            return
        end

        if event == "UNIT_PET" and unit ~= "player" then
            return
        end

        if event == "UNIT_TARGET" then
            local targetOk = currentOwner.unit == "targettarget" and unit == "target"
            local focusOk = currentOwner.unit == "focustarget" and unit == "focus"
            if not targetOk and not focusOk then
                return
            end
        end

        if State.QueueRefresh then
            State.QueueRefresh(currentOwner, event, "layout")
        else
            C_Timer.After(0, function()
                if currentOwner and currentOwner:IsShown() then
                    owner:UpdateCombatIndicator(currentOwner)
                end
            end)
        end
    end)

    frame.CombatIndicatorEventFrame = eventFrame
end
