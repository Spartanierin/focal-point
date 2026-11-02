local _, ns = ...

local Control = {}
ns.GUI.Editor.Composition.TreeControl = Control

Control.ROW_HEIGHT = 34 -- Includes the 4px gap between cards; scrolling uses this stride.
Control.ROOT_ROW_HEIGHT = 44 -- 36px Unit header plus 8px separation from its cards.
local CARD_HEIGHT = 30
local ROW_INDENT = 16
local ROW_FONT_SIZE = 13
local freeControls = {}
local methods = {}
local ApplyTextStyle = ns.GUI.Helpers.FormWidgets.ApplyTextStyle

local ICON_PATH_BY_NODE_TYPE = {
    segmentedBar = "Interface\\AddOns\\FocalPoint\\Media\\Icons\\Runtime\\fp_icon_bar.png",
    unit = "Interface\\AddOns\\FocalPoint\\Media\\Icons\\Runtime\\fp_icon_unit.png",
    healthbar = "Interface\\AddOns\\FocalPoint\\Media\\Icons\\Runtime\\fp_icon_bar.png",
    normalAbsorbBar = "Interface\\AddOns\\FocalPoint\\Media\\Icons\\Runtime\\fp_icon_bar.png",
    healingAbsorbBar = "Interface\\AddOns\\FocalPoint\\Media\\Icons\\Runtime\\fp_icon_bar.png",
    powerbar = "Interface\\AddOns\\FocalPoint\\Media\\Icons\\Runtime\\fp_icon_bar.png",
    classPowerBar = "Interface\\AddOns\\FocalPoint\\Media\\Icons\\Runtime\\fp_icon_bar.png",
    alternativePowerBar = "Interface\\AddOns\\FocalPoint\\Media\\Icons\\Runtime\\fp_icon_bar.png",
    castbar = "Interface\\AddOns\\FocalPoint\\Media\\Icons\\Runtime\\fp_icon_bar.png",
    textElement = "Interface\\AddOns\\FocalPoint\\Media\\Icons\\Runtime\\fp_icon_text.png",
    buffs = "Interface\\AddOns\\FocalPoint\\Media\\Icons\\Runtime\\fp_icon_aura.png",
    debuffs = "Interface\\AddOns\\FocalPoint\\Media\\Icons\\Runtime\\fp_icon_aura.png",
    decorationElement = "Interface\\AddOns\\FocalPoint\\Media\\Icons\\Runtime\\fp_icon_decoration.png",
}

local ICON_ROLE_BY_NODE_TYPE = {
    segmentedBar = "bar",
    unit = "unit",
    healthbar = "bar",
    normalAbsorbBar = "bar",
    healingAbsorbBar = "bar",
    powerbar = "bar",
    classPowerBar = "bar",
    alternativePowerBar = "bar",
    castbar = "bar",
    textElement = "text",
    buffs = "aura",
    debuffs = "aura",
    decorationElement = "decoration",
}

local function GetCompositionTreePresentation()
    local palette = ns.GUI.Skins.GetFormPalette()
    return palette.CompositionTree
end

local function ResolveNodeIcon(node, presentation)
    if type(node) ~= "table" then
        return nil
    end
    if node.type == "indicatorElement" then
        local target = node.inspectorTarget
        if type(target) == "table" and target.indicatorKey == "Portrait" then
            return "Interface\\AddOns\\FocalPoint\\Media\\Icons\\Runtime\\fp_icon_portrait.png", presentation.icon.portrait
        end
        return "Interface\\AddOns\\FocalPoint\\Media\\Icons\\Runtime\\fp_icon_indicator.png", presentation.icon.indicator
    end
    return ICON_PATH_BY_NODE_TYPE[node.type], presentation.icon[ICON_ROLE_BY_NODE_TYPE[node.type]]
end

local function SetIconColor(icon, color, brightness, alpha)
    icon:SetVertexColor(
        math.min(1, color[1] * brightness),
        math.min(1, color[2] * brightness),
        math.min(1, color[3] * brightness),
        alpha
    )
end

local function GetActiveUnitMarkerColor()
    local componentStyles = ns.GUI
        and ns.GUI.Layouts
        and ns.GUI.Layouts.FormElements
        and ns.GUI.Layouts.FormElements.ComponentStyles
    local activeState = componentStyles
        and componentStyles.Navigation
        and componentStyles.Navigation.UnitNavigatorItem
        and componentStyles.Navigation.UnitNavigatorItem.states
        and componentStyles.Navigation.UnitNavigatorItem.states.active
    return activeState and activeState.accent or nil
end

local function ClampScrollOffset(value, maxScroll)
    maxScroll = math.max(0, tonumber(maxScroll) or 0)
    return math.max(0, math.min(maxScroll, tonumber(value) or 0))
end

-- Native slider values increase from the visual top to bottom, matching ScrollFrame offsets.
local function SliderValueToScrollOffset(value, maxScroll)
    return ClampScrollOffset(value, maxScroll)
end

local function ScrollOffsetToSliderValue(offset, maxScroll)
    return ClampScrollOffset(offset, maxScroll)
end

local function RowTop(control, index)
    local first = control.rows[1]
    local rootExtra = index > 1 and first and first.item and first.item.node.type == "unit"
        and (Control.ROOT_ROW_HEIGHT - Control.ROW_HEIGHT) or 0
    return (index - 1) * Control.ROW_HEIGHT + rootExtra
end

local function StyleLabel(label, size, role)
    if ApplyTextStyle then
        ApplyTextStyle(label, role or "label", size, 1)
    else
        label:SetFont(STANDARD_TEXT_FONT, size, "")
    end
    label:SetWordWrap(false)
    label:SetMaxLines(1)
    label:SetJustifyH("LEFT")
end

local function Paint(row)
    local item = row.item
    if not item then return end
    local presentation = GetCompositionTreePresentation()
    local unitHeader = item.node.type == "unit"
    if item.selected then
        row.background:SetColorTexture(unpack(presentation.rowSelected))
        row.background:Show()
    elseif row.hovered then
        row.background:SetColorTexture(unpack(presentation.rowHover))
        row.background:Show()
    else
        row.background:SetColorTexture(unpack(unitHeader and ns.GUI.Skins.GetFormPalette().Chrome.panelHeader or presentation.surface))
        row.background:Show()
    end
    local subtle = item.depth >= 2 and not item.selected and not row.hovered
    row.background:SetAlpha(subtle and .65 or 1)
    local border = (item.selected or row.hovered) and presentation.text.selected
        or unitHeader and (GetActiveUnitMarkerColor() or presentation.text.selected)
        or ns.GUI.Skins.GetFormPalette().Chrome.sectionBorder
    for _, edge in ipairs(row.edges) do
        edge:SetColorTexture(unpack(border))
        edge:SetAlpha(subtle and .65 or 1)
        edge:Show()
    end
    if item.node.enabled == false then
        row.label:SetTextColor(unpack(presentation.text.disabled))
    elseif item.depth == 1 then
        local color = NORMAL_FONT_COLOR or ns.GUI.Helpers.TextStyles.Get("strongHeading")
        row.label:SetTextColor(color.r, color.g, color.b)
    else
        row.label:SetTextColor(1, 1, 1, 1)
    end
    if item.selected then
        SetIconColor(row.icon, row.iconTint or presentation.icon.fallback, presentation.icon.selectedBrightness, presentation.icon.selectedAlpha)
    elseif row.hovered then
        SetIconColor(row.icon, row.iconTint or presentation.icon.fallback, presentation.icon.hoverBrightness, presentation.icon.hoverAlpha)
    elseif item.node.enabled == false then
        row.icon:SetVertexColor(unpack(presentation.icon.disabled))
    else
        SetIconColor(row.icon, row.iconTint or presentation.icon.fallback, presentation.icon.normalBrightness, presentation.icon.normalAlpha)
    end
    -- Existing AceGUI submenu arrow, rotated through texture coordinates when expanded.
    if item.expanded then
        row.disclosureGlyph:SetTexCoord(0, 1, 1, 1, 0, 0, 1, 0)
    else
        row.disclosureGlyph:SetTexCoord(0, 1, 0, 1)
    end
    row.toggle:SetChecked(item.node.enabled ~= false)
    row.toggleCheck:SetVertexColor(1, 1, 1, 1) -- Preserve Blizzard's original yellow check texture.
end

function methods:SetKeyboardActive(active)
    self.frame:EnableKeyboard(active and self.callbacks ~= nil)
    self.frame:SetPropagateKeyboardInput(true)
end

local function IsMouseOverFrame(frame)
    if frame and frame.IsMouseOver then
        return frame:IsMouseOver()
    end
    if MouseIsOver then
        return MouseIsOver(frame) == true
    end
    return false
end

-- Reuse MinimalScrollBar art on the existing Slider, without its ScrollBox controller.
local function PaintThumb(control, suffix)
    control.thumbTop:SetAtlas("minimal-scrollbar-small-thumb-top" .. suffix, true)
    control.thumbTop:SetWidth(8)
    control.thumbMiddle:SetAtlas("minimal-scrollbar-small-thumb-middle" .. suffix)
    control.thumbBottom:SetAtlas("minimal-scrollbar-small-thumb-bottom" .. suffix, true)
    control.thumbBottom:SetWidth(8)
end

local function HideRowTooltip(row)
    if not GameTooltip then return end
    for _, frame in ipairs({row.frame, row.disclosure, row.toggle, row.add, row.remove}) do
        if GameTooltip:IsOwned(frame) then GameTooltip:Hide(); return end
    end
end

local function BindRowScripts(control, row)
    local node, generation = row.item.node, control.generation
    local function IsCurrentRow()
        return control.callbacks ~= nil and control.generation == generation and row.item and row.item.node == node
    end
    local function Enter(frame)
        if not row.item then return end
        if frame == row.add or frame == row.remove then
            frame:SetAlpha(InCombatLockdown and InCombatLockdown() and .4 or 1)
        end
        row.hovered = true
        Paint(row)
        control:SetKeyboardActive(true)
        if GameTooltip then
            GameTooltip:SetOwner(frame, "ANCHOR_RIGHT")
            GameTooltip:ClearLines()
            GameTooltip:AddLine(row.item.label, 1, 1, 1, true)
            if frame == row.frame and row.item.clickable then
                GameTooltip:AddLine((ns.L or {}).COMPONENT_EDIT_TOOLTIP or "", 1, 1, 1, true)
            elseif frame == row.toggle then
                local labels = ns.L or {}
                GameTooltip:AddLine(row.item.node.enabled == false and (labels.OPTION_OFF or "Off") or (labels.OPTION_ON or "On"), 1, 1, 1)
            elseif frame == row.add or frame == row.remove then
                local labels = ns.L or {}
                local addLabel = row.item.node.type == "unit" and labels.COMPONENT_ADD or labels.COMPONENT_ADD_CONTEXT
                GameTooltip:AddLine(frame == row.add and (addLabel or "Add Component…")
                    or (labels.INFO_COMMON_REMOVE or "Remove"), 1, 1, 1)
            end
            GameTooltip:Show()
        end
    end
    local function Leave()
        HideRowTooltip(row)
        row.hovered = false
        Paint(row)
        if not IsMouseOverFrame(control.frame) then control:SetKeyboardActive(false) end
    end
    for _, frame in ipairs({ row.frame, row.disclosure, row.toggle, row.add, row.remove }) do
        local disabled = frame == row.toggle and not row.item.toggleable or frame == row.remove and not row.item.removable
        frame:SetScript("OnEnter", not disabled and Enter or nil)
        frame:SetScript("OnLeave", not disabled and Leave or nil)
        frame:SetScript("OnHide", function() HideRowTooltip(row) end)
    end
    row.frame:SetScript("OnMouseDown", function(_, button)
        if button ~= "LeftButton" or not row.item or not row.item.clickable then return end
        local callback = control.callbacks and control.callbacks.onSelect
        if callback then callback(row.item.node) end
    end)
    row.disclosure:SetScript("OnMouseDown", function(_, button)
        if button ~= "LeftButton" or not IsCurrentRow() or not row.item.expandable then return end
        local callback = control.callbacks and control.callbacks.onExpand
        if callback then callback(row.item.node, not row.item.expanded) end
    end)
    row.toggle:SetScript("OnClick", row.item.toggleable and function(_, button)
        if button ~= "LeftButton" or not IsCurrentRow() or not row.item.toggleable then return end
        local callback = control.callbacks and control.callbacks.onToggle
        if callback then callback(row.item.node, row.item.node.enabled == false) end
        Paint(row) -- Reassert the canonical value even when the guarded mutation was rejected.
    end or nil)
    row.add:SetScript("OnMouseDown", function(_, button)
        if button ~= "LeftButton" or not IsCurrentRow() or not row.item.addable then return end
        local callback = control.callbacks.onAdd
        if callback then callback(node, IsCurrentRow) end
    end)
    row.remove:SetScript("OnMouseDown", row.item.removable and function(_, button)
        if button ~= "LeftButton" or not IsCurrentRow() or not row.item.removable then return end
        local callback = control.callbacks.onRemove
        if callback then callback(node, IsCurrentRow) end
    end or nil)
end

local function UnbindRow(row)
    HideRowTooltip(row)
    row.item = nil
    row.hovered = false
    for _, frame in ipairs({ row.frame, row.disclosure, row.toggle, row.add, row.remove }) do
        frame:Hide()
        frame:EnableMouse(false)
        frame:SetScript("OnEnter", nil)
        frame:SetScript("OnLeave", nil)
        frame:SetScript("OnMouseDown", nil)
        frame:SetScript("OnClick", nil)
        frame:SetScript("OnHide", nil)
    end
    row.frame:ClearAllPoints()
    row.label:SetText("")
    row.icon:SetTexture(nil)
    row.icon:Hide()
    row.iconTint = nil
    row.textRole = nil
    row.background:Hide()
    for _, edge in ipairs(row.edges) do edge:Hide() end
end

function methods:AcquireRow(index)
    local row = self.rows[index]
    if row then return row end
    local frame = CreateFrame("Button", nil, self.content)
    frame:SetHeight(CARD_HEIGHT)
    local background = frame:CreateTexture(nil, "BACKGROUND")
    background:SetAllPoints(frame)
    local edges = {}
    for _, side in ipairs({"TOP", "BOTTOM", "LEFT", "RIGHT"}) do
        local edge = frame:CreateTexture(nil, "BORDER")
        if side == "TOP" or side == "BOTTOM" then
            edge:SetHeight(1)
            edge:SetPoint(side.."LEFT", frame, side.."LEFT")
            edge:SetPoint(side.."RIGHT", frame, side.."RIGHT")
        else
            edge:SetWidth(1)
            edge:SetPoint("TOP"..side, frame, "TOP"..side)
            edge:SetPoint("BOTTOM"..side, frame, "BOTTOM"..side)
        end
        edges[#edges+1] = edge
    end
    local label = frame:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    StyleLabel(label, ROW_FONT_SIZE)
    local icon = frame:CreateTexture(nil, "ARTWORK", nil, 1)
    icon:SetSize(16, 16)
    local disclosure = CreateFrame("Button", nil, frame)
    disclosure:SetSize(26, 26)
    local disclosureGlyph = disclosure:CreateTexture(nil, "ARTWORK")
    disclosureGlyph:SetTexture(130940) -- Existing AceGUI ChatFrameExpandArrow.
    disclosureGlyph:SetSize(18, 18)
    disclosureGlyph:SetPoint("CENTER")
    disclosureGlyph:SetDesaturated(true)
    disclosureGlyph:SetVertexColor(1, .82, 0, 1)
    local toggle = CreateFrame("CheckButton", nil, frame, "UICheckButtonArtTemplate")
    toggle:SetSize(26, 26)
    toggle:SetPoint("RIGHT", frame, "RIGHT", -6, 0)
    toggle:RegisterForClicks("LeftButtonDown") -- One native click, routed to the existing toggle dispatch.
    local toggleGlyph, toggleCheck = toggle:GetNormalTexture(), toggle:GetCheckedTexture()
    local function ActionButton()
        local button = CreateFrame("Button", nil, frame)
        button:SetSize(28, 26)
        button:SetHighlightTexture(130753, "ADD")
        button:SetPushedTexture(130753)
        local border = button:CreateTexture(nil, "BACKGROUND")
        border:SetAllPoints(button)
        border:SetColorTexture(unpack(ns.GUI.Skins.GetFormPalette().Chrome.sectionBorder))
        local fill = button:CreateTexture(nil, "BORDER")
        fill:SetPoint("TOPLEFT", button, "TOPLEFT", 1, -1)
        fill:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -1, 1)
        fill:SetColorTexture(unpack(ns.GUI.Skins.GetFormPalette().Chrome.panelHeader))
        return button
    end
    local add, remove = ActionButton(), ActionButton()
    local addGlyph = add:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    StyleLabel(addGlyph, 26, "strongHeading")
    addGlyph:SetJustifyH("CENTER")
    addGlyph:SetText("+")
    addGlyph:SetTextColor(1, .82, 0, 1)
    addGlyph:SetPoint("CENTER", add, "CENTER", 0, 1)
    local removeGlyph = remove:CreateTexture(nil, "OVERLAY")
    removeGlyph:SetAtlas("common-icon-delete")
    removeGlyph:SetDesaturated(true)
    removeGlyph:SetVertexColor(1, .08, .08, 1)
    removeGlyph:SetSize(20, 20)
    removeGlyph:SetPoint("CENTER")
    row = {
        frame = frame, background = background, edges = edges, label = label, icon = icon,
        disclosure = disclosure, disclosureGlyph = disclosureGlyph,
        toggle = toggle, toggleGlyph = toggleGlyph, toggleCheck = toggleCheck,
        add = add, remove = remove, addGlyph = addGlyph, removeGlyph = removeGlyph,
    }
    self.rows[index] = row
    return row
end

function methods:SetScroll(value, forceProjection)
    local offset = ClampScrollOffset(value, self.maxScroll)
    self.offset = offset
    if self.scrollStatus then self.scrollStatus.scrollvalue = offset end
    self.scroll:SetVerticalScroll(offset)
    local sliderValue = ScrollOffsetToSliderValue(offset, self.maxScroll)
    if forceProjection or self.scrollbar:GetValue() ~= sliderValue then
        self.scrollbar:SetValue(sliderValue)
    end
end

function methods:StopThumbDrag()
    self._thumbDrag = nil
    if self.thumbDragHandle then
        self.thumbDragHandle:SetScript("OnUpdate", nil)
        PaintThumb(self, IsMouseOverFrame(self.thumbDragHandle) and "-over" or "")
    end
end

function methods:BeginThumbDrag()
    local thumb = self.scrollbar:GetThumbTexture()
    local sliderHeight = tonumber(self.scrollbar:GetHeight()) or 0
    local thumbHeight = thumb and (tonumber(thumb:GetHeight()) or 0) or 0
    local travel = sliderHeight - thumbHeight
    local scale = self.scrollbar:GetEffectiveScale()
    local _, cursorY = GetCursorPosition()
    if not cursorY or travel <= 0 or not scale or scale <= 0 then
        return
    end

    self._thumbDrag = {
        startCursorY = cursorY / scale,
        startOffset = self.offset or 0,
        maxScroll = self.maxScroll or 0,
        travel = travel,
        scale = scale,
    }
    self.thumbDragHandle:SetScript("OnUpdate", function()
        local drag = self._thumbDrag
        if not drag then return end
        local _, currentCursorY = GetCursorPosition()
        if not currentCursorY then return end
        local pixelDeltaDown = drag.startCursorY - (currentCursorY / drag.scale)
        local scrollDelta = pixelDeltaDown * (drag.maxScroll / drag.travel)
        self:SetScroll(drag.startOffset + scrollDelta)
    end)
end

function methods:Layout()
    local height = tonumber(self.frame:GetHeight()) or 0
    local width = tonumber(self.frame:GetWidth()) or 0
    if height <= 0 or width <= 0 then
        -- The AceGUI host has not received its final geometry yet. OnSizeChanged retries this path.
        self.scrollbar:Hide()
        return false
    end

    local contentHeight = RowTop(self, (self.count or 0) + 1)
    self.maxScroll = math.max(0, contentHeight - height)
    local hasScroll = self.maxScroll > 0
    self.scroll:ClearAllPoints()
    self.scroll:SetPoint("TOPLEFT", self.frame, "TOPLEFT")
    self.scroll:SetPoint("BOTTOMRIGHT", self.frame, "BOTTOMRIGHT", hasScroll and -10 or 0, 0)
    self.content:SetWidth(math.max(1, width - (hasScroll and 10 or 0)))
    self.content:SetHeight(math.max(1, contentHeight))
    self.scrollbar:SetMinMaxValues(0, self.maxScroll)
    self.scrollbar:SetShown(hasScroll)
    local thumbHeight = math.max(16, height * math.min(1, height / math.max(1, contentHeight)))
    self.scrollbar:GetThumbTexture():SetHeight(thumbHeight)
    if not hasScroll then self._scrollbarProjectionInitialized = false end
    local forceProjection = hasScroll and not self._scrollbarProjectionInitialized
    self:SetScroll(self.scrollStatus and self.scrollStatus.scrollvalue or 0, forceProjection)
    if hasScroll then self._scrollbarProjectionInitialized = true end
    return true
end

function methods:SetRows(items)
    self.generation = (self.generation or 0) + 1
    self.count = #items
    for index, item in ipairs(items) do
        local row = self:AcquireRow(index)
        HideRowTooltip(row)
        row.item = item
        row.textRole = item.node.type == "unit" and "identity" or "label"
        row.hovered = false
        row.frame:SetHeight(item.node.type == "unit" and 36 or CARD_HEIGHT)
        row.frame:ClearAllPoints()
        row.frame:SetPoint("TOPLEFT", self.content, "TOPLEFT", math.max(0, item.depth - 1) * ROW_INDENT, -RowTop(self, index))
        row.frame:SetPoint("TOPRIGHT", self.content, "TOPRIGHT", 0, -RowTop(self, index))
        row.disclosure:ClearAllPoints()
        row.disclosure:SetPoint("LEFT", row.frame, "LEFT", 0, 0)
        row.icon:ClearAllPoints()
        row.icon:SetPoint("LEFT", row.disclosure, "RIGHT", 0, 0)
        local iconPath, iconTint = ResolveNodeIcon(item.node, GetCompositionTreePresentation())
        row.icon:SetTexture(iconPath)
        row.icon:SetShown(iconPath ~= nil)
        row.iconTint = iconTint
        row.label:ClearAllPoints()
        row.label:SetPoint("LEFT", row.icon, "RIGHT", 3, 0)
        local right, rightPoint = row.toggle, "LEFT"
        row.remove:ClearAllPoints()
        row.remove:SetPoint("RIGHT", right, rightPoint, -4, 0)
        right, rightPoint = row.remove, "LEFT"
        row.add:ClearAllPoints()
        row.add:SetPoint("RIGHT", right, rightPoint, -4, 0)
        if item.addable then right, rightPoint = row.add, "LEFT" end
        row.label:SetPoint("RIGHT", right, rightPoint, -4, 0)
        row.label:SetText(item.label)
        StyleLabel(row.label, item.node.type == "unit" and 16 or ROW_FONT_SIZE, row.textRole)
        BindRowScripts(self, row)
        row.frame:EnableMouse(true)
        row.disclosure:EnableMouse(item.expandable)
        row.disclosure:SetShown(item.expandable)
        row.toggle:EnableMouse(true) -- Disabled cells still consume their own hit zone.
        if item.toggleable then row.toggle:Enable() else row.toggle:Disable() end
        row.toggle:SetAlpha(item.toggleable and 1 or .4)
        row.toggle:Show()
        local unlocked = not (InCombatLockdown and InCombatLockdown())
        row.add:EnableMouse(item.addable)
        row.add:SetAlpha(unlocked and 1 or .4)
        row.add:SetShown(item.addable)
        row.remove:EnableMouse(true)
        if item.removable then row.remove:Enable() else row.remove:Disable() end
        row.remove:SetAlpha(item.removable and (unlocked and 1 or .4) or .35)
        row.removeGlyph:SetVertexColor(item.removable and 1 or .5, item.removable and .08 or .5, item.removable and .08 or .5, 1)
        row.remove:Show()
        Paint(row)
        row.frame:Show()
    end
    for index = #items + 1, #self.rows do UnbindRow(self.rows[index]) end
    self:Layout()
end

function methods:RefreshSelection(isSelected)
    for index = 1, self.count or 0 do
        local row = self.rows[index]
        row.item.selected = isSelected(row.item.node)
        Paint(row)
    end
end

function methods:EnsureVisible(index)
    if not index then return end
    local top = RowTop(self, index)
    local bottom = RowTop(self, index + 1)
    local offset = self.offset or 0
    if top < offset then
        self:SetScroll(top)
    elseif bottom > offset + self.frame:GetHeight() then
        self:SetScroll(bottom - self.frame:GetHeight())
    end
end

function methods:Release()
    if not self.callbacks then return end
    self:StopThumbDrag()
    self.callbacks = nil
    self.scrollStatus = nil
    self.count = 0
    self.maxScroll = 0
    self.offset = 0
    self.scrollbar:Hide()
    self.generation = (self.generation or 0) + 1
    self:SetKeyboardActive(false)
    for _, row in ipairs(self.rows) do UnbindRow(row) end
    self.frame:Hide()
    self.frame:ClearAllPoints()
    self.frame:SetParent(UIParent)
    freeControls[#freeControls + 1] = self
end

local function CreateControl()
    local self = setmetatable({ rows = {}, count = 0 }, { __index = methods })
    self.frame = CreateFrame("Frame", nil, UIParent)
    self.frame:Hide()
    self.background = self.frame:CreateTexture(nil, "BACKGROUND")
    self.background:SetAllPoints()
    self.background:SetColorTexture(unpack(GetCompositionTreePresentation().surface))
    self.background:Hide() -- Inherit the Customize host surface instead of stacking an opaque panel.
    self.frame:EnableMouse(true)
    self.frame:EnableMouseWheel(true)
    self.scroll = CreateFrame("ScrollFrame", nil, self.frame)
    self.scroll:SetPoint("TOPLEFT", self.frame, "TOPLEFT")
    self.scroll:SetPoint("BOTTOMRIGHT", self.frame, "BOTTOMRIGHT")
    self.content = CreateFrame("Frame", nil, self.scroll)
    self.content:SetPoint("TOPLEFT", self.scroll, "TOPLEFT")
    self.scroll:SetScrollChild(self.content)
    self.scrollbar = CreateFrame("Slider", nil, self.frame)
    self.scrollbar:SetPoint("TOPRIGHT", self.frame, "TOPRIGHT", -1, 0)
    self.scrollbar:SetPoint("BOTTOMRIGHT", self.frame, "BOTTOMRIGHT", -1, 0)
    self.scrollbar:SetWidth(8)
    self.scrollbar:SetOrientation("VERTICAL")
    self.scrollbar:SetMinMaxValues(0, 0)
    self.scrollbar:SetValueStep(1)
    self.scrollbar:SetObeyStepOnDrag(false)
    local trackTop = self.scrollbar:CreateTexture(nil, "BACKGROUND")
    trackTop:SetAtlas("minimal-scrollbar-track-top", true)
    trackTop:SetWidth(8)
    trackTop:SetPoint("TOP", self.scrollbar, "TOP")
    local trackBottom = self.scrollbar:CreateTexture(nil, "BACKGROUND")
    trackBottom:SetAtlas("minimal-scrollbar-track-bottom", true)
    trackBottom:SetWidth(8)
    trackBottom:SetPoint("BOTTOM", self.scrollbar, "BOTTOM")
    local trackMiddle = self.scrollbar:CreateTexture(nil, "BACKGROUND")
    trackMiddle:SetAtlas("!minimal-scrollbar-track-middle")
    trackMiddle:SetPoint("TOPLEFT", trackTop, "BOTTOMLEFT")
    trackMiddle:SetPoint("BOTTOMRIGHT", trackBottom, "TOPRIGHT")
    local thumb = self.scrollbar:CreateTexture(nil, "ARTWORK")
    thumb:SetColorTexture(0, 0, 0, 0) -- Keep the Slider's canonical drag bounds; art uses native caps/middle.
    thumb:SetSize(8, 20)
    self.scrollbar:SetThumbTexture(thumb)
    self.thumbTop = self.scrollbar:CreateTexture(nil, "OVERLAY")
    self.thumbTop:SetPoint("TOP", thumb, "TOP")
    self.thumbBottom = self.scrollbar:CreateTexture(nil, "OVERLAY")
    self.thumbBottom:SetPoint("BOTTOM", thumb, "BOTTOM")
    self.thumbMiddle = self.scrollbar:CreateTexture(nil, "ARTWORK")
    self.thumbMiddle:SetPoint("TOPLEFT", self.thumbTop, "BOTTOMLEFT")
    self.thumbMiddle:SetPoint("BOTTOMRIGHT", self.thumbBottom, "TOPRIGHT")
    PaintThumb(self, "")
    self.thumbDragHandle = CreateFrame("Button", nil, self.scrollbar)
    self.thumbDragHandle:SetAllPoints(thumb)
    self.thumbDragHandle:SetFrameLevel(self.scrollbar:GetFrameLevel() + 1)
    self.thumbDragHandle:EnableMouse(true)
    self.thumbDragHandle:RegisterForDrag("LeftButton")
    self.thumbDragHandle:SetScript("OnMouseDown", function(_, button)
        if button == "LeftButton" then
            self:BeginThumbDrag()
            PaintThumb(self, "-down")
        end
    end)
    self.thumbDragHandle:SetScript("OnMouseUp", function(_, button)
        if button == "LeftButton" then
            self:StopThumbDrag()
        end
    end)
    self.thumbDragHandle:SetScript("OnDragStop", function()
        self:StopThumbDrag()
    end)
    self.thumbDragHandle:SetScript("OnHide", function()
        self:StopThumbDrag()
    end)
    self.thumbDragHandle:SetScript("OnEnter", function()
        self:SetKeyboardActive(true)
        PaintThumb(self, self._thumbDrag and "-down" or "-over")
    end)
    self.thumbDragHandle:SetScript("OnLeave", function()
        PaintThumb(self, self._thumbDrag and "-down" or "")
        if not IsMouseOverFrame(self.frame) then self:SetKeyboardActive(false) end
    end)
    self.scrollbar:SetScript("OnValueChanged", function(_, value)
        self:SetScroll(SliderValueToScrollOffset(value, self.maxScroll))
    end)
    self.frame:SetScript("OnSizeChanged", function() self:Layout() end)
    local function OnMouseWheel(_, delta)
        self:SetScroll((self.offset or 0) - delta * Control.ROW_HEIGHT * 3)
    end
    self.frame:SetScript("OnMouseWheel", OnMouseWheel)
    self.scroll:EnableMouseWheel(true)
    self.scroll:SetScript("OnMouseWheel", OnMouseWheel)
    self.frame:SetScript("OnEnter", function() self:SetKeyboardActive(true) end)
    self.frame:SetScript("OnLeave", function()
        if not IsMouseOverFrame(self.frame) then self:SetKeyboardActive(false) end
    end)
    self.scrollbar:SetScript("OnEnter", function() self:SetKeyboardActive(true) end)
    self.scrollbar:SetScript("OnLeave", function()
        if not IsMouseOverFrame(self.frame) then self:SetKeyboardActive(false) end
    end)
    self.frame:SetScript("OnHide", function()
        self:StopThumbDrag()
        self:SetKeyboardActive(false)
    end)
    self.frame:SetScript("OnKeyDown", function(frame, key)
        local callback = self.callbacks and self.callbacks.onKey
        frame:SetPropagateKeyboardInput(not (callback and callback(key)))
    end)
    return self
end

function Control.Acquire(parent, scrollStatus, callbacks)
    local self = table.remove(freeControls) or CreateControl()
    self.scrollStatus = scrollStatus
    self.callbacks = callbacks
    self.frame:SetParent(parent)
    self.frame:SetFrameLevel(parent:GetFrameLevel() + 1)
    self.frame:SetAllPoints(parent)
    self:SetKeyboardActive(false)
    self.frame:Show()
    self._scrollbarProjectionInitialized = false
    return self
end

return Control
