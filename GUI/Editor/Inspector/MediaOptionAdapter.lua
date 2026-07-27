local _, ns = ...

ns.GUI = ns.GUI or {}
ns.GUI.Editor = ns.GUI.Editor or {}
ns.GUI.Editor.Inspector = ns.GUI.Editor.Inspector or {}

local MediaOptionAdapter = {}
ns.GUI.Editor.Inspector.MediaOptionAdapter = MediaOptionAdapter

local STATUSBAR = "statusbar"
local DEFAULT_STATUSBAR_REFERENCE = "fp:statusbar:blizzard-default"
local L = ns.L or {}

local SOURCE_ORDER = {
    Blizzard = 1,
    ["Focal Point"] = 2,
    Shared = 3,
    ["Legacy Path"] = 4,
    Unavailable = 5,
    External = 6,
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

local function GetMissingLabel(reference)
    reference = Trim(reference)
    local key = reference:match("^[^:]+:[^:]+:(.+)$") or reference
    if key == "" then
        return L["MEDIA_MISSING_TEXTURE"] or "Missing Texture"
    end

    local format = L["MEDIA_MISSING_TEXTURE_FORMAT"] or "Missing: %s"
    return string.format(format, key)
end

local function GetEntryOrder(entry)
    return SOURCE_ORDER[entry and entry.source] or SOURCE_ORDER[entry and entry.category] or 50
end

local function GetSortLabel(label)
    return Trim(label):lower()
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

local function AddItem(items, values, seen, value, label, entry)
    if not IsNonEmptyString(value) or seen[value] then
        return
    end

    label = IsNonEmptyString(label) and label or value
    seen[value] = true
    values[value] = label
    items[#items + 1] = {
        value = value,
        label = label,
        sortLabel = GetSortLabel(label),
        order = GetEntryOrder(entry),
    }
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

function MediaOptionAdapter.BuildStatusBarDropdown(currentValue)
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

    local entries = Registry.GetAvailable(STATUSBAR, { availableOnly = true })
    for _, entry in ipairs(entries) do
        AddItem(items, values, seen, entry.id, GetDisplayName(entry), entry)
    end

    local hasCurrentValue = IsNonEmptyString(currentValue)
    if hasCurrentValue then
        local result = Registry.ResolveReference(currentValue, STATUSBAR, DEFAULT_STATUSBAR_REFERENCE)
        local entry = Registry.GetEntry(currentValue, STATUSBAR)

        if result and result.available == true and type(entry) == "table" then
            local label = GetDisplayName(entry) or GetFilenameLabel(result.resolvedAsset) or currentValue
            if IsReferenceId(currentValue) then
                if not seen[currentValue] then
                    AddItem(items, values, seen, currentValue, label, entry)
                end
            elseif not seen[currentValue] then
                RemoveItem(items, values, seen, entry.id)
                AddItem(items, values, seen, currentValue, label, entry)
            end
        elseif IsReferenceId(currentValue) then
            AddItem(items, values, seen, currentValue, GetMissingLabel(currentValue), {
                source = "Unavailable",
                category = "Unavailable",
            })
        else
            AddItem(items, values, seen, currentValue, GetFilenameLabel(currentValue) or (L["MEDIA_CUSTOM_TEXTURE"] or "Custom Texture"), {
                source = "Legacy Path",
                category = "Legacy",
            })
        end
    else
        local result = Registry.ResolveReference(currentValue, STATUSBAR, DEFAULT_STATUSBAR_REFERENCE)
        selectedValue = result
            and (result.fallbackReference or (result.fallbackEntry and result.fallbackEntry.id))
            or DEFAULT_STATUSBAR_REFERENCE
        if IsNonEmptyString(selectedValue) and not seen[selectedValue] then
            local entry = Registry.GetEntry(selectedValue, STATUSBAR)
            AddItem(items, values, seen, selectedValue, GetDisplayName(entry) or GetFilenameLabel(selectedValue), entry)
        end
    end

    return {
        values = values,
        order = BuildOrder(items),
        value = selectedValue,
    }
end

return MediaOptionAdapter
