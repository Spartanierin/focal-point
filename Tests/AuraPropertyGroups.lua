-- Actual Workspace, Aura builder, selection and mutations; native clipping is a client gate.
local function Read(path)local f=assert(io.open(path));local s=f:read("*a");f:close();return s end
local source=Read("Tests/PowerBarPropertyGroups.lua")
local stop=assert(source:find("\nlocal count=0",1,true))
local p=assert(load(source:sub(1,stop).."\nreturn s","@AuraGroups/Workspace"))()
assert(loadfile("GUI/Layouts/UnitAuraDefinition.lua"))("FocalPoint",p.ns)
for _,path in ipairs({"GUI/Editor/Inspector/InspectorAuraSelection.lua","GUI/Editor/Inspector/InspectorContext.lua",
    "GUI/Editor/Inspector/InspectorController.lua"})do assert(loadfile(path))("FocalPoint",p.ns)end
local defaults={};assert(loadfile("Data/Defaults.lua"))("FocalPoint",defaults)
local defaultUnit=defaults:GetDefaultDB().profile.Units.player
local window,unit,db,key,expert
local function Select(aura,unitKey)
    assert(p.selection.SelectObject({kind="aura",unit=unitKey or "player",auraKey=aura}));p.Drain()
end
local function Start(aura,mode)
    window,unit,db=p.Start();key,expert=aura,mode
    for _,name in ipairs({"Buffs","Debuffs"})do
        unit[name]=p.h.Copy(defaultUnit[name]);unit[name].present=true;unit[name].enabled=true
        unit[name].placement="ATTACHED";unit[name].hideLongAuras=false
    end
    db.profile={General={ExpertMode=mode}}
    p.state.SetMode(mode and "quick" or "expert") -- Stored profile, not fallback, controls availability.
    p.state.SetInspectorPropertyGroup("appearance")
    Select(aura)
end
local function Body()
    local body;p.Walk(window._focalPointPropertyScroll,function(w)
        if w:GetUserData("focalPointSectionKey")=="auras" and w._focalPointRequestRebuild then body=w end
    end);return assert(body)
end
local function Field(name,optional)
    local found;p.Walk(Body(),function(w)
        if w:GetUserData("focalPointAnchorKey")=="aura_"..name then assert(not found,"duplicate control: "..name);found=w end
    end)
    if not optional then assert(found,name)end;return found
end
local function Actions()
    local area,button,n=nil,nil,0
    for _,group in ipairs(Body().children)do
        if group:GetUserData("normalAbsorbObjectActions")then area=group;n=n+1 end
    end
    assert(n==1 and area.type=="InlineGroup" and area.parent==Body() and area==Body().children[#Body().children])
    assert(area.frame:IsShown() and not area:GetUserData("normalAbsorbPropertyGroup")
        and not area:GetUserData("normalAbsorbPropertyContent"))
    p.Walk(area,function(w)if w.type=="Button"then assert(not button);button=w end end)
    assert(button and button.frame:IsShown() and not button.disabled)
    assert(area.events.OnRelease,"framed section release binding was lost")
    return area,button
end
local function Click(tab)p.Tabs()[tab]:Fire("OnClick");p.Drain()end
local function Check(active)
    local tabs,order=p.Tabs();assert(table.concat(order,",")=="appearance,geometry,behavior")
    assert(p.state.Get().inspectorPropertyGroup==active)
    for name,tab in pairs(tabs)do
        assert(tab.frame:IsShown() and not tab.disabled)
    end
    local titles={}
    for _,group in ipairs(Body().children)do
        local tab=group:GetUserData("normalAbsorbPropertyGroup")
        if tab then assert(group.frame:IsShown()==(tab==active))end
        if group.type=="InlineGroup"then
            assert(group.parent==Body() and not group:GetUserData("flatPropertySectionTitle"))
            titles[#titles+1]=group.titletext:GetText()
            if tab then assert(group:GetUserData("normalAbsorbPropertyContent") and #group.children>0)end
        end
        p.Walk(group,function(w)assert(not w:GetUserData("flatPropertyHeading"),"duplicate section heading")end)
    end
    assert(table.concat(titles,",")=="Appearance,Size,Layout,Position,Display,Behavior,Actions")
    for _=1,2 do Body():DoLayout();window._focalPointPropertyScroll:DoLayout()end
    local height=0;for _,child in ipairs(Body().children)do if child.frame:IsShown()then height=height+child.frame:GetHeight()end end
    assert(math.abs(Body().frame:GetHeight()-height)<.01,"hidden groups still consume scroll content height")
    Actions()
end
local count=0
local function Test(name,fn)fn();count=count+1;print("PASS: "..name)end
Test("Buffs/Debuffs expose identical Workspace controls and tab membership in both stored profile modes",function()
    for _,mode in ipairs({false,true})do for _,aura in ipairs({"Buffs","Debuffs"})do
        Start(aura,mode);Check("appearance")
        local expected={enabled="behavior",icon_size="geometry",show_stacks="behavior",show_timer="behavior",
            icons_per_row="geometry",max_rows="geometry",spacing_x="geometry",spacing_y="geometry",
            growth_x="geometry",growth_y="geometry",placement="geometry"}
        if aura=="Buffs"then expected.weapon_enhancements="behavior"end
        for _,field in ipairs({"sort_mode","show_only_mine","show_boss","hide_permanent","hide_long","long_threshold"})do expected[field]="behavior"end
        expected[aura=="Buffs" and "show_stealable_only" or "show_dispellable_only"]="behavior"
        expected.stack_font_scale="appearance";expected.timer_font_scale="appearance"
        for _,field in ipairs({"point","relative_point","offset_x","offset_y"})do expected[field]="geometry"end
        local actual={};p.Walk(Body(),function(w)
            local anchor=w:GetUserData("focalPointAnchorKey")
            if type(anchor)=="string" and anchor:sub(1,5)=="aura_"then
                local field=anchor:sub(6);assert(expected[field],"unexpected control: "..field)
                assert(not actual[field]);actual[field]=true
                assert(w.parent.parent.parent:GetUserData("normalAbsorbPropertyGroup")==expected[field],field)
            end
        end)
        for field in pairs(expected)do assert(actual[field],"missing control: "..field)end
        local orders={Appearance="stack_font_scale,timer_font_scale",Size="icon_size",
            Layout="icons_per_row,max_rows,spacing_x,spacing_y,growth_x,growth_y",
            Position="placement,point,relative_point,offset_x,offset_y",
            Display="enabled,show_stacks,show_timer"..(aura=="Buffs" and ",weapon_enhancements" or ""),
            Behavior="sort_mode,show_only_mine,show_boss,hide_permanent,hide_long,long_threshold,"..
                (aura=="Buffs" and "show_stealable_only" or "show_dispellable_only")}
        for _,group in ipairs(Body().children)do
            if group.type=="InlineGroup" and orders[group.titletext:GetText()]then
                local fields={};p.Walk(group,function(w)
                    local anchor=w:GetUserData("focalPointAnchorKey")
                    if type(anchor)=="string" and anchor:sub(1,5)=="aura_"then fields[#fields+1]=anchor:sub(6)end
                end)
                assert(table.concat(fields,",")==orders[group.titletext:GetText()],"Aura row order changed")
            end
        end
        assert(not Field("inside_side",true))
        local before=p.h.Copy(db);Click("appearance");Check("appearance");p.h.Equal(db,before)
    end end
end)
Test("tab switches retain controls, owners, release callbacks and canonical data without allocations",function()
    Start("Buffs",true);local body=Body();local field=Field("icon_size");local area=Actions()
    local onRelease=area.events.OnRelease;local before=p.h.Copy(db);local a,r,t=p.Stats()
    for _=1,30 do
        for _,tab in ipairs({"geometry","behavior","appearance"})do
            window._focalPointPropertyScroll:SetScroll(400);Click(tab);Check(tab)
            assert(window._focalPointPropertyScroll.status.scrollvalue==0)
            assert(Body()==body and Field("icon_size")==field and Actions()==area and area.events.OnRelease==onRelease)
        end
    end
    local aa,rr,tt=p.Stats();assert(a==aa and r==rr and t==tt);p.h.Equal(db,before)
end)
Test("existing fields mutate locally; long-duration and placement rebuild dependencies keep the tab",function()
    Start("Buffs",true);local other=p.h.Copy(unit.Debuffs);local record=unit.Buffs
    Click("geometry");Field("icon_size"):Fire("OnValueChanged",37);p.Drain();assert(record.iconSize==37)
    Field("icons_per_row"):Fire("OnEnterPressed","7");p.Drain();assert(record.iconsPerRow==7)
    Field("growth_x"):Fire("OnValueChanged","LEFT");p.Drain();assert(record.growthX=="LEFT")
    Field("placement"):Fire("OnValueChanged","INSIDE");p.Drain();Check("geometry")
    assert(record.placement=="INSIDE" and Field("inside_side"))
    Field("inside_side"):Fire("OnValueChanged","RIGHT");p.Drain();assert(record.insideSide=="RIGHT")
    Field("placement"):Fire("OnValueChanged","ATTACHED");p.Drain();assert(not Field("inside_side",true))
    Click("behavior");assert(Field("long_threshold").disabled)
    Field("hide_long"):Fire("OnValueChanged",true);p.Drain();Check("behavior")
    assert(record.hideLongAuras and not Field("long_threshold").disabled)
    Field("long_threshold"):Fire("OnValueChanged",120);p.Drain();assert(record.longAuraThreshold==120)
    Field("show_stacks"):Fire("OnValueChanged",false);p.Drain();assert(not record.showStackText)
    p.h.Equal(unit.Debuffs,other);assert(unit.Buffs==record and db.profile.General.ExpertMode==true)
end)
Test("disabled Aura keeps real tabs available and Remove accessible; Player-only weapon rule survives",function()
    Start("Buffs",true);Click("behavior");Field("enabled"):Fire("OnValueChanged",false);p.Drain();Check("behavior")
    assert(not unit.Buffs.enabled)
    p.Walk(Body(),function(w)
        local anchor=w:GetUserData("focalPointAnchorKey")
        if type(anchor)=="string" and anchor:sub(1,5)=="aura_" and anchor~="aura_enabled"then assert(w.disabled,anchor)end
    end)
    Field("enabled"):Fire("OnValueChanged",true);p.Drain();assert(not Field("icon_size").disabled)
    local root=p.ns.ActiveLayoutResolver.GetActiveRuntimeRoot();root.units.target=p.h.Copy(unit)
    Select("Buffs","target");assert(Field("weapon_enhancements").disabled)
    Select("Debuffs","target");assert(not Field("weapon_enhancements",true) and Field("show_dispellable_only"))
end)
Test("rebuild, object/unit/layout changes and reopen reject old tab callbacks and release framed owners",function()
    Start("Buffs",true);Click("behavior")
    local old=p.Tabs().geometry.events.OnClick
    p.controller.RefreshActiveProperties();p.Drain();old();Check("behavior")
    local groups={};for _,w in ipairs(Body().children)do if w.type=="InlineGroup"then groups[#groups+1]=w end end
    p.Select("PowerBar");for _,w in ipairs(groups)do assert(not w.frame:IsShown())end
    Select("Buffs");Check("behavior")
    local ok,id=p.ns.LayoutMutations.CopyLayout("layout:existing",nil,{activate=false});assert(ok)
    assert(p.ns:ActivateLayout(id));p.controller.BuildInspector(nil,{GetEditorState=p.state.Get});p.Drain()
    Select("Debuffs");Click("geometry");Check("geometry")
    for _=1,20 do
        local retained=p.Tabs().behavior.events.OnClick
        window.closebutton:GetScript("OnClick")(window.closebutton);p.Drain();assert(p.state.IsArrange())
        retained();assert(p.state.IsArrange());window=p.Build();p.Drain();Check("geometry")
        Select("Buffs");Select("Debuffs");Check("geometry")
    end
end)
Test("Remove stays unique, immediate and independent of the selected tab in both profile modes",function()
    for _,mode in ipairs({false,true})do for _,aura in ipairs({"Buffs","Debuffs"})do
        for _,tab in ipairs({"appearance","geometry","behavior"})do
            Start(aura,mode);Click(tab);local record=unit[aura];local other=aura=="Buffs" and "Debuffs" or "Buffs"
            local before=p.h.Copy(unit[other]);local area,button=Actions();button:Fire("OnClick");p.Drain()
            assert(record.present==false and unit[aura]==record and p.selection.GetSelectedObject().kind=="unit")
            -- Unit-root rebuilding may already reuse the released InlineGroup.
            assert(not area:GetUserData("normalAbsorbObjectActions"),"Aura action metadata leaked through pooling")
            p.Walk(window._focalPointPropertyScroll,function(w)
                assert(w:GetUserData("focalPointSectionKey")~="auras","removed Aura retained an Inspector body")
            end)
            p.h.Equal(unit[other],before)
        end
    end end
end)
Test("non-Workspace Aura keeps its framed section order and original profile filtering",function()
    for _,mode in ipairs({false,true})do for _,aura in ipairs({"Buffs","Debuffs"})do
        Start(aura,mode)
        local host=p.h.ui.ace:Create("SimpleGroup")
        p.ns.GUI.Editor.Inspector.BuildProperties(host,p.state.Get(),{getUnitConfig=p.ns.UnitFrameUtils.GetUnitDB})
        local titles,fields={},{};p.Walk(host,function(w)
            assert(not w:GetUserData("normalAbsorbPropertyTab"))
            if w.type=="InlineGroup"then titles[#titles+1]=w.titletext:GetText()end
            local anchor=w:GetUserData("focalPointAnchorKey")
            if type(anchor)=="string" and anchor:sub(1,5)=="aura_"then fields[anchor:sub(6)]=w end
        end)
        assert(table.concat(titles,",")=="Display,Actions,Layout,Behavior,Position"..(mode and ",Advanced" or ""))
        for _,field in ipairs({"enabled","icon_size","show_stacks","show_timer","icons_per_row","max_rows",
            "spacing_x","spacing_y","growth_x","growth_y","placement"})do assert(fields[field],field)end
        for _,field in ipairs({"sort_mode","stack_font_scale","timer_font_scale","show_only_mine","show_boss",
            "hide_permanent","hide_long","long_threshold","point","relative_point","offset_x","offset_y",
            aura=="Buffs" and "show_stealable_only" or "show_dispellable_only"})do
            assert((fields[field]~=nil)==mode,"Legacy mode filter changed: "..field)
        end
        assert((fields.weapon_enhancements~=nil)==(aura=="Buffs"))
        assert(not fields.inside_side)
        assert(db.profile.General.ExpertMode==mode)
        p.h.ui.ace:Release(host)
    end end
end)
Test("previously Expert-only fields mutate and rebuild identically in both profiles without changing mode or dependencies",function()
    for _,mode in ipairs({false,true})do for _,aura in ipairs({"Buffs","Debuffs"})do
        Start(aura,mode)
        local record=unit[aura];local expected=p.h.Copy(record)
        local other=aura=="Buffs" and "Debuffs" or "Buffs";local untouched=p.h.Copy(unit[other])
        local general=p.h.Copy(db.profile.General);local fallback=p.state.Get().mode
        Click("appearance")
        Field("stack_font_scale"):Fire("OnValueChanged",1.25);p.Drain();expected.stackFontScale=1.25
        Field("timer_font_scale"):Fire("OnValueChanged",1.5);p.Drain();expected.timerFontScale=1.5
        Click("behavior");assert(Field("long_threshold").disabled)
        Field("sort_mode"):Fire("OnValueChanged","OLDEST_FIRST");p.Drain();expected.sortMode="OLDEST_FIRST"
        Field("show_only_mine"):Fire("OnValueChanged",true);p.Drain();expected.showOnlyMine=true
        Field("show_boss"):Fire("OnValueChanged",false);p.Drain();expected.showBossAuras=false
        Field("hide_permanent"):Fire("OnValueChanged",true);p.Drain();expected.hidePermanentAuras=true
        Field("hide_long"):Fire("OnValueChanged",true);p.Drain();expected.hideLongAuras=true
        Check("behavior");assert(not Field("long_threshold").disabled)
        Field("long_threshold"):Fire("OnValueChanged",90);p.Drain();expected.longAuraThreshold=90
        Field(aura=="Buffs" and "show_stealable_only" or "show_dispellable_only"):Fire("OnValueChanged",true);p.Drain()
        expected[aura=="Buffs" and "showStealableOnly" or "showDispellableOnly"]=true
        Click("geometry");assert(not Field("inside_side",true))
        Field("placement"):Fire("OnValueChanged","INSIDE");p.Drain();expected.placement="INSIDE"
        Check("geometry");Field("inside_side"):Fire("OnValueChanged","TOP");p.Drain();expected.insideSide="TOP"
        Field("point"):Fire("OnValueChanged","LEFT");p.Drain();expected.point="LEFT"
        Field("relative_point"):Fire("OnValueChanged","RIGHT");p.Drain();expected.relativePoint="RIGHT"
        Field("offset_x"):Fire("OnValueChanged",11);p.Drain();expected.offsetX=11
        Field("offset_y"):Fire("OnValueChanged",-7);p.Drain();expected.offsetY=-7
        p.h.Equal(record,expected);p.h.Equal(unit[other],untouched)
        Click("behavior");Field("enabled"):Fire("OnValueChanged",false);p.Drain();Check("behavior")
        for _,field in ipairs({"sort_mode","stack_font_scale","point","inside_side","long_threshold"})do assert(Field(field).disabled,field)end
        Field("enabled"):Fire("OnValueChanged",true);p.Drain();Check("behavior")
        assert(not Field("sort_mode").disabled and not Field("inside_side").disabled)
        p.h.Equal(record,expected);p.h.Equal(db.profile.General,general);assert(p.state.Get().mode==fallback)
        local ok,id=p.ns.LayoutMutations.CopyLayout("layout:existing",nil,{activate=false});assert(ok)
        assert(p.ns:ActivateLayout(id));p.controller.BuildInspector(nil,{GetEditorState=p.state.Get});p.Drain()
        Select(aura);Click("geometry");Check("geometry")
        local active=p.ns.UnitFrameUtils.GetUnitDB("player")[aura];p.h.Equal(active,expected)
        window.closebutton:GetScript("OnClick")(window.closebutton);p.Drain();window=p.Build();p.Drain();Check("geometry")
        assert(Field("sort_mode") and Field("stack_font_scale") and Field("inside_side"))
        p.h.Equal(db.profile.General,general);assert(p.state.Get().mode==fallback)
    end end
end)
assert(#p.h.ui.env.errors==0,table.concat(p.h.ui.env.errors,"\n"))
print("Aura Property Groups: "..count.." groups PASS")
