local _, FocalPoint = ...

FocalPoint.TextTemplateUsage = FocalPoint.TextTemplateUsage or {}

local Usage = FocalPoint.TextTemplateUsage

local function SortKeys(left, right)
    local leftType = type(left)
    local rightType = type(right)
    if leftType ~= rightType then
        return leftType < rightType
    end
    return tostring(left) < tostring(right)
end

local function SortedKeys(source)
    local keys = {}
    if type(source) ~= "table" then
        return keys
    end

    for key in pairs(source) do
        keys[#keys + 1] = key
    end
    table.sort(keys, SortKeys)
    return keys
end

local function GetProfileName(db)
    if not db or type(db.GetCurrentProfile) ~= "function" then
        return nil
    end

    local ok, profileName = pcall(db.GetCurrentProfile, db)
    if ok and type(profileName) == "string" and profileName ~= "" then
        return profileName
    end
    return nil
end

local function AddUsage(usages, profileName, templates, unitKey, textId, textConfig, templateName, referenceType, stateKey)
    if type(templateName) ~= "string" or templateName == "" then
        return
    end

    local templateValue = type(templates) == "table" and templates[templateName] or nil
    local existsInActiveProfile = type(templateValue) == "string"

    usages[#usages + 1] = {
        profileName = profileName,
        unit = unitKey,
        textId = textId,
        anchorTo = textConfig.anchorTo,
        role = textConfig.role,
        templateName = templateName,
        referenceType = referenceType,
        isPrimary = referenceType == "templateName",
        isState = referenceType == "stateTemplates",
        stateKey = stateKey,
        tag = textConfig.tag,
        enabled = textConfig.enabled,
        existsInActiveProfile = existsInActiveProfile,
        isMissing = not existsInActiveProfile,
        templateValue = existsInActiveProfile and templateValue or nil,
    }
end

function Usage.ScanActiveProfileTemplateAssignments(db)
    db = db or FocalPoint.db
    local profile = db and db.profile
    if type(profile) ~= "table" then
        return {}
    end

    local templates = type(profile.TextTemplates) == "table" and profile.TextTemplates or {}
    local units = type(profile.Units) == "table" and profile.Units or {}
    local profileName = GetProfileName(db)
    local usages = {}

    for _, unitKey in ipairs(SortedKeys(units)) do
        local unitConfig = units[unitKey]
        local texts = type(unitConfig) == "table" and unitConfig.Texts or nil
        if type(texts) == "table" then
            for _, textId in ipairs(SortedKeys(texts)) do
                local textConfig = texts[textId]
                if type(textConfig) == "table" then
                    AddUsage(usages, profileName, templates, unitKey, textId, textConfig, textConfig.templateName, "templateName", nil)

                    if type(textConfig.stateTemplates) == "table" then
                        for _, stateKey in ipairs(SortedKeys(textConfig.stateTemplates)) do
                            AddUsage(
                                usages,
                                profileName,
                                templates,
                                unitKey,
                                textId,
                                textConfig,
                                textConfig.stateTemplates[stateKey],
                                "stateTemplates",
                                stateKey
                            )
                        end
                    end
                end
            end
        end
    end

    return usages
end

Usage.GetActiveProfileTemplateUsages = Usage.ScanActiveProfileTemplateAssignments

function Usage.GetActiveProfileTemplateUsageSummary(db)
    db = db or FocalPoint.db
    local profile = db and db.profile
    local templates = profile and type(profile.TextTemplates) == "table" and profile.TextTemplates or {}
    local usages = Usage.ScanActiveProfileTemplateAssignments(db)
    local usedTemplates = {}
    local missingTemplates = {}
    local missingReferenceCount = 0

    for _, entry in ipairs(usages) do
        local templateName = entry.templateName
        if type(templateName) == "string" and templateName ~= "" then
            usedTemplates[templateName] = (usedTemplates[templateName] or 0) + 1
            if entry.isMissing then
                missingTemplates[templateName] = (missingTemplates[templateName] or 0) + 1
                missingReferenceCount = missingReferenceCount + 1
            end
        end
    end

    local usedTemplateNames = SortedKeys(usedTemplates)
    local missingTemplateNames = SortedKeys(missingTemplates)
    local unusedTemplateNames = {}

    for _, templateName in ipairs(SortedKeys(templates)) do
        if usedTemplates[templateName] == nil then
            unusedTemplateNames[#unusedTemplateNames + 1] = templateName
        end
    end

    return {
        usages = usages,
        usedTemplates = usedTemplates,
        usedTemplateNames = usedTemplateNames,
        missingTemplates = missingTemplates,
        missingTemplateNames = missingTemplateNames,
        missingReferenceCount = missingReferenceCount,
        unusedTemplateNames = unusedTemplateNames,
    }
end

return Usage
