local _, FocalPoint = ...

FocalPoint.TextTemplateEntityCutover = FocalPoint.TextTemplateEntityCutover or {}
local Cutover = FocalPoint.TextTemplateEntityCutover

local BACKUP_KEY = 'TextTemplateEntityMigrationBackup'
local MARKER_KEY = 'TextTemplateEntityMigration'
local BACKUP_VERSION = 1
local MARKER_VERSION = 1
local LAYOUT_FORMAT_VERSION = 2

local function IsPlain(value)
    return type(value) == 'table' and getmetatable(value) == nil
end

local function IsKey(value)
    return type(value) == 'string' and value ~= ''
end

local function IsLayoutId(value)
    return type(value) == 'string'
        and value:match('^layout:[^:]+:[^:]+$') ~= nil
end

local function Copy(value, visiting)
    if type(value) ~= 'table' then
        local kind = type(value)
        assert(kind == 'nil' or kind == 'string' or kind == 'number' or kind == 'boolean',
            'invalid saved value')
        return value
    end
    assert(IsPlain(value), 'invalid saved table')
    visiting = visiting or {}
    assert(not visiting[value], 'cyclic saved table')
    visiting[value] = true
    local result = {}
    for key, entry in pairs(value) do
        assert(type(key) == 'string' or type(key) == 'number', 'invalid saved key')
        result[Copy(key, visiting)] = Copy(entry, visiting)
    end
    visiting[value] = nil
    return result
end

local function Equal(left, right)
    if left == right then return true end
    if type(left) ~= 'table' or type(right) ~= 'table' then return false end
    for key, value in pairs(left) do
        if not Equal(value, right[key]) then return false end
    end
    for key in pairs(right) do
        if left[key] == nil then return false end
    end
    return true
end

local function Count(source)
    local count = 0
    if type(source) == 'table' then
        for _ in pairs(source) do count = count + 1 end
    end
    return count
end

local function IsEmptyValue(value, visiting, depth)
    if type(value) ~= 'table' then return false end
    depth = depth or 0
    if next(value) == nil then return true end
    if depth >= 2 then return false end
    visiting = visiting or {}
    if visiting[value] then return false end
    visiting[value] = true
    for _, entry in pairs(value) do
        if type(entry) ~= 'table' or not IsEmptyValue(entry, visiting, depth + 1) then
            visiting[value] = nil
            return false
        end
    end
    visiting[value] = nil
    return true
end

local function Error(code, detail)
    local result = {ok = false, errorCode = code}
    if type(detail) == 'table' then
        for key, value in pairs(detail) do result[key] = value end
    end
    return result
end

local function RawSavedVariables(db)
    if type(db) ~= 'table' then return nil end
    local saved = rawget(db, 'sv')
    if saved ~= nil then
        return IsPlain(saved) and saved or nil
    end
    return db
end

local function RawGlobal(raw)
    return type(raw) == 'table' and rawget(raw, 'global') or nil
end

local function ValidateAceDBAlias(db)
    if type(db) ~= 'table' then return false, 'invalid-db' end
    local saved = rawget(db, 'sv')
    if saved == nil then return true end
    if not IsPlain(saved) then return false, 'invalid-saved-variables' end

    local dbGlobal = rawget(db, 'global')
    local savedGlobal = rawget(saved, 'global')
    if dbGlobal ~= nil and not IsPlain(dbGlobal) then
        return false, 'invalid-global'
    end
    if savedGlobal ~= nil and not IsPlain(savedGlobal) then
        return false, 'invalid-global'
    end
    -- A materialized db.global without its SavedVariables counterpart is
    -- already divergent. A lazy missing db.global is allowed.
    if dbGlobal ~= nil and savedGlobal == nil then
        return false, 'ace-db-alias-conflict'
    end
    if dbGlobal ~= nil and savedGlobal ~= nil and dbGlobal ~= savedGlobal then
        return false, 'ace-db-alias-conflict'
    end
    return true
end

local function LiveGlobal(db)
    if type(db) ~= 'table' then return nil end
    local saved = rawget(db, 'sv')
    if type(saved) == 'table' then
        return rawget(saved, 'global') or rawget(db, 'global')
    end
    return rawget(db, 'global')
end

local function EnsureLiveGlobal(db)
    local saved = rawget(db, 'sv')
    if type(saved) == 'table' then
        local global = rawget(saved, 'global')
        if type(global) == 'table' then
            return global, nil, nil, false
        end
        global = {}
        rawset(saved, 'global', global)
        return global, saved, 'global', true
    end

    local global = rawget(db, 'global')
    if type(global) == 'table' then
        return global, nil, nil, false
    end
    global = {}
    rawset(db, 'global', global)
    return global, db, 'global', true
end

local function IsToken(value)
    return type(value) == 'string' and #value == 32 and value:match('^[0-9a-f]+$') ~= nil
end

local function ValidateIdState(state)
    return state == nil or (IsPlain(state) and IsToken(state.namespace))
end

local function ValidateUserStore(records, state)
    if records ~= nil and not IsPlain(records) then return false, 'invalid-template-store' end
    if not ValidateIdState(state) then return false, 'invalid-id-state' end
    local library = FocalPoint.TextTemplateLibrary
    if type(library) ~= 'table' or type(library.GetTemplateIdKind) ~= 'function'
        or type(library.ValidateTemplateRecord) ~= 'function'
    then
        return false, 'entity-library-unavailable'
    end
    for id, record in pairs(records or {}) do
        if type(id) ~= 'string' or library.GetTemplateIdKind(id) ~= 'user' then
            return false, 'invalid-user-template-id'
        end
        if not library.ValidateTemplateRecord(record) then
            return false, 'invalid-template-record'
        end
    end
    return true
end

local function ValidateBackup(backup)
    if not IsPlain(backup) or backup.version ~= BACKUP_VERSION
        or backup.snapshot ~= 'SavedVariables'
        or not IsPlain(backup.savedVariables)
        or next(backup.savedVariables) == nil
    then
        return false, 'invalid-backup'
    end
    local saved = backup.savedVariables
    local global = rawget(saved, 'global')
    if not IsPlain(global) or not IsPlain(rawget(global, 'UserLayouts')) then
        return false, 'invalid-backup-snapshot'
    end
    if rawget(global, BACKUP_KEY) ~= nil or rawget(global, MARKER_KEY) ~= nil then
        return false, 'invalid-backup-snapshot'
    end
    return true
end

local function TextsFor(unit)
    return type(unit) == 'table' and unit.Texts or nil
end

local function ValidatePreparedLayouts(layouts, records, state)
    if not IsPlain(layouts) then return false, 'invalid-layout-store' end
    local library = FocalPoint.TextTemplateLibrary
    local seenLayouts = {}
    for layoutId, layout in pairs(layouts) do
        if not IsLayoutId(layoutId) or not IsPlain(layout) or seenLayouts[layout] then
            return false, 'invalid-layout-structure'
        end
        seenLayouts[layout] = true
        if type(layout.name) ~= 'string' or not layout.name:find('%S')
            or layout.formatVersion ~= LAYOUT_FORMAT_VERSION
            or not IsPlain(layout.payload)
            or layout.payload.TextTemplates ~= nil
            or not IsPlain(layout.payload.Units)
        then
            return false, 'invalid-layout-envelope'
        end
        for unitKey, unit in pairs(layout.payload.Units) do
            if not IsKey(unitKey) or not IsPlain(unit) then
                return false, 'invalid-unit-structure'
            end
            local texts = TextsFor(unit)
            if texts ~= nil and not IsPlain(texts) then
                return false, 'invalid-text-store'
            end
            for textKey, text in pairs(texts or {}) do
                if not IsKey(textKey) or not IsPlain(text)
                    or text.templateName ~= nil or text.stateTemplates ~= nil
                then
                    return false, 'legacy-template-field'
                end
                if text.tag ~= nil and type(text.tag) ~= 'string' then
                    return false, 'invalid-tag'
                end
                if text.templateId ~= nil
                    and library.GetTemplateIdKind(text.templateId) == nil
                then
                    return false, 'invalid-main-template-id'
                end
                if text.stateTemplateIds ~= nil then
                    if not IsPlain(text.stateTemplateIds) then
                        return false, 'invalid-state-template-ids'
                    end
                    for stateKey, id in pairs(text.stateTemplateIds) do
                        if not IsKey(stateKey) or library.GetTemplateIdKind(id) == nil then
                            return false, 'invalid-state-template-id'
                        end
                    end
                end
            end
        end
    end
    local global = {TextTemplates = records, TextTemplateIdState = state}
    local validation = FocalPoint.TextTemplateValidation
        and FocalPoint.TextTemplateValidation.ValidateEntityLayouts
    if type(validation) ~= 'function' then
        return false, 'entity-validator-unavailable'
    end
    local graph = validation(layouts, {global = global})
    if type(graph) ~= 'table' or graph.valid ~= true then
        return false, 'invalid-entity-graph'
    end
    return true
end

local function ValidateTarget(global)
    if not IsPlain(global) then return false, 'invalid-global' end
    local records, state = rawget(global, 'TextTemplates'), rawget(global, 'TextTemplateIdState')
    local storeOk, storeCode = ValidateUserStore(records, state)
    if not storeOk then return false, storeCode end
    if records == nil then records = {} end
    return ValidatePreparedLayouts(rawget(global, 'UserLayouts'), records, state)
end

local function ClassifyRaw(raw)
    local global = RawGlobal(raw)
    if global == nil then
        if IsEmptyValue(raw) then
            return {ok = true, classification = 'empty'}
        end
        return Error('invalid-global')
    end
    if not IsPlain(global) then return Error('invalid-global') end

    -- Marker/backup roots are authoritative presence indicators. Inspect them
    -- before the permissive empty-start classification, even when malformed.
    local marker = rawget(global, MARKER_KEY)
    local backup = rawget(global, BACKUP_KEY)
    if marker ~= nil or backup ~= nil then
        if marker ~= nil then
            if not IsPlain(marker) or marker.version ~= MARKER_VERSION then
                return Error('unknown-marker-version')
            end
            if marker.layoutFormatVersion ~= LAYOUT_FORMAT_VERSION or marker.complete ~= true then
                return Error('invalid-marker')
            end
            local backupOk, backupCode = ValidateBackup(backup)
            if not backupOk then return Error(backupCode) end
            local ok, code = ValidateTarget(global)
            if not ok then return Error('marker-data-inconsistent', {detailCode = code}) end
            return {ok = true, classification = 'complete', marker = marker}
        end
        return Error('backup-without-marker')
    end

    if IsEmptyValue(raw) then
        return {ok = true, classification = 'empty'}
    end

    local layouts = rawget(global, 'UserLayouts')
    if not IsPlain(layouts) then return Error('invalid-layout-store') end
    local hasLegacy, hasEntity = false, false
    for layoutId, layout in pairs(layouts) do
        if not IsKey(layoutId) or not IsPlain(layout) or not IsPlain(layout.payload) then
            return Error('unclassifiable-layout')
        end
        local payload = layout.payload
        local legacyLayout = layout.formatVersion == 1 and IsPlain(payload.TextTemplates)
            and IsPlain(payload.Units)
        local entityLayout = layout.formatVersion == LAYOUT_FORMAT_VERSION
            and payload.TextTemplates == nil and IsPlain(payload.Units)
        if not legacyLayout and not entityLayout then
            return Error('mixed-or-invalid-layout')
        end
        if legacyLayout then
            hasLegacy = true
            for _, unit in pairs(payload.Units) do
                if not IsPlain(unit) or (unit.Texts ~= nil and not IsPlain(unit.Texts)) then
                    return Error('unclassifiable-layout')
                end
                for _, text in pairs(unit.Texts or {}) do
                    if not IsPlain(text) or text.templateId ~= nil or text.stateTemplateIds ~= nil then
                        return Error('mixed-layout')
                    end
                end
            end
        else
            hasEntity = true
            for _, unit in pairs(payload.Units) do
                if not IsPlain(unit) or (unit.Texts ~= nil and not IsPlain(unit.Texts)) then
                    return Error('unclassifiable-layout')
                end
                for _, text in pairs(unit.Texts or {}) do
                    if not IsPlain(text) or text.templateName ~= nil or text.stateTemplates ~= nil then
                        return Error('mixed-layout')
                    end
                end
            end
        end
    end
    if hasLegacy and hasEntity then return Error('mixed-layout') end
    if hasEntity then
        local storeOk, storeCode = ValidateUserStore(rawget(global, 'TextTemplates'),
            rawget(global, 'TextTemplateIdState'))
        if not storeOk then return Error(storeCode) end
        return Error('entity-without-marker')
    end
    local storeOk, storeCode = ValidateUserStore(rawget(global, 'TextTemplates'),
        rawget(global, 'TextTemplateIdState'))
    if not storeOk then return Error(storeCode) end
    return {ok = true, classification = 'legacy'}
end

local function NeedsLegacyPreparation(working)
    local global = RawGlobal(working) or {}
    local state = rawget(global, 'LayoutMigration')
    if IsPlain(state) and type(state.version) == 'number' and state.version >= 1 then
        return false
    end
    local profiles = rawget(working, 'profiles')
    local presets = rawget(global, 'UserPresets')
    return Count(profiles) > 0 or Count(presets) > 0
end

local function PrepareLegacySources(working)
    if not NeedsLegacyPreparation(working) then return true, nil end
    local migration = FocalPoint.LayoutMigration
    if type(migration) ~= 'table'
        or type(migration.EnsureBackup) ~= 'function'
        or type(migration.MigrateAll) ~= 'function'
    then
        return false, 'legacy-preparation-unavailable'
    end
    local backupOk = migration.EnsureBackup(working)
    if backupOk ~= true then
        return false, 'legacy-backup-failed'
    end
    local result = migration.MigrateAll(working)
    if type(result) ~= 'table' or result.complete ~= true or #(result.errors or {}) ~= 0 then
        return false, 'legacy-preparation-failed', result
    end
    local global = RawGlobal(working)
    if not IsPlain(global)
        or not IsPlain(rawget(global, 'LayoutMigration'))
        or not IsPlain(rawget(global, 'LayoutMigrationBackup'))
    then
        return false, 'legacy-metadata-invalid'
    end
    return true, nil, {
        LayoutMigration = Copy(rawget(global, 'LayoutMigration')),
        LayoutMigrationBackup = Copy(rawget(global, 'LayoutMigrationBackup')),
    }
end

local function SetFormatVersion(layouts)
    for _, layout in pairs(layouts) do
        layout.formatVersion = LAYOUT_FORMAT_VERSION
    end
end

local function NormalizeEmptyWorking(working)
    local global = RawGlobal(working)
    if global == nil then
        global = {}
        rawset(working, 'global', global)
    end
    if rawget(global, 'UserLayouts') == nil then
        rawset(global, 'UserLayouts', {})
    end
    return global
end

local function ValidateSourceRoots(raw)
    local global = RawGlobal(raw)
    if IsEmptyValue(raw) then return true end
    return IsPlain(global) and IsPlain(rawget(global, 'UserLayouts'))
end


local function SnapshotRoots(raw)
    local global = RawGlobal(raw) or {}
    return {
        UserLayouts = Copy(rawget(global, 'UserLayouts')),
        TextTemplates = Copy(rawget(global, 'TextTemplates')),
        TextTemplateIdState = Copy(rawget(global, 'TextTemplateIdState')),
        Marker = Copy(rawget(global, MARKER_KEY)),
        Backup = Copy(rawget(global, BACKUP_KEY)),
        LayoutMigration = Copy(rawget(global, 'LayoutMigration')),
        LayoutMigrationBackup = Copy(rawget(global, 'LayoutMigrationBackup')),
    }
end

local function RelevantSnapshot(raw)
    local global = RawGlobal(raw) or {}
    return {
        char = Copy(rawget(raw, 'char')),
        profileKeys = Copy(rawget(raw, 'profileKeys')),
        profiles = Copy(rawget(raw, 'profiles')),
        global = {
            UserLayouts = Copy(rawget(global, 'UserLayouts')),
            TextTemplates = Copy(rawget(global, 'TextTemplates')),
            TextTemplateIdState = Copy(rawget(global, 'TextTemplateIdState')),
            Marker = Copy(rawget(global, MARKER_KEY)),
            Backup = Copy(rawget(global, BACKUP_KEY)),
            LayoutMigration = Copy(rawget(global, 'LayoutMigration')),
            LayoutMigrationBackup = Copy(rawget(global, 'LayoutMigrationBackup')),
            UserPresets = Copy(rawget(global, 'UserPresets')),
            ProfileAutomation = Copy(rawget(global, 'ProfileAutomation')),
        },
    }
end

local function CaptureGuard(db, raw)
    local saved = rawget(db, 'sv')
    local savedGlobal = type(saved) == 'table' and rawget(saved, 'global') or nil
    return {
        saved = saved,
        dbGlobal = rawget(db, 'global'),
        savedGlobal = savedGlobal,
        snapshot = RelevantSnapshot(raw),
    }
end

local function SameGuard(db, raw, guard)
    local saved = rawget(db, 'sv')
    local savedGlobal = type(saved) == 'table' and rawget(saved, 'global') or nil
    if saved ~= guard.saved or rawget(db, 'global') ~= guard.dbGlobal
        or savedGlobal ~= guard.savedGlobal
    then
        return false
    end
    local aliasOk = ValidateAceDBAlias(db)
    return aliasOk and Equal(RelevantSnapshot(raw), guard.snapshot)
end

local function SameRoots(raw, roots)
    local global = RawGlobal(raw) or {}
    return Equal(rawget(global, 'UserLayouts'), roots.UserLayouts)
        and Equal(rawget(global, 'TextTemplates'), roots.TextTemplates)
        and Equal(rawget(global, 'TextTemplateIdState'), roots.TextTemplateIdState)
        and Equal(rawget(global, MARKER_KEY), roots.Marker)
        and Equal(rawget(global, BACKUP_KEY), roots.Backup)
        and Equal(rawget(global, 'LayoutMigration'), roots.LayoutMigration)
        and Equal(rawget(global, 'LayoutMigrationBackup'), roots.LayoutMigrationBackup)
end

local function Commit(db, roots, backup, prepared, legacyMetadata, failureAt)
    local global, owner, ownerKey, createdGlobal = EnsureLiveGlobal(db)
    if type(global) ~= 'table' then return Error('live-global-unavailable') end
    local old = {
        UserLayouts = rawget(global, 'UserLayouts'),
        TextTemplates = rawget(global, 'TextTemplates'),
        TextTemplateIdState = rawget(global, 'TextTemplateIdState'),
        Backup = rawget(global, BACKUP_KEY),
        Marker = rawget(global, MARKER_KEY),
        LayoutMigration = rawget(global, 'LayoutMigration'),
        LayoutMigrationBackup = rawget(global, 'LayoutMigrationBackup'),
    }
    local writes = 0
    local function Write(key, value)
        rawset(global, key, value)
        writes = writes + 1
        if failureAt ~= nil and failureAt == writes then
            error('injected-commit-failure')
        end
    end
    local ok, reason = pcall(function()
        Write('UserLayouts', prepared.layouts)
        Write('TextTemplates', prepared.templates)
        Write('TextTemplateIdState', prepared.idState)
        if legacyMetadata then
            Write('LayoutMigration', legacyMetadata.LayoutMigration)
            Write('LayoutMigrationBackup', legacyMetadata.LayoutMigrationBackup)
        end
        Write(BACKUP_KEY, backup)
        Write(MARKER_KEY, {
            version = MARKER_VERSION,
            layoutFormatVersion = LAYOUT_FORMAT_VERSION,
            complete = true,
        })
    end)
    if not ok then
        rawset(global, 'UserLayouts', old.UserLayouts)
        rawset(global, 'TextTemplates', old.TextTemplates)
        rawset(global, 'TextTemplateIdState', old.TextTemplateIdState)
        rawset(global, BACKUP_KEY, old.Backup)
        rawset(global, MARKER_KEY, old.Marker)
        rawset(global, 'LayoutMigration', old.LayoutMigration)
        rawset(global, 'LayoutMigrationBackup', old.LayoutMigrationBackup)
        if createdGlobal then rawset(owner, ownerKey, nil) end
        return Error('commit-failed', {detail = tostring(reason)})
    end
    return {ok = true, changed = true, classification = roots.classification}
end

function Cutover.Classify(db)
    local raw = RawSavedVariables(db)
    if not raw then return Error('invalid-db') end
    local aliasOk, aliasCode = ValidateAceDBAlias(db)
    if not aliasOk then return Error(aliasCode) end
    local ok, result = pcall(ClassifyRaw, raw)
    if not ok then return Error('invalid-saved-data', {detail = tostring(result)}) end
    return result
end

function Cutover.Validate(db)
    local raw = RawSavedVariables(db)
    if not raw then return Error('invalid-db') end
    local aliasOk, aliasCode = ValidateAceDBAlias(db)
    if not aliasOk then return Error(aliasCode) end
    local global = RawGlobal(raw)
    if not global then return Error('invalid-global') end
    local ok, code = ValidateTarget(global)
    if not ok then return Error(code) end
    local backupOk, backupCode = ValidateBackup(rawget(global, BACKUP_KEY))
    if not backupOk then return Error(backupCode) end
    local marker = rawget(global, MARKER_KEY)
    if not IsPlain(marker) or marker.version ~= MARKER_VERSION
        or marker.layoutFormatVersion ~= LAYOUT_FORMAT_VERSION or marker.complete ~= true
    then
        return Error('invalid-marker')
    end
    return {ok = true}
end

function Cutover.Prepare(db, options)
    local optionTable = type(options) == 'table' and options or {}
    local generator = rawget(optionTable, 'generator')
    local failureAt = rawget(optionTable, 'testCommitFailureAt')
    if failureAt ~= nil and type(failureAt) ~= 'number' then
        return Error('invalid-options')
    end

    local raw = RawSavedVariables(db)
    if not raw then return Error('invalid-db') end
    local aliasOk, aliasCode = ValidateAceDBAlias(db)
    if not aliasOk then return Error(aliasCode) end
    local ok, classification = pcall(ClassifyRaw, raw)
    if not ok then return Error('invalid-saved-data', {detail = tostring(classification)}) end
    if classification.ok and classification.classification == 'complete' then
        return {ok = true, changed = false, classification = 'complete'}
    end
    if not classification.ok then return classification end
    local guard = CaptureGuard(db, raw)

    local roots
    ok, roots = pcall(SnapshotRoots, raw)
    if not ok then return Error('invalid-saved-data', {detail = tostring(roots)}) end
    roots.classification = classification.classification

    local working
    ok, working = pcall(Copy, raw)
    if not ok then return Error('working-copy-failed', {detail = tostring(working)}) end
    if classification.classification == 'empty' then
        NormalizeEmptyWorking(working)
    end
    local backupSource = classification.classification == 'empty' and working or raw
    local backup
    ok, backup = pcall(function()
        return {
            version = BACKUP_VERSION,
            snapshot = 'SavedVariables',
            savedVariables = Copy(backupSource),
        }
    end)
    if not ok then return Error('backup-failed', {detail = tostring(backup)}) end

    local legacyOk, legacyCode, legacyMetadata = PrepareLegacySources(working)
    if not legacyOk then
        return Error(legacyCode, {migration = legacyMetadata})
    end
    local migration = FocalPoint.TextTemplateEntityMigration
    if type(migration) ~= 'table' or type(migration.Prepare) ~= 'function' then
        return Error('entity-preparation-unavailable')
    end
    local prepared
    ok, prepared = pcall(migration.Prepare, working, generator)
    if not ok then return Error('entity-preparation-failed', {detail = tostring(prepared)}) end
    if type(prepared) ~= 'table' or prepared.ready ~= true then
        return Error('entity-preparation-failed', {diagnostics = prepared and prepared.diagnostics})
    end
    SetFormatVersion(prepared.layouts)
    local preparedGlobal = {
        UserLayouts = prepared.layouts,
        TextTemplates = prepared.templates,
        TextTemplateIdState = prepared.idState,
    }
    local valid, code = ValidateTarget(preparedGlobal)
    if not valid then return Error('target-validation-failed', {detailCode = code}) end
    if not SameGuard(db, raw, guard) then return Error('live-conflict') end
    if not SameRoots(raw, roots) or not ValidateSourceRoots(raw) then
        return Error('live-conflict')
    end
    return Commit(db, roots, backup, prepared, legacyMetadata, failureAt)
end

return Cutover
