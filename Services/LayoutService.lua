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

function LayoutService.MaterializeFromProfile(profile, defaults)
    local defaultProfile = defaults and defaults.profile or defaults
    local defaultUnits = defaultProfile and defaultProfile.Units
    local profileUnits = profile and profile.Units
    local layout = {
        Units = {},
        TextTemplates = LayoutService.Clone(profile and profile.TextTemplates) or {},
    }

    if type(defaultUnits) == "table" then
        for unitKey, defaultUnit in pairs(defaultUnits) do
            layout.Units[unitKey] = LayoutService.MaterializeUnit(defaultUnit, profileUnits and profileUnits[unitKey])
        end
    elseif type(profileUnits) == "table" then
        layout.Units = LayoutService.Clone(profileUnits) or {}
    end

    return layout
end

function LayoutService.BuildPreviewUnitConfig(layout, unitKey)
    if type(layout) ~= "table" or type(layout.Units) ~= "table" then
        return nil
    end
    return LayoutService.Clone(layout.Units[unitKey])
end

return LayoutService
