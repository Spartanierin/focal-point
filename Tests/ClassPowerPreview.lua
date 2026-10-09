-- lua54 Tests/ClassPowerPreview.lua
-- Real demo toggle, refresh, ApplyConfig and class-power renderer; native widgets are doubles.
local function Read(path)local f=assert(io.open(path));local s=f:read("*a");f:close();return s end
local h=assert(load(Read("Tests/ClassPowerRunes.lua")..[[
return {ns=ns,Load=Load,native=native,Defaults=Defaults,Frame=Frame,Eq=Eq,Equal=Equal,Copy=Copy,
Time=function(v)now=v end,Class=function(v)class=v end,Spec=function(v)spec=v end,Plays=Plays}
]],"@ClassPowerPreview/Fixture"))()
local ns,C,Eq=h.ns,h.ns.UnitFrameClassPower,h.Eq
local function Noop()end
h.native.SetScale=function(self,value)self.scale=value end
h.native.GetEffectiveScale=function(self)return self.scale or 1 end
h.native.SetClampedToScreen=Noop;h.native.SetMouseClickEnabled=Noop
ns.MediaRegistry=nil;h.Load("Services/MediaRegistry.lua")
for _,path in ipairs({
    "Engine/UnitFrame/Shared/UnitFrameColors.lua",
    "Engine/UnitFrame/Shared/UnitFramePreview.lua",
    "Engine/UnitFrame/Runtime/UnitFrameLayout.lua",
    "Engine/UnitFrame/Runtime/UnitFrameInsideLayout.lua",
    "Engine/UnitFrame/Bars/UnitFrameBarLayout.lua",
    "Engine/UnitFrame/Indicators/UnitFramePortrait.lua",
    "Engine/UnitFrame/Indicators/UnitFrameIndicators.lua",
    "Engine/UnitFrame/Runtime/UnitFrameRefresh.lua",
})do h.Load(path)end
ns.UnitFrameAssets={GetStatusBarTexture=function()return "fixture"end}
ns.UnitFrameCastBar={Start=Noop,Stop=Noop,StartPreview=Noop,Refresh=Noop}
ns.UnitFrameClassificationIndicator={ApplyLayout=Noop}
h.Load("Engine/UnitFrame.lua")
local UF=ns.UnitFrame
-- Unrelated health/text/aura/cast rendering is not part of this fixture.
UF.ApplyRangeFade=Noop;UF.RefreshLiveValues=Noop;UF.UpdateTextElements=Noop
UF.UpdateHealthBarColor=Noop;UF.UpdatePowerBarColor=Noop
UF.RefreshUnitBarValues=function(self,frame)C.RefreshValues(self,frame)end
UF.UpdateTextEditCastPreview=Noop;UF.RefreshCastBar=Noop;UF.RefreshAuras=Noop
local frame,scope,selected
ns.GUI.Editor.State.GetPropertyScope=function()return scope end
ns.GUI.Editor.ObjectSelection={}
ns.GUI.Editor.ObjectSelection.GetSelectedObject=function()return selected end
ns.IsEditorActive=function()return ns.framesUnlocked==true end
local function Select(key)
    scope={unit="player",objectKey=key};selected=key and {unit="player",kind="bar",key=key,objectKey=key} or nil
end
local function Refresh()UF:Refresh(frame,{reason="class-power-preview-test"})end
ns.RefreshAllUnitFrames=function()Refresh()end
ns.EnsureBossFrames=nil;ns.TestEnvironment=nil
local gui=Read("GUI/GUIMainController.lua")
local start=assert(gui:find("    function self:SetTestModeEnabled",1,true))
local finish=assert(gui:find('    hostWidget:SetCallback("OnClose"',start,true))
assert(load("local self,FocalPoint=...; local function GetReadyStatusText()return 'Ready'end\n"..gui:sub(start,finish-1),"@ClassPowerPreview/RealDemoToggle"))(ns,ns)
local function Setup(class)
    h.Defaults();h.Class(class);frame=h.Frame();Select(nil)
    frame.config.Texts={};frame.config.Portrait=nil
    frame.HealthBar=CreateFrame("StatusBar",nil,frame);frame.PowerBar=CreateFrame("StatusBar",nil,frame)
    frame.Elements.HealthBar=frame.HealthBar;frame.Elements.PowerBar=frame.PowerBar
    frame.IsProtected=function()return false end
    return frame,frame.Elements.ClassPowerBar
end

-- Native OnShow/OnHide also fires when an ancestor changes effective visibility.
local create=CreateFrame
CreateFrame=function(kind,name,parent,...)
    local widget=create(kind,name,parent,...)
    if parent then parent.previewTestChildren=parent.previewTestChildren or {};table.insert(parent.previewTestChildren,widget)end
    return widget
end
for _,method in ipairs({"Show","Hide"})do
    local original=h.native[method]
    h.native[method]=function(self,...)
        local descendants={}
        local function Visit(parent)
            for _,child in ipairs(parent.previewTestChildren or {})do
                descendants[#descendants+1]={child,child:IsVisible()};Visit(child)
            end
        end
        Visit(self);original(self,...)
        for _,entry in ipairs(descendants)do
            local visible=entry[1]:IsVisible()
            if visible~=entry[2] then entry[1]:Run(visible and "OnShow" or "OnHide")end
        end
    end
end

local count=0
local function Test(name,fn)fn();count=count+1;print("PASS: "..name)end
Test("Warrior real detailed toggle/refresh shows aggregate fallback and exits to live",function()
    local f,holder=Setup("WARRIOR")
    Refresh();assert(not holder:IsShown())
    ns:ToggleTestMode();Eq(f.FocalPointDemoRuntime.mode,"detailed");assert(holder:IsShown())
    Eq(f.LiveValues.classPowerMaxSafe,5);assert(not holder.segments)
    ns:ToggleTestMode();assert(not holder:IsShown());assert(not f._classPowerPreviewInfo)
end)

local function NoFlashes(holder)
    for i=1,6 do Eq(h.Plays(holder,i),0)end
end
local function Timers(holder)
    assert(holder:IsShown());Eq(#holder.segments,6)
    Eq(holder.Bars[4].Countdown:GetText(),"10.0")
    Eq(holder.Bars[5].Countdown:GetText(),"8.0");Eq(holder.Bars[6].Countdown:GetText(),"6.0")
    for i=1,6 do Eq(holder.segments[i].index,i);Eq(holder.Bars[i].Countdown:GetParent(),holder.Bars[i])end
    NoFlashes(holder)
end
Test("detailed fallback respects presence/show; unsupported live specs remain synthetic only in preview",function()
    for _,class in ipairs({"WARRIOR","MAGE","MONK","DRUID"})do
        local f,holder=Setup(class);h.Spec(2)
        Refresh();assert(not holder:IsShown())
        ns:ToggleTestMode();assert(holder:IsShown());assert(not holder.segments)
        for _,field in ipairs({"classPowerBarPresent","showClassPowerBar"})do
            f.config[field]=false;Refresh();assert(not holder:IsShown());Eq(C.ShouldForcePreview("player",f),false)
            f.config[field]=true;Refresh();assert(holder:IsShown())
        end
        ns:ToggleTestMode();assert(not holder:IsShown())
    end
end)
Test("DK detailed toggle uses six synthetic timers without querying rune API",function()
    local f,holder=Setup("DEATHKNIGHT");local api=GetRuneCooldown
    GetRuneCooldown=function()error("synthetic preview queried runes")end
    ns:ToggleTestMode();Timers(holder);Eq(f._classPowerPreviewInfo.previewMode,"detailed")
    GetRuneCooldown=api;ns:ToggleTestMode();assert(not f._classPowerPreviewInfo)
    Eq(holder.Bars[2].Countdown:GetText(),"5.0");Eq(holder.Bars[4].Countdown:GetText(),"")
    NoFlashes(holder)
end)
Test("selected Canvas bar on Warrior/DK: actual layout applies font/size/outline, no rune API",function()
    for _,class in ipairs({"WARRIOR","DEATHKNIGHT"})do
        local f,holder=Setup(class);ns.framesUnlocked=true;Select("ClassPowerBar")
        local api=GetRuneCooldown;GetRuneCooldown=function()error("selection queried runes")end
        Refresh();Timers(holder);Eq(f._classPowerPreviewInfo.previewMode,"selection")
        f.config.classPowerRuneTimerFont="fp:font:morpheus"
        f.config.classPowerRuneTimerFontSize=18;f.config.classPowerRuneTimerFontStyle="THICKOUTLINE_MONOCHROME"
        Refresh();Timers(holder)
        for i=1,6 do
            local font,size,flags=holder.Bars[i].Countdown:GetFont()
            Eq(font,"Fonts\\MORPHEUS.ttf");Eq(size,18);Eq(flags,"THICKOUTLINE,MONOCHROME")
        end
        GetRuneCooldown=api;Select("HealthBar");Refresh();assert(not f._classPowerPreviewInfo)
        if class=="WARRIOR" then assert(not holder.segments)else Eq(holder.Bars[2].Countdown:GetText(),"5.0")end
    end
end)
Test("finite preview does not auto-recharge; reselect and each style field restart once",function()
    local f,holder=Setup("WARRIOR");ns.framesUnlocked=true;Select("ClassPowerBar");Refresh()
    local initial=f._classPowerPreviewInfo;local tick=assert(holder:GetScript("OnUpdate"))
    h.Time(111);tick(holder);assert(not holder:GetScript("OnUpdate"));Refresh()
    Eq(f._classPowerPreviewInfo,initial);Eq(initial.current,6)
    for i=1,6 do Eq(holder.Bars[i].Countdown:GetText(),"")end
    h.Time(130);Refresh();Eq(f._classPowerPreviewInfo,initial);assert(not holder:GetScript("OnUpdate"))
    Select("ClassPowerBar");Refresh();assert(f._classPowerPreviewInfo~=initial);Timers(holder)
    for key,value in pairs({classPowerRuneTimerFont="fp:font:morpheus",classPowerRuneTimerFontSize=16,classPowerRuneTimerFontStyle="NONE"})do
        local previous=f._classPowerPreviewInfo;h.Time(150);f.config[key]=value;Refresh()
        assert(f._classPowerPreviewInfo~=previous);Timers(holder)
        local restarted=f._classPowerPreviewInfo;h.Time(150.1);Refresh();Eq(f._classPowerPreviewInfo,restarted)
        Eq(holder.Bars[4].Countdown:GetText(),"9.9")
    end
    NoFlashes(holder)
end)
Test("selection/detailed/live boundaries, placeholder and editor reentry",function()
    local f,holder=Setup("WARRIOR");ns.framesUnlocked=true;Select("ClassPowerBar");Refresh();Timers(holder)
    ns:ToggleTestMode();assert(not holder.segments);assert(not f._classPowerPreviewInfo)
    ns:ToggleTestMode();Timers(holder)
    ns.framesUnlocked=false;Refresh();assert(not holder:IsShown());assert(not f._classPowerPreviewInfo)
    ns.framesUnlocked=true;Refresh();Timers(holder)
    f.config.enabled=false -- player presence is unconditional; disabled editor units use placeholders
    Select(nil);Refresh();Eq(f.FocalPointDemoRuntime.mode,"placeholder");assert(holder:IsShown());assert(not holder.segments)
    Select("ClassPowerBar");Refresh();Timers(holder)
    f.config.enabled=true;ns.framesUnlocked=false;Refresh();assert(not holder:IsShown())
end)
Test("50 reuse cycles: both growth directions, alpha zero, combat, hide/clear, root and frame replacement",function()
    local f,holder=Setup("WARRIOR");ns.framesUnlocked=true;Select("ClassPowerBar")
    local original=h.Copy(f.config);local combat=InCombatLockdown;local bars={table.unpack(holder.Bars)}
    for cycle=1,50 do
        InCombatLockdown=function()return cycle%2==0 end
        f.config.classPowerBarGrowth=cycle%2==0 and "RIGHT_TO_LEFT" or "LEFT_TO_RIGHT"
        f.config.classPowerColor={.2,.3,.4,0};Select("ClassPowerBar");Refresh();Timers(holder)
        for i=1,6 do Eq(holder.Bars[i],bars[i]);Eq(holder.Bars[i].lastSetStatusBarColor[4],0)end
        holder:Hide();assert(not holder:GetScript("OnUpdate"));holder:Show();assert(holder:GetScript("OnUpdate"))
        C.Clear(f);assert(not f._classPowerPreviewInfo);assert(not holder:GetScript("OnUpdate"))
        Refresh();Timers(holder)
    end
    InCombatLockdown=combat
    local prior=f._classPowerPreviewInfo
    ns.ActiveLayoutResolver.InvalidateActiveRuntimeRoot();assert(ns.ActiveLayoutResolver.EnsureActiveRuntimeRoot(ns.db))
    Refresh();assert(f._classPowerPreviewInfo~=prior);Timers(holder)
    -- New frame models reopening/reload: no timer state or preview metadata is persisted.
    assert(not f.config._classPowerPreviewInfo);assert(not original._classPowerPreviewInfo)
    f,holder=Setup("DEATHKNIGHT");ns.framesUnlocked=true;Select("ClassPowerBar");Refresh();Timers(holder)
end)
Test("preview countdown hotpath has no media, DB, template, rune or refresh calls",function()
    local f,holder=Setup("WARRIOR");ns.framesUnlocked=true;Select("ClassPowerBar");Refresh()
    local tick=assert(holder:GetScript("OnUpdate"));local restore={}
    local function Block(owner,key)
        local old=owner[key];restore[#restore+1]=function()owner[key]=old end
        owner[key]=function()error("unexpected countdown call: "..key)end
    end
    Block(_G,"GetRuneCooldown");Block(ns.MediaRegistry,"ResolveReference");Block(ns.UnitFrameUtils,"GetUnitDB")
    Block(ns.TextTemplateResolver,"Resolve");Block(UF,"Refresh");Block(h.native,"SetFont")
    for i=1,600 do h.Time(100+i/100);tick(holder)end
    h.Time(111);tick(holder);assert(not holder:GetScript("OnUpdate"));NoFlashes(holder)
    for _,fn in ipairs(restore)do fn()end
end)

print("OK: class power preview ("..count.." groups)")
