local _, ns = ...

ns.GUI = ns.GUI or {}
ns.GUI.Helpers = ns.GUI.Helpers or {}

local AceGUI = LibStub("AceGUI-3.0")
local TextStyles = ns.GUI.Helpers.TextStyles

local ToolFormBuilder = {}
ns.GUI.Helpers.ToolFormBuilder = ToolFormBuilder

local DEFAULT_WIDTH = 860
local DEFAULT_PADDING = 16
local DEFAULT_SPACING = 12

local function StyleLabel(widget, role, size)
    if TextStyles and TextStyles.ApplyLabelWidget then
        TextStyles.ApplyLabelWidget(widget, role or "label", { size = size })
    end
end

local function StyleWidget(widget, role, size)
    if TextStyles and TextStyles.ApplyWidgetText then
        TextStyles.ApplyWidgetText(widget, role or "label", { size = size })
    end
end

local function ResolveParent(parent)
    if type(parent) == "table" and parent.content and parent.surface and parent.root then
        return parent.content
    end
    return parent
end

local function GetSurfaceChromeHeight(surface)
    if not surface then
        return 40
    end

    local frameHeight = surface.frame and surface.frame:GetHeight() or 0
    local contentHeight = surface.content and surface.content:GetHeight() or 0
    local extra = frameHeight - contentHeight
    if extra > 0 then
        return extra
    end
    return 40
end

local function CreateGroup(layout, opts)
    local options = type(opts) == "table" and opts or {}
    local group = AceGUI:Create("SimpleGroup")
    group:SetLayout(layout or "List")

    if options.fullWidth ~= false then
        group:SetFullWidth(true)
    elseif options.width then
        group:SetWidth(options.width)
    end

    if options.autoHeight == false and group.SetAutoAdjustHeight then
        group:SetAutoAdjustHeight(false)
    end

    if options.height then
        group:SetHeight(options.height)
    end

    return group
end

local function CreateLabel(text, role, size, fullWidth)
    local label = AceGUI:Create("Label")
    if fullWidth ~= false then
        label:SetFullWidth(true)
    end
    label:SetText(text or "")
    StyleLabel(label, role, size)
    return label
end

local function CreateButton(def)
    if def.type then
        return def
    end

    local button = AceGUI:Create("Button")
    button:SetText(def.text or def.label or "")
    if def.width then
        button:SetWidth(def.width)
    end
    if def.callback then
        button:SetCallback("OnClick", def.callback)
    end
    return button
end

local function DoLayoutRecursive(widget)
    if not widget then
        return
    end

    for _, child in ipairs(widget.children or {}) do
        DoLayoutRecursive(child)
    end

    if widget.DoLayout then
        widget:DoLayout()
    end
end

function ToolFormBuilder.CreatePage(container, opts)
    local options = type(opts) == "table" and opts or {}
    local width = options.width or DEFAULT_WIDTH
    local padding = options.padding or DEFAULT_PADDING
    local spacing = options.spacing or DEFAULT_SPACING
    local scrollable = options.scrollable == true

    if container.ReleaseChildren then
        container:ReleaseChildren()
    end
    if container.SetLayout then
        container:SetLayout(scrollable and "Fill" or "List")
    end

    local scroll
    local host = container
    if scrollable then
        scroll = AceGUI:Create("ScrollFrame")
        scroll:SetLayout("List")
        scroll:SetFullWidth(true)
        scroll:SetFullHeight(true)
        container:AddChild(scroll)
        host = scroll
    end

    local root = CreateGroup("List", {
        fullWidth = false,
        width = width,
    })
    host:AddChild(root)

    local surface = AceGUI:Create("InlineGroup")
    surface:SetLayout("List")
    surface.content:ClearAllPoints()
    surface.content:SetPoint("TOPLEFT", surface.frame, "TOPLEFT", padding, -padding)
    surface.content:SetPoint("BOTTOMRIGHT", surface.frame, "BOTTOMRIGHT", -padding, padding)
    surface:SetTitle("")
    surface:SetWidth(width)
    root:AddChild(surface)

    local page = {
        container = container,
        root = root,
        scroll = scroll,
        surface = surface,
        content = surface,
        width = width,
        padding = padding,
        spacing = spacing,
        _surfaceChromeHeight = nil,
    }

    return page
end

function ToolFormBuilder.AddHeader(page, opts)
    local options = type(opts) == "table" and opts or {}
    local block = ToolFormBuilder.AddBlock(page, {})

    if options.title and options.title ~= "" then
        block:AddChild(CreateLabel(options.title, "sectionHeader", 17))
    end

    if options.description and options.description ~= "" then
        block:AddChild(CreateLabel(options.description, "help", 11))
    end

    if options.statusLabel and options.statusLabel ~= "" then
        block:AddChild(CreateLabel(options.statusLabel, "sectionHeader", 13))
        if options.statusValue and options.statusValue ~= "" then
            block:AddChild(CreateLabel(options.statusValue, "highlight", 16))
        end
    end

    return block
end

function ToolFormBuilder.AddBlock(parent, opts)
    local target = ResolveParent(parent)
    local options = type(opts) == "table" and opts or {}
    local block = CreateGroup("List", {
        fullWidth = true,
    })
    target:AddChild(block)

    if options.title and options.title ~= "" then
        ToolFormBuilder.AddBlockTitle(block, options.title)
    end

    return block
end

function ToolFormBuilder.AddBlockTitle(parent, text)
    local target = ResolveParent(parent)
    local label = CreateLabel(text, "sectionHeader", 13)
    target:AddChild(label)
    return label
end

function ToolFormBuilder.AddTwoColumns(parent, opts)
    local target = ResolveParent(parent)
    local options = type(opts) == "table" and opts or {}
    local gap = options.gap or 16
    local leftWeight = options.leftWeight or 1
    local rightWeight = options.rightWeight or 1

    local row = CreateGroup("Table", {
        fullWidth = true,
    })
    row:SetUserData("table", {
        columns = {
            { weight = leftWeight },
            { weight = rightWeight },
        },
        spaceH = gap,
        spaceV = 0,
        align = "TOPLEFT",
        alignV = "start",
        alignH = "start",
    })
    target:AddChild(row)

    local left = CreateGroup("List", { fullWidth = true })
    local right = CreateGroup("List", { fullWidth = true })
    row:AddChild(left)
    row:AddChild(right)

    return left, right, row
end

function ToolFormBuilder.AddDisplayField(parent, opts)
    local options = type(opts) == "table" and opts or {}
    local block = ToolFormBuilder.AddBlock(parent, {})

    if options.label and options.label ~= "" then
        block:AddChild(CreateLabel(options.label, "label", 12))
    end

    local valueLabel = CreateLabel(options.value or "", options.role or "highlight", options.size or 14)
    block:AddChild(valueLabel)
    return valueLabel, block
end

function ToolFormBuilder.AddSelectField(parent, opts)
    local options = type(opts) == "table" and opts or {}
    local block = ToolFormBuilder.AddBlock(parent, {})

    if options.label and options.label ~= "" then
        block:AddChild(CreateLabel(options.label, "label", 12))
    end

    local dropdown = AceGUI:Create("Dropdown")
    dropdown:SetLabel("")
    dropdown:SetWidth(options.width or 360)
    if options.list then
        dropdown:SetList(options.list)
    end
    if options.value ~= nil then
        dropdown:SetValue(options.value)
    end
    StyleWidget(dropdown, "label", 12)
    block:AddChild(dropdown)

    return dropdown, block
end

function ToolFormBuilder.AddInputField(parent, opts)
    local options = type(opts) == "table" and opts or {}
    local block = ToolFormBuilder.AddBlock(parent, {})

    if options.label and options.label ~= "" then
        block:AddChild(CreateLabel(options.label, "label", 12))
    end

    local input = AceGUI:Create("EditBox")
    input:SetLabel("")
    input:SetWidth(options.width or 360)
    input:DisableButton(true)
    input:SetText(options.value or "")
    StyleWidget(input, "label", 12)
    block:AddChild(input)

    return input, block
end

function ToolFormBuilder.AddActionStack(parent, buttons)
    local target = ResolveParent(parent)
    local block = CreateGroup("List", { fullWidth = true })
    target:AddChild(block)

    for _, def in ipairs(buttons or {}) do
        local button = CreateButton(def)
        block:AddChild(button)
    end

    return block
end

function ToolFormBuilder.AddButtonRow(parent, buttons)
    local target = ResolveParent(parent)
    local defs = buttons or {}
    local columns = {}
    for index, def in ipairs(defs) do
        columns[index] = { width = def.width or 180 }
    end

    local row = CreateGroup("Table", { fullWidth = true })
    row:SetUserData("table", {
        columns = columns,
        spaceH = 8,
        spaceV = 0,
        align = "TOPLEFT",
        alignV = "start",
        alignH = "start",
    })
    target:AddChild(row)

    for _, def in ipairs(defs) do
        local button = CreateButton(def)
        row:AddChild(button)
    end

    return row
end

function ToolFormBuilder.AddNote(parent, text)
    local target = ResolveParent(parent)
    local label = CreateLabel(text or "", "help", 10)
    target:AddChild(label)
    return label
end

function ToolFormBuilder.AddSpacer(parent, height)
    local target = ResolveParent(parent)
    local spacer = CreateGroup("List", {
        fullWidth = true,
        autoHeight = false,
        height = height or DEFAULT_SPACING,
    })
    target:AddChild(spacer)
    return spacer
end

function ToolFormBuilder.Finalize(page)
    if not page then
        return
    end

    DoLayoutRecursive(page.surface)
    DoLayoutRecursive(page.root)

    local contentHeight = page.surface.content and (page.surface.content:GetHeight() or 0) or 0
    if not page._surfaceChromeHeight then
        page._surfaceChromeHeight = GetSurfaceChromeHeight(page.surface)
    end

    local surfaceHeight = contentHeight + (page._surfaceChromeHeight or 40)
    if surfaceHeight > 0 then
        page.surface:SetHeight(surfaceHeight)
    end

    DoLayoutRecursive(page.surface)
    DoLayoutRecursive(page.root)

    if page.scroll then
        if page.scroll.DoLayout then
            page.scroll:DoLayout()
        end
        if page.scroll.FixScroll then
            page.scroll:FixScroll()
        end
    elseif page.container and page.container.DoLayout then
        page.container:DoLayout()
    end
end

return ToolFormBuilder
