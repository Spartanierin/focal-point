-- lua54 Tests/TypographyLabels.lua
-- Reuse the established native test environment; product files remain unchanged.
local function Read(path)
    local file = assert(io.open(path)); local text = file:read("*a"); file:close(); return text
end
local env, ns, ace, native = assert(load(Read("Tests/PresentationPreview.lua") ..
    "\nreturn env, ns, ace, native", "@Tests/PresentationPreview.lua"))()
local function Load(path) return assert(loadfile(path))("FocalPoint", ns) end
local api, widgets = ns.Ace.PresentationPreview, ns.GUI.Helpers.FormWidgets
local function Equal(a, b)
    if a == b then return end
    if type(a) == "table" and type(b) == "table" then
        for k,v in pairs(a) do Equal(v,b[k]) end
        for k in pairs(b) do assert(a[k] ~= nil, "extra key: " .. tostring(k)) end
    else assert(false, tostring(a) .. " ~= " .. tostring(b)) end
end
local function Copy(t)
    if type(t) ~= "table" then return t end
    local result = {}; for k,v in pairs(t) do result[k] = Copy(v) end; return result
end
for _, method in ipairs({ "Enable", "Disable", "SetDesaturated", "SetNormalTexture", "SetPushedTexture",
    "SetHighlightTexture", "SetDisabledTexture", "SetClampedToScreen", "SetToplevel", "Raise", "SetMovable",
    "SetScrollChild", "SetVerticalScroll", "SetResizable", "SetMinResize", "SetMaxResize" }) do
    native[method] = function(self, ...) self["last" .. method] = {...} end
end
function native:GetStringHeight() return 14 end
function native:GetHeight() return self.nativeHeight or 100 end
function native:GetStringWidth() return #(self.text or "") * 7 end
function native:GetTexture() return self.lastSetTexture and self.lastSetTexture[1] end
function native:GetName() return self.name end
function native:GetChildren() end
function native:SetFormattedText(format, ...) self:SetText(string.format(format, ...)) end
function native:SetShown(shown) if shown then self:Show() else self:Hide() end end
function PlaySound() end
function Round(v) return math.floor(v + .5) end
local originalCreate = CreateFrame
function CreateFrame(kind, name, parent, template)
    local frame = originalCreate(kind, name, parent); frame.name = name
    if name then _G[name] = frame end
    if template == "UIDropDownMenuTemplate" then
        for _, suffix in ipairs({"Left", "Middle", "Right", "Button", "Text"}) do
            _G[name .. suffix] = originalCreate("Frame", nil, frame)
        end
    end
    return frame
end
for _, file in ipairs({"Label", "CheckBox", "Slider", "DropDown", "ColorPicker"}) do
    Load("Libraries/Ace3/AceGUI-3.0/widgets/AceGUIWidget-" .. file .. ".lua")
end
Load("GUI/Editor/SidebarShared.lua")
Load("GUI/Editor/Inspector/InspectorController.lua")
Load("GUI/Editor/Toolbar/ToolbarBinding.lua")
local shared = ns.GUI.Editor.SidebarShared
local function Upvalue(fn, name)
    for i = 1, 100 do local key, value = debug.getupvalue(fn, i)
        if key == name then return value end
        if not key then break end
    end
    error("Missing Inspector upvalue: " .. name)
end
-- Actual central Inspector adapters captured by Build, not duplicate test implementations.
local addCheck = Upvalue(ns.GUI.Editor.Inspector.Build, "AddCheckBox")
local addSlider = Upvalue(ns.GUI.Editor.Inspector.Build, "AddSlider")
local addDropdown = Upvalue(ns.GUI.Editor.Inspector.Build, "AddDropdown")
local source = Read("GUI/Editor/Inspector/InspectorController.lua")
local function LocalConstructor(name, nextName, context)
    local first = assert(source:find("    local function " .. name .. "(", 1, true))
    local last = assert(source:find("    local function " .. nextName .. "(", first + 1, true))
    return assert(load(source:sub(first, last - 1) .. "\nreturn " .. name,
        "@InspectorController." .. name, "t", setmetatable(context, { __index = _G })))()
end
local context = { AceGUI = ace, FormWidgets = widgets, PROPERTY_LABEL_WIDTH = 108,
    INSPECTOR_ROW_STRIDES = { COMPACT = 32 }, INSPECTOR_FLOW_GAP = 3,
    activeInspectorDiagnosticHosts = {}, Shared = shared, L = {} }
local row = LocalConstructor("AddPropertyRow", "CreateTwoControlTableRow", context)
context.AddPropertyRow = row
local checkRow = LocalConstructor("AddPropertyCheckBoxRow", "AddPropertyColorRow", context)
local valueRow = LocalConstructor("AddPropertyValueTextRow", "AddPropertyActionButtonRow", context)
local host = ace:Create("SimpleGroup")
local targets = {}; for _, t in ipairs(api.GetTypographyTargets()) do targets[t.id] = t end
Equal(targets.inspector_label.area, "Inspector"); Equal(targets.sidebar_label.area, "Sidebar")
Equal(targets.inspector_label.properties, targets.inspector_section_heading.properties)
assert(targets.inspector_label.role == nil)
targets.inspector_label.properties[1] = "bad"
Equal(api.GetTypographyCapabilities().properties.size, {type="number",min=6,max=96})
local patch = {font="lsm:font:fixture",size=19,flags="OUTLINE",color={.21,.32,.43},alpha=.37,shadowEnabled=false}
assert(api.SetTypographyPresentation("inspector_label", patch))
patch.color[1] = 99
local expected = api.GetTypographyPresentation("inspector_label")
Equal(expected.color, {.21,.32,.43})
local copied = api.GetTypographyPresentation("inspector_label"); copied.color[1] = 99
Equal(api.GetTypographyPresentation("inspector_label").color, expected.color)
local function Applied(slot, descriptor)
    descriptor = descriptor or expected
    Equal(slot.lastSetTextColor, {descriptor.color[1],descriptor.color[2],descriptor.color[3],descriptor.alpha})
    Equal(slot.font, {ns.GUI.PresentationPreview.ResolveTypographyFont(descriptor.font),descriptor.size,descriptor.flags})
    Equal(slot.shadowOffset, descriptor.shadowEnabled and {1,-1} or {0,0})
    Equal(slot.shadowColor, descriptor.shadowEnabled and {0,0,0,.90} or {0,0,0,0})
end
local propertyRow = row(host, "Width", function() end)
local label = propertyRow.children[1]; Applied(label.label)
local check = addCheck(host, "Show in Solo", true, function() end)
local slider = addSlider(host, "Transparency", 0, 1, .01, .8, function() end)
local dropdown = addDropdown(host, "Frame Strata", {}, nil, function() end)
for _, owner in ipairs({check, slider, dropdown}) do
    local slot = owner == check and owner.text or owner.label
    Applied(slot)
    owner:SetDisabled(true); Applied(slot)
    owner:SetDisabled(false); Applied(slot)
end
check:SetValue(false); Applied(check.text)
check.frame:Run("OnMouseUp"); Applied(check.text)
widgets.StyleCheckBox(check, false); Applied(check.text)
local dropValue = Copy(dropdown.text.lastSetTextColor)
widgets.StyleDropdown(dropdown, "editor_inset", "value"); Applied(dropdown.label)
local sliderValues = {Copy(slider.lowtext.lastSetTextColor),Copy(slider.hightext.lastSetTextColor),Copy(slider.editbox.lastSetTextColor)}
local onOff = checkRow(host, "Enabled", true, function() end)
local template = valueRow(host, "Template", "Dynamic template")
local excluded = {}
for _, role in ipairs({"label", "identity", "help", "statusError", "sectionHeader", "value"}) do
    local owner = widgets.CreateBodyText("Excluded " .. role, role, 12)
    host:AddChild(owner); excluded[#excluded+1] = { owner.label, Copy(owner.label.lastSetTextColor), Copy(owner.label.font) }
end
excluded[#excluded+1] = { onOff.text, Copy(onOff.text.lastSetTextColor), Copy(onOff.text.font) }
excluded[#excluded+1] = { template.label, Copy(template.label.lastSetTextColor), Copy(template.label.font) }
assert(not onOff:GetUserData("fpLabelTypography")); assert(not template:GetUserData("fpLabelTypography"))
local sidebar = ns.GUI.Editor.ToolbarBinding.CreateItemWidget({id="expertMode",widget="checkbox",text="Expert Mode"},
    {AceGUI=ace,StyleCheckBox=widgets.StyleCheckBox})
assert(sidebar:GetUserData("fpLabelTypography")); host:AddChild(sidebar)
local otherSidebar = ns.GUI.Editor.ToolbarBinding.CreateItemWidget({id="notActive",widget="checkbox",text="Other"},
    {AceGUI=ace,StyleCheckBox=widgets.StyleCheckBox})
assert(not otherSidebar:GetUserData("fpLabelTypography")); host:AddChild(otherSidebar)
assert(api.SetTypographyPresentation("sidebar_label", {color={.41,.52,.63}}))
Equal(sidebar.text.lastSetTextColor, {.41,.52,.63,1}); Applied(label.label)
assert(api.SetTypographyPresentation("inspector_label", {size=20}))
for _, entry in ipairs(excluded) do Equal(entry[1].lastSetTextColor,entry[2]); Equal(entry[1].font,entry[3]) end
Equal({slider.lowtext.lastSetTextColor,slider.hightext.lastSetTextColor,slider.editbox.lastSetTextColor},sliderValues)
local previousCombat = InCombatLockdown
InCombatLockdown=function() return true end
local ok, why = api.SetTypographyPresentation("inspector_label", {size=25}); Equal(ok,false); Equal(why,"combat")
ok, why=api.ClearTypography("inspector_label"); Equal(ok,false); Equal(why,"combat")
InCombatLockdown=previousCombat
local skin = ns.GUI.Skins.GetActiveSkin()
local oldColor, oldFont = skin.textColors.label, skin.fonts.default
skin.textColors.label={r=.31,g=.42,b=.53}; skin.fonts.default="Fonts\\MORPHEUS.ttf"
assert(api.ClearTypography("inspector_label"))
Equal(label.label.font, {"Fonts\\MORPHEUS.ttf",12,""})
Equal(api.GetTypographyPresentation("inspector_label").font,"fp:font:morpheus")
Equal(label.label.lastSetTextColor,{.31,.42,.53,1}); Equal(label.label.shadowOffset,{1,-1})
skin.textColors.label,skin.fonts.default=oldColor,oldFont
assert(api.ClearTypography())
local collapseHost=ace:Create("SimpleGroup")
local latestCaption
ns.GUI.Editor.Inspector.InspectorBinding.CreateInspectorSection(collapseHost,shared.CreateSection,{},"t3","Section",false,nil,{
    localContentBuilder=function(group)
        latestCaption=row(group,"Width",function() end).children[1]
        addCheck(group,"Enabled",true,function() end)
    end,
})
for cycle=1,20 do
    assert(api.SetTypographyPresentation("inspector_label",{size=21}))
    Equal(latestCaption.label.font[2],21)
    collapseHost.children[1]:Fire("OnClick")
    Equal(#collapseHost.children[2].children,0)
    collapseHost.children[1]:Fire("OnClick")
    Equal(latestCaption.label.font[2],21)
end
ace:Release(collapseHost); assert(api.ClearTypography())
local originalAceCreate,originalBuild=ace.Create,ns.GUI.Helpers.FormRenderer.BuildLayout
ace.Create=function(self,kind)
    if kind~="Window" and kind~="ScrollFrame" then return originalAceCreate(self,kind) end
    local owner=originalAceCreate(self,"SimpleGroup")
    function owner:SetTitle() end
    function owner:EnableResize() end
    function owner:Show() self.frame:Show() end
    return owner
end
local expert
ns.GUI.Helpers.FormRenderer.BuildLayout=function()
    expert=ns.GUI.Editor.ToolbarBinding.CreateItemWidget({id="expertMode",widget="checkbox",text="Expert Mode"},
        {AceGUI=ace,StyleCheckBox=widgets.StyleCheckBox})
    return {},{expertMode=expert}
end
Load("GUI/Editor/Toolbar/ToolbarController.lua")
ns.GUI.Editor.Toolbar.Open({},{})
assert(api.SetTypographyPresentation("sidebar_label",{color={.32,.43,.54},size=17}))
for cycle=1,20 do
    ns.GUI.Editor.Toolbar.Hide(); ns.GUI.Editor.Toolbar.Open({},{})
    Equal(expert.text.lastSetTextColor,{.32,.43,.54,1}); Equal(expert.text.font[2],17)
end
ace.Create,ns.GUI.Helpers.FormRenderer.BuildLayout=originalAceCreate,originalBuild
assert(api.ClearTypography())
local releases=0
for cycle=1,50 do
    local section=ace:Create("SimpleGroup"); host:AddChild(section)
    local a=addCheck(section,"Enabled",true,function() end)
    a:SetCallback("OnValueChanged",function() end)
    local b=row(section,"Height",function() end)
    assert(api.SetTypographyPresentation("inspector_label",{size=18,color={.11,.22,.33}}))
    Equal(a.text.font[2],18); Equal(b.children[1].label.font[2],18)
    local original=a:GetUserData("fpLabelTypography").originalSetDisabled
    section:ReleaseChildren() -- actual AceGUI path used by rebuild/collapse
    Equal(a.SetDisabled,original); Equal(a:GetUserData("fpLabelTypography"),nil)
    Equal(a.text.font[2],12)
    assert(api.ClearTypography("inspector_label"))
end
local callbackOwner=ace:Create("Label")
callbackOwner:SetCallback("OnRelease",function() releases=releases+1 end)
widgets.BindLabelTypography(callbackOwner,"label","inspector_label")
widgets.BindLabelTypography(callbackOwner,"label","inspector_label")
ace:Release(callbackOwner); Equal(releases,1)
local inspectorContext=Upvalue(ns.GUI.Editor.Inspector.Build,"InspectorContext")
local objectSelection=Upvalue(ns.GUI.Editor.Inspector.Build,"ObjectSelection")
inspectorContext.Create=function() return {unitKey="player",unitConfig={},isQuick=true} end
objectSelection.GetSelectedObject=function() return {kind="unit",unit="player"} end
for i=1,100 do
    local name=debug.getupvalue(ns.GUI.Editor.Inspector.Build,i)
    if name=="POINTS" then debug.setupvalue(ns.GUI.Editor.Inspector.Build,i,{}); break end
end
local buildHost=ace:Create("SimpleGroup")
local function Visit(owner, fn)
    fn(owner); for _,child in ipairs(owner.children or {}) do Visit(child,fn) end
end
for cycle=1,3 do
    assert(api.SetTypographyPresentation("inspector_label",{size=18}))
    ns.GUI.Editor.Inspector.BuildProperties(buildHost,{selectedUnit="player"},{})
    local labels=0
    Visit(buildHost,function(owner)
        local binding=owner:GetUserData("fpLabelTypography")
        if binding then labels=labels+1; Equal(owner[binding.slot].font[2],18) end
        if owner.type=="CheckBox" or owner.type=="ColorPicker" then assert(not binding) end
    end)
    assert(labels>=10,"Expected unit-root property labels across multiple sections")
end
ace:Release(buildHost); assert(api.ClearTypography())
assert(#env.errors==0, table.concat(env.errors,"\n"))
print("PASS: T3 targets/copies, real Inspector row/control adapters, native checkbox click/state, slider/dropdown state, Sidebar Expert Mode/reopen, six properties, fresh canonical reset, exclusions, collapse/reopen and 50 release/rebuild cycles")
