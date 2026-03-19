local _, FocalPoint = ...

FocalPoint.UnitFramePreview = FocalPoint.UnitFramePreview or {}
local Preview = FocalPoint.UnitFramePreview

local TEST_PREVIEW_VALUES = {
    player = {
        healthCurrent = 146000,
        healthMax = 146000,
        powerCurrent = 84,
        powerMax = 100,
        altPowerCurrent = 72,
        altPowerMax = 100,
        name = "Spartanierin",
        level = 84,
        classToken = "WARRIOR",
        role = "DAMAGER",
        race = "Mensch",
        castName = "Schildschlag",
        castDuration = 2.5,
    },
    target = {
        healthCurrent = 108000,
        healthMax = 146000,
        powerCurrent = 42,
        powerMax = 100,
        altPowerCurrent = 0,
        altPowerMax = 0,
        name = "Zielattrappe",
        level = 83,
        classToken = "PALADIN",
        role = "TANK",
        creature = "Humanoid",
        castName = "Frostblitz",
        castDuration = 2.5,
    },
    focus = {
        healthCurrent = 92000,
        healthMax = 120000,
        powerCurrent = 55,
        powerMax = 100,
        altPowerCurrent = 0,
        altPowerMax = 0,
        name = "Fokusziel",
        level = 83,
        classToken = "PRIEST",
        role = "HEALER",
        creature = "Humanoid",
        castName = "Heilung",
        castDuration = 2.5,
    },
    pet = {
        healthCurrent = 72000,
        healthMax = 90000,
        powerCurrent = 70,
        powerMax = 100,
        altPowerCurrent = 0,
        altPowerMax = 0,
        name = "Begleiter",
        level = 83,
        role = "DAMAGER",
        creature = "Wildtier",
    },
}

local SECONDARY_POWER_BAR_SPECS = {
    [258] = 0, -- Shadow Priest -> Mana
    [262] = 0, -- Elemental Shaman -> Mana
}

-- Preview helpers provide stable fake values for test/unlock mode
-- and encapsulate the small amount of secondary power lookup logic.

function Preview.GetTestValues(frame)
    if not frame or not frame.unit then
        return nil
    end

    return TEST_PREVIEW_VALUES[frame.unit] or TEST_PREVIEW_VALUES.target or TEST_PREVIEW_VALUES.player
end

function Preview.GetRaidTargetIndex(frame)
    local previewMap = {
        player = 1,
        target = 8,
        focus = 3,
        pet = 2,
        targettarget = 7,
        focustarget = 4,
        boss = 6,
    }

    return previewMap[frame and frame.unit or ""] or 1
end

function Preview.GetPlayerSpecializationID()
    if not GetSpecialization or not GetSpecializationInfo then
        return nil
    end

    local specializationIndex = GetSpecialization()
    if not specializationIndex then
        return nil
    end

    local specializationID = GetSpecializationInfo(specializationIndex)
    if type(specializationID) ~= "number" then
        return nil
    end

    return specializationID
end

function Preview.GetSecondaryPowerTypeForUnit(unit)
    if unit ~= "player" then
        return nil
    end

    local specializationID = Preview.GetPlayerSpecializationID()
    if not specializationID then
        return nil
    end

    return SECONDARY_POWER_BAR_SPECS[specializationID]
end

function Preview.GetSecondaryPowerValues(unit)
    local secondaryPowerType = Preview.GetSecondaryPowerTypeForUnit(unit)
    if secondaryPowerType == nil or not UnitPower or not UnitPowerMax then
        return nil, 0, 0
    end

    return secondaryPowerType, UnitPower(unit, secondaryPowerType) or 0, UnitPowerMax(unit, secondaryPowerType) or 0
end

function Preview.IsIndicatorVisible(frame, indicatorKey)
    if not frame or not indicatorKey or not frame.unit then
        return false
    end
    return true
end
