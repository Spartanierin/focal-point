-- lua54 Tests/ActiveRuntimeRootReads.lua
-- Real resolver/storage/geometry, Inspector writers, selection and activation.
-- Reuse only the existing native WoW fixture and module setup, not its tests.
local file = assert(io.open("Tests/TextBuilderDraftSafety.lua"))
local source = file:read("*a"); file:close()
local boundary = assert(source:find('local a, b = Payload("A"), Payload("B")', 1, true))
local f = assert(load(source:sub(1, boundary - 1) .. "\nreturn f", "@RuntimeRoot/Fixture"))()
local ns, Load = f.ns, f.Load
for _, path in ipairs({
    "Engine/UnitFrame/Shared/UnitFramePreview.lua",
    "Engine/UnitFrame/Runtime/UnitFrameLayout.lua",
    "Engine/UnitFrame/Runtime/UnitFrameInsideLayout.lua",
    "Engine/UnitFrame/Bars/UnitFrameBarLayout.lua",
    "GUI/Editor/Inspector/InspectorMutations.lua",
    "GUI/Editor/Composition/LegacyAssociationMap.lua",
    "GUI/Editor/Composition/CompositionOwnership.lua",
    "GUI/Editor/Composition/CompositionPresence.lua",
}) do Load(path) end
local selectionState = {selectedUnit = "target"}
local scope = {kind = "aura", auraKey = "Buffs"}
ns.GUI.Editor.State = {
    Get = function() return selectionState end,
    GetPrimaryUnit = function() return "target" end,
    GetPropertyScope = function() return scope end,
}
Load("GUI/Editor/ObjectSelection.lua")
Load("Engine/UnitFrame/Shared/EditorVisualPolicy.lua")
ns.framesUnlocked = true
ns.IsEditorActive = function() return true end
local R, U, S = ns.ActiveLayoutResolver, ns.UnitFrameUtils, ns.LayoutService
local Copy = S.Clone
local function Equal(a, b)
    if type(a) ~= "table" or type(b) ~= "table" then assert(a == b); return end
    for k, v in pairs(a) do Equal(v, b[k]) end
    for k in pairs(b) do assert(a[k] ~= nil) end
end
local function Record()
    return {name = "Test", formatVersion = 2, payload = {Units = {target = {
        enabled = true, width = 220, height = 40, showPowerBar = true, powerBarHeight = 8,
        Buffs = {enabled = true, anchorTo = "Frame", insideAnchorTo = "Frame", placement = "ATTACHED"},
        Texts = {},
    }}}}
end
local function Reset()
    ns.db = {profile = {General = {}}, char = {activeLayoutId = "layout:a"},
        global = {UserLayouts = {["layout:a"] = Record(), ["layout:b"] = Record()}}}
    R.InvalidateActiveRuntimeRoot()
    return ns.db.global.UserLayouts["layout:a"]
end
local counts = {}
local function CountCalls(owner, key)
    local original = assert(owner[key])
    owner[key] = function(...)
        counts[key] = (counts[key] or 0) + 1
        return original(...)
    end
end
for _, key in ipairs({"MigrateLegacyPayload", "MigrateLegacyUnits", "MigrateLegacyUnitPresence",
    "EnsurePayload", "EnsureUnits", "EnsureUnit"}) do CountCalls(ns.CompositionPresenceStorage, key) end
CountCalls(S, "CanonicalizeAuraAnchors")
CountCalls(S, "Clone")
CountCalls(ns.UserLayoutStore, "GetMutableRaw")
local function ClearCounts() counts = {} end
local function Once()
    for _, key in ipairs({"GetMutableRaw", "MigrateLegacyPayload", "MigrateLegacyUnits",
        "MigrateLegacyUnitPresence", "EnsurePayload", "EnsureUnits", "EnsureUnit", "CanonicalizeAuraAnchors"}) do
        assert(counts[key] == 1, key .. ": expected one boundary call, got " .. tostring(counts[key]))
    end
    assert(not counts.Clone, "Frame-only materialization must not clone")
end
local function PureReads(root, preview)
    local before = Copy(ns.db)
    local units, unit = root.payload.Units, root.payload.Units.target
    ClearCounts()
    for _ = 1, 100 do
        assert(U.GetUnitsDB() == units and U.GetUnitDB("target") == unit)
        assert(R.GetActiveRuntimeRoot() == root)
        if preview then
            local selected = ns.GUI.Editor.ObjectSelection.GetSelectedObject()
            assert(selected and selected.kind == "aura")
            assert(ns.EditorVisualPolicy.IsSelectionPreview({_fpUnit = "target", config = unit}, scope))
        end
    end
    for key, value in pairs(counts) do assert(value == 0, "current read called " .. key .. " " .. value .. " times") end
    Equal(ns.db, before)
end

-- Red first: this fails on the old mutating Current check.
Reset(); ClearCounts()
local root = assert(R.EnsureActiveRuntimeRoot())
Once(); PureReads(root, true)

-- Every identity change must rebuild once, then return to pure reads.
local replacements = {
    activeId = function() ns.db.char.activeLayoutId = "layout:b" end,
    record = function() local old = ns.db.global.UserLayouts["layout:a"]
        ns.db.global.UserLayouts["layout:a"] = {name = old.name, formatVersion = 2, payload = old.payload} end,
    payload = function() ns.db.global.UserLayouts["layout:a"].payload = Record().payload end,
    units = function() ns.db.global.UserLayouts["layout:a"].payload.Units = Record().payload.Units end,
    store = function() local old = ns.db.global.UserLayouts
        ns.db.global.UserLayouts = {["layout:a"] = old["layout:a"], ["layout:b"] = old["layout:b"]} end,
    global = function() ns.db.global = {UserLayouts = ns.db.global.UserLayouts} end,
    db = function() ns.db = {profile = ns.db.profile, char = ns.db.char, global = ns.db.global} end,
    invalidation = function() R.InvalidateActiveRuntimeRoot() end,
}
for name, replace in pairs(replacements) do
    Reset(); local old = assert(R.EnsureActiveRuntimeRoot())
    replace(); ClearCounts()
    local nextRoot = assert(R.EnsureActiveRuntimeRoot())
    assert(nextRoot ~= old, name .. " reused stale root")
    Once(); PureReads(nextRoot, true)
end

-- Malformed replacement data cannot hide behind a formerly current root.
for _, corrupt in ipairs({
    function(r) r.formatVersion = 1 end,
    function(r) r.payload.TextTemplates = {} end,
    function(r) r.payload = false end,
    function(r) r.payload.Units = false end,
    function() ns.db.global.UserLayouts["layout:a"] = nil end,
}) do
    local record = Reset(); assert(R.EnsureActiveRuntimeRoot())
    corrupt(record); ClearCounts()
    local nextRoot, reason = R.EnsureActiveRuntimeRoot()
    assert(nextRoot == nil and type(reason) == "string" and R.GetActiveRuntimeRoot() == nil)
    assert(counts.GetMutableRaw == 1 and not counts.CanonicalizeAuraAnchors)
end

-- Presence migration precedes Ensure, including newly replaced Units.
local record = Reset(); assert(R.EnsureActiveRuntimeRoot())
record.payload.Units = Record().payload.Units
record.payload.Units.target.enabled = false
ClearCounts(); root = assert(R.EnsureActiveRuntimeRoot()); Once()
assert(root.payload.Units.target.present == false)
PureReads(root)

-- Actual legacy anchors on replacement still reach geometry + migration.
record = Reset(); assert(R.EnsureActiveRuntimeRoot())
local unit = Record().payload.Units.target
unit.showPowerBar = false
unit.Buffs.anchorTo = "PowerBar"
record.payload.Units = {target = unit}
ClearCounts(); root = assert(R.EnsureActiveRuntimeRoot())
assert(counts.CanonicalizeAuraAnchors == 1 and counts.MigrateLegacyUnitPresence == 1)
assert(counts.EnsureUnit == 2, "stored unit plus isolated geometry input")
assert(unit.Buffs.anchorTo == "Frame" and unit.Buffs.insideAnchorTo == "Frame" and unit.Buffs.enabled == false)
PureReads(root)

-- Real Inspector mutations preserve the canonical root in place.
record = Reset(); root = assert(R.EnsureActiveRuntimeRoot())
unit = root.payload.Units.target
local context, M = {unitKey = "target", unitConfig = unit}, ns.InspectorMutations
for _, mutate in ipairs({
    function() return M.SetUnitField(context, "powerBarHeight", 15) end,
    function() return M.SetComponentPresence(context, "Buffs", false) end,
    function() return M.AddComponent(context, "Buffs") end,
    function() return M.SetAuraField(context, "Buffs", "placement", "INSIDE") end,
    function() return M.SetAuraPositionOffsets(context, "Buffs", 12, -4) end,
    function() return M.SetComponentPresence(context, "PowerBar", false) end,
    function() return M.AddComponent(context, "PowerBar") end,
}) do
    assert(mutate().ok)
    assert(unit.Buffs.anchorTo == "Frame" and unit.Buffs.insideAnchorTo == "Frame")
    PureReads(root)
end
assert(unit.powerBarHeight == 15 and unit.Buffs.offsetX == 12 and unit.Buffs.offsetY == -4)

-- The explicit editable access remains a materialization boundary.
ClearCounts(); assert(R.GetEditableActiveUnits() == root.payload.Units); Once(); PureReads(root)

-- Actual ActivateLayout rollback and specialization/combat-deferred activation.
local combat, failResync = false, false
function InCombatLockdown() return combat end
ns.GUIController = {CanActivateLayout = function() return true end, HasUnsavedChanges = function() return false end}
ns.RebuildFramesForActiveProfile = function() if failResync then error("injected resync failure") end end
ns.RefreshEditorSelectionVisuals = function() end
ns.RefreshEditorInteractionVisuals = function() end
ns.GUI.RequestRefreshOptions = function() end
Reset(); root = assert(R.EnsureActiveRuntimeRoot())
failResync = true
local ok, why = ns:ActivateLayout("layout:b", "rollback")
failResync = false
assert(not ok and why == "resync-error" and ns.db.char.activeLayoutId == "layout:a")
assert(R.GetActiveRuntimeRoot() == root); PureReads(root)
function GetSpecialization() return 1 end
C_SpecializationInfo = {GetSpecializationInfo = function() return 71 end}
assert(ns.LayoutAssignmentService.SetSpecializationAssignment(71, "layout:b"))
combat = true
ok, why = ns.LayoutAssignmentService.EvaluateCurrentSpecializationAssignment("test")
assert(not ok and why == "pending" and R.GetActiveRuntimeRoot() == root)
-- Replacing the queued target must not publish the previously prepared payload.
ns.db.global.UserLayouts["layout:b"] = Record()
ClearCounts(); combat = false
ns._layoutActivationEventFrame:Run("OnEvent", "PLAYER_REGEN_ENABLED")
assert(ns.db.char.activeLayoutId == "layout:b" and ns._pendingLayoutActivation == nil)
root = assert(R.GetActiveRuntimeRoot())
assert(root.payload == ns.db.global.UserLayouts["layout:b"].payload)
Once(); PureReads(root)

-- Built-in projection remains a boundary; subsequent reads reuse its identity.
ns.db.char.activeLayoutId = "builtin:default"
root = assert(R.EnsureActiveRuntimeRoot())
PureReads(root)
local old = root
root.payload.Units = {}
root = assert(R.EnsureActiveRuntimeRoot())
assert(root ~= old and next(root.payload.Units)); PureReads(root)
print("PASS ActiveRuntimeRootReads: pure reads/counters, selection/preview, identity replacement, invalid data, presence, legacy aura, Inspector mutations, rollback, spec/combat-deferred activation, built-ins")
