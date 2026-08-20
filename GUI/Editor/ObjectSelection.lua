local _, ns = ...

ns.GUI = ns.GUI or {}
ns.GUI.Editor = ns.GUI.Editor or {}

local ObjectSelection = {}
ns.GUI.Editor.ObjectSelection = ObjectSelection

local EditorState = ns.GUI.Editor.State
local Constants = ns.Constants or {}

local BAR_BY_SECTION = {
    health = "HealthBar",
    power = "PowerBar",
    alt_power = "AlternativePowerBar",
    class_power = "ClassPowerBar",
    cast = "CastBar",
}

local SECTION_BY_BAR = {
    HealthBar = "health",
    PowerBar = "power",
    AlternativePowerBar = "alt_power",
    ClassPowerBar = "class_power",
    CastBar = "cast",
    NormalAbsorbBar = "absorbs",
    HealingAbsorbBar = "absorbs",
}

local ABSORB_BAR_BY_OBJECT = {
    NormalAbsorbBar = true,
    HealingAbsorbBar = true,
}

local VALID_UNITS = nil

local function NormalizeUnitKey(unitKey)
    if type(unitKey) ~= "string" or unitKey == "" then
        return nil
    end

    if unitKey:match("^boss%d+$") then
        return "boss"
    end

    return unitKey
end

local function BuildValidUnits()
    local validUnits = {}
    for _, unitKey in ipairs(Constants.UnitOrder or {}) do
        local normalizedUnit = NormalizeUnitKey(unitKey)
        if normalizedUnit then
            validUnits[normalizedUnit] = true
        end
    end

    return validUnits
end

local function IsValidUnit(unitKey)
    local normalizedUnit = NormalizeUnitKey(unitKey)
    if not normalizedUnit then
        return false
    end

    VALID_UNITS = VALID_UNITS or BuildValidUnits()
    return VALID_UNITS[normalizedUnit] == true
end

local function GetState()
    if EditorState and type(EditorState.Get) == "function" then
        return EditorState.Get()
    end

    return nil
end

local function GetSelectedUnit()
    if EditorState and type(EditorState.GetPrimaryUnit) == "function" then
        return NormalizeUnitKey(EditorState.GetPrimaryUnit())
    end

    local state = GetState()
    return NormalizeUnitKey(state and state.selectedUnit)
end

local function HasSpecificUnsupportedSelection(state, scope)
    if type(state) == "table"
        and type(state.selectedTextElementUnit) == "string"
        and state.selectedTextElementUnit ~= ""
        and type(state.selectedTextElementId) == "string"
        and state.selectedTextElementId ~= ""
    then
        return true
    end

    local scopeKind = type(scope) == "table" and scope.kind or nil
    if scopeKind == "text" or scopeKind == "aura" or scopeKind == "indicator" or scopeKind == "decoration" then
        return true
    end

    return false
end

local function SelectUnit(unitKey)
    local normalizedUnit = NormalizeUnitKey(unitKey)
    if not IsValidUnit(normalizedUnit) then
        return nil
    end

    if GetSelectedUnit() == normalizedUnit then
        return normalizedUnit
    end

    if FocalPoint and type(FocalPoint.SelectEditorUnit) == "function" then
        FocalPoint:SelectEditorUnit(normalizedUnit)
        return normalizedUnit
    end

    if EditorState and type(EditorState.SetSingleSelection) == "function" then
        return EditorState.SetSingleSelection(normalizedUnit)
    end

    return nil
end

function ObjectSelection.GetSelectedObject()
    local selectedUnit = GetSelectedUnit()
    if not IsValidUnit(selectedUnit) then
        return nil
    end

    local state = GetState()
    local scope = EditorState and type(EditorState.GetPropertyScope) == "function" and EditorState.GetPropertyScope() or nil
    if HasSpecificUnsupportedSelection(state, scope) then
        return nil
    end

    local sectionKey = type(scope) == "table" and scope.kind == "unit" and scope.sectionKey or nil
    if sectionKey == "absorbs" then
        local objectKey = type(scope) == "table" and scope.objectKey or nil
        if ABSORB_BAR_BY_OBJECT[objectKey] then
            return {
                kind = "bar",
                unit = selectedUnit,
                objectKey = objectKey,
                sectionKey = sectionKey,
            }
        end
        return nil
    end

    local objectKey = BAR_BY_SECTION[sectionKey or ""]
    if objectKey then
        return {
            kind = "bar",
            unit = selectedUnit,
            objectKey = objectKey,
            sectionKey = sectionKey,
        }
    end

    return {
        kind = "unit",
        unit = selectedUnit,
        sectionKey = "frame",
    }
end

function ObjectSelection.SelectObject(objectRef)
    if type(objectRef) ~= "table" then
        return false
    end

    local kind = objectRef.kind
    local unit = NormalizeUnitKey(objectRef.unit)
    if not IsValidUnit(unit) then
        return false
    end
    local previousUnit = GetSelectedUnit()

    if kind == "unit" then
        if not SelectUnit(unit) then
            return false
        end
        if EditorState and type(EditorState.ClearPropertyScope) == "function" then
            EditorState.ClearPropertyScope()
        end
        return true, previousUnit == GetSelectedUnit() and "sameUnitObject" or "unitChanged"
    end

    if kind == "bar" then
        local sectionKey = SECTION_BY_BAR[objectRef.objectKey]
        if not sectionKey then
            return false
        end
        if not SelectUnit(unit) then
            return false
        end
        if EditorState and type(EditorState.ClearSelectedTextElement) == "function" then
            EditorState.ClearSelectedTextElement()
        end
        if EditorState and type(EditorState.SetPropertyScope) == "function" then
            local scopeObjectKey = sectionKey == "absorbs" and objectRef.objectKey or nil
            local scope = EditorState.SetPropertyScope("unit", sectionKey, scopeObjectKey)
            if scope ~= nil then
                return true, previousUnit == GetSelectedUnit() and "sameUnitObject" or "unitChanged"
            end
        end
    end

    return false
end
