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
local ROW_WIDGET_TYPE = "FocalPointMediaLibraryRow"
local ROW_WIDGET_VERSION = 1
local ROW_HEIGHT_COMPACT = 28
local ROW_HEIGHT_BADGED = 38
local CHROME_PREFIX = "_fpMediaBrowser"

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

local ROW_COLORS = {
    fill = { 0.075, 0.085, 0.105, 0.78 },
    fillHover = { 0.105, 0.118, 0.142, 0.92 },
    fillSelected = { 0.210, 0.170, 0.082, 0.98 },
    fillMissing = { 0.105, 0.074, 0.070, 0.84 },
    border = { 0.22, 0.24, 0.28, 0.46 },
    borderHover = { 0.36, 0.39, 0.44, 0.72 },
    borderSelected = { 0.95, 0.76, 0.28, 0.98 },
    marker = { 1.00, 0.80, 0.24, 1.00 },
    markerMuted = { 0.58, 0.62, 0.68, 0.34 },
    name = { 0.93, 0.91, 0.84, 1.00 },
    nameSelected = { 1.00, 0.98, 0.88, 1.00 },
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

    local fill = selected and ROW_COLORS.fillSelected or (hovered and ROW_COLORS.fillHover or (missing and ROW_COLORS.fillMissing or ROW_COLORS.fill))
    local border = selected and ROW_COLORS.borderSelected or (hovered and ROW_COLORS.borderHover or ROW_COLORS.border)
    frame:SetBackdropColor(unpack(fill))
    frame:SetBackdropBorderColor(unpack(border))
end

local function UpdateRowVisual(widget)
    local item = widget and widget.item or nil
    local selected = widget and widget.selected == true
    local hovered = widget and widget.hovered == true
    local disabled = widget and widget.disabled == true
    local missing = item and item.missing == true
    local badges = BuildItemBadges(item)
    local hasBadges = badges ~= ""
    local height = GetItemRowHeight(item)

    ApplyRowBackdrop(widget.frame, selected, hovered, missing)

    local label = item and item.label or ""
    widget.nameText:SetText(Shorten(label, 58))
    widget.sourceText:SetText(item and GetSourceLabel(item.source) or "")
    widget.badgeText:SetText(badges)

    SetTextureColor(widget.marker, selected and ROW_COLORS.marker or ROW_COLORS.markerMuted)
    widget.marker:SetWidth(selected and 6 or (item and item.current == true and 4 or 2))
    widget.marker:SetAlpha((selected or item and item.current == true or hovered) and 1 or 0.55)

    SetFontColor(widget.nameText, disabled and ROW_COLORS.nameDisabled or (selected and ROW_COLORS.nameSelected or ROW_COLORS.name))
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
        frame:SetBackdropColor(unpack(ROW_COLORS.fill))
        frame:SetBackdropBorderColor(unpack(ROW_COLORS.border))

        local marker = frame:CreateTexture(nil, "ARTWORK")
        marker:SetPoint("TOPLEFT", frame, "TOPLEFT", 1, -1)
        marker:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 1, 1)
        marker:SetWidth(2)
        marker:SetColorTexture(unpack(ROW_COLORS.markerMuted))

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
        ApplyFontStringStyle(nameText, "label", 11, ROW_COLORS.name)

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

local FRAME_CHROME = {
    fill = { 0.052, 0.060, 0.076, 0.965 },
    header = { 0.095, 0.105, 0.130, 0.90 },
    border = { 0.48, 0.42, 0.28, 0.94 },
    innerBorder = { 0.18, 0.20, 0.25, 0.96 },
    topShade = { 1.00, 1.00, 1.00, 0.05 },
    bottomShade = { 0.00, 0.00, 0.00, 0.38 },
}

local SECTION_CHROME = {
    fill = { 0.060, 0.068, 0.084, 0.56 },
    border = { 0.25, 0.28, 0.33, 0.54 },
    topShade = { 1.00, 1.00, 1.00, 0.030 },
    bottomShade = { 0.00, 0.00, 0.00, 0.240 },
    footerFill = { 0.065, 0.072, 0.088, 0.66 },
    footerBorder = { 0.30, 0.32, 0.36, 0.44 },
}

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

local function ApplyMediaBrowserWindowChrome(window)
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
    ApplyMediaBrowserWindowChrome(window)
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
    LockContainerHeight(titleRow, 24)
    root:AddChild(titleRow)

    titleRow:AddChild(CreateSpacer(12))
    local title = CreateLabel(context.state.subtitle or "", "sectionHeader", 13, 650)
    titleRow:AddChild(title)

    local filterRow = AceGUI:Create("SimpleGroup")
    filterRow:SetLayout("Flow")
    filterRow:SetFullWidth(true)
    LockContainerHeight(filterRow, 52)
    root:AddChild(filterRow)

    filterRow:AddChild(CreateSpacer(38))

    local searchBox = AceGUI:Create("EditBox")
    searchBox:SetLabel(T("MEDIA_LIBRARY_SEARCH", "Search"))
    searchBox:DisableButton(true)
    searchBox:SetWidth(388)
    if FormWidgets.StyleEditBox then
        FormWidgets.StyleEditBox(searchBox, "editor_inset")
    end
    filterRow:AddChild(searchBox)

    filterRow:AddChild(CreateSpacer(14))

    local sourceDropdown = AceGUI:Create("Dropdown")
    local sourceValues, sourceOrder = BuildSourceDropdown()
    sourceDropdown:SetLabel(T("MEDIA_LIBRARY_SOURCE", "Source"))
    sourceDropdown:SetList(sourceValues, sourceOrder)
    sourceDropdown:SetValue("all")
    sourceDropdown:SetWidth(220)
    if FormWidgets.StyleDropdown then
        FormWidgets.StyleDropdown(sourceDropdown, "editor_inset")
    end
    filterRow:AddChild(sourceDropdown)

    local itemScroll = AceGUI:Create("ScrollFrame")
    itemScroll:SetLayout("Flow")
    itemScroll:SetFullWidth(true)
    itemScroll:SetHeight(270)
    root:AddChild(itemScroll)
    ApplySectionChrome(itemScroll, "List", {
        fill = { 0.044, 0.050, 0.064, 0.58 },
        border = { 0.27, 0.30, 0.36, 0.62 },
    })

    local Preview = ns.GUI
        and ns.GUI.Editor
        and ns.GUI.Editor.MediaLibrary
        and ns.GUI.Editor.MediaLibrary.MediaLibraryPreview
    local preview = Preview and Preview.Create and Preview.Create(root) or nil
    ApplySectionChrome(preview, "Preview", {
        fill = { 0.052, 0.058, 0.072, 0.48 },
        border = { 0.24, 0.27, 0.32, 0.46 },
    })

    local metadata = AceGUI:Create("SimpleGroup")
    metadata:SetLayout("Flow")
    metadata:SetFullWidth(true)
    LockContainerHeight(metadata, 104)
    root:AddChild(metadata)
    ApplySectionChrome(metadata, "Metadata", {
        fill = { 0.054, 0.061, 0.076, 0.50 },
        border = { 0.23, 0.26, 0.31, 0.44 },
    })

    metadata:AddChild(CreateSpacer(nil, 6))
    metadata:AddChild(CreateSpacer(12, 1))

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
    LockContainerHeight(actions, 38)
    root:AddChild(actions)
    ApplySectionChrome(actions, "Footer", {
        fill = SECTION_CHROME.footerFill,
        border = SECTION_CHROME.footerBorder,
        topShade = { 0.78, 0.78, 0.74, 0.050 },
        bottomShade = { 0.00, 0.00, 0.00, 0.280 },
    })

    actions:AddChild(CreateSpacer(nil, 5))
    actions:AddChild(CreateSpacer(450, 1))

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
