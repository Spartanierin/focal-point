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
local MediaOptionAdapter = ns.GUI.Editor.Inspector and ns.GUI.Editor.Inspector.MediaOptionAdapter or {}
local EditorStateApi = ns.GUI.Editor and ns.GUI.Editor.State or {}
local ObjectSelection = ns.GUI.Editor and ns.GUI.Editor.ObjectSelection or {}

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
local activeTextFontSizeControl
local MEDIA_TYPE_FONT = "font"
local MEDIA_TYPE_STATUSBAR = "statusbar"
local MEDIA_TYPE_DECORATION = "decoration"
local DEFAULT_FONT_REFERENCE = "fp:font:standard"
local DEFAULT_STATUSBAR_REFERENCE = "fp:statusbar:blizzard-default"
local DEFAULT_DECORATION_REFERENCE = "fp:decoration:shadow1"
local deleteTextInstanceDialog
local deleteDecorationDialog

local function NormalizeInspectorUnitKey(unitKey)
    if type(unitKey) ~= "string" or unitKey == "" then
        return nil
    end
    if unitKey:match("^boss%d+$") then
        return "boss"
    end
    return unitKey
end

local function NormalizeInspectorTextFontSize(value)
    value = tonumber(value) or 12
    if value < 6 then
        value = 6
    elseif value > 32 then
        value = 32
    end
    return math.floor(value + 0.5)
end

local function RegisterActiveTextFontSizeControl(unitKey, textKey, widget)
    activeTextFontSizeControl = {
        unitKey = NormalizeInspectorUnitKey(unitKey),
        textKey = textKey,
        widget = widget,
        suppress = false,
    }
end

function InspectorController.SetActiveTextFontSizeValue(unitKey, textKey, value)
    local control = activeTextFontSizeControl
    if type(control) ~= "table"
        or control.unitKey ~= NormalizeInspectorUnitKey(unitKey)
        or control.textKey ~= textKey
        or not (control.widget and control.widget.SetValue)
    then
        return false
    end

    control.suppress = true
    local ok = pcall(function()
        control.widget:SetValue(NormalizeInspectorTextFontSize(value))
    end)
    control.suppress = false
    return ok == true
end

function InspectorController.Build(container, state, options)
    options = options or {}
    local buildContextOnly = options.buildContextOnly == true
    local buildPropertiesOnly = options.buildPropertiesOnly == true

    activeTextFontSizeControl = nil
    container:ReleaseChildren()
    container:SetLayout("Flow")

    local barLayouts = ns.GUI and ns.GUI.Layouts and ns.GUI.Layouts.UnitBars or {}
    local frameLayouts = ns.GUI and ns.GUI.Layouts and ns.GUI.Layouts.UnitFrame or {}
    local textLayouts = ns.GUI and ns.GUI.Layouts and ns.GUI.Layouts.UnitTexts or {}
    local portraitLayouts = ns.GUI and ns.GUI.Layouts and ns.GUI.Layouts.UnitPortrait or {}
    local classificationLayouts = ns.GUI and ns.GUI.Layouts and ns.GUI.Layouts.UnitClassificationIndicator or {}
    local statusIndicatorLayouts = ns.GUI and ns.GUI.Layouts and ns.GUI.Layouts.UnitStatusIndicator or {}
    local auraLayouts = ns.GUI and ns.GUI.Layouts and ns.GUI.Layouts.UnitAuras or {}

    local barAnchorList = BuildLocalizedList(barLayouts.Lists and barLayouts.Lists.anchorPoints)
    local textAnchorTargetList = BuildLocalizedList(textLayouts.Lists and textLayouts.Lists.anchorTo)
    local textAnchorPointList = BuildLocalizedList(textLayouts.Lists and textLayouts.Lists.anchorPoints)
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
    local decorationTargetList = {
        FRAME = L["EDITOR_SECTION_FRAME"] or "Frame",
        PORTRAIT = L["EDITOR_SECTION_PORTRAIT"] or "Portrait",
    }
    local decorationConditionList = {
        ALWAYS = L["OPTION_ALWAYS"] or "Always",
        ELITE = L["CLASSIFICATION_ELITE"] or "Elite",
        RARE = L["CLASSIFICATION_RARE"] or "Rare",
        RAREELITE = L["CLASSIFICATION_RAREELITE"] or "Rare-Elite",
        BOSS = L["CLASSIFICATION_BOSS"] or "Boss",
    }
    local absorbAnchorTargetList = {
        Frame = textAnchorTargetList.Frame or (L["EDITOR_SECTION_FRAME"] or "Frame"),
        HealthBar = textAnchorTargetList.HealthBar or (L["BAR_HEALTH"] or "Health"),
        PowerBar = textAnchorTargetList.PowerBar or (L["BAR_POWER"] or "Power"),
    }
    local absorbSizeModeList = {
        MATCH_TARGET = L["OPTION_MATCH_TARGET"] or "Match Target",
        CUSTOM = L["OPTION_CUSTOM"] or "Custom",
    }
    local absorbGrowthList = {
        LEFT_TO_RIGHT = L["OPTION_LEFT_TO_RIGHT"] or "Left to Right",
        RIGHT_TO_LEFT = L["OPTION_RIGHT_TO_LEFT"] or "Right to Left",
    }

    local function BuildDecorationTextureOptions(currentValue)
        if MediaOptionAdapter and MediaOptionAdapter.BuildDecorationDropdown then
            return MediaOptionAdapter.BuildDecorationDropdown(currentValue)
        end

        return {
            values = {},
            order = {},
            value = currentValue,
        }
    end

    local function GetDecorationList(currentInspectorContext, currentUnitConfig)
        if type(InspectorMutations.GetDecorationList) == "function" then
            return InspectorMutations.GetDecorationList(currentInspectorContext) or {}
        end
        return type(currentUnitConfig) == "table" and type(currentUnitConfig.decorations) == "table" and currentUnitConfig.decorations or {}
    end

    local function BuildDecorationLabel(decoration, index)
        local condition = type(decoration) == "table" and decoration.condition or nil
        local target = type(decoration) == "table" and decoration.target or nil
        local conditionLabel = decorationConditionList[condition or "ALWAYS"] or condition or (L["OPTION_ALWAYS"] or "Always")
        local targetLabel = decorationTargetList[target or "FRAME"] or target or (L["EDITOR_SECTION_FRAME"] or "Frame")
        return string.format("%s %d - %s - %s", L["EDITOR_SECTION_DECORATION"] or "Decoration", index or 1, conditionLabel, targetLabel)
    end

    local function ResolveSelectedDecoration(currentInspectorContext, currentUnitConfig)
        local decorations = GetDecorationList(currentInspectorContext, currentUnitConfig)
        if #decorations == 0 then
            state.selectedDecorationId = nil
            return nil, nil, decorations
        end

        local selectedDecorationId = state.selectedDecorationId
        local selectedDecoration = nil
        for _, decoration in ipairs(decorations) do
            if type(decoration) == "table" and decoration.id == selectedDecorationId then
                selectedDecoration = decoration
                break
            end
        end

        if not selectedDecoration then
            selectedDecoration = decorations[1]
            selectedDecorationId = type(selectedDecoration) == "table" and selectedDecoration.id or nil
            state.selectedDecorationId = selectedDecorationId
        end

        return selectedDecorationId, selectedDecoration, decorations
    end

    local function BuildDecorationSelectorOptions(decorations)
        local values = {}
        local order = {}
        for index, decoration in ipairs(decorations or {}) do
            if type(decoration) == "table" and type(decoration.id) == "string" and decoration.id ~= "" then
                values[decoration.id] = BuildDecorationLabel(decoration, index)
                order[#order + 1] = decoration.id
            end
        end
        return {
            values = values,
            order = order,
        }
    end

    local function BuildStatusBarTextureOptions(currentValue)
        if MediaOptionAdapter and MediaOptionAdapter.BuildStatusBarDropdown then
            return MediaOptionAdapter.BuildStatusBarDropdown(currentValue)
        end

        return {
            values = {},
            order = {},
            value = currentValue,
        }
    end

    local function BuildFontOptions(currentValue)
        if MediaOptionAdapter and MediaOptionAdapter.BuildFontDropdown then
            return MediaOptionAdapter.BuildFontDropdown(currentValue)
        end

        return {
            values = {},
            order = {},
            value = currentValue,
        }
    end

    local function GetActiveProfileTextTemplates()
        local templates = ns.UnitFrameUtils
            and ns.UnitFrameUtils.GetTextTemplatesDB
            and ns.UnitFrameUtils.GetTextTemplatesDB()
            or nil
        return type(templates) == "table" and templates or {}
    end

    local function GetEditableActivePayload()
        local resolver = ns.ActiveLayoutResolver
        if resolver and resolver.EnsureEditableActiveLayout then
            local payload = resolver.EnsureEditableActiveLayout(ns.db)
            return type(payload) == "table" and payload or nil
        end
        return nil
    end

    local function GetEditableUnitConfig(unitKey)
        local payload = GetEditableActivePayload()
        local units = type(payload) == "table" and payload.Units or nil
        local normalizedUnit = ns.UnitFrameUtils
            and ns.UnitFrameUtils.NormalizeConfigUnitKey
            and ns.UnitFrameUtils.NormalizeConfigUnitKey(unitKey)
            or unitKey
        return type(units) == "table" and units[normalizedUnit] or nil
    end

    local function BuildTextStateTemplateOptions(currentValue)
        local values = {
            __none = L["TEXT_STATE_TEMPLATE_NONE"] or "None",
        }
        local order = { "__none" }
        local templates = GetActiveProfileTextTemplates()
        local templateNames = {}

        for templateName, templateValue in pairs(templates) do
            if type(templateName) == "string" and templateName ~= "" and type(templateValue) == "string" then
                templateNames[#templateNames + 1] = templateName
            end
        end

        table.sort(templateNames)
        for _, templateName in ipairs(templateNames) do
            values[templateName] = templateName
            order[#order + 1] = templateName
        end

        if type(currentValue) == "string" and currentValue ~= "" and values[currentValue] == nil then
            values[currentValue] = string.format("%s: %s", L["MEDIA_LIBRARY_MISSING"] or "Missing", currentValue)
            order[#order + 1] = currentValue
        end

        return {
            values = values,
            order = order,
            value = (type(currentValue) == "string" and currentValue ~= "") and currentValue or "__none",
        }
    end

    local function IsMediaBrowserAvailable()
        return ns.GUI
            and ns.GUI.Editor
            and ns.GUI.Editor.MediaLibrary
            and type(ns.GUI.Editor.MediaLibrary.Open) == "function"
    end

    local function AddMediaBrowseButton(section, disabled, onClick, options)
        if not section or not IsMediaBrowserAvailable() then
            return nil
        end

        options = type(options) == "table" and options or {}
        local button = AceGUI:Create("Button")
        if FormWidgets.ResetInspectorButtonState then
            FormWidgets.ResetInspectorButtonState(button)
        end
        button:SetText(options.label or L["MEDIA_LIBRARY_BROWSE"] or "Browse...")
        button:SetFullWidth(options.fullWidth == true)
        button:SetWidth(options.width or 112)
        button:SetDisabled(disabled and true or false)
        button:SetCallback("OnClick", function()
            if disabled or type(onClick) ~= "function" then
                return
            end
            onClick()
        end)
        if FormWidgets.ApplyModalActionButtonVisual then
            FormWidgets.ApplyModalActionButtonVisual(button, "utility")
        end
        if FormWidgets.SetInspectorButtonTooltip then
            FormWidgets.SetInspectorButtonTooltip(button, nil)
        end

        section:AddChild(button)
        return button
    end

    local function OpenMediaBrowserForField(options)
        options = type(options) == "table" and options or {}
        local MediaLibrary = ns.GUI
            and ns.GUI.Editor
            and ns.GUI.Editor.MediaLibrary
        if not (MediaLibrary and type(MediaLibrary.Open) == "function") then
            return
        end

        MediaLibrary.Open({
            mediaType = options.mediaType,
            currentValue = type(options.currentValue) == "function" and options.currentValue() or options.currentValue,
            defaultReference = options.fallbackReference,
            title = options.title,
            onApply = function(selectedValue, selectedItem)
                if type(options.onApply) == "function" then
                    options.onApply(selectedValue, selectedItem)
                end
            end,
        })
    end

    local function AddMediaBrowserForField(section, mediaType, currentValue, fallbackReference, title, disabled, onApply, buttonOptions)
        return AddMediaBrowseButton(section, disabled, function()
            OpenMediaBrowserForField({
                mediaType = mediaType,
                currentValue = currentValue,
                fallbackReference = fallbackReference,
                title = title,
                onApply = onApply,
            })
        end, buttonOptions)
    end

    local function SyncDropdownToStoredValue(dropdown, value)
        if dropdown and dropdown.SetValue then
            dropdown:SetValue(value)
        end
    end

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
        getEditablePayload = GetEditableActivePayload,
        getEditableUnitConfig = GetEditableUnitConfig,
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

    local function ResolveSelectedUnitLabel()
        if ns.GetLabel and ns.KeyMap and ns.KeyMap.Units then
            return ns.GetLabel(ns.KeyMap.Units, selectedUnit) or selectedUnit
        end
        return selectedUnit
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

    local function NotifySelectionChanged(changeKind)
        if options.onSelectionChanged then
            options.onSelectionChanged(changeKind)
            return
        end
        NotifySidebarChanged()
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
        if scope == "unitEnabled" then
            NotifyUnitEnabledChanged()
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
        elseif errorCode == "unit_not_found" then
            return L["EDITOR_INSPECTOR_ERROR_UNIT_CONFIG_NOT_FOUND"] or L["EDITOR_INSPECTOR_ERROR_CHANGE_FAILED"]
        elseif errorCode == "text_element_not_found" then
            return L["EDITOR_INSPECTOR_ERROR_TEXT_CONFIG_NOT_FOUND"] or L["EDITOR_INSPECTOR_ERROR_CHANGE_FAILED"]
        elseif errorCode == "indicator_config_not_found" then
            return L["EDITOR_INSPECTOR_ERROR_INDICATOR_CONFIG_NOT_FOUND"] or L["EDITOR_INSPECTOR_ERROR_CHANGE_FAILED"]
        elseif errorCode == "aura_config_not_found" then
            return L["EDITOR_INSPECTOR_ERROR_AURA_CONFIG_NOT_FOUND"] or L["EDITOR_INSPECTOR_ERROR_CHANGE_FAILED"]
        elseif errorCode == "template_not_found" then
            return L["INFO_TEXT_BUILDER_STATUS_SELECT_TEMPLATE"] or L["EDITOR_INSPECTOR_ERROR_CHANGE_FAILED"]
        elseif errorCode == "invalid_template_name" or errorCode == "state_key_invalid" then
            return L["EDITOR_INSPECTOR_ERROR_CHANGE_FAILED"]
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

    local function SetTextStateTemplate(textKey, stateKey, value, section, dropdown)
        local result
        if value == "__none" then
            result = type(InspectorMutations.UnassignTextStateTemplate) == "function"
                and InspectorMutations.UnassignTextStateTemplate(inspectorContext, textKey, stateKey)
                or nil
        elseif type(GetActiveProfileTextTemplates()[value]) == "string" then
            result = type(InspectorMutations.AssignTextStateTemplate) == "function"
                and InspectorMutations.AssignTextStateTemplate(inspectorContext, textKey, stateKey, value)
                or nil
        else
            local textConfig = type(unitConfig.Texts) == "table" and unitConfig.Texts[textKey] or nil
            local stateTemplates = type(textConfig) == "table" and textConfig.stateTemplates or nil
            SyncDropdownToStoredValue(dropdown, type(stateTemplates) == "table" and stateTemplates[stateKey] or "__none")
            return { ok = true, changed = false }
        end

        if result and result.ok == false then
            ReportMutationError(result)
            local textConfig = type(unitConfig.Texts) == "table" and unitConfig.Texts[textKey] or nil
            local stateTemplates = type(textConfig) == "table" and textConfig.stateTemplates or nil
            SyncDropdownToStoredValue(dropdown, type(stateTemplates) == "table" and stateTemplates[stateKey] or "__none")
            return result
        end

        if result and result.ok and result.changed then
            NotifyConfigChangedAndRebuildSection(section, "texts")
            return result
        end

        local textConfig = type(unitConfig.Texts) == "table" and unitConfig.Texts[textKey] or nil
        local stateTemplates = type(textConfig) == "table" and textConfig.stateTemplates or nil
        SyncDropdownToStoredValue(dropdown, type(stateTemplates) == "table" and stateTemplates[stateKey] or "__none")
        return result
    end

    local function RefreshTextFontSizeLocally(textKey, newValue)
        local overlay = ns.GUI
            and ns.GUI.Editor
            and ns.GUI.Editor.TextEditorOverlay
        local refreshed = overlay
            and overlay.RefreshTextElementByUnit
            and overlay.RefreshTextElementByUnit(state and state.selectedUnit, textKey)
            or false

        InspectorController.SetActiveTextFontSizeValue(state and state.selectedUnit, textKey, newValue)
        if not refreshed then
            NotifyConfigChanged()
        end
    end

    local function SetTextFontSize(textKey, value)
        if type(InspectorMutations.SetTextFontSize) ~= "function" then
            return nil
        end

        local result = InspectorMutations.SetTextFontSize(inspectorContext, textKey, value)
        if result and result.ok == false then
            ReportMutationError(result)
            return result
        end
        if result and result.ok and result.changed then
            RefreshTextFontSizeLocally(textKey, result.newValue)
        end
        return result
    end

    local function IsSelectedTextObject(unitKey, textKey)
        local selected = type(ObjectSelection.GetSelectedObject) == "function"
            and ObjectSelection.GetSelectedObject()
            or nil
        return type(selected) == "table"
            and selected.kind == "text"
            and selected.unit == NormalizeInspectorUnitKey(unitKey)
            and selected.textKey == textKey
    end

    local function IsSelectedIndicatorObject(unitKey, indicatorKey)
        local selected = type(ObjectSelection.GetSelectedObject) == "function"
            and ObjectSelection.GetSelectedObject()
            or nil
        return type(selected) == "table"
            and selected.kind == "indicator"
            and selected.unit == NormalizeInspectorUnitKey(unitKey)
            and selected.indicatorKey == indicatorKey
    end

    local function CloseDeleteTextInstanceDialog()
        if deleteTextInstanceDialog and deleteTextInstanceDialog.Close then
            deleteTextInstanceDialog:Close()
        elseif deleteTextInstanceDialog and deleteTextInstanceDialog.window and deleteTextInstanceDialog.window.Hide then
            deleteTextInstanceDialog.window:Hide()
        end
        deleteTextInstanceDialog = nil
    end

    local function CloseDeleteDecorationDialog()
        if deleteDecorationDialog and deleteDecorationDialog.Close then
            deleteDecorationDialog:Close()
        elseif deleteDecorationDialog and deleteDecorationDialog.window and deleteDecorationDialog.window.Hide then
            deleteDecorationDialog.window:Hide()
        end
        deleteDecorationDialog = nil
    end

    local function SelectUnitRootAfterTextDelete(unitKey)
        local ok = false
        if type(ObjectSelection.SelectObject) == "function" then
            ok = ObjectSelection.SelectObject({
                kind = "unit",
                unit = unitKey,
            }) == true
        end
        if not ok then
            if EditorStateApi and type(EditorStateApi.SetSingleSelection) == "function" then
                EditorStateApi.SetSingleSelection(unitKey)
            end
            if EditorStateApi and type(EditorStateApi.ClearSelectedTextElement) == "function" then
                EditorStateApi.ClearSelectedTextElement()
            end
            if EditorStateApi and type(EditorStateApi.ClearPropertyScope) == "function" then
                EditorStateApi.ClearPropertyScope()
            end
        end
    end

    local function SelectUnitRoot(unitKey)
        local ok = false
        if type(ObjectSelection.SelectObject) == "function" then
            ok = ObjectSelection.SelectObject({
                kind = "unit",
                unit = unitKey,
            }) == true
        end
        if not ok then
            if EditorStateApi and type(EditorStateApi.SetSingleSelection) == "function" then
                EditorStateApi.SetSingleSelection(unitKey)
            end
            if EditorStateApi and type(EditorStateApi.ClearPropertyScope) == "function" then
                EditorStateApi.ClearPropertyScope()
            end
        end
    end

    local function OpenDeleteTextInstanceConfirmDialog(unitKey, textKey)
        if not IsSelectedTextObject(unitKey, textKey) then
            return
        end
        if type(InspectorMutations.DeleteTextInstance) ~= "function" then
            return
        end
        if not (FormWidgets and type(FormWidgets.CreateCompactFormDialog) == "function") then
            return
        end

        CloseDeleteTextInstanceDialog()
        local dialog = FormWidgets.CreateCompactFormDialog({
            title = L["EDITOR_DELETE_TEXT_CONFIRM_TITLE"] or "Delete Text?",
            description = L["EDITOR_DELETE_TEXT_CONFIRM_DESCRIPTION"] or "This permanently removes this text from the selected unit.",
            width = 420,
            height = 226,
            bodyHeight = 58,
        })
        if not dialog then
            return
        end

        local bodyText = FormWidgets.CreateBodyText
            and FormWidgets.CreateBodyText(L["EDITOR_DELETE_TEXT_CONFIRM_TEMPLATE_NOTE"] or "The text template is not deleted.", "description", 12, nil, dialog.contentWidth - 18, false)
            or AceGUI:Create("Label")
        bodyText:SetText(L["EDITOR_DELETE_TEXT_CONFIRM_TEMPLATE_NOTE"] or "The text template is not deleted.")
        dialog.body:AddChild(bodyText)

        dialog:SetActions({
            secondary = {
                text = L["INFO_COMMON_CANCEL"] or "Cancel",
                role = "utility",
                width = 104,
                onClick = function()
                    CloseDeleteTextInstanceDialog()
                end,
            },
            primary = {
                text = L["EDITOR_DELETE_TEXT_CONFIRM_BUTTON"] or "Delete",
                role = "danger",
                width = 104,
                onClick = function(activeDialog)
                    local overlay = ns.GUI and ns.GUI.Editor and ns.GUI.Editor.TextEditorOverlay or nil
                    if overlay and type(overlay.CancelActiveDrag) == "function" then
                        overlay.CancelActiveDrag()
                    end

                    local result = InspectorMutations.DeleteTextInstance(inspectorContext, textKey)
                    if result and result.ok == false then
                        if activeDialog and activeDialog.SetStatus then
                            activeDialog:SetStatus(ResolveMutationErrorMessage(result))
                        end
                        return
                    end

                    CloseDeleteTextInstanceDialog()
                    SelectUnitRootAfterTextDelete(unitKey)
                    NotifySidebarChanged("texts")
                end,
            },
        })

        dialog.window:SetCallback("OnClose", function()
            if deleteTextInstanceDialog == dialog then
                deleteTextInstanceDialog = nil
            end
        end)
        deleteTextInstanceDialog = dialog
        dialog:Show()
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

    local function SetDecorationField(fieldName, value, section, fallbackNotify)
        if type(InspectorMutations.SetDecorationField) ~= "function" then
            return nil
        end
        local decorationId = state and state.selectedDecorationId
        if type(decorationId) ~= "string" or decorationId == "" then
            return nil
        end
        return ApplyMutation("decoration", fieldName, InspectorMutations.SetDecorationField(inspectorContext, decorationId, fieldName, value), section, fallbackNotify)
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

    local function ResolvePropertyScope()
        if not buildPropertiesOnly then
            return nil
        end
        if type(state) ~= "table" then
            return nil
        end
        local scope = state.propertyScope
        if type(scope) ~= "table" or type(scope.sectionKey) ~= "string" or scope.sectionKey == "" then
            return nil
        end
        return scope
    end

    local function ShouldBuildSection(sectionKey)
        local scope = ResolvePropertyScope()
        if not scope then
            return true
        end
        return sectionKey == scope.sectionKey
    end

    local function AddScopedInspectorSection(sectionKey, title, defaultCollapsed, sectionOptions)
        if not ShouldBuildSection(sectionKey) then
            return nil
        end
        local scopedOptions = sectionOptions
        if ResolvePropertyScope() then
            scopedOptions = {}
            for key, value in pairs(sectionOptions or {}) do
                scopedOptions[key] = value
            end
            scopedOptions.forceExpanded = true
            scopedOptions.persistCollapse = false
        end
        AddSpacer(container, INSPECTOR_SECTION_SPACING)
        return CreateInspectorSection(sectionKey, title, defaultCollapsed, scopedOptions)
    end

    local function IsScopedPowerBarObjectMode()
        local scope = ResolvePropertyScope()
        return type(scope) == "table"
            and scope.kind == "unit"
            and scope.sectionKey == "power"
    end

    local function IsScopedAlternativePowerBarObjectMode()
        local scope = ResolvePropertyScope()
        return type(scope) == "table"
            and scope.kind == "unit"
            and scope.sectionKey == "alt_power"
    end

    local function IsScopedClassPowerBarObjectMode()
        local scope = ResolvePropertyScope()
        return type(scope) == "table"
            and scope.kind == "unit"
            and scope.sectionKey == "class_power"
    end

    local function IsScopedHealthBarObjectMode()
        local scope = ResolvePropertyScope()
        return type(scope) == "table"
            and scope.kind == "unit"
            and scope.sectionKey == "health"
    end

    local function IsScopedCastBarObjectMode()
        local scope = ResolvePropertyScope()
        return type(scope) == "table"
            and scope.kind == "unit"
            and scope.sectionKey == "cast"
    end

    local function ResolveScopedAbsorbObject()
        local scope = ResolvePropertyScope()
        if not (type(scope) == "table" and scope.kind == "unit" and scope.sectionKey == "absorbs") then
            return nil
        end
        if scope.objectKey == "NormalAbsorbBar" then
            return {
                objectKey = "NormalAbsorbBar",
                prefix = "normalAbsorbBar",
                showField = "showNormalAbsorbBar",
                title = L["OPTION_NORMAL_ABSORB"] or "Normal Absorb",
                headerTitle = L["OPTION_NORMAL_ABSORB"] or "Normal Absorb Bar",
                fallbackColor = { 0.66, 0.86, 1.0, 0.62 },
                fallbackGrowth = "LEFT_TO_RIGHT",
            }
        elseif scope.objectKey == "HealingAbsorbBar" then
            return {
                objectKey = "HealingAbsorbBar",
                prefix = "healingAbsorbBar",
                showField = "showHealingAbsorbBar",
                title = L["OPTION_HEALING_ABSORB"] or "Healing Absorb",
                headerTitle = L["OPTION_HEALING_ABSORB"] or "Healing Absorb Bar",
                fallbackColor = { 0.75, 0.20, 1.0, 0.62 },
                fallbackGrowth = "RIGHT_TO_LEFT",
            }
        end
        return nil
    end

    local function AddObjectInspectorHeader(parent, title, subtitle)
        local titleLabel
        if FormWidgets.CreateSectionTitle then
            titleLabel = FormWidgets.CreateSectionTitle(title or "")
        else
            titleLabel = AceGUI:Create("Label")
            titleLabel:SetFullWidth(true)
            titleLabel:SetText(title or "")
        end
        parent:AddChild(titleLabel)

        local subtitleLabel
        if FormWidgets.CreateBodyText then
            subtitleLabel = FormWidgets.CreateBodyText(subtitle or "", "description", 11, ResolveItemColor and ResolveItemColor("statusMuted") or nil)
        else
            subtitleLabel = AceGUI:Create("Label")
            subtitleLabel:SetFullWidth(true)
            subtitleLabel:SetText(subtitle or "")
        end
        parent:AddChild(subtitleLabel)
    end

    local function AddScopedObjectInspectorBody(sectionKey, title, localContentBuilder)
        if not ShouldBuildSection(sectionKey) then
            return nil
        end

        AddSpacer(container, INSPECTOR_SECTION_SPACING)

        local root = AceGUI:Create("SimpleGroup")
        root:SetFullWidth(true)
        root:SetLayout("Flow")
        container:AddChild(root)

        AddObjectInspectorHeader(root, title, ResolveSelectedUnitLabel())
        AddSpacer(root, 6)

        local body = AceGUI:Create("SimpleGroup")
        body:SetFullWidth(true)
        body:SetLayout("Flow")
        root:AddChild(body)

        local function BuildBodyContent()
            body:ReleaseChildren()
            if type(localContentBuilder) == "function" then
                localContentBuilder(body)
            end
        end

        local function RebuildBody()
            BuildBodyContent()
            RefreshInspectorLayout()
        end

        body._focalPointRequestRebuild = RebuildBody
        if body.SetUserData then
            body:SetUserData("focalPointSectionKey", sectionKey)
            body:SetUserData("focalPointSectionRole", "content")
        end
        if body.frame then
            body.frame._focalPointSectionKey = sectionKey
            body.frame._focalPointSectionRole = "content"
        end

        BuildBodyContent()
        return body
    end

    local function AddObjectPropertyGroup(parent, title, addTopSpacing)
        if addTopSpacing then
            AddSpacer(parent, 10)
        end

        local group = AceGUI:Create("SimpleGroup")
        group:SetFullWidth(true)
        group:SetLayout("Flow")
        parent:AddChild(group)

        local header = AceGUI:Create("SimpleGroup")
        header:SetFullWidth(true)
        header:SetLayout("Table")
        header:SetUserData("table", {
            columns = {
                { width = 96 },
                { weight = 1 },
            },
            spaceH = 8,
            spaceV = 0,
            align = "TOPLEFT",
            alignV = "center",
            alignH = "start",
        })
        group:AddChild(header)

        local titleLabel
        if FormWidgets.CreateSectionTitle then
            titleLabel = FormWidgets.CreateSectionTitle(title or "", 12)
        else
            titleLabel = AceGUI:Create("Label")
            titleLabel:SetText(title or "")
        end
        titleLabel:SetFullWidth(false)
        titleLabel:SetWidth(96)
        header:AddChild(titleLabel)

        local separator = AceGUI:Create("SimpleGroup")
        separator:SetFullWidth(true)
        separator:SetHeight(12)
        header:AddChild(separator)
        if separator.frame and separator.frame.CreateTexture then
            local line = separator.frame:CreateTexture(nil, "ARTWORK")
            local color = ResolveItemColor and ResolveItemColor("sectionBorder") or { 0.16, 0.19, 0.24, 0.75 }
            line:SetPoint("LEFT", separator.frame, "LEFT", 0, 0)
            line:SetPoint("RIGHT", separator.frame, "RIGHT", 0, 0)
            line:SetHeight(1)
            line:SetColorTexture(color[1] or 0.16, color[2] or 0.19, color[3] or 0.24, color[4] or 0.75)
        end

        AddSpacer(group, 4)

        local content = AceGUI:Create("SimpleGroup")
        content:SetFullWidth(true)
        content:SetLayout("Flow")
        group:AddChild(content)

        return content
    end

    local function AddPropertyLabel(parent, text)
        if not parent then
            return nil
        end

        local label
        if FormWidgets.CreateBodyText then
            label = FormWidgets.CreateBodyText(text or "", "label", 12, nil, nil, true)
        else
            label = AceGUI:Create("Label")
            label:SetFullWidth(true)
            label:SetText(text or "")
        end
        parent:AddChild(label)
        return label
    end

    local function CreateTwoControlTableRow(parent, rightColumnWidth)
        if not parent then
            return nil
        end

        local row = AceGUI:Create("SimpleGroup")
        row:SetFullWidth(true)
        row:SetLayout("Table")
        row:SetUserData("table", {
            columns = {
                { weight = 1 },
                { width = rightColumnWidth or 96 },
            },
            spaceH = 8,
            spaceV = 0,
            align = "TOPLEFT",
            alignV = "start",
            alignH = "start",
        })
        parent:AddChild(row)
        return row
    end

    local function CreateEvenTwoControlTableRow(parent)
        if not parent then
            return nil
        end

        local row = AceGUI:Create("SimpleGroup")
        row:SetFullWidth(true)
        row:SetLayout("Table")
        row:SetUserData("table", {
            columns = {
                { weight = 1 },
                { weight = 1 },
            },
            spaceH = 8,
            spaceV = 0,
            align = "TOPLEFT",
            alignV = "start",
            alignH = "start",
        })
        parent:AddChild(row)
        return row
    end

    local function AddDropdownBrowseRow(parent, dropdownOptions, browseCallback, disabled)
        local row = CreateTwoControlTableRow(parent, 80)
        if not row then
            return nil, nil
        end

        dropdownOptions = type(dropdownOptions) == "table" and dropdownOptions or {}
        local dropdown = AddDropdown(
            row,
            "",
            dropdownOptions.list,
            dropdownOptions.value,
            dropdownOptions.onChanged,
            disabled,
            dropdownOptions.anchorKey
        )

        local browse = AddMediaBrowseButton(row, disabled, browseCallback, {
            width = 80,
        })
        return dropdown, browse
    end

    local function AddToggleColorRow(parent, toggleOptions, colorOptions)
        local row = CreateTwoControlTableRow(parent, 96)
        if not row then
            return nil, nil
        end

        toggleOptions = type(toggleOptions) == "table" and toggleOptions or {}
        colorOptions = type(colorOptions) == "table" and colorOptions or {}

        local toggle = AddCheckBox(
            row,
            toggleOptions.label or L["OPTION_ENABLED"] or "Enabled",
            toggleOptions.value,
            toggleOptions.onChanged,
            toggleOptions.disabled,
            toggleOptions.anchorKey
        )
        local color = AddColorPicker(
            row,
            "",
            colorOptions.color,
            colorOptions.hasAlpha ~= false,
            colorOptions.onChanged,
            colorOptions.disabled,
            colorOptions.anchorKey
        )
        return toggle, color
    end


    local function AddPointPairRow(parent, pointOptions, relativePointOptions)
        AddPropertyLabel(parent, L["OPTION_ANCHOR_POINTS"] or "Anchor Points")
        local row = CreateEvenTwoControlTableRow(parent)
        if not row then
            return nil, nil
        end

        pointOptions = type(pointOptions) == "table" and pointOptions or {}
        relativePointOptions = type(relativePointOptions) == "table" and relativePointOptions or {}
        local point = AddDropdown(row, pointOptions.label or L["OPTION_FROM_POINT"] or "From Point", pointOptions.list, pointOptions.value, pointOptions.onChanged, pointOptions.disabled, pointOptions.anchorKey)
        local relativePoint = AddDropdown(row, relativePointOptions.label or L["OPTION_TO_POINT"] or "To Point", relativePointOptions.list, relativePointOptions.value, relativePointOptions.onChanged, relativePointOptions.disabled, relativePointOptions.anchorKey)
        return point, relativePoint
    end


    if buildContextOnly then
        return
    end

    local function BuildFrameSectionContent(frameSection)
        if not frameSection then
            return
        end

        AddCheckBox(frameSection, L["EDITOR_OPTION_ENABLED"] or "Enabled", unitConfig.enabled ~= false, function(value)
            SetUnitField("enabled", value and true or false)
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

    AddScopedInspectorSection("frame", L["EDITOR_SECTION_FRAME"] or "Frame", false, {
        localContentBuilder = BuildFrameSectionContent,
        layoutRefresh = RefreshInspectorLayout,
    })

    local function BuildHealthSectionContent(healthSection)
        if not healthSection then
            return
        end

        local usePropertyGroups = IsScopedHealthBarObjectMode()
        local appearanceSection = healthSection
        local behaviorSection = healthSection
        if usePropertyGroups then
            appearanceSection = AddObjectPropertyGroup(healthSection, L["SECTION_APPEARANCE"] or "Appearance", false)
            if isExpert then
                behaviorSection = AddObjectPropertyGroup(healthSection, L["SECTION_BEHAVIOR"] or "Behavior", true)
            end
        end

        local healthTextureOptions = BuildStatusBarTextureOptions(unitConfig.healthBarTexture)
        local healthTextureDropdown
        local function SetHealthBarTexture(value)
            local result = SetUnitField("healthBarTexture", value)
            if not (result and result.ok == false) then
                SyncDropdownToStoredValue(healthTextureDropdown, unitConfig.healthBarTexture)
            end
            return result
        end
        if usePropertyGroups then
            AddPropertyLabel(appearanceSection, L["OPTION_TEXTURE"] or L["OPTION_BAR_TEXTURE"] or "Texture")
            healthTextureDropdown = AddDropdownBrowseRow(appearanceSection, {
                list = healthTextureOptions,
                value = healthTextureOptions.value,
                onChanged = SetHealthBarTexture,
            }, function()
                OpenMediaBrowserForField({
                    mediaType = MEDIA_TYPE_STATUSBAR,
                    currentValue = function()
                        return unitConfig.healthBarTexture
                    end,
                    fallbackReference = DEFAULT_STATUSBAR_REFERENCE,
                    title = L["MEDIA_LIBRARY_BROWSE_STATUSBAR_TITLE"] or "Choose Bar Texture",
                    onApply = SetHealthBarTexture,
                })
            end)
        else
            healthTextureDropdown = AddDropdown(appearanceSection, L["OPTION_BAR_TEXTURE"] or "Bar Texture", healthTextureOptions, healthTextureOptions.value, SetHealthBarTexture)
            AddMediaBrowserForField(appearanceSection, MEDIA_TYPE_STATUSBAR, function()
                return unitConfig.healthBarTexture
            end, DEFAULT_STATUSBAR_REFERENCE, L["MEDIA_LIBRARY_BROWSE_STATUSBAR_TITLE"] or "Choose Bar Texture", false, SetHealthBarTexture)
        end

        AddCheckBox(appearanceSection, L["OPTION_USE_CLASS_COLORS"] or "Use Class Colors", unitConfig.useClassColorHealth == true, function(value)
            SetUnitField("useClassColorHealth", value and true or false, healthSection)
        end)

        if isExpert then
            AddCheckBox(appearanceSection, L["OPTION_USE_REACTION_COLORS_NPC_HEALTH"] or "Use NPC Reaction Colors", unitConfig.useReactionColorNpcHealth == true, function(value)
                SetUnitField("useReactionColorNpcHealth", value and true or false, healthSection)
            end)

            AddCheckBox(behaviorSection, L["OPTION_REVERSE_FILL"] or "Reverse Fill", unitConfig.healthBarReverseFill == true, function(value)
                SetUnitField("healthBarReverseFill", value and true or false)
            end)
        end

        if isQuick or unitConfig.useClassColorHealth ~= true then
            AddColorPicker(appearanceSection, L["OPTION_COLOR"] or "Color", unitConfig.healthColor, true, function(value)
                SetUnitField("healthColor", value)
            end, unitConfig.useClassColorHealth == true or unitConfig.useReactionColorNpcHealth == true)
        end

        if usePropertyGroups then
            AddPropertyLabel(appearanceSection, L["OPTION_LOW_HEALTH_COLOR"] or "Low Health Color")
            AddToggleColorRow(appearanceSection, {
                label = L["OPTION_ENABLED"] or "Enabled",
                value = unitConfig.useLowHealthColor ~= false,
                onChanged = function(value)
                    SetUnitField("useLowHealthColor", value and true or false, healthSection)
                end,
            }, {
                color = unitConfig.healthLowColor,
                hasAlpha = true,
                onChanged = function(value)
                    SetUnitField("healthLowColor", value)
                end,
                disabled = unitConfig.useLowHealthColor == false,
            })
        else
            AddCheckBox(appearanceSection, L["OPTION_USE_LOW_HEALTH_COLOR"] or "Use Low Health Color", unitConfig.useLowHealthColor ~= false, function(value)
                SetUnitField("useLowHealthColor", value and true or false, healthSection)
            end)

            AddColorPicker(appearanceSection, L["OPTION_LOW_HEALTH_COLOR"] or "Low Health Color", unitConfig.healthLowColor, true, function(value)
                SetUnitField("healthLowColor", value)
            end, unitConfig.useLowHealthColor == false)
        end

        if isExpert then
            if usePropertyGroups then
                AddPropertyLabel(appearanceSection, L["OPTION_BACKGROUND"] or "Background")
                AddToggleColorRow(appearanceSection, {
                    label = L["OPTION_ENABLED"] or "Enabled",
                    value = unitConfig.healthBackground ~= false,
                    onChanged = function(value)
                        SetUnitField("healthBackground", value and true or false, healthSection)
                    end,
                }, {
                    color = unitConfig.healthBackgroundColor,
                    hasAlpha = true,
                    onChanged = function(value)
                        SetUnitField("healthBackgroundColor", value)
                    end,
                    disabled = unitConfig.healthBackground == false,
                })
            else
                AddCheckBox(appearanceSection, L["OPTION_SHOW_BACKGROUND"] or "Show Background", unitConfig.healthBackground ~= false, function(value)
                    SetUnitField("healthBackground", value and true or false, healthSection)
                end)

                AddColorPicker(appearanceSection, L["OPTION_BACKGROUND_COLOR"] or "Background Color", unitConfig.healthBackgroundColor, true, function(value)
                    SetUnitField("healthBackgroundColor", value)
                end, unitConfig.healthBackground == false)
            end
        end
    end

    if IsScopedHealthBarObjectMode() then
        AddScopedObjectInspectorBody("health", L["VALUE_ANCHOR_TARGET_HEALTH_BAR"] or L["BAR_HEALTH"] or "Health Bar", BuildHealthSectionContent)
    else
        AddScopedInspectorSection("health", L["BAR_HEALTH"] or "Health", false, {
            localContentBuilder = BuildHealthSectionContent,
            layoutRefresh = RefreshInspectorLayout,
        })
    end

    local function BuildAbsorbsSectionContent(absorbsSection)
        if not absorbsSection then
            return
        end

        local scopedAbsorbObject = ResolveScopedAbsorbObject()

        local function AddAbsorbSubheading(text)
            local label = AceGUI:Create("Label")
            label:SetFullWidth(true)
            label:SetText(text)
            absorbsSection:AddChild(label)
        end

        local function BuildAbsorbBar(prefix, showField, title, fallbackColor, fallbackGrowth, options)
            options = type(options) == "table" and options or {}
            local isScopedObject = options.scopedObject == true
            local rootSection = options.rootSection or absorbsSection
            local generalSection = absorbsSection
            local appearanceSection = absorbsSection
            local geometrySection = absorbsSection
            local behaviorSection = absorbsSection

            if isScopedObject then
                generalSection = AddObjectPropertyGroup(absorbsSection, L["SECTION_GENERAL"] or "General", false)
                appearanceSection = AddObjectPropertyGroup(absorbsSection, L["SECTION_APPEARANCE"] or "Appearance", true)
                if isExpert then
                    geometrySection = AddObjectPropertyGroup(absorbsSection, L["SECTION_GEOMETRY"] or "Geometry", true)
                    behaviorSection = AddObjectPropertyGroup(absorbsSection, L["SECTION_BEHAVIOR"] or "Behavior", true)
                end
            else
                AddAbsorbSubheading(title)
            end

            local showValue = unitConfig[showField] ~= false
            AddCheckBox(generalSection, L["OPTION_SHOW"] or "Show", showValue, function(value)
                SetUnitField(showField, value and true or false, rootSection)
            end)

            local textureField = prefix .. "Texture"
            local textureOptions = BuildStatusBarTextureOptions(unitConfig[textureField])
            local textureDropdown
            local function SetAbsorbTexture(value)
                local result = SetUnitField(textureField, value, rootSection)
                if not (result and result.ok == false) then
                    SyncDropdownToStoredValue(textureDropdown, unitConfig[textureField])
                end
                return result
            end
            if isScopedObject then
                AddPropertyLabel(appearanceSection, L["OPTION_TEXTURE"] or L["OPTION_BAR_TEXTURE"] or "Texture")
                textureDropdown = AddDropdownBrowseRow(appearanceSection, {
                    list = textureOptions,
                    value = textureOptions.value,
                    onChanged = SetAbsorbTexture,
                }, function()
                    OpenMediaBrowserForField({
                        mediaType = MEDIA_TYPE_STATUSBAR,
                        currentValue = function()
                            return unitConfig[textureField]
                        end,
                        fallbackReference = DEFAULT_STATUSBAR_REFERENCE,
                        title = L["MEDIA_LIBRARY_BROWSE_STATUSBAR_TITLE"] or "Choose Bar Texture",
                        onApply = SetAbsorbTexture,
                    })
                end)
            else
                textureDropdown = AddDropdown(absorbsSection, L["OPTION_BAR_TEXTURE"] or "Bar Texture", textureOptions, textureOptions.value, SetAbsorbTexture)
                AddMediaBrowserForField(absorbsSection, MEDIA_TYPE_STATUSBAR, function()
                    return unitConfig[textureField]
                end, DEFAULT_STATUSBAR_REFERENCE, L["MEDIA_LIBRARY_BROWSE_STATUSBAR_TITLE"] or "Choose Bar Texture", false, SetAbsorbTexture)
            end

            AddColorPicker(appearanceSection, L["OPTION_COLOR"] or "Color", unitConfig[prefix .. "Color"] or fallbackColor, true, function(value)
                SetUnitField(prefix .. "Color", value, rootSection)
            end)

            if not isExpert then
                return
            end

            AddColorPicker(appearanceSection, L["OPTION_BACKGROUND_COLOR"] or "Background Color", unitConfig[prefix .. "BackgroundColor"] or { 0, 0, 0, 0 }, true, function(value)
                SetUnitField(prefix .. "BackgroundColor", value, rootSection)
            end)

            local sizeMode = unitConfig[prefix .. "SizeMode"] or "MATCH_TARGET"
            local isCustom = sizeMode == "CUSTOM"
            AddDropdown(geometrySection, L["OPTION_SIZE_MODE"] or "Size Mode", absorbSizeModeList, sizeMode, function(value)
                SetUnitField(prefix .. "SizeMode", value, rootSection)
            end)
            local anchorTargetLabel = isScopedObject
                and (L["OPTION_ANCHOR_TARGET"] or "Anchor Target")
                or (L["OPTION_ANCHOR_TO_TARGET"] or "Anchor To Element")
            AddDropdown(geometrySection, anchorTargetLabel, absorbAnchorTargetList, unitConfig[prefix .. "AnchorTo"] or "HealthBar", function(value)
                SetUnitField(prefix .. "AnchorTo", value, rootSection)
            end)
            if isScopedObject then
                AddPropertyLabel(geometrySection, L["OPTION_SIZE"] or "Size")
                AddSlider(geometrySection, L["OPTION_WIDTH"] or "Width", 1, 512, 1, tonumber(unitConfig[prefix .. "Width"]) or 120, function(value)
                    SetUnitField(prefix .. "Width", math.floor((value or 0) + 0.5), rootSection)
                end, not isCustom)
                AddSlider(geometrySection, L["OPTION_HEIGHT"] or "Height", 1, 128, 1, tonumber(unitConfig[prefix .. "Height"]) or 8, function(value)
                    SetUnitField(prefix .. "Height", math.floor((value or 0) + 0.5), rootSection)
                end, not isCustom)
                AddPointPairRow(geometrySection, {
                    list = barAnchorList,
                    value = unitConfig[prefix .. "Point"] or "LEFT",
                    onChanged = function(value)
                        SetUnitField(prefix .. "Point", value, rootSection)
                    end,
                    disabled = not isCustom,
                }, {
                    list = barAnchorList,
                    value = unitConfig[prefix .. "RelativePoint"] or "LEFT",
                    onChanged = function(value)
                        SetUnitField(prefix .. "RelativePoint", value, rootSection)
                    end,
                    disabled = not isCustom,
                })
                AddPropertyLabel(geometrySection, L["OPTION_OFFSET"] or "Offset")
                AddSlider(geometrySection, L["OPTION_OFFSET_X"] or "Offset X", -500, 500, 1, tonumber(unitConfig[prefix .. "OffsetX"]) or 0, function(value)
                    SetUnitField(prefix .. "OffsetX", math.floor((value or 0) + 0.5), rootSection)
                end, not isCustom)
                AddSlider(geometrySection, L["OPTION_OFFSET_Y"] or "Offset Y", -500, 500, 1, tonumber(unitConfig[prefix .. "OffsetY"]) or 0, function(value)
                    SetUnitField(prefix .. "OffsetY", math.floor((value or 0) + 0.5), rootSection)
                end, not isCustom)
            else
                AddSlider(geometrySection, L["OPTION_WIDTH"] or "Width", 1, 512, 1, tonumber(unitConfig[prefix .. "Width"]) or 120, function(value)
                    SetUnitField(prefix .. "Width", math.floor((value or 0) + 0.5), rootSection)
                end, not isCustom)
                AddSlider(geometrySection, L["OPTION_HEIGHT"] or "Height", 1, 128, 1, tonumber(unitConfig[prefix .. "Height"]) or 8, function(value)
                    SetUnitField(prefix .. "Height", math.floor((value or 0) + 0.5), rootSection)
                end, not isCustom)
                AddDropdown(geometrySection, L["OPTION_ANCHOR_FROM"] or "Anchor From", barAnchorList, unitConfig[prefix .. "Point"] or "LEFT", function(value)
                    SetUnitField(prefix .. "Point", value, rootSection)
                end, not isCustom)
                AddDropdown(geometrySection, L["OPTION_ANCHOR_TO"] or "Anchor To", barAnchorList, unitConfig[prefix .. "RelativePoint"] or "LEFT", function(value)
                    SetUnitField(prefix .. "RelativePoint", value, rootSection)
                end, not isCustom)
                AddSlider(geometrySection, L["OPTION_X_OFFSET"] or "X Offset", -500, 500, 1, tonumber(unitConfig[prefix .. "OffsetX"]) or 0, function(value)
                    SetUnitField(prefix .. "OffsetX", math.floor((value or 0) + 0.5), rootSection)
                end, not isCustom)
                AddSlider(geometrySection, L["OPTION_Y_OFFSET"] or "Y Offset", -500, 500, 1, tonumber(unitConfig[prefix .. "OffsetY"]) or 0, function(value)
                    SetUnitField(prefix .. "OffsetY", math.floor((value or 0) + 0.5), rootSection)
                end, not isCustom)
            end
            AddDropdown(behaviorSection, L["OPTION_GROWTH_DIRECTION"] or "Growth Direction", absorbGrowthList, unitConfig[prefix .. "Growth"] or fallbackGrowth, function(value)
                SetUnitField(prefix .. "Growth", value, rootSection)
            end)
        end

        if scopedAbsorbObject then
            BuildAbsorbBar(
                scopedAbsorbObject.prefix,
                scopedAbsorbObject.showField,
                scopedAbsorbObject.title,
                scopedAbsorbObject.fallbackColor,
                scopedAbsorbObject.fallbackGrowth,
                { scopedObject = true, rootSection = absorbsSection }
            )
            return
        end

        BuildAbsorbBar("normalAbsorbBar", "showNormalAbsorbBar", L["OPTION_NORMAL_ABSORB"] or "Normal Absorb", { 0.66, 0.86, 1.0, 0.62 }, "LEFT_TO_RIGHT")
        AddSpacer(absorbsSection, 6)
        BuildAbsorbBar("healingAbsorbBar", "showHealingAbsorbBar", L["OPTION_HEALING_ABSORB"] or "Healing Absorb", { 0.75, 0.20, 1.0, 0.62 }, "RIGHT_TO_LEFT")
    end

    do
        local scopedAbsorbObject = ResolveScopedAbsorbObject()
        if scopedAbsorbObject then
            AddScopedObjectInspectorBody("absorbs", scopedAbsorbObject.headerTitle, BuildAbsorbsSectionContent)
        else
            AddScopedInspectorSection("absorbs", L["OPTION_ABSORBS"] or "Absorbs", true, {
                localContentBuilder = BuildAbsorbsSectionContent,
                layoutRefresh = RefreshInspectorLayout,
            })
        end
    end

    local function BuildPowerSectionContent(powerSection)
        if not powerSection then
            return
        end

        local usePropertyGroups = IsScopedPowerBarObjectMode()
        local generalSection = powerSection
        local appearanceSection = powerSection
        local geometrySection = powerSection
        local behaviorSection = powerSection
        if usePropertyGroups then
            generalSection = AddObjectPropertyGroup(powerSection, L["SECTION_GENERAL"] or "General", false)
            appearanceSection = AddObjectPropertyGroup(powerSection, L["SECTION_APPEARANCE"] or "Appearance", true)
            if isExpert then
                geometrySection = AddObjectPropertyGroup(powerSection, L["SECTION_GEOMETRY"] or "Geometry", true)
                behaviorSection = AddObjectPropertyGroup(powerSection, L["SECTION_BEHAVIOR"] or "Behavior", true)
            end
        end

        AddCheckBox(generalSection, L["EDITOR_OPTION_SHOW_POWER"] or "Show Power Bar", unitConfig.showPowerBar ~= false, function(value)
            SetUnitField("showPowerBar", value and true or false, powerSection)
        end)

        local powerTextureOptions = BuildStatusBarTextureOptions(unitConfig.powerBarTexture)
        local powerTextureDropdown
        local function SetPowerBarTexture(value)
            local result = SetUnitField("powerBarTexture", value)
            if not (result and result.ok == false) then
                SyncDropdownToStoredValue(powerTextureDropdown, unitConfig.powerBarTexture)
            end
            return result
        end
        if usePropertyGroups then
            AddPropertyLabel(appearanceSection, L["OPTION_TEXTURE"] or L["OPTION_BAR_TEXTURE"] or "Texture")
            powerTextureDropdown = AddDropdownBrowseRow(appearanceSection, {
                list = powerTextureOptions,
                value = powerTextureOptions.value,
                onChanged = SetPowerBarTexture,
            }, function()
                OpenMediaBrowserForField({
                    mediaType = MEDIA_TYPE_STATUSBAR,
                    currentValue = function()
                        return unitConfig.powerBarTexture
                    end,
                    fallbackReference = DEFAULT_STATUSBAR_REFERENCE,
                    title = L["MEDIA_LIBRARY_BROWSE_STATUSBAR_TITLE"] or "Choose Bar Texture",
                    onApply = SetPowerBarTexture,
                })
            end, unitConfig.showPowerBar == false)
        else
            powerTextureDropdown = AddDropdown(appearanceSection, L["OPTION_BAR_TEXTURE"] or "Bar Texture", powerTextureOptions, powerTextureOptions.value, SetPowerBarTexture, unitConfig.showPowerBar == false)
            AddMediaBrowserForField(appearanceSection, MEDIA_TYPE_STATUSBAR, function()
                return unitConfig.powerBarTexture
            end, DEFAULT_STATUSBAR_REFERENCE, L["MEDIA_LIBRARY_BROWSE_STATUSBAR_TITLE"] or "Choose Bar Texture", unitConfig.showPowerBar == false, SetPowerBarTexture)
        end

        if isExpert then
            AddSlider(geometrySection, L["OPTION_POWER_BAR_HEIGHT"] or "Power Bar Height", 4, 30, 1, tonumber(unitConfig.powerBarHeight) or 20, function(value)
                SetUnitField("powerBarHeight", math.floor((value or 0) + 0.5))
            end, unitConfig.showPowerBar == false)
        end

        AddCheckBox(appearanceSection, L["OPTION_USE_CLASS_COLORS"] or "Use Class Colors", unitConfig.useClassColorPower == true, function(value)
            SetUnitField("useClassColorPower", value and true or false, powerSection)
        end, unitConfig.showPowerBar == false)

        if isExpert then
            AddCheckBox(behaviorSection, L["OPTION_REVERSE_FILL"] or "Reverse Fill", unitConfig.powerBarReverseFill == true, function(value)
                SetUnitField("powerBarReverseFill", value and true or false)
            end, unitConfig.showPowerBar == false)
        end

        AddColorPicker(appearanceSection, L["OPTION_COLOR"] or "Color", unitConfig.powerColor, true, function(value)
            SetUnitField("powerColor", value)
        end, unitConfig.showPowerBar == false or unitConfig.useClassColorPower == true)

        if isExpert then
            if usePropertyGroups then
                AddPropertyLabel(appearanceSection, L["OPTION_BACKGROUND"] or "Background")
                AddToggleColorRow(appearanceSection, {
                    label = L["OPTION_ENABLED"] or "Enabled",
                    value = unitConfig.powerBackground ~= false,
                    onChanged = function(value)
                        SetUnitField("powerBackground", value and true or false, powerSection)
                    end,
                    disabled = unitConfig.showPowerBar == false,
                }, {
                    color = unitConfig.powerBackgroundColor,
                    hasAlpha = true,
                    onChanged = function(value)
                        SetUnitField("powerBackgroundColor", value)
                    end,
                    disabled = unitConfig.showPowerBar == false or unitConfig.powerBackground == false,
                })
            else
                AddCheckBox(appearanceSection, L["OPTION_SHOW_BACKGROUND"] or "Show Background", unitConfig.powerBackground ~= false, function(value)
                    SetUnitField("powerBackground", value and true or false, powerSection)
                end, unitConfig.showPowerBar == false)

                AddColorPicker(appearanceSection, L["OPTION_BACKGROUND_COLOR"] or "Background Color", unitConfig.powerBackgroundColor, true, function(value)
                    SetUnitField("powerBackgroundColor", value)
                end, unitConfig.showPowerBar == false or unitConfig.powerBackground == false)
            end
        end
    end

    if IsScopedPowerBarObjectMode() then
        AddScopedObjectInspectorBody("power", L["VALUE_ANCHOR_TARGET_POWER_BAR"] or L["BAR_POWER"] or "Power Bar", BuildPowerSectionContent)
    else
        AddScopedInspectorSection("power", L["BAR_POWER"] or "Power", true, {
            localContentBuilder = BuildPowerSectionContent,
            layoutRefresh = RefreshInspectorLayout,
        })
    end

    local function BuildAltPowerSectionContent(altPowerSection)
        if not altPowerSection or selectedUnit ~= "player" then
            return
        end

        local usePropertyGroups = IsScopedAlternativePowerBarObjectMode()
        local rootSection = altPowerSection
        local generalSection = altPowerSection
        local appearanceSection = altPowerSection
        local geometrySection = altPowerSection
        local behaviorSection = altPowerSection
        if usePropertyGroups then
            generalSection = AddObjectPropertyGroup(altPowerSection, L["SECTION_GENERAL"] or "General", false)
            appearanceSection = AddObjectPropertyGroup(altPowerSection, L["SECTION_APPEARANCE"] or "Appearance", true)
            geometrySection = AddObjectPropertyGroup(altPowerSection, L["SECTION_GEOMETRY"] or "Geometry", true)
            if isExpert then
                behaviorSection = AddObjectPropertyGroup(altPowerSection, L["SECTION_BEHAVIOR"] or "Behavior", true)
            end
        end

        AddCheckBox(generalSection, L["OPTION_SHOW_ALTERNATIVE_POWER_BAR"] or "Show Alternative Power Bar", unitConfig.showAlternativePowerBar == true, function(value)
            SetUnitField("showAlternativePowerBar", value and true or false, rootSection)
        end)

        local alternativePowerTextureValue = unitConfig.alternativePowerBarTexture or unitConfig.powerBarTexture
        local alternativePowerTextureOptions = BuildStatusBarTextureOptions(alternativePowerTextureValue)
        local alternativePowerTextureDropdown
        local function SetAlternativePowerBarTexture(value)
            local result = SetUnitField("alternativePowerBarTexture", value)
            if not (result and result.ok == false) then
                SyncDropdownToStoredValue(alternativePowerTextureDropdown, unitConfig.alternativePowerBarTexture or unitConfig.powerBarTexture)
            end
            return result
        end
        if usePropertyGroups then
            AddPropertyLabel(appearanceSection, L["OPTION_TEXTURE"] or L["OPTION_BAR_TEXTURE"] or "Texture")
            alternativePowerTextureDropdown = AddDropdownBrowseRow(appearanceSection, {
                list = alternativePowerTextureOptions,
                value = alternativePowerTextureOptions.value,
                onChanged = SetAlternativePowerBarTexture,
                disabled = unitConfig.showAlternativePowerBar ~= true,
            }, function()
                OpenMediaBrowserForField({
                    mediaType = MEDIA_TYPE_STATUSBAR,
                    currentValue = function()
                        return unitConfig.alternativePowerBarTexture or unitConfig.powerBarTexture
                    end,
                    fallbackReference = DEFAULT_STATUSBAR_REFERENCE,
                    title = L["MEDIA_LIBRARY_BROWSE_STATUSBAR_TITLE"] or "Choose Bar Texture",
                    onApply = SetAlternativePowerBarTexture,
                })
            end, unitConfig.showAlternativePowerBar ~= true)
        else
            alternativePowerTextureDropdown = AddDropdown(altPowerSection, L["OPTION_BAR_TEXTURE"] or "Bar Texture", alternativePowerTextureOptions, alternativePowerTextureOptions.value, SetAlternativePowerBarTexture, unitConfig.showAlternativePowerBar ~= true)
            AddMediaBrowserForField(altPowerSection, MEDIA_TYPE_STATUSBAR, function()
                return unitConfig.alternativePowerBarTexture or unitConfig.powerBarTexture
            end, DEFAULT_STATUSBAR_REFERENCE, L["MEDIA_LIBRARY_BROWSE_STATUSBAR_TITLE"] or "Choose Bar Texture", unitConfig.showAlternativePowerBar ~= true, SetAlternativePowerBarTexture)
        end

        AddSlider(geometrySection, L["OPTION_ALTERNATIVE_POWER_BAR_HEIGHT"] or "Alternative Power Height", 4, 30, 1, tonumber(unitConfig.alternativePowerBarHeight) or 20, function(value)
            SetUnitField("alternativePowerBarHeight", math.floor((value or 0) + 0.5))
        end, unitConfig.showAlternativePowerBar ~= true)

        if isExpert then
            local altPowerReverseFillEnabled = unitConfig.alternativePowerBarReverseFill
            if altPowerReverseFillEnabled == nil then
                altPowerReverseFillEnabled = unitConfig.powerBarReverseFill == true
            else
                altPowerReverseFillEnabled = altPowerReverseFillEnabled == true
            end

            AddCheckBox(behaviorSection, L["OPTION_REVERSE_FILL"] or "Reverse Fill", altPowerReverseFillEnabled, function(value)
                SetUnitField("alternativePowerBarReverseFill", value and true or false)
            end, unitConfig.showAlternativePowerBar ~= true)

            AddColorPicker(appearanceSection, L["OPTION_COLOR"] or "Color", unitConfig.alternativePowerColor, true, function(value)
                SetUnitField("alternativePowerColor", value)
            end, unitConfig.showAlternativePowerBar ~= true)

            local altPowerBackgroundEnabled = unitConfig.alternativePowerBackground
            if altPowerBackgroundEnabled == nil then
                altPowerBackgroundEnabled = unitConfig.powerBackground ~= false
            else
                altPowerBackgroundEnabled = altPowerBackgroundEnabled ~= false
            end

            if usePropertyGroups then
                AddPropertyLabel(appearanceSection, L["OPTION_BACKGROUND"] or "Background")
                AddToggleColorRow(appearanceSection, {
                    label = L["OPTION_ENABLED"] or "Enabled",
                    value = altPowerBackgroundEnabled,
                    onChanged = function(value)
                        SetUnitField("alternativePowerBackground", value and true or false, rootSection)
                    end,
                    disabled = unitConfig.showAlternativePowerBar ~= true,
                }, {
                    color = unitConfig.alternativePowerBackgroundColor or unitConfig.powerBackgroundColor,
                    hasAlpha = true,
                    onChanged = function(value)
                        SetUnitField("alternativePowerBackgroundColor", value)
                    end,
                    disabled = unitConfig.showAlternativePowerBar ~= true or altPowerBackgroundEnabled == false,
                })
            else
                AddCheckBox(altPowerSection, L["OPTION_SHOW_BACKGROUND"] or "Show Background", altPowerBackgroundEnabled, function(value)
                    SetUnitField("alternativePowerBackground", value and true or false, altPowerSection)
                end, unitConfig.showAlternativePowerBar ~= true)

                AddColorPicker(altPowerSection, L["OPTION_BACKGROUND_COLOR"] or "Background Color", unitConfig.alternativePowerBackgroundColor or unitConfig.powerBackgroundColor, true, function(value)
                    SetUnitField("alternativePowerBackgroundColor", value)
                end, unitConfig.showAlternativePowerBar ~= true or altPowerBackgroundEnabled == false)
            end
        end
    end
    local function BuildClassPowerSectionContent(classPowerSection)
        if not classPowerSection or selectedUnit ~= "player" then
            return
        end

        local usePropertyGroups = IsScopedClassPowerBarObjectMode()
        local rootSection = classPowerSection
        local generalSection = classPowerSection
        local appearanceSection = classPowerSection
        local geometrySection = classPowerSection
        if usePropertyGroups then
            generalSection = AddObjectPropertyGroup(classPowerSection, L["SECTION_GENERAL"] or "General", false)
            appearanceSection = AddObjectPropertyGroup(classPowerSection, L["SECTION_APPEARANCE"] or "Appearance", true)
            geometrySection = AddObjectPropertyGroup(classPowerSection, L["SECTION_GEOMETRY"] or "Geometry", true)
        end

        AddCheckBox(generalSection, L["OPTION_SHOW_CLASS_POWER_BAR"] or "Show Class Power Bar", unitConfig.showClassPowerBar == true, function(value)
            SetUnitField("showClassPowerBar", value and true or false, rootSection)
        end)

        local classPowerTextureValue = unitConfig.classPowerBarTexture or unitConfig.powerBarTexture
        local classPowerTextureOptions = BuildStatusBarTextureOptions(classPowerTextureValue)
        local classPowerTextureDropdown
        local function SetClassPowerBarTexture(value)
            local result = SetUnitField("classPowerBarTexture", value)
            if not (result and result.ok == false) then
                SyncDropdownToStoredValue(classPowerTextureDropdown, unitConfig.classPowerBarTexture or unitConfig.powerBarTexture)
            end
            return result
        end
        if usePropertyGroups then
            AddPropertyLabel(appearanceSection, L["OPTION_TEXTURE"] or L["OPTION_BAR_TEXTURE"] or "Texture")
            classPowerTextureDropdown = AddDropdownBrowseRow(appearanceSection, {
                list = classPowerTextureOptions,
                value = classPowerTextureOptions.value,
                onChanged = SetClassPowerBarTexture,
                disabled = unitConfig.showClassPowerBar ~= true,
            }, function()
                OpenMediaBrowserForField({
                    mediaType = MEDIA_TYPE_STATUSBAR,
                    currentValue = function()
                        return unitConfig.classPowerBarTexture or unitConfig.powerBarTexture
                    end,
                    fallbackReference = DEFAULT_STATUSBAR_REFERENCE,
                    title = L["MEDIA_LIBRARY_BROWSE_STATUSBAR_TITLE"] or "Choose Bar Texture",
                    onApply = SetClassPowerBarTexture,
                })
            end, unitConfig.showClassPowerBar ~= true)
        else
            classPowerTextureDropdown = AddDropdown(classPowerSection, L["OPTION_BAR_TEXTURE"] or "Bar Texture", classPowerTextureOptions, classPowerTextureOptions.value, SetClassPowerBarTexture, unitConfig.showClassPowerBar ~= true)
            AddMediaBrowserForField(classPowerSection, MEDIA_TYPE_STATUSBAR, function()
                return unitConfig.classPowerBarTexture or unitConfig.powerBarTexture
            end, DEFAULT_STATUSBAR_REFERENCE, L["MEDIA_LIBRARY_BROWSE_STATUSBAR_TITLE"] or "Choose Bar Texture", unitConfig.showClassPowerBar ~= true, SetClassPowerBarTexture)
        end

        AddColorPicker(appearanceSection, L["OPTION_COLOR"] or "Color", unitConfig.classPowerColor or unitConfig.powerColor, true, function(value)
            SetUnitField("classPowerColor", value)
        end, unitConfig.showClassPowerBar ~= true)

        AddColorPicker(appearanceSection, L["OPTION_BACKGROUND_COLOR"] or "Background Color", unitConfig.classPowerBackgroundColor or unitConfig.powerBackgroundColor, true, function(value)
            SetUnitField("classPowerBackgroundColor", value)
        end, unitConfig.showClassPowerBar ~= true)

        AddSlider(geometrySection, L["OPTION_CLASS_POWER_BAR_HEIGHT"] or "Class Power Height", 4, 30, 1, tonumber(unitConfig.classPowerBarHeight) or 12, function(value)
            SetUnitField("classPowerBarHeight", math.floor((value or 0) + 0.5))
        end, unitConfig.showClassPowerBar ~= true)

        if isExpert then
            AddSlider(geometrySection, L["OPTION_CLASS_POWER_BAR_WIDTH"] or "Class Power Width", 40, 260, 1, tonumber(unitConfig.classPowerBarWidth) or 100, function(value)
                SetUnitField("classPowerBarWidth", math.floor((value or 0) + 0.5))
            end, unitConfig.showClassPowerBar ~= true)

            AddSlider(geometrySection, L["OPTION_CLASS_POWER_BAR_SPACING"] or "Class Power Spacing", 0, 20, 1, tonumber(unitConfig.classPowerBarSpacing) or 2, function(value)
                SetUnitField("classPowerBarSpacing", math.floor((value or 0) + 0.5))
            end, unitConfig.showClassPowerBar ~= true)

            local classPowerAnchorTargetLabel = usePropertyGroups
                and (L["OPTION_ANCHOR_TARGET"] or "Anchor Target")
                or (L["OPTION_ANCHOR_TO_TARGET"] or "Anchor To Element")
            AddDropdown(geometrySection, classPowerAnchorTargetLabel, classPowerAnchorTargetList, unitConfig.classPowerBarAnchorTo or "HealthBar", function(value)
                SetUnitField("classPowerBarAnchorTo", value)
            end, unitConfig.showClassPowerBar ~= true)

            if usePropertyGroups then
                AddPointPairRow(geometrySection, {
                    list = barAnchorList,
                    value = unitConfig.classPowerBarPoint or "BOTTOMRIGHT",
                    onChanged = function(value)
                        SetUnitField("classPowerBarPoint", value)
                    end,
                    disabled = unitConfig.showClassPowerBar ~= true,
                }, {
                    list = barAnchorList,
                    value = unitConfig.classPowerBarRelativePoint or "BOTTOMRIGHT",
                    onChanged = function(value)
                        SetUnitField("classPowerBarRelativePoint", value)
                    end,
                    disabled = unitConfig.showClassPowerBar ~= true,
                })
            else
                AddDropdown(classPowerSection, L["OPTION_ANCHOR_FROM"] or "Anchor From", barAnchorList, unitConfig.classPowerBarPoint or "BOTTOMRIGHT", function(value)
                    SetUnitField("classPowerBarPoint", value)
                end, unitConfig.showClassPowerBar ~= true)

                AddDropdown(classPowerSection, L["OPTION_ANCHOR_TO"] or "Anchor To", barAnchorList, unitConfig.classPowerBarRelativePoint or "BOTTOMRIGHT", function(value)
                    SetUnitField("classPowerBarRelativePoint", value)
                end, unitConfig.showClassPowerBar ~= true)
            end

            local offsetXLabel = usePropertyGroups and (L["OPTION_OFFSET_X"] or "Offset X") or (L["OPTION_X_OFFSET"] or "X Offset")
            local offsetYLabel = usePropertyGroups and (L["OPTION_OFFSET_Y"] or "Offset Y") or (L["OPTION_Y_OFFSET"] or "Y Offset")
            AddSlider(geometrySection, offsetXLabel, -200, 200, 1, tonumber(unitConfig.classPowerBarOffsetX) or -5, function(value)
                SetUnitField("classPowerBarOffsetX", math.floor((value or 0) + 0.5))
            end, unitConfig.showClassPowerBar ~= true)

            AddSlider(geometrySection, offsetYLabel, -200, 200, 1, tonumber(unitConfig.classPowerBarOffsetY) or 5, function(value)
                SetUnitField("classPowerBarOffsetY", math.floor((value or 0) + 0.5))
            end, unitConfig.showClassPowerBar ~= true)
        end
    end

    if selectedUnit == "player" then
        if IsScopedAlternativePowerBarObjectMode() then
            AddScopedObjectInspectorBody("alt_power", L["BAR_ALT_POWER"] or "Alternative Power Bar", BuildAltPowerSectionContent)
        else
            AddScopedInspectorSection("alt_power", L["BAR_ALT_POWER"] or "Alt Power", true, {
                localContentBuilder = BuildAltPowerSectionContent,
                layoutRefresh = RefreshInspectorLayout,
            })
        end

        if IsScopedClassPowerBarObjectMode() then
            AddScopedObjectInspectorBody("class_power", L["BAR_CLASS_POWER"] or "Class Power Bar", BuildClassPowerSectionContent)
        else
            AddScopedInspectorSection("class_power", L["BAR_CLASS_POWER"] or "Class Power", true, {
                localContentBuilder = BuildClassPowerSectionContent,
                layoutRefresh = RefreshInspectorLayout,
            })
        end
    end

    local function BuildCastSectionContent(castSection)
        if not castSection then
            return
        end

        local usePropertyGroups = IsScopedCastBarObjectMode()
        local generalSection = castSection
        local appearanceSection = castSection
        local geometrySection = castSection
        if usePropertyGroups then
            generalSection = AddObjectPropertyGroup(castSection, L["SECTION_GENERAL"] or "General", false)
            appearanceSection = AddObjectPropertyGroup(castSection, L["SECTION_APPEARANCE"] or "Appearance", true)
            if isExpert then
                geometrySection = AddObjectPropertyGroup(castSection, L["SECTION_GEOMETRY"] or "Geometry", true)
            end
        end

        AddCheckBox(generalSection, L["OPTION_SHOW_CAST_BAR"] or "Show Cast Bar", unitConfig.showCastBar ~= false, function(value)
            SetUnitField("showCastBar", value and true or false, castSection)
        end)

        AddCheckBox(generalSection, L["OPTION_SHOW_CAST_BAR_ICON"] or "Show Cast Bar Icon", unitConfig.showCastBarIcon ~= false, function(value)
            SetUnitField("showCastBarIcon", value and true or false)
        end, unitConfig.showCastBar == false)

        AddColorPicker(appearanceSection, L["OPTION_CAST_BAR_COLOR"] or "Cast Bar Color", unitConfig.castBarColor, true, function(value)
            SetUnitField("castBarColor", value)
        end, unitConfig.showCastBar == false)

        if isExpert then
            local castTextureOptions = BuildStatusBarTextureOptions(unitConfig.castBarTexture)
            local castTextureDropdown
            local function SetCastBarTexture(value)
                local result = SetUnitField("castBarTexture", value)
                if not (result and result.ok == false) then
                    SyncDropdownToStoredValue(castTextureDropdown, unitConfig.castBarTexture)
                end
                return result
            end
            if usePropertyGroups then
                AddPropertyLabel(appearanceSection, L["OPTION_TEXTURE"] or L["OPTION_BAR_TEXTURE"] or "Texture")
                castTextureDropdown = AddDropdownBrowseRow(appearanceSection, {
                    list = castTextureOptions,
                    value = castTextureOptions.value,
                    onChanged = SetCastBarTexture,
                }, function()
                    OpenMediaBrowserForField({
                        mediaType = MEDIA_TYPE_STATUSBAR,
                        currentValue = function()
                            return unitConfig.castBarTexture
                        end,
                        fallbackReference = DEFAULT_STATUSBAR_REFERENCE,
                        title = L["MEDIA_LIBRARY_BROWSE_STATUSBAR_TITLE"] or "Choose Bar Texture",
                        onApply = SetCastBarTexture,
                    })
                end, unitConfig.showCastBar == false)
            else
                castTextureDropdown = AddDropdown(castSection, L["OPTION_BAR_TEXTURE"] or "Bar Texture", castTextureOptions, castTextureOptions.value, SetCastBarTexture, unitConfig.showCastBar == false)
                AddMediaBrowserForField(castSection, MEDIA_TYPE_STATUSBAR, function()
                    return unitConfig.castBarTexture
                end, DEFAULT_STATUSBAR_REFERENCE, L["MEDIA_LIBRARY_BROWSE_STATUSBAR_TITLE"] or "Choose Bar Texture", unitConfig.showCastBar == false, SetCastBarTexture)
            end

            AddSlider(geometrySection, L["OPTION_CAST_BAR_HEIGHT"] or "Cast Bar Height", 4, 30, 1, tonumber(unitConfig.castBarHeight) or 20, function(value)
                SetUnitField("castBarHeight", math.floor((value or 0) + 0.5))
            end, unitConfig.showCastBar == false)
        end
    end

    if IsScopedCastBarObjectMode() then
        AddScopedObjectInspectorBody("cast", L["BAR_CAST"] or "Cast Bar", BuildCastSectionContent)
    else
        AddScopedInspectorSection("cast", L["BAR_CAST"] or "Cast Bar", true, {
            localContentBuilder = BuildCastSectionContent,
            layoutRefresh = RefreshInspectorLayout,
        })
    end

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

    AddScopedInspectorSection("visibility", L["EDITOR_SECTION_VISIBILITY"] or "Visibility", true, {
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
        AddScopedInspectorSection("positioning", L["EDITOR_POSITIONING"] or "Positioning", true, {
            localContentBuilder = BuildPositioningSectionContent,
            layoutRefresh = RefreshInspectorLayout,
        })

        AddScopedInspectorSection("cast_position", L["EDITOR_SECTION_CAST_POSITION"] or "Cast Bar Position", true, {
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
                local ok = type(ObjectSelection.SelectObject) == "function"
                    and ObjectSelection.SelectObject({
                        kind = "text",
                        unit = selectedUnit,
                        textKey = value,
                    })
                if ok == true then
                    RebuildLocalSection(textSection)
                    return
                end
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

            local changeTemplateButton = AceGUI:Create("Button")
            if FormWidgets.ResetInspectorButtonState then
                FormWidgets.ResetInspectorButtonState(changeTemplateButton)
            end
            changeTemplateButton:SetText(L["EDITOR_CHANGE_TEXT_TEMPLATE"] or "Change Text...")
            changeTemplateButton:SetFullWidth(false)
            changeTemplateButton:SetWidth(142)
            changeTemplateButton:SetCallback("OnClick", function()
                local library = ns.GUI and ns.GUI.Editor and ns.GUI.Editor.TextTemplateLibraryWindow or nil
                if library and type(library.Open) == "function" then
                    library.Open({
                        mode = "change",
                        unit = selectedUnit,
                        textKey = selectedTextId,
                        initialTemplateName = type(textConfig.templateName) == "string" and textConfig.templateName or nil,
                    })
                end
            end)
            if FormWidgets.ApplyModalActionButtonVisual then
                FormWidgets.ApplyModalActionButtonVisual(changeTemplateButton, "utility")
            end
            textSection:AddChild(changeTemplateButton)

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
            local fontSizeSlider
            fontSizeSlider = AddSlider(textSection, L["OPTION_FONT_SIZE"] or "Font Size", 6, 32, 1, tonumber(textConfig.fontSize) or 12, function(value)
                if activeTextFontSizeControl
                    and activeTextFontSizeControl.widget == fontSizeSlider
                    and activeTextFontSizeControl.suppress == true
                then
                    return
                end
                SetTextFontSize(selectedTextId, value)
            end, textConfig.enabled == false, "text_font_size")
            RegisterActiveTextFontSizeControl(state and state.selectedUnit, selectedTextId, fontSizeSlider)

            AddColorPicker(textSection, L["OPTION_COLOR"] or "Color", textConfig.color, true, function(value)
                SetTextField(selectedTextId, "color", value)
            end, textConfig.enabled == false, "text_color")
        else
            local fontOptions = BuildFontOptions(textConfig.font)
            local fontDropdown
            local function SetTextFont(value)
                local result = SetTextField(selectedTextId, "font", value)
                if not (result and result.ok == false) then
                    SyncDropdownToStoredValue(fontDropdown, textConfig.font)
                end
                return result
            end
            fontDropdown = AddDropdown(textSection, L["OPTION_FONT"] or "Font", fontOptions, fontOptions.value, SetTextFont, textConfig.enabled == false, "text_font")
            AddMediaBrowserForField(textSection, MEDIA_TYPE_FONT, function()
                return textConfig.font
            end, DEFAULT_FONT_REFERENCE, L["MEDIA_LIBRARY_BROWSE_FONT_TITLE"] or "Choose Font", textConfig.enabled == false, SetTextFont)

            AddDropdown(textSection, L["OPTION_FONT_STYLE"] or "Font Style", fontStyleList, textConfig.fontStyle or "NONE", function(value)
                SetTextField(selectedTextId, "fontStyle", value)
            end, textConfig.enabled == false, "text_font_style")

            local fontSizeSlider
            fontSizeSlider = AddSlider(textSection, L["OPTION_FONT_SIZE"] or "Font Size", 6, 32, 1, tonumber(textConfig.fontSize) or 12, function(value)
                if activeTextFontSizeControl
                    and activeTextFontSizeControl.widget == fontSizeSlider
                    and activeTextFontSizeControl.suppress == true
                then
                    return
                end
                SetTextFontSize(selectedTextId, value)
            end, textConfig.enabled == false, "text_font_size")
            RegisterActiveTextFontSizeControl(state and state.selectedUnit, selectedTextId, fontSizeSlider)

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

            if type(InspectorMutations.AssignTextStateTemplate) == "function"
                and type(InspectorMutations.UnassignTextStateTemplate) == "function"
            then
                AddSpacer(textSection, 6)
                local stateTemplateTitle = AceGUI:Create("Label")
                stateTemplateTitle:SetFullWidth(true)
                stateTemplateTitle:SetText(L["TEXT_STATE_TEMPLATES"] or "State Templates")
                if stateTemplateTitle.label and stateTemplateTitle.label.SetFont then
                    stateTemplateTitle.label:SetFont(STANDARD_TEXT_FONT, 11, "")
                    stateTemplateTitle.label:SetTextColor(0.68, 0.70, 0.75, 1)
                end
                textSection:AddChild(stateTemplateTitle)

                local stateTemplates = type(textConfig.stateTemplates) == "table" and textConfig.stateTemplates or nil
                local deadTemplateOptions = BuildTextStateTemplateOptions(stateTemplates and stateTemplates.dead or nil)
                local deadTemplateDropdown
                deadTemplateDropdown = AddDropdown(textSection, L["TEXT_DEAD_TEMPLATE"] or "Dead Template", deadTemplateOptions, deadTemplateOptions.value, function(value)
                    SetTextStateTemplate(selectedTextId, "dead", value, textSection, deadTemplateDropdown)
                end, textConfig.enabled == false, "text_dead_template")

                local ghostTemplateOptions = BuildTextStateTemplateOptions(stateTemplates and stateTemplates.ghost or nil)
                local ghostTemplateDropdown
                ghostTemplateDropdown = AddDropdown(textSection, L["TEXT_GHOST_TEMPLATE"] or "Ghost Template", ghostTemplateOptions, ghostTemplateOptions.value, function(value)
                    SetTextStateTemplate(selectedTextId, "ghost", value, textSection, ghostTemplateDropdown)
                end, textConfig.enabled == false, "text_ghost_template")
            end
        end

        if IsSelectedTextObject(selectedUnit, selectedTextId) then
            AddSpacer(textSection, 10)
            local deleteTextButton = FormWidgets.CreateActionButton
                and FormWidgets.CreateActionButton(L["EDITOR_DELETE_TEXT_BUTTON"] or "Delete Text", "danger", 128, false)
                or AceGUI:Create("Button")
            deleteTextButton:SetText(L["EDITOR_DELETE_TEXT_BUTTON"] or "Delete Text")
            deleteTextButton:SetWidth(128)
            deleteTextButton:SetFullWidth(false)
            if FormWidgets.ApplyModalActionButtonVisual then
                FormWidgets.ApplyModalActionButtonVisual(deleteTextButton, "danger")
            end
            deleteTextButton:SetCallback("OnClick", function()
                OpenDeleteTextInstanceConfirmDialog(selectedUnit, selectedTextId)
            end)
            textSection:AddChild(deleteTextButton)
        end
    end

    if select(2, ResolveTextContext()) then
        AddScopedInspectorSection("texts", L["EDITOR_SECTION_TEXT_ELEMENTS"] or "Text Elements", true, {
            localContentBuilder = BuildTextSectionContent,
            layoutRefresh = RefreshInspectorLayout,
        })
    end

    local function BuildIndicatorSectionContent(indicatorSection)
        local selectedIndicatorKey, indicatorMeta, indicatorConfig, _, currentIndicatorList = ResolveIndicatorContext()
        if not indicatorSection or type(indicatorConfig) ~= "table" or type(indicatorMeta) ~= "table" then
            return
        end

        local disableActionAdded = false
        local function DisableSelectedIndicator()
            local result = SetIndicatorField(selectedIndicatorKey, "enabled", false, indicatorSection)
            if result and result.ok == false then
                return result
            end
            SelectUnitRoot(selectedUnit)
            NotifySidebarChanged("indicators")
            return result
        end

        local function AddDisableIndicatorAction()
            if disableActionAdded or not IsSelectedIndicatorObject(selectedUnit, selectedIndicatorKey) then
                return
            end
            disableActionAdded = true
            AddSpacer(indicatorSection, 8)
            local disableButton = FormWidgets.CreateActionButton
                and FormWidgets.CreateActionButton(L["EDITOR_DISABLE_INDICATOR_BUTTON"] or "Disable Indicator", "danger", 148, false)
                or AceGUI:Create("Button")
            disableButton:SetText(L["EDITOR_DISABLE_INDICATOR_BUTTON"] or "Disable Indicator")
            disableButton:SetWidth(148)
            disableButton:SetFullWidth(false)
            disableButton:SetCallback("OnClick", DisableSelectedIndicator)
            if FormWidgets.ApplyModalActionButtonVisual then
                FormWidgets.ApplyModalActionButtonVisual(disableButton, "danger")
            elseif FormWidgets.StyleActionButton then
                FormWidgets.StyleActionButton(disableButton, "danger")
            end
            indicatorSection:AddChild(disableButton)
        end

        AddDropdown(indicatorSection, L["EDITOR_OPTION_INDICATOR"] or "Indicator", currentIndicatorList, selectedIndicatorKey, function(value)
            local ok = type(ObjectSelection.SelectObject) == "function"
                and ObjectSelection.SelectObject({
                    kind = "indicator",
                    unit = selectedUnit,
                    indicatorKey = value,
                })
            if ok == true then
                RebuildLocalSection(indicatorSection)
                return
            end
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
            AddDisableIndicatorAction()
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
            AddDisableIndicatorAction()
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
            AddDisableIndicatorAction()
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
            AddDisableIndicatorAction()
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

        AddDisableIndicatorAction()
    end

    do
        local _, indicatorMeta, indicatorConfig = ResolveIndicatorContext()
        if indicatorConfig and indicatorMeta then
            AddScopedInspectorSection("indicators", L["EDITOR_SECTION_INDICATORS"] or "Indicators", true, {
                localContentBuilder = BuildIndicatorSectionContent,
                layoutRefresh = RefreshInspectorLayout,
            })
        end
    end

    local function BuildDecorationSectionContent(decorationSection)
        if not decorationSection then
            return
        end

        local selectedDecorationId, decorationConfig, decorations = ResolveSelectedDecoration(inspectorContext, unitConfig)
        local decorationSelectorOptions = BuildDecorationSelectorOptions(decorations)
        local function RebuildDecorationSection()
            NotifyConfigChangedAndRebuildSection(decorationSection, "decoration")
        end

        local function DeleteDecoration()
            if type(InspectorMutations.DeleteDecoration) ~= "function" or not selectedDecorationId then
                return nil
            end
            local result = InspectorMutations.DeleteDecoration(inspectorContext, selectedDecorationId)
            if result and result.ok == false then
                ReportMutationError(result)
                return result
            end
            if result and result.ok and result.changed then
                state.selectedDecorationId = nil
                SelectUnitRoot(selectedUnit)
                NotifySidebarChanged("decoration")
            end
            return result
        end

        local function OpenDeleteDecorationConfirmDialog()
            if not selectedDecorationId or type(InspectorMutations.DeleteDecoration) ~= "function" then
                return
            end
            if not (FormWidgets and type(FormWidgets.CreateCompactFormDialog) == "function") then
                DeleteDecoration()
                return
            end

            CloseDeleteDecorationDialog()
            local dialog = FormWidgets.CreateCompactFormDialog({
                title = L["EDITOR_DELETE_DECORATION_CONFIRM_TITLE"] or "Delete Decoration?",
                description = L["EDITOR_DELETE_DECORATION_CONFIRM_DESCRIPTION"] or "This removes the selected decoration from this unit frame.",
                width = 420,
                height = 204,
                bodyHeight = 34,
            })
            if not dialog then
                return
            end

            dialog:SetActions({
                secondary = {
                    text = L["INFO_COMMON_CANCEL"] or "Cancel",
                    role = "utility",
                    width = 104,
                    onClick = function()
                        CloseDeleteDecorationDialog()
                    end,
                },
                primary = {
                    text = L["EDITOR_DELETE_DECORATION_CONFIRM_BUTTON"] or "Delete",
                    role = "danger",
                    width = 104,
                    onClick = function(activeDialog)
                        local result = DeleteDecoration()
                        if result and result.ok == false then
                            if activeDialog and activeDialog.SetStatus then
                                activeDialog:SetStatus(ResolveMutationErrorMessage(result))
                            end
                            return
                        end
                        CloseDeleteDecorationDialog()
                    end,
                },
            })

            dialog.window:SetCallback("OnClose", function()
                if deleteDecorationDialog == dialog then
                    deleteDecorationDialog = nil
                end
            end)
            deleteDecorationDialog = dialog
            dialog:Show()
        end

        if #decorations > 0 then
            local selectorRow = AceGUI:Create("SimpleGroup")
            selectorRow:SetFullWidth(true)
            selectorRow:SetLayout("Flow")
            decorationSection:AddChild(selectorRow)

            local decorationSelector = AceGUI:Create("Dropdown")
            decorationSelector:SetFullWidth(true)
            decorationSelector:SetLabel("")
            decorationSelector:SetList(decorationSelectorOptions.values, decorationSelectorOptions.order)
            decorationSelector:SetValue(selectedDecorationId)
            decorationSelector:SetCallback("OnValueChanged", function(_, _, value)
                local ok = type(ObjectSelection.SelectObject) == "function"
                    and ObjectSelection.SelectObject({
                        kind = "decoration",
                        unit = selectedUnit,
                        decorationId = value,
                    })
                if ok ~= true then
                    state.selectedDecorationId = value
                end
                RebuildDecorationSection()
            end)
            if FormWidgets and FormWidgets.StyleDropdown then
                FormWidgets.StyleDropdown(decorationSelector, "editor_inset")
            end
            selectorRow:AddChild(decorationSelector)
        else
            local emptyLabel = AceGUI:Create("Label")
            emptyLabel:SetFullWidth(true)
            emptyLabel:SetText(L["OPTION_DECORATION_EMPTY"] or "No decorations yet.")
            decorationSection:AddChild(emptyLabel)
            return
        end

        if type(decorationConfig) ~= "table" then
            local emptyLabel = AceGUI:Create("Label")
            emptyLabel:SetFullWidth(true)
            emptyLabel:SetText(L["OPTION_DECORATION_EMPTY"] or "No decorations yet.")
            decorationSection:AddChild(emptyLabel)
            return
        end

        local disabled = decorationConfig.enabled == false
        local textureOptions = BuildDecorationTextureOptions(decorationConfig.texture)
        local decorationTextureDropdown

        AddCheckBox(decorationSection, L["OPTION_DECORATION_ENABLED"] or "Enable Decoration", decorationConfig.enabled == true, function(value)
            SetDecorationField("enabled", value and true or false, decorationSection)
        end, nil, "decoration_enabled")

        local function SetDecorationTexture(value)
            local result = SetDecorationField("texture", value or "")
            if not (result and result.ok == false) then
                SyncDropdownToStoredValue(decorationTextureDropdown, result and result.newValue or value or "")
            end
            return result
        end

        decorationTextureDropdown = AddDropdown(decorationSection, L["OPTION_TEXTURE"] or "Texture", textureOptions, textureOptions.value, SetDecorationTexture, disabled, "decoration_texture")
        AddMediaBrowserForField(decorationSection, MEDIA_TYPE_DECORATION, function()
            return decorationConfig.texture
        end, DEFAULT_DECORATION_REFERENCE, L["MEDIA_LIBRARY_BROWSE_DECORATION_TITLE"] or "Choose Decoration Texture", disabled, SetDecorationTexture)

        AddDropdown(decorationSection, L["OPTION_ANCHOR_TO_TARGET"] or "Anchor To Element", decorationTargetList, decorationConfig.target or "FRAME", function(value)
            SetDecorationField("target", value)
        end, disabled, "decoration_target")

        AddSlider(decorationSection, L["OPTION_WIDTH"] or "Width", 1, 512, 1, tonumber(decorationConfig.width) or 64, function(value)
            SetDecorationField("width", math.floor((value or 0) + 0.5))
        end, disabled, "decoration_width")

        AddSlider(decorationSection, L["OPTION_HEIGHT"] or "Height", 1, 512, 1, tonumber(decorationConfig.height) or 64, function(value)
            SetDecorationField("height", math.floor((value or 0) + 0.5))
        end, disabled, "decoration_height")

        AddDropdown(decorationSection, L["OPTION_ANCHOR_FROM"] or "Anchor From", portraitAnchorPointList, decorationConfig.point or "CENTER", function(value)
            SetDecorationField("point", value)
        end, disabled, "decoration_point")

        AddDropdown(decorationSection, L["OPTION_ANCHOR_TO"] or "Anchor To", portraitAnchorPointList, decorationConfig.relativePoint or "CENTER", function(value)
            SetDecorationField("relativePoint", value)
        end, disabled, "decoration_relative_point")

        AddSlider(decorationSection, L["OPTION_X_OFFSET"] or "X Offset", -500, 500, 1, tonumber(decorationConfig.offsetX) or 0, function(value)
            SetDecorationField("offsetX", math.floor((value or 0) + 0.5))
        end, disabled, "decoration_offset_x")

        AddSlider(decorationSection, L["OPTION_Y_OFFSET"] or "Y Offset", -500, 500, 1, tonumber(decorationConfig.offsetY) or 0, function(value)
            SetDecorationField("offsetY", math.floor((value or 0) + 0.5))
        end, disabled, "decoration_offset_y")

        AddSlider(decorationSection, L["OPTION_ALPHA"] or "Alpha", 0, 1, 0.01, tonumber(decorationConfig.alpha) or 1, function(value)
            SetDecorationField("alpha", tonumber(string.format("%.2f", value or 1)) or 1)
        end, disabled, "decoration_alpha")

        AddDropdown(decorationSection, L["OPTION_CONDITION"] or "Condition", decorationConditionList, decorationConfig.condition or "ALWAYS", function(value)
            SetDecorationField("condition", value)
        end, disabled, "decoration_condition")

        AddSpacer(decorationSection, 8)
        local deleteButton = AceGUI:Create("Button")
        if FormWidgets and FormWidgets.ResetInspectorButtonState then
            FormWidgets.ResetInspectorButtonState(deleteButton)
        end
        deleteButton:SetText(L["OPTION_DECORATION_DELETE"] or "Delete Decoration")
        deleteButton:SetFullWidth(true)
        deleteButton:SetDisabled(not decorationConfig)
        deleteButton:SetCallback("OnClick", OpenDeleteDecorationConfirmDialog)
        if FormWidgets and FormWidgets.ApplyModalActionButtonVisual then
            FormWidgets.ApplyModalActionButtonVisual(deleteButton, "danger")
        elseif FormWidgets and FormWidgets.StyleActionButton then
            FormWidgets.StyleActionButton(deleteButton, "danger")
        end
        decorationSection:AddChild(deleteButton)
    end

    AddScopedInspectorSection("decoration", L["EDITOR_SECTION_DECORATION"] or "Decoration", true, {
        localContentBuilder = BuildDecorationSectionContent,
        layoutRefresh = RefreshInspectorLayout,
    })

    local function BuildAuraSectionContent(auraSection)
        local selectedAuraKey, auraConfig, _, currentAuraList = ResolveAuraContext()
        if not auraSection or type(auraConfig) ~= "table" then
            return
        end

        AddDropdown(auraSection, L["EDITOR_OPTION_AURA_BLOCK"] or "Aura Block", currentAuraList, selectedAuraKey, function(value)
            local ok = type(ObjectSelection.SelectObject) == "function"
                and ObjectSelection.SelectObject({
                    kind = "aura",
                    unit = selectedUnit,
                    auraKey = value,
                })
            if ok == true then
                RebuildLocalSection(auraSection)
                return
            end
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
        AddScopedInspectorSection("auras", L["EDITOR_SECTION_AURAS"] or "Auras", true, {
            localContentBuilder = BuildAuraSectionContent,
            layoutRefresh = RefreshInspectorLayout,
        })
    end

end

function InspectorController.BuildContext(container, state, options)
    local contextOptions = {}
    for key, value in pairs(options or {}) do
        contextOptions[key] = value
    end
    contextOptions.buildContextOnly = true
    return InspectorController.Build(container, state, contextOptions)
end

function InspectorController.BuildProperties(container, state, options)
    local propertyOptions = {}
    for key, value in pairs(options or {}) do
        propertyOptions[key] = value
    end
    propertyOptions.buildPropertiesOnly = true
    return InspectorController.Build(container, state, propertyOptions)
end

return InspectorController

