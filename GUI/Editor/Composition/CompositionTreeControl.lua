local _, ns = ...

local Control = {}
ns.GUI.Editor.Composition.TreeControl = Control

Control.ROW_HEIGHT = 16
local freeControls = {}
local methods = {}
local ApplyTextStyle = ns.GUI.Helpers.FormWidgets.ApplyTextStyle
local activeControl = nil

local ScrollTraceState = {
    onValueChangedCount = 0,
    programmaticSetValueCount = 0,
    dragSampleCount = 0,
    dragSamples = {},
}

local MAX_DRAG_TRACE_SAMPLES = 12

local function GetRegionTraceValues(region)
    if not region then
        return nil, nil, nil
    end
    return region.GetTop and region:GetTop() or nil,
        region.GetBottom and region:GetBottom() or nil,
        region.GetHeight and region:GetHeight() or nil
end

local function AppendNativeDragSample(sample)
    local samples = ScrollTraceState.dragSamples
    if #samples >= MAX_DRAG_TRACE_SAMPLES then
        table.remove(samples, 1)
    end
    ScrollTraceState.dragSampleCount = ScrollTraceState.dragSampleCount + 1
    sample.index = ScrollTraceState.dragSampleCount
    samples[#samples + 1] = sample
end

local TREE_SURFACE_COLOR = { 0.05, 0.055, 0.06, 0.92 }
local TREE_TEXT_DESCRIPTION = { 0.68, 0.70, 0.75, 1.00 }
local TREE_TEXT_DISABLED = { 0.43, 0.45, 0.49, 1.00 }

local ICON_PATH_BY_NODE_TYPE = {
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

local ICON_TINT_BY_NODE_TYPE = {
    unit = { 0.93, 0.79, 0.49 },
    healthbar = { 0.43, 0.70, 0.90 },
    normalAbsorbBar = { 0.43, 0.70, 0.90 },
    healingAbsorbBar = { 0.43, 0.70, 0.90 },
    powerbar = { 0.43, 0.70, 0.90 },
    classPowerBar = { 0.43, 0.70, 0.90 },
    alternativePowerBar = { 0.43, 0.70, 0.90 },
    castbar = { 0.43, 0.70, 0.90 },
    textElement = { 0.95, 0.89, 0.72 },
    buffs = { 0.67, 0.48, 0.84 },
    debuffs = { 0.67, 0.48, 0.84 },
    decorationElement = { 0.70, 0.65, 0.82 },
}

local INDICATOR_ICON_TINT = { 0.91, 0.55, 0.32 }
local PORTRAIT_ICON_TINT = { 0.80, 0.65, 0.40 }
local DEFAULT_ICON_TINT = { 0.72, 0.76, 0.82 }

local function ResolveNodeIcon(node)
    if type(node) ~= "table" then
        return nil
    end
    if node.type == "indicatorElement" then
        local target = node.inspectorTarget
        if type(target) == "table" and target.indicatorKey == "Portrait" then
            return "Interface\\AddOns\\FocalPoint\\Media\\Icons\\Runtime\\fp_icon_portrait.png", PORTRAIT_ICON_TINT
        end
        return "Interface\\AddOns\\FocalPoint\\Media\\Icons\\Runtime\\fp_icon_indicator.png", INDICATOR_ICON_TINT
    end
    return ICON_PATH_BY_NODE_TYPE[node.type], ICON_TINT_BY_NODE_TYPE[node.type]
end

local function SetIconColor(icon, tint, brightness, alpha)
    local color = tint or DEFAULT_ICON_TINT
    icon:SetVertexColor(
        math.min(1, color[1] * brightness),
        math.min(1, color[2] * brightness),
        math.min(1, color[3] * brightness),
        alpha
    )
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

local function StyleLabel(label, size)
    if ApplyTextStyle then
        ApplyTextStyle(label, "label", size, 1)
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
    if item.selected then
        row.background:SetColorTexture(0.11, 0.18, 0.27, 0.94)
        row.background:Show()
    elseif row.hovered then
        row.background:SetColorTexture(0.07, 0.10, 0.15, 0.72)
        row.background:Show()
    else
        row.background:Hide()
    end
    if item.selected then
        row.label:SetTextColor(0.88, 0.91, 0.95, 1)
    elseif item.node.enabled == false then
        row.label:SetTextColor(unpack(TREE_TEXT_DISABLED))
    else
        row.label:SetTextColor(unpack(TREE_TEXT_DESCRIPTION))
    end
    if item.selected then
        SetIconColor(row.icon, row.iconTint, 1.18, 1.00)
    elseif row.hovered then
        SetIconColor(row.icon, row.iconTint, 1.04, 0.90)
    elseif item.node.enabled == false then
        row.icon:SetVertexColor(0.42, 0.44, 0.48, 0.42)
    else
        SetIconColor(row.icon, row.iconTint, 0.90, 0.76)
    end
    row.disclosureGlyph:SetText(item.expanded and "-" or ">")
    row.toggleGlyph:SetColorTexture(0.49, 0.54, 0.61, item.node.enabled == false and 0.14 or 0.38)
end

function methods:SetKeyboardActive(active)
    self.frame:EnableKeyboard(active and self.callbacks ~= nil)
    self.frame:SetPropagateKeyboardInput(true)
end

local function BindRowScripts(control, row)
    local function Enter()
        row.hovered = true
        Paint(row)
        control:SetKeyboardActive(true)
    end
    local function Leave()
        row.hovered = false
        Paint(row)
        if not MouseIsOver(control.frame) then control:SetKeyboardActive(false) end
    end
    for _, frame in ipairs({ row.frame, row.disclosure, row.toggle }) do
        frame:SetScript("OnEnter", Enter)
        frame:SetScript("OnLeave", Leave)
    end
    row.frame:SetScript("OnMouseDown", function(_, button)
        if button ~= "LeftButton" or not row.item or not row.item.clickable then return end
        local callback = control.callbacks and control.callbacks.onSelect
        if callback then callback(row.item.node) end
    end)
    row.disclosure:SetScript("OnMouseDown", function(_, button)
        if button ~= "LeftButton" or not row.item or not row.item.expandable then return end
        local callback = control.callbacks and control.callbacks.onExpand
        if callback then callback(row.item.node, not row.item.expanded) end
    end)
    row.toggle:SetScript("OnMouseDown", function(_, button)
        if button ~= "LeftButton" or not row.item or not row.item.toggleable then return end
        local callback = control.callbacks and control.callbacks.onToggle
        if callback then callback(row.item.node, row.item.node.enabled == false) end
    end)
end

local function UnbindRow(row)
    row.item = nil
    row.hovered = false
    for _, frame in ipairs({ row.frame, row.disclosure, row.toggle }) do
        frame:Hide()
        frame:EnableMouse(false)
        frame:SetScript("OnEnter", nil)
        frame:SetScript("OnLeave", nil)
        frame:SetScript("OnMouseDown", nil)
    end
    row.frame:ClearAllPoints()
    row.label:SetText("")
    row.icon:SetTexture(nil)
    row.icon:Hide()
    row.iconTint = nil
    row.background:Hide()
end

function methods:AcquireRow(index)
    local row = self.rows[index]
    if row then return row end
    local frame = CreateFrame("Button", nil, self.content)
    frame:SetHeight(Control.ROW_HEIGHT)
    local background = frame:CreateTexture(nil, "BACKGROUND")
    background:SetAllPoints(frame)
    local label = frame:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    StyleLabel(label, 11)
    local icon = frame:CreateTexture(nil, "ARTWORK", nil, 1)
    icon:SetSize(14, 14)
    local disclosure = CreateFrame("Button", nil, frame)
    disclosure:SetSize(12, Control.ROW_HEIGHT)
    local disclosureGlyph = disclosure:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    disclosureGlyph:SetPoint("CENTER")
    disclosureGlyph:SetTextColor(0.58, 0.63, 0.70, 1)
    local toggle = CreateFrame("Button", nil, frame)
    toggle:SetSize(20, Control.ROW_HEIGHT)
    toggle:SetPoint("RIGHT", frame, "RIGHT", -3, 0)
    local toggleGlyph = toggle:CreateTexture(nil, "ARTWORK")
    toggleGlyph:SetSize(8, 8)
    toggleGlyph:SetPoint("CENTER")
    row = {
        frame = frame, background = background, label = label, icon = icon,
        disclosure = disclosure, disclosureGlyph = disclosureGlyph,
        toggle = toggle, toggleGlyph = toggleGlyph,
    }
    self.rows[index] = row
    return row
end

function methods:SetScroll(value)
    local offset = ClampScrollOffset(value, self.maxScroll)
    self.offset = offset
    if self.scrollStatus then self.scrollStatus.scrollvalue = offset end
    self.scroll:SetVerticalScroll(offset)
    local sliderValue = ScrollOffsetToSliderValue(offset, self.maxScroll)
    if self.scrollbar:GetValue() ~= sliderValue then
        ScrollTraceState.programmaticSetValueCount = ScrollTraceState.programmaticSetValueCount + 1
        self._settingScrollbarValue = true
        self.scrollbar:SetValue(sliderValue)
        self._settingScrollbarValue = nil
    end
end

function methods:StopThumbDrag()
    self._thumbDrag = nil
    if self.thumbDragHandle then
        self.thumbDragHandle:SetScript("OnUpdate", nil)
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

    local contentHeight = (self.count or 0) * Control.ROW_HEIGHT
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
    self:SetScroll(self.scrollStatus and self.scrollStatus.scrollvalue or 0)
    return true
end

function methods:SetRows(items)
    self.generation = (self.generation or 0) + 1
    self.count = #items
    for index, item in ipairs(items) do
        local row = self:AcquireRow(index)
        row.item = item
        row.hovered = false
        row.frame:ClearAllPoints()
        row.frame:SetPoint("TOPLEFT", self.content, "TOPLEFT", 0, -(index - 1) * Control.ROW_HEIGHT)
        row.frame:SetPoint("TOPRIGHT", self.content, "TOPRIGHT", 0, -(index - 1) * Control.ROW_HEIGHT)
        row.disclosure:ClearAllPoints()
        row.disclosure:SetPoint("LEFT", row.frame, "LEFT", 3 + item.depth * 10, 0)
        row.icon:ClearAllPoints()
        row.icon:SetPoint("LEFT", row.disclosure, "RIGHT", 2, 0)
        local iconPath, iconTint = ResolveNodeIcon(item.node)
        row.icon:SetTexture(iconPath)
        row.icon:SetShown(iconPath ~= nil)
        row.iconTint = iconTint
        row.label:ClearAllPoints()
        row.label:SetPoint("LEFT", row.icon, "RIGHT", 3, 0)
        row.label:SetPoint("RIGHT", item.toggleable and row.toggle or row.frame,
            item.toggleable and "LEFT" or "RIGHT", -4, 0)
        row.label:SetText(item.label)
        StyleLabel(row.label, item.node.type == "unit" and 12 or 11)
        BindRowScripts(self, row)
        row.frame:EnableMouse(true)
        row.disclosure:EnableMouse(item.expandable)
        row.disclosure:SetShown(item.expandable)
        row.toggle:EnableMouse(item.toggleable)
        row.toggle:SetShown(item.toggleable)
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
    local top = (index - 1) * Control.ROW_HEIGHT
    local bottom = top + Control.ROW_HEIGHT
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
    if activeControl == self then activeControl = nil end
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
    self.background:SetColorTexture(unpack(TREE_SURFACE_COLOR))
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
    self.scrollbar:SetWidth(7)
    self.scrollbar:SetOrientation("VERTICAL")
    self.scrollbar:SetMinMaxValues(0, 0)
    self.scrollbar:SetValueStep(1)
    self.scrollbar:SetObeyStepOnDrag(false)
    local thumb = self.scrollbar:CreateTexture(nil, "ARTWORK")
    thumb:SetColorTexture(0.45, 0.50, 0.58, 0.55)
    thumb:SetSize(5, 20)
    self.scrollbar:SetThumbTexture(thumb)
    self.thumbDragHandle = CreateFrame("Button", nil, self.scrollbar)
    self.thumbDragHandle:SetAllPoints(thumb)
    self.thumbDragHandle:SetFrameLevel(self.scrollbar:GetFrameLevel() + 1)
    self.thumbDragHandle:EnableMouse(true)
    self.thumbDragHandle:RegisterForDrag("LeftButton")
    self.thumbDragHandle:SetScript("OnMouseDown", function(_, button)
        if button == "LeftButton" then
            self:BeginThumbDrag()
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
    self.scrollbar:SetScript("OnValueChanged", function(_, value)
        ScrollTraceState.onValueChangedCount = ScrollTraceState.onValueChangedCount + 1
        local sample = nil
        if not self._settingScrollbarValue then
            local _, cursorY = GetCursorPosition()
            local thumbTop, thumbBottom = GetRegionTraceValues(self.scrollbar:GetThumbTexture())
            sample = {
                cursorY = cursorY,
                value = value,
                sliderValue = self.scrollbar:GetValue(),
                thumbTop = thumbTop,
                thumbBottom = thumbBottom,
                beforeOffset = self.offset,
                beforeVerticalScroll = self.scroll:GetVerticalScroll(),
            }
        end
        self:SetScroll(SliderValueToScrollOffset(value, self.maxScroll))
        if sample then
            sample.afterOffset = self.offset
            sample.afterVerticalScroll = self.scroll:GetVerticalScroll()
            AppendNativeDragSample(sample)
        end
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
        if not MouseIsOver(self.frame) then self:SetKeyboardActive(false) end
    end)
    self.scrollbar:SetScript("OnEnter", function() self:SetKeyboardActive(true) end)
    self.scrollbar:SetScript("OnLeave", function()
        if not MouseIsOver(self.frame) then self:SetKeyboardActive(false) end
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
    activeControl = self
    ScrollTraceState.onValueChangedCount = 0
    ScrollTraceState.programmaticSetValueCount = 0
    ScrollTraceState.dragSampleCount = 0
    ScrollTraceState.dragSamples = {}
    self.scrollStatus = scrollStatus
    self.callbacks = callbacks
    self.frame:SetParent(parent)
    self.frame:SetFrameLevel(parent:GetFrameLevel() + 1)
    self.frame:SetAllPoints(parent)
    self:SetKeyboardActive(false)
    self.frame:Show()
    return self
end

function Control.GetScrollTraceSnapshot()
    local self = activeControl
    if not self then
        return nil
    end

    local scrollbar = self.scrollbar
    local minimum, maximum = nil, nil
    if scrollbar and scrollbar.GetMinMaxValues then
        minimum, maximum = scrollbar:GetMinMaxValues()
    end
    local thumb = scrollbar and scrollbar.GetThumbTexture and scrollbar:GetThumbTexture() or nil
    local thumbTop, thumbBottom, thumbHeight = GetRegionTraceValues(thumb)
    local sliderTop, sliderBottom, sliderHeight = GetRegionTraceValues(scrollbar)

    return {
        scrollbarExists = scrollbar ~= nil,
        scrollbarShown = scrollbar and scrollbar.IsShown and scrollbar:IsShown() or false,
        scrollbarVisible = scrollbar and scrollbar.IsVisible and scrollbar:IsVisible() or false,
        sliderMinimum = minimum,
        sliderMaximum = maximum,
        sliderValue = scrollbar and scrollbar.GetValue and scrollbar:GetValue() or nil,
        verticalScroll = self.scroll and self.scroll.GetVerticalScroll and self.scroll:GetVerticalScroll() or nil,
        offset = self.offset,
        maxScroll = self.maxScroll,
        thumbTop = thumbTop,
        thumbBottom = thumbBottom,
        thumbHeight = thumbHeight,
        sliderTop = sliderTop,
        sliderBottom = sliderBottom,
        sliderHeight = sliderHeight,
        onValueChangedCount = ScrollTraceState.onValueChangedCount,
        programmaticSetValueCount = ScrollTraceState.programmaticSetValueCount,
    }
end

function Control.ResetScrollDragTrace()
    ScrollTraceState.dragSampleCount = 0
    ScrollTraceState.dragSamples = {}
end

function Control.GetScrollDragTraceSamples()
    local samples = {}
    for index, sample in ipairs(ScrollTraceState.dragSamples) do
        samples[index] = sample
    end
    return samples
end

return Control
