-- Block B: real selection/resolver/activation/queue; native frames are doubles.
local file = assert(io.open("Tests/TextBuilderDraftSafety.lua"))
local source = file:read("*a"); file:close()
local boundary = assert(source:find('local a, b = Payload("A"), Payload("B")', 1, true))
local f = assert(load(source:sub(1, boundary - 1) .. "\nreturn f", "@AccountDefault/Fixture"))()
local ns, Load = f.ns, f.Load
Load("Services/LayoutMutations.lua")
Load("Data/BuiltInTextTemplates.lua")
local S, R = ns.LayoutAssignmentService, ns.ActiveLayoutResolver
local combat, dirty, failResync, spec = false, false, false, 71
local transitions = {}
function InCombatLockdown() return combat end
function GetSpecialization() return spec and 1 or nil end
C_SpecializationInfo = {GetSpecializationInfo = function() return spec end}
ns.GUIController = {CanActivateLayout = function() return not dirty, "unsaved-changes" end,
    OnActiveLayoutChanged = function(_, id) transitions[#transitions + 1] = id end}
ns.GUI.Pages.TextBuilder.HasUnsavedChanges = function() return dirty end
ns.RebuildFramesForActiveProfile = function() if failResync then error("injected rebuild failure") end end
ns.RefreshEditorSelectionVisuals = function() end
ns.GUI.RequestRefreshOptions = function() end
local function Record(name) return {name=name, formatVersion=2, payload={Units={player={Texts={}}}}} end
local function Reset(selection)
    combat, dirty, failResync, spec = false, false, false, 71
    transitions = {}
    ns.db = {profile={General={}}, char={activeLayoutId="layout:a", LayoutAssignments={
        characterSelection=selection, specialization={}}}, global={defaultLayoutId="layout:b",
        UserLayouts={["layout:a"]=Record("A"), ["layout:b"]=Record("B"), ["layout:c"]=Record("C")}}}
    ns._pendingLayoutActivation = nil
    R.InvalidateActiveRuntimeRoot()
    assert(R.EnsureActiveRuntimeRoot())
end
local function Active(id) assert(ns.db.char.activeLayoutId == id); assert(R.GetActiveRuntimeRoot().layoutId == id) end
local function Selection(mode, id)
    local s = ns.db.char.LayoutAssignments.characterSelection
    if mode == nil then assert(s == nil) else assert(s.mode == mode and s.layoutId == id) end
end
local function Applied(ok, reason) assert(ok, tostring(reason)) end
local function Pending(ok, reason) assert(not ok and reason == "pending", tostring(reason)) end
local function Rejected(ok, reason) assert(not ok and reason ~= "pending", tostring(reason)) end
local function FinishCombat()
    combat = false
    ns._layoutActivationEventFrame:Run("OnEvent", "PLAYER_REGEN_ENABLED")
end
local function EventFrame()
    -- Each isolated login gets the real event callback with a fresh one-shot boundary.
    for i=1,20 do local name=debug.getupvalue(S.InitializeRuntime,i)
        if name=="eventFrame" then debug.setupvalue(S.InitializeRuntime,i,nil); break end end
    S.InitializeRuntime()
    return assert(f.Upvalue(S.InitializeRuntime,"eventFrame"))
end
local passed=0
local function Test(name, fn) fn(); passed=passed+1; print("PASS: "..name) end

Test("global preference setters never activate or change character intent", function()
    Reset(); local root=R.GetActiveRuntimeRoot()
    Applied(S.SetAccountDefaultLayoutId("layout:c")); Applied(S.SetAccountDefaultLayoutId(nil))
    Active("layout:a"); Selection(nil); assert(R.GetActiveRuntimeRoot()==root and #transitions==0)
end)
Test("user/builtin actions and same-ID mode changes", function()
    Reset(); Applied(S.ApplyAccountDefaultForCurrentCharacter()); Active("layout:b"); Selection("accountDefault")
    local root=R.GetActiveRuntimeRoot(); local count=#transitions
    Applied(S.ApplyCharacterLayoutOverride("layout:b")); Selection("override","layout:b")
    Applied(S.ApplyAccountDefaultForCurrentCharacter()); Selection("accountDefault")
    assert(R.GetActiveRuntimeRoot()==root and #transitions==count)
    Applied(S.ApplyCharacterLayoutOverride("builtin:modern")); Active("builtin:modern"); Selection("override","builtin:modern")
    Applied(S.SetAccountDefaultLayoutId("builtin:classic")); Applied(S.ApplyAccountDefaultForCurrentCharacter())
    Active("builtin:classic"); Selection("accountDefault")
    Applied(S.SetAccountDefaultLayoutId(nil)); root=R.GetActiveRuntimeRoot()
    Applied(S.ApplyAccountDefaultForCurrentCharacter()); Active("builtin:classic"); assert(R.GetActiveRuntimeRoot()==root)
end)
Test("system fallback retains Block A legacy-current and profile-map contract", function()
    Reset(); ns.db.global.defaultLayoutId=nil; ns.db.char.activeLayoutId=nil; R.InvalidateActiveRuntimeRoot()
    ns.db.GetCurrentProfile=function() return "Old" end
    ns.db.global.LayoutMigration={profileMap={Old="layout:c"}}
    Applied(S.ApplyAccountDefaultForCurrentCharacter()); Active("layout:c")
    ns.db.char.activeLayoutId=nil; ns.db.global.LayoutMigration=nil; R.InvalidateActiveRuntimeRoot()
    Applied(S.ApplyAccountDefaultForCurrentCharacter()); Active("builtin:default")
end)
Test("guards, invalid targets and rebuild rollback restore exact selection/root", function()
    Reset({mode="override",layoutId="layout:a"})
    local selection=ns.db.char.LayoutAssignments.characterSelection; local root=R.GetActiveRuntimeRoot()
    dirty=true; Rejected(S.ApplyAccountDefaultForCurrentCharacter()); dirty=false
    assert(ns.db.char.LayoutAssignments.characterSelection==selection and R.GetActiveRuntimeRoot()==root)
    failResync=true; Rejected(S.ApplyAccountDefaultForCurrentCharacter()); failResync=false
    Active("layout:a"); assert(ns.db.char.LayoutAssignments.characterSelection==selection and R.GetActiveRuntimeRoot()==root)
    Rejected(S.ApplyCharacterLayoutOverride("layout:missing"))
    ns.db.global.defaultLayoutId="layout:missing"; Rejected(S.ApplyAccountDefaultForCurrentCharacter())
    Active("layout:a"); assert(ns.db.char.LayoutAssignments.characterSelection==selection)
    ns.db.char.LayoutAssignments.characterSelection={mode="override",layoutId="layout:missing"}
    local frame=EventFrame(); frame:Run("OnEvent","PLAYER_ENTERING_WORLD")
    Active("layout:a"); Selection("override","layout:missing"); assert(#transitions==0)
end)
Test("runtime-root publication rejection rolls back active ID and selection", function()
    Reset(); local root=R.GetActiveRuntimeRoot(); local publish=R.SetActiveRuntimeRoot
    R.SetActiveRuntimeRoot=function(nextRoot) if nextRoot.layoutId=="layout:b" then return false end; return publish(nextRoot) end
    Rejected(S.ApplyAccountDefaultForCurrentCharacter())
    R.SetActiveRuntimeRoot=publish
    Active("layout:a"); Selection(nil); assert(R.GetActiveRuntimeRoot()==root)
end)
Test("publication and layout-changed exceptions cannot leave half-applied selection", function()
    Reset(); local root=R.GetActiveRuntimeRoot(); local publish=R.SetActiveRuntimeRoot
    R.SetActiveRuntimeRoot=function(nextRoot) if nextRoot.layoutId=="layout:b" then error("injected publication failure") end; return publish(nextRoot) end
    Rejected(S.ApplyAccountDefaultForCurrentCharacter()); R.SetActiveRuntimeRoot=publish
    Active("layout:a"); Selection(nil); assert(R.GetActiveRuntimeRoot()==root)
    local changed=ns.GUIController.OnActiveLayoutChanged
    ns.GUIController.OnActiveLayoutChanged=function() error("injected lifecycle failure") end
    Rejected(S.ApplyAccountDefaultForCurrentCharacter()); ns.GUIController.OnActiveLayoutChanged=changed
    Active("layout:a"); Selection(nil); assert(R.GetActiveRuntimeRoot()==root)
end)
Test("combat intent is transient and default is freshly resolved", function()
    Reset(); combat=true; Pending(S.ApplyAccountDefaultForCurrentCharacter())
    local queue=ns._pendingLayoutActivation; assert(queue and queue.options.characterSelectionRequest)
    Active("layout:a"); Selection(nil)
    Applied(S.SetAccountDefaultLayoutId("layout:c")); assert(ns._pendingLayoutActivation==queue)
    FinishCombat(); Active("layout:c"); Selection("accountDefault"); assert(ns._pendingLayoutActivation==nil)
    Reset(); combat=true; Pending(S.ApplyCharacterLayoutOverride("layout:b"))
    Selection(nil); FinishCombat(); Active("layout:b"); Selection("override","layout:b")
end)
Test("pending clear, deleted target and changed selection are safe", function()
    Reset(); combat=true; Pending(S.ApplyAccountDefaultForCurrentCharacter()); Applied(S.SetAccountDefaultLayoutId(nil))
    FinishCombat(); Active("layout:a"); Selection("accountDefault")
    Reset(); combat=true; Pending(S.ApplyCharacterLayoutOverride("layout:b"))
    ns.db.global.UserLayouts["layout:b"]=nil
    FinishCombat(); Active("layout:a"); Selection(nil)
    Reset(); combat=true; Pending(S.ApplyAccountDefaultForCurrentCharacter())
    Applied(S.SetCharacterSelection({mode="override",layoutId="layout:c"}))
    FinishCombat(); Active("layout:a"); Selection("override","layout:c")
    Reset(); combat=true; Pending(S.ApplyAccountDefaultForCurrentCharacter())
    ns.db.char.LayoutAssignments.characterSelection={mode="override",layoutId="layout:c"}
    FinishCombat(); Active("layout:a"); Selection("override","layout:c")
end)
Test("latest new selection wins; legacy-to-legacy queue semantics stay unchanged", function()
    Reset(); combat=true; Pending(S.ApplyAccountDefaultForCurrentCharacter())
    Applied(S.ApplyCharacterLayoutOverride("layout:a")); FinishCombat(); Active("layout:a"); Selection("override","layout:a")
    Reset(); combat=true; Pending(S.ApplyAccountDefaultForCurrentCharacter())
    local ok, reason=ns:ActivateLayout("layout:a","manual")
    assert(not ok and reason=="same-layout"); FinishCombat(); Active("layout:a"); Selection(nil)
    Reset(); combat=true; Pending(S.ApplyAccountDefaultForCurrentCharacter())
    Pending(ns:ActivateLayout("layout:c","manual")); FinishCombat(); Active("layout:c"); Selection(nil)
    Reset(); combat=true; Pending(ns:ActivateLayout("layout:b","legacy-manual"))
    ns:ActivateLayout("layout:a","legacy-same")
    FinishCombat(); Active("layout:b") -- existing concrete-ID queue semantics unchanged
    Reset(); combat=true; Pending(ns:ActivateLayout("layout:b","legacy-manual"))
    Applied(S.ApplyCharacterLayoutOverride("layout:a"))
    FinishCombat(); Active("layout:a"); Selection("override","layout:a")
end)
Test("spec/mapping changes invalidate rule request; existing spec queue still works", function()
    Reset(); local event=EventFrame(); combat=true; Pending(S.ApplyAccountDefaultForCurrentCharacter())
    spec=72; event:Run("OnEvent","PLAYER_SPECIALIZATION_CHANGED","player")
    FinishCombat(); Active("layout:a"); Selection(nil)
    Reset(); combat=true; Pending(S.ApplyAccountDefaultForCurrentCharacter())
    Applied(S.SetSpecializationAssignment(71,"layout:c"))
    FinishCombat(); Active("layout:a"); Selection(nil)
    Reset(); combat=true; Pending(S.ApplyAccountDefaultForCurrentCharacter())
    Applied(S.SetSpecializationAssignment(71,"layout:c")); Pending(S.EvaluateCurrentSpecializationAssignment("test"))
    FinishCombat(); Active("layout:c"); Selection(nil)
end)
Test("dirty draft at replay and DB replacement discard transient intent", function()
    Reset(); combat=true; Pending(S.ApplyAccountDefaultForCurrentCharacter()); local root=R.GetActiveRuntimeRoot()
    dirty=true; FinishCombat(); Active("layout:a"); Selection(nil); assert(R.GetActiveRuntimeRoot()==root)
    Reset(); combat=true; Pending(S.ApplyAccountDefaultForCurrentCharacter())
    ns.db=ns.LayoutService.Clone(ns.db); FinishCombat(); Selection(nil); assert(ns.db.char.activeLayoutId=="layout:a")
end)
Test("delete clears default only after success, keeps current/foreign character contracts", function()
    Reset({mode="override",layoutId="layout:b"})
    local remove=ns.UserLayoutStore.RemoveRaw
    ns.UserLayoutStore.RemoveRaw=function() return false end
    Rejected(ns.LayoutMutations.DeleteUserLayout("layout:b"))
    assert(ns.db.global.defaultLayoutId=="layout:b" and ns.db.global.UserLayouts["layout:b"])
    ns.UserLayoutStore.RemoveRaw=remove
    local foreign={activeLayoutId="layout:b",LayoutAssignments={characterSelection={mode="override",layoutId="layout:b"}}}
    ns.db.sv={char={Other=foreign}}
    Applied(S.SetSpecializationAssignment(71,"layout:b"))
    Applied(ns.LayoutMutations.DeleteUserLayout("layout:b"))
    assert(ns.db.global.defaultLayoutId==nil and S.GetSpecializationAssignment(71)==nil)
    local _,status=S.GetCharacterSelection(); assert(status=="stale")
    assert(foreign.activeLayoutId=="layout:b" and foreign.LayoutAssignments.characterSelection.layoutId=="layout:b")
    Rejected(ns.LayoutMutations.DeleteUserLayout("layout:a")); Rejected(ns.LayoutMutations.DeleteUserLayout("builtin:default"))
    Active("layout:a")
end)
Test("selection resolution stays outside current runtime reads", function()
    Reset(); Applied(S.ApplyAccountDefaultForCurrentCharacter())
    local root=R.GetActiveRuntimeRoot(); local resolve=R.ResolveLayoutSelection
    R.ResolveLayoutSelection=function() error("selection resolution on runtime read") end
    for _=1,100 do
        assert(ns.UnitFrameUtils.GetUnitsDB()==root.payload.Units)
        assert(ns.UnitFrameUtils.GetUnitDB("player")==root.payload.Units.player)
        assert(R.GetActiveRuntimeRoot()==root)
    end
    R.ResolveLayoutSelection=resolve
end)
Test("login consumes explicit baseline once, Legacy remains untouched", function()
    for _,case in ipairs({{nil,"layout:a"},{{mode="accountDefault"},"layout:b"},{{mode="override",layoutId="layout:c"},"layout:c"}}) do
        Reset(case[1]); local root=R.GetActiveRuntimeRoot(); local event=EventFrame()
        event:Run("OnEvent","PLAYER_ENTERING_WORLD"); Active(case[2])
        assert(#transitions==(case[1] and 1 or 0))
        if not case[1] then assert(R.GetActiveRuntimeRoot()==root) end
        local ok, reason=ns:ActivateLayout("layout:a","manual"); assert(ok or reason=="same-layout"); transitions={}
        event:Run("OnEvent","PLAYER_SPECIALIZATION_CHANGED","player"); Active("layout:a")
        event:Run("OnEvent","PLAYER_ENTERING_WORLD"); Active("layout:a"); assert(#transitions==0)
    end
end)
Test("login goes A-to-C directly, never A-to-B-to-C, including blocked spec", function()
    for _,selection in ipairs({{mode="accountDefault"},{mode="override",layoutId="layout:b"}}) do
        Reset(selection); Applied(S.SetSpecializationAssignment(71,"layout:c")); local event=EventFrame()
        event:Run("OnEvent","PLAYER_ENTERING_WORLD"); Active("layout:c")
        assert(#transitions==1 and transitions[1]=="layout:c")
        Applied(S.ApplyAccountDefaultForCurrentCharacter()); Active("layout:b")
        event:Run("OnEvent","PLAYER_SPECIALIZATION_CHANGED","player"); Active("layout:c")
        Applied(S.SetSpecializationAssignment(71,nil)); event:Run("OnEvent","PLAYER_SPECIALIZATION_CHANGED","player"); Active("layout:c")
        Reset(selection); Applied(S.SetSpecializationAssignment(71,"layout:c")); event=EventFrame(); dirty=true
        event:Run("OnEvent","PLAYER_ENTERING_WORLD"); Active("layout:a"); assert(#transitions==0)
        dirty=false
    end
end)
Test("login deferred spec has no intermediate baseline and stale mapping follows existing cleanup", function()
    Reset({mode="accountDefault"}); Applied(S.SetSpecializationAssignment(71,"layout:c"))
    local event=EventFrame(); combat=true; event:Run("OnEvent","PLAYER_ENTERING_WORLD")
    assert(ns._pendingLayoutActivation.layoutId=="layout:c" and not ns._pendingLayoutActivation.options.characterSelectionRequest)
    FinishCombat(); Active("layout:c"); assert(#transitions==1)
    Reset({mode="accountDefault"}); ns.db.char.LayoutAssignments.specialization[71]="layout:missing"
    event=EventFrame(); event:Run("OnEvent","PLAYER_ENTERING_WORLD")
    assert(S.GetSpecializationAssignment(71)==nil); Active("layout:b")
end)
Test("same-active spec still wins over baseline and absent specialization permits login baseline", function()
    Reset({mode="accountDefault"}); Applied(S.SetSpecializationAssignment(71,"layout:a"))
    local event=EventFrame(); event:Run("OnEvent","PLAYER_ENTERING_WORLD")
    Active("layout:a"); assert(#transitions==0)
    Reset({mode="accountDefault"}); spec=nil; event=EventFrame()
    event:Run("OnEvent","PLAYER_ENTERING_WORLD"); Active("layout:b"); assert(#transitions==1)
end)
print("AccountDefaultActivation: "..passed.." groups passed")
