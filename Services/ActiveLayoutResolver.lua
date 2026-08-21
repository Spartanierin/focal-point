local _, FocalPoint = ...

FocalPoint.ActiveLayoutResolver = FocalPoint.ActiveLayoutResolver or {}
local Resolver = FocalPoint.ActiveLayoutResolver

local DEFAULT_ACTIVE_LAYOUT_ID = "builtin:default"
local LAYOUT_FORMAT_VERSION = 1

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

local function BuildUsedLayoutNames(db)
    local used = {}
    local UserLayoutStore = FocalPoint.UserLayoutStore or {}
    local layouts = UserLayoutStore.ListRawReadOnly and UserLayoutStore.ListRawReadOnly(db) or {}
    if type(layouts) ~= "table" then
        return used
    end

    for _, record in pairs(layouts) do
        local name = type(record) == "table" and record.name or nil
        if IsNonEmptyString(name) then
            used[string.lower(name)] = true
        end
    end

    return used
end

local function ResolveUniqueCopyName(baseName, db)
    baseName = IsNonEmptyString(baseName) and baseName or "Layout"
    local used = BuildUsedLayoutNames(db)
    local candidate = baseName .. " Copy"
    if not used[string.lower(candidate)] then
        return candidate
    end

    local index = 2
    while true do
        candidate = string.format("%s Copy %d", baseName, index)
        if not used[string.lower(candidate)] then
            return candidate
        end
        index = index + 1
    end
end

local function ResolveMutableUserLayoutPayload(db, layoutId)
    local UserLayoutStore = FocalPoint.UserLayoutStore or {}
    local record = UserLayoutStore.GetMutableRaw and UserLayoutStore.GetMutableRaw(layoutId, db)
        or UserLayoutStore.GetRaw and UserLayoutStore.GetRaw(layoutId)
        or nil
    local payload = type(record) == "table" and record.payload or nil
    if type(payload) ~= "table" then
        return nil, "missing-user-layout-payload"
    end
    if type(payload.Units) ~= "table" then
        return nil, "missing-user-layout-units"
    end
    if type(payload.TextTemplates) ~= "table" then
        return nil, "missing-user-layout-text-templates"
    end

    return payload, nil, record
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

function Resolver.EnsureEditableActiveLayout(db)
    db = ResolveDB(db)
    if type(db) ~= "table" then
        return nil, nil, false, "db-unavailable"
    end

    db.char = type(db.char) == "table" and db.char or {}

    local layoutId = Resolver.GetStoredActiveLayoutId(db)
    local sourceKind = SplitActiveLayoutId(layoutId)
    if sourceKind == "layout" then
        local payload, reason = ResolveMutableUserLayoutPayload(db, layoutId)
        if type(payload) ~= "table" then
            return nil, layoutId, false, reason
        end
        return payload, layoutId, false
    end

    if sourceKind ~= "builtin" then
        return nil, layoutId, false, "unsupported-source"
    end

    local envelope, resolveReason = Resolver.ResolveLayout(db, layoutId)
    if type(envelope) ~= "table" or type(envelope.payload) ~= "table" then
        return nil, layoutId, false, resolveReason or "builtin-unresolvable"
    end

    local LayoutService = FocalPoint.LayoutService or {}
    local payload = LayoutService.NormalizePayload and LayoutService.NormalizePayload(envelope.payload, ResolveDefaults()) or nil
    if type(payload) ~= "table" or type(payload.Units) ~= "table" or type(payload.TextTemplates) ~= "table" then
        return nil, layoutId, false, "invalid-builtin-payload"
    end

    local UserLayoutStore = FocalPoint.UserLayoutStore or {}
    if not (UserLayoutStore.GenerateId and UserLayoutStore.PutRaw) then
        return nil, layoutId, false, "user-layout-store-unavailable"
    end

    local newLayoutId = UserLayoutStore.GenerateId()
    if not IsNonEmptyString(newLayoutId) then
        return nil, layoutId, false, "id-failed"
    end

    local record = {
        name = ResolveUniqueCopyName(envelope.name, db),
        payload = payload,
        formatVersion = LAYOUT_FORMAT_VERSION,
        createdFrom = {
            source = "builtin",
            id = envelope.id,
        },
    }
    local storedId = UserLayoutStore.PutRaw(newLayoutId, record)
    if storedId ~= newLayoutId then
        return nil, layoutId, false, "store-write-failed"
    end

    local mutablePayload, mutableReason = ResolveMutableUserLayoutPayload(db, newLayoutId)
    if type(mutablePayload) ~= "table" then
        return nil, layoutId, false, mutableReason or "store-verify-failed"
    end

    db.char.activeLayoutId = newLayoutId
    return mutablePayload, newLayoutId, true
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
