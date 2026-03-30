local _, ns = ...

ns.GUI = ns.GUI or {}
ns.GUI.Editor = ns.GUI.Editor or {}

local AceGUI = LibStub("AceGUI-3.0")
local Shared = {}
ns.GUI.Editor.SidebarShared = Shared

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
    "Level",
    "Class",
    "Race",
    "Status",
    "CastName",
    "CastTime",
    "Custom1",
    "Custom2",
    "Custom3",
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
    "default",
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

    local keyMap = ns.KeyMap and ns.KeyMap.Texts
    if type(keyMap) == "table" then
        local labelKey = keyMap[textKey]
        if type(labelKey) == "string" and type(L[labelKey]) == "string" and L[labelKey] ~= "" then
            return L[labelKey]
        end
    end

    local spaced = textKey:gsub("(%l)(%u)", "%1 %2")
    return spaced
end

local function BuildTextList(texts)
    local list = {}
    local seen = {}

    if type(texts) ~= "table" then
        return list
    end

    for _, textKey in ipairs(TEXT_ORDER) do
        if type(texts[textKey]) == "table" then
            list[textKey] = FormatTextKey(textKey)
            seen[textKey] = true
        end
    end

    local extraKeys = {}
    for textKey, textConfig in pairs(texts) do
        if not seen[textKey] and type(textConfig) == "table" then
            extraKeys[#extraKeys + 1] = textKey
        end
    end

    table.sort(extraKeys, function(a, b)
        return tostring(a) < tostring(b)
    end)

    for _, textKey in ipairs(extraKeys) do
        list[textKey] = FormatTextKey(textKey)
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


Shared.POINTS = POINTS
Shared.INDICATOR_META = INDICATOR_META
Shared.AddSpacer = AddSpacer
Shared.CreateSection = CreateSection
Shared.StyleSidebarButton = StyleSidebarButton
Shared.IsToolPagePath = IsToolPagePath
Shared.AddActiveSidebarItem = AddActiveSidebarItem
Shared.BuildLocalizedList = BuildLocalizedList
Shared.CompactSidebarText = CompactSidebarText
Shared.AddCheckBox = AddCheckBox
Shared.AddSlider = AddSlider
Shared.AddDropdown = AddDropdown
Shared.AddUnitSelector = AddUnitSelector
Shared.AddColorPicker = AddColorPicker
Shared.BuildTextList = BuildTextList
Shared.BuildIndicatorList = BuildIndicatorList
Shared.GetFirstIndicatorKey = GetFirstIndicatorKey
Shared.BuildAuraList = BuildAuraList
Shared.GetFirstAuraKey = GetFirstAuraKey
Shared.GetFirstTextKey = GetFirstTextKey
Shared.BuildThemeList = BuildThemeList
Shared.GetFirstThemeId = GetFirstThemeId

return Shared
