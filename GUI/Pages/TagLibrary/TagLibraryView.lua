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

local function ApplyGroupBox(widget)
    local box = widget.frame._fpTagLibraryGroupBox
    if box then box:Hide() end
    local layout = NineSliceUtil and NineSliceUtil.GetLayout and NineSliceUtil.GetLayout("UniqueCornersLayout")
    local atlasInfo = C_Texture and C_Texture.GetAtlasInfo or GetAtlasInfo
    local available = layout and NineSliceUtil.ApplyLayoutByName and type(atlasInfo) == "function"
    for _, key in ipairs({"TopLeftCorner", "TopRightCorner", "BottomLeftCorner", "BottomRightCorner",
        "TopEdge", "BottomEdge", "LeftEdge", "RightEdge"}) do
        local piece = layout and layout[key]
        if available and piece and type(piece.atlas) == "string" then
            local ok, info = pcall(atlasInfo, string.format(piece.atlas, "OptionsFrame"))
            available = ok and info ~= nil and info ~= false
        else
            available = false
        end
    end
    -- Same native OptionsFrame pattern as Texts Manager; Center is optional.
    if available then
        if not box then
            box = CreateFrame("Frame", nil, widget.frame:GetParent())
            widget.frame._fpTagLibraryGroupBox = box
            box:EnableMouse(false)
        end
        box:SetParent(widget.frame:GetParent())
        box:ClearAllPoints()
        box:SetPoint("TOPLEFT", widget.frame, "TOPLEFT", -16, 15)
        box:SetPoint("BOTTOMRIGHT", widget.frame, "BOTTOMRIGHT", 16, -15)
        box:SetFrameLevel(widget.frame:GetFrameLevel())
        box:SetAlpha(1)
        NineSliceUtil.ApplyLayoutByName(box, "UniqueCornersLayout", "OptionsFrame")
        box:Show()
    end
    widget:SetCallback("OnRelease", function(owner)
        if owner.frame._fpTagLibraryGroupBox then owner.frame._fpTagLibraryGroupBox:Hide() end
        ns.GUI.Helpers.FormSectionSurfaceRenderer.ApplySectionPadding(owner, nil)
    end)
end

local function Heading(text)
    local label = CreateLabel(text, "sectionHeader", 14)
    local color = NORMAL_FONT_COLOR or {r = 1, g = 0.82, b = 0}
    label.label:SetTextColor(color.r, color.g, color.b, 1)
    return label
end

local function Gap(parent, height)
    local gap = AceGUI:Create("SimpleGroup")
    gap:SetFullWidth(true)
    gap:SetAutoAdjustHeight(false)
    gap:SetHeight(height)
    parent:AddChild(gap)
end

local function FitWindow(context)
    local widgets = context.widgets
    widgets.root:DoLayout()
    local height = 0
    for _, child in ipairs(widgets.root.children) do height = height + child.frame:GetHeight() end
    height = height + widgets.root._fpSectionPadding.top + widgets.root._fpSectionPadding.bottom
    context.window:SetHeight(57 + height)
    context.dialog.body:SetHeight(context.window.content:GetHeight())
    context.dialog.body:DoLayout()
end

local function CenterWindow(window)
    if FormWidgets.CenterWindow then
        FormWidgets.CenterWindow(window)
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
    if frame.SetPropagateKeyboardInput then
        frame:SetPropagateKeyboardInput(false)
    end
    if frame.SetScript then
        frame:SetScript("OnKeyDown", function(_, key)
            if key == "ESCAPE" and window.Hide then
                window:Hide()
            end
        end)
    end
end

local function RefreshDetails(context)
    local widgets = context and context.widgets or {}
    local details = widgets.details
    if not details then return end
    details:ReleaseChildren()
    local item = context.state and context.state.selectedEntry or nil
    if not item then
        details:AddChild(CreateLabel(T("INFO_TAG_LIBRARY_NO_SELECTION", "No tag selected."), "parchmentSecondary", 12))
    else
        details:AddChild(CreateLabel(item.token, "identity", 14))
        details:AddChild(CreateLabel(item.category, "parchmentSecondary", 12))
        Gap(details, 8)
        details:AddChild(Heading(T("INFO_TAG_LIBRARY_COL_DESC", "Description")))
        details:AddChild(CreateLabel(item.description ~= "" and item.description or "-", "label", 12))
        Gap(details, 8)
        details:AddChild(Heading(T("INFO_TAG_LIBRARY_COL_EXAMPLE", "Example")))
        details:AddChild(CreateLabel(item.example ~= "" and item.example or "-", "identity", 12))
    end
    details:DoLayout()
    FitWindow(context)
end

local function BindSelectionRow(row, context, item)
    row:Bind({
        key = item,
        presentation = {labelSize = 12, height = 42},
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
            local font = {row.description:GetFont()}
            FormWidgets.ApplyTextStyle(row.description, "parchmentSecondary", 10, 1)
            row:SetCallback("OnRelease", function(owner) owner.description:SetFont(unpack(font)) end)
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

    ApplyGroupBox(widgets.browser)
    ApplyGroupBox(widgets.detailGroup)
    RefreshRows(context)
    RefreshDetails(context)
    if widgets.applyButton and widgets.applyButton.SetDisabled then
        widgets.applyButton:SetDisabled(context.state.selectedEntry == nil)
    end
end

function TagLibraryView.Create(context)
    local dialog = FormWidgets.CreateCompactFormDialog({
        title = context.state.title or T("INFO_TAG_LIBRARY_TITLE", "Tag Library"),
        width = 540, height = 670,
        windowChrome = "editmode",
        titleFontSize = 16, titleOffsetY = -7,
        headerDrag = {left = 8, right = 36, top = 0, height = 32},
        bodyLayout = "Fill", contentRoot = true,
    })
    local window = dialog.window
    -- Keep the existing tool content bounds instead of adding compact-form insets.
    dialog.body.frame:ClearAllPoints()
    dialog.body.frame:SetAllPoints(window.content)
    dialog.body:SetWidth(window.content:GetWidth())
    dialog.body:SetHeight(window.content:GetHeight())
    EnableEscapeClose(window)

    local renderer = ns.GUI.Helpers.FormSectionSurfaceRenderer
    local root = AceGUI:Create("SimpleGroup")
    root:SetLayout("List")
    root:SetFullWidth(true)
    root:SetFullHeight(true)
    root:SetAutoAdjustHeight(false)
    renderer.ApplySectionPadding(root, {left = 16, right = 16, top = 8})
    root:SetCallback("OnRelease", function(owner) renderer.ApplySectionPadding(owner, nil) end)
    dialog.body:AddChild(root)

    local subtitle = CreateLabel(context.state.subtitle or "", "parchmentSecondary", 12)
    root:AddChild(subtitle)
    Gap(root, 18)

    local content = AceGUI:Create("SimpleGroup")
    content:SetLayout("List")
    content:SetFullWidth(true)
    content:SetAutoAdjustHeight(false)
    LockHeight(content, 324 + 32 + 160)
    root:AddChild(content)

    local browser = AceGUI:Create("SimpleGroup")
    browser:SetLayout("List")
    browser:SetFullWidth(true)
    browser:SetAutoAdjustHeight(false)
    LockHeight(browser, 324)
    renderer.ApplySectionPadding(browser, {left = 10, right = 10, top = 10, bottom = 10})
    content:AddChild(browser)
    browser:AddChild(Heading(T("INFO_TAG_LIBRARY_SEARCH", "Search tags")))
    Gap(browser, 6)
    local searchBox = AceGUI:Create("EditBox")
    searchBox:DisableButton(true)
    searchBox:SetFullWidth(true)
    FormWidgets.StyleEditBox(searchBox, "editor_inset")
    browser:AddChild(searchBox)
    Gap(browser, 8)
    local listScroll = AceGUI:Create("ScrollFrame")
    listScroll:SetLayout("Flow")
    listScroll:SetFullWidth(true)
    LockHeight(listScroll, 242)
    browser:AddChild(listScroll)

    Gap(content, 32)
    local detailGroup = AceGUI:Create("SimpleGroup")
    detailGroup:SetLayout("List")
    detailGroup:SetFullWidth(true)
    detailGroup:SetAutoAdjustHeight(false)
    LockHeight(detailGroup, 160)
    renderer.ApplySectionPadding(detailGroup, {left = 10, right = 10, top = 10, bottom = 10})
    content:AddChild(detailGroup)
    detailGroup:AddChild(Heading(T("INSERT_TEXT_DETAILS", "Details")))
    Gap(detailGroup, 6)
    local details = AceGUI:Create("ScrollFrame")
    details:SetLayout("List")
    details:SetFullWidth(true)
    LockHeight(details, 112)
    detailGroup:AddChild(details)

    Gap(root, 20)
    local actions = AceGUI:Create("SimpleGroup")
    actions:SetLayout("Table")
    actions:SetUserData("table", {columns = {{weight = 1, alignH = "left"}, {weight = 1, alignH = "right"}}, alignV = "middle"})
    actions:SetFullWidth(true)
    actions:SetAutoAdjustHeight(false)
    LockHeight(actions, 30)
    root:AddChild(actions)
    local applyButton = CreateButton(T("INFO_TAG_LIBRARY_INSERT", "Insert Tag"), "primary_action", 115)
    actions:AddChild(applyButton)
    local cancelButton = CreateButton(T("INFO_COMMON_CANCEL", "Cancel"), "utility", 105)
    actions:AddChild(cancelButton)
    Gap(root, 4)

    context.window = window
    context.dialog = dialog
    context.widgets = {
        root = root,
        browser = browser,
        detailGroup = detailGroup,
        actions = actions,
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
    dialog:Show()
    TagLibraryView.Refresh(context)
    return window
end

function TagLibraryView.Show(context)
    if not context then
        return nil
    end

    if context.window then
        context.window:SetTitle(context.state.title or T("INFO_TAG_LIBRARY_TITLE", "Tag Library"))
        context.dialog:Show()
        TagLibraryView.Refresh(context)
        return context.window
    end

    return TagLibraryView.Create(context)
end

return TagLibraryView
