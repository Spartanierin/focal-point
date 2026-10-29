-- Actual persistent Workspace, selection, Inspector, layouts and mutations.
-- Native frames use the existing fixture; no SavedVariables or files are written.
local function Read(path)
    local f=assert(io.open(path)); local s=f:read("*a"); f:close(); return s
end
local source=Read("Tests/CustomizeWorkspace.lua")
local stop=assert(source:find("\nlocal count = 0",1,true))
local h,ns,state,controller,selection,Setup,Build,Drain,Tree,Node=assert(load(source:sub(1,stop)..
    "\nreturn h,ns,state,controller,selection,Setup,Build,Drain,Tree,Node", "@NormalAbsorb/Workspace"))()
local getUnits,getUnit=ns.UnitFrameUtils.GetUnitsDB,ns.UnitFrameUtils.GetUnitDB
for _,path in ipairs({"GUI/Helpers/OptionPaths.lua","GUI/Helpers/OptionValues.lua",
    "Engine/UnitFrame/Shared/UnitFrameUtils.lua",
    "GUI/Editor/Inspector/InspectorRefreshPolicy.lua","GUI/Editor/Inspector/InspectorController.lua"}) do
    assert(loadfile(path))("FocalPoint",ns)
end
ns.UnitFrameUtils.GetUnitsDB,ns.UnitFrameUtils.GetUnitDB=getUnits,getUnit
local media
ns.GUI.Editor.MediaLibrary={Open=function(options) media=options end}
local ace=h.ui.ace
local acquired,released,timers=0,0,0
local create,release,after=ace.Create,ace.Release,C_Timer.After
ace.Create=function(...) acquired=acquired+1; return create(...) end
ace.Release=function(...) released=released+1; return release(...) end
C_Timer.After=function(...) timers=timers+1; return after(...) end
local window,unit,db
local function Walk(w,fn)
    fn(w); for _,child in ipairs(w.children or {}) do Walk(child,fn) end
end
local function Tabs()
    local tabs,order={},{}
    Walk(window._focalPointPropertyScroll,function(w)
        local key=w:GetUserData("normalAbsorbPropertyTab")
        if key then tabs[key]=w; order[#order+1]=key end
    end)
    return tabs,order
end
local function Body()
    local body
    Walk(window._focalPointPropertyScroll,function(w)
        if w:GetUserData("focalPointSectionKey")=="absorbs" and w._focalPointRequestRebuild then body=w end
    end)
    return assert(body)
end
local function ObjectActions()
    local area,button,areas,buttons=nil,nil,0,0
    local healing=selection.GetSelectedObject().objectKey=="HealingAbsorbBar"
    local label=healing and (ns.L.EDITOR_REMOVE_HEALING_ABSORB_BAR_BUTTON or "Remove Healing Absorb")
        or (ns.L.EDITOR_REMOVE_NORMAL_ABSORB_BAR_BUTTON or "Remove Normal Absorb")
    for _,child in ipairs(Body().children) do
        if child:GetUserData("normalAbsorbObjectActions") then area=child; areas=areas+1 end
    end
    assert(areas==1,"expected exactly one separate object-action area")
    assert(area==Body().children[#Body().children] and area.parent==Body())
    assert(not area:GetUserData("normalAbsorbPropertyContent") and not area:GetUserData("normalAbsorbPropertyGroup"))
    Walk(Body(),function(w)
        if w.type=="Button" and w.text:GetText()==label then
            button=w; buttons=buttons+1
        end
    end)
    assert(buttons==1,"Remove action was missing or duplicated")
    assert(button.parent.parent.parent==area,"Remove action has a different owner")
    assert(button:IsFullWidth() and #button.parent.parent.children==1,"object action must span the row without a duplicate label")
    assert(area.frame:IsShown() and button.frame:IsShown())
    assert(area.frame._fpNormalAbsorbActionDivider:IsShown() and area.frame._fpNormalAbsorbActionDivider:GetHeight()==1)
    return area,button
end
local function Click(key) assert(Tabs()[key],key):Fire("OnClick"); Drain() end
local function Select(key)
    assert(selection.SelectObject({kind="bar",unit="player",objectKey=key})); Drain()
end
local function Control(label,kind)
    local found
    local root=window._focalPointPropertyScroll
    Walk(root,function(w)
        if kind=="Button" and w.type=="Button" and w.text:GetText()==label then found=w end
        local c=w.children or {}
        if c[1] and c[1].type=="Label" and c[1].label:GetText()==label and c[2] then
            Walk(c[2],function(child) if child.type==kind then found=child end end)
        end
    end)
    return assert(found,label..":"..kind)
end
local function CheckProjection(key)
    local tabs,order=Tabs()
    assert(table.concat(order,",")=="appearance,geometry,behavior")
    for name,tab in pairs(tabs) do
        assert(not tab.disabled)
        local surface=assert(tab.frame._fpNormalAbsorbTab)
        local labels={appearance=ns.L.EDITOR_PROPERTY_APPEARANCE or "Appearance",
            geometry=ns.L.SECTION_SIZE_POSITION or "Size & Position",behavior=ns.L.SECTION_BEHAVIOR or "Behavior"}
        assert(surface.label:GetText()==labels[name] and surface.label:IsShown())
        assert((tab.text:GetText() or "")=="","native template retains a second caption")
        assert(tab.frame:GetWidth()>=surface.label:GetStringWidth()+16,"tab label truncated")
        assert(surface.bottom:IsShown()==(name~=key),"active tab has a lower edge")
        for i=1,surface.top:GetNumPoints() do
            local _,_,_,_,top=surface.top:GetPoint(i)
            assert(top==(name==key and 0 or -4),"inactive tab is not recessed")
        end
    end
    assert(state.Get().inspectorPropertyGroup==key)
    local body=Body(); local visible=0
    local root=body.parent
    assert(#root.children==1 and root.children[1]==body,"redundant Workspace object header returned")
    assert(body.children[1].frame:GetHeight()==40,"tab navigation must retain 10px below its 30px buttons")
    Walk(body,function(widget)
        if widget.type=="Label" and widget:GetUserData("fpLabelTypography") then
            local _,size=widget.label:GetFont()
            assert(size==13,"Workspace property labels must match the 13px tabs")
            h.Equal(widget.label.lastSetTextColor,{1,1,1,1})
        end
    end)
    for i,child in ipairs(root.parent.children) do
        if child==root then assert(root.parent.children[i-1].frame:GetHeight()==4,"pilot outer spacing changed") end
    end
    for _,child in ipairs(body.children) do
        local group=child:GetUserData("normalAbsorbPropertyGroup")
        if group then
            assert(child.frame:IsShown()==(group==key),"group/spacer projection differs")
            if child:GetUserData("normalAbsorbPropertyContent") and child.frame:IsShown() then visible=visible+1 end
        end
    end
    assert(visible==({appearance=2,geometry=3,behavior=1})[key])
    -- Table must keep inactive groups/spacers excluded across parent relayouts.
    for _=1,3 do body:DoLayout(); window._focalPointPropertyScroll:DoLayout() end
    local height=0
    for _,child in ipairs(body.children) do
        local group=child:GetUserData("normalAbsorbPropertyGroup")
        if group then assert(child.frame:IsShown()==(group==key)) end
        if child.frame:IsShown() then height=height+child.frame:GetHeight() end
    end
    assert(math.abs(body.frame:GetHeight()-height)<.01,"inactive content contributes layout height")
    ObjectActions()
end
local count=0
local function Test(name,fn) fn(); count=count+1; print("PASS: "..name) end
Test("three tabs project groups and spacers without rebuild, allocation, timers or mutations",function()
    db,unit=Setup(); unit.normalAbsorbBarPresent=true; unit.showNormalAbsorbBar=true
    window=Build(); Select("NormalAbsorbBar"); CheckProjection("appearance")
    local scope=state.GetPropertyScope(); local scroll=window._focalPointPropertyScroll
    local body=Body(); local width=Control("Width","FPCompactSlider")
    for i=1,30 do
        local key=({"geometry","behavior","appearance"})[(i-1)%3+1]
        scroll:SetScroll(500)
        local a,r,t=acquired,released,timers; local before=h.Copy(db)
        Click(key); CheckProjection(key)
        assert(acquired==a and released==r and timers==t,"tab navigation changed lifetimes")
        assert(Body()==body and Control("Width","FPCompactSlider")==width)
        assert(state.GetPropertyScope()==scope and scroll.status.scrollvalue==0)
        h.Equal(db,before)
    end
end)
Test("one caption survives both Disabled states even if native text alpha returns to one",function()
    local a,r,t=acquired,released,timers
    local before=h.Copy(db)
    for _,tab in pairs(Tabs()) do
        local surface=tab.frame._fpNormalAbsorbTab
        local caption=surface.label:GetText()
        local setText,setDisabled=tab.SetText,tab.SetDisabled
        for _,disabled in ipairs({true,false,true,false}) do
            tab:SetDisabled(disabled)
            -- Reproduce the measured alpha=1 state, without claiming which native call caused it.
            tab.text:SetAlpha(1)
            assert((tab.text:GetText() or "")=="","native alpha restoration reveals duplicate text")
            assert(surface.label:GetText()==caption and surface.label:IsShown())
            assert(tab.SetText==setText and tab.SetDisabled==setDisabled,"widget methods were overridden")
        end
    end
    assert(acquired==a and released==r and timers==t)
    h.Equal(db,before)
    CheckProjection("appearance")
end)
Test("flat content has no section chrome/title or 40px surcharge and retains full-size rows",function()
    local contents=0
    Walk(Body(),function(w) assert(w.type~="InlineGroup","legacy section survived in Normal Absorb") end)
    for _,group in ipairs(Body().children) do
        if group:GetUserData("normalAbsorbPropertyContent") then
            contents=contents+1
            assert(group.type=="SimpleGroup" and not group.titletext)
            local padding=assert(group._fpSectionPadding)
            assert(padding.left==0 and padding.right==0 and padding.top==0 and padding.bottom==0)
            for _,name in ipairs({"_fpSectionFill","_fpSectionAccent","_fpSectionTopShade","_fpSectionBottomShade",
                "_fpSectionBorderTop","_fpSectionBorderBottom","_fpSectionBorderLeft","_fpSectionBorderRight"}) do
                assert(not group.frame[name] or not group.frame[name]:IsShown(),name.." leaked into flat content")
            end
            group:LayoutFinished(group.frame:GetWidth(),100)
            assert(group.frame:GetHeight()==100,"old InlineGroup height surcharge survived")
            group:DoLayout()
        end
    end
    assert(contents==6,"expected six property groups, excluding object actions")
    local labels={}
    Walk(Body(),function(w)
        local c=w.children or {}
        if w:GetUserData("table") and c[1] and c[1].type=="Label" and c[2] and c[2].type=="SimpleGroup" then
            local label=c[1].label:GetText(); labels[label]=(labels[label] or 0)+1
            assert(c[1].frame:GetWidth()==160,"Workspace label column changed")
            -- The existing picker row is 25px in HEAD; ordinary compact rows are 29px.
            assert(w.frame:GetHeight()==(label=="Texture" and 25 or 29),"property row height changed")
        end
    end)
    for _,label in ipairs({"Show","Texture","Color","Background Color","Border Width","Border Color",
        "Size Mode","Width","Height","Anchor Target","Offset X","Offset Y","Growth Direction"}) do
        assert(labels[label]==1,"missing or duplicate property: "..label)
    end
    CheckProjection("appearance")
end)
Test("Show rebuild renews only current bindings while retaining active group",function()
    Click("behavior")
    local callback=Tabs().appearance.events.OnClick
    Control("Show","CheckBox"):Fire("OnValueChanged",false); Drain()
    assert(unit.showNormalAbsorbBar==false); CheckProjection("behavior")
    local a,r=acquired,released; callback()
    assert(acquired==a and released==r and state.Get().inspectorPropertyGroup=="behavior")
    Control("Show","CheckBox"):Fire("OnValueChanged",true); Drain()
    assert(unit.showNormalAbsorbBar); CheckProjection("behavior")
end)
Test("appearance callbacks stay live across tabs; colors, background and borders persist",function()
    Click("appearance"); Control("Texture","Button"):Fire("OnClick"); assert(media)
    Click("geometry"); media.onApply("fp:statusbar:flat-white"); Drain()
    assert(unit.normalAbsorbBarTexture=="fp:statusbar:flat-white"); CheckProjection("geometry")
    Click("appearance")
    Control("Color","ColorPicker"):Fire("OnValueConfirmed",.2,.3,.4,.5)
    Control("Background Color","ColorPicker"):Fire("OnValueConfirmed",.1,.2,.3,.4)
    Control("Border Width","FPCompactSlider"):Fire("OnValueChanged",2)
    Control("Border Color","ColorPicker"):Fire("OnValueConfirmed",.4,.3,.2,0)
    assert(unit.normalAbsorbBarBorderWidth==2 and unit.normalAbsorbBarBorderColor[4]==0)
    assert(unit.normalAbsorbBarColor[4]==.5)
    assert(unit.normalAbsorbBarBackgroundColor[4]==.4)
    controller.RefreshActiveProperties(); Drain(); CheckProjection("appearance")
end)
Test("custom geometry, growth and canvas synchronization retain original controls and semantics",function()
    state.SetMode("expert"); controller.BuildInspector(nil,{GetEditorState=state.Get}); Drain()
    Click("geometry")
    Control("Size Mode","Dropdown"):Fire("OnValueChanged","CUSTOM"); Drain(); CheckProjection("geometry")
    Control("Width","FPCompactSlider"):Fire("OnValueChanged",185)
    Control("Height","FPCompactSlider"):Fire("OnValueChanged",10)
    Control("Offset X","FPCompactSlider"):Fire("OnValueChanged",7)
    Control("Offset Y","FPCompactSlider"):Fire("OnValueChanged",-4)
    Control("Anchor Target","Dropdown"):Fire("OnValueChanged","Frame"); Drain()
    Control(ns.L.OPTION_ANCHOR_FROM or "Anchor From","Dropdown"):Fire("OnValueChanged","TOPLEFT"); Drain()
    Control(ns.L.OPTION_ANCHOR_TO or "Anchor To","Dropdown"):Fire("OnValueChanged","BOTTOMLEFT"); Drain()
    assert(unit.normalAbsorbBarAnchorTo=="Frame" and unit.normalAbsorbBarPoint=="TOPLEFT"
        and unit.normalAbsorbBarRelativePoint=="BOTTOMLEFT")
    Control("Growth Direction","Dropdown"):Fire("OnValueChanged","RIGHT_TO_LEFT"); Drain()
    assert(unit.normalAbsorbBarWidth==185 and unit.normalAbsorbBarHeight==10)
    assert(unit.normalAbsorbBarOffsetX==7 and unit.normalAbsorbBarOffsetY==-4)
    assert(unit.normalAbsorbBarGrowth=="RIGHT_TO_LEFT")
    Click("appearance")
    assert(ns.GUI.Editor.Inspector.SetActiveCanvasDirectMoveOffsetValues("player",
        {kind="bar",unit="player",objectKey="NormalAbsorbBar"},12,-9))
    Click("geometry")
    assert(Control("Offset X","FPCompactSlider"):GetValue()==12)
    Control("Size Mode","Dropdown"):Fire("OnValueChanged","MATCH_TARGET"); Drain()
    assert(Control("Width","FPCompactSlider").disabled); CheckProjection("geometry")
end)
Test("selection, modes, layout and reopen preserve presentation only for the pilot",function()
    local callback=Tabs().appearance.events.OnClick
    Select("HealthBar"); assert(Tabs().appearance and Tabs().geometry.disabled and not Tabs().behavior.disabled)
    callback(); assert(state.Get().inspectorPropertyGroup=="appearance")
    Tree().control.callbacks.onSelect(Node("unit")); Drain()
    assert(next((Tabs()))==nil)
    Select("NormalAbsorbBar"); CheckProjection("appearance");Click("geometry")
    local units=ns.ActiveLayoutResolver.GetActiveRuntimeRoot().units
    units.target=h.Copy(unit)
    callback=Tabs().appearance.events.OnClick
    assert(selection.SelectObject({kind="bar",unit="target",objectKey="NormalAbsorbBar"})); Drain()
    CheckProjection("geometry"); callback()
    assert(state.GetPrimaryUnit()=="target" and state.Get().inspectorPropertyGroup=="geometry")
    Select("NormalAbsorbBar"); CheckProjection("geometry")
    for _,mode in ipairs({"expert","quick"}) do
        state.SetMode(mode); controller.BuildInspector(nil,{GetEditorState=state.Get}); Drain()
        CheckProjection("geometry")
    end
    local ok,id=ns.LayoutMutations.CopyLayout("layout:existing",nil,{activate=false}); assert(ok)
    assert(ns:ActivateLayout(id)); controller.BuildInspector(nil,{GetEditorState=state.Get}); Drain()
    CheckProjection("geometry")
    callback=Tabs().appearance.events.OnClick
    window.closebutton:GetScript("OnClick")(window.closebutton); Drain(); callback()
    assert(state.IsArrange() and state.Get().inspectorPropertyGroup=="geometry")
    window=Build(); CheckProjection("geometry")
    window.closebutton:GetScript("OnClick")(window.closebutton); Drain(); callback()
    window=Build(); CheckProjection("geometry")
end)
Test("fallback uses available groups and invalid group input cannot create an empty path",function()
    assert(state.ResolveInspectorPropertyGroup({appearance=true,behavior=true})=="appearance")
    assert(not state.SetInspectorPropertyGroup("unknown"))
    assert(state.ResolveInspectorPropertyGroup({behavior=true})=="behavior")
    assert(state.ResolveInspectorPropertyGroup({})==nil)
    assert(state.ResolveInspectorPropertyGroup({appearance=true,geometry=true,behavior=true})=="appearance")
    controller.RefreshActiveProperties(); Drain(); CheckProjection("appearance")
end)
Test("empty-group projection disables the tab and ordinary rebuild restores current bindings",function()
    -- Controlled empty view exercises the otherwise unreachable empty Normal-Absorb group.
    -- No ownership changes; the regular Body rebuild will recreate its released controls.
    for _,child in ipairs(Body().children) do
        if child:GetUserData("normalAbsorbPropertyContent") and child:GetUserData("normalAbsorbPropertyGroup")=="geometry" then
            child:ReleaseChildren()
        end
    end
    Click("behavior")
    assert(Tabs().geometry.disabled)
    local alpha=Tabs().geometry.frame._fpNormalAbsorbTab.label.lastSetTextColor[4]
    assert(alpha==.35,"empty tab is not visually disabled")
    Click("geometry"); assert(state.Get().inspectorPropertyGroup=="behavior")
    controller.RefreshActiveProperties(); Drain(); CheckProjection("behavior")
    Click("geometry"); CheckProjection("geometry")
end)
Test("narrow Workspace and German labels retain three reachable tabs and local Table layout",function()
    local width=UIParent:GetWidth()
    local old={ns.L.EDITOR_PROPERTY_APPEARANCE,ns.L.SECTION_SIZE_POSITION,ns.L.SECTION_BEHAVIOR}
    ns.L.EDITOR_PROPERTY_APPEARANCE="Aussehen"
    ns.L.SECTION_SIZE_POSITION="Größe & Position"
    ns.L.SECTION_BEHAVIOR="Verhalten"
    UIParent:SetWidth(600)
    controller.BuildInspector(nil,{GetEditorState=state.Get}); Drain()
    local tabs=Tabs()
    assert(tabs.appearance.frame._fpNormalAbsorbTab.label:GetText()=="Aussehen"
        and tabs.geometry.frame._fpNormalAbsorbTab.label:GetText()=="Größe & Position")
    local required=0
    for _,tab in pairs(tabs) do
        assert(tab.frame:IsShown())
        required=required+tab.frame:GetWidth()
        assert(tab.frame:GetWidth()>=tab.frame._fpNormalAbsorbTab.label:GetStringWidth()+16)
    end
    local navigation=tabs.appearance.parent
    assert(required<=navigation.frame:GetWidth(),"German tabs exceed narrow Properties width")
    assert(navigation:GetUserData("table").spaceH==0)
    Click("appearance"); CheckProjection("appearance")
    UIParent:SetWidth(width)
    ns.L.EDITOR_PROPERTY_APPEARANCE,ns.L.SECTION_SIZE_POSITION,ns.L.SECTION_BEHAVIOR=table.unpack(old)
    controller.BuildInspector(nil,{GetEditorState=state.Get}); Drain()
    CheckProjection("appearance")
end)
Test("pooling between flat Normal Absorb and framed Unit/Text preserves both presentations",function()
    local active=ns.UnitFrameUtils.GetUnitDB("player")
    active.healingAbsorbBarPresent=true; active.castBarPresent=true; active.showCastBar=true
    for _=1,8 do
        for _,object in ipairs({"unit","text"}) do
            local oldTabs=Tabs()
            local oldActions=ObjectActions()
            local oldActionDivider=oldActions.frame._fpNormalAbsorbActionDivider
            local oldCallback=oldTabs.geometry.events.OnClick
            local oldBaseline=oldTabs.appearance.parent.frame._fpNormalAbsorbTabBaseline
            if object=="text" then
                assert(selection.SelectObject({kind="text",unit="player",textKey="localText"})); Drain()
            else
                assert(selection.SelectObject({kind="unit",unit="player"})); Drain()
            end
            assert(next((Tabs()))==nil)
            assert(not oldActionDivider:IsShown(),"object-action divider leaked after release")
            assert(not oldBaseline:IsShown(),"released navigation left its baseline visible")
            for _,tab in pairs(oldTabs) do
                for _,part in pairs(tab.frame._fpNormalAbsorbTab) do
                    assert(not part:IsShown(),"tab skin leaked into pooled widget")
                end
                assert(tab.text:GetAlpha()==1,"native pooled button presentation not restored")
            end
            local before=state.Get().inspectorPropertyGroup
            oldCallback()
            assert(state.Get().inspectorPropertyGroup==before,"released tab callback remains active")
            local framed=0
            Walk(window._focalPointPropertyScroll,function(w)
                if w.type=="InlineGroup" then
                    framed=framed+1
                    assert(not w:GetUserData("normalAbsorbPropertyContent"))
                    assert(w.titletext:GetText()~="")
                end
            end)
            assert(framed>0,"another component lost its framed Inspector")
            Select("NormalAbsorbBar"); CheckProjection("appearance")
            Walk(Body(),function(w) assert(w.type~="InlineGroup") end)
        end
    end
end)
Test("Normal and Healing share the flat workspace while old tab bindings remain invalid",function()
    local before=h.Copy(db)
    for _=1,10 do
        local old=Tabs().geometry.events.OnClick
        local scope=state.GetPropertyScope()
        Select("HealingAbsorbBar"); CheckProjection("appearance")
        assert(state.GetPropertyScope()~=scope and state.GetPropertyScope().objectKey=="HealingAbsorbBar")
        old(); CheckProjection("appearance")
        old=Tabs().geometry.events.OnClick
        Select("PowerBar")
        old(); assert(state.GetPropertyScope().sectionKey=="power" and state.Get().inspectorPropertyGroup=="appearance")
        old=Tabs().geometry.events.OnClick
        Select("NormalAbsorbBar"); CheckProjection("appearance")
        old(); CheckProjection("appearance")
    end
    h.Equal(db,before)
end)
Test("object action stays outside tab availability and removes the selected bar from every tab",function()
    local area,button=ObjectActions()
    for _,key in ipairs({"appearance","geometry","behavior"}) do
        Click(key)
        local currentArea,currentButton=ObjectActions()
        assert(currentArea==area and currentButton==button,"tab switch recreated the action")
    end
    -- Only properties decide availability, even when the action is the only remaining control.
    for _,child in ipairs(Body().children) do
        if child:GetUserData("normalAbsorbPropertyContent") then child:ReleaseChildren() end
    end
    Click("appearance")
    for _,tab in pairs(Tabs()) do assert(tab.disabled) end
    assert(state.Get().inspectorPropertyGroup==nil)
    ObjectActions()
    controller.RefreshActiveProperties(); Drain(); CheckProjection("appearance")
    for _,key in ipairs({"appearance","geometry","behavior"}) do
        db,unit=Setup(); unit.normalAbsorbBarPresent=true; unit.showNormalAbsorbBar=true
        window=Build(); Select("NormalAbsorbBar"); Click(key)
        local releasedArea,remove=ObjectActions()
        local previousCallback=remove.events.OnClick
        -- A regular Show rebuild must bind the action under the newly built Body.
        Control("Show","CheckBox"):Fire("OnValueChanged",false); Drain()
        assert(not releasedArea.frame._fpNormalAbsorbActionDivider:IsShown() or releasedArea==ObjectActions())
        local _,currentRemove=ObjectActions()
        assert(currentRemove.events.OnClick~=previousCallback,"rebuild retained the released action binding")
        currentRemove:Fire("OnClick"); Drain()
        assert(ns.UnitFrameUtils.GetUnitDB("player").normalAbsorbBarPresent==false)
        assert(selection.GetSelectedObject().kind=="unit" and selection.GetSelectedObject().unit=="player")
        assert(next((Tabs()))==nil,"Remove did not leave the selected object's properties")
    end
end)
assert(#h.ui.env.errors==0,table.concat(h.ui.env.errors,"\n"))
print("Normal Absorb Property Groups: "..count.." groups PASS")
