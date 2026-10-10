local _, FocalPoint = ...

FocalPoint.LayoutMutations = FocalPoint.LayoutMutations or {}
local Mutations = FocalPoint.LayoutMutations

local MAX_NAME_LENGTH = 64
local LAYOUT_FORMAT_VERSION = 2

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

local function NormalizeComparableName(value)
    local trimmed = Trim(value)
    if trimmed == "" then
        return ""
    end
    return string.lower(trimmed)
end

local function ResolveLayoutSummaryName(summary)
    local layoutService = FocalPoint.LayoutService or {}
    if layoutService.GetDisplayName then
        return layoutService.GetDisplayName(summary)
    end
    return type(summary) == "table" and (summary.name or summary.id) or ""
end

local function IsProductLayoutSource(source)
    return source == "userLayout" or source == "builtin"
end

local function IsCopyableLayoutId(layoutId)
    return type(layoutId) == "string"
        and (layoutId:match("^layout:") ~= nil or layoutId:match("^builtin:") ~= nil)
end

local function ResolveCreatedFromSource(source)
    if source == "userLayout" then
        return "layout"
    end
    if source == "builtin" then
        return "builtin"
    end
    return nil
end

local function IsValidLayoutPayload(payload)
    return type(payload) == "table"
        and type(payload.Units) == "table"
        and payload.TextTemplates == nil
end

local function ShortenForSuffix(baseName, suffix)
    baseName = Trim(baseName)
    if baseName == "" then
        baseName = "Layout"
    end

    local maxBaseLength = math.max(1, MAX_NAME_LENGTH - GetTextLength(suffix))
    while GetTextLength(baseName) > maxBaseLength do
        baseName = baseName:sub(1, -2)
        baseName = Trim(baseName)
        if baseName == "" then
            return "Layout"
        end
    end
    return baseName
end

local function BuildCopyNameCandidate(baseName, index)
    local suffix = index and index > 1 and (" Copy " .. tostring(index)) or " Copy"
    return ShortenForSuffix(baseName, suffix) .. suffix
end

local function IsLayoutNameCollision(normalizedName, options)
    local layoutService = FocalPoint.LayoutService or {}
    local summaries = layoutService.ListLayoutSummaries and layoutService.ListLayoutSummaries({ db = FocalPoint.db }) or {}
    local candidate = NormalizeComparableName(normalizedName)
    local excludeLayoutId = type(options) == "table" and options.excludeLayoutId or nil

    for _, summary in ipairs(summaries) do
        if type(summary) == "table" and IsProductLayoutSource(summary.source) and summary.id ~= excludeLayoutId then
            local name = ResolveLayoutSummaryName(summary)
            if NormalizeComparableName(name) == candidate then
                return true
            end
        end
    end
    return false
end

function Mutations.ValidateLayoutName(name, options)
    options = type(options) == "table" and options or {}
    local normalizedName = Trim(name)
    if normalizedName == "" then
        return false, "name-required"
    end
    if GetTextLength(normalizedName) > MAX_NAME_LENGTH then
        return false, "name-too-long"
    end
    if IsLayoutNameCollision(normalizedName, options) then
        return false, "duplicate-name"
    end
    return true, normalizedName
end

function Mutations.SuggestLayoutCopyName(baseName)
    local index = 1
    while index < 1000 do
        local candidate = BuildCopyNameCandidate(baseName, index)
        local validName = Mutations.ValidateLayoutName(candidate)
        if validName then
            return candidate
        end
        index = index + 1
    end
    return BuildCopyNameCandidate("Layout", 1)
end

function Mutations.CreateUserLayoutFromSource(layoutId, newName, options)
    if not IsCopyableLayoutId(layoutId) then return false, "unsupported-source" end
    options = type(options) == "table" and options or {}
    if InCombatLockdown and InCombatLockdown() then return false, "combat-blocked" end

    local Resolver = FocalPoint.ActiveLayoutResolver or {}
    local envelope, resolveReason = Resolver.ResolveLayout and Resolver.ResolveLayout(FocalPoint.db, layoutId) or nil
    if type(envelope) ~= "table" then return false, resolveReason or "layout-not-found" end
    if envelope.source ~= "userLayout" and envelope.source ~= "builtin" then return false, "unsupported-source" end

    local displayName = ResolveLayoutSummaryName(envelope)
    local requestedName = type(newName) == "string" and newName or Mutations.SuggestLayoutCopyName(displayName)
    local validName, normalizedNameOrReason = Mutations.ValidateLayoutName(requestedName)
    if not validName then return false, normalizedNameOrReason end

    local LayoutService = FocalPoint.LayoutService or {}
    local payload = LayoutService.CopyPayload and LayoutService.CopyPayload(envelope.payload) or nil
    if not IsValidLayoutPayload(payload) then return false, "payload-invalid" end
    local UserLayoutStore = FocalPoint.UserLayoutStore or {}
    if not (UserLayoutStore.GenerateId and UserLayoutStore.PutRaw and UserLayoutStore.RemoveRaw) then return false, "user-layout-store-unavailable" end
    local newLayoutId = UserLayoutStore.GenerateId()
    if type(newLayoutId) ~= "string" or newLayoutId == "" then return false, "id-failed" end
    local record = { name = normalizedNameOrReason, payload = payload, formatVersion = LAYOUT_FORMAT_VERSION, createdFrom = { source = ResolveCreatedFromSource(envelope.source), id = envelope.id } }
    if UserLayoutStore.PutRaw(newLayoutId, record) ~= newLayoutId then return false, "store-write-failed" end
    if options.activate == true then
        local activated, reason = FocalPoint.ActivateLayout and FocalPoint:ActivateLayout(newLayoutId, options.reason or "create-layout-from-source") or false, "activation-unavailable"
        if not activated then UserLayoutStore.RemoveRaw(newLayoutId, FocalPoint.db); return false, reason or "activation-failed" end
    end
    return true, newLayoutId, normalizedNameOrReason
end
function Mutations.CopyLayout(layoutId, newName, options)
    options = type(options) == "table" and options or {}
    return Mutations.CreateUserLayoutFromSource(layoutId, newName, { activate = options.activate == true, reason = options.reason or "copy-layout" })
end
function Mutations.DeleteUserLayout(layoutId)
    if type(layoutId) ~= "string" or layoutId == "" or not layoutId:match("^layout:") then
        return false, "invalid-layout"
    end

    local Resolver = FocalPoint.ActiveLayoutResolver or {}
    local activeLayoutId = Resolver.GetStoredActiveLayoutId and Resolver.GetStoredActiveLayoutId(FocalPoint.db) or nil
    if activeLayoutId == layoutId then
        return false, "active-layout"
    end

    local UserLayoutStore = FocalPoint.UserLayoutStore or {}
    local existing = UserLayoutStore.GetRawReadOnly and UserLayoutStore.GetRawReadOnly(layoutId, FocalPoint.db) or nil
    if type(existing) ~= "table" then
        return false, "layout-not-found"
    end
    if not UserLayoutStore.RemoveRaw then
        return false, "user-layout-store-unavailable"
    end

    if not UserLayoutStore.RemoveRaw(layoutId) then
        return false, "store-delete-failed"
    end
    local afterDelete = UserLayoutStore.GetRawReadOnly and UserLayoutStore.GetRawReadOnly(layoutId, FocalPoint.db) or nil
    if type(afterDelete) == "table" then
        return false, "store-delete-failed"
    end

    local db = FocalPoint.db
    local global = type(db) == "table" and rawget(db, "global")
    if type(global) == "table" and rawget(global, "defaultLayoutId") == layoutId then
        FocalPoint.LayoutAssignmentService.SetAccountDefaultLayoutId(nil, db)
    end

    local migration = FocalPoint.LayoutMigration or {}
    local migrationOk, migrationReason = true, "not-migrated"
    if type(migration.MarkDeletedUserLayout) == "function" then
        migrationOk, migrationReason = migration.MarkDeletedUserLayout(layoutId, existing.createdFrom, FocalPoint.db)
    end

    local clearedAssignments = 0
    local AssignmentService = FocalPoint.LayoutAssignmentService or {}
    if AssignmentService.ClearAssignmentsForLayout then
        local clearOk, countOrReason, partialCount = AssignmentService.ClearAssignmentsForLayout(layoutId, FocalPoint.db)
        clearedAssignments = type(countOrReason) == "number" and countOrReason or partialCount or 0
        if not clearOk then
            return true, layoutId, clearedAssignments, countOrReason or "assignment-reconcile-failed"
        end
    end

    if not migrationOk then
        return true, layoutId, clearedAssignments, migrationReason or "migration-delete-marker-failed"
    end

    return true, layoutId, clearedAssignments
end

function Mutations.RenameUserLayout(layoutId, newName)
    if type(layoutId) ~= "string" or layoutId == "" or not layoutId:match("^layout:") then
        return false, "invalid-layout"
    end

    local UserLayoutStore = FocalPoint.UserLayoutStore or {}
    local existing = UserLayoutStore.GetRawReadOnly and UserLayoutStore.GetRawReadOnly(layoutId, FocalPoint.db) or nil
    if type(existing) ~= "table" then
        return false, "layout-not-found"
    end

    local record = UserLayoutStore.GetMutableRaw and UserLayoutStore.GetMutableRaw(layoutId, FocalPoint.db) or nil
    if type(record) ~= "table" then
        return false, "layout-not-found"
    end

    local validName, normalizedNameOrReason = Mutations.ValidateLayoutName(newName, {
        excludeLayoutId = layoutId,
    })
    if not validName then
        return false, normalizedNameOrReason
    end

    local normalizedName = normalizedNameOrReason
    if Trim(record.name) == normalizedName then
        return true, "unchanged", layoutId
    end

    record.name = normalizedName
    return true, normalizedName, layoutId
end

-- C1b: data-only instance operations. Capture after the editable-layout workflow
-- has completed; a built-in is never mutated (nor copied implicitly here).
local SegmentedBars = {}
Mutations.SegmentedBars = SegmentedBars
local segmentSequence, observedSegmentIds = 0, {}
local segmentContexts = setmetatable({}, { __mode = "k" })

local function SegmentResult(ok, reason, id, changed)
    return { ok = ok, errorCode = reason, id = id, changed = changed == true }
end

local function SameSegmentData(a, b)
    if type(a) ~= type(b) then return false end
    if type(a) ~= "table" then return a == b end
    for key, value in pairs(a) do if not SameSegmentData(value, b[key]) then return false end end
    for key in pairs(b) do if a[key] == nil then return false end end
    return true
end

local function CurrentSegmentTarget(unitKey)
    if unitKey ~= "player" then return nil, "unsupported-unit" end
    local resolver, store = FocalPoint.ActiveLayoutResolver, FocalPoint.UserLayoutStore
    if not resolver or not store then return nil, "service-unavailable" end
    local db = FocalPoint.db
    local id = resolver.GetStoredActiveLayoutId(db)
    if type(id) ~= "string" or not id:match("^layout:") then return nil, "readonly-layout" end
    local root = resolver.GetActiveRuntimeRoot()
    local record = store.GetRawReadOnly(id, db)
    if not root or root.db ~= db or root.layoutId ~= id or not record or record.formatVersion ~= 2
        or type(record.payload) ~= "table"
        or root.record ~= record or root.payload ~= record.payload or root.units ~= record.payload.Units
        or root.global ~= db.global or root.store ~= store.PeekStore(db) then
        return nil, "stale-layout"
    end
    local unit = root.units and root.units[unitKey]
    if type(unit) ~= "table" then return nil, "unit-config-not-found" end
    local valid, reason = FocalPoint.LayoutService.ValidateSegmentedBars(unit.segmentedBars, unitKey)
    if not valid then return nil, reason end
    for _, item in ipairs(unit.segmentedBars or {}) do observedSegmentIds[item.id] = true end
    return { db = db, root = root, record = record, unit = unit, collection = unit.segmentedBars }
end

function SegmentedBars.CaptureContext(unitKey)
    local target, reason = CurrentSegmentTarget(unitKey)
    if not target then return nil, reason end
    target.snapshot = FocalPoint.LayoutService.Clone(target.collection)
    local context = {} -- Opaque, transient handle: callers cannot retarget old callbacks.
    segmentContexts[context] = target
    return context
end

local function CheckSegmentContext(context)
    local expected = segmentContexts[context]
    if not expected then return nil, "invalid-context" end
    local target, reason = CurrentSegmentTarget("player")
    if not target then return nil, reason end
    for _, key in ipairs({ "db", "root", "record", "unit", "collection" }) do
        if target[key] ~= expected[key] then return nil, "stale-context" end
    end
    if not SameSegmentData(target.collection, expected.snapshot) then return nil, "stale-context" end
    return target
end

local function NewSegmentId()
    local id
    repeat
        segmentSequence = segmentSequence + 1
        id = "segmented-bar-" .. segmentSequence
    until not observedSegmentIds[id]
    observedSegmentIds[id] = true -- Session only; deleted IDs cannot target a new record.
    return id
end

function SegmentedBars.IsContextCurrent(context)
    return CheckSegmentContext(context) ~= nil
end

local SEGMENT_GEOMETRY_FIELDS = {width=true,height=true,anchorTo=true,point=true,
    relativePoint=true,offsetX=true,offsetY=true}

local SEGMENT_STYLE_FIELDS = {texture=true,color=true,useBlizzardColor=true,background=true,backgroundColor=true,spacing=true,growth=true,
    runeTimerFont=true,runeTimerFontSize=true,runeTimerFontStyle=true}

local function MutateSegments(context, operation, id, value)
    if InCombatLockdown and InCombatLockdown() then return SegmentResult(false, "combat-blocked") end
    local target, reason = CheckSegmentContext(context)
    if not target then return SegmentResult(false, reason) end
    local service = FocalPoint.LayoutService
    local candidate = service.Clone(target.collection or {})
    local index
    for i, item in ipairs(candidate) do if item.id == id then index = i; break end end
    if operation ~= "add" and not index then return SegmentResult(false, "instance-not-found") end
    if operation == "add" then
        -- Validate before cloning caller data, including cycles/unknown runtime fields.
        local input = value
        if input == nil then input = { enabled = true, dataSource = { id = "auto", scope = "player" },
            useBlizzardColor = true, anchorTo = "Frame" } end
        if type(input) ~= "table" or getmetatable(input) or input.id ~= nil then
            return SegmentResult(false, "invalid-initial-values")
        end
        local item = {}; for key, entry in pairs(input) do item[key] = entry end
        id = NewSegmentId(); item.id = id; candidate[#candidate + 1] = item
    elseif operation == "duplicate" then
        local item = service.Clone(candidate[index]); id = NewSegmentId(); item.id = id
        table.insert(candidate, index + 1, item)
    elseif operation == "delete" then
        for _, item in ipairs(candidate) do
            if item.anchorTo == "SegmentedBar:" .. id then return SegmentResult(false, "anchor-in-use") end
        end
        table.remove(candidate, index)
    elseif operation == "enabled" then
        if type(value) ~= "boolean" then return SegmentResult(false, "invalid-enabled") end
        candidate[index].enabled = value
    elseif operation == "dataSource" then
        candidate[index].dataSource = value -- Shared validator checks the complete source before publication.
    elseif operation == "geometry" then
        if type(value) ~= "table" or getmetatable(value) then return SegmentResult(false, "invalid-geometry") end
        for field, entry in pairs(value) do
            if not SEGMENT_GEOMETRY_FIELDS[field] then return SegmentResult(false, "invalid-geometry-field") end
            candidate[index][field] = entry
        end
    elseif operation == "style" then
        if type(value) ~= "table" or getmetatable(value) then return SegmentResult(false, "invalid-style") end
        for field, entry in pairs(value) do
            if not SEGMENT_STYLE_FIELDS[field] then return SegmentResult(false, "invalid-style-field") end
            candidate[index][field] = entry
        end
    elseif operation == "reorder" then
        if type(value) ~= "number" or value ~= value or value % 1 ~= 0 or value < 1 or value > #candidate then
            return SegmentResult(false, "invalid-position")
        end
        table.insert(candidate, value, table.remove(candidate, index))
    end
    local valid, why = service.ValidateSegmentedBars(candidate, "player")
    if not valid then return SegmentResult(false, why) end
    candidate = service.Clone(candidate) -- Detach initialValues; never publish caller-owned tables.
    if SameSegmentData(candidate, target.collection or {}) then return SegmentResult(true, nil, id, false) end
    local workflow = FocalPoint.LayoutEditWorkflow
    if not workflow or not workflow.RequestEditableLayoutForMutation then return SegmentResult(false, "workflow-unavailable") end
    local result
    local ready, workflowReason = workflow.RequestEditableLayoutForMutation(function()
        if InCombatLockdown and InCombatLockdown() then result = SegmentResult(false, "combat-blocked"); return end
        local current, conflict = CheckSegmentContext(context)
        if not current then result = SegmentResult(false, conflict); return end
        current.unit.segmentedBars = candidate -- Single publication; existing runtime root shares this unit.
        segmentContexts[context] = nil
        result = SegmentResult(true, nil, id, true)
    end)
    -- No deferred operation: editable-user workflow is synchronous. Fail closed if it changes.
    if not result then segmentContexts[context] = nil end
    return result or SegmentResult(false, workflowReason or (ready and "mutation-not-applied" or "mutation-blocked"))
end

function SegmentedBars.Add(context, initialValues) return MutateSegments(context, "add", nil, initialValues) end
function SegmentedBars.Duplicate(context, id) return MutateSegments(context, "duplicate", id) end
function SegmentedBars.Delete(context, id) return MutateSegments(context, "delete", id) end
function SegmentedBars.SetEnabled(context, id, enabled) return MutateSegments(context, "enabled", id, enabled) end
function SegmentedBars.Reorder(context, id, position) return MutateSegments(context, "reorder", id, position) end
function SegmentedBars.SetGeometry(context, id, values) return MutateSegments(context, "geometry", id, values) end

function SegmentedBars.SetStyle(context, id, values) return MutateSegments(context, "style", id, values) end

function SegmentedBars.SetDataSource(context, id, source) return MutateSegments(context, "dataSource", id, source) end

return Mutations
