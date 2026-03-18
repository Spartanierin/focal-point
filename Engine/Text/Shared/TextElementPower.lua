local _, FocalPoint = ...

FocalPoint.TextElementPower = FocalPoint.TextElementPower or {}
local Power = FocalPoint.TextElementPower

-- Secondary power helpers stay separate so the main text runtime does not
-- need to keep specialization and fallback logic inline.

local SECONDARY_POWER_BAR_SPECS = {
    [258] = 0, -- Shadow Priest -> Mana
    [262] = 0, -- Elemental Shaman -> Mana
}

function Power.GetLiveValue(frame, key, fallback)
    if frame and frame.LiveValues and frame.LiveValues[key] ~= nil then
        return frame.LiveValues[key]
    end

    return fallback
end

function Power.GetPlayerSpecializationID()
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

function Power.GetSecondaryPowerTypeForUnit(unit)
    if unit ~= "player" then
        return nil
    end

    local specializationID = Power.GetPlayerSpecializationID()
    if not specializationID then
        return nil
    end

    return SECONDARY_POWER_BAR_SPECS[specializationID]
end

function Power.GetSecondaryPowerValues(unit)
    local secondaryPowerType = Power.GetSecondaryPowerTypeForUnit(unit)
    if secondaryPowerType == nil or not UnitPower or not UnitPowerMax then
        return nil, 0, 0
    end

    return secondaryPowerType, UnitPower(unit, secondaryPowerType) or 0, UnitPowerMax(unit, secondaryPowerType) or 0
end

function Power.GetSecondaryPowerDisplayValues(unit)
    local secondaryPowerType, currentValue, maxValue = Power.GetSecondaryPowerValues(unit)
    if secondaryPowerType == nil then
        return nil, "0", "0", 0
    end

    local currentTextOk, currentText = pcall(tostring, currentValue)
    local maxTextOk, maxText = pcall(tostring, maxValue)

    if not currentTextOk or type(currentText) ~= "string" then
        currentText = "0"
    end

    if not maxTextOk or type(maxText) ~= "string" then
        maxText = "0"
    end

    local maxNumberOk, maxNumber = pcall(tonumber, maxText)
    if not maxNumberOk or type(maxNumber) ~= "number" then
        maxNumber = 0
    end

    return secondaryPowerType, currentText, maxText, maxNumber
end
