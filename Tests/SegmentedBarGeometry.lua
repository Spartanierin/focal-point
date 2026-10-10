-- Real mutation/Inspector/Canvas paths. Native rendering remains an ingame gate.
local function Read(path)local f=assert(io.open(path));local s=f:read("*a");f:close();return s end
local h=assert(load(Read("Tests/SegmentedBarSelection.lua")..
    "\nreturn {ns=ns,Setup=Setup,Add=Add,Context=Context,M=M,Copy=Copy,Equal=Equal,ui=ui,state=state,Select=Select,Nodes=Nodes,Build=BuildInspector,Find=Find}",
    "@SegmentedBarGeometry/Inspector"))()
local ns,M,Eq=h.ns,h.M,h.Equal
local count=0
local function Test(name,fn)fn();count=count+1;print("PASS: "..name)end
local function Setup()
    local db,unit=h.Setup();h.state.SetSingleSelection("player");h.state.ClearPropertyScope()
    local a,b=h.Add(),h.Add();h.Select(h.Nodes()[1]);return db,unit,a,b
end
local function Set(id,values)return M.SetGeometry(h.Context(),id,values)end
Test("atomic geometry, independent records, graph validation and no style/source writes",function()
    local db,u,a,b=Setup();local other=h.Copy(u.segmentedBars[2]);local legacy=u.classPowerBarWidth
    assert(Set(a,{width=230,height=27,offsetX=19,offsetY=-37,point="BOTTOMRIGHT",relativePoint="TOPRIGHT"}).ok)
    Eq(u.segmentedBars[2],other);assert(u.classPowerBarWidth==legacy)
    assert(Set(b,{anchorTo="SegmentedBar:"..a,width=157,height=19}).ok)
    for _,values in ipairs({{width=3},{height=0},{offsetX=0/0},{anchorTo="HealthBar"},
        {anchorTo="PowerBar"},{anchorTo="SegmentedBar:missing"},{anchorTo="SegmentedBar:"..a},
        {anchorTo="SegmentedBar:"..b},{growth="RIGHT_TO_LEFT"},{color={1,0,0,1}},{id=b}})do
        local before=h.Copy(db);assert(not Set(a,values).ok);Eq(db,before)
    end
    assert(M.Delete(h.Context(),a).errorCode=="anchor-in-use")
    local context=h.Context();assert(Set(b,{offsetX=42}).ok)
    assert(M.SetGeometry(context,a,{width=200}).errorCode=="stale-context")
end)
Test("Inspector loads seven fields and persists only selected ID; stale/released bindings fail closed",function()
    local db,u,a,b=Setup();local _,c,container=h.Build(true)
    assert(c.width:GetValue()==100 and c.height:GetValue()==12 and c.offsetX:GetValue()==0)
    c.width:Fire("OnValueChanged",211);c.height:Fire("OnValueChanged",23)
    c.offsetX:Fire("OnValueChanged",41);c.offsetY:Fire("OnValueChanged",-51)
    c.point:Fire("OnValueChanged","CENTER");c.relativePoint:Fire("OnValueChanged","BOTTOM")
    assert(u.segmentedBars[1].width==211 and u.segmentedBars[1].height==23)
    assert(u.segmentedBars[1].offsetX==41 and u.segmentedBars[1].offsetY==-51)
    assert(u.segmentedBars[1].point=="CENTER" and u.segmentedBars[1].relativePoint=="BOTTOM")
    assert(u.segmentedBars[2].width==nil)
    c.anchorTo:Fire("OnValueChanged","SegmentedBar:"..b)
    assert(u.segmentedBars[1].anchorTo=="SegmentedBar:"..b)
    c.anchorTo:Fire("OnValueChanged","HealthBar")
    assert(u.segmentedBars[1].anchorTo=="SegmentedBar:"..b and c.anchorTo:GetValue()=="SegmentedBar:"..b)
    h.Select(h.Nodes()[2]);h.Select(h.Nodes()[1]) -- same ID, different selection lifetime
    local before=h.Copy(db);c.width:Fire("OnValueChanged",299);Eq(db,before)
    h.ui.ace:Release(container)
    local _,fresh,newContainer=h.Build(true);assert(fresh.width:GetValue()==211)
    fresh.width:Fire("OnValueChanged",212);assert(u.segmentedBars[1].width==212)
    local callback=fresh.width.events.OnValueChanged
    h.ui.ace:Release(newContainer);before=h.Copy(db)
    callback(fresh.width,"OnValueChanged",333);Eq(db,before)
end)
Test("Inspector context survives own edits and canvas sync, but not combat/layout/root replacement",function()
    local db,u,a=Setup();local _,c,container=h.Build(true)
    assert(Set(a,{offsetX=73,offsetY=-28}).ok)
    assert(ns.GUI.Editor.Inspector.SetActiveCanvasDirectMoveOffsetValues("player",{kind="segmentedBar",unit="player",objectKey=a},73,-28))
    assert(c.offsetX:GetValue()==73 and c.offsetY:GetValue()==-28)
    c.width:Fire("OnValueChanged",222);assert(u.segmentedBars[1].width==222)
    local combat=InCombatLockdown;InCombatLockdown=function()return true end
    local before=h.Copy(db);c.width:Fire("OnValueChanged",333);Eq(db,before);InCombatLockdown=combat
    ns.ActiveLayoutResolver.InvalidateActiveRuntimeRoot();assert(ns.ActiveLayoutResolver.EnsureActiveRuntimeRoot(db))
    c.width:Fire("OnValueChanged",444);Eq(db,before);h.ui.ace:Release(container)
end)
Test("geometry persists through duplicate, codec and copy/materialize; built-ins remain read-only",function()
    local db,u,a,b=Setup()
    assert(Set(a,{width=210,height=26,offsetX=-77,offsetY=58}).ok)
    assert(Set(b,{anchorTo="SegmentedBar:"..a,point="LEFT",relativePoint="RIGHT"}).ok)
    local duplicated=M.Duplicate(h.Context(),a);assert(duplicated.ok)
    local copy=h.Copy(u.segmentedBars[1]);copy.id=duplicated.id;Eq(u.segmentedBars[2],copy)
    local payload=ns.LayoutService.CopyPayload({Units={player=u}})
    local encoded=assert(ns.LayoutTransferCodec.Encode(payload))
    local decoded=assert(ns.LayoutTransferCodec.Decode(encoded));Eq(decoded,payload)
    local materialized=ns.LayoutService.MaterializeUnit({},decoded.Units.player,"player")
    Eq(materialized.segmentedBars,u.segmentedBars)
    local context=h.Context();db.char.activeLayoutId="builtin:default"
    ns.ActiveLayoutResolver.InvalidateActiveRuntimeRoot();assert(ns.ActiveLayoutResolver.EnsureActiveRuntimeRoot(db))
    assert(not M.SetGeometry(context,a,{width=999}).ok);assert(not M.CaptureContext("player"))
end)

-- The runtime fixture uses actual holders/snapshot/renderer. Reuse its isolated DB.
local r=assert(load(Read("Tests/SegmentedBarRuntime.lua")..
    "\nreturn {ns=ns,Setup=Setup,UF=UF,B=B,f=f}","@SegmentedBarGeometry/Runtime"))()
ns=r.ns
r.f.Load("Services/LayoutMutations.lua");r.f.Load("GUI/Editor/LayoutEditWorkflow.lua")
M=ns.LayoutMutations.SegmentedBars
local canvas=ns.GUI.Editor.CanvasHoverOverlay
local describe=assert(h.Find(canvas.RouteSelectedComponentPointer,"ResolveDirectMoveDescriptor"))
local begin=assert(h.Find(canvas.RouteSelectedComponentPointer,"BeginDirectMoveDrag"))
local finish=assert(h.Find(canvas.RouteSelectedComponentPointer,"EndDirectMoveDrag"))
local selected,scope,cx,cy,combat
ns.GUI.Editor.ObjectSelection.GetSelectedObject=function()return selected end
ns.GUI.Editor.State.GetPropertyScope=function()return scope end
GetCursorPosition=function()return cx,cy end
InCombatLockdown=function()return combat end
IsMouseButtonDown=function()return true end
local function Select(id)
    selected={kind="segmentedBar",unit="player",objectKey=id};scope={objectKey=id}
end
local function DragSetup()
    combat=false;cx,cy=0,0
    local frame,legacy=r.Setup();r.UF:Refresh(frame);ns.framesUnlocked=true
    ns.frames={player=frame};frame.MoveOverlay=CreateFrame("Frame",nil,frame);frame.MoveOverlay:Show()
    canvas.UpdateFrame(frame);Select("segmented-bar-a")
    return frame,legacy,frame._focalPointCanvasHoverZones["segmentedBar:segmented-bar-a"]
end
local function Start(frame,zone)
    local descriptor=assert(describe(frame,selected))
    assert(begin(zone,{directMove=descriptor,selectionTarget=selected,selectionLocked=true,
        ownerFrame=frame,movementOwner=descriptor.holder}))
end
Test("actual Canvas move commits geometry only, anchors follow and snapshot is not reread",function()
    local frame,legacy,zone=DragSetup();local snapshot=frame.LiveValues.classPowerSnapshot
    local before=h.Copy(frame.config);local holder=frame._segmentedBars.byId["segmented-bar-a"]
    local other=frame._segmentedBars.byId["segmented-bar-b"]
    local api=GetRuneCooldown;GetRuneCooldown=function()error("geometry rereads Rune API")end
    local refresh=ns.RefreshUnitFrame;ns.RefreshUnitFrame=function()error("geometry full refresh")end
    Start(frame,zone);cx,cy=31,-17;zone:Run("OnUpdate");finish(zone,true)
    assert(frame.config.segmentedBars[1].offsetX==39 and frame.config.segmentedBars[1].offsetY==-24)
    Eq(frame.config.segmentedBars[2],before.segmentedBars[2]);assert(select(2,other:GetPoint(1))==holder)
    assert(select(4,holder:GetPoint(1))==39 and select(5,holder:GetPoint(1))==-24)
    assert(frame.LiveValues.classPowerSnapshot==snapshot and frame.Elements.ClassPowerBar==legacy)
    assert(holder.Bars[2].Countdown:GetText()=="5.0" and not holder.Bars[2].ReadyHighlight)
    ns.RefreshUnitFrame=refresh;GetRuneCooldown=api
end)
Test("actual Shift gesture uses selected holder and never moves the owning unit",function()
    local frame,_,zone=DragSetup();local expected=h.Copy(frame.config)
    ns.GUI.Editor.InteractionMode={IsShiftDown=function()return true end}
    zone:Run("OnMouseDown","LeftButton");assert(zone._focalPointGesture.mode=="direct")
    zone:Run("OnDragStart");assert(zone._focalPointDirectDragState.target==frame._segmentedBars.byId[selected.objectKey])
    cx=24;zone:Run("OnUpdate");zone:Run("OnDragStop")
    expected.segmentedBars[1].offsetX=32
    Eq(frame.config,expected)
    ns.GUI.Editor.InteractionMode=nil
end)
Test("Canvas cancels selection A-B-A, layout replacement, hide and combat without stale writes",function()
    for _,change in ipairs({function(frame)Select("segmented-bar-b");Select("segmented-bar-a")end,
        function(frame)ns.ActiveLayoutResolver.InvalidateActiveRuntimeRoot();assert(ns.ActiveLayoutResolver.EnsureActiveRuntimeRoot(ns.db))end,
        function(frame)r.B.Clear(frame)end,
        function()combat=true end})do
        local frame,_,zone=DragSetup();local before=h.Copy(ns.db)
        Start(frame,zone);cx=20;zone:Run("OnUpdate");change(frame);zone:Run("OnUpdate");finish(zone,true)
        Eq(ns.db,before)
        if not frame._segmentedBars.byId["segmented-bar-a"]._segmentedBarRendered then
            assert(not frame._segmentedBars.byId["segmented-bar-a"]:IsShown())
        end
    end
end)
Test("old Canvas holder cannot start an interaction against a newly activated layout",function()
    local frame=DragSetup();local old=frame.config
    local record=ns.db.global.UserLayouts["layout:runes"]
    ns.db.global.UserLayouts["layout:copy"]=r.f.Copy(record);ns.db.char.activeLayoutId="layout:copy"
    ns.ActiveLayoutResolver.InvalidateActiveRuntimeRoot();assert(ns.ActiveLayoutResolver.EnsureActiveRuntimeRoot(ns.db))
    assert(ns.ActiveLayoutResolver.GetActiveRuntimeRoot().units.player~=old)
    assert(describe(frame,selected)==nil)
end)
Test("50 move/layout/clear/reuse cycles retain independent IDs, growth and local timer ownership",function()
    local frame,legacy,zone=DragSetup();local other=h.Copy(frame.config.segmentedBars[2])
    local api=GetRuneCooldown;GetRuneCooldown=function()error("geometry/lifecycle rereads Rune API")end
    for i=1,50 do
        Select("segmented-bar-a");cx,cy=0,0;Start(frame,zone);cx=i;zone:Run("OnUpdate");finish(zone,true)
        Eq(frame.config.segmentedBars[2],other)
        local saved=h.Copy(ns.db);ns.db=h.Copy(saved)
        ns.ActiveLayoutResolver.InvalidateActiveRuntimeRoot();assert(ns.ActiveLayoutResolver.EnsureActiveRuntimeRoot(ns.db))
        frame.config=ns.ActiveLayoutResolver.GetActiveRuntimeRoot().units.player
        r.B.Clear(frame);r.B.Apply(frame);canvas.UpdateFrame(frame)
        local a,b=frame._segmentedBars.byId["segmented-bar-a"],frame._segmentedBars.byId["segmented-bar-b"]
        assert(a~=b and a.segments==b.segments and a.Bars[2].Countdown~=b.Bars[2].Countdown)
        assert(frame.Elements.ClassPowerBar==legacy and not a.Bars[2].ReadyHighlight)
        Eq(ns.db,saved)
    end
    GetRuneCooldown=api
end)
print("Segmented Bar Geometry: "..count.." groups PASS")
