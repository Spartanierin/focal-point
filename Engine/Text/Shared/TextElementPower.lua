local _, FocalPoint = ...

FocalPoint.TextElementPower = FocalPoint.TextElementPower or {}
local Power = FocalPoint.TextElementPower

-- Secondary power helpers stay separate so the main text runtime can reuse
-- the unit-frame alternate-power source without duplicating Blizzard lookups.

function Power.GetLiveValue(frame, key, fallback)
    if frame and frame.LiveValues and frame.LiveValues[key] ~= nil then
        return frame.LiveValues[key]
    end

    return fallback
end

function Power.GetSecondaryPowerTypeForUnit(unit)
    local preview = FocalPoint.UnitFramePreview or {}
    if preview.GetSecondaryPowerTypeForUnit then
        return preview.GetSecondaryPowerTypeForUnit(unit)
    end

    return nil
end

function Power.GetSecondaryPowerValues(unit)
    local preview = FocalPoint.UnitFramePreview or {}
    if preview.GetSecondaryPowerValues then
        return preview.GetSecondaryPowerValues(unit)
    end

    return nil, 0, 0, 0
end

function Power.GetSecondaryPowerDisplayValues(unit)
    local preview = FocalPoint.UnitFramePreview or {}
    if preview.GetSecondaryPowerDisplayValues then
        local secondaryPowerType, currentText, maxText, maxNumber, currentSafe, maxSafe = preview.GetSecondaryPowerDisplayValues(unit)
        return secondaryPowerType, currentText, maxText, maxNumber, currentSafe, maxSafe
    end

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

    local currentNumberOk, currentNumber = pcall(tonumber, currentText)
    if not currentNumberOk or type(currentNumber) ~= "number" then
        currentNumber = 0
    end

    return secondaryPowerType, currentText, maxText, maxNumber, currentNumber, maxNumber
end
