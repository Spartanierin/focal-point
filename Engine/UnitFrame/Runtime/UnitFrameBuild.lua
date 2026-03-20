local _, FocalPoint = ...

FocalPoint.UnitFrameBuild = FocalPoint.UnitFrameBuild or {}
local Build = FocalPoint.UnitFrameBuild

-- Build orchestration keeps the creation and registration sequence in one
-- place so the main unit-frame runtime can stay focused on live behavior.

function Build.EnsurePlayerAltPowerText(config)
    if not config or not config.showAlternativePowerBar then
        return
    end

    config.Texts = config.Texts or {}
    if config.Texts.AltPower ~= nil or not FocalPoint.GetDefaultDB then
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
        config.Texts.AltPower = CopyTable(defaultAltPowerText)
    end
end

function Build.CreateElements(owner, frame)
    owner:CreateHealthBar(frame)
    owner:CreatePowerBar(frame)
    owner:CreateAlternativePowerBar(frame)
    owner:CreateCastBar(frame)
    owner:CreatePortrait(frame)
    owner:CreateRaidTargetIcon(frame)
    owner:CreateLeaderIcon(frame)
    owner:CreateRoleIcon(frame)
    owner:CreateCombatIndicator(frame)
    owner:CreateRestingIndicator(frame)
    owner:CreateReadyCheckIndicator(frame)
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
    owner:RegisterCastBarEvents(frame)
    owner:RegisterTextEvents(frame)
    owner:RegisterVisibilityEvents(frame)
    owner:RegisterHealthBarEvents(frame)
    owner:RegisterAlternativePowerEvents(frame)
    if owner.RegisterAuraEvents then
        owner:RegisterAuraEvents(frame)
    end
end
