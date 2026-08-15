local _, FocalPoint = ...

FocalPoint.ProfileLayoutService = FocalPoint.ProfileLayoutService or {}
local ProfileLayoutService = FocalPoint.ProfileLayoutService

local LayoutService = FocalPoint.LayoutService or {}
local PresetService = FocalPoint.PresetService or {}

local MAX_PROFILE_NAME_LENGTH = 64

local function Clone(value)
    return LayoutService.Clone and LayoutService.Clone(value) or value
end

local function Trim(value)
    if type(value) ~= "string" then
        return ""
    end
    return (value:gsub("^%s+", ""):gsub("%s+$", ""))
end

local function GetTextLength(value)
    if strlenutf8 then
        local ok, length = pcall(strlenutf8, value)
        if ok and type(length) == "number" then
            return length
        end
    end
    return #value
end

local function IsValidLayout(layout)
    return type(layout) == "table"
        and type(layout.Units) == "table"
        and type(layout.TextTemplates) == "table"
end

local function GetProfilesTable(db)
    if type(db) ~= "table" then
        return nil
    end

    if type(db.profiles) == "table" then
        return db.profiles
    end

    if type(db.sv) == "table" then
        db.sv.profiles = type(db.sv.profiles) == "table" and db.sv.profiles or {}
        db.profiles = db.sv.profiles
        return db.profiles
    end

    return nil
end

local function GetProfileList(db)
    local profiles = {}
    if db and db.GetProfiles then
        local ok, result = pcall(db.GetProfiles, db, {})
        if ok and type(result) == "table" then
            for _, profileName in ipairs(result) do
                profiles[profileName] = true
            end
        end
    end
    return profiles
end

local function BuildProfileFromLayout(layout)
    local defaults = FocalPoint.GetDefaultDB and FocalPoint:GetDefaultDB() or nil
    local defaultProfile = defaults and defaults.profile or nil
    local profile = Clone(defaultProfile) or {}

    profile.Units = Clone(layout.Units) or {}
    profile.TextTemplates = Clone(layout.TextTemplates) or {}

    return profile
end

function ProfileLayoutService.ValidateProfileName(profileName)
    local normalizedName = Trim(profileName)
    if normalizedName == "" or GetTextLength(normalizedName) > MAX_PROFILE_NAME_LENGTH then
        return false, "invalid-profile-name"
    end

    local db = FocalPoint.db
    local profiles = GetProfileList(db)
    if profiles[normalizedName] then
        return false, "profile-exists"
    end

    return true, normalizedName
end

function ProfileLayoutService.CreateProfileFromLayout(layout, profileName, options)
    options = type(options) == "table" and options or {}

    if not IsValidLayout(layout) then
        return false, "layout-invalid"
    end

    local db = FocalPoint.db
    if type(db) ~= "table" or type(db.SetProfile) ~= "function" then
        return false, "profile-db-unavailable"
    end

    if InCombatLockdown and InCombatLockdown() then
        return false, "combat-blocked"
    end

    local isValidProfileName, normalizedNameOrError = ProfileLayoutService.ValidateProfileName(profileName)
    if not isValidProfileName then
        return false, normalizedNameOrError
    end

    local profiles = GetProfilesTable(db)
    if type(profiles) ~= "table" then
        return false, "profile-db-unavailable"
    end

    local previousProfileName = db.GetCurrentProfile and db:GetCurrentProfile() or nil
    local profileNameToCreate = normalizedNameOrError
    local profileWasCreated = false

    profiles[profileNameToCreate] = BuildProfileFromLayout(layout)
    profileWasCreated = true

    local ok, result = pcall(function()
        if FocalPoint.ActivateProfile then
            return FocalPoint:ActivateProfile(profileNameToCreate, options.reason or "profile-create-from-preset")
        end

        db:SetProfile(profileNameToCreate)
        return true
    end)

    if not ok or result ~= true then
        if profileWasCreated and profiles[profileNameToCreate] ~= nil then
            profiles[profileNameToCreate] = nil
        end

        if previousProfileName
            and previousProfileName ~= profileNameToCreate
            and db.GetCurrentProfile
            and db:GetCurrentProfile() == profileNameToCreate
        then
            pcall(db.SetProfile, db, previousProfileName)
        end

        return false, "create-failed"
    end

    return true, profileNameToCreate
end

function ProfileLayoutService.CreateProfileFromPreset(presetId, profileName, options)
    local preset = PresetService.GetPreset and PresetService.GetPreset(presetId) or nil
    if type(preset) ~= "table" then
        return false, "preset-not-found"
    end

    return ProfileLayoutService.CreateProfileFromLayout(preset.layout, profileName, options)
end

return ProfileLayoutService
