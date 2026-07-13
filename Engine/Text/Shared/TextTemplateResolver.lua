local _, FocalPoint = ...

FocalPoint.TextTemplateResolver = FocalPoint.TextTemplateResolver or {}
local Resolver = FocalPoint.TextTemplateResolver

local function IsNonEmptyString(value)
    return type(value) == "string" and value ~= ""
end

local function GetTemplateText(templateName, context)
    if not IsNonEmptyString(templateName) or type(context) ~= "table" or type(context.GetTemplate) ~= "function" then
        return nil
    end

    local ok, templateText = pcall(context.GetTemplate, templateName)
    if ok and IsNonEmptyString(templateText) then
        return templateText
    end

    return nil
end

local function NormalizeText(text, context)
    if type(text) ~= "string" then
        return ""
    end

    if type(context) == "table" and type(context.NormalizeText) == "function" then
        local ok, normalized = pcall(context.NormalizeText, text)
        if ok and type(normalized) == "string" then
            return normalized
        end
    end

    return text
end

local function AddStateFallbacks(state, stateKeys)
    if not IsNonEmptyString(state) then
        return
    end

    stateKeys[#stateKeys + 1] = state

    if state == "ghost" then
        stateKeys[#stateKeys + 1] = "dead"
    end
end

local function BuildStateReference(textConfig, state)
    if type(textConfig) ~= "table" or type(textConfig.stateTemplates) ~= "table" or not IsNonEmptyString(state) then
        return nil
    end

    local templateName = textConfig.stateTemplates[state]
    if IsNonEmptyString(templateName) then
        return {
            kind = "state",
            state = state,
            templateName = templateName,
        }
    end

    return nil
end

local function BuildTemplateReference(textConfig)
    if type(textConfig) == "table" and IsNonEmptyString(textConfig.templateName) then
        return {
            kind = "template",
            templateName = textConfig.templateName,
        }
    end

    return nil
end

local function BuildInlineReference(textConfig)
    if type(textConfig) == "table" and IsNonEmptyString(textConfig.tag) then
        return {
            kind = "inline",
            text = textConfig.tag,
        }
    end

    return nil
end

local function BuildRuntimeCandidates(textConfig, state)
    local candidates = {}
    local stateKeys = {}
    AddStateFallbacks(state, stateKeys)

    for _, stateKey in ipairs(stateKeys) do
        candidates[#candidates + 1] = BuildStateReference(textConfig, stateKey)
    end

    candidates[#candidates + 1] = BuildTemplateReference(textConfig)
    candidates[#candidates + 1] = BuildInlineReference(textConfig)

    return candidates
end

function Resolver.ResolveReference(textConfig, state)
    if type(textConfig) ~= "table" then
        return nil
    end

    local stateKeys = {}
    AddStateFallbacks(state, stateKeys)

    for _, stateKey in ipairs(stateKeys) do
        local reference = BuildStateReference(textConfig, stateKey)
        if reference then
            return reference
        end
    end

    return BuildTemplateReference(textConfig) or BuildInlineReference(textConfig)
end

function Resolver.ResolveTemplateText(reference, context)
    if type(reference) ~= "table" then
        return ""
    end

    if reference.kind == "state" or reference.kind == "template" then
        return NormalizeText(GetTemplateText(reference.templateName, context) or "", context)
    end

    if reference.kind == "inline" then
        return NormalizeText(reference.text or "", context)
    end

    return ""
end

function Resolver.Resolve(textConfig, state, context)
    if type(textConfig) ~= "table" then
        return ""
    end

    for _, reference in ipairs(BuildRuntimeCandidates(textConfig, state)) do
        local resolvedText = Resolver.ResolveTemplateText(reference, context)
        if IsNonEmptyString(resolvedText) then
            return resolvedText
        end
    end

    return ""
end
