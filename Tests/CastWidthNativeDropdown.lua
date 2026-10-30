-- Actual Cast builder, Workspace, mutations and AceGUI pooling.
-- Only the Blizzard Menu/native XML boundary is simulated; no pixel/Forever claim.
local f = assert(io.open("Tests/CastBarPropertyGroups.lua"))
local source = f:read("*a"); f:close()
local stop = assert(source:find("\nlocal window,unit,db", 1, true))
local s = assert(load(source:sub(1, stop) .. "\nreturn s", "@CastWidth/Workspace"))()
local create = CreateFrame
local created, failTemplate = 0, false
-- Menu-manager boundary: a separate pooled menu frame, not the button's child.
-- Blizzard restores acquired menu-frame changes when returning it to the pool.
local popup = create("Frame", nil, UIParent)
popup:Hide()
DropdownButtonMixin = {
    SetupMenu = function(self, generator)
        self.generator = generator
        local entries = {}
        self.acquired = nil
        generator(self, {
            AddMenuAcquiredCallback = function(_, callback) self.acquired = callback end,
            CreateRadio = function(_, text, selected, callback)
                entries[#entries + 1] = {text=text, selected=selected, callback=callback}
            end,
        })
        self.entries = entries
    end,
    ClearMenuState = function(self)
        self.clearCount = (self.clearCount or 0) + 1
        self:CloseMenu()
        self.generator, self.entries, self.acquired = nil, nil, nil
    end,
}
WowStyle1DropdownMixin = {}
function CreateFrame(kind, name, parent, template)
    if kind ~= "DropdownButton" then return create(kind, name, parent, template) end
    assert(template == "WowStyle1DropdownTemplate")
    if failTemplate then error("template unavailable") end
    created = created + 1
    local frame = create(kind, name, parent)
    frame.SetupMenu = DropdownButtonMixin.SetupMenu
    frame.ClearMenuState = DropdownButtonMixin.ClearMenuState
    function frame:SetDefaultText(text) self.defaultText = text end
    function frame:SetEnabled(value) self.enabled = value end
    function frame:CloseMenu()
        if self.menuOpen then
            popup:Hide(); popup:SetFrameStrata("FULLSCREEN_DIALOG")
        end
        self.menuOpen = false
    end
    function frame:OpenMenu()
        if not self.enabled or self.menuOpen then return end
        assert(not popup:IsShown(), "old pooled popup remains open")
        popup:SetFrameStrata("FULLSCREEN_DIALOG")
        popup:SetFrameLevel(501) -- Manager boundary; product must not inflate this.
        if self.acquired then self.acquired(popup) end
        popup:Show(); self.menuOpen = true
    end
    return frame
end
local window, unit
local function Native()
    local found, owner
    s.Walk(window._focalPointPropertyScroll, function(w)
        local dropdown = w:GetUserData("nativePropertyDropdown")
        local row = w.parent and w.parent.parent
        local label = row and row.children and row.children[1]
        if dropdown and dropdown.generator and label and label.type == "Label"
            and label.label:GetText() == (s.ns.L.OPTION_WIDTH_MODE or "Width Mode") then
            assert(not found, "duplicate live Width Mode native dropdown")
            found, owner = dropdown, w
        end
    end)
    return found, owner
end
local function Geometry() s.Tabs().geometry:Fire("OnClick"); s.Drain() end
local count = 0
local function Test(name, fn) fn(); count=count+1; print("PASS: " .. name) end
Test("missing API or template falls back to original AceGUI path without rejected surface", function()
    local mixin = DropdownButtonMixin; DropdownButtonMixin = nil
    window, unit = s.Start(); Geometry(); assert(not Native())
    local dropdown = s.Control("Width Mode", "Dropdown")
    assert(not dropdown.frame._fpInspectorDropdownSurface)
    for _, item in dropdown.pullout:IterateItems() do assert(item.userdata.value == "CUSTOM"); break end
    dropdown:Fire("OnValueChanged", "CUSTOM"); s.Drain(); assert(unit.castBarWidthMode == "CUSTOM")
    s.controller.ReleaseInspector(); DropdownButtonMixin = mixin; failTemplate = true
    window, unit = s.Start(); Geometry(); assert(not Native())
    assert(s.Control("Width Mode", "Dropdown"))
    s.controller.ReleaseInspector(); failTemplate = false
end)
Test("native template, initial canonical selection, fixed row and untouched parent ownership", function()
    window, unit = s.Start(); Geometry()
    local dropdown, owner = Native(); assert(dropdown and owner.type == "Dropdown")
    assert(dropdown.parent == owner.frame and dropdown:GetHeight() == 25)
    assert(dropdown.points.LEFT.relative == owner.button_cover and dropdown.points.RIGHT.relative == owner.button_cover)
    assert(dropdown.points.LEFT.x == 8 and dropdown.points.RIGHT.x == -8)
    assert(not dropdown._fpInspectorDropdownSurface)
    assert(dropdown.defaultText == (s.ns.L.OPTION_MATCH_FRAME or "Match Frame"))
    assert(#dropdown.entries == 2 and dropdown.entries[1].selected() and not dropdown.entries[2].selected())
    assert(dropdown.entries[2].text == (s.ns.L.OPTION_CUSTOM or "Custom"))
end)
Test("native radio callbacks use original mutation and width dependencies", function()
    Native().entries[2].callback(); s.Drain()
    assert(unit.castBarWidthMode == "CUSTOM" and not s.Control("Width", "FPCompactSlider").disabled)
    assert(Native().entries[2].selected() and not Native().entries[1].selected())
    s.Control("Width", "FPCompactSlider"):Fire("OnValueChanged", 211.6)
    assert(unit.castBarWidth == 212)
    Native().entries[1].callback(); s.Drain()
    assert(unit.castBarWidthMode == "MATCH_FRAME" and s.Control("Width", "FPCompactSlider").disabled)
end)
Test("only acquired popup is above Inspector strata; button and controls keep their layering", function()
    local dropdown, owner = Native()
    local before = s.h.Copy(owner.frame.lastSetFrameStrata or {})
    owner.frame:SetFrameLevel(9000) -- A level collision must not require bigger magic levels.
    dropdown:OpenMenu()
    assert(popup.parent ~= dropdown and popup.lastSetFrameStrata[1] == "TOOLTIP")
    assert(popup:GetFrameLevel() == 501 and owner.frame:GetFrameLevel() == 9000)
    assert(not dropdown.lastSetFrameStrata)
    s.h.Equal(owner.frame.lastSetFrameStrata or {}, before)
    for _, entry in ipairs(dropdown.entries) do assert(entry.text ~= "" and type(entry.callback) == "function") end
    dropdown:CloseMenu()
    assert(not popup:IsShown() and popup.lastSetFrameStrata[1] == "FULLSCREEN_DIALOG")
    -- An unrelated menu reusing the manager's frame retains its normal strata.
    local other = CreateFrame("DropdownButton", nil, UIParent, "WowStyle1DropdownTemplate")
    other:SetEnabled(true); other:SetupMenu(function() end); other:OpenMenu()
    assert(popup.lastSetFrameStrata[1] == "FULLSCREEN_DIALOG")
    other:CloseMenu()
    for _=1,20 do
        dropdown:OpenMenu(); assert(popup:IsShown() and popup.lastSetFrameStrata[1] == "TOOLTIP")
        dropdown:CloseMenu(); assert(not popup:IsShown())
    end
end)
Test("enabled/disabled native control and hide close menu; Show-off retains existing editability", function()
    local dropdown = Native(); dropdown:SetEnabled(false); dropdown:OpenMenu(); assert(not dropdown.menuOpen)
    dropdown:SetEnabled(true); dropdown:OpenMenu(); assert(dropdown.menuOpen)
    dropdown:Hide(); assert(not dropdown.menuOpen); dropdown:Show()
    s.Tabs().behavior:Fire("OnClick"); s.Drain()
    s.Control("Show", "CheckBox"):Fire("OnValueChanged", false); s.Drain(); Geometry()
    assert(unit.showCastBar == false and Native().enabled)
end)
Test("release clears native menu and stale callbacks; reacquired host binds current selection", function()
    local dropdown = Native(); local old = dropdown.entries[2].callback
    local clears = dropdown.clearCount or 0
    dropdown:OpenMenu()
    s.Select("NormalAbsorbBar")
    -- The same Dropdown may already be reacquired by an Absorb row.
    assert(dropdown.clearCount > clears and not dropdown.menuOpen)
    old(); s.Drain(); assert(unit.castBarWidthMode == "MATCH_FRAME")
    s.Select("CastBar"); Geometry()
    local current = Native(); assert(current and current.entries[1].selected())
    old(); s.Drain(); assert(unit.castBarWidthMode == "MATCH_FRAME")
    current.entries[2].callback(); s.Drain(); assert(unit.castBarWidthMode == "CUSTOM")
end)
Test("rebuild, close/reopen and repeated pool reuse reject old bindings", function()
    for _=1,20 do
        local dropdown = Native()
        local old = dropdown.entries[1].callback
        s.controller.RefreshActiveProperties(); s.Drain(); Geometry()
        old(); s.Drain(); assert(unit.castBarWidthMode == "CUSTOM")
    end
    local dropdown = Native(); local old = dropdown.entries[1].callback
    window.closebutton:GetScript("OnClick")(window.closebutton); s.Drain()
    assert(not window.frame:IsShown())
    -- Workspace Close hides the retained host, rather than releasing its children.
    -- The native boundary does not propagate ancestor OnHide notifications itself.
    dropdown:Run("OnHide"); assert(not dropdown.menuOpen)
    old(); assert(unit.castBarWidthMode == "CUSTOM")
    window = s.Build(); s.Drain(); Geometry()
    old(); assert(unit.castBarWidthMode == "CUSTOM" and Native().entries[2].selected())
    assert(created < 20, "native child recreated on every rebuild")
end)
assert(#s.h.ui.env.errors == 0, table.concat(s.h.ui.env.errors, "\n"))
print("Cast Width Native Dropdown: " .. count .. " groups PASS")
