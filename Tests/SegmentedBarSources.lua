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
local function Arcane()return {id="arcaneCharges",scope="player"}end
local function Chi()return {id="chi",scope="player"}end
local function Combo()return {id="comboPoints",scope="player"}end
local function Runes()return {id="runes",scope="player"}end
Test("source mutation is atomic, detached, instance-local and preserves geometry/style",function()
    local db,u=h.Setup();local a,b=h.Add(),h.Add();local original=h.Copy(u.segmentedBars)
    local binding=Holy();local result=h.M.SetDataSource(h.Context(),a,binding);assert(result.ok and result.changed)
    binding.id="runes";assert(u.segmentedBars[1].dataSource.id=="holyPower")
    original[1].dataSource=Holy();h.Equal(u.segmentedBars,original)
    result=h.M.SetDataSource(h.Context(),a,Holy());assert(result.ok and not result.changed)
    for _,bad in ipairs({false,"holyPower",{id="holyPower"},{id="holyPower",scope="target"},
        {id="holyPower",scope="player",current=2},{id="essence",scope="player"},setmetatable(Holy(),{})})do
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

local function SetupArcane()
    local frame,legacy=r.Setup("MAGE");f.Spec(1)
    for _,record in ipairs(frame.config.segmentedBars)do record.dataSource=Arcane()end
    frame.config.classPowerBarPresent=false;frame.config.showClassPowerBar=false
    local state={current=3,max=4,reads=0}
    local power,max,runes=UnitPower,UnitPowerMax,GetRuneCooldown
    UnitPower=function(unit,id)
        if id==16 then state.reads=state.reads+1;return state.current end
        return power(unit,id)
    end
    UnitPowerMax=function(unit,id)
        if id==16 then state.reads=state.reads+1;return state.max end
        return max(unit,id)
    end
    GetRuneCooldown=function()error("Arcane Charges consumer read runes")end
    local function Restore()UnitPower,UnitPowerMax,GetRuneCooldown=power,max,runes end
    return frame,legacy,state,Restore
end
Test("two Arcane Charges instances share live 0/4, 3/4 and 4/4 without extra reads or flashes",function()
    local frame,legacy,state,restore=SetupArcane()
    local oldColors=PowerBarColor
    PowerBarColor={ARCANE_CHARGES={r=.9,g=.7,b=.1}}
    frame.config.segmentedBars[2].useBlizzardColor=true
    frame.config.segmentedBars[2].color={.8,.6,.4,0}
    for refresh,values in ipairs({{3,4},{0,4},{4,4}})do
        state.current,state.max=table.unpack(values);UF:Refresh(frame)
        Eq(state.reads,refresh*2)
        local a,b=r.Holders(frame);assert(a:IsShown() and b:IsShown())
        for _,holder in ipairs({a,b})do
            NoTiming(holder)
            for i,bar in ipairs(holder.Bars)do
                Eq(bar:IsShown(),i<=state.max)
                if i<=state.max then Eq(bar:GetValue(),i<=state.current and 1 or 0)end
            end
        end
        Equal(a.Bars[1].lastSetStatusBarColor,{.2,.4,.6,0})
        Equal(b.Bars[1].lastSetStatusBarColor,{.9,.7,.1,0})
        Eq(a.Bars[1]:GetWidth(),(130-3*2)/4)
        local snapshot=frame.LiveValues.classPowerSnapshot
        Eq(snapshot.sourceInfo,snapshot.info);Eq(snapshot.info.token,"ARCANE_CHARGES")
        for i=1,20 do B.Apply(frame)end
        Eq(state.reads,refresh*2);Eq(frame.LiveValues.classPowerSnapshot,snapshot)
    end
    assert(not legacy:IsShown())
    PowerBarColor=oldColors;restore()
end)
Test("Arcane Charges fail closed for bad raw values, source identity, context and preview",function()
    local frame,_,state,restore=SetupArcane();UF:Refresh(frame)
    local a,b=r.Holders(frame);local records=f.Copy(frame.config.segmentedBars)
    local secret={};local oldSecret=issecretvalue
    issecretvalue=function(v)return v==secret or (oldSecret and oldSecret(v))end
    for _,value in ipairs({secret,-1,5,1.5,0/0,math.huge})do
        state.current=value;UF:Refresh(frame);assert(not a:IsShown() and not b:IsShown());NoTiming(a)
    end
    state.current=nil;UF:Refresh(frame);assert(not a:IsShown())
    state.current=3
    for _,value in ipairs({secret,0,-1,2.5,7,0/0,math.huge})do
        state.max=value;UF:Refresh(frame);assert(not a:IsShown());NoTiming(a)
    end
    state.max=nil;UF:Refresh(frame);assert(not a:IsShown())
    state.max=4;UF:Refresh(frame);assert(a:IsShown() and b:IsShown())
    local published=frame.LiveValues.classPowerSnapshot;local reads=state.reads
    for _,change in ipairs({
        function(s)s.currentKnown=false end,function(s)s.maxKnown=false end,
        function(s)s.info.currentKnown=false end,function(s)s.info.maxKnown=false end,
        function(s)s.info.rawCurrent=secret end,function(s)s.info.rawMax=secret end,
        function(s)s.info.current=2.5 end,function(s)s.info.max=7 end,
        function(s)s.source="preview";s.sourceInfo=nil end,function(s)s.sourceInfo={}end,
        function(s)s.context.class="PALADIN"end,function(s)s.context.spec=2 end,
        function(s)s.context.spec=secret end,function(s)s.context.unit="target"end,
        function(s)s.info.token="CHI"end,function(s)s.info.token=secret end,
        function(s)s.info.typeId=12 end,function(s)s.info.typeId=secret end,
        function(s)s.context.config={}end,
    })do
        local snapshot=f.Copy(published);snapshot.context.config=frame.config;snapshot.sourceInfo=snapshot.info
        change(snapshot);frame.LiveValues.classPowerSnapshot=snapshot;B.Apply(frame)
        assert(not a:IsShown() and not b:IsShown());NoTiming(a)
    end
    Eq(state.reads,reads);Equal(frame.config.segmentedBars,records)
    frame.LiveValues.classPowerSnapshot=published;B.Apply(frame);assert(a:IsShown() and b:IsShown())
    f.Spec(2);UF:Refresh(frame);assert(not a:IsShown() and not b:IsShown())
    f.Spec(1);f.Class("PALADIN");UF:Refresh(frame);assert(not a:IsShown() and not b:IsShown())
    f.Class("MAGE");UF:Refresh(frame);assert(a:IsShown() and b:IsShown())
    local finalReads=state.reads
    frame.config.segmentedBars[1].dataSource={id="auto",scope="player"}
    B.Apply(frame);assert(a:IsShown() and b:IsShown())
    frame.config.segmentedBars[1].dataSource=Arcane()
    frame.config.segmentedBars[1].spacing=50
    B.Apply(frame);assert(not a:IsShown() and b:IsShown())
    frame.config.segmentedBars[1].spacing=2
    B.Apply(frame);assert(a:IsShown() and b:IsShown());Eq(state.reads,finalReads)
    issecretvalue=oldSecret;restore()
end)
Test("50 Arcane Charges clear, pool, spec, combat and hide cycles retain fixed widgets",function()
    local frame,_,state,restore=SetupArcane();UF:Refresh(frame)
    local a,b=r.Holders(frame);local records=f.Copy(frame.config.segmentedBars)
    local widgets={[a]={table.unpack(a.Bars)},[b]={table.unpack(b.Bars)}}
    local oldCombat=InCombatLockdown
    for cycle=1,50 do
        frame.config.segmentedBars={};B.Apply(frame)
        frame.config.segmentedBars=f.Copy(records)
        InCombatLockdown=function()return cycle%2==0 end
        f.Spec(2);UF:Refresh(frame);a,b=r.Holders(frame)
        assert(not a:IsShown() and not b:IsShown());NoTiming(a)
        f.Spec(1);state.current=cycle%5;UF:Refresh(frame)
        a,b=r.Holders(frame);assert(a:IsShown() and b:IsShown())
        a:Hide();a:Show();NoTiming(a)
        local snapshot=frame.LiveValues.classPowerSnapshot
        B.Clear(frame);Eq(frame.LiveValues.classPowerSnapshot,snapshot)
        B.Apply(frame);assert(a:IsShown());NoTiming(a)
        for _,holder in ipairs({a,b})do
            for i,bar in ipairs(holder.Bars)do Eq(bar,widgets[holder][i]);assert(not bar.ReadyHighlight)end
        end
    end
    InCombatLockdown=oldCombat;restore()
end)

local function SetupChi()
    local frame,legacy=r.Setup("MONK");f.Spec(3)
    for _,record in ipairs(frame.config.segmentedBars)do record.dataSource=Chi()end
    frame.config.classPowerBarPresent=false;frame.config.showClassPowerBar=false
    local state={current=4,max=6,reads=0}
    local power,max,runes=UnitPower,UnitPowerMax,GetRuneCooldown
    UnitPower=function(unit,id)
        if id==12 then state.reads=state.reads+1;return state.current end
        return power(unit,id)
    end
    UnitPowerMax=function(unit,id)
        if id==12 then state.reads=state.reads+1;return state.max end
        return max(unit,id)
    end
    GetRuneCooldown=function()error("Chi consumer read runes")end
    local function Restore()UnitPower,UnitPowerMax,GetRuneCooldown=power,max,runes end
    return frame,legacy,state,Restore
end
Test("two Chi instances share live 4/6, 0/6 and 6/6 without extra reads or flashes",function()
    local frame,legacy,state,restore=SetupChi()
    local oldColors=PowerBarColor
    PowerBarColor={CHI={r=.9,g=.7,b=.1}}
    frame.config.segmentedBars[2].useBlizzardColor=true
    frame.config.segmentedBars[2].color={.8,.6,.4,0}
    for refresh,values in ipairs({{4,6},{0,6},{6,6}})do
        state.current,state.max=table.unpack(values);UF:Refresh(frame)
        Eq(state.reads,refresh*2)
        local a,b=r.Holders(frame);assert(a:IsShown() and b:IsShown())
        for _,holder in ipairs({a,b})do
            NoTiming(holder)
            for i,bar in ipairs(holder.Bars)do
                Eq(bar:IsShown(),i<=state.max)
                if i<=state.max then Eq(bar:GetValue(),i<=state.current and 1 or 0)end
            end
        end
        Equal(a.Bars[1].lastSetStatusBarColor,{.2,.4,.6,0})
        Equal(b.Bars[1].lastSetStatusBarColor,{.9,.7,.1,0})
        Eq(a.Bars[1]:GetWidth(),(130-5*2)/6)
        local snapshot=frame.LiveValues.classPowerSnapshot
        Eq(snapshot.sourceInfo,snapshot.info);Eq(snapshot.info.token,"CHI")
        for i=1,20 do B.Apply(frame)end
        Eq(state.reads,refresh*2);Eq(frame.LiveValues.classPowerSnapshot,snapshot)
    end
    assert(not legacy:IsShown())
    PowerBarColor=oldColors;restore()
end)
Test("Chi fails closed for bad raw values, wrong context and preview",function()
    local frame,_,state,restore=SetupChi();UF:Refresh(frame)
    local a,b=r.Holders(frame);local records=f.Copy(frame.config.segmentedBars)
    local secret={};local oldSecret=issecretvalue
    issecretvalue=function(v)return v==secret or (oldSecret and oldSecret(v))end
    for _,value in ipairs({secret,-1,7,1.5,0/0,math.huge})do
        state.current=value;UF:Refresh(frame);assert(not a:IsShown() and not b:IsShown());NoTiming(a)
    end
    state.current=nil;UF:Refresh(frame);assert(not a:IsShown())
    state.current=4
    for _,value in ipairs({secret,0,-1,2.5,7,0/0,math.huge})do
        state.max=value;UF:Refresh(frame);assert(not a:IsShown());NoTiming(a)
    end
    state.max=nil;UF:Refresh(frame);assert(not a:IsShown())
    state.max=6;UF:Refresh(frame);assert(a:IsShown() and b:IsShown())
    local published=frame.LiveValues.classPowerSnapshot;local reads=state.reads
    for _,change in ipairs({
        function(s)s.currentKnown=false end,function(s)s.maxKnown=false end,
        function(s)s.info.currentKnown=false end,function(s)s.info.maxKnown=false end,
        function(s)s.info.rawCurrent=secret end,function(s)s.info.rawMax=secret end,
        function(s)s.info.current=1.5 end,function(s)s.info.max=7 end,
        function(s)s.source="preview";s.sourceInfo=nil end,function(s)s.sourceInfo={}end,
        function(s)s.context.class="MAGE"end,function(s)s.context.spec=1 end,
        function(s)s.context.spec=secret end,function(s)s.context.unit="target"end,
        function(s)s.info.token="ARCANE_CHARGES"end,function(s)s.info.token=secret end,
        function(s)s.info.typeId=16 end,function(s)s.info.typeId=secret end,
        function(s)s.context.config={}end,
    })do
        local snapshot=f.Copy(published);snapshot.context.config=frame.config;snapshot.sourceInfo=snapshot.info
        change(snapshot);frame.LiveValues.classPowerSnapshot=snapshot;B.Apply(frame)
        assert(not a:IsShown() and not b:IsShown());NoTiming(a)
    end
    Eq(state.reads,reads);Equal(frame.config.segmentedBars,records)
    frame.LiveValues.classPowerSnapshot=published;B.Apply(frame);assert(a:IsShown() and b:IsShown())
    f.Spec(1);UF:Refresh(frame);assert(not a:IsShown() and not b:IsShown())
    f.Spec(2);UF:Refresh(frame);assert(not a:IsShown() and not b:IsShown())
    f.Spec(3);f.Class("MAGE");UF:Refresh(frame);assert(not a:IsShown() and not b:IsShown())
    f.Class("MONK");UF:Refresh(frame);assert(a:IsShown() and b:IsShown())
    local finalReads=state.reads
    frame.config.segmentedBars[1].dataSource={id="auto",scope="player"}
    B.Apply(frame);assert(a:IsShown() and b:IsShown())
    frame.config.segmentedBars[1].dataSource=Chi()
    frame.config.segmentedBars[1].spacing=50
    B.Apply(frame);assert(not a:IsShown() and b:IsShown())
    frame.config.segmentedBars[1].spacing=2
    B.Apply(frame);assert(a:IsShown() and b:IsShown());Eq(state.reads,finalReads)
    issecretvalue=oldSecret;restore()
end)
Test("50 Chi clear, pool, spec, combat and hide cycles retain fixed widgets",function()
    local frame,_,state,restore=SetupChi();UF:Refresh(frame)
    local a,b=r.Holders(frame);local records=f.Copy(frame.config.segmentedBars)
    local widgets={[a]={table.unpack(a.Bars)},[b]={table.unpack(b.Bars)}}
    local oldCombat=InCombatLockdown
    for cycle=1,50 do
        frame.config.segmentedBars={};B.Apply(frame)
        frame.config.segmentedBars=f.Copy(records)
        InCombatLockdown=function()return cycle%2==0 end
        f.Spec(1);UF:Refresh(frame);a,b=r.Holders(frame)
        assert(not a:IsShown() and not b:IsShown());NoTiming(a)
        f.Spec(3);state.current=cycle%7;UF:Refresh(frame)
        a,b=r.Holders(frame);assert(a:IsShown() and b:IsShown())
        a:Hide();a:Show();NoTiming(a)
        local snapshot=frame.LiveValues.classPowerSnapshot
        B.Clear(frame);Eq(frame.LiveValues.classPowerSnapshot,snapshot)
        B.Apply(frame);assert(a:IsShown());NoTiming(a)
        for _,holder in ipairs({a,b})do
            for i,bar in ipairs(holder.Bars)do Eq(bar,widgets[holder][i]);assert(not bar.ReadyHighlight)end
        end
    end
    InCombatLockdown=oldCombat;restore()
end)

local function SetupCombo(class)
    local frame,legacy=r.Setup(class or "ROGUE")
    for _,record in ipairs(frame.config.segmentedBars)do record.dataSource=Combo()end
    frame.config.classPowerBarPresent=false;frame.config.showClassPowerBar=false
    local state={current=3,max=5,reads=0,energy=3,shred=true,gateReads=0}
    local power,max,powerType,spellBook,runes=UnitPower,UnitPowerMax,UnitPowerType,C_SpellBook,GetRuneCooldown
    UnitPower=function(unit,id)
        if id==4 then state.reads=state.reads+1;return state.current end
        return power(unit,id)
    end
    UnitPowerMax=function(unit,id)
        if id==4 then state.reads=state.reads+1;return state.max end
        return max(unit,id)
    end
    UnitPowerType=function(unit)state.gateReads=state.gateReads+1;return state.energy end
    C_SpellBook={IsSpellKnown=function(id)Eq(id,5221);state.gateReads=state.gateReads+1;return state.shred end}
    GetRuneCooldown=function()error("Combo Points consumer read runes")end
    local function Restore()
        UnitPower,UnitPowerMax,UnitPowerType,C_SpellBook,GetRuneCooldown=power,max,powerType,spellBook,runes
    end
    return frame,legacy,state,Restore
end
Test("Rogue canvas keeps one selected ID and record geometry through Combo, Chi and disabled",function()
    local frame,_,state,restore=SetupCombo("ROGUE");UF:Refresh(frame)
    local a=r.Holders(frame)
    local record=frame.config.segmentedBars[1]
    local ref={kind="segmentedBar",unit="player",objectKey=record.id}
    local resolve=ns.GUI.Editor.SelectionGeometryResolver.Resolve
    local canvas=ns.GUI.Editor.CanvasHoverOverlay
    local selection=ns.GUI.Editor.ObjectSelection
    local oldSelected,oldSelect=selection.GetSelectedObject,selection.SelectObject
    local clicked
    selection.GetSelectedObject=function()return ref end
    selection.SelectObject=function(value)clicked=value;return true end
    ns.framesUnlocked=true;frame.MoveOverlay=CreateFrame("Frame",nil,frame);frame.MoveOverlay:Show()
    local geometry=assert(resolve(frame,ref));Eq(geometry.source,"segmented-bar-holder");Eq(geometry.target,a)
    canvas.UpdateFrame(frame)
    local zone=assert(frame._focalPointCanvasHoverZones["segmentedBar:"..record.id])
    assert(zone:IsShown() and zone.lastSetBackdropBorderColor[4]>0)
    local reads=state.reads
    record.dataSource=Chi();B.Apply(frame)
    assert(not a:IsShown() and not B.GetVisibleHolder(frame,record.id))
    a:SetSize(0,0) -- Native hidden-size mismatch; record geometry remains authoritative.
    geometry=assert(resolve(frame,ref));Eq(geometry.source,"segmented-bar-config")
    Eq(geometry.width,130);Eq(geometry.height,14)
    Eq(geometry.points[1].relativeTo,frame);Eq(geometry.points[1].offsetX,8);Eq(geometry.points[1].offsetY,-7)
    canvas.UpdateFrame(frame)
    assert(zone:IsShown() and zone.lastSetBackdropBorderColor[4]>0)
    Eq(zone:GetWidth(),130);Eq(zone:GetHeight(),14)
    Eq(select(2,zone:GetPoint(1)),frame)
    zone:Run("OnMouseUp","LeftButton");Eq(clicked.objectKey,record.id)
    record.enabled=false;B.Apply(frame);a:SetSize(0,0);canvas.UpdateFrame(frame)
    assert(not a:IsShown() and zone:IsShown() and zone.lastSetBackdropBorderColor[4]>0)
    for _,bad in ipairs({0,0/0,math.huge,"unknown",{}})do
        record.width=bad
        Eq(resolve(frame,ref),nil)
        canvas.UpdateFrame(frame);assert(not zone:IsShown())
    end
    record.width=130
    local oldSecret=issecretvalue
    issecretvalue=function(value)return value==130 or (oldSecret and oldSecret(value))end
    Eq(resolve(frame,ref),nil)
    issecretvalue=oldSecret
    record.height=0
    Eq(resolve(frame,ref),nil)
    record.height=14
    record.enabled=true;record.dataSource=Combo();B.Apply(frame)
    geometry=assert(resolve(frame,ref));Eq(geometry.source,"segmented-bar-holder");Eq(geometry.target,a)
    canvas.UpdateFrame(frame);assert(zone:IsShown() and zone.lastSetBackdropBorderColor[4]>0)
    Eq(state.reads,reads)
    selection.GetSelectedObject,selection.SelectObject=oldSelected,oldSelect
    ns.framesUnlocked=false;restore()
end)
Test("Rogue Combo Points in three specs: two holders share 0, 1, max and independent styles",function()
    local frame,legacy,state,restore=SetupCombo("ROGUE")
    local oldColors=PowerBarColor
    PowerBarColor={COMBO_POINTS={r=.9,g=.7,b=.1}}
    frame.config.segmentedBars[2].useBlizzardColor=true
    frame.config.segmentedBars[2].color={.8,.6,.4,0}
    frame.config.segmentedBars[1].backgroundColor={.1,.2,.3,.4}
    for refresh,values in ipairs({{1,0,5},{2,1,5},{3,6,6}})do
        f.Spec(values[1]);state.current,state.max=values[2],values[3];UF:Refresh(frame)
        Eq(state.reads,refresh*2)
        local gates=state.gateReads
        local a,b=r.Holders(frame);assert(a:IsShown() and b:IsShown())
        for _,holder in ipairs({a,b})do
            NoTiming(holder)
            for i,bar in ipairs(holder.Bars)do
                Eq(bar:IsShown(),i<=state.max)
                if i<=state.max then Eq(bar:GetValue(),i<=state.current and 1 or 0)end
            end
        end
        Equal(a.Bars[1].lastSetStatusBarColor,{.2,.4,.6,0})
        Equal(b.Bars[1].lastSetStatusBarColor,{.9,.7,.1,0})
        Equal(a.Bars[1].bg.lastSetVertexColor,{.1,.2,.3,.4})
        Eq(a.Bars[1]:GetWidth(),(130-(state.max-1)*2)/state.max)
        Eq(select(1,a.Bars[1]:GetPoint(1)),"TOPLEFT")
        Eq(select(1,b.Bars[1]:GetPoint(1)),"TOPRIGHT")
        local snapshot=frame.LiveValues.classPowerSnapshot
        Eq(snapshot.sourceInfo,snapshot.info);Eq(snapshot.info.token,"COMBO_POINTS")
        for i=1,20 do B.Apply(frame)end
        Eq(state.reads,refresh*2);Eq(state.gateReads,gates)
        Eq(frame.LiveValues.classPowerSnapshot,snapshot)
    end
    assert(not legacy:IsShown())
    PowerBarColor=oldColors;restore()
end)
Test("Druid Combo Points use only the provider's Energy and Shred gate",function()
    local frame,_,state,restore=SetupCombo("DRUID")
    for _,spec in ipairs({1,2,3,4})do
        f.Spec(spec);UF:Refresh(frame)
        local a,b=r.Holders(frame);assert(a:IsShown() and b:IsShown())
        Eq(frame.LiveValues.classPowerSnapshot.source,"live")
        Eq(frame.LiveValues.classPowerSnapshot.info.token,"COMBO_POINTS")
        NoTiming(a);NoTiming(b)
    end
    local a,b=r.Holders(frame);local reads=state.reads;local gates=state.gateReads
    for i=1,20 do B.Apply(frame)end
    Eq(state.reads,reads);Eq(state.gateReads,gates)
    state.energy=0;UF:Refresh(frame);assert(not a:IsShown() and not b:IsShown())
    Eq(frame.LiveValues.classPowerSnapshot.source,"unavailable")
    state.energy=3;state.shred=false;UF:Refresh(frame);assert(not a:IsShown() and not b:IsShown())
    state.shred=true;UF:Refresh(frame);assert(a:IsShown() and b:IsShown())
    state.current=0;UF:Refresh(frame);Eq(a.Bars[1]:GetValue(),0)
    state.current=state.max;UF:Refresh(frame);Eq(a.Bars[5]:GetValue(),1)
    f.Class("MAGE");UF:Refresh(frame);assert(not a:IsShown() and not b:IsShown())
    f.Class("ROGUE");state.energy=0;state.shred=false;UF:Refresh(frame)
    assert(a:IsShown() and b:IsShown())
    restore()
end)
Test("Combo Points reject invalid raw values, source identity, context and preview",function()
    local frame,_,state,restore=SetupCombo("ROGUE");UF:Refresh(frame)
    local a,b=r.Holders(frame);local records=f.Copy(frame.config.segmentedBars)
    local secret={};local oldSecret=issecretvalue
    issecretvalue=function(v)return v==secret or (oldSecret and oldSecret(v))end
    for _,value in ipairs({secret,-1,6,1.5,0/0,math.huge})do
        state.current=value;UF:Refresh(frame);assert(not a:IsShown() and not b:IsShown());NoTiming(a)
    end
    state.current=nil;UF:Refresh(frame);assert(not a:IsShown())
    state.current=3
    for _,value in ipairs({secret,0,-1,2.5,7,0/0,math.huge})do
        state.max=value;UF:Refresh(frame);assert(not a:IsShown());NoTiming(a)
    end
    state.max=nil;UF:Refresh(frame);assert(not a:IsShown())
    state.max=5;UF:Refresh(frame);assert(a:IsShown() and b:IsShown())
    local published=frame.LiveValues.classPowerSnapshot;local reads=state.reads
    for _,change in ipairs({
        function(s)s.currentKnown=false end,function(s)s.maxKnown=false end,
        function(s)s.info.currentKnown=false end,function(s)s.info.maxKnown=false end,
        function(s)s.info.rawCurrent=secret end,function(s)s.info.rawMax=secret end,
        function(s)s.info.current=1.5 end,function(s)s.info.max=7 end,
        function(s)s.source="preview";s.sourceInfo=nil end,function(s)s.sourceInfo={}end,
        function(s)s.context.class="PALADIN"end,function(s)s.context.unit="target"end,
        function(s)s.info.token="CHI"end,function(s)s.info.token=secret end,
        function(s)s.info.typeId=12 end,function(s)s.info.typeId=secret end,
        function(s)s.context.config={}end,
    })do
        local snapshot=f.Copy(published);snapshot.context.config=frame.config;snapshot.sourceInfo=snapshot.info
        change(snapshot);frame.LiveValues.classPowerSnapshot=snapshot;B.Apply(frame)
        assert(not a:IsShown() and not b:IsShown());NoTiming(a)
    end
    Eq(state.reads,reads);Equal(frame.config.segmentedBars,records)
    frame.LiveValues.classPowerSnapshot=published;B.Apply(frame);assert(a:IsShown() and b:IsShown())
    local finalReads=state.reads
    frame.config.segmentedBars[1].dataSource={id="auto",scope="player"}
    B.Apply(frame);assert(a:IsShown() and b:IsShown())
    frame.config.segmentedBars[1].dataSource=Combo()
    frame.config.segmentedBars[1].spacing=50
    B.Apply(frame);assert(not a:IsShown() and b:IsShown())
    frame.config.segmentedBars[1].spacing=2
    B.Apply(frame);assert(a:IsShown() and b:IsShown());Eq(state.reads,finalReads)
    issecretvalue=oldSecret;restore()
end)
Test("Automatic shares each numeric live gate, snapshot and widgets without new reads",function()
    for _,case in ipairs({
        {SetupArcane,"arcaneCharges"},{SetupChi,"chi"},
        {function()return SetupCombo("ROGUE")end,"comboPoints"},
        {function()return SetupCombo("DRUID")end,"comboPoints"},
    })do
        local frame,_,state,restore=case[1]();UF:Refresh(frame)
        local a,b=r.Holders(frame);local record=frame.config.segmentedBars[1]
        local snapshot=frame.LiveValues.classPowerSnapshot
        local reads=state.reads;record.dataSource={id="auto",scope="player"}
        Eq(B.ResolveDataSource(record,frame),case[2]);B.Apply(frame)
        assert(a:IsShown() and b:IsShown() and a~=b)
        for cycle=1,50 do
            B.Clear(frame);B.Apply(frame)
            assert(a:IsShown() and b:IsShown() and not a.Bars[1].ReadyHighlight)
        end
        Eq(state.reads,reads);Eq(frame.LiveValues.classPowerSnapshot,snapshot)
        snapshot.sourceInfo={};B.Apply(frame)
        Eq(B.ResolveDataSource(record,frame),nil);assert(not a:IsShown() and not b:IsShown())
        snapshot.sourceInfo=snapshot.info;snapshot.currentKnown=false;B.Apply(frame)
        Eq(B.ResolveDataSource(record,frame),nil);assert(not a:IsShown())
        snapshot.currentKnown=true;B.Apply(frame);assert(a:IsShown() and b:IsShown())
        local info=snapshot.info;local originalCurrent,originalMax=info.current,info.max
        for _,badMax in ipairs({0,7})do
            info.max=badMax;B.Apply(frame)
            Eq(B.ResolveDataSource(record,frame),nil);assert(not a:IsShown())
        end
        info.max=originalMax;info.current=1.5;B.Apply(frame)
        Eq(B.ResolveDataSource(record,frame),nil);assert(not a:IsShown())
        info.current=originalCurrent;snapshot.source="preview";B.Apply(frame)
        Eq(B.ResolveDataSource(record,frame),nil);assert(not a:IsShown())
        snapshot.source="live";B.Apply(frame);assert(a:IsShown() and b:IsShown())
        local token,secret,oldSecret=info.token,{},issecretvalue
        issecretvalue=function(value)return rawequal(value,secret) or (oldSecret and oldSecret(value))end
        info.token=secret;B.Apply(frame)
        Eq(B.ResolveDataSource(record,frame),nil);assert(not a:IsShown())
        info.token=token;issecretvalue=oldSecret;B.Apply(frame);assert(a:IsShown())
        for _,value in ipairs({0,state.max})do
            state.current=value;UF:Refresh(frame);assert(a:IsShown() and b:IsShown())
        end
        restore()
    end
end)
Test("Druid Automatic follows only the existing Energy and Shred provider gate",function()
    local frame,_,state,restore=SetupCombo("DRUID")
    frame.config.segmentedBars[1].dataSource={id="auto",scope="player"}
    UF:Refresh(frame);local a,b=r.Holders(frame);assert(a:IsShown() and b:IsShown())
    state.energy=0;UF:Refresh(frame);assert(not a:IsShown() and not b:IsShown())
    Eq(B.ResolveDataSource(frame.config.segmentedBars[1],frame),nil)
    state.energy=3;state.shred=false;UF:Refresh(frame);assert(not a:IsShown())
    state.shred=true;UF:Refresh(frame);assert(a:IsShown() and b:IsShown())
    restore()
end)
Test("50 Combo Points clear, pool, class, combat and hide cycles retain widgets",function()
    local frame,_,state,restore=SetupCombo("ROGUE");UF:Refresh(frame)
    local a,b=r.Holders(frame);local records=f.Copy(frame.config.segmentedBars)
    local widgets={[a]={table.unpack(a.Bars)},[b]={table.unpack(b.Bars)}}
    local oldCombat=InCombatLockdown
    for cycle=1,50 do
        frame.config.segmentedBars={};B.Apply(frame)
        frame.config.segmentedBars=f.Copy(records)
        InCombatLockdown=function()return cycle%2==0 end
        f.Class("DRUID");state.energy=0;UF:Refresh(frame);a,b=r.Holders(frame)
        assert(not a:IsShown() and not b:IsShown());NoTiming(a)
        state.energy=3;state.shred=true;state.current=cycle%6
        UF:Refresh(frame);assert(a:IsShown() and b:IsShown())
        a:Hide();a:Show();NoTiming(a)
        local snapshot=frame.LiveValues.classPowerSnapshot
        B.Clear(frame);Eq(frame.LiveValues.classPowerSnapshot,snapshot)
        B.Apply(frame);assert(a:IsShown());NoTiming(a)
        f.Class("ROGUE");UF:Refresh(frame);assert(a:IsShown() and b:IsShown())
        for _,holder in ipairs({a,b})do
            for i,bar in ipairs(holder.Bars)do Eq(bar,widgets[holder][i]);assert(not bar.ReadyHighlight)end
        end
    end
    InCombatLockdown=oldCombat;restore()
end)

source=Read("Tests/SegmentedBarContract.lua");stop=assert(source:find('Test("pure validator',1,true))
local t=assert(load(source:sub(1,stop-1)..
    "\nreturn {ns=ns,S=S,T=T,N=N,C=C,Records=Records,Layout=Layout,Target=Target,Generator=Generator,Equal=Equal}","@Sources/Transfer"))()
Test("mixed sources copy/export/import with the same strict validator and no migration",function()
    local records=t.Records();records[2].dataSource=Arcane()
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
Test("Chi uses shared copy and legacy/vNext transfer validation",function()
    local records=t.Records();records[2].dataSource=Chi()
    local db,layout=t.Layout(records);t.ns.db=db;db.global.UserLayouts["layout:chi"]=layout
    t.Equal(t.S.CopyPayload(layout.payload).Units.player.segmentedBars,records)
    local encoded=assert(t.T.Export("layout:chi"));local target=t.Target()
    local ok,id=t.T.Import(encoded);assert(ok,id)
    t.Equal(target.global.UserLayouts[id].payload.Units.player.segmentedBars,records)
    local legacy={transferSchema=1,formatVersion=1,addonVersion="old",name="Chi",
        payload={Units={player={segmentedBars=records,Texts={}}},TextTemplates={}}}
    target=t.Target();ok,id=t.T.Import(assert(t.C.Encode(legacy)),{generator=t.Generator()});assert(ok,id)
    t.Equal(target.global.UserLayouts[id].payload.Units.player.segmentedBars,records)
    records[2].dataSource.scope="target";assert(not t.S.ValidateSegmentedBars(records,"player"))
end)
Test("Combo Points uses shared copy and legacy/vNext transfer validation",function()
    local records=t.Records();records[2].dataSource=Combo()
    local db,layout=t.Layout(records);t.ns.db=db;db.global.UserLayouts["layout:combo"]=layout
    t.Equal(t.S.CopyPayload(layout.payload).Units.player.segmentedBars,records)
    local encoded=assert(t.T.Export("layout:combo"));local target=t.Target()
    local ok,id=t.T.Import(encoded);assert(ok,id)
    t.Equal(target.global.UserLayouts[id].payload.Units.player.segmentedBars,records)
    local legacy={transferSchema=1,formatVersion=1,addonVersion="old",name="Combo",
        payload={Units={player={segmentedBars=records,Texts={}}},TextTemplates={}}}
    target=t.Target();ok,id=t.T.Import(assert(t.C.Encode(legacy)),{generator=t.Generator()});assert(ok,id)
    t.Equal(target.global.UserLayouts[id].payload.Units.player.segmentedBars,records)
    records[2].dataSource.scope="target";assert(not t.S.ValidateSegmentedBars(records,"player"))
end)
print("Segmented Bar Sources: "..count.." groups PASS")
