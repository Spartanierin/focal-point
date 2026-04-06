local _, ns = ...

ns.GUI = ns.GUI or {}
ns.GUI.Pages = ns.GUI.Pages or {}

local AceGUI = LibStub("AceGUI-3.0")
local L = ns.L
local FormWidgets = ns.GUI.Helpers and ns.GUI.Helpers.FormWidgets
local FormLayoutRuntime = ns.GUI.Helpers and ns.GUI.Helpers.FormLayoutRuntime
local TagDatabaseFormLayout = ns.GUI.Layouts and ns.GUI.Layouts.TagDatabase and ns.GUI.Layouts.TagDatabase.Form

local TagDatabasePage = {}
ns.GUI.Pages.TagDatabase = TagDatabasePage

local CATEGORY_ORDER = {
    "INFO_TAG_CATEGORY_FORMAT",
    "INFO_TAG_CATEGORY_HEALTH",
    "INFO_TAG_CATEGORY_POWER",
    "INFO_TAG_CATEGORY_CAST",
    "INFO_TAG_CATEGORY_UNIT",
    "INFO_TAG_CATEGORY_STATUS",
}

local fallbackRootState = {}
local windowContext

local CreateBodyText = FormWidgets.CreateBodyText
local StyleDropdown = FormWidgets.StyleDropdown
local ApplyWindowChrome = FormWidgets.ApplyWindowChrome
local ResolveItemColor = FormWidgets.ResolveItemColor

local function T(key, fallback)
    return (L and L[key]) or fallback or ""
end

local function GetTagDatabaseState(deps)
    local rootState = (deps and deps.GetGUIState and deps.GetGUIState()) or fallbackRootState
    rootState.tagDatabase = rootState.tagDatabase or {}

    local state = rootState.tagDatabase
    if type(state.category) ~= "string" then
        state.category = ""
    end
    if type(state.tagIndex) ~= "string" then
        state.tagIndex = "1"
    end

    return state
end

local function BuildCategoryEntries(tagDatabase)
    local grouped = {}
    for _, def in ipairs(tagDatabase or {}) do
        grouped[def.category] = grouped[def.category] or {}
        table.insert(grouped[def.category], def)
    end

    for _, entries in pairs(grouped) do
        table.sort(entries, function(a, b)
            return (a.token or "") < (b.token or "")
        end)
    end

    return grouped
end

local function BuildCategoryList(grouped)
    local list = {}
    for _, categoryKey in ipairs(CATEGORY_ORDER) do
        if grouped[categoryKey] and #grouped[categoryKey] > 0 then
            list[categoryKey] = T(categoryKey)
        end
    end
    return list
end

local function FindDefaultCategory(grouped)
    for _, categoryKey in ipairs(CATEGORY_ORDER) do
        if grouped[categoryKey] and #grouped[categoryKey] > 0 then
            return categoryKey
        end
    end
    return nil
end

local function BuildTagList(entries)
    local list = {}
    for index, def in ipairs(entries or {}) do
        list[tostring(index)] = def.token or ""
    end
    return list
end

local function CollectTagDatabase()
    local tagDatabase = ns.UnitFrame and ns.UnitFrame.GetTagDatabase and ns.UnitFrame:GetTagDatabase() or {}
    local grouped = BuildCategoryEntries(tagDatabase)
    local defaultCategory = FindDefaultCategory(grouped)

    return tagDatabase, grouped, defaultCategory
end

local function CenterWindow(window)
    local frame = window and window.frame
    if not frame then
        return
    end

    frame:ClearAllPoints()
    frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
end

local function FocusWindow(window)
    local frame = window and window.frame
    if not frame then
        return
    end

    if frame.IsShown and not frame:IsShown() then
        CenterWindow(window)
    end

    if window.Show then
        window:Show()
    elseif frame.Show then
        frame:Show()
    end

    frame:SetFrameStrata("FULLSCREEN_DIALOG")
    frame:SetToplevel(true)
    if frame.Raise then
        frame:Raise()
    end
end

local function ResolveItemText(item)
    if not item then
        return ""
    end

    if item.textKey then
        return T(item.textKey)
    end

    return item.text or ""
end

local function CreateItemWidget(group, item, props)
    if not props or not props.widget then
        return nil
    end

    if props.widget == "label" then
        local label = CreateBodyText(
            ResolveItemText(props),
            props.role or "label",
            props.size or 12,
            ResolveItemColor(props.colorKey),
            props.width,
            props.fullWidth
        )
        if props.justifyH and label.label and label.label.SetJustifyH then
            label.label:SetJustifyH(props.justifyH)
        end
        return label
    end

    if props.widget == "dropdown" then
        local dropdown = AceGUI:Create("Dropdown")
        if props.label ~= nil then
            dropdown:SetLabel(props.label)
        else
            dropdown:SetLabel(T(props.labelKey))
        end
        if props.fitGroupWidth then
            dropdown:SetWidth((group.frame and group.frame.width or group.width or props.groupWidthFallback or 332) - 4)
        elseif props.fullWidth ~= false then
            dropdown:SetFullWidth(true)
        end
        StyleDropdown(dropdown, props.fieldVariant or "neutral")
        return dropdown
    end

    return nil
end

local function RefreshWindowState()
    if not windowContext then
        return
    end

    local state = windowContext.state
    local tagDatabase, grouped, defaultCategory = CollectTagDatabase()

    windowContext.grouped = grouped
    windowContext.defaultCategory = defaultCategory

    if defaultCategory and not grouped[state.category] then
        state.category = defaultCategory
        state.tagIndex = "1"
    end

    local categoryList = BuildCategoryList(grouped)
    windowContext.categorySelect:SetList(categoryList)
    windowContext.categorySelect:SetValue(state.category ~= "" and state.category or nil)

    if #tagDatabase == 0 or not defaultCategory then
        windowContext.emptyState:SetText(T("INFO_COMMON_UNAVAILABLE"))
        windowContext.emptyState.frame:Show()
        windowContext.filtersGroup.frame:Hide()
        windowContext.detailsGroup.frame:Hide()
        return
    end

    windowContext.emptyState.frame:Hide()
    windowContext.filtersGroup.frame:Show()
    windowContext.detailsGroup.frame:Show()

    local entries = grouped[state.category] or {}
    if #entries == 0 then
        state.tagIndex = nil
        windowContext.tagSelect:SetList({})
        windowContext.tagSelect:SetValue(nil)
        windowContext.tokenValue:SetText("-")
        windowContext.descriptionValue:SetText("-")
        windowContext.exampleValue:SetText("-")
        windowContext.hintValue:SetText(T("INFO_TAG_DATABASE_USAGE_HINT"))
        return
    end

    local selectedIndex = tonumber(state.tagIndex or "1") or 1
    if selectedIndex < 1 or selectedIndex > #entries then
        selectedIndex = 1
    end

    state.tagIndex = tostring(selectedIndex)
    windowContext.tagSelect:SetList(BuildTagList(entries))
    windowContext.tagSelect:SetValue(state.tagIndex)

    local entry = entries[selectedIndex]
    if not entry then
        windowContext.tokenValue:SetText("-")
        windowContext.descriptionValue:SetText("-")
        windowContext.exampleValue:SetText("-")
        return
    end

    windowContext.tokenValue:SetText(entry.token or "-")
    windowContext.descriptionValue:SetText(T(entry.description, entry.description or "-"))
    windowContext.exampleValue:SetText(entry.example or "-")
    windowContext.hintValue:SetText(T("INFO_TAG_DATABASE_USAGE_HINT"))
end

local function CreateWindowContent(window, state)
    local groups, widgets = FormLayoutRuntime.BuildLayout(window, TagDatabaseFormLayout, {
        createItemWidget = CreateItemWidget,
    })
    local root = groups.Root

    local filtersGroup = groups.ColumnContainer

    local detailsGroup = groups.Footer

    return {
        window = window,
        state = state,
        root = root,
        filtersGroup = filtersGroup,
        detailsGroup = detailsGroup,
        categorySelect = widgets.categorySelect,
        tagSelect = widgets.tagSelect,
        tokenValue = widgets.tokenValue,
        descriptionValue = widgets.descriptionValue,
        exampleValue = widgets.exampleValue,
        hintValue = widgets.hintValue,
        emptyState = widgets.emptyState,
    }
end

local function WireWindowCallbacks(context)
    context.categorySelect:SetCallback("OnValueChanged", function(_, _, value)
        context.state.category = value or context.defaultCategory or ""
        context.state.tagIndex = "1"
        RefreshWindowState()
    end)

    context.tagSelect:SetCallback("OnValueChanged", function(_, _, value)
        context.state.tagIndex = value or "1"
        RefreshWindowState()
    end)
end

local function CreateWindow(state)
    local window = AceGUI:Create("Window")
    window:SetTitle(T("INFO_TAG_DATABASE_TITLE"))
    window:SetLayout("Fill")
    window:SetWidth(760)
    window:SetHeight(540)
    window:EnableResize(false)

    if window.frame then
        window.frame:SetClampedToScreen(true)
    end

    ApplyWindowChrome(window)
    CenterWindow(window)

    local context = CreateWindowContent(window, state)
    windowContext = context
    WireWindowCallbacks(context)

    window:SetCallback("OnClose", function()
        if ns.GUI and ns.GUI.ResetStatusText then
            ns.GUI:ResetStatusText()
        end
    end)

    return context
end

function TagDatabasePage.OpenWindow(deps)
    local state = GetTagDatabaseState(deps)
    local _, grouped, defaultCategory = CollectTagDatabase()

    if defaultCategory and not grouped[state.category] then
        state.category = defaultCategory
        state.tagIndex = "1"
    end

    if not windowContext or not windowContext.window or not windowContext.window.frame then
        CreateWindow(state)
    else
        windowContext.state = state
    end

    RefreshWindowState()
    FocusWindow(windowContext.window)
end

function TagDatabasePage.HideWindow()
    if not windowContext or not windowContext.window then
        return
    end

    if windowContext.window.Hide then
        windowContext.window:Hide()
    elseif windowContext.window.frame and windowContext.window.frame.Hide then
        windowContext.window.frame:Hide()
    end
end

return TagDatabasePage
