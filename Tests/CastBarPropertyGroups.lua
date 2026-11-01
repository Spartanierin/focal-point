-- Real Cast builder, shared Workspace, selection and mutations; native picker Cancel is a client gate.
local function Read(path)local f=assert(io.open(path));local s=f:read("*a");f:close();return s end
local source=Read("Tests/NormalAbsorbPropertyGroups.lua")
local stop=assert(source:find("\nlocal count=0",1,true))
local s=assert(load(source:sub(1,stop)..[[
return {h=h,ns=ns,state=state,controller=controller,selection=selection,Drain=Drain,Build=Build,
Select=Select,Control=Control,Walk=Walk,Tabs=Tabs,Media=function()return media end,
Stats=function()return acquired,released,timers end,
Start=function(mode,expert)
    db,unit=Setup();unit.castBarPresent=true;unit.showCastBar=true;unit.showCastBarIcon=true
    unit.castBarWidthMode="MATCH_FRAME";unit.castBarWidth=120;unit.castBarHeight=20
    unit.castBarColor={.2,.3,.4,.8};unit.castBarInterruptibleColor={.5,.4,.3,.7}
    unit.normalAbsorbBarPresent=true;unit.showNormalAbsorbBar=true
    if expert~=nil then db.profile={General={ExpertMode=expert}} end
    state.SetMode(mode or "quick");window=Build();Select("CastBar");return window,unit,db
end}
]],"@CastBar/Workspace"))()
local window,unit,db
local function Body()
    local found;s.Walk(window._focalPointPropertyScroll,function(w)
        if w:GetUserData("focalPointSectionKey")=="cast" and w._focalPointRequestRebuild then found=w end
    end);return assert(found)
end
local function Actions()
    local area,button,n,m
    n,m=0,0
    for _,w in ipairs(Body().children)do
        if w:GetUserData("normalAbsorbObjectActions")then area=w;n=n+1 end
    end
    s.Walk(Body(),function(w)
        if w.type=="Button" and w.text:GetText()==(s.ns.L.EDITOR_REMOVE_CAST_BAR_BUTTON or "Remove Cast Bar")then button=w;m=m+1 end
    end)
    assert(n==0 and m==0,"Workspace still has Remove or an Actions area")
end
local function Click(key)s.Tabs()[key]:Fire("OnClick");s.Drain()end
local function Check(key)
    local tabs,order=s.Tabs();assert(table.concat(order,",")=="appearance,geometry,behavior")
    assert(s.state.Get().inspectorPropertyGroup==key)
    for _,tab in pairs(tabs)do assert(not tab.disabled and (tab.text:GetText() or "")=="")end
    for _,child in ipairs(Body().children)do
        local group=child:GetUserData("normalAbsorbPropertyGroup")
        if group then assert(child.frame:IsShown()==(group==key))end
    end
    s.Walk(Body(),function(w)assert(w.type~="InlineGroup")end);Actions()
end
local function Group(label,kind)
    return s.Control(label,kind).parent.parent.parent:GetUserData("normalAbsorbPropertyGroup")
end
local count=0
local function Test(name,fn)fn();count=count+1;print("PASS: "..name)end
Test("Cast opts into the shared three-tab presentation in Quick and Expert with unchanged field membership",function()
    for _,mode in ipairs({"quick","expert"})do
        window,unit,db=s.Start(mode);Check("appearance")
        assert(s.selection.GetSelectedObject().objectKey=="CastBar")
        assert(Group("Show","CheckBox")=="behavior" and Group("Show Cast Bar Icon","CheckBox")=="behavior")
        assert(Group("Texture","Button")=="appearance" and Group("Color","ColorPicker")=="appearance")
        assert(Group("Width Mode","Dropdown")=="geometry" and Group("Height","FPCompactSlider")=="geometry")
    end
end)
Test("tab switching and repeated selection retain controls, independent action and canonical data",function()
    local data=s.h.Copy(db);local body=Body();Actions();local width=s.Control("Width","FPCompactSlider")
    local a,r,t=s.Stats()
    for _=1,20 do for _,key in ipairs({"geometry","behavior","appearance","appearance"})do Click(key);Check(key)end end
    local aa,rr,tt=s.Stats();assert(a==aa and r==rr and t==tt)
        Actions();assert(body==Body() and width==s.Control("Width","FPCompactSlider"));s.h.Equal(db,data)
end)
Test("existing texture Apply and no-Apply path retain values and color/border callbacks",function()
    local before=s.h.Copy(db);s.Control("Texture","Button"):Fire("OnClick")
    assert(s.Media());s.h.Equal(db,before) -- Native Cancel performs no Apply; native interaction stays open.
    s.Media().onApply("fp:statusbar:flat-white");s.Drain();assert(unit.castBarTexture=="fp:statusbar:flat-white")
    s.Control("Color","ColorPicker"):Fire("OnValueConfirmed",.3,.4,.5,.6)
    s.Control("Interruptible Color","ColorPicker"):Fire("OnValueConfirmed",.6,.5,.4,.3)
    s.Control("Border Width","FPCompactSlider"):Fire("OnValueChanged",2)
    s.Control("Border Color","ColorPicker"):Fire("OnValueConfirmed",.4,.2,.1,0)
    assert(unit.castBarColor[4]==.6 and unit.castBarInterruptibleColor[4]==.3)
    assert(unit.castBarBorderWidth==2 and unit.castBarBorderColor[4]==0)
end)
Test("width mode, width/height rounding and existing disabled Show dependencies remain intact",function()
    Click("geometry");assert(s.Control("Width","FPCompactSlider").disabled)
    s.Control("Width Mode","Dropdown"):Fire("OnValueChanged","CUSTOM");s.Drain();Check("geometry")
    assert(not s.Control("Width","FPCompactSlider").disabled)
    s.Control("Width","FPCompactSlider"):Fire("OnValueChanged",211.6)
    s.Control("Height","FPCompactSlider"):Fire("OnValueChanged",17.6)
    assert(unit.castBarWidth==212 and unit.castBarHeight==18)
    Click("behavior");s.Control("Show Cast Bar Icon","CheckBox"):Fire("OnValueChanged",false);s.Drain()
    assert(unit.showCastBarIcon==false)
    s.Control("Show","CheckBox"):Fire("OnValueChanged",false);s.Drain();Check("behavior")
    assert(unit.showCastBar==false and s.Control("Height","FPCompactSlider").disabled and s.Control("Texture","Button").disabled)
    s.Control("Show","CheckBox"):Fire("OnValueChanged",true);s.Drain();Check("behavior")
    assert(unit.showCastBar and not s.Control("Height","FPCompactSlider").disabled)
end)
Test("Cast/Absorb selection, Unit changes, rebuild and reopen share the canonical Workspace",function()
    local host=window
    for _=1,10 do
        local old=s.Tabs().appearance.events.OnClick
        s.Select("NormalAbsorbBar");Click("geometry");old();assert(s.state.Get().inspectorPropertyGroup=="geometry")
        s.Select("CastBar");Click("geometry");Check("geometry")
    end
    local units=s.ns.ActiveLayoutResolver.GetActiveRuntimeRoot().units;units.target=s.h.Copy(unit)
    assert(s.selection.SelectObject({kind="bar",unit="target",objectKey="CastBar"}));s.Drain();Check("geometry")
    s.Control("Height","FPCompactSlider"):Fire("OnValueChanged",23);assert(units.target.castBarHeight==23 and unit.castBarHeight==18)
    assert(s.selection.SelectObject({kind="bar",unit="player",objectKey="CastBar"}));s.Drain();Check("geometry")
    s.controller.RefreshActiveProperties();s.Drain();Check("geometry")
    host.closebutton:GetScript("OnClick")(host.closebutton);s.Drain();assert(s.Build()==host);s.Drain();Check("geometry")
end)
Test("Remove remains absent from every tab without altering component presence",function()
    for _,key in ipairs({"appearance","geometry","behavior"})do
        window,unit,db=s.Start();Click(key)
        local absorb=unit.normalAbsorbBarPresent;Actions()
        assert(unit.castBarPresent==true and unit.normalAbsorbBarPresent==absorb)
        assert(s.selection.GetSelectedObject().objectKey=="CastBar")
    end
end)
Test("non-Workspace scoped Cast keeps General/Appearance/Geometry/Actions and original controls",function()
    window,unit,db=s.Start()
    local host=s.h.ui.ace:Create("SimpleGroup")
    s.ns.GUI.Editor.Inspector.BuildProperties(host,s.state.Get(),{getUnitConfig=s.ns.UnitFrameUtils.GetUnitDB})
    local groups={};s.Walk(host,function(w)
        assert(not w:GetUserData("normalAbsorbPropertyTab"))
        if w.type=="InlineGroup"then groups[#groups+1]=w.titletext:GetText()end
    end)
    assert(table.concat(groups,",")=="General,Appearance,Geometry,Actions")
    s.h.ui.ace:Release(host)
end)
Test("Workspace cast scope exposes each position field once in geometry across profile modes and rebuilds",function()
    local fields={
        {"Anchor From","Dropdown","castBarPoint","BOTTOMLEFT"},
        {"Anchor To","Dropdown","castBarRelativePoint","TOPLEFT"},
        {s.ns.L.OPTION_X_OFFSET or "X Offset","FPCompactSlider","castBarOffsetX",0},
        {s.ns.L.OPTION_Y_OFFSET or "Y Offset","FPCompactSlider","castBarOffsetY",4},
    }
    for _,expert in ipairs({false,true})do
        window,unit,db=s.Start(expert and "quick" or "expert",expert)
        local profile=s.h.Copy(db.profile)
        assert(s.state.Get().propertyScope.sectionKey=="cast")
        for cycle=1,3 do
            Click("geometry");Check("geometry")
            for _,field in ipairs(fields)do
                local control=s.Control(field[1],field[2]);local n=0
                assert(Group(field[1],field[2])=="geometry")
                s.Walk(Body(),function(w)
                    local children=w.children or {}
                    if children[1] and children[1].type=="Label" and children[1].label:GetText()==field[1] then n=n+1 end
                    assert(w:GetUserData("focalPointSectionKey")~="cast_position")
                end)
                assert(n==1,"missing or duplicate position row: "..field[1])
                assert(control:GetValue()==(unit[field[3]] or field[4]))
            end
            s.Control("Anchor From","Dropdown"):Fire("OnValueChanged","RIGHT");s.Drain()
            s.Control("Anchor To","Dropdown"):Fire("OnValueChanged","CENTER");s.Drain()
            s.Control(fields[3][1],"FPCompactSlider"):Fire("OnValueChanged",-31.6)
            s.Control(fields[4][1],"FPCompactSlider"):Fire("OnValueChanged",48.6)
            assert(unit.castBarPoint=="RIGHT" and unit.castBarRelativePoint=="CENTER")
            assert(unit.castBarOffsetX==-32 and unit.castBarOffsetY==49)
            s.controller.RefreshActiveProperties();s.Drain()
            s.Select("NormalAbsorbBar");s.Select("CastBar")
        end
        s.h.Equal(db.profile,profile)
    end
end)
Test("unscoped Legacy retains Expert-only separate cast_position section and controls",function()
    for _,expert in ipairs({false,true})do
        window,unit,db=s.Start(expert and "quick" or "expert",expert)
        local before=s.h.Copy(db)
        s.state.SetSectionCollapsed("cast_position",false)
        local host=s.h.ui.ace:Create("SimpleGroup")
        s.ns.GUI.Editor.Inspector.Build(host,s.state.Get(),{getUnitConfig=s.ns.UnitFrameUtils.GetUnitDB})
        local section
        s.Walk(host,function(w)
            if w:GetUserData("focalPointSectionKey")=="cast_position" and w._focalPointRequestRebuild then assert(not section);section=w end
        end)
        assert((section~=nil)==expert,"Legacy position availability changed")
        if expert then
            local labels={}
            s.Walk(section,function(w)
                if w.type=="Dropdown" and w.label then labels[w.label:GetText()]=true end
                if w.type=="Slider" and w.label then labels[w.label:GetText()]=true end
            end)
            assert(labels["Anchor From"] and labels["Anchor To"])
            assert(labels[s.ns.L.OPTION_X_OFFSET or "X Offset"] and labels[s.ns.L.OPTION_Y_OFFSET or "Y Offset"])
        end
        s.h.Equal(db,before);s.h.ui.ace:Release(host)
    end
end)
assert(#s.h.ui.env.errors==0,table.concat(s.h.ui.env.errors,"\n"))
print("Cast Bar Property Groups: "..count.." groups PASS")
