local _, ns = ...

ns.GUI = ns.GUI or {}
ns.GUI.Editor = ns.GUI.Editor or {}

local AceGUI = LibStub("AceGUI-3.0")
local CanvasToolbar = {}
ns.GUI.Editor.CanvasToolbar = CanvasToolbar

local ToolbarBinding = ns.GUI.Editor and ns.GUI.Editor.ToolbarBinding
local FormWidgets = ns.GUI.Helpers and ns.GUI.Helpers.FormWidgets

local TOOLBAR_WIDTH = 856
local TOOLBAR_HEIGHT = 50
local TOOLBAR_TOP_OFFSET = 12
local BUTTON_Y = -6
local INSERT_LABEL_X = 12
local INSERT_ADD_OBJECT_X = 58
local INSERT_ADD_OBJECT_WIDTH = 142
local LAYOUT_LABEL_X = 224
local LAYOUT_DROPDOWN_X = 270
local LAYOUT_DROPDOWN_WIDTH = 156
local LAYOUT_ADD_X = 430
local LAYOUT_ADD_WIDTH = 30
local LAYOUT_ACTIVATE_X = 468
local LAYOUT_MANAGE_WIDTH = 148
local OPTIONS_X = 620
local OPTIONS_WIDTH = 28
local PRESENTATION_X = 654
local PRESENTATION_WIDTH = 108
local CLOSE_X = 770
local CLOSE_WIDTH = 70

local context
local newLayoutDialog
local addObjectPickerDialog
local entityAddOriginToken

local function GetChromeColors()
    local skins = ns.GUI and ns.GUI.Skins or nil
    local palette = skins and skins.GetFormPalette and skins.GetFormPalette() or {}
    return palette.Chrome or {}
end

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

local function RequestEditorRefresh(reason)
    if ns.GUI and ns.GUI.RequestRefreshOptions then
        ns.GUI:RequestRefreshOptions(reason or "CanvasToolbar")
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
    local layoutService = ns.LayoutService or {}
    if layoutService.GetDisplayName then
        return layoutService.GetDisplayName(layout)
    end
    return type(layout) == "table" and (layout.name or layout.id) or ""
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

local function BuildLayoutDropdownData()
    local layoutService = ns.LayoutService or {}
    local layouts = layoutService.ListLayoutSummaries and layoutService.ListLayoutSummaries({ db = ns.db }) or {}
    local activeLayoutId = ResolveActiveLayoutId()
    local assignments = ns.LayoutAssignmentService or {}
    local defaultId = assignments.GetAccountDefaultLayoutId and assignments.GetAccountDefaultLayoutId(ns.db)
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
                if layoutId == defaultId then
                    label = label .. T("LAYOUT_ACCOUNT_DEFAULT_MARKER", " [Default]")
                end
                if layoutId == activeLayoutId then
                    activeName = name
                end
                values[layoutId] = label
                order[#order + 1] = layoutId
                known[layoutId] = true
            end
        end
    end

    return values, order, known[activeLayoutId] and activeLayoutId or order[1], activeLayoutId, activeName
end

local function ResolveLayoutNameById(layoutId)
    if type(layoutId) ~= "string" or layoutId == "" then
        return ""
    end

    local layoutService = ns.LayoutService or {}
    local layouts = layoutService.ListLayoutSummaries and layoutService.ListLayoutSummaries({ db = ns.db }) or {}
    for _, layout in ipairs(layouts) do
        if type(layout) == "table" and layout.id == layoutId then
            return ResolveLayoutDisplayName(layout)
        end
    end
    return layoutId
end

local function ResolveCurrentSpecAssignment()
    local service = ns.LayoutAssignmentService or {}
    if type(service.GetAssignmentForCurrentSpecialization) ~= "function" then
        return nil
    end

    local layoutId, status, specID, specName = service.GetAssignmentForCurrentSpecialization(ns.db)
    if status ~= "ok" or type(layoutId) ~= "string" or layoutId == "" then
        return nil
    end

    return {
        layoutId = layoutId,
        layoutName = ResolveLayoutNameById(layoutId),
        specID = specID,
        specName = type(specName) == "string" and specName ~= "" and specName or nil,
    }
end

local function ReportManualAutomationMismatch(selectedLayoutId)
    local assignment = ResolveCurrentSpecAssignment()
    if not assignment or assignment.layoutId == selectedLayoutId then
        return
    end
    if ns.Info then
        local assignedName = assignment.layoutName
        if type(assignedName) ~= "string" or assignedName == "" then
            assignedName = assignment.layoutId
        end
        ns:Info(string.format(
            T("LAYOUT_ASSIGNMENT_MANUAL_MISMATCH_HINT", "This specialization is assigned to \"%s\". The assigned layout may be restored automatically."),
            assignedName
        ))
    end
end

local function RefreshLayoutControls(current)
    if not current or not current.widgets then
        return
    end

    local dropdown = current.widgets.layoutDropdown
    local manageButton = current.widgets.layoutManageButton
    if not dropdown or not manageButton then
        return
    end

    local values, order, selectedLayoutId, activeLayoutId, activeName = BuildLayoutDropdownData()
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
    if current.widgets.layoutAutomationLabel then
        local assignment = ResolveCurrentSpecAssignment()
        if assignment then
            local assignedName = assignment.layoutName
            if type(assignedName) ~= "string" or assignedName == "" then
                assignedName = assignment.layoutId
            end
            local text
            if assignment.layoutId == activeLayoutId then
                text = T("LAYOUT_ASSIGNMENT_STATUS_ACTIVE", "Active via Specialization Automation")
            else
                text = string.format(T("LAYOUT_ASSIGNMENT_STATUS_ASSIGNED", "Assigned via Specialization: %s"), assignedName)
            end
            current.widgets.layoutAutomationLabel:SetText(text)
            current.widgets.layoutAutomationLabel:Show()
        else
            current.widgets.layoutAutomationLabel:SetText("")
            current.widgets.layoutAutomationLabel:Hide()
        end
    end

    manageButton:SetText("Manage Layouts")
    manageButton:SetDisabled(false)
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
        FormWidgets.ApplyModalActionButtonVisual(manageButton, "utility")
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
    if resolver and type(resolver.EnsureEditableForMutation) == "function" then
        local payload = resolver.EnsureEditableForMutation and resolver.EnsureEditableForMutation(ns.db)
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

local function ResolveUnitLabel(unitKey)
    local keyMap = ns.KeyMap and ns.KeyMap.Units or nil
    if ns.GetLabel and keyMap then
        return ns.GetLabel(keyMap, unitKey) or unitKey
    end
    return unitKey
end

local function CustomizeAddedChild(selected)
    local state = ns.GUI.Editor.State
    local controller = ns.GUI.Editor.Controller
    if selected and state and state.IsArrange and state.IsArrange()
        and controller and controller.SetPresentation then
        controller.SetPresentation("customize")
    end
end

local function RefreshDecorationInsertResult(unitKey, decorationId)
    local objectSelection = ns.GUI and ns.GUI.Editor and ns.GUI.Editor.ObjectSelection or nil
    local selected
    if objectSelection and type(objectSelection.SelectObject) == "function" then
        selected = objectSelection.SelectObject({
            kind = "decoration",
            unit = unitKey,
            decorationId = decorationId,
        })
    end

    if type(ns.RefreshUnitFrame) == "function" and type(unitKey) == "string" and unitKey ~= "" then
        ns:RefreshUnitFrame(unitKey)
    end
    CustomizeAddedChild(selected)
    RequestEditorRefresh()
end

local function InsertDecoration(request)
    local unitKey = request and request.unitKey or ResolveSelectedObjectUnit()
    local mutations = ns.InspectorMutations or (ns.GUI and ns.GUI.Editor and ns.GUI.Editor.Inspector and ns.GUI.Editor.Inspector.Mutations) or nil
    local workflow = ns.LayoutEditWorkflow
    if type(unitKey) ~= "string" or not (mutations and mutations.AddDecoration and workflow and workflow.RequestEditableLayoutForMutation) then return end
    workflow.RequestEditableLayoutForMutation(function()
        if request and not request.isCurrent(true) then return end
        local result = mutations.AddDecoration(BuildDecorationMutationContext(unitKey))
        if result and result.ok and result.newDecorationId then
            RefreshDecorationInsertResult(unitKey, result.newDecorationId)
        elseif ns.Info then
            ns:Info(T("INSERT_DECORATION_STATUS_FAILED", "Decoration could not be added."))
        end
    end)
end

local ADD_OBJECT_BAR_CAPABILITIES = {
    { componentKey = "PowerBar", labelKey = "EDITOR_ADD_POWER_BAR_BUTTON", fallback = "Power Bar" },
    { componentKey = "CastBar", labelKey = "EDITOR_ADD_CAST_BAR_BUTTON", fallback = "Cast Bar" },
    { componentKey = "ClassPowerBar", labelKey = "EDITOR_ADD_CLASS_POWER_BAR_BUTTON", fallback = "Add Class Power Bar", playerOnly = true },
    { componentKey = "AlternativePowerBar", labelKey = "EDITOR_ADD_ALTERNATIVE_POWER_BAR_BUTTON", fallback = "Add Secondary Resource Bar", playerOnly = true },
    { componentKey = "NormalAbsorbBar", labelKey = "EDITOR_ADD_NORMAL_ABSORB_BAR_BUTTON", fallback = "Normal Absorb" },
    { componentKey = "HealingAbsorbBar", labelKey = "EDITOR_ADD_HEALING_ABSORB_BAR_BUTTON", fallback = "Healing Absorb" },
}

local ADD_OBJECT_VISUAL_CAPABILITIES = {
    { componentKey = "Portrait", labelKey = "EDITOR_ADD_PORTRAIT_BUTTON", fallback = "Portrait" },
    { componentKey = "RaidTargetIcon", labelKey = "EDITOR_ADD_RAID_TARGET_ICON_BUTTON", fallback = "Raid Target" },
    { componentKey = "LeaderIcon", labelKey = "EDITOR_ADD_LEADER_ICON_BUTTON", fallback = "Leader" },
    { componentKey = "RoleIcon", labelKey = "EDITOR_ADD_ROLE_ICON_BUTTON", fallback = "Role" },
    { componentKey = "CombatIndicator", labelKey = "EDITOR_ADD_COMBAT_INDICATOR_BUTTON", fallback = "Combat" },
    { componentKey = "RestingIndicator", labelKey = "EDITOR_ADD_RESTING_INDICATOR_BUTTON", fallback = "Resting" },
    { componentKey = "ReadyCheckIndicator", labelKey = "EDITOR_ADD_READY_CHECK_INDICATOR_BUTTON", fallback = "Ready Check" },
    { componentKey = "ClassificationIndicator", labelKey = "ELEMENT_CLASSIFICATION_INDICATOR", fallback = "Classification" },
}

local ADD_OBJECT_AURA_CAPABILITIES = {
    { componentKey = "Buffs", labelKey = "AURA_BUFFS", fallback = "Buffs" },
    { componentKey = "Debuffs", labelKey = "AURA_DEBUFFS", fallback = "Debuffs" },
}

local ADD_OBJECT_UNIT_CAPABILITIES = {
    { unitKey = "pet" },
    { unitKey = "targettarget" },
    { unitKey = "focus" },
    { unitKey = "focustarget" },
    { unitKey = "boss", labelKey = "ADD_OBJECT_UNIT_BOSS_FRAMES_BUTTON", fallback = "Boss Frames" },
}

local function CloseAddObjectPickerDialog()
    if addObjectPickerDialog and addObjectPickerDialog.Close then
        addObjectPickerDialog:Close()
    elseif addObjectPickerDialog and addObjectPickerDialog.window and addObjectPickerDialog.window.Hide then
        addObjectPickerDialog.window:Hide()
    end
    addObjectPickerDialog = nil
end

local function IsSingletonComponentPresent(unitKey, kind, componentKey)
    local unitConfig = ns.UnitFrameUtils and ns.UnitFrameUtils.GetUnitDB and ns.UnitFrameUtils.GetUnitDB(unitKey) or nil
    local presence = ns.GUI and ns.GUI.Editor and ns.GUI.Editor.Composition and ns.GUI.Editor.Composition.Presence or nil
    if presence and type(presence.IsPresent) == "function" then
        return presence.IsPresent(unitConfig, {
            kind = kind,
            unit = unitKey,
            objectKey = componentKey,
            indicatorKey = kind == "indicator" and componentKey or nil,
            auraKey = kind == "aura" and componentKey or nil,
        }) == true
    end
    return false
end

local function CanAddUnitFrame(unitKey)
    local unitConfig = ns.UnitFrameUtils and ns.UnitFrameUtils.GetUnitDB and ns.UnitFrameUtils.GetUnitDB(unitKey) or nil
    return type(unitConfig) == "table" and unitConfig.present == false
end

local function HasMissingUnitFrames()
    for _, item in ipairs(ADD_OBJECT_UNIT_CAPABILITIES) do
        if CanAddUnitFrame(item.unitKey) then return true end
    end
    return false
end

local function CanAddContextIndicator(unitKey, componentKey, indicatorList)
    local shared = ns.GUI.Editor.SidebarShared
    local meta = shared.INDICATOR_META[componentKey]
    local unit = ns.UnitFrameUtils.GetUnitDB(unitKey)
    indicatorList = indicatorList or shared.BuildIndicatorList(unitKey)
    return meta and meta.contextAttached == true and indicatorList[componentKey] ~= nil
        and type(unit) == "table" and type(unit[componentKey]) == "table"
        and getmetatable(unit[componentKey]) == nil
        and not IsSingletonComponentPresent(unitKey,"indicator",componentKey) or false
end

local function HasContextIndicator(unitKey)
    for _,item in ipairs(ADD_OBJECT_VISUAL_CAPABILITIES) do
        if CanAddContextIndicator(unitKey,item.componentKey) then return true end
    end
    return false
end

local function SelectSingletonComponent(unitKey, kind, componentKey)
    local objectSelection = ns.GUI and ns.GUI.Editor and ns.GUI.Editor.ObjectSelection or nil
    local selected
    if objectSelection and type(objectSelection.SelectObject) == "function" then
        selected = objectSelection.SelectObject({
            kind = kind,
            unit = unitKey,
            objectKey = componentKey,
            indicatorKey = kind == "indicator" and componentKey or nil,
            auraKey = kind == "aura" and componentKey or nil,
        })
    end
    if type(ns.RefreshUnitFrame) == "function" then
        ns:RefreshUnitFrame(unitKey)
    end
    CustomizeAddedChild(selected)
    RequestEditorRefresh("CanvasToolbar.AddObject")
end

local function AddSingletonComponent(unitKey, kind, componentKey, request)
    local mutations = ns.InspectorMutations or (ns.GUI and ns.GUI.Editor and ns.GUI.Editor.Inspector and ns.GUI.Editor.Inspector.Mutations) or nil
    local workflow = ns.LayoutEditWorkflow
    if not (mutations and mutations.AddComponent and workflow and workflow.RequestEditableLayoutForMutation) then return end
    if request and request.indicatorPlacement
        and (not request.isCurrent() or not CanAddContextIndicator(unitKey,componentKey)) then return end
    workflow.RequestEditableLayoutForMutation(function()
        if request and not request.isCurrent(true) then return end
        local context = BuildDecorationMutationContext(unitKey)
        local placement = request and request.indicatorPlacement
        if placement then
            context.isCurrent = function() return request.isCurrent(true) end
            context.placementTarget = request.parentRef
        end
        local result = mutations.AddComponent(context, componentKey, placement)
        if result and result.ok ~= false then
            SelectSingletonComponent(unitKey, kind, componentKey)
        elseif ns.Info then
            ns:Info(T("ADD_OBJECT_STATUS_FAILED", "Object could not be added."))
        end
    end)
end

local function BuildSegmentedBarAddAction(unitKey, request)
    local mutations = ns.LayoutMutations and ns.LayoutMutations.SegmentedBars
    local workflow, resolver = ns.LayoutEditWorkflow, ns.ActiveLayoutResolver
    if unitKey ~= "player" or not (mutations and mutations.CaptureContext and mutations.Add
        and workflow and workflow.RequestEditableLayoutForMutation and resolver and resolver.GetActiveRuntimeRoot) then return nil end
    local db, root, layoutId = ns.db, resolver.GetActiveRuntimeRoot(), ResolveActiveLayoutId()
    local originToken = entityAddOriginToken
    local builtin = type(layoutId) == "string" and layoutId:match("^builtin:") ~= nil
    local mutationContext = not builtin and mutations.CaptureContext(unitKey) or nil
    local consumed = false
    local function Failed()
        if ns.Info then ns:Info(T("ADD_OBJECT_STATUS_FAILED", "Object could not be added.")) end
    end
    local function Add()
        if request and not request.isCurrent(true) then Failed(); return end
        if ns.db ~= db or entityAddOriginToken ~= originToken then Failed(); return end
        if builtin then
            -- The existing workflow has created AND activated the editable copy.
            local current = resolver.GetActiveRuntimeRoot()
            local from = current and current.record and current.record.createdFrom
            if not from or from.id ~= layoutId then Failed(); return end
            mutationContext = mutations.CaptureContext(unitKey)
        end
        if not mutationContext then Failed(); return end
        local result = mutations.Add(mutationContext)
        if not (result and result.ok and result.id) then Failed(); return end
        entityAddOriginToken = nil
        SelectSingletonComponent(unitKey, "segmentedBar", result.id)
    end
    return function()
        if consumed then return end
        consumed = true
        if ns.db ~= db or ResolveActiveLayoutId() ~= layoutId or resolver.GetActiveRuntimeRoot() ~= root
            or entityAddOriginToken ~= originToken then Failed(); return end
        if builtin then
            local ready, reason = workflow.RequestEditableLayoutForMutation(Add)
            if not ready and reason ~= "confirmation-open" then Failed() end
        else
            Add() -- C1b owns the editable workflow, final context check and publication.
        end
    end
end

local function AddUnitFrame(unitKey, request)
    if not request or not request.isCurrent() or not CanAddUnitFrame(unitKey) then return end
    local mutations = ns.InspectorMutations or (ns.GUI and ns.GUI.Editor and ns.GUI.Editor.Inspector and ns.GUI.Editor.Inspector.Mutations) or nil
    local workflow = ns.LayoutEditWorkflow
    if not (mutations and mutations.SetUnitPresence and workflow and workflow.RequestEditableLayoutForMutation) then return end
    workflow.RequestEditableLayoutForMutation(function()
        if not request.isCurrent(true) or not CanAddUnitFrame(unitKey) then return end
        local result = mutations.SetUnitPresence(BuildDecorationMutationContext(unitKey), true)
        if not (result and result.ok ~= false) then
            if ns.Info then ns:Info(T("ADD_OBJECT_STATUS_FAILED", "Object could not be added.")) end
            return
        end
        if type(ns.ResyncActiveLayout) == "function" then ns:ResyncActiveLayout("CanvasToolbar.AddUnitFrame")
        elseif type(ns.RebuildFramesForActiveProfile) == "function" then ns:RebuildFramesForActiveProfile()
        elseif type(ns.RefreshUnitFrame) == "function" then ns:RefreshUnitFrame(unitKey) end
        local objectSelection = ns.GUI and ns.GUI.Editor and ns.GUI.Editor.ObjectSelection or nil
        if objectSelection and objectSelection.SelectUnitRoot then objectSelection.SelectUnitRoot(unitKey)
        elseif type(ns.SelectEditorUnit) == "function" then ns:SelectEditorUnit(unitKey) end
        RequestEditorRefresh("CanvasToolbar.AddUnitFrame")
    end)
end

local PICKER_SECTION_HEIGHT = 18
local PICKER_BUTTON_HEIGHT = 22
local ADD_OBJECT_DESCRIPTION_HEIGHT = 24
local ADD_OBJECT_DESCRIPTION_GAP = 8
local ADD_OBJECT_ACTION_HEIGHT = 30
local ADD_OBJECT_BOTTOM_PADDING = 6
local COMPACT_WINDOW_CHROME_HEIGHT = 57

local COMPACT_BODY_TOP_PADDING = 6
local ADD_OBJECT_MIN_SELECTION_HEIGHT = 68 - COMPACT_BODY_TOP_PADDING
local ADD_OBJECT_MAX_WINDOW_HEIGHT = 560
local ADD_OBJECT_SCREEN_MARGIN = 16

local function AddPickerHeader(container, label)
    local header = FormWidgets and FormWidgets.CreateSectionTitle and FormWidgets.CreateSectionTitle(label, 12) or AceGUI:Create("Label")
    header:SetText(label)
    if FormWidgets and FormWidgets.ApplyTextStyle and header.label then
        FormWidgets.ApplyTextStyle(header.label, "parchmentSectionHeader", 12, 1)
    end
    header:SetFullWidth(true)
    header:SetHeight(PICKER_SECTION_HEIGHT)
    container:AddChild(header)
end

local function AddPickerButton(dialog, container, label, callback, closeBefore)
    local buttonWidth = (tonumber(dialog and dialog.contentWidth) or 340) - 18
    local button = FormWidgets and FormWidgets.CreateActionButton
        and FormWidgets.CreateActionButton(label, "secondary", buttonWidth, false)
        or AceGUI:Create("Button")
    button:SetText(label)
    button:SetFullWidth(true)
    button:SetHeight(PICKER_BUTTON_HEIGHT)
    button:SetCallback("OnClick", function()
        if dialog.released or addObjectPickerDialog ~= dialog then return end
        if closeBefore ~= false then CloseAddObjectPickerDialog() end
        callback()
    end)
    if FormWidgets and FormWidgets.ApplyModalActionButtonVisual then
        FormWidgets.ApplyModalActionButtonVisual(button, "secondary")
    end
    button.text:SetJustifyH("CENTER")
    container:AddChild(button)
end

local function OpenTextTemplateLibrary(entityMode, request)
    entityMode = true
    local libraryWindow = ns.GUI and ns.GUI.Editor and ns.GUI.Editor.TextTemplateLibraryWindow or nil
    if libraryWindow and libraryWindow.Open then
        local objectSelection = ns.GUI and ns.GUI.Editor and ns.GUI.Editor.ObjectSelection or nil
        local selectedObject = request and request.parentRef or objectSelection and type(objectSelection.GetSelectedObject) == "function" and objectSelection.GetSelectedObject() or nil
        local layoutId = ResolveActiveLayoutId()
        local returnContext
        if entityMode == true and entityAddOriginToken then
            returnContext = {pickerMode = "add", layoutId = layoutId,
                unitKey = (request and request.unitKey or ResolveSelectedObjectUnit()), originToken = entityAddOriginToken,
                anchorContext = type(selectedObject) == "table" and {kind = selectedObject.kind,
                    unitKey = selectedObject.unit, textKey = selectedObject.textKey,
                    objectKey = selectedObject.objectKey, sectionKey = selectedObject.sectionKey} or nil}
        end
        libraryWindow.Open({
            entity = entityMode == true,
            unit = (request and request.unitKey or ResolveSelectedObjectUnit()),
            anchorSelection = selectedObject,
            isCurrent = request and request.isCurrent,
            targetLabel = request and request.displayName,
            returnContext = returnContext,
        })
    elseif ns.Info then
        ns:Info(T("ADD_OBJECT_STATUS_FAILED", "Object could not be added."))
    end
end

local function OpenAddObjectPicker(entityMode, request)
    local picker
    local unitKey = request and request.unitKey or ResolveSelectedObjectUnit()
    local unitFramesOnly = request and request.unitFramesOnly == true
    local unitLevel = not unitFramesOnly and (not request or request.parentRef.kind == "unit")
    if type(unitKey) ~= "string" or unitKey == "" then
        if ns.Info then
            ns:Info(T("ADD_OBJECT_STATUS_SELECT_UNIT", "Select a unit first."))
        end
        return
    end

    -- Materialize availability once. Rendering and its measured layout consume
    -- this same ordered snapshot, including only nonempty categories.
    local categories = {}
    local function AddCategory(label, entries)
        if #entries > 0 then
            categories[#categories + 1] = { label = label, entries = entries }
        end
    end
    local entries = {}
    for _, item in ipairs(ADD_OBJECT_UNIT_CAPABILITIES) do
        if unitFramesOnly and CanAddUnitFrame(item.unitKey) then
            entries[#entries + 1] = {
                label = item.labelKey and T(item.labelKey, item.fallback) or ResolveUnitLabel(item.unitKey),
                action = AddUnitFrame, args = { item.unitKey, request },
            }
        end
    end
    AddCategory(T("ADD_OBJECT_CATEGORY_UNIT_FRAMES", "Unit Frames"), entries)
    if unitFramesOnly and #entries == 0 then return end

    entries = {}
    for _, item in ipairs(ADD_OBJECT_BAR_CAPABILITIES) do
        if unitLevel and (not item.playerOnly or unitKey == "player") and not IsSingletonComponentPresent(unitKey, "bar", item.componentKey) then
            entries[#entries + 1] = {
                label = T(item.labelKey, item.fallback),
                action = AddSingletonComponent, args = { unitKey, "bar", item.componentKey, request },
            }
        end
    end
    local addSegmentedBar = unitLevel and BuildSegmentedBarAddAction(unitKey, request)
    if addSegmentedBar then
        entries[#entries + 1] = {
            label = T("EDITOR_SEGMENTED_BAR", "Class Resource Bar"), args = {}, closeBefore = false,
            action = function()
                if addObjectPickerDialog ~= picker then return end
                CloseAddObjectPickerDialog()
                addSegmentedBar()
            end,
        }
    end
    AddCategory(T("ADD_OBJECT_CATEGORY_BARS", "Bars"), entries)

    local shared = ns.GUI and ns.GUI.Editor and ns.GUI.Editor.SidebarShared or {}
    local indicatorList = type(shared.BuildIndicatorList) == "function" and shared.BuildIndicatorList(unitKey) or {}
    entries = {}
    for _, item in ipairs(ADD_OBJECT_VISUAL_CAPABILITIES) do
        if (unitLevel or request.indicatorPlacement and CanAddContextIndicator(unitKey,item.componentKey,indicatorList))
            and indicatorList[item.componentKey] and not IsSingletonComponentPresent(unitKey, "indicator", item.componentKey) then
            entries[#entries + 1] = {
                label = T(item.labelKey, item.fallback),
                action = AddSingletonComponent, args = { unitKey, "indicator", item.componentKey, request },
            }
        end
    end
    AddCategory(T("ADD_OBJECT_CATEGORY_VISUALS", "Visuals"), entries)

    entries = {}
    for _, item in ipairs(ADD_OBJECT_AURA_CAPABILITIES) do
        if unitLevel and not IsSingletonComponentPresent(unitKey, "aura", item.componentKey) then
            entries[#entries + 1] = {
                label = T(item.labelKey, item.fallback),
                action = AddSingletonComponent, args = { unitKey, "aura", item.componentKey, request },
            }
        end
    end
    AddCategory(T("EDITOR_SECTION_AURAS", "Auras"), entries)
    local contentEntries = {
        { label = T("ADD_OBJECT_TEXT_BUTTON", "Text"), action = function() OpenTextTemplateLibrary(entityMode, request) end, args = {}, closeBefore = entityMode ~= true },
    }
    if unitLevel then contentEntries[#contentEntries+1] = { label = T("ADD_OBJECT_DECORATION_BUTTON", "Decoration"), action = InsertDecoration, args = {request} } end
    if not unitFramesOnly then AddCategory(T("ADD_OBJECT_CATEGORY_CONTENT", "Content"), contentEntries) end

    -- Window and UIParent share a scale. Reserve the fixed regions before
    -- assigning the remaining screen/comfort budget to the selection viewport.
    local maxWindowHeight = math.min(ADD_OBJECT_MAX_WINDOW_HEIGHT,
        UIParent:GetHeight() - 2 * ADD_OBJECT_SCREEN_MARGIN)
    local fixedHeight = COMPACT_WINDOW_CHROME_HEIGHT + COMPACT_BODY_TOP_PADDING
        + ADD_OBJECT_DESCRIPTION_HEIGHT + ADD_OBJECT_DESCRIPTION_GAP
        + ADD_OBJECT_ACTION_HEIGHT + ADD_OBJECT_BOTTOM_PADDING

    CloseAddObjectPickerDialog()
    local dialog = FormWidgets and FormWidgets.CreateCompactFormDialog and FormWidgets.CreateCompactFormDialog({
        title = unitFramesOnly and T("ADD_UNIT_TITLE", "Add Unit") or T("ADD_OBJECT_TITLE", "Add Object"),
        width = 420,
        height = maxWindowHeight,
        bodyLayout = "List",
        addBodySpacer = false,
        contentRoot = true,
        contentSurface = "parchment",
    }) or nil
    if not dialog then
        return
    end

    local description = AceGUI:Create("Label")
    description:SetText(unitFramesOnly and T("ADD_UNIT_DESCRIPTION", "Choose a missing unit frame to restore.")
        or request and not unitLevel and request.displayName
        and string.format(T("COMPONENT_ADD_TARGET", "Add to: %s"), request.displayName)
        or request and unitLevel
        and string.format(T("COMPONENT_ADD_UNIT_DESCRIPTION", "Choose what to add to %s."), ResolveUnitLabel(unitKey))
        or T("ADD_OBJECT_DESCRIPTION", "Choose what to add to the selected unit frame."))
    description:SetFullWidth(true)
    description:SetHeight(ADD_OBJECT_DESCRIPTION_HEIGHT)
    if FormWidgets and FormWidgets.ApplyTextStyle and description.label then
        FormWidgets.ApplyTextStyle(description.label, "parchmentSecondary", 11, 1)
    end
    dialog.body:AddChild(description)

    local descriptionGap = AceGUI:Create("Label")
    descriptionGap:SetText("")
    descriptionGap:SetFullWidth(true)
    descriptionGap:SetHeight(ADD_OBJECT_DESCRIPTION_GAP)
    dialog.body:AddChild(descriptionGap)

    -- Label height can change after width assignment (e.g. translated text).
    fixedHeight = fixedHeight + math.max(0,
        math.ceil(description.frame:GetHeight()) - ADD_OBJECT_DESCRIPTION_HEIGHT)
    local maxSelectionHeight = math.max(1, maxWindowHeight - fixedHeight)
    local selectionScroll = AceGUI:Create("ScrollFrame")
    selectionScroll:SetLayout("List")
    selectionScroll:SetFullWidth(true)
    selectionScroll:SetHeight(maxSelectionHeight)
    dialog.body:AddChild(selectionScroll)
    selectionScroll:PauseLayout()
    for _, category in ipairs(categories) do
        AddPickerHeader(selectionScroll, category.label)
        for _, entry in ipairs(category.entries) do
            AddPickerButton(dialog, selectionScroll, entry.label, function()
                if request and not request.isCurrent() then return end
                entry.action(unpack(entry.args))
            end, entry.closeBefore)
        end
    end
    selectionScroll:ResumeLayout()
    selectionScroll:DoLayout()
    -- ScrollFrame's existing List/LayoutFinished contract measures the actual
    -- rendered widgets and handles the narrower content when its bar is shown.
    local selectionNeed = math.max(ADD_OBJECT_MIN_SELECTION_HEIGHT,
        math.ceil(selectionScroll.content:GetHeight()))
    local selectionHeight = math.min(selectionNeed, maxSelectionHeight)
    selectionScroll:SetHeight(selectionHeight)
    dialog.window:SetHeight(fixedHeight + selectionHeight)

    local actionContainer = AceGUI:Create("SimpleGroup")
    actionContainer:SetLayout("Flow")
    actionContainer:SetFullWidth(true)
    if actionContainer.SetAutoAdjustHeight then
        actionContainer:SetAutoAdjustHeight(false)
    end
    actionContainer:SetHeight(ADD_OBJECT_ACTION_HEIGHT)
    dialog.body:AddChild(actionContainer)

    dialog:SetActions({
        cancel = {
            text = T("INFO_COMMON_CANCEL", "Cancel"),
            role = "utility",
            width = 105,
            icon = "cancel",
            onClick = CloseAddObjectPickerDialog,
        },
    }, actionContainer)

    local bottomPadding = AceGUI:Create("Label")
    bottomPadding:SetText("")
    bottomPadding:SetFullWidth(true)
    bottomPadding:SetHeight(ADD_OBJECT_BOTTOM_PADDING)
    dialog.body:AddChild(bottomPadding)
    dialog.window:SetCallback("OnClose", function()
        if dialog.released then return end
        dialog.released = true
        if addObjectPickerDialog == dialog then
            addObjectPickerDialog = nil
        end
        -- The factory owns recursive shell/child cleanup. Do not release the
        -- shell separately; all close paths converge here, including X/Escape.
        AceGUI:Release(dialog.window)
    end)
    addObjectPickerDialog = dialog
    picker = dialog
    dialog:Show()
    dialog.body:DoLayout()
    selectionScroll:FixScroll()
    selectionScroll.scrollbar:SetValue(0)
    selectionScroll:SetScroll(0)
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
        return T("LAYOUT_CREATE_DIRTY_TEXT_BUILDER", "Save or discard text changes before creating a layout.")
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

local function BuildNewLayoutSourceList()
    local sources = { blank = T("LAYOUT_CREATE_SOURCE_BLANK", "Blank") }
    local layoutService = ns.LayoutService or {}
    local summaries = layoutService.ListLayoutSummaries and layoutService.ListLayoutSummaries({ db = ns.db }) or {}
    for _, summary in ipairs(summaries) do
        if type(summary) == "table" and (summary.source == "builtin" or summary.source == "userLayout") and type(summary.id) == "string" then
            local prefix = summary.source == "builtin" and T("LAYOUT_CREATE_SOURCE_BUILTIN", "Template: ") or T("LAYOUT_CREATE_SOURCE_USER", "My layout: ")
            sources[summary.id] = prefix .. ResolveLayoutDisplayName(summary)
        end
    end
    return sources
end

local function OpenNewLayoutDialog(initialSourceId)
    CloseNewLayoutDialog()
    local descriptionHeight = 32
    local descriptionNameGap = 6
    local nameHeight = 32
    local nameSourceGap = 6
    local sourceHeight = 32
    local sourceStatusGap = 6
    local statusHeight = 16
    local statusActionGap = 6
    local actionHeight = 30
    local bottomPadding = 6
    local dialog = FormWidgets and FormWidgets.CreateCompactFormDialog and FormWidgets.CreateCompactFormDialog({
        title = T("LAYOUT_CREATE_TITLE", "New Layout"),
        width = 420,
        height = 57 + descriptionHeight + descriptionNameGap + nameHeight + nameSourceGap + sourceHeight + sourceStatusGap + statusHeight + statusActionGap + actionHeight + bottomPadding,
        bodyLayout = "List",
        addBodySpacer = false,
        contentRoot = true,
    }) or nil
    if not dialog then return end

    local description = FormWidgets.CreateBodyText(T("LAYOUT_CREATE_DESCRIPTION", "Start with a blank layout or an existing layout."), "label", 12, nil, dialog.contentWidth, false)
    description:SetFullWidth(true)
    description:SetHeight(descriptionHeight)
    dialog.body:AddChild(description)

    local function AddSpacer(height)
        local spacer = AceGUI:Create("Label")
        spacer:SetText("")
        spacer:SetFullWidth(true)
        spacer:SetHeight(height)
        dialog.body:AddChild(spacer)
    end

    AddSpacer(descriptionNameGap)

    local nameEdit = AceGUI:Create("EditBox")
    nameEdit:SetLabel(T("LAYOUT_CREATE_NAME", "Name"))
    nameEdit:SetFullWidth(true)
    nameEdit:SetHeight(nameHeight)
    nameEdit:SetText(ResolveDefaultNewLayoutName())
    if FormWidgets and FormWidgets.StyleEditBox then FormWidgets.StyleEditBox(nameEdit, "editor_inset") end
    dialog.body:AddChild(nameEdit)

    AddSpacer(nameSourceGap)

    local sourceSelect = AceGUI:Create("Dropdown")
    sourceSelect:SetLabel(T("LAYOUT_CREATE_START_FROM", "Start from"))
    sourceSelect:SetFullWidth(true)
    sourceSelect:SetHeight(sourceHeight)
    sourceSelect:SetList(BuildNewLayoutSourceList())
    sourceSelect:SetValue(initialSourceId or "blank")
    dialog.body:AddChild(sourceSelect)

    AddSpacer(sourceStatusGap)

    local status = AceGUI:Create("Label")
    status:SetText(" ")
    status:SetFullWidth(true)
    status:SetHeight(statusHeight)
    if FormWidgets and FormWidgets.ApplyTextStyle and status.label then
        FormWidgets.ApplyTextStyle(status.label, "help", 10, 1)
    end
    dialog.body:AddChild(status)

    AddSpacer(statusActionGap)

    local actionContainer = AceGUI:Create("SimpleGroup")
    actionContainer:SetFullWidth(true)
    actionContainer:SetHeight(actionHeight)
    actionContainer:SetLayout("Flow")
    if actionContainer.SetAutoAdjustHeight then actionContainer:SetAutoAdjustHeight(false) end
    dialog.body:AddChild(actionContainer)
    AddSpacer(bottomPadding)

    local function updateCreateButton()
        if dialog.primaryButton then
            dialog.primaryButton:SetDisabled(Trim(nameEdit:GetText() or "") == "")
        end
    end

    local function clearStatus()
        dialog:SetStatus("", nil, status)
        updateCreateButton()
    end

    local function confirm()
        if HasDirtyTextBuilderDraft() then
            dialog:SetStatus(ResolveCreateLayoutStatus("dirty-text-builder"), "error", status)
            return
        end
        local sourceId = sourceSelect:GetValue() or "blank"
        local ok, resultOrReason, createdLayoutId = false, "create-unavailable", nil
        if sourceId == "blank" and ns.CreateBlankLayout then
            ok, resultOrReason, createdLayoutId = ns:CreateBlankLayout(nameEdit:GetText(), { reason = "create-layout" })
        elseif sourceId ~= "blank" then
            local mutations = ns.LayoutMutations or {}
            if mutations.CreateUserLayoutFromSource then
                ok, resultOrReason = mutations.CreateUserLayoutFromSource(sourceId, nameEdit:GetText(), { activate = true, reason = "create-layout-from-source" })
                createdLayoutId = resultOrReason
            end
        end
        if ok then
            dialog:Close()
            CanvasToolbar.Refresh()
            return
        end
        dialog:SetStatus(ResolveCreateLayoutStatus(resultOrReason), "error", status)
        updateCreateButton()
        CanvasToolbar.Refresh()
    end

    nameEdit:SetCallback("OnTextChanged", clearStatus)
    nameEdit:SetCallback("OnEnterPressed", function()
        if Trim(nameEdit:GetText() or "") ~= "" then confirm() end
    end)
    dialog:SetActions({
        cancel = {
            text = T("INFO_COMMON_CANCEL", "Cancel"),
            role = "utility",
            width = 110,
            onClick = CloseNewLayoutDialog,
        },
        primary = {
            text = T("LAYOUT_CREATE_CONFIRM", "Create Layout"),
            role = "primary_action",
            width = 120,
            onClick = confirm,
        },
    }, actionContainer)
    dialog.confirmationStatus = status
    dialog.window:SetCallback("OnClose", function()
        if newLayoutDialog == dialog then newLayoutDialog = nil end
    end)
    newLayoutDialog = dialog
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
    local chromeColors = GetChromeColors()

    local bg = host:CreateTexture(nil, "BACKGROUND")
    bg:SetPoint("TOPLEFT", host, "TOPLEFT", 0, 0)
    bg:SetPoint("BOTTOMRIGHT", host, "BOTTOMRIGHT", 0, 0)
    bg:SetColorTexture(unpack(chromeColors.canvasToolbarBackground or {}))
    host.bg = bg

    local border = host:CreateTexture(nil, "BORDER")
    border:SetPoint("TOPLEFT", host, "TOPLEFT", 0, 0)
    border:SetPoint("BOTTOMRIGHT", host, "BOTTOMRIGHT", 0, 0)
    border:SetColorTexture(unpack(chromeColors.canvasToolbarBorder or {}))
    host.border = border

    local inset = host:CreateTexture(nil, "ARTWORK")
    inset:SetPoint("TOPLEFT", host, "TOPLEFT", 1, -1)
    inset:SetPoint("BOTTOMRIGHT", host, "BOTTOMRIGHT", -1, 1)
    inset:SetColorTexture(unpack(chromeColors.canvasToolbarInset or {}))
    host.inset = inset

    FormWidgets.ApplyCanvasToolbarPresentation(host)

    local widgets = {
        addObjectButton = CreateButton(T("ADD_UNIT_BUTTON", "+ Add Unit"), INSERT_ADD_OBJECT_WIDTH),
        layoutDropdown = AceGUI:Create("Dropdown"),
        layoutAddButton = CreateButton("+", LAYOUT_ADD_WIDTH),
        layoutManageButton = CreateButton("Manage Layouts", LAYOUT_MANAGE_WIDTH),
        optionsButton = CreateButton(T("OPTION_OPTIONS", "Options"), OPTIONS_WIDTH),
        presentationButton = CreateButton(T("EDITOR_CUSTOMIZE", "Customize"), PRESENTATION_WIDTH),
        closeButton = CreateButton(T("CLOSE", "Close"), CLOSE_WIDTH),
    }

    if FormWidgets and FormWidgets.ApplyModalActionButtonVisual then
        FormWidgets.ApplyModalActionButtonVisual(widgets.addObjectButton, "secondary")
    end

    AnchorButton(widgets.addObjectButton, host, {
        x = INSERT_ADD_OBJECT_X,
        width = INSERT_ADD_OBJECT_WIDTH,
    })
    AnchorWidget(widgets.layoutDropdown, host, {
        x = LAYOUT_DROPDOWN_X,
        y = -5,
        width = LAYOUT_DROPDOWN_WIDTH,
        height = 26,
    })
    AnchorButton(widgets.layoutManageButton, host, {
        x = LAYOUT_ACTIVATE_X,
        width = LAYOUT_MANAGE_WIDTH,
    })
    AnchorButton(widgets.layoutAddButton, host, {
        x = LAYOUT_ADD_X,
        width = LAYOUT_ADD_WIDTH,
    })
    AnchorButton(widgets.presentationButton, host, { x = PRESENTATION_X, width = PRESENTATION_WIDTH })
    AnchorButton(widgets.optionsButton, host, { x = OPTIONS_X, width = OPTIONS_WIDTH })
    if FormWidgets and FormWidgets.ApplyInspectorGlyphButton then
        FormWidgets.ApplyInspectorGlyphButton(widgets.optionsButton, "|TInterface\\Buttons\\UI-OptionsButton:18:18|t", false)
    end
    widgets.optionsButton:SetCallback("OnClick", function()
        local optionsDialog = ns.GUI.Editor.OptionsDialog
        if optionsDialog and optionsDialog.Open then
            optionsDialog.Open()
        end
    end)
    AnchorButton(widgets.closeButton, host, { x = CLOSE_X, width = CLOSE_WIDTH })
    widgets.presentationButton:SetCallback("OnClick", function()
        local editorState = ns.GUI.Editor.State
        local controller = ns.GUI.Editor.Controller
        if editorState and editorState.IsArrange and controller and controller.SetPresentation then
            controller.SetPresentation(editorState.IsArrange() and "customize" or "arrange")
        end
    end)
    widgets.closeButton:SetCallback("OnClick", function()
        if ns.CloseConfig then ns:CloseConfig() end
    end)
    if FormWidgets and FormWidgets.SetInspectorButtonTooltip then
        FormWidgets.SetInspectorButtonTooltip(widgets.addObjectButton, T("ADD_UNIT_TOOLTIP", "Restore a missing unit frame"))
        FormWidgets.SetInspectorButtonTooltip(widgets.layoutAddButton, T("LAYOUT_ADD_TOOLTIP", "Add Layout"))
        FormWidgets.SetInspectorButtonTooltip(widgets.optionsButton, T("OPTION_OPTIONS", "Options"))
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

    local layoutAutomationLabel = host:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    layoutAutomationLabel:SetPoint("TOPLEFT", host, "TOPLEFT", LAYOUT_LABEL_X, -31)
    layoutAutomationLabel:SetWidth(418)
    layoutAutomationLabel:SetJustifyH("LEFT")
    layoutAutomationLabel:SetText("")
    layoutAutomationLabel:Hide()
    if FormWidgets and FormWidgets.ApplyTextStyle then
        FormWidgets.ApplyTextStyle(layoutAutomationLabel, "contextHighlight", 10, 0.9)
    end
    widgets.layoutAutomationLabel = layoutAutomationLabel

    context = {
        host = host,
        widgets = widgets,
        options = {
            onGlobalChanged = RequestEditorRefresh,
        },
    }

    if ToolbarBinding then
        if widgets.addObjectButton then
            widgets.addObjectButton:SetCallback("OnClick", function() CanvasToolbar.OpenEntityAddObjectPicker() end)
        end
        if widgets.layoutDropdown then
            widgets.layoutDropdown:SetCallback("OnValueChanged", function(_, _, value)
                if context._suspendLayoutCallbacks then
                    return
                end
                if HasDirtyTextBuilderDraft() then
                    if ns.Info then
                        ns:Info("Save or discard text changes before activating another layout.")
                    end
                    RefreshLayoutControls(context)
                    return
                end
                if type(value) ~= "string" or value == "" or value == ResolveActiveLayoutId() then
                    RefreshLayoutControls(context)
                    return
                end
                local ok, reason = false, "activate-unavailable"
                if ns.ActivateLayout then
                    ok, reason = ns:ActivateLayout(value, "canvas-toolbar")
                end
                if ok then
                    ReportManualAutomationMismatch(value)
                end
                ReportLayoutActivationResult(ok, reason)
                CanvasToolbar.Refresh()
            end)
        end
        if widgets.layoutAddButton then
            widgets.layoutAddButton:SetCallback("OnClick", function()
                OpenNewLayoutDialog()
            end)
        end
        if widgets.layoutManageButton then
            widgets.layoutManageButton:SetCallback("OnClick", function()
                local layoutManager = ns.GUI
                    and ns.GUI.Editor
                    and ns.GUI.Editor.LayoutManager
                if layoutManager and layoutManager.Open then
                    layoutManager.Open()
                end
            end)
        end
    end

    return context
end

function CanvasToolbar.UpdateGeometry()
    local current = EnsureHost()
    if not current or not current.host then
        return
    end

    local parent = ns.guiEditorWorkspaceLayer or UIParent
    current.host:SetParent(parent)
    current.host:ClearAllPoints()
    current.host:SetPoint("TOP", parent, "TOP", 0, -TOOLBAR_TOP_OFFSET)
    current.host:SetSize(TOOLBAR_WIDTH, TOOLBAR_HEIGHT)
end

local function CaptureComponentRequest(objectRef, isCurrent, displayName, allowArrange)
    if type(objectRef) ~= "table" or type(isCurrent) ~= "function" or not isCurrent() then return end
    local ref = {}; for key,value in pairs(objectRef) do ref[key] = value end
    local resolver = ns.ActiveLayoutResolver
    local db, root, layoutId = ns.db, resolver.GetActiveRuntimeRoot(), ResolveActiveLayoutId()
    local config = ns.UnitFrameUtils.GetUnitDB(ref.unit)
    local function Identity(unit)
        if not unit then return end
        if ref.kind == "text" then return unit.Texts and unit.Texts[ref.textKey or ref.objectKey] end
        local list = ref.kind == "segmentedBar" and unit.segmentedBars or ref.kind == "decoration" and unit.decorations
        if list then
            for _,record in ipairs(list) do if record.id == (ref.decorationId or ref.objectKey) then return record end end
            return nil
        end
        return unit
    end
    local identity = Identity(config)
    local function Current(allowCopy)
        if not isCurrent() or ns.db ~= db or (InCombatLockdown and InCombatLockdown()) then return false end
        local state = ns.GUI.Editor.State
        if (not allowArrange and state.IsArrange()) or state.GetPrimaryUnit() ~= ref.unit then return false end
        local current = resolver.GetActiveRuntimeRoot()
        local unit = ns.UnitFrameUtils.GetUnitDB(ref.unit)
        local copied = allowCopy and type(layoutId) == "string" and layoutId:match("^builtin:")
            and current and current.record and current.record.createdFrom and current.record.createdFrom.id == layoutId
        if not copied and (current ~= root or unit ~= config or Identity(unit) ~= identity) then return false end
        local presence = ns.GUI.Editor.Composition.Presence
        return unit ~= nil and (ref.kind == "unit" and unit.present ~= false
            or ref.kind ~= "unit" and presence and presence.IsPresent(unit, ref) == true)
    end
    if not Current() then return end
    return {unitKey=ref.unit, parentRef=ref, isCurrent=Current,
        displayName=type(displayName)=="string" and displayName~="" and displayName
            or ref.kind=="unit" and ResolveUnitLabel(ref.unit) or nil}
end

function CanvasToolbar.CanAddComponentChild(ref)
    local map = ns.LegacyAssociationMap
    return map and map.CanOwnText and map.CanOwnText(ref) == true or false
end

function CanvasToolbar.CanAddComponentAt(ref)
    local mutations = ns.InspectorMutations
    return CanvasToolbar.CanAddComponentChild(ref)
        or mutations and mutations.GetContextIndicatorAddPlacement(ref) ~= nil and HasContextIndicator(ref.unit) or false
end

function CanvasToolbar.OpenComponentAdd(ref, isCurrent, displayName)
    if ref.kind ~= "unit" and not CanvasToolbar.CanAddComponentChild(ref) then return end
    local request = CaptureComponentRequest(ref, isCurrent, displayName)
    if not request then return end
    entityAddOriginToken = {}
    if ref.kind ~= "unit" then
        CloseAddObjectPickerDialog()
        return OpenTextTemplateLibrary(true, request)
    end
    return OpenAddObjectPicker(true, request)
end

local function OpenComponentRemove(request)
    if not request.isCurrent() then return end
    local ref = request.parentRef
    local mutations = ns.InspectorMutations
    if not (mutations and mutations.CanRemoveObject(ref)) then return end
    local segmented = ref.kind == "segmentedBar" and ns.LayoutMutations.SegmentedBars
    local deleteContext = segmented and segmented.CaptureContext(ref.unit)
    local dialog
    local active=true
    dialog = FormWidgets.CreateCompactConfirmation({
        title=T("COMPONENT_REMOVE_TITLE", "Remove Component?"),
        message=request.displayName
            and string.format(T("COMPONENT_REMOVE_NAMED_DESCRIPTION", "Remove \"%s\" from the unit frame?"), request.displayName)
            or T("COMPONENT_REMOVE_DESCRIPTION", "Remove this object from the unit frame?"),
        primary={text=T("INFO_COMMON_REMOVE", "Remove"),role="danger",width=104,
            onClick=function(activeDialog)
                if not active then return end
                if not request.isCurrent() then activeDialog:Close();return end
                local selection=ns.GUI.Editor.ObjectSelection
                local selected=selection.GetSelectedObject()
                local result
                ns.LayoutEditWorkflow.RequestEditableLayoutForMutation(function()
                    if not active or not request.isCurrent(true) then return end
                    result=mutations.RemoveObject(BuildDecorationMutationContext(ref.unit),ref,
                        deleteContext or segmented and segmented.CaptureContext(ref.unit))
                    if result and result.ok and result.changed then
                        local same=selected and selected.kind==ref.kind and selected.unit==ref.unit
                            and (selected.objectKey or selected.textKey or selected.decorationId)==(ref.objectKey or ref.textKey or ref.decorationId)
                        local presence=ns.GUI.Editor.Composition.Presence
                        if ref.kind == "unit" then
                            if ns.ResyncActiveLayout then ns:ResyncActiveLayout("Components.RemoveUnit")
                            elseif ns.RebuildFramesForActiveProfile then ns:RebuildFramesForActiveProfile() end
                            local current = selection.GetSelectedObject()
                            local currentConfig = current and ns.UnitFrameUtils.GetUnitDB(current.unit)
                            local fallback = currentConfig and currentConfig.present ~= false and current.unit or nil
                            if not fallback then
                                for _, key in ipairs(ns.Constants.UnitOrder) do
                                    local config = ns.UnitFrameUtils.GetUnitDB(key)
                                    if config and config.present ~= false then fallback = key; break end
                                end
                            end
                            if fallback then selection.SelectUnitRoot(fallback) end
                        elseif same or selected and presence and not presence.IsPresent(ns.UnitFrameUtils.GetUnitDB(ref.unit),selected) then
                            selection.SelectUnitRoot(ref.unit)
                        end
                        if ref.kind ~= "unit" and ns.RefreshUnitFrame then ns:RefreshUnitFrame(ref.unit) end
                        local controller=ns.GUI.Editor.Controller
                        controller.RefreshCompositionTree()
                        controller.RefreshActiveProperties()
                        local inspector=controller.GetActiveInspectorHost()
                        if inspector and inspector._focalPointSetCustomizeView then inspector._focalPointSetCustomizeView("components") end
                        RequestEditorRefresh("Components.Remove")
                        activeDialog:Close()
                    end
                end)
                if result and not result.ok and activeDialog.SetStatus then
                    activeDialog:SetStatus(result.errorCode=="anchor-in-use"
                        and T("EDITOR_DELETE_SEGMENTED_BAR_ANCHOR_IN_USE", "Another segmented bar uses this one as its anchor.")
                        or T("ADD_OBJECT_STATUS_FAILED", "Object could not be changed."),"error",activeDialog.confirmationStatus)
                end
            end},
        cancel={text=T("INFO_COMMON_CANCEL", "Cancel"),role="utility",width=104,onClick=function(activeDialog)activeDialog:Close()end},
    })
    if dialog then
        local previousClose = dialog.window.events and dialog.window.events.OnClose
        local previousRelease = dialog.window.events and dialog.window.events.OnRelease
        dialog.window:SetCallback("OnClose", function(owner, event, ...)
            active = false
            if previousClose then previousClose(owner, event, ...) end
        end)
        dialog.window:SetCallback("OnRelease", function(owner, event, ...)
            active = false
            if previousRelease then previousRelease(owner, event, ...) end
        end)
        dialog:Show()
    end
end

function CanvasToolbar.OpenComponentCatalog(ref, isCurrent, displayName)
    if not CanvasToolbar.CanAddComponentAt(ref) then return end
    local request = CaptureComponentRequest(ref,isCurrent,displayName)
    if not request then return end
    request.indicatorPlacement = ns.InspectorMutations.GetContextIndicatorAddPlacement(ref)
    entityAddOriginToken = {}
    return OpenAddObjectPicker(true,request)
end

function CanvasToolbar.OpenComponentRemove(ref, isCurrent, displayName)
    if not ns.InspectorMutations.CanRemoveObject(ref) then return end
    local request = CaptureComponentRequest(ref,isCurrent,displayName)
    if request then return OpenComponentRemove(request) end
end

function CanvasToolbar.OpenEntityAddObjectPicker()
    if not HasMissingUnitFrames() then return end
    local owner, refreshSerial = context, ns._guiRefreshSerial
    local editor = ns.GUI.Editor
    local buildSerial, state = editor._inspectorBuildSerial, editor.State
    local arrange = state.IsArrange and state.IsArrange()
    local selection = editor.ObjectSelection
    local selected = selection and selection.GetSelectedObject and selection.GetSelectedObject()
    local token = {}
    entityAddOriginToken = token
    local request = CaptureComponentRequest({kind="unit", unit=ResolveSelectedObjectUnit()}, function()
        if context ~= owner or (owner and not owner.host:IsShown())
            or ns._guiRefreshSerial ~= refreshSerial or editor._inspectorBuildSerial ~= buildSerial
            or (state.IsArrange and state.IsArrange()) ~= arrange or entityAddOriginToken ~= token then return false end
        if selected then
            local current = selection.GetSelectedObject()
            if not current then return false end
            for key,value in pairs(selected) do if current[key] ~= value then return false end end
            for key,value in pairs(current) do if selected[key] ~= value then return false end end
        end
        return true
    end, nil, true)
    if not request then return end
    request.unitFramesOnly = true
    return OpenAddObjectPicker(true, request)
end

function CanvasToolbar.OpenEntityTextTemplateLibrary()
    return OpenTextTemplateLibrary(true)
end

function CanvasToolbar.AcceptEntityReturn(returnContext, result)
    if type(returnContext) ~= "table" or returnContext.originToken ~= entityAddOriginToken then return false end
    entityAddOriginToken = nil
    CloseAddObjectPickerDialog()
    return true
end

function CanvasToolbar.Refresh()
    local perf = ns and ns.SelectionPerfDebug
    local perfStart = perf and perf.Begin and perf:Begin("CanvasToolbar.Refresh")

    local current = EnsureHost()
    if not current or not ToolbarBinding then
        if perf and perf.End then
            perf:End("CanvasToolbar.Refresh", perfStart)
        end
        return
    end

    local editorState = ns.GUI.Editor.State
    local arrange = editorState and editorState.IsArrange and editorState.IsArrange()
    current.widgets.presentationButton:SetText(arrange and T("EDITOR_CUSTOMIZE", "Customize") or T("EDITOR_ARRANGE", "Arrange"))
    RefreshLayoutControls(current)
    current.widgets.addObjectButton:SetDisabled(not HasMissingUnitFrames()
        or (InCombatLockdown and InCombatLockdown() == true))
    local layoutManager = ns.GUI and ns.GUI.Editor and ns.GUI.Editor.LayoutManager
    if layoutManager and layoutManager.Refresh then
        layoutManager.Refresh()
    end

    if perf and perf.End then
        perf:End("CanvasToolbar.Refresh", perfStart)
    end
end

function CanvasToolbar.Show()
    local current = EnsureHost()
    if not current or not current.host then
        return
    end

    CanvasToolbar.UpdateGeometry()
    CanvasToolbar.Refresh()
    FormWidgets.ApplyCanvasToolbarPresentation(current.host)
    current.host:Show()
end

function CanvasToolbar.Hide()
    if context and context.host then
        context.host:Hide()
    end
end


return CanvasToolbar
