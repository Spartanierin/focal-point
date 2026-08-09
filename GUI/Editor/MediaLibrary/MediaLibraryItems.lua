local _, ns = ...

ns.GUI = ns.GUI or {}
ns.GUI.Editor = ns.GUI.Editor or {}
ns.GUI.Editor.MediaLibrary = ns.GUI.Editor.MediaLibrary or {}

local MediaLibraryItems = {}
ns.GUI.Editor.MediaLibrary.MediaLibraryItems = MediaLibraryItems

local STATUSBAR = "statusbar"
local FONT = "font"
local DECORATION = "decoration"
local DEFAULT_STATUSBAR_REFERENCE = "fp:statusbar:blizzard-default"
local DEFAULT_FONT_REFERENCE = "fp:font:standard"
local DEFAULT_DECORATION_REFERENCE = "fp:decoration:shadow1"
local L = ns.L or {}

local SOURCE_ORDER = {
    Blizzard = 1,
    ["Focal Point"] = 2,
    Shared = 3,
    ["Legacy Path"] = 4,
    Unavailable = 5,
    External = 6,
}

local SOURCE_LABEL_KEYS = {
    Blizzard = "MEDIA_SOURCE_BLIZZARD",
    ["Focal Point"] = "MEDIA_SOURCE_FOCAL_POINT",
    Shared = "MEDIA_SOURCE_SHARED",
    ["Legacy Path"] = "MEDIA_SOURCE_LEGACY_PATH",
    Unavailable = "MEDIA_SOURCE_UNAVAILABLE",
}

local function Trim(value)
    if type(value) ~= "string" then
        return ""
    end

    return (value:gsub("^%s+", ""):gsub("%s+$", ""))
end

local function IsNonEmptyString(value)
    return type(value) == "string" and Trim(value) ~= ""
end

local function IsReferenceId(value)
    return type(value) == "string" and value:match("^[^:]+:[^:]+:.+") ~= nil
end

local function GetDefaultReference(mediaType, explicitDefault)
    if IsNonEmptyString(explicitDefault) then
        return explicitDefault
    end

    if mediaType == FONT then
        return DEFAULT_FONT_REFERENCE
    end
    if mediaType == DECORATION then
        return DEFAULT_DECORATION_REFERENCE
    end

    return DEFAULT_STATUSBAR_REFERENCE
end

local function GetDisplayName(entry)
    if type(entry) ~= "table" then
        return nil
    end

    if IsNonEmptyString(entry.name) then
        return entry.name
    end

    if IsNonEmptyString(entry.providerKey) then
        return entry.providerKey
    end

    if IsNonEmptyString(entry.id) then
        return entry.id
    end

    return nil
end

local function GetFilenameLabel(path)
    path = Trim(path)
    if path == "" then
        return nil
    end

    local filename = path:match("([^\\/:]+)$") or path
    filename = filename:gsub("%.[^%.]+$", "")
    return filename ~= "" and filename or path
end

local function GetMissingLabel(reference, mediaType)
    reference = Trim(reference)
    local key = reference:match("^[^:]+:[^:]+:(.+)$") or reference
    if key == "" then
        if mediaType == FONT then
            return L["MEDIA_MISSING_FONT"] or "Missing Font"
        end
        return L["MEDIA_MISSING_TEXTURE"] or "Missing Texture"
    end

    local format = mediaType == FONT
        and (L["MEDIA_MISSING_FONT_FORMAT"] or "Missing: %s")
        or (L["MEDIA_MISSING_TEXTURE_FORMAT"] or "Missing: %s")
    return string.format(format, key)
end

local function GetCustomLabel(mediaType)
    if mediaType == FONT then
        return L["MEDIA_CUSTOM_FONT"] or "Custom Font"
    end

    return L["MEDIA_CUSTOM_TEXTURE"] or "Custom Texture"
end

local function GetCurrentLabel(label, mediaType)
    label = IsNonEmptyString(label) and label or GetCustomLabel(mediaType)
    local format = mediaType == FONT
        and (L["MEDIA_CURRENT_FONT_FORMAT"] or "%s (Current)")
        or (L["MEDIA_CURRENT_TEXTURE_FORMAT"] or "%s (Current)")
    return string.format(format, label)
end

local function GetSourceLabel(source)
    if not IsNonEmptyString(source) then
        return nil
    end

    local key = SOURCE_LABEL_KEYS[source]
    return (key and L[key]) or source
end

local function GetEntrySource(entry)
    if type(entry) ~= "table" then
        return nil
    end

    return IsNonEmptyString(entry.source) and entry.source
        or (IsNonEmptyString(entry.category) and entry.category or nil)
end

local function FormatFontLabel(label, entry)
    label = IsNonEmptyString(label) and label or ""
    local sourceLabel = GetSourceLabel(GetEntrySource(entry))
    if not IsNonEmptyString(sourceLabel) then
        return label
    end

    local format = L["MEDIA_FONT_SOURCE_FORMAT"] or "%s \194\183 %s"
    return string.format(format, sourceLabel, label)
end

local function FormatOptionLabel(mediaType, label, entry)
    if mediaType == FONT then
        return FormatFontLabel(label, entry)
    end

    return label
end

local function GetEntryOrder(entry)
    return SOURCE_ORDER[entry and entry.source] or SOURCE_ORDER[entry and entry.category] or 50
end

local function GetSortLabel(label)
    return Trim(label):lower()
end

local function NormalizeAssetPath(path)
    path = Trim(path)
    if path == "" then
        return nil
    end

    return path:gsub("/", "\\"):lower()
end

local function SortItems(left, right)
    if left.sourceRank ~= right.sourceRank then
        return left.sourceRank < right.sourceRank
    end

    local leftSortLabel = left.sortLabel or GetSortLabel(left.label)
    local rightSortLabel = right.sortLabel or GetSortLabel(right.label)
    if leftSortLabel ~= rightSortLabel then
        return leftSortLabel < rightSortLabel
    end

    local leftName = left.name or ""
    local rightName = right.name or ""
    if leftName ~= rightName then
        return leftName < rightName
    end

    return (left.value or "") < (right.value or "")
end

local function IsPreferredCandidate(candidate, current)
    if not current then
        return true
    end

    if candidate.sourceRank ~= current.sourceRank then
        return candidate.sourceRank < current.sourceRank
    end

    if candidate.sortLabel ~= current.sortLabel then
        return candidate.sortLabel < current.sortLabel
    end

    if candidate.name ~= current.name then
        return candidate.name < current.name
    end

    return candidate.value < current.value
end

local function GetReferenceKind(value, legacy, missing)
    if legacy then
        return "legacy"
    end
    if missing then
        return "missing"
    end
    if type(value) == "string" and value:match("^fp:") then
        return "builtin"
    end
    if type(value) == "string" and value:match("^lsm:") then
        return "shared"
    end
    if IsReferenceId(value) then
        return "reference"
    end
    return "path"
end

local function CreateItem(value, label, entry, mediaType, options)
    options = type(options) == "table" and options or {}
    local source = GetEntrySource(entry) or options.source or "Unavailable"
    local name = IsNonEmptyString(options.name) and options.name
        or GetDisplayName(entry)
        or GetFilenameLabel(value)
        or value
    local resolvedAsset = IsNonEmptyString(options.resolvedAsset) and options.resolvedAsset
        or (type(entry) == "table" and entry.path or nil)
    local missing = options.missing == true
    local legacy = options.legacy == true
    local available = options.available
    if available == nil then
        available = type(entry) == "table" and entry.available ~= false and IsNonEmptyString(entry.path)
    end

    return {
        id = value,
        value = value,
        mediaType = mediaType,
        name = name,
        label = IsNonEmptyString(label) and label or name,
        source = source,
        sourceRank = SOURCE_ORDER[source] or 50,
        provider = type(entry) == "table" and entry.provider or nil,
        resolvedAsset = resolvedAsset,
        available = available == true,
        missing = missing,
        legacy = legacy,
        current = options.current == true,
        referenceKind = GetReferenceKind(value, legacy, missing),
        dedupeKey = options.dedupeKey or NormalizeAssetPath(resolvedAsset),
        sortLabel = GetSortLabel(options.sortLabel or label or name),
        selectable = options.selectable ~= false,
        entry = entry,
    }
end

local function AddItem(items, seen, value, label, entry, mediaType, options)
    if not IsNonEmptyString(value) or seen[value] then
        return nil
    end

    local item = CreateItem(value, label, entry, mediaType, options)
    seen[value] = true
    items[#items + 1] = item
    return item
end

local function RemoveItem(items, seen, value)
    if not IsNonEmptyString(value) or not seen[value] then
        return
    end

    seen[value] = nil

    for index = #items, 1, -1 do
        if items[index].value == value then
            table.remove(items, index)
            return
        end
    end
end

local function AddRegularAvailableEntries(items, seen, entries, mediaType)
    local preferredByPath = {}
    local pathOrder = {}
    local undeduplicated = {}

    for _, entry in ipairs(entries or {}) do
        local value = entry and entry.id
        local label = GetDisplayName(entry)
        if IsNonEmptyString(value) then
            local candidate = {
                value = value,
                name = IsNonEmptyString(label) and label or value,
                label = IsNonEmptyString(label) and label or value,
                sortLabel = GetSortLabel(label or value),
                sourceRank = GetEntryOrder(entry),
                entry = entry,
                dedupeKey = NormalizeAssetPath(entry and entry.path),
            }
            if candidate.dedupeKey then
                if not preferredByPath[candidate.dedupeKey] then
                    pathOrder[#pathOrder + 1] = candidate.dedupeKey
                end
                if IsPreferredCandidate(candidate, preferredByPath[candidate.dedupeKey]) then
                    preferredByPath[candidate.dedupeKey] = candidate
                end
            else
                undeduplicated[#undeduplicated + 1] = candidate
            end
        end
    end

    for _, pathKey in ipairs(pathOrder) do
        local candidate = preferredByPath[pathKey]
        if candidate then
            AddItem(
                items,
                seen,
                candidate.value,
                FormatOptionLabel(mediaType, candidate.label, candidate.entry),
                candidate.entry,
                mediaType,
                {
                    name = candidate.name,
                    sortLabel = candidate.label,
                    dedupeKey = candidate.dedupeKey,
                }
            )
        end
    end

    for _, candidate in ipairs(undeduplicated) do
        AddItem(
            items,
            seen,
            candidate.value,
            FormatOptionLabel(mediaType, candidate.label, candidate.entry),
            candidate.entry,
            mediaType,
            {
                name = candidate.name,
                sortLabel = candidate.label,
                dedupeKey = candidate.dedupeKey,
            }
        )
    end
end

local function MatchesSourceFilter(item, sourceFilter)
    sourceFilter = Trim(sourceFilter)
    if sourceFilter == "" or sourceFilter == "all" then
        return true
    end

    return item and item.source == sourceFilter
end

local function MatchesSearchText(item, searchText)
    searchText = Trim(searchText):lower()
    if searchText == "" then
        return true
    end

    local haystack = table.concat({
        tostring(item and item.label or ""),
        tostring(item and item.name or ""),
        tostring(item and item.value or ""),
        tostring(item and item.resolvedAsset or ""),
        tostring(item and item.source or ""),
    }, "\n"):lower()

    return haystack:find(searchText, 1, true) ~= nil
end

local function ApplyFilters(items, options)
    options = type(options) == "table" and options or {}
    if not IsNonEmptyString(options.sourceFilter) and not IsNonEmptyString(options.searchText) then
        return items
    end

    local filtered = {}
    for _, item in ipairs(items) do
        if MatchesSourceFilter(item, options.sourceFilter) and MatchesSearchText(item, options.searchText) then
            filtered[#filtered + 1] = item
        end
    end
    return filtered
end

local function FindItemByValue(items, value)
    if not IsNonEmptyString(value) then
        return nil
    end

    for _, item in ipairs(items or {}) do
        if item.value == value then
            return item
        end
    end

    return nil
end

function MediaLibraryItems.Build(mediaType, currentValue, options)
    options = type(options) == "table" and options or {}
    local Registry = ns.MediaRegistry
    local items = {}
    local seen = {}
    local selectedValue = currentValue
    local defaultReference = GetDefaultReference(mediaType, options.defaultReference)

    if not (Registry and Registry.GetAvailable and Registry.ResolveReference and Registry.GetEntry) then
        return {
            items = items,
            currentItem = nil,
            metadata = {
                mediaType = mediaType,
                selectedValue = selectedValue,
                defaultReference = defaultReference,
                registryAvailable = false,
            },
        }
    end

    local entries = Registry.GetAvailable(mediaType, { availableOnly = options.availableOnly ~= false })
    if options.deduplicate ~= false then
        AddRegularAvailableEntries(items, seen, entries, mediaType)
    else
        for _, entry in ipairs(entries or {}) do
            local value = entry and entry.id
            local label = GetDisplayName(entry)
            AddItem(items, seen, value, FormatOptionLabel(mediaType, label, entry), entry, mediaType, {
                name = label,
                sortLabel = label,
            })
        end
    end

    local hasCurrentValue = IsNonEmptyString(currentValue)
    if hasCurrentValue and options.includeCurrent ~= false then
        local result = Registry.ResolveReference(currentValue, mediaType, defaultReference)
        local entry = Registry.GetEntry(currentValue, mediaType)

        if result and result.available == true and type(entry) == "table" then
            local label = GetDisplayName(entry) or GetFilenameLabel(result.resolvedAsset) or currentValue
            if IsReferenceId(currentValue) then
                if not seen[currentValue] then
                    local currentLabel = GetCurrentLabel(label, mediaType)
                    AddItem(
                        items,
                        seen,
                        currentValue,
                        FormatOptionLabel(mediaType, currentLabel, entry),
                        entry,
                        mediaType,
                        {
                            name = label,
                            sortLabel = currentLabel,
                            resolvedAsset = result.resolvedAsset,
                            current = true,
                        }
                    )
                else
                    local currentItem = FindItemByValue(items, currentValue)
                    if currentItem then
                        currentItem.current = true
                    end
                end
            elseif not seen[currentValue] then
                if mediaType ~= FONT then
                    RemoveItem(items, seen, entry.id)
                end
                AddItem(
                    items,
                    seen,
                    currentValue,
                    FormatOptionLabel(mediaType, label, entry),
                    entry,
                    mediaType,
                    {
                        name = label,
                        sortLabel = label,
                        resolvedAsset = result.resolvedAsset,
                        current = true,
                        legacy = true,
                    }
                )
            end
        elseif IsReferenceId(currentValue) and options.includeUnavailable ~= false then
            local missingLabel = GetMissingLabel(currentValue, mediaType)
            local missingEntry = {
                id = currentValue,
                name = missingLabel,
                mediaType = mediaType,
                source = "Unavailable",
                category = "Unavailable",
                available = false,
            }
            AddItem(
                items,
                seen,
                currentValue,
                FormatOptionLabel(mediaType, missingLabel, missingEntry),
                missingEntry,
                mediaType,
                {
                    name = missingLabel,
                    sortLabel = missingLabel,
                    current = true,
                    missing = true,
                    available = false,
                    selectable = false,
                }
            )
        elseif options.includeLegacy ~= false then
            local legacyLabel = mediaType == FONT
                and GetCustomLabel(mediaType)
                or (GetFilenameLabel(currentValue) or GetCustomLabel(mediaType))
            local legacyEntry = {
                id = currentValue,
                name = legacyLabel,
                mediaType = mediaType,
                source = "Legacy Path",
                category = "Legacy",
                path = currentValue,
                available = true,
            }
            AddItem(
                items,
                seen,
                currentValue,
                FormatOptionLabel(mediaType, legacyLabel, legacyEntry),
                legacyEntry,
                mediaType,
                {
                    name = legacyLabel,
                    sortLabel = legacyLabel,
                    resolvedAsset = currentValue,
                    current = true,
                    legacy = true,
                }
            )
        end
    elseif not hasCurrentValue then
        local result = Registry.ResolveReference(currentValue, mediaType, defaultReference)
        selectedValue = result
            and (result.fallbackReference or (result.fallbackEntry and result.fallbackEntry.id))
            or defaultReference
        if IsNonEmptyString(selectedValue) and not seen[selectedValue] then
            local entry = Registry.GetEntry(selectedValue, mediaType)
            local label = GetDisplayName(entry) or GetFilenameLabel(selectedValue)
            AddItem(
                items,
                seen,
                selectedValue,
                FormatOptionLabel(mediaType, label, entry),
                entry,
                mediaType,
                {
                    name = label,
                    sortLabel = label,
                    current = true,
                }
            )
        else
            local currentItem = FindItemByValue(items, selectedValue)
            if currentItem then
                currentItem.current = true
            end
        end
    end

    table.sort(items, SortItems)

    local filteredItems = ApplyFilters(items, options)
    local currentItem = FindItemByValue(items, selectedValue)

    return {
        items = filteredItems,
        currentItem = currentItem,
        metadata = {
            mediaType = mediaType,
            selectedValue = selectedValue,
            defaultReference = defaultReference,
            registryAvailable = true,
            totalItems = #items,
            filteredItems = #filteredItems,
        },
    }
end

return MediaLibraryItems
