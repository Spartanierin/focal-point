-- Pure detached data; real editable workflow, resolver, store and transfer.
local f=assert(io.open("Tests/LayoutTransferEntityCommit.lua"));local source=f:read("*a");f:close()
local stop=assert(source:find("for failure=1,3 do",1,true))
local ns,Copy,Equal,Target=assert(load(source:sub(1,stop-1).."\nreturn ns,Copy,Equal,Target"))()
assert(loadfile("GUI/Editor/LayoutEditWorkflow.lua"))("FocalPoint",ns)
local M,S,R=ns.LayoutMutations.SegmentedBars,ns.LayoutService,ns.ActiveLayoutResolver
local workflow=ns.LayoutEditWorkflow.RequestEditableLayoutForMutation
local calls,combat,count=0,false,0
InCombatLockdown=function()return combat end
ns.LayoutEditWorkflow.RequestEditableLayoutForMutation=function(...)
    calls=calls+1;return workflow(...)
end
local normalWorkflow=ns.LayoutEditWorkflow.RequestEditableLayoutForMutation
local function Test(name,fn)fn();count=count+1;print("PASS: "..name)end
local function Setup()
    combat=false;ns.LayoutEditWorkflow.RequestEditableLayoutForMutation=normalWorkflow
    local db=Target();db.char={activeLayoutId="layout:existing"}
    R.InvalidateActiveRuntimeRoot();assert(R.EnsureActiveRuntimeRoot(db))
    return db,db.global.UserLayouts["layout:existing"].payload.Units.player
end
local function Context()return assert(M.CaptureContext("player"))end
local function Add(values)local r=M.Add(Context(),values);assert(r.ok,r.errorCode);return r.id end
local function Reject(fn,code)
    local before=Copy(ns.db);local root=R.GetActiveRuntimeRoot()
    local unit=root.payload.Units.player;local collection=unit.segmentedBars
    local r=fn();assert(not r.ok,"unexpected acceptance")
    if code then assert(r.errorCode==code,r.errorCode)end
    Equal(ns.db,before);assert(R.GetActiveRuntimeRoot()==root and unit.segmentedBars==collection)
end
Test("add, independent duplicate and valid defaults through existing workflow",function()
    local db,unit=Setup();local before=calls
    local a=Add();local values={enabled=false,dataSource={id="runes",scope="player"},anchorTo="SegmentedBar:"..a,
        point="TOPRIGHT",relativePoint="BOTTOMRIGHT",offsetX=4,offsetY=-3,width=180,height=14,
        spacing=2,growth="RIGHT_TO_LEFT",color={.2,.3,.4,0}}
    local b=Add(values);local r=M.Duplicate(Context(),b);assert(r.ok,r.errorCode)
    assert(a~=b and b~=r.id and a~=r.id and calls==before+3)
    local records=unit.segmentedBars;assert(#records==3 and records[1].enabled==true)
    assert(S.ValidateSegmentedBars(records,"player"))
    local twin=Copy(records[3]);twin.id=b;Equal(twin,records[2])
    assert(records[2].dataSource~=records[3].dataSource and records[2].color~=records[3].color)
    values.color[1]=.9;assert(records[2].color[1]==.2)
end)
Test("delete referenced target rejects; deleting last record leaves explicit empty",function()
    local _,unit=Setup();local a=Add();local b=Add({enabled=true,dataSource={id="runes",scope="player"},anchorTo="SegmentedBar:"..a})
    Reject(function()return M.Delete(Context(),a)end,"anchor-in-use")
    assert(M.Delete(Context(),b).ok);assert(M.Delete(Context(),a).ok)
    assert(type(unit.segmentedBars)=="table" and next(unit.segmentedBars)==nil)
    assert(next(S.CopyPayload({Units={player=unit}}).Units.player.segmentedBars)==nil)
end)
Test("enabled only and reorder preserve identity, anchor and field values",function()
    local _,unit=Setup();local a=Add();local b=Add({enabled=true,dataSource={id="runes",scope="player"},anchorTo="SegmentedBar:"..a})
    local expected=Copy(unit.segmentedBars);expected[1].enabled=false
    assert(M.SetEnabled(Context(),a,false).ok);Equal(unit.segmentedBars,expected)
    local r=M.SetEnabled(Context(),a,false);assert(r.ok and not r.changed)
    expected[1],expected[2]=expected[2],expected[1]
    assert(M.Reorder(Context(),b,1).ok);Equal(unit.segmentedBars,expected)
    Reject(function()return M.Reorder(Context(),a,0)end,"invalid-position")
    Reject(function()return M.SetEnabled(Context(),a,1)end,"invalid-enabled")
    Reject(function()return M.Delete(Context(),"segmented-bar-missing")end,"instance-not-found")
end)
Test("invalid initial source, scope, anchors and runtime fields are atomic",function()
    Setup()
    for _,bad in ipairs({false,"bad",{id="segmented-bar-1"},
        {enabled=true,dataSource={id="chi",scope="player"}},
        {enabled=true,dataSource={id="runes",scope="target"}},
        {enabled=true,dataSource={id="runes",scope="player"},anchorTo="SegmentedBar:segmented-bar-missing"},
        {enabled=true,dataSource={id="runes",scope="player"},snapshot={ready=true}}})do
        Reject(function()return M.Add(Context(),bad)end)
    end
    local context,reason=M.CaptureContext("target");assert(not context and reason=="unsupported-unit")
end)
Test("corrupt duplicate IDs, self-anchor and cycle reject before any write",function()
    for _,mode in ipairs({"duplicate","self","cycle","runtime"})do
        local _,unit=Setup();local a,b=Add(),Add();local context=Context()
        local records=unit.segmentedBars
        if mode=="duplicate" then records[2].id=a
        elseif mode=="self" then records[1].anchorTo="SegmentedBar:"..a
        elseif mode=="cycle" then records[1].anchorTo="SegmentedBar:"..b;records[2].anchorTo="SegmentedBar:"..a
        else records[1].timer={remaining=3}end
        Reject(function()return M.Duplicate(context,a)end)
    end
end)
Test("deleted observed and generated IDs are never reused within the session",function()
    local _,unit=Setup()
    unit.segmentedBars={{id="segmented-bar-999",enabled=true,dataSource={id="runes",scope="player"}}}
    local old=Context();assert(M.Delete(Context(),"segmented-bar-999").ok)
    local a=Add();assert(a~="segmented-bar-999")
    local stale=Context();assert(M.Delete(Context(),a).ok);local b=Add();assert(a~=b)
    Reject(function()return M.SetEnabled(stale,a,false)end,"stale-context")
    Reject(function()return M.Delete(old,"segmented-bar-999")end,"stale-context")
end)
Test("layout A-B-A, unit replacement and in-place changes invalidate contexts",function()
    local db,unit=Setup();local a=Add();local stale=Context()
    db.global.UserLayouts["layout:other"]=Copy(db.global.UserLayouts["layout:existing"])
    db.char.activeLayoutId="layout:other";R.InvalidateActiveRuntimeRoot();assert(R.EnsureActiveRuntimeRoot(db))
    Reject(function()return M.Delete(stale,a)end,"stale-context")
    db.char.activeLayoutId="layout:existing";R.InvalidateActiveRuntimeRoot();assert(R.EnsureActiveRuntimeRoot(db))
    Reject(function()return M.Delete(stale,a)end,"stale-context")
    stale=Context();unit.segmentedBars[1].enabled=false
    Reject(function()return M.Delete(stale,a)end,"stale-context")
    stale=Context();db.global.UserLayouts["layout:existing"].payload.Units.player=Copy(unit)
    Reject(function()return M.Delete(stale,a)end,"stale-context")
end)
Test("workflow final guard, deferred callback, combat and consumed context fail closed",function()
    local _,unit=Setup();local a=Add();local context=Context()
    combat=true;Reject(function()return M.Delete(context,a)end,"combat-blocked");combat=false
    ns.LayoutEditWorkflow.RequestEditableLayoutForMutation=function(fn) R.InvalidateActiveRuntimeRoot();return workflow(fn)end
    local r=M.Delete(context,a);assert(not r.ok and r.errorCode=="stale-layout" and #unit.segmentedBars==1)
    Setup();a=Add();context=Context();local deferred
    ns.LayoutEditWorkflow.RequestEditableLayoutForMutation=function(fn)deferred=fn;return false,"confirmation-open"end
    Reject(function()return M.Delete(context,a)end,"confirmation-open")
    local before=Copy(ns.db);deferred();Equal(ns.db,before)
    ns.LayoutEditWorkflow.RequestEditableLayoutForMutation=normalWorkflow
    context=Context();assert(M.Delete(context,a).ok)
    Reject(function()return M.Add(context)end,"invalid-context")
end)
Test("copy and public transfer preserve reordered and empty collections",function()
    for _,empty in ipairs({false,true})do
        local db,unit=Setup();local a,b=Add(),Add();assert(M.Reorder(Context(),b,1).ok)
        if empty then assert(M.Delete(Context(),a).ok);assert(M.Delete(Context(),b).ok)end
        local expected=Copy(unit.segmentedBars)
        Equal(S.CopyPayload(db.global.UserLayouts["layout:existing"].payload).Units.player.segmentedBars,expected)
        local encoded=assert(ns.LayoutTransfer.Export("layout:existing"))
        local ok,id=ns.LayoutTransfer.Import(encoded);assert(ok,id)
        Equal(db.global.UserLayouts[id].payload.Units.player.segmentedBars,expected)
    end
end)
Test("legacy fields and built-ins remain unchanged; no implicit collection",function()
    local db,unit=Setup();assert(unit.segmentedBars==nil)
    unit.classPowerPresent=true;unit.showClassPowerBar=true;unit.classPowerColor={1,0,0,.5}
    local before=Copy(unit);Add();local after=Copy(unit);after.segmentedBars=nil;Equal(after,before)
    for _,id in ipairs({"default","classic","minimal","modern"})do
        db.char.activeLayoutId="builtin:"..id;R.InvalidateActiveRuntimeRoot();assert(R.EnsureActiveRuntimeRoot(db))
        local beforeDB=Copy(db);local ctx,reason=M.CaptureContext("player");assert(not ctx and reason=="readonly-layout")
        Equal(db,beforeDB)
        for _,config in pairs(R.GetActiveRuntimeRoot().units)do assert(config.segmentedBars==nil)end
    end
end)
print("Segmented Bar Mutations: "..count.." groups PASS")
