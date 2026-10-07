local _, FocalPoint = ...

FocalPoint.UnitFrameBuild = FocalPoint.UnitFrameBuild or {}
local Build = FocalPoint.UnitFrameBuild

-- Build orchestration keeps the creation and registration sequence in one
-- place so the main unit-frame runtime can stay focused on live behavior.

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
