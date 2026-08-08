local _, FocalPoint = ...

FocalPoint.UnitFramePreview = FocalPoint.UnitFramePreview or {}
local Preview = FocalPoint.UnitFramePreview
local Demo = FocalPoint.UnitFrameDemoEnvironment or {}
local Utils = FocalPoint.UnitFrameUtils or {}
local ToSafeNumberValue = Utils.ToSafeNumberValue
local FormatDisplayNumber = Utils.FormatDisplayNumber

local ALTERNATE_POWER_INDEX = Enum and Enum.PowerType and Enum.PowerType.Alternate or 10
local MANA_POWER_INDEX = Enum and Enum.PowerType and Enum.PowerType.Mana or 0

-- Compatibility facade for older callers; UnitFrameDemoEnvironment owns mode decisions.

local STRUCTURAL_COMPONENTS = {
    background = true,
    border = true,
    health = true,
    power = true,
    classPower = true,
    alternativePower = true,
    portrait = true,
    castBar = true,
    texts = true,
}

local DECORATIVE_COMPONENTS = {
    auras = true,
    indicators = true,
    absorbs = true,
    rareEliteRaid = true,
    resting = true,
    distanceRange = true,
    statusIcons = true,
    demoOnlyMarkers = true,
}

local function IsTextEditMode()
    local interactionMode = FocalPoint
        and FocalPoint.GUI
        and FocalPoint.GUI.Editor
        and FocalPoint.GUI.Editor.InteractionMode

    return interactionMode
        and interactionMode.IsTextMode
        and interactionMode.IsTextMode()
        or false
end

local function ResolveDemoModeForUnit(unit, caller)
    if type(unit) ~= "string" or unit == "" then
        return "live"
    end
    if Demo.ResolveMode then
        local mode = Demo.ResolveMode({ unit = unit }, caller or "preview")
        return mode or "live"
    end
    return "live"
end

function Preview.IsTextEditMode()
    return IsTextEditMode()
end

function Preview.ResolveComponentState(componentKey, context)
    local key = tostring(componentKey or "")
    local textMode = IsTextEditMode()

    if textMode and DECORATIVE_COMPONENTS[key] then
        return {
            visible = false,
            reason = "text-edit-decorative-hidden",
            class = "decorative",
        }
    end

    if STRUCTURAL_COMPONENTS[key] then
        return {
            visible = true,
            reason = textMode and "text-edit-structural-visible" or "normal-structural",
            class = "structural",
        }
    end

    return {
        visible = true,
        reason = textMode and "text-edit-unclassified-visible" or "normal-unclassified",
        class = "unclassified",
    }
end

function Preview.ShouldShowComponent(componentKey, context)
    local state = Preview.ResolveComponentState(componentKey, context)
    return not state or state.visible ~= false
end

function Preview.ShouldForceSecondaryPowerPreview(unit)
    if unit ~= "player" then
        return false
    end

    local unitConfig = FocalPoint.UnitFrameUtils
        and FocalPoint.UnitFrameUtils.GetUnitDB
        and FocalPoint.UnitFrameUtils.GetUnitDB(unit)
    if type(unitConfig) ~= "table" or unitConfig.showAlternativePowerBar ~= true then
        return false
    end

    return ResolveDemoModeForUnit(unit, "secondaryPower") == "detailed"
end

function Preview.IsDetailedPreviewEnabled(frame)
    return Demo.IsDetailed and Demo.IsDetailed(frame) or false
end

function Preview.IsPlaceholderPreviewEnabled(frame)
    return Demo.IsPlaceholder and Demo.IsPlaceholder(frame) or false
end

function Preview.GetTestValues(frame)
    return Demo.GetUnitValues and Demo.GetUnitValues(frame) or nil
end

function Preview.GetTestAuras(frame, groupKey)
    return Demo.GetAuras and Demo.GetAuras(frame, groupKey) or nil
end

function Preview.GetRaidTargetIndex(frame)
    return Demo.GetRaidTargetIndex and Demo.GetRaidTargetIndex(frame) or 1
end

local function GetAlternatePowerBarInfo(unit)
    if type(unit) ~= "string" or unit == "" then
        return nil, nil
    end

    if not UnitPowerBarID or not GetUnitPowerBarInfoByID then
        return nil, nil
    end

    local barID = UnitPowerBarID(unit)
    if not barID then
        return nil, nil
    end

    local barInfo = GetUnitPowerBarInfoByID(barID)
    if type(barInfo) ~= "table" then
        return barID, nil
    end

    return barID, barInfo
end

local function GetManaSecondaryPowerValues(unit)
    if unit ~= "player" or not UnitPowerMax then
        return nil, 0, 0, 0
    end

    local primaryPowerType = UnitPowerType and UnitPowerType(unit) or nil
    if primaryPowerType == MANA_POWER_INDEX then
        return nil, 0, 0, 0
    end

    local maxMana = ToSafeNumberValue(UnitPowerMax(unit, MANA_POWER_INDEX))
    if maxMana <= 0 then
        return nil, 0, 0, 0
    end

    local currentMana = UnitPower and UnitPower(unit, MANA_POWER_INDEX) or 0
    local currentManaSafe = ToSafeNumberValue(currentMana)

    if UnitPower then
        local unmodifiedMana = UnitPower(unit, MANA_POWER_INDEX, true)
        local unmodifiedManaSafe = ToSafeNumberValue(unmodifiedMana)
        if currentManaSafe <= 0 and unmodifiedManaSafe > 0 then
            currentMana = unmodifiedMana
            currentManaSafe = unmodifiedManaSafe
        end
    end

    if currentManaSafe <= 0 and maxMana > 0 and not (issecretvalue and issecretvalue(currentMana)) then
        currentMana = currentManaSafe
    end

    return MANA_POWER_INDEX, currentMana, maxMana, 0
end

local function FormatSecondaryPowerDisplayText(rawValue, safeValue)
    if FormatDisplayNumber then
        local ok, result = pcall(FormatDisplayNumber, rawValue)
        if ok and type(result) == "string" then
            return result
        end
    end

    do
        local ok, result = pcall(tostring, rawValue)
        if ok and type(result) == "string" then
            return result
        end
    end

    if FormatDisplayNumber then
        local ok, result = pcall(FormatDisplayNumber, safeValue)
        if ok and type(result) == "string" then
            return result
        end
    end

    local ok, result = pcall(tostring, safeValue or 0)
    if ok and type(result) == "string" then
        return result
    end

    return "0"
end

local function IsAlternatePowerVisible(unit, barInfo)
    if type(unit) ~= "string" or unit == "" or type(barInfo) ~= "table" then
        return false
    end

    local visibleOnRaid = barInfo.showOnRaid
        and ((UnitInParty and UnitInParty(unit)) or (UnitInRaid and UnitInRaid(unit)))
    local visibleForOthers = not barInfo.hideFromOthers
    local isPlayerUnit = UnitIsUnit and UnitIsUnit(unit, "player")

    return visibleOnRaid or visibleForOthers or isPlayerUnit
end

local function GetForcedSecondaryPowerPreviewValues(unit)
    if not Preview.ShouldForceSecondaryPowerPreview(unit) then
        return nil, 0, 0, 0
    end

    local previewValues = (Demo.GetDetailedValuesForUnit and Demo.GetDetailedValuesForUnit(unit)) or {}
    local minPower = tonumber(previewValues.altPowerMin) or 0
    local maxPower = tonumber(previewValues.altPowerMax) or 100
    local currentPower = tonumber(previewValues.altPowerCurrent)

    if type(currentPower) ~= "number" then
        currentPower = maxPower
    end

    return ALTERNATE_POWER_INDEX, currentPower, maxPower, minPower
end

function Preview.GetSecondaryPowerTypeForUnit(unit)
    local _, barInfo = GetAlternatePowerBarInfo(unit)
    if IsAlternatePowerVisible(unit, barInfo) then
        return ALTERNATE_POWER_INDEX
    end

    local manaPowerType = GetManaSecondaryPowerValues(unit)
    if manaPowerType ~= nil then
        return manaPowerType
    end

    local previewPowerType = GetForcedSecondaryPowerPreviewValues(unit)
    return previewPowerType
end

function Preview.GetSecondaryPowerValues(unit)
    local _, barInfo = GetAlternatePowerBarInfo(unit)
    if IsAlternatePowerVisible(unit, barInfo) then
        local minPower = tonumber(barInfo.minPower) or 0
        local currentPower = UnitPower and UnitPower(unit, ALTERNATE_POWER_INDEX) or minPower
        local maxPower = UnitPowerMax and UnitPowerMax(unit, ALTERNATE_POWER_INDEX) or minPower

        return ALTERNATE_POWER_INDEX, currentPower or minPower, maxPower or minPower, minPower
    end

    local manaPowerType, currentMana, maxMana, minMana = GetManaSecondaryPowerValues(unit)
    if manaPowerType ~= nil then
        return manaPowerType, currentMana, maxMana, minMana
    end

    return GetForcedSecondaryPowerPreviewValues(unit)
end

function Preview.GetSecondaryPowerDisplayValues(unit)
    local powerType, currentValue, maxValue = Preview.GetSecondaryPowerValues(unit)
    if powerType == nil then
        return nil, "0", "0", 0, 0, 0
    end

    local safeMax = ToSafeNumberValue(maxValue)
    local safeCurrent = ToSafeNumberValue(currentValue)
    local currentText = FormatSecondaryPowerDisplayText(currentValue, safeCurrent)
    local maxText = FormatSecondaryPowerDisplayText(maxValue, safeMax)

    if safeCurrent <= 0 and safeMax > 0 and UnitPowerMissing then
        local missingValue = ToSafeNumberValue(UnitPowerMissing(unit, powerType))
        if missingValue >= 0 and missingValue <= safeMax then
            safeCurrent = math.max(0, safeMax - missingValue)
        end
    end

    if safeCurrent <= 0 and safeMax > 0 and UnitPowerPercent then
        local percentValue = ToSafeNumberValue(UnitPowerPercent(unit, powerType, false, CurveConstants and CurveConstants.ScaleTo100))
        if percentValue > 0 then
            safeCurrent = math.max(0, math.min(safeMax, math.floor((safeMax * percentValue / 100) + 0.5)))
        end
    end

    return powerType,
        currentText,
        maxText,
        safeMax,
        safeCurrent,
        safeMax
end

function Preview.IsIndicatorVisible(frame, indicatorKey)
    return Demo.GetIndicatorState and Demo.GetIndicatorState(frame, indicatorKey) or false
end
