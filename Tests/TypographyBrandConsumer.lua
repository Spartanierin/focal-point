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
-- Font Pack: exercise the canonical registry, public discovery and unchanged Tool.
local registry=product.MediaRegistry
local entries=registry.GetAvailable("font")
local options=api.GetTypographyFontOptions()
Equal(options,api.GetTypographyFontOptions())
Equal(#entries,#options)
local expectedOrder={"achtung-polizei","cinzel-decorative-black","cinzel-decorative-bold",
    "cinzel-decorative-regular","arial-narrow","friz-quadrata","morpheus","skurri","standard"}
for index,key in ipairs(expectedOrder) do
    Equal(entries[index].id,"fp:font:"..key)
end
local labels,order=tool.TypographyFontOptions()
for index,entry in ipairs(entries) do
    Equal(options[index],{id=entry.id,label=entry.name,available=true})
end
for index=2,#order do
    local previous,current=order[index-1],order[index]
    assert(labels[previous]<labels[current] or (labels[previous]==labels[current] and previous<current))
end
for _,weight in ipairs({"Black","Bold","Regular"}) do
    local id="fp:font:cinzel-decorative-"..weight:lower()
    local label="Cinzel Decorative "..weight
    local path="Interface\\AddOns\\FocalPoint\\Media\\CinzelDecorative-"..weight..".ttf"
    local entry=assert(registry.GetEntry(id,"font"))
    Equal(entry.name,label); Equal(entry.path,path)
    Equal(entry.source,"Focal Point"); Equal(entry.provider,"FocalPoint")
    Equal(entry.category,"FocalPoint"); Equal(entry.sortName,label:lower())
    assert(entry.builtin and entry.verified and registry.IsAvailable(id,"font"))
    local resolved=registry.ResolveReference(id,"font")
    Equal(resolved.resolvedAsset,path); Equal(resolved.normalizedReference,id)
    assert(resolved.available and not resolved.fallbackUsed)
    local localPath=resolved.resolvedAsset:gsub("^Interface\\AddOns\\FocalPoint\\",""):gsub("\\","/")
    local asset=assert(io.open(localPath,"rb"))
    Equal(asset:read(4),"\0\1\0\0"); asset:close()
    Equal(labels[id],label)
    Equal(ui.typographyControls.font.list[id],label)
    assert(api.SetTypographyPresentation("sidebar_brand",{font=id}))
    Equal(api.GetTypographyPresentation("sidebar_brand").font,id)
    entry.name="mutated"; resolved.entry.path="mutated"
    Equal(registry.GetEntry(id,"font").name,label)
    Equal(registry.ResolveReference(id,"font").resolvedAsset,path)
end
entries[2].name="mutated"; options[2].label="mutated"; labels[order[1]]="mutated"
Equal(registry.GetAvailable("font")[2].name,"Cinzel Decorative Black")
Equal(api.GetTypographyFontOptions()[2].label,"Cinzel Decorative Black")
Equal(tool.TypographyFontOptions()["fp:font:achtung-polizei"],"Achtung! Polizei")
local existing={
    {"standard","Standard",STANDARD_TEXT_FONT},
    {"arial-narrow","Arial Narrow","Fonts\\ARIALN.TTF"},
    {"achtung-polizei","Achtung! Polizei","Interface\\AddOns\\FocalPoint\\Media\\Achtung! Polizei.otf"},
    {"morpheus","Morpheus","Fonts\\MORPHEUS.ttf"},
    {"skurri","Skurri","Fonts\\SKURRI.ttf"},
    {"friz-quadrata","Friz Quadrata","Fonts\\FRIZQT__.TTF"},
}
for _,font in ipairs(existing) do
    local id="fp:font:"..font[1]
    Equal(registry.GetEntry(id,"font").name,font[2])
    Equal(registry.ResolveReference(id,"font").resolvedAsset,font[3])
    assert(registry.IsAvailable(id,"font"))
end
local unknown="fp:font:font-pack-missing"
assert(not registry.IsAvailable(unknown,"font"))
Equal(registry.GetEntry(unknown,"font").available,false)
local before=api.GetTypographyOverrides("sidebar_brand")
local accepted,reason=api.SetTypographyPresentation("sidebar_brand",{font=unknown})
Equal(accepted,false); Equal(reason,"unavailable_font")
Equal(api.GetTypographyOverrides("sidebar_brand"),before)
tool.ResetTypography()
Equal(registry.GetDefault("font"),"fp:font:standard")
Equal(api.GetTypographyPresentation("sidebar_brand").font,"fp:font:achtung-polizei")
print("PASS: Font Pack registry, resolver paths/TTF headers, availability, public/Tool discovery, sorting, defensive DTOs, rejection and existing defaults")
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
