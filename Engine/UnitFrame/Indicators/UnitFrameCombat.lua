local _, FocalPoint = ...

FocalPoint.UnitFrameCombat = FocalPoint.UnitFrameCombat or {}
local Combat = FocalPoint.UnitFrameCombat

local Presence = FocalPoint.UnitFramePresence or {}

local IsPreviewModeEnabled = Presence.IsPreviewModeEnabled

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

    if not combatConfig or combatConfig.enabled == false then
        icon:SetTexture(nil)
        icon:Hide()
        holder:Hide()
        return
    end

    local inCombat = frame.unit and UnitAffectingCombat and UnitAffectingCombat(frame.unit) or false

    if IsPreviewModeEnabled() then
        inCombat = frame.unit == "player" or frame.unit == "target"
    end

    if not inCombat then
        icon:SetTexture(nil)
        icon:Hide()
        holder:Hide()
        return
    end

    icon:SetAtlas("UI-HUD-UnitFrame-Player-CombatIcon", true)
    holder:Show()
    icon:Show()
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

        C_Timer.After(0, function()
            if currentOwner and currentOwner:IsShown() then
                owner:UpdateCombatIndicator(currentOwner)
            end
        end)
    end)

    frame.CombatIndicatorEventFrame = eventFrame
end
