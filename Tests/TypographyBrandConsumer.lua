-- lua54 Tests/TypographyBrandConsumer.lua [DesignTool directory]
-- The Tool remains byte-for-byte unchanged. Extend the existing consumer fixture
-- with the real product font registry and Brand resolver, not a Brand UI mock.
local f=assert(io.open("Tests/TypographyLabelConsumer.lua")); local source=f:read("*a"); f:close()
local tool,api,ui,setCombat,product=assert(load(source..
    "\nreturn tool,api,ui,setCombat,product", "@Tests/TypographyLabelConsumer.lua"))()
STANDARD_TEXT_FONT="Fonts\\FRIZQT__.TTF"
local lsm={
    List=function(_,kind) return kind=="font" and {"Wide Fixture"} or {} end,
    HashTable=function(_,kind) return kind=="font" and {["Wide Fixture"]="Interface\\AddOns\\Fixture\\Wide.ttf"} or {} end,
    Fetch=function(_,kind,key) if kind=="font" and key=="Wide Fixture" then return "Interface\\AddOns\\Fixture\\Wide.ttf" end end,
    IsValid=function(_,kind,key) return kind=="font" and key=="Wide Fixture" end,
}
local originalLibStub=LibStub
LibStub=function(name,...)
    if name=="LibSharedMedia-3.0" then return lsm end
    return originalLibStub(name,...)
end
assert(loadfile("Services/MediaRegistry.lua"))("FocalPoint",product)
product.MediaRegistry.RefreshProvider("lsm","font")
local function Equal(a,b)
    if a==b then return end
    if type(a)=="table" and type(b)=="table" then
        for k,v in pairs(a) do Equal(v,b[k]) end
        for k in pairs(b) do assert(a[k]~=nil) end
    else error(tostring(a).." ~= "..tostring(b)) end
end
tool.DiscoverTypography()
tool.SelectTypographyArea("Sidebar"); tool.SelectTypographyTarget("sidebar_brand")
Equal(tool.typographyTarget,"sidebar_brand"); Equal(tool.typographyLabels.sidebar_brand,"Brand")
Equal(#ui.typographyProperties.children,6)
local fonts=tool.TypographyFontOptions()
assert(fonts["fp:font:achtung-polizei"]=="Achtung! Polizei")
local sharedId
for id,label in pairs(fonts) do if label=="Wide Fixture" then sharedId=id end end
assert(sharedId and sharedId:find("lsm:font:",1,true))
Equal(api.GetTypographyPresentation("sidebar_brand").font,"fp:font:achtung-polizei")
local isolated={api.GetTypographyOverrides("sidebar_label"),api.GetTypographyOverrides("inspector_label"),
    api.GetTypographyOverrides("sidebar_section_heading"),api.GetTypographyOverrides("inspector_section_heading")}
assert(tool.WorkspaceNew("Brand B2 contract"))
local picker=ui.typographyControls.color
picker.frame:GetScript("OnClick")(picker.frame)
ColorPickerFrame.rgb={.13,.24,.35}; ColorPickerFrame.info.swatchFunc()
tool.SetTypographyProperty("font",sharedId)
tool.SetTypographyProperty("size",96); tool.SetTypographyProperty("flags","OUTLINE,MONOCHROME")
tool.SetTypographyProperty("alpha",.17); tool.SetTypographyProperty("shadowEnabled",false)
local saved=api.GetTypographyOverrides("sidebar_brand")
Equal(saved,{font=sharedId,size=96,flags="OUTLINE,MONOCHROME",color={.13,.24,.35},alpha=.17,shadowEnabled=false})
assert(tool.WorkspaceSave())
Equal(FocalPointDesignToolDB.designs["Brand B2 contract"].schemaVersion,3)
Equal(FocalPointDesignToolDB.designs["Brand B2 contract"].typography.sidebar_brand,saved)
tool.ResetTypography(); Equal(api.GetTypographyOverrides("sidebar_brand"),{})
Equal(api.GetTypographyPresentation("sidebar_brand").font,"fp:font:achtung-polizei")
assert(tool.WorkspaceLoad("Brand B2 contract")); Equal(api.GetTypographyOverrides("sidebar_brand"),saved)
setCombat(true); tool.SetTypographyProperty("size",42); tool.ResetTypography()
assert(not tool.WorkspaceLoad("Brand B2 contract")); setCombat(false)
Equal(api.GetTypographyOverrides("sidebar_brand"),saved)
Equal({api.GetTypographyOverrides("sidebar_label"),api.GetTypographyOverrides("inspector_label"),
    api.GetTypographyOverrides("sidebar_section_heading"),api.GetTypographyOverrides("inspector_section_heading")},isolated)
LibStub=originalLibStub
print("PASS: unchanged DesignTool discovers Sidebar/Brand, real public built-in/LSM fonts, six controls, native RGB, Schema 3 Save/Load/Reset and combat isolation")
