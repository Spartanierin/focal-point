-- Real Inspector sections, tree, mutations and selection in the existing Window.
-- Native geometry/hit testing remain client checks; data is detached.
local function Read(path)
    local file = assert(io.open(path)); local source = file:read("*a"); file:close(); return source
end
local source = Read("Tests/AddObjectPresentation.lua")
local stop = assert(source:find("local count = 0", 1, true))
local h, ns, state, controller, selection, Setup, Add = assert(load(source:sub(1, stop - 1) ..
    "\nreturn h,ns,state,controller,selection,Setup,Add", "@CustomizeWorkspace/Fixture"))()
ns.Ace = h.ui.ns.Ace
assert(loadfile("Libraries/Ace3/AceGUI-3.0/widgets/AceGUIWidget-InteractiveLabel.lua"))()
assert(loadfile("Libraries/Ace3/AceGUI-3.0/widgets/AceGUIWidget-Slider.lua"))()
assert(loadfile("GUI/Editor/Inspector/InspectorTextSelection.lua"))("FocalPoint", ns)
assert(loadfile("GUI/Editor/Inspector/InspectorBinding.lua"))("FocalPoint", ns)
assert(loadfile("GUI/Editor/Inspector/InspectorController.lua"))("FocalPoint", ns)
-- Health Threshold is now reachable in Quick too; load its real normalization dependency.
local getUnits, getUnit = ns.UnitFrameUtils.GetUnitsDB, ns.UnitFrameUtils.GetUnitDB
assert(loadfile("Engine/UnitFrame/Shared/UnitFrameUtils.lua"))("FocalPoint", ns)
ns.UnitFrameUtils.GetUnitsDB, ns.UnitFrameUtils.GetUnitDB = getUnits, getUnit
local pending = {}
function h.ui.native:SetObeyStepOnDrag(value) self.obeyStepOnDrag = value end
function h.ui.native:RegisterForDrag(...) self.dragButtons = {...} end
function h.ui.native:GetValue() return self.value or 0 end
function h.ui.native:SetHighlightTexture(...) self.lastSetHighlightTexture={...} end
function h.ui.native:SetPushedTexture(...) self.lastSetPushedTexture={...} end
function h.ui.native:RegisterForClicks(...) self.clickButtons={...} end
function h.ui.native:GetNormalTexture()
    if not self.normalTexture then self.normalTexture=self:CreateTexture();self.normalTexture:SetTexture(130755) end
    return self.normalTexture
end
function h.ui.native:GetCheckedTexture()
    if not self.checkedTexture then self.checkedTexture=self:CreateTexture();self.checkedTexture:SetTexture(130751) end
    return self.checkedTexture
end
function h.ui.native:SetChecked(checked) self.checked=checked;self:GetCheckedTexture():SetShown(checked) end
function h.ui.native:GetChecked() return self.checked end
function h.ui.native:Enable() self.nativeEnabled=true end
function h.ui.native:Disable() self.nativeEnabled=false end
function h.ui.native:IsEnabled() return self.nativeEnabled~=false end
C_Timer = {After = function(_, callback) pending[#pending + 1] = callback end}
local function Drain()
    local passes = 0
    while #pending > 0 do
        passes = passes + 1; assert(passes < 20)
        local batch = pending; pending = {}
        for _, callback in ipairs(batch) do callback() end
    end
end
local open = true
ns.GUI.RequestRefreshOptions = function()
    pending[#pending + 1] = function()
        if open then controller.BuildInspector(nil, {GetEditorState = state.Get}) end
    end
end
ns.CloseConfig = function()
    open = false; controller.ReleaseInspector(); state.SetPresentation("arrange")
end
local function Build()
    open = true; controller.SetPresentation("customize")
    controller.BuildInspector(nil, {GetEditorState = state.Get}); Drain()
    return assert(controller.GetActiveInspectorHost())
end
local function Tree()
    return assert(ns.CompositionTreeView._keyboardBindingContext)
end
local function Node(kind, key)
    for _, row in ipairs(Tree().options.visibleRows) do
        local node = row.node
        if node.inspectorTarget.kind == kind and (not key or node.inspectorTarget.objectKey == key
            or node.inspectorTarget.textKey == key) then return node end
    end
    error("missing node: " .. kind .. ":" .. tostring(key))
end
local function Labels(widget)
    local result = {}
    local function Walk(child)
        if child.type == "Label" then result[#result + 1] = child.label:GetText() or "" end
        for _, nested in ipairs(child.children or {}) do Walk(nested) end
    end
    Walk(widget); return table.concat(result, "\n")
end
local count = 0
local function Test(name, fn) fn(); count = count + 1; print("PASS: " .. name) end
local window, unit
Test("first open has one Window with current unit, tree and actual properties", function()
    local db; db, unit = Setup()
    window = Build()
    local body = window._focalPointInspectorContent
    assert(window.type == "Window" and #body.children == 3)
    assert(window._focalPointCompositionHost.parent == body)
    assert(window._focalPointPropertyScroll.parent.parent == body)
    assert(window.frame:GetWidth() == 392 and window.frame:GetHeight() == 620)
    assert(window.titletext:GetText():find("player", 1, true))
    local header=body.children[1]
    assert(header:GetUserData("table").columns[2].weight==1)
    assert(header.frame:IsShown() and #header.children==3)
    local back,componentsLabel,objectLabel=table.unpack(header.children)
    assert(back.type=="Button" and componentsLabel.type=="Label" and objectLabel.type=="Label")
    assert(back==window._focalPointComponentsButton and objectLabel==window._focalPointObjectBreadcrumb)
    local function CheckHeader(view)
        assert(window._focalPointCustomizeView==view)
        local properties=view=="properties"
        assert(objectLabel.frame:IsShown()==properties)
        assert(back.frame:IsShown()==properties and back.disabled==not properties)
        assert(componentsLabel.frame:IsShown()==not properties)
        local visible={}
        for _,child in ipairs(header.children)do if child.frame:IsShown()then visible[#visible+1]=child end end
        local navigation=properties and back or componentsLabel
        assert(componentsLabel.label:GetText()==(ns.L.EDITOR_COMPONENTS or "Components"))
        if properties then
            assert(#visible==2 and visible[1]==back and visible[2]==objectLabel)
            local node=assert(ns.CompositionTreeView.GetSelectedNode())
            assert(objectLabel.label:GetText()==node.label and objectLabel.label.lastSetJustifyH[1]=="RIGHT")
        else
            assert(#visible==1 and visible[1]==componentsLabel and objectLabel.label:GetText()=="")
        end
        header:DoLayout()
        local columns=header:GetUserData("table").columns
        assert(columns[1].width==back.frame:GetWidth() and columns[2].weight==1)
        assert(navigation.frame.points.LEFT.relative==header.content and navigation.frame.points.LEFT.x==0)
        if properties then
            assert(objectLabel.frame.points.LEFT.relative==header.content and objectLabel.frame.points.LEFT.x==columns[1].width+4)
        else
            assert(componentsLabel:GetUserData("cell").colspan==2)
            assert(componentsLabel.frame.points.RIGHT.relative==header.content)
        end
    end
    CheckHeader("components")
    local selected=h.Copy(selection.GetSelectedObject())
    for _=1,2 do
        Tree().control.callbacks.onSelect(Node("unit"));Drain();CheckHeader("properties")
        h.Equal(selection.GetSelectedObject(),selected)
        back:Fire("OnClick");Drain();CheckHeader("components")
        h.Equal(selection.GetSelectedObject(),selected)
    end
    assert(not window._focalPointArrangeButton and not window._focalPointCloseButton)
    assert(Tree().state == state.Get() and Tree().tree.unit == "player")
    assert(selection.GetSelectedObject().kind == "unit")
    assert(window._focalPointCompositionHost.frame.points.TOPLEFT.x == 0)
    assert(window._focalPointCompositionHost.frame:GetWidth() == math.min(360, window._focalPointInspectorContent.frame:GetWidth()))
    assert(window._focalPointPropertyScroll.parent.frame.points.TOPLEFT.x == 0)
    assert(window._focalPointCompositionHost.frame:IsShown())
    assert(not window._focalPointPropertyScroll.parent.frame:IsShown())
end)
Test("real Add Object, tree and canvas selection share one Inspector", function()
    controller.SetPresentation("arrange"); Drain()
    Add("Class Resource Bar"); Drain()
    assert(controller.GetActiveInspectorHost() == window and not state.IsArrange())
    local id = unit.segmentedBars[1].id
    assert(selection.GetSelectedObject().objectKey == id)
    assert(not Labels(window._focalPointPropertyScroll):find("player / Class Resource Bar 1", 1, true))
    assert(state.GetPropertyScope().kind == "segmentedBar")
    local node = Node("segmentedBar", id)
    Tree().control.callbacks.onToggle(node, false); Drain()
    assert(unit.segmentedBars[1].enabled == false)
    assert(Node("segmentedBar", id).enabled == false)
    Tree().control.callbacks.onSelect(Node("unit")); Drain()
    assert(selection.GetSelectedObject().kind == "unit")
    Tree().control.callbacks.onSelect(Node("segmentedBar", id)); Drain()
    assert(selection.GetSelectedObject().objectKey == id and not selection.GetSelectedObject().unavailable)
    -- Canvas uses the same public entry; no alternate selection in this fixture.
    assert(selection.SelectObject({kind = "text", unit = "player", textKey = "localText"})); Drain()
    assert(state.GetPropertyScope().sectionKey == "texts")
    assert(Tree().state.selectedTextElementId == "localText")
end)
Test("geometry refresh preserves moved Window; properties rebuild keeps one owner", function()
    window.frame:ClearAllPoints(); window.frame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 75, -80)
    controller.UpdateActiveInspectorGeometry()
    assert(window.frame.points.TOPLEFT.x == 75 and window.frame.points.TOPLEFT.y == -80)
    local body = window._focalPointInspectorContent
    local treeHost = window._focalPointCompositionHost
    local scroll = window._focalPointPropertyScroll
    controller.RefreshActiveProperties(); Drain()
    assert(window._focalPointPropertyScroll == scroll and window._focalPointCompositionHost == treeHost)
    assert(#body.children == 3 and scroll.status == state.Get().editorSidebarScroll)
    assert(scroll.status.scrollvalue == 0)
end)
Test("same-context rebuild reuses scroll state; selection resets it without moving Window", function()
    local scroll = window._focalPointPropertyScroll
    scroll:SetScroll(300)
    scroll.scrollbar:SetValue(300)
    local status = state.Get().editorSidebarScroll
    controller.BuildInspector(nil, {GetEditorState = state.Get}); Drain()
    assert(window._focalPointPropertyScroll.status == status)
    assert(#window._focalPointPropertyScroll.children > 0)
    -- This native double does not resolve the scroll viewport's anchored height.
    -- Exact offset retention is a client check, not a synthetic pixel assertion.
    -- A read-only HEAD/WIP comparison produced identical clamping in this fixture.
    controller.RefreshActiveProperties(); Drain()
    assert(status.scrollvalue == 0)
    assert(window.frame.points.TOPLEFT.x == 75 and window.frame.points.TOPLEFT.y == -80)
end)
Test("Arrange and Close reject retained callbacks and deferred UI restores", function()
    local treeCallback = Tree().control.callbacks.onSelect
    local node = Node("segmentedBar", unit.segmentedBars[1].id)
    local properties = ns.GUI.Editor._activeInspectorRefreshProperties
    local before = selection.GetSelectedObject().textKey
    window.closebutton:GetScript("OnClick")(window.closebutton)
    treeCallback(node); properties(); Drain()
    assert(state.IsArrange() and not window.frame:IsShown() and not controller.GetActiveInspectorHost())
    assert(selection.GetSelectedObject().textKey == before)
    Build()
    local oldBack = window._focalPointComponentsButton.events.OnClick
    controller.BuildInspector(nil, {GetEditorState = state.Get}); Drain()
    oldBack(); assert(open and controller.GetActiveInspectorHost() == window)
    window.closebutton:GetScript("OnClick")(window.closebutton); Drain()
    assert(open and state.IsArrange() and not window.frame:IsShown())
end)
Test("30 reopen/mode cycles reuse the Window and release old tree controls", function()
    for _ = 1, 30 do
        assert(Build() == window)
        local old = Tree().control.callbacks.onSelect
        local node = Node("unit")
        local scope = state.GetPropertyScope()
        window.closebutton:GetScript("OnClick")(window.closebutton); Drain()
        old(node); assert(state.GetPropertyScope() == scope)
        assert(not window.frame:IsShown())
    end
end)
Test("layout validation projects replacement unit data without new initial selection", function()
    local db = Setup(); Build()
    assert(selection.SelectObject({kind = "text", unit = "player", textKey = "localText"})); Drain()
    local ok, id = ns.LayoutMutations.CopyLayout("layout:existing", nil, {activate = false}); assert(ok)
    assert(ns:ActivateLayout(id))
    state.ValidateSelection(function(key) return ns.UnitFrameUtils.GetUnitDB(key) ~= nil end)
    controller.BuildInspector(nil, {GetEditorState = state.Get}); Drain()
    assert(state.GetPrimaryUnit() == "player" and selection.GetSelectedObject().textKey == "localText")
    assert(Tree().tree.unit == "player" and window._focalPointPropertyScroll)
    ns:CloseConfig(); Drain()
end)
Test("unit selection updates title, tree and properties in the same Window", function()
    local _, player = Setup(); Build()
    local units = ns.ActiveLayoutResolver.GetActiveRuntimeRoot().units
    units.target = h.Copy(player)
    assert(selection.SelectObject({kind = "unit", unit = "target"})); Drain()
    assert(controller.GetActiveInspectorHost() == window)
    assert(window.titletext:GetText():find("target", 1, true))
    assert(Tree().tree.unit == "target" and state.GetPrimaryUnit() == "target")
    Tree().control.callbacks.onSelect(Node("text", "localText")); Drain()
    local selected = selection.GetSelectedObject()
    assert(selected.unit == "target" and selected.textKey == "localText")
    assert(state.GetPropertyScope().sectionKey == "texts")
    assert(#window._focalPointPropertyScroll.children > 0)
    ns:CloseConfig(); Drain()
end)
-- Extend the real Workspace fixture for Root options and the production Boss unit catalog.
controller.ReleaseInspector()
-- Root restore actions can select Cast; use the same real dependencies as NormalAbsorbPropertyGroups.
UIParent.GetEffectiveScale = UIParent.GetEffectiveScale or function() return 1 end
for _,path in ipairs({"Data/Constants.lua","GUI/Layouts/UnitFrameDefinition.lua",
    "GUI/Helpers/OptionPaths.lua","GUI/Helpers/OptionValues.lua",
    "Engine/UnitFrame/Runtime/UnitFrameLayout.lua","Engine/UnitFrame/Bars/UnitFrameCastBar.lua",
    "GUI/Editor/EditorAnchorGeometry.lua",
    "GUI/Editor/ObjectSelection.lua","GUI/Editor/Composition/CompositionTreeView.lua",
    "GUI/Editor/Toolbar/ToolbarBinding.lua","GUI/Editor/Inspector/InspectorRefreshPolicy.lua",
    "GUI/Editor/Inspector/InspectorController.lua"})do
    assert(loadfile(path))("FocalPoint",ns)
end
selection=ns.GUI.Editor.ObjectSelection
local function RootWalk(w,fn)fn(w);for _,child in ipairs(w.children or {})do RootWalk(child,fn)end end
local function RootSection(host,key)
    local found;RootWalk(host,function(w)
        if w:GetUserData("focalPointSectionKey")==key and w._focalPointRequestRebuild then assert(not found);found=w end
    end);return found
end
local function RootFind(host,label,kind)
    local found,seen={},{}
    local function Add(w)if w.type==kind and not seen[w]then seen[w]=true;found[#found+1]=w end end
    RootWalk(host,function(w)
        if w.label and w.label.GetText and w.label:GetText()==label then Add(w)end
        if w.text and w.text.GetText and w.text:GetText()==label then Add(w)end
        local c=w.children or {}
        if c[1] and c[1].type=="Label" and c[1].label:GetText()==label and c[2]then RootWalk(c[2],Add)end
    end);return found
end
local function RootControl(label,kind,host)
    local list=RootFind(host or assert(RootSection(window._focalPointPropertyScroll,"frame")),label,kind)
    assert(#list==1,label..": expected one control, got "..#list);return list[1]
end
local function RootStart(expert,unitKey)
    local db,unit=Setup();db.profile={General={ExpertMode=expert}}
    state.SetMode(expert and "quick" or "expert")
    unitKey=unitKey or "player"
    if unitKey~="player"then
        local units=ns.ActiveLayoutResolver.GetActiveRuntimeRoot().units
        units[unitKey]=h.Copy(unit);unit=units[unitKey]
    end
    assert(selection.SelectObject({kind="unit",unit=unitKey}));window=Build();Drain()
    Tree().control.callbacks.onSelect(Node("unit"));Drain()
    assert(selection.GetSelectedObject().kind=="unit" and selection.GetSelectedObject().unit==unitKey)
    assert(window._focalPointCustomizeView=="properties")
    return db,unit
end
local function RootGroup(control)
    local group=control.parent;while group and group.type~="InlineGroup"do group=group.parent end
    return assert(group).titletext:GetText()
end
local function RootTabs()
    local tabs,order={},{}
    RootWalk(assert(RootSection(window._focalPointPropertyScroll,"frame")),function(w)
        local key=w:GetUserData("normalAbsorbPropertyTab")
        if key then assert(not tabs[key]);tabs[key]=w;order[#order+1]=key end
    end)
    assert(table.concat(order,",")=="appearance,geometry,behavior","Root tabs: "..table.concat(order,",")..
        "; selection="..tostring(selection.GetSelectedObject().kind).."; mode="..tostring(state.Get().presentation))
    return tabs
end
local function RootClickTab(key)RootTabs()[key]:Fire("OnClick");Drain()end
local function RootCheckTabs()
    local body=assert(RootSection(window._focalPointPropertyScroll,"frame"))
    local active=state.Get().inspectorPropertyGroup
    for _,tab in pairs(RootTabs())do assert(tab.frame:IsShown() and not tab.disabled)end
    local membership={General="behavior",Appearance="appearance",Geometry="geometry",Position="geometry",
        Visibility="behavior",Behavior="behavior",Advanced="geometry"}
    local groups={}
    for _,group in ipairs(body.children)do if group.type=="InlineGroup"then
        local title=group.titletext:GetText();assert(not groups[title]);groups[title]=group
        assert(group.parent==body and group.events.OnRelease)
        if membership[title]then
            assert(group:GetUserData("normalAbsorbPropertyGroup")==membership[title])
            assert(group:GetUserData("normalAbsorbPropertyContent") and #group.children>0)
            assert(group.frame:IsShown()==(active==membership[title]))
        else
            assert(title=="Actions" and group:GetUserData("normalAbsorbObjectActions"))
            assert(group.frame:IsShown() and not group:GetUserData("normalAbsorbPropertyGroup"))
            assert(not group:GetUserData("normalAbsorbPropertyContent"))
        end
        RootWalk(group,function(w)assert(not w:GetUserData("flatPropertyHeading"),"duplicate section heading")end)
    end end
    for title in pairs(membership)do assert(groups[title],title)end
    body:DoLayout();window._focalPointPropertyScroll:DoLayout()
    local height=0;for _,child in ipairs(body.children)do if child.frame:IsShown()then height=height+child.frame:GetHeight()end end
    assert(math.abs(body.frame:GetHeight()-height)<.01,"hidden Root groups consume scroll height")
    return body,groups
end
Test("Root Workspace exposes six former Expert fields once in both saved modes without writing defaults",function()
    for _,expert in ipairs({false,true})do
        local db,unit=RootStart(expert);local before=h.Copy(db)
        local sections={};local body=assert(RootSection(window._focalPointPropertyScroll,"frame"))
        for _,child in ipairs(body.children)do if child.type=="InlineGroup"then
            local title=child.titletext:GetText();assert(not sections[title]);sections[title]=true
        end end
        for _,title in ipairs({"General","Appearance","Geometry","Position","Visibility","Behavior","Advanced"})do assert(sections[title])end
        for _,f in ipairs({{"Border Width","FPCompactSlider","Appearance"},{"Border Color","ColorPicker","Appearance"},
            {"Mouse Enabled","CheckBox","Behavior"},{"Click Through","CheckBox","Behavior"},
            {"Frame Strata","Dropdown","Advanced"},{"Frame Level","EditBox","Advanced"}})do
            assert(RootGroup(RootControl(f[1],f[2]))==f[3])
        end
        assert(RootControl("Border Width","FPCompactSlider"):GetValue()==(unit.frameBorderWidth or 1))
        assert(RootControl("Frame Strata","Dropdown"):GetValue()==(unit.frameStrata or "MEDIUM"))
        assert(RootControl("Frame Level","EditBox"):GetText()==tostring(unit.frameLevel or 1))
        for _,f in ipairs({{"Enabled","CheckBox"},{"Transparency","FPCompactSlider"},{"Background Color","ColorPicker"},
            {"Height","FPCompactSlider"},{"Width","FPCompactSlider"},{"Scale","FPCompactSlider"},
            {"Anchor From","Dropdown"},{"Anchor To","Dropdown"},{"X Offset","FPCompactSlider"},{"Y Offset","FPCompactSlider"},
            {"Show in Solo","CheckBox"},{"Show in Party","CheckBox"},{"Show in Raid","CheckBox"},
            {"Show in Arena","CheckBox"},{"Show in PvP","CheckBox"}})do RootControl(f[1],f[2])end
        RootCheckTabs()
        h.Equal(db,before)
        assert(state.Get().mode==(expert and "quick" or "expert"))
    end
end)
Test("Root mutations, Click Through disabled dependency, rebuild and reopen preserve canonical values",function()
    for _,expert in ipairs({false,true})do
        local db,unit=RootStart(expert);local expected=h.Copy(unit);local profile=h.Copy(db.profile)
        RootControl("Border Width","FPCompactSlider"):Fire("OnValueChanged",0);expected.frameBorderWidth=0
        RootControl("Border Color","ColorPicker"):Fire("OnValueConfirmed",.2,.3,.4,0);expected.borderColor={.2,.3,.4,0,r=.2,g=.3,b=.4,a=0}
        RootControl("Frame Strata","Dropdown"):Fire("OnValueChanged","HIGH");expected.frameStrata="HIGH"
        RootControl("Frame Level","EditBox"):Fire("OnEnterPressed","17.6");expected.frameLevel=18
        h.Equal(unit,expected)
        RootControl("Mouse Enabled","CheckBox"):Fire("OnValueChanged",false);Drain();expected.mouseEnabled=false
        assert(RootControl("Click Through","CheckBox").disabled);h.Equal(unit,expected)
        RootControl("Mouse Enabled","CheckBox"):Fire("OnValueChanged",true);Drain();expected.mouseEnabled=true
        assert(not RootControl("Click Through","CheckBox").disabled)
        RootControl("Click Through","CheckBox"):Fire("OnValueChanged",true);expected.clickThrough=true;h.Equal(unit,expected)
        for _=1,3 do
            controller.RefreshActiveProperties();Drain()
            assert(RootControl("Border Width","FPCompactSlider"):GetValue()==0)
            assert(RootControl("Frame Strata","Dropdown"):GetValue()=="HIGH")
            assert(RootControl("Frame Level","EditBox"):GetText()=="18")
            assert(RootControl("Click Through","CheckBox"):GetValue())
            assert(selection.SelectObject({kind="text",unit="player",textKey="localText"}));Drain()
            assert(selection.SelectObject({kind="unit",unit="player"}));Drain()
        end
        window.closebutton:GetScript("OnClick")(window.closebutton);Drain();window=Build();Drain()
        assert(selection.GetSelectedObject().kind=="unit")
        assert(RootControl("Border Width","FPCompactSlider"):GetValue()==0)
        assert(RootControl("Frame Level","EditBox"):GetText()=="18")
        h.Equal(unit,expected);h.Equal(db.profile,profile)
    end
end)
Test("Root Legacy Properties and unscoped Frame/Visibility/Position retain their saved-mode gates",function()
    for _,expert in ipairs({false,true})do
        local db,unit=RootStart(expert)
        for _,propertiesOnly in ipairs({false,true})do
            for _,key in ipairs({"frame","visibility","positioning"})do state.SetSectionCollapsed(key,false)end
            local before=h.Copy(db);local host=h.ui.ace:Create("SimpleGroup")
            local builder=propertiesOnly and ns.GUI.Editor.Inspector.BuildProperties or ns.GUI.Editor.Inspector.Build
            builder(host,state.Get(),{getUnitConfig=ns.UnitFrameUtils.GetUnitDB})
            RootWalk(host,function(w)assert(not w:GetUserData("normalAbsorbPropertyTab"),"Legacy gained Root tabs")end)
            local frame=assert(RootSection(host,"frame"))
            local visibility=propertiesOnly and frame or assert(RootSection(host,"visibility"))
            for _,f in ipairs({{"Border Width","FPCompactSlider"},{"Border Color","ColorPicker"},
                {"Frame Strata","Dropdown"},{"Frame Level",propertiesOnly and "EditBox" or "Slider"}})do
                local controls=RootFind(frame,f[1],f[2])
                if not propertiesOnly and f[2]=="FPCompactSlider"then controls=RootFind(frame,f[1],"Slider")end
                assert(#controls==(expert and 1 or 0),f[1])
            end
            for _,label in ipairs({"Mouse Enabled","Click Through"})do
                assert(#RootFind(visibility,label,"CheckBox")== (expert and 1 or 0),label)
            end
            if not propertiesOnly then assert((RootSection(host,"positioning")~=nil)==expert)end
            assert(#RootFind(frame,"Width",propertiesOnly and "FPCompactSlider" or "Slider")==1)
            h.Equal(db,before);h.ui.ace:Release(host)
        end
    end
end)
Test("Root Boss spacing stays Boss-only and Unit/Layout changes bind the active root",function()
    for _,expert in ipairs({false,true})do
        for _,key in ipairs({"player","target","boss"})do
            local db,unit=RootStart(expert,key)
            local root=assert(RootSection(window._focalPointPropertyScroll,"frame"))
            local spacing=RootFind(root,"Boss Frame Spacing","FPCompactSlider")
            assert(#spacing==(key=="boss" and 1 or 0))
            RootCheckTabs()
            if key=="boss"then
                spacing[1]:Fire("OnValueChanged",14);assert(unit.bossSpacing==14)
            end
            RootControl("Frame Level","EditBox"):Fire("OnEnterPressed","9");assert(unit.frameLevel==9)
            local ok,id=ns.LayoutMutations.CopyLayout("layout:existing",nil,{activate=false});assert(ok)
            assert(ns:ActivateLayout(id));controller.BuildInspector(nil,{GetEditorState=state.Get});Drain()
            local active=ns.UnitFrameUtils.GetUnitDB(key);assert(active~=unit)
            RootControl("Frame Level","EditBox"):Fire("OnEnterPressed","12")
            assert(active.frameLevel==12 and unit.frameLevel==9)
        end
    end
end)
Test("Root tabs preserve controls, framed release owners and data across repeated tab, rebuild and navigation cycles",function()
    for _,expert in ipairs({false,true})do
        local db,unit=RootStart(expert);local body,groups=RootCheckTabs()
        local width=RootControl("Width","FPCompactSlider");local before=h.Copy(db);local releases={}
        for title,group in pairs(groups)do releases[title]=group.events.OnRelease end
        for _=1,20 do for _,tab in ipairs({"geometry","behavior","appearance"})do
            window._focalPointPropertyScroll:SetScroll(400);RootClickTab(tab)
            local currentBody,current=RootCheckTabs();assert(currentBody==body and RootControl("Width","FPCompactSlider")==width)
            for title,group in pairs(groups)do assert(current[title]==group and group.events.OnRelease==releases[title])end
            assert(window._focalPointPropertyScroll.status.scrollvalue==0)
        end end
        h.Equal(db,before)
        RootClickTab("behavior");RootControl("Mouse Enabled","CheckBox"):Fire("OnValueChanged",false);Drain()
        -- Disabled is derived at build time; keep the existing live-only mouse mutation policy.
        controller.RefreshActiveProperties();Drain()
        RootCheckTabs();assert(RootControl("Click Through","CheckBox").disabled and unit.mouseEnabled==false,
            "Mouse mutation/disabled: "..tostring(unit.mouseEnabled).."/"..tostring(RootControl("Click Through","CheckBox").disabled))
        RootControl("Mouse Enabled","CheckBox"):Fire("OnValueChanged",true);Drain()
        controller.RefreshActiveProperties();Drain();RootCheckTabs()
        assert(not RootControl("Click Through","CheckBox").disabled)
        local tab=RootTabs().geometry;local callback=tab.events.OnClick
        assert(selection.SelectObject({kind="text",unit="player",textKey="localText"}));Drain()
        local active=state.Get().inspectorPropertyGroup;before=h.Copy(db)
        callback(tab);Drain();assert(state.Get().inspectorPropertyGroup==active);h.Equal(db,before)
        assert(selection.SelectObject({kind="unit",unit="player"}));Drain();RootCheckTabs()
        window._focalPointSetCustomizeView("components");window._focalPointSetCustomizeView("properties");RootCheckTabs()
        tab=RootTabs().geometry;callback=tab.events.OnClick
        window.closebutton:GetScript("OnClick")(window.closebutton);Drain();window=Build();Drain();RootCheckTabs()
        active=state.Get().inspectorPropertyGroup;before=h.Copy(db);callback(tab);Drain()
        assert(state.Get().inspectorPropertyGroup==active);h.Equal(db,before)
        tab=RootTabs().geometry;callback=tab.events.OnClick
        local ok,id=ns.LayoutMutations.CopyLayout("layout:existing",nil,{activate=false});assert(ok)
        assert(ns:ActivateLayout(id));controller.BuildInspector(nil,{GetEditorState=state.Get});Drain();RootCheckTabs()
        active=state.Get().inspectorPropertyGroup;before=h.Copy(db);callback(tab);Drain()
        assert(state.Get().inspectorPropertyGroup==active);h.Equal(db,before)
    end
end)
Test("Root conditional restore and Remove actions remain available outside every tab",function()
    local cases={{"Add Power Bar","powerBarPresent"},{"Add Cast Bar","castBarPresent"},
        {"Add Normal Absorb","normalAbsorbBarPresent"},{"Add Healing Absorb","healingAbsorbBarPresent"}}
    for _,expert in ipairs({false,true})do for _,tab in ipairs({"appearance","geometry","behavior"})do
        for _,case in ipairs(cases)do
            local db,unit=RootStart(expert);unit[case[2]]=false;controller.RefreshActiveProperties();Drain()
            RootClickTab(tab);local _,groups=RootCheckTabs();assert(groups.Actions)
            local button=RootControl(case[1],"Button");assert(RootGroup(button)=="Actions" and button.frame:IsShown())
            button:Fire("OnClick");Drain();assert(unit[case[2]]==true)
        end
        local db,unit=RootStart(expert,"boss");RootClickTab(tab);local _,groups=RootCheckTabs();assert(groups.Actions)
        local remove=RootControl("Remove Boss Frames","Button")
        assert(RootGroup(remove)=="Actions" and remove.frame:IsShown())
        remove:Fire("OnClick");Drain();assert(unit.present==false)
    end end
end)
-- Decoration controls reuse the same real Workspace and row assertions as Root.
assert(loadfile("GUI/Layouts/UnitPortraitDefinition.lua"))("FocalPoint",ns)
local function DecorationStart(expert)
    local db,unit=RootStart(expert)
    local first=ns.InspectorMutations.AddDecoration({unitConfig=unit})
    local second=ns.InspectorMutations.AddDecoration({unitConfig=unit})
    assert(first.ok and second.ok)
    controller.RefreshCompositionTree()
    local counts={[first.newDecorationId]=0,[second.newDecorationId]=0}
    RootWalk(Tree().tree,function(node)
        local id=node.inspectorTarget and node.inspectorTarget.decorationId
        if counts[id]~=nil then counts[id]=counts[id]+1 end
    end)
    assert(counts[first.newDecorationId]==1 and counts[second.newDecorationId]==1)
    local function Select(id)
        assert(selection.SelectObject({kind="decoration",unit="player",decorationId=id}));Drain()
    end
    Select(first.newDecorationId)
    return db,unit,first.newValue,second.newValue,Select
end
local function DecorationBody()return assert(RootSection(window._focalPointPropertyScroll,"decoration"))end
local function DecorationControl(label,kind)return RootControl(label,kind,DecorationBody())end
local function DecorationTabs()
    local tabs,order={},{}
    RootWalk(DecorationBody(),function(w)
        local key=w:GetUserData("normalAbsorbPropertyTab")
        if key then assert(not tabs[key]);tabs[key]=w;order[#order+1]=key end
    end)
    assert(table.concat(order,",")=="appearance,geometry,behavior")
    return tabs
end
local function DecorationClickTab(key)DecorationTabs()[key]:Fire("OnClick");Drain()end
local function DecorationCheckTabs()
    local active=state.Get().inspectorPropertyGroup
    for _,tab in pairs(DecorationTabs())do assert(tab.frame:IsShown() and not tab.disabled)end
    local membership={Appearance="appearance",Geometry="geometry",Position="geometry",Behavior="behavior"}
    local groups={}
    for _,group in ipairs(DecorationBody().children)do
        if group.type=="InlineGroup"then
            local title=group.titletext:GetText();assert(not groups[title]);groups[title]=group
            assert(group.parent==DecorationBody() and group.events.OnRelease)
            if membership[title]then
                assert(group:GetUserData("normalAbsorbPropertyGroup")==membership[title])
                assert(group:GetUserData("normalAbsorbPropertyContent") and #group.children>0)
                assert(group.frame:IsShown()==(active==membership[title]))
            else
                error("unexpected Decoration Workspace group: "..title)
            end
            RootWalk(group,function(w)assert(not w:GetUserData("flatPropertyHeading"),"duplicate section heading")end)
        end
    end
    for _,title in ipairs({"Appearance","Geometry","Position","Behavior"})do assert(groups[title])end
    assert(not groups.Actions)
    RootWalk(DecorationBody(),function(w)assert(not w:GetUserData("normalAbsorbObjectActions"))end)
    for label,tab in pairs({Texture="appearance",Alpha="appearance",Width="geometry",Height="geometry",
        ["Anchor To Element"]="geometry",["Anchor From"]="geometry",["Anchor To"]="geometry",
        ["X Offset"]="geometry",["Y Offset"]="geometry",Enabled="behavior",Condition="behavior"})do
        local kind=(label=="Enabled" and "CheckBox")or(label=="Texture" and "Button")or
            ((label:find("Anchor")or label=="Condition")and "Dropdown")or "FPCompactSlider"
        assert(membership[RootGroup(DecorationControl(label,kind))]==tab,label)
    end
    assert(#RootFind(DecorationBody(),"Delete Decoration","Button")==0)
    DecorationBody():DoLayout();window._focalPointPropertyScroll:DoLayout()
    local height=0
    for _,child in ipairs(DecorationBody().children)do if child.frame:IsShown()then height=height+child.frame:GetHeight()end end
    assert(math.abs(DecorationBody().frame:GetHeight()-height)<.01,"hidden groups consume scroll height")
    return groups
end
local function DecorationPoints(disabled)
    for _,field in ipairs({{"Anchor From","point","CENTER","Position"},
        {"Anchor To","relativePoint","CENTER","Position"},{"Condition","condition","ALWAYS","Behavior"}})do
        local control=DecorationControl(field[1],"Dropdown")
        assert(control.disabled==disabled and RootGroup(control)==field[4])
    end
end
Test("Decoration Workspace exposes unique Position points and Behavior condition in both saved modes, preserving defaults and lists",function()
    for _,expert in ipairs({false,true})do
        local db,unit,decoration=DecorationStart(expert)
        decoration.point=nil;decoration.relativePoint=nil;decoration.condition=nil;decoration.target=nil
        controller.RefreshActiveProperties();Drain();local before=h.Copy(db)
        DecorationPoints(false)
        assert(DecorationControl("Anchor From","Dropdown"):GetValue()=="CENTER")
        assert(DecorationControl("Anchor To","Dropdown"):GetValue()=="CENTER")
        assert(DecorationControl("Condition","Dropdown"):GetValue()=="ALWAYS")
        assert(DecorationControl("Anchor To Element","Dropdown"):GetValue()=="FRAME")
        local targets=DecorationControl("Anchor To Element","Dropdown").list
        assert(targets.FRAME and targets.PORTRAIT)
        local n=0;for _ in pairs(targets)do n=n+1 end;assert(n==2)
        local conditions=DecorationControl("Condition","Dropdown").list;n=0
        for _ in pairs(conditions)do n=n+1 end;assert(n==5)
        for _,value in ipairs({"ALWAYS","ELITE","RARE","RAREELITE","BOSS"})do assert(conditions[value])end
        for _,label in ipairs({"Anchor From","Anchor To"})do
            local points=DecorationControl(label,"Dropdown").list;n=0
            for _ in pairs(points)do n=n+1 end;assert(n==9 and points.CENTER and points.TOPLEFT and points.BOTTOMRIGHT)
        end
        for _,f in ipairs({{"Enabled","CheckBox"},{"Texture","Button"},{"Alpha","FPCompactSlider"},
            {"Width","FPCompactSlider"},{"Height","FPCompactSlider"},{"X Offset","FPCompactSlider"},{"Y Offset","FPCompactSlider"}})do DecorationControl(f[1],f[2])end
        local controls={CheckBox=0,Button=0,FPCompactSlider=0,Dropdown=0}
        -- Count existing property/action controls separately from the three navigation buttons.
        RootWalk(DecorationBody(),function(w)
            if controls[w.type] and not w:GetUserData("normalAbsorbPropertyTab")then controls[w.type]=controls[w.type]+1 end
        end)
        h.Equal(controls,{CheckBox=1,Button=1,FPCompactSlider=5,Dropdown=4})
        DecorationCheckTabs()
        h.Equal(db,before)
        assert(db.profile.General.ExpertMode==expert and state.Get().mode==(expert and "quick" or "expert"))
    end
end)
Test("Decoration mutations and synchronized anchors keep data local through disabled, rebuild, object and layout changes",function()
    for _,expert in ipairs({false,true})do
        local db,unit,decoration,other,Select=DecorationStart(expert)
        local expected=h.Copy(unit);local expectedDecoration
        for _,d in ipairs(expected.decorations)do if d.id==decoration.id then expectedDecoration=d end end
        local profile=h.Copy(db.profile)
        DecorationControl("Anchor From","Dropdown"):Fire("OnValueChanged","TOPLEFT");expectedDecoration.point="TOPLEFT"
        DecorationControl("Anchor To","Dropdown"):Fire("OnValueChanged","BOTTOMRIGHT");expectedDecoration.relativePoint="BOTTOMRIGHT"
        for _,target in ipairs({"PORTRAIT","FRAME"})do
            DecorationControl("Anchor To Element","Dropdown"):Fire("OnValueChanged",target);expectedDecoration.target=target
            assert(decoration.target==target)
        end
        for _,condition in ipairs({"ELITE","RARE","RAREELITE","BOSS","ALWAYS"})do
            DecorationControl("Condition","Dropdown"):Fire("OnValueChanged",condition);expectedDecoration.condition=condition
            assert(decoration.condition==condition)
        end
        DecorationControl("X Offset","FPCompactSlider"):Fire("OnValueChanged",-18.6);expectedDecoration.offsetX=-19
        DecorationControl("Y Offset","FPCompactSlider"):Fire("OnValueChanged",27.6);expectedDecoration.offsetY=28
        DecorationControl("Width","FPCompactSlider"):Fire("OnValueChanged",83.6);expectedDecoration.width=84
        DecorationControl("Height","FPCompactSlider"):Fire("OnValueChanged",51.6);expectedDecoration.height=52
        DecorationControl("Alpha","FPCompactSlider"):Fire("OnValueChanged",.28);expectedDecoration.alpha=.28
        h.Equal(unit,expected)
        local before=h.Copy(unit);local ref={kind="decoration",unit="player",decorationId=decoration.id,objectKey=decoration.id}
        assert(ns.GUI.Editor.Inspector.SetActiveCanvasDirectMoveAnchorValues("player",ref,
            {point="LEFT",relativePoint="RIGHT",offsetX=11,offsetY=-12}))
        assert(DecorationControl("Anchor From","Dropdown"):GetValue()=="LEFT")
        assert(DecorationControl("Anchor To","Dropdown"):GetValue()=="RIGHT")
        assert(DecorationControl("X Offset","FPCompactSlider"):GetValue()==11)
        h.Equal(unit,before)
        controller.RefreshActiveProperties();Drain()
        DecorationControl("Enabled","CheckBox"):Fire("OnValueChanged",false);Drain();expectedDecoration.enabled=false
        DecorationPoints(true)
        for _,f in ipairs({{"Width","FPCompactSlider"},{"Height","FPCompactSlider"},{"X Offset","FPCompactSlider"},
            {"Y Offset","FPCompactSlider"},{"Alpha","FPCompactSlider"},{"Anchor To Element","Dropdown"},{"Texture","Button"}})do
            assert(DecorationControl(f[1],f[2]).disabled)
        end
        DecorationControl("Enabled","CheckBox"):Fire("OnValueChanged",true);Drain();expectedDecoration.enabled=true
        for _=1,3 do
            Select(other.id);DecorationPoints(false)
            Select(decoration.id);controller.RefreshActiveProperties();Drain();DecorationPoints(false)
            assert(DecorationControl("Anchor From","Dropdown"):GetValue()=="TOPLEFT")
            assert(DecorationControl("Anchor To","Dropdown"):GetValue()=="BOTTOMRIGHT")
        end
        window.closebutton:GetScript("OnClick")(window.closebutton);Drain();window=Build();Drain();DecorationPoints(false)
        h.Equal(unit,expected);h.Equal(db.profile,profile)
        local ok,id=ns.LayoutMutations.CopyLayout("layout:existing",nil,{activate=false});assert(ok)
        assert(ns:ActivateLayout(id));controller.BuildInspector(nil,{GetEditorState=state.Get});Drain();DecorationPoints(false)
        local active=ns.UnitFrameUtils.GetUnitDB("player");assert(active~=unit)
        DecorationControl("Condition","Dropdown"):Fire("OnValueChanged","BOSS")
        local updated;for _,d in ipairs(active.decorations)do if d.id==decoration.id then updated=d end end
        assert(updated and updated.condition=="BOSS" and decoration.condition=="ALWAYS")
    end
end)
Test("Decoration Legacy scoped and unscoped builds keep Quick/Expert filters",function()
    for _,expert in ipairs({false,true})do
        local db=DecorationStart(expert)
        for _,propertiesOnly in ipairs({false,true})do
            state.SetSectionCollapsed("decoration",false)
            local before=h.Copy(db);local host=h.ui.ace:Create("SimpleGroup")
            local builder=propertiesOnly and ns.GUI.Editor.Inspector.BuildProperties or ns.GUI.Editor.Inspector.Build
            builder(host,state.Get(),{getUnitConfig=ns.UnitFrameUtils.GetUnitDB})
            local body=assert(RootSection(host,"decoration"))
            RootWalk(body,function(w)assert(not w:GetUserData("normalAbsorbPropertyTab"),"Legacy gained Workspace tabs")end)
            RootControl("Enabled","CheckBox",body);RootControl("Anchor To Element","Dropdown",body)
            assert(RootGroup(RootControl("Enabled","CheckBox",body))=="Appearance")
            RootControl("Delete Decoration","Button",body)
            for _,label in ipairs({"Anchor From","Anchor To","Condition"})do
                local actual=#RootFind(body,label,"Dropdown")
                local expected=expert and 1 or 0
                assert(actual==expected,string.format("%s: expected %d Dropdowns, got %d; mode=%s",label,expected,actual,expert and "Expert" or "Quick"))
            end
            h.Equal(db,before);h.ui.ace:Release(host)
        end
    end
end)
Test("Decoration texture Apply/no-Apply and Tree Delete/Cancel retain their existing flows",function()
    local forms=ns.GUI.Helpers.FormWidgets;local previous=forms.CreateCompactConfirmation
    local dialog,options
    forms.CreateCompactConfirmation=function(o)options=o;dialog=previous(o);return dialog end
    local previousMedia=ns.GUI.Editor.MediaLibrary;local media
    ns.GUI.Editor.MediaLibrary={Open=function(o)media=o end}
    for _,expert in ipairs({false,true})do for _,tab in ipairs({"appearance","geometry","behavior"})do
        local db,unit,decoration,other=DecorationStart(expert)
        decoration.texture=nil;controller.RefreshActiveProperties();Drain()
        DecorationClickTab("appearance")
        local before=h.Copy(db)
        DecorationControl("Texture","Button"):Fire("OnClick");assert(media);h.Equal(db,before)
        media.onApply("fp:decoration:shadow1");Drain()
        assert(decoration.texture=="fp:decoration:shadow1")
        DecorationClickTab(tab);DecorationCheckTabs()
        window._focalPointComponentsButton:Fire("OnClick");Drain()
        local function Trash()
            for i=1,Tree().control.count do
                local row=Tree().control.rows[i]
                if row.item.node.inspectorTarget.decorationId==decoration.id then
                    row.remove:Run("OnMouseDown","LeftButton");return
                end
            end
            error("missing Decoration Tree row: "..decoration.id)
        end
        Trash();assert(dialog and options)
        before=h.Copy(db);options.cancel.onClick(dialog);Drain();h.Equal(db,before)
        Trash();options.primary.onClick(dialog);Drain()
        local found=false;for _,d in ipairs(unit.decorations)do assert(d.id~=decoration.id);if d.id==other.id then found=true end end
        assert(found and selection.GetSelectedObject().kind=="unit")
    end end
    forms.CreateCompactConfirmation=previous;ns.GUI.Editor.MediaLibrary=previousMedia
end)
Test("Decoration tab cycles retain framed owners, controls, release bindings and data without rebuilding",function()
    for _,expert in ipairs({false,true})do
        local db=DecorationStart(expert)
        local body=DecorationBody();local groups=DecorationCheckTabs();local release=groups.Position.events.OnRelease
        local width=DecorationControl("Width","FPCompactSlider");local before=h.Copy(db);local children=#body.children
        for _=1,20 do for _,tab in ipairs({"geometry","behavior","appearance"})do
            window._focalPointPropertyScroll:SetScroll(400);DecorationClickTab(tab)
            local current=DecorationCheckTabs()
            assert(DecorationBody()==body and #body.children==children and DecorationControl("Width","FPCompactSlider")==width)
            for title,group in pairs(groups)do assert(current[title]==group)end
            assert(current.Position.events.OnRelease==release)
            assert(window._focalPointPropertyScroll.status.scrollvalue==0)
        end end
        h.Equal(db,before)
    end
end)
Test("Decoration tabs survive mutations, rebuild, Back/Reopen and reject stale object, Unit and Layout callbacks",function()
    for _,expert in ipairs({false,true})do
        local db,unit,decoration,other,Select=DecorationStart(expert)
        DecorationClickTab("geometry")
        DecorationControl("Anchor From","Dropdown"):Fire("OnValueChanged","LEFT")
        DecorationControl("Anchor To","Dropdown"):Fire("OnValueChanged","RIGHT")
        DecorationClickTab("behavior")
        DecorationControl("Condition","Dropdown"):Fire("OnValueChanged","BOSS")
        DecorationControl("Enabled","CheckBox"):Fire("OnValueChanged",false);Drain()
        DecorationCheckTabs();DecorationPoints(true)
        DecorationControl("Enabled","CheckBox"):Fire("OnValueChanged",true);Drain()
        controller.RefreshActiveProperties();Drain();DecorationCheckTabs();DecorationPoints(false)
        assert(decoration.point=="LEFT" and decoration.relativePoint=="RIGHT" and decoration.condition=="BOSS")
        local oldTab=DecorationTabs().geometry;local callback=oldTab.events.OnClick
        Select(other.id);DecorationCheckTabs()
        local before=h.Copy(db);local active=state.Get().inspectorPropertyGroup
        callback(oldTab);Drain();assert(state.Get().inspectorPropertyGroup==active);h.Equal(db,before)
        Select(decoration.id);DecorationCheckTabs()
        window._focalPointSetCustomizeView("components");window._focalPointSetCustomizeView("properties")
        DecorationCheckTabs();assert(selection.GetSelectedObject().decorationId==decoration.id)
        oldTab=DecorationTabs().geometry;callback=oldTab.events.OnClick
        window.closebutton:GetScript("OnClick")(window.closebutton);Drain();window=Build();Drain();DecorationCheckTabs()
        active=state.Get().inspectorPropertyGroup;callback(oldTab);Drain();assert(state.Get().inspectorPropertyGroup==active)
        local units=ns.ActiveLayoutResolver.GetActiveRuntimeRoot().units;units.target=h.Copy(unit)
        oldTab=DecorationTabs().geometry;callback=oldTab.events.OnClick
        assert(selection.SelectObject({kind="decoration",unit="target",decorationId=decoration.id}));Drain();DecorationCheckTabs()
        active=state.Get().inspectorPropertyGroup;before=h.Copy(db);callback(oldTab);Drain()
        assert(state.Get().inspectorPropertyGroup==active);h.Equal(db,before)
        oldTab=DecorationTabs().geometry;callback=oldTab.events.OnClick
        local ok,id=ns.LayoutMutations.CopyLayout("layout:existing",nil,{activate=false});assert(ok)
        assert(ns:ActivateLayout(id));controller.BuildInspector(nil,{GetEditorState=state.Get});Drain();DecorationCheckTabs()
        active=state.Get().inspectorPropertyGroup;before=h.Copy(db);callback(oldTab);Drain()
        assert(state.Get().inspectorPropertyGroup==active);h.Equal(db,before)
        assert(db.profile.General.ExpertMode==expert)
    end
end)
assert(#h.ui.env.errors == 0, table.concat(h.ui.env.errors, "\n"))
print("Customize Workspace: " .. count .. " groups PASS")
