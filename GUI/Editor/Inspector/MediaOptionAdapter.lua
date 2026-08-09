local _, ns = ...

ns.GUI = ns.GUI or {}
ns.GUI.Editor = ns.GUI.Editor or {}
ns.GUI.Editor.Inspector = ns.GUI.Editor.Inspector or {}

local MediaOptionAdapter = {}
ns.GUI.Editor.Inspector.MediaOptionAdapter = MediaOptionAdapter

local STATUSBAR = "statusbar"
local FONT = "font"
local DECORATION = "decoration"
local DEFAULT_STATUSBAR_REFERENCE = "fp:statusbar:blizzard-default"
local DEFAULT_FONT_REFERENCE = "fp:font:standard"
local DEFAULT_DECORATION_REFERENCE = "fp:decoration:shadow1"

local function BuildDropdownFromItems(mediaType, currentValue, defaultReference)
    local MediaLibraryItems = ns.GUI
        and ns.GUI.Editor
        and ns.GUI.Editor.MediaLibrary
        and ns.GUI.Editor.MediaLibrary.MediaLibraryItems

    local values = {}
    local order = {}
    local selectedValue = currentValue

    if not (MediaLibraryItems and MediaLibraryItems.Build) then
        return {
            values = values,
            order = order,
            value = selectedValue,
        }
    end

    local result = MediaLibraryItems.Build(mediaType, currentValue, {
        defaultReference = defaultReference,
        availableOnly = true,
        includeCurrent = true,
        includeUnavailable = true,
        includeLegacy = true,
        deduplicate = true,
    })

    if type(result) == "table" and type(result.metadata) == "table" then
        selectedValue = result.metadata.selectedValue
    end

    for _, item in ipairs(type(result) == "table" and result.items or {}) do
        if type(item) == "table" and type(item.value) == "string" and item.value ~= "" then
            values[item.value] = item.label or item.value
            order[#order + 1] = item.value
        end
    end

    return {
        values = values,
        order = order,
        value = selectedValue,
    }
end

function MediaOptionAdapter.BuildStatusBarDropdown(currentValue)
    return BuildDropdownFromItems(STATUSBAR, currentValue, DEFAULT_STATUSBAR_REFERENCE)
end

function MediaOptionAdapter.BuildFontDropdown(currentValue)
    return BuildDropdownFromItems(FONT, currentValue, DEFAULT_FONT_REFERENCE)
end

function MediaOptionAdapter.BuildDecorationDropdown(currentValue)
    return BuildDropdownFromItems(DECORATION, currentValue, DEFAULT_DECORATION_REFERENCE)
end

return MediaOptionAdapter
