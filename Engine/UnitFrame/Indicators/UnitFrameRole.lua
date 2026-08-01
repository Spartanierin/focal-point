local _, FocalPoint = ...

FocalPoint.UnitFrameRole = FocalPoint.UnitFrameRole or {}
local Role = FocalPoint.UnitFrameRole

local Presence = FocalPoint.UnitFramePresence or {}
local Preview = FocalPoint.UnitFramePreview or {}
local Indicators = FocalPoint.UnitFrameIndicators or {}
local State = FocalPoint.UnitFrameState or {}
local Utils = FocalPoint.UnitFrameUtils or {}

local IsPreviewModeEnabled = Presence.IsPreviewModeEnabled
local IsPreviewIndicatorVisible = Preview.IsIndicatorVisible
local HandleVisibilityTransition = Indicators.HandleVisibilityTransition
local IsSecretValue = Utils.IsSecretValue

-- Role icon runtime keeps role evaluation and event wiring isolated.

local function NormalizeRoleValue(role)
    if IsSecretValue and IsSecretValue(role) then
        return nil
    end

    if type(role) ~= "string" then
        return nil
    end

    if role == "TANK" or role == "HEALER" or role == "DAMAGER" then
        return role
    end

    return nil
end

local function ResolveLiveRole(unit)
    if not unit or type(UnitGroupRolesAssigned) ~= "function" then
        return nil
    end

    local ok, role = pcall(UnitGroupRolesAssigned, unit)
    if not ok then
        return nil
    end

    return NormalizeRoleValue(role)
end

local function ResolvePreviewRole(frame)
    local preview = Preview.GetTestValues and Preview.GetTestValues(frame) or nil
    return NormalizeRoleValue(preview and preview.role or nil)
end

function Role.Update(owner, frame)
    if not frame or not frame.Elements or not frame.Elements.RoleIcon then
        return
    end

    local holder = frame.Elements.RoleIcon
    local icon = holder.Texture or holder
    local config = frame.config
    local roleConfig = config and config.RoleIcon or nil

    if Preview.ShouldShowComponent and Preview.ShouldShowComponent("indicators", { frame = frame }) == false then
        HandleVisibilityTransition(owner, frame, holder, false, "_roleLayoutRefreshQueued")
        return
    end

    if not roleConfig or roleConfig.enabled == false then
        HandleVisibilityTransition(owner, frame, holder, false, "_roleLayoutRefreshQueued")
        return
    end

    local role = ResolveLiveRole(frame.unit)

    if not role and IsPreviewModeEnabled() and IsPreviewIndicatorVisible(frame, "role") then
        role = ResolvePreviewRole(frame)
    end

    if role == "TANK" then
        icon:SetAtlas("UI-LFG-RoleIcon-Tank-Micro-Raid", true)
    elseif role == "HEALER" then
        icon:SetAtlas("UI-LFG-RoleIcon-Healer-Micro-Raid", true)
    elseif role == "DAMAGER" then
        icon:SetAtlas("UI-LFG-RoleIcon-DPS-Micro-Raid", true)
    else
        HandleVisibilityTransition(owner, frame, holder, false, "_roleLayoutRefreshQueued")
        return
    end

    HandleVisibilityTransition(owner, frame, holder, true, "_roleLayoutRefreshQueued")
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
                    owner:UpdateRoleIcon(currentOwner)
                end
            end)
        end
    end)

    frame.RoleIconEventFrame = eventFrame
end
