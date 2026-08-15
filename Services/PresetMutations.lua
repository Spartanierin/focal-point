local _, FocalPoint = ...

FocalPoint.PresetMutations = FocalPoint.PresetMutations or {}
local PresetMutations = FocalPoint.PresetMutations

local LayoutService = FocalPoint.LayoutService or {}
local PresetService = FocalPoint.PresetService or {}
local UserPresetStore = FocalPoint.UserPresetStore or {}

local FORMAT_VERSION = 1
local PRESET_VERSION = 1
local MAX_NAME_LENGTH = 64

local BUILT_IN_NAME_FALLBACKS = {
    default = "Default",
    classic = "Classic",
    minimal = "Minimal",
    modern = "Modern",
}

local function Clone(value)
    return LayoutService.Clone and LayoutService.Clone(value) or value
end

local function Trim(value)
    if type(value) ~= "string" then
        return ""
    end
    return (value:gsub("^%s+", ""):gsub("%s+$", ""))
end

local function GetTextLength(value)
    if strlenutf8 then
        local ok, length = pcall(strlenutf8, value)
        if ok and type(length) == "number" then
            return length
        end
    end
    return #value
end

local function NormalizeComparableName(value)
    local trimmed = Trim(value)
    if trimmed == "" then
        return ""
    end
    return string.lower(trimmed)
end

local function ResolveBuiltInName(id, preset)
    local metadata = preset and preset.metadata or nil
    local labelKey = metadata and metadata.labelKey or nil
    local localized = labelKey and FocalPoint.L and FocalPoint.L[labelKey] or nil
    if type(localized) == "string" and localized ~= "" then
        return localized
    end
    return BUILT_IN_NAME_FALLBACKS[id] or tostring(id or "")
end

local function IsDuplicateUserPresetName(candidate)
    local rawPresets = UserPresetStore.ListRaw and UserPresetStore.ListRaw() or {}
    if type(rawPresets) ~= "table" then
        return false
    end

    for _, rawPreset in pairs(rawPresets) do
        local metadata = type(rawPreset) == "table" and rawPreset.metadata or nil
        if NormalizeComparableName(metadata and metadata.name) == candidate then
            return true
        end
    end

    return false
end

local function IsBuiltInName(candidate)
    local builtIns = PresetService.GetBuiltInPresets and PresetService.GetBuiltInPresets() or {}
    if type(builtIns) ~= "table" then
        return false
    end

    for id, preset in pairs(builtIns) do
        if NormalizeComparableName(ResolveBuiltInName(id, preset)) == candidate then
            return true
        end
    end

    return false
end

local function IsValidLayout(layout)
    return type(layout) == "table"
        and type(layout.Units) == "table"
        and type(layout.TextTemplates) == "table"
end

function PresetMutations.ValidateName(name)
    local normalizedName = Trim(name)
    if normalizedName == "" or GetTextLength(normalizedName) > MAX_NAME_LENGTH then
        return false, "invalid-name"
    end

    local comparableName = NormalizeComparableName(normalizedName)
    if IsDuplicateUserPresetName(comparableName) or IsBuiltInName(comparableName) then
        return false, "duplicate-name"
    end

    return true, normalizedName
end

function PresetMutations.CreateUserPresetFromProfile(name)
    local isValidName, normalizedNameOrError = PresetMutations.ValidateName(name)
    if not isValidName then
        return false, normalizedNameOrError
    end

    if not (UserPresetStore.EnsureStore and UserPresetStore.EnsureStore()) then
        return false, "store-unavailable"
    end

    local profile = FocalPoint.db and FocalPoint.db.profile or nil
    local defaults = FocalPoint.GetDefaultDB and FocalPoint:GetDefaultDB() or nil
    local layout = LayoutService.MaterializeFromProfile and LayoutService.MaterializeFromProfile(profile, defaults) or nil
    if not IsValidLayout(layout) then
        return false, "layout-invalid"
    end

    local id = UserPresetStore.GenerateId and UserPresetStore.GenerateId() or nil
    if type(id) ~= "string" or id == "" then
        return false, "create-failed"
    end

    local preset = {
        metadata = {
            id = id,
            name = normalizedNameOrError,
            source = "user",
            readOnly = false,
            version = PRESET_VERSION,
            formatVersion = FORMAT_VERSION,
        },
        layout = Clone(layout),
    }

    local storedId = UserPresetStore.PutRaw and UserPresetStore.PutRaw(preset) or nil
    if storedId ~= id then
        return false, "create-failed"
    end

    local storedPreset = PresetService.GetPreset and PresetService.GetPreset(id) or nil
    return true, storedPreset or Clone(preset)
end

return PresetMutations
