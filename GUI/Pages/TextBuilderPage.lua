local _, ns = ...

ns.GUI = ns.GUI or {}
ns.GUI.Pages = ns.GUI.Pages or {}

local AceGUI = LibStub("AceGUI-3.0")
local C = ns.Constants
local KM = ns.KeyMap
local L = ns.L
local TextStyles = ns.GUI.Helpers and ns.GUI.Helpers.TextStyles
local SidebarShared = ns.GUI.Editor and ns.GUI.Editor.SidebarShared or {}

local TextBuilderPage = {}
ns.GUI.Pages.TextBuilder = TextBuilderPage

local DEFAULT_TEMPLATE = "[hp:cur:abbr]/[hp:max:abbr] | [hp:perc]%"
local TEMPLATE_EXAMPLE = DEFAULT_TEMPLATE
local UNIT_KEYS = {
    C.Units.PLAYER,
    C.Units.TARGET,
    C.Units.FOCUS,
    C.Units.PET,
}

local fallbackRootState = {}
local windowContext

local PANEL_BACKGROUND = { 0.07, 0.08, 0.10, 0.90 }
local PANEL_BORDER = { 0.24, 0.27, 0.31, 0.92 }
local PANEL_HEADER = { 0.10, 0.11, 0.14, 0.70 }
local FIELD_BACKGROUND = { 0.10, 0.11, 0.14, 0.96 }
local FIELD_BORDER = { 0.31, 0.34, 0.39, 0.95 }
local BUTTON_RED = { 0.34, 0.12, 0.12, 0.95 }
local BUTTON_RED_DARK = { 0.23, 0.08, 0.08, 0.98 }
local BUTTON_RED_HIGHLIGHT = { 0.48, 0.18, 0.18, 0.95 }
local BUTTON_RED_DISABLED = { 0.19, 0.12, 0.12, 0.90 }
local DESCRIPTION_TEXT = { 0.68, 0.70, 0.75 }
local HINT_TEXT = { 0.70, 0.73, 0.78 }
local FOOTER_HINT_TEXT = { 0.62, 0.65, 0.70 }
local VALUE_TEXT = { 0.93, 0.90, 0.80 }

local function T(key, fallback)
    return (L and L[key]) or fallback
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

    state.applyUnits = state.applyUnits or {}
    if state.applyUnits[C.Units.PLAYER] == nil then
        state.applyUnits[C.Units.PLAYER] = true
    end
    if state.applyUnits[C.Units.TARGET] == nil then
        state.applyUnits[C.Units.TARGET] = false
    end
    if state.applyUnits[C.Units.FOCUS] == nil then
        state.applyUnits[C.Units.FOCUS] = false
    end
    if state.applyUnits[C.Units.PET] == nil then
        state.applyUnits[C.Units.PET] = false
    end

    return state
end

local function SetStatus(message)
    if ns.GUI and ns.GUI.SetStatusText then
        ns.GUI:SetStatusText(message)
    end
end

local function RefreshToolUI()
    if ns.GUI and ns.GUI.RefreshOptions then
        ns.GUI:RefreshOptions()
    end
end

local function GetTemplates()
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

local function ApplyTextStyle(target, role, size, alpha)
    if not target then
        return
    end

    if TextStyles and TextStyles.ApplyFontString then
        TextStyles.ApplyFontString(target, role, {
            size = size,
            alpha = alpha,
        })
    end
end

local function SetTextureColor(texture, color)
    if texture and texture.SetVertexColor and color then
        texture:SetVertexColor(color[1] or 1, color[2] or 1, color[3] or 1, color[4] or 1)
    end
end

local function CreateSectionTitle(text, size)
    local label = AceGUI:Create("Label")
    label:SetFullWidth(true)
    label:SetText(text or "")
    ApplyTextStyle(label.label, "sectionHeader", size or 13, 1)
    return label
end

local function CreateBodyText(text, role, size, color)
    local label = AceGUI:Create("Label")
    label:SetFullWidth(true)
    label:SetText(text or "")
    ApplyTextStyle(label.label, role or "label", size or 12, 1)

    if color and label.label and label.label.SetTextColor then
        label.label:SetTextColor(color[1] or 1, color[2] or 1, color[3] or 1, color[4] or 1)
    end

    return label
end

local function StyleActionButton(button, variant)
    if not button or not button.frame then
        return
    end

    if SidebarShared and SidebarShared.StyleSidebarButton then
        SidebarShared.StyleSidebarButton(button, variant == "danger" and "danger" or "primary")
    end

    button:SetHeight(26)

    if button.text and button.text.SetTextColor then
        button.text:SetTextColor(0.95, 0.91, 0.88, 1)
    end

    local frame = button.frame
    local normal = frame.GetNormalTexture and frame:GetNormalTexture() or nil
    local pushed = frame.GetPushedTexture and frame:GetPushedTexture() or nil
    local highlight = frame.GetHighlightTexture and frame:GetHighlightTexture() or nil
    local disabled = frame.GetDisabledTexture and frame:GetDisabledTexture() or nil

    SetTextureColor(normal, BUTTON_RED)
    SetTextureColor(pushed, BUTTON_RED_DARK)
    SetTextureColor(highlight, BUTTON_RED_HIGHLIGHT)
    SetTextureColor(disabled, BUTTON_RED_DISABLED)
end

local function StyleDropdown(dropdown)
    if not dropdown then
        return
    end

    ApplyTextStyle(dropdown.label, "label", 12, 1)
    if dropdown.text and dropdown.text.SetTextColor then
        dropdown.text:SetTextColor(VALUE_TEXT[1], VALUE_TEXT[2], VALUE_TEXT[3], 1)
    end

    if dropdown.dropdown then
        local name = dropdown.dropdown:GetName()
        if name then
            SetTextureColor(_G[name .. "Left"], FIELD_BORDER)
            SetTextureColor(_G[name .. "Middle"], FIELD_BACKGROUND)
            SetTextureColor(_G[name .. "Right"], FIELD_BORDER)
        end
    end

    if dropdown.button then
        local buttonNormal = dropdown.button.GetNormalTexture and dropdown.button:GetNormalTexture() or nil
        local buttonPushed = dropdown.button.GetPushedTexture and dropdown.button:GetPushedTexture() or nil
        local buttonHighlight = dropdown.button.GetHighlightTexture and dropdown.button:GetHighlightTexture() or nil
        SetTextureColor(buttonNormal, FIELD_BORDER)
        SetTextureColor(buttonPushed, BUTTON_RED_DARK)
        SetTextureColor(buttonHighlight, BUTTON_RED_HIGHLIGHT)
    end
end

local function StyleEditBox(editBox)
    if not editBox then
        return
    end

    ApplyTextStyle(editBox.label, "label", 12, 1)

    if editBox.editbox then
        if editBox.editbox.SetTextColor then
            editBox.editbox:SetTextColor(VALUE_TEXT[1], VALUE_TEXT[2], VALUE_TEXT[3], 1)
        end

        for _, region in ipairs({ editBox.editbox:GetRegions() }) do
            if region and region.GetObjectType and region:GetObjectType() == "Texture" then
                SetTextureColor(region, FIELD_BORDER)
            end
        end
    end
end

local function StyleCheckBox(checkbox, disabled)
    if not checkbox then
        return
    end

    if checkbox.text and checkbox.text.SetTextColor then
        if disabled then
            checkbox.text:SetTextColor(0.50, 0.50, 0.50, 1)
        else
            checkbox.text:SetTextColor(0.94, 0.90, 0.82, 1)
        end
    end

    if TextStyles and TextStyles.ApplyInteractiveWidgetText then
        TextStyles.ApplyInteractiveWidgetText(checkbox, "label", disabled and true or false, { size = 12 })
    end
end

local function ApplyWindowChrome(window)
    if not window or not window.frame then
        return
    end

    local frame = window.frame
    local content = window.content

    if window.titletext then
        ApplyTextStyle(window.titletext, "sectionHeader", 15, 1)
    end

    if not frame._fpPanelFill then
        frame._fpPanelFill = frame:CreateTexture(nil, "ARTWORK")
        frame._fpPanelFill:SetPoint("TOPLEFT", frame, "TOPLEFT", 12, -30)
        frame._fpPanelFill:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -12, 12)
    end
    frame._fpPanelFill:SetColorTexture(unpack(PANEL_BACKGROUND))

    if not frame._fpPanelHeaderFill then
        frame._fpPanelHeaderFill = frame:CreateTexture(nil, "ARTWORK")
        frame._fpPanelHeaderFill:SetPoint("TOPLEFT", frame, "TOPLEFT", 12, -30)
        frame._fpPanelHeaderFill:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -12, -30)
        frame._fpPanelHeaderFill:SetHeight(26)
    end
    frame._fpPanelHeaderFill:SetColorTexture(unpack(PANEL_HEADER))

    local function EnsureBorder(name)
        if not frame[name] then
            frame[name] = frame:CreateTexture(nil, "BORDER")
        end
        frame[name]:SetColorTexture(unpack(PANEL_BORDER))
        frame[name]:Show()
    end

    EnsureBorder("_fpPanelBorderTop")
    frame._fpPanelBorderTop:SetPoint("TOPLEFT", frame, "TOPLEFT", 12, -30)
    frame._fpPanelBorderTop:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -12, -30)
    frame._fpPanelBorderTop:SetHeight(1)

    EnsureBorder("_fpPanelBorderBottom")
    frame._fpPanelBorderBottom:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 12, 12)
    frame._fpPanelBorderBottom:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -12, 12)
    frame._fpPanelBorderBottom:SetHeight(1)

    EnsureBorder("_fpPanelBorderLeft")
    frame._fpPanelBorderLeft:SetPoint("TOPLEFT", frame, "TOPLEFT", 12, -30)
    frame._fpPanelBorderLeft:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 12, 12)
    frame._fpPanelBorderLeft:SetWidth(1)

    EnsureBorder("_fpPanelBorderRight")
    frame._fpPanelBorderRight:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -12, -30)
    frame._fpPanelBorderRight:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -12, 12)
    frame._fpPanelBorderRight:SetWidth(1)

    if content then
        if not content._fpAccent then
            content._fpAccent = content:CreateTexture(nil, "BORDER")
            content._fpAccent:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -2)
            content._fpAccent:SetPoint("TOPRIGHT", content, "TOPRIGHT", 0, -2)
            content._fpAccent:SetHeight(1)
        end
        content._fpAccent:SetColorTexture(0.83, 0.70, 0.30, 0.35)
    end
end

local function CreateActionButton(text, variant, width, fullWidth)
    local button = AceGUI:Create("Button")
    button:SetText(text or "")
    if fullWidth == false and width then
        button:SetWidth(width)
    else
        button:SetFullWidth(true)
    end
    StyleActionButton(button, variant)
    return button
end

local function CreateVerticalGroup(spacing)
    local group = AceGUI:Create("SimpleGroup")
    group:SetFullWidth(true)
    group:SetLayout("Table")
    group:SetUserData("table", {
        columns = {
            { weight = 1 },
        },
        spaceH = 0,
        spaceV = spacing or 8,
        align = "TOPLEFT",
        alignV = "start",
        alignH = "start",
    })
    return group
end

local function CreateTwoColumnGroup(spacing)
    local group = AceGUI:Create("SimpleGroup")
    group:SetFullWidth(true)
    group:SetLayout("Table")
    group:SetUserData("table", {
        columns = {
            { weight = 1 },
            { weight = 1 },
        },
        spaceH = spacing or 24,
        spaceV = 0,
        align = "TOPLEFT",
        alignV = "start",
        alignH = "start",
    })
    return group
end

local function CreateFourColumnGroup(spacing)
    local group = AceGUI:Create("SimpleGroup")
    group:SetFullWidth(true)
    group:SetLayout("Table")
    group:SetUserData("table", {
        columns = {
            { weight = 1 },
            { weight = 1 },
            { weight = 1 },
            { weight = 1 },
        },
        spaceH = spacing or 16,
        spaceV = 0,
        align = "TOPLEFT",
        alignV = "start",
        alignH = "start",
    })
    return group
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
    local usage = {
        [C.Units.PLAYER] = 0,
        [C.Units.TARGET] = 0,
        [C.Units.FOCUS] = 0,
        [C.Units.PET] = 0,
    }

    if type(templateName) ~= "string" or templateName == "" then
        return usage
    end

    local units = ns.db and ns.db.profile and ns.db.profile.Units or {}
    for unitKey, unitConfig in pairs(units or {}) do
        local texts = type(unitConfig) == "table" and unitConfig.Texts or nil
        if type(texts) == "table" and usage[unitKey] ~= nil then
            for _, textConfig in pairs(texts) do
                if type(textConfig) == "table" then
                    if textConfig.templateName == templateName then
                        usage[unitKey] = usage[unitKey] + 1
                    elseif type(textConfig.stateTemplates) == "table" then
                        for _, stateTemplateName in pairs(textConfig.stateTemplates) do
                            if stateTemplateName == templateName then
                                usage[unitKey] = usage[unitKey] + 1
                                break
                            end
                        end
                    end
                end
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
        SetStatus(T("INFO_TEXT_BUILDER_STATUS_SELECT_UNIT", "Select at least one unit."))
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
        statusParts[#statusParts + 1] = (T("INFO_TEXT_BUILDER_STATUS_APPLIED_TO", "Applied to") .. ": " .. table.concat(appliedEntries, ", "))
    end
    if #removedEntries > 0 then
        statusParts[#statusParts + 1] = (T("INFO_TEXT_BUILDER_TEMPLATE_USAGE_UNLINKED", "Template unlinked from") .. ": " .. table.concat(removedEntries, ", "))
    end

    local statusText = table.concat(statusParts, " | ")
    if linkedTemplateName ~= "" and statusText ~= "" then
        statusText = statusText .. " (" .. linkedTemplateName .. ")"
    end
    if statusText == "" then
        statusText = T("INFO_TEXT_BUILDER_STATUS_SELECT_UNIT", "Select at least one unit.")
    end

    SetStatus(statusText)
    SyncDesiredTemplateUsage(context)
    RefreshTemplateUsageState(context)
end

local function RefreshWindowState()
    local context = windowContext
    if not context then
        return
    end

    local hasDB = ns.db and ns.db.profile
    if not hasDB then
        context.templateEdit:SetDisabled(true)
        context.updateButton:SetDisabled(true)
        context.previewValue:SetText(T("INFO_COMMON_UNAVAILABLE", "Diese Ansicht ist im Moment nicht verfuegbar."))
        context.templateSelect:SetList({})
        context.templateSelect:SetDisabled(true)
        context.templateNameEdit:SetDisabled(true)
        context.deleteTemplateButton:SetDisabled(true)
        context.saveButton:SetDisabled(true)
        context.updateTemplateButton:SetDisabled(true)
        context.applyTemplateButton:SetDisabled(true)
        context.libraryHint:SetText(T("INFO_COMMON_UNAVAILABLE", "Diese Ansicht ist im Moment nicht verfuegbar."))
        context.usageHint:SetText(T("INFO_COMMON_UNAVAILABLE", "Diese Ansicht ist im Moment nicht verfuegbar."))
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

    context.libraryHint:SetText(T("INFO_TEXT_BUILDER_LIBRARY_HINT_SHORT", "Vorlagen sichern, aktualisieren oder entfernen."))
    context.usageHint:SetText(T("INFO_TEXT_BUILDER_TEMPLATE_USAGE_HINT_SHORT", "Auswaehlen, dann Vorlage anwenden."))

    local hasSelectedTemplate = type(context.state.selectedTemplate) == "string" and context.state.selectedTemplate ~= ""
    local hasTemplateName = Trim(context.templateNameEdit:GetText() or "") ~= ""
    local hasTemplateText = Trim(context.templateEdit:GetText() or "") ~= ""

    SyncTemplateSelectWidget(context)

    context.deleteTemplateButton:SetDisabled(not hasSelectedTemplate)
    context.saveButton:SetDisabled(not hasTemplateName or not hasTemplateText)
    context.updateTemplateButton:SetDisabled(not hasSelectedTemplate or not hasTemplateName or not hasTemplateText)
    context.applyTemplateButton:SetDisabled(not hasTemplateText)

    RefreshPreview(context)
    RefreshTemplateUsageState(context)

    if context.window and context.window.DoLayout then
        context.window:DoLayout()
    end
end

local function CreateWindowContent(window, state)
    local root = CreateVerticalGroup(14)
    root:SetFullWidth(true)
    root:SetFullHeight(true)
    window:AddChild(root)

    local headerGroup = CreateVerticalGroup(4)
    root:AddChild(headerGroup)

    headerGroup:AddChild(CreateSectionTitle(T("INFO_TEXT_BUILDER_TITLE", "Text Builder"), 18))
    headerGroup:AddChild(CreateBodyText(
        T("INFO_TEXT_BUILDER_DESCRIPTION_SHORT", "Vorlage bauen, Vorschau pruefen, speichern und anwenden."),
        "help",
        11,
        DESCRIPTION_TEXT
    ))

    local templateGroup = CreateVerticalGroup(4)
    root:AddChild(templateGroup)

    templateGroup:AddChild(CreateSectionTitle(T("INFO_TEXT_BUILDER_TEMPLATE", "Vorlage"), 14))
    templateGroup:AddChild(CreateBodyText(
        (T("INFO_TEXT_BUILDER_TEMPLATE_EXAMPLE", "Beispiel:") .. " " .. TEMPLATE_EXAMPLE),
        "help",
        10,
        HINT_TEXT
    ))

    local templateEdit = AceGUI:Create("EditBox")
    templateEdit:SetLabel(T("INFO_TEXT_BUILDER_TEMPLATE", "Vorlage"))
    templateEdit:SetFullWidth(true)
    templateEdit:DisableButton(true)
    templateEdit:SetText(NormalizeTemplateInput(state.template or ""))
    StyleEditBox(templateEdit)
    templateGroup:AddChild(templateEdit)

    local updateButton = CreateActionButton(T("INFO_TEXT_BUILDER_APPLY", "Vorschau aktualisieren"), "primary", 220, false)
    templateGroup:AddChild(updateButton)

    local previewGroup = CreateVerticalGroup(3)
    root:AddChild(previewGroup)

    previewGroup:AddChild(CreateSectionTitle(T("INFO_TEXT_BUILDER_PREVIEW", "Vorschau"), 14))

    local previewValue = CreateBodyText(" ", "highlight", 20, VALUE_TEXT)
    if previewValue.label and previewValue.label.SetJustifyH then
        previewValue.label:SetJustifyH("LEFT")
    end
    previewGroup:AddChild(previewValue)

    previewGroup:AddChild(CreateBodyText(
        T("INFO_TEXT_BUILDER_PREVIEW_HINT_SHORT", "Kurz pruefen, dann speichern oder anwenden."),
        "help",
        10,
        HINT_TEXT
    ))

    local templatesGroup = CreateVerticalGroup(4)
    root:AddChild(templatesGroup)

    templatesGroup:AddChild(CreateSectionTitle(T("INFO_TEXT_BUILDER_TEMPLATES", "Vorlagen"), 14))
    templatesGroup:AddChild(CreateBodyText(
        T("INFO_TEXT_BUILDER_TEMPLATES_HINT_SHORT", "Gespeicherte Vorlagen verwalten."),
        "help",
        10,
        DESCRIPTION_TEXT
    ))

    local templatesColumns = CreateTwoColumnGroup(20)
    templatesGroup:AddChild(templatesColumns)

    local templatesLeft = CreateVerticalGroup(6)
    templatesColumns:AddChild(templatesLeft)

    local templatesRight = CreateVerticalGroup(6)
    templatesColumns:AddChild(templatesRight)

    local templateSelect = AceGUI:Create("Dropdown")
    templateSelect:SetLabel(T("INFO_TEXT_BUILDER_SAVED_TEMPLATES", "Gespeicherte Vorlagen"))
    templateSelect:SetFullWidth(true)
    StyleDropdown(templateSelect)
    templatesLeft:AddChild(templateSelect)

    local templateNameEdit = AceGUI:Create("EditBox")
    templateNameEdit:SetLabel(T("INFO_TEXT_BUILDER_TEMPLATE_NAME", "Vorlagenname"))
    templateNameEdit:SetFullWidth(true)
    templateNameEdit:DisableButton(true)
    templateNameEdit:SetText(state.templateName or "")
    StyleEditBox(templateNameEdit)
    templatesRight:AddChild(templateNameEdit)

    local templatesActions = AceGUI:Create("SimpleGroup")
    templatesActions:SetFullWidth(true)
    templatesActions:SetLayout("Table")
    templatesActions:SetUserData("table", {
        columns = {
            { weight = 1 },
            { weight = 1 },
            { weight = 1 },
        },
        spaceH = 12,
        spaceV = 0,
        align = "TOPLEFT",
        alignV = "start",
        alignH = "start",
    })
    templatesGroup:AddChild(templatesActions)

    local saveButton = CreateActionButton(T("INFO_TEXT_BUILDER_SAVE", "Speichern"), "primary")
    templatesActions:AddChild(saveButton)

    local updateTemplateButton = CreateActionButton(T("INFO_TEXT_BUILDER_UPDATE", "Aktualisieren"), "primary")
    templatesActions:AddChild(updateTemplateButton)

    local deleteTemplateButton = CreateActionButton(T("INFO_TEXT_BUILDER_DELETE", "Loeschen"), "danger")
    templatesActions:AddChild(deleteTemplateButton)

    local libraryHint = CreateBodyText(
        T("INFO_TEXT_BUILDER_LIBRARY_HINT_SHORT", "Vorlagen sichern, aktualisieren oder entfernen."),
        "help",
        10,
        HINT_TEXT
    )
    templatesGroup:AddChild(libraryHint)

    local usageGroup = CreateVerticalGroup(4)
    root:AddChild(usageGroup)

    usageGroup:AddChild(CreateSectionTitle(T("INFO_TEXT_BUILDER_TEMPLATE_USAGE", "Vorlagenverwendung"), 14))
    local usageHint = CreateBodyText(
        T("INFO_TEXT_BUILDER_TEMPLATE_USAGE_HINT_SHORT", "Auswaehlen, dann Vorlage anwenden."),
        "help",
        10,
        DESCRIPTION_TEXT
    )
    usageGroup:AddChild(usageHint)
    usageGroup:AddChild(CreateBodyText(
        T("INFO_TEXT_BUILDER_USAGE_LEAD", "Verknuepfte Units"),
        "label",
        12,
        VALUE_TEXT
    ))

    local usageRow = CreateFourColumnGroup(16)
    usageGroup:AddChild(usageRow)

    local usageCheckboxes = {}
    for _, unitKey in ipairs(UNIT_KEYS) do
        local checkbox = AceGUI:Create("CheckBox")
        checkbox:SetFullWidth(true)
        checkbox:SetLabel(ns.GetLabel and ns.GetLabel(KM.Units, unitKey) or unitKey)
        checkbox:SetValue(false)
        checkbox:SetDisabled(true)
        StyleCheckBox(checkbox, true)
        usageRow:AddChild(checkbox)
        usageCheckboxes[unitKey] = checkbox
    end

    local applyTemplateButton = CreateActionButton(T("INFO_TEXT_BUILDER_APPLY_TEMPLATE", "Vorlage anwenden"), "primary", 220, false)
    usageGroup:AddChild(applyTemplateButton)

    return {
        window = window,
        state = state,
        root = root,
        templateEdit = templateEdit,
        updateButton = updateButton,
        previewValue = previewValue,
        templateSelect = templateSelect,
        templateNameEdit = templateNameEdit,
        deleteTemplateButton = deleteTemplateButton,
        saveButton = saveButton,
        updateTemplateButton = updateTemplateButton,
        libraryHint = libraryHint,
        usageHint = usageHint,
        usageCheckboxes = usageCheckboxes,
        applyTemplateButton = applyTemplateButton,
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
        local templates = GetTemplates()
        local name = Trim(context.templateNameEdit:GetText() or "")
        local template = NormalizeTemplateInput(context.templateEdit:GetText() or "")

        if name == "" then
            SetStatus(T("INFO_TEXT_BUILDER_STATUS_NAME_REQUIRED", "Please enter a template name."))
            return
        end

        templates[name] = template
        context.state.selectedTemplate = name
        context.state.templateName = name
        context.state.template = template
        RefreshTemplateDropdown(context)
        RefreshWindowState()
        SetStatus((T("INFO_TEXT_BUILDER_STATUS_SAVED", "Template saved:")) .. " " .. name)
    end)

    context.updateTemplateButton:SetCallback("OnClick", function()
        local templates = GetTemplates()
        local selectedName = context.state.selectedTemplate or ""
        local updatedName = Trim(context.templateNameEdit:GetText() or "")
        local template = NormalizeTemplateInput(context.templateEdit:GetText() or "")

        if selectedName == "" or type(templates[selectedName]) ~= "string" then
            SetStatus(T("INFO_TEXT_BUILDER_STATUS_SELECT_TEMPLATE", "Select a saved template first."))
            return
        end

        if updatedName == "" then
            SetStatus(T("INFO_TEXT_BUILDER_STATUS_NAME_REQUIRED", "Please enter a template name."))
            return
        end

        if updatedName ~= selectedName and type(templates[updatedName]) == "string" then
            SetStatus((T("INFO_TEXT_BUILDER_STATUS_NAME_EXISTS", "A template with this name already exists:")) .. " " .. updatedName)
            return
        end

        if updatedName ~= selectedName then
            templates[updatedName] = template
            templates[selectedName] = nil
            RenameTemplateReferences(selectedName, updatedName)
            context.state.selectedTemplate = updatedName
            context.state.templateName = updatedName
            context.state.template = template
            RefreshTemplateDropdown(context)
            RefreshWindowState()
            SetStatus((T("INFO_TEXT_BUILDER_STATUS_UPDATED", "Template updated:")) .. " " .. updatedName)
            return
        end

        templates[selectedName] = template
        context.state.template = template
        context.state.templateName = selectedName
        RefreshTemplateDropdown(context)
        RefreshWindowState()
        SetStatus((T("INFO_TEXT_BUILDER_STATUS_UPDATED", "Template updated:")) .. " " .. selectedName)
    end)

    context.deleteTemplateButton:SetCallback("OnClick", function()
        local templates = GetTemplates()
        local selectedName = context.state.selectedTemplate or ""

        if selectedName == "" or type(templates[selectedName]) ~= "string" then
            SetStatus(T("INFO_TEXT_BUILDER_STATUS_SELECT_TEMPLATE", "Select a saved template first."))
            return
        end

        templates[selectedName] = nil
        context.state.selectedTemplate = ""
        context.state.templateName = ""
        RefreshTemplateDropdown(context)
        RefreshWindowState()
        SetStatus((T("INFO_TEXT_BUILDER_STATUS_DELETED", "Template deleted:")) .. " " .. selectedName)
    end)

    context.applyTemplateButton:SetCallback("OnClick", function()
        ApplyTemplateToTextElement(context)
    end)
end

local function CreateWindow(state)
    local window = AceGUI:Create("Window")
    window:SetTitle(T("INFO_TEXT_BUILDER_TITLE", "Text Builder"))
    window:SetLayout("Fill")
    window:SetWidth(980)
    window:SetHeight(660)
    window:EnableResize(false)

    if window.frame then
        window.frame:SetClampedToScreen(true)
    end

    ApplyWindowChrome(window)
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

function TextBuilderPage.OpenWindow(deps)
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

function TextBuilderPage.HideWindow()
    if not windowContext or not windowContext.window then
        return
    end

    if windowContext.window.Hide then
        windowContext.window:Hide()
    elseif windowContext.window.frame and windowContext.window.frame.Hide then
        windowContext.window.frame:Hide()
    end
end

function TextBuilderPage.Build(container, deps)
    if container and container.ReleaseChildren then
        container:ReleaseChildren()
    end
    if container and container.SetLayout then
        container:SetLayout("Fill")
    end

    TextBuilderPage.OpenWindow(deps)
end

return TextBuilderPage
