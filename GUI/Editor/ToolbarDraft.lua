local _, ns = ...

ns.GUI = ns.GUI or {}
ns.GUI.Editor = ns.GUI.Editor or {}

local AceGUI = LibStub("AceGUI-3.0")
local ToolbarDraft = {}
ns.GUI.Editor.ToolbarDraft = ToolbarDraft

local C = ns.Constants or {}
local KM = ns.KeyMap or {}
local L = ns.L or {}

local FormWidgets = ns.GUI.Helpers and ns.GUI.Helpers.FormWidgets
local FormLayoutRuntime = ns.GUI.Helpers and ns.GUI.Helpers.FormLayoutRuntime
local Shared = ns.GUI.Editor and ns.GUI.Editor.SidebarShared or {}

local CreateBodyText = FormWidgets and FormWidgets.CreateBodyText
local CreateActionButton = FormWidgets and FormWidgets.CreateActionButton
local StyleCheckBox = FormWidgets and FormWidgets.StyleCheckBox
local StyleDropdown = FormWidgets and FormWidgets.StyleDropdown
local ResolveItemColor = FormWidgets and FormWidgets.ResolveItemColor
local ApplyWindowChrome = FormWidgets and FormWidgets.ApplyWindowChrome

local ApplyUnitButtonSelection = Shared.ApplyUnitButtonSelection
local StyleSidebarButton = Shared.StyleSidebarButton

local windowContext

local NAV_WIDGET_IDS = {
    editorButton = C.Nav and C.Nav.EDITOR,
    profilesButton = C.Nav and C.Nav.PROFILES,
    textBuilderButton = C.Nav and C.Nav.TEXT_BUILDER,
    tagDatabaseButton = C.Nav and C.Nav.TAG_DATABASE,
}

local UNIT_WIDGET_IDS = {
    playerButton = C.Units and C.Units.PLAYER,
    targetButton = C.Units and C.Units.TARGET,
    targetTargetButton = C.Units and C.Units.TARGETTARGET,
    petButton = C.Units and C.Units.PET,
    focusButton = C.Units and C.Units.FOCUS,
    focusTargetButton = C.Units and C.Units.FOCUSTARGET,
    bossButton = C.Units and C.Units.BOSS,
}

local DRAFT_SECTIONS = {
    Root = true,
    Header = true,
    Tools = true,
    Workspace = true,
    WorkspaceEditorBody = true,
    UnitGrid = true,
    UnitGridRow1 = true,
    UnitGridRow2 = true,
    UnitGridRow3 = true,
    UnitGridRow4 = true,
    WorkspaceEditorFooter = true,
    Editing = true,
    Presets = true,
    Global = true,
    Footer = true,
}

local function T(key, fallback)
    return (type(key) == "string" and L[key]) or fallback or ""
end

local function ResolveItemText(props)
    if not props then
        return ""
    end
    if props.textKey then
        return T(props.textKey)
    end
    return props.text or ""
end

local function CenterWindow(window)
    local frame = window and window.frame
    if not frame then
        return
    end
    frame:ClearAllPoints()
    frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
end

local function GetDraftWindowHeight()
    local rootHeight = UIParent and UIParent.GetHeight and UIParent:GetHeight() or 900
    return math.max(760, math.floor(rootHeight - 24))
end

local function ApplyDraftWindowPresentation(window)
    if not window or not window.frame then
        return
    end

    if window.titletext and window.titletext.Hide then
        window.titletext:Hide()
    end

    if window.closebutton and window.closebutton.Hide then
        window.closebutton:Hide()
    end
end

local function FocusWindow(window)
    local frame = window and window.frame
    if not frame then
        return
    end
    if frame.IsShown and not frame:IsShown() then
        CenterWindow(window)
    end
    if window.Show then
        window:Show()
    elseif frame.Show then
        frame:Show()
    end
    frame:SetFrameStrata("FULLSCREEN_DIALOG")
    frame:SetToplevel(true)
    if frame.Raise then
        frame:Raise()
    end
end

local function FilterDefinitions()
    local definitions = {}
    local toolbarLayout = ns.GUI.Layouts and ns.GUI.Layouts.Editor and ns.GUI.Layouts.Editor.ToolbarForm
    for _, definition in ipairs(toolbarLayout or {}) do
        if DRAFT_SECTIONS[definition.section] then
            definitions[#definitions + 1] = definition
        end
    end
    return definitions
end

local function CreateItemWidget(_, _, props)
    if not props or not props.widget then
        return nil
    end

    if props.widget == "label" then
        local label = CreateBodyText(
            ResolveItemText(props),
            props.role or "label",
            props.size or 12,
            ResolveItemColor(props.colorKey),
            props.width,
            props.fullWidth
        )
        if props.justifyH and label.label and label.label.SetJustifyH then
            label.label:SetJustifyH(props.justifyH)
        end
        return label
    end

    if props.widget == "button" then
        return CreateActionButton(ResolveItemText(props), props.buttonVariant, props.width, props.fullWidth)
    end

    if props.widget == "checkbox" then
        local checkbox = AceGUI:Create("CheckBox")
        if type(props.width) == "number" then
            checkbox:SetFullWidth(false)
            checkbox:SetWidth(props.width)
        elseif props.fullWidth ~= false then
            checkbox:SetFullWidth(true)
        end
        checkbox:SetLabel(ResolveItemText(props))
        checkbox:SetValue(props.checked and true or false)
        StyleCheckBox(checkbox, false)
        return checkbox
    end

    if props.widget == "dropdown" then
        local dropdown = AceGUI:Create("Dropdown")
        dropdown:SetLabel(T(props.labelKey))
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

local function CreateWindowContent(window)
    local groups, widgets = FormLayoutRuntime.BuildLayout(window, FilterDefinitions(), {
        createItemWidget = CreateItemWidget,
    })

    return {
        window = window,
        groups = groups,
        widgets = widgets,
        state = nil,
        options = nil,
    }
end

local function RefreshWindowState()
    local context = windowContext
    if not context or not context.widgets then
        return
    end

    local state = context.state or {}
    local options = context.options or {}
    local generalConfig = ns.db and ns.db.profile and ns.db.profile.General
    local ThemeService = ns.ThemeService or {}
    local themes = ThemeService.GetThemes and ThemeService.GetThemes() or {}
    local themeList = Shared.BuildThemeList and Shared.BuildThemeList(themes) or {}
    local customThemeId = ThemeService.GetCustomThemeId and ThemeService.GetCustomThemeId() or "__custom__"
    local activeThemeId = generalConfig and generalConfig.ActiveThemeId
    local selectedThemeId = state.selectedThemeId or activeThemeId
    if type(generalConfig) ~= "table" then
        return
    end

    if ThemeService.HasDefaultSnapshot and ThemeService.HasDefaultSnapshot() then
        themeList[customThemeId] = T("THEME_CUSTOM", "My Layout")
    end
    if not themeList[selectedThemeId] then
        selectedThemeId = activeThemeId
    end
    if not themeList[selectedThemeId] and Shared.GetFirstThemeId then
        selectedThemeId = Shared.GetFirstThemeId(themeList)
    end
    state.selectedThemeId = selectedThemeId

    local BuilderUI = ns.GUI and ns.GUI.Helpers and ns.GUI.Helpers.BuilderUI or {}
    local versionText = BuilderUI.GetAddonVersionText and BuilderUI.GetAddonVersionText() or "dev"
    local logoPath = "Interface\\AddOns\\FocalPoint\\Media\\icon.tga"
    local normalizedCurrent = options.currentPath or (ns.GUI and ns.GUI.selectedPath) or (C.Nav and C.Nav.EDITOR)

    if context.widgets.brandLine then
        context.widgets.brandLine:SetText(string.format("|T%s:24:24:0:0|t  |cff6fd2ff%s|r", logoPath, T("ADDON_NAME", C.ADDON_NAME or "FocalPoint")))
    end
    if context.widgets.versionLine then
        context.widgets.versionLine:SetText(string.format("|cffd8c27a%s|r  |cff4cff88%s|r", T("INFO_VERSION", "Version"), versionText))
    end
    if context.widgets.toolsTitle then
        context.widgets.toolsTitle:SetText(T("EDITOR_CONTEXT_TOOLS", "Tools"))
    end
    if context.widgets.workspaceTitle then
        context.widgets.workspaceTitle:SetText(T("EDITOR_CONTEXT_WORKSPACE", "Workspace"))
    end
    if context.widgets.editingTitle then
        context.widgets.editingTitle:SetText(T("EDITOR_CONTEXT_PREVIEW", "Editing"))
    end
    if context.widgets.presetsTitle then
        context.widgets.presetsTitle:SetText(T("EDITOR_CONTEXT_PRESET", "Presets"))
    end
    if context.widgets.globalTitle then
        context.widgets.globalTitle:SetText(T("EDITOR_CONTEXT_GLOBAL", "Addon"))
    end
    if context.widgets.footerNote then
        context.widgets.footerNote:SetText("Draft Toolbar")
    end
    if context.widgets.unitLabel then
        context.widgets.unitLabel:SetText(T("EDITOR_UNIT", "Unit"))
    end

    for widgetId, navPath in pairs(NAV_WIDGET_IDS) do
        local button = context.widgets[widgetId]
        if button then
            local label = ns.GetLabel and ns.GetLabel(KM.Nav, navPath) or navPath or ""
            button:SetText(label)
            if StyleSidebarButton then
                StyleSidebarButton(button, normalizedCurrent == navPath and "active" or "secondary")
            end
            button:SetDisabled(normalizedCurrent == navPath)
        end
    end

    if context.widgets.closeButton then
        context.widgets.closeButton:SetText(CLOSE or "Close")
        if StyleSidebarButton then
            StyleSidebarButton(context.widgets.closeButton, "danger")
        end
    end

    for widgetId, unitKey in pairs(UNIT_WIDGET_IDS) do
        local button = context.widgets[widgetId]
        if button then
            button:SetText(ns.GetLabel and ns.GetLabel(KM.Units, unitKey) or unitKey or "")
            if ApplyUnitButtonSelection then
                ApplyUnitButtonSelection(button, unitKey == state.selectedUnit)
            end
        end
    end

    if context.widgets.expertMode then
        context.widgets.expertMode:SetLabel(T("OPTION_EXPERT_MODE", "Expert Mode"))
        context.widgets.expertMode:SetValue(generalConfig.ExpertMode ~= false)
        StyleCheckBox(context.widgets.expertMode, false)
    end

    if context.widgets.demoButton then
        context.widgets.demoButton:SetText((ns.guiTestModeEnabled and T("GUI_TEST_STOP", "Stop Test")) or T("GUI_TEST_START", "Test"))
    end

    if context.widgets.unlockButton then
        context.widgets.unlockButton:SetText((ns.framesUnlocked and T("GUI_UNLOCK_STOP", "Lock Frames")) or T("GUI_UNLOCK_START", "Unlock Frames"))
    end

    if context.widgets.editingHint then
        context.widgets.editingHint:SetText(T("EDITOR_PREVIEW_INTERACTION_HINT"))
    end

    if context.widgets.presetsIntro then
        context.widgets.presetsIntro:SetText(T("EDITOR_PRESET_CONTEXT_HINT"))
    end

    if context.widgets.presetDropdown then
        context.widgets.presetDropdown:SetLabel(T("EDITOR_PRESET_SELECT", T("THEME_SELECT", "Select Preset")))
        context.widgets.presetDropdown:SetList(themeList)
        context.widgets.presetDropdown:SetValue(selectedThemeId)
        context.widgets.presetDropdown:SetDisabled(next(themeList) == nil)
        if StyleDropdown then
            StyleDropdown(context.widgets.presetDropdown, "accented")
        end
    end

    if context.widgets.presetThemeInfo then
        local selectedTheme = themes[selectedThemeId]
        local themeDescription
        if selectedThemeId == customThemeId then
            themeDescription = T("THEME_CUSTOM_DESC")
        else
            themeDescription = (selectedTheme and selectedTheme.descriptionKey and T(selectedTheme.descriptionKey))
                or T("INFO_GENERAL_THEMES_DESC")
        end
        context.widgets.presetThemeInfo:SetText(themeDescription or "")
    end

    if context.widgets.applyPreset then
        context.widgets.applyPreset:SetText(T("THEME_APPLY", T("INFO_GENERAL_THEME_APPLY", "Apply Preset")))
        context.widgets.applyPreset:SetDisabled(not selectedThemeId)
    end

    if context.widgets.saveCustom then
        context.widgets.saveCustom:SetText(T("EDITOR_PRESET_SAVE_CUSTOM", "Save Current Layout as My Layout"))
        context.widgets.saveCustom:SetDisabled(not ThemeService.CaptureDefaultSnapshot)
    end

    if context.widgets.restoreCustom then
        context.widgets.restoreCustom:SetText(T("EDITOR_PRESET_RESTORE", "Restore Previous Layout"))
        context.widgets.restoreCustom:SetDisabled(not (ThemeService.HasRestoreSnapshot and ThemeService.HasRestoreSnapshot() and ThemeService.RestoreSnapshot))
    end

    if context.widgets.restoreHint then
        context.widgets.restoreHint:SetText(T("EDITOR_PRESET_RESTORE_HINT"))
    end

    if context.widgets.hideBlizzard then
        context.widgets.hideBlizzard:SetLabel(T("OPTION_HIDE_BLIZZARD_FRAMES", "Hide Blizzard Frames"))
        context.widgets.hideBlizzard:SetValue(generalConfig.HideBlizzardFrames == true)
        StyleCheckBox(context.widgets.hideBlizzard, false)
    end

    if context.widgets.mouseEnabled then
        context.widgets.mouseEnabled:SetLabel(T("OPTION_MOUSE_ENABLED", "Mouse Enabled"))
        context.widgets.mouseEnabled:SetValue(generalConfig.MouseEnabled ~= false)
        context.widgets.mouseEnabled:SetDisabled(generalConfig.ExpertMode == false)
        StyleCheckBox(context.widgets.mouseEnabled, false)
    end

    if context.widgets.clickthrough then
        context.widgets.clickthrough:SetLabel(T("OPTION_GLOBAL_CLICKTHROUGH", "Global Click Through"))
        context.widgets.clickthrough:SetValue(generalConfig.GlobalClickThrough == true)
        context.widgets.clickthrough:SetDisabled(generalConfig.ExpertMode == false)
        StyleCheckBox(context.widgets.clickthrough, false)
    end

    if context.window and context.window.DoLayout then
        context.window:DoLayout()
    end
end

local function WireCallbacks(context)
    for widgetId, navPath in pairs(NAV_WIDGET_IDS) do
        local button = context.widgets[widgetId]
        if button then
            button:SetCallback("OnClick", function()
                if context.options and context.options.onNavigate then
                    context.options.onNavigate(navPath)
                end
            end)
        end
    end

    if context.widgets.closeButton then
        context.widgets.closeButton:SetCallback("OnClick", function()
            if context.options and context.options.onClose then
                context.options.onClose()
            end
        end)
    end

    for widgetId, unitKey in pairs(UNIT_WIDGET_IDS) do
        local button = context.widgets[widgetId]
        if button then
            button:SetCallback("OnClick", function()
                if context.options and context.options.onUnitChanged then
                    context.options.onUnitChanged(unitKey)
                end
            end)
        end
    end

    if context.widgets.expertMode then
        context.widgets.expertMode:SetCallback("OnValueChanged", function(_, _, value)
            if context.options and context.options.onModeChanged then
                context.options.onModeChanged(value and "expert" or "quick")
            end
        end)
    end

    if context.widgets.demoButton then
        context.widgets.demoButton:SetCallback("OnClick", function()
            if ns.ToggleTestMode then
                ns:ToggleTestMode()
                if context.options and context.options.onGlobalChanged then
                    context.options.onGlobalChanged()
                end
            end
        end)
    end

    if context.widgets.unlockButton then
        context.widgets.unlockButton:SetCallback("OnClick", function()
            if ns.ToggleFrameLock then
                ns:ToggleFrameLock()
                if context.options and context.options.onGlobalChanged then
                    context.options.onGlobalChanged()
                end
            end
        end)
    end

    if context.widgets.presetDropdown then
        context.widgets.presetDropdown:SetCallback("OnValueChanged", function(_, _, value)
            context.state.selectedThemeId = value
            if context.options and context.options.onThemeChanged then
                context.options.onThemeChanged(value)
            else
                RefreshWindowState()
            end
        end)
    end

    if context.widgets.applyPreset then
        context.widgets.applyPreset:SetCallback("OnClick", function()
            local ThemeService = ns.ThemeService or {}
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
                local appliedThemeId = ns.db and ns.db.profile and ns.db.profile.General and ns.db.profile.General.ActiveThemeId or selectedThemeId
                context.state.selectedThemeId = appliedThemeId
                if context.options and context.options.onThemeApplied then
                    context.options.onThemeApplied(appliedThemeId)
                else
                    RefreshWindowState()
                end
            end
        end)
    end

    if context.widgets.saveCustom then
        context.widgets.saveCustom:SetCallback("OnClick", function()
            local ThemeService = ns.ThemeService or {}
            if ThemeService.CaptureDefaultSnapshot and ThemeService.CaptureDefaultSnapshot() then
                if context.options and context.options.onThemeApplied then
                    context.options.onThemeApplied(context.state and context.state.selectedThemeId)
                else
                    RefreshWindowState()
                end
            end
        end)
    end

    if context.widgets.restoreCustom then
        context.widgets.restoreCustom:SetCallback("OnClick", function()
            local ThemeService = ns.ThemeService or {}
            if ThemeService.RestoreSnapshot and ThemeService.RestoreSnapshot() then
                local restoredThemeId = ns.db and ns.db.profile and ns.db.profile.General and ns.db.profile.General.ActiveThemeId or (context.state and context.state.selectedThemeId)
                if context.state then
                    context.state.selectedThemeId = restoredThemeId
                end
                if context.options and context.options.onThemeApplied then
                    context.options.onThemeApplied(restoredThemeId)
                else
                    RefreshWindowState()
                end
            end
        end)
    end

    if context.widgets.hideBlizzard then
        context.widgets.hideBlizzard:SetCallback("OnValueChanged", function(_, _, value)
            local generalConfig = ns.db and ns.db.profile and ns.db.profile.General
            if type(generalConfig) ~= "table" then
                return
            end
            generalConfig.HideBlizzardFrames = value and true or false
            if ns.ApplyGeneralSettings then
                ns:ApplyGeneralSettings()
            end
            if not generalConfig.HideBlizzardFrames and ns.Info then
                ns:Info(T("INFO_RELOAD_REQUIRED_BLIZZARD_FRAMES"))
            end
            if context.options and context.options.onGlobalChanged then
                context.options.onGlobalChanged()
            else
                RefreshWindowState()
            end
        end)
    end

    if context.widgets.mouseEnabled then
        context.widgets.mouseEnabled:SetCallback("OnValueChanged", function(_, _, value)
            local generalConfig = ns.db and ns.db.profile and ns.db.profile.General
            if type(generalConfig) ~= "table" then
                return
            end
            generalConfig.MouseEnabled = value and true or false
            if ns.RefreshAllUnitFrames then
                ns:RefreshAllUnitFrames()
            end
            if context.options and context.options.onGlobalChanged then
                context.options.onGlobalChanged()
            else
                RefreshWindowState()
            end
        end)
    end

    if context.widgets.clickthrough then
        context.widgets.clickthrough:SetCallback("OnValueChanged", function(_, _, value)
            local generalConfig = ns.db and ns.db.profile and ns.db.profile.General
            if type(generalConfig) ~= "table" then
                return
            end
            generalConfig.GlobalClickThrough = value and true or false
            if ns.RefreshAllUnitFrames then
                ns:RefreshAllUnitFrames()
            end
            if context.options and context.options.onGlobalChanged then
                context.options.onGlobalChanged()
            else
                RefreshWindowState()
            end
        end)
    end
end

local function CreateWindow(state, options)
    local window = AceGUI:Create("Window")
    window:SetTitle("Toolbar Draft")
    window:SetLayout("Fill")
    window:SetWidth(285)
    window:SetHeight(GetDraftWindowHeight())
    window:EnableResize(false)

    if window.frame then
        window.frame:SetClampedToScreen(true)
    end

    if ApplyWindowChrome then
        ApplyWindowChrome(window)
    end
    ApplyDraftWindowPresentation(window)
    CenterWindow(window)

    local context = CreateWindowContent(window)
    context.state = state
    context.options = options
    windowContext = context
    WireCallbacks(context)

    return context
end

function ToolbarDraft.Open(state, options)
    if not windowContext or not windowContext.window or not windowContext.window.frame then
        CreateWindow(state, options)
    else
        windowContext.state = state
        windowContext.options = options
    end

    if windowContext and windowContext.window then
        windowContext.window:SetHeight(GetDraftWindowHeight())
        ApplyDraftWindowPresentation(windowContext.window)
    end

    RefreshWindowState()
    FocusWindow(windowContext.window)
end

function ToolbarDraft.Hide()
    if not windowContext or not windowContext.window then
        return
    end

    if windowContext.window.Hide then
        windowContext.window:Hide()
    elseif windowContext.window.frame and windowContext.window.frame.Hide then
        windowContext.window.frame:Hide()
    end
end

return ToolbarDraft
