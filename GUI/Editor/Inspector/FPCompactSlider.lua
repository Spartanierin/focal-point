local AceGUI = LibStub and LibStub("AceGUI-3.0", true)
local Type, Version = "FPCompactSlider", 1
if not AceGUI or (AceGUI:GetWidgetVersion(Type) or 0) >= Version then return end

local TRACK_HEIGHT, INPUT_HEIGHT = 15, 14
local HEIGHT = TRACK_HEIGHT + INPUT_HEIGHT
local INPUT_WIDTH = 65

local function NormalizeValue(self, value)
    value = tonumber(value)
    if not value or value ~= value or value == math.huge or value == -math.huge then return nil end
    value = math.max(self.min, math.min(self.max, value))
    value = self.min + math.floor((value - self.min) / self.step + 0.5) * self.step
    return math.max(self.min, math.min(self.max, value))
end

local function UpdateText(self)
    self.editbox:SetText(string.format("%.12g", self.value))
end

local function CommitValue(self, value, clearFocus)
    if self.disabled or self.isQueuedForRelease then return end
    value = NormalizeValue(self, value)
    local changed = value ~= nil and value ~= self.value
    self:SetValue(value or self.value)
    if clearFocus then self:ClearFocus() end
    -- The mutation may release/rebuild this widget: no accesses after Fire.
    if changed then self:Fire("OnValueChanged", value) end
end

local methods = {}

function methods:SetValue(value)
    value = NormalizeValue(self, value)
    if value == nil then return end
    self.value = value
    self.settingValue = true
    self.slider:SetValue(value)
    self.settingValue = nil
    UpdateText(self)
end

function methods:GetValue()
    return self.value
end

function methods:SetSliderValues(minValue, maxValue, step)
    self.min, self.max = minValue or 0, maxValue or 100
    self.step = step and step > 0 and step or 1
    -- Match the standard slider's plain numeric range labels (no percent mode).
    self.lowtext:SetText(self.min)
    self.hightext:SetText(self.max)
    self.settingValue = true
    self.slider:SetMinMaxValues(self.min, self.max)
    self.slider:SetValueStep(self.step)
    self.settingValue = nil
    self:SetValue(self.value or self.min)
end

function methods:ClearFocus()
    if AceGUI.FocusedWidget == self then AceGUI.FocusedWidget = nil end
    self.editbox:ClearFocus()
    UpdateText(self)
end

function methods:SetDisabled(disabled)
    self.disabled = disabled == true
    self.slider:EnableMouse(not self.disabled)
    self.editbox:EnableMouse(not self.disabled)
    self.editbox:EnableKeyboard(not self.disabled)
    self.slider:GetThumbTexture():SetAlpha(self.disabled and 0.45 or 1)
    local tone = self.disabled and 0.5 or 1
    self.editbox:SetTextColor(tone, tone, tone)
    self.lowtext:SetTextColor(tone, tone, tone)
    self.hightext:SetTextColor(tone, tone, tone)
    if self.disabled then
        self.slider:EnableMouseWheel(false)
        self:ClearFocus()
    end
    self.editbox:SetBackdropBorderColor(0.3, 0.3, 0.3, 0.8)
end

function methods:OnAcquire()
    self:SetWidth(200)
    self:SetHeight(HEIGHT)
    self:SetSliderValues(0, 100, 1)
    self:SetValue(0)
    self:ClearFocus()
    self:SetDisabled(false)
    self.slider:EnableMouseWheel(false)
end

function methods:OnRelease()
    self:SetDisabled(true)
    self:SetSliderValues(0, 100, 1)
    self:SetValue(0)
    -- AceGUI clears callbacks, userdata and host anchors when pooling.
    -- Child anchors and scripts are installed once, on construction only.
end

local function BeginInteraction(frame)
    local self = frame.obj
    if self.disabled then return end
    AceGUI:ClearFocus()
    self.slider:EnableMouseWheel(true)
end

local function Constructor()
    local frame = CreateFrame("Frame", nil, UIParent)
    frame:Hide()
    local slider = CreateFrame("Slider", nil, frame, "BackdropTemplate")
    slider:SetOrientation("HORIZONTAL")
    slider:SetPoint("TOPLEFT", frame, "TOPLEFT", 3, 0)
    slider:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -3, 0)
    slider:SetHeight(TRACK_HEIGHT)
    slider:SetHitRectInsets(0, 0, 0, 0)
    slider:SetBackdrop({
        bgFile = "Interface\\Buttons\\UI-SliderBar-Background",
        edgeFile = "Interface\\Buttons\\UI-SliderBar-Border",
        tile = true, tileSize = 8, edgeSize = 8,
        insets = { left = 3, right = 3, top = 6, bottom = 6 },
    })
    slider:SetThumbTexture("Interface\\Buttons\\UI-SliderBar-Button-Horizontal")
    slider:GetThumbTexture():SetSize(14, TRACK_HEIGHT)

    local editbox = CreateFrame("EditBox", nil, frame, "BackdropTemplate")
    editbox:SetAutoFocus(false)
    editbox:SetFontObject(GameFontHighlightSmall)
    editbox:SetJustifyH("CENTER")
    editbox:SetPoint("TOP", frame, "TOP", 0, -TRACK_HEIGHT)
    editbox:SetWidth(INPUT_WIDTH)
    editbox:SetHeight(INPUT_HEIGHT)
    editbox:SetBackdrop({
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\ChatFrame\\ChatFrameBackground",
        tile = true, edgeSize = 1, tileSize = 5,
    })
    editbox:SetBackdropColor(0, 0, 0, 0.5)

    -- At 77px: 5px Min + 1px gap + 65px input + 1px gap + 5px Max.
    -- The lower line uses the host width; the track keeps its existing inset.
    local lowtext = frame:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    lowtext:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, -TRACK_HEIGHT)
    lowtext:SetPoint("TOPRIGHT", editbox, "TOPLEFT", -1, 0)
    lowtext:SetHeight(INPUT_HEIGHT)
    lowtext:SetJustifyH("LEFT")
    lowtext:SetJustifyV("MIDDLE")
    lowtext:SetWordWrap(false)

    local hightext = frame:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    hightext:SetPoint("TOPLEFT", editbox, "TOPRIGHT", 1, 0)
    hightext:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, -TRACK_HEIGHT)
    hightext:SetHeight(INPUT_HEIGHT)
    hightext:SetJustifyH("RIGHT")
    hightext:SetJustifyV("MIDDLE")
    hightext:SetWordWrap(false)

    local widget = { type = Type, frame = frame, slider = slider, editbox = editbox,
        lowtext = lowtext, hightext = hightext }
    for name, method in pairs(methods) do widget[name] = method end
    frame.obj, slider.obj, editbox.obj = widget, widget, widget

    frame:EnableMouse(true)
    frame:SetScript("OnMouseDown", BeginInteraction)
    frame:SetScript("OnHide", function()
        widget:ClearFocus()
        slider:EnableMouseWheel(false)
    end)
    slider:SetScript("OnMouseDown", BeginInteraction)
    slider:SetScript("OnValueChanged", function(_, value)
        if not widget.settingValue then CommitValue(widget, value) end
    end)
    slider:SetScript("OnMouseWheel", function(_, delta)
        if delta ~= 0 then CommitValue(widget, widget.value + (delta > 0 and widget.step or -widget.step)) end
    end)
    slider:SetScript("OnMouseUp", function()
        if not widget.disabled then widget:Fire("OnMouseUp", widget.value) end
    end)
    slider:SetScript("OnEnter", function() widget:Fire("OnEnter") end)
    slider:SetScript("OnLeave", function() widget:Fire("OnLeave") end)
    editbox:SetScript("OnEditFocusGained", function()
        if widget.disabled then widget:ClearFocus() else AceGUI:SetFocus(widget) end
    end)
    editbox:SetScript("OnEditFocusLost", function()
        if AceGUI.FocusedWidget == widget then AceGUI.FocusedWidget = nil end
        UpdateText(widget)
    end)
    editbox:SetScript("OnEnterPressed", function() CommitValue(widget, editbox:GetText(), true) end)
    editbox:SetScript("OnEscapePressed", function() widget:ClearFocus() end)
    editbox:SetScript("OnEnter", function()
        if not widget.disabled then editbox:SetBackdropBorderColor(0.5, 0.5, 0.5, 1) end
    end)
    editbox:SetScript("OnLeave", function() editbox:SetBackdropBorderColor(0.3, 0.3, 0.3, 0.8) end)

    return AceGUI:RegisterAsWidget(widget)
end

AceGUI:RegisterWidgetType(Type, Constructor, Version)
