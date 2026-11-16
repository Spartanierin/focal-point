-- Actual Workspace, builders, selection, mutations and AceGUI pooling.
local function Read(path)
    local f=assert(io.open(path));local text=f:read("*a");f:close();return text
end
local source=Read("Tests/ClassResourcePropertyGroups.lua")
local stop=assert(source:find("\nlocal count=0",1,true))
local p,Start,Body,Click,Current=assert(load(source:sub(1,stop)..[[
return p,Start,Body,Click,function()return window,unit,db end
]],"@InspectorSectionLayout/Workspace"))()
local function Headings(section,tab)
    local result={}
    for _,group in ipairs(Body(section).children)do
        if group:GetUserData("normalAbsorbPropertyGroup")==tab and group:GetUserData("normalAbsorbPropertyContent")then
            assert(group.type=="InlineGroup" and #group.children>0,"missing or empty frame")
            local padding=assert(group._fpSectionPadding)
            local nativeHealth=section=="health" and tab=="appearance"
            local horizontal=nativeHealth and 24 or 16
            assert(padding.left==horizontal and padding.right==horizontal and padding.top==(nativeHealth and 31 or 27) and padding.bottom==13)
            assert(group.frame:IsShown()==(p.state.Get().inspectorPropertyGroup==tab))
            result[#result+1]=group.titletext:GetText()
            p.Walk(group,function(w)assert(not w:GetUserData("flatPropertyHeading"),"duplicate flat section title")end)
        end
    end
    return table.concat(result,",")
end

local count=0
local function Test(name,fn)fn();count=count+1;print("PASS: "..name)end
Test("Class Power frames follow Size, Anchor and Growth without changing field bindings",function()
    Start("expert");Click("geometry")
    assert(Headings("class_power","geometry")=="Size,Anchor,Growth")
    p.Control("Height","FPCompactSlider"):Fire("OnValueChanged",23);p.Drain()
    local _,unit=Current();assert(unit.classPowerBarHeight==23)
    p.Control("Anchor From","Dropdown"):Fire("OnValueChanged","LEFT");p.Drain()
    assert(unit.classPowerBarPoint=="LEFT")
    p.Control("Offset X","FPCompactSlider"):Fire("OnValueChanged",16);p.Drain()
    assert(unit.classPowerBarOffsetX==16)
end)
Test("tab switches allocate no headings and create no singleton Actions area",function()
    local window,_,db=Current();local before=p.h.Copy(db)
    local a,r,t=p.Stats()
    for _=1,20 do
        for _,key in ipairs({"appearance","geometry","behavior"})do
            Click(key)
            assert(Headings("class_power","geometry")=="Size,Anchor,Growth")
            local actions=0
            for _,group in ipairs(Body("class_power").children)do
                if group:GetUserData("normalAbsorbObjectActions")then
                    actions=actions+1;assert(group.frame:IsShown())
                    assert(not group:GetUserData("normalAbsorbPropertyGroup"))
                    p.Walk(group,function(w)assert(not w:GetUserData("flatPropertyHeading"))end)
                end
            end
            assert(actions==0)
        end
    end
    local aa,rr,tt=p.Stats();assert(a==aa and r==rr and t==tt)
    p.h.Equal(db,before)
    assert(window==Current())
end)
Test("conditional and single-control groups retain one nonempty Behavior frame",function()
    Start("quick")
    assert(Headings("class_power","geometry")=="Size,Anchor,Growth")
    assert(Headings("class_power","behavior")=="Behavior")
    local window,unit=Current()
    unit.alternativePowerBarPresent=true;unit.showAlternativePowerBar=true
    unit.castBarPresent=true;unit.showCastBar=true
    for _,item in ipairs({{"HealthBar","health"},{"PowerBar","power"},{"AlternativePowerBar","alt_power"},
        {"NormalAbsorbBar","absorbs"},{"HealingAbsorbBar","absorbs"},{"CastBar","cast"}})do
        p.Select(item[1])
        for _,key in ipairs({"appearance","geometry","behavior"})do Headings(item[2],key)end
        assert(Headings(item[2],"behavior")=="Behavior")
        local expected={health="",power="Size,Anchor",alt_power="Size",absorbs="Size,Anchor,Growth",cast="Size,Anchor"}
        assert(Headings(item[2],"geometry")==expected[item[2]],item[1].." geometry frames")
    end
    p.Select("NormalAbsorbBar")
    assert(Headings("absorbs","geometry")=="Size,Anchor,Growth")
    window.closebutton:GetScript("OnClick")(window.closebutton);p.Drain()
    p.Build();p.Select("ClassPowerBar")
    assert(Headings("class_power","geometry")=="Size,Anchor,Growth")
end)
Test("all singleton tabs keep framed order and original Behavior rows in both stored modes",function()
    for _,expert in ipairs({false,true})do
        Start(expert and "quick" or "expert")
        local _,unit,db=Current()
        db.profile={General={ExpertMode=expert}}
        unit.alternativePowerBarPresent=true;unit.showAlternativePowerBar=true
        unit.castBarPresent=true;unit.showCastBar=true
        p.controller.RefreshActiveProperties();p.Drain()
        for _,item in ipairs({
            {"HealthBar","health","","Reverse Fill"},
            {"PowerBar","power","Size,Anchor","Show,Reverse Fill"},
            {"AlternativePowerBar","alt_power","Size","Show,Reverse Fill"},
            {"NormalAbsorbBar","absorbs","Size,Anchor,Growth","Show"},
            {"HealingAbsorbBar","absorbs","Size,Anchor,Growth","Show"},
            {"ClassPowerBar","class_power","Size,Anchor,Growth","Show"},
            {"CastBar","cast","Size,Anchor","Show,Show Cast Bar Icon"},
        })do
            p.Select(item[1]);Click("behavior")
            assert(Headings(item[2],"behavior")=="Behavior")
            assert(Headings(item[2],"geometry")==item[3])
            local labels={}
            for _,group in ipairs(Body(item[2]).children)do
                if group:GetUserData("normalAbsorbPropertyGroup")=="behavior" and group:GetUserData("normalAbsorbPropertyContent")then
                    for _,row in ipairs(group.children)do
                        local label=(row.children or {})[1]
                        assert(label and label.type=="Label")
                        labels[#labels+1]=label.label:GetText()
                    end
                end
            end
            assert(table.concat(labels,",")==item[4],item[1].." Behavior controls")
            local before=p.h.Copy(db);local a,r,t=p.Stats()
            for _,tab in ipairs({"appearance","geometry","behavior"})do Click(tab)end
            local aa,rr,tt=p.Stats();assert(a==aa and r==rr and t==tt)
            p.h.Equal(db,before)
        end
        assert(db.profile.General.ExpertMode==expert)
    end
end)
Test("instances use the same Health frames without duplicate flat section labels",function()
    Start("expert")
    local m=p.ns.LayoutMutations.SegmentedBars
    local result=m.Add(assert(m.CaptureContext("player")),{enabled=true,dataSource={id="runes",scope="player"},anchorTo="Frame"})
    assert(result.ok,result.errorCode)
    assert(p.selection.SelectObject({kind="segmentedBar",unit="player",objectKey=result.id}));p.Drain()
    assert(Headings("segmented_bars","geometry")=="Size,Anchor,Growth")
    for _=1,10 do
        p.controller.RefreshActiveProperties();p.Drain()
        assert(Headings("segmented_bars","geometry")=="Size,Anchor,Growth")
        p.Select("HealthBar");p.Select("ClassPowerBar")
        assert(Headings("class_power","geometry")=="Size,Anchor,Growth")
        assert(p.selection.SelectObject({kind="segmentedBar",unit="player",objectKey=result.id}));p.Drain()
    end
    local window=Current()
    p.Walk(window._focalPointPropertyScroll,function(w)
        if w.type=="Label" then
            assert(not w.frame._fpFlatSectionLine,"section divider leaked into a pooled Label")
        end
    end)
end)
-- Model the same native API boundary as the Manager fixture, not atlas raster bounds.
local previousNineSlice, previousTexture, previousAtlas = NineSliceUtil, C_Texture, GetAtlasInfo
local previousNormalFontColor = NORMAL_FONT_COLOR
NORMAL_FONT_COLOR = {r=1,g=.82,b=0}
local pieces = {
    TopLeftCorner={atlas="%s-NineSlice-CornerTopLeft"}, TopRightCorner={atlas="%s-NineSlice-CornerTopRight"},
    BottomLeftCorner={atlas="%s-NineSlice-CornerBottomLeft"}, BottomRightCorner={atlas="%s-NineSlice-CornerBottomRight"},
    TopEdge={atlas="_%s-NineSlice-EdgeTop"}, BottomEdge={atlas="_%s-NineSlice-EdgeBottom"},
    LeftEdge={atlas="!%s-NineSlice-EdgeLeft"}, RightEdge={atlas="!%s-NineSlice-EdgeRight"},
    Center={atlas="%s-NineSlice-Center"},
}
local missingAtlas
local function Atlas(name)
    if name=="OptionsFrame-NineSlice-Center" or name==missingAtlas then return nil end
    if name:find("OptionsFrame",1,true) then return {width=32,height=32} end
    local get=previousTexture and previousTexture.GetAtlasInfo or previousAtlas
    return get and get(name)
end
C_Texture={GetAtlasInfo=Atlas}
NineSliceUtil={
    GetLayout=function(name)
        if name=="UniqueCornersLayout"then return pieces end
        return previousNineSlice and previousNineSlice.GetLayout(name)
    end,
    ApplyLayoutByName=function(host,name,kit)
        if name~="UniqueCornersLayout"then return previousNineSlice.ApplyLayoutByName(host,name,kit)end
        assert(kit=="OptionsFrame")
        for key,piece in pairs(pieces)do
            host[key]=host[key] or host:CreateTexture(nil,"BORDER")
            local atlas=string.format(piece.atlas,kit)
            if Atlas(atlas)then host[key]:SetAtlas(atlas,true)end
        end
    end,
}
local renderer=p.ns.GUI.Helpers.FormSectionSurfaceRenderer
local binding=p.ns.GUI.Editor.Inspector.InspectorBinding
local nativeDescriptor=binding.ResolveSectionPresentation("muted","blizzardGroupBox")
local reserve=assert(nativeDescriptor.decorationReserve)
assert(reserve.top==6 and reserve.bottom==6,"prototype reserve changed")
local function NoMaterial(group)
    for _,name in ipairs({"Fill","TopShade","BottomShade","Accent","Divider",
        "BorderTop","BorderBottom","BorderLeft","BorderRight"})do
        local region=group.frame["_fpSection"..name]
        assert(not region or not region:IsShown(),"material overlaps native border: "..name)
    end
end
Test("native mode has optional Center, strict border preflight and exclusive reversible owner-local decoration",function()
    local owner=p.h.ui.ace:Create("InlineGroup")
    local style=binding.ResolveSectionPresentation("muted")
    style.border={color={1,1,1,1}}
    style.surface=p.h.Copy(style.surface)
    style.surface.accent={color={1,1,1,1}}
    style.surface.divider={mode="center_vertical",color={1,1,1,1}}
    renderer.ApplySectionSurface(owner,style);renderer.ApplySectionBorder(owner,style.border)
    assert(owner.frame._fpSectionFill:IsShown() and owner.frame._fpSectionBorderTop:IsShown())
    assert(owner.frame._fpSectionFill.points.TOPLEFT.x==6 and owner.frame._fpSectionFill.points.BOTTOMRIGHT.x==-6)
    style.presentationMode="blizzardGroupBox"
    style.decorationReserve=reserve
    renderer.ApplySectionSurface(owner,style);renderer.ApplySectionBorder(owner,style.border)
    local box=assert(owner.frame._fpSectionGroupBox)
    assert(box:GetParent()==owner.frame and box:IsShown() and not box.Center:IsShown())
    assert(box.lastEnableMouse[1]==false)
    assert(box.points.TOPLEFT.relative==owner.frame and box.points.TOPLEFT.relativePoint=="TOPLEFT"
        and box.points.TOPLEFT.x==0 and box.points.TOPLEFT.y==reserve.top)
    assert(box.points.BOTTOMRIGHT.relative==owner.frame and box.points.BOTTOMRIGHT.relativePoint=="BOTTOMRIGHT"
        and box.points.BOTTOMRIGHT.x==0 and box.points.BOTTOMRIGHT.y==-reserve.bottom)
    NoMaterial(owner)
    for key,piece in pairs(pieces)do if key~="Center"then
        missingAtlas=string.format(piece.atlas,"OptionsFrame")
        renderer.ApplySectionSurface(owner,style);renderer.ApplySectionBorder(owner,style.border)
        assert(not box:IsShown() and owner.frame._fpSectionFill:IsShown() and owner.frame._fpSectionBorderTop:IsShown())
    end end
    missingAtlas=nil
    for _=1,20 do
        renderer.ApplySectionSurface(owner,style);renderer.ApplySectionBorder(owner,style.border)
        assert(owner.frame._fpSectionGroupBox==box and box:IsShown());NoMaterial(owner)
        assert(box.points.TOPLEFT.x==0 and box.points.BOTTOMRIGHT.x==0)
        style.presentationMode=nil
        renderer.ApplySectionSurface(owner,style);renderer.ApplySectionBorder(owner,style.border)
        assert(not box:IsShown() and owner.frame._fpSectionFill:IsShown())
        assert(owner.frame._fpSectionFill.points.TOPLEFT.x==6 and owner.frame._fpSectionFill.points.BOTTOMRIGHT.x==-6)
        style.presentationMode="blizzardGroupBox"
    end
    renderer.ApplySectionSurface(owner,nil);renderer.ApplySectionBorder(owner,false)
    assert(not box:IsShown());NoMaterial(owner)
    p.h.ui.ace:Release(owner)
end)
Test("Player/Target Health Appearance/Background keep their native content room and unchanged tabs",function()
    Start("quick");p.Select("HealthBar");Click("appearance")
    local window,unit=Current()
    local root=p.ns.ActiveLayoutResolver.GetActiveRuntimeRoot()
    root.units.target=p.h.Copy(unit)
    for _,unitKey in ipairs({"player","target"})do
    assert(p.selection.SelectObject({kind="bar",unit=unitKey,objectKey="HealthBar"}));p.Drain();Click("appearance")
    local health=Body("health")
    assert(Headings("health","appearance")=="Appearance,Background")
    local groups={}
    for _,group in ipairs(health.children)do if group.type=="InlineGroup"then
        local box=group.frame._fpSectionGroupBox
        if group:GetUserData("normalAbsorbPropertyGroup")=="appearance"then
            assert(box and box:IsShown());NoMaterial(group);groups[#groups+1]=group
        else assert(not box or not box:IsShown())end
    end end
    assert(#groups==2)
    for _,group in ipairs(groups)do
        assert(group.content.points.TOPLEFT.x==24 and group.content.points.TOPLEFT.y==-31)
        assert(group.content.points.BOTTOMRIGHT.x==-24 and group.content.points.BOTTOMRIGHT.y==13)
        assert(group.titletext.points.TOPLEFT.x==24 and group.titletext.points.TOPLEFT.y==-12)
        assert(group.titletext.points.TOPRIGHT.x==-24 and group.titletext.points.TOPRIGHT.y==-12)
        local color=group.titletext.lastSetTextColor
        assert(color[1]==NORMAL_FONT_COLOR.r and color[2]==NORMAL_FONT_COLOR.g and color[3]==NORMAL_FONT_COLOR.b)
        assert(color[4]==1,"native Health title must use local alpha one")
        local last=group.children[#group.children]
        assert(last.type=="SimpleGroup" and #last.children==0 and last.frame:GetHeight()==5)
        local row=group.children[#group.children-1]
        group:DoLayout()
        local rowBottom=-row.frame.points.TOPLEFT.y+row.frame:GetHeight()
        assert(group.frame:GetHeight()-31-rowBottom==17,"last property row must retain 17 nominal inner units")
        for _,child in ipairs(group.children)do
            local label=child.children and child.children[1]
            if label then assert(label.type=="Label" and label.frame:GetWidth()==160,"property label column changed")end
        end
    end
    local function CheckReserve(active)
        local slots={}
        for _,group in ipairs(groups)do
            local index
            for i,w in ipairs(health.children)do if w==group then index=i end end
            local before,after=health.children[index-1],health.children[index+1]
            assert(before.type=="SimpleGroup" and after.type=="SimpleGroup")
            assert(before.frame:GetHeight()==reserve.top and after.frame:GetHeight()==reserve.bottom)
            for _,slot in ipairs({before,after})do
                assert(slot:GetUserData("normalAbsorbPropertyGroup")=="appearance")
                assert(not slot:GetUserData("normalAbsorbPropertyContent"))
                assert(slot.frame:IsShown()==(active=="appearance"))
            end
            slots[#slots+1]={before=before,group=group,after=after}
        end
        health:DoLayout();window._focalPointPropertyScroll:DoLayout()
        if active=="appearance"then
            local function Top(w)return -w.frame.points.TOP.y end
            local first,last=slots[1],slots[2]
            assert(Top(first.before)==0,"first reserve must start the scrollable property body")
            for _,entry in ipairs(slots)do
                local box=entry.group.frame._fpSectionGroupBox
                assert(Top(entry.group)-box.points.TOPLEFT.y==Top(entry.before))
                assert(Top(entry.group)+entry.group.frame:GetHeight()-box.points.BOTTOMRIGHT.y
                    ==Top(entry.after)+entry.after.frame:GetHeight())
            end
            local firstBottom=Top(first.after)+first.after.frame:GetHeight()
            assert(Top(last.before)-firstBottom==2,"reserved border hosts must leave a positive two-unit gap")
            local lastBottom=Top(last.after)+last.after.frame:GetHeight()
            assert(lastBottom==health.frame:GetHeight(),"last border reserve is missing from content height")
            assert(window._focalPointPropertyScroll.content:GetHeight()>=lastBottom,"scroll extent lost the bottom reserve")
        end
        local total=0
        for _,w in ipairs(health.children)do if w.frame:IsShown()then total=total+w.frame:GetHeight()end end
        assert(total==health.frame:GetHeight(),"hidden reserve consumes layout space")
    end
    CheckReserve("appearance")
    assert(p.Tabs().geometry.disabled,"Health's existing empty geometry tab must remain disabled")
    for _,tab in ipairs({"geometry","behavior","appearance"})do
        Click(tab)
        local expected=tab=="geometry" and "appearance" or tab
        assert(p.state.Get().inspectorPropertyGroup==expected)
        for _,group in ipairs(groups)do assert(group.frame:IsShown()==(expected=="appearance"))end
        CheckReserve(expected)
    end
    end
    local host=p.h.ui.ace:Create("SimpleGroup")
    p.ns.GUI.Editor.Inspector.BuildProperties(host,p.state.Get(),{getUnitConfig=p.ns.UnitFrameUtils.GetUnitDB})
    p.Walk(host,function(w)
        assert(not w.frame._fpSectionGroupBox or not w.frame._fpSectionGroupBox:IsShown())
        if w._fpSectionPadding then assert(w._fpSectionPadding.right==16)end
    end)
    p.h.ui.ace:Release(host)
    unit.castBarPresent=true;unit.showCastBar=true
    for _,object in ipairs({"PowerBar","NormalAbsorbBar","ClassPowerBar","CastBar"})do
        p.Select(object)
        p.Walk(window._focalPointPropertyScroll,function(w)
            assert(not w.frame._fpSectionGroupBox or not w.frame._fpSectionGroupBox:IsShown(),object)
            if w._fpSectionPadding then assert(w._fpSectionPadding.right==16)end
        end)
    end
end)
Test("every catalog Health unit reuses native groups only in the scoped workspace; boss aliases share config",function()
    Start("quick");p.Select("HealthBar");Click("appearance")
    local _,unit=Current()
    local root=p.ns.ActiveLayoutResolver.GetActiveRuntimeRoot()
    local catalog={}
    assert(loadfile("Data/Constants.lua"))("FocalPoint",catalog)
    local previousBoss=root.units.boss
    root.units.boss=p.h.Copy(unit)
    for _,alias in ipairs({"boss1","boss2","boss3","boss4","boss5"})do
        local tree=assert(p.ns.CompositionTreeAdapter.BuildUnitTree(alias))
        assert(tree.unit=="boss" and tree.id=="unit:boss")
        assert(root.units[alias]==nil,"boss aliases must not create separate configs")
    end
    root.units.boss=previousBoss
    for _,unitKey in ipairs(catalog.Constants.UnitOrder)do
        local previous=root.units[unitKey]
        root.units[unitKey]=p.h.Copy(unit)
        local state=p.h.Copy(p.state.Get())
        state.selectedUnit=unitKey
        state.propertyScope={kind="unit",unit=unitKey,sectionKey="health"}
        local host=p.h.ui.ace:Create("SimpleGroup")
        p.ns.GUI.Editor.Inspector.BuildProperties(host,state,{
            getUnitConfig=p.ns.UnitFrameUtils.GetUnitDB,isCurrentBuild=function()return true end})
        local count=0
        local body
        p.Walk(host,function(w)
            if w:GetUserData("focalPointSectionKey")=="health" and w._focalPointRequestRebuild then body=w end
            if w.type=="InlineGroup" and w:GetUserData("normalAbsorbPropertyGroup")=="appearance"then
                count=count+1
                assert(w.frame._fpSectionGroupBox and w.frame._fpSectionGroupBox:IsShown(),unitKey)
                NoMaterial(w)
                assert(w._fpSectionPadding.left==24 and w._fpSectionPadding.right==24
                    and w._fpSectionPadding.top==31 and w._fpSectionPadding.bottom==13,unitKey)
                assert(w.titletext.points.TOPLEFT.x==24 and w.titletext.points.TOPLEFT.y==-12)
                p.h.Equal(w.titletext.lastSetTextColor,{NORMAL_FONT_COLOR.r,NORMAL_FONT_COLOR.g,NORMAL_FONT_COLOR.b,1})
                local tail=w.children[#w.children]
                assert(tail.type=="SimpleGroup" and #tail.children==0 and tail.frame:GetHeight()==5)
            else
                assert(not w.frame._fpSectionGroupBox or not w.frame._fpSectionGroupBox:IsShown(),unitKey)
            end
        end)
        assert(count==2,"missing native Health groups: "..unitKey)
        assert(body);body:DoLayout()
        local total=0
        for i,w in ipairs(body.children)do
            if w.frame:IsShown()then total=total+w.frame:GetHeight()end
            if w.type=="InlineGroup" and w:GetUserData("normalAbsorbPropertyGroup")=="appearance"then
                local before,after=body.children[i-1],body.children[i+1]
                assert(before.frame:GetHeight()==6 and after.frame:GetHeight()==6)
                assert(before:GetUserData("normalAbsorbPropertyGroup")=="appearance"
                    and after:GetUserData("normalAbsorbPropertyGroup")=="appearance")
            end
        end
        assert(total==body.frame:GetHeight(),"reserve slots missing from Health layout height")
        p.ns.GUI.Editor.Inspector.BuildProperties(host,state,{getUnitConfig=p.ns.UnitFrameUtils.GetUnitDB})
        p.Walk(host,function(w)
            assert(not w.frame._fpSectionGroupBox or not w.frame._fpSectionGroupBox:IsShown(),unitKey)
            if w._fpSectionPadding then assert(w._fpSectionPadding.left==16 and w._fpSectionPadding.right==16
                and w._fpSectionPadding.top==27 and w._fpSectionPadding.bottom==13,unitKey)end
        end)
        p.h.ui.ace:Release(host)
        root.units[unitKey]=previous
    end
    for _,scenario in ipairs({{unit="missing",section="health"},{unit="player",section="not_implemented"}})do
        local state=p.h.Copy(p.state.Get())
        state.selectedUnit=scenario.unit
        state.propertyScope={kind="unit",unit=scenario.unit,sectionKey=scenario.section}
        local host=p.h.ui.ace:Create("SimpleGroup")
        local before=p.h.Copy(root)
        p.ns.GUI.Editor.Inspector.BuildProperties(host,state,{
            getUnitConfig=p.ns.UnitFrameUtils.GetUnitDB,isCurrentBuild=function()return true end})
        p.Walk(host,function(w)assert(not w.frame._fpSectionGroupBox or not w.frame._fpSectionGroupBox:IsShown())end)
        p.h.Equal(root,before)
        p.h.ui.ace:Release(host)
    end
end)
Test("native binding survives override/reset, rebuild, release/reuse and reopen without duplicate decoration",function()
    for _,path in ipairs({"GUI/Helpers/PresentationPreview.lua","GUI/Helpers/PresentationCompositionPreview.lua"})do
        local name=path:match("([^/]+)%.lua$")
        if not p.ns.GUI[name]then assert(loadfile(path))("FocalPoint",p.ns)end
    end
    local ace=p.h.ui.ace
    local owner=ace:Create("InlineGroup")
    binding.ApplyInspectorSectionStructure(owner,"muted",nil,"blizzardGroupBox")
    local box=assert(owner.frame._fpSectionGroupBox)
    local preview=p.ns.Ace.PresentationPreview
    assert(preview.Set("inspector_section_surface","color",{1,0,0}))
    assert(not box:IsShown() and owner.frame._fpSectionFill:IsShown())
    assert(preview.Clear("inspector_section_surface"));assert(box:IsShown());NoMaterial(owner)
    local composition=p.ns.Ace.PresentationCompositionPreview
    assert(composition.AddLayer("inspector_section","surface"))
    assert(not box:IsShown());NoMaterial(owner)
    assert(composition.ResetComposition("inspector_section"));assert(box:IsShown());NoMaterial(owner)
    local alternate={presentationMode="blizzardGroupBox",decorationReserve={top=2,bottom=4}}
    binding.ApplyInspectorSectionStructure(owner,"muted",nil,alternate)
    assert(box.points.TOPLEFT.y==alternate.decorationReserve.top
        and box.points.BOTTOMRIGHT.y==-alternate.decorationReserve.bottom,"renderer ignored the supplied descriptor")
    for _=1,20 do
        local yellow=NORMAL_FONT_COLOR
        binding.ApplyInspectorSectionStructure(owner,"muted",{headerInsetX=24,headerTopGap=12,
            color={yellow.r,yellow.g,yellow.b},alpha=1},"blizzardGroupBox")
        assert(owner.titletext.points.TOPLEFT.x==24 and owner.titletext.points.TOPLEFT.y==-12)
        assert(preview.SetTypographyPresentation("inspector_section_heading",{size=14}))
        assert(owner.titletext.points.TOPLEFT.x==24 and owner.titletext.points.TOPLEFT.y==-12)
        assert(preview.ClearTypography("inspector_section_heading"))
        assert(owner.titletext.points.TOPLEFT.x==24 and owner.titletext.points.TOPLEFT.y==-12)
        local function CheckColor(r,g,b)
            local color=owner.titletext.lastSetTextColor
            assert(color[1]==r and color[2]==g and color[3]==b and color[4]==1)
        end
        CheckColor(yellow.r,yellow.g,yellow.b)
        for _,alpha in ipairs({0,.35})do
            assert(preview.SetTypographyPresentation("inspector_section_heading",{alpha=alpha}))
            assert(owner.titletext.lastSetTextColor[4]==alpha,"explicit alpha override lost priority")
            assert(preview.ClearTypography("inspector_section_heading"))
            CheckColor(yellow.r,yellow.g,yellow.b)
        end
        assert(preview.SetTypographyPresentation("inspector_section_heading",{color={.1,.2,.3}}))
        CheckColor(.1,.2,.3)
        assert(preview.ClearTypography("inspector_section_heading"))
        CheckColor(yellow.r,yellow.g,yellow.b)
        assert(owner.frame._fpSectionGroupBox==box and box:IsShown());NoMaterial(owner)
        assert(box.points.TOPLEFT.x==0 and box.points.TOPLEFT.y==reserve.top
            and box.points.BOTTOMRIGHT.x==0 and box.points.BOTTOMRIGHT.y==-reserve.bottom)
        ace:Release(owner);assert(not box:IsShown())
        local nextOwner=ace:Create("InlineGroup");assert(nextOwner==owner)
        assert(not box:IsShown(),"native decoration leaked into an ordinary pooled InlineGroup")
        assert(nextOwner.titletext.points.TOPLEFT.x==8 and nextOwner.titletext.points.TOPLEFT.y==-8,
            "local Health title anchors leaked into a pooled InlineGroup")
        local canonical=assert(p.ns.GUI.PresentationPreview.ResolveTypographyPresentation("inspector_section_heading",true))
        p.h.Equal(nextOwner.titletext.lastSetTextColor,{canonical.color[1],canonical.color[2],canonical.color[3],canonical.alpha})
        owner=nextOwner
    end
    ace:Release(owner)
    Start("quick");p.Select("HealthBar");Click("appearance")
    local root=p.ns.ActiveLayoutResolver.GetActiveRuntimeRoot()
    local _,unit=Current();root.units.target=p.h.Copy(unit)
    for _=1,20 do
        local window=Current()
        window.closebutton:GetScript("OnClick")(window.closebutton);p.Drain()
        p.Build()
        local unitKey=_%2==0 and "player" or "target"
        assert(p.selection.SelectObject({kind="bar",unit=unitKey,objectKey="HealthBar"}));p.Drain();Click("appearance")
        assert(Headings("health","appearance")=="Appearance,Background")
    end
end)
Test("Health layout reserve remains constant across material fallback and presentation overrides",function()
    Start("quick");p.Select("HealthBar");Click("appearance")
    local root=p.ns.ActiveLayoutResolver.GetActiveRuntimeRoot()
    local _,unit=Current();root.units.target=p.h.Copy(unit)
    for _,unitKey in ipairs({"player","target"})do
    assert(p.selection.SelectObject({kind="bar",unit=unitKey,objectKey="HealthBar"}));p.Drain();Click("appearance")
    local function Snapshot(native)
        local health=Body("health")
        health:DoLayout()
        local window=Current();window._focalPointPropertyScroll:DoLayout()
        local data={height=health.frame:GetHeight(),scroll=window._focalPointPropertyScroll.content:GetHeight(),children={}}
        local count=0
        for _,w in ipairs(health.children)do
            data.children[#data.children+1]={w.type,w.frame:GetHeight(),w.frame.points.TOP.y,
                w:GetUserData("normalAbsorbPropertyGroup"),w.frame:IsShown()}
            if w.type=="InlineGroup" and w:GetUserData("normalAbsorbPropertyGroup")=="appearance"then
                count=count+1
                local box=assert(w.frame._fpSectionGroupBox)
                assert(box:IsShown()==native)
                if native then NoMaterial(w)end
            end
        end
        assert(count==2)
        return data
    end
    local before=Snapshot(true)
    local preview=p.ns.Ace.PresentationPreview
    assert(preview.Set("inspector_section_surface","color",{1,0,0}));p.h.Equal(Snapshot(false),before)
    assert(preview.Clear("inspector_section_surface"));p.h.Equal(Snapshot(true),before)
    local composition=p.ns.Ace.PresentationCompositionPreview
    assert(composition.AddLayer("inspector_section","surface"));p.h.Equal(Snapshot(false),before)
    assert(composition.ResetComposition("inspector_section"));p.h.Equal(Snapshot(true),before)
    missingAtlas="_OptionsFrame-NineSlice-EdgeTop"
    p.controller.RefreshActiveProperties();p.Drain();p.h.Equal(Snapshot(false),before)
    missingAtlas=nil
    p.controller.RefreshActiveProperties();p.Drain();p.h.Equal(Snapshot(true),before)
    end
end)
NineSliceUtil,C_Texture,GetAtlasInfo=previousNineSlice,previousTexture,previousAtlas
NORMAL_FONT_COLOR=previousNormalFontColor
assert(#p.h.ui.env.errors==0,table.concat(p.h.ui.env.errors,"\n"))
print("Inspector Section Layout: "..count.." groups PASS")
