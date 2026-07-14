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

local function IsNonEmptyString(value)
    return type(value) == "string" and value ~= ""
end

local function SafeCall(method, ...)
    if type(method) ~= "function" then
        return nil
    end

    local ok, result = pcall(method, ...)
    if ok then
        return result
    end
    return nil
end

local function GetTemplatesFromContext(context)
    if type(context) ~= "table" then
        return nil
    end

    local templates = SafeCall(context.GetTemplates)
    return type(templates) == "table" and templates or nil
end

local function GetUnitsFromContext(context)
    if type(context) ~= "table" then
        return nil
    end

    local units = SafeCall(context.GetUnits)
    return type(units) == "table" and units or nil
end

local function GetProfileNameFromContext(context)
    if type(context) ~= "table" then
        return nil
    end

    local profileName = SafeCall(context.GetProfileName)
    return IsNonEmptyString(profileName) and profileName or nil
end

function Usage.CreateProfileContext(profile, profileName)
    if type(profile) ~= "table" then
        return nil
    end

    return {
        GetProfileName = function()
            return profileName
        end,
        GetTemplates = function()
            return type(profile.TextTemplates) == "table" and profile.TextTemplates or nil
        end,
        GetUnits = function()
            return type(profile.Units) == "table" and profile.Units or nil
        end,
        GetUnitConfig = function(unitKey)
            return type(profile.Units) == "table" and profile.Units[unitKey] or nil
        end,
    }
end

local function BuildReference(context, templates, unitKey, textKey, textConfig, referenceKind, templateName, stateKey)
    if not IsNonEmptyString(templateName) then
        return nil
    end

    local templateValue = type(templates) == "table" and templates[templateName] or nil
    local existsInProfile = type(templateValue) == "string"
    local referenceType = referenceKind == "state" and "stateTemplates" or "templateName"

    return {
        profileName = GetProfileNameFromContext(context),
        unitKey = unitKey,
        textKey = textKey,
        referenceKind = referenceKind,
        stateKey = stateKey,
        templateName = templateName,
        anchorTo = type(textConfig) == "table" and textConfig.anchorTo or nil,
        role = type(textConfig) == "table" and textConfig.role or nil,
        tag = type(textConfig) == "table" and textConfig.tag or nil,
        enabled = type(textConfig) == "table" and textConfig.enabled or nil,
        existsInProfile = existsInProfile,
        isMissing = not existsInProfile,
        templateValue = existsInProfile and templateValue or nil,

        -- Compatibility fields for older editor/inspector callers.
        unit = unitKey,
        textId = textKey,
        referenceType = referenceType,
        isPrimary = referenceKind == "template",
        isState = referenceKind == "state",
        existsInActiveProfile = existsInProfile,
    }
end

local function SortReferences(left, right)
    local fields = { "unitKey", "textKey", "referenceKind", "stateKey", "templateName" }
    for _, field in ipairs(fields) do
        local leftValue = left[field]
        local rightValue = right[field]
        if leftValue ~= rightValue then
            return tostring(leftValue or "") < tostring(rightValue or "")
        end
    end
    return false
end

function Usage.Scan(context)
    local units = GetUnitsFromContext(context)
    if type(units) ~= "table" then
        return {}
    end

    local templates = GetTemplatesFromContext(context) or {}
    local references = {}

    for _, unitKey in ipairs(SortedKeys(units)) do
        local unitConfig = units[unitKey]
        local texts = type(unitConfig) == "table" and unitConfig.Texts or nil
        if type(texts) == "table" then
            for _, textKey in ipairs(SortedKeys(texts)) do
                local textConfig = texts[textKey]
                if type(textConfig) == "table" then
                    local mainReference = BuildReference(context, templates, unitKey, textKey, textConfig, "template", textConfig.templateName, nil)
                    if mainReference then
                        references[#references + 1] = mainReference
                    end

                    if type(textConfig.stateTemplates) == "table" then
                        for _, stateKey in ipairs(SortedKeys(textConfig.stateTemplates)) do
                            local stateReference = BuildReference(context, templates, unitKey, textKey, textConfig, "state", textConfig.stateTemplates[stateKey], stateKey)
                            if stateReference then
                                references[#references + 1] = stateReference
                            end
                        end
                    end
                end
            end
        end
    end

    table.sort(references, SortReferences)
    return references
end

function Usage.FindReferences(context, templateName)
    if not IsNonEmptyString(templateName) then
        return {}
    end

    local matches = {}
    for _, reference in ipairs(Usage.Scan(context)) do
        if reference.templateName == templateName then
            matches[#matches + 1] = reference
        end
    end
    return matches
end

function Usage.CountReferences(context, templateName)
    return #Usage.FindReferences(context, templateName)
end

function Usage.GetTemplateUsage(context, templateName)
    local references = Usage.FindReferences(context, templateName)
    local unitsByKey = {}
    local units = {}
    local mainReferenceCount = 0
    local stateReferenceCount = 0

    for _, reference in ipairs(references) do
        if IsNonEmptyString(reference.unitKey) and not unitsByKey[reference.unitKey] then
            unitsByKey[reference.unitKey] = true
            units[#units + 1] = reference.unitKey
        end
        if reference.referenceKind == "state" then
            stateReferenceCount = stateReferenceCount + 1
        elseif reference.referenceKind == "template" then
            mainReferenceCount = mainReferenceCount + 1
        end
    end

    table.sort(units, SortKeys)

    return {
        templateName = templateName,
        referenceCount = #references,
        mainReferenceCount = mainReferenceCount,
        stateReferenceCount = stateReferenceCount,
        unitCount = #units,
        units = units,
        isUsed = #references > 0,
        references = references,
    }
end

function Usage.ScanProfileTemplateAssignments(profile, profileName)
    return Usage.Scan(Usage.CreateProfileContext(profile, profileName))
end

local function GetProfileName(db)
    if not db or type(db.GetCurrentProfile) ~= "function" then
        return nil
    end

    local ok, profileName = pcall(db.GetCurrentProfile, db)
    if ok and IsNonEmptyString(profileName) then
        return profileName
    end
    return nil
end

function Usage.ScanActiveProfileTemplateAssignments(db)
    if not db or type(db.profile) ~= "table" then
        return {}
    end
    return Usage.ScanProfileTemplateAssignments(db.profile, GetProfileName(db))
end

Usage.GetActiveProfileTemplateUsages = Usage.ScanActiveProfileTemplateAssignments

function Usage.GetActiveProfileTemplateUsageSummary(db)
    local profile = db and db.profile or nil
    local context = Usage.CreateProfileContext(profile, GetProfileName(db))
    local templates = GetTemplatesFromContext(context) or {}
    local references = Usage.Scan(context)
    local usedTemplates = {}
    local missingTemplates = {}
    local missingReferenceCount = 0

    for _, entry in ipairs(references) do
        local templateName = entry.templateName
        if IsNonEmptyString(templateName) then
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
        if type(templates[templateName]) == "string" and templates[templateName] ~= "" and usedTemplates[templateName] == nil then
            unusedTemplateNames[#unusedTemplateNames + 1] = templateName
        end
    end

    return {
        usages = references,
        references = references,
        usedTemplates = usedTemplates,
        usedTemplateNames = usedTemplateNames,
        missingTemplates = missingTemplates,
        missingTemplateNames = missingTemplateNames,
        missingReferenceCount = missingReferenceCount,
        unusedTemplateNames = unusedTemplateNames,
    }
end

return Usage
