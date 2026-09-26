-- lua54 Tests/NavigatorBrassWindow.lua [path/to/Blizzard_SharedXML/NineSlice.lua]
-- Actual FP owners, composition and AceGUI pooling. Native rendering remains an ingame gate.
local env = dofile("Tests/FPCompactSlider.lua")
local ns, ace, native = env.ns, env.ace, env.native
ns.Ace = {}
STANDARD_TEXT_FONT = "Fonts\\FRIZQT__.TTF"
local combat, created = false, 0
function InCombatLockdown() return combat end
local create = CreateFrame
function CreateFrame(kind, name, parent, template)
    created = created + 1
    local frame = create(kind, name, parent)
    frame.template = template
    return frame
end
for _, method in ipairs({ "SetAllPoints", "SetFrameStrata", "SetFrameLevel", "SetIgnoreParentAlpha",
    "SetTexture", "SetTexCoord", "SetBlendMode", "SetColorTexture", "SetDrawLayer", "SetClampedToScreen",
    "SetToplevel", "Raise", "AddMaskTexture" }) do
    native[method] = function(self, ...) self["last" .. method] = { ... } end
end
function native:GetFrameLevel() return self.lastSetFrameLevel and self.lastSetFrameLevel[1] or 10 end
function native:GetParent() return self.parent end
function native:GetRegions() end
function native:GetNumPoints() return 0 end
function native:GetDrawLayer() return "OVERLAY", 0 end
function native:GetAlpha() return self.lastSetAlpha and self.lastSetAlpha[1] or 1 end
function native:GetTexture() return self.lastSetTexture and self.lastSetTexture[1] end
native.CreateMaskTexture = native.CreateTexture
UIParent:SetSize(1920, 1080)
local function Load(path) return assert(loadfile(path))("FocalPoint", ns) end
for _, path in ipairs({ "GUI/GUISkin.lua", "GUI/Helpers/PresentationPreview.lua",
    "Media/Decorations/DecorationManifest.lua", "Media/Textures/GUI/GUITextureManifest.lua",
    "Services/MediaRegistry.lua", "GUI/Helpers/PresentationCompositionPreview.lua",
    "GUI/Helpers/FormWidgets.lua", "Libraries/Ace3/AceGUI-3.0/widgets/AceGUIContainer-SimpleGroup.lua" }) do Load(path) end
local widgets, composition, api = ns.GUI.Helpers.FormWidgets, ns.GUI.PresentationCompositionPreview,
    ns.Ace.PresentationCompositionPreview
local function Equal(a, b)
    if a == b then return end
    if type(a) == "table" and type(b) == "table" then
        for k, v in pairs(a) do Equal(v, b[k]) end
        for k in pairs(b) do assert(a[k] ~= nil, "extra key " .. tostring(k)) end
    else assert(false, tostring(a) .. " ~= " .. tostring(b)) end
end
-- Offline native contract double. An optional unmodified client NineSlice.lua
-- exercises the same assertions through Blizzard's actual dispatcher/anchoring.
local setups = {
    { "TopLeftCorner", "TOPLEFT" }, { "TopRightCorner", "TOPRIGHT", mirrorHorizontal = true },
    { "BottomLeftCorner", "BOTTOMLEFT", mirrorVertical = true },
    { "BottomRightCorner", "BOTTOMRIGHT", mirrorHorizontal = true, mirrorVertical = true },
    { "TopEdge", "TOPLEFT", "TOPRIGHT", "TopLeftCorner", "TopRightCorner", tileHorizontal = true },
    { "BottomEdge", "BOTTOMLEFT", "BOTTOMRIGHT", "BottomLeftCorner", "BottomRightCorner", tileHorizontal = true, mirrorVertical = true },
    { "LeftEdge", "TOPLEFT", "BOTTOMLEFT", "TopLeftCorner", "BottomLeftCorner", tileVertical = true },
    { "RightEdge", "TOPRIGHT", "BOTTOMRIGHT", "TopRightCorner", "BottomRightCorner", tileVertical = true, mirrorHorizontal = true },
}
NineSliceLayouts = { PortraitFrameTemplate = {}, ButtonFrameTemplateNoPortrait = {} }
NineSliceUtil = { GetLayout = function(name) return NineSliceLayouts[name] end }
function NineSliceUtil.ApplyLayout(host, layout)
    for _, setup in ipairs(setups) do
        local key, definition = setup[1], layout[setup[1]]
        if definition then
            local piece = host[key]
            if not piece then piece = host:CreateTexture(); host[key] = piece; piece:SetDrawLayer(definition.layer) end
            piece:ClearAllPoints()
            piece:SetPoint(setup[2], setup[4] and host[setup[4]] or host, setup[3] or setup[2])
            if setup[5] then piece:SetPoint(setup[3], host[setup[5]], setup[2]) end
            layout.setupPieceVisualsFunction(host, piece, setup, definition)
        end
    end
end
function NineSliceUtil.ApplyLayoutByName(host, name) NineSliceUtil.ApplyLayout(host, NineSliceLayouts[name]) end
if arg[1] then dofile(arg[1]) end
local applyNamed = NineSliceUtil.ApplyLayoutByName
NineSliceUtil.ApplyLayoutByName = function(host, name) host.testLayoutName = name; return applyNamed(host, name) end

local oldCreate = ace.Create
local windows = {}
ace.Create = function(self, kind)
    if kind ~= "Window" and kind ~= "ScrollFrame" then return oldCreate(self, kind) end
    local owner = oldCreate(self, "SimpleGroup")
    function owner:SetTitle() end
    function owner:EnableResize() end
    function owner:SetStatusTable(status) self.status = status end
    function owner:Show() self.frame:Show() end
    if kind == "Window" then windows[#windows + 1] = owner end
    return owner
end
ns.GUI.Helpers.FormRenderer = { BuildLayout = function() return {}, {} end }
ns.GUI.Editor = { SidebarGeometry = { width = 285, inspectorWidth = 315, left = 0, right = 0, top = 0 },
    Inspector = { BuildProperties = function() end } }
Load("GUI/Editor/Toolbar/ToolbarController.lua")
Load("GUI/Editor/EditorController.lua")
ns.GUI.Editor.Toolbar.Open({}, {})
local sidebar = windows[1]
local state, deps = {}, {}
deps.GetEditorState = function() return state end
ns.GUI.Editor.Controller.BuildInspector(nil, deps)
local inspector = ns.GUI.Editor.Controller.GetActiveInspectorHost()
Equal(windows[2], inspector)
Equal(sidebar._fpNavigatorBrassTarget, "sidebar_shell")
Equal(inspector._fpNavigatorBrassTarget, "inspector_shell")
Equal(sidebar.frame:GetWidth(), 285); Equal(inspector.frame:GetWidth(), 315)
Equal(inspector._focalPointInspectorInset.points.TOPLEFT.x, 16)
Equal(inspector._focalPointInspectorInset.points.TOPLEFT.y, -10)
Equal(inspector._focalPointInspectorInset.points.BOTTOMRIGHT.x, -16)

local function Geometry(owner)
    local function Snapshot(frame)
        local points = {}
        for k, p in pairs(frame.points) do points[k] = { p.relative, p.relativePoint, p.x, p.y } end
        return { frame.parent, frame.nativeWidth, frame.nativeHeight, points }
    end
    return { Snapshot(owner.frame), Snapshot(owner.content), owner._focalPointInspectorInset and Snapshot(owner._focalPointInspectorInset) }
end
local borderKeys = { "PanelBorderTop", "PanelBorderBottom", "PanelBorderLeft", "PanelBorderRight",
    "PanelInnerTop", "PanelInnerBottom", "PanelInnerLeft", "PanelInnerRight", "PanelTopShade", "PanelBottomShade" }
local function Borders(owner, shown)
    for _, key in ipairs(borderKeys) do Equal(owner.frame["_fpSidebar" .. key]:IsShown(), shown) end
end
for _, owner in ipairs({ sidebar, inspector }) do
    local frame, geometry = owner.frame, Geometry(owner)
    local border = frame._fpNavigatorBrassNineSlice
    Equal(border.template, "NineSlicePanelTemplate"); Equal(border.parent, frame)
    Equal(border.lastSetAllPoints, { frame }); Equal(border:GetFrameLevel(), frame:GetFrameLevel() + 3)
    Equal(border.lastEnableMouse, { false }); Equal(border.Center, nil)
    Equal(border.TopLeftCorner.nativeWidth, 56); Equal(border.TopLeftCorner.nativeHeight, 56)
    Equal(border.TopEdge.nativeHeight, 56); Equal(border.LeftEdge.nativeWidth, 56)
    Equal(border.TopEdge.points.TOPLEFT.relative, border.TopLeftCorner)
    Equal(border.TopEdge.points.TOPRIGHT.relative, border.TopRightCorner)
    Equal(border.LeftEdge.points.TOPLEFT.relative, border.TopLeftCorner)
    Equal(border.LeftEdge.points.BOTTOMLEFT.relative, border.BottomLeftCorner)
    Equal(border.TopRightCorner.lastSetTexCoord, { 1, 0, 0, 1 })
    Equal(border.BottomLeftCorner.lastSetTexCoord, { 0, 1, 1, 0 })
    Equal(border.BottomRightCorner.lastSetTexCoord, { 1, 0, 1, 0 })
    Equal(border.BottomEdge.lastSetTexCoord, { 0, 1, 1, 0 })
    Equal(border.RightEdge.lastSetTexCoord, { 1, 0, 0, 1 })
    for _, setup in ipairs(setups) do
        local piece = border[setup[1]]
        Equal(piece.lastSetDrawLayer[1], "OVERLAY")
        Equal(piece.lastSetHorizTile, { setup.tileHorizontal == true })
        Equal(piece.lastSetVertTile, { setup.tileVertical == true })
        Equal(piece.lastSetTexture[2], setup.tileHorizontal and "REPEAT" or "CLAMP")
        Equal(piece.lastSetTexture[3], setup.tileVertical and "REPEAT" or "CLAMP")
        assert(piece:GetTexture():find("Interface\\AddOns\\FocalPoint\\Media\\Textures\\Window\\fp_navigator_brass_", 1, true))
    end
    Borders(owner, false)
    local fill = frame._fpSidebarPanelFill.lastSetColorTexture
    local count = created
    for cycle = 1, 50 do
        widgets.BindNavigatorBrassWindow(owner, owner._fpNavigatorBrassTarget)
        widgets.ApplyNavigatorBrassBorder(owner)
        assert(widgets.SetNavigatorBrassEnabled(owner, false)); Borders(owner, true)
        assert(not border:IsShown())
        assert(widgets.SetNavigatorBrassEnabled(owner, true)); Borders(owner, false)
        frame:Hide(); frame:Show()
    end
    Equal(created, count); Equal(Geometry(owner), geometry); Equal(frame._fpSidebarPanelFill.lastSetColorTexture, fill)
    combat = true
    local ok, reason = widgets.SetNavigatorBrassEnabled(owner, false)
    Equal(ok, false); Equal(reason, "combat"); assert(border:IsShown())
    combat = false
    local target = owner._fpNavigatorBrassTarget
    local ok, layer = api.AddLayer(target, "texture", { textureId = "fp:texture:fp-mahagony-128x128", alpha = .6 })
    assert(ok, layer)
    local descriptor = api.GetComposition(target)
    assert(border:IsShown()); Borders(owner, false)
    assert(widgets.SetNavigatorBrassEnabled(owner, false)); Borders(owner, false)
    Equal(api.GetComposition(target), descriptor)
    assert(widgets.SetNavigatorBrassEnabled(owner, true))
    Equal(api.GetComposition(target), descriptor)
    assert(api.ResetComposition(target)); assert(border:IsShown()); Borders(owner, false)
    assert(widgets.SetNavigatorBrassEnabled(owner, false)); Borders(owner, true)
    Equal(frame._fpSidebarPanelBorderTop.lastSetColorTexture, ns.GUI.Skins.GetFormPalette().Chrome.panelBorder)
    assert(widgets.SetNavigatorBrassEnabled(owner, true))
    Equal(Geometry(owner), geometry)
end

-- A second sidebar_shell owner (AppShell underlay) receives composition only.
local underlay = ace:Create("SimpleGroup")
widgets.ApplySidebarChrome(underlay, "sidebar_shell")
composition.Bind("sidebar_shell", underlay, function(owner, canonical)
    composition.Apply("sidebar_shell", owner, nil, canonical)
end)
assert(api.AddLayer("sidebar_shell", "surface", { color = { .2, .1, .05 } }))
Equal(underlay.frame._fpNavigatorBrassNineSlice, nil)
Equal(widgets.ApplyNavigatorBrassBorder(underlay), false)
assert(api.ResetComposition("sidebar_shell"))

local sidebarBorder, inspectorBorder = sidebar.frame._fpNavigatorBrassNineSlice, inspector.frame._fpNavigatorBrassNineSlice
for cycle = 1, 50 do
    ns.GUI.Editor.Toolbar.Hide(); ns.GUI.Editor.Toolbar.Open({}, {})
    ns.GUI.Editor.Controller.ReleaseInspector(); ns.GUI.Editor.Controller.BuildInspector(nil, deps)
    Equal(sidebar.frame._fpNavigatorBrassNineSlice, sidebarBorder)
    Equal(inspector.frame._fpNavigatorBrassNineSlice, inspectorBorder)
    Borders(sidebar, false); Borders(inspector, false)
end
Equal(#windows, 2)
assert(widgets.SetNavigatorBrassEnabled(sidebar, false))
ns.GUI.Editor.Toolbar.Hide(); ns.GUI.Editor.Toolbar.Open({}, {})
assert(not sidebarBorder:IsShown()); assert(inspectorBorder:IsShown())
Borders(sidebar, true)
assert(widgets.SetNavigatorBrassEnabled(sidebar, true))
local function Copy(value)
    if type(value) ~= "table" then return value end
    local result = {}; for k, v in pairs(value) do result[k] = Copy(v) end; return result
end
local alternate = Copy(ns.GUI.Skins.GetActiveSkin())
alternate.formPalette.Chrome.panelBorder = { .12, .23, .34, .45 }
ns.GUI.Skins.Register("brass_reset_test", alternate)
ns.GUI.Skins.SetActiveSkin("brass_reset_test")
assert(widgets.SetNavigatorBrassEnabled(sidebar, false))
Equal(sidebar.frame._fpSidebarPanelBorderTop.lastSetColorTexture, alternate.formPalette.Chrome.panelBorder)
ns.GUI.Skins.SetActiveSkin("default")
assert(widgets.SetNavigatorBrassEnabled(sidebar, true))

local pooled = ace:Create("SimpleGroup")
local released = 0
for cycle = 1, 50 do
    pooled:SetCallback("OnRelease", function() released = released + 1 end)
    widgets.ApplySidebarChrome(pooled, "sidebar_shell")
    widgets.BindNavigatorBrassWindow(pooled, "sidebar_shell")
    widgets.BindNavigatorBrassWindow(pooled, "sidebar_shell")
    composition.Bind("sidebar_shell", pooled, function() error("released owner leaked") end)
    local old, border = pooled, pooled.frame._fpNavigatorBrassNineSlice
    ace:Release(pooled)
    assert(not border:IsShown()); Equal(pooled._fpNavigatorBrassTarget, nil)
    assert(api.ResetComposition("sidebar_shell"))
    pooled = ace:Create("SimpleGroup"); Equal(pooled, old)
end
Equal(released, 50)

-- Shared host preserves the established Modern named layout, title and portrait levels.
local modern = ace:Create("SimpleGroup")
modern.title = CreateFrame("Button", nil, modern.frame)
modern.closebutton = CreateFrame("Button", nil, modern.frame)
modern.titletext = modern.frame:CreateFontString()
local geometry = Geometry(modern)
for _, portrait in ipairs({ true, false }) do
    for cycle = 1, 3 do
        widgets.ApplyModernWindowChrome(modern, { nineSlice = true, portrait = portrait, portraitTexture = "portrait.png" })
        local border = modern.frame._fpModernNineSlice
        Equal(border.testLayoutName, portrait and "PortraitFrameTemplate" or "ButtonFrameTemplateNoPortrait")
        Equal(border:GetFrameLevel(), modern.frame:GetFrameLevel() + 3)
        Equal(modern.title:GetFrameLevel(), modern.frame:GetFrameLevel() + 4)
        Equal(modern.closebutton:GetFrameLevel(), modern.frame:GetFrameLevel() + 5)
        assert(border:IsShown()); Equal(modern.frame._fpNavigatorBrassNineSlice, nil)
        if portrait then Equal(modern.frame._fpModernPortraitContainer:GetFrameLevel(), modern.frame:GetFrameLevel() + 2) end
        Equal(Geometry(modern), geometry)
    end
end
assert(#env.errors == 0, table.concat(env.errors, "\n"))
print("PASS: real Sidebar/Inspector bindings, eight mirrored slices, canonical reset, composition isolation, geometry, combat, 50 reopen/pooling cycles, Modern window contract")
