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
        liveClassPowerGainValid=info and info.comboPointGainValid,
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

-- Animation doubles assert scheduling/reset only, not native WoW rendering.
function native:GetStatusBarColor() return table.unpack(self.lastSetStatusBarColor or {1,1,1,1}) end
local animationCount = 0
function native:CreateAnimationGroup()
    animationCount = animationCount + 1
    local group = { children = {}, scripts = {}, plays = 0 }
    function group:SetLooping(value) self.looping = value end
    function group:SetScript(event, fn) self.scripts[event] = fn end
    function group:CreateAnimation(kind)
        Eq(kind, "Alpha")
        local child = {}
        for _, name in ipairs({"Order", "Duration", "FromAlpha", "ToAlpha"}) do
            child["Set"..name] = function(self, value) self[name] = value end
        end
        self.children[#self.children+1] = child
        return child
    end
    function group:Play() self.plays = self.plays + 1; self.playing = true end
    function group:Stop() self.playing = false end
    function group:Finish() self.playing = false; self.scripts.OnFinished(self) end
    return group
end
local function Plays(holder, index)
    local texture = holder.Bars[index].ReadyHighlight
    return texture and texture.animation.plays or 0
end
local function Quiet(holder)
    for _, bar in ipairs(holder.Bars) do
        if bar.ReadyHighlight then
            assert(not bar.ReadyHighlight.animation.playing)
            assert(not bar.ReadyHighlight:IsShown())
            Eq(bar.ReadyHighlight.lastSetAlpha[1], 0)
        end
    end
end
local function HighlightCase(fn)
    Defaults()
    local frame = Frame()
    local _, holder = Apply(frame)
    local queue = ns.UnitFrameState.QueueRefresh
    -- Deliberately retain only the last reason, as the shared queue does.
    local reason
    ns.UnitFrameState.QueueRefresh = function(_, event) reason = event end
    C.RegisterEvents(ns.UnitFrame, frame)
    local function Event(event, index)
        frame.ClassPowerEventFrame:Run("OnEvent", event, index)
    end
    fn(frame, holder, Event, function() return reason end)
    ns.UnitFrameState.QueueRefresh = queue
end
Test("highlight: initial snapshot, qualified ready once, no unqualified or repeated ready", function()
    HighlightCase(function(frame, h, event)
        for i=1,6 do Eq(Plays(h,i),0) end
        cooldowns[2]={0,0,true};event("RUNE_POWER_UPDATE",2);Apply(frame)
        Eq(Plays(h,2),1)
        event("RUNE_POWER_UPDATE",2);Apply(frame);Apply(frame);Eq(Plays(h,2),1)
        cooldowns[3]={0,0,true};event("UNIT_AURA","player");Apply(frame);Eq(Plays(h,3),0)
        event("RUNE_POWER_UPDATE",3);Apply(frame);Eq(Plays(h,3),0)
        cooldowns[2]={nil,nil,false};event("RUNE_POWER_UPDATE",2);Apply(frame);Quiet(h)
        event("RUNE_POWER_UPDATE",2);Apply(frame);Eq(Plays(h,2),1)
    end)
end)
Test("highlight: countdown expiry is not ready; spent without timing needs event and flag", function()
    HighlightCase(function(frame,h,event)
        now=120;h:GetScript("OnUpdate")(h);Eq(h.Bars[2]:GetValue(),1)
        Eq(Plays(h,2),0);event("RUNE_POWER_UPDATE",2);Apply(frame);Eq(Plays(h,2),0)
        cooldowns[2]={0,0,true};cooldowns[4]={0,0,true}
        event("RUNE_POWER_UPDATE",2);event("RUNE_POWER_UPDATE",4);Apply(frame)
        Eq(Plays(h,2),1);Eq(Plays(h,4),1)
    end)
end)
Test("highlight: batching retains rune invalidation despite unrelated final queue reason", function()
    HighlightCase(function(frame,h,event,reason)
        cooldowns[2]={0,0,true};cooldowns[3]={0,0,true};cooldowns[4]={0,0,true}
        event("RUNE_POWER_UPDATE",2);event("RUNE_POWER_UPDATE",2);event("RUNE_POWER_UPDATE",3)
        event("UNIT_AURA","player");Eq(reason(),"UNIT_AURA");Apply(frame)
        Eq(Plays(h,2),1);Eq(Plays(h,3),1);Eq(Plays(h,4),1);Eq(Plays(h,6),0)
        Apply(frame);Eq(Plays(h,2),1);Eq(Plays(h,3),1)
    end)
end)
Test("highlight: resync after rune event cancels evidence", function()
    for _,boundary in ipairs({"PLAYER_ENTERING_WORLD","PLAYER_ALIVE","PLAYER_UNGHOST",
        "PLAYER_SPECIALIZATION_CHANGED","UNIT_MAXPOWER","UNIT_DISPLAYPOWER"}) do
        HighlightCase(function(frame,h,event)
            cooldowns[2]={0,0,true};event("RUNE_POWER_UPDATE",2)
            event(boundary,boundary:match("^UNIT_") and "player" or nil);Apply(frame);Eq(Plays(h,2),0)
        end)
    end
end)
Test("highlight: opaque event payload is never inspected, formatted or stored", function()
    HighlightCase(function(frame,h,event)
        local function Forbidden() error("event payload inspected") end
        local secret=setmetatable({}, {__tostring=Forbidden,__lt=Forbidden,__le=Forbidden,__mod=Forbidden})
        local old=issecretvalue
        issecretvalue=function(value)
            if rawequal(value,secret) then Forbidden() end
            return old(value)
        end
        cooldowns[2]={0,0,true};event("RUNE_POWER_UPDATE",secret);Apply(frame)
        Eq(Plays(h,2),1)
        assert(not h._readyTransitions.runeEventObserved)
        event("RUNE_POWER_UPDATE",secret);Apply(frame);Eq(Plays(h,2),1)
        issecretvalue=old
    end)
end)
Test("highlight: early event is consumed by unchanged snapshot, never retried", function()
    HighlightCase(function(frame,h,event)
        event("RUNE_POWER_UPDATE");Apply(frame)
        assert(not h._readyTransitions.runeEventObserved);Eq(Plays(h,2),0)
        cooldowns[2]={0,0,true};Apply(frame);Eq(Plays(h,2),0)
        cooldowns[2]={nil,nil,false};Apply(frame)
        cooldowns[2]={0,0,true};event("RUNE_POWER_UPDATE");Apply(frame);Eq(Plays(h,2),1)
        Apply(frame);Eq(Plays(h,2),1)
    end)
end)
Test("highlight: invalid API breaks baseline, recovery is initial snapshot", function()
    HighlightCase(function(frame,h,event)
        cooldowns[2]={0,0,"invalid"};event("RUNE_POWER_UPDATE",2);Apply(frame);Quiet(h)
        assert(not h._readyTransitions)
        cooldowns[2]={0,0,true};event("RUNE_POWER_UPDATE",2);Apply(frame);Eq(Plays(h,2),0)
    end)
end)
Test("highlight: root/config/spec/editor context changes discard evidence", function()
    for _,change in ipairs({
        function(frame) frame.config=Copy(frame.config) end,
        function() ns.ActiveLayoutResolver.InvalidateActiveRuntimeRoot();assert(ns.ActiveLayoutResolver.EnsureActiveRuntimeRoot(ns.db)) end,
        function() spec=2 end,
        function() ns.framesUnlocked=true end,
    }) do
        HighlightCase(function(frame,h,event)
            event("RUNE_POWER_UPDATE",2);change(frame);cooldowns[2]={0,0,true};Apply(frame)
            Eq(Plays(h,2),0);Quiet(h)
        end)
    end
end)
Test("highlight: 50 clear/hide/reuse cycles cancel animation and reinitialize quietly", function()
    HighlightCase(function(frame,h,event)
        for cycle=1,50 do
            cooldowns[2]={nil,nil,false};Apply(frame)
            cooldowns[2]={0,0,true};event("RUNE_POWER_UPDATE",2);Apply(frame);Eq(Plays(h,2),cycle)
            if cycle%2==0 then C.Clear(frame) else h:Hide();h:Show() end
            Quiet(h);assert(not h._readyTransitions)
            event("RUNE_POWER_UPDATE",2);Apply(frame);Eq(Plays(h,2),cycle)
        end
    end)
end)
Test("highlight: demo/live boundary and resource switch never reuse rune evidence", function()
    HighlightCase(function(frame,h,event)
        event("RUNE_POWER_UPDATE",2);ns.guiTestModeEnabled=true
        ns.UnitFrameDemoEnvironment.ApplyFrameSnapshot(nil,frame,{},"detailed","highlight-test")
        Apply(frame);assert(not h._readyTransitions);Quiet(h)
        ns.guiTestModeEnabled=false
        ns.UnitFrameDemoEnvironment.ApplyFrameSnapshot(nil,frame,{},"live","highlight-test")
        cooldowns[2]={0,0,true};event("RUNE_POWER_UPDATE",2);Apply(frame);Eq(Plays(h,2),0)
        class="ROGUE";UnitPower=function()return 4 end;UnitPowerMax=function()return 5 end
        event("UNIT_POWER_UPDATE","player");Apply(frame);assert(not h._readyTransitions);Quiet(h)
        class="DEATHKNIGHT";event("RUNE_POWER_UPDATE",2);Apply(frame);Eq(Plays(h,2),0)
    end)
end)
Test("highlight: native one-shot shape, resolved colors/alpha and zero per-frame callbacks", function()
    for _,mode in ipairs({true,false}) do
        for currentSpec=1,3 do
            HighlightCase(function(frame,h,event)
                spec=currentSpec;local oldOUF=ns.oUF;ns.oUF={colors={runes=runePalette}}
                Apply(frame,mode,{.2,.3,.4,.6})
                local color=h.Bars[2].lastSetStatusBarColor
                local before=Copy(color);local created=animationCount
                cooldowns[2]={0,0,true};event("RUNE_POWER_UPDATE",2);Apply(frame,mode,{.2,.3,.4,.6})
                local texture=assert(h.Bars[2].ReadyHighlight);local group=texture.animation
                Eq(animationCount,created+1);Eq(group.looping,"NONE");Eq(#group.children,2)
                Near(group.children[1].Duration+group.children[2].Duration,.125)
                Equal(texture.lastSetVertexColor,{color[1]+(1-color[1])*.6,color[2]+(1-color[2])*.6,color[3]+(1-color[3])*.6,.6})
                Equal(before,h.Bars[2].lastSetStatusBarColor);assert(not texture:GetScript("OnUpdate"))
                local oldAPI=GetRuneCooldown;GetRuneCooldown=function()error("animation API")end
                group:Finish();Quiet(h);GetRuneCooldown=oldAPI
                ns.oUF=oldOUF
            end)
        end
    end
    HighlightCase(function(frame,h,event)
        Apply(frame,false,{.2,.3,.4,0});cooldowns[2]={0,0,true};event("RUNE_POWER_UPDATE",2)
        Apply(frame,false,{.2,.3,.4,0});Eq(Plays(h,2),0);Quiet(h)
    end)
end)


Test("highlight: max mismatch and secret snapshot reset instead of manufacturing transitions", function()
    HighlightCase(function(frame,h,event)
        local original=C.GetInfo
        C.GetInfo=function(...) local info=original(...);info.max=5;return info end
        event("RUNE_POWER_UPDATE",2);Apply(frame);assert(not h._readyTransitions)
        C.GetInfo=original;cooldowns[2]={0,0,true};event("RUNE_POWER_UPDATE",2);Apply(frame);Eq(Plays(h,2),0)
        cooldowns[2]={nil,nil,false};Apply(frame)
        local secret={};local old=issecretvalue;issecretvalue=function(value)return value==secret end
        cooldowns[2]={0,0,secret};event("RUNE_POWER_UPDATE",2);Apply(frame);assert(not h._readyTransitions)
        issecretvalue=old;cooldowns[2]={0,0,true};event("RUNE_POWER_UPDATE",2);Apply(frame);Eq(Plays(h,2),0)
    end)
end)
Test("highlight: active color/alpha sync and individual segment reuse", function()
    HighlightCase(function(frame,h,event)
        cooldowns[2]={0,0,true};event("RUNE_POWER_UPDATE",2);Apply(frame)
        local texture=assert(h.Bars[2].ReadyHighlight)
        Apply(frame,false,{.1,.2,.3,.4})
        Equal(texture.lastSetVertexColor,{.1+.9*.6,.2+.8*.6,.3+.7*.6,.4})
        Apply(frame,false,{.1,.2,.3,0});Quiet(h)
        cooldowns[2]={nil,nil,false};Apply(frame)
        cooldowns[2]={0,0,true};event("RUNE_POWER_UPDATE",2);Apply(frame)
        h.Bars[2]:Hide();Quiet(h);assert(not h._readyTransitions)
        h.Bars[2]:Show();event("RUNE_POWER_UPDATE",2);Apply(frame);Eq(Plays(h,2),2)
    end)
end)
Test("highlight: real shared queue coalesces unrelated refresh without losing evidence", function()
    local realQueue=ns.UnitFrameState.QueueRefresh
    HighlightCase(function(frame,h,event)
        local oldTimer,oldRefresh=C_Timer,ns.UnitFrame.Refresh
        local pending={};C_Timer={After=function(_,fn)pending[#pending+1]=fn end}
        ns.UnitFrameState.QueueRefresh=realQueue
        local commits=0
        ns.UnitFrame.Refresh=function(_,owner,request)
            Eq(owner,frame);Eq(request.reason,"UNIT_AURA");commits=commits+1;Apply(owner)
        end
        cooldowns[2]={0,0,true};cooldowns[3]={0,0,true}
        event("RUNE_POWER_UPDATE",2);event("RUNE_POWER_UPDATE",3);event("UNIT_AURA","player")
        Eq(#pending,1);pending[1]();Eq(commits,1);Eq(Plays(h,2),1);Eq(Plays(h,3),1)
        Apply(frame);Eq(Plays(h,2),1)
        C_Timer=oldTimer;ns.UnitFrame.Refresh=oldRefresh
    end)
end)


-- Combo Points share the real provider, snapshot path, renderer and animation.
local function ComboCase(fn)
    Defaults();class="ROGUE"
    local values={current=2,max=5}
    UnitPower=function()return values.current end
    UnitPowerMax=function()return values.max end
    local frame=Frame();local _,h=Apply(frame)
    local queue=ns.UnitFrameState.QueueRefresh
    ns.UnitFrameState.QueueRefresh=function()end
    C.RegisterEvents(ns.UnitFrame,frame)
    local function Event(event,unit,token)
        frame.ClassPowerEventFrame:Run("OnEvent",event,unit,token)
    end
    local function Gain()Event("UNIT_POWER_UPDATE","player","COMBO_POINTS");Apply(frame)end
    fn(frame,h,values,Event,Gain)
    ns.UnitFrameState.QueueRefresh=queue
end
Test("combo: initial/identical, single and multiple gains, spend and renewed gain",function()
    ComboCase(function(frame,h,v,event,gain)
        Apply(frame);for i=1,10 do Eq(Plays(h,i),0)end
        v.current=3;gain();Eq(Plays(h,3),1);Eq(Plays(h,2),0)
        Apply(frame);gain();Eq(Plays(h,3),1)
        v.current=2;gain();Quiet(h)
        v.current=4;gain();Eq(Plays(h,3),2);Eq(Plays(h,4),1);Eq(Plays(h,5),0)
    end)
end)
Test("combo: no event, wrong token/unit, early event and render-only resync never flash",function()
    ComboCase(function(frame,h,v,event,gain)
        event("UNIT_POWER_UPDATE","player","COMBO_POINTS");Apply(frame)
        v.current=3;Apply(frame);Eq(Plays(h,3),0)
        v.current=4;event("UNIT_POWER_UPDATE","player","ENERGY");Apply(frame);Eq(Plays(h,4),0)
        v.current=5;event("UNIT_POWER_UPDATE","target","COMBO_POINTS");Apply(frame);Eq(Plays(h,5),0)
        v.current=2;Apply(frame)
        -- A rendering-only snapshot may resync but cannot qualify gains.
        event("UNIT_POWER_UPDATE","player","COMBO_POINTS")
        v.current=4;local info=C.GetInfo("player",frame)
        C.ApplyLayout(frame,{classPowerBarVisible=true,liveClassPowerCurrent=4,liveClassPowerMax=5,
            liveClassPowerToken=info.token,liveClassPowerGainValid=info.comboPointGainValid})
        Eq(Plays(h,3),0);Eq(Plays(h,4),0);Apply(frame);Eq(Plays(h,3),0)
    end)
end)
Test("combo: fractional progress only flashes newly completed boundaries",function()
    ComboCase(function(frame,h,v,event,gain)
        v.current=2.7;gain();Eq(Plays(h,3),0)
        v.current=3;gain();Eq(Plays(h,3),1)
        v.current=3.8;gain();Eq(Plays(h,4),0)
    end)
end)
Test("combo: actual shared queue batching and lost intermediate states are conservative",function()
    local realQueue=ns.UnitFrameState.QueueRefresh
    ComboCase(function(frame,h,v,event,gain)
        local oldTimer,oldRefresh=C_Timer,ns.UnitFrame.Refresh
        local pending={};C_Timer={After=function(_,fn)pending[#pending+1]=fn end}
        ns.UnitFrameState.QueueRefresh=realQueue
        ns.UnitFrame.Refresh=function(_,owner)Apply(owner)end
        v.current=3;event("UNIT_POWER_UPDATE","player","COMBO_POINTS")
        v.current=4;event("UNIT_POWER_UPDATE","player","COMBO_POINTS");event("UNIT_AURA","player")
        Eq(#pending,1);pending[1]();Eq(Plays(h,3),1);Eq(Plays(h,4),1)
        pending={};v.current=2;event("UNIT_POWER_UPDATE","player","COMBO_POINTS")
        v.current=4;event("UNIT_POWER_UPDATE","player","COMBO_POINTS");pending[1]()
        Eq(Plays(h,3),1);Eq(Plays(h,4),1)
        C_Timer=oldTimer;ns.UnitFrame.Refresh=oldRefresh
    end)
end)
Test("combo: secret/missing event payload cannot qualify or preserve pending evidence",function()
    ComboCase(function(frame,h,v,event,gain)
        local secret=setmetatable({},{__tostring=function()error("secret formatting")end,
            __eq=function()error("secret comparison")end})
        local old=issecretvalue;issecretvalue=function(value)return rawequal(value,secret)end
        for _,args in ipairs({{secret,"COMBO_POINTS"},{"player",secret},{"player"}})do
            v.current=2;Apply(frame)
            event("UNIT_POWER_UPDATE","player","COMBO_POINTS")
            v.current=3;event("UNIT_POWER_UPDATE",args[1],args[2]);Apply(frame)
            Eq(Plays(h,3),0)
        end
        issecretvalue=old
    end)
end)
Test("combo: invalid API values/fallback zero and recovery never manufacture gain",function()
    ComboCase(function(frame,h,v,event,gain)
        local secret={};local old=issecretvalue;issecretvalue=function(value)return rawequal(value,secret)end
        for _,invalid in ipairs({false,"0",secret,0/0,math.huge,-1,6})do
            v.current=invalid;gain();assert(not h._readyTransitions)
            v.current=3;gain();Eq(Plays(h,3),0)
        end
        v.current=nil;gain();assert(not h._readyTransitions)
        v.current=4;gain();Eq(Plays(h,4),0)
        v.max=secret;gain();assert(not h._readyTransitions)
        v.max=5;gain();Eq(Plays(h,4),0)
        issecretvalue=old
    end)
end)
Test("combo: max/spec/layout/resource/demo/editor transitions invalidate evidence",function()
    local changes={
        function(frame,v)v.max=6 end,
        function()spec=2 end,
        function(frame)frame.config=Copy(frame.config)end,
        function()ns.ActiveLayoutResolver.InvalidateActiveRuntimeRoot();assert(ns.ActiveLayoutResolver.EnsureActiveRuntimeRoot(ns.db))end,
        function()class="PALADIN"end,
        function()ns.framesUnlocked=true end,
        function(frame)ns.guiTestModeEnabled=true;ns.UnitFrameDemoEnvironment.ApplyFrameSnapshot(nil,frame,{},"detailed","combo-test")end,
    }
    for _,change in ipairs(changes)do
        ComboCase(function(frame,h,v,event,gain)
            event("UNIT_POWER_UPDATE","player","COMBO_POINTS");change(frame,v);v.current=3;Apply(frame)
            Eq(Plays(h,3),0);Quiet(h)
        end)
    end
end)
Test("combo: 50 clear/hide/reuse cycles, ordinary aggregate refresh preserves animation",function()
    ComboCase(function(frame,h,v,event,gain)
        for cycle=1,50 do
            v.current=2;Apply(frame);v.current=3;gain();Eq(Plays(h,3),cycle)
            local texture=assert(h.Bars[3].ReadyHighlight)
            Apply(frame);assert(texture.animation.playing);Eq(Plays(h,3),cycle)
            if cycle%2==0 then C.Clear(frame)else h:Hide();h:Show()end
            Quiet(h);assert(not h._readyTransitions)
            gain();Eq(Plays(h,3),cycle)
        end
    end)
end)
Test("combo: shared 125ms animation, custom/Blizzard color and alpha zero",function()
    ComboCase(function(frame,h,v,event,gain)
        local old=PowerBarColor;PowerBarColor={COMBO_POINTS={r=.2,g=.3,b=.4}}
        Apply(frame,true);v.current=3;gain()
        local texture=assert(h.Bars[3].ReadyHighlight)
        Equal(texture.lastSetVertexColor,{.2+.8*.6,.3+.7*.6,.4+.6*.6,1})
        Near(texture.animation.children[1].Duration+texture.animation.children[2].Duration,.125)
        v.current=2;Apply(frame,false,{.1,.2,.3,0})
        v.current=3;event("UNIT_POWER_UPDATE","player","COMBO_POINTS");Apply(frame,false,{.1,.2,.3,0})
        Eq(Plays(h,3),1);Quiet(h)
        PowerBarColor=old
    end)
end)
assert(#f.env.errors==0,table.concat(f.env.errors,"\n"))
print("Class Power Runes: "..count.." groups PASS")
