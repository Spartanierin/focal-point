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
    ["selection-simulated"] = true,
}

local function NormalizeUnitKey(unit)
    if type(unit) ~= "string" or unit == "" then
        return nil
    end
    return unit:match("^boss%d+$") and "boss" or unit
end

local function GetSelectedObject()
    local selection = FocalPoint.GUI
        and FocalPoint.GUI.Editor
        and FocalPoint.GUI.Editor.ObjectSelection
        or nil
    return selection and selection.GetSelectedObject and selection.GetSelectedObject() or nil
end

local function GetObjectKey(objectRef)
    return type(objectRef) == "table"
        and (objectRef.objectKey or objectRef.barKey or objectRef.auraKey or objectRef.indicatorKey)
        or nil
end

function Policy.IsSelectionPreview(frame, objectRef)
    if not Policy.IsNormalEditorActive() or type(frame) ~= "table" or type(objectRef) ~= "table" then
        return false
    end

    local selected = GetSelectedObject()
    if type(selected) ~= "table" or selected.kind ~= objectRef.kind then
        return false
    end
    if NormalizeUnitKey(selected.unit) ~= NormalizeUnitKey(frame._fpUnit) then
        return false
    end

    if selected.kind == "text" then
        return selected.textKey == objectRef.textKey
    elseif selected.kind == "decoration" then
        return selected.decorationId == objectRef.decorationId
    end

    return GetObjectKey(selected) == GetObjectKey(objectRef)
end

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
    local objectRef = options.objectRef or {
        kind = "bar",
        objectKey = componentKey,
    }
    local selectionPreview = Policy.IsSelectionPreview(frame, objectRef)
    local enabled = options.enabled
    if enabled == nil then
        enabled = Policy.IsComponentEnabled(frame, componentKey)
    end

    if enabled == false then
        return selectionPreview and "selection-simulated" or "hidden"
    end

    if Policy.IsExplicitPreviewMode() then
        return "detailed-simulated"
    end

    if selectionPreview and options.hasLiveData ~= true and options.canSimulate ~= false then
        return "selection-simulated"
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

    if state == "editor-simulated" or state == "selection-simulated" then
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
