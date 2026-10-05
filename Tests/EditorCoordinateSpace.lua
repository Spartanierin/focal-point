-- lua54 Tests/EditorCoordinateSpace.lua
-- Actual move/commit, snap and resize projection code. Native frame coordinates
-- are modelled in each frame's effective-scale units; this is not an ingame test.
local function Near(actual, expected, context)
    assert(type(actual) == "number" and math.abs(actual - expected) < 1e-8,
        (context or "coordinate") .. ": " .. tostring(actual) .. " ~= " .. tostring(expected))
end
local function Noop() end
local function Surface()
    local s = { scripts = {} }
    for _, key in ipairs({"SetFrameStrata", "SetFrameLevel", "SetSize", "SetColorTexture",
        "SetAllPoints", "SetBackdrop", "SetBackdropBorderColor", "SetRotation",
        "EnableMouse", "RegisterForDrag", "ClearAllPoints"}) do s[key] = Noop end
    function s:SetPoint(...) self.point = {...} end
    function s:SetScript(event, callback) self.scripts[event] = callback end
    function s:Show() self.shown = true end
    function s:Hide() self.shown = false end
    function s:CreateTexture() return Surface() end
    return s
end
CreateFrame = Surface
InCombatLockdown = function() return false end
UIParent = { scale = 1 }
function UIParent:GetEffectiveScale() return self.scale end
function UIParent:GetCenter() return 960, 540 end
function UIParent:GetWidth() return 1920 end
function UIParent:GetHeight() return 1080 end
local cursorX, cursorY = 300, 400
GetCursorPosition = function() return cursorX, cursorY end
local configs = {}
local ns = {
    framesUnlocked = true, frames = {}, L = {},
    GUI = { Editor = {} }, db = { profile = { General = { SnappingEnabled = false } } },
    UnitFrameUtils = { GetUnitDB = function(unit) return configs[unit] end },
    ActiveLayoutResolver = { GetEditableActiveUnits = function() return configs end },
    LayoutEditWorkflow = { RequestEditableLayoutForMutation = function(action) action(); return true end },
    IsEditorActive = function() return true end,
}
local function Load(path) assert(loadfile(path))("FocalPoint", ns) end
-- Same order as Init.xml: Core looks up the projection at interaction time.
Load("Engine/Core.lua")
Load("Engine/UnitFrame/Runtime/UnitFrameLayout.lua")
Load("GUI/Editor/FrameSnapLines.lua")
Load("GUI/Editor/FrameResizeHandles.lua")
ns.RefreshEditorSelectionVisuals = Noop
local layout, snap = ns.UnitFrameLayout, ns.GUI.Editor.FrameSnapLines
local function Frame(unit, scale, x, y, width, height, extension)
    local f = Surface()
    f._fpUnit, f.scale = unit, scale * UIParent.scale
    f.width, f.height = width or 120, (height or 40) + (extension or 0)
    f.shown = true
    function f:GetEffectiveScale() return self.scale end
    function f:GetWidth() return self.width end
    function f:GetHeight() return self.height end
    function f:GetCenter() return self.centerX, self.centerY end
    function f:IsShown() return self.shown end
    function f:ClearAllPoints() end
    function f:SetPoint(point, parent, relativePoint, dx, dy)
        assert(point == "CENTER" and relativePoint == "CENTER")
        local px, py = parent:GetCenter()
        local ratio = parent:GetEffectiveScale() / self:GetEffectiveScale()
        self.centerX, self.centerY = px * ratio + dx, py * ratio + dy
    end
    configs[unit] = { point = "CENTER", relativePoint = "CENTER", relativeTo = "UIParent",
        x = x, y = y, width = f.width, height = height or 40, scale = scale }
    ns.frames[unit] = f
    ns:ApplyStoredFramePosition(f)
    return f
end
local function Position(frame, x, y)
    local cx, cy = layout.GetFrameCenterOffsets(frame, UIParent)
    cx, cy = layout.ProjectRootCenterToConfigCenter(frame, configs[frame._fpUnit], cx, cy)
    Near(cx, x, "visible/config X"); Near(cy, y, "visible/config Y")
end
local cases = 0
for _, parentScale in ipairs({1, 0.64}) do
    UIParent.scale = parentScale
    for _, scale in ipairs({0.5, 0.75, 1, 1.25, 1.5}) do
        for _, pos in ipairs({{0,0}, {137,83}, {-211,-97}, {153,-71}}) do
            for _, extension in ipairs({0, 5}) do
                ns.frames = {}
                local f = Frame("target", scale, pos[1], pos[2], 120, 40, extension)
                Position(f, pos[1], pos[2])
                assert(ns:BeginEditorUnitFrameDrag(f))
                f.scripts.OnUpdate(f) -- no cursor movement must never move the frame
                Position(f, pos[1], pos[2])
                cursorX, cursorY = cursorX + 37 * parentScale, cursorY - 19 * parentScale
                f.scripts.OnUpdate(f)
                Position(f, pos[1] + 37, pos[2] - 19)
                ns:EndEditorUnitFrameDrag(f, true)
                Near(configs.target.x, pos[1] + 37, "saved X")
                Near(configs.target.y, pos[2] - 19, "saved Y")
                -- Recreate native frame and apply persisted config, as after reload.
                local saved = configs.target
                local reopened = Frame("target", scale, saved.x, saved.y, 120, 40, extension)
                Position(reopened, saved.x, saved.y)
                assert(ns:BeginEditorUnitFrameDrag(reopened))
                cursorX = cursorX + 11 * parentScale
                reopened.scripts.OnUpdate(reopened)
                ns:EndEditorUnitFrameDrag(reopened, false)
                Position(reopened, saved.x, saved.y)
                cases = cases + 1
            end
        end
    end
end
print("PASS: " .. cases .. " actual move/start/delta/commit/reapply/cancel roundtrips")

ns.db.profile.General.SnappingEnabled = true
assert(snap.SNAP_THRESHOLD == 6)
local snapCases = 0
for _, parentScale in ipairs({1, 0.64}) do
    UIParent.scale = parentScale
    for _, movingScale in ipairs({0.5, 0.75, 1, 1.25, 1.5}) do
        for _, targetScale in ipairs({0.5, 0.75, 1, 1.25, 1.5}) do
            ns.frames = {}
            local moving = Frame("target", movingScale, -400, -200)
            Frame("player", targetScale, 300, 200, 400, 240)
            local w, h = layout.GetFrameSizeInParent(moving, UIParent)
            Near(w, 120 * movingScale); Near(h, 40 * movingScale)
            for _, side in ipairs({-1, 0, 1}) do
                local expectedX = 300 + side * (200 * targetScale - 60 * movingScale)
                local expectedY = 200 + side * (120 * targetScale - 20 * movingScale)
                local x, y = snap.Apply(moving, expectedX + 2, expectedY - 2)
                Near(x, expectedX, "snap X"); Near(y, expectedY, "snap Y")
                Near(snap.lines.vertical.point[4], 300 + side * 200 * targetScale, "guide X")
                Near(snap.lines.horizontal.point[5], 200 + side * 120 * targetScale, "guide Y")
            end
            -- Actual drag with snapping: first tick stays put; commit keeps snap.
            assert(ns:BeginEditorUnitFrameDrag(moving))
            moving.scripts.OnUpdate(moving)
            Position(moving, -400, -200)
            cursorX, cursorY = cursorX + 702 * parentScale, cursorY + 398 * parentScale
            moving.scripts.OnUpdate(moving)
            Position(moving, 300, 200)
            ns:EndEditorUnitFrameDrag(moving, true)
            Position(moving, 300, 200)
            snapCases = snapCases + 1
        end
    end
end
print("PASS: " .. snapCases .. " same/mixed-scale snap center/edge/guide and drag cases")

-- Capture the actual resize handler through its public handle construction.
-- Only its existing center fallback is under test, not resize delta semantics.
local function Upvalue(fn, wanted)
    for i = 1, math.huge do
        local name, value = debug.getupvalue(fn, i)
        if not name then break end
        if name == wanted then return value end
    end
    error("missing test boundary: " .. wanted)
end
ns.frames = {}
local f = Frame("target", 1.5, 127, -63)
f.MoveOverlay = Surface()
ns.GUI.Editor.FrameResizeHandles.UpdateFrame(f)
local beginResize = Upvalue(f.ResizeHandle.scripts.OnDragStart, "BeginResize")
local resolveCenter = Upvalue(beginResize, "ResolveConfigCenter")
for _, scale in ipairs({0.5, 0.75, 1, 1.25, 1.5}) do
    local resized = Frame("target", scale, 127, -63, 120, 40, 5)
    local x, y = resolveCenter(resized, {}, 5, 0)
    Near(x, 127, "resize fallback X"); Near(y, -63, "resize fallback Y")
    x, y = resolveCenter(resized, {x=12,y=34}, 5, 0)
    Near(x, 12); Near(y, 34)
end
print("PASS: resize center fallback shares projection; explicit config center unchanged")
