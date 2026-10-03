local _, ns = ...

ns.GUI = ns.GUI or {}
ns.GUI.Editor = ns.GUI.Editor or {}

local AceGUI = LibStub("AceGUI-3.0")
local FormWidgets = ns.GUI.Helpers and ns.GUI.Helpers.FormWidgets or {}
local TextStyles = ns.GUI.Helpers and ns.GUI.Helpers.TextStyles or {}
local FormRenderer = ns.GUI.Helpers and ns.GUI.Helpers.FormRenderer or {}
local SelectionRow = ns.GUI.Widgets and ns.GUI.Widgets.SelectionRow or {}

local TextTemplateLibraryWindow = {}
ns.GUI.Editor.TextTemplateLibraryWindow = TextTemplateLibraryWindow

local windowContext
local managerContext
local managerRenameDialog
local managerDeleteDialog
local pendingEntityReturns = setmetatable({}, {__mode = "k"})
local lastEntityReturn

local function T(key, fallback)
    local L = ns.L or {}
    local value = L[key]
    return type(value) == "string" and value ~= "" and value or fallback or key
end

local function Trim(value)
    if type(value) ~= "string" then
        return ""
    end
    return (value:gsub("^%s+", ""):gsub("%s+$", ""))
end

local function SortKeys(left, right)
    return tostring(left or "") < tostring(right or "")
end

local function Shorten(value, limit)
    value = tostring(value or "")
    limit = tonumber(limit) or 86
    if #value <= limit then
        return value
    end
    return value:sub(1, math.max(1, limit - 3)) .. "..."
end

local function BuildRenderedPreview(templateText)
    local unitFrame = ns.UnitFrame or nil
    if unitFrame and type(unitFrame.BuildTemplatePreview) == "function" then
        local preview = unitFrame:BuildTemplatePreview(templateText)
        if type(preview) == "string" and preview ~= "" then
            return preview
        end
    end
    return tostring(templateText or "")
end

local function ApplyLabelText(widget, role, size)
    if TextStyles.ApplyLabelWidget then
        TextStyles.ApplyLabelWidget(widget, role or "label", { size = size or 11 })
    elseif FormWidgets.ApplyTextStyle and widget and widget.label then
        FormWidgets.ApplyTextStyle(widget.label, role or "label", size or 11, 1)
    end
end

local function CreateLabel(text, role, size, width, height)
    local label = AceGUI:Create("Label")
    label:SetText(text or "")
    label:SetFullWidth(width == nil)
    if width then
        label:SetWidth(width)
    end
    if height then
        label:SetHeight(height)
    end
    ApplyLabelText(label, role or "label", size or 11)
    return label
end

local function CreateResultPanel(host)
    local layouts = ns.GUI and ns.GUI.Layouts and ns.GUI.Layouts.TextBuilder
    local definition
    for _, candidate in ipairs(layouts and layouts.Form or {}) do
        if candidate.section == "Preview" then
            definition = candidate
            break
        end
    end
    if not definition or type(FormRenderer.CreateLayoutGroup) ~= "function" then
        return nil
    end
    return FormRenderer.CreateLayoutGroup(host, definition)
end

local function CreateButton(text, role, width)
    local button = FormWidgets.CreateActionButton and FormWidgets.CreateActionButton(text or "", role or "utility", width or 110, false) or AceGUI:Create("Button")
    button:SetText(text or "")
    button:SetFullWidth(false)
    button:SetWidth(width or 110)
    if FormWidgets.ApplyModalActionButtonVisual then
        FormWidgets.ApplyModalActionButtonVisual(button, role or "utility")
    end
    return button
end

local function CreateSpacer(width, height)
    local spacer = AceGUI:Create("Label")
    spacer:SetText("")
    spacer:SetFullWidth(false)
    spacer:SetWidth(width or 8)
    if height then
        spacer:SetHeight(height)
    end
    return spacer
end

local function LockContainerHeight(container, height)
    if not container then
        return
    end
    if container.SetAutoAdjustHeight then
        container:SetAutoAdjustHeight(false)
    end
    container:SetHeight(height)
    if container.frame and container.frame.SetHeight then
        container.frame:SetHeight(height)
    end
end

local function GetSelectedUnit()
    local objectSelection = ns.GUI and ns.GUI.Editor and ns.GUI.Editor.ObjectSelection or nil
    if objectSelection and type(objectSelection.GetSelectedObject) == "function" then
        local selectedObject = objectSelection.GetSelectedObject()
        if type(selectedObject) == "table" and type(selectedObject.unit) == "string" and selectedObject.unit ~= "" then
            return selectedObject.unit
        end
    end

    local editorState = ns.GUI and ns.GUI.Editor and ns.GUI.Editor.State or nil
    if editorState and type(editorState.GetPrimaryUnit) == "function" then
        return editorState.GetPrimaryUnit()
    end

    local state = editorState and type(editorState.Get) == "function" and editorState.Get() or nil
    return type(state) == "table" and state.selectedUnit or nil
end

local function GetTargetUnit(context)
    if type(context) == "table" and type(context.targetUnit) == "string" and context.targetUnit ~= "" then
        return context.targetUnit
    end
    return GetSelectedUnit()
end

local function GetActiveTemplates()
    local resolver = ns.ActiveLayoutResolver or {}
    local templates = resolver.GetActiveTextTemplates and resolver.GetActiveTextTemplates(ns.db) or nil
    return type(templates) == "table" and templates or {}
end

local function BuildTemplateEntries()
    local templates = GetActiveTemplates()
    local keys = {}
    for templateName, templateText in pairs(templates) do
        if type(templateName) == "string" and templateName ~= "" and type(templateText) == "string" then
            keys[#keys + 1] = templateName
        end
    end
    table.sort(keys, SortKeys)

    local entries = {}
    for _, templateName in ipairs(keys) do
        entries[#entries + 1] = {
            key = "active:" .. templateName,
            templateName = templateName,
            templateText = templates[templateName],
            sourceType = "activeLayout",
            sourceLabel = T("INSERT_TEXT_SOURCE_CURRENT_LAYOUT", "Current layout"),
        }
    end

    local library = ns.TextTemplateLibrary or {}
    local integratedEntries = library.ListIntegratedTemplateDefinitions and library.ListIntegratedTemplateDefinitions() or {}
    for index, entry in ipairs(integratedEntries) do
        if type(entry) == "table" and type(entry.templateName) == "string" and entry.templateName ~= "" and type(entry.templateValue) == "string" then
            local key = library.BuildTemplateEntryKey and library.BuildTemplateEntryKey(entry) or nil
            entries[#entries + 1] = {
                key = key or "library:" .. tostring(index) .. ":" .. entry.templateName,
                templateName = entry.templateName,
                templateText = entry.templateValue,
                sourceType = entry.sourceType,
                sourceId = entry.sourceId,
                themeId = entry.themeId,
                sourceLabel = entry.sourceLabel,
            }
        end
    end

    return entries
end

local function ResolveActiveEntityLayoutId()
    local char = ns.db and ns.db.char
    return type(char) == "table" and char.activeLayoutId or nil
end

local function BuildEntityTemplateEntries()
    local library = ns.TextTemplateLibrary or {}
    local rows = library.Entity and library.Entity.List and library.Entity.List(ns.db) or {}
    local entries = {}
    for _, row in ipairs(rows or {}) do
        if type(row) == "table" and type(row.value) == "string" and type(row.label) == "string" then
            entries[#entries + 1] = {
                key = "entity:" .. row.value,
                templateId = row.value,
                templateName = row.label,
                templateText = row.content,
                sourceType = row.readOnly and "builtin" or "user",
                sourceLabel = row.readOnly and T("INSERT_TEXT_SOURCE_BUILTIN", "Built-in") or T("INSERT_TEXT_SOURCE_USER", "User"),
                readOnly = row.readOnly == true,
            }
        end
    end
    return entries
end

local function FindInitialEntityEntryKey(entries, templateId)
    if type(entries) ~= "table" or type(templateId) ~= "string" or templateId == "" then return nil end
    for _, entry in ipairs(entries) do
        if entry.templateId == templateId then return entry.key end
    end
    return nil
end

local function BuildEntityMutationContext(context)
    local target = type(context) == "table" and context.entityPickerTarget or nil
    local layoutId = type(target) == "table" and target.layoutId or ResolveActiveEntityLayoutId()
    local global = ns.db and ns.db.global
    local layouts = type(global) == "table" and global.UserLayouts or nil
    local record = type(layouts) == "table" and layouts[layoutId] or nil
    local payload = type(record) == "table" and record.payload or nil
    local units = type(payload) == "table" and payload.Units or nil
    return {
        db = ns.db,
        expectedLayoutId = layoutId,
        expectedTextConfig = type(target) == "table" and target.textConfig or nil,
        GetUnits = function() return units end,
        GetUnitConfig = function(unitKey) return type(units) == "table" and units[unitKey] or nil end,
    }
end

local function CaptureEntityPickerTarget(options, mode)
    local layoutId = type(options.layoutId) == "string" and options.layoutId or ResolveActiveEntityLayoutId()
    local target = {
        layoutId = layoutId,
        unitKey = options.unit,
        textKey = options.textKey,
    }
    local global = ns.db and ns.db.global
    local layouts = type(global) == "table" and global.UserLayouts or nil
    local record = type(layouts) == "table" and layouts[layoutId] or nil
    local payload = type(record) == "table" and record.payload or nil
    local units = type(payload) == "table" and payload.Units or nil
    local unit = type(units) == "table" and units[options.unit] or nil
    local texts = type(unit) == "table" and unit.Texts or nil
    target.textConfig = mode == "change" and type(texts) == "table" and texts[options.textKey] or nil

    local entityContext = ns.GUI and ns.GUI.Pages and ns.GUI.Pages.TextBuilder
        and ns.GUI.Pages.TextBuilder.EntityContext
    if mode == "change" and entityContext and type(entityContext.Snapshot) == "function" then
        target.snapshot, target.snapshotError = entityContext.Snapshot({
            kind = "object",
            layoutId = layoutId,
            unitKey = options.unit,
            textKey = options.textKey,
            returnContext = options.returnContext,
        }, ns.db, layoutId)
    end
    return target
end

local function ValidateEntityPickerTarget(context)
    local target = type(context) == "table" and context.entityPickerTarget or nil
    local activeLayoutId = ResolveActiveEntityLayoutId()
    if type(target) ~= "table" or type(target.layoutId) ~= "string"
        or target.layoutId ~= activeLayoutId then
        return false, "layout_mismatch"
    end
    if context.mode ~= "change" then
        return true
    end
    if target.snapshotError then
        return false, target.snapshotError
    end
    local entityContext = ns.GUI and ns.GUI.Pages and ns.GUI.Pages.TextBuilder
        and ns.GUI.Pages.TextBuilder.EntityContext
    if target.snapshot and entityContext and type(entityContext.Snapshot) == "function"
        and type(entityContext.SameSession) == "function" then
        local current, reason = entityContext.Snapshot({
            kind = "object",
            layoutId = target.layoutId,
            unitKey = target.unitKey,
            textKey = target.textKey,
            returnContext = context.returnContext,
        }, ns.db, activeLayoutId)
        if not current then
            return false, reason or "invalid_context"
        end
        if not entityContext.SameSession(target.snapshot, current) then
            return false, "stale_context"
        end
        return true
    end
    local global = ns.db and ns.db.global
    local layouts = type(global) == "table" and global.UserLayouts or nil
    local record = type(layouts) == "table" and layouts[target.layoutId] or nil
    local payload = type(record) == "table" and record.payload or nil
    local units = type(payload) == "table" and payload.Units or nil
    local unit = type(units) == "table" and units[target.unitKey] or nil
    local texts = type(unit) == "table" and unit.Texts or nil
    if type(texts) ~= "table" or texts[target.textKey] ~= target.textConfig then
        return false, "stale_context"
    end
    return true
end

local function NotifyEntityReturn(context, result)
    local returnContext = type(context) == "table" and context.returnContext or nil
    local token = type(returnContext) == "table" and returnContext.originToken or nil
    if type(token) ~= "table" or getmetatable(token) ~= nil or next(token) ~= nil then return end
    local returned = {
        pickerMode = returnContext.pickerMode,
        layoutId = returnContext.layoutId,
        unitKey = returnContext.unitKey,
        textKey = returnContext.textKey,
        originToken = token,
        templateId = result and result.templateId,
    }
    lastEntityReturn = returned
    local origin = pendingEntityReturns[token]
    if origin then
        origin.returnedTemplateId = returned.templateId
        origin.returnedTextKey = result and result.textKey
    end
    local toolbar = ns.GUI and ns.GUI.Editor and ns.GUI.Editor.CanvasToolbar
    if toolbar and type(toolbar.AcceptEntityReturn) == "function" then
        toolbar.AcceptEntityReturn(returnContext, result)
    end
end
local function GetEntryLabel(entry)
    if type(entry) ~= "table" then
        return ""
    end
    return entry.templateName or ""
end

local function GetEntryTypeLabel(entry)
    if type(entry) ~= "table" then
        return ""
    end
    if entry.sourceType == "activeLayout" then
        return T("INSERT_TEXT_SOURCE_CURRENT_LAYOUT", "Current layout")
    end
    return entry.readOnly
        and T("INSERT_TEXT_TYPE_BUILTIN_READ_ONLY", "Built-in · Read-only")
        or T("INSERT_TEXT_TYPE_USER_TEMPLATE", "User Template")
end

local function FindEntry(context, entryKey)
    if type(context) ~= "table" or type(context.entries) ~= "table" then
        return nil
    end
    for _, entry in ipairs(context.entries) do
        if entry.key == entryKey then
            return entry
        end
    end
    return nil
end

local function FindInitialEntryKey(entries, templateName)
    if type(entries) ~= "table" or type(templateName) ~= "string" or templateName == "" then
        return nil
    end
    for _, entry in ipairs(entries) do
        if entry.sourceType == "activeLayout" and entry.templateName == templateName then
            return entry.key
        end
    end
    return nil
end
local function ResolveMutationStatus(result)
    local errorCode = type(result) == "table" and result.errorCode or nil
    if errorCode == "invalid_template_name" or errorCode == "template_not_found" then
        return T("INSERT_TEXT_STATUS_SELECT_TEMPLATE", "Select a text template first.")
    end
    if errorCode == "unit_not_found" then
        return T("INFO_TEXT_BUILDER_STATUS_UNIT_NOT_FOUND", "Unit configuration was not found.")
    end
    if errorCode == "invalid_context" then
        return T("INFO_TEXT_BUILDER_STATUS_CONTEXT_INVALID", "The active profile is not available.")
    end
    if errorCode == "layout_mismatch" or errorCode == "stale_context"
        or errorCode == "text_element_not_found" then
        return T("INFO_TEXT_BUILDER_STATUS_CONTEXT_INVALID", "The active profile is not available.")
    end
    return T("INSERT_TEXT_STATUS_FAILED", "Text could not be added.")
end

local function ResolvePrimaryLabel(context)
    if type(context) == "table" and context.mode == "change" then
        return T("INSERT_TEXT_CHANGE_PRIMARY", "Change")
    end
    return T("INSERT_TEXT_ADD", "Add")
end

local function RefreshPreview(context)
    if type(context) ~= "table" or not context.previewGroup then
        return
    end

    context.previewGroup:ReleaseChildren()
    local entry = FindEntry(context, context.selectedTemplateKey)
    if not entry then
        context.previewPanel = nil
        context.previewGroup:AddChild(CreateLabel(T("INSERT_TEXT_PREVIEW", "Preview"), "sectionHeader", 11, 388, 18))
        context.previewGroup:AddChild(CreateLabel(T("INSERT_TEXT_PREVIEW_EMPTY", "Select a template to preview it."), "help", 12, 388, 72))
        return
    end

    context.previewGroup:AddChild(CreateLabel(entry.templateName, "sectionHeader", 14, 388, 22))
    context.previewGroup:AddChild(CreateLabel(T("INSERT_TEXT_PREVIEW", "Preview"), "sectionHeader", 11, 388, 18))

    local previewPanel = CreateResultPanel(context.previewGroup)
    if not previewPanel then
        context.previewPanel = nil
        context.previewGroup:AddChild(CreateLabel(T("INSERT_TEXT_PREVIEW_EMPTY", "Select a template to preview it."), "help", 12, 388, 72))
        return
    end
    context.previewPanel = previewPanel
    previewPanel:SetFullWidth(false)
    previewPanel:SetWidth(388)
    previewPanel:AddChild(CreateLabel(BuildRenderedPreview(entry.templateText), "highlight", 17, 368, 48))
    context.previewGroup:AddChild(previewPanel)

    context.previewGroup:AddChild(CreateLabel(T("INSERT_TEXT_DETAILS", "Details"), "sectionHeader", 11, 388, 18))
    context.previewGroup:AddChild(CreateLabel(
        T("INSERT_TEXT_NAME", "Name") .. ": " .. tostring(entry.templateName or ""),
        "label", 10, 388, 14))
    context.previewGroup:AddChild(CreateLabel(
        GetEntryTypeLabel(entry),
        "help", 10, 388, 14))
    context.previewGroup:AddChild(CreateLabel(T("INSERT_TEXT_EXPRESSION", "Expression"), "label", 10, 388, 14))
    context.previewGroup:AddChild(CreateLabel(Shorten(entry.templateText, 360), "help", 11, 388, 28))
end

local function SetStatus(context, message, role)
    if context and context.dialog then
        context.dialog:SetStatus(message, role, context.statusTarget)
    end
end

local function RefreshSelectionRowVisual(context, entryKey)
    local row = context and context.rowWidgets and context.rowWidgets[entryKey] or nil
    local binding = context and context.rowBindings and context.rowBindings[entryKey] or nil
    if row and binding and row.Bind then
        binding.selected = entryKey == context.selectedTemplateKey
        row:Bind(binding)
    end
end
local function RefreshRows(context)
    if type(context) ~= "table" or not context.listGroup then
        return
    end

    context.listGroup:ReleaseChildren()
    context.rowWidgets = {}
    context.rowBindings = {}
    if #context.entries == 0 then
        context.listGroup:AddChild(CreateLabel(T("INSERT_TEXT_EMPTY", "No text templates available."), "help", 11, 214, 44))
        return
    end

    for _, entry in ipairs(context.entries) do
        local binding = {
            key = entry.key,
            label = GetEntryLabel(entry) .. " | " .. tostring(entry.sourceLabel or ""),
            selected = entry.key == context.selectedTemplateKey,
            onSelect = function(entryKey)
                local previousTemplateKey = context.selectedTemplateKey
                context.selectedTemplateKey = entryKey
                RefreshSelectionRowVisual(context, previousTemplateKey)
                RefreshSelectionRowVisual(context, entryKey)
                RefreshPreview(context)
                if context.primaryButton then
                    context.primaryButton:SetDisabled(false)
                end
            end,
        }
        local row = SelectionRow.Create and SelectionRow.Create(binding) or nil
        if row then
            row:SetFullWidth(false)
            row:SetWidth(214)
            context.listGroup:AddChild(row)
            context.rowWidgets[entry.key] = row
            context.rowBindings[entry.key] = binding
        end
    end
end

local SelectText

local function SubmitEntityTemplate(context, unitKey, entry)
    local mutations = ns.TextTemplateMutations and ns.TextTemplateMutations.Entity or nil
    local valid, reason = ValidateEntityPickerTarget(context)
    if not valid then
        SetStatus(context, ResolveMutationStatus({errorCode = reason}))
        return
    end
    local mutationContext = BuildEntityMutationContext(context)
    if type(mutations) ~= "table" or type(mutationContext.expectedLayoutId) ~= "string" then
        SetStatus(context, ResolveMutationStatus({errorCode = "invalid_context"}))
        return
    end
    local result
    if context.mode == "change" then
        local textKey = context.targetTextKey
        if type(textKey) ~= "string" or textKey == "" then
            SetStatus(context, T("INSERT_TEXT_STATUS_SELECT_TEXT", "Select a text object first."))
            return
        end
        if entry.templateId == context.initialTemplateId then
            NotifyEntityReturn(context, {templateId = entry.templateId, changed = false, textKey = textKey})
            SelectText(unitKey, textKey)
            context.dialog:Close()
            return
        end
        result = mutations.AssignMainTemplate(mutationContext, unitKey, textKey, entry.templateId)
    else
        local anchorTo = ns.TextTemplateMutations.ResolveTextAnchorTarget
            and ns.TextTemplateMutations.ResolveTextAnchorTarget(mutationContext, context.anchorSelection)
            or "Frame"
        result = mutations.CreateTextFromTemplate(mutationContext, unitKey, entry.templateId, {anchorTo = anchorTo})
    end
    if type(result) ~= "table" or not result.ok then
        SetStatus(context, ResolveMutationStatus(result))
        return
    end
    NotifyEntityReturn(context, result)
    if ns.RefreshUnitFrame then ns:RefreshUnitFrame(result.unitKey or unitKey) end
    SelectText(result.unitKey or unitKey, result.textKey or context.targetTextKey)
    if ns.GUI and ns.GUI.RequestRefreshOptions then ns.GUI:RequestRefreshOptions("TextTemplateLibrary.ApplyEntityTemplate") end
    context.dialog:Close()
end
local function RefreshWindow(context)
    if type(context) ~= "table" then
        return
    end
    context.entries = context.entity and BuildEntityTemplateEntries() or BuildTemplateEntries()
    if not FindEntry(context, context.selectedTemplateKey) then
        context.selectedTemplateKey = context.entity
            and FindInitialEntityEntryKey(context.entries, context.initialTemplateId)
            or FindInitialEntryKey(context.entries, context.initialTemplateName)
            or (context.entries[1] and context.entries[1].key or nil)
    end
    RefreshRows(context)
    RefreshPreview(context)
    if context.primaryButton then
        context.primaryButton:SetDisabled(context.selectedTemplateKey == nil)
    end
end

SelectText = function(unitKey, textKey)
    local objectSelection = ns.GUI and ns.GUI.Editor and ns.GUI.Editor.ObjectSelection or nil
    if objectSelection and type(objectSelection.SelectObject) == "function" then
        return objectSelection.SelectObject({
            kind = "text",
            unit = unitKey,
            textKey = textKey,
        })
    end
    return false
end

local function SubmitSelectedTemplate(context)
    local unitKey = GetTargetUnit(context)
    if type(unitKey) ~= "string" or unitKey == "" then
        SetStatus(context, T("INSERT_TEXT_STATUS_SELECT_UNIT", "Select a unit first."))
        return
    end

    local entry = FindEntry(context, context.selectedTemplateKey)
    if type(entry) ~= "table" then
        SetStatus(context, T("INSERT_TEXT_STATUS_SELECT_TEMPLATE", "Select a text template first."))
        return
    end

    if context.entity then
        return SubmitEntityTemplate(context, unitKey, entry)
    end

    local mutations = ns.TextTemplateMutations or {}
    local mutationContext = mutations.CreateActiveLayoutContext and mutations.CreateActiveLayoutContext(ns.db) or nil
    local materialized = mutations.MaterializeTemplateEntry and mutations.MaterializeTemplateEntry(mutationContext, entry) or nil
    if type(materialized) ~= "table" or not materialized.ok then
        SetStatus(context, ResolveMutationStatus(materialized))
        return
    end
    local templateName = materialized.templateName

    if context.mode == "change" then
        local textKey = context.targetTextKey
        if type(textKey) ~= "string" or textKey == "" then
            SetStatus(context, T("INSERT_TEXT_STATUS_SELECT_TEXT", "Select a text object first."))
            return
        end

        if templateName == context.initialTemplateName then
            SelectText(unitKey, textKey)
            context.dialog:Close()
            return
        end

        local result = mutations.AssignTemplate and mutations.AssignTemplate(mutationContext, unitKey, textKey, templateName) or nil
        if type(result) ~= "table" or not result.ok then
            SetStatus(context, ResolveMutationStatus(result))
            return
        end

        if ns.RefreshUnitFrame then
            ns:RefreshUnitFrame(result.unitKey or unitKey)
        end
        SelectText(result.unitKey or unitKey, result.textKey or textKey)
        if ns.GUI and ns.GUI.RequestRefreshOptions then
            ns.GUI:RequestRefreshOptions("TextTemplateLibrary.ApplyTemplate")
        end
        context.dialog:Close()
        return
    end

    local anchorTo = mutations.ResolveTextAnchorTarget and mutations.ResolveTextAnchorTarget(mutationContext, context.anchorSelection) or "Frame"
    local result = mutations.CreateTextFromTemplate and mutations.CreateTextFromTemplate(mutationContext, unitKey, templateName, {
        anchorTo = anchorTo,
    }) or nil
    if type(result) ~= "table" or not result.ok then
        SetStatus(context, ResolveMutationStatus(result))
        return
    end

    if ns.RefreshUnitFrame then
        ns:RefreshUnitFrame(unitKey)
    end
    SelectText(result.unitKey or unitKey, result.textKey)
    if ns.GUI and ns.GUI.RequestRefreshOptions then
        ns.GUI:RequestRefreshOptions("TextTemplateLibrary.ApplyTemplate")
    end
    context.dialog:Close()
end

local function BuildEntityReturnContext(context)
    return {
        pickerMode = context.mode,
        layoutId = ResolveActiveEntityLayoutId(),
        unitKey = context.targetUnit,
        textKey = context.targetTextKey,
        originToken = context.originToken,
        anchorContext = type(context.anchorSelection) == "table" and {
            kind = context.anchorSelection.kind,
            unitKey = context.anchorSelection.unit,
            textKey = context.anchorSelection.textKey,
            objectKey = context.anchorSelection.objectKey,
            sectionKey = context.anchorSelection.sectionKey,
        } or nil,
    }
end

local function OpenEntityBuilder(context, request)
    local controller = ns.GUIController or {}
    if type(controller.OpenTextBuilderWindow) ~= "function" then return false end
    request.returnContext = BuildEntityReturnContext(context)
    local accepted = controller.OpenTextBuilderWindow(request)
    if accepted ~= true then
        SetStatus(context, T("INFO_TEXT_BUILDER_STATUS_CONTEXT_INVALID", "The active profile is not available."))
        return false
    end
    pendingEntityReturns[context.originToken] = context
    context.dialog:Close()
    return true
end

local function OpenTextBuilder()
    local context = windowContext
    if not context then return end
    if context.entity then
        OpenEntityBuilder(context, {entity = true, kind = "new-template", layoutId = ResolveActiveEntityLayoutId()})
        return
    end
    if context.dialog then context.dialog:Close() end
    local controller = ns.GUIController or {}
    if controller.OpenTextBuilderWindow then controller.OpenTextBuilderWindow() end
end

local function BuildFooter(context)
    local actions = {
        primary = {
            text = ResolvePrimaryLabel(context),
            role = "primary_action",
            width = 82,
            onClick = function() SubmitSelectedTemplate(context) end,
        },
        secondary = {
            text = T("INSERT_TEXT_CREATE_NEW_TEMPLATE", "Create New Template"),
            role = "utility",
            width = 190,
            onClick = OpenTextBuilder,
        },
        cancel = {
            text = T("INSERT_TEXT_CANCEL", "Cancel"),
            role = "utility",
            width = 82,
            onClick = function() context.dialog:Close() end,
        },
    }
    context.dialog:SetActions(actions, context.actionContainer)
    context.primaryButton = context.dialog.primaryButton
end

local function BuildBody(context)
    local body = context.dialog.body
    body:ReleaseChildren()
    body:SetLayout("List")

    local description = CreateLabel(
        context.mode == "change" and T("INSERT_TEXT_CHANGE_DESCRIPTION", "Choose a text template for this text object.") or T("INSERT_TEXT_DESCRIPTION", "Choose a text template."),
        "help",
        11,
        nil,
        24
    )
    body:AddChild(description)

    local descriptionGap = CreateSpacer(nil, 6)
    descriptionGap:SetFullWidth(true)
    body:AddChild(descriptionGap)

    local content = AceGUI:Create("SimpleGroup")
    content:SetLayout("Flow")
    content:SetFullWidth(true)
    content:SetFullHeight(false)
    LockContainerHeight(content, 228)
    body:AddChild(content)

    local listColumn = AceGUI:Create("SimpleGroup")
    listColumn:SetLayout("List")
    listColumn:SetFullWidth(false)
    listColumn:SetWidth(220)
    LockContainerHeight(listColumn, 228)
    listColumn:AddChild(CreateLabel(T("INSERT_TEXT_TEMPLATES", "Templates"), "sectionHeader", 11, 202, 18))
    local listGroup = AceGUI:Create("ScrollFrame")
    listGroup:SetLayout("List")
    listGroup:SetFullWidth(false)
    listGroup:SetWidth(202)
    LockContainerHeight(listGroup, 200)
    context.listGroup = listGroup
    listColumn:AddChild(listGroup)
    content:AddChild(listColumn)

    local previewColumn = AceGUI:Create("SimpleGroup")
    previewColumn:SetLayout("List")
    previewColumn:SetFullWidth(false)
    previewColumn:SetWidth(400)
    LockContainerHeight(previewColumn, 228)
    local previewGroup = AceGUI:Create("SimpleGroup")
    previewGroup:SetLayout("List")
    previewGroup:SetFullWidth(false)
    previewGroup:SetWidth(388)
    LockContainerHeight(previewGroup, 218)
    context.previewGroup = previewGroup
    previewColumn:AddChild(previewGroup)
    content:AddChild(previewColumn)

    local status = CreateLabel(" ", "help", 10, nil, 16)
    context.statusTarget = status
    body:AddChild(status)

    local actionContainer = AceGUI:Create("SimpleGroup")
    actionContainer:SetLayout("Flow")
    actionContainer:SetFullWidth(true)
    if actionContainer.SetAutoAdjustHeight then
        actionContainer:SetAutoAdjustHeight(false)
    end
    actionContainer:SetHeight(30)
    context.actionContainer = actionContainer
    body:AddChild(actionContainer)
end

-- The manager is intentionally local to this existing template window module.
-- It shares the picker rows, compact window shell and canonical result panel;
-- it never carries an object or layout binding context.
local function ManagerR2()
    return ns.GUI and ns.GUI.Pages and ns.GUI.Pages.TextBuilder
        and ns.GUI.Pages.TextBuilder.EntityBuilder
end

local function BuildManagerEntries()
    local library = ns.TextTemplateLibrary or {}
    local rows = library.Entity and library.Entity.List and library.Entity.List(ns.db) or {}
    local user, builtin = {}, {}
    for _, row in ipairs(rows or {}) do
        if type(row) == "table" and type(row.value) == "string" and type(row.label) == "string" then
            local entry = {
                key = "entity:" .. row.value,
                templateId = row.value,
                templateName = row.label,
                templateText = row.content,
                readOnly = row.readOnly == true,
            }
            if entry.readOnly then builtin[#builtin + 1] = entry else user[#user + 1] = entry end
        end
    end
    local function SortEntries(left, right)
        if left.templateName ~= right.templateName then
            return left.templateName < right.templateName
        end
        return left.templateId < right.templateId
    end
    table.sort(user, SortEntries)
    table.sort(builtin, SortEntries)
    return user, builtin
end

local function FindManagerEntry(context, templateId)
    if not context or type(templateId) ~= "string" then return nil end
    for _, entry in ipairs(context.userEntries or {}) do
        if entry.templateId == templateId then return entry end
    end
    for _, entry in ipairs(context.builtinEntries or {}) do
        if entry.templateId == templateId then return entry end
    end
end

local function ManagerStatus(message, role)
    if managerContext and managerContext.dialog and managerContext.statusTarget then
        managerContext.dialog:SetStatus(message or " ", role, managerContext.statusTarget)
    end
end

local function ManagerGroup(parent, height, layout)
    local group = AceGUI:Create("SimpleGroup")
    group:SetLayout(layout or "List")
    group:SetFullWidth(true)
    LockContainerHeight(group, height)
    parent:AddChild(group)
    return group
end

local function ManagerText(parent, text, role, size, height)
    local slot = ManagerGroup(parent, height)
    local label = CreateLabel(text, role, size)
    slot:AddChild(label)
    return label, slot
end

local function AddManagerHeader(parent, text)
    local row = ManagerGroup(parent, 24, "Flow")
    row:AddChild(CreateLabel(text, "sectionHeader", 12, 210))
    local divider = AceGUI:Create("SimpleGroup")
    divider:SetFullWidth(false)
    divider:SetWidth(220)
    LockContainerHeight(divider, 1)
    row:AddChild(divider)
    local line = divider._fpDivider
    if not line then
        line = divider.frame:CreateTexture(nil, "ARTWORK")
        divider._fpDivider = line
        divider.frame:HookScript("OnHide", function() line:Hide() end)
    end
    line:ClearAllPoints()
    line:SetPoint("LEFT", divider.frame, "LEFT", 0, 0)
    line:SetPoint("RIGHT", divider.frame, "RIGHT", 0, 0)
    line:SetHeight(1)
    local palette = ns.GUI.Skins.GetFormPalette() or {}
    line:SetColorTexture(unpack(palette.Chrome.sectionBorder))
    line:Show()
    return row
end

local function ManagerUsage(templateId)
    local library = ns.TextTemplateLibrary
    local references = library.Entity.Usage(ns.db.global.UserLayouts or {}, ns.db, templateId) or {}
    local summary = {texts = 0, layouts = 0, main = 0, state = 0, disabled = 0}
    local layouts = {}
    for _, reference in ipairs(references) do
        local layout = layouts[reference.layoutId]
        if not layout then
            layout = {}; layouts[reference.layoutId] = layout
            summary.layouts = summary.layouts + 1
        end
        local unit = layout[reference.unitKey]
        if not unit then unit = {}; layout[reference.unitKey] = unit end
        if not unit[reference.textKey] then
            unit[reference.textKey] = true
            summary.texts = summary.texts + 1
            if reference.enabled == false then summary.disabled = summary.disabled + 1 end
        end
        local kind = reference.referenceKind == "state" and "state" or "main"
        summary[kind] = summary[kind] + 1
    end
    return summary
end

-- These transient manager dialogs own and release their complete widget tree.
local function BindManagerDialogClose(context, dialog, kind)
    dialog.window:SetCallback("OnClose", function()
        if dialog.released then return end
        dialog.released = true
        if kind == "rename" then
            if managerRenameDialog == dialog then managerRenameDialog = nil end
            if context.renameDialog == dialog then
                context.renameDialog, context.renameEdit, context.renameStatus = nil, nil, nil
            end
        else
            if managerDeleteDialog == dialog then managerDeleteDialog = nil end
            if context.deleteDialog == dialog then context.deleteDialog = nil end
        end
        AceGUI:ClearFocus()
        AceGUI:Release(dialog.window)
    end)
end

local function ManagerSession(entry)
    local r = ManagerR2()
    local active = ResolveActiveEntityLayoutId()
    return r.Open({entity = true, kind = "shared-template", layoutId = active,
        templateId = entry.templateId}, ns.db, active)
end

local function OpenManagerRename(context, entry)
    if managerRenameDialog then managerRenameDialog:Close() end
    local r = ManagerR2()
    local session = ManagerSession(entry)
    if not session then return end
    local capture = r.Capture(session)
    local dialog = FormWidgets.CreateCompactFormDialog({
        title = T("INFO_TEXT_MANAGER_RENAME", "Rename"), width = 420, height = 210,
        bodyLayout = "List", contentRoot = true,
    })
    managerRenameDialog, context.renameDialog = dialog, dialog
    local edit = AceGUI:Create("EditBox")
    edit:SetLabel(T("INFO_TEXT_TEMPLATE_NAME", "Template Name"))
    edit:SetFullWidth(true)
    edit:SetText(entry.templateName)
    dialog.body:AddChild(edit)
    ManagerGroup(dialog.body, 8)
    local status = ManagerText(dialog.body, " ", "help", 10, 34)
    local actions = ManagerGroup(dialog.body, 30, "Flow")
    context.renameEdit, context.renameStatus = edit, status
    dialog:SetActions({
        primary = {text = T("INFO_TEXT_MANAGER_RENAME", "Rename"), role = "primary_action", width = 110,
            onClick = function()
                if dialog.released then return end
                if managerContext ~= context or context.selectedTemplateId ~= entry.templateId
                    or not r.Valid(session, capture) then
                    dialog:SetStatus(T("INFO_TEXT_BUILDER_STATUS_CONTEXT_INVALID"), "error", status)
                    return
                end
                local name = Trim(edit:GetText() or "")
                if name == "" then
                    dialog:SetStatus(T("INFO_TEXT_STATUS_INVALID_NAME", "Enter a template name."), "error", status)
                    return
                end
                local ok = r.SetName(session, name)
                if ok then capture = r.Capture(session) end
                local result = ok and r.Rename(session)
                if result and result.ok then
                    dialog:Close()
                    TextTemplateLibraryWindow.Refresh()
                    ManagerStatus(T("INFO_TEXT_MANAGER_STATUS_RENAMED", "Template renamed."), "success")
                else
                    dialog:SetStatus(T("INFO_TEXT_MANAGER_STATUS_FAILED", "Template operation failed."), "error", status)
                end
            end},
        cancel = {text = T("INFO_COMMON_CANCEL", "Cancel"), width = 100,
            onClick = function() dialog:Close() end},
    }, actions)
    BindManagerDialogClose(context, dialog, "rename")
    dialog:Show()
    edit:SetFocus()
end

local function ManagerDeleteSuccessor(context, id)
    for index, entry in ipairs(context.userEntries) do
        if entry.templateId == id then
            local nextEntry = context.userEntries[index + 1] or context.userEntries[index - 1]
                or context.builtinEntries[1]
            return nextEntry and nextEntry.templateId
        end
    end
end

local function OpenManagerDelete(context, entry)
    if managerDeleteDialog then managerDeleteDialog:Close() end
    local r = ManagerR2()
    local session = ManagerSession(entry)
    if not session then return end
    local capture = r.Capture(session)
    local dialog = FormWidgets.CreateCompactConfirmation({
        title = T("INFO_TEXT_MANAGER_DELETE", "Delete"),
        message = string.format(T("INFO_TEXT_MANAGER_DELETE_PROMPT", 'Delete the template "%s"?'), entry.templateName),
        primary = {text = T("INFO_TEXT_MANAGER_DELETE", "Delete"), role = "danger", width = 100},
        cancel = {text = T("INFO_COMMON_CANCEL", "Cancel"), width = 100},
    })
    managerDeleteDialog, context.deleteDialog = dialog, dialog
    dialog.primaryButton:SetCallback("OnClick", function()
        if dialog.released then return end
        if managerContext ~= context or context.selectedTemplateId ~= entry.templateId
            or not r.Valid(session, capture) then
            dialog:SetStatus(T("INFO_TEXT_BUILDER_STATUS_CONTEXT_INVALID"), "error", dialog.confirmationStatus)
            return
        end
        local successor = ManagerDeleteSuccessor(context, entry.templateId)
        local result = r.Delete(session)
        if result and result.ok then
            dialog:Close()
            context.selectedTemplateId = successor
            TextTemplateLibraryWindow.Refresh()
            ManagerStatus(T("INFO_TEXT_MANAGER_STATUS_DELETED", "Template deleted."), "success")
        else
            dialog:SetStatus(result and result.errorCode == "template_in_use"
                and T("INFO_TEXT_BUILDER_STATUS_TEMPLATE_IN_USE")
                or T("INFO_TEXT_MANAGER_STATUS_FAILED", "Template operation failed."), "error", dialog.confirmationStatus)
        end
    end)
    BindManagerDialogClose(context, dialog, "delete")
    dialog:Show()
end

local function RefreshManagerActions(context, entry)
    local container = context.actionContainer
    container:ReleaseChildren()
    context.actionButtons = {}
    if not entry then return end
    local previous
    local function Add(key, label, role, width, action, disabled)
        local button = CreateButton(label, role, width)
        context.actionButtons[key] = button
        button:SetDisabled(disabled == true)
        button:SetCallback("OnClick", function()
            if managerContext ~= context or context.selectedTemplateId ~= entry.templateId
                or button.disabled then return end
            action()
        end)
        -- The paused local action bar keeps these explicit anchors.
        container:AddChild(button)
        button.frame:ClearAllPoints()
        if key == "delete" then
            button.frame:SetPoint("RIGHT", container.content, "RIGHT", 0, 0)
        elseif previous then
            button.frame:SetPoint("LEFT", previous, "RIGHT", 8, 0)
        else
            button.frame:SetPoint("LEFT", container.content, "LEFT", 0, 0)
        end
        if key ~= "delete" then previous = button.frame end
    end
    if not entry.readOnly then
        Add("edit", T("INFO_TEXT_MANAGER_EDIT", "Edit"), "utility", 84, function()
            local ok = ManagerR2().OpenTemplateEditor(entry.templateId, true)
            if not ok then
                TextTemplateLibraryWindow.ShowManager(entry.templateId)
                ManagerStatus(T("INFO_TEXT_MANAGER_STATUS_FAILED"), "error")
            end
        end)
        Add("rename", T("INFO_TEXT_MANAGER_RENAME", "Rename"), "utility", 108,
            function() OpenManagerRename(context, entry) end)
    end
    Add("duplicate", T("INFO_TEXT_MANAGER_DUPLICATE", "Duplicate"), "utility", 112, function()
        local session = ManagerSession(entry)
        local result = session and ManagerR2().Copy(session)
        if result and result.ok then
            context.selectedTemplateId = result.templateId
            TextTemplateLibraryWindow.Refresh()
            ManagerStatus(T("INFO_TEXT_MANAGER_STATUS_DUPLICATED", "Template duplicated."), "success")
        else
            ManagerStatus(T("INFO_TEXT_MANAGER_STATUS_FAILED", "Template operation failed."), "error")
        end
    end)
    if not entry.readOnly then
        Add("delete", T("INFO_TEXT_MANAGER_DELETE", "Delete"), "danger", 92,
            function() OpenManagerDelete(context, entry) end, context.usage.texts > 0)
    end
end

local function RefreshManagerDetails()
    local context = managerContext
    if not context or not context.detailGroup then return end
    local entry = FindManagerEntry(context, context.selectedTemplateId)
    context.nameLabel:SetText(entry and entry.templateName
        or T("INFO_TEXT_MANAGER_SELECTED", "Select a template to view its details."))
    context.typeLabel:SetText(entry and (entry.readOnly and T("INFO_TEXT_MANAGER_BUILTIN_TYPE", "Built-in · Read-only")
        or T("INFO_TEXT_MANAGER_USER_TYPE", "My Template")) or "")
    context.expressionTitle:SetText(entry and T("INFO_TEXT_MANAGER_EXPRESSION", "Expression") or "")
    context.expression:SetText(entry and tostring(entry.templateText or "") or "")
    context.expressionScroll:DoLayout()
    context.expressionScroll:SetScroll(0)
    context.previewTitle:SetText(entry and T("INFO_TEXT_BUILDER_PREVIEW", "Preview") or "")
    context.previewValue:SetText(entry and BuildRenderedPreview(entry.templateText) or "")
    context.previewValue.label:SetHeight(70)
    context.previewPanel.frame:SetAlpha(entry and 1 or 0)
    context.usage = entry and not entry.readOnly and ManagerUsage(entry.templateId) or nil
    local usage = context.usage
    context.usageLabel:SetText(usage and string.format(
        T("INFO_TEXT_MANAGER_USAGE_SUMMARY", "Used by %d texts in %d layouts"), usage.texts, usage.layouts)
        .. "\n" .. string.format(T("INFO_TEXT_MANAGER_USAGE_DETAIL", "Main: %d · State: %d · Disabled texts: %d"),
            usage.main, usage.state, usage.disabled) or "")
    context.detailGroup:DoLayout()
    RefreshManagerActions(context, entry)
end

local function ManagerSelect(templateId)
    local context = managerContext
    if not context or not FindManagerEntry(context, templateId) then return end
    context.selectedTemplateId = templateId
    for id, row in pairs(context.rows) do
        row.binding.selected = id == templateId
        row:Bind(row.binding)
    end
    ManagerStatus("")
    RefreshManagerDetails()
end

local function RefreshManagerList()
    local context = managerContext
    if not context or not context.listGroup then return end
    context.userEntries, context.builtinEntries = BuildManagerEntries()
    if not FindManagerEntry(context, context.selectedTemplateId) then
        local first = context.userEntries[1] or context.builtinEntries[1]
        context.selectedTemplateId = first and first.templateId
    end
    local scroll = context.listGroup
    scroll:PauseLayout()
    context.headers = context.headers or {}
    -- Retain the two heading/divider widgets while rebuilding only the rows.
    for index = #scroll.children, 1, -1 do
        local child = scroll.children[index]
        if child == context.headers.user or child == context.headers.builtin then
            table.remove(scroll.children, index)
        end
    end
    scroll:ReleaseChildren()
    context.rows = {}
    local function AddRows(entries, heading, builtin)
        local key = builtin and "builtin" or "user"
        local text = string.format("%s (%d)", heading, #entries)
        local header = context.headers[key]
        if header then
            header.children[1]:SetText(text)
            scroll:AddChild(header)
            header.children[2]._fpDivider:Show()
        else
            context.headers[key] = AddManagerHeader(scroll, text)
        end
        if not builtin and #entries == 0 then
            scroll:AddChild(CreateLabel(T("INFO_TEXT_MANAGER_EMPTY", "No user templates yet."), "help", 11))
        end
        for _, entry in ipairs(entries) do
            local row = SelectionRow.Create({key = entry.key, label = entry.templateName,
                detail = builtin and T("INFO_TEXT_MANAGER_READ_ONLY", "Read-only") or T("INFO_TEXT_MANAGER_USER_TYPE", "My Template"),
                selected = entry.templateId == context.selectedTemplateId,
                onSelect = function() ManagerSelect(entry.templateId) end})
            row:SetFullWidth(true)
            context.rows[entry.templateId] = row
            scroll:AddChild(row)
        end
    end
    AddRows(context.userEntries, T("INFO_TEXT_MANAGER_MY_TEMPLATES", "My Templates"), false)
    ManagerGroup(scroll, 8)
    AddRows(context.builtinEntries, T("INFO_TEXT_MANAGER_BUILTIN_TEMPLATES", "Built-in Templates"), true)
    scroll:ResumeLayout()
    scroll:DoLayout()
end

local function BuildManagerBody(context)
    local body = context.dialog.body
    body:ReleaseChildren()
    body:SetLayout("List")
    ManagerText(body, T("INFO_TEXT_MANAGER_DESCRIPTION", "Manage reusable text templates."), "help", 11, 24)
    local newRow = ManagerGroup(body, 32, "Flow")
    local newButton = CreateButton(T("INFO_TEXT_MANAGER_NEW_TEMPLATE", "New Template"), "primary_action", 160)
    context.newButton = newButton
    newButton:SetCallback("OnClick", function()
        TextTemplateLibraryWindow.HideManager()
        local ok = ns.GUIController.OpenTextBuilderWindow({entity = true, kind = "new-template",
            layoutId = ResolveActiveEntityLayoutId(), managerReturn = true})
        if not ok then
            TextTemplateLibraryWindow.ShowManager()
            ManagerStatus(T("INFO_TEXT_MANAGER_STATUS_FAILED"), "error")
        end
    end)
    newRow:AddChild(newButton)
    ManagerGroup(body, 8)
    local list = AceGUI:Create("ScrollFrame")
    list:SetLayout("List")
    list:SetFullWidth(true)
    LockContainerHeight(list, 242)
    context.listGroup = list
    body:AddChild(list)
    ManagerGroup(body, 10)
    local detail = ManagerGroup(body, 256)
    context.detailGroup = detail
    context.nameLabel = ManagerText(detail, " ", "sectionHeader", 15, 24)
    context.typeLabel = ManagerText(detail, " ", "help", 10, 16)
    context.expressionTitle = ManagerText(detail, " ", "sectionHeader", 11, 18)
    local expression = AceGUI:Create("ScrollFrame")
    expression:SetLayout("List")
    expression:SetFullWidth(true)
    LockContainerHeight(expression, 48)
    context.expressionScroll = expression
    detail:AddChild(expression)
    context.expression = CreateLabel(" ", "label", 11)
    context.expression.label:SetWordWrap(true)
    expression:AddChild(context.expression)
    ManagerGroup(detail, 8)
    context.previewTitle = ManagerText(detail, " ", "sectionHeader", 11, 18)
    local preview = CreateResultPanel(detail)
    preview:SetFullWidth(true)
    LockContainerHeight(preview, 80)
    if preview.frame.SetClipsChildren then preview.frame:SetClipsChildren(true) end
    context.previewPanel = preview
    context.previewValue = CreateLabel(" ", "highlight", 17)
    context.previewValue:SetJustifyH("CENTER")
    context.previewValue:SetJustifyV("MIDDLE")
    context.previewValue.label:SetWordWrap(true)
    preview:AddChild(context.previewValue)
    detail:AddChild(preview)
    ManagerGroup(detail, 8)
    context.usageLabel = ManagerText(detail, " ", "help", 10, 36)
    context.statusTarget = ManagerText(body, " ", "help", 10, 20)
    ManagerGroup(body, 8)
    -- No layout owns these button anchors; visibility follows the selected type.
    context.actionContainer = ManagerGroup(body, 34)
    context.actionContainer:PauseLayout()
    ManagerGroup(body, 8)
end

function TextTemplateLibraryWindow.OpenManager()
    if managerContext and managerContext.dialog then
        return TextTemplateLibraryWindow.ShowManager()
    end
    local dialog = FormWidgets.CreateCompactFormDialog({
        title = T("INFO_TEXT_MANAGER_TITLE", "Texts Manager"),
        width = 560, height = 720, bodyLayout = "List", contentRoot = true,
    })
    if not dialog then return false, "manager-unavailable" end
    managerContext = {dialog = dialog, window = dialog.window}
    BuildManagerBody(managerContext)
    dialog.window:SetCallback("OnClose", function()
        if managerRenameDialog then managerRenameDialog:Close() end
        if managerDeleteDialog then managerDeleteDialog:Close() end
        -- Temporary hide for New/Edit preserves the selected ID and scroll.
        if not managerContext.returnPending then managerContext.selectedTemplateId = nil end
    end)
    FormWidgets.CenterWindow(dialog.window)
    RefreshManagerList()
    RefreshManagerDetails()
    dialog:Show()
    return true
end

function TextTemplateLibraryWindow.HideManager()
    if managerContext and managerContext.window then
        managerContext.returnPending = true
        managerContext.window:Hide()
    end
end

function TextTemplateLibraryWindow.ShowManager(templateId)
    local context = managerContext
    if not context or not context.dialog then return false end
    context.returnPending = nil
    if templateId then context.selectedTemplateId = templateId end
    RefreshManagerList()
    RefreshManagerDetails()
    context.dialog:Show()
    return true
end

function TextTemplateLibraryWindow.Open(options)
    if windowContext and windowContext.dialog then
        windowContext.dialog:Close()
    end
    options = type(options) == "table" and options or {}
    local mode = options.mode == "change" and "change" or "add"

    local dialog = FormWidgets.CreateCompactFormDialog and FormWidgets.CreateCompactFormDialog({
        title = mode == "change" and T("INSERT_TEXT_CHANGE_TITLE", "Choose Template") or T("INSERT_TEXT_TITLE", "Add Text"),
        description = mode == "change" and T("INSERT_TEXT_CHANGE_DESCRIPTION", "Choose a text template for this text object.") or T("INSERT_TEXT_DESCRIPTION", "Choose a text template."),
        width = 700,
        mode = "picker",
        pickerContentHeight = 304,
        bodyLayout = "List",
        contentRoot = true,
    }) or nil
    if not dialog then
        return
    end

    local context = {
        dialog = dialog,
        entries = {},
        mode = mode,
        targetUnit = options.unit,
        anchorSelection = options.anchorSelection,
        targetTextKey = options.textKey,
        entity = true,
        originToken = type(options.returnContext) == "table" and options.returnContext.originToken or (type(options.originToken) == "table" and options.originToken or {}),
        initialTemplateName = options.initialTemplateName,
        initialTemplateId = options.initialTemplateId,
        returnContext = options.returnContext,
        entityPickerTarget = CaptureEntityPickerTarget(options, mode),
        selectedTemplateKey = nil,
    }
    windowContext = context

    BuildBody(context)
    BuildFooter(context)
    RefreshWindow(context)
    dialog:Show()
end

function TextTemplateLibraryWindow.NotifyEntityReturn(returnContext, result)
    if type(returnContext) ~= "table" or type(returnContext.originToken) ~= "table"
        or getmetatable(returnContext.originToken) ~= nil or next(returnContext.originToken) ~= nil then
        return false
    end
    local token = returnContext.originToken
    local origin = pendingEntityReturns[token]
    if origin then
        local valid = ValidateEntityPickerTarget(origin)
        if not valid then
            pendingEntityReturns[token] = nil
            return false
        end
    end
    local templateId = type(result) == "table" and result.templateId or nil
    if type(templateId) ~= "string" or templateId == "" then
        return false
    end
    lastEntityReturn = {
        pickerMode = returnContext.pickerMode,
        layoutId = returnContext.layoutId,
        unitKey = returnContext.unitKey,
        textKey = returnContext.textKey,
        originToken = returnContext.originToken,
        templateId = templateId,
    }
    if not origin then
        return true, false
    end
    origin.returnedTemplateId = templateId
    origin.selectedTemplateKey = "entity:" .. templateId
    RefreshWindow(origin)
    if origin.dialog and origin.dialog.Show then
        origin.dialog:Show()
    end
    pendingEntityReturns[token] = nil
    return true, true
end

function TextTemplateLibraryWindow.GetLastEntityReturn()
    return lastEntityReturn
end
function TextTemplateLibraryWindow.Refresh()
    RefreshWindow(windowContext)
    RefreshManagerList()
    RefreshManagerDetails()
end

function TextTemplateLibraryWindow.Close()
    if windowContext and windowContext.dialog then
        windowContext.dialog:Close()
    end
    TextTemplateLibraryWindow.HideManager()
end

return TextTemplateLibraryWindow
