-- lua54 Tests/CanvasToolbarPresentation.lua
-- Real toolbar, AppShell lifecycle and AceGUI controls; native rendering and
-- layout activation are simulated. Pixel filtering/hit testing remain ingame gates.
local file = assert(io.open("Tests/DialogWindowFamily.lua"))
local source = file:read("*a"); file:close()
local stop = assert(source:find("local created,latest=", 1, true))
local f = assert(load(source:sub(1, stop - 1) .. "\nreturn f", "@Canvas/NativeFixture"))()
local ns, forms, Equal, Load = f.ns, f.widgets, f.Equal, f.Load
Load("GUI/Editor/Toolbar/ToolbarBinding.lua")
Load("GUI/Editor/CanvasToolbar.lua")
Load("GUI/AppShell.lua")
local toolbar, shell = ns.GUI.Editor.CanvasToolbar, ns.GUI.AppShell
ns.GUI.Editor.SidebarGeometry = { width = 285, inspectorWidth = 315 }
local ensure = f.Upvalue(toolbar.UpdateGeometry, "EnsureHost")
local combat, activation, pending = false, nil, nil
function InCombatLockdown() return combat end
ns.ActivateLayout = function(_, id)
    activation = id
    if combat then pending = id; return false, "pending" end
    ns.db.char.activeLayoutId = id; return true
end
local notices = {}
ns.Info = function(_, message) notices[#notices + 1] = message end
ns.LayoutAssignmentService = { GetAssignmentForCurrentSpecialization = function()
    return "layout:one", "ok", 1, "Fixture Specialization"
end }

-- Capture the actual owner's geometry, visuals and callbacks before styling.
local apply = forms.ApplyCanvasToolbarPresentation
local initialApplies = 0
forms.ApplyCanvasToolbarPresentation = function() initialApplies = initialApplies + 1 end
shell.AssignEditorRuntimeRoles(ns)
Equal(initialApplies, 2) -- Both creation and the existing Show path apply presentation.
local context = ensure()
local host, controls = context.host, context.widgets
assert(host:IsShown())
local function Shallow(t)
    local result = {}; for k, v in pairs(t or {}) do result[k] = v end; return result
end
local function Geometry(region)
    local points = {}
    for key, p in pairs(region.points) do points[key] = { p.relative, p.relativePoint, p.x, p.y } end
    return { region.parent, region.nativeWidth, region.nativeHeight, points,
        region.lastSetFrameStrata, region.lastSetFrameLevel, region.lastEnableMouse,
        region.lastSetHitRectInsets, Shallow(region.scripts) }
end
local function ControlState()
    local result = {}
    for key, control in pairs(controls) do
        local region = control.frame or control
        result[key] = { Geometry(region), Shallow(control.events), region.text,
            region.font, region.lastSetTextColor, region.lastSetAlpha }
        if control.dropdown then
            result[key].dropdown = Geometry(control.dropdown)
            result[key].button = Geometry(control.button)
            result[key].cover = Geometry(control.button_cover)
        end
    end
    return result
end
local baseline, hostGeometry = ControlState(), Geometry(host)
Equal({ host:GetWidth(), host:GetHeight() }, { 662, 50 })
Equal(host.points.TOP, { relative = ns.guiEditorWorkspaceLayer, relativePoint = "TOP", x = -15, y = -12 })
Equal(host.lastSetFrameStrata, { "DIALOG" }); Equal(host:GetFrameLevel(), 140)
Equal(host.lastEnableMouse, { true })
local old = {}
for _, key in ipairs({ "bg", "border", "inset" }) do
    local region = host[key]
    old[key] = { region, Geometry(region), region.lastSetColorTexture, region:IsShown() }
end
forms.ApplyCanvasToolbarPresentation = apply
assert(apply(host))
local material = ns.GUI.Skins.GetFormPalette().Chrome.navigatorShellSurface
local resolved = ns.MediaRegistry.ResolveReference(material.textureId, "texture")
assert(resolved.available and not resolved.fallbackUsed)
local border, surface = host._fpCanvasBrassNineSlice, host._fpCanvasMaterial
local function Check()
    Equal(Geometry(host), hostGeometry); Equal(ControlState(), baseline)
    assert(border:IsShown() and surface:IsShown())
    Equal(surface:GetTexture(), resolved.resolvedAsset)
    Equal(surface.lastSetVertexColor, material.tint)
    Equal(surface.lastSetAlpha, { 1 })
    Equal(surface.points, {
        TOPLEFT = { relative = host, relativePoint = "TOPLEFT", x = 2, y = -2 },
        BOTTOMRIGHT = { relative = host, relativePoint = "BOTTOMRIGHT", x = -2, y = 2 },
    })
    Equal(surface.lastSetDrawLayer, { "BACKGROUND", -8 })
    Equal(surface.lastSetHorizTile, { false }); Equal(surface.lastSetVertTile, { false })
    Equal(border.lastEnableMouse, { false }); Equal(border.lastSetAllPoints, { host })
    Equal(border:GetFrameLevel(), 143)
    assert(not host._fpNavigatorBrassTarget and not host._fpNavigatorBrassNineSlice)
    assert(not border.Center)
    local count = 0
    for _, spec in ipairs({
        { "TopLeftCorner", 24, 24, {0,1,0,1}, false, false },
        { "TopRightCorner", 24, 24, {1,0,0,1}, false, false },
        { "BottomLeftCorner", 24, 24, {0,1,1,0}, false, false },
        { "BottomRightCorner", 24, 24, {1,0,1,0}, false, false },
        { "TopEdge", 48, 24, {0,1,0,1}, true, false },
        { "BottomEdge", 48, 24, {0,1,1,0}, true, false },
        { "LeftEdge", 24, 48, {0,1,0,1}, false, true },
        { "RightEdge", 24, 48, {1,0,0,1}, false, true },
    }) do
        local piece = assert(border[spec[1]])
        assert(piece:IsShown()); count = count + 1
        Equal({piece.nativeWidth, piece.nativeHeight}, {spec[2], spec[3]})
        Equal(piece.lastSetTexCoord, spec[4])
        Equal(piece.lastSetHorizTile, {spec[5]}); Equal(piece.lastSetVertTile, {spec[6]})
    end
    Equal(count, 8); Equal(#{border:GetRegions()}, 8)
    for key, state in pairs(old) do
        Equal(host[key], state[1]); Equal(Geometry(host[key]), state[2])
        Equal(host[key].lastSetColorTexture, state[3]); assert(not host[key]:IsShown())
    end
end
Check()
-- Descriptor is consumed on every apply, not copied into a Canvas theme.
local tint = material.tint
material.tint = { 0.21, 0.32, 0.43, 0.54 }
apply(host); Equal(surface.lastSetVertexColor, material.tint)
material.tint = tint; apply(host)

local count = f.Count()
for i = 1, 50 do assert(apply(host)); Check() end
Equal(f.Count(), count)
for i = 1, 50 do
    toolbar.Hide(); assert(not host:IsShown())
    toolbar.Show(); assert(host:IsShown() and ensure() == context); Check()
end
Equal(f.Count(), count)
for i = 1, 50 do
    shell.ClearEditorRuntimeRoles(ns); assert(not host:IsShown())
    ns.framesUnlocked = i % 2 == 0
    shell.AssignEditorRuntimeRoles(ns); Check()
end
Equal(f.Count(), count)
forms.RestoreCanvasToolbarPresentation(host)
assert(not border:IsShown() and not surface:IsShown())
for key, state in pairs(old) do Equal(host[key]:IsShown(), state[4]) end
forms.RestoreCanvasToolbarPresentation(host)
host.inset:Hide(); apply(host); forms.RestoreCanvasToolbarPresentation(host)
assert(not host.inset:IsShown()); host.inset:Show(); apply(host); Check()
Equal(f.Count(), count)
-- Missing material falls back locally and does not leave a half-styled host.
local resolve = ns.MediaRegistry.ResolveReference
ns.MediaRegistry.ResolveReference = function() return { available = false } end
assert(not apply(host)); assert(not border:IsShown())
assert(host.bg:IsShown() and host.border:IsShown() and host.inset:IsShown())
ns.MediaRegistry.ResolveReference = resolve; assert(apply(host)); Check()

-- Project existing runtime alpha onto unchanged content bounds. No images are
-- generated: read the uncompressed 32-bit TGA source pixels and sample in memory.
local function Alpha(name, width, height)
    local input = assert(io.open("Media/Textures/Window/fp_navigator_brass_" .. name .. ".tga", "rb"))
    local bytes = input:read("*a"); input:close()
    Equal(bytes:byte(3), 2); Equal(bytes:byte(17), 32)
    Equal(string.unpack("<I2", bytes, 13), width); Equal(string.unpack("<I2", bytes, 15), height)
    local topDown = (bytes:byte(18) & 32) ~= 0
    return function(x, y)
        if not topDown then y = height - 1 - y end
        return bytes:byte(18 + bytes:byte(1) + (y * width + x) * 4 + 4)
    end
end
local corner, horizontal, vertical = Alpha("corner", 128, 128), Alpha("horizontal", 256, 128), Alpha("vertical", 128, 256)
for i = 0, 127 do
    Equal(corner(127, i), horizontal(0, i)); Equal(corner(i, 127), vertical(i, 0))
    Equal(horizontal(0, i), horizontal(255, i)); Equal(vertical(i, 0), vertical(i, 255))
    for j = 0, 255 do Equal(horizontal(j, i), vertical(i, j)) end
end
local function Sample(alpha, x, y)
    x = math.max(0, math.min(127, (x + 0.5) * 128 / 24 - 0.5))
    y = math.max(0, math.min(127, (y + 0.5) * 128 / 24 - 0.5))
    local ix, iy = math.floor(x), math.floor(y)
    local dx, dy = x - ix, y - iy
    return alpha(ix, iy) * (1-dx) * (1-dy) + alpha(math.min(ix+1,127), iy) * dx * (1-dy)
        + alpha(ix, math.min(iy+1,127)) * (1-dx) * dy + alpha(math.min(ix+1,127), math.min(iy+1,127)) * dx * dy
end
local function Rail(_, y) return horizontal(0, y) end
for _, rect in ipairs({
    {12,10,44,11}, {58,6,142,24}, {224,10,44,11}, {270,5,156,26},
    {430,6,30,24}, {468,6,148,24}, {224,31,418,12},
}) do
    for x = rect[1], rect[1]+rect[3]-1 do
        for y = rect[2], rect[2]+rect[4]-1 do
            local xx, yy = math.min(x,661-x), math.min(y,49-y)
            local alpha = xx < 24 and yy < 24 and Sample(corner,xx,yy)
                or yy < 24 and Sample(Rail,0,yy) or xx < 24 and Sample(Rail,0,xx) or 0
            Equal(alpha, 0)
        end
    end
end

-- Exercise actual click wiring and actual dropdown opening, without replacing controls.
local opened = {}
local createDialog = forms.CreateCompactFormDialog
forms.CreateCompactFormDialog = function(options)
    local dialog = createDialog(options); opened[#opened + 1] = dialog; return dialog
end
controls.addObjectButton:Fire("OnClick"); assert(#opened == 1)
opened[1].cancelButton:Fire("OnClick")
controls.layoutAddButton:Fire("OnClick"); assert(#opened == 2)
opened[2].cancelButton:Fire("OnClick")
local managed = 0
ns.GUI.Editor.LayoutManager.Open = function() managed = managed + 1 end
controls.layoutManageButton:Fire("OnClick"); Equal(managed, 1)
local dropdown = controls.layoutDropdown
dropdown.button:Run("OnClick"); assert(dropdown.open and dropdown.pullout.frame:IsShown())
dropdown.button:Run("OnClick"); assert(not dropdown.open)
dropdown:Fire("OnValueChanged", "builtin:default")
Equal(activation, "builtin:default"); Equal(ns.db.char.activeLayoutId, "builtin:default")
assert(controls.layoutAutomationLabel:IsShown())
combat = true
assert(apply(host)) -- Presentation has no combat guard and does not activate layouts.
dropdown:Fire("OnValueChanged", "layout:one")
Equal(pending, "layout:one"); Equal(ns.db.char.activeLayoutId, "builtin:default")
assert(notices[#notices]:find("pending", 1, true))
combat = false
ns:ActivateLayout(pending); pending = nil; toolbar.Refresh()
Equal(ns.db.char.activeLayoutId, "layout:one")
-- Global-default marker decorates labels only; it never changes IDs or activation.
local defaultId="builtin:default"
ns.LayoutAssignmentService.GetAccountDefaultLayoutId=function() return defaultId end
local currentId=ns.db.char.activeLayoutId
toolbar.Refresh()
Equal(dropdown.list["builtin:default"],"Built-in: Default [Default]")
Equal(dropdown.list["layout:one"],"My: One")
Equal(ns.db.char.activeLayoutId,currentId)
-- Manager action refreshes both real surfaces, without triggering OnValueChanged.
local manager=ns.GUI.Editor.LayoutManager
local refreshList=f.Upvalue(manager.Refresh,"RefreshList")
local managerContext=f.Upvalue(refreshList,"context")
ns.LayoutAssignmentService.SetAccountDefaultLayoutId=function(id) defaultId=id; return true end
managerContext.selectedLayoutId="layout:one"; manager.Refresh()
managerContext.widgets.defaultButton:Fire("OnClick")
Equal(defaultId,"layout:one")
Equal(dropdown.list["builtin:default"],"Built-in: Default")
Equal(dropdown.list["layout:one"],"My: One [Default]")
Equal(ns.db.char.activeLayoutId,currentId)
managerContext.widgets.defaultButton:Fire("OnClick")
Equal(defaultId,nil); Equal(dropdown.list["layout:one"],"My: One")
Equal(ns.db.char.activeLayoutId,currentId)
forms.CreateCompactFormDialog = createDialog
assert(#f.env.errors == 0, table.concat(f.env.errors, "\n"))
print("PASS: Canvas material/8 slices, unchanged geometry/controls/callbacks, reset/fallback, 50 apply + 50 show/hide + 50 shell cycles, buttons/dropdown and simulated combat/layout activation")
