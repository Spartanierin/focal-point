-- lua54 Tests/TextTemplateEntityMigration.lua [SavedVariables path]
local ns = {}
local function Load(path) assert(loadfile(path))('FocalPoint', ns) end
Load('Data/Defaults.lua')
Load('Services/LayoutService.lua')
Load('Engine/UnitFrame/Shared/UnitFrameUtils.lua')
Load('Engine/Text/Shared/TextTemplateLibrary.lua')
Load('Services/TextTemplateEntityMigration.lua')
local library, migration = ns.TextTemplateLibrary, ns.TextTemplateEntityMigration
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
local function Count(t) local n = 0; for _ in pairs(t or {}) do n = n + 1 end; return n end
local function NoAliases(source, target)
    local tables = {}
    local function Collect(t)
        if type(t) ~= 'table' or tables[t] then return end
        tables[t] = true; for k, v in pairs(t) do Collect(k); Collect(v) end
    end
    Collect(source)
    local function Check(t)
        if type(t) ~= 'table' then return end
        assert(not tables[t], 'prepared/source table alias')
        for k, v in pairs(t) do Check(k); Check(v) end
    end
    Check(target)
end
local function Generator()
    return assert(library.CreateUserTemplateIdGenerator({time = function() return 1700000000 end,
        uptime = function() return 1 end, random = function() return 1 end}))
end
local function Layout()
    return {name = 'Example', createdFrom = {source = 'profile', id = 'Default'}, payload = {
        TextTemplates = {Health = 'X', Dead = 'Y'}, Units = {player = {Texts = {
            text_1 = {templateName = 'Health', stateTemplates = {dead = 'Dead'}, tag = 'fallback',
                enabled = false, role = 'health', point = 'CENTER', x = 17, color = {1, .5, 0}},
            local_1 = {tag = 'local', templateName = '', stateTemplates = {}, fontSize = 13},
        }}, empty = {Texts = {}}, noTexts = {enabled = true}}}}
end
local function DB() return {global = {UserLayouts = {['layout:A'] = Layout()}}} end
local function Prepare(db, generator)
    local before = Copy(db)
    local result = migration.Prepare(db, generator or Generator())
    assert(Equal(db, before), 'source mutated'); NoAliases(db, result)
    return result
end
local function Diagnostic(result, code)
    assert(not result.ready)
    assert(result.layouts == nil and result.templates == nil and result.mappings == nil, 'no partial target')
    for _, d in ipairs(result.diagnostics) do if d.errorCode == code then return d end end
    error('missing diagnostic: ' .. code)
end
local function Verify(db, result)
    assert(result.ready, result.diagnostics[1] and result.diagnostics[1].errorCode)
    local seen, templates, texts, mains, states, units = {}, 0, 0, 0, 0, 0
    assert(Count(result.layouts) == Count(db.global.UserLayouts))
    for layoutId, old in pairs(db.global.UserLayouts) do
        local new = result.layouts[layoutId]
        assert(new.payload.TextTemplates == nil)
        assert(Count(result.mappings[layoutId]) == Count(old.payload.TextTemplates))
        for name, content in pairs(old.payload.TextTemplates) do
            local id = assert(result.mappings[layoutId][name])
            assert(not seen[id] and library.GetTemplateIdKind(id) == 'user')
            seen[id] = true; templates = templates + 1
            assert(Equal(result.templates[id], {name = name, content = content}))
        end
        local restored = Copy(new); restored.payload.TextTemplates = Copy(old.payload.TextTemplates)
        assert(Count(new.payload.Units) == Count(old.payload.Units))
        for unitKey, unit in pairs(old.payload.Units) do
            units = units + 1
            assert(Count(new.payload.Units[unitKey].Texts) == Count(unit.Texts))
            for textKey, text in pairs(unit.Texts or {}) do
                texts = texts + 1
                local target = new.payload.Units[unitKey].Texts[textKey]
                assert(target.templateName == nil and target.stateTemplates == nil and target.tag == text.tag)
                if text.templateName and text.templateName ~= '' then
                    mains = mains + 1
                    assert(target.templateId == result.mappings[layoutId][text.templateName])
                    assert(result.templates[target.templateId])
                else assert(target.templateId == nil) end
                local storedStates = text.stateTemplates
                local concrete = 0
                for stateKey, name in pairs(type(storedStates) == 'table' and storedStates or {}) do
                    if name ~= false then
                        concrete = concrete + 1; states = states + 1
                        assert(target.stateTemplateIds[stateKey] == result.mappings[layoutId][name])
                        assert(result.templates[target.stateTemplateIds[stateKey]])
                    end
                end
                assert(Count(target.stateTemplateIds) == concrete)
                if concrete == 0 then assert(target.stateTemplateIds == nil) end
                for _, id in pairs(target.stateTemplateIds or {}) do
                    assert(type(id) == 'string' and library.GetTemplateIdKind(id) == 'user')
                end
                local reverse = restored.payload.Units[unitKey].Texts[textKey]
                reverse.templateId, reverse.stateTemplateIds = nil, nil
                reverse.templateName, reverse.stateTemplates = text.templateName, Copy(text.stateTemplates)
            end
        end
        assert(Equal(restored, old), 'composition changed')
    end
    assert(Count(result.templates) == templates + Count(db.global.TextTemplates))
    for id, record in pairs(db.global.TextTemplates or {}) do assert(Equal(record, result.templates[id])) end
    return templates, texts, mains, states, units
end
local passed = 0
local function Test(name, run) run(); passed = passed + 1; print('PASS: ' .. name) end
Test('main/state, disabled objects, local tags, composition and source isolation', function()
    local db = DB(); local result = Prepare(db); Verify(db, result)
    assert(Count(result.templates) == 2 and result.idState.namespace)
    local text = result.layouts['layout:A'].payload.Units.player.Texts.text_1
    assert(text.stateTemplateIds.ghost == nil and text.enabled == false)
    text.color[1] = 0; result.idState.namespace = 'changed'
    assert(db.global.UserLayouts['layout:A'].payload.Units.player.Texts.text_1.color[1] == 1)
    assert(db.global.TextTemplateIdState == nil)
end)
Test('equal names/content/origins and unused templates never merge', function()
    local db = DB(); db.global.UserLayouts['layout:B'] = Layout(); db.global.UserLayouts['layout:C'] = Layout()
    db.global.UserLayouts['layout:C'].payload.TextTemplates.Health = 'other'
    db.global.UserLayouts['layout:A'].payload.TextTemplates.Unused = 'X'
    assert(Verify(db, Prepare(db)) == 7)
end)
Test('all explicit states share only layout-local identity with main', function()
    local db = DB(); local text = db.global.UserLayouts['layout:A'].payload.Units.player.Texts.text_1
    text.stateTemplates = {dead = 'Health', ghost = 'Health', offline = 'Dead', afk = 'Dead', dnd = 'Dead'}
    Verify(db, Prepare(db))
end)
Test('missing references have exact context and no cross-layout/global/builtin fallback', function()
    local db = DB(); db.global.UserLayouts['layout:B'] = Layout()
    db.global.UserLayouts['layout:A'].payload.TextTemplates = {}
    local id = assert(Generator():Reserve(db, {})); db.global.TextTemplates = {[id] = {name = 'Health', content = 'X'}}
    local result = Prepare(db)
    local main = Diagnostic(result, 'missing-main-template-reference')
    local state = Diagnostic(result, 'missing-state-template-reference')
    assert(main.layoutId == 'layout:A' and main.unitKey == 'player' and main.textKey == 'text_1' and main.oldName == 'Health')
    assert(state.layoutId == 'layout:A' and state.unitKey == 'player' and state.textKey == 'text_1' and state.stateKey == 'dead' and state.oldName == 'Dead')
end)
Test('existing global records remain distinct; E1 skips collisions', function()
    local db = DB(); local id = assert(Generator():Reserve(db, {}))
    db.global.TextTemplates = {[id] = {name = 'Health', content = 'X'}}
    local result = Prepare(db); Verify(db, result)
    assert(result.mappings['layout:A'].Health ~= id and Count(result.templates) == 3)
end)
Test('materialized builtin equality never implies builtin identity', function()
    Load('Data/Defaults.lua'); Load('Data/Themes.lua'); Load('Data/BuiltInTextTemplates.lua')
    local db = DB(); local record = ns.BuiltInTextTemplates.GetRecord('tpl:b:default-013')
    db.global.UserLayouts['layout:A'].payload.TextTemplates[record.name] = record.content
    local result = Prepare(db); Verify(db, result)
    assert(library.GetTemplateIdKind(result.mappings['layout:A'][record.name]) == 'user')
    db.global.UserLayouts['layout:A'].payload.TextTemplates[record.name] = nil
    db.global.UserLayouts['layout:A'].payload.Units.player.Texts.text_1.templateName = record.name
    Diagnostic(Prepare(db), 'missing-main-template-reference')
end)
Test('legacy profiles/presets/maps/backups are not reimported', function()
    local db = DB(); db.profiles = {Legacy = {TextTemplates = {Ignored = 'legacy'}}}
    db.global.UserPresets = {old = {layout = {TextTemplates = {Ignored = 'preset'}}}}
    db.global.LayoutMigration = {version = 1, profileMap = {Legacy = 'layout:A'}, userPresetMap = {}}
    db.global.LayoutMigrationBackup = {profiles = Copy(db.profiles)}
    assert(Verify(db, Prepare(db)) == 2)
end)
Test('invalid records/layouts and mixed target fields reject without repair', function()
    local cases = {
        {'invalid-layout-payload', function(p) p.Units = nil end},
        {'invalid-layout-payload', function(p) p.TextTemplates = nil end},
        {'invalid-layout-payload', function(p) p.Units.player.Texts.text_1 = false end},
        {'invalid-template-record', function(p) p.TextTemplates.Health = false end},
        {'invalid-template-record', function(p) p.TextTemplates[' '] = 'x' end},
        {'invalid-layout-payload', function(p) p.Units.player.Texts.text_1.templateId = 'tpl:b:default-013' end},
        {'invalid-layout-payload', function(p) p.Units.player.Texts.text_1.stateTemplateIds = {} end},
    }
    for _, case in ipairs(cases) do local db = DB(); case[2](db.global.UserLayouts['layout:A'].payload); Diagnostic(Prepare(db), case[1]) end
    local db = DB(); db.global.UserLayouts['layout:A'].payload = false; Diagnostic(Prepare(db), 'invalid-layout-payload')
    db = DB(); db.global.TextTemplates = {bad = {name = 'x', content = 'y'}}; Diagnostic(Prepare(db), 'prepared-id-invariant-failure')
end)
Test('reservation failures and invalid/repeated IDs cannot yield ready target', function()
    Diagnostic(Prepare(DB(), {Reserve = function() return nil, 'failure' end}), 'id-reservation-failure')
    Diagnostic(Prepare(DB(), {Reserve = function() return 'tpl:b:default-013' end}), 'prepared-id-invariant-failure')
    local id = assert(Generator():Reserve({}, {}))
    Diagnostic(Prepare(DB(), {Reserve = function() return id end}), 'prepared-id-invariant-failure')
end)
Test('raw AceDB peek avoids lazy writes; empty canonical store stays empty', function()
    local saved = DB()
    local db = setmetatable({sv = saved}, {__index = function() error('lazy source access') end,
        __newindex = function() error('source write') end})
    Verify(saved, Prepare(db))
    local result = Prepare({global = {UserLayouts = {}}})
    assert(result.ready and next(result.templates) == nil and result.idState == nil)
    Diagnostic(Prepare({}), 'invalid-layout-payload')
end)
Test('aliased source objects/layouts cannot couple target migrations', function()
    local db = DB(); db.global.UserLayouts['layout:B'] = db.global.UserLayouts['layout:A']
    local texts = db.global.UserLayouts['layout:A'].payload.Units.player.Texts; texts.text_2 = texts.text_1
    local result = Prepare(db); Verify(db, result)
    local target = result.layouts['layout:A'].payload.Units.player.Texts
    assert(target.text_1 ~= target.text_2)
end)
Test('lossless whitespace/empty content and unbound objects without legacy fields', function()
    local db = DB(); local payload = db.global.UserLayouts['layout:A'].payload
    payload.TextTemplates[' Name with spaces '] = '  text\n'
    payload.TextTemplates.Empty = ''
    payload.Units.player.Texts.bare = {tag = '', enabled = true, style = {nested = {1, 2}}}
    Verify(db, Prepare(db))
end)
Test('malformed nested structures, state references and E1 state fail explicitly', function()
    local changes = {
        {'invalid-layout-payload', function(p) p.Units.player.Texts = false end},
        {'invalid-layout-payload', function(p) p.Units.player.Texts.text_1.templateName = false end},
        {'invalid-layout-payload', function(p) p.Units.player.Texts.text_1.stateTemplates = true end},
        {'invalid-state-template-reference', function(p) p.Units.player.Texts.text_1.stateTemplates.dead = '' end},
        {'invalid-state-template-reference', function(p) p.Units.player.Texts.text_1.stateTemplates.dead = {} end},
        {'invalid-state-template-reference', function(p) p.Units.player.Texts.text_1.stateTemplates[2] = 'Dead' end},
    }
    for _, case in ipairs(changes) do
        local db = DB(); case[2](db.global.UserLayouts['layout:A'].payload); Diagnostic(Prepare(db), case[1])
    end
    local db = DB(); db.global.TextTemplateIdState = {namespace = 'invalid'}
    Diagnostic(Prepare(db), 'id-reservation-failure')
    db = DB(); local id = assert(Generator():Reserve(db, {}))
    db.global.TextTemplates = {[id] = {name = 'Valid', content = false}}
    Diagnostic(Prepare(db), 'invalid-template-record')
    db = DB(); db.global.UserLayouts['layout:A'].payload.self = db.global.UserLayouts['layout:A'].payload
    local result = migration.Prepare(db, Generator())
    Diagnostic(result, 'invalid-layout-payload')
    assert(db.global.UserLayouts['layout:A'].payload.self == db.global.UserLayouts['layout:A'].payload)
end)
Test('default E1 reservation path writes namespace only to prepared copy', function()
    local oldTime, oldUptime = time, GetTime
    time, GetTime = function() return 1700000000 end, function() return 1 end
    local db, before = DB(), DB()
    local a = migration.Prepare(db); local b = migration.Prepare(db)
    Verify(db, a); Verify(db, b)
    assert(Equal(db, before) and db.global.TextTemplateIdState == nil)
    assert(a.idState.namespace and b.idState.namespace)
    assert(a.mappings['layout:A'].Health ~= b.mappings['layout:A'].Health)
    NoAliases(db, a)
    time, GetTime = oldTime, oldUptime
end)
-- Projectable defaults are deliberately separate from the raw migration source.
local function WithStateDefaults(run)
    local getter = ns.GetDefaultDB
    local defaults = {profile = {Units = {player = {Texts = {
        text_1 = {stateTemplates = {dead = 'Dead', ghost = 'Dead', offline = 'Health', afk = 'Dead', dnd = 'Health'},
            tag = 'must not replace source tag', offsetX = 999},
        default_only = {tag = 'must not create an object'},
    }}}}}
    local before = Copy(defaults)
    ns.GetDefaultDB = function() return defaults end
    local ok, reason = pcall(run)
    ns.GetDefaultDB = getter
    assert(Equal(defaults, before), 'defaults mutated')
    assert(ok, reason)
end
local function SourceText(db) return db.global.UserLayouts['layout:A'].payload.Units.player.Texts.text_1 end
local function TargetText(result) return result.layouts['layout:A'].payload.Units.player.Texts.text_1 end
Test('raw whole-map false yields no state IDs despite projectable defaults', function()
    WithStateDefaults(function()
        local db = DB(); SourceText(db).stateTemplates = false
        local result = Prepare(db); Verify(db, result)
        assert(TargetText(result).stateTemplateIds == nil)
        assert(TargetText(result).templateId == result.mappings['layout:A'].Health)
        assert(TargetText(result).tag == 'fallback' and SourceText(db).stateTemplates == false)
    end)
end)
Test('raw nil never activates projectable defaults even when their records exist', function()
    WithStateDefaults(function()
        local db = DB(); SourceText(db).stateTemplates = nil
        local result = Prepare(db); Verify(db, result)
        assert(TargetText(result).stateTemplateIds == nil)
        -- Demonstrate the distinction using the real projection, on a copy.
        local projected = ns.LayoutService.ProjectUserLayout('layout:A', Copy(db.global.UserLayouts['layout:A']), ns:GetDefaultDB())
        assert(projected.payload.Units.player.Texts.text_1.stateTemplates.dead == 'Dead')
        assert(projected.payload.Units.player.Texts.text_1.stateTemplates.ghost == 'Dead')
        assert(result.layouts['layout:A'].payload.Units.player.Texts.default_only == nil)
        assert(TargetText(result).offsetX == nil and SourceText(db).stateTemplates == nil)
    end)
end)
Test('partial false keeps only stored strings, with no ghost or inherited FK', function()
    WithStateDefaults(function()
        local db = DB(); SourceText(db).stateTemplates = {dead = 'Health', ghost = false}
        local result = Prepare(db); Verify(db, result)
        local states = TargetText(result).stateTemplateIds
        assert(states.dead == result.mappings['layout:A'].Health and states.ghost == nil)
        assert(Count(states) == 1 and states.offline == nil and states.afk == nil)
        assert(SourceText(db).stateTemplates.ghost == false)
    end)
end)
Test('mixed raw states materialize stored strings only', function()
    WithStateDefaults(function()
        local db = DB()
        SourceText(db).stateTemplates = {dead = 'Dead', ghost = false, offline = 'Health', afk = false, dnd = 'Health'}
        local result = Prepare(db); Verify(db, result)
        assert(Count(TargetText(result).stateTemplateIds) == 3)
        assert(TargetText(result).stateTemplateIds.ghost == nil and TargetText(result).stateTemplateIds.afk == nil)
    end)
end)
Test('raw nil, empty and all-false maps require no target state map', function()
    for _, mode in ipairs({'missing', 'empty', 'suppressed'}) do
        local db = DB()
        if mode == 'missing' then SourceText(db).stateTemplates = nil
        elseif mode == 'empty' then SourceText(db).stateTemplates = {}
        else SourceText(db).stateTemplates = {dead = false, ghost = false} end
        local result = Prepare(db); Verify(db, result)
        assert(TargetText(result).stateTemplateIds == nil)
    end
end)
Test('default-only missing record is irrelevant without a stored binding', function()
    WithStateDefaults(function()
        local db = DB(); SourceText(db).stateTemplates = nil
        db.global.UserLayouts['layout:A'].payload.TextTemplates.Dead = nil
        local result = Prepare(db); Verify(db, result)
        assert(result.ready and #result.diagnostics == 0 and TargetText(result).stateTemplateIds == nil)
        assert(result.mappings['layout:A'].Dead == nil)
    end)
end)
Test('prepared validator accepts only resolvable IDs, never sentinels', function()
    local result = Prepare(DB()); local id = result.mappings['layout:A'].Dead
    assert(migration.ValidatePreparedStateIds(nil, result.templates))
    assert(migration.ValidatePreparedStateIds({dead = id}, result.templates))
    assert(not migration.ValidatePreparedStateIds(false, result.templates))
    assert(not migration.ValidatePreparedStateIds({dead = false}, result.templates))
    assert(not migration.ValidatePreparedStateIds({ghost = id, dead = 'tpl:b:default-013'}, result.templates))
    assert(not migration.ValidatePreparedStateIds({dead = id}, {}))
end)
Test('stored missing string still blocks despite projectable defaults', function()
    WithStateDefaults(function()
        local db = DB(); SourceText(db).stateTemplates = {dead = 'Missing'}
        local d = Diagnostic(Prepare(db), 'missing-state-template-reference')
        assert(d.layoutId == 'layout:A' and d.unitKey == 'player' and d.textKey == 'text_1')
        assert(d.stateKey == 'dead' and d.oldName == 'Missing')
    end)
end)
Test('preparation does not read defaults or invoke merge/projection/normalization', function()
    local service, getter, utils = ns.LayoutService, ns.GetDefaultDB, ns.UnitFrameUtils
    local function Forbidden() error('defaults/projection/normalization forbidden') end
    ns.GetDefaultDB = Forbidden
    ns.LayoutService = setmetatable({}, {__index = Forbidden})
    ns.UnitFrameUtils = setmetatable({}, {__index = Forbidden})
    local db = DB(); SourceText(db).stateTemplates = nil
    local ok, result = pcall(Prepare, db)
    ns.LayoutService, ns.GetDefaultDB, ns.UnitFrameUtils = service, getter, utils
    assert(ok, result); Verify(db, result)
end)
print('TextTemplateEntityMigration: ' .. passed .. ' passed')
-- Explicit offline acceptance, isolated environment; never writes the supplied file.
if arg and arg[1] then
    local environment = {}; assert(loadfile(arg[1], 't', environment))()
    local sourceDb = assert(environment.FocalPointDB, 'fixture must define FocalPointDB')
    local db = Copy(sourceDb) -- Prepare receives only an independent copy.
    local totalUnits, totalTexts, totalTemplates, totalMains, totalStates = 0, 0, 0, 0, 0
    local wholeFalse, entryFalse = 0, 0
    local ids = {}; for id in pairs(db.global.UserLayouts) do ids[#ids + 1] = id end; table.sort(ids)
    for _, id in ipairs(ids) do
        local layout = db.global.UserLayouts[id]
        local texts, mains, states = 0, 0, 0
        for _, unit in pairs(layout.payload.Units) do
            totalUnits = totalUnits + 1
            for _, text in pairs(unit.Texts or {}) do
                texts = texts + 1
                if text.templateName and text.templateName ~= '' then mains = mains + 1 end
                if text.stateTemplates == false then wholeFalse = wholeFalse + 1
                elseif type(text.stateTemplates) == 'table' then
                    for _, name in pairs(text.stateTemplates) do
                        if name == false then entryFalse = entryFalse + 1
                        elseif type(name) == 'string' and name ~= '' then states = states + 1 end
                    end
                end
            end
        end
        totalTexts, totalMains, totalStates = totalTexts + texts, totalMains + mains, totalStates + states
        totalTemplates = totalTemplates + Count(layout.payload.TextTemplates)
        print(string.format('SOURCE %s: templates=%d texts=%d main=%d stateStrings=%d', id, Count(layout.payload.TextTemplates), texts, mains, states))
    end
    print(string.format('SOURCE TOTAL: layouts=%d units=%d texts=%d templates=%d main=%d stateStrings=%d wholeFalse=%d entryFalse=%d existingGlobal=%d',
        Count(db.global.UserLayouts), totalUnits, totalTexts, totalTemplates, totalMains, totalStates, wholeFalse, entryFalse, Count(db.global.TextTemplates)))
    local result = Prepare(db)
    assert(Equal(sourceDb, db), 'loaded source/input copy differs')
    NoAliases(sourceDb, result)
    print('PREPARED ready=' .. tostring(result.ready) .. ' diagnostics=' .. #result.diagnostics)
    if not result.ready then
        for _, d in ipairs(result.diagnostics) do
            print(table.concat({d.errorCode, tostring(d.layoutId), tostring(d.unitKey), tostring(d.textKey), tostring(d.stateKey), tostring(d.oldName)}, ' | '))
        end
        error('real data blocked; source unchanged')
    end
    local templates, texts, mains, states, units = Verify(db, result)
    assert(templates == totalTemplates and texts == totalTexts and mains == totalMains and states == totalStates and units == totalUnits)
    print(string.format('REAL: layouts=%d units=%d texts=%d mainFKs=%d stateFKs=%d newTemplates=%d totalTemplates=%d',
        Count(result.layouts), units, texts, mains, states, templates, Count(result.templates)))
    print('PASS: IDs unique; raw-string/FK bijection; no added FKs; all FKs resolve; names/content/tag/composition/text keys preserved; no legacy fields or false target bindings; source unchanged; no table aliases')
end
