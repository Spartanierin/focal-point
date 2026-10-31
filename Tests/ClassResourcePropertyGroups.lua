-- Real Workspace/Inspector/selection/mutations; native rendering remains a client check.
local function Read(path)
    local f=assert(io.open(path));local source=f:read("*a");f:close();return source
end
local source=Read("Tests/PowerBarPropertyGroups.lua")
local stop=assert(source:find("\nlocal count=0",1,true))
local p=assert(load(source:sub(1,stop).."\nreturn s","@ClassResource/Workspace"))()
local window,unit,db
local function Start(mode)
    window,unit,db=p.Start(mode or "quick")
    unit.classPowerBarPresent=true;unit.showClassPowerBar=true
    unit.useBlizzardColorClassPower=true
    unit.classPowerColor={.3,.4,.5,.8}
    p.Select("ClassPowerBar")
end
local function Body(section)
    local found
    p.Walk(window._focalPointPropertyScroll,function(w)
        if w:GetUserData("focalPointSectionKey")==section and w._focalPointRequestRebuild then found=w end
    end)
    return assert(found,section)
end
local function Click(key) p.Tabs()[key]:Fire("OnClick");p.Drain() end
local function Check(section,key)
    local tabs,order=p.Tabs();assert(table.concat(order,",")=="appearance,geometry,behavior")
    assert(p.state.Get().inspectorPropertyGroup==key)
    for _,tab in pairs(tabs) do
        assert(not tab.disabled and tab.text:GetText()=="" and tab.frame._fpNormalAbsorbTab.label:IsShown())
    end
    local body=Body(section);body:DoLayout();window._focalPointPropertyScroll:DoLayout()
    local actions=0
    for _,child in ipairs(body.children) do
        local group=child:GetUserData("normalAbsorbPropertyGroup")
        if group then assert(child.frame:IsShown()==(group==key)) end
        if child:GetUserData("normalAbsorbObjectActions") then
            actions=actions+1;assert(child.frame:IsShown() and child==body.children[#body.children] and not group)
        end
    end
    assert(actions==1)
    p.Walk(body,function(w)assert(w.type~="InlineGroup")end)
end
local function Label(key,fallback) return p.ns.L[key] or fallback end
local function FindUpvalue(fn,name,seen)
    seen=seen or {};if seen[fn]then return end;seen[fn]=true
    for i=1,100 do
        local key,value=debug.getupvalue(fn,i);if not key then break end
        if key==name then return value end
        if type(value)=="function"then local found=FindUpvalue(value,name,seen);if found then return found end end
    end
end
local count=0
local function Test(name,fn)fn();count=count+1;print("PASS: "..name)end
Test("Class Power Quick has three flat tabs, one action and stable controls without tab mutations",function()
    Start();Check("class_power","appearance")
    local body=Body("class_power");local height=p.Control("Height","FPCompactSlider")
    local before=p.h.Copy(db);local a,r,t=p.Stats()
    for _=1,20 do
        for _,key in ipairs({"geometry","behavior","appearance"})do Click(key);Check("class_power",key)end
    end
    local aa,rr,tt=p.Stats();assert(a==aa and r==rr and t==tt)
    assert(Body("class_power")==body and p.Control("Height","FPCompactSlider")==height);p.h.Equal(db,before)
end)
Test("Class Power keeps Blizzard/color, background, Rune font and disabled Show dependencies",function()
    assert(p.Control("Color","ColorPicker").disabled)
    p.Control(Label("OPTION_BLIZZARD_STANDARD","Blizzard Standard"),"CheckBox"):Fire("OnValueChanged",false);p.Drain()
    assert(not unit.useBlizzardColorClassPower and not p.Control("Color","ColorPicker").disabled)
    p.Control("Color","ColorPicker"):Fire("OnValueConfirmed",.2,.3,.4,0)
    p.Control("Background Color","ColorPicker"):Fire("OnValueConfirmed",.1,.2,.3,.4)
    assert(unit.classPowerColor[4]==0 and unit.classPowerBackgroundColor[4]==.4)
    local before=p.h.Copy(db);p.Control("Font","Button"):Fire("OnClick");p.h.Equal(db,before)
    p.Media().onApply("fp:font:friz-quadrata");p.Drain()
    p.Control("Font Size","FPCompactSlider"):Fire("OnValueChanged",18)
    assert(unit.classPowerRuneTimerFontSize==18)
    Click("behavior");p.Control("Show","CheckBox"):Fire("OnValueChanged",false);p.Drain()
    assert(not unit.showClassPowerBar)
    for _,item in ipairs({{"Texture","Button"},{"Color","ColorPicker"},{"Background Color","ColorPicker"},
        {"Height","FPCompactSlider"},{"Font","Button"},{"Font Size","FPCompactSlider"}})do assert(p.Control(item[1],item[2]).disabled)end
    Check("class_power","behavior")
    p.Control("Show","CheckBox"):Fire("OnValueChanged",true);p.Drain()
end)
Test("Class Power Expert keeps geometry, wheel and direct-move bindings with stale tab guards",function()
    p.state.SetMode("expert");p.controller.BuildInspector(nil,{GetEditorState=p.state.Get});p.Drain()
    Click("geometry");Check("class_power","geometry")
    p.Control("Width","FPCompactSlider"):Fire("OnValueChanged",154)
    p.Control("Offset X","FPCompactSlider"):Fire("OnValueChanged",13)
    p.Control("Height","FPCompactSlider"):Fire("OnValueChanged",19)
    assert(unit.classPowerBarWidth==154 and unit.classPowerBarOffsetX==13 and unit.classPowerBarHeight==19)
    local before=p.h.Copy(db)
    assert(p.ns.GUI.Editor.Inspector.SetActiveCanvasWheelFieldValue("player",
        {kind="bar",unit="player",objectKey="ClassPowerBar"},"classPowerBarHeight",22))
    assert(p.Control("Height","FPCompactSlider"):GetValue()==22);p.h.Equal(db,before)
    local old=p.Tabs().behavior.events.OnClick
    p.Select("HealthBar");old();assert(p.state.Get().inspectorPropertyGroup=="appearance")
    p.Select("ClassPowerBar");Check("class_power","appearance")
end)
Test("Class Power Remove is independent from every tab and non-Workspace keeps framed groups",function()
    for _,key in ipairs({"appearance","geometry","behavior"})do
        Start();Click(key);Check("class_power",key)
        p.Control(Label("EDITOR_REMOVE_CLASS_POWER_BAR_BUTTON","Remove Class Power Bar"),"Button"):Fire("OnClick");p.Drain()
        assert(not unit.classPowerBarPresent and p.selection.GetSelectedObject().kind=="unit")
    end
    for _,mode in ipairs({"quick","expert"})do
        Start(mode);local host=p.h.ui.ace:Create("SimpleGroup")
        p.ns.GUI.Editor.Inspector.BuildProperties(host,p.state.Get(),{getUnitConfig=p.ns.UnitFrameUtils.GetUnitDB})
        local n=0;p.Walk(host,function(w)
            assert(not w:GetUserData("normalAbsorbPropertyTab"));if w.type=="InlineGroup"then n=n+1 end
        end)
        assert(n==(mode=="quick" and 6 or 7));p.h.ui.ace:Release(host)
    end
end)
Test("Workspace Class Power geometry ignores saved mode with unique controls, mutations, disabled and rebuild bindings",function()
    local fields={
        {"Width","FPCompactSlider","classPowerBarWidth",100,40,260},
        {Label("OPTION_CLASS_POWER_BAR_SPACING","Class Power Spacing"),"FPCompactSlider","classPowerBarSpacing",2,0,20},
        {"Anchor Target","Dropdown","classPowerBarAnchorTo","HealthBar"},
        {"Anchor From","Dropdown","classPowerBarPoint","BOTTOMRIGHT"},
        {"Anchor To","Dropdown","classPowerBarRelativePoint","BOTTOMRIGHT"},
        {"Offset X","FPCompactSlider","classPowerBarOffsetX",-5,-200,200},
        {"Offset Y","FPCompactSlider","classPowerBarOffsetY",5,-200,200},
        {Label("OPTION_CLASS_POWER_SEGMENT_GROWTH","Segment Growth"),"Dropdown","classPowerBarGrowth","LEFT_TO_RIGHT"},
    }
    local ref={kind="bar",unit="player",objectKey="ClassPowerBar"}
    for _,expert in ipairs({false,true})do
        Start(expert and "quick" or "expert")
        db.profile={General={ExpertMode=expert}}
        for _,field in ipairs(fields)do unit[field[3]]=nil end
        p.controller.RefreshActiveProperties();p.Drain()
        local profile=p.h.Copy(db.profile);local initial=p.h.Copy(unit)
        local function Controls(disabled)
            assert(p.state.Get().propertyScope.sectionKey=="class_power")
            for _,field in ipairs(fields)do
                local c=p.Control(field[1],field[2]);local n=0
                p.Walk(Body("class_power"),function(w)
                    local children=w.children or {}
                    if children[1] and children[1].type=="Label" and children[1].label:GetText()==field[1]then n=n+1 end
                end)
                assert(n==1,"missing or duplicate Class Power row: "..field[1])
                assert(c.parent.parent.parent:GetUserData("normalAbsorbPropertyGroup")=="geometry")
                assert(c:GetValue()==(unit[field[3]] or field[4]) and c.disabled==disabled,field[1])
                if field[5]then assert(c.min==field[5] and c.max==field[6] and c.step==1)end
            end
        end
        Click("geometry");Check("class_power","geometry");Controls(false);p.h.Equal(unit,initial)
        assert(p.Control("Anchor Target","Dropdown"):GetUserData("focalPointAnchorKey")=="class_power_anchor_to")
        p.Control("Width","FPCompactSlider"):Fire("OnValueChanged",151.6)
        p.Control(fields[2][1],"FPCompactSlider"):Fire("OnValueChanged",6.6)
        p.Control("Anchor Target","Dropdown"):Fire("OnValueChanged","PowerBar");p.Drain()
        p.Control("Anchor From","Dropdown"):Fire("OnValueChanged","TOPLEFT");p.Drain()
        p.Control("Anchor To","Dropdown"):Fire("OnValueChanged","BOTTOMLEFT");p.Drain()
        p.Control("Offset X","FPCompactSlider"):Fire("OnValueChanged",-23.6)
        p.Control("Offset Y","FPCompactSlider"):Fire("OnValueChanged",31.6)
        assert(unit.classPowerBarWidth==152 and unit.classPowerBarSpacing==7)
        assert(unit.classPowerBarAnchorTo=="PowerBar" and unit.classPowerBarPoint=="TOPLEFT" and unit.classPowerBarRelativePoint=="BOTTOMLEFT")
        assert(unit.classPowerBarOffsetX==-24 and unit.classPowerBarOffsetY==32)
        for _,growth in ipairs({"RIGHT_TO_LEFT","LEFT_TO_RIGHT"})do
            p.Control(fields[8][1],"Dropdown"):Fire("OnValueChanged",growth)
            assert(unit.classPowerBarGrowth==growth)
            p.controller.RefreshActiveProperties();p.Drain();Controls(false)
        end
        local before=p.h.Copy(unit)
        assert(p.ns.GUI.Editor.Inspector.SetActiveCanvasDirectMoveAnchorValues("player",ref,{offsetX=12,offsetY=13,point="RIGHT",relativePoint="LEFT"}))
        assert(p.Control("Offset X","FPCompactSlider"):GetValue()==12 and p.Control("Offset Y","FPCompactSlider"):GetValue()==13)
        assert(p.Control("Anchor From","Dropdown"):GetValue()=="RIGHT" and p.Control("Anchor To","Dropdown"):GetValue()=="LEFT")
        p.h.Equal(unit,before) -- Synchronization must not invoke mutation callbacks.
        p.controller.RefreshActiveProperties();p.Drain();Controls(false)
        Click("behavior");p.Control("Show","CheckBox"):Fire("OnValueChanged",false);p.Drain()
        Controls(true)
        p.Control("Show","CheckBox"):Fire("OnValueChanged",true);p.Drain();Controls(false)
        for _=1,3 do
            p.Select("PowerBar");p.Select("ClassPowerBar");Click("geometry");Controls(false)
            p.controller.RefreshActiveProperties();p.Drain();Controls(false)
        end
        window.closebutton:GetScript("OnClick")(window.closebutton);p.Drain();window=p.Build();Click("geometry");Controls(false)
        p.h.Equal(db.profile,profile)
        assert(p.state.Get().mode==(expert and "quick" or "expert"))
    end
end)
Test("unscoped Legacy Class Power retains saved-mode filtering and one Growth control",function()
    for _,expert in ipairs({false,true})do
        Start(expert and "quick" or "expert");db.profile={General={ExpertMode=expert}}
        p.state.SetSectionCollapsed("class_power",false)
        local before=p.h.Copy(db);local host=p.h.ui.ace:Create("SimpleGroup")
        p.ns.GUI.Editor.Inspector.Build(host,p.state.Get(),{getUnitConfig=p.ns.UnitFrameUtils.GetUnitDB})
        local section
        p.Walk(host,function(w)
            if w:GetUserData("focalPointSectionKey")=="class_power" and w._focalPointRequestRebuild then assert(not section);section=w end
        end)
        assert(section)
        local counts={}
        p.Walk(section,function(w)
            if (w.type=="Dropdown" or w.type=="Slider") and w.label then
                local label=w.label:GetText();counts[label]=(counts[label] or 0)+1
            end
        end)
        assert(counts[Label("OPTION_CLASS_POWER_SEGMENT_GROWTH","Segment Growth")]==1)
        assert(counts[Label("OPTION_CLASS_POWER_BAR_HEIGHT","Class Power Height")]==1)
        for _,label in ipairs({Label("OPTION_CLASS_POWER_BAR_WIDTH","Class Power Width"),
            Label("OPTION_CLASS_POWER_BAR_SPACING","Class Power Spacing"),Label("OPTION_ANCHOR_TO_TARGET","Anchor To Element"),
            "Anchor From","Anchor To",Label("OPTION_X_OFFSET","X Offset"),Label("OPTION_Y_OFFSET","Y Offset")})do
            assert((counts[label] or 0)==(expert and 1 or 0),label)
        end
        p.h.Equal(db,before);p.h.ui.ace:Release(host)
    end
end)
local M=p.ns.LayoutMutations.SegmentedBars
local function Context()return assert(M.CaptureContext("player"))end
local function SelectInstance(id)
    assert(p.selection.SelectObject({kind="segmentedBar",unit="player",objectKey=id}));p.Drain()
end
local function Instances()
    Start("expert")
    local a=M.Add(Context(),{enabled=true,dataSource={id="runes",scope="player"},anchorTo="Frame"})
    assert(a.ok,a.errorCode)
    local b=M.Add(Context(),{enabled=true,dataSource={id="holyPower",scope="player"},anchorTo="Frame"})
    assert(b.ok,b.errorCode);SelectInstance(a.id)
    return a.id,b.id
end
local function Controls()
    local controls={}
    p.Walk(Body("segmented_bars"),function(w)
        local key=w:GetUserData("focalPointAnchorKey")
        if key and key:match("^segmentedBar_")then controls[key:sub(14)]=w end
    end)
    return controls
end
local function Group(w)
    while w do
        local key=w:GetUserData("normalAbsorbPropertyGroup");if key then return key end
        w=w.parent
    end
end
local function Set(field,value)
    local control=assert(Controls()[field],field);control:Fire("OnValueChanged",value);p.Drain()
end
Test("instances keep stable IDs, three flat categories and one action without tab allocations",function()
    local a,b=Instances();local c=Controls()
    assert(a~=b and #unit.segmentedBars==2 and p.selection.GetSelectedObject().objectKey==a)
    for _,field in ipairs({"texture","useBlizzardColor","color","background","backgroundColor","borderWidth","borderColor",
        "runeTimerFont","runeTimerFontSize","runeTimerFontStyle"})do assert(Group(c[field])=="appearance",field)end
    for _,field in ipairs({"width","height","spacing","growth","anchorTo","point","relativePoint","offsetX","offsetY"})do
        assert(Group(c[field])=="geometry",field)
    end
    assert(Group(c.enabled)=="behavior" and Group(c.dataSource)=="behavior")
    local before=p.h.Copy(db);local body=Body("segmented_bars");local n,r,t=p.Stats()
    for _=1,20 do for _,key in ipairs({"appearance","geometry","behavior"})do Click(key);Check("segmented_bars",key)end end
    local nn,rr,tt=p.Stats();assert(n==nn and r==rr and t==tt)
    assert(Controls().width==c.width and Body("segmented_bars")==body);p.h.Equal(db,before)
end)
Test("instance Source rebuild keeps ID and rejects stale bindings, Rune controls follow resolved source",function()
    local a=Instances();local old=Controls().dataSource;local callback=old.events.OnValueChanged
    Set("dataSource","holyPower");assert(not Controls().runeTimerFont)
    local before=p.h.Copy(db);callback(old,"OnValueChanged","runes");p.Drain();p.h.Equal(db,before)
    assert(unit.segmentedBars[1].id==a)
    Set("dataSource","auto");assert(not Controls().runeTimerFont)
    local labels={};p.Walk(Body("segmented_bars"),function(w)if w.type=="Label"then labels[#labels+1]=w.label:GetText()end end)
    assert(table.concat(labels,"\n"):find("Resolved Source",1,true))
    Set("dataSource","runes");assert(Controls().runeTimerFont and Controls().runeTimerFontSize and Controls().runeTimerFontStyle)
    for _=1,20 do Set("dataSource","chi");assert(not Controls().runeTimerFont);Set("dataSource","runes");assert(Controls().runeTimerFont)end
    assert(unit.segmentedBars[1].id==a and #unit.segmentedBars==2)
end)
Test("instance geometry/style uses only selected record, foreign anchors and direct-move bindings survive",function()
    local a,b=Instances();local other=p.h.Copy(unit.segmentedBars[2]);local primary=p.h.Copy(unit.classPowerColor)
    assert(Controls().anchorTo.list["SegmentedBar:"..b] and not Controls().anchorTo.list["SegmentedBar:"..a])
    Set("anchorTo","SegmentedBar:"..b);Set("width",180);Set("height",21);Set("spacing",4)
    Set("growth","RIGHT_TO_LEFT");Set("offsetX",14);Set("runeTimerFontSize",19)
    Controls().color:Fire("OnValueConfirmed",.2,.4,.6,0)
    local record=unit.segmentedBars[1]
    assert(record.anchorTo=="SegmentedBar:"..b and record.width==180 and record.height==21 and record.spacing==4)
    assert(record.growth=="RIGHT_TO_LEFT" and record.offsetX==14 and record.color[4]==0 and record.runeTimerFontSize==19)
    p.h.Equal(unit.segmentedBars[2],other);p.h.Equal(unit.classPowerColor,primary)
    local before=p.h.Copy(db)
    assert(p.ns.GUI.Editor.Inspector.SetActiveCanvasDirectMoveOffsetValues("player",
        {kind="segmentedBar",unit="player",objectKey=a},31,-12))
    assert(Controls().offsetX:GetValue()==31 and Controls().offsetY:GetValue()==-12);p.h.Equal(db,before)
    Set("useBlizzardColor",true);assert(Controls().color.disabled)
    Set("background",false);assert(Controls().backgroundColor.disabled)
    Set("enabled",false);assert(not Controls().enabled.disabled and not Controls().dataSource.disabled and Controls().width.disabled)
    Check("segmented_bars",p.state.Get().inspectorPropertyGroup)
end)
Test("instance texture/font picker opening is read-only and stale apply cannot modify another instance",function()
    local a,b=Instances();local before=p.h.Copy(db)
    Controls().texture:Fire("OnClick");local texture=assert(p.Media());p.h.Equal(db,before)
    texture.onApply("fp:statusbar:healbot");p.Drain();assert(unit.segmentedBars[1].texture=="fp:statusbar:healbot")
    Controls().runeTimerFont:Fire("OnClick");local font=assert(p.Media())
    SelectInstance(b);before=p.h.Copy(db);font.onApply("fp:font:friz-quadrata");p.Drain();p.h.Equal(db,before)
    assert(not Controls().runeTimerFont and p.selection.GetSelectedObject().objectKey==b)
    SelectInstance(a);assert(Controls().runeTimerFont)
end)
Test("instance Confirm Delete and Cancel remain independent of tabs, anchors and stale selection guarded",function()
    local forms=p.ns.GUI.Helpers.FormWidgets;local original=forms.CreateCompactConfirmation
    local options,dialog
    forms.CreateCompactConfirmation=function(input)options=input;dialog=original(input);return dialog end
    local deleteLabel=Label("EDITOR_DELETE_SEGMENTED_BAR_BUTTON","Delete Class Resource Bar")
    for _,key in ipairs({"appearance","geometry","behavior"})do
        local a,b=Instances();Click(key);Check("segmented_bars",key)
        local button=p.Control(deleteLabel,"Button");local before=p.h.Copy(db)
        button:Fire("OnClick");assert(dialog);options.cancel.onClick();p.h.Equal(db,before)
        button:Fire("OnClick");options.primary.onClick(dialog);p.Drain()
        assert(#unit.segmentedBars==1 and unit.segmentedBars[1].id==b and p.selection.GetSelectedObject().kind=="unit")
    end
    local a,b=Instances();assert(M.SetGeometry(Context(),b,{anchorTo="SegmentedBar:"..a}).ok)
    p.controller.RefreshActiveProperties();p.Drain()
    p.Control(deleteLabel,"Button"):Fire("OnClick");local before=p.h.Copy(db)
    options.primary.onClick(dialog);p.Drain();p.h.Equal(db,before);assert(dialog.statusRole=="error")
    SelectInstance(b);options.primary.onClick(dialog);p.Drain();p.h.Equal(db,before)
    forms.CreateCompactConfirmation=original
end)
Test("instance rebuild/reopen and layout switch rebind; non-Workspace stays framed",function()
    local a,b=Instances();Click("geometry")
    local old=Controls().width;local callback=old.events.OnValueChanged
    local oldX=Controls().offsetX;local offsetCallback=oldX.events.OnValueChanged
    local scope=p.state.GetPropertyScope();local serial=p.ns.GUI.Editor._inspectorBuildSerial
    Controls().texture:Fire("OnClick");local media=assert(p.Media())
    p.controller.RefreshActiveProperties();p.Drain();local before=p.h.Copy(db)
    assert(old==Controls().width and oldX==Controls().offsetX,"pool reuse was not exercised")
    assert(scope==p.state.GetPropertyScope() and serial==p.ns.GUI.Editor._inspectorBuildSerial)
    local selected=p.selection.GetSelectedObject();assert(selected.kind=="segmentedBar" and selected.objectKey==a)
    callback(old,"OnValueChanged",211);p.Drain();p.h.Equal(db,before)
    Controls().width:Fire("OnValueChanged",212);p.Drain();assert(unit.segmentedBars[1].width==212)
    before=p.h.Copy(db);offsetCallback(oldX,"OnValueChanged",81);p.Drain();p.h.Equal(db,before)
    Controls().offsetX:Fire("OnValueChanged",82);p.Drain();assert(unit.segmentedBars[1].offsetX==82)
    before=p.h.Copy(db);media.onApply("fp:statusbar:healbot");p.Drain();p.h.Equal(db,before)
    Click("appearance");Controls().width:Fire("OnValueChanged",213);p.Drain()
    assert(unit.segmentedBars[1].width==213,"tab projection invalidated the current binding")
    Click("geometry")
    local released=Controls().width;local releasedCallback=released.events.OnValueChanged
    Controls().texture:Fire("OnClick");local releasedMedia=assert(p.Media())
    window.closebutton:GetScript("OnClick")(window.closebutton);p.Drain();window=p.Build();Check("segmented_bars","geometry")
    before=p.h.Copy(db);releasedCallback(released,"OnValueChanged",214)
    releasedMedia.onApply("fp:statusbar:healbot");p.Drain();p.h.Equal(db,before)
    Controls().width:Fire("OnValueChanged",215);p.Drain();assert(unit.segmentedBars[1].width==215)
    window.closebutton:GetScript("OnClick")(window.closebutton);p.Drain();window=p.Build();Check("segmented_bars","geometry")
    local host=p.h.ui.ace:Create("SimpleGroup")
    p.ns.GUI.Editor.Inspector.BuildProperties(host,p.state.Get(),{getUnitConfig=p.ns.UnitFrameUtils.GetUnitDB})
    local n=0;p.Walk(host,function(w)assert(not w:GetUserData("normalAbsorbPropertyTab"));if w.type=="InlineGroup"then n=n+1 end end)
    assert(n==6);p.h.ui.ace:Release(host)
    p.controller.BuildInspector(nil,{GetEditorState=p.state.Get});p.Drain()
    local previous=unit;local ok,id=p.ns.LayoutMutations.CopyLayout("layout:existing",nil,{activate=false});assert(ok)
    assert(p.ns:ActivateLayout(id));p.controller.BuildInspector(nil,{GetEditorState=p.state.Get});p.Drain()
    SelectInstance(a);Set("width",203)
    assert(p.ns.UnitFrameUtils.GetUnitDB("player").segmentedBars[1].width==203 and previous.segmentedBars[1].width~=203)
    assert(p.selection.GetSelectedObject().objectKey==a)
end)
Test("stale offsets reject Source/object changes and release; current bindings stay usable",function()
    local a,b=Instances()
    local old=Controls().offsetX;local callback=old.events.OnValueChanged
    Set("dataSource","holyPower");local before=p.h.Copy(db)
    callback(old,"OnValueChanged",71);p.Drain();p.h.Equal(db,before)
    Set("offsetX",72);assert(unit.segmentedBars[1].offsetX==72)
    old=Controls().offsetX;callback=old.events.OnValueChanged
    SelectInstance(b);SelectInstance(a);before=p.h.Copy(db)
    callback(old,"OnValueChanged",73);p.Drain();p.h.Equal(db,before)
    Set("offsetX",74);assert(unit.segmentedBars[1].offsetX==74)
    old=Controls().offsetX;callback=old.events.OnValueChanged
    local oldWidth=Controls().width;local widthCallback=oldWidth.events.OnValueChanged
    Controls().texture:Fire("OnClick");local media=assert(p.Media())
    local isCurrent=assert(FindUpvalue(p.Tabs().appearance.events.OnClick,"workspaceIsCurrent"))
    assert(isCurrent())
    window.closebutton:GetScript("OnClick")(window.closebutton);p.Drain()
    assert(not isCurrent(),"old workspace remained current after Close")
    before=p.h.Copy(db);callback(old,"OnValueChanged",75);p.Drain();p.h.Equal(db,before)
    widthCallback(oldWidth,"OnValueChanged",175);media.onApply("fp:statusbar:healbot");p.Drain();p.h.Equal(db,before)
    window=p.Build();assert(not isCurrent(),"old workspace reactivated on Reopen")
    assert(FindUpvalue(p.Tabs().appearance.events.OnClick,"workspaceIsCurrent")())
    before=p.h.Copy(db);callback(old,"OnValueChanged",76)
    widthCallback(oldWidth,"OnValueChanged",176);media.onApply("fp:statusbar:healbot");p.Drain();p.h.Equal(db,before)
    Set("offsetX",77);assert(unit.segmentedBars[1].offsetX==77)
    Set("width",177);assert(unit.segmentedBars[1].width==177)
end)
Test("pending Confirm Delete retains its existing contract across a data-unchanged rebuild",function()
    local a,b=Instances();local forms=p.ns.GUI.Helpers.FormWidgets
    local original=forms.CreateCompactConfirmation;local options,dialog
    forms.CreateCompactConfirmation=function(input)options=input;dialog=original(input);return dialog end
    p.Control(Label("EDITOR_DELETE_SEGMENTED_BAR_BUTTON","Delete Class Resource Bar"),"Button"):Fire("OnClick")
    local before=p.h.Copy(db);p.controller.RefreshActiveProperties();p.Drain();p.h.Equal(db,before)
    options.primary.onClick(dialog);p.Drain()
    assert(#unit.segmentedBars==1 and unit.segmentedBars[1].id==b and p.selection.GetSelectedObject().kind=="unit")
    forms.CreateCompactConfirmation=original
end)
assert(#p.h.ui.env.errors==0,table.concat(p.h.ui.env.errors,"\n"))
print("Class Resource Property Groups: "..count.." groups PASS")
