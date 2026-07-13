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
