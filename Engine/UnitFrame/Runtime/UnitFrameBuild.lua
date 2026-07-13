local _, FocalPoint = ...

FocalPoint.UnitFrameBuild = FocalPoint.UnitFrameBuild or {}
local Build = FocalPoint.UnitFrameBuild
local Roles = FocalPoint.TextElementRoles or {}

-- Build orchestration keeps the creation and registration sequence in one
-- place so the main unit-frame runtime can stay focused on live behavior.

function Build.EnsurePlayerAltPowerText(config)
    if not config or not config.showAlternativePowerBar then
        return
    end

    config.Texts = config.Texts or {}
    if (Roles.HasRole and Roles.HasRole(config.Texts, "altpower", "AltPower")) or not FocalPoint.GetDefaultDB then
        return
    end

    local defaults = FocalPoint:GetDefaultDB()
    local defaultAltPowerText = defaults
        and defaults.profile
        and defaults.profile.Units
        and defaults.profile.Units.player
        and defaults.profile.Units.player.Texts
        and defaults.profile.Units.player.Texts.AltPower

    if defaultAltPowerText ~= nil then
        local altPowerText = CopyTable(defaultAltPowerText)
        if type(altPowerText) == "table" and (type(altPowerText.role) ~= "string" or altPowerText.role == "") then
            altPowerText.role = "altpower"
        end

        config.Texts.AltPower = altPowerText
    end
end

function Build.EnsurePlayerClassPowerText(config)
    if not config or not config.showClassPowerBar then
        return
    end

    config.Texts = config.Texts or {}
    if (Roles.HasRole and Roles.HasRole(config.Texts, "classpower", "ClassPower")) or not FocalPoint.GetDefaultDB then
        return
    end

    local defaults = FocalPoint:GetDefaultDB()
    local defaultClassPowerText = defaults
        and defaults.profile
        and defaults.profile.Units
        and defaults.profile.Units.player
        and defaults.profile.Units.player.Texts
        and defaults.profile.Units.player.Texts.ClassPower

    if defaultClassPowerText ~= nil then
        local classPowerText = CopyTable(defaultClassPowerText)
        if type(classPowerText) == "table" and (type(classPowerText.role) ~= "string" or classPowerText.role == "") then
            classPowerText.role = "classpower"
        end

        config.Texts.ClassPower = classPowerText
    end
end

function Build.CreateElements(owner, frame)
    owner:CreateHealthBar(frame)
    owner:CreatePowerBar(frame)
    owner:CreateClassPowerBar(frame)
    owner:CreateAlternativePowerBar(frame)
    owner:CreateCastBar(frame)
    owner:CreatePortrait(frame)
    owner:CreateRaidTargetIcon(frame)
    owner:CreateLeaderIcon(frame)
    owner:CreateRoleIcon(frame)
    owner:CreateCombatIndicator(frame)
    owner:CreateRestingIndicator(frame)
    owner:CreateReadyCheckIndicator(frame)
    owner:CreateClassificationIndicator(frame)
    owner:CreateTextElements(frame)
    if owner.BuildAuraElements then
        owner:BuildAuraElements(frame)
    end
end

function Build.RegisterEvents(owner, frame)
    owner:RegisterPortraitEvents(frame)
    owner:RegisterRaidTargetEvents(frame)
    owner:RegisterLeaderIconEvents(frame)
    owner:RegisterRoleIconEvents(frame)
    owner:RegisterCombatIndicatorEvents(frame)
    owner:RegisterRestingIndicatorEvents(frame)
    owner:RegisterReadyCheckIndicatorEvents(frame)
    owner:RegisterClassificationIndicatorEvents(frame)
    owner:RegisterCastBarEvents(frame)
    owner:RegisterTextEvents(frame)
    owner:RegisterVisibilityEvents(frame)
    owner:RegisterHealthBarEvents(frame)
    owner:RegisterClassPowerEvents(frame)
    owner:RegisterAlternativePowerEvents(frame)
    if owner.RegisterAuraEvents then
        owner:RegisterAuraEvents(frame)
    end
end
