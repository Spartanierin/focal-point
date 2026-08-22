local _, FocalPoint = ...

FocalPoint.LayoutAssignmentService = FocalPoint.LayoutAssignmentService or {}
local Service = FocalPoint.LayoutAssignmentService

local eventFrame = nil
local MIGRATION_KEY = "LayoutAssignmentMigration"

local function ResolveDB(db)
    return type(db) == "table" and db or FocalPoint.db
end

local function IsValidSpecID(specID)
    return type(specID) == "number" and specID > 0
end

local function NormalizeStoredSpecID(specID)
    if IsValidSpecID(specID) then
        return specID
    end
    if type(specID) == "string" and specID ~= "" then
        local numeric = tonumber(specID)
        if IsValidSpecID(numeric) then
            return numeric
        end
    end
    return nil
end

local function IsAllowedLayoutId(layoutId)
    return type(layoutId) == "string"
        and layoutId ~= ""
        and (layoutId:match("^builtin:") ~= nil or layoutId:match("^layout:") ~= nil)
end

local function IsResolvableLayoutId(db, layoutId)
    if not IsAllowedLayoutId(layoutId) then
        return false, "unsupported-layout-source"
    end

    local resolver = FocalPoint.ActiveLayoutResolver or {}
    if not resolver.IsResolvableLayoutId then
        return false, "layout-resolver-unavailable"
    end

    if resolver.IsResolvableLayoutId(db, layoutId) then
        return true
    end
    return false, "layout-unresolvable"
end

local function PeekSpecializationAssignments(db)
    db = ResolveDB(db)
    local char = type(db) == "table" and rawget(db, "char") or nil
    local root = type(char) == "table" and rawget(char, "LayoutAssignments") or nil
    local specialization = type(root) == "table" and rawget(root, "specialization") or nil
    return type(specialization) == "table" and specialization or nil
end

local function EnsureSpecializationAssignments(db)
    db = ResolveDB(db)
    if type(db) ~= "table" then
        return nil, "db-unavailable"
    end

    db.char = type(db.char) == "table" and db.char or {}
    db.char.LayoutAssignments = type(db.char.LayoutAssignments) == "table" and db.char.LayoutAssignments or {}
    db.char.LayoutAssignments.specialization = type(db.char.LayoutAssignments.specialization) == "table"
        and db.char.LayoutAssignments.specialization
        or {}

    return db.char.LayoutAssignments.specialization
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
        if ok and IsValidSpecID(specID) then
            return specID, name
        end
    end

    if type(_G.GetSpecializationInfo) == "function" then
        local ok, specID, name = pcall(_G.GetSpecializationInfo, specIndex)
        if ok and IsValidSpecID(specID) then
            return specID, name
        end
    end

    return nil
end

local function BuildAvailableSpecializationSet()
    local specs = {}
    local count = 0
    if type(GetNumSpecializations) == "function" then
        local ok, value = pcall(GetNumSpecializations)
        if ok and type(value) == "number" and value > 0 then
            count = value
        end
    end
    if count == 0 then
        count = 4
    end

    for specIndex = 1, count do
        local specID = ResolveSpecializationInfo(specIndex)
        if IsValidSpecID(specID) then
            specs[specID] = true
        end
    end
    return specs
end

local function GetLegacyProfileAutomationConfig(db)
    db = ResolveDB(db)
    local global = type(db) == "table" and rawget(db, "global") or nil
    local config = type(global) == "table" and rawget(global, "ProfileAutomation") or nil
    if type(config) ~= "table" then
        return nil
    end
    return config
end

local function GetMigrationProfileMap(db)
    db = ResolveDB(db)
    local global = type(db) == "table" and rawget(db, "global") or nil
    local state = type(global) == "table" and rawget(global, "LayoutMigration") or nil
    local profileMap = type(state) == "table" and rawget(state, "profileMap") or nil
    return type(profileMap) == "table" and profileMap or nil
end

local function EnsureAssignmentMigrationState(db)
    db = ResolveDB(db)
    if type(db) ~= "table" then
        return nil, "db-unavailable"
    end

    db.char = type(db.char) == "table" and db.char or {}
    db.char[MIGRATION_KEY] = type(db.char[MIGRATION_KEY]) == "table" and db.char[MIGRATION_KEY] or {}
    db.char[MIGRATION_KEY].legacyProfileAutomation = type(db.char[MIGRATION_KEY].legacyProfileAutomation) == "table"
        and db.char[MIGRATION_KEY].legacyProfileAutomation
        or {}
    return db.char[MIGRATION_KEY].legacyProfileAutomation
end

local function MarkLegacyAssignmentHandled(db, specID, profileName)
    if not (IsValidSpecID(specID) and type(profileName) == "string" and profileName ~= "") then
        return
    end
    local state = EnsureAssignmentMigrationState(db)
    if type(state) == "table" then
        state[specID] = profileName
        state[tostring(specID)] = nil
    end
end

local function IsLegacyAssignmentHandled(db, specID, profileName)
    db = ResolveDB(db)
    local char = type(db) == "table" and rawget(db, "char") or nil
    local root = type(char) == "table" and rawget(char, MIGRATION_KEY) or nil
    local state = type(root) == "table" and rawget(root, "legacyProfileAutomation") or nil
    if type(state) ~= "table" then
        return false
    end
    local handledProfileName = state[specID] or state[tostring(specID)]
    return handledProfileName == profileName
end

local function HasDirtyTextBuilderDraft()
    local textBuilder = FocalPoint.GUI and FocalPoint.GUI.Pages and FocalPoint.GUI.Pages.TextBuilder or nil
    return textBuilder and textBuilder.HasUnsavedChanges and textBuilder.HasUnsavedChanges() == true
end

function Service.GetCurrentSpecialization()
    local specIndex = GetSpecializationIndex()
    local specID, specName = ResolveSpecializationInfo(specIndex)
    if not IsValidSpecID(specID) then
        return nil, "spec-unavailable"
    end
    return specID, specName, specIndex
end

function Service.GetSpecializationAssignment(specID, db)
    if not IsValidSpecID(specID) then
        return nil, "invalid-spec"
    end

    local assignments = PeekSpecializationAssignments(db)
    if type(assignments) ~= "table" then
        return nil, "missing"
    end

    local layoutId = assignments[specID] or assignments[tostring(specID)]
    if type(layoutId) ~= "string" or layoutId == "" then
        return nil, "missing"
    end

    local ok, reason = IsResolvableLayoutId(ResolveDB(db), layoutId)
    if not ok then
        return nil, "stale", layoutId, reason
    end

    return layoutId, "ok"
end

function Service.GetAssignmentForCurrentSpecialization(db)
    local specID, specName, specIndexOrReason = Service.GetCurrentSpecialization()
    if not specID then
        return nil, specName or specIndexOrReason or "spec-unavailable"
    end

    local layoutId, status, staleLayoutId, staleReason = Service.GetSpecializationAssignment(specID, db)
    return layoutId, status, specID, specName, specIndexOrReason, staleLayoutId, staleReason
end

function Service.GetAllSpecializationAssignments(db)
    local assignments = PeekSpecializationAssignments(db)
    local result = {}
    if type(assignments) ~= "table" then
        return result
    end

    for specID, layoutId in pairs(assignments) do
        local normalizedSpecID = NormalizeStoredSpecID(specID)
        if normalizedSpecID and type(layoutId) == "string" and layoutId ~= "" then
            result[normalizedSpecID] = layoutId
        end
    end
    return result
end

function Service.SetSpecializationAssignment(specID, layoutId, db)
    if not IsValidSpecID(specID) then
        return false, "invalid-spec"
    end

    local assignments, storeReason = EnsureSpecializationAssignments(db)
    if type(assignments) ~= "table" then
        return false, storeReason or "assignment-store-unavailable"
    end

    if layoutId == nil then
        assignments[specID] = nil
        assignments[tostring(specID)] = nil
        return true
    end

    local ok, reason = IsResolvableLayoutId(ResolveDB(db), layoutId)
    if not ok then
        return false, reason
    end

    assignments[specID] = layoutId
    assignments[tostring(specID)] = nil
    return true
end

function Service.ClearAssignmentsForLayout(layoutId, db)
    if type(layoutId) ~= "string" or layoutId == "" or layoutId:match("^layout:") == nil then
        return false, "invalid-layout", 0
    end

    local cleared = 0
    local assignments = Service.GetAllSpecializationAssignments(db)
    for specID, assignedLayoutId in pairs(assignments) do
        if assignedLayoutId == layoutId then
            local ok = Service.SetSpecializationAssignment(specID, nil, db)
            if ok then
                cleared = cleared + 1
            else
                return false, "clear-failed", cleared
            end
        end
    end

    return true, cleared
end

function Service.MigrateLegacyProfileAutomationAssignments(db)
    db = ResolveDB(db)
    local result = {
        migrated = 0,
        skippedExisting = 0,
        skippedHandled = 0,
        skippedNoLegacy = 0,
        skippedNoProfileMap = 0,
        skippedUnresolvable = 0,
        skippedDisabled = 0,
        errors = 0,
    }

    local config = GetLegacyProfileAutomationConfig(db)
    local legacyAssignments = type(config) == "table" and config.specProfiles or nil
    if type(config) ~= "table" or type(legacyAssignments) ~= "table" then
        return result, "missing-legacy"
    end
    if config.enabled ~= true then
        result.skippedDisabled = result.skippedDisabled + 1
        return result, "legacy-disabled"
    end

    local profileMap = GetMigrationProfileMap(db)
    if type(profileMap) ~= "table" then
        return result, "missing-profile-map"
    end

    local classSpecs = BuildAvailableSpecializationSet()
    for specID in pairs(classSpecs) do
        local profileName = legacyAssignments[specID] or legacyAssignments[tostring(specID)]
        if type(profileName) ~= "string" or profileName == "" then
            result.skippedNoLegacy = result.skippedNoLegacy + 1
        else
            local currentLayoutId, status = Service.GetSpecializationAssignment(specID, db)
            if status == "ok" and type(currentLayoutId) == "string" and currentLayoutId ~= "" then
                result.skippedExisting = result.skippedExisting + 1
                MarkLegacyAssignmentHandled(db, specID, profileName)
            else
                if status == "stale" then
                    Service.SetSpecializationAssignment(specID, nil, db)
                elseif status ~= "missing" and status ~= "invalid-spec" then
                    result.errors = result.errors + 1
                end

                if IsLegacyAssignmentHandled(db, specID, profileName) then
                    result.skippedHandled = result.skippedHandled + 1
                else
                    local layoutId = profileMap[profileName]
                    if type(layoutId) ~= "string" or layoutId == "" then
                        result.skippedNoProfileMap = result.skippedNoProfileMap + 1
                    else
                        local ok, reason = Service.SetSpecializationAssignment(specID, layoutId, db)
                        if ok then
                            result.migrated = result.migrated + 1
                            MarkLegacyAssignmentHandled(db, specID, profileName)
                        else
                            result.skippedUnresolvable = result.skippedUnresolvable + 1
                            if reason == "invalid-spec" or reason == "assignment-store-unavailable" then
                                result.errors = result.errors + 1
                            end
                        end
                    end
                end
            end
        end
    end

    return result, "ok"
end

function Service.EvaluateCurrentSpecializationAssignment(reason)
    local layoutId, status, specID, _, _, staleLayoutId = Service.GetAssignmentForCurrentSpecialization()
    if status == "missing" or status == "spec-unavailable" or status == "invalid-spec" then
        return false, status or "missing"
    end

    if status == "stale" then
        if type(specID) == "number" then
            Service.SetSpecializationAssignment(specID, nil)
        end
        return false, "stale", staleLayoutId
    end

    if type(layoutId) ~= "string" or layoutId == "" then
        return false, status or "missing"
    end

    if HasDirtyTextBuilderDraft() then
        return false, "dirty-text-builder"
    end

    if not FocalPoint.ActivateLayout then
        return false, "activate-layout-unavailable"
    end

    return FocalPoint:ActivateLayout(layoutId, reason or "assignment:spec")
end

function Service.InitializeRuntime()
    if eventFrame then
        return
    end

    eventFrame = CreateFrame("Frame")
    eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    eventFrame:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
    eventFrame:SetScript("OnEvent", function(_, event, unit)
        if event == "PLAYER_SPECIALIZATION_CHANGED" and unit ~= nil and unit ~= "player" then
            return
        end

        local reason = event == "PLAYER_ENTERING_WORLD" and "assignment:login" or "assignment:spec-change"
        Service.EvaluateCurrentSpecializationAssignment(reason)
    end)
end

return Service
