-- Existing Workspace/native boundary, actual Inspector controls, selection and mutations.
local function Read(path)
    local file=assert(io.open(path)); local source=file:read("*a"); file:close(); return source
end
local source=Read("Tests/PowerBarPropertyGroups.lua")
local boundary=assert(source:find("\nlocal count=0",1,true))
local p=assert(load(source:sub(1,boundary).."\nreturn s", "@HealthAltPower/Workspace"))()
local window,unit,db
local function Start(key,mode)
    window,unit,db=p.Start(mode or "quick")
    unit.healthColor={.3,.4,.5,.8}; unit.healthLowColor={1,.1,.1,1}
    unit.useClassColorHealth=false; unit.useReactionColorNpcHealth=false; unit.useLowHealthColor=true
    unit.healthBackground=true; unit.healthBackgroundColor={.1,.1,.1,.4}
    unit.alternativePowerBarPresent=true; unit.showAlternativePowerBar=true
    unit.alternativePowerColor={.2,.3,.4,.7}
    p.Select(key)
end
local function Body(section)
    local found
    p.Walk(window._focalPointPropertyScroll,function(w)
        if w:GetUserData("focalPointSectionKey")==section and w._focalPointRequestRebuild then found=w end
    end)
    return assert(found,section)
end
local function Click(key) p.Tabs()[key]:Fire("OnClick"); p.Drain() end
local function Row(label,kind,required)
    local found
    p.Walk(window._focalPointPropertyScroll,function(w)
        if kind=="Button" and w.type=="Button" and w.text:GetText()==label then found=w end
        local children=w.children or {}
        if children[1] and children[1].type=="Label" and children[1].label:GetText()==label and children[2] then
            p.Walk(children[2],function(c) if c.type==kind then found=c end end)
        end
    end)
    if required~=false then assert(found,label..":"..kind) end
    return found
end
local function Check(section,key,available,actionLabel)
    local tabs,order=p.Tabs()
    assert(table.concat(order,",")=="appearance,geometry,behavior")
    assert(p.state.Get().inspectorPropertyGroup==key)
    for name,tab in pairs(tabs) do
        assert(tab.frame:IsShown() and tab.disabled==not available[name])
        assert((tab.text:GetText() or "")=="" and tab.frame._fpNormalAbsorbTab.label:IsShown())
    end
    local body=Body(section); body:DoLayout(); window._focalPointPropertyScroll:DoLayout()
    local actions,buttons=0,0
    for _,child in ipairs(body.children) do
        local group=child:GetUserData("normalAbsorbPropertyGroup")
        if group then assert(child.frame:IsShown()==(group==key)) end
        if child:GetUserData("normalAbsorbObjectActions") then
            actions=actions+1
            assert(actionLabel and child.frame:IsShown() and child==body.children[#body.children])
            assert(not child:GetUserData("normalAbsorbPropertyContent") and not group)
        end
        assert(not child.frame._fpNormalAbsorbActionDivider or not child.frame._fpNormalAbsorbActionDivider:IsShown()
            or actionLabel,"Health has a decorative action area")
    end
    local framed={}
    p.Walk(body,function(w)
        if w.type=="InlineGroup" then
            assert(section=="health" and w.parent==body)
            local title=w.titletext:GetText();framed[#framed+1]=title
            assert(w:GetUserData("normalAbsorbPropertyGroup")=="appearance")
            assert(w:GetUserData("normalAbsorbPropertyContent") and #w.children>0)
            assert(not w:GetUserData("flatPropertySectionTitle"))
            p.Walk(w,function(child)assert(not child:GetUserData("flatPropertyHeading"),"duplicate section title")end)
        end
        if w.type=="Button" and w.text:GetText()==actionLabel then buttons=buttons+1 end
    end)
    assert(table.concat(framed,",")==(section=="health" and "Appearance,Background" or ""))
    assert(actions==(actionLabel and 1 or 0) and buttons==(actionLabel and 1 or 0))
end
local function Color(label,r,g,b,a) Row(label,"ColorPicker"):Fire("OnValueConfirmed",r,g,b,a) end
local count=0
local function Test(name,fn) fn();count=count+1;print("PASS: "..name) end
Test("Health Workspace exposes existing properties in Quick without synthetic geometry or actions",function()
    Start("HealthBar"); Check("health","appearance",{appearance=true,behavior=true})
    for _,label in ipairs({"Show","Enabled","Width","Height","Anchor Target","Offset X","Offset Y"}) do
        assert(not Row(label,"CheckBox",false) and not Row(label,"FPCompactSlider",false)
            and not Row(label,"Dropdown",false),label)
    end
    Click("geometry");Check("health","appearance",{appearance=true,behavior=true})
    Click("behavior");Check("health","behavior",{appearance=true,behavior=true})
    Click("appearance")
    local before=p.h.Copy(db);local a,r,t=p.Stats()
    for _=1,30 do Click("appearance"); Click("geometry"); Click("behavior") end
    local aa,rr,tt=p.Stats(); assert(a==aa and r==rr and t==tt);p.h.Equal(db,before)
    Click("appearance")
end)
Test("Health frames keep control order, one owner and titles across tabs, rebuild and reuse",function()
    local function Groups()
        local groups={}
        for _,child in ipairs(Body("health").children)do
            if child.type=="InlineGroup"then groups[#groups+1]=child end
        end
        assert(#groups==2)
        for i,expected in ipairs({"Texture,Color,Class Color,Reaction Color,Low Health Color,Low Health Threshold",
            "Show Background,Background Color,Border Width,Border Color"})do
            local labels={}
            for _,row in ipairs(groups[i].children)do
                local first=(row.children or {})[1]
                if first and first.type=="Label"then labels[#labels+1]=first.label:GetText()end
            end
            assert(table.concat(labels,",")==expected,"Health control order changed")
            local padding=assert(groups[i]._fpSectionPadding)
            assert(padding.left==16 and padding.right==16 and padding.top==27 and padding.bottom==13)
        end
        return groups
    end
    local groups=Groups();local texture=Row("Texture","Button")
    local a,r,t=p.Stats()
    for _=1,20 do Click("behavior");Click("appearance")end
    local aa,rr,tt=p.Stats();assert(a==aa and r==rr and t==tt)
    assert(Groups()[1]==groups[1] and Row("Texture","Button")==texture)
    for _=1,10 do
        groups=Groups()
        p.Select("PowerBar")
        for _,group in ipairs(groups)do assert(not group.frame:IsShown(),"released Health frame remained visible")end
        p.Walk(window._focalPointPropertyScroll,function(w)assert(w.type~="InlineGroup","Health frame leaked into Power")end)
        p.Select("HealthBar");Click("appearance")
        p.controller.RefreshActiveProperties();p.Drain()
        Check("health","appearance",{appearance=true,behavior=true});Groups()
    end
    window.closebutton:GetScript("OnClick")(window.closebutton);p.Drain();window=p.Build()
    Check("health","appearance",{appearance=true,behavior=true});Groups()
end)
Test("Health color/media/background/border and Low Health use their original fields",function()
    local power=p.h.Copy(unit.powerColor)
    local before=p.h.Copy(db)
    Row("Texture","Button"):Fire("OnClick"); local media=assert(p.Media())
    p.h.Equal(db,before) -- No Apply: no data mutation; native Cancel is separate.
    media.onApply("fp:statusbar:flat-white"); p.Drain(); assert(unit.healthBarTexture=="fp:statusbar:flat-white")
    Color("Color",.1,.2,.3,.6); Color("Background Color",.3,.2,.1,.5)
    Row("Border Width","FPCompactSlider"):Fire("OnValueChanged",2)
    Color("Border Color",.2,.4,.6,0)
    assert(unit.healthColor[4]==.6 and unit.healthBackgroundColor[4]==.5)
    assert(unit.healthBarBorderWidth==2 and unit.healthBarBorderColor[4]==0)
    Row("Show Background","CheckBox"):Fire("OnValueChanged",false);p.Drain()
    assert(not unit.healthBackground and Row("Background Color","ColorPicker").disabled)
    Row("Show Background","CheckBox"):Fire("OnValueChanged",true);p.Drain()
    Row("Class Color","CheckBox"):Fire("OnValueChanged",true);p.Drain()
    assert(unit.useClassColorHealth and not Row("Color","ColorPicker",false))
    Row("Class Color","CheckBox"):Fire("OnValueChanged",false);p.Drain()
    local low=Row("Low Health Color","CheckBox")
    low:Fire("OnValueChanged",false);p.Drain()
    assert(not unit.useLowHealthColor and Row("Low Health Color","ColorPicker").disabled)
    Row("Low Health Color","CheckBox"):Fire("OnValueChanged",true);p.Drain()
    Color("Low Health Color",.9,.2,.1,.8);assert(unit.healthLowColor[4]==.8)
    p.h.Equal(unit.powerColor,power)
end)
Test("Health Expert preserves conditional colors/threshold and maps Reverse Fill to Behavior",function()
    p.state.SetMode("expert");p.controller.BuildInspector(nil,{GetEditorState=p.state.Get});p.Drain()
    Check("health","appearance",{appearance=true,behavior=true})
    Row("Class Color","CheckBox"):Fire("OnValueChanged",true);p.Drain()
    assert(not Row("Color","ColorPicker",false))
    Row("Class Color","CheckBox"):Fire("OnValueChanged",false);p.Drain()
    Row("Reaction Color","CheckBox"):Fire("OnValueChanged",true);p.Drain()
    assert(unit.useReactionColorNpcHealth and Row("Color","ColorPicker").disabled)
    Row("Reaction Color","CheckBox"):Fire("OnValueChanged",false);p.Drain()
    Row("Low Health Threshold","Dropdown"):Fire("OnValueChanged","25");assert(unit.lowHealthColorThreshold==25)
    Row("Low Health Color","CheckBox"):Fire("OnValueChanged",false);p.Drain()
    assert(not Row("Low Health Threshold","Dropdown",false))
    Click("behavior"); Row("Reverse Fill","CheckBox"):Fire("OnValueChanged",true)
    assert(unit.healthBarReverseFill)
    local old=p.Tabs().appearance.events.OnClick
    p.state.SetMode("quick");p.controller.BuildInspector(nil,{GetEditorState=p.state.Get});p.Drain()
    old();Check("health","behavior",{appearance=true,behavior=true})
end)
Test("Health/previous flat bars keep fallback, rebuilt scope and neutral action cleanup",function()
    for _=1,10 do
        p.Select("PowerBar");Click("behavior")
        local old=p.Tabs().geometry.events.OnClick
        p.Select("HealthBar");old();Check("health","behavior",{appearance=true,behavior=true})
        Click("appearance")
        p.Select("NormalAbsorbBar");assert(p.state.Get().inspectorPropertyGroup=="appearance")
        p.Select("HealingAbsorbBar");assert(p.state.Get().inspectorPropertyGroup=="appearance")
    end
    p.Select("HealthBar");Check("health","appearance",{appearance=true,behavior=true})
    local old=p.Tabs().geometry.events.OnClick
    window.closebutton:GetScript("OnClick")(window.closebutton);p.Drain();old()
    window=p.Build();Check("health","appearance",{appearance=true,behavior=true})
    window.closebutton:GetScript("OnClick")(window.closebutton);p.Drain();window=p.Build()
    Check("health","appearance",{appearance=true,behavior=true})
end)
Test("non-Workspace Health retains its original framed groups and spacing",function()
    for _,mode in ipairs({"quick","expert"}) do
        Start("HealthBar",mode)
        local host=p.h.ui.ace:Create("SimpleGroup")
        p.ns.GUI.Editor.Inspector.BuildProperties(host,p.state.Get(),{getUnitConfig=p.ns.UnitFrameUtils.GetUnitDB})
        local groups={};p.Walk(host,function(w)
            assert(not w:GetUserData("normalAbsorbPropertyTab"))
            if w.type=="InlineGroup" then groups[#groups+1]=w.titletext:GetText() end
        end)
        assert(table.concat(groups,",")== (mode=="quick" and "Appearance,Background" or "Appearance,Background,Behavior"))
        p.h.ui.ace:Release(host)
    end
end)
local altAction=p.ns.L.EDITOR_REMOVE_ALTERNATIVE_POWER_BAR_BUTTON or "Remove Secondary Resource Bar"
Test("Alternative Power has three categories and a stable independent action without tab allocations",function()
    Start("AlternativePowerBar");Check("alt_power","appearance",{appearance=true,geometry=true,behavior=true},altAction)
    assert(p.state.GetPropertyScope().kind=="unit" and p.state.GetPropertyScope().objectKey==nil)
    for _,label in ipairs({"Width","Anchor Target","Offset X","Offset Y","Growth Direction","Size Mode"}) do
        assert(not Row(label,"FPCompactSlider",false) and not Row(label,"Dropdown",false),label)
    end
    local body=Body("alt_power");local height=Row("Height","FPCompactSlider");local remove=Row(altAction,"Button")
    local before=p.h.Copy(db)
    for i=1,30 do
        local key=({"geometry","behavior","appearance"})[(i-1)%3+1]
        local a,r,t=p.Stats();window._focalPointPropertyScroll:SetScroll(400)
        Click(key);Check("alt_power",key,{appearance=true,geometry=true,behavior=true},altAction)
        local aa,rr,tt=p.Stats();assert(a==aa and r==rr and t==tt)
        assert(Body("alt_power")==body and Row("Height","FPCompactSlider")==height and Row(altAction,"Button")==remove)
        assert(window._focalPointPropertyScroll.status.scrollvalue==0)
    end
    p.h.Equal(db,before)
end)
Test("Alternative Power inherits Power defaults without writing them and mutations remain local",function()
    unit.alternativePowerBarTexture=nil;unit.powerBarTexture="fp:statusbar:flat-white"
    unit.alternativePowerBackground=nil;unit.powerBackground=false
    unit.alternativePowerBackgroundColor=nil;unit.powerBackgroundColor={.1,.2,.3,.4}
    unit.alternativePowerBarReverseFill=nil;unit.powerBarReverseFill=true
    p.state.SetMode("expert");p.controller.BuildInspector(nil,{GetEditorState=p.state.Get});p.Drain()
    local before=p.h.Copy(db)
    assert(not Row("Show Background","CheckBox"):GetValue() and Row("Background Color","ColorPicker").disabled)
    assert(Row("Reverse Fill","CheckBox"):GetValue())
    local bg=Row("Background Color","ColorPicker");assert(bg.r==.1 and bg.g==.2 and bg.b==.3 and bg.a==.4)
    Row("Texture","Button"):Fire("OnClick");local media=assert(p.Media())
    assert(media.currentValue==unit.powerBarTexture);p.h.Equal(db,before)
    media.onApply("fp:statusbar:healbot");p.Drain()
    assert(unit.alternativePowerBarTexture=="fp:statusbar:healbot" and unit.powerBarTexture=="fp:statusbar:flat-white")
    Color("Color",.5,.4,.3,.6)
    Row("Show Background","CheckBox"):Fire("OnValueChanged",true);p.Drain()
    Color("Background Color",.2,.3,.4,.5)
    Row("Border Width","FPCompactSlider"):Fire("OnValueChanged",3);Color("Border Color",.3,.2,.1,0)
    Row("Reverse Fill","CheckBox"):Fire("OnValueChanged",false)
    assert(unit.alternativePowerColor[4]==.6 and unit.alternativePowerBackground==true)
    assert(unit.alternativePowerBackgroundColor[4]==.5 and unit.alternativePowerBarBorderWidth==3)
    assert(unit.alternativePowerBarBorderColor[4]==0 and unit.alternativePowerBarReverseFill==false)
    assert(unit.powerBarReverseFill and unit.powerBackground==false and unit.powerBackgroundColor[4]==.4)
    Click("behavior");local old=p.Tabs().appearance.events.OnClick
    Row("Show","CheckBox"):Fire("OnValueChanged",false);p.Drain();old()
    assert(not unit.showAlternativePowerBar)
    for _,item in ipairs({{"Texture","Button"},{"Color","ColorPicker"},{"Show Background","CheckBox"},
        {"Background Color","ColorPicker"},{"Border Width","FPCompactSlider"},{"Border Color","ColorPicker"},
        {"Height","FPCompactSlider"},{"Reverse Fill","CheckBox"}}) do assert(Row(item[1],item[2]).disabled,item[1]) end
    Check("alt_power","behavior",{appearance=true,geometry=true,behavior=true},altAction)
    Row("Show","CheckBox"):Fire("OnValueChanged",true);p.Drain()
end)
Test("Alternative Height retains boundaries, rounding and Wheel; Expert Reverse Fill is geometry",function()
    Click("geometry");local height=Row("Height","FPCompactSlider")
    assert(height.min==4 and height.max==30 and height.step==1)
    local primary=unit.powerBarHeight
    height:Fire("OnValueChanged",17.8);assert(unit.alternativePowerBarHeight==18 and unit.powerBarHeight==primary)
    local before=p.h.Copy(db)
    assert(p.ns.GUI.Editor.Inspector.SetActiveCanvasWheelFieldValue("player",
        {kind="bar",unit="player",objectKey="AlternativePowerBar"},"alternativePowerBarHeight",23))
    assert(height:GetValue()==23);p.h.Equal(db,before)
    assert(Row("Reverse Fill","CheckBox").parent.parent.parent:GetUserData("normalAbsorbPropertyGroup")=="geometry")
    p.state.SetMode("quick");p.controller.BuildInspector(nil,{GetEditorState=p.state.Get});p.Drain()
    assert(not Row("Reverse Fill","CheckBox",false))
    Check("alt_power","geometry",{appearance=true,geometry=true,behavior=true},altAction)
end)
Test("Alternative Power remains Player-only and scope/layout/reopen changes rebind safely",function()
    local root=p.ns.ActiveLayoutResolver.GetActiveRuntimeRoot();root.units.target=p.h.Copy(unit)
    local before=p.h.Copy(db)
    assert(p.selection.SelectObject({kind="unit",unit="target"}));p.Drain()
    p.selection.SelectObject({kind="bar",unit="target",objectKey="AlternativePowerBar"});p.Drain()
    assert(next((p.Tabs()))==nil,"non-Player Alternative Power acquired a workspace")
    p.h.Equal(db,before)
    p.Select("AlternativePowerBar");Click("behavior")
    local old=p.Tabs().geometry.events.OnClick
    p.Select("HealthBar");old();Check("health","behavior",{appearance=true,behavior=true});Click("appearance")
    p.Select("AlternativePowerBar");Check("alt_power","appearance",{appearance=true,geometry=true,behavior=true},altAction)
    local ok,id=p.ns.LayoutMutations.CopyLayout("layout:existing",nil,{activate=false});assert(ok)
    assert(p.ns:ActivateLayout(id));p.controller.BuildInspector(nil,{GetEditorState=p.state.Get});p.Drain()
    local active=p.ns.UnitFrameUtils.GetUnitDB("player")
    Click("behavior");Row("Show","CheckBox"):Fire("OnValueChanged",false);p.Drain()
    assert(active~=unit and not active.showAlternativePowerBar and unit.showAlternativePowerBar)
    window.closebutton:GetScript("OnClick")(window.closebutton);p.Drain();window=p.Build()
    Check("alt_power","behavior",{appearance=true,geometry=true,behavior=true},altAction)
    window.closebutton:GetScript("OnClick")(window.closebutton);p.Drain();window=p.Build()
    Check("alt_power","behavior",{appearance=true,geometry=true,behavior=true},altAction)
end)
Test("Alternative Remove remains unique and functional from every category",function()
    for _,key in ipairs({"appearance","geometry","behavior"}) do
        Start("AlternativePowerBar");Click(key)
        local beforePower=p.h.Copy(unit.powerColor)
        local previous=Row(altAction,"Button").events.OnClick
        p.controller.RefreshActiveProperties();p.Drain()
        local remove=Row(altAction,"Button");assert(remove.events.OnClick~=previous)
        remove:Fire("OnClick");p.Drain()
        assert(not unit.alternativePowerBarPresent and unit.powerBarPresent and p.selection.GetSelectedObject().kind=="unit")
        p.h.Equal(unit.powerColor,beforePower)
    end
end)
Test("non-Workspace Alternative Power keeps its original Quick/Expert groups",function()
    for _,mode in ipairs({"quick","expert"}) do
        Start("AlternativePowerBar",mode)
        local host=p.h.ui.ace:Create("SimpleGroup")
        p.ns.GUI.Editor.Inspector.BuildProperties(host,p.state.Get(),{getUnitConfig=p.ns.UnitFrameUtils.GetUnitDB})
        local groups={};p.Walk(host,function(w)
            assert(not w:GetUserData("normalAbsorbPropertyTab"))
            if w.type=="InlineGroup" then groups[#groups+1]=w.titletext:GetText() end
        end)
        assert(table.concat(groups,",")== (mode=="quick" and "General,Appearance,Background,Geometry,Actions"
            or "General,Appearance,Background,Geometry,Behavior,Actions"))
        p.h.ui.ace:Release(host)
    end
end)
Test("stored profile modes expose identical Health/Power controls without changing General or mutation fields",function()
    for _,expert in ipairs({false,true})do
        Start("HealthBar")
        db.profile={General={ExpertMode=expert}}
        p.state.SetMode(expert and "quick" or "expert") -- Profile must win over the opposite fallback.
        p.controller.BuildInspector(nil,{GetEditorState=p.state.Get});p.Drain()
        Click("appearance")
        local general=p.h.Copy(db.profile.General)
        for _,item in ipairs({{"Reaction Color","CheckBox"},{"Low Health Threshold","Dropdown"},{"Reverse Fill","CheckBox"}})do
            assert(Row(item[1],item[2]))
        end
        Check("health","appearance",{appearance=true,behavior=true})
        Row("Class Color","CheckBox"):Fire("OnValueChanged",true);p.Drain()
        assert(not Row("Color","ColorPicker",false))
        Row("Class Color","CheckBox"):Fire("OnValueChanged",false);p.Drain()
        Row("Reaction Color","CheckBox"):Fire("OnValueChanged",true);p.Drain()
        assert(Row("Color","ColorPicker").disabled)
        Row("Reaction Color","CheckBox"):Fire("OnValueChanged",false);p.Drain()
        Row("Low Health Color","CheckBox"):Fire("OnValueChanged",false);p.Drain()
        assert(not Row("Low Health Threshold","Dropdown",false) and Row("Low Health Color","ColorPicker").disabled)
        Row("Low Health Color","CheckBox"):Fire("OnValueChanged",true);p.Drain()
        assert(Row("Low Health Threshold","Dropdown"))
        local expected=p.h.Copy(unit);expected.healthBarReverseFill=true
        Click("behavior");Check("health","behavior",{appearance=true,behavior=true})
        assert(Row("Reverse Fill","CheckBox").parent.parent.parent:GetUserData("normalAbsorbPropertyGroup")=="behavior")
        Click("geometry");Check("health","behavior",{appearance=true,behavior=true})
        Row("Reverse Fill","CheckBox"):Fire("OnValueChanged",true);p.Drain();p.h.Equal(unit,expected)
        p.Select("PowerBar")
        assert(Row("Show","CheckBox") and Row("Height","FPCompactSlider") and Row("Reverse Fill","CheckBox"))
        for _,item in ipairs({{"Show","CheckBox","behavior"},{"Reverse Fill","CheckBox","behavior"},
            {"Height","FPCompactSlider","geometry"}})do
            assert(Row(item[1],item[2]).parent.parent.parent:GetUserData("normalAbsorbPropertyGroup")==item[3])
        end
        assert(Row("Height","FPCompactSlider").min==4 and Row("Height","FPCompactSlider").max==30)
        expected=p.h.Copy(unit);expected.powerBarReverseFill=true
        Row("Reverse Fill","CheckBox"):Fire("OnValueChanged",true);p.Drain();p.h.Equal(unit,expected)
        Row("Show","CheckBox"):Fire("OnValueChanged",false);p.Drain()
        assert(Row("Reverse Fill","CheckBox").disabled and Row("Height","FPCompactSlider").disabled)
        Row("Show","CheckBox"):Fire("OnValueChanged",true);p.Drain()
        p.h.Equal(db.profile.General,general)
        p.Select("HealthBar")
        window.closebutton:GetScript("OnClick")(window.closebutton);p.Drain();window=p.Build()
        assert(Row("Reaction Color","CheckBox") and Row("Low Health Threshold","Dropdown") and Row("Reverse Fill","CheckBox"))
        local units=p.ns.ActiveLayoutResolver.GetActiveRuntimeRoot().units;units.target=p.h.Copy(unit)
        assert(p.selection.SelectUnitRoot("target"));p.Drain()
        assert(p.selection.SelectObject({kind="bar",unit="target",objectKey="HealthBar"}));p.Drain()
        assert(Row("Reaction Color","CheckBox") and Row("Low Health Threshold","Dropdown") and Row("Reverse Fill","CheckBox"))
        local ok,id=p.ns.LayoutMutations.CopyLayout("layout:existing",nil,{activate=false});assert(ok)
        assert(p.ns:ActivateLayout(id));p.controller.BuildInspector(nil,{GetEditorState=p.state.Get});p.Drain()
        assert(Row("Reaction Color","CheckBox") and Row("Low Health Threshold","Dropdown") and Row("Reverse Fill","CheckBox"))
        p.h.Equal(db.profile.General,general)
    end
end)
Test("Legacy Health and Power retain profile-driven Quick/Expert filtering and original color dependencies",function()
    local function Find(host,label,kind)
        local found;p.Walk(host,function(w)
            local c=w.children or {}
            if c[1] and c[1].type=="Label" and c[1].label:GetText()==label and c[2]then
                p.Walk(c[2],function(control)if control.type==kind then found=control end end)
            end
        end);return found
    end
    for _,expert in ipairs({false,true})do
        for _,key in ipairs({"HealthBar","PowerBar"})do
            Start(key);db.profile={General={ExpertMode=expert}};p.state.SetMode(expert and "quick" or "expert")
            unit.useClassColorHealth=true
            local host=p.h.ui.ace:Create("SimpleGroup")
            p.ns.GUI.Editor.Inspector.BuildProperties(host,p.state.Get(),{getUnitConfig=p.ns.UnitFrameUtils.GetUnitDB})
            assert((Find(host,"Reverse Fill","CheckBox")~=nil)==expert)
            if expert then
                local group=Find(host,"Reverse Fill","CheckBox").parent
                while group and group.type~="InlineGroup"do group=group.parent end
                assert(group and group.titletext:GetText()=="Behavior","Legacy Reverse Fill group changed")
            end
            if key=="HealthBar"then
                assert((Find(host,"Reaction Color","CheckBox")~=nil)==expert)
                assert((Find(host,"Low Health Threshold","Dropdown")~=nil)==expert)
                local appearance;p.Walk(host,function(w)
                    if w.type=="InlineGroup" and w.titletext:GetText()=="Appearance" then appearance=w end
                end)
                assert(appearance and (Find(appearance,"Color","ColorPicker")~=nil)==not expert)
            else
                assert(Find(host,"Height","FPCompactSlider") and Find(host,"Show","CheckBox"))
            end
            assert(db.profile.General.ExpertMode==expert)
            p.h.ui.ace:Release(host)
        end
    end
end)
assert(#p.h.ui.env.errors==0,table.concat(p.h.ui.env.errors,"\n"))
print("Health/Alternative Power Property Groups: "..count.." groups PASS")
