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
local EditorSidebarThemeHelpers = ns.GUI.Editor and ns.GUI.Editor.EditorSidebarThemeHelpers or {}
local ToolbarBinding = ns.GUI.Editor and ns.GUI.Editor.ToolbarBinding

local CreateBodyText = FormWidgets and FormWidgets.CreateBodyText
local CreateActionButton = FormWidgets and FormWidgets.CreateActionButton
local StyleCheckBox = FormWidgets and FormWidgets.StyleCheckBox
local StyleDropdown = FormWidgets and FormWidgets.StyleDropdown
local StyleActionButton = FormWidgets and FormWidgets.StyleActionButton
local ResolveItemColor = FormWidgets and FormWidgets.ResolveItemColor
local ApplySidebarChrome = FormWidgets and FormWidgets.ApplySidebarChrome

local StyleSidebarButton = EditorSidebarThemeHelpers.StyleSidebarButton
local BuildThemeList = EditorSidebarThemeHelpers.BuildThemeList
local GetFirstThemeId = EditorSidebarThemeHelpers.GetFirstThemeId

local windowContext

local TOOLBAR_SECTIONS = {
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

local function BuildBindingDeps()
    return {
        AceGUI = AceGUI,
        L = L,
        C = C,
        KM = KM,
        ns = ns,
        ThemeService = ns.ThemeService or {},
        BuilderUI = ns.GUI and ns.GUI.Helpers and ns.GUI.Helpers.GUIRuntimeHelpers or {},
        CreateBodyText = CreateBodyText,
        CreateActionButton = CreateActionButton,
        StyleCheckBox = StyleCheckBox,
        StyleDropdown = StyleDropdown,
        StyleActionButton = StyleActionButton,
        ResolveItemColor = ResolveItemColor,
        StyleSidebarButton = StyleSidebarButton,
        BuildThemeList = BuildThemeList,
        GetFirstThemeId = GetFirstThemeId,
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
        ApplySidebarChrome(window)
    end
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

    if windowContext.window.Hide then
        windowContext.window:Hide()
    elseif windowContext.window.frame and windowContext.window.frame.Hide then
        windowContext.window.frame:Hide()
    end
end

return ToolbarController
