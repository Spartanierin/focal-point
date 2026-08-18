local _, ns = ...

ns.GUI = ns.GUI or {}
ns.GUI.Pages = ns.GUI.Pages or {}

local AceGUI = LibStub("AceGUI-3.0")
local C = ns.Constants
local KM = ns.KeyMap
local L = ns.L
local FormWidgets = ns.GUI.Helpers and ns.GUI.Helpers.FormWidgets
local FormRenderer = ns.GUI.Helpers and ns.GUI.Helpers.FormRenderer
local TextBuilderLayouts = ns.GUI.Layouts and ns.GUI.Layouts.TextBuilder or {}
local TextBuilderDefinition = TextBuilderLayouts.Form
local TextTemplateMutations = ns.TextTemplateMutations or {}

local TextBuilderController = {}
ns.GUI.Pages.TextBuilder = TextBuilderController

local DEFAULT_TEMPLATE = "[hp:cur:abbr]/[hp:max:abbr] | [hp:perc]%"
local TEMPLATE_EXAMPLE = DEFAULT_TEMPLATE
local UNIT_KEYS = C.UnitOrder or {
    C.Units.PLAYER,
    C.Units.TARGET,
    C.Units.TARGETTARGET,
    C.Units.PET,
    C.Units.FOCUS,
    C.Units.FOCUSTARGET,
    C.Units.BOSS,
}

local fallbackRootState = {}
local windowContext
local deleteDialogContext
local unsavedApplyDialogContext
local unsavedCloseDialogContext
local isPerformingClose = false
local RefreshWindowState
local GetSelectedTemplateEntry
local EnsureWritableProfileContext

local CreateBodyText = FormWidgets.CreateBodyText
local StyleDropdown = FormWidgets.StyleDropdown
local StyleEditBox = FormWidgets.StyleEditBox
local StyleCheckBox = FormWidgets.StyleCheckBox
local ApplyWindowChrome = FormWidgets.ApplyWindowChrome
local EnsureStandardWindowCloseButton = FormWidgets.EnsureStandardWindowCloseButton
local CreateActionButton = FormWidgets.CreateActionButton
local ApplyModalActionButtonVisual = FormWidgets.ApplyModalActionButtonVisual
local ResolveItemColor = FormWidgets.ResolveItemColor
local CenterWindow = FormWidgets.CenterWindow

local function T(key, fallback)
    return (L and L[key]) or fallback or ""
end

local STATUS_COLORS = {
    info = { 0.84, 0.87, 0.92, 1.00 },
    success = { 0.66, 0.90, 0.58, 1.00 },
    warning = { 1.00, 0.82, 0.42, 1.00 },
    error = { 1.00, 0.52, 0.48, 1.00 },
}

local function NormalizeStatusKind(statusKind)
    if statusKind == "success" or statusKind == "warning" or statusKind == "error" then
        return statusKind
    end
    return "info"
end

local function Trim(value)
    if type(value) ~= "string" then
        return ""
    end

    return (value:gsub("^%s+", ""):gsub("%s+$", ""))
end

local function NormalizeTemplateInput(value)
    local normalizer = ns.TextElementTemplates and ns.TextElementTemplates.NormalizeTemplateText
    if type(normalizer) == "function" then
        return normalizer(value)
    end

    return type(value) == "string" and value or ""
end

local function GetCurrentProfileName()
    local library = ns.TextTemplateLibrary
    if library and library.GetCurrentProfileName then
        return library.GetCurrentProfileName(ns.db)
    end

    local db = ns.db
    if db and type(db.GetCurrentProfile) == "function" then
        local ok, profileName = pcall(db.GetCurrentProfile, db)
        if ok and type(profileName) == "string" and profileName ~= "" then
            return profileName
        end
    end

    return nil
end

local function GetActiveProfileTemplates()
    local profileName = GetCurrentProfileName()
    local library = ns.TextTemplateLibrary
    if library and library.GetProfileTemplates then
        return library.GetProfileTemplates(ns.db, profileName), profileName
    end

    local profile = ns.db and ns.db.profile
    local templates = profile and type(profile.TextTemplates) == "table" and profile.TextTemplates or {}
    return templates, profileName
end

local function ListProfileTemplateEntries()
    local library = ns.TextTemplateLibrary
    if library and library.ListProfileTemplateEntries then
        return library.ListProfileTemplateEntries(ns.db)
    end

    local templates, profileName = GetActiveProfileTemplates()
    local entries = {}
    for templateName, templateValue in pairs(templates or {}) do
        if type(templateName) == "string" and type(templateValue) == "string" then
            entries[#entries + 1] = {
                sourceType = "profile",
                sourceId = profileName,
                sourceLabel = profileName,
                profileName = profileName,
                templateName = templateName,
                templateValue = templateValue,
                readOnly = false,
                isActiveProfile = true,
            }
        end
    end
    table.sort(entries, function(left, right)
        return tostring(left.templateName or "") < tostring(right.templateName or "")
    end)
    return entries
end

local function GetProfileTemplateEntry(profileName, templateName)
    local library = ns.TextTemplateLibrary
    if library and library.GetProfileTemplateEntry then
        return library.GetProfileTemplateEntry(ns.db, profileName, templateName)
    end

    local templates = GetActiveProfileTemplates()
    local templateValue = type(templates) == "table" and templates[templateName] or nil
    if type(profileName) ~= "string" or profileName == "" or type(templateName) ~= "string" or templateName == "" or type(templateValue) ~= "string" then
        return nil
    end

    return {
        sourceType = "profile",
        sourceId = profileName,
        profileName = profileName,
        templateName = templateName,
        templateValue = templateValue,
        readOnly = false,
    }
end

local function BuildTemplateEntryKey(entry)
    local library = ns.TextTemplateLibrary
    if library and library.BuildTemplateEntryKey then
        return library.BuildTemplateEntryKey(entry)
    end

    if type(entry) ~= "table" or type(entry.sourceType) ~= "string" or type(entry.sourceId) ~= "string" or type(entry.templateName) ~= "string" then
        return nil
    end

    return table.concat({
        entry.sourceType,
        entry.sourceId,
        entry.profileName or "",
        entry.themeId or "",
        entry.templateName,
    }, "\031")
end

local function ResolveTemplateEntryKey(key)
    local library = ns.TextTemplateLibrary
    if library and library.FindTemplateEntryByKey then
        return library.FindTemplateEntryByKey(ns.db, key)
    end

    return nil
end

local function FormatTemplateEntryLabel(entry)
    if type(entry) ~= "table" then
        return ""
    end

    local profileName = entry.profileName or entry.sourceLabel or entry.sourceId or ""
    if entry.isActiveProfile then
        return string.format("[Current] %s - %s", tostring(profileName), tostring(entry.templateName or ""))
    end

    return string.format("%s - %s", tostring(profileName), tostring(entry.templateName or ""))
end

local function FormatTemplateOwnerText(state)
    local entry = GetSelectedTemplateEntry(state)
    if not entry or entry.sourceType ~= "profile" then
        return " "
    end

    local profileName = entry.profileName or entry.sourceLabel or entry.sourceId or ""
    if profileName == GetCurrentProfileName() then
        return string.format("Profile: %s (Current)", tostring(profileName))
    end

    return string.format("Profile: %s", tostring(profileName))
end

local function BuildTemplateSelection(entry)
    if type(entry) ~= "table"
        or type(entry.sourceType) ~= "string"
        or entry.sourceType == ""
        or type(entry.sourceId) ~= "string"
        or entry.sourceId == ""
        or type(entry.templateName) ~= "string"
        or entry.templateName == ""
    then
        return nil
    end

    local selection = {
        sourceType = entry.sourceType,
        sourceId = entry.sourceId,
        templateName = entry.templateName,
    }

    if type(entry.profileName) == "string" and entry.profileName ~= "" then
        selection.profileName = entry.profileName
    end
    if type(entry.themeId) == "string" and entry.themeId ~= "" then
        selection.themeId = entry.themeId
    end
    if entry.readOnly ~= nil then
        selection.readOnly = entry.readOnly and true or false
    end

    return selection
end

local function ResolveTemplateSelection(selection)
    if type(selection) ~= "table" then
        return nil
    end

    local library = ns.TextTemplateLibrary
    if library and library.FindTemplateEntry then
        return library.FindTemplateEntry(ns.db, selection)
    end

    if selection.sourceType == "profile" then
        return GetProfileTemplateEntry(selection.profileName or selection.sourceId, selection.templateName)
    end

    return nil
end

local function IsSameTemplateSelection(left, right)
    if type(left) ~= "table" or type(right) ~= "table" then
        return false
    end

    return left.sourceType == right.sourceType
        and left.sourceId == right.sourceId
        and left.profileName == right.profileName
        and left.themeId == right.themeId
        and left.templateName == right.templateName
end

local function ResetApplyUnits(state)
    state.applyUnits = {}
    for index, unitKey in ipairs(UNIT_KEYS) do
        state.applyUnits[unitKey] = index == 1
    end
end

local function ClearTemplateSelection(state)
    state.selectedTemplateEntry = nil
    state.selectedTemplate = ""
    state.templateName = ""
    state.template = DEFAULT_TEMPLATE
    state.selectedTemplateProfileName = state.activeProfileName
    ResetApplyUnits(state)
end

local function GetSelectedTemplateKey(state)
    local entry = GetSelectedTemplateEntry(state)
    return entry and BuildTemplateEntryKey(entry) or nil
end

local function CanEditTemplateEntry(entry)
    return type(entry) == "table"
        and entry.sourceType == "profile"
        and entry.profileName == GetCurrentProfileName()
        and not entry.readOnly
end

local function CanEditSelectedTemplate(context)
    return context and CanEditTemplateEntry(GetSelectedTemplateEntry(context.state))
end

local function CanCopySelectedTemplate(context)
    local entry = context and GetSelectedTemplateEntry(context.state) or nil
    return type(entry) == "table"
        and entry.sourceType == "profile"
        and type(entry.profileName) == "string"
        and entry.profileName ~= ""
        and entry.profileName ~= GetCurrentProfileName()
end

local function GetCurrentEditorTemplate(context)
    if not context then
        return ""
    end

    if context.templateEdit and context.templateEdit.GetText then
        return NormalizeTemplateInput(context.templateEdit:GetText() or "")
    end

    return NormalizeTemplateInput(context.state and context.state.template or "")
end

local function GetCurrentEditorTemplateName(context)
    if not context then
        return ""
    end

    if context.templateNameEdit and context.templateNameEdit.GetText then
        return Trim(context.templateNameEdit:GetText() or "")
    end

    return Trim(context.state and context.state.templateName or "")
end

local function GetStoredSelectedTemplateText(context)
    local entry = context and GetSelectedTemplateEntry(context.state) or nil
    if type(entry) ~= "table" or type(entry.templateValue) ~= "string" then
        return nil
    end

    return NormalizeTemplateInput(entry.templateValue)
end

local function IsSelectedTemplateDirty(context)
    local storedTemplate = GetStoredSelectedTemplateText(context)
    if storedTemplate == nil then
        return false
    end

    return GetCurrentEditorTemplate(context) ~= storedTemplate
end

local function GetTemplateNativeEditBox(context)
    return context and context.templateEdit and context.templateEdit.editbox or nil
end

local function ClampCursorPosition(position, text)
    local textLength = type(text) == "string" and #text or 0
    local cursor = tonumber(position)
    if not cursor then
        return nil
    end
    if cursor < 0 then
        return 0
    end
    if cursor > textLength then
        return textLength
    end
    return cursor
end

local function CaptureTemplateCursor(context)
    local editBox = GetTemplateNativeEditBox(context)
    if not editBox or not editBox.GetCursorPosition then
        return nil
    end

    local draft = editBox.GetText and editBox:GetText() or (context.templateEdit and context.templateEdit.GetText and context.templateEdit:GetText()) or ""
    local cursor = ClampCursorPosition(editBox:GetCursorPosition(), draft)
    if cursor ~= nil then
        context.lastTemplateCursorPosition = cursor
    end
    return cursor
end

local function ResolvePrimarySaveMode(context)
    local entry = context and GetSelectedTemplateEntry(context.state) or nil
    if not entry then
        return "create"
    end

    if CanEditTemplateEntry(entry) then
        return "update"
    end

    return "readOnly"
end

local function SetButtonText(button, text)
    if button and button.SetText then
        button:SetText(text or "")
    end
end

local function SetTemplateSelection(state, entry)
    if type(state) ~= "table" or type(entry) ~= "table" then
        return false
    end

    local selection = BuildTemplateSelection(entry)
    if not selection then
        ClearTemplateSelection(state)
        return false
    end

    state.selectedTemplateEntry = selection
    state.selectedTemplate = entry.templateName
    state.selectedTemplateProfileName = entry.profileName or state.activeProfileName
    state.templateName = entry.templateName
    state.template = NormalizeTemplateInput(entry.templateValue)
    return true
end

local function SetTemplateSelectionIdentity(state, entry)
    if type(state) ~= "table" or type(entry) ~= "table" then
        return false
    end

    local selection = BuildTemplateSelection(entry)
    if not selection then
        ClearTemplateSelection(state)
        return false
    end

    state.selectedTemplateEntry = selection
    state.selectedTemplate = entry.templateName
    state.selectedTemplateProfileName = entry.profileName or state.activeProfileName
    return true
end

GetSelectedTemplateEntry = function(state)
    if type(state) ~= "table" then
        return nil
    end

    local entry = ResolveTemplateSelection(state.selectedTemplateEntry)
    if entry then
        return entry
    end

    if type(state.selectedTemplate) == "string" and state.selectedTemplate ~= "" then
        return GetProfileTemplateEntry(state.selectedTemplateProfileName or state.activeProfileName, state.selectedTemplate)
    end

    return nil
end

local function GetSelectedTemplateName(state)
    local entry = GetSelectedTemplateEntry(state)
    if entry and type(entry.templateName) == "string" then
        return entry.templateName
    end

    return type(state) == "table" and state.selectedTemplate or ""
end

local function ReconcileTextBuilderProfileContext(state)
    if type(state) ~= "table" then
        return false
    end

    local currentProfileName = GetCurrentProfileName()
    if type(currentProfileName) ~= "string" or currentProfileName == "" then
        currentProfileName = nil
    end

    local previousProfileName = state.activeProfileName
    local previousEntry = GetSelectedTemplateEntry(state)
    local profileChanged = previousProfileName ~= nil and previousProfileName ~= currentProfileName

    if previousProfileName == nil then
        state.activeProfileName = currentProfileName
        if state.selectedTemplateProfileName == nil then
            state.selectedTemplateProfileName = currentProfileName
        end
        if previousEntry then
            SetTemplateSelection(state, previousEntry)
        end
        return false
    end

    if not profileChanged then
        if previousEntry then
            SetTemplateSelectionIdentity(state, previousEntry)
        elseif type(state.selectedTemplateEntry) == "table" or (type(state.selectedTemplate) == "string" and state.selectedTemplate ~= "") then
            ClearTemplateSelection(state)
        end
        return false
    end

    state.activeProfileName = currentProfileName
    state._profileContextChanged = true

    if previousEntry then
        SetTemplateSelection(state, previousEntry)
        ResetApplyUnits(state)
        return true
    end

    ClearTemplateSelection(state)
    return true
end

local function GetTextBuilderState(deps)
    local rootState = (deps and deps.GetGUIState and deps.GetGUIState()) or fallbackRootState
    rootState.textBuilder = rootState.textBuilder or {}

    local state = rootState.textBuilder
    if type(state.template) ~= "string" or state.template == "" then
        state.template = DEFAULT_TEMPLATE
    end
    if type(state.templateName) ~= "string" then
        state.templateName = ""
    end
    if type(state.selectedTemplate) ~= "string" then
        state.selectedTemplate = ""
    end
    if type(state.selectedTemplateEntry) ~= "table" and state.selectedTemplate ~= "" then
        state.selectedTemplateEntry = BuildTemplateSelection({
            sourceType = "profile",
            sourceId = state.selectedTemplateProfileName or state.activeProfileName or GetCurrentProfileName() or "",
            profileName = state.selectedTemplateProfileName or state.activeProfileName or GetCurrentProfileName(),
            templateName = state.selectedTemplate,
        })
    end
    if type(state.activeProfileName) ~= "string" then
        state.activeProfileName = GetCurrentProfileName()
    end
    if type(state.selectedTemplateProfileName) ~= "string" then
        state.selectedTemplateProfileName = state.activeProfileName
    end

    state.applyUnits = state.applyUnits or {}
    for index, unitKey in ipairs(UNIT_KEYS) do
        if state.applyUnits[unitKey] == nil then
            state.applyUnits[unitKey] = index == 1
        end
    end

    ReconcileTextBuilderProfileContext(state)
    return state
end

local function ApplyStatusVisual(statusWidget, statusKind)
    local color = STATUS_COLORS[NormalizeStatusKind(statusKind)] or STATUS_COLORS.info
    local label = statusWidget and statusWidget.label
    if label and label.SetTextColor then
        label:SetTextColor(color[1], color[2], color[3], color[4])
    end
    if label and label.SetJustifyH then
        label:SetJustifyH("LEFT")
    end
end

local function SetStatus(message, statusKind)
    if ns.GUI and ns.GUI.SetStatusText then
        ns.GUI:SetStatusText(message)
    end
    if windowContext and windowContext.libraryHint and windowContext.libraryHint.SetText then
        ApplyStatusVisual(windowContext.libraryHint, statusKind)
        windowContext.libraryHint:SetText(message or "")
    end
end

local function RefreshToolUI()
    if ns.GUI and ns.GUI.RequestRefreshOptions then
        ns.GUI:RequestRefreshOptions()
    end
end

local function GetTemplates()
    return GetActiveProfileTemplates()
end

local function FormatMutationError(result)
    local errorCode = type(result) == "table" and result.errorCode or "unknown"
    if errorCode == "invalid_template_name" then
        return T("INFO_TEXT_BUILDER_STATUS_NAME_REQUIRED")
    elseif errorCode == "invalid_template_text" then
        return T("INFO_TEXT_BUILDER_STATUS_TEMPLATE_TEXT_INVALID")
    elseif errorCode == "template_name_exists" then
        return T("INFO_TEXT_BUILDER_STATUS_NAME_EXISTS")
    elseif errorCode == "template_not_found" then
        return T("INFO_TEXT_BUILDER_STATUS_SELECT_TEMPLATE")
    elseif errorCode == "invalid_context" then
        return T("INFO_TEXT_BUILDER_STATUS_CONTEXT_INVALID")
    elseif errorCode == "template_in_use" then
        return T("INFO_TEXT_BUILDER_STATUS_TEMPLATE_IN_USE")
    elseif errorCode == "unit_not_found" then
        return T("INFO_TEXT_BUILDER_STATUS_UNIT_NOT_FOUND")
    elseif errorCode == "text_element_not_found" then
        return T("INFO_TEXT_BUILDER_STATUS_TEXT_ELEMENT_NOT_FOUND")
    end

    return T("INFO_TEXT_BUILDER_STATUS_OPERATION_FAILED")
end

local function FocusWindow(window)
    FormWidgets.FocusWindow(window, { centerIfHidden = true })
end

local function IsTextBuilderWindowShown(context)
    local frame = context and context.window and context.window.frame or nil
    return frame and frame.IsShown and frame:IsShown() or false
end

local function ResolveItemText(item)
    if not item then
        return ""
    end

    if item.builder == "templateExample" then
        return (T("INFO_TEXT_BUILDER_TEMPLATE_EXAMPLE") .. " " .. TEMPLATE_EXAMPLE)
    end

    if item.textKey then
        return T(item.textKey)
    end

    return item.text or ""
end

local function CreateItemWidget(group, item, props, state)
    if not props or not props.widget then
        return nil
    end

    if props.widget == "label" or props.widget == "computed_label" then
        local text = ResolveItemText(props)
        if props.stateKey and state and state[props.stateKey] ~= nil then
            text = state[props.stateKey]
        end
        local label = CreateBodyText(
            text,
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

    if props.widget == "dropdown" then
        local dropdown = AceGUI:Create("Dropdown")
        if props.label ~= nil then
            dropdown:SetLabel(props.label)
        else
            dropdown:SetLabel(T(props.labelKey))
        end
        if props.fullWidth ~= false then
            dropdown:SetFullWidth(true)
        end
        StyleDropdown(dropdown, props.fieldVariant or "accented")
        return dropdown
    end

    if props.widget == "editbox" then
        local editBox = AceGUI:Create("EditBox")
        editBox:SetLabel(T(props.labelKey))
        if props.fullWidth ~= false then
            editBox:SetFullWidth(true)
        end
        if props.disableButton then
            editBox:DisableButton(true)
        end
        local text = props.stateKey and state and state[props.stateKey] or props.text or ""
        if props.normalize == "template" then
            text = NormalizeTemplateInput(text)
        end
        editBox:SetText(text)
        StyleEditBox(editBox, props.fieldVariant)
        return editBox
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
        checkbox:SetLabel(ns.GetLabel and ns.GetLabel(KM.Units, props.unitKey) or props.unitKey or "")
        checkbox:SetValue(props.checked and true or false)
        checkbox:SetDisabled(props.disabled and true or false)
        StyleCheckBox(checkbox, props.disabled and true or false)
        return checkbox
    end

    return nil
end

local function SyncEditBoxText(context, widget, value, flagName)
    if not context or not widget then
        return
    end

    local targetValue = value or ""
    if widget.GetText and widget:GetText() == targetValue then
        return
    end

    context[flagName] = true
    widget:SetText(targetValue)
    context[flagName] = false
end

local function ApplyDialogState(context, state)
    if not context or type(state) ~= "table" then
        return
    end

    if context.widgets then
        for widgetId, widget in pairs(context.widgets) do
            local value = state[widgetId]
            if value ~= nil and widget and widget.SetText then
                widget:SetText(value)
            end
        end
    end
end

local function EnableDialogEscapeClose(window)
    local frame = window and window.frame
    if not frame then
        return
    end

    if frame.EnableKeyboard then
        frame:EnableKeyboard(true)
    end
    if frame.SetScript then
        frame:SetScript("OnKeyDown", function(_, key)
            if key == "ESCAPE" and window.Hide then
                window:Hide()
            end
        end)
    end
end

local function OpenTextBuilderLayoutDialog(existingContext, layoutDefinition, options)
    options = options or {}

    if existingContext and existingContext.window and existingContext.window.frame then
        existingContext.window:SetTitle(options.title or "")
        existingContext.window:SetWidth(options.windowWidth or 420)
        existingContext.window:SetHeight(options.windowHeight or 210)
        existingContext.window:SetCallback("OnClose", nil)
        ApplyDialogState(existingContext, options.state)
        EnableDialogEscapeClose(existingContext.window)
        FocusWindow(existingContext.window)
        return existingContext
    end

    local window = AceGUI:Create("Window")
    window:SetTitle(options.title or "")
    window:SetLayout("Fill")
    window:SetWidth(options.windowWidth or 420)
    window:SetHeight(options.windowHeight or 210)
    window:EnableResize(false)

    if window.frame then
        window.frame:SetClampedToScreen(true)
    end

    ApplyWindowChrome(window)
    if EnsureStandardWindowCloseButton then
        EnsureStandardWindowCloseButton(window)
    end
    EnableDialogEscapeClose(window)
    CenterWindow(window)

    local groups, widgets = FormRenderer.BuildLayout(window, layoutDefinition, {
        state = options.state or {},
        createItemWidget = CreateItemWidget,
    })

    local context = {
        window = window,
        groups = groups,
        widgets = widgets,
        deleteConfirmButton = widgets.deleteConfirmButton,
        saveApplyButton = widgets.saveApplyButton,
        applyStoredButton = widgets.applyStoredButton,
        saveCloseButton = widgets.saveCloseButton,
        discardCloseButton = widgets.discardCloseButton,
        cancelButton = widgets.cancelButton,
    }

    FocusWindow(window)
    return context
end

local function GetTemplateUsageCounts(templateName, profileName)
    local usage = {}
    for _, unitKey in ipairs(UNIT_KEYS) do
        usage[unitKey] = 0
    end

    if type(templateName) ~= "string" or templateName == "" then
        return usage
    end

    local usageApi = ns.TextTemplateUsage
    if not usageApi or not usageApi.CreateProfileContext or not usageApi.GetTemplateUsage then
        return usage
    end
    local library = ns.TextTemplateLibrary
    local profile = library and library.GetProfileByName and library.GetProfileByName(ns.db, profileName) or nil
    if type(profile) ~= "table" then
        return usage
    end

    local usageResult = usageApi.GetTemplateUsage(usageApi.CreateProfileContext(profile, profileName), templateName)
    local countedTextElements = {}
    for _, entry in ipairs(type(usageResult) == "table" and usageResult.references or {}) do
        if entry.templateName == templateName and usage[entry.unitKey] ~= nil then
            local textKey = tostring(entry.unitKey or "") .. "\001" .. tostring(entry.textKey or "")
            if not countedTextElements[textKey] then
                usage[entry.unitKey] = usage[entry.unitKey] + 1
                countedTextElements[textKey] = true
            end
        end
    end

    return usage
end

local function SyncDesiredTemplateUsage(context)
    local selectedEntry = GetSelectedTemplateEntry(context.state)
    local selectedTemplateName = selectedEntry and selectedEntry.templateName or ""
    local usageCounts = GetTemplateUsageCounts(selectedTemplateName, selectedEntry and selectedEntry.profileName or nil)

    context.state.applyUnits = context.state.applyUnits or {}
    for _, unitKey in ipairs(UNIT_KEYS) do
        context.state.applyUnits[unitKey] = (usageCounts[unitKey] or 0) > 0
    end
end

local function BuildMutationContext()
    return TextTemplateMutations.CreateProfileContext and TextTemplateMutations.CreateProfileContext(ns.db and ns.db.profile) or {}
end

local function RefreshPreview(context)
    local template = NormalizeTemplateInput(context.state.template or context.templateEdit:GetText() or "")
    local previewText = ""

    if ns.UnitFrame and ns.UnitFrame.BuildTemplatePreview then
        previewText = ns.UnitFrame:BuildTemplatePreview(template)
    end

    if previewText == "" then
        previewText = template
    end

    context.previewValue:SetText(previewText ~= "" and previewText or " ")
end

local function RefreshTemplateUsageState(context)
    local selectedEntry = GetSelectedTemplateEntry(context.state)
    local selectedTemplateName = selectedEntry and selectedEntry.templateName or ""
    local canEdit = CanEditSelectedTemplate(context)
    local usageCounts = GetTemplateUsageCounts(selectedTemplateName, selectedEntry and selectedEntry.profileName or nil)

    for unitKey, checkbox in pairs(context.usageCheckboxes or {}) do
        local count = usageCounts[unitKey] or 0
        local label = ns.GetLabel and ns.GetLabel(KM.Units, unitKey) or unitKey
        if count > 0 then
            label = string.format("%s (%d)", label, count)
        end

        checkbox:SetLabel(label)
        checkbox:SetValue(context.state.applyUnits and context.state.applyUnits[unitKey] == true)
        checkbox:SetDisabled(selectedTemplateName == "" or not canEdit)
        StyleCheckBox(checkbox, selectedTemplateName == "" or not canEdit)
    end
end

local function SyncTemplateSelectWidget(context)
    local list = {}
    local order = {}
    for _, entry in ipairs(ListProfileTemplateEntries()) do
        local key = BuildTemplateEntryKey(entry)
        if key then
            list[key] = FormatTemplateEntryLabel(entry)
            order[#order + 1] = key
        end
    end

    context.templateSelect:SetList(list, order)
    context.suspendTemplateSelectCallbacks = true
    context.templateSelect:SetValue(GetSelectedTemplateKey(context.state))
    context.suspendTemplateSelectCallbacks = false
end

local function RefreshTemplateDropdown(context)
    SyncTemplateSelectWidget(context)
    SyncDesiredTemplateUsage(context)
    RefreshTemplateUsageState(context)
end

local function RefreshEditorInteractionPreview()
    if ns.RefreshEditorInteractionVisuals then
        ns:RefreshEditorInteractionVisuals()
    end
end

local function OpenDeleteTemplateConfirmDialog(templateName)
    if type(templateName) ~= "string" or templateName == "" then
        SetStatus(T("INFO_TEXT_BUILDER_STATUS_SELECT_TEMPLATE"), "warning")
        return
    end

    local confirmedTemplateName = templateName
    deleteDialogContext = OpenTextBuilderLayoutDialog(deleteDialogContext, TextBuilderLayouts.DeleteConfirm, {
        title = T("INFO_TEXT_BUILDER_DELETE_CONFIRM_TITLE"),
        windowWidth = 420,
        windowHeight = 210,
        state = {
            message = string.format(T("INFO_TEXT_BUILDER_DELETE_CONFIRM_PROMPT"), confirmedTemplateName),
        },
    })

    if deleteDialogContext and deleteDialogContext.deleteConfirmButton then
        deleteDialogContext.deleteConfirmButton:SetDisabled(false)
        deleteDialogContext.deleteConfirmButton:SetCallback("OnClick", function(widget)
            if widget and widget.SetDisabled then
                widget:SetDisabled(true)
            end
            if deleteDialogContext.window and deleteDialogContext.window.Hide then
                deleteDialogContext.window:Hide()
            end

            local templates = GetTemplates()
            if type(templates[confirmedTemplateName]) ~= "string" then
                SetStatus(FormatMutationError({ errorCode = "template_not_found", templateName = confirmedTemplateName }), "error")
                return
            end

            local result = TextTemplateMutations.DeleteTemplate and TextTemplateMutations.DeleteTemplate(BuildMutationContext(), confirmedTemplateName)
            if type(result) ~= "table" or not result.ok then
                SetStatus(FormatMutationError(result), "error")
                return
            end

            if windowContext then
                ClearTemplateSelection(windowContext.state)
                RefreshTemplateDropdown(windowContext)
                RefreshWindowState()
            end
            RefreshEditorInteractionPreview()
            SetStatus((T("INFO_TEXT_BUILDER_STATUS_DELETED")) .. " " .. confirmedTemplateName, "success")
        end)
    end

    if deleteDialogContext and deleteDialogContext.cancelButton then
        deleteDialogContext.cancelButton:SetCallback("OnClick", function()
            if deleteDialogContext.window and deleteDialogContext.window.Hide then
                deleteDialogContext.window:Hide()
            end
        end)
    end
end

local function ApplyTemplateToTextElement(context, options)
    options = type(options) == "table" and options or {}
    local optionRefresh = ns.GUI and ns.GUI.Helpers and ns.GUI.Helpers.OptionRefresh
    if not TextTemplateMutations or not TextTemplateMutations.ApplyTemplateToUnits then
        return
    end

    local templates = GetTemplates()
    local selectedEntry = GetSelectedTemplateEntry(context.state)
    local selectedTemplateName = selectedEntry and selectedEntry.templateName or ""
    local template = options.useStoredTemplate and NormalizeTemplateInput(selectedEntry and selectedEntry.templateValue or templates[selectedTemplateName] or "")
        or NormalizeTemplateInput(context.templateEdit:GetText() or "")
    local linkedTemplateName = ""
    local unitsToAdd = {}
    local unitsToRemove = {}
    local usageCounts = GetTemplateUsageCounts(selectedTemplateName, selectedEntry and selectedEntry.profileName or nil)

    if options.useStoredTemplate and type(templates[selectedTemplateName]) == "string" then
        linkedTemplateName = selectedTemplateName
    elseif type(templates[selectedTemplateName]) == "string" and templates[selectedTemplateName] == template then
        linkedTemplateName = selectedTemplateName
    else
        local currentName = context.state.templateName or ""
        if type(templates[currentName]) == "string" and templates[currentName] == template then
            linkedTemplateName = currentName
        end
    end

    for _, unitKey in ipairs(UNIT_KEYS) do
        local wantsLinked = context.state.applyUnits and context.state.applyUnits[unitKey] == true
        local isLinked = (usageCounts[unitKey] or 0) > 0

        if wantsLinked and not isLinked then
            unitsToAdd[#unitsToAdd + 1] = unitKey
        elseif (not wantsLinked) and isLinked then
            unitsToRemove[#unitsToRemove + 1] = unitKey
        end
    end

    if #unitsToAdd == 0 and #unitsToRemove == 0 then
        SetStatus(T("INFO_TEXT_BUILDER_STATUS_SELECT_UNIT"), "warning")
        return
    end

    local result = TextTemplateMutations.ApplyTemplateToUnits(BuildMutationContext(), {
        selectedTemplateName = selectedTemplateName,
        linkedTemplateName = linkedTemplateName,
        templateText = template,
        unitsToAdd = unitsToAdd,
        unitsToRemove = unitsToRemove,
    })
    if type(result) ~= "table" or not result.ok then
        SetStatus(FormatMutationError(result), "error")
        return
    end

    local appliedEntries = {}
    for _, unitKey in ipairs(result.appliedUnits or {}) do
        appliedEntries[#appliedEntries + 1] = ns.GetLabel and ns.GetLabel(KM.Units, unitKey) or unitKey
    end

    local removedEntries = {}
    for _, unitKey in ipairs(result.removedUnits or {}) do
        removedEntries[#removedEntries + 1] = ns.GetLabel and ns.GetLabel(KM.Units, unitKey) or unitKey
    end

    if optionRefresh and optionRefresh.Live then
        optionRefresh.Live()
    end

    RefreshEditorInteractionPreview()
    RefreshToolUI()

    local statusParts = {}
    if #appliedEntries > 0 then
        statusParts[#statusParts + 1] = (T("INFO_TEXT_BUILDER_STATUS_APPLIED_TO") .. ": " .. table.concat(appliedEntries, ", "))
    end
    if #removedEntries > 0 then
        statusParts[#statusParts + 1] = (T("INFO_TEXT_BUILDER_TEMPLATE_USAGE_UNLINKED") .. ": " .. table.concat(removedEntries, ", "))
    end

    local statusText = table.concat(statusParts, " | ")
    if linkedTemplateName ~= "" and statusText ~= "" then
        statusText = statusText .. " (" .. linkedTemplateName .. ")"
    end
    if statusText == "" then
        statusText = T("INFO_TEXT_BUILDER_STATUS_SELECT_UNIT")
    end

    SetStatus(statusText, statusText == T("INFO_TEXT_BUILDER_STATUS_SELECT_UNIT") and "warning" or "success")
    SyncDesiredTemplateUsage(context)
    RefreshTemplateUsageState(context)
end

local function SaveCurrentTemplate(context)
    if not EnsureWritableProfileContext(context) then
        return false
    end

    local name = Trim(context.templateNameEdit:GetText() or "")
    local template = NormalizeTemplateInput(context.templateEdit:GetText() or "")
    local mode = ResolvePrimarySaveMode(context)

    if name == "" then
        SetStatus(T("INFO_TEXT_BUILDER_STATUS_NAME_REQUIRED"), "error")
        return false
    end
    if Trim(template) == "" then
        SetStatus(FormatMutationError({ errorCode = "invalid_template_text" }), "error")
        return false
    end

    if mode == "create" then
        local result = TextTemplateMutations.CreateTemplate and TextTemplateMutations.CreateTemplate(BuildMutationContext(), name, template)
        if type(result) ~= "table" or not result.ok then
            SetStatus(FormatMutationError(result), "error")
            return false
        end

        SetTemplateSelection(context.state, GetProfileTemplateEntry(context.state.activeProfileName, name) or {
            sourceType = "profile",
            sourceId = context.state.activeProfileName,
            profileName = context.state.activeProfileName,
            templateName = name,
            templateValue = template,
        })
        RefreshTemplateDropdown(context)
        RefreshWindowState()
        RefreshEditorInteractionPreview()
        SetStatus((T("INFO_TEXT_BUILDER_STATUS_SAVED")) .. " " .. name, "success")
        return true
    end

    if mode ~= "update" then
        RefreshWindowState()
        SetStatus(T("INFO_TEXT_BUILDER_STATUS_COPY_TO_CURRENT_FIRST"), "warning")
        return false
    end

    local selectedEntry = GetSelectedTemplateEntry(context.state)
    if not CanEditTemplateEntry(selectedEntry) then
        RefreshWindowState()
        SetStatus(T("INFO_TEXT_BUILDER_STATUS_SELECT_TEMPLATE"), "warning")
        return false
    end
    if not IsSelectedTemplateDirty(context) then
        RefreshWindowState()
        SetStatus(T("INFO_TEXT_BUILDER_STATUS_NO_CHANGES"), "warning")
        return false
    end

    local selectedName = selectedEntry.templateName
    local updateResult = TextTemplateMutations.UpdateTemplate and TextTemplateMutations.UpdateTemplate(BuildMutationContext(), selectedName, template)
    if type(updateResult) ~= "table" or not updateResult.ok then
        SetStatus(FormatMutationError(updateResult), "error")
        return false
    end

    SetTemplateSelection(context.state, GetProfileTemplateEntry(context.state.activeProfileName, selectedName) or {
        sourceType = "profile",
        sourceId = context.state.activeProfileName,
        profileName = context.state.activeProfileName,
        templateName = selectedName,
        templateValue = template,
    })
    RefreshTemplateDropdown(context)
    RefreshWindowState()
    RefreshEditorInteractionPreview()
    SetStatus((T("INFO_TEXT_BUILDER_STATUS_UPDATED")) .. " " .. selectedName, "success")
    return true
end

function EnsureWritableProfileContext(context)
    if not context or type(context.state) ~= "table" then
        return false
    end

    if ReconcileTextBuilderProfileContext(context.state) then
        if RefreshWindowState then
            RefreshWindowState()
        end
        return false
    end

    return context.state.activeProfileName == GetCurrentProfileName()
end

local function ResolveWritableProfileSelection(context)
    if not EnsureWritableProfileContext(context) then
        return nil
    end

    local entry = GetSelectedTemplateEntry(context.state)
    local currentProfileName = GetCurrentProfileName()
    if not entry
        or entry.sourceType ~= "profile"
        or entry.profileName ~= currentProfileName
        or entry.readOnly
    then
        ClearTemplateSelection(context.state)
        if RefreshWindowState then
            RefreshWindowState()
        end
        return nil
    end

    SetTemplateSelection(context.state, entry)
    return entry
end

local function ResolveApplyTemplateSelection(context)
    if not EnsureWritableProfileContext(context) then
        return nil
    end

    local entry = GetSelectedTemplateEntry(context.state)
    local currentProfileName = GetCurrentProfileName()
    if not entry
        or entry.sourceType ~= "profile"
        or entry.profileName ~= currentProfileName
        or entry.readOnly
    then
        ClearTemplateSelection(context.state)
        if RefreshWindowState then
            RefreshWindowState()
        end
        return nil
    end

    return entry
end

local function OpenUnsavedApplyConfirmDialog(context)
    if not context then
        return
    end

    unsavedApplyDialogContext = OpenTextBuilderLayoutDialog(unsavedApplyDialogContext, TextBuilderLayouts.UnsavedApplyConfirm, {
        title = T("INFO_TEXT_BUILDER_UNSAVED_APPLY_TITLE"),
        windowWidth = 560,
        windowHeight = 230,
    })

    if unsavedApplyDialogContext and unsavedApplyDialogContext.saveApplyButton then
        unsavedApplyDialogContext.saveApplyButton:SetDisabled(false)
        unsavedApplyDialogContext.saveApplyButton:SetCallback("OnClick", function(widget)
            if widget and widget.SetDisabled then
                widget:SetDisabled(true)
            end

            if SaveCurrentTemplate(context) then
                if unsavedApplyDialogContext.window and unsavedApplyDialogContext.window.Hide then
                    unsavedApplyDialogContext.window:Hide()
                end
                ApplyTemplateToTextElement(context)
            elseif widget and widget.SetDisabled then
                widget:SetDisabled(false)
            end
        end)
    end

    if unsavedApplyDialogContext and unsavedApplyDialogContext.applyStoredButton then
        unsavedApplyDialogContext.applyStoredButton:SetDisabled(false)
        unsavedApplyDialogContext.applyStoredButton:SetCallback("OnClick", function()
            if unsavedApplyDialogContext.window and unsavedApplyDialogContext.window.Hide then
                unsavedApplyDialogContext.window:Hide()
            end
            ApplyTemplateToTextElement(context, { useStoredTemplate = true })
        end)
    end

    if unsavedApplyDialogContext and unsavedApplyDialogContext.cancelButton then
        unsavedApplyDialogContext.cancelButton:SetCallback("OnClick", function()
            if unsavedApplyDialogContext.window and unsavedApplyDialogContext.window.Hide then
                unsavedApplyDialogContext.window:Hide()
            end
        end)
    end
end

local function CloseOwnedTagLibrary()
    local tagLibraryPage = ns.GUI and ns.GUI.Pages and ns.GUI.Pages.TagLibrary
    if tagLibraryPage and tagLibraryPage.Close then
        tagLibraryPage.Close()
    end
end

local function HideOwnedChildDialogs()
    if deleteDialogContext and deleteDialogContext.window and deleteDialogContext.window.Hide then
        deleteDialogContext.window:Hide()
    end
    if unsavedApplyDialogContext and unsavedApplyDialogContext.window and unsavedApplyDialogContext.window.Hide then
        unsavedApplyDialogContext.window:Hide()
    end
    if unsavedCloseDialogContext and unsavedCloseDialogContext.window and unsavedCloseDialogContext.window.Hide then
        unsavedCloseDialogContext.window:Hide()
    end
end

local function PerformClose(context)
    context = context or windowContext
    if not context or not context.window then
        return
    end

    HideOwnedChildDialogs()
    CloseOwnedTagLibrary()
    if ns.GUI and ns.GUI.ResetStatusText then
        ns.GUI:ResetStatusText()
    end

    isPerformingClose = true
    if context.window.Hide then
        context.window:Hide()
    elseif context.window.frame and context.window.frame.Hide then
        context.window.frame:Hide()
    end
    isPerformingClose = false
end

local function OpenUnsavedCloseConfirmDialog(context)
    if not context then
        return
    end

    unsavedCloseDialogContext = OpenTextBuilderLayoutDialog(unsavedCloseDialogContext, TextBuilderLayouts.UnsavedCloseConfirm, {
        title = T("INFO_TEXT_BUILDER_UNSAVED_CLOSE_TITLE"),
        windowWidth = 560,
        windowHeight = 230,
    })

    if unsavedCloseDialogContext and unsavedCloseDialogContext.saveCloseButton then
        unsavedCloseDialogContext.saveCloseButton:SetDisabled(false)
        unsavedCloseDialogContext.saveCloseButton:SetCallback("OnClick", function(widget)
            if widget and widget.SetDisabled then
                widget:SetDisabled(true)
            end

            if SaveCurrentTemplate(context) then
                PerformClose(context)
            elseif widget and widget.SetDisabled then
                widget:SetDisabled(false)
            end
        end)
    end

    if unsavedCloseDialogContext and unsavedCloseDialogContext.discardCloseButton then
        unsavedCloseDialogContext.discardCloseButton:SetDisabled(false)
        unsavedCloseDialogContext.discardCloseButton:SetCallback("OnClick", function()
            PerformClose(context)
        end)
    end

    if unsavedCloseDialogContext and unsavedCloseDialogContext.cancelButton then
        unsavedCloseDialogContext.cancelButton:SetCallback("OnClick", function()
            if unsavedCloseDialogContext.window and unsavedCloseDialogContext.window.Hide then
                unsavedCloseDialogContext.window:Hide()
            end
        end)
    end
end

local function RequestClose(context)
    context = context or windowContext
    if not context then
        return
    end
    if IsSelectedTemplateDirty(context) then
        OpenUnsavedCloseConfirmDialog(context)
        return
    end
    PerformClose(context)
end

RefreshWindowState = function()
    local context = windowContext
    if not context then
        return
    end
    local profileContextChanged = ReconcileTextBuilderProfileContext(context.state)

    local function ApplyTextBuilderButtonVisuals()
        if not ApplyModalActionButtonVisual then
            return
        end

        ApplyModalActionButtonVisual(context.updateButton, "utility")
        ApplyModalActionButtonVisual(context.tagDatabaseButton, "utility")
        ApplyModalActionButtonVisual(context.newTemplateButton, "utility")
        ApplyModalActionButtonVisual(context.saveButton, "primary_action")
        ApplyModalActionButtonVisual(context.copyTemplateButton, "utility")
        ApplyModalActionButtonVisual(context.updateTemplateButton, "utility")
        ApplyModalActionButtonVisual(context.deleteTemplateButton, "danger")
        ApplyModalActionButtonVisual(context.applyTemplateButton, "primary_action")
    end

    local hasDB = ns.db and ns.db.profile
    if not hasDB then
        context.templateEdit:SetDisabled(true)
        context.updateButton:SetDisabled(true)
        context.previewValue:SetText(T("INFO_COMMON_UNAVAILABLE"))
        context.templateSelect:SetList({})
        context.templateSelect:SetDisabled(true)
        context.templateNameEdit:SetDisabled(true)
        context.newTemplateButton:SetDisabled(true)
        context.deleteTemplateButton:SetDisabled(true)
        context.saveButton:SetDisabled(true)
        context.copyTemplateButton:SetDisabled(true)
        context.updateTemplateButton:SetDisabled(true)
        context.applyTemplateButton:SetDisabled(true)
        ApplyTextBuilderButtonVisuals()
        SetStatus(T("INFO_COMMON_UNAVAILABLE"), "error")
        if context.usageHint then
            context.usageHint:SetText(T("INFO_COMMON_UNAVAILABLE"))
        end
        for _, checkbox in pairs(context.usageCheckboxes or {}) do
            checkbox:SetDisabled(true)
            checkbox:SetValue(false)
            StyleCheckBox(checkbox, true)
        end
        if context.window and context.window.DoLayout then
            context.window:DoLayout()
        end
        return
    end

    context.state.template = NormalizeTemplateInput(context.state.template or context.templateEdit:GetText() or "")
    context.templateEdit:SetDisabled(false)
    SyncEditBoxText(context, context.templateEdit, context.state.template, "suspendTemplateEditCallbacks")
    context.updateButton:SetDisabled(false)

    context.templateSelect:SetDisabled(false)
    context.templateNameEdit:SetDisabled(false)
    SyncEditBoxText(context, context.templateNameEdit, context.state.templateName or "", "suspendTemplateNameCallbacks")

    SetStatus(T("INFO_TEXT_BUILDER_LIBRARY_HINT_SHORT"), "info")
    if context.usageHint then
        context.usageHint:SetText(T("INFO_TEXT_BUILDER_TEMPLATE_USAGE_HINT_SHORT"))
    end

    local hasSelectedTemplate = type(context.state.selectedTemplate) == "string" and context.state.selectedTemplate ~= ""
    local hasTemplateName = Trim(context.templateNameEdit:GetText() or "") ~= ""
    local hasTemplateText = Trim(context.templateEdit:GetText() or "") ~= ""
    local canEditSelectedTemplate = CanEditSelectedTemplate(context)
    local canCopySelectedTemplate = CanCopySelectedTemplate(context)
    local saveMode = ResolvePrimarySaveMode(context)
    local selectedEntry = GetSelectedTemplateEntry(context.state)
    local selectedName = selectedEntry and selectedEntry.templateName or ""
    local currentName = GetCurrentEditorTemplateName(context)
    local isDirty = IsSelectedTemplateDirty(context)
    local isRenameCandidate = canEditSelectedTemplate and currentName ~= "" and selectedName ~= "" and currentName ~= selectedName

    SyncTemplateSelectWidget(context)
    if profileContextChanged or context.state._profileContextChanged then
        SyncDesiredTemplateUsage(context)
        context.state._profileContextChanged = nil
    end

    if context.templateOwnerLabel then
        context.templateOwnerLabel:SetText(FormatTemplateOwnerText(context.state))
    end

    SetButtonText(context.saveButton, saveMode == "update" and T("INFO_TEXT_BUILDER_SAVE_CHANGES") or T("INFO_TEXT_BUILDER_CREATE_TEMPLATE"))
    SetButtonText(context.updateTemplateButton, T("INFO_TEXT_BUILDER_RENAME_TEMPLATE"))

    context.newTemplateButton:SetDisabled(false)
    context.deleteTemplateButton:SetDisabled(not hasSelectedTemplate or not canEditSelectedTemplate)
    context.saveButton:SetDisabled(
        (saveMode == "create" and (not hasTemplateName or not hasTemplateText))
        or (saveMode == "update" and (not hasTemplateText or not canEditSelectedTemplate or not isDirty))
        or saveMode == "readOnly"
    )
    context.copyTemplateButton:SetDisabled(not canCopySelectedTemplate)
    context.updateTemplateButton:SetDisabled(not isRenameCandidate)
    context.applyTemplateButton:SetDisabled(not hasTemplateText or not canEditSelectedTemplate)
    ApplyTextBuilderButtonVisuals()

    RefreshPreview(context)
    RefreshTemplateUsageState(context)

    if context.window and context.window.DoLayout then
        context.window:DoLayout()
    end
end

local function CreateWindowContent(window, state, deps)
    local usageCheckboxes = {}
    local groups, widgets = FormRenderer.BuildLayout(window, TextBuilderDefinition, {
        state = state,
        createItemWidget = CreateItemWidget,
        onWidgetCreated = function(widget, group, item)
            if item.widget == "checkbox" and item.unitKey then
                usageCheckboxes[item.unitKey] = widget
            end
        end,
    })

    local root = groups.Root

    return {
        window = window,
        state = state,
        root = root,
        getGUIState = deps and deps.GetGUIState,
        templateEdit = widgets.templateEdit,
        updateButton = widgets.updateButton,
        tagDatabaseButton = widgets.tagDatabaseButton,
        previewValue = widgets.previewValue,
        templateSelect = widgets.templateSelect,
        templateOwnerLabel = widgets.templateOwnerLabel,
        templateNameEdit = widgets.templateNameEdit,
        newTemplateButton = widgets.newTemplateButton,
        deleteTemplateButton = widgets.deleteTemplateButton,
        saveButton = widgets.saveButton,
        copyTemplateButton = widgets.copyTemplateButton,
        updateTemplateButton = widgets.updateTemplateButton,
        libraryHint = widgets.libraryHint,
        usageHint = widgets.usageHint,
        usageCheckboxes = usageCheckboxes,
        applyTemplateButton = widgets.applyTemplateButton,
        suspendTemplateSelectCallbacks = false,
        suspendTemplateNameCallbacks = false,
        suspendTemplateEditCallbacks = false,
        lastTemplateCursorPosition = nil,
    }
end

local function WireWindowCallbacks(context)
    if not context then
        return
    end

    for unitKey, checkbox in pairs(context.usageCheckboxes or {}) do
        checkbox:SetCallback("OnValueChanged", function(widget, _, value)
            if not CanEditSelectedTemplate(context) then
                widget:SetValue(context.state.applyUnits and context.state.applyUnits[unitKey] == true)
                return
            end

            local selectedTemplateName = GetSelectedTemplateName(context.state)
            if selectedTemplateName == "" then
                widget:SetValue(false)
                return
            end

            context.state.applyUnits = context.state.applyUnits or {}
            context.state.applyUnits[unitKey] = value and true or false
            RefreshTemplateUsageState(context)
        end)
    end

    context.templateEdit:SetCallback("OnTextChanged", function(_, _, value)
        if context.suspendTemplateEditCallbacks then
            return
        end

        context.state.template = NormalizeTemplateInput(value or "")
        CaptureTemplateCursor(context)
        RefreshWindowState()
    end)

    context.templateEdit:SetCallback("OnEnterPressed", function(widget, _, value)
        if context.suspendTemplateEditCallbacks then
            return
        end

        context.state.template = NormalizeTemplateInput(value or "")
        CaptureTemplateCursor(context)
        widget:ClearFocus()
        RefreshPreview(context)
        RefreshWindowState()
    end)

    context.templateEdit:SetCallback("OnFocusLost", function(widget)
        if context.suspendTemplateEditCallbacks then
            return
        end

        context.state.template = NormalizeTemplateInput(widget:GetText() or "")
        CaptureTemplateCursor(context)
        RefreshPreview(context)
        RefreshWindowState()
    end)

    context.updateButton:SetCallback("OnClick", function()
        context.state.template = NormalizeTemplateInput(context.templateEdit:GetText() or "")
        RefreshPreview(context)
        RefreshWindowState()
    end)

    if context.tagDatabaseButton then
        context.tagDatabaseButton:SetCallback("OnClick", function()
            local tagLibraryPage = ns.GUI and ns.GUI.Pages and ns.GUI.Pages.TagLibrary
            if not tagLibraryPage or not tagLibraryPage.Open then
                return
            end

            tagLibraryPage.Open({
                owner = "TextBuilder",
                onApply = function(token)
                    return TextBuilderController.InsertTextIntoDraft(token)
                end,
            })
        end)
    end

    context.templateNameEdit:SetCallback("OnTextChanged", function(_, _, value)
        if context.suspendTemplateNameCallbacks then
            return
        end

        context.state.templateName = value or ""
        RefreshWindowState()
    end)

    context.templateNameEdit:SetCallback("OnEnterPressed", function(widget, _, value)
        if context.suspendTemplateNameCallbacks then
            return
        end

        context.state.templateName = value or ""
        widget:ClearFocus()
        RefreshWindowState()
    end)

    context.templateNameEdit:SetCallback("OnFocusLost", function(widget)
        if context.suspendTemplateNameCallbacks then
            return
        end

        context.state.templateName = widget:GetText() or ""
        RefreshWindowState()
    end)

    context.templateSelect:SetCallback("OnValueChanged", function(_, _, value)
        if context.suspendTemplateSelectCallbacks then
            return
        end

        local selectedEntry = ResolveTemplateEntryKey(value)
        if selectedEntry then
            SetTemplateSelection(context.state, selectedEntry)
        else
            ClearTemplateSelection(context.state)
        end

        context.suspendTemplateNameCallbacks = true
        context.templateNameEdit:SetText(context.state.templateName or "")
        context.suspendTemplateNameCallbacks = false

        context.suspendTemplateEditCallbacks = true
        context.templateEdit:SetText(context.state.template or "")
        context.suspendTemplateEditCallbacks = false

        SyncDesiredTemplateUsage(context)
        RefreshPreview(context)
        RefreshWindowState()
    end)

    context.newTemplateButton:SetCallback("OnClick", function()
        ClearTemplateSelection(context.state)
        context.state.templateName = ""
        context.state.template = ""

        context.suspendTemplateSelectCallbacks = true
        context.templateSelect:SetValue(nil)
        context.suspendTemplateSelectCallbacks = false

        context.suspendTemplateNameCallbacks = true
        context.templateNameEdit:SetText("")
        context.suspendTemplateNameCallbacks = false

        context.suspendTemplateEditCallbacks = true
        context.templateEdit:SetText("")
        context.suspendTemplateEditCallbacks = false

        SyncDesiredTemplateUsage(context)
        RefreshPreview(context)
        RefreshTemplateDropdown(context)
        RefreshWindowState()
        SetStatus(T("INFO_TEXT_BUILDER_STATUS_NEW_DRAFT"), "info")
    end)

    context.saveButton:SetCallback("OnClick", function()
        SaveCurrentTemplate(context)
    end)

    context.copyTemplateButton:SetCallback("OnClick", function()
        if not CanCopySelectedTemplate(context) then
            RefreshWindowState()
            SetStatus(T("INFO_TEXT_BUILDER_STATUS_COPY_SELECT_OTHER"), "warning")
            return
        end

        local mutations = ns.TextTemplateMutations
        if not mutations or not mutations.CopyTemplateEntryToProfile then
            SetStatus(T("INFO_TEXT_BUILDER_STATUS_COPY_UNAVAILABLE"), "error")
            return
        end

        local sourceEntry = GetSelectedTemplateEntry(context.state)
        local result = mutations.CopyTemplateEntryToProfile(ns.db, sourceEntry, GetCurrentProfileName())
        if type(result) ~= "table" or not result.success then
            RefreshWindowState()
            SetStatus(T("INFO_TEXT_BUILDER_STATUS_COPY_FAILED"), "error")
            return
        end

        local targetEntry = GetProfileTemplateEntry(result.targetProfileName, result.targetTemplateName)
        if targetEntry then
            SetTemplateSelection(context.state, targetEntry)
        end

        RefreshTemplateDropdown(context)
        RefreshWindowState()
        RefreshEditorInteractionPreview()

        if result.reusedExisting then
            SetStatus(T("INFO_TEXT_BUILDER_STATUS_COPY_REUSED"), "success")
        else
            SetStatus(string.format(T("INFO_TEXT_BUILDER_STATUS_COPY_SUCCESS"), tostring(result.targetTemplateName or "")), "success")
        end
    end)

    context.updateTemplateButton:SetCallback("OnClick", function()
        if not EnsureWritableProfileContext(context) then
            return
        end

        local selectedEntry = GetSelectedTemplateEntry(context.state)
        if not CanEditTemplateEntry(selectedEntry) then
            RefreshWindowState()
            SetStatus(T("INFO_TEXT_BUILDER_STATUS_SELECT_TEMPLATE"), "warning")
            return
        end

        local selectedName = selectedEntry.templateName
        local updatedName = Trim(context.templateNameEdit:GetText() or "")
        local templates = GetTemplates()
        local draft = NormalizeTemplateInput(context.templateEdit:GetText() or "")

        if selectedName == "" or type(templates[selectedName]) ~= "string" then
            SetStatus(T("INFO_TEXT_BUILDER_STATUS_SELECT_TEMPLATE"), "warning")
            return
        end

        if updatedName == "" then
            SetStatus(T("INFO_TEXT_BUILDER_STATUS_NAME_REQUIRED"), "error")
            return
        end

        if updatedName == selectedName then
            RefreshWindowState()
            SetStatus(T("INFO_TEXT_BUILDER_STATUS_NO_CHANGES"), "warning")
            return
        end

        local renameResult = TextTemplateMutations.RenameTemplate and TextTemplateMutations.RenameTemplate(BuildMutationContext(), selectedName, updatedName)
        if type(renameResult) ~= "table" or not renameResult.ok then
            SetStatus(FormatMutationError(renameResult), "error")
            return
        end

        SetTemplateSelectionIdentity(context.state, GetProfileTemplateEntry(context.state.activeProfileName, updatedName) or {
            sourceType = "profile",
            sourceId = context.state.activeProfileName,
            profileName = context.state.activeProfileName,
            templateName = updatedName,
        })
        context.state.templateName = updatedName
        context.state.template = draft
        RefreshTemplateDropdown(context)
        RefreshWindowState()
        RefreshEditorInteractionPreview()
        SetStatus((T("INFO_TEXT_BUILDER_STATUS_RENAMED")) .. " " .. selectedName .. " -> " .. updatedName, "success")
    end)

    context.deleteTemplateButton:SetCallback("OnClick", function()
        local selectedEntry = ResolveWritableProfileSelection(context)
        if not selectedEntry then
            return
        end

        local selectedName = selectedEntry.templateName
        local templates = GetTemplates()

        if selectedName == "" or type(templates[selectedName]) ~= "string" then
            SetStatus(T("INFO_TEXT_BUILDER_STATUS_SELECT_TEMPLATE"), "warning")
            return
        end

        OpenDeleteTemplateConfirmDialog(selectedName)
    end)

    context.applyTemplateButton:SetCallback("OnClick", function()
        if not ResolveApplyTemplateSelection(context) then
            return
        end

        if IsSelectedTemplateDirty(context) then
            OpenUnsavedApplyConfirmDialog(context)
            return
        end

        ApplyTemplateToTextElement(context)
    end)
end

local function CreateWindow(state, deps)
    local window = AceGUI:Create("Window")
    window:SetTitle(T("INFO_TEXT_BUILDER_TITLE"))
    window:SetLayout("Fill")
    window:SetWidth(1040)
    window:SetHeight(700)
    window:EnableResize(false)

    if window.frame then
        window.frame:SetClampedToScreen(true)
    end

    ApplyWindowChrome(window)
    if EnsureStandardWindowCloseButton then
        EnsureStandardWindowCloseButton(window)
    end
    if window.closebutton and window.closebutton.SetScript then
        window.closebutton:SetScript("OnClick", function()
            RequestClose(windowContext)
        end)
    end
    CenterWindow(window)

    local context = CreateWindowContent(window, state, deps)
    windowContext = context
    WireWindowCallbacks(context)

    window:SetCallback("OnClose", function()
        if not isPerformingClose and windowContext and IsSelectedTemplateDirty(windowContext) then
            FocusWindow(windowContext.window)
            OpenUnsavedCloseConfirmDialog(windowContext)
            return
        end
        HideOwnedChildDialogs()
        CloseOwnedTagLibrary()
        if ns.GUI and ns.GUI.ResetStatusText then
            ns.GUI:ResetStatusText()
        end
    end)

    return context
end

function TextBuilderController.OpenWindow(deps)
    local state = GetTextBuilderState(deps)

    if not windowContext or not windowContext.window or not windowContext.window.frame then
        CreateWindow(state, deps)
    else
        windowContext.state = state
        windowContext.getGUIState = deps and deps.GetGUIState
    end

    SyncDesiredTemplateUsage(windowContext)
    RefreshWindowState()
    FocusWindow(windowContext.window)
end

function TextBuilderController.InsertTextIntoDraft(text)
    if type(text) ~= "string" or text == "" then
        return false
    end

    local context = windowContext
    if not context or not context.state or not context.templateEdit or not context.templateEdit.GetText then
        return false
    end
    if not IsTextBuilderWindowShown(context) then
        return false
    end

    local nativeEditBox = GetTemplateNativeEditBox(context)
    if nativeEditBox and nativeEditBox.HasFocus and nativeEditBox:HasFocus() and nativeEditBox.Insert then
        nativeEditBox:Insert(text)
        local nextDraft = NormalizeTemplateInput(context.templateEdit:GetText() or "")
        if context.state.template ~= nextDraft then
            context.state.template = nextDraft
            RefreshPreview(context)
            RefreshWindowState()
        end
        CaptureTemplateCursor(context)
        return true
    end

    local draft = context.templateEdit:GetText() or ""
    local cursor = ClampCursorPosition(context.lastTemplateCursorPosition, draft) or #draft
    local nextDraft = draft:sub(1, cursor) .. text .. draft:sub(cursor + 1)
    local nextCursor = cursor + #text

    context.suspendTemplateEditCallbacks = true
    context.templateEdit:SetText(nextDraft)
    context.suspendTemplateEditCallbacks = false

    if nativeEditBox and nativeEditBox.SetCursorPosition then
        nativeEditBox:SetCursorPosition(nextCursor)
    end

    context.state.template = NormalizeTemplateInput(nextDraft)
    context.lastTemplateCursorPosition = ClampCursorPosition(nextCursor, nextDraft)
    RefreshPreview(context)
    RefreshWindowState()
    return true
end

function TextBuilderController.HideWindow()
    RequestClose(windowContext)
end

function TextBuilderController.RefreshWindowState()
    RefreshWindowState()
end

return TextBuilderController
