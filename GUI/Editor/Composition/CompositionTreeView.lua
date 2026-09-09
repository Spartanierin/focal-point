local _, ns = ...

ns.GUI = ns.GUI or {}
ns.GUI.Editor = ns.GUI.Editor or {}
ns.GUI.Editor.Composition = ns.GUI.Editor.Composition or {}

local AceGUI = LibStub("AceGUI-3.0")
local View = {}
ns.GUI.Editor.Composition.TreeView = View
ns.CompositionTreeView = View

local L = ns.L or {}
local Adapter = ns.CompositionTreeAdapter or (ns.GUI.Editor.Composition and ns.GUI.Editor.Composition.TreeAdapter) or {}
local ObjectSelection = ns.GUI.Editor.ObjectSelection or {}

local Control = ns.GUI.Editor.Composition.TreeControl
local TREE_SCROLL_MAX_HEIGHT = 320
local TREE_SCROLL_MIN_HEIGHT = 64
local TREE_ROW_ESTIMATED_HEIGHT = Control.ROW_HEIGHT
local treeUiStateByUnit = {}

local function FormatNodeLabel(node)
    return type(node.label) == "string" and node.label or tostring(node.type or "")
end

local CLICKABLE_NODE_TYPES = {
    unit = true,
    healthbar = true,
    powerbar = true,
    classPowerBar = true,
    alternativePowerBar = true,
    castbar = true,
    normalAbsorbBar = true,
    healingAbsorbBar = true,
    textElement = true,
    buffs = true,
    debuffs = true,
    indicatorElement = true,
    decorationElement = true,
}

local BAR_OBJECT_BY_NODE_TYPE = {
    healthbar = "HealthBar",
    powerbar = "PowerBar",
    classPowerBar = "ClassPowerBar",
    alternativePowerBar = "AlternativePowerBar",
    castbar = "CastBar",
    normalAbsorbBar = "NormalAbsorbBar",
    healingAbsorbBar = "HealingAbsorbBar",
}

local function IsClickableNode(node)
    if type(node) ~= "table" or CLICKABLE_NODE_TYPES[node.type] ~= true then
        return false
    end
    local target = node.inspectorTarget
    if type(target) ~= "table" or type(target.sectionKey) ~= "string" or target.sectionKey == "" then
        return false
    end
    if target.kind == "unit" then
        return true
    end
    if target.kind == "text" then
        return type(target.textKey) == "string" and target.textKey ~= ""
    end
    if target.kind == "aura" then
        return type(target.auraKey) == "string" and target.auraKey ~= ""
    end
    if target.kind == "decoration" then
        return type(target.decorationId) == "string" and target.decorationId ~= ""
    end
    if target.kind == "indicator" then
        return type(target.indicatorKey) == "string" and target.indicatorKey ~= ""
    end
    return false
end

local TOGGLE_FIELD_BY_NODE_TYPE = {
    powerbar = { target = "unit", field = "showPowerBar" },
    classPowerBar = { target = "unit", field = "showClassPowerBar" },
    alternativePowerBar = { target = "unit", field = "showAlternativePowerBar" },
    castbar = { target = "unit", field = "showCastBar" },
    normalAbsorbBar = { target = "unit", field = "showNormalAbsorbBar" },
    healingAbsorbBar = { target = "unit", field = "showHealingAbsorbBar" },
    textElement = { target = "text", field = "enabled" },
    buffs = { target = "aura", field = "enabled" },
    debuffs = { target = "aura", field = "enabled" },
    indicatorElement = { target = "indicator", field = "enabled" },
    decorationElement = { target = "decoration", field = "enabled" },
}

local function GetToggleSpec(node)
    if type(node) ~= "table" then
        return nil
    end
    local spec = TOGGLE_FIELD_BY_NODE_TYPE[node.type]
    if type(spec) ~= "table" then
        return nil
    end
    if spec.target == "text" and not (node.inspectorTarget and node.inspectorTarget.textKey) then
        return nil
    end
    if spec.target == "aura" and not (node.inspectorTarget and node.inspectorTarget.auraKey) then
        return nil
    end
    if spec.target == "indicator" and not (node.inspectorTarget and node.inspectorTarget.indicatorKey) then
        return nil
    end
    if spec.target == "decoration" and not (node.inspectorTarget and node.inspectorTarget.decorationId) then
        return nil
    end
    return spec
end

local function HasChildren(node)
    return type(node) == "table" and type(node.children) == "table" and #node.children > 0
end

local function ResolveTreeStateKey(unit)
    if type(unit) == "string" and unit ~= "" then
        return unit
    end
    return "__default"
end

local function GetTreeUiState(unit)
    local key = ResolveTreeStateKey(unit)
    local state = treeUiStateByUnit[key]
    if type(state) ~= "table" then
        state = {
            expanded = {},
            scroll = { scrollvalue = 0 },
        }
        treeUiStateByUnit[key] = state
    end
    state.expanded = type(state.expanded) == "table" and state.expanded or {}
    state.scroll = type(state.scroll) == "table" and state.scroll or { scrollvalue = 0 }
    return state
end

local function IsExpanded(node, expansionState)
    if not HasChildren(node) then
        return false
    end
    return not (type(expansionState) == "table" and expansionState[node.id] == false)
end

local function IsToggleableNode(node)
    return GetToggleSpec(node) ~= nil
end

local function RequestTreeOwnerRelayout(container)
    local FormRenderer = ns.GUI.Helpers and ns.GUI.Helpers.FormRenderer or nil
    if FormRenderer and type(FormRenderer.RequestRelayout) == "function" then
        FormRenderer.RequestRelayout(container)
    elseif container and container.DoLayout then
        container:DoLayout()
    end
end

local function ResolveTreeScrollHeight(rowCount, options)
    local height = math.max(0, tonumber(rowCount) or 0) * TREE_ROW_ESTIMATED_HEIGHT
    local minHeight = tonumber(options and options.minHeight) or TREE_SCROLL_MIN_HEIGHT
    local maxHeight = tonumber(options and options.maxHeight) or TREE_SCROLL_MAX_HEIGHT
    if maxHeight < minHeight then
        maxHeight = minHeight
    end
    if height <= 0 then
        return minHeight
    end
    return math.min(maxHeight, math.max(minHeight, height))
end

local IsActiveNode

local function BuildObjectRef(node)
    if not IsClickableNode(node) then
        return nil
    end

    local unit = node.unit
    local sectionKey = node.inspectorTarget.sectionKey
    local targetKind = node.inspectorTarget.kind
    if node.type == "unit" then
        return {
            kind = "unit",
            unit = unit,
            sectionKey = "frame",
        }
    end

    if targetKind == "text" then
        return {
            kind = "text",
            unit = unit,
            textKey = node.inspectorTarget.textKey,
            objectKey = node.inspectorTarget.textKey,
            sectionKey = sectionKey,
        }
    end

    if targetKind == "aura" then
        return {
            kind = "aura",
            unit = unit,
            auraKey = node.inspectorTarget.auraKey,
            objectKey = node.inspectorTarget.auraKey,
            sectionKey = sectionKey,
        }
    end

    if targetKind == "decoration" then
        return {
            kind = "decoration",
            unit = unit,
            decorationId = node.inspectorTarget.decorationId,
            objectKey = node.inspectorTarget.decorationId,
            sectionKey = sectionKey,
        }
    end

    if targetKind == "indicator" then
        return {
            kind = "indicator",
            unit = unit,
            indicatorKey = node.inspectorTarget.indicatorKey,
            objectKey = node.inspectorTarget.indicatorKey,
            sectionKey = sectionKey,
        }
    end

    local objectKey = BAR_OBJECT_BY_NODE_TYPE[node.type]
    if objectKey then
        return {
            kind = "bar",
            unit = unit,
            objectKey = node.inspectorTarget.objectKey or objectKey,
            sectionKey = sectionKey,
        }
    end

    return nil
end

local function RevealActiveNode(node, state, expansionState)
    if type(node) ~= "table" then
        return false
    end
    if IsActiveNode(node, state) then
        return true
    end
    for _, child in ipairs(node.children or {}) do
        if RevealActiveNode(child, state, expansionState) then
            if HasChildren(node) then
                expansionState[node.id] = true
            end
            return true
        end
    end
    return false
end

local function FindVisibleRowIndex(visibleRows, state)
    if type(visibleRows) ~= "table" then
        return nil
    end
    for index, row in ipairs(visibleRows) do
        if IsActiveNode(row.node, state) then
            return index
        end
    end
    return nil
end

local function FindVisibleRowByNodeId(visibleRows, nodeId)
    if type(visibleRows) ~= "table" or type(nodeId) ~= "string" then
        return nil
    end
    for index, row in ipairs(visibleRows) do
        if row.node and row.node.id == nodeId then
            return row, index
        end
    end
    return nil
end

function IsActiveNode(node, state)
    if not IsClickableNode(node) or type(state) ~= "table" then
        return false
    end
    local scope = state.propertyScope
    if node.type == "unit" then
        return state.selectedUnit == node.unit
            and (type(scope) ~= "table" or scope.sectionKey == "frame")
    end
    if node.inspectorTarget.kind == "text" then
        return state.selectedUnit == node.unit
            and state.selectedTextElementUnit == node.unit
            and state.selectedTextElementId == node.inspectorTarget.textKey
    end
    if node.inspectorTarget.kind == "aura" then
        return state.selectedUnit == node.unit
            and state.selectedAuraKey == node.inspectorTarget.auraKey
            and type(scope) == "table"
            and scope.kind == "aura"
            and scope.sectionKey == node.inspectorTarget.sectionKey
            and scope.objectKey == node.inspectorTarget.auraKey
    end
    if node.inspectorTarget.kind == "decoration" then
        return state.selectedUnit == node.unit
            and state.selectedDecorationId == node.inspectorTarget.decorationId
            and type(scope) == "table"
            and scope.kind == "decoration"
            and scope.sectionKey == node.inspectorTarget.sectionKey
            and scope.objectKey == node.inspectorTarget.decorationId
    end
    if node.inspectorTarget.kind == "indicator" then
        return state.selectedUnit == node.unit
            and state.selectedIndicatorKey == node.inspectorTarget.indicatorKey
            and type(scope) == "table"
            and scope.kind == "indicator"
            and scope.sectionKey == node.inspectorTarget.sectionKey
            and scope.objectKey == node.inspectorTarget.indicatorKey
    end
    return type(scope) == "table"
        and scope.kind == "unit"
        and scope.sectionKey == node.inspectorTarget.sectionKey
        and (
            not node.inspectorTarget.objectKey
            or scope.objectKey == node.inspectorTarget.objectKey
        )
        and state.selectedUnit == node.unit
end

local function SelectTreeNode(node, state, options)
    local objectRef = BuildObjectRef(node)
    if not objectRef or type(ObjectSelection.SelectObject) ~= "function" then
        return false
    end

    local ok, changeKind = ObjectSelection.SelectObject(objectRef)
    if ok ~= true then
        return false
    end
    if options and type(options.onSelect) == "function" then
        options.onSelect(objectRef, node, changeKind)
    end
    return true
end

local function RebuildTree(options)
    if options and type(options.rebuild) == "function" then
        options.rebuild()
        return true
    end
    return false
end

local function EnsureActiveSelectionVisible(control, state, options)
    control:EnsureVisible(FindVisibleRowIndex(options.visibleRows, state))
end

local function SelectVisibleRow(visibleRows, index, state, options)
    local row = type(visibleRows) == "table" and visibleRows[index] or nil
    if not (row and row.node) then
        return false
    end
    local selected = SelectTreeNode(row.node, state, options)
    if selected then
        EnsureActiveSelectionVisible(options and options._focalPointScroll, state, options)
    end
    return selected
end

local function SelectNextVisibleObject(visibleRows, startIndex, direction, state, options)
    if type(visibleRows) ~= "table" then
        return false
    end

    local step = direction == "up" and -1 or 1
    local index = (tonumber(startIndex) or 0) + step
    while index >= 1 and index <= #visibleRows do
        if SelectVisibleRow(visibleRows, index, state, options) then
            return true
        end
        index = index + step
    end
    return false
end

local function HandleTreeKey(key, state, options)
    local visibleRows = options and options.visibleRows or nil
    local expansionState = options and options.expanded or nil
    local currentIndex = FindVisibleRowIndex(visibleRows, state)
    local currentRow = type(visibleRows) == "table" and currentIndex and visibleRows[currentIndex] or nil
    local currentNode = currentRow and currentRow.node or nil
    if not currentNode then
        return false
    end

    if key == "UP" then
        if currentIndex and currentIndex > 1 then
            return SelectNextVisibleObject(visibleRows, currentIndex, "up", state, options)
        end
        return false
    elseif key == "DOWN" then
        if currentIndex and currentIndex < #visibleRows then
            return SelectNextVisibleObject(visibleRows, currentIndex, "down", state, options)
        end
        return false
    elseif key == "LEFT" then
        if HasChildren(currentNode) and IsExpanded(currentNode, expansionState) then
            expansionState[currentNode.id] = false
            return RebuildTree(options)
        end
        local parentRow = FindVisibleRowByNodeId(visibleRows, currentNode.parentId)
        if parentRow then
            return SelectTreeNode(parentRow.node, state, options)
        end
        return false
    elseif key == "RIGHT" then
        if HasChildren(currentNode) and not IsExpanded(currentNode, expansionState) then
            expansionState[currentNode.id] = true
            return RebuildTree(options)
        end
        if HasChildren(currentNode) and IsExpanded(currentNode, expansionState) then
            local firstChild = currentNode.children and currentNode.children[1] or nil
            local childRow = firstChild and FindVisibleRowByNodeId(visibleRows, firstChild.id) or nil
            if childRow then
                return SelectTreeNode(childRow.node, state, options)
            end
        end
    end
    return false
end

local function CollectVisibleRows(node, depth, state, options)
    local rows = options.visibleRows
    rows[#rows + 1] = {
        node = node,
        depth = depth,
        label = FormatNodeLabel(node),
        clickable = IsClickableNode(node),
        toggleable = IsToggleableNode(node) and type(options.onToggle) == "function",
        expandable = HasChildren(node),
        expanded = IsExpanded(node, options.expanded),
        selected = IsActiveNode(node, state),
    }
    if IsExpanded(node, options.expanded) then
        for _, child in ipairs(node.children) do
            CollectVisibleRows(child, depth + 1, state, options)
        end
    end
end

function View.Build(container, state, options)
    local perf = ns.SelectionPerfDebug
    local perfStart = perf and perf.Begin and perf:Begin("CompositionTreeView.Build")
    if not container then
        if perf and perf.End then perf:End("CompositionTreeView.Build", perfStart) end
        return false
    end
    options = options or {}
    local unit = type(state) == "table" and state.selectedUnit or nil
    local tree = Adapter.BuildUnitTree(unit)
    if not tree then
        local empty = AceGUI:Create("Label")
        empty:SetFullWidth(true)
        empty:SetText(L["COMPOSITION_TREE_EMPTY"] or "No composition tree available.")
        container:AddChild(empty)
        if perf and perf.End then perf:End("CompositionTreeView.Build", perfStart) end
        return false
    end

    local uiState = GetTreeUiState(unit)
    options.expanded = uiState.expanded
    RevealActiveNode(tree, state, options.expanded)
    local host = AceGUI:Create("SimpleGroup")
    host:SetFullWidth(true)
    host:SetAutoAdjustHeight(false)
    local control
    local context

    local function RenderRows()
        options.visibleRows = {}
        CollectVisibleRows(tree, 0, state, options)
        host:SetHeight(ResolveTreeScrollHeight(#options.visibleRows, options))
        RequestTreeOwnerRelayout(container)
        control:SetRows(options.visibleRows)
    end

    options.rebuild = function()
        RenderRows()
        return true
    end
    options.visibleRows = {}
    CollectVisibleRows(tree, 0, state, options)
    host:SetHeight(ResolveTreeScrollHeight(#options.visibleRows, options))
    container:AddChild(host)
    RequestTreeOwnerRelayout(container)

    local callbacks = {
        onSelect = function(node)
            AceGUI:ClearFocus()
            SelectTreeNode(node, state, options)
        end,
        onExpand = function(node, expanded)
            AceGUI:ClearFocus()
            options.expanded[node.id] = expanded
            options.rebuild()
        end,
        onToggle = function(node, enabled)
            AceGUI:ClearFocus()
            local generation = control.generation
            local result = options.onToggle(node, enabled)
            -- A mutation may synchronously release and rebind this pooled control.
            if control.generation == generation and not (result and result.ok == false) then
                node.enabled = enabled
                control:RefreshSelection(function(rowNode) return IsActiveNode(rowNode, state) end)
            end
        end,
        onKey = function(key)
            return HandleTreeKey(key, state, options)
        end,
    }
    control = Control.Acquire(host.content, uiState.scroll, callbacks)
    options._focalPointScroll = control
    context = { control = control, state = state, options = options, tree = tree, render = RenderRows }
    host:SetCallback("OnRelease", function()
        if View._keyboardBindingContext == context then View._keyboardBindingContext = nil end
        options.rebuild = nil
        options._focalPointScroll = nil
        options.visibleRows = nil
        control:Release()
    end)
    View._keyboardBindingContext = context
    control:SetRows(options.visibleRows)
    EnsureActiveSelectionVisible(control, state, options)
    if perf and perf.End then perf:End("CompositionTreeView.Build", perfStart) end
    return true
end

function View.RefreshKeyboardBinding()
    local context = View._keyboardBindingContext
    if not context then return false end
    local control, state, options = context.control, context.state, context.options
    if not control.callbacks then return false end
    if not FindVisibleRowIndex(options.visibleRows, state) then
        RevealActiveNode(context.tree, state, options.expanded)
        context.render()
    end
    control:RefreshSelection(function(node) return IsActiveNode(node, state) end)
    EnsureActiveSelectionVisible(control, state, options)
    return true
end

return View
