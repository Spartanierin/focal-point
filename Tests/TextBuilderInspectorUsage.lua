-- lua54 Tests/TextBuilderInspectorUsage.lua
-- Execute the actual scoped Inspector helper without constructing unrelated UI.
-- No copy of its scan logic: the helper is read from the current product file.
local ns={L={THEME_DEFAULT="Default"}}
local function Load(path) assert(loadfile(path))("FocalPoint",ns) end
for _,path in ipairs({"Data/Defaults.lua","Services/CompositionPresenceStorage.lua",
    "Services/LayoutService.lua","Services/UserLayoutStore.lua","Services/ActiveLayoutResolver.lua",
    "Engine/Text/Shared/TextTemplateUsage.lua"}) do Load(path) end
local payload={TextTemplates={Present="[name]"},Units={player={Texts={
    Test={templateName="Missing main",stateTemplates={dead="Missing state"}},
    Clean={templateName="Present"},
}}}}
ns.db={char={activeLayoutId="layout:test"},global={UserLayouts={
    ["layout:test"]={name="Test",formatVersion=1,payload=payload},
}},profile={TextTemplates={["Missing main"]="legacy main",["Missing state"]="legacy state"},
    Units={player={Texts={Clean={templateName="Legacy missing"}}}}}}
local file=assert(io.open("GUI/Editor/Inspector/InspectorController.lua"))
local source=file:read("*a"); file:close()
local first=assert(source:find("    local function BuildMissingTemplateMessages(textId)",1,true))
local last=assert(source:find("    local function ResolveIndicatorContext()",first,true))
local build=assert(load("local ns, selectedUnit = ...\n"..source:sub(first,last-1)
    .."\nreturn BuildMissingTemplateMessages","@Inspector/LayoutUsage"))(ns,"player")
local resolver=ns.ActiveLayoutResolver
local getPayload=resolver.GetActivePayloadRoot
local calls=0
resolver.GetActivePayloadRoot=function(...)
    calls=calls+1
    return getPayload(...)
end
resolver.EnsureEditableForMutation=function() error("read-only scan requested a mutation context") end
ns.TextTemplateUsage.ScanActiveProfileTemplateAssignments=function() error("legacy profile scan used") end
local messages=build("Test")
assert(calls==1,"Inspector must capture exactly one canonical payload")
assert(#messages==2)
assert(messages[1]:find('"Missing main"',1,true) and messages[1]:find("active layout",1,true))
assert(messages[2]:find("dead -> Missing state",1,true))
calls=0; assert(#build("Clean")==0 and calls==1,"legacy-only missing reference leaked into layout warnings")
payload.TextTemplates["Missing main"]="[name]"
payload.TextTemplates["Missing state"]="[status]"
assert(#build("Test")==0)
resolver.GetActivePayloadRoot=function() return nil,"unavailable" end
assert(#build("Clean")==0,"missing layout must not fall back to profile")
print("PASS: Inspector main/state warnings use one canonical layout read; no profile fallback or mutation context")
