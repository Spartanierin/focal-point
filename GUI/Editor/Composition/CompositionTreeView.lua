local _, ns = ...

ns.GUI = ns.GUI or {}
ns.GUI.Editor = ns.GUI.Editor or {}
ns.GUI.Editor.Composition = ns.GUI.Editor.Composition or {}

local AceGUI = LibStub("AceGUI-3.0")
local View = {}
ns.GUI.Editor.Composition.TreeView = View
ns.CompositionTreeView = View

local L = ns.L or {}
local FormWidgets = ns.GUI.Helpers and ns.GUI.Helpers.FormWidgets or {}
local ResolveItemColor = FormWidgets.ResolveItemColor
local ApplyTextStyle = FormWidgets.ApplyTextStyle
local Adapter = ns.CompositionTreeAdapter or (ns.GUI.Editor.Composition and ns.GUI.Editor.Composition.TreeAdapter) or {}

local function ResolveColor(role, fallback)
    return (ResolveItemColor and ResolveItemColor(role)) or fallback
end

local function ApplyLabelStyle(label, node)
    if not label then
        return
    end

    local size = node and node.type == "unit" and 12 or 11
    if ApplyTextStyle then
        ApplyTextStyle(label, "label", size, 1)
    elseif label.SetFont then
        label:SetFont(STANDARD_TEXT_FONT, size, "")
    end

    local color
    if node and node.core == true then
        color = ResolveColor("text", { 0.88, 0.84, 0.72, 1 })
    elseif node and (node.type == "health" or node.type == "power" or node.type == "cast" or node.type == "texts" or node.type == "auras") then
        color = ResolveColor("statusMuted", { 0.66, 0.70, 0.75, 1 })
    else
        color = ResolveColor("description", { 0.76, 0.79, 0.84, 1 })
    end

    if label.SetTextColor then
        label:SetTextColor(color[1] or 1, color[2] or 1, color[3] or 1, color[4] or 1)
    end
    if label.SetJustifyH then
        label:SetJustifyH("LEFT")
    end
end

local function FormatNodeLabel(node)
    if type(node) ~= "table" then
        return ""
    end
    if type(node.label) == "string" and node.label ~= "" then
        return node.label
    end
    return tostring(node.type or node.id or "")
end

local function AddNodeRow(container, node, depth)
    local label = AceGUI:Create("Label")
    label:SetFullWidth(true)
    label:SetText(string.rep("  ", math.max(0, tonumber(depth) or 0)) .. FormatNodeLabel(node))
    if label.label then
        ApplyLabelStyle(label.label, node)
    end
    container:AddChild(label)
end

local function RenderNode(container, node, depth)
    if type(node) ~= "table" then
        return
    end

    AddNodeRow(container, node, depth)
    for _, child in ipairs(node.children or {}) do
        RenderNode(container, child, (tonumber(depth) or 0) + 1)
    end
end

function View.Build(container, state)
    if not container then
        return false
    end

    local unit = type(state) == "table" and state.selectedUnit or nil
    local tree = type(Adapter.BuildUnitTree) == "function" and Adapter.BuildUnitTree(unit) or nil
    if type(tree) ~= "table" then
        local empty = AceGUI:Create("Label")
        empty:SetFullWidth(true)
        empty:SetText(L["COMPOSITION_TREE_EMPTY"] or "No composition tree available.")
        if empty.label then
            ApplyLabelStyle(empty.label, { type = "empty" })
        end
        container:AddChild(empty)
        return false
    end

    RenderNode(container, tree, 0)
    return true
end

return View
