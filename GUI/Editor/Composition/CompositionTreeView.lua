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
local ROW_WIDGET_VERSION = 1
local ROW_HEIGHT_CLICKABLE = 12
local ROW_HEIGHT_STATIC = 12
local ROW_INDENT = 8
local ROW_TEXT_INSET = 4
local ROW_TEXT_RIGHT_INSET = 3
local ROW_ACCENT_WIDTH = 2

local ROW_COLORS = {
    fillSelected = { 0.11, 0.12, 0.15, 0.66 },
    fillHover = { 0.09, 0.10, 0.12, 0.42 },
    accent = { 0.90, 0.78, 0.34, 0.76 },
    textRoot = { 0.93, 0.90, 0.80, 1.00 },
    textLeaf = { 0.88, 0.84, 0.72, 1.00 },
    textLeafSelected = { 0.97, 0.95, 0.91, 1.00 },
    textContainer = { 0.58, 0.61, 0.66, 1.00 },
    textDisabled = { 0.54, 0.57, 0.61, 0.95 },
    textFallback = { 0.76, 0.79, 0.84, 1.00 },
}

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
    )
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
    if node.type == "unit" then
        return state.selectedUnit == node.unit
            and (type(scope) ~= "table" or scope.sectionKey == "frame")
    end
    return type(scope) == "table"
        and scope.kind == "unit"
        and scope.sectionKey == node.inspectorTarget.sectionKey
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
    local label = row.label
    label:ClearAllPoints()
    label:SetPoint("LEFT", row.frame, "LEFT", ROW_TEXT_INSET + depth * ROW_INDENT, 0)
    label:SetPoint("RIGHT", row.frame, "RIGHT", -ROW_TEXT_RIGHT_INSET, 0)
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
        if self.events then
            self.events.OnClick = nil
            self.events.OnEnter = nil
            self.events.OnLeave = nil
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
        if self.events then
            self.events.OnClick = nil
            self.events.OnEnter = nil
            self.events.OnLeave = nil
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
    end

    function methods:SetRow(node, depth, state, clickable)
        self.node = node
        self.depth = math.max(0, tonumber(depth) or 0)
        self.state = state
        self.clickable = clickable == true
        self.hovered = false
        self:SetHeight(self.clickable and ROW_HEIGHT_CLICKABLE or ROW_HEIGHT_STATIC)
        if self.frame then
            self.frame:EnableMouse(self.clickable)
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

        local widget = {
            frame = frame,
            type = ROW_WIDGET_TYPE,
            background = background,
            accent = accent,
            label = label,
        }
        frame.obj = widget

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

local function AddNodeRow(container, node, depth, state, options)
    local clickable = IsClickableNode(node) and type(options) == "table" and type(options.onSelect) == "function"
    local rowWidget = AceGUI:Create(ROW_WIDGET_TYPE)
    rowWidget:SetFullWidth(true)
    if rowWidget.SetRow then
        rowWidget:SetRow(node, depth, state, clickable)
    end
    if type(options) == "table" and type(options._focalPointRows) == "table" then
        options._focalPointRows[#options._focalPointRows + 1] = {
            widget = rowWidget,
            node = node,
            depth = depth,
            clickable = clickable,
        }
    end
    if clickable and rowWidget.SetCallback then
        rowWidget:SetCallback("OnClick", function()
            local objectRef = BuildObjectRef(node)
            if type(ObjectSelection.SelectObject) ~= "function" then
                return
            end
            local ok, changeKind = ObjectSelection.SelectObject(objectRef)
            if ok ~= true then
                return
            end
            if changeKind == "sameUnitObject" then
                RefreshRowStates(options._focalPointRows, state)
            end
            options.onSelect(objectRef, node, changeKind)
        end)
    end
    container:AddChild(rowWidget)
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
    options = options or {}
    options._focalPointRows = {}

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
