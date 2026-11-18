-- lua54 Tests/ToolWindowFamily.lua
-- Reuse native WoW doubles and real AceGUI widgets, without modifying U1 tests.
local file=assert(io.open("Tests/DialogWindowFamily.lua")); local source=file:read("*a"); file:close()
local stop=assert(source:find("-- Direct utility chrome",1,true))
local f,Find=assert(load(source:sub(1,stop-1).."\nforms.CreateCompactFormDialog=create; return f,Find","@Tool/NativeFixture"))()
local ns,ace,native,Equal,Load,Upvalue=f.ns,f.ace,f.native,f.Equal,f.Load,f.Upvalue
local forms=f.widgets
function native:GetJustifyH() return self.lastSetJustifyH and self.lastSetJustifyH[1] or "CENTER" end
function native:GetShadowOffset() return table.unpack(self.lastSetShadowOffset or {1,-1}) end
function native:GetShadowColor() return table.unpack(self.lastSetShadowColor or {0,0,0,1}) end
local tagPieces
function native:SetStatusBarColor(...) self.lastSetStatusBarColor={...} end
function native:SetStatusBarTexture(...) self.lastSetStatusBarTexture={...} end
local tool={nineSlice=true,portrait=true,focalPointTool=true}
local legacy={nineSlice=true,portrait=true,portraitTexture="portrait.png"}
local material=ns.GUI.Skins.GetFormPalette().CompactDialogContent.parchment
local texture=ns.MediaRegistry.ResolveReference(material.textureId,"texture").resolvedAsset
local function NoErrors() assert(#f.env.errors==0,table.concat(f.env.errors,"\n")) end
local function Check(window,w,h)
    local frame=window.frame; local border=assert(frame._fpModernNineSlice)
    assert(frame._fpToolChromeActive and border:IsShown())
    Equal({frame:GetWidth(),frame:GetHeight()},{w,h})
    Equal(border.TopLeftCorner.nativeWidth,28); Equal(border.TopEdge.nativeHeight,28)
    Equal(border.TopRightCorner.lastSetTexCoord,{1,0,0,1})
    Equal(border.lastSetAllPoints,{frame})
    assert(not window._fpNavigatorBrassTarget and not frame._fpCompactFormShell)
    for _,key in ipairs({"_fpToolBody","_fpToolTitlebar"}) do
        local region=assert(frame[key]); assert(region:IsShown())
        Equal(region:GetTexture(),texture)
        Equal(region.lastSetVertexColor,key=="_fpToolBody" and material.tint or material.headerTint)
        Equal(region.lastSetHorizTile,{false}); Equal(region.lastSetVertTile,{false})
        Equal(region.lastSetTexCoord,{0,1,0,1})
    end
    Equal(frame._fpToolTitlebar:GetHeight(),24)
    local color=ns.GUI.Helpers.TextStyles.Get("sectionHeader")
    Equal(window.titletext.lastSetTextColor,{color.r,color.g,color.b,1})
    for _,key in ipairs({"_fpModernPortraitContainer","_fpModernPortraitBackground","_fpModernPortraitTopTileStreaks",
        "_fpModernTitleLeft","_fpModernTitleCenter","_fpModernTitleRight"}) do
        assert(not frame[key] or not frame[key]:IsShown(),key)
    end
    for _,region in ipairs({frame:GetRegions()}) do
        if region:GetTexture()==251963 or region:GetTexture()==251966 or region:GetTexture()==137056 then
            assert(not region:IsShown(),"native texture leaked")
        end
    end
    assert(not border.Center or not border.Center:IsShown())
    Equal(window.closebutton:GetFrameLevel(),frame:GetFrameLevel()+5)
    Equal(window.title:GetFrameLevel(),frame:GetFrameLevel()+4)
    assert(not window.sizer_se:IsShown() and not window.sizer_s:IsShown() and not window.sizer_e:IsShown())
end

local function CheckTags(context)
    local window,frame=context.window,context.window.frame
    Equal(frame:GetWidth(),540)
    local height=0
    for _,child in ipairs(context.widgets.root.children) do height=height+child.frame:GetHeight() end
    Equal(frame:GetHeight(),57+height+8)
    assert(frame:GetHeight()<760)
    Equal({window.titletext:GetFont()},{STANDARD_TEXT_FONT,16,""})
    local points=window.titletext.points
    Equal({points.TOPLEFT.x,points.TOPLEFT.y,points.TOPRIGHT.x,points.TOPRIGHT.y},{12,-15,-32,-15})
    Equal(window.titletext.lastSetTextColor,{1,1,1,1})
    assert(frame._fpModernTitleLeft:IsShown())
    Equal(frame._fpModernTitleLeft.atlas,"UI-Frame-DiamondMetal-CornerTopLeft")
    assert(not frame._fpModernNineSlice or not frame._fpModernNineSlice:IsShown())
    assert(not frame._fpToolBody or not frame._fpToolBody:IsShown())
    assert(not frame._fpModernPortraitContainer or not frame._fpModernPortraitContainer:IsShown())
    Equal({window.title.points.TOPLEFT.x,window.title.points.TOPLEFT.y,
        window.title.points.BOTTOMRIGHT.x,window.title.points.BOTTOMRIGHT.y},{8,0,-math.max(36,window.closebutton:GetWidth()+4),-32})
    Equal(context.dialog.body.frame.lastSetAllPoints,{window.content})
    -- The native double does not resolve stretched child anchors automatically.
    -- Mirror the zero-inset body content before asserting the unchanged root bounds.
    Equal(context.dialog.body.frame:GetWidth(),506)
    context.dialog.body.content:SetSize(context.dialog.body.frame:GetWidth(),context.dialog.body.frame:GetHeight())
    context.dialog.body:DoLayout()
    Equal(context.widgets.root.frame:GetWidth(),506)
    Equal(context.widgets.listScroll.frame:GetHeight(),242)
    Equal(context.widgets.details.frame:GetHeight(),112)
    local browser,detail=context.widgets.browser,context.widgets.detailGroup
    assert(browser.parent==detail.parent and browser.parent.LayoutFunc==ace:GetLayout("List"))
    -- As with the body above, resolve the stack's stretched native content in this double.
    local root=context.widgets.root
    local padding=root._fpSectionPadding
    Equal(padding.top,8)
    Equal(root.content.points.TOPLEFT.y,-8)
    root.content:SetSize(root.frame:GetWidth()-padding.left-padding.right,root.frame:GetHeight()-padding.top-padding.bottom)
    root:DoLayout()
    local content=browser.parent
    content.content:SetSize(content.frame:GetWidth(),content.frame:GetHeight())
    content:DoLayout()
    Equal(browser.frame:GetWidth(),detail.frame:GetWidth())
    Equal(browser.frame:GetWidth(),474)
    local gap=content.children[2]
    assert(gap.frame.points.TOPLEFT.relative==browser.frame and gap.frame.points.TOPLEFT.relativePoint=="BOTTOMLEFT")
    assert(detail.frame.points.TOPLEFT.relative==gap.frame and detail.frame.points.TOPLEFT.relativePoint=="BOTTOMLEFT")
    Equal(gap.frame:GetHeight(),32)
    assert(gap.frame:GetHeight()>=15+15)
    Equal(content.frame:GetHeight(),browser.frame:GetHeight()+32+detail.frame:GetHeight())
    Equal(detail.frame:GetHeight(),160)
    local footerGap=context.widgets.root.children[4]
    assert(footerGap.frame.points.TOPLEFT.relative==content.frame and footerGap.frame.points.TOPLEFT.relativePoint=="BOTTOMLEFT")
    assert(context.widgets.actions.frame.points.TOPLEFT.relative==footerGap.frame)
    Equal(footerGap.frame:GetHeight(),20)
    assert(context.widgets.details.type=="ScrollFrame")
    Equal(context.widgets.actions.LayoutFunc,ace:GetLayout("Table"))
    for _,host in ipairs({context.widgets.browser,context.widgets.detailGroup}) do
        Equal(select(2,host.children[1].label:GetFont()),14)
        local color=NORMAL_FONT_COLOR or {r=1,g=.82,b=0}
        Equal(host.children[1].label.lastSetTextColor,{color.r,color.g,color.b,1})
        local box=assert(host.frame._fpTagLibraryGroupBox)
        assert(box:IsShown() and box:GetParent()==host.frame:GetParent())
        assert(box.testLayout=="UniqueCornersLayout" and box.testKit=="OptionsFrame")
        assert(#box.regions==9 and not box.Center.testAtlas)
        for key,piece in pairs(tagPieces) do
            if key~="Center" then Equal(box[key].testAtlas,string.format(piece.atlas,"OptionsFrame")) end
        end
        assert(box.lastEnableMouse==false or box.lastEnableMouse[1]==false)
        assert(not host.frame.__fpTagLibraryBrowserFill and not host.frame.__fpTagLibraryDetailsFill)
    end
    for _,row in ipairs(context.widgets.rows) do
        Equal(row.frame:GetHeight(),42)
        Equal(select(2,row.label:GetFont()),12)
        Equal(select(2,row.description:GetFont()),10)
    end
end

-- Compare the same actual Window before/after presentation, including scripts.
local window=ace:Create("Window"); window:EnableResize(false)
local nativeStates={}
for _,region in ipairs({window.frame:GetRegions()}) do
    nativeStates[region]={region:IsShown(),region:GetAlpha(),region:GetTexture()}
end
local neutral=f.Geometry(window)
forms.ApplyModernWindowChrome(window,legacy)
local baseline=f.Geometry(window); local font={window.titletext:GetFont()}
local shadowOffset,shadowColor=window.titletext.lastSetShadowOffset,window.titletext.lastSetShadowColor
local close,drag,dragEnd=window.closebutton:GetScript("OnClick"),window.title:GetScript("OnMouseDown"),window.title:GetScript("OnMouseUp")
forms.ApplyModernWindowChrome(window,tool)
Equal(f.Geometry(window),baseline); Equal({window.titletext:GetFont()},font)
Equal(window.titletext.lastSetShadowOffset,shadowOffset); Equal(window.titletext.lastSetShadowColor,shadowColor)
Equal(window.closebutton:GetScript("OnClick"),close); Equal(window.title:GetScript("OnMouseDown"),drag)
Equal(window.title:GetScript("OnMouseUp"),dragEnd)
local count=f.Count(); local release=window.events.OnRelease
for i=1,50 do
    local sizes={{720,660},{760,560},{1040,700}}; local size=sizes[(i-1)%3+1]
    window:SetWidth(size[1]); window:SetHeight(size[2])
    forms.ApplyModernWindowChrome(window,tool); Check(window,size[1],size[2])
    Equal(window.content:GetWidth(),size[1]-34); Equal(window.content:GetHeight(),size[2]-57)
    Equal(window.events.OnRelease,release)
    forms.RestoreDefaultWindowChrome(window)
    assert(not window.frame._fpToolBody:IsShown() and not window.frame._fpToolTitlebar:IsShown())
    assert(not window.frame._fpModernNineSlice:IsShown())
    for region,state in pairs(nativeStates) do Equal({region:IsShown(),region:GetAlpha(),region:GetTexture()},state) end
end
Equal(f.Count(),count)
window:SetWidth(neutral[1]); window:SetHeight(neutral[2]); Equal(f.Geometry(window),neutral)
forms.ApplyModernWindowChrome(window,tool); ace:Release(window)
local poolCount; local releases=0
for i=1,30 do
    local acquired=ace:Create("Window"); Equal(acquired,window); acquired:EnableResize(false)
    acquired:SetCallback("OnRelease",function() releases=releases+1 end)
    forms.ApplyModernWindowChrome(acquired,legacy)
    forms.ApplyModernWindowChrome(acquired,tool); Check(acquired,700,500)
    forms.ApplyWindowChrome(acquired,{focalPointDialog=true})
    assert(not acquired.frame._fpToolBody:IsShown()); assert(not acquired.frame._fpModernNineSlice:IsShown())
    forms.ApplyModernWindowChrome(acquired,tool); assert(not acquired.frame._fpParchmentNineSlice:IsShown())
    ace:Release(acquired)
    Equal(releases,i)
    assert(not acquired.frame._fpModernNineSlice:IsShown())
    if i==1 then poolCount=f.Count() else Equal(f.Count(),poolCount) end
end
NoErrors()

local directOptions={windowChrome="editmode",titleFontSize=16,titleOffsetY=-7,
    headerDrag={left=8,right=36,top=0,height=32}}
local function Points(region)
    local result={}
    for index=1,region:GetNumPoints() do
        local point,relative,relativePoint,x,y=region:GetPoint(index)
        result[point]={relative,relativePoint,x,y}
    end
    return result
end
local function CheckDirect(window,w,h)
    Equal({window.frame:GetWidth(),window.frame:GetHeight()},{w,h})
    Equal({window.titletext:GetFont()},{STANDARD_TEXT_FONT,16,""})
    Equal(window.titletext.lastSetTextColor,{1,1,1,1})
    local p=window.titletext.points
    Equal({p.TOPLEFT.x,p.TOPLEFT.y,p.TOPRIGHT.x,p.TOPRIGHT.y},{12,-15,-32,-15})
    local d=window.title.points
    assert(d.TOPLEFT.relative==window.frame and d.BOTTOMRIGHT.relative==window.frame)
    Equal({d.TOPLEFT.x,d.TOPLEFT.y,d.BOTTOMRIGHT.x,d.BOTTOMRIGHT.y},{8,0,-math.max(36,window.closebutton:GetWidth()+4),-32})
    Equal(window.frame._fpModernPortraitBackground.lastSetColorTexture,{0,0,0,.8})
    assert(window.frame._fpModernPortraitBackground:IsShown())
    for _,key in ipairs({"_fpToolBody","_fpToolTitlebar","_fpModernNineSlice","_fpModernPortraitContainer","_fpModernPortraitTopTileStreaks"}) do
        assert(not window.frame[key] or not window.frame[key]:IsShown(),key)
    end
    assert(not window.frame._fpCompactFormShell and not window._focalPointEditorRole)
    assert(window:GetUserData("fpDirectEditModeChrome"))
end
do
    local atlas,legacyAtlas=C_Texture,GetAtlasInfo
    local releases=0
    for _,mode in ipairs({"native","metal","flat"}) do
        C_Texture={GetAtlasInfo=function(name)
            if mode=="flat" or mode=="metal" and name:find("DiamondMetal",1,true) then return nil end
            return {width=32,height=32}
        end};GetAtlasInfo=nil
        local direct=ace:Create("Window");direct:SetWidth(720);direct:SetHeight(660);direct:EnableResize(false)
        direct.titletext:SetFont(STANDARD_TEXT_FONT,19,"OUTLINE")
        direct.titletext:SetTextColor(.2,.3,.4,.5);direct.titletext:SetJustifyH("LEFT")
        direct.titletext:SetShadowOffset(2,-3);direct.titletext:SetShadowColor(.1,.2,.3,.4)
        local before={font={direct.titletext:GetFont()},color={direct.titletext:GetTextColor()},
            justify=direct.titletext:GetJustifyH(),layer={direct.titletext:GetDrawLayer()},
            title=Points(direct.titletext),drag=Points(direct.title),
            dragSize={direct.title:GetWidth(),direct.title:GetHeight()},content=Points(direct.content)}
        before.parent=direct.titletext:GetParent()
        before.shadowOffset={direct.titletext:GetShadowOffset()};before.shadowColor={direct.titletext:GetShadowColor()}
        local mouseDown,mouseUp,close=direct.title:GetScript("OnMouseDown"),direct.title:GetScript("OnMouseUp"),direct.closebutton:GetScript("OnClick")
        direct:SetCallback("OnRelease",function() releases=releases+1 end)
        forms.ApplyModernWindowChrome(direct,directOptions);CheckDirect(direct,720,660)
        Equal(Points(direct.content),before.content)
        Equal(direct.title:GetScript("OnMouseDown"),mouseDown);Equal(direct.title:GetScript("OnMouseUp"),mouseUp)
        Equal(direct.closebutton:GetScript("OnClick"),close)
        if mode=="flat" then assert(direct.frame._fpPanelBorderTop:IsShown())
        else
            assert(direct.frame._fpModernTitleLeft:IsShown())
            Equal(direct.frame._fpModernTitleLeft.atlas,mode=="native" and "UI-Frame-DiamondMetal-CornerTopLeft" or "UI-Frame-PortraitMetal-CornerTopLeft")
        end
        local release=direct.events.OnRelease
        for cycle=1,20 do
            forms.ApplyModernWindowChrome(direct,directOptions);CheckDirect(direct,720,660)
            Equal(direct.events.OnRelease,release)
            forms.RestoreDefaultWindowChrome(direct)
            Equal({direct.titletext:GetFont()},before.font);Equal({direct.titletext:GetTextColor()},before.color)
            Equal(direct.titletext:GetJustifyH(),before.justify);Equal({direct.titletext:GetDrawLayer()},before.layer)
            Equal(direct.titletext:GetParent(),before.parent)
            Equal({direct.titletext:GetShadowOffset()},before.shadowOffset);Equal({direct.titletext:GetShadowColor()},before.shadowColor)
            Equal(Points(direct.titletext),before.title);Equal(Points(direct.title),before.drag)
            Equal({direct.title:GetWidth(),direct.title:GetHeight()},before.dragSize)
            assert(not direct:GetUserData("fpDirectEditModeChrome"))
        end
        forms.ApplyModernWindowChrome(direct,tool);Check(direct,720,660)
        forms.ApplyModernWindowChrome(direct,directOptions);CheckDirect(direct,720,660)
        ace:Release(direct)
        assert(not direct:GetUserData("fpDirectEditModeChrome") and not direct:GetUserData("fpDirectEditModeRelease"))
        assert(not direct.frame._fpModernPortraitBackground:IsShown())
        local reacquired=ace:Create("Window");Equal(reacquired,direct)
        reacquired:SetWidth(720);reacquired:SetHeight(660);reacquired:EnableResize(false)
        forms.ApplyModernWindowChrome(reacquired,tool);Check(reacquired,720,660)
        ace:Release(reacquired)
    end
    Equal(releases,3)
    C_Texture,GetAtlasInfo=atlas,legacyAtlas
end

-- Actual tools: only media/catalog and persistence are fixture data.
local applyModern=forms.ApplyModernWindowChrome; local consumerCount=0
forms.ApplyModernWindowChrome=function(owner,options)
    if options.windowChrome=="editmode" then
        local content=Points(owner.content)
        applyModern(owner,options);CheckDirect(owner,720,660)
        Equal(Points(owner.content),content)
        consumerCount=consumerCount+1
        return
    end
    assert(options.focalPointTool and options.nineSlice and options.portrait)
    local old={}; for k,v in pairs(options) do old[k]=v end; old.focalPointTool=nil
    applyModern(owner,old)
    local geometry=f.Geometry(owner); local titleFont={owner.titletext:GetFont()}
    applyModern(owner,options)
    Equal(f.Geometry(owner),geometry); Equal({owner.titletext:GetFont()},titleFont)
    consumerCount=consumerCount+1
end
for _,path in ipairs({"GUI/Editor/MediaLibrary/MediaLibraryItems.lua","GUI/Editor/MediaLibrary/MediaLibraryPreviewWidget.lua",
    "GUI/Editor/MediaLibrary/MediaLibraryPreview.lua","GUI/Editor/MediaLibrary/MediaLibraryView.lua",
    "GUI/Editor/MediaLibrary/MediaLibraryController.lua"}) do Load(path) end
local applied,cancelled=nil,0
local media=ns.GUI.Editor.MediaLibrary.Controller
local function OpenMedia()
    assert(media.Open({mediaType="font",onApply=function(value) applied=value end,onCancel=function() cancelled=cancelled+1 end}))
end
OpenMedia(); NoErrors()
local mediaContext=Upvalue(media.Open,"context")
CheckDirect(mediaContext.window,720,660)
assert(mediaContext.widgets.preview and mediaContext.widgets.itemScroll)
assert(#mediaContext.state.items>0)
mediaContext.widgets.searchBox:Fire("OnTextChanged","unlikely-missing-font"); NoErrors()
Equal(mediaContext.state.searchText,"unlikely-missing-font")
mediaContext.widgets.searchBox:Fire("OnTextChanged","")
mediaContext.widgets.sourceDropdown:Fire("OnValueChanged","all"); NoErrors()
local row=assert(mediaContext.widgets.itemRows[1]); row.widget:Fire("OnClick")
mediaContext.widgets.applyButton:Fire("OnClick"); NoErrors(); assert(applied)
OpenMedia(); mediaContext.widgets.cancelButton:Fire("OnClick"); Equal(cancelled,1)

ns.UnitFrame=ns.UnitFrame or {}
function ns.UnitFrame:GetTagDatabase() return {{token="[name]",category="Unit",description="Unit name",example="Player"},
    {token="[hp:cur]",category="Health",description="Current health",example="100"}} end
Load("GUI/Pages/TagLibrary/TagLibraryView.lua"); Load("GUI/Pages/TagLibrary/TagLibraryController.lua")
local nativeLayout,nativeApply=NineSliceUtil.GetLayout,NineSliceUtil.ApplyLayoutByName
tagPieces={TopLeftCorner={atlas="%s-NineSlice-CornerTopLeft"},TopRightCorner={atlas="%s-NineSlice-CornerTopRight"},
    BottomLeftCorner={atlas="%s-NineSlice-CornerBottomLeft"},BottomRightCorner={atlas="%s-NineSlice-CornerBottomRight"},
    TopEdge={atlas="_%s-NineSlice-EdgeTop"},BottomEdge={atlas="_%s-NineSlice-EdgeBottom"},
    LeftEdge={atlas="!%s-NineSlice-EdgeLeft"},RightEdge={atlas="!%s-NineSlice-EdgeRight"},Center={atlas="%s-NineSlice-Center"}}
NineSliceUtil.GetLayout=function(name) if name=="UniqueCornersLayout" then return tagPieces end;return nativeLayout(name) end
NineSliceUtil.ApplyLayoutByName=function(host,name,kit)
    if name~="UniqueCornersLayout" then return nativeApply(host,name,kit) end
    host.testLayout,host.testKit=name,kit
    for key,piece in pairs(tagPieces) do
        host[key]=host[key] or host:CreateTexture(nil,"BORDER")
        local atlas=string.format(piece.atlas,kit)
        if C_Texture.GetAtlasInfo(atlas) then host[key]:SetAtlas(atlas,true);host[key].testAtlas=atlas end
    end
end
-- Media uses the same native border pattern with optional Center and no rectangle fallback.
do
    local view=ns.GUI.Editor.MediaLibrary.MediaLibraryView
    local surface=Upvalue(view.Create,"ApplyCentralSectionChrome")
    local w=mediaContext.widgets
    local atlasAPI=C_Texture
    local missing
    C_Texture={GetAtlasInfo=function(name)
        if name=="OptionsFrame-NineSlice-Center" or name==missing then return nil end
        return {width=32,height=32}
    end}
    for _,group in ipairs({w.listGroup,w.previewGroup}) do
        surface(group)
        local box=assert(group.frame._fpMediaGroupBox)
        Equal(box.testKit,"OptionsFrame");assert(box:IsShown())
        Equal(Points(box),{TOPLEFT={group.frame,"TOPLEFT",-16,15},BOTTOMRIGHT={group.frame,"BOTTOMRIGHT",16,-15}})
        for cycle=1,30 do surface(group);Equal(group.frame._fpMediaGroupBox,box) end
        missing="OptionsFrame-NineSlice-CornerTopLeft";surface(group);assert(not box:IsShown())
        missing=nil;surface(group);assert(box:IsShown())
    end
    Equal(w.listGroup.frame:GetHeight(),272);Equal(w.itemScroll.frame:GetHeight(),226)
    Equal(w.previewGroup.frame:GetHeight(),192);Equal(w.preview.frame:GetHeight(),112)
    Equal(w.root.children[5].frame:GetHeight(),32) -- expanded borders have a 2-unit host gap
    Equal(w.root.children[7].frame:GetHeight(),16) -- footer outside the preview host
    Equal(w.actions.children,{w.applyButton,w.cancelButton})
    Equal(w.root.children[1].frame:GetHeight(),14)
    Equal(w.filterRow.frame:GetHeight(),40);Equal(w.root.children[3].frame:GetHeight(),12)
    Equal(w.actions.frame:GetHeight(),25)
    assert(w.applyButton.frame:GetHeight()<=25 and w.cancelButton.frame:GetHeight()<=25)
    Equal(w.searchBox.label.font[2],13);Equal(w.sourceDropdown.label.font[2],13)
    Equal(w.searchBox.editbox.font[2],14)
    assert(not w.valueLabel.frame:IsShown() and not w.resolvedAssetLabel.frame:IsShown())
    Equal(w.selectedLabel:GetUserData("cell").colspan,2)
    assert(not DropdownButtonMixin) -- native-menu fixture was restored by the New Layout tests
    assert(not w.sourceDropdown:GetUserData("nativePropertyDropdown"))
    assert(w.sourceDropdown.dropdown:IsShown())
    local originalLocale=GetLocale
    for _,locale in ipairs({"enUS","deDE"}) do
        GetLocale=function()return locale end
        Load("Locales/enUS.lua");if locale=="deDE" then Load("Locales/deDE.lua") end
        for _,kind in ipairs({"font","statusbar","decoration"}) do
            assert(media.Open({mediaType=kind}))
            Equal(w.listTitle.label:GetText(),ns.L["MEDIA_LIBRARY_TYPE_"..kind:upper()])
            assert(w.preview.item==mediaContext.state.selectedItem)
            media.Close()
        end
        local ref="Interface/"..string.rep("long-technical-reference/",24).."asset"
        assert(media.Open({mediaType="font",currentValue=ref}))
        assert(w.valueLabel.frame.__fpInspectorTooltip:find(ref,1,true))
        assert(w.resolvedAssetLabel.frame.__fpInspectorTooltip==w.resolvedAssetLabel.label:GetText())
        media.Close()
    end
    GetLocale=originalLocale;Load("Locales/enUS.lua")
    -- A released group hides its sibling art and reacquires without a second frame.
    local group=ace:Create("SimpleGroup");surface(group)
    local box=group.frame._fpMediaGroupBox
    ace:Release(group);assert(not box:IsShown())
    local reused=ace:Create("SimpleGroup");Equal(reused,group);surface(reused)
    Equal(reused.frame._fpMediaGroupBox,box);ace:Release(reused)
    C_Texture=atlasAPI
    NoErrors()
    print("PASS: Media two native groups, optional Center/required-edge fallback, 30 reapplications, release/reuse, Source fallback, EN/DE types and complete reference tooltips")
end
-- Local filter typography must not survive an actual AceGUI window release.
do
    local view=ns.GUI.Editor.MediaLibrary.MediaLibraryView
    local context={state={title="Media release fixture",subtitle="Choose media",mediaType="font",items={},sourceFilter="all"},
        callbacks={onWindowClosed=function() end}}
    view.Create(context)
    local w=context.widgets
    local release=w.searchBox.events.OnRelease
    local inputFont,inputSize,inputFlags=Upvalue(release,"inputFont"),Upvalue(release,"inputSize"),Upvalue(release,"inputFlags")
    local sourceRelease=w.sourceDropdown.events.OnRelease
    local sourceFont,sourceSize,sourceFlags=Upvalue(sourceRelease,"font"),Upvalue(sourceRelease,"size"),Upvalue(sourceRelease,"flags")
    ace:Release(context.window)
    Equal({w.searchBox.editbox:GetFont()},{inputFont,inputSize,inputFlags})
    Equal({w.sourceDropdown.label:GetFont()},{sourceFont,sourceSize,sourceFlags})
    assert(not w.searchBox.frame._fpMediaSearchFill:IsShown())
    for _,label in ipairs({w.selectedLabel,w.sourceLabel,w.statusLabel,w.selectionHelp,w.valueLabel,w.resolvedAssetLabel}) do
        assert(not label.frame.__fpInspectorTooltip)
        Equal(label.label.lastSetWordWrap,{true})
        Equal(label.label.lastSetMaxLines,{0})
    end
    NoErrors()
    print("PASS: Media local 13/14 filter fonts and metadata tooltip state restore on actual window release")
end

local tags=ns.GUI.Pages.TagLibrary; local tagApplied
local missingTagAtlas
local function OpenTags(options)
    local atlasAPI=C_Texture
    C_Texture={GetAtlasInfo=function(name)
        if name=="OptionsFrame-NineSlice-Center" or name==missingTagAtlas then return nil end
        return {width=32,height=32}
    end}
    assert(tags.Open(options or {owner="fixture",onApply=function(token) tagApplied=token end}))
    C_Texture=atlasAPI
end
OpenTags(); NoErrors()
local tagContext=Upvalue(tags.Open,"context"); CheckTags(tagContext)
tagContext.widgets.searchBox:Fire("OnTextChanged","name"); NoErrors()
Equal(#tagContext.state.visibleEntries,1); Equal(tagContext.state.selectedEntry.token,"[name]")
assert(#tagContext.widgets.details.children>0 and tagContext.widgets.listScroll)
tagContext.widgets.applyButton:Fire("OnClick"); Equal(tagApplied,"[name]")
OpenTags(); tagContext.widgets.cancelButton:Fire("OnClick")
local tagWindow=tagContext.window
local keyboard=tagWindow.frame:GetScript("OnKeyDown")
Equal(tagWindow.frame.lastSetPropagateKeyboardInput,{false})
local applyCalls,cancelCalls=0,0
OpenTags({onApply=function(token,entry)
    applyCalls=applyCalls+1;assert(token==entry.token);return false
end,onCancel=function()cancelCalls=cancelCalls+1 end})
tagContext.widgets.applyButton:Fire("OnClick")
assert(applyCalls==1 and tagWindow.frame:IsShown() and cancelCalls==0)
tagContext.widgets.searchBox:Fire("OnTextChanged","no matching token")
assert(tagContext.widgets.applyButton.disabled and #tagContext.state.visibleEntries==0)
tagWindow.frame:Run("OnKeyDown","ESCAPE")
assert(cancelCalls==1 and not tagWindow.frame:IsShown())
OpenTags({onCancel=function()cancelCalls=cancelCalls+1 end})
assert(tagContext.window==tagWindow and tagContext.state.searchText=="")
assert(tagWindow.frame:GetScript("OnKeyDown")==keyboard)
tagWindow.closebutton:Run("OnClick");assert(cancelCalls==2)
OpenTags({onApply=function()applyCalls=applyCalls+1 end,onCancel=function()cancelCalls=cancelCalls+1 end})
tagContext.widgets.applyButton:Fire("OnClick")
assert(applyCalls==2 and cancelCalls==2 and not tagWindow.frame:IsShown())
local boxes={tagContext.widgets.browser.frame._fpTagLibraryGroupBox,tagContext.widgets.detailGroup.frame._fpTagLibraryGroupBox}
for key,piece in pairs(tagPieces) do
    if key~="Center" then
        missingTagAtlas=string.format(piece.atlas,"OptionsFrame")
        OpenTags()
        assert(not boxes[1]:IsShown() and not boxes[2]:IsShown())
    end
end
missingTagAtlas=nil
OpenTags();CheckTags(tagContext)
assert(tagContext.widgets.browser.frame._fpTagLibraryGroupBox==boxes[1])
assert(tagContext.widgets.detailGroup.frame._fpTagLibraryGroupBox==boxes[2])
local database=ns.UnitFrame.GetTagDatabase
local longExample=string.rep("[color:class][name][rc]",30)
for _,longDescription in ipairs({string.rep("Long description ",100),string.rep("Lange Beschreibung mit Textumbruch ",100)}) do
ns.UnitFrame.GetTagDatabase=function()return {{token="[color:blizz_highlight]",category="Format",description=longDescription,example=longExample}}end
OpenTags();CheckTags(tagContext)
local description=assert(Find(tagContext.widgets.details,"Label",longDescription))
local measure=description.label.GetStringHeight
description.label.GetStringHeight=function()return 500 end
description:SetText(longDescription)
tagContext.widgets.details:DoLayout()
assert(tagContext.widgets.details.content:GetHeight()>tagContext.widgets.details.frame:GetHeight())
assert(Find(tagContext.widgets.details,"Label",longExample))
Equal(tagContext.widgets.details.frame:GetHeight(),112)
description.label.GetStringHeight=measure
end
ns.UnitFrame.GetTagDatabase=database
OpenTags();CheckTags(tagContext)
NoErrors()

Load("Data/Constants.lua"); ns.KeyMap=ns.KeyMap or {}
Load("GUI/Helpers/FormSectionSurfaceRenderer.lua"); Load("GUI/Helpers/FormRenderer.lua")
Load("GUI/Pages/TextBuilder/TextBuilderDefinition.lua")
local templates={Sample="[name]"}; local mutationCalls={}
ns.db.GetCurrentProfile=function() return "Test" end
ns.UnitFrameUtils={GetTextTemplatesDB=function() return templates end}
local builderPayload={TextTemplates=templates,Units={}}
ns.ActiveLayoutResolver={
    GetStoredActiveLayoutId=function() return ns.db.char.activeLayoutId end,
    GetActiveLayout=function() return {name="Tool fixture",readOnly=false,payload=builderPayload} end,
    EnsureEditableForMutation=function() return builderPayload,ns.db.char.activeLayoutId end,
}
ns.TextTemplateMutations={
    CreateTemplate=function(_,name,text) templates[name]=text; mutationCalls.create=name; return {ok=true} end,
    UpdateTemplate=function(_,name,text) templates[name]=text; mutationCalls.update=name; return {ok=true} end,
    ApplyTemplateToUnits=function(_,opts) mutationCalls.apply=opts; return {ok=true,appliedUnits=opts.unitsToAdd} end,
}
Load("GUI/Pages/TextBuilder/TextBuilderController.lua")
local builder=ns.GUI.Pages.TextBuilder
builder.OpenWindow(); NoErrors()
Equal(consumerCount,3); forms.ApplyModernWindowChrome=applyModern -- Media, release fixture and large Builder; Tags use Compact Edit Mode.
local builderContext=Upvalue(builder.OpenWindow,"windowContext")
Check(builderContext.window,1040,700)
local key=table.concat({"profile","Test","Test","","Sample"},"\031")
builderContext.templateSelect:Fire("OnValueChanged",key); NoErrors()
Equal(builderContext.state.selectedTemplate,"Sample"); Equal(builderContext.templateEdit:GetText(),"[name]")
builderContext.templateEdit:SetText("[hp:cur]"); builderContext.templateEdit:Fire("OnTextChanged","[hp:cur]")
assert(builder.HasUnsavedChanges())
builderContext.saveButton:Fire("OnClick"); NoErrors()
Equal(mutationCalls.update,"Sample"); Equal(templates.Sample,"[hp:cur]"); assert(not builder.HasUnsavedChanges())
builderContext.usageCheckboxes.player:Fire("OnValueChanged",true)
builderContext.applyTemplateButton:Fire("OnClick"); NoErrors()
Equal(mutationCalls.apply.templateText,"[hp:cur]"); Equal(mutationCalls.apply.unitsToAdd,{"player"})
builderContext.templateEdit:SetText("[name] dirty"); builderContext.templateEdit:Fire("OnTextChanged","[name] dirty")
assert(builder.HasUnsavedChanges())
builder.HideWindow(); NoErrors(); assert(builderContext.window.frame:IsShown())
local function Closure(fn,name,seen)
    seen=seen or {}; if seen[fn] then return end; seen[fn]=true
    local children={}
    for i=1,100 do local key,value=debug.getupvalue(fn,i); if not key then break end
        if key==name then return value end
        if type(value)=="function" then children[#children+1]=value end
    end
    for _,child in ipairs(children) do local value=Closure(child,name,seen); if value then return value end end
end
local closeContext=assert(Closure(builder.HideWindow,"unsavedCloseDialogContext"))
assert(closeContext.window.frame._fpParchmentNineSlice:IsShown())
assert(not closeContext.window.frame._fpToolChromeActive)
closeContext.cancelButton:Fire("OnClick"); assert(builderContext.window.frame:IsShown())
builder.HideWindow(); closeContext.discardCloseButton:Fire("OnClick"); assert(not builderContext.window.frame:IsShown())
-- Discard now clears the draft rather than only hiding the tool.
assert(not builder.HasUnsavedChanges())
Equal(builderContext.templateEdit:GetText(),"")
assert(builderContext.state.editingLayoutId==nil and builderContext.state.draftBaseline==nil)
NoErrors()

local warmCount
local callbacks={mediaContext.window.events.OnRelease,tagContext.window.events.OnRelease,builderContext.window.events.OnRelease}
for cycle=1,30 do
    OpenMedia(); CheckDirect(mediaContext.window,720,660)
    mediaContext.window.frame:Run("OnKeyDown","ESCAPE"); assert(not mediaContext.window.frame:IsShown())
    OpenTags(); CheckTags(tagContext)
    tagContext.window.closebutton:Run("OnClick"); assert(not tagContext.window.frame:IsShown())
    builder.OpenWindow(); Check(builderContext.window,1040,700)
    builderContext.window.closebutton:Run("OnClick"); assert(not builderContext.window.frame:IsShown())
    Equal({mediaContext.window.events.OnRelease,tagContext.window.events.OnRelease,builderContext.window.events.OnRelease},callbacks)
    if cycle==1 then warmCount=f.Count() else Equal(f.Count(),warmCount) end
end
NoErrors()
ace:Release(tagWindow)
for _,box in ipairs(boxes) do assert(not box:IsShown()) end
NineSliceUtil.GetLayout,NineSliceUtil.ApplyLayoutByName=nativeLayout,nativeApply
print("PASS: FP Tool structure/material/neutralization, 50 reset/size/reapply cycles, 30 pooling/tool-reopen cycles; real Media/Tag search/selection/preview/actions and TextBuilder template/edit/save/apply/dirty-close with U1 utility")
