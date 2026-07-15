local _, FocalPoint = ...

FocalPoint.GUI = FocalPoint.GUI or {}
FocalPoint.GUI.Editor = FocalPoint.GUI.Editor or {}
FocalPoint.GUI.Editor.Inspector = FocalPoint.GUI.Editor.Inspector or {}

local InspectorAuraSelection = {}
FocalPoint.InspectorAuraSelection = InspectorAuraSelection
FocalPoint.GUI.Editor.Inspector.AuraSelection = InspectorAuraSelection

local function Result(ok, details)
    details = type(details) == "table" and details or {}
    details.ok = ok and true or false
    return details
end

local function IsValidAuraKey(auraKey)
    return type(auraKey) == "string" and auraKey ~= ""
end

function InspectorAuraSelection.IsValid(auraList, auraKey)
    return type(auraList) == "table" and IsValidAuraKey(auraKey) and auraList[auraKey] ~= nil
end

local function ResolveStoredAuraKey(state)
    if type(state) ~= "table" then
        return nil
    end

    return IsValidAuraKey(state.selectedAuraKey) and state.selectedAuraKey or nil
end

local function ResolveFallbackAuraKey(options, auraList)
    if type(options.getFirstAuraKey) == "function" then
        local ok, auraKey = pcall(options.getFirstAuraKey, auraList)
        if ok and InspectorAuraSelection.IsValid(auraList, auraKey) then
            return auraKey
        end
    end

    return nil
end

local function ResolveAuraConfig(unitConfig, auraKey)
    if type(unitConfig) ~= "table" or not IsValidAuraKey(auraKey) then
        return nil
    end

    local auraConfig = unitConfig[auraKey]
    return type(auraConfig) == "table" and auraConfig or nil
end

function InspectorAuraSelection.Resolve(options)
    options = type(options) == "table" and options or {}

    local state = options.state
    local auraList = type(options.auraList) == "table" and options.auraList or {}
    local unitConfig = type(options.unitConfig) == "table" and options.unitConfig or nil
    local storedAuraKey = ResolveStoredAuraKey(state)
    local effectiveAuraKey = storedAuraKey
    local usedFallback = false

    if not InspectorAuraSelection.IsValid(auraList, effectiveAuraKey) then
        effectiveAuraKey = ResolveFallbackAuraKey(options, auraList)
        usedFallback = storedAuraKey ~= effectiveAuraKey
    end

    local auraConfig = ResolveAuraConfig(unitConfig, effectiveAuraKey)
    if type(auraConfig) ~= "table" then
        auraConfig = nil
    end

    return Result(true, {
        storedAuraKey = storedAuraKey,
        effectiveAuraKey = effectiveAuraKey,
        auraConfig = auraConfig,
        usedFallback = usedFallback,
    })
end

function InspectorAuraSelection.Set(state, auraKey, auraList)
    if type(state) ~= "table" then
        return Result(false, { errorCode = "invalid_state" })
    end
    if not IsValidAuraKey(auraKey) then
        return Result(false, { errorCode = "invalid_aura_selection" })
    end
    if type(auraList) == "table" and auraList[auraKey] == nil then
        return Result(false, { errorCode = "aura_selection_not_found" })
    end

    local changed = state.selectedAuraKey ~= auraKey
    if changed then
        state.selectedAuraKey = auraKey
    end

    return Result(true, {
        changed = changed,
        auraKey = auraKey,
    })
end

return InspectorAuraSelection
