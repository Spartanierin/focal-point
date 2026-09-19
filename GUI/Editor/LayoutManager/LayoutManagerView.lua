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
local WINDOW_CHROME_HEIGHT = 57
local WINDOW_DESCRIPTION_HEIGHT = 32
local WINDOW_LIST_HEIGHT = 330
local WINDOW_STATUS_HEIGHT = 22
local WINDOW_FOOTER_HEIGHT = 42
local WINDOW_TRANSFER_ACTIONS_HEIGHT = 32
local WINDOW_HEIGHT = WINDOW_CHROME_HEIGHT + WINDOW_DESCRIPTION_HEIGHT + WINDOW_LIST_HEIGHT + WINDOW_STATUS_HEIGHT + WINDOW_FOOTER_HEIGHT + WINDOW_TRANSFER_ACTIONS_HEIGHT + 6 -- compact body top inset

local context
local renameDialog
local copyDialog
local deleteDialog
local transferDialog

local function GetListSelectionRowColors()
    local skins = ns.GUI and ns.GUI.Skins or nil
    local palette = skins and skins.GetFormPalette and skins.GetFormPalette() or {}
    return palette.ListSelectionRow or {}
end

local ROW_COLORS = {
    status = { 0.72, 0.74, 0.78, 0.96 },
    active = { 0.96, 0.82, 0.38, 1.00 },
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
    local colors = GetListSelectionRowColors()
    local fill = selected and colors.fillSelected or (hovered and colors.fillHover or colors.fill)
    local border = selected and colors.borderSelected or (hovered and colors.borderHover or colors.border)
    frame:SetBackdropColor(fill[1], fill[2], fill[3], fill[4])
    frame:SetBackdropBorderColor(border[1], border[2], border[3], border[4])
end

local function UpdateRowVisual(widget)
    local item = widget and widget.item or nil
    local selected = widget and widget.selected == true
    local hovered = widget and widget.hovered == true
    local active = item and item.active == true
    local colors = GetListSelectionRowColors()

    ApplyRowBackdrop(widget.frame, selected, hovered)

    local status = ""
    if active then
        status = T("LAYOUT_MANAGER_ACTIVE", "Active")
    elseif item and item.readOnly then
        status = T("LAYOUT_MANAGER_READ_ONLY", "Read-only")
    end

    widget.nameText:SetText(Shorten(item and item.name or "", 48))
    widget.statusText:SetText(status)

    SetTextureColor(widget.marker, (selected or active) and colors.marker or colors.markerMuted)
    widget.marker:SetWidth(selected and 6 or (active and 4 or 2))
    widget.marker:SetAlpha((selected or active or hovered) and 1 or 0.55)
    SetFontColor(widget.nameText, selected and colors.nameSelected or colors.name)
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
        local colors = GetListSelectionRowColors()
        frame:SetBackdropColor(colors.fill[1], colors.fill[2], colors.fill[3], colors.fill[4])
        frame:SetBackdropBorderColor(colors.border[1], colors.border[2], colors.border[3], colors.border[4])

        local marker = frame:CreateTexture(nil, "ARTWORK")
        marker:SetPoint("TOPLEFT", frame, "TOPLEFT", 1, -1)
        marker:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 1, 1)
        marker:SetWidth(2)
        marker:SetColorTexture(colors.markerMuted[1], colors.markerMuted[2], colors.markerMuted[3], colors.markerMuted[4])

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
        ApplyFontStringStyle(nameText, "label", 11, colors.name)

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
    local layoutService = ns.LayoutService or {}
    if layoutService.GetDisplayName then
        return layoutService.GetDisplayName(summary)
    end
    return type(summary) == "table" and (summary.name or summary.id) or ""
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
    row:AddChild(CreateLabel(text, "parchmentSectionHeader", 12, 180))
    row:AddChild(CreateSpacer(8, 1))
    local divider = AceGUI:Create("SimpleGroup")
    divider:SetAutoAdjustHeight(false)
    divider:SetFullWidth(false)
    divider:SetWidth(270)
    divider:SetHeight(1)
    row:AddChild(divider)
    if divider.frame and divider.frame.CreateTexture then
        local line = divider._fpDivider
        if not line then
            line = divider.frame:CreateTexture(nil, "ARTWORK")
            divider._fpDivider = line
            divider.frame:HookScript("OnHide", function()
                line:Hide()
            end)
        end
        line:ClearAllPoints()
        line:SetPoint("LEFT", divider.frame, "LEFT", 0, 0)
        line:SetPoint("RIGHT", divider.frame, "RIGHT", 0, 0)
        line:SetHeight(1)
        local skins = ns.GUI and ns.GUI.Skins or nil
        local palette = skins and skins.GetFormPalette and skins.GetFormPalette() or {}
        SetTextureColor(line, (palette.Chrome or {}).sectionBorder)
        line:Show()
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
    row:AddChild(CreateLabel(T("LAYOUT_MANAGER_EMPTY_MY_LAYOUTS", "No custom layouts yet."), "parchmentMuted", 11, 480))
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

local function ResolveCopyStatus(reason)
    if reason == "name-required" then
        return T("LAYOUT_RENAME_NAME_REQUIRED", "Please enter a layout name.")
    end
    if reason == "name-too-long" then
        return T("LAYOUT_RENAME_NAME_TOO_LONG", "Layout name is too long.")
    end
    if reason == "duplicate-name" then
        return T("LAYOUT_RENAME_NAME_EXISTS", "A layout with this name already exists.")
    end
    if reason == "unsupported-source" or reason == "layout-not-found" or reason == "missing-builtin" then
        return T("LAYOUT_COPY_INVALID_SOURCE", "Select a layout that can be copied.")
    end
    return T("LAYOUT_COPY_FAILED", "Layout copy could not be created.")
end

local function ResolveDeleteStatus(reason)
    if reason == "active-layout" then
        return T("LAYOUT_DELETE_ACTIVE_BLOCKED", "Activate another layout before deleting this one.")
    end
    if reason == "invalid-layout" or reason == "layout-not-found" then
        return T("LAYOUT_DELETE_INVALID_LAYOUT", "Select a custom layout first.")
    end
    return T("LAYOUT_DELETE_FAILED", "Layout could not be deleted.")
end

local function RefreshCanvasPicker()
    local canvasToolbar = ns.GUI and ns.GUI.Editor and ns.GUI.Editor.CanvasToolbar
    if canvasToolbar and canvasToolbar.Refresh then
        canvasToolbar.Refresh()
        return
    end
    LayoutManager.Refresh()
end

local function SetButtonVisible(button, visible, width)
    if not button then
        return
    end
    if button.frame then
        if visible and button.frame.Show then
            button.frame:Show()
        elseif not visible and button.frame.Hide then
            button.frame:Hide()
        end
    end
    if button.SetWidth then
        button:SetWidth(visible and width or 1)
    end
    if button.SetDisabled then
        button:SetDisabled(not visible)
    end
end

local function AnchorFooterButton(button, point, relativeTo, relativePoint, xOffset, yOffset)
    local frame = button and button.frame
    if not frame then
        return
    end
    frame:ClearAllPoints()
    frame:SetPoint(point, relativeTo, relativePoint, xOffset or 0, yOffset or 0)
end

local function LayoutFooterActions()
    if not (context and context.widgets and context.widgets.actionContainer) then
        return
    end

    local actionFrame = context.widgets.actionContainer.frame
    local renameButton = context.widgets.renameButton
    local copyButton = context.widgets.copyButton
    local deleteButton = context.widgets.deleteButton
    local gap = 8

    local previous
    if renameButton and renameButton.frame and renameButton.frame:IsShown() then
        AnchorFooterButton(renameButton, "LEFT", actionFrame, "LEFT", 12, 0)
        previous = renameButton.frame
    end
    if copyButton and copyButton.frame and copyButton.frame:IsShown() then
        if previous then
            AnchorFooterButton(copyButton, "LEFT", previous, "RIGHT", gap, 0)
        else
            AnchorFooterButton(copyButton, "LEFT", actionFrame, "LEFT", 12, 0)
        end
        previous = copyButton.frame
    end
    if deleteButton and deleteButton.frame and deleteButton.frame:IsShown() then
        if previous then
            AnchorFooterButton(deleteButton, "LEFT", previous, "RIGHT", gap, 0)
        else
            AnchorFooterButton(deleteButton, "LEFT", actionFrame, "LEFT", 12, 0)
        end
    end
end

local function CloseRenameDialog()
    if renameDialog and renameDialog.Close then
        renameDialog:Close()
    elseif renameDialog and renameDialog.window and renameDialog.window.Hide then
        renameDialog.window:Hide()
    end
end

local function CloseCopyDialog()
    if copyDialog and copyDialog.Close then
        copyDialog:Close()
    elseif copyDialog and copyDialog.window and copyDialog.window.Hide then
        copyDialog.window:Hide()
    end
end

local function CloseDeleteDialog()
    if deleteDialog and deleteDialog.Hide then
        deleteDialog:Hide()
    elseif deleteDialog and deleteDialog.window and deleteDialog.window.Hide then
        deleteDialog.window:Hide()
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

local function CreateDeleteConfirmDialog(item)
    local dialog = FormWidgets.CreateCompactConfirmation({
        title = T("LAYOUT_DELETE_TITLE", "Delete Layout?"),
        message = string.format(T("LAYOUT_DELETE_MESSAGE", "This permanently deletes \"%s\".\nThis cannot be undone."), item and item.name or ""),
        width = 430,
        messageHeight = 52,
        primary = {
            text = T("LAYOUT_DELETE_CONFIRM", "Delete"),
            role = "danger",
            width = 100,
        },
        cancel = {
            text = T("INFO_COMMON_CANCEL", "Cancel"),
            role = "utility",
            width = 100,
        },
    })
    if not dialog then
        return nil
    end

    return {
        window = dialog.window,
        dialog = dialog,
        status = dialog.confirmationStatus,
        cancelButton = dialog.cancelButton,
        deleteButton = dialog.primaryButton,
    }
end

local function CreateLayoutNameDialog(options)
    options = options or {}
    local descriptionHeight = 32
    local nameHeight = 50
    local descriptionNameGap = 6
    local nameStatusGap = 6
    local statusHeight = 16
    local statusActionGap = 6
    local actionHeight = 30
    local bottomPadding = 6
    local dialog = FormWidgets.CreateCompactFormDialog and FormWidgets.CreateCompactFormDialog({
        title = options.title,
        width = 420,
        height = 57 + descriptionHeight + descriptionNameGap + nameHeight + nameStatusGap + statusHeight + statusActionGap + actionHeight + bottomPadding,
        bodyLayout = "List",
        addBodySpacer = false,
        contentRoot = true,
    }) or nil
    if not dialog then
        return nil
    end

    local description = FormWidgets.CreateBodyText(options.description or "", "label", 12, nil, dialog.contentWidth, false)
    description:SetFullWidth(true)
    description:SetHeight(descriptionHeight)
    dialog.body:AddChild(description)

    local function AddSpacer(height)
        local spacer = AceGUI:Create("Label")
        spacer:SetText("")
        spacer:SetFullWidth(true)
        spacer:SetHeight(height)
        dialog.body:AddChild(spacer)
    end

    AddSpacer(descriptionNameGap)

    local nameEdit = AceGUI:Create("EditBox")
    nameEdit:SetLabel(options.nameLabel or T("LAYOUT_RENAME_NAME", "Name"))
    nameEdit:SetFullWidth(true)
    nameEdit:SetHeight(nameHeight)
    nameEdit:SetText(options.defaultName or "")
    if nameEdit.DisableButton then
        nameEdit:DisableButton(true)
    end
    if FormWidgets.StyleEditBox then
        FormWidgets.StyleEditBox(nameEdit, "editor_inset")
    end
    dialog.body:AddChild(nameEdit)

    AddSpacer(nameStatusGap)

    local status = AceGUI:Create("Label")
    status:SetText(" ")
    status:SetFullWidth(true)
    status:SetHeight(statusHeight)
    if FormWidgets.ApplyTextStyle and status.label then
        FormWidgets.ApplyTextStyle(status.label, "help", 10, 1)
    end
    dialog.body:AddChild(status)

    AddSpacer(statusActionGap)

    local actionContainer = AceGUI:Create("SimpleGroup")
    actionContainer:SetFullWidth(true)
    actionContainer:SetHeight(actionHeight)
    actionContainer:SetLayout("Flow")
    if actionContainer.SetAutoAdjustHeight then
        actionContainer:SetAutoAdjustHeight(false)
    end
    dialog.body:AddChild(actionContainer)
    AddSpacer(bottomPadding)

    local function updatePrimaryButton()
        if dialog.primaryButton then
            dialog.primaryButton:SetDisabled(Trim(nameEdit:GetText() or "") == "")
        end
    end

    local function clearStatus()
        dialog:SetStatus("", nil, status)
        updatePrimaryButton()
    end

    nameEdit:SetCallback("OnTextChanged", clearStatus)
    nameEdit:SetCallback("OnEnterPressed", function()
        if Trim(nameEdit:GetText() or "") ~= "" and options.onSubmit then
            options.onSubmit(dialog, nameEdit)
        end
    end)

    dialog:SetActions({
        cancel = {
            text = T("INFO_COMMON_CANCEL", "Cancel"),
            role = "utility",
            width = 110,
            onClick = options.onCancel,
        },
        primary = {
            text = options.primaryText,
            role = "primary_action",
            width = 120,
            onClick = function()
                if options.onSubmit then
                    options.onSubmit(dialog, nameEdit)
                end
            end,
        },
    }, actionContainer)

    dialog.nameEdit = nameEdit
    dialog.confirmationStatus = status
    updatePrimaryButton()
    return dialog
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

    local dialog = CreateLayoutNameDialog({
        title = T("LAYOUT_RENAME_TITLE", "Rename Layout"),
        description = T("LAYOUT_RENAME_DESCRIPTION", "Change the display name. The layout ID and design stay unchanged."),
        defaultName = selected.name or "",
        nameLabel = T("LAYOUT_RENAME_NAME", "Name"),
        primaryText = T("LAYOUT_RENAME_CONFIRM", "Rename"),
        onCancel = CloseRenameDialog,
    })
    if not dialog then
        return
    end

    local function setStatus(message)
        dialog:SetStatus(message, "error", dialog.confirmationStatus)
    end

    local function submitRename(_, nameEdit)
        local mutations = ns.LayoutMutations or {}
        local ok, resultOrReason = false, "rename-unavailable"
        if mutations.RenameUserLayout then
            ok, resultOrReason = mutations.RenameUserLayout(selected.id, nameEdit:GetText())
        end
        if ok then
            context.selectedLayoutId = selected.id
            CloseRenameDialog()
            RefreshCanvasPicker()
            return
        end

        setStatus(ResolveRenameStatus(resultOrReason))
        if dialog.primaryButton then
            dialog.primaryButton:SetDisabled(Trim(nameEdit:GetText() or "") == "")
        end
    end
    dialog.primaryButton:SetCallback("OnClick", function()
        submitRename(dialog, dialog.nameEdit)
    end)
    dialog.nameEdit:SetCallback("OnEnterPressed", function()
        if Trim(dialog.nameEdit:GetText() or "") ~= "" then
            submitRename(dialog, dialog.nameEdit)
        end
    end)

    dialog.window:SetCallback("OnClose", function()
        if renameDialog == dialog then
            renameDialog = nil
        end
    end)

    renameDialog = dialog
    dialog:Show()
    FocusDialogEditBox(dialog.nameEdit)
end

local function OpenCopyDialog()
    if not (context and context.state) then
        return
    end

    local selected = FindSelectedItem(context.state)
    if not (selected and (selected.source == "userLayout" or selected.source == "builtin")) then
        return
    end

    CloseCopyDialog()

    local mutations = ns.LayoutMutations or {}
    local defaultName = mutations.SuggestLayoutCopyName and mutations.SuggestLayoutCopyName(selected.name) or (selected.name or "Layout") .. " Copy"
    local isBuiltin = selected.source == "builtin"
    local dialog = CreateLayoutNameDialog({
        title = isBuiltin and T("LAYOUT_COPY_TITLE_BUILTIN", "Create Layout Copy") or T("LAYOUT_COPY_TITLE_DUPLICATE", "Duplicate Layout"),
        description = isBuiltin
            and T("LAYOUT_COPY_DESCRIPTION_BUILTIN", "Create a personal layout from this built-in template.")
            or T("LAYOUT_COPY_DESCRIPTION", "Create a new custom layout from the selected source. It will not be activated automatically."),
        defaultName = defaultName,
        nameLabel = T("LAYOUT_COPY_NAME", "Name"),
        primaryText = isBuiltin and T("LAYOUT_MANAGER_CREATE_FROM_TEMPLATE", "Create Layout from This") or T("LAYOUT_MANAGER_DUPLICATE", "Duplicate"),
        onCancel = CloseCopyDialog,
    })
    if not dialog then
        return
    end

    local function submitCopy(_, nameEdit)
        local ok, resultOrReason = false, "copy-unavailable"
        if mutations.CopyLayout then
            ok, resultOrReason = mutations.CopyLayout(selected.id, nameEdit:GetText(), { activate = selected.source == "builtin", reason = "layout-manager-copy" })
        end
        if ok then
            context.selectedLayoutId = resultOrReason
            CloseCopyDialog()
            RefreshCanvasPicker()
            return
        end

        dialog:SetStatus(ResolveCopyStatus(resultOrReason), "error", dialog.confirmationStatus)
        if dialog.primaryButton then
            dialog.primaryButton:SetDisabled(Trim(nameEdit:GetText() or "") == "")
        end
    end

    dialog.primaryButton:SetCallback("OnClick", function()
        submitCopy(dialog, dialog.nameEdit)
    end)
    dialog.nameEdit:SetCallback("OnEnterPressed", function()
        if Trim(dialog.nameEdit:GetText() or "") ~= "" then
            submitCopy(dialog, dialog.nameEdit)
        end
    end)

    dialog.window:SetCallback("OnClose", function()
        if copyDialog == dialog then
            copyDialog = nil
        end
    end)

    copyDialog = dialog
    dialog:Show()
    FocusDialogEditBox(dialog.nameEdit)
end

local function OpenDeleteDialog()
    if not (context and context.state) then
        return
    end

    local selected = FindSelectedItem(context.state)
    if not (selected and selected.source == "userLayout" and selected.id ~= context.activeLayoutId) then
        return
    end

    CloseDeleteDialog()

    local dialog = CreateDeleteConfirmDialog(selected)
    if not dialog then
        return
    end

    dialog.cancelButton:SetCallback("OnClick", CloseDeleteDialog)
    dialog.deleteButton:SetCallback("OnClick", function(widget)
        if widget and widget.SetDisabled then
            widget:SetDisabled(true)
        end

        local mutations = ns.LayoutMutations or {}
        local ok, resultOrReason = false, "delete-unavailable"
        if mutations.DeleteUserLayout then
            ok, resultOrReason = mutations.DeleteUserLayout(selected.id)
        end

        if ok then
            context.selectedLayoutId = nil
            CloseDeleteDialog()
            RefreshCanvasPicker()
            return
        end

        if dialog.dialog and dialog.dialog.SetStatus then
            dialog.dialog:SetStatus(ResolveDeleteStatus(resultOrReason), "error", dialog.status)
        end
        if widget and widget.SetDisabled then
            widget:SetDisabled(false)
        end
    end)
    dialog.window:SetCallback("OnClose", function()
        if deleteDialog == dialog then
            deleteDialog = nil
        end
    end)

    deleteDialog = dialog
    FocusWindow(dialog.window)
end

local function CloseTransferDialog()
    if transferDialog then transferDialog:Close() end
end

local function TransferError(reason)
    local key = ({
        ["invalid-header"] = "LAYOUT_TRANSFER_ERROR_HEADER",
        ["invalid-encoding"] = "LAYOUT_TRANSFER_ERROR_ENCODING",
        ["transfer-version"] = "LAYOUT_TRANSFER_ERROR_VERSION",
        ["layout-version"] = "LAYOUT_TRANSFER_ERROR_VERSION",
        ["name-required"] = "LAYOUT_RENAME_NAME_REQUIRED",
        ["name-too-long"] = "LAYOUT_RENAME_NAME_TOO_LONG",
        ["name-invalid"] = "LAYOUT_TRANSFER_ERROR_NAME",
        ["duplicate-name"] = "LAYOUT_RENAME_NAME_EXISTS",
        ["too-large"] = "LAYOUT_TRANSFER_ERROR_SIZE",
        ["too-complex"] = "LAYOUT_TRANSFER_ERROR_SIZE",
        ["units-invalid"] = "LAYOUT_TRANSFER_ERROR_PAYLOAD",
        ["templates-invalid"] = "LAYOUT_TRANSFER_ERROR_PAYLOAD",
        ["payload-invalid"] = "LAYOUT_TRANSFER_ERROR_PAYLOAD",
        ["document-invalid"] = "LAYOUT_TRANSFER_ERROR_PAYLOAD",
    })[reason] or "LAYOUT_TRANSFER_ERROR_FAILED"
    return T(key, "Layout transfer failed.")
end

local function OpenTransferDialog(export)
    local transfer = ns.LayoutTransfer
    if not (context and transfer) then return end
    local exportText
    if export then
        local selected = FindSelectedItem(context.state)
        if not (selected and selected.source == "userLayout" and not selected.readOnly) then return end
        local reason
        exportText, reason = transfer.Export(selected.id)
        if not exportText then
            context.dialog:SetStatus(TransferError(reason), "error", context.widgets.status)
            return
        end
    end
    CloseTransferDialog()
    local dialog = FormWidgets.CreateCompactFormDialog({
        title = T(export and "LAYOUT_TRANSFER_EXPORT_TITLE" or "LAYOUT_TRANSFER_IMPORT_TITLE"),
        description = T(export and "LAYOUT_TRANSFER_EXPORT_HINT" or "LAYOUT_TRANSFER_IMPORT_HINT"),
        width = 560,
        formContentHeight = 312,
        bodyLayout = "List",
        addBodySpacer = false,
        contentRoot = true,
    })

    local body = dialog.body
    body:ReleaseChildren()
    body:SetLayout("List")

    local description = AceGUI:Create("Label")
    description:SetText(T(export and "LAYOUT_TRANSFER_EXPORT_HINT" or "LAYOUT_TRANSFER_IMPORT_HINT"))
    description:SetFullWidth(true)
    description:SetHeight(24)
    if FormWidgets.ApplyTextStyle and description.label then
        FormWidgets.ApplyTextStyle(description.label, "help", 11, 1)
    end
    body:AddChild(description)

    local descriptionGap = AceGUI:Create("Label")
    descriptionGap:SetText("")
    descriptionGap:SetFullWidth(true)
    descriptionGap:SetHeight(6)
    body:AddChild(descriptionGap)

    local edit = AceGUI:Create("MultiLineEditBox")
    edit:SetLabel("")
    edit:SetNumLines(10)
    edit:SetFullWidth(true)
    edit:SetFullHeight(false)
    edit:SetHeight(220)
    edit:DisableButton(true)
    edit:SetText(exportText or "")
    if FormWidgets.StyleEditBox then FormWidgets.StyleEditBox(edit, "editor_inset") end
    body:AddChild(edit)

    local statusTarget = AceGUI:Create("Label")
    statusTarget:SetText(" ")
    statusTarget:SetFullWidth(true)
    statusTarget:SetHeight(32)
    if FormWidgets.ApplyTextStyle and statusTarget.label then
        FormWidgets.ApplyTextStyle(statusTarget.label, "help", 10, 1)
    end
    body:AddChild(statusTarget)

    local actionContainer = AceGUI:Create("SimpleGroup")
    actionContainer:SetLayout("Flow")
    actionContainer:SetFullWidth(true)
    if actionContainer.SetAutoAdjustHeight then
        actionContainer:SetAutoAdjustHeight(false)
    end
    actionContainer:SetHeight(30)
    body:AddChild(actionContainer)

    local function SelectText()
        edit:SetFocus()
        edit:HighlightText()
    end
    dialog:SetActions({
        primary = {
            text = T(export and "LAYOUT_TRANSFER_SELECT_ALL" or "LAYOUT_TRANSFER_IMPORT"),
            onClick = function()
                if export then SelectText(); return end
                local ok, id, name = transfer.Import(edit:GetText())
                if not ok then
                    dialog:SetStatus(TransferError(id), "error", statusTarget)
                    return
                end
                context.selectedLayoutId = id
                LayoutManager.Refresh() -- library selection only; never Activate
                edit:SetText("")
                dialog.primaryButton:SetDisabled(true)
                dialog:SetStatus(string.format(T("LAYOUT_TRANSFER_IMPORTED"), name), "success", statusTarget)
            end,
        },
        cancel = {text=T("INFO_COMMON_CLOSE", "Close"), onClick=CloseTransferDialog},
    }, actionContainer)
    if not export then
        dialog.primaryButton:SetDisabled(true)
        edit:SetCallback("OnTextChanged", function()
            local text = edit:GetText() or ""
            dialog:SetStatus("", nil, statusTarget)
            dialog.primaryButton:SetDisabled(Trim(text) == "")
        end)
    end
    dialog.window:SetCallback("OnClose", function()
        if dialog.released then return end
        dialog.released = true
        if transferDialog == dialog then transferDialog = nil end
        if AceGUI.FocusedWidget == edit then AceGUI:ClearFocus() else edit:ClearFocus() end
        if dialog.shell and dialog.shell.Release then
            dialog.shell:Release()
        end
        dialog.window.frame._fpCompactFormShell = nil
        AceGUI:Release(dialog.window)
    end)
    transferDialog = dialog
    dialog:Show()
    if export then SelectText() else edit:SetFocus() end
end

local function RefreshActions()
    if not (context and context.widgets) then
        return
    end

    local selected = FindSelectedItem(context.state)
    local isUserLayout = selected and selected.source == "userLayout"
    local isBuiltin = selected and selected.source == "builtin"
    local canDelete = isUserLayout and selected.id ~= context.activeLayoutId
    if context.widgets.exportButton then
        context.widgets.exportButton:SetDisabled(not (isUserLayout and not selected.readOnly))
    end
    if context.widgets.renameButton then
        context.widgets.renameButton:SetText(T("LAYOUT_MANAGER_RENAME", "Rename"))
        SetButtonVisible(context.widgets.renameButton, isUserLayout, 105)
        if FormWidgets.ApplyModalActionButtonVisual then
            FormWidgets.ApplyModalActionButtonVisual(context.widgets.renameButton, "utility")
        end
    end
    if context.widgets.copyButton then
        context.widgets.copyButton:SetText(isBuiltin and T("LAYOUT_MANAGER_CREATE_FROM_TEMPLATE", "Create Layout from This") or T("LAYOUT_MANAGER_DUPLICATE", "Duplicate"))
        SetButtonVisible(context.widgets.copyButton, isUserLayout or isBuiltin, isBuiltin and 120 or 105)
        if FormWidgets.ApplyModalActionButtonVisual then
            FormWidgets.ApplyModalActionButtonVisual(context.widgets.copyButton, "utility")
        end
    end
    if context.widgets.deleteButton then
        context.widgets.deleteButton:SetText(T("LAYOUT_MANAGER_DELETE", "Delete"))
        SetButtonVisible(context.widgets.deleteButton, isUserLayout, 105)
        context.widgets.deleteButton:SetDisabled(not canDelete)
        if FormWidgets.ApplyModalActionButtonVisual then
            FormWidgets.ApplyModalActionButtonVisual(context.widgets.deleteButton, "danger")
        end
    end
    LayoutFooterActions()
    if context.window and context.window.DoLayout then
        context.window:DoLayout()
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
        context.dialog:SetStatus(string.format(
            T("LAYOUT_MANAGER_STATUS_COUNTS", "%d custom layouts, %d built-in layouts"),
            #state.userLayouts,
            #state.builtinLayouts
        ), nil, context.widgets.status)
    end

    if scroll.FixScroll then
        scroll:FixScroll()
    end

    RefreshActions()
end

local function Close()
    CloseTransferDialog()
    CloseRenameDialog()
    CloseCopyDialog()
    CloseDeleteDialog()
    if context and context.window and context.window.Hide then
        context.selectedLayoutId = nil
        context.window:Hide()
    end
end

local function CreateWindow()
    local dialog = FormWidgets.CreateCompactFormDialog({
        title = T("LAYOUT_MANAGER_TITLE", "Manage Layouts"),
        description = T("LAYOUT_MANAGER_DESCRIPTION", "View available layouts. Activate them from the Canvas Toolbar."),
        width = WINDOW_WIDTH,
        height = WINDOW_HEIGHT,
        bodyLayout = "List",
        useCanonicalWindowShell = true,
        contentSurface = "parchment",
        addBodySpacer = false,
        contentRoot = true,
    })

    local body = dialog.body
    body:ReleaseChildren()
    body:SetLayout("List")

    local description = AceGUI:Create("Label")
    description:SetText(T("LAYOUT_MANAGER_DESCRIPTION", "View available layouts. Activate them from the Canvas Toolbar."))
    description:SetFullWidth(true)
    description:SetHeight(WINDOW_DESCRIPTION_HEIGHT)
    if FormWidgets.ApplyTextStyle and description.label then
        FormWidgets.ApplyTextStyle(description.label, "parchmentSecondary", 11, 1)
    end
    body:AddChild(description)

    local transferActions = AceGUI:Create("SimpleGroup")
    transferActions:SetLayout("Flow")
    transferActions:SetFullWidth(true)
    LockContainerHeight(transferActions, WINDOW_TRANSFER_ACTIONS_HEIGHT)
    body:AddChild(transferActions)
    local importButton = AceGUI:Create("Button")
    importButton:SetText(T("LAYOUT_TRANSFER_IMPORT"))
    importButton:SetWidth(120)
    importButton:SetCallback("OnClick", function() OpenTransferDialog(false) end)
    transferActions:AddChild(importButton)
    local exportButton = AceGUI:Create("Button")
    exportButton:SetText(T("LAYOUT_TRANSFER_EXPORT"))
    exportButton:SetWidth(120)
    exportButton:SetCallback("OnClick", function() OpenTransferDialog(true) end)
    transferActions:AddChild(exportButton)
    if FormWidgets.ApplyModalActionButtonVisual then
        FormWidgets.ApplyModalActionButtonVisual(importButton, "utility")
        FormWidgets.ApplyModalActionButtonVisual(exportButton, "utility")
    end

    local scroll = AceGUI:Create("ScrollFrame")
    scroll:SetLayout("Flow")
    scroll:SetFullWidth(true)
    scroll:SetFullHeight(false)
    scroll:SetHeight(WINDOW_LIST_HEIGHT)
    body:AddChild(scroll)

    local status = AceGUI:Create("Label")
    status:SetText(" ")
    status:SetFullWidth(true)
    status:SetHeight(WINDOW_STATUS_HEIGHT)
    if FormWidgets.ApplyTextStyle and status.label then
        FormWidgets.ApplyTextStyle(status.label, "parchmentMuted", 10, 1)
    end
    body:AddChild(status)

    local actionContainer = AceGUI:Create("SimpleGroup")
    actionContainer:SetLayout("Flow")
    actionContainer:SetFullWidth(true)
    LockContainerHeight(actionContainer, WINDOW_FOOTER_HEIGHT)
    body:AddChild(actionContainer)

    local renameButton = AceGUI:Create("Button")
    renameButton:SetText(T("LAYOUT_MANAGER_RENAME", "Rename"))
    renameButton:SetWidth(105)
    renameButton:SetFullWidth(false)
    if FormWidgets.ApplyModalActionButtonVisual then
        FormWidgets.ApplyModalActionButtonVisual(renameButton, "utility")
    end
    local copyButton = AceGUI:Create("Button")
    copyButton:SetText(T("LAYOUT_MANAGER_DUPLICATE", "Duplicate"))
    copyButton:SetWidth(105)
    copyButton:SetFullWidth(false)
    if FormWidgets.ApplyModalActionButtonVisual then
        FormWidgets.ApplyModalActionButtonVisual(copyButton, "utility")
    end
    local deleteButton = AceGUI:Create("Button")
    deleteButton:SetText(T("LAYOUT_MANAGER_DELETE", "Delete"))
    deleteButton:SetWidth(105)
    deleteButton:SetFullWidth(false)
    if FormWidgets.ApplyModalActionButtonVisual then
        FormWidgets.ApplyModalActionButtonVisual(deleteButton, "danger")
    end
    renameButton.frame:SetParent(actionContainer.frame)
    copyButton.frame:SetParent(actionContainer.frame)
    deleteButton.frame:SetParent(actionContainer.frame)

    context.dialog = dialog
    context.window = dialog.window
    context.widgets = {
        scroll = scroll,
        actionContainer = actionContainer,
        status = status,
        importButton = importButton,
        exportButton = exportButton,
        renameButton = renameButton,
        copyButton = copyButton,
        deleteButton = deleteButton,
    }

    renameButton:SetCallback("OnClick", OpenRenameDialog)
    copyButton:SetCallback("OnClick", OpenCopyDialog)
    deleteButton:SetCallback("OnClick", OpenDeleteDialog)
    dialog.window:SetCallback("OnClose", function()
        CloseTransferDialog()
        CloseRenameDialog()
        CloseCopyDialog()
        CloseDeleteDialog()
        context.selectedLayoutId = nil
        if GameTooltip and GameTooltip.Hide then
            GameTooltip:Hide()
        end
    end)

    if FormWidgets.CenterWindow then
        FormWidgets.CenterWindow(dialog.window)
    end
    FocusWindow(dialog.window)
    RefreshList()
    return dialog.window
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
