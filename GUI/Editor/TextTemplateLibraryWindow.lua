local _, ns = ...

ns.GUI = ns.GUI or {}
ns.GUI.Editor = ns.GUI.Editor or {}

local AceGUI = LibStub("AceGUI-3.0")
local FormWidgets = ns.GUI.Helpers and ns.GUI.Helpers.FormWidgets or {}
local TextStyles = ns.GUI.Helpers and ns.GUI.Helpers.TextStyles or {}

local TextTemplateLibraryWindow = {}
ns.GUI.Editor.TextTemplateLibraryWindow = TextTemplateLibraryWindow

local windowContext

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

local function GetEntryLabel(entry)
    if type(entry) ~= "table" then
        return ""
    end
    if entry.sourceType == "activeLayout" then
        return entry.templateName
    end
    if type(entry.sourceLabel) == "string" and entry.sourceLabel ~= "" then
        return entry.templateName .. " - " .. entry.sourceLabel
    end
    return entry.templateName
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
        context.previewGroup:AddChild(CreateLabel(T("INSERT_TEXT_PREVIEW_EMPTY", "Select a template to preview it."), "help", 11, 238, 44))
        return
    end

    context.previewGroup:AddChild(CreateLabel(entry.templateName, "section_title", 12, 238, 20))
    context.previewGroup:AddChild(CreateLabel(T("INSERT_TEXT_TEMPLATE_STRING", "Template"), "label", 10, 238, 14))
    context.previewGroup:AddChild(CreateLabel(Shorten(entry.templateText, 120), "help", 11, 238, 64))
end

local function RefreshRows(context)
    if type(context) ~= "table" or not context.listGroup then
        return
    end

    context.listGroup:ReleaseChildren()
    if #context.entries == 0 then
        context.listGroup:AddChild(CreateLabel(T("INSERT_TEXT_EMPTY", "No text templates available."), "help", 11, 214, 44))
        return
    end

    for _, entry in ipairs(context.entries) do
        local selected = entry.key == context.selectedTemplateKey
        local button = CreateButton(GetEntryLabel(entry), selected and "primary_action" or "utility", 214)
        button:SetCallback("OnClick", function()
            context.selectedTemplateKey = entry.key
            RefreshRows(context)
            RefreshPreview(context)
            if context.primaryButton then
                context.primaryButton:SetDisabled(false)
            end
        end)
        context.listGroup:AddChild(button)
    end
end

local function RefreshWindow(context)
    if type(context) ~= "table" then
        return
    end
    context.entries = BuildTemplateEntries()
    if not FindEntry(context, context.selectedTemplateKey) then
        context.selectedTemplateKey = FindInitialEntryKey(context.entries, context.initialTemplateName)
            or (context.entries[1] and context.entries[1].key or nil)
    end
    RefreshRows(context)
    RefreshPreview(context)
    if context.primaryButton then
        context.primaryButton:SetDisabled(context.selectedTemplateKey == nil)
    end
end

local function SelectText(unitKey, textKey)
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
        context.dialog:SetStatus(T("INSERT_TEXT_STATUS_SELECT_UNIT", "Select a unit first."))
        return
    end

    local entry = FindEntry(context, context.selectedTemplateKey)
    if type(entry) ~= "table" then
        context.dialog:SetStatus(T("INSERT_TEXT_STATUS_SELECT_TEMPLATE", "Select a text template first."))
        return
    end

    local mutations = ns.TextTemplateMutations or {}
    local mutationContext = mutations.CreateActiveLayoutContext and mutations.CreateActiveLayoutContext(ns.db) or nil
    local materialized = mutations.MaterializeTemplateEntry and mutations.MaterializeTemplateEntry(mutationContext, entry) or nil
    if type(materialized) ~= "table" or not materialized.ok then
        context.dialog:SetStatus(ResolveMutationStatus(materialized))
        return
    end
    local templateName = materialized.templateName

    if context.mode == "change" then
        local textKey = context.targetTextKey
        if type(textKey) ~= "string" or textKey == "" then
            context.dialog:SetStatus(T("INSERT_TEXT_STATUS_SELECT_TEXT", "Select a text object first."))
            return
        end

        if templateName == context.initialTemplateName then
            SelectText(unitKey, textKey)
            context.dialog:Close()
            return
        end

        local result = mutations.AssignTemplate and mutations.AssignTemplate(mutationContext, unitKey, textKey, templateName) or nil
        if type(result) ~= "table" or not result.ok then
            context.dialog:SetStatus(ResolveMutationStatus(result))
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

    local result = mutations.CreateTextFromTemplate and mutations.CreateTextFromTemplate(mutationContext, unitKey, templateName) or nil
    if type(result) ~= "table" or not result.ok then
        context.dialog:SetStatus(ResolveMutationStatus(result))
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

local function OpenTextBuilder()
    if windowContext and windowContext.dialog then
        windowContext.dialog:Close()
    end
    local controller = ns.GUIController or {}
    if controller.OpenTextBuilderWindow then
        controller.OpenTextBuilderWindow()
    end
end

local function BuildFooter(context)
    local footer = context.dialog.footer
    footer:ReleaseChildren()

    local createButton = CreateButton(T("INSERT_TEXT_CREATE_NEW_TEMPLATE", "Create New Template"), "utility", 164)
    createButton:SetCallback("OnClick", OpenTextBuilder)
    footer:AddChild(createButton)

    local footerWidth = context.dialog.contentWidth or 520
    local spacerWidth = math.max(8, footerWidth - 164 - 82 - 82 - 8)
    footer:AddChild(CreateSpacer(spacerWidth, 1))

    local cancelButton = CreateButton(T("INSERT_TEXT_CANCEL", "Cancel"), "utility", 82)
    cancelButton:SetCallback("OnClick", function()
        context.dialog:Close()
    end)
    footer:AddChild(cancelButton)
    footer:AddChild(CreateSpacer(8, 1))

    local addButton = CreateButton(ResolvePrimaryLabel(context), "primary_action", 82)
    addButton:SetCallback("OnClick", function()
        SubmitSelectedTemplate(context)
    end)
    footer:AddChild(addButton)
    context.primaryButton = addButton
end

local function BuildBody(context)
    local body = context.dialog.body
    body:ReleaseChildren()
    body:SetLayout("Flow")

    local listColumn = AceGUI:Create("SimpleGroup")
    listColumn:SetLayout("List")
    listColumn:SetFullWidth(false)
    listColumn:SetWidth(232)
    LockContainerHeight(listColumn, 178)
    listColumn:AddChild(CreateLabel(T("INSERT_TEXT_TEMPLATES", "Templates"), "section_title", 11, 214, 18))
    local listGroup = AceGUI:Create("ScrollFrame")
    listGroup:SetLayout("List")
    listGroup:SetFullWidth(false)
    listGroup:SetWidth(214)
    LockContainerHeight(listGroup, 150)
    context.listGroup = listGroup
    listColumn:AddChild(listGroup)
    body:AddChild(listColumn)

    body:AddChild(CreateSpacer(12, 1))

    local previewColumn = AceGUI:Create("SimpleGroup")
    previewColumn:SetLayout("List")
    previewColumn:SetFullWidth(false)
    previewColumn:SetWidth(250)
    LockContainerHeight(previewColumn, 178)
    previewColumn:AddChild(CreateLabel(T("INSERT_TEXT_PREVIEW", "Preview"), "section_title", 11, 238, 18))
    local previewGroup = AceGUI:Create("SimpleGroup")
    previewGroup:SetLayout("List")
    previewGroup:SetFullWidth(false)
    previewGroup:SetWidth(238)
    LockContainerHeight(previewGroup, 150)
    context.previewGroup = previewGroup
    previewColumn:AddChild(previewGroup)
    body:AddChild(previewColumn)
end

function TextTemplateLibraryWindow.Open(options)
    if windowContext and windowContext.dialog then
        windowContext.dialog:Close()
    end
    options = type(options) == "table" and options or {}
    local mode = options.mode == "change" and "change" or "add"

    local dialog = FormWidgets.CreateCompactFormDialog and FormWidgets.CreateCompactFormDialog({
        title = mode == "change" and T("INSERT_TEXT_CHANGE_TITLE", "Change Text") or T("INSERT_TEXT_TITLE", "Add Text"),
        description = mode == "change" and T("INSERT_TEXT_CHANGE_DESCRIPTION", "Choose a text template for this text object.") or T("INSERT_TEXT_DESCRIPTION", "Choose a text template."),
        width = 548,
        height = 342,
        bodyHeight = 196,
        bodyLayout = "Flow",
        footerHeight = 40,
    }) or nil
    if not dialog then
        return
    end

    local context = {
        dialog = dialog,
        entries = {},
        mode = mode,
        targetUnit = options.unit,
        targetTextKey = options.textKey,
        initialTemplateName = options.initialTemplateName,
        selectedTemplateKey = nil,
    }
    windowContext = context

    BuildBody(context)
    BuildFooter(context)
    RefreshWindow(context)
    dialog:Show()
end

function TextTemplateLibraryWindow.Refresh()
    RefreshWindow(windowContext)
end

function TextTemplateLibraryWindow.Close()
    if windowContext and windowContext.dialog then
        windowContext.dialog:Close()
    end
end

return TextTemplateLibraryWindow
