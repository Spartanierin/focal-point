-- lua54 Tests/TextTemplateEntityCutover.lua [SavedVariables path]
local ns = {}
local function Load(path) assert(loadfile(path))('FocalPoint', ns) end

Load('Data/Defaults.lua')
Load('Data/Themes.lua')
Load('Services/CompositionPresenceStorage.lua')
Load('Services/LayoutService.lua')
Load('Services/UserLayoutStore.lua')
Load('Services/LayoutMigration.lua')
Load('Engine/UnitFrame/Shared/UnitFrameUtils.lua')
Load('Engine/Text/Shared/TextTemplateLibrary.lua')
Load('Data/BuiltInTextTemplates.lua')
Load('Engine/Text/Shared/TextTemplateUsage.lua')
Load('Engine/Text/Shared/TextTemplateValidation.lua')
Load('Services/TextTemplateEntityMigration.lua')
Load('Services/TextTemplateEntityCutover.lua')

local library = ns.TextTemplateLibrary
local cutover = ns.TextTemplateEntityCutover

local function Copy(value)
    if type(value) ~= 'table' then return value end
    local result = {}
    for key, entry in pairs(value) do result[Copy(key)] = Copy(entry) end
    return result
end

local function Equal(left, right)
    if left == right then return true end
    if type(left) ~= 'table' or type(right) ~= 'table' then return false end
    for key, value in pairs(left) do if not Equal(value, right[key]) then return false end end
    for key in pairs(right) do if left[key] == nil then return false end end
    return true
end

local function Count(source)
    local result = 0
    for _ in pairs(source or {}) do result = result + 1 end
    return result
end

local function Id(n)
    return 'tpl:u:' .. string.rep('a', 32) .. ':1-2-' .. string.rep('b', 32) .. ':' .. n
end

local function Generator()
    return assert(library.CreateUserTemplateIdGenerator({
        time = function() return 1700000000 end,
        uptime = function() return 1 end,
        random = function() return 2 end,
    }))
end

local function LegacyDB()
    return {
        char = {activeLayoutId = 'layout:A:001'},
        profileKeys = {['Test - Realm'] = 'Legacy'},
        profiles = {},
        global = {
            UserLayouts = {
                ['layout:A:001'] = {
                    name = 'Legacy',
                    formatVersion = 1,
                    metadata = {keep = true},
                    payload = {
                        TextTemplates = {
                            Main = '[name]  \n',
                            State = '[dead]',
                            Empty = '',
                        },
                        Units = {
                            player = {
                                Texts = {
                                    Health = {
                                        templateName = 'Main',
                                        stateTemplates = {dead = 'State', ghost = false},
                                        tag = '[hp:cur]  \n',
                                        enabled = false,
                                        fontSize = 17,
                                        color = {1, .5, 0},
                                    },
                                    Local = {
                                        tag = 'object-local',
                                        enabled = true,
                                        anchorTo = 'HealthBar',
                                    },
                                },
                            },
                        },
                    },
                },
            },
        },
    }
end

local function EntityDB()
    local a, b = Id(1), Id(2)
    return {
        global = {
            UserLayouts = {
                ['layout:A:001'] = {
                    name = 'Entity',
                    formatVersion = 2,
                    payload = {
                        Units = {player = {Texts = {
                            Health = {templateId = a, tag = 'tag'},
                            Local = {stateTemplateIds = {dead = b}, tag = 'local'},
                        }}},
                    },
                },
            },
            TextTemplates = {
                [a] = {name = 'Main', content = '[name]'},
                [b] = {name = 'Dead', content = '[dead]'},
            },
            TextTemplateIdState = {namespace = string.rep('a', 32)},
        },
    }
end

local function LegacyWithE1Store()
    local db = LegacyDB()
    local id = Id(9)
    db.global.TextTemplates = {[id] = {name = 'Existing', content = 'existing'}}
    db.global.TextTemplateIdState = {namespace = string.rep('a', 32)}
    return db
end

local function LegacyWithProfiles()
    local db = {
        char = {activeLayoutId = nil},
        profiles = {
            Legacy = {
                TextTemplates = {Main = '[name]'},
                Units = {player = {Texts = {
                    Health = {templateName = 'Main', tag = 'from-profile'},
                }}},
            },
        },
        global = {
            UserLayouts = {},
            LayoutMigration = {version = 0, profileMap = {}, userPresetMap = {}},
            LayoutMigrationBackup = {
                version = 1,
                profiles = {Legacy = {TextTemplates = {Main = '[name]'}}},
                userPresets = {},
                profileAutomation = {},
            },
        },
    }
    return db
end

local function Ok(result)
    assert(result and result.ok, tostring(result and result.errorCode) .. ':' .. tostring(result and result.detailCode or ''))
    return result
end


local function Fails(db, code, options)
    local before = Copy(db)
    local result = cutover.Prepare(db, options)
    assert(not result.ok, 'unexpected success: ' .. tostring(result.errorCode))
    assert(result.errorCode == code, tostring(result.errorCode) .. ' ~= ' .. code)
    assert(Equal(db, before), 'failed cutover mutated live data')
    return result
end

local function RootReferences(db)
    local global = db.global
    return {
        global = global,
        UserLayouts = global.UserLayouts,
        TextTemplates = global.TextTemplates,
        TextTemplateIdState = global.TextTemplateIdState,
        LayoutMigration = global.LayoutMigration,
        LayoutMigrationBackup = global.LayoutMigrationBackup,
        TextTemplateEntityMigrationBackup = global.TextTemplateEntityMigrationBackup,
        TextTemplateEntityMigration = global.TextTemplateEntityMigration,
    }
end

local function AssertRootReferences(db, refs)
    local global = db.global
    assert(global == refs.global)
    assert(global.UserLayouts == refs.UserLayouts)
    assert(global.TextTemplates == refs.TextTemplates)
    assert(global.TextTemplateIdState == refs.TextTemplateIdState)
    assert(global.LayoutMigration == refs.LayoutMigration)
    assert(global.LayoutMigrationBackup == refs.LayoutMigrationBackup)
    assert(global.TextTemplateEntityMigrationBackup == refs.TextTemplateEntityMigrationBackup)
    assert(global.TextTemplateEntityMigration == refs.TextTemplateEntityMigration)
end

local passed = 0
local function Test(name, run)
    run()
    passed = passed + 1
    print('PASS: ' .. name)
end

Test('classifies and commits complete legacy data', function()
    local db = LegacyDB()
    local original = Copy(db)
    local result = Ok(cutover.Prepare(db, {generator = Generator()}))
    assert(result.changed == true and result.classification == 'legacy')
    local global = db.global
    assert(global.TextTemplateEntityMigration.complete == true)
    assert(global.TextTemplateEntityMigration.layoutFormatVersion == 2)
    assert(global.TextTemplateEntityMigrationBackup.version == 1)
    assert(global.UserLayouts['layout:A:001'].formatVersion == 2)
    assert(global.UserLayouts['layout:A:001'].payload.TextTemplates == nil)
    assert(global.UserLayouts['layout:A:001'].payload.Units.player.Texts.Health.tag == '[hp:cur]  \n')
    assert(global.UserLayouts['layout:A:001'].payload.Units.player.Texts.Local.tag == 'object-local')
    assert(Count(global.TextTemplates) == 3)
    for id, record in pairs(global.TextTemplates) do
        assert(library.GetTemplateIdKind(id) == 'user')
        assert(library.ValidateTemplateRecord(record))
    end
    assert(Equal(global.TextTemplateEntityMigrationBackup.savedVariables, original))
end)

Test('preserves an existing valid E1 store and appends only legacy entities', function()
    local db = LegacyWithE1Store()
    local existing = Copy(db.global.TextTemplates)
    Ok(cutover.Prepare(db, {generator = Generator()}))
    assert(Equal(db.global.TextTemplates[Id(9)], existing[Id(9)]))
    assert(Count(db.global.TextTemplates) == 4)
end)

Test('backup is independent and contains all saved-variable roots', function()
    local db = LegacyDB()
    db.profileKeys['Backup - Realm'] = 'Legacy'
    db.global.UserLayouts['layout:A:001'].payload.Units.player.Texts.Local.tag = 'backup-check'
    Ok(cutover.Prepare(db, {generator = Generator()}))
    local backup = db.global.TextTemplateEntityMigrationBackup
    assert(backup.savedVariables.profileKeys['Backup - Realm'] == 'Legacy')
    assert(backup.savedVariables.global.UserLayouts ~= db.global.UserLayouts)
    assert(backup.savedVariables.global.UserLayouts['layout:A:001'] ~= db.global.UserLayouts['layout:A:001'])
    backup.savedVariables.global.UserLayouts['layout:A:001'].name = 'changed-backup'
    assert(db.global.UserLayouts['layout:A:001'].name ~= 'changed-backup')
end)

Test('valid marker is idempotent and does not create IDs or rewrite backup', function()
    local db = LegacyDB()
    Ok(cutover.Prepare(db, {generator = Generator()}))
    local beforeBackup = Copy(db.global.TextTemplateEntityMigrationBackup)
    local beforeLayouts, beforeRecords = Copy(db.global.UserLayouts), Copy(db.global.TextTemplates)
    local result = Ok(cutover.Prepare(db, {generator = Generator()}))
    assert(result.changed == false and result.classification == 'complete')
    assert(Equal(db.global.TextTemplateEntityMigrationBackup, beforeBackup))
    assert(Equal(db.global.UserLayouts, beforeLayouts))
    assert(Equal(db.global.TextTemplates, beforeRecords))
end)

Test('legacy plus valid E1 store is accepted, entity without marker is rejected', function()
    local db = EntityDB()
    Fails(db, 'entity-without-marker')
    local legacy = LegacyWithE1Store()
    assert(cutover.Classify(legacy).classification == 'legacy')
end)

Test('mixed layouts and invalid marker states are rejected without repair', function()
    local db = LegacyDB()
    db.global.UserLayouts['layout:B'] = Copy(EntityDB().global.UserLayouts['layout:A:001'])
    Fails(db, 'mixed-layout')
    db = EntityDB()
    db.global.TextTemplateEntityMigration = {version = 99, layoutFormatVersion = 2, complete = true}
    Fails(db, 'unknown-marker-version')
    db = EntityDB()
    db.global.TextTemplateEntityMigration = {version = 1, layoutFormatVersion = 2, complete = true}
    Fails(db, 'invalid-backup')
end)

Test('private profile preparation never writes the live profile source', function()
    local db = LegacyWithProfiles()
    local beforeProfiles = Copy(db.profiles)
    local result = Ok(cutover.Prepare(db, {generator = Generator()}))
    assert(Count(db.global.UserLayouts) == 1)
    assert(db.global.UserLayouts['layout:0:001'].formatVersion == 2)
    assert(Equal(db.profiles, beforeProfiles))
    assert(db.global.UserLayouts['layout:0:001'].payload.Units.player.Texts.Health.tag == 'from-profile')
end)

Test('final guard rejects a live-root change before commit', function()
    local db = LegacyDB()
    local real = Generator()
    local changed = false
    local generator = {
        Reserve = function(_, working, reserved)
            if not changed then
                changed = true
                db.global.UserLayouts['layout:A:001'].name = 'concurrent-change'
            end
            return real:Reserve(working, reserved)
        end,
    }
    local result = cutover.Prepare(db, {generator = generator})
    assert(not result.ok and result.errorCode == 'live-conflict')
    assert(db.global.UserLayouts['layout:A:001'].name == 'concurrent-change')
    assert(db.global.TextTemplateEntityMigration == nil)
end)

Test('commit failure restores every root and leaves marker absent', function()
    for failureAt = 1, 5 do
        local db = LegacyDB()
        local before = Copy(db)
        local refs = RootReferences(db)
        local result = cutover.Prepare(db, {generator = Generator(), testCommitFailureAt = failureAt})
        assert(not result.ok and result.errorCode == 'commit-failed')
        assert(Equal(db, before))
        AssertRootReferences(db, refs)
        assert(db.global.TextTemplateEntityMigration == nil)
    end
end)

Test('validation rejects broken target graphs', function()
    local db = EntityDB()
    db.global.UserLayouts['layout:A:001'].payload.Units.player.Texts.Health.templateId = Id(99)
    local before = Copy(db)
    local result = cutover.Validate(db)
    assert(not result.ok and result.errorCode == 'invalid-entity-graph')
    assert(Equal(db, before))
end)

Test('empty first start is prepared only on the private copy', function()
    local cases = {
        {},
        {sv = {profileKeys = {}}},
        {sv = {global = {}}},
        {global = {UserLayouts = {}}},
    }
    for index, db in ipairs(cases) do
        local result = Ok(cutover.Prepare(db, {generator = Generator()}))
        assert(result.changed == true)
        local raw = db.sv or db
        assert(raw.global and raw.global.UserLayouts)
        assert(raw.global.TextTemplateEntityMigration.complete == true)
    end
end)

Test('partially populated first start is rejected', function()
    Fails({profileKeys = {['Player - Realm'] = 'Profile'}}, 'invalid-global')
    Fails({global = {UserPresets = {Preset = {}}}}, 'invalid-layout-store')
    Fails({global = {UserLayouts = {}, TextTemplateEntityMigration = {}}}, 'unknown-marker-version')
    Fails({global = {UserLayouts = {}, TextTemplateEntityMigrationBackup = {}}}, 'backup-without-marker')
    Fails({global = {UserLayouts = {}, TextTemplateEntityMigration = {}, TextTemplateEntityMigrationBackup = {}}}, 'unknown-marker-version')
end)

Test('AceDB alias divergence is rejected before preparation', function()
    Fails({sv = {global = {}}, global = {}}, 'ace-db-alias-conflict')
end)

Test('final guard rejects SavedVariables replacement and root changes', function()
    local function Conflict(mutator, db)
        local real = Generator()
        local changed = false
        local generator = {
            Reserve = function(_, working, reserved)
                if not changed then
                    changed = true
                    mutator(db)
                end
                return real:Reserve(working, reserved)
            end,
        }
        local result = cutover.Prepare(db, {generator = generator})
        assert(not result.ok and result.errorCode == 'live-conflict')
        assert(db.global.TextTemplateEntityMigration == nil)
    end

    local db = LegacyDB()
    Conflict(function(target) target.sv = Copy(target.sv or {global = target.global}) end, db)

    db = LegacyDB()
    db.sv = {global = db.global}
    Conflict(function(target) target.sv.global = {} end, db)

    db = LegacyDB()
    Conflict(function(target) target.global = Copy(target.global) end, db)

    db = LegacyDB()
    Conflict(function(target)
        target.global.TextTemplateEntityMigrationBackup = {version = 1}
    end, db)

    db = LegacyDB()
    Conflict(function(target)
        target.profiles.Added = {TextTemplates = {}}
    end, db)
end)

Test('private Legacy migration creates and publishes backup and mappings', function()
    local db = LegacyWithProfiles()
    db.global.LayoutMigrationBackup = nil
    local beforeProfiles = Copy(db.profiles)
    local result = Ok(cutover.Prepare(db, {generator = Generator()}))
    assert(result.changed == true)
    assert(db.global.LayoutMigration.version == 1)
    assert(type(db.global.LayoutMigration.profileMap.Legacy) == 'string')
    assert(db.global.LayoutMigrationBackup.version == 1)
    assert(Equal(db.profiles, beforeProfiles))
    local metadata = Copy(db.global.LayoutMigration)
    local backup = Copy(db.global.LayoutMigrationBackup)
    local second = Ok(cutover.Prepare(db, {generator = Generator()}))
    assert(second.changed == false)
    assert(Equal(db.global.LayoutMigration, metadata))
    assert(Equal(db.global.LayoutMigrationBackup, backup))
end)

Test('recovery restores legacy metadata at every commit write', function()
    for failureAt = 1, 7 do
        local db = LegacyWithProfiles()
        db.global.LayoutMigrationBackup = nil
        local before = Copy(db)
        local refs = RootReferences(db)
        local result = cutover.Prepare(db, {
            generator = Generator(),
            testCommitFailureAt = failureAt,
        })
        assert(not result.ok and result.errorCode == 'commit-failed')
        assert(Equal(db, before), 'commit failure left a mixed root at ' .. failureAt)
        AssertRootReferences(db, refs)
    end
end)

Test('backup validation rejects empty, incomplete, wrong-version and self-embedded snapshots', function()
    local db = LegacyDB()
    Ok(cutover.Prepare(db, {generator = Generator()}))
    db.global.TextTemplateEntityMigrationBackup.savedVariables = {}
    local result = cutover.Prepare(db)
    assert(not result.ok and result.errorCode == 'invalid-backup')

    db = LegacyDB()
    Ok(cutover.Prepare(db, {generator = Generator()}))
    db.global.TextTemplateEntityMigrationBackup.savedVariables = {global = {}}
    result = cutover.Prepare(db)
    assert(not result.ok and result.errorCode == 'invalid-backup-snapshot')

    db = LegacyDB()
    Ok(cutover.Prepare(db, {generator = Generator()}))
    db.global.TextTemplateEntityMigrationBackup.version = 99
    result = cutover.Prepare(db)
    assert(not result.ok and result.errorCode == 'invalid-backup')

    db = LegacyDB()
    Ok(cutover.Prepare(db, {generator = Generator()}))
    local backup = db.global.TextTemplateEntityMigrationBackup
    backup.savedVariables.global.TextTemplateEntityMigrationBackup = backup
    result = cutover.Prepare(db)
    assert(not result.ok and result.errorCode == 'invalid-backup-snapshot')
end)

Test('layout envelope requires a user ID, name and canonical payload', function()
    local db = LegacyDB()
    Ok(cutover.Prepare(db, {generator = Generator()}))
    db.global.UserLayouts['layout:A:001'].name = nil
    local result = cutover.Validate(db)
    assert(not result.ok and result.errorCode == 'invalid-layout-envelope')

    db = LegacyDB()
    Ok(cutover.Prepare(db, {generator = Generator()}))
    db.global.UserLayouts['layout:A:001'].payload.Units = nil
    result = cutover.Validate(db)
    assert(not result.ok and result.errorCode == 'invalid-layout-envelope')

    db = LegacyDB()
    Ok(cutover.Prepare(db, {generator = Generator()}))
    local layout = db.global.UserLayouts['layout:A:001']
    db.global.UserLayouts['builtin:wrong'] = layout
    db.global.UserLayouts['layout:A:001'] = nil
    result = cutover.Validate(db)
    assert(not result.ok and result.errorCode == 'invalid-layout-structure')
end)

Test('commit phase is callback-free after option capture', function()
    local db = LegacyDB()
    local indexCalls = 0
    local options = setmetatable({
        generator = Generator(),
    }, {
        __index = function(_, key)
            indexCalls = indexCalls + 1
            if key == 'testCommitFailureAt' then return 5 end
            error('options metamethod called: ' .. tostring(key))
        end,
    })
    local result = cutover.Prepare(db, options)
    assert(result.ok and result.changed == true)
    assert(indexCalls == 0)
end)

local passedReal = 0
if arg and arg[1] then
    local environment = {}
    assert(loadfile(arg[1], 't', environment))()
    local source = assert(environment.FocalPointDB, 'fixture must define FocalPointDB')
    local beforeSource = Copy(source)
    local db = Copy(source)
    local result = cutover.Prepare(db, {generator = Generator()})
    assert(result and result.ok, tostring(result and result.errorCode) .. ':' .. tostring(result and result.detailCode or ''))
    local second = cutover.Prepare(db, {generator = Generator()})
    assert(second.ok and second.changed == false)
    assert(Equal(source, beforeSource), 'real source environment changed')
    local layouts, texts, mains, states = 0, 0, 0, 0
    for _, layout in pairs(db.global.UserLayouts or {}) do
        layouts = layouts + 1
        for _, unit in pairs(layout.payload.Units or {}) do
            for _, text in pairs(unit.Texts or {}) do
                texts = texts + 1
                if text.templateId then mains = mains + 1 end
                states = states + Count(text.stateTemplateIds)
            end
        end
    end
    print(string.format('REAL: layouts=%d texts=%d mainFKs=%d stateFKs=%d records=%d',
        layouts, texts, mains, states, Count(db.global.TextTemplates)))
    print('PASS: real SavedVariables processed on independent copy; source unchanged; second run idempotent')
    passedReal = 1
end

print('TextTemplateEntityCutover: ' .. (passed + passedReal) .. ' passed')
