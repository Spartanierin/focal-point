local _, ns = ...

ns.GUI = ns.GUI or {}
ns.GUI.Helpers = ns.GUI.Helpers or {}

local AceGUI = LibStub("AceGUI-3.0")
local TextStyles = ns.GUI.Helpers.TextStyles
local ToolPageStyles = ns.GUI.Styles and ns.GUI.Styles.ToolPageStyles

local ToolPageUI = {}
ns.GUI.Helpers.ToolPageUI = ToolPageUI

ToolPageUI.PAGE_WIDTH = 880
ToolPageUI.CARD_BACKGROUND = { 0.07, 0.08, 0.10, 0.74 }
ToolPageUI.CARD_BORDER = { 0.16, 0.19, 0.24, 0.92 }
ToolPageUI.CARD_HEADER = { 0.10, 0.11, 0.14, 0.48 }
ToolPageUI.CARD_ACCENT = { 0.91, 0.77, 0.29, 0.92 }
ToolPageUI.PAGE_SURFACE = { 0.07, 0.08, 0.10, 0.58 }
ToolPageUI.PAGE_BORDER = { 0.18, 0.20, 0.25, 0.80 }
ToolPageUI.SUBCARD_BACKGROUND = { 0.10, 0.11, 0.14, 0.42 }
ToolPageUI.SUBCARD_BORDER = { 0.18, 0.20, 0.25, 0.72 }

local function ApplySurface(group, opts)
    local frame = group and group.frame
    local content = group and group.content
    if not frame or not content then
        return
    end

    if opts.background then
        if not frame._fpBg then
            frame._fpBg = frame:CreateTexture(nil, "BACKGROUND")
            frame._fpBg:SetAllPoints()
        end
        frame._fpBg:SetColorTexture(unpack(opts.background))
        frame._fpBg:Show()
    elseif frame._fpBg then
        frame._fpBg:Hide()
    end

    if opts.border then
        local function EnsureBorder(name)
            if not frame[name] then
                frame[name] = frame:CreateTexture(nil, "BORDER")
                frame[name]:SetColorTexture(unpack(opts.border))
            end
            frame[name]:Show()
            frame[name]:SetColorTexture(unpack(opts.border))
        end

        EnsureBorder("_fpBorderTop")
        frame._fpBorderTop:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
        frame._fpBorderTop:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0)
        frame._fpBorderTop:SetHeight(1)

        EnsureBorder("_fpBorderBottom")
        frame._fpBorderBottom:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, 0)
        frame._fpBorderBottom:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
        frame._fpBorderBottom:SetHeight(1)

        EnsureBorder("_fpBorderLeft")
        frame._fpBorderLeft:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
        frame._fpBorderLeft:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, 0)
        frame._fpBorderLeft:SetWidth(1)

        EnsureBorder("_fpBorderRight")
        frame._fpBorderRight:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0)
        frame._fpBorderRight:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
        frame._fpBorderRight:SetWidth(1)
    end

    local inset = opts.inset or 0
    local topInset = opts.topInset or inset
    local bottomInset = opts.bottomInset or inset
    content:ClearAllPoints()
    content:SetPoint("TOPLEFT", frame, "TOPLEFT", inset, -topInset)
    content:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -inset, bottomInset)
end

local function GetStyles()
    if ToolPageStyles and ToolPageStyles.Get then
        return ToolPageStyles.Get()
    end

    return {
        page = { width = ToolPageUI.PAGE_WIDTH },
        spacing = { xs = 4, sm = 8, md = 12, lg = 16 },
        row = { input_height = 64, button_height = 42 },
        columns = {
            two = {
                left = 420,
                right = 420,
                gap = 16,
            },
        },
        buttons = {
            small = 120,
            medium = 150,
            action = 190,
            wide = 220,
        },
    }
end

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

function ToolPageUI.CreateListGroup(fullWidth, width, height)
    local group = AceGUI:Create("SimpleGroup")
    group:SetLayout("List")
    if fullWidth then
        group:SetFullWidth(true)
    elseif width then
        group:SetWidth(width)
    end
    if height then
        group:SetHeight(height)
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

function ToolPageUI.CreateCheckBox(label, width)
    local checkbox = AceGUI:Create("CheckBox")
    if width then
        checkbox:SetWidth(width)
    end
    checkbox:SetLabel(label or "")
    return checkbox
end

function ToolPageUI.AddText(parent, text, role, size, width)
    local label = AceGUI:Create("Label")
    if width then
        label:SetWidth(width)
    else
        label:SetFullWidth(true)
    end
    label:SetText(text or "")
    ToolPageUI.ApplyLabelStyle(label, role or "help", size)
    parent:AddChild(label)
    return label
end

local function CreatePageBody(parent, width)
    local styles = GetStyles()
    local resolvedWidth = width or (styles.page and styles.page.width) or ToolPageUI.PAGE_WIDTH

    local wrapper = AceGUI:Create("SimpleGroup")
    wrapper:SetLayout("Flow")
    wrapper:SetFullWidth(true)
    parent:AddChild(wrapper)

    local page = AceGUI:Create("SimpleGroup")
    page:SetLayout("List")
    page:SetWidth(resolvedWidth)
    wrapper:AddChild(page)

    return page, wrapper
end

function ToolPageUI.CreatePageRoot(container, width)
    if container.ReleaseChildren then
        container:ReleaseChildren()
    end
    if container.SetLayout then
        container:SetLayout("Fill")
    end
    container._focalPointUsesOwnSurface = false

    local scroll = AceGUI:Create("ScrollFrame")
    scroll:SetLayout("List")
    scroll:SetFullWidth(true)
    scroll:SetFullHeight(true)
    container:AddChild(scroll)

    local page = CreatePageBody(scroll, width)

    if scroll.DoLayout then
        scroll:DoLayout()
    end
    if scroll.FixScroll then
        scroll:FixScroll()
    end
    if container.DoLayout then
        container:DoLayout()
    end

    return page, scroll
end

function ToolPageUI.CreateStandardPage(container, width)
    return ToolPageUI.CreatePageRoot(container, width)
end

function ToolPageUI.CreateToolPageRoot(container, width)
    return ToolPageUI.CreateStandardPage(container, width)
end

function ToolPageUI.CreateScrollablePage(container, width, statusTable)
    local renderToken = {}
    if container.ReleaseChildren then
        container:ReleaseChildren()
    end
    if container.SetLayout then
        container:SetLayout("Fill")
    end
    container._focalPointRenderToken = renderToken
    container._focalPointUsesOwnSurface = false

    local scroll = AceGUI:Create("ScrollFrame")
    scroll:SetLayout("List")
    scroll:SetFullWidth(true)
    scroll:SetFullHeight(true)
    if type(statusTable) == "table" and scroll.SetStatusTable then
        scroll:SetStatusTable(statusTable)
    end
    container:AddChild(scroll)

    local page = CreatePageBody(scroll, width)

    if scroll.DoLayout then
        scroll:DoLayout()
    end
    if scroll.FixScroll then
        scroll:FixScroll()
    end
    if container.DoLayout then
        container:DoLayout()
    end

    return page, scroll
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

function ToolPageUI.AddStandardHeader(parent, title, description)
    local header = AceGUI:Create("SimpleGroup")
    header:SetLayout("List")
    header:SetFullWidth(true)
    parent:AddChild(header)

    local titleLabel = AceGUI:Create("Label")
    titleLabel:SetFullWidth(true)
    titleLabel:SetText(title or "")
    ToolPageUI.ApplyLabelStyle(titleLabel, "sectionHeader", 17)
    header:AddChild(titleLabel)

    if type(description) == "string" and description ~= "" then
        local descriptionLabel = AceGUI:Create("Label")
        descriptionLabel:SetFullWidth(true)
        descriptionLabel:SetText(description)
        ToolPageUI.ApplyLabelStyle(descriptionLabel, "help", 11)
        header:AddChild(descriptionLabel)
    end

    return header
end

function ToolPageUI.AddToolHeader(parent, title, description)
    return ToolPageUI.AddStandardHeader(parent, title, description)
end

function ToolPageUI.AddStandardSection(parent, title)
    local styles = GetStyles()
    local gap = (styles.page and styles.page.section_gap) or 12

    local section = AceGUI:Create("SimpleGroup")
    section:SetFullWidth(true)
    section:SetLayout("List")
    parent:AddChild(section)

    local titleLabel = AceGUI:Create("Label")
    titleLabel:SetFullWidth(true)
    titleLabel:SetText(title or "")
    ToolPageUI.ApplyLabelStyle(titleLabel, "sectionHeader", 13)
    section:AddChild(titleLabel)
    section:AddChild(ToolPageUI.CreateSpacer(gap - 6))
    return section
end

function ToolPageUI.AddToolSection(parent, title, description)
    local section = ToolPageUI.AddStandardSection(parent, title)
    ToolPageUI.AddSectionDescription(section, description)
    return section
end

function ToolPageUI.AddSectionDescription(parent, text)
    if type(text) == "string" and text ~= "" then
        ToolPageUI.AddText(parent, text, "help", 11)
        parent:AddChild(ToolPageUI.CreateSpacer(6))
    end
end

function ToolPageUI.AddFieldLabel(parent, text)
    return ToolPageUI.AddText(parent, text, "label", 12)
end

function ToolPageUI.AddInfoText(parent, text, role, size)
    return ToolPageUI.AddText(parent, text, role or "help", size or 11)
end

function ToolPageUI.AddFieldBlock(parent, labelText)
    local block = AceGUI:Create("SimpleGroup")
    block:SetLayout("List")
    block:SetFullWidth(true)
    parent:AddChild(block)
    if labelText and labelText ~= "" then
        ToolPageUI.AddFieldLabel(block, labelText)
        block:AddChild(ToolPageUI.CreateSpacer(4))
    end
    return block
end

function ToolPageUI.AddFormRow(parent, height)
    local styles = GetStyles()
    return ToolPageUI.CreateRow(parent, height or styles.row.input_height)
end

function ToolPageUI.AddStandardButtonRow(parent, buttons)
    local row = AceGUI:Create("SimpleGroup")
    row:SetLayout("Flow")
    row:SetFullWidth(true)
    parent:AddChild(row)

    for _, button in ipairs(buttons or {}) do
        if button then
            row:AddChild(button)
        end
    end

    return row
end

function ToolPageUI.AddActionRow(parent, buttons)
    return ToolPageUI.AddStandardButtonRow(parent, buttons)
end

function ToolPageUI.AddTwoColumnRow(parent, leftWidth, rightWidth, gap)
    local styles = GetStyles()
    local spec = styles.columns.two or {}
    local resolvedGap = gap or spec.gap or 16
    local resolvedLeft = leftWidth or spec.left or 420
    local resolvedRight = rightWidth or spec.right or 420

    local row = AceGUI:Create("SimpleGroup")
    row:SetLayout("Flow")
    row:SetFullWidth(true)
    parent:AddChild(row)

    local left = AceGUI:Create("SimpleGroup")
    left:SetLayout("List")
    left:SetWidth(resolvedLeft)
    row:AddChild(left)

    local gutter = AceGUI:Create("SimpleGroup")
    gutter:SetLayout("List")
    gutter:SetWidth(resolvedGap)
    row:AddChild(gutter)

    local right = AceGUI:Create("SimpleGroup")
    right:SetLayout("List")
    right:SetWidth(resolvedRight)
    row:AddChild(right)

    return row, left, right, gutter
end

function ToolPageUI.AddTwoColumnSection(parent, leftWidth, rightWidth, gap)
    return ToolPageUI.AddTwoColumnRow(parent, leftWidth, rightWidth, gap)
end

function ToolPageUI.AddSubsection(parent, title)
    local group = AceGUI:Create("SimpleGroup")
    group:SetFullWidth(true)
    group:SetLayout("List")
    parent:AddChild(group)

    ApplySurface(group, {
        background = ToolPageUI.SUBCARD_BACKGROUND,
        border = ToolPageUI.SUBCARD_BORDER,
        inset = 12,
        topInset = 12,
        bottomInset = 12,
    })

    if title and title ~= "" then
        local titleLabel = AceGUI:Create("Label")
        titleLabel:SetFullWidth(true)
        titleLabel:SetText(title)
        ToolPageUI.ApplyLabelStyle(titleLabel, "sectionHeader", 12)
        group:AddChild(titleLabel)
    end

    return group
end

function ToolPageUI.AddSubCard(parent, title, description)
    local group = ToolPageUI.AddSubsection(parent, title)
    ToolPageUI.AddSectionDescription(group, description)
    return group
end

function ToolPageUI.AddCheckboxMatrix(parent, options)
    local opts = type(options) == "table" and options or {}
    local grid = AceGUI:Create("SimpleGroup")
    grid:SetLayout("Flow")
    grid:SetFullWidth(true)
    grid._fpMatrixColumns = opts.columns or 4
    grid._fpMatrixItemWidth = opts.itemWidth or 150
    parent:AddChild(grid)
    return grid
end

function ToolPageUI.AddCheckboxMatrixItem(matrix, label, options)
    local opts = type(options) == "table" and options or {}
    local checkbox = ToolPageUI.CreateCheckBox(label, opts.width or matrix._fpMatrixItemWidth or 150)
    matrix:AddChild(checkbox)
    return checkbox
end

function ToolPageUI.CreateCard(parent, title, subtitle, options)
    local opts = type(options) == "table" and options or {}

    if (opts.topSpacing or 0) > 0 then
        parent:AddChild(ToolPageUI.CreateSpacer(opts.topSpacing))
    end

    local card = AceGUI:Create("SimpleGroup")
    if opts.fullWidth == false and opts.width then
        card:SetWidth(opts.width)
    else
        card:SetFullWidth(true)
    end
    if opts.height then
        card:SetHeight(opts.height)
        if card.frame and card.frame.SetHeight then
            card.frame:SetHeight(opts.height)
        end
    end
    card:SetLayout(opts.layout or "Flow")
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

function ToolPageUI.CreateFixedSplitRow(parent, leftWidth, rightWidth, height, gap)
    local row = ToolPageUI.CreateFlowGroup(true)
    row:SetHeight(height)
    parent:AddChild(row)

    local left = ToolPageUI.CreateListGroup(false, leftWidth, height)
    local gutter = ToolPageUI.CreateListGroup(false, gap or 16, height)
    local right = ToolPageUI.CreateListGroup(false, rightWidth, height)

    row:AddChild(left)
    row:AddChild(gutter)
    row:AddChild(right)

    return row, left, right, gutter
end

return ToolPageUI
