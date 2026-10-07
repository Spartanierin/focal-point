-- lua54 Tests/ClassPowerRunes.lua
-- Real provider, factory, renderer, events, text runtime and clear boundaries.
-- Native APIs/widgets are simulated; no claim of native WoW rendering coverage.
local file = assert(io.open("Tests/TextTemplateEntityRuntime.lua"))
local source = file:read("*a"); file:close()
local stop = assert(source:find('local A="tpl:u:', 1, true))
local f = assert(load(source:sub(1, stop - 1).."\nreturn f", "@Runes/Fixture"))()
local ns, Load, native = f.ns, f.Load, f.native
Load("Engine/UnitFrame/Runtime/UnitFrameFactory.lua")
Load("Engine/UnitFrame/Runtime/UnitFrameState.lua")
Load("Engine/UnitFrame/Bars/UnitFrameClassPower.lua")
Load("Engine/UnitFrame.lua")
Load("Engine/UnitFrame/Runtime/UnitFrameVisibility.lua")
Load("GUI/Editor/Inspector/InspectorMutations.lua")
wipe=table.wipe
local C, Copy = ns.UnitFrameClassPower, ns.LayoutService.Clone
local count = 0
local function Test(name, fn) fn();count=count+1;print("PASS: "..name) end
local function Eq(a,b) assert(a==b,tostring(a).." ~= "..tostring(b)) end
local function Near(a,b) assert(math.abs(a-b)<0.00001,tostring(a).." ~= "..tostring(b)) end
local function Equal(a,b)
    if type(a)~="table" or type(b)~="table" then return Eq(a,b) end
    for k,v in pairs(a)do Equal(v,b[k])end
    for k in pairs(b)do assert(a[k]~=nil)end
end
-- Native visibility walks ancestors. The fixture otherwise treats IsVisible as IsShown.
function native:RegisterUnitEvent(event, unit) self:RegisterEvent(event); self.eventUnits=self.eventUnits or {}; self.eventUnits[event]=unit end
function native:GetValue() return self.value end
function native:Show() local was=self.shown;self.shown=true;if not was then self:Run("OnShow") end end
function native:GetFrameStrata() return "MEDIUM" end
function native:IsVisible() return self:IsShown() and (not self.parent or self.parent:IsVisible()) end
local now, class, spec, interface, calls = 100, "DEATHKNIGHT", 1, 120100, 0
GetTime=function()return now end
GetBuildInfo=function()return "12.1.0","x","x",interface end
WOW_PROJECT_MAINLINE=1;WOW_PROJECT_ID=1
UnitClassBase=function()return class end
GetSpecialization=function()return spec end
C_SpecializationInfo=nil
local cooldowns
local function RuneAPI(index)
    calls=calls+1
    local row=assert(cooldowns[index],"index")
    return table.unpack(row,1,3)
end
local function Defaults()
    now,class,spec,interface=100,"DEATHKNIGHT",1,120100
    WOW_PROJECT_ID=1;GetRuneCooldown=RuneAPI
    cooldowns={{0,0,true},{95,10,false},{98,10,false},{nil,nil,false},{0,0,true},{99,8,false}}
    ns.guiTestModeEnabled=false;ns.framesUnlocked=false
end
local function Frame()
    local unit=Copy(ns:GetDefaultDB().profile.Units.player)
    unit.classPowerBarPresent=true;unit.showClassPowerBar=true
    ns.db={profile={General={}},char={activeLayoutId="layout:runes"},global={TextTemplates={},UserLayouts={
        ["layout:runes"]={name="Runes",formatVersion=2,payload={Units={player=unit}}}}}}
    ns.ActiveLayoutResolver.InvalidateActiveRuntimeRoot()
    assert(ns.ActiveLayoutResolver.EnsureActiveRuntimeRoot(ns.db))
    local frame=CreateFrame("Frame");frame:Show();frame._fpUnit="player";frame.config=unit
    frame.Elements={};frame.Texts={};frame.Tags={}
    ns.UnitFrameFactory.CreateClassPowerBar(frame)
    return frame
end
local function Apply(frame,mode,rgba)
    rgba=rgba or {1,1,1,1}
    C.RefreshValues(ns.UnitFrame,frame)
    local info=C.GetInfo("player",frame)
    C.ApplyLayout(frame,{useBlizzardColorClassPower=mode,classPowerBarVisible=info~=nil,classPowerBarWidth=180,classPowerBarHeight=14,
        liveClassPowerSegments=info and info.segments,liveClassPowerCurrent=info and info.current,
        liveClassPowerMax=info and info.max,liveClassPowerType=info and info.typeId,
        liveClassPowerToken=info and info.token,classPowerR=rgba[1],classPowerG=rgba[2],classPowerB=rgba[3],classPowerA=rgba[4]})
    return info,frame.Elements.ClassPowerBar
end
Test("DK ordered six-state snapshot, independent timing, queued rune and aggregate",function()
    Defaults();local info=C.GetInfo("player")
    Eq(info.token,"RUNES");Eq(info.typeId,5);Eq(info.max,6);Eq(info.current,2)
    Eq(info.safeCurrent,2);Eq(info.safeMax,6);Eq(#info.segments,6)
    for i,s in ipairs(info.segments)do Eq(s.index,i)end
    assert(info.segments[1].ready);assert(not info.segments[2].ready)
    Eq(info.segments[2].startTime,95);Eq(info.segments[2].duration,10)
    Eq(info.segments[3].startTime,98);assert(info.segments[4].startTime==nil)
    UnitPower=function()error("DK must not use competing UnitPower aggregate")end
    Eq(C.GetInfo("player").current,2)
end)
Test("API missing/throwing/malformed/secret, unsupported client, no fabricated live state",function()
    Defaults();GetRuneCooldown=nil;assert(C.GetInfo("player")==nil)
    GetRuneCooldown=function()error("unavailable")end;assert(C.GetInfo("player")==nil)
    GetRuneCooldown=RuneAPI
    for _,row in ipairs({{0,0,"yes"},{95,-1,false},{95,0/0,false},{-1,10,false}})do
        cooldowns[2]=row;assert(C.GetInfo("player")==nil)
    end
    Defaults();local secret={};local old=issecretvalue
    issecretvalue=function(v)return v==secret end
    cooldowns[2]={secret,10,false};assert(C.GetInfo("player")==nil)
    cooldowns[2]={95,10,secret};assert(C.GetInfo("player")==nil)
    issecretvalue=old
    Defaults();interface=16001;local before=calls;assert(C.GetInfo("player")==nil);Eq(calls,before)
    interface=120100;WOW_PROJECT_ID=2;assert(C.GetInfo("player")==nil);WOW_PROJECT_ID=1
end)
Test("independent fill and timer, ready and queued without countdown, expiry stops work",function()
    Defaults();local frame=Frame();local info,h=Apply(frame)
    for i=1,10 do Eq(h.Bars[i]:IsShown(),i<=6)end
    Eq(h.Bars[1]:GetValue(),1);assert(not h.Bars[1].Countdown:IsShown())
    Near(h.Bars[2]:GetValue(),.5);Eq(h.Bars[2].Countdown:GetText(),"5.0")
    Near(h.Bars[3]:GetValue(),.2);Eq(h.Bars[3].Countdown:GetText(),"8.0")
    Eq(h.Bars[4]:GetValue(),0);assert(not h.Bars[4].Countdown:IsShown())
    local oldSnapshot=Copy(info);local updates=h:GetScript("OnUpdate");assert(updates)
    now=105;updates(h);Eq(h.Bars[2]:GetValue(),1);assert(not h.Bars[2].Countdown:IsShown())
    assert(h:GetScript("OnUpdate"));Eq(h.Bars[3].Countdown:GetText(),"3.0")
    now=109;updates(h);assert(not h:GetScript("OnUpdate"))
    Eq(h.Bars[4]:GetValue(),0);Equal(info,oldSnapshot) -- renderer never rewrites API truth
end)
Test("tenths update independently; same displayed tenth avoids redundant text writes",function()
    Defaults();local frame=Frame();local _,h=Apply(frame);local tick=assert(h:GetScript("OnUpdate"))
    local text=h.Bars[2].Countdown;local setText=text.SetText;local writes=0
    text.SetText=function(self,value)writes=writes+1;setText(self,value)end
    now=100.01;tick(h);Eq(text:GetText(),"5.0");Eq(writes,0)
    now=100.1;tick(h);Eq(text:GetText(),"4.9");Eq(writes,1)
    Eq(h.Bars[3].Countdown:GetText(),"7.9");Eq(h.Bars[6].Countdown:GetText(),"6.9")
    now=100.11;tick(h);Eq(writes,1)
    now=100.2;tick(h);Eq(text:GetText(),"4.8");Eq(writes,2)
    now=104.99;tick(h);Eq(text:GetText(),"0.1");assert(text:IsShown())
    now=105;tick(h);Eq(text:GetText(),"");assert(not text:IsShown())
    Eq(h.Bars[3].Countdown:GetText(),"3.0");assert(h:GetScript("OnUpdate"))
    now=109;tick(h);assert(not h:GetScript("OnUpdate"))
    for i=1,6 do Eq(h.Bars[i].Countdown:GetText(),"");assert(not h.Bars[i].Countdown:IsShown())end
    -- A single active recharge has the same rounding and final stop contract.
    Defaults();for i=1,6 do cooldowns[i]={0,0,true}end
    cooldowns[2]={95,10,false};cooldowns[4]={nil,nil,false}
    frame=Frame();_,h=Apply(frame);tick=assert(h:GetScript("OnUpdate"))
    now=100.1;tick(h);Eq(h.Bars[2].Countdown:GetText(),"4.9")
    assert(not h.Bars[1].Countdown:IsShown() and not h.Bars[4].Countdown:IsShown())
    now=105.1;tick(h);Eq(h.Bars[2].Countdown:GetText(),"");assert(not h:GetScript("OnUpdate"))
end)
Test("custom color applies equally to six runes without changing recharge state",function()
    Defaults();PowerBarColor={RUNES={r=.2,g=.3,b=.4}}
    local frame=Frame();local info,h=Apply(frame,false)
    for i=1,6 do Equal(h.Bars[i].lastSetStatusBarColor,{1,1,1,1})end
    local snapshot=Copy(info);local tick=assert(h:GetScript("OnUpdate"))
    now=100.1;tick(h);Eq(h.Bars[2].Countdown:GetText(),"4.9")
    Eq(h.Bars[3].Countdown:GetText(),"7.9");Equal(info,snapshot)
    Apply(frame,true)
    for i=1,6 do Equal(h.Bars[i].lastSetStatusBarColor,{.2,.3,.4,1})end
    Eq(h.Bars[2].Countdown:GetText(),"4.9")
    Apply(frame,false)
    for i=1,6 do Equal(h.Bars[i].lastSetStatusBarColor,{1,1,1,1})end
    Eq(h.Bars[2].Countdown:GetText(),"4.9")
end)
Test("timer hotpath: 600 ticks, no API/DB/template/global text calls or snapshot mutation",function()
    Defaults();for i=1,6 do cooldowns[i]={90+i,20,false}end
    local frame=Frame();local _,h=Apply(frame);local tick=assert(h:GetScript("OnUpdate"))
    local oldAPI=GetRuneCooldown;GetRuneCooldown=function()error("API in tick")end
    local oldDB=ns.UnitFrameUtils.GetUnitDB;ns.UnitFrameUtils.GetUnitDB=function()error("DB in tick")end
    local oldUpdate=ns.UnitFrame.UpdateTextElements;ns.UnitFrame.UpdateTextElements=function()error("text update in tick")end
    local oldResolve=ns.TextTemplateResolver.Resolve
    ns.TextTemplateResolver.Resolve=function()error("resolver in tick")end
    local before=Copy(ns.db);local segments=h.segments;local snapshot=Copy(segments)
    for i=1,600 do now=100+i/100;tick(h)end
    Eq(h.segments,segments);Equal(snapshot,segments);Equal(before,ns.db)
    now=120;tick(h);assert(not h:GetScript("OnUpdate"))
    GetRuneCooldown=oldAPI;ns.UnitFrameUtils.GetUnitDB=oldDB
    ns.UnitFrame.UpdateTextElements=oldUpdate;ns.TextTemplateResolver.Resolve=oldResolve
end)
local function AssertClear(frame)
    local h=frame.Elements.ClassPowerBar
    assert(not h.segments and not h:GetScript("OnUpdate") and not frame._classPowerPreviewInfo)
    assert(not frame.LiveValues or not frame.LiveValues.classPowerSegments)
    for _,bar in ipairs(h.Bars)do if bar.Countdown then assert(not bar.Countdown:IsShown());Eq(bar.Countdown:GetText(),"")end end
end
Test("clear boundaries remove timer state, text, fills and driver; reuse restores fresh data",function()
    for _,clear in ipairs({C.Clear,ns.UnitFrameState.ResetDerivedFrameState,
        ns.UnitFrameVisibility.ClearFrameContentValuesOnly,ns.UnitFrameVisibility.ClearFrameVisualState})do
        Defaults();local frame=Frame();Apply(frame);clear(frame);AssertClear(frame)
        for _,bar in ipairs(frame.Elements.ClassPowerBar.Bars)do Eq(bar:GetValue(),0)end
        frame:Show();Apply(frame);assert(frame.Elements.ClassPowerBar:GetScript("OnUpdate"))
    end
end)
Test("resource absent and DK to aggregate resource remove all rune leftovers",function()
    Defaults();local frame=Frame();Apply(frame)
    GetRuneCooldown=nil;Apply(frame);AssertClear(frame);assert(not frame.Elements.ClassPowerBar:IsShown())
    Defaults();Apply(frame);class="ROGUE";UnitPower=function()return 3 end;UnitPowerMax=function()return 5 end
    local info,h=Apply(frame);assert(not info.segments);AssertClear(frame)
    for i=1,5 do Eq(h.Bars[i]:GetValue(),i<=3 and 1 or 0)end
    class="WARRIOR";Apply(frame);AssertClear(frame)
end)
Test("hidden holder stops timing, re-show computes from same cached timing",function()
    Defaults();local frame=Frame();local _,h=Apply(frame)
    h:Hide();assert(not h:GetScript("OnUpdate"));now=102;h:Show()
    assert(h:GetScript("OnUpdate"));Eq(h.Bars[2].Countdown:GetText(),"3.0")
    now=120;h:Hide();h:Show();assert(not h:GetScript("OnUpdate"))
end)
Test("Detailed DK preview independent of API, stable starts, live return and placeholder",function()
    Defaults();local frame=Frame();local demo=ns.UnitFrameDemoEnvironment
    GetRuneCooldown=function()error("preview must not read runes")end
    ns.guiTestModeEnabled=true;demo.ApplyFrameSnapshot(nil,frame,{},"detailed","test")
    local info,h=Apply(frame);Eq(info.current,3);Eq(info.max,6);Eq(#info.segments,6)
    now=102;Eq(C.GetInfo("player",frame),info);Eq(info.segments[4].startTime,100)
    assert(h:GetScript("OnUpdate"))
    ns.guiTestModeEnabled=false;ns.framesUnlocked=false;GetRuneCooldown=RuneAPI
    demo.ApplyFrameSnapshot(nil,frame,{},"live","test");now=now+1
    demo.ApplyFrameSnapshot(nil,frame,{},"live","test")
    local live=Apply(frame);Eq(live.current,2);assert(not frame._classPowerPreviewInfo);assert(live~=info)
    ns.framesUnlocked=true;demo.ApplyFrameSnapshot(nil,frame,{},"placeholder","test")
    Apply(frame); -- placeholder is only a color policy, not another rune provider
    ns.framesUnlocked=false;demo.ApplyFrameSnapshot(nil,frame,{},"live","test");now=now+1
    demo.ApplyFrameSnapshot(nil,frame,{},"live","test");Apply(frame)
    assert(not frame._classPowerPreviewInfo)
end)
Test("rune events join existing refresh queue, including combat, startup and resync",function()
    Defaults();local frame=Frame();local seen={};local old=ns.UnitFrameState.QueueRefresh
    ns.UnitFrameState.QueueRefresh=function(owner,event,scopes)
        Eq(owner,frame);Eq(table.concat(scopes,","),"bars,texts,layout");seen[event]=true
    end
    C.RegisterEvents(ns.UnitFrame,frame);local events=frame.ClassPowerEventFrame
    local before=Copy(ns.db)
    for _,event in ipairs({"RUNE_POWER_UPDATE","PLAYER_SPECIALIZATION_CHANGED","PLAYER_ENTERING_WORLD","PLAYER_ALIVE","PLAYER_UNGHOST"})do
        assert(events.registeredEvents[event],event)
        for _,combat in ipairs({false,true})do InCombatLockdown=function()return combat end;events:GetScript("OnEvent")(events,event,1)end
        assert(seen[event])
    end
    Equal(before,ns.db);ns.UnitFrameState.QueueRefresh=old;InCombatLockdown=function()return false end
    Defaults();interface=16001;frame=Frame();C.RegisterEvents(ns.UnitFrame,frame)
    assert(not frame.ClassPowerEventFrame.registeredEvents.RUNE_POWER_UPDATE)
end)
Test("normal ClassPower expression/tag and deletion are independent of segment timers",function()
    Defaults();local frame=Frame();Apply(frame)
    local text=frame.config.Texts.ClassPower;assert(text)
    frame.Texts.ClassPower=frame:CreateFontString()
    ns.UnitFrame:UpdateTextElement(frame,"ClassPower")
    Eq(frame.Texts.ClassPower:GetText(),"2 / 6")
    assert(ns.TextTemplateMutations.SetLocalMainContent({db=ns.db,expectedLayoutId="layout:runes"},"player","ClassPower","READY [classpower:cur]").ok)
    local bind=f.Upvalue(ns.UnitFrame.ApplyTextElementConfig,"MaterializeTextRuntimeBinding")
    bind(frame,"ClassPower",text)
    ns.TextElementState.Reset(frame);ns.UnitFrame:UpdateTextElement(frame,"ClassPower")
    Eq(frame.Texts.ClassPower:GetText(),"READY 2")
    local h=frame.Elements.ClassPowerBar;local timer=h.Bars[2].Countdown
    assert(ns.InspectorMutations.DeleteTextInstance({unitKey="player",unitConfig=frame.config},"ClassPower").ok)
    Apply(frame);Eq(h.Bars[2].Countdown,timer);assert(timer:IsShown() and h:GetScript("OnUpdate"))
    assert(frame.config.Texts.ClassPower==nil)
    for _,config in pairs(frame.config.Texts)do assert(config~=timer)end
end)
Test("layout replacement and independent saved-state reload never persist runtime state",function()
    Defaults();local frame=Frame();local before=Copy(ns.db);Apply(frame)
    Equal(before,ns.db)
    ns.UnitFrameState.ResetDerivedFrameState(frame);AssertClear(frame)
    ns.db.global.UserLayouts["layout:other"]=Copy(ns.db.global.UserLayouts["layout:runes"])
    ns.db.char.activeLayoutId="layout:other";assert(ns.ActiveLayoutResolver.EnsureActiveRuntimeRoot(ns.db))
    frame.config=ns.UnitFrameUtils.GetUnitDB("player");Apply(frame)
    local saved=Copy(ns.db);ns.UnitFrameState.ResetDerivedFrameState(frame)
    ns.db=Copy(saved);ns.ActiveLayoutResolver.InvalidateActiveRuntimeRoot();assert(ns.ActiveLayoutResolver.EnsureActiveRuntimeRoot(ns.db))
    frame.config=ns.UnitFrameUtils.GetUnitDB("player");Apply(frame);Equal(saved,ns.db)
end)
Test("existing aggregate providers, shard fractional fill and secondary separation",function()
    Defaults();local frame=Frame();Apply(frame)
    local cases={{"ROGUE",1,"COMBO_POINTS",3,5},{"PALADIN",1,"HOLY_POWER",3,5},
        {"MONK",3,"CHI",3,6},{"MAGE",1,"ARCANE_CHARGES",3,4},{"EVOKER",1,"ESSENCE",3,6},
        {"WARLOCK",3,"SOUL_SHARDS",2.7,5},{"SHAMAN",2,"MAELSTROM",4,10}}
    C_SpellBook={IsSpellKnown=function()return true end}
    C_UnitAuras={GetPlayerAuraBySpellID=function()return {applications=4}end}
    C_Spell={GetSpellMaxCumulativeAuraApplications=function()return 10 end}
    UnitPowerDisplayMod=function()return 10 end
    for _,case in ipairs(cases)do
        class,spec=case[1],case[2]
        UnitPower=function(_,_,raw)return raw and 27 or 3 end;UnitPowerMax=function()return case[5]end
        local info,h=Apply(frame);Eq(info.token,case[3]);Near(info.current,case[4]);Eq(info.max,case[5]);assert(not info.segments)
        assert(not h.segments and not h:GetScript("OnUpdate"));Eq(frame.LiveValues.classPowerSegments,nil)
        if class=="WARLOCK" then Near(h.Bars[3]:GetValue(),.7)end
    end
    frame.LiveValues.altPowerCurrentRaw=72;frame.LiveValues.altPowerMaxRaw=100
    Defaults();Apply(frame);Eq(frame.LiveValues.altPowerCurrentRaw,72);Eq(frame.LiveValues.altPowerMaxRaw,100)
end)
-- Read the shipped oUF palette, rather than a second product color table.
local paletteFile=assert(io.open("Libraries/oUF/colors.lua"));local paletteSource=paletteFile:read("*a");paletteFile:close()
local paletteBody=assert(paletteSource:match("runes = (%b{})"))
local runePalette=assert(load("return "..paletteBody,"@oUF.RunePalette","t",{oUF={
    CreateColor=function(_,r,g,b)return {GetRGB=function()return r/255,g/255,b/255 end}end}}))()
local function AssertPaint(holder,rgb,alpha)
    for i=1,6 do Equal(holder.Bars[i].lastSetStatusBarColor,{rgb[1],rgb[2],rgb[3],alpha})end
end
Test("oUF Blood/Frost/Unholy colors, auto modes and spec refresh; custom ignores spec",function()
    Defaults();local oldOUF=ns.oUF;local oldQueue=ns.UnitFrameState.QueueRefresh
    ns.oUF={colors={runes=runePalette}};PowerBarColor={RUNES={r=.5,g=.5,b=.5}}
    local expected={{247/255,65/255,57/255},{148/255,203/255,247/255},{173/255,235/255,66/255}}
    local frame=Frame();local before=Copy(ns.db);local mode;local rgba={.23,.34,.45,0}
    local function PaintNow()local info,h=Apply(frame,mode,rgba);return info,h end
    ns.UnitFrameState.QueueRefresh=function(owner,event,scopes)
        Eq(owner,frame);Eq(event,"PLAYER_SPECIALIZATION_CHANGED");Eq(table.concat(scopes,","),"bars,texts,layout")
        PaintNow()
    end
    C.RegisterEvents(ns.UnitFrame,frame)
    local info,h=PaintNow();local snapshot=Copy(info)
    for _,api in ipairs({"modern","legacy"})do
        C_SpecializationInfo=api=="modern" and {GetSpecialization=function()return spec end} or nil
        for _,setting in ipairs({{}, {mode=true}, {mode=false}})do
            mode=setting.mode
            for index=1,3 do
                spec=index
                for _,alpha in ipairs({0,.6,1})do
                    rgba[4]=alpha
                    frame.ClassPowerEventFrame:GetScript("OnEvent")(frame.ClassPowerEventFrame,"PLAYER_SPECIALIZATION_CHANGED","player")
                    AssertPaint(h,mode==false and rgba or expected[index],alpha)
                    Eq(h.Bars[2].Countdown:GetText(),"5.0");Near(h.Bars[2]:GetValue(),.5)
                end
            end
        end
    end
    Equal(info,snapshot);Equal(ns.db,before)
    ns.UnitFrameState.QueueRefresh=oldQueue;ns.oUF=oldOUF;C_SpecializationInfo=nil
end)
Test("unknown spec or unavailable rune palette uses existing resource fallback",function()
    Defaults();local oldOUF=ns.oUF;ns.oUF={colors={runes=runePalette}}
    PowerBarColor={RUNES={r=.5,g=.5,b=.5}};local frame=Frame()
    for _,unknown in ipairs({0,4,-1,1.5,"invalid"})do
        spec=unknown;local _,h=Apply(frame,true);AssertPaint(h,{.5,.5,.5},1)
    end
    spec=nil;local _,h=Apply(frame);AssertPaint(h,{.5,.5,.5},1)
    spec=1
    for _,colors in ipairs({{}, {runes={}}, {runes={[1]={r="bad"}}}})do
        ns.oUF={colors=colors};_,h=Apply(frame,true);AssertPaint(h,{.5,.5,.5},1)
    end
    ns.oUF=oldOUF
end)
Test("detailed rune demo follows spec; neutral placeholder ignores rune palette",function()
    Defaults();local oldOUF=ns.oUF;ns.oUF={colors={runes=runePalette}}
    PowerBarColor={RUNES={r=.5,g=.5,b=.5}}
    local frame=Frame();local demo=ns.UnitFrameDemoEnvironment
    ns.guiTestModeEnabled=true;GetRuneCooldown=function()error("demo must not read live rune API")end
    demo.ApplyFrameSnapshot(nil,frame,{},"detailed","color-test")
    for i=1,3 do
        spec=i;local _,h=Apply(frame,true);AssertPaint(h,{runePalette[i]:GetRGB()},1)
    end
    ns.guiTestModeEnabled=false;ns.framesUnlocked=true
    demo.ApplyFrameSnapshot(nil,frame,{},"placeholder","color-test");assert(demo.IsPlaceholder(frame))
    local _,h=Apply(frame,true);local p=demo.GetPlaceholderColors();AssertPaint(h,{p.barR,p.barG,p.barB},p.barA)
    ns.oUF=oldOUF;Defaults()
end)
assert(#f.env.errors==0,table.concat(f.env.errors,"\n"))
print("Class Power Runes: "..count.." groups PASS")
