-- Real scoped Workspace, Inspector, selection and text mutations; detached data only.
local function Read(path)local f=assert(io.open(path));local s=f:read("*a");f:close();return s end
local source=Read("Tests/PowerBarPropertyGroups.lua")
local stop=assert(source:find("\nlocal count=0",1,true))
local p=assert(load(source:sub(1,stop).."\nreturn s","@TextModes/Workspace"))()
for _,path in ipairs({"GUI/Layouts/UnitTextDefinition.lua",
    "Engine/Text/Shared/TextElementRoles.lua","Engine/Text/Shared/TextTemplateResolver.lua",
    "Engine/Text/Shared/TextTemplateMutations.lua"})do assert(loadfile(path))("FocalPoint",p.ns)end
local window,unit,db
local function Select(key,unitKey)
    assert(p.selection.SelectObject({kind="text",unit=unitKey or "player",textKey=key or "localText"}));p.Drain()
end
local function Start(mode,key)
    window,unit,db=p.Start()
    db.profile={General={ExpertMode=mode}}
    p.state.SetMode(mode and "quick" or "expert")
    unit.Texts={localText={tag="[name]",enabled=true,fontSize=12,fontStyle="NONE",justifyH="CENTER",
        anchorTo="Frame",point="CENTER",relativePoint="CENTER",offsetX=0,offsetY=0,
        overflowMode="NONE",shadowEnabled=true,color={1,1,1,1},shadowColor={0,0,0,1}}}
    unit.Texts.linkedText=p.h.Copy(unit.Texts.localText)
    unit.Texts.linkedText.templateId="tpl:b:default-001"
    Select(key)
end
local function Body()
    local body;p.Walk(window._focalPointPropertyScroll,function(w)
        if w:GetUserData("focalPointSectionKey")=="texts" and w._focalPointRequestRebuild then body=w end
    end);return assert(body)
end
local function Fields(host)
    local result={};p.Walk(host or Body(),function(w)
        if host then assert(not w:GetUserData("normalAbsorbPropertyTab"),"Legacy must not use Workspace tabs") end
        local key=w:GetUserData("focalPointAnchorKey")
        if type(key)=="string" and key:sub(1,5)=="text_"then
            key=key:sub(6);assert(not result[key],"duplicate: "..key);result[key]=w
        end
    end);return result
end
local function Field(key)return assert(Fields()[key],key)end
local function Button(label)
    local found;p.Walk(Body(),function(w)if w.type=="Button" and w.text:GetText()==label then
        assert(not found);found=w
    end end);return found
end
local basic={"enabled","font_style","font_size","color","justify","anchor_to","offset_x","offset_y"}
local extended={"point","relative_point","overflow","shadow","shadow_color","dead_template","ghost_template"}
local function Actions()
    local area,n=nil,0
    for _,group in ipairs(Body().children)do
        if group:GetUserData("normalAbsorbObjectActions")then area=group;n=n+1 end
    end
    assert(n==1 and area.type=="InlineGroup" and area.parent==Body() and area==Body().children[#Body().children])
    assert(area.frame:IsShown() and area.events.OnRelease)
    assert(not area:GetUserData("normalAbsorbPropertyGroup") and not area:GetUserData("normalAbsorbPropertyContent"))
    local button=assert(Button("Delete Text"));assert(button.frame:IsShown() and not button.disabled)
    return area,button
end
local function Click(key)p.Tabs()[key]:Fire("OnClick");p.Drain()end
local function Check(full,host)
    local fields=Fields(host)
    for _,key in ipairs(basic)do assert(fields[key],key)end
    for _,key in ipairs(extended)do assert((fields[key]~=nil)==full,"mode availability: "..key)end
    if not host then
        local tabs,order=p.Tabs();assert(table.concat(order,",")=="appearance,geometry,behavior")
        local active=p.state.Get().inspectorPropertyGroup
        for _,tab in pairs(tabs)do assert(tab.frame:IsShown() and not tab.disabled)end
        local membership={Content="behavior",Appearance="appearance",Position="geometry",["State Templates"]="behavior"}
        local fieldGroups={enabled="Content",font_style="Appearance",font_size="Appearance",color="Appearance",
            shadow="Appearance",shadow_color="Appearance",justify="Position",anchor_to="Position",point="Position",
            relative_point="Position",offset_x="Position",offset_y="Position",overflow="Content",
            dead_template="State Templates",ghost_template="State Templates"}
        local titles={};for _,group in ipairs(Body().children)do
            if group.type=="InlineGroup"then
                local title=group.titletext:GetText();titles[#titles+1]=title;assert(group.parent==Body())
                assert(not group:GetUserData("flatPropertySectionTitle"))
                if membership[title]then
                    assert(group:GetUserData("normalAbsorbPropertyGroup")==membership[title])
                    assert(group:GetUserData("normalAbsorbPropertyContent") and #group.children>0)
                    assert(group.frame:IsShown()==(active==membership[title]))
                end
                p.Walk(group,function(w)
                    assert(not w:GetUserData("flatPropertyHeading"),"duplicate heading")
                    local key=w:GetUserData("focalPointAnchorKey")
                    if type(key)=="string" and key:sub(1,5)=="text_"then assert(fieldGroups[key:sub(6)]==title,key)end
                end)
            end
        end
        assert(table.concat(titles,",")=="Content,Appearance,Position,State Templates,Actions")
        assert(Button("Choose Template...") and Button("Delete Text"))
        for _,label in ipairs({"Choose Template...","Edit Text..."})do
            local button=Button(label)
            if button then
                local owner=button.parent
                while owner and owner.parent~=Body()do owner=owner.parent end
                assert(owner and owner.type=="InlineGroup" and owner.titletext:GetText()=="Content")
                assert(owner:GetUserData("normalAbsorbPropertyGroup")=="behavior")
            end
        end
        Actions()
        for _=1,2 do Body():DoLayout();window._focalPointPropertyScroll:DoLayout()end
        local height=0;for _,child in ipairs(Body().children)do if child.frame:IsShown()then height=height+child.frame:GetHeight()end end
        assert(math.abs(Body().frame:GetHeight()-height)<.01,"hidden groups or spacers consume scroll height")
    end
    return fields
end
local count=0
local function Test(name,fn)fn();count=count+1;print("PASS: "..name)end
Test("Workspace local and linked Text expose the same full controls in both saved modes",function()
    for _,mode in ipairs({false,true})do for _,key in ipairs({"localText","linkedText"})do
        Start(mode,key);local before=p.h.Copy(db);Check(true)
        assert((Button("Edit Text...")~=nil)==(key=="localText"))
        assert(p.selection.GetSelectedObject().textKey==key)
        assert(p.state.Get().mode==(mode and "quick" or "expert"));p.h.Equal(db,before)
    end end
end)
Test("Legacy scoped Text retains saved Quick/Expert filtering with opposite fallback",function()
    for _,mode in ipairs({false,true})do for _,key in ipairs({"localText","linkedText"})do
        Start(mode,key);local before=p.h.Copy(db)
        local host=p.h.ui.ace:Create("SimpleGroup")
        p.ns.GUI.Editor.Inspector.BuildProperties(host,p.state.Get(),{getUnitConfig=p.ns.UnitFrameUtils.GetUnitDB})
        Check(mode,host)
        local titles={};p.Walk(host,function(w)if w.type=="InlineGroup"then titles[#titles+1]=w.titletext:GetText()end end)
        assert(table.concat(titles,",")=="Content,Appearance,Position,"..(mode and "Advanced," or "").."Actions")
        p.h.Equal(db,before);p.h.ui.ace:Release(host)
    end end
end)
Test("newly reachable controls use existing mutations and preserve text/template identity",function()
    for _,mode in ipairs({false,true})do for _,key in ipairs({"localText","linkedText"})do
        Start(mode,key);local record=unit.Texts[key];local expected=p.h.Copy(record)
        local other=key=="localText" and "linkedText" or "localText";local untouched=p.h.Copy(unit.Texts[other])
        local general=p.h.Copy(db.profile.General);local fallback=p.state.Get().mode
        for _,change in ipairs({{"point","TOPLEFT","point"},{"relative_point","BOTTOMRIGHT","relativePoint"},
            {"overflow","ELLIPSIS","overflowMode"},{"offset_x",13,"offsetX"},{"offset_y",-9,"offsetY"}})do
            Click(change[3]=="overflowMode" and "behavior" or "geometry")
            Field(change[1]):Fire("OnValueChanged",change[2]);p.Drain();expected[change[3]]=change[2]
        end
        Click("appearance")
        Field("shadow"):Fire("OnValueChanged",false);p.Drain();expected.shadowEnabled=false
        -- shadowEnabled has the existing live-only policy; dependency state is evaluated on rebuild.
        assert(record.shadowEnabled==false);p.controller.RefreshActiveProperties();p.Drain()
        assert(Field("shadow_color").disabled)
        Field("shadow"):Fire("OnValueChanged",true);p.Drain();expected.shadowEnabled=true
        assert(record.shadowEnabled==true);p.controller.RefreshActiveProperties();p.Drain()
        assert(not Field("shadow_color").disabled)
        Field("shadow_color"):Fire("OnValueConfirmed",.1,.2,.3,.4);p.Drain()
        expected.shadowColor={.1,.2,.3,.4,r=.1,g=.2,b=.3,a=.4}
        p.h.Equal(record,expected);p.h.Equal(unit.Texts[other],untouched)
        Click("behavior")
        for _,stateKey in ipairs({"dead","ghost"})do
            local id=stateKey=="dead" and "tpl:b:default-001" or "tpl:b:default-002"
            assert(p.ns.TextTemplateLibrary.ResolveTemplateEntity(id,db))
            Field(stateKey.."_template"):Fire("OnValueChanged",id);p.Drain()
            assert(record.stateTemplateIds[stateKey]==id)
        end
        local assigned=p.h.Copy(record.stateTemplateIds)
        Field("dead_template"):Fire("OnValueChanged","tpl:b:missing");p.Drain();p.h.Equal(record.stateTemplateIds,assigned)
        for _,stateKey in ipairs({"dead","ghost"})do
            Field(stateKey.."_template"):Fire("OnValueChanged","__none");p.Drain()
            assert(not record.stateTemplateIds or not record.stateTemplateIds[stateKey])
        end
        assert(unit.Texts[key]==record and record.templateId==expected.templateId and record.tag==expected.tag)
        p.h.Equal(unit.Texts[other],untouched);p.h.Equal(db.profile.General,general);assert(p.state.Get().mode==fallback)
    end end
end)
Test("enabled and shadow dependencies plus media availability remain effective",function()
    for _,mode in ipairs({false,true})do
        Start(mode);Click("behavior");Field("enabled"):Fire("OnValueChanged",false);p.Drain();Check(true)
        for key,w in pairs(Fields())do if key~="enabled"then assert(w.disabled,key)end end
        Field("enabled"):Fire("OnValueChanged",true);p.Drain();assert(not Field("point").disabled)
        Click("appearance")
        Field("shadow"):Fire("OnValueChanged",false);p.Drain();p.controller.RefreshActiveProperties();p.Drain()
        assert(Field("shadow_color").disabled)
        Field("shadow"):Fire("OnValueChanged",true);p.Drain();p.controller.RefreshActiveProperties();p.Drain()
        assert(not Field("shadow_color").disabled)
        local media=p.ns.GUI.Editor.MediaLibrary;p.ns.GUI.Editor.MediaLibrary=nil
        p.controller.RefreshActiveProperties();p.Drain()
        -- The existing picker remains visible but disabled without a media service.
        local fontButton
        p.Walk(Body(),function(w)
            local c=w.children or {};if c[1] and c[1].type=="Label" and c[1].label:GetText()=="Font"then
                p.Walk(w,function(child)if child.type=="Button"then fontButton=child end end)
            end
        end)
        assert(fontButton and fontButton.disabled)
        p.ns.GUI.Editor.MediaLibrary=media;p.controller.RefreshActiveProperties();p.Drain();Check(true)
    end
end)
Test("state-template controls still require both existing mutation capabilities",function()
    for _,mode in ipairs({false,true})do
        Start(mode)
        local mutations=p.ns.GUI.Editor.Inspector.Mutations
        for _,name in ipairs({"AssignTextStateTemplate","UnassignTextStateTemplate"})do
            local saved=mutations[name];mutations[name]=nil
            p.controller.RefreshActiveProperties();p.Drain()
            local fields=Fields();assert(not fields.dead_template and not fields.ghost_template)
            for _,tab in pairs(p.Tabs())do assert(not tab.disabled)end
            for _,group in ipairs(Body().children)do
                assert(group.type~="InlineGroup" or group.titletext:GetText()~="State Templates")
            end
            assert(fields.point and fields.overflow and fields.shadow)
            mutations[name]=saved;p.controller.RefreshActiveProperties();p.Drain();Check(true)
        end
    end
end)
Test("refresh, pooling, unit/layout changes and reopen preserve full Text controls and framed tabs",function()
    for _,mode in ipairs({false,true})do
        Start(mode);local expected=p.h.Copy(unit.Texts);local general=p.h.Copy(db.profile.General)
        for _=1,20 do
            p.controller.RefreshActiveProperties();p.Drain();Check(true)
            p.Select("PowerBar");Select("linkedText");Check(true);Select("localText");Check(true)
            window.closebutton:GetScript("OnClick")(window.closebutton);p.Drain();assert(p.state.IsArrange())
            window=p.Build();p.Drain();Check(true)
        end
        local root=p.ns.ActiveLayoutResolver.GetActiveRuntimeRoot();root.units.target=p.h.Copy(unit)
        Select("localText","target");Check(true)
        assert(p.state.Get().selectedUnit=="target" and p.selection.GetSelectedObject().unit=="target")
        local ok,id=p.ns.LayoutMutations.CopyLayout("layout:existing",nil,{activate=false});assert(ok)
        assert(p.ns:ActivateLayout(id));p.controller.BuildInspector(nil,{GetEditorState=p.state.Get});p.Drain()
        Select("linkedText");Check(true)
        p.h.Equal(p.ns.UnitFrameUtils.GetUnitDB("player").Texts,expected);p.h.Equal(db.profile.General,general)
    end
end)
Test("tab switches retain framed owners, controls and release bindings without allocating widgets",function()
    Start(false);Click("behavior");local body=Body();local control=Field("point");local area=Actions()
    local release=area.events.OnRelease;local before=p.h.Copy(db);local a,r,t=p.Stats()
    for _=1,30 do for _,tab in ipairs({"appearance","geometry","behavior"})do
        window._focalPointPropertyScroll:SetScroll(400);Click(tab);Check(true)
        assert(p.state.Get().inspectorPropertyGroup==tab)
        assert(window._focalPointPropertyScroll.status.scrollvalue==0)
        assert(Body()==body and Field("point")==control and Actions()==area and area.events.OnRelease==release)
    end end
    local aa,rr,tt=p.Stats();assert(a==aa and r==rr and t==tt);p.h.Equal(db,before)
end)
Test("released Text tab callbacks are inert after rebuild, object switch and close/reopen",function()
    Start(true);Click("behavior")
    local old=p.Tabs().geometry.events.OnClick
    p.controller.RefreshActiveProperties();p.Drain();old();Check(true)
    assert(p.state.Get().inspectorPropertyGroup=="behavior")
    old=p.Tabs().geometry.events.OnClick;p.Select("PowerBar");old()
    assert(p.selection.GetSelectedObject().objectKey=="PowerBar" and p.state.Get().inspectorPropertyGroup=="behavior")
    Select();Check(true);old=p.Tabs().geometry.events.OnClick
    window.closebutton:GetScript("OnClick")(window.closebutton);p.Drain();old();assert(p.state.IsArrange())
    window=p.Build();p.Drain();old();Check(true)
    assert(p.state.Get().inspectorPropertyGroup=="behavior")
end)
Test("Delete is unique and tab-independent and preserves the existing Cancel/Confirm workflow",function()
    local forms=p.ns.GUI.Helpers.FormWidgets;local original=forms.CreateCompactConfirmation
    local options,dialog
    forms.CreateCompactConfirmation=function(input)options=input;dialog=original(input);return dialog end
    for _,mode in ipairs({false,true})do for _,tab in ipairs({"appearance","geometry","behavior"})do
        Start(mode,"linkedText");Click(tab);Check(true)
        local record=unit.Texts.linkedText;local before=p.h.Copy(db)
        local _,button=Actions();button:Fire("OnClick");assert(options and dialog)
        p.h.Equal(db,before);options.cancel.onClick(dialog);p.Drain();p.h.Equal(db,before)
        assert(unit.Texts.linkedText==record);Check(true)
        local untouched=p.h.Copy(unit.Texts.localText);local templates=p.h.Copy(db.global.TextTemplates)
        _,button=Actions();button:Fire("OnClick");options.primary.onClick(dialog);p.Drain()
        assert(not unit.Texts.linkedText and p.selection.GetSelectedObject().kind=="unit")
        p.h.Equal(unit.Texts.localText,untouched);p.h.Equal(db.global.TextTemplates,templates)
        assert(p.ns.TextTemplateLibrary.ResolveTemplateEntity(record.templateId,db))
        p.Walk(window._focalPointPropertyScroll,function(w)
            assert(w:GetUserData("focalPointSectionKey")~="texts","deleted Text body retained")
        end)
    end end
    forms.CreateCompactConfirmation=original
end)
Test("user templates, long names and missing main/state references stay in the Behavior group",function()
    local id="tpl:u:"..string.rep("a",32)..":1-2-"..string.rep("b",32)..":1"
    local name=string.rep("Langer Vorlagenname ",12)
    for _,mode in ipairs({false,true})do
        Start(mode);db.global.TextTemplates[id]={name=name,content="[name]"}
        unit.Texts.linkedText.templateId=id
        Select("linkedText");Click("behavior");Check(true)
        assert(not Button("Edit Text..."))
        local content=Body().children[2];assert(content.titletext:GetText()=="Content")
        local labelFound=false;p.Walk(content,function(w)
            if w.type=="Label" and (w.label:GetText() or ""):find(name,1,true)then labelFound=true end
        end);assert(labelFound)
        local missing="tpl:b:missing-main";local stateMissing="tpl:b:missing-state"
        unit.Texts.linkedText.templateId=missing
        unit.Texts.linkedText.stateTemplateIds={dead=stateMissing,ghost="tpl:b:default-002"}
        p.controller.RefreshActiveProperties();p.Drain();Check(true)
        local warning
        for _,group in ipairs(Body().children)do if group.type=="InlineGroup" and group.titletext:GetText()=="Content"then
            p.Walk(group,function(w)if w.type=="Label" and (w.label:GetText() or ""):find("Missing template:",1,true)then warning=w.label:GetText()end end)
        end end
        assert(warning and warning:find(missing,1,true) and warning:find(stateMissing,1,true))
        assert(Field("dead_template").value==stateMissing and Field("ghost_template").value=="tpl:b:default-002")
        local before=p.h.Copy(db)
        for _,tab in ipairs({"geometry","appearance","behavior"})do Click(tab);Check(true)end
        p.h.Equal(db,before)
    end
end)
assert(#p.h.ui.env.errors==0,table.concat(p.h.ui.env.errors,"\n"))
print("Text Property Modes: "..count.." groups PASS")
