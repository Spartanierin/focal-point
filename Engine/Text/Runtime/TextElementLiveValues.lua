local _, FocalPoint = ...

FocalPoint.TextElementLiveValues = FocalPoint.TextElementLiveValues or {}

local LiveValues = FocalPoint.TextElementLiveValues
local TextUtils = FocalPoint.TextElementUtils or {}
local TextStatus = FocalPoint.TextElementStatus or {}
local TextPower = FocalPoint.TextElementPower or {}
local TextState = FocalPoint.TextElementState or {}
local Demo = FocalPoint.UnitFrameDemoEnvironment or {}
local Health = FocalPoint.UnitFrameHealth or {}

local IsPreviewModeEnabled = TextUtils.IsPreviewModeEnabled
local FormatNumber = TextUtils.FormatNumber
local FormatInteger = TextUtils.FormatInteger
local ToSafeNumber = TextUtils.ToSafeNumber
local GetCurrentStatusInfo = TextStatus.GetCurrentStatusInfo
local GetSecondaryPowerTypeForUnit = TextPower.GetSecondaryPowerTypeForUnit
local GetSecondaryPowerValues = TextPower.GetSecondaryPowerValues
local GetSecondaryPowerDisplayValues = TextPower.GetSecondaryPowerDisplayValues

local function IsSecretValue(value)
    return issecretvalue and issecretvalue(value) or false
end

local function ToKnownNumber(value)
    if value == nil or IsSecretValue(value) then
        return nil
    end

    if type(value) == "number" then
        return value
    end

    local ok, numberValue = pcall(tonumber, value)
    if ok and type(numberValue) == "number" and not IsSecretValue(numberValue) then
        return numberValue
    end

    return nil
end

local function GetSafeUnitPowerPercent(unit, powerType)
    if not UnitPowerPercent then
        return nil
    end

    local ok, percent = pcall(UnitPowerPercent, unit, powerType, false, CurveConstants and CurveConstants.ScaleTo100)
    if not ok then
        return nil
    end

    return ToKnownNumber(percent)
end

local function GetRenderableUnitPowerPercent(unit)
    if not UnitPowerPercent then
        return nil, nil
    end

    local ok, percent = pcall(UnitPowerPercent, unit, nil, true, CurveConstants and CurveConstants.ScaleTo100)
    if not ok then
        return nil, nil
    end

    local okFormat, formatted = pcall(FormatInteger, percent)
    if okFormat then
        return percent, formatted
    end

    return percent, nil
end

local function EnsureCanonicalHealthLiveValues(frame, unit)
    local live = frame.LiveValues
    local currentRaw = live.healthCurrentRaw
    local maxRaw = live.healthMaxRaw
    local currentSafe = ToKnownNumber(live.healthCurrentSafe)
    local maxSafe = ToKnownNumber(live.healthMaxSafe)

    if currentRaw ~= nil and maxRaw ~= nil and currentSafe ~= nil and maxSafe ~= nil and maxSafe > 0 then
        return currentRaw, maxRaw, currentSafe, maxSafe
    end

    local currentHealth, maxHealth
    if Health.GetCurrentValues then
        currentHealth, maxHealth = Health.GetCurrentValues(frame)
    else
        currentHealth = UnitHealth and UnitHealth(unit) or 0
        maxHealth = UnitHealthMax and UnitHealthMax(unit) or 1
    end

    currentSafe = ToSafeNumber(currentHealth)
    maxSafe = ToSafeNumber(maxHealth)
    live.healthCurrentRaw = currentHealth
    live.healthMaxRaw = maxHealth
    live.healthCurrentSafe = currentSafe
    live.healthMaxSafe = maxSafe

    return currentHealth, maxHealth, currentSafe, maxSafe
end

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

    local demoValues = Demo.GetUnitValues and Demo.GetUnitValues(frame) or nil
    if demoValues or (IsPreviewModeEnabled() and frame.TestValues) then
        local preview = demoValues or frame.TestValues
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
        local healthCurrentSafe = ToSafeNumber(healthCurrent)
        local healthMaxSafe = ToSafeNumber(healthMax)
        frame.LiveValues.healthPercentValue = healthMaxSafe > 0 and math.floor((healthCurrentSafe / healthMaxSafe) * 100) or 0
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
        local powerCurrentSafe = ToSafeNumber(powerCurrent)
        local powerMaxSafe = ToSafeNumber(powerMax)
        frame.LiveValues.powerPercentValue = powerMaxSafe > 0 and math.floor((powerCurrentSafe / powerMaxSafe) * 100) or 0
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
    local healthCurrent, healthMax, healthCurrentSafe, healthMaxSafe = EnsureCanonicalHealthLiveValues(frame, unit)
    local healthPercent = UnitHealthPercent and UnitHealthPercent(unit, true, CurveConstants and CurveConstants.ScaleTo100) or 0
    local powerCurrent = UnitPower and UnitPower(unit) or 0
    local powerMax = UnitPowerMax and UnitPowerMax(unit) or 0
    local powerType = UnitPowerType and UnitPowerType(unit) or nil
    local altPowerCurrent = 0
    local altPowerMax = 0
    local powerBar = frame.Elements and frame.Elements.PowerBar
    local alternativePowerBar = frame.Elements and frame.Elements.AlternativePowerBar
    local powerBarCurrent = powerBar and powerBar.GetValue and powerBar:GetValue() or nil
    local alternativePowerBarCurrent = alternativePowerBar and alternativePowerBar.GetValue and alternativePowerBar:GetValue() or nil
    local powerBarMax = nil
    local alternativePowerBarMax = nil

    if powerBar and powerBar.GetMinMaxValues then
        local _, maxValue = powerBar:GetMinMaxValues()
        powerBarMax = maxValue
    end

    if alternativePowerBar and alternativePowerBar.GetMinMaxValues then
        local _, maxValue = alternativePowerBar:GetMinMaxValues()
        alternativePowerBarMax = maxValue
    end

    local secondaryPowerType = GetSecondaryPowerTypeForUnit(frame.unit)
    local displayPowerType = nil
    local displayAltPowerCurrentText = nil
    local displayAltPowerMaxText = nil
    local displayAltPowerCurrentSafe = 0
    local displayAltPowerMaxSafe = 0

    local altPowerMin = 0

    if secondaryPowerType ~= nil then
        secondaryPowerType, altPowerCurrent, altPowerMax, altPowerMin = GetSecondaryPowerValues(unit)
        if GetSecondaryPowerDisplayValues then
            displayPowerType, displayAltPowerCurrentText, displayAltPowerMaxText, _, displayAltPowerCurrentSafe, displayAltPowerMaxSafe =
                GetSecondaryPowerDisplayValues(unit)
        end
    end

    frame.LiveValues.healthCurrent = healthCurrent
    frame.LiveValues.healthMax = healthMax
    frame.LiveValues.healthCurrentText = FormatNumber(healthCurrent)
    frame.LiveValues.healthMaxText = FormatNumber(healthMax)
    frame.LiveValues.healthPercentText = FormatInteger(healthPercent)
    frame.LiveValues.healthPercentValue = 0
    if healthMaxSafe > 0 and healthCurrentSafe >= 0 then
        frame.LiveValues.healthPercentValue = math.floor((healthCurrentSafe / healthMaxSafe) * 100)
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
    -- Midnight can mark power values as secret. Treat untrusted values as
    -- unknown instead of collapsing them to 0%, which would be misleading.
    local powerPercentRaw, powerPercentText = GetRenderableUnitPowerPercent(unit)
    local powerPercentValue = ToKnownNumber(powerPercentRaw) or GetSafeUnitPowerPercent(unit, powerType)
    if powerPercentValue == nil then
        local knownPowerCurrent = ToKnownNumber(powerBarCurrent) or ToKnownNumber(powerCurrent)
        local knownPowerMax = ToKnownNumber(powerBarMax) or ToKnownNumber(powerMax)
        if knownPowerCurrent and knownPowerMax and knownPowerMax > 0 then
            powerPercentValue = math.floor((knownPowerCurrent / knownPowerMax) * 100)
            powerPercentText = FormatInteger(powerPercentValue)
        end
    end
    frame.LiveValues.powerPercentValue = powerPercentValue
    frame.LiveValues.powerPercentText = powerPercentText or (powerPercentValue ~= nil and FormatInteger(powerPercentValue) or "--")

    local altPowerCurrentSafe = ToSafeNumber(altPowerCurrent)
    local altPowerMaxSafe = ToSafeNumber(altPowerMax)
    local alternativePowerBarCurrentSafe = ToSafeNumber(alternativePowerBarCurrent)
    local alternativePowerBarMaxSafe = ToSafeNumber(alternativePowerBarMax)
    local preparedAltPowerCurrentSafe = ToSafeNumber(displayAltPowerCurrentSafe)
    if preparedAltPowerCurrentSafe <= 0 then
        preparedAltPowerCurrentSafe = ToSafeNumber(frame.LiveValues.altPowerCurrentSafe)
    end
    local preparedAltPowerMaxSafe = ToSafeNumber(displayAltPowerMaxSafe)
    if preparedAltPowerMaxSafe <= 0 then
        preparedAltPowerMaxSafe = ToSafeNumber(frame.LiveValues.altPowerMaxSafe)
    end
    local preparedAltPowerCurrentText = type(displayAltPowerCurrentText) == "string" and displayAltPowerCurrentText or frame.LiveValues.altPowerCurrentText
    local preparedAltPowerMaxText = type(displayAltPowerMaxText) == "string" and displayAltPowerMaxText or frame.LiveValues.altPowerMaxText

    frame.LiveValues.altPowerCurrent = altPowerCurrentSafe
    if frame.LiveValues.altPowerCurrent <= 0 and alternativePowerBarCurrentSafe > 0 then
        frame.LiveValues.altPowerCurrent = alternativePowerBarCurrentSafe
    end
    if frame.LiveValues.altPowerCurrent <= 0 and preparedAltPowerCurrentSafe > 0 then
        frame.LiveValues.altPowerCurrent = preparedAltPowerCurrentSafe
    end

    frame.LiveValues.altPowerMax = altPowerMaxSafe
    if frame.LiveValues.altPowerMax <= 0 and alternativePowerBarMaxSafe > 0 then
        frame.LiveValues.altPowerMax = alternativePowerBarMaxSafe
    end
    if frame.LiveValues.altPowerMax <= 0 and preparedAltPowerMaxSafe > 0 then
        frame.LiveValues.altPowerMax = preparedAltPowerMaxSafe
    end
    frame.LiveValues.altPowerCurrentText = type(preparedAltPowerCurrentText) == "string" and preparedAltPowerCurrentText or FormatNumber(frame.LiveValues.altPowerCurrent)
    frame.LiveValues.altPowerMaxText = type(preparedAltPowerMaxText) == "string" and preparedAltPowerMaxText or FormatNumber(frame.LiveValues.altPowerMax)
    frame.LiveValues.altPowerCurrentSafe = ToSafeNumber(frame.LiveValues.altPowerCurrent)
    if frame.LiveValues.altPowerCurrentSafe <= 0 and preparedAltPowerCurrentSafe > 0 then
        frame.LiveValues.altPowerCurrentSafe = preparedAltPowerCurrentSafe
    end
    frame.LiveValues.altPowerMaxSafe = ToSafeNumber(frame.LiveValues.altPowerMax)
    if frame.LiveValues.altPowerMaxSafe <= 0 and preparedAltPowerMaxSafe > 0 then
        frame.LiveValues.altPowerMaxSafe = preparedAltPowerMaxSafe
    end
    frame.LiveValues.altPowerMinRaw = ToSafeNumber(altPowerMin)
    frame.LiveValues.altPowerType = displayPowerType ~= nil and displayPowerType or secondaryPowerType
    frame.LiveValues.altPowerVisible = frame.LiveValues.altPowerType ~= nil

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
