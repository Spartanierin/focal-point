local _, ns = ...

ns.GUI = ns.GUI or {}
ns.GUI.Editor = ns.GUI.Editor or {}
ns.GUI.Editor.Inspector = ns.GUI.Editor.Inspector or {}

local MediaOptionAdapter = {}
ns.GUI.Editor.Inspector.MediaOptionAdapter = MediaOptionAdapter

local STATUSBAR = "statusbar"
local FONT = "font"
local DEFAULT_STATUSBAR_REFERENCE = "fp:statusbar:blizzard-default"
local DEFAULT_FONT_REFERENCE = "fp:font:standard"
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

    local format = L["MEDIA_FONT_SOURCE_FORMAT"] or "%s · %s"
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
    if left.order ~= right.order then
        return left.order < right.order
    end

    local leftSortLabel = left.sortLabel or GetSortLabel(left.label)
    local rightSortLabel = right.sortLabel or GetSortLabel(right.label)
    if leftSortLabel ~= rightSortLabel then
        return leftSortLabel < rightSortLabel
    end

    if left.label ~= right.label then
        return left.label < right.label
    end

    return left.value < right.value
end

local function IsPreferredCandidate(candidate, current)
    if not current then
        return true
    end

    if candidate.order ~= current.order then
        return candidate.order < current.order
    end

    if candidate.sortLabel ~= current.sortLabel then
        return candidate.sortLabel < current.sortLabel
    end

    if candidate.label ~= current.label then
        return candidate.label < current.label
    end

    return candidate.value < current.value
end

local function AddItem(items, values, seen, value, label, entry, sortLabel)
    if not IsNonEmptyString(value) or seen[value] then
        return
    end

    label = IsNonEmptyString(label) and label or value
    seen[value] = true
    values[value] = label
    items[#items + 1] = {
        value = value,
        label = label,
        sortLabel = GetSortLabel(sortLabel or label),
        order = GetEntryOrder(entry),
    }
end

local function AddRegularAvailableEntries(items, values, seen, entries, mediaType)
    local preferredByPath = {}
    local pathOrder = {}
    local undeduplicated = {}

    for _, entry in ipairs(entries or {}) do
        local value = entry and entry.id
        local label = GetDisplayName(entry)
        if IsNonEmptyString(value) then
            local candidate = {
                value = value,
                label = IsNonEmptyString(label) and label or value,
                sortLabel = GetSortLabel(label or value),
                order = GetEntryOrder(entry),
                entry = entry,
            }
            local pathKey = NormalizeAssetPath(entry and entry.path)
            if pathKey then
                if not preferredByPath[pathKey] then
                    pathOrder[#pathOrder + 1] = pathKey
                end
                if IsPreferredCandidate(candidate, preferredByPath[pathKey]) then
                    preferredByPath[pathKey] = candidate
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
                values,
                seen,
                candidate.value,
                FormatOptionLabel(mediaType, candidate.label, candidate.entry),
                candidate.entry,
                candidate.label
            )
        end
    end

    for _, candidate in ipairs(undeduplicated) do
        AddItem(
            items,
            values,
            seen,
            candidate.value,
            FormatOptionLabel(mediaType, candidate.label, candidate.entry),
            candidate.entry,
            candidate.label
        )
    end
end

local function RemoveItem(items, values, seen, value)
    if not IsNonEmptyString(value) or not seen[value] then
        return
    end

    seen[value] = nil
    values[value] = nil

    for index = #items, 1, -1 do
        if items[index].value == value then
            table.remove(items, index)
            return
        end
    end
end

local function BuildOrder(items)
    table.sort(items, SortItems)

    local order = {}
    for _, item in ipairs(items) do
        order[#order + 1] = item.value
    end

    return order
end

local function BuildMediaDropdown(mediaType, currentValue, defaultReference)
    local Registry = ns.MediaRegistry
    local values = {}
    local seen = {}
    local items = {}
    local selectedValue = currentValue

    if not (Registry and Registry.GetAvailable and Registry.ResolveReference and Registry.GetEntry) then
        return {
            values = values,
            order = {},
            value = selectedValue,
        }
    end

    local entries = Registry.GetAvailable(mediaType, { availableOnly = true })
    AddRegularAvailableEntries(items, values, seen, entries, mediaType)

    local hasCurrentValue = IsNonEmptyString(currentValue)
    if hasCurrentValue then
        local result = Registry.ResolveReference(currentValue, mediaType, defaultReference)
        local entry = Registry.GetEntry(currentValue, mediaType)

        if result and result.available == true and type(entry) == "table" then
            local label = GetDisplayName(entry) or GetFilenameLabel(result.resolvedAsset) or currentValue
            if IsReferenceId(currentValue) then
                if not seen[currentValue] then
                    local currentLabel = GetCurrentLabel(label, mediaType)
                    AddItem(
                        items,
                        values,
                        seen,
                        currentValue,
                        FormatOptionLabel(mediaType, currentLabel, entry),
                        entry,
                        currentLabel
                    )
                end
            elseif not seen[currentValue] then
                if mediaType ~= FONT then
                    RemoveItem(items, values, seen, entry.id)
                end
                AddItem(
                    items,
                    values,
                    seen,
                    currentValue,
                    FormatOptionLabel(mediaType, label, entry),
                    entry,
                    label
                )
            end
        elseif IsReferenceId(currentValue) then
            local missingLabel = GetMissingLabel(currentValue, mediaType)
            local missingEntry = {
                source = "Unavailable",
                category = "Unavailable",
            }
            AddItem(
                items,
                values,
                seen,
                currentValue,
                FormatOptionLabel(mediaType, missingLabel, missingEntry),
                missingEntry,
                missingLabel
            )
        else
            local legacyLabel = mediaType == FONT
                and GetCustomLabel(mediaType)
                or (GetFilenameLabel(currentValue) or GetCustomLabel(mediaType))
            local legacyEntry = {
                source = "Legacy Path",
                category = "Legacy",
            }
            AddItem(
                items,
                values,
                seen,
                currentValue,
                FormatOptionLabel(mediaType, legacyLabel, legacyEntry),
                legacyEntry,
                legacyLabel
            )
        end
    else
        local result = Registry.ResolveReference(currentValue, mediaType, defaultReference)
        selectedValue = result
            and (result.fallbackReference or (result.fallbackEntry and result.fallbackEntry.id))
            or defaultReference
        if IsNonEmptyString(selectedValue) and not seen[selectedValue] then
            local entry = Registry.GetEntry(selectedValue, mediaType)
            local label = GetDisplayName(entry) or GetFilenameLabel(selectedValue)
            AddItem(
                items,
                values,
                seen,
                selectedValue,
                FormatOptionLabel(mediaType, label, entry),
                entry,
                label
            )
        end
    end

    return {
        values = values,
        order = BuildOrder(items),
        value = selectedValue,
    }
end

function MediaOptionAdapter.BuildStatusBarDropdown(currentValue)
    return BuildMediaDropdown(STATUSBAR, currentValue, DEFAULT_STATUSBAR_REFERENCE)
end

function MediaOptionAdapter.BuildFontDropdown(currentValue)
    return BuildMediaDropdown(FONT, currentValue, DEFAULT_FONT_REFERENCE)
end

return MediaOptionAdapter
