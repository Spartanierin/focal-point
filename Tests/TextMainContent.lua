-- Run from the repository root: lua54 Tests/TextMainContent.lua
local ns={L={THEME_DEFAULT="Default"}}
local function Load(path) assert(loadfile(path))("FocalPoint",ns) end
for _,path in ipairs({
    "Data/Defaults.lua", "Data/Themes.lua", "Services/CompositionPresenceStorage.lua",
    "Services/LayoutService.lua", "Services/LegacyThemeAdapter.lua", "Services/PresetService.lua",
    "Services/UserLayoutStore.lua", "Services/ActiveLayoutResolver.lua", "Services/LayoutMutations.lua",
    "Engine/Text/Shared/TextTemplateLibrary.lua", "Data/BuiltInTextTemplates.lua",
    "Engine/Text/Shared/TextTemplateUsage.lua", "Engine/Text/Shared/TextTemplateValidation.lua",
    "Services/TextTemplateEntityMigration.lua", "Services/LayoutTransferCodec.lua",
    "Services/LayoutTransferVNext.lua", "Services/LayoutTransfer.lua",
    "Engine/Text/Shared/TextElementRoles.lua", "Engine/Text/Shared/TextTemplateResolver.lua",
    "Engine/Text/Runtime/TextElementState.lua",
    "Engine/UnitFrame/Shared/UnitFrameUtils.lua", "Engine/Text/Shared/TextTemplateMutations.lua",
}) do Load(path) end
local mutations, resolver, clone=ns.TextTemplateMutations,ns.TextTemplateResolver,ns.LayoutService.Clone
local function Equal(a,b)
    if a==b then return true end
    if type(a)~="table" or type(b)~="table" then return false end
    for k,v in pairs(a) do if not Equal(v,b[k]) then return false end end
    for k in pairs(b) do if a[k]==nil then return false end end
    return true
end
local passed,failed=0,0
local function Test(name,run)
    local ok,reason=pcall(run)
    if ok then passed=passed+1; print("PASS: "..name)
    else failed=failed+1; print("FAIL: "..name..": "..tostring(reason)) end
end
local ids={}
for i,name in ipairs({"Health","Dead","Ghost","Offline","AFK","DND"}) do ids[name]="tpl:u:"..string.rep("a",32)..":1-2-"..string.rep("b",32)..":"..i end
local function Fixture()
    local text={templateId=ids.Health,tag="OLD SNAPSHOT",enabled=true,role="health",
        anchorTo="HealthBar",point="RIGHT",relativePoint="RIGHT",offsetX=-9,offsetY=3,
        font="fp:font:standard",fontSize=17,fontStyle="OUTLINE",outline=true,
        shadowOffsetX=2,shadowOffsetY=-2,shadowColor={0,0,0,0.8},color={1,0.7,0.3,1},
        overflowMode="ELLIPSIS",stateTemplateIds={dead=ids.Dead,ghost=ids.Ghost,offline=ids.Offline,afk=ids.AFK,dnd=ids.DND}}
    local payload={Units={player={Texts={text_1=text,text_2=clone(text)}}}}
    local templates={}
    for name,value in pairs({Health="CURRENT",Dead="DEAD",Ghost="GHOST",Offline="OFFLINE",AFK=ids.AFK,DND=ids.DND}) do
        templates[ids[name]]={name=name,content=value}
    end
    ns.db={profile={},char={activeLayoutId="layout:test"},global={TextTemplates=templates,UserLayouts={
        ["layout:test"]={name="Test",formatVersion=2,payload=payload},
        ["layout:other"]={name="Other",formatVersion=2,payload=clone(payload)}}}}
    ns.ActiveLayoutResolver.InvalidateActiveRuntimeRoot()
    return {db=ns.db,expectedLayoutId="layout:test"},payload,text
end
local function Runtime(payload)
    return {db=ns.db,
        GetBasicTagDependencies=function(token) return ({["hp:cur"]="health",["power:cur"]="power"})[token] end}
end
local function Retained(payload,text,before,states,main,tag)
    local expected=clone(before);expected.Units.player.Texts.text_1.templateId=main
    expected.Units.player.Texts.text_1.tag=tag
    assert(Equal(payload,expected),"fields outside main source changed")
    assert(payload.Units.player.Texts.text_1==text,"configuration identity changed")
    assert(text.stateTemplateIds==states,"state table replaced")
end
local function States(payload,text,main)
    local context=Runtime(payload)
    assert(resolver.Resolve(text,nil,context)==main)
    for state,expected in pairs({dead="DEAD",ghost="GHOST",offline="OFFLINE",afk=ids.AFK,dnd=ids.DND}) do
        assert(resolver.Resolve(text,state,context)==expected,state.." changed")
    end
    ns.db.global.TextTemplates[ids.Ghost]=nil
    assert(resolver.Resolve(text,"ghost",context)=="DEAD","ghost fallback changed")
    ns.db.global.TextTemplates[ids.Dead]=nil
    assert(resolver.Resolve(text,"ghost",context)==main)
    for _,state in ipairs({"offline","afk","dnd"}) do
        ns.db.global.TextTemplates[text.stateTemplateIds[state]]=nil
        assert(resolver.Resolve(text,state,context)==main,state.." main fallback changed")
    end
end
local function Roundtrips(payload)
    local before=clone(payload)
    local copy=ns.LayoutService.CopyPayload(payload)
    assert(Equal(copy.Units.player.Texts,payload.Units.player.Texts))
    local encoded,reason=ns.LayoutTransfer.Export("layout:test"); assert(encoded,reason)
    local ok,id=ns.LayoutTransfer.Import(encoded); assert(ok,id)
    assert(Equal(ns.db.global.UserLayouts[id].payload.Units.player.Texts,payload.Units.player.Texts))
    ok,id=ns.LayoutMutations.CopyLayout("layout:test","Duplicate",{activate=false}); assert(ok,id)
    assert(Equal(ns.db.global.UserLayouts[id].payload.Units.player.Texts,payload.Units.player.Texts))
    assert(Equal(payload,before),"roundtrip mutated source")
end
Test("Shared -> Local: current main source, atomic pair, identity, states and roundtrips",function()
    local context,payload,text=Fixture();local before=clone(payload);local states=text.stateTemplateIds
    local source=mutations.GetMainTemplateExpression(context,"player","text_1")
    assert(source.ok and source.expression=="CURRENT" and source.templateId==ids.Health)
    assert(Equal(payload,before),"read changed payload")
    local runtime=Runtime(payload)
    assert(resolver.Resolve(text,nil,runtime)=="CURRENT") -- warm candidate cache
    assert(resolver.Resolve(text,"ghost",runtime)=="GHOST")
    local invalidate=resolver.Invalidate
    local observed=false
    resolver.Invalidate=function(config)
        observed=true
        assert(config==text and config.templateId==nil and config.tag=="LOCAL [power:cur]","non-atomic pair")
        return invalidate(config)
    end
    local ok,result=pcall(mutations.SetLocalMainContent,context,"player","text_1","LOCAL [power:cur]")
    resolver.Invalidate=invalidate
    assert(ok,result);assert(result.ok and result.changed and observed)
    Retained(payload,text,before,states,nil,"LOCAL [power:cur]")
    assert(resolver.ResolveDependencies(text,runtime).power)
    Roundtrips(payload);States(payload,text,"LOCAL [power:cur]")
end)
Test("Local -> Shared: neutralizes old content, dependencies, states and roundtrips",function()
    local context,payload,text=Fixture();text.templateId=nil;text.tag="LOCAL [power:cur]"
    ns.db.global.TextTemplates[ids.Health].content="[hp:cur]"
    local before=clone(payload);local states=text.stateTemplateIds;local runtime=Runtime(payload)
    assert(resolver.Resolve(text,nil,runtime)=="LOCAL [power:cur]")
    local result=mutations.AssignMainTemplate(context,"player","text_1",ids.Health)
    assert(result.ok and result.changed)
    Retained(payload,text,before,states,ids.Health,"")
    local dependencies=resolver.ResolveDependencies(text,runtime)
    assert(dependencies.health and not dependencies.power,"stale local dependency")
    Roundtrips(payload);States(payload,text,"[hp:cur]")
    ns.db.global.TextTemplates[ids.Health]=nil
    assert(resolver.Resolve(text,nil,runtime)=="","old local content revived")
end)
Test("Legacy -> same Shared: clears snapshot once; subsequent call is idempotent",function()
    local context,payload,text=Fixture();local before=clone(payload);local states=text.stateTemplateIds
    local result=mutations.AssignMainTemplate(context,"player","text_1",ids.Health)
    assert(result.ok and result.changed)
    Retained(payload,text,before,states,ids.Health,"")
    result=mutations.AssignMainTemplate(context,"player","text_1",ids.Health)
    assert(result.ok and result.changed==false)
end)
-- Local saves require no main binding or usable previous local expression.
for index,source in ipairs({{tag="OLD"},{tag="OLD"},{tag=""},{}}) do
    Test("Local -> Local source variant "..index..", identity and roundtrips",function()
        local context,payload,text=Fixture();text.templateId=source.name;text.tag=source.tag
        -- All instances in this fixture are local; no dangling global dependency.
        for _,layout in pairs(ns.db.global.UserLayouts) do
            for _,config in pairs(layout.payload.Units.player.Texts) do config.templateId=nil end
        end
        ns.db.global.TextTemplates[ids.Health]=nil -- unrelated main entities are not required
        local before=clone(payload);local states=text.stateTemplateIds
        local read=mutations.GetMainTemplateExpression(context,"player","text_1")
        assert(not read.ok and read.errorCode=="invalid-template-id" and Equal(payload,before))
        resolver.Resolve(text,nil,Runtime(payload)) -- warm the old local candidate
        local result=mutations.SetLocalMainContent(context,"player","text_1","NEW")
        assert(result.ok and result.changed and result.cacheInvalidated)
        Retained(payload,text,before,states,nil,"NEW")
        assert(resolver.Resolve(text,nil,Runtime(payload))=="NEW")
        Roundtrips(payload);States(payload,text,"NEW")
    end)
end
Test("Local -> Local idempotence does not invalidate cache",function()
    local context,payload,text=Fixture();text.templateId=nil;text.tag="SAME"
    local before=clone(payload);local states=text.stateTemplateIds;local calls=0
    local invalidate=resolver.Invalidate
    resolver.Invalidate=function(...) calls=calls+1;return invalidate(...) end
    local ok,result=pcall(mutations.SetLocalMainContent,context,"player","text_1","SAME")
    resolver.Invalidate=invalidate
    assert(ok,result);assert(result.ok and result.changed==false and calls==0)
    Retained(payload,text,before,states,nil,"SAME")
end)
Test("Shared -> Local can be saved locally again",function()
    local context,payload,text=Fixture();local states=text.stateTemplateIds
    assert(mutations.SetLocalMainContent(context,"player","text_1","FIRST").ok)
    local before=clone(payload)
    local result=mutations.SetLocalMainContent(context,"player","text_1","SECOND")
    assert(result.ok and result.changed)
    Retained(payload,text,before,states,nil,"SECOND")
end)
for _,name in ipairs({false,42,{}," \t"}) do
    Test("ambiguous main reference is not treated as Local: "..tostring(name),function()
        local context,payload,text=Fixture();text.templateId=name;local before=clone(ns.db)
        local result=mutations.SetLocalMainContent(context,"player","text_1","NEW")
        assert(not result.ok and result.errorCode=="invalid-template-id" and Equal(ns.db,before))
    end)
end
local operations={
    localContent=function(c,u,k) return mutations.SetLocalMainContent(c,u,k,"LOCAL") end,
    shared=function(c,u,k) return mutations.AssignMainTemplate(c,u,k,ids.Health) end,
    read=function(c,u,k) return mutations.GetMainTemplateExpression(c,u,k) end,
}
local cases={
    {"invalid context",function() return false end,"invalid_context"},
    {"missing expected ID",function() return {} end,"invalid_context"},
    {"layout mismatch",function(c) c.expectedLayoutId="layout:other" end,"layout_mismatch"},
    {"read-only",function(c) c.expectedLayoutId="builtin:default";ns.db.char.activeLayoutId=c.expectedLayoutId end,"readonly_layout"},
    {"missing unit",function(c,p) p.Units.player=nil end,"unit_not_found"},
    {"missing object",function(c,p) p.Units.player.Texts.text_1=nil end,"text_element_not_found"},
    {"missing template",function(c,p) ns.db.global.TextTemplates[ids.Health]=nil end,"user-template-not-found"},
    {"invalid template value",function(c,p) ns.db.global.TextTemplates[ids.Health]={} end,"invalid-template-name"},
    {"empty template value",function(c,p) ns.db.global.TextTemplates[ids.Health].content="" end,"invalid_template_text"},
    {"blank template value",function(c,p) ns.db.global.TextTemplates[ids.Health].content=" \t\n" end,"invalid_template_text"},
}
for operation,run in pairs(operations) do
    for _,case in ipairs(cases) do
        Test(operation..": "..case[1].." leaves database unchanged",function()
            local context,payload,text=Fixture();local replacement=case[2](context,payload,text)
            if replacement~=nil then context=replacement end
            local before=clone(ns.db)
            local result=run(context,"player","text_1")
            assert(not result.ok and result.errorCode==case[3],tostring(result.errorCode))
            assert(Equal(ns.db,before),"failed operation mutated database")
        end)
    end
    for _,key in ipairs({"AltPower","ClassPower"}) do
        Test(operation..": implicit resource role "..key.." supports main content",function()
            local context,payload,text=Fixture();text.role=nil;payload.Units.player.Texts[key]=text
            local before=clone(payload);local states=text.stateTemplateIds
            local result=run(context,"player",key)
            assert(result.ok, result.errorCode)
            if operation~="read" then
                for _,k in ipairs({key,"text_1"}) do
                    before.Units.player.Texts[k].templateId=operation=="shared" and ids.Health or nil
                    before.Units.player.Texts[k].tag=operation=="shared" and "" or "LOCAL"
                end
            else
                assert(result.expression=="CURRENT")
            end
            assert(Equal(payload,before) and text.stateTemplateIds==states)
            assert(payload.Units.player.Texts[key]==text)
        end)
    end
end
for index,case in ipairs(cases) do
    if index<=6 then
        Test("Local save: "..case[1].." leaves database unchanged",function()
            local context,payload,text=Fixture();text.templateId=nil;text.tag="OLD"
            local replacement=case[2](context,payload,text)
            if replacement~=nil then context=replacement end
            local before=clone(ns.db)
            local result=mutations.SetLocalMainContent(context,"player","text_1","NEW")
            assert(not result.ok and result.errorCode==case[3] and Equal(ns.db,before))
        end)
    end
end
for _,key in ipairs({"AltPower","ClassPower"}) do
    Test("resource role "..key.." preserves identity, states and transfer",function()
        local context,payload,text=Fixture()
        text.role=key=="AltPower" and "altpower" or "classpower"
        text.anchorTo=key=="AltPower" and "AlternativePowerBar" or "ClassPowerBar"
        local before=clone(payload);local states=text.stateTemplateIds
        assert(mutations.AssignMainTemplate(context,"player","text_1",ids.Ghost).ok)
        Retained(payload,text,before,states,ids.Ghost,"")
        Roundtrips(payload)
        before=clone(payload)
        assert(mutations.SetLocalMainContent(context,"player","text_1","NEW").ok)
        Retained(payload,text,before,states,nil,"NEW")
        before=clone(payload)
        assert(mutations.SetLocalMainContent(context,"player","text_1","AGAIN").ok)
        Retained(payload,text,before,states,nil,"AGAIN")
    end)
end
for _,value in ipairs({false,""," \t\n"}) do
    Test("invalid local expression "..tostring(value),function()
        local context=Fixture();local before=clone(ns.db)
        local result=mutations.SetLocalMainContent(context,"player","text_1",value)
        assert(not result.ok and result.errorCode=="invalid_local_content");assert(Equal(ns.db,before))
    end)
    Test("Local save rejects invalid expression "..tostring(value),function()
        local context,payload,text=Fixture();text.templateId=nil;local before=clone(ns.db)
        local result=mutations.SetLocalMainContent(context,"player","text_1",value)
        assert(not result.ok and result.errorCode=="invalid_local_content" and Equal(ns.db,before))
    end)
    Test("invalid target template name "..tostring(value),function()
        local context=Fixture();local before=clone(ns.db)
        local result=mutations.AssignMainTemplate(context,"player","text_1",value)
        assert(not result.ok and result.errorCode=="invalid-template-id");assert(Equal(ns.db,before))
    end)
end
for _,name in ipairs({"Missing"}) do
    Test("broken main source never seeds from snapshot: "..name,function()
        local context,payload,text=Fixture();text.templateId=name;local before=clone(ns.db)
        local result=mutations.GetMainTemplateExpression(context,"player","text_1")
        assert(not result.ok)
        result=mutations.SetLocalMainContent(context,"player","text_1","LOCAL")
        assert(not result.ok and Equal(ns.db,before))
    end)
end
Test("explicit role overrides legacy key via existing role contract",function()
    local context,payload,text=Fixture();text.role="health";payload.Units.player.Texts.AltPower=text
    assert(mutations.AssignMainTemplate(context,"player","AltPower",ids.Health).ok)
end)
for _,mode in ipairs({"layout","object","payload","template"}) do
    Test("recheck before commit detects changed "..mode,function()
        local context,payload,text=Fixture();local original=clone(text)
        -- Inject at entity lookup, which still runs after target capture. Role
        -- resolution no longer participates in main-content permission checks.
        local library=ns.TextTemplateLibrary
        local resolve=library.ResolveTemplateEntity
        local injected=false
        library.ResolveTemplateEntity=function(...)
            local entity,reason=resolve(...)
            injected=true
            if mode=="layout" then ns.db.char.activeLayoutId="layout:other"
            elseif mode=="object" then payload.Units.player.Texts.text_1=clone(text)
            elseif mode=="payload" then ns.db.global.UserLayouts["layout:test"].payload=clone(payload)
            else ns.db.global.TextTemplates[ids.Health].content="" end
            return entity,reason
        end
        local ok,result=pcall(mutations.AssignMainTemplate,context,"player","text_1",ids.Health)
        library.ResolveTemplateEntity=resolve
        assert(injected,"stale-target injection did not execute")
        assert(ok,result);assert(not result.ok,"stale target accepted")
        assert(Equal(text,original),"old object written after identity change")
        assert(ns.db.global.UserLayouts["layout:test"].payload.Units.player.Texts.text_1.tag=="OLD SNAPSHOT")
    end)
end
Test("post-commit invalidation failure reports committed data honestly",function()
    local context,payload,text=Fixture();local before=clone(payload);local states=text.stateTemplateIds
    local invalidate=resolver.Invalidate
    resolver.Invalidate=function() error("simulated cache invalidation failure") end
    local ok,result=pcall(mutations.AssignMainTemplate,context,"player","text_1",ids.Health)
    resolver.Invalidate=invalidate
    assert(ok,result)
    assert(result.ok and result.changed and result.cacheInvalidated==false and result.cacheInvalidationError)
    Retained(payload,text,before,states,ids.Health,"")
end)
Test("existing full-refresh path renews frame dependency bindings after source switch",function()
    local context,payload,text=Fixture();local runtime=Runtime(payload)
    ns.db.global.TextTemplates[ids.Health].content="[hp:cur]";text.tag=""
    local frame={}
    ns.TextElementState.SetDependencies(frame,"text_1",resolver.ResolveDependencies(text,runtime))
    assert(ns.TextElementState.GetDependencies(frame,"text_1").health)
    local result=mutations.SetLocalMainContent(context,"player","text_1","[power:cur]")
    assert(result.ok and result.changed and result.cacheInvalidated)
    ns.TextElementState.MarkDirty(frame,"test caller refresh","full")
    assert(ns.TextElementState.GetDependencies(frame,"text_1")==nil)
    ns.TextElementState.SetDependencies(frame,"text_1",resolver.ResolveDependencies(text,runtime))
    local dependencies=ns.TextElementState.GetDependencies(frame,"text_1")
    assert(dependencies.power and not dependencies.health)
end)
Test("missing global entity is not reconstructed from another layout reference",function()
    local context,payload=Fixture();ns.db.global.TextTemplates[ids.Health]=nil
    local before=clone(ns.db)
    local result=mutations.AssignMainTemplate(context,"player","text_1",ids.Health)
    assert(not result.ok and result.errorCode=="user-template-not-found" and Equal(ns.db,before))
end)
Test("missing unit store and missing layout never trigger repair",function()
    for _,part in ipairs({"Units","record"}) do
        local context,payload=Fixture()
        if part=="record" then ns.db.global.UserLayouts["layout:test"]=nil else payload[part]=nil end
        local before=clone(ns.db)
        local result=mutations.AssignMainTemplate(context,"player","text_1",ids.Health)
        assert(not result.ok and result.errorCode=="invalid_context" and Equal(ns.db,before))
    end
end)
Test("loading new APIs leaves legacy hybrid data untouched",function()
    Fixture();local before=clone(ns.db);Load("Engine/Text/Shared/TextTemplateMutations.lua")
    assert(Equal(ns.db,before))
end)
print(string.format("Main content: %d passed, %d failed",passed,failed))
assert(failed==0,"main content regressions")
