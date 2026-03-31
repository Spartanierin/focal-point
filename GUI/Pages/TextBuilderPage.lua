local _, ns = ...

ns.GUI = ns.GUI or {}
ns.GUI.Pages = ns.GUI.Pages or {}

local AceGUI = LibStub("AceGUI-3.0")
local C = ns.Constants
local KM = ns.KeyMap
local L = ns.L
local TextStyles = ns.GUI.Helpers.TextStyles
local ToolPageUI = ns.GUI.Helpers.ToolPageUI

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

    local CreateSpacer = ToolPageUI and ToolPageUI.CreateSpacer
    local CreateRow = ToolPageUI and ToolPageUI.CreateRow
    local CreateButton = ToolPageUI and ToolPageUI.CreateButton

    local page = ToolPageUI and ToolPageUI.CreatePageRoot(container, 880) or container
    if ToolPageUI and ToolPageUI.CreatePageHeader then
        ToolPageUI.CreatePageHeader(
            page,
            L["INFO_TEXT_BUILDER_TITLE"] or "Text Builder",
            L["INFO_TEXT_BUILDER_DESCRIPTION"] or "",
            L["INFO_TOOLS_WORKSPACE"] or "Werkzeugansicht"
        )
    end

    local introHint = AceGUI:Create("Label")
    introHint:SetFullWidth(true)
    introHint:SetText(L["INFO_TEXT_BUILDER_TEMPLATE_HINT"] or "")
    if TextStyles and TextStyles.ApplyLabelWidget then
        TextStyles.ApplyLabelWidget(introHint, "highlight", { size = 12 })
    end
    page:AddChild(introHint)

    page:AddChild(CreateSpacer(10))

    local builderGroup = ToolPageUI and ToolPageUI.CreateCard(
        page,
        L["INFO_TEXT_BUILDER_TEMPLATE"] or "01 Vorlage entwerfen",
        L["INFO_TEXT_BUILDER_TEMPLATE_WORKFLOW"] or "Baue hier die Vorlage auf, mit der spaeter Vorschau, Bibliothek und Textverknuepfung arbeiten."
    ) or page

    local templateHelp = AceGUI:Create("Label")
    templateHelp:SetFullWidth(true)
    templateHelp:SetText(L["INFO_TEXT_BUILDER_TEMPLATE_HINT"] or "")
    if TextStyles and TextStyles.ApplyLabelWidget then
        TextStyles.ApplyLabelWidget(templateHelp, "help", { size = 11 })
    end
    builderGroup:AddChild(templateHelp)

    builderGroup:AddChild(CreateSpacer(3))

    local templateRow = CreateRow(builderGroup, 64)

    local templateEdit = AceGUI:Create("EditBox")
    templateEdit:SetLabel(L["INFO_TEXT_BUILDER_TEMPLATE"] or "Template")
    templateEdit:SetWidth(620)
    templateEdit:DisableButton(true)
    templateEdit:SetText(NormalizeTemplateInput(state.textBuilder.template or ""))
    if TextStyles and TextStyles.ApplyWidgetText then
        TextStyles.ApplyWidgetText(templateEdit, "label", { size = 12 })
    end
    templateRow:AddChild(templateEdit)

    local updateButton = CreateButton(L["INFO_TEXT_BUILDER_APPLY"] or "Update Preview", 190)
    templateRow:AddChild(updateButton)

    local templateFlowHint = AceGUI:Create("Label")
    templateFlowHint:SetFullWidth(true)
    templateFlowHint:SetText(L["INFO_TEXT_BUILDER_TEMPLATE_FLOW_HINT"] or "Arbeite erst an der Vorlage, pruefe dann die Wirkung und speichere nur Varianten, die als Werkzeugbaustein wirklich taugen.")
    if TextStyles and TextStyles.ApplyLabelWidget then
        TextStyles.ApplyLabelWidget(templateFlowHint, "help", { size = 10 })
    end
    builderGroup:AddChild(templateFlowHint)

    local previewGroup = ToolPageUI and ToolPageUI.CreateCard(
        page,
        L["INFO_TEXT_BUILDER_PREVIEW"] or "02 Vorschau lesen",
        L["INFO_TEXT_BUILDER_PREVIEW_HINT_TOOL"] or "Die Vorschau zeigt sofort, ob Lesbarkeit, Informationsdichte und Rhythmus der Vorlage stimmen.",
        { topSpacing = 8 }
    ) or page

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

    local previewHint = AceGUI:Create("Label")
    previewHint:SetFullWidth(true)
    previewHint:SetText(L["INFO_TEXT_BUILDER_PREVIEW_CONTEXT"] or "Nutze diesen Schritt als schnellen Qualitaetscheck, bevor du die Vorlage speicherst oder verknuepfst.")
    if TextStyles and TextStyles.ApplyLabelWidget then
        TextStyles.ApplyLabelWidget(previewHint, "help", { size = 10 })
    end
    previewGroup:AddChild(previewHint)

    local templatesGroup = ToolPageUI and ToolPageUI.CreateCard(
        page,
        L["INFO_TEXT_BUILDER_TEMPLATES"] or "03 Vorlagenbibliothek",
        L["INFO_TEXT_BUILDER_TEMPLATES_HINT_TOOL"] or "Speichere gute Bausteine, aktualisiere bestehende Vorlagen und halte deine Bibliothek sauber und wiederverwendbar.",
        { topSpacing = 8 }
    ) or page

    local templates = (ns.db and ns.db.profile and ns.db.profile.TextTemplates) or {}

    local savedTemplateRow = CreateRow(templatesGroup, 64)

    local templateSelect = AceGUI:Create("Dropdown")
    templateSelect:SetLabel(L["INFO_TEXT_BUILDER_SAVED_TEMPLATES"] or "Saved Templates")
    templateSelect:SetWidth(540)
    if TextStyles and TextStyles.ApplyWidgetText then
        TextStyles.ApplyWidgetText(templateSelect, "label", { size = 12 })
    end
    savedTemplateRow:AddChild(templateSelect)

    local deleteTemplateButton = CreateButton(L["INFO_TEXT_BUILDER_DELETE"] or "Delete", 150)
    savedTemplateRow:AddChild(deleteTemplateButton)

    templatesGroup:AddChild(CreateSpacer(2))

    local templateNameRow = CreateRow(templatesGroup, 64)

    local templateNameEdit = AceGUI:Create("EditBox")
    templateNameEdit:SetLabel(L["INFO_TEXT_BUILDER_TEMPLATE_NAME"] or "Template Name")
    templateNameEdit:SetWidth(460)
    templateNameEdit:DisableButton(true)
    templateNameEdit:SetText(state.textBuilder.templateName or "")
    if TextStyles and TextStyles.ApplyWidgetText then
        TextStyles.ApplyWidgetText(templateNameEdit, "label", { size = 12 })
    end
    templateNameRow:AddChild(templateNameEdit)

    local saveButton = CreateButton(L["INFO_TEXT_BUILDER_SAVE"] or "Save", 120)
    templateNameRow:AddChild(saveButton)

    local updateTemplateButton = CreateButton(L["INFO_TEXT_BUILDER_UPDATE"] or "Update", 140)
    templateNameRow:AddChild(updateTemplateButton)

    local templatesHint = AceGUI:Create("Label")
    templatesHint:SetFullWidth(true)
    templatesHint:SetText(L["INFO_TEXT_BUILDER_LIBRARY_HINT"] or "Die Bibliothek ist dein wiederverwendbarer Werkzeugkasten. Nicht jeder Zwischenstand muss dort landen.")
    if TextStyles and TextStyles.ApplyLabelWidget then
        TextStyles.ApplyLabelWidget(templatesHint, "help", { size = 10 })
    end
    templatesGroup:AddChild(templatesHint)

    local usageGroup = ToolPageUI and ToolPageUI.CreateCard(
        page,
        L["INFO_TEXT_BUILDER_TEMPLATE_USAGE"] or "04 Verknuepfung und Anwendung",
        L["INFO_TEXT_BUILDER_TEMPLATE_USAGE_HINT"] or "Checked units already use the selected template. Uncheck to remove the template link from that unit.",
        { topSpacing = 8 }
    ) or page

    local usageHint = AceGUI:Create("Label")
    usageHint:SetFullWidth(true)
    usageHint:SetText(L["INFO_TEXT_BUILDER_USAGE_LEAD"] or "Verknuepfte Units")
    if TextStyles and TextStyles.ApplyLabelWidget then
        TextStyles.ApplyLabelWidget(usageHint, "label", { size = 12 })
    end
    usageGroup:AddChild(usageHint)

    local usageRow = CreateRow(usageGroup)

    local usageCheckboxes = {}

    local applyHint = AceGUI:Create("Label")
    applyHint:SetFullWidth(true)
    applyHint:SetText(L["INFO_TEXT_BUILDER_APPLY_TO_TEXT"] or "Auf Text anwenden")
    if TextStyles and TextStyles.ApplyLabelWidget then
        TextStyles.ApplyLabelWidget(applyHint, "label", { size = 12 })
    end
    usageGroup:AddChild(CreateSpacer(4))
    usageGroup:AddChild(applyHint)

    local applyContext = AceGUI:Create("Label")
    applyContext:SetFullWidth(true)
    applyContext:SetText(L["INFO_TEXT_BUILDER_APPLY_CONTEXT"] or "Lege die aktuelle Vorlage kontrolliert auf freie Text-Slots der ausgewaehlten Units und halte die Verknuepfung anschliessend in der Bibliothek nachvollziehbar.")
    if TextStyles and TextStyles.ApplyLabelWidget then
        TextStyles.ApplyLabelWidget(applyContext, "help", { size = 10 })
    end
    usageGroup:AddChild(applyContext)

    usageGroup:AddChild(CreateSpacer(3))
    local applyTemplateButton = CreateButton(L["INFO_TEXT_BUILDER_APPLY_TEMPLATE"] or "Apply Template", 190)
    usageGroup:AddChild(applyTemplateButton)

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
        if ns.GUI and ns.GUI.SetStatusText then
            ns.GUI:SetStatusText(message)
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

        for textId, textConfig in pairs(texts) do
            if TextConfigUsesTemplate(textConfig, templateName, templateValue) then
                if type(textId) == "string" and (textId:match("^text_%d+$") or textId:match("^Custom%d+$")) then
                    texts[textId] = nil
                    changed = true
                else
                    textConfig.templateName = ""
                end

                if texts[textId] == nil then
                    -- removed entirely above
                elseif type(textConfig.stateTemplates) == "table" then
                    for stateKey, stateTemplateName in pairs(textConfig.stateTemplates) do
                        if stateTemplateName == templateName then
                            textConfig.stateTemplates[stateKey] = ""
                        end
                    end
                end
                if texts[textId] ~= nil
                    and (textConfig.templateName == nil or textConfig.templateName == "")
                    and (
                        type(textConfig.stateTemplates) ~= "table"
                        or next(textConfig.stateTemplates) == nil
                    )
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
        local texts = ns.GUI.Helpers.OptionValues.Get({ "Units", unitKey, "Texts" }, {}) or {}
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

    local function ApplyTemplateToTextElement()
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

        for _, unitKey in ipairs(unitsToAdd) do
            local textId = GetNextTextElementId(unitKey)
            local newTextConfig = BuildNewTextElementConfig(template, linkedTemplateName)
            ns.GUI.Helpers.OptionValues.Set({ "Units", unitKey, "Texts", textId }, newTextConfig)
            appliedEntries[#appliedEntries + 1] = ns.GetLabel(KM.Units, unitKey)
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
            statusText = L["INFO_TEXT_BUILDER_STATUS_SELECT_UNIT"] or "Select at least one unit."
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
        ApplyTemplateToTextElement()
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
