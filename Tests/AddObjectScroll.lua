-- lua54 Tests/AddObjectScroll.lua
-- Real Add Object, Compact Shell, AceGUI List/ScrollFrame and capability rules.
-- Only native anchor resolution, font metrics and product mutation endpoints
-- are doubles. No alternate implementation of the production height policy.
local f=dofile("Tests/ParchmentWindow.lua")
local ns,ace,native,Equal=f.ns,f.ace,f.native,f.Equal
local previousAtlas=C_Texture
local missingAtlas,invalidAtlas,throwAtlas,noAtlasAPI
C_Texture={GetAtlasInfo=function(name)
    if name==throwAtlas then error("missing atlas") end
    if name==missingAtlas then return nil end
    if name==invalidAtlas then return {width=0,height=0} end
    return {width=8,height=8}
end}
for _,method in ipairs({"SetBackdropColor","SetBackdropBorderColor"})do
    local original=native[method]
    native[method]=function(self,...)
        self["last"..method]={...}
        return original(self,...)
    end
end

-- Resolve the stretched rectangles used by the real compact/scroll owners.
local oldWidth,oldHeight=native.GetWidth,native.GetHeight
function native:GetWidth()
    local a,b=self.points.TOPLEFT,self.points.BOTTOMRIGHT
    if a and b and a.relative==b.relative then
        return math.max(0,a.relative:GetWidth()+b.x-a.x)
    end
    -- Compact SelectionRow labels span from the optional icon (or marker) to the right inset.
    local left,right=self.points.LEFT,self.points.RIGHT
    local marker=left and left.relative
    if marker and marker.points.LEFT then
        local iconLeft=marker.points.LEFT
        local iconMarker=iconLeft.relative
        local markerLeft=iconMarker.points.TOPLEFT
        if right and markerLeft and markerLeft.relative==right.relative then
            return right.relative:GetWidth()+right.x-(markerLeft.x+iconMarker:GetWidth()+iconLeft.x+marker:GetWidth()+left.x)
        end
    end
    local leading=marker and marker.points.TOPLEFT
    if right and leading and leading.relative==right.relative and left.relativePoint=="RIGHT"
        and right.relativePoint=="RIGHT" then
        return right.relative:GetWidth()+right.x-(leading.x+marker:GetWidth()+left.x)
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
ns.GUI.Editor.State={GetPrimaryUnit=function()return selected end,IsArrange=function()return false end}
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
local function Open(height,buttons,headers,globalUnit)
    UIParent:SetHeight(height); presenceCalls={}; indicatorCalls=0
    if globalUnit then open()
    else ns.GUI.Editor.CanvasToolbar.OpenComponentAdd({kind="unit",unit=selected},function()return true end) end
    local dialog=last
    local scroll=assert(dialog.body.children[3])
    assert(scroll.type=="ScrollFrame" and scroll.LayoutFunc==ace:GetLayout("List"))
    -- Execute the existing widget's deferred native correction once.
    scroll.scrollframe:Run("OnUpdate")
    local bar=scroll.scrollbar
    local styled=not (missingAtlas or invalidAtlas or throwAtlas or noAtlasAPI)
    local art=bar._fpAddObjectScrollArt
    Equal(bar:GetWidth(),16);Equal({bar.min,bar.max},{0,1000})
    Equal({bar:GetThumbTexture():GetWidth(),bar:GetThumbTexture():GetHeight()},{16,24})
    Equal({bar.points.TOPLEFT.x,bar.points.TOPLEFT.y,bar.points.BOTTOMLEFT.x,bar.points.BOTTOMLEFT.y},{4,-16,4,16})
    if styled then
        assert(art and #art==6)
        Equal(art[1].atlas,"minimal-scrollbar-track-top")
        Equal(art[2].atlas,"!minimal-scrollbar-track-middle")
        Equal(art[3].atlas,"minimal-scrollbar-track-bottom")
        for _,region in ipairs(art) do assert(region:IsShown());Equal(region:GetWidth(),8) end
        for _,snapshot in ipairs(bar._testNativeScrollbar.original) do Equal(snapshot[1]:GetAlpha(),0) end
        local valueChanged=bar:GetScript("OnValueChanged")
        local previousEvents={};for _,event in ipairs({"OnEnter","OnMouseDown","OnMouseUp","OnLeave"}) do previousEvents[event]=bar.nativeEvents and bar.nativeEvents[event] or 0 end
        bar:Run("OnEnter");Equal(art[4].atlas,"minimal-scrollbar-small-thumb-top-over")
        bar:Run("OnMouseDown","LeftButton");Equal(art[4].atlas,"minimal-scrollbar-small-thumb-top-down")
        bar:Run("OnMouseUp","LeftButton");Equal(art[4].atlas,"minimal-scrollbar-small-thumb-top-over")
        bar:Run("OnLeave");Equal(art[4].atlas,"minimal-scrollbar-small-thumb-top")
        for event,count in pairs(previousEvents) do Equal(bar.nativeEvents[event],count+1) end
        assert(bar:GetScript("OnValueChanged")==valueChanged)
    else
        for _,region in ipairs(art or {}) do assert(not region:IsShown()) end
        for _,snapshot in ipairs(bar._testNativeScrollbar.original) do Equal(snapshot[1]:GetAlpha(),snapshot[2]) end
    end
    local b,h,gaps,sectionGaps,headingGaps=0,0,0,0,0
    for index,child in ipairs(scroll.children) do
        if child.type=="FocalPointSelectionRow" then
            b=b+1
            assert(child.binding and child.binding.selected==false and child.key==child.label:GetText())
            assert(not child.binding.description and not child.binding.detail and not child.binding.status)
            assert(child.binding.icon and child.icon:IsShown())
            Equal(child.icon:GetTexture(),child.binding.icon)
            local states=ns.GUI.Skins.GetFormPalette().CompositionTree.icon
            local tint=states[child.binding.icon:match("fp_icon_(%a+)%.png$")]
            assert(child.binding.presentation.iconColor==tint and child.binding.presentation.iconStates==states)
            Equal(child.icon.lastSetVertexColor,{tint[1],tint[2],tint[3],states.normalAlpha})
            if globalUnit then assert(child.binding.icon:match("fp_icon_unit%.png$")) end
            Equal(child.frame:GetHeight(),30)
            assert(not child.marker:IsShown())
            local _,size=child.label:GetFont();Equal(size,13)
            local palette=ns.GUI.Skins.GetFormPalette()
            assert(child.binding.presentation.colors.fill==palette.CompositionTree.surface)
            assert(child.binding.presentation.colors.fillHover==palette.CompositionTree.rowHover)
            assert(child.binding.presentation.colors.borderHover==palette.CompositionTree.text.selected)
            local fill,border=palette.CompositionTree.surface,palette.Chrome.sectionBorder
            Equal(child.frame.lastSetBackdropColor,{fill[1],fill[2],fill[3],fill[4]*.65})
            Equal(child.frame.lastSetBackdropBorderColor,{border[1],border[2],border[3],border[4]*.65})
            assert(child.label:GetStringWidth()<=child.label:GetWidth(),"object name clipped: "..child.label:GetText())
            assert(child.label:GetStringHeight()<=child.frame:GetHeight())
        elseif child.type=="Label" and child.label:GetText()~="" then
            h=h+1
            local _,size=child.label:GetFont();Equal(size,16)
            local color=NORMAL_FONT_COLOR or ns.GUI.Helpers.TextStyles.Get("strongHeading")
            Equal(child.label.lastSetTextColor,{color.r,color.g,color.b})
            assert(child.frame:GetHeight()>=child.label:GetStringHeight(),"section heading overlaps the next row")
            local after=assert(scroll.children[index+1]);Equal(after.frame:GetHeight(),5)
            if h>1 then Equal(scroll.children[index-1].frame:GetHeight(),10) end
        else
            assert(child.type=="SimpleGroup" and #child.children==0)
            local height=child.frame:GetHeight()
            if height==4 then gaps=gaps+1
            elseif height==5 then headingGaps=headingGaps+1
            else Equal(height,10);sectionGaps=sectionGaps+1 end
        end
    end
    Equal({b,h,gaps},{buttons,headers,buttons}); Equal(indicatorCalls,1)
    Equal({sectionGaps,headingGaps},{headers-1,headers})
    for _,count in pairs(presenceCalls) do Equal(count,1) end
    Equal(dialog.window.frame:GetWidth(),420)
    assert(dialog.window.frame:GetHeight()<=height-32)
    assert(dialog.body.children[1].type=="Label")
    assert(dialog.cancelButton==nil and #dialog.body.children==3,"unexpected footer or Cancel button")
    local used=0
    for _,child in ipairs(dialog.body.children) do used=used+child.frame:GetHeight() end
    assert(used<=dialog.body.frame:GetHeight(),"selection exceeds shell bounds")
    Equal(dialog.window.frame:GetHeight()-scroll.frame:GetHeight(),95+math.max(0,dialog.body.children[1].frame:GetHeight()-24))
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
    local rows={}
    for _,child in ipairs(scroll.children)do if child.type=="FocalPointSelectionRow"then rows[#rows+1]=child end end
    if how=="escape" then dialog.window.frame:Run("OnKeyDown","ESCAPE")
    else dialog.window.closebutton:Run("OnClick") end
    assert(dialog.released and not dialog.window.frame:IsShown())
    Equal(#dialog.body.children,0); Equal(#scroll.children,0)
    assert(not scroll.scrollBarShown)
    local bar=scroll.scrollbar
    for _,region in ipairs(bar._fpAddObjectScrollArt or {}) do assert(not region:IsShown()) end
    for _,snapshot in ipairs(bar._testNativeScrollbar.original) do Equal(snapshot[1]:GetAlpha(),snapshot[2]) end
    for event,script in pairs(bar._testNativeScrollbar.scripts) do assert(bar:GetScript(event)==script) end
    for _,row in ipairs(rows)do
        row.frame:Run("OnLeave")
        assert(row.binding==nil and row.onSelect==nil and row.key==nil and not row.hovered and row.presentationFont==nil)
        assert(row.label:GetText()=="" and not row.frame:IsShown() and not row.marker:IsShown())
        assert(not row.icon:IsShown() and row.icon:GetTexture()==nil)
        Equal(row.icon.lastSetVertexColor,{1,1,1,1})
    end
    NoErrors()
end

for _,height in ipairs({1440,1080,768,640,480}) do
    Setup("min"); local d,s=Open(height,2,1)
    assert(not s.scrollBarShown);Equal(d.window.frame:GetHeight(),182)
    local smallHeight=d.window.frame:GetHeight(); Close(d,s)
    Setup("normal"); d,s=Open(height,6,4)
    assert(d.window.frame:GetHeight()>smallHeight); Close(d,s)
    Setup("max"); d,s=Open(height,17,4)
    if s.scrollBarShown then Bottom(s,true); s.scrollbar:SetValue(0); Bottom(s,false)
    else assert(s.content:GetHeight()<=s.scrollframe:GetHeight()+1) end
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
Setup("max"); d,s=Open(640,17,4); local shortNeed=s.content:GetHeight(); Close(d,s)
local oldHeading,oldButton,oldDescription=ns.L.ADD_OBJECT_CATEGORY_BARS,ns.L.ADD_OBJECT_ALTERNATIVE_POWER_BAR_BUTTON,ns.L.ADD_OBJECT_DESCRIPTION
ns.L.ADD_OBJECT_CATEGORY_BARS=string.rep("Verfuegbare zusaetzliche Ressourcenleisten ",4)
ns.L.ADD_OBJECT_ALTERNATIVE_POWER_BAR_BUTTON="Sekundaere Ressourcenleiste hinzufuegen"
ns.L.ADD_OBJECT_DESCRIPTION=string.rep("Waehle ein Objekt fuer den ausgewaehlten Einheitenrahmen. ",3)
d,s=Open(640,17,4)
assert(s.content:GetHeight()>shortNeed)
local found=false
for _,child in ipairs(s.children) do
    if child.type=="FocalPointSelectionRow" and child.label:GetText()==ns.L.ADD_OBJECT_ALTERNATIVE_POWER_BAR_BUTTON then
        found=true; assert(child.label:GetStringHeight()<=child.frame:GetHeight())
    end
end
assert(found); Bottom(s,true); Close(d,s)
ns.L.ADD_OBJECT_CATEGORY_BARS=oldHeading; ns.L.ADD_OBJECT_ALTERNATIVE_POWER_BAR_BUTTON=oldButton; ns.L.ADD_OBJECT_DESCRIPTION=oldDescription

-- Capability variants use the actual Presence and indicator rules.
Setup("max"); configs.player.Buffs.present=true; configs.player.Debuffs.present=true
d,s=Open(640,15,3); Close(d,s)
Setup("max"); for _,key in ipairs(bars) do configs.player[key]=true end
d,s=Open(640,11,3); Close(d,s)
Setup("max"); selected="target"; d,s=Open(640,15,4); Close(d,s)
Setup("max"); d,s=Open(640,5,1,true); Close(d,s)

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
    Setup("max"); d,s=Open(640,index<=5 and 5 or 17,index<=5 and 1 or 4,index<=5)
    local options={}; for _,child in ipairs(s.children) do if child.type=="FocalPointSelectionRow" then options[#options+1]=child end end
    options[index<=5 and index or index-5].frame:Run("OnMouseDown","LeftButton")
    Equal(#calls,index); Equal(calls[index],expect)
    if expect[1]=="text" then Close(d,s) end
    assert(d.released); Equal(#s.children,0)
    NoErrors()
end

-- Shipped translations and missing-locale fallbacks change names only: the same
-- ordered options must still dispatch the same 22 actions/arguments.
local originalLocale=ns.L
local labels={
    enUS={"Power Bar","Cast Bar","Class Power Bar","Secondary Resource Bar","Normal Absorb Bar","Healing Absorb Bar",
        "Portrait","Raid Target","Leader","Role","Combat","Resting","Ready Check","Buffs","Debuffs","Text","Decoration"},
    deDE={"Ressourcenleiste","Zauberbalken","Klassenressourcenleiste","Sekundärressourcenleiste","Normaler Absorptionsbalken","Heilungsabsorptionsbalken",
        "Porträt","Schlachtzugsziel","Gruppenleiter","Rolle","Kampf","Ruhe","Bereitschaft","Buffs","Debuffs","Text","Dekoration"},
}
for _,locale in ipairs({"enUS","deDE","fallback"})do
    local localized={}
    if locale~="fallback"then
        local env=setmetatable({GetLocale=function()return locale end},{__index=_G})
        assert(loadfile("Locales/"..locale..".lua","t",env))("FocalPoint",localized)
        for _,key in ipairs({"POWER","CAST","CLASS_POWER","ALTERNATIVE_POWER","NORMAL_ABSORB","HEALING_ABSORB"})do
            assert(type(localized.L["ADD_OBJECT_"..key.."_BAR_BUTTON"])=="string",locale..":"..key)
        end
    end
    ns.L=localized.L or {}
    Setup("max");d,s=Open(640,17,4)
    local names={}
    for _,child in ipairs(s.children)do
        if child.type=="FocalPointSelectionRow"then
            local name=child.label:GetText()
            assert(not name:match("^Add%s") and not name:find("hinzufügen",1,true))
            names[#names+1]=name
            local index=#names
            local icon=index<=6 and "bar" or index==7 and "portrait" or index<=13 and "indicator"
                or index<=15 and "aura" or index==16 and "text" or "decoration"
            Equal(child.binding.icon,"Interface\\AddOns\\FocalPoint\\Media\\Icons\\Runtime\\fp_icon_"..icon..".png")
        end
    end
    Equal(names,labels[locale] or labels.enUS)
    Close(d,s)
    for index,expect in ipairs(expected)do
        Setup("max");d,s=Open(640,index<=5 and 5 or 17,index<=5 and 1 or 4,index<=5)
        local options={};for _,child in ipairs(s.children)do if child.type=="FocalPointSelectionRow"then options[#options+1]=child end end
        local before=#calls
        options[index<=5 and index or index-5].frame:Run("OnMouseDown","LeftButton")
        Equal(#calls,before+1);Equal(calls[#calls],expect)
        if expect[1]=="text"then Close(d,s)end
        assert(d.released);NoErrors()
    end
end
ns.L=originalLocale

-- Existing Row MouseDown contract: hover/right-click never activates or selects.
Setup("max");d,s=Open(640,17,4)
local entry=s.children[3];assert(entry.type=="FocalPointSelectionRow")
local before=#calls
entry.frame:Run("OnEnter");assert(entry.hovered and entry.binding.selected==false)
local palette=ns.GUI.Skins.GetFormPalette()
Equal(entry.frame.lastSetBackdropColor,palette.CompositionTree.rowHover)
Equal(entry.frame.lastSetBackdropBorderColor,palette.CompositionTree.text.selected)
local tint,states=entry.binding.presentation.iconColor,palette.CompositionTree.icon
Equal(entry.icon.lastSetVertexColor,{math.min(1,tint[1]*states.hoverBrightness),math.min(1,tint[2]*states.hoverBrightness),math.min(1,tint[3]*states.hoverBrightness),states.hoverAlpha})
assert(not entry.marker:IsShown())
entry.frame:Run("OnMouseDown","RightButton");Equal(#calls,before);assert(not d.released)
entry.frame:Run("OnLeave");assert(not entry.hovered and entry.binding.selected==false)
local oldBinding=entry.binding
local originalFont=entry.presentationFont
local disabledBinding={};for key,value in pairs(oldBinding) do disabledBinding[key]=value end
disabledBinding.disabled=true
entry:Bind(disabledBinding);Equal(entry.icon.lastSetVertexColor,states.disabled)
entry:Bind({key=oldBinding.key,label=oldBinding.label,icon=oldBinding.icon,selected=false,disabled=true,onSelect=oldBinding.onSelect})
Equal(entry.icon.lastSetVertexColor,{1,1,1,1})
Equal(entry.frame:GetHeight(),22);assert(entry.marker:IsShown() and entry.presentationFont==nil)
Equal({entry.label:GetFont()},originalFont)
Equal(entry.frame.lastSetBackdropColor,palette.ListSelectionRow.fill)
Equal(entry.frame.lastSetBackdropBorderColor,palette.ListSelectionRow.border)
entry.frame:Run("OnEnter");assert(not entry.hovered)
entry.frame:Run("OnMouseDown","LeftButton");Equal(#calls,before);assert(not d.released)
entry:Bind(oldBinding)
Equal(entry.frame:GetHeight(),30);assert(not entry.marker:IsShown())
local stale=entry.onSelect
Close(d,s);stale();Equal(#calls,before)
Setup("max");d,s=Open(640,17,4);stale();Equal(#calls,before);assert(not d.released);Close(d,s)

-- Every required atlas fails closed before any native texture/script is modified.
local required={"minimal-scrollbar-track-top","!minimal-scrollbar-track-middle","minimal-scrollbar-track-bottom"}
for _,part in ipairs({"top","middle","bottom"}) do
    for _,suffix in ipairs({"","-over","-down"}) do required[#required+1]="minimal-scrollbar-small-thumb-"..part..suffix end
end
for _,atlas in ipairs(required) do
    missingAtlas=atlas;Setup("max");d,s=Open(640,17,4);Bottom(s,true);Close(d,s)
end
missingAtlas=nil
invalidAtlas=required[1];Setup("max");d,s=Open(640,17,4);Close(d,s);invalidAtlas=nil
throwAtlas=required[1];Setup("max");d,s=Open(640,17,4);Close(d,s);throwAtlas=nil
local availableAtlas,availableLegacyAtlas=C_Texture,GetAtlasInfo
C_Texture,GetAtlasInfo=nil,nil;noAtlasAPI=true
Setup("max");d,s=Open(640,17,4);Close(d,s)
C_Texture,GetAtlasInfo=availableAtlas,availableLegacyAtlas;noAtlasAPI=nil
Setup("max");d,s=Open(640,17,4)
local lateLeave=s.scrollbar:GetScript("OnLeave");local oldBar=s.scrollbar
Close(d,s)
Setup("max");d,s=Open(640,17,4)
s.scrollbar:Run("OnEnter");lateLeave(oldBar)
Equal(s.scrollbar._fpAddObjectScrollArt[4].atlas,"minimal-scrollbar-small-thumb-top-over")
Close(d,s)
-- Ordinary AceGUI consumers retain their native assets, alpha and scripts,
-- regardless of whether the pool returns a previously styled ScrollFrame.
local ordinary=ace:Create("ScrollFrame")
for _,region in ipairs(ordinary.scrollbar._fpAddObjectScrollArt or {}) do assert(not region:IsShown()) end
for _,snapshot in ipairs(ordinary.scrollbar._testNativeScrollbar.original) do Equal(snapshot[1]:GetAlpha(),snapshot[2]) end
for event,script in pairs(ordinary.scrollbar._testNativeScrollbar.scripts) do assert(ordinary.scrollbar:GetScript(event)==script) end
Equal(ordinary.scrollbar:GetThumbTexture():GetTexture(),"native-scroll-thumb")
ace:Release(ordinary)

-- Warm all sizes, then verify allocation stability and reset across all exits.
Setup("min"); d,s=Open(640,2,1); Close(d,s)
Setup("max"); d,s=Open(640,17,4); Close(d,s)
local count=f.Count()
for cycle=1,30 do
    Setup("min"); d,s=Open(640,2,1); Close(d,s)
    Setup("max"); d,s=Open(480,17,4); Bottom(s,true)
    Close(d,s,cycle%2==0 and "x" or "escape")
    Setup("min"); d,s=Open(640,2,1); Close(d,s)
    Equal(f.Count(),count)
end
NoErrors()
C_Texture=previousAtlas
print("PASS: Tree-styled SelectionRows, 30px cards/4px gaps, full DE/EN/fallback names, isolated presentation/font restore, hover/MouseDown/disabled, scroll/22 actions, stale bindings and 30 pooling cycles")
