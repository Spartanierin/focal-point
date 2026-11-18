local _, ns = ...

ns.GUI = ns.GUI or {}
ns.GUI.Editor = ns.GUI.Editor or {}
ns.GUI.Editor.MediaLibrary = ns.GUI.Editor.MediaLibrary or {}

local AceGUI = LibStub("AceGUI-3.0")
local FormWidgets = ns.GUI.Helpers and ns.GUI.Helpers.FormWidgets or {}
local FormSectionSurfaceRenderer = ns.GUI.Helpers and ns.GUI.Helpers.FormSectionSurfaceRenderer or {}
local TextStyles = ns.GUI.Helpers and ns.GUI.Helpers.TextStyles or {}
local L = ns.L or {}

local MediaLibraryView = {}
ns.GUI.Editor.MediaLibrary.MediaLibraryView = MediaLibraryView

local STATUSBAR = "statusbar"
local FONT = "font"
local DECORATION = "decoration"
local ROW_WIDGET_TYPE = "FocalPointMediaLibraryRow"
local ROW_WIDGET_VERSION = 1
local ROW_HEIGHT_COMPACT = 28
local ROW_HEIGHT_BADGED = 38

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

local function LockContainerHeight(container, height)
    if not container then
        return
    end

    if container.SetAutoAdjustHeight then
        container:SetAutoAdjustHeight(false)
    end
    container:SetHeight(height)
end

local CenterWindow = FormWidgets.CenterWindow

local function FocusWindow(window)
    FormWidgets.FocusWindow(window, { centerIfHidden = true })
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

local function Shorten(value, limit)
    value = tostring(value or "")
    limit = tonumber(limit) or 72
    if #value <= limit then
        return value
    end

    return value:sub(1, math.max(1, limit - 3)) .. "..."
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

local function ApplyFontStringStyle(fontString, role, size, color)
    if TextStyles.ApplyFontString then
        TextStyles.ApplyFontString(fontString, role or "label", {
            size = size,
            alpha = color and color[4] or 1,
        })
    elseif fontString and fontString.SetFont then
        fontString:SetFont(STANDARD_TEXT_FONT, size or 11, "")
    end
    SetFontColor(fontString, color)
end

local function BuildItemBadges(item)
    local badges = {}
    if item and item.current == true then
        badges[#badges + 1] = T("MEDIA_LIBRARY_MARKER_CURRENT", "Current")
    end
    if item and item.missing == true then
        badges[#badges + 1] = T("MEDIA_LIBRARY_MARKER_MISSING", "Missing")
    elseif item and item.legacy == true then
        badges[#badges + 1] = T("MEDIA_LIBRARY_MARKER_LEGACY", "Legacy")
    elseif item and item.available ~= true then
        badges[#badges + 1] = T("MEDIA_LIBRARY_STATUS_UNAVAILABLE", "Unavailable")
    end

    if #badges == 0 then
        return ""
    end
    return "[" .. table.concat(badges, "]  [") .. "]"
end

local function GetItemRowHeight(item)
    return BuildItemBadges(item) ~= "" and ROW_HEIGHT_BADGED or ROW_HEIGHT_COMPACT
end

local function GetListSelectionRowColors()
    local skins = ns.GUI and ns.GUI.Skins or nil
    local palette = skins and skins.GetFormPalette and skins.GetFormPalette() or {}
    return palette.ListSelectionRow or {}
end

local ROW_COLORS = {
    fillMissing = { 0.105, 0.074, 0.070, 0.84 },
    nameDisabled = { 0.54, 0.57, 0.61, 0.95 },
    source = { 0.64, 0.67, 0.72, 1.00 },
    sourceSelected = { 0.82, 0.78, 0.64, 1.00 },
    current = { 0.96, 0.82, 0.38, 1.00 },
    badge = { 0.75, 0.73, 0.66, 0.95 },
    warning = { 0.88, 0.58, 0.52, 0.98 },
}

local function ApplyRowBackdrop(frame, selected, hovered, missing)
    if not (frame and frame.SetBackdropColor and frame.SetBackdropBorderColor) then
        return
    end

    local colors = GetListSelectionRowColors()
    local fill = selected and colors.fillSelected or (hovered and colors.fillHover or (missing and ROW_COLORS.fillMissing or colors.fill))
    local border = selected and colors.borderSelected or (hovered and colors.borderHover or colors.border)
    frame:SetBackdropColor(unpack(fill))
    frame:SetBackdropBorderColor(unpack(border))
end

local function UpdateRowVisual(widget)
    local item = widget and widget.item or nil
    local selected = widget and widget.selected == true
    local hovered = widget and widget.hovered == true
    local disabled = widget and widget.disabled == true
    local missing = item and item.missing == true
    local colors = GetListSelectionRowColors()
    local badges = BuildItemBadges(item)
    local hasBadges = badges ~= ""
    local height = GetItemRowHeight(item)

    ApplyRowBackdrop(widget.frame, selected, hovered, missing)

    local label = item and item.label or ""
    widget.nameText:SetText(Shorten(label, 58))
    widget.sourceText:SetText(item and GetSourceLabel(item.source) or "")
    widget.badgeText:SetText(badges)

    SetTextureColor(widget.marker, selected and colors.marker or colors.markerMuted)
    widget.marker:SetWidth(selected and 6 or (item and item.current == true and 4 or 2))
    widget.marker:SetAlpha((selected or item and item.current == true or hovered) and 1 or 0.55)

    SetFontColor(widget.nameText, disabled and ROW_COLORS.nameDisabled or (selected and colors.nameSelected or colors.name))
    SetFontColor(widget.sourceText, item and item.current == true and ROW_COLORS.current or (selected and ROW_COLORS.sourceSelected or ROW_COLORS.source))
    SetFontColor(widget.badgeText, item and item.current == true and ROW_COLORS.current or (missing and ROW_COLORS.warning or ROW_COLORS.badge))

    if widget.frame and widget.frame.SetHeight then
        widget.frame:SetHeight(height)
    end
    if widget.SetHeight then
        widget:SetHeight(height)
    end
    if hasBadges then
        widget.badgeText:Show()
    else
        widget.badgeText:Hide()
    end
end

local function RegisterMediaLibraryRowWidget()
    if AceGUI:GetWidgetVersion(ROW_WIDGET_TYPE) and AceGUI:GetWidgetVersion(ROW_WIDGET_TYPE) >= ROW_WIDGET_VERSION then
        return
    end

    local methods = {}

    function methods:OnAcquire()
        self:SetFullWidth(true)
        self:SetHeight(ROW_HEIGHT_COMPACT)
        self.item = nil
        self.selected = false
        self.hovered = false
        self.disabled = false
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
        self.disabled = false
        if self.nameText then
            self.nameText:SetText("")
        end
        if self.sourceText then
            self.sourceText:SetText("")
        end
        if self.badgeText then
            self.badgeText:SetText("")
        end
    end

    function methods:SetItem(item, selectedItem)
        self.item = item
        self.selected = item ~= nil and item == selectedItem
        self.disabled = item and item.selectable == false or false
        UpdateRowVisual(self)
    end

    function methods:SetDisabled(disabled)
        self.disabled = disabled == true
        UpdateRowVisual(self)
    end

    local function Constructor()
        local frame = CreateFrame("Button", nil, UIParent, "BackdropTemplate")
        frame:Hide()
        frame:SetHeight(ROW_HEIGHT_COMPACT)
        frame:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Buttons\\WHITE8X8",
            edgeSize = 1,
        })
        local colors = GetListSelectionRowColors()
        frame:SetBackdropColor(unpack(colors.fill))
        frame:SetBackdropBorderColor(unpack(colors.border))

        local marker = frame:CreateTexture(nil, "ARTWORK")
        marker:SetPoint("TOPLEFT", frame, "TOPLEFT", 1, -1)
        marker:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 1, 1)
        marker:SetWidth(2)
        marker:SetColorTexture(unpack(colors.markerMuted))

        local sourceText = frame:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
        sourceText:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -12, -6)
        sourceText:SetWidth(128)
        sourceText:SetJustifyH("RIGHT")
        sourceText:SetWordWrap(false)
        if sourceText.SetMaxLines then
            sourceText:SetMaxLines(1)
        end
        ApplyFontStringStyle(sourceText, "help", 10, ROW_COLORS.source)

        local nameText = frame:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
        nameText:SetPoint("TOPLEFT", frame, "TOPLEFT", 16, -5)
        nameText:SetPoint("TOPRIGHT", sourceText, "TOPLEFT", -10, 0)
        nameText:SetJustifyH("LEFT")
        nameText:SetWordWrap(false)
        if nameText.SetMaxLines then
            nameText:SetMaxLines(1)
        end
        ApplyFontStringStyle(nameText, "label", 11, colors.name)

        local badgeText = frame:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
        badgeText:SetPoint("TOPLEFT", frame, "TOPLEFT", 16, -20)
        badgeText:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -12, -20)
        badgeText:SetJustifyH("LEFT")
        badgeText:SetWordWrap(false)
        if badgeText.SetMaxLines then
            badgeText:SetMaxLines(1)
        end
        ApplyFontStringStyle(badgeText, "help", 9, ROW_COLORS.badge)

        local widget = {
            frame = frame,
            type = ROW_WIDGET_TYPE,
            marker = marker,
            nameText = nameText,
            sourceText = sourceText,
            badgeText = badgeText,
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
            if obj and not obj.disabled then
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

RegisterMediaLibraryRowWidget()

local function ApplyCentralSectionChrome(widget)
    local renderer = ns.GUI.Helpers.FormSectionSurfaceRenderer
    renderer.ApplySectionSurface(widget, nil)
    renderer.ApplySectionBorder(widget, false)
    local box = widget.frame._fpMediaGroupBox
    if box then box:Hide() end
    do
        -- Blizzard_EditMode/Shared/EditModeManager.xml: BorderArt, OptionsFrame kit.
        local layout = NineSliceUtil and NineSliceUtil.GetLayout and NineSliceUtil.GetLayout("UniqueCornersLayout")
        local atlasInfo = C_Texture and C_Texture.GetAtlasInfo or GetAtlasInfo
        local available = layout and NineSliceUtil.ApplyLayoutByName and type(atlasInfo) == "function"
        -- Center is optional: Blizzard SetupPieceVisuals skips SetAtlas when it is absent.
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
        -- Missing border art means no decoration, never a substitute rectangle.
        if available then
            if not box then
                -- A sibling keeps native corner art outside the clipped scroll/preview.
                box = CreateFrame("Frame", nil, widget.frame:GetParent())
                widget.frame._fpMediaGroupBox = box
                box:EnableMouse(false)
            end
            box:SetParent(widget.frame:GetParent())
            box:ClearAllPoints()
            -- Native BorderArt margins surround the full section, including its last row.
            box:SetPoint("TOPLEFT", widget.frame, "TOPLEFT", -16, 15)
            box:SetPoint("BOTTOMRIGHT", widget.frame, "BOTTOMRIGHT", 16, -15)
            box:SetFrameLevel(widget.frame:GetFrameLevel())
            box:SetAlpha(1)
            NineSliceUtil.ApplyLayoutByName(box, "UniqueCornersLayout", "OptionsFrame")
            box:Show()
        end
    end
    widget:SetCallback("OnRelease", function(released)
        renderer.ApplySectionSurface(released, nil)
        renderer.ApplySectionBorder(released, false)
        if released._fpSectionPadding then renderer.ApplySectionPadding(released, nil) end
        if released.frame._fpMediaGroupBox then released.frame._fpMediaGroupBox:Hide() end
    end)
end

local function FindCurrentRowIndex(rows)
    if type(rows) ~= "table" then
        return nil
    end

    for index, row in ipairs(rows) do
        if row and row.item and row.item.current == true then
            return index
        end
    end

    return nil
end

local function CalculateRowOffset(rows, targetIndex)
    local offset = 0
    for index, row in ipairs(rows or {}) do
        if index >= targetIndex then
            break
        end
        offset = offset + GetItemRowHeight(row and row.item or nil)
    end
    return offset
end

local function ScrollRowIntoView(scroll, rows, targetIndex)
    if not (scroll and rows and targetIndex) then
        return
    end

    if scroll.DoLayout then
        scroll:DoLayout()
    end
    if scroll.FixScroll then
        scroll:FixScroll()
    end

    local scrollFrame = scroll.scrollframe
    local content = scroll.content
    if not (scrollFrame and content and scroll.SetScroll) then
        return
    end

    local viewHeight = scrollFrame:GetHeight() or 0
    local contentHeight = content:GetHeight() or 0
    if viewHeight <= 0 or contentHeight <= viewHeight then
        scroll:SetScroll(0)
        return
    end

    local rowTop = CalculateRowOffset(rows, targetIndex)
    local rowHeight = GetItemRowHeight(rows[targetIndex] and rows[targetIndex].item or nil)
    local rowBottom = rowTop + rowHeight
    local status = scroll.status or scroll.localstatus or {}
    local currentOffset = status.offset or 0

    if rowTop >= currentOffset and rowBottom <= currentOffset + viewHeight then
        return
    end

    local maxOffset = math.max(0, contentHeight - viewHeight)
    local targetOffset = math.max(0, math.min(rowTop - 6, maxOffset))
    local scrollValue = maxOffset > 0 and math.max(0, math.min(1000, (targetOffset / maxOffset) * 1000)) or 0

    if scroll.scrollbar and scroll.scrollbar.SetValue then
        scroll.scrollbar:SetValue(scrollValue)
    else
        scroll:SetScroll(scrollValue)
    end
end

local function RequestScrollCurrentIntoView(context)
    local widgets = context and context.widgets or {}
    local rows = widgets.itemRows
    local scroll = widgets.itemScroll
    local targetIndex = FindCurrentRowIndex(rows)
    if not targetIndex then
        return
    end

    context.mediaLibraryScrollToken = (context.mediaLibraryScrollToken or 0) + 1
    local token = context.mediaLibraryScrollToken
    local function apply()
        if not context or context.mediaLibraryScrollToken ~= token then
            return
        end
        ScrollRowIntoView(scroll, rows, targetIndex)
    end

    if C_Timer and C_Timer.After then
        C_Timer.After(0, apply)
    else
        apply()
    end
end

local function RefreshItemSelectionMarkers(context)
    local widgets = context and context.widgets or {}
    local rows = widgets.itemRows
    if type(rows) ~= "table" then
        return false
    end

    for _, row in ipairs(rows) do
        if row and row.widget and row.widget.SetItem then
            row.widget:SetItem(row.item, context.state and context.state.selectedItem or nil)
        end
    end

    return true
end

local function SetMetaLabel(label, title, value)
    if not label then
        return
    end

    local text = string.format("%s: %s", title, tostring(value or ""))
    label:SetText(text)
    FormWidgets.SetInspectorButtonTooltip(label, text)
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
    -- currentValue/currentItem remain the saved-value context. Derive result
    -- membership from the existing browser selection; do not store a second one.
    local inResults = false
    for _, result in ipairs(context.state.items or {}) do
        if item and result.value == item.value then inResults = true; break end
    end
    local canApply = item and item.selectable ~= false
    local selectionHelp
    if not item then
        selectionHelp = T("MEDIA_LIBRARY_SELECTION_PROMPT", "Select a result to apply.")
    elseif not canApply then
        selectionHelp = inResults
            and T("MEDIA_LIBRARY_SELECTION_UNAVAILABLE", "This selection cannot be applied.")
            or T("MEDIA_LIBRARY_SELECTION_RETAINED_UNAVAILABLE", "Selection outside the results; Apply is unavailable.")
    elseif not inResults then
        selectionHelp = T("MEDIA_LIBRARY_SELECTION_RETAINED", "Selection outside the results; Apply uses the selection shown here.")
    else
        selectionHelp = T("MEDIA_LIBRARY_SELECTION_VISIBLE", "Apply uses the selected result.")
    end
    SetMetaLabel(widgets.selectedLabel, T("MEDIA_LIBRARY_SELECTED", "Selected"),
        item and (item.name or item.label) or T("MEDIA_LIBRARY_STATUS_NONE", "No media selected"))
    widgets.selectionHelp:SetText(selectionHelp)
    FormWidgets.SetInspectorButtonTooltip(widgets.selectionHelp, selectionHelp)
    -- The ordinary Apply hint repeats the button; retained/unavailable/empty warnings do not.
    widgets.selectionHelp.frame:SetShown(not (item and canApply and inResults))

    local source = item and GetSourceLabel(item.source) or "-"
    if item and item.provider and item.provider ~= "" then
        source = source .. " / " .. T("MEDIA_LIBRARY_PROVIDER", "Provider") .. ": " .. item.provider
    end
    SetMetaLabel(widgets.sourceLabel, T("MEDIA_LIBRARY_SOURCE", "Source"), source)
    local status = { BuildStatusText(item) }
    if item then
        if item.legacy and item.missing then status[#status + 1] = T("MEDIA_LIBRARY_STATUS_LEGACY", "Legacy") end
        if item.legacy and item.available and not item.missing then status[#status + 1] = T("MEDIA_LIBRARY_STATUS_AVAILABLE", "Available") end
        if item.current then status[#status + 1] = T("MEDIA_LIBRARY_CURRENT", "Current") end
        if item.missing or item.available ~= true or not item.resolvedAsset then
            status[#status + 1] = T("MEDIA_LIBRARY_FALLBACK_PREVIEW", "Fallback preview")
        end
    end
    SetMetaLabel(widgets.statusLabel, T("MEDIA_LIBRARY_STATUS", "Status"), table.concat(status, " / "))
    SetMetaLabel(widgets.valueLabel, T("MEDIA_LIBRARY_VALUE", "Value"), item and item.value or "-")
    SetMetaLabel(widgets.resolvedAssetLabel, T("MEDIA_LIBRARY_RESOLVED_ASSET", "Resolved Asset"), item and item.resolvedAsset or "-")

    -- Technical references remain complete, but do not compete with identity/source/status.
    FormWidgets.SetInspectorButtonTooltip(widgets.selectedLabel, table.concat({
        widgets.selectedLabel.label:GetText(), widgets.valueLabel.label:GetText(),
        widgets.resolvedAssetLabel.label:GetText(),
    }, "\n"))

    if widgets.metadata and widgets.metadata.DoLayout then
        widgets.metadata:DoLayout()
    end

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
        local row = AceGUI:Create(ROW_WIDGET_TYPE)
        row:SetItem(item, context.state.selectedItem)
        row:SetDisabled(item.selectable == false)
        row:SetCallback("OnClick", function()
            if item.selectable == false then
                return
            end
            context.callbacks.onSelect(item)
        end)
        scroll:AddChild(row)
        widgets.itemRows[#widgets.itemRows + 1] = {
            item = item,
            widget = row,
        }
    end

    RefreshMetadata(context)
    RequestScrollCurrentIntoView(context)
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

    if widgets.listTitle then
        local keys = { font = "MEDIA_LIBRARY_TYPE_FONT", statusbar = "MEDIA_LIBRARY_TYPE_STATUSBAR", decoration = "MEDIA_LIBRARY_TYPE_DECORATION" }
        widgets.listTitle:SetText(T(keys[context.state.mediaType] or "MEDIA_LIBRARY_TITLE", "Media Library"))
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

    if FormWidgets.ApplyModernWindowChrome then
        FormWidgets.ApplyModernWindowChrome(window, {
            windowChrome = "editmode",
            titleFontSize = 16,
            titleOffsetY = -7,
            headerDrag = { left = 8, right = 36, top = 0, height = 32 },
        })
    end
    if FormWidgets.EnsureStandardWindowCloseButton then
        FormWidgets.EnsureStandardWindowCloseButton(window)
    end
    EnableEscapeClose(window)

    local function Group(parent, height, layout)
        local group = AceGUI:Create("SimpleGroup")
        group:SetLayout(layout == "Table" and "List" or (layout or "List"))
        group:SetFullWidth(true)
        LockContainerHeight(group, height)
        parent:AddChild(group)
        return group
    end
    local function Gap(parent, height)
        -- SimpleGroup has a stable height, unlike dynamically measured empty Labels.
        return Group(parent, height)
    end
    local function Heading(label)
        local color = NORMAL_FONT_COLOR or ns.GUI.Helpers.TextStyles.Get("sectionHeader")
        ApplyLabelText(label, "sectionHeader", { size = 14 })
        label.label:SetTextColor(color.r, color.g, color.b, 1)
    end
    local root = AceGUI:Create("SimpleGroup")
    root:SetLayout("List")
    root:SetFullWidth(true)
    root:SetFullHeight(true)
    window:AddChild(root)
    FormSectionSurfaceRenderer.ApplySectionPadding(root, { left = 16, right = 16, top = 0, bottom = 0 })
    root:SetCallback("OnRelease", function(widget) FormSectionSurfaceRenderer.ApplySectionPadding(widget, nil) end)

    -- List budget: 14 + 40 + 12 + 272 + 32 + 192 + 16 + 25 = 603.
    -- Native Source ends at row y=40. Its 12-unit gap to the next section replaces
    -- the old 4-unit row reserve; the unchanged border host extends 15 upward.
    -- Thus the filter-to-border contour gains 8 units regardless of atlas artwork.
    local titleRow = Group(root, 14)
    local title = CreateLabel(context.state.subtitle or "", "help", 11)
    titleRow:AddChild(title)

    local filterRow = Group(root, 40, "Table")
    filterRow:SetUserData("table", { columns = { { weight = 2 }, { weight = 1 } }, spaceH = 14 })
    filterRow:SetLayout("Table")
    local function StyleFilterLabel(widget)
        local font, size, flags = widget.label:GetFont()
        local color = { widget.label:GetTextColor() }
        local height = widget.label:GetHeight()
        local yellow = NORMAL_FONT_COLOR or TextStyles.Get("sectionHeader")
        widget.label:SetFont(font, 13, flags)
        widget.label:SetTextColor(yellow.r, yellow.g, yellow.b, 1)
        widget.label:SetHeight(14)
        return function()
            widget.label:SetFont(font, size, flags)
            widget.label:SetTextColor(unpack(color))
            widget.label:SetHeight(height)
        end
    end
    local searchBox = AceGUI:Create("EditBox")
    searchBox:SetLabel(T("MEDIA_LIBRARY_SEARCH", "Search"))
    searchBox:DisableButton(true)
    searchBox:SetFullWidth(true)
    FormWidgets.StyleEditBox(searchBox, "editor_inset")
    local inputFill = searchBox.frame._fpMediaSearchFill or searchBox.editbox:CreateTexture(nil, "BACKGROUND")
    searchBox.frame._fpMediaSearchFill = inputFill
    inputFill:SetAllPoints(searchBox.editbox)
    local fieldStyle = FormWidgets.ResolveFieldStyle("editor_inset")
    inputFill:SetColorTexture(unpack(fieldStyle.background))
    inputFill:Show()
    local restoreSearchLabel = StyleFilterLabel(searchBox)
    local inputFont, inputSize, inputFlags = searchBox.editbox:GetFont()
    searchBox.editbox:SetFont(inputFont, 14, inputFlags)
    -- Existing top/bottom anchors leave 22 input units; 3+3 text insets leave 16.
    searchBox:SetHeight(40)
    searchBox:SetCallback("OnRelease", function()
        inputFill:Hide()
        restoreSearchLabel()
        searchBox.editbox:SetFont(inputFont, inputSize, inputFlags)
    end)
    filterRow:AddChild(searchBox)

    local sourceDropdown = AceGUI:Create("Dropdown")
    local sourceValues, sourceOrder = BuildSourceDropdown()
    sourceDropdown:SetLabel(T("MEDIA_LIBRARY_SOURCE", "Source"))
    sourceDropdown:SetList(sourceValues, sourceOrder)
    sourceDropdown:SetValue("all")
    sourceDropdown:SetFullWidth(true)
    FormWidgets.StyleDropdown(sourceDropdown, "editor_inset")
    FormWidgets.BindNativeDropdown(sourceDropdown, { order = sourceOrder })
    local restoreSourceLabel = StyleFilterLabel(sourceDropdown)
    sourceDropdown:SetCallback("OnRelease", restoreSourceLabel)
    filterRow:AddChild(sourceDropdown)
    Gap(root, 12)

    local listGroup = Group(root, 272)
    FormSectionSurfaceRenderer.ApplySectionPadding(listGroup, { left = 12, right = 12, top = 12, bottom = 14 })
    ApplyCentralSectionChrome(listGroup)
    local listTitle = CreateLabel("", "sectionHeader", 14)
    Heading(listTitle)
    local headingRow = Group(listGroup, 20)
    headingRow:AddChild(listTitle)
    local itemScroll = AceGUI:Create("ScrollFrame")
    itemScroll:SetLayout("Flow")
    itemScroll:SetFullWidth(true)
    itemScroll:SetHeight(226)
    listGroup:AddChild(itemScroll)

    Gap(root, 32) -- Expanded native hosts extend 15 above/below; 2 units remain between them.
    local previewGroup = Group(root, 192)
    FormSectionSurfaceRenderer.ApplySectionPadding(previewGroup, { left = 12, right = 12, top = 12, bottom = 14 })
    ApplyCentralSectionChrome(previewGroup)
    local Preview = ns.GUI.Editor.MediaLibrary.MediaLibraryPreview
    local preview = Preview and Preview.Create and Preview.Create(previewGroup) or nil
    if preview and preview.title then
        local font, size, flags = preview.title:GetFont()
        local color = { preview.title:GetTextColor() }
        local headingColor = NORMAL_FONT_COLOR or TextStyles.Get("sectionHeader")
        preview.title:SetFont(font, 14, flags)
        preview.title:SetTextColor(headingColor.r, headingColor.g, headingColor.b, 1)
        preview:SetCallback("OnRelease", function(widget)
            widget.title:SetFont(font, size, flags)
            widget.title:SetTextColor(unpack(color))
        end)
    end

    local metadata = Group(previewGroup, 54, "Table")
    metadata:SetUserData("table", { columns = { { weight = 1 }, { weight = 1 } }, spaceH = 12, spaceV = 3 })
    metadata:SetLayout("Table")
    local labels = {
        selectedLabel = CreateLabel("", "highlight", 13),
        selectionHelp = CreateLabel("", "help", 10),
        sourceLabel = CreateLabel("", "label", 12),
        statusLabel = CreateLabel("", "label", 12),
        valueLabel = CreateLabel("", "help", 10),
        resolvedAssetLabel = CreateLabel("", "help", 10),
    }
    labels.selectedLabel.label:SetMaxLines(1) -- same bounded identity role as Texts Manager
    labels.selectedLabel:SetUserData("cell", { colspan = 2 })
    labels.selectionHelp:SetUserData("cell", { colspan = 2 })
    for _, key in ipairs({ "selectedLabel", "sourceLabel", "statusLabel", "selectionHelp", "valueLabel", "resolvedAssetLabel" }) do
        local label = labels[key]
        label.label:SetWordWrap(false)
        label.frame:EnableMouse(true)
        label:SetCallback("OnRelease", function(widget)
            widget.frame.__fpInspectorTooltip = nil
            widget.frame:EnableMouse(false)
            widget.label:SetWordWrap(true)
            widget.label:SetMaxLines(0)
        end)
        metadata:AddChild(label)
        if key == "valueLabel" or key == "resolvedAssetLabel" then label.frame:Hide() end
    end

    Gap(root, 16) -- Native preview border ends before the footer begins.
    local actions = Group(root, 25, "Table")
    actions:SetUserData("table", { columns = { { weight = 1, alignH = "left" }, { weight = 1, alignH = "right" } } })
    actions:SetLayout("Table")
    local applyButton = CreateButton(T("MEDIA_LIBRARY_APPLY", "Apply"), "primary_action", 105)
    actions:AddChild(applyButton)
    local cancelButton = CreateButton(T("MEDIA_LIBRARY_CANCEL", "Cancel"), "utility", 105)
    actions:AddChild(cancelButton)

    context.window = window
    context.widgets = {
        root = root,
        listGroup = listGroup,
        listTitle = listTitle,
        previewGroup = previewGroup,
        filterRow = filterRow,
        actions = actions,
        title = title,
        searchBox = searchBox,
        sourceDropdown = sourceDropdown,
        itemScroll = itemScroll,
        preview = preview,
        metadata = metadata,
        selectedLabel = labels.selectedLabel,
        selectionHelp = labels.selectionHelp,
        statusLabel = labels.statusLabel,
        sourceLabel = labels.sourceLabel,
        valueLabel = labels.valueLabel,
        resolvedAssetLabel = labels.resolvedAssetLabel,
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
