local _, ns = ...

ns.GUI = ns.GUI or {}
ns.GUI.Widgets = ns.GUI.Widgets or {}

local AceGUI = LibStub("AceGUI-3.0")
local SelectionRow = {}
ns.GUI.Widgets.SelectionRow = SelectionRow

local TYPE = "FocalPointSelectionRow"
local VERSION = 1
local COMPACT_HEIGHT = 22
local DETAIL_HEIGHT = 38
local LABEL_FONT_SIZE = 11
local DESCRIPTION_FONT_SIZE = 9
local DESCRIPTION_GAP = 2

local function GetColors()
    local skins = ns.GUI and ns.GUI.Skins or nil
    local palette = skins and skins.GetFormPalette and skins.GetFormPalette() or {}
    return palette.ListSelectionRow or {}
end

local function SetTextColor(fontString, color, alpha)
    if fontString and fontString.SetTextColor and type(color) == "table" then
        fontString:SetTextColor(color[1] or 1, color[2] or 1, color[3] or 1, alpha or color[4] or 1)
    end
end

local function ApplyTextStyle(fontString, role, size)
    local textStyles = ns.GUI.Helpers and ns.GUI.Helpers.TextStyles or nil
    if textStyles and textStyles.ApplyFontString then
        textStyles.ApplyFontString(fontString, role, { size = size })
    elseif fontString and fontString.SetFont then
        fontString:SetFont(STANDARD_TEXT_FONT, size, "")
    end
end

local function HasText(value)
    return type(value) == "string" and value ~= ""
end

local function UpdateLayout(widget, hasIcon, hasDescription, hasDetail, hasStatus)
    local left = hasIcon and widget.icon or widget.marker
    local right = hasDetail and widget.detail or widget.frame
    local rightPoint = hasDetail and "LEFT" or "RIGHT"
    local descriptionRight = hasStatus and widget.status or widget.frame
    local descriptionRightPoint = hasStatus and "BOTTOMLEFT" or "BOTTOMRIGHT"
    local descriptionRightInset = hasStatus and -6 or -8

    widget.label:ClearAllPoints()
    widget.description:ClearAllPoints()
    if hasDescription then
        -- The marker/icon owns horizontal leading only; the text block centers against the row.
        local textBlockHeight = LABEL_FONT_SIZE + DESCRIPTION_GAP + DESCRIPTION_FONT_SIZE
        local textBlockTopInset = (DETAIL_HEIGHT - textBlockHeight) / 2
        widget.label:SetPoint("TOP", widget.frame, "TOP", 0, -textBlockTopInset)
        widget.label:SetPoint("LEFT", left, "RIGHT", 5, 0)
        widget.label:SetPoint("RIGHT", right, rightPoint, -8, 0)
        widget.description:SetPoint("TOPLEFT", widget.label, "BOTTOMLEFT", 0, -DESCRIPTION_GAP)
        widget.description:SetPoint("TOPRIGHT", widget.label, "BOTTOMRIGHT", 0, -DESCRIPTION_GAP)
    else
        widget.label:SetPoint("LEFT", left, "RIGHT", 5, 0)
        if hasStatus then
            widget.label:SetPoint("TOP", widget.frame, "TOP", 0, -4)
        else
            widget.label:SetPoint("TOP", widget.frame, "TOP", 0, -2)
            widget.label:SetPoint("BOTTOM", widget.frame, "BOTTOM", 0, 2)
        end
        widget.label:SetPoint("RIGHT", right, rightPoint, -8, 0)
        widget.description:SetPoint("BOTTOMLEFT", left, "RIGHT", 5, 4)
        widget.description:SetPoint("BOTTOMRIGHT", descriptionRight, descriptionRightPoint, descriptionRightInset, 4)
    end

    widget.detail:ClearAllPoints()
    widget.detail:SetPoint("TOPRIGHT", widget.frame, "TOPRIGHT", -8, -4)
    widget.status:ClearAllPoints()
    widget.status:SetPoint("BOTTOMRIGHT", widget.frame, "BOTTOMRIGHT", -8, 4)
end

local function UpdateVisual(widget)
    local binding = widget.binding or {}
    local colors = GetColors()
    local selected = binding.selected == true
    local hovered = widget.hovered == true
    local disabled = binding.disabled == true
    local missing = binding.missing == true
    local hasIcon = HasText(binding.icon)
    local hasDescription = HasText(binding.description)
    local hasDetail = HasText(binding.detail)
    local hasStatus = HasText(binding.status)
    local height = (hasDescription or hasStatus) and DETAIL_HEIGHT or COMPACT_HEIGHT

    local fill = selected and colors.fillSelected or (hovered and colors.fillHover or colors.fill)
    local border = selected and colors.borderSelected or (hovered and colors.borderHover or colors.border)
    if missing and not selected and not hovered then
        fill = { 0.105, 0.074, 0.070, 0.84 }
    end
    widget.frame:SetBackdropColor(fill[1] or 0, fill[2] or 0, fill[3] or 0, fill[4] or 1)
    widget.frame:SetBackdropBorderColor(border[1] or 0, border[2] or 0, border[3] or 0, border[4] or 1)

    widget.marker:SetWidth(selected and 6 or 2)
    widget.marker:SetColorTexture(unpack(selected and colors.marker or colors.markerMuted))
    widget.marker:SetAlpha((selected or hovered) and 1 or 0.55)

    widget.label:SetText(binding.label or "")
    widget.description:SetText(binding.description or "")
    widget.detail:SetText(binding.detail or "")
    widget.status:SetText(binding.status or "")
    SetTextColor(widget.label, selected and colors.nameSelected or colors.name, disabled and 0.48 or nil)
    if widget.description.SetAlpha then widget.description:SetAlpha(disabled and 0.42 or 1) end
    SetTextColor(widget.detail, colors.name, disabled and 0.42 or 0.72)
    SetTextColor(widget.status, missing and { 0.88, 0.58, 0.52, 0.98 } or colors.name, disabled and 0.42 or 0.72)

    if hasIcon then
        widget.icon:SetTexture(binding.icon)
        widget.icon:Show()
    else
        widget.icon:SetTexture(nil)
        widget.icon:Hide()
    end
    widget.description:SetShown(hasDescription)
    widget.detail:SetShown(hasDetail)
    widget.status:SetShown(hasStatus)
    UpdateLayout(widget, hasIcon, hasDescription, hasDetail, hasStatus)
    widget:SetHeight(height)
    widget.frame:SetHeight(height)
end

local function ResetBinding(widget)
    widget.binding = nil
    widget.key = nil
    widget.onSelect = nil
    widget.hovered = false
    widget.frame:EnableMouse(false)
    widget.label:SetText("")
    widget.description:SetText("")
    widget.detail:SetText("")
    widget.status:SetText("")
    widget.icon:SetTexture(nil)
    widget.icon:Hide()
    widget.description:Hide()
    widget.detail:Hide()
    widget.status:Hide()
    widget.marker:Hide()
end

local function RegisterWidget()
    if AceGUI:GetWidgetVersion(TYPE) and AceGUI:GetWidgetVersion(TYPE) >= VERSION then
        return
    end

    local methods = {}

    function methods:OnAcquire()
        self:SetFullWidth(true)
        self:SetHeight(COMPACT_HEIGHT)
        ResetBinding(self)
        self.frame:Show()
    end

    function methods:OnRelease()
        ResetBinding(self)
    end

    function methods:Bind(binding)
        binding = type(binding) == "table" and binding or {}
        self.binding = binding
        self.key = binding.key
        self.onSelect = type(binding.onSelect) == "function" and binding.onSelect or nil
        self.hovered = false
        self.frame:EnableMouse(binding.disabled ~= true)
        self.marker:Show()
        UpdateVisual(self)
    end

    local function Constructor()
        local frame = CreateFrame("Button", nil, UIParent, "BackdropTemplate")
        frame:Hide()
        frame:SetHeight(COMPACT_HEIGHT)
        frame:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Buttons\\WHITE8X8",
            edgeSize = 1,
        })

        local marker = frame:CreateTexture(nil, "ARTWORK")
        marker:SetPoint("TOPLEFT", frame, "TOPLEFT", 1, -1)
        marker:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 1, 1)
        marker:SetWidth(2)
        local icon = frame:CreateTexture(nil, "ARTWORK", nil, 1)
        icon:SetSize(14, 14)
        icon:SetPoint("LEFT", marker, "RIGHT", 5, 0)
        local label = frame:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
        label:SetJustifyH("LEFT")
        label:SetWordWrap(false)
        label:SetMaxLines(1)
        ApplyTextStyle(label, "label", LABEL_FONT_SIZE)
        local description = frame:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
        description:SetJustifyH("LEFT")
        description:SetWordWrap(false)
        description:SetMaxLines(1)
        ApplyTextStyle(description, "sectionHeader", DESCRIPTION_FONT_SIZE)
        local detail = frame:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
        detail:SetJustifyH("RIGHT")
        detail:SetWordWrap(false)
        detail:SetMaxLines(1)
        ApplyTextStyle(detail, "help", 10)
        local status = frame:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
        status:SetJustifyH("RIGHT")
        status:SetWordWrap(false)
        status:SetMaxLines(1)
        ApplyTextStyle(status, "help", 9)

        local widget = {
            type = TYPE,
            frame = frame,
            marker = marker,
            icon = icon,
            label = label,
            description = description,
            detail = detail,
            status = status,
        }
        frame.obj = widget
        frame:SetScript("OnEnter", function(self)
            local obj = self.obj
            if obj and obj.binding and obj.binding.disabled ~= true then
                obj.hovered = true
                UpdateVisual(obj)
            end
        end)
        frame:SetScript("OnLeave", function(self)
            local obj = self.obj
            if obj then
                obj.hovered = false
                UpdateVisual(obj)
            end
        end)
        frame:SetScript("OnMouseDown", function(self, button)
            local obj = self.obj
            if button == "LeftButton" and obj and obj.binding and obj.binding.disabled ~= true and obj.onSelect then
                obj.onSelect(obj.key)
            end
            AceGUI:ClearFocus()
        end)

        for method, func in pairs(methods) do
            widget[method] = func
        end
        return AceGUI:RegisterAsWidget(widget)
    end

    AceGUI:RegisterWidgetType(TYPE, Constructor, VERSION)
end

RegisterWidget()

function SelectionRow.Create(binding)
    local row = AceGUI:Create(TYPE)
    row:Bind(binding)
    return row
end

return SelectionRow