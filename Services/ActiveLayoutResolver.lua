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

local function IsValidLayoutPayload(payload)
    return type(payload) == "table"
        and type(payload.Units) == "table"
        and type(payload.TextTemplates) == "table"
end

local function BuildRuntimeRoot(db, layoutId)
    db = ResolveDB(db)
    local sourceKind = SplitActiveLayoutId(layoutId)
    if sourceKind == "layout" then
        local payload, reason = ResolveMutableUserLayoutPayload(db, layoutId)
        if not IsValidLayoutPayload(payload) then
            return nil, reason or "invalid-user-layout-payload"
        end
        return {
            db = db,
            layoutId = layoutId,
            source = sourceKind,
            payload = payload,
        }
    end

    if sourceKind == "builtin" then
        local envelope, reason = Resolver.ResolveLayout(db, layoutId)
        local payload = type(envelope) == "table" and envelope.payload or nil
        if not IsValidLayoutPayload(payload) then
            return nil, reason or "invalid-builtin-payload"
        end
        return {
            db = db,
            layoutId = layoutId,
            source = sourceKind,
            payload = payload,
        }
    end

    return nil, "unsupported-source"
end

local function IsRuntimeRootCurrent(root, db, layoutId)
    if type(root) ~= "table"
        or root.db ~= db
        or root.layoutId ~= layoutId
        or not IsValidLayoutPayload(root.payload)
    then
        return false
    end

    if root.source == "layout" then
        local payload = ResolveMutableUserLayoutPayload(db, layoutId)
        return payload == root.payload
    end

    return root.source == "builtin"
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

function Resolver.ResolveRuntimeRoot(db, layoutId)
    if not IsNonEmptyString(layoutId) then
        return nil, "invalid-layout"
    end
    return BuildRuntimeRoot(db, layoutId)
end

function Resolver.GetActiveRuntimeRoot()
    return Resolver._activeRuntimeRoot
end

function Resolver.SetActiveRuntimeRoot(root)
    if type(root) ~= "table" or not IsNonEmptyString(root.layoutId) or not IsValidLayoutPayload(root.payload) then
        return false
    end

    Resolver._activeRuntimeRoot = root
    return true
end

function Resolver.InvalidateActiveRuntimeRoot()
    Resolver._activeRuntimeRoot = nil
end

function Resolver.EnsureActiveRuntimeRoot(db)
    db = ResolveDB(db)
    local layoutId = Resolver.GetStoredActiveLayoutId(db)
    if not IsNonEmptyString(layoutId) then
        return nil, "not-initialized"
    end

    local root = Resolver._activeRuntimeRoot
    if IsRuntimeRootCurrent(root, db, layoutId) then
        return root
    end

    local nextRoot, reason = BuildRuntimeRoot(db, layoutId)
    if type(nextRoot) ~= "table" then
        Resolver._activeRuntimeRoot = nil
        return nil, reason
    end

    Resolver._activeRuntimeRoot = nextRoot
    return nextRoot
end

function Resolver.GetActivePayloadRoot(db)
    local root, reason = Resolver.EnsureActiveRuntimeRoot(db)
    if type(root) ~= "table" then
        return nil, reason, Resolver.GetStoredActiveLayoutId(db)
    end

    return root.payload, nil, root.layoutId
end

function Resolver.GetActiveUnits(db)
    local payload, reason = Resolver.GetActivePayloadRoot(db)
    local units = type(payload) == "table" and payload.Units or nil
    return type(units) == "table" and units or nil, reason
end

function Resolver.GetActiveTextTemplates(db)
    local payload, reason = Resolver.GetActivePayloadRoot(db)
    local templates = type(payload) == "table" and payload.TextTemplates or nil
    return type(templates) == "table" and templates or nil, reason
end

function Resolver.GetEditableActiveUnits(db)
    local payload, layoutId, created, reason = Resolver.EnsureEditableActiveLayout(db)
    local units = type(payload) == "table" and payload.Units or nil
    return type(units) == "table" and units or nil, layoutId, created, reason
end

function Resolver.GetEditableActiveTextTemplates(db)
    local payload, layoutId, created, reason = Resolver.EnsureEditableActiveLayout(db)
    local templates = type(payload) == "table" and payload.TextTemplates or nil
    return type(templates) == "table" and templates or nil, layoutId, created, reason
end

function Resolver.IsCoreCutoverEnabled()
    return true
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
    Resolver.SetActiveRuntimeRoot({
        db = db,
        layoutId = newLayoutId,
        source = "layout",
        payload = mutablePayload,
    })
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
