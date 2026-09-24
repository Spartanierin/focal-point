local _, ns = ...

ns.GUI = ns.GUI or {}
ns.GUI.Editor = ns.GUI.Editor or {}

local AceGUI = LibStub("AceGUI-3.0")
local ToolbarController = {}
ns.GUI.Editor.Toolbar = ToolbarController

local C = ns.Constants or {}
local KM = ns.KeyMap or {}
local L = ns.L or {}
local SidebarGeometry = ns.GUI.Editor and ns.GUI.Editor.SidebarGeometry
local SIDEBAR_WIDTH = (SidebarGeometry and SidebarGeometry.width) or 285

local FormWidgets = ns.GUI.Helpers and ns.GUI.Helpers.FormWidgets
local FormRenderer = ns.GUI.Helpers and ns.GUI.Helpers.FormRenderer
local FormSectionSurfaceRenderer = ns.GUI.Helpers and ns.GUI.Helpers.FormSectionSurfaceRenderer
local TextStyles = ns.GUI.Helpers and ns.GUI.Helpers.TextStyles
local EditorSidebarThemeHelpers = ns.GUI.Editor and ns.GUI.Editor.EditorSidebarThemeHelpers or {}
local ToolbarBinding = ns.GUI.Editor and ns.GUI.Editor.ToolbarBinding

local CreateBodyText = FormWidgets and FormWidgets.CreateBodyText
local CreateActionButton = FormWidgets and FormWidgets.CreateActionButton
local StyleCheckBox = FormWidgets and FormWidgets.StyleCheckBox
local StyleDropdown = FormWidgets and FormWidgets.StyleDropdown
local StyleActionButton = FormWidgets and FormWidgets.StyleActionButton
local ResolveItemColor = FormWidgets and FormWidgets.ResolveItemColor
local ApplySidebarChrome = FormWidgets and FormWidgets.ApplySidebarChrome
local StyleEditBox = FormWidgets and FormWidgets.StyleEditBox
local ApplyWindowChrome = FormWidgets and FormWidgets.ApplyWindowChrome
local EnsureStandardWindowCloseButton = FormWidgets and FormWidgets.EnsureStandardWindowCloseButton

local StyleSidebarButton = EditorSidebarThemeHelpers.StyleSidebarButton
local windowContext

local SIDEBAR_SECTION_STYLES = {
    Workspace = "toolbar_workspace_panel",
    Editing = "toolbar_editing_panel",
    Options = "toolbar_global_panel",
    Secondary = "toolbar_global_panel",
}

local TOOLBAR_SECTIONS = {
    Root = true,
    Header = true,
    Composition = true,
    Workspace = true,
    WorkspaceEditorBody = true,
    UnitGrid = true,
    UnitGridRow1 = true,
    UnitGridRow2 = true,
    UnitGridRow3 = true,
    UnitGridRow4 = true,
    Editing = true,
    Options = true,
    Secondary = true,
    Footer = true,
}

local function BuildBindingDeps()
    return {
        AceGUI = AceGUI,
        L = L,
        C = C,
        KM = KM,
        ns = ns,
        ThemeService = ns.ThemeService or {},
        PresetService = ns.PresetService or {},
        ProfileLayoutService = ns.ProfileLayoutService or {},
        BuilderUI = ns.GUI and ns.GUI.Helpers and ns.GUI.Helpers.GUIRuntimeHelpers or {},
        CreateBodyText = CreateBodyText,
        CreateActionButton = CreateActionButton,
        StyleCheckBox = StyleCheckBox,
        StyleDropdown = StyleDropdown,
        StyleEditBox = StyleEditBox,
        StyleActionButton = StyleActionButton,
        ResolveItemColor = ResolveItemColor,
        ApplyWindowChrome = ApplyWindowChrome,
        EnsureStandardWindowCloseButton = EnsureStandardWindowCloseButton,
        StyleSidebarButton = StyleSidebarButton,
    }
end

local function PositionWindow(window)
    local frame = window and window.frame
    if not frame then
        return
    end
    frame:ClearAllPoints()
    frame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", SidebarGeometry.left or 16, SidebarGeometry.top or 0)
end

local function GetToolbarWindowHeight()
    local rootHeight = UIParent and UIParent.GetHeight and UIParent:GetHeight() or 900
    return math.floor(rootHeight)
end

local function ApplyToolbarWindowPresentation(window)
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

local function ApplyToolbarShellComposition(window, canonicalOnly)
    local composition = ns.GUI.PresentationCompositionPreview
    if not composition or not window then
        return false
    end

    local active = composition.Apply("sidebar_shell", window, nil, canonicalOnly)
    if not active and ApplySidebarChrome then
        ApplySidebarChrome(window, "sidebar_shell")
    end
    return active
end

local function EnsureToolbarShellCompositionBinding(window)
    local composition = ns.GUI.PresentationCompositionPreview
    if not composition or not window then
        return
    end

    if not window._fpSidebarCompositionBound then
        composition.Bind("sidebar_shell", window, ApplyToolbarShellComposition)
        window._fpSidebarCompositionBound = true
    end
    ApplyToolbarShellComposition(window)
end

local function ApplyToolbarSectionComposition(owner, styleId, canonicalOnly)
    local composition = ns.GUI.PresentationCompositionPreview
    if not composition or not owner then
        return false
    end

    local active = composition.Apply("sidebar_section", owner, nil, canonicalOnly)
    if not active and FormSectionSurfaceRenderer and FormWidgets and FormWidgets.ResolveSectionStyle then
        local style = FormWidgets.ResolveSectionStyle(styleId)
        if style then
            FormSectionSurfaceRenderer.ApplySectionSurface(owner, style)
            FormSectionSurfaceRenderer.ApplySectionBorder(owner, style.border, style.surfaceInsets)
        end
    end
    return active
end

local function BindToolbarSectionOwner(groups, sectionKey, styleId)
    local group = groups and groups[sectionKey]
    local composition = ns.GUI.PresentationCompositionPreview
    if not group or not composition then
        return
    end

    composition.Bind("sidebar_section", group, function(owner, canonicalOnly)
        return ApplyToolbarSectionComposition(owner, styleId, canonicalOnly)
    end)
    ApplyToolbarSectionComposition(group, styleId)
end

local function EnsureToolbarSectionCompositionBindings(groups)
    for sectionKey, styleId in pairs(SIDEBAR_SECTION_STYLES) do
        BindToolbarSectionOwner(groups, sectionKey, styleId)
    end
end

local SIDEBAR_SECTION_HEADING_WIDGETS = {
    "unitLabel",
    "compositionTitle",
    "editingTitle",
    "toolsTitle",
}

local function ApplyToolbarSectionTypography(widget, canonicalOnly)
    local target = widget and widget.label
    local preview = ns.GUI.PresentationPreview
    if not target or not preview or not preview.ResolveTypographyPresentation then
        return
    end

    local descriptor = preview.ResolveTypographyPresentation("sidebar_section_heading", canonicalOnly)
    if not descriptor or not TextStyles or not TextStyles.ApplyFontString then
        return
    end

    local font = preview.ResolveTypographyFont and preview.ResolveTypographyFont(descriptor.font) or nil
    TextStyles.ApplyFontString(target, "sectionHeader", {
        font = font,
        size = descriptor.size,
        flags = descriptor.flags,
        alpha = descriptor.alpha,
        shadow = descriptor.shadowEnabled,
    })
end

local function EnsureToolbarSectionTypographyBindings(widgets)
    local preview = ns.GUI.PresentationPreview
    if not preview or not preview.BindTypographyWidget then
        return
    end

    for _, widgetId in ipairs(SIDEBAR_SECTION_HEADING_WIDGETS) do
        local widget = widgets and widgets[widgetId]
        if widget then
            preview.BindTypographyWidget(widget, { "sidebar_section_heading" }, function(owner, canonicalOnly)
                ApplyToolbarSectionTypography(owner, canonicalOnly)
            end)
            ApplyToolbarSectionTypography(widget)
        end
    end
end

local function FocusWindow(window)
    local frame = window and window.frame
    if not frame then
        return
    end
    if frame.IsShown and not frame:IsShown() then
        PositionWindow(window)
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
        if TOOLBAR_SECTIONS[definition.section] then
            definitions[#definitions + 1] = definition
        end
    end
    return definitions
end

local function CreateWindowContent(window)
    local deps = BuildBindingDeps()
    local scroll = AceGUI:Create("ScrollFrame")
    scroll:SetLayout("Flow")
    scroll:SetFullWidth(true)
    scroll:SetFullHeight(true)
    window:AddChild(scroll)

    local groups, widgets = FormRenderer.BuildLayout(scroll, FilterDefinitions(), {
        createItemWidget = function(_, _, props)
            if ToolbarBinding and ToolbarBinding.CreateItemWidget then
                return ToolbarBinding.CreateItemWidget(props, deps)
            end
            return nil
        end,
    })

    EnsureToolbarSectionCompositionBindings(groups)
    EnsureToolbarSectionTypographyBindings(widgets)
    if ns.GUI.PresentationPreview then
        ns.GUI.PresentationPreview.BindSidebarNavigatorInset(groups.UnitGrid)
    end

    return {
        window = window,
        scroll = scroll,
        groups = groups,
        widgets = widgets,
        state = nil,
        options = nil,
    }
end

local function RefreshBindingState()
    if ToolbarBinding and ToolbarBinding.RefreshWindowState then
        ToolbarBinding.RefreshWindowState(windowContext, BuildBindingDeps())
    end
end

local function CreateWindow(state, options)
    local window = AceGUI:Create("Window")
    window:SetTitle("Toolbar")
    window:SetLayout("Fill")
    window:SetWidth(SIDEBAR_WIDTH)
    window:SetHeight(GetToolbarWindowHeight())
    window:EnableResize(false)

    if window.frame then
        window.frame:SetClampedToScreen(true)
    end

    if ApplySidebarChrome then
        ApplySidebarChrome(window, "sidebar_shell")
    end
    EnsureToolbarShellCompositionBinding(window)
    ApplyToolbarWindowPresentation(window)
    PositionWindow(window)

    local context = CreateWindowContent(window)
    context.state = state
    context.options = options
    windowContext = context
    if ToolbarBinding and ToolbarBinding.WireCallbacks then
        ToolbarBinding.WireCallbacks(context, BuildBindingDeps(), RefreshBindingState)
    end

    return context
end

function ToolbarController.Open(state, options)
    if not windowContext or not windowContext.window or not windowContext.window.frame then
        CreateWindow(state, options)
    else
        windowContext.state = state
        windowContext.options = options
    end

    if windowContext and windowContext.window then
        windowContext.window:SetHeight(GetToolbarWindowHeight())
        EnsureToolbarShellCompositionBinding(windowContext.window)
        EnsureToolbarSectionCompositionBindings(windowContext.groups)
        EnsureToolbarSectionTypographyBindings(windowContext.widgets)
        ApplyToolbarWindowPresentation(windowContext.window)
        PositionWindow(windowContext.window)
    end

    RefreshBindingState()
    FocusWindow(windowContext.window)
end

function ToolbarController.Hide()
    if not windowContext or not windowContext.window then
        return
    end

    if GameTooltip and GameTooltip.Hide then
        GameTooltip:Hide()
    end

    if windowContext.window.Hide then
        windowContext.window:Hide()
    elseif windowContext.window.frame and windowContext.window.frame.Hide then
        windowContext.window.frame:Hide()
    end
end

function ToolbarController.RefreshInteractionModeControls()
    if ToolbarBinding and ToolbarBinding.RefreshInteractionModeControls then
        ToolbarBinding.RefreshInteractionModeControls(windowContext, BuildBindingDeps())
    end
    local canvasToolbar = ns.GUI and ns.GUI.Editor and ns.GUI.Editor.CanvasToolbar
    if canvasToolbar and canvasToolbar.Refresh then
        canvasToolbar.Refresh()
    end
end

function ToolbarController.RefreshCompositionTree()
    if ToolbarBinding and ToolbarBinding.RefreshCompositionTree then
        ToolbarBinding.RefreshCompositionTree(windowContext, BuildBindingDeps())
    end
end

return ToolbarController
