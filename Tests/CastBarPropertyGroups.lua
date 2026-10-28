-- Real Cast builder, shared Workspace, selection and mutations; native picker Cancel is a client gate.
local function Read(path)local f=assert(io.open(path));local s=f:read("*a");f:close();return s end
local source=Read("Tests/NormalAbsorbPropertyGroups.lua")
local stop=assert(source:find("\nlocal count=0",1,true))
local s=assert(load(source:sub(1,stop)..[[
return {h=h,ns=ns,state=state,controller=controller,selection=selection,Drain=Drain,Build=Build,
Select=Select,Control=Control,Walk=Walk,Tabs=Tabs,Media=function()return media end,
Stats=function()return acquired,released,timers end,
Start=function(mode)
    db,unit=Setup();unit.castBarPresent=true;unit.showCastBar=true;unit.showCastBarIcon=true
    unit.castBarWidthMode="MATCH_FRAME";unit.castBarWidth=120;unit.castBarHeight=20
    unit.castBarColor={.2,.3,.4,.8};unit.castBarInterruptibleColor={.5,.4,.3,.7}
    unit.normalAbsorbBarPresent=true;unit.showNormalAbsorbBar=true
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
    assert(n==1 and m==1 and area==Body().children[#Body().children])
    assert(not area:GetUserData("normalAbsorbPropertyGroup") and not area:GetUserData("normalAbsorbPropertyContent"))
    assert(area.frame:IsShown() and button.frame:IsShown() and button.parent.parent.parent==area)
    return button
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
    local data=s.h.Copy(db);local body=Body();local remove=Actions();local width=s.Control("Width","FPCompactSlider")
    local a,r,t=s.Stats()
    for _=1,20 do for _,key in ipairs({"geometry","behavior","appearance","appearance"})do Click(key);Check(key)end end
    local aa,rr,tt=s.Stats();assert(a==aa and r==rr and t==tt)
    assert(body==Body() and remove==Actions() and width==s.Control("Width","FPCompactSlider"));s.h.Equal(db,data)
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
Test("Remove remains unique and functional from every tab without altering unrelated components",function()
    for _,key in ipairs({"appearance","geometry","behavior"})do
        window,unit,db=s.Start();Click(key)
        local absorb=unit.normalAbsorbBarPresent;Actions():Fire("OnClick");s.Drain()
        assert(unit.castBarPresent==false and unit.normalAbsorbBarPresent==absorb)
        assert(s.selection.GetSelectedObject().kind=="unit")
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
assert(#s.h.ui.env.errors==0,table.concat(s.h.ui.env.errors,"\n"))
print("Cast Bar Property Groups: "..count.." groups PASS")
