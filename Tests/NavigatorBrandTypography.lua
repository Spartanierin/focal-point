-- lua54 Tests/NavigatorBrandTypography.lua
-- Reuse B1's actual Header/Table/Toolbar setup, with real media registration and
-- variable native font metrics. No product constructor or binding is duplicated.
local function Read(path) local f=assert(io.open(path)); local s=f:read("*a"); f:close(); return s end
local source=Read("Tests/NavigatorBrandPlaque.lua")
local boundary=assert(source:find("local geometry,contents,count,hookCount",1,true))
source=source:sub(1,boundary-1)
-- Some Header fills were pooled before B1's draw-layer instrumentation started;
-- layering itself is covered by the standalone, unchanged B1 regression test.
source=source:gsub('Equal%(fill.drawLayer,{"BACKGROUND",0}%); ', '')
local marker="local function Equal(a,b)"
local at=assert(source:find(marker,1,true))
source=source:sub(1,at-1)..[[
function native:SetClipsChildren(value) self.clipsChildren=value end
function native:SetMaxLines(value) self.maxLines=value end
Load("Media/Decorations/DecorationManifest.lua")
Load("Media/Textures/GUI/GUITextureManifest.lua")
Load("Services/MediaRegistry.lua")
ns.db={profile={General={}}}
]]..source:sub(at)
source=source:gsub('function native:GetStringHeight%(%) return self:GetText%(%)=="" and 1 or 14 end',[[
function native:GetStringHeight()
    if self:GetText()=="" then return 1 end
    if self:GetText():find("|T",1,true) then return 34 end
    return (self.font and self.font[2] or 11)*1.25
end]])
local env,ns,ace,native,toolbar,context,geometry,contents,plaque,equal,copy,upvalue=
    assert(load(source.."\nreturn env,ns,ace,native,toolbar,context,Geometry,Contents,Plaque,Equal,Copy,Upvalue",
        "@BrandTypography/HeaderFixture"))()
local api=ns.Ace.PresentationPreview
local brand,version=context.widgets.brandLine,context.widgets.versionLine
local target="sidebar_brand"
local baselineGeometry=geometry()
local baselineVersion=contents().versionLine
local baselinePlaque={copy(context.groups.Header.frame._fpSectionFill.lastSetTexCoord),
    context.groups.Header.frame._fpSectionFill:GetTexture()}
local labels={api.GetTypographyPresentation("sidebar_label"),api.GetTypographyPresentation("inspector_label"),
    api.GetTypographyPresentation("sidebar_section_heading"),api.GetTypographyPresentation("inspector_section_heading")}
local targets={}; for _,t in ipairs(api.GetTypographyTargets()) do targets[t.id]=t end
equal(targets[target].area,"Sidebar"); equal(targets[target].label,"Brand")
equal(targets[target].properties,{"font","size","flags","color","alpha","shadowEnabled"})
targets[target].properties[1]="bad"; equal(api.GetTypographyTargets()[5].properties[1],"font")
local fontId="fp:font:achtung-polizei"
local entry=ns.MediaRegistry.GetEntry(fontId,"font")
assert(entry.available); assert(entry.path:find("Achtung! Polizei.otf",1,true))
local discovered=false
for _,font in ipairs(api.GetTypographyFontOptions()) do if font.id==fontId then discovered=true end end
assert(discovered); equal(api.GetTypographyPresentation(target).font,fontId)
equal(brand:GetUserData("fpSidebarBrandTypography").rowHeight,34)
equal(brand.label.font,{entry.path,18,""})
local canonicalText=brand.label:GetText()
assert(canonicalText:find("|cffFFFFFF",1,true)); assert(not canonicalText:find("|T",1,true))
local bind=upvalue(ns.GUI.Editor.ToolbarBinding.RefreshWindowState,"BindBrandTypography")
-- Use the normal localized title to exercise both canonical Brand colors.
bind(brand,"Focal Point")
canonicalText=ns.GUI.Skins.GetBrandTitle("Focal Point")
equal(brand.label:GetText(),canonicalText)
assert(canonicalText:find("|cffEA7500",1,true))
local function Logo(widget)
    equal(widget.image:GetTexture(),"Interface\\AddOns\\FocalPoint\\Media\\icon.tga")
    equal(widget.image.nativeWidth,24); equal(widget.image.nativeHeight,24)
    equal(widget.image.points.LEFT.relative,widget.frame)
    equal(widget.image.points.LEFT.relativePoint,"LEFT")
    equal(widget.image.lastSetAlpha,{1}); equal(widget.image.lastSetVertexColor,{1,1,1,1})
    assert(widget.image:IsShown()); assert(not widget.label:GetText():find("|T",1,true))
    equal(widget.label.points.TOPLEFT.x,28)
    assert(widget.frame.clipsChildren); equal(widget.label.maxLines,1)
end
local function Isolated()
    equal(geometry(),baselineGeometry); equal(contents().versionLine,baselineVersion)
    equal({api.GetTypographyPresentation("sidebar_label"),api.GetTypographyPresentation("inspector_label"),
        api.GetTypographyPresentation("sidebar_section_heading"),api.GetTypographyPresentation("inspector_section_heading")},labels)
    plaque(); equal({copy(context.groups.Header.frame._fpSectionFill.lastSetTexCoord),
        context.groups.Header.frame._fpSectionFill:GetTexture()},baselinePlaque)
end
Logo(brand)
local patch={font="fp:font:morpheus",size=96,flags="THICKOUTLINE",color={.12,.34,.56},alpha=.23,shadowEnabled=false}
assert(api.SetTypographyPresentation(target,patch)); patch.color[1]=99
equal(brand.label.font,{"Fonts\\MORPHEUS.ttf",96,"THICKOUTLINE"})
equal(brand.label.lastSetTextColor,{.12,.34,.56,1}); equal(brand.label.lastSetAlpha,{.23})
equal(brand.label.shadowOffset,{0,0}); equal(brand.label.shadowColor,{0,0,0,0})
equal(brand.label:GetText(),"FOCAL POINT"); Logo(brand); Isolated()
local detached=api.GetTypographyPresentation(target); detached.color[1]=99
equal(api.GetTypographyPresentation(target).color,{.12,.34,.56})
for _,size in ipairs({6,18,48,96}) do
    assert(api.SetTypographyPresentation(target,{size=size})); equal(brand.label.font[2],size)
    toolbar.Hide(); toolbar.Open({},{})
    equal(brand.label.font[2],size); equal(brand.label.lastSetAlpha,{.23}); Logo(brand); Isolated()
end
-- No RGB override: retain both skin colors while font/alpha/shadow remain editable.
assert(api.ClearTypography(target)); bind(brand,"Focal Point")
assert(api.SetTypographyPresentation(target,{alpha=0,size=96,shadowEnabled=false}))
equal(brand.label:GetText(),canonicalText); equal(brand.label.lastSetAlpha,{0}); Logo(brand); Isolated()
local skin=ns.GUI.Skins.GetActiveSkin()
local originalFocal,originalPoint=skin.brand.titleFocal,skin.brand.titlePoint
skin.brand.titleFocal={wow="|cff336699",r=.2,g=.4,b=.6}
skin.brand.titlePoint={wow="|cffCC8844",r=.8,g=.533,b=.267}
assert(api.ClearTypography(target))
equal(brand.label:GetText(),ns.GUI.Skins.GetBrandTitle("Focal Point"))
equal(brand.label.lastSetAlpha,{1}); equal(brand.label.font,{entry.path,18,""})
equal(brand.label.shadowOffset,{1,-1}); equal(api.GetTypographyPresentation(target).color,{.2,.4,.6})
skin.brand.titleFocal,skin.brand.titlePoint=originalFocal,originalPoint
assert(api.ClearTypography(target))
-- Registry rejects unknown/unavailable references before touching the consumer.
for _,id in ipairs({"fp:font:does-not-exist","lsm:font:missing"}) do
    local ok,reason=api.SetTypographyPresentation(target,{font=id}); equal(ok,false); equal(reason,"unavailable_font")
end
-- A registered font can still fail at SetFont in the client: deterministic Friz fallback.
local setFont=native.SetFont
native.SetFont=function(self,font,...)
    if font=="Fonts\\MORPHEUS.ttf" then return false end
    return setFont(self,font,...)
end
assert(api.SetTypographyPresentation(target,{font="fp:font:morpheus"}))
equal(brand.label.font[1],"Fonts\\FRIZQT__.TTF")
native.SetFont=setFont; assert(api.ClearTypography(target))
local before=copy(api.GetTypographyOverrides(target)); local inCombat=InCombatLockdown
InCombatLockdown=function() return true end
local ok,reason=api.SetTypographyPresentation(target,{size=50}); equal(ok,false); equal(reason,"combat")
ok,reason=api.ClearTypography(target); equal(ok,false); equal(reason,"combat")
equal(api.GetTypographyOverrides(target),before); InCombatLockdown=inCombat
-- Late binding and pooled reuse: native AceGUI auto image layout is replaced only
-- on this instance, including widths that would normally flip the image vertically.
local released=0
for cycle=1,25 do
    assert(api.SetTypographyPresentation(target,{font="fp:font:morpheus",size=96,alpha=.1,color={.2,.3,.4}}))
    local widget=ns.GUI.Helpers.FormWidgets.CreateBodyText("", "sectionHeader",18,nil,180,false)
    local originalText,originalWidth=widget.SetText,widget.OnWidthSet
    widget:SetCallback("OnRelease",function() released=released+1 end)
    bind(widget,"Very wide localized Focal Point identity")
    equal(widget.frame:GetHeight(),34); equal(widget.label.font[2],96); Logo(widget)
    for _,width in ipairs({100,180,225,315}) do
        widget:SetWidth(width); equal(widget.frame:GetHeight(),34); Logo(widget)
    end
    ace:Release(widget)
    equal(widget.SetText,originalText); equal(widget.OnWidthSet,originalWidth)
    equal(widget:GetUserData("fpSidebarBrandTypography"),nil)
    equal(widget.image:GetTexture(),nil); assert(not widget.frame.clipsChildren)
    equal(widget.label.maxLines,0); equal(widget.label.lastSetAlpha,{1})
    local reused=ace:Create("Label"); equal(reused,widget)
    reused:SetText("Normal pooled label"); local normalHeight=reused.frame:GetHeight()
    assert(api.ClearTypography(target)); equal(reused.frame:GetHeight(),normalHeight)
    assert(not reused.frame.clipsChildren); ace:Release(reused)
end
equal(released,25)
assert(#env.errors==0,table.concat(env.errors,"\n"))
print("PASS: Brand discovery/registry, six properties, isolated logo, two-color reset, fallback/combat/copies, bounded large-font layout, late binding and 25 pooled cycles")
