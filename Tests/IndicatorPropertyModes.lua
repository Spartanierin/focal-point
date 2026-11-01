-- Real Workspace, canonical selection, Indicator builder and mutations; no native pixel claim.
local function Read(path)local f=assert(io.open(path));local s=f:read("*a");f:close();return s end
local source=Read("Tests/PowerBarPropertyGroups.lua")
local stop=assert(source:find("\nlocal count=0",1,true))
local p=assert(load(source:sub(1,stop).."\nreturn s","@IndicatorModes/Workspace"))()
for _,path in ipairs({"GUI/Layouts/UnitPortraitDefinition.lua","GUI/Layouts/UnitClassificationIndicatorLayouts.lua",
    "GUI/Editor/Inspector/InspectorIndicatorSelection.lua","GUI/Editor/Inspector/InspectorController.lua"})do
    assert(loadfile(path))("FocalPoint",p.ns)
end
local defaults={};assert(loadfile("Data/Defaults.lua"))("FocalPoint",defaults)
local defaultUnits=defaults:GetDefaultDB().profile.Units
local meta=p.ns.GUI.Editor.SidebarShared.INDICATOR_META
local window,unit,db,key,unitKey
local function Select(indicator)
    assert(p.selection.SelectObject({kind="indicator",unit=unitKey,indicatorKey=indicator}));p.Drain()
end
local function Start(indicator,expert,placement,targetUnit)
    window,unit,db=p.Start(expert and "quick" or "expert")
    db.profile={General={ExpertMode=expert}}
    key,unitKey=indicator,targetUnit or "player"
    if unitKey~="player"then
        local units=p.ns.ActiveLayoutResolver.GetActiveRuntimeRoot().units
        units[unitKey]=p.h.Copy(unit);unit=units[unitKey]
    end
    unit[key]=p.h.Copy(assert(defaultUnits[unitKey][key]));unit[key].present=true;unit[key].enabled=true
    unit[key].placement=placement or "ATTACHED"
    unit[key].effect=meta[key].classification and "PORTRAIT_OVERLAY" or "ICON"
    Select(key)
end
local function Body()
    local body;p.Walk(window._focalPointPropertyScroll,function(w)
        if w:GetUserData("focalPointSectionKey")=="indicators" and w._focalPointRequestRebuild then body=w end
    end);return assert(body)
end
local function Find(host,label,kind)
    local result,seen={},{}
    local function Add(w)if w.type==kind and not seen[w]then result[#result+1]=w;seen[w]=true end end
    p.Walk(host,function(w)
        if w.label and w.label.GetText and w.label:GetText()==label then Add(w)end
        if w.text and w.text.GetText and w.text:GetText()==label then Add(w)end
        local c=w.children or {}
        if c[1] and c[1].type=="Label" and c[1].label:GetText()==label and c[2]then p.Walk(c[2],Add)end
    end)
    return result
end
local function One(label,kind,host)
    local list=Find(host or Body(),label,kind);assert(#list==1,label..": expected exactly one, got "..#list);return list[1]
end
local function Label(name,fallback)return p.ns.L[name] or fallback end
local function Click(tab)p.Tabs()[tab]:Fire("OnClick");p.Drain()end
local function Projection()
    local appearance=meta[key].classification or meta[key].effectListKey=="status"
    local geometry=not meta[key].classification and unit[key].effect~="FRAME_OVERLAY"
    local available={appearance=appearance,geometry=geometry,behavior=true}
    local tabs,order=p.Tabs();assert(table.concat(order,",")=="appearance,geometry,behavior")
    for name,tab in pairs(tabs)do assert(tab.frame:IsShown() and tab.disabled==not available[name],name)end
    local active=p.state.Get().inspectorPropertyGroup;assert(available[active])
    local membership={Appearance="appearance",Geometry="geometry",Position="geometry",Behavior="behavior"}
    local groups={}
    for _,group in ipairs(Body().children)do if group.type=="InlineGroup"then
        local title=group.titletext:GetText();assert(not groups[title]);groups[title]=group
        assert(group.parent==Body() and group.events.OnRelease)
        if membership[title]then
            assert(group:GetUserData("normalAbsorbPropertyGroup")==membership[title])
            assert(group:GetUserData("normalAbsorbPropertyContent"))
            assert(group.frame:IsShown()==(active==membership[title]))
        else
            error("unexpected Workspace group: "..title)
        end
        p.Walk(group,function(w)assert(not w:GetUserData("flatPropertyHeading"),"duplicate heading")end)
    end end
    for _,title in ipairs({"Appearance","Geometry","Position","Behavior"})do assert(groups[title])end
    assert(not groups.Actions)
    assert(#groups.Appearance.children==(appearance and 1 or 0))
    assert(#groups.Behavior.children==1)
    local enabled=One("Enabled","CheckBox");local owner=enabled.parent
    while owner and owner.type~="InlineGroup"do owner=owner.parent end
    assert(owner==groups.Behavior and not enabled.disabled)
    if geometry then
        local placement=One(Label(meta[key].placementLabel,"Placement"),"Dropdown").parent
        while placement and placement.type~="InlineGroup"do placement=placement.parent end
        assert(placement==groups.Position)
        One(Label(meta[key].sizeLabel,"Size"),"FPCompactSlider")
    else
        assert(#groups.Geometry.children==0 and #groups.Position.children==0)
    end
    assert(#Find(Body(),Label("EDITOR_REMOVE_INDICATOR_BUTTON","Remove Indicator"),"Button")==0)
    Body():DoLayout();window._focalPointPropertyScroll:DoLayout()
    local height=0;for _,child in ipairs(Body().children)do if child.frame:IsShown()then height=height+child.frame:GetHeight()end end
    assert(math.abs(Body().frame:GetHeight()-height)<.01,"hidden groups consume scroll height")
    return groups
end
local function Fields(placement)
    local m=meta[key]
    local fields={{Label(m.scaleLabel,"Scale"),"FPCompactSlider","scale",1,"Geometry"}}
    if placement=="INSIDE"then
        fields[#fields+1]={Label("OPTION_ANCHOR_TO_TARGET","Anchor To Element"),"Dropdown","insideAnchorTo","Frame","Position"}
        fields[#fields+1]={Label(m.insideSideLabel,"Inside Side"),"Dropdown","insideSide","LEFT","Position"}
        fields[#fields+1]={Label("OPTION_PADDING","Padding"),"FPCompactSlider","padding",2,"Position"}
    else
        for _,f in ipairs({{"OPTION_ANCHOR_TO_TARGET","Anchor To Element","anchorTo","Frame"},
            {"OPTION_ANCHOR_FROM","Anchor From","point","TOP"},{"OPTION_ANCHOR_TO","Anchor To","relativePoint","TOP"}})do
            fields[#fields+1]={Label(f[1],f[2]),"Dropdown",f[3],f[4],"Position"}
        end
        fields[#fields+1]={Label("OPTION_X_OFFSET","X Offset"),"FPCompactSlider","offsetX",0,"Position"}
        fields[#fields+1]={Label("OPTION_Y_OFFSET","Y Offset"),"FPCompactSlider","offsetY",0,"Position"}
    end
    return fields
end
local function Check(placement,disabled)
    Projection()
    assert(p.selection.GetSelectedObject().indicatorKey==key)
    assert(p.state.Get().propertyScope.kind=="indicator" and p.state.Get().propertyScope.sectionKey=="indicators")
    for _,f in ipairs(Fields(placement))do
        local c=One(f[1],f[2]);assert(c:GetValue()==(unit[key][f[3]] or f[4]) and c.disabled==disabled,f[1])
        local group=c.parent;while group and group.type~="InlineGroup"do group=group.parent end
        assert(group and group.titletext:GetText()==Label("SECTION_"..f[5]:upper(),f[5]))
    end
    local absent=placement=="INSIDE" and {"Anchor From","Anchor To","X Offset","Y Offset"} or {"Inside Side","Padding"}
    for _,label in ipairs(absent)do
        assert(#Find(Body(),label,"Dropdown")==0 and #Find(Body(),label,"FPCompactSlider")==0,label)
    end
end
local count=0
local function Test(name,fn)fn();count=count+1;print("PASS: "..name)end
Test("Portrait and ordinary Indicator expose each applicable row once in both saved modes, preserving data and disabled rules",function()
    for _,expert in ipairs({false,true})do for _,indicator in ipairs({"Portrait","RaidTargetIcon"})do
        for _,placement in ipairs({"INSIDE","ATTACHED"})do
            Start(indicator,expert,placement)
            local initial=p.h.Copy(db);Check(placement,false);p.h.Equal(db,initial)
            local expected=p.h.Copy(unit)
            Click("geometry")
            One(Label(meta[key].scaleLabel,"Scale"),"FPCompactSlider"):Fire("OnValueChanged",1.27);expected[key].scale=1.27
            if placement=="INSIDE"then
                One("Anchor To Element","Dropdown"):Fire("OnValueChanged","HealthBar");expected[key].insideAnchorTo="HealthBar"
                One("Inside Side","Dropdown"):Fire("OnValueChanged","RIGHT");expected[key].insideSide="RIGHT"
                One("Padding","FPCompactSlider"):Fire("OnValueChanged",7.6);expected[key].padding=8
            else
                One("Anchor To Element","Dropdown"):Fire("OnValueChanged","PowerBar");expected[key].anchorTo="PowerBar"
                One("Anchor From","Dropdown"):Fire("OnValueChanged","BOTTOMLEFT");expected[key].point="BOTTOMLEFT"
                One("Anchor To","Dropdown"):Fire("OnValueChanged","TOPRIGHT");expected[key].relativePoint="TOPRIGHT"
                One("X Offset","FPCompactSlider"):Fire("OnValueChanged",-11.6);expected[key].offsetX=-12
                One("Y Offset","FPCompactSlider"):Fire("OnValueChanged",19.6);expected[key].offsetY=20
            end
            p.h.Equal(unit,expected)
            local ref={kind="indicator",unit=unitKey,indicatorKey=key,objectKey=key}
            local before=p.h.Copy(unit)
            assert(p.ns.GUI.Editor.Inspector.SetActiveCanvasWheelFieldValue(unitKey,ref,"scale",1.75))
            assert(One(Label(meta[key].scaleLabel,"Scale"),"FPCompactSlider"):GetValue()==1.75)
            if placement=="ATTACHED"then
                assert(p.ns.GUI.Editor.Inspector.SetActiveCanvasDirectMoveAnchorValues(unitKey,ref,
                    {point="LEFT",relativePoint="RIGHT",offsetX=21,offsetY=-17}))
                assert(One("Anchor From","Dropdown"):GetValue()=="LEFT" and One("Anchor To","Dropdown"):GetValue()=="RIGHT")
                assert(One("X Offset","FPCompactSlider"):GetValue()==21 and One("Y Offset","FPCompactSlider"):GetValue()==-17)
            end
            p.h.Equal(unit,before) -- Canvas synchronization cannot mutate canonical values.
            p.controller.RefreshActiveProperties();p.Drain();Check(placement,false)
            Click("behavior");One("Enabled","CheckBox"):Fire("OnValueChanged",false);p.Drain();Check(placement,true)
            One("Enabled","CheckBox"):Fire("OnValueChanged",true);p.Drain();Check(placement,false)
            for _=1,3 do
                assert(p.selection.SelectObject({kind="bar",unit=unitKey,objectKey="PowerBar"}));p.Drain()
                Select(key);Check(placement,false);p.controller.RefreshActiveProperties();p.Drain();Check(placement,false)
            end
            window.closebutton:GetScript("OnClick")(window.closebutton);p.Drain();window=p.Build();Check(placement,false)
            assert(db.profile.General.ExpertMode==expert and p.state.Get().mode==(expert and "quick" or "expert"))
        end
    end end
end)
Test("placement rebuild changes valid fields without duplicate controls or new records",function()
    for _,indicator in ipairs({"Portrait","RaidTargetIcon"})do
        Start(indicator,false,"ATTACHED")
        for _,placement in ipairs({"INSIDE","ATTACHED","INSIDE"})do
            One(Label(meta[key].placementLabel,"Placement"),"Dropdown"):Fire("OnValueChanged",placement);p.Drain()
            assert(unit[key].placement==placement);Check(placement,false)
        end
    end
end)
Test("Classification and status FRAME_OVERLAY retain their early exits in both saved modes",function()
    for _,expert in ipairs({false,true})do
        for _,case in ipairs({{"ClassificationIndicator","target"},{"CombatIndicator","player"},{"RestingIndicator","player"}})do
            Start(case[1],expert,"ATTACHED",case[2])
            if not meta[key].classification then unit[key].effect="FRAME_OVERLAY";p.controller.RefreshActiveProperties();p.Drain()end
            local before=p.h.Copy(db)
            Projection()
            One("Enabled","CheckBox");One(Label(meta[key].effectLabel,"Effect"),"Dropdown")
            for _,label in ipairs({"Size","Scale","Placement","Anchor To Element","Anchor From","Anchor To","Inside Side","Padding","X Offset","Y Offset"})do
                for _,kind in ipairs({"Dropdown","FPCompactSlider"})do assert(#Find(Body(),label,kind)==0,label)end
            end
            local removes=0;p.Walk(Body(),function(w)
                if w.type=="Button" and w.text:GetText()==Label("EDITOR_REMOVE_INDICATOR_BUTTON","Remove Indicator")then removes=removes+1 end
            end);assert(removes==0);p.h.Equal(db,before)
            if meta[key].classification then
                for effect in pairs(One(Label(meta[key].effectLabel,"Effect"),"Dropdown").list)do
                    One(Label(meta[key].effectLabel,"Effect"),"Dropdown"):Fire("OnValueChanged",effect)
                    assert(unit[key].effect==effect);p.controller.RefreshActiveProperties();p.Drain();Projection()
                end
            end
            Click("behavior");One("Enabled","CheckBox"):Fire("OnValueChanged",false);p.Drain();Projection()
            assert(One(Label(meta[key].effectLabel,"Effect"),"Dropdown").disabled)
            One("Enabled","CheckBox"):Fire("OnValueChanged",true);p.Drain();Projection()
        end
    end
end)
Test("status Effect rebuilds expose only ICON placement controls and remove them again for FRAME_OVERLAY",function()
    for _,expert in ipairs({false,true})do
        for _,indicator in ipairs({"CombatIndicator","RestingIndicator"})do
            Start(indicator,expert,"ATTACHED");Check("ATTACHED",false)
            for _=1,2 do
                One(Label(meta[key].effectLabel,"Effect"),"Dropdown"):Fire("OnValueChanged","FRAME_OVERLAY");p.Drain()
                assert(unit[key].effect=="FRAME_OVERLAY" and #Find(Body(),"Scale","FPCompactSlider")==0)
                One(Label(meta[key].effectLabel,"Effect"),"Dropdown"):Fire("OnValueChanged","ICON");p.Drain()
                assert(unit[key].effect=="ICON");Check("ATTACHED",false)
            end
        end
    end
end)
Test("Legacy scoped and unscoped builds retain profile-driven Quick/Expert filtering",function()
    for _,expert in ipairs({false,true})do for _,indicator in ipairs({"Portrait","RaidTargetIcon","LeaderIcon","RoleIcon",
        "ReadyCheckIndicator","CombatIndicator","RestingIndicator"})do
        for _,placement in ipairs({"INSIDE","ATTACHED"})do
            Start(indicator,expert,placement)
            for _,build in ipairs({p.ns.GUI.Editor.Inspector.BuildProperties,p.ns.GUI.Editor.Inspector.Build})do
                local host=p.h.ui.ace:Create("SimpleGroup");p.state.SetSectionCollapsed("indicators",false)
                local before=p.h.Copy(db)
                build(host,p.state.Get(),{getUnitConfig=p.ns.UnitFrameUtils.GetUnitDB})
                p.Walk(host,function(w)assert(not w:GetUserData("normalAbsorbPropertyTab"),"Legacy gained tabs")end)
                local indicatorBody;p.Walk(host,function(w)
                    if w:GetUserData("focalPointSectionKey")=="indicators" and w._focalPointRequestRebuild then
                        assert(not indicatorBody);indicatorBody=w
                    end
                end)
                assert(indicatorBody,"Legacy did not build the selected indicator")
                One("Enabled","CheckBox",indicatorBody)
                One(Label(meta[key].sizeLabel,"Size"),"FPCompactSlider",indicatorBody)
                One(Label(meta[key].placementLabel,"Placement"),"Dropdown",indicatorBody)
                for _,f in ipairs(Fields(placement))do
                    local controls=Find(indicatorBody,f[1],f[2]);assert(#controls==(expert and 1 or 0),f[1])
                    if expert then assert(controls[1]:GetValue()==(unit[key][f[3]] or f[4]))end
                end
                p.h.Equal(db,before);p.h.ui.ace:Release(host)
            end
        end
    end end
end)
local cases={{"Portrait","player"},{"RaidTargetIcon","player"},{"LeaderIcon","player"},{"RoleIcon","player"},
    {"ReadyCheckIndicator","player"},{"CombatIndicator","player"},{"RestingIndicator","player"},{"ClassificationIndicator","target"}}
Test("Legacy Classification and FRAME_OVERLAY keep their supported-only fields without Workspace tabs",function()
    for _,expert in ipairs({false,true})do
        for _,case in ipairs({{"ClassificationIndicator","target"},{"CombatIndicator","player"},{"RestingIndicator","player"}})do
            Start(case[1],expert,"ATTACHED",case[2])
            if not meta[key].classification then unit[key].effect="FRAME_OVERLAY"end
            for _,build in ipairs({p.ns.GUI.Editor.Inspector.BuildProperties,p.ns.GUI.Editor.Inspector.Build})do
                local host=p.h.ui.ace:Create("SimpleGroup");p.state.SetSectionCollapsed("indicators",false)
                local before=p.h.Copy(db);build(host,p.state.Get(),{getUnitConfig=p.ns.UnitFrameUtils.GetUnitDB})
                p.Walk(host,function(w)assert(not w:GetUserData("normalAbsorbPropertyTab"))end)
                local body;p.Walk(host,function(w)
                    if w:GetUserData("focalPointSectionKey")=="indicators" and w._focalPointRequestRebuild then assert(not body);body=w end
                end);assert(body)
                One("Enabled","CheckBox",body);One(Label(meta[key].effectLabel,"Effect"),"Dropdown",body)
                for _,label in ipairs({"Size","Scale","Placement","Anchor To Element","Anchor From","Anchor To","Padding","X Offset","Y Offset"})do
                    for _,kind in ipairs({"Dropdown","FPCompactSlider"})do assert(#Find(body,label,kind)==0,label)end
                end
                One(Label("EDITOR_REMOVE_INDICATOR_BUTTON","Remove Indicator"),"Button",body)
                p.h.Equal(db,before);p.h.ui.ace:Release(host)
            end
        end
    end
end)
Test("all eight types project their supported fields in both saved modes and retain empty-tab fallback",function()
    for _,expert in ipairs({false,true})do for _,case in ipairs(cases)do
        for _,placement in ipairs(meta[case[1]].classification and {"ATTACHED"} or {"ATTACHED","INSIDE"})do
            Start(case[1],expert,placement,case[2]);local before=p.h.Copy(db)
            if meta[key].classification then Projection()else Check(placement,false)end
            for _,tab in ipairs({"appearance","geometry","behavior"})do
                local disabled=p.Tabs()[tab].disabled;local active=p.state.Get().inspectorPropertyGroup
                Click(tab);Projection()
                assert(p.state.Get().inspectorPropertyGroup==(disabled and active or tab))
            end
            assert(db.profile.General.ExpertMode==expert and p.state.Get().mode==(expert and "quick" or "expert"))
            p.h.Equal(db,before)
            Click("behavior");One("Enabled","CheckBox"):Fire("OnValueChanged",false);p.Drain()
            local groups=Projection();assert(unit[key].enabled==false)
            for _,title in ipairs({"Appearance","Geometry","Position"})do p.Walk(groups[title],function(w)
                if w.type=="Dropdown" or w.type=="FPCompactSlider"then assert(w.disabled,"disabled rule: "..title)end
            end)end
            One("Enabled","CheckBox"):Fire("OnValueChanged",true);p.Drain();Projection();assert(unit[key].enabled==true)
        end
    end end
end)
Test("tab cycles retain owners, release bindings and controls without allocations or mutation",function()
    for _,case in ipairs(cases)do
        Start(case[1],false,"ATTACHED",case[2]);local groups=Projection();local body=Body()
        local enabled=One("Enabled","CheckBox");local releases={}
        for title,group in pairs(groups)do releases[title]=group.events.OnRelease end
        local before=p.h.Copy(db);local a,r,t=p.Stats()
        for _=1,20 do for _,tab in ipairs({"appearance","geometry","behavior"})do
            if not p.Tabs()[tab].disabled then
                local changed=p.state.Get().inspectorPropertyGroup~=tab
                window._focalPointPropertyScroll:SetScroll(400);Click(tab)
                local current=Projection();assert(Body()==body and One("Enabled","CheckBox")==enabled)
                for title,group in pairs(groups)do assert(current[title]==group and group.events.OnRelease==releases[title])end
                if changed then assert(window._focalPointPropertyScroll.status.scrollvalue==0)end
            end
        end end
        local aa,rr,tt=p.Stats();assert(a==aa and r==rr and t==tt);p.h.Equal(db,before)
    end
end)
Test("Remove and Actions remain absent from all Workspace tabs for every type and status effect branch",function()
    for _,expert in ipairs({false,true})do for _,case in ipairs(cases)do
        for _,effect in ipairs(meta[case[1]].effectListKey=="status" and {"ICON","FRAME_OVERLAY"} or {"ICON"})do
            for _,tab in ipairs({"appearance","geometry","behavior"})do
                Start(case[1],expert,"ATTACHED",case[2])
                if meta[key].effectListKey=="status"then unit[key].effect=effect;p.controller.RefreshActiveProperties();p.Drain()end
                Projection()
                if not p.Tabs()[tab].disabled then
                    Click(tab);Projection()
                    assert(unit[key].present and p.selection.GetSelectedObject().indicatorKey==key)
                end
            end
        end
    end end
end)
Test("stale tabs reject object, Unit, Layout and Reopen contexts while current projection stays usable",function()
    Start("RaidTargetIcon",false,"ATTACHED")
    unit.Portrait=p.h.Copy(defaultUnits.player.Portrait);unit.Portrait.present=true;unit.Portrait.enabled=true
    local function Capture()local tab=p.Tabs().behavior;return tab,tab.events.OnClick end
    local function Reject(tab,callback)
        local before=p.h.Copy(db);local active=p.state.Get().inspectorPropertyGroup
        callback(tab);p.Drain();assert(p.state.Get().inspectorPropertyGroup==active);p.h.Equal(db,before);Projection()
    end
    local tab,callback=Capture();key="Portrait";Select(key);Reject(tab,callback)
    tab,callback=Capture();window.closebutton:GetScript("OnClick")(window.closebutton);p.Drain();window=p.Build();Reject(tab,callback)
    tab,callback=Capture();local units=p.ns.ActiveLayoutResolver.GetActiveRuntimeRoot().units
    units.target=p.h.Copy(unit);unit=units.target;unitKey="target";key="RaidTargetIcon";Select(key);Reject(tab,callback)
    tab,callback=Capture();local ok,id=p.ns.LayoutMutations.CopyLayout("layout:existing",nil,{activate=false});assert(ok)
    assert(p.ns:ActivateLayout(id));p.controller.BuildInspector(nil,{GetEditorState=p.state.Get});p.Drain()
    unit=p.ns.UnitFrameUtils.GetUnitDB(unitKey);Reject(tab,callback)
end)
assert(#p.h.ui.env.errors==0,table.concat(p.h.ui.env.errors,"\n"))
print("Indicator Property Modes: "..count.." groups PASS")
