local _, ns = ...

ns.GUI = ns.GUI or {}
ns.GUI.Helpers = ns.GUI.Helpers or {}

local AceGUI = LibStub("AceGUI-3.0")
local TextStyles = ns.GUI.Helpers.TextStyles

local ToolPageUI = {}
ns.GUI.Helpers.ToolPageUI = ToolPageUI

ToolPageUI.PAGE_WIDTH = 880
ToolPageUI.CARD_BACKGROUND = { 0.07, 0.08, 0.10, 0.74 }
ToolPageUI.CARD_BORDER = { 0.16, 0.19, 0.24, 0.92 }
ToolPageUI.CARD_HEADER = { 0.10, 0.11, 0.14, 0.48 }
ToolPageUI.CARD_ACCENT = { 0.91, 0.77, 0.29, 0.92 }

function ToolPageUI.ApplyLabelStyle(widget, role, size)
    if TextStyles and TextStyles.ApplyLabelWidget then
        TextStyles.ApplyLabelWidget(widget, role, { size = size })
    end
end

function ToolPageUI.ApplyWidgetStyle(widget, role, size)
    if TextStyles and TextStyles.ApplyWidgetText then
        TextStyles.ApplyWidgetText(widget, role, { size = size })
    end
end

function ToolPageUI.CreateSpacer(height)
    local spacer = AceGUI:Create("Label")
    spacer:SetText(" ")
    spacer:SetFullWidth(true)
    spacer:SetHeight(height or 1)
    return spacer
end

function ToolPageUI.CreateFlowGroup(fullWidth, width)
    local group = AceGUI:Create("SimpleGroup")
    group:SetLayout("Flow")
    if fullWidth then
        group:SetFullWidth(true)
    elseif width then
        group:SetWidth(width)
    end
    return group
end

function ToolPageUI.CreateRow(parent, height)
    local row = ToolPageUI.CreateFlowGroup(true)
    if height then
        row:SetHeight(height)
    end
    parent:AddChild(row)
    return row
end

function ToolPageUI.CreateButton(text, width)
    local button = AceGUI:Create("Button")
    button:SetText(text)
    button:SetWidth(width)
    return button
end

function ToolPageUI.CreatePageRoot(container, width)
    local root = ToolPageUI.CreateFlowGroup(true)
    container:AddChild(root)

    local column = ToolPageUI.CreateFlowGroup(false, width or ToolPageUI.PAGE_WIDTH)
    root:AddChild(column)
    return column
end

function ToolPageUI.CreatePageHeader(parent, title, descriptionText, eyebrowText)
    local header = ToolPageUI.CreateFlowGroup(true)
    parent:AddChild(header)

    local eyebrow = AceGUI:Create("Label")
    eyebrow:SetFullWidth(true)
    eyebrow:SetText(eyebrowText or "Werkzeugansicht")
    ToolPageUI.ApplyLabelStyle(eyebrow, "help", 10)
    header:AddChild(eyebrow)

    local titleLabel = AceGUI:Create("Label")
    titleLabel:SetFullWidth(true)
    titleLabel:SetText(title or "")
    ToolPageUI.ApplyLabelStyle(titleLabel, "sectionHeader", 17)
    header:AddChild(titleLabel)

    if type(descriptionText) == "string" and descriptionText ~= "" then
        local description = AceGUI:Create("Label")
        description:SetFullWidth(true)
        description:SetText(descriptionText)
        ToolPageUI.ApplyLabelStyle(description, "help", 11)
        header:AddChild(description)
    end

    return header
end

function ToolPageUI.CreateCard(parent, title, subtitle, options)
    local opts = type(options) == "table" and options or {}

    if (opts.topSpacing or 0) > 0 then
        parent:AddChild(ToolPageUI.CreateSpacer(opts.topSpacing))
    end

    local card = AceGUI:Create("SimpleGroup")
    card:SetFullWidth(true)
    card:SetLayout("Flow")
    parent:AddChild(card)

    local frame = card.frame
    local content = card.content
    if frame and content then
        if not frame._fpCardBg then
            local bg = frame:CreateTexture(nil, "BACKGROUND")
            bg:SetAllPoints()
            bg:SetColorTexture(unpack(ToolPageUI.CARD_BACKGROUND))
            frame._fpCardBg = bg
        end

        if not frame._fpCardHeader then
            local header = frame:CreateTexture(nil, "BORDER")
            header:SetPoint("TOPLEFT")
            header:SetPoint("TOPRIGHT")
            header:SetHeight(34)
            header:SetColorTexture(unpack(ToolPageUI.CARD_HEADER))
            frame._fpCardHeader = header
        end

        if not frame._fpCardAccent then
            local accent = frame:CreateTexture(nil, "BORDER")
            accent:SetPoint("TOPLEFT")
            accent:SetPoint("TOPRIGHT")
            accent:SetHeight(2)
            accent:SetColorTexture(unpack(ToolPageUI.CARD_ACCENT))
            frame._fpCardAccent = accent
        end

        local function EnsureBorder(name, ...)
            if frame[name] then
                return
            end

            local border = frame:CreateTexture(nil, "BORDER")
            border:SetColorTexture(unpack(ToolPageUI.CARD_BORDER))
            border:SetPoint(...)
            frame[name] = border
        end

        EnsureBorder("_fpCardBorderTop", "TOPLEFT", frame, "TOPLEFT", 0, 0)
        frame._fpCardBorderTop:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0)
        frame._fpCardBorderTop:SetHeight(1)

        EnsureBorder("_fpCardBorderBottom", "BOTTOMLEFT", frame, "BOTTOMLEFT", 0, 0)
        frame._fpCardBorderBottom:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
        frame._fpCardBorderBottom:SetHeight(1)

        EnsureBorder("_fpCardBorderLeft", "TOPLEFT", frame, "TOPLEFT", 0, 0)
        frame._fpCardBorderLeft:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, 0)
        frame._fpCardBorderLeft:SetWidth(1)

        EnsureBorder("_fpCardBorderRight", "TOPRIGHT", frame, "TOPRIGHT", 0, 0)
        frame._fpCardBorderRight:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
        frame._fpCardBorderRight:SetWidth(1)

        content:ClearAllPoints()
        content:SetPoint("TOPLEFT", frame, "TOPLEFT", 16, -12)
        content:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -16, 14)
    end

    if title and title ~= "" then
        local titleLabel = AceGUI:Create("Label")
        titleLabel:SetFullWidth(true)
        titleLabel:SetText(title)
        ToolPageUI.ApplyLabelStyle(titleLabel, "sectionHeader", 13)
        card:AddChild(titleLabel)
    end

    if subtitle and subtitle ~= "" then
        local subtitleLabel = AceGUI:Create("Label")
        subtitleLabel:SetFullWidth(true)
        subtitleLabel:SetText(subtitle)
        ToolPageUI.ApplyLabelStyle(subtitleLabel, "help", 11)
        card:AddChild(subtitleLabel)
    end

    if title or subtitle then
        card:AddChild(ToolPageUI.CreateSpacer(6))
    end

    return card
end

return ToolPageUI
