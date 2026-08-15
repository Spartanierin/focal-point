local _, FocalPoint = ...

FocalPoint.PresetService = FocalPoint.PresetService or {}
local PresetService = FocalPoint.PresetService

local LayoutService = FocalPoint.LayoutService or {}
local LegacyThemeAdapter = FocalPoint.LegacyThemeAdapter or {}
local UserPresetStore = FocalPoint.UserPresetStore or {}

local BUILT_IN_PRESET_ORDER = {
    "default",
    "classic",
    "minimal",
    "modern",
}

local FORMAT_VERSION = 1
local PRESET_VERSION = 1

local function Clone(value)
    return LayoutService.Clone and LayoutService.Clone(value) or value
end

local function GetDefaults()
    return FocalPoint.GetDefaultDB and FocalPoint:GetDefaultDB() or nil
end

local function NormalizeBuiltInMetadata(id, theme)
    return {
        id = id,
        labelKey = theme and theme.labelKey or nil,
        descriptionKey = theme and theme.descriptionKey or nil,
        source = "builtin",
        readOnly = true,
        version = PRESET_VERSION,
        formatVersion = FORMAT_VERSION,
    }
end

local function NormalizeUserMetadata(id, raw)
    local metadata = type(raw.metadata) == "table" and raw.metadata or {}
    return {
        id = id,
        name = type(metadata.name) == "string" and metadata.name or tostring(id),
        description = type(metadata.description) == "string" and metadata.description or nil,
        source = "user",
        readOnly = false,
        version = tonumber(metadata.version) or PRESET_VERSION,
        formatVersion = tonumber(metadata.formatVersion) or FORMAT_VERSION,
    }
end

local function BuildBuiltInPreset(id)
    local themes = FocalPoint.Themes or {}
    local theme = themes[id]
    if type(theme) ~= "table" then
        return nil
    end

    local layout = LegacyThemeAdapter.MaterializePreviewLayout
        and LegacyThemeAdapter.MaterializePreviewLayout(theme, GetDefaults())
        or nil

    if type(layout) ~= "table" then
        return nil
    end

    return {
        metadata = NormalizeBuiltInMetadata(id, theme),
        layout = Clone(layout),
    }
end

local function NormalizeUserPreset(id, raw)
    if type(raw) ~= "table" or type(raw.layout) ~= "table" then
        return nil
    end

    return {
        metadata = NormalizeUserMetadata(id, raw),
        layout = Clone(raw.layout),
    }
end

local function SortedKeys(source)
    local keys = {}
    if type(source) ~= "table" then
        return keys
    end

    for key in pairs(source) do
        if type(key) == "string" and key ~= "" then
            keys[#keys + 1] = key
        end
    end

    table.sort(keys)
    return keys
end

local function AddBuiltIns(target)
    local seen = {}
    local themes = FocalPoint.Themes or {}

    for _, id in ipairs(BUILT_IN_PRESET_ORDER) do
        local preset = BuildBuiltInPreset(id)
        if preset then
            target[id] = preset
            seen[id] = true
        end
    end

    for _, id in ipairs(SortedKeys(themes)) do
        if not seen[id] then
            local preset = BuildBuiltInPreset(id)
            if preset then
                target[id] = preset
            end
        end
    end
end

function PresetService.GetBuiltInPresets()
    local presets = {}
    AddBuiltIns(presets)
    return Clone(presets)
end

function PresetService.GetUserPresets()
    local presets = {}
    local rawPresets = UserPresetStore.ListRaw and UserPresetStore.ListRaw() or {}

    for _, id in ipairs(SortedKeys(rawPresets)) do
        local preset = NormalizeUserPreset(id, rawPresets[id])
        if preset then
            presets[id] = preset
        end
    end

    return Clone(presets)
end

function PresetService.ListPresets()
    local presets = {}
    AddBuiltIns(presets)

    local userPresets = PresetService.GetUserPresets()
    for id, preset in pairs(userPresets) do
        presets[id] = preset
    end

    return Clone(presets)
end

function PresetService.GetPreset(id)
    if type(id) ~= "string" or id == "" then
        return nil
    end

    local builtin = BuildBuiltInPreset(id)
    if builtin then
        return Clone(builtin)
    end

    local raw = UserPresetStore.GetRaw and UserPresetStore.GetRaw(id) or nil
    local userPreset = NormalizeUserPreset(id, raw)
    return userPreset and Clone(userPreset) or nil
end

function PresetService.IsReadOnly(id)
    local preset = PresetService.GetPreset(id)
    return preset and preset.metadata and preset.metadata.readOnly == true or false
end

return PresetService
