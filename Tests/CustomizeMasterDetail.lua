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
    assert(header.children[1].label:GetText()==unitName)
    assert(window._focalPointComponentsButton.label:GetText()=="› "..(ns.L and ns.L.EDITOR_COMPONENTS or "Components"))
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
Test("Player to Power Bar uses one complete breadcrumb and Back retains existing Properties widgets",function()
    db,unit=Setup();unit.powerBarPresent=true;unit.showPowerBar=true
    window=Build();Check("components")
    local header=window._focalPointInspectorContent.children[1]
    local unitKey=state.Get().selectedUnit
    local unitName=ns.GetLabel and ns.KeyMap and ns.KeyMap.Units and ns.GetLabel(ns.KeyMap.Units,unitKey) or unitKey
    assert(header.children[1].label:GetText()==unitName)
    assert(window._focalPointObjectBreadcrumb.label:GetText()=="")
    local row
    for i=1,Tree().control.count do
        local candidate=Tree().control.rows[i]
        if candidate.item.node.type=="powerbar"then row=candidate;break end
    end
    assert(row);row.frame:Run("OnMouseDown","LeftButton");Drain();Check("properties")
    local selected=selection.GetSelectedObject()
    assert(selected.unit==unitKey and selected.kind=="bar" and selected.objectKey=="PowerBar")
    assert(window._focalPointObjectBreadcrumb.label:GetText()=="› "..(ns.L.ELEMENT_POWER_BAR or "Power Bar"))
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
    assert(header.children[2]==window._focalPointComponentsButton and #window._focalPointInspectorContent.children==3)
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
Test("actual Window release restores title presentation and native X before pooling",function()
    local ace=h.ui.ace
    ace:Release(window)
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
    ace:Release(window)
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
print("Customize Master Detail: "..count.." groups PASS")
