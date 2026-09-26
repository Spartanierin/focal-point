-- lua54 Tests/PresentationPreview.lua
-- Real FP renderers and AceGUI pooling; native WoW regions are simulated.
local env = dofile("Tests/FPCompactSlider.lua")
local ns, ace, native = env.ns, env.ace, env.native
ns.Ace = {}
STANDARD_TEXT_FONT = "Fonts\\FRIZQT__.TTF"
local textureNS = {}
assert(loadfile("Media/Textures/GUI/GUITextureManifest.lua"))("FocalPoint", textureNS)
assert(loadfile("Services/MediaRegistry.lua"))("FocalPoint", textureNS)
local fontEntries = {
    { id = "fp:font:standard", name = "Focal Point Standard", path = "Fonts\\FRIZQT__.TTF", available = true },
    { id = "fp:font:morpheus", name = "Morpheus", path = "Fonts\\MORPHEUS.ttf", available = true },
    { id = "lsm:font:fixture", name = "LSM Fixture", path = "Interface\\AddOns\\Fixture\\Font.ttf", available = true },
    { id = "lsm:font:missing", name = "Unavailable", path = "", available = false },
}
local requestedMediaType, requestedOptions
ns.MediaRegistry = {
    GetDefault = function(mediaType)
        if mediaType == "font" then return "fp:font:standard" end
    end,
    GetAvailable = function(mediaType, options)
        requestedMediaType, requestedOptions = mediaType, options
        local result = {}
        for _, entry in ipairs(fontEntries) do
            if not options or options.availableOnly ~= true or entry.available == true then
                result[#result + 1] = {
                    id = entry.id, name = entry.name, path = entry.path,
                    available = entry.available,
                }
            end
        end
        return result
    end,
    GetEntry = function(reference, mediaType)
        if mediaType == "texture" then return textureNS.MediaRegistry.GetEntry(reference, mediaType) end
        if mediaType ~= "font" then return nil end
        for _, entry in ipairs(fontEntries) do
            if entry.id == reference then return entry end
        end
    end,
    ResolveReference = function(reference, mediaType)
        local entry = ns.MediaRegistry.GetEntry(reference, mediaType)
        if not entry then return nil end
        return { available = entry.available, resolvedAsset = entry.path }
    end,
}
local geometryWrites = 0
for _, method in ipairs({ "SetPoint", "ClearAllPoints", "SetWidth", "SetHeight" }) do
    local original = native[method]
    native[method] = function(self, ...)
        geometryWrites = geometryWrites + 1
        return original(self, ...)
    end
end
for _, method in ipairs({ "SetAllPoints", "SetFrameStrata", "SetFrameLevel", "SetIgnoreParentAlpha", "SetDrawLayer",
    "SetTexture", "SetTexCoord", "SetBlendMode", "SetColorTexture" }) do
    native[method] = function(self, ...) self["last" .. method] = { ... } end
end
function native:GetParent() return self.parent end
function native:GetRegions() end
function native:GetFrameStrata() return "DIALOG" end
function native:GetFrameLevel() return 1 end
function native:GetFont() return table.unpack(self.font or { STANDARD_TEXT_FONT, 14, "OUTLINE" }) end
function native:SetFont(...) self.font = { ... } end
function native:SetShadowOffset(...) self.shadowOffset = { ... } end
function native:SetShadowColor(...) self.shadowColor = { ... } end
local combat = false
function InCombatLockdown() return combat end
local function Load(path) return assert(loadfile(path))("FocalPoint", ns) end
Load("GUI/GUISkin.lua")
Load("GUI/Helpers/TextStyles.lua")
Load("GUI/Helpers/PresentationPreview.lua")
Load("GUI/Helpers/FormWidgets.lua")
Load("GUI/Helpers/FormSectionSurfaceRenderer.lua")
Load("GUI/Helpers/FormRenderer.lua")
Load("GUI/Layouts/FormElementDefinition.lua")
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
local function Color(region, expected)
    assert(region)
    if region.lastSetTexture and region.lastSetTexture[1] then
        Equal(region.lastSetVertexColor, expected)
    else
        Equal(region.lastSetColorTexture, expected)
    end
end
local red = { 1, 0, 0 }
Equal(#api.GetTargets(), 7)
for _, target in ipairs(api.GetTargets()) do
    Equal(target.area, target.id:match("^sidebar_") and "Sidebar" or "Inspector")
    Equal(target.properties, { "color", "alpha" })
end
Equal(api.GetCapabilities().version, 1)
local typographyCapabilities = api.GetTypographyCapabilities()
Equal(typographyCapabilities.properties.size, { type = "number", min = 6, max = 96 })
Equal(typographyCapabilities.properties.flags,
    { type = "enum", values = { "", "OUTLINE", "THICKOUTLINE", "MONOCHROME",
        "OUTLINE,MONOCHROME", "THICKOUTLINE,MONOCHROME" } })
Equal(typographyCapabilities.properties.font,
    { type = "mediaReference", mediaType = "font",
        discovery = { api = "GetTypographyFontOptions", mediaType = "font" } })
local fontOptions = api.GetTypographyFontOptions()
Equal(requestedMediaType, "font")
Equal(requestedOptions, { availableOnly = true })
Equal(fontOptions, {
    { id = "fp:font:standard", label = "Focal Point Standard", available = true },
    { id = "fp:font:morpheus", label = "Morpheus", available = true },
    { id = "lsm:font:fixture", label = "LSM Fixture", available = true },
})
for _, option in ipairs(fontOptions) do
    assert(api.SetTypographyPresentation("sidebar_section_heading", { font = option.id }))
    Equal(ns.GUI.PresentationPreview.ResolveTypographyFont(option.id), ns.MediaRegistry.GetEntry(option.id, "font").path)
end
assert(fontOptions[1].path == nil)
fontOptions[1].id = "mutated"
fontOptions[1].label = "mutated"
Equal(api.GetTypographyFontOptions()[1],
    { id = "fp:font:standard", label = "Focal Point Standard", available = true })
assert(api.SetTypographyPresentation("sidebar_section_heading", { font = "fp:font:morpheus" }))
Equal(ns.GUI.PresentationPreview.ResolveTypographyFont("fp:font:morpheus"), "Fonts\\MORPHEUS.ttf")
local fontOk, fontReason = api.SetTypographyPresentation("sidebar_section_heading", { font = "lsm:font:missing" })
Equal(fontOk, false); Equal(fontReason, "unavailable_font")
assert(api.ClearTypography("sidebar_section_heading"))
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
targets[1].area = "wrong"
Equal(api.GetTargets()[1].properties[1], "color")
Equal(api.GetTargets()[1].area, "Sidebar")

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
assert(api.Set("inspector_section_border", "alpha", 0.25))
assert(api.Clear("inspector_section_border"))
local edge = section.frame._fpSectionBorderTop
local sections = {
    inspector_section_surface = section.frame._fpSectionFill,
    inspector_section_border = edge,
    inspector_section_accent = section.frame._fpSectionTopShade,
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

-- All three targets on the same owner survive rebinding and independent clears.
binding.ApplyInspectorSectionStructure(section, "default")
beforeGeometry = geometryWrites
for target in pairs(sections) do assert(api.Set(target, "color", { 0.3, 0.5, 0.7 })) end
assert(api.Set("inspector_section_accent", "alpha", 0))
assert(api.Clear("inspector_section_border"))
Color(sections.inspector_section_surface, { 0.3, 0.5, 0.7, RGBA("inspector_section_surface")[4] })
Color(sections.inspector_section_accent, { 0.3, 0.5, 0.7, 0 })
Color(edge, RGBA("inspector_section_border"))
assert(api.ClearAll())
Equal(geometryWrites, beforeGeometry)

-- v0.2 admits only the unchanged inset descriptor, not the twelve WIP targets.
local insetId = "sidebar_unit_navigator_inset"
local styles = ns.GUI.Layouts.FormElements.SectionStyles
local canonicalStyles = Clone(styles)
for _, family in ipairs({ "brand_header", "workspace_section", "editing_section", "utility_section" }) do
    for _, part in ipairs({ "surface", "border", "accent" }) do
        local id = "sidebar_" .. family .. "_" .. part
        local value, reason = api.GetBaseline(id)
        Equal(value, nil); Equal(reason, "unknown_target")
        local ok; ok, reason = api.Set(id, "alpha", 0.4)
        Equal(ok, false); Equal(reason, "unknown_target")
    end
end
Equal(RGBA(insetId), styles.toolbar_explorer_inset.surface.tint)
local insetCopy = api.GetBaseline(insetId); insetCopy.color[1] = 99; insetCopy.alpha = 99
Equal(RGBA(insetId), styles.toolbar_explorer_inset.surface.tint)
assert(api.Set(insetId, "alpha", 0)) -- before the Sidebar exists
local surfaceRenderer = ns.GUI.Helpers.FormSectionSurfaceRenderer
local function Surface(style)
    local group = ace:Create("SimpleGroup")
    surfaceRenderer.ApplySectionSurface(group, styles[style])
    surfaceRenderer.ApplySectionBorder(group, styles[style].border)
    return group
end
local inset = Surface("toolbar_explorer_inset")
local options, tools = Surface("toolbar_global_panel"), Surface("toolbar_global_panel")
local brand = Surface("page_header")
local itemState = Clone(ns.GUI.Layouts.FormElements.ComponentStyles.Navigation.UnitNavigatorItem.states)
-- Exercise the real Sidebar builder; simulate only the surrounding window/layout.
local oldCreate, oldBuild = ace.Create, ns.GUI.Helpers.FormRenderer.BuildLayout
ace.Create = function(self, kind)
    if kind ~= "Window" and kind ~= "ScrollFrame" then return oldCreate(self, kind) end
    local group = oldCreate(self, "SimpleGroup")
    function group:SetTitle() end
    function group:EnableResize() end
    function group:Show() self.frame:Show() end
    return group
end
local headingWidgets = {}
for _, id in ipairs({ "unitLabel", "compositionTitle", "editingTitle", "toolsTitle" }) do
    local owner = ace:Create("SimpleGroup")
    owner.label = owner.frame:CreateFontString()
    owner.label:SetText(id)
    headingWidgets[id] = owner
end
ns.GUI.Helpers.FormRenderer.BuildLayout = function()
    return { UnitGrid = inset, Options = options, Secondary = tools, Header = brand }, headingWidgets
end
for _, method in ipairs({ "SetClampedToScreen", "SetToplevel", "Raise" }) do native[method] = function() end end
ns.GUI.Editor.SidebarGeometry = { left = 0, top = 0 }
UIParent:SetHeight(900)
Load("GUI/Editor/Toolbar/ToolbarController.lua")
ns.GUI.Editor.Toolbar.Open({}, {})
ace.Create, ns.GUI.Helpers.FormRenderer.BuildLayout = oldCreate, oldBuild
-- Real Sidebar and Inspector owner apply, including the final FontString RGB.
local sidebarHeading, inspectorHeading = "sidebar_section_heading", "inspector_section_heading"
local inspectorTextOwner = ace:Create("SimpleGroup")
inspectorTextOwner.titletext = inspectorTextOwner.frame:CreateFontString()
inspectorTextOwner.titletext:SetText("Inspector title")
binding.ApplyInspectorSectionStructure(inspectorTextOwner, "default")
local function TypographyColor(region, descriptor)
    Equal(region.lastSetTextColor, { descriptor.color[1], descriptor.color[2], descriptor.color[3], descriptor.alpha })
end
local inspectorBaseline = api.GetTypographyPresentation(inspectorHeading)
local sidebarBaseline = api.GetTypographyPresentation(sidebarHeading)
local typographyPatch = { font = "lsm:font:fixture", size = 22, flags = "THICKOUTLINE",
    color = { 0.2, 0.4, 0.6 }, alpha = 0.35, shadowEnabled = false }
beforeGeometry = geometryWrites
assert(api.SetTypographyPresentation(sidebarHeading, typographyPatch))
for id, owner in pairs(headingWidgets) do
    TypographyColor(owner.label, typographyPatch)
    Equal(owner.label.font, { "Interface\\AddOns\\Fixture\\Font.ttf", 22, "THICKOUTLINE" })
    Equal(owner.label.shadowOffset, { 0, 0 }); Equal(owner.label.shadowColor, { 0, 0, 0, 0 })
    Equal(owner.label:GetText(), id)
end
Equal(geometryWrites, beforeGeometry)
TypographyColor(inspectorTextOwner.titletext, inspectorBaseline)
assert(api.SetTypographyPresentation(inspectorHeading, typographyPatch))
TypographyColor(inspectorTextOwner.titletext, typographyPatch)
Equal(inspectorTextOwner.titletext.font, { "Interface\\AddOns\\Fixture\\Font.ttf", 22, "THICKOUTLINE" })
Equal(inspectorTextOwner.titletext.shadowOffset, { 0, 0 })
Equal(inspectorTextOwner.titletext:GetText(), "Inspector title")
typographyPatch.color[1] = 0.9
Equal(api.GetTypographyPresentation(sidebarHeading).color, { 0.2, 0.4, 0.6 })
local descriptorCopy = api.GetTypographyPresentation(sidebarHeading)
descriptorCopy.color[1] = 0.9
Equal(api.GetTypographyPresentation(sidebarHeading).color, { 0.2, 0.4, 0.6 })
local overridesBeforeInvalid = api.GetTypographyOverrides()
for _, patch in ipairs({ { color = { 1, 0 } }, { color = { 1, 0, 0, 1 } },
    { alpha = -1 }, { alpha = 0/0 }, { shadowEnabled = 1 }, { font = "Fonts\\Raw.ttf" },
    { size = 20, flags = "BAD" } }) do
    local ok, reason = api.SetTypographyPresentation(sidebarHeading, patch)
    Equal(ok, false); assert(type(reason) == "string")
    Equal(api.GetTypographyOverrides(), overridesBeforeInvalid)
end
assert(api.ClearTypography(sidebarHeading))
for _, owner in pairs(headingWidgets) do
    TypographyColor(owner.label, sidebarBaseline)
    Equal(owner.label.font, { STANDARD_TEXT_FONT, 14, "OUTLINE" })
    Equal(owner.label.shadowOffset, { 1, -1 })
end
Equal(api.GetTypographyPresentation(inspectorHeading).alpha, 0.35)
combat = true
for _, call in ipairs({ function() return api.SetTypographyPresentation(inspectorHeading, { alpha = 0.8 }) end,
    function() return api.ClearTypography(inspectorHeading) end, api.ClearAllTypography }) do
    local ok, reason = call(); Equal(ok, false); Equal(reason, "combat")
end
Equal(api.GetTypographyPresentation(inspectorHeading).alpha, 0.35)
combat = false
assert(api.ClearTypography(inspectorHeading))
TypographyColor(inspectorTextOwner.titletext, inspectorBaseline)
Color(inset.frame._fpSectionFill, { 0.6549019813537598, 0.6549019813537598, 0.6549019813537598, 0 })
local insetReleased = 0
for cycle = 1, 50 do
    ns.GUI.PresentationPreview.BindSidebarNavigatorInset(inset)
    ns.GUI.PresentationPreview.BindSidebarNavigatorInset(inset)
    beforeGeometry = geometryWrites
    assert(api.Set(insetId, "color", { 1, 0, 1 }))
    assert(api.Set(insetId, "alpha", 0.3))
    Color(inset.frame._fpSectionFill, { 1, 0, 1, 0.3 })
    assert(api.Clear(insetId, "color"))
    Color(inset.frame._fpSectionFill, { 0.6549019813537598, 0.6549019813537598, 0.6549019813537598, 0.3 })
    Color(options.frame._fpSectionFill, styles.toolbar_global_panel.surface.tint)
    Color(tools.frame._fpSectionFill, styles.toolbar_global_panel.surface.tint)
    Color(brand.frame._fpSectionAccent, styles.page_header.surface.accent.color)
    Color(sidebar.frame._fpSidebarPanelFill, RGBA("sidebar_shell"))
    Equal(geometryWrites, beforeGeometry)
    local old = inset
    ace:Release(inset); insetReleased = insetReleased + 1
    Color(old.frame._fpSectionFill, RGBA(insetId))
    assert(api.Set(insetId, "color", { 0, 1, 0 }))
    Color(old.frame._fpSectionFill, RGBA(insetId)) -- no writes to released owner
    inset = Surface("toolbar_explorer_inset"); Equal(inset, old)
    ns.GUI.PresentationPreview.BindSidebarNavigatorInset(inset)
    Color(inset.frame._fpSectionFill, { 0, 1, 0, 0.3 })
end
Equal(insetReleased, 50)
beforeGeometry = geometryWrites
assert(api.ClearAll()); Color(inset.frame._fpSectionFill, RGBA(insetId))
Equal(geometryWrites, beforeGeometry)
Equal(styles, canonicalStyles)
Equal(ns.GUI.Layouts.FormElements.ComponentStyles.Navigation.UnitNavigatorItem.states, itemState)
combat = true
for _, call in ipairs({ function() return api.Set(insetId, "alpha", 1) end,
    function() return api.Clear(insetId) end, api.ClearAll }) do
    local ok, reason = call(); Equal(ok, false); Equal(reason, "combat")
end
Equal(api.GetOverrides(), {})
combat = false
ace:Release(inset); assert(api.Clear(insetId))

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
alternate.formPalette.Chrome.navigatorShellSurface.tint = { 0.2, 0.3, 0.4, 0.6 }
alternate.formPalette.Chrome.inspectorSectionSurface.tint = { 0.4, 0.3, 0.2, 0.7 }
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
ace:Release(inspectorTextOwner)
for _, owner in pairs(headingWidgets) do ace:Release(owner) end
assert(api.SetTypographyPresentation(sidebarHeading, { color = { 1, 0, 0 } }))
for _, owner in pairs(headingWidgets) do TypographyColor(owner.label, sidebarBaseline) end
assert(api.ClearTypography(sidebarHeading))
print("PASS: typography public built-in/LSM DTOs, resolvable IDs, copies, real Sidebar/Inspector font/color/alpha/size/flags/shadow owners, isolation, reset, release and combat")
Load("GUI/Helpers/PresentationPreview.lua") -- fresh addon Lua state has no overrides
api = ns.Ace.PresentationPreview
-- T1.2 verifies the public Typography contract on real Sidebar/Inspector owners.
local oldCreate, oldBuild = ace.Create, ns.GUI.Helpers.FormRenderer.BuildLayout
local headingWidgets = {}
for _, id in ipairs({ "unitLabel", "compositionTitle", "editingTitle", "toolsTitle" }) do
    local owner = ace:Create("SimpleGroup")
    owner.label = owner.frame:CreateFontString()
    owner.label:SetText(id)
    headingWidgets[id] = owner
end
ace.Create = function(self, kind)
    if kind ~= "Window" and kind ~= "ScrollFrame" then return oldCreate(self, kind) end
    local group = oldCreate(self, "SimpleGroup")
    function group:SetTitle() end
    function group:EnableResize() end
    function group:Show() self.frame:Show() end
    return group
end
ns.GUI.Helpers.FormRenderer.BuildLayout = function()
    return {}, headingWidgets
end
for _, method in ipairs({ "SetClampedToScreen", "SetToplevel", "Raise" }) do native[method] = function() end end
ns.GUI.Editor.SidebarGeometry = { left = 0, top = 0 }
Load("GUI/Editor/Toolbar/ToolbarController.lua")
ns.GUI.Editor.Toolbar.Open({}, {})
ace.Create, ns.GUI.Helpers.FormRenderer.BuildLayout = oldCreate, oldBuild
local sidebarHeading, inspectorHeading = "sidebar_section_heading", "inspector_section_heading"
local inspectorTextOwner = ace:Create("SimpleGroup")
inspectorTextOwner.titletext = inspectorTextOwner.frame:CreateFontString()
inspectorTextOwner.titletext:SetText("Inspector title")
binding.ApplyInspectorSectionStructure(inspectorTextOwner, "default")
local function TypographyColor(region, descriptor)
    Equal(region.lastSetTextColor, { descriptor.color[1], descriptor.color[2], descriptor.color[3], descriptor.alpha })
end
local inspectorBaseline = api.GetTypographyPresentation(inspectorHeading)
local sidebarBaseline = api.GetTypographyPresentation(sidebarHeading)
local typographyPatch = { font = "lsm:font:fixture", size = 22, flags = "THICKOUTLINE",
    color = { 0.2, 0.4, 0.6 }, alpha = 0.35, shadowEnabled = false }
beforeGeometry = geometryWrites
assert(api.SetTypographyPresentation(sidebarHeading, typographyPatch))
for id, owner in pairs(headingWidgets) do
    TypographyColor(owner.label, typographyPatch)
    Equal(owner.label.font, { "Interface\\AddOns\\Fixture\\Font.ttf", 22, "THICKOUTLINE" })
    Equal(owner.label.shadowOffset, { 0, 0 }); Equal(owner.label.shadowColor, { 0, 0, 0, 0 })
    Equal(owner.label:GetText(), id)
end
Equal(geometryWrites, beforeGeometry)
TypographyColor(inspectorTextOwner.titletext, inspectorBaseline)
assert(api.SetTypographyPresentation(inspectorHeading, typographyPatch))
TypographyColor(inspectorTextOwner.titletext, typographyPatch)
Equal(inspectorTextOwner.titletext.font, { "Interface\\AddOns\\Fixture\\Font.ttf", 22, "THICKOUTLINE" })
Equal(inspectorTextOwner.titletext.shadowOffset, { 0, 0 })
Equal(inspectorTextOwner.titletext:GetText(), "Inspector title")
assert(api.ClearTypography(sidebarHeading)); assert(api.ClearTypography(inspectorHeading))
for _, owner in pairs(headingWidgets) do ace:Release(owner) end
ace:Release(inspectorTextOwner)
ns.GUI.Editor.Toolbar.Hide()
print("PASS: T1.2 public font DTOs, Sidebar RGB apply, Inspector isolation, resolver compatibility and typography state")
Equal(ns.Ace.PresentationPreview.GetOverrides(), {})
assert(#env.errors == 0, table.concat(env.errors, "\n"))
print("PASS: seven preview targets/areas, WIP gate, Sidebar builder binding, inset isolation, multi-target owner, copies/validation, canonical reset/skin switch, combat, geometry isolation, 50 inset + section + slider pooling cycles")
