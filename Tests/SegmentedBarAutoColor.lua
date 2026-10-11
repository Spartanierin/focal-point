-- Auto binds the existing snapshot; presentation never fetches another observation.
local function Read(path)local f=assert(io.open(path));local s=f:read("*a");f:close();return s end
local source=Read("Tests/SegmentedBarSourceInspector.lua")
local stop=assert(source:find("-- UI-created transfer payload",1,true))
local ui=assert(load(source:sub(1,stop-1).."\nreturn {h=h,Scan=Scan}","@AutoColor/Inspector"))()
local h=ui.h;local ns=h.ns;local M=ns.LayoutMutations.SegmentedBars
local count=0
local function Test(name,fn)fn();count=count+1;print("PASS: "..name)end
local function Context()return assert(M.CaptureContext("player"))end
Test("new defaults explicit; old records unchanged; strict style/source mutation and transfer",function()
    local db,u=h.Setup();local id=assert(M.Add(Context()).id)
    local record=u.segmentedBars[1];assert(record.id==id and record.useBlizzardColor==true)
    h.Equal(record.dataSource,{id="auto",scope="player"})
    local old=h.Add();assert(u.segmentedBars[2].useBlizzardColor==nil and u.segmentedBars[2].dataSource.id=="runes")
    local oldRecord=h.Copy(u.segmentedBars[2]);local copied=ns.LayoutService.CopyPayload({Units={player=u}})
    h.Equal(copied.Units.player.segmentedBars[2],oldRecord)
    for _,bad in ipairs({1,"true",{},"false"})do
        local before=h.Copy(db);assert(not M.SetStyle(Context(),id,{useBlizzardColor=bad}).ok);h.Equal(db,before)
    end
    assert(M.SetStyle(Context(),id,{useBlizzardColor=false,color={.1,.2,.3,0}}).ok)
    local stale=Context();assert(M.SetStyle(Context(),id,{useBlizzardColor=true}).ok)
    assert(not M.SetStyle(stale,id,{useBlizzardColor=false}).ok)
    local combat=InCombatLockdown;InCombatLockdown=function()return true end
    assert(not M.SetStyle(Context(),id,{useBlizzardColor=false}).ok);InCombatLockdown=combat
    local duplicate=M.Duplicate(Context(),id);assert(duplicate.ok)
    assert(u.segmentedBars[2].useBlizzardColor and u.segmentedBars[2].dataSource.id=="auto")
    local before=h.Copy(db);assert(M.SetDataSource(Context(),id,{id="auto",scope="target"}).ok==false);h.Equal(db,before)
    local encoded=assert(ns.LayoutTransfer.Export("layout:existing"));local ok,imported=ns.LayoutTransfer.Import(encoded)
    assert(ok,imported);h.Equal(db.global.UserLayouts[imported].payload.Units.player.segmentedBars,u.segmentedBars)
end)
Test("Inspector auto resolution and independent color switch preserve alpha/font with no gameplay reads",function()
    local _,u=h.Setup();h.state.SetSingleSelection("player");h.state.ClearPropertyScope()
    assert(M.Add(Context()).ok);h.Select(h.Nodes()[1])
    assert(loadfile("Engine/UnitFrame/Bars/UnitFrameSegmentedBars.lua"))("FocalPoint",ns)
    local B=ns.UnitFrameSegmentedBars;local applied=0;B.Apply=function()applied=applied+1 end
    local frame={config=u,LiveValues={classPowerSnapshot={
        context={class="DEATHKNIGHT",config=u,unit="player"},
        info={token="RUNES",current=3,max=6,segments={{},{},{},{},{},{}}},source="preview",
        available=true,currentKnown=true,maxKnown=true}}}
    ns.frames={player=frame}
    local power,rune,cl,sp=UnitPower,GetRuneCooldown,UnitClassBase,GetSpecialization
    local function Forbidden()error("Inspector queried gameplay")end
    UnitPower,GetRuneCooldown,UnitClassBase,GetSpecialization=Forbidden,Forbidden,Forbidden,Forbidden
    local _,c,container=h.Build(true)
    assert(c.dataSource:GetValue()=="auto" and c.useBlizzardColor:GetValue()==true and c.color.disabled)
    assert(c.runeTimerFont)
    local _,labels=ui.Scan(container);assert(labels:find("Resolved Source: Runes (Death Knight)",1,true))
    c.useBlizzardColor:Fire("OnValueChanged",false);assert(not c.color.disabled)
    c.color:Fire("OnValueChanged",.2,.4,.6,0);c.runeTimerFontSize:Fire("OnValueChanged",22)
    c.useBlizzardColor:Fire("OnValueChanged",true);assert(c.color.disabled)
    c.color:Fire("OnValueChanged",1,1,1,1);h.Equal(u.segmentedBars[1].color,{.2,.4,.6,0})
    c.dataSource:Fire("OnValueChanged","holyPower");c=ui.Scan(container)
    assert(not c.runeTimerFont and c.useBlizzardColor:GetValue()==true)
    c.dataSource:Fire("OnValueChanged","auto");c=ui.Scan(container);assert(c.runeTimerFontSize:GetValue()==22)
    c.useBlizzardColor:Fire("OnValueChanged",false);assert(c.color.a==0 and c.color.r==.2)
    h.ui.ace:Release(container)
    for _,class in ipairs({"PALADIN","WARRIOR"})do
        frame.LiveValues.classPowerSnapshot.context.class=class
        local text,controls,view=h.Build(true);assert(not controls.runeTimerFont and controls.dataSource:GetValue()=="auto")
        assert(text:find("Unavailable",1,true))
        h.ui.ace:Release(view)
    end
    frame.LiveValues.classPowerSnapshot=nil
    local text,controls,view=h.Build(true);assert(not controls.runeTimerFont and text:find("Unavailable",1,true))
    h.ui.ace:Release(view)
    local otherConfig={};frame.config=otherConfig
    frame.LiveValues.classPowerSnapshot={context={class="DEATHKNIGHT",config=otherConfig,unit="player"}}
    text,controls,view=h.Build(true);assert(not controls.runeTimerFont and text:find("Unavailable",1,true))
    h.ui.ace:Release(view);assert(applied==7)
    UnitPower,GetRuneCooldown,UnitClassBase,GetSpecialization=power,rune,cl,sp;ns.frames=nil
end)

local f=assert(load(Read("Tests/SegmentedBarSources.lua")..
    "\nreturn {r=r,Setup=Setup,NoTiming=NoTiming}","@AutoColor/Runtime"))()
local r=f.r;ns=r.ns;local B,C=r.B,ns.UnitFrameClassPower
local Eq,Equal=r.f.Eq,r.f.Equal
local function Auto(frame,mode)
    for _,record in ipairs(frame.config.segmentedBars)do record.dataSource={id="auto",scope="player"};record.useBlizzardColor=mode end
end
local paletteBody=assert(Read("Libraries/oUF/colors.lua"):match("runes = (%b{})"))
local runePalette=assert(load("return "..paletteBody,"@AutoColor/Palette","t",{oUF={CreateColor=function(_,red,green,blue)
    return {r=red/255,g=green/255,b=blue/255}
end}}))()
Test("four modes, DK specs, shared actual palette and zero additional reads on repeated render",function()
    local oldOUF,oldPower=ns.oUF,PowerBarColor
    ns.oUF={colors={runes=runePalette}};PowerBarColor={RUNES={r=.9,g=.8,b=.7}}
    for spec=1,3 do
        local frame=r.Setup("DEATHKNIGHT");r.f.Spec(spec);r.UF:Refresh(frame)
        local a,b=r.Holders(frame);local snapshot=frame.LiveValues.classPowerSnapshot
        local rune,power,max,cl,sp=GetRuneCooldown,UnitPower,UnitPowerMax,UnitClassBase,GetSpecialization
        local function Forbidden()error("render queried gameplay")end
        GetRuneCooldown,UnitPower,UnitPowerMax,UnitClassBase,GetSpecialization=Forbidden,Forbidden,Forbidden,Forbidden,Forbidden
        for _,sourceId in ipairs({"auto","runes"})do
            for _,mode in ipairs({true,false})do
                for _,alpha in ipairs({0,.4,1})do
                    local record=frame.config.segmentedBars[1];record.dataSource={id=sourceId,scope="player"}
                    record.useBlizzardColor=mode;record.color={.1,.2,.3,alpha}
                    local second=frame.config.segmentedBars[2];second.useBlizzardColor=false;second.color={.7,.6,.5,.2}
                    B.Apply(frame);local p=runePalette[spec]
                    Equal(a.Bars[1].lastSetStatusBarColor,mode and {p.r,p.g,p.b,alpha} or {.1,.2,.3,alpha})
                    Equal(b.Bars[1].lastSetStatusBarColor,{.7,.6,.5,.2})
                    Eq(a.segments,snapshot.info.segments);Eq(frame.LiveValues.classPowerSnapshot,snapshot)
                end
            end
        end
        GetRuneCooldown,UnitPower,UnitPowerMax,UnitClassBase,GetSpecialization=rune,power,max,cl,sp
    end
    ns.oUF,PowerBarColor=oldOUF,oldPower
end)
Test("Holy auto/manual standard/custom token priority; legacy records and palette fallback",function()
    local frame,_,state,restore=f.Setup();r.UF:Refresh(frame);local reads=state.reads
    local a,b=r.Holders(frame);local oldOUF,oldPower=ns.oUF,PowerBarColor
    ns.oUF={colors={}};PowerBarColor={HOLY_POWER={r=.9,g=.7,b=.1},[9]={r=1,g=0,b=0}}
    for _,sourceId in ipairs({"auto","holyPower"})do
        for _,mode in ipairs({true,false})do
            local record=frame.config.segmentedBars[1];record.dataSource={id=sourceId,scope="player"}
            record.useBlizzardColor=mode;record.color={.1,.2,.3,0};B.Apply(frame)
            Equal(a.Bars[1].lastSetStatusBarColor,mode and {.9,.7,.1,0} or {.1,.2,.3,0})
        end
    end
    local record=frame.config.segmentedBars[1];record.useBlizzardColor=nil;B.Apply(frame)
    Equal(a.Bars[1].lastSetStatusBarColor,{.1,.2,.3,0})
    record.color=nil;B.Apply(frame);Equal(a.Bars[1].lastSetStatusBarColor,{1,1,1,1})
    record.useBlizzardColor=true;PowerBarColor=nil;B.Apply(frame);Equal(a.Bars[1].lastSetStatusBarColor,{1,1,1,1})
    record.color={.1,.2,.3,0};B.Apply(frame);Equal(a.Bars[1].lastSetStatusBarColor,{.1,.2,.3,0})
    Eq(state.reads,reads);f.NoTiming(a);ns.oUF,PowerBarColor=oldOUF,oldPower;restore()
end)
Test("shared resolver remains pure while Legacy alone retains aura-variant selection",function()
    local frame=r.Setup("DEATHKNIGHT")
    local oldPower,oldAura=PowerBarColor,C_UnitAuras
    PowerBarColor={SOUL_FRAGMENTS={{r=.2,g=.4,b=.6},{r=.8,g=.6,b=.4}}}
    local active,reads=false,0
    C_UnitAuras={GetPlayerAuraBySpellID=function()reads=reads+1;return active and {applications=1} or nil end}
    local red,green,blue=C.ResolveResourceColor({token="SOUL_FRAGMENTS"},nil,.1,.2,.3)
    Equal({red,green,blue},{.1,.2,.3});Eq(reads,0)
    local options={classPowerBarVisible=true,liveClassPowerMax=1,liveClassPowerCurrent=1,
        liveClassPowerToken="SOUL_FRAGMENTS",classPowerR=.1,classPowerG=.2,classPowerB=.3,classPowerA=0}
    C.ApplyLayout(frame,options);Equal(frame.Elements.ClassPowerBar.Bars[1].lastSetStatusBarColor,{.2,.4,.6,0});Eq(reads,1)
    active=true;C.ApplyLayout(frame,options);Equal(frame.Elements.ClassPowerBar.Bars[1].lastSetStatusBarColor,{.8,.6,.4,0});Eq(reads,2)
    options.useBlizzardColorClassPower=false;C.ApplyLayout(frame,options)
    Equal(frame.Elements.ClassPowerBar.Bars[1].lastSetStatusBarColor,{.1,.2,.3,0});Eq(reads,2)
    PowerBarColor,C_UnitAuras=oldPower,oldAura
end)
Test("unsupported/secret context and synthetic tokens cannot manufacture an auto resource",function()
    local frame=r.Setup("DEATHKNIGHT");Auto(frame,true);r.UF:Refresh(frame);local a,b=r.Holders(frame)
    local snapshot=frame.LiveValues.classPowerSnapshot;local context=snapshot.context
    for _,class in ipairs({"WARRIOR","PALADIN",false})do
        context.class=class;B.Apply(frame);assert(not a:IsShown() and not b:IsShown());f.NoTiming(a)
    end
    local secret=setmetatable({}, {__eq=function()error("secret compare")end,__tostring=function()error("secret format")end})
    local oldSecret=issecretvalue;issecretvalue=function(v)return rawequal(v,secret)end
    context.class=secret;B.Apply(frame);assert(not a:IsShown())
    context.class="DEATHKNIGHT";context.spec=secret;B.Apply(frame);assert(a:IsShown())
    issecretvalue=oldSecret;context.spec=1
    snapshot.source="preview";snapshot.sourceInfo=nil;context.class="PALADIN"
    B.Apply(frame);assert(not a:IsShown());Eq(B.ResolveDataSource(frame.config.segmentedBars[1],frame),nil)
    context.class="DEATHKNIGHT";B.Apply(frame);assert(a:IsShown())
    snapshot.currentKnown=false;B.Apply(frame);assert(not a:IsShown());f.NoTiming(a)
    snapshot.currentKnown=true;snapshot.source="unavailable";B.Apply(frame);assert(not a:IsShown())
    snapshot.source="live";B.Apply(frame);assert(not a:IsShown())
    snapshot.sourceInfo=snapshot.info;context.config={};B.Apply(frame);assert(not a:IsShown())
    for _,record in ipairs(frame.config.segmentedBars)do Eq(record.dataSource.id,"auto") end
end)
Test("50 auto class/spec/layout/reuse cycles clear timing, preserve bindings and never add flashes",function()
    local frame=r.Setup("DEATHKNIGHT");Auto(frame,true);r.UF:Refresh(frame)
    local a,b=r.Holders(frame);local widgets={a.Bars[1],b.Bars[1]};local initial=r.f.Copy(frame.config.segmentedBars)
    local power,max=UnitPower,UnitPowerMax
    UnitPower=function(unit,id)if id==9 then return 2 end;return power(unit,id)end
    UnitPowerMax=function(unit,id)if id==9 then return 5 end;return max(unit,id)end
    for cycle=1,50 do
        r.f.Class("PALADIN");r.UF:Refresh(frame);assert(a:IsShown());f.NoTiming(a);f.NoTiming(b)
        r.f.Class("DEATHKNIGHT");r.f.Spec(cycle%3+1);r.UF:Refresh(frame)
        assert(a:IsShown() and a:GetScript("OnUpdate"));Eq(a.segments,frame.LiveValues.classPowerSnapshot.info.segments)
        for _,holder in ipairs({a,b})do for _,bar in ipairs(holder.Bars)do assert(not bar.ReadyHighlight)end end
        B.Clear(frame);f.NoTiming(a);B.Apply(frame);assert(a:GetScript("OnUpdate"))
        frame.config.segmentedBars={};B.Apply(frame);frame.config.segmentedBars=r.f.Copy(initial);B.Apply(frame)
        a,b=r.Holders(frame);assert(a.Bars[1]==widgets[1] or a.Bars[1]==widgets[2])
        Equal(frame.config.segmentedBars,initial)
    end
    UnitPower,UnitPowerMax=power,max
end)
print("Segmented Bar Auto Color: "..count.." groups PASS")
