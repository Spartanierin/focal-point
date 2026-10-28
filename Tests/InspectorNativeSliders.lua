-- Real owner, normalization, events, Workspace and mutations; XML is the client boundary.
local function Read(path)local f=assert(io.open(path));local s=f:read("*a");f:close();return s end
local source=Read("Tests/InspectorNativeDropdownRows.lua")
local stop=assert(source:find("\nlocal count=0",1,true))
local s=assert(load(source:sub(1,stop).."\nreturn s","@NativeSlider/Workspace"))()
local ace=s.h.ui.ace
local create=CreateFrame
local allocated,missing=0,false
MinimalSliderMixin={}
function CreateFrame(kind,name,parent,template)
    if template~="MinimalSliderTemplate"then return create(kind,name,parent,template)end
    if missing then error("native template absent")end
    allocated=allocated+1
    local frame=create(kind,name,parent)
    frame.template=template;frame:SetThumbTexture("native-template-thumb")
    return frame
end
local function Near(a,b)assert(math.abs(a-b)<1e-9,tostring(a).." ~= "..tostring(b))end
local count=0
local function Test(name,fn)fn();count=count+1;print("PASS: "..name)end
Test("native template retains a separate input before min/track/max with one owner",function()
    local w=ace:Create("FPCompactSlider");w:SetWidth(260);w:SetSliderValues(4,30,1);w:SetValue(15)
    w:SetNativeInspectorPresentation()
    assert(w.slider~=w._fpCompactSlider and w.slider.template=="MinimalSliderTemplate")
    assert(w.editbox.points.LEFT.relative==w.frame and w.editbox:GetWidth()==52)
    assert(w.lowtext.points.LEFT.relative==w.editbox and w.slider.points.LEFT.relative==w.lowtext)
    assert(w.slider.points.RIGHT.relative==w.hightext and w.hightext.points.RIGHT.relative==w.frame)
    assert(w.slider:GetHeight()==19 and w.editbox:GetText()=="15")
    assert(w.lowtext:GetText()=="4" and w.hightext:GetText()=="30")
    assert(not w._fpCompactSlider:IsShown());ace:Release(w)
end)
Test("integer, negative, coarse-step, decimal and alpha use unchanged canonical commits",function()
    for _,case in ipairs({{4,30,1,15,20.4,20},{-500,500,1,0,-81.6,-82},
        {-500,500,5,0,84,85},{0,1,.01,.1,.337,.34},{.1,1,.01,.2,.255,.26}})do
        local w=ace:Create("FPCompactSlider");w:SetWidth(260)
        w:SetSliderValues(case[1],case[2],case[3]);w:SetValue(case[4]);w:SetNativeInspectorPresentation()
        local calls=0;w:SetCallback("OnValueChanged",function()calls=calls+1 end)
        w.editbox:SetText(tostring(case[5]));w.editbox:Run("OnEnterPressed")
        Near(w:GetValue(),case[6]);Near(w.slider:GetValue(),case[6]);assert(calls==1)
        w.editbox:Run("OnEnterPressed");assert(calls==1)
        w.editbox:SetText("99999");w.editbox:Run("OnEnterPressed");Near(w:GetValue(),case[2]);assert(calls==2)
        w.editbox:SetText("-99999");w.editbox:Run("OnEnterPressed");Near(w:GetValue(),case[1]);assert(calls==3)
        w.slider:SetValue(case[4]);Near(w:GetValue(),case[4]);assert(calls==4)
        w:SetValue(case[6]);assert(calls==4)
        w.editbox:SetText("invalid");w.editbox:Run("OnEnterPressed");Near(w:GetValue(),case[6]);assert(calls==4)
        w:SetDisabled(true);w.slider:SetValue(case[4]);w.editbox:SetText(tostring(case[4]));w.editbox:Run("OnEnterPressed")
        Near(w:GetValue(),case[6]);assert(calls==4)
        ace:Release(w)
    end
end)
Test("narrow widths and missing native API/template fall back; reuse clears native state",function()
    local w=ace:Create("FPCompactSlider");w:SetWidth(260);w:SetNativeInspectorPresentation()
    local native=w.slider;local n=allocated
    w.frame:SetWidth(90);w.frame:Run("OnSizeChanged");assert(w.slider==w._fpCompactSlider and not native:IsShown())
    w.frame:SetWidth(260);w.frame:Run("OnSizeChanged");assert(w.slider==native and allocated==n)
    ace:Release(w);assert(not native:IsShown() and w.slider==w._fpCompactSlider and not w._fpNativeRequested)
    for _=1,20 do
        local current=ace:Create("FPCompactSlider");assert(not current._fpNativeRequested and current.slider==current._fpCompactSlider)
        current:SetWidth(260);current:SetNativeInspectorPresentation();ace:Release(current)
    end
    assert(allocated==n)
    local held=ace:Create("FPCompactSlider") -- Reserve the already native-capable pooled owner.
    missing=true;local absent=ace:Create("FPCompactSlider");absent:SetNativeInspectorPresentation()
    assert(absent.slider==absent._fpCompactSlider);ace:Release(absent);missing=false
    MinimalSliderMixin=nil
    held:SetNativeInspectorPresentation(false);ace:Release(held)
    MinimalSliderMixin={}
end)
local window,unit
local function Order(expected)
    local included={};for _,name in ipairs(expected)do included[name]=true end
    local actual={};s.Walk(window._focalPointPropertyScroll,function(w)
        local c=w.children or {}
        if c[1] and c[1].type=="Label"then local name=c[1].label:GetText();if included[name]then actual[#actual+1]=name end end
    end)
    assert(table.concat(actual,"|")==table.concat(expected,"|"),table.concat(actual,"|"))
end
local function Label(key,fallback)return s.ns.L[key] or fallback end
Test("Class Power order and Quick/Expert conditions retain every existing field",function()
    window,unit=s.Start("expert");unit.classPowerBarPresent=true;unit.showClassPowerBar=true;s.Select("ClassPowerBar")
    Order({"Height","Width",Label("OPTION_CLASS_POWER_BAR_SPACING","Class Power Spacing"),
        "Anchor Target","Anchor From","Anchor To","Offset X","Offset Y",Label("OPTION_CLASS_POWER_SEGMENT_GROWTH","Segment Growth")})
    local height=s.Control("Height","FPCompactSlider")
    assert(height._fpNativeRequested);height.editbox:SetText("17");height.editbox:Run("OnEnterPressed");s.Drain()
    assert(unit.classPowerBarHeight==17)
    s.state.SetMode("quick");s.controller.BuildInspector(nil,{GetEditorState=s.state.Get});s.Drain()
    Order({"Height",Label("OPTION_CLASS_POWER_SEGMENT_GROWTH","Segment Growth")})
end)
Test("Cast and Absorb keep Height/Width and separate aligned Anchor rows across Reopen",function()
    window,unit=s.Start("expert")
    Order({"Height","Width Mode","Width"})
    s.Select("NormalAbsorbBar");Order({"Size Mode","Height","Width","Anchor Target","Anchor From","Anchor To","Offset X","Offset Y","Growth Direction"})
    local a=s.Control("Anchor From","Dropdown");local b=s.Control("Anchor To","Dropdown")
    assert(a.parent.parent~=b.parent.parent)
    assert(a.parent.parent:GetUserData("table").columns[1].width==b.parent.parent:GetUserData("table").columns[1].width)
    window.closebutton:GetScript("OnClick")(window.closebutton);s.Drain();window=s.Build();s.Drain()
    assert(s.Control("Height","FPCompactSlider")._fpNativeRequested)
end)
assert(#s.h.ui.env.errors==0,table.concat(s.h.ui.env.errors,"\n"))
print("Inspector Native Sliders: "..count.." groups PASS")
