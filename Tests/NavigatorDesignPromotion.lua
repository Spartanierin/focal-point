-- lua54 Tests/NavigatorDesignPromotion.lua
-- Golden product defaults, without DesignTool or SavedVariables. Reuse the real
-- Header/Table/Toolbar fixture and native region doubles from the Brand tests.
local f=assert(io.open("Tests/NavigatorBrandTypography.lua")); local source=f:read("*a"); f:close()
local boundary=assert(source:find("local api=ns.Ace.PresentationPreview",1,true))
local env,ns,ace,native,toolbar,context,Equal,Copy=assert(load(source:sub(1,boundary-1)..
    "\nreturn env,ns,ace,native,toolbar,context,equal,copy", "@Promotion/HeaderFixture"))()
local function Load(path) assert(loadfile(path))("FocalPoint",ns) end
Load("GUI/Helpers/PresentationCompositionPreview.lua")
local preview,composition=ns.Ace.PresentationPreview,ns.Ace.PresentationCompositionPreview
-- The shared preview fixture ends on an alternate skin to test fresh baselines.
assert(ns.GUI.Skins.SetActiveSkin("default"))
assert(preview.ClearAll())
local widgets=ns.GUI.Helpers.FormWidgets
local renderer=ns.GUI.Helpers.FormSectionSurfaceRenderer
local binding=ns.GUI.Editor.Inspector.InspectorBinding
local metal={0.3137255012989044,0.3137255012989044,0.3137255012989044,0.92}
local wood={0.1960784494876862,0.1960784494876862,0.1960784494876862,0.9}
local inspectorWood={0.2117647230625153,0.2117647230625153,0.2117647230625153,0.9}
local parchment={0.6549019813537598,0.6549019813537598,0.6549019813537598,0.99}
local line={0.9490196704864502,0.8156863451004028,0.3607843220233917}
local label={0.8117647767066956,0.7725490927696228,0.6745098233222961}
local heading={0.9098039865493774,0.7568628191947937,0.4000000357627869}
local brand={0.8274510502815247,0.6784313917160034,0.4078431725502014}
local metalId,woodId="fp:texture:fp-forged-metal-128x128","fp:texture:fp-mahagony-128x128"
local function Asset(id,kind)
    local resolved=ns.MediaRegistry.ResolveReference(id,kind or "texture")
    assert(resolved.available and not resolved.fallbackUsed)
    local path=resolved.resolvedAsset:gsub("^Interface\\AddOns\\FocalPoint\\",""):gsub("\\","/")
    local file=assert(io.open(path,"rb")); file:close()
    return resolved.resolvedAsset
end
local function Material(region,id,tint)
    assert(region and region:IsShown())
    Equal(region:GetTexture(),Asset(id)); Equal(region.lastSetVertexColor,tint)
    Equal(region.lastSetTexCoord,{0,1,0,1})
end
local function NoSectionExtras(owner)
    for _,suffix in ipairs({"Accent","Divider","BorderTop","BorderBottom","BorderLeft","BorderRight"}) do
        local region=owner.frame["_fpSection"..suffix]
        assert(not region or not region:IsShown(),suffix)
    end
end
local function Lines(owner,topAlpha)
    Equal(owner.frame._fpSectionTopShade.lastSetColorTexture,{line[1],line[2],line[3],topAlpha})
    Equal(owner.frame._fpSectionBottomShade.lastSetColorTexture,{line[1],line[2],line[3],0.4})
    Equal(owner.frame._fpSectionTopShade:GetHeight(),1)
    Equal(owner.frame._fpSectionBottomShade:GetHeight(),1)
    NoSectionExtras(owner)
end
Equal(preview.GetTypographyOverrides(),{})
for _,target in ipairs(composition.GetTargets()) do Equal(composition.GetComposition(target.id),nil) end
for _,target in ipairs({"sidebar_label","inspector_label"}) do
    local d=preview.GetTypographyPresentation(target)
    Equal(d.color,label); Equal(d.alpha,0.9); Equal(d.size,12)
    Equal(d.flags,""); Equal(d.shadowEnabled,true)
end
for _,target in ipairs({"sidebar_section_heading","inspector_section_heading"}) do
    local d=preview.GetTypographyPresentation(target)
    Equal(d.color,target=="sidebar_section_heading" and {0.910,0.757,0.400} or heading)
    Equal(d.size,14); Equal(d.flags,"OUTLINE"); Equal(d.alpha,0.8)
    Equal(d.font,"fp:font:standard"); Equal(d.shadowEnabled,true)
end
local d=preview.GetTypographyPresentation("sidebar_brand")
Equal(d,{font="fp:font:cinzel-decorative-bold",size=19,color=brand,alpha=0.9,flags="",shadowEnabled=true})
Asset(d.font,"font")
Equal(ns.GUI.Skins.GetBrandTitle("Focal Point"),"FOCAL POINT")
-- Global text roles are not the target defaults.
Equal(ns.GUI.Helpers.TextStyles.Get("label").r,0.949)
Equal(ns.GUI.Helpers.TextStyles.Get("strongHeading").r,0.949)
local baseline=preview.GetTypographyPresentation()
for _,target in ipairs(preview.GetTypographyTargets()) do
    assert(preview.SetTypographyPresentation(target.id,{size=96,color={1,0,1},alpha=0}))
    assert(preview.ClearTypography(target.id))
    Equal(preview.GetTypographyPresentation(target.id),baseline[target.id])
end
-- Fresh bind uses original B3 allocation even though Cinzel's mocked metrics differ.
Equal(context.groups.Header.frame:GetHeight(),67.75)
Equal(context.groups.Options.frame.points.TOP.x,-83.75)
Equal(context.widgets.brandLine:GetUserData("fpSidebarBrandTypography").rowHeight,34)
Equal(context.widgets.brandLine.label.font,{Asset(d.font,"font"),19,""})
Equal(context.widgets.brandLine.label.lastSetTextColor,{brand[1],brand[2],brand[3],1})
Equal(context.widgets.brandLine.label.lastSetAlpha,{0.9})
Equal(context.widgets.brandLine.image.lastSetAlpha,{1})
local shell=context.window
local function CheckSidebar()
    Material(shell.frame._fpSidebarPanelFill,metalId,metal)
    Equal(shell.frame._fpSidebarPanelFill.points.TOPLEFT.x,0)
    Equal(shell.frame._fpSidebarPanelFill.points.BOTTOMRIGHT.y,0)
    for _,suffix in ipairs({"HeaderFill","TopShade","BottomShade"}) do
        assert(not shell.frame["_fpSidebarPanel"..suffix]:IsShown())
    end
    assert(not shell.content._fpSidebarAccent:IsShown())
    Equal(shell.content.points.TOPLEFT.x,12)
end
toolbar.Open({},{}) -- binds the real Shell and Section composition owners
CheckSidebar()
ns.GUI.AppShell.AssignEditorRuntimeRoles(ns)
Material(ns.guiEditorToolbarLayer._editorSidebar,metalId,metal)
for cycle=1,10 do
    assert(composition.AddLayer("sidebar_shell","surface",{color={1,0,0}}))
    assert(composition.ResetComposition("sidebar_shell")); CheckSidebar()
    Material(ns.guiEditorToolbarLayer._editorSidebar,metalId,metal)
    toolbar.Hide(); toolbar.Open({},{}); CheckSidebar()
    Equal(context.groups.Header.frame:GetHeight(),67.75)
    Equal(context.groups.Options.frame.points.TOP.x,-83.75)
end
-- Inspector shell and its separate 12px surface bounds; normal content anchors remain.
local inspector=ace:Create("SimpleGroup")
widgets.ApplySidebarChrome(inspector,"inspector_shell")
Material(inspector.frame._fpSidebarPanelFill,metalId,metal)
Equal(inspector.frame._fpSidebarPanelFill.points.TOPLEFT.x,12)
Equal(inspector.frame._fpSidebarPanelFill.points.BOTTOMRIGHT.y,12)
Equal(inspector.content.points.TOPLEFT.x,12)
ace:Release(inspector)
for _,styleId in ipairs({"toolbar_workspace_panel","toolbar_editing_panel","toolbar_global_panel"}) do
    local owner=ace:Create("SimpleGroup")
    local style=widgets.ResolveSectionStyle(styleId)
    renderer.ApplySectionSurface(owner,style); renderer.ApplySectionBorder(owner,style.border)
    Material(owner.frame._fpSectionFill,woodId,wood); Lines(owner,0.6)
    Equal(owner.frame._fpSectionFill.points.TOPLEFT.x,0)
    ace:Release(owner)
end
for cycle=1,10 do
    local owner=ace:Create("SimpleGroup")
    binding.ApplyInspectorSectionStructure(owner,"default")
    local function CheckSection()
        Material(owner.frame._fpSectionFill,woodId,inspectorWood); Lines(owner,0.4)
        Equal(owner.frame._fpSectionFill.points.TOPLEFT.x,6)
        Equal(owner.frame._fpSectionFill.points.BOTTOMRIGHT.x,-6)
    end
    CheckSection()
    assert(composition.AddLayer("inspector_section","texture"))
    assert(composition.ResetComposition("inspector_section")); CheckSection()
    assert(preview.Set("inspector_section_surface","color",{1,0,0}))
    assert(preview.Clear("inspector_section_surface")); CheckSection()
    assert(preview.Set("inspector_section_border","alpha",1))
    assert(preview.Clear("inspector_section_border")); CheckSection()
    binding.ApplyInspectorSectionStructure(owner,"muted"); CheckSection()
    ace:Release(owner)
    local inset=ace:Create("SimpleGroup")
    local style=widgets.ResolveSectionStyle("toolbar_explorer_inset")
    renderer.ApplySectionSurface(inset,style); renderer.ApplySectionBorder(inset,style.border)
    ns.GUI.PresentationPreview.BindSidebarNavigatorInset(inset)
    Material(inset.frame._fpSectionFill,"fp:texture:parchment",parchment)
    assert(composition.AddLayer("sidebar_unit_navigator_inset","surface"))
    assert(composition.ResetComposition("sidebar_unit_navigator_inset"))
    Material(inset.frame._fpSectionFill,"fp:texture:parchment",parchment); NoSectionExtras(inset)
    assert(preview.Set("sidebar_unit_navigator_inset","color",{0,1,0}))
    assert(preview.Clear("sidebar_unit_navigator_inset"))
    Material(inset.frame._fpSectionFill,"fp:texture:parchment",parchment)
    ace:Release(inset)
end
assert(#env.errors==0,table.concat(env.errors,"\n"))
print("PASS: exact promoted materials/typography, registry files, distinct shell bounds/underlay, no extra chrome, fresh B3 allocation, reset/reopen/rebuild/pooling without DesignTool")
