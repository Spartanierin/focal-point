local _, FocalPoint = ...

FocalPoint.LayoutAssignmentService = FocalPoint.LayoutAssignmentService or {}
local Service = FocalPoint.LayoutAssignmentService

local eventFrame = nil

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
