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
local ObjectSelection = ns.GUI.Editor.ObjectSelection or {}

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
    if node and node.enabled == false then
        color = ResolveColor("description", { 0.45, 0.48, 0.52, 0.72 })
    elseif node and node.core == true then
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

local CLICKABLE_NODE_TYPES = {
    unit = true,
    healthbar = true,
    powerbar = true,
    castbar = true,
}

local BAR_OBJECT_BY_NODE_TYPE = {
    healthbar = "HealthBar",
    powerbar = "PowerBar",
    castbar = "CastBar",
}

local function IsClickableNode(node)
    if type(node) ~= "table" or CLICKABLE_NODE_TYPES[node.type] ~= true then
        return false
    end
    local target = node.inspectorTarget
    return type(target) == "table"
        and target.kind == "unit"
        and type(target.sectionKey) == "string"
        and target.sectionKey ~= ""
end

local function BuildObjectRef(node)
    if not IsClickableNode(node) then
        return nil
    end

    local unit = node.unit
    local sectionKey = node.inspectorTarget.sectionKey
    if node.type == "unit" then
        return {
            kind = "unit",
            unit = unit,
            sectionKey = "frame",
        }
    end

    local objectKey = BAR_OBJECT_BY_NODE_TYPE[node.type]
    if objectKey then
        return {
            kind = "bar",
            unit = unit,
            objectKey = objectKey,
            sectionKey = sectionKey,
        }
    end

    return nil
end

local function IsActiveNode(node, state)
    if not IsClickableNode(node) or type(state) ~= "table" then
        return false
    end
    local scope = state.propertyScope
    return type(scope) == "table"
        and scope.kind == "unit"
        and scope.sectionKey == node.inspectorTarget.sectionKey
        and state.selectedUnit == node.unit
end

local function AddNodeRow(container, node, depth, state, options)
    local clickable = IsClickableNode(node) and type(options) == "table" and type(options.onSelect) == "function"
    local label = AceGUI:Create(clickable and "InteractiveLabel" or "Label")
    label:SetFullWidth(true)
    if label.SetHeight then
        label:SetHeight(clickable and 20 or 18)
    end
    local prefix = clickable and (IsActiveNode(node, state) and "> " or "  ") or "  "
    label:SetText(string.rep("  ", math.max(0, tonumber(depth) or 0)) .. prefix .. FormatNodeLabel(node))
    if label.label then
        ApplyLabelStyle(label.label, node)
        if clickable and label.label.SetTextColor then
            local color = IsActiveNode(node, state)
                and ResolveColor("accent", { 1, 0.82, 0.36, 1 })
                or node.enabled == false and ResolveColor("description", { 0.45, 0.48, 0.52, 0.72 })
                or ResolveColor("text", { 0.88, 0.84, 0.72, 1 })
            label.label:SetTextColor(color[1] or 1, color[2] or 1, color[3] or 1, color[4] or 1)
        end
    end
    if clickable and label.SetCallback then
        label:SetCallback("OnClick", function()
            local objectRef = BuildObjectRef(node)
            if type(ObjectSelection.SelectObject) ~= "function" or ObjectSelection.SelectObject(objectRef) ~= true then
                return
            end
            options.onSelect(objectRef, node)
        end)
    end
    container:AddChild(label)
end

local function RenderNode(container, node, depth, state, options)
    if type(node) ~= "table" then
        return
    end

    AddNodeRow(container, node, depth, state, options)
    for _, child in ipairs(node.children or {}) do
        RenderNode(container, child, (tonumber(depth) or 0) + 1, state, options)
    end
end

function View.Build(container, state, options)
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

    RenderNode(container, tree, 0, state, options)
    return true
end

return View
