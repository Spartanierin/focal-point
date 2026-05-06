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

local state = {
    selectedUnit = "player",
    mode = "quick",
    selectedThemeId = "classic",
    selectedTextId = nil,
    selectedTextKey = nil,
    selectedIndicatorKey = "Portrait",
    selectedAuraKey = "Buffs",
    collapsedSections = {},
}

function EditorState.Get()
    return state
end

function EditorState.SetSelectedUnit(unitKey)
    if type(unitKey) ~= "string" or unitKey == "" then
        return
    end

    state.selectedUnit = unitKey
end

function EditorState.SetMode(mode)
    if mode ~= "expert" then
        mode = "quick"
    end

    state.mode = mode
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
