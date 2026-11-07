-- Real Workspace, TreeView, ObjectSelection, Inspector and mutations.
local function Read(path)local f=assert(io.open(path));local s=f:read("*a");f:close();return s end
local source=Read("Tests/NormalAbsorbPropertyGroups.lua")
local stop=assert(source:find("\nlocal count=0",1,true))
local h,ns,state,controller,selection,Setup,Build,Drain,Tree,Node,Control=assert(load(source:sub(1,stop)..
    "\nreturn h,ns,state,controller,selection,Setup,function()window=Build();return window end,Drain,Tree,Node,Control","@MasterDetail/Workspace"))()
local window,unit,db
local function Check(view)
    assert(window._focalPointCustomizeView==view)
    local tree=window._focalPointCompositionHost
    local properties=window._focalPointPropertyScroll.parent
    assert(tree.frame:IsShown()==(view=="components"))
    assert(properties.frame:IsShown()==(view=="properties"))
    assert(tree.frame:GetWidth()==math.min(360,window._focalPointInspectorContent.frame:GetWidth()))
    assert(properties.frame:GetWidth()==window._focalPointInspectorContent.frame:GetWidth())
    assert(properties.frame.points.TOPLEFT.x==0)
    local header=window._focalPointInspectorContent.children[1]
    local back=window._focalPointComponentsButton
    assert(back.type=="Button" and back.frame:IsShown()==(view=="properties"))
    assert(back.disabled==(view~="properties"))
    assert(header.children[2].type=="Label" and header.children[2].frame:IsShown()==(view=="components"))
    assert(#header.children==3 and header.children[1]==back and header.children[3]==window._focalPointObjectBreadcrumb)
    assert(header.children[3].frame:IsShown()==(view=="properties"))
    local visible={};for _,child in ipairs(header.children)do if child.frame:IsShown()then visible[#visible+1]=child end end
    if view=="properties" then
        assert(#visible==2 and visible[1]==back and visible[2]==header.children[3])
    else
        assert(#visible==1 and visible[1]==header.children[2])
    end
    assert(back.frame:GetHeight()==30 and back.frame:GetWidth()==110)
    assert(back.text:GetText()==(ns.L.EDITOR_BACK_TO_COMPONENTS or "<- Back"))
    local _,backSize=back.text:GetFont()
    assert(backSize==13 and back.text.lastSetJustifyH[1]=="CENTER" and back.text.lastSetJustifyV[1]=="MIDDLE")
    local object=window._focalPointObjectBreadcrumb
    local _,objectSize=object.label:GetFont()
    assert(objectSize==13 and object.label.lastSetJustifyH[1]=="RIGHT" and object.label.lastSetJustifyV[1]=="MIDDLE")
    assert(object:GetUserData("cell").alignH=="start")
    if view=="properties"then
        assert(back.frame.points.LEFT.relative==header.content and back.frame.points.LEFT.x==0)
        assert(object.frame.points.LEFT.relative==header.content and object.frame.points.LEFT.x==114)
        assert(not object.frame.points.RIGHT)
        assert(math.abs(object.frame.points.LEFT.x+object.frame:GetWidth()-(header.content:GetWidth()-32))<.01)
        assert(math.abs(back.frame.points.TOP.y-back.frame:GetHeight()/2-object.frame.points.TOP.y+object.frame:GetHeight()/2)<.01)
    end
    assert(not back.frame._fpComponentsBackBorder and not back.frame._fpComponentsBackFill)
    assert(type(back.frame:GetScript("OnClick"))=="function")
    assert(back.events.OnClick and not back.events.OnEnter and not back.events.OnLeave and not back.events.OnRelease)
    assert(header.frame:GetHeight()==30 and header:GetUserData("table").columns[1].width==back.frame:GetWidth())
end
local function Pick(kind,key)
    local node
    for _,row in ipairs(Tree().options.visibleRows)do
        if row.node.type==kind then node=row.node;break end
    end
    Tree().control.callbacks.onSelect(node or Node(kind,key));Drain();Check("properties")
end
local function Back()window._focalPointComponentsButton:Fire("OnClick");Drain();Check("components")end
local count=0
local function Test(name,fn)fn();count=count+1;print("PASS: "..name)end
Test("open starts with one compact Components list and existing X",function()
    db,unit=Setup();unit.normalAbsorbBarPresent=true;unit.showNormalAbsorbBar=true
    window=Build();Check("components")
    assert(window.closebutton:IsShown() and window.closebutton:GetScript("OnClick"))
    local header=window._focalPointInspectorContent.children[1]
    assert(window.frame:GetWidth()==392 and header.frame:IsShown())
    local unitKey=state.Get().selectedUnit
    local unitName=ns.GetLabel and ns.KeyMap and ns.KeyMap.Units and ns.GetLabel(ns.KeyMap.Units,unitKey) or unitKey
    assert(window.titletext:GetText():find(unitName,1,true))
    assert(window._focalPointComponentsButton.text:GetText()==(ns.L.EDITOR_BACK_TO_COMPONENTS or "<- Back"))
    assert(header.children[2].label:GetText()==(ns.L.EDITOR_COMPONENTS or "Components"))
    assert(window._focalPointObjectBreadcrumb.label:GetText()=="")
    assert(not window._focalPointArrangeButton and not window._focalPointCloseButton)
    local _,size=window.titletext:GetFont();assert(size==18)
    h.Equal(window.titletext.lastSetTextColor,{1,1,1,1})
    assert(window.titletext.points.TOPLEFT.x==36 and window.titletext.points.TOPLEFT.y==-18)
    assert(window.titletext.points.TOPRIGHT.x==-36)
    assert(#window._focalPointInspectorContent.children==3)
    assert(selection.GetSelectedObject().kind=="unit")
end)
Test("tree selection opens existing Properties and Back preserves canonical selection and tree state",function()
    local width,height=window.frame:GetWidth(),window.frame:GetHeight()
    Pick("healthbar")
    assert(selection.GetSelectedObject().objectKey=="HealthBar")
    local context=Tree();local tree=context.control
    local scroll=tree.offset;local expanded=context.options.expanded
    Back()
    assert(window.frame:GetWidth()==width)
    assert(Tree().control==tree and Tree().options.expanded==expanded and tree.offset==scroll)
    assert(selection.GetSelectedObject().objectKey=="HealthBar")
    Pick("healthbar") -- same selected object must still enter Properties.
    local label=window._focalPointObjectBreadcrumb.label:GetText()
    assert(label:find(ns.CompositionTreeView.GetSelectedNode().label,1,true))
    assert(window.frame:GetWidth()==600 and window.frame:GetHeight()==math.min(520,UIParent:GetHeight()-100))
end)
Test("collapse, disabled objects and checkbox toggles retain their existing semantics",function()
    Back();local node=Tree().options.visibleRows[2].node;assert(node.type=="healthbar")
    Tree().control.callbacks.onExpand(node,false)
    Check("components");assert(Tree().options.expanded[node.id]==false)
    Tree().control.callbacks.onExpand(node,true)
    local absorb
    for _,row in ipairs(Tree().options.visibleRows)do if row.node.type=="normalAbsorbBar"then absorb=row.node end end
    Tree().control.callbacks.onToggle(assert(absorb),false);Drain()
    Check("components");assert(unit.showNormalAbsorbBar==false)
    Pick("normalAbsorbBar")
    assert(selection.GetSelectedObject().objectKey=="NormalAbsorbBar")
end)
Test("existing property callbacks mutate real data; removing an object leaves no stale Properties",function()
    Control("Show","CheckBox"):Fire("OnValueChanged",true);Drain()
    Control("Size Mode","Dropdown"):Fire("OnValueChanged","CUSTOM");Drain()
    Control("Height","FPCompactSlider"):Fire("OnValueChanged",26);Drain()
    assert(unit.normalAbsorbBarHeight==26)
    Back()
    local forms=ns.GUI.Helpers.FormWidgets
    local create,confirmation=forms.CreateCompactConfirmation
    forms.CreateCompactConfirmation=function(options)confirmation=create(options);return confirmation end
    for i=1,Tree().control.count do
        local row=Tree().control.rows[i]
        if row.item.node.type=="normalAbsorbBar"then row.remove:Run("OnMouseDown","LeftButton");break end
    end
    forms.CreateCompactConfirmation=create
    assert(confirmation);confirmation.primaryButton:Fire("OnClick");Drain()
    assert(not unit.normalAbsorbBarPresent)
    assert(selection.GetSelectedObject().objectKey~="NormalAbsorbBar")
    assert(not (window._focalPointObjectBreadcrumb.label:GetText() or ""):find("Normal Absorb",1,true))
end)
Test("direct canvas selection opens Properties; unit and layout changes return to Components",function()
    Back();assert(selection.SelectObject({kind="text",unit="player",textKey="localText"}));Drain();Check("properties")
    local root=ns.ActiveLayoutResolver.GetActiveRuntimeRoot()
    root.units.target=h.Copy(unit)
    assert(selection.SelectObject({kind="unit",unit="target"}));Drain();Check("components")
    assert(window.titletext:GetText():find("target",1,true))
    Pick("unit")
    local ok,id=ns.LayoutMutations.CopyLayout("layout:existing",nil,{activate=false});assert(ok)
    assert(ns:ActivateLayout(id))
    controller.BuildInspector(nil,{GetEditorState=state.Get});Drain();Check("components")
end)
Test("stale navigation callbacks cannot affect rebuilt or reopened views; X closes Customize",function()
    Pick("unit")
    local old=window._focalPointComponentsButton.events.OnClick
    controller.BuildInspector(nil,{GetEditorState=state.Get});Drain()
    Pick("unit");old();Check("properties")
    local oldTree=Tree().control.callbacks.onSelect
    local close=ns.CloseConfig
    ns.CloseConfig=function()error("X must return to Arrange without closing the editor")end
    window.closebutton:GetScript("OnClick")(window.closebutton);Drain()
    ns.CloseConfig=close
    assert(state.IsArrange() and not controller.GetActiveInspectorHost())
    oldTree(Node("unit"));assert(state.IsArrange())
    assert(Build()==window);Check("components")
end)
Test("30 navigation and reopen cycles retain one Window and current widget owners",function()
    for _=1,30 do
        Pick("unit");Back()
        assert(#window._focalPointInspectorContent.children==3)
        window.closebutton:GetScript("OnClick")(window.closebutton);Drain()
        assert(Build()==window);Check("components")
    end
    assert(#h.ui.env.errors==0,table.concat(h.ui.env.errors,"\n"))
end)
Test("compact list remains bounded in a smaller viewport without narrowing Properties",function()
    local width,height=UIParent:GetWidth(),UIParent:GetHeight()
    UIParent:SetSize(400,height);controller.UpdateActiveInspectorGeometry()
    Check("components")
    assert(window._focalPointCompositionHost.frame:GetWidth()<360)
    local frameWidth,frameHeight=window.frame:GetWidth(),window.frame:GetHeight()
    Pick("unit");Back()
    assert(window.frame:GetWidth()==frameWidth and window.frame:GetHeight()==frameHeight)
    UIParent:SetSize(width,height);controller.UpdateActiveInspectorGeometry()
    Check("components")
    assert(window._focalPointCompositionHost.frame:GetWidth()==360)
end)
Test("Unit title and plain Power Bar context retain existing Properties widgets on Back",function()
    db,unit=Setup();unit.powerBarPresent=true;unit.showPowerBar=true
    window=Build();Check("components")
    local header=window._focalPointInspectorContent.children[1]
    local unitKey=state.Get().selectedUnit
    local unitName=ns.GetLabel and ns.KeyMap and ns.KeyMap.Units and ns.GetLabel(ns.KeyMap.Units,unitKey) or unitKey
    assert(window.titletext:GetText():find(unitName,1,true))
    assert(window._focalPointObjectBreadcrumb.label:GetText()=="")
    local row
    for i=1,Tree().control.count do
        local candidate=Tree().control.rows[i]
        if candidate.item.node.type=="powerbar"then row=candidate;break end
    end
    assert(row);row.frame:Run("OnMouseDown","LeftButton");Drain();Check("properties")
    local selected=selection.GetSelectedObject()
    assert(selected.unit==unitKey and selected.kind=="bar" and selected.objectKey=="PowerBar")
    assert(window._focalPointObjectBreadcrumb.label:GetText()==(ns.L.ELEMENT_POWER_BAR or "Power Bar"))
    local scroll=window._focalPointPropertyScroll
    local widgets={}
    local function Collect(w)
        widgets[#widgets+1]=w
        for _,child in ipairs(w.children or {})do Collect(child)end
    end
    Collect(scroll)
    local ace=h.ui.ace;local create,release=ace.Create,ace.Release;local acquired,released=0,0
    ace.Create=function(...)acquired=acquired+1;return create(...)end
    ace.Release=function(...)released=released+1;return release(...)end
    Back();ace.Create,ace.Release=create,release
    assert(acquired==0 and released==0,"Back rebuilt existing Inspector widgets")
    assert(scroll==window._focalPointPropertyScroll and widgets[1]==scroll)
    local previous=widgets;widgets={};Collect(scroll)
    assert(#widgets==#previous)
    for i,w in ipairs(previous)do assert(widgets[i]==w,"Inspector widget identity changed on Back")end
    h.Equal(selection.GetSelectedObject(),selected)
    assert(window._focalPointObjectBreadcrumb.label:GetText()=="")
    assert(header.children[1]==window._focalPointComponentsButton and #window._focalPointInspectorContent.children==3)
end)
Test("Back retains nonzero tree scrolling and expanded branches for a selected child",function()
    for i=1,45 do unit.Texts["extra"..i]={tag="[name]",enabled=true}end
    controller.RefreshCompositionTree();Drain()
    local tree=Tree().control
    -- Same native viewport boundary used by CompositionTreePresentation.
    tree.frame:SetSize(360,102);assert(tree:Layout())
    Tree().control.callbacks.onSelect(Node("text","extra9"));Drain();Check("properties")
    local offset=tree.offset;assert(offset>0,"fixture did not exercise a scrolled selection")
    local expanded=Tree().options.expanded
    local before=h.Copy(selection.GetSelectedObject())
    Back()
    assert(Tree().control==tree and tree.offset==offset)
    assert(Tree().options.expanded==expanded)
    h.Equal(selection.GetSelectedObject(),before)
end)
Test("localized Back breadcrumb retains Unit/object context and table slots through repeated view changes",function()
    local locale=GetLocale
    local savedBack,savedComponents=ns.L.EDITOR_BACK_TO_COMPONENTS,ns.L.EDITOR_COMPONENTS
    for _,lang in ipairs({"enUS","deDE"})do
        GetLocale=function()return lang end
        local localized={L={}};assert(loadfile("Locales/"..lang..".lua"))("FocalPoint",localized)
        ns.L.EDITOR_BACK_TO_COMPONENTS=assert(localized.L.EDITOR_BACK_TO_COMPONENTS)
        ns.L.EDITOR_COMPONENTS=assert(localized.L.EDITOR_COMPONENTS)
        db,unit=Setup();unit.powerBarPresent=true;unit.showPowerBar=true;window=Build();Check("components")
        assert(window._focalPointComponentsButton.text:GetText()==(lang=="deDE" and "<- Zurück" or "<- Back"))
        local header=window._focalPointInspectorContent.children[1]
        local titleText=window.titletext:GetText()
        for _=1,3 do
            Pick("powerbar")
            local node=assert(ns.CompositionTreeView.GetSelectedNode())
            assert(window._focalPointObjectBreadcrumb.label:GetText()==node.label)
            assert(window.titletext:GetText()==titleText)
            assert(window._focalPointObjectBreadcrumb.label.lastSetJustifyH[1]=="RIGHT")
            local selected=h.Copy(selection.GetSelectedObject())
            window._focalPointComponentsButton.frame:Run("OnClick","LeftButton");Drain();Check("components")
            h.Equal(selection.GetSelectedObject(),selected)
            assert(window._focalPointObjectBreadcrumb.label:GetText()=="")
        end
    end
    GetLocale=locale
    ns.L.EDITOR_BACK_TO_COMPONENTS,ns.L.EDITOR_COMPONENTS=savedBack,savedComponents
end)
Test("long component names stay in the right header cell without changing navigation or selection",function()
    db,unit=Setup();unit.powerBarPresent=true;unit.showPowerBar=true;window=Build()
    Pick("powerbar")
    local node=assert(ns.CompositionTreeView.GetSelectedNode())
    local originalName=node.label
    local selected=h.Copy(selection.GetSelectedObject())
    for _,name in ipairs({"Health","Healing Absorb","Very long selected component name for header clipping and alignment"})do
        node.label=name
        window._focalPointSetCustomizeView("properties");Check("properties")
        local object=window._focalPointObjectBreadcrumb
        assert(object.label:GetText()==name and object.label.lastSetWordWrap[1]==false)
        assert(object.frame.points.LEFT.x>=window._focalPointComponentsButton.frame:GetWidth()+4)
        h.Equal(selection.GetSelectedObject(),selected)
    end
    node.label=originalName
    Back()
end)
Test("actual Window release restores title presentation and native X before pooling",function()
    local ace=h.ui.ace
    local backFrame=window._focalPointComponentsButton.frame
    ace:Release(window)
    assert(not backFrame._fpComponentsBackBorder and not backFrame._fpComponentsBackFill)
    assert(not controller.GetActiveInspectorHost() and not ns.GUI.Editor._persistentInspector)
    local create=ace.Create
    local captured
    ace.Create=function(self,kind,...)
        local owner=create(self,kind,...)
        if kind=="Window"then
            captured={font={owner.titletext:GetFont()},color={owner.titletext:GetTextColor()},
                close=owner.closebutton:GetScript("OnClick"),points={}}
            for i=1,owner.titletext:GetNumPoints()do captured.points[i]={owner.titletext:GetPoint(i)}end
        end
        return owner
    end
    window=Build();ace.Create=create
    assert(captured);Check("components")
    backFrame=window._focalPointComponentsButton.frame
    ace:Release(window)
    assert(not backFrame._fpComponentsBackBorder and not backFrame._fpComponentsBackFill)
    h.Equal({window.titletext:GetFont()},captured.font)
    h.Equal({window.titletext:GetTextColor()},captured.color)
    assert(window.closebutton:GetScript("OnClick")==captured.close)
    assert(window.titletext:GetNumPoints()==#captured.points)
    local points={}
    for i=1,window.titletext:GetNumPoints()do
        local point={window.titletext:GetPoint(i)};points[point[1]]=point
    end
    for _,point in ipairs(captured.points)do
        local actual=assert(points[point[1]])
        for j=1,5 do assert(actual[j]==point[j],"title anchor was not restored")end
    end
    assert(not controller.GetActiveInspectorHost() and not ns.GUI.Editor._persistentInspector)
end)
-- Real Canvas handlers share this existing Workspace/selection boundary.
for _,path in ipairs({"GUI/Editor/CanvasHoverOverlay.lua","GUI/Editor/TextEditorOverlay.lua"})do
    assert(loadfile(path))("FocalPoint",ns)
end
local hover,text=ns.GUI.Editor.CanvasHoverOverlay,ns.GUI.Editor.TextEditorOverlay
function h.ui.native:SetRotation(radians) self.rotation=radians end
function h.ui.native:GetFrameStrata()
    return self.lastSetFrameStrata and self.lastSetFrameStrata[1] or "MEDIUM"
end
local function CanvasFixture()
    db,unit=Setup();unit.powerBarPresent=true;unit.showPowerBar=true
    unit.Texts.localText.enabled=true
    window=Build();state.SetPresentation("customize")
    ns.framesUnlocked=true;ns.IsEditorActive=function()return true end
    local frame=CreateFrame("Frame",nil,UIParent);frame:SetSize(240,60);frame:Show()
    frame._fpUnit,frame.unit,frame.config="player","player",unit
    frame.MoveOverlay=CreateFrame("Frame",nil,frame);frame.MoveOverlay:Show()
    frame.Elements={}
    for _,key in ipairs({"HealthBar","PowerBar"})do
        local bar=CreateFrame("Frame",nil,frame);bar:SetSize(240,20);bar:Show();frame.Elements[key]=bar
    end
    frame.Texts={localText=frame:CreateFontString()};frame.Texts.localText:SetText("Visible local text")
    ns.frames={player=frame}
    text.UpdateFrame(frame);hover.UpdateFrame(frame)
    return frame
end
local function CanvasRow(kind,key)
    for _,row in ipairs(Tree().control.rows)do
        if row.item and row.item.node.type==kind and (not key or row.item.node.inspectorTarget.textKey==key)then return row end
    end
    error("missing row "..kind)
end
Test("Canvas component and text clicks show Components; explicit Tree activation opens Properties",function()
    local frame=CanvasFixture();Pick("healthbar")
    local zone=assert(frame._focalPointCanvasHoverZones["bar:PowerBar"])
    zone:Run("OnMouseDown","LeftButton");zone:Run("OnMouseUp","LeftButton");Drain();Check("components")
    assert(selection.GetSelectedObject().objectKey=="PowerBar" and CanvasRow("powerbar").item.selected)
    CanvasRow("powerbar").frame:Run("OnMouseDown","LeftButton");Drain();Check("properties")
    Back();CanvasRow("powerbar").frame:Run("OnMouseDown","LeftButton");Drain();Check("properties")
    local hit=assert(frame._focalPointTextEditorOverlays.localText)
    hit:Run("OnClick","LeftButton");Drain();Check("components")
    assert(selection.GetSelectedObject().textKey=="localText" and CanvasRow("textElement","localText").item.selected)
    CanvasRow("textElement","localText").frame:Run("OnMouseDown","LeftButton");Drain();Check("properties")
    Back();text.UpdateFrame(frame)
    CanvasRow("textElement","localText").frame:Run("OnEnter")
    assert(not hover.GetHoveredObject() and hit._focalPointSelected and hit.VisualBounds:IsShown())
    selection.SelectObject({kind="bar",unit="player",objectKey="HealthBar"});Drain();Check("properties")
end)
Test("Canvas component and text selection across Units keeps the new Unit tree visible",function()
    local frame=CanvasFixture();Pick("healthbar")
    local root=ns.ActiveLayoutResolver.GetActiveRuntimeRoot()
    root.units.target=h.Copy(unit)
    frame._fpUnit,frame.unit,frame.config="target","target",root.units.target
    ns.frames={target=frame};hover.UpdateFrame(frame);text.UpdateFrame(frame)
    local zone=frame._focalPointCanvasHoverZones["bar:PowerBar"]
    zone:Run("OnMouseDown","LeftButton");zone:Run("OnMouseUp","LeftButton");Drain();Check("components")
    assert(selection.GetSelectedObject().unit=="target" and CanvasRow("powerbar").item.selected)
    CanvasRow("powerbar").frame:Run("OnMouseDown","LeftButton");Drain();Check("properties")
    frame._focalPointTextEditorOverlays.localText:Run("OnClick","LeftButton");Drain();Check("components")
    assert(selection.GetSelectedObject().unit=="target" and selection.GetSelectedObject().textKey=="localText")
end)
Test("Tree arrows select without detail navigation, Enter and same-object clicks activate",function()
    CanvasFixture();Back()
    local control=Tree().control
    assert(control.callbacks.onKey("DOWN"));Drain();Check("components")
    assert(selection.GetSelectedObject().objectKey=="HealthBar")
    assert(Tree().control.callbacks.onKey("ENTER"));Drain();Check("properties")
    Back();assert(Tree().control.callbacks.onKey("LEFT"));Drain();Check("components")
    assert(selection.GetSelectedObject().kind=="unit")
    assert(Tree().control.callbacks.onKey("RIGHT"));Drain();Check("components")
    assert(selection.GetSelectedObject().objectKey=="HealthBar")
end)
Test("Tree hover uses visible reference targets, preserves selection/data and rejects late leave",function()
    local frame=CanvasFixture();Back()
    local before=h.Copy(db);local selected=h.Copy(selection.GetSelectedObject())
    local health,power=CanvasRow("healthbar"),CanvasRow("powerbar")
    health.frame:Run("OnEnter")
    assert(hover.GetHoveredObject().objectKey=="HealthBar" and hover.Frame:IsShown())
    assert(hover.Frame.points.TOPLEFT.relative==frame._focalPointCanvasHoverZones["bar:HealthBar"])
    frame._focalPointCanvasHoverZones["bar:HealthBar"]:Run("OnLeave")
    assert(hover.GetHoveredObject().objectKey=="HealthBar","Canvas leave cleared Tree-owned hover")
    local oldLeave=health.frame:GetScript("OnLeave")
    power.frame:Run("OnEnter");oldLeave();assert(hover.GetHoveredObject().objectKey=="PowerBar")
    h.Equal(selection.GetSelectedObject(),selected);h.Equal(db,before)
    power.frame:Run("OnLeave");assert(not hover.GetHoveredObject() and not hover.Frame:IsShown())
    frame.Elements.PowerBar:Hide();power.frame:Run("OnEnter");assert(not hover.GetHoveredObject())
    frame.Elements.PowerBar:Show();frame.Elements.PowerBar:SetSize(0,0)
    power.frame:Run("OnEnter");assert(not hover.GetHoveredObject(),"zero-size target produced a hover frame")
    frame.Elements.PowerBar:SetSize(240,20)
    local hit=assert(frame._focalPointTextEditorOverlays.localText)
    CanvasRow("textElement","localText").frame:Run("OnEnter")
    assert(hover.GetHoveredObject().kind=="text" and hit._focalPointTreeHovered and hit.VisualBounds:IsShown())
    assert(not hover.Frame:IsShown(),"text must not use generic hover chrome")
    CanvasRow("textElement","localText").frame:Run("OnLeave")
    assert(not hit._focalPointTreeHovered and not hit.VisualBounds:IsShown())
    h.Equal(selection.GetSelectedObject(),selected);h.Equal(db,before)
    health.frame:Run("OnEnter");local staleLeave=health.frame:GetScript("OnLeave")
    Tree().options.rebuild();assert(not hover.GetHoveredObject())
    CanvasRow("powerbar").frame:Run("OnEnter");staleLeave();assert(hover.GetHoveredObject().objectKey=="PowerBar")
    Pick("powerbar");assert(not hover.GetHoveredObject());Back()
    CanvasRow("healthbar").frame:Run("OnEnter");Tree().control.frame:Hide();assert(not hover.GetHoveredObject())
    Tree().control.frame:Show();CanvasRow("healthbar").frame:Run("OnEnter")
    window.closebutton:GetScript("OnClick")(window.closebutton);Drain();assert(not hover.GetHoveredObject())
    window=Build();assert(not hover.GetHoveredObject())
end)
Test("selection context stays explicit and layout replacement releases only the old hover owner",function()
    local frame=CanvasFixture();Back()
    local nodes={};for _,row in ipairs(Tree().options.visibleRows)do
        if row.clickable then nodes[#nodes+1]=row.node end
    end
    assert(#nodes>=3)
    for _,node in ipairs(nodes)do
        Tree().control.callbacks.onSelect(node);Drain();Check("properties")
        local ref=selection.GetSelectedObject()
        assert(selection.SelectObject(ref,{view="components"}));Drain();Check("components")
        h.Equal(selection.GetSelectedObject(),ref)
    end
    Back();CanvasRow("healthbar").frame:Run("OnEnter")
    local oldLeave=CanvasRow("healthbar").frame:GetScript("OnLeave")
    local ok,id=ns.LayoutMutations.CopyLayout("layout:existing",nil,{activate=false});assert(ok)
    assert(ns:ActivateLayout(id));controller.BuildInspector(nil,{GetEditorState=state.Get});Drain()
    assert(not hover.GetHoveredObject())
    frame.config=ns.UnitFrameUtils.GetUnitDB("player");hover.UpdateFrame(frame)
    selection.SelectUnitRoot("player",{view="components"});Drain()
    CanvasRow("powerbar").frame:Run("OnEnter");oldLeave()
    assert(hover.GetHoveredObject().objectKey=="PowerBar")
    frame.Elements.PowerBar:Hide();hover.UpdateFrame(frame)
    assert(not hover.GetHoveredObject(),"hidden target retained Tree hover")
    state.SetPresentation("arrange");assert(not hover.SetTreeHover({kind="bar",unit="player",objectKey="HealthBar"},{}))
end)
assert(#h.ui.env.errors==0,table.concat(h.ui.env.errors,"\n"))
print("Customize Master Detail: "..count.." groups PASS")
