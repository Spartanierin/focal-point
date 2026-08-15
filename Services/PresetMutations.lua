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

local function IsDuplicateUserPresetName(candidate, excludePresetId)
    local rawPresets = UserPresetStore.ListRaw and UserPresetStore.ListRaw() or {}
    if type(rawPresets) ~= "table" then
        return false
    end

    for id, rawPreset in pairs(rawPresets) do
        local metadata = type(rawPreset) == "table" and rawPreset.metadata or nil
        if id ~= excludePresetId and NormalizeComparableName(metadata and metadata.name) == candidate then
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

function PresetMutations.ValidateName(name, options)
    options = type(options) == "table" and options or {}
    local normalizedName = Trim(name)
    if normalizedName == "" then
        return false, "invalid-name"
    end
    if GetTextLength(normalizedName) > MAX_NAME_LENGTH then
        return false, "name-too-long"
    end

    local comparableName = NormalizeComparableName(normalizedName)
    if IsDuplicateUserPresetName(comparableName, options.excludePresetId) then
        return false, "duplicate-name"
    end
    if IsBuiltInName(comparableName) then
        return false, "reserved-name"
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

function PresetMutations.RenameUserPreset(presetId, newName)
    if type(presetId) ~= "string" or presetId == "" then
        return false, "not-found"
    end
    if PresetService.IsReadOnly and PresetService.IsReadOnly(presetId) then
        return false, "read-only"
    end

    local rawPreset = UserPresetStore.GetRaw and UserPresetStore.GetRaw(presetId) or nil
    if type(rawPreset) ~= "table" then
        return false, "not-found"
    end

    local isValidName, normalizedNameOrError = PresetMutations.ValidateName(newName, {
        excludePresetId = presetId,
    })
    if not isValidName then
        return false, normalizedNameOrError
    end

    local metadata = type(rawPreset.metadata) == "table" and rawPreset.metadata or {}
    if NormalizeComparableName(metadata.name) == NormalizeComparableName(normalizedNameOrError) then
        return true, PresetService.GetPreset and PresetService.GetPreset(presetId) or Clone(rawPreset)
    end

    local updatedPreset = Clone(rawPreset)
    updatedPreset.metadata = type(updatedPreset.metadata) == "table" and updatedPreset.metadata or {}
    updatedPreset.metadata.id = presetId
    updatedPreset.metadata.name = normalizedNameOrError
    updatedPreset.metadata.source = "user"
    updatedPreset.metadata.readOnly = false

    local storedId = UserPresetStore.PutRaw and UserPresetStore.PutRaw(updatedPreset) or nil
    if storedId ~= presetId then
        return false, "update-failed"
    end

    return true, PresetService.GetPreset and PresetService.GetPreset(presetId) or Clone(updatedPreset)
end

function PresetMutations.DeleteUserPreset(presetId)
    if type(presetId) ~= "string" or presetId == "" then
        return false, "not-found"
    end
    if PresetService.IsReadOnly and PresetService.IsReadOnly(presetId) then
        return false, "read-only"
    end

    local rawPreset = UserPresetStore.GetRaw and UserPresetStore.GetRaw(presetId) or nil
    if type(rawPreset) ~= "table" then
        return false, "not-found"
    end

    if not (UserPresetStore.RemoveRaw and UserPresetStore.RemoveRaw(presetId)) then
        return false, "delete-failed"
    end

    return true
end

return PresetMutations
