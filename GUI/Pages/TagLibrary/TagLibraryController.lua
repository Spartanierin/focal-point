local _, ns = ...

ns.GUI = ns.GUI or {}
ns.GUI.Pages = ns.GUI.Pages or {}
ns.GUI.Pages.TagLibrary = ns.GUI.Pages.TagLibrary or {}

local TagLibraryController = {}
ns.GUI.Pages.TagLibrary = TagLibraryController

local L = ns.L or {}
local context

local function T(key, fallback)
    return (key and L[key]) or fallback or key or ""
end

local function Trim(value)
    if type(value) ~= "string" then
        return ""
    end
    return (value:gsub("^%s+", ""):gsub("%s+$", ""))
end

local function Lower(value)
    return string.lower(Trim(value))
end

local function Contains(haystack, needle)
    if needle == "" then
        return true
    end
    return string.find(Lower(haystack), needle, 1, true) ~= nil
end

local function NormalizeOptions(options)
    options = type(options) == "table" and options or {}
    return {
        owner = options.owner,
        onApply = options.onApply,
        onCancel = options.onCancel,
    }
end

local function BuildItems()
    local tagDatabase = ns.UnitFrame and ns.UnitFrame.GetTagDatabase and ns.UnitFrame:GetTagDatabase() or {}
    local items = {}

    for index, entry in ipairs(tagDatabase) do
        local token = type(entry.token) == "string" and entry.token or ""
        if token ~= "" then
            local category = T(entry.category, entry.category or "")
            local description = T(entry.description, entry.description or "")
            local example = type(entry.example) == "string" and entry.example or ""
            items[#items + 1] = {
                entry = entry,
                token = token,
                category = category,
                description = description,
                example = example,
                sourceIndex = index,
            }
        end
    end

    table.sort(items, function(a, b)
        local categoryA = Lower(a.category)
        local categoryB = Lower(b.category)
        if categoryA ~= categoryB then
            return categoryA < categoryB
        end
        return Lower(a.token) < Lower(b.token)
    end)

    return items
end

local function FilterItems()
    if not context or not context.state then
        return
    end

    local state = context.state
    local query = Lower(state.searchText)
    state.visibleEntries = {}

    for _, item in ipairs(state.items or {}) do
        if Contains(item.token, query)
            or Contains(item.description, query)
            or Contains(item.category, query)
            or Contains(item.example, query)
        then
            state.visibleEntries[#state.visibleEntries + 1] = item
        end
    end

    local selectedToken = state.selectedEntry and state.selectedEntry.token
    local selectedStillVisible = false
    for _, item in ipairs(state.visibleEntries) do
        if item.token == selectedToken then
            state.selectedEntry = item
            selectedStillVisible = true
            break
        end
    end

    if not selectedStillVisible then
        state.selectedEntry = state.visibleEntries[1]
    end
end

local function Refresh()
    FilterItems()
    local View = ns.GUI and ns.GUI.Pages and ns.GUI.Pages.TagLibraryView
    if View and View.Refresh then
        View.Refresh(context)
    end
end

local function SetClosingReason(reason)
    if context then
        context.closingReason = reason or "cancel"
    end
end

local function HideWindow(reason)
    if not context then
        return
    end

    SetClosingReason(reason)
    if context.window and context.window.Hide then
        context.window:Hide()
    else
        TagLibraryController.HandleClosed()
    end
end

local function CreateCallbacks()
    return {
        onSearchChanged = function(value)
            if not context then
                return
            end
            context.state.searchText = value or ""
            Refresh()
        end,
        onSelect = function(item)
            if not context or not item then
                return
            end
            context.state.selectedEntry = item
            local View = ns.GUI and ns.GUI.Pages and ns.GUI.Pages.TagLibraryView
            if View and View.RefreshSelection then
                View.RefreshSelection(context)
            elseif View and View.Refresh then
                View.Refresh(context)
            end
        end,
        onApply = function()
            if not context then
                return
            end
            local item = context.state and context.state.selectedEntry or nil
            if not item or item.token == "" then
                return
            end

            local callback = context.options and context.options.onApply
            if type(callback) == "function" and callback(item.token, item.entry or item) == false then
                return
            end
            HideWindow("apply")
        end,
        onCancel = function()
            HideWindow("cancel")
        end,
        onWindowClosed = function()
            TagLibraryController.HandleClosed()
        end,
    }
end

function TagLibraryController.HandleClosed()
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

function TagLibraryController.Open(options)
    context = context or {}
    context.options = NormalizeOptions(options)
    context.state = {
        searchText = "",
        items = BuildItems(),
        visibleEntries = {},
        selectedEntry = nil,
        title = T("INFO_TAG_LIBRARY_TITLE", "Tag Library"),
        subtitle = T("INFO_TAG_LIBRARY_DESCRIPTION_SHORT", "Choose a tag to insert into your text."),
    }
    context.callbacks = CreateCallbacks()
    context.closingReason = nil

    FilterItems()

    local View = ns.GUI and ns.GUI.Pages and ns.GUI.Pages.TagLibraryView
    if not (View and View.Show) then
        return nil, "view_unavailable"
    end

    View.Show(context)
    return true
end

function TagLibraryController.Close()
    HideWindow("cancel")
end

return TagLibraryController
