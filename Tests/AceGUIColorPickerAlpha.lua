-- lua54 Tests/AceGUIColorPickerAlpha.lua
-- Execute the embedded widget against isolated native picker doubles.
local widgetPath = "Libraries/Ace3/AceGUI-3.0/widgets/AceGUIWidget-ColorPicker.lua"

local function Frame()
    local frame = { scripts = {} }
    return setmetatable(frame, { __index = function(_, key)
        return function(self, ...)
            if key == "CreateTexture" or key == "CreateFontString" then return Frame() end
            if key == "GetFrameLevel" then return 1 end
            if key == "SetScript" then
                local name, script = ...
                self.scripts[name] = script
            elseif key == "SetVertexColor" then
                self.color = { ... }
            end
        end
    end })
end

local function Near(actual, expected)
    assert(type(actual) == "number" and math.abs(actual - expected) < 0.000001,
        tostring(actual) .. " ~= " .. tostring(expected))
end

local function Fixture(project, modern)
    local constructor, version, events
    events = {}
    local ace = {}
    function ace:GetWidgetVersion() return version end
    function ace:RegisterWidgetType(_, build, number) constructor, version = build, number end
    function ace:RegisterAsWidget(widget)
        widget.frame.obj = widget
        function widget:SetHeight(value) self.height = value end
        function widget:SetWidth(value) self.width = value end
        function widget:Fire(event, _, _, _, alpha)
            events[#events + 1] = { event, alpha }
        end
        return widget
    end
    function ace:ClearFocus() end

    local picker = { visible = false, rgb = { 0.2, 0.3, 0.4 } }
    function picker:Hide() self.visible = false end
    function picker:Show() self.visible = true end
    function picker:IsVisible() return self.visible end
    function picker:GetColorRGB() return table.unpack(self.rgb) end
    function picker:GetColorAlpha() return self.alpha end
    function picker:SetColorRGB(r, g, b) self.rgb = { r, g, b } end
    function picker:SetFrameStrata() end
    function picker:SetFrameLevel() end
    function picker:SetClampedToScreen() end
    if modern then
        function picker:SetupColorPickerAndShow(info)
            self.info, self.alpha, self.rgb, self.visible = info, info.opacity,
                { info.r, info.g, info.b }, true
        end
    end

    local env = setmetatable({
        LibStub = function() return ace end,
        CreateFrame = function() return Frame() end,
        UIParent = Frame(),
        ColorPickerFrame = picker,
        OpacitySliderFrame = { GetValue = function() return picker.alpha end },
        WOW_PROJECT_ID = project,
        WOW_PROJECT_MAINLINE = 1,
        WOW_PROJECT_CAMELOT = 3,
    }, { __index = _G })
    assert(loadfile(widgetPath, "t", env))()
    assert(version == 29 and type(constructor) == "function")
    local widget = constructor()
    widget:OnAcquire()
    widget:SetHasAlpha(true)
    local function Open()
        widget.frame.scripts.OnClick(widget.frame)
        assert(picker:IsVisible())
        return modern and picker.info.opacity or picker.opacity
    end
    local function Preview(alpha)
        picker.alpha = alpha
        if modern then picker.info.opacityFunc() else picker.opacityFunc() end
    end
    local function Confirm(alpha)
        picker.alpha = alpha
        picker:Hide()
        if modern then picker.info.opacityFunc() else picker.opacityFunc() end
    end
    local function Cancel()
        picker:Hide()
        if modern then picker.info.cancelFunc() else picker.cancelFunc() end
    end
    return widget, events, Open, Preview, Confirm, Cancel
end

local count = 0
for _, project in ipairs({ 1, 3, 2 }) do
    -- The legacy native picker exists only on the older, inverted client.
    local modes = project == 2 and { true, false } or { true }
    for _, modern in ipairs(modes) do
        for _, initial in ipairs({ 0, 0.25, 1 }) do
            local widget, events, open, preview, confirm, cancel = Fixture(project, modern)
            local inverted = project == 2
            local function Native(alpha) return inverted and 1 - alpha or alpha end
            widget:SetColor(0.2, 0.3, 0.4, initial)
            Near(open(), Native(initial))

            preview(Native(0.6))
            Near(widget.a, 0.6)
            assert(events[#events][1] == "OnValueChanged")
            Near(events[#events][2], 0.6)

            cancel()
            Near(widget.a, initial)
            assert(events[#events][1] == "OnValueConfirmed")
            Near(events[#events][2], initial)
            Near(open(), Native(initial))

            preview(Native(0.35))
            Near(widget.a, 0.35)
            confirm(Native(initial))
            Near(widget.a, initial)
            assert(events[#events][1] == "OnValueConfirmed")
            Near(events[#events][2], initial)
            Near(open(), Native(initial))

            preview(Native(0.6))
            confirm(Native(0.7))
            Near(widget.a, 0.7)
            assert(events[#events][1] == "OnValueConfirmed")
            Near(events[#events][2], 0.7)
            Near(open(), Native(0.7))
            count = count + 1
        end
    end
end
print("PASS: AceGUI ColorPicker alpha open/preview/confirm/cancel/reopen (" .. count .. " cases)")
