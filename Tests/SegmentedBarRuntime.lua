-- Real shared snapshot, factory, renderer, ApplyConfig, clear and canvas geometry.
-- Native widget/secure execution remains an ingame acceptance boundary.
local function Read(path)local f=assert(io.open(path));local s=f:read("*a");f:close();return s end
local h=assert(load(Read("Tests/ClassPowerPreview.lua")..
    "\nreturn {ns=ns,UF=UF,Setup=Setup,fixture=h}","@SegmentedBarRuntime/Fixture"))()
local ns,UF,f=h.ns,h.UF,h.fixture
local Eq,Equal=f.Eq,f.Equal
function f.native:RegisterForClicks(...) self.registeredClicks={...} end
function f.native:RegisterForDrag(...) self.registeredDrags={...} end
for _,path in ipairs({"GUI/Editor/Composition/CompositionOwnership.lua",
    "Engine/UnitFrame/Bars/UnitFrameSegmentedBars.lua","GUI/Editor/SelectionGeometryResolver.lua",
    "GUI/Editor/CanvasHoverOverlay.lua"})do f.Load(path)end
local B=ns.UnitFrameSegmentedBars
local count=0
local function Test(name,fn)fn();count=count+1;print("PASS: "..name)end
local function Records()
    return {
        {id="segmented-bar-a",enabled=true,dataSource={id="runes",scope="player"},
         width=130,height=14,spacing=2,point="TOPLEFT",relativePoint="BOTTOMLEFT",offsetX=8,offsetY=-7,
         growth="LEFT_TO_RIGHT",color={.2,.4,.6,0}},
        {id="segmented-bar-b",enabled=true,dataSource={id="runes",scope="player"},
         width=190,height=18,spacing=2,anchorTo="SegmentedBar:segmented-bar-a",
         point="TOPLEFT",relativePoint="BOTTOMRIGHT",offsetX=3,offsetY=-5,
         growth="RIGHT_TO_LEFT",color={.8,.6,.4,.7}},
    }
end
local function Setup(class)
    local frame,legacy=h.Setup(class or "DEATHKNIGHT")
    frame.config.segmentedBars=Records()
    assert(ns.LayoutService.ValidateSegmentedBars(frame.config.segmentedBars,"player"))
    return frame,legacy
end
local function Holders(frame)return frame._segmentedBars.byId["segmented-bar-a"],frame._segmentedBars.byId["segmented-bar-b"]end
local function NoFlashes(holder)for _,bar in ipairs(holder.Bars)do assert(not bar.ReadyHighlight)end end
Test("two independent holders consume one canonical refresh, no additional gameplay reads",function()
    local frame,legacy=Setup();local api=GetRuneCooldown;local reads=0
    GetRuneCooldown=function(i)reads=reads+1;return api(i)end
    UF:Refresh(frame);Eq(reads,6)
    local a,b=Holders(frame);assert(a~=b and a~=legacy and b~=legacy)
    Eq(a.segments,frame.LiveValues.classPowerSnapshot.info.segments);Eq(b.segments,a.segments)
    local binding=assert(legacy._runeSlotBinding)
    Eq(binding.snapshot.info.segments,a.segments)
    for slot=1,6 do Eq(legacy.segments[slot],a.segments[binding.slotToApi[slot]])end
    Eq(a:GetWidth(),130);Eq(b:GetWidth(),190);Eq(a:GetHeight(),14);Eq(b:GetHeight(),18)
    Equal(a.Bars[2].lastSetStatusBarColor,{.2,.4,.6,0});Equal(b.Bars[2].lastSetStatusBarColor,{.8,.6,.4,.7})
    Eq(a.Bars[2].Countdown:GetText(),"5.0");Eq(b.Bars[3].Countdown:GetText(),"8.0")
    local _,size,flags=a.Bars[2].Countdown:GetFont();Eq(size,10);Eq(flags,"OUTLINE")
    local p,target,rp,x,y=b:GetPoint(1);Eq(target,a);Equal({p,rp,x,y},{"TOPLEFT","BOTTOMRIGHT",3,-5})
    UF:ApplyConfig(frame);Eq(reads,6)
    GetRuneCooldown=function()error("rune read during countdown")end
    local oldDB=ns.UnitFrameUtils.GetUnitDB;ns.UnitFrameUtils.GetUnitDB=function()error("DB read during countdown")end
    f.Time(100.1);a:Run("OnUpdate");b:Run("OnUpdate")
    Eq(a.Bars[2].Countdown:GetText(),"4.9");Eq(b.Bars[3].Countdown:GetText(),"7.9")
    ns.UnitFrameUtils.GetUnitDB=oldDB;GetRuneCooldown=api
    NoFlashes(a);NoFlashes(b)
end)
Test("shared dynamic ordering retains API identity in both growth directions without flashes",function()
    local frame=Setup();UF:Refresh(frame);local a,b=Holders(frame)
    local slots=ns.UnitFrameClassPower.GetRuneVisualSlots(a.segments)
    local api=GetRuneCooldown
    GetRuneCooldown=function(i)if i==3 then return 0,0,true end;return api(i)end
    UF:Refresh(frame)
    assert(slots[3]~=ns.UnitFrameClassPower.GetRuneVisualSlots(a.segments)[3])
    local after=ns.UnitFrameClassPower.GetRuneVisualSlots(a.segments)
    for i=1,6 do
        Eq(a.segments[i].index,i);Eq(b.segments[i].index,i)
        local p,owner,_,x=a.Bars[i]:GetPoint(1);Eq(p,"TOPLEFT");Eq(owner,a);Eq(x,(after[i]-1)*22)
        p,owner,_,x=b.Bars[i]:GetPoint(1);Eq(p,"TOPRIGHT");Eq(owner,b);Eq(x,-(after[i]-1)*32)
    end
    NoFlashes(a);NoFlashes(b);assert(not a.Bars[3].Countdown:IsShown())
    GetRuneCooldown=api
end)
Test("bars-only refresh consumes the new observation and clears unavailable timers",function()
    local frame=Setup();UF:Refresh(frame);local a,b=Holders(frame)
    local api=GetRuneCooldown;local reads=0
    GetRuneCooldown=function(i)reads=reads+1;if i==2 then return 0,0,true end;return api(i)end
    UF:Refresh(frame,{scopes={bars=true}});Eq(reads,6)
    assert(a.segments[2].ready and b.segments[2].ready)
    assert(not a.Bars[2].Countdown:IsShown());NoFlashes(a);NoFlashes(b)
    GetRuneCooldown=nil;UF:Refresh(frame,{scopes={bars=true}})
    assert(not a:IsShown() and not b:IsShown() and not a:GetScript("OnUpdate"))
    GetRuneCooldown=api
end)
Test("disable, delete and clear isolate Legacy and preserve source; hidden anchor still positions child",function()
    local frame,legacy=Setup();UF:Refresh(frame);local a,b=Holders(frame)
    local snapshot=frame.LiveValues.classPowerSnapshot;local legacySegments=legacy.segments
    local otherHides=0;b:HookScript("OnHide",function()otherHides=otherHides+1 end)
    frame.config.segmentedBars[1].enabled=false;B.Apply(frame)
    assert(not a:IsShown() and b:IsShown());Eq(select(2,b:GetPoint(1)),a)
    assert(not a:GetScript("OnUpdate"));Eq(legacy.segments,legacySegments);Eq(frame.LiveValues.classPowerSnapshot,snapshot)
    frame.config.segmentedBars[2].anchorTo="Frame";table.remove(frame.config.segmentedBars,1);B.Apply(frame)
    assert(not frame._segmentedBars.byId["segmented-bar-a"] and b:IsShown())
    Eq(otherHides,0)
    B.Clear(frame);assert(not b:IsShown() and not b:GetScript("OnUpdate"));assert(legacy:IsShown())
    Eq(frame.LiveValues.classPowerSnapshot,snapshot);Eq(legacy.segments,legacySegments)
    frame.config.classPowerBarPresent=false;frame.config.showClassPowerBar=false
    UF:Refresh(frame);assert(not legacy:IsShown());assert(b:IsShown())
end)
Test("unavailable, non-rune source and invalid anchor never fabricate geometry or leave timers",function()
    local frame=Setup();UF:Refresh(frame);local a,b=Holders(frame)
    local api=GetRuneCooldown;GetRuneCooldown=nil;UF:Refresh(frame)
    for _,holder in ipairs({a,b})do assert(not holder:IsShown() and holder.segments==nil and not holder:GetScript("OnUpdate"))end
    GetRuneCooldown=api;UF:Refresh(frame)
    frame.config.segmentedBars[2].anchorTo="SegmentedBar:segmented-bar-missing";B.Apply(frame)
    assert(not a:IsShown() and not b:IsShown())
    assert(not B.GetVisibleHolder(frame,"segmented-bar-b"))
    frame.config.segmentedBars=Records();UF:Refresh(frame)
    frame.config.segmentedBars[1].spacing=1000;B.Apply(frame);assert(not a:IsShown())
    frame=Setup("WARRIOR");UF:Refresh(frame);a,b=Holders(frame);assert(not a:IsShown() and not b:IsShown())
end)
Test("canvas uses visible holders and validated hidden editor anchors",function()
    local frame=Setup();UF:Refresh(frame);local a,b=Holders(frame)
    local resolve=ns.GUI.Editor.SelectionGeometryResolver.Resolve
    local ref={kind="segmentedBar",unit="player",objectKey="segmented-bar-b"}
    Eq(resolve(frame,ref).target,b);Eq(B.GetVisibleHolder(frame,"segmented-bar-a"),a)
    frame.config.segmentedBars[2].enabled=false;assert(not resolve(frame,ref));B.Apply(frame)
    local hidden=assert(resolve(frame,ref));Eq(hidden.target,nil);Eq(hidden.width,190);Eq(hidden.height,18)
    local p=hidden.points[1];Eq(p.point,"TOPLEFT");Eq(p.relativeTo,a)
    Eq(p.relativePoint,"BOTTOMRIGHT");Eq(p.offsetX,3);Eq(p.offsetY,-5)
    a:ClearAllPoints();assert(not resolve(frame,ref));B.Apply(frame)
    frame.config.segmentedBars[1].enabled=false;B.Apply(frame)
    assert(resolve(frame,ref) and not a:IsShown() and not b:IsShown())
    frame.config.segmentedBars[2].enabled=true;B.Apply(frame);Eq(resolve(frame,ref).target,b)
    frame.config=f.Copy(frame.config);assert(not resolve(frame,ref))
    ns.ActiveLayoutResolver.GetActiveRuntimeRoot().units.player=frame.config
    UF:Refresh(frame);Eq(resolve(frame,ref).target,b)
    ref.objectKey="missing";assert(not resolve(frame,ref))
end)
Test("canvas guards reject stale bindings and preserve auto editor geometry",function()
    local frame=Setup();frame.config.segmentedBars[2].dataSource={id="auto",scope="player"}
    UF:Refresh(frame)
    local resolve=ns.GUI.Editor.SelectionGeometryResolver.Resolve
    local ref={kind="segmentedBar",unit="player",objectKey="segmented-bar-b"}
    local a,b=Holders(frame)
    local geometry=resolve(frame,ref)
    Eq(geometry.source,"segmented-bar-holder");Eq(geometry.target,b)
    frame.config.segmentedBars[2].enabled=false;B.Apply(frame)
    geometry=resolve(frame,ref)
    Eq(geometry.source,"segmented-bar-config");Eq(geometry.points[1].relativeTo,a)
    b:ClearAllPoints();Eq(resolve(frame,ref),nil)
    B.Apply(frame)
    b:SetSize(1,1);geometry=resolve(frame,ref)
    Eq(geometry.source,"segmented-bar-config");Eq(geometry.width,190);Eq(geometry.height,18)
    B.Apply(frame)
    a:SetSize(1,1);Eq(resolve(frame,ref),nil)
    B.Apply(frame)
    local bound=b._segmentedBarRecord;b._segmentedBarRecord={}
    Eq(resolve(frame,ref),nil)
    b._segmentedBarRecord=bound
    local state=frame._segmentedBars;state.config={}
    Eq(resolve(frame,ref),nil)
    state.config=frame.config
    local root=ns.ActiveLayoutResolver.GetActiveRuntimeRoot();root.units.player={}
    Eq(resolve(frame,ref),nil)
    root.units.player=frame.config
    ref.objectKey="missing";Eq(resolve(frame,ref),nil)
    ref.objectKey="segmented-bar-b"
    local oldWidth=frame.config.segmentedBars[2].width
    frame.config.segmentedBars[2].width=0
    Eq(resolve(frame,ref),nil)
    frame.config.segmentedBars[2].width=oldWidth
    geometry=resolve(frame,ref);Eq(geometry.source,"segmented-bar-config")
end)
Test("canvas rejects invalid anchor fields on selected and chained holders",function()
    local frame=Setup();UF:Refresh(frame);local a,b=Holders(frame)
    frame.config.segmentedBars[2].enabled=false;B.Apply(frame)
    local resolve=ns.GUI.Editor.SelectionGeometryResolver.Resolve
    local ref={kind="segmentedBar",unit="player",objectKey="segmented-bar-b"}
    local cases={
        {field="relativeTo",actual=frame},
        {field="point",actual="LEFT"},
        {field="relativePoint",actual="TOPLEFT"},
        {field="x",actual=4},
        {field="y",actual=-4},
    }
    local getPoint=b.GetPoint
    for _,case in ipairs(cases)do
        b.GetPoint=function(self,index)
            local point,relativeTo,relativePoint,x,y=getPoint(self,index)
            if case.field=="point"then point=case.actual
            elseif case.field=="relativeTo"then relativeTo=case.actual
            elseif case.field=="relativePoint"then relativePoint=case.actual
            elseif case.field=="x"then x=case.actual
            else y=case.actual end
            return point,relativeTo,relativePoint,x,y
        end
        Eq(resolve(frame,ref),nil)
    end
    b.GetPoint=nil
    local original=a.GetPoint
    a.GetPoint=function(self,index)
        local _,relativeTo,relativePoint,x,y=original(self,index)
        return "LEFT",relativeTo,relativePoint,x,y
    end
    Eq(resolve(frame,ref),nil)
    a.GetPoint=nil
    Eq(resolve(frame,ref).source,"segmented-bar-config")
end)
Test("50 clear/hide/show/layout/reuse cycles retain holders and never play new highlights",function()
    local frame,legacy=Setup();UF:Refresh(frame);local a,b=Holders(frame)
    for cycle=1,50 do
        frame:Hide();assert(not a:GetScript("OnUpdate") and not b:GetScript("OnUpdate"))
        frame:Show();assert(a:GetScript("OnUpdate") and b:GetScript("OnUpdate"))
        ns.UnitFrameVisibility.ClearFrameVisualState(frame)
        assert(not a:IsShown() and not b:IsShown())
        frame.config.segmentedBars={};UF:Refresh(frame);Eq(next(frame._segmentedBars.byId),nil)
        frame.config=f.Copy(frame.config);frame.config.segmentedBars=Records()
        ns.ActiveLayoutResolver.GetActiveRuntimeRoot().units.player=frame.config
        UF:Refresh(frame)
        local one,two=Holders(frame);assert((one==a or one==b) and (two==a or two==b) and one~=two)
        NoFlashes(one);NoFlashes(two);Eq(frame.Elements.ClassPowerBar,legacy)
    end
    ns.UnitFrameState.ResetDerivedFrameState(frame)
    assert(not a:IsShown() and not b:IsShown() and not a:GetScript("OnUpdate"))
end)
Test("canvas hit zones select stable IDs for disabled and unavailable instances",function()
    local frame=Setup();UF:Refresh(frame);local a,b=Holders(frame)
    ns.framesUnlocked=true;frame.MoveOverlay=CreateFrame("Frame",nil,frame);frame.MoveOverlay:Show()
    local canvas=ns.GUI.Editor.CanvasHoverOverlay
    local selection=ns.GUI.Editor.ObjectSelection;local selectObject=selection.SelectObject
    local selected
    selection.SelectObject=function(ref)selected=ref;return true end
    canvas.UpdateFrame(frame)
    for _,id in ipairs({"segmented-bar-a","segmented-bar-b"})do
        local zone=assert(frame._focalPointCanvasHoverZones["segmentedBar:"..id])
        assert(zone:IsShown());Eq(zone._focalPointVisualTarget,frame._segmentedBars.byId[id])
        Eq(select(2,zone:GetPoint(1)),frame._segmentedBars.byId[id])
        zone:Run("OnMouseUp","LeftButton");Eq(selected.kind,"segmentedBar");Eq(selected.objectKey,id);Eq(selected.unit,"player")
        assert(not zone._focalPointMovesUnit)
    end
    frame.config.segmentedBars[2].enabled=false;B.Apply(frame);canvas.UpdateFrame(frame)
    local hidden=frame._focalPointCanvasHoverZones["segmentedBar:segmented-bar-b"]
    assert(hidden:IsShown());Eq(hidden:GetWidth(),190);Eq(select(2,hidden:GetPoint(1)),a)
    hidden:Run("OnMouseUp","LeftButton");Eq(selected.objectKey,"segmented-bar-b")
    assert(frame._focalPointCanvasHoverZones["segmentedBar:segmented-bar-a"]:IsShown())
    local api=GetRuneCooldown;GetRuneCooldown=nil;UF:Refresh(frame);canvas.UpdateFrame(frame)
    assert(frame._focalPointCanvasHoverZones["segmentedBar:segmented-bar-a"]:IsShown())
    GetRuneCooldown=api
    local combat=InCombatLockdown;InCombatLockdown=function()return true end
    selected=nil;hidden:Run("OnMouseUp","LeftButton");Eq(selected,nil)
    canvas.UpdateFrame(frame);assert(not hidden:IsShown());InCombatLockdown=combat
    ns.framesUnlocked=false;canvas.UpdateFrame(frame);assert(not hidden:IsShown())
    selection.SelectObject=selectObject;ns.framesUnlocked=false
end)
Test("anchor graph reversal clears old anchors; invalid cycle fails closed",function()
    local frame=Setup();UF:Refresh(frame);local a,b=Holders(frame)
    local records=frame.config.segmentedBars
    records[1].anchorTo="SegmentedBar:segmented-bar-b";records[2].anchorTo="Frame"
    B.Apply(frame);Eq(select(2,a:GetPoint(1)),b);Eq(select(2,b:GetPoint(1)),frame)
    records[2].anchorTo="SegmentedBar:segmented-bar-a";B.Apply(frame)
    assert(not a:IsShown() and not b:IsShown());assert(not a:GetScript("OnUpdate"))
end)
Test("detailed DK preview shares synthetic snapshot; returning live resumes canonical source",function()
    local frame=Setup();UF:Refresh(frame)
    ns:ToggleTestMode();Eq(frame.LiveValues.classPowerSnapshot.source,"preview")
    local a,b=Holders(frame);Eq(a.segments,frame.LiveValues.classPowerSnapshot.info.segments);Eq(b.segments,a.segments)
    assert(a:IsShown() and b:IsShown());NoFlashes(a);NoFlashes(b)
    ns:ToggleTestMode();Eq(frame.LiveValues.classPowerSnapshot.source,"live");assert(a:IsShown())
end)
print("Segmented Bar Runtime: "..count.." groups PASS")
