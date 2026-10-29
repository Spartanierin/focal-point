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
        assert(not w:GetUserData("normalAbsorbPropertyTab"),"Text must retain framed Sections")
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
local function Check(full,host)
    local fields=Fields(host)
    for _,key in ipairs(basic)do assert(fields[key],key)end
    for _,key in ipairs(extended)do assert((fields[key]~=nil)==full,"mode availability: "..key)end
    if not host then
        local titles={};for _,group in ipairs(Body().children)do
            if group.type=="InlineGroup"then titles[#titles+1]=group.titletext:GetText();assert(group.parent==Body())end
        end
        assert(table.concat(titles,",")=="Content,Appearance,Position,Advanced,Actions")
        assert(Button("Choose Template...") and Button("Delete Text"))
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
            Field(change[1]):Fire("OnValueChanged",change[2]);p.Drain();expected[change[3]]=change[2]
        end
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
        Start(mode);Field("enabled"):Fire("OnValueChanged",false);p.Drain();Check(true)
        for key,w in pairs(Fields())do if key~="enabled"then assert(w.disabled,key)end end
        Field("enabled"):Fire("OnValueChanged",true);p.Drain();assert(not Field("point").disabled)
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
            for _,group in ipairs(Body().children)do
                assert(group.type~="InlineGroup" or group.titletext:GetText()~="Advanced")
            end
            assert(fields.point and fields.overflow and fields.shadow)
            mutations[name]=saved;p.controller.RefreshActiveProperties();p.Drain();Check(true)
        end
    end
end)
Test("refresh, pooling, unit/layout changes and reopen preserve full Text controls without new tabs",function()
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
assert(#p.h.ui.env.errors==0,table.concat(p.h.ui.env.errors,"\n"))
print("Text Property Modes: "..count.." groups PASS")
