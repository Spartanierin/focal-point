local _, ns = ...

ns.GUI = ns.GUI or {}
ns.GUI.Editor = ns.GUI.Editor or {}

local AceGUI = LibStub("AceGUI-3.0")
local CanvasToolbar = {}
ns.GUI.Editor.CanvasToolbar = CanvasToolbar

local ToolbarBinding = ns.GUI.Editor and ns.GUI.Editor.ToolbarBinding
local FormWidgets = ns.GUI.Helpers and ns.GUI.Helpers.FormWidgets
local SidebarGeometry = ns.GUI.Editor and ns.GUI.Editor.SidebarGeometry or {}

local TOOLBAR_WIDTH = 662
local TOOLBAR_HEIGHT = 34
local TOOLBAR_TOP_OFFSET = 12
local BUTTON_Y = -6
local INSERT_LABEL_X = 12
local INSERT_TEXT_X = 58
local INSERT_TEXT_WIDTH = 62
local INSERT_DECORATION_X = 124
local INSERT_DECORATION_WIDTH = 94
local INSERT_INDICATOR_X = 222
local INSERT_INDICATOR_WIDTH = 86
local LAYOUT_LABEL_X = 322
local LAYOUT_DROPDOWN_X = 368
local LAYOUT_DROPDOWN_WIDTH = 156
local LAYOUT_ADD_X = 528
local LAYOUT_ADD_WIDTH = 30
local LAYOUT_ACTIVATE_X = 566
local LAYOUT_ACTIVATE_WIDTH = 76

local context
local newLayoutDialog
local indicatorPickerDialog

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
    local used = BuildUsedLayoutNames()
    local baseName = T("LAYOUT_NEW_DEFAULT_BASE", "New Layout")
    if not used[string.lower(baseName)] then
        return baseName
    end

    local index = 2
    while true do
        local candidate = string.format("%s %d", baseName, index)
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
    if dropdown.SetText then
        dropdown:SetText(values[selectedLayoutId] or "")
    end
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

local function ResolveSelectedObjectUnit()
    local objectSelection = ns.GUI and ns.GUI.Editor and ns.GUI.Editor.ObjectSelection or nil
    local selected = objectSelection and type(objectSelection.GetSelectedObject) == "function" and objectSelection.GetSelectedObject() or nil
    if type(selected) == "table" and type(selected.unit) == "string" and selected.unit ~= "" then
        return selected.unit
    end

    local editorState = ns.GUI and ns.GUI.Editor and ns.GUI.Editor.State or nil
    if editorState and type(editorState.GetPrimaryUnit) == "function" then
        return editorState.GetPrimaryUnit()
    end

    local state = editorState and type(editorState.Get) == "function" and editorState.Get() or nil
    return type(state) == "table" and state.selectedUnit or nil
end

local function GetEditableActivePayload()
    local resolver = ns.ActiveLayoutResolver
    if resolver and type(resolver.EnsureEditableActiveLayout) == "function" then
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

local function BuildDecorationMutationContext(unitKey)
    return {
        unitKey = unitKey,
        unit = unitKey,
        unitConfig = ns.UnitFrameUtils and ns.UnitFrameUtils.GetUnitDB and ns.UnitFrameUtils.GetUnitDB(unitKey) or nil,
        getEditablePayload = GetEditableActivePayload,
        getEditableUnitConfig = GetEditableUnitConfig,
    }
end

local function RefreshDecorationInsertResult(unitKey, decorationId)
    local objectSelection = ns.GUI and ns.GUI.Editor and ns.GUI.Editor.ObjectSelection or nil
    if objectSelection and type(objectSelection.SelectObject) == "function" then
        objectSelection.SelectObject({
            kind = "decoration",
            unit = unitKey,
            decorationId = decorationId,
        })
    end

    if type(ns.RefreshUnitFrame) == "function" and type(unitKey) == "string" and unitKey ~= "" then
        ns:RefreshUnitFrame(unitKey)
    end
    RequestEditorRefresh()
end

local function InsertDecoration()
    local unitKey = ResolveSelectedObjectUnit()
    if type(unitKey) ~= "string" or unitKey == "" then
        if ns.Info then
            ns:Info(T("INSERT_DECORATION_STATUS_SELECT_UNIT", "Select a unit first."))
        end
        return
    end

    local mutations = ns.InspectorMutations or (ns.GUI and ns.GUI.Editor and ns.GUI.Editor.Inspector and ns.GUI.Editor.Inspector.Mutations) or nil
    if not (mutations and type(mutations.AddDecoration) == "function") then
        if ns.Info then
            ns:Info(T("INSERT_DECORATION_STATUS_FAILED", "Decoration could not be added."))
        end
        return
    end

    local result = mutations.AddDecoration(BuildDecorationMutationContext(unitKey))
    if not (result and result.ok and result.newDecorationId) then
        if ns.Info then
            ns:Info(T("INSERT_DECORATION_STATUS_FAILED", "Decoration could not be added."))
        end
        return
    end

    RefreshDecorationInsertResult(unitKey, result.newDecorationId)
end

local function CloseIndicatorPickerDialog()
    if indicatorPickerDialog and indicatorPickerDialog.Close then
        indicatorPickerDialog:Close()
    elseif indicatorPickerDialog and indicatorPickerDialog.window and indicatorPickerDialog.window.Hide then
        indicatorPickerDialog.window:Hide()
    end
    indicatorPickerDialog = nil
end

local function GetIndicatorConfig(unitKey, indicatorKey)
    local unitConfig = ns.UnitFrameUtils and ns.UnitFrameUtils.GetUnitDB and ns.UnitFrameUtils.GetUnitDB(unitKey) or nil
    local meta = ns.GUI and ns.GUI.Editor and ns.GUI.Editor.SidebarShared and ns.GUI.Editor.SidebarShared.INDICATOR_META or nil
    local entry = type(meta) == "table" and meta[indicatorKey] or nil
    return type(unitConfig) == "table" and type(entry) == "table" and unitConfig[entry.optionKey] or nil
end

local function BuildIndicatorMutationContext(unitKey)
    local shared = ns.GUI and ns.GUI.Editor and ns.GUI.Editor.SidebarShared or {}
    return {
        unitKey = unitKey,
        unit = unitKey,
        unitConfig = ns.UnitFrameUtils and ns.UnitFrameUtils.GetUnitDB and ns.UnitFrameUtils.GetUnitDB(unitKey) or nil,
        getEditablePayload = GetEditableActivePayload,
        getEditableUnitConfig = GetEditableUnitConfig,
        indicatorMeta = shared.INDICATOR_META,
    }
end

local function SelectIndicator(unitKey, indicatorKey)
    local objectSelection = ns.GUI and ns.GUI.Editor and ns.GUI.Editor.ObjectSelection or nil
    if objectSelection and type(objectSelection.SelectObject) == "function" then
        objectSelection.SelectObject({
            kind = "indicator",
            unit = unitKey,
            indicatorKey = indicatorKey,
        })
    end
    if ns.RefreshUnitFrame and type(unitKey) == "string" and unitKey ~= "" then
        ns:RefreshUnitFrame(unitKey)
    end
    RequestEditorRefresh()
end

local function EnableIndicator(unitKey, indicatorKey)
    local mutations = ns.InspectorMutations or (ns.GUI and ns.GUI.Editor and ns.GUI.Editor.Inspector and ns.GUI.Editor.Inspector.Mutations) or nil
    if not (mutations and type(mutations.SetIndicatorField) == "function") then
        return false
    end
    local result = mutations.SetIndicatorField(BuildIndicatorMutationContext(unitKey), indicatorKey, "enabled", true)
    return result and result.ok ~= false
end

local function AddIndicatorPickerButton(dialog, unitKey, indicatorKey, label)
    local indicatorConfig = GetIndicatorConfig(unitKey, indicatorKey)
    local active = type(indicatorConfig) == "table" and indicatorConfig.enabled ~= false
    local text = active
        and string.format("%s %s", label, T("INSERT_INDICATOR_ACTIVE_SUFFIX", "(Active)"))
        or label
    local buttonWidth = (tonumber(dialog and dialog.contentWidth) or 340) - 18
    local button = FormWidgets and FormWidgets.CreateActionButton
        and FormWidgets.CreateActionButton(text, "secondary", buttonWidth, false)
        or AceGUI:Create("Button")
    button:SetText(text)
    button:SetFullWidth(true)
    button:SetCallback("OnClick", function()
        if active or EnableIndicator(unitKey, indicatorKey) then
            CloseIndicatorPickerDialog()
            SelectIndicator(unitKey, indicatorKey)
        elseif ns.Info then
            ns:Info(T("INSERT_INDICATOR_STATUS_FAILED", "Indicator could not be enabled."))
        end
    end)
    if FormWidgets and FormWidgets.ApplyModalActionButtonVisual then
        FormWidgets.ApplyModalActionButtonVisual(button, active and "utility" or "primary_action")
    end
    dialog.body:AddChild(button)
end

local function OpenIndicatorPicker()
    local unitKey = ResolveSelectedObjectUnit()
    if type(unitKey) ~= "string" or unitKey == "" then
        if ns.Info then
            ns:Info(T("INSERT_INDICATOR_STATUS_SELECT_UNIT", "Select a unit first."))
        end
        return
    end

    local shared = ns.GUI and ns.GUI.Editor and ns.GUI.Editor.SidebarShared or {}
    local indicatorList = type(shared.BuildIndicatorList) == "function" and shared.BuildIndicatorList(unitKey) or {}
    local order = { "RaidTargetIcon", "LeaderIcon", "RoleIcon", "CombatIndicator", "RestingIndicator", "ReadyCheckIndicator", "ClassificationIndicator" }

    CloseIndicatorPickerDialog()
    local dialog = FormWidgets and FormWidgets.CreateCompactFormDialog and FormWidgets.CreateCompactFormDialog({
        title = T("INSERT_INDICATOR_TITLE", "Add Indicator"),
        description = T("INSERT_INDICATOR_DESCRIPTION", "Choose an indicator for the selected unit frame."),
        width = 380,
        height = 430,
        bodyHeight = 260,
    }) or nil
    if not dialog then
        return
    end

    local added = false
    for _, indicatorKey in ipairs(order) do
        local label = indicatorList[indicatorKey]
        if type(label) == "string" and label ~= "" then
            AddIndicatorPickerButton(dialog, unitKey, indicatorKey, label)
            added = true
        end
    end
    if not added then
        local bodyWidth = (tonumber(dialog and dialog.contentWidth) or 340) - 18
        local empty = FormWidgets and FormWidgets.CreateBodyText
            and FormWidgets.CreateBodyText(T("INSERT_INDICATOR_EMPTY", "No indicators are available for this unit."), "description", 12, nil, bodyWidth, false)
            or AceGUI:Create("Label")
        empty:SetText(T("INSERT_INDICATOR_EMPTY", "No indicators are available for this unit."))
        dialog.body:AddChild(empty)
    end

    dialog:SetActions({
        secondary = {
            text = T("INFO_COMMON_CANCEL", "Cancel"),
            role = "utility",
            width = 110,
            onClick = CloseIndicatorPickerDialog,
        },
    })
    dialog.window:SetCallback("OnClose", function()
        if indicatorPickerDialog == dialog then
            indicatorPickerDialog = nil
        end
    end)
    indicatorPickerDialog = dialog
    dialog:Show()
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
        description = T("LAYOUT_CREATE_DESCRIPTION", "Create a blank layout and start from scratch."),
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
        if ns.CreateBlankLayout then
            ok, resultOrReason, createdLayoutId = ns:CreateBlankLayout(nameEdit:GetText(), {
                reason = "create-layout",
            })
        end
        if ok then
            dialog:Close()
            context.selectedLayoutId = createdLayoutId or resultOrReason or ResolveActiveLayoutId()
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
        insertTextButton = CreateButton(T("INSERT_TEXT_BUTTON", "Text"), INSERT_TEXT_WIDTH),
        insertDecorationButton = CreateButton(T("INSERT_DECORATION_BUTTON", "Decoration"), INSERT_DECORATION_WIDTH),
        insertIndicatorButton = CreateButton(T("INSERT_INDICATOR_BUTTON", "Indicator"), INSERT_INDICATOR_WIDTH),
        layoutDropdown = AceGUI:Create("Dropdown"),
        layoutAddButton = CreateButton("+", LAYOUT_ADD_WIDTH),
        layoutActivateButton = CreateButton("Activate", LAYOUT_ACTIVATE_WIDTH),
    }

    AnchorButton(widgets.insertTextButton, host, {
        x = INSERT_TEXT_X,
        width = INSERT_TEXT_WIDTH,
    })
    AnchorButton(widgets.insertDecorationButton, host, {
        x = INSERT_DECORATION_X,
        width = INSERT_DECORATION_WIDTH,
    })
    AnchorButton(widgets.insertIndicatorButton, host, {
        x = INSERT_INDICATOR_X,
        width = INSERT_INDICATOR_WIDTH,
    })
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
        FormWidgets.SetInspectorButtonTooltip(widgets.insertTextButton, T("INSERT_TEXT_TOOLTIP", "Add Text"))
        FormWidgets.SetInspectorButtonTooltip(widgets.insertDecorationButton, T("INSERT_DECORATION_TOOLTIP", "Add Decoration"))
        FormWidgets.SetInspectorButtonTooltip(widgets.insertIndicatorButton, T("INSERT_INDICATOR_TOOLTIP", "Add Indicator"))
        FormWidgets.SetInspectorButtonTooltip(widgets.layoutAddButton, T("LAYOUT_ADD_TOOLTIP", "Add Layout"))
    end

    local insertLabel = host:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    insertLabel:SetPoint("TOPLEFT", host, "TOPLEFT", INSERT_LABEL_X, -10)
    insertLabel:SetWidth(44)
    insertLabel:SetJustifyH("LEFT")
    insertLabel:SetText(T("INSERT_TEXT_GROUP_LABEL", "Insert:"))
    if FormWidgets and FormWidgets.ApplyTextStyle then
        FormWidgets.ApplyTextStyle(insertLabel, "label", 11, 1)
    end
    widgets.insertLabel = insertLabel

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

    if ToolbarBinding then
        if widgets.insertTextButton then
            widgets.insertTextButton:SetCallback("OnClick", function()
                local libraryWindow = ns.GUI
                    and ns.GUI.Editor
                    and ns.GUI.Editor.TextTemplateLibraryWindow
                    or nil
                if libraryWindow and libraryWindow.Open then
                    libraryWindow.Open()
                end
            end)
        end
        if widgets.insertDecorationButton then
            widgets.insertDecorationButton:SetCallback("OnClick", InsertDecoration)
        end
        if widgets.insertIndicatorButton then
            widgets.insertIndicatorButton:SetCallback("OnClick", OpenIndicatorPicker)
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
