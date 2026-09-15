-- Run from the repository root: lua54 Tests/FPCompactSlider.lua
-- Real AceGUI registration, callbacks and pooling; native WoW frames simulated.
local errors, created = {}, 0
function geterrorhandler() return function(err) errors[#errors + 1] = err end end
table.wipe = function(t) for key in pairs(t) do t[key] = nil end end
unpack = table.unpack

local native = {}
function native:SetScript(event, fn) self.scripts[event] = fn end
function native:Run(event, ...) if self.scripts[event] then self.scripts[event](self, ...) end end
function native:SetParent(parent) self.parent = parent end
function native:Show() self.shown = true end
function native:Hide()
    local shown = self.shown
    self.shown = false
    if shown then self:Run("OnHide") end
end
function native:IsShown() return self.shown end
native.IsVisible = native.IsShown
function native:SetWidth(width) self.nativeWidth = width end
function native:SetHeight(height) self.nativeHeight = height end
function native:SetSize(width, height) self:SetWidth(width); self:SetHeight(height) end
function native:GetHeight() return self.nativeHeight end
function native:SetPoint(point, relative, relativePoint, x, y)
    self.points[point] = { relative = relative, relativePoint = relativePoint, x = x or 0, y = y or 0 }
end
function native:ClearAllPoints() self.points = {} end
local function anchorX(point)
    local relative = point.relative
    local x = relative:GetLeft()
    if point.relativePoint:find("RIGHT") then x = x + relative:GetWidth()
    elseif not point.relativePoint:find("LEFT") then x = x + relative:GetWidth() / 2 end
    return x + point.x
end
function native:GetLeft()
    local left = self.points.TOPLEFT
    if left then return anchorX(left) end
    local center = self.points.TOP
    return center and (anchorX(center) - self:GetWidth() / 2) or 0
end
function native:GetWidth()
    local left, right = self.points.TOPLEFT, self.points.TOPRIGHT
    if left and right then return anchorX(right) - anchorX(left) end
    return self.nativeWidth
end
function native:GetTop()
    local point = self.points.TOPLEFT or self.points.TOP
    return point and (point.relative:GetTop() + point.y) or 0
end
function native:CreateFontString(_, _, font)
    local text = CreateFrame("FontString", nil, self)
    text:SetFontObject(font)
    return text
end
function native:SetValue(value)
    value = math.max(self.min or 0, math.min(self.max or 100, value))
    local previous = self.value
    self.value = value
    if previous ~= value then self:Run("OnValueChanged", value) end
end
function native:SetMinMaxValues(low, high)
    self.min, self.max = low, high
    if self.value then self:SetValue(self.value) end
end
function native:SetText(text) self.text = tostring(text) end
function native:GetText() return self.text end
function native:SetFocus() self.focus = true; self:Run("OnEditFocusGained") end
function native:ClearFocus()
    local focused = self.focus
    self.focus = false
    if focused then self:Run("OnEditFocusLost") end
end
function native:SetThumbTexture() self.thumb = CreateFrame("Texture", nil, self) end
function native:GetThumbTexture() return self.thumb end
for _, method in ipairs({"EnableMouse", "EnableKeyboard", "EnableMouseWheel", "SetValueStep",
    "SetOrientation", "SetHitRectInsets", "SetBackdrop", "SetBackdropColor", "SetBackdropBorderColor",
    "SetAutoFocus", "SetFontObject", "SetJustifyH", "SetJustifyV", "SetWordWrap", "SetTextColor", "SetAlpha"}) do
    native[method] = function(self, ...) self["last" .. method] = {...} end
end
function CreateFrame(kind, name, parent)
    created = created + 1
    return setmetatable({ kind = kind, parent = parent, scripts = {}, points = {}, shown = true }, {__index = native})
end
UIParent = CreateFrame("Frame")
GameFontHighlightSmall = {}
local library = {}
LibStub = setmetatable({NewLibrary = function() return library end}, {__call = function() return library end})
assert(loadfile("Libraries/Ace3/AceGUI-3.0/AceGUI-3.0.lua"))()
assert(loadfile("GUI/Editor/Inspector/FPCompactSlider.lua"))()
local ace = LibStub("AceGUI-3.0")
local widget = ace:Create("FPCompactSlider")
local count = created

local function equal(actual, expected)
    assert(actual == expected, tostring(actual) .. " ~= " .. tostring(expected))
end
local function input(value, event)
    widget.editbox:SetFocus()
    widget.editbox:SetText(value)
    widget.editbox:Run(event or "OnEnterPressed")
end

for cycle = 1, 50 do
    equal(widget.frame:GetHeight(), 29)
    equal(widget:GetValue(), 0)
    equal(widget.min, 0); equal(widget.max, 100); equal(widget.step, 1)
    equal(widget.lowtext:GetText(), "0"); equal(widget.hightext:GetText(), "100")
    assert(not widget.disabled and not widget.editbox.focus and not ace.FocusedWidget)
    assert(next(widget.events) == nil and next(widget.userdata) == nil)
    assert(not widget.slider.lastEnableMouseWheel[1])
    for _, width in ipairs({77, 97}) do
        widget:SetWidth(width)
        equal(widget.slider:GetWidth(), width - 6)
        equal(widget.editbox:GetWidth(), 65)
        equal(widget.editbox:GetLeft(), (width - 65) / 2)
        equal(widget.lowtext:GetLeft(), 0)
        equal(widget.lowtext:GetWidth(), (width - 65) / 2 - 1)
        equal(widget.hightext:GetWidth(), (width - 65) / 2 - 1)
        equal(widget.lowtext:GetLeft() + widget.lowtext:GetWidth() + 1, widget.editbox:GetLeft())
        equal(widget.editbox:GetLeft() + widget.editbox:GetWidth() + 1, widget.hightext:GetLeft())
        equal(widget.hightext:GetLeft() + widget.hightext:GetWidth(), width)
        for _, text in ipairs({widget.lowtext, widget.hightext}) do
            equal(text:GetHeight(), 14)
            equal(widget.frame:GetTop() - text:GetTop() + text:GetHeight(), 29)
            equal(text.lastSetFontObject[1], "GameFontHighlightSmall")
        end
        equal(widget.slider:GetHeight(), 15)
        equal(widget.editbox:GetHeight(), 14)
        equal(widget.frame:GetTop() - widget.editbox:GetTop() + widget.editbox:GetHeight(), 29)
        equal(widget.slider:GetThumbTexture():GetWidth(), 20)
        equal(widget.slider:GetThumbTexture():GetHeight(), 26)
    end
    widget:SetFullWidth(true)
    assert(widget:IsFullWidth())
    widget.frame:Show()
    for _, step in ipairs({1, 5, 0.1, 0.05, 0.01}) do
        local low, value, high = -800, -270, 800
        if step < 1 then low, value, high = 0.1, 0.9, 1 end
        widget:SetSliderValues(low, high, step)
        widget:SetValue(value)
        equal(widget.lowtext:GetText(), tostring(low))
        equal(widget.hightext:GetText(), tostring(high))
        equal(tonumber(widget.editbox:GetText()), value)
    end
    widget:SetSliderValues(-800, 800, 1)
    local changes = 0
    widget:SetCallback("OnValueChanged", function(self, event, value)
        changes = changes + 1
        equal(event, "OnValueChanged"); equal(value, self:GetValue())
        self:SetValue(value) -- external synchronization must remain silent
    end)
    widget:SetValue(10); equal(changes, 0)
    widget.slider:SetValue(-12.6); equal(widget:GetValue(), -13); equal(changes, 1)
    widget.slider:SetValue(-12.9); equal(changes, 1)
    widget.slider:Run("OnMouseDown")
    assert(widget.slider.lastEnableMouseWheel[1])
    widget.slider:Run("OnMouseWheel", 1); equal(widget:GetValue(), -12)
    widget.slider:Run("OnMouseWheel", -1); equal(widget:GetValue(), -13)
    input("900"); equal(widget:GetValue(), 800)
    input("-900"); equal(widget:GetValue(), -800)
    input("25"); equal(widget:GetValue(), 25)
    local before = changes
    input("invalid"); equal(widget:GetValue(), 25); equal(changes, before)
    input("1e999"); equal(widget:GetValue(), 25); equal(changes, before)
    input("60", "OnEscapePressed"); equal(widget.editbox:GetText(), "25"); equal(changes, before)
    widget.editbox:SetFocus(); widget.editbox:SetText("70"); widget.editbox:ClearFocus()
    equal(widget.editbox:GetText(), "25"); equal(changes, before)
    widget:SetDisabled(true)
    equal(widget.lowtext.lastSetTextColor[1], 0.5)
    equal(widget.hightext.lastSetTextColor[1], 0.5)
    widget.slider:Run("OnMouseWheel", 1)
    input("100"); equal(widget:GetValue(), 25); equal(changes, before)
    assert(not widget.editbox.focus and not widget.slider.lastEnableMouse[1])
    assert(not widget.editbox.lastEnableKeyboard[1])
    widget:SetDisabled(false)
    equal(widget.lowtext.lastSetTextColor[1], 1)
    widget:SetSliderValues(-1, 1, 0.25)
    input("-0.62"); equal(widget:GetValue(), -0.5)
    widget:SetCallback("OnValueChanged", function(self) self:SetValue(0.75) end)
    input("0"); equal(widget:GetValue(), 0.75); equal(widget.editbox:GetText(), "0.75")
    widget:SetUserData("oldScope", cycle)
    widget.editbox:SetFocus(); widget.editbox:SetText("pending")
    local old = widget
    ace:Release(widget)
    assert(not widget.editbox.focus and not ace.FocusedWidget)
    widget = ace:Create("FPCompactSlider")
    equal(widget, old); equal(created, count)
end
-- A synchronous Inspector rebuild during the mutation must be safe.
widget:SetCallback("OnValueChanged", function(self)
    ace:Release(self)
    widget = ace:Create("FPCompactSlider")
    widget:SetValue(42)
end)
input("3")
equal(widget:GetValue(), 42); equal(widget.editbox:GetText(), "42")
equal(created, count)
assert(#errors == 0, table.concat(errors, "\n"))
print("PASS: FPCompactSlider Min/Edit/Max at 77/97px, range formatting/reset, geometry, input and 50 AceGUI pooling cycles")
