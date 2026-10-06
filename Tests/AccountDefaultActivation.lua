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
local function Reset()
    combat, dirty, failResync, spec = false, false, false, 71
    transitions = {}
    ns.db = {profile={General={}}, char={activeLayoutId="layout:a", LayoutAssignments={
        specialization={}}}, global={defaultLayoutId="layout:b",
        UserLayouts={["layout:a"]=Record("A"), ["layout:b"]=Record("B"), ["layout:c"]=Record("C")}}}
    ns._pendingLayoutActivation = nil
    R.InvalidateActiveRuntimeRoot()
    assert(R.EnsureActiveRuntimeRoot())
end
local function Active(id) assert(ns.db.char.activeLayoutId == id); assert(R.GetActiveRuntimeRoot().layoutId == id) end
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

Test("set/unset default never activates or mutates character state", function()
    Reset(); local root=R.GetActiveRuntimeRoot(); local char=ns.db.char; local assignments=char.LayoutAssignments
    Applied(S.SetAccountDefaultLayoutId("layout:c")); Applied(S.SetAccountDefaultLayoutId(nil))
    Active("layout:a"); assert(ns.db.char==char and char.LayoutAssignments==assignments)
    assert(R.GetActiveRuntimeRoot()==root and #transitions==0)
end)
Test("login default once; absent/stale default retains legacy behavior", function()
    for _,case in ipairs({{default="layout:b",target="layout:b"},{target="layout:a"},{default="layout:missing",target="layout:a"}}) do
        Reset(); ns.db.global.defaultLayoutId=case.default
        local char=ns.db.char; local assignments=char.LayoutAssignments
        local event=EventFrame(); event:Run("OnEvent","PLAYER_ENTERING_WORLD"); Active(case.target)
        assert(#transitions==(case.target=="layout:a" and 0 or 1))
        assert(ns.db.char==char and char.LayoutAssignments==assignments and next(assignments)=="specialization")
        ns:ActivateLayout("layout:a","manual"); transitions={}
        event:Run("OnEvent","PLAYER_SPECIALIZATION_CHANGED","player")
        event:Run("OnEvent","PLAYER_ENTERING_WORLD"); Active("layout:a"); assert(#transitions==0)
    end
end)
Test("abandoned character preferences are inert, not migrated", function()
    Reset(); local old={mode="override",layoutId="layout:c"}
    ns.db.char.LayoutAssignments.characterSelection=old
    local event=EventFrame(); event:Run("OnEvent","PLAYER_ENTERING_WORLD")
    Active("layout:b"); assert(ns.db.char.LayoutAssignments.characterSelection==old)
end)
Test("spec wins directly, including same-active, blocked and deferred activation", function()
    for _,case in ipairs({{target="layout:c"},{target="layout:a"},{target="layout:c",dirty=true},{target="layout:c",combat=true}}) do
        Reset(); Applied(S.SetSpecializationAssignment(71,case.target)); dirty=case.dirty; combat=case.combat
        local event=EventFrame(); event:Run("OnEvent","PLAYER_ENTERING_WORLD")
        if combat then assert(ns._pendingLayoutActivation.layoutId=="layout:c"); FinishCombat() end
        Active(dirty and "layout:a" or case.target)
        for _,id in ipairs(transitions) do assert(id~="layout:b","A-to-default-to-spec") end
    end
end)
Test("manual activation stays ordinary; later unmapped spec never resets it", function()
    Reset(); local event=EventFrame(); event:Run("OnEvent","PLAYER_ENTERING_WORLD")
    Applied(ns:ActivateLayout("layout:c","manual")); Active("layout:c")
    event:Run("OnEvent","PLAYER_SPECIALIZATION_CHANGED","player"); Active("layout:c")
    Applied(S.SetSpecializationAssignment(71,"layout:a")); event:Run("OnEvent","PLAYER_SPECIALIZATION_CHANGED","player"); Active("layout:a")
    Applied(S.SetSpecializationAssignment(71,nil)); event:Run("OnEvent","PLAYER_SPECIALIZATION_CHANGED","player"); Active("layout:a")
end)
Test("existing concrete-ID combat queue and replay guard remain unchanged", function()
    Reset(); combat=true; local event=EventFrame(); event:Run("OnEvent","PLAYER_ENTERING_WORLD")
    local pending=assert(ns._pendingLayoutActivation); assert(pending.layoutId=="layout:b" and next(pending.options)==nil)
    Applied(S.SetAccountDefaultLayoutId("layout:c")) -- no new rule queue; pending activation remains concrete B
    assert(ns._pendingLayoutActivation==pending); FinishCombat(); Active("layout:b")
    Reset(); combat=true; event=EventFrame(); event:Run("OnEvent","PLAYER_ENTERING_WORLD")
    dirty=true; FinishCombat(); Active("layout:a")
    Reset(); combat=true; event=EventFrame(); event:Run("OnEvent","PLAYER_ENTERING_WORLD")
    ns.db.global.UserLayouts["layout:b"]=nil; FinishCombat(); Active("layout:a")
    Reset(); combat=true; Pending(ns:ActivateLayout("layout:b","manual"))
    ns:ActivateLayout("layout:a","same-layout"); FinishCombat(); Active("layout:b")
end)
Test("same-ID default does not rebuild; unavailable spec permits default", function()
    Reset(); ns.db.global.defaultLayoutId="layout:a"; local root=R.GetActiveRuntimeRoot()
    local event=EventFrame(); event:Run("OnEvent","PLAYER_ENTERING_WORLD")
    assert(R.GetActiveRuntimeRoot()==root and #transitions==0)
    Reset(); spec=nil; event=EventFrame(); event:Run("OnEvent","PLAYER_ENTERING_WORLD"); Active("layout:b")
end)
Test("guards and all activation rollback boundaries retain exact root and ID", function()
    for _,failure in ipairs({"dirty","resync","publication-false","publication-error","callback"}) do
        Reset(); local root=R.GetActiveRuntimeRoot(); local publish=R.SetActiveRuntimeRoot
        local callback=ns.GUIController.OnActiveLayoutChanged
        if failure=="dirty" then dirty=true
        elseif failure=="resync" then failResync=true
        elseif failure=="callback" then ns.GUIController.OnActiveLayoutChanged=function() error("callback failure") end
        else R.SetActiveRuntimeRoot=function(nextRoot)
            if nextRoot.layoutId=="layout:b" then
                if failure=="publication-error" then error("publication failure") end
                return false
            end
            return publish(nextRoot)
        end end
        Rejected(ns:ActivateLayout("layout:b","test"))
        R.SetActiveRuntimeRoot=publish; ns.GUIController.OnActiveLayoutChanged=callback
        Active("layout:a"); assert(R.GetActiveRuntimeRoot()==root)
    end
end)
Test("delete clears reference after success only and retains active/builtin protection", function()
    Reset(); local remove=ns.UserLayoutStore.RemoveRaw
    ns.UserLayoutStore.RemoveRaw=function() return false end
    Rejected(ns.LayoutMutations.DeleteUserLayout("layout:b")); assert(ns.db.global.defaultLayoutId=="layout:b")
    ns.UserLayoutStore.RemoveRaw=remove
    Applied(S.SetSpecializationAssignment(71,"layout:b")); Applied(ns.LayoutMutations.DeleteUserLayout("layout:b"))
    assert(ns.db.global.defaultLayoutId==nil and S.GetSpecializationAssignment(71)==nil)
    Rejected(ns.LayoutMutations.DeleteUserLayout("layout:a")); Rejected(ns.LayoutMutations.DeleteUserLayout("builtin:default"))
end)
Test("default resolution remains outside runtime reads", function()
    Reset(); local event=EventFrame(); event:Run("OnEvent","PLAYER_ENTERING_WORLD")
    local root=R.GetActiveRuntimeRoot(); local getter=S.GetAccountDefaultLayoutId
    S.GetAccountDefaultLayoutId=function() error("default read in runtime hotpath") end
    for _=1,100 do
        assert(ns.UnitFrameUtils.GetUnitsDB()==root.payload.Units)
        assert(ns.UnitFrameUtils.GetUnitDB("player")==root.payload.Units.player)
    end
    S.GetAccountDefaultLayoutId=getter
end)
print("AccountDefaultActivation: "..passed.." groups passed")
