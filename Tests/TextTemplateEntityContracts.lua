-- lua54 Tests/TextTemplateEntityContracts.lua
-- E4 uses explicit independent databases only; no active runtime cutover.
local ns = {}
local function Load(path) assert(loadfile(path))('FocalPoint', ns) end
Load('Data/Defaults.lua')
Load('Data/Themes.lua')
for _, name in ipairs({'TextTemplateLibrary', 'TextElementRoles', 'TextTemplateResolver',
    'TextTemplateUsage', 'TextTemplateValidation', 'TextTemplateMutations'}) do
    Load('Engine/Text/Shared/' .. name .. '.lua')
end
Load('Data/BuiltInTextTemplates.lua')
Load('Services/TextTemplateEntityMigration.lua')
local L, R, U, V, M = ns.TextTemplateLibrary, ns.TextTemplateResolver.Entity,
    ns.TextTemplateUsage, ns.TextTemplateValidation, ns.TextTemplateMutations.Entity
local passed = 0
local function Test(name, run) run(); passed = passed + 1; print('PASS: ' .. name) end
local function Copy(v)
    if type(v) ~= 'table' then return v end
    local r = {}; for k, x in pairs(v) do r[k] = Copy(x) end; return r
end
local function Equal(a, b)
    if a == b then return true end
    if type(a) ~= 'table' or type(b) ~= 'table' then return false end
    for k, v in pairs(a) do if not Equal(v, b[k]) then return false end end
    for k in pairs(b) do if a[k] == nil then return false end end
    return true
end
local function Id(n) return 'tpl:u:' .. string.rep('a', 32) .. ':1-2-' .. string.rep('b', 32) .. ':' .. n end
local A, B, D, G, missing, builtin = Id(1), Id(2), Id(3), Id(4), Id(99), 'tpl:b:default-013'
local function Generator()
    return assert(L.CreateUserTemplateIdGenerator({time = function() return 5 end,
        uptime = function() return 1 end, random = function() return 2 end}))
end
local function Fixture()
    local text = {templateId = A, tag = 'inline', stateTemplateIds = {dead = D, ghost = G},
        enabled = false, role = 'health', color = {1, .5, 0}, fontSize = 17, anchorTo = 'HealthBar'}
    local layouts = {['layout:A'] = {payload = {Units = {player = {Texts = {Health = text,
        duplicate = Copy(text)}}}, composition = {objects = {Health = true}}}}}
    local db = {char = {activeLayoutId = 'layout:A'}, global = {UserLayouts = layouts,
        TextTemplates = {[A] = {name = 'Same', content = '[hp:cur]'},
            [B] = {name = 'Same', content = '[power:cur]'},
            [D] = {name = 'Dead', content = 'dead'}, [G] = {name = 'Ghost', content = 'ghost'}}}}
    return db, {db = db, expectedLayoutId = 'layout:A'}, text, layouts
end
local function Ok(result) assert(result.ok, result.errorCode); return result end
local function FailUnchanged(db, run, code)
    local before = Copy(db); local result = run()
    assert(not result.ok, 'unexpected success')
    if code then assert(result.errorCode == code, tostring(result.errorCode)) end
    assert(Equal(db, before), 'failed operation wrote data')
end
Test('explicit ID contracts exist before any cutover', function()
    assert(R and R.Resolve and M and M.AssignMainTemplate, 'E4 explicit contracts missing')
end)
Test('User/Built-in IDs and same-name identity; object-local tag', function()
    local db = Fixture()
    assert(R.Resolve({templateId = A}, nil, {db = db}) == '[hp:cur]')
    assert(R.Resolve({templateId = B}, nil, {db = db}) == '[power:cur]')
    assert(R.Resolve({templateId = builtin}, nil, {db = db}) == '[cast:time]')
    assert(R.Resolve({tag = 'local'}, nil, {db = db}) == 'local')
end)
Test('unknown ID uses only existing runtime fallback, never a name/map/default', function()
    local db = Fixture()
    local context = {db = db, GetTemplate = function() error('legacy lookup') end}
    assert(R.Resolve({templateId = missing, templateName = 'Same'}, nil, context) == '')
    assert(R.Resolve({templateId = missing, tag = 'inline'}, nil, context) == 'inline')
    assert(R.ResolveReference({templateId = missing}).templateId == missing)
end)
Test('dead, ghost, ghost-to-dead, main and inline fallback', function()
    local db, _, text = Fixture(); local ctx = {db = db}
    assert(R.Resolve(text, 'dead', ctx) == 'dead')
    assert(R.Resolve(text, 'ghost', ctx) == 'ghost')
    text.stateTemplateIds.ghost = nil; R.Invalidate(text)
    assert(R.Resolve(text, 'ghost', ctx) == 'dead')
    text.stateTemplateIds.dead = missing; R.Invalidate(text)
    assert(R.Resolve(text, 'ghost', ctx) == '[hp:cur]')
    text.templateId = nil; text.stateTemplateIds = nil; R.Invalidate(text)
    assert(R.Resolve(text, 'ghost', ctx) == 'inline')
end)
Test('persisted absence is complete despite available default dead binding', function()
    assert(ns:GetDefaultDB().profile.Units.target.Texts.Health.stateTemplateIds.dead)
    local db, _, _, layouts = Fixture()
    local text = {tag = 'persisted'}
    layouts['layout:A'].payload.Units.target = {Texts = {Health = text}}
    local before = Copy(db)
    assert(R.Resolve(text, 'dead', {db = db}) == 'persisted')
    assert(V.ValidateEntityLayouts(layouts, db).valid)
    assert(Equal(db, before) and text.stateTemplateIds == nil)
end)
Test('ID dependencies share token and role handling without content caching', function()
    local db, _, text = Fixture()
    local ctx = {db = db, GetTokenDependencies = function(token) return token == 'hp:cur' and 'health' or 'power' end,
        GetRoleDependencies = function() return 'identity' end}
    local deps = R.ResolveDependencies(text, ctx); assert(deps.health and deps.static == nil)
    assert(R.ResolveDependencies({}, ctx).identity)
end)
Test('usage spans layouts, main/state and disabled objects; equal names stay separate', function()
    local db, _, _, layouts = Fixture()
    layouts['layout:B'] = {payload = {Units = {target = {Texts = {x = {stateTemplateIds = {dead = A}}}}}}}
    layouts['layout:C'] = {payload = {Units = {focus = {Texts = {x = {templateId = A}, y = {templateId = B}}}}}}
    local refs = U.ScanEntities(layouts, A); assert(#refs == 4)
    local seen = {}; for _, ref in ipairs(refs) do
        assert(ref.templateId == A and ref.unitKey and ref.textKey)
        seen[ref.layoutId] = true
        assert(ref.referenceKind == 'main' or ref.referenceKind == 'state')
        if ref.referenceKind == 'state' then assert(ref.stateKey == 'dead') end
    end
    assert(seen['layout:A'] and seen['layout:B'] and seen['layout:C'])
    assert(#U.ScanEntities(layouts, B) == 1 and V.ValidateEntityLayouts(layouts, db).valid)
end)
Test('validation rejects unknown/malformed IDs, old fields and false without repair', function()
    for _, change in ipairs({{templateId = missing}, {templateId = false}, {templateId = ''},
        {templateName = ''}, {stateTemplates = {}}, {stateTemplateIds = false},
        {stateTemplateIds = {dead = false}}, {stateTemplateIds = {dead = 'Same'}},
        {stateTemplateIds = {[''] = A}}, {tag = false}}) do
        local db, _, text, layouts = Fixture()
        for k, v in pairs(change) do text[k] = v end
        local before = Copy(db); local result = V.ValidateEntityLayouts(layouts, db)
        assert(not result.valid and #result.issues > 0); assert(Equal(db, before))
    end
    local db, _, _, layouts = Fixture(); layouts['layout:A'].payload.TextTemplates = {}
    assert(not V.ValidateEntityLayouts(layouts, db).valid)
end)
Test('unreferenced global records, empty content, object-local and Built-ins are valid', function()
    local db, _, text, layouts = Fixture()
    db.global.TextTemplates[missing] = {name = 'Unused', content = ''}
    text.templateId = builtin; text.stateTemplateIds = nil
    assert(V.ValidateEntityLayouts(layouts, db).valid)
    text.templateId = nil; assert(V.ValidateEntityLayouts(layouts, db).valid)
end)
Test('main read ignores state, tag and render fallback; missing source is rejected', function()
    local db, ctx, text = Fixture()
    assert(Ok(M.GetMainTemplateExpression(ctx, 'player', 'Health')).expression == '[hp:cur]')
    text.templateId = missing
    FailUnchanged(db, function() return M.GetMainTemplateExpression(ctx, 'player', 'Health') end)
    FailUnchanged(db, function() return M.SetLocalMainContent(ctx, 'player', 'Health', 'new') end)
    text.templateId = nil
    FailUnchanged(db, function() return M.GetMainTemplateExpression(ctx, 'player', 'Health') end)
end)
Test('main assign/local/local preserve object keys, states, style and composition', function()
    local db, ctx, text, layouts = Fixture()
    local payload = layouts['layout:A'].payload; local texts = payload.Units.player.Texts
    local states, color, composition, other = text.stateTemplateIds, text.color, payload.composition, Copy(texts.duplicate)
    Ok(M.AssignMainTemplate(ctx, 'player', 'Health', builtin)); assert(text.templateId == builtin and text.tag == '')
    Ok(M.SetLocalMainContent(ctx, 'player', 'Health', 'local')); assert(text.templateId == nil and text.tag == 'local')
    Ok(M.SetLocalMainContent(ctx, 'player', 'Health', 'local 2')); assert(text.tag == 'local 2')
    assert(not Ok(M.SetLocalMainContent(ctx, 'player', 'Health', 'local 2')).changed)
    Ok(M.AssignMainTemplate(ctx, 'player', 'Health', B)); assert(text.templateId == B and text.tag == '')
    assert(texts.Health == text and text.stateTemplateIds == states and text.color == color)
    assert(payload.composition == composition and text.enabled == false and text.fontSize == 17)
    assert(Equal(texts.duplicate, other) and text.templateName == nil)
end)
Test('main and state failures are atomic; context/layout/role safety', function()
    local db, ctx, text = Fixture()
    FailUnchanged(db, function() return M.AssignMainTemplate(ctx, 'player', 'Health', missing) end)
    FailUnchanged(db, function() return M.AssignMainTemplate(ctx, 'player', 'missing', A) end)
    FailUnchanged(db, function() return M.SetLocalMainContent(ctx, 'player', 'Health', ' ') end)
    ctx.expectedLayoutId = 'layout:B'
    FailUnchanged(db, function() return M.AssignMainTemplate(ctx, 'player', 'Health', A) end, 'layout_mismatch')
    ctx.expectedLayoutId = 'builtin:default'; db.char.activeLayoutId = ctx.expectedLayoutId
    FailUnchanged(db, function() return M.AssignMainTemplate(ctx, 'player', 'Health', A) end, 'readonly_layout')
    ctx.expectedLayoutId = 'layout:A'; db.char.activeLayoutId = ctx.expectedLayoutId
    text.role = 'classpower'
    FailUnchanged(db, function() return M.SetLocalMainContent(ctx, 'player', 'Health', 'x') end, 'unsupported_text_role')
end)
Test('state assign/unassign preserves main and object; no false/ghost FK', function()
    local db, ctx, text = Fixture()
    Ok(M.UnassignStateTemplate(ctx, 'player', 'Health', 'ghost'))
    assert(text.stateTemplateIds.ghost == nil and R.Resolve(text, 'ghost', {db = db}) == 'dead')
    Ok(M.AssignStateTemplate(ctx, 'player', 'Health', 'dead', builtin))
    assert(text.templateId == A and text.tag == 'inline' and text.stateTemplateIds.dead == builtin)
    FailUnchanged(db, function() return M.AssignStateTemplate(ctx, 'player', 'Health', 'dead', missing) end)
    FailUnchanged(db, function() return M.AssignStateTemplate(ctx, 'player', 'Health', '', A) end)
    Ok(M.UnassignStateTemplate(ctx, 'player', 'Health', 'dead')); assert(text.stateTemplateIds == nil)
    assert(not Ok(M.UnassignStateTemplate(ctx, 'player', 'Health', 'dead')).changed)
end)
Test('lookup-side context/object/record changes abort before main or state writes', function()
    for _, operation in ipairs({'main', 'local', 'state'}) do
        for _, sabotage in ipairs({'layout', 'object', 'record', 'states', 'db'}) do
            local db, ctx, text, layouts = Fixture()
            local lookup = L.ResolveTemplateEntity
            L.ResolveTemplateEntity = function(id, source)
                local entity, err = lookup(id, source)
                if sabotage == 'layout' then db.char.activeLayoutId = 'layout:B'
                elseif sabotage == 'object' then layouts['layout:A'].payload.Units.player.Texts.Health = Copy(text)
                elseif sabotage == 'record' then db.global.TextTemplates[id].content = 'concurrent'
                elseif sabotage == 'states' then text.stateTemplateIds.dead = B
                else ctx.db = nil end
                return entity, err
            end
            local result
            if operation == 'main' then result = M.AssignMainTemplate(ctx, 'player', 'Health', B)
            elseif operation == 'local' then result = M.SetLocalMainContent(ctx, 'player', 'Health', 'new local')
            else result = M.AssignStateTemplate(ctx, 'player', 'Health', 'ghost', B) end
            L.ResolveTemplateEntity = lookup
            assert(not result.ok, operation .. '/' .. sabotage)
            assert(text.templateId == A and text.tag == 'inline' and text.stateTemplateIds.ghost == G)
        end
    end
end)
Test('cache invalidation failure does not turn a committed mutation into failure', function()
    local db, ctx, text = Fixture()
    local invalidate = ns.TextTemplateResolver.Invalidate
    ns.TextTemplateResolver.Invalidate = function() error('refresh unavailable') end
    local result = Ok(M.SetLocalMainContent(ctx, 'player', 'Health', 'committed'))
    assert(result.cacheInvalidated == false and result.cacheInvalidationError)
    assert(text.templateId == nil and text.tag == 'committed')
    ns.TextTemplateResolver.Invalidate = invalidate
    invalidate(text)
end)
Test('delete fails closed for incomplete or legacy graphs and stale records', function()
    local db, _, _, layouts = Fixture(); local expected = L.GetUserTemplateRecord(B, db)
    layouts['layout:B'] = {payload = {Units = false}}
    FailUnchanged(db, function() return M.DeleteTemplate(db, B, expected) end, 'invalid_context')
    layouts['layout:B'] = {payload = {Units = {}, TextTemplates = {}}}
    FailUnchanged(db, function() return M.DeleteTemplate(db, B, expected) end, 'invalid_context')
    layouts['layout:B'] = nil; expected.content = 'stale'
    FailUnchanged(db, function() return M.DeleteTemplate(db, B, expected) end, 'template-conflict')
end)
Test('entity create/copy allow equal names and content but generate independent User IDs', function()
    local db = Fixture(); local generator = Generator()
    local one = Ok(M.CreateTemplate(db, 'Same', '[hp:cur]', generator)).templateId
    local two = Ok(M.CopyTemplate(db, A, generator)).templateId
    local three = Ok(M.CopyTemplate(db, builtin, generator)).templateId
    assert(one ~= two and two ~= A and L.GetTemplateIdKind(three) == 'user')
    assert(Equal(L.GetUserTemplateRecord(two, db), L.GetUserTemplateRecord(A, db)))
    assert(L.GetUserTemplateRecord(three, db).content == '[cast:time]')
    FailUnchanged(db, function() return M.CreateTemplate(db, ' ', 'bad', generator) end)
end)
Test('entity rename/update preserve IDs and FKs; cache reads fresh content by ID', function()
    local db, _, text, layouts = Fixture(); local before = Copy(layouts)
    assert(R.Resolve(text, nil, {db = db}) == '[hp:cur]')
    local expected = L.GetUserTemplateRecord(A, db)
    Ok(M.RenameTemplate(db, A, expected, 'New name'))
    assert(Equal(layouts, before) and L.GetUserTemplateRecord(A, db).name == 'New name')
    FailUnchanged(db, function() return M.UpdateTemplate(db, A, expected, 'stale') end, 'template-conflict')
    Ok(M.UpdateTemplate(db, A, L.GetUserTemplateRecord(A, db), 'changed'))
    assert(R.Resolve(text, nil, {db = db}) == 'changed')
    assert(R.Resolve({templateId = B}, nil, {db = db}) == '[power:cur]' and Equal(layouts, before))
end)
Test('content update is fresh in warmed caches while equal-name entities stay independent', function()
    local db, ctx, text = Fixture()
    local other = {templateId = B}
    local runtime = {db = db, GetTokenDependencies = function(token)
        return token == 'hp:cur' and 'health' or 'power'
    end}
    assert(R.Resolve(text, nil, runtime) == '[hp:cur]')
    assert(R.Resolve(other, nil, runtime) == '[power:cur]')
    assert(R.ResolveDependencies(text, runtime).health)
    Ok(M.UpdateTemplate(db, A, L.GetUserTemplateRecord(A, db), '[power:cur] updated'))
    assert(L.GetUserTemplateRecord(A, db).name == L.GetUserTemplateRecord(B, db).name)
    assert(R.Resolve(text, nil, runtime) == '[power:cur] updated')
    assert(R.Resolve(other, nil, runtime) == '[power:cur]')
    local deps = R.ResolveDependencies(text, runtime); assert(deps.power and not deps.health)
    Ok(M.AssignMainTemplate(ctx, 'player', 'Health', builtin))
    assert(R.Resolve(text, nil, runtime) == '[cast:time]')
    Ok(M.SetLocalMainContent(ctx, 'player', 'Health', 'local after cached main'))
    assert(R.Resolve(text, nil, runtime) == 'local after cached main')
end)
Test('ID lookup requires an explicit database and never falls back to active legacy state', function()
    local db = Fixture(); ns.db = db
    assert(R.Resolve({templateId = A}, nil, {}) == '')
    FailUnchanged(db, function() return M.AssignMainTemplate({expectedLayoutId = 'layout:A'}, 'player', 'Health', B) end,
        'invalid_context')
    ns.db = nil
end)
Test('Built-in writes blocked; delete checks full graph and allows unused entity', function()
    local db, _, _, layouts = Fixture()
    for _, run in ipairs({function() return M.UpdateTemplate(db, builtin, {}, 'x') end,
        function() return M.RenameTemplate(db, builtin, {}, 'x') end,
        function() return M.DeleteTemplate(db, builtin, {}) end}) do FailUnchanged(db, run) end
    FailUnchanged(db, function() return M.DeleteTemplate(db, A, L.GetUserTemplateRecord(A, db)) end, 'template_in_use')
    local expected = L.GetUserTemplateRecord(B, db)
    layouts['layout:B'] = {payload = {Units = {target = {Texts = {x = {enabled = false, stateTemplateIds = {dead = B}}}}}}}
    FailUnchanged(db, function() return M.DeleteTemplate(db, B, expected) end, 'template_in_use')
    layouts['layout:B'] = nil
    Ok(M.DeleteTemplate(db, B, expected)); assert(L.ResolveTemplateEntity(B, db) == nil)
end)
Test('E3 prepared records are directly consumable without projection or normalization', function()
    local source = {global = {UserLayouts = {}}}
    for _, key in ipairs({'layout:A', 'layout:B'}) do
        source.global.UserLayouts[key] = {payload = {TextTemplates = {Health = 'health', Dead = 'dead'},
            Units = {target = {Texts = {Health = {templateName = 'Health', tag = 'inline'},
                state = {stateTemplates = {dead = 'Dead', ghost = false}, tag = 'fallback'}}}}}}
    end
    local prepared = ns.TextTemplateEntityMigration.Prepare(source, Generator()); assert(prepared.ready)
    local db = {char = {activeLayoutId = 'layout:A'}, global = {UserLayouts = prepared.layouts,
        TextTemplates = prepared.templates, TextTemplateIdState = prepared.idState}}
    local before = Copy(db)
    local getDefaults = ns.GetDefaultDB
    ns.GetDefaultDB = function() error('default projection forbidden') end
    assert(V.ValidateEntityLayouts(prepared.layouts, db).valid)
    assert(#U.ScanEntities(prepared.layouts) == 4)
    for id, layout in pairs(prepared.layouts) do
        assert(layout.payload.TextTemplates == nil)
        local texts = layout.payload.Units.target.Texts
        assert(R.Resolve(texts.Health, 'dead', {db = db}) == 'health')
        assert(texts.Health.stateTemplateIds == nil)
        assert(R.Resolve(texts.state, 'ghost', {db = db}) == 'dead')
        assert(texts.state.stateTemplateIds.ghost == nil)
        assert(Ok(M.GetMainTemplateExpression({db = db, expectedLayoutId = 'layout:A'}, 'target', 'Health')).expression == 'health')
    end
    assert(Equal(db, before)); ns.GetDefaultDB = getDefaults
end)
Test('canonical runtime is Entity-only and ignores legacy names', function()
    local db = Fixture()
    assert(ns.TextTemplateResolver.Resolve({templateId = A, tag = 'old inline'}, nil, {db = db}) == '[hp:cur]')
    assert(ns.TextTemplateResolver.Resolve({templateName = 'old'}, nil,
        {GetTemplate = function(name) assert(name == 'old'); return 'legacy' end}) == '')
end)

Test('R1 fork is atomic, lossless and invalidates a warm binding only for its object', function()
    local db,ctx,text,layouts=Fixture(); ctx.expectedTextConfig=text
    layouts['layout:B']={payload={Units={target={Texts={x=Copy(text)}}}}}
    local before=Copy(db); local states=text.stateTemplateIds
    local content=string.rep('long',200)..'\000\001\n'
    assert(R.Resolve(text,nil,{db=db})=='[hp:cur]')
    local result=Ok(M.ForkMainTemplate(ctx,'player','Health',A,L.GetUserTemplateRecord(A,db),content,Generator()))
    assert(result.changed and result.cacheInvalidated and L.GetTemplateIdKind(result.templateId)=='user')
    assert(result.templateId~=A and result.templateId~=B)
    assert(text.templateId==result.templateId and text.stateTemplateIds==states)
    assert(Equal(db.global.TextTemplates[result.templateId],{name='Same',content=content}))
    assert(R.Resolve(text,nil,{db=db})==content)
    assert(R.Resolve(layouts['layout:A'].payload.Units.player.Texts.duplicate,nil,{db=db})=='[hp:cur]')
    before.global.TextTemplates[result.templateId]={name='Same',content=content}
    before.global.TextTemplateIdState=Copy(db.global.TextTemplateIdState)
    before.global.UserLayouts['layout:A'].payload.Units.player.Texts.Health.templateId=result.templateId
    assert(Equal(db,before),'fork changed fields outside its record, ID state and main FK')
end)
Test('R1 no-op never reserves or invalidates; Built-in fork creates a User entity', function()
    local db,ctx,text=Fixture(); local before=Copy(db)
    local invalidate=ns.TextTemplateResolver.Invalidate
    ns.TextTemplateResolver.Invalidate=function() error('no-op invalidated') end
    local no=Ok(M.ForkMainTemplate(ctx,'player','Health',A,L.GetUserTemplateRecord(A,db),'[hp:cur]',
        {Reserve=function() error('no-op reserved') end}))
    ns.TextTemplateResolver.Invalidate=invalidate
    assert(no.changed==false and no.cacheInvalidated==nil and Equal(db,before))
    text.templateId=builtin
    local source=assert(L.ResolveTemplateEntity(builtin,db))
    local fork=Ok(M.ForkMainTemplate(ctx,'player','Health',builtin,
        {name=source.name,content=source.content},'',Generator()))
    assert(fork.changed and L.GetTemplateIdKind(fork.templateId)=='user')
    assert(db.global.TextTemplates[fork.templateId].name==source.name and text.tag=='inline')
    assert(L.ResolveTemplateEntity(builtin,db).content==source.content)
    -- An existing namespace/store keeps its identity on the next fork.
    local store,state=db.global.TextTemplates,db.global.TextTemplateIdState
    Ok(M.ForkMainTemplate(ctx,'player','Health',fork.templateId,store[fork.templateId],'next',Generator()))
    assert(db.global.TextTemplates==store and db.global.TextTemplateIdState==state)
end)
Test('R1 rejects all pre-reservation conflicts without writes', function()
    local cases={
        function(db,ctx) ctx.expectedLayoutId='layout:B' end,
        function(db,ctx) ctx.expectedLayoutId='builtin:default'; db.char.activeLayoutId=ctx.expectedLayoutId end,
        function(db,ctx,text,layouts) layouts['layout:A'].payload.Units.player.Texts.Health=nil end,
        function(db,ctx,text) text.templateId=B end,
        function(db) db.global.TextTemplates[A]=nil end,
        function(db) db.global.TextTemplates[A].content='changed' end,
        function(db,ctx,text) text.role='altpower' end,
        function(db,ctx) ctx.expectedTextConfig={} end,
    }
    for _,change in ipairs(cases) do
        local db,ctx,text,layouts=Fixture(); local expected=Copy(db.global.TextTemplates[A])
        change(db,ctx,text,layouts)
        FailUnchanged(db,function() return M.ForkMainTemplate(ctx,'player','Health',A,expected,'new',
            {Reserve=function() error('invalid request reached reservation') end}) end)
    end
end)
Test('R1 final checks reject injected layout, object, FK, source, state and store conflicts', function()
    local cases={
        function(db) db.char.activeLayoutId='layout:B' end,
        function(db,ctx,text,layouts) layouts['layout:A'].payload.Units.player.Texts.Health=Copy(text) end,
        function(db,ctx,text) text.templateId=B end,
        function(db) db.global.TextTemplates[A].name='changed' end,
        function(db) db.global.TextTemplates=Copy(db.global.TextTemplates) end,
        function(db,ctx,text) text.stateTemplateIds.dead=B end,
        function(db,ctx,text) text.tag='external' end,
        function(db,ctx,text,layouts,id) db.global.TextTemplates[id]={name='Collision',content='external'} end,
        function(db) db.global.TextTemplateIdState={namespace=string.rep('c',32)} end,
        function(db,ctx) ctx.expectedTextConfig={} end,
    }
    for _,change in ipairs(cases) do
        local db,ctx,text,layouts=Fixture(); ctx.expectedTextConfig=text
        local expected=Copy(db.global.TextTemplates[A]); local injected, reservedId
        local generator=Generator()
        local result=M.ForkMainTemplate(ctx,'player','Health',A,expected,'new',{Reserve=function(_,private,reserved)
            assert(private~=db and private.global~=db.global)
            local id=assert(generator:Reserve(private,reserved)); reservedId=id
            assert(db.global.TextTemplates[id]==nil and db.global.TextTemplateIdState==nil)
            change(db,ctx,text,layouts,id); injected=Copy(db)
            return id
        end})
        assert(reservedId and not result.ok and Equal(db,injected),'fork added writes after a conflict')
    end
end)
Test('R1 helper failure and post-creation conflict never persist a half-fork', function()
    local db,ctx=Fixture(); local expected=Copy(db.global.TextTemplates[A])
    FailUnchanged(db,function() return M.ForkMainTemplate(ctx,'player','Health',A,expected,'new',
        {Reserve=function(_,private,reserved) Generator():Reserve(private,reserved); error('injected') end}) end)
    local create=L.CreateUserTemplateRecord; local injected
    L.CreateUserTemplateRecord=function(id,record,private)
        local ok,reason=create(id,record,private)
        db.global.TextTemplates[A].content='external'; injected=Copy(db)
        return ok,reason
    end
    local result=M.ForkMainTemplate(ctx,'player','Health',A,expected,'new',Generator())
    L.CreateUserTemplateRecord=create
    assert(not result.ok and Equal(db,injected))
end)
Test('R1 post-commit invalidation failure reports committed data', function()
    local db,ctx,text=Fixture(); local invalidate=ns.TextTemplateResolver.Invalidate
    ns.TextTemplateResolver.Invalidate=function() error('refresh failure') end
    local result=M.ForkMainTemplate(ctx,'player','Health',A,Copy(db.global.TextTemplates[A]),'new',Generator())
    ns.TextTemplateResolver.Invalidate=invalidate
    assert(result.ok and result.changed and result.cacheInvalidated==false and result.cacheInvalidationError)
    assert(text.templateId==result.templateId and db.global.TextTemplates[result.templateId].content=='new')
end)
print('TextTemplateEntityContracts: ' .. passed .. ' groups passed')
