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
    end);assert(n==3)
    assert(Control("Size Mode"):GetValue()==(unit.normalAbsorbBarSizeMode or "MATCH_TARGET"))
    assert(Control("Growth Direction"):GetValue()==(unit.normalAbsorbBarGrowth or "LEFT_TO_RIGHT"))
    assert(#Native("Size Mode").entries==2 and #Native("Growth Direction").entries==2)
    assert(Control("Anchor Target"):GetUserData("nativePropertyDropdown"))
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
assert(#s.h.ui.env.errors==0,table.concat(s.h.ui.env.errors,"\n"))
print("Inspector Native Dropdown Rows: "..count.." groups PASS")
