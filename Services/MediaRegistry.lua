local _, FocalPoint = ...

FocalPoint.MediaRegistry = FocalPoint.MediaRegistry or {}
local MediaRegistry = FocalPoint.MediaRegistry

local MEDIA_TYPE_STATUSBAR = "statusbar"
local PROVIDER_FOCAL_POINT = "FocalPoint"
local PROVIDER_BLIZZARD = "Blizzard"
local PROVIDER_LIB_SHARED_MEDIA = "LibSharedMedia"
local PROVIDER_PATH = "Path"

local DEFAULT_STATUSBAR_REFERENCE = "fp:statusbar:blizzard-default"
local DEFAULT_STATUSBAR_PATH = "Interface\\TargetingFrame\\UI-StatusBar"

local SOURCE_ORDER = {
    ["Focal Point"] = 1,
    Blizzard = 2,
    External = 3,
    ["Legacy Path"] = 4,
    Unavailable = 5,
}

local entriesByType = {}
local entriesByReference = {}
local pathReferencesByType = {}
local defaultReferences = {
    [MEDIA_TYPE_STATUSBAR] = DEFAULT_STATUSBAR_REFERENCE,
}

local function Trim(value)
    if type(value) ~= "string" then
        return ""
    end

    return (value:gsub("^%s+", ""):gsub("%s+$", ""))
end

local function NormalizeMediaType(mediaType)
    mediaType = Trim(mediaType):lower()
    if mediaType == "" then
        return nil
    end

    return mediaType
end

local function NormalizePathKey(path)
    path = Trim(path)
    if path == "" then
        return nil
    end

    return path:gsub("/", "\\"):lower()
end

local function CopyEntry(entry)
    if type(entry) ~= "table" then
        return nil
    end

    local copy = {}
    for key, value in pairs(entry) do
        copy[key] = value
    end
    return copy
end

local function GetEntrySortOrder(entry)
    if entry and entry.available == false then
        return SOURCE_ORDER.Unavailable
    end

    return SOURCE_ORDER[entry and entry.source] or SOURCE_ORDER[entry and entry.category] or 50
end

local function SortEntries(left, right)
    local leftOrder = GetEntrySortOrder(left)
    local rightOrder = GetEntrySortOrder(right)
    if leftOrder ~= rightOrder then
        return leftOrder < rightOrder
    end

    local leftName = left.sortName or left.name or left.id or ""
    local rightName = right.sortName or right.name or right.id or ""
    if leftName ~= rightName then
        return leftName < rightName
    end

    return (left.id or "") < (right.id or "")
end

local function EnsureType(mediaType)
    mediaType = NormalizeMediaType(mediaType)
    if not mediaType then
        return nil
    end

    entriesByType[mediaType] = entriesByType[mediaType] or {}
    entriesByReference[mediaType] = entriesByReference[mediaType] or {}
    pathReferencesByType[mediaType] = pathReferencesByType[mediaType] or {}

    return mediaType
end

local function IsLegacyPath(value)
    if type(value) ~= "string" then
        return false
    end

    return value:match("^Interface\\") ~= nil or value:match("^Fonts\\") ~= nil
end

local function ParseReference(reference, expectedMediaType)
    reference = Trim(reference)
    if reference == "" then
        return nil, "empty_reference"
    end

    local legacyPath = reference:match("^path:(.+)$")
    if legacyPath and legacyPath ~= "" then
        local mediaType = NormalizeMediaType(expectedMediaType) or MEDIA_TYPE_STATUSBAR
        return {
            kind = "legacy",
            provider = PROVIDER_PATH,
            mediaType = mediaType,
            providerKey = legacyPath,
            path = legacyPath,
            id = "path:" .. legacyPath,
        }
    end

    local provider, mediaType, providerKey = reference:match("^([^:]+):([^:]+):(.+)$")
    if provider and mediaType and providerKey then
        provider = provider:lower()
        mediaType = NormalizeMediaType(mediaType)

        if expectedMediaType and mediaType ~= NormalizeMediaType(expectedMediaType) then
            return nil, "media_type_mismatch"
        end

        if provider == "fp" then
            return {
                kind = "builtin",
                provider = PROVIDER_FOCAL_POINT,
                mediaType = mediaType,
                providerKey = providerKey,
                id = "fp:" .. mediaType .. ":" .. providerKey,
            }
        end

        if provider == "lsm" then
            return {
                kind = "external",
                provider = PROVIDER_LIB_SHARED_MEDIA,
                mediaType = mediaType,
                providerKey = providerKey,
                id = "lsm:" .. mediaType .. ":" .. providerKey,
            }
        end

        return nil, "unknown_provider"
    end

    if IsLegacyPath(reference) then
        local mediaType = NormalizeMediaType(expectedMediaType) or MEDIA_TYPE_STATUSBAR
        return {
            kind = "legacy",
            provider = PROVIDER_PATH,
            mediaType = mediaType,
            providerKey = reference,
            path = reference,
            id = "path:" .. reference,
        }
    end

    return nil, "invalid_reference"
end

local function BuildUnavailableEntry(parsedReference)
    if type(parsedReference) ~= "table" then
        return nil
    end

    local source = parsedReference.provider == PROVIDER_LIB_SHARED_MEDIA and "External" or "Unavailable"
    local category = parsedReference.provider == PROVIDER_LIB_SHARED_MEDIA and "External" or "Unavailable"

    return {
        id = parsedReference.id,
        name = parsedReference.providerKey,
        mediaType = parsedReference.mediaType,
        source = source,
        provider = parsedReference.provider,
        providerKey = parsedReference.providerKey,
        path = nil,
        available = false,
        builtin = false,
        category = category,
        sortName = tostring(parsedReference.providerKey or ""):lower(),
    }
end

local function BuildLegacyEntry(parsedReference)
    if type(parsedReference) ~= "table" or not parsedReference.path then
        return nil
    end

    return {
        id = parsedReference.id,
        name = parsedReference.path,
        mediaType = parsedReference.mediaType,
        source = "Legacy Path",
        provider = PROVIDER_PATH,
        providerKey = parsedReference.path,
        path = parsedReference.path,
        available = true,
        builtin = false,
        category = "Legacy",
        sortName = parsedReference.path:lower(),
        verified = false,
    }
end

function MediaRegistry.RegisterBuiltin(mediaType, id, name, path, options)
    mediaType = EnsureType(mediaType)
    id = Trim(id)
    path = Trim(path)
    if not mediaType or id == "" or path == "" then
        return nil, "invalid_builtin"
    end

    if not id:match("^[^:]+:[^:]+:.+") then
        id = "fp:" .. mediaType .. ":" .. id
    end

    local parsed, reason = ParseReference(id, mediaType)
    if not parsed then
        return nil, reason
    end

    options = type(options) == "table" and options or {}
    local source = options.source or "Focal Point"
    local provider = options.provider or (source == "Blizzard" and PROVIDER_BLIZZARD or PROVIDER_FOCAL_POINT)
    local providerKey = options.providerKey or parsed.providerKey
    local entry = {
        id = parsed.id,
        name = name or providerKey,
        mediaType = mediaType,
        source = source,
        provider = provider,
        providerKey = providerKey,
        path = path,
        available = options.available ~= false,
        builtin = options.builtin ~= false,
        category = options.category or (source == "Blizzard" and "Blizzard" or "Built-in"),
        sortName = (options.sortName or name or providerKey or parsed.id):lower(),
        verified = options.verified == true,
    }

    entriesByReference[mediaType][entry.id] = entry
    entriesByType[mediaType][entry.id] = entry

    local pathKey = NormalizePathKey(path)
    if pathKey then
        pathReferencesByType[mediaType][pathKey] = entry.id
    end

    return CopyEntry(entry)
end

function MediaRegistry.NormalizeReference(value, mediaType)
    local parsed, reason = ParseReference(value, mediaType)
    if not parsed then
        return nil, reason
    end

    if parsed.kind == "legacy" then
        local normalizedType = EnsureType(parsed.mediaType)
        local pathKey = NormalizePathKey(parsed.path)
        local knownReference = normalizedType and pathKey and pathReferencesByType[normalizedType][pathKey]
        return knownReference or parsed.id
    end

    return parsed.id
end

function MediaRegistry.GetEntry(reference, mediaType)
    local parsed, reason = ParseReference(reference, mediaType)
    if not parsed then
        return nil, reason
    end

    local normalizedType = EnsureType(parsed.mediaType)
    if not normalizedType then
        return nil, "invalid_media_type"
    end

    if parsed.kind == "legacy" then
        local pathKey = NormalizePathKey(parsed.path)
        local knownReference = pathKey and pathReferencesByType[normalizedType][pathKey]
        if knownReference and entriesByReference[normalizedType][knownReference] then
            return CopyEntry(entriesByReference[normalizedType][knownReference])
        end

        return BuildLegacyEntry(parsed)
    end

    local entry = entriesByReference[normalizedType][parsed.id]
    if entry then
        return CopyEntry(entry)
    end

    return BuildUnavailableEntry(parsed)
end

function MediaRegistry.GetDefault(mediaType)
    mediaType = NormalizeMediaType(mediaType)
    if not mediaType then
        return nil
    end

    return defaultReferences[mediaType]
end

function MediaRegistry.Resolve(reference, mediaType, fallbackReference)
    local entry = MediaRegistry.GetEntry(reference, mediaType)
    if entry and entry.available and type(entry.path) == "string" and entry.path ~= "" then
        return entry.path, entry
    end

    if fallbackReference and fallbackReference ~= reference then
        local fallbackPath, fallbackEntry = MediaRegistry.Resolve(fallbackReference, mediaType)
        if fallbackPath then
            return fallbackPath, fallbackEntry
        end
    end

    local defaultReference = MediaRegistry.GetDefault(mediaType)
    if defaultReference and defaultReference ~= reference and defaultReference ~= fallbackReference then
        local defaultEntry = MediaRegistry.GetEntry(defaultReference, mediaType)
        if defaultEntry and defaultEntry.available and type(defaultEntry.path) == "string" and defaultEntry.path ~= "" then
            return defaultEntry.path, defaultEntry
        end
    end

    if NormalizeMediaType(mediaType) == MEDIA_TYPE_STATUSBAR then
        return DEFAULT_STATUSBAR_PATH, nil
    end

    return nil, entry
end

function MediaRegistry.IsAvailable(reference, mediaType)
    local entry = MediaRegistry.GetEntry(reference, mediaType)
    return entry and entry.available == true or false
end

function MediaRegistry.GetAvailable(mediaType, options)
    mediaType = EnsureType(mediaType)
    if not mediaType then
        return {}
    end

    local includeUnavailable = not (type(options) == "table" and options.availableOnly == true)
    local entries = {}
    for _, entry in pairs(entriesByType[mediaType]) do
        if includeUnavailable or entry.available == true then
            entries[#entries + 1] = CopyEntry(entry)
        end
    end

    table.sort(entries, SortEntries)
    return entries
end

function MediaRegistry.GetSources(mediaType)
    local entries = MediaRegistry.GetAvailable(mediaType)
    local sourceSet = {}
    for _, entry in ipairs(entries) do
        if entry.source then
            sourceSet[entry.source] = true
        end
    end

    local sources = {}
    for source in pairs(sourceSet) do
        sources[#sources + 1] = source
    end

    table.sort(sources, function(left, right)
        local leftOrder = SOURCE_ORDER[left] or 50
        local rightOrder = SOURCE_ORDER[right] or 50
        if leftOrder ~= rightOrder then
            return leftOrder < rightOrder
        end
        return left < right
    end)

    return sources
end

function MediaRegistry.Refresh()
    -- Passive placeholder for future providers such as LibSharedMedia.
    return true
end

MediaRegistry.RegisterBuiltin(MEDIA_TYPE_STATUSBAR, "blizzard-default", "Blizzard Default", DEFAULT_STATUSBAR_PATH, {
    source = "Blizzard",
    provider = PROVIDER_BLIZZARD,
    category = "Blizzard",
    sortName = "blizzard default",
    verified = true,
})

MediaRegistry.RegisterBuiltin(MEDIA_TYPE_STATUSBAR, "raid-hp-fill", "Raid HP Fill", "Interface\\RaidFrame\\Raid-Bar-Hp-Fill", {
    source = "Blizzard",
    provider = PROVIDER_BLIZZARD,
    category = "Blizzard",
    sortName = "raid hp fill",
    verified = true,
})

MediaRegistry.RegisterBuiltin(MEDIA_TYPE_STATUSBAR, "flat-white", "Flat", "Interface\\Buttons\\WHITE8X8", {
    source = "Blizzard",
    provider = PROVIDER_BLIZZARD,
    category = "Blizzard",
    sortName = "flat",
    verified = true,
})

MediaRegistry.RegisterBuiltin(MEDIA_TYPE_STATUSBAR, "greyscale-ramp", "Greyscale Ramp", "Interface\\Buttons\\GreyscaleRamp64", {
    source = "Blizzard",
    provider = PROVIDER_BLIZZARD,
    category = "Blizzard",
    sortName = "greyscale ramp",
    verified = true,
})

MediaRegistry.RegisterBuiltin(MEDIA_TYPE_STATUSBAR, "better-blizzard", "Better Blizzard", "Interface\\AddOns\\FocalPoint\\Media\\Textures\\BetterBlizzard.blp", {
    sortName = "better blizzard",
    verified = true,
})

MediaRegistry.RegisterBuiltin(MEDIA_TYPE_STATUSBAR, "gradient", "Gradient", "Interface\\AddOns\\FocalPoint\\Media\\Textures\\Gradient.png", {
    sortName = "gradient",
    verified = true,
})

MediaRegistry.RegisterBuiltin(MEDIA_TYPE_STATUSBAR, "healbot", "Healbot", "Interface\\AddOns\\FocalPoint\\Media\\Textures\\Healbot.tga", {
    sortName = "healbot",
    verified = true,
})

MediaRegistry.RegisterBuiltin(MEDIA_TYPE_STATUSBAR, "simple-gray", "Focal Point Simple Gray", "Interface\\AddOns\\FocalPoint\\Media\\Textures\\fp_simple_gray_256x32.png", {
    sortName = "focal point simple gray",
    verified = true,
})

MediaRegistry.RegisterBuiltin(MEDIA_TYPE_STATUSBAR, "shadow1", "Shadow 1", "Interface\\AddOns\\FocalPoint\\Media\\Textures\\shadow1.png", {
    sortName = "shadow 1",
    verified = true,
})

MediaRegistry.RegisterBuiltin(MEDIA_TYPE_STATUSBAR, "simple-3d-gray", "Focal Point Simple 3D Gray", "Interface\\AddOns\\FocalPoint\\Media\\Textures\\fp_button_simple3d_gray_normal_256x32.png", {
    available = false,
    sortName = "focal point simple 3d gray",
    verified = true,
})

return MediaRegistry
