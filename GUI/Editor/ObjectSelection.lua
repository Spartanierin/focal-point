local _, ns = ...

ns.GUI = ns.GUI or {}
ns.GUI.Editor = ns.GUI.Editor or {}

local ObjectSelection = {}
ns.GUI.Editor.ObjectSelection = ObjectSelection

local EditorState = ns.GUI.Editor.State
local Constants = ns.Constants or {}
local CompositionPresence = ns.GUI.Editor.Composition and ns.GUI.Editor.Composition.Presence or ns.CompositionPresence

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

local AURA_BY_KEY = {
    Buffs = true,
    Debuffs = true,
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

local function GetUnitConfig(unitKey)
    local utils = ns.UnitFrameUtils
    if utils and type(utils.GetUnitDB) == "function" then
        return utils.GetUnitDB(unitKey)
    end

    return nil
end

local function BuildUnitRootSelection(unitKey)
    return {
        kind = "unit",
        unit = unitKey,
        sectionKey = "frame",
    }
end

local function IsCompositionPresent(unitKey, objectRef)
    local unitConfig = GetUnitConfig(unitKey)
    if CompositionPresence and type(CompositionPresence.IsPresent) == "function" then
        return CompositionPresence.IsPresent(unitConfig, objectRef) == true
    end
    return true
end

local function IsUnitPresent(unitKey)
    return IsCompositionPresent(unitKey, {
        kind = "unit",
        unit = unitKey,
    })
end

local function IsValidText(unitKey, textKey)
    local unitConfig = GetUnitConfig(unitKey)
    local texts = type(unitConfig) == "table" and unitConfig.Texts or nil
    return type(textKey) == "string" and textKey ~= ""
        and type(texts) == "table"
        and type(texts[textKey]) == "table"
end

local function IsValidAura(unitKey, auraKey)
    local unitConfig = GetUnitConfig(unitKey)
    return AURA_BY_KEY[auraKey] == true
        and type(unitConfig) == "table"
        and type(unitConfig[auraKey]) == "table"
end

local function IsValidIndicator(unitKey, indicatorKey)
    if type(indicatorKey) ~= "string" or indicatorKey == "" then
        return false
    end

    local sidebarShared = ns.GUI and ns.GUI.Editor and ns.GUI.Editor.SidebarShared or nil
    if sidebarShared and type(sidebarShared.BuildIndicatorList) == "function" then
        local list = sidebarShared.BuildIndicatorList(unitKey)
        return type(list) == "table" and list[indicatorKey] ~= nil
    end

    return false
end

local function IsValidDecoration(unitKey, decorationId)
    if type(decorationId) ~= "string" or decorationId == "" then
        return false
    end

    local unitConfig = GetUnitConfig(unitKey)
    local decorations = type(unitConfig) == "table" and unitConfig.decorations or nil
    if type(decorations) ~= "table" then
        return false
    end

    for _, decoration in ipairs(decorations) do
        if type(decoration) == "table" and decoration.id == decorationId then
            return true
        end
    end

    return false
end

local function ClearTextSelection()
    if EditorState and type(EditorState.ClearSelectedTextElement) == "function" then
        EditorState.ClearSelectedTextElement()
    end
end

local function RefreshInteractionVisuals()
    if FocalPoint and type(FocalPoint.RefreshEditorInteractionVisuals) == "function" then
        FocalPoint:RefreshEditorInteractionVisuals()
    elseif FocalPoint and type(FocalPoint.RefreshEditorSelectionVisuals) == "function" then
        FocalPoint:RefreshEditorSelectionVisuals()
    end
end

local function RefreshEditorSurface()
    if FocalPoint and FocalPoint.GUI and type(FocalPoint.GUI.RequestRefreshOptions) == "function" then
        FocalPoint.GUI:RequestRefreshOptions("ObjectSelection.CompleteSelection")
    else
        RefreshInteractionVisuals()
    end
end

local function RefreshUnitRuntime(unitKey)
    local normalizedUnit = NormalizeUnitKey(unitKey)
    if not normalizedUnit or not (FocalPoint and type(FocalPoint.RefreshUnitFrame) == "function") then
        return
    end

    FocalPoint:RefreshUnitFrame(normalizedUnit)
end

local function RefreshAuraSelectionRuntime(previousUnit)
    local selectedUnit = GetSelectedUnit()
    RefreshUnitRuntime(previousUnit)
    if selectedUnit ~= previousUnit then
        RefreshUnitRuntime(selectedUnit)
    end
end

local function CompleteSelection(previousUnit, previousObject, nextKind)
    RefreshEditorSurface()
    RefreshInteractionVisuals()
    if (type(previousObject) == "table" and previousObject.kind == "aura") or nextKind == "aura" then
        RefreshAuraSelectionRuntime(previousUnit)
    end
    local changeKind = previousUnit == GetSelectedUnit() and "sameUnitObject" or "unitChanged"
    local perf = FocalPoint and FocalPoint.SelectionPerfDebug
    if perf and perf.RecordSelection then
        perf:RecordSelection(changeKind)
    end
    return true, changeKind
end

local function SelectUnit(unitKey)
    local normalizedUnit = NormalizeUnitKey(unitKey)
    if not IsValidUnit(normalizedUnit) then
        return nil
    end

    if GetSelectedUnit() == normalizedUnit then
        return normalizedUnit
    end

    if EditorState and type(EditorState.SetSingleSelection) == "function" then
        return EditorState.SetSingleSelection(normalizedUnit)
    end

    return nil
end

function ObjectSelection.GetSelectedObject()
    local selectedUnit = GetSelectedUnit()
    if not IsValidUnit(selectedUnit) or not IsUnitPresent(selectedUnit) then
        return nil
    end

    local state = GetState()
    local scope = EditorState and type(EditorState.GetPropertyScope) == "function" and EditorState.GetPropertyScope() or nil

    if type(state) == "table"
        and state.selectedTextElementUnit == selectedUnit
        and IsValidText(selectedUnit, state.selectedTextElementId)
    then
        local objectRef = {
            kind = "text",
            unit = selectedUnit,
            textKey = state.selectedTextElementId,
            objectKey = state.selectedTextElementId,
            sectionKey = "texts",
        }
        if IsCompositionPresent(selectedUnit, objectRef) then
            return objectRef
        end
        return BuildUnitRootSelection(selectedUnit)
    end

    local scopeKind = type(scope) == "table" and scope.kind or nil
    if scopeKind == "aura" then
        local auraKey = scope.auraKey or scope.objectKey
        if IsValidAura(selectedUnit, auraKey) then
            local objectRef = {
                kind = "aura",
                unit = selectedUnit,
                auraKey = auraKey,
                objectKey = auraKey,
                sectionKey = "auras",
            }
            if IsCompositionPresent(selectedUnit, objectRef) then
                return objectRef
            end
            return BuildUnitRootSelection(selectedUnit)
        end
        return BuildUnitRootSelection(selectedUnit)
    end

    if scopeKind == "indicator" then
        local indicatorKey = scope.indicatorKey or scope.objectKey
        if IsValidIndicator(selectedUnit, indicatorKey) then
            local objectRef = {
                kind = "indicator",
                unit = selectedUnit,
                indicatorKey = indicatorKey,
                objectKey = indicatorKey,
                sectionKey = "indicators",
            }
            if IsCompositionPresent(selectedUnit, objectRef) then
                return objectRef
            end
            return BuildUnitRootSelection(selectedUnit)
        end
        return BuildUnitRootSelection(selectedUnit)
    end

    if scopeKind == "decoration" then
        local decorationId = scope.decorationId or scope.objectKey
        if IsValidDecoration(selectedUnit, decorationId) then
            local objectRef = {
                kind = "decoration",
                unit = selectedUnit,
                decorationId = decorationId,
                objectKey = decorationId,
                sectionKey = "decoration",
            }
            if IsCompositionPresent(selectedUnit, objectRef) then
                return objectRef
            end
            return BuildUnitRootSelection(selectedUnit)
        end
        return BuildUnitRootSelection(selectedUnit)
    end

    local sectionKey = type(scope) == "table" and scope.kind == "unit" and scope.sectionKey or nil
    if sectionKey == "absorbs" then
        local objectKey = type(scope) == "table" and scope.objectKey or nil
        if ABSORB_BAR_BY_OBJECT[objectKey] then
            local objectRef = {
                kind = "bar",
                unit = selectedUnit,
                objectKey = objectKey,
                sectionKey = sectionKey,
            }
            if IsCompositionPresent(selectedUnit, objectRef) then
                return objectRef
            end
            return BuildUnitRootSelection(selectedUnit)
        end
        return BuildUnitRootSelection(selectedUnit)
    end

    local objectKey = BAR_BY_SECTION[sectionKey or ""]
    if objectKey then
        local objectRef = {
            kind = "bar",
            unit = selectedUnit,
            objectKey = objectKey,
            sectionKey = sectionKey,
        }
        if IsCompositionPresent(selectedUnit, objectRef) then
            return objectRef
        end
        return BuildUnitRootSelection(selectedUnit)
    end

    return BuildUnitRootSelection(selectedUnit)
end

function ObjectSelection.SelectUnitRoot(unitKey)
    return ObjectSelection.SelectObject({
        kind = "unit",
        unit = unitKey,
    })
end

function ObjectSelection.SelectObject(objectRef)
    if type(objectRef) ~= "table" then
        return false
    end

    local kind = objectRef.kind
    local unit = NormalizeUnitKey(objectRef.unit)
    if not IsValidUnit(unit) or not IsUnitPresent(unit) then
        return false
    end
    local previousUnit = GetSelectedUnit()
    local previousObject = ObjectSelection.GetSelectedObject()

    if kind == "unit" then
        if not SelectUnit(unit) then
            return false
        end
        ClearTextSelection()
        if EditorState and type(EditorState.ClearPropertyScope) == "function" then
            EditorState.ClearPropertyScope()
        end
        return CompleteSelection(previousUnit, previousObject, kind)
    end

    if kind == "bar" then
        local sectionKey = SECTION_BY_BAR[objectRef.objectKey]
        if not sectionKey then
            return false
        end
        local barRef = {
            kind = "bar",
            unit = unit,
            objectKey = objectRef.objectKey,
        }
        if not IsCompositionPresent(unit, barRef) then
            return false
        end
        if not SelectUnit(unit) then
            return false
        end
        ClearTextSelection()
        if EditorState and type(EditorState.SetPropertyScope) == "function" then
            local scopeObjectKey = sectionKey == "absorbs" and objectRef.objectKey or nil
            local scope = EditorState.SetPropertyScope("unit", sectionKey, scopeObjectKey)
            if scope ~= nil then
                return CompleteSelection(previousUnit, previousObject, kind)
            end
        end
    end

    if kind == "text" then
        local textKey = objectRef.textKey or objectRef.objectKey
        local textRef = {
            kind = "text",
            unit = unit,
            textKey = textKey,
            objectKey = textKey,
        }
        if not IsValidText(unit, textKey) or not IsCompositionPresent(unit, textRef) or not SelectUnit(unit) then
            return false
        end
        if EditorState and type(EditorState.SetSelectedTextElement) == "function" then
            local selectedUnit, selectedTextKey = EditorState.SetSelectedTextElement(unit, textKey)
            if selectedUnit and selectedTextKey then
                if EditorState and type(EditorState.SetPropertyScope) == "function" then
                    EditorState.SetPropertyScope("text", "texts", selectedTextKey)
                end
                return CompleteSelection(previousUnit, previousObject, kind)
            end
        end
    end

    if kind == "aura" then
        local auraKey = objectRef.auraKey or objectRef.objectKey
        local auraRef = {
            kind = "aura",
            unit = unit,
            objectKey = auraKey,
            auraKey = auraKey,
        }
        if not IsValidAura(unit, auraKey) or not IsCompositionPresent(unit, auraRef) or not SelectUnit(unit) then
            return false
        end
        ClearTextSelection()
        if EditorState and type(EditorState.SetSelectedAuraKey) == "function" then
            EditorState.SetSelectedAuraKey(auraKey)
        end
        if EditorState and type(EditorState.SetPropertyScope) == "function" then
            local scope = EditorState.SetPropertyScope("aura", "auras", auraKey)
            if scope ~= nil then
                return CompleteSelection(previousUnit, previousObject, kind)
            end
        end
    end

    if kind == "indicator" then
        local indicatorKey = objectRef.indicatorKey or objectRef.objectKey
        local indicatorRef = {
            kind = "indicator",
            unit = unit,
            indicatorKey = indicatorKey,
            objectKey = indicatorKey,
        }
        if not IsValidIndicator(unit, indicatorKey) or not IsCompositionPresent(unit, indicatorRef) or not SelectUnit(unit) then
            return false
        end
        ClearTextSelection()
        if EditorState and type(EditorState.SetSelectedIndicatorKey) == "function" then
            EditorState.SetSelectedIndicatorKey(indicatorKey)
        end
        if EditorState and type(EditorState.SetPropertyScope) == "function" then
            local scope = EditorState.SetPropertyScope("indicator", "indicators", indicatorKey)
            if scope ~= nil then
                return CompleteSelection(previousUnit, previousObject, kind)
            end
        end
    end

    if kind == "decoration" then
        local decorationId = objectRef.decorationId or objectRef.objectKey
        local decorationRef = {
            kind = "decoration",
            unit = unit,
            decorationId = decorationId,
            objectKey = decorationId,
        }
        if not IsValidDecoration(unit, decorationId) or not IsCompositionPresent(unit, decorationRef) or not SelectUnit(unit) then
            return false
        end
        ClearTextSelection()
        local state = GetState()
        if type(state) == "table" then
            state.selectedDecorationId = decorationId
        end
        if EditorState and type(EditorState.SetPropertyScope) == "function" then
            local scope = EditorState.SetPropertyScope("decoration", "decoration", decorationId)
            if scope ~= nil then
                return CompleteSelection(previousUnit, previousObject, kind)
            end
        end
    end

    return false
end
