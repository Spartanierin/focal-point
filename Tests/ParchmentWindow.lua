-- lua54 Tests/ParchmentWindow.lua [optional Blizzard NineSlice.lua]
-- Real AceGUI Window, Compact Dialog and consumers; native rendering is simulated.
local f = assert(io.open("Tests/NavigatorBrassWindow.lua")); local source = f:read("*a"); f:close()
local boundary = assert(source:find("local oldCreate = ace.Create", 1, true))
local env, ns, ace, native, Equal, Count = assert(load(source:sub(1, boundary - 1)
    .. "\nreturn env,ns,ace,native,Equal,function() return created end", "@Parchment/NativeFixture"))()
local function Load(path) return assert(loadfile(path))("FocalPoint", ns) end
local function Upvalue(fn, name)
    for i = 1, 100 do
        local key, value = debug.getupvalue(fn, i)
        if key == name then return value end
        if not key then break end
    end
    error("missing upvalue " .. name)
end
local point = native.SetPoint
function native:SetPoint(p, relative, rp, x, y)
    if type(relative) == "number" then x,y,relative,rp=relative,rp,self.parent,p
    elseif type(rp) == "number" then x,y,rp=rp,x,p
    elseif not relative then relative,rp=self.parent,p end
    return point(self,p,relative,rp or p,x,y)
end
function native:GetNumPoints() local n=0; for _ in pairs(self.points) do n=n+1 end; return n end
function native:GetPoint(index)
    local n=0; for p,v in pairs(self.points) do n=n+1; if n==index then return p,v.relative,v.relativePoint,v.x,v.y end end
end
function native:GetObjectType() return self.kind end
local texture = native.CreateTexture
function native:CreateTexture(name, layer, template, sublevel)
    local region = texture(self); self.regions=self.regions or {}; self.regions[#self.regions+1]=region
    region:SetDrawLayer(layer or "ARTWORK", sublevel or 0); return region
end
function native:GetRegions() return table.unpack(self.regions or {}) end
function native:GetDrawLayer() return table.unpack(self.lastSetDrawLayer or {"ARTWORK",0}) end
function native:GetVertexColor() return table.unpack(self.lastSetVertexColor or {1,1,1,1}) end
function native:GetTextColor() return table.unpack(self.lastSetTextColor or {1,1,1,1}) end
function native:SetColorTexture(...) self.lastSetColorTexture={...}; self.lastSetTexture=nil end
function native:SetFontObject() self.font={STANDARD_TEXT_FONT,12,""} end
function native:GetFont() return table.unpack(self.font or {STANDARD_TEXT_FONT,12,""}) end
function native:SetFont(...) self.font={...}; return true end
function native:GetStringHeight() return self:GetText()=="" and 1 or 14 end
function native:GetStringWidth() return #(self:GetText() or "")*7 end
local width=native.GetWidth
function native:GetWidth() return width(self) or 0 end
function native:GetHeight() return self.nativeHeight or 0 end
function native:GetFontString() if not self.fontString then self.fontString=self:CreateFontString() end; return self.fontString end
function native:GetScript(event) return self.scripts[event] end
-- Native UIPanelScrollBarTemplate supplies these regions/buttons in the client;
-- Lua-only CreateFrame cannot materialize XML, so model only that existing boundary.
local createFrame=CreateFrame
function CreateFrame(kind,name,parent,template)
    local frame=createFrame(kind,name,parent,template)
    if template=="UIPanelScrollBarTemplate" then
        function frame:GetName() return name end
        frame:SetThumbTexture("native-scroll-thumb")
        frame.thumb:SetTexture("native-scroll-thumb");frame.thumb:SetSize(16,24);frame.thumb:SetAlpha(.85)
        local original={{frame.thumb,.85}}
        for _,key in ipairs({"ScrollUpButton","ScrollDownButton"}) do
            local button=createFrame("Button",nil,frame)
            frame[key]=button
            local texture=button:CreateTexture();texture:SetTexture(key);texture:SetAlpha(.75)
            original[#original+1]={texture,.75}
        end
        local scripts={}
        for _,event in ipairs({"OnEnter","OnLeave","OnMouseDown","OnMouseUp","OnHide"}) do
            local fn=function(self) self.nativeEvents=self.nativeEvents or {};self.nativeEvents[event]=(self.nativeEvents[event] or 0)+1 end
            frame:SetScript(event,fn);scripts[event]=fn
        end
        frame._testNativeScrollbar={original=original,scripts=scripts}
    end
    return frame
end
function native:HookScript(event, callback)
    local previous=self.scripts[event]
    self:SetScript(event,function(owner,...) if previous then previous(owner,...) end; callback(owner,...) end)
end
function native:SetShown(shown) if shown then self:Show() else self:Hide() end end
for _,method in ipairs({"SetMovable","SetResizable","SetResizeBounds","SetPropagateKeyboardInput",
    "SetShadowOffset","SetShadowColor","SetMaxLines","SetScrollChild","SetVerticalScroll","SetButtonState",
    "Enable","Disable","StartMoving","StopMovingOrSizing","StartSizing","SetDesaturated"}) do
    native[method]=function(self,...) self["last"..method]={...} end
end
GameFontNormal={}; GameFontHighlight={}
function PlaySound() end
Load("GUI/Helpers/TextStyles.lua")
Load("GUI/Layouts/FormElementDefinition.lua")
for _,file in ipairs({"AceGUIContainer-Window","AceGUIContainer-ScrollFrame","AceGUIWidget-Label",
    "AceGUIWidget-Button","AceGUIWidget-CheckBox"}) do Load("Libraries/Ace3/AceGUI-3.0/widgets/"..file..".lua") end
local widgets=ns.GUI.Helpers.FormWidgets
local function CheckContent(dialog, headings)
    local description=dialog.body.children[1].label
    Equal(description.lastSetTextColor,{0.70,0.68,0.62,1})
    Equal(description.font,{STANDARD_TEXT_FONT,11,""})
    Equal(description.lastSetShadowOffset,{1,-1})
    local found={}
    local function Visit(widget)
        if widget.label and headings[widget.label:GetText()] then
            found[widget.label:GetText()]=true
            Equal(widget.label.lastSetTextColor,{0.910,0.757,0.400,1})
            Equal(widget.label.font,{STANDARD_TEXT_FONT,12,""})
            Equal(widget.label.lastSetShadowOffset,{1,-1})
        end
        for _,child in ipairs(widget.children or {}) do Visit(child) end
    end
    Visit(dialog.body)
    Equal(found,headings)
end
local skin=ns.GUI.Skins.GetActiveSkin()
local styles=ns.GUI.Helpers.TextStyles
for _,role in ipairs({"parchmentSectionHeader","parchmentSecondary"}) do
    Equal(styles.TextColors[role],skin.textColors[role])
end
Equal({skin.textColors.parchmentSecondary.r,skin.textColors.parchmentSecondary.g,
    skin.textColors.parchmentSecondary.b,1},skin.visual.TextSecondary)
Equal(skin.textColors.parchmentSectionHeader,skin.textColors.sectionHeader)
Equal(skin.textColors.help,{hex="B8AD95",wow="|cffB8AD95",r=0.722,g=0.678,b=0.584})
Equal(skin.textColors.parchmentMuted,{hex="7A613D",wow="|cff7A613D",r=0.48,g=0.38,b=0.24})
local function Points(region)
    local result={}; for p,v in pairs(region.points) do result[p]={v.relative,v.relativePoint,v.x,v.y} end; return result
end
local function Geometry(window)
    return {window.frame.nativeWidth,window.frame.nativeHeight,Points(window.content),
        Points(window.titletext),Points(window.title),Points(window.closebutton),
        window.content.nativeWidth,window.content.nativeHeight,window.sizer_se:IsShown()}
end
local material=ns.GUI.Skins.GetFormPalette().CompactDialogContent.parchment
local metal=ns.MediaRegistry.ResolveReference("fp:texture:fp-forged-metal-128x128","texture")
assert(metal.available and not metal.fallbackUsed)
Equal(material.tint,{0.40,0.40,0.40,0.96}); Equal(material.headerTint,{0.16,0.16,0.16,1})
local function Check(dialog)
    local w=dialog.window; local frame=w.frame; local border=assert(frame._fpParchmentNineSlice)
    assert(border:IsShown()); assert(not w._fpNavigatorBrassTarget)
    Equal(border.TopLeftCorner.nativeWidth,28); Equal(border.TopEdge.nativeHeight,28)
    Equal(border.TopRightCorner.lastSetTexCoord,{1,0,0,1})
    Equal(border.BottomEdge.lastSetTexCoord,{0,1,1,0})
    Equal(border.lastSetAllPoints,{frame}); Equal(border:GetFrameLevel(),frame:GetFrameLevel()+3)
    for _,key in ipairs({"_fpPanelFill","_fpPanelHeaderFill"}) do
        Equal(frame[key]:GetTexture(),metal.resolvedAsset)
        Equal(frame[key].lastSetVertexColor,key=="_fpPanelHeaderFill" and material.headerTint or material.tint)
        Equal(frame[key].lastSetHorizTile,{false}); Equal(frame[key].lastSetVertTile,{false})
    end
    Equal(dialog.shell.frame._fpCompactDialogWindowContentSurface:GetTexture(),metal.resolvedAsset)
    Equal(dialog.shell.frame._fpCompactDialogWindowContentSurface.lastSetVertexColor,material.tint)
    for _,suffix in ipairs({"BorderTop","BorderBottom","BorderLeft","BorderRight",
        "InnerTop","InnerBottom","InnerLeft","InnerRight","TopShade","BottomShade"}) do
        assert(not frame["_fpPanel"..suffix]:IsShown(),suffix)
    end
    assert(frame._fpPanelHeaderSeparator:IsShown()); Equal(frame._fpPanelHeaderFill:GetHeight(),24)
    Equal(w.titletext.font,{STANDARD_TEXT_FONT,15,""})
    Equal(w.titletext.lastSetTextColor,{0.910,0.757,0.400,1})
    Equal(w.titletext.lastSetShadowOffset,{1,-1})
    assert(w.titletext:GetParent()==w.title and w.title:GetFrameLevel()>border:GetFrameLevel())
    assert(w.closebutton:GetFrameLevel()>border:GetFrameLevel())
    Equal(w.content.points.TOPLEFT.x,12); Equal(w.content.points.TOPLEFT.y,-32)
    Equal(w.content.points.BOTTOMRIGHT.x,-12); Equal(w.content.points.BOTTOMRIGHT.y,13)
    Equal(w.closebutton.points.TOPRIGHT.x,2); Equal(w.closebutton.points.TOPRIGHT.y,1)
    assert(not w.sizer_se:IsShown()); Equal(border.Center,nil)
end
local plain=widgets.CreateCompactFormDialog({title="Control",width=560,height=521,dialogPresentation=false})
local dialog=widgets.CreateCompactFormDialog({title="Parchment",width=560,height=521,contentSurface="parchment"})
Check(dialog)
-- Compare numeric geometry; native region identities naturally differ.
for _,key in ipairs({"content","titletext","title","closebutton"}) do
    for p,v in pairs(plain.window[key].points) do
        local actual=dialog.window[key].points[p]; Equal({actual.relativePoint,actual.x,actual.y},{v.relativePoint,v.x,v.y})
    end
end
Equal(dialog.window.content.nativeWidth,526); Equal(dialog.window.content.nativeHeight,464)
local geometry=Geometry(dialog.window); local callback=dialog.window.events.OnRelease; local count=Count()
for _=1,5 do dialog:Close(); dialog:Show(); Check(dialog); Equal(Geometry(dialog.window),geometry) end
Equal(Count(),count); Equal(dialog.window.events.OnRelease,callback)
-- Real pooled Window transitions, including the actual Modern presentation.
local previous=dialog.window; local titleLevel,closeLevel=plain.window.title:GetFrameLevel(),plain.window.closebutton:GetFrameLevel()
ace:Release(previous)
assert(not previous.frame._fpParchmentNineSlice:IsShown()); Equal(previous.frame._fpCompactFormShell,nil)
Equal(previous.titletext:GetParent(),previous.frame); Equal(previous.title:GetFrameLevel(),titleLevel)
Equal(previous.closebutton:GetFrameLevel(),closeLevel)
local pooled=widgets.CreateCompactFormDialog({title="Other",width=360,formContentHeight=286,dialogPresentation=false})
Equal(pooled.window,previous); assert(not previous.frame._fpParchmentNineSlice:IsShown())
assert(previous.frame._fpPanelBorderTop:IsShown()); Equal(previous.frame._fpPanelFill:GetTexture(),nil)
Equal(previous.frame._fpPanelFill.lastSetVertexColor,{1,1,1,1})
Equal(previous.frame._fpPanelFill.lastSetColorTexture,ns.GUI.Skins.GetFormPalette().Chrome.panelBackground)
Equal(previous.frame:GetHeight(),349)
ace:Release(previous)
local modern=ace:Create("Window"); Equal(modern,previous)
widgets.ApplyModernWindowChrome(modern,{nineSlice=true,portrait=true,portraitTexture="portrait.png"})
assert(modern.frame._fpModernNineSlice:IsShown() and not modern.frame._fpParchmentNineSlice:IsShown())
Equal(modern.frame._fpModernNineSlice.testLayoutName,"PortraitFrameTemplate")
assert(not modern.frame._fpPanelFill:IsShown())
ace:Release(modern)
local again=widgets.CreateCompactFormDialog({title="Again",width=420,height=300,contentSurface="parchment"})
Check(again)
assert(not again.window.frame._fpModernNineSlice:IsShown(),"Modern border leaked into Parchment")
assert(not again.window.frame._fpModernPortraitBackground:IsShown(),"Modern rock leaked into Parchment")
local parchment=ns.MediaRegistry.ResolveReference("fp:texture:parchment","texture")
assert(parchment.resolvedAsset:find("fp_window_background.jpg",1,true))
Equal(widgets.ResolveSectionStyle("toolbar_explorer_inset").surface.textureId,"fp:texture:parchment")
-- Exercise actual consumer creation; observe options/results without replacing
-- the Compact Dialog factory, Window owner, content builders or callbacks.
local createdDialogs={}
local createDialog=widgets.CreateCompactFormDialog
widgets.CreateCompactFormDialog=function(options)
    local result=createDialog(options)
    createdDialogs[#createdDialogs+1]={dialog=result,options=options}
    return result
end
ns.L={}; ns.db={char={activeLayoutId="layout:one"},profile={General={}}}
ns.LayoutService={ListLayoutSummaries=function() return {
    {id="layout:one",name="One",source="userLayout"},
    {id="builtin:default",name="Default",source="builtin"},
} end}
Load("GUI/Editor/LayoutManager/LayoutManagerView.lua")
ns.GUI.Editor.LayoutManager.Open()
local manager=createdDialogs[#createdDialogs].dialog
Check(manager); Equal({manager.window.frame:GetWidth(),manager.window.frame:GetHeight()},{560,521})
CheckContent(manager,{["My Layouts"]=true,["Built-in Layouts"]=true})
local managerGeometry=Geometry(manager.window)
ns.GUI.Editor.LayoutManager.Close(); ns.GUI.Editor.LayoutManager.Open()
Equal(Geometry(manager.window),managerGeometry); Check(manager)
CheckContent(manager,{["My Layouts"]=true,["Built-in Layouts"]=true})
-- The real Add Object entry point is a closure of the actual toolbar builder.
ns.GUI.Editor.State={GetPrimaryUnit=function() return "player" end}
local unitConfigs={player={present=true},pet={present=false}}
ns.UnitFrameUtils={GetUnitDB=function(key) return unitConfigs[key] end}
local unitRoot={units=unitConfigs}
ns.ActiveLayoutResolver={GetActiveRuntimeRoot=function() return unitRoot end}
ns.GUI.Editor.Composition=ns.GUI.Editor.Composition or {}
Load("GUI/Widgets/SelectionRow.lua")
Load("GUI/Editor/CanvasToolbar.lua")
local ensureHost=Upvalue(ns.GUI.Editor.CanvasToolbar.UpdateGeometry,"EnsureHost")
local openAddObject=ns.GUI.Editor.CanvasToolbar.OpenEntityAddObjectPicker
local editAtlases={Left="UI-Frame-DiamondMetal-CornerTopLeft",Right="UI-Frame-DiamondMetal-CornerTopRight",
    BottomLeft="UI-Frame-DiamondMetal-CornerBottomLeft",BottomRight="UI-Frame-DiamondMetal-CornerBottomRight",
    Center="_UI-Frame-DiamondMetal-EdgeTop",BottomCenter="_UI-Frame-DiamondMetal-EdgeBottom",
    SideLeft="!UI-Frame-DiamondMetal-EdgeLeft",SideRight="!UI-Frame-DiamondMetal-EdgeRight"}
local previousAtlas=C_Texture
C_Texture={GetAtlasInfo=function() return {width=32,height=32} end}
local function CheckEditorPanel(dialog, mode)
    mode=mode or "editmode"
    local frame=dialog.window.frame
    assert(dialog.window._focalPointEditorRole~="editor_inspector")
    assert(not frame._fpParchmentNineSlice or not frame._fpParchmentNineSlice:IsShown())
    assert(not frame._fpModernNineSlice or not frame._fpModernNineSlice:IsShown())
    assert(not frame._fpPanelFill:IsShown() and not frame._fpPanelHeaderFill:IsShown())
    assert(not frame._fpPanelHeaderSeparator:IsShown())
    for slot,atlas in pairs(editAtlases) do
        local region=frame["_fpModernTitle"..slot]
        if mode=="flat" then assert(not region or not region:IsShown())
        else
            assert(region and region:IsShown())
            if mode=="editmode" then Equal(region.atlas,atlas);Equal({region:GetDrawLayer()},{"BORDER",0}) end
        end
    end
    if mode=="editmode" then
        for _,corner in ipairs({{"Left","TOPLEFT"},{"Right","TOPRIGHT"},{"BottomLeft","BOTTOMLEFT"},{"BottomRight","BOTTOMRIGHT"}}) do
            local point=frame["_fpModernTitle"..corner[1]].points[corner[2]]
            assert(point.relative==frame and point.relativePoint==corner[2]);Equal({point.x,point.y},{0,0})
        end
    elseif mode=="metal" then
        Equal(frame._fpModernTitleLeft.atlas,"UI-Frame-PortraitMetal-CornerTopLeft")
    end
    assert(frame._fpPanelBorderTop:IsShown()==(mode=="flat"))
    local background=assert(frame._fpModernPortraitBackground)
    assert(background:IsShown());Equal(background:GetTexture(),nil)
    Equal(background.lastSetColorTexture,{0,0,0,.8})
    Equal({background:GetDrawLayer()},{"BACKGROUND",-5})
    Equal({background.points.TOPLEFT.x,background.points.TOPLEFT.y,background.points.BOTTOMRIGHT.x,background.points.BOTTOMRIGHT.y},{7,-7,-7,7})
    assert(not frame._fpModernPortraitTopTileStreaks or not frame._fpModernPortraitTopTileStreaks:IsShown())
    local surface=dialog.shell.frame._fpCompactDialogWindowContentSurface
    assert(not surface or not surface:IsShown())
    local content=dialog.body.frame:GetParent()
    Equal(content._fpCompactDialogBodyFill:GetTexture(),nil)
    for _,suffix in ipairs({"Fill","BorderTop","TopShade","BottomShade"}) do
        Equal(content["_fpCompactDialogBody"..suffix].lastSetColorTexture,{0,0,0,0})
    end
    Equal(dialog.window.titletext.font,{STANDARD_TEXT_FONT,17,""})
    Equal(dialog.window.titletext.lastSetTextColor,{1,1,1,1})
    Equal(dialog.window.titletext.lastSetJustifyH,{"CENTER"})
    local description=dialog.body.children[1].label
    local color=styles.Get("help")
    Equal(description.lastSetTextColor,{color.r,color.g,color.b,1})
    Equal(description.font,{STANDARD_TEXT_FONT,13,""})
    Equal(dialog.body.children[2].frame:GetHeight(),8)
    local heading=dialog.body.children[3].children[1].label
    Equal(heading:GetText(),"Unit Frames")
    color=NORMAL_FONT_COLOR or styles.Get("strongHeading")
    Equal(heading.lastSetTextColor,{color.r,color.g,color.b})
    Equal(heading.font,{STANDARD_TEXT_FONT,16,""})
    for _,key in ipairs({"content","titletext","closebutton"}) do
        for point,value in pairs(plain.window[key].points) do
            local actual=dialog.window[key].points[point]
            if key=="titletext" then assert(actual.relative==dialog.window.frame) end
            Equal({actual.relativePoint,actual.x,actual.y},{value.relativePoint,value.x,value.y+(key=="titletext" and -3 or 0)})
        end
    end
    local drag=dialog.window.title
    Equal(drag:GetNumPoints(),2)
    local left,right=drag.points.TOPLEFT,drag.points.BOTTOMRIGHT
    assert(left.relative==frame and right.relative==frame)
    Equal({left.relativePoint,left.x,left.y,right.relativePoint,right.x,right.y},{"TOPLEFT",8,0,"TOPRIGHT",-math.max(36,dialog.window.closebutton:GetWidth()+4),-32})
    local dragRight=frame:GetWidth()+right.x
    for _,x in ipairs({left.x+1,(left.x+dragRight)/2,dragRight-1}) do
        assert(x>=left.x and x<=dragRight)
    end
    -- Content begins below the 32px hitbox; the native X stays entirely to its right.
    local contentTop=dialog.window.content.points.TOPLEFT.y+dialog.body.frame.points.TOPLEFT.y
    assert(right.y>contentTop)
    local close=dialog.window.closebutton
    local closeLeft=frame:GetWidth()+close.points.TOPRIGHT.x-close:GetWidth()
    assert(dragRight<closeLeft)
    assert(not dialog.window.sizer_se:IsShown())
end
openAddObject()
local add=createdDialogs[#createdDialogs].dialog
local addOptions=createdDialogs[#createdDialogs].options
assert(addOptions.windowChrome=="editmode" and addOptions.contentSurface==nil)
Equal({addOptions.titleFontSize,addOptions.titleOffsetY},{17,-3})
Equal(addOptions.headerDrag,{left=8,right=36,top=0,height=32})
assert(addOptions.bodyFill==nil and addOptions.bodyBorder==nil)
CheckEditorPanel(add); Equal(add.window.frame:GetWidth(),420)
local addHeight=add.window.frame:GetHeight(); assert(addHeight>=157 and addHeight<=560)
assert(add.body.children[3].type=="ScrollFrame")
assert(add.cancelButton==nil and #add.body.children==3)
add.window.closebutton:Run("OnClick"); assert(not add.window.frame:IsShown())
assert(add.released and #add.body.children==0)
assert(not add.window:GetUserData("fpCustomizeBlizzardShell"))
assert(not add.window.frame._fpModernPortraitBackground:IsShown())
for slot in pairs(editAtlases) do assert(not add.window.frame["_fpModernTitle"..slot]:IsShown()) end
openAddObject(); local recreated=createdDialogs[#createdDialogs].dialog
assert(recreated~=add); CheckEditorPanel(recreated); Equal(recreated.window.frame:GetHeight(),addHeight)
local geometry=Geometry(recreated.window)
local mouseDown,mouseUp=recreated.window.title:GetScript("OnMouseDown"),recreated.window.title:GetScript("OnMouseUp")
local close=recreated.window.closebutton:GetScript("OnClick")
for _=1,10 do recreated:Show();CheckEditorPanel(recreated);Equal(Geometry(recreated.window),geometry) end
assert(recreated.window.title:GetScript("OnMouseDown")==mouseDown and recreated.window.title:GetScript("OnMouseUp")==mouseUp)
assert(recreated.window.closebutton:GetScript("OnClick")==close)
-- Same availability checks as Customize: missing/invalid Edit Mode -> metal -> flat.
for _,scenario in ipairs({"missing","invalid","throw","absent"}) do
    if scenario=="absent" then C_Texture=nil
    else C_Texture={GetAtlasInfo=function(name)
        if name:find("DiamondMetal",1,true) then
            if scenario=="throw" then error("atlas unavailable") end
            return scenario=="invalid" and {width=0,height=32} or nil
        end
        return {width=32,height=32}
    end} end
    recreated:Show();CheckEditorPanel(recreated,scenario=="absent" and "flat" or "metal")
    Equal(Geometry(recreated.window),geometry)
end
C_Texture={GetAtlasInfo=function() return {width=32,height=32} end}
recreated:Show();CheckEditorPanel(recreated)
recreated.window.frame:Run("OnKeyDown","ESCAPE")
assert(recreated.released and not recreated.window:GetUserData("fpCustomizeBlizzardShell"))
-- Observe the real factory acquisition to verify exact title restoration, without
-- assuming which pooled Window is returned or introducing an alternate shell.
local acquire=ace.Create
local titleBefore
ace.Create=function(self,kind,...)
    local owner=acquire(self,kind,...)
    if kind=="Window" then
        titleBefore={owner=owner,font={owner.titletext:GetFont()},color={owner.titletext:GetTextColor()},layer={owner.titletext:GetDrawLayer()},points=Points(owner.titletext),dragPoints=Points(owner.title),dragWidth=owner.title:GetWidth(),dragHeight=owner.title:GetHeight(),mouseDown=owner.title:GetScript("OnMouseDown"),mouseUp=owner.title:GetScript("OnMouseUp")}
    end
    return owner
end
for cycle=1,12 do
    openAddObject();local current=createdDialogs[#createdDialogs].dialog
    CheckEditorPanel(current)
    local before=titleBefore;assert(before.owner==current.window)
    assert(current.window.title:GetScript("OnMouseDown")==before.mouseDown and current.window.title:GetScript("OnMouseUp")==before.mouseUp)
    -- Dispatch through the real, unchanged AceGUI drag endpoints for all header zones.
    for _,zone in ipairs({"left","middle","right"}) do
        current.window.frame.lastStartMoving,current.window.frame.lastStopMovingOrSizing=nil,nil
        current.window.title:Run("OnMouseDown","LeftButton")
        assert(current.window.frame.lastStartMoving,"drag start missing: "..zone)
        current.window.title:Run("OnMouseUp","LeftButton")
        assert(current.window.frame.lastStopMovingOrSizing,"drag stop missing: "..zone)
    end
    local liveGeometry=Geometry(current.window)
    current:Show();CheckEditorPanel(current);Equal(Geometry(current.window),liveGeometry)
    assert(current.cancelButton==nil and #current.body.children==3)
    if cycle%2==0 then current.window.closebutton:Run("OnClick")
    else current.window.frame:Run("OnKeyDown","ESCAPE") end
    assert(current.released and #current.body.children==0)
    assert(not current.window:GetUserData("fpCustomizeBlizzardShell"))
    assert(not current.window.frame._fpModernPortraitBackground:IsShown())
    for slot in pairs(editAtlases) do assert(not current.window.frame["_fpModernTitle"..slot]:IsShown()) end
    Equal({current.window.titletext:GetFont()},before.font)
    Equal({current.window.titletext:GetTextColor()},before.color)
    Equal({current.window.titletext:GetDrawLayer()},before.layer)
    local restored=Points(current.window.titletext)
    for point,value in pairs(before.points) do
        assert(restored[point][1]==value[1]);Equal({restored[point][2],restored[point][3],restored[point][4]},{value[2],value[3],value[4]})
    end
    for point in pairs(restored) do assert(before.points[point]) end
    Equal({current.window.title:GetWidth(),current.window.title:GetHeight()},{before.dragWidth,before.dragHeight})
    restored=Points(current.window.title)
    for point,value in pairs(before.dragPoints) do
        assert(restored[point][1]==value[1]);Equal({restored[point][2],restored[point][3],restored[point][4]},{value[2],value[3],value[4]})
    end
    for point in pairs(restored) do assert(before.dragPoints[point]) end
end
ace.Create=acquire
-- Reacquiring a standard dialog must not inherit opt-in artwork or white title text.
local standard=widgets.CreateCompactFormDialog({title="Default after Edit Mode",width=420,height=300})
Check(standard)
for slot in pairs(editAtlases) do
    local region=standard.window.frame["_fpModernTitle"..slot];assert(not region or not region:IsShown())
end
assert(not standard.window:GetUserData("fpCustomizeBlizzardShell"))
ace:Release(standard.window)
local defaultEdit=widgets.CreateCompactFormDialog({title="Unmodified Edit Mode defaults",width=420,height=300,windowChrome="editmode"})
Equal(defaultEdit.window.titletext.font,{STANDARD_TEXT_FONT,18,""})
for point,value in pairs(plain.window.title.points) do
    local actual=defaultEdit.window.title.points[point]
    Equal({actual.relativePoint,actual.x,actual.y},{value.relativePoint,value.x,value.y})
end
for point,value in pairs(plain.window.titletext.points) do
    local actual=defaultEdit.window.titletext.points[point]
    assert(actual.relative==defaultEdit.window.frame)
    Equal({actual.relativePoint,actual.x,actual.y},{value.relativePoint,value.x,value.y})
end
ace:Release(defaultEdit.window)
C_Texture=previousAtlas
-- Options and Confirmations now consume the same dialog presentation as W1.
Load("GUI/Editor/EditorOptionsDialog.lua")
ns.GUI.Editor.OptionsDialog.Open()
local options=createdDialogs[#createdDialogs].dialog
Equal({options.window.frame:GetWidth(),options.window.frame:GetHeight()},{360,373})
local confirm=widgets.CreateCompactConfirmation({title="Confirm",message="Unchanged",primary={text="OK"},cancel={text="Cancel"}})
for _,other in ipairs({options,confirm}) do
    Check(other)
end
widgets.CreateCompactFormDialog=createDialog
assert(#env.errors==0,table.concat(env.errors,"\n"))
print("PASS: unchanged W1/W2 consumers, shared Options/Confirmation chrome, Window geometry/title/X, idempotence, recreate/reopen/pooling and Modern/Navigator isolation")
print("PASS: opt-in Edit Mode atlas shell, transparent body, native geometry/drag/X, metal/flat fallback, 12 X/Escape release cycles and exact title restore")
return {ns=ns,ace=ace,native=native,Equal=Equal,Count=Count,Load=Load,Upvalue=Upvalue,
    Check=Check,Geometry=Geometry,widgets=widgets,options=options,manager=manager,env=env}
