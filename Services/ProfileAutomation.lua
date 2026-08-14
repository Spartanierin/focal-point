local _, FocalPoint = ...

local ProfileAutomation = {}
FocalPoint.ProfileAutomation = ProfileAutomation

local pendingProfileName = nil
local eventFrame = nil

local function GetAutomationConfig()
    local db = FocalPoint.db
    if type(db) ~= "table" then
        return nil
    end

    db.global = type(db.global) == "table" and db.global or {}
    db.global.ProfileAutomation = type(db.global.ProfileAutomation) == "table" and db.global.ProfileAutomation or {}
    db.global.ProfileAutomation.specProfiles = type(db.global.ProfileAutomation.specProfiles) == "table"
        and db.global.ProfileAutomation.specProfiles
        or {}
    if db.global.ProfileAutomation.enabled == nil then
        db.global.ProfileAutomation.enabled = false
    end

    return db.global.ProfileAutomation
end

local function GetProfileList()
    local db = FocalPoint.db
    if not db or type(db.GetProfiles) ~= "function" then
        return {}
    end

    local ok, profiles = pcall(db.GetProfiles, db, {})
    if not ok or type(profiles) ~= "table" then
        return {}
    end

    return profiles
end

local function ProfileExists(profileName)
    if type(profileName) ~= "string" or profileName == "" then
        return false
    end

    for _, name in ipairs(GetProfileList()) do
        if name == profileName then
            return true
        end
    end

    return false
end

local function GetCurrentProfileName()
    local db = FocalPoint.db
    if not db or type(db.GetCurrentProfile) ~= "function" then
        return nil
    end

    local ok, profileName = pcall(db.GetCurrentProfile, db)
    if ok and type(profileName) == "string" and profileName ~= "" then
        return profileName
    end

    return nil
end

local function GetSpecializationIndex()
    if C_SpecializationInfo and type(C_SpecializationInfo.GetSpecialization) == "function" then
        local ok, specIndex = pcall(C_SpecializationInfo.GetSpecialization)
        if ok and type(specIndex) == "number" and specIndex > 0 then
            return specIndex
        end
    end

    if type(GetSpecialization) == "function" then
        local ok, specIndex = pcall(GetSpecialization)
        if ok and type(specIndex) == "number" and specIndex > 0 then
            return specIndex
        end
    end

    return nil
end

local function ResolveSpecializationInfo(specIndex)
    if type(specIndex) ~= "number" or specIndex <= 0 then
        return nil
    end

    if C_SpecializationInfo and type(C_SpecializationInfo.GetSpecializationInfo) == "function" then
        local ok, specID, name = pcall(C_SpecializationInfo.GetSpecializationInfo, specIndex)
        if ok and type(specID) == "number" then
            return specID, name
        end
    end

    if type(_G.GetSpecializationInfo) == "function" then
        local ok, specID, name = pcall(_G.GetSpecializationInfo, specIndex)
        if ok and type(specID) == "number" then
            return specID, name
        end
    end

    return nil
end

function ProfileAutomation.GetCurrentSpec()
    local specIndex = GetSpecializationIndex()
    local specID, specName = ResolveSpecializationInfo(specIndex)
    if type(specID) ~= "number" or specID <= 0 then
        return nil
    end

    return specID, specName, specIndex
end

function ProfileAutomation.GetAvailableSpecs()
    local specs = {}
    local maxSpecs = 4

    for specIndex = 1, maxSpecs do
        local specID, specName = ResolveSpecializationInfo(specIndex)
        if type(specID) == "number" and specID > 0 then
            specs[#specs + 1] = {
                id = specID,
                name = type(specName) == "string" and specName ~= "" and specName or tostring(specID),
                index = specIndex,
            }
        end
    end

    return specs
end

function ProfileAutomation.GetConfig()
    return GetAutomationConfig()
end

function ProfileAutomation.IsEnabled()
    local config = GetAutomationConfig()
    return config and config.enabled == true
end

function ProfileAutomation.SetEnabled(enabled)
    local config = GetAutomationConfig()
    if not config then
        return false
    end

    config.enabled = enabled == true
    return true
end

function ProfileAutomation.GetAssignedProfile(specID)
    local config = GetAutomationConfig()
    if not config or type(specID) ~= "number" then
        return nil
    end

    local profileName = config.specProfiles[specID] or config.specProfiles[tostring(specID)]
    if type(profileName) == "string" and profileName ~= "" then
        return profileName
    end

    return nil
end

function ProfileAutomation.SetAssignedProfile(specID, profileName)
    local config = GetAutomationConfig()
    if not config or type(specID) ~= "number" then
        return false
    end

    if type(profileName) == "string" and profileName ~= "" and ProfileExists(profileName) then
        config.specProfiles[specID] = profileName
    else
        config.specProfiles[specID] = nil
        config.specProfiles[tostring(specID)] = nil
    end

    return true
end

function ProfileAutomation.GetProfileOptions(includeUnassigned)
    local options = {}
    if includeUnassigned then
        options[""] = FocalPoint.L and FocalPoint.L["INFO_PROFILE_AUTOMATION_UNASSIGNED"] or "Unassigned"
    end

    for _, profileName in ipairs(GetProfileList()) do
        options[profileName] = profileName
    end

    return options
end

function ProfileAutomation.ReconcileProfileRenamed(oldName, newName)
    if type(oldName) ~= "string" or oldName == "" or type(newName) ~= "string" or newName == "" then
        return
    end

    local config = GetAutomationConfig()
    if not config then
        return
    end

    for specID, profileName in pairs(config.specProfiles) do
        if profileName == oldName then
            config.specProfiles[specID] = newName
        end
    end
end

function ProfileAutomation.ReconcileProfileDeleted(profileName)
    if type(profileName) ~= "string" or profileName == "" then
        return
    end

    local config = GetAutomationConfig()
    if not config then
        return
    end

    for specID, assignedProfileName in pairs(config.specProfiles) do
        if assignedProfileName == profileName then
            config.specProfiles[specID] = nil
        end
    end
end

function FocalPoint:ActivateProfile(profileName, reason, options)
    local db = self.db
    options = type(options) == "table" and options or {}
    local profileExists = ProfileExists(profileName)
    if not db or type(db.SetProfile) ~= "function" or (not profileExists and options.allowCreate ~= true) then
        return false
    end

    local currentProfileName = GetCurrentProfileName()
    if currentProfileName == profileName then
        if self.HandleActiveProfileChanged then
            self:HandleActiveProfileChanged(reason or "profile-activate-current", options)
        end
        return true
    end

    self._pendingProfileActivationReason = reason
    self._pendingProfileActivationOptions = options
    db:SetProfile(profileName)
    return true
end

local function ApplyMappedProfile(reason)
    if not ProfileAutomation.IsEnabled() then
        pendingProfileName = nil
        return false
    end

    local specID = ProfileAutomation.GetCurrentSpec()
    local profileName = ProfileAutomation.GetAssignedProfile(specID)
    if type(profileName) ~= "string" or profileName == "" or not ProfileExists(profileName) then
        pendingProfileName = nil
        return false
    end

    if profileName == GetCurrentProfileName() then
        pendingProfileName = nil
        return true
    end

    if InCombatLockdown and InCombatLockdown() then
        pendingProfileName = profileName
        return false
    end

    pendingProfileName = nil
    return FocalPoint.ActivateProfile and FocalPoint:ActivateProfile(profileName, reason or "profile-automation", { silent = true })
end

function ProfileAutomation.Apply(reason)
    return ApplyMappedProfile(reason)
end

function ProfileAutomation.Initialize()
    if eventFrame then
        return
    end

    eventFrame = CreateFrame("Frame")
    eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    eventFrame:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
    eventFrame:RegisterEvent("ACTIVE_TALENT_GROUP_CHANGED")
    eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
    eventFrame:SetScript("OnEvent", function(_, event, unit)
        if event == "PLAYER_SPECIALIZATION_CHANGED" and unit ~= nil and unit ~= "player" then
            return
        end

        if event == "PLAYER_REGEN_ENABLED" and not pendingProfileName then
            return
        end

        ApplyMappedProfile("profile-automation-" .. string.lower(event))
    end)
end

return ProfileAutomation
