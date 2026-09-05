local _, FocalPoint = ...

FocalPoint.EditorVisualPolicy = FocalPoint.EditorVisualPolicy or {}
local Policy = FocalPoint.EditorVisualPolicy

local Demo = FocalPoint.UnitFrameDemoEnvironment or {}
local Presence = FocalPoint.UnitFramePresence or {}
local Utils = FocalPoint.UnitFrameUtils or {}

local BAR_SHOW_FIELDS = {
    PowerBar = "showPowerBar",
    CastBar = "showCastBar",
    ClassPowerBar = "showClassPowerBar",
    AlternativePowerBar = "showAlternativePowerBar",
    NormalAbsorbBar = "showNormalAbsorbBar",
    HealingAbsorbBar = "showHealingAbsorbBar",
}

local EXPLICIT_TRUE_FIELDS = {
    showAlternativePowerBar = true,
    showClassPowerBar = true,
}

local SIMULATED_STATES = {
    ["editor-simulated"] = true,
    ["detailed-simulated"] = true,
}

local function GetUnitConfig(frame)
    if frame and type(frame.config) == "table" then
        return frame.config
    end
    if frame and frame._fpUnit and Utils.GetUnitDB then
        return Utils.GetUnitDB(frame._fpUnit)
    end
    return nil
end

function Policy.IsExplicitPreviewMode()
    return FocalPoint.guiTestModeEnabled == true
end

function Policy.IsNormalEditorActive()
    if FocalPoint.guiTestModeEnabled == true or FocalPoint.framesUnlocked ~= true then
        return false
    end

    if type(FocalPoint.IsEditorActive) == "function" then
        local ok, active = pcall(FocalPoint.IsEditorActive, FocalPoint)
        if ok then
            return active == true
        end
    end

    return true
end

function Policy.IsComponentEnabled(frame, componentKey)
    if componentKey == "HealthBar" then
        return true
    end

    local field = BAR_SHOW_FIELDS[componentKey]
    if not field then
        return true
    end

    local config = GetUnitConfig(frame)
    if type(config) ~= "table" then
        return false
    end

    if EXPLICIT_TRUE_FIELDS[field] then
        return config[field] == true
    end

    return config[field] ~= false
end

function Policy.Resolve(frame, componentKey, options)
    options = options or {}
    local enabled = options.enabled
    if enabled == nil then
        enabled = Policy.IsComponentEnabled(frame, componentKey)
    end
    if enabled == false then
        return "hidden"
    end

    if Policy.IsExplicitPreviewMode() then
        return "detailed-simulated"
    end

    if Policy.IsNormalEditorActive() then
        return options.hasLiveData == true and "live" or "editor-simulated"
    end

    return "live"
end

function Policy.IsSimulatedState(state)
    return SIMULATED_STATES[state] == true
end

local function CopyValues(source, target)
    if type(source) ~= "table" then
        return target
    end
    for key, value in pairs(source) do
        target[key] = value
    end
    return target
end

function Policy.GetSimulationValues(frame, state)
    if not frame or not frame._fpUnit then
        return nil
    end

    if state == "detailed-simulated" then
        return Demo.GetUnitValues and Demo.GetUnitValues(frame, "detailed") or nil
    end

    if state == "editor-simulated" then
        local values = {}
        if Demo.GetDetailedValuesForUnit then
            CopyValues(Demo.GetDetailedValuesForUnit(frame._fpUnit), values)
        end
        if Demo.GetUnitValues then
            CopyValues(Demo.GetUnitValues(frame, "placeholder"), values)
        end
        return next(values) and values or nil
    end

    return nil
end

function Policy.DoesUnitHaveLiveContext(frame)
    return frame and frame._fpUnit and Presence.DoesUnitSeemPresent and Presence.DoesUnitSeemPresent(frame._fpUnit) == true or false
end
