local _, ns = ...

ns.GUI = ns.GUI or {}
ns.GUI.Editor = ns.GUI.Editor or {}
ns.GUI.Editor.MediaLibrary = ns.GUI.Editor.MediaLibrary or {}

local AceGUI = LibStub("AceGUI-3.0")
local FormWidgets = ns.GUI.Helpers and ns.GUI.Helpers.FormWidgets or {}
local TextStyles = ns.GUI.Helpers and ns.GUI.Helpers.TextStyles or {}
local L = ns.L or {}

local MediaLibraryView = {}
ns.GUI.Editor.MediaLibrary.MediaLibraryView = MediaLibraryView

local STATUSBAR = "statusbar"
local FONT = "font"

local SOURCE_ORDER = {
    "all",
    "Blizzard",
    "Focal Point",
    "Shared",
    "Legacy Path",
    "Unavailable",
}

local SOURCE_LABEL_KEYS = {
    all = "MEDIA_LIBRARY_SOURCE_ALL",
    Blizzard = "MEDIA_SOURCE_BLIZZARD",
    ["Focal Point"] = "MEDIA_SOURCE_FOCAL_POINT",
    Shared = "MEDIA_SOURCE_SHARED",
    ["Legacy Path"] = "MEDIA_SOURCE_LEGACY_PATH",
    Unavailable = "MEDIA_SOURCE_UNAVAILABLE",
}

local function T(key, fallback)
    return L[key] or fallback or key
end

local function ApplyText(widget, role, options)
    if TextStyles.ApplyWidgetText then
        TextStyles.ApplyWidgetText(widget, role or "label", options)
    end
end

local function ApplyLabelText(widget, role, options)
    if TextStyles.ApplyLabelWidget then
        TextStyles.ApplyLabelWidget(widget, role or "label", options)
    else
        ApplyText(widget, role, options)
    end
end

local function CreateLabel(text, role, size, width)
    local label = AceGUI:Create("Label")
    if width then
        label:SetFullWidth(false)
        label:SetWidth(width)
    else
        label:SetFullWidth(true)
    end
    label:SetText(text or "")
    ApplyLabelText(label, role or "label", { size = size or 11 })
    return label
end

local function CreateButton(text, role, width)
    local button = AceGUI:Create("Button")
    button:SetText(text or "")
    if width then
        button:SetFullWidth(false)
        button:SetWidth(width)
    else
        button:SetFullWidth(true)
    end
    if FormWidgets.ApplyModalActionButtonVisual then
        FormWidgets.ApplyModalActionButtonVisual(button, role or "utility")
    end
    return button
end

local function CenterWindow(window)
    local frame = window and window.frame
    if not frame then
        return
    end

    frame:ClearAllPoints()
    frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
end

local function FocusWindow(window)
    local frame = window and window.frame
    if not frame then
        return
    end

    if frame.IsShown and not frame:IsShown() then
        CenterWindow(window)
    end

    if window.Show then
        window:Show()
    elseif frame.Show then
        frame:Show()
    end

    frame:SetFrameStrata("FULLSCREEN_DIALOG")
    frame:SetToplevel(true)
    if frame.Raise then
        frame:Raise()
    end
end

local function EnableEscapeClose(window)
    local frame = window and window.frame
    if not frame then
        return
    end

    if frame.EnableKeyboard then
        frame:EnableKeyboard(true)
    end
    if frame.SetScript then
        frame:SetScript("OnKeyDown", function(_, key)
            if key == "ESCAPE" and window.Hide then
                window:Hide()
            end
        end)
    end
end

local function FormatBool(value)
    return value and T("MEDIA_LIBRARY_VALUE_YES", "Yes") or T("MEDIA_LIBRARY_VALUE_NO", "No")
end

local function GetSourceLabel(source)
    local key = SOURCE_LABEL_KEYS[source]
    return (key and T(key)) or tostring(source or "")
end

local function BuildSourceDropdown()
    local values = {}
    local order = {}
    for _, source in ipairs(SOURCE_ORDER) do
        values[source] = GetSourceLabel(source)
        order[#order + 1] = source
    end
    return values, order
end

local function BuildItemRowText(item, selectedItem)
    local markers = {}
    if item == selectedItem then
        markers[#markers + 1] = T("MEDIA_LIBRARY_MARKER_SELECTED", "Selected")
    end
    if item and item.current == true then
        markers[#markers + 1] = T("MEDIA_LIBRARY_MARKER_CURRENT", "Current")
    end
    if item and item.missing == true then
        markers[#markers + 1] = T("MEDIA_LIBRARY_MARKER_MISSING", "Missing")
    elseif item and item.legacy == true then
        markers[#markers + 1] = T("MEDIA_LIBRARY_MARKER_LEGACY", "Legacy")
    end

    local prefix = ""
    if #markers > 0 then
        prefix = "[" .. table.concat(markers, "] [") .. "] "
    end

    local source = item and item.source and ("  -  " .. GetSourceLabel(item.source)) or ""
    return prefix .. tostring(item and item.label or "") .. source
end

local function RefreshItemSelectionMarkers(context)
    local widgets = context and context.widgets or {}
    local rows = widgets.itemRows
    if type(rows) ~= "table" then
        return false
    end

    for _, row in ipairs(rows) do
        if row and row.button and row.button.SetText then
            row.button:SetText(BuildItemRowText(row.item, context.state and context.state.selectedItem or nil))
        end
    end

    return true
end

local function SetMetaLabel(label, title, value)
    if not label then
        return
    end

    label:SetText(string.format("%s: %s", title, tostring(value or "")))
end

local function Shorten(value, limit)
    value = tostring(value or "")
    limit = tonumber(limit) or 72
    if #value <= limit then
        return value
    end

    return value:sub(1, math.max(1, limit - 3)) .. "..."
end

local function BuildStatusText(item)
    if not item then
        return T("MEDIA_LIBRARY_STATUS_NONE", "No media selected")
    end

    if item.missing == true then
        return T("MEDIA_LIBRARY_STATUS_MISSING", "Missing")
    end
    if item.legacy == true then
        return T("MEDIA_LIBRARY_STATUS_LEGACY", "Legacy")
    end
    if item.available == true then
        return T("MEDIA_LIBRARY_STATUS_AVAILABLE", "Available")
    end
    return T("MEDIA_LIBRARY_STATUS_UNAVAILABLE", "Unavailable")
end

local function RefreshMetadata(context)
    local widgets = context and context.widgets or {}
    local item = context and context.state and context.state.selectedItem or nil
    local isStatusBar = context and context.state and context.state.mediaType == STATUSBAR
    local hasPreview = isStatusBar or (context and context.state and context.state.mediaType == FONT)

    SetMetaLabel(widgets.selectedLabel, T("MEDIA_LIBRARY_SELECTED", "Selected"), item and Shorten(item.label, 86) or T("MEDIA_LIBRARY_STATUS_NONE", "No media selected"))
    SetMetaLabel(widgets.nameLabel, T("MEDIA_LIBRARY_NAME", "Name"), item and Shorten(item.name, 44) or "n/a")
    SetMetaLabel(widgets.sourceLabel, T("MEDIA_LIBRARY_SOURCE", "Source"), item and GetSourceLabel(item.source) or "n/a")
    SetMetaLabel(widgets.providerLabel, T("MEDIA_LIBRARY_PROVIDER", "Provider"), item and item.provider or "n/a")
    SetMetaLabel(widgets.valueLabel, T("MEDIA_LIBRARY_VALUE", "Value"), item and Shorten(item.value, 92) or "n/a")
    SetMetaLabel(widgets.availableLabel, T("MEDIA_LIBRARY_AVAILABLE", "Available"), item and FormatBool(item.available == true) or "n/a")
    SetMetaLabel(widgets.currentLabel, T("MEDIA_LIBRARY_CURRENT", "Current"), item and FormatBool(item.current == true) or "n/a")
    SetMetaLabel(widgets.legacyLabel, T("MEDIA_LIBRARY_LEGACY", "Legacy"), item and FormatBool(item.legacy == true) or "n/a")
    SetMetaLabel(widgets.missingLabel, T("MEDIA_LIBRARY_MISSING", "Missing"), item and FormatBool(item.missing == true) or "n/a")
    SetMetaLabel(widgets.statusLabel, T("MEDIA_LIBRARY_STATUS", "Status"), item and BuildStatusText(item) or "n/a")
    SetMetaLabel(widgets.previewStatusLabel, T("MEDIA_LIBRARY_PREVIEW_STATUS", "Preview Status"), hasPreview and BuildStatusText(item) or "n/a")
    SetMetaLabel(widgets.resolvedAssetLabel, T("MEDIA_LIBRARY_RESOLVED_ASSET", "Resolved Asset"), hasPreview and item and Shorten(item.resolvedAsset, 92) or "n/a")
    SetMetaLabel(widgets.fallbackUsedLabel, T("MEDIA_LIBRARY_FALLBACK_USED", "Fallback Used"), hasPreview and item and FormatBool(item.missing == true or item.available ~= true or not item.resolvedAsset) or "n/a")

    if widgets.applyButton and widgets.applyButton.SetDisabled then
        widgets.applyButton:SetDisabled(not (item and item.selectable ~= false))
    end

    local Preview = ns.GUI
        and ns.GUI.Editor
        and ns.GUI.Editor.MediaLibrary
        and ns.GUI.Editor.MediaLibrary.MediaLibraryPreview
    if Preview and Preview.SetItem and widgets.preview then
        Preview.SetItem(widgets.preview, item)
    end
end

function MediaLibraryView.RefreshList(context)
    local widgets = context and context.widgets or {}
    local scroll = widgets.itemScroll
    if not scroll then
        return
    end

    widgets.itemRows = {}
    scroll:ReleaseChildren()

    local items = context.state and context.state.items or {}
    if #items == 0 then
        scroll:AddChild(CreateLabel(T("MEDIA_LIBRARY_NO_MEDIA_FOUND", "No media found"), "help", 11))
        RefreshMetadata(context)
        return
    end

    for _, item in ipairs(items) do
        local button = CreateButton(BuildItemRowText(item, context.state.selectedItem), "utility")
        button:SetDisabled(item.selectable == false)
        button:SetCallback("OnClick", function()
            if item.selectable == false then
                return
            end
            context.callbacks.onSelect(item)
        end)
        scroll:AddChild(button)
        widgets.itemRows[#widgets.itemRows + 1] = {
            item = item,
            button = button,
        }
    end

    RefreshMetadata(context)
end

function MediaLibraryView.RefreshSelection(context)
    if not context then
        return
    end

    if not RefreshItemSelectionMarkers(context) then
        MediaLibraryView.RefreshList(context)
        return
    end

    RefreshMetadata(context)
end

function MediaLibraryView.Refresh(context)
    if not context then
        return
    end

    local widgets = context.widgets or {}
    if widgets.searchBox and widgets.searchBox.GetText and widgets.searchBox:GetText() ~= (context.state.searchText or "") then
        context.suppressSearchCallback = true
        widgets.searchBox:SetText(context.state.searchText or "")
        context.suppressSearchCallback = false
    end
    if widgets.sourceDropdown then
        widgets.sourceDropdown:SetValue(context.state.sourceFilter or "all")
    end

    MediaLibraryView.RefreshList(context)
end

function MediaLibraryView.Create(context)
    local window = AceGUI:Create("Window")
    window:SetTitle(context.state.title or T("MEDIA_LIBRARY_TITLE", "Media Library"))
    window:SetLayout("Fill")
    window:SetWidth(720)
    window:SetHeight(660)
    window:EnableResize(false)

    if window.frame then
        window.frame:SetClampedToScreen(true)
    end

    if FormWidgets.ApplyWindowChrome then
        FormWidgets.ApplyWindowChrome(window)
    end
    if FormWidgets.EnsureStandardWindowCloseButton then
        FormWidgets.EnsureStandardWindowCloseButton(window)
    end
    EnableEscapeClose(window)

    local root = AceGUI:Create("SimpleGroup")
    root:SetLayout("Flow")
    root:SetFullWidth(true)
    root:SetFullHeight(true)
    window:AddChild(root)

    local title = CreateLabel(context.state.subtitle or "", "sectionHeader", 13)
    root:AddChild(title)

    local searchBox = AceGUI:Create("EditBox")
    searchBox:SetLabel(T("MEDIA_LIBRARY_SEARCH", "Search"))
    searchBox:DisableButton(true)
    searchBox:SetWidth(420)
    if FormWidgets.StyleEditBox then
        FormWidgets.StyleEditBox(searchBox, "editor_inset")
    end
    root:AddChild(searchBox)

    local sourceDropdown = AceGUI:Create("Dropdown")
    local sourceValues, sourceOrder = BuildSourceDropdown()
    sourceDropdown:SetLabel(T("MEDIA_LIBRARY_SOURCE", "Source"))
    sourceDropdown:SetList(sourceValues, sourceOrder)
    sourceDropdown:SetValue("all")
    sourceDropdown:SetWidth(220)
    if FormWidgets.StyleDropdown then
        FormWidgets.StyleDropdown(sourceDropdown, "editor_inset")
    end
    root:AddChild(sourceDropdown)

    local itemScroll = AceGUI:Create("ScrollFrame")
    itemScroll:SetLayout("Flow")
    itemScroll:SetFullWidth(true)
    itemScroll:SetHeight(300)
    root:AddChild(itemScroll)

    local Preview = ns.GUI
        and ns.GUI.Editor
        and ns.GUI.Editor.MediaLibrary
        and ns.GUI.Editor.MediaLibrary.MediaLibraryPreview
    local preview = Preview and Preview.Create and Preview.Create(root) or nil

    local metadata = AceGUI:Create("SimpleGroup")
    metadata:SetLayout("Flow")
    metadata:SetFullWidth(true)
    metadata:SetHeight(112)
    root:AddChild(metadata)

    local primaryWidth = 330
    local secondaryWidth = 310
    local labels = {
        selectedLabel = CreateLabel("", "highlight", 11),
        nameLabel = CreateLabel("", "label", 10, primaryWidth),
        sourceLabel = CreateLabel("", "label", 10, secondaryWidth),
        statusLabel = CreateLabel("", "help", 10, primaryWidth),
        providerLabel = CreateLabel("", "help", 10, secondaryWidth),
        currentLabel = CreateLabel("", "help", 10, primaryWidth),
        legacyLabel = CreateLabel("", "help", 10, 150),
        missingLabel = CreateLabel("", "help", 10, 160),
        valueLabel = CreateLabel("", "help", 9),
        previewStatusLabel = CreateLabel("", "help", 9, primaryWidth),
        resolvedAssetLabel = CreateLabel("", "help", 9),
        fallbackUsedLabel = CreateLabel("", "help", 9, secondaryWidth),
    }

    for _, key in ipairs({
        "selectedLabel",
        "nameLabel",
        "sourceLabel",
        "statusLabel",
        "providerLabel",
        "currentLabel",
        "legacyLabel",
        "missingLabel",
        "previewStatusLabel",
        "fallbackUsedLabel",
        "valueLabel",
        "resolvedAssetLabel",
    }) do
        metadata:AddChild(labels[key])
    end

    local actions = AceGUI:Create("SimpleGroup")
    actions:SetLayout("Flow")
    actions:SetFullWidth(true)
    actions:SetHeight(34)
    root:AddChild(actions)

    local spacer = AceGUI:Create("Label")
    spacer:SetText("")
    spacer:SetWidth(480)
    actions:AddChild(spacer)

    local cancelButton = CreateButton(T("MEDIA_LIBRARY_CANCEL", "Cancel"), "utility", 105)
    actions:AddChild(cancelButton)

    local applyButton = CreateButton(T("MEDIA_LIBRARY_APPLY", "Apply"), "primary_action", 105)
    actions:AddChild(applyButton)

    context.window = window
    context.widgets = {
        root = root,
        title = title,
        searchBox = searchBox,
        sourceDropdown = sourceDropdown,
        itemScroll = itemScroll,
        preview = preview,
        metadata = metadata,
        selectedLabel = labels.selectedLabel,
        statusLabel = labels.statusLabel,
        sourceLabel = labels.sourceLabel,
        providerLabel = labels.providerLabel,
        valueLabel = labels.valueLabel,
        nameLabel = labels.nameLabel,
        availableLabel = labels.availableLabel,
        currentLabel = labels.currentLabel,
        legacyLabel = labels.legacyLabel,
        missingLabel = labels.missingLabel,
        previewStatusLabel = labels.previewStatusLabel,
        resolvedAssetLabel = labels.resolvedAssetLabel,
        fallbackUsedLabel = labels.fallbackUsedLabel,
        cancelButton = cancelButton,
        applyButton = applyButton,
    }

    searchBox:SetCallback("OnTextChanged", function(_, _, value)
        if context.suppressSearchCallback then
            return
        end
        context.callbacks.onSearchChanged(value or "")
    end)
    searchBox:SetCallback("OnEnterPressed", function(_, _, value)
        context.callbacks.onSearchChanged(value or "")
    end)

    sourceDropdown:SetCallback("OnValueChanged", function(_, _, value)
        context.callbacks.onSourceChanged(value or "all")
    end)

    cancelButton:SetCallback("OnClick", function()
        context.callbacks.onCancel()
    end)
    applyButton:SetCallback("OnClick", function()
        context.callbacks.onApply()
    end)

    window:SetCallback("OnClose", function()
        context.callbacks.onWindowClosed()
    end)

    CenterWindow(window)
    FocusWindow(window)
    MediaLibraryView.Refresh(context)
    return window
end

function MediaLibraryView.Show(context)
    if not context then
        return
    end

    if context.window then
        context.window:SetTitle(context.state.title or T("MEDIA_LIBRARY_TITLE", "Media Library"))
        if context.widgets and context.widgets.title then
            context.widgets.title:SetText(context.state.subtitle or "")
        end
        FocusWindow(context.window)
        MediaLibraryView.Refresh(context)
        return
    end

    MediaLibraryView.Create(context)
end

return MediaLibraryView
