-- D1: real source contract/mutations/transfer and existing canonical live provider.
-- No UI source selector or synthetic Holy Power provider is introduced.
local function Read(path)local f=assert(io.open(path));local s=f:read("*a");f:close();return s end
local source=Read("Tests/SegmentedBarMutations.lua")
local stop=assert(source:find('Test("add,',1,true))
local h=assert(load(source:sub(1,stop-1)..
    "\nreturn {ns=ns,M=M,Setup=Setup,Add=Add,Context=Context,Copy=Copy,Equal=Equal}","@Sources/Mutation"))()
local count=0
local function Test(name,fn)fn();count=count+1;print("PASS: "..name)end
local function Holy()return {id="holyPower",scope="player"}end
local function Runes()return {id="runes",scope="player"}end
Test("source mutation is atomic, detached, instance-local and preserves geometry/style",function()
    local db,u=h.Setup();local a,b=h.Add(),h.Add();local original=h.Copy(u.segmentedBars)
    local binding=Holy();local result=h.M.SetDataSource(h.Context(),a,binding);assert(result.ok and result.changed)
    binding.id="runes";assert(u.segmentedBars[1].dataSource.id=="holyPower")
    original[1].dataSource=Holy();h.Equal(u.segmentedBars,original)
    result=h.M.SetDataSource(h.Context(),a,Holy());assert(result.ok and not result.changed)
    for _,bad in ipairs({false,"holyPower",{id="holyPower"},{id="holyPower",scope="target"},
        {id="holyPower",scope="player",current=2},{id="comboPoints",scope="player"},setmetatable(Holy(),{})})do
        local before=h.Copy(db);local root=u.segmentedBars
        assert(not h.M.SetDataSource(h.Context(),a,bad).ok);h.Equal(db,before);assert(u.segmentedBars==root)
    end
    assert(not h.M.SetDataSource(h.Context(),a,nil).ok)
    local context=h.Context();assert(h.M.SetDataSource(h.Context(),b,Holy()).ok)
    assert(h.M.SetDataSource(context,a,Runes()).errorCode=="stale-context")
    local combat=InCombatLockdown;InCombatLockdown=function()return true end
    assert(h.M.SetDataSource(h.Context(),a,Runes()).errorCode=="combat-blocked");InCombatLockdown=combat
    local copy=h.M.Duplicate(h.Context(),a);assert(copy.ok)
    assert(u.segmentedBars[2].dataSource.id=="holyPower" and u.segmentedBars[2].dataSource~=u.segmentedBars[1].dataSource)
    context=h.Context();db.char.activeLayoutId="builtin:default"
    h.ns.ActiveLayoutResolver.InvalidateActiveRuntimeRoot();assert(h.ns.ActiveLayoutResolver.EnsureActiveRuntimeRoot(db))
    assert(not h.M.CaptureContext("player"));assert(not h.M.SetDataSource(context,a,Runes()).ok)
end)
Test("source mutation revalidates layout/combat at publication",function()
    local db,u=h.Setup();local a=h.Add();local workflow=h.ns.LayoutEditWorkflow.RequestEditableLayoutForMutation
    local before=h.Copy(db);local context=h.Context()
    h.ns.LayoutEditWorkflow.RequestEditableLayoutForMutation=function(callback)
        h.ns.ActiveLayoutResolver.InvalidateActiveRuntimeRoot();assert(h.ns.ActiveLayoutResolver.EnsureActiveRuntimeRoot(db))
        callback();return true
    end
    assert(not h.M.SetDataSource(context,a,Holy()).ok);h.Equal(db,before)
    h.ns.LayoutEditWorkflow.RequestEditableLayoutForMutation=workflow
    local combat=InCombatLockdown
    h.ns.LayoutEditWorkflow.RequestEditableLayoutForMutation=function(callback)
        InCombatLockdown=function()return true end;callback();return true
    end
    assert(h.M.SetDataSource(h.Context(),a,Holy()).errorCode=="combat-blocked");h.Equal(db,before)
    InCombatLockdown=combat;h.ns.LayoutEditWorkflow.RequestEditableLayoutForMutation=workflow
end)

local r=assert(load(Read("Tests/SegmentedBarRuntime.lua")..
    "\nreturn {ns=ns,UF=UF,Setup=Setup,B=B,f=f,Holders=Holders}","@Sources/Runtime"))()
local ns,UF,B,f=r.ns,r.UF,r.B,r.f
local Eq,Equal=f.Eq,f.Equal
local function CheckLegacyProjection(legacy,segments)
    local binding=assert(legacy._runeSlotBinding)
    Eq(binding.snapshot.info.segments,segments)
    for slot=1,6 do Eq(legacy.segments[slot],segments[binding.slotToApi[slot]])end
end
f.Load("Services/LayoutMutations.lua");f.Load("GUI/Editor/LayoutEditWorkflow.lua")
local M=ns.LayoutMutations.SegmentedBars
local function Context()return assert(M.CaptureContext("player"))end
local function Bind(frame,index,binding)
    local result=M.SetDataSource(Context(),frame.config.segmentedBars[index].id,binding)
    assert(result.ok,result.errorCode);B.Apply(frame)
end
local function NoTiming(holder)
    assert(not holder.segments and not holder:GetScript("OnUpdate"))
    for _,bar in ipairs(holder.Bars)do
        assert(not bar.ReadyHighlight)
        if bar.Countdown then assert(not bar.Countdown:IsShown());Eq(bar.Countdown:GetText(),"")end
    end
end
local function Setup()
    local frame,legacy=r.Setup("PALADIN")
    for _,record in ipairs(frame.config.segmentedBars)do record.dataSource=Holy()end
    -- The source does not depend on Legacy component presence/show.
    frame.config.classPowerBarPresent=false;frame.config.showClassPowerBar=false
    local state={current=2,max=5,reads=0}
    local power,max,runes=UnitPower,UnitPowerMax,GetRuneCooldown
    UnitPower=function(unit,id)if id==9 then state.reads=state.reads+1;return state.current end;return power(unit,id)end
    UnitPowerMax=function(unit,id)if id==9 then state.reads=state.reads+1;return state.max end;return max(unit,id)end
    GetRuneCooldown=function()error("Holy Power consumer read runes")end
    local function Restore()UnitPower,UnitPowerMax,GetRuneCooldown=power,max,runes end
    return frame,legacy,state,Restore
end
Test("two Holy Power instances share one read pair; real zero/current/dynamic maximum and independent styles",function()
    local frame,legacy,state,restore=Setup()
    local before=f.Copy(frame.config);local observations=0
    for _,values in ipairs({{0,5},{2,5},{5,5},{4,4},{6,6}})do
        state.current,state.max=table.unpack(values);UF:Refresh(frame);observations=observations+1
        Eq(state.reads,observations*2)
        local a,b=r.Holders(frame);assert(a:IsShown() and b:IsShown())
        for _,holder in ipairs({a,b})do
            NoTiming(holder)
            for i,bar in ipairs(holder.Bars)do
                Eq(bar:IsShown(),i<=state.max)
                if i<=state.max then Eq(bar:GetValue(),i<=state.current and 1 or 0)end
            end
        end
        Equal(a.Bars[1].lastSetStatusBarColor,{.2,.4,.6,0})
        Equal(b.Bars[1].lastSetStatusBarColor,{.8,.6,.4,.7})
        Eq(a.Bars[1]:GetWidth(),(130-(state.max-1)*2)/state.max)
        Eq(select(1,a.Bars[1]:GetPoint(1)),"TOPLEFT");Eq(select(1,b.Bars[1]:GetPoint(1)),"TOPRIGHT")
        local snapshot=frame.LiveValues.classPowerSnapshot
        for i=1,20 do B.Apply(frame)end
        Eq(frame.LiveValues.classPowerSnapshot,snapshot);Eq(state.reads,observations*2)
    end
    local a,b=r.Holders(frame);local reads=state.reads
    assert(M.SetStyle(Context(),frame.config.segmentedBars[1].id,{color={.1,.2,.3,0},spacing=1}).ok)
    B.Apply(frame);Eq(state.reads,reads);Equal(b.Bars[1].lastSetStatusBarColor,{.8,.6,.4,.7})
    before.segmentedBars=frame.config.segmentedBars;Equal(frame.config,before)
    assert(not legacy:IsShown());restore()
end)
Test("unknown/secret/unavailable/current and invalid or over-capacity max never paint a fake zero",function()
    local frame,_,state,restore=Setup();UF:Refresh(frame);local a,b=r.Holders(frame)
    local secret={};local oldSecret=issecretvalue
    issecretvalue=function(v)return v==secret or (oldSecret and oldSecret(v))end
    for _,value in ipairs({secret,-1,7,0/0,math.huge})do
        state.current=value;UF:Refresh(frame);assert(not a:IsShown() and not b:IsShown());NoTiming(a)
    end
    state.current=nil;UF:Refresh(frame);assert(not a:IsShown())
    state.current=2
    for _,value in ipairs({secret,0,-1,2.5,7,0/0,math.huge})do
        state.max=value;UF:Refresh(frame);assert(not a:IsShown());NoTiming(a)
    end
    state.max=5;UF:Refresh(frame);assert(a:IsShown())
    local api=UnitPower;UnitPower=nil;UF:Refresh(frame);assert(not a:IsShown());UnitPower=api
    api=UnitPowerMax;UnitPowerMax=nil;UF:Refresh(frame);assert(not a:IsShown());UnitPowerMax=api
    UF:Refresh(frame);local published=frame.LiveValues.classPowerSnapshot
    for _,change in ipairs({
        function(s)s.currentKnown=false end,function(s)s.maxKnown=false end,
        function(s)s.info.currentKnown=false end,function(s)s.info.maxKnown=false end,
        function(s)s.source="preview";s.sourceInfo=nil end,function(s)s.sourceInfo={}end,
        function(s)s.context.class="DEATHKNIGHT"end,function(s)s.info.token="CHI"end,
        function(s)s.info.typeId=12 end,function(s)s.info.current=secret end,
        function(s)s.info.max=secret end,function(s)s.context.config={}end,
    })do
        local snapshot=f.Copy(published);snapshot.context.config=frame.config;snapshot.sourceInfo=snapshot.info
        change(snapshot);frame.LiveValues.classPowerSnapshot=snapshot;B.Apply(frame);assert(not a:IsShown());NoTiming(a)
    end
    frame.LiveValues.classPowerSnapshot=published
    assert(M.SetStyle(Context(),frame.config.segmentedBars[1].id,{spacing=40}).ok)
    B.Apply(frame);assert(not a:IsShown() and b:IsShown())
    issecretvalue=oldSecret;restore()
end)
Test("source binding mismatch hides only that visual, preserving objects and shared data",function()
    local frame,_,state,restore=Setup();UF:Refresh(frame);local a,b=r.Holders(frame)
    local snapshot=frame.LiveValues.classPowerSnapshot;Bind(frame,1,Runes())
    assert(not a:IsShown() and b:IsShown());Eq(frame.LiveValues.classPowerSnapshot,snapshot)
    Eq(#frame.config.segmentedBars,2);NoTiming(a)
    Bind(frame,1,Holy());assert(a:IsShown());restore()
    frame=r.Setup("DEATHKNIGHT");UF:Refresh(frame);a,b=r.Holders(frame)
    snapshot=frame.LiveValues.classPowerSnapshot;Bind(frame,1,Holy())
    assert(not a:IsShown() and b:IsShown());Eq(frame.LiveValues.classPowerSnapshot,snapshot);NoTiming(a)
    Bind(frame,1,Runes());assert(a:IsShown() and a:GetScript("OnUpdate"))
    Eq(a.segments,snapshot.info.segments);Eq(a.Bars[2].Countdown:GetText(),"5.0")
end)
Test("50 Rune-Holy-Rune/pool/layout/spec/combat/hide cycles clear local timing and preserve Legacy/source identity",function()
    local frame,legacy=r.Setup("DEATHKNIGHT");UF:Refresh(frame)
    local a,b=r.Holders(frame);local original=f.Copy(frame.config.segmentedBars)
    local power,max,combat=UnitPower,UnitPowerMax,InCombatLockdown
    UnitPower=function(unit,id)if id==9 then return 2 end;return power(unit,id)end
    UnitPowerMax=function(unit,id)if id==9 then return 5 end;return max(unit,id)end
    local widgets={[a]={table.unpack(a.Bars)},[b]={table.unpack(b.Bars)}}
    for cycle=1,50 do
        f.Time(100);f.Class("PALADIN");f.Spec(cycle%3+1)
        frame.config.segmentedBars={};B.Apply(frame)
        frame.config.segmentedBars=f.Copy(original)
        for _,record in ipairs(frame.config.segmentedBars)do record.dataSource=Holy()end
        InCombatLockdown=function()return cycle%2==0 end
        UF:Refresh(frame);a,b=r.Holders(frame)
        assert(a:IsShown() and b:IsShown());NoTiming(a);NoTiming(b)
        a:Hide();a:Show();NoTiming(a);Eq(a.Bars[2]:GetValue(),1)
        local shared=frame.LiveValues.classPowerSnapshot;B.Clear(frame);Eq(frame.LiveValues.classPowerSnapshot,shared)
        B.Apply(frame);assert(a:IsShown());NoTiming(a)
        f.Class("DEATHKNIGHT");frame.config.segmentedBars=f.Copy(original)
        UF:Refresh(frame);a,b=r.Holders(frame)
        Eq(a.segments,frame.LiveValues.classPowerSnapshot.info.segments);Eq(b.segments,a.segments)
        CheckLegacyProjection(legacy,a.segments)
        Eq(a.Bars[2].Countdown:GetText(),"5.0");assert(a:GetScript("OnUpdate"))
        for _,holder in ipairs({a,b})do
            assert(widgets[holder],"unexpected holder allocation")
            for i,bar in ipairs(holder.Bars)do Eq(bar,widgets[holder][i]);assert(not bar.ReadyHighlight)end
        end
        ns.ActiveLayoutResolver.InvalidateActiveRuntimeRoot();assert(ns.ActiveLayoutResolver.EnsureActiveRuntimeRoot(ns.db))
        UF:ApplyConfig(frame)
    end
    UnitPower,UnitPowerMax,InCombatLockdown=power,max,combat
end)
Test("in-place source switch clears rune timing before aggregate Apply without recycling the holder",function()
    local frame,legacy=r.Setup("DEATHKNIGHT");UF:Refresh(frame);local a,b=r.Holders(frame)
    local timer=a.Bars[2].Countdown;local api,max=UnitPower,UnitPowerMax
    assert(a:GetScript("OnUpdate") and timer:IsShown())
    assert(M.SetDataSource(Context(),frame.config.segmentedBars[1].id,Holy()).ok)
    f.Class("PALADIN")
    UnitPower=function(unit,id)if id==9 then return 2 end;return api(unit,id)end
    UnitPowerMax=function(unit,id)if id==9 then return 5 end;return max(unit,id)end
    UF:Refresh(frame);Eq(select(1,r.Holders(frame)),a)
    assert(a:IsShown() and not b:IsShown());NoTiming(a);Eq(a.Bars[2]:GetValue(),1)
    a:Hide();a:Show();NoTiming(a);Eq(a.Bars[2]:GetValue(),1)
    assert(M.SetDataSource(Context(),frame.config.segmentedBars[1].id,Runes()).ok)
    f.Class("DEATHKNIGHT");UF:Refresh(frame)
    Eq(a.Bars[2].Countdown,timer);assert(timer:IsShown() and a:GetScript("OnUpdate"))
    CheckLegacyProjection(legacy,a.segments);Eq(timer:GetText(),"5.0")
    UnitPower,UnitPowerMax=api,max
end)

source=Read("Tests/SegmentedBarContract.lua");stop=assert(source:find('Test("pure validator',1,true))
local t=assert(load(source:sub(1,stop-1)..
    "\nreturn {ns=ns,S=S,T=T,N=N,C=C,Records=Records,Layout=Layout,Target=Target,Generator=Generator,Equal=Equal}","@Sources/Transfer"))()
Test("mixed sources copy/export/import with the same strict validator and no migration",function()
    local records=t.Records();records[2].dataSource=Holy()
    local db,layout=t.Layout(records);t.ns.db=db;db.global.UserLayouts["layout:source"]=layout
    t.Equal(t.S.CopyPayload(layout.payload).Units.player.segmentedBars,records)
    local encoded=assert(t.T.Export("layout:source"));local target=t.Target()
    local ok,id=t.T.Import(encoded);assert(ok,id);t.Equal(target.global.UserLayouts[id].payload.Units.player.segmentedBars,records)
    local legacy={transferSchema=1,formatVersion=1,addonVersion="old",name="Mixed",
        payload={Units={player={segmentedBars=records,Texts={}}},TextTemplates={}}}
    target=t.Target();ok,id=t.T.Import(assert(t.C.Encode(legacy)),{generator=t.Generator()});assert(ok,id)
    t.Equal(target.global.UserLayouts[id].payload.Units.player.segmentedBars,records)
    records[2].dataSource.scope="target";assert(not t.S.ValidateSegmentedBars(records,"player"))
    assert(not t.N.Export(layout,db));assert(not t.N.PrepareLegacyImport(assert(t.C.Encode(legacy)),t.Target(),t.Generator()).ready)
    records[2].dataSource={id="essence",scope="player"};assert(not t.S.ValidateSegmentedBars(records,"player"))
end)
print("Segmented Bar Sources: "..count.." groups PASS")
