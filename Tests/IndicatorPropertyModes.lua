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
        local c=w.children or {}
        if c[1] and c[1].type=="Label" and c[1].label:GetText()==label and c[2]then p.Walk(c[2],Add)end
    end)
    return result
end
local function One(label,kind,host)
    local list=Find(host or Body(),label,kind);assert(#list==1,label..": expected exactly one, got "..#list);return list[1]
end
local function Label(name,fallback)return p.ns.L[name] or fallback end
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
            One("Enabled","CheckBox"):Fire("OnValueChanged",false);p.Drain();Check(placement,true)
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
            One("Enabled","CheckBox");One(Label(meta[key].effectLabel,"Effect"),"Dropdown")
            for _,label in ipairs({"Size","Scale","Placement","Anchor To Element","Anchor From","Anchor To","Inside Side","Padding","X Offset","Y Offset"})do
                for _,kind in ipairs({"Dropdown","FPCompactSlider"})do assert(#Find(Body(),label,kind)==0,label)end
            end
            local removes=0;p.Walk(Body(),function(w)
                if w.type=="Button" and w.text:GetText()==Label("EDITOR_REMOVE_INDICATOR_BUTTON","Remove Indicator")then removes=removes+1 end
            end);assert(removes==1);p.h.Equal(db,before)
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
    for _,expert in ipairs({false,true})do for _,indicator in ipairs({"Portrait","RaidTargetIcon"})do
        for _,placement in ipairs({"INSIDE","ATTACHED"})do
            Start(indicator,expert,placement)
            for _,build in ipairs({p.ns.GUI.Editor.Inspector.BuildProperties,p.ns.GUI.Editor.Inspector.Build})do
                local host=p.h.ui.ace:Create("SimpleGroup");p.state.SetSectionCollapsed("indicators",false)
                local before=p.h.Copy(db)
                build(host,p.state.Get(),{getUnitConfig=p.ns.UnitFrameUtils.GetUnitDB})
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
assert(#p.h.ui.env.errors==0,table.concat(p.h.ui.env.errors,"\n"))
print("Indicator Property Modes: "..count.." groups PASS")
