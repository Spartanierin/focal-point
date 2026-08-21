local _, FocalPoint = ...

FocalPoint.LayoutMigration = FocalPoint.LayoutMigration or {}
local LayoutMigration = FocalPoint.LayoutMigration

local LayoutService = FocalPoint.LayoutService or {}

local BACKUP_VERSION = 1
local MIGRATION_VERSION = 0
local BACKUP_KEY = "LayoutMigrationBackup"
local STATE_KEY = "LayoutMigration"

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

    return state
end

return LayoutMigration
