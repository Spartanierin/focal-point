local _, ns = ...

ns.GUI = ns.GUI or {}
ns.GUI.Pages = ns.GUI.Pages or {}

local AceGUI = LibStub("AceGUI-3.0")
local C = ns.Constants
local KM = ns.KeyMap
local L = ns.L
local ColorPicker = ns.GUI.Widgets.ColorPicker
local Slider = ns.GUI.Widgets.Sliders
local Dropdown = ns.GUI.Widgets.Dropdown
local Checkbox = ns.GUI.Widgets.Checkbox

local UnitTextsPage = {}
ns.GUI.Pages.UnitTexts = UnitTextsPage

function UnitTextsPage.Build(container, unitKey, deps)
    local GetGUIState = deps.GetGUIState
    local GetTextElementLabel = deps.GetTextElementLabel
    local GetTextTabValues = deps.GetTextTabValues
    local ResetFlowContainer = deps.ResetFlowContainer
    local AddPageHeading = deps.AddPageHeading
    local CreateSection = deps.CreateSection
    local AddLayoutHandle = deps.AddLayoutHandle
    local BuildScrollableTabContent = deps.BuildScrollableTabContent
    local ResolveLayoutText = deps.ResolveLayoutText
    local ResolveLayoutPath = deps.ResolveLayoutPath
    local ResolveLayoutList = deps.ResolveLayoutList
    local CanBuildLayoutWidget = deps.CanBuildLayoutWidget

    local function BuildUnitTextPage(content, textConfigKey, textLabel)
        ResetFlowContainer(content)

        local unitLabel = ns.GetLabel(KM.Units, unitKey)
        local TEXT_TAB_LAYOUT = ns.GUI.Layouts.UnitTexts.TextTab
        local TEXT_TAB_LISTS = ns.GUI.Layouts.UnitTexts.Lists
        local tokenReplacements = {
            ["$textKey"] = textConfigKey,
        }

        local function IsUnitDisabled()
            return not ns.GUI.Helpers.OptionValues.Get({ "Units", unitKey, "enabled" }, true)
        end

        local function IsTextDisabled()
            return IsUnitDisabled()
                or not ns.GUI.Helpers.OptionValues.Get({ "Units", unitKey, "Texts", textConfigKey, "enabled" }, true)
        end

        local function IsShadowDisabled()
            return IsTextDisabled()
                or not ns.GUI.Helpers.OptionValues.Get({ "Units", unitKey, "Texts", textConfigKey, "shadowEnabled" }, true)
        end

        local function IsExpertModeEnabled()
            return ns.GUI.Helpers.OptionValues.Get({ "General", "ExpertMode" }, true) == true
        end

        local function GetTextConfig()
            return ns.GUI.Helpers.OptionValues.Get({ "Units", unitKey, "Texts", textConfigKey }, {}) or {}
        end

        local function GetTemplateList()
            local list = {}
            local templates = ns.db and ns.db.profile and ns.db.profile.TextTemplates or {}

            for templateName in pairs(templates) do
                list[templateName] = templateName
            end

            return list, templates
        end

        local function SetStatus(message)
            if ns.guiFrame and ns.guiFrame.SetStatusText then
                ns.guiFrame:SetStatusText(message)
            end
        end

        local function ResolveCurrentTemplateName(textConfig, templates)
            if type(textConfig) ~= "table" then
                return ""
            end

            if type(textConfig.templateName) == "string" and textConfig.templateName ~= "" and type(templates[textConfig.templateName]) == "string" then
                return textConfig.templateName
            end

            local currentTag = textConfig.tag or ""
            if currentTag == "" then
                return ""
            end

            for templateName, templateValue in pairs(templates) do
                if templateValue == currentTag then
                    return templateName
                end
            end

            return ""
        end

        local function ResolveCurrentTemplateText(textConfig, templates)
            local currentTemplateName = ResolveCurrentTemplateName(textConfig, templates)
            if currentTemplateName ~= "" then
                return templates[currentTemplateName] or ""
            end

            return textConfig.tag or ""
        end

        local function ResolveDisabled(def)
            if def.disabled == "unit" then
                return IsUnitDisabled
            end

            if def.disabled == "text" then
                return IsTextDisabled
            end

            if def.disabled == "shadow" then
                return IsShadowDisabled
            end

            return nil
        end

        local function AddEditBoxWidget(layout, def)
            local path = ResolveLayoutPath(def.path, unitKey, tokenReplacements)
            local disabled = ResolveDisabled(def)
            local group = AceGUI:Create("SimpleGroup")
            group:SetFullWidth(true)
            group:SetLayout("Flow")

            local editBox = AceGUI:Create("EditBox")
            editBox:SetLabel(ResolveLayoutText(def.label))
            editBox:SetWidth(def.width or 320)
            editBox:DisableButton(true)
            editBox:SetText(ns.GUI.Helpers.OptionValues.Get(path, def.fallback or ""))
            editBox:SetDisabled(ns.GUI.Helpers.OptionValues.ResolveState(disabled, def))
            editBox:SetCallback("OnEnterPressed", function(widget, _, newValue)
                if ns.GUI.Helpers.OptionValues.ResolveState(disabled, def) then
                    return
                end

                ns.GUI.Helpers.OptionValues.Set(path, newValue or "")
                ns.GUI.Helpers.OptionRefresh.Live()

                if def.refreshGUI then
                    ns.GUI:RefreshOptions()
                end

                widget:ClearFocus()
            end)
            editBox:SetCallback("OnFocusLost", function(widget)
                if ns.GUI.Helpers.OptionValues.ResolveState(disabled, def) then
                    return
                end

                ns.GUI.Helpers.OptionValues.Set(path, widget:GetText() or "")
                ns.GUI.Helpers.OptionRefresh.Live()

                if def.refreshGUI then
                    ns.GUI:RefreshOptions()
                end
            end)
            group:AddChild(editBox)

            if def.description and def.description ~= "" then
                local description = AceGUI:Create("Label")
                description:SetFullWidth(true)
                description:SetText(ResolveLayoutText(def.description))
                group:AddChild(description)
            end

            AddLayoutHandle(layout, { group = group }, def)
        end

        local function AddSectionWidget(layout, def)
            local resolvedList = def.list and ResolveLayoutList(TEXT_TAB_LISTS[def.list]) or nil

            if def.widget == "editbox" then
                AddEditBoxWidget(layout, def)
                return
            end

            if def.widget == "fontstyle" then
                local path = ResolveLayoutPath(def.path, unitKey, tokenReplacements)
                local disabled = ResolveDisabled(def)
                local group = AceGUI:Create("SimpleGroup")
                group:SetFullWidth(true)
                group:SetLayout("Flow")
                local dropdown = AceGUI:Create("Dropdown")
                local textConfig = ns.GUI.Helpers.OptionValues.Get(path, {}) or {}
                local currentStyle = "NONE"

                if textConfig.thickOutline and textConfig.monochrome then
                    currentStyle = "THICKOUTLINE_MONOCHROME"
                elseif textConfig.outline and textConfig.monochrome then
                    currentStyle = "OUTLINE_MONOCHROME"
                elseif textConfig.thickOutline then
                    currentStyle = "THICKOUTLINE"
                elseif textConfig.outline then
                    currentStyle = "OUTLINE"
                elseif textConfig.monochrome then
                    currentStyle = "MONOCHROME"
                end

                dropdown:SetLabel(ResolveLayoutText(def.label))
                dropdown:SetList(resolvedList)
                dropdown:SetWidth(220)
                dropdown:SetValue(currentStyle)
                dropdown:SetDisabled(ns.GUI.Helpers.OptionValues.ResolveState(disabled, def))
                dropdown:SetCallback("OnValueChanged", function(_, _, newValue)
                    if ns.GUI.Helpers.OptionValues.ResolveState(disabled, def) then
                        return
                    end

                    local stylePath = path
                    local isOutline = newValue == "OUTLINE" or newValue == "OUTLINE_MONOCHROME"
                    local isThickOutline = newValue == "THICKOUTLINE" or newValue == "THICKOUTLINE_MONOCHROME"
                    local isMonochrome = newValue == "MONOCHROME" or newValue == "OUTLINE_MONOCHROME" or newValue == "THICKOUTLINE_MONOCHROME"

                    ns.GUI.Helpers.OptionValues.Set({ stylePath[1], stylePath[2], stylePath[3], stylePath[4], "outline" }, isOutline)
                    ns.GUI.Helpers.OptionValues.Set({ stylePath[1], stylePath[2], stylePath[3], stylePath[4], "thickOutline" }, isThickOutline)
                    ns.GUI.Helpers.OptionValues.Set({ stylePath[1], stylePath[2], stylePath[3], stylePath[4], "monochrome" }, isMonochrome)
                    ns.GUI.Helpers.OptionRefresh.Live()
                end)
                group:AddChild(dropdown)
                AddLayoutHandle(layout, { group = group }, def)
                return
            end

            if def.widget == "colorpicker" then
                AddLayoutHandle(layout, ColorPicker.Create({
                    path = ResolveLayoutPath(def.path, unitKey, tokenReplacements),
                    label = ResolveLayoutText(def.label),
                    description = ResolveLayoutText(def.description),
                    hasAlpha = def.hasAlpha == true,
                    fallback = def.fallback,
                    resetText = L["OPTION_RESET"],
                    resetWidth = def.resetWidth or 64,
                    disabled = ResolveDisabled(def),
                }), def)
                return
            end

            if not CanBuildLayoutWidget(def, resolvedList) then
                return
            end

            if def.widget == "checkbox" then
                AddLayoutHandle(layout, Checkbox.Create({
                    path = ResolveLayoutPath(def.path, unitKey, tokenReplacements),
                    label = ResolveLayoutText(def.label),
                    description = ResolveLayoutText(def.description),
                    fallback = def.fallback,
                    resetText = def.resetText ~= nil and def.resetText or L["OPTION_RESET"],
                    resetWidth = def.resetWidth or 64,
                    disabled = ResolveDisabled(def),
                    refreshGUI = def.refreshGUI,
                }), def)
                return
            end

            if def.widget == "dropdown" then
                AddLayoutHandle(layout, Dropdown.Create({
                    path = ResolveLayoutPath(def.path, unitKey, tokenReplacements),
                    label = ResolveLayoutText(def.label),
                    description = ResolveLayoutText(def.description),
                    list = resolvedList,
                    fallback = def.fallback,
                    resetText = def.resetText ~= nil and def.resetText or L["OPTION_RESET"],
                    resetWidth = def.resetWidth or 64,
                    disabled = ResolveDisabled(def),
                    refreshGUI = def.refreshGUI,
                }), def)
                return
            end

            if def.widget == "slider" then
                AddLayoutHandle(layout, Slider.Create({
                    path = ResolveLayoutPath(def.path, unitKey, tokenReplacements),
                    label = ResolveLayoutText(def.label),
                    description = ResolveLayoutText(def.description),
                    min = def.min,
                    max = def.max,
                    step = def.step,
                    fallback = def.fallback,
                    format = def.format,
                    resetText = def.resetText ~= nil and def.resetText or L["OPTION_RESET"],
                    resetWidth = def.resetWidth or 64,
                    disabled = ResolveDisabled(def),
                }), def)
            end
        end

        AddPageHeading(content, unitLabel .. " - " .. ns.GetLabel(KM.Tabs, C.Tabs.TEXTS) .. " - " .. textLabel)

        local templatesList, templates = GetTemplateList()
        local textConfig = GetTextConfig()
        local currentTemplateName = ResolveCurrentTemplateName(textConfig, templates)
        local currentTemplateText = ResolveCurrentTemplateText(textConfig, templates)

        local templateGroup = AceGUI:Create("InlineGroup")
        templateGroup:SetFullWidth(true)
        templateGroup:SetLayout("Flow")
        templateGroup:SetTitle(L["INFO_UNIT_TEXT_TEMPLATE_GROUP"] or "Template")
        content:AddChild(templateGroup)

        local templateHint = AceGUI:Create("Label")
        templateHint:SetFullWidth(true)
        if templateHint.SetFont then
            templateHint:SetFont(STANDARD_TEXT_FONT, 10, "")
        end
        templateHint:SetText(string.format("|cff9ea8b3%s|r", L["INFO_UNIT_TEXT_TEMPLATE_HINT"] or "Choose a template for this text element. Layout, font, and effects stay on this page."))
        templateGroup:AddChild(templateHint)

        local templateFields = CreateSection(templateGroup)

        local templateDropdownGroup = AceGUI:Create("SimpleGroup")
        templateDropdownGroup:SetFullWidth(true)
        templateDropdownGroup:SetLayout("Flow")
        local templateDropdown = AceGUI:Create("Dropdown")
        templateDropdown:SetLabel(L["INFO_UNIT_TEXT_TEMPLATE_SELECT"] or "Template")
        templateDropdown:SetWidth(320)
        templateDropdown:SetList(templatesList)
        templateDropdown:SetValue(currentTemplateName ~= "" and currentTemplateName or nil)
        templateDropdown:SetDisabled(IsUnitDisabled())
        templateDropdownGroup:AddChild(templateDropdown)
        templateFields:Add({ group = templateDropdownGroup }, {
            placement = "full",
            rowType = "toolbar",
            subsection = ResolveLayoutText("SECTION_CONTENT"),
        })

        if IsExpertModeEnabled() then
            local rawTemplateGroup = AceGUI:Create("SimpleGroup")
            rawTemplateGroup:SetFullWidth(true)
            rawTemplateGroup:SetLayout("Flow")
            local rawTemplateEdit = AceGUI:Create("EditBox")
            rawTemplateEdit:SetLabel(L["OPTION_TAG"] or "Tag")
            rawTemplateEdit:SetWidth(320)
            rawTemplateEdit:DisableButton(true)
            rawTemplateEdit:SetText(textConfig.tag or "")
            rawTemplateEdit:SetDisabled(IsUnitDisabled())
            rawTemplateEdit:SetCallback("OnEnterPressed", function(widget, _, newValue)
                if IsUnitDisabled() then
                    return
                end

                ns.GUI.Helpers.OptionValues.Set({ "Units", unitKey, "Texts", textConfigKey, "tag" }, newValue or "")
                ns.GUI.Helpers.OptionRefresh.Live()
                widget:ClearFocus()
            end)
            rawTemplateEdit:SetCallback("OnFocusLost", function(widget)
                if IsUnitDisabled() then
                    return
                end

                ns.GUI.Helpers.OptionValues.Set({ "Units", unitKey, "Texts", textConfigKey, "tag" }, widget:GetText() or "")
                ns.GUI.Helpers.OptionRefresh.Live()
            end)
            rawTemplateGroup:AddChild(rawTemplateEdit)

            local expertInfo = AceGUI:Create("Label")
            expertInfo:SetFullWidth(true)
            if expertInfo.SetFont then
                expertInfo:SetFont(STANDARD_TEXT_FONT, 10, "")
            end
            expertInfo:SetText(string.format("|cff8f98a3%s|r", L["INFO_UNIT_TEXT_TEMPLATE_EXPERT_HINT"] or "Expert Mode: you can still edit the raw template string below."))
            rawTemplateGroup:AddChild(expertInfo)
            templateFields:Add({ group = rawTemplateGroup }, {
                placement = "full",
                rowType = "preview",
                subsection = ResolveLayoutText("SECTION_CONTENT"),
            })
        end

        local previewGroup = AceGUI:Create("InlineGroup")
        previewGroup:SetFullWidth(true)
        previewGroup:SetLayout("Flow")
        previewGroup:SetTitle(L["INFO_UNIT_TEXT_TEMPLATE_PREVIEW"] or "Preview")
        templateGroup:AddChild(previewGroup)

        local previewBox = AceGUI:Create("Label")
        previewBox:SetFullWidth(true)
        previewBox:SetHeight(34)
        if previewBox.SetFont then
            previewBox:SetFont(STANDARD_TEXT_FONT, 13, "")
        end
        previewBox:SetText((ns.UnitFrame and ns.UnitFrame.BuildTemplatePreview and ns.UnitFrame:BuildTemplatePreview(currentTemplateText)) or currentTemplateText or " ")
        previewGroup:AddChild(previewBox)

        local actionGroup = AceGUI:Create("SimpleGroup")
        actionGroup:SetFullWidth(true)
        actionGroup:SetLayout("Flow")
        content:AddChild(actionGroup)

        local deleteTextButton = AceGUI:Create("Button")
        deleteTextButton:SetText(L["INFO_UNIT_TEXT_TEMPLATE_DELETE"] or "Delete Text")
        deleteTextButton:SetWidth(135)
        deleteTextButton:SetDisabled(IsUnitDisabled())
        actionGroup:AddChild(deleteTextButton)

        local openBuilderButton = AceGUI:Create("Button")
        openBuilderButton:SetText(L["INFO_UNIT_TEXT_TEMPLATE_OPEN_BUILDER"] or "Open in Text Builder")
        openBuilderButton:SetWidth(165)
        openBuilderButton:SetDisabled(IsUnitDisabled())
        actionGroup:AddChild(openBuilderButton)

        templateDropdown:SetCallback("OnValueChanged", function(_, _, value)
            if IsUnitDisabled() then
                return
            end

            local selectedName = value or ""
            local selectedTemplate = templates[selectedName]
            if type(selectedTemplate) ~= "string" then
                return
            end

            ns.GUI.Helpers.OptionValues.Set({ "Units", unitKey, "Texts", textConfigKey, "templateName" }, selectedName)
            ns.GUI.Helpers.OptionValues.Set({ "Units", unitKey, "Texts", textConfigKey, "tag" }, selectedTemplate)
            ns.GUI.Helpers.OptionRefresh.Live()
            ns.GUI:RefreshOptions()
        end)

        deleteTextButton:SetCallback("OnClick", function()
            if IsUnitDisabled() then
                return
            end

            ns.GUI.Helpers.OptionValues.Set({ "Units", unitKey, "Texts", textConfigKey, "templateName" }, "")
            ns.GUI.Helpers.OptionValues.Set({ "Units", unitKey, "Texts", textConfigKey, "tag" }, "")
            ns.GUI.Helpers.OptionValues.Set({ "Units", unitKey, "Texts", textConfigKey, "enabled" }, false)
            ns.GUI.Helpers.OptionRefresh.Live()
            ns.GUI:RefreshOptions()
            SetStatus((L["INFO_UNIT_TEXT_TEMPLATE_STATUS_DELETED"] or "Text deleted:") .. " " .. textLabel)
        end)

        openBuilderButton:SetCallback("OnClick", function()
            if IsUnitDisabled() then
                return
            end

            local state = GetGUIState()
            state.textBuilder = state.textBuilder or {}
            state.textBuilder.template = currentTemplateText or ""
            state.textBuilder.templateName = currentTemplateName or ""
            state.textBuilder.selectedTemplate = currentTemplateName or ""

            if ns.GUI then
                ns.GUI.selectedPath = C.Nav.TEXT_BUILDER
            end

            if ns.guiTreeGroup and ns.guiTreeGroup.SelectByValue then
                ns.guiTreeGroup:SelectByValue(C.Nav.TEXT_BUILDER)
            elseif ns.GUI and ns.GUI.RefreshOptions then
                ns.GUI:RefreshOptions()
            end
        end)

        local basicsGroup = AceGUI:Create("InlineGroup")
        basicsGroup:SetFullWidth(true)
        basicsGroup:SetLayout("Flow")
        basicsGroup:SetTitle(ResolveLayoutText("SECTION_GENERAL"))
        content:AddChild(basicsGroup)

        local basicsLayout = CreateSection(basicsGroup)
        basicsLayout:Add(Checkbox.Create({
            path = { "Units", unitKey, "Texts", textConfigKey, "enabled" },
            label = ResolveLayoutText("OPTION_ENABLED"),
            fallback = true,
            resetText = L["OPTION_RESET"],
            disabled = IsUnitDisabled,
            refreshGUI = true,
        }))
        basicsLayout:Add(ColorPicker.Create({
            path = { "Units", unitKey, "Texts", textConfigKey, "color" },
            label = ResolveLayoutText("OPTION_COLOR"),
            hasAlpha = true,
            fallback = { 1, 1, 1, 1 },
            resetText = L["OPTION_RESET"],
            resetWidth = 64,
            disabled = IsTextDisabled,
        }))

        local sectionOrder = {
            "SECTION_POSITION",
            "SECTION_FONT",
            "SECTION_EFFECTS",
        }

        local sectionDefsByKey = {}
        for _, sectionDef in ipairs(TEXT_TAB_LAYOUT) do
            sectionDefsByKey[sectionDef.section] = sectionDefsByKey[sectionDef.section] or sectionDef
        end

        for _, sectionKey in ipairs(sectionOrder) do
            local sectionDef = sectionDefsByKey[sectionKey]
            if sectionDef and sectionDef.mode == "section" then
                local sectionGroup = AceGUI:Create("InlineGroup")
                sectionGroup:SetFullWidth(true)
                sectionGroup:SetLayout("Flow")
                sectionGroup:SetTitle(ResolveLayoutText(sectionDef.section))
                content:AddChild(sectionGroup)

                local layout = CreateSection(sectionGroup)
                for _, item in ipairs(sectionDef.items) do
                    if sectionKey == "SECTION_EFFECTS"
                        and item.widget == "colorpicker"
                        and type(item.path) == "table"
                        and item.path[#item.path] == "color"
                    then
                        -- Base text color is grouped with the basic text state above.
                    else
                        AddSectionWidget(layout, item)
                    end
                end
            end
        end
    end

    container:ReleaseChildren()
    container:SetLayout("Fill")

    local state = GetGUIState()
    local tabs = GetTextTabValues(unitKey)
    local firstTab = tabs[1] and tabs[1].value or nil

    if not firstTab then
        deps.BuildPlaceholderPage(container, ns.GetLabel(KM.Tabs, C.Tabs.TEXTS))
        return
    end

    state.unitTextTabs[unitKey] = state.unitTextTabs[unitKey] or firstTab
    state.unitTextScroll[unitKey] = state.unitTextScroll[unitKey] or {}

    local tabGroup = AceGUI:Create("TabGroup")
    tabGroup:SetFullWidth(true)
    tabGroup:SetFullHeight(true)
    tabGroup:SetLayout("Fill")
    tabGroup:SetTabs(tabs)

    tabGroup:SetCallback("OnGroupSelected", function(widget, _, textConfigKey)
        state.unitTextTabs[unitKey] = textConfigKey
        state.unitTextScroll[unitKey][textConfigKey] = state.unitTextScroll[unitKey][textConfigKey] or { scrollvalue = 0 }

        BuildScrollableTabContent(widget, state.unitTextScroll[unitKey][textConfigKey], function(content)
            local textLabel = textConfigKey
            for index, tab in ipairs(tabs) do
                if tab.value == textConfigKey then
                    textLabel = GetTextElementLabel(index)
                    break
                end
            end

            BuildUnitTextPage(content, textConfigKey, textLabel)
        end)
    end)

    container:AddChild(tabGroup)
    tabGroup:SelectTab(state.unitTextTabs[unitKey] or firstTab)
end
