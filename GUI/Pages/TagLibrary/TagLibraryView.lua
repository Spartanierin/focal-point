local _, ns = ...

ns.GUI = ns.GUI or {}
ns.GUI.Pages = ns.GUI.Pages or {}

local AceGUI = LibStub("AceGUI-3.0")
local L = ns.L or {}
local FormWidgets = ns.GUI.Helpers and ns.GUI.Helpers.FormWidgets or {}
local TextStyles = ns.GUI.Helpers and ns.GUI.Helpers.TextStyles or {}
local SelectionRow = ns.GUI.Widgets and ns.GUI.Widgets.SelectionRow or {}

local TagLibraryView = {}

ns.GUI.Pages.TagLibraryView = TagLibraryView

local CHROME_PREFIX = "__fpTagLibrary"

local SECTION_CHROME = {
    fill = { 0.050, 0.057, 0.072, 0.70 },
    border = { 0.28, 0.31, 0.37, 0.62 },
    topShade = { 1.00, 1.00, 1.00, 0.04 },
    bottomShade = { 0.00, 0.00, 0.00, 0.28 },
}

local function SetTextureColor(texture, color)
    if texture and texture.SetColorTexture and color then
        texture:SetColorTexture(color[1] or 1, color[2] or 1, color[3] or 1, color[4] or 1)
    end
end

local function EnsureColorTexture(frame, key, layer)
    if not frame then
        return nil
    end

    if not frame[key] then
        frame[key] = frame:CreateTexture(nil, layer or "BACKGROUND")
    end
    frame[key]:Show()
    return frame[key]
end

local function SetPointPair(texture, startPoint, startRelative, startX, startY, endPoint, endRelative, endX, endY)
    if not texture then
        return
    end

    texture:ClearAllPoints()
    texture:SetPoint(startPoint, startRelative, startPoint, startX or 0, startY or 0)
    texture:SetPoint(endPoint, endRelative, endPoint, endX or 0, endY or 0)
end

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

local function ApplySectionChrome(widget, key, options)
    local frame = widget and widget.frame
    if not frame then
        return
    end

    options = options or {}
    local prefix = CHROME_PREFIX .. key
    local fillColor = options.fill or SECTION_CHROME.fill
    local borderColor = options.border or SECTION_CHROME.border

    local fill = EnsureColorTexture(frame, prefix .. "Fill", "BACKGROUND")
    SetPointPair(fill, "TOPLEFT", frame, 0, 0, "BOTTOMRIGHT", frame, 0, 0)
    SetTextureColor(fill, fillColor)

    local topShade = EnsureColorTexture(frame, prefix .. "TopShade", "BORDER")
    SetPointPair(topShade, "TOPLEFT", frame, 1, -1, "TOPRIGHT", frame, -1, -1)
    topShade:SetHeight(1)
    SetTextureColor(topShade, options.topShade or SECTION_CHROME.topShade)

    local bottomShade = EnsureColorTexture(frame, prefix .. "BottomShade", "BORDER")
    SetPointPair(bottomShade, "BOTTOMLEFT", frame, 1, 1, "BOTTOMRIGHT", frame, -1, 1)
    bottomShade:SetHeight(1)
    SetTextureColor(bottomShade, options.bottomShade or SECTION_CHROME.bottomShade)

    local borderTop = EnsureColorTexture(frame, prefix .. "BorderTop", "BORDER")
    SetPointPair(borderTop, "TOPLEFT", frame, 0, 0, "TOPRIGHT", frame, 0, 0)
    borderTop:SetHeight(1)
    SetTextureColor(borderTop, borderColor)

    local borderBottom = EnsureColorTexture(frame, prefix .. "BorderBottom", "BORDER")
    SetPointPair(borderBottom, "BOTTOMLEFT", frame, 0, 0, "BOTTOMRIGHT", frame, 0, 0)
    borderBottom:SetHeight(1)
    SetTextureColor(borderBottom, borderColor)

    local borderLeft = EnsureColorTexture(frame, prefix .. "BorderLeft", "BORDER")
    SetPointPair(borderLeft, "TOPLEFT", frame, 0, 0, "BOTTOMLEFT", frame, 0, 0)
    borderLeft:SetWidth(1)
    SetTextureColor(borderLeft, borderColor)

    local borderRight = EnsureColorTexture(frame, prefix .. "BorderRight", "BORDER")
    SetPointPair(borderRight, "TOPRIGHT", frame, 0, 0, "BOTTOMRIGHT", frame, 0, 0)
    borderRight:SetWidth(1)
    SetTextureColor(borderRight, borderColor)
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
    local field = AceGUI:Create("SimpleGroup")
    field:SetLayout("List")
    field:SetWidth(container.frame:GetWidth())
    field:SetFullWidth(true)
    field:AddChild(CreateLabel(labelText, "help", 10))
    field:AddChild(CreateLabel(valueText ~= "" and valueText or "-", "label", 11))
    container:AddChild(field)
end

local function RefreshDetails(context)
    local widgets = context and context.widgets or {}
    local details = widgets.details
    if not details then
        return
    end

    details:ReleaseChildren()
    details:AddChild(CreateSpacer(nil, 10))
    details:AddChild(CreateSpacer(14, 1))
    local fields = AceGUI:Create("SimpleGroup")
    fields:SetLayout("Table")
    fields:SetUserData("table", { columns = { 1 }, spaceV = 8, align = "TOPLEFT" })
    fields:SetWidth(352) -- 380-wide detail surface, with 14 on either side.
    fields:SetFullWidth(false)
    details:AddChild(fields)

    local item = context.state and context.state.selectedEntry or nil
    if not item then
        fields:AddChild(CreateLabel(T("INFO_TAG_LIBRARY_NO_SELECTION", "No tag selected."), "help", 11))
    else
        AddField(fields, T("INFO_TAG_LIBRARY_COL_TAG", "Tag"), item.token)
        AddField(fields, T("INFO_TAG_LIBRARY_CATEGORY", "Category"), item.category)
        AddField(fields, T("INFO_TAG_LIBRARY_COL_DESC", "Description"), item.description)
        AddField(fields, T("INFO_TAG_LIBRARY_COL_EXAMPLE", "Example"), item.example)
    end
    details:DoLayout()
    widgets.root:DoLayout()
end

local function BindSelectionRow(row, context, item)
    row:Bind({
        key = item,
        label = item.token,
        description = item.description ~= "" and item.description or nil,
        selected = context.state.selectedEntry == item,
        onSelect = function(selectedItem)
            context.callbacks.onSelect(selectedItem)
        end,
    })
end

local function RefreshSelectionRows(context)
    local widgets = context and context.widgets or {}
    for _, row in ipairs(widgets.rows or {}) do
        if row.item then
            BindSelectionRow(row, context, row.item)
        end
    end
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
        local row = SelectionRow.Create and SelectionRow.Create({}) or nil
        if row then
            row.item = item
            BindSelectionRow(row, context, item)
            scroll:AddChild(row)
            widgets.rows[#widgets.rows + 1] = row
        end
    end
end

function TagLibraryView.RefreshSelection(context)
    RefreshSelectionRows(context)
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
    if FormWidgets.ApplyModernWindowChrome then
        FormWidgets.ApplyModernWindowChrome(window, {
            focalPointTool = true,
            nineSlice = true,
            portrait = true,
            portraitTexture = "Interface\\AddOns\\FocalPoint\\Media\\Icons\\Runtime\\fp_icon_portrait.png",
        })
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

    local subtitle = CreateLabel(context.state.subtitle or "", "help", 11)
    root:AddChild(subtitle)

    local content = AceGUI:Create("SimpleGroup")
    content:SetLayout("Flow")
    content:SetFullWidth(true)
    LockHeight(content, 408)
    root:AddChild(content)

    local browser = AceGUI:Create("SimpleGroup")
    browser:SetLayout("Flow")
    browser:SetFullWidth(false)
    browser:SetWidth(330)
    LockHeight(browser, 402)
    content:AddChild(browser)
    ApplySectionChrome(browser, "Browser", {
        fill = { 0.044, 0.050, 0.064, 0.74 },
        border = { 0.30, 0.33, 0.39, 0.66 },
    })

    browser:AddChild(CreateSpacer(nil, 8))
    browser:AddChild(CreateSpacer(12, 1))

    local searchBox = AceGUI:Create("EditBox")
    searchBox:SetLabel(T("INFO_TAG_LIBRARY_SEARCH", "Search tags"))
    searchBox:DisableButton(true)
    searchBox:SetWidth(304)
    if FormWidgets.StyleEditBox then
        FormWidgets.StyleEditBox(searchBox, "editor_inset")
    end
    browser:AddChild(searchBox)

    browser:AddChild(CreateSpacer(nil, 6))
    browser:AddChild(CreateSpacer(12, 1))

    local listScroll = AceGUI:Create("ScrollFrame")
    listScroll:SetLayout("Flow")
    listScroll:SetFullWidth(false)
    listScroll:SetWidth(304)
    listScroll:SetHeight(322)
    browser:AddChild(listScroll)

    content:AddChild(CreateSpacer(12, 1))

    local details = AceGUI:Create("SimpleGroup")
    details:SetLayout("Flow")
    details:SetFullWidth(false)
    details:SetWidth(380)
    details:SetAutoAdjustHeight(true) -- Four fields grow with their actual text.
    content:AddChild(details)
    ApplySectionChrome(details, "Details", {
        fill = { 0.052, 0.059, 0.074, 0.70 },
        border = { 0.27, 0.30, 0.36, 0.58 },
    })

    local actions = AceGUI:Create("SimpleGroup")
    actions:SetLayout("Flow")
    actions:SetFullWidth(true)
    LockHeight(actions, 42)
    root:AddChild(actions)
    FormWidgets.ApplySurfacePresentation(actions, "Footer", {
        prefix = CHROME_PREFIX,
        actionBar = true,
    })

    actions:AddChild(CreateSpacer(nil, 5))
    local applyButton = CreateButton(T("INFO_TAG_LIBRARY_INSERT", "Insert Tag"), "primary_action", 115)
    actions:AddChild(applyButton)
    actions:AddChild(CreateSpacer(494, 1))
    local cancelButton = CreateButton(T("INFO_COMMON_CANCEL", "Cancel"), "utility", 105)
    actions:AddChild(cancelButton)

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
