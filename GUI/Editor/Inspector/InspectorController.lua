local _, ns = ...

ns.GUI = ns.GUI or {}
ns.GUI.Editor = ns.GUI.Editor or {}
ns.GUI.Editor.Inspector = ns.GUI.Editor.Inspector or {}

local AceGUI = LibStub("AceGUI-3.0")
local InspectorController = ns.GUI.Editor.Inspector
ns.GUI.Editor.Inspector = InspectorController
local InspectorBinding = InspectorController.InspectorBinding or {}
local InspectorContext = ns.InspectorContext or (ns.GUI.Editor.Inspector and ns.GUI.Editor.Inspector.Context) or {}
local InspectorTextSelection = ns.InspectorTextSelection or (ns.GUI.Editor.Inspector and ns.GUI.Editor.Inspector.TextSelection) or {}
local InspectorIndicatorSelection = ns.InspectorIndicatorSelection or (ns.GUI.Editor.Inspector and ns.GUI.Editor.Inspector.IndicatorSelection) or {}
local InspectorAuraSelection = ns.InspectorAuraSelection or (ns.GUI.Editor.Inspector and ns.GUI.Editor.Inspector.AuraSelection) or {}
local InspectorMutations = ns.InspectorMutations or (ns.GUI.Editor.Inspector and ns.GUI.Editor.Inspector.Mutations) or {}
local InspectorRefreshPolicy = ns.InspectorRefreshPolicy or (ns.GUI.Editor.Inspector and ns.GUI.Editor.Inspector.RefreshPolicy) or {}

local L = ns.L or {}
local FormWidgets = ns.GUI.Helpers and ns.GUI.Helpers.FormWidgets or {}
local ResolveItemColor = FormWidgets.ResolveItemColor
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
local GetFirstTextId = Shared.GetFirstTextId
local INSPECTOR_SECTION_SPACING = 10

function InspectorController.Build(container, state, options)
    container:ReleaseChildren()
    container:SetLayout("Flow")

    local barLayouts = ns.GUI and ns.GUI.Layouts and ns.GUI.Layouts.UnitBars or {}
    local frameLayouts = ns.GUI and ns.GUI.Layouts and ns.GUI.Layouts.UnitFrame or {}
    local textLayouts = ns.GUI and ns.GUI.Layouts and ns.GUI.Layouts.UnitTexts or {}
    local portraitLayouts = ns.GUI and ns.GUI.Layouts and ns.GUI.Layouts.UnitPortrait or {}
    local classificationLayouts = ns.GUI and ns.GUI.Layouts and ns.GUI.Layouts.UnitClassificationIndicator or {}
    local statusIndicatorLayouts = ns.GUI and ns.GUI.Layouts and ns.GUI.Layouts.UnitStatusIndicator or {}
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
    local statusIndicatorEffectList = BuildLocalizedList(statusIndicatorLayouts.Lists and statusIndicatorLayouts.Lists.effect)
    local auraPlacementList = BuildLocalizedList(auraLayouts.Lists and auraLayouts.Lists.placement)
    local auraAnchorTargetList = BuildLocalizedList(auraLayouts.Lists and auraLayouts.Lists.anchorTo)
    local auraAnchorPointList = BuildLocalizedList(auraLayouts.Lists and auraLayouts.Lists.anchorPoints)
    local auraInsideSideList = BuildLocalizedList(auraLayouts.Lists and auraLayouts.Lists.insideSide)
    local auraGrowthXList = BuildLocalizedList(auraLayouts.Lists and auraLayouts.Lists.growthX)
    local auraGrowthYList = BuildLocalizedList(auraLayouts.Lists and auraLayouts.Lists.growthY)
    local auraSortModeList = BuildLocalizedList(auraLayouts.Lists and auraLayouts.Lists.sortMode)

    textAnchorTargetList.CastBar = textAnchorTargetList.CastBar or (L["BAR_CAST"] or "Cast Bar")
    textAnchorTargetList.AlternativePowerBar = textAnchorTargetList.AlternativePowerBar or (L["BAR_ALT_POWER"] or "Alt Power")
    textAnchorTargetList.ClassPowerBar = textAnchorTargetList.ClassPowerBar or (L["BAR_CLASS_POWER"] or "Class Power")
    local classPowerAnchorTargetList = {
        Frame = textAnchorTargetList.Frame or (L["EDITOR_SECTION_FRAME"] or "Frame"),
        HealthBar = textAnchorTargetList.HealthBar or (L["BAR_HEALTH"] or "Health"),
        PowerBar = textAnchorTargetList.PowerBar or (L["BAR_POWER"] or "Power"),
        AlternativePowerBar = textAnchorTargetList.AlternativePowerBar or (L["BAR_ALT_POWER"] or "Alt Power"),
        CastBar = textAnchorTargetList.CastBar or (L["BAR_CAST"] or "Cast"),
    }

    local inspectorContext = InspectorContext.Create and InspectorContext.Create({
        state = state,
        profile = ns.db and ns.db.profile,
        getUnitConfig = function(unitKey)
            return ns.UnitFrameUtils and ns.UnitFrameUtils.GetUnitDB and ns.UnitFrameUtils.GetUnitDB(unitKey) or nil
        end,
        buildTextList = function(_, currentUnitConfig)
            return BuildTextList(type(currentUnitConfig) == "table" and currentUnitConfig.Texts or nil)
        end,
        getFirstTextId = GetFirstTextId,
        buildIndicatorList = function(unitKey)
            return BuildIndicatorList(unitKey)
        end,
        getFirstIndicatorKey = GetFirstIndicatorKey,
        indicatorMeta = INDICATOR_META,
        buildAuraList = function(_, currentUnitConfig)
            return BuildAuraList(currentUnitConfig)
        end,
        getFirstAuraKey = GetFirstAuraKey,
    }) or {}

    local isQuick = inspectorContext.isQuick == true
    local isExpert = inspectorContext.isExpert == true
    local selectedUnit = inspectorContext.unitKey
    local unitConfig = inspectorContext.unitConfig
    if type(unitConfig) ~= "table" then
        local label = AceGUI:Create("Label")
        label:SetFullWidth(true)
        label:SetText("Missing unit config.")
        container:AddChild(label)
        return
    end

    local function ResolveTextContext()
        local currentTextList = BuildTextList(type(unitConfig) == "table" and unitConfig.Texts or nil)
        local visualTextUnit = state and state.selectedTextElementUnit
        local visualTextId = state and state.selectedTextElementId
        if visualTextUnit == selectedUnit
            and type(visualTextId) == "string"
            and visualTextId ~= ""
            and type(unitConfig.Texts) == "table"
            and type(unitConfig.Texts[visualTextId]) == "table"
            and currentTextList[visualTextId] == nil
        then
            currentTextList[visualTextId] = visualTextId
        end
        if type(InspectorTextSelection.Resolve) == "function" and InspectorContext.GetTextSelection then
            local result = InspectorTextSelection.Resolve({
                state = state,
                textList = currentTextList,
                unitConfig = unitConfig,
                getFirstTextId = GetFirstTextId,
            })
            local selectedTextId, textConfig, linkedTemplateName = InspectorContext.GetTextSelection({
                textSelection = result,
            })
            return selectedTextId, textConfig, linkedTemplateName, result, currentTextList
        end

        return nil, nil, nil, nil, currentTextList
    end

    local function BuildMissingTemplateMessages(textId)
        local scanner = ns.TextTemplateUsage and ns.TextTemplateUsage.ScanActiveProfileTemplateAssignments
        if type(scanner) ~= "function" or textId == nil then
            return {}
        end

        local primaryMissing = nil
        local missingStates = {}
        for _, entry in ipairs(scanner(ns.db) or {}) do
            if entry.unit == selectedUnit and entry.textId == textId and entry.isMissing then
                if entry.isPrimary then
                    primaryMissing = entry.templateName
                elseif entry.isState then
                    missingStates[#missingStates + 1] = string.format("%s -> %s", tostring(entry.stateKey or "?"), tostring(entry.templateName or "?"))
                end
            end
        end

        local messages = {}
        if type(primaryMissing) == "string" and primaryMissing ~= "" then
            messages[#messages + 1] = string.format("Template \"%s\" is not installed in the active profile.", primaryMissing)
        end
        if #missingStates > 0 then
            table.sort(missingStates)
            messages[#messages + 1] = "Missing state templates: " .. table.concat(missingStates, ", ")
        end
        return messages
    end

    local function ResolveIndicatorContext()
        local currentIndicatorList = type(BuildIndicatorList) == "function" and BuildIndicatorList(selectedUnit) or {}
        if type(InspectorIndicatorSelection.Resolve) == "function" and InspectorContext.GetIndicatorSelection then
            local result = InspectorIndicatorSelection.Resolve({
                state = state,
                indicatorList = currentIndicatorList,
                indicatorMeta = INDICATOR_META,
                unitConfig = unitConfig,
                unitKey = selectedUnit,
                getFirstIndicatorKey = GetFirstIndicatorKey,
            })
            local selectedIndicatorKey, indicatorMeta, indicatorConfig = InspectorContext.GetIndicatorSelection({
                indicatorSelection = result,
            })
            return selectedIndicatorKey, indicatorMeta, indicatorConfig, result, currentIndicatorList
        end

        return nil, nil, nil, nil, currentIndicatorList
    end

    local function ResolveAuraContext()
        local currentAuraList = type(BuildAuraList) == "function" and BuildAuraList(unitConfig) or {}
        if type(InspectorAuraSelection.Resolve) == "function" and InspectorContext.GetAuraSelection then
            local result = InspectorAuraSelection.Resolve({
                state = state,
                auraList = currentAuraList,
                unitConfig = unitConfig,
                getFirstAuraKey = GetFirstAuraKey,
            })
            local selectedAuraKey, auraConfig = InspectorContext.GetAuraSelection({
                auraSelection = result,
            })
            return selectedAuraKey, auraConfig, result, currentAuraList
        end

        return nil, nil, nil, currentAuraList
    end

    local function NotifyConfigChanged()
        if options.onConfigChanged then
            options.onConfigChanged()
        end
    end

    local function NotifyUnitEnabledChanged()
        if options.onUnitEnabledChanged then
            options.onUnitEnabledChanged()
        else
            NotifyConfigChanged()
        end
    end

    local function NotifySidebarChanged(sectionKey)
        if options.onSidebarChanged then
            options.onSidebarChanged(sectionKey)
        else
            NotifyConfigChanged()
        end
    end

    local function RebuildLocalSection(section)
        if section and section._focalPointRequestRebuild then
            section._focalPointRequestRebuild()
            return true
        end
        return false
    end

    local function NotifyConfigChangedAndRebuildSection(section, fallbackSectionKey)
        NotifyConfigChanged()
        if not RebuildLocalSection(section) and fallbackSectionKey then
            NotifySidebarChanged(fallbackSectionKey)
        end
    end

    local function ApplyRefreshPolicy(policy, section)
        local scope = type(policy) == "table" and policy.scope or "live"
        if scope == "none" then
            return
        end
        if scope == "section" then
            NotifyConfigChangedAndRebuildSection(section, policy and policy.sectionKey)
            return
        end
        if scope == "sidebar" then
            NotifySidebarChanged(policy and policy.sectionKey)
            return
        end

        NotifyConfigChanged()
    end

    local function ResolveMutationErrorMessage(result)
        local errorCode = type(result) == "table" and result.errorCode or nil
        if errorCode == "unit_config_not_found" then
            return L["EDITOR_INSPECTOR_ERROR_UNIT_CONFIG_NOT_FOUND"] or L["EDITOR_INSPECTOR_ERROR_CHANGE_FAILED"]
        elseif errorCode == "text_config_not_found" then
            return L["EDITOR_INSPECTOR_ERROR_TEXT_CONFIG_NOT_FOUND"] or L["EDITOR_INSPECTOR_ERROR_CHANGE_FAILED"]
        elseif errorCode == "indicator_config_not_found" then
            return L["EDITOR_INSPECTOR_ERROR_INDICATOR_CONFIG_NOT_FOUND"] or L["EDITOR_INSPECTOR_ERROR_CHANGE_FAILED"]
        elseif errorCode == "aura_config_not_found" then
            return L["EDITOR_INSPECTOR_ERROR_AURA_CONFIG_NOT_FOUND"] or L["EDITOR_INSPECTOR_ERROR_CHANGE_FAILED"]
        end

        return L["EDITOR_INSPECTOR_ERROR_CHANGE_FAILED"]
    end

    local function ReportMutationError(result)
        if ns.GUI and type(ns.GUI.SetStatusText) == "function" then
            ns.GUI:SetStatusText(ResolveMutationErrorMessage(result))
        end
    end

    local function ApplyMutation(targetKind, fieldName, result, section, fallbackNotify)
        if result and result.ok == false then
            ReportMutationError(result)
            return result
        end

        if not (result and result.ok and result.changed) then
            return result
        end

        if type(fallbackNotify) == "function" then
            fallbackNotify()
            return result
        end

        local policy = type(InspectorRefreshPolicy.Resolve) == "function"
            and InspectorRefreshPolicy.Resolve(targetKind, fieldName)
            or { scope = "live" }
        ApplyRefreshPolicy(policy, section)
        return result
    end

    local function SetUnitField(fieldName, value, section, fallbackNotify)
        if type(InspectorMutations.SetUnitField) ~= "function" then
            return nil
        end
        return ApplyMutation("unit", fieldName, InspectorMutations.SetUnitField(inspectorContext, fieldName, value), section, fallbackNotify)
    end

    local function SetTextField(textKey, fieldName, value, section, fallbackNotify)
        if type(InspectorMutations.SetTextField) ~= "function" then
            return nil
        end
        return ApplyMutation("text", fieldName, InspectorMutations.SetTextField(inspectorContext, textKey, fieldName, value), section, fallbackNotify)
    end

    local function SetIndicatorField(indicatorKey, fieldName, value, section, fallbackNotify)
        if type(InspectorMutations.SetIndicatorField) ~= "function" then
            return nil
        end
        return ApplyMutation("indicator", fieldName, InspectorMutations.SetIndicatorField(inspectorContext, indicatorKey, fieldName, value), section, fallbackNotify)
    end

    local function SetAuraField(auraKey, fieldName, value, section, fallbackNotify)
        if type(InspectorMutations.SetAuraField) ~= "function" then
            return nil
        end
        return ApplyMutation("aura", fieldName, InspectorMutations.SetAuraField(inspectorContext, auraKey, fieldName, value), section, fallbackNotify)
    end

    local function RefreshInspectorLayout()
        if container and container.DoLayout then
            container:DoLayout()
        end
        if container and container.FixScroll then
            container:FixScroll()
        end
        local parent = container and container.parent or nil
        if parent and parent.DoLayout then
            parent:DoLayout()
        end
        if parent and parent.FixScroll then
            parent:FixScroll()
        end
        if C_Timer and C_Timer.After then
            C_Timer.After(0, function()
                if container and container.DoLayout then
                    container:DoLayout()
                end
                if container and container.FixScroll then
                    container:FixScroll()
                end
                local delayedParent = container and container.parent or nil
                if delayedParent and delayedParent.DoLayout then
                    delayedParent:DoLayout()
                end
                if delayedParent and delayedParent.FixScroll then
                    delayedParent:FixScroll()
                end
            end)
        end
    end

    local function CreateInspectorSection(sectionKey, title, defaultCollapsed, sectionOptions)
        return InspectorBinding.CreateInspectorSection(container, CreateSection, state, sectionKey, title, defaultCollapsed, NotifySidebarChanged, sectionOptions)
    end

    local summarySection = InspectorBinding.ApplyInspectorSectionStructure(
        CreateSection(container, L["EDITOR_SIDEBAR_TITLE"] or "Inspector", { style = "prominent" }),
        "prominent"
    )
    if summarySection then
        local summaryTextColor = ResolveItemColor and ResolveItemColor("statusMuted") or { 0.66, 0.70, 0.75, 1 }
        local hintTextColor = ResolveItemColor and ResolveItemColor("description") or { 0.60, 0.64, 0.69, 1 }
        local inspectorSummary = AceGUI:Create("Label")
        inspectorSummary:SetFullWidth(true)
        inspectorSummary:SetText(string.format(
            "%s: |cffefe6c5%s|r  |  %s: |cff9cd5ff%s|r",
            L["EDITOR_UNIT"] or "Unit",
            ns.GetLabel and ns.GetLabel(ns.KeyMap.Units, selectedUnit) or selectedUnit,
            L["EDITOR_MODE"] or "Mode",
            isExpert and (L["EDITOR_MODE_EXPERT"] or "Expert") or (L["EDITOR_MODE_QUICK"] or "Quick")
        ))
        if inspectorSummary.label and inspectorSummary.label.SetFont then
            inspectorSummary.label:SetFont(STANDARD_TEXT_FONT, 12, "")
            inspectorSummary.label:SetTextColor(
                summaryTextColor[1] or 0.66,
                summaryTextColor[2] or 0.70,
                summaryTextColor[3] or 0.75,
                summaryTextColor[4] or 1
            )
            inspectorSummary.label:SetShadowOffset(1, -1)
            inspectorSummary.label:SetShadowColor(0, 0, 0, 0.7)
        end
        summarySection:AddChild(inspectorSummary)

        local inspectorHint = AceGUI:Create("Label")
        inspectorHint:SetFullWidth(true)
        inspectorHint:SetText(L["EDITOR_INSPECTOR_NOTE"] or "Bearbeitet immer nur die aktuell ausgewaehlte Unit.")
        if inspectorHint.label and inspectorHint.label.SetFont then
            inspectorHint.label:SetFont(STANDARD_TEXT_FONT, 10, "")
            inspectorHint.label:SetTextColor(
                hintTextColor[1] or 0.60,
                hintTextColor[2] or 0.64,
                hintTextColor[3] or 0.69,
                hintTextColor[4] or 1
            )
        end
        summarySection:AddChild(inspectorHint)
    end

    local function BuildFrameSectionContent(frameSection)
        if not frameSection then
            return
        end

        AddCheckBox(frameSection, L["EDITOR_OPTION_ENABLED"] or "Enabled", unitConfig.enabled ~= false, function(value)
            local wasEnabled = unitConfig.enabled ~= false
            local isEnabled = value and true or false
            if wasEnabled == isEnabled then
                return
            end
            unitConfig.enabled = isEnabled
            NotifyUnitEnabledChanged()
        end)

        AddSlider(frameSection, L["EDITOR_OPTION_WIDTH"] or "Width", 120, 420, 1, tonumber(unitConfig.width) or 260, function(value)
            SetUnitField("width", math.floor((value or 0) + 0.5))
        end)

        AddSlider(frameSection, L["EDITOR_OPTION_HEIGHT"] or "Height", 24, 120, 1, tonumber(unitConfig.height) or 65, function(value)
            SetUnitField("height", math.floor((value or 0) + 0.5))
        end)

        if selectedUnit == "boss" then
            AddSlider(frameSection, L["OPTION_BOSS_FRAME_SPACING"] or "Boss Frame Spacing", 0, 40, 1, tonumber(unitConfig.bossSpacing) or 10, function(value)
                SetUnitField("bossSpacing", math.floor((value or 0) + 0.5))
            end)
        end

        AddSlider(frameSection, L["EDITOR_OPTION_SCALE"] or "Scale", 0.5, 1.5, 0.01, tonumber(unitConfig.scale) or 1, function(value)
            SetUnitField("scale", tonumber(string.format("%.2f", value or 1)) or 1)
        end)

        AddSlider(frameSection, L["EDITOR_OPTION_ALPHA"] or "Transparency", 0.1, 1.0, 0.01, tonumber(unitConfig.alpha) or 1, function(value)
            SetUnitField("alpha", tonumber(string.format("%.2f", value or 1)) or 1)
        end)

        AddColorPicker(frameSection, L["OPTION_BACKGROUND_COLOR"] or "Background Color", unitConfig.backgroundColor, true, function(value)
            SetUnitField("backgroundColor", value)
        end)

        if isExpert then
            AddColorPicker(frameSection, L["OPTION_BORDER_COLOR"] or "Border Color", unitConfig.borderColor, true, function(value)
                SetUnitField("borderColor", value)
            end)

            AddDropdown(frameSection, L["OPTION_FRAME_STRATA"] or "Frame Strata", frameStrataList, unitConfig.frameStrata or "MEDIUM", function(value)
                SetUnitField("frameStrata", value)
            end)

            AddSlider(frameSection, L["OPTION_FRAME_LEVEL"] or "Frame Level", 0, 50, 1, tonumber(unitConfig.frameLevel) or 1, function(value)
                SetUnitField("frameLevel", math.floor((value or 0) + 0.5))
            end)
        end
    end

    AddSpacer(container, INSPECTOR_SECTION_SPACING)
    CreateInspectorSection("frame", L["EDITOR_SECTION_FRAME"] or "Frame", false, {
        localContentBuilder = BuildFrameSectionContent,
        layoutRefresh = RefreshInspectorLayout,
    })

    local function BuildHealthSectionContent(healthSection)
        if not healthSection then
            return
        end

        AddDropdown(healthSection, L["OPTION_BAR_TEXTURE"] or "Bar Texture", textureList, unitConfig.healthBarTexture, function(value)
            SetUnitField("healthBarTexture", value)
        end)

        AddCheckBox(healthSection, L["OPTION_USE_CLASS_COLORS"] or "Use Class Colors", unitConfig.useClassColorHealth == true, function(value)
            SetUnitField("useClassColorHealth", value and true or false, healthSection)
        end)

        if isExpert then
            AddCheckBox(healthSection, L["OPTION_USE_REACTION_COLORS_NPC_HEALTH"] or "Use NPC Reaction Colors", unitConfig.useReactionColorNpcHealth == true, function(value)
                SetUnitField("useReactionColorNpcHealth", value and true or false, healthSection)
            end)

            AddCheckBox(healthSection, L["OPTION_REVERSE_FILL"] or "Reverse Fill", unitConfig.healthBarReverseFill == true, function(value)
                SetUnitField("healthBarReverseFill", value and true or false)
            end)
        end

        if isQuick or unitConfig.useClassColorHealth ~= true then
            AddColorPicker(healthSection, L["OPTION_COLOR"] or "Color", unitConfig.healthColor, true, function(value)
                SetUnitField("healthColor", value)
            end, unitConfig.useClassColorHealth == true or unitConfig.useReactionColorNpcHealth == true)
        end

        AddColorPicker(healthSection, L["OPTION_LOW_HEALTH_COLOR"] or "Low Health Color", unitConfig.healthLowColor, true, function(value)
            SetUnitField("healthLowColor", value)
        end)

        if isExpert then
            AddCheckBox(healthSection, L["OPTION_SHOW_BACKGROUND"] or "Show Background", unitConfig.healthBackground ~= false, function(value)
                SetUnitField("healthBackground", value and true or false, healthSection)
            end)

            AddColorPicker(healthSection, L["OPTION_BACKGROUND_COLOR"] or "Background Color", unitConfig.healthBackgroundColor, true, function(value)
                SetUnitField("healthBackgroundColor", value)
            end, unitConfig.healthBackground == false)
        end
    end

    AddSpacer(container, INSPECTOR_SECTION_SPACING)
    CreateInspectorSection("health", L["BAR_HEALTH"] or "Health", false, {
        localContentBuilder = BuildHealthSectionContent,
        layoutRefresh = RefreshInspectorLayout,
    })

    local function BuildPowerSectionContent(powerSection)
        if not powerSection then
            return
        end

        AddCheckBox(powerSection, L["EDITOR_OPTION_SHOW_POWER"] or "Show Power Bar", unitConfig.showPowerBar ~= false, function(value)
            SetUnitField("showPowerBar", value and true or false, powerSection)
        end)

        AddDropdown(powerSection, L["OPTION_BAR_TEXTURE"] or "Bar Texture", textureList, unitConfig.powerBarTexture, function(value)
            SetUnitField("powerBarTexture", value)
        end, unitConfig.showPowerBar == false)

        if isExpert then
            AddSlider(powerSection, L["OPTION_POWER_BAR_HEIGHT"] or "Power Bar Height", 4, 30, 1, tonumber(unitConfig.powerBarHeight) or 20, function(value)
                SetUnitField("powerBarHeight", math.floor((value or 0) + 0.5))
            end, unitConfig.showPowerBar == false)
        end

        AddCheckBox(powerSection, L["OPTION_USE_CLASS_COLORS"] or "Use Class Colors", unitConfig.useClassColorPower == true, function(value)
            SetUnitField("useClassColorPower", value and true or false, powerSection)
        end, unitConfig.showPowerBar == false)

        if isExpert then
            AddCheckBox(powerSection, L["OPTION_REVERSE_FILL"] or "Reverse Fill", unitConfig.powerBarReverseFill == true, function(value)
                SetUnitField("powerBarReverseFill", value and true or false)
            end, unitConfig.showPowerBar == false)
        end

        AddColorPicker(powerSection, L["OPTION_COLOR"] or "Color", unitConfig.powerColor, true, function(value)
            SetUnitField("powerColor", value)
        end, unitConfig.showPowerBar == false or unitConfig.useClassColorPower == true)

        if isExpert then
            AddCheckBox(powerSection, L["OPTION_SHOW_BACKGROUND"] or "Show Background", unitConfig.powerBackground ~= false, function(value)
                SetUnitField("powerBackground", value and true or false, powerSection)
            end, unitConfig.showPowerBar == false)

            AddColorPicker(powerSection, L["OPTION_BACKGROUND_COLOR"] or "Background Color", unitConfig.powerBackgroundColor, true, function(value)
                SetUnitField("powerBackgroundColor", value)
            end, unitConfig.showPowerBar == false or unitConfig.powerBackground == false)
        end
    end

    AddSpacer(container, INSPECTOR_SECTION_SPACING)
    CreateInspectorSection("power", L["BAR_POWER"] or "Power", true, {
        localContentBuilder = BuildPowerSectionContent,
        layoutRefresh = RefreshInspectorLayout,
    })

    local function BuildAltPowerSectionContent(altPowerSection)
        if not altPowerSection or selectedUnit ~= "player" then
            return
        end

        AddCheckBox(altPowerSection, L["OPTION_SHOW_ALTERNATIVE_POWER_BAR"] or "Show Alternative Power Bar", unitConfig.showAlternativePowerBar == true, function(value)
            SetUnitField("showAlternativePowerBar", value and true or false, altPowerSection)
        end)

        AddDropdown(altPowerSection, L["OPTION_BAR_TEXTURE"] or "Bar Texture", textureList, unitConfig.alternativePowerBarTexture or unitConfig.powerBarTexture, function(value)
            SetUnitField("alternativePowerBarTexture", value)
        end, unitConfig.showAlternativePowerBar ~= true)

        AddSlider(altPowerSection, L["OPTION_ALTERNATIVE_POWER_BAR_HEIGHT"] or "Alternative Power Height", 4, 30, 1, tonumber(unitConfig.alternativePowerBarHeight) or 20, function(value)
            SetUnitField("alternativePowerBarHeight", math.floor((value or 0) + 0.5))
        end, unitConfig.showAlternativePowerBar ~= true)

        if isExpert then
            local altPowerReverseFillEnabled = unitConfig.alternativePowerBarReverseFill
            if altPowerReverseFillEnabled == nil then
                altPowerReverseFillEnabled = unitConfig.powerBarReverseFill == true
            else
                altPowerReverseFillEnabled = altPowerReverseFillEnabled == true
            end

            AddCheckBox(altPowerSection, L["OPTION_REVERSE_FILL"] or "Reverse Fill", altPowerReverseFillEnabled, function(value)
                SetUnitField("alternativePowerBarReverseFill", value and true or false)
            end, unitConfig.showAlternativePowerBar ~= true)

            AddColorPicker(altPowerSection, L["OPTION_COLOR"] or "Color", unitConfig.alternativePowerColor, true, function(value)
                SetUnitField("alternativePowerColor", value)
            end, unitConfig.showAlternativePowerBar ~= true)

            local altPowerBackgroundEnabled = unitConfig.alternativePowerBackground
            if altPowerBackgroundEnabled == nil then
                altPowerBackgroundEnabled = unitConfig.powerBackground ~= false
            else
                altPowerBackgroundEnabled = altPowerBackgroundEnabled ~= false
            end

            AddCheckBox(altPowerSection, L["OPTION_SHOW_BACKGROUND"] or "Show Background", altPowerBackgroundEnabled, function(value)
                SetUnitField("alternativePowerBackground", value and true or false, altPowerSection)
            end, unitConfig.showAlternativePowerBar ~= true)

            AddColorPicker(altPowerSection, L["OPTION_BACKGROUND_COLOR"] or "Background Color", unitConfig.alternativePowerBackgroundColor or unitConfig.powerBackgroundColor, true, function(value)
                SetUnitField("alternativePowerBackgroundColor", value)
            end, unitConfig.showAlternativePowerBar ~= true or altPowerBackgroundEnabled == false)
        end
    end

    local function BuildClassPowerSectionContent(classPowerSection)
        if not classPowerSection or selectedUnit ~= "player" then
            return
        end

        AddCheckBox(classPowerSection, L["OPTION_SHOW_CLASS_POWER_BAR"] or "Show Class Power Bar", unitConfig.showClassPowerBar == true, function(value)
            SetUnitField("showClassPowerBar", value and true or false, classPowerSection)
        end)

        AddDropdown(classPowerSection, L["OPTION_BAR_TEXTURE"] or "Bar Texture", textureList, unitConfig.classPowerBarTexture or unitConfig.powerBarTexture, function(value)
            SetUnitField("classPowerBarTexture", value)
        end, unitConfig.showClassPowerBar ~= true)

        AddColorPicker(classPowerSection, L["OPTION_COLOR"] or "Color", unitConfig.classPowerColor or unitConfig.powerColor, true, function(value)
            SetUnitField("classPowerColor", value)
        end, unitConfig.showClassPowerBar ~= true)

        AddColorPicker(classPowerSection, L["OPTION_BACKGROUND_COLOR"] or "Background Color", unitConfig.classPowerBackgroundColor or unitConfig.powerBackgroundColor, true, function(value)
            SetUnitField("classPowerBackgroundColor", value)
        end, unitConfig.showClassPowerBar ~= true)

        AddSlider(classPowerSection, L["OPTION_CLASS_POWER_BAR_HEIGHT"] or "Class Power Height", 4, 30, 1, tonumber(unitConfig.classPowerBarHeight) or 12, function(value)
            SetUnitField("classPowerBarHeight", math.floor((value or 0) + 0.5))
        end, unitConfig.showClassPowerBar ~= true)

        if isExpert then
            AddSlider(classPowerSection, L["OPTION_CLASS_POWER_BAR_WIDTH"] or "Class Power Width", 40, 260, 1, tonumber(unitConfig.classPowerBarWidth) or 100, function(value)
                SetUnitField("classPowerBarWidth", math.floor((value or 0) + 0.5))
            end, unitConfig.showClassPowerBar ~= true)

            AddSlider(classPowerSection, L["OPTION_CLASS_POWER_BAR_SPACING"] or "Class Power Spacing", 0, 20, 1, tonumber(unitConfig.classPowerBarSpacing) or 2, function(value)
                SetUnitField("classPowerBarSpacing", math.floor((value or 0) + 0.5))
            end, unitConfig.showClassPowerBar ~= true)

            AddDropdown(classPowerSection, L["OPTION_ANCHOR_TO_TARGET"] or "Anchor To Element", classPowerAnchorTargetList, unitConfig.classPowerBarAnchorTo or "HealthBar", function(value)
                SetUnitField("classPowerBarAnchorTo", value)
            end, unitConfig.showClassPowerBar ~= true)

            AddDropdown(classPowerSection, L["OPTION_ANCHOR_FROM"] or "Anchor From", barAnchorList, unitConfig.classPowerBarPoint or "BOTTOMRIGHT", function(value)
                SetUnitField("classPowerBarPoint", value)
            end, unitConfig.showClassPowerBar ~= true)

            AddDropdown(classPowerSection, L["OPTION_ANCHOR_TO"] or "Anchor To", barAnchorList, unitConfig.classPowerBarRelativePoint or "BOTTOMRIGHT", function(value)
                SetUnitField("classPowerBarRelativePoint", value)
            end, unitConfig.showClassPowerBar ~= true)

            AddSlider(classPowerSection, L["OPTION_X_OFFSET"] or "X Offset", -200, 200, 1, tonumber(unitConfig.classPowerBarOffsetX) or -5, function(value)
                SetUnitField("classPowerBarOffsetX", math.floor((value or 0) + 0.5))
            end, unitConfig.showClassPowerBar ~= true)

            AddSlider(classPowerSection, L["OPTION_Y_OFFSET"] or "Y Offset", -200, 200, 1, tonumber(unitConfig.classPowerBarOffsetY) or 5, function(value)
                SetUnitField("classPowerBarOffsetY", math.floor((value or 0) + 0.5))
            end, unitConfig.showClassPowerBar ~= true)
        end
    end

    if selectedUnit == "player" then
        AddSpacer(container, INSPECTOR_SECTION_SPACING)
        CreateInspectorSection("alt_power", L["BAR_ALT_POWER"] or "Alt Power", true, {
            localContentBuilder = BuildAltPowerSectionContent,
            layoutRefresh = RefreshInspectorLayout,
        })

        AddSpacer(container, INSPECTOR_SECTION_SPACING)
        CreateInspectorSection("class_power", L["BAR_CLASS_POWER"] or "Class Power", true, {
            localContentBuilder = BuildClassPowerSectionContent,
            layoutRefresh = RefreshInspectorLayout,
        })
    end

    local function BuildCastSectionContent(castSection)
        if not castSection then
            return
        end

        AddCheckBox(castSection, L["OPTION_SHOW_CAST_BAR"] or "Show Cast Bar", unitConfig.showCastBar ~= false, function(value)
            SetUnitField("showCastBar", value and true or false, castSection)
        end)

        AddCheckBox(castSection, L["OPTION_SHOW_CAST_BAR_ICON"] or "Show Cast Bar Icon", unitConfig.showCastBarIcon ~= false, function(value)
            SetUnitField("showCastBarIcon", value and true or false)
        end, unitConfig.showCastBar == false)

        AddColorPicker(castSection, L["OPTION_CAST_BAR_COLOR"] or "Cast Bar Color", unitConfig.castBarColor, true, function(value)
            SetUnitField("castBarColor", value)
        end, unitConfig.showCastBar == false)

        if isExpert then
            AddDropdown(castSection, L["OPTION_BAR_TEXTURE"] or "Bar Texture", textureList, unitConfig.castBarTexture, function(value)
                SetUnitField("castBarTexture", value)
            end, unitConfig.showCastBar == false)

            AddSlider(castSection, L["OPTION_CAST_BAR_HEIGHT"] or "Cast Bar Height", 4, 30, 1, tonumber(unitConfig.castBarHeight) or 20, function(value)
                SetUnitField("castBarHeight", math.floor((value or 0) + 0.5))
            end, unitConfig.showCastBar == false)
        end
    end

    AddSpacer(container, INSPECTOR_SECTION_SPACING)
    CreateInspectorSection("cast", L["BAR_CAST"] or "Cast Bar", true, {
        localContentBuilder = BuildCastSectionContent,
        layoutRefresh = RefreshInspectorLayout,
    })

    local function BuildVisibilitySectionContent(visibilitySection)
        if not visibilitySection then
            return
        end

        AddCheckBox(visibilitySection, L["OPTION_SHOW_IN_SOLO"] or "Show in Solo", unitConfig.showInSolo ~= false, function(value)
            SetUnitField("showInSolo", value and true or false)
        end)

        AddCheckBox(visibilitySection, L["OPTION_SHOW_IN_PARTY"] or "Show in Party", unitConfig.showInParty ~= false, function(value)
            SetUnitField("showInParty", value and true or false)
        end)

        AddCheckBox(visibilitySection, L["OPTION_SHOW_IN_RAID"] or "Show in Raid", unitConfig.showInRaid ~= false, function(value)
            SetUnitField("showInRaid", value and true or false)
        end)

        AddCheckBox(visibilitySection, L["OPTION_SHOW_IN_ARENA"] or "Show in Arena", unitConfig.showInArena ~= false, function(value)
            SetUnitField("showInArena", value and true or false)
        end)

        AddCheckBox(visibilitySection, L["OPTION_SHOW_IN_PVP"] or "Show in PvP", unitConfig.showInPvp ~= false, function(value)
            SetUnitField("showInPvp", value and true or false)
        end)

        if isExpert then
            AddCheckBox(visibilitySection, L["OPTION_MOUSE_ENABLED"] or "Mouse Enabled", unitConfig.mouseEnabled ~= false, function(value)
                SetUnitField("mouseEnabled", value and true or false, visibilitySection)
            end)

            AddCheckBox(visibilitySection, L["OPTION_CLICK_THROUGH"] or "Click Through", unitConfig.clickThrough == true, function(value)
                SetUnitField("clickThrough", value and true or false)
            end, unitConfig.mouseEnabled == false)
        end
    end

    AddSpacer(container, INSPECTOR_SECTION_SPACING)
    CreateInspectorSection("visibility", L["EDITOR_SECTION_VISIBILITY"] or "Visibility", true, {
        localContentBuilder = BuildVisibilitySectionContent,
        layoutRefresh = RefreshInspectorLayout,
    })

    local function BuildPositioningSectionContent(positioning)
        if not positioning or not isExpert then
            return
        end

        AddDropdown(positioning, L["EDITOR_OPTION_POINT"] or "Anchor From", POINTS, unitConfig.point or "CENTER", function(value)
            SetUnitField("point", value)
        end)

        AddDropdown(positioning, L["EDITOR_OPTION_RELATIVE_POINT"] or "Anchor To", POINTS, unitConfig.relativePoint or "CENTER", function(value)
            SetUnitField("relativePoint", value)
        end)

        AddSlider(positioning, L["EDITOR_OPTION_X"] or "X Offset", -800, 800, 1, tonumber(unitConfig.x) or 0, function(value)
            SetUnitField("x", math.floor((value or 0) + 0.5))
        end)

        AddSlider(positioning, L["EDITOR_OPTION_Y"] or "Y Offset", -800, 800, 1, tonumber(unitConfig.y) or 0, function(value)
            SetUnitField("y", math.floor((value or 0) + 0.5))
        end)
    end

    local function BuildCastPositionSectionContent(castPosition)
        if not castPosition or not isExpert then
            return
        end

        AddDropdown(castPosition, L["OPTION_ANCHOR_FROM"] or "Anchor From", barAnchorList, unitConfig.castBarPoint or "BOTTOMLEFT", function(value)
            SetUnitField("castBarPoint", value)
        end)

        AddDropdown(castPosition, L["OPTION_ANCHOR_TO"] or "Anchor To", barAnchorList, unitConfig.castBarRelativePoint or "TOPLEFT", function(value)
            SetUnitField("castBarRelativePoint", value)
        end)

        AddSlider(castPosition, L["OPTION_X_OFFSET"] or "X Offset", -500, 500, 1, tonumber(unitConfig.castBarOffsetX) or 0, function(value)
            SetUnitField("castBarOffsetX", math.floor((value or 0) + 0.5))
        end)

        AddSlider(castPosition, L["OPTION_Y_OFFSET"] or "Y Offset", -500, 500, 1, tonumber(unitConfig.castBarOffsetY) or 4, function(value)
            SetUnitField("castBarOffsetY", math.floor((value or 0) + 0.5))
        end)
    end

    if isExpert then
        AddSpacer(container, INSPECTOR_SECTION_SPACING)
        CreateInspectorSection("positioning", L["EDITOR_POSITIONING"] or "Positioning", true, {
            localContentBuilder = BuildPositioningSectionContent,
            layoutRefresh = RefreshInspectorLayout,
        })

        AddSpacer(container, INSPECTOR_SECTION_SPACING)
        CreateInspectorSection("cast_position", L["EDITOR_SECTION_CAST_POSITION"] or "Cast Bar Position", true, {
            localContentBuilder = BuildCastPositionSectionContent,
            layoutRefresh = RefreshInspectorLayout,
        })
    end

    local function BuildTextSectionContent(textSection)
        local selectedTextId, textConfig, linkedTemplateName, _, currentTextList = ResolveTextContext()
        if not textSection or not textConfig then
            return
        end

            AddDropdown(textSection, L["EDITOR_OPTION_TEXT_ELEMENT"] or "Text Element", currentTextList, selectedTextId, function(value)
                local result = type(InspectorTextSelection.Set) == "function"
                    and InspectorTextSelection.Set(state, value, currentTextList)
                    or nil
                if result and result.ok and result.changed then
                    RebuildLocalSection(textSection)
                end
            end, nil, "text_element")

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

            local missingTemplateMessages = BuildMissingTemplateMessages(selectedTextId)
            if #missingTemplateMessages > 0 then
                local missingTemplateWarning = AceGUI:Create("Label")
                missingTemplateWarning:SetFullWidth(true)
                missingTemplateWarning:SetText(table.concat(missingTemplateMessages, "\n"))
                if missingTemplateWarning.label and missingTemplateWarning.label.SetFont then
                    missingTemplateWarning.label:SetFont(STANDARD_TEXT_FONT, 10, "")
                    missingTemplateWarning.label:SetTextColor(1.00, 0.72, 0.28, 1)
                end
                textSection:AddChild(missingTemplateWarning)
            end

            AddCheckBox(textSection, L["OPTION_ENABLED"] or "Enabled", textConfig.enabled ~= false, function(value)
                SetTextField(selectedTextId, "enabled", value and true or false, textSection)
            end, nil, "text_enabled")

        if isQuick then
            AddSlider(textSection, L["OPTION_FONT_SIZE"] or "Font Size", 6, 32, 1, tonumber(textConfig.fontSize) or 12, function(value)
                SetTextField(selectedTextId, "fontSize", math.floor((value or 0) + 0.5))
            end, textConfig.enabled == false, "text_font_size")

            AddColorPicker(textSection, L["OPTION_COLOR"] or "Color", textConfig.color, true, function(value)
                SetTextField(selectedTextId, "color", value)
            end, textConfig.enabled == false, "text_color")
        else
            AddDropdown(textSection, L["OPTION_FONT"] or "Font", fontList, textConfig.font or STANDARD_TEXT_FONT, function(value)
                SetTextField(selectedTextId, "font", value)
            end, textConfig.enabled == false, "text_font")

            AddDropdown(textSection, L["OPTION_FONT_STYLE"] or "Font Style", fontStyleList, textConfig.fontStyle or "NONE", function(value)
                SetTextField(selectedTextId, "fontStyle", value)
            end, textConfig.enabled == false, "text_font_style")

            AddSlider(textSection, L["OPTION_FONT_SIZE"] or "Font Size", 6, 32, 1, tonumber(textConfig.fontSize) or 12, function(value)
                SetTextField(selectedTextId, "fontSize", math.floor((value or 0) + 0.5))
            end, textConfig.enabled == false, "text_font_size")

            AddDropdown(textSection, L["OPTION_JUSTIFY_H"] or "Justify", justifyList, textConfig.justifyH or "CENTER", function(value)
                SetTextField(selectedTextId, "justifyH", value)
            end, textConfig.enabled == false, "text_justify")

            AddDropdown(textSection, L["OPTION_ANCHOR_TO_TARGET"] or "Anchor To Element", textAnchorTargetList, textConfig.anchorTo or "Frame", function(value)
                SetTextField(selectedTextId, "anchorTo", value)
            end, textConfig.enabled == false, "text_anchor_to")

            AddDropdown(textSection, L["OPTION_ANCHOR_FROM"] or "Anchor From", textAnchorPointList, textConfig.point or "CENTER", function(value)
                SetTextField(selectedTextId, "point", value)
            end, textConfig.enabled == false, "text_point")

            AddDropdown(textSection, L["OPTION_ANCHOR_TO"] or "Anchor To", textAnchorPointList, textConfig.relativePoint or "CENTER", function(value)
                SetTextField(selectedTextId, "relativePoint", value)
            end, textConfig.enabled == false, "text_relative_point")

            AddSlider(textSection, L["OPTION_X_OFFSET"] or "X Offset", -100, 100, 1, tonumber(textConfig.offsetX) or 0, function(value)
                SetTextField(selectedTextId, "offsetX", math.floor((value or 0) + 0.5))
            end, textConfig.enabled == false, "text_offset_x")

            AddSlider(textSection, L["OPTION_Y_OFFSET"] or "Y Offset", -100, 100, 1, tonumber(textConfig.offsetY) or 0, function(value)
                SetTextField(selectedTextId, "offsetY", math.floor((value or 0) + 0.5))
            end, textConfig.enabled == false, "text_offset_y")

            AddDropdown(textSection, L["OPTION_TEXT_OVERFLOW"] or "Text Overflow", overflowList, textConfig.overflowMode or "NONE", function(value)
                SetTextField(selectedTextId, "overflowMode", value)
            end, textConfig.enabled == false, "text_overflow")

            AddCheckBox(textSection, L["OPTION_FONT_SHADOW"] or "Shadow", textConfig.shadowEnabled ~= false, function(value)
                SetTextField(selectedTextId, "shadowEnabled", value and true or false)
            end, textConfig.enabled == false, "text_shadow")

            AddColorPicker(textSection, L["OPTION_SHADOW_COLOR"] or "Shadow Color", textConfig.shadowColor, true, function(value)
                SetTextField(selectedTextId, "shadowColor", value)
            end, textConfig.enabled == false or textConfig.shadowEnabled == false, "text_shadow_color")
        end
    end

    if select(2, ResolveTextContext()) then
        AddSpacer(container, INSPECTOR_SECTION_SPACING)

        CreateInspectorSection("texts", L["EDITOR_SECTION_TEXT_ELEMENTS"] or "Text Elements", true, {
            localContentBuilder = BuildTextSectionContent,
            layoutRefresh = RefreshInspectorLayout,
        })
    end

    local function BuildIndicatorSectionContent(indicatorSection)
        local selectedIndicatorKey, indicatorMeta, indicatorConfig, _, currentIndicatorList = ResolveIndicatorContext()
        if not indicatorSection or type(indicatorConfig) ~= "table" or type(indicatorMeta) ~= "table" then
            return
        end

        AddDropdown(indicatorSection, L["EDITOR_OPTION_INDICATOR"] or "Indicator", currentIndicatorList, selectedIndicatorKey, function(value)
            local result = type(InspectorIndicatorSelection.Set) == "function"
                and InspectorIndicatorSelection.Set(state, value, currentIndicatorList)
                or nil
            if result and result.ok and result.changed then
                RebuildLocalSection(indicatorSection)
            end
        end)

        AddCheckBox(indicatorSection, L[indicatorMeta.labelKey] or "Enabled", indicatorConfig.enabled ~= false, function(value)
            SetIndicatorField(selectedIndicatorKey, "enabled", value and true or false, indicatorSection)
        end)

        if indicatorMeta.classification then
            AddDropdown(indicatorSection, L[indicatorMeta.effectLabel] or "Effect", classificationEffectList, indicatorConfig.effect or "PORTRAIT_OVERLAY", function(value)
                SetIndicatorField(selectedIndicatorKey, "effect", value)
            end, indicatorConfig.enabled == false)
            return
        end

        local effect = indicatorConfig.effect or "ICON"
        if indicatorMeta.effectListKey == "status" then
            AddDropdown(indicatorSection, L[indicatorMeta.effectLabel] or "Effect", statusIndicatorEffectList, effect, function(value)
                SetIndicatorField(selectedIndicatorKey, "effect", value, nil, function()
                    NotifyConfigChangedAndRebuildSection(indicatorSection, "indicators")
                end)
            end, indicatorConfig.enabled == false)
        end

        local useOverlayEffect = indicatorMeta.effectListKey == "status" and effect == "FRAME_OVERLAY"
        if useOverlayEffect then
            return
        end

        AddDropdown(indicatorSection, L[indicatorMeta.placementLabel] or "Placement", portraitPlacementList, indicatorConfig.placement or "ATTACHED", function(value)
            SetIndicatorField(selectedIndicatorKey, "placement", value, indicatorSection)
        end, indicatorConfig.enabled == false)

        if isExpert and indicatorMeta.supportsMode then
            AddDropdown(indicatorSection, L[indicatorMeta.modeLabel] or "Mode", portraitModeList, indicatorConfig.mode or "2D", function(value)
                SetIndicatorField(selectedIndicatorKey, "mode", value)
            end, indicatorConfig.enabled == false)
        end

        AddSlider(indicatorSection, L[indicatorMeta.sizeLabel] or "Size", 8, 128, 1, tonumber(indicatorConfig.size) or 16, function(value)
            SetIndicatorField(selectedIndicatorKey, "size", math.floor((value or 0) + 0.5))
        end, indicatorConfig.enabled == false)

        if not isExpert then
            return
        end

        AddSlider(indicatorSection, L[indicatorMeta.scaleLabel] or "Scale", 0.25, 3.0, 0.01, tonumber(indicatorConfig.scale) or 1, function(value)
            SetIndicatorField(selectedIndicatorKey, "scale", tonumber(string.format("%.2f", value or 1)) or 1)
        end, indicatorConfig.enabled == false)

        local placement = indicatorConfig.placement or "ATTACHED"
        local inside = placement == "INSIDE"

        if inside then
            AddDropdown(indicatorSection, L["OPTION_ANCHOR_TO_TARGET"] or "Anchor To Element", portraitAnchorTargetList, indicatorConfig.insideAnchorTo or "Frame", function(value)
                SetIndicatorField(selectedIndicatorKey, "insideAnchorTo", value)
            end, indicatorConfig.enabled == false)

            AddDropdown(indicatorSection, L[indicatorMeta.insideSideLabel] or (L["OPTION_INSIDE_SIDE"] or "Inside Side"), portraitInsideSideList, indicatorConfig.insideSide or "LEFT", function(value)
                SetIndicatorField(selectedIndicatorKey, "insideSide", value)
            end, indicatorConfig.enabled == false)

            AddSlider(indicatorSection, L["OPTION_PADDING"] or "Padding", 0, 64, 1, tonumber(indicatorConfig.padding) or 2, function(value)
                SetIndicatorField(selectedIndicatorKey, "padding", math.floor((value or 0) + 0.5))
            end, indicatorConfig.enabled == false)
            return
        end

        AddDropdown(indicatorSection, L["OPTION_ANCHOR_TO_TARGET"] or "Anchor To Element", portraitAnchorTargetList, indicatorConfig.anchorTo or "Frame", function(value)
            SetIndicatorField(selectedIndicatorKey, "anchorTo", value)
        end, indicatorConfig.enabled == false)

        AddDropdown(indicatorSection, L["OPTION_ANCHOR_FROM"] or "Anchor From", portraitAnchorPointList, indicatorConfig.point or "TOP", function(value)
            SetIndicatorField(selectedIndicatorKey, "point", value)
        end, indicatorConfig.enabled == false)

        AddDropdown(indicatorSection, L["OPTION_ANCHOR_TO"] or "Anchor To", portraitAnchorPointList, indicatorConfig.relativePoint or "TOP", function(value)
            SetIndicatorField(selectedIndicatorKey, "relativePoint", value)
        end, indicatorConfig.enabled == false)

        AddSlider(indicatorSection, L["OPTION_X_OFFSET"] or "X Offset", -500, 500, 1, tonumber(indicatorConfig.offsetX) or 0, function(value)
            SetIndicatorField(selectedIndicatorKey, "offsetX", math.floor((value or 0) + 0.5))
        end, indicatorConfig.enabled == false)

        AddSlider(indicatorSection, L["OPTION_Y_OFFSET"] or "Y Offset", -500, 500, 1, tonumber(indicatorConfig.offsetY) or 0, function(value)
            SetIndicatorField(selectedIndicatorKey, "offsetY", math.floor((value or 0) + 0.5))
        end, indicatorConfig.enabled == false)
    end

    do
        local _, indicatorMeta, indicatorConfig = ResolveIndicatorContext()
        if indicatorConfig and indicatorMeta then
            AddSpacer(container, INSPECTOR_SECTION_SPACING)

            CreateInspectorSection("indicators", L["EDITOR_SECTION_INDICATORS"] or "Indicators", true, {
                localContentBuilder = BuildIndicatorSectionContent,
                layoutRefresh = RefreshInspectorLayout,
            })
        end
    end

    local function BuildAuraSectionContent(auraSection)
        local selectedAuraKey, auraConfig, _, currentAuraList = ResolveAuraContext()
        if not auraSection or type(auraConfig) ~= "table" then
            return
        end

        AddDropdown(auraSection, L["EDITOR_OPTION_AURA_BLOCK"] or "Aura Block", currentAuraList, selectedAuraKey, function(value)
            local result = type(InspectorAuraSelection.Set) == "function"
                and InspectorAuraSelection.Set(state, value, currentAuraList)
                or nil
            if result and result.ok and result.changed then
                RebuildLocalSection(auraSection)
            end
        end, nil, "aura_block")

        AddCheckBox(auraSection, L["OPTION_AURA_ENABLED"] or "Enable Aura Block", auraConfig.enabled ~= false, function(value)
            SetAuraField(selectedAuraKey, "enabled", value and true or false, auraSection)
        end, nil, "aura_enabled")

        AddDropdown(auraSection, L["OPTION_AURA_PLACEMENT"] or "Aura Block Placement", auraPlacementList, auraConfig.placement or "ATTACHED", function(value)
            SetAuraField(selectedAuraKey, "placement", value, auraSection)
        end, auraConfig.enabled == false, "aura_placement")

        AddSlider(auraSection, L["OPTION_AURA_ICON_SIZE"] or "Icon Size", 12, 64, 1, tonumber(auraConfig.iconSize) or 30, function(value)
            SetAuraField(selectedAuraKey, "iconSize", math.floor((value or 0) + 0.5))
        end, auraConfig.enabled == false, "aura_icon_size")

        AddSlider(auraSection, L["OPTION_AURA_ICONS_PER_ROW"] or "Icons Per Row", 1, 20, 1, tonumber(auraConfig.iconsPerRow) or 5, function(value)
            SetAuraField(selectedAuraKey, "iconsPerRow", math.floor((value or 0) + 0.5))
        end, auraConfig.enabled == false, "aura_icons_per_row")

        AddSlider(auraSection, L["OPTION_AURA_MAX_ROWS"] or "Maximum Rows", 0, 10, 1, tonumber(auraConfig.maxRows) or 0, function(value)
            SetAuraField(selectedAuraKey, "maxRows", math.floor((value or 0) + 0.5))
        end, auraConfig.enabled == false, "aura_max_rows")

        if isQuick then
            AddCheckBox(auraSection, L["OPTION_AURA_SHOW_STACKS"] or "Show Stacks", auraConfig.showStackText ~= false, function(value)
                SetAuraField(selectedAuraKey, "showStackText", value and true or false)
            end, auraConfig.enabled == false, "aura_show_stacks")

            AddCheckBox(auraSection, L["OPTION_AURA_SHOW_TIMER"] or "Show Timer", auraConfig.showTimerText ~= false, function(value)
                SetAuraField(selectedAuraKey, "showTimerText", value and true or false)
            end, auraConfig.enabled == false, "aura_show_timer")
        else
            AddSlider(auraSection, L["OPTION_AURA_SPACING_X"] or "Spacing X", 0, 20, 1, tonumber(auraConfig.spacingX) or 3, function(value)
                SetAuraField(selectedAuraKey, "spacingX", math.floor((value or 0) + 0.5))
            end, auraConfig.enabled == false, "aura_spacing_x")

            AddSlider(auraSection, L["OPTION_AURA_SPACING_Y"] or "Spacing Y", 0, 20, 1, tonumber(auraConfig.spacingY) or 3, function(value)
                SetAuraField(selectedAuraKey, "spacingY", math.floor((value or 0) + 0.5))
            end, auraConfig.enabled == false, "aura_spacing_y")

            AddDropdown(auraSection, L["OPTION_AURA_GROWTH_X"] or "Growth X", auraGrowthXList, auraConfig.growthX or "RIGHT", function(value)
                SetAuraField(selectedAuraKey, "growthX", value)
            end, auraConfig.enabled == false, "aura_growth_x")

            AddDropdown(auraSection, L["OPTION_AURA_GROWTH_Y"] or "Growth Y", auraGrowthYList, auraConfig.growthY or "DOWN", function(value)
                SetAuraField(selectedAuraKey, "growthY", value)
            end, auraConfig.enabled == false, "aura_growth_y")

            AddDropdown(auraSection, L["OPTION_AURA_SORT_MODE"] or "Sort Mode", auraSortModeList, auraConfig.sortMode or "NEWEST_FIRST", function(value)
                SetAuraField(selectedAuraKey, "sortMode", value)
            end, auraConfig.enabled == false, "aura_sort_mode")

            AddSlider(auraSection, L["OPTION_AURA_STACK_FONT_SCALE"] or "Stack Font Scale", 0.5, 2.0, 0.05, tonumber(auraConfig.stackFontScale) or 1, function(value)
                SetAuraField(selectedAuraKey, "stackFontScale", tonumber(string.format("%.2f", value or 1)) or 1)
            end, auraConfig.enabled == false, "aura_stack_font_scale")

            AddSlider(auraSection, L["OPTION_AURA_TIMER_FONT_SCALE"] or "Timer Font Scale", 0.5, 2.0, 0.05, tonumber(auraConfig.timerFontScale) or 1, function(value)
                SetAuraField(selectedAuraKey, "timerFontScale", tonumber(string.format("%.2f", value or 1)) or 1)
            end, auraConfig.enabled == false, "aura_timer_font_scale")

            AddCheckBox(auraSection, L["OPTION_AURA_SHOW_ONLY_MINE"] or "Only My Auras", auraConfig.showOnlyMine == true, function(value)
                SetAuraField(selectedAuraKey, "showOnlyMine", value and true or false)
            end, auraConfig.enabled == false, "aura_show_only_mine")

            AddCheckBox(auraSection, L["OPTION_AURA_SHOW_BOSS"] or "Force Boss Auras", auraConfig.showBossAuras ~= false, function(value)
                SetAuraField(selectedAuraKey, "showBossAuras", value and true or false)
            end, auraConfig.enabled == false, "aura_show_boss")

            AddCheckBox(auraSection, L["OPTION_AURA_HIDE_PERMANENT"] or "Hide Permanent Auras", auraConfig.hidePermanentAuras == true, function(value)
                SetAuraField(selectedAuraKey, "hidePermanentAuras", value and true or false)
            end, auraConfig.enabled == false, "aura_hide_permanent")

            AddCheckBox(auraSection, L["OPTION_AURA_HIDE_LONG"] or "Hide Long Auras", auraConfig.hideLongAuras == true, function(value)
                SetAuraField(selectedAuraKey, "hideLongAuras", value and true or false, auraSection)
            end, auraConfig.enabled == false, "aura_hide_long")

            AddSlider(auraSection, L["OPTION_AURA_LONG_THRESHOLD"] or "Hide Above Duration", 0, 3600, 5, tonumber(auraConfig.longAuraThreshold) or 300, function(value)
                SetAuraField(selectedAuraKey, "longAuraThreshold", math.floor((value or 0) + 0.5))
            end, auraConfig.enabled == false or auraConfig.hideLongAuras ~= true, "aura_long_threshold")

            if selectedAuraKey == "Buffs" then
                AddCheckBox(auraSection, L["OPTION_AURA_SHOW_STEALABLE_ONLY"] or "Only Stealable Buffs", auraConfig.showStealableOnly == true, function(value)
                    SetAuraField(selectedAuraKey, "showStealableOnly", value and true or false)
                end, auraConfig.enabled == false, "aura_show_stealable_only")
            else
                AddCheckBox(auraSection, L["OPTION_AURA_SHOW_DISPELLABLE_ONLY"] or "Only Dispellable Debuffs", auraConfig.showDispellableOnly == true, function(value)
                    SetAuraField(selectedAuraKey, "showDispellableOnly", value and true or false)
                end, auraConfig.enabled == false, "aura_show_dispellable_only")
            end

            AddCheckBox(auraSection, L["OPTION_AURA_SHOW_STACKS"] or "Show Stacks", auraConfig.showStackText ~= false, function(value)
                SetAuraField(selectedAuraKey, "showStackText", value and true or false)
            end, auraConfig.enabled == false, "aura_show_stacks")

            AddCheckBox(auraSection, L["OPTION_AURA_SHOW_TIMER"] or "Show Timer", auraConfig.showTimerText ~= false, function(value)
                SetAuraField(selectedAuraKey, "showTimerText", value and true or false)
            end, auraConfig.enabled == false, "aura_show_timer")

            local inside = (auraConfig.placement or "ATTACHED") == "INSIDE"
            if inside then
                AddDropdown(auraSection, L["OPTION_ANCHOR_TO_TARGET"] or "Anchor To Element", auraAnchorTargetList, auraConfig.insideAnchorTo or "Frame", function(value)
                    SetAuraField(selectedAuraKey, "insideAnchorTo", value)
                end, auraConfig.enabled == false, "aura_inside_anchor_to")

                AddDropdown(auraSection, L["OPTION_INSIDE_SIDE"] or "Inside Side", auraInsideSideList, auraConfig.insideSide or "LEFT", function(value)
                    SetAuraField(selectedAuraKey, "insideSide", value)
                end, auraConfig.enabled == false, "aura_inside_side")
            else
                AddDropdown(auraSection, L["OPTION_ANCHOR_TO_TARGET"] or "Anchor To Element", auraAnchorTargetList, auraConfig.anchorTo or "Frame", function(value)
                    SetAuraField(selectedAuraKey, "anchorTo", value)
                end, auraConfig.enabled == false, "aura_anchor_to")

                AddDropdown(auraSection, L["OPTION_ANCHOR_FROM"] or "Anchor From", auraAnchorPointList, auraConfig.point or "BOTTOMLEFT", function(value)
                    SetAuraField(selectedAuraKey, "point", value)
                end, auraConfig.enabled == false, "aura_point")

                AddDropdown(auraSection, L["OPTION_ANCHOR_TO"] or "Anchor To", auraAnchorPointList, auraConfig.relativePoint or "TOPLEFT", function(value)
                    SetAuraField(selectedAuraKey, "relativePoint", value)
                end, auraConfig.enabled == false, "aura_relative_point")

                AddSlider(auraSection, L["OPTION_X_OFFSET"] or "X Offset", -500, 500, 1, tonumber(auraConfig.offsetX) or 0, function(value)
                    SetAuraField(selectedAuraKey, "offsetX", math.floor((value or 0) + 0.5))
                end, auraConfig.enabled == false, "aura_offset_x")

                AddSlider(auraSection, L["OPTION_Y_OFFSET"] or "Y Offset", -500, 500, 1, tonumber(auraConfig.offsetY) or 4, function(value)
                    SetAuraField(selectedAuraKey, "offsetY", math.floor((value or 0) + 0.5))
                end, auraConfig.enabled == false, "aura_offset_y")
            end
        end
    end

    if type(select(2, ResolveAuraContext())) == "table" then
        AddSpacer(container, INSPECTOR_SECTION_SPACING)

        CreateInspectorSection("auras", L["EDITOR_SECTION_AURAS"] or "Auras", true, {
            localContentBuilder = BuildAuraSectionContent,
            layoutRefresh = RefreshInspectorLayout,
        })
    end

end

return InspectorController

