-- Real data mutations, projection, selection and Inspector with native UI doubles.
local function Read(path)local f=assert(io.open(path));local s=f:read("*a");f:close();return s end
local source=Read("Tests/SegmentedBarMutations.lua")
local stop=assert(source:find('Test("add,',1,true))
local ns,Setup,Add,Context,M,Copy,Equal=assert(load(source:sub(1,stop-1)..
    "\nreturn ns,Setup,Add,Context,M,Copy,Equal","@SegmentedBarSelection/Data"))()
local AddDefault=Add
Add=function(values)
    return AddDefault(values or {enabled=true,dataSource={id="runes",scope="player"},anchorTo="Frame"})
end
local ui=assert(load(Read("Tests/DialogWindowFamily.lua").."\nreturn f","@Tests/DialogWindowFamily.lua"))()
dofile("Libraries/Ace3/AceGUI-3.0/widgets/AceGUIWidget-ColorPicker.lua")
ns.GUI=ui.ns.GUI;ns.Constants={UnitOrder={"player","target"}}
ns.UnitFrameUtils={GetUnitsDB=function()return ns.ActiveLayoutResolver.GetActiveRuntimeRoot().units end,
    GetUnitDB=function(key)return ns.ActiveLayoutResolver.GetActiveRuntimeRoot().units[key]end}
local projections=0
ns.GUI.Editor.Controller={ApplyObjectSelectionProjection=function()projections=projections+1 end}
local function Load(path)assert(loadfile(path))("FocalPoint",ns)end
for _,path in ipairs({"GUI/Editor/EditorState.lua","GUI/Editor/Composition/CompositionOwnership.lua",
    "GUI/Editor/Composition/CompositionPresence.lua","GUI/Editor/EditorPresencePolicy.lua",
    "GUI/Editor/ObjectSelection.lua","GUI/Editor/Composition/CompositionTreeAdapter.lua",
    "GUI/Editor/Composition/CompositionTreeControl.lua","GUI/Editor/Composition/CompositionTreeView.lua",
    "GUI/Editor/SelectionGeometryResolver.lua","GUI/Editor/Inspector/InspectorContext.lua",
    "GUI/Editor/SidebarShared.lua","GUI/Editor/Inspector/InspectorController.lua"})do Load(path)end
local state=ns.GUI.Editor.State
local selection=ns.GUI.Editor.ObjectSelection
local tree=ns.CompositionTreeAdapter
local function Find(fn,name,seen)
    seen=seen or {};if seen[fn]then return end;seen[fn]=true
    for i=1,100 do local k,v=debug.getupvalue(fn,i);if not k then break end
        if k==name then return v end
        if type(v)=="function" then local found=Find(v,name,seen);if found then return found end end
    end
end
local click=assert(Find(ns.CompositionTreeView.Build,"SelectTreeNode"))
local active=assert(Find(ns.CompositionTreeView.Build,"IsActiveNode"))
local count=0
local function Test(name,fn)fn();count=count+1;print("PASS: "..name)end
local function Nodes()
    local nodes={};for _,node in ipairs(tree.BuildUnitTree("player").children)do
        if node.type=="segmentedBar"then nodes[#nodes+1]=node end
    end;return nodes
end
local function Select(node)assert(click(node,state.Get(),{}));return selection.GetSelectedObject()end
local function BuildInspector(keep)
    local container=ui.ace:Create("SimpleGroup")
    ns.GUI.Editor.Inspector.BuildProperties(container,state.Get(),{getUnitConfig=ns.UnitFrameUtils.GetUnitDB})
    local labels,controls={},{}
    local function Walk(widget)
        assert(widget.type=="SimpleGroup" or widget.type=="InlineGroup" or widget.type=="Label" or widget.type=="Dropdown"
            or widget.type=="FPCompactSlider" or widget.type=="CheckBox" or widget.type=="ColorPicker"
            or widget.type=="Button","unexpected control: "..tostring(widget.type))
        local key=widget.GetUserData and widget:GetUserData("focalPointAnchorKey")
        if key and key:match("^segmentedBar_") then controls[key:sub(14)]=widget end
        if widget.type=="Label"then labels[#labels+1]=widget.label:GetText()end
        for _,child in ipairs(widget.children or {})do Walk(child)end
    end
    Walk(container)
    local selected=selection.GetSelectedObject()
    if selected and selected.kind=="segmentedBar" and not selected.unavailable then
        for _,field in ipairs({"anchorTo","point","relativePoint","width","height","offsetX","offsetY"})do
            assert(controls[field],"missing geometry control: "..field)
        end
    end
    if not keep then ui.ace:Release(container) end
    return table.concat(labels,"\n"),controls,container
end
Test("two nodes, disabled presence, real tree click and independent Inspector identity",function()
    Setup();state.SetSingleSelection("player");state.ClearPropertyScope()
    local a=Add();local b=Add({enabled=false,dataSource={id="runes",scope="player"},anchorTo="Frame"})
    local nodes=Nodes();assert(#nodes==2 and nodes[1].id=="unit:player/segmentedBar:"..a)
    assert(nodes[2].enabled==false and nodes[2].inspectorTarget.objectKey==b)
    for i,node in ipairs(nodes)do
        local selected=Select(node);assert(selected.unit=="player" and selected.objectKey==(i==1 and a or b))
        assert(active(node,state.Get()) and not active(nodes[3-i],state.Get()))
        assert(state.GetPropertyScope().sectionKey=="segmented_bars")
        local text=BuildInspector();assert(text:find("Unit: player",1,true) and text:find(selected.objectKey,1,true),text)
        assert(text:find(i==1 and "Enabled" or "Disabled",1,true),text)
        assert(text:find("Visual runtime and canvas",1,true),text)
    end
    assert(projections==2)
end)
Test("reorder and duplicate preserve selected ID; delete has no foreign/root fallback",function()
    local _,unit=Setup();local a,b=Add(),Add();local nodes=Nodes();Select(nodes[1])
    assert(M.Reorder(Context(),a,2).ok);local reordered=Nodes()
    assert(reordered[2].id==nodes[1].id and selection.GetSelectedObject().objectKey==a)
    local duplicate=M.Duplicate(Context(),a);assert(duplicate.ok and duplicate.id~=a)
    assert(#Nodes()==3 and selection.GetSelectedObject().objectKey==a)
    assert(M.Delete(Context(),a).ok)
    local selected=selection.GetSelectedObject();assert(selected.unavailable and selected.objectKey==nil and selected.kind~="unit")
    local text=BuildInspector();assert(text:find("no longer selected or available",1,true),text)
    for _,node in ipairs(Nodes())do assert(not active(node,state.Get()))end
    assert(not selection.SelectObject({kind="segmentedBar",unit="player",objectKey=a}))
    assert(#unit.segmentedBars==2 and unit.segmentedBars[1].id==b)
end)
Test("layout/root and unit replacement cannot select a same-ID foreign record",function()
    local db,unit=Setup();local a=Add();Select(Nodes()[1])
    db.global.UserLayouts["layout:copy"]={name="Copy",formatVersion=2,payload=ns.LayoutService.CopyPayload({Units={player=unit}})}
    db.char.activeLayoutId="layout:copy";ns.ActiveLayoutResolver.InvalidateActiveRuntimeRoot()
    assert(ns.ActiveLayoutResolver.EnsureActiveRuntimeRoot(db))
    assert(selection.GetSelectedObject().unavailable)
    assert(BuildInspector():find("no longer selected or available",1,true))
    assert(Select(Nodes()[1]).objectKey==a)
    ns.ActiveLayoutResolver.GetActiveRuntimeRoot().units.player=Copy(unit)
    assert(selection.GetSelectedObject().unavailable)
end)
Test("explicit unavailable presence, nil canvas geometry and stable object identity",function()
    local _,unit=Setup();local a=Add();local selected=Select(Nodes()[1])
    local policy=ns.EditorPresencePolicy.ResolveObject("player",selected)
    assert(policy.kind=="segmentedBar" and policy.recordFound and not policy.isPersistent and not policy.isConditional)
    assert(policy.runtimeAvailable==false and policy.targetKey==nil)
    local missing=ns.EditorPresencePolicy.ResolveObject("player",{kind="segmentedBar",objectKey="missing"})
    assert(not missing.recordFound and missing.kind=="segmentedBar" and not missing.fallback)
    assert(ns.GUI.Editor.SelectionGeometryResolver.Resolve({config=unit},selected)==nil)
    assert(ns.CompositionOwnership.IsSameObject(selected,{kind="segmentedBar",unit="player",objectKey=a}))
    assert(not ns.CompositionOwnership.IsSameObject(selected,{kind="segmentedBar",unit="player",objectKey="other"}))
end)
Test("empty/missing and legacy objects unchanged, projection is read-only",function()
    local _,unit=Setup();assert(#Nodes()==0);unit.segmentedBars={};assert(#Nodes()==0)
    unit.classPowerBarPresent=true;unit.showClassPowerBar=true
    unit.Texts={localText={tag="test"}};unit.decorations={{id="decoration-1",enabled=false}}
    unit.Buffs={present=true,enabled=false}
    local before=Copy(unit);tree.BuildUnitTree("player");Equal(unit,before)
    for _,ref in ipairs({{kind="bar",objectKey="ClassPowerBar"},{kind="text",textKey="localText"},
        {kind="decoration",decorationId="decoration-1"},{kind="aura",auraKey="Buffs"}})do
        ref.unit="player";assert(selection.SelectObject(ref),ref.kind.." selection failed");assert(selection.GetSelectedObject().kind==ref.kind,ref.kind.." identity changed")
    end
end)
Test("built-in trees remain unchanged and projection never creates records",function()
    local db=Setup()
    for _,id in ipairs({"default","classic","minimal","modern"})do
        db.char.activeLayoutId="builtin:"..id;ns.ActiveLayoutResolver.InvalidateActiveRuntimeRoot()
        assert(ns.ActiveLayoutResolver.EnsureActiveRuntimeRoot(db))
        local beforeDB=Copy(db);local units=ns.ActiveLayoutResolver.GetActiveRuntimeRoot().units
        local beforeUnits=Copy(units)
        assert(#Nodes()==0)
        Equal(db,beforeDB);Equal(units,beforeUnits)
        for _,unit in pairs(units)do assert(unit.segmentedBars==nil)end
    end
end)
local function CheckPropertyGroups(container, hasRuneTimer)
    local body
    local function FindBody(widget)
        if widget.GetUserData and widget:GetUserData("focalPointSectionKey")=="segmented_bars"
            and widget:GetUserData("focalPointSectionRole")=="content" then body=widget end
        for _,child in ipairs(widget.children or {})do FindBody(child)end
    end
    FindBody(container);assert(body and body._focalPointRequestRebuild,"missing full-body rebuild target")
    local expected={
        {"General","enabled,dataSource"},
        {"Appearance","texture,useBlizzardColor,color,background,backgroundColor"},
        {"Geometry","width,height,spacing"},
        {"Position","anchorTo,point,relativePoint,offsetX,offsetY,growth"},
    }
    if hasRuneTimer then expected[#expected+1]={"Rune Timer","runeTimerFont,runeTimerFontSize,runeTimerFontStyle"}end
    local groups,controls={},{}
    for _,child in ipairs(body.children)do
        if child.type=="InlineGroup"then groups[#groups+1]=child end
    end
    assert(#groups==#expected,"unexpected property group count")
    for i,group in ipairs(groups)do
        assert(group.titletext:GetText()==expected[i][1],"property group order/title changed")
        local fields={}
        local function Walk(widget)
            assert(widget.type~="InteractiveLabel","property group must not collapse")
            local key=widget.GetUserData and widget:GetUserData("focalPointAnchorKey")
            if key and key:match("^segmentedBar_")then
                local field=key:sub(14);fields[#fields+1]=field;controls[field]=widget
            end
            for _,child in ipairs(widget.children or {})do Walk(child)end
        end
        Walk(group)
        assert(table.concat(fields,",")==expected[i][2],"wrong controls in "..expected[i][1]..": "..table.concat(fields,","))
    end
    return body,controls
end
Test("ordered non-collapsible property groups and full-body source rebuild",function()
    local db,unit=Setup();state.SetSingleSelection("player");state.ClearPropertyScope()
    Add();Select(Nodes()[1]);local _,_,container=BuildInspector(true)
    local body,c=CheckPropertyGroups(container,true)
    local old,callback=c.dataSource,c.dataSource.events.OnValueChanged
    c.dataSource:Fire("OnValueChanged","holyPower")
    local rebuilt;rebuilt,c=CheckPropertyGroups(container,false)
    assert(rebuilt==body and unit.segmentedBars[1].dataSource.id=="holyPower")
    local saved=Copy(db);callback(old,"OnValueChanged","runes");Equal(db,saved)
    c.dataSource:Fire("OnValueChanged","auto")
    rebuilt,c=CheckPropertyGroups(container,false);assert(rebuilt==body)
    c.dataSource:Fire("OnValueChanged","runes")
    rebuilt,c=CheckPropertyGroups(container,true);assert(rebuilt==body)
    ui.ace:Release(container)
end)
Test("automatic source shows Rune Timer group only with a resolved rune context",function()
    local _,unit=Setup();state.SetSingleSelection("player");state.ClearPropertyScope()
    Add({enabled=true,dataSource={id="auto",scope="player"},anchorTo="Frame"});Select(Nodes()[1])
    local adapter,frames=ns.UnitFrameSegmentedBars,ns.frames
    assert(loadfile("Engine/UnitFrame/Bars/UnitFrameSegmentedBars.lua"))("FocalPoint",ns)
    for _,class in ipairs({"DEATHKNIGHT","PALADIN","WARRIOR"})do
        ns.frames={player={config=unit,LiveValues={classPowerSnapshot={context={class=class,config=unit,unit="player"}}}}}
        local _,_,container=BuildInspector(true)
        CheckPropertyGroups(container,class=="DEATHKNIGHT");ui.ace:Release(container)
    end
    ns.frames={player={config=unit,LiveValues={}}}
    local _,_,container=BuildInspector(true);CheckPropertyGroups(container,false);ui.ace:Release(container)
    ns.UnitFrameSegmentedBars,ns.frames=adapter,frames
end)
Test("grouping preserves disabled controls, custom alpha zero and combat rejection",function()
    local db,unit=Setup();state.SetSingleSelection("player");state.ClearPropertyScope()
    local id=Add();Select(Nodes()[1])
    assert(M.SetStyle(Context(),id,{useBlizzardColor=false,color={.2,.4,.6,0}}).ok)
    local _,_,container=BuildInspector(true);local _,c=CheckPropertyGroups(container,true)
    assert(not c.color.disabled and unit.segmentedBars[1].color[4]==0)
    local combat=InCombatLockdown;InCombatLockdown=function()return true end
    local saved=Copy(db);c.dataSource:Fire("OnValueChanged","holyPower");Equal(db,saved)
    InCombatLockdown=combat;CheckPropertyGroups(container,true)
    c.enabled:Fire("OnValueChanged",false)
    assert(not c.enabled.disabled and not c.dataSource.disabled)
    assert(c.color.disabled and c.width.disabled and c.offsetX.disabled and c.runeTimerFontSize.disabled)
    CheckPropertyGroups(container,true);ui.ace:Release(container)
end)
print("Segmented Bar Selection: "..count.." groups PASS")
