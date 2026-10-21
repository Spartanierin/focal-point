-- lua54 Tests/PowerFrequent.lua
-- Real event handler, queue/commit, refresh, LiveValues, text tags and Class Power.
-- Native widgets/APIs are doubles; event cadence and Midnight taint need ingame QA.
local function Read(path)local f=assert(io.open(path));local s=f:read("*a");f:close();return s end
local source=Read("Tests/ClassPowerPreview.lua")
local boundary=assert(source:find('local count=0',1,true))
local h=assert(load(source:sub(1,boundary-1)..[[
return {ns=ns,UF=UF,Setup=Setup,fixture=h,Select=Select}
]],"@PowerFrequent/Fixture"))()
local ns,UF,fixture=h.ns,h.UF,h.fixture
fixture.Load("Engine/UnitFrame/Shared/EditorVisualPolicy.lua")
fixture.Load("Engine/UnitFrame/Runtime/UnitFrameRuntimeActivity.lua")
UnitExists=function()return true end
fixture.Load("Engine/UnitFrame/Bars/UnitFramePower.lua")
fixture.Load("Engine/TextElements.lua") -- Restore the real text methods omitted by the preview fixture.
local Eq=fixture.Eq
local count=0
local function Test(name,fn)fn();count=count+1;print("PASS: "..name)end
local current,maximum,powerType,combo,pending,reads
local function Flush()
    local callbacks=pending;pending={}
    for _,callback in ipairs(callbacks)do callback()end
end
local function EnsureTestUnit(unit,frameConfig)
    local layout=ns.db.global.UserLayouts["layout:runes"]
    local defaultUnit=ns:GetDefaultDB().profile.Units[unit]
    assert(type(defaultUnit)=="table",unit.." default Unit config missing")
    layout.payload.Units[unit]=ns.LayoutService.Clone(defaultUnit)
    layout.payload.Units[unit].present=true
    layout.payload.Units[unit].enabled=true
    layout.payload.Units[unit].Texts=ns.LayoutService.Clone(frameConfig.Texts)
    ns.ActiveLayoutResolver.InvalidateActiveRuntimeRoot()
    assert(ns.ActiveLayoutResolver.EnsureActiveRuntimeRoot(ns.db))
end
local function Setup(class,unit)
    local frame,holder=h.Setup(class or "ROGUE")
    current,maximum,powerType,combo=20,100,3,2
    reads={power=0,max=0,class=0}
    UnitPower=function(_,kind)
        if kind==4 then reads.class=reads.class+1;return combo end
        reads.power=reads.power+1;return current
    end
    UnitPowerMax=function(_,kind)if kind==4 then return 5 end;reads.max=reads.max+1;return maximum end
    UnitPowerType=function()return powerType end
    UnitPowerPercent=function()return current/maximum*100 end
    UnitHealthPercent=function()return 100 end
    frame.config.Texts={Cur={enabled=true,tag="[power:cur]"},Smart={enabled=true,tag="[power:smart]"},
        Health={enabled=true,tag="[health:cur]"}}
    frame.Texts={}
    for key in pairs(frame.config.Texts)do frame.Texts[key]=frame:CreateFontString()end
    UF:Refresh(frame);UF:Refresh(frame)
    frame._fpUnit=unit or frame._fpUnit
    if unit and unit~="player" then
        EnsureTestUnit(unit,frame.config)
    end
    ns.UnitFramePower.RegisterAlternativeEvents(UF,frame)
    if frame._fpUnit=="player" then ns.UnitFrameClassPower.RegisterEvents(UF,frame)end
    pending={};C_Timer={After=function(delay,fn)Eq(delay,0);pending[#pending+1]=fn end}
    return frame,holder
end
local function Frequent(frame,unit)
    local event=frame.AlternativePowerEventFrame
    assert(event.registeredEvents.UNIT_POWER_FREQUENT,"Power handler must register UNIT_POWER_FREQUENT")
    event:Run("OnEvent","UNIT_POWER_FREQUENT",unit or frame._fpUnit,"ENERGY")
end
Test("Frequent-only commit updates Energy bar and real current/smart tags without Class Power",function()
    local frame=Setup()
    local snapshot=frame.LiveValues.classPowerSnapshot
    local before=reads.class
    current=37;Frequent(frame);Eq(#pending,1)
    Eq(frame.PowerBar:GetValue(),20)
    Flush()
    Eq(frame.PowerBar:GetValue(),37);Eq(frame.Texts.Cur:GetText(),"37");Eq(frame.Texts.Smart:GetText(),"37")
    Eq(frame.LiveValues.classPowerSnapshot,snapshot);Eq(reads.class,before)
end)
Test("Frequent before Combo Points update preserves exactly one qualified gain highlight",function()
    local frame,holder=Setup()
    local snapshot=frame.LiveValues.classPowerSnapshot
    combo=3;current=42;Frequent(frame);Flush()
    Eq(frame.LiveValues.classPowerSnapshot,snapshot);Eq(fixture.Plays(holder,3),0)
    frame.ClassPowerEventFrame:Run("OnEvent","UNIT_POWER_UPDATE","player","COMBO_POINTS");Flush()
    Eq(fixture.Plays(holder,3),1);Eq(#frame.LiveValues.classPowerSnapshot.readyTransitions,1)
    Frequent(frame);Flush();Eq(fixture.Plays(holder,3),1)
end)
Test("multiple Frequent events coalesce; no health/alternative/layout/segment work or bar readback",function()
    local frame=Setup()
    local snapshot=frame.LiveValues.classPowerSnapshot
    local powerBefore,maxBefore=reads.power,reads.max
    local layout,health=UF.ApplyConfig,UF.RefreshHealthBar
    local function Forbidden()error("Frequent crossed primary-power scope")end
    UF.ApplyConfig,UF.RefreshHealthBar=Forbidden,Forbidden
    frame.PowerBar.GetValue,frame.PowerBar.GetMinMaxValues=Forbidden,Forbidden
    frame.Elements.AlternativePowerBar={SetValue=Forbidden,SetMinMaxValues=Forbidden}
    local healthText=frame.Texts.Health:GetText()
    frame.Texts.Health.SetText=Forbidden
    for i=1,12 do current=40+i;Frequent(frame)end
    Eq(#pending,1);Flush()
    Eq(reads.power,powerBefore+1);Eq(reads.max,maxBefore+1)
    Eq(frame.PowerBar.value,52);Eq(frame.Texts.Cur:GetText(),"52");Eq(frame.Texts.Smart:GetText(),"52")
    Eq(frame.Texts.Health:GetText(),healthText);Eq(frame.LiveValues.classPowerSnapshot,snapshot)
    UF.ApplyConfig,UF.RefreshHealthBar=layout,health
end)
Test("broad plus Frequent commits once in either order and keeps Combo-Point gain",function()
    for _,frequentFirst in ipairs({true,false})do
        local frame,holder=Setup()
        local apply=ns.UnitFramePower.RefreshUnitBarValues
        local broad,narrow=0,0
        ns.UnitFramePower.RefreshUnitBarValues=function(owner,f,primaryOnly)
            if primaryOnly then narrow=narrow+1 else broad=broad+1 end
            return apply(owner,f,primaryOnly)
        end
        combo=3;current=63
        if frequentFirst then Frequent(frame)end
        frame.ClassPowerEventFrame:Run("OnEvent","UNIT_POWER_UPDATE","player","COMBO_POINTS")
        if not frequentFirst then Frequent(frame)end
        Eq(#pending,1);Flush();Eq(broad,1);Eq(narrow,0)
        Eq(frame.Texts.Smart:GetText(),"63");Eq(fixture.Plays(holder,3),1)
        ns.UnitFramePower.RefreshUnitBarValues=apply
    end
end)
Test("bars-only coalescing wins; unrelated text dependencies still include power",function()
    local frame=Setup();local state=ns.UnitFrameState
    local apply=ns.UnitFramePower.RefreshUnitBarValues;local applications=0
    ns.UnitFramePower.RefreshUnitBarValues=function(...)applications=applications+1;return apply(...)end
    current=47;Frequent(frame);state.QueueRefresh(frame,"bar-test","bars");Flush()
    Eq(applications,1);Eq(frame.Texts.Cur:GetText(),"47")
    current=48;Frequent(frame)
    state.QueueRefresh(frame,"health-text","texts",{textDependencies={health=true}});Flush()
    Eq(applications,2);Eq(frame.Texts.Cur:GetText(),"48");Eq(frame.Texts.Smart:GetText(),"48")
    ns.UnitFramePower.RefreshUnitBarValues=apply
end)
Test("disabled or absent primary bar does not disable Power text",function()
    for _,absent in ipairs({false,true})do
        local frame=Setup();frame.config.showPowerBar=false
        if absent then frame.Elements.PowerBar=nil end
        -- ClearComponentVisual may reset the hidden bar; text still needs live data.
        current=59;Frequent(frame);Flush()
        Eq(frame.Texts.Cur:GetText(),"59");Eq(frame.Texts.Smart:GetText(),"59")
    end
end)
Test("all five unit tokens refresh their primary bar and text; foreign tokens are ignored",function()
    for _,unit in ipairs({"player","target","targettarget","focus","focustarget"})do
        local frame=Setup("ROGUE",unit);local event=frame.AlternativePowerEventFrame
        Eq(event.eventUnits.UNIT_POWER_FREQUENT,unit)
        Eq(event.eventUnits.UNIT_POWER_UPDATE,unit)
        Eq(event.eventUnits.UNIT_MAXPOWER,unit)
        Eq(event.eventUnits.UNIT_DISPLAYPOWER,unit)
        if unit=="player" then
            assert(event.registeredEvents.UNIT_POWER_BAR_SHOW and event.registeredEvents.UNIT_POWER_BAR_HIDE)
            assert(frame.ClassPowerEventFrame and not frame.ClassPowerEventFrame.registeredEvents.UNIT_POWER_FREQUENT)
        else
            assert(not event.registeredEvents.UNIT_POWER_BAR_SHOW and not event.registeredEvents.UNIT_POWER_BAR_HIDE)
            assert(not frame.ClassPowerEventFrame)
        end
        UF:RegisterTextEvents(frame)
        assert(not frame.TextEventFrame.registeredEvents.UNIT_POWER_FREQUENT)
        local foreign=unit=="player" and "target" or "player"
        local before=frame.PowerBar.value
        Frequent(frame,foreign);Eq(#pending,0);Eq(frame.PowerBar.value,before)
        for _,name in ipairs({"UNIT_POWER_UPDATE","UNIT_MAXPOWER","UNIT_DISPLAYPOWER"})do
            event:Run("OnEvent",name,foreign);Eq(#pending,0)
        end
        Frequent(frame,unit);Eq(#pending,1);Flush()
        Eq(frame.Texts.Cur:GetText(),"20");Eq(frame.Texts.Smart:GetText(),"20")

        local broad,narrow=0,0
        local apply=ns.UnitFramePower.RefreshUnitBarValues
        ns.UnitFramePower.RefreshUnitBarValues=function(owner,f,primaryOnly)
            if primaryOnly then narrow=narrow+1 else broad=broad+1 end
            return apply(owner,f,primaryOnly)
        end
        for index,name in ipairs({"UNIT_POWER_UPDATE","UNIT_MAXPOWER","UNIT_DISPLAYPOWER"})do
            event:Run("OnEvent",name,foreign);Eq(#pending,0)
            current=30+index;event:Run("OnEvent",name,unit)
            assert(#pending==1,unit.." "..name.." was not queued: "..#pending)
            local dirty=ns.UnitFrameState.Ensure(frame).dirty
            assert(dirty.bars and dirty.texts and dirty.layout and not dirty.power,
                unit.." "..name.." did not request the broad Power refresh")
            Flush()
            assert(broad==index,unit.." "..name.." missed broad refresh: "..broad)
            assert(narrow==0,unit.." "..name.." entered narrow refresh: "..narrow)
            Eq(frame.PowerBar.value,30+index);Eq(frame.Texts.Cur:GetText(),tostring(30+index))
        end
        ns.UnitFramePower.RefreshUnitBarValues=apply
    end
end)
Test("token-bound event registration survives clear and deactivate/pool/reactivate",function()
    local frame=Setup("ROGUE","target");local event=frame.AlternativePowerEventFrame
    Eq(event.owner,frame);Eq(event.eventUnits.UNIT_POWER_FREQUENT,"target")
    local oldFrames,oldPool=ns.frames,ns.framePool
    ns.frames={target=frame};ns.framePool={}
    Eq(ns:DeactivateUnitFrame("target",true),frame)
    Eq(ns.framePool.target,frame);Eq(ns.frames.target,nil)
    current=44;Frequent(frame,"target");Flush()
    Eq(frame.PowerBar.value,44);Eq(frame.Texts.Cur:GetText(),"44")
    Eq(frame.AlternativePowerEventFrame,event);Eq(event.owner._fpUnit,"target")
    Eq(ns:SpawnUnitFrame("target"),frame)
    Eq(ns.frames.target,frame);Eq(ns.framePool.target,nil)
    Eq(frame.AlternativePowerEventFrame,event);Eq(event.eventUnits.UNIT_POWER_FREQUENT,"target")
    ns.frames,ns.framePool=oldFrames,oldPool
end)
Test("player regular Power events keep broad scopes; missing/foreign payloads are ignored",function()
    local frame=Setup();local event=frame.AlternativePowerEventFrame
    assert(not frame.ClassPowerEventFrame.registeredEvents.UNIT_POWER_FREQUENT)
    for _,name in ipairs({"UNIT_POWER_UPDATE","UNIT_MAXPOWER","UNIT_DISPLAYPOWER"})do
        assert(event.registeredEvents[name]);event:Run("OnEvent",name,"player")
        local dirty=ns.UnitFrameState.Ensure(frame).dirty
        assert(dirty.bars and dirty.texts and dirty.layout and not dirty.power)
        Flush()
    end
    event:Run("OnEvent","UNIT_POWER_FREQUENT");Eq(#pending,0)
    event:Run("OnEvent","UNIT_POWER_FREQUENT","target");Eq(#pending,0)
    local other={_fpUnit="pet"};ns.UnitFramePower.RegisterAlternativeEvents(UF,other)
    assert(not other.AlternativePowerEventFrame)
end)
Test("secret unit event payload is rejected without comparison or refresh",function()
    local frame=Setup("ROGUE","target");local event=frame.AlternativePowerEventFrame
    local isSecret=issecretvalue
    issecretvalue=function(value)return rawequal(value,"secret-unit-token")end
    event:Run("OnEvent","UNIT_POWER_FREQUENT","secret-unit-token","ENERGY")
    event:Run("OnEvent","UNIT_POWER_UPDATE","secret-unit-token","ENERGY")
    Eq(#pending,0)
    issecretvalue=isSecret
end)
Test("Energy/Rage/Mana and max changes, true zero/full, 20 form cycles",function()
    local frame=Setup("DRUID")
    for _=1,20 do
        for _,case in ipairs({{3,0,100,"0"},{3,100,100,"100"},{1,45,100,"45"},{0,80,200,"40%"}})do
            powerType,current,maximum=case[1],case[2],case[3]
            frame.AlternativePowerEventFrame:Run("OnEvent","UNIT_DISPLAYPOWER","player");Flush()
            Frequent(frame);Flush()
            Eq(frame.PowerBar.value,current);Eq(frame.LiveValues.powerMaxRaw,maximum)
            Eq(frame.Texts.Smart:GetText(),case[4])
        end
    end
end)
Test("demo ignores native Frequent values; live reentry resumes without Class-Power consumption",function()
    local frame=Setup("DRUID")
    ns:ToggleTestMode()
    local value,snapshot=frame.PowerBar.value,frame.LiveValues.classPowerSnapshot
    local before=reads.power
    current=93;Frequent(frame);Flush()
    Eq(frame.PowerBar.value,value);Eq(frame.LiveValues.classPowerSnapshot,snapshot);Eq(reads.power,before)
    ns:ToggleTestMode();snapshot=frame.LiveValues.classPowerSnapshot
    fixture.Time(101) -- Existing demo cleanup requires 0.20 s of stable live mode.
    current=94;Frequent(frame);Flush();Eq(frame.Texts.Smart:GetText(),"94")
    Eq(frame.LiveValues.classPowerSnapshot,snapshot)
end)
Test("secret numeric double bypasses clamping; secret percent remains renderable",function()
    local frame=Setup()
    -- Negative and zero sentinels detect accidental numeric clamping. They do
    -- not model native taint propagation; that remains an ingame requirement.
    current,maximum=-17,0
    local submitted,submittedMax
    -- Native StatusBar accepts opaque numeric arguments. The generic slider
    -- double clamps them in Lua, so record the native API boundary instead.
    frame.PowerBar.SetValue=function(_,value)submitted=value end
    frame.PowerBar.SetMinMaxValues=function(_,_,value)submittedMax=value end
    issecretvalue=function(v)return rawequal(v,-17) or rawequal(v,0)end
    UnitPowerPercent=function()return -17 end
    Frequent(frame);Flush();Eq(submitted,-17);Eq(submittedMax,0);Eq(frame.Texts.Cur:GetText(),"-17")
    Eq(frame.Texts.Smart:GetText(),"-17");Eq(frame.LiveValues.powerMaxRaw,0)
    powerType=0
    issecretvalue=function(v)return rawequal(v,-17)end
    Frequent(frame);Flush();Eq(frame.Texts.Smart:GetText(),"-17%")
    issecretvalue=function()return false end
    UnitPower=nil;UnitPowerMax=nil;UnitPowerPercent=nil
    Frequent(frame);Flush();Eq(frame.Texts.Smart:GetText(),"--")
end)
Test("combat Frequent leaves protected root geometry and Class-Power snapshot untouched",function()
    local frame=Setup();local snapshot=frame.LiveValues.classPowerSnapshot
    local combat=InCombatLockdown
    InCombatLockdown=function()return true end;frame.IsProtected=function()return true end
    for _,method in ipairs({"SetPoint","ClearAllPoints","SetSize","SetWidth","SetHeight","Show","Hide"})do
        frame[method]=function()error("protected root mutation: "..method)end
    end
    current=64;Frequent(frame);Flush()
    Eq(frame.Texts.Smart:GetText(),"64");Eq(frame.LiveValues.classPowerSnapshot,snapshot)
    InCombatLockdown=combat
end)
Test("editor simulated Power retains synthetic type/percent without live percent reads",function()
    local frame=Setup()
    ns.framesUnlocked=true;h.Select("PowerBar")
    issecretvalue=function(v)return rawequal(v,20)end
    UF:Refresh(frame)
    local cur,smart=frame.Texts.Cur:GetText(),frame.Texts.Smart:GetText()
    local snapshot=frame.LiveValues.classPowerSnapshot
    UnitPowerPercent=function()error("preview queried live percent")end
    Frequent(frame);Flush()
    Eq(frame.Texts.Cur:GetText(),cur);Eq(frame.Texts.Smart:GetText(),smart)
    Eq(frame.LiveValues.classPowerSnapshot,snapshot)
    ns.framesUnlocked=false;issecretvalue=function()return false end
end)
print(string.format("PowerFrequent: %d tests passed",count))
