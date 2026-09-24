-- lua54 Tests/PresentationCompositionPreview.lua
-- Real FP dispatcher/renderer and real AceGUI InlineGroup/InteractiveLabel/pooling.
-- Native regions are simulated; actual draw order/clipping require client acceptance.
local env = dofile("Tests/FPCompactSlider.lua")
local ns, ace, native = env.ns, env.ace, env.native
ns.Ace = {}
STANDARD_TEXT_FONT = "Fonts\\FRIZQT__.TTF"
local combat, functionalWrites, regionCount = false, 0, 0
function InCombatLockdown() return combat end
for _, method in ipairs({ "SetTexture", "SetTexCoord", "SetBlendMode", "SetColorTexture", "SetDrawLayer",
    "SetFrameStrata", "SetFrameLevel", "SetAllPoints", "SetIgnoreParentAlpha" }) do
    native[method] = function(self, ...) self["last" .. method] = { ... } end
end
local createTexture = native.CreateTexture
function native:CreateTexture(...)
    regionCount = regionCount + 1
    local region = createTexture(self, ...)
    return region
end
function native:GetTexture() return self.lastSetTexture and self.lastSetTexture[1] end
function native:GetStringHeight() return 14 end
function native:GetParent() return self.parent end
function native:GetRegions() end
local setPoint = native.SetPoint
function native:SetPoint(point, relative, relativePoint, x, y)
    if type(relative) == "number" then x, y, relative, relativePoint = relative, relativePoint, self.parent, point
    elseif not relative then relative, relativePoint = self.parent, point end
    return setPoint(self, point, relative, relativePoint or point, x, y)
end
for _, method in ipairs({ "SetPoint", "ClearAllPoints", "SetWidth", "SetHeight", "SetAllPoints",
    "SetFrameStrata", "SetFrameLevel", "EnableMouse", "EnableMouseWheel" }) do
    local original = native[method]
    native[method] = function(self, ...)
        if self.kind ~= "Texture" then functionalWrites = functionalWrites + 1 end
        return original(self, ...)
    end
end
local function Load(path) return assert(loadfile(path))("FocalPoint", ns) end
Load("GUI/GUISkin.lua")
Load("GUI/Helpers/PresentationPreview.lua")
Load("GUI/Helpers/PresentationCompositionPreview.lua")
Load("GUI/Helpers/FormWidgets.lua")
Load("GUI/Helpers/FormSectionSurfaceRenderer.lua")
Load("GUI/Helpers/FormRenderer.lua")
Load("GUI/Layouts/FormElementDefinition.lua")
Load("GUI/Editor/Inspector/InspectorBinding.lua")
for _, file in ipairs({ "AceGUIContainer-SimpleGroup", "AceGUIContainer-InlineGroup", "AceGUIWidget-Label", "AceGUIWidget-InteractiveLabel" }) do
    Load("Libraries/Ace3/AceGUI-3.0/widgets/" .. file .. ".lua")
end
Load("GUI/Editor/SidebarShared.lua")
local api, preview = ns.Ace.PresentationCompositionPreview, ns.Ace.PresentationPreview
local composition = ns.GUI.PresentationCompositionPreview
local binding = ns.GUI.Editor.Inspector.InspectorBinding
local target = "inspector_section"
local function Equal(a, b)
    if a == b then return end
    if type(a) == "table" and type(b) == "table" then
        for k, v in pairs(a) do Equal(v, b[k]) end
        for k in pairs(b) do assert(a[k] ~= nil, "extra key " .. tostring(k)) end
    else assert(false, tostring(a) .. " ~= " .. tostring(b)) end
end
local function Rejected(reason, fn)
    local before, writes, regions = api.GetComposition(target), functionalWrites, regionCount
    local ok, why = fn()
    Equal(ok, false); Equal(why, reason)
    Equal(api.GetComposition(target), before)
    Equal(functionalWrites, writes); Equal(regionCount, regions)
end
local function Add(kind, values)
    local ok, id = api.AddLayer(target, kind, values); assert(ok, id); return id
end
local function NewSection()
    local owner = ace:Create("InlineGroup")
    owner:SetTitle("General")
    binding.ApplyInspectorSectionStructure(owner, "muted")
    return owner
end
local function Neutral(region)
    assert(not region:IsShown())
    Equal(region:GetTexture(), nil); Equal(region.lastSetVertexColor, { 1, 1, 1, 1 })
    Equal(region.lastSetAlpha, { 1 }); Equal(region.lastSetHorizTile, { false }); Equal(region.lastSetVertTile, { false })
    Equal(region.points, {}); Equal(region.lastSetTexCoord, { 0, 1, 0, 1 })
    Equal(region.nativeWidth, 0); Equal(region.nativeHeight, 0)
end
Equal(api.version, 1); Equal(api.GetComposition(target), nil)
local caps = api.GetCapabilities(); caps.types[1] = "bad"; Equal(api.GetCapabilities().types[1], "surface")
local opts = api.GetTextureOptions(); opts[1].id = "bad"; Equal(api.GetTextureOptions()[1].id, "parchment")
local value, reason = api.GetComposition({}); Equal(value, nil); Equal(reason, "unknown_target")
Rejected("unknown_target", function() return api.AddLayer("sidebar", "surface") end)
Rejected("unknown_type", function() return api.AddLayer(target, {}) end)
Rejected("invalid_initial", function() return api.AddLayer(target, "surface", false) end)
for _, initial in ipairs({ { id = "own" }, { type = "line" }, { width = 50 }, { color = { 1, 1 } },
    { color = { 1, 1, 1, 1 } }, { color = { 1, 1, 1, bad = true } }, { alpha = 0/0 },
    { alpha = math.huge }, { alpha = "1" }, { alpha = -1 }, { alpha = 2 },
    { insets = { left = 0, right = 0, top = 0, bottom = 9 } }, { insets = {} },
    { color = setmetatable({ 1, 1, 1 }, {}) }, { color = function() end } }) do
    Rejected("invalid_property", function() return api.AddLayer(target, "surface", initial) end)
end
local cycle = {}; cycle.color = cycle
Rejected("invalid_property", function() return api.AddLayer(target, "surface", cycle) end)
Rejected("invalid_initial", function() return api.AddLayer(target, "line", setmetatable({}, {})) end)
for _, id in ipairs({ "inspector_section_surface", "inspector_section_border", "inspector_section_accent" }) do
    assert(preview.Set(id, "alpha", 0))
    Rejected("section_color_preview_active", function() return api.AddLayer(target, "surface") end)
    Rejected("section_color_preview_active", function() return api.ClearComposition(target) end)
    assert(preview.Clear(id))
end
local rgb = { 0.1, 0.2, 0.3 }
local surface = Add("surface", { color = rgb, alpha = 0, insets = { left = 1, right = 2, top = 3, bottom = 4 } })
Equal(surface, "layer_1") -- failed transactions did not consume IDs or activate a mode
rgb[1] = 99
local copy = api.GetComposition(target); copy.layers[1].color[1] = 99; copy.layers[1].insets.left = 99
Equal(api.GetComposition(target).layers[1].color, { 0.1, 0.2, 0.3 })
local a, b = NewSection(), NewSection()
local slots = a.frame._fpCompositionRegions
Equal(slots[1].lastSetColorTexture, { 0.1, 0.2, 0.3, 1 }); Equal(slots[1].lastSetAlpha, { 0 })
Equal(slots[1].points.TOPLEFT.x, 7); Equal(slots[1].points.TOPLEFT.y, -3)
Equal(slots[1].points.BOTTOMRIGHT.x, -8); Equal(slots[1].points.BOTTOMRIGHT.y, 4)
local beforeGeometry = functionalWrites
local line = Add("line", { edge = "left", thickness = 4, offset = 8 })
for _, initial in ipairs({ { edge = "diagonal" }, { offset = -1 }, { offset = 9 }, { thickness = 0 }, { thickness = 5 } }) do
    Rejected("invalid_property", function() return api.AddLayer(target, "line", initial) end)
end
for _, initial in ipairs({ { textureId = "Interface\\anything.blp" }, { mode = "tile" }, { tint = { 1, 2, 1 } } }) do
    Rejected("invalid_property", function() return api.AddLayer(target, "texture", initial) end)
end
local texture = Add("texture", { textureId = "blizzard", tint = { 0.2, 0.3, 0.4 }, alpha = 0.6 })
Equal(slots[3].lastSetVertexColor, { 0.2, 0.3, 0.4, 1 }); Equal(slots[3].lastSetAlpha, { 0.6 })
assert(slots[3]:GetTexture():find("BetterBlizzard", 1, true))
Equal(slots[3].lastSetTexture[2], "CLAMP"); Equal(slots[3].lastSetTexture[3], "CLAMP")
for _, edge in ipairs({ "top", "bottom", "left", "right" }) do
    assert(api.UpdateLayer(target, line, "edge", edge))
    local r = slots[2]
    if edge == "top" then Equal(r.points.TOPLEFT.y, -8); Equal(r.nativeHeight, 4)
    elseif edge == "bottom" then Equal(r.points.BOTTOMLEFT.y, 8); Equal(r.nativeHeight, 4)
    elseif edge == "left" then Equal(r.points.TOPLEFT.x, 14); Equal(r.nativeWidth, 4)
    else Equal(r.points.TOPRIGHT.x, -14); Equal(r.nativeWidth, 4) end
end
local count = regionCount
assert(api.MoveLayer(target, texture, 1)) -- texture into former color slot
Equal(slots[1].lastSetVertexColor, { 0.2, 0.3, 0.4, 1 })
assert(api.MoveLayer(target, surface, "down")) -- color into former texture slot
Equal(slots[1]:GetTexture(), nil); Equal(slots[1].lastSetVertexColor, { 1, 1, 1, 1 })
assert(api.MoveLayer(target, texture, "down")); Equal(slots[1].lastSetVertexColor, { 0.2, 0.3, 0.4, 1 })
assert(api.MoveLayer(target, texture, "up")); Equal(api.GetComposition(target).layers[2].id, texture)
for index, r in ipairs(slots) do Equal(r.lastSetDrawLayer, { "BACKGROUND", index - 9 }) end
Equal(regionCount, count)
Rejected("invalid_position", function() return api.MoveLayer(target, surface, 1.5) end)
Rejected("invalid_position", function() return api.MoveLayer(target, surface, 11) end)
Rejected("unknown_layer", function() return api.RemoveLayer(target, "missing") end)
Rejected("invalid_property", function() return api.UpdateLayer(target, surface, "id", "other") end)
Rejected("invalid_property", function() return api.UpdateLayer(target, texture, "type", "surface") end)
local replacement = { 0.8, 0.7, 0.6 }
assert(api.UpdateLayer(target, surface, "color", replacement)); replacement[1] = 9
Equal(api.GetComposition(target).layers[1].color, { 0.8, 0.7, 0.6 })
for _, owner in ipairs({ a, b }) do
    Equal(owner.frame._fpCompositionRegions[1].lastSetColorTexture, { 0.8, 0.7, 0.6, 1 })
end
for _, id in ipairs({ "inspector_section_surface", "inspector_section_border", "inspector_section_accent" }) do
    local ok, why = preview.Set(id, "alpha", 0.3); Equal(ok, false); Equal(why, "section_composition_active")
    assert(preview.Clear(id)); assert(preview.Refresh(id))
end
for _, id in ipairs({ "sidebar_shell", "inspector_shell", "inspector_slider_thumb" }) do
    assert(preview.Set(id, "alpha", 0.4))
end
assert(preview.ClearAll()); assert(preview.Refresh())
Equal(functionalWrites, beforeGeometry)
local ids = {}; for _, layer in ipairs(api.GetComposition(target).layers) do ids[layer.id] = true end
while #api.GetComposition(target).layers < 10 do local id = Add("surface"); assert(not ids[id]); ids[id] = true end
Equal(#slots, 10)
Rejected("layer_limit", function() return api.AddLayer(target, "line") end)
count = regionCount
assert(api.RemoveLayer(target, texture)); Neutral(slots[10])
assert(api.ClearComposition(target)); Equal(#api.GetComposition(target).layers, 0)
for _, r in ipairs(slots) do Neutral(r) end
assert(not a.frame._fpSectionFill or not a.frame._fpSectionFill:IsShown())
assert(api.ResetComposition(target)); Equal(api.GetComposition(target), nil)
assert(a.frame._fpSectionFill:IsShown())
Equal(a.frame._fpSectionFill.lastSetColorTexture, ns.GUI.Skins.GetFormPalette().Chrome.sectionFill)
local canonicalStyle = binding.ResolveSectionPresentation()
Equal(a.frame._fpSectionBorderTop.lastSetColorTexture, canonicalStyle.border.color)
Equal(a.frame._fpSectionAccent.lastSetColorTexture, canonicalStyle.surface.accent.color)
-- Canonical reset resolves current data; it does not copy a cached palette.
Add("texture")
local palette = ns.GUI.Skins.GetFormPalette()
local old = palette.Chrome.sectionFill
palette.Chrome.sectionFill = { 0.7, 0.6, 0.5, 0.4 }
assert(api.ResetComposition(target)); Equal(a.frame._fpSectionFill.lastSetColorTexture, palette.Chrome.sectionFill)
palette.Chrome.sectionFill = old
assert(api.ClearComposition(target)); assert(api.ResetComposition(target))
Equal(functionalWrites, beforeGeometry)

-- Minimum native InlineGroup height is content height + 40. Even a conservative
-- 40px-wide owner leaves positive surface area at the pilot's maximum insets.
local small = NewSection()
small:SetWidth(40); small:LayoutFinished(40, 0)
Equal(small.frame:GetHeight(), 40)
assert(api.ClearComposition(target))
local insetLayer = Add("surface", { insets = { left = 8, right = 8, top = 8, bottom = 8 } })
local sr = small.frame._fpCompositionRegions[1]
Equal(sr.points.TOPLEFT.x, 14); Equal(sr.points.BOTTOMRIGHT.x, -14)
assert(small.frame:GetWidth() - sr.points.TOPLEFT.x + sr.points.BOTTOMRIGHT.x > 0)
assert(small.frame:GetHeight() + sr.points.TOPLEFT.y - sr.points.BOTTOMRIGHT.y > 0)
local geometryAfterResize = functionalWrites
assert(api.UpdateLayer(target, insetLayer, "insets", { left = 0, right = 0, top = 0, bottom = 0 }))
Rejected("invalid_property", function() return api.UpdateLayer(target, insetLayer, "insets", { left = -1, right = 0, top = 0, bottom = 0 }) end)
Equal(functionalWrites, geometryAfterResize)
ace:Release(small)
assert(api.ResetComposition(target))

-- A texture-backed canonical fallback restores its material and every optional
-- surface part, without going through structure/padding/title rebuilds.
local chrome = ns.GUI.Skins.GetFormPalette().Chrome
local savedFill, savedBorder = chrome.sectionFill, chrome.sectionBorder
chrome.sectionFill, chrome.sectionBorder = nil, nil
local fallback = NewSection()
local fallbackStyle = binding.ResolveSectionPresentation("muted")
local savedDivider = fallbackStyle.surface.divider
fallbackStyle.surface.divider = { mode = "center_vertical", color = { 1, 0, 0, 1 }, thickness = 1 }
binding.ApplyInspectorSectionStructure(fallback, "muted")
local fallbackGeometry = functionalWrites
Add("surface")
for _, name in ipairs({ "Fill", "TopShade", "BottomShade", "Accent", "Divider", "BorderTop", "BorderBottom", "BorderLeft", "BorderRight" }) do
    local r = fallback.frame["_fpSection" .. name]; assert(r and not r:IsShown(), name)
end
assert(api.ResetComposition(target))
Equal(fallback.frame._fpSectionFill:GetTexture(), fallbackStyle.surface.texture)
Equal(fallback.frame._fpSectionFill.lastSetVertexColor, fallbackStyle.surface.tint)
assert(fallback.frame._fpSectionDivider:IsShown())
Equal(functionalWrites, fallbackGeometry)
fallbackStyle.surface.divider = savedDivider
ace:Release(fallback)
chrome.sectionFill, chrome.sectionBorder = savedFill, savedBorder

-- Release in combat is cleanup, not a public mutation. Foreign users see no composer state.
surface = Add("surface"); texture = Add("texture")
local callbacks = 0
local c = ace:Create("InlineGroup")
c:SetCallback("OnRelease", function() callbacks = callbacks + 1 end)
binding.ApplyInspectorSectionStructure(c)
binding.ApplyInspectorSectionStructure(c)
combat = true
for _, fn in ipairs({ function() return api.AddLayer(target, "line") end,
    function() return api.RemoveLayer(target, surface) end, function() return api.UpdateLayer(target, surface, "alpha", 1) end,
    function() return api.MoveLayer(target, surface, "up") end, function() return api.ClearComposition(target) end,
    function() return api.ResetComposition(target) end }) do Rejected("combat", fn) end
assert(api.GetComposition(target)); ace:Release(c); Equal(callbacks, 1)
for _, r in ipairs(c.frame._fpCompositionRegions) do Neutral(r) end
combat = false
local foreign = ace:Create("InlineGroup"); Equal(foreign, c)
assert(api.UpdateLayer(target, surface, "alpha", 0.3))
for _, r in ipairs(foreign.frame._fpCompositionRegions) do Neutral(r) end
ace:Release(foreign)
-- Warm both baseline and composer allocations before checking a stable high-water mark.
local pooled = NewSection(); ace:Release(pooled)
count = regionCount
for iteration = 1, 60 do
    pooled = NewSection(); Equal(pooled, c)
    Equal(pooled.frame._fpCompositionRegions[1].lastSetAlpha, { 0.3 })
    ace:Release(pooled)
    foreign = ace:Create("InlineGroup"); Equal(foreign, pooled)
    for _, r in ipairs(foreign.frame._fpCompositionRegions) do Neutral(r) end
    assert(api.MoveLayer(target, surface, "down"))
    for _, r in ipairs(foreign.frame._fpCompositionRegions) do Neutral(r) end
    ace:Release(foreign)
end
Equal(regionCount, count)
-- Real local collapse/expand path creates and binds each new body.
local host = ace:Create("SimpleGroup")
binding.CreateInspectorSection(host, ns.GUI.Editor.SidebarShared.CreateSection, {}, "test", "Section", false, nil, {
    localContentBuilder = function() end,
})
local toggle, body = host.children[1], host.children[2]
local headerBackground = toggle._sectionBg
toggle:Fire("OnClick"); toggle:Fire("OnClick") -- warm baseline restoration
count = regionCount
for iteration = 1, 60 do
    local previous = body.children[1]
    toggle:Fire("OnClick"); Equal(#body.children, 0)
    for _, r in ipairs(previous.frame._fpCompositionRegions) do Neutral(r) end
    toggle:Fire("OnClick"); Equal(#body.children, 1)
    assert(body.children[1].frame._fpCompositionRegions[1]:IsShown())
    Equal(toggle._sectionBg, headerBackground); assert(headerBackground:IsShown())
end
Equal(regionCount, count)
ace:Release(host)
assert(api.ResetComposition(target))
for _, owner in ipairs({ a, b }) do ace:Release(owner) end
-- Target discovery and Inspector shell isolation.
local discovered = api.GetTargets()
Equal(#discovered, 4)
Equal(discovered[1].id, "inspector_section")
Equal(discovered[2].id, "inspector_shell")
Equal(discovered[3].id, "sidebar_shell")
Equal(discovered[3].label, "Shell")
Equal(discovered[3].area, "Sidebar")
Equal(discovered[4].id, "sidebar_unit_navigator_inset")
Equal(discovered[4].label, "Unit Navigator Inset")
Equal(discovered[4].area, "Sidebar")
discovered[3].types[1] = "bad"
Equal(api.GetTargets()[3].types[1], "surface")
discovered[4].properties.surface[1] = "bad"
Equal(api.GetTargets()[4].properties.surface[1], "color")
local capsCopy = api.GetCapabilities()
capsCopy.targets[3].properties.surface[1] = "bad"
Equal(api.GetCapabilities().targets[3].properties.surface[1], "color")

local shell = ace:Create("SimpleGroup")
local shellCanonical = 0
local function ApplyShell(owner, canonicalOnly)
    local active = composition.Apply("inspector_shell", owner, nil, canonicalOnly)
    if not active then shellCanonical = shellCanonical + 1 end
end
composition.Bind("inspector_shell", shell, ApplyShell)
ApplyShell(shell)
assert(api.AddLayer("inspector_shell", "surface", { color = { 0.3, 0.4, 0.5 } }))
assert(api.AddLayer("inspector_shell", "line", { edge = "bottom", thickness = 2 }))
assert(api.AddLayer("inspector_shell", "texture", { alpha = 0.4 }))
local shellSurfaceId = api.GetComposition("inspector_shell").layers[1].id
assert(api.MoveLayer("inspector_shell", shellSurfaceId, "up"))
assert(api.ClearComposition("inspector_shell"))
Equal(#api.GetComposition("inspector_shell").layers, 0)
for _, region in ipairs(shell.frame._fpCompositionRegionsByTarget.inspector_shell) do Neutral(region) end
assert(api.AddLayer("inspector_shell", "surface", { color = { 0.3, 0.4, 0.5 } }))
assert(api.AddLayer("inspector_shell", "line", { edge = "bottom", thickness = 2 }))
assert(api.AddLayer("inspector_shell", "texture", { alpha = 0.4 }))
local shellSlots = shell.frame._fpCompositionRegionsByTarget.inspector_shell
assert(shellSlots[1]:IsShown() and shellSlots[2]:IsShown() and shellSlots[3]:IsShown())
Equal(api.GetComposition(target), nil) -- Shell state is independent from sections.
assert(api.AddLayer(target, "surface", { color = { 0.6, 0.5, 0.4 } }))
assert(api.GetComposition(target))
assert(api.GetComposition("inspector_shell"))
local ok, why = preview.Set("inspector_shell", "alpha", 0.5)
Equal(ok, false); Equal(why, "shell_composition_active")
assert(preview.Set("inspector_section_surface", "alpha", 0.5) == false)
local shellBeforeCombat = api.GetComposition("inspector_shell")
combat = true
local shellCombatOK, shellCombatReason = api.ClearComposition("inspector_shell")
Equal(shellCombatOK, false); Equal(shellCombatReason, "combat")
Equal(api.GetComposition("inspector_shell"), shellBeforeCombat)
combat = false
assert(api.ResetComposition("inspector_shell"))
assert(shellCanonical > 0)
for _, region in ipairs(shellSlots) do Neutral(region) end
assert(api.GetComposition("inspector_shell") == nil)
assert(api.GetComposition(target))
assert(api.ResetComposition(target))
composition.Release("inspector_shell", shell)
ace:Release(shell)

-- Sidebar shell discovery and multi-owner isolation. One descriptor may drive
-- the persistent AppShell underlay and the AceGUI toolbar window separately.
local sidebarUnderlay = CreateFrame("Frame", nil, UIParent)
local sidebarWindow = CreateFrame("Frame", nil, UIParent)
sidebarUnderlay._editorSidebar = sidebarUnderlay:CreateTexture(nil, "BACKGROUND")
sidebarUnderlay._editorSidebarBorder = sidebarUnderlay:CreateTexture(nil, "BORDER")
sidebarUnderlay._editorSidebar:Show()
sidebarUnderlay._editorSidebarBorder:Show()
local sidebarCanonical = 0
local function ApplySidebarShell(owner, canonicalOnly)
    local active = composition.Apply("sidebar_shell", owner, nil, canonicalOnly)
    if not active then
        sidebarCanonical = sidebarCanonical + 1
        if owner._editorSidebar then owner._editorSidebar:Show() end
        if owner._editorSidebarBorder then owner._editorSidebarBorder:Show() end
    end
end
composition.Bind("sidebar_shell", sidebarUnderlay, ApplySidebarShell)
composition.Bind("sidebar_shell", sidebarWindow, ApplySidebarShell)
ApplySidebarShell(sidebarUnderlay)
ApplySidebarShell(sidebarWindow)
assert(api.AddLayer("sidebar_shell", "surface", { color = { 0.2, 0.3, 0.4 } }))
assert(api.AddLayer("sidebar_shell", "line", { edge = "right", thickness = 2 }))
local sidebarUnderlaySlots = sidebarUnderlay._fpCompositionRegionsByTarget.sidebar_shell
local sidebarWindowSlots = sidebarWindow._fpCompositionRegionsByTarget.sidebar_shell
assert(#sidebarUnderlaySlots == 2 and #sidebarWindowSlots == 2)
assert(sidebarUnderlaySlots[1]:IsShown() and sidebarWindowSlots[1]:IsShown())
assert(not sidebarUnderlay._editorSidebar:IsShown())
local sidebarSurfaceId = api.GetComposition("sidebar_shell").layers[1].id
assert(api.AddLayer("sidebar_shell", "texture", { textureId = "blizzard", alpha = 0.4 }))
assert(api.AddLayer("sidebar_shell", "line", { edge = "bottom", thickness = 2 }))
assert(api.MoveLayer("sidebar_shell", sidebarSurfaceId, "up"))
assert(api.ClearComposition("sidebar_shell"))
Equal(#api.GetComposition("sidebar_shell").layers, 0)
assert(not sidebarUnderlaySlots[1]:IsShown() and not sidebarWindowSlots[1]:IsShown())
assert(api.AddLayer("sidebar_shell", "surface", { color = { 0.2, 0.3, 0.4 } }))
Equal(api.GetComposition("inspector_shell"), nil)
local sidebarPreviewOK, sidebarPreviewReason = preview.Set("sidebar_shell", "alpha", 0.5)
Equal(sidebarPreviewOK, false); Equal(sidebarPreviewReason, "sidebar_shell_composition_active")
assert(api.ResetComposition("sidebar_shell"))
assert(sidebarCanonical > 0)
for _, slotsForOwner in ipairs({ sidebarUnderlaySlots, sidebarWindowSlots }) do
    for _, region in ipairs(slotsForOwner) do Neutral(region) end
end
assert(api.GetComposition("sidebar_shell") == nil)
composition.Release("sidebar_shell", sidebarUnderlay)
composition.Release("sidebar_shell", sidebarWindow)
assert(api.AddLayer("inspector_shell", "surface", { color = { 0.4, 0.5, 0.6 } }))
assert(api.GetComposition("sidebar_shell") == nil)
assert(api.ResetComposition("inspector_shell"))

-- The UnitGrid inset is a distinct Sidebar target. Its canonical surface is
-- neutralized while composed, but UnitNavigatorItem state remains external.
local navigator = ace:Create("SimpleGroup")
local navigatorStyle = ns.GUI.Helpers.FormWidgets.ResolveSectionStyle("toolbar_explorer_inset")
local navigatorRenderer = ns.GUI.Helpers.FormSectionSurfaceRenderer
navigatorRenderer.ApplySectionSurface(navigator, navigatorStyle)
navigatorRenderer.ApplySectionBorder(navigator, navigatorStyle.border, navigatorStyle.surfaceInsets)
ns.GUI.PresentationPreview.BindSidebarNavigatorInset(navigator)
assert(navigator.frame._fpSectionFill:IsShown())
assert(preview.Set("sidebar_unit_navigator_inset", "alpha", 0.5))
local navigatorCompositionOK, navigatorCompositionReason = api.AddLayer("sidebar_unit_navigator_inset", "surface")
Equal(navigatorCompositionOK, false)
Equal(navigatorCompositionReason, "unit_navigator_inset_color_preview_active")
assert(preview.Clear("sidebar_unit_navigator_inset"))
assert(api.AddLayer("sidebar_unit_navigator_inset", "surface", { color = { 0.3, 0.2, 0.1 } }))
assert(api.AddLayer("sidebar_unit_navigator_inset", "line", { edge = "bottom", thickness = 2 }))
local navigatorSlots = navigator.frame._fpCompositionRegionsByTarget.sidebar_unit_navigator_inset
assert(#navigatorSlots == 2)
assert(navigatorSlots[1]:IsShown() and navigatorSlots[2]:IsShown())
assert(not navigator.frame._fpSectionFill:IsShown())
local navigatorBeforeReset = api.GetComposition("sidebar_unit_navigator_inset")
local navigatorPreviewOK, navigatorPreviewReason = preview.Set("sidebar_unit_navigator_inset", "alpha", 0.5)
Equal(navigatorPreviewOK, false)
Equal(navigatorPreviewReason, "unit_navigator_inset_composition_active")
assert(api.ResetComposition("sidebar_unit_navigator_inset"))
assert(api.GetComposition("sidebar_unit_navigator_inset") == nil)
assert(navigator.frame._fpSectionFill:IsShown())
assert(navigatorSlots[1]:GetTexture() == nil and not navigatorSlots[1]:IsShown())
assert(navigatorBeforeReset.layers[1].type == "surface")
ace:Release(navigator)
assert(api.GetComposition("sidebar_unit_navigator_inset") == nil)

-- A descriptor may exist before the pooled UnitGrid owner is rebuilt.
assert(api.AddLayer("sidebar_unit_navigator_inset", "surface", { color = { 0.4, 0.3, 0.2 } }))
local lateNavigator = ace:Create("SimpleGroup")
navigatorRenderer.ApplySectionSurface(lateNavigator, navigatorStyle)
navigatorRenderer.ApplySectionBorder(lateNavigator, navigatorStyle.border, navigatorStyle.surfaceInsets)
ns.GUI.PresentationPreview.BindSidebarNavigatorInset(lateNavigator)
local lateNavigatorSlots = lateNavigator.frame._fpCompositionRegionsByTarget.sidebar_unit_navigator_inset
assert(lateNavigatorSlots[1]:IsShown())
assert(not lateNavigator.frame._fpSectionFill:IsShown())
assert(api.ResetComposition("sidebar_unit_navigator_inset"))
assert(lateNavigator.frame._fpSectionFill:IsShown())
ace:Release(lateNavigator)

Load("GUI/Helpers/PresentationCompositionPreview.lua")
Equal(ns.Ace.PresentationCompositionPreview.GetComposition(target), nil)
assert(#env.errors == 0, table.concat(env.errors, "\n"))
print("PASS: composition validation/atomicity, regions/material reset, ordering, multi-owner, 60 pooling + 60 collapse cycles, conflicts, combat and functional geometry isolation")
