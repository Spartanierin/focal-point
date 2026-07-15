local _, ns = ...

ns.GUI = ns.GUI or {}
ns.GUI.Editor = ns.GUI.Editor or {}

local ToolbarBinding = {}
ns.GUI.Editor.ToolbarBinding = ToolbarBinding

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

local function ResolveEditorMode(state, profile)
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

    return nil
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
    local BuildThemeList = deps and deps.BuildThemeList
    local GetFirstThemeId = deps and deps.GetFirstThemeId
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
    local themes = ThemeService.GetThemes and ThemeService.GetThemes() or {}
    local themeList = BuildThemeList and BuildThemeList(themes) or {}
    local customThemeId = ThemeService.GetCustomThemeId and ThemeService.GetCustomThemeId() or "__custom__"
    local activeThemeId = generalConfig and generalConfig.ActiveThemeId
    local selectedThemeId = state.selectedThemeId or activeThemeId
    if type(generalConfig) ~= "table" then
        context._suspendCallbacks = false
        return
    end
    local activeEditorMode = ResolveEditorMode(state, nsRef.db and nsRef.db.profile)
    local isExpertMode = activeEditorMode == "expert"

    if ThemeService.HasDefaultSnapshot and ThemeService.HasDefaultSnapshot() then
        themeList[customThemeId] = T("THEME_CUSTOM", "My Layout", deps)
    end
    if not themeList[selectedThemeId] then
        selectedThemeId = activeThemeId
    end
    if not themeList[selectedThemeId] and GetFirstThemeId then
        selectedThemeId = GetFirstThemeId(themeList)
    end
    state.selectedThemeId = selectedThemeId

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
        context.widgets.presetDropdown:SetLabel(T("EDITOR_PRESET_SELECT", T("THEME_SELECT", "Select Preset", deps), deps))
        context.widgets.presetDropdown:SetList(themeList)
        context.widgets.presetDropdown:SetValue(selectedThemeId)
        context.widgets.presetDropdown:SetDisabled(next(themeList) == nil)
        if StyleDropdown then
            StyleDropdown(context.widgets.presetDropdown, "editor_inset")
        end
    end

    if context.widgets.presetThemeInfo then
        local selectedTheme = themes[selectedThemeId]
        local themeDescription
        if selectedThemeId == customThemeId then
            themeDescription = T("THEME_CUSTOM_DESC", nil, deps)
        else
            themeDescription = (selectedTheme and selectedTheme.descriptionKey and T(selectedTheme.descriptionKey, nil, deps))
                or T("INFO_GENERAL_THEMES_DESC", nil, deps)
        end
        context.widgets.presetThemeInfo:SetText(themeDescription or "")
    end

    if context.widgets.applyPreset then
        context.widgets.applyPreset:SetText(T("THEME_APPLY", T("INFO_GENERAL_THEME_APPLY", "Apply Preset", deps), deps))
        context.widgets.applyPreset:SetDisabled(not selectedThemeId)
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

    if context.widgets.hideBlizzard then
        context.widgets.hideBlizzard:SetLabel(T("OPTION_HIDE_BLIZZARD_FRAMES", "Hide Blizzard Frames", deps))
        context.widgets.hideBlizzard:SetValue(generalConfig.HideBlizzardFrames == true)
        if StyleCheckBox then
            StyleCheckBox(context.widgets.hideBlizzard, false)
        end
    end

    if context.widgets.mouseEnabled then
        context.widgets.mouseEnabled:SetLabel(T("OPTION_MOUSE_ENABLED", "Mouse Enabled", deps))
        context.widgets.mouseEnabled:SetValue(generalConfig.MouseEnabled ~= false)
        context.widgets.mouseEnabled:SetDisabled(not isExpertMode)
        if StyleCheckBox then
            StyleCheckBox(context.widgets.mouseEnabled, false)
        end
    end

    if context.widgets.clickthrough then
        context.widgets.clickthrough:SetLabel(T("OPTION_GLOBAL_CLICKTHROUGH", "Global Click Through", deps))
        context.widgets.clickthrough:SetValue(generalConfig.GlobalClickThrough == true)
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

    if context.widgets.presetDropdown then
        context.widgets.presetDropdown:SetCallback("OnValueChanged", function(_, _, value)
            if context._suspendCallbacks then
                return
            end
            context.state.selectedThemeId = value
            if context.options and context.options.onThemeChanged then
                context.options.onThemeChanged(value)
            elseif refreshFn then
                refreshFn()
            end
        end)
    end

    if context.widgets.applyPreset then
        context.widgets.applyPreset:SetCallback("OnClick", function()
            local ThemeService = (deps and deps.ThemeService) or nsRef.ThemeService or {}
            local selectedThemeId = context.state and context.state.selectedThemeId
            local customThemeId = ThemeService.GetCustomThemeId and ThemeService.GetCustomThemeId() or "__custom__"
            if not selectedThemeId or not ThemeService.ApplyTheme then
                return
            end

            if selectedThemeId ~= customThemeId
                and ThemeService.HasDefaultSnapshot
                and ThemeService.CaptureDefaultSnapshot
                and not ThemeService.HasDefaultSnapshot() then
                ThemeService.CaptureDefaultSnapshot()
            end

            if selectedThemeId ~= customThemeId and ThemeService.CaptureRestoreSnapshot then
                ThemeService.CaptureRestoreSnapshot()
            end

            if ThemeService.ApplyTheme(selectedThemeId) then
                local appliedThemeId = nsRef.db and nsRef.db.profile and nsRef.db.profile.General and nsRef.db.profile.General.ActiveThemeId or selectedThemeId
                context.state.selectedThemeId = appliedThemeId
                if context.options and context.options.onThemeApplied then
                    context.options.onThemeApplied(appliedThemeId)
                elseif refreshFn then
                    refreshFn()
                end
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
            local generalConfig = nsRef.db and nsRef.db.profile and nsRef.db.profile.General
            if type(generalConfig) ~= "table" then
                return
            end
            generalConfig.HideBlizzardFrames = value and true or false
            if nsRef.ApplyGeneralSettings then
                nsRef:ApplyGeneralSettings()
            end
            if not generalConfig.HideBlizzardFrames and nsRef.Info then
                nsRef:Info(T("INFO_RELOAD_REQUIRED_BLIZZARD_FRAMES", nil, deps))
            end
            if context.options and context.options.onGlobalChanged then
                context.options.onGlobalChanged()
            elseif refreshFn then
                refreshFn()
            end
        end)
    end

    if context.widgets.mouseEnabled then
        context.widgets.mouseEnabled:SetCallback("OnValueChanged", function(_, _, value)
            if context._suspendCallbacks then
                return
            end
            local generalConfig = nsRef.db and nsRef.db.profile and nsRef.db.profile.General
            if type(generalConfig) ~= "table" then
                return
            end
            generalConfig.MouseEnabled = value and true or false
            if nsRef.RefreshAllUnitFrames then
                nsRef:RefreshAllUnitFrames()
            end
            if context.options and context.options.onGlobalChanged then
                context.options.onGlobalChanged()
            elseif refreshFn then
                refreshFn()
            end
        end)
    end

    if context.widgets.clickthrough then
        context.widgets.clickthrough:SetCallback("OnValueChanged", function(_, _, value)
            if context._suspendCallbacks then
                return
            end
            local generalConfig = nsRef.db and nsRef.db.profile and nsRef.db.profile.General
            if type(generalConfig) ~= "table" then
                return
            end
            generalConfig.GlobalClickThrough = value and true or false
            if nsRef.RefreshAllUnitFrames then
                nsRef:RefreshAllUnitFrames()
            end
            if context.options and context.options.onGlobalChanged then
                context.options.onGlobalChanged()
            elseif refreshFn then
                refreshFn()
            end
        end)
    end
end

ToolbarBinding.CreateItemWidget = CreateItemWidget
ToolbarBinding.RefreshWindowState = RefreshWindowState
ToolbarBinding.WireCallbacks = WireCallbacks

return ToolbarBinding
