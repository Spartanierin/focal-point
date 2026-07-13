local _, ns = ...

ns.GUI = ns.GUI or {}
ns.GUI.Pages = ns.GUI.Pages or {}

local AceGUI = LibStub("AceGUI-3.0")
local C = ns.Constants
local KM = ns.KeyMap
local L = ns.L
local FormWidgets = ns.GUI.Helpers and ns.GUI.Helpers.FormWidgets
local FormRenderer = ns.GUI.Helpers and ns.GUI.Helpers.FormRenderer
local TextBuilderDefinition = ns.GUI.Layouts and ns.GUI.Layouts.TextBuilder and ns.GUI.Layouts.TextBuilder.Form

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
local RefreshWindowState

local CreateBodyText = FormWidgets.CreateBodyText
local StyleDropdown = FormWidgets.StyleDropdown
local StyleEditBox = FormWidgets.StyleEditBox
local StyleCheckBox = FormWidgets.StyleCheckBox
local ApplyWindowChrome = FormWidgets.ApplyWindowChrome
local EnsureStandardWindowCloseButton = FormWidgets.EnsureStandardWindowCloseButton
local CreateActionButton = FormWidgets.CreateActionButton
local ApplyModalActionButtonVisual = FormWidgets.ApplyModalActionButtonVisual
local ResolveItemColor = FormWidgets.ResolveItemColor

local function T(key, fallback)
    return (L and L[key]) or fallback or ""
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

local function ResetApplyUnits(state)
    state.applyUnits = {}
    for index, unitKey in ipairs(UNIT_KEYS) do
        state.applyUnits[unitKey] = index == 1
    end
end

local function ClearTemplateSelection(state)
    state.selectedTemplate = ""
    state.templateName = ""
    state.template = DEFAULT_TEMPLATE
    state.selectedTemplateProfileName = state.activeProfileName
    ResetApplyUnits(state)
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
    local previousSelectedTemplate = state.selectedTemplate
    local profileChanged = previousProfileName ~= nil and previousProfileName ~= currentProfileName
    local selectionProfileMismatch = type(previousSelectedTemplate) == "string"
        and previousSelectedTemplate ~= ""
        and state.selectedTemplateProfileName ~= nil
        and state.selectedTemplateProfileName ~= currentProfileName

    if previousProfileName == nil then
        state.activeProfileName = currentProfileName
        if state.selectedTemplateProfileName == nil then
            state.selectedTemplateProfileName = currentProfileName
        end
        return false
    end

    if not profileChanged and not selectionProfileMismatch then
        return false
    end

    local templates = GetActiveProfileTemplates()
    state.activeProfileName = currentProfileName
    state.selectedTemplateProfileName = currentProfileName
    state._profileContextChanged = true

    if type(previousSelectedTemplate) == "string"
        and previousSelectedTemplate ~= ""
        and type(templates[previousSelectedTemplate]) == "string"
    then
        state.selectedTemplate = previousSelectedTemplate
        state.templateName = previousSelectedTemplate
        state.template = NormalizeTemplateInput(templates[previousSelectedTemplate])
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

local function SetStatus(message)
    if ns.GUI and ns.GUI.SetStatusText then
        ns.GUI:SetStatusText(message)
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

local function GetWritableTemplates()
    if not ns.db or not ns.db.profile then
        return {}
    end

    ns.db.profile.TextTemplates = ns.db.profile.TextTemplates or {}
    return ns.db.profile.TextTemplates
end

local function CenterWindow(window)
    local frame = window and window.frame
    if not frame then
        return
    end

    frame:ClearAllPoints()
    frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
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

local function GetTemplateUsageCounts(templateName)
    local usage = {}
    for _, unitKey in ipairs(UNIT_KEYS) do
        usage[unitKey] = 0
    end

    if type(templateName) ~= "string" or templateName == "" then
        return usage
    end

    local scanner = ns.TextTemplateUsage and ns.TextTemplateUsage.ScanActiveProfileTemplateAssignments
    if not scanner then
        return usage
    end

    local countedTextElements = {}
    for _, entry in ipairs(scanner(ns.db) or {}) do
        if entry.templateName == templateName and usage[entry.unit] ~= nil then
            local textKey = tostring(entry.unit or "") .. "\001" .. tostring(entry.textId or "")
            if not countedTextElements[textKey] then
                usage[entry.unit] = usage[entry.unit] + 1
                countedTextElements[textKey] = true
            end
        end
    end

    return usage
end

local function SyncDesiredTemplateUsage(context)
    local selectedTemplateName = context.state.selectedTemplate or ""
    local usageCounts = GetTemplateUsageCounts(selectedTemplateName)

    context.state.applyUnits = context.state.applyUnits or {}
    for _, unitKey in ipairs(UNIT_KEYS) do
        context.state.applyUnits[unitKey] = (usageCounts[unitKey] or 0) > 0
    end
end

local function UnlinkTemplateFromUnit(unitKey, templateName)
    local unitConfig = ns.db and ns.db.profile and ns.db.profile.Units and ns.db.profile.Units[unitKey]
    local texts = unitConfig and unitConfig.Texts
    local changed = false

    if type(texts) ~= "table" then
        return false
    end

    for textId, textConfig in pairs(texts) do
        if type(textConfig) == "table" then
            local matched = textConfig.templateName == templateName
            if not matched and type(textConfig.stateTemplates) == "table" then
                for _, stateTemplateName in pairs(textConfig.stateTemplates) do
                    if stateTemplateName == templateName then
                        matched = true
                        break
                    end
                end
            end

            if matched then
                if type(textId) == "string" and (textId:match("^text_%d+$") or textId:match("^Custom%d+$")) then
                    texts[textId] = nil
                    changed = true
                else
                    textConfig.templateName = ""
                end

                if texts[textId] ~= nil and type(textConfig.stateTemplates) == "table" then
                    for stateKey, stateTemplateName in pairs(textConfig.stateTemplates) do
                        if stateTemplateName == templateName then
                            textConfig.stateTemplates[stateKey] = ""
                        end
                    end
                end

                if texts[textId] ~= nil
                    and (textConfig.templateName == nil or textConfig.templateName == "")
                    and (type(textConfig.stateTemplates) ~= "table" or next(textConfig.stateTemplates) == nil)
                then
                    if type(textId) == "string" and textId:match("^text_%d+$") then
                        texts[textId] = nil
                    else
                        textConfig.enabled = false
                    end
                end

                changed = true
            end
        end
    end

    return changed
end

local function RenameTemplateReferences(oldName, newName)
    if oldName == "" or newName == "" or oldName == newName then
        return
    end

    local units = ns.db and ns.db.profile and ns.db.profile.Units or {}
    for _, unitConfig in pairs(units or {}) do
        local texts = type(unitConfig) == "table" and unitConfig.Texts or nil
        if type(texts) == "table" then
            for _, textConfig in pairs(texts) do
                if type(textConfig) == "table" then
                    if textConfig.templateName == oldName then
                        textConfig.templateName = newName
                    end

                    if type(textConfig.stateTemplates) == "table" then
                        for stateKey, stateTemplateName in pairs(textConfig.stateTemplates) do
                            if stateTemplateName == oldName then
                                textConfig.stateTemplates[stateKey] = newName
                            end
                        end
                    end
                end
            end
        end
    end
end

local function BuildNewTextElementConfig(template, linkedTemplateName)
    return {
        enabled = true,
        tag = template or "",
        templateName = linkedTemplateName or "",
        font = STANDARD_TEXT_FONT,
        fontStyle = "NONE",
        fontSize = 12,
        justifyH = "CENTER",
        anchorTo = "HealthBar",
        point = "CENTER",
        relativePoint = "CENTER",
        offsetX = 0,
        offsetY = 0,
        overflowMode = "NONE",
        shadowEnabled = true,
        shadowColor = { 0, 0, 0, 1 },
        shadowOffsetX = 1,
        shadowOffsetY = -1,
        color = { 1, 1, 1, 1 },
    }
end

local function GetNextTextElementId(unitKey)
    local optionValues = ns.GUI and ns.GUI.Helpers and ns.GUI.Helpers.OptionValues
    local texts = optionValues and optionValues.Get and optionValues.Get({ "Units", unitKey, "Texts" }, {}) or {}
    local maxIndex = 0

    if type(texts) == "table" then
        for textId in pairs(texts) do
            if type(textId) == "string" then
                local numericId = tonumber(textId:match("^text_(%d+)$"))
                if numericId and numericId > maxIndex then
                    maxIndex = numericId
                end
            end
        end
    end

    local nextIndex = maxIndex + 1
    local candidateId = string.format("text_%d", nextIndex)
    while type(texts) == "table" and texts[candidateId] ~= nil do
        nextIndex = nextIndex + 1
        candidateId = string.format("text_%d", nextIndex)
    end

    return candidateId
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
    local selectedTemplateName = context.state.selectedTemplate or ""
    local usageCounts = GetTemplateUsageCounts(selectedTemplateName)

    for unitKey, checkbox in pairs(context.usageCheckboxes or {}) do
        local count = usageCounts[unitKey] or 0
        local label = ns.GetLabel and ns.GetLabel(KM.Units, unitKey) or unitKey
        if count > 0 then
            label = string.format("%s (%d)", label, count)
        end

        checkbox:SetLabel(label)
        checkbox:SetValue(context.state.applyUnits and context.state.applyUnits[unitKey] == true)
        checkbox:SetDisabled(selectedTemplateName == "")
        StyleCheckBox(checkbox, selectedTemplateName == "")
    end
end

local function SyncTemplateSelectWidget(context)
    local list = {}
    for name in pairs(GetTemplates()) do
        list[name] = name
    end

    context.templateSelect:SetList(list)
    context.suspendTemplateSelectCallbacks = true
    context.templateSelect:SetValue(context.state.selectedTemplate ~= "" and context.state.selectedTemplate or nil)
    context.suspendTemplateSelectCallbacks = false
end

local function RefreshTemplateDropdown(context)
    SyncTemplateSelectWidget(context)
    SyncDesiredTemplateUsage(context)
    RefreshTemplateUsageState(context)
end

local function ApplyTemplateToTextElement(context)
    local optionValues = ns.GUI and ns.GUI.Helpers and ns.GUI.Helpers.OptionValues
    local optionRefresh = ns.GUI and ns.GUI.Helpers and ns.GUI.Helpers.OptionRefresh
    if not optionValues or not optionValues.Set then
        return
    end

    local templates = GetTemplates()
    local template = NormalizeTemplateInput(context.templateEdit:GetText() or "")
    local selectedTemplateName = context.state.selectedTemplate or ""
    local linkedTemplateName = ""
    local unitsToAdd = {}
    local unitsToRemove = {}
    local usageCounts = GetTemplateUsageCounts(selectedTemplateName)

    if type(templates[selectedTemplateName]) == "string" and templates[selectedTemplateName] == template then
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
        SetStatus(T("INFO_TEXT_BUILDER_STATUS_SELECT_UNIT"))
        return
    end

    local appliedEntries = {}
    local removedEntries = {}

    for _, unitKey in ipairs(unitsToAdd) do
        local textId = GetNextTextElementId(unitKey)
        local newTextConfig = BuildNewTextElementConfig(template, linkedTemplateName)
        optionValues.Set({ "Units", unitKey, "Texts", textId }, newTextConfig)
        appliedEntries[#appliedEntries + 1] = ns.GetLabel and ns.GetLabel(KM.Units, unitKey) or unitKey
    end

    for _, unitKey in ipairs(unitsToRemove) do
        if UnlinkTemplateFromUnit(unitKey, selectedTemplateName) then
            removedEntries[#removedEntries + 1] = ns.GetLabel and ns.GetLabel(KM.Units, unitKey) or unitKey
        end
    end

    if optionRefresh and optionRefresh.Live then
        optionRefresh.Live()
    end

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

    SetStatus(statusText)
    SyncDesiredTemplateUsage(context)
    RefreshTemplateUsageState(context)
end

local function EnsureWritableProfileContext(context)
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
        ApplyModalActionButtonVisual(context.saveButton, "primary_action")
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
        context.deleteTemplateButton:SetDisabled(true)
        context.saveButton:SetDisabled(true)
        context.updateTemplateButton:SetDisabled(true)
        context.applyTemplateButton:SetDisabled(true)
        ApplyTextBuilderButtonVisuals()
        context.libraryHint:SetText(T("INFO_COMMON_UNAVAILABLE"))
        context.usageHint:SetText(T("INFO_COMMON_UNAVAILABLE"))
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

    context.libraryHint:SetText(T("INFO_TEXT_BUILDER_LIBRARY_HINT_SHORT"))
    context.usageHint:SetText(T("INFO_TEXT_BUILDER_TEMPLATE_USAGE_HINT_SHORT"))

    local hasSelectedTemplate = type(context.state.selectedTemplate) == "string" and context.state.selectedTemplate ~= ""
    local hasTemplateName = Trim(context.templateNameEdit:GetText() or "") ~= ""
    local hasTemplateText = Trim(context.templateEdit:GetText() or "") ~= ""

    SyncTemplateSelectWidget(context)
    if profileContextChanged or context.state._profileContextChanged then
        SyncDesiredTemplateUsage(context)
        context.state._profileContextChanged = nil
    end

    context.deleteTemplateButton:SetDisabled(not hasSelectedTemplate)
    context.saveButton:SetDisabled(not hasTemplateName or not hasTemplateText)
    context.updateTemplateButton:SetDisabled(not hasSelectedTemplate or not hasTemplateName or not hasTemplateText)
    context.applyTemplateButton:SetDisabled(not hasTemplateText)
    ApplyTextBuilderButtonVisuals()

    RefreshPreview(context)
    RefreshTemplateUsageState(context)

    if context.window and context.window.DoLayout then
        context.window:DoLayout()
    end
end

local function CreateWindowContent(window, state)
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
        templateEdit = widgets.templateEdit,
        updateButton = widgets.updateButton,
        previewValue = widgets.previewValue,
        templateSelect = widgets.templateSelect,
        templateNameEdit = widgets.templateNameEdit,
        deleteTemplateButton = widgets.deleteTemplateButton,
        saveButton = widgets.saveButton,
        updateTemplateButton = widgets.updateTemplateButton,
        libraryHint = widgets.libraryHint,
        usageHint = widgets.usageHint,
        usageCheckboxes = usageCheckboxes,
        applyTemplateButton = widgets.applyTemplateButton,
        suspendTemplateSelectCallbacks = false,
        suspendTemplateNameCallbacks = false,
        suspendTemplateEditCallbacks = false,
    }
end

local function WireWindowCallbacks(context)
    if not context then
        return
    end

    for unitKey, checkbox in pairs(context.usageCheckboxes or {}) do
        checkbox:SetCallback("OnValueChanged", function(widget, _, value)
            local selectedTemplateName = context.state.selectedTemplate or ""
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
        RefreshWindowState()
    end)

    context.templateEdit:SetCallback("OnEnterPressed", function(widget, _, value)
        if context.suspendTemplateEditCallbacks then
            return
        end

        context.state.template = NormalizeTemplateInput(value or "")
        widget:ClearFocus()
        RefreshPreview(context)
        RefreshWindowState()
    end)

    context.templateEdit:SetCallback("OnFocusLost", function(widget)
        if context.suspendTemplateEditCallbacks then
            return
        end

        context.state.template = NormalizeTemplateInput(widget:GetText() or "")
        RefreshPreview(context)
        RefreshWindowState()
    end)

    context.updateButton:SetCallback("OnClick", function()
        context.state.template = NormalizeTemplateInput(context.templateEdit:GetText() or "")
        RefreshPreview(context)
        RefreshWindowState()
    end)

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

        local selectedName = value or ""
        local selectedTemplate = GetTemplates()[selectedName]

        context.state.selectedTemplate = selectedName
        context.state.selectedTemplateProfileName = context.state.activeProfileName
        context.state.templateName = selectedName
        context.state.template = type(selectedTemplate) == "string" and NormalizeTemplateInput(selectedTemplate) or context.state.template

        context.suspendTemplateNameCallbacks = true
        context.templateNameEdit:SetText(selectedName)
        context.suspendTemplateNameCallbacks = false

        if type(selectedTemplate) == "string" then
            context.suspendTemplateEditCallbacks = true
            context.templateEdit:SetText(NormalizeTemplateInput(selectedTemplate))
            context.suspendTemplateEditCallbacks = false
        end

        SyncDesiredTemplateUsage(context)
        RefreshPreview(context)
        RefreshWindowState()
    end)

    context.saveButton:SetCallback("OnClick", function()
        if not EnsureWritableProfileContext(context) then
            return
        end

        local templates = GetWritableTemplates()
        local name = Trim(context.templateNameEdit:GetText() or "")
        local template = NormalizeTemplateInput(context.templateEdit:GetText() or "")

        if name == "" then
            SetStatus(T("INFO_TEXT_BUILDER_STATUS_NAME_REQUIRED"))
            return
        end

        templates[name] = template
        context.state.selectedTemplate = name
        context.state.selectedTemplateProfileName = context.state.activeProfileName
        context.state.templateName = name
        context.state.template = template
        RefreshTemplateDropdown(context)
        RefreshWindowState()
        SetStatus((T("INFO_TEXT_BUILDER_STATUS_SAVED")) .. " " .. name)
    end)

    context.updateTemplateButton:SetCallback("OnClick", function()
        if not EnsureWritableProfileContext(context) then
            return
        end

        local templates = GetWritableTemplates()
        local selectedName = context.state.selectedTemplate or ""
        local updatedName = Trim(context.templateNameEdit:GetText() or "")
        local template = NormalizeTemplateInput(context.templateEdit:GetText() or "")

        if selectedName == "" or type(templates[selectedName]) ~= "string" then
            SetStatus(T("INFO_TEXT_BUILDER_STATUS_SELECT_TEMPLATE"))
            return
        end

        if updatedName == "" then
            SetStatus(T("INFO_TEXT_BUILDER_STATUS_NAME_REQUIRED"))
            return
        end

        if updatedName ~= selectedName and type(templates[updatedName]) == "string" then
            SetStatus((T("INFO_TEXT_BUILDER_STATUS_NAME_EXISTS")) .. " " .. updatedName)
            return
        end

        if updatedName ~= selectedName then
            templates[updatedName] = template
            templates[selectedName] = nil
            RenameTemplateReferences(selectedName, updatedName)
            context.state.selectedTemplate = updatedName
            context.state.selectedTemplateProfileName = context.state.activeProfileName
            context.state.templateName = updatedName
            context.state.template = template
            RefreshTemplateDropdown(context)
            RefreshWindowState()
            SetStatus((T("INFO_TEXT_BUILDER_STATUS_UPDATED")) .. " " .. updatedName)
            return
        end

        templates[selectedName] = template
        context.state.template = template
        context.state.templateName = selectedName
        context.state.selectedTemplateProfileName = context.state.activeProfileName
        RefreshTemplateDropdown(context)
        RefreshWindowState()
        SetStatus((T("INFO_TEXT_BUILDER_STATUS_UPDATED")) .. " " .. selectedName)
    end)

    context.deleteTemplateButton:SetCallback("OnClick", function()
        if not EnsureWritableProfileContext(context) then
            return
        end

        local templates = GetWritableTemplates()
        local selectedName = context.state.selectedTemplate or ""

        if selectedName == "" or type(templates[selectedName]) ~= "string" then
            SetStatus(T("INFO_TEXT_BUILDER_STATUS_SELECT_TEMPLATE"))
            return
        end

        templates[selectedName] = nil
        context.state.selectedTemplate = ""
        context.state.selectedTemplateProfileName = context.state.activeProfileName
        context.state.templateName = ""
        RefreshTemplateDropdown(context)
        RefreshWindowState()
        SetStatus((T("INFO_TEXT_BUILDER_STATUS_DELETED")) .. " " .. selectedName)
    end)

    context.applyTemplateButton:SetCallback("OnClick", function()
        if not EnsureWritableProfileContext(context) then
            return
        end

        ApplyTemplateToTextElement(context)
    end)
end

local function CreateWindow(state)
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
    CenterWindow(window)

    local context = CreateWindowContent(window, state)
    windowContext = context
    WireWindowCallbacks(context)

    window:SetCallback("OnClose", function()
        if ns.GUI and ns.GUI.ResetStatusText then
            ns.GUI:ResetStatusText()
        end
    end)

    return context
end

function TextBuilderController.OpenWindow(deps)
    local state = GetTextBuilderState(deps)

    if not windowContext or not windowContext.window or not windowContext.window.frame then
        CreateWindow(state)
    else
        windowContext.state = state
    end

    SyncDesiredTemplateUsage(windowContext)
    RefreshWindowState()
    FocusWindow(windowContext.window)
end

function TextBuilderController.HideWindow()
    if not windowContext or not windowContext.window then
        return
    end

    if windowContext.window.Hide then
        windowContext.window:Hide()
    elseif windowContext.window.frame and windowContext.window.frame.Hide then
        windowContext.window.frame:Hide()
    end
end

function TextBuilderController.RefreshWindowState()
    RefreshWindowState()
end

return TextBuilderController
