-- Native alpha interpolation/event ordering remain an ingame smoke, not simulated here.
local function Read(path) local f=assert(io.open(path));local s=f:read("*a");f:close();return s end
local ns,MakeFrame,Options=assert(load(Read("Tests/CastBarSelectionPreview.lua")..
    "\nreturn ns,MakeFrame,Options","@Tests/CastBarSelectionPreview.lua"))()
local function Load(path)assert(load(Read(path),"@"..path))("FocalPoint",ns)end
Load("Engine/UnitFrame/Shared/UnitFrameUtils.lua")
Load("Engine/UnitFrame/Bars/UnitFrameCastBar.lua")
local C=ns.UnitFrameCastBar
local now,live,channel,reads=1.5,nil,nil,0
GetTime=function()return now end
local secret=setmetatable({},{__eq=function()error("secret comparison")end,__tostring=function()error("secret formatting")end})
issecretvalue=function(v)return rawequal(v,secret)end
UnitCastingInfo=function()
    reads=reads+1
    if live then return "Cast",nil,123,1000,3000,nil,secret,false,secret,live end
end
UnitChannelInfo=function()
    reads=reads+1
    if channel then return "Channel",nil,123,1000,3000,nil,false,secret,false,7,channel end
end
C_EventUtils={IsEventValid=function(e)return e=="UNIT_SPELLCAST_EMPOWER_START"end}
local function EventFrame()
    local f={scripts={},events={}}
    function f:SetScript(k,fn)self.scripts[k]=fn end
    function f:RegisterEvent(e)self.events[e]=true end
    return f
end
CreateFrame=EventFrame
local pending={}
ns.UnitFrameState={QueueRefresh=function(frame)pending[frame]=true end}
ns.UnitFrameRuntimeActivity.ShouldRunComponent=function(frame)return frame.present~=false and frame.config.showCastBar~=false end
Load("Engine/UnitFrame/Bars/UnitFrameCastRuntime.lua")
local R=ns.UnitFrameCastRuntime
local owner={RefreshCastBar=function(self,frame)R.Refresh(self,frame)end}
local function Flush()for f in pairs(pending)do pending[f]=nil;R.Refresh(owner,f)end end
local function Texture()
    local t={}
    function t:SetTexture(v)self.texture=v end
    function t:SetAllPoints(v)self.anchor=v end
    function t:SetVertexColor(...)self.color={...}end
    function t:SetAlpha(v)self.alpha=v end
    function t:Show()self.shown=true end
    function t:Hide()self.shown=false end
    function t:CreateAnimationGroup()
        local g={steps={},plays=0,scripts={}}
        function g:SetLooping(v)self.looping=v end
        function g:SetScript(k,fn)self.scripts[k]=fn end
        function g:Stop()self.playing=false end
        function g:Play()self.plays=self.plays+1;self.playing=true end
        function g:CreateAnimation(kind)
            local a={kind=kind};self.steps[#self.steps+1]=a
            function a:SetOrder(v)self.order=v end
            function a:SetDuration(v)self.duration=v end
            function a:SetFromAlpha(v)self.from=v end
            function a:SetToAlpha(v)self.to=v end
            return a
        end
        return g
    end
    return t
end
local function Fixture(config)
    ns.editorActive=false;ns.guiTestModeEnabled=false;ns.framesUnlocked=false
    live=42;channel=nil;now=1.5;pending={}
    local f=MakeFrame(config or {showCastBar=true});local b=f.Elements.CastBar
    f.visible=true;b.hooks={};b.textureCount=0
    function b:IsVisible()return self.shown and f.visible end
    function b:GetAlpha()return self.alpha or 1 end
    function b:GetEffectiveAlpha()return self:GetAlpha()*(f.alpha or 1)end
    function b:HookScript(k,fn)assert(not self.hooks[k]);self.hooks[k]=fn end
    function b:Hide()local was=self.shown;self.shown=false;if was and self.hooks.OnHide then self.hooks.OnHide()end end
    function b:CreateTexture(_,layer)assert(layer=="OVERLAY");self.textureCount=self.textureCount+1;return Texture()end
    function f:Hide()self.visible=false;b:Hide()end
    function f:Show()self.visible=true end
    R.RegisterEvents(owner,f);R.Refresh(owner,f)
    assert(b.isCasting and b.value==.5 and b.shown)
    local function Event(e,u,id)
        if u==nil then u=f._fpUnit end
        if id==nil then id=42 end
        if e=="UNIT_SPELLCAST_INTERRUPTED" then
            f.CastBarEventFrame.scripts.OnEvent(nil,e,u,secret,secret,secret,id)
        else f.CastBarEventFrame.scripts.OnEvent(nil,e,u,secret,secret,id)end
    end
    return f,b,Event
end
local count=0
local function Test(name,fn)fn();count=count+1;print("PASS: "..name)end
local function Flash(event,config)
    local f,b,e=Fixture(config);live=nil;e(event or "UNIT_SPELLCAST_INTERRUPTED")
    assert(b.endFlash and b.EndFlash.animation.plays==1 and b.value==.5 and b.shown)
    return f,b,e
end
Test("matching Interrupted and Failed freeze existing progress, queue and driver preserve it; 125 ms finish clears",function()
    for _,event in ipairs({"UNIT_SPELLCAST_INTERRUPTED","UNIT_SPELLCAST_FAILED"})do
        local f,b,e=Flash(event);local icon=b.icon.texture;local color=b.statusColor
        local before=reads;Flush();C.ApplyLayout(f,Options(f.config));C.Start(f)
        f.CastBarEventFrame.scripts.OnUpdate(f.CastBarEventFrame,.1)
        assert(reads==before and b.value==.5 and b.icon.texture==icon and b.statusColor==color)
        local a=b.EndFlash.animation;assert(a.steps[1].duration==.025 and a.steps[2].duration==.100)
        e(event);e("UNIT_SPELLCAST_STOP");Flush();assert(a.plays==1 and b.shown)
        a.scripts.OnFinished();assert(not b.endFlash and not b.shown and b.value==0 and not b.isCasting)
        assert(not b.icon.shown and not b.EndFlash.shown)
    end
end)
Test("STOP/success/unknown never trigger; stale, missing and secret identities or units rejected",function()
    for _,event in ipairs({"UNIT_SPELLCAST_STOP","UNIT_SPELLCAST_SUCCEEDED","UNKNOWN"})do
        local f,b,e=Fixture();live=nil;e(event);Flush();assert(not b.EndFlash and not b.shown)
    end
    for _,case in ipairs({{"player",42},{secret,42},{"target",41},{"target",secret},{"target",false}})do
        local f,b,e=Fixture();live=nil;e("UNIT_SPELLCAST_INTERRUPTED",case[1],case[2]);assert(not b.EndFlash)
    end
    for _,field in ipairs({"isPreview","isTextEditPreview"})do
        local f,b,e=Fixture();b[field]=true;live=nil;e("UNIT_SPELLCAST_FAILED");assert(not b.EndFlash)
    end
    local f,b,e=Fixture();b.castID=secret;live=nil;e("UNIT_SPELLCAST_FAILED");assert(not b.EndFlash)
    f.CastBarEventFrame.scripts.OnEvent(nil,"UNIT_SPELLCAST_FAILED","target",secret,secret,nil)
    assert(not b.EndFlash)
end)
Test("new cast in same queue invalidates old event and stale finish; valid new cast can flash",function()
    local f,b,e=Flash();local old=b.EndFlash.animation.scripts.OnFinished
    live=43;e("UNIT_SPELLCAST_START","target",43);e("UNIT_SPELLCAST_INTERRUPTED","target",42)
    assert(not b.endFlash);Flush();old();assert(b.shown and b.castID==43 and b.isCasting)
    live=nil;e("UNIT_SPELLCAST_FAILED","target",43);assert(b.EndFlash.animation.plays==2)
    old();assert(b.endFlash and b.shown);b.EndFlash.animation.scripts.OnFinished();assert(not b.shown)
end)
Test("configured/legacy/default overlay color and alpha, zero-alpha never made visible",function()
    for _,case in ipairs({{{castBarInterruptibleColor={.2,.4,.6,.5}},{.68,.76,.84,.5}},
        {{castBarUninterruptibleColor={.2,.4,.6,.5}},{.68,.76,.84,.5}},{{},{.84,.84,.84,1}}})do
        local f,b=Flash(nil,case[1]);for i,v in ipairs(case[2])do assert(math.abs(b.EndFlash.color[i]-v)<.00001)end
    end
    for _,cfg in ipairs({{castBarInterruptibleColor={1,0,0,0}},
        {castBarColor={1,0,0,0},castBarInterruptibleColor={1,1,1,1}}})do
        local f,b,e=Fixture(cfg);if cfg.castBarColor then C.ApplyStateColor(b,"PROTECTED",cfg.castBarColor)end
        live=nil;e("UNIT_SPELLCAST_INTERRUPTED");assert(not b.EndFlash)
    end
    local f,b,e=Fixture();f.alpha=0;live=nil;e("UNIT_SPELLCAST_FAILED");assert(not b.EndFlash)
end)
Test("channels/empower never flash and new channel/empower cancels tail",function()
    local f,b,e=Fixture();live=nil;channel=77;R.Refresh(owner,f);assert(b.isChannel)
    e("UNIT_SPELLCAST_INTERRUPTED","target",7);assert(not b.EndFlash)
    for _,event in ipairs({"UNIT_SPELLCAST_CHANNEL_START","UNIT_SPELLCAST_EMPOWER_START"})do
        f,b,e=Flash();local old=b.EndFlash.animation.scripts.OnFinished
        assert(f.CastBarEventFrame.events.UNIT_SPELLCAST_EMPOWER_START)
        live=nil;channel=77;e(event,"target",77);assert(not b.endFlash);Flush();old()
        e("UNIT_SPELLCAST_FAILED","target",77);assert(not b.endFlash)
    end
end)
Test("Hide/UnitWatch, clear, layout, presence, config, unit, spec, preview and demo discard tail",function()
    local actions={
        function(f,b,e)f:Hide()end,
        function(f,b,e)b:Hide()end,
        function(f)C.ClearVisuals(f)end,
        function(f)C.Stop(f)end,
        function(f)f.config={showCastBar=true};C.ApplyLayout(f,Options(f.config))end,
        function(f)f.present=false;R.Refresh(owner,f)end,
        function(f)f.alpha=0;f.CastBarEventFrame.scripts.OnUpdate(f.CastBarEventFrame,.02)end,
        function(f)f.config.enabled=false;R.Refresh(owner,f)end,
        function(f)f.config.showCastBar=false;R.Refresh(owner,f)end,
        function(f)f.config={};R.Refresh(owner,f)end,
        function(f)f._fpUnit="focus";R.Refresh(owner,f)end,
        function(f,b,e)e("PLAYER_TARGET_CHANGED")end,
        function(f,b,e)e("PLAYER_FOCUS_CHANGED")end,
        function(f,b,e)e("PLAYER_SPECIALIZATION_CHANGED","player")end,
        function(f,b,e)e("PLAYER_ENTERING_WORLD")end,
        function(f)ns.editorActive=true;R.Refresh(owner,f)end,
        function(f)ns.guiTestModeEnabled=true;R.Refresh(owner,f)end,
        function(f)ns.framesUnlocked=true;R.Refresh(owner,f)end,
        function(f)C.ApplyTextEditPreview(f)end,
        function(f)C.StartPreview(f)end,
    }
    for _,action in ipairs(actions)do
        local f,b,e=Flash();local old=b.EndFlash.animation.scripts.OnFinished
        action(f,b,e);assert(not b.endFlash and not b.EndFlash.shown)
        local shown,value=b.shown,b.value;old();assert(b.shown==shown and b.value==value)
    end
    for _,unit in ipairs({"focustarget","targettarget","pet"})do
        local f,b,e=Flash();f._fpUnit=unit
        e(unit=="pet" and "UNIT_PET" or "UNIT_TARGET",unit=="focustarget" and "focus" or unit=="pet" and "player" or "target")
        assert(not b.endFlash)
    end
end)
Test("50 reuse cycles including combat retain one overlay and reject old callbacks",function()
    local f,b,e=Fixture();local previous
    for i=1,50 do
        InCombatLockdown=function()return i%2==0 end
        live=100+i;e("UNIT_SPELLCAST_START","target",live);Flush()
        if previous then previous();assert(b.shown)end
        live=nil;e("UNIT_SPELLCAST_INTERRUPTED","target",100+i);assert(b.endFlash)
        previous=b.EndFlash.animation.scripts.OnFinished;previous()
        assert(not b.shown and not b.endFlash and not b.EndFlash.animation.playing)
        assert(b.textureCount==1)
    end
end)
print("Cast Bar End Flash: "..count.." groups PASS")
