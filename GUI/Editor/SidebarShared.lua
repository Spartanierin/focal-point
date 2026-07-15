local _, ns = ...

ns.GUI = ns.GUI or {}
ns.GUI.Editor = ns.GUI.Editor or {}

local AceGUI = LibStub("AceGUI-3.0")
local Shared = {}
ns.GUI.Editor.SidebarShared = Shared

local C = ns.Constants
local L = ns.L or {}
local FormWidgets = ns.GUI.Helpers and ns.GUI.Helpers.FormWidgets or {}

local ResolveSectionStyle = FormWidgets.ResolveSectionStyle
local ApplyTextStyle = FormWidgets.ApplyTextStyle
local StyleDropdownField = FormWidgets.StyleDropdown
local StyleCheckBoxField = FormWidgets.StyleCheckBox

local function GetChromeColors()
    local fallback = ((ns.GUI.Layouts and ns.GUI.Layouts.FormElements and ns.GUI.Layouts.FormElements.Palette) or {})
    local skins = ns.GUI and ns.GUI.Skins or nil
    local palette = skins and skins.GetFormPalette and skins.GetFormPalette(fallback) or fallback
    return palette.Chrome or {}
end

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

local INDICATOR_META = {
    Portrait = {
        labelKey = "OPTION_PORTRAIT_ENABLED",
        dropdownLabelKey = "ELEMENT_PORTRAIT",
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
        dropdownLabelKey = "ELEMENT_RAID_TARGET_ICON",
        optionKey = "RaidTargetIcon",
        placementLabel = "OPTION_RTM_PLACEMENT",
        sizeLabel = "OPTION_RTM_SIZE",
        scaleLabel = "OPTION_RTM_SCALE",
        insideSideLabel = "OPTION_INSIDE_SIDE",
    },
    LeaderIcon = {
        labelKey = "OPTION_LEADER_ICON_ENABLED",
        dropdownLabelKey = "ELEMENT_LEADER_ICON",
        optionKey = "LeaderIcon",
        placementLabel = "OPTION_LEADER_ICON_PLACEMENT",
        sizeLabel = "OPTION_LEADER_ICON_SIZE",
        scaleLabel = "OPTION_LEADER_ICON_SCALE",
        insideSideLabel = "OPTION_INSIDE_SIDE",
        unavailable = function(unitKey)
            return unitKey == "boss"
        end,
    },
    RoleIcon = {
        labelKey = "OPTION_ROLE_ICON_ENABLED",
        dropdownLabelKey = "ELEMENT_ROLE_ICON",
        optionKey = "RoleIcon",
        placementLabel = "OPTION_ROLE_ICON_PLACEMENT",
        sizeLabel = "OPTION_ROLE_ICON_SIZE",
        scaleLabel = "OPTION_ROLE_ICON_SCALE",
        insideSideLabel = "OPTION_INSIDE_SIDE",
        unavailable = function(unitKey)
            return unitKey == "boss"
        end,
    },
    CombatIndicator = {
        labelKey = "OPTION_COMBAT_INDICATOR_ENABLED",
        dropdownLabelKey = "ELEMENT_COMBAT_INDICATOR",
        optionKey = "CombatIndicator",
        effectLabel = "OPTION_COMBAT_INDICATOR_EFFECT",
        effectListKey = "status",
        placementLabel = "OPTION_COMBAT_INDICATOR_PLACEMENT",
        sizeLabel = "OPTION_COMBAT_INDICATOR_SIZE",
        scaleLabel = "OPTION_COMBAT_INDICATOR_SCALE",
        insideSideLabel = "OPTION_INSIDE_SIDE",
        unavailable = function(unitKey)
            return unitKey == "boss"
        end,
    },
    RestingIndicator = {
        labelKey = "OPTION_RESTING_INDICATOR_ENABLED",
        dropdownLabelKey = "ELEMENT_RESTING_INDICATOR",
        optionKey = "RestingIndicator",
        effectLabel = "OPTION_RESTING_INDICATOR_EFFECT",
        effectListKey = "status",
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
        dropdownLabelKey = "ELEMENT_READY_CHECK_INDICATOR",
        optionKey = "ReadyCheckIndicator",
        placementLabel = "OPTION_READY_CHECK_INDICATOR_PLACEMENT",
        sizeLabel = "OPTION_READY_CHECK_INDICATOR_SIZE",
        scaleLabel = "OPTION_READY_CHECK_INDICATOR_SCALE",
        insideSideLabel = "OPTION_INSIDE_SIDE",
        unavailable = function(unitKey)
            return unitKey == "boss"
        end,
    },
    ClassificationIndicator = {
        labelKey = "OPTION_CLASSIFICATION_INDICATOR_ENABLED",
        dropdownLabelKey = "ELEMENT_CLASSIFICATION_INDICATOR",
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

local function AddSpacer(container, height)
    local spacer = AceGUI:Create("SimpleGroup")
    spacer:SetFullWidth(true)
    spacer:SetAutoAdjustHeight(false)
    spacer:SetHeight(height or 8)
    container:AddChild(spacer)
    return spacer
end

local function ResolveLegacySectionStyle(style)
    if style == "prominent" then
        return "result_panel"
    end
    if style == "muted" then
        return "status_panel"
    end
    return "section_panel"
end

local function ApplyLegacySectionSkin(frame, style)
    if not frame then
        return
    end

    local resolvedStyle = ResolveSectionStyle and ResolveSectionStyle(ResolveLegacySectionStyle(style)) or nil
    local border = resolvedStyle and resolvedStyle.border or nil
    local surface = resolvedStyle and resolvedStyle.surface or nil

    if frame.SetBackdropColor and surface and surface.fill then
        frame:SetBackdropColor(unpack(surface.fill))
    end
    if frame.SetBackdropBorderColor and border and border.color then
        frame:SetBackdropBorderColor(unpack(border.color))
    end

    if not frame._fpAccent then
        local accent = frame:CreateTexture(nil, "ARTWORK")
        accent:SetPoint("TOPLEFT", frame, "TOPLEFT", 1, -1)
        accent:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -1, -1)
        frame._fpAccent = accent
    end

    if frame._fpAccent and frame._fpAccent.SetColorTexture then
        local accent = surface and surface.accent
        frame._fpAccent:SetHeight((accent and accent.thickness) or 1)
        local chromeColors = GetChromeColors()
        frame._fpAccent:SetColorTexture(unpack((accent and accent.color) or chromeColors.sectionAccent or chromeColors.accent or { 0.83, 0.70, 0.30, 0.26 }))
    end
end

local function StyleSidebarLabel(fontString, size, color)
    if not fontString then
        return
    end

    if ApplyTextStyle then
        ApplyTextStyle(fontString, "label", size or 12, 1)
    elseif fontString.SetFont then
        fontString:SetFont(STANDARD_TEXT_FONT, size or 12, "")
    end

    if color and fontString.SetTextColor then
        fontString:SetTextColor(color[1] or 1, color[2] or 1, color[3] or 1, color[4] or 1)
    end
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

        if titleText then
            StyleSidebarLabel(titleText, 13, { 0.89, 0.82, 0.60, 1 })
        end

        if border then
            ApplyLegacySectionSkin(border, style)
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
    toggle:SetHeight(34)
    local function UpdateToggleText()
        toggle:SetText(string.format("%s %s", collapsed and "[+]" or "[-]", title or ""))
    end
    UpdateToggleText()
    if toggle.SetUserData then
        toggle:SetUserData("focalPointSectionKey", sectionKey)
        toggle:SetUserData("focalPointSectionRole", "header")
    end
    if toggle.frame then
        toggle.frame._focalPointSectionKey = sectionKey
        toggle.frame._focalPointSectionRole = "header"
    end
    if toggle.label then
        StyleSidebarLabel(toggle.label, 13, { 0.88, 0.82, 0.62, 1 })
        if toggle.label.SetJustifyH then
            toggle.label:SetJustifyH("LEFT")
        end
    end

    if toggle.frame then
        local chromeColors = GetChromeColors()
        local bg = toggle.frame:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints()
        bg:SetColorTexture(unpack(chromeColors.sectionFillStrong or chromeColors.sectionFill or { 0.09, 0.10, 0.12, 0.86 }))
        toggle._sectionBg = bg

        local leftAccent = toggle.frame:CreateTexture(nil, "ARTWORK")
        leftAccent:SetPoint("TOPLEFT")
        leftAccent:SetPoint("BOTTOMLEFT")
        leftAccent:SetWidth(2)
        leftAccent:SetColorTexture(unpack(chromeColors.sectionAccent or chromeColors.accent or { 0.82, 0.69, 0.29, 0.52 }))
        toggle._sectionLeftAccent = leftAccent

        local topBorder = toggle.frame:CreateTexture(nil, "BORDER")
        topBorder:SetPoint("TOPLEFT", toggle.frame, "TOPLEFT", 3, 0)
        topBorder:SetPoint("TOPRIGHT")
        topBorder:SetHeight(1)
        topBorder:SetColorTexture(unpack(chromeColors.sectionBorder or chromeColors.panelInnerBorder or { 0.34, 0.31, 0.22, 0.52 }))
        toggle._sectionTopBorder = topBorder

        local bottomBorder = toggle.frame:CreateTexture(nil, "BORDER")
        bottomBorder:SetPoint("BOTTOMLEFT", toggle.frame, "BOTTOMLEFT", 3, 1)
        bottomBorder:SetPoint("BOTTOMRIGHT", toggle.frame, "BOTTOMRIGHT", 0, 1)
        bottomBorder:SetHeight(1)
        bottomBorder:SetColorTexture(unpack(chromeColors.panelInnerBorder or chromeColors.sectionBorder or { 0.05, 0.06, 0.08, 0.92 }))
        toggle._sectionBottomBorder = bottomBorder

        if toggle.SetHighlight then
            toggle:SetHighlight("Interface\\Buttons\\WHITE8X8")
        end
        if toggle.highlight and toggle.highlight.SetVertexColor then
            local highlightColor = chromeColors.sectionAccent or chromeColors.accent or { 0.90, 0.80, 0.34, 0.05 }
            toggle.highlight:SetVertexColor(
                highlightColor[1] or 0.90,
                highlightColor[2] or 0.80,
                highlightColor[3] or 0.34,
                (highlightColor[4] and math.min(highlightColor[4], 0.05)) or 0.05
            )
        end
    end

    container:AddChild(toggle)

    if options.localContentBuilder then
        local host = AceGUI:Create("SimpleGroup")
        host:SetFullWidth(true)
        host:SetLayout("Flow")
        container:AddChild(host)

        local currentGroup = nil

        local function CreateContentGroup()
            local group = AceGUI:Create("InlineGroup")
            group:SetTitle(" ")
            group:SetFullWidth(true)
            group:SetLayout("Flow")
            if group.SetUserData then
                group:SetUserData("focalPointSectionKey", sectionKey)
                group:SetUserData("focalPointSectionRole", "content")
            end
            if group.frame then
                group.frame._focalPointSectionKey = sectionKey
                group.frame._focalPointSectionRole = "content"
            end
            local border = group.content and group.content:GetParent()
            if border then
                ApplyLegacySectionSkin(border, "default")
            end
            return group
        end

        local function RebuildLocalContent()
            host:ReleaseChildren()
            currentGroup = nil

            if collapsed then
                if host.SetHeight then
                    host:SetHeight(1)
                end
                return
            end

            if host.SetHeight then
                host:SetHeight(0)
            end

            currentGroup = CreateContentGroup()
            currentGroup._focalPointRequestRebuild = function()
                RebuildLocalContent()
                if options.layoutRefresh then
                    options.layoutRefresh()
                end
            end
            host:AddChild(currentGroup)
            options.localContentBuilder(currentGroup)
        end

        toggle:SetCallback("OnClick", function()
            collapsed = not collapsed
            if stateApi and stateApi.SetSectionCollapsed then
                stateApi.SetSectionCollapsed(sectionKey, collapsed)
            elseif state then
                state.collapsedSections = state.collapsedSections or {}
                state.collapsedSections[sectionKey] = collapsed
            end

            UpdateToggleText()
            RebuildLocalContent()

            if options.layoutRefresh then
                options.layoutRefresh()
            end
        end)

        RebuildLocalContent()
        return currentGroup
    end

    toggle:SetCallback("OnClick", function()
        if stateApi and stateApi.SetSectionCollapsed then
            stateApi.SetSectionCollapsed(sectionKey, not collapsed)
        elseif state then
            state.collapsedSections = state.collapsedSections or {}
            state.collapsedSections[sectionKey] = not collapsed
        end

        if options.onToggle then
            options.onToggle(sectionKey)
        end
    end)

    if collapsed then
        return nil
    end

    local group = AceGUI:Create("InlineGroup")
    group:SetTitle(" ")
    group:SetFullWidth(true)
    group:SetLayout("Flow")
    if group.SetUserData then
        group:SetUserData("focalPointSectionKey", sectionKey)
        group:SetUserData("focalPointSectionRole", "content")
    end
    if group.frame then
        group.frame._focalPointSectionKey = sectionKey
        group.frame._focalPointSectionRole = "content"
    end
    local border = group.content and group.content:GetParent()
    if border then
        ApplyLegacySectionSkin(border, "default")
    end
    container:AddChild(group)
    return group
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

local function ApplyAnchorMetadata(widget, anchorKey)
    if type(anchorKey) ~= "string" or anchorKey == "" or not widget then
        return
    end

    if widget.SetUserData then
        widget:SetUserData("focalPointAnchorKey", anchorKey)
    end
    if widget.frame then
        widget.frame._focalPointAnchorKey = anchorKey
    end
end

local function AddCheckBox(container, label, value, onChanged, disabled, anchorKey)
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
    if StyleCheckBoxField then
        StyleCheckBoxField(widget, disabled and true or false)
    end
    ApplyAnchorMetadata(widget, anchorKey)
    container:AddChild(widget)
    return widget
end

local function AddSlider(container, label, minValue, maxValue, step, value, onChanged, disabled, anchorKey)
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
    if widget.label then
        StyleSidebarLabel(widget.label, 12, disabled and { 0.50, 0.50, 0.50, 1 } or { 0.68, 0.70, 0.75, 1 })
    end
    ApplyAnchorMetadata(widget, anchorKey)
    container:AddChild(widget)
    return widget
end

local function AddDropdown(container, label, list, value, onChanged, disabled, anchorKey)
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
    if StyleDropdownField then
        StyleDropdownField(widget, "editor_inset")
    end
    ApplyAnchorMetadata(widget, anchorKey)
    container:AddChild(widget)
    return widget
end

local function AddColorPicker(container, label, color, hasAlpha, onChanged, disabled, anchorKey)
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
    if widget.label then
        StyleSidebarLabel(widget.label, 12, disabled and { 0.50, 0.50, 0.50, 1 } or { 0.68, 0.70, 0.75, 1 })
    end
    ApplyAnchorMetadata(widget, anchorKey)
    container:AddChild(widget)
    return widget
end

local function GetFallbackTemplateLabel(textConfig)
    return nil
end

local function FormatTextEntry(textId, textConfig)
    if type(textConfig) ~= "table" then
        return nil
    end

    local templateName = textConfig.templateName
    if type(templateName) == "string" and templateName ~= "" then
        return templateName
    end

    if type(textConfig.stateTemplates) == "table" then
        for _, linkedTemplateName in pairs(textConfig.stateTemplates) do
            if type(linkedTemplateName) == "string" and linkedTemplateName ~= "" then
                return linkedTemplateName
            end
        end
    end

    return GetFallbackTemplateLabel(textConfig)
end

local function HasMeaningfulTextIdentity(textConfig)
    if type(textConfig) ~= "table" then
        return false
    end

    if type(textConfig.templateName) == "string" and textConfig.templateName ~= "" then
        return true
    end

    if type(textConfig.stateTemplates) == "table" then
        for _, linkedTemplateName in pairs(textConfig.stateTemplates) do
            if type(linkedTemplateName) == "string" and linkedTemplateName ~= "" then
                return true
            end
        end
    end

    return false
end

local function NormalizeStateTemplatesForInspector(stateTemplates)
    if type(stateTemplates) ~= "table" then
        return ""
    end

    local entries = {}
    for stateKey, templateName in pairs(stateTemplates) do
        if type(templateName) == "string" and templateName ~= "" then
            entries[#entries + 1] = tostring(stateKey) .. "=" .. templateName
        end
    end

    table.sort(entries)
    return table.concat(entries, "|")
end

local function IsGeneratedTextId(textId)
    return type(textId) == "string" and textId:match("^text_%d+$") ~= nil
end

local function IsLegacyCustomTextId(textId)
    return type(textId) == "string" and textId:match("^Custom%d+$") ~= nil
end

local function HasExplicitTemplateBinding(textConfig)
    if type(textConfig) ~= "table" then
        return false
    end

    if type(textConfig.templateName) == "string" and textConfig.templateName ~= "" then
        return true
    end

    return NormalizeStateTemplatesForInspector(textConfig.stateTemplates) ~= ""
end

local function IsInactiveGeneratedTemplateDuplicate(textId, textConfig, texts)
    if not IsGeneratedTextId(textId) or type(textConfig) ~= "table" or textConfig.enabled ~= false then
        return false
    end

    local templateName = textConfig.templateName
    if type(templateName) ~= "string" or templateName == "" or type(texts) ~= "table" then
        return false
    end

    for otherId, otherConfig in pairs(texts) do
        if otherId ~= textId
            and type(otherConfig) == "table"
            and HasExplicitTemplateBinding(otherConfig)
            and otherConfig.templateName == templateName
            and not IsGeneratedTextId(otherId)
        then
            return true
        end
    end

    return false
end

local function IsLegacyCustomTemplateDuplicate(textId, textConfig, texts)
    if not IsLegacyCustomTextId(textId) or type(textConfig) ~= "table" or type(texts) ~= "table" then
        return false
    end

    local templateName = textConfig.templateName
    if type(templateName) ~= "string" or templateName == "" then
        return false
    end

    local fieldCount = 0
    for key, value in pairs(textConfig) do
        if key == "templateName" then
            if type(value) == "string" and value ~= "" then
                fieldCount = fieldCount + 1
            end
        elseif key == "stateTemplates" then
            if NormalizeStateTemplatesForInspector(value) ~= "" then
                fieldCount = fieldCount + 1
            end
        elseif key == "tag" then
            if type(value) == "string" and value ~= "" then
                fieldCount = fieldCount + 1
            end
        elseif key == "enabled" then
            if value ~= nil then
                fieldCount = fieldCount + 1
            end
        else
            fieldCount = fieldCount + 1
        end
    end

    if fieldCount > 1 then
        return false
    end

    for otherId, otherConfig in pairs(texts) do
        if otherId ~= textId
            and type(otherConfig) == "table"
            and HasExplicitTemplateBinding(otherConfig)
            and otherConfig.templateName == templateName
            and not IsLegacyCustomTextId(otherId)
        then
            return true
        end
    end

    return false
end

local function BuildSortedTextIds(texts)
    local textIds = {}

    if type(texts) ~= "table" then
        return textIds
    end

    for textId, textConfig in pairs(texts) do
        if HasMeaningfulTextIdentity(textConfig)
            and not IsInactiveGeneratedTemplateDuplicate(textId, textConfig, texts)
            and not IsLegacyCustomTemplateDuplicate(textId, textConfig, texts)
        then
            textIds[#textIds + 1] = textId
        end
    end

    table.sort(textIds, function(a, b)
        local labelA = tostring(FormatTextEntry(a, texts[a] or {}))
        local labelB = tostring(FormatTextEntry(b, texts[b] or {}))

        if labelA == labelB then
            local aIsGenerated = type(a) == "string" and a:match("^text_%d+$") ~= nil
            local bIsGenerated = type(b) == "string" and b:match("^text_%d+$") ~= nil
            if aIsGenerated ~= bIsGenerated then
                return aIsGenerated
            end
            return tostring(a) < tostring(b)
        end

        return labelA < labelB
    end)

    return textIds
end

local function BuildTextList(texts)
    local list = {}
    local orderedIds = BuildSortedTextIds(texts)

    if type(texts) ~= "table" then
        return list
    end

    for _, textId in ipairs(orderedIds) do
        local label = FormatTextEntry(textId, texts[textId])
        if type(label) == "string" and label ~= "" then
            list[textId] = label
        end
    end

    local duplicateCounts = {}
    for _, label in pairs(list) do
        duplicateCounts[label] = (duplicateCounts[label] or 0) + 1
    end

    local duplicateIndex = {}
    for _, textId in ipairs(orderedIds) do
        local label = list[textId]
        if label and duplicateCounts[label] and duplicateCounts[label] > 1 then
            duplicateIndex[label] = (duplicateIndex[label] or 0) + 1
            list[textId] = string.format("%s %d", label, duplicateIndex[label])
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
            local dropdownLabelKey = meta.dropdownLabelKey or meta.labelKey
            list[indicatorKey] = L[dropdownLabelKey] or L[meta.labelKey] or indicatorKey
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
    if type(auraList) ~= "table" then
        return "Buffs"
    end

    for _, auraKey in ipairs(AURA_ORDER) do
        if auraList[auraKey] then
            return auraKey
        end
    end

    local remainingAuraKeys = {}
    for auraKey in pairs(auraList) do
        if type(auraKey) == "string" and auraList[auraKey] ~= nil then
            remainingAuraKeys[#remainingAuraKeys + 1] = auraKey
        end
    end
    table.sort(remainingAuraKeys)
    if remainingAuraKeys[1] then
        return remainingAuraKeys[1]
    end

    return "Buffs"
end

local function GetFirstTextId(textList)
    local firstTextId = nil
    local firstLabel = nil

    for textId in pairs(textList) do
        local label = tostring(textList[textId] or "")
        if firstTextId == nil or label < firstLabel or (label == firstLabel and tostring(textId) < tostring(firstTextId)) then
            firstTextId = textId
            firstLabel = label
        end
    end

    return firstTextId
end


Shared.POINTS = POINTS
Shared.INDICATOR_META = INDICATOR_META
Shared.AddSpacer = AddSpacer
Shared.CreateSection = CreateSection
Shared.BuildLocalizedList = BuildLocalizedList
Shared.AddCheckBox = AddCheckBox
Shared.AddSlider = AddSlider
Shared.AddDropdown = AddDropdown
Shared.AddColorPicker = AddColorPicker
Shared.BuildTextList = BuildTextList
Shared.BuildIndicatorList = BuildIndicatorList
Shared.GetFirstIndicatorKey = GetFirstIndicatorKey
Shared.BuildAuraList = BuildAuraList
Shared.GetFirstAuraKey = GetFirstAuraKey
Shared.GetFirstTextId = GetFirstTextId

return Shared
