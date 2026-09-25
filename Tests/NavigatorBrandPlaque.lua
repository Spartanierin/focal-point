-- lua54 Tests/NavigatorBrandPlaque.lua
-- Real Header form/table layout, section renderer, Toolbar and AceGUI pooling.
-- Native metrics are doubles: visual client acceptance remains mandatory.
local function Read(path)
    local f=assert(io.open(path)); local s=f:read("*a"); f:close(); return s
end
local env,ns,ace,native=assert(load(Read("Tests/PresentationPreview.lua")..
    "\nreturn env,ns,ace,native", "@Tests/PresentationPreview.lua"))()
local function Load(path) return assert(loadfile(path))("FocalPoint",ns) end
local function Equal(a,b)
    if a==b then return end
    if type(a)=="number" and type(b)=="number" then assert(math.abs(a-b)<1e-8, a.." ~= "..b)
    elseif type(a)=="table" and type(b)=="table" then
        for k,v in pairs(a) do Equal(v,b[k]) end
        for k in pairs(b) do assert(a[k]~=nil,"extra "..tostring(k)) end
    else error(tostring(a).." ~= "..tostring(b)) end
end
local function Copy(t)
    if type(t)~="table" then return t end
    local c={}; for k,v in pairs(t) do c[k]=Copy(v) end; return c
end
local function Upvalue(fn,name)
    for i=1,100 do local key,value=debug.getupvalue(fn,i)
        if key==name then return value end
        if not key then break end
    end
    error("Missing upvalue "..name)
end
local hooks,textures=0,0
function native:HookScript(event,fn)
    hooks=hooks+1; local previous=self.scripts[event]
    self:SetScript(event,function(frame,...) if previous then previous(frame,...) end; fn(frame,...) end)
end
for _,method in ipairs({"SetWidth","SetHeight"}) do
    local original=native[method]
    native[method]=function(self,value)
        local old=method=="SetWidth" and self.nativeWidth or self.nativeHeight
        original(self,value)
        if old~=value then self:Run("OnSizeChanged",self.nativeWidth,self.nativeHeight) end
    end
end
local createTexture=native.CreateTexture
function native:CreateTexture(name,layer,template,sublevel)
    textures=textures+1; local t=createTexture(self); t.drawLayer={layer,sublevel or 0}; return t
end
function native:GetStringHeight() return self:GetText()=="" and 1 or 14 end
function native:GetStringWidth() return #(self:GetText() or "")*7 end
function native:GetTexture() return self.lastSetTexture and self.lastSetTexture[1] end
function native:SetColorTexture(...) self.lastSetTexture=nil; self.lastSetColorTexture={...} end
function native:SetFontObject() self.font={STANDARD_TEXT_FONT,11,""} end
function native:SetFont(...) self.font={...}; return true end
Load("Libraries/Ace3/AceGUI-3.0/widgets/AceGUIWidget-Label.lua")
Load("GUI/Editor/Toolbar/ToolbarDefinition.lua")
Load("GUI/Editor/Toolbar/ToolbarBinding.lua")
local renderer=ns.GUI.Helpers.FormRenderer
local actualBuild=renderer.BuildLayout
-- Restrict the fixture to actual Root/Header/Options definitions. The only
-- omitted widgets are unrelated controls; real Brand/Version creation/refresh runs.
renderer.BuildLayout=function(host,definitions,options)
    local selected={}
    for _,definition in ipairs(definitions) do
        if definition.section=="Root" or definition.section=="Header" or definition.section=="Options" then
            selected[#selected+1]=definition
        end
    end
    return actualBuild(host,selected,{createItemWidget=function(...)
        local props=select(3,...)
        if props.widget=="label" then return options.createItemWidget(...) end
    end})
end
local actualCreate=ace.Create
ace.Create=function(self,kind)
    if kind~="Window" and kind~="ScrollFrame" then return actualCreate(self,kind) end
    local owner=actualCreate(self,"SimpleGroup")
    function owner:SetTitle() end
    function owner:EnableResize() end
    function owner:Show() self.frame:Show() end
    return owner
end
ns.GUI.Editor.SidebarGeometry={width=285,left=0,top=0}
Load("GUI/Editor/Toolbar/ToolbarController.lua")
local toolbar=ns.GUI.Editor.Toolbar
toolbar.Open({},{})
local context=Upvalue(toolbar.SetBrandPlaqueEnabled,"windowContext")
local header,following=context.groups.Header,context.groups.Options
local fill=header.frame._fpSectionFill
local function FrameSnapshot(frame)
    local points={}
    for k,p in pairs(frame.points) do points[k]={p.relative,p.relativePoint,p.x,p.y} end
    return {frame.nativeWidth,frame.nativeHeight,points,frame.parent}
end
local function Geometry()
    return {FrameSnapshot(header.frame),FrameSnapshot(header.content),FrameSnapshot(following.frame),
        FrameSnapshot(context.window.frame),FrameSnapshot(context.groups.Root.frame)}
end
local function Contents()
    local result={}
    for _,id in ipairs({"brandLine","versionLine"}) do
        local widget=context.widgets[id]
        result[id]={widget.label:GetText(),Copy(widget.label.font),Copy(widget.label.lastSetTextColor),
            Copy(widget.label.shadowOffset),FrameSnapshot(widget.frame),FrameSnapshot(widget.label)}
        assert(widget.frame:IsShown())
        Equal(widget.frame.parent,header.content)
    end
    return result
end
local chrome={"BorderTop","BorderBottom","BorderLeft","BorderRight","TopShade","BottomShade","Accent"}
local function Plaque()
    Equal(header.frame._fpSectionFill,fill)
    assert(fill:GetTexture():find("fp_navigator_brand_plaque.tga",1,true))
    Equal(fill.drawLayer,{"BACKGROUND",0}); Equal(fill.parent,header.frame)
    Equal(fill.lastSetVertexColor,{1,1,1,1})
    for _,key in ipairs(chrome) do assert(not header.frame["_fpSection"..key]:IsShown(),key) end
    local w,h=header.frame:GetWidth(),header.frame:GetHeight()
    local tl,br=fill.points.TOPLEFT,fill.points.BOTTOMRIGHT
    local fitW,fitH=w-tl.x+br.x,h+tl.y-br.y
    Equal(fitW/fitH,4); assert(fitW<=w+1e-8 and fitH<=h+1e-8)
    Equal(tl.x,-br.x); Equal(tl.y,-br.y)
end
local function Canonical(style)
    Equal(header.frame._fpSectionFill,fill); Equal(fill:GetTexture(),nil)
    Equal(fill.lastSetColorTexture,style.surface.fill)
    Equal(header.frame._fpSectionTopShade.lastSetColorTexture,style.surface.topShade)
    Equal(header.frame._fpSectionBottomShade.lastSetColorTexture,style.surface.bottomShade)
    Equal(header.frame._fpSectionAccent.lastSetColorTexture,style.surface.accent.color)
    for _,key in ipairs(chrome) do assert(header.frame["_fpSection"..key]:IsShown(),key) end
    Equal(header.frame._fpSectionBorderTop.lastSetColorTexture,style.border.color)
    Equal(fill.points.TOPLEFT.x,0); Equal(fill.points.TOPLEFT.y,0)
end
local styles=ns.GUI.Layouts.FormElements.SectionStyles
local baseline=Copy(styles.page_header)
Plaque()
local geometry,contents,count,hookCount=Geometry(),Contents(),textures,hooks
for i=1,25 do
    assert(toolbar.SetBrandPlaqueEnabled(false)); Canonical(styles.page_header)
    Equal(Geometry(),geometry); Equal(Contents(),contents)
    assert(toolbar.SetBrandPlaqueEnabled(true)); Plaque()
    toolbar.Hide(); toolbar.Open({},{})
    Equal(Geometry(),geometry); Equal(Contents(),contents); Plaque()
end
Equal(textures,count); Equal(hooks,hookCount); Equal(styles.page_header,baseline)
-- Live owner dimensions, including unusually tall/narrow content. Only texture
-- anchors change: no hard 245x66 assignment or auto-height interaction.
header.frame:ClearAllPoints() -- native parent-resize fixture, after real-layout invariance above
header:SetAutoAdjustHeight(false)
for _,size in ipairs({{245,66},{315,66},{245,110},{100,66}}) do
    header:SetWidth(size[1]); header:SetHeight(size[2]); local current=Geometry()
    Plaque(); Equal(Geometry(),current)
    assert(toolbar.SetBrandPlaqueEnabled(false)); Equal(Geometry(),current)
    assert(toolbar.SetBrandPlaqueEnabled(true)); Equal(Geometry(),current)
end
header:SetWidth(245); header:SetHeight(66)
Equal(fill.points.TOPLEFT.y,-2.375)
-- A fresh canonical style after binding must win over any old rendered colors.
styles.page_header.surface.fill={.11,.22,.33,.44}
styles.page_header.surface.topShade={.21,.32,.43,.54}
styles.page_header.surface.bottomShade={.31,.42,.53,.64}
styles.page_header.surface.accent.color={.41,.52,.63,.74}
styles.page_header.border.color={.51,.62,.73,.84}
assert(toolbar.SetBrandPlaqueEnabled(false)); Canonical(styles.page_header)
toolbar.Hide(); toolbar.Open({},{}) -- a reset stays reset through reopen
Canonical(styles.page_header)
assert(toolbar.SetBrandPlaqueEnabled(true)); Plaque()
local previousCombat=InCombatLockdown
InCombatLockdown=function() return true end
local ok,reason=toolbar.SetBrandPlaqueEnabled(false); Equal(ok,false); Equal(reason,"combat"); Plaque()
InCombatLockdown=previousCombat
local bind=Upvalue(Upvalue(Upvalue(toolbar.Open,"CreateWindow"),"CreateWindowContent"),"EnsureToolbarBrandBinding")
local released=0
for cycle=1,25 do
    local group=ace:Create("SimpleGroup"); group:SetAutoAdjustHeight(false); group:SetWidth(245); group:SetHeight(66)
    group:SetCallback("OnRelease",function() released=released+1 end)
    bind(group); local region=group.frame._fpSectionFill
    ace:Release(group)
    Equal(region:GetTexture(),nil); Equal(region.lastSetColorTexture,styles.page_header.surface.fill)
    Equal(group:GetUserData("fpNavigatorBrandPlaque"),nil)
    local reused=ace:Create("SimpleGroup"); Equal(reused,group)
    reused:SetWidth(300); reused:SetHeight(80) -- size hook must be inert in another consumer
    Equal(region:GetTexture(),nil)
    ns.GUI.Helpers.FormSectionSurfaceRenderer.ApplySectionSurface(reused,styles.page_header)
    Equal(region.lastSetColorTexture,styles.page_header.surface.fill)
    ace:Release(reused)
end
Equal(released,25)
styles.page_header=baseline
ace.Create,renderer.BuildLayout=actualCreate,actualBuild
assert(#env.errors==0,table.concat(env.errors,"\n"))
print("PASS: Brand sole fill, aspect fit/resize, real Header layout and content invariance, fresh reset, 25 reopen/release cycles")
