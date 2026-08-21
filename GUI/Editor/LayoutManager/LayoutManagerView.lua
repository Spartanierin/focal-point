local _, ns = ...

ns.GUI = ns.GUI or {}
ns.GUI.Editor = ns.GUI.Editor or {}
ns.GUI.Editor.LayoutManager = ns.GUI.Editor.LayoutManager or {}

local AceGUI = LibStub("AceGUI-3.0")
local FormWidgets = ns.GUI.Helpers and ns.GUI.Helpers.FormWidgets or {}
local TextStyles = ns.GUI.Helpers and ns.GUI.Helpers.TextStyles or {}
local LayoutManager = {}
ns.GUI.Editor.LayoutManager = LayoutManager

local ROW_WIDGET_TYPE = "FocalPointLayoutManagerRow"
local ROW_WIDGET_VERSION = 1
local ROW_HEIGHT = 30
local WINDOW_WIDTH = 560
local WINDOW_HEIGHT = 460

local context
local renameDialog

local ROW_COLORS = {
    fill = { 0.075, 0.085, 0.105, 0.78 },
    fillHover = { 0.105, 0.118, 0.142, 0.92 },
    fillSelected = { 0.210, 0.170, 0.082, 0.98 },
    border = { 0.22, 0.24, 0.28, 0.46 },
    borderHover = { 0.36, 0.39, 0.44, 0.72 },
    borderSelected = { 0.95, 0.76, 0.28, 0.98 },
    marker = { 1.00, 0.80, 0.24, 1.00 },
    markerMuted = { 0.58, 0.62, 0.68, 0.34 },
    name = { 0.93, 0.91, 0.84, 1.00 },
    nameSelected = { 1.00, 0.98, 0.88, 1.00 },
    status = { 0.72, 0.74, 0.78, 0.96 },
    active = { 0.96, 0.82, 0.38, 1.00 },
}

local SECTION_CHROME = {
    fill = { 0.060, 0.068, 0.084, 0.56 },
    border = { 0.25, 0.28, 0.33, 0.54 },
    footerFill = { 0.065, 0.072, 0.088, 0.66 },
    footerBorder = { 0.30, 0.32, 0.36, 0.44 },
}

local function T(key, fallback)
    local L = ns.L or {}
    local value = L[key]
    return type(value) == "string" and value ~= "" and value or fallback or key
end

local function ApplyFontStringStyle(fontString, role, size, color)
    if TextStyles.ApplyFontString then
        TextStyles.ApplyFontString(fontString, role or "label", {
            size = size,
            alpha = color and color[4] or 1,
        })
    elseif fontString and fontString.SetFont then
        fontString:SetFont(STANDARD_TEXT_FONT, size or 11, "")
    end
    if fontString and fontString.SetTextColor and color then
        fontString:SetTextColor(color[1] or 1, color[2] or 1, color[3] or 1, color[4] or 1)
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
    if FormWidgets.ApplyTextStyle and label.label then
        FormWidgets.ApplyTextStyle(label.label, role or "label", size or 11, 1)
    elseif TextStyles.ApplyLabelWidget then
        TextStyles.ApplyLabelWidget(label, role or "label", { size = size or 11 })
    end
    return label
end

local function CreateSpacer(width, height)
    local spacer = AceGUI:Create("Label")
    spacer:SetText("")
    if width then
        spacer:SetFullWidth(false)
        spacer:SetWidth(width)
    else
        spacer:SetFullWidth(true)
    end
    if height and spacer.SetHeight then
        spacer:SetHeight(height)
    end
    return spacer
end

local function LockContainerHeight(container, height)
    if not container then
        return
    end
    if container.SetAutoAdjustHeight then
        container:SetAutoAdjustHeight(false)
    end
    container:SetHeight(height)
end

local function ApplySectionChrome(widget, colors)
    local frame = widget and widget.frame
    if not frame then
        return
    end
    if not frame.SetBackdrop then
        return
    end

    frame:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
    })
    local fill = colors and colors.fill or SECTION_CHROME.fill
    local border = colors and colors.border or SECTION_CHROME.border
    frame:SetBackdropColor(fill[1], fill[2], fill[3], fill[4])
    frame:SetBackdropBorderColor(border[1], border[2], border[3], border[4])
end

local function SetTextureColor(texture, color)
    if texture and texture.SetColorTexture and color then
        texture:SetColorTexture(color[1] or 1, color[2] or 1, color[3] or 1, color[4] or 1)
    end
end

local function SetFontColor(fontString, color)
    if fontString and fontString.SetTextColor and color then
        fontString:SetTextColor(color[1] or 1, color[2] or 1, color[3] or 1, color[4] or 1)
    end
end

local function Shorten(value, limit)
    value = tostring(value or "")
    limit = tonumber(limit) or 42
    if #value <= limit then
        return value
    end
    return value:sub(1, math.max(1, limit - 3)) .. "..."
end

local function Trim(value)
    value = tostring(value or "")
    return value:gsub("^%s+", ""):gsub("%s+$", "")
end

local function ApplyRowBackdrop(frame, selected, hovered)
    if not (frame and frame.SetBackdropColor and frame.SetBackdropBorderColor) then
        return
    end
    local fill = selected and ROW_COLORS.fillSelected or (hovered and ROW_COLORS.fillHover or ROW_COLORS.fill)
    local border = selected and ROW_COLORS.borderSelected or (hovered and ROW_COLORS.borderHover or ROW_COLORS.border)
    frame:SetBackdropColor(fill[1], fill[2], fill[3], fill[4])
    frame:SetBackdropBorderColor(border[1], border[2], border[3], border[4])
end

local function UpdateRowVisual(widget)
    local item = widget and widget.item or nil
    local selected = widget and widget.selected == true
    local hovered = widget and widget.hovered == true
    local active = item and item.active == true

    ApplyRowBackdrop(widget.frame, selected, hovered)

    local status = ""
    if active then
        status = T("LAYOUT_MANAGER_ACTIVE", "Active")
    elseif item and item.readOnly then
        status = T("LAYOUT_MANAGER_READ_ONLY", "Read-only")
    end

    widget.nameText:SetText(Shorten(item and item.name or "", 48))
    widget.statusText:SetText(status)

    SetTextureColor(widget.marker, (selected or active) and ROW_COLORS.marker or ROW_COLORS.markerMuted)
    widget.marker:SetWidth(selected and 6 or (active and 4 or 2))
    widget.marker:SetAlpha((selected or active or hovered) and 1 or 0.55)
    SetFontColor(widget.nameText, selected and ROW_COLORS.nameSelected or ROW_COLORS.name)
    SetFontColor(widget.statusText, active and ROW_COLORS.active or ROW_COLORS.status)
end

local function RegisterLayoutRowWidget()
    if AceGUI:GetWidgetVersion(ROW_WIDGET_TYPE) and AceGUI:GetWidgetVersion(ROW_WIDGET_TYPE) >= ROW_WIDGET_VERSION then
        return
    end

    local methods = {}

    function methods:OnAcquire()
        self:SetFullWidth(true)
        self:SetHeight(ROW_HEIGHT)
        self.item = nil
        self.selected = false
        self.hovered = false
        if self.frame then
            self.frame:EnableMouse(true)
            self.frame:Show()
        end
        UpdateRowVisual(self)
    end

    function methods:OnRelease()
        self.item = nil
        self.selected = false
        self.hovered = false
        if self.nameText then
            self.nameText:SetText("")
        end
        if self.statusText then
            self.statusText:SetText("")
        end
    end

    function methods:SetItem(item, selectedLayoutId)
        self.item = item
        self.selected = item and item.id == selectedLayoutId or false
        UpdateRowVisual(self)
    end

    local function Constructor()
        local frame = CreateFrame("Button", nil, UIParent, "BackdropTemplate")
        frame:Hide()
        frame:SetHeight(ROW_HEIGHT)
        frame:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Buttons\\WHITE8X8",
            edgeSize = 1,
        })
        frame:SetBackdropColor(ROW_COLORS.fill[1], ROW_COLORS.fill[2], ROW_COLORS.fill[3], ROW_COLORS.fill[4])
        frame:SetBackdropBorderColor(ROW_COLORS.border[1], ROW_COLORS.border[2], ROW_COLORS.border[3], ROW_COLORS.border[4])

        local marker = frame:CreateTexture(nil, "ARTWORK")
        marker:SetPoint("TOPLEFT", frame, "TOPLEFT", 1, -1)
        marker:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 1, 1)
        marker:SetWidth(2)
        marker:SetColorTexture(ROW_COLORS.markerMuted[1], ROW_COLORS.markerMuted[2], ROW_COLORS.markerMuted[3], ROW_COLORS.markerMuted[4])

        local statusText = frame:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
        statusText:SetPoint("RIGHT", frame, "RIGHT", -12, 0)
        statusText:SetWidth(120)
        statusText:SetJustifyH("RIGHT")
        statusText:SetWordWrap(false)
        if statusText.SetMaxLines then
            statusText:SetMaxLines(1)
        end
        ApplyFontStringStyle(statusText, "help", 10, ROW_COLORS.status)

        local nameText = frame:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
        nameText:SetPoint("LEFT", frame, "LEFT", 16, 0)
        nameText:SetPoint("RIGHT", statusText, "LEFT", -10, 0)
        nameText:SetJustifyH("LEFT")
        nameText:SetWordWrap(false)
        if nameText.SetMaxLines then
            nameText:SetMaxLines(1)
        end
        ApplyFontStringStyle(nameText, "label", 11, ROW_COLORS.name)

        local widget = {
            frame = frame,
            type = ROW_WIDGET_TYPE,
            marker = marker,
            nameText = nameText,
            statusText = statusText,
        }
        frame.obj = widget
        frame:SetScript("OnEnter", function(self)
            local obj = self.obj
            if obj then
                obj.hovered = true
                UpdateRowVisual(obj)
            end
        end)
        frame:SetScript("OnLeave", function(self)
            local obj = self.obj
            if obj then
                obj.hovered = false
                UpdateRowVisual(obj)
            end
        end)
        frame:SetScript("OnMouseDown", function(self, button)
            local obj = self.obj
            if obj then
                obj:Fire("OnClick", button)
            end
            AceGUI:ClearFocus()
        end)

        for method, func in pairs(methods) do
            widget[method] = func
        end

        return AceGUI:RegisterAsWidget(widget)
    end

    AceGUI:RegisterWidgetType(ROW_WIDGET_TYPE, Constructor, ROW_WIDGET_VERSION)
end

RegisterLayoutRowWidget()

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

local function FocusWindow(window)
    if FormWidgets.FocusWindow then
        FormWidgets.FocusWindow(window, { centerIfHidden = true, strata = "FULLSCREEN_DIALOG" })
        return
    end
    if window and window.Show then
        window:Show()
    end
end

local function ResolveActiveLayoutId()
    local resolver = ns.ActiveLayoutResolver or {}
    if resolver.GetStoredActiveLayoutId then
        return resolver.GetStoredActiveLayoutId(ns.db)
    end
    local char = ns.db and ns.db.char or nil
    return type(char) == "table" and rawget(char, "activeLayoutId") or nil
end

local function ResolveLayoutName(summary)
    if type(summary) ~= "table" then
        return ""
    end
    local L = ns.L or {}
    if type(summary.labelKey) == "string" and L[summary.labelKey] then
        return L[summary.labelKey]
    end
    if type(summary.name) == "string" and summary.name ~= "" then
        return summary.name
    end
    return type(summary.id) == "string" and summary.id or ""
end

local function IsProductLayout(summary)
    return summary and (summary.source == "userLayout" or summary.source == "builtin")
end

local function FindSelectedItem(state)
    if not state or type(state.selectedLayoutId) ~= "string" then
        return nil
    end
    for _, item in ipairs(state.userLayouts or {}) do
        if item.id == state.selectedLayoutId then
            return item
        end
    end
    for _, item in ipairs(state.builtinLayouts or {}) do
        if item.id == state.selectedLayoutId then
            return item
        end
    end
    return nil
end

local function BuildState()
    local layoutService = ns.LayoutService or {}
    local summaries = layoutService.ListLayoutSummaries and layoutService.ListLayoutSummaries({ db = ns.db }) or {}
    local activeLayoutId = ResolveActiveLayoutId()
    local userLayouts = {}
    local builtinLayouts = {}
    local visible = {}

    for _, summary in ipairs(summaries) do
        if IsProductLayout(summary) and type(summary.id) == "string" and summary.id ~= "" then
            local item = {
                id = summary.id,
                name = ResolveLayoutName(summary),
                source = summary.source,
                readOnly = summary.readOnly == true or summary.source == "builtin",
                active = summary.id == activeLayoutId,
            }
            visible[item.id] = true
            if summary.source == "userLayout" then
                userLayouts[#userLayouts + 1] = item
            else
                builtinLayouts[#builtinLayouts + 1] = item
            end
        end
    end

    local selectedLayoutId = context and context.selectedLayoutId or nil
    if type(selectedLayoutId) ~= "string" or not visible[selectedLayoutId] then
        selectedLayoutId = visible[activeLayoutId] and activeLayoutId or nil
    end
    if not selectedLayoutId and userLayouts[1] then
        selectedLayoutId = userLayouts[1].id
    end
    if not selectedLayoutId and builtinLayouts[1] then
        selectedLayoutId = builtinLayouts[1].id
    end

    return {
        activeLayoutId = activeLayoutId,
        selectedLayoutId = selectedLayoutId,
        userLayouts = userLayouts,
        builtinLayouts = builtinLayouts,
    }
end

local function AddGroupHeader(parent, text)
    local row = AceGUI:Create("SimpleGroup")
    row:SetLayout("Flow")
    row:SetFullWidth(true)
    LockContainerHeight(row, 24)
    parent:AddChild(row)

    row:AddChild(CreateSpacer(10, 1))
    row:AddChild(CreateLabel(text, "sectionHeader", 12, 180))
    row:AddChild(CreateSpacer(8, 1))
    local divider = CreateLabel("", "help", 1, 270)
    row:AddChild(divider)
    if divider.frame and divider.frame.CreateTexture then
        local line = divider.frame:CreateTexture(nil, "ARTWORK")
        line:SetPoint("LEFT", divider.frame, "LEFT", 0, 0)
        line:SetPoint("RIGHT", divider.frame, "RIGHT", 0, 0)
        line:SetHeight(1)
        line:SetColorTexture(0.32, 0.34, 0.38, 0.52)
        divider._fpDivider = line
    end
end

local function AddLayoutRow(parent, item)
    local row = AceGUI:Create(ROW_WIDGET_TYPE)
    row:SetItem(item, context.selectedLayoutId)
    row:SetCallback("OnClick", function()
        context.selectedLayoutId = item.id
        LayoutManager.Refresh()
    end)
    parent:AddChild(row)
end

local function AddEmptyState(parent)
    local row = AceGUI:Create("SimpleGroup")
    row:SetLayout("Flow")
    row:SetFullWidth(true)
    LockContainerHeight(row, 26)
    parent:AddChild(row)
    row:AddChild(CreateSpacer(16, 1))
    row:AddChild(CreateLabel(T("LAYOUT_MANAGER_EMPTY_MY_LAYOUTS", "No custom layouts yet."), "help", 11, 480))
end

local function ResolveRenameStatus(reason)
    if reason == "name-required" then
        return T("LAYOUT_RENAME_NAME_REQUIRED", "Please enter a layout name.")
    end
    if reason == "name-too-long" then
        return T("LAYOUT_RENAME_NAME_TOO_LONG", "Layout name is too long.")
    end
    if reason == "duplicate-name" then
        return T("LAYOUT_RENAME_NAME_EXISTS", "A layout with this name already exists.")
    end
    if reason == "invalid-layout" or reason == "layout-not-found" then
        return T("LAYOUT_RENAME_INVALID_LAYOUT", "Select a custom layout first.")
    end
    return T("LAYOUT_RENAME_FAILED", "Layout could not be renamed.")
end

local function CloseRenameDialog()
    if renameDialog and renameDialog.Close then
        renameDialog:Close()
    elseif renameDialog and renameDialog.window and renameDialog.window.Hide then
        renameDialog.window:Hide()
    end
end

local function FocusDialogEditBox(editBox)
    local native = editBox and editBox.editbox or nil
    if native and native.SetFocus then
        native:SetFocus()
    end
    if native and native.HighlightText then
        native:HighlightText()
    end
end

local function OpenRenameDialog()
    if not (context and context.state) then
        return
    end

    local selected = FindSelectedItem(context.state)
    if not (selected and selected.source == "userLayout") then
        return
    end

    CloseRenameDialog()

    local dialog = FormWidgets.CreateCompactFormDialog and FormWidgets.CreateCompactFormDialog({
        title = T("LAYOUT_RENAME_TITLE", "Rename Layout"),
        description = T("LAYOUT_RENAME_DESCRIPTION", "Change the display name. The layout ID and design stay unchanged."),
        width = 420,
        height = 220,
        bodyHeight = 62,
    }) or nil
    if not dialog then
        return
    end

    local nameEdit = AceGUI:Create("EditBox")
    nameEdit:SetLabel(T("LAYOUT_RENAME_NAME", "Name"))
    nameEdit:SetFullWidth(true)
    nameEdit:SetText(selected.name or "")
    if nameEdit.DisableButton then
        nameEdit:DisableButton(true)
    end
    if FormWidgets.StyleEditBox then
        FormWidgets.StyleEditBox(nameEdit, "editor_inset")
    end
    dialog.body:AddChild(nameEdit)

    local function setStatus(message)
        dialog:SetStatus(message)
    end

    local function updateRenameButton()
        if dialog.primaryButton then
            dialog.primaryButton:SetDisabled(Trim(nameEdit:GetText() or "") == "")
        end
    end

    local function submitRename()
        local mutations = ns.LayoutMutations or {}
        local ok, resultOrReason = false, "rename-unavailable"
        if mutations.RenameUserLayout then
            ok, resultOrReason = mutations.RenameUserLayout(selected.id, nameEdit:GetText())
        end
        if ok then
            context.selectedLayoutId = selected.id
            CloseRenameDialog()
            local canvasToolbar = ns.GUI and ns.GUI.Editor and ns.GUI.Editor.CanvasToolbar
            if canvasToolbar and canvasToolbar.Refresh then
                canvasToolbar.Refresh()
            else
                LayoutManager.Refresh()
            end
            return
        end

        setStatus(ResolveRenameStatus(resultOrReason))
        updateRenameButton()
    end

    nameEdit:SetCallback("OnTextChanged", function()
        setStatus("")
        updateRenameButton()
    end)
    nameEdit:SetCallback("OnEnterPressed", function()
        if Trim(nameEdit:GetText() or "") ~= "" then
            submitRename()
        end
    end)

    dialog:SetActions({
        secondary = {
            text = T("INFO_COMMON_CANCEL", "Cancel"),
            role = "utility",
            width = 110,
            onClick = CloseRenameDialog,
        },
        primary = {
            text = T("LAYOUT_RENAME_CONFIRM", "Rename"),
            role = "primary_action",
            width = 120,
            onClick = submitRename,
        },
    })

    dialog.window:SetCallback("OnClose", function()
        if renameDialog == dialog then
            renameDialog = nil
        end
    end)

    renameDialog = dialog
    renameDialog.nameEdit = nameEdit
    updateRenameButton()
    dialog:Show()
    FocusDialogEditBox(nameEdit)
end

local function RefreshActions()
    if not (context and context.widgets) then
        return
    end

    local selected = FindSelectedItem(context.state)
    local canRename = selected and selected.source == "userLayout"
    if context.widgets.renameButton then
        context.widgets.renameButton:SetText(T("LAYOUT_MANAGER_RENAME", "Rename"))
        context.widgets.renameButton:SetDisabled(not canRename)
        if FormWidgets.ApplyModalActionButtonVisual then
            FormWidgets.ApplyModalActionButtonVisual(context.widgets.renameButton, "utility")
        end
    end
end

local function RefreshList()
    if not (context and context.widgets and context.widgets.scroll) then
        return
    end

    local state = BuildState()
    context.state = state
    context.selectedLayoutId = state.selectedLayoutId
    context.activeLayoutId = state.activeLayoutId

    local scroll = context.widgets.scroll
    scroll:ReleaseChildren()

    AddGroupHeader(scroll, T("LAYOUT_MANAGER_MY_LAYOUTS", "My Layouts"))
    if #state.userLayouts == 0 then
        AddEmptyState(scroll)
    else
        for _, item in ipairs(state.userLayouts) do
            AddLayoutRow(scroll, item)
        end
    end

    scroll:AddChild(CreateSpacer(nil, 8))
    AddGroupHeader(scroll, T("LAYOUT_MANAGER_BUILT_IN_LAYOUTS", "Built-in Layouts"))
    for _, item in ipairs(state.builtinLayouts) do
        AddLayoutRow(scroll, item)
    end

    if context.widgets.status then
        context.widgets.status:SetText(string.format(
            T("LAYOUT_MANAGER_STATUS_COUNTS", "%d custom layouts, %d built-in layouts"),
            #state.userLayouts,
            #state.builtinLayouts
        ))
    end

    if scroll.FixScroll then
        scroll:FixScroll()
    end

    RefreshActions()
end

local function Close()
    CloseRenameDialog()
    if context and context.window and context.window.Hide then
        context.selectedLayoutId = nil
        context.window:Hide()
    end
end

local function CreateWindow()
    local window = AceGUI:Create("Window")
    window:SetTitle(T("LAYOUT_MANAGER_TITLE", "Manage Layouts"))
    window:SetLayout("Fill")
    window:SetWidth(WINDOW_WIDTH)
    window:SetHeight(WINDOW_HEIGHT)
    window:EnableResize(false)

    if window.frame then
        window.frame:SetClampedToScreen(true)
        window.frame:SetFrameStrata("FULLSCREEN_DIALOG")
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

    local titleRow = AceGUI:Create("SimpleGroup")
    titleRow:SetLayout("Flow")
    titleRow:SetFullWidth(true)
    LockContainerHeight(titleRow, 30)
    root:AddChild(titleRow)
    titleRow:AddChild(CreateSpacer(12, 1))
    titleRow:AddChild(CreateLabel(T("LAYOUT_MANAGER_DESCRIPTION", "View available layouts. Activate them from the Canvas Toolbar."), "help", 11, 505))

    local scroll = AceGUI:Create("ScrollFrame")
    scroll:SetLayout("Flow")
    scroll:SetFullWidth(true)
    scroll:SetHeight(330)
    root:AddChild(scroll)
    ApplySectionChrome(scroll, {
        fill = SECTION_CHROME.fill,
        border = SECTION_CHROME.border,
    })

    local footer = AceGUI:Create("SimpleGroup")
    footer:SetLayout("Flow")
    footer:SetFullWidth(true)
    LockContainerHeight(footer, 42)
    root:AddChild(footer)
    ApplySectionChrome(footer, {
        fill = SECTION_CHROME.footerFill,
        border = SECTION_CHROME.footerBorder,
    })

    footer:AddChild(CreateSpacer(12, 1))
    local status = CreateLabel("", "help", 10, 280)
    footer:AddChild(status)
    footer:AddChild(CreateSpacer(22, 1))
    local renameButton = AceGUI:Create("Button")
    renameButton:SetText(T("LAYOUT_MANAGER_RENAME", "Rename"))
    renameButton:SetWidth(105)
    renameButton:SetFullWidth(false)
    if FormWidgets.ApplyModalActionButtonVisual then
        FormWidgets.ApplyModalActionButtonVisual(renameButton, "utility")
    end
    footer:AddChild(renameButton)
    footer:AddChild(CreateSpacer(8, 1))
    local closeButton = AceGUI:Create("Button")
    closeButton:SetText(T("INFO_COMMON_CLOSE", "Close"))
    closeButton:SetWidth(105)
    closeButton:SetFullWidth(false)
    if FormWidgets.ApplyModalActionButtonVisual then
        FormWidgets.ApplyModalActionButtonVisual(closeButton, "utility")
    end
    footer:AddChild(closeButton)

    context.window = window
    context.widgets = {
        root = root,
        scroll = scroll,
        footer = footer,
        status = status,
        renameButton = renameButton,
        closeButton = closeButton,
    }

    renameButton:SetCallback("OnClick", OpenRenameDialog)
    closeButton:SetCallback("OnClick", Close)
    window:SetCallback("OnClose", function()
        CloseRenameDialog()
        context.selectedLayoutId = nil
        if GameTooltip and GameTooltip.Hide then
            GameTooltip:Hide()
        end
    end)

    if FormWidgets.CenterWindow then
        FormWidgets.CenterWindow(window)
    end
    FocusWindow(window)
    RefreshList()
    return window
end

function LayoutManager.Open()
    context = context or {}
    if context.window then
        RefreshList()
        FocusWindow(context.window)
        return true
    end
    CreateWindow()
    return true
end

function LayoutManager.Refresh()
    if not (context and context.window) then
        return
    end
    RefreshList()
end

function LayoutManager.Close()
    Close()
end

return LayoutManager
