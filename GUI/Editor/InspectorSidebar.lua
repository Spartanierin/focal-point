local _, ns = ...

ns.GUI = ns.GUI or {}
ns.GUI.Editor = ns.GUI.Editor or {}

local AceGUI = LibStub("AceGUI-3.0")
local InspectorSidebar = {}
ns.GUI.Editor.InspectorSidebar = InspectorSidebar

local L = ns.L or {}
local Shared = ns.GUI.Editor.SidebarShared or {}

local POINTS = Shared.POINTS or {}
local INDICATOR_META = Shared.INDICATOR_META or {}
local AddSpacer = Shared.AddSpacer
local CreateSection = Shared.CreateSection
local BuildLocalizedList = Shared.BuildLocalizedList
local AddCheckBox = Shared.AddCheckBox
local AddSlider = Shared.AddSlider
local AddDropdown = Shared.AddDropdown
local AddColorPicker = Shared.AddColorPicker
local BuildTextList = Shared.BuildTextList
local BuildIndicatorList = Shared.BuildIndicatorList
local GetFirstIndicatorKey = Shared.GetFirstIndicatorKey
local BuildAuraList = Shared.BuildAuraList
local GetFirstAuraKey = Shared.GetFirstAuraKey
local GetFirstTextId = Shared.GetFirstTextId or Shared.GetFirstTextKey

function InspectorSidebar.Build(container, state, options)
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
    local selectedTextId = state.selectedTextId or state.selectedTextKey
    if not textList[selectedTextId] then
        selectedTextId = GetFirstTextId(textList)
        state.selectedTextId = selectedTextId
        state.selectedTextKey = selectedTextId
    end

    local textConfig = type(unitConfig.Texts) == "table" and unitConfig.Texts[selectedTextId] or nil
    local linkedTemplateName = textConfig and textConfig.templateName or nil
    if (type(linkedTemplateName) ~= "string" or linkedTemplateName == "") and textConfig and type(textConfig.stateTemplates) == "table" then
        for _, stateTemplateName in pairs(textConfig.stateTemplates) do
            if type(stateTemplateName) == "string" and stateTemplateName ~= "" then
                linkedTemplateName = stateTemplateName
                break
            end
        end
    end
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

        local textSection = CreateInspectorSection("texts", L["EDITOR_SECTION_TEXT_ELEMENTS"] or "Text Elements", true)
        if textSection then

            AddDropdown(textSection, L["EDITOR_OPTION_TEXT_ELEMENT"] or "Text Element", textList, selectedTextId, function(value)
                state.selectedTextId = value
                state.selectedTextKey = value
                NotifySidebarChanged()
            end)

            local templateSummary = AceGUI:Create("Label")
            templateSummary:SetFullWidth(true)
            templateSummary:SetText(
                (L["EDITOR_TEMPLATE_LINKED"] or "Linked Template") .. ": " ..
                ((type(linkedTemplateName) == "string" and linkedTemplateName ~= "") and linkedTemplateName or (L["EDITOR_TEXT_DIRECT_TEMPLATE"] or "Direct Template"))
            )
            if templateSummary.label and templateSummary.label.SetFont then
                templateSummary.label:SetFont(STANDARD_TEXT_FONT, 10, "")
                templateSummary.label:SetTextColor(0.55, 0.59, 0.64, 1)
            end
            textSection:AddChild(templateSummary)

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

return InspectorSidebar
