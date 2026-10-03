-- lua54 Tests/AddObjectScroll.lua
-- Real Add Object, Compact Shell, AceGUI List/ScrollFrame and capability rules.
-- Only native anchor resolution, font metrics and product mutation endpoints
-- are doubles. No alternate implementation of the production height policy.
local f=dofile("Tests/ParchmentWindow.lua")
local ns,ace,native,Equal=f.ns,f.ace,f.native,f.Equal

-- Resolve the stretched rectangles used by the real compact/scroll owners.
local oldWidth,oldHeight=native.GetWidth,native.GetHeight
function native:GetWidth()
    local a,b=self.points.TOPLEFT,self.points.BOTTOMRIGHT
    if a and b and a.relative==b.relative then
        return math.max(0,a.relative:GetWidth()+b.x-a.x)
    end
    return oldWidth(self)
end
function native:GetHeight()
    local a,b=self.points.TOPLEFT,self.points.BOTTOMRIGHT
    if a and b and a.relative==b.relative then
        return math.max(0,a.relative:GetHeight()+a.y-b.y)
    end
    return oldHeight(self)
end
function native:GetStringHeight()
    local text=self:GetText() or ""
    if text=="" then return 1 end
    return 14*math.max(1,math.ceil(#text*6/math.max(1,self:GetWidth())))
end

f.Load("Data/Constants.lua"); f.Load("Locales/enUS.lua")
f.Load("GUI/Editor/SidebarShared.lua")
f.Load("GUI/Editor/Composition/CompositionOwnership.lua")
f.Load("GUI/Editor/Composition/CompositionPresence.lua")
local selected,configs="player",{}
ns.UnitFrameUtils={GetUnitDB=function(k) return configs[k] end}
ns.GUI.Editor.ObjectSelection={GetSelectedObject=function() return {unit=selected} end}
local presence=ns.GUI.Editor.Composition.Presence
local isPresent=presence.IsPresent
local presenceCalls,indicatorCalls={},0
presence.IsPresent=function(config,ref)
    local key=ref.kind..":"..ref.objectKey
    presenceCalls[key]=(presenceCalls[key] or 0)+1
    return isPresent(config,ref)
end
local shared=ns.GUI.Editor.SidebarShared
local indicators=shared.BuildIndicatorList
shared.BuildIndicatorList=function(unit) indicatorCalls=indicatorCalls+1; return indicators(unit) end
local open=ns.GUI.Editor.CanvasToolbar.OpenEntityAddObjectPicker
local last
local create=f.widgets.CreateCompactFormDialog
f.widgets.CreateCompactFormDialog=function(options) last=create(options); return last end
local bars={"powerBarPresent","castBarPresent","classPowerBarPresent","alternativePowerBarPresent","normalAbsorbBarPresent","healingAbsorbBarPresent"}
local visuals={"Portrait","RaidTargetIcon","LeaderIcon","RoleIcon","CombatIndicator","RestingIndicator","ReadyCheckIndicator","ClassificationIndicator"}
local function Setup(mode)
    selected="player"
    local present=mode~="max"
    configs={player={present=true},target={present=true}}
    for _,key in ipairs({"pet","targettarget","focus","focustarget","boss"}) do configs[key]={present=present} end
    for _,unit in ipairs({"player","target"}) do
        for _,key in ipairs(bars) do configs[unit][key]=present end
        for _,key in ipairs(visuals) do configs[unit][key]={present=present} end
        for _,key in ipairs({"Buffs","Debuffs"}) do configs[unit][key]={present=present} end
    end
    if mode=="normal" then
        configs.player.powerBarPresent=false; configs.player.castBarPresent=false
        configs.player.Portrait.present=false; configs.player.Buffs.present=false
    end
end
local function NoErrors() assert(#f.env.errors==0,table.concat(f.env.errors,"\n")) end
local function Open(height,buttons,headers)
    UIParent:SetHeight(height); presenceCalls={}; indicatorCalls=0
    open()
    local dialog=last
    local scroll=assert(dialog.body.children[3])
    assert(scroll.type=="ScrollFrame" and scroll.LayoutFunc==ace:GetLayout("List"))
    -- Execute the existing widget's deferred native correction once.
    scroll.scrollframe:Run("OnUpdate")
    local b,h=0,0
    for _,child in ipairs(scroll.children) do
        if child.type=="Button" then b=b+1 else h=h+1 end
    end
    Equal({b,h},{buttons,headers}); Equal(indicatorCalls,1)
    for _,count in pairs(presenceCalls) do Equal(count,1) end
    Equal(dialog.window.frame:GetWidth(),420)
    assert(dialog.window.frame:GetHeight()<=height-32)
    assert(dialog.body.children[1].type=="Label")
    assert(dialog.cancelButton.parent==dialog.body.children[4])
    assert(dialog.cancelButton.parent.parent==dialog.body)
    local used=0
    for _,child in ipairs(dialog.body.children) do used=used+child.frame:GetHeight() end
    assert(used<=dialog.body.frame:GetHeight(),"body/Cancel exceeds shell bounds")
    local content,viewport=scroll.content:GetHeight(),scroll.scrollframe:GetHeight()
    Equal(scroll.scrollBarShown==true,content>=viewport+2)
    Equal(scroll.localstatus.scrollvalue,0); Equal(scroll.localstatus.offset,0)
    if scroll.scrollBarShown then
        Equal(scroll.content.width,scroll.content.original_width-20)
        for _,child in ipairs(scroll.children) do Equal(child.frame:GetWidth(),scroll.content.width) end
    end
    NoErrors()
    return dialog,scroll
end
local function Bottom(scroll,wheel)
    assert(scroll.scrollBarShown)
    if wheel then
        for i=1,100 do scroll.scrollframe:Run("OnMouseWheel",-1) end
    else scroll.scrollbar:SetValue(1000) end
    Equal(scroll.localstatus.scrollvalue,1000)
    local bottom=scroll.content:GetHeight()-scroll.localstatus.offset
    assert(bottom<=scroll.scrollframe:GetHeight()+1,"last option not reachable")
end
local function Close(dialog,scroll,how)
    if how=="x" then dialog.window.closebutton:Run("OnClick")
    elseif how=="escape" then dialog.window.frame:Run("OnKeyDown","ESCAPE")
    else dialog.cancelButton:Fire("OnClick") end
    assert(dialog.released and not dialog.window.frame:IsShown())
    Equal(#dialog.body.children,0); Equal(#scroll.children,0)
    assert(not scroll.scrollBarShown)
    NoErrors()
end

for _,height in ipairs({1440,1080,768,640,480}) do
    Setup("min"); local d,s=Open(height,2,1)
    assert(not s.scrollBarShown and d.window.frame:GetHeight()<=200)
    local smallHeight=d.window.frame:GetHeight(); Close(d,s)
    Setup("normal"); d,s=Open(height,6,4)
    assert(d.window.frame:GetHeight()>smallHeight); Close(d,s)
    Setup("max"); d,s=Open(height,22,5)
    Bottom(s,true); s.scrollbar:SetValue(0); Bottom(s,false)
    print("PASS Add Object height "..height..": minimal="..smallHeight..", maximal="..d.window.frame:GetHeight()..", selection="..s.scrollframe:GetHeight())
    Close(d,s)
end

-- Boundary checks derive the content need from the actual normal-state layout.
Setup("normal"); local d,s=Open(1080,6,4)
local need=s.content:GetHeight()
local fixed=d.window.frame:GetHeight()-s.frame:GetHeight()
Close(d,s)
for _,delta in ipairs({-3,3}) do
    d,s=Open(fixed+need+32+delta,6,4)
    Equal(s.scrollBarShown==true,delta<0); Close(d,s)
end

-- Long translated heading exercises actual wrapping, not count * fixed height.
Setup("max"); d,s=Open(640,22,5); local shortNeed=s.content:GetHeight(); Close(d,s)
local oldHeading,oldButton,oldDescription=ns.L.ADD_OBJECT_CATEGORY_BARS,ns.L.EDITOR_ADD_ALTERNATIVE_POWER_BAR_BUTTON,ns.L.ADD_OBJECT_DESCRIPTION
ns.L.ADD_OBJECT_CATEGORY_BARS=string.rep("Verfuegbare zusaetzliche Ressourcenleisten ",4)
ns.L.EDITOR_ADD_ALTERNATIVE_POWER_BAR_BUTTON="Sekundaere Ressourcenleiste hinzufuegen"
ns.L.ADD_OBJECT_DESCRIPTION=string.rep("Waehle ein Objekt fuer den ausgewaehlten Einheitenrahmen. ",3)
d,s=Open(640,22,5)
assert(s.content:GetHeight()>shortNeed)
local found=false
for _,child in ipairs(s.children) do
    if child.type=="Button" and child.text:GetText()==ns.L.EDITOR_ADD_ALTERNATIVE_POWER_BAR_BUTTON then
        found=true; assert(child.text:GetStringHeight()<=child.frame:GetHeight())
    end
end
assert(found); Bottom(s,true); Close(d,s)
ns.L.ADD_OBJECT_CATEGORY_BARS=oldHeading; ns.L.EDITOR_ADD_ALTERNATIVE_POWER_BAR_BUTTON=oldButton; ns.L.ADD_OBJECT_DESCRIPTION=oldDescription

-- Capability variants use the actual Presence and indicator rules.
Setup("max"); configs.player.Buffs.present=true; configs.player.Debuffs.present=true
d,s=Open(640,20,4); Close(d,s)
Setup("max"); for _,key in ipairs(bars) do configs.player[key]=true end
d,s=Open(640,16,4); Close(d,s)
Setup("max"); selected="target"; d,s=Open(640,20,5); Close(d,s)

-- Exercise every option's retained callback/arguments, after its close/release.
local calls={}
local function Record(kind,...) assert(last.released); calls[#calls+1]={kind,...} end
ns.LayoutEditWorkflow={RequestEditableLayoutForMutation=function(callback) callback() end}
ns.InspectorMutations={
    SetUnitPresence=function(context,present) Record("unit",context.unitKey,present); return {ok=true} end,
    AddComponent=function(context,key) Record("component",context.unitKey,key); return {ok=true} end,
    AddDecoration=function(context) Record("decoration",context.unitKey); return {ok=true,newDecorationId="test"} end,
}
ns.GUI.Editor.TextTemplateLibraryWindow={Open=function(options)
    assert(not last.released and options.entity and options.returnContext.originToken)
    calls[#calls+1]={"text",options.unit}
end}
local expected={}
for _,key in ipairs({"pet","targettarget","focus","focustarget","boss"}) do expected[#expected+1]={"unit",key,true} end
for _,key in ipairs({"PowerBar","CastBar","ClassPowerBar","AlternativePowerBar","NormalAbsorbBar","HealingAbsorbBar","Portrait","RaidTargetIcon","LeaderIcon","RoleIcon","CombatIndicator","RestingIndicator","ReadyCheckIndicator","Buffs","Debuffs"}) do expected[#expected+1]={"component","player",key} end
expected[#expected+1]={"text","player"}; expected[#expected+1]={"decoration","player"}
for index,expect in ipairs(expected) do
    Setup("max"); d,s=Open(640,22,5)
    local options={}; for _,child in ipairs(s.children) do if child.type=="Button" then options[#options+1]=child end end
    options[index]:Fire("OnClick")
    Equal(#calls,index); Equal(calls[index],expect)
    if expect[1]=="text" then Close(d,s) end
    assert(d.released); Equal(#s.children,0)
    NoErrors()
end

-- Warm all sizes, then verify allocation stability and reset across all exits.
Setup("min"); d,s=Open(640,2,1); Close(d,s)
Setup("max"); d,s=Open(640,22,5); Close(d,s)
local count=f.Count()
for cycle=1,30 do
    Setup("min"); d,s=Open(640,2,1); Close(d,s)
    Setup("max"); d,s=Open(640,22,5); Bottom(s,true)
    Close(d,s,({"cancel","x","escape"})[(cycle-1)%3+1])
    Setup("min"); d,s=Open(640,2,1); Close(d,s)
    Equal(f.Count(),count)
end
NoErrors()
print("PASS: measured Add Object content/overflow, real capabilities once, fixed Cancel, translations, 22 actions, all close paths and 30 pooling cycles")
