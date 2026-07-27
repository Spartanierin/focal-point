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
local debugState = {
    enabled = false,
    totalComparisons = 0,
    legacyCompatibleComparisons = 0,
    legacyCompatibleMismatches = 0,
    newReferenceObservations = 0,
    invalidReferences = 0,
    fallbackUses = 0,
    byReferenceKind = {},
    byMediaField = {},
    byUnit = {},
    byUnitAndField = {},
    bySource = {},
    details = {},
    lastMismatch = nil,
}
local MAX_DEBUG_DETAILS = 20

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

local function IncrementCounter(bucket, key)
    key = tostring(key or "unknown")
    bucket[key] = (bucket[key] or 0) + 1
end

local function NormalizeContextValue(value)
    if type(value) ~= "string" or Trim(value) == "" then
        return "unknown"
    end

    return value
end

local function ResetDebugState()
    debugState.totalComparisons = 0
    debugState.legacyCompatibleComparisons = 0
    debugState.legacyCompatibleMismatches = 0
    debugState.newReferenceObservations = 0
    debugState.invalidReferences = 0
    debugState.fallbackUses = 0
    debugState.byReferenceKind = {}
    debugState.byMediaField = {}
    debugState.byUnit = {}
    debugState.byUnitAndField = {}
    debugState.bySource = {}
    debugState.details = {}
    debugState.lastMismatch = nil
end

local function ClassifyReference(reference, mediaType)
    local parsed, reason = ParseReference(reference, mediaType)
    if not parsed then
        if type(reference) ~= "string" or reference == "" then
            return "nil/default", nil, reason
        end
        return "invalid", nil, reason
    end

    if parsed.kind == "builtin" then
        return "fp-id", parsed
    end
    if parsed.kind == "external" then
        return "lsm-id", parsed
    end
    if parsed.kind == "legacy" then
        if type(reference) == "string" and reference:match("^path:") then
            return "path-id", parsed
        end
        return "direct-path", parsed
    end

    return "invalid", parsed, reason
end

local function IsLegacyCompatibleKind(kind)
    return kind == "direct-path" or kind == "nil/default"
end

local function GetSafePath(value)
    if type(value) == "string" and value ~= "" then
        return value
    end

    return DEFAULT_STATUSBAR_PATH
end

local function AddDebugDetail(detail)
    if #debugState.details >= MAX_DEBUG_DETAILS then
        return
    end

    debugState.details[#debugState.details + 1] = detail
end

local function FormatBool(value)
    return value and "true" or "false"
end

local function AppendSortedCounters(lines, title, counters)
    lines[#lines + 1] = title

    local keys = {}
    for key in pairs(counters or {}) do
        keys[#keys + 1] = key
    end
    table.sort(keys)

    if #keys == 0 then
        lines[#lines + 1] = "  none"
        return
    end

    for _, key in ipairs(keys) do
        lines[#lines + 1] = string.format("  %s=%d", tostring(key), tonumber(counters[key]) or 0)
    end
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

local function BuildResolveResult(reference, mediaType)
    return {
        requestedReference = reference,
        normalizedReference = nil,
        mediaType = mediaType,
        entry = nil,
        resolvedAsset = nil,
        available = false,
        fallbackUsed = false,
        reason = nil,
        source = nil,
        provider = nil,
        fallbackReference = nil,
        fallbackEntry = nil,
    }
end

local function IsEmptyReference(reference)
    if reference == nil then
        return true
    end

    return type(reference) == "string" and Trim(reference) == ""
end

local function ResolveAvailableEntry(reference, mediaType)
    local entry = MediaRegistry.GetEntry(reference, mediaType)
    if entry and entry.available == true and type(entry.path) == "string" and entry.path ~= "" then
        local normalizedReference = MediaRegistry.NormalizeReference(reference, mediaType)
        return entry.path, entry, normalizedReference or entry.id
    end

    return nil, entry, nil
end

local function ResolveFallback(reference, mediaType, fallbackReference)
    local checked = {}

    local function TryFallback(candidate)
        if type(candidate) ~= "string" or Trim(candidate) == "" or checked[candidate] then
            return nil, nil, nil
        end

        checked[candidate] = true
        if candidate == reference then
            return nil, nil, nil
        end

        return ResolveAvailableEntry(candidate, mediaType)
    end

    local path, entry, normalizedReference = TryFallback(fallbackReference)
    if path then
        return path, entry, normalizedReference
    end

    path, entry, normalizedReference = TryFallback(MediaRegistry.GetDefault(mediaType))
    if path then
        return path, entry, normalizedReference
    end

    if NormalizeMediaType(mediaType) == MEDIA_TYPE_STATUSBAR then
        return DEFAULT_STATUSBAR_PATH, nil, DEFAULT_STATUSBAR_REFERENCE
    end

    return nil, nil, nil
end

function MediaRegistry.ResolveReference(reference, mediaType, fallbackReference)
    local normalizedType = NormalizeMediaType(mediaType) or MEDIA_TYPE_STATUSBAR
    local result = BuildResolveResult(reference, normalizedType)

    local invalidInputType = reference ~= nil and type(reference) ~= "string"
    local parsed, parseReason

    if invalidInputType then
        parseReason = "invalid_reference"
    elseif IsEmptyReference(reference) then
        parseReason = "empty_reference"
    else
        parsed, parseReason = ParseReference(reference, normalizedType)
    end

    if parsed then
        result.normalizedReference = MediaRegistry.NormalizeReference(reference, normalizedType)
        local path, entry = ResolveAvailableEntry(reference, normalizedType)
        result.entry = entry

        if path then
            result.resolvedAsset = path
            result.normalizedReference = result.normalizedReference or (entry and entry.id) or parsed.id
            result.available = true
            result.source = entry and entry.source or nil
            result.provider = entry and entry.provider or nil
            return result
        end

        if parsed.kind == "external" then
            parseReason = "unavailable"
        elseif parsed.kind == "builtin" then
            parseReason = "invalid_reference"
        else
            parseReason = parseReason or "unavailable"
        end
    else
        result.reason = parseReason or "invalid_reference"
    end

    local fallbackPath, fallbackEntry, fallbackNormalizedReference = ResolveFallback(reference, normalizedType, fallbackReference)
    result.resolvedAsset = fallbackPath
    result.fallbackEntry = fallbackEntry
    result.fallbackReference = fallbackNormalizedReference
    result.fallbackUsed = fallbackPath ~= nil
    result.reason = parseReason or result.reason or (fallbackPath and "unavailable" or "fallback_missing")

    if fallbackEntry then
        result.source = fallbackEntry.source
        result.provider = fallbackEntry.provider
    end

    if not fallbackPath and result.reason == nil then
        result.reason = "fallback_missing"
    end

    return result
end

function MediaRegistry.Resolve(reference, mediaType, fallbackReference)
    local result = MediaRegistry.ResolveReference(reference, mediaType, fallbackReference)
    if not result then
        return nil, nil
    end

    return result.resolvedAsset, result.fallbackEntry or result.entry
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

function MediaRegistry.SetDebugEnabled(enabled)
    debugState.enabled = enabled == true
    return debugState.enabled
end

function MediaRegistry.IsDebugEnabled()
    return debugState.enabled == true
end

function MediaRegistry.ResetDebug()
    ResetDebugState()
end

function MediaRegistry.RecordStatusBarShadow(reference, legacyPath, context, resolvedResult)
    if debugState.enabled ~= true then
        return
    end

    local mediaType = MEDIA_TYPE_STATUSBAR
    local referenceKind, parsedReference, parseReason = ClassifyReference(reference, mediaType)
    local legacyEffectivePath = GetSafePath(legacyPath)
    local originalEntry = MediaRegistry.GetEntry(reference, mediaType)
    resolvedResult = type(resolvedResult) == "table" and resolvedResult or MediaRegistry.ResolveReference(reference, mediaType, DEFAULT_STATUSBAR_REFERENCE)
    local registryPath = resolvedResult and resolvedResult.resolvedAsset or nil
    local registryEntry = resolvedResult and (resolvedResult.entry or resolvedResult.fallbackEntry) or nil
    local registryEffectivePath = registryPath or DEFAULT_STATUSBAR_PATH
    local registryAvailable = originalEntry and originalEntry.available == true or false
    local source = originalEntry and originalEntry.source or "Fallback"
    local unitKey = NormalizeContextValue(type(context) == "table" and context.unitKey or nil)
    local field = NormalizeContextValue(type(context) == "table" and context.field or nil)
    local referenceSourceField = NormalizeContextValue(type(context) == "table" and context.referenceSourceField or nil)
    if referenceSourceField == "unknown" then
        referenceSourceField = field
    end
    local usedFallback = not (originalEntry
        and originalEntry.available == true
        and type(originalEntry.path) == "string"
        and originalEntry.path ~= ""
        and originalEntry.path == registryEffectivePath)
    local legacyUsedFallback = legacyEffectivePath == DEFAULT_STATUSBAR_PATH and not (type(reference) == "string" and reference ~= "")
    local isLegacyCompatible = IsLegacyCompatibleKind(referenceKind)
    local isMismatch = isLegacyCompatible and legacyEffectivePath ~= registryEffectivePath

    debugState.totalComparisons = debugState.totalComparisons + 1
    IncrementCounter(debugState.byReferenceKind, referenceKind)
    IncrementCounter(debugState.byMediaField, field)
    IncrementCounter(debugState.byUnit, unitKey)
    IncrementCounter(debugState.byUnitAndField, unitKey .. "." .. field)
    IncrementCounter(debugState.bySource, source)

    if isLegacyCompatible then
        debugState.legacyCompatibleComparisons = debugState.legacyCompatibleComparisons + 1
        if isMismatch then
            debugState.legacyCompatibleMismatches = debugState.legacyCompatibleMismatches + 1
        end
    elseif referenceKind == "fp-id" or referenceKind == "lsm-id" or referenceKind == "path-id" then
        debugState.newReferenceObservations = debugState.newReferenceObservations + 1
    else
        debugState.invalidReferences = debugState.invalidReferences + 1
    end

    if usedFallback then
        debugState.fallbackUses = debugState.fallbackUses + 1
    end

    local detail = {
        reference = tostring(reference),
        kind = referenceKind,
        unitKey = unitKey,
        field = field,
        referenceSourceField = referenceSourceField,
        legacyPath = legacyEffectivePath,
        registryPath = registryEffectivePath,
        legacyFallback = legacyUsedFallback,
        registryFallback = usedFallback,
        registryAvailable = registryAvailable,
        source = source,
        reason = parseReason,
        mismatch = isMismatch,
    }

    if isMismatch then
        debugState.lastMismatch = detail
    end

    AddDebugDetail(detail)
end

function MediaRegistry.BuildDebugReport()
    local lines = {
        "Media Registry shadow report",
        string.format("enabled=%s", FormatBool(debugState.enabled == true)),
        string.format("Comparisons=%d", tonumber(debugState.totalComparisons) or 0),
        string.format("Legacy-compatible comparisons=%d", tonumber(debugState.legacyCompatibleComparisons) or 0),
        string.format("Legacy-compatible mismatches=%d", tonumber(debugState.legacyCompatibleMismatches) or 0),
        string.format("New reference observations=%d", tonumber(debugState.newReferenceObservations) or 0),
        string.format("Invalid references=%d", tonumber(debugState.invalidReferences) or 0),
        string.format("Fallback uses=%d", tonumber(debugState.fallbackUses) or 0),
    }

    AppendSortedCounters(lines, "By reference kind", debugState.byReferenceKind)
    AppendSortedCounters(lines, "By media field", debugState.byMediaField)
    AppendSortedCounters(lines, "By unit", debugState.byUnit)
    AppendSortedCounters(lines, "By unit and field", debugState.byUnitAndField)
    AppendSortedCounters(lines, "By source", debugState.bySource)

    if debugState.lastMismatch then
        local detail = debugState.lastMismatch
        lines[#lines + 1] = string.format(
            "Last mismatch kind=%s unit=%s field=%s reference=%s legacy=%s registry=%s",
            tostring(detail.kind),
            tostring(detail.unitKey),
            tostring(detail.field),
            tostring(detail.reference),
            tostring(detail.legacyPath),
            tostring(detail.registryPath)
        )
    else
        lines[#lines + 1] = "Last mismatch=none"
    end

    lines[#lines + 1] = string.format("Details=%d/%d", #debugState.details, MAX_DEBUG_DETAILS)
    for index, detail in ipairs(debugState.details) do
        lines[#lines + 1] = string.format(
            "%02d kind=%s unit=%s field=%s sourceField=%s source=%s available=%s legacyFallback=%s registryFallback=%s mismatch=%s reference=%s legacy=%s registry=%s",
            index,
            tostring(detail.kind),
            tostring(detail.unitKey),
            tostring(detail.field),
            tostring(detail.referenceSourceField),
            tostring(detail.source),
            FormatBool(detail.registryAvailable),
            FormatBool(detail.legacyFallback),
            FormatBool(detail.registryFallback),
            FormatBool(detail.mismatch),
            tostring(detail.reference),
            tostring(detail.legacyPath),
            tostring(detail.registryPath)
        )
    end

    return lines
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

return MediaRegistry
