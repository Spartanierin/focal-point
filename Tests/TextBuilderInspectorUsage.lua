-- lua54 Tests/TextBuilderInspectorUsage.lua
-- Execute the actual scoped Inspector helper without constructing unrelated UI.
-- No copy of its scan logic: the helper is read from the current product file.
local ns={L={THEME_DEFAULT="Default"}}
local function Load(path) assert(loadfile(path))("FocalPoint",ns) end
for _,path in ipairs({"Data/Defaults.lua","Services/CompositionPresenceStorage.lua",
    "Services/LayoutService.lua","Services/UserLayoutStore.lua","Services/ActiveLayoutResolver.lua",
    "Engine/Text/Shared/TextTemplateLibrary.lua","Data/BuiltInTextTemplates.lua",
    "Engine/Text/Shared/TextTemplateUsage.lua"}) do Load(path) end
local main,state="tpl:b:missing-main","tpl:b:missing-state"
local payload={Units={player={Texts={
    Test={templateId=main,stateTemplateIds={dead=state}},
    Clean={templateId="tpl:b:default-001"}, Local={tag="[name]"},
}}}}
ns.db={char={activeLayoutId="layout:test"},global={UserLayouts={
    ["layout:test"]={name="Test",formatVersion=2,payload=payload},
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
assert(messages[1]:find(main,1,true))
assert(messages[2]:find(state,1,true) and messages[2]:find("(dead)",1,true))
assert(#build("Local")==0)
calls=0; assert(#build("Clean")==0 and calls==1,"legacy-only missing reference leaked into layout warnings")
payload.Units.player.Texts.Test.templateId="tpl:b:default-001"
payload.Units.player.Texts.Test.stateTemplateIds.dead="tpl:b:default-002"
assert(#build("Test")==0)
resolver.GetActivePayloadRoot=function() return nil,"unavailable" end
assert(#build("Clean")==0,"missing layout must not fall back to profile")

-- Exercise the actual template-label branch from the current Inspector source.
-- This keeps the test coupled to the product branch without reimplementing it.
local labelFirst=assert(source:find("        local templateLabel = ",1,true))
local labelLast=assert(source:find("        if isScopedObject then",labelFirst,true))
local resolveCalls={}
ns.TextTemplateLibrary={ResolveTemplateEntity=function(templateId)
    resolveCalls[#resolveCalls+1]=templateId
    if templateId=="tpl:u:custom-001" then return {name="User text"} end
    if templateId=="tpl:b:default-001" then return {name="Built-in text"} end
end}
local makeLabel=assert(load("return function(inspectorContext,textConfig,linkedTemplateName)\n"
    ..source:sub(labelFirst,labelLast-1).."\nreturn templateLabel\nend",
    "@Inspector/TemplateLabel","t",setmetatable({ns=ns,L={EDITOR_TEXT_DIRECT_TEMPLATE="Direct Template",
        MEDIA_LIBRARY_MISSING="Missing"}},{__index=_G})))()
local objectLocal={tag="[name]"}
assert(makeLabel({entity=true},objectLocal,nil)=="Local")
assert(objectLocal.templateId==nil)
assert(makeLabel({entity=true},{templateId="tpl:u:custom-001"},nil):find("User text",1,true))
assert(makeLabel({entity=true},{templateId="tpl:b:default-001"},nil):find("Built-in text",1,true))
assert(makeLabel({entity=true},{templateId="tpl:b:unknown-999"},nil)=="Missing")
assert(#resolveCalls==3 and resolveCalls[1]=="tpl:u:custom-001"
    and resolveCalls[2]=="tpl:b:default-001" and resolveCalls[3]=="tpl:b:unknown-999")
print("PASS: Inspector main/state warnings use one canonical layout read; no profile fallback or mutation context; object-local and entity labels distinguish missing IDs")
