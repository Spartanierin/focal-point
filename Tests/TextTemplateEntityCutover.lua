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

local function CanonicalLegacyDB()
    local catalog = ns.BuiltInTextTemplates.ListRecords()
    local function Content(id) return assert(catalog[id]).content end
    local function Layout(name, texts)
        local unitTexts = {
            Focus = {templateName = 'Unit Name Focus', enabled = false,
                tag = '[name]', color = {1, .5, 0}},
            Local = {tag = 'object-local'},
        }
        if name == 'A' then
            unitTexts.Focus.stateTemplates = {dead = 'Dead/Ghost Timer'}
            unitTexts.Target = {templateName = 'Unit Name Target'}
            unitTexts.FocusClass = {templateName = 'Focus Level and Class'}
            unitTexts.TargetClass = {templateName = 'Target Level and Class'}
            unitTexts.ChangedName = {templateName = 'Renamed'}
            unitTexts.ChangedContent = {templateName = 'Unit Name Focus Changed'}
        end
        return {name = name, formatVersion = 1, payload = {
            TextTemplates = texts,
            Units = {player = {Texts = unitTexts}},
        }}
    end
    return {global = {UserLayouts = {
        ['layout:A:001'] = Layout('A', {
            ['Unit Name Focus'] = Content('tpl:b:default-003'),
            ['Unit Name Target'] = Content('tpl:b:default-004'),
            ['Focus Level and Class'] = Content('tpl:b:default-016'),
            ['Target Level and Class'] = Content('tpl:b:default-017'),
            ['Dead/Ghost Timer'] = Content('tpl:b:default-005'),
            Renamed = Content('tpl:b:default-003'),
            ['Unit Name Focus Changed'] = 'changed',
            Tester = 'tester',
            Unreferenced = 'unreferenced',
        }),
        ['layout:B:001'] = Layout('B', {
            ['Unit Name Focus'] = Content('tpl:b:default-003'),
            CopyOnly = 'copy',
        }),
        ['layout:C:001'] = Layout('C', {
            ['Unit Name Focus'] = 'changed content',
        }),
    }}}
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

Test('E6A canonicalizes exact Built-in records in E3 without reserving User IDs', function()
    local db = CanonicalLegacyDB()
    local real = Generator(); local reservations = 0
    local generator = {Reserve = function(_, working, reserved)
        reservations = reservations + 1
        return real:Reserve(working, reserved)
    end}
    local result = Ok(cutover.Prepare(db, {generator = generator}))
    local a = db.global.UserLayouts['layout:A:001'].payload.Units.player.Texts
    local b = db.global.UserLayouts['layout:B:001'].payload.Units.player.Texts
    local c = db.global.UserLayouts['layout:C:001'].payload.Units.player.Texts
    assert(reservations == 6 and Count(db.global.TextTemplates) == 6)
    assert(a.Focus.templateId == 'tpl:b:default-003')
    assert(a.Target.templateId == 'tpl:b:default-004')
    assert(a.FocusClass.templateId == 'tpl:b:default-016')
    assert(a.TargetClass.templateId == 'tpl:b:default-017')
    assert(a.Focus.stateTemplateIds.dead == 'tpl:b:default-005')
    assert(a.ChangedName.templateId ~= 'tpl:b:default-003')
    assert(a.ChangedContent.templateId ~= 'tpl:b:default-003')
    assert(b.Focus.templateId == 'tpl:b:default-003')
    assert(library.GetTemplateIdKind(c.Focus.templateId) == 'user')
    assert(a.Focus.enabled == false and a.Focus.tag == '[name]' and a.Local.tag == 'object-local')
    local userNames = {}
    for _, record in pairs(db.global.TextTemplates) do userNames[record.name] = true end
    assert(userNames.Tester and userNames.Unreferenced and userNames.Renamed)
    assert(result.changed == true and result.classification == 'legacy')
end)

Test('normal E3 reservation cannot smuggle an exact Built-in ID', function()
    local record = ns.BuiltInTextTemplates.GetRecord('tpl:b:default-013')
    local source = {global = {UserLayouts = {
        ['layout:A:001'] = {name = 'A', formatVersion = 1, payload = {
            TextTemplates = {[record.name] = record.content},
            Units = {player = {Texts = {Text = {templateName = record.name}}}},
        }},
    }}}
    local prepared = ns.TextTemplateEntityMigration.Prepare(source, {
        Reserve = function() return 'tpl:b:default-013' end,
    })
    assert(not prepared.ready and prepared.mappings == nil and prepared.templates == nil)
    local found = false
    for _, diagnostic in ipairs(prepared.diagnostics or {}) do
        if diagnostic.errorCode == 'prepared-id-invariant-failure' then found = true end
    end
    assert(found)
end)

Test('ambiguous exact Built-in matches fall back to a User entity', function()
    local catalog = ns.BuiltInTextTemplates
    local original = catalog.ListRecords
    catalog.ListRecords = function()
        local records = original()
        records['tpl:b:ambiguous'] = records['tpl:b:default-003']
        return records
    end
    local exactMatches = 0
    for _, record in pairs(catalog.ListRecords()) do
        if record.name == 'Unit Name Focus' and record.content == '[name] [status] [status:timer]' then
            exactMatches = exactMatches + 1
        end
    end
    assert(exactMatches == 2)
    local db = {global = {UserLayouts = {
        ['layout:A:001'] = {name = 'A', formatVersion = 1, payload = {
            TextTemplates = {['Unit Name Focus'] = '[name] [status] [status:timer]'},
            Units = {player = {Texts = {Text = {templateName = 'Unit Name Focus'}}}},
        }},
    }}}
    local result = Ok(cutover.Prepare(db, {generator = Generator()}))
    catalog.ListRecords = original
    local text = db.global.UserLayouts['layout:A:001'].payload.Units.player.Texts.Text
    assert(text.templateId ~= 'tpl:b:default-003')
    assert(library.GetTemplateIdKind(text.templateId) == 'user')
    assert(result.changed == true)
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

Test('AceDB pre-start proof authorizes only the real fresh intermediate', function()
    strmatch = string.match
    function CreateFrame()
        return {RegisterEvent = function() end, SetScript = function() end}
    end
    function GetRealmName() return 'Test realm' end
    function UnitName() return 'Test player' end
    function UnitClass() return 'Mage', 'MAGE' end
    function UnitRace() return 'Human', 'Human' end
    function UnitFactionGroup() return 'Alliance' end
    function GetLocale() return 'enUS' end
    function GetCurrentRegion() return 3 end
    dofile('Libraries/LibStub/LibStub.lua')
    dofile('Libraries/CallbackHandler-1.0/CallbackHandler-1.0.lua')
    dofile('Libraries/Ace3/AceDB-3.0/AceDB-3.0.lua')
    local aceDB = LibStub('AceDB-3.0')
    local defaults = {global = {UserLayouts = {}}}

    local saved = {}
    local proof = assert(cutover.CapturePreAceDBStart(saved))
    assert(next(saved) == nil)
    local db = aceDB:New(saved, defaults, true)
    assert(type(saved.profileKeys) == 'table' and next(saved.profileKeys) ~= nil)
    local result = Ok(cutover.Prepare(db, {
        generator = Generator(),
        preAceDBStartProof = proof,
    }))
    assert(result.changed == true and saved.global and saved.global.UserLayouts)
    assert(saved.preAceDBStartProof == nil)

    local name = 'TextTemplateEntityCutoverAceDBAbsent'
    _G[name] = nil
    proof = assert(cutover.CapturePreAceDBStart(_G[name]))
    db = aceDB:New(name, defaults, true)
    saved = _G[name]
    assert(type(saved.profileKeys) == 'table' and next(saved.profileKeys) ~= nil)
    result = Ok(cutover.Prepare(db, {
        generator = Generator(),
        preAceDBStartProof = proof,
    }))
    assert(result.changed == true and saved.global and saved.global.UserLayouts)
    _G[name] = nil

    saved = {}
    db = aceDB:New(saved, defaults, true)
    local before = Copy(saved)
    result = cutover.Prepare(db, {generator = Generator()})
    assert(not result.ok and result.errorCode == 'invalid-global')
    assert(Equal(saved, before))

    saved = {profileKeys = {['Existing - Realm'] = 'Existing'}}
    local rejectedProof, reason = cutover.CapturePreAceDBStart(saved)
    assert(rejectedProof == nil and reason == 'saved-variables-not-fresh')
    db = aceDB:New(saved, defaults, true)
    before = Copy(saved)
    result = cutover.Prepare(db, {generator = Generator()})
    assert(not result.ok and result.errorCode == 'invalid-global')
    assert(Equal(saved, before))
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
    local layouts, texts, mains, states, userRecords = 0, 0, 0, 0, 0
    local builtinMain, builtinState, userMain, userState, missing = 0, 0, 0, 0, 0
    local referencedBuiltIns = {}
    for _, layout in pairs(db.global.UserLayouts or {}) do
        layouts = layouts + 1
        for _, unit in pairs(layout.payload.Units or {}) do
            for _, text in pairs(unit.Texts or {}) do
                texts = texts + 1
                if text.templateId then
                    mains = mains + 1
                    local kind = library.GetTemplateIdKind(text.templateId)
                    if kind == 'builtin' then
                        builtinMain = builtinMain + 1
                        referencedBuiltIns[text.templateId] = true
                    elseif kind == 'user' then
                        userMain = userMain + 1
                    end
                    if not library.ResolveTemplateEntity(text.templateId, db) then missing = missing + 1 end
                end
                for _, id in pairs(text.stateTemplateIds or {}) do
                    states = states + 1
                    local kind = library.GetTemplateIdKind(id)
                    if kind == 'builtin' then
                        builtinState = builtinState + 1
                        referencedBuiltIns[id] = true
                    elseif kind == 'user' then
                        userState = userState + 1
                    end
                    if not library.ResolveTemplateEntity(id, db) then missing = missing + 1 end
                end
            end
        end
    end
    userRecords = Count(db.global.TextTemplates)
    print(string.format('REAL: layouts=%d texts=%d mainFKs=%d stateFKs=%d userRecords=%d '
        .. 'builtinMainFKs=%d builtinStateFKs=%d referencedBuiltIns=%d userMainFKs=%d userStateFKs=%d missingFKs=%d',
        layouts, texts, mains, states, userRecords, builtinMain, builtinState, Count(referencedBuiltIns),
        userMain, userState, missing))
    print('PASS: real SavedVariables processed on independent copy; source unchanged; second run idempotent')
    passedReal = 1
end

print('TextTemplateEntityCutover: ' .. (passed + passedReal) .. ' passed')
