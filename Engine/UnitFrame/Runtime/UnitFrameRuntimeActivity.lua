local _, FocalPoint = ...

FocalPoint.UnitFrameRuntimeActivity = FocalPoint.UnitFrameRuntimeActivity or {}
local RuntimeActivity = FocalPoint.UnitFrameRuntimeActivity

local Utils = FocalPoint.UnitFrameUtils or {}

local SHOW_FIELD_BY_BAR = {
    PowerBar = "showPowerBar",
    CastBar = "showCastBar",
    NormalAbsorbBar = "showNormalAbsorbBar",
    HealingAbsorbBar = "showHealingAbsorbBar",
}

local TRUE_ONLY_SHOW_BARS = {
    ClassPowerBar = "showClassPowerBar",
    AlternativePowerBar = "showAlternativePowerBar",
}

local function NormalizeUnitKey(unit)
    if type(unit) ~= "string" or unit == "" then
        return nil
    end
    if unit:match("^boss%d+$") then
        return "boss"
    end
    return unit
end

local function GetUnitConfig(frame)
    if type(frame) ~= "table" then
        return nil
    end
    if type(frame.config) == "table" then
        return frame.config
    end
    if Utils.GetUnitDB then
        return Utils.GetUnitDB(NormalizeUnitKey(frame.unit))
    end
    return nil
end

local function BuildBarRef(frame, objectKey)
    local unit = NormalizeUnitKey(frame and frame.unit)
    if not unit or type(objectKey) ~= "string" or objectKey == "" then
        return nil
    end
    return {
        kind = "bar",
        unit = unit,
        objectKey = objectKey,
    }
end

local function GetObjectKey(objectRef)
    if type(objectRef) ~= "table" then
        return nil
    end
    return objectRef.objectKey or objectRef.barKey or objectRef.auraKey or objectRef.indicatorKey
end

local function IsComponentEnabled(unitConfig, objectRef)
    local objectKey = GetObjectKey(objectRef)
    local showField = SHOW_FIELD_BY_BAR[objectKey]
    if showField then
        return unitConfig[showField] ~= false
    end

    local trueOnlyShowField = TRUE_ONLY_SHOW_BARS[objectKey]
    if trueOnlyShowField then
        return unitConfig[trueOnlyShowField] == true
    end

    if objectRef.kind == "aura" then
        local config = unitConfig[objectRef.auraKey or objectRef.objectKey]
        return type(config) ~= "table" or config.enabled ~= false
    end

    if objectRef.kind == "indicator" then
        local config = unitConfig[objectRef.indicatorKey or objectRef.objectKey]
        return type(config) ~= "table" or config.enabled ~= false
    end

    return true
end

function RuntimeActivity.ShouldRunComponent(frame, objectRef)
    local unitConfig = GetUnitConfig(frame)
    if type(unitConfig) ~= "table" then
        return false
    end

    if type(objectRef) == "string" then
        objectRef = BuildBarRef(frame, objectRef)
    end
    if type(objectRef) ~= "table" then
        return false
    end

    local Presence = FocalPoint.CompositionPresence
    if Presence and type(Presence.IsPresent) == "function" and Presence.IsPresent(unitConfig, objectRef) ~= true then
        return false
    end

    return IsComponentEnabled(unitConfig, objectRef)
end

function RuntimeActivity.ClearComponentVisual(frame, objectKey)
    local element = frame and frame.Elements and frame.Elements[objectKey]
    if not element then
        return false
    end
    if element.SetMinMaxValues then
        element:SetMinMaxValues(0, 1)
    end
    if element.SetValue then
        element:SetValue(0)
    end
    if element.bg and element.bg.Hide then
        element.bg:Hide()
    end
    if element.icon then
        if element.icon.SetTexture then
            element.icon:SetTexture(nil)
        end
        if element.icon.Hide then
            element.icon:Hide()
        end
    end
    if element.Hide then
        element:Hide()
    end
    return true
end

return RuntimeActivity
