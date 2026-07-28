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

local function CreateLabel(text, role, size)
    local label = AceGUI:Create("Label")
    label:SetFullWidth(true)
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

local function SetMetaLabel(label, title, value)
    if not label then
        return
    end

    label:SetText(string.format("%s: %s", title, tostring(value or "")))
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

    SetMetaLabel(widgets.selectedLabel, T("MEDIA_LIBRARY_SELECTED", "Selected"), item and item.label or T("MEDIA_LIBRARY_STATUS_NONE", "No media selected"))
    SetMetaLabel(widgets.nameLabel, T("MEDIA_LIBRARY_NAME", "Name"), item and item.name or "n/a")
    SetMetaLabel(widgets.sourceLabel, T("MEDIA_LIBRARY_SOURCE", "Source"), item and GetSourceLabel(item.source) or "n/a")
    SetMetaLabel(widgets.providerLabel, T("MEDIA_LIBRARY_PROVIDER", "Provider"), item and item.provider or "n/a")
    SetMetaLabel(widgets.valueLabel, T("MEDIA_LIBRARY_VALUE", "Value"), item and item.value or "n/a")
    SetMetaLabel(widgets.availableLabel, T("MEDIA_LIBRARY_AVAILABLE", "Available"), item and FormatBool(item.available == true) or "n/a")
    SetMetaLabel(widgets.currentLabel, T("MEDIA_LIBRARY_CURRENT", "Current"), item and FormatBool(item.current == true) or "n/a")
    SetMetaLabel(widgets.legacyLabel, T("MEDIA_LIBRARY_LEGACY", "Legacy"), item and FormatBool(item.legacy == true) or "n/a")
    SetMetaLabel(widgets.missingLabel, T("MEDIA_LIBRARY_MISSING", "Missing"), item and FormatBool(item.missing == true) or "n/a")
    SetMetaLabel(widgets.statusLabel, T("MEDIA_LIBRARY_STATUS", "Status"), BuildStatusText(item))

    if widgets.applyButton and widgets.applyButton.SetDisabled then
        widgets.applyButton:SetDisabled(not (item and item.selectable ~= false))
    end
end

function MediaLibraryView.RefreshList(context)
    local widgets = context and context.widgets or {}
    local scroll = widgets.itemScroll
    if not scroll then
        return
    end

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
    window:SetHeight(560)
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

    local metadata = AceGUI:Create("SimpleGroup")
    metadata:SetLayout("Flow")
    metadata:SetFullWidth(true)
    metadata:SetHeight(120)
    root:AddChild(metadata)

    local labels = {
        selectedLabel = CreateLabel("", "highlight", 11),
        statusLabel = CreateLabel("", "label", 10),
        sourceLabel = CreateLabel("", "help", 10),
        providerLabel = CreateLabel("", "help", 10),
        valueLabel = CreateLabel("", "help", 10),
        nameLabel = CreateLabel("", "help", 10),
        availableLabel = CreateLabel("", "help", 10),
        currentLabel = CreateLabel("", "help", 10),
        legacyLabel = CreateLabel("", "help", 10),
        missingLabel = CreateLabel("", "help", 10),
    }

    for _, key in ipairs({
        "selectedLabel",
        "statusLabel",
        "sourceLabel",
        "providerLabel",
        "valueLabel",
        "nameLabel",
        "availableLabel",
        "currentLabel",
        "legacyLabel",
        "missingLabel",
    }) do
        metadata:AddChild(labels[key])
    end

    local actions = AceGUI:Create("SimpleGroup")
    actions:SetLayout("Flow")
    actions:SetFullWidth(true)
    actions:SetHeight(36)
    root:AddChild(actions)

    local spacer = AceGUI:Create("Label")
    spacer:SetText("")
    spacer:SetWidth(470)
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
