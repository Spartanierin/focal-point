local _, ns = ...

ns.GUI = ns.GUI or {}
ns.GUI.Pages = ns.GUI.Pages or {}

local AceGUI = LibStub("AceGUI-3.0")
local L = ns.L
local TextStyles = ns.GUI.Helpers and ns.GUI.Helpers.TextStyles

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

local PANEL_BACKGROUND = { 0.07, 0.08, 0.10, 0.90 }
local PANEL_BORDER = { 0.24, 0.27, 0.31, 0.92 }
local PANEL_HEADER = { 0.10, 0.11, 0.14, 0.70 }
local FIELD_BACKGROUND = { 0.10, 0.11, 0.14, 0.96 }
local FIELD_BORDER = { 0.31, 0.34, 0.39, 0.95 }
local DESCRIPTION_TEXT = { 0.68, 0.70, 0.75 }
local HINT_TEXT = { 0.70, 0.73, 0.78 }
local VALUE_TEXT = { 0.93, 0.90, 0.80 }

local function T(key, fallback)
    return (L and L[key]) or fallback
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
            list[categoryKey] = T(categoryKey, categoryKey)
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

local function ApplyTextStyle(target, role, size, alpha)
    if not target then
        return
    end

    if TextStyles and TextStyles.ApplyFontString then
        TextStyles.ApplyFontString(target, role, {
            size = size,
            alpha = alpha,
        })
    end
end

local function SetTextureColor(texture, color)
    if texture and texture.SetVertexColor and color then
        texture:SetVertexColor(color[1] or 1, color[2] or 1, color[3] or 1, color[4] or 1)
    end
end

local function CreateBodyText(text, role, size, color)
    local label = AceGUI:Create("Label")
    label:SetFullWidth(true)
    label:SetText(text or "")
    ApplyTextStyle(label.label, role or "label", size or 12, 1)

    if color and label.label and label.label.SetTextColor then
        label.label:SetTextColor(color[1] or 1, color[2] or 1, color[3] or 1, color[4] or 1)
    end

    return label
end

local function CreateSectionTitle(text, size)
    return CreateBodyText(text, "sectionHeader", size or 13)
end

local function StyleDropdown(dropdown)
    if not dropdown then
        return
    end

    ApplyTextStyle(dropdown.label, "label", 12, 1)
    if dropdown.text and dropdown.text.SetTextColor then
        dropdown.text:SetTextColor(VALUE_TEXT[1], VALUE_TEXT[2], VALUE_TEXT[3], 1)
    end

    if dropdown.dropdown then
        local name = dropdown.dropdown:GetName()
        if name then
            SetTextureColor(_G[name .. "Left"], FIELD_BORDER)
            SetTextureColor(_G[name .. "Middle"], FIELD_BACKGROUND)
            SetTextureColor(_G[name .. "Right"], FIELD_BORDER)
        end
    end

    if dropdown.button then
        local buttonNormal = dropdown.button.GetNormalTexture and dropdown.button:GetNormalTexture() or nil
        local buttonPushed = dropdown.button.GetPushedTexture and dropdown.button:GetPushedTexture() or nil
        local buttonHighlight = dropdown.button.GetHighlightTexture and dropdown.button:GetHighlightTexture() or nil
        SetTextureColor(buttonNormal, FIELD_BORDER)
        SetTextureColor(buttonPushed, FIELD_BORDER)
        SetTextureColor(buttonHighlight, FIELD_BORDER)
    end
end

local function ApplyWindowChrome(window)
    if not window or not window.frame then
        return
    end

    local frame = window.frame
    local content = window.content

    if window.titletext then
        ApplyTextStyle(window.titletext, "sectionHeader", 15, 1)
    end

    if not frame._fpPanelFill then
        frame._fpPanelFill = frame:CreateTexture(nil, "ARTWORK")
        frame._fpPanelFill:SetPoint("TOPLEFT", frame, "TOPLEFT", 12, -30)
        frame._fpPanelFill:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -12, 12)
    end
    frame._fpPanelFill:SetColorTexture(unpack(PANEL_BACKGROUND))

    if not frame._fpPanelHeaderFill then
        frame._fpPanelHeaderFill = frame:CreateTexture(nil, "ARTWORK")
        frame._fpPanelHeaderFill:SetPoint("TOPLEFT", frame, "TOPLEFT", 12, -30)
        frame._fpPanelHeaderFill:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -12, -30)
        frame._fpPanelHeaderFill:SetHeight(26)
    end
    frame._fpPanelHeaderFill:SetColorTexture(unpack(PANEL_HEADER))

    local function EnsureBorder(name)
        if not frame[name] then
            frame[name] = frame:CreateTexture(nil, "BORDER")
        end
        frame[name]:SetColorTexture(unpack(PANEL_BORDER))
        frame[name]:Show()
    end

    EnsureBorder("_fpPanelBorderTop")
    frame._fpPanelBorderTop:SetPoint("TOPLEFT", frame, "TOPLEFT", 12, -30)
    frame._fpPanelBorderTop:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -12, -30)
    frame._fpPanelBorderTop:SetHeight(1)

    EnsureBorder("_fpPanelBorderBottom")
    frame._fpPanelBorderBottom:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 12, 12)
    frame._fpPanelBorderBottom:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -12, 12)
    frame._fpPanelBorderBottom:SetHeight(1)

    EnsureBorder("_fpPanelBorderLeft")
    frame._fpPanelBorderLeft:SetPoint("TOPLEFT", frame, "TOPLEFT", 12, -30)
    frame._fpPanelBorderLeft:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 12, 12)
    frame._fpPanelBorderLeft:SetWidth(1)

    EnsureBorder("_fpPanelBorderRight")
    frame._fpPanelBorderRight:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -12, -30)
    frame._fpPanelBorderRight:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -12, 12)
    frame._fpPanelBorderRight:SetWidth(1)

    if content then
        if not content._fpAccent then
            content._fpAccent = content:CreateTexture(nil, "BORDER")
            content._fpAccent:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -2)
            content._fpAccent:SetPoint("TOPRIGHT", content, "TOPRIGHT", 0, -2)
            content._fpAccent:SetHeight(1)
        end
        content._fpAccent:SetColorTexture(0.83, 0.70, 0.30, 0.35)
    end
end

local function CreateRootContent(window)
    local scroll = AceGUI:Create("ScrollFrame")
    scroll:SetLayout("Fill")
    scroll:SetFullWidth(true)
    scroll:SetFullHeight(true)
    window:AddChild(scroll)

    local content = AceGUI:Create("SimpleGroup")
    content:SetFullWidth(true)
    content:SetLayout("List")
    scroll:AddChild(content)

    return content
end

local function CreateFieldGroup(width, title, labelText)
    local group = AceGUI:Create("SimpleGroup")
    group:SetLayout("List")
    group:SetWidth(width)
    group:AddChild(CreateSectionTitle(title, 13))
    group:AddChild(CreateBodyText(labelText, "label", 12, DESCRIPTION_TEXT))

    local dropdown = AceGUI:Create("Dropdown")
    dropdown:SetLabel("")
    dropdown:SetWidth(width - 4)
    StyleDropdown(dropdown)
    group:AddChild(dropdown)

    return group, dropdown
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
        windowContext.emptyState:SetText(T("INFO_COMMON_UNAVAILABLE", "Diese Ansicht ist im Moment nicht verfuegbar."))
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
        windowContext.hintValue:SetText(T("INFO_TAG_DATABASE_USAGE_HINT", "Nutze die Tag-Datenbank als Nachschlagehilfe und uebernimm Tags anschliessend bewusst in deine Vorlagen."))
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
    windowContext.hintValue:SetText(T("INFO_TAG_DATABASE_USAGE_HINT", "Nutze die Tag-Datenbank als Nachschlagehilfe und uebernimm Tags anschliessend bewusst in deine Vorlagen."))
end

local function CreateWindowContent(window, state)
    local root = CreateRootContent(window)

    root:AddChild(CreateBodyText(T("INFO_TAG_DATABASE_TITLE", "Tag-Datenbank"), "sectionHeader", 18))
    root:AddChild(CreateBodyText(T("INFO_TAG_DATABASE_DESCRIPTION_SHORT", "Tags finden, auswaehlen und ihre Bedeutung direkt nachschlagen."), "label", 11, DESCRIPTION_TEXT))
    root:AddChild(CreateBodyText(" ", "label", 6))

    local filtersGroup = AceGUI:Create("SimpleGroup")
    filtersGroup:SetFullWidth(true)
    filtersGroup:SetLayout("Flow")
    root:AddChild(filtersGroup)

    local categoryGroup, categorySelect = CreateFieldGroup(332, T("INFO_TAG_DATABASE_CATEGORY_PICK", "Kategorie waehlen"), T("INFO_TAG_DATABASE_CATEGORY_LABEL", "Kategorie"))
    local tagGroup, tagSelect = CreateFieldGroup(332, T("INFO_TAG_DATABASE_TAG_PICK", "Tag waehlen"), T("INFO_TAG_DATABASE_TAG_LABEL", "Tag"))
    filtersGroup:AddChild(categoryGroup)
    filtersGroup:AddChild(tagGroup)

    root:AddChild(CreateBodyText(" ", "label", 6))

    local detailsGroup = AceGUI:Create("SimpleGroup")
    detailsGroup:SetFullWidth(true)
    detailsGroup:SetLayout("List")
    root:AddChild(detailsGroup)

    detailsGroup:AddChild(CreateSectionTitle(T("INFO_TAG_DATABASE_DETAILS", "Details"), 13))
    detailsGroup:AddChild(CreateBodyText(T("INFO_TAG_DATABASE_COL_TAG", "Tag"), "label", 12, DESCRIPTION_TEXT))
    local tokenValue = CreateBodyText("-", "highlight", 15, VALUE_TEXT)
    detailsGroup:AddChild(tokenValue)

    detailsGroup:AddChild(CreateBodyText(" ", "label", 4))
    detailsGroup:AddChild(CreateBodyText(T("INFO_TAG_DATABASE_COL_DESC", "Beschreibung"), "label", 12, DESCRIPTION_TEXT))
    local descriptionValue = CreateBodyText("-", "label", 12)
    detailsGroup:AddChild(descriptionValue)

    detailsGroup:AddChild(CreateBodyText(" ", "label", 4))
    detailsGroup:AddChild(CreateBodyText(T("INFO_TAG_DATABASE_COL_EXAMPLE", "Beispiel"), "label", 12, DESCRIPTION_TEXT))
    local exampleValue = CreateBodyText("-", "highlight", 12, VALUE_TEXT)
    detailsGroup:AddChild(exampleValue)

    detailsGroup:AddChild(CreateBodyText(" ", "label", 6))
    detailsGroup:AddChild(CreateSectionTitle(T("INFO_TAG_DATABASE_USAGE_HINT_TITLE", "Hinweis"), 13))
    local hintValue = CreateBodyText(T("INFO_TAG_DATABASE_USAGE_HINT", "Nutze die Tag-Datenbank als Nachschlagehilfe und uebernimm Tags anschliessend bewusst in deine Vorlagen."), "label", 11, HINT_TEXT)
    detailsGroup:AddChild(hintValue)

    local emptyState = CreateBodyText("", "label", 11, HINT_TEXT)
    emptyState.frame:Hide()
    root:AddChild(emptyState)

    return {
        window = window,
        state = state,
        root = root,
        filtersGroup = filtersGroup,
        detailsGroup = detailsGroup,
        categorySelect = categorySelect,
        tagSelect = tagSelect,
        tokenValue = tokenValue,
        descriptionValue = descriptionValue,
        exampleValue = exampleValue,
        hintValue = hintValue,
        emptyState = emptyState,
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
    window:SetTitle(T("INFO_TAG_DATABASE_TITLE", "Tag-Datenbank"))
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

function TagDatabasePage.Build(container, deps)
    if container and container.ReleaseChildren then
        container:ReleaseChildren()
    end
    if container and container.SetLayout then
        container:SetLayout("Fill")
    end

    TagDatabasePage.OpenWindow(deps)
end

return TagDatabasePage
