local _, PORTRAIT = ...

PORTRAIT.GUI = PORTRAIT.GUI or {}
PORTRAIT.GUI.Layouts = PORTRAIT.GUI.Layouts or {}

local AceGUI = LibStub("AceGUI-3.0")

local SectionLayout = {}
PORTRAIT.GUI.Layouts.SectionLayout = SectionLayout

local function CreateColumn(relativeWidth)
    local column = AceGUI:Create("SimpleGroup")
    column:SetRelativeWidth(relativeWidth or 0.5)
    column:SetLayout("List")
    return column
end

function SectionLayout.CreateTwoColumn(parent, config)
    if not parent then
        return nil
    end

    config = config or {}

    local section = AceGUI:Create("SimpleGroup")
    section:SetFullWidth(true)
    section:SetLayout("Flow")
    parent:AddChild(section)

    local left = CreateColumn(0.5)
    local right = CreateColumn(0.5)

    section:AddChild(left)
    section:AddChild(right)

    local nextColumn = 1

    local layout = {}

    function layout:Add(handle)
        if not handle or not handle.group then
            return nil
        end

        local target = nextColumn == 1 and left or right
        target:AddChild(handle.group)
        nextColumn = nextColumn == 1 and 2 or 1
        return handle
    end

    function layout:Reset()
        nextColumn = 1
    end

    return layout
end

return SectionLayout
