local _, ns = ...

ns.GUI = ns.GUI or {}
ns.GUI.Editor = ns.GUI.Editor or {}

local ToolbarBinding = {}
ns.GUI.Editor.ToolbarBinding = ToolbarBinding

local PresetUI = ns.GUI.Editor and ns.GUI.Editor.PresetUI or {}
local CompositionTreeView = ns.CompositionTreeView or (ns.GUI.Editor.Composition and ns.GUI.Editor.Composition.TreeView) or {}
local Shared = ns.GUI.Editor.SidebarShared or {}

local NAV_WIDGET_IDS = {
    editorButton = { "Nav", "EDITOR" },
    profilesButton = { "Nav", "PROFILES" },
    textBuilderButton = { "Nav", "TEXT_BUILDER" },
    tagDatabaseButton = { "Nav", "TAG_DATABASE" },
}

local UNIT_WIDGET_IDS = {
    playerButton = { "Units", "PLAYER" },
    targetButton = { "Units", "TARGET" },
    targetTargetButton = { "Units", "TARGETTARGET" },
    petButton = { "Units", "PET" },
    focusButton = { "Units", "FOCUS" },
    focusTargetButton = { "Units", "FOCUSTARGET" },
    bossButton = { "Units", "BOSS" },
}

local INTERACTION_MODE_BUTTONS = {
    frame = "frameModeButton",
    text = "textModeButton",
}

local function ResolveConstantPath(root, path)
    if type(root) ~= "table" or type(path) ~= "table" then
        return nil
    end

    local value = root
    for _, key in ipairs(path) do
        if type(value) ~= "table" then
            return nil
        end
        value = value[key]
    end
    return value
end

local function T(key, fallback, deps)
    local L = deps and deps.L or {}
    return (type(key) == "string" and L[key]) or fallback or ""
end

local ResolveEditorMode

local function ResolveAddon(deps)
    return (deps and deps.ns) or ns or {}
end

local function ResolveInspectorContext()
    return ns.InspectorContext or (ns.GUI.Editor.Inspector and ns.GUI.Editor.Inspector.Context) or {}
end

local function ResolveInspectorMutations()
    return ns.InspectorMutations or (ns.GUI.Editor.Inspector and ns.GUI.Editor.Inspector.Mutations) or {}
end

local function EnsureGeneralConfig(nsRef)
    local profile = nsRef and nsRef.db and nsRef.db.profile
    if type(profile) ~= "table" then
        return nil
    end

    profile.General = type(profile.General) == "table" and profile.General or {}
    return profile.General
end

local function EnsureMinimapConfig(nsRef)
    local profile = nsRef and nsRef.db and nsRef.db.profile
    if type(profile) ~= "table" then
        return nil
    end

    profile.Minimap = type(profile.Minimap) == "table" and profile.Minimap or {}
    return profile.Minimap
end

local function NotifyGlobalChanged(options, refreshFn)
    if options and options.onGlobalChanged then
        options.onGlobalChanged()
    elseif refreshFn then
        refreshFn()
    end
end

local function IsExpertMode(deps, state)
    local nsRef = ResolveAddon(deps)
    return ResolveEditorMode(state, nsRef.db and nsRef.db.profile) == "expert"
end

function ToolbarBinding.GetGlobalOptionValue(optionId, deps)
    local nsRef = ResolveAddon(deps)
    local generalConfig = EnsureGeneralConfig(nsRef)
    if type(generalConfig) ~= "table" then
        return nil
    end

    if optionId == "hideBlizzard" then
        return generalConfig.HideBlizzardFrames == true
    elseif optionId == "showMinimapButton" then
        local minimapConfig = nsRef.db and nsRef.db.profile and nsRef.db.profile.Minimap
        return not (type(minimapConfig) == "table" and minimapConfig.hide == true)
    elseif optionId == "mouseEnabled" then
        return generalConfig.MouseEnabled ~= false
    elseif optionId == "clickthrough" then
        return generalConfig.GlobalClickThrough == true
    end

    return nil
end

function ToolbarBinding.ApplyGlobalOptionValue(optionId, value, deps, options)
    local nsRef = ResolveAddon(deps)
    local generalConfig = EnsureGeneralConfig(nsRef)
    if type(generalConfig) ~= "table" then
        return false
    end

    if optionId == "hideBlizzard" then
        generalConfig.HideBlizzardFrames = value and true or false
        if nsRef.ApplyGeneralSettings then
            nsRef:ApplyGeneralSettings()
        end
        if not generalConfig.HideBlizzardFrames and nsRef.Info then
            nsRef:Info(T("INFO_RELOAD_REQUIRED_BLIZZARD_FRAMES", nil, deps))
        end
    elseif optionId == "showMinimapButton" then
        if nsRef.SetMinimapButtonVisible then
            nsRef:SetMinimapButtonVisible(value == true)
        else
            local minimapConfig = EnsureMinimapConfig(nsRef)
            if type(minimapConfig) ~= "table" then
                return false
            end
            minimapConfig.hide = value ~= true
        end
    elseif optionId == "mouseEnabled" then
        generalConfig.MouseEnabled = value and true or false
        if nsRef.RefreshAllUnitFrames then
            nsRef:RefreshAllUnitFrames()
        end
    elseif optionId == "clickthrough" then
        generalConfig.GlobalClickThrough = value and true or false
        if nsRef.RefreshAllUnitFrames then
            nsRef:RefreshAllUnitFrames()
        end
    else
        return false
    end

    NotifyGlobalChanged(options, options and options.refreshFn)
    return true
end

function ResolveEditorMode(state, profile)
    local editorMode = ns.EditorMode or (ns.GUI and ns.GUI.Editor and ns.GUI.Editor.Mode)
    if editorMode and editorMode.Resolve then
        return editorMode.Resolve(state, profile)
    end

    return "quick"
end

local function ResolveItemText(props, deps)
    if not props then
        return ""
    end
    if props.textKey then
        return T(props.textKey, nil, deps)
    end
    return props.text or ""
end

local function ResolveLabelRole(props)
    if not props then
        return "label"
    end

    local variant = props.itemVariant
    if variant == "section_title" or variant == "section_title_large" then
        return "sectionHeader"
    end
    if variant == "group_title" then
        return "groupTitle"
    end
    if variant == "group_description" then
        return "description"
    end
    if variant == "footer_hint_muted" then
        return "muted"
    end
    if variant == "status_value" then
        return "value"
    end

    return props.role or "label"
end

local function IsCombatLocked()
    return InCombatLockdown and InCombatLockdown() == true
end

local function GetInteractionMode(nsRef)
    return nsRef
        and nsRef.GUI
        and nsRef.GUI.Editor
        and nsRef.GUI.Editor.InteractionMode
        or nil
end

local function IsInteractionModeControlDisabled(nsRef)
    return not (nsRef and nsRef.framesUnlocked == true)
        or IsCombatLocked()
        or not (nsRef.IsEditorActive and nsRef:IsEditorActive())
end

local function AttachInteractionModeTooltip(button, titleKey, fallbackTitle, deps)
    if not button or not button.frame or button.__fpInteractionModeTooltipHooked then
        return
    end

    button.__fpInteractionModeTooltipHooked = true
    button.frame:HookScript("OnEnter", function(self)
        local title = T(titleKey, fallbackTitle, deps)
        if type(title) ~= "string" or title == "" or not GameTooltip then
            return
        end

        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        if GameTooltip.ClearLines then
            GameTooltip:ClearLines()
        end
        GameTooltip:AddLine(title, 1, 1, 1, true)
        GameTooltip:AddLine(T("EDITOR_INTERACTION_MODE_TOOLTIP_SHIFT", "Press Shift to toggle modes.", deps), 0.80, 0.76, 0.66, true)
        GameTooltip:Show()
    end)
    button.frame:HookScript("OnLeave", function()
        if GameTooltip and GameTooltip.Hide then
            GameTooltip:Hide()
        end
    end)
end

local function IterateWidgetMap(widgetMap, callback)
    if type(widgetMap) ~= "table" or type(callback) ~= "function" then
        return
    end
    for widgetId, constantPath in pairs(widgetMap) do
        callback(widgetId, constantPath)
    end
end

local function CreateItemWidget(props, deps)
    if not props or not props.widget then
        return nil
    end

    local AceGUI = deps and deps.AceGUI
    local CreateBodyText = deps and deps.CreateBodyText
    local CreateActionButton = deps and deps.CreateActionButton
    local StyleCheckBox = deps and deps.StyleCheckBox
    local StyleDropdown = deps and deps.StyleDropdown
    local ResolveItemColor = deps and deps.ResolveItemColor

    if props.widget == "label" then
        local label = CreateBodyText and CreateBodyText(
            ResolveItemText(props, deps),
            ResolveLabelRole(props),
            props.size or 12,
            ResolveItemColor and ResolveItemColor(props.colorKey),
            props.width,
            props.fullWidth
        )
        if props.justifyH and label and label.label and label.label.SetJustifyH then
            label.label:SetJustifyH(props.justifyH)
        end
        return label
    end

    if props.widget == "button" then
        return CreateActionButton and CreateActionButton(ResolveItemText(props, deps), props.buttonVariant, props.width, props.fullWidth)
    end

    if props.widget == "checkbox" and AceGUI then
        local checkbox = AceGUI:Create("CheckBox")
        if type(props.width) == "number" then
            checkbox:SetFullWidth(false)
            checkbox:SetWidth(props.width)
        elseif props.fullWidth ~= false then
            checkbox:SetFullWidth(true)
        end
        checkbox:SetLabel(ResolveItemText(props, deps))
        checkbox:SetValue(props.checked and true or false)
        if StyleCheckBox then
            StyleCheckBox(checkbox, false)
        end
        return checkbox
    end

    if props.widget == "dropdown" and AceGUI then
        local dropdown = AceGUI:Create("Dropdown")
        dropdown:SetLabel(T(props.labelKey, nil, deps))
        if props.fullWidth ~= false then
            dropdown:SetFullWidth(true)
        end
        if StyleDropdown then
            StyleDropdown(dropdown, props.fieldVariant or "accented")
        end
        return dropdown
    end

    if props.widget == "compositionTree" and AceGUI then
        local treeHost = AceGUI:Create("SimpleGroup")
        treeHost:SetFullWidth(true)
        treeHost:SetLayout("Flow")
        return treeHost
    end

    return nil
end

local function BuildInspectorContextForToolbar(state, deps)
    local nsRef = ResolveAddon(deps)
    local InspectorContext = ResolveInspectorContext()
    local profile = nsRef.db and nsRef.db.profile or nil
    local units = profile and profile.Units or nil
    local unitKey = state and state.selectedUnit or nil
    local unitConfig = type(units) == "table" and units[unitKey] or nil

    if type(unitConfig) ~= "table" then
        return nil
    end

    if type(InspectorContext.Create) == "function" then
        return InspectorContext.Create({
            state = state,
            profile = profile,
            getUnitConfig = function(key)
                return type(units) == "table" and units[key] or nil
            end,
            buildTextList = Shared.BuildTextList,
            getFirstTextId = Shared.GetFirstTextId,
            buildIndicatorList = Shared.BuildIndicatorList,
            getFirstIndicatorKey = Shared.GetFirstIndicatorKey,
            indicatorMeta = Shared.INDICATOR_META,
            buildAuraList = Shared.BuildAuraList,
            getFirstAuraKey = Shared.GetFirstAuraKey,
        })
    end

    return {
        state = state,
        unitKey = unitKey,
        unitConfig = unitConfig,
    }
end

local function ApplyTreeToggleMutation(context, node, nextEnabled)
    local InspectorMutations = ResolveInspectorMutations()
    local target = type(node) == "table" and node.inspectorTarget or nil
    if type(target) ~= "table" then
        return { ok = false, errorCode = "invalid_target" }
    end

    local enabled = nextEnabled and true or false
    if node.type == "powerbar" then
        if type(InspectorMutations.SetUnitField) ~= "function" then
            return { ok = false, errorCode = "invalid_context" }
        end
        return InspectorMutations.SetUnitField(context, "showPowerBar", enabled)
    elseif node.type == "classPowerBar" then
        if type(InspectorMutations.SetUnitField) ~= "function" then
            return { ok = false, errorCode = "invalid_context" }
        end
        return InspectorMutations.SetUnitField(context, "showClassPowerBar", enabled)
    elseif node.type == "alternativePowerBar" then
        if type(InspectorMutations.SetUnitField) ~= "function" then
            return { ok = false, errorCode = "invalid_context" }
        end
        return InspectorMutations.SetUnitField(context, "showAlternativePowerBar", enabled)
    elseif node.type == "castbar" then
        if type(InspectorMutations.SetUnitField) ~= "function" then
            return { ok = false, errorCode = "invalid_context" }
        end
        return InspectorMutations.SetUnitField(context, "showCastBar", enabled)
    elseif node.type == "normalAbsorbBar" then
        if type(InspectorMutations.SetUnitField) ~= "function" then
            return { ok = false, errorCode = "invalid_context" }
        end
        return InspectorMutations.SetUnitField(context, "showNormalAbsorbBar", enabled)
    elseif node.type == "healingAbsorbBar" then
        if type(InspectorMutations.SetUnitField) ~= "function" then
            return { ok = false, errorCode = "invalid_context" }
        end
        return InspectorMutations.SetUnitField(context, "showHealingAbsorbBar", enabled)
    elseif node.type == "textElement" and type(target.textKey) == "string" then
        if type(InspectorMutations.SetTextField) ~= "function" then
            return { ok = false, errorCode = "invalid_context" }
        end
        return InspectorMutations.SetTextField(context, target.textKey, "enabled", enabled)
    elseif (node.type == "buffs" or node.type == "debuffs") and type(target.auraKey) == "string" then
        if type(InspectorMutations.SetAuraField) ~= "function" then
            return { ok = false, errorCode = "invalid_context" }
        end
        return InspectorMutations.SetAuraField(context, target.auraKey, "enabled", enabled)
    end

    return { ok = false, errorCode = "unsupported_target" }
end

local function RefreshTreeRuntimeAndProperties(context, deps)
    local nsRef = ResolveAddon(deps)
    local state = context and context.state or nil
    local unitKey = state and state.selectedUnit or nil

    if nsRef.RefreshUnitFrame and type(unitKey) == "string" and unitKey ~= "" then
        nsRef:RefreshUnitFrame(unitKey == "boss" and "boss" or unitKey)
    end

    local controller = nsRef.GUI and nsRef.GUI.Editor and nsRef.GUI.Editor.Controller
    if controller and type(controller.RefreshActiveProperties) == "function" then
        controller.RefreshActiveProperties()
    end
end

local function BuildCompositionTree(context, deps)
    local treeHost = context and context.widgets and context.widgets.compositionTree or nil
    if not treeHost then
        return
    end

    if treeHost.ReleaseChildren then
        treeHost:ReleaseChildren()
    end

    if type(CompositionTreeView.Build) ~= "function" then
        return
    end

    CompositionTreeView.Build(treeHost, context.state, {
        minHeight = 112,
        maxHeight = 184,
        onSelect = function(_, _, changeKind)
            local nsRef = ResolveAddon(deps)
            local controller = nsRef.GUI and nsRef.GUI.Editor and nsRef.GUI.Editor.Controller
            if changeKind == "sameUnitObject" and controller and type(controller.RefreshActiveProperties) == "function" then
                controller.RefreshActiveProperties()
                return
            end
            if context.options and type(context.options.onObjectSelectionChanged) == "function" then
                context.options.onObjectSelectionChanged(changeKind)
            elseif nsRef.GUI and nsRef.GUI.RequestRefreshOptions then
                nsRef.GUI:RequestRefreshOptions()
            end
        end,
        onToggle = function(node, nextEnabled)
            local mutationContext = BuildInspectorContextForToolbar(context.state, deps)
            if not mutationContext then
                return { ok = false, errorCode = "invalid_context" }
            end
            local result = ApplyTreeToggleMutation(mutationContext, node, nextEnabled)
            if result and result.ok and result.changed then
                RefreshTreeRuntimeAndProperties(context, deps)
            end
            return result
        end,
    })
end

local function RefreshInteractionModeControls(context, deps)
    if not context or not context.widgets then
        return
    end

    local nsRef = deps and deps.ns or {}
    local sidebarThemeHelpers = nsRef.GUI and nsRef.GUI.Editor and nsRef.GUI.Editor.EditorSidebarThemeHelpers or {}
    local SIDEBAR_VISUAL_ROLE = (nsRef.GUI and nsRef.GUI.ButtonVisualRole)
        or sidebarThemeHelpers.ButtonVisualRole
        or sidebarThemeHelpers.SIDEBAR_VISUAL_ROLE
        or {
            ACTIVE = "active",
            SECONDARY = "secondary",
        }
    local ApplySidebarButtonVisual = sidebarThemeHelpers.ApplySidebarButtonVisual or sidebarThemeHelpers.StyleSidebarButton
    local interactionMode = GetInteractionMode(nsRef)
    local isFrameMode = interactionMode and interactionMode.IsFrameMode and interactionMode.IsFrameMode() or false
    local isTextMode = interactionMode and interactionMode.IsTextMode and interactionMode.IsTextMode() or false
    local disabled = IsInteractionModeControlDisabled(nsRef)
    local frameButton = context.widgets[INTERACTION_MODE_BUTTONS.frame]
    local textButton = context.widgets[INTERACTION_MODE_BUTTONS.text]

    if frameButton then
        frameButton:SetText(T("EDITOR_INTERACTION_FRAME_MODE", "Frame", deps))
        frameButton:SetDisabled(disabled)
        if ApplySidebarButtonVisual then
            ApplySidebarButtonVisual(frameButton, isFrameMode and SIDEBAR_VISUAL_ROLE.ACTIVE or SIDEBAR_VISUAL_ROLE.SECONDARY)
        end
        AttachInteractionModeTooltip(frameButton, "EDITOR_INTERACTION_FRAME_MODE_TOOLTIP", "Edit, move and resize unit frames.", deps)
    end

    if textButton then
        textButton:SetText(T("EDITOR_INTERACTION_TEXT_MODE", "Text", deps))
        textButton:SetDisabled(disabled)
        if ApplySidebarButtonVisual then
            ApplySidebarButtonVisual(textButton, isTextMode and SIDEBAR_VISUAL_ROLE.ACTIVE or SIDEBAR_VISUAL_ROLE.SECONDARY)
        end
        AttachInteractionModeTooltip(textButton, "EDITOR_INTERACTION_TEXT_MODE_TOOLTIP", "Select, move, anchor and resize text elements.", deps)
    end
end

local function RefreshWindowState(context, deps)
    if not context or not context.widgets then
        return
    end

    context._suspendCallbacks = true

    local state = context.state or {}
    local options = context.options or {}
    local nsRef = deps and deps.ns or {}
    local C = deps and deps.C or {}
    local KM = deps and deps.KM or {}
    local StyleCheckBox = deps and deps.StyleCheckBox
    local StyleDropdown = deps and deps.StyleDropdown
    local sidebarThemeHelpers = nsRef.GUI and nsRef.GUI.Editor and nsRef.GUI.Editor.EditorSidebarThemeHelpers or {}
    local SIDEBAR_VISUAL_ROLE = (nsRef.GUI and nsRef.GUI.ButtonVisualRole)
        or sidebarThemeHelpers.ButtonVisualRole
        or sidebarThemeHelpers.SIDEBAR_VISUAL_ROLE
        or {
            ACTIVE = "active",
            SECONDARY = "secondary",
            PRIMARY_ACTION = "primary_action",
            UTILITY = "utility",
            QUIET_UTILITY = "quiet_utility",
            DANGER = "danger",
        }
    local ApplySidebarButtonVisual = sidebarThemeHelpers.ApplySidebarButtonVisual or sidebarThemeHelpers.StyleSidebarButton
    local ThemeService = (deps and deps.ThemeService) or nsRef.ThemeService or {}
    local BuilderUI = (deps and deps.BuilderUI) or (nsRef.GUI and nsRef.GUI.Helpers and nsRef.GUI.Helpers.GUIRuntimeHelpers) or {}
    local generalConfig = nsRef.db and nsRef.db.profile and nsRef.db.profile.General
    if type(generalConfig) ~= "table" then
        context._suspendCallbacks = false
        return
    end
    local presetView = PresetUI.BuildPresetViewData and PresetUI.BuildPresetViewData(state, deps, {
        includeCustom = ThemeService.HasDefaultSnapshot and ThemeService.HasDefaultSnapshot(),
    }) or {}
    local presetList = presetView.presetList or {}
    local presetOrder = presetView.presetOrder
    local selectedPresetId = presetView.selectedPresetId
    local isExpertMode = IsExpertMode(deps, state)

    local selectedPreset = presetView.selectedPreset
    local selectedIsBuiltInPreset = presetView.selectedIsBuiltInPreset
    local selectedIsCustomLayout = presetView.selectedIsCustomLayout

    local versionText = BuilderUI.GetAddonVersionText and BuilderUI.GetAddonVersionText() or "dev"
    local logoPath = "Interface\\AddOns\\FocalPoint\\Media\\icon.tga"
    local normalizedCurrent = options.currentPath or (nsRef.GUI and nsRef.GUI.selectedPath) or ResolveConstantPath(C, { "Nav", "EDITOR" })

    if context.widgets.brandLine then
        local skins = nsRef.GUI and nsRef.GUI.Skins or nil
        local addonName = T("ADDON_NAME", C.ADDON_NAME or "FocalPoint", deps)
        local brandTitle = skins and skins.GetBrandTitle and skins.GetBrandTitle(addonName) or addonName
        context.widgets.brandLine:SetText(string.format("|T%s:24:24:0:0|t  %s", logoPath, brandTitle))
    end
    if context.widgets.versionLine then
        context.widgets.versionLine:SetText(string.format("|cffd8c27a%s|r  |cff4cff88%s|r", T("INFO_VERSION", "Version", deps), versionText))
    end
    if context.widgets.toolsTitle then
        context.widgets.toolsTitle:SetText(T("EDITOR_CONTEXT_TOOLS", "Tools", deps))
    end
    if context.widgets.compositionTitle then
        context.widgets.compositionTitle:SetText(T("EDITOR_SECTION_COMPOSITION_TREE", "Composition", deps))
    end
    if context.widgets.workspaceTitle then
        context.widgets.workspaceTitle:SetText(T("EDITOR_CONTEXT_WORKSPACE", "Workspace", deps))
    end
    if context.widgets.editingTitle then
        context.widgets.editingTitle:SetText(T("EDITOR_CONTEXT_PREVIEW", "Editing", deps))
    end
    if context.widgets.presetsTitle then
        context.widgets.presetsTitle:SetText(T("EDITOR_CONTEXT_PRESET", "Presets", deps))
    end
    if context.widgets.globalTitle then
        context.widgets.globalTitle:SetText(T("EDITOR_CONTEXT_GLOBAL", "Addon", deps))
    end
    if context.widgets.footerNote then
        context.widgets.footerNote:SetText("")
    end
    if context.widgets.unitLabel then
        context.widgets.unitLabel:SetText(T("EDITOR_UNIT", "Unit", deps))
    end
    if context.widgets.workspaceTitle then
        context.widgets.workspaceTitle:SetText("")
    end

    IterateWidgetMap(NAV_WIDGET_IDS, function(widgetId, constantPath)
        local navPath = ResolveConstantPath(C, constantPath)
        local button = context.widgets[widgetId]
        if button then
            local isActivePath = normalizedCurrent == navPath
            local label = nsRef.GetLabel and nsRef.GetLabel(KM.Nav, navPath) or navPath or ""
            button:SetText(label)
            button:SetDisabled(isActivePath)
            if ApplySidebarButtonVisual then
                ApplySidebarButtonVisual(button, isActivePath and SIDEBAR_VISUAL_ROLE.ACTIVE or SIDEBAR_VISUAL_ROLE.SECONDARY)
            end
        end
    end)

    if context.widgets.closeButton then
        context.widgets.closeButton:SetText(CLOSE or "Close")
        if ApplySidebarButtonVisual then
            ApplySidebarButtonVisual(context.widgets.closeButton, SIDEBAR_VISUAL_ROLE.QUIET_UTILITY or SIDEBAR_VISUAL_ROLE.UTILITY)
        end
    end

    IterateWidgetMap(UNIT_WIDGET_IDS, function(widgetId, constantPath)
        local unitKey = ResolveConstantPath(C, constantPath)
        local button = context.widgets[widgetId]
        if button then
            button:SetText(nsRef.GetLabel and nsRef.GetLabel(KM.Units, unitKey) or unitKey or "")
            if ApplySidebarButtonVisual then
                ApplySidebarButtonVisual(button, unitKey == state.selectedUnit and SIDEBAR_VISUAL_ROLE.ACTIVE or SIDEBAR_VISUAL_ROLE.SECONDARY)
            end
        end
    end)

    if context.widgets.expertMode then
        context.widgets.expertMode:SetLabel(T("OPTION_EXPERT_MODE", "Expert Mode", deps))
        context.widgets.expertMode:SetValue(isExpertMode)
        if StyleCheckBox then
            StyleCheckBox(context.widgets.expertMode, false)
        end
    end

    if context.widgets.demoButton then
        context.widgets.demoButton:SetText((nsRef.guiTestModeEnabled and T("GUI_TEST_STOP", "Stop Test", deps)) or T("GUI_TEST_START", "Test", deps))
        if ApplySidebarButtonVisual then
            ApplySidebarButtonVisual(context.widgets.demoButton, SIDEBAR_VISUAL_ROLE.UTILITY)
        end
    end

    if context.widgets.unlockButton then
        context.widgets.unlockButton:SetText((nsRef.framesUnlocked and T("GUI_UNLOCK_STOP", "Lock Frames", deps)) or T("GUI_UNLOCK_START", "Unlock Frames", deps))
        if ApplySidebarButtonVisual then
            ApplySidebarButtonVisual(context.widgets.unlockButton, SIDEBAR_VISUAL_ROLE.PRIMARY_ACTION)
        end
    end

    RefreshInteractionModeControls(context, deps)
    BuildCompositionTree(context, deps)

    if context.widgets.editingHint then
        context.widgets.editingHint:SetText(T("EDITOR_PREVIEW_INTERACTION_HINT", nil, deps))
    end

    if context.widgets.presetsIntro then
        context.widgets.presetsIntro:SetText(T("EDITOR_PRESET_CONTEXT_HINT", nil, deps))
    end

    if context.widgets.returnToEditor and ApplySidebarButtonVisual then
        ApplySidebarButtonVisual(context.widgets.returnToEditor, SIDEBAR_VISUAL_ROLE.UTILITY)
    end

    if context.widgets.presetDropdown then
        context.widgets.presetDropdown:SetList(presetList, presetOrder)
        context.widgets.presetDropdown:SetValue(selectedPresetId)
        context.widgets.presetDropdown:SetDisabled(next(presetList) == nil)
        if StyleDropdown then
            StyleDropdown(context.widgets.presetDropdown, "editor_inset")
        end
    end

    if context.widgets.applyPreset then
        context.widgets.applyPreset:SetText(T("THEME_APPLY", T("INFO_GENERAL_THEME_APPLY", "Apply Preset", deps), deps))
        context.widgets.applyPreset:SetDisabled(not (selectedIsBuiltInPreset or selectedIsCustomLayout))
        if ApplySidebarButtonVisual then
            ApplySidebarButtonVisual(context.widgets.applyPreset, SIDEBAR_VISUAL_ROLE.PRIMARY_ACTION)
        end
    end

    if context.widgets.saveCustom then
        context.widgets.saveCustom:SetText(T("EDITOR_PRESET_SAVE_CUSTOM", "Save Current Layout as My Layout", deps))
        context.widgets.saveCustom:SetDisabled(not ThemeService.CaptureDefaultSnapshot)
        if ApplySidebarButtonVisual then
            ApplySidebarButtonVisual(context.widgets.saveCustom, SIDEBAR_VISUAL_ROLE.UTILITY)
        end
    end

    if context.widgets.restoreCustom then
        context.widgets.restoreCustom:SetText(T("EDITOR_PRESET_RESTORE", "Restore Previous Layout", deps))
        context.widgets.restoreCustom:SetDisabled(not (ThemeService.HasRestoreSnapshot and ThemeService.HasRestoreSnapshot() and ThemeService.RestoreSnapshot))
        if ApplySidebarButtonVisual then
            ApplySidebarButtonVisual(context.widgets.restoreCustom, SIDEBAR_VISUAL_ROLE.UTILITY)
        end
    end

    if context.widgets.restoreHint then
        context.widgets.restoreHint:SetText(T("EDITOR_PRESET_RESTORE_HINT", nil, deps))
    end

    if context.widgets.globalOptions then
        context.widgets.globalOptions:SetText(T("OPTION_OPTIONS", "Options", deps))
        if ApplySidebarButtonVisual then
            ApplySidebarButtonVisual(context.widgets.globalOptions, SIDEBAR_VISUAL_ROLE.UTILITY)
        end
    end

    if context.widgets.hideBlizzard then
        context.widgets.hideBlizzard:SetLabel(T("OPTION_HIDE_BLIZZARD_FRAMES", "Hide Blizzard Frames", deps))
        context.widgets.hideBlizzard:SetValue(ToolbarBinding.GetGlobalOptionValue("hideBlizzard", deps) == true)
        if StyleCheckBox then
            StyleCheckBox(context.widgets.hideBlizzard, false)
        end
    end

    if context.widgets.showMinimapButton then
        context.widgets.showMinimapButton:SetLabel(T("OPTION_SHOW_MINIMAP_BUTTON", "Show Minimap Button", deps))
        context.widgets.showMinimapButton:SetValue(ToolbarBinding.GetGlobalOptionValue("showMinimapButton", deps) == true)
        if StyleCheckBox then
            StyleCheckBox(context.widgets.showMinimapButton, false)
        end
    end

    if context.widgets.mouseEnabled then
        context.widgets.mouseEnabled:SetLabel(T("OPTION_MOUSE_ENABLED", "Mouse Enabled", deps))
        context.widgets.mouseEnabled:SetValue(ToolbarBinding.GetGlobalOptionValue("mouseEnabled", deps) == true)
        context.widgets.mouseEnabled:SetDisabled(not isExpertMode)
        if StyleCheckBox then
            StyleCheckBox(context.widgets.mouseEnabled, false)
        end
    end

    if context.widgets.clickthrough then
        context.widgets.clickthrough:SetLabel(T("OPTION_GLOBAL_CLICKTHROUGH", "Global Click Through", deps))
        context.widgets.clickthrough:SetValue(ToolbarBinding.GetGlobalOptionValue("clickthrough", deps) == true)
        context.widgets.clickthrough:SetDisabled(not isExpertMode)
        if StyleCheckBox then
            StyleCheckBox(context.widgets.clickthrough, false)
        end
    end

    if context.window and context.window.DoLayout then
        context.window:DoLayout()
    end
    if context.scroll and context.scroll.FixScroll then
        context.scroll:FixScroll()
    end

    context._suspendCallbacks = false
end

local function WireCallbacks(context, deps, refreshFn)
    local C = deps and deps.C or {}
    local nsRef = deps and deps.ns or {}

    IterateWidgetMap(NAV_WIDGET_IDS, function(widgetId, constantPath)
        local navPath = ResolveConstantPath(C, constantPath)
        local button = context.widgets[widgetId]
        if button then
            button:SetCallback("OnClick", function()
                if context.options and context.options.onNavigate then
                    context.options.onNavigate(navPath)
                end
            end)
        end
    end)

    if context.widgets.closeButton then
        context.widgets.closeButton:SetCallback("OnClick", function()
            if context.options and context.options.onClose then
                context.options.onClose()
            end
        end)
    end

    IterateWidgetMap(UNIT_WIDGET_IDS, function(widgetId, constantPath)
        local unitKey = ResolveConstantPath(C, constantPath)
        local button = context.widgets[widgetId]
        if button then
            button:SetCallback("OnClick", function()
                if context.options and context.options.onUnitChanged then
                    context.options.onUnitChanged(unitKey)
                end
            end)
        end
    end)

    if context.widgets.expertMode then
        context.widgets.expertMode:SetCallback("OnValueChanged", function(_, _, value)
            if context._suspendCallbacks then
                return
            end
            if context.options and context.options.onModeChanged then
                context.options.onModeChanged(value and "expert" or "quick")
            end
        end)
    end

    if context.widgets.demoButton then
        context.widgets.demoButton:SetCallback("OnClick", function()
            if nsRef.ToggleTestMode then
                nsRef:ToggleTestMode()
                if context.options and context.options.onGlobalChanged then
                    context.options.onGlobalChanged()
                end
            end
        end)
    end

    if context.widgets.unlockButton then
        context.widgets.unlockButton:SetCallback("OnClick", function()
            if nsRef.ToggleFrameLock then
                nsRef:ToggleFrameLock()
                if context.options and context.options.onGlobalChanged then
                    context.options.onGlobalChanged()
                end
            end
        end)
    end

    if context.widgets.frameModeButton then
        context.widgets.frameModeButton:SetCallback("OnClick", function()
            if IsInteractionModeControlDisabled(nsRef) then
                return
            end

            local interactionMode = GetInteractionMode(nsRef)
            if interactionMode
                and interactionMode.IsFrameMode
                and interactionMode.IsFrameMode() then
                return
            end
            if interactionMode and interactionMode.SetLatchedTextMode then
                interactionMode.SetLatchedTextMode(false)
            end
        end)
    end

    if context.widgets.textModeButton then
        context.widgets.textModeButton:SetCallback("OnClick", function()
            if IsInteractionModeControlDisabled(nsRef) then
                return
            end

            local interactionMode = GetInteractionMode(nsRef)
            if interactionMode
                and interactionMode.IsTextMode
                and interactionMode.IsTextMode() then
                return
            end
            if interactionMode and interactionMode.SetLatchedTextMode then
                interactionMode.SetLatchedTextMode(true)
            end
        end)
    end

    if context.widgets.presetDropdown then
        context.widgets.presetDropdown:SetCallback("OnValueChanged", function(_, _, value)
            if context._suspendCallbacks then
                return
            end
            if PresetUI.SelectPreset then
                PresetUI.SelectPreset(context, value, deps, refreshFn)
            end
        end)
    end

    if context.widgets.applyPreset then
        context.widgets.applyPreset:SetCallback("OnClick", function()
            if PresetUI.ApplyPresetToCurrent then
                PresetUI.ApplyPresetToCurrent(context, deps, refreshFn, {
                    allowCustomLayout = true,
                })
            end
        end)
    end

    if context.widgets.saveCustom then
        context.widgets.saveCustom:SetCallback("OnClick", function()
            local ThemeService = (deps and deps.ThemeService) or nsRef.ThemeService or {}
            if ThemeService.CaptureDefaultSnapshot and ThemeService.CaptureDefaultSnapshot() then
                if context.options and context.options.onThemeApplied then
                    context.options.onThemeApplied(context.state and context.state.selectedThemeId)
                elseif refreshFn then
                    refreshFn()
                end
            end
        end)
    end

    if context.widgets.restoreCustom then
        context.widgets.restoreCustom:SetCallback("OnClick", function()
            local ThemeService = (deps and deps.ThemeService) or nsRef.ThemeService or {}
            if ThemeService.RestoreSnapshot and ThemeService.RestoreSnapshot() then
                local restoredThemeId = nsRef.db and nsRef.db.profile and nsRef.db.profile.General and nsRef.db.profile.General.ActiveThemeId or (context.state and context.state.selectedThemeId)
                if context.state then
                    context.state.selectedThemeId = restoredThemeId
                end
                if context.options and context.options.onThemeApplied then
                    context.options.onThemeApplied(restoredThemeId)
                elseif refreshFn then
                    refreshFn()
                end
            end
        end)
    end

    if context.widgets.hideBlizzard then
        context.widgets.hideBlizzard:SetCallback("OnValueChanged", function(_, _, value)
            if context._suspendCallbacks then
                return
            end
            ToolbarBinding.ApplyGlobalOptionValue("hideBlizzard", value, deps, { onGlobalChanged = context.options and context.options.onGlobalChanged, refreshFn = refreshFn })
        end)
    end

    if context.widgets.showMinimapButton then
        context.widgets.showMinimapButton:SetCallback("OnValueChanged", function(_, _, value)
            if context._suspendCallbacks then
                return
            end
            ToolbarBinding.ApplyGlobalOptionValue("showMinimapButton", value, deps, { onGlobalChanged = context.options and context.options.onGlobalChanged, refreshFn = refreshFn })
        end)
    end

    if context.widgets.globalOptions then
        context.widgets.globalOptions:SetCallback("OnClick", function()
            if context._suspendCallbacks then
                return
            end
            local optionsDialog = nsRef.GUI
                and nsRef.GUI.Editor
                and nsRef.GUI.Editor.OptionsDialog
            if optionsDialog and optionsDialog.Open then
                optionsDialog.Open()
            end
        end)
    end

    if context.widgets.mouseEnabled then
        context.widgets.mouseEnabled:SetCallback("OnValueChanged", function(_, _, value)
            if context._suspendCallbacks then
                return
            end
            ToolbarBinding.ApplyGlobalOptionValue("mouseEnabled", value, deps, { onGlobalChanged = context.options and context.options.onGlobalChanged, refreshFn = refreshFn })
        end)
    end

    if context.widgets.clickthrough then
        context.widgets.clickthrough:SetCallback("OnValueChanged", function(_, _, value)
            if context._suspendCallbacks then
                return
            end
            ToolbarBinding.ApplyGlobalOptionValue("clickthrough", value, deps, { onGlobalChanged = context.options and context.options.onGlobalChanged, refreshFn = refreshFn })
        end)
    end
end

ToolbarBinding.CreateItemWidget = CreateItemWidget
ToolbarBinding.RefreshInteractionModeControls = RefreshInteractionModeControls
ToolbarBinding.RefreshWindowState = RefreshWindowState
ToolbarBinding.WireCallbacks = WireCallbacks
ToolbarBinding.IsExpertMode = IsExpertMode

return ToolbarBinding
