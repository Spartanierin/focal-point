-- lua54 Tests/ClassPowerRuneTimerStyle.lua
-- Real media, flags, renderer, mutation and transfer. Native font legibility needs ingame smoke.
local function Read(path)
    local f=assert(io.open(path));local s=f:read("*a");f:close();return s
end
local h=assert(load(Read("Tests/ClassPowerRunes.lua")..[[
return {ns=ns,Load=Load,f=f,native=native,Apply=Apply,Defaults=Defaults,Frame=Frame,
    HighlightCase=HighlightCase,Plays=Plays,Quiet=Quiet,Eq=Eq,Equal=Equal,Copy=Copy,
    Runes=function()return cooldowns end,Time=function(value)now=value end}
]],"@RuneStyle/Fixture"))()
local ns,C=h.ns,h.ns.UnitFrameClassPower
local Eq,Equal,Apply=h.Eq,h.Equal,h.Apply
ns.MediaRegistry=nil;h.Load("Services/MediaRegistry.lua") -- replace GUI fixture's media double
h.Load("GUI/Editor/Inspector/InspectorRefreshPolicy.lua")
local fields={"classPowerRuneTimerFont","classPowerRuneTimerFontSize","classPowerRuneTimerFontStyle"}
local custom={"fp:font:morpheus",14,"THICKOUTLINE_MONOCHROME"}
local standard=STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF"
local function SetStyle(frame,values)
    for i,key in ipairs(fields)do frame.config[key]=values[i]end
end
local function Style(holder,font,size,flags)
    for _,bar in ipairs(holder.Bars)do
        local text=assert(bar.Countdown);local path,actualSize,actualFlags=text:GetFont()
        Eq(path,font);Eq(actualSize,size);Eq(actualFlags or "",flags)
        Equal(text.lastSetTextColor,{1,1,1,1});Eq(text:GetParent(),bar)
    end
end
local count=0
local function Test(name,fn)fn();count=count+1;print("PASS: "..name)end
Test("missing/default styles, independent values, no text entity, unchanged bar alpha",function()
    h.Defaults();local frame=h.Frame();frame.config.Texts={};SetStyle(frame,{})
    local _,holder=Apply(frame,false,{.2,.3,.4,0});Style(holder,standard,10,"OUTLINE")
    Eq(holder.Bars[2].Countdown:GetText(),"5.0");Eq(holder.Bars[3].Countdown:GetText(),"8.0")
    Eq(holder.Bars[6].Countdown:GetText(),"7.0");assert(not next(frame.Texts))
    for i=1,6 do Equal(holder.Bars[i].lastSetStatusBarColor,{.2,.3,.4,0})end
    local before=h.Copy(frame.config);Apply(frame);Equal(frame.config,before)
end)
Test("real media/all font flags, live changes, no redundant SetFont, default return",function()
    h.Defaults();local frame=h.Frame();Apply(frame)
    for style,expected in pairs({NONE="",OUTLINE="OUTLINE",THICKOUTLINE="THICKOUTLINE",MONOCHROME="MONOCHROME",
        OUTLINE_MONOCHROME="OUTLINE,MONOCHROME",THICKOUTLINE_MONOCHROME="THICKOUTLINE,MONOCHROME"})do
        SetStyle(frame,{custom[1],14,style});local _,holder=Apply(frame)
        Style(holder,"Fonts\\MORPHEUS.ttf",14,expected);Eq(holder.Bars[2].Countdown:GetText(),"5.0")
        local original=h.native.SetFont;local writes=0
        h.native.SetFont=function(self,...)writes=writes+1;return original(self,...)end
        Apply(frame);Eq(writes,0);h.native.SetFont=original
    end
    SetStyle(frame,{});local _,holder=Apply(frame);Style(holder,standard,10,"OUTLINE")
end)
Test("invalid references/sizes/styles, unavailable media and native font failures recover",function()
    h.Defaults();local frame=h.Frame()
    for _,values in ipairs({{"fp:font:missing",0,"bad"},{false,"12",false},{"lsm:font:absent",math.huge,{}},
        {"",0/0,""},{42,-1,42},{"fp:font:standard",33,"bad"}})do
        SetStyle(frame,values);local _,holder=Apply(frame);Style(holder,standard,10,"OUTLINE")
    end
    local original=h.native.SetFont
    for _,throws in ipairs({false,true})do
        SetStyle(frame,custom)
        h.native.SetFont=function(self,font,...)
            if font=="Fonts\\MORPHEUS.ttf" then if throws then error("font rejected")end;return false end
            return original(self,font,...)
        end
        local _,holder=Apply(frame);Style(holder,standard,14,"THICKOUTLINE,MONOCHROME")
    end
    h.native.SetFont=original
    local media=ns.MediaRegistry;ns.MediaRegistry=nil
    SetStyle(frame,custom);local _,holder=Apply(frame);Style(holder,standard,14,"THICKOUTLINE,MONOCHROME")
    ns.MediaRegistry=media
    local standardGlobal=STANDARD_TEXT_FONT;STANDARD_TEXT_FONT=nil;SetStyle(frame,{})
    Apply(frame);Style(holder,"Fonts\\FRIZQT__.TTF",10,"OUTLINE");STANDARD_TEXT_FONT=standardGlobal
end)
Test("600 countdown ticks/Show: no media, flags, font writes, DB, template, tag or rune API",function()
    h.Defaults();local frame=h.Frame();SetStyle(frame,custom)
    local _,holder=Apply(frame);local tick=assert(holder:GetScript("OnUpdate"));local restore={}
    local function Block(owner,key)
        local old=owner[key];restore[#restore+1]=function()owner[key]=old end
        owner[key]=function()error("unexpected hotpath call: "..key)end
    end
    Block(ns.MediaRegistry,"ResolveReference");Block(ns.TextElementUtils,"BuildFontFlags")
    Block(ns.UnitFrameUtils,"GetUnitDB");Block(ns.TextTemplateResolver,"Resolve")
    Block(ns.UnitFrame,"UpdateTextElements");Block(ns.TextElementTokenResolver,"Resolve")
    Block(_G,"GetRuneCooldown");Block(h.native,"SetFont")
    local before=h.Copy(holder.segments)
    for i=1,600 do h.Time(100+i/100);tick(holder)end
    holder:Hide();holder:Show();Style(holder,"Fonts\\MORPHEUS.ttf",14,"THICKOUTLINE,MONOCHROME")
    h.Time(120);tick(holder);assert(not holder:GetScript("OnUpdate"));Equal(holder.segments,before)
    for _,restoreCall in ipairs(restore)do restoreCall()end
end)
Test("50 style/layout/clear/hide cycles, LTR/RTL, combat, API identity and ready flash",function()
    local combat=InCombatLockdown
    for _,direction in ipairs({"LEFT_TO_RIGHT","RIGHT_TO_LEFT"})do
        h.HighlightCase(function(frame,holder,event)
            local bars={table.unpack(holder.Bars)};frame.config.classPowerBarGrowth=direction
            for cycle=1,50 do
                InCombatLockdown=function()return cycle%2==0 end
                ns.db.char.activeLayoutId="layout:style-"..cycle
                h.Runes()[3]={98,10,false};C.Clear(frame)
                local values=cycle%2==0 and {} or custom;SetStyle(frame,values);Apply(frame)
                Style(holder,values[1] and "Fonts\\MORPHEUS.ttf" or standard,values[2] or 10,
                    values[3] and "THICKOUTLINE,MONOCHROME" or "OUTLINE")
                local plays=h.Plays(holder,3);h.Runes()[3]={0,0,true};event("RUNE_POWER_UPDATE");Apply(frame)
                Eq(h.Plays(holder,3),plays+1);Eq(holder.Bars[3].Countdown:GetText(),"")
                for i=1,6 do Eq(holder.Bars[i],bars[i]);Eq(holder.segments[i].index,i)end
                local flash=assert(holder.Bars[3].ReadyHighlight);assert(flash.animation.playing)
                SetStyle(frame,custom);Apply(frame);Eq(h.Plays(holder,3),plays+1)
                assert(flash.animation.playing);Eq(flash,holder.Bars[3].ReadyHighlight)
                holder:Hide();assert(not holder:GetScript("OnUpdate"));holder:Show()
                C.Clear(frame);h.Quiet(holder)
            end
        end)
    end
    InCombatLockdown=combat
end)
Test("Demo/placeholder/selection preview, ready-only style change and fresh-frame reload",function()
    h.Defaults();local frame=h.Frame();SetStyle(frame,custom)
    local api=GetRuneCooldown;GetRuneCooldown=function()error("demo queried runes")end
    ns.guiTestModeEnabled=true
    ns.UnitFrameDemoEnvironment.ApplyFrameSnapshot(nil,frame,{},"detailed","style")
    local _,holder=Apply(frame);Style(holder,"Fonts\\MORPHEUS.ttf",14,"THICKOUTLINE,MONOCHROME")
    GetRuneCooldown=api;ns.guiTestModeEnabled=false;ns.framesUnlocked=false
    ns.UnitFrameDemoEnvironment.ApplyFrameSnapshot(nil,frame,{},"live","style");Apply(frame)
    ns.framesUnlocked=true;ns.UnitFrameDemoEnvironment.ApplyFrameSnapshot(nil,frame,{},"placeholder","style")
    Apply(frame);Style(holder,"Fonts\\MORPHEUS.ttf",14,"THICKOUTLINE,MONOCHROME")
    ns.framesUnlocked=false;ns.UnitFrameDemoEnvironment.ApplyFrameSnapshot(nil,frame,{},"live","style")
    for i=1,6 do h.Runes()[i]={0,0,true}end
    SetStyle(frame,{custom[1],18,"NONE"});Apply(frame);Style(holder,"Fonts\\MORPHEUS.ttf",18,"")
    assert(not holder:GetScript("OnUpdate"))
    h.Runes()[2]={99,10,false};Apply(frame);Eq(holder.Bars[2].Countdown:GetText(),"9.0")
    local saved=h.Copy(frame.config);local fresh=h.Frame();fresh.config=saved;Apply(fresh)
    Style(fresh.Elements.ClassPowerBar,"Fonts\\MORPHEUS.ttf",18,"");assert(fresh.Elements.ClassPowerBar~=holder)
    local force=C.ShouldForcePreview;C.ShouldForcePreview=function()return true end
    GetRuneCooldown=nil;Apply(fresh);C.ShouldForcePreview=force;GetRuneCooldown=api
    assert(fresh._classPowerPreviewInfo and fresh.Elements.ClassPowerBar:GetScript("OnUpdate"))
    Style(fresh.Elements.ClassPowerBar,"Fonts\\MORPHEUS.ttf",18,"")
end)
Test("defaults, Built-ins, create/copy, sparse legacy and transfer preserve plain fields",function()
    h.Load("Services/LayoutTransferCodec.lua");h.Load("Services/LayoutTransfer.lua");h.Load("Services/LayoutTransferVNext.lua")
    local expected={"fp:font:standard",10,"OUTLINE"}
    local function Values(unit)return {unit[fields[1]],unit[fields[2]],unit[fields[3]]}end
    Equal(Values(ns:GetDefaultDB().profile.Units.player),expected)
    local create=assert(h.f.Upvalue(ns.CreateBlankLayout,"BuildNewLayoutPayload"))
    Equal(Values(create(ns).Units.player),expected)
    ns.db={profile={General={}},char={activeLayoutId="builtin:default"},global={TextTemplates={},UserLayouts={}}}
    for _,key in ipairs({"default","classic","minimal","modern"})do
        Equal(Values(ns.PresetService.GetPreset(key).layout.Units.player),expected)
        local ok,id=ns.LayoutMutations.CopyLayout("builtin:"..key,"Timer "..key);assert(ok,id)
        Equal(Values(ns.db.global.UserLayouts[id].payload.Units.player),expected)
    end
    for case,values in ipairs({{},custom})do
        local unit={Texts={}};for i,key in ipairs(fields)do unit[key]=values[i]end
        local record={name="Timer "..case,formatVersion=2,payload={Units={player=unit}}}
        ns.db.global.UserLayouts["layout:style"]=record;local before=h.Copy(record)
        local ok,id=ns.LayoutMutations.CopyLayout("layout:style","Timer copy "..case);assert(ok,id)
        Equal(Values(ns.db.global.UserLayouts[id].payload.Units.player),case==1 and expected or custom)
        local text=assert(ns.LayoutTransferVNext.Export(record,ns.db))
        local prepared=ns.LayoutTransferVNext.PrepareImport(text,{global={TextTemplates={},UserLayouts={}}})
        assert(prepared.ready);Equal(prepared.preparedLayout.payload,record.payload);Equal(record,before)
    end
end)
Test("full UnitFrame ApplyConfig forwards all three values without source mutation",function()
    local source=Read("Tests/UnitFrameGeometry.lua");local stop=assert(source:find("local fixtures={",1,true))
    local runtime,Applied=assert(load(source:sub(1,stop-1).."\nreturn ns,Applied","@RuneStyle/ApplyConfig"))()
    local captured
    for i=1,100 do
        local name=debug.getupvalue(runtime.UnitFrame.ApplyConfig,i);if not name then break end
        if name=="ApplyClassPowerLayout" then debug.setupvalue(runtime.UnitFrame.ApplyConfig,i,function(_,options)captured=options end);break end
    end
    for _,values in ipairs({{},custom})do
        local config={};for i,key in ipairs(fields)do config[key]=values[i]end
        local before=h.Copy(config);Applied(runtime,config,"player",false);assert(captured)
        for i,key in ipairs(fields)do Eq(captured[key],values[i])end
        Equal(config,before)
    end
end)
Test("Inspector scoped/fallback controls use unit mutations, media browser and live refresh",function()
    local source=Read("GUI/Editor/Inspector/InspectorController.lua")
    local a=assert(source:find('        runeTimerSection = runeTimerSection or',1,true))
    local b=assert(source:find('        local classPowerGrowth =',a,true))
    for _,scoped in ipairs({false,true})do
        local config={showClassPowerBar=true,Texts={}};local group={};local controls,opened,browse,refreshes
        refreshes=0
        local function Control(label,value,callback,disabled)
            local control={value=value,callback=callback,disabled=disabled}
            control._fpSetPropertyValueText=function(text)control.value=text end
            controls[label]=control;return control
        end
        local function Dropdown(parent,label,list,value,callback,disabled)
            Eq(parent,group);return Control(label,value,callback,disabled)
        end
        local function Slider(parent,label,min,max,step,value,callback,disabled)
            Eq(parent,group);Eq(min,6);Eq(max,32);Eq(step,1)
            return Control(label,value,callback,disabled)
        end
        local env=setmetatable({unitConfig=config,usePropertyGroups=scoped,L={},rootSection={},
            DEFAULT_FONT_REFERENCE="fp:font:standard",MEDIA_TYPE_FONT="font",fontStyleList={OUTLINE="Outline",NONE="None"},
            AddFramedObjectPropertyGroup=function(_,title)Eq(title,"Rune Timer");return group end,
            BuildFontOptions=function(value)return {value=value}end,
            ResolveOptionValueLabel=function(_,value)return value end,
            IsMediaBrowserAvailable=function()return true end,
            OpenMediaBrowserForField=function(options)opened=options end,
            AddMediaBrowserForField=function(parent,kind,current,fallback,title,disabled,onApply)
                Eq(parent,group);browse={mediaType=kind,currentValue=current,fallbackReference=fallback,onApply=onApply,disabled=disabled}
            end,
            AddPropertyPickerValueRow=function(parent,label,value,onClick,disabled)
                Eq(parent,group);return Control(label,value,onClick,disabled)
            end,
            AddPropertyDropdownRow=function(parent,label,options,disabled)
                return Dropdown(parent,label,options.list,options.value,options.onChanged,disabled)
            end,
            AddDropdown=Dropdown,AddSlider=Slider,AddPropertyCompactSliderRow=Slider,
            SyncDropdownToStoredValue=function(control,value)control.value=value end,
            SetUnitField=function(key,value)
                local result=ns.InspectorMutations.SetUnitField({unitConfig=config},key,value)
                assert(result.ok and result.changed)
                Eq(ns.InspectorRefreshPolicy.Resolve("unit",key).scope,"live")
                refreshes=refreshes+1;return result
            end}, {__index=_G})
        local build=assert(load(source:sub(a,b-1),"@RuneStyle/Inspector","t",env))
        local function Render()controls={};build()end
        Render();Eq(controls.Font.value,"fp:font:standard");Eq(controls["Font Size"].value,10)
        Eq(controls["Font Outline"].value,"OUTLINE");assert(not controls.Font.disabled)
        if scoped then controls.Font.callback()else opened=browse end
        Eq(opened.mediaType,"font");Eq(opened.currentValue(),"fp:font:standard")
        Eq(opened.fallbackReference,"fp:font:standard");opened.onApply(custom[1])
        Eq(controls.Font.value,custom[1]);controls["Font Size"].callback(14)
        controls["Font Outline"].callback("NONE");Render()
        Eq(config.classPowerRuneTimerFont,custom[1]);Eq(controls["Font Size"].value,14)
        Eq(controls["Font Outline"].value,"NONE");Eq(refreshes,3);assert(not next(config.Texts))
        config.showClassPowerBar=false;Render()
        for _,control in pairs(controls)do assert(control.disabled)end
        if not scoped then assert(browse.disabled)end
        config.showClassPowerBar=true;Render();assert(not controls.Font.disabled)
    end
    local locale={};assert(loadfile("Locales/enUS.lua"))("FocalPoint",locale)
    Eq(locale.L.SECTION_RUNE_TIMER,"Rune Timer");Eq(locale.L.OPTION_FONT_OUTLINE,"Outline")
    local old=GetLocale;GetLocale=function()return "deDE"end
    assert(loadfile("Locales/deDE.lua"))("FocalPoint",locale);GetLocale=old
    Eq(locale.L.SECTION_RUNE_TIMER,"Runen-Timer");Eq(locale.L.OPTION_FONT_OUTLINE,"Kontur")
end)
assert(#h.f.env.errors==0,table.concat(h.f.env.errors,"\n"))
print("Class Power Rune Timer Style: "..count.." groups PASS")
