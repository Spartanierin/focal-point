local _, FocalPoint = ...

FocalPoint.LayoutMigration = FocalPoint.LayoutMigration or {}
local LayoutMigration = FocalPoint.LayoutMigration

local LayoutService = FocalPoint.LayoutService or {}
local UserLayoutStore = FocalPoint.UserLayoutStore or {}

local BACKUP_VERSION = 1
local MIGRATION_VERSION = 0
local ADDITIVE_MIGRATION_VERSION = 1
local BACKUP_KEY = "LayoutMigrationBackup"
local STATE_KEY = "LayoutMigration"
local LAYOUT_FORMAT_VERSION = 1
local DELETED_PROFILE_MAP_KEY = "deletedProfileMap"
local DELETED_USER_PRESET_MAP_KEY = "deletedUserPresetMap"

local function Clone(value)
    return LayoutService.Clone and LayoutService.Clone(value) or value
end

local function ResolveDB(db)
    return type(db) == "table" and db or FocalPoint.db
end

local function EnsureGlobal(db)
    db = ResolveDB(db)
    if type(db) ~= "table" then
        return nil
    end

    db.global = type(db.global) == "table" and db.global or {}
    return db.global
end

local function GetProfileStore(db)
    if type(db) ~= "table" then
        return nil
    end
    if type(db.profiles) == "table" then
        return db.profiles
    end

    local savedVariables = rawget(db, "sv")
    return type(savedVariables) == "table" and type(savedVariables.profiles) == "table" and savedVariables.profiles or nil
end

local function GetCurrentProfileName(db)
    if type(db) ~= "table" or type(db.GetCurrentProfile) ~= "function" then
        return nil
    end

    local ok, profileName = pcall(db.GetCurrentProfile, db)
    if ok and type(profileName) == "string" and profileName ~= "" then
        return profileName
    end

    return nil
end

local function IsValidSourceMap(map)
    if type(map) ~= "table" then
        return false
    end

    for sourceId, layoutId in pairs(map) do
        if type(sourceId) ~= "string" or sourceId == "" or type(layoutId) ~= "string" or layoutId == "" then
            return false
        end
    end

    return true
end

local function IsValidOptionalSourceMap(state, key)
    local map = type(state) == "table" and rawget(state, key) or nil
    return map == nil or IsValidSourceMap(map)
end

local function IsDeliberatelyDeleted(deletedMap, sourceId, layoutId)
    return type(deletedMap) == "table"
        and type(sourceId) == "string"
        and type(layoutId) == "string"
        and deletedMap[sourceId] == layoutId
end

local function SortedStringKeys(source)
    local keys = {}
    if type(source) ~= "table" then
        return keys
    end

    for key in pairs(source) do
        if type(key) == "string" and key ~= "" then
            keys[#keys + 1] = key
        end
    end

    table.sort(keys)
    return keys
end

local function GetProfileNames(db)
    if type(db) == "table" and type(db.GetProfiles) == "function" then
        local ok, profiles = pcall(db.GetProfiles, db, {})
        if ok and type(profiles) == "table" then
            table.sort(profiles)
            return profiles
        end
    end

    return SortedStringKeys(GetProfileStore(db))
end

local function GetProfileByName(db, profileName)
    if type(profileName) ~= "string" or profileName == "" then
        return nil
    end
    if type(db) == "table" and type(db.GetCurrentProfile) == "function" then
        local ok, currentProfileName = pcall(db.GetCurrentProfile, db)
        if ok and currentProfileName == profileName and type(db.profile) == "table" then
            return db.profile
        end
    end

    local profiles = GetProfileStore(db)
    return type(profiles) == "table" and type(profiles[profileName]) == "table" and profiles[profileName] or nil
end

local function BuildUsedNames(layouts)
    local used = {}
    if type(layouts) ~= "table" then
        return used
    end

    for _, record in pairs(layouts) do
        local name = type(record) == "table" and record.name or nil
        if type(name) == "string" and name ~= "" then
            used[string.lower(name)] = true
        end
    end

    return used
end

local function ResolveUniqueName(baseName, usedNames, preferredSuffix)
    baseName = type(baseName) == "string" and baseName ~= "" and baseName or "Migrated Layout"
    usedNames = type(usedNames) == "table" and usedNames or {}

    local function Reserve(candidate)
        local key = string.lower(candidate)
        if usedNames[key] then
            return nil
        end
        usedNames[key] = true
        return candidate
    end

    local resolved = Reserve(baseName)
    if resolved then
        return resolved
    end

    if type(preferredSuffix) == "string" and preferredSuffix ~= "" then
        resolved = Reserve(baseName .. " " .. preferredSuffix)
        if resolved then
            return resolved
        end
    end

    local index = 2
    while true do
        resolved = Reserve(string.format("%s (%d)", baseName, index))
        if resolved then
            return resolved
        end
        index = index + 1
    end
end

local function AppendError(result, source, id, reason)
    result.errors[#result.errors + 1] = {
        source = source,
        id = id,
        reason = reason,
    }
end

local function BuildResult()
    return {
        migratedProfiles = 0,
        skippedProfiles = 0,
        recoveredProfiles = 0,
        migratedUserPresets = 0,
        skippedUserPresets = 0,
        recoveredUserPresets = 0,
        errors = {},
        complete = false,
    }
end

local function BuildVerificationSection()
    return {
        total = 0,
        valid = 0,
        missingLegacy = 0,
        missingLayout = 0,
        mismatch = 0,
        unmappedLegacy = 0,
        orphanLayouts = 0,
    }
end

local function BuildVerificationResult()
    return {
        profiles = BuildVerificationSection(),
        userPresets = BuildVerificationSection(),
        errors = {},
        complete = false,
    }
end

local function AppendVerificationError(result, section, id, reason)
    result.errors[#result.errors + 1] = {
        section = section,
        id = id,
        reason = reason,
    }
end

local function PeekState(db)
    db = ResolveDB(db)
    local global = type(db) == "table" and rawget(db, "global") or nil
    local state = type(global) == "table" and rawget(global, STATE_KEY) or nil
    if type(state) ~= "table" then
        return nil, "missing-state"
    end
    if type(state.version) ~= "number" then
        return nil, "invalid-state-version"
    end
    if not IsValidSourceMap(state.profileMap) then
        return nil, "invalid-profile-map"
    end
    if not IsValidSourceMap(state.userPresetMap) then
        return nil, "invalid-user-preset-map"
    end
    if not IsValidOptionalSourceMap(state, DELETED_PROFILE_MAP_KEY) then
        return nil, "invalid-deleted-profile-map"
    end
    if not IsValidOptionalSourceMap(state, DELETED_USER_PRESET_MAP_KEY) then
        return nil, "invalid-deleted-user-preset-map"
    end

    return state
end

local function GetReadOnlyUserLayouts(db)
    if UserLayoutStore.ListRawReadOnly then
        return UserLayoutStore.ListRawReadOnly(db)
    end

    db = ResolveDB(db)
    local global = type(db) == "table" and rawget(db, "global") or nil
    local layouts = type(global) == "table" and rawget(global, "UserLayouts") or nil
    return type(layouts) == "table" and layouts or {}
end

local function DeepEqual(left, right)
    if left == right then
        return true
    end
    if type(left) ~= type(right) then
        return false
    end
    if type(left) ~= "table" then
        return false
    end

    for key, value in pairs(left) do
        if not DeepEqual(value, right[key]) then
            return false
        end
    end
    for key in pairs(right) do
        if left[key] == nil then
            return false
        end
    end

    return true
end

local function PayloadsEqual(left, right, defaults)
    if not (LayoutService.NormalizePayload and type(left) == "table" and type(right) == "table") then
        return false
    end

    local normalizedLeft = LayoutService.NormalizePayload(left, defaults)
    local normalizedRight = LayoutService.NormalizePayload(right, defaults)
    return DeepEqual(normalizedLeft, normalizedRight), normalizedLeft, normalizedRight
end

local function VerifyMappedPayload(result, sectionName, section, sourceId, legacyPayload, layouts, layoutId, defaults)
    section.total = section.total + 1

    if type(legacyPayload) ~= "table" then
        section.missingLegacy = section.missingLegacy + 1
        AppendVerificationError(result, sectionName, sourceId, "missing-legacy")
        return
    end

    local record = type(layouts) == "table" and layouts[layoutId] or nil
    if type(record) ~= "table" then
        section.missingLayout = section.missingLayout + 1
        AppendVerificationError(result, sectionName, sourceId, "missing-layout")
        return
    end

    local equal, normalizedLegacy, normalizedLayout = PayloadsEqual(legacyPayload, record.payload, defaults)
    if not equal then
        section.mismatch = section.mismatch + 1
        AppendVerificationError(result, sectionName, sourceId, "payload-mismatch")
        return
    end

    if normalizedLegacy
        and normalizedLayout
        and (
            normalizedLegacy.Units == normalizedLayout.Units
            or normalizedLegacy.TextTemplates == normalizedLayout.TextTemplates
        )
    then
        section.mismatch = section.mismatch + 1
        AppendVerificationError(result, sectionName, sourceId, "payload-alias")
        return
    end

    section.valid = section.valid + 1
end

local function VerifyUnmappedSources(result, sectionName, section, sourceIds, map, isComplete)
    if not isComplete then
        return
    end

    for _, sourceId in ipairs(sourceIds) do
        if type(map) ~= "table" or type(map[sourceId]) ~= "string" or map[sourceId] == "" then
            section.unmappedLegacy = section.unmappedLegacy + 1
            AppendVerificationError(result, sectionName, sourceId, "unmapped-legacy")
        end
    end
end

local function VerifyOrphanCreatedFrom(result, layouts, state)
    if type(layouts) ~= "table" or type(state) ~= "table" then
        return
    end

    for layoutId, record in pairs(layouts) do
        local createdFrom = type(record) == "table" and record.createdFrom or nil
        local source = type(createdFrom) == "table" and createdFrom.source or nil
        local sourceId = type(createdFrom) == "table" and createdFrom.id or nil
        if type(layoutId) == "string"
            and type(sourceId) == "string"
            and sourceId ~= ""
            and (source == "profile" or source == "userPreset")
        then
            local sectionName = source == "profile" and "profiles" or "userPresets"
            local section = result[sectionName]
            local map = source == "profile" and state.profileMap or state.userPresetMap
            if type(map) ~= "table" or map[sourceId] ~= layoutId then
                section.orphanLayouts = section.orphanLayouts + 1
                AppendVerificationError(result, sectionName, layoutId, "orphan-created-from")
            end
        end
    end
end

local function ResolvePreconditions(db)
    db = ResolveDB(db)
    local backupOk, backupReason = LayoutMigration.ValidateBackup(db)
    if not backupOk then
        return nil, nil, nil, backupReason
    end

    local state, stateReason = LayoutMigration.GetState(db)
    if type(state) ~= "table" then
        return nil, nil, nil, stateReason
    end

    if not (UserLayoutStore.EnsureStore and UserLayoutStore.GenerateId and UserLayoutStore.PutRaw) then
        return nil, nil, nil, "user-layout-store-unavailable"
    end

    local layouts = UserLayoutStore.EnsureStore()
    if type(layouts) ~= "table" then
        return nil, nil, nil, "user-layout-store-unavailable"
    end

    return db, state, layouts
end

local function FindLayoutByCreatedFrom(layouts, source, sourceId)
    local foundId = nil
    if type(layouts) ~= "table" or type(source) ~= "string" or type(sourceId) ~= "string" then
        return nil
    end

    for layoutId, record in pairs(layouts) do
        local createdFrom = type(record) == "table" and record.createdFrom or nil
        if type(layoutId) == "string"
            and type(createdFrom) == "table"
            and createdFrom.source == source
            and createdFrom.id == sourceId
        then
            if foundId ~= nil then
                return nil, "created-from-ambiguous"
            end
            foundId = layoutId
        end
    end

    return foundId
end

local function EnsureMappedSource(map, deletedMap, layouts, source, sourceId, result, recoveredField, skippedField)
    local mappedLayoutId = map[sourceId]
    if type(mappedLayoutId) == "string" and mappedLayoutId ~= "" then
        if type(layouts[mappedLayoutId]) == "table" then
            result[skippedField] = result[skippedField] + 1
            return true, "mapped"
        end
        if IsDeliberatelyDeleted(deletedMap, sourceId, mappedLayoutId) then
            result[skippedField] = result[skippedField] + 1
            return true, "deleted"
        end
        AppendError(result, source, sourceId, "mapped-layout-missing")
        return false, "mapped-layout-missing"
    end

    local recoveredLayoutId, recoveryError = FindLayoutByCreatedFrom(layouts, source, sourceId)
    if recoveryError then
        AppendError(result, source, sourceId, recoveryError)
        return false, recoveryError
    end
    if type(recoveredLayoutId) == "string" and recoveredLayoutId ~= "" then
        map[sourceId] = recoveredLayoutId
        result[recoveredField] = result[recoveredField] + 1
        return true, "recovered"
    end

    return true, "new"
end

local function StoreMigratedLayout(layouts, record)
    local layoutId = UserLayoutStore.GenerateId()
    if type(layoutId) ~= "string" or layoutId == "" then
        return nil, "id-failed"
    end

    local storedId = UserLayoutStore.PutRaw(layoutId, record)
    if storedId ~= layoutId or type(layouts[layoutId]) ~= "table" then
        return nil, "store-write-failed"
    end

    return layoutId
end

function LayoutMigration.ValidateBackup(db)
    db = ResolveDB(db)
    local global = type(db) == "table" and db.global or nil
    local backup = type(global) == "table" and global[BACKUP_KEY] or nil
    if backup == nil then
        return false, "missing-backup"
    end
    if type(backup) ~= "table" then
        return false, "invalid-backup"
    end
    if backup.version ~= BACKUP_VERSION then
        return false, "invalid-backup-version"
    end
    if type(backup.profiles) ~= "table" then
        return false, "missing-profiles"
    end
    if type(backup.userPresets) ~= "table" then
        return false, "missing-user-presets"
    end
    if type(backup.profileAutomation) ~= "table" then
        return false, "missing-profile-automation"
    end
    if backup.currentProfileName ~= nil
        and (type(backup.currentProfileName) ~= "string" or backup.currentProfileName == "")
    then
        return false, "invalid-current-profile"
    end

    return true, "ok"
end

function LayoutMigration.EnsureBackup(db)
    db = ResolveDB(db)
    local global = EnsureGlobal(db)
    if type(global) ~= "table" then
        return false, "db-unavailable"
    end

    if global[BACKUP_KEY] ~= nil then
        return LayoutMigration.ValidateBackup(db)
    end

    local profiles = GetProfileStore(db)
    if type(profiles) ~= "table" then
        return false, "missing-profiles"
    end

    local sourceGlobal = type(db.global) == "table" and db.global or {}
    global[BACKUP_KEY] = {
        version = BACKUP_VERSION,
        profiles = Clone(profiles) or {},
        userPresets = Clone(sourceGlobal.UserPresets) or {},
        profileAutomation = Clone(sourceGlobal.ProfileAutomation) or {},
        currentProfileName = GetCurrentProfileName(db),
    }

    return LayoutMigration.ValidateBackup(db)
end

function LayoutMigration.GetState(db)
    local global = EnsureGlobal(db)
    if type(global) ~= "table" then
        return nil, "db-unavailable"
    end

    if global[STATE_KEY] == nil then
        global[STATE_KEY] = {
            version = MIGRATION_VERSION,
            profileMap = {},
            userPresetMap = {},
        }
    end

    local state = global[STATE_KEY]
    if type(state) ~= "table" then
        return nil, "invalid-state"
    end
    if type(state.version) ~= "number" then
        return nil, "invalid-state-version"
    end
    if not IsValidSourceMap(state.profileMap) then
        return nil, "invalid-profile-map"
    end
    if not IsValidSourceMap(state.userPresetMap) then
        return nil, "invalid-user-preset-map"
    end

    if state[DELETED_PROFILE_MAP_KEY] == nil then
        state[DELETED_PROFILE_MAP_KEY] = {}
    end
    if state[DELETED_USER_PRESET_MAP_KEY] == nil then
        state[DELETED_USER_PRESET_MAP_KEY] = {}
    end
    if not IsValidSourceMap(state[DELETED_PROFILE_MAP_KEY]) then
        return nil, "invalid-deleted-profile-map"
    end
    if not IsValidSourceMap(state[DELETED_USER_PRESET_MAP_KEY]) then
        return nil, "invalid-deleted-user-preset-map"
    end

    return state
end

function LayoutMigration.MarkDeletedUserLayout(layoutId, createdFrom, db)
    if type(layoutId) ~= "string" or layoutId == "" then
        return false, "invalid-layout"
    end

    local source = type(createdFrom) == "table" and createdFrom.source or nil
    local sourceId = type(createdFrom) == "table" and createdFrom.id or nil
    local mapKey = source == "profile" and "profileMap" or source == "userPreset" and "userPresetMap" or nil
    local deletedMapKey = source == "profile" and DELETED_PROFILE_MAP_KEY
        or source == "userPreset" and DELETED_USER_PRESET_MAP_KEY
        or nil
    if type(sourceId) ~= "string" or sourceId == "" or mapKey == nil or deletedMapKey == nil then
        return true, "not-migrated"
    end

    local state, reason = LayoutMigration.GetState(db)
    if type(state) ~= "table" then
        return false, reason or "state-unavailable"
    end
    if state[mapKey][sourceId] ~= layoutId then
        return true, "mapping-mismatch"
    end

    state[deletedMapKey][sourceId] = layoutId
    return true, "marked-deleted"
end

function LayoutMigration.MigrateProfiles(db, context)
    context = type(context) == "table" and context or {}
    local result = type(context.result) == "table" and context.result or BuildResult()
    db = ResolveDB(db)
    local resolvedDB, state, layouts, preconditionError = ResolvePreconditions(db)
    if not resolvedDB then
        AppendError(result, "precondition", "profiles", preconditionError or "precondition-failed")
        return result
    end

    local defaults = FocalPoint.GetDefaultDB and FocalPoint:GetDefaultDB() or nil
    local usedNames = context.usedNames or BuildUsedNames(layouts)
    context.usedNames = usedNames

    for _, profileName in ipairs(GetProfileNames(resolvedDB)) do
        local ok, status = EnsureMappedSource(
            state.profileMap,
            state[DELETED_PROFILE_MAP_KEY],
            layouts,
            "profile",
            profileName,
            result,
            "recoveredProfiles",
            "skippedProfiles"
        )
        if not ok then
            -- Keep processing other sources; the failed source remains unmapped.
        elseif status == "new" then
            local profile = GetProfileByName(resolvedDB, profileName)
            local payload = LayoutService.MaterializeFromLegacyProfile
                and LayoutService.MaterializeFromLegacyProfile(profile, defaults)
                or nil
            if type(payload) ~= "table" then
                AppendError(result, "profile", profileName, "payload-invalid")
            else
                local record = {
                    name = ResolveUniqueName(profileName, usedNames),
                    payload = payload,
                    formatVersion = LAYOUT_FORMAT_VERSION,
                    createdFrom = {
                        source = "profile",
                        id = profileName,
                    },
                }
                local layoutId, reason = StoreMigratedLayout(layouts, record)
                if layoutId then
                    state.profileMap[profileName] = layoutId
                    result.migratedProfiles = result.migratedProfiles + 1
                else
                    AppendError(result, "profile", profileName, reason or "store-write-failed")
                end
            end
        end
    end

    return result
end

function LayoutMigration.MigrateUserPresets(db, context)
    context = type(context) == "table" and context or {}
    local result = type(context.result) == "table" and context.result or BuildResult()
    db = ResolveDB(db)
    local resolvedDB, state, layouts, preconditionError = ResolvePreconditions(db)
    if not resolvedDB then
        AppendError(result, "precondition", "userPresets", preconditionError or "precondition-failed")
        return result
    end

    local rawPresets = type(resolvedDB.global) == "table" and resolvedDB.global.UserPresets or nil
    local defaults = FocalPoint.GetDefaultDB and FocalPoint:GetDefaultDB() or nil
    local usedNames = context.usedNames or BuildUsedNames(layouts)
    context.usedNames = usedNames

    for _, presetId in ipairs(SortedStringKeys(rawPresets)) do
        local ok, status = EnsureMappedSource(
            state.userPresetMap,
            state[DELETED_USER_PRESET_MAP_KEY],
            layouts,
            "userPreset",
            presetId,
            result,
            "recoveredUserPresets",
            "skippedUserPresets"
        )
        if not ok then
            -- Keep processing other sources; the failed source remains unmapped.
        elseif status == "new" then
            local rawPreset = rawPresets[presetId]
            local payload = type(rawPreset) == "table"
                and type(rawPreset.layout) == "table"
                and LayoutService.NormalizePayload
                and LayoutService.NormalizePayload(rawPreset.layout, defaults)
                or nil
            if type(payload) ~= "table" then
                AppendError(result, "userPreset", presetId, "payload-invalid")
            else
                local metadata = type(rawPreset) == "table" and rawPreset.metadata or {}
                local name = type(metadata.name) == "string" and metadata.name ~= "" and metadata.name or presetId
                local record = {
                    name = ResolveUniqueName(name, usedNames, "(Preset)"),
                    payload = payload,
                    formatVersion = LAYOUT_FORMAT_VERSION,
                    createdFrom = {
                        source = "userPreset",
                        id = presetId,
                    },
                }
                local layoutId, reason = StoreMigratedLayout(layouts, record)
                if layoutId then
                    state.userPresetMap[presetId] = layoutId
                    result.migratedUserPresets = result.migratedUserPresets + 1
                else
                    AppendError(result, "userPreset", presetId, reason or "store-write-failed")
                end
            end
        end
    end

    return result
end

function LayoutMigration.MigrateAll(db)
    local result = BuildResult()
    local context = {
        result = result,
    }

    LayoutMigration.MigrateProfiles(db, context)
    LayoutMigration.MigrateUserPresets(db, context)

    if #result.errors == 0 then
        local state = LayoutMigration.GetState(db)
        if type(state) == "table" then
            state.version = ADDITIVE_MIGRATION_VERSION
            result.complete = true
        else
            AppendError(result, "state", "all", "state-unavailable")
        end
    end

    return result
end

function LayoutMigration.VerifyUserLayouts(db)
    local result = BuildVerificationResult()
    db = ResolveDB(db)

    local backupOk, backupReason = LayoutMigration.ValidateBackup(db)
    if not backupOk then
        AppendVerificationError(result, "precondition", "backup", backupReason or "invalid-backup")
        return result
    end

    local state, stateReason = PeekState(db)
    if type(state) ~= "table" then
        AppendVerificationError(result, "precondition", "state", stateReason or "invalid-state")
        return result
    end

    local defaults = FocalPoint.GetDefaultDB and FocalPoint:GetDefaultDB() or nil
    local layouts = GetReadOnlyUserLayouts(db)
    local isComplete = state.version >= ADDITIVE_MIGRATION_VERSION

    local profileNames = GetProfileNames(db)
    for _, profileName in ipairs(SortedStringKeys(state.profileMap)) do
        local mappedLayoutId = state.profileMap[profileName]
        if IsDeliberatelyDeleted(state[DELETED_PROFILE_MAP_KEY], profileName, mappedLayoutId) then
            result.profiles.total = result.profiles.total + 1
            result.profiles.valid = result.profiles.valid + 1
        else
        local profile = GetProfileByName(db, profileName)
        local legacyPayload = type(profile) == "table"
            and LayoutService.MaterializeFromLegacyProfile
            and LayoutService.MaterializeFromLegacyProfile(profile, defaults)
            or nil
        VerifyMappedPayload(
            result,
            "profiles",
            result.profiles,
            profileName,
            legacyPayload,
            layouts,
            mappedLayoutId,
            defaults
        )
        end
    end
    VerifyUnmappedSources(result, "profiles", result.profiles, profileNames, state.profileMap, isComplete)

    local rawPresets = type(db) == "table" and type(db.global) == "table" and db.global.UserPresets or nil
    for _, presetId in ipairs(SortedStringKeys(state.userPresetMap)) do
        local mappedLayoutId = state.userPresetMap[presetId]
        if IsDeliberatelyDeleted(state[DELETED_USER_PRESET_MAP_KEY], presetId, mappedLayoutId) then
            result.userPresets.total = result.userPresets.total + 1
            result.userPresets.valid = result.userPresets.valid + 1
        else
        local rawPreset = type(rawPresets) == "table" and rawPresets[presetId] or nil
        local legacyPayload = type(rawPreset) == "table"
            and type(rawPreset.layout) == "table"
            and LayoutService.NormalizePayload
            and LayoutService.NormalizePayload(rawPreset.layout, defaults)
            or nil
        VerifyMappedPayload(
            result,
            "userPresets",
            result.userPresets,
            presetId,
            legacyPayload,
            layouts,
            mappedLayoutId,
            defaults
        )
        end
    end
    VerifyUnmappedSources(
        result,
        "userPresets",
        result.userPresets,
        SortedStringKeys(rawPresets),
        state.userPresetMap,
        isComplete
    )

    VerifyOrphanCreatedFrom(result, layouts, state)

    result.complete = #result.errors == 0
    return result
end

return LayoutMigration
