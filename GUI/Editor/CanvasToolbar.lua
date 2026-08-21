local _, ns = ...

ns.GUI = ns.GUI or {}
ns.GUI.Editor = ns.GUI.Editor or {}

local AceGUI = LibStub("AceGUI-3.0")
local CanvasToolbar = {}
ns.GUI.Editor.CanvasToolbar = CanvasToolbar

local ToolbarBinding = ns.GUI.Editor and ns.GUI.Editor.ToolbarBinding
local FormWidgets = ns.GUI.Helpers and ns.GUI.Helpers.FormWidgets
local SidebarGeometry = ns.GUI.Editor and ns.GUI.Editor.SidebarGeometry or {}

local TOOLBAR_WIDTH = 248
local TOOLBAR_HEIGHT = 34
local TOOLBAR_TOP_OFFSET = 12
local BUTTON_Y = -6

local BUTTONS = {
    unlock = { width = 100, x = 8 },
    frame = { width = 62, x = 114 },
    text = { width = 62, x = 182 },
}

local context

local function BuildBindingDeps()
    local editorSidebarThemeHelpers = ns.GUI and ns.GUI.Editor and ns.GUI.Editor.EditorSidebarThemeHelpers or {}
    return {
        AceGUI = AceGUI,
        L = ns.L or {},
        C = ns.Constants or {},
        KM = ns.KeyMap or {},
        ns = ns,
        ThemeService = ns.ThemeService or {},
        PresetService = ns.PresetService or {},
        ProfileLayoutService = ns.ProfileLayoutService or {},
        BuilderUI = ns.GUI and ns.GUI.Helpers and ns.GUI.Helpers.GUIRuntimeHelpers or {},
        CreateBodyText = FormWidgets and FormWidgets.CreateBodyText,
        CreateActionButton = FormWidgets and FormWidgets.CreateActionButton,
        StyleCheckBox = FormWidgets and FormWidgets.StyleCheckBox,
        StyleDropdown = FormWidgets and FormWidgets.StyleDropdown,
        StyleEditBox = FormWidgets and FormWidgets.StyleEditBox,
        StyleActionButton = FormWidgets and FormWidgets.StyleActionButton,
        ResolveItemColor = FormWidgets and FormWidgets.ResolveItemColor,
        ApplyWindowChrome = FormWidgets and FormWidgets.ApplyWindowChrome,
        EnsureStandardWindowCloseButton = FormWidgets and FormWidgets.EnsureStandardWindowCloseButton,
        StyleSidebarButton = editorSidebarThemeHelpers.StyleSidebarButton,
    }
end

local function RequestEditorRefresh()
    if ns.GUI and ns.GUI.RequestRefreshOptions then
        ns.GUI:RequestRefreshOptions()
    end
end

local function CreateButton(label, width)
    local createActionButton = FormWidgets and FormWidgets.CreateActionButton
    local button = createActionButton and createActionButton(label, "secondary", width, false) or AceGUI:Create("Button")
    button:SetText(label)
    button:SetWidth(width)
    return button
end

local function AnchorButton(button, parent, layout)
    if not button or not button.frame or not parent or not layout then
        return
    end

    button.frame:SetParent(parent)
    button.frame:ClearAllPoints()
    button.frame:SetPoint("TOPLEFT", parent, "TOPLEFT", layout.x, BUTTON_Y)
    button.frame:SetWidth(layout.width)
    button.frame:SetHeight(24)
    button.frame:Show()
end

local function EnsureHost()
    if context and context.host then
        return context
    end

    local parent = ns.guiEditorWorkspaceLayer
    if not parent then
        return nil
    end

    local host = CreateFrame("Frame", nil, parent)
    host:SetSize(TOOLBAR_WIDTH, TOOLBAR_HEIGHT)
    host:SetFrameStrata("DIALOG")
    host:SetFrameLevel(140)
    host:EnableMouse(true)
    host:Hide()

    local bg = host:CreateTexture(nil, "BACKGROUND")
    bg:SetPoint("TOPLEFT", host, "TOPLEFT", 0, 0)
    bg:SetPoint("BOTTOMRIGHT", host, "BOTTOMRIGHT", 0, 0)
    bg:SetColorTexture(0.035, 0.04, 0.045, 0.88)
    host.bg = bg

    local border = host:CreateTexture(nil, "BORDER")
    border:SetPoint("TOPLEFT", host, "TOPLEFT", 0, 0)
    border:SetPoint("BOTTOMRIGHT", host, "BOTTOMRIGHT", 0, 0)
    border:SetColorTexture(0.92, 0.46, 0, 0.34)
    host.border = border

    local inset = host:CreateTexture(nil, "ARTWORK")
    inset:SetPoint("TOPLEFT", host, "TOPLEFT", 1, -1)
    inset:SetPoint("BOTTOMRIGHT", host, "BOTTOMRIGHT", -1, 1)
    inset:SetColorTexture(0.05, 0.055, 0.06, 0.92)
    host.inset = inset

    local widgets = {
        unlockButton = CreateButton("Unlock", BUTTONS.unlock.width),
        frameModeButton = CreateButton("Frame", BUTTONS.frame.width),
        textModeButton = CreateButton("Text", BUTTONS.text.width),
    }

    AnchorButton(widgets.unlockButton, host, BUTTONS.unlock)
    AnchorButton(widgets.frameModeButton, host, BUTTONS.frame)
    AnchorButton(widgets.textModeButton, host, BUTTONS.text)

    context = {
        host = host,
        widgets = widgets,
        options = {
            onGlobalChanged = RequestEditorRefresh,
        },
    }

    local deps = BuildBindingDeps()
    if ToolbarBinding then
        if widgets.unlockButton then
            widgets.unlockButton:SetCallback("OnClick", function()
                if ToolbarBinding.HandleToggleUnlock then
                    ToolbarBinding.HandleToggleUnlock(context, deps)
                end
                CanvasToolbar.Refresh()
            end)
        end
        if widgets.frameModeButton then
            widgets.frameModeButton:SetCallback("OnClick", function()
                if ToolbarBinding.HandleSetFrameMode then
                    ToolbarBinding.HandleSetFrameMode(deps)
                end
                CanvasToolbar.Refresh()
            end)
        end
        if widgets.textModeButton then
            widgets.textModeButton:SetCallback("OnClick", function()
                if ToolbarBinding.HandleSetTextMode then
                    ToolbarBinding.HandleSetTextMode(deps)
                end
                CanvasToolbar.Refresh()
            end)
        end
    end

    return context
end

local function ResolveCanvasCenterOffset()
    local leftWidth = (ns.guiEditorToolbarLayer and ns.guiEditorToolbarLayer.GetWidth and ns.guiEditorToolbarLayer:GetWidth())
        or SidebarGeometry.width
        or 285
    local rightWidth = SidebarGeometry.inspectorWidth or SidebarGeometry.width or 315
    return math.floor(((leftWidth or 0) - (rightWidth or 0)) * 0.5)
end

function CanvasToolbar.UpdateGeometry()
    local current = EnsureHost()
    if not current or not current.host then
        return
    end

    local parent = ns.guiEditorWorkspaceLayer or UIParent
    current.host:SetParent(parent)
    current.host:ClearAllPoints()
    current.host:SetPoint("TOP", parent, "TOP", ResolveCanvasCenterOffset(), -TOOLBAR_TOP_OFFSET)
    current.host:SetSize(TOOLBAR_WIDTH, TOOLBAR_HEIGHT)
end

function CanvasToolbar.Refresh()
    local current = EnsureHost()
    if not current or not ToolbarBinding then
        return
    end

    local deps = BuildBindingDeps()
    if ToolbarBinding.RefreshUnlockControl then
        ToolbarBinding.RefreshUnlockControl(current.widgets.unlockButton, deps)
    end
    if ToolbarBinding.RefreshInteractionModeControlPair then
        ToolbarBinding.RefreshInteractionModeControlPair(
            current.widgets.frameModeButton,
            current.widgets.textModeButton,
            deps
        )
    end
end

function CanvasToolbar.Show()
    local current = EnsureHost()
    if not current or not current.host then
        return
    end

    CanvasToolbar.UpdateGeometry()
    CanvasToolbar.Refresh()
    current.host:Show()
end

function CanvasToolbar.Hide()
    if context and context.host then
        context.host:Hide()
    end
end

return CanvasToolbar
