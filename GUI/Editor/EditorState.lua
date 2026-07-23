local _, ns = ...

ns.GUI = ns.GUI or {}
ns.GUI.Editor = ns.GUI.Editor or {}
ns.GUI.Editor.SidebarGeometry = ns.GUI.Editor.SidebarGeometry or {
    width = 285,
    top = 0,
    left = 0,
    right = 0,
}

local EditorState = {}
ns.GUI.Editor.State = EditorState
local EditorMode = ns.EditorMode or (ns.GUI.Editor and ns.GUI.Editor.Mode) or {}
local Constants = ns.Constants or {}

local DEFAULT_UNIT = "player"

local function NormalizeUnitKey(unitKey)
    if type(unitKey) ~= "string" or unitKey == "" then
        return nil
    end

    if unitKey:match("^boss%d+$") then
        return "boss"
    end

    return unitKey
end

local function BuildUnitOrderIndex()
    local index = {}
    local unitOrder = Constants.UnitOrder or {}
    for order, unitKey in ipairs(unitOrder) do
        local normalizedUnit = NormalizeUnitKey(unitKey)
        if normalizedUnit and index[normalizedUnit] == nil then
            index[normalizedUnit] = order
        end
    end

    return index
end

local UNIT_ORDER_INDEX = BuildUnitOrderIndex()

local state = {
    primaryUnit = DEFAULT_UNIT,
    selectedUnit = "player",
    selectedUnits = {
        [DEFAULT_UNIT] = true,
    },
    mode = "quick",
    selectedThemeId = "classic",
    selectedTextId = nil,
    selectedTextKey = nil,
    selectedTextElementUnit = nil,
    selectedTextElementId = nil,
    selectedIndicatorKey = "Portrait",
    selectedAuraKey = "Buffs",
    collapsedSections = {},
}

local function EnsureSelectedUnits()
    if type(state.selectedUnits) ~= "table" then
        state.selectedUnits = {}
    end

    return state.selectedUnits
end

local function CompareUnitKeys(left, right)
    local leftOrder = UNIT_ORDER_INDEX[left]
    local rightOrder = UNIT_ORDER_INDEX[right]

    if leftOrder and rightOrder and leftOrder ~= rightOrder then
        return leftOrder < rightOrder
    end

    if leftOrder then
        return true
    end

    if rightOrder then
        return false
    end

    return tostring(left) < tostring(right)
end

local function GetSortedSelectedUnits()
    local selectedUnits = EnsureSelectedUnits()
    local units = {}
    local seen = {}
    for unitKey, selected in pairs(selectedUnits) do
        local normalizedUnit = NormalizeUnitKey(unitKey)
        if selected == true and normalizedUnit and not seen[normalizedUnit] then
            seen[normalizedUnit] = true
            units[#units + 1] = normalizedUnit
        end
    end

    table.sort(units, CompareUnitKeys)
    return units
end

local function SyncSelectionAlias(primaryUnit)
    local normalizedUnit = NormalizeUnitKey(primaryUnit)
    state.primaryUnit = normalizedUnit
    state.selectedUnit = normalizedUnit
end

local function PickPrimaryUnit(preferredUnit)
    local selectedUnits = EnsureSelectedUnits()
    local normalizedPreferred = NormalizeUnitKey(preferredUnit)
    if normalizedPreferred and selectedUnits[normalizedPreferred] == true then
        return normalizedPreferred
    end

    local currentPrimary = NormalizeUnitKey(state.primaryUnit or state.selectedUnit)
    if currentPrimary and selectedUnits[currentPrimary] == true then
        return currentPrimary
    end

    local units = GetSortedSelectedUnits()
    return units[1]
end

function EditorState.Get()
    return state
end

function EditorState.GetPrimaryUnit()
    return NormalizeUnitKey(state.primaryUnit or state.selectedUnit)
end

function EditorState.GetSelectedUnits()
    return GetSortedSelectedUnits()
end

function EditorState.GetSelectedUnitCount()
    return #GetSortedSelectedUnits()
end

function EditorState.IsUnitSelected(unitKey)
    local normalizedUnit = NormalizeUnitKey(unitKey)
    if not normalizedUnit then
        return false
    end

    local selectedUnits = EnsureSelectedUnits()
    return selectedUnits[normalizedUnit] == true
end

function EditorState.SetSingleSelection(unitKey)
    local normalizedUnit = NormalizeUnitKey(unitKey)
    if not normalizedUnit then
        return nil
    end

    state.selectedUnits = {
        [normalizedUnit] = true,
    }
    SyncSelectionAlias(normalizedUnit)
    return normalizedUnit
end

function EditorState.SetPrimaryUnit(unitKey)
    local normalizedUnit = NormalizeUnitKey(unitKey)
    if not normalizedUnit then
        return nil
    end

    local selectedUnits = EnsureSelectedUnits()
    selectedUnits[normalizedUnit] = true
    SyncSelectionAlias(normalizedUnit)
    return normalizedUnit
end

function EditorState.SetSelectedUnit(unitKey)
    return EditorState.SetSingleSelection(unitKey)
end

function EditorState.ToggleUnitSelection(unitKey)
    local normalizedUnit = NormalizeUnitKey(unitKey)
    if not normalizedUnit then
        return nil
    end

    local selectedUnits = EnsureSelectedUnits()
    if selectedUnits[normalizedUnit] == true then
        selectedUnits[normalizedUnit] = nil
        SyncSelectionAlias(PickPrimaryUnit())
    else
        selectedUnits[normalizedUnit] = true
        SyncSelectionAlias(normalizedUnit)
    end

    return state.selectedUnit
end

function EditorState.ClearSelection(fallbackUnit)
    state.selectedUnits = {}
    EditorState.ClearSelectedTextElement()

    local normalizedFallback = NormalizeUnitKey(fallbackUnit)
    if normalizedFallback then
        state.selectedUnits[normalizedFallback] = true
        SyncSelectionAlias(normalizedFallback)
    else
        SyncSelectionAlias(nil)
    end
end

function EditorState.ValidateSelection(validUnitPredicate)
    local predicate = type(validUnitPredicate) == "function" and validUnitPredicate or function(unitKey)
        return NormalizeUnitKey(unitKey) ~= nil
    end
    local function isValid(unitKey)
        local ok, result = pcall(predicate, unitKey)
        return ok and result == true
    end

    local selectedUnits = EnsureSelectedUnits()
    local validatedUnits = {}
    for unitKey, selected in pairs(selectedUnits) do
        local normalizedUnit = NormalizeUnitKey(unitKey)
        if selected == true and normalizedUnit and isValid(normalizedUnit) then
            validatedUnits[normalizedUnit] = true
        end
    end

    state.selectedUnits = validatedUnits
    local primaryUnit = PickPrimaryUnit(state.primaryUnit or state.selectedUnit)
    if not primaryUnit and isValid(DEFAULT_UNIT) then
        state.selectedUnits[DEFAULT_UNIT] = true
        primaryUnit = DEFAULT_UNIT
    end

    SyncSelectionAlias(primaryUnit)
    return primaryUnit
end

function EditorState.SetMode(mode)
    state.mode = type(EditorMode.Normalize) == "function" and EditorMode.Normalize(mode) or "quick"
end

function EditorState.SetSelectedThemeId(themeId)
    if type(themeId) ~= "string" or themeId == "" then
        return
    end

    state.selectedThemeId = themeId
end

function EditorState.SetSelectedTextId(textId)
    if type(textId) ~= "string" or textId == "" then
        return
    end

    state.selectedTextId = textId
    state.selectedTextKey = textId
end

function EditorState.SetSelectedTextKey(textKey)
    EditorState.SetSelectedTextId(textKey)
end

function EditorState.SetSelectedTextElement(unitKey, textElementId)
    local normalizedUnit = NormalizeUnitKey(unitKey)
    if not normalizedUnit or type(textElementId) ~= "string" or textElementId == "" then
        return nil
    end

    state.selectedTextElementUnit = normalizedUnit
    state.selectedTextElementId = textElementId
    state.selectedTextId = textElementId
    state.selectedTextKey = textElementId
    return normalizedUnit, textElementId
end

function EditorState.GetSelectedTextElement()
    if type(state.selectedTextElementUnit) ~= "string" or state.selectedTextElementUnit == ""
        or type(state.selectedTextElementId) ~= "string" or state.selectedTextElementId == ""
    then
        return nil, nil
    end

    return state.selectedTextElementUnit, state.selectedTextElementId
end

function EditorState.ClearSelectedTextElement()
    state.selectedTextElementUnit = nil
    state.selectedTextElementId = nil
end

function EditorState.IsTextElementSelected(unitKey, textElementId)
    local normalizedUnit = NormalizeUnitKey(unitKey)
    return normalizedUnit ~= nil
        and type(textElementId) == "string"
        and textElementId ~= ""
        and state.selectedTextElementUnit == normalizedUnit
        and state.selectedTextElementId == textElementId
end

function EditorState.SetSelectedIndicatorKey(indicatorKey)
    if type(indicatorKey) ~= "string" or indicatorKey == "" then
        return
    end

    state.selectedIndicatorKey = indicatorKey
end

function EditorState.SetSelectedAuraKey(auraKey)
    if type(auraKey) ~= "string" or auraKey == "" then
        return
    end

    state.selectedAuraKey = auraKey
end

function EditorState.IsSectionCollapsed(sectionKey)
    if type(sectionKey) ~= "string" or sectionKey == "" then
        return false
    end

    return state.collapsedSections and state.collapsedSections[sectionKey] == true or false
end

function EditorState.GetSectionCollapsed(sectionKey, fallback)
    if type(sectionKey) ~= "string" or sectionKey == "" then
        return fallback and true or false
    end

    if state.collapsedSections and state.collapsedSections[sectionKey] ~= nil then
        return state.collapsedSections[sectionKey] == true
    end

    return fallback and true or false
end

function EditorState.SetSectionCollapsed(sectionKey, collapsed)
    if type(sectionKey) ~= "string" or sectionKey == "" then
        return
    end

    state.collapsedSections = state.collapsedSections or {}
    state.collapsedSections[sectionKey] = collapsed and true or false
end
