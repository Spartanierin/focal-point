local _, FocalPoint = ...

FocalPoint.TextTemplateResolver = FocalPoint.TextTemplateResolver or {}
local Resolver = FocalPoint.TextTemplateResolver
local BindingCache = setmetatable({}, { __mode = "k" })

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

local function GetStateKey(state)
    return IsNonEmptyString(state) and state or ""
end

local function GetRuntimeCandidates(textConfig, state)
    if type(textConfig) ~= "table" then
        return nil
    end

    local binding = BindingCache[textConfig]
    if type(binding) ~= "table" then
        binding = {
            states = {},
        }
        BindingCache[textConfig] = binding
    end

    local stateKey = GetStateKey(state)
    local candidates = binding.states[stateKey]
    if type(candidates) ~= "table" then
        candidates = BuildRuntimeCandidates(textConfig, state)
        binding.states[stateKey] = candidates
    end

    return candidates
end

function Resolver.Invalidate(textConfig)
    if type(textConfig) == "table" then
        BindingCache[textConfig] = nil
    end
end

function Resolver.InvalidateUnitTexts(unitConfig)
    local texts = unitConfig and unitConfig.Texts
    if type(texts) ~= "table" then
        return
    end

    for _, textConfig in pairs(texts) do
        Resolver.Invalidate(textConfig)
    end
end

function Resolver.InvalidateAllUnitTexts(units)
    if type(units) ~= "table" then
        return
    end

    for _, unitConfig in pairs(units) do
        Resolver.InvalidateUnitTexts(unitConfig)
    end
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

    for _, reference in ipairs(GetRuntimeCandidates(textConfig, state) or {}) do
        local resolvedText = Resolver.ResolveTemplateText(reference, context)
        if IsNonEmptyString(resolvedText) then
            return resolvedText
        end
    end

    return ""
end
