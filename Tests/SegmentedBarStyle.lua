-- Instance-only presentation: real mutation/Inspector, media, renderer and transfer.
local function Read(path)local f=assert(io.open(path));local s=f:read("*a");f:close();return s end
local h=assert(load(Read("Tests/SegmentedBarSelection.lua")..
    "\nreturn {ns=ns,Setup=Setup,Add=Add,Context=Context,M=M,Copy=Copy,Equal=Equal,ui=ui,state=state,Select=Select,Nodes=Nodes,Build=BuildInspector}",
    "@SegmentedBarStyle/Inspector"))()
local ns,M,Equal=h.ns,h.M,h.Equal
local count=0
local function Test(name,fn)fn();count=count+1;print("PASS: "..name)end
local function Style()
    return {texture="fp:statusbar:raid-hp-fill",color={.2,.3,.4,0},background=false,backgroundColor={.5,.6,.7,0},
        spacing=4,growth="RIGHT_TO_LEFT",runeTimerFont="fp:font:morpheus",runeTimerFontSize=18,
        runeTimerFontStyle="THICKOUTLINE_MONOCHROME"}
end
local function Setup()
    local db,u=h.Setup();h.state.SetSingleSelection("player");h.state.ClearPropertyScope()
    local a,b=h.Add(),h.Add();h.Select(h.Nodes()[1]);return db,u,a,b
end
Test("strict style mutation is atomic, ID-local, detached and guarded",function()
    local db,u,a,b=Setup();local style=Style();local before=h.Copy(u.segmentedBars[2])
    assert(M.SetStyle(h.Context(),a,style).ok);Equal(u.segmentedBars[2],before)
    style.color[1]=1;assert(u.segmentedBars[1].color[1]==.2)
    for _,bad in ipairs({{texture=false},{texture=""},{runeTimerFont=12},{runeTimerFont=""},
        {background=1},{backgroundColor={1,1,1}},{backgroundColor={1,1,1,2}},
        {color={1,1,1,0,0}},{runeTimerFontSize=5},{runeTimerFontSize=33},{runeTimerFontSize=0/0},
        {runeTimerFontStyle="INVALID"},{spacing=-1},{spacing=math.huge},{growth="UP"},
        {width=100},{id=b},{dataSource={id="chi",scope="player"}},{snapshot={}}})do
        local saved=h.Copy(db);local root=u.segmentedBars
        assert(not M.SetStyle(h.Context(),a,bad).ok);Equal(db,saved);assert(u.segmentedBars==root)
    end
    local context=h.Context();assert(M.SetStyle(h.Context(),b,{spacing=3}).ok)
    assert(M.SetStyle(context,a,{spacing=1}).errorCode=="stale-context")
    local combat=InCombatLockdown;InCombatLockdown=function()return true end
    assert(M.SetStyle(h.Context(),a,{spacing=1}).errorCode=="combat-blocked");InCombatLockdown=combat
    local duplicate=M.Duplicate(h.Context(),a);assert(duplicate.ok)
    local expected=h.Copy(u.segmentedBars[1]);expected.id=duplicate.id;Equal(u.segmentedBars[2],expected)
    assert(u.segmentedBars[1].color~=u.segmentedBars[2].color)
    local payload=ns.LayoutService.CopyPayload({Units={player=u}})
    Equal(ns.LayoutService.MaterializeUnit({},payload.Units.player,"player").segmentedBars,u.segmentedBars)
    context=h.Context();db.char.activeLayoutId="builtin:default"
    ns.ActiveLayoutResolver.InvalidateActiveRuntimeRoot();assert(ns.ActiveLayoutResolver.EnsureActiveRuntimeRoot(db))
    assert(not M.CaptureContext("player"));assert(not M.SetStyle(context,a,{spacing=2}).ok)
end)
Test("Inspector controls isolate IDs, retain alpha zero and enable/disable without gameplay refresh",function()
    local db,u,a=Setup();local _,c,container=h.Build(true)
    for _,field in ipairs({"enabled","texture","color","background","backgroundColor","spacing","growth",
        "runeTimerFont","runeTimerFontSize","runeTimerFontStyle"})do assert(c[field],field)end
    local before=h.Copy(u.segmentedBars[2]);local api=GetRuneCooldown
    GetRuneCooldown=function()error("Inspector style queried runes")end
    c.texture:Fire("OnValueChanged","fp:statusbar:flat-white")
    c.color:Fire("OnValueChanged",.1,.2,.3,0)
    c.backgroundColor:Fire("OnValueConfirmed",.3,.2,.1,0)
    c.spacing:Fire("OnValueChanged",7);c.growth:Fire("OnValueChanged","RIGHT_TO_LEFT")
    c.runeTimerFont:Fire("OnValueChanged","fp:font:morpheus")
    c.runeTimerFontSize:Fire("OnValueChanged",23);c.runeTimerFontStyle:Fire("OnValueChanged","NONE")
    local r=u.segmentedBars[1];Equal(r.color,{.1,.2,.3,0});Equal(r.backgroundColor,{.3,.2,.1,0})
    assert(r.spacing==7 and r.growth=="RIGHT_TO_LEFT" and r.runeTimerFontSize==23 and r.runeTimerFontStyle=="NONE")
    c.background:Fire("OnValueChanged",false);assert(c.backgroundColor.disabled)
    c.background:Fire("OnValueChanged",true);assert(not c.backgroundColor.disabled)
    c.enabled:Fire("OnValueChanged",false);assert(not u.segmentedBars[1].enabled and c.color.disabled and not c.enabled.disabled)
    c.enabled:Fire("OnValueChanged",true);assert(u.segmentedBars[1].enabled and not c.color.disabled)
    c.color:Fire("OnValueChanged",.6,.7,.8,0);Equal(u.segmentedBars[1].color,{.6,.7,.8,0})
    local combat=InCombatLockdown;InCombatLockdown=function()return true end
    local saved=h.Copy(db);c.color:Fire("OnValueChanged",1,0,0,1);Equal(db,saved)
    assert(c.color.a==0 and c.color.r==.6);InCombatLockdown=combat
    Equal(u.segmentedBars[2],before);GetRuneCooldown=api
    h.Select(h.Nodes()[2]);h.Select(h.Nodes()[1]);saved=h.Copy(db)
    c.spacing:Fire("OnValueChanged",9);Equal(db,saved);h.ui.ace:Release(container)
    local _,fresh,nextContainer=h.Build(true);assert(fresh.spacing:GetValue()==7)
    local callback=fresh.color.events.OnValueChanged;h.ui.ace:Release(nextContainer)
    callback(fresh.color,"OnValueChanged",1,1,1,1);Equal(db,saved)
end)
Test("existing media browser applies to captured instance only; stale dialog cannot write",function()
    local db,u=Setup();local browser=ns.GUI.Editor.MediaLibrary;local request
    ns.GUI.Editor.MediaLibrary={Open=function(options)request=options end}
    local _,c,container=h.Build(true);assert(c.texture.type=="Button" and c.runeTimerFont.type=="Button")
    c.texture:Fire("OnClick");assert(request.mediaType=="statusbar" and request.defaultReference=="fp:statusbar:flat-white")
    request.onApply("fp:statusbar:raid-hp-fill");assert(u.segmentedBars[1].texture=="fp:statusbar:raid-hp-fill")
    c.runeTimerFont:Fire("OnClick");assert(request.mediaType=="font")
    request.onApply("fp:font:morpheus");assert(u.segmentedBars[1].runeTimerFont=="fp:font:morpheus")
    c.texture:Fire("OnClick");local apply=request.onApply
    h.Select(h.Nodes()[2]);h.Select(h.Nodes()[1]);local before=h.Copy(db)
    apply("fp:statusbar:flat-white");Equal(db,before)
    h.ui.ace:Release(container);ns.GUI.Editor.MediaLibrary=browser
end)

local r=assert(load(Read("Tests/SegmentedBarRuntime.lua")..
    "\nreturn {ns=ns,Setup=Setup,UF=UF,B=B,f=f,Holders=Holders}","@SegmentedBarStyle/Runtime"))()
ns=r.ns
ns.MediaRegistry=nil;r.f.Load("Services/MediaRegistry.lua")
r.f.Load("Engine/UnitFrame/Shared/UnitFrameAssets.lua")
local Eq=r.f.Eq
local function CheckFont(holder,path,size,flags)
    for _,bar in ipairs(holder.Bars)do
        local font,n,f=bar.Countdown:GetFont();Eq(font,path);Eq(n,size);Eq(f or "",flags)
        assert(bar.Countdown:GetParent()==bar and not bar.ReadyHighlight)
    end
end
local function ApplyStyle(record,style)for key,value in pairs(style)do record[key]=value end end
Test("two simultaneous styles share rune identity/timebase, with no Legacy changes",function()
    local frame,legacy=r.Setup();r.UF:Refresh(frame);local oldFont={legacy.Bars[2].Countdown:GetFont()}
    local legacyConfig=r.f.Copy(frame.config);legacyConfig.segmentedBars=nil
    local snapshot=frame.LiveValues.classPowerSnapshot
    ApplyStyle(frame.config.segmentedBars[1],Style())
    ApplyStyle(frame.config.segmentedBars[2],{texture="fp:statusbar:flat-white",color={.8,.7,.6,.5},background=true,
        backgroundColor={.1,.2,.3,.4},spacing=1,runeTimerFont="fp:font:standard",runeTimerFontSize=6,runeTimerFontStyle="NONE"})
    local api=GetRuneCooldown;GetRuneCooldown=function()error("style apply queried gameplay")end
    r.B.Apply(frame);local a,b=r.Holders(frame)
    assert(a.segments==snapshot.info.segments and b.segments==a.segments)
    local binding=assert(legacy._runeSlotBinding)
    Eq(binding.snapshot,snapshot)
    for slot=1,6 do Eq(legacy.segments[slot],a.segments[binding.slotToApi[slot]])end
    CheckFont(a,"Fonts\\MORPHEUS.ttf",18,"THICKOUTLINE,MONOCHROME")
    CheckFont(b,STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF",6,"")
    for i=1,6 do
        Equal(a.Bars[i].lastSetStatusBarColor,{.2,.3,.4,0});Equal(b.Bars[i].lastSetStatusBarColor,{.8,.7,.6,.5})
        Equal(a.Bars[i].bg.lastSetVertexColor,{.5,.6,.7,0});assert(not a.Bars[i].bg:IsShown())
        Equal(b.Bars[i].bg.lastSetVertexColor,{.1,.2,.3,.4});assert(b.Bars[i].bg:IsShown())
        Eq(a.Bars[i].bg.lastSetTexture[1],"Interface\\RaidFrame\\Raid-Bar-Hp-Fill")
        Eq(b.Bars[i].bg.lastSetTexture[1],"Interface\\Buttons\\WHITE8X8")
        Eq(a.Bars[i]:GetWidth(),(130-5*4)/6);Eq(b.Bars[i]:GetWidth(),(190-5)/6)
    end
    Equal({legacy.Bars[2].Countdown:GetFont()},oldFont)
    local after=r.f.Copy(frame.config);after.segmentedBars=nil;Equal(after,legacyConfig)
    local media=ns.MediaRegistry.ResolveReference;local font=r.f.native.SetFont
    ns.MediaRegistry.ResolveReference=function()error("media in tick")end
    r.f.native.SetFont=function()error("font write in tick")end
    local db=ns.UnitFrameUtils.GetUnitDB;ns.UnitFrameUtils.GetUnitDB=function()error("DB in tick")end
    r.f.Time(100.1);a:Run("OnUpdate");b:Run("OnUpdate")
    Eq(a.Bars[2].Countdown:GetText(),"4.9");Eq(b.Bars[2].Countdown:GetText(),"4.9")
    Eq(a.Bars[3].Countdown:GetText(),"7.9");Eq(b.Bars[3].Countdown:GetText(),"7.9")
    ns.MediaRegistry.ResolveReference=media;r.f.native.SetFont=font;ns.UnitFrameUtils.GetUnitDB=db;GetRuneCooldown=api
end)
Test("missing style defaults stay visual only, missing media falls back, invalid spacing hides safely",function()
    local frame=r.Setup();local records=frame.config.segmentedBars
    records[1]={id=records[1].id,enabled=true,dataSource={id="runes",scope="player"}}
    local before=r.f.Copy(records);r.UF:Refresh(frame);Equal(records,before)
    local a=r.Holders(frame);CheckFont(a,STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF",10,"OUTLINE")
    Equal(a.Bars[1].lastSetStatusBarColor,{1,1,1,1});Equal(a.Bars[1].bg.lastSetVertexColor,{0,0,0,.35})
    Eq(a.Bars[1].bg.lastSetTexture[1],"Interface\\Buttons\\WHITE8X8")
    records[1].texture="lsm:statusbar:not-installed";records[1].runeTimerFont="lsm:font:not-installed"
    r.B.Apply(frame);CheckFont(a,STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF",10,"OUTLINE")
    Eq(a.Bars[1].bg.lastSetTexture[1],"Interface\\TargetingFrame\\UI-StatusBar")
    records[1].spacing=100;r.B.Apply(frame);assert(not a:IsShown() and not a:GetScript("OnUpdate"))
    records[1].spacing=2;r.B.Apply(frame);assert(a:IsShown())
end)
Test("50 style/clear/hide/pool reuse cycles reset presentation and retain API-index timer ownership",function()
    local frame=r.Setup();r.UF:Refresh(frame);local a,b=r.Holders(frame)
    local widgets={table.unpack(a.Bars)};local snapshot=frame.LiveValues.classPowerSnapshot
    local api=GetRuneCooldown;GetRuneCooldown=function()error("reuse queried gameplay")end
    for cycle=1,50 do
        r.f.Time(100)
        local record={id="segmented-bar-a",enabled=true,dataSource={id="runes",scope="player"}}
        if cycle%2==0 then ApplyStyle(record,Style())end
        frame.config.segmentedBars={};r.B.Apply(frame)
        frame.config.segmentedBars={record};r.B.Apply(frame)
        local holder=frame._segmentedBars.byId[record.id];assert(holder==a or holder==b)
        assert(holder.segments==snapshot.info.segments)
        CheckFont(holder,cycle%2==0 and "Fonts\\MORPHEUS.ttf" or (STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF"),
            cycle%2==0 and 18 or 10,cycle%2==0 and "THICKOUTLINE,MONOCHROME" or "OUTLINE")
        local slots=ns.UnitFrameClassPower.GetRuneVisualSlots(holder.segments)
        for i,bar in ipairs(holder.Bars)do
            local point,owner,_,x=bar:GetPoint(1)
            Eq(owner,holder);Eq(point,cycle%2==0 and "TOPRIGHT" or "TOPLEFT")
            Eq(x,(cycle%2==0 and -1 or 1)*(slots[i]-1)*(bar:GetWidth()+(record.spacing or 2)))
            if holder==a then Eq(bar,widgets[i])end
        end
        Eq(holder.Bars[2].Countdown:GetText(),"5.0");Eq(holder.Bars[3].Countdown:GetText(),"8.0")
        holder:Hide();assert(not holder:GetScript("OnUpdate"));holder:Show();assert(holder:GetScript("OnUpdate"))
        r.B.Clear(frame);assert(not holder:GetScript("OnUpdate"));r.B.Apply(frame)
    end
    GetRuneCooldown=api
end)

local source=Read("Tests/SegmentedBarContract.lua");local boundary=assert(source:find('Test("pure validator',1,true))
local t=assert(load(source:sub(1,boundary-1)..
    "\nreturn {ns=ns,S=S,T=T,N=N,C=C,Records=Records,Layout=Layout,Target=Target,Generator=Generator,Copy=Copy,Equal=Equal}",
    "@SegmentedBarStyle/Transfer"))()
Test("all style fields roundtrip in vNext and legacy imports; validator rejects malformed styles everywhere",function()
    local records=t.Records();ApplyStyle(records[1],Style())
    local db,layout=t.Layout(records);t.ns.db=db;db.global.UserLayouts["layout:source"]=layout
    local encoded=assert(t.T.Export("layout:source"));local target=t.Target()
    local ok,id=t.T.Import(encoded);assert(ok,id);t.Equal(target.global.UserLayouts[id].payload.Units.player.segmentedBars,records)
    local legacy={transferSchema=1,formatVersion=1,addonVersion="old",name="Styled",
        payload={Units={player={segmentedBars=records,Texts={}}},TextTemplates={}}}
    target=t.Target();ok,id=t.T.Import(assert(t.C.Encode(legacy)),{generator=t.Generator()});assert(ok,id)
    t.Equal(target.global.UserLayouts[id].payload.Units.player.segmentedBars,records)
    for _,bad in ipairs({{runeTimerFontSize=33},{background="yes"},{backgroundColor={1,1,1,-1}},{texture={}}})do
        local invalid=t.Copy(records);ApplyStyle(invalid[1],bad)
        local badDB,badLayout=t.Layout(invalid);local before=t.Copy(badDB)
        assert(not t.S.ValidateSegmentedBars(invalid,"player"));assert(not pcall(t.S.CopyPayload,badLayout.payload))
        assert(not t.N.Export(badLayout,badDB))
        local document={transferSchema=2,formatVersion=2,addonVersion="test",name="Invalid",payload=badLayout.payload,templates={}}
        target=t.Target();local saved=t.Copy(target)
        assert(not t.N.PrepareImport(assert(t.C.Encode(document)),target).ready)
        legacy.payload.Units.player.segmentedBars=invalid
        assert(not t.N.PrepareLegacyImport(assert(t.C.Encode(legacy)),target,t.Generator()).ready)
        t.Equal(target,saved);t.Equal(badDB,before)
    end
end)
print("Segmented Bar Style: "..count.." groups PASS")
