-- Real Workspace, Power builder, selection and mutations; native rendering is a client gate.
local function Read(path)
    local file=assert(io.open(path)); local source=file:read("*a"); file:close(); return source
end
local source=Read("Tests/NormalAbsorbPropertyGroups.lua")
local boundary=assert(source:find("\nlocal count=0",1,true))
local s=assert(load(source:sub(1,boundary)..[[
return {h=h,ns=ns,state=state,controller=controller,selection=selection,Drain=Drain,Build=Build,
    Select=Select,Control=Control,Walk=Walk,Tabs=Tabs,CheckAppearanceFrames=CheckAppearanceFrames,Media=function() return media end,
    Stats=function() return acquired,released,timers end,
    Start=function(mode)
        db,unit=Setup()
        unit.powerBarPresent=true; unit.showPowerBar=true; unit.powerBarHeight=20
        unit.powerColor={.2,.3,.4,.8}; unit.useClassColorPower=false
        unit.powerBackground=true; unit.powerBackgroundColor={.1,.1,.1,.5}
        unit.normalAbsorbBarPresent=true; unit.healingAbsorbBarPresent=true
        state.SetMode(mode or "quick"); window=Build(); Select("PowerBar")
        return window,unit,db
    end}
]],"@PowerBar/Workspace"))()
local window,unit,db
local function Body()
    local body
    s.Walk(window._focalPointPropertyScroll,function(w)
        if w:GetUserData("focalPointSectionKey")=="power" and w._focalPointRequestRebuild then body=w end
    end)
    return assert(body)
end
local function Click(key) assert(s.Tabs()[key]):Fire("OnClick"); s.Drain() end
local function HasRow(label)
    local found=false
    s.Walk(Body(),function(w)
        if w.type=="Label" and w.label:GetText()==label then found=true end
    end)
    return found
end
local function Actions()
    local area,button,n,m=nil,nil,0,0
    for _,child in ipairs(Body().children) do
        if child:GetUserData("normalAbsorbObjectActions") then area=child; n=n+1 end
    end
    s.Walk(Body(),function(w)
        if w.type=="Button" and w.text:GetText()==(s.ns.L.EDITOR_REMOVE_POWER_BAR_BUTTON or "Remove Power Bar") then
            button=w; m=m+1
        end
    end)
    assert(n==0 and m==0,"Workspace must have neither Remove nor an empty Actions owner")
end
local function Check(key)
    local tabs,order=s.Tabs()
    assert(table.concat(order,",")=="appearance,geometry,behavior")
    assert(s.state.Get().inspectorPropertyGroup==key)
    local labels={appearance=s.ns.L.EDITOR_PROPERTY_APPEARANCE or "Appearance",
        geometry=s.ns.L.SECTION_SIZE_POSITION or "Size & Position",behavior=s.ns.L.SECTION_BEHAVIOR or "Behavior"}
    for name,tab in pairs(tabs) do
        assert(not tab.disabled and (tab.text:GetText() or "")=="")
        local surface=assert(tab.frame._fpNormalAbsorbTab)
        assert(surface.label:GetText()==labels[name] and surface.label:IsShown())
        assert(tab.frame:GetWidth()>=surface.label:GetStringWidth()+16)
        assert(surface.bottom:IsShown()==(name~=key))
    end
    for _=1,2 do Body():DoLayout(); window._focalPointPropertyScroll:DoLayout() end
    for _,child in ipairs(Body().children) do
        local group=child:GetUserData("normalAbsorbPropertyGroup")
        if group then assert(child.frame:IsShown()==(group==key)) end
    end
    s.CheckAppearanceFrames(Body(),"Appearance,Background",{Appearance="Texture,Color,Class Color",Background="Show Background,Background Color,Border Width,Border Color"})
    Actions()
end
local function OtherFields(config)
    local result={}
    for key,value in pairs(config) do
        if key:match("Absorb") or key:match("^alternativePower") or key:match("^classPower")
            or key=="showAlternativePowerBar" or key=="showClassPowerBar" then
            result[key]=s.h.Copy(value)
        end
    end
    return result
end
local count=0
local function Test(name,fn) fn(); count=count+1; print("PASS: "..name) end
Test("Power retains its scope and appearance while exposing existing CUSTOM geometry only in Workspace",function()
    window,unit,db=s.Start("quick"); Check("appearance")
    local scope=s.state.GetPropertyScope()
    assert(scope.kind=="unit" and scope.sectionKey=="power" and scope.objectKey==nil)
    for _,label in ipairs({"Texture","Color","Class Color","Show Background","Background Color","Border Width","Border Color","Height","Show","Reverse Fill"}) do
        assert(HasRow(label),label)
    end
    for _,label in ipairs({"Width","Size Mode","Anchor Target","Offset X","Offset Y"}) do assert(HasRow(label),label) end
    assert(not HasRow("Growth Direction"))
    assert(not s.Control("Height","FPCompactSlider").disabled)
    for _,item in ipairs({{"Width","FPCompactSlider"},{"Anchor Target","Dropdown"},{"Offset X","FPCompactSlider"},{"Offset Y","FPCompactSlider"}})do
        assert(s.Control(item[1],item[2]).disabled,item[1])
    end
    local body=Body(); local height=s.Control("Height","FPCompactSlider"); local before=s.h.Copy(db)
    Actions()
    for i=1,30 do
        local key=({"geometry","behavior","appearance"})[(i-1)%3+1]
        local a,r,t=s.Stats(); window._focalPointPropertyScroll:SetScroll(400)
        Click(key); Check(key)
        local aa,rr,tt=s.Stats(); assert(a==aa and r==rr and t==tt)
        assert(Body()==body and s.Control("Height","FPCompactSlider")==height)
        Actions()
        assert(window._focalPointPropertyScroll.status.scrollvalue==0)
    end
    s.h.Equal(db,before)
end)
Test("Power colors, media open/Apply and border fields preserve other component targets",function()
    local others=OtherFields(unit)
    s.Control("Texture","Button"):Fire("OnClick")
    local media=assert(s.Media()); local before=s.h.Copy(db)
    -- Opening/choosing no item leaves the canonical data untouched; native Cancel is a client gate.
    s.h.Equal(db,before)
    media.onApply("fp:statusbar:flat-white"); s.Drain()
    assert(unit.powerBarTexture=="fp:statusbar:flat-white")
    s.Control("Color","ColorPicker"):Fire("OnValueConfirmed",.3,.4,.5,.6)
    s.Control("Background Color","ColorPicker"):Fire("OnValueConfirmed",.2,.1,.3,.4)
    s.Control("Border Width","FPCompactSlider"):Fire("OnValueChanged",2)
    s.Control("Border Color","ColorPicker"):Fire("OnValueConfirmed",.4,.2,.1,0)
    assert(unit.powerColor[4]==.6 and unit.powerBackgroundColor[4]==.4)
    assert(unit.powerBarBorderWidth==2 and unit.powerBarBorderColor[4]==0)
    s.h.Equal(OtherFields(unit),others)
end)
Test("Class Color, Background and Show rebuild dependencies retain the active category",function()
    local old=s.Tabs().geometry.events.OnClick
    s.Control("Class Color","CheckBox"):Fire("OnValueChanged",true); s.Drain()
    assert(unit.useClassColorPower and s.Control("Color","ColorPicker").disabled)
    old(); Check("appearance")
    s.Control("Class Color","CheckBox"):Fire("OnValueChanged",false); s.Drain()
    assert(not s.Control("Color","ColorPicker").disabled)
    s.Control("Show Background","CheckBox"):Fire("OnValueChanged",false); s.Drain()
    assert(not unit.powerBackground and s.Control("Background Color","ColorPicker").disabled)
    s.Control("Show Background","CheckBox"):Fire("OnValueChanged",true); s.Drain()
    assert(not s.Control("Background Color","ColorPicker").disabled)
    Click("behavior"); s.Control("Show","CheckBox"):Fire("OnValueChanged",false); s.Drain(); Check("behavior")
    for _,item in ipairs({{"Texture","Button"},{"Color","ColorPicker"},{"Class Color","CheckBox"},
        {"Show Background","CheckBox"},{"Background Color","ColorPicker"},{"Height","FPCompactSlider"},
        {"Border Width","FPCompactSlider"},{"Border Color","ColorPicker"}}) do
        assert(s.Control(item[1],item[2]).disabled,item[1])
    end
    s.Control("Show","CheckBox"):Fire("OnValueChanged",true); s.Drain(); Check("behavior")
end)
Test("Height keeps geometry and existing wheel synchronization; Reverse Fill uses Behavior",function()
    Click("geometry")
    local height=s.Control("Height","FPCompactSlider")
    assert(height.min==4 and height.max==30 and height.step==1)
    height:Fire("OnValueChanged",15.8); assert(unit.powerBarHeight==16)
    local before=s.h.Copy(db)
    assert(s.ns.GUI.Editor.Inspector.SetActiveCanvasWheelFieldValue("player",
        {kind="bar",unit="player",objectKey="PowerBar"},"powerBarHeight",22))
    assert(height:GetValue()==22); s.h.Equal(db,before)
    assert(not s.ns.GUI.Editor.Inspector.SetActiveCanvasWheelFieldValue("player",
        {kind="bar",unit="player",objectKey="NormalAbsorbBar"},"powerBarHeight",24))
    s.state.SetMode("expert"); s.controller.BuildInspector(nil,{GetEditorState=s.state.Get}); s.Drain(); Check("geometry")
    local reverse=s.Control("Reverse Fill","CheckBox")
    Click("behavior");Check("behavior")
    reverse:Fire("OnValueChanged",true); assert(unit.powerBarReverseFill)
    local group=reverse.parent.parent.parent
    assert(group:GetUserData("normalAbsorbPropertyGroup")=="behavior" and group.frame:IsShown())
    Click("behavior"); s.Control("Show","CheckBox"):Fire("OnValueChanged",false); s.Drain()
    assert(s.Control("Reverse Fill","CheckBox").disabled)
    s.Control("Show","CheckBox"):Fire("OnValueChanged",true); s.Drain()
    s.state.SetMode("quick"); s.controller.BuildInspector(nil,{GetEditorState=s.state.Get}); s.Drain()
    assert(HasRow("Reverse Fill")); Check("behavior")
end)
Test("empty property groups disable with canonical fallback while the action stays independent",function()
    for _,child in ipairs(Body().children) do
        if child:GetUserData("normalAbsorbPropertyGroup")=="geometry" and child:GetUserData("normalAbsorbPropertyContent") then
            child:ReleaseChildren()
        end
    end
    s.state.SetInspectorPropertyGroup("geometry")
    assert(s.state.ResolveInspectorPropertyGroup({appearance=true,behavior=true})=="appearance")
    Click("behavior"); assert(s.Tabs().geometry.disabled); Click("geometry")
    assert(s.state.Get().inspectorPropertyGroup=="behavior"); Actions()
    s.controller.RefreshActiveProperties(); s.Drain(); Check("behavior")
end)
Test("Power/Absorb pooling invalidates old callbacks and preserves one shared session category",function()
    s.controller.RefreshActiveProperties(); s.Drain(); Click("geometry"); Check("geometry")
    for _=1,15 do
        local old=s.Tabs().appearance.events.OnClick
        s.Select("NormalAbsorbBar"); old(); assert(s.state.Get().inspectorPropertyGroup=="geometry")
        s.Select("HealingAbsorbBar"); assert(s.state.Get().inspectorPropertyGroup=="geometry")
        old=s.Tabs().appearance.events.OnClick
        s.Select("PowerBar"); old(); Check("geometry")
    end
    local old=s.Tabs().appearance.events.OnClick
    Actions()
    s.Select("HealthBar"); old()
    assert(s.Tabs().geometry.disabled and not s.Tabs().behavior.disabled)
    assert(s.state.Get().inspectorPropertyGroup=="appearance")
    s.Select("PowerBar"); Check("appearance")
    window.closebutton:GetScript("OnClick")(window.closebutton); s.Drain()
    window=s.Build(); Check("appearance")
    window.closebutton:GetScript("OnClick")(window.closebutton); s.Drain()
    window=s.Build(); Check("appearance")
end)
Test("unit/layout changes and narrow German tabs preserve current Power bindings",function()
    local root=s.ns.ActiveLayoutResolver.GetActiveRuntimeRoot()
    root.units.target=s.h.Copy(unit)
    assert(s.selection.SelectObject({kind="bar",unit="target",objectKey="PowerBar"})); s.Drain()
    Click("behavior"); s.Control("Show","CheckBox"):Fire("OnValueChanged",false); s.Drain()
    assert(not root.units.target.showPowerBar and unit.showPowerBar)
    s.Select("PowerBar")
    local ok,id=s.ns.LayoutMutations.CopyLayout("layout:existing",nil,{activate=false}); assert(ok)
    assert(s.ns:ActivateLayout(id)); s.controller.BuildInspector(nil,{GetEditorState=s.state.Get}); s.Drain()
    local active=s.ns.UnitFrameUtils.GetUnitDB("player")
    s.Control("Show","CheckBox"):Fire("OnValueChanged",false); s.Drain()
    assert(active~=unit and not active.showPowerBar and unit.showPowerBar)
    local labels={s.ns.L.EDITOR_PROPERTY_APPEARANCE,s.ns.L.SECTION_SIZE_POSITION,s.ns.L.SECTION_BEHAVIOR}
    local width=UIParent:GetWidth()
    s.ns.L.EDITOR_PROPERTY_APPEARANCE="Aussehen"; s.ns.L.SECTION_SIZE_POSITION="Größe & Position"; s.ns.L.SECTION_BEHAVIOR="Verhalten"
    UIParent:SetWidth(600); s.controller.BuildInspector(nil,{GetEditorState=s.state.Get}); s.Drain(); Check("behavior")
    local total=0; for _,tab in pairs(s.Tabs()) do total=total+tab.frame:GetWidth() end
    assert(total<=s.Tabs().appearance.parent.frame:GetWidth())
    UIParent:SetWidth(width)
    s.ns.L.EDITOR_PROPERTY_APPEARANCE,s.ns.L.SECTION_SIZE_POSITION,s.ns.L.SECTION_BEHAVIOR=table.unpack(labels)
end)
Test("Remove remains absent in every tab and after rebuild without changing component presence",function()
    for _,key in ipairs({"appearance","geometry","behavior"}) do
        window,unit,db=s.Start(); Click(key)
        local other=OtherFields(unit); Actions()
        s.controller.RefreshActiveProperties(); s.Drain()
        Actions()
        assert(unit.powerBarPresent and s.selection.GetSelectedObject().objectKey=="PowerBar")
        s.h.Equal(OtherFields(unit),other)
    end
end)
Test("non-Workspace scoped Power retains its committed framed Inspector",function()
    window,unit,db=s.Start()
    local host=s.h.ui.ace:Create("SimpleGroup")
    s.ns.GUI.Editor.Inspector.BuildProperties(host,s.state.Get(),{getUnitConfig=s.ns.UnitFrameUtils.GetUnitDB})
    local groups={}; s.Walk(host,function(w)
        assert(not w:GetUserData("normalAbsorbPropertyTab"))
        if w.type=="InlineGroup" then groups[#groups+1]=w.titletext:GetText() end
    end)
    assert(table.concat(groups,",")=="General,Appearance,Background,Geometry,Behavior,Actions")
    s.h.ui.ace:Release(host)
end)
Test("Power CUSTOM fields, framed Size/Anchor groups and mode round trips preserve canonical settings",function()
    for _,mode in ipairs({"quick","expert"})do
        window,unit,db=s.Start(mode);Click("geometry")
        local unaffected=OtherFields(unit)
        s.Control("Size Mode","Dropdown"):Fire("OnValueChanged","CUSTOM");s.Drain();Check("geometry")
        local height=s.Control("Height","FPCompactSlider");assert(height.min==1 and height.max==128)
        for _,item in ipairs({{"Width","FPCompactSlider"},{"Anchor Target","Dropdown"},{"Anchor From","Dropdown"},
            {"Anchor To","Dropdown"},{"Offset X","FPCompactSlider"},{"Offset Y","FPCompactSlider"}})do
            assert(not s.Control(item[1],item[2]).disabled,item[1])
        end
        local groups={}
        for _,child in ipairs(Body().children)do
            if child.type=="InlineGroup" and child:GetUserData("normalAbsorbPropertyGroup")=="geometry"then
                groups[#groups+1]=child.titletext:GetText()
            end
        end
        assert(table.concat(groups,",")=="Size,Anchor")
        height:Fire("OnValueChanged",41);s.Control("Width","FPCompactSlider"):Fire("OnValueChanged",173)
        s.Control("Anchor Target","Dropdown"):Fire("OnValueChanged","HealthBar")
        s.Control("Anchor From","Dropdown"):Fire("OnValueChanged","TOPLEFT")
        s.Control("Anchor To","Dropdown"):Fire("OnValueChanged","BOTTOMRIGHT")
        s.Control("Offset X","FPCompactSlider"):Fire("OnValueChanged",27)
        s.Control("Offset Y","FPCompactSlider"):Fire("OnValueChanged",-39)
        local values={powerBarWidth=173,powerBarHeight=41,powerBarAnchorTo="HealthBar",powerBarPoint="TOPLEFT",
            powerBarRelativePoint="BOTTOMRIGHT",powerBarOffsetX=27,powerBarOffsetY=-39}
        local function Retained()for key,value in pairs(values)do assert(unit[key]==value,key)end end
        Retained();s.h.Equal(OtherFields(unit),unaffected)
        local before=s.h.Copy(db)
        assert(s.ns.GUI.Editor.Inspector.SetActiveCanvasDirectMoveAnchorValues("player",
            {kind="bar",unit="player",objectKey="PowerBar"},{point="RIGHT",relativePoint="LEFT",offsetX=31,offsetY=-42}))
        s.h.Equal(db,before)
        assert(s.Control("Offset X","FPCompactSlider"):GetValue()==31)
        s.controller.RefreshActiveProperties();s.Drain();Retained()
        s.Control("Size Mode","Dropdown"):Fire("OnValueChanged","MATCH_TARGET");s.Drain();Retained()
        assert(s.Control("Width","FPCompactSlider").disabled and s.Control("Anchor From","Dropdown").disabled)
        assert(not s.Control("Height","FPCompactSlider").disabled and s.Control("Height","FPCompactSlider").max==30)
        s.Control("Size Mode","Dropdown"):Fire("OnValueChanged","CUSTOM");s.Drain();Retained()
        s.Control("Show","CheckBox"):Fire("OnValueChanged",false);s.Drain()
        for _,item in ipairs({{"Size Mode","Dropdown"},{"Height","FPCompactSlider"},{"Width","FPCompactSlider"},
            {"Anchor Target","Dropdown"},{"Anchor From","Dropdown"},{"Anchor To","Dropdown"},
            {"Offset X","FPCompactSlider"},{"Offset Y","FPCompactSlider"}})do assert(s.Control(item[1],item[2]).disabled,item[1]) end
        s.Control("Show","CheckBox"):Fire("OnValueChanged",true);s.Drain();Retained()
        local stale=s.Control("Offset X","FPCompactSlider");local callback=stale.events.OnValueChanged
        s.Select("NormalAbsorbBar")
        assert(stale.events.OnValueChanged~=callback,"released Power binding still owns the widget callback")
        before=s.h.Copy(db)
        assert(not s.ns.GUI.Editor.Inspector.SetActiveCanvasDirectMoveOffsetValues("player",
            {kind="bar",unit="player",objectKey="PowerBar"},99,99))
        s.h.Equal(db,before)
        s.Select("PowerBar");s.controller.RefreshActiveProperties();s.Drain();Retained()
        window.closebutton:GetScript("OnClick")(window.closebutton);s.Drain();window=s.Build();s.Select("PowerBar");Retained()
    end
end)
Test("Power CUSTOM layout replacement binds the new record and preserves the old configuration",function()
    window,unit,db=s.Start("quick");Click("geometry")
    s.Control("Size Mode","Dropdown"):Fire("OnValueChanged","CUSTOM");s.Drain()
    s.Control("Width","FPCompactSlider"):Fire("OnValueChanged",173)
    local oldMode=s.Control("Size Mode","Dropdown");local callback=oldMode.events.OnValueChanged
    local ok,id=s.ns.LayoutMutations.CopyLayout("layout:existing",nil,{activate=false});assert(ok)
    assert(s.ns:ActivateLayout(id));s.controller.BuildInspector(nil,{GetEditorState=s.state.Get});s.Drain()
    local active=s.ns.ActiveLayoutResolver.GetActiveRuntimeRoot().units.player
    assert(active~=unit and active.powerBarSizeMode=="CUSTOM" and s.Control("Width","FPCompactSlider"):GetValue()==173)
    assert(oldMode.events.OnValueChanged~=callback,"old layout still owns the widget callback")
    s.Control("Width","FPCompactSlider"):Fire("OnValueChanged",99)
    assert(active.powerBarWidth==99 and unit.powerBarWidth==173)
end)
assert(#s.h.ui.env.errors==0,table.concat(s.h.ui.env.errors,"\n"))
print("Power Bar Property Groups: "..count.." groups PASS")
