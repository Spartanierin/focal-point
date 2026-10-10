-- lua54 Tests/ClassPowerSnapshot.lua
-- Actual full/direct/scoped refresh, Power refresh, ApplyConfig and ApplyTestValues.
-- Native WoW event/render behavior remains an ingame smoke obligation.
local function Read(path)local f=assert(io.open(path));local s=f:read("*a");f:close();return s end
local h=assert(load(Read("Tests/ClassPowerPreview.lua")..[[
return {ns=ns,C=C,UF=UF,Eq=Eq,Setup=Setup,Select=Select,Refresh=Refresh,fixture=h}
]],"@ClassPowerSnapshot/Fixture"))()
local ns,C,UF,Eq=h.ns,h.C,h.UF,h.Eq
local count=0
local function Test(name,fn)fn();count=count+1;print("PASS: "..name)end
local reads,powerReads,runeReads=0,0,0
local getInfo,refreshPower=C.GetInfo,ns.UnitFramePower.RefreshUnitBarValues
C.GetInfo=function(...)reads=reads+1;return getInfo(...)end
ns.UnitFramePower.RefreshUnitBarValues=function(...)powerReads=powerReads+1;return refreshPower(...)end
local function Setup()
    local frame,holder=h.Setup("DEATHKNIGHT")
    local api=GetRuneCooldown
    GetRuneCooldown=function(...)runeReads=runeReads+1;return api(...)end
    reads,powerReads,runeReads=0,0,0
    return frame,holder
end
Test("full direct refresh reads once; both consumers share snapshot; Power still refreshes twice",function()
    local frame=Setup();local original=C.GetSnapshotInfo;local seen={}
    C.GetSnapshotInfo=function(...)local info=original(...);seen[#seen+1]=info;return info end
    UF:Refresh(frame)
    Eq(reads,1);Eq(runeReads,6);Eq(powerReads,2);Eq(#seen,2);Eq(seen[1],seen[2])
    local first=frame.LiveValues.classPowerSnapshot;Eq(first.info,seen[1]);Eq(first.sourceInfo,first.info)
    Eq(first.source,"live");assert(first.available and first.currentKnown and first.maxKnown)
    local api=GetRuneCooldown
    GetRuneCooldown=function(index)if index==2 then runeReads=runeReads+1;return 0,0,true end;return api(index)end
    UF:Refresh(frame)
    Eq(reads,2);Eq(runeReads,12);Eq(powerReads,4)
    local second=frame.LiveValues.classPowerSnapshot
    assert(first~=second and first.info~=second.info);Eq(second.info.current,first.info.current+1)
    Eq(seen[3],seen[4]);Eq(second.info,seen[3]);Eq(first.info.segments[2].ready,false)
    C.GetSnapshotInfo=original
end)
Test("first ApplyConfig initializes once; ApplyTestValues and repeated layout apply only consume",function()
    local frame=Setup()
    UF:ApplyConfig(frame);Eq(reads,1);Eq(runeReads,6)
    local snapshot=frame.LiveValues.classPowerSnapshot
    UF:ApplyTestValues(frame);UF:ApplyConfig(frame);Eq(reads,1);Eq(powerReads,1)
    Eq(snapshot,frame.LiveValues.classPowerSnapshot)
    -- The subsequent Build refresh is its own responsible cycle, not a stale cache hit.
    UF:Refresh(frame);Eq(reads,2);Eq(runeReads,12)
    UF:Refresh(frame,{scopes={layout=true},reason="layout-only"});Eq(reads,2)
end)
Test("real queue bundles events once; final rune anchor precedes one Ready play",function()
    for _,growth in ipairs({"LEFT_TO_RIGHT","RIGHT_TO_LEFT"})do
        local frame,holder=Setup();frame.config.classPowerBarGrowth=growth
        UF:Refresh(frame);UF:Refresh(frame)
        C.RegisterEvents(UF,frame)
        local oldTimer=C_Timer;local pending={}
        C_Timer={After=function(_,fn)pending[#pending+1]=fn end}
        local api=GetRuneCooldown
        GetRuneCooldown=function(index)if index==3 then runeReads=runeReads+1;return 0,0,true end;return api(index)end
        -- Capability function changed only in the double: publish baseline before the event.
        local readsBefore=reads;local apiBefore=runeReads
        frame.ClassPowerEventFrame:Run("OnEvent","RUNE_POWER_UPDATE")
        frame.ClassPowerEventFrame:Run("OnEvent","UNIT_AURA","player")
        Eq(#pending,1);pending[1]();Eq(reads,readsBefore+1);Eq(runeReads,apiBefore+12)
        assert(holder.segments[3].ready);Eq(holder.Bars[3].Countdown:GetText(),"")
        Eq(h.fixture.Plays(holder,3),1)
        UF:ApplyTestValues(frame);UF:ApplyConfig(frame)
        Eq(reads,readsBefore+1);Eq(h.fixture.Plays(holder,3),1)
        Eq(runeReads,apiBefore+12) -- no retry or second confirmation on repeated presentation
        C_Timer=oldTimer
    end
end)
Test("full and queued refresh reject S1 ready-3 to S2 spent-3/ready-2 without republishing",function()
    for _,growth in ipairs({"LEFT_TO_RIGHT","RIGHT_TO_LEFT"})do
        for _,queued in ipairs({false,true})do
            local frame,holder=Setup();frame.config.classPowerBarGrowth=growth
            local api=GetRuneCooldown;local stage=0
            GetRuneCooldown=function(index)
                if stage>0 and index==3 then
                    runeReads=runeReads+1
                    if stage==1 then return 0,0,true end
                    return nil,nil,false
                end
                if stage==2 and index==2 then runeReads=runeReads+1;return 0,0,true end
                return api(index)
            end
            UF:Refresh(frame);UF:Refresh(frame);C.RegisterEvents(UF,frame)
            local apply,queue,timer=UF.ApplyConfig,ns.UnitFrameState.QueueRefresh,C_Timer
            local callbacks={};C_Timer={After=function(_,fn)callbacks[#callbacks+1]=fn end}
            if not queued then ns.UnitFrameState.QueueRefresh=function()end end
            local published
            UF.ApplyConfig=function(self,owner,...)
                assert(holder._readyTransitions.pendingReady[3])
                published=owner.LiveValues.classPowerSnapshot
                stage=2 -- source changes after qualification, before the actual renderer
                return apply(self,owner,...)
            end
            local beforeReads,beforeRunes=reads,runeReads
            stage=1;frame.ClassPowerEventFrame:Run("OnEvent","RUNE_POWER_UPDATE")
            if queued then Eq(#callbacks,1);callbacks[1]()else UF:Refresh(frame)end
            Eq(reads,beforeReads+1);Eq(runeReads,beforeRunes+12)
            Eq(frame.LiveValues.classPowerSnapshot,published);assert(published.info.segments[3].ready)
            assert(not holder._readyTransitions)
            for i=1,6 do Eq(h.fixture.Plays(holder,i),0)end
            UF.ApplyConfig=apply
            -- A normal refresh seeds the actual current baseline; no stale intent survives.
            UF:Refresh(frame);assert(not holder.segments[3].ready and holder.segments[2].ready)
            for i=1,6 do Eq(h.fixture.Plays(holder,i),0)end
            ns.UnitFrameState.QueueRefresh=queue;C_Timer=timer
        end
    end
end)
Test("spec/root changes invalidate layout-only context; no first-bind flash",function()
    local frame,holder=Setup();UF:Refresh(frame)
    h.fixture.Spec(2);UF:ApplyConfig(frame);Eq(reads,2)
    ns.ActiveLayoutResolver.InvalidateActiveRuntimeRoot();assert(ns.ActiveLayoutResolver.EnsureActiveRuntimeRoot(ns.db))
    UF:ApplyConfig(frame);Eq(reads,3)
    for i=1,6 do Eq(h.fixture.Plays(holder,i),0)end
end)
Test("selection and detailed preview never publish synthetic gameplay values",function()
    local frame=Setup();UF:Refresh(frame);local live=frame.LiveValues.classPowerSnapshot.info
    ns.framesUnlocked=true;h.Select("ClassPowerBar");local before=runeReads
    UF:ApplyConfig(frame);Eq(reads,2);Eq(runeReads,before)
    local preview=frame.LiveValues.classPowerSnapshot
    Eq(preview.source,"preview");assert(preview.info.segments and not preview.sourceInfo)
    Eq(live.segments[2].ready,false);Eq(live.segments[2].startTime,95)
    UF:ApplyTestValues(frame);UF:ApplyConfig(frame);Eq(reads,2)
    h.Select(nil);ns.framesUnlocked=false;UF:ApplyConfig(frame)
    Eq(reads,3);Eq(runeReads,before+6);Eq(frame.LiveValues.classPowerSnapshot.source,"live")
end)
Test("unavailable observations do not retry in consumers or claim known zero",function()
    local frame=Setup();GetRuneCooldown=function()runeReads=runeReads+1;return nil,nil,nil end
    UF:Refresh(frame);Eq(reads,1);Eq(runeReads,1)
    local snapshot=frame.LiveValues.classPowerSnapshot
    assert(not snapshot.available and not snapshot.currentKnown and not snapshot.maxKnown)
    Eq(snapshot.source,"unavailable");assert(not snapshot.info and not snapshot.sourceInfo)
    Eq(frame.LiveValues.classPowerVisible,false);Eq(frame.LiveValues.classPowerCurrentSafe,0)
    UF:ApplyConfig(frame);UF:ApplyTestValues(frame);Eq(reads,1);Eq(runeReads,1)
end)
Test("secret/unknown numeric current differs from actual zero, legacy projection retained",function()
    local frame=h.Setup("ROGUE");local power,max,secretFn=UnitPower,UnitPowerMax,issecretvalue
    local secret={};issecretvalue=function(value)return value==secret end
    local current=secret;UnitPower=function()return current end;UnitPowerMax=function()return 5 end
    C.RefreshValues(UF,frame)
    local snapshot=frame.LiveValues.classPowerSnapshot
    assert(snapshot.available and not snapshot.currentKnown and snapshot.maxKnown)
    Eq(snapshot.sourceInfo.rawCurrent,secret);Eq(frame.LiveValues.classPowerCurrentSafe,0)
    current=0;C.RefreshValues(UF,frame);assert(frame.LiveValues.classPowerSnapshot.currentKnown)
    Eq(frame.LiveValues.classPowerSnapshot.sourceInfo.rawCurrent,0)
    current=nil;C.RefreshValues(UF,frame);assert(not frame.LiveValues.classPowerSnapshot.currentKnown)
    UnitPower,UnitPowerMax,issecretvalue=power,max,secretFn
end)
Test("50 clear/hide/layout cycles keep one read per full refresh and none per countdown tick",function()
    local frame,holder=Setup()
    for cycle=1,50 do
        frame.config.classPowerBarGrowth=cycle%2==0 and "RIGHT_TO_LEFT" or "LEFT_TO_RIGHT"
        frame.config.classPowerColor={.2,.3,.4,0}
        UF:Refresh(frame);Eq(reads,cycle);Eq(runeReads,cycle*6)
        UF:ApplyConfig(frame);UF:ApplyTestValues(frame);Eq(reads,cycle)
        local tick=holder:GetScript("OnUpdate");if tick then tick(holder)end;Eq(runeReads,cycle*6)
        holder:Hide();holder:Show();C.Clear(frame);assert(not frame.LiveValues.classPowerSnapshot)
    end
end)
Test("full detailed/placeholder refresh uses one observation and subsequent consumers reuse it",function()
    for _,class in ipairs({"DEATHKNIGHT","WARRIOR"})do
        local frame=h.Setup(class);reads=0
        ns.guiTestModeEnabled=true;ns.framesUnlocked=true
        UF:Refresh(frame);Eq(reads,1)
        Eq(frame.LiveValues.classPowerSnapshot.source,"preview")
        assert(not frame.LiveValues.classPowerSnapshot.sourceInfo)
        UF:ApplyConfig(frame);UF:ApplyTestValues(frame);Eq(reads,1)
        UF:Refresh(frame);Eq(reads,2)
        ns.guiTestModeEnabled=false;frame.config.enabled=false
        UF:Refresh(frame);Eq(reads,3)
        UF:ApplyConfig(frame);UF:ApplyTestValues(frame);Eq(reads,3)
    end
end)
Test("derived aura/shard display fallbacks retain unknown versus known-zero validity",function()
    local oldAuras,oldSpells,oldPower,oldMax,oldMod,oldSecret=C_UnitAuras,C_SpellBook,UnitPower,UnitPowerMax,UnitPowerDisplayMod,issecretvalue
    local secret={};issecretvalue=function(value)return value==secret end
    local frame=h.Setup("SHAMAN");h.fixture.Spec(2)
    C_SpellBook={IsSpellKnown=function()return true end}
    C_UnitAuras={GetPlayerAuraBySpellID=function()return {applications=secret}end}
    C.RefreshValues(UF,frame);assert(not frame.LiveValues.classPowerSnapshot.currentKnown)
    C_UnitAuras.GetPlayerAuraBySpellID=function()return nil end
    C.RefreshValues(UF,frame);assert(frame.LiveValues.classPowerSnapshot.currentKnown)
    Eq(frame.LiveValues.classPowerSnapshot.info.current,0)
    C_UnitAuras=nil;C.RefreshValues(UF,frame);assert(not frame.LiveValues.classPowerSnapshot.currentKnown)
    frame=h.Setup("WARLOCK");h.fixture.Spec(3)
    UnitPower=function()return secret end;UnitPowerMax=function()return 5 end;UnitPowerDisplayMod=function()return 10 end
    C.RefreshValues(UF,frame);assert(not frame.LiveValues.classPowerSnapshot.currentKnown)
    UnitPower=function()return 0 end;C.RefreshValues(UF,frame);assert(frame.LiveValues.classPowerSnapshot.currentKnown)
    C_UnitAuras,C_SpellBook,UnitPower,UnitPowerMax,UnitPowerDisplayMod,issecretvalue=oldAuras,oldSpells,oldPower,oldMax,oldMod,oldSecret
end)
C.GetInfo=getInfo;ns.UnitFramePower.RefreshUnitBarValues=refreshPower
print("Class Power Snapshot: "..count.." groups PASS")
