-- Real Inspector widgets and mutation paths; no native pixel/Combat proof.
local function Read(path)
    local f=assert(io.open(path));local s=f:read("*a");f:close();return s
end
local fixture=Read("Tests/SegmentedBarSelection.lua")
fixture=fixture:sub(1,assert(fixture:find('Test("two nodes',1,true))-1)
fixture=fixture:gsub('"GUI/Editor/SidebarShared.lua",', '"GUI/Helpers/OptionPaths.lua","GUI/Helpers/OptionValues.lua",' ..
    '"GUI/Editor/Inspector/InspectorMutations.lua","GUI/Editor/Inspector/InspectorRefreshPolicy.lua","GUI/Editor/SidebarShared.lua",',1)
local ns,Setup,Add,Context,M,Copy,Equal,ui,state,selection,tree,Select,Nodes,BuildInspector=assert(load(fixture..
    "\nreturn ns,Setup,Add,Context,M,Copy,Equal,ui,state,selection,tree,Select,Nodes,BuildInspector","@BarBorderInspector/Fixture"))()
local getUnitsDB,getUnitDB=ns.UnitFrameUtils.GetUnitsDB,ns.UnitFrameUtils.GetUnitDB
assert(loadfile("Engine/UnitFrame/Shared/UnitFrameUtils.lua"))("FocalPoint",ns)
ns.UnitFrameUtils.GetUnitsDB,ns.UnitFrameUtils.GetUnitDB=getUnitsDB,getUnitDB
local cases={
    {"healthBar","healthbar"},
    {"powerBar","powerbar","showPowerBar"},
    {"alternativePowerBar","alternativePowerBar","showAlternativePowerBar"},
    {"classPowerBar","classPowerBar","showClassPowerBar"},
    {"castBar","castbar","showCastBar"},
    {"normalAbsorbBar","normalAbsorbBar","showNormalAbsorbBar"},
    {"healingAbsorbBar","healingAbsorbBar","showHealingAbsorbBar"},
}
local count=0
local function Test(name,run)run();count=count+1;print("PASS: "..name)end
local function Prepare()
    local db,unit=Setup();state.SetSingleSelection("player");state.ClearPropertyScope()
    for _,case in ipairs(cases)do unit[case[1].."Present"]=true;if case[3]then unit[case[3]]=true end end
    return db,unit
end
local function Choose(case)
    for _,node in ipairs(tree.BuildUnitTree("player").children)do if node.type==case[2]then Select(node);return end end
    error("missing node "..case[2])
end
local function Inspector()
    local _,_,container=BuildInspector(true)
    local controls,groups,order={},{},{}
    local function Walk(w,group)
        if w.type=="InlineGroup"then group=w.titletext:GetText()end
        local key=w.GetUserData and w:GetUserData("focalPointAnchorKey")
        if key then controls[key]=w;groups[key]=group;order[#order+1]=key end
        for _,child in ipairs(w.children or {})do Walk(child,group)end
    end
    Walk(container);return controls,container,groups,order
end
local function Width(c,prefix,value)c[prefix.."BorderWidth"]:Fire("OnValueChanged",value)end
local function Color(c,key)c[key]:Fire("OnValueConfirmed",.2,.3,.4,0)end
Test("seven classic bars: pure defaults, integer slider, RGBA, Quick/Expert and grouped order",function()
    for _,mode in ipairs({"quick","expert"})do
        for _,case in ipairs(cases)do
            local _,unit=Prepare();state.SetMode(mode);Choose(case)
            local before=Copy(unit);local c,view,groups,order=Inspector();Equal(unit,before)
            local prefix=case[1];local width=assert(c[prefix.."BorderWidth"]);local color=assert(c[prefix.."BorderColor"])
            assert(width:GetValue()==0 and not width.disabled and not color.disabled)
            assert(width.min==0 and width.max==5 and width.step==1)
            assert(color.HasAlpha and color.r==0 and color.g==0 and color.b==0 and color.a==1)
            assert(groups[prefix.."BorderWidth"]==(prefix=="castBar" and "Appearance" or "Background"))
            for i,key in ipairs(order)do if key==prefix.."BorderWidth"then assert(order[i+1]==prefix.."BorderColor")end end
            for _,value in ipairs({1,5,0})do Width(c,prefix,value);assert(unit[prefix.."BorderWidth"]==value)end
            Color(c,prefix.."BorderColor");Equal(unit[prefix.."BorderColor"],{.2,.3,.4,0,r=.2,g=.3,b=.4,a=0})
            ui.ace:Release(view);c,view=Inspector();assert(c[prefix.."BorderWidth"]:GetValue()==0 and c[prefix.."BorderColor"].a==0)
            ui.ace:Release(view)
        end
    end
end)
Test("classic disabled bars reject callbacks and invalid widths preserve stored state",function()
    for _,case in ipairs(cases)do
        local _,unit=Prepare();state.SetMode("quick");Choose(case)
        local prefix=case[1];unit[prefix.."BorderWidth"]=1
        local c,view=Inspector()
        for _,bad in ipairs({-1,6,.5,0/0,math.huge,-math.huge,"1"})do
            Width(c,prefix,bad);assert(unit[prefix.."BorderWidth"]==1 and c[prefix.."BorderWidth"]:GetValue()==1)
        end
        ui.ace:Release(view)
        if case[3]then
            unit[case[3]]=false;c,view=Inspector();local before=Copy(unit)
            assert(c[prefix.."BorderWidth"].disabled and c[prefix.."BorderColor"].disabled)
            Width(c,prefix,5);Color(c,prefix.."BorderColor");Equal(unit,before);ui.ace:Release(view)
        end
    end
end)
Test("classic stale selection, released widgets and replaced layout root cannot mutate",function()
    local _,unit=Prepare();Choose(cases[1]);local c,view=Inspector()
    local callback=c.healthBarBorderWidth.events.OnValueChanged
    Choose(cases[2]);callback(nil,nil,5);assert(unit.healthBarBorderWidth==nil)
    Choose(cases[1]);ui.ace:Release(view);callback(nil,nil,5);assert(unit.healthBarBorderWidth==nil)
    c,view=Inspector();local old=c.healthBarBorderWidth.events.OnValueChanged
    local _,other=Prepare();Choose(cases[1]);old(nil,nil,5)
    assert(unit.healthBarBorderWidth==nil and other.healthBarBorderWidth==nil);ui.ace:Release(view)
end)
Test("two segment instances: common defaults, isolated styles, 0/1/5 and alpha zero",function()
    local _,unit=Prepare();local a,b=Add(),Add();Select(Nodes()[1])
    local before=Copy(unit);local c,view,groups=Inspector();Equal(unit,before)
    assert(c.segmentedBar_borderWidth:GetValue()==0 and c.segmentedBar_borderColor.a==1)
    assert(groups.segmentedBar_borderWidth=="Appearance")
    for _,value in ipairs({0,1,5})do
        c.segmentedBar_borderWidth:Fire("OnValueChanged",value)
        assert(unit.segmentedBars[1].borderWidth==value and unit.segmentedBars[2].borderWidth==nil)
    end
    Color(c,"segmentedBar_borderColor");Equal(unit.segmentedBars[1].borderColor,{.2,.3,.4,0})
    assert(unit.segmentedBars[2].borderColor==nil)
    Select(Nodes()[2]);c.segmentedBar_borderWidth:Fire("OnValueChanged",1);assert(unit.segmentedBars[2].borderWidth==nil)
    ui.ace:Release(view);Select(Nodes()[1]);c,view=Inspector()
    assert(c.segmentedBar_borderWidth:GetValue()==5 and c.segmentedBar_borderColor.a==0)
    ui.ace:Release(view)
end)
Test("segment full-body source rebuild, invalid values, Combat and disabled guards",function()
    local _,unit=Prepare();Add();Select(Nodes()[1]);local c,view=Inspector()
    c.segmentedBar_borderWidth:Fire("OnValueChanged",1)
    for _,bad in ipairs({-1,6,.5,0/0,math.huge,"1"})do
        c.segmentedBar_borderWidth:Fire("OnValueChanged",bad);assert(unit.segmentedBars[1].borderWidth==1)
    end
    local combat=InCombatLockdown;InCombatLockdown=function()return true end
    c.segmentedBar_borderWidth:Fire("OnValueChanged",5);assert(unit.segmentedBars[1].borderWidth==1)
    InCombatLockdown=combat
    local old=c.segmentedBar_borderWidth.events.OnValueChanged
    c.segmentedBar_dataSource:Fire("OnValueChanged","holyPower")
    old(nil,nil,5);assert(unit.segmentedBars[1].borderWidth==1)
    ui.ace:Release(view);c,view=Inspector();assert(c.segmentedBar_borderWidth:GetValue()==1)
    Color(c,"segmentedBar_borderColor");assert(unit.segmentedBars[1].borderColor[4]==0)
    c.segmentedBar_enabled:Fire("OnValueChanged",false)
    assert(c.segmentedBar_borderWidth.disabled and c.segmentedBar_borderColor.disabled)
    c.segmentedBar_borderWidth:Fire("OnValueChanged",5);assert(unit.segmentedBars[1].borderWidth==1)
    ui.ace:Release(view)
end)
print("Bar Border Inspector: "..count.." groups PASS")
