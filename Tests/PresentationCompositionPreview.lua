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
Load("GUI/Helpers/PresentationCompositionPreview.lua")
Equal(ns.Ace.PresentationCompositionPreview.GetComposition(target), nil)
assert(#env.errors == 0, table.concat(env.errors, "\n"))
print("PASS: composition validation/atomicity, regions/material reset, ordering, multi-owner, 60 pooling + 60 collapse cycles, conflicts, combat and functional geometry isolation")
