local _, FocalPoint = ...

FocalPoint.LayoutService = FocalPoint.LayoutService or {}
local LayoutService = FocalPoint.LayoutService

function LayoutService.Clone(value)
    if type(value) ~= "table" then
        return value
    end

    if CopyTable then
        return CopyTable(value)
    end

    local result = {}
    for key, entry in pairs(value) do
        result[key] = LayoutService.Clone(entry)
    end
    return result
end

function LayoutService.MergeInto(target, source)
    if type(target) ~= "table" or type(source) ~= "table" then
        return target
    end

    for key, value in pairs(source) do
        if type(value) == "table" then
            target[key] = type(target[key]) == "table" and target[key] or {}
            LayoutService.MergeInto(target[key], value)
        else
            target[key] = value
        end
    end

    return target
end

function LayoutService.MaterializeUnit(defaultUnit, unitConfig)
    local materialized = LayoutService.Clone(defaultUnit) or {}
    if type(unitConfig) == "table" then
        LayoutService.MergeInto(materialized, unitConfig)
    end
    return materialized
end

local function ResolveLayoutDefaults(defaults)
    local defaultProfile = defaults and defaults.profile or defaults
    return {
        Units = defaultProfile and defaultProfile.Units or nil,
        TextTemplates = defaultProfile and defaultProfile.TextTemplates or nil,
    }
end

function LayoutService.NormalizePayload(payload, defaults)
    local layoutDefaults = ResolveLayoutDefaults(defaults)
    local sourceUnits = type(payload) == "table" and payload.Units or nil
    local sourceTemplates = type(payload) == "table" and payload.TextTemplates or nil
    local normalized = {
        Units = {},
        TextTemplates = LayoutService.Clone(layoutDefaults.TextTemplates) or {},
    }

    if type(sourceTemplates) == "table" then
        LayoutService.MergeInto(normalized.TextTemplates, sourceTemplates)
    end

    if type(layoutDefaults.Units) == "table" then
        for unitKey, defaultUnit in pairs(layoutDefaults.Units) do
            normalized.Units[unitKey] = LayoutService.MaterializeUnit(defaultUnit, sourceUnits and sourceUnits[unitKey])
        end
    elseif type(sourceUnits) == "table" then
        normalized.Units = LayoutService.Clone(sourceUnits) or {}
    end

    return normalized
end

function LayoutService.CopyPayload(payload)
    return LayoutService.NormalizePayload(payload)
end

function LayoutService.MaterializeFromProfile(profile, defaults)
    local defaultProfile = defaults and defaults.profile or defaults
    return LayoutService.NormalizePayload({
        Units = profile and profile.Units or nil,
        TextTemplates = profile and profile.TextTemplates or nil,
    }, defaultProfile)
end

function LayoutService.BuildPreviewUnitConfig(layout, unitKey)
    if type(layout) ~= "table" or type(layout.Units) ~= "table" then
        return nil
    end
    return LayoutService.Clone(layout.Units[unitKey])
end

return LayoutService
