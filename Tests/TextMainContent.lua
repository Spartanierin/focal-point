-- Run from the repository root: lua54 Tests/TextMainContent.lua
local ns={L={THEME_DEFAULT="Default"}}
local function Load(path) assert(loadfile(path))("FocalPoint",ns) end
for _,path in ipairs({
    "Data/Defaults.lua", "Data/Themes.lua", "Services/CompositionPresenceStorage.lua",
    "Services/LayoutService.lua", "Services/LegacyThemeAdapter.lua", "Services/PresetService.lua",
    "Services/UserLayoutStore.lua", "Services/ActiveLayoutResolver.lua", "Services/LayoutMutations.lua",
    "Services/LayoutTransferCodec.lua", "Services/LayoutTransfer.lua",
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
local function Fixture()
    local text={templateName="Health",tag="OLD SNAPSHOT",enabled=true,role="health",
        anchorTo="HealthBar",point="RIGHT",relativePoint="RIGHT",offsetX=-9,offsetY=3,
        font="fp:font:standard",fontSize=17,fontStyle="OUTLINE",outline=true,
        shadowOffsetX=2,shadowOffsetY=-2,shadowColor={0,0,0,0.8},color={1,0.7,0.3,1},
        overflowMode="ELLIPSIS",stateTemplates={dead="Dead",ghost="Ghost",offline="Offline",afk="AFK",dnd="DND"}}
    local payload={Units={player={Texts={text_1=text,text_2=clone(text)}}},
        TextTemplates={Health="CURRENT",Dead="DEAD",Ghost="GHOST",Offline="OFFLINE",AFK="AFK",DND="DND"}}
    ns.db={profile={},char={activeLayoutId="layout:test"},global={UserLayouts={
        ["layout:test"]={name="Test",formatVersion=1,payload=payload},
        ["layout:other"]={name="Other",formatVersion=1,payload=clone(payload)}}}}
    ns.ActiveLayoutResolver.InvalidateActiveRuntimeRoot()
    return {expectedLayoutId="layout:test"},payload,text
end
local function Runtime(payload)
    return {GetTemplate=function(name) return payload.TextTemplates[name] end,
        GetBasicTagDependencies=function(token) return ({["hp:cur"]="health",["power:cur"]="power"})[token] end}
end
local function Retained(payload,text,before,states,main,tag)
    local expected=clone(before);expected.Units.player.Texts.text_1.templateName=main
    expected.Units.player.Texts.text_1.tag=tag
    assert(Equal(payload,expected),"fields outside main source changed")
    assert(payload.Units.player.Texts.text_1==text,"configuration identity changed")
    assert(text.stateTemplates==states,"state table replaced")
end
local function States(payload,text,main)
    local context=Runtime(payload)
    assert(resolver.Resolve(text,nil,context)==main)
    for state,expected in pairs({dead="DEAD",ghost="GHOST",offline="OFFLINE",afk="AFK",dnd="DND"}) do
        assert(resolver.Resolve(text,state,context)==expected,state.." changed")
    end
    payload.TextTemplates.Ghost=nil
    assert(resolver.Resolve(text,"ghost",context)=="DEAD","ghost fallback changed")
    payload.TextTemplates.Dead=nil
    assert(resolver.Resolve(text,"ghost",context)==main)
    for _,state in ipairs({"offline","afk","dnd"}) do
        payload.TextTemplates[text.stateTemplates[state]]=nil
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
    local context,payload,text=Fixture();local before=clone(payload);local states=text.stateTemplates
    local source=mutations.GetMainTemplateExpression(context,"player","text_1")
    assert(source.ok and source.expression=="CURRENT" and source.templateName=="Health")
    assert(Equal(payload,before),"read changed payload")
    local runtime=Runtime(payload)
    assert(resolver.Resolve(text,nil,runtime)=="CURRENT") -- warm candidate cache
    assert(resolver.Resolve(text,"ghost",runtime)=="GHOST")
    local invalidate=resolver.Invalidate
    local observed=false
    resolver.Invalidate=function(config)
        observed=true
        assert(config==text and config.templateName=="" and config.tag=="LOCAL [power:cur]","non-atomic pair")
        return invalidate(config)
    end
    local ok,result=pcall(mutations.SetLocalMainContent,context,"player","text_1","LOCAL [power:cur]")
    resolver.Invalidate=invalidate
    assert(ok,result);assert(result.ok and result.changed and observed)
    Retained(payload,text,before,states,"","LOCAL [power:cur]")
    assert(resolver.ResolveDependencies(text,runtime).power)
    Roundtrips(payload);States(payload,text,"LOCAL [power:cur]")
end)
Test("Local -> Shared: neutralizes old content, dependencies, states and roundtrips",function()
    local context,payload,text=Fixture();text.templateName="";text.tag="LOCAL [power:cur]"
    payload.TextTemplates.Health="[hp:cur]"
    local before=clone(payload);local states=text.stateTemplates;local runtime=Runtime(payload)
    assert(resolver.Resolve(text,nil,runtime)=="LOCAL [power:cur]")
    local result=mutations.AssignMainTemplate(context,"player","text_1","Health")
    assert(result.ok and result.changed)
    Retained(payload,text,before,states,"Health","")
    local dependencies=resolver.ResolveDependencies(text,runtime)
    assert(dependencies.health and not dependencies.power,"stale local dependency")
    Roundtrips(payload);States(payload,text,"[hp:cur]")
    payload.TextTemplates.Health=nil
    assert(resolver.Resolve(text,nil,runtime)=="","old local content revived")
end)
Test("Legacy -> same Shared: clears snapshot once; subsequent call is idempotent",function()
    local context,payload,text=Fixture();local before=clone(payload);local states=text.stateTemplates
    local result=mutations.AssignMainTemplate(context,"player","text_1","Health")
    assert(result.ok and result.changed)
    Retained(payload,text,before,states,"Health","")
    result=mutations.AssignMainTemplate(context,"player","text_1","Health")
    assert(result.ok and result.changed==false)
end)
local operations={
    localContent=function(c,u,k) return mutations.SetLocalMainContent(c,u,k,"LOCAL") end,
    shared=function(c,u,k) return mutations.AssignMainTemplate(c,u,k,"Health") end,
    read=function(c,u,k) return mutations.GetMainTemplateExpression(c,u,k) end,
}
local cases={
    {"invalid context",function() return false end,"invalid_context"},
    {"missing expected ID",function() return {} end,"invalid_context"},
    {"layout mismatch",function(c) c.expectedLayoutId="layout:other" end,"layout_mismatch"},
    {"read-only",function(c) c.expectedLayoutId="builtin:default";ns.db.char.activeLayoutId=c.expectedLayoutId end,"readonly_layout"},
    {"missing unit",function(c,p) p.Units.player=nil end,"unit_not_found"},
    {"missing object",function(c,p) p.Units.player.Texts.text_1=nil end,"text_element_not_found"},
    {"missing template",function(c,p) p.TextTemplates.Health=nil end,"template_not_found"},
    {"invalid template value",function(c,p) p.TextTemplates.Health={} end,"invalid_template_text"},
    {"empty template value",function(c,p) p.TextTemplates.Health="" end,"invalid_template_text"},
    {"blank template value",function(c,p) p.TextTemplates.Health=" \t\n" end,"invalid_template_text"},
    {"explicit altpower",function(c,p,t) t.role="altpower" end,"unsupported_text_role"},
    {"explicit classpower",function(c,p,t) t.role="classpower" end,"unsupported_text_role"},
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
        Test(operation..": implicit legacy "..key.." role rejected",function()
            local context,payload,text=Fixture();text.role=nil;payload.Units.player.Texts[key]=text
            local before=clone(ns.db);local result=run(context,"player",key)
            assert(not result.ok and result.errorCode=="unsupported_text_role")
            assert(Equal(ns.db,before))
        end)
    end
end
for _,value in ipairs({false,""," \t\n"}) do
    Test("invalid local expression "..tostring(value),function()
        local context=Fixture();local before=clone(ns.db)
        local result=mutations.SetLocalMainContent(context,"player","text_1",value)
        assert(not result.ok and result.errorCode=="invalid_local_content");assert(Equal(ns.db,before))
    end)
    Test("invalid target template name "..tostring(value),function()
        local context=Fixture();local before=clone(ns.db)
        local result=mutations.AssignMainTemplate(context,"player","text_1",value)
        assert(not result.ok and result.errorCode=="invalid_template_name");assert(Equal(ns.db,before))
    end)
end
for _,name in ipairs({"","Missing"}) do
    Test("broken main source never seeds from snapshot: "..name,function()
        local context,payload,text=Fixture();text.templateName=name;local before=clone(ns.db)
        local result=mutations.GetMainTemplateExpression(context,"player","text_1")
        assert(not result.ok)
        result=mutations.SetLocalMainContent(context,"player","text_1","LOCAL")
        assert(not result.ok and Equal(ns.db,before))
    end)
end
Test("explicit role overrides legacy key via existing role contract",function()
    local context,payload,text=Fixture();text.role="health";payload.Units.player.Texts.AltPower=text
    assert(mutations.AssignMainTemplate(context,"player","AltPower","Health").ok)
end)
for _,mode in ipairs({"layout","object","payload","template"}) do
    Test("recheck before commit detects changed "..mode,function()
        local context,payload,text=Fixture();local original=clone(text)
        local resolve=ns.TextElementRoles.Resolve
        ns.TextElementRoles.Resolve=function(...)
            local role=resolve(...)
            if mode=="layout" then ns.db.char.activeLayoutId="layout:other"
            elseif mode=="object" then payload.Units.player.Texts.text_1=clone(text)
            elseif mode=="payload" then ns.db.global.UserLayouts["layout:test"].payload=clone(payload)
            else payload.TextTemplates.Health="" end
            return role
        end
        local ok,result=pcall(mutations.AssignMainTemplate,context,"player","text_1","Health")
        ns.TextElementRoles.Resolve=resolve
        assert(ok,result);assert(not result.ok,"stale target accepted")
        assert(Equal(text,original),"old object written after identity change")
        assert(ns.db.global.UserLayouts["layout:test"].payload.Units.player.Texts.text_1.tag=="OLD SNAPSHOT")
    end)
end
Test("post-commit invalidation failure reports committed data honestly",function()
    local context,payload,text=Fixture();local before=clone(payload);local states=text.stateTemplates
    local invalidate=resolver.Invalidate
    resolver.Invalidate=function() error("simulated cache invalidation failure") end
    local ok,result=pcall(mutations.AssignMainTemplate,context,"player","text_1","Health")
    resolver.Invalidate=invalidate
    assert(ok,result)
    assert(result.ok and result.changed and result.cacheInvalidated==false and result.cacheInvalidationError)
    Retained(payload,text,before,states,"Health","")
end)
Test("existing full-refresh path renews frame dependency bindings after source switch",function()
    local context,payload,text=Fixture();local runtime=Runtime(payload)
    payload.TextTemplates.Health="[hp:cur]";text.tag=""
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
Test("template existing only in another layout is not materialized or assigned",function()
    local context,payload=Fixture();payload.TextTemplates.Health=nil
    local before=clone(ns.db)
    local result=mutations.AssignMainTemplate(context,"player","text_1","Health")
    assert(not result.ok and result.errorCode=="template_not_found" and Equal(ns.db,before))
end)
Test("missing unit store and missing layout never trigger repair",function()
    for _,part in ipairs({"Units","TextTemplates","record"}) do
        local context,payload=Fixture()
        if part=="record" then ns.db.global.UserLayouts["layout:test"]=nil else payload[part]=nil end
        local before=clone(ns.db)
        local result=mutations.AssignMainTemplate(context,"player","text_1","Health")
        assert(not result.ok and result.errorCode=="invalid_context" and Equal(ns.db,before))
    end
end)
Test("loading new APIs leaves legacy hybrid data untouched",function()
    Fixture();local before=clone(ns.db);Load("Engine/Text/Shared/TextTemplateMutations.lua")
    assert(Equal(ns.db,before))
end)
print(string.format("Main content: %d passed, %d failed",passed,failed))
assert(failed==0,"main content regressions")
