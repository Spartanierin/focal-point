local _, FocalPoint = ...

FocalPoint.GUI = FocalPoint.GUI or {}
FocalPoint.GUI.Layouts = FocalPoint.GUI.Layouts or {}

local AceGUI = LibStub("AceGUI-3.0")
local TitleStyles = FocalPoint.GUI.Helpers and FocalPoint.GUI.Helpers.TitleStyles or nil

local SectionLayout = {}
FocalPoint.GUI.Layouts.SectionLayout = SectionLayout

local function CreateColumn(relativeWidth)
    local column = AceGUI:Create("SimpleGroup")
    column:SetRelativeWidth(relativeWidth or 0.5)
    column:SetLayout("List")
    return column
end

local function CreateRow()
    local row = AceGUI:Create("SimpleGroup")
    row:SetFullWidth(true)
    row:SetLayout("Flow")
    return row
end

local function CreateSingleColumn()
    local column = AceGUI:Create("SimpleGroup")
    column:SetFullWidth(true)
    column:SetLayout("List")
    return column
end

local function CreateSubsectionHeader(text)
    local group = AceGUI:Create("SimpleGroup")
    group:SetFullWidth(true)
    group:SetLayout("Flow")

    local spacer = AceGUI:Create("Label")
    spacer:SetText(" ")
    spacer:SetFullWidth(true)
    spacer:SetHeight(4)
    group:AddChild(spacer)

    local heading = AceGUI:Create("Heading")
    if TitleStyles and TitleStyles.FormatSubsection then
        heading:SetText(TitleStyles.FormatSubsection(text or ""))
    else
        heading:SetText(text or "")
    end
    heading:SetFullWidth(true)
    group:AddChild(heading)

    return group
end

local function NormalizeLayoutMeta(meta)
    local source = type(meta) == "table" and meta or {}

    local placement = source.placement
    if placement ~= "left" and placement ~= "right" and placement ~= "full" then
        placement = "auto"
    end

    local span = tonumber(source.span) == 2 and 2 or 1
    local rowType = source.rowType
    if rowType ~= "inline"
        and rowType ~= "actions"
        and rowType ~= "preview"
        and rowType ~= "toolbar"
    then
        rowType = "default"
    end

    if placement == "full" then
        span = 2
    end

    if rowType == "actions" or rowType == "preview" or rowType == "toolbar" then
        span = 2
    end

    return {
        placement = placement,
        span = span,
        rowType = rowType,
        subsection = type(source.subsection) == "string" and source.subsection ~= "" and source.subsection or nil,
    }
end

function SectionLayout.CreateTwoColumn(parent)
    if not parent then
        return nil
    end

    local section = AceGUI:Create("SimpleGroup")
    section:SetFullWidth(true)
    section:SetLayout("Flow")
    parent:AddChild(section)

    local currentLeft = nil
    local currentRight = nil
    local nextColumn = 1
    local currentSubsection = nil

    local layout = {}

    local function ResetRowState()
        currentLeft = nil
        currentRight = nil
        nextColumn = 1
    end

    local function AddSubsection(text)
        ResetRowState()

        local row = CreateRow()
        local column = CreateSingleColumn()
        row:AddChild(column)
        column:AddChild(CreateSubsectionHeader(text))
        section:AddChild(row)

        ResetRowState()
    end

    local function EnsureTwoColumnRow()
        if currentLeft and currentRight then
            return
        end

        local row = CreateRow()
        local left = CreateColumn(0.5)
        local right = CreateColumn(0.5)

        row:AddChild(left)
        row:AddChild(right)
        section:AddChild(row)

        currentLeft = left
        currentRight = right
    end

    local function AddFullWidth(handle)
        ResetRowState()

        local row = CreateRow()
        local column = CreateSingleColumn()
        row:AddChild(column)
        column:AddChild(handle.group)
        section:AddChild(row)

        ResetRowState()
    end

    function layout:Add(handle, meta)
        if not handle or not handle.group then
            return nil
        end

        local resolvedMeta = NormalizeLayoutMeta(meta or handle.layoutMeta)
        if resolvedMeta.subsection ~= currentSubsection then
            if resolvedMeta.subsection then
                AddSubsection(resolvedMeta.subsection)
            end
            currentSubsection = resolvedMeta.subsection
        end

        if resolvedMeta.span == 2 then
            AddFullWidth(handle)
            return handle
        end

        EnsureTwoColumnRow()

        local target = nil
        if resolvedMeta.placement == "left" then
            target = currentLeft
            nextColumn = 2
        elseif resolvedMeta.placement == "right" then
            target = currentRight
            nextColumn = 1
        else
            target = nextColumn == 1 and currentLeft or currentRight
            nextColumn = nextColumn == 1 and 2 or 1
        end

        target:AddChild(handle.group)
        return handle
    end

    function layout:Reset()
        ResetRowState()
        currentSubsection = nil
    end

    return layout
end

return SectionLayout
