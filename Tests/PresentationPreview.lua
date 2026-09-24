-- lua54 Tests/PresentationPreview.lua
-- Real FP renderers and AceGUI pooling; native WoW regions are simulated.
local env = dofile("Tests/FPCompactSlider.lua")
local ns, ace, native = env.ns, env.ace, env.native
ns.Ace = {}
STANDARD_TEXT_FONT = "Fonts\\FRIZQT__.TTF"
local geometryWrites = 0
for _, method in ipairs({ "SetPoint", "ClearAllPoints", "SetWidth", "SetHeight" }) do
    local original = native[method]
    native[method] = function(self, ...)
        geometryWrites = geometryWrites + 1
        return original(self, ...)
    end
end
for _, method in ipairs({ "SetAllPoints", "SetFrameStrata", "SetFrameLevel", "SetIgnoreParentAlpha",
    "SetTexture", "SetTexCoord", "SetBlendMode", "SetColorTexture" }) do
    native[method] = function(self, ...) self["last" .. method] = { ... } end
end
function native:GetParent() return self.parent end
function native:GetRegions() end
function native:GetFrameStrata() return "DIALOG" end
function native:GetFrameLevel() return 1 end
local combat = false
function InCombatLockdown() return combat end
local function Load(path) return assert(loadfile(path))("FocalPoint", ns) end
Load("GUI/GUISkin.lua")
Load("GUI/Helpers/PresentationPreview.lua")
Load("GUI/Helpers/FormWidgets.lua")
Load("GUI/Helpers/FormSectionSurfaceRenderer.lua")
Load("GUI/Helpers/FormRenderer.lua")
Load("GUI/Editor/Inspector/InspectorBinding.lua")
Load("Libraries/Ace3/AceGUI-3.0/widgets/AceGUIContainer-SimpleGroup.lua")
Load("GUI/AppShell.lua")
local api = ns.Ace.PresentationPreview
local widgets = ns.GUI.Helpers.FormWidgets
local binding = ns.GUI.Editor.Inspector.InspectorBinding

local function Equal(a, b)
    if a == b then return end
    if type(a) == "table" and type(b) == "table" then
        for k, v in pairs(a) do Equal(v, b[k]) end
        for k in pairs(b) do assert(a[k] ~= nil, "extra key " .. tostring(k)) end
    elseif type(a) == "number" and type(b) == "number" then
        assert(math.abs(a - b) < 1e-10, tostring(a) .. " ~= " .. tostring(b))
    else assert(a == b, tostring(a) .. " ~= " .. tostring(b)) end
end
local function Clone(value)
    if type(value) ~= "table" then return value end
    local copy = {}; for k, v in pairs(value) do copy[k] = Clone(v) end; return copy
end
local canonical = Clone(ns.GUI.Skins.GetActiveSkin())
local function RGBA(target)
    local b = assert(api.GetBaseline(target))
    return { b.color[1], b.color[2], b.color[3], b.alpha }
end
local function Color(region, expected) Equal(region.lastSetColorTexture, expected) end
local red = { 1, 0, 0 }
Equal(#api.GetTargets(), 6)
Equal(api.GetCapabilities().version, 1)
local typographyCapabilities = api.GetTypographyCapabilities()
Equal(typographyCapabilities.properties.size, { type = "number", min = 6, max = 96 })
Equal(typographyCapabilities.properties.flags,
    { type = "enum", values = { "", "OUTLINE", "THICKOUTLINE", "MONOCHROME",
        "OUTLINE,MONOCHROME", "THICKOUTLINE,MONOCHROME" } })
Equal(typographyCapabilities.properties.font,
    { type = "mediaReference", mediaType = "font",
        discovery = { api = "MediaRegistry.GetAvailable", mediaType = "font",
            options = { availableOnly = true } } })
Equal(typographyCapabilities.properties.color, { type = "rgb", components = 3, min = 0, max = 1 })
Equal(typographyCapabilities.properties.alpha, { type = "number", min = 0, max = 1 })
Equal(typographyCapabilities.properties.shadowEnabled, { type = "boolean" })
local capabilityCopy = api.GetTypographyCapabilities()
capabilityCopy.properties.size.min = 99
capabilityCopy.properties.flags.values[1] = "MUTATED"
Equal(api.GetTypographyCapabilities().properties.size.min, 6)
Equal(api.GetTypographyCapabilities().properties.flags.values[1], "")
for _, flag in ipairs(api.GetTypographyCapabilities().properties.flags.values) do
    assert(api.SetTypographyPresentation("sidebar_section_heading", { flags = flag }))
    Equal(api.GetTypographyPresentation("sidebar_section_heading").flags, flag)
end
local ok, reason = api.SetTypographyPresentation("sidebar_section_heading", { flags = "INVALID" })
Equal(ok, false); Equal(reason, "invalid_flags")
assert(api.SetTypographyPresentation("sidebar_section_heading", { size = 6 }))
Equal(api.GetTypographyPresentation("sidebar_section_heading").size, 6)
assert(api.SetTypographyPresentation("sidebar_section_heading", { size = 96 }))
Equal(api.GetTypographyPresentation("sidebar_section_heading").size, 96)
ok, reason = api.SetTypographyPresentation("sidebar_section_heading", { size = 5 })
Equal(ok, false); Equal(reason, "invalid_size")
ok, reason = api.SetTypographyPresentation("sidebar_section_heading", { size = 97 })
Equal(ok, false); Equal(reason, "invalid_size")
assert(api.ClearTypography("sidebar_section_heading"))
Equal(api.GetOverrides(), {})
for _, args in ipairs({
    { "bad", "alpha", 0.5 }, { {}, "alpha", 0.5 }, { "sidebar_shell", "width", 2 },
    { "sidebar_shell", "alpha", -1 }, { "sidebar_shell", "alpha", 1.1 },
    { "sidebar_shell", "alpha", 0/0 }, { "sidebar_shell", "alpha", math.huge },
    { "sidebar_shell", "alpha", "0.5" }, { "sidebar_shell", "color", { 1, 0 } },
    { "sidebar_shell", "color", { 1, 0, 0, 1 } }, { "sidebar_shell", "color", { 1, 0, 0, bad = true } },
}) do
    local ok, reason = api.Set(unpack(args)); assert(ok == false and type(reason) == "string")
end
Equal(api.GetOverrides(), {})
local original = api.GetBaseline("sidebar_shell")
local copy = api.GetBaseline("sidebar_shell"); copy.color[1] = 99
Equal(api.GetBaseline("sidebar_shell"), original)
local targets = api.GetTargets(); targets[1].properties[1] = "width"
Equal(api.GetTargets()[1].properties[1], "color")

-- Store before any instance exists. Input and output values must be detached.
assert(api.Set("sidebar_shell", "color", red)); red[1] = 0
local copied = api.GetOverrides(); copied.sidebar_shell.color[1] = 0.2
Equal(api.GetOverrides("sidebar_shell").color, { 1, 0, 0 })
assert(api.Set("sidebar_shell", "alpha", 0))
local sidebar, inspector = ace:Create("SimpleGroup"), ace:Create("SimpleGroup")
widgets.ApplySidebarChrome(sidebar, "sidebar_shell")
widgets.ApplySidebarChrome(inspector, "inspector_shell")
ns.GUI.AppShell.AssignEditorRuntimeRoles(ns)
local layer = ns.guiEditorToolbarLayer._editorSidebar
Color(sidebar.frame._fpSidebarPanelFill, { 1, 0, 0, 0 })
Color(layer, { 1, 0, 0, 0 })
Color(inspector.frame._fpSidebarPanelFill, RGBA("inspector_shell"))
local beforeGeometry = geometryWrites
assert(api.Clear("sidebar_shell", "alpha"))
Color(layer, { 1, 0, 0, original.alpha })
assert(api.Clear("sidebar_shell"))
Color(layer, RGBA("sidebar_shell"))
Color(sidebar.frame._fpSidebarPanelFill, RGBA("sidebar_shell"))
Equal(geometryWrites, beforeGeometry)

-- All section regions use the real shared renderer. Reapply must not layout.
local section = ace:Create("SimpleGroup")
binding.ApplyInspectorSectionStructure(section, "default")
local edge = section.frame._fpSectionBorderTop
local sections = {
    inspector_section_surface = section.frame._fpSectionFill,
    inspector_section_border = edge,
    inspector_section_accent = section.frame._fpSectionAccent,
}
beforeGeometry = geometryWrites
for target, region in pairs(sections) do
    assert(api.Set(target, "color", { 0, 1, 1 }))
    assert(api.Set(target, "alpha", 0.25))
    Color(region, { 0, 1, 1, 0.25 })
    assert(api.Clear(target, "color"))
    local baseline = RGBA(target); baseline[4] = 0.25; Color(region, baseline)
    assert(api.Clear(target)); Color(region, RGBA(target))
end
Equal(geometryWrites, beforeGeometry)

-- A released section cannot receive previews while used by a different owner.
local released = 0
local pooled = ace:Create("SimpleGroup")
pooled:SetCallback("OnRelease", function() released = released + 1 end)
for cycle = 1, 50 do
    binding.ApplyInspectorSectionStructure(pooled, "muted")
    binding.ApplyInspectorSectionStructure(pooled, "muted") -- no nested release hooks
    assert(api.Set("inspector_section_surface", "color", { 1, 0, 0 }))
    Color(pooled.frame._fpSectionFill, { 1, 0, 0, RGBA("inspector_section_surface")[4] })
    local old = pooled
    ace:Release(pooled)
    Color(old.frame._fpSectionFill, RGBA("inspector_section_surface"))
    assert(api.Set("inspector_section_surface", "color", { 0, 0, 1 }))
    Color(old.frame._fpSectionFill, RGBA("inspector_section_surface"))
    pooled = ace:Create("SimpleGroup"); Equal(pooled, old)
end
Equal(released, 1) -- AceGUI clears consumer callbacks on release
assert(api.ClearAll())

-- Exercise the real local collapse/expand owner, not just manual registration.
ace:RegisterWidgetType("InteractiveLabel", function()
    local frame = CreateFrame("Frame", nil, UIParent)
    local widget = { type = "InteractiveLabel", frame = frame, label = frame:CreateFontString() }
    function widget:OnAcquire() end
    function widget:SetText(text) self.label:SetText(text) end
    return ace:RegisterAsWidget(widget)
end, 1)
ace:RegisterWidgetType("InlineGroup", function()
    local frame = CreateFrame("Frame", nil, UIParent)
    local widget = { type = "InlineGroup", frame = frame, content = CreateFrame("Frame", nil, frame),
        titletext = frame:CreateFontString() }
    function widget:OnAcquire() self:SetWidth(300); self:SetHeight(100) end
    function widget:SetTitle(text) self.titletext:SetText(text) end
    return ace:RegisterAsContainer(widget)
end, 1)
Load("GUI/Editor/SidebarShared.lua")
local host = ace:Create("SimpleGroup")
local builds = 0
binding.CreateInspectorSection(host, ns.GUI.Editor.SidebarShared.CreateSection, {}, "collapse_test", "Section", false, nil, {
    localContentBuilder = function() builds = builds + 1 end,
})
local toggle, bodyHost = host.children[1], host.children[2]
for cycle = 1, 25 do
    assert(api.Set("inspector_section_surface", "color", { 1, 0, 0 }))
    toggle:Fire("OnClick") -- collapse/release
    Equal(#bodyHost.children, 0)
    toggle:Fire("OnClick") -- expand: fresh resolve and registration
    Equal(#bodyHost.children, 1)
    Color(bodyHost.children[1].frame._fpSectionFill, { 1, 0, 0, RGBA("inspector_section_surface")[4] })
    assert(api.ClearAll())
    Color(bodyHost.children[1].frame._fpSectionFill, RGBA("inspector_section_surface"))
end
Equal(builds, 26)
ace:Release(host)

local slider = ace:Create("FPCompactSlider")
slider:SetInspectorPresentation()
slider:SetValue(37)
slider.editbox:SetFocus()
beforeGeometry = geometryWrites
assert(api.Set("inspector_slider_thumb", "color", { 1, 0, 1 }))
assert(api.Set("inspector_slider_thumb", "alpha", 0.5))
Equal(slider.slider:GetThumbTexture().lastSetVertexColor, { 1, 0, 1, 1 })
Equal(slider.slider:GetThumbTexture().lastSetAlpha[1], 0.5)
assert(slider.editbox.focus); Equal(slider:GetValue(), 37)
Equal(geometryWrites, beforeGeometry)
slider:SetDisabled(true)
Equal(slider.slider:GetThumbTexture().lastSetAlpha[1], 0.225)
assert(api.Clear("inspector_slider_thumb"))
Equal(slider.slider:GetThumbTexture().lastSetAlpha[1], 0.45)
slider:SetDisabled(false)
for cycle = 1, 50 do
    slider:SetInspectorPresentation()
    assert(api.Set("inspector_slider_thumb", "color", { 1, 0, 1 }))
    local old = slider; ace:Release(slider)
    assert(api.Refresh("inspector_slider_thumb"))
    slider = ace:Create("FPCompactSlider"); Equal(slider, old)
    Equal(slider.slider:GetThumbTexture().lastSetVertexColor, { 1, 1, 1, 1 })
    Equal(slider.slider:GetThumbTexture().lastSetAlpha[1], 1)
end
assert(api.ClearAll())

-- Current canonical contracts, including shared table aliases, remain untouched.
Equal(ns.GUI.Skins.GetActiveSkin(), canonical)
local alternate = Clone(canonical)
alternate.formPalette.Navigator.navigatorBlackenedMetal = { 0.2, 0.3, 0.4, 0.6 }
alternate.formPalette.Chrome.panelBackground = { 0.2, 0.3, 0.4, 0.6 }
alternate.formPalette.Chrome.sectionFill = { 0.4, 0.3, 0.2, 0.7 }
ns.GUI.Skins.Register("preview_test", alternate)
assert(api.Set("sidebar_shell", "color", { 1, 0, 0 }))
ns.GUI.Skins.SetActiveSkin("preview_test")
assert(api.ClearAll())
Color(sidebar.frame._fpSidebarPanelFill, { 0.2, 0.3, 0.4, 0.6 })
assert(api.Refresh())
Color(section.frame._fpSectionFill, { 0.4, 0.3, 0.2, 0.7 })
Equal(ns.GUI.Skins.Builtin.default, canonical)

-- Every write entry point is blocked in combat, including reset/refresh.
assert(api.Set("inspector_shell", "alpha", 0.3))
local saved = api.GetOverrides()
combat = true
for _, call in ipairs({
    function() return api.Set("inspector_shell", "alpha", 0.9) end,
    function() return api.Clear("inspector_shell") end,
    api.ClearAll, api.Refresh,
}) do local ok, reason = call(); Equal(ok, false); Equal(reason, "combat") end
Equal(api.GetOverrides(), saved)
assert(api.GetBaseline("inspector_shell"))
combat = false
assert(api.ClearAll())
inspector.frame:Hide()
assert(api.Set("inspector_shell", "color", { 0, 1, 0 }))
assert(not inspector.frame:IsShown())
inspector.frame:Show()
Color(inspector.frame._fpSidebarPanelFill, { 0, 1, 0, 0.6 })
assert(api.ClearAll())
assert(api.Set("inspector_shell", "color", { 0, 1, 0 }))
Load("GUI/Helpers/PresentationPreview.lua") -- fresh addon Lua state has no overrides
Equal(ns.Ace.PresentationPreview.GetOverrides(), {})
assert(#env.errors == 0, table.concat(env.errors, "\n"))
print("PASS: six preview targets, copies/validation, canonical reset/skin switch, combat, geometry isolation and 50 section + slider pooling cycles")
