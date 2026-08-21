local _, ns = ...

ns.GUI = ns.GUI or {}
ns.GUI.Editor = ns.GUI.Editor or {}

local AceGUI = LibStub("AceGUI-3.0")
local CanvasToolbar = {}
ns.GUI.Editor.CanvasToolbar = CanvasToolbar

local ToolbarBinding = ns.GUI.Editor and ns.GUI.Editor.ToolbarBinding
local FormWidgets = ns.GUI.Helpers and ns.GUI.Helpers.FormWidgets
local SidebarGeometry = ns.GUI.Editor and ns.GUI.Editor.SidebarGeometry or {}

local TOOLBAR_WIDTH = 596
local TOOLBAR_HEIGHT = 34
local TOOLBAR_TOP_OFFSET = 12
local BUTTON_Y = -6
local LAYOUT_LABEL_X = 268
local LAYOUT_DROPDOWN_X = 314
local LAYOUT_DROPDOWN_WIDTH = 156
local LAYOUT_ADD_X = 474
local LAYOUT_ADD_WIDTH = 30
local LAYOUT_ACTIVATE_X = 512
local LAYOUT_ACTIVATE_WIDTH = 76

local BUTTONS = {
    unlock = { width = 100, x = 8 },
    frame = { width = 62, x = 114 },
    text = { width = 62, x = 182 },
}

local context
local newLayoutDialog

local function T(key, fallback)
    local L = ns.L or {}
    local value = L[key]
    return type(value) == "string" and value ~= "" and value or fallback or key
end

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

local function AnchorWidget(widget, parent, layout)
    if not widget or not widget.frame or not parent or not layout then
        return
    end

    widget.frame:SetParent(parent)
    widget.frame:ClearAllPoints()
    widget.frame:SetPoint("TOPLEFT", parent, "TOPLEFT", layout.x, layout.y or BUTTON_Y)
    widget.frame:SetWidth(layout.width)
    widget.frame:SetHeight(layout.height or 24)
    widget.frame:Show()
end

local function AnchorButton(button, parent, layout)
    AnchorWidget(button, parent, layout)
end

local function IsProductLayoutSource(source)
    return source == "builtin" or source == "userLayout"
end

local function ResolveActiveLayoutId()
    local resolver = ns.ActiveLayoutResolver or {}
    if resolver.GetStoredActiveLayoutId then
        return resolver.GetStoredActiveLayoutId(ns.db)
    end
    local char = ns.db and ns.db.char or nil
    return type(char) == "table" and rawget(char, "activeLayoutId") or nil
end

local function ResolveLayoutDisplayName(layout)
    if type(layout) ~= "table" then
        return ""
    end
    local L = ns.L or {}
    if type(layout.labelKey) == "string" and L[layout.labelKey] then
        return L[layout.labelKey]
    end
    if type(layout.name) == "string" and layout.name ~= "" then
        return layout.name
    end
    return type(layout.id) == "string" and layout.id or ""
end

local function Trim(value)
    if type(value) ~= "string" then
        return ""
    end
    return (value:gsub("^%s+", ""):gsub("%s+$", ""))
end

local function BuildUsedLayoutNames()
    local layoutService = ns.LayoutService or {}
    local layouts = layoutService.ListLayoutSummaries and layoutService.ListLayoutSummaries({ db = ns.db }) or {}
    local used = {}
    for _, layout in ipairs(layouts) do
        if type(layout) == "table" and IsProductLayoutSource(layout.source) then
            local name = ResolveLayoutDisplayName(layout)
            name = Trim(name)
            if name ~= "" then
                used[string.lower(name)] = true
            end
        end
    end
    return used
end

local function ResolveDefaultNewLayoutName()
    local activeName = context and context.activeLayoutName or ""
    if activeName == "" then
        local resolver = ns.ActiveLayoutResolver or {}
        local envelope = resolver.GetActiveLayout and resolver.GetActiveLayout(ns.db) or nil
        activeName = ResolveLayoutDisplayName(envelope)
    end
    activeName = activeName ~= "" and activeName or T("LAYOUT_NEW_DEFAULT_BASE", "New Layout")

    local used = BuildUsedLayoutNames()
    local baseName = activeName .. " Copy"
    if not used[string.lower(baseName)] then
        return baseName
    end

    local index = 2
    while true do
        local candidate = string.format("%s Copy %d", activeName, index)
        if not used[string.lower(candidate)] then
            return candidate
        end
        index = index + 1
    end
end

local function BuildLayoutDropdownData(selectedLayoutId)
    local layoutService = ns.LayoutService or {}
    local layouts = layoutService.ListLayoutSummaries and layoutService.ListLayoutSummaries({ db = ns.db }) or {}
    local activeLayoutId = ResolveActiveLayoutId()
    local values = {}
    local order = {}
    local known = {}
    local activeName = ""

    for _, source in ipairs({ "userLayout", "builtin" }) do
        for _, layout in ipairs(layouts) do
            local layoutId = type(layout) == "table" and layout.id or nil
            if IsProductLayoutSource(layout and layout.source) and layout.source == source and type(layoutId) == "string" and layoutId ~= "" then
                local name = ResolveLayoutDisplayName(layout)
                local prefix = source == "userLayout" and "My: " or "Built-in: "
                local label = prefix .. name
                if layoutId == activeLayoutId then
                    label = label .. " (Active)"
                    activeName = name
                end
                values[layoutId] = label
                order[#order + 1] = layoutId
                known[layoutId] = true
            end
        end
    end

    if type(selectedLayoutId) ~= "string" or not known[selectedLayoutId] then
        selectedLayoutId = known[activeLayoutId] and activeLayoutId or order[1]
    end

    return values, order, selectedLayoutId, activeLayoutId, activeName
end

local function RefreshLayoutControls(current)
    if not current or not current.widgets then
        return
    end

    local dropdown = current.widgets.layoutDropdown
    local activateButton = current.widgets.layoutActivateButton
    if not dropdown or not activateButton then
        return
    end

    local values, order, selectedLayoutId, activeLayoutId, activeName = BuildLayoutDropdownData(current.selectedLayoutId)
    current.selectedLayoutId = selectedLayoutId
    current.activeLayoutId = activeLayoutId
    current.activeLayoutName = activeName

    current._suspendLayoutCallbacks = true
    dropdown:SetList(values, order)
    dropdown:SetValue(selectedLayoutId)
    dropdown:SetDisabled(#order == 0)
    current._suspendLayoutCallbacks = false

    if current.widgets.layoutLabel then
        current.widgets.layoutLabel:SetText("Layout:")
    end
    if current.widgets.layoutActiveLabel then
        current.widgets.layoutActiveLabel:SetText(activeName ~= "" and activeName or "")
    end

    activateButton:SetText("Activate")
    activateButton:SetDisabled(type(selectedLayoutId) ~= "string" or selectedLayoutId == "" or selectedLayoutId == activeLayoutId)
    local addDisabled = type(activeLayoutId) ~= "string" or activeLayoutId == ""
    if current.widgets.layoutAddButton then
        current.widgets.layoutAddButton:SetDisabled(addDisabled)
    end

    if FormWidgets and FormWidgets.StyleDropdown then
        FormWidgets.StyleDropdown(dropdown, "editor_inset")
    end
    if FormWidgets and FormWidgets.ApplyModalActionButtonVisual and current.widgets.layoutAddButton then
        FormWidgets.ApplyModalActionButtonVisual(current.widgets.layoutAddButton, "utility")
    end
    if FormWidgets and FormWidgets.ApplyInspectorGlyphButton and current.widgets.layoutAddButton then
        FormWidgets.ApplyInspectorGlyphButton(current.widgets.layoutAddButton, "+", addDisabled)
    elseif current.widgets.layoutAddButton then
        current.widgets.layoutAddButton:SetText("+")
    end
    if FormWidgets and FormWidgets.ApplyModalActionButtonVisual then
        FormWidgets.ApplyModalActionButtonVisual(activateButton, "primary_action")
    end
end

local function HasDirtyTextBuilderDraft()
    local textBuilder = ns.GUI and ns.GUI.Pages and ns.GUI.Pages.TextBuilder or nil
    return textBuilder and textBuilder.HasUnsavedChanges and textBuilder.HasUnsavedChanges() == true
end

local function ReportLayoutActivationResult(ok, reason)
    if ok then
        return
    end
    if reason == "pending" then
        if ns.Info then
            ns:Info("Layout activation is pending until combat ends.")
        end
        return
    end
    if reason and reason ~= "same-layout" and ns.Info then
        ns:Info("Layout activation failed: " .. tostring(reason))
    end
end

local function ResolveCreateLayoutStatus(reason)
    if reason == "name-required" then
        return T("LAYOUT_CREATE_NAME_REQUIRED", "Please enter a layout name.")
    end
    if reason == "name-too-long" then
        return T("LAYOUT_CREATE_NAME_TOO_LONG", "Layout name is too long.")
    end
    if reason == "duplicate-name" then
        return T("LAYOUT_CREATE_NAME_EXISTS", "A layout with this name already exists.")
    end
    if reason == "combat-blocked" then
        return T("LAYOUT_CREATE_COMBAT_BLOCKED", "Create layouts outside combat.")
    end
    if reason == "dirty-text-builder" then
        return T("LAYOUT_CREATE_DIRTY_TEXT_BUILDER", "Save or discard Text Builder changes before creating a layout.")
    end
    if reason == "activation-failed" then
        return T("LAYOUT_CREATE_ACTIVATION_FAILED", "The layout was created, but could not be activated.")
    end
    return T("LAYOUT_CREATE_FAILED", "Layout could not be created.")
end

local function CloseNewLayoutDialog()
    if newLayoutDialog and newLayoutDialog.Close then
        newLayoutDialog:Close()
    elseif newLayoutDialog and newLayoutDialog.window and newLayoutDialog.window.Hide then
        newLayoutDialog.window:Hide()
    end
end

local function FocusDialogEditBox(editBox)
    local native = editBox and editBox.editbox or nil
    if native and native.SetFocus then
        native:SetFocus()
    end
    if native and native.HighlightText then
        native:HighlightText()
    end
end

local function OpenNewLayoutDialog()
    CloseNewLayoutDialog()

    local dialog = FormWidgets and FormWidgets.CreateCompactFormDialog and FormWidgets.CreateCompactFormDialog({
        title = T("LAYOUT_CREATE_TITLE", "New Layout"),
        description = T("LAYOUT_CREATE_DESCRIPTION", "Create a new layout from the currently active layout."),
        width = 420,
        height = 220,
        bodyHeight = 62,
    }) or nil
    if not dialog then
        return
    end

    local nameEdit = AceGUI:Create("EditBox")
    nameEdit:SetLabel(T("LAYOUT_CREATE_NAME", "Name"))
    nameEdit:SetFullWidth(true)
    nameEdit:SetText(ResolveDefaultNewLayoutName())
    if FormWidgets and FormWidgets.StyleEditBox then
        FormWidgets.StyleEditBox(nameEdit, "editor_inset")
    end
    dialog.body:AddChild(nameEdit)

    local function setStatus(message)
        dialog:SetStatus(message)
    end

    local function updateCreateButton()
        if dialog.primaryButton then
            dialog.primaryButton:SetDisabled(Trim(nameEdit:GetText() or "") == "")
        end
    end

    local function confirm()
        if HasDirtyTextBuilderDraft() then
            setStatus(ResolveCreateLayoutStatus("dirty-text-builder"))
            return
        end

        local ok, resultOrReason, createdLayoutId = false, "create-unavailable", nil
        if ns.CreateLayoutFromActive then
            ok, resultOrReason, createdLayoutId = ns:CreateLayoutFromActive(nameEdit:GetText(), {
                reason = "create-layout",
            })
        end
        if ok then
            dialog:Close()
            context.selectedLayoutId = ResolveActiveLayoutId()
            CanvasToolbar.Refresh()
            return
        end

        local reason = resultOrReason
        if createdLayoutId and resultOrReason ~= "pending" then
            reason = "activation-failed"
        end
        setStatus(ResolveCreateLayoutStatus(reason))
        updateCreateButton()
        CanvasToolbar.Refresh()
    end

    nameEdit:SetCallback("OnTextChanged", function()
        setStatus("")
        updateCreateButton()
    end)
    nameEdit:SetCallback("OnEnterPressed", function()
        if Trim(nameEdit:GetText() or "") ~= "" then
            confirm()
        end
    end)

    dialog:SetActions({
        secondary = {
            text = T("INFO_COMMON_CANCEL", "Cancel"),
            role = "utility",
            width = 110,
            onClick = CloseNewLayoutDialog,
        },
        primary = {
            text = T("LAYOUT_CREATE_CONFIRM", "Create"),
            role = "primary_action",
            width = 120,
            onClick = confirm,
        },
    })

    dialog.window:SetCallback("OnClose", function()
        newLayoutDialog = nil
    end)

    newLayoutDialog = dialog
    newLayoutDialog.nameEdit = nameEdit
    updateCreateButton()
    dialog:Show()
    FocusDialogEditBox(nameEdit)
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
        layoutDropdown = AceGUI:Create("Dropdown"),
        layoutAddButton = CreateButton("+", LAYOUT_ADD_WIDTH),
        layoutActivateButton = CreateButton("Activate", LAYOUT_ACTIVATE_WIDTH),
    }

    AnchorButton(widgets.unlockButton, host, BUTTONS.unlock)
    AnchorButton(widgets.frameModeButton, host, BUTTONS.frame)
    AnchorButton(widgets.textModeButton, host, BUTTONS.text)
    AnchorWidget(widgets.layoutDropdown, host, {
        x = LAYOUT_DROPDOWN_X,
        y = -5,
        width = LAYOUT_DROPDOWN_WIDTH,
        height = 26,
    })
    AnchorButton(widgets.layoutActivateButton, host, {
        x = LAYOUT_ACTIVATE_X,
        width = LAYOUT_ACTIVATE_WIDTH,
    })
    AnchorButton(widgets.layoutAddButton, host, {
        x = LAYOUT_ADD_X,
        width = LAYOUT_ADD_WIDTH,
    })
    if FormWidgets and FormWidgets.SetInspectorButtonTooltip then
        FormWidgets.SetInspectorButtonTooltip(widgets.layoutAddButton, T("LAYOUT_ADD_TOOLTIP", "Add Layout"))
    end

    local separator = host:CreateTexture(nil, "ARTWORK")
    separator:SetPoint("TOPLEFT", host, "TOPLEFT", 252, -7)
    separator:SetSize(1, 20)
    separator:SetColorTexture(0.92, 0.46, 0, 0.42)
    host.separator = separator

    local layoutLabel = host:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    layoutLabel:SetPoint("TOPLEFT", host, "TOPLEFT", LAYOUT_LABEL_X, -10)
    layoutLabel:SetWidth(44)
    layoutLabel:SetJustifyH("LEFT")
    layoutLabel:SetText("Layout:")
    if FormWidgets and FormWidgets.ApplyTextStyle then
        FormWidgets.ApplyTextStyle(layoutLabel, "label", 11, 1)
    end
    widgets.layoutLabel = layoutLabel

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
        if widgets.layoutDropdown then
            widgets.layoutDropdown:SetCallback("OnValueChanged", function(_, _, value)
                if context._suspendLayoutCallbacks then
                    return
                end
                context.selectedLayoutId = value
                RefreshLayoutControls(context)
            end)
        end
        if widgets.layoutAddButton then
            widgets.layoutAddButton:SetCallback("OnClick", function()
                OpenNewLayoutDialog()
            end)
        end
        if widgets.layoutActivateButton then
            widgets.layoutActivateButton:SetCallback("OnClick", function()
                if HasDirtyTextBuilderDraft() then
                    if ns.Info then
                        ns:Info("Save or discard Text Builder changes before activating another layout.")
                    end
                    return
                end
                local layoutId = context.selectedLayoutId
                if type(layoutId) ~= "string" or layoutId == "" or layoutId == ResolveActiveLayoutId() then
                    RefreshLayoutControls(context)
                    return
                end
                local ok, reason = false, "activate-unavailable"
                if ns.ActivateLayout then
                    ok, reason = ns:ActivateLayout(layoutId, "canvas-toolbar")
                end
                if ok then
                    context.selectedLayoutId = ResolveActiveLayoutId()
                end
                ReportLayoutActivationResult(ok, reason)
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
    RefreshLayoutControls(current)
    local layoutManager = ns.GUI and ns.GUI.Editor and ns.GUI.Editor.LayoutManager
    if layoutManager and layoutManager.Refresh then
        layoutManager.Refresh()
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
