local _, FocalPoint = ...

FocalPoint.LayoutMutations = FocalPoint.LayoutMutations or {}
local Mutations = FocalPoint.LayoutMutations

local MAX_NAME_LENGTH = 64

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
