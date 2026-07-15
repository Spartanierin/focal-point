local _, FocalPoint = ...

FocalPoint.GUI = FocalPoint.GUI or {}
FocalPoint.GUI.Editor = FocalPoint.GUI.Editor or {}
FocalPoint.GUI.Editor.Inspector = FocalPoint.GUI.Editor.Inspector or {}

local InspectorIndicatorSelection = {}
FocalPoint.InspectorIndicatorSelection = InspectorIndicatorSelection
FocalPoint.GUI.Editor.Inspector.IndicatorSelection = InspectorIndicatorSelection

local function Result(ok, details)
    details = type(details) == "table" and details or {}
    details.ok = ok and true or false
    return details
end

local function IsValidIndicatorKey(indicatorKey)
    return type(indicatorKey) == "string" and indicatorKey ~= ""
end

function InspectorIndicatorSelection.IsValid(indicatorList, indicatorKey)
    return type(indicatorList) == "table" and IsValidIndicatorKey(indicatorKey) and indicatorList[indicatorKey] ~= nil
end

local function ResolveStoredIndicatorKey(state)
    if type(state) ~= "table" then
        return nil
    end

    return IsValidIndicatorKey(state.selectedIndicatorKey) and state.selectedIndicatorKey or nil
end

local function ResolveFallbackIndicatorKey(options, indicatorList)
    if type(options.getFirstIndicatorKey) == "function" then
        local ok, indicatorKey = pcall(options.getFirstIndicatorKey, indicatorList)
        if ok and InspectorIndicatorSelection.IsValid(indicatorList, indicatorKey) then
            return indicatorKey
        end
    end

    return nil
end

local function ResolveIndicatorConfig(unitConfig, indicatorMetaEntry)
    if type(unitConfig) ~= "table" or type(indicatorMetaEntry) ~= "table" then
        return nil
    end

    return unitConfig[indicatorMetaEntry.optionKey]
end

function InspectorIndicatorSelection.Resolve(options)
    options = type(options) == "table" and options or {}

    local state = options.state
    local indicatorList = type(options.indicatorList) == "table" and options.indicatorList or {}
    local indicatorMeta = type(options.indicatorMeta) == "table" and options.indicatorMeta or {}
    local unitConfig = type(options.unitConfig) == "table" and options.unitConfig or nil
    local unitKey = options.unitKey
    local storedIndicatorKey = ResolveStoredIndicatorKey(state)
    local effectiveIndicatorKey = storedIndicatorKey
    local usedFallback = false

    if not InspectorIndicatorSelection.IsValid(indicatorList, effectiveIndicatorKey) then
        effectiveIndicatorKey = ResolveFallbackIndicatorKey(options, indicatorList)
        usedFallback = storedIndicatorKey ~= effectiveIndicatorKey
    end

    local indicatorMetaEntry = indicatorMeta[effectiveIndicatorKey]
    local indicatorConfig = ResolveIndicatorConfig(unitConfig, indicatorMetaEntry)

    if not indicatorConfig and unitKey == "boss" and indicatorList.RaidTargetIcon then
        effectiveIndicatorKey = "RaidTargetIcon"
        indicatorMetaEntry = indicatorMeta[effectiveIndicatorKey]
        indicatorConfig = ResolveIndicatorConfig(unitConfig, indicatorMetaEntry)
        usedFallback = storedIndicatorKey ~= effectiveIndicatorKey
    end

    if type(indicatorMetaEntry) ~= "table" then
        indicatorMetaEntry = nil
    end
    if type(indicatorConfig) ~= "table" then
        indicatorConfig = nil
    end

    return Result(true, {
        storedIndicatorKey = storedIndicatorKey,
        effectiveIndicatorKey = effectiveIndicatorKey,
        indicatorMetaEntry = indicatorMetaEntry,
        indicatorConfig = indicatorConfig,
        usedFallback = usedFallback,
    })
end

function InspectorIndicatorSelection.Set(state, indicatorKey, indicatorList)
    if type(state) ~= "table" then
        return Result(false, { errorCode = "invalid_state" })
    end
    if not IsValidIndicatorKey(indicatorKey) then
        return Result(false, { errorCode = "invalid_indicator_selection" })
    end
    if type(indicatorList) == "table" and indicatorList[indicatorKey] == nil then
        return Result(false, { errorCode = "indicator_selection_not_found" })
    end

    local changed = state.selectedIndicatorKey ~= indicatorKey
    if changed then
        state.selectedIndicatorKey = indicatorKey
    end

    return Result(true, {
        changed = changed,
        indicatorKey = indicatorKey,
    })
end

return InspectorIndicatorSelection
