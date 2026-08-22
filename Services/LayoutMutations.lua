local _, FocalPoint = ...

FocalPoint.LayoutMutations = FocalPoint.LayoutMutations or {}
local Mutations = FocalPoint.LayoutMutations

local MAX_NAME_LENGTH = 64
local LAYOUT_FORMAT_VERSION = 1

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
    if type(summary) ~= "table" then
        return ""
    end
    local labelKey = summary.labelKey
    local localized = type(labelKey) == "string" and FocalPoint.L and FocalPoint.L[labelKey] or nil
    if type(localized) == "string" and localized ~= "" then
        return localized
    end
    if type(summary.name) == "string" and summary.name ~= "" then
        return summary.name
    end
    return type(summary.id) == "string" and summary.id or ""
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
        and type(payload.TextTemplates) == "table"
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

function Mutations.CopyLayout(layoutId, newName)
    if not IsCopyableLayoutId(layoutId) then
        return false, "unsupported-source"
    end

    local validName, normalizedNameOrReason = Mutations.ValidateLayoutName(newName)
    if not validName then
        return false, normalizedNameOrReason
    end

    local Resolver = FocalPoint.ActiveLayoutResolver or {}
    if not Resolver.ResolveLayout then
        return false, "resolver-unavailable"
    end
    local envelope, resolveReason = Resolver.ResolveLayout(FocalPoint.db, layoutId)
    if type(envelope) ~= "table" then
        return false, resolveReason or "layout-not-found"
    end
    if envelope.source ~= "userLayout" and envelope.source ~= "builtin" then
        return false, "unsupported-source"
    end

    local LayoutService = FocalPoint.LayoutService or {}
    local copiedPayload = LayoutService.CopyPayload and LayoutService.CopyPayload(envelope.payload) or nil
    if not IsValidLayoutPayload(copiedPayload) then
        return false, "payload-invalid"
    end

    local UserLayoutStore = FocalPoint.UserLayoutStore or {}
    if not (UserLayoutStore.GenerateId and UserLayoutStore.PutRaw) then
        return false, "user-layout-store-unavailable"
    end

    local newLayoutId = UserLayoutStore.GenerateId()
    if type(newLayoutId) ~= "string" or newLayoutId == "" then
        return false, "id-failed"
    end

    local record = {
        name = normalizedNameOrReason,
        payload = copiedPayload,
        formatVersion = LAYOUT_FORMAT_VERSION,
        createdFrom = {
            source = ResolveCreatedFromSource(envelope.source),
            id = envelope.id,
        },
    }
    local storedId = UserLayoutStore.PutRaw(newLayoutId, record)
    if storedId ~= newLayoutId then
        return false, "store-write-failed"
    end

    local storedRecord = UserLayoutStore.GetRawReadOnly and UserLayoutStore.GetRawReadOnly(newLayoutId, FocalPoint.db) or nil
    if type(storedRecord) ~= "table" or not IsValidLayoutPayload(storedRecord.payload) then
        return false, "store-verify-failed"
    end

    return true, newLayoutId, normalizedNameOrReason
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

    local clearedAssignments = 0
    local AssignmentService = FocalPoint.LayoutAssignmentService or {}
    if AssignmentService.ClearAssignmentsForLayout then
        local clearOk, countOrReason, partialCount = AssignmentService.ClearAssignmentsForLayout(layoutId, FocalPoint.db)
        clearedAssignments = type(countOrReason) == "number" and countOrReason or partialCount or 0
        if not clearOk then
            return true, layoutId, clearedAssignments, countOrReason or "assignment-reconcile-failed"
        end
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

return Mutations
