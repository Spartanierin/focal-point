local _, ns = ...

ns.GUI = ns.GUI or {}
ns.GUI.Pages = ns.GUI.Pages or {}

local AceGUI = LibStub("AceGUI-3.0")
local L = ns.L or {}
local FormWidgets = ns.GUI.Helpers and ns.GUI.Helpers.FormWidgets or {}
local TextStyles = ns.GUI.Helpers and ns.GUI.Helpers.TextStyles or {}

local TagLibraryView = {}
ns.GUI.Pages.TagLibraryView = TagLibraryView

local CHROME_PREFIX = "__fpTagLibrary"

local FRAME_CHROME = {
    fill = { 0.028, 0.033, 0.044, 0.94 },
    header = { 0.070, 0.076, 0.094, 0.86 },
    border = { 0.36, 0.38, 0.43, 0.66 },
    innerBorder = { 0.76, 0.70, 0.54, 0.10 },
    topShade = { 1.00, 0.94, 0.70, 0.06 },
    bottomShade = { 0.00, 0.00, 0.00, 0.36 },
}

local SECTION_CHROME = {
    fill = { 0.050, 0.057, 0.072, 0.70 },
    border = { 0.28, 0.31, 0.37, 0.62 },
    topShade = { 1.00, 1.00, 1.00, 0.04 },
    bottomShade = { 0.00, 0.00, 0.00, 0.28 },
    footerFill = { 0.058, 0.064, 0.080, 0.76 },
    footerBorder = { 0.32, 0.35, 0.40, 0.50 },
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

local function ApplyPickerWindowChrome(window)
    local frame = window and window.frame
    if not frame then
        return
    end

    local fill = EnsureColorTexture(frame, CHROME_PREFIX .. "OuterFill", "BACKGROUND")
    SetPointPair(fill, "TOPLEFT", frame, 7, -7, "BOTTOMRIGHT", frame, -7, 7)
    SetTextureColor(fill, FRAME_CHROME.fill)

    local header = EnsureColorTexture(frame, CHROME_PREFIX .. "HeaderFill", "BACKGROUND")
    SetPointPair(header, "TOPLEFT", frame, 8, -8, "TOPRIGHT", frame, -8, -8)
    header:SetHeight(24)
    SetTextureColor(header, FRAME_CHROME.header)

    local topShade = EnsureColorTexture(frame, CHROME_PREFIX .. "TopShade", "ARTWORK")
    SetPointPair(topShade, "TOPLEFT", frame, 8, -32, "TOPRIGHT", frame, -8, -32)
    topShade:SetHeight(1)
    SetTextureColor(topShade, FRAME_CHROME.topShade)

    local bottomShade = EnsureColorTexture(frame, CHROME_PREFIX .. "BottomShade", "ARTWORK")
    SetPointPair(bottomShade, "BOTTOMLEFT", frame, 8, 8, "BOTTOMRIGHT", frame, -8, 8)
    bottomShade:SetHeight(1)
    SetTextureColor(bottomShade, FRAME_CHROME.bottomShade)

    local borderTop = EnsureColorTexture(frame, CHROME_PREFIX .. "BorderTop", "OVERLAY")
    SetPointPair(borderTop, "TOPLEFT", frame, 7, -7, "TOPRIGHT", frame, -7, -7)
    borderTop:SetHeight(1)
    SetTextureColor(borderTop, FRAME_CHROME.border)

    local borderBottom = EnsureColorTexture(frame, CHROME_PREFIX .. "BorderBottom", "OVERLAY")
    SetPointPair(borderBottom, "BOTTOMLEFT", frame, 7, 7, "BOTTOMRIGHT", frame, -7, 7)
    borderBottom:SetHeight(1)
    SetTextureColor(borderBottom, FRAME_CHROME.border)

    local borderLeft = EnsureColorTexture(frame, CHROME_PREFIX .. "BorderLeft", "OVERLAY")
    SetPointPair(borderLeft, "TOPLEFT", frame, 7, -7, "BOTTOMLEFT", frame, 7, 7)
    borderLeft:SetWidth(1)
    SetTextureColor(borderLeft, FRAME_CHROME.border)

    local borderRight = EnsureColorTexture(frame, CHROME_PREFIX .. "BorderRight", "OVERLAY")
    SetPointPair(borderRight, "TOPRIGHT", frame, -7, -7, "BOTTOMRIGHT", frame, -7, 7)
    borderRight:SetWidth(1)
    SetTextureColor(borderRight, FRAME_CHROME.border)

    local innerTop = EnsureColorTexture(frame, CHROME_PREFIX .. "InnerTop", "BORDER")
    SetPointPair(innerTop, "TOPLEFT", frame, 8, -8, "TOPRIGHT", frame, -8, -8)
    innerTop:SetHeight(1)
    SetTextureColor(innerTop, FRAME_CHROME.innerBorder)

    local innerBottom = EnsureColorTexture(frame, CHROME_PREFIX .. "InnerBottom", "BORDER")
    SetPointPair(innerBottom, "BOTTOMLEFT", frame, 8, 8, "BOTTOMRIGHT", frame, -8, 8)
    innerBottom:SetHeight(1)
    SetTextureColor(innerBottom, FRAME_CHROME.innerBorder)

    local innerLeft = EnsureColorTexture(frame, CHROME_PREFIX .. "InnerLeft", "BORDER")
    SetPointPair(innerLeft, "TOPLEFT", frame, 8, -8, "BOTTOMLEFT", frame, 8, 8)
    innerLeft:SetWidth(1)
    SetTextureColor(innerLeft, FRAME_CHROME.innerBorder)

    local innerRight = EnsureColorTexture(frame, CHROME_PREFIX .. "InnerRight", "BORDER")
    SetPointPair(innerRight, "TOPRIGHT", frame, -8, -8, "BOTTOMRIGHT", frame, -8, 8)
    innerRight:SetWidth(1)
    SetTextureColor(innerRight, FRAME_CHROME.innerBorder)
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
    container:AddChild(CreateLabel(labelText, "help", 10, 96))
    container:AddChild(CreateLabel(valueText ~= "" and valueText or "-", "label", 11, 245))
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
    ApplyPickerWindowChrome(window)
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
    details:SetHeight(402)
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
    ApplySectionChrome(actions, "Footer", {
        fill = SECTION_CHROME.footerFill,
        border = SECTION_CHROME.footerBorder,
        topShade = { 0.78, 0.78, 0.74, 0.05 },
        bottomShade = { 0.00, 0.00, 0.00, 0.28 },
    })

    actions:AddChild(CreateSpacer(nil, 5))
    actions:AddChild(CreateSpacer(486, 1))

    local cancelButton = CreateButton(T("INFO_COMMON_CANCEL", "Cancel"), "utility", 105)
    actions:AddChild(cancelButton)
    actions:AddChild(CreateSpacer(8, 1))
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
