-- M1b Arrange alpha regression. Real alpha decision/application and Core chrome;
-- native alpha inheritance, hit testing, forbidden aura children and taint are NOT simulated.
local file = assert(io.open("Tests/DialogWindowFamily.lua"))
local source = file:read("*a"); file:close()
local boundary = assert(source:find("local created,latest=", 1, true))
local f = assert(load(source:sub(1, boundary - 1) .. "\nreturn f", "@ArrangeAlphaProof/Fixture"))()
local ns, Load, native, Equal = f.ns, f.Load, f.native, f.Equal
for _, name in ipairs({"RegisterEvent", "RegisterForDrag", "RegisterForClicks", "SetAttribute", "SetRotation", "SetScale", "SetMouseClickEnabled"}) do
    native[name] = function(self, ...) self["last" .. name] = {...} end
end
function native:GetFrameStrata() return self.lastSetFrameStrata and self.lastSetFrameStrata[1] or "MEDIUM" end
function native:GetEffectiveScale() return self.lastSetScale and self.lastSetScale[1] or 1 end
function native:GetCenter() return 0, 0 end
local editorOpen, combat = true, false
function ns:IsEditorActive() return editorOpen end
InCombatLockdown = function() return combat end
UnitExists = function() return true end
UnitIsDeadOrGhost = function() return false end
UnitIsConnected = function() return true end
UnitCanAttack = function() return true end
UnitCanAssist = function() return false end
issecretvalue = function() return false end
Load("Data/Constants.lua")
Load("GUI/Editor/EditorState.lua")
local units = {
    player = {present=true, enabled=true, alpha=0.65, width=120, height=40, x=0, y=0},
    target = {present=true, enabled=true, alpha=0.8, width=140, height=50, x=100, y=50},
}
for _, unit in ipairs({"targettarget", "pet", "focus", "focustarget", "boss"}) do
    units[unit] = {present=true, enabled=true, alpha=0.6, width=120, height=40, x=50, y=20}
end
units.pet.alpha = 0 -- Editor chrome must also remain available for configured zero alpha.
Load("Engine/UnitFrame/Shared/UnitFrameUtils.lua")
ns.UnitFrameUtils.GetUnitsDB = function() return units end
Load("Engine/UnitFrame/Shared/UnitFramePresence.lua")
Load("Engine/UnitFrame/Shared/UnitFrameDemoEnvironment.lua")
Load("Engine/UnitFrame/Shared/UnitFramePreview.lua")
Load("Engine/UnitFrame/Shared/UnitFrameRange.lua")
Load("Engine/UnitFrame/Runtime/UnitFrameVisibility.lua")
Load("Engine/UnitFrame/Runtime/UnitFrameLayout.lua")
Load("Engine/UnitFrame.lua")
Load("Engine/Core.lua")
Load("GUI/Editor/EditorInteractionMode.lua")
Load("GUI/Editor/FrameResizeHandles.lua")
Load("GUI/Editor/EditorController.lua")
ns.GUI.RequestRefreshOptions = function() end -- GUI rebuilding has its own EditorPresentation suite.
local function Frame(unit)
    local frame = CreateFrame("Button", nil, UIParent)
    local config = ns.UnitFrameUtils.GetUnitDB(unit)
    frame._fpUnit, frame.config, frame.Elements = unit, config, {}
    frame:SetPoint("CENTER", UIParent, "CENTER", config.x, config.y)
    frame:SetSize(config.width, config.height)
    return frame
end
local player, target = Frame("player"), Frame("target")
ns.frames = {player=player, target=target}; ns.framesUnlocked = true
for _, unit in ipairs({"targettarget", "pet", "focus", "focustarget", "boss1", "boss2", "boss3", "boss4", "boss5"}) do
    ns.frames[unit] = Frame(unit)
end
local state, visibility, controller = ns.GUI.Editor.State, ns.UnitFrameVisibility, ns.GUI.Editor.Controller
local function Copy(value)
    if type(value) ~= "table" then return value end
    local result = {}; for key, item in pairs(value) do result[key] = Copy(item) end; return result
end
local saved = Copy(units)
local function Project()
    for _, frame in pairs(ns.frames) do ns.UnitFrame:ApplyRangeFade(frame) end
    ns:UpdateAllFrameDragStates()
end
Project()
for _, frame in pairs(ns.frames) do
    Equal(frame:GetAlpha(), 0)
    assert(frame.MoveOverlay.lastSetIgnoreParentAlpha[1] and frame.SelectionOverlay.lastSetIgnoreParentAlpha[1])
    assert(frame.MoveOverlay.PlaceholderLabel:IsShown())
    assert(frame.MoveOverlay:GetParent() == frame and frame.SelectionOverlay:GetParent() == frame)
    assert(frame.MoveOverlay.scripts.OnDragStart and frame.MoveOverlay.scripts.OnDragStop)
end
assert(player.MoveOverlay:GetParent() == player and player.SelectionOverlay:GetParent() == player)
assert(player.ResizeHandle:GetParent() == player.MoveOverlay)
assert(player.MoveOverlay.PlaceholderLabel:IsShown() and player.ResizeHandle:IsShown())
assert(player.MoveOverlay.scripts.OnDragStart and player.MoveOverlay.scripts.OnDragStop)
local parent, points, width, height = player:GetParent(), player.points, player:GetWidth(), player:GetHeight()
for _, frame in pairs(ns.frames) do
    for _, entry in ipairs({{"layout",1}, {"range-fade",0.5}, {"range-driver",0.5},
        {"refresh-placeholder",1}, {"demo-snapshot",1}, {"visibility",1}}) do
        local decision = visibility.ResolveRootAlphaDecision(frame, {source=entry[1], rangeMultiplier=entry[2]})
        Equal(decision.finalAlpha, 0); Equal(decision.configAlpha, frame.config.alpha)
        Equal(decision.targetAlpha, frame.config.alpha * entry[2]); assert(decision.writesImmediately)
    end
end
player._focalPointDragState = {}
ns:RefreshEditorSelectionVisuals()
assert(player.MoveOverlay.PlaceholderLabel:IsShown())
player._focalPointDragState = nil
-- No stored alpha snapshot: Customize uses even a value changed while masked.
units.player.alpha = 0.37; saved.player.alpha = 0.37
local selection, scope = state.Get().selectedUnits, state.GetPropertyScope()
for _ = 1, 30 do
    assert(controller.SetPresentation("customize")); ns:RefreshEditorSelectionVisuals()
    for _, frame in pairs(ns.frames) do
        Equal(frame:GetAlpha(), frame.config.alpha)
        assert(not frame.MoveOverlay.lastSetIgnoreParentAlpha[1] and not frame.SelectionOverlay.lastSetIgnoreParentAlpha[1])
    end
    assert(controller.SetPresentation("arrange")); ns:RefreshEditorSelectionVisuals()
    for _, frame in pairs(ns.frames) do Equal(frame:GetAlpha(), 0) end
    assert(player.MoveOverlay.PlaceholderLabel:IsShown() and player.ResizeHandle:IsShown())
    assert(state.Get().selectedUnits == selection and state.GetPropertyScope() == scope)
end
Equal(player:GetParent(), parent); Equal(player.points, points)
Equal(player:GetWidth(), width); Equal(player:GetHeight(), height)
Equal(units, saved)
Equal(player._rangeCurrentAlpha, 0.37); Equal(player._rangeTargetAlpha, 0.37)
-- If the native alpha-independence API is absent, do not suppress the contents.
player.SetIgnoreParentAlpha = false
ns.UnitFrame:ApplyRangeFade(player); Equal(player:GetAlpha(), 0.37)
player.SetIgnoreParentAlpha = nil
-- Existing combat blocking remains authoritative; no extra combat/recovery path.
combat = true; Project(); assert(not player.ResizeHandle:IsShown())
combat = false; Project(); assert(player.ResizeHandle:IsShown())
ns.guiTestModeEnabled = true; Project(); Equal(player:GetAlpha(), 0)
ns.guiTestModeEnabled = false
local stale = Frame("player")
assert(not visibility.IsArrangePresentationActive(stale))
-- Canonical configuration, support and active identity reject partial/stale roots.
local pet = ns.frames.pet
local petConfig = units.pet
units.pet = nil; assert(not visibility.IsArrangePresentationActive(pet)); units.pet = petConfig
pet.config = units.pet
units.pet.present = false; assert(not visibility.IsArrangePresentationActive(pet)); units.pet.present = true
units.pet.enabled = false; assert(visibility.IsArrangePresentationActive(pet)); units.pet.enabled = true
units.raid1 = Copy(units.player)
local unsupported = Frame("raid1"); ns.frames.raid1 = unsupported
assert(not visibility.IsArrangePresentationActive(unsupported))
ns.frames.raid1 = nil; units.raid1 = nil
local focus = ns.frames.focus
units.focus = Copy(units.focus); units.focus.alpha = 0.42; saved.focus.alpha = 0.42
assert(not visibility.IsArrangePresentationActive(focus))
focus.config = units.focus; assert(visibility.IsArrangePresentationActive(focus))
ns.frames.focus = nil; ns.framePool = {focus=focus}
assert(not visibility.IsArrangePresentationActive(focus))
ns.framePool.focus = nil; ns.frames.focus = focus; Project()
Equal(focus:GetAlpha(), 0)
-- Existing target interpolation keeps its own current/target values under the mask.
target._rangeCurrentAlpha = 0.2; target._rangeTargetAlpha = 0.8
ns.UnitFrame:ApplyRangeFade(target); Equal(target:GetAlpha(), 0)
local driver = target.RangeFadeDriver
assert(driver:IsShown())
driver:Run("OnUpdate", 1/32)
Equal(target._rangeCurrentAlpha, 0.5); Equal(target._rangeTargetAlpha, 0.8); Equal(target:GetAlpha(), 0)
assert(controller.SetPresentation("customize"))
driver:Run("OnUpdate", 1/64)
Equal(target._rangeCurrentAlpha, 0.575); Equal(target:GetAlpha(), 0.575)
assert(controller.SetPresentation("arrange")); Equal(target:GetAlpha(), 0)
driver:Run("OnUpdate", 1); driver:Run("OnUpdate", 1)
Equal(target._rangeCurrentAlpha, 0.8); Equal(target:GetAlpha(), 0); assert(not driver:IsShown())
ns.framesUnlocked = false; Project(); Equal(player:GetAlpha(), 0.37)
assert(not player.MoveOverlay.lastSetIgnoreParentAlpha[1] and not player.SelectionOverlay.lastSetIgnoreParentAlpha[1])
ns.framesUnlocked = true; editorOpen = false; Project(); Equal(player:GetAlpha(), 0.37)
assert(not visibility.IsArrangePresentationActive(player))
-- Out-of-editor range fading still reaches its regular half-alpha target.
ns.framesUnlocked = false
ns.RangeCheck = {GetRange=function() return 50,60 end}
ns.UnitFrame:ApplyRangeFade(target); driver:Run("OnUpdate", 1); driver:Run("OnUpdate", 1)
Equal(target._rangeTargetAlpha, 0.4); Equal(target._rangeCurrentAlpha, 0.4); Equal(target:GetAlpha(), 0.4)
for _ = 1, 30 do
    editorOpen = true; ns.framesUnlocked = true; Project()
    for _, frame in pairs(ns.frames) do Equal(frame:GetAlpha(), 0) end
    editorOpen = false; ns.framesUnlocked = false; Project()
    driver:Run("OnUpdate", 1); driver:Run("OnUpdate", 1)
    for unit, frame in pairs(ns.frames) do Equal(frame:GetAlpha(), frame.config.alpha * (unit == "target" and 0.5 or 1)) end
end
Equal(units, saved)
print("PASS: all 11 editor frames, current alpha restore, canonical/pool guards, target fade ticks, 30 switches + 30 entry/exit cycles and existing combat gates")

-- Real Build/Spawn/Refresh/Deactivate/Pool/Rebuild and real root layout/chrome.
-- Component creation/rendering and its event registrations are unrelated leaf
-- boundaries. No Project() or UpdateAllFrameDragStates follows a rebuild here.
Load("Engine/UnitFrame/Shared/UnitFrameUnitWatchPolicy.lua")
Load("Engine/UnitFrame/Runtime/UnitFrameFactory.lua")
Load("Engine/UnitFrame/Runtime/UnitFrameRefresh.lua")
ns.UnitFrameBuild = {CreateElements=function() end, RegisterEvents=function() end}
RegisterUnitWatch = function(frame) frame.testUnitWatch = true end
UnregisterUnitWatch = function(frame) frame.testUnitWatch = false end
function native:IsProtected() return self.template and self.template:find("SecureUnitButtonTemplate", 1, true) ~= nil or false end
Load("Engine/UnitFrame.lua") -- Bind the real factory and refresh modules, as in Init.xml.
local UF = ns.UnitFrame
for _, method in ipairs({"ApplyTestValues", "RefreshUnitBarValues", "RefreshLiveValues",
    "UpdateTextElements", "RefreshAuras", "RefreshCastBar"}) do UF[method] = function() end end
function UF:ApplyConfig(frame)
    local config = frame.config
    ns.UnitFrameLayout.ApplyBaseFrame(self, frame, config, {
        width=config.width, height=config.height, alpha=config.alpha, scale=1,
        frameLevel=10, frameStrata="MEDIUM", bottomExtensionHeight=0,
    })
    self:ApplyRangeFade(frame)
end
local two = {"player", "target"}
local five = {"player", "target", "targettarget", "focus", "focustarget"}
local layout = {}
for _, unit in ipairs(five) do layout[unit] = Copy(saved[unit]) end
local function Rebuild(keys)
    units = {}
    for _, unit in ipairs(keys) do units[unit] = Copy(layout[unit]) end
    local before = Copy(units)
    ns:RebuildFramesForActiveProfile()
    Equal(units, before)
end
local function CheckActive(keys, arrange)
    local count = 0
    for _, unit in ipairs(keys) do
        local frame = assert(ns.frames[unit], "missing active frame: " .. unit .. ": " .. tostring(ns.spawnDiagnostics[unit] and ns.spawnDiagnostics[unit].reason))
        assert(frame.config == units[unit] and frame:IsShown(), unit .. ": stale/hidden root")
        Equal(frame:GetAlpha(), arrange and 0 or units[unit].alpha)
        assert(frame.MoveOverlay:IsShown(), unit .. ": MoveOverlay remains hidden after rebuild")
        Equal(frame.MoveOverlay.lastSetIgnoreParentAlpha[1], arrange)
        assert(frame.MoveOverlay.scripts.OnDragStart and frame.MoveOverlay.scripts.OnDragStop)
        if arrange then assert(frame.MoveOverlay.PlaceholderLabel:IsShown(), unit .. ": label hidden") end
        count = count + 1
    end
    local actual = 0; for _ in pairs(ns.frames) do actual = actual + 1 end
    Equal(actual, count)
    assert(ns.frames.player.SelectionOverlay:IsShown() and ns.frames.player.ResizeHandle:IsShown())
    for unit, frame in pairs(ns.framePool) do
        assert(not ns.frames[unit] and not frame:IsShown() and not frame.MoveOverlay:IsShown(), unit .. ": pooled frame/chrome visible")
    end
end
local failures = {}
local function LifecycleCase(name, run)
    ns.frames, ns.framePool = {}, {}
    ns.framesUnlocked, editorOpen, combat, ns.guiTestModeEnabled = true, true, false, false
    state.SetPresentation("arrange"); state.SetSingleSelection("player")
    local ok, err = pcall(run)
    if ok then print("PASS: " .. name) else failures[#failures + 1] = name .. ": " .. tostring(err) end
end
LifecycleCase("5->2->5 real pool reactivation, 20 repeats, removal and current Customize alpha", function()
    Rebuild(five)
    local identities = {}; for unit, frame in pairs(ns.frames) do identities[unit] = frame end
    for _ = 1, 20 do
        Rebuild(two); CheckActive(two, true)
        for _, unit in ipairs({"targettarget", "focus", "focustarget"}) do assert(ns.framePool[unit] == identities[unit]) end
        Rebuild(five); CheckActive(five, true)
        for unit, frame in pairs(ns.frames) do assert(frame == identities[unit]) end
    end
    layout.focus.present = false
    Rebuild(five); assert(ns.framePool.focus == identities.focus and not identities.focus.MoveOverlay:IsShown())
    layout.focus.present = true; layout.focus.alpha = 0.23
    state.SetPresentation("customize"); Rebuild(five); CheckActive(five, false)
    state.SetPresentation("arrange"); Rebuild(five); CheckActive(five, true)
end)
LifecycleCase("2->5 new frames receive final alpha after registry publication", function()
    Rebuild(two)
    local firstPlayer, firstTarget = ns.frames.player, ns.frames.target
    assert(ns.framePool.focus == nil and ns.frames.focus == nil)
    Rebuild(five); CheckActive(five, true)
    assert(ns.frames.player == firstPlayer and ns.frames.target == firstTarget)
    assert(ns.spawnDiagnostics.focus.ok and ns.spawnDiagnostics.focus.reason == "spawned")
end)
LifecycleCase("editor finalization is excluded while closed or combat-locked", function()
    Rebuild(five); CheckActive(five, true)
    local update, calls = ns.UpdateFrameDragState, 0
    ns.UpdateFrameDragState = function(self, frame)
        calls = calls + 1
        assert(editorOpen and not combat, "editor finalization crossed lifecycle guard")
        return update(self, frame)
    end
    combat = true; ns:RebuildFramesForActiveProfile(); Equal(calls, 0)
    assert(not ns.frames.player.ResizeHandle:IsShown())
    combat = false; editorOpen = false
    ns:RebuildFramesForActiveProfile(); Equal(calls, 0)
    editorOpen = true; ns:RebuildFramesForActiveProfile(); Equal(calls, #five)
    CheckActive(five, true)
    ns.UpdateFrameDragState = update
end)
assert(#failures == 0, table.concat(failures, "\n"))
