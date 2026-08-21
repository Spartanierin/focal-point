local _, FocalPoint = ...

FocalPoint.ActiveLayoutResolver = FocalPoint.ActiveLayoutResolver or {}
local Resolver = FocalPoint.ActiveLayoutResolver

local DEFAULT_ACTIVE_LAYOUT_ID = "builtin:default"

local function IsNonEmptyString(value)
    return type(value) == "string" and value ~= ""
end

local function ResolveDB(db)
    return type(db) == "table" and db or FocalPoint.db
end

local function ResolveDefaults()
    return FocalPoint.GetDefaultDB and FocalPoint:GetDefaultDB() or nil
end

local function SplitActiveLayoutId(layoutId)
    if not IsNonEmptyString(layoutId) then
        return nil, nil
    end

    local prefix = layoutId:match("^([^:]+):")
    if prefix == "builtin" then
        return prefix, layoutId:sub(9)
    end
    if prefix == "layout" then
        return prefix, layoutId
    end

    return nil, nil
end

local function GetCurrentProfileName(db)
    if type(db) ~= "table" or type(db.GetCurrentProfile) ~= "function" then
        return nil
    end

    local ok, profileName = pcall(db.GetCurrentProfile, db)
    if ok and IsNonEmptyString(profileName) then
        return profileName
    end

    return nil
end

local function GetMigrationProfileMap(db)
    local global = type(db) == "table" and rawget(db, "global") or nil
    local state = type(global) == "table" and rawget(global, "LayoutMigration") or nil
    local profileMap = type(state) == "table" and rawget(state, "profileMap") or nil
    return type(profileMap) == "table" and profileMap or nil
end

function Resolver.GetStoredActiveLayoutId(db)
    db = ResolveDB(db)
    local char = type(db) == "table" and rawget(db, "char") or nil
    return type(char) == "table" and rawget(char, "activeLayoutId") or nil
end

function Resolver.ResolveLayout(db, layoutId)
    db = ResolveDB(db)
    local sourceKind, sourceId = SplitActiveLayoutId(layoutId)
    if not sourceKind then
        return nil, "unsupported-source"
    end

    local LayoutService = FocalPoint.LayoutService or {}
    local defaults = ResolveDefaults()

    if sourceKind == "builtin" then
        local PresetService = FocalPoint.PresetService or {}
        local builtIns = PresetService.GetBuiltInPresets and PresetService.GetBuiltInPresets() or nil
        local preset = type(builtIns) == "table" and builtIns[sourceId] or nil
        if type(preset) ~= "table" or type(preset.metadata) ~= "table" or preset.metadata.source ~= "builtin" then
            return nil, "missing-builtin"
        end

        local envelope = LayoutService.ProjectPreset and LayoutService.ProjectPreset(preset, defaults) or nil
        return type(envelope) == "table" and envelope or nil, envelope and nil or "invalid-builtin-payload"
    end

    if sourceKind == "layout" then
        local UserLayoutStore = FocalPoint.UserLayoutStore or {}
        local record = UserLayoutStore.GetRawReadOnly and UserLayoutStore.GetRawReadOnly(sourceId, db) or nil
        if type(record) ~= "table" then
            return nil, "missing-user-layout"
        end

        local envelope = LayoutService.ProjectUserLayout and LayoutService.ProjectUserLayout(sourceId, record, defaults) or nil
        return type(envelope) == "table" and envelope or nil, envelope and nil or "invalid-user-layout-payload"
    end

    return nil, "unsupported-source"
end

function Resolver.IsResolvableLayoutId(db, layoutId)
    return Resolver.ResolveLayout(db, layoutId) ~= nil
end

function Resolver.GetActiveLayout(db)
    db = ResolveDB(db)
    local layoutId = Resolver.GetStoredActiveLayoutId(db)
    if not IsNonEmptyString(layoutId) then
        return nil, "not-initialized"
    end

    return Resolver.ResolveLayout(db, layoutId)
end

function Resolver.GetActivePayload(db)
    local envelope, reason = Resolver.GetActiveLayout(db)
    if type(envelope) ~= "table" or type(envelope.payload) ~= "table" then
        return nil, reason or "missing-payload"
    end

    local LayoutService = FocalPoint.LayoutService or {}
    return LayoutService.Clone and LayoutService.Clone(envelope.payload) or nil
end

function Resolver.InitializeActiveLayoutId(db)
    db = ResolveDB(db)
    if type(db) ~= "table" then
        return nil, "db-unavailable"
    end

    db.char = type(db.char) == "table" and db.char or {}

    local current = rawget(db.char, "activeLayoutId")
    if IsNonEmptyString(current) then
        if Resolver.IsResolvableLayoutId(db, current) then
            return current, "existing"
        end
        return current, "invalid-existing"
    end

    local profileName = GetCurrentProfileName(db)
    local profileMap = GetMigrationProfileMap(db)
    local mappedLayoutId = profileMap and profileMap[profileName] or nil
    if IsNonEmptyString(mappedLayoutId) and Resolver.IsResolvableLayoutId(db, mappedLayoutId) then
        db.char.activeLayoutId = mappedLayoutId
        return mappedLayoutId, "mapped-profile"
    end

    if Resolver.IsResolvableLayoutId(db, DEFAULT_ACTIVE_LAYOUT_ID) then
        db.char.activeLayoutId = DEFAULT_ACTIVE_LAYOUT_ID
        return DEFAULT_ACTIVE_LAYOUT_ID, "default-builtin"
    end

    return nil, "default-unavailable"
end

return Resolver
