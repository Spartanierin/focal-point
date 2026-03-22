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
local TextStyles = ns.GUI.Helpers and ns.GUI.Helpers.TextStyles or nil
local LayoutHelpers = ns.GUI.Helpers and ns.GUI.Helpers.LayoutHelpers or nil
local TextUtils = FocalPoint and FocalPoint.TextElementUtils or nil
local TextColors = FocalPoint and FocalPoint.TextElementColors or nil

local function TemplateUsesToken(template, token)
    if type(template) ~= "string" or template == "" or type(token) ~= "string" or token == "" then
        return false
    end

    return template:find("%[" .. token:gsub("([^%w:])", "%%%1") .. "%]") ~= nil
end

local function ApplyPreviewTextAppearance(widget, unitKey, textKey, textConfig, templateText)
    if not widget or type(textConfig) ~= "table" then
        return
    end

    local fontString = widget.label or widget.text
    if not fontString then
        return
    end

    local fontPath = TextUtils and TextUtils.GetFontPath and TextUtils.GetFontPath(textConfig.font) or STANDARD_TEXT_FONT
    local fontSize = textConfig.fontSize or 12
    local fontFlags = TextUtils and TextUtils.BuildFontFlags and TextUtils.BuildFontFlags(textConfig) or ""
    local justifyH = textConfig.justifyH or "LEFT"

    if fontString.SetFont then
        fontString:SetFont(fontPath, fontSize, fontFlags ~= "" and fontFlags or nil)
    end

    if fontString.SetJustifyH then
        fontString:SetJustifyH(justifyH)
    end

    local r, g, b, a = 1, 1, 1, 1
    if TextUtils and TextUtils.UnpackColor then
        r, g, b, a = TextUtils.UnpackColor(textConfig.color, { 1, 1, 1, 1 })
    end

    local previewFrame = {
        unit = unitKey,
        IsTemplatePreview = true,
        TestValues = ns.UnitFrame and ns.UnitFrame.GetTestPreviewValues and ns.UnitFrame:GetTestPreviewValues({ unit = unitKey }) or nil,
    }

    if textKey == "Class" or TemplateUsesToken(templateText, "class") then
        local classR, classG, classB, classA = TextColors and TextColors.GetClassTextColor and TextColors.GetClassTextColor(unitKey, previewFrame)
        if classR and classG and classB then
            r, g, b, a = classR, classG, classB, classA or 1
        end
    elseif textKey == "Level" then
        r, g, b, a = 1.00, 0.82, 0.00, 1.00
    end

    if fontString.SetTextColor then
        fontString:SetTextColor(r, g, b, a)
    end

    if textConfig.shadowEnabled then
        local sx = textConfig.shadowOffsetX or 1
        local sy = textConfig.shadowOffsetY or -1
        local sr, sg, sb, sa = 0, 0, 0, 1
        if TextUtils and TextUtils.UnpackColor then
            sr, sg, sb, sa = TextUtils.UnpackColor(textConfig.shadowColor, { 0, 0, 0, 1 })
        end

        if fontString.SetShadowOffset then
            fontString:SetShadowOffset(sx, sy)
        end
        if fontString.SetShadowColor then
            fontString:SetShadowColor(sr, sg, sb, sa)
        end
    else
        if fontString.SetShadowOffset then
            fontString:SetShadowOffset(0, 0)
        end
        if fontString.SetShadowColor then
            fontString:SetShadowColor(0, 0, 0, 0)
        end
    end
end

local UnitTextsPage = {}
ns.GUI.Pages.UnitTexts = UnitTextsPage

function UnitTextsPage.Build(container, unitKey, deps)
    local GetGUIState = deps.GetGUIState
    local GetTextElementLabel = deps.GetTextElementLabel
    local GetTextTabValues = deps.GetTextTabValues
    local ResetFlowContainer = deps.ResetFlowContainer
    local AddSectionHeading = deps.AddSectionHeading
    local CreateSection = deps.CreateSection
    local AddLayoutHandle = deps.AddLayoutHandle
    local BuildScrollableTabContent = deps.BuildScrollableTabContent
    local ResolveLayoutText = deps.ResolveLayoutText
    local ResolveLayoutPath = deps.ResolveLayoutPath
    local ResolveLayoutList = deps.ResolveLayoutList
    local CanBuildLayoutWidget = deps.CanBuildLayoutWidget

    local function BuildUnitTextPage(content, textConfigKey, textLabel)
        ResetFlowContainer(content)
        if LayoutHelpers and LayoutHelpers.ApplyUnitLayoutDefaults then
            LayoutHelpers.ApplyUnitLayoutDefaults(content)
        end

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

        local function ValuesEqual(left, right)
            if type(left) ~= type(right) then
                return false
            end

            if type(left) ~= "table" then
                return left == right
            end

            for key, value in pairs(left) do
                if not ValuesEqual(value, right[key]) then
                    return false
                end
            end

            for key, value in pairs(right) do
                if not ValuesEqual(left[key], value) then
                    return false
                end
            end

            return true
        end

        local function IsPathAtDefault(path)
            local currentValue = ns.GUI.Helpers.OptionValues.Get(path, nil)
            local defaultValue = ns.GUI.Helpers.OptionValues.GetDefault(path, nil)
            return ValuesEqual(currentValue, defaultValue)
        end

        local function ResetPaths(paths, disabled)
            if type(disabled) == "function" and disabled() then
                return
            end

            local changed = false
            for _, path in ipairs(paths) do
                changed = ns.GUI.Helpers.OptionValues.Reset(path) or changed
            end

            if changed then
                ns.GUI.Helpers.OptionRefresh.Live()
                ns.GUI:RefreshOptions()
            end
        end

        local function BuildSectionResetAction(paths, disabled)
            if type(paths) ~= "table" or #paths == 0 then
                return nil
            end

            return {
                text = L["OPTION_RESET"] or RESET or "Reset",
                width = 112,
                onClick = function()
                    ResetPaths(paths, disabled)
                end,
            }
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
            if TextStyles and TextStyles.ApplyInteractiveWidgetText then
                TextStyles.ApplyInteractiveWidgetText(
                    editBox,
                    "label",
                    ns.GUI.Helpers.OptionValues.ResolveState(disabled, def),
                    { size = 12 }
                )
            end
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
                if TextStyles and TextStyles.ApplyLabelWidget then
                    TextStyles.ApplyLabelWidget(
                        description,
                        ns.GUI.Helpers.OptionValues.ResolveState(disabled, def) and "disabled" or "help",
                        { size = 11 }
                    )
                end
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
                if TextStyles and TextStyles.ApplyInteractiveWidgetText then
                    TextStyles.ApplyInteractiveWidgetText(
                        dropdown,
                        "label",
                        ns.GUI.Helpers.OptionValues.ResolveState(disabled, def),
                        { size = 12 }
                    )
                end
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

                if def.description and def.description ~= "" then
                    local description = AceGUI:Create("Label")
                    description:SetFullWidth(true)
                    description:SetText(ResolveLayoutText(def.description))
                    if TextStyles and TextStyles.ApplyLabelWidget then
                        TextStyles.ApplyLabelWidget(
                            description,
                            ns.GUI.Helpers.OptionValues.ResolveState(disabled, def) and "disabled" or "help",
                            { size = 11 }
                        )
                    end
                    group:AddChild(description)
                end

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
                    showReset = def.showReset,
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
                    showReset = false,
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
                    showReset = false,
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
                    showReset = false,
                    resetText = def.resetText ~= nil and def.resetText or L["OPTION_RESET"],
                    resetWidth = def.resetWidth or 64,
                    disabled = ResolveDisabled(def),
                }), def)
            end
        end

        local templatesList, templates = GetTemplateList()
        local textConfig = GetTextConfig()
        local currentTemplateName = ResolveCurrentTemplateName(textConfig, templates)
        local currentTemplateText = ResolveCurrentTemplateText(textConfig, templates)

        AddSectionHeading(content, ResolveLayoutText("SECTION_GENERAL"), 0, BuildSectionResetAction({
            { "Units", unitKey, "Texts", textConfigKey, "enabled" },
            { "Units", unitKey, "Texts", textConfigKey, "color" },
        }, IsTextDisabled))
        local basicsLayout = CreateSection(content)
        local generalHint = AceGUI:Create("Label")
        generalHint:SetFullWidth(true)
        generalHint:SetText(L["INFO_UNIT_TEXT_GENERAL_HINT"] or "Controls whether this text element is active and which base color it uses.")
        if TextStyles and TextStyles.ApplyLabelWidget then
            TextStyles.ApplyLabelWidget(generalHint, "help", { size = 10 })
        end
        basicsLayout:Add({ group = generalHint }, {
            placement = "full",
        })
        AddLayoutHandle(basicsLayout, Checkbox.Create({
            path = { "Units", unitKey, "Texts", textConfigKey, "enabled" },
            label = ResolveLayoutText("OPTION_ENABLED"),
            description = ResolveLayoutText("OPTION_ENABLED_DESC"),
            fallback = true,
            showReset = false,
            resetText = L["OPTION_RESET"],
            disabled = IsUnitDisabled,
            refreshGUI = true,
        }), {
            widget = "checkbox",
            path = { "Units", unitKey, "Texts", textConfigKey, "enabled" },
            placement = "left",
            rowType = "inline",
        })
        AddLayoutHandle(basicsLayout, ColorPicker.Create({
            path = { "Units", unitKey, "Texts", textConfigKey, "color" },
            label = ResolveLayoutText("OPTION_COLOR"),
            description = ResolveLayoutText("OPTION_COLOR_DESC"),
            hasAlpha = true,
            fallback = { 1, 1, 1, 1 },
            resetText = L["OPTION_RESET"],
            resetWidth = 64,
            disabled = IsTextDisabled,
        }), {
            widget = "colorpicker",
            path = { "Units", unitKey, "Texts", textConfigKey, "color" },
            placement = "right",
            rowType = "inline",
        })

        local templateHint = AceGUI:Create("Label")
        templateHint:SetFullWidth(true)
        templateHint:SetText(L["INFO_UNIT_TEXT_TEMPLATE_HINT"] or "Choose a template for this text element. Layout, font, and effects stay on this page.")
        if TextStyles and TextStyles.ApplyLabelWidget then
            TextStyles.ApplyLabelWidget(templateHint, "help", { size = 10 })
        end

        AddSectionHeading(content, L["INFO_UNIT_TEXT_TEMPLATE_GROUP"] or "Template")
        local templateFields = CreateSection(content)
        templateFields:Add({ group = templateHint }, {
            placement = "full",
        })
        local stateTemplateOptions = {
            { key = "dead", label = L["INFO_UNIT_TEXT_TEMPLATE_STATE_DEAD"] or "When DEAD" },
            { key = "ghost", label = L["INFO_UNIT_TEXT_TEMPLATE_STATE_GHOST"] or "When GHOST" },
            { key = "offline", label = L["INFO_UNIT_TEXT_TEMPLATE_STATE_OFFLINE"] or "When OFFLINE" },
            { key = "afk", label = L["INFO_UNIT_TEXT_TEMPLATE_STATE_AFK"] or "When AFK" },
            { key = "dnd", label = L["INFO_UNIT_TEXT_TEMPLATE_STATE_DND"] or "When DND" },
        }

        local templateDropdownGroup = AceGUI:Create("SimpleGroup")
        templateDropdownGroup:SetFullWidth(true)
        templateDropdownGroup:SetLayout("Flow")
        local templateDropdown = AceGUI:Create("Dropdown")
        templateDropdown:SetLabel(L["INFO_UNIT_TEXT_TEMPLATE_SELECT"] or "Template")
        templateDropdown:SetWidth(320)
        templateDropdown:SetList(templatesList)
        templateDropdown:SetValue(currentTemplateName ~= "" and currentTemplateName or nil)
        templateDropdown:SetDisabled(IsUnitDisabled())
        if TextStyles and TextStyles.ApplyInteractiveWidgetText then
            TextStyles.ApplyInteractiveWidgetText(templateDropdown, "label", IsUnitDisabled(), { size = 12 })
        end
        templateDropdownGroup:AddChild(templateDropdown)

        local stateTemplateList = { [""] = L["OPTION_NONE"] or "None" }
        for templateName, label in pairs(templatesList) do
            stateTemplateList[templateName] = label
        end

        local stateHint = AceGUI:Create("Label")
        stateHint:SetFullWidth(true)
        stateHint:SetText(L["INFO_UNIT_TEXT_TEMPLATE_STATE_HINT"] or "Optional: choose a replacement template for specific unit states. While a state is active, it replaces the base template above.")
        if TextStyles and TextStyles.ApplyLabelWidget then
            TextStyles.ApplyLabelWidget(stateHint, "help", { size = 10 })
        end

        local stateHintSecondary = AceGUI:Create("Label")
        stateHintSecondary:SetFullWidth(true)
        stateHintSecondary:SetText(L["INFO_UNIT_TEXT_TEMPLATE_STATE_HINT_SECONDARY"] or "Leave a state empty to keep using the base template.")
        if TextStyles and TextStyles.ApplyLabelWidget then
            TextStyles.ApplyLabelWidget(stateHintSecondary, "help", { size = 10 })
        end

        local leftTemplateColumn = AceGUI:Create("SimpleGroup")
        leftTemplateColumn:SetFullWidth(true)
        leftTemplateColumn:SetLayout("Flow")

        leftTemplateColumn:AddChild(templateDropdownGroup)

        local rightTemplateColumn = AceGUI:Create("SimpleGroup")
        rightTemplateColumn:SetFullWidth(true)
        rightTemplateColumn:SetLayout("Flow")

        local rightTemplateHeading = AceGUI:Create("Label")
        rightTemplateHeading:SetFullWidth(true)
        rightTemplateHeading:SetText(L["INFO_UNIT_TEXT_TEMPLATE_STATE_GROUP_OPTIONAL"] or "Optional Replacement Templates")
        if TextStyles and TextStyles.ApplyLabelWidget then
            TextStyles.ApplyLabelWidget(rightTemplateHeading, "highlight", { size = 12 })
        end
        rightTemplateColumn:AddChild(rightTemplateHeading)
        rightTemplateColumn:AddChild(stateHint)
        rightTemplateColumn:AddChild(stateHintSecondary)

        for _, option in ipairs(stateTemplateOptions) do
            local stateDropdownGroup = AceGUI:Create("SimpleGroup")
            stateDropdownGroup:SetFullWidth(true)
            stateDropdownGroup:SetLayout("Flow")

            local stateDropdown = AceGUI:Create("Dropdown")
            stateDropdown:SetLabel(option.label)
            stateDropdown:SetWidth(320)
            stateDropdown:SetList(stateTemplateList)
            stateDropdown:SetValue(textConfig.stateTemplates and textConfig.stateTemplates[option.key] or "")
            stateDropdown:SetDisabled(IsUnitDisabled())
            if TextStyles and TextStyles.ApplyInteractiveWidgetText then
                TextStyles.ApplyInteractiveWidgetText(stateDropdown, "label", IsUnitDisabled(), { size = 12 })
            end
            stateDropdown:SetCallback("OnValueChanged", function(_, _, value)
                if IsUnitDisabled() then
                    return
                end

                ns.GUI.Helpers.OptionValues.Set({ "Units", unitKey, "Texts", textConfigKey, "stateTemplates", option.key }, value or "")
                ns.GUI.Helpers.OptionRefresh.Live()
                ns.GUI:RefreshOptions()
            end)
            stateDropdownGroup:AddChild(stateDropdown)

            rightTemplateColumn:AddChild(stateDropdownGroup)
        end

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
            if TextStyles and TextStyles.ApplyInteractiveWidgetText then
                TextStyles.ApplyInteractiveWidgetText(rawTemplateEdit, "label", IsUnitDisabled(), { size = 12 })
            end
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
            expertInfo:SetText(L["INFO_UNIT_TEXT_TEMPLATE_EXPERT_HINT"] or "Expert Mode: you can still edit the raw template string below.")
            if TextStyles and TextStyles.ApplyLabelWidget then
                TextStyles.ApplyLabelWidget(expertInfo, "help", { size = 10 })
            end
            rawTemplateGroup:AddChild(expertInfo)
            leftTemplateColumn:AddChild(rawTemplateGroup)
        end

        local previewTopSpacer = AceGUI:Create("Label")
        previewTopSpacer:SetFullWidth(true)
        previewTopSpacer:SetText(" ")
        previewTopSpacer:SetHeight(6)
        leftTemplateColumn:AddChild(previewTopSpacer)

        local previewGroup = AceGUI:Create("SimpleGroup")
        previewGroup:SetFullWidth(true)
        previewGroup:SetLayout("Flow")

        local previewPanel = AceGUI:Create("InlineGroup")
        previewPanel:SetFullWidth(true)
        previewPanel:SetLayout("Flow")
        previewPanel:SetTitle(L["INFO_UNIT_TEXT_TEMPLATE_CURRENT_PREVIEW"] or "Current Preview")
        if previewPanel._focalPointHeaderButton then
            previewPanel._focalPointHeaderButton:SetScript("OnClick", nil)
            previewPanel._focalPointHeaderButton:Hide()
        end
        if previewPanel.titletext and TextStyles and TextStyles.ApplyFontString then
            TextStyles.ApplyFontString(previewPanel.titletext, "highlight", {
                size = 12,
                shadow = true,
            })
        end

        local previewBox = AceGUI:Create("Label")
        previewBox:SetFullWidth(true)
        previewBox:SetHeight(math.max((textConfig.fontSize or 12) + 18, 40))
        previewBox:SetText((ns.UnitFrame and ns.UnitFrame.BuildTemplatePreview and ns.UnitFrame:BuildTemplatePreview(currentTemplateText)) or currentTemplateText or " ")
        ApplyPreviewTextAppearance(previewBox, unitKey, textConfigKey, textConfig, currentTemplateText)
        previewPanel:AddChild(previewBox)
        previewGroup:AddChild(previewPanel)
        leftTemplateColumn:AddChild(previewGroup)

        local actionTopSpacer = AceGUI:Create("Label")
        actionTopSpacer:SetFullWidth(true)
        actionTopSpacer:SetText(" ")
        actionTopSpacer:SetHeight(6)
        leftTemplateColumn:AddChild(actionTopSpacer)

        local actionGroup = AceGUI:Create("SimpleGroup")
        actionGroup:SetFullWidth(true)
        actionGroup:SetLayout("Flow")

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
        leftTemplateColumn:AddChild(actionGroup)

        templateFields:Add({ group = leftTemplateColumn }, {
            placement = "left",
        })

        templateFields:Add({ group = rightTemplateColumn }, {
            placement = "right",
        })

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
            ns.GUI.Helpers.OptionValues.Set({ "Units", unitKey, "Texts", textConfigKey, "stateTemplates" }, {})
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
                local resetPaths = {}
                for _, item in ipairs(sectionDef.items) do
                    if type(item.path) == "table" then
                        local skipBaseColor = sectionKey == "SECTION_EFFECTS"
                            and item.widget == "colorpicker"
                            and item.path[#item.path] == "color"

                        if not skipBaseColor then
                            table.insert(resetPaths, ResolveLayoutPath(item.path, unitKey, tokenReplacements))
                        end
                    end
                end

                AddSectionHeading(content, ResolveLayoutText(sectionDef.section), 0, BuildSectionResetAction(resetPaths, IsTextDisabled))
                local layout = CreateSection(content)

                for _, item in ipairs(sectionDef.items) do
                    local itemDef = {}
                    for key, value in pairs(item) do
                        itemDef[key] = value
                    end
                    itemDef.subsection = nil

                    if sectionKey == "SECTION_EFFECTS"
                        and itemDef.widget == "colorpicker"
                        and type(itemDef.path) == "table"
                        and itemDef.path[#itemDef.path] == "color"
                    then
                        -- Base text color is grouped with the basic text state above.
                    else
                        AddSectionWidget(layout, itemDef)
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
