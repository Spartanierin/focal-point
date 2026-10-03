local _, FocalPoint = ...

FocalPoint.TextTemplateResolver = FocalPoint.TextTemplateResolver or {}
local Resolver = FocalPoint.TextTemplateResolver
local EntityBinding = {main = "templateId", states = "stateTemplateIds", reference = "templateId",
    cache = setmetatable({}, { __mode = "k" })}
local BindingCache = EntityBinding.cache

local function IsNonEmptyString(value)
    return type(value) == "string" and value ~= ""
end

local function GetTemplateText(templateId, context)
    if type(context) ~= "table" or type(context.db) ~= "table" then return nil end
    local entity = FocalPoint.TextTemplateLibrary.ResolveTemplateEntity(templateId, context.db)
    return entity and entity.content or nil
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

local function BuildStateReference(textConfig, state, binding)
    binding = binding or EntityBinding
    if type(textConfig) ~= "table" or type(textConfig[binding.states]) ~= "table" or not IsNonEmptyString(state) then
        return nil
    end

    local templateName = textConfig[binding.states][state]
    if IsNonEmptyString(templateName) then
        return {
            kind = "state",
            state = state,
            [binding.reference] = templateName,
        }
    end

    return nil
end

local function BuildTemplateReference(textConfig, binding)
    binding = binding or EntityBinding
    if type(textConfig) == "table" and IsNonEmptyString(textConfig[binding.main]) then
        return {
            kind = "template",
            [binding.reference] = textConfig[binding.main],
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

local function BuildRuntimeCandidates(textConfig, state, binding)
    local candidates = {}
    local stateKeys = {}
    AddStateFallbacks(state, stateKeys)

    for _, stateKey in ipairs(stateKeys) do
        candidates[#candidates + 1] = BuildStateReference(textConfig, stateKey, binding)
    end

    candidates[#candidates + 1] = BuildTemplateReference(textConfig, binding)
    candidates[#candidates + 1] = BuildInlineReference(textConfig)

    return candidates
end

local function SortedKeys(source)
    local keys = {}
    if type(source) ~= "table" then
        return keys
    end

    for key in pairs(source) do
        if type(key) == "string" then
            keys[#keys + 1] = key
        end
    end

    table.sort(keys)
    return keys
end

local function BuildDependencyCandidates(textConfig, binding)
    local candidates = {}
    if type(textConfig) ~= "table" then
        return candidates
    end

    if type(textConfig[binding.states]) == "table" then
        for _, stateKey in ipairs(SortedKeys(textConfig[binding.states])) do
            candidates[#candidates + 1] = BuildStateReference(textConfig, stateKey, binding)
        end
    end

    candidates[#candidates + 1] = BuildTemplateReference(textConfig, binding)
    candidates[#candidates + 1] = BuildInlineReference(textConfig)
    return candidates
end

local function GetStateKey(state)
    return IsNonEmptyString(state) and state or ""
end

local function GetRuntimeCandidates(textConfig, state, contract)
    if type(textConfig) ~= "table" then
        return nil
    end

    local binding = contract.cache[textConfig]
    if type(binding) ~= "table" then
        binding = {
            states = {},
        }
        contract.cache[textConfig] = binding
    end

    local stateKey = GetStateKey(state)
    local candidates = binding.states[stateKey]
    if type(candidates) ~= "table" then
        candidates = BuildRuntimeCandidates(textConfig, state, contract)
        binding.states[stateKey] = candidates
    end

    return candidates
end

function Resolver.Invalidate(textConfig)
    if type(textConfig) == "table" then
        BindingCache[textConfig] = nil
        EntityBinding.cache[textConfig] = nil
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

local function ResolveReference(binding, textConfig, state)
    if type(textConfig) ~= "table" then
        return nil
    end

    local stateKeys = {}
    AddStateFallbacks(state, stateKeys)

    for _, stateKey in ipairs(stateKeys) do
        local reference = BuildStateReference(textConfig, stateKey, binding)
        if reference then
            return reference
        end
    end

    return BuildTemplateReference(textConfig, binding) or BuildInlineReference(textConfig)
end

local function ResolveTemplateText(binding, reference, context)
    if type(reference) ~= "table" then
        return ""
    end

    if reference.kind == "state" or reference.kind == "template" then
        return NormalizeText(GetTemplateText(reference[binding.reference], context, binding) or "", context)
    end

    if reference.kind == "inline" then
        return NormalizeText(reference.text or "", context)
    end

    return ""
end

local function Resolve(binding, textConfig, state, context)
    if type(textConfig) ~= "table" then
        return ""
    end

    for _, reference in ipairs(GetRuntimeCandidates(textConfig, state, binding) or {}) do
        local resolvedText = ResolveTemplateText(binding, reference, context)
        if IsNonEmptyString(resolvedText) then
            return resolvedText
        end
    end

    return ""
end

local function AddDependency(target, dependency)
    if type(target) ~= "table" then
        return
    end

    if type(dependency) == "string" and dependency ~= "" then
        target[dependency] = true
        return
    end

    if type(dependency) == "table" then
        for _, entry in ipairs(dependency) do
            AddDependency(target, entry)
        end
    end
end

local function HasAnyDependency(dependencies)
    if type(dependencies) ~= "table" then
        return false
    end

    for _, enabled in pairs(dependencies) do
        if enabled == true then
            return true
        end
    end

    return false
end

local function ScanTemplateDependencies(template, dependencies, context)
    template = NormalizeText(template, context)
    if template == "" then
        return false
    end

    local foundToken = false
    for token in template:gmatch("%[([^%]]+)%]") do
        foundToken = true

        local dependency = nil
        if type(context) == "table" and type(context.GetBasicTagDependencies) == "function" then
            dependency = context.GetBasicTagDependencies(token)
        end

        if dependency == nil and type(context) == "table" and type(context.GetTokenDependencies) == "function" then
            dependency = context.GetTokenDependencies(token)
        end

        AddDependency(dependencies, dependency or "unknown")
    end

    return foundToken
end

local function ResolveDependencies(binding, textConfig, context)
    local dependencies = {}
    local sawTemplate = false
    local sawToken = false

    if type(textConfig) == "table" then
        for _, reference in ipairs(BuildDependencyCandidates(textConfig, binding)) do
            if reference then
                local template = ResolveTemplateText(binding, reference, context)
                if template ~= "" then
                    sawTemplate = true
                    sawToken = ScanTemplateDependencies(template, dependencies, context) or sawToken
                end
            end
        end
    end

    if not sawTemplate and type(context) == "table" and type(context.GetRoleDependencies) == "function" then
        AddDependency(dependencies, context.GetRoleDependencies())
    end

    if not HasAnyDependency(dependencies) then
        AddDependency(dependencies, sawTemplate and "static" or "unknown")
    end

    return dependencies
end

local function BindContract(binding, target)
    target.ResolveReference = function(config, state) return ResolveReference(binding, config, state) end
    target.ResolveTemplateText = function(reference, context) return ResolveTemplateText(binding, reference, context) end
    target.Resolve = function(config, state, context) return Resolve(binding, config, state, context) end
    target.ResolveDependencies = function(config, context) return ResolveDependencies(binding, config, context) end
    return target
end
BindContract(EntityBinding, Resolver)
-- The explicit Entity API and the canonical runtime share one contract.
Resolver.Entity = Resolver
