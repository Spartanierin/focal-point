local _, ns = ...

ns.GUI = ns.GUI or {}
ns.GUI.Editor = ns.GUI.Editor or {}

local AceGUI = LibStub("AceGUI-3.0")
local Sidebar = {}
ns.GUI.Editor.Sidebar = Sidebar

local C = ns.Constants
local L = ns.L or {}

local POINTS = {
    CENTER = "CENTER",
    TOP = "TOP",
    BOTTOM = "BOTTOM",
    LEFT = "LEFT",
    RIGHT = "RIGHT",
    TOPLEFT = "TOPLEFT",
    TOPRIGHT = "TOPRIGHT",
    BOTTOMLEFT = "BOTTOMLEFT",
    BOTTOMRIGHT = "BOTTOMRIGHT",
}

local TEXT_ORDER = {
    "Name",
    "Health",
    "Power",
    "CastName",
    "CastTime",
}

local INDICATOR_META = {
    Portrait = {
        labelKey = "OPTION_PORTRAIT_ENABLED",
        optionKey = "Portrait",
        placementLabel = "OPTION_PORTRAIT_PLACEMENT",
        sizeLabel = "OPTION_PORTRAIT_SIZE",
        scaleLabel = "OPTION_PORTRAIT_SCALE",
        insideSideLabel = "OPTION_INSIDE_SIDE",
        modeLabel = "OPTION_PORTRAIT_MODE",
        supportsMode = true,
        unavailable = function()
            return false
        end,
    },
    RaidTargetIcon = {
        labelKey = "OPTION_RTM_ENABLED",
        optionKey = "RaidTargetIcon",
        placementLabel = "OPTION_RTM_PLACEMENT",
        sizeLabel = "OPTION_RTM_SIZE",
        scaleLabel = "OPTION_RTM_SCALE",
        insideSideLabel = "OPTION_INSIDE_SIDE",
    },
    LeaderIcon = {
        labelKey = "OPTION_LEADER_ICON_ENABLED",
        optionKey = "LeaderIcon",
        placementLabel = "OPTION_LEADER_ICON_PLACEMENT",
        sizeLabel = "OPTION_LEADER_ICON_SIZE",
        scaleLabel = "OPTION_LEADER_ICON_SCALE",
        insideSideLabel = "OPTION_INSIDE_SIDE",
    },
    RoleIcon = {
        labelKey = "OPTION_ROLE_ICON_ENABLED",
        optionKey = "RoleIcon",
        placementLabel = "OPTION_ROLE_ICON_PLACEMENT",
        sizeLabel = "OPTION_ROLE_ICON_SIZE",
        scaleLabel = "OPTION_ROLE_ICON_SCALE",
        insideSideLabel = "OPTION_INSIDE_SIDE",
    },
    CombatIndicator = {
        labelKey = "OPTION_COMBAT_INDICATOR_ENABLED",
        optionKey = "CombatIndicator",
        placementLabel = "OPTION_COMBAT_INDICATOR_PLACEMENT",
        sizeLabel = "OPTION_COMBAT_INDICATOR_SIZE",
        scaleLabel = "OPTION_COMBAT_INDICATOR_SCALE",
        insideSideLabel = "OPTION_INSIDE_SIDE",
    },
    RestingIndicator = {
        labelKey = "OPTION_RESTING_INDICATOR_ENABLED",
        optionKey = "RestingIndicator",
        placementLabel = "OPTION_RESTING_INDICATOR_PLACEMENT",
        sizeLabel = "OPTION_RESTING_INDICATOR_SIZE",
        scaleLabel = "OPTION_RESTING_INDICATOR_SCALE",
        insideSideLabel = "OPTION_INSIDE_SIDE",
        unavailable = function(unitKey)
            return unitKey ~= "player"
        end,
    },
    ReadyCheckIndicator = {
        labelKey = "OPTION_READY_CHECK_INDICATOR_ENABLED",
        optionKey = "ReadyCheckIndicator",
        placementLabel = "OPTION_READY_CHECK_INDICATOR_PLACEMENT",
        sizeLabel = "OPTION_READY_CHECK_INDICATOR_SIZE",
        scaleLabel = "OPTION_READY_CHECK_INDICATOR_SCALE",
        insideSideLabel = "OPTION_INSIDE_SIDE",
    },
    ClassificationIndicator = {
        labelKey = "OPTION_CLASSIFICATION_INDICATOR_ENABLED",
        optionKey = "ClassificationIndicator",
        effectLabel = "OPTION_CLASSIFICATION_INDICATOR_EFFECT",
        classification = true,
        unavailable = function(unitKey)
            return unitKey == "player" or unitKey == "pet"
        end,
    },
}

local AURA_ORDER = {
    "Buffs",
    "Debuffs",
}

local THEME_ORDER = {
    "classic",
    "minimal",
    "modern",
}

local function AddSpacer(container, height)
    local spacer = AceGUI:Create("Label")
    spacer:SetText(" ")
    spacer:SetFullWidth(true)
    spacer:SetHeight(height or 8)
    container:AddChild(spacer)
end

local function CreateSection(container, title, options)
    options = options or {}
    local state = options.state
    local stateApi = ns.GUI and ns.GUI.Editor and ns.GUI.Editor.State

    if not options.collapsible then
        local group = AceGUI:Create("InlineGroup")
        group:SetTitle(title or "")
        group:SetFullWidth(true)
        group:SetLayout("Flow")
        container:AddChild(group)

        local titleText = group.titletext
        local border = group.content and group.content:GetParent()
        local style = options.style or "default"

        if titleText and titleText.SetFont then
            if style == "prominent" then
                titleText:SetFont(STANDARD_TEXT_FONT, 13, "")
                titleText:SetTextColor(0.94, 0.85, 0.46, 1)
            elseif style == "muted" then
                titleText:SetFont(STANDARD_TEXT_FONT, 11, "")
                titleText:SetTextColor(0.63, 0.67, 0.72, 1)
            else
                titleText:SetFont(STANDARD_TEXT_FONT, 12, "")
                titleText:SetTextColor(0.79, 0.83, 0.88, 1)
            end
        end

        if border then
            if style == "prominent" then
                if border.SetBackdropColor then
                    border:SetBackdropColor(0.10, 0.11, 0.14, 0.52)
                end
                if border.SetBackdropBorderColor then
                    border:SetBackdropBorderColor(0.34, 0.37, 0.42, 0.95)
                end
            elseif style == "muted" then
                if border.SetBackdropColor then
                    border:SetBackdropColor(0.08, 0.09, 0.11, 0.26)
                end
                if border.SetBackdropBorderColor then
                    border:SetBackdropBorderColor(0.18, 0.20, 0.24, 0.65)
                end
            else
                if border.SetBackdropColor then
                    border:SetBackdropColor(0.09, 0.10, 0.12, 0.38)
                end
                if border.SetBackdropBorderColor then
                    border:SetBackdropBorderColor(0.24, 0.27, 0.31, 0.85)
                end
            end

            if not border._fpAccent then
                local accent = border:CreateTexture(nil, "ARTWORK")
                accent:SetPoint("TOPLEFT", border, "TOPLEFT", 1, -1)
                accent:SetPoint("TOPRIGHT", border, "TOPRIGHT", -1, -1)
                accent:SetHeight(style == "prominent" and 2 or 1)
                border._fpAccent = accent
            end

            if border._fpAccent and border._fpAccent.SetColorTexture then
                if style == "prominent" then
                    border._fpAccent:SetColorTexture(0.83, 0.70, 0.30, 0.55)
                elseif style == "muted" then
                    border._fpAccent:SetColorTexture(0.30, 0.34, 0.40, 0.35)
                else
                    border._fpAccent:SetColorTexture(0.42, 0.46, 0.52, 0.40)
                end
            end
        end

        return group
    end

    local sectionKey = options.key or title or "section"
    local collapsed = false
    if stateApi and stateApi.GetSectionCollapsed then
        collapsed = stateApi.GetSectionCollapsed(sectionKey, options.defaultCollapsed)
    elseif state and state.collapsedSections and state.collapsedSections[sectionKey] ~= nil then
        collapsed = state.collapsedSections[sectionKey] == true
    else
        collapsed = options.defaultCollapsed == true
    end

    local toggle = AceGUI:Create("InteractiveLabel")
    toggle:SetFullWidth(true)
    toggle:SetHeight(32)
    toggle:SetText(string.format("%s %s", collapsed and "[+]" or "[-]", title or ""))
    toggle:SetCallback("OnClick", function()
        if stateApi and stateApi.SetSectionCollapsed then
            stateApi.SetSectionCollapsed(sectionKey, not collapsed)
        elseif state then
            state.collapsedSections = state.collapsedSections or {}
            state.collapsedSections[sectionKey] = not collapsed
        end

        if options.onToggle then
            options.onToggle()
        end
    end)

    if toggle.label and toggle.label.SetFont then
        toggle.label:SetFont(STANDARD_TEXT_FONT, 13, "")
        toggle.label:SetJustifyH("LEFT")
        toggle.label:SetTextColor(0.93, 0.84, 0.42, 1)
    end

    if toggle.frame then
        local bg = toggle.frame:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints()
        bg:SetColorTexture(0.13, 0.14, 0.17, 0.84)
        toggle._sectionBg = bg

        local leftAccent = toggle.frame:CreateTexture(nil, "ARTWORK")
        leftAccent:SetPoint("TOPLEFT")
        leftAccent:SetPoint("BOTTOMLEFT")
        leftAccent:SetWidth(3)
        leftAccent:SetColorTexture(0.84, 0.70, 0.27, 0.78)
        toggle._sectionLeftAccent = leftAccent

        local topBorder = toggle.frame:CreateTexture(nil, "BORDER")
        topBorder:SetPoint("TOPLEFT", toggle.frame, "TOPLEFT", 3, 0)
        topBorder:SetPoint("TOPRIGHT")
        topBorder:SetHeight(1)
        topBorder:SetColorTexture(0.25, 0.28, 0.33, 0.95)
        toggle._sectionTopBorder = topBorder

        local bottomBorder = toggle.frame:CreateTexture(nil, "BORDER")
        bottomBorder:SetPoint("BOTTOMLEFT", toggle.frame, "BOTTOMLEFT", 3, 0)
        bottomBorder:SetPoint("BOTTOMRIGHT")
        bottomBorder:SetHeight(1)
        bottomBorder:SetColorTexture(0.07, 0.08, 0.10, 0.95)
        toggle._sectionBottomBorder = bottomBorder

        if toggle.SetHighlight then
            toggle:SetHighlight("Interface\\Buttons\\WHITE8X8")
        end
        if toggle.highlight and toggle.highlight.SetVertexColor then
            toggle.highlight:SetVertexColor(0.92, 0.82, 0.36, 0.08)
        end
    end

    container:AddChild(toggle)

    if collapsed then
        return nil
    end

    local group = AceGUI:Create("InlineGroup")
    group:SetTitle(" ")
    group:SetFullWidth(true)
    group:SetLayout("Flow")
    container:AddChild(group)
    return group
end

local function StyleSidebarButton(button, variant)
    if not button then
        return
    end

    if variant == "active" then
        button:SetHeight(24)
    elseif variant == "danger" then
        button:SetHeight(22)
    elseif variant == "secondary" then
        button:SetHeight(22)
    else
        button:SetHeight(24)
    end

    if button.text and button.text.SetTextColor then
        if variant == "active" then
            button.text:SetTextColor(0.95, 0.86, 0.54, 1)
        elseif variant == "danger" then
            button.text:SetTextColor(0.90, 0.82, 0.82, 1)
        elseif variant == "secondary" then
            button.text:SetTextColor(0.82, 0.84, 0.88, 1)
        else
            button.text:SetTextColor(0.95, 0.95, 0.95, 1)
        end
    end
end

local function IsToolPagePath(path)
    return path == C.Nav.PROFILES or path == C.Nav.TEXT_BUILDER or path == C.Nav.TAG_DATABASE
end

local function AddActiveSidebarItem(container, text)
    local item = AceGUI:Create("InteractiveLabel")
    item:SetFullWidth(true)
    item:SetHeight(26)
    item:SetText(text or "")
    if item.label and item.label.SetFont then
        item.label:SetFont(STANDARD_TEXT_FONT, 12, "")
        item.label:SetJustifyH("CENTER")
        item.label:SetTextColor(0.95, 0.86, 0.54, 1)
        item.label:SetShadowOffset(1, -1)
        item.label:SetShadowColor(0, 0, 0, 0.7)
    end

    if item.frame then
        local bg = item.frame:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints()
        bg:SetColorTexture(0.17, 0.16, 0.12, 0.74)
        item._bg = bg

        local leftAccent = item.frame:CreateTexture(nil, "ARTWORK")
        leftAccent:SetPoint("TOPLEFT")
        leftAccent:SetPoint("BOTTOMLEFT")
        leftAccent:SetWidth(3)
        leftAccent:SetColorTexture(0.86, 0.71, 0.28, 0.85)
        item._leftAccent = leftAccent

        local top = item.frame:CreateTexture(nil, "BORDER")
        top:SetPoint("TOPLEFT", item.frame, "TOPLEFT", 3, 0)
        top:SetPoint("TOPRIGHT")
        top:SetHeight(1)
        top:SetColorTexture(0.72, 0.60, 0.24, 0.55)
        item._top = top

        local bottom = item.frame:CreateTexture(nil, "BORDER")
        bottom:SetPoint("BOTTOMLEFT", item.frame, "BOTTOMLEFT", 3, 0)
        bottom:SetPoint("BOTTOMRIGHT")
        bottom:SetHeight(1)
        bottom:SetColorTexture(0.08, 0.08, 0.09, 0.90)
        item._bottom = bottom

        local right = item.frame:CreateTexture(nil, "BORDER")
        right:SetPoint("TOPRIGHT")
        right:SetPoint("BOTTOMRIGHT")
        right:SetWidth(1)
        right:SetColorTexture(0.20, 0.18, 0.12, 0.70)
        item._right = right

        if item.SetHighlight then
            item:SetHighlight("Interface\\Buttons\\WHITE8X8")
        end
        if item.highlight and item.highlight.SetVertexColor then
            item.highlight:SetVertexColor(0.92, 0.82, 0.36, 0.06)
        end
    end

    container:AddChild(item)
    return item
end

local function BuildUnitList()
    local units = {}
    for _, unitKey in ipairs(C.UnitOrder or {}) do
        units[unitKey] = ns.GetLabel and ns.GetLabel(ns.KeyMap.Units, unitKey) or unitKey
    end
    return units
end

local function BuildLocalizedList(sourceList)
    local list = {}
    if type(sourceList) ~= "table" then
        return list
    end

    for value, labelKey in pairs(sourceList) do
        if type(labelKey) == "string" and L[labelKey] then
            list[value] = L[labelKey]
        else
            list[value] = tostring(value)
        end
    end

    return list
end

local function NormalizeColor(color, fallback)
    local source = type(color) == "table" and color or fallback or {}
    local r = tonumber(source.r) or tonumber(source[1]) or 1
    local g = tonumber(source.g) or tonumber(source[2]) or 1
    local b = tonumber(source.b) or tonumber(source[3]) or 1
    local a = tonumber(source.a) or tonumber(source[4]) or 1

    return {
        r = r,
        g = g,
        b = b,
        a = a,
        [1] = r,
        [2] = g,
        [3] = b,
        [4] = a,
    }
end

local function CompactSidebarText(text, maxLength)
    if type(text) ~= "string" or text == "" then
        return ""
    end

    local firstSentence = text:match("^(.-%.)%s")
    if firstSentence and firstSentence ~= "" then
        text = firstSentence
    end

    maxLength = maxLength or 90
    if #text <= maxLength then
        return text
    end

    return text:sub(1, math.max(0, maxLength - 3)) .. "..."
end

local function AddCheckBox(container, label, value, onChanged, disabled)
    local widget = AceGUI:Create("CheckBox")
    widget:SetFullWidth(true)
    widget:SetLabel(label)
    widget:SetValue(value and true or false)
    widget:SetDisabled(disabled and true or false)
    widget:SetCallback("OnValueChanged", function(_, _, newValue)
        if onChanged then
            onChanged(newValue and true or false)
        end
    end)
    container:AddChild(widget)
    return widget
end

local function AddSlider(container, label, minValue, maxValue, step, value, onChanged, disabled)
    local widget = AceGUI:Create("Slider")
    widget:SetFullWidth(true)
    widget:SetLabel(label)
    widget:SetSliderValues(minValue, maxValue, step)
    widget:SetValue(value)
    widget:SetDisabled(disabled and true or false)
    widget:SetCallback("OnValueChanged", function(_, _, newValue)
        if onChanged then
            onChanged(newValue)
        end
    end)
    container:AddChild(widget)
    return widget
end

local function AddDropdown(container, label, list, value, onChanged, disabled)
    local widget = AceGUI:Create("Dropdown")
    widget:SetFullWidth(true)
    widget:SetLabel(label)
    widget:SetList(list)
    widget:SetValue(value)
    widget:SetDisabled(disabled and true or false)
    widget:SetCallback("OnValueChanged", function(_, _, newValue)
        if onChanged then
            onChanged(newValue)
        end
    end)
    container:AddChild(widget)
    return widget
end

local function AddUnitSelector(container, selectedUnit, onChanged)
    local list = BuildUnitList()

    local label = AceGUI:Create("Label")
    label:SetFullWidth(true)
    label:SetText(L["EDITOR_UNIT"] or "Unit")
    container:AddChild(label)

    local row = AceGUI:Create("SimpleGroup")
    row:SetFullWidth(true)
    row:SetLayout("Flow")
    container:AddChild(row)

    for _, unitKey in ipairs(C.UnitOrder or {}) do
        local button = AceGUI:Create("Button")
        local isSelected = unitKey == selectedUnit
        button:SetText(list[unitKey] or unitKey)
        button:SetWidth(108)
        button:SetDisabled(isSelected)
        button:SetCallback("OnClick", function()
            if onChanged then
                onChanged(unitKey)
            end
        end)

        if button.text and button.text.SetTextColor then
            if isSelected then
                button.text:SetTextColor(0.90, 0.82, 0.55, 1)
            else
                button.text:SetTextColor(0.88, 0.90, 0.94, 1)
            end
        end

        row:AddChild(button)
    end
end

local function AddColorPicker(container, label, color, hasAlpha, onChanged, disabled)
    local widget = AceGUI:Create("ColorPicker")
    local current = NormalizeColor(color)
    widget:SetFullWidth(true)
    widget:SetLabel(label)
    widget:SetHasAlpha(hasAlpha and true or false)
    widget:SetDisabled(disabled and true or false)
    widget:SetColor(current.r, current.g, current.b, current.a)

    local function HandleColorChanged(_, _, r, g, b, a)
        if disabled then
            return
        end

        if onChanged then
            onChanged(NormalizeColor({
                r = r,
                g = g,
                b = b,
                a = a,
            }, current))
        end
    end

    widget:SetCallback("OnValueChanged", HandleColorChanged)
    widget:SetCallback("OnValueConfirmed", HandleColorChanged)
    container:AddChild(widget)
    return widget
end

local function FormatTextKey(textKey)
    if type(textKey) ~= "string" or textKey == "" then
        return "Text"
    end

    local spaced = textKey:gsub("(%l)(%u)", "%1 %2")
    return spaced
end

local function BuildTextList(texts)
    local list = {}

    for _, textKey in ipairs(TEXT_ORDER) do
        if type(texts) == "table" and type(texts[textKey]) == "table" then
            list[textKey] = FormatTextKey(textKey)
        end
    end

    return list
end

local function BuildIndicatorList(unitKey)
    local list = {}

    for _, indicatorKey in ipairs({
        "Portrait",
        "RaidTargetIcon",
        "LeaderIcon",
        "RoleIcon",
        "CombatIndicator",
        "RestingIndicator",
        "ReadyCheckIndicator",
        "ClassificationIndicator",
    }) do
        local meta = INDICATOR_META[indicatorKey]
        local blocked = type(meta.unavailable) == "function" and meta.unavailable(unitKey) or false
        if not blocked then
            list[indicatorKey] = L[meta.labelKey] or indicatorKey
        end
    end

    return list
end

local function GetFirstIndicatorKey(indicatorList)
    for _, indicatorKey in ipairs({
        "Portrait",
        "RaidTargetIcon",
        "LeaderIcon",
        "RoleIcon",
        "CombatIndicator",
        "RestingIndicator",
        "ReadyCheckIndicator",
        "ClassificationIndicator",
    }) do
        if indicatorList[indicatorKey] then
            return indicatorKey
        end
    end

    for indicatorKey in pairs(indicatorList) do
        return indicatorKey
    end

    return "Portrait"
end

local function BuildAuraList(unitConfig)
    local list = {}
    for _, auraKey in ipairs(AURA_ORDER) do
        if type(unitConfig[auraKey]) == "table" then
            if auraKey == "Buffs" then
                list[auraKey] = L["AURA_BUFFS"] or auraKey
            elseif auraKey == "Debuffs" then
                list[auraKey] = L["AURA_DEBUFFS"] or auraKey
            else
                list[auraKey] = auraKey
            end
        end
    end
    return list
end

local function GetFirstAuraKey(auraList)
    for _, auraKey in ipairs(AURA_ORDER) do
        if auraList[auraKey] then
            return auraKey
        end
    end

    for auraKey in pairs(auraList) do
        return auraKey
    end

    return "Buffs"
end

local function GetFirstTextKey(textList)
    for _, textKey in ipairs(TEXT_ORDER) do
        if textList[textKey] then
            return textKey
        end
    end

    for textKey in pairs(textList) do
        return textKey
    end

    return "Name"
end

local function BuildThemeList(themes)
    local list = {}

    if type(themes) ~= "table" then
        return list
    end

    for _, themeId in ipairs(THEME_ORDER) do
        local theme = themes[themeId]
        if type(theme) == "table" then
            list[themeId] = (theme.labelKey and L[theme.labelKey]) or theme.id or themeId
        end
    end

    for themeId, theme in pairs(themes) do
        if not list[themeId] and type(theme) == "table" then
            list[themeId] = (theme.labelKey and L[theme.labelKey]) or theme.id or themeId
        end
    end

    return list
end

local function GetFirstThemeId(themeList)
    for _, themeId in ipairs(THEME_ORDER) do
        if themeList[themeId] then
            return themeId
        end
    end

    for themeId in pairs(themeList) do
        return themeId
    end

    return nil
end

function Sidebar.BuildContext(container, state, options)
    container:ReleaseChildren()
    container:SetLayout("Flow")

    local ThemeService = ns.ThemeService or {}
    local BuilderUI = ns.GUI and ns.GUI.Helpers and ns.GUI.Helpers.BuilderUI or {}
    local C = ns.Constants or {}
    local themes = ThemeService.GetThemes and ThemeService.GetThemes() or {}
    local themeList = BuildThemeList(themes)
    local activeThemeId = ns.db and ns.db.profile and ns.db.profile.General and ns.db.profile.General.ActiveThemeId
    local selectedThemeId = state.selectedThemeId
    local versionText = BuilderUI.GetAddonVersionText and BuilderUI.GetAddonVersionText() or "dev"
    local logoPath = "Interface\\AddOns\\FocalPoint\\Media\\Icon.tga"
    local generalConfig = ns.db and ns.db.profile and ns.db.profile.General
    local currentPath = ns.GUI and ns.GUI.selectedPath
    local normalizedCurrent = currentPath == nil and C.Nav.EDITOR or currentPath
    local showingToolPage = IsToolPagePath(normalizedCurrent)

    if type(generalConfig) ~= "table" then
        return
    end

    if not themeList[selectedThemeId] then
        selectedThemeId = activeThemeId
    end
    if not themeList[selectedThemeId] then
        selectedThemeId = GetFirstThemeId(themeList)
    end
    state.selectedThemeId = selectedThemeId
    state.mode = generalConfig.ExpertMode ~= false and "expert" or "quick"

    local brandGroup = AceGUI:Create("SimpleGroup")
    brandGroup:SetFullWidth(true)
    brandGroup:SetLayout("Flow")
    container:AddChild(brandGroup)

    local brandLine = AceGUI:Create("Label")
    brandLine:SetFullWidth(true)
    brandLine:SetText(string.format(
        "|T%s:24:24:0:0|t  |cff6fd2ff%s|r",
        logoPath,
        L["ADDON_NAME"] or C.ADDON_NAME or "FocalPoint"
    ))
    if brandLine.label and brandLine.label.SetFont then
        brandLine.label:SetFont(STANDARD_TEXT_FONT, 16, "")
        brandLine.label:SetShadowOffset(1, -1)
        brandLine.label:SetShadowColor(0, 0, 0, 0.75)
    end
    brandGroup:AddChild(brandLine)

    local versionLine = AceGUI:Create("Label")
    versionLine:SetFullWidth(true)
    versionLine:SetText(string.format(
        "|cffd8c27a%s|r  |cff4cff88%s|r",
        L["INFO_VERSION"] or "Version",
        versionText
    ))
    if versionLine.label and versionLine.label.SetFont then
        versionLine.label:SetFont(STANDARD_TEXT_FONT, 12, "")
        versionLine.label:SetShadowOffset(1, -1)
        versionLine.label:SetShadowColor(0, 0, 0, 0.75)
    end
    brandGroup:AddChild(versionLine)

    AddSpacer(container, 4)

    local toolsSection = CreateSection(container, L["EDITOR_CONTEXT_TOOLS"] or "Tools", { style = "muted" })

    for _, item in ipairs({
        { path = C.Nav.EDITOR, label = ns.GetLabel and ns.GetLabel(ns.KeyMap.Nav, C.Nav.EDITOR) or "Editor" },
        { path = C.Nav.PROFILES, label = ns.GetLabel and ns.GetLabel(ns.KeyMap.Nav, C.Nav.PROFILES) or "Profiles" },
        { path = C.Nav.TEXT_BUILDER, label = ns.GetLabel and ns.GetLabel(ns.KeyMap.Nav, C.Nav.TEXT_BUILDER) or "Text Builder" },
        { path = C.Nav.TAG_DATABASE, label = ns.GetLabel and ns.GetLabel(ns.KeyMap.Nav, C.Nav.TAG_DATABASE) or "Tag Database" },
    }) do
        if normalizedCurrent == item.path then
            AddActiveSidebarItem(toolsSection, item.label or item.path)
        else
            local button = AceGUI:Create("Button")
            button:SetFullWidth(true)
            button:SetText(item.label or item.path)
            StyleSidebarButton(button, "secondary")
            button:SetCallback("OnClick", function()
                if options.onNavigate then
                    options.onNavigate(item.path)
                end
            end)
            toolsSection:AddChild(button)
        end
    end

    if options.onClose then
        AddSpacer(toolsSection, 2)
        local closeButton = AceGUI:Create("Button")
        closeButton:SetFullWidth(true)
        closeButton:SetText(CLOSE or "Close")
        StyleSidebarButton(closeButton, "danger")
        closeButton:SetCallback("OnClick", function()
            options.onClose()
        end)
        toolsSection:AddChild(closeButton)
    end

    if showingToolPage then
        local toolContext = CreateSection(container, L["EDITOR_CONTEXT_WORKSPACE"] or "Workspace", { style = "prominent" })

        local toolLabel = AceGUI:Create("Label")
        toolLabel:SetFullWidth(true)
        toolLabel:SetText(L["EDITOR_TOOL_CONTEXT_HINT"] or "Dieses Werkzeug arbeitet in der mittleren Werkzeugflaeche. Fuer Unit-Bearbeitung wechselst du zurueck in den Editor.")
        if toolLabel.label and toolLabel.label.SetFont then
            toolLabel.label:SetFont(STANDARD_TEXT_FONT, 11, "")
            toolLabel.label:SetTextColor(0.72, 0.75, 0.80, 1)
        end
        toolContext:AddChild(toolLabel)

        AddSpacer(toolContext, 2)

        local selectedUnitLabel = AceGUI:Create("Label")
        selectedUnitLabel:SetFullWidth(true)
        selectedUnitLabel:SetText(string.format(
            "%s: |cffE7C44A%s|r",
            L["EDITOR_UNIT"] or "Unit",
            ns.GetLabel and ns.GetLabel(ns.KeyMap.Units, state.selectedUnit or C.Units.PLAYER) or (state.selectedUnit or C.Units.PLAYER)
        ))
        if selectedUnitLabel.label and selectedUnitLabel.label.SetFont then
            selectedUnitLabel.label:SetFont(STANDARD_TEXT_FONT, 12, "")
            selectedUnitLabel.label:SetShadowOffset(1, -1)
            selectedUnitLabel.label:SetShadowColor(0, 0, 0, 0.75)
        end
        toolContext:AddChild(selectedUnitLabel)

        local returnButton = AceGUI:Create("Button")
        returnButton:SetFullWidth(true)
        returnButton:SetText(L["EDITOR_RETURN_TO_EDITOR"] or "Zurueck zum Editor")
        StyleSidebarButton(returnButton, "primary")
        returnButton:SetCallback("OnClick", function()
            if options.onNavigate then
                options.onNavigate(C.Nav.EDITOR)
            end
        end)
        toolContext:AddChild(returnButton)
    else
        local workspace = CreateSection(container, L["EDITOR_CONTEXT_WORKSPACE"] or "Workspace", { style = "prominent" })

        AddUnitSelector(workspace, state.selectedUnit, function(value)
            if options.onUnitChanged then
                options.onUnitChanged(value)
            end
        end)

        AddCheckBox(workspace, L["OPTION_EXPERT_MODE"] or "Expert Mode", generalConfig.ExpertMode ~= false, function(value)
            generalConfig.ExpertMode = value and true or false
            state.mode = generalConfig.ExpertMode and "expert" or "quick"
            if options.onModeChanged then
                options.onModeChanged(state.mode)
            end
        end)

        local previewSection = CreateSection(container, L["EDITOR_CONTEXT_PREVIEW"] or "Editing", { style = "prominent" })

        local testButton = AceGUI:Create("Button")
        testButton:SetFullWidth(true)
        testButton:SetText((ns.guiTestModeEnabled and (L["GUI_TEST_STOP"] or "Stop Test")) or (L["GUI_TEST_START"] or "Test"))
        StyleSidebarButton(testButton, "primary")
        testButton:SetCallback("OnClick", function()
            if ns.ToggleTestMode then
                ns:ToggleTestMode()
                if options.onGlobalChanged then
                    options.onGlobalChanged()
                end
            end
        end)
        previewSection:AddChild(testButton)

        local unlockButton = AceGUI:Create("Button")
        unlockButton:SetFullWidth(true)
        unlockButton:SetText((ns.framesUnlocked and (L["GUI_UNLOCK_STOP"] or "Lock Frames")) or (L["GUI_UNLOCK_START"] or "Unlock Frames"))
        StyleSidebarButton(unlockButton, "primary")
        unlockButton:SetCallback("OnClick", function()
            if ns.ToggleFrameLock then
                ns:ToggleFrameLock()
                if options.onGlobalChanged then
                    options.onGlobalChanged()
                end
            end
        end)
        previewSection:AddChild(unlockButton)

        local previewHint = AceGUI:Create("Label")
        previewHint:SetFullWidth(true)
        previewHint:SetText(L["EDITOR_PREVIEW_INTERACTION_HINT"] or "")
        if previewHint.label and previewHint.label.SetFont then
            previewHint.label:SetFont(STANDARD_TEXT_FONT, 11, "")
            previewHint.label:SetTextColor(0.67, 0.71, 0.76, 1)
        end
        previewSection:AddChild(previewHint)

        if next(themeList) ~= nil then
            local presetSection = CreateSection(container, L["EDITOR_CONTEXT_PRESET"] or "Presets")

            local presetIntro = AceGUI:Create("Label")
            presetIntro:SetFullWidth(true)
            presetIntro:SetText(L["EDITOR_PRESET_CONTEXT_HINT"] or "")
            if presetIntro.label and presetIntro.label.SetFont then
                presetIntro.label:SetFont(STANDARD_TEXT_FONT, 11, "")
                presetIntro.label:SetTextColor(0.71, 0.74, 0.78, 1)
            end
            presetSection:AddChild(presetIntro)

            AddDropdown(presetSection, L["EDITOR_PRESET_SELECT"] or L["THEME_SELECT"] or "Select Preset", themeList, selectedThemeId, function(value)
                state.selectedThemeId = value
                if options.onThemeChanged then
                    options.onThemeChanged(value)
                end
            end)

            local selectedTheme = themes[selectedThemeId]
            local themeInfo = AceGUI:Create("Label")
            themeInfo:SetFullWidth(true)
            themeInfo:SetText(CompactSidebarText((selectedTheme and selectedTheme.descriptionKey and L[selectedTheme.descriptionKey]) or (L["INFO_GENERAL_THEMES_DESC"] or ""), 82))
            if themeInfo.label and themeInfo.label.SetFont then
                themeInfo.label:SetFont(STANDARD_TEXT_FONT, 11, "")
                themeInfo.label:SetTextColor(0.67, 0.70, 0.75, 1)
            end
            presetSection:AddChild(themeInfo)

            local applyButton = AceGUI:Create("Button")
            applyButton:SetText(L["THEME_APPLY"] or L["INFO_GENERAL_THEME_APPLY"] or "Apply Preset")
            applyButton:SetFullWidth(true)
            applyButton:SetDisabled(not selectedThemeId)
            StyleSidebarButton(applyButton, "secondary")
            applyButton:SetCallback("OnClick", function()
                if not selectedThemeId or not ThemeService.ApplyTheme then
                    return
                end

                if ThemeService.ApplyTheme(selectedThemeId) then
                    state.selectedThemeId = ns.db and ns.db.profile and ns.db.profile.General and ns.db.profile.General.ActiveThemeId or selectedThemeId
                    if options.onThemeApplied then
                        options.onThemeApplied(state.selectedThemeId)
                    end
                end
            end)
            presetSection:AddChild(applyButton)
        end
    end

    local globalSection = CreateSection(container, L["EDITOR_CONTEXT_GLOBAL"] or "Addon", { style = "muted" })

    AddCheckBox(globalSection, L["OPTION_HIDE_BLIZZARD_FRAMES"] or "Hide Blizzard Frames", generalConfig.HideBlizzardFrames == true, function(value)
        generalConfig.HideBlizzardFrames = value and true or false

        if ns.ApplyGeneralSettings then
            ns:ApplyGeneralSettings()
        end

        if not generalConfig.HideBlizzardFrames and ns.Info then
            ns:Info(L["INFO_RELOAD_REQUIRED_BLIZZARD_FRAMES"])
        end

        if options.onGlobalChanged then
            options.onGlobalChanged()
        end
    end)

    if generalConfig.ExpertMode ~= false then
        AddCheckBox(globalSection, L["OPTION_MOUSE_ENABLED"] or "Mouse Enabled", generalConfig.MouseEnabled ~= false, function(value)
            generalConfig.MouseEnabled = value and true or false

            if ns.RefreshAllUnitFrames then
                ns:RefreshAllUnitFrames()
            end

            if options.onGlobalChanged then
                options.onGlobalChanged()
            end
        end)

        AddCheckBox(globalSection, L["OPTION_GLOBAL_CLICKTHROUGH"] or "Global Click Through", generalConfig.GlobalClickThrough == true, function(value)
            generalConfig.GlobalClickThrough = value and true or false

            if ns.RefreshAllUnitFrames then
                ns:RefreshAllUnitFrames()
            end

            if options.onGlobalChanged then
                options.onGlobalChanged()
            end
        end)
    end

    AddSpacer(container, 2)

    local info = AceGUI:Create("Label")
    info:SetFullWidth(true)
    info:SetText(L["EDITOR_PREVIEW_NOTE"] or "")
    if info.label and info.label.SetFont then
        info.label:SetFont(STANDARD_TEXT_FONT, 11, "")
        info.label:SetTextColor(0.55, 0.58, 0.63, 1)
    end
    container:AddChild(info)
end

function Sidebar.Build(container, state, options)
    container:ReleaseChildren()
    container:SetLayout("Flow")

    local barLayouts = ns.GUI and ns.GUI.Layouts and ns.GUI.Layouts.UnitBars or {}
    local frameLayouts = ns.GUI and ns.GUI.Layouts and ns.GUI.Layouts.UnitFrame or {}
    local textLayouts = ns.GUI and ns.GUI.Layouts and ns.GUI.Layouts.UnitTexts or {}
    local portraitLayouts = ns.GUI and ns.GUI.Layouts and ns.GUI.Layouts.UnitPortrait or {}
    local classificationLayouts = ns.GUI and ns.GUI.Layouts and ns.GUI.Layouts.UnitClassificationIndicator or {}
    local auraLayouts = ns.GUI and ns.GUI.Layouts and ns.GUI.Layouts.UnitAuras or {}

    local textureList = BuildLocalizedList(barLayouts.Lists and barLayouts.Lists.textures)
    local barAnchorList = BuildLocalizedList(barLayouts.Lists and barLayouts.Lists.anchorPoints)
    local textAnchorTargetList = BuildLocalizedList(textLayouts.Lists and textLayouts.Lists.anchorTo)
    local textAnchorPointList = BuildLocalizedList(textLayouts.Lists and textLayouts.Lists.anchorPoints)
    local fontList = BuildLocalizedList(textLayouts.Lists and textLayouts.Lists.fonts)
    local fontStyleList = BuildLocalizedList(textLayouts.Lists and textLayouts.Lists.fontStyles)
    local justifyList = BuildLocalizedList(textLayouts.Lists and textLayouts.Lists.justifyH)
    local overflowList = BuildLocalizedList(textLayouts.Lists and textLayouts.Lists.overflowMode)
    local frameStrataList = BuildLocalizedList(frameLayouts.Lists and frameLayouts.Lists.frameStrata)
    local portraitPlacementList = BuildLocalizedList(portraitLayouts.Lists and portraitLayouts.Lists.placement)
    local portraitModeList = BuildLocalizedList(portraitLayouts.Lists and portraitLayouts.Lists.mode)
    local portraitInsideSideList = BuildLocalizedList(portraitLayouts.Lists and portraitLayouts.Lists.insideSide)
    local portraitAnchorTargetList = BuildLocalizedList(portraitLayouts.Lists and portraitLayouts.Lists.anchorTo)
    local portraitAnchorPointList = BuildLocalizedList(portraitLayouts.Lists and portraitLayouts.Lists.anchorPoints)
    local classificationEffectList = BuildLocalizedList(classificationLayouts.Lists and classificationLayouts.Lists.effect)
    local auraPlacementList = BuildLocalizedList(auraLayouts.Lists and auraLayouts.Lists.placement)
    local auraAnchorTargetList = BuildLocalizedList(auraLayouts.Lists and auraLayouts.Lists.anchorTo)
    local auraAnchorPointList = BuildLocalizedList(auraLayouts.Lists and auraLayouts.Lists.anchorPoints)
    local auraInsideSideList = BuildLocalizedList(auraLayouts.Lists and auraLayouts.Lists.insideSide)
    local auraGrowthXList = BuildLocalizedList(auraLayouts.Lists and auraLayouts.Lists.growthX)
    local auraGrowthYList = BuildLocalizedList(auraLayouts.Lists and auraLayouts.Lists.growthY)
    local auraSortModeList = BuildLocalizedList(auraLayouts.Lists and auraLayouts.Lists.sortMode)

    textAnchorTargetList.CastBar = textAnchorTargetList.CastBar or (L["BAR_CAST"] or "Cast Bar")
    textAnchorTargetList.AlternativePowerBar = textAnchorTargetList.AlternativePowerBar or (L["BAR_ALT_POWER"] or "Alt Power")

    local unitConfig = ns.UnitFrameUtils and ns.UnitFrameUtils.GetUnitDB and ns.UnitFrameUtils.GetUnitDB(state.selectedUnit)
    if type(unitConfig) ~= "table" then
        local label = AceGUI:Create("Label")
        label:SetFullWidth(true)
        label:SetText("Missing unit config.")
        container:AddChild(label)
        return
    end

    local textList = BuildTextList(unitConfig.Texts)
    local selectedTextKey = state.selectedTextKey
    if not textList[selectedTextKey] then
        selectedTextKey = GetFirstTextKey(textList)
        state.selectedTextKey = selectedTextKey
    end

    local textConfig = type(unitConfig.Texts) == "table" and unitConfig.Texts[selectedTextKey] or nil
    local indicatorList = BuildIndicatorList(state.selectedUnit)
    local selectedIndicatorKey = state.selectedIndicatorKey
    if not indicatorList[selectedIndicatorKey] then
        selectedIndicatorKey = GetFirstIndicatorKey(indicatorList)
        state.selectedIndicatorKey = selectedIndicatorKey
    end

    local indicatorMeta = INDICATOR_META[selectedIndicatorKey]
    local indicatorConfig = indicatorMeta and unitConfig[indicatorMeta.optionKey] or nil
    local auraList = BuildAuraList(unitConfig)
    local selectedAuraKey = state.selectedAuraKey
    if not auraList[selectedAuraKey] then
        selectedAuraKey = GetFirstAuraKey(auraList)
        state.selectedAuraKey = selectedAuraKey
    end
    local auraConfig = unitConfig[selectedAuraKey]

    local function NotifyConfigChanged()
        if options.onConfigChanged then
            options.onConfigChanged()
        end
    end

    local function NotifySidebarChanged()
        if options.onSidebarChanged then
            options.onSidebarChanged()
        else
            NotifyConfigChanged()
        end
    end

    local function CreateInspectorSection(sectionKey, title, defaultCollapsed)
        return CreateSection(container, title, {
            collapsible = true,
            key = sectionKey,
            state = state,
            defaultCollapsed = defaultCollapsed,
            onToggle = NotifySidebarChanged,
        })
    end

    local header = AceGUI:Create("Heading")
    header:SetText(L["EDITOR_SIDEBAR_TITLE"] or "Inspector")
    header:SetFullWidth(true)
    container:AddChild(header)

    local inspectorSummary = AceGUI:Create("Label")
    inspectorSummary:SetFullWidth(true)
    inspectorSummary:SetText(string.format(
        "%s: |cffefe6c5%s|r  |  %s: |cff9cd5ff%s|r",
        L["EDITOR_UNIT"] or "Unit",
        ns.GetLabel and ns.GetLabel(ns.KeyMap.Units, state.selectedUnit) or state.selectedUnit,
        L["EDITOR_MODE"] or "Mode",
        state.mode == "expert" and (L["EDITOR_MODE_EXPERT"] or "Expert") or (L["EDITOR_MODE_QUICK"] or "Quick")
    ))
    if inspectorSummary.label and inspectorSummary.label.SetFont then
        inspectorSummary.label:SetFont(STANDARD_TEXT_FONT, 11, "")
        inspectorSummary.label:SetTextColor(0.66, 0.70, 0.75, 1)
        inspectorSummary.label:SetShadowOffset(1, -1)
        inspectorSummary.label:SetShadowColor(0, 0, 0, 0.7)
    end
    container:AddChild(inspectorSummary)

    local inspectorHint = AceGUI:Create("Label")
    inspectorHint:SetFullWidth(true)
    inspectorHint:SetText(L["EDITOR_INSPECTOR_NOTE"] or "Bearbeitet immer nur die aktuell ausgewaehlte Unit.")
    if inspectorHint.label and inspectorHint.label.SetFont then
        inspectorHint.label:SetFont(STANDARD_TEXT_FONT, 10, "")
        inspectorHint.label:SetTextColor(0.55, 0.59, 0.64, 1)
    end
    container:AddChild(inspectorHint)

    AddSpacer(container, 8)

    local frameSection = CreateInspectorSection("frame", L["EDITOR_SECTION_FRAME"] or "Frame", false)
    if frameSection then
        AddCheckBox(frameSection, L["EDITOR_OPTION_ENABLED"] or "Enabled", unitConfig.enabled ~= false, function(value)
            unitConfig.enabled = value and true or false
            NotifyConfigChanged()
        end)

        AddCheckBox(frameSection, L["EDITOR_OPTION_SHOW_POWER"] or "Show Power Bar", unitConfig.showPowerBar ~= false, function(value)
            unitConfig.showPowerBar = value and true or false
            NotifySidebarChanged()
        end)

        AddSlider(frameSection, L["EDITOR_OPTION_WIDTH"] or "Width", 120, 420, 1, tonumber(unitConfig.width) or 260, function(value)
            unitConfig.width = math.floor((value or 0) + 0.5)
            NotifyConfigChanged()
        end)

        AddSlider(frameSection, L["EDITOR_OPTION_HEIGHT"] or "Height", 24, 120, 1, tonumber(unitConfig.height) or 65, function(value)
            unitConfig.height = math.floor((value or 0) + 0.5)
            NotifyConfigChanged()
        end)

        AddSlider(frameSection, L["EDITOR_OPTION_SCALE"] or "Scale", 0.5, 1.5, 0.01, tonumber(unitConfig.scale) or 1, function(value)
            unitConfig.scale = tonumber(string.format("%.2f", value or 1)) or 1
            NotifyConfigChanged()
        end)

        AddSlider(frameSection, L["EDITOR_OPTION_ALPHA"] or "Transparency", 0.1, 1.0, 0.01, tonumber(unitConfig.alpha) or 1, function(value)
            unitConfig.alpha = tonumber(string.format("%.2f", value or 1)) or 1
            NotifyConfigChanged()
        end)

        AddColorPicker(frameSection, L["OPTION_BACKGROUND_COLOR"] or "Background Color", unitConfig.backgroundColor, true, function(value)
            unitConfig.backgroundColor = value
            NotifyConfigChanged()
        end)

        if state.mode == "expert" then
            AddColorPicker(frameSection, L["OPTION_BORDER_COLOR"] or "Border Color", unitConfig.borderColor, true, function(value)
                unitConfig.borderColor = value
                NotifyConfigChanged()
            end)
        end

        if state.mode == "expert" then
            AddDropdown(frameSection, L["OPTION_FRAME_STRATA"] or "Frame Strata", frameStrataList, unitConfig.frameStrata or "MEDIUM", function(value)
                unitConfig.frameStrata = value
                NotifyConfigChanged()
            end)

            AddSlider(frameSection, L["OPTION_FRAME_LEVEL"] or "Frame Level", 0, 50, 1, tonumber(unitConfig.frameLevel) or 1, function(value)
                unitConfig.frameLevel = math.floor((value or 0) + 0.5)
                NotifyConfigChanged()
            end)
        end
    end

    AddSpacer(container, 6)

    local healthSection = CreateInspectorSection("health", L["BAR_HEALTH"] or "Health", false)
    if healthSection then
        AddDropdown(healthSection, L["OPTION_BAR_TEXTURE"] or "Bar Texture", textureList, unitConfig.healthBarTexture, function(value)
            unitConfig.healthBarTexture = value
            NotifyConfigChanged()
        end)

        AddCheckBox(healthSection, L["OPTION_USE_CLASS_COLORS"] or "Use Class Colors", unitConfig.useClassColorHealth == true, function(value)
            unitConfig.useClassColorHealth = value and true or false
            NotifySidebarChanged()
        end)

        if state.mode == "expert" then
            AddCheckBox(healthSection, L["OPTION_USE_REACTION_COLORS_NPC_HEALTH"] or "Use NPC Reaction Colors", unitConfig.useReactionColorNpcHealth == true, function(value)
                unitConfig.useReactionColorNpcHealth = value and true or false
                NotifySidebarChanged()
            end)

            AddCheckBox(healthSection, L["OPTION_REVERSE_FILL"] or "Reverse Fill", unitConfig.healthBarReverseFill == true, function(value)
                unitConfig.healthBarReverseFill = value and true or false
                NotifyConfigChanged()
            end)
        end

        if state.mode == "quick" or unitConfig.useClassColorHealth ~= true then
            AddColorPicker(healthSection, L["OPTION_COLOR"] or "Color", unitConfig.healthColor, true, function(value)
                unitConfig.healthColor = value
                NotifyConfigChanged()
            end, unitConfig.useClassColorHealth == true or unitConfig.useReactionColorNpcHealth == true)
        end

        AddColorPicker(healthSection, L["OPTION_LOW_HEALTH_COLOR"] or "Low Health Color", unitConfig.healthLowColor, true, function(value)
            unitConfig.healthLowColor = value
            NotifyConfigChanged()
        end)

        if state.mode == "expert" then
            AddCheckBox(healthSection, L["OPTION_SHOW_BACKGROUND"] or "Show Background", unitConfig.healthBackground ~= false, function(value)
                unitConfig.healthBackground = value and true or false
                NotifySidebarChanged()
            end)

            AddColorPicker(healthSection, L["OPTION_BACKGROUND_COLOR"] or "Background Color", unitConfig.healthBackgroundColor, true, function(value)
                unitConfig.healthBackgroundColor = value
                NotifyConfigChanged()
            end, unitConfig.healthBackground == false)
        end
    end

    AddSpacer(container, 6)

    local powerSection = CreateInspectorSection("power", L["BAR_POWER"] or "Power", true)
    if powerSection then
        AddCheckBox(powerSection, L["EDITOR_OPTION_SHOW_POWER"] or "Show Power Bar", unitConfig.showPowerBar ~= false, function(value)
            unitConfig.showPowerBar = value and true or false
            NotifySidebarChanged()
        end)

        AddDropdown(powerSection, L["OPTION_BAR_TEXTURE"] or "Bar Texture", textureList, unitConfig.powerBarTexture, function(value)
            unitConfig.powerBarTexture = value
            NotifyConfigChanged()
        end, unitConfig.showPowerBar == false)

        if state.mode == "expert" then
            AddSlider(powerSection, L["OPTION_POWER_BAR_HEIGHT"] or "Power Bar Height", 4, 30, 1, tonumber(unitConfig.powerBarHeight) or 20, function(value)
                unitConfig.powerBarHeight = math.floor((value or 0) + 0.5)
                NotifyConfigChanged()
            end, unitConfig.showPowerBar == false)
        end

        AddCheckBox(powerSection, L["OPTION_USE_CLASS_COLORS"] or "Use Class Colors", unitConfig.useClassColorPower == true, function(value)
            unitConfig.useClassColorPower = value and true or false
            NotifySidebarChanged()
        end, unitConfig.showPowerBar == false)

        if state.mode == "expert" then
            AddCheckBox(powerSection, L["OPTION_REVERSE_FILL"] or "Reverse Fill", unitConfig.powerBarReverseFill == true, function(value)
                unitConfig.powerBarReverseFill = value and true or false
                NotifyConfigChanged()
            end, unitConfig.showPowerBar == false)
        end

        AddColorPicker(powerSection, L["OPTION_COLOR"] or "Color", unitConfig.powerColor, true, function(value)
            unitConfig.powerColor = value
            NotifyConfigChanged()
        end, unitConfig.showPowerBar == false or unitConfig.useClassColorPower == true)

        if state.mode == "expert" then
            AddCheckBox(powerSection, L["OPTION_SHOW_BACKGROUND"] or "Show Background", unitConfig.powerBackground ~= false, function(value)
                unitConfig.powerBackground = value and true or false
                NotifySidebarChanged()
            end, unitConfig.showPowerBar == false)

            AddColorPicker(powerSection, L["OPTION_BACKGROUND_COLOR"] or "Background Color", unitConfig.powerBackgroundColor, true, function(value)
                unitConfig.powerBackgroundColor = value
                NotifyConfigChanged()
            end, unitConfig.showPowerBar == false or unitConfig.powerBackground == false)
        end
    end

    AddSpacer(container, 8)

    local castSection = CreateInspectorSection("cast", L["BAR_CAST"] or "Cast Bar", true)
    if castSection then
        AddCheckBox(castSection, L["OPTION_SHOW_CAST_BAR"] or "Show Cast Bar", unitConfig.showCastBar ~= false, function(value)
            unitConfig.showCastBar = value and true or false
            NotifySidebarChanged()
        end)

        AddCheckBox(castSection, L["OPTION_SHOW_CAST_BAR_ICON"] or "Show Cast Bar Icon", unitConfig.showCastBarIcon ~= false, function(value)
            unitConfig.showCastBarIcon = value and true or false
            NotifyConfigChanged()
        end, unitConfig.showCastBar == false)

        AddColorPicker(castSection, L["OPTION_CAST_BAR_COLOR"] or "Cast Bar Color", unitConfig.castBarColor, true, function(value)
            unitConfig.castBarColor = value
            NotifyConfigChanged()
        end, unitConfig.showCastBar == false)

        if state.mode == "expert" then
            AddDropdown(castSection, L["OPTION_BAR_TEXTURE"] or "Bar Texture", textureList, unitConfig.castBarTexture, function(value)
                unitConfig.castBarTexture = value
                NotifyConfigChanged()
            end, unitConfig.showCastBar == false)

            AddSlider(castSection, L["OPTION_CAST_BAR_HEIGHT"] or "Cast Bar Height", 4, 30, 1, tonumber(unitConfig.castBarHeight) or 20, function(value)
                unitConfig.castBarHeight = math.floor((value or 0) + 0.5)
                NotifyConfigChanged()
            end, unitConfig.showCastBar == false)
        end
    end

    if state.mode == "expert" then
        AddSpacer(container, 6)

        local positioning = CreateInspectorSection("positioning", L["EDITOR_POSITIONING"] or "Positioning", true)
        if positioning then
            AddDropdown(positioning, L["EDITOR_OPTION_POINT"] or "Anchor From", POINTS, unitConfig.point or "CENTER", function(value)
                unitConfig.point = value
                NotifyConfigChanged()
            end)

            AddDropdown(positioning, L["EDITOR_OPTION_RELATIVE_POINT"] or "Anchor To", POINTS, unitConfig.relativePoint or "CENTER", function(value)
                unitConfig.relativePoint = value
                NotifyConfigChanged()
            end)

            AddSlider(positioning, L["EDITOR_OPTION_X"] or "X Offset", -800, 800, 1, tonumber(unitConfig.x) or 0, function(value)
                unitConfig.x = math.floor((value or 0) + 0.5)
                NotifyConfigChanged()
            end)

            AddSlider(positioning, L["EDITOR_OPTION_Y"] or "Y Offset", -800, 800, 1, tonumber(unitConfig.y) or 0, function(value)
                unitConfig.y = math.floor((value or 0) + 0.5)
                NotifyConfigChanged()
            end)
        end

        AddSpacer(container, 6)

        local castPosition = CreateInspectorSection("cast_position", L["EDITOR_SECTION_CAST_POSITION"] or "Cast Bar Position", true)
        if castPosition then
            AddDropdown(castPosition, L["OPTION_ANCHOR_FROM"] or "Anchor From", barAnchorList, unitConfig.castBarPoint or "BOTTOMLEFT", function(value)
                unitConfig.castBarPoint = value
                NotifyConfigChanged()
            end)

            AddDropdown(castPosition, L["OPTION_ANCHOR_TO"] or "Anchor To", barAnchorList, unitConfig.castBarRelativePoint or "TOPLEFT", function(value)
                unitConfig.castBarRelativePoint = value
                NotifyConfigChanged()
            end)

            AddSlider(castPosition, L["OPTION_X_OFFSET"] or "X Offset", -500, 500, 1, tonumber(unitConfig.castBarOffsetX) or 0, function(value)
                unitConfig.castBarOffsetX = math.floor((value or 0) + 0.5)
                NotifyConfigChanged()
            end)

            AddSlider(castPosition, L["OPTION_Y_OFFSET"] or "Y Offset", -500, 500, 1, tonumber(unitConfig.castBarOffsetY) or 4, function(value)
                unitConfig.castBarOffsetY = math.floor((value or 0) + 0.5)
                NotifyConfigChanged()
            end)
        end
    end

    if textConfig then
        AddSpacer(container, 6)

        local textSection = CreateInspectorSection("texts", L["EDITOR_SECTION_TEXTS"] or "Texts", true)
        if textSection then

            AddDropdown(textSection, L["EDITOR_OPTION_TEXT"] or "Text", textList, selectedTextKey, function(value)
                state.selectedTextKey = value
                NotifySidebarChanged()
            end)

            AddCheckBox(textSection, L["OPTION_ENABLED"] or "Enabled", textConfig.enabled ~= false, function(value)
                textConfig.enabled = value and true or false
                NotifySidebarChanged()
            end)

        if state.mode == "quick" then
            AddSlider(textSection, L["OPTION_FONT_SIZE"] or "Font Size", 6, 32, 1, tonumber(textConfig.fontSize) or 12, function(value)
                textConfig.fontSize = math.floor((value or 0) + 0.5)
                NotifyConfigChanged()
            end, textConfig.enabled == false)

            AddColorPicker(textSection, L["OPTION_COLOR"] or "Color", textConfig.color, true, function(value)
                textConfig.color = value
                NotifyConfigChanged()
            end, textConfig.enabled == false)
        else
            AddDropdown(textSection, L["OPTION_FONT"] or "Font", fontList, textConfig.font or STANDARD_TEXT_FONT, function(value)
                textConfig.font = value
                NotifyConfigChanged()
            end, textConfig.enabled == false)

            AddDropdown(textSection, L["OPTION_FONT_STYLE"] or "Font Style", fontStyleList, textConfig.fontStyle or "NONE", function(value)
                textConfig.fontStyle = value
                NotifyConfigChanged()
            end, textConfig.enabled == false)

            AddSlider(textSection, L["OPTION_FONT_SIZE"] or "Font Size", 6, 32, 1, tonumber(textConfig.fontSize) or 12, function(value)
                textConfig.fontSize = math.floor((value or 0) + 0.5)
                NotifyConfigChanged()
            end, textConfig.enabled == false)

            AddDropdown(textSection, L["OPTION_JUSTIFY_H"] or "Justify", justifyList, textConfig.justifyH or "CENTER", function(value)
                textConfig.justifyH = value
                NotifyConfigChanged()
            end, textConfig.enabled == false)

            AddDropdown(textSection, L["OPTION_ANCHOR_TO_TARGET"] or "Anchor To Element", textAnchorTargetList, textConfig.anchorTo or "Frame", function(value)
                textConfig.anchorTo = value
                NotifyConfigChanged()
            end, textConfig.enabled == false)

            AddDropdown(textSection, L["OPTION_ANCHOR_FROM"] or "Anchor From", textAnchorPointList, textConfig.point or "CENTER", function(value)
                textConfig.point = value
                NotifyConfigChanged()
            end, textConfig.enabled == false)

            AddDropdown(textSection, L["OPTION_ANCHOR_TO"] or "Anchor To", textAnchorPointList, textConfig.relativePoint or "CENTER", function(value)
                textConfig.relativePoint = value
                NotifyConfigChanged()
            end, textConfig.enabled == false)

            AddSlider(textSection, L["OPTION_X_OFFSET"] or "X Offset", -100, 100, 1, tonumber(textConfig.offsetX) or 0, function(value)
                textConfig.offsetX = math.floor((value or 0) + 0.5)
                NotifyConfigChanged()
            end, textConfig.enabled == false)

            AddSlider(textSection, L["OPTION_Y_OFFSET"] or "Y Offset", -100, 100, 1, tonumber(textConfig.offsetY) or 0, function(value)
                textConfig.offsetY = math.floor((value or 0) + 0.5)
                NotifyConfigChanged()
            end, textConfig.enabled == false)

            AddDropdown(textSection, L["OPTION_TEXT_OVERFLOW"] or "Text Overflow", overflowList, textConfig.overflowMode or "NONE", function(value)
                textConfig.overflowMode = value
                NotifyConfigChanged()
            end, textConfig.enabled == false)

            AddCheckBox(textSection, L["OPTION_FONT_SHADOW"] or "Shadow", textConfig.shadowEnabled ~= false, function(value)
                textConfig.shadowEnabled = value and true or false
                NotifySidebarChanged()
            end, textConfig.enabled == false)

            AddColorPicker(textSection, L["OPTION_SHADOW_COLOR"] or "Shadow Color", textConfig.shadowColor, true, function(value)
                textConfig.shadowColor = value
                NotifyConfigChanged()
            end, textConfig.enabled == false or textConfig.shadowEnabled == false)
        end
        end
    end

    if indicatorConfig and indicatorMeta then
        AddSpacer(container, 8)

        local indicatorSection = CreateInspectorSection("indicators", L["EDITOR_SECTION_INDICATORS"] or "Indicators", true)
        if indicatorSection then

            AddDropdown(indicatorSection, L["EDITOR_OPTION_INDICATOR"] or "Indicator", indicatorList, selectedIndicatorKey, function(value)
                state.selectedIndicatorKey = value
                NotifySidebarChanged()
            end)

            AddCheckBox(indicatorSection, L[indicatorMeta.labelKey] or "Enabled", indicatorConfig.enabled ~= false, function(value)
                indicatorConfig.enabled = value and true or false
                NotifySidebarChanged()
            end)

        if indicatorMeta.classification then
            AddDropdown(indicatorSection, L[indicatorMeta.effectLabel] or "Effect", classificationEffectList, indicatorConfig.effect or "NAME_GLOW", function(value)
                indicatorConfig.effect = value
                NotifyConfigChanged()
            end, indicatorConfig.enabled == false)
        else
            AddDropdown(indicatorSection, L[indicatorMeta.placementLabel] or "Placement", portraitPlacementList, indicatorConfig.placement or "ATTACHED", function(value)
                indicatorConfig.placement = value
                NotifySidebarChanged()
            end, indicatorConfig.enabled == false)

            if state.mode == "expert" and indicatorMeta.supportsMode then
                AddDropdown(indicatorSection, L[indicatorMeta.modeLabel] or "Mode", portraitModeList, indicatorConfig.mode or "2D", function(value)
                    indicatorConfig.mode = value
                    NotifyConfigChanged()
                end, indicatorConfig.enabled == false)
            end

            AddSlider(indicatorSection, L[indicatorMeta.sizeLabel] or "Size", 8, 128, 1, tonumber(indicatorConfig.size) or 16, function(value)
                indicatorConfig.size = math.floor((value or 0) + 0.5)
                NotifyConfigChanged()
            end, indicatorConfig.enabled == false)

            if state.mode == "expert" then
                AddSlider(indicatorSection, L[indicatorMeta.scaleLabel] or "Scale", 0.25, 3.0, 0.01, tonumber(indicatorConfig.scale) or 1, function(value)
                    indicatorConfig.scale = tonumber(string.format("%.2f", value or 1)) or 1
                    NotifyConfigChanged()
                end, indicatorConfig.enabled == false)

                local placement = indicatorConfig.placement or "ATTACHED"
                local inside = placement == "INSIDE"

                if inside then
                    AddDropdown(indicatorSection, L["OPTION_ANCHOR_TO_TARGET"] or "Anchor To Element", portraitAnchorTargetList, indicatorConfig.insideAnchorTo or "Frame", function(value)
                        indicatorConfig.insideAnchorTo = value
                        NotifyConfigChanged()
                    end, indicatorConfig.enabled == false)

                    AddDropdown(indicatorSection, L[indicatorMeta.insideSideLabel] or (L["OPTION_INSIDE_SIDE"] or "Inside Side"), portraitInsideSideList, indicatorConfig.insideSide or "LEFT", function(value)
                        indicatorConfig.insideSide = value
                        NotifyConfigChanged()
                    end, indicatorConfig.enabled == false)

                    AddSlider(indicatorSection, L["OPTION_PADDING"] or "Padding", 0, 64, 1, tonumber(indicatorConfig.padding) or 2, function(value)
                        indicatorConfig.padding = math.floor((value or 0) + 0.5)
                        NotifyConfigChanged()
                    end, indicatorConfig.enabled == false)
                else
                    AddDropdown(indicatorSection, L["OPTION_ANCHOR_TO_TARGET"] or "Anchor To Element", portraitAnchorTargetList, indicatorConfig.anchorTo or "Frame", function(value)
                        indicatorConfig.anchorTo = value
                        NotifyConfigChanged()
                    end, indicatorConfig.enabled == false)

                    AddDropdown(indicatorSection, L["OPTION_ANCHOR_FROM"] or "Anchor From", portraitAnchorPointList, indicatorConfig.point or "TOP", function(value)
                        indicatorConfig.point = value
                        NotifyConfigChanged()
                    end, indicatorConfig.enabled == false)

                    AddDropdown(indicatorSection, L["OPTION_ANCHOR_TO"] or "Anchor To", portraitAnchorPointList, indicatorConfig.relativePoint or "TOP", function(value)
                        indicatorConfig.relativePoint = value
                        NotifyConfigChanged()
                    end, indicatorConfig.enabled == false)

                    AddSlider(indicatorSection, L["OPTION_X_OFFSET"] or "X Offset", -500, 500, 1, tonumber(indicatorConfig.offsetX) or 0, function(value)
                        indicatorConfig.offsetX = math.floor((value or 0) + 0.5)
                        NotifyConfigChanged()
                    end, indicatorConfig.enabled == false)

                    AddSlider(indicatorSection, L["OPTION_Y_OFFSET"] or "Y Offset", -500, 500, 1, tonumber(indicatorConfig.offsetY) or 0, function(value)
                        indicatorConfig.offsetY = math.floor((value or 0) + 0.5)
                        NotifyConfigChanged()
                    end, indicatorConfig.enabled == false)
                end
            end
        end
        end
    end

    if type(auraConfig) == "table" then
        AddSpacer(container, 8)

        local auraSection = CreateInspectorSection("auras", L["EDITOR_SECTION_AURAS"] or "Auras", true)
        if auraSection then

            AddDropdown(auraSection, L["EDITOR_OPTION_AURA_BLOCK"] or "Aura Block", auraList, selectedAuraKey, function(value)
                state.selectedAuraKey = value
                NotifySidebarChanged()
            end)

            AddCheckBox(auraSection, L["OPTION_AURA_ENABLED"] or "Enable Aura Block", auraConfig.enabled ~= false, function(value)
                auraConfig.enabled = value and true or false
                NotifySidebarChanged()
            end)

        AddDropdown(auraSection, L["OPTION_AURA_PLACEMENT"] or "Aura Block Placement", auraPlacementList, auraConfig.placement or "ATTACHED", function(value)
            auraConfig.placement = value
            NotifySidebarChanged()
        end, auraConfig.enabled == false)

        AddSlider(auraSection, L["OPTION_AURA_ICON_SIZE"] or "Icon Size", 12, 64, 1, tonumber(auraConfig.iconSize) or 30, function(value)
            auraConfig.iconSize = math.floor((value or 0) + 0.5)
            NotifyConfigChanged()
        end, auraConfig.enabled == false)

        AddSlider(auraSection, L["OPTION_AURA_ICONS_PER_ROW"] or "Icons Per Row", 1, 20, 1, tonumber(auraConfig.iconsPerRow) or 5, function(value)
            auraConfig.iconsPerRow = math.floor((value or 0) + 0.5)
            NotifyConfigChanged()
        end, auraConfig.enabled == false)

        AddSlider(auraSection, L["OPTION_AURA_MAX_ROWS"] or "Maximum Rows", 0, 10, 1, tonumber(auraConfig.maxRows) or 0, function(value)
            auraConfig.maxRows = math.floor((value or 0) + 0.5)
            NotifyConfigChanged()
        end, auraConfig.enabled == false)

        if state.mode == "quick" then
            AddCheckBox(auraSection, L["OPTION_AURA_SHOW_STACKS"] or "Show Stacks", auraConfig.showStackText ~= false, function(value)
                auraConfig.showStackText = value and true or false
                NotifyConfigChanged()
            end, auraConfig.enabled == false)

            AddCheckBox(auraSection, L["OPTION_AURA_SHOW_TIMER"] or "Show Timer", auraConfig.showTimerText ~= false, function(value)
                auraConfig.showTimerText = value and true or false
                NotifyConfigChanged()
            end, auraConfig.enabled == false)
        else
            AddSlider(auraSection, L["OPTION_AURA_SPACING_X"] or "Spacing X", 0, 20, 1, tonumber(auraConfig.spacingX) or 3, function(value)
                auraConfig.spacingX = math.floor((value or 0) + 0.5)
                NotifyConfigChanged()
            end, auraConfig.enabled == false)

            AddSlider(auraSection, L["OPTION_AURA_SPACING_Y"] or "Spacing Y", 0, 20, 1, tonumber(auraConfig.spacingY) or 3, function(value)
                auraConfig.spacingY = math.floor((value or 0) + 0.5)
                NotifyConfigChanged()
            end, auraConfig.enabled == false)

            AddDropdown(auraSection, L["OPTION_AURA_GROWTH_X"] or "Growth X", auraGrowthXList, auraConfig.growthX or "RIGHT", function(value)
                auraConfig.growthX = value
                NotifyConfigChanged()
            end, auraConfig.enabled == false)

            AddDropdown(auraSection, L["OPTION_AURA_GROWTH_Y"] or "Growth Y", auraGrowthYList, auraConfig.growthY or "DOWN", function(value)
                auraConfig.growthY = value
                NotifyConfigChanged()
            end, auraConfig.enabled == false)

            AddDropdown(auraSection, L["OPTION_AURA_SORT_MODE"] or "Sort Mode", auraSortModeList, auraConfig.sortMode or "NEWEST_FIRST", function(value)
                auraConfig.sortMode = value
                NotifyConfigChanged()
            end, auraConfig.enabled == false)

            AddSlider(auraSection, L["OPTION_AURA_STACK_FONT_SCALE"] or "Stack Font Scale", 0.5, 2.0, 0.05, tonumber(auraConfig.stackFontScale) or 1, function(value)
                auraConfig.stackFontScale = tonumber(string.format("%.2f", value or 1)) or 1
                NotifyConfigChanged()
            end, auraConfig.enabled == false)

            AddSlider(auraSection, L["OPTION_AURA_TIMER_FONT_SCALE"] or "Timer Font Scale", 0.5, 2.0, 0.05, tonumber(auraConfig.timerFontScale) or 1, function(value)
                auraConfig.timerFontScale = tonumber(string.format("%.2f", value or 1)) or 1
                NotifyConfigChanged()
            end, auraConfig.enabled == false)

            AddCheckBox(auraSection, L["OPTION_AURA_SHOW_ONLY_MINE"] or "Only My Auras", auraConfig.showOnlyMine == true, function(value)
                auraConfig.showOnlyMine = value and true or false
                NotifyConfigChanged()
            end, auraConfig.enabled == false)

            AddCheckBox(auraSection, L["OPTION_AURA_SHOW_BOSS"] or "Force Boss Auras", auraConfig.showBossAuras ~= false, function(value)
                auraConfig.showBossAuras = value and true or false
                NotifyConfigChanged()
            end, auraConfig.enabled == false)

            AddCheckBox(auraSection, L["OPTION_AURA_HIDE_PERMANENT"] or "Hide Permanent Auras", auraConfig.hidePermanentAuras == true, function(value)
                auraConfig.hidePermanentAuras = value and true or false
                NotifyConfigChanged()
            end, auraConfig.enabled == false)

            AddCheckBox(auraSection, L["OPTION_AURA_HIDE_LONG"] or "Hide Long Auras", auraConfig.hideLongAuras == true, function(value)
                auraConfig.hideLongAuras = value and true or false
                NotifySidebarChanged()
            end, auraConfig.enabled == false)

            AddSlider(auraSection, L["OPTION_AURA_LONG_THRESHOLD"] or "Hide Above Duration", 0, 3600, 5, tonumber(auraConfig.longAuraThreshold) or 300, function(value)
                auraConfig.longAuraThreshold = math.floor((value or 0) + 0.5)
                NotifyConfigChanged()
            end, auraConfig.enabled == false or auraConfig.hideLongAuras ~= true)

            if selectedAuraKey == "Buffs" then
                AddCheckBox(auraSection, L["OPTION_AURA_SHOW_STEALABLE_ONLY"] or "Only Stealable Buffs", auraConfig.showStealableOnly == true, function(value)
                    auraConfig.showStealableOnly = value and true or false
                    NotifyConfigChanged()
                end, auraConfig.enabled == false)
            else
                AddCheckBox(auraSection, L["OPTION_AURA_SHOW_DISPELLABLE_ONLY"] or "Only Dispellable Debuffs", auraConfig.showDispellableOnly == true, function(value)
                    auraConfig.showDispellableOnly = value and true or false
                    NotifyConfigChanged()
                end, auraConfig.enabled == false)
            end

            AddCheckBox(auraSection, L["OPTION_AURA_SHOW_STACKS"] or "Show Stacks", auraConfig.showStackText ~= false, function(value)
                auraConfig.showStackText = value and true or false
                NotifyConfigChanged()
            end, auraConfig.enabled == false)

            AddCheckBox(auraSection, L["OPTION_AURA_SHOW_TIMER"] or "Show Timer", auraConfig.showTimerText ~= false, function(value)
                auraConfig.showTimerText = value and true or false
                NotifyConfigChanged()
            end, auraConfig.enabled == false)

            local inside = (auraConfig.placement or "ATTACHED") == "INSIDE"
            if inside then
                AddDropdown(auraSection, L["OPTION_ANCHOR_TO_TARGET"] or "Anchor To Element", auraAnchorTargetList, auraConfig.insideAnchorTo or "Frame", function(value)
                    auraConfig.insideAnchorTo = value
                    NotifyConfigChanged()
                end, auraConfig.enabled == false)

                AddDropdown(auraSection, L["OPTION_INSIDE_SIDE"] or "Inside Side", auraInsideSideList, auraConfig.insideSide or "LEFT", function(value)
                    auraConfig.insideSide = value
                    NotifyConfigChanged()
                end, auraConfig.enabled == false)
            else
                AddDropdown(auraSection, L["OPTION_ANCHOR_TO_TARGET"] or "Anchor To Element", auraAnchorTargetList, auraConfig.anchorTo or "Frame", function(value)
                    auraConfig.anchorTo = value
                    NotifyConfigChanged()
                end, auraConfig.enabled == false)

                AddDropdown(auraSection, L["OPTION_ANCHOR_FROM"] or "Anchor From", auraAnchorPointList, auraConfig.point or "BOTTOMLEFT", function(value)
                    auraConfig.point = value
                    NotifyConfigChanged()
                end, auraConfig.enabled == false)

                AddDropdown(auraSection, L["OPTION_ANCHOR_TO"] or "Anchor To", auraAnchorPointList, auraConfig.relativePoint or "TOPLEFT", function(value)
                    auraConfig.relativePoint = value
                    NotifyConfigChanged()
                end, auraConfig.enabled == false)

                AddSlider(auraSection, L["OPTION_X_OFFSET"] or "X Offset", -500, 500, 1, tonumber(auraConfig.offsetX) or 0, function(value)
                    auraConfig.offsetX = math.floor((value or 0) + 0.5)
                    NotifyConfigChanged()
                end, auraConfig.enabled == false)

                AddSlider(auraSection, L["OPTION_Y_OFFSET"] or "Y Offset", -500, 500, 1, tonumber(auraConfig.offsetY) or 4, function(value)
                    auraConfig.offsetY = math.floor((value or 0) + 0.5)
                    NotifyConfigChanged()
                end, auraConfig.enabled == false)
            end
        end
        end
    end

    AddSpacer(container, 8)

    local visibilitySection = CreateInspectorSection("visibility", L["EDITOR_SECTION_VISIBILITY"] or "Visibility", true)
    if visibilitySection then
        AddCheckBox(visibilitySection, L["OPTION_SHOW_IN_SOLO"] or "Show in Solo", unitConfig.showInSolo ~= false, function(value)
            unitConfig.showInSolo = value and true or false
            NotifyConfigChanged()
        end)

        AddCheckBox(visibilitySection, L["OPTION_SHOW_IN_PARTY"] or "Show in Party", unitConfig.showInParty ~= false, function(value)
            unitConfig.showInParty = value and true or false
            NotifyConfigChanged()
        end)

        AddCheckBox(visibilitySection, L["OPTION_SHOW_IN_RAID"] or "Show in Raid", unitConfig.showInRaid ~= false, function(value)
            unitConfig.showInRaid = value and true or false
            NotifyConfigChanged()
        end)

        AddCheckBox(visibilitySection, L["OPTION_SHOW_IN_ARENA"] or "Show in Arena", unitConfig.showInArena ~= false, function(value)
            unitConfig.showInArena = value and true or false
            NotifyConfigChanged()
        end)

        AddCheckBox(visibilitySection, L["OPTION_SHOW_IN_PVP"] or "Show in PvP", unitConfig.showInPvp ~= false, function(value)
            unitConfig.showInPvp = value and true or false
            NotifyConfigChanged()
        end)

        if state.mode == "expert" then
            AddCheckBox(visibilitySection, L["OPTION_MOUSE_ENABLED"] or "Mouse Enabled", unitConfig.mouseEnabled ~= false, function(value)
                unitConfig.mouseEnabled = value and true or false
                NotifySidebarChanged()
            end)

            AddCheckBox(visibilitySection, L["OPTION_CLICK_THROUGH"] or "Click Through", unitConfig.clickThrough == true, function(value)
                unitConfig.clickThrough = value and true or false
                NotifyConfigChanged()
            end, unitConfig.mouseEnabled == false)

        end
    end
end
