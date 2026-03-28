local _, ns = ...

ns.GUI = ns.GUI or {}
ns.GUI.Helpers = ns.GUI.Helpers or {}
ns.GUI.Helpers.TabValues = ns.GUI.Helpers.TabValues or {}

local C = ns.Constants
local KM = ns.KeyMap

local TabValues = ns.GUI.Helpers.TabValues

local function MakeNode(value, text, children)
    local node = {
        value = value,
        text = text,
    }

    if children and #children > 0 then
        node.children = children
    end

    return node
end

function TabValues.CreateNavTree()
    local tree = {}

    table.insert(tree, MakeNode(
        C.Nav.EDITOR,
        ns.GetLabel(KM.Nav, C.Nav.EDITOR)
    ))

    table.insert(tree, MakeNode(
        C.Nav.PROFILES,
        ns.GetLabel(KM.Nav, C.Nav.PROFILES)
    ))

    table.insert(tree, MakeNode(
        C.Nav.TEXT_BUILDER,
        ns.GetLabel(KM.Nav, C.Nav.TEXT_BUILDER)
    ))

    table.insert(tree, MakeNode(
        C.Nav.TAG_DATABASE,
        ns.GetLabel(KM.Nav, C.Nav.TAG_DATABASE)
    ))

    return tree
end
