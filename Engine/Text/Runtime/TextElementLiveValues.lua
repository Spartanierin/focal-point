local _, FocalPoint = ...

FocalPoint.TextElementLiveValues = FocalPoint.TextElementLiveValues or {}

local LiveValues = FocalPoint.TextElementLiveValues
local TextUtils = FocalPoint.TextElementUtils or {}
local TextStatus = FocalPoint.TextElementStatus or {}
local TextPower = FocalPoint.TextElementPower or {}
local TextState = FocalPoint.TextElementState or {}

local IsPreviewModeEnabled = TextUtils.IsPreviewModeEnabled
local FormatNumber = TextUtils.FormatNumber
local FormatInteger = TextUtils.FormatInteger
local ToSafeNumber = TextUtils.ToSafeNumber
local GetCurrentStatusInfo = TextStatus.GetCurrentStatusInfo
local GetSecondaryPowerTypeForUnit = TextPower.GetSecondaryPowerTypeForUnit
local GetSecondaryPowerValues = TextPower.GetSecondaryPowerValues

-- Builds the live text value cache that all token resolvers read from.
function LiveValues.Refresh(frame)
    if not frame or not frame.unit then
        if TextState.Reset then
            TextState.Reset(frame)
        end
        return
    end

    if TextState.Ensure then
        TextState.Ensure(frame)
    end

    frame.LiveValues = frame.LiveValues or {}

    if IsPreviewModeEnabled() and frame.TestValues then
        local preview = frame.TestValues
        local healthCurrent = preview.healthCurrent or 100
        local healthMax = preview.healthMax or 100
        local powerCurrent = preview.powerCurrent or 65
        local powerMax = preview.powerMax or 100
        local altPowerCurrent = preview.altPowerCurrent or 0
        local altPowerMax = preview.altPowerMax or 0

        frame.LiveValues.healthCurrent = healthCurrent
        frame.LiveValues.healthMax = healthMax
        frame.LiveValues.healthCurrentText = FormatNumber(healthCurrent)
        frame.LiveValues.healthMaxText = FormatNumber(healthMax)
        frame.LiveValues.healthCurrentSafe = ToSafeNumber(healthCurrent)
        frame.LiveValues.healthMaxSafe = ToSafeNumber(healthMax)
        frame.LiveValues.healthPercentValue = healthMax > 0 and math.floor((healthCurrent / healthMax) * 100) or 0
        frame.LiveValues.healthPercentText = FormatInteger(frame.LiveValues.healthPercentValue)
        frame.LiveValues.healthCurrentRaw = healthCurrent
        frame.LiveValues.healthMaxRaw = healthMax

        frame.LiveValues.powerCurrent = powerCurrent
        frame.LiveValues.powerMax = powerMax
        frame.LiveValues.powerCurrentText = FormatNumber(powerCurrent)
        frame.LiveValues.powerMaxText = FormatNumber(powerMax)
        frame.LiveValues.powerCurrentSafe = ToSafeNumber(powerCurrent)
        frame.LiveValues.powerMaxSafe = ToSafeNumber(powerMax)
        frame.LiveValues.powerCurrentRaw = powerCurrent
        frame.LiveValues.powerMaxRaw = powerMax
        frame.LiveValues.powerPercentValue = powerMax > 0 and math.floor((powerCurrent / powerMax) * 100) or 0
        frame.LiveValues.powerPercentText = FormatInteger(frame.LiveValues.powerPercentValue)

        frame.LiveValues.altPowerCurrent = altPowerCurrent
        frame.LiveValues.altPowerMax = altPowerMax
        frame.LiveValues.altPowerCurrentText = FormatNumber(altPowerCurrent)
        frame.LiveValues.altPowerMaxText = FormatNumber(altPowerMax)
        frame.LiveValues.altPowerCurrentSafe = ToSafeNumber(altPowerCurrent)
        frame.LiveValues.altPowerMaxSafe = ToSafeNumber(altPowerMax)
        frame.LiveValues.altPowerCurrentRaw = altPowerCurrent
        frame.LiveValues.altPowerMaxRaw = altPowerMax
        frame.LiveValues.statusKey = preview.statusKey or ""
        frame.LiveValues.statusText = preview.status or ""
        frame.LiveValues.statusTimerStart = preview.statusTimerStart
        frame.LiveValues.deadTimerStart = preview.deadTimerStart
        if TextState.MarkLiveValuesFresh then
            TextState.MarkLiveValuesFresh(frame)
        end
        return
    end

    local unit = frame.unit
    local healthCurrent = UnitHealth and UnitHealth(unit) or 0
    local healthMax = UnitHealthMax and UnitHealthMax(unit) or 0
    local healthPercent = UnitHealthPercent and UnitHealthPercent(unit, true, CurveConstants and CurveConstants.ScaleTo100) or 0
    local powerCurrent = UnitPower and UnitPower(unit) or 0
    local powerMax = UnitPowerMax and UnitPowerMax(unit) or 0
    local altPowerCurrent = 0
    local altPowerMax = 0
    local healthBar = frame.Elements and frame.Elements.HealthBar
    local powerBar = frame.Elements and frame.Elements.PowerBar
    local alternativePowerBar = frame.Elements and frame.Elements.AlternativePowerBar
    local healthBarCurrent = healthBar and healthBar.GetValue and healthBar:GetValue() or nil
    local powerBarCurrent = powerBar and powerBar.GetValue and powerBar:GetValue() or nil
    local alternativePowerBarCurrent = alternativePowerBar and alternativePowerBar.GetValue and alternativePowerBar:GetValue() or nil
    local healthBarMax = nil
    local powerBarMax = nil
    local alternativePowerBarMax = nil

    if healthBar and healthBar.GetMinMaxValues then
        local _, maxValue = healthBar:GetMinMaxValues()
        healthBarMax = maxValue
    end

    if powerBar and powerBar.GetMinMaxValues then
        local _, maxValue = powerBar:GetMinMaxValues()
        powerBarMax = maxValue
    end

    if alternativePowerBar and alternativePowerBar.GetMinMaxValues then
        local _, maxValue = alternativePowerBar:GetMinMaxValues()
        alternativePowerBarMax = maxValue
    end

    local secondaryPowerType = GetSecondaryPowerTypeForUnit(frame.unit)

    local altPowerMin = 0

    if secondaryPowerType ~= nil then
        secondaryPowerType, altPowerCurrent, altPowerMax, altPowerMin = GetSecondaryPowerValues(unit)
    end

    frame.LiveValues.healthCurrent = healthCurrent
    frame.LiveValues.healthMax = healthMax
    frame.LiveValues.healthCurrentText = FormatNumber(healthCurrent)
    frame.LiveValues.healthMaxText = FormatNumber(healthMax)
    frame.LiveValues.healthCurrentSafe = ToSafeNumber(healthBarCurrent)
    if frame.LiveValues.healthCurrentSafe <= 0 then
        frame.LiveValues.healthCurrentSafe = ToSafeNumber(healthCurrent)
    end
    frame.LiveValues.healthMaxSafe = ToSafeNumber(healthBarMax)
    if frame.LiveValues.healthMaxSafe <= 0 then
        frame.LiveValues.healthMaxSafe = ToSafeNumber(healthMax)
    end
    frame.LiveValues.healthPercentText = FormatInteger(healthPercent)
    frame.LiveValues.healthPercentValue = 0
    if frame.LiveValues.healthMaxSafe > 0 and frame.LiveValues.healthCurrentSafe >= 0 then
        frame.LiveValues.healthPercentValue = math.floor((frame.LiveValues.healthCurrentSafe / frame.LiveValues.healthMaxSafe) * 100)
    end
    if frame.LiveValues.healthPercentValue <= 0 then
        frame.LiveValues.healthPercentValue = ToSafeNumber(healthPercent)
    end

    frame.LiveValues.powerCurrent = powerCurrent
    frame.LiveValues.powerMax = powerMax
    frame.LiveValues.powerCurrentText = FormatNumber(powerCurrent)
    frame.LiveValues.powerMaxText = FormatNumber(powerMax)
    frame.LiveValues.powerCurrentSafe = ToSafeNumber(powerBarCurrent)
    if frame.LiveValues.powerCurrentSafe <= 0 then
        frame.LiveValues.powerCurrentSafe = ToSafeNumber(powerCurrent)
    end
    frame.LiveValues.powerMaxSafe = ToSafeNumber(powerBarMax)
    if frame.LiveValues.powerMaxSafe <= 0 then
        frame.LiveValues.powerMaxSafe = ToSafeNumber(powerMax)
    end
    frame.LiveValues.powerPercentValue = 0
    if frame.LiveValues.powerMaxSafe > 0 and frame.LiveValues.powerCurrentSafe >= 0 then
        frame.LiveValues.powerPercentValue = math.floor((frame.LiveValues.powerCurrentSafe / frame.LiveValues.powerMaxSafe) * 100)
    end
    frame.LiveValues.powerPercentText = FormatInteger(frame.LiveValues.powerPercentValue)

    local altPowerCurrentSafe = ToSafeNumber(altPowerCurrent)
    local altPowerMaxSafe = ToSafeNumber(altPowerMax)
    local alternativePowerBarCurrentSafe = ToSafeNumber(alternativePowerBarCurrent)
    local alternativePowerBarMaxSafe = ToSafeNumber(alternativePowerBarMax)

    frame.LiveValues.altPowerCurrent = altPowerCurrentSafe
    if frame.LiveValues.altPowerCurrent <= 0 and alternativePowerBarCurrentSafe > 0 then
        frame.LiveValues.altPowerCurrent = alternativePowerBarCurrentSafe
    end

    frame.LiveValues.altPowerMax = altPowerMaxSafe
    if frame.LiveValues.altPowerMax <= 0 and alternativePowerBarMaxSafe > 0 then
        frame.LiveValues.altPowerMax = alternativePowerBarMaxSafe
    end
    frame.LiveValues.altPowerCurrentText = FormatNumber(frame.LiveValues.altPowerCurrent)
    frame.LiveValues.altPowerMaxText = FormatNumber(frame.LiveValues.altPowerMax)
    frame.LiveValues.altPowerCurrentSafe = ToSafeNumber(frame.LiveValues.altPowerCurrent)
    frame.LiveValues.altPowerMaxSafe = ToSafeNumber(frame.LiveValues.altPowerMax)
    frame.LiveValues.altPowerCurrentRaw = frame.LiveValues.altPowerCurrent
    frame.LiveValues.altPowerMaxRaw = frame.LiveValues.altPowerMax
    frame.LiveValues.altPowerMinRaw = ToSafeNumber(altPowerMin)
    frame.LiveValues.altPowerType = secondaryPowerType
    frame.LiveValues.altPowerVisible = secondaryPowerType ~= nil

    local statusKey, statusText = GetCurrentStatusInfo(unit)
    local previousStatusKey = frame.LiveValues.statusKey or ""
    local now = GetTime and GetTime() or 0

    frame.LiveValues.statusKey = statusKey
    frame.LiveValues.statusText = statusText

    if statusKey == "dead" or statusKey == "ghost" then
        if previousStatusKey ~= statusKey or type(frame.LiveValues.deadTimerStart) ~= "number" then
            frame.LiveValues.deadTimerStart = now
        end
        frame.LiveValues.statusTimerStart = nil
    elseif statusKey ~= "" then
        if previousStatusKey ~= statusKey or type(frame.LiveValues.statusTimerStart) ~= "number" then
            frame.LiveValues.statusTimerStart = now
        end
        frame.LiveValues.deadTimerStart = nil
    else
        frame.LiveValues.statusTimerStart = nil
        frame.LiveValues.deadTimerStart = nil
    end

    if TextState.MarkLiveValuesFresh then
        TextState.MarkLiveValuesFresh(frame)
    end
end
