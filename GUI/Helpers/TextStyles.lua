local _, ns = ...

ns.GUI = ns.GUI or {}
ns.GUI.Helpers = ns.GUI.Helpers or {}

local TextStyles = {}
ns.GUI.Helpers.TextStyles = TextStyles

TextStyles.TextColors = {
    sectionHeader = {
        hex = "E7C44A",
        wow = "|cffE7C44A",
        r = 0.906,
        g = 0.769,
        b = 0.290,
    },
    label = {
        hex = "F2E6C9",
        wow = "|cffF2E6C9",
        r = 0.949,
        g = 0.902,
        b = 0.788,
    },
    help = {
        hex = "B7AA8A",
        wow = "|cffB7AA8A",
        r = 0.718,
        g = 0.667,
        b = 0.541,
    },
    highlight = {
        hex = "8FC7FF",
        wow = "|cff8FC7FF",
        r = 0.561,
        g = 0.780,
        b = 1.000,
    },
    disabled = {
        hex = "7E7564",
        wow = "|cff7E7564",
        r = 0.494,
        g = 0.459,
        b = 0.392,
    },
}

local function GetRole(role)
    return TextStyles.TextColors[role] or TextStyles.TextColors.label
end

function TextStyles.Get(role)
    return GetRole(role)
end

function TextStyles.Wrap(text, role)
    if type(text) ~= "string" or text == "" then
        return text or ""
    end

    local style = GetRole(role)
    return string.format("%s%s|r", style.wow or "|cffffffff", text)
end

function TextStyles.ApplyFontString(fontString, role, options)
    if not fontString then
        return
    end

    local style = GetRole(role)
    local opts = type(options) == "table" and options or {}

    if fontString.SetTextColor then
        fontString:SetTextColor(style.r, style.g, style.b, opts.alpha or 1)
    end

    if fontString.SetFont then
        local currentFont, currentSize, currentFlags = fontString:GetFont()
        fontString:SetFont(
            opts.font or currentFont or STANDARD_TEXT_FONT,
            opts.size or currentSize or 12,
            opts.flags or currentFlags or ""
        )
    end

    local shadowEnabled = opts.shadow
    if shadowEnabled == nil then
        shadowEnabled = true
    end

    if shadowEnabled and fontString.SetShadowOffset then
        fontString:SetShadowOffset(1, -1)
    end

    if shadowEnabled and fontString.SetShadowColor then
        fontString:SetShadowColor(0, 0, 0, 0.90)
    end
end

local function ApplyToKnownTextSlots(widget, role, options)
    if not widget then
        return
    end

    local seen = {}
    local function ApplySlot(slot)
        if not slot or seen[slot] then
            return
        end
        seen[slot] = true
        TextStyles.ApplyFontString(slot, role, options)
    end

    ApplySlot(widget.label)
    ApplySlot(widget.text)
    ApplySlot(widget.titletext)

    if widget.checkbox then
        ApplySlot(widget.checkbox.text)
    end

    if widget.frame then
        ApplySlot(widget.frame.text)
        ApplySlot(widget.frame.label)
    end
end

function TextStyles.ApplyWidgetText(widget, role, options)
    ApplyToKnownTextSlots(widget, role, options)
end

function TextStyles.ApplyInteractiveWidgetText(widget, activeRole, disabled, options)
    local role = disabled and "disabled" or activeRole
    ApplyToKnownTextSlots(widget, role, options)
end

function TextStyles.ApplyLabelWidget(widget, role, options)
    if not widget then
        return
    end

    local target = widget.label or widget.text
    if target then
        TextStyles.ApplyFontString(target, role, options)
    end
end

function TextStyles.ApplyTextRole(widget, text, role, options)
    if not widget or not widget.SetText then
        return
    end

    widget:SetText(text or "")
    TextStyles.ApplyLabelWidget(widget, role, options)
end

function TextStyles.ApplyLabelRole(widget, text, role, options)
    if not widget then
        return
    end

    if widget.SetLabel then
        widget:SetLabel(text or "")
    elseif widget.SetText then
        widget:SetText(text or "")
    end

    TextStyles.ApplyWidgetText(widget, role, options)
end

return TextStyles
