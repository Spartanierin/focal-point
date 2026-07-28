local _, ns = ...

ns.GUI = ns.GUI or {}
ns.GUI.Editor = ns.GUI.Editor or {}
ns.GUI.Editor.MediaLibrary = ns.GUI.Editor.MediaLibrary or {}

local MediaLibrary = {}
ns.GUI.Editor.MediaLibrary.Controller = MediaLibrary
ns.GUI.Editor.MediaLibrary.Open = function(options)
    return MediaLibrary.Open(options)
end
ns.GUI.Editor.MediaLibrary.Close = function()
    return MediaLibrary.Close()
end

local STATUSBAR = "statusbar"
local FONT = "font"
local L = ns.L or {}

local context

local function T(key, fallback)
    return L[key] or fallback or key
end

local function Trim(value)
    if type(value) ~= "string" then
        return ""
    end

    return (value:gsub("^%s+", ""):gsub("%s+$", ""))
end

local function NormalizeMediaType(mediaType)
    mediaType = Trim(mediaType):lower()
    if mediaType == FONT or mediaType == STATUSBAR then
        return mediaType
    end
    return nil
end

local function GetMediaTypeLabel(mediaType)
    if mediaType == FONT then
        return T("MEDIA_LIBRARY_TYPE_FONT", "Fonts")
    end
    if mediaType == STATUSBAR then
        return T("MEDIA_LIBRARY_TYPE_STATUSBAR", "Status Bars")
    end
    return tostring(mediaType or "")
end

local function GetDefaultTitle(mediaType)
    return string.format(T("MEDIA_LIBRARY_TITLE_FORMAT", "Media Library: %s"), GetMediaTypeLabel(mediaType))
end

local function FindItemByValue(items, value)
    if type(value) ~= "string" or value == "" then
        return nil
    end

    for _, item in ipairs(items or {}) do
        if item and item.value == value then
            return item
        end
    end

    return nil
end

local function FindFirstSelectableItem(items)
    for _, item in ipairs(items or {}) do
        if item and item.selectable ~= false then
            return item
        end
    end
    return nil
end

local function SetClosingReason(reason)
    if context then
        context.closingReason = reason
    end
end

local function HideWindow(reason)
    if not context then
        return
    end

    SetClosingReason(reason or "cancel")
    if context.window and context.window.Hide then
        context.window:Hide()
    else
        MediaLibrary.HandleClosed()
    end
end

local function BuildItems()
    local Items = ns.GUI
        and ns.GUI.Editor
        and ns.GUI.Editor.MediaLibrary
        and ns.GUI.Editor.MediaLibrary.MediaLibraryItems

    if not (context and Items and Items.Build) then
        return
    end

    local state = context.state
    local result = Items.Build(state.mediaType, state.currentValue, {
        defaultReference = state.defaultReference,
        availableOnly = true,
        includeCurrent = true,
        includeUnavailable = true,
        includeLegacy = true,
        deduplicate = true,
        sourceFilter = state.sourceFilter,
        searchText = state.searchText,
    })

    state.items = type(result) == "table" and result.items or {}
    state.metadata = type(result) == "table" and result.metadata or {}
    state.currentItem = type(result) == "table" and result.currentItem or nil

    local selectedValue = state.selectedItem and state.selectedItem.value
    if selectedValue then
        state.selectedItem = FindItemByValue(state.items, selectedValue) or state.selectedItem
    else
        state.selectedItem = state.currentItem or FindFirstSelectableItem(state.items)
    end
end

local function Refresh()
    if not context then
        return
    end

    BuildItems()

    local View = ns.GUI
        and ns.GUI.Editor
        and ns.GUI.Editor.MediaLibrary
        and ns.GUI.Editor.MediaLibrary.MediaLibraryView
    if View and View.Refresh then
        View.Refresh(context)
    end
end

local function CreateCallbacks()
    return {
        onSelect = function(item)
            if not context or not item or item.selectable == false then
                return
            end
            context.state.selectedItem = item
            local View = ns.GUI.Editor.MediaLibrary.MediaLibraryView
            if View and View.RefreshList then
                View.RefreshList(context)
            end
        end,
        onSearchChanged = function(value)
            if not context then
                return
            end
            context.state.searchText = value or ""
            Refresh()
        end,
        onSourceChanged = function(value)
            if not context then
                return
            end
            context.state.sourceFilter = value or "all"
            Refresh()
        end,
        onApply = function()
            if not context then
                return
            end

            local item = context.state.selectedItem
            if not item or item.selectable == false then
                return
            end

            local callback = context.options and context.options.onApply
            if type(callback) == "function" then
                callback(item.value, item)
            end
            HideWindow("apply")
        end,
        onCancel = function()
            HideWindow("cancel")
        end,
        onWindowClosed = function()
            MediaLibrary.HandleClosed()
        end,
    }
end

function MediaLibrary.HandleClosed()
    if not context then
        return
    end

    local reason = context.closingReason or "cancel"
    local options = context.options or {}
    context.closingReason = nil

    if reason ~= "apply" and type(options.onCancel) == "function" then
        options.onCancel()
    end
end

function MediaLibrary.Open(options)
    options = type(options) == "table" and options or {}
    local mediaType = NormalizeMediaType(options.mediaType)
    if not mediaType then
        return nil, "invalid_media_type"
    end

    context = context or {}
    context.options = {
        onApply = options.onApply,
        onCancel = options.onCancel,
    }
    context.state = {
        mediaType = mediaType,
        currentValue = options.currentValue,
        defaultReference = options.defaultReference,
        sourceFilter = "all",
        searchText = "",
        title = options.title or GetDefaultTitle(mediaType),
        subtitle = string.format(T("MEDIA_LIBRARY_SUBTITLE_FORMAT", "Select %s from the shared media library."), GetMediaTypeLabel(mediaType)),
        items = {},
        selectedItem = nil,
        currentItem = nil,
        metadata = {},
    }
    context.callbacks = CreateCallbacks()
    context.closingReason = nil

    BuildItems()

    local View = ns.GUI
        and ns.GUI.Editor
        and ns.GUI.Editor.MediaLibrary
        and ns.GUI.Editor.MediaLibrary.MediaLibraryView
    if not (View and View.Show) then
        return nil, "view_unavailable"
    end

    View.Show(context)
    return true
end

function MediaLibrary.Close()
    HideWindow("cancel")
end

return MediaLibrary
