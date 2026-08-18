local _, ns = ...

ns.GUI = ns.GUI or {}
ns.GUI.Pages = ns.GUI.Pages or {}

local AceGUI = LibStub("AceGUI-3.0")
local L = ns.L or {}
local FormWidgets = ns.GUI.Helpers and ns.GUI.Helpers.FormWidgets or {}
local TextStyles = ns.GUI.Helpers and ns.GUI.Helpers.TextStyles or {}

local TagLibraryView = {}
ns.GUI.Pages.TagLibraryView = TagLibraryView

local function T(key, fallback)
    return (key and L[key]) or fallback or key or ""
end

local function Shorten(value, limit)
    value = tostring(value or "")
    limit = tonumber(limit) or 80
    if #value <= limit then
        return value
    end
    return value:sub(1, math.max(1, limit - 3)) .. "..."
end

local function ApplyLabelText(widget, role, options)
    if TextStyles.ApplyLabelWidget then
        TextStyles.ApplyLabelWidget(widget, role or "label", options or {})
    elseif TextStyles.ApplyWidgetText then
        TextStyles.ApplyWidgetText(widget, role or "label", options or {})
    end
end

local function CreateLabel(text, role, size, width)
    local label = AceGUI:Create("Label")
    label:SetText(text or "")
    if width then
        label:SetFullWidth(false)
        label:SetWidth(width)
    else
        label:SetFullWidth(true)
    end
    ApplyLabelText(label, role or "label", { size = size or 11 })
    return label
end

local function SetButtonTextJustify(button, justifyH)
    local text = button and (button.text or (button.frame and button.frame.GetFontString and button.frame:GetFontString())) or nil
    if text and text.SetJustifyH then
        text:SetJustifyH(justifyH or "CENTER")
    end
end

local function CreateButton(text, role, width, justifyH)
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
    SetButtonTextJustify(button, justifyH)
    return button
end

local function CreateSpacer(width, height)
    local spacer = AceGUI:Create("Label")
    spacer:SetText("")
    if width then
        spacer:SetWidth(width)
        spacer:SetFullWidth(false)
    else
        spacer:SetFullWidth(true)
    end
    if height and spacer.SetHeight then
        spacer:SetHeight(height)
    end
    return spacer
end

local function LockHeight(widget, height)
    if widget and widget.SetHeight then
        widget:SetHeight(height)
    end
    if widget and widget.frame and widget.frame.SetHeight then
        widget.frame:SetHeight(height)
    end
end

local function CenterWindow(window)
    if FormWidgets.CenterWindow then
        FormWidgets.CenterWindow(window)
    end
end

local function FocusWindow(window)
    if FormWidgets.FocusWindow then
        FormWidgets.FocusWindow(window, { centerIfHidden = true })
        return
    end

    local frame = window and window.frame
    if window and window.Show then
        window:Show()
    elseif frame and frame.Show then
        frame:Show()
    end
    if frame then
        frame:SetFrameStrata("FULLSCREEN_DIALOG")
        frame:SetToplevel(true)
        if frame.Raise then
            frame:Raise()
        end
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

local function AddField(container, labelText, valueText)
    container:AddChild(CreateLabel(labelText, "help", 10, 110))
    container:AddChild(CreateLabel(valueText ~= "" and valueText or "-", "label", 11, 520))
end

local function RefreshDetails(context)
    local widgets = context and context.widgets or {}
    local details = widgets.details
    if not details then
        return
    end

    details:ReleaseChildren()
    local item = context.state and context.state.selectedEntry or nil
    if not item then
        details:AddChild(CreateLabel(T("INFO_TAG_LIBRARY_NO_SELECTION", "No tag selected."), "help", 11))
        return
    end

    AddField(details, T("INFO_TAG_DATABASE_COL_TAG", "Tag"), item.token)
    AddField(details, T("INFO_TAG_LIBRARY_CATEGORY", "Category"), item.category)
    AddField(details, T("INFO_TAG_DATABASE_COL_DESC", "Description"), item.description)
    AddField(details, T("INFO_TAG_DATABASE_COL_EXAMPLE", "Example"), item.example)
end

local function RefreshRows(context)
    local widgets = context and context.widgets or {}
    local scroll = widgets.listScroll
    if not scroll then
        return
    end

    scroll:ReleaseChildren()
    widgets.rows = {}

    local entries = context.state and context.state.visibleEntries or {}
    if #entries == 0 then
        scroll:AddChild(CreateLabel(T("INFO_TAG_LIBRARY_NO_TAGS_FOUND", "No tags found."), "help", 11))
        return
    end

    for _, item in ipairs(entries) do
        local selected = context.state.selectedEntry == item
        local label = selected and ("> " .. item.token) or item.token
        if item.description ~= "" then
            label = label .. "  -  " .. Shorten(item.description, 68)
        elseif item.category ~= "" then
            label = label .. "  -  " .. item.category
        end

        local row = CreateButton(label, selected and "primary_action" or "utility", nil, "LEFT")
        row:SetCallback("OnClick", function()
            context.callbacks.onSelect(item)
        end)
        scroll:AddChild(row)
        widgets.rows[#widgets.rows + 1] = row
    end
end

function TagLibraryView.RefreshSelection(context)
    RefreshRows(context)
    RefreshDetails(context)
    local applyButton = context and context.widgets and context.widgets.applyButton
    if applyButton and applyButton.SetDisabled then
        applyButton:SetDisabled(context.state.selectedEntry == nil)
    end
end

function TagLibraryView.Refresh(context)
    if not context then
        return
    end

    local widgets = context.widgets or {}
    if widgets.searchBox and widgets.searchBox.GetText and widgets.searchBox:GetText() ~= (context.state.searchText or "") then
        context.suppressSearchCallback = true
        widgets.searchBox:SetText(context.state.searchText or "")
        context.suppressSearchCallback = false
    end
    if widgets.subtitle and widgets.subtitle.SetText then
        widgets.subtitle:SetText(context.state.subtitle or "")
    end

    RefreshRows(context)
    RefreshDetails(context)
    if widgets.applyButton and widgets.applyButton.SetDisabled then
        widgets.applyButton:SetDisabled(context.state.selectedEntry == nil)
    end
end

function TagLibraryView.Create(context)
    local window = AceGUI:Create("Window")
    window:SetTitle(context.state.title or T("INFO_TAG_LIBRARY_TITLE", "Tag Library"))
    window:SetLayout("Fill")
    window:SetWidth(760)
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

    local subtitle = CreateLabel(context.state.subtitle or "", "sectionHeader", 13)
    root:AddChild(subtitle)

    local searchBox = AceGUI:Create("EditBox")
    searchBox:SetLabel(T("INFO_TAG_LIBRARY_SEARCH", "Search tags"))
    searchBox:DisableButton(true)
    searchBox:SetFullWidth(true)
    if FormWidgets.StyleEditBox then
        FormWidgets.StyleEditBox(searchBox, "editor_inset")
    end
    root:AddChild(searchBox)

    local content = AceGUI:Create("SimpleGroup")
    content:SetLayout("Flow")
    content:SetFullWidth(true)
    LockHeight(content, 390)
    root:AddChild(content)

    local listScroll = AceGUI:Create("ScrollFrame")
    listScroll:SetLayout("Flow")
    listScroll:SetFullWidth(false)
    listScroll:SetWidth(365)
    listScroll:SetHeight(380)
    content:AddChild(listScroll)

    content:AddChild(CreateSpacer(12, 1))

    local details = AceGUI:Create("SimpleGroup")
    details:SetLayout("Flow")
    details:SetFullWidth(false)
    details:SetWidth(345)
    details:SetHeight(380)
    content:AddChild(details)

    local actions = AceGUI:Create("SimpleGroup")
    actions:SetLayout("Flow")
    actions:SetFullWidth(true)
    LockHeight(actions, 40)
    root:AddChild(actions)
    actions:AddChild(CreateSpacer(520, 1))

    local cancelButton = CreateButton(T("INFO_COMMON_CANCEL", "Cancel"), "utility", 105)
    actions:AddChild(cancelButton)
    local applyButton = CreateButton(T("INFO_TAG_LIBRARY_INSERT", "Insert Tag"), "primary_action", 115)
    actions:AddChild(applyButton)

    context.window = window
    context.widgets = {
        root = root,
        subtitle = subtitle,
        searchBox = searchBox,
        listScroll = listScroll,
        details = details,
        cancelButton = cancelButton,
        applyButton = applyButton,
        rows = {},
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
    TagLibraryView.Refresh(context)
    return window
end

function TagLibraryView.Show(context)
    if not context then
        return nil
    end

    if context.window then
        context.window:SetTitle(context.state.title or T("INFO_TAG_LIBRARY_TITLE", "Tag Library"))
        FocusWindow(context.window)
        TagLibraryView.Refresh(context)
        return context.window
    end

    return TagLibraryView.Create(context)
end

return TagLibraryView
