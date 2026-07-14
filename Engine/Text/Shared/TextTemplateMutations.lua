local _, FocalPoint = ...

FocalPoint.TextTemplateMutations = FocalPoint.TextTemplateMutations or {}

local Mutations = FocalPoint.TextTemplateMutations

local function ResolveLibrary()
    return FocalPoint.TextTemplateLibrary
end

local function GetCurrentProfileName(db)
    local library = ResolveLibrary()
    return library and library.GetCurrentProfileName and library.GetCurrentProfileName(db) or nil
end

local function GetProfileByName(db, profileName)
    local library = ResolveLibrary()
    return library and library.GetProfileByName and library.GetProfileByName(db, profileName) or nil
end

local function FindTemplateEntry(db, selection)
    local library = ResolveLibrary()
    return library and library.FindTemplateEntry and library.FindTemplateEntry(db, selection) or nil
end

local function BuildCopyName(baseName, suffix)
    if suffix == 1 then
        return baseName .. " (Copy)"
    end

    return baseName .. " (Copy " .. tostring(suffix) .. ")"
end

local function ResolveTargetTemplateName(templates, templateName, templateValue)
    if type(templates) ~= "table" or type(templateName) ~= "string" or templateName == "" or type(templateValue) ~= "string" then
        return nil, false, false
    end

    local existingValue = templates[templateName]
    if existingValue == nil then
        return templateName, false, true
    end

    if existingValue == templateValue then
        return templateName, true, false
    end

    local suffix = 1
    while true do
        local candidate = BuildCopyName(templateName, suffix)
        local candidateValue = templates[candidate]
        if candidateValue == nil then
            return candidate, false, true
        end
        if candidateValue == templateValue then
            return candidate, true, false
        end
        suffix = suffix + 1
    end
end

local function Result(ok, fields)
    fields = fields or {}
    fields.ok = ok and true or false
    if fields.success == nil then
        fields.success = fields.ok
    end
    return fields
end

local function IsNonEmptyString(value)
    return type(value) == "string" and value ~= ""
end

local function GetTemplatesFromContext(context)
    if type(context) ~= "table" or type(context.GetTemplates) ~= "function" then
        return nil
    end

    local ok, templates = pcall(context.GetTemplates)
    if ok and type(templates) == "table" then
        return templates
    end

    return nil
end

local function GetUnitsFromContext(context)
    if type(context) ~= "table" then
        return nil
    end

    if type(context.GetUnits) == "function" then
        local ok, units = pcall(context.GetUnits)
        if ok and type(units) == "table" then
            return units
        end
    end

    return nil
end

local function GetUnitConfigFromContext(context, unitKey)
    if type(context) ~= "table" or not IsNonEmptyString(unitKey) then
        return nil
    end

    if type(context.GetUnitConfig) == "function" then
        local ok, unitConfig = pcall(context.GetUnitConfig, unitKey)
        if ok and type(unitConfig) == "table" then
            return unitConfig
        end
        return nil
    end

    local units = GetUnitsFromContext(context)
    local unitConfig = units and units[unitKey] or nil
    return type(unitConfig) == "table" and unitConfig or nil
end

local function GetTextConfig(context, unitKey, textKey)
    local unitConfig = GetUnitConfigFromContext(context, unitKey)
    local texts = unitConfig and unitConfig.Texts or nil
    local textConfig = type(texts) == "table" and texts[textKey] or nil
    return type(textConfig) == "table" and textConfig or nil, texts, unitConfig
end

local function IsDynamicTextKey(textKey)
    return type(textKey) == "string" and (textKey:match("^text_%d+$") ~= nil or textKey:match("^Custom%d+$") ~= nil)
end

local function HasNonEmptyStateTemplates(stateTemplates)
    if type(stateTemplates) ~= "table" then
        return false
    end

    for _, templateName in pairs(stateTemplates) do
        if IsNonEmptyString(templateName) then
            return true
        end
    end

    return false
end

local function RemoveTemplateReferencesFromTextConfig(textConfig, templateName)
    if type(textConfig) ~= "table" or not IsNonEmptyString(templateName) then
        return false
    end

    local changed = false
    if textConfig.templateName == templateName then
        textConfig.templateName = ""
        changed = true
    end

    if type(textConfig.stateTemplates) == "table" then
        for stateKey, stateTemplateName in pairs(textConfig.stateTemplates) do
            if stateTemplateName == templateName then
                textConfig.stateTemplates[stateKey] = ""
                changed = true
            end
        end
    end

    return changed
end

local function RemovePrimaryTemplateReference(textConfig, templateName)
    if type(textConfig) ~= "table" or not IsNonEmptyString(templateName) or textConfig.templateName ~= templateName then
        return false
    end

    textConfig.templateName = ""
    return true
end

local function RemoveStateTemplateReference(textConfig, stateKey, templateName)
    if type(textConfig) ~= "table" or not IsNonEmptyString(stateKey) or type(textConfig.stateTemplates) ~= "table" then
        return false
    end
    if not IsNonEmptyString(templateName) or textConfig.stateTemplates[stateKey] ~= templateName then
        return false
    end

    textConfig.stateTemplates[stateKey] = nil
    if next(textConfig.stateTemplates) == nil then
        textConfig.stateTemplates = nil
    end
    return true
end

local function HasIndependentTextContent(textConfig)
    if type(textConfig) ~= "table" then
        return false
    end

    if IsNonEmptyString(textConfig.templateName) or HasNonEmptyStateTemplates(textConfig.stateTemplates) then
        return true
    end

    if IsNonEmptyString(textConfig.tag) then
        return true
    end

    return false
end

local function ShouldRemoveGeneratedTextElement(textKey, textConfig, removedTemplateText)
    if not IsDynamicTextKey(textKey) or type(textConfig) ~= "table" then
        return false
    end

    if IsNonEmptyString(textConfig.templateName) or HasNonEmptyStateTemplates(textConfig.stateTemplates) then
        return false
    end

    return not IsNonEmptyString(textConfig.tag) or textConfig.tag == removedTemplateText
end

local function CleanupUnassignedTextElement(texts, textKey, textConfig, removedTemplateText)
    if type(texts) ~= "table" or type(textConfig) ~= "table" then
        return false, nil
    end

    if ShouldRemoveGeneratedTextElement(textKey, textConfig, removedTemplateText) then
        texts[textKey] = nil
        return true, "removed"
    end

    if not HasIndependentTextContent(textConfig) then
        local changed = textConfig.enabled ~= false
        textConfig.enabled = false
        return changed, "disabled"
    end

    return false, nil
end

local function RemoveTemplateReferenceAndCleanup(texts, textKey, textConfig, templateName, removedTemplateText, removeMode, stateKey)
    local removedReference = false
    if removeMode == "primary" then
        removedReference = RemovePrimaryTemplateReference(textConfig, templateName)
    elseif removeMode == "state" then
        removedReference = RemoveStateTemplateReference(textConfig, stateKey, templateName)
    else
        removedReference = RemoveTemplateReferencesFromTextConfig(textConfig, templateName)
    end

    if not removedReference then
        return false, nil
    end

    local _, cleanupAction = CleanupUnassignedTextElement(texts, textKey, textConfig, removedTemplateText)
    return true, cleanupAction
end

function Mutations.BuildTextElementConfig(template, linkedTemplateName)
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

function Mutations.GetNextTextKey(context, unitKey)
    local unitConfig = GetUnitConfigFromContext(context, unitKey)
    local texts = unitConfig and unitConfig.Texts or nil
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

local function ValidateTemplateName(templateName)
    if not IsNonEmptyString(templateName) then
        return false
    end
    return true
end

local function ValidateTemplateText(templateText)
    return type(templateText) == "string"
end

local function ForEachTemplateReference(context, templateName, callback)
    local usage = FocalPoint.TextTemplateUsage
    local references = usage and usage.FindReferences and usage.FindReferences(context, templateName) or {}
    if type(references) ~= "table" then
        return 0
    end

    local processed = 0
    local unresolved = 0
    for _, reference in ipairs(references) do
        local textConfig = GetTextConfig(context, reference.unitKey, reference.textKey)
        if callback and type(textConfig) == "table" then
            local field = reference.referenceKind == "state" and "stateTemplates" or "templateName"
            callback(reference.unitKey, reference.textKey, textConfig, field, reference.stateKey)
            processed = processed + 1
        elseif callback then
            unresolved = unresolved + 1
        end
    end

    if callback then
        return processed, unresolved
    end
    return #references, 0
end

function Mutations.CountTemplateReferences(context, templateName)
    local usage = FocalPoint.TextTemplateUsage
    if usage and usage.CountReferences then
        return usage.CountReferences(context, templateName)
    end

    return ForEachTemplateReference(context, templateName, nil)
end

function Mutations.CreateProfileContext(profile)
    if type(profile) ~= "table" then
        return nil
    end

    return {
        GetTemplates = function()
            profile.TextTemplates = type(profile.TextTemplates) == "table" and profile.TextTemplates or {}
            return profile.TextTemplates
        end,
        GetUnits = function()
            return type(profile.Units) == "table" and profile.Units or nil
        end,
        GetUnitConfig = function(unitKey)
            return type(profile.Units) == "table" and profile.Units[unitKey] or nil
        end,
    }
end

function Mutations.CreateTemplate(context, templateName, templateText)
    if not ValidateTemplateName(templateName) then
        return Result(false, { errorCode = "invalid_template_name" })
    end
    if not ValidateTemplateText(templateText) then
        return Result(false, { errorCode = "invalid_template_text" })
    end

    local templates = GetTemplatesFromContext(context)
    if type(templates) ~= "table" then
        return Result(false, { errorCode = "invalid_context" })
    end
    if templates[templateName] ~= nil then
        return Result(false, { errorCode = "template_name_exists", templateName = templateName })
    end

    templates[templateName] = templateText
    return Result(true, { templateName = templateName, changed = true })
end

function Mutations.UpdateTemplate(context, templateName, templateText)
    if not ValidateTemplateName(templateName) then
        return Result(false, { errorCode = "invalid_template_name" })
    end
    if not ValidateTemplateText(templateText) then
        return Result(false, { errorCode = "invalid_template_text" })
    end

    local templates = GetTemplatesFromContext(context)
    if type(templates) ~= "table" then
        return Result(false, { errorCode = "invalid_context" })
    end
    if type(templates[templateName]) ~= "string" then
        return Result(false, { errorCode = "template_not_found", templateName = templateName })
    end

    local changed = templates[templateName] ~= templateText
    templates[templateName] = templateText
    return Result(true, { templateName = templateName, changed = changed })
end

function Mutations.RenameTemplate(context, oldName, newName, templateText)
    if not ValidateTemplateName(oldName) or not ValidateTemplateName(newName) then
        return Result(false, { errorCode = "invalid_template_name" })
    end
    if templateText ~= nil and not ValidateTemplateText(templateText) then
        return Result(false, { errorCode = "invalid_template_text" })
    end
    if oldName == newName then
        return Result(true, { templateName = oldName, changed = false, affectedReferences = 0 })
    end

    local templates = GetTemplatesFromContext(context)
    if type(templates) ~= "table" then
        return Result(false, { errorCode = "invalid_context" })
    end
    if type(templates[oldName]) ~= "string" then
        return Result(false, { errorCode = "template_not_found", templateName = oldName })
    end
    if templates[newName] ~= nil then
        return Result(false, { errorCode = "template_name_exists", templateName = newName })
    end

    local references = {}
    local affected, unresolved = ForEachTemplateReference(context, oldName, function(unitKey, textKey, textConfig, field, stateKey)
        references[#references + 1] = {
            textConfig = textConfig,
            field = field,
            stateKey = stateKey,
        }
    end)
    if unresolved and unresolved > 0 then
        return Result(false, { errorCode = "invalid_context", templateName = oldName })
    end

    templates[newName] = templateText ~= nil and templateText or templates[oldName]
    templates[oldName] = nil
    for _, reference in ipairs(references) do
        if reference.field == "templateName" then
            reference.textConfig.templateName = newName
        elseif reference.field == "stateTemplates" and type(reference.textConfig.stateTemplates) == "table" then
            reference.textConfig.stateTemplates[reference.stateKey] = newName
        end
    end

    return Result(true, { templateName = newName, oldName = oldName, changed = true, affectedReferences = affected })
end

function Mutations.DeleteTemplate(context, templateName)
    if not ValidateTemplateName(templateName) then
        return Result(false, { errorCode = "invalid_template_name" })
    end

    local templates = GetTemplatesFromContext(context)
    if type(templates) ~= "table" then
        return Result(false, { errorCode = "invalid_context" })
    end
    if type(templates[templateName]) ~= "string" then
        return Result(false, { errorCode = "template_not_found", templateName = templateName })
    end

    local affected = ForEachTemplateReference(context, templateName, nil)
    if affected > 0 then
        return Result(false, { errorCode = "template_in_use", templateName = templateName, affectedReferences = affected })
    end

    templates[templateName] = nil
    return Result(true, { templateName = templateName, changed = true, affectedReferences = 0 })
end

function Mutations.CopyTemplate(sourceContext, targetContext, sourceName, targetName)
    if not ValidateTemplateName(sourceName) or not ValidateTemplateName(targetName) then
        return Result(false, { errorCode = "invalid_template_name" })
    end

    local sourceTemplates = GetTemplatesFromContext(sourceContext)
    local targetTemplates = GetTemplatesFromContext(targetContext)
    if type(sourceTemplates) ~= "table" or type(targetTemplates) ~= "table" then
        return Result(false, { errorCode = "invalid_context" })
    end

    local templateText = sourceTemplates[sourceName]
    if type(templateText) ~= "string" then
        return Result(false, { errorCode = "template_not_found", templateName = sourceName })
    end
    if targetTemplates[targetName] ~= nil then
        return Result(false, { errorCode = "template_name_exists", templateName = targetName })
    end

    targetTemplates[targetName] = templateText
    return Result(true, { sourceName = sourceName, templateName = targetName, templateValue = templateText, changed = true })
end

function Mutations.AssignTemplate(context, unitKey, textKey, templateName)
    if not ValidateTemplateName(templateName) then
        return Result(false, { errorCode = "invalid_template_name" })
    end

    local templates = GetTemplatesFromContext(context)
    if type(templates) ~= "table" then
        return Result(false, { errorCode = "invalid_context" })
    end
    if type(templates[templateName]) ~= "string" then
        return Result(false, { errorCode = "template_not_found", templateName = templateName })
    end

    local textConfig, _, unitConfig = GetTextConfig(context, unitKey, textKey)
    if not unitConfig then
        return Result(false, { errorCode = "unit_not_found", unitKey = unitKey })
    end
    if not textConfig then
        return Result(false, { errorCode = "text_element_not_found", unitKey = unitKey, textKey = textKey })
    end

    local changed = textConfig.templateName ~= templateName
    textConfig.templateName = templateName
    return Result(true, { templateName = templateName, unitKey = unitKey, textKey = textKey, changed = changed })
end

function Mutations.UnassignTemplate(context, unitKey, textKey)
    local textConfig, texts, unitConfig = GetTextConfig(context, unitKey, textKey)
    if not unitConfig then
        return Result(false, { errorCode = "unit_not_found", unitKey = unitKey })
    end
    if not textConfig then
        return Result(false, { errorCode = "text_element_not_found", unitKey = unitKey, textKey = textKey })
    end

    local templateName = textConfig.templateName
    if not IsNonEmptyString(templateName) then
        return Result(true, { unitKey = unitKey, textKey = textKey, changed = false })
    end

    local templates = GetTemplatesFromContext(context) or {}
    local templateText = templates[templateName]
    local changed, cleanupAction = RemoveTemplateReferenceAndCleanup(texts, textKey, textConfig, templateName, templateText, "primary")
    return Result(true, {
        templateName = templateName,
        unitKey = unitKey,
        textKey = textKey,
        changed = changed,
        cleanupAction = cleanupAction,
    })
end

function Mutations.AssignStateTemplate(context, unitKey, textKey, stateKey, templateName)
    if not IsNonEmptyString(stateKey) then
        return Result(false, { errorCode = "state_key_invalid" })
    end
    if not ValidateTemplateName(templateName) then
        return Result(false, { errorCode = "invalid_template_name" })
    end

    local templates = GetTemplatesFromContext(context)
    if type(templates) ~= "table" then
        return Result(false, { errorCode = "invalid_context" })
    end
    if type(templates[templateName]) ~= "string" then
        return Result(false, { errorCode = "template_not_found", templateName = templateName })
    end

    local textConfig, _, unitConfig = GetTextConfig(context, unitKey, textKey)
    if not unitConfig then
        return Result(false, { errorCode = "unit_not_found", unitKey = unitKey })
    end
    if not textConfig then
        return Result(false, { errorCode = "text_element_not_found", unitKey = unitKey, textKey = textKey })
    end

    textConfig.stateTemplates = type(textConfig.stateTemplates) == "table" and textConfig.stateTemplates or {}
    local changed = textConfig.stateTemplates[stateKey] ~= templateName
    textConfig.stateTemplates[stateKey] = templateName
    return Result(true, { templateName = templateName, unitKey = unitKey, textKey = textKey, stateKey = stateKey, changed = changed })
end

function Mutations.UnassignStateTemplate(context, unitKey, textKey, stateKey)
    if not IsNonEmptyString(stateKey) then
        return Result(false, { errorCode = "state_key_invalid" })
    end

    local textConfig, texts, unitConfig = GetTextConfig(context, unitKey, textKey)
    if not unitConfig then
        return Result(false, { errorCode = "unit_not_found", unitKey = unitKey })
    end
    if not textConfig then
        return Result(false, { errorCode = "text_element_not_found", unitKey = unitKey, textKey = textKey })
    end
    if type(textConfig.stateTemplates) ~= "table" then
        return Result(true, { unitKey = unitKey, textKey = textKey, stateKey = stateKey, changed = false })
    end

    local templateName = textConfig.stateTemplates[stateKey]
    if not IsNonEmptyString(templateName) then
        local changed = textConfig.stateTemplates[stateKey] ~= nil
        textConfig.stateTemplates[stateKey] = nil
        if next(textConfig.stateTemplates) == nil then
            textConfig.stateTemplates = nil
        end
        return Result(true, { unitKey = unitKey, textKey = textKey, stateKey = stateKey, changed = changed })
    end

    local templates = GetTemplatesFromContext(context) or {}
    local templateText = templates[templateName]
    local changed, cleanupAction = RemoveTemplateReferenceAndCleanup(texts, textKey, textConfig, templateName, templateText, "state", stateKey)
    return Result(true, {
        templateName = templateName,
        unitKey = unitKey,
        textKey = textKey,
        stateKey = stateKey,
        changed = changed,
        cleanupAction = cleanupAction,
    })
end

function Mutations.ApplyTemplateToUnits(context, options)
    if type(options) ~= "table" or not ValidateTemplateName(options.selectedTemplateName) then
        return Result(false, { errorCode = "invalid_template_name" })
    end

    local templates = GetTemplatesFromContext(context)
    if type(templates) ~= "table" then
        return Result(false, { errorCode = "invalid_context" })
    end
    if type(templates[options.selectedTemplateName]) ~= "string" then
        return Result(false, { errorCode = "template_not_found", templateName = options.selectedTemplateName })
    end
    local selectedTemplateText = templates[options.selectedTemplateName]

    local appliedUnits = {}
    local removedUnits = {}

    for _, unitKey in ipairs(type(options.unitsToAdd) == "table" and options.unitsToAdd or {}) do
        local unitConfig = GetUnitConfigFromContext(context, unitKey)
        if type(unitConfig) == "table" then
            unitConfig.Texts = unitConfig.Texts or {}
            local textKey = type(context.GetNextTextKey) == "function" and context.GetNextTextKey(unitKey) or Mutations.GetNextTextKey(context, unitKey)
            local textConfig = type(context.CreateTextConfig) == "function"
                and context.CreateTextConfig(unitKey, options.templateText or "", options.linkedTemplateName or "")
                or Mutations.BuildTextElementConfig(options.templateText or "", options.linkedTemplateName or "")
            if IsNonEmptyString(textKey) and type(textConfig) == "table" then
                unitConfig.Texts[textKey] = textConfig
                appliedUnits[#appliedUnits + 1] = unitKey
            end
        end
    end

    for _, unitKey in ipairs(type(options.unitsToRemove) == "table" and options.unitsToRemove or {}) do
        local unitConfig = GetUnitConfigFromContext(context, unitKey)
        local texts = unitConfig and unitConfig.Texts or nil
        local unitChanged = false
        if type(texts) == "table" then
            for textId, textConfig in pairs(texts) do
                if type(textConfig) == "table" then
                    local matched = textConfig.templateName == options.selectedTemplateName
                    if not matched and type(textConfig.stateTemplates) == "table" then
                        for _, stateTemplateName in pairs(textConfig.stateTemplates) do
                            if stateTemplateName == options.selectedTemplateName then
                                matched = true
                                break
                            end
                        end
                    end

                    if matched then
                        RemoveTemplateReferenceAndCleanup(texts, textId, textConfig, options.selectedTemplateName, selectedTemplateText, "all")
                        unitChanged = true
                    end
                end
            end
        end
        if unitChanged then
            removedUnits[#removedUnits + 1] = unitKey
        end
    end

    return Result(true, {
        templateName = options.selectedTemplateName,
        linkedTemplateName = options.linkedTemplateName,
        appliedUnits = appliedUnits,
        removedUnits = removedUnits,
        changed = #appliedUnits > 0 or #removedUnits > 0,
    })
end

function Mutations.CopyTemplateEntryToProfile(db, sourceEntry, targetProfileName)
    db = db or FocalPoint.db
    if type(sourceEntry) ~= "table" or sourceEntry.sourceType ~= "profile" then
        return { success = false, reason = "invalid_source" }
    end

    local currentProfileName = GetCurrentProfileName(db)
    if type(targetProfileName) ~= "string" or targetProfileName == "" then
        targetProfileName = currentProfileName
    end
    if type(currentProfileName) ~= "string" or currentProfileName == "" or targetProfileName ~= currentProfileName then
        return { success = false, reason = "invalid_target" }
    end

    local sourceProfileName = sourceEntry.profileName or sourceEntry.sourceId
    local sourceTemplateName = sourceEntry.templateName
    if type(sourceProfileName) ~= "string" or sourceProfileName == "" or type(sourceTemplateName) ~= "string" or sourceTemplateName == "" then
        return { success = false, reason = "invalid_source" }
    end

    local resolvedSource = FindTemplateEntry(db, {
        sourceType = "profile",
        sourceId = sourceProfileName,
        profileName = sourceProfileName,
        templateName = sourceTemplateName,
    })
    if not resolvedSource or type(resolvedSource.templateValue) ~= "string" then
        return { success = false, reason = "source_missing" }
    end

    local targetProfile = GetProfileByName(db, targetProfileName)
    if type(targetProfile) ~= "table" or targetProfile ~= db.profile then
        return { success = false, reason = "invalid_target" }
    end

    targetProfile.TextTemplates = targetProfile.TextTemplates or {}
    local targetTemplates = targetProfile.TextTemplates
    local targetTemplateName, reusedExisting, createdNew = ResolveTargetTemplateName(
        targetTemplates,
        resolvedSource.templateName,
        resolvedSource.templateValue
    )
    if type(targetTemplateName) ~= "string" or targetTemplateName == "" then
        return { success = false, reason = "copy_failed" }
    end

    if createdNew then
        targetTemplates[targetTemplateName] = resolvedSource.templateValue
    end

    return {
        success = true,
        sourceProfileName = sourceProfileName,
        sourceTemplateName = resolvedSource.templateName,
        targetProfileName = targetProfileName,
        targetTemplateName = targetTemplateName,
        templateValue = resolvedSource.templateValue,
        reusedExisting = reusedExisting and true or false,
        createdNew = createdNew and true or false,
    }
end

function Mutations.CopyProfileTemplateToProfile(db, sourceProfileName, templateName, targetProfileName)
    return Mutations.CopyTemplateEntryToProfile(db, {
        sourceType = "profile",
        sourceId = sourceProfileName,
        profileName = sourceProfileName,
        templateName = templateName,
    }, targetProfileName)
end

return Mutations
