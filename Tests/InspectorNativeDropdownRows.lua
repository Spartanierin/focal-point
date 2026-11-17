-- Actual Workspace/builders and AceGUI Dropdown API; Blizzard Menu is a native boundary.
local function Read(path) local f=assert(io.open(path)); local s=f:read("*a"); f:close(); return s end
local source=Read("Tests/CastWidthNativeDropdown.lua")
local stop=assert(source:find("\nlocal count = 0",1,true))
local s,popup=assert(load(source:sub(1,stop).."\nreturn s,popup","@NativeRows/Fixture"))()
for _,path in ipairs({"GUI/Layouts/UnitBarDefinition.lua","GUI/Layouts/UnitTextDefinition.lua"})do
    assert(loadfile(path))("FocalPoint",s.ns)
end
local window,unit
local function Control(label) return s.Control(label,"Dropdown") end
local function Native(label) return assert(Control(label):GetUserData("nativePropertyDropdown")) end
local function Pick(label,key)
    local widget=Control(label); local native=Native(label)
    for _,entry in ipairs(native.entries)do
        -- Derive keys from the actual AceGUI item order, rather than localized labels.
        local index=0
        for _,item in widget.pullout:IterateItems()do
            index=index+1
            if item.userdata.value==key and native.entries[index]==entry then entry.callback();s.Drain();return end
        end
    end
    error("missing option: "..tostring(key))
end
local count=0
local function Test(name,fn) fn(); count=count+1; print("PASS: "..name) end
Test("both new opt-ins retain the compatible dropdown when native APIs are absent",function()
    local mixin=DropdownButtonMixin;DropdownButtonMixin=nil
    window,unit=s.Start();s.Select("NormalAbsorbBar")
    for _,label in ipairs({"Size Mode","Growth Direction"})do
        local widget=Control(label);assert(not widget:GetUserData("nativePropertyDropdown"))
        assert(widget.dropdown:IsShown() and widget.button_cover:IsShown())
    end
    Control("Size Mode"):Fire("OnValueChanged","CUSTOM");s.Drain();assert(unit.normalAbsorbBarSizeMode=="CUSTOM")
    DropdownButtonMixin=mixin;s.controller.RefreshActiveProperties();s.Drain()
end)
Test("all compatible Normal Absorb rows use the shared native presentation",function()
    window,unit=s.Start();s.Select("NormalAbsorbBar")
    local n=0;s.Walk(window._focalPointPropertyScroll,function(w)
        if w:GetUserData("nativePropertyDropdown")then n=n+1 end
    end);assert(n==5)
    assert(Control("Size Mode"):GetValue()==(unit.normalAbsorbBarSizeMode or "MATCH_TARGET"))
    assert(Control("Growth Direction"):GetValue()==(unit.normalAbsorbBarGrowth or "LEFT_TO_RIGHT"))
    assert(#Native("Size Mode").entries==2 and #Native("Growth Direction").entries==2)
    assert(Control("Anchor Target"):GetUserData("nativePropertyDropdown"))
    for _,case in ipairs({{"Anchor From","normalAbsorbBarPoint"},{"Anchor To","normalAbsorbBarRelativePoint"}})do
        assert(Control(case[1]):GetValue()==(unit[case[2]] or "LEFT"))
        assert(Control(case[1]).disabled and not Native(case[1]).enabled)
    end
end)
Test("both controls use their existing mutation fields and width dependency",function()
    s.Tabs().geometry:Fire("OnClick");s.Drain();Pick("Size Mode","CUSTOM")
    assert(unit.normalAbsorbBarSizeMode=="CUSTOM" and not s.Control("Width","FPCompactSlider").disabled)
    s.Tabs().behavior:Fire("OnClick");s.Drain();Pick("Growth Direction","RIGHT_TO_LEFT")
    assert(unit.normalAbsorbBarGrowth=="RIGHT_TO_LEFT" and unit.castBarWidthMode=="MATCH_FRAME")
end)
Test("SetValue and SetList preserve owner, ordering, display and callback semantics",function()
    local widget=Control("Size Mode");local native=Native("Size Mode")
    local before=s.h.Copy(unit)
    widget:SetList({values={CUSTOM="Custom test",MATCH_TARGET="Match test"},order={"MATCH_TARGET","CUSTOM"}})
    widget:SetValue("CUSTOM")
    assert(native==Native("Size Mode") and native.defaultText=="Custom test" and native.entries[2].selected())
    assert(native.entries[1].text=="Match test" and native.entries[2].text=="Custom test")
    widget:SetList({CUSTOM="C",MATCH_TARGET="M"},{"CUSTOM","MATCH_TARGET"})
    assert(native.entries[1].text=="C" and native.entries[1].selected())
    widget:SetList({[10]="ten",[2]="two",[1]="one"});widget:SetValue(2)
    assert(native.entries[1].text=="one" and native.entries[2].text=="two" and native.entries[3].text=="ten")
    widget:SetList(nil);widget:SetValue(nil);assert(#native.entries==0 and native.defaultText=="")
    s.h.Equal(unit,before) -- Programmatic synchronization never invokes mutations.
    s.controller.RefreshActiveProperties();s.Drain()
end)
Test("Disabled blocks retained callbacks and closes only the native popup",function()
    local widget=Control("Size Mode");local native=Native("Size Mode");local old=native.entries[1].callback
    native:OpenMenu();assert(popup:IsShown() and popup.lastSetFrameStrata[1]=="TOOLTIP")
    widget:SetDisabled(true);assert(widget.disabled and not native.enabled and not popup:IsShown())
    local before=s.h.Copy(unit);old();s.h.Equal(unit,before)
    widget:SetDisabled(false);assert(not widget.disabled and native.enabled)
    native:OpenMenu();assert(popup:IsShown());native:Hide();assert(not popup:IsShown());native:Show()
end)
Test("Rebuild and object changes invalidate callbacks/setters; Healing shares the same presentation",function()
    local widget=Control("Size Mode");local native=Native("Size Mode")
    local old=native.entries[1].callback;local setValue=widget.SetValue
    s.controller.RefreshActiveProperties();s.Drain()
    local before=s.h.Copy(unit);old();setValue(widget,"MATCH_TARGET");s.h.Equal(unit,before)
    assert(Control("Size Mode"):GetValue()=="CUSTOM")
    unit.healingAbsorbBarPresent=true;unit.showHealingAbsorbBar=true;before=s.h.Copy(unit);s.Select("HealingAbsorbBar")
    assert(Control("Size Mode"):GetUserData("nativePropertyDropdown"))
    assert(Control("Growth Direction"):GetUserData("nativePropertyDropdown"))
    assert(not Control("Size Mode").dropdown:IsShown() and not Control("Size Mode").button_cover:IsShown())
    old();s.h.Equal(unit,before)
end)
Test("repeated object changes and Close/Reopen retain all three opt-ins without stale popups",function()
    for _=1,20 do
        s.Select("NormalAbsorbBar")
        local native=Native("Growth Direction");native:OpenMenu()
        s.Select("CastBar");assert(not popup:IsShown())
        assert(Control("Width Mode"):GetUserData("nativePropertyDropdown"))
        assert(not s.Control("Texture","Button"):GetUserData("nativePropertyDropdown"))
    end
    s.Select("NormalAbsorbBar");local old=Native("Size Mode").entries[1].callback
    window.closebutton:GetScript("OnClick")(window.closebutton);s.Drain();local before=s.h.Copy(unit)
    old();s.h.Equal(unit,before)
    window=s.Build();s.Drain();assert(Native("Size Mode") and Native("Growth Direction"))
end)
Test("anchorKey and initial Disabled use the unchanged Shared helper contract",function()
    -- Reuse the existing TypographyLabels local-constructor test pattern.
    local product=Read("GUI/Editor/Inspector/InspectorController.lua")
    local function Constructor(name,nextName,context)
        local a=assert(product:find("    local function "..name.."(",1,true))
        local b=assert(product:find("    local function "..nextName.."(",a+1,true))
        return assert(load(product:sub(a,b-1).."\nreturn "..name,"@Inspector/"..name,"t",setmetatable(context,{__index=_G})))()
    end
    local current=true;local scope={}
    local context={AceGUI=s.h.ui.ace,FormWidgets=s.ns.GUI.Helpers.FormWidgets,Shared=s.ns.GUI.Editor.SidebarShared,
        AddDropdown=s.ns.GUI.Editor.SidebarShared.AddDropdown,PROPERTY_LABEL_WIDTH=108,
        INSPECTOR_ROW_STRIDES={COMPACT=32},INSPECTOR_FLOW_GAP=3,activeInspectorDiagnosticHosts={},
        workspaceIsCurrent=function()return current end,ResolvePropertyScope=function()return scope end,
        ns=s.ns,selectedUnit="player",unitConfig=unit}
    context.AddPropertyRow=Constructor("AddPropertyRow","CreateTwoControlTableRow",context)
    context.BindNativePropertyDropdown=Constructor("BindNativePropertyDropdown","AddPropertyDropdownRow",context)
    local build=Constructor("AddPropertyDropdownRow","AddPropertySliderRow",context)
    local host=s.h.ui.ace:Create("SimpleGroup");local calls=0
    local widget=build(host,"Example",{native=true,list={values={a="A",b="B"},order={"b","a"}},value="a",
        anchorKey="existing_anchor_contract",onChanged=function()calls=calls+1 end},true)
    local native=assert(widget:GetUserData("nativePropertyDropdown"))
    assert(widget:GetUserData("focalPointAnchorKey")=="existing_anchor_contract" and widget.frame._focalPointAnchorKey=="existing_anchor_contract")
    assert(widget.disabled and not native.enabled and native.entries[1].text=="B")
    native.entries[1].callback();assert(calls==0)
    widget:SetDisabled(false);native.entries[1].callback();assert(calls==1 and widget:GetValue()=="b")
    current=false;native.entries[2].callback();assert(calls==1)
    s.h.ui.ace:Release(host)
    current=true;host=s.h.ui.ace:Create("SimpleGroup")
    local excluded=build(host,"Excluded",{native=false,list={a="A"},value="a"})
    assert(not excluded:GetUserData("nativePropertyDropdown") and excluded.dropdown:IsShown())
    context.workspaceIsCurrent=nil
    local legacy=build(host,"Legacy",{list={a="A"},value="a"})
    assert(not legacy:GetUserData("nativePropertyDropdown") and legacy.dropdown:IsShown())
    s.h.ui.ace:Release(host)
end)
Test("Workspace rows reserve measured multiline-label height and retain native controls",function()
    -- Reuse the same production local-constructor boundary as the metadata test.
    local product=Read("GUI/Editor/Inspector/InspectorController.lua")
    local a=assert(product:find("    local function AddPropertyRow(",1,true))
    local b=assert(product:find("    local function CreateTwoControlTableRow(",a,true))
    local forms=s.ns.GUI.Helpers.FormWidgets
    local create=forms.CreateBodyText
    local label,measure
    forms.CreateBodyText=function(...)
        label=create(...);measure=label.label.GetStringHeight
        label.label.GetStringHeight=function()return 54 end
        return label
    end
    local context={AceGUI=s.h.ui.ace,FormWidgets=forms,workspaceIsCurrent=function()return true end,
        PROPERTY_LABEL_WIDTH=108,INSPECTOR_ROW_STRIDES={COMPACT=32},INSPECTOR_FLOW_GAP=3,activeInspectorDiagnosticHosts={}}
    local build=assert(load(product:sub(a,b-1).."\nreturn AddPropertyRow","@Row/MeasuredLabel","t",setmetatable(context,{__index=_G})))()
    local host=s.h.ui.ace:Create("SimpleGroup")
    local row,value=build(host,"A long label reported by the native text boundary",function()end,{rowType="COMPACT"})
    forms.CreateBodyText=create
    assert(row.frame:GetHeight()>=54 and value.frame:GetHeight()==29)
    assert(row:GetUserData("table").alignV=="center")
    assert(row:GetUserData("table").columns[1].width==160)
    label.label.GetStringHeight=measure
    for _,workspace in ipairs({true,false})do
        context.workspaceIsCurrent=workspace and function()return true end or nil
        for _,override in ipairs({false,96})do
            local expected=override or (workspace and 160 or 108)
            local current,control=build(host,"Row width contract",function()end,
                {rowType="COMPACT",labelWidth=override or nil})
            assert(current:GetUserData("table").columns[1].width==expected)
            assert(current:GetUserData("table").spaceH==8)
            for _,width in ipairs({548,568})do -- 600-wide Workspace, with/without scrollbar.
                current:SetWidth(width);current:DoLayout()
                -- The native double records anchors, but does not resolve opposing points into GetWidth().
                local left,right=control.frame.points.LEFT,control.frame.points.RIGHT
                assert(left.relative==current.content and right.relative==current.content)
                assert(left.x==expected+8 and right.x-left.x==width-expected-8,
                    "control column lost the available remainder")
            end
        end
    end
    s.h.ui.ace:Release(host)
end)
Test("anchor dropdowns use independent full rows and the standard control column",function()
    window,unit=s.Start("expert");unit.normalAbsorbBarSizeMode="MATCH_TARGET"
    s.Select("NormalAbsorbBar")
    local a=Control(s.ns.L.OPTION_ANCHOR_FROM or "Anchor From")
    local b=Control(s.ns.L.OPTION_ANCHOR_TO or "Anchor To")
    assert(a.parent.parent~=b.parent.parent)
    for _,widget in ipairs({a,b})do
        assert(widget.parent.parent:GetUserData("table").columns[1].width==160)
        assert(widget.disabled and widget:GetUserData("nativePropertyDropdown") and not widget.label:IsShown())
    end
    Pick("Size Mode","CUSTOM")
    a=Control(s.ns.L.OPTION_ANCHOR_FROM or "Anchor From")
    b=Control(s.ns.L.OPTION_ANCHOR_TO or "Anchor To")
    assert(not a.disabled and not b.disabled)
    Pick(s.ns.L.OPTION_ANCHOR_FROM or "Anchor From","RIGHT")
    assert(unit.normalAbsorbBarPoint=="RIGHT")
end)
Test("segmented source rebuild and in-place synchronization retain native binding guards",function()
    window,unit=s.Start("expert")
    local mutations=s.ns.LayoutMutations.SegmentedBars
    local added=mutations.Add(assert(mutations.CaptureContext("player")),
        {enabled=true,dataSource={id="runes",scope="player"},anchorTo="Frame"})
    assert(added.ok,added.errorCode)
    assert(s.selection.SelectObject({kind="segmentedBar",unit="player",objectKey=added.id}));s.Drain()
    local function Field(key)
        local found;s.Walk(window._focalPointPropertyScroll,function(w)
            if w:GetUserData("focalPointAnchorKey")=="segmentedBar_"..key then found=w end
        end);return assert(found,key)
    end
    local function Record()
        for _,r in ipairs(unit.segmentedBars)do if r.id==added.id then return r end end
        error("selected record missing")
    end
    local source=Field("dataSource");local native=assert(source:GetUserData("nativePropertyDropdown"))
    local old=native.entries[1].callback
    local i=0;for _,item in source.pullout:IterateItems()do
        i=i+1;if item.userdata.value=="holyPower"then native.entries[i].callback();break end
    end
    s.Drain();assert(Record().dataSource.id=="holyPower")
    local before=s.h.Copy(Record());old();s.Drain();s.h.Equal(Record(),before)
    local growth=Field("growth");native=assert(growth:GetUserData("nativePropertyDropdown"))
    i=0;for _,item in growth.pullout:IterateItems()do
        i=i+1;if item.userdata.value=="RIGHT_TO_LEFT"then native.entries[i].callback();break end
    end
    s.Drain();assert(Record().growth=="RIGHT_TO_LEFT")
    assert(Field("growth"):GetValue()=="RIGHT_TO_LEFT")
    -- Media controls keep their existing picker, and the native opt-out is preserved.
    assert(not Field("texture"):GetUserData("nativePropertyDropdown"))
    local media=s.ns.GUI.Editor.MediaLibrary;s.ns.GUI.Editor.MediaLibrary=nil
    s.controller.RefreshActiveProperties();s.Drain()
    local fallback=Field("texture")
    assert(fallback.type=="Dropdown" and not fallback:GetUserData("nativePropertyDropdown") and fallback.dropdown:IsShown())
    assert(Field("dataSource"):GetUserData("nativePropertyDropdown"))
    s.ns.GUI.Editor.MediaLibrary=media;s.controller.RefreshActiveProperties();s.Drain()
end)
Test("Power mode/anchor menus preserve Disabled and reject retained native actions after layout change",function()
    window,unit=s.Start();unit.powerBarPresent=true;unit.showPowerBar=true
    s.controller.RefreshCompositionTree();s.Select("PowerBar")
    assert(Native("Size Mode").enabled)
    for _,label in ipairs({"Anchor Target","Anchor From","Anchor To"})do assert(not Native(label).enabled,label)end
    Pick("Size Mode","CUSTOM")
    for _,label in ipairs({"Anchor Target","Anchor From","Anchor To"})do assert(Native(label).enabled,label)end
    Pick("Anchor Target","HealthBar");Pick("Anchor From","TOPLEFT");Pick("Anchor To","BOTTOMRIGHT")
    assert(unit.powerBarAnchorTo=="HealthBar" and unit.powerBarPoint=="TOPLEFT" and unit.powerBarRelativePoint=="BOTTOMRIGHT")
    local old=Native("Size Mode").entries[1].callback
    s.Control("Show","CheckBox"):Fire("OnValueChanged",false);s.Drain()
    for _,label in ipairs({"Size Mode","Anchor Target","Anchor From","Anchor To"})do assert(not Native(label).enabled,label)end
    local before=s.h.Copy(unit);old();s.h.Equal(unit,before)
    s.Control("Show","CheckBox"):Fire("OnValueChanged",true);s.Drain()
    old=Native("Size Mode").entries[1].callback
    local ok,id=s.ns.LayoutMutations.CopyLayout("layout:existing",nil,{activate=false});assert(ok)
    assert(s.ns:ActivateLayout(id));s.controller.BuildInspector(nil,{GetEditorState=s.state.Get});s.Drain()
    local db=s.ns.db;before=s.h.Copy(db);old();s.h.Equal(db,before)
    assert(Native("Size Mode").enabled)
end)
Test("Workspace value fonts preserve faces, colors, controls and pooling; Legacy stays unchanged",function()
    local product=Read("GUI/Editor/Inspector/InspectorController.lua")
    local first=assert(product:find("    local function AddPropertyRow(",1,true))
    local last=assert(product:find("    local function CreateTwoControlTableRow(",first,true))
    local context={AceGUI=s.h.ui.ace,FormWidgets=s.ns.GUI.Helpers.FormWidgets,PROPERTY_LABEL_WIDTH=108,
        INSPECTOR_ROW_STRIDES={COMPACT=32},INSPECTOR_FLOW_GAP=3,activeInspectorDiagnosticHosts={},
        workspaceIsCurrent=function()return true end}
    local build=assert(load(product:sub(first,last-1).."\nreturn AddPropertyRow","@Inspector/WorkspaceFonts","t",
        setmetatable(context,{__index=_G})))()
    local host=s.h.ui.ace:Create("SimpleGroup")
    local saved,controls={},{}
    local originalCheckboxBounds
    local originalColorBounds
    local originalColorTexture
    local function Remember(slot,size)
        saved[#saved+1]={slot=slot,font={slot:GetFont()},color={slot:GetTextColor()},size=size or 13}
    end
    local row=build(host,"Long localized property label",function(value)
        local check=s.ns.GUI.Editor.SidebarShared.AddCheckBox(value,"On",true,function()end)
        originalCheckboxBounds={check.checkbg:GetWidth(),check.checkbg:GetHeight(),check.frame:GetHeight()}
        Remember(check.text);controls.check=check
        local color=s.ns.GUI.Editor.SidebarShared.AddColorPicker(value,"",{.2,.3,.4,.5},true,function()end)
        originalColorTexture=color.colorSwatch:GetTexture()
        originalColorBounds={}
        for _,region in ipairs({color.colorSwatch,color.colorSwatch.background,color.colorSwatch.checkers})do
            originalColorBounds[#originalColorBounds+1]={region,region:GetWidth(),region:GetHeight()}
        end
        controls.color=color
        local input=s.h.ui.ace:Create("EditBox");input:SetText("123")
        -- One native InputBox texture boundary; the real template supplies its border regions.
        local edge=input.editbox:CreateTexture(nil,"BACKGROUND");edge.kind="Texture"
        s.ns.GUI.Helpers.FormWidgets.StyleEditBox(input,"editor_inset","value")
        controls.input=input;controls.inputEdge=edge;controls.inputHeight=input.editbox:GetHeight()
        controls.inputStyle=input.editbox._fpFieldStyle
        controls.inputFocus=input.editbox:GetScript("OnEditFocusGained")
        Remember(input.editbox,14);value:AddChild(input)
        local slider=s.h.ui.ace:Create("FPCompactSlider");slider:SetSliderValues(-10,100,1)
        slider:SetValue(42);slider:SetInspectorPresentation();value:AddChild(slider);slider:SetNativeInspectorPresentation()
        for _,slot in ipairs({slider.editbox,slider.lowtext,slider.hightext})do Remember(slot)end
        controls.slider=slider
        local dropdown=s.ns.GUI.Editor.SidebarShared.AddDropdown(value,"",{a="A",b="B"},"a",function()end)
        assert(s.ns.GUI.Helpers.FormWidgets.BindNativeDropdown(dropdown,{}))
        local native=dropdown:GetUserData("nativePropertyDropdown")
        -- Model the FontString supplied by the real WowStyle1DropdownTemplate.
        native.Text=native.Text or native:CreateFontString(nil,"OVERLAY","GameFontHighlight")
        Remember(dropdown.text);Remember(native.Text);controls.dropdown=dropdown
    end,{rowType="COMPACT"})
    assert(select(2,row.children[1].label:GetFont())==14)
    local color=controls.color
    assert(color.colorSwatch:GetWidth()==24 and color.colorSwatch:GetHeight()==24)
    assert(color.colorSwatch.background:GetWidth()==21 and color.colorSwatch.background:GetHeight()==21)
    assert(color.colorSwatch.checkers:GetWidth()==19 and color.colorSwatch.checkers:GetHeight()==19)
    assert(color.frame:GetHeight()>=color.colorSwatch:GetHeight())
    assert(color.r==.2 and color.g==.3 and color.b==.4 and color.a==.5 and color.HasAlpha)
    assert(color.colorSwatch:GetTexture()=="Interface\\Buttons\\WHITE8X8")
    local border=assert(color.frame._fpColorSwatchBorder)
    local edges=0
    for side,edge in pairs(border)do
        edges=edges+1;assert(edge:IsShown())
        local layer,sublevel=edge:GetDrawLayer();assert(layer=="OVERLAY" and sublevel==1)
        if side=="TOP" or side=="BOTTOM"then
            assert(edge:GetHeight()==1 and edge.points[side.."LEFT"].relative==color.colorSwatch)
        else
            assert(edge:GetWidth()==1 and edge.points["TOP"..side].y==-1 and edge.points["BOTTOM"..side].y==1)
        end
    end
    assert(edges==4)
    for _,rgba in ipairs({{1,1,1,1},{0,0,0,1},{1,0,0,1},{1,1,0,1},{0,1,0,1},{.3,.5,.7,.5}})do
        color:SetColor(table.unpack(rgba))
        s.h.Equal(color.colorSwatch.lastSetVertexColor,rgba)
        for _,edge in pairs(border)do
            s.h.Equal(edge.lastSetColorTexture,s.ns.GUI.Helpers.FormWidgets.ResolveFieldStyle("neutral").border)
        end
    end
    local click=color.frame:GetScript("OnClick")
    color:SetDisabled(true);color:SetDisabled(false)
    color:SetColor(.7,.6,.5,.4)
    assert(color.frame:GetScript("OnClick")==click and color.a==.4)
    assert(color.colorSwatch:GetWidth()==24 and color.colorSwatch.checkers:GetWidth()==19)
    for _,entry in ipairs(saved)do
        local font,size,flags=entry.slot:GetFont()
        assert(font==entry.font[1] and size==entry.size and flags==entry.font[3])
        s.h.Equal({entry.slot:GetTextColor()},entry.color)
    end
    assert(controls.check.checkbg:GetWidth()==32 and controls.check.checkbg:GetHeight()==32)
    assert(controls.check.frame:GetHeight()>=32 and row.frame:GetHeight()>=32)
    assert(row.children[2].frame:GetHeight()>=32,"value host clips the native-sized checkbox")
    assert(controls.check.check.lastSetAllPoints[1]==controls.check.checkbg)
    assert(controls.check.highlight.lastSetAllPoints[1]==controls.check.checkbg)
    local check=controls.check
    local down,up=check.frame:GetScript("OnMouseDown"),check.frame:GetScript("OnMouseUp")
    check:SetValue(false);assert(not check.check:IsShown())
    down(check.frame);up(check.frame);assert(check:GetValue() and check.check:IsShown())
    assert(check.text.points.LEFT.relative==check.checkbg and check.text.points.LEFT.x==0)
    check:SetDisabled(true);down(check.frame);up(check.frame);assert(check:GetValue())
    assert(check.check.lastSetDesaturated[1]==true)
    check:SetDisabled(false);down(check.frame);up(check.frame);assert(not check:GetValue())
    assert(check.frame:GetScript("OnMouseDown")==down and check.frame:GetScript("OnMouseUp")==up)
    controls.check:SetDisabled(true);controls.check:SetDisabled(false)
    controls.check:SetLabel("Off");assert(select(2,controls.check.text:GetFont())==13)
    controls.slider:SetDisabled(true);controls.slider:SetDisabled(false)
    controls.slider:SetWidth(97);assert(controls.slider:GetValue()==42)
    assert(select(2,controls.slider.editbox:GetFont())==13)
    controls.dropdown:SetValue("b");assert(controls.dropdown:GetValue()=="b")
    local input=controls.input;local fill=assert(input.frame._fpInspectorInputFill)
    local neutral=s.ns.GUI.Helpers.FormWidgets.ResolveFieldStyle("neutral")
    assert(fill:IsShown() and fill.lastSetAllPoints[1]==input.editbox)
    s.h.Equal(fill.lastSetColorTexture,neutral.background)
    assert(input.editbox._fpFieldStyle==neutral and input.editbox:GetHeight()>=20)
    assert(input.editbox:GetScript("OnEditFocusGained")==controls.inputFocus,"existing focus handler was replaced")
    input.editbox:Run("OnEditFocusGained")
    s.h.Equal(controls.inputEdge.lastSetVertexColor,neutral.borderFocus)
    input.editbox:Run("OnEditFocusLost")
    s.h.Equal(controls.inputEdge.lastSetVertexColor,neutral.border)
    for _,text in ipairs({"0","3","4","-17","Langer Text / long text"})do
        input:SetText(text);assert(input:GetText()==text and select(2,input.editbox:GetFont())==14)
    end
    input:SetDisabled(true);assert(input.disabled and fill:IsShown())
    s.h.Equal({input.editbox:GetTextColor()},{.5,.5,.5})
    input:SetDisabled(false);assert(not input.disabled and select(2,input.editbox:GetFont())==14)
    s.h.ui.ace:Release(host)
    assert(not fill:IsShown() and input.editbox:GetHeight()==controls.inputHeight)
    assert(input.editbox._fpFieldStyle==controls.inputStyle)
    s.h.Equal({check.checkbg:GetWidth(),check.checkbg:GetHeight(),check.frame:GetHeight()},originalCheckboxBounds)
    assert(color.colorSwatch:GetTexture()==originalColorTexture)
    for _,edge in pairs(border)do assert(not edge:IsShown())end
    for _,entry in ipairs(originalColorBounds)do
        assert(entry[1]:GetWidth()==entry[2] and entry[1]:GetHeight()==entry[3])
    end
    for _,entry in ipairs(saved)do s.h.Equal({entry.slot:GetFont()},entry.font)end
    context.workspaceIsCurrent=nil
    host=s.h.ui.ace:Create("SimpleGroup")
    local row=build(host,"Legacy",function(value)
        local input=s.h.ui.ace:Create("EditBox");Remember(input.editbox);value:AddChild(input)
        assert(not input.frame._fpInspectorInputFill or not input.frame._fpInspectorInputFill:IsShown())
        local legacy=s.ns.GUI.Editor.SidebarShared.AddCheckBox(value,"Legacy",false,function()end)
        assert(legacy.checkbg:GetWidth()==24 and legacy.checkbg:GetHeight()==24)
        local color=s.ns.GUI.Editor.SidebarShared.AddColorPicker(value,"Legacy",{1,0,0,.5},true,function()end)
        assert(color.colorSwatch:GetWidth()==19 and color.colorSwatch.background:GetWidth()==16
            and color.colorSwatch.checkers:GetWidth()==14)
        assert(color.colorSwatch:GetTexture()==130939,"flat Workspace swatch leaked into Legacy")
        for _,edge in pairs(color.frame._fpColorSwatchBorder or {})do assert(not edge:IsShown())end
    end,{rowType="COMPACT"})
    assert(select(2,row.children[1].label:GetFont())~=14)
    local entry=saved[#saved];s.h.Equal({entry.slot:GetFont()},entry.font)
    s.h.ui.ace:Release(host)
end)
Test("Workspace media triggers use native artwork and one click opens the existing picker without mutation",function()
    local boundary=s.h.ui.native
    local originals={}
    for _,method in ipairs({"GetNormalTexture","GetPushedTexture","GetHighlightTexture","GetDisabledTexture"})do
        originals[method]=boundary[method]
        boundary[method]=function(self)
            local key="mediaTest"..method
            if not self[key]then self[key]=self:CreateTexture(nil,"ARTWORK")end
            return self[key]
        end
    end
    window,unit=s.Start()
    unit.powerBarPresent=true;unit.showPowerBar=true
    local library=s.ns.GUI.Editor.MediaLibrary
    local open=library.Open;local options,calls
    library.Open=function(value)options=value;calls=(calls or 0)+1;return open(value)end
    for _,object in ipairs({"HealthBar","PowerBar","CastBar"})do
        s.controller.RefreshCompositionTree();s.Select(object)
        local button=s.Control("Texture","Button")
        local art=assert(button.frame._fpMediaPickerArt)
        assert(art.background.atlas=="common-dropdown-textholder" and art.background:IsShown())
        assert(art.arrow.atlas=="common-dropdown-a-button" and art.arrow:IsShown())
        assert(button.text.lastSetTextColor[1]>.9 and button.text.lastSetTextColor[2]>.9)
        assert(select(2,button.text:GetFont())==13)
        assert(art.background.points.TOPLEFT.relative==button.frame and art.background.points.TOPLEFT.x==0)
        assert(art.background.points.BOTTOMRIGHT.relative==button.frame and art.background.points.BOTTOMRIGHT.x==0)
        assert(art.arrow.points.RIGHT.relative==button.frame and art.arrow.points.RIGHT.x==-7)
        assert(button.text.points.TOPLEFT.x==16 and button.text.points.BOTTOMRIGHT.x==-8-art.arrow:GetWidth())
        if object=="PowerBar"then
            local reference=Control("Size Mode")
            local native=Native("Size Mode")
            assert(native.points.LEFT.relative==reference.button_cover and native.points.RIGHT.relative==reference.button_cover)
            -- Same native atlas: host insets cancel its -8/+8 horizontal expansion.
            assert(art.background.points.TOPLEFT.x==native.points.LEFT.x-8)
            assert(art.background.points.BOTTOMRIGHT.x==native.points.RIGHT.x+8)
            assert(art.arrow.points.RIGHT.x==native.points.RIGHT.x+1)
            assert(button.text.points.TOPLEFT.x==native.points.LEFT.x+8)
        end
        assert(button.text:GetText():sub(-2)~=" v" and not button:GetUserData("nativePropertyDropdown"))
        -- Check all four native regions even when the boundary previously had no getters.
        for _,method in ipairs({"GetNormalTexture","GetPushedTexture","GetHighlightTexture","GetDisabledTexture"})do
            assert(button.frame[method](button.frame):GetAlpha()==0)
        end
        local before=s.h.Copy(unit);local previous=calls or 0
        button.frame:GetScript("OnClick")(button.frame)
        assert(calls==previous+1 and options.mediaType=="statusbar")
        s.h.Equal(unit,before) -- Opening/previewing is not Apply.
        button:Fire("OnEnter");assert(art.arrow.atlas=="common-dropdown-a-button-hover")
        button:Fire("OnLeave");assert(art.arrow.atlas=="common-dropdown-a-button")
        local height=button.frame:GetHeight()
        button:SetDisabled(true);button:Fire("OnClick")
        assert(calls==previous+1 and art.arrow.atlas=="common-dropdown-a-button-disabled")
        button:SetDisabled(false);assert(button.frame:GetHeight()==height)
        button._fpSetPropertyValueText("Langer Medienname / long media name")
        assert(button.text:GetText()=="Langer Medienname / long media name")
        assert(button.frame.__fpInspectorTooltip)
    end
    options.onApply("fp:statusbar:gradient");s.Drain()
    assert(unit.castBarTexture=="fp:statusbar:gradient")
    unit.castBarTexture="fp:statusbar:missing-media-control-test"
    s.controller.RefreshActiveProperties();s.Drain()
    local button=s.Control("Texture","Button")
    assert(button.text:GetText()~="" and unit.castBarTexture=="fp:statusbar:missing-media-control-test")
    button.frame:GetScript("OnClick")(button.frame)
    assert(options.currentValue==unit.castBarTexture)
    local art=button.frame._fpMediaPickerArt
    local stale=button.events.OnClick;local previous=calls
    s.Select("HealthBar")
    assert(not art.background:IsShown() or s.Control("Texture","Button")==button)
    stale();assert(calls==previous,"released trigger reopened the picker")
    library.Open=open
    s.controller.ReleaseInspector()
    assert(not window.frame:IsShown())
    s.h.ui.ace:Release(window)
    assert(not art.background:IsShown() and not art.arrow:IsShown())
    for _,method in ipairs({"GetNormalTexture","GetPushedTexture","GetHighlightTexture","GetDisabledTexture"})do
        assert(button.frame[method](button.frame):GetAlpha()==1)
        boundary[method]=originals[method]
    end
    local other=s.h.ui.ace:Create("Button")
    local decoration=other.frame._fpMediaPickerArt
    if decoration then assert(not decoration.background:IsShown() and not decoration.arrow:IsShown())end
    assert(not other._fpSetPropertyValueText)
    s.h.ui.ace:Release(other)
end)
assert(#s.h.ui.env.errors==0,table.concat(s.h.ui.env.errors,"\n"))
print("Inspector Native Dropdown Rows: "..count.." groups PASS")
