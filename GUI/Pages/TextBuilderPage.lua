local _, ns = ...

ns.GUI = ns.GUI or {}
ns.GUI.Pages = ns.GUI.Pages or {}

local AceGUI = LibStub("AceGUI-3.0")
local C = ns.Constants
local KM = ns.KeyMap
local L = ns.L
local TextStyles = ns.GUI.Helpers.TextStyles

local TextBuilderPage = {}
ns.GUI.Pages.TextBuilder = TextBuilderPage

local function NormalizeTemplateInput(value)
    local normalizer = ns.TextElementTemplates and ns.TextElementTemplates.NormalizeTemplateText
    if type(normalizer) == "function" then
        return normalizer(value)
    end

    return type(value) == "string" and value or ""
end

function TextBuilderPage.Build(container, deps)
    local GetGUIState = deps.GetGUIState
    local ResetFlowContainer = deps.ResetFlowContainer

    local function StyleGroupTitle(widget)
        if TextStyles and TextStyles.ApplyWidgetText then
            TextStyles.ApplyWidgetText(widget, "sectionHeader", { size = 13 })
        end
    end

    ResetFlowContainer(container)

    local state = GetGUIState()
    state.textBuilder = state.textBuilder or {
        template = "[hp:cur:abbr]/[hp:max:abbr] | [hp:perc]%",
        templateName = "",
        selectedTemplate = "",
        applyUnits = {
            [C.Units.PLAYER] = true,
            [C.Units.TARGET] = false,
            [C.Units.FOCUS] = false,
            [C.Units.PET] = false,
        },
    }

    local function CreateSpacer(height)
        local spacer = AceGUI:Create("Label")
        spacer:SetText(" ")
        spacer:SetFullWidth(true)
        spacer:SetHeight(height or 1)
        return spacer
    end

    local function CreateSection(title)
        local group = AceGUI:Create("InlineGroup")
        group:SetFullWidth(true)
        group:SetLayout("Flow")
        group:SetTitle(title)
        StyleGroupTitle(group)
        container:AddChild(group)
        return group
    end

    local function CreateRow(parent)
        local row = AceGUI:Create("SimpleGroup")
        row:SetFullWidth(true)
        row:SetLayout("Flow")
        parent:AddChild(row)
        return row
    end

    local introGroup = CreateSection(L["INFO_TEXT_BUILDER_TITLE"] or "Text Builder")

    local description = AceGUI:Create("Label")
    description:SetFullWidth(true)
    description:SetText(L["INFO_TEXT_BUILDER_DESCRIPTION"] or "")
    if TextStyles and TextStyles.ApplyLabelWidget then
        TextStyles.ApplyLabelWidget(description, "label", { size = 12 })
    end
    introGroup:AddChild(description)

    introGroup:AddChild(CreateSpacer(2))

    local hint = AceGUI:Create("Label")
    hint:SetFullWidth(true)
    hint:SetText(L["INFO_TEXT_BUILDER_TEMPLATE_HINT"] or "")
    if TextStyles and TextStyles.ApplyLabelWidget then
        TextStyles.ApplyLabelWidget(hint, "highlight", { size = 12 })
    end
    introGroup:AddChild(hint)

    container:AddChild(CreateSpacer(3))

    local builderGroup = CreateSection(L["INFO_TEXT_BUILDER_TEMPLATE"] or "Template")

    local templateHelp = AceGUI:Create("Label")
    templateHelp:SetFullWidth(true)
    templateHelp:SetText(L["INFO_TEXT_BUILDER_TEMPLATE_HINT"] or "")
    if TextStyles and TextStyles.ApplyLabelWidget then
        TextStyles.ApplyLabelWidget(templateHelp, "help", { size = 11 })
    end
    builderGroup:AddChild(templateHelp)

    builderGroup:AddChild(CreateSpacer(2))

    local templateRow = CreateRow(builderGroup)

    local templateEdit = AceGUI:Create("EditBox")
    templateEdit:SetLabel(L["INFO_TEXT_BUILDER_TEMPLATE"] or "Template")
    templateEdit:SetWidth(560)
    templateEdit:DisableButton(true)
    templateEdit:SetText(NormalizeTemplateInput(state.textBuilder.template or ""))
    if TextStyles and TextStyles.ApplyWidgetText then
        TextStyles.ApplyWidgetText(templateEdit, "label", { size = 12 })
    end
    templateRow:AddChild(templateEdit)

    local updateButton = AceGUI:Create("Button")
    updateButton:SetText(L["INFO_TEXT_BUILDER_APPLY"] or "Update Preview")
    updateButton:SetWidth(170)
    templateRow:AddChild(updateButton)

    container:AddChild(CreateSpacer(2))

    local previewGroup = CreateSection(L["INFO_TEXT_BUILDER_PREVIEW"] or "Preview")

    local previewLabel = AceGUI:Create("Label")
    previewLabel:SetFullWidth(true)
    if previewLabel.SetFont then
        previewLabel:SetFont(STANDARD_TEXT_FONT, 14, "")
    end
    if previewLabel.label and previewLabel.label.SetJustifyH then
        previewLabel.label:SetJustifyH("LEFT")
    end
    if previewLabel.label and previewLabel.label.SetJustifyV then
        previewLabel.label:SetJustifyV("MIDDLE")
    end
    previewLabel:SetHeight(34)
    previewLabel:SetText(" ")
    if TextStyles and TextStyles.ApplyLabelWidget then
        TextStyles.ApplyLabelWidget(previewLabel, "highlight", { size = 14 })
    end
    previewGroup:AddChild(previewLabel)

    container:AddChild(CreateSpacer(2))

    local templatesGroup = CreateSection(L["INFO_TEXT_BUILDER_TEMPLATES"] or "Templates")

    local templates = (ns.db and ns.db.profile and ns.db.profile.TextTemplates) or {}

    local savedTemplateRow = CreateRow(templatesGroup)

    local templateSelect = AceGUI:Create("Dropdown")
    templateSelect:SetLabel(L["INFO_TEXT_BUILDER_SAVED_TEMPLATES"] or "Saved Templates")
    templateSelect:SetWidth(460)
    if TextStyles and TextStyles.ApplyWidgetText then
        TextStyles.ApplyWidgetText(templateSelect, "label", { size = 12 })
    end
    savedTemplateRow:AddChild(templateSelect)

    local deleteTemplateButton = AceGUI:Create("Button")
    deleteTemplateButton:SetText(L["INFO_TEXT_BUILDER_DELETE"] or "Delete")
    deleteTemplateButton:SetWidth(140)
    savedTemplateRow:AddChild(deleteTemplateButton)

    templatesGroup:AddChild(CreateSpacer(2))

    local templateNameRow = CreateRow(templatesGroup)

    local templateNameEdit = AceGUI:Create("EditBox")
    templateNameEdit:SetLabel(L["INFO_TEXT_BUILDER_TEMPLATE_NAME"] or "Template Name")
    templateNameEdit:SetWidth(400)
    templateNameEdit:DisableButton(true)
    templateNameEdit:SetText(state.textBuilder.templateName or "")
    if TextStyles and TextStyles.ApplyWidgetText then
        TextStyles.ApplyWidgetText(templateNameEdit, "label", { size = 12 })
    end
    templateNameRow:AddChild(templateNameEdit)

    local saveButton = AceGUI:Create("Button")
    saveButton:SetText(L["INFO_TEXT_BUILDER_SAVE"] or "Save")
    saveButton:SetWidth(120)
    templateNameRow:AddChild(saveButton)

    local updateTemplateButton = AceGUI:Create("Button")
    updateTemplateButton:SetText(L["INFO_TEXT_BUILDER_UPDATE"] or "Update")
    updateTemplateButton:SetWidth(140)
    templateNameRow:AddChild(updateTemplateButton)

    container:AddChild(CreateSpacer(2))

    local usageGroup = CreateSection(L["INFO_TEXT_BUILDER_TEMPLATE_USAGE"] or "Template Usage")

    local usageHint = AceGUI:Create("Label")
    usageHint:SetFullWidth(true)
    usageHint:SetText(L["INFO_TEXT_BUILDER_TEMPLATE_USAGE_HINT"] or "Checked units already use the selected template. Uncheck to remove the template link from that unit.")
    if TextStyles and TextStyles.ApplyLabelWidget then
        TextStyles.ApplyLabelWidget(usageHint, "help", { size = 11 })
    end
    usageGroup:AddChild(usageHint)

    local usageRow = CreateRow(usageGroup)

    local usageCheckboxes = {}

    container:AddChild(CreateSpacer(2))

    local applyGroup = CreateSection(L["INFO_TEXT_BUILDER_APPLY_TO_TEXT"] or "Apply To Text")

    local applyHint = AceGUI:Create("Label")
    applyHint:SetFullWidth(true)
    applyHint:SetText(L["INFO_TEXT_BUILDER_APPLY_TEMPLATE"] or "Apply Template")
    if TextStyles and TextStyles.ApplyLabelWidget then
        TextStyles.ApplyLabelWidget(applyHint, "help", { size = 11 })
    end
    applyGroup:AddChild(applyHint)

    applyGroup:AddChild(CreateSpacer(2))

    local applyTemplateButton = AceGUI:Create("Button")
    applyTemplateButton:SetText(L["INFO_TEXT_BUILDER_APPLY_TEMPLATE"] or "Apply Template")
    applyTemplateButton:SetWidth(170)
    applyGroup:AddChild(applyTemplateButton)

    local function RefreshPreview()
        local template = state.textBuilder.template or ""
        local previewText = ""

        if ns.UnitFrame and ns.UnitFrame.BuildTemplatePreview then
            previewText = ns.UnitFrame:BuildTemplatePreview(template)
        end

        if previewText == "" then
            previewText = template
        end

        previewLabel:SetText(previewText)
    end

    local function SetStatus(message)
        if ns.guiFrame and ns.guiFrame.SetStatusText then
            ns.guiFrame:SetStatusText(message)
        end
    end

    local function TextConfigUsesTemplate(textConfig, templateName, templateValue)
        if type(textConfig) ~= "table" then
            return false
        end

        if type(templateName) == "string" and templateName ~= "" and textConfig.templateName == templateName then
            return true
        end

        if type(templateName) == "string" and templateName ~= "" and type(textConfig.stateTemplates) == "table" then
            for _, stateTemplateName in pairs(textConfig.stateTemplates) do
                if stateTemplateName == templateName then
                    return true
                end
            end
        end

        if type(templateValue) == "string" and templateValue ~= "" and textConfig.tag == templateValue then
            return true
        end

        return false
    end

    local function GetTemplateUsageCounts(templateName)
        local usage = {
            [C.Units.PLAYER] = 0,
            [C.Units.TARGET] = 0,
            [C.Units.FOCUS] = 0,
            [C.Units.PET] = 0,
        }
        local templateValue = templates[templateName]

        if type(templateName) ~= "string" or templateName == "" then
            return usage
        end

        local units = ns.db and ns.db.profile and ns.db.profile.Units or {}
        for unitKey, unitConfig in pairs(units) do
            local texts = type(unitConfig) == "table" and unitConfig.Texts or nil
            if type(texts) == "table" and usage[unitKey] ~= nil then
                for _, textConfig in pairs(texts) do
                    if TextConfigUsesTemplate(textConfig, templateName, templateValue) then
                        usage[unitKey] = usage[unitKey] + 1
                    end
                end
            end
        end

        return usage
    end

    local function SyncDesiredTemplateUsage()
        local selectedTemplateName = state.textBuilder.selectedTemplate or ""
        local usageCounts = GetTemplateUsageCounts(selectedTemplateName)

        state.textBuilder.applyUnits = state.textBuilder.applyUnits or {}
        for _, unitKey in ipairs({ C.Units.PLAYER, C.Units.TARGET, C.Units.FOCUS, C.Units.PET }) do
            state.textBuilder.applyUnits[unitKey] = (usageCounts[unitKey] or 0) > 0
        end
    end

    local function UnlinkTemplateFromUnit(unitKey, templateName)
        local unitConfig = ns.db and ns.db.profile and ns.db.profile.Units and ns.db.profile.Units[unitKey]
        local texts = unitConfig and unitConfig.Texts
        local changed = false
        local templateValue = templates[templateName]

        if type(texts) ~= "table" then
            return false
        end

        for _, textConfig in pairs(texts) do
            if TextConfigUsesTemplate(textConfig, templateName, templateValue) then
                textConfig.templateName = ""
                if type(textConfig.stateTemplates) == "table" then
                    for stateKey, stateTemplateName in pairs(textConfig.stateTemplates) do
                        if stateTemplateName == templateName then
                            textConfig.stateTemplates[stateKey] = ""
                        end
                    end
                end
                if type(templateValue) == "string" and templateValue ~= "" and textConfig.tag == templateValue then
                    textConfig.tag = ""
                end
                if (textConfig.templateName == nil or textConfig.templateName == "")
                    and (textConfig.tag == nil or textConfig.tag == "")
                then
                    textConfig.enabled = false
                end
                changed = true
            end
        end

        return changed
    end

    local function RenameTemplateReferences(oldName, newName)
        if type(oldName) ~= "string" or oldName == "" or type(newName) ~= "string" or newName == "" or oldName == newName then
            return 0
        end

        local renamedCount = 0
        local units = ns.db and ns.db.profile and ns.db.profile.Units or {}
        for _, unitConfig in pairs(units) do
            local texts = type(unitConfig) == "table" and unitConfig.Texts or nil
            if type(texts) == "table" then
                for _, textConfig in pairs(texts) do
                    if type(textConfig) == "table" and textConfig.templateName == oldName then
                        textConfig.templateName = newName
                        renamedCount = renamedCount + 1
                    end

                    if type(textConfig) == "table" and type(textConfig.stateTemplates) == "table" then
                        for stateKey, stateTemplateName in pairs(textConfig.stateTemplates) do
                            if stateTemplateName == oldName then
                                textConfig.stateTemplates[stateKey] = newName
                                renamedCount = renamedCount + 1
                            end
                        end
                    end
                end
            end
        end

        return renamedCount
    end

    local function RefreshTemplateUsageState()
        local selectedTemplateName = state.textBuilder.selectedTemplate or ""
        local usageCounts = GetTemplateUsageCounts(selectedTemplateName)

        for unitKey, checkbox in pairs(usageCheckboxes) do
            local count = usageCounts[unitKey] or 0
            local label = ns.GetLabel(KM.Units, unitKey)
            if count > 0 then
                label = string.format("%s (%d)", label, count)
            end
            checkbox:SetLabel(label)
            checkbox:SetValue(state.textBuilder.applyUnits and state.textBuilder.applyUnits[unitKey] == true)
            checkbox:SetDisabled(selectedTemplateName == "")
            if TextStyles and TextStyles.ApplyInteractiveWidgetText then
                TextStyles.ApplyInteractiveWidgetText(checkbox, "label", selectedTemplateName == "", { size = 12 })
            end
        end
    end

    local function CreateTemplateUsageCheckbox(unitKey)
        local checkbox = AceGUI:Create("CheckBox")
        checkbox:SetWidth(150)
        checkbox:SetLabel(ns.GetLabel(KM.Units, unitKey))
        checkbox:SetValue(false)
        checkbox:SetDisabled(true)
        if TextStyles and TextStyles.ApplyInteractiveWidgetText then
            TextStyles.ApplyInteractiveWidgetText(checkbox, "label", true, { size = 12 })
        end
        checkbox:SetCallback("OnValueChanged", function(widget, _, value)
            local selectedTemplateName = state.textBuilder.selectedTemplate or ""

            if selectedTemplateName == "" then
                widget:SetValue(false)
                return
            end

            state.textBuilder.applyUnits = state.textBuilder.applyUnits or {}
            state.textBuilder.applyUnits[unitKey] = value and true or false
            RefreshTemplateUsageState()
        end)
        usageRow:AddChild(checkbox)
        usageCheckboxes[unitKey] = checkbox
    end

    CreateTemplateUsageCheckbox(C.Units.PLAYER)
    CreateTemplateUsageCheckbox(C.Units.TARGET)
    CreateTemplateUsageCheckbox(C.Units.FOCUS)
    CreateTemplateUsageCheckbox(C.Units.PET)

    local function RefreshTemplateDropdown()
        local list = {}

        for name in pairs(templates) do
            list[name] = name
        end

        templateSelect:SetList(list)
        templateSelect:SetValue(state.textBuilder.selectedTemplate or nil)
        SyncDesiredTemplateUsage()
        RefreshTemplateUsageState()
    end

    local function GetNextTextElementSlot(unitKey)
        local candidateSlots = { "Custom1", "Custom2", "Custom3" }

        for _, slotKey in ipairs(candidateSlots) do
            local textConfig = ns.GUI.Helpers.OptionValues.Get({ "Units", unitKey, "Texts", slotKey }, {}) or {}
            local hasTemplateName = type(textConfig.templateName) == "string" and textConfig.templateName ~= ""
            local hasTag = type(textConfig.tag) == "string" and textConfig.tag ~= ""
            local isEnabled = textConfig.enabled == true

            if (not isEnabled) or (not hasTemplateName and not hasTag) then
                return slotKey
            end
        end

        return nil
    end

    local function ApplyTemplateToTextSlot()
        local template = templateEdit:GetText() or ""
        local selectedTemplateName = state.textBuilder.selectedTemplate or ""
        local linkedTemplateName = ""
        local unitsToAdd = {}
        local unitsToRemove = {}
        local usageCounts = GetTemplateUsageCounts(selectedTemplateName)

        if type(templates[selectedTemplateName]) == "string" and templates[selectedTemplateName] == template then
            linkedTemplateName = selectedTemplateName
        else
            local currentName = state.textBuilder.templateName or ""
            if type(templates[currentName]) == "string" and templates[currentName] == template then
                linkedTemplateName = currentName
            end
        end

        for _, unitKey in ipairs({ C.Units.PLAYER, C.Units.TARGET, C.Units.FOCUS, C.Units.PET }) do
            local wantsLinked = state.textBuilder.applyUnits and state.textBuilder.applyUnits[unitKey] == true
            local isLinked = (usageCounts[unitKey] or 0) > 0

            if wantsLinked and not isLinked then
                unitsToAdd[#unitsToAdd + 1] = unitKey
            elseif (not wantsLinked) and isLinked then
                unitsToRemove[#unitsToRemove + 1] = unitKey
            end
        end

        if #unitsToAdd == 0 and #unitsToRemove == 0 then
            SetStatus(L["INFO_TEXT_BUILDER_STATUS_SELECT_UNIT"] or "Select at least one unit.")
            return
        end

        local appliedEntries = {}
        local removedEntries = {}
        local skippedUnits = {}

        for _, unitKey in ipairs(unitsToAdd) do
            local slotKey = GetNextTextElementSlot(unitKey)
            if not slotKey then
                skippedUnits[#skippedUnits + 1] = ns.GetLabel(KM.Units, unitKey)
            else
                ns.GUI.Helpers.OptionValues.Set({ "Units", unitKey, "Texts", slotKey, "enabled" }, true)
                ns.GUI.Helpers.OptionValues.Set({ "Units", unitKey, "Texts", slotKey, "tag" }, template)
                ns.GUI.Helpers.OptionValues.Set({ "Units", unitKey, "Texts", slotKey, "templateName" }, linkedTemplateName)
                appliedEntries[#appliedEntries + 1] = string.format("%s -> %s", ns.GetLabel(KM.Units, unitKey), slotKey)
            end
        end

        for _, unitKey in ipairs(unitsToRemove) do
            if UnlinkTemplateFromUnit(unitKey, selectedTemplateName) then
                removedEntries[#removedEntries + 1] = ns.GetLabel(KM.Units, unitKey)
            end
        end

        ns.GUI.Helpers.OptionRefresh.Live()

        if ns.GUI and ns.GUI.RefreshOptions then
            ns.GUI:RefreshOptions()
        end

        local statusParts = {}

        if #appliedEntries > 0 then
            statusParts[#statusParts + 1] = (L["INFO_TEXT_BUILDER_STATUS_APPLIED_TO"] or "Applied to") .. ": " .. table.concat(appliedEntries, ", ")
        end

        if #removedEntries > 0 then
            statusParts[#statusParts + 1] = (L["INFO_TEXT_BUILDER_TEMPLATE_USAGE_UNLINKED"] or "Template unlinked from") .. ": " .. table.concat(removedEntries, ", ")
        end

        local statusText = table.concat(statusParts, " | ")
        if linkedTemplateName ~= "" and statusText ~= "" then
            statusText = statusText .. " (" .. linkedTemplateName .. ")"
        end
        if #appliedEntries == 0 and #removedEntries == 0 then
            statusText = L["INFO_TEXT_BUILDER_STATUS_NO_FREE_SLOT"] or "No free text element available for the selected units."
        elseif #skippedUnits > 0 then
            statusText = statusText .. " | " .. (L["INFO_TEXT_BUILDER_STATUS_SKIPPED_UNITS"] or "Skipped") .. ": " .. table.concat(skippedUnits, ", ")
        end

        SetStatus(statusText)
        SyncDesiredTemplateUsage()
        RefreshTemplateUsageState()
    end

    templateEdit:SetCallback("OnEnterPressed", function(widget, _, value)
        state.textBuilder.template = value or ""
        RefreshPreview()
        widget:ClearFocus()
    end)

    templateEdit:SetCallback("OnFocusLost", function(widget)
        state.textBuilder.template = widget:GetText() or ""
        RefreshPreview()
    end)

    updateButton:SetCallback("OnClick", function()
        state.textBuilder.template = NormalizeTemplateInput(templateEdit:GetText() or "")
        RefreshPreview()
    end)

    applyTemplateButton:SetCallback("OnClick", function()
        ApplyTemplateToTextSlot()
    end)

    templateNameEdit:SetCallback("OnEnterPressed", function(widget, _, value)
        state.textBuilder.templateName = value or ""
        widget:ClearFocus()
    end)

    templateNameEdit:SetCallback("OnFocusLost", function(widget)
        state.textBuilder.templateName = widget:GetText() or ""
    end)

    templateSelect:SetCallback("OnValueChanged", function(_, _, value)
        local selectedName = value or ""
        local selectedTemplate = templates[selectedName]

        state.textBuilder.selectedTemplate = selectedName
        state.textBuilder.templateName = selectedName
        templateNameEdit:SetText(selectedName)

        if type(selectedTemplate) == "string" then
            state.textBuilder.template = NormalizeTemplateInput(selectedTemplate)
            templateEdit:SetText(NormalizeTemplateInput(selectedTemplate))
            RefreshPreview()
        end

        SyncDesiredTemplateUsage()
        RefreshTemplateUsageState()
    end)

    saveButton:SetCallback("OnClick", function()
        local name = (templateNameEdit:GetText() or ""):gsub("^%s+", ""):gsub("%s+$", "")
        local template = NormalizeTemplateInput(templateEdit:GetText() or "")

        if name == "" then
            SetStatus(L["INFO_TEXT_BUILDER_STATUS_NAME_REQUIRED"] or "Please enter a template name.")
            return
        end

        templates[name] = template
        state.textBuilder.selectedTemplate = name
        state.textBuilder.templateName = name
        state.textBuilder.template = template
        RefreshTemplateDropdown()
        SetStatus((L["INFO_TEXT_BUILDER_STATUS_SAVED"] or "Template saved:") .. " " .. name)
    end)

    updateTemplateButton:SetCallback("OnClick", function()
        local selectedName = state.textBuilder.selectedTemplate or ""
        local updatedName = (templateNameEdit:GetText() or ""):gsub("^%s+", ""):gsub("%s+$", "")
        local template = NormalizeTemplateInput(templateEdit:GetText() or "")

        if selectedName == "" or type(templates[selectedName]) ~= "string" then
            SetStatus(L["INFO_TEXT_BUILDER_STATUS_SELECT_TEMPLATE"] or "Select a saved template first.")
            return
        end

        if updatedName == "" then
            SetStatus(L["INFO_TEXT_BUILDER_STATUS_NAME_REQUIRED"] or "Please enter a template name.")
            return
        end

        if updatedName ~= selectedName and type(templates[updatedName]) == "string" then
            SetStatus((L["INFO_TEXT_BUILDER_STATUS_NAME_EXISTS"] or "A template with this name already exists:") .. " " .. updatedName)
            return
        end

        if updatedName ~= selectedName then
            templates[updatedName] = template
            templates[selectedName] = nil
            RenameTemplateReferences(selectedName, updatedName)
            state.textBuilder.selectedTemplate = updatedName
            state.textBuilder.templateName = updatedName
            state.textBuilder.template = template
            templateNameEdit:SetText(updatedName)
            RefreshTemplateDropdown()
            SetStatus((L["INFO_TEXT_BUILDER_STATUS_UPDATED"] or "Template updated:") .. " " .. updatedName)
            return
        end

        templates[selectedName] = template
        state.textBuilder.template = template
        state.textBuilder.templateName = selectedName
        RefreshTemplateDropdown()
        SetStatus((L["INFO_TEXT_BUILDER_STATUS_UPDATED"] or "Template updated:") .. " " .. selectedName)
    end)

    deleteTemplateButton:SetCallback("OnClick", function()
        local selectedName = state.textBuilder.selectedTemplate or ""

        if selectedName == "" or type(templates[selectedName]) ~= "string" then
            SetStatus(L["INFO_TEXT_BUILDER_STATUS_SELECT_TEMPLATE"] or "Select a saved template first.")
            return
        end

        templates[selectedName] = nil
        state.textBuilder.selectedTemplate = ""
        state.textBuilder.templateName = ""
        templateNameEdit:SetText("")
        RefreshTemplateDropdown()
        SetStatus((L["INFO_TEXT_BUILDER_STATUS_DELETED"] or "Template deleted:") .. " " .. selectedName)
    end)

    RefreshTemplateDropdown()
    RefreshPreview()
    SyncDesiredTemplateUsage()
    RefreshTemplateUsageState()
end
