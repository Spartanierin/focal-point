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
ns.UnitFrameUtils={GetUnitDB=function() return {present=true} end}
Load("GUI/Editor/CanvasToolbar.lua")
local ensureHost=Upvalue(ns.GUI.Editor.CanvasToolbar.UpdateGeometry,"EnsureHost")
local openAddObject=ns.GUI.Editor.CanvasToolbar.OpenEntityAddObjectPicker
openAddObject()
local add=createdDialogs[#createdDialogs].dialog
Check(add); Equal(add.window.frame:GetWidth(),420)
local addHeight=add.window.frame:GetHeight(); assert(addHeight>=193 and addHeight<=560)
CheckContent(add,{Bars=true,Content=true})
assert(add.body.children[3].type=="ScrollFrame")
assert(add.cancelButton.parent==add.body.children[4])
add.cancelButton:Fire("OnClick"); assert(not add.window.frame:IsShown())
assert(add.released and #add.body.children==0)
openAddObject(); local recreated=createdDialogs[#createdDialogs].dialog
assert(recreated~=add); Check(recreated); Equal(recreated.window.frame:GetHeight(),addHeight)
CheckContent(recreated,{Bars=true,Content=true})
-- Options and Confirmations now consume the same dialog presentation as W1.
Load("GUI/Editor/EditorOptionsDialog.lua")
ns.GUI.Editor.OptionsDialog.Open()
local options=createdDialogs[#createdDialogs].dialog
Equal({options.window.frame:GetWidth(),options.window.frame:GetHeight()},{360,349})
local confirm=widgets.CreateCompactConfirmation({title="Confirm",message="Unchanged",primary={text="OK"},cancel={text="Cancel"}})
for _,other in ipairs({options,confirm}) do
    Check(other)
end
widgets.CreateCompactFormDialog=createDialog
assert(#env.errors==0,table.concat(env.errors,"\n"))
print("PASS: unchanged W1/W2 consumers, shared Options/Confirmation chrome, Window geometry/title/X, idempotence, recreate/reopen/pooling and Modern/Navigator isolation")
return {ns=ns,ace=ace,native=native,Equal=Equal,Count=Count,Load=Load,Upvalue=Upvalue,
    Check=Check,Geometry=Geometry,widgets=widgets,options=options,manager=manager,env=env}
