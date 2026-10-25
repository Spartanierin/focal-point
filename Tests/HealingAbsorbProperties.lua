-- Real Inspector controls/mutations in the existing detached UI/data fixture.
-- The media-picker boundary returns an item; native layout remains an ingame check.
local f = assert(io.open("Tests/BarBorderInspector.lua"))
local source = f:read("*a"); f:close()
local stop = assert(source:find("\nlocal count=0", 1, true))
local ns, Setup, Copy, Equal, ui, state, selection = assert(load(source:sub(1, stop) ..
    "\nreturn ns,Setup,Copy,Equal,ui,state,selection", "@HealingAbsorb/Fixture"))()
ns.Ace = ui.ns.Ace
for _, path in ipairs({"GUI/Editor/Inspector/InspectorTextSelection.lua",
    "GUI/Editor/Inspector/InspectorBinding.lua", "GUI/Editor/Inspector/InspectorController.lua"}) do
    assert(loadfile(path))("FocalPoint", ns)
end
local media
ns.GUI.Editor.MediaLibrary = {Open = function(options) media = options end}
local container = ui.ace:Create("SimpleGroup")
local unit, db
local function Select(key)
    assert(selection.SelectObject({kind="bar", unit="player", objectKey=key}))
end
local function Build()
    ns.GUI.Editor.Inspector.BuildProperties(container, state.Get(), {getUnitConfig=ns.UnitFrameUtils.GetUnitDB})
end
local function Scan()
    local groups, rows, shows = {}, {}, {}
    local function Walk(w, group)
        if w.type == "InlineGroup" then
            group = w.titletext:GetText(); groups[#groups + 1] = group
        end
        if w.type == "CheckBox" then
            local row = w.parent and w.parent.parent
            local label = row and row.children and row.children[1]
            if label and label.type == "Label" and label.label:GetText() == "Show" then
                shows[#shows + 1] = w
            end
        end
        local children = w.children or {}
        if children[1] and children[1].type == "Label" and children[2] and children[2].type == "SimpleGroup" then
            local label = children[1].label:GetText()
            rows[label] = {group=group, widget=children[2]}
            rows[tostring(group).."|"..label] = rows[label]
        end
        for _, child in ipairs(children) do Walk(child, group) end
    end
    Walk(container)
    return groups, rows, shows
end
local function Control(label, kind, group)
    local _, rows = Scan(); local row = assert(rows[group and (group.."|"..label) or label], label)
    local function Find(w)
        if w.type == kind then return w end
        for _, child in ipairs(w.children or {}) do local result=Find(child); if result then return result end end
    end
    return assert(Find(row.widget), label .. ":" .. kind), row.group
end
local count = 0
local function Test(name, run) run(); count=count+1; print("PASS: " .. name) end
Test("Healing Absorb retains General Show and separate Appearance/Background groups", function()
    db, unit = Setup(); state.SetSingleSelection("player"); state.ClearPropertyScope()
    unit.healingAbsorbBarPresent=true; unit.showHealingAbsorbBar=true
    state.SetMode("expert"); Select("HealingAbsorbBar")
    local before=Copy(db); Build(); Equal(db,before)
    local groups, _, shows = Scan()
    assert(table.concat(groups, ",") == "General,Appearance,Background,Geometry,Position,Behavior,Actions")
    local root=container.children[#container.children]
    assert(container.children[#container.children-1].frame:GetHeight()==10,"stable outer spacing changed")
    assert(root.children[2].frame:GetHeight()==6,"stable header spacing changed")
    for i,child in ipairs(root.children[3].children) do
        if child.type=="InlineGroup" and i>1 then
            assert(root.children[3].children[i-1].frame:GetHeight()==8,"stable framed-group spacing changed")
        end
    end
    assert(#shows == 1 and shows[1].type == "CheckBox" and shows[1]:GetValue())
    local _, showGroup=Control("Show","CheckBox"); assert(showGroup=="General")
    local _, colorGroup=Control("Color","ColorPicker","Appearance"); assert(colorGroup=="Appearance")
    for _, label in ipairs({"Color","Border Color"}) do
        local _, group=Control(label,"ColorPicker","Background"); assert(group=="Background")
    end
    local _, group=Control("Texture","Button"); assert(group=="Appearance")
    local _, widthGroup=Control("Width","FPCompactSlider"); assert(widthGroup=="Geometry")
    Control("Size Mode","Dropdown"); Control("Height","FPCompactSlider")
    Control("Anchor Target","Dropdown"); Control("Offset X","FPCompactSlider")
    Control("Offset Y","FPCompactSlider"); Control("Growth Direction","Dropdown")
end)
Test("General Show and separate colors use existing fields and survive refresh", function()
    local _,_,shows=Scan(); shows[1]:Fire("OnValueChanged",false)
    assert(unit.showHealingAbsorbBar==false)
    local _,_,current=Scan(); assert(#current==1 and not current[1]:GetValue())
    current[1]:Fire("OnValueChanged",true); assert(unit.showHealingAbsorbBar)
    Control("Texture","Button"):Fire("OnClick"); assert(media and media.onApply)
    media.onApply("fp:statusbar:flat-white"); assert(unit.healingAbsorbBarTexture=="fp:statusbar:flat-white")
    Control("Color","ColorPicker","Appearance"):Fire("OnValueConfirmed",.2,.3,.4,.5)
    Control("Color","ColorPicker","Background"):Fire("OnValueConfirmed",.1,.2,.3,.4)
    Control("Border Width","FPCompactSlider"):Fire("OnValueChanged",3)
    Control("Border Color","ColorPicker"):Fire("OnValueConfirmed",.4,.3,.2,0)
    assert(unit.healingAbsorbBarColor[4]==.5 and unit.healingAbsorbBarBackgroundColor[4]==.4)
    assert(unit.healingAbsorbBarBorderWidth==3 and unit.healingAbsorbBarBorderColor[4]==0)
    Build(); assert(Control("Border Width","FPCompactSlider"):GetValue()==3)
    assert(Control("Border Color","ColorPicker").a==0)
    Control("Texture","Button"):Fire("OnClick"); assert(media.currentValue==unit.healingAbsorbBarTexture)
end)
Test("size mode, dimensions and lower properties retain mutation semantics", function()
    Control("Size Mode","Dropdown"):Fire("OnValueChanged","CUSTOM")
    assert(unit.healingAbsorbBarSizeMode=="CUSTOM")
    assert(not Control("Width","FPCompactSlider").disabled)
    Control("Width","FPCompactSlider"):Fire("OnValueChanged",180)
    Control("Height","FPCompactSlider"):Fire("OnValueChanged",11)
    Control("Offset X","FPCompactSlider"):Fire("OnValueChanged",7)
    Control("Offset Y","FPCompactSlider"):Fire("OnValueChanged",-5)
    Control("Growth Direction","Dropdown"):Fire("OnValueChanged","LEFT_TO_RIGHT")
    assert(unit.healingAbsorbBarWidth==180 and unit.healingAbsorbBarHeight==11)
    assert(unit.healingAbsorbBarOffsetX==7 and unit.healingAbsorbBarOffsetY==-5)
    assert(unit.healingAbsorbBarGrowth=="LEFT_TO_RIGHT")
    Build(); assert(Control("Height","FPCompactSlider"):GetValue()==11)
    Control("Size Mode","Dropdown"):Fire("OnValueChanged","MATCH_TARGET")
    assert(Control("Width","FPCompactSlider").disabled and Control("Height","FPCompactSlider").disabled)
end)
Test("other bars retain their groups; selection and layout rebuild rebind General Show", function()
    local _,_,shows=Scan(); local old=shows[1].events.OnValueChanged
    for _, item in ipairs({{"NormalAbsorbBar","normalAbsorbBarPresent"},{"HealthBar","healthBarPresent"},
        {"PowerBar","powerBarPresent"}}) do
        unit[item[2]]=true; Select(item[1]); Build()
        local groups=Scan(); local found={}; for _,name in ipairs(groups) do found[name]=true end
        assert(found.Background and found.Appearance)
        if item[1]~="HealthBar" then assert(found.General) end
    end
    -- AceGUI may pool the same widget for another field. The old event binding
    -- must be gone; manually invoking a retained function is not a widget event.
    assert(shows[1].events.OnValueChanged~=old)
    assert(selection.SelectObject({kind="text",unit="player",textKey="localText"})); Build()
    local textGroups,_,textShows=Scan(); local found={}
    for _,name in ipairs(textGroups) do found[name]=true end
    assert(found.Content and found.Appearance and found.Position and found.Actions and #textShows==0)
    local before=Copy(db); Build(); Equal(db,before)
    assert(selection.GetSelectedObject().textKey=="localText")
    Select("HealingAbsorbBar"); Build()
    local _,_,current=Scan(); assert(#current==1 and current[1]:GetValue())
    local ok,id=ns.LayoutMutations.CopyLayout("layout:existing",nil,{activate=false}); assert(ok)
    ns.db.char.activeLayoutId=id; ns.ActiveLayoutResolver.InvalidateActiveRuntimeRoot()
    assert(ns.ActiveLayoutResolver.EnsureActiveRuntimeRoot(ns.db))
    Build()
    local _,_,rebuilt=Scan(); assert(#rebuilt==1 and rebuilt[1]:GetValue())
    rebuilt[1]:Fire("OnValueChanged",false)
    local active=ns.UnitFrameUtils.GetUnitDB("player")
    assert(active~=unit and active.showHealingAbsorbBar==false and unit.showHealingAbsorbBar==true)
end)
assert(#ui.env.errors==0,table.concat(ui.env.errors,"\n"))
ui.ace:Release(container)
-- Same real Workspace/Inspector fixture as the Normal pilot; native pixels stay an ingame gate.
do
    local file=assert(io.open("Tests/NormalAbsorbPropertyGroups.lua"))
    local source=file:read("*a"); file:close()
    local boundary=assert(source:find("\nlocal count=0",1,true))
    local w=assert(load(source:sub(1,boundary)..[[
return {h=h,ns=ns,state=state,controller=controller,selection=selection,Drain=Drain,Build=Build,
    Select=Select,Click=Click,Control=Control,Body=Body,Tabs=Tabs,Walk=Walk,Project=CheckProjection,
    Actions=ObjectActions,Media=function() return media end,
    Stats=function() return acquired,released,timers end,
    Start=function()
        db,unit=Setup()
        unit.normalAbsorbBarPresent=true; unit.showNormalAbsorbBar=true
        unit.healingAbsorbBarPresent=true; unit.showHealingAbsorbBar=true
        window=Build(); Select("HealingAbsorbBar")
        return window,unit,db
    end}
]],"@HealingAbsorb/Workspace"))()
    local window,unit,db=w.Start()
    local function NormalFields(config)
        local fields={}
        for key,value in pairs(config) do
            if key=="showNormalAbsorbBar" or key:match("^normalAbsorbBar") then fields[key]=w.h.Copy(value) end
        end
        return fields
    end
    Test("Healing workspace shares three flat tabs with no allocation or data mutation on tab changes",function()
        unit.healingAbsorbBarColor=nil; unit.normalAbsorbBarColor=nil
        w.controller.RefreshActiveProperties(); w.Drain()
        w.Project("appearance")
        local color=w.Control("Color","ColorPicker")
        assert(color.r==.75 and color.g==.20 and color.b==1 and color.a==.62)
        local body=w.Body(); local width=w.Control("Width","FPCompactSlider")
        local before=w.h.Copy(db)
        for i=1,30 do
            local key=({"geometry","behavior","appearance"})[(i-1)%3+1]
            local a,r,t=w.Stats()
            w.Click(key); w.Project(key)
            local aa,rr,tt=w.Stats()
            assert(a==aa and r==rr and t==tt)
            assert(w.Body()==body and w.Control("Width","FPCompactSlider")==width)
        end
        w.h.Equal(db,before)
        w.Walk(body,function(widget) assert(widget.type~="InlineGroup") end)
        w.Select("NormalAbsorbBar")
        color=w.Control("Color","ColorPicker")
        assert(color.r==.66 and color.g==.86 and color.b==1 and color.a==.62)
        w.Select("HealingAbsorbBar"); w.Project("appearance"); w.h.Equal(db,before)
    end)
    Test("Healing appearance and Show mutate only Healing fields and retain bindings after rebuild",function()
        local normal=NormalFields(unit)
        w.Click("appearance")
        w.Control("Texture","Button"):Fire("OnClick")
        local media=assert(w.Media()); media.onApply("fp:statusbar:flat-white"); w.Drain()
        w.Control("Color","ColorPicker"):Fire("OnValueConfirmed",.2,.3,.4,.5)
        w.Control("Background Color","ColorPicker"):Fire("OnValueConfirmed",.1,.2,.3,.4)
        w.Control("Border Width","FPCompactSlider"):Fire("OnValueChanged",3)
        w.Control("Border Color","ColorPicker"):Fire("OnValueConfirmed",.4,.3,.2,0)
        assert(unit.healingAbsorbBarTexture=="fp:statusbar:flat-white")
        assert(unit.healingAbsorbBarColor[4]==.5 and unit.healingAbsorbBarBackgroundColor[4]==.4)
        assert(unit.healingAbsorbBarBorderWidth==3 and unit.healingAbsorbBarBorderColor[4]==0)
        w.Click("behavior")
        local old=w.Tabs().appearance.events.OnClick
        w.Control("Show","CheckBox"):Fire("OnValueChanged",false); w.Drain()
        assert(not unit.showHealingAbsorbBar); old(); w.Project("behavior")
        w.Click("appearance")
        assert(w.Control("Border Width","FPCompactSlider").disabled and w.Control("Border Color","ColorPicker").disabled)
        w.Click("behavior")
        w.Control("Show","CheckBox"):Fire("OnValueChanged",true); w.Drain()
        assert(unit.showHealingAbsorbBar)
        w.h.Equal(NormalFields(unit),normal)
    end)
    Test("Healing geometry preserves Quick/Expert, disabled fields and opposite Growth fallback",function()
        unit.healingAbsorbBarGrowth=nil; unit.normalAbsorbBarGrowth=nil
        local normal=NormalFields(unit)
        w.state.SetMode("quick"); w.controller.RefreshActiveProperties(); w.Drain(); w.Click("geometry")
        assert(w.Control("Growth Direction","Dropdown").value=="RIGHT_TO_LEFT")
        w.Select("NormalAbsorbBar"); w.Project("geometry")
        assert(w.Control("Growth Direction","Dropdown").value=="LEFT_TO_RIGHT")
        w.Select("HealingAbsorbBar")
        local function Points()
            local found={}
            w.Walk(w.Body(),function(widget)
                if widget.type=="Dropdown" then found[widget.label:GetText()]=widget end
            end)
            return found
        end
        assert(not Points()[w.ns.L.OPTION_FROM_POINT or "From Point"])
        w.Control("Size Mode","Dropdown"):Fire("OnValueChanged","CUSTOM"); w.Drain()
        w.Control("Width","FPCompactSlider"):Fire("OnValueChanged",184)
        w.Control("Height","FPCompactSlider"):Fire("OnValueChanged",12)
        w.Control("Offset X","FPCompactSlider"):Fire("OnValueChanged",8)
        w.Control("Offset Y","FPCompactSlider"):Fire("OnValueChanged",-6)
        w.Control("Anchor Target","Dropdown"):Fire("OnValueChanged","Frame"); w.Drain()
        w.state.SetMode("expert"); w.controller.RefreshActiveProperties(); w.Drain()
        Points()[w.ns.L.OPTION_FROM_POINT or "From Point"]:Fire("OnValueChanged","TOPLEFT"); w.Drain()
        Points()[w.ns.L.OPTION_TO_POINT or "To Point"]:Fire("OnValueChanged","BOTTOMLEFT"); w.Drain()
        w.Control("Growth Direction","Dropdown"):Fire("OnValueChanged","LEFT_TO_RIGHT"); w.Drain()
        assert(unit.healingAbsorbBarWidth==184 and unit.healingAbsorbBarHeight==12)
        assert(unit.healingAbsorbBarOffsetX==8 and unit.healingAbsorbBarOffsetY==-6)
        assert(unit.healingAbsorbBarAnchorTo=="Frame" and unit.healingAbsorbBarPoint=="TOPLEFT")
        assert(unit.healingAbsorbBarRelativePoint=="BOTTOMLEFT" and unit.healingAbsorbBarGrowth=="LEFT_TO_RIGHT")
        w.Control("Size Mode","Dropdown"):Fire("OnValueChanged","MATCH_TARGET"); w.Drain()
        assert(w.Control("Width","FPCompactSlider").disabled and w.Control("Height","FPCompactSlider").disabled)
        assert(w.Control("Offset X","FPCompactSlider").disabled and w.Control("Offset Y","FPCompactSlider").disabled)
        assert(Points()[w.ns.L.OPTION_FROM_POINT or "From Point"].disabled)
        w.h.Equal(NormalFields(unit),normal)
    end)
    Test("Healing empty groups disable and fall back without counting its object action",function()
        w.Click("geometry")
        for _,child in ipairs(w.Body().children) do
            if child:GetUserData("normalAbsorbPropertyGroup")=="geometry"
                and child:GetUserData("normalAbsorbPropertyContent") then child:ReleaseChildren() end
        end
        local available={}
        for _,child in ipairs(w.Body().children) do
            if child:GetUserData("normalAbsorbPropertyContent") and #child.children>0 then
                available[child:GetUserData("normalAbsorbPropertyGroup")]=true
            end
        end
        assert(w.state.ResolveInspectorPropertyGroup(available)=="appearance")
        w.Click("behavior"); w.Click("geometry")
        assert(w.state.Get().inspectorPropertyGroup=="behavior" and w.Tabs().geometry.disabled)
        w.Actions()
        w.Click("appearance")
        w.controller.RefreshActiveProperties(); w.Drain(); w.Project("appearance")
    end)
    Test("Healing narrow German labels use the same fitted single-caption tab presentation",function()
        local width=UIParent:GetWidth()
        local labels={w.ns.L.EDITOR_PROPERTY_APPEARANCE,w.ns.L.SECTION_SIZE_POSITION,w.ns.L.SECTION_BEHAVIOR}
        w.ns.L.EDITOR_PROPERTY_APPEARANCE="Aussehen"
        w.ns.L.SECTION_SIZE_POSITION="Größe & Position"
        w.ns.L.SECTION_BEHAVIOR="Verhalten"
        UIParent:SetWidth(600); w.controller.BuildInspector(nil,{GetEditorState=w.state.Get}); w.Drain()
        w.Project("appearance")
        local total=0
        for _,tab in pairs(w.Tabs()) do total=total+tab.frame:GetWidth() end
        assert(total<=w.Tabs().appearance.parent.frame:GetWidth())
        UIParent:SetWidth(width)
        w.ns.L.EDITOR_PROPERTY_APPEARANCE,w.ns.L.SECTION_SIZE_POSITION,w.ns.L.SECTION_BEHAVIOR=table.unpack(labels)
        w.controller.BuildInspector(nil,{GetEditorState=w.state.Get}); w.Drain(); w.Project("appearance")
    end)
    Test("Healing unit/layout/reopen and Normal alternation keep current scope and release old tab callbacks",function()
        unit.powerBarPresent=true; unit.showPowerBar=true
        for _=1,15 do
            local old=w.Tabs().geometry.events.OnClick
            w.Select("NormalAbsorbBar"); old(); w.Project("appearance")
            old=w.Tabs().geometry.events.OnClick
            w.Select("HealingAbsorbBar"); old(); w.Project("appearance")
            old=w.Tabs().geometry.events.OnClick
            w.Select("PowerBar"); old()
            assert(w.state.GetPropertyScope().sectionKey=="power" and w.state.Get().inspectorPropertyGroup=="appearance")
            w.Select("HealingAbsorbBar"); w.Project("appearance")
        end
        local root=w.ns.ActiveLayoutResolver.GetActiveRuntimeRoot()
        root.units.target=w.h.Copy(unit)
        assert(w.selection.SelectObject({kind="bar",unit="target",objectKey="HealingAbsorbBar"})); w.Drain()
        w.Click("behavior"); w.Control("Show","CheckBox"):Fire("OnValueChanged",false); w.Drain()
        assert(not root.units.target.showHealingAbsorbBar and unit.showHealingAbsorbBar)
        w.Select("HealingAbsorbBar"); w.Project("behavior")
        local ok,id=w.ns.LayoutMutations.CopyLayout("layout:existing",nil,{activate=false}); assert(ok)
        assert(w.ns:ActivateLayout(id)); w.controller.BuildInspector(nil,{GetEditorState=w.state.Get}); w.Drain()
        local active=w.ns.UnitFrameUtils.GetUnitDB("player")
        w.Control("Show","CheckBox"):Fire("OnValueChanged",false); w.Drain()
        assert(active~=unit and not active.showHealingAbsorbBar and unit.showHealingAbsorbBar)
        window._focalPointArrangeButton:Fire("OnClick"); w.Drain()
        window=w.Build(); w.Project("behavior")
        window._focalPointCloseButton:Fire("OnClick"); w.Drain()
        window=w.Build(); w.Project("behavior")
    end)
    Test("Healing Remove is unique and tab independent while Normal remains present",function()
        for _,key in ipairs({"appearance","geometry","behavior"}) do
            window,unit,db=w.Start(); w.Click(key)
            local normal=NormalFields(unit)
            local _,remove=w.Actions()
            remove:Fire("OnClick"); w.Drain()
            assert(not w.ns.UnitFrameUtils.GetUnitDB("player").healingAbsorbBarPresent)
            assert(w.selection.GetSelectedObject().kind=="unit")
            w.h.Equal(NormalFields(unit),normal)
        end
        assert(#w.h.ui.env.errors==0,table.concat(w.h.ui.env.errors,"\n"))
    end)
end
print("Healing Absorb Properties: " .. count .. " groups PASS")
