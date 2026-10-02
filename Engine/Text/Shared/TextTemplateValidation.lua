local _, FocalPoint = ...

FocalPoint.TextTemplateValidation = FocalPoint.TextTemplateValidation or {}

local Validation = FocalPoint.TextTemplateValidation

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

local function GetTemplates(context)
    if type(context) ~= "table" then
        return nil
    end

    local templates = SafeCall(context.GetTemplates)
    return type(templates) == "table" and templates or nil
end

local function GetUnits(context)
    if type(context) ~= "table" then
        return nil
    end

    local units = SafeCall(context.GetUnits)
    return type(units) == "table" and units or nil
end

local function AddIssue(issues, issue)
    issues[#issues + 1] = issue
end

local function SortIssues(left, right)
    local fields = { "unitKey", "textKey", "referenceKind", "stateKey", "templateName", "code" }
    for _, field in ipairs(fields) do
        local leftValue = left[field]
        local rightValue = right[field]
        if leftValue ~= rightValue then
            return tostring(leftValue or "") < tostring(rightValue or "")
        end
    end
    return false
end

function Validation.ValidateTemplate(context, templateName)
    local issues = {}
    local templates = GetTemplates(context)

    if not IsNonEmptyString(templateName) then
        AddIssue(issues, {
            severity = "error",
            code = "invalid_template_reference",
            templateName = templateName,
        })
        return issues
    end

    local templateValue = type(templates) == "table" and templates[templateName] or nil
    if templateValue == nil then
        AddIssue(issues, {
            severity = "error",
            code = "missing_template_reference",
            templateName = templateName,
        })
    elseif type(templateValue) ~= "string" then
        AddIssue(issues, {
            severity = "error",
            code = "invalid_template_value",
            templateName = templateName,
        })
    elseif templateValue == "" then
        AddIssue(issues, {
            severity = "warning",
            code = "invalid_template_value",
            templateName = templateName,
        })
    end

    return issues
end

function Validation.ValidateTemplateReference(context, reference)
    local issues = {}
    if type(reference) ~= "table" then
        AddIssue(issues, {
            severity = "error",
            code = "invalid_template_reference",
        })
        return issues
    end

    local templateName = reference.templateName
    if not IsNonEmptyString(templateName) then
        AddIssue(issues, {
            severity = "error",
            code = "invalid_template_reference",
            unitKey = reference.unitKey,
            textKey = reference.textKey,
            referenceKind = reference.referenceKind,
            stateKey = reference.stateKey,
            templateName = templateName,
        })
        return issues
    end

    local templateIssues = Validation.ValidateTemplate(context, templateName)
    for _, issue in ipairs(templateIssues) do
        issue.unitKey = issue.unitKey or reference.unitKey
        issue.textKey = issue.textKey or reference.textKey
        issue.referenceKind = issue.referenceKind or reference.referenceKind
        issue.stateKey = issue.stateKey or reference.stateKey
        AddIssue(issues, issue)
    end

    return issues
end

local function ValidateStateTemplates(context, unitKey, textKey, stateTemplates, issues)
    if stateTemplates == nil then
        return
    end

    if type(stateTemplates) ~= "table" then
        AddIssue(issues, {
            severity = "error",
            code = "invalid_state_templates",
            unitKey = unitKey,
            textKey = textKey,
        })
        return
    end

    for _, stateKey in ipairs(SortedKeys(stateTemplates)) do
        local templateName = stateTemplates[stateKey]
        if not IsNonEmptyString(stateKey) then
            AddIssue(issues, {
                severity = "error",
                code = "invalid_state_key",
                unitKey = unitKey,
                textKey = textKey,
                referenceKind = "state",
                stateKey = stateKey,
                templateName = templateName,
            })
        end

        local reference = {
            unitKey = unitKey,
            textKey = textKey,
            referenceKind = "state",
            stateKey = stateKey,
            templateName = templateName,
        }
        for _, issue in ipairs(Validation.ValidateTemplateReference(context, reference)) do
            AddIssue(issues, issue)
        end
    end
end

function Validation.ValidateTextConfig(context, unitKey, textKey, textConfig)
    local issues = {}
    if type(textConfig) ~= "table" then
        AddIssue(issues, {
            severity = "error",
            code = "invalid_text_config",
            unitKey = unitKey,
            textKey = textKey,
        })
        return issues
    end

    if textConfig.role ~= nil and not IsNonEmptyString(textConfig.role) then
        AddIssue(issues, {
            severity = "warning",
            code = "invalid_text_role",
            unitKey = unitKey,
            textKey = textKey,
        })
    end

    if textConfig.templateName ~= nil and textConfig.templateName ~= "" then
        local reference = {
            unitKey = unitKey,
            textKey = textKey,
            referenceKind = "template",
            templateName = textConfig.templateName,
        }
        for _, issue in ipairs(Validation.ValidateTemplateReference(context, reference)) do
            AddIssue(issues, issue)
        end
    elseif textConfig.templateName ~= nil and type(textConfig.templateName) ~= "string" then
        AddIssue(issues, {
            severity = "error",
            code = "invalid_template_reference",
            unitKey = unitKey,
            textKey = textKey,
            referenceKind = "template",
            templateName = textConfig.templateName,
        })
    end

    ValidateStateTemplates(context, unitKey, textKey, textConfig.stateTemplates, issues)
    table.sort(issues, SortIssues)
    return issues
end

local function CountSeverities(issues)
    local errorCount = 0
    local warningCount = 0
    for _, issue in ipairs(issues) do
        if issue.severity == "error" then
            errorCount = errorCount + 1
        elseif issue.severity == "warning" then
            warningCount = warningCount + 1
        end
    end
    return errorCount, warningCount
end

function Validation.ValidateProfile(context)
    local issues = {}
    local unusedTemplates = {}
    local units = GetUnits(context) or {}
    local templates = GetTemplates(context) or {}
    local usedTemplates = {}

    local usage = FocalPoint.TextTemplateUsage
    local references = usage and usage.Scan and usage.Scan(context) or {}
    for _, reference in ipairs(references) do
        if IsNonEmptyString(reference.templateName) then
            usedTemplates[reference.templateName] = true
        end
    end

    for _, unitKey in ipairs(SortedKeys(units)) do
        local unitConfig = units[unitKey]
        local texts = type(unitConfig) == "table" and unitConfig.Texts or nil
        if type(texts) == "table" then
            for _, textKey in ipairs(SortedKeys(texts)) do
                for _, issue in ipairs(Validation.ValidateTextConfig(context, unitKey, textKey, texts[textKey])) do
                    AddIssue(issues, issue)
                end
            end
        end
    end

    for _, templateName in ipairs(SortedKeys(templates)) do
        local templateValue = templates[templateName]
        if not IsNonEmptyString(templateName) then
            AddIssue(issues, {
                severity = "error",
                code = "invalid_template_reference",
                templateName = templateName,
            })
        elseif type(templateValue) ~= "string" then
            AddIssue(issues, {
                severity = "error",
                code = "invalid_template_value",
                templateName = templateName,
            })
        elseif templateValue == "" then
            AddIssue(issues, {
                severity = "warning",
                code = "invalid_template_value",
                templateName = templateName,
            })
        end

        if IsNonEmptyString(templateName) and type(templateValue) == "string" and templateValue ~= "" and not usedTemplates[templateName] then
            unusedTemplates[#unusedTemplates + 1] = templateName
        end
    end

    table.sort(unusedTemplates, SortKeys)
    table.sort(issues, SortIssues)

    local errorCount, warningCount = CountSeverities(issues)
    return {
        valid = errorCount == 0,
        errorCount = errorCount,
        warningCount = warningCount,
        issues = issues,
        unusedTemplates = unusedTemplates,
    }
end

-- E4 opt-in target validation. Absence is complete; never repair or project.
local function ValidateEntityGraph(layouts, resolve)
    local issues = {}
    local library = FocalPoint.TextTemplateLibrary
    local function Issue(code, layoutId, unitKey, textKey, kind, stateKey, id)
        issues[#issues + 1] = {severity = "error", code = code, layoutId = layoutId,
            unitKey = unitKey, textKey = textKey, referenceKind = kind, stateKey = stateKey, templateId = id}
    end
    if type(resolve) ~= "function" then Issue("invalid_context") end
    if type(layouts) == "table" then
        for _, layoutId in ipairs(SortedKeys(layouts)) do
            local record = layouts[layoutId]
            local payload = type(record) == "table" and record.payload
            if type(payload) == "table" and payload.TextTemplates ~= nil then
                Issue("legacy_template_store", layoutId)
            end
        end
    end
    FocalPoint.TextTemplateUsage.VisitEntityTexts(layouts, function(layoutId, unitKey, textKey, text)
        local function Check(id, kind, stateKey)
            if not library.GetTemplateIdKind(id) then
                Issue("invalid_template_id", layoutId, unitKey, textKey, kind, stateKey, id)
            elseif type(resolve) == "function" and not resolve(id) then
                Issue("missing_template_entity", layoutId, unitKey, textKey, kind, stateKey, id)
            end
        end
        if text.templateName ~= nil or text.stateTemplates ~= nil then
            Issue("legacy_template_fields", layoutId, unitKey, textKey)
        end
        if text.tag ~= nil and type(text.tag) ~= "string" then Issue("invalid_tag", layoutId, unitKey, textKey) end
        if text.templateId ~= nil then Check(text.templateId, "main") end
        if text.stateTemplateIds ~= nil then
            if type(text.stateTemplateIds) ~= "table" then Issue("invalid_state_template_ids", layoutId, unitKey, textKey)
            else
                for _, stateKey in ipairs(SortedKeys(text.stateTemplateIds)) do
                    if not IsNonEmptyString(stateKey) then Issue("invalid_state_key", layoutId, unitKey, textKey, "state", stateKey) end
                    Check(text.stateTemplateIds[stateKey], "state", stateKey)
                end
            end
        end
    end, function(layoutId, unitKey, textKey) Issue("invalid_layout_structure", layoutId, unitKey, textKey) end)
    return {valid = #issues == 0, errorCount = #issues, warningCount = 0, issues = issues}
end

function Validation.ValidateEntityLayouts(layouts, db)
    local resolve
    if type(db) == "table" then
        resolve = function(id) return FocalPoint.TextTemplateLibrary.ResolveTemplateEntity(id, db) end
    end
    return ValidateEntityGraph(layouts, resolve)
end

-- Explicit transport graph validation: imported definitions may intentionally
-- conflict with the local catalog. Never install them just to validate FKs.
function Validation.ValidateEntityResourceGraph(layouts, definitions)
    local resolve
    if type(definitions) == "table" then
        resolve = function(id)
            local record = definitions[id]
            return FocalPoint.TextTemplateLibrary.ValidateTemplateRecord(record) and record or nil
        end
    end
    return ValidateEntityGraph(layouts, resolve)
end

return Validation
