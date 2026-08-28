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

local ROW_WIDGET_TYPE = "FocalPointCompositionTreeRow"
local ROW_WIDGET_VERSION = 3
local ROW_HEIGHT_CLICKABLE = 12
local ROW_HEIGHT_STATIC = 12
local ROW_INDENT = 8
local ROW_TEXT_INSET = 4
local ROW_TEXT_RIGHT_INSET = 3
local ROW_ACCENT_WIDTH = 2
local ROW_CHEVRON_SIZE = 8
local ROW_ICON_SIZE = 10
local ROW_TOGGLE_SIZE = 9
local ROW_LABEL_GAP = 3
local TREE_SCROLL_MAX_HEIGHT = 132
local TREE_SCROLL_MIN_HEIGHT = 64
local TREE_ROW_ESTIMATED_HEIGHT = 15

local ROW_COLORS = {
    fillSelected = { 0.18, 0.22, 0.30, 0.92 },
    fillHover = { 0.09, 0.10, 0.12, 0.34 },
    accent = { 0.90, 0.78, 0.34, 0.76 },
    textRoot = { 0.93, 0.90, 0.80, 1.00 },
    textLeaf = { 0.88, 0.84, 0.72, 1.00 },
    textLeafSelected = { 0.97, 0.95, 0.91, 1.00 },
    textContainer = { 0.58, 0.61, 0.66, 1.00 },
    textDisabled = { 0.54, 0.57, 0.61, 0.95 },
    textFallback = { 0.76, 0.79, 0.84, 1.00 },
    icon = { 0.72, 0.68, 0.54, 0.92 },
    iconContainer = { 0.50, 0.54, 0.60, 0.82 },
    chevron = { 0.60, 0.64, 0.70, 0.88 },
    chevronFill = { 0.06, 0.07, 0.09, 0.82 },
    chevronFillSelected = { 0.90, 0.78, 0.34, 0.22 },
    toggleOn = { 0.90, 0.78, 0.34, 0.92 },
    toggleOff = { 0.42, 0.45, 0.50, 0.58 },
}

local treeUiStateByUnit = {}

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

local function SetTextureColor(texture, color)
    if texture and texture.SetColorTexture and type(color) == "table" then
        texture:SetColorTexture(color[1] or 0, color[2] or 0, color[3] or 0, color[4] or 0)
    end
end

local function IsContainerNode(node)
    return node and (
        node.type == "health"
        or node.type == "power"
        or node.type == "cast"
        or node.type == "texts"
        or node.type == "auras"
        or node.type == "indicators"
        or node.type == "decorations"
    )
end

local TYPE_ICON_BY_NODE_TYPE = {
    unit = "F",
    health = "+",
    power = "+",
    cast = "+",
    texts = "+",
    auras = "+",
    healthbar = "|",
    powerbar = "|",
    classPowerBar = "|",
    alternativePowerBar = "|",
    castbar = "|",
    normalAbsorbBar = "~",
    healingAbsorbBar = "~",
    textElement = "T",
    buffs = "A",
    debuffs = "A",
    indicators = "+",
    indicatorElement = "I",
    decorations = "+",
    decorationElement = "D",
}

local function ResolveTypeIcon(node)
    return type(node) == "table" and (TYPE_ICON_BY_NODE_TYPE[node.type] or "?") or "?"
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

local function CountVisibleRows(node, expansionState)
    if type(node) ~= "table" then
        return 0
    end
    local count = 1
    if IsExpanded(node, expansionState) then
        for _, child in ipairs(node.children or {}) do
            count = count + CountVisibleRows(child, expansionState)
        end
    end
    return count
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

local function ApplyTreeScrollValue(scroll, value)
    if not (scroll and value) then
        return
    end
    if scroll.scrollbar and scroll.scrollbar.SetValue then
        scroll.scrollbar:SetValue(value)
    elseif scroll.SetScroll then
        scroll:SetScroll(value)
    end
end

local function GetTreeScrollValue(scroll, scrollStatus)
    if scroll and scroll.scrollbar and scroll.scrollbar.GetValue then
        local value = tonumber(scroll.scrollbar:GetValue())
        if value then
            return value
        end
    end
    return tonumber(scrollStatus and scrollStatus.scrollvalue) or 0
end

local function AdjustScrollForSelection(scrollStatus, selectedRowIndex, rowCount, scrollHeight, currentScrollValue)
    selectedRowIndex = tonumber(selectedRowIndex)
    rowCount = tonumber(rowCount) or 0
    if not (type(scrollStatus) == "table" and selectedRowIndex and selectedRowIndex > 0 and rowCount > 0) then
        return
    end

    local visibleRows = math.max(1, math.floor((tonumber(scrollHeight) or TREE_SCROLL_MIN_HEIGHT) / TREE_ROW_ESTIMATED_HEIGHT))
    if rowCount <= visibleRows then
        scrollStatus.scrollvalue = 0
        return
    end

    local maxFirstRow = rowCount - visibleRows + 1
    local currentValue = tonumber(currentScrollValue) or tonumber(scrollStatus.scrollvalue) or 0
    local firstRow = math.ceil((maxFirstRow - 1) * math.max(0, math.min(1000, currentValue)) / 1000) + 1
    local lastRow = firstRow + visibleRows - 1

    if selectedRowIndex < firstRow then
        firstRow = selectedRowIndex
    elseif selectedRowIndex > lastRow then
        firstRow = selectedRowIndex - visibleRows + 1
    else
        return
    end

    firstRow = math.max(1, math.min(maxFirstRow, firstRow))
    scrollStatus.scrollvalue = (firstRow - 1) / (maxFirstRow - 1) * 1000
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

local function ResolveRowTextColor(node, selected, clickable)
    if node and node.enabled == false then
        return ResolveColor("description", ROW_COLORS.textDisabled)
    end
    if selected then
        return ResolveColor("valueEmphasis", ROW_COLORS.textLeafSelected)
    end
    if node and node.type == "unit" then
        return ResolveColor("value", ROW_COLORS.textRoot)
    end
    if IsContainerNode(node) then
        return ResolveColor("statusMuted", ROW_COLORS.textContainer)
    end
    if clickable then
        return ResolveColor("text", ROW_COLORS.textLeaf)
    end
    return ResolveColor("description", ROW_COLORS.textFallback)
end

local function ApplyRowGeometry(row)
    if not (row and row.label and row.frame) then
        return
    end

    local depth = math.max(0, tonumber(row.depth) or 0)
    local indent = ROW_TEXT_INSET + depth * ROW_INDENT

    if row.expander then
        row.expander:ClearAllPoints()
        row.expander:SetPoint("LEFT", row.frame, "LEFT", indent, 0)
        row.expander:SetSize(ROW_CHEVRON_SIZE + 3, ROW_CHEVRON_SIZE + 3)
    end
    if row.expanderBackground then
        row.expanderBackground:ClearAllPoints()
        row.expanderBackground:SetAllPoints(row.expander)
    end

    if row.icon then
        row.icon:ClearAllPoints()
        row.icon:SetPoint("LEFT", row.expander or row.frame, row.expander and "RIGHT" or "LEFT", row.expander and 1 or indent, 0)
        row.icon:SetSize(ROW_ICON_SIZE, ROW_ICON_SIZE)
    end

    if row.toggle then
        row.toggle:ClearAllPoints()
        row.toggle:SetPoint("RIGHT", row.frame, "RIGHT", -ROW_TEXT_RIGHT_INSET, 0)
        row.toggle:SetSize(ROW_TOGGLE_SIZE + 4, ROW_TOGGLE_SIZE + 4)
    end

    local hasToggle = row.toggleable == true and row.toggle ~= nil
    local labelRightTarget = hasToggle and row.toggle or row.frame
    local labelRightPoint = hasToggle and "LEFT" or "RIGHT"
    local labelRightOffset = hasToggle and -ROW_LABEL_GAP or -ROW_TEXT_RIGHT_INSET

    local label = row.label
    label:ClearAllPoints()
    label:SetPoint("LEFT", row.icon or row.frame, row.icon and "RIGHT" or "LEFT", row.icon and ROW_LABEL_GAP or indent, 0)
    label:SetPoint("RIGHT", labelRightTarget, labelRightPoint, labelRightOffset, 0)
end

local function ApplyRowVisualState(row)
    if not row then
        return
    end

    local node = row.node
    local clickable = row.clickable == true
    local selected = clickable and IsActiveNode(node, row.state) or false
    local hovered = clickable and row.hovered == true

    if row.background then
        if selected then
            SetTextureColor(row.background, ROW_COLORS.fillSelected)
            row.background:Show()
        elseif hovered then
            SetTextureColor(row.background, ROW_COLORS.fillHover)
            row.background:Show()
        else
            row.background:Hide()
        end
    end

    if row.accent then
        if selected then
            SetTextureColor(row.accent, ResolveColor("accent", ROW_COLORS.accent))
            row.accent:Show()
        else
            row.accent:Hide()
        end
    end

    if row.icon then
        row.icon:SetText(ResolveTypeIcon(node))
        local iconColor = IsContainerNode(node)
            and ResolveColor("statusMuted", ROW_COLORS.iconContainer)
            or ResolveColor("description", ROW_COLORS.icon)
        row.icon:SetTextColor(iconColor[1] or 1, iconColor[2] or 1, iconColor[3] or 1, iconColor[4] or 1)
    end

    if row.expander then
        if row.expandable then
            row.expander:Show()
            if row.expanderBackground then
                local fill = selected and ROW_COLORS.chevronFillSelected or ROW_COLORS.chevronFill
                SetTextureColor(row.expanderBackground, fill)
                row.expanderBackground:Show()
            end
            if row.expanderGlyph then
                row.expanderGlyph:SetText(row.expanded and "-" or "+")
                local color = ResolveColor("description", ROW_COLORS.chevron)
                row.expanderGlyph:SetTextColor(color[1] or 1, color[2] or 1, color[3] or 1, color[4] or 1)
            end
        else
            row.expander:Hide()
            if row.expanderBackground then
                row.expanderBackground:Hide()
            end
            if row.expanderGlyph then
                row.expanderGlyph:SetText("")
            end
        end
    end

    if row.toggle then
        local toggleable = IsToggleableNode(node)
        if toggleable then
            row.toggle:Show()
            local toggleColor = node and node.enabled == false
                and ResolveColor("statusMuted", ROW_COLORS.toggleOff)
                or ResolveColor("accent", ROW_COLORS.toggleOn)
            local alpha = node and node.enabled == false and 0.56 or 0.94
            SetTextureColor(row.toggleGlyph, {
                toggleColor[1] or 1,
                toggleColor[2] or 1,
                toggleColor[3] or 1,
                alpha,
            })
            if row.toggleGlyph then
                row.toggleGlyph:SetSize(node and node.enabled == false and 5 or 7, node and node.enabled == false and 5 or 7)
            end
        else
            row.toggle:Hide()
        end
    end

    if row.label then
        local size = node and node.type == "unit" and 12 or 11
        if ApplyTextStyle then
            ApplyTextStyle(row.label, "label", size, 1)
        elseif row.label.SetFont then
            row.label:SetFont(STANDARD_TEXT_FONT, size, "")
        end
        row.label:SetText(FormatNodeLabel(node))
        row.label:SetJustifyH("LEFT")
        if row.label.SetJustifyV then
            row.label:SetJustifyV("MIDDLE")
        end
        if row.label.SetWordWrap then
            row.label:SetWordWrap(false)
        end
        if row.label.SetMaxLines then
            row.label:SetMaxLines(1)
        end

        local color = ResolveRowTextColor(node, selected, clickable)
        row.label:SetTextColor(color[1] or 1, color[2] or 1, color[3] or 1, color[4] or 1)
    end
end

local function RegisterCompositionTreeRowWidget()
    if AceGUI:GetWidgetVersion(ROW_WIDGET_TYPE) and AceGUI:GetWidgetVersion(ROW_WIDGET_TYPE) >= ROW_WIDGET_VERSION then
        return
    end

    local methods = {}

    function methods:OnAcquire()
        self:SetFullWidth(true)
        self:SetHeight(ROW_HEIGHT_STATIC)
        self.node = nil
        self.depth = 0
        self.state = nil
        self.clickable = false
        self.hovered = false
        self.toggleable = false
        self.expandable = false
        self.expanded = false
        if self.events then
            self.events.OnClick = nil
            self.events.OnEnter = nil
            self.events.OnLeave = nil
            self.events.OnToggle = nil
            self.events.OnExpandToggle = nil
        end
        if self.frame then
            self.frame:EnableMouse(false)
            self.frame:Show()
        end
        if self.label then
            self.label:SetText("")
            ApplyRowGeometry(self)
        end
        ApplyRowVisualState(self)
    end

    function methods:OnRelease()
        self.node = nil
        self.depth = 0
        self.state = nil
        self.clickable = false
        self.hovered = false
        self.toggleable = false
        self.expandable = false
        self.expanded = false
        if self.events then
            self.events.OnClick = nil
            self.events.OnEnter = nil
            self.events.OnLeave = nil
            self.events.OnToggle = nil
            self.events.OnExpandToggle = nil
        end
        if self.frame then
            self.frame:EnableMouse(false)
        end
        if self.label then
            self.label:SetText("")
        end
        if self.background then
            self.background:Hide()
        end
        if self.accent then
            self.accent:Hide()
        end
        if self.toggle then
            self.toggle:Hide()
        end
        if self.expander then
            self.expander:Hide()
        end
        if self.expanderGlyph then
            self.expanderGlyph:SetText("")
        end
        if self.expanderBackground then
            self.expanderBackground:Hide()
        end
    end

    function methods:SetRow(node, depth, state, clickable, expandable, expanded)
        self.node = node
        self.depth = math.max(0, tonumber(depth) or 0)
        self.state = state
        self.clickable = clickable == true
        self.hovered = false
        self.toggleable = IsToggleableNode(node)
        self.expandable = expandable == true
        self.expanded = expanded == true
        self:SetHeight(self.clickable and ROW_HEIGHT_CLICKABLE or ROW_HEIGHT_STATIC)
        if self.frame then
            self.frame:EnableMouse(self.clickable or self.toggleable or self.expandable)
        end
        if self.expander then
            if self.expandable then
                self.expander:Show()
            else
                self.expander:Hide()
            end
        end
        if self.toggle then
            if self.toggleable then
                self.toggle:Show()
            else
                self.toggle:Hide()
            end
        end
        ApplyRowGeometry(self)
        ApplyRowVisualState(self)
    end

    function methods:RefreshState(state)
        self.state = state
        ApplyRowVisualState(self)
    end

    local function Constructor()
        local frame = CreateFrame("Button", nil, UIParent)
        frame:Hide()
        frame:SetHeight(ROW_HEIGHT_STATIC)

        local background = frame:CreateTexture(nil, "BACKGROUND")
        background:SetPoint("TOPLEFT", frame, "TOPLEFT", 2, -1)
        background:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -2, 1)
        background:Hide()

        local accent = frame:CreateTexture(nil, "ARTWORK")
        accent:SetPoint("TOPLEFT", frame, "TOPLEFT", 3, -3)
        accent:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 3, 3)
        accent:SetWidth(ROW_ACCENT_WIDTH)
        accent:Hide()

        local label = frame:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
        label:SetJustifyH("LEFT")
        label:SetJustifyV("MIDDLE")
        label:SetWordWrap(false)
        if label.SetMaxLines then
            label:SetMaxLines(1)
        end

        local expander = CreateFrame("Button", nil, frame)
        expander:Hide()
        expander:EnableMouse(true)

        local expanderBackground = expander:CreateTexture(nil, "BACKGROUND")
        expanderBackground:SetTexture("Interface\\Buttons\\WHITE8X8")
        expanderBackground:Hide()

        local expanderGlyph = expander:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
        expanderGlyph:SetPoint("CENTER")
        expanderGlyph:SetJustifyH("CENTER")
        expanderGlyph:SetJustifyV("MIDDLE")
        expanderGlyph:SetText("")

        local icon = frame:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
        icon:SetJustifyH("CENTER")
        icon:SetJustifyV("MIDDLE")
        icon:SetWordWrap(false)
        if icon.SetMaxLines then
            icon:SetMaxLines(1)
        end

        local toggle = CreateFrame("Button", nil, frame)
        toggle:Hide()
        toggle:EnableMouse(true)

        local toggleGlyph = toggle:CreateTexture(nil, "ARTWORK")
        toggleGlyph:SetPoint("CENTER")
        toggleGlyph:SetTexture("Interface\\Buttons\\WHITE8X8")

        local widget = {
            frame = frame,
            type = ROW_WIDGET_TYPE,
            background = background,
            accent = accent,
            expander = expander,
            expanderBackground = expanderBackground,
            expanderGlyph = expanderGlyph,
            icon = icon,
            label = label,
            toggle = toggle,
            toggleGlyph = toggleGlyph,
        }
        frame.obj = widget
        expander.obj = widget
        toggle.obj = widget

        frame:SetScript("OnEnter", function(self)
            local obj = self.obj
            if obj and obj.clickable then
                obj.hovered = true
                ApplyRowVisualState(obj)
                obj:Fire("OnEnter")
            end
        end)
        frame:SetScript("OnLeave", function(self)
            local obj = self.obj
            if obj and obj.clickable then
                obj.hovered = false
                ApplyRowVisualState(obj)
                obj:Fire("OnLeave")
            end
        end)
        frame:SetScript("OnMouseDown", function(self, button)
            local obj = self.obj
            if obj and obj.clickable then
                obj:Fire("OnClick", button)
            end
            AceGUI:ClearFocus()
        end)
        expander:SetScript("OnMouseDown", function(self, button)
            local obj = self.obj
            if not (obj and obj.expandable and obj.node) then
                return
            end
            obj:Fire("OnExpandToggle", obj.node, obj.expanded ~= true, button)
            AceGUI:ClearFocus()
        end)
        toggle:SetScript("OnMouseDown", function(self, button)
            local obj = self.obj
            if not (obj and obj.toggleable and obj.node) then
                return
            end
            local nextEnabled = obj.node.enabled == false
            local result = obj:Fire("OnToggle", obj.node, nextEnabled, button)
            if not (result and result.ok == false) then
                obj.node.enabled = nextEnabled
                ApplyRowVisualState(obj)
            end
            AceGUI:ClearFocus()
        end)
        frame:SetScript("OnHide", function(self)
            local obj = self.obj
            if obj then
                obj.hovered = false
            end
        end)

        for method, func in pairs(methods) do
            widget[method] = func
        end

        return AceGUI:RegisterAsWidget(widget)
    end

    AceGUI:RegisterWidgetType(ROW_WIDGET_TYPE, Constructor, ROW_WIDGET_VERSION)
end

RegisterCompositionTreeRowWidget()

local function RefreshRowStates(rows, state)
    if type(rows) ~= "table" then
        return
    end

    for _, row in ipairs(rows) do
        if row.widget and row.widget.RefreshState then
            row.widget:RefreshState(state)
        end
    end
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
    if changeKind == "sameUnitObject" then
        RefreshRowStates(options and options._focalPointRows, state)
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

local function EnsureActiveSelectionVisible(scroll, state, options)
    local uiState = options and options._focalPointTreeUiState or nil
    local visibleRows = options and options.visibleRows or nil
    local selectedRowIndex = FindVisibleRowIndex(visibleRows, state)
    local rowCount = type(visibleRows) == "table" and #visibleRows or tonumber(options and options._focalPointRowCount) or 0
    local scrollHeight = options and options._focalPointScrollHeight or nil
    local scrollStatus = uiState and uiState.scroll or nil
    AdjustScrollForSelection(scrollStatus, selectedRowIndex, rowCount, scrollHeight, GetTreeScrollValue(scroll, scrollStatus))
    if scrollStatus and scrollStatus.scrollvalue then
        ApplyTreeScrollValue(scroll, scrollStatus.scrollvalue)
    end
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
    local currentRow = currentIndex and visibleRows[currentIndex] or nil
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

local function EnableTreeKeyboard(scroll, state, options)
    local frame = scroll and (scroll.scrollframe or scroll.frame)
    if not (frame and frame.SetScript and frame.EnableKeyboard) then
        return
    end

    frame:EnableKeyboard(false)
    if frame.SetPropagateKeyboardInput then
        frame:SetPropagateKeyboardInput(true)
    end
    frame:SetScript("OnEnter", function(self)
        self:EnableKeyboard(true)
        if self.SetPropagateKeyboardInput then
            self:SetPropagateKeyboardInput(true)
        end
    end)
    frame:SetScript("OnLeave", function(self)
        if self.SetPropagateKeyboardInput then
            self:SetPropagateKeyboardInput(true)
        end
        self:EnableKeyboard(false)
    end)
    frame:SetScript("OnKeyDown", function(self, key)
        local handled = HandleTreeKey(key, state, options)
        if self.SetPropagateKeyboardInput then
            self:SetPropagateKeyboardInput(not handled)
        end
    end)
end

local function AddNodeRow(container, node, depth, state, options)
    local clickable = IsClickableNode(node) and type(options) == "table" and type(options.onSelect) == "function"
    local toggleable = IsToggleableNode(node) and type(options) == "table" and type(options.onToggle) == "function"
    local expandable = HasChildren(node)
    local expanded = IsExpanded(node, options and options.expanded)
    local rowWidget = AceGUI:Create(ROW_WIDGET_TYPE)
    rowWidget:SetFullWidth(true)
    if rowWidget.SetRow then
        rowWidget:SetRow(node, depth, state, clickable, expandable, expanded)
    end
    if type(options) == "table" and type(options._focalPointRows) == "table" then
        options._visibleRowIndex = (tonumber(options._visibleRowIndex) or 0) + 1
        if type(options.visibleRows) == "table" then
            options.visibleRows[#options.visibleRows + 1] = {
                node = node,
                depth = depth,
            }
        end
        if type(options._rowIndexByNodeId) == "table" and type(node.id) == "string" then
            options._rowIndexByNodeId[node.id] = options._visibleRowIndex
        end
        options._focalPointRows[#options._focalPointRows + 1] = {
            widget = rowWidget,
            node = node,
            depth = depth,
            clickable = clickable,
        }
    end
    if clickable and rowWidget.SetCallback then
        rowWidget:SetCallback("OnClick", function()
            SelectTreeNode(node, state, options)
        end)
    end
    if toggleable and rowWidget.SetCallback then
        rowWidget:SetCallback("OnToggle", function(_, _, toggleNode, nextEnabled)
            return options.onToggle(toggleNode, nextEnabled)
        end)
    end
    if expandable and rowWidget.SetCallback then
        rowWidget:SetCallback("OnExpandToggle", function(_, _, expandNode, nextExpanded)
            local expansionState = options and options.expanded
            if type(expansionState) == "table" and type(expandNode) == "table" and type(expandNode.id) == "string" then
                expansionState[expandNode.id] = nextExpanded == true
                if type(options.rebuild) == "function" then
                    options.rebuild()
                end
            end
        end)
    end
    container:AddChild(rowWidget)
end

local function RenderNode(container, node, depth, state, options)
    if type(node) ~= "table" then
        return
    end

    AddNodeRow(container, node, depth, state, options)
    if IsExpanded(node, options and options.expanded) then
        for _, child in ipairs(node.children or {}) do
            RenderNode(container, child, (tonumber(depth) or 0) + 1, state, options)
        end
    end
end

function View.Build(container, state, options)
    local perf = ns and ns.SelectionPerfDebug
    local perfStart = perf and perf.Begin and perf:Begin("CompositionTreeView.Build")

    if not container then
        if perf and perf.End then
            perf:End("CompositionTreeView.Build", perfStart)
        end
        return false
    end
    options = options or {}
    options._focalPointRows = {}
    options._rowIndexByNodeId = {}
    options._visibleRowIndex = 0
    options.visibleRows = {}

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
        if perf and perf.End then
            perf:End("CompositionTreeView.Build", perfStart)
        end
        return false
    end

    local uiState = GetTreeUiState(unit)
    options.expanded = uiState.expanded
    RevealActiveNode(tree, state, options.expanded)
    options.rebuild = function()
        if container.ReleaseChildren then
            container:ReleaseChildren()
        end
        View.Build(container, state, options)
    end

    local rowCount = CountVisibleRows(tree, options.expanded)
    local scrollHeight = ResolveTreeScrollHeight(rowCount, options)
    local scroll = AceGUI:Create("ScrollFrame")
    scroll:SetFullWidth(true)
    scroll:SetHeight(scrollHeight)
    if scroll.SetLayout then
        scroll:SetLayout("Flow")
    end
    if scroll.SetStatusTable then
        scroll:SetStatusTable(uiState.scroll)
    end
    options._focalPointScroll = scroll
    options._focalPointTreeUiState = uiState
    options._focalPointRowCount = rowCount
    options._focalPointScrollHeight = scrollHeight
    EnableTreeKeyboard(scroll, state, options)
    container:AddChild(scroll)

    RenderNode(scroll, tree, 0, state, options)
    local selectedRowIndex
    for _, row in ipairs(options._focalPointRows) do
        if IsActiveNode(row.node, state) then
            selectedRowIndex = options._rowIndexByNodeId[row.node.id]
            break
        end
    end
    AdjustScrollForSelection(uiState.scroll, selectedRowIndex, rowCount, scrollHeight)
    if uiState.scroll and uiState.scroll.scrollvalue then
        ApplyTreeScrollValue(scroll, uiState.scroll.scrollvalue)
    end
    View._keyboardBindingContext = {
        scroll = scroll,
        state = state,
        options = options,
    }
    if perf and perf.End then
        perf:End("CompositionTreeView.Build", perfStart)
    end
    return true
end

function View.RefreshKeyboardBinding()
    local context = View._keyboardBindingContext
    local scroll = context and context.scroll or nil
    local state = context and context.state or nil
    local options = context and context.options or nil
    if not (scroll and state and options) then
        return false
    end

    EnableTreeKeyboard(scroll, state, options)
    EnsureActiveSelectionVisible(scroll, state, options)
    return true
end
return View
