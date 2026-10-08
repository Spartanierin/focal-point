-- lua54 Tests/ClassPowerSegmentGrowth.lua
-- Real provider/renderer/mutations/transfer; native visuals remain an ingame check.
local function Read(path)
    local file=assert(io.open(path));local text=file:read("*a");file:close();return text
end
local h=assert(load(Read("Tests/ClassPowerRunes.lua")..[[
return {ns=ns,Load=Load,f=f,native=native,Apply=Apply,Defaults=Defaults,Frame=Frame,
    HighlightCase=HighlightCase,ComboCase=ComboCase,AggregateCase=AggregateCase,resources=resources,
    Plays=Plays,Quiet=Quiet,Eq=Eq,Equal=Equal,Near=Near,Copy=Copy,
    Runes=function()return cooldowns end,Spec=function(value)spec=value end,
    Advance=function()now=now+1 end}
]],"@Growth/RunesFixture"))()
local ns,C=h.ns,h.ns.UnitFrameClassPower
local Eq,Equal,Near,Apply,Plays,Quiet=h.Eq,h.Equal,h.Near,h.Apply,h.Plays,h.Quiet
local count=0
local function Test(name,fn)fn();count=count+1;print("PASS: "..name)end
local directions={"LEFT_TO_RIGHT","RIGHT_TO_LEFT"}
-- Resolve the actual native anchor chain in holder-local coordinates.
local function Left(bar,holder)
    if bar==holder then return 0 end
    local point,relative,relativePoint,x=bar:GetPoint(1)
    assert(point and relative and bar:GetNumPoints()==1)
    local result=Left(relative,holder)+x
    if relativePoint:find("RIGHT",1,true) then result=result+relative:GetWidth() end
    if point:find("RIGHT",1,true) then result=result-bar:GetWidth() end
    return result
end
local function RuneOrder(holder,direction)
    local width=(holder:GetWidth()-5*2)/6
    local order={}
    for index=1,6 do
        local x=Left(holder.Bars[index],holder)
        local physical=math.floor(x/(width+2)+.5)
        Near(x,physical*(width+2))
        assert(physical>=0 and physical<6)
        local slot=direction=="RIGHT_TO_LEFT" and 6-physical or physical+1
        assert(not order[slot],"overlapping rune slots")
        order[slot]=index
    end
    return order
end
local function Positions(holder,n,direction)
    local width=(holder:GetWidth()-(n-1)*2)/n
    local runeOrder=holder.segments and RuneOrder(holder,direction)
    local previousGroup,previousEnd,previousIndex=0,0,0
    if runeOrder then
        for _,index in ipairs(runeOrder)do
            local s=holder.segments[index]
            local group=s.ready and 1 or (s.startTime and 2 or 3)
            local ending=group==2 and s.startTime+s.duration or 0
            assert(group>=previousGroup,"ready/recharge/spent grouping")
            if group==previousGroup then
                assert(ending>=previousEnd,"earliest completion first")
                if ending==previousEnd then assert(index>previousIndex,"stable API tie-breaker")end
            end
            previousGroup,previousEnd,previousIndex=group,ending,index
        end
    end
    for i=1,n do
        local bar=holder.Bars[i];assert(bar:IsShown())
        local slot=direction=="RIGHT_TO_LEFT" and n-i or i-1
        if not runeOrder then Near(Left(bar,holder),slot*(width+2))end
        Near(bar:GetWidth(),width)
        assert(not bar.lastSetReverseFill and not bar.lastSetOrientation)
    end
    for i=n+1,#holder.Bars do assert(not holder.Bars[i]:IsShown())end
end
Test("aggregate 0..max, fractional fill and gains keep logical indices in both directions",function()
    local function Check(frame,holder,v,event,gain,token)
        v.max=6
        for _,direction in ipairs(directions)do
            frame.config.classPowerBarGrowth=direction;v.current=0;Apply(frame)
            for value=0,6 do
                v.current=value;gain();Positions(holder,6,direction)
                for i=1,6 do Eq(holder.Bars[i]:GetValue(),i<=value and 1 or 0)end
                if value==3 and direction=="RIGHT_TO_LEFT" then
                    for i=1,3 do assert(Left(holder.Bars[i],holder)>=holder:GetWidth()/2)end
                end
            end
            v.current=2;gain();local p3,p4=Plays(holder,3),Plays(holder,4)
            v.current=4;gain();Eq(Plays(holder,3),p3+1);Eq(Plays(holder,4),p4+1)
            v.current=2.9;gain();Near(holder.Bars[3]:GetValue(),.9)
            p3=Plays(holder,3);v.current=3;gain();Eq(Plays(holder,3),p3+1)
            Positions(holder,6,direction)
        end
    end
    h.ComboCase(Check)
    for _,resource in ipairs(h.resources)do h.AggregateCase(resource,Check)end
end)
Test("all DK specs group visual slots while preserving six API identities, timers and flashes",function()
    for spec=1,3 do
        h.HighlightCase(function(frame,holder,event)
            h.Spec(spec)
            local bars={table.unpack(holder.Bars)}
            for _,direction in ipairs(directions)do
                frame.config.classPowerBarGrowth=direction;Apply(frame);Positions(holder,6,direction)
                for i=1,6 do Eq(holder.Bars[i],bars[i]);Eq(holder.segments[i].index,i)end
                Eq(bars[1]:GetValue(),1);Eq(bars[5]:GetValue(),1)
                Near(bars[2]:GetValue(),.5);Eq(bars[2].Countdown:GetText(),"5.0")
                Near(bars[3]:GetValue(),.2);Eq(bars[3].Countdown:GetText(),"8.0")
                Eq(bars[4]:GetValue(),0);Eq(bars[4].Countdown:GetText(),"")
                Near(bars[6]:GetValue(),1/8);Eq(bars[6].Countdown:GetText(),"7.0")
                for i=1,6 do Eq(Plays(holder,i),0)end
            end
            h.Runes()[3]={0,0,true};event("RUNE_POWER_UPDATE");Apply(frame)
            Eq(Plays(holder,3),1);Eq(Plays(holder,2),0);Eq(bars[3].Countdown:GetText(),"")
            Positions(holder,6,"RIGHT_TO_LEFT")
        end)
    end
end)
Test("DK 0..6 ready, sparse indices, both growth sides and immutable snapshots",function()
    h.HighlightCase(function(frame,holder)
        local sequence={6,2,5,1,4,3}
        local bars={table.unpack(holder.Bars)}
        for _,direction in ipairs(directions)do
            frame.config.classPowerBarGrowth=direction
            for ready=0,6 do
                for i=1,6 do h.Runes()[i]={nil,nil,false}end
                for i=1,ready do h.Runes()[sequence[i]]={0,0,true}end
                local info=Apply(frame);local snapshot=h.Copy(info.segments)
                Positions(holder,6,direction)
                local order=RuneOrder(holder,direction)
                for slot,index in ipairs(order)do
                    Eq(info.segments[index].ready,slot<=ready)
                    Eq(holder.Bars[index],bars[index]);Eq(info.segments[index].index,index)
                    Eq(bars[index].Countdown:GetText(),"");Eq(Plays(holder,index),0)
                end
                local before=h.Copy(ns.db);Apply(frame)
                Equal(snapshot,info.segments);Equal(before,ns.db)
            end
        end
    end)
end)
Test("DK completion time beats start time; ready, recharge and spent ties use API index",function()
    h.HighlightCase(function(frame,holder)
        local runes=h.Runes()
        runes[1]={95,20,false};runes[2]={99,3,false};runes[3]={0,0,true}
        runes[4]={90,12,false};runes[5]={nil,nil,false};runes[6]={0,0,true}
        for _,direction in ipairs(directions)do
            frame.config.classPowerBarGrowth=direction;Apply(frame)
            Equal(RuneOrder(holder,direction),{3,6,2,4,1,5})
            Eq(holder.Bars[1].Countdown:GetText(),"15.0")
            Eq(holder.Bars[2].Countdown:GetText(),"2.0");Eq(holder.Bars[4].Countdown:GetText(),"2.0")
            Eq(holder.Bars[5].Countdown:GetText(),"")
            -- No reordering/anchoring from a countdown tick, even across expiry.
            local setPoint,clear=h.native.SetPoint,h.native.ClearAllPoints
            h.native.SetPoint=function()error("anchor mutation in countdown tick")end
            h.native.ClearAllPoints=function()error("anchor clear in countdown tick")end
            for i=1,4 do h.Advance();holder:GetScript("OnUpdate")(holder)end
            h.native.SetPoint,h.native.ClearAllPoints=setPoint,clear
            Equal(RuneOrder(holder,direction),{3,6,2,4,1,5})
            -- Reset fixture time for the mirrored case without replacing widgets.
            h.Defaults();runes=h.Runes()
            runes[1]={95,20,false};runes[2]={99,3,false};runes[3]={0,0,true}
            runes[4]={90,12,false};runes[5]={nil,nil,false};runes[6]={0,0,true}
        end
        runes[2]={0,0,false};Apply(frame)
        Equal(RuneOrder(holder,"RIGHT_TO_LEFT"),{3,6,4,1,2,5})
    end)
end)

Test("growth mutation on the same config cancels pending and active DK/aggregate flashes",function()
    local function Check(frame,holder,queueReady,spend)
        local config=frame.config
        queueReady();frame.config.classPowerBarGrowth="RIGHT_TO_LEFT";Apply(frame)
        Eq(frame.config,config);Eq(Plays(holder,3),0);Quiet(holder)
        Eq(holder._readyTransitions.growth,"RIGHT_TO_LEFT")
        spend();Apply(frame);queueReady();Apply(frame);Eq(Plays(holder,3),1)
        local texture=holder.Bars[3].ReadyHighlight
        frame.config.classPowerBarGrowth="LEFT_TO_RIGHT";Apply(frame);Quiet(holder)
        Eq(Plays(holder,3),1);Eq(holder.Bars[3].ReadyHighlight,texture)
        -- An event from before another change cannot be carried into a later snapshot.
        spend();Apply(frame);queueReady();frame.config.classPowerBarGrowth="RIGHT_TO_LEFT"
        C.RefreshValues(ns.UnitFrame,frame);Eq(Plays(holder,3),1);Quiet(holder)
    end
    h.HighlightCase(function(frame,holder,event)
        Check(frame,holder,function()h.Runes()[3]={0,0,true};event("RUNE_POWER_UPDATE")end,
            function()h.Runes()[3]={98,10,false}end)
    end)
    local function Aggregate(frame,holder,v,event)
        local token=assert(holder._readyTransitions.token)
        Check(frame,holder,function()v.current=3;event("UNIT_POWER_UPDATE","player",token)end,function()v.current=2 end)
    end
    h.ComboCase(Aggregate)
    for _,resource in ipairs(h.resources)do h.AggregateCase(resource,Aggregate)end
end)
Test("missing/invalid growth preserves legacy anchors and normalized highlight context",function()
    h.ComboCase(function(frame,holder,v,event,gain)
        for _,value in ipairs({false,"invalid",1,"LEFT_TO_RIGHT"})do
            frame.config.classPowerBarGrowth=value;Apply(frame);Positions(holder,5,"LEFT_TO_RIGHT")
            Eq(holder._readyTransitions.growth,"LEFT_TO_RIGHT")
        end
        frame.config.classPowerBarGrowth=nil;Apply(frame);Positions(holder,5,"LEFT_TO_RIGHT")
        v.current=3;gain();Eq(Plays(holder,3),1)
    end)
end)
Test("50 mirrored clear/hide/layout/spec/combat/reuse cycles retain widgets and fresh baselines",function()
    h.HighlightCase(function(frame,holder,event)
        frame.config.classPowerBarGrowth="RIGHT_TO_LEFT";Apply(frame)
        local bars={table.unpack(holder.Bars)};local texts={};for i=1,6 do texts[i]=bars[i].Countdown end
        local hook=h.native.HookScript;h.native.HookScript=function()error("new lifecycle hook")end
        local combat=InCombatLockdown
        for cycle=1,50 do
            local direction=directions[cycle%2+1]
            frame.config.classPowerBarGrowth=direction;h.Runes()[3]={98,10,false};Apply(frame)
            local before=Plays(holder,3)
            h.Runes()[3]={0,0,true};event("RUNE_POWER_UPDATE");Apply(frame);Eq(Plays(holder,3),before+1)
            local texture=bars[3].ReadyHighlight
            if cycle%4==0 then C.Clear(frame)
            elseif cycle%4==1 then holder:Hide();holder:Show()
            elseif cycle%4==2 then frame.config=h.Copy(frame.config)
            else h.Spec(cycle%3+1);event("PLAYER_SPECIALIZATION_CHANGED","player")end
            InCombatLockdown=function()return cycle%2==0 end
            Apply(frame);Positions(holder,6,direction);Quiet(holder);Eq(Plays(holder,3),before+1)
            Eq(bars[3].ReadyHighlight,texture)
            for i=1,6 do Eq(holder.Bars[i],bars[i]);Eq(bars[i].Countdown,texts[i])end
        end
        h.native.HookScript=hook;InCombatLockdown=combat
    end)
end)
Test("detailed demo, placeholder, selection preview and live return share mirrored anchors",function()
    h.HighlightCase(function(frame,holder,event)
        frame.config.classPowerBarGrowth="RIGHT_TO_LEFT"
        local demo=ns.UnitFrameDemoEnvironment
        ns.guiTestModeEnabled=true;demo.ApplyFrameSnapshot(nil,frame,{},"detailed","growth")
        Apply(frame);Positions(holder,6,"RIGHT_TO_LEFT")
        for i=1,6 do Eq(holder.segments[i].index,i);Eq(Plays(holder,i),0)end
        ns.guiTestModeEnabled=false;ns.framesUnlocked=true
        demo.ApplyFrameSnapshot(nil,frame,{},"placeholder","growth");Apply(frame)
        Positions(holder,6,"RIGHT_TO_LEFT");local colors=demo.GetPlaceholderColors()
        Equal(holder.Bars[1].lastSetStatusBarColor,{colors.barR,colors.barG,colors.barB,colors.barA})
        ns.framesUnlocked=false;demo.ApplyFrameSnapshot(nil,frame,{},"live","growth");h.Advance()
        demo.ApplyFrameSnapshot(nil,frame,{},"live","growth");Apply(frame);Positions(holder,6,"RIGHT_TO_LEFT")
        -- Existing selection-preview fallback, no fabricated live Rune API result.
        local api,preview=GetRuneCooldown,C.ShouldForcePreview
        GetRuneCooldown=nil;C.ShouldForcePreview=function()return true end
        Apply(frame);Positions(holder,6,"RIGHT_TO_LEFT");assert(not holder._readyTransitions)
        GetRuneCooldown=api;C.ShouldForcePreview=preview
        Apply(frame);Positions(holder,6,"RIGHT_TO_LEFT");for i=1,6 do Eq(Plays(holder,i),0)end
    end)
end)
h.Load("GUI/Editor/Inspector/InspectorRefreshPolicy.lua")
Test("Inspector scoped/fallback dropdown, real mutation and live refresh policy",function()
    local source=Read("GUI/Editor/Inspector/InspectorController.lua")
    local a=assert(source:find('        local classPowerGrowth =',1,true))
    local b=assert(source:find('        if isExpert then',a,true))
    local block=source:sub(a,b-1)
    for _,scoped in ipairs({false,true})do
        local config={showClassPowerBar=true};local geometry={};local control;local refreshes=0
        local function Dropdown(parent,label,list,value,callback,disabled)
            Eq(parent,geometry);Eq(label,"Segment Growth")
            control={list=list,value=value,callback=callback,disabled=disabled}
        end
        local env={usePropertyGroups=scoped,unitConfig=config,geometrySection=geometry,L={},
            absorbGrowthList={LEFT_TO_RIGHT="Left to Right",RIGHT_TO_LEFT="Right to Left"},
            AddDropdown=Dropdown,
            AddPropertyDropdownRow=function(parent,label,options,disabled)
                Dropdown(parent,label,options.list,options.value,options.onChanged,disabled)
            end,
            SetUnitField=function(key,value)
                Eq(key,"classPowerBarGrowth")
                local result=ns.InspectorMutations.SetUnitField({unitConfig=config},key,value);assert(result.ok and result.changed)
                Eq(ns.InspectorRefreshPolicy.Resolve("unit",key).scope,"live");refreshes=refreshes+1
            end}
        local build=assert(load(block,"@Inspector.SegmentGrowth","t",env))
        build();Eq(control.value,"LEFT_TO_RIGHT");assert(not control.disabled)
        for _,direction in ipairs({"RIGHT_TO_LEFT","LEFT_TO_RIGHT"})do
            control.callback(direction);build();Eq(config.classPowerBarGrowth,direction);Eq(control.value,direction)
        end
        Eq(refreshes,2);config.showClassPowerBar=false;build();assert(control.disabled)
        config.classPowerBarGrowth="bad";build();Eq(control.value,"LEFT_TO_RIGHT")
    end
    local locale={};assert(loadfile("Locales/enUS.lua"))("FocalPoint",locale)
    Eq(locale.L.OPTION_CLASS_POWER_SEGMENT_GROWTH,"Segment Growth")
    assert(locale.L.OPTION_LEFT_TO_RIGHT and locale.L.OPTION_RIGHT_TO_LEFT)
    local getLocale=GetLocale;GetLocale=function()return "deDE" end
    assert(loadfile("Locales/deDE.lua"))("FocalPoint",locale);GetLocale=getLocale
    Eq(locale.L.OPTION_CLASS_POWER_SEGMENT_GROWTH,"Segment-Wachstumsrichtung")
end)
Test("defaults, new layouts, Built-in copy, sparse legacy and RTL transfer/reload stay pure data",function()
    h.Load("Services/LayoutTransferCodec.lua");h.Load("Services/LayoutTransfer.lua");h.Load("Services/LayoutTransferVNext.lua")
    Eq(ns:GetDefaultDB().profile.Units.player.classPowerBarGrowth,"LEFT_TO_RIGHT")
    local build=assert(h.f.Upvalue(ns.CreateBlankLayout,"BuildNewLayoutPayload"))
    Eq(build(ns).Units.player.classPowerBarGrowth,"LEFT_TO_RIGHT")
    ns.db={profile={General={}},char={activeLayoutId="builtin:default"},global={TextTemplates={},UserLayouts={}}}
    for _,key in ipairs({"default","classic","minimal","modern"})do
        Eq(ns.PresetService.GetPreset(key).layout.Units.player.classPowerBarGrowth,"LEFT_TO_RIGHT")
        local ok,id=ns.LayoutMutations.CopyLayout("builtin:"..key,"Copy "..key);assert(ok,id)
        Eq(ns.db.global.UserLayouts[id].payload.Units.player.classPowerBarGrowth,"LEFT_TO_RIGHT")
    end
    for _,case in ipairs({{}, {growth="LEFT_TO_RIGHT"},{growth="RIGHT_TO_LEFT"}})do
        local record={name="Growth",formatVersion=2,payload={Units={player={Texts={},classPowerBarGrowth=case.growth}}}}
        ns.db.global.UserLayouts["layout:growth"]=record
        local before=h.Copy(record)
        local ok,id=ns.LayoutMutations.CopyLayout("layout:growth","Growth copy "..tostring(case.growth));assert(ok,id)
        Eq(ns.db.global.UserLayouts[id].payload.Units.player.classPowerBarGrowth,case.growth or "LEFT_TO_RIGHT")
        local encoded=assert(ns.LayoutTransferVNext.Export(record,ns.db))
        local result=ns.LayoutTransferVNext.PrepareImport(encoded,{global={TextTemplates={},UserLayouts={}}})
        assert(result.ready);Equal(result.preparedLayout.payload,record.payload);Equal(before,record)
    end
    -- Saved layout data and a fresh frame reproduce RTL, without copying live widgets/state.
    h.Defaults();local frame=h.Frame();frame.config.classPowerBarGrowth="RIGHT_TO_LEFT";Apply(frame)
    local saved=h.Copy(frame.config);local fresh=h.Frame();fresh.config=saved;Apply(fresh)
    Positions(fresh.Elements.ClassPowerBar,6,"RIGHT_TO_LEFT")
    assert(fresh.Elements.ClassPowerBar~=frame.Elements.ClassPowerBar)
    for i=1,6 do Eq(Plays(fresh.Elements.ClassPowerBar,i),0)end
    Equal(saved,frame.config)
end)
Test("full UnitFrame ApplyConfig forwards layout growth without touching source fields",function()
    local source=Read("Tests/UnitFrameGeometry.lua")
    local boundary=assert(source:find("local fixtures={",1,true))
    local runtime,Applied=assert(load(source:sub(1,boundary-1).."\nreturn ns,Applied","@Growth/GeometryFixture"))()
    local captured
    for i=1,100 do
        local name=debug.getupvalue(runtime.UnitFrame.ApplyConfig,i)
        if not name then break end
        if name=="ApplyClassPowerLayout" then debug.setupvalue(runtime.UnitFrame.ApplyConfig,i,function(_,options)captured=options end);break end
    end
    for _,case in ipairs({{}, {growth="LEFT_TO_RIGHT"},{growth="RIGHT_TO_LEFT"}})do
        local config={classPowerBarGrowth=case.growth};Applied(runtime,config,"player",false)
        assert(captured);Eq(captured.classPowerBarGrowth,case.growth)
    end
end)
assert(#h.f.env.errors==0,table.concat(h.f.env.errors,"\n"))
print("Class Power Segment Growth: "..count.." groups PASS")
