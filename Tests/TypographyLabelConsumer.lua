-- lua54 Tests/TypographyLabelConsumer.lua [DesignTool directory]
-- Read-only use of the Tool's native test harness and unmodified consumer files.
-- Its old exact-two-target assertions are replaced by this additive contract test.
local toolRoot = arg[1] or "../FocalPointDesignTool"
local function Read(path)
    local file=assert(io.open(path)); local text=file:read("*a"); file:close(); return text
end
local source=Read(toolRoot .. "/Tests/Workbench.lua")
local boundary=assert(source:find("Equal(#tool.typographyOrder, 2)",1,true))
local originalLoadfile, originalArg=loadfile,arg
loadfile=function(path, ...)
    if not path:find("/",1,true) then path=toolRoot .. "/" .. path end
    return originalLoadfile(path,...)
end
arg={"."}
local tool,api,ui,setCombat,product=assert(load(source:sub(1,boundary-1) ..
    "\nreturn tool, api, ui, function(value) combat=value end, product", "@DesignTool/Tests/Workbench.lua"))()
loadfile,arg=originalLoadfile,originalArg
-- The older Tool fixture only stubs Skins; additive product targets use its real resolver.
assert(loadfile("GUI/GUISkin.lua"))("FocalPoint",product)
local function Equal(a,b)
    if a==b then return end
    if type(a)=="table" and type(b)=="table" then
        for k,v in pairs(a) do Equal(v,b[k]) end
        for k in pairs(b) do assert(a[k]~=nil) end
    else assert(false,tostring(a).." ~= "..tostring(b)) end
end
assert(tool.typographyTargets.inspector_label and tool.typographyTargets.sidebar_label)
tool.SetMode("typography")
assert(tool.WorkspaceInit()); assert(tool.WorkspaceNew("T3 contract test"))
for _,area in ipairs({"Inspector","Sidebar"}) do
    local id=area:lower().."_label"
    tool.SelectTypographyArea(area); tool.SelectTypographyTarget(id)
    Equal(tool.typographyTarget,id); Equal(#ui.typographyProperties.children,6)
    for _,property in ipairs({"font","size","flags","color","alpha","shadowEnabled"}) do
        assert(ui.typographyControls[property])
    end
    local picker=ui.typographyControls.color
    picker.frame:GetScript("OnClick")(picker.frame)
    ColorPickerFrame.rgb={.23,.34,.45}; ColorPickerFrame.info.swatchFunc()
    Equal(api.GetTypographyOverrides(id).color,{.23,.34,.45})
    tool.SetTypographyProperty("font","fp:font:morpheus")
    tool.SetTypographyProperty("size",18); tool.SetTypographyProperty("flags","OUTLINE")
    tool.SetTypographyProperty("alpha",.6); tool.SetTypographyProperty("shadowEnabled",false)
    local saved=api.GetTypographyOverrides(id)
    assert(tool.WorkspaceSave())
    Equal(FocalPointDesignToolDB.designs["T3 contract test"].schemaVersion,3)
    tool.ResetTypography(); Equal(api.GetTypographyOverrides(id),{})
    assert(tool.WorkspaceLoad("T3 contract test")); Equal(api.GetTypographyOverrides(id),saved)
    setCombat(true); tool.SetTypographyProperty("size",25); tool.ResetTypography(); setCombat(false)
    Equal(api.GetTypographyOverrides(id),saved)
end
Equal(api.GetTypographyOverrides("inspector_section_heading"),{})
Equal(api.GetTypographyOverrides("sidebar_section_heading"),{})
print("PASS: unchanged DesignTool discovers real T3 targets, six controls, native live RGB, font/size/flags/alpha/shadow, Schema 3 Save/Load/Reset, combat and heading isolation")
