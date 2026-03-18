local _, FocalPoint = ...

FocalPoint.UnitFrameRole = FocalPoint.UnitFrameRole or {}
local Role = FocalPoint.UnitFrameRole

local Presence = FocalPoint.UnitFramePresence or {}
local Preview = FocalPoint.UnitFramePreview or {}

local IsPreviewModeEnabled = Presence.IsPreviewModeEnabled

-- Role icon runtime keeps role evaluation and event wiring isolated.

function Role.Update(owner, frame)
    if not frame or not frame.Elements or not frame.Elements.RoleIcon then
        return
    end

    local holder = frame.Elements.RoleIcon
    local icon = holder.Texture or holder
    local config = frame.config
    local roleConfig = config and config.RoleIcon or nil

    if not roleConfig or roleConfig.enabled == false then
        icon:SetTexture(nil)
        icon:Hide()
        holder:Hide()
        return
    end

    local role = frame.unit and UnitGroupRolesAssigned and UnitGroupRolesAssigned(frame.unit) or nil

    if (not role or role == "NONE") and IsPreviewModeEnabled() then
        local preview = Preview.GetTestValues(frame)
        role = preview and preview.role or nil
    end

    if role == "TANK" then
        icon:SetAtlas("UI-LFG-RoleIcon-Tank-Micro-Raid", true)
    elseif role == "HEALER" then
        icon:SetAtlas("UI-LFG-RoleIcon-Healer-Micro-Raid", true)
    elseif role == "DAMAGER" then
        icon:SetAtlas("UI-LFG-RoleIcon-DPS-Micro-Raid", true)
    else
        icon:SetTexture(nil)
        icon:Hide()
        holder:Hide()
        return
    end

    holder:Show()
    icon:Show()
end

function Role.RegisterEvents(owner, frame)
    if not frame or frame.RoleIconEventFrame then
        return
    end

    local eventFrame = CreateFrame("Frame", nil, frame)
    eventFrame.owner = frame

    eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    eventFrame:RegisterEvent("GROUP_ROSTER_UPDATE")
    eventFrame:RegisterEvent("PLAYER_ROLES_ASSIGNED")

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
                owner:UpdateRoleIcon(currentOwner)
            end
        end)
    end)

    frame.RoleIconEventFrame = eventFrame
end
