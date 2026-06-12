local _, FocalPoint = ...

FocalPoint.AuraScan = FocalPoint.AuraScan or {}
local AuraScan = FocalPoint.AuraScan
local IsSafeTrue = function(value)
    local ok, result = pcall(function()
        return value and true or false
    end)
    if ok and type(result) == "boolean" then
        return result
    end

    return false
end
local function IsSafeNumber(value)
    local ok, result = pcall(function()
        return type(value) == "number"
    end)
    if ok and type(result) == "boolean" then
        return result
    end

    return false
end
local function ComparePositive(value)
    local ok, result = pcall(function()
        return value > 0
    end)
    if ok and type(result) == "boolean" then
        return result
    end

    return nil
end

local function CompareNonPositive(value)
    local ok, result = pcall(function()
        return value <= 0
    end)
    if ok and type(result) == "boolean" then
        return result
    end

    return nil
end

local function CompareMoreThanOne(value)
    local ok, result = pcall(function()
        return value > 1
    end)
    if ok and type(result) == "boolean" then
        return result
    end

    return false
end

local function TryAdd(leftValue, rightValue)
    local ok, result = pcall(function()
        return leftValue + rightValue
    end)
    if ok and type(result) == "number" then
        return result
    end

    return nil
end

local function TryRemainingFromExpiration(expirationTime)
    local ok, result = pcall(function()
        return math.max(expirationTime - ((GetTime and GetTime()) or 0), 0)
    end)
    if ok and type(result) == "number" then
        return result
    end

    return 0
end

local function IsNonZeroValue(value)
    local ok, result = pcall(function()
        return value ~= 0
    end)
    if ok and type(result) == "boolean" then
        return result
    end

    return false
end

local function HasReadableText(value)
    local ok, result = pcall(function()
        return type(value) == "string" and value ~= ""
    end)
    if ok and type(result) == "boolean" then
        return result
    end

    return false
end
local function ToSafeString(value)
    local okDirect, directValue = pcall(function()
        if type(value) ~= "string" then
            return nil
        end

        if value == "" then
            return nil
        end

        return value
    end)
    if okDirect and type(directValue) == "string" then
        return directValue
    end

    local ok, textValue = pcall(tostring, value)
    local okText, safeText = pcall(function()
        if not ok or type(textValue) ~= "string" then
            return nil
        end

        if textValue == "" then
            return nil
        end

        return textValue
    end)
    if okText and type(safeText) == "string" then
        return safeText
    end

    local okFallback, fallbackText = pcall(function()
        if not ok or type(textValue) ~= "string" then
            return nil
        end

        local parsed = string.format("%s", textValue)
        if type(parsed) ~= "string" or parsed == "" then
            return nil
        end

        return parsed
    end)
    if okFallback and type(fallbackText) == "string" then
        return fallbackText
    end

    return nil
end
local ToSafeNumber = function(value)
    local okDirect, directValue = pcall(function()
        if type(value) == "number" then
            return value
        end

        return nil
    end)
    if okDirect and type(directValue) == "number" then
        return directValue
    end

    local ok, numberValue = pcall(tonumber, value)
    if ok and type(numberValue) == "number" then
        return numberValue
    end

    return 0
end

-- Normalizes Blizzard/Midnight aura data into FocalPoint-owned aura records.

local function GetGroupFilter(groupKey)
    if groupKey == "Debuffs" then
        return "HARMFUL", false, true
    end

    return "HELPFUL", true, false
end

local function IsMidnightClient()
    if not GetBuildInfo then
        return false
    end

    local ok, version, build, date, interfaceVersion = pcall(GetBuildInfo)
    return ok and (tonumber(interfaceVersion) or 0) >= 120000
end

local function GetAuraInstanceId(rawAura)
    if type(rawAura) ~= "table" then
        return 0
    end

    return ToSafeNumber(rawAura.auraInstanceId or rawAura.auraInstanceID or 0)
end

local function CallDurationMethod(durationObject, methodName)
    if not durationObject or not methodName then
        return nil
    end

    local ok, value = pcall(function()
        local method = durationObject[methodName]
        if type(method) ~= "function" then
            return nil
        end

        return method(durationObject)
    end)
    if ok and value ~= nil then
        return value
    end

    return nil
end

local function ReadDurationObjectFields(durationObject)
    if not durationObject then
        return 0, 0, 0, false, false, false
    end

    local duration = 0
    local expirationTime = 0
    local remaining = 0
    local hasExplicitDurationSignal = false
    local startTime = 0

    local valueRemaining = CallDurationMethod(durationObject, "GetRemainingDuration")
    if valueRemaining ~= nil then
        hasExplicitDurationSignal = true
        remaining = ToSafeNumber(valueRemaining)
    end

    local valueDuration = CallDurationMethod(durationObject, "GetDuration")
        or CallDurationMethod(durationObject, "GetTotalDuration")
    if valueDuration == nil then
        local okDuration, rawValue = pcall(function()
            return durationObject.duration or durationObject.total or durationObject.totalDuration
        end)
        if okDuration then
            valueDuration = rawValue
        end
    end
    if valueDuration ~= nil then
        hasExplicitDurationSignal = true
    end
    duration = ToSafeNumber(valueDuration)

    local valueExpiration = CallDurationMethod(durationObject, "GetExpirationTime")
    if valueExpiration == nil then
        local _, rawValue = pcall(function()
            return durationObject.expirationTime or durationObject.expires
        end)
        valueExpiration = rawValue
    end
    if valueExpiration ~= nil then
        hasExplicitDurationSignal = true
    end
    expirationTime = ToSafeNumber(valueExpiration)

    if CompareNonPositive(expirationTime) == true then
        local valueStart = CallDurationMethod(durationObject, "GetStartTime")
        if valueStart == nil then
            local _, rawValue = pcall(function()
                return durationObject.startTime or durationObject.start
            end)
            valueStart = rawValue
        end
        if valueStart ~= nil then
            hasExplicitDurationSignal = true
        end
        startTime = ToSafeNumber(valueStart)

        if ComparePositive(startTime) == true and ComparePositive(duration) == true then
            local computedExpiration = TryAdd(startTime, duration)
            if computedExpiration then
                expirationTime = computedExpiration
            end
        end
    end

    if CompareNonPositive(remaining) == true and ComparePositive(expirationTime) == true then
        remaining = TryRemainingFromExpiration(expirationTime)
    end

    if CompareNonPositive(expirationTime) == true and ComparePositive(remaining) == true then
        local computedExpiration = TryAdd(((GetTime and GetTime()) or 0), remaining)
        if computedExpiration then
            expirationTime = computedExpiration
        end
    end

    if CompareNonPositive(duration) == true and ComparePositive(remaining) == true then
        duration = remaining
    end

    local hasFullTimer = ComparePositive(duration) == true and ComparePositive(expirationTime) == true
    local hasReadableRemaining = ComparePositive(remaining) == true
    local hasExplicitZeroTimer = hasExplicitDurationSignal
        and CompareNonPositive(duration) == true
        and CompareNonPositive(expirationTime) == true
        and CompareNonPositive(remaining) == true
        and CompareNonPositive(startTime) == true

    return duration, expirationTime, remaining, hasFullTimer, hasReadableRemaining, hasExplicitZeroTimer
end

local function ResolveTimeModel(unit, rawAura, sourceContext)
    local rawDuration = rawAura and rawAura.duration or 0
    local rawExpirationTime = rawAura and rawAura.expirationTime or 0
    local rawHasFields = rawAura and rawAura.duration ~= nil and rawAura.expirationTime ~= nil
    local rawDurationPositive = rawHasFields and ComparePositive(rawDuration) or nil
    local rawExpirationPositive = rawHasFields and ComparePositive(rawExpirationTime) or nil
    local rawDurationNonPositive = rawHasFields and CompareNonPositive(rawDuration) or nil
    local rawExpirationNonPositive = rawHasFields and CompareNonPositive(rawExpirationTime) or nil

    local auraInstanceId = GetAuraInstanceId(rawAura)
    local durationObject = nil
    if ComparePositive(auraInstanceId) == true and C_UnitAuras and C_UnitAuras.GetAuraDuration then
        local okDurationObject, resolvedDurationObject = pcall(C_UnitAuras.GetAuraDuration, unit, auraInstanceId)
        if okDurationObject then
            durationObject = resolvedDurationObject
        end
    end

    if durationObject then
        local duration, expirationTime, remaining, hasFullTimer, hasReadableRemaining, hasExplicitZeroTimer = ReadDurationObjectFields(durationObject)
        if hasFullTimer then
            return duration, expirationTime, remaining, durationObject, "object-readable", "TIMED", "READY"
        end

        if hasReadableRemaining then
            return duration, expirationTime, remaining, durationObject, "object-remaining", "TIMED", "READY"
        end

        local rawLooksPermanent = rawHasFields
            and rawDurationNonPositive == true
            and rawExpirationNonPositive == true
        if hasExplicitZeroTimer and rawLooksPermanent then
            return 0, 0, 0, durationObject, "object-zero", "PERMANENT", "HIDDEN"
        end
    end

    if rawHasFields and rawDurationPositive ~= nil and rawExpirationPositive ~= nil then
        if rawDurationPositive and rawExpirationPositive then
            local remaining = TryRemainingFromExpiration(rawExpirationTime)
            return rawDuration, rawExpirationTime, remaining, durationObject, "raw-readable", "TIMED", "READY"
        end

        if rawDurationNonPositive == true and rawExpirationNonPositive == true then
            return 0, 0, 0, durationObject, "raw-permanent", "PERMANENT", "HIDDEN"
        end
    end

    if durationObject then
        if sourceContext == "EVENT" then
            return 0, 0, 0, durationObject, "object-unreadable", "PENDING", "UNAVAILABLE"
        end

        return 0, 0, 0, durationObject, "object-unreadable", "PERMANENT", "HIDDEN"
    end

    if not rawHasFields then
        return 0, 0, 0, nil, "missing", "PERMANENT", "HIDDEN"
    end

    return 0, 0, 0, nil, "unknown", "UNRESOLVED", "UNAVAILABLE"
end

local function IsAuraVisibleInFilter(unit, auraInstanceId, filterToken)
    if ComparePositive(auraInstanceId) ~= true or not filterToken or not (C_UnitAuras and C_UnitAuras.IsAuraFilteredOutByInstanceID) then
        return false
    end

    local ok, isFilteredOut = pcall(C_UnitAuras.IsAuraFilteredOutByInstanceID, unit, auraInstanceId, filterToken)
    if ok and type(isFilteredOut) == "boolean" and not (issecretvalue and issecretvalue(isFilteredOut)) then
        return not isFilteredOut
    end

    return false
end

local function ResolveGroupFlags(unit, rawAura, groupIsHelpful, groupIsHarmful)
    local isHelpful = IsSafeTrue(rawAura.isHelpful)
    local isHarmful = IsSafeTrue(rawAura.isHarmful)
    if isHelpful or isHarmful then
        return isHelpful, isHarmful
    end

    local auraInstanceId = GetAuraInstanceId(rawAura)
    if ComparePositive(auraInstanceId) == true then
        local helpfulVisible = IsAuraVisibleInFilter(unit, auraInstanceId, "HELPFUL")
        local harmfulVisible = IsAuraVisibleInFilter(unit, auraInstanceId, "HARMFUL")
        if helpfulVisible or harmfulVisible then
            return helpfulVisible, harmfulVisible
        end
    end

    return groupIsHelpful, groupIsHarmful
end

local function ResolveIsMine(unit, groupKey, rawAura, sourceUnit, castByPlayer, isHelpful, isHarmful)
    if castByPlayer or sourceUnit == "player" or sourceUnit == "pet" then
        return true
    end

    local auraInstanceId = GetAuraInstanceId(rawAura)
    if groupKey then
        local filterToken = GetGroupFilter(groupKey)
        return IsAuraVisibleInFilter(unit, auraInstanceId, filterToken .. "|PLAYER")
    end

    if isHelpful and IsAuraVisibleInFilter(unit, auraInstanceId, "HELPFUL|PLAYER") then
        return true
    end

    if isHarmful and IsAuraVisibleInFilter(unit, auraInstanceId, "HARMFUL|PLAYER") then
        return true
    end

    return false
end

local function SafeUnitGUID(unit)
    if not unit or not UnitGUID then
        return nil
    end

    local ok, guid = pcall(UnitGUID, unit)
    if not ok or guid == nil then
        return nil
    end

    if issecretvalue and issecretvalue(guid) then
        return nil
    end

    local okType, isString = pcall(function()
        return type(guid) == "string"
    end)
    if not okType or isString ~= true then
        return nil
    end

    local okNonEmpty, isNonEmpty = pcall(function()
        return guid ~= ""
    end)
    if not okNonEmpty or isNonEmpty ~= true then
        return nil
    end

    return guid
end

local function BuildLegacyRawAura(unit, index, filterToken, isHelpful, isHarmful)
    if not UnitAura then
        return nil
    end

    local name,
        icon,
        applications,
        dispelName,
        duration,
        expirationTime,
        sourceUnit,
        isStealable,
        _nameplateShowPersonal,
        spellId,
        canApplyAura,
        isBossAura,
        castByPlayer = UnitAura(unit, index, filterToken)

    if not name and not icon and not spellId then
        return nil
    end

    return {
        name = name,
        icon = icon,
        applications = applications,
        dispelName = dispelName,
        duration = duration,
        expirationTime = expirationTime,
        sourceUnit = sourceUnit,
        isStealable = isStealable,
        spellId = spellId,
        canApplyAura = canApplyAura,
        isBossAura = isBossAura,
        isHelpful = isHelpful,
        isHarmful = isHarmful,
        castByPlayer = castByPlayer,
    }
end

function AuraScan.CollectUnitAuras(unit, groupKey)
    local auraList = {}
    if not unit then
        return auraList
    end

    local filterToken, isHelpful, isHarmful = GetGroupFilter(groupKey)

    if C_UnitAuras then
        if C_UnitAuras.GetAuraSlots and C_UnitAuras.GetAuraDataBySlot then
            local continuationToken = nil
            repeat
                local slots = { C_UnitAuras.GetAuraSlots(unit, filterToken, 40, continuationToken) }
                continuationToken = slots[1]

                for index = 2, #slots do
                    local auraData = C_UnitAuras.GetAuraDataBySlot(unit, slots[index])
                    if auraData then
                        auraList[#auraList + 1] = auraData
                    end
                end

            until not continuationToken

            return auraList
        end

        if C_UnitAuras.GetAuraDataByIndex then
            local index = 1
            while true do
                local auraData = C_UnitAuras.GetAuraDataByIndex(unit, index, filterToken)
                if not auraData then
                    break
                end

                auraList[#auraList + 1] = auraData
                index = index + 1
            end

            return auraList
        end
    end

    -- Legacy compatibility for pre-Midnight clients only. Focal Point 1.0.6
    -- targets Midnight, where C_UnitAuras is expected and this path stays off.
    if IsMidnightClient() then
        return auraList
    end

    local index = 1
    while true do
        local rawAura = BuildLegacyRawAura(unit, index, filterToken, isHelpful, isHarmful)
        if not rawAura then
            break
        end

        auraList[#auraList + 1] = rawAura
        index = index + 1
    end

    return auraList
end

function AuraScan.GetAuraDataByInstanceID(unit, auraInstanceId)
    auraInstanceId = ToSafeNumber(auraInstanceId)
    if ComparePositive(auraInstanceId) ~= true or not (C_UnitAuras and C_UnitAuras.GetAuraDataByAuraInstanceID) then
        return nil
    end

    local ok, auraData = pcall(C_UnitAuras.GetAuraDataByAuraInstanceID, unit, auraInstanceId)
    if ok then
        return auraData
    end

    return nil
end

function AuraScan.AuraBelongsToGroup(unit, rawAura, groupKey)
    if type(rawAura) ~= "table" or not unit or not groupKey then
        return false
    end

    local auraInstanceId = GetAuraInstanceId(rawAura)
    local filterToken = GetGroupFilter(groupKey)
    if ComparePositive(auraInstanceId) == true and C_UnitAuras and C_UnitAuras.IsAuraFilteredOutByInstanceID then
        local ok, isFilteredOut = pcall(C_UnitAuras.IsAuraFilteredOutByInstanceID, unit, auraInstanceId, filterToken)
        if ok and type(isFilteredOut) == "boolean" and not (issecretvalue and issecretvalue(isFilteredOut)) then
            return not isFilteredOut
        end
    end

    if groupKey == "Buffs" then
        return IsSafeTrue(rawAura.isHelpful)
    end

    if groupKey == "Debuffs" then
        return IsSafeTrue(rawAura.isHarmful)
    end

    return false
end

function AuraScan.NormalizeAura(rawAura, unit, groupKey, sourceContext)
    if type(rawAura) ~= "table" then
        return nil
    end

    local groupIsHelpful = false
    local groupIsHarmful = false
    if groupKey then
        local _
        _, groupIsHelpful, groupIsHarmful = GetGroupFilter(groupKey)
    end
    local sourceUnit = ToSafeString(rawAura.sourceUnit)
    local count = ToSafeNumber(rawAura.applications or rawAura.count or 0)
    local duration, expirationTime, remaining, durationObject, durationSource, durationState, timerState = ResolveTimeModel(unit, rawAura, sourceContext)

    local isHelpful, isHarmful = ResolveGroupFlags(unit, rawAura, groupIsHelpful, groupIsHarmful)

    local hasDuration = durationState == "TIMED"
    local isPlayerCast = IsSafeTrue(rawAura.castByPlayer)
    local isMine = ResolveIsMine(unit, groupKey, rawAura, sourceUnit, isPlayerCast, isHelpful, isHarmful)

    local normalizedAura = {
        spellId = rawAura.spellId or 0,
        auraInstanceId = rawAura.auraInstanceId or rawAura.auraInstanceID or 0,

        name = rawAura.name or "",
        icon = rawAura.icon,

        isHelpful = isHelpful,
        isHarmful = isHarmful,

        count = count,
        duration = duration,
        expirationTime = expirationTime,
        remaining = remaining,
        durationObject = durationObject,
        durationSource = durationSource,
        durationState = durationState,
        timerState = timerState,
        durationObjectPresent = durationObject ~= nil,
        timerReadable = timerState == "READY",

        sourceUnit = sourceUnit,
        sourceGUID = SafeUnitGUID(sourceUnit),

        isPlayerCast = isPlayerCast,
        isMine = isMine,
        isBossAura = IsSafeTrue(rawAura.isBossAura),
        isStealable = IsSafeTrue(rawAura.isStealable),
        dispelName = rawAura.dispelName,
        canApplyAura = IsSafeTrue(rawAura.canApplyAura),

        durationKnown = durationState ~= "UNKNOWN" and durationState ~= "PENDING" and durationState ~= "UNRESOLVED",
        hasDuration = hasDuration,
        hasStacks = CompareMoreThanOne(count),
        sourceIndex = ToSafeNumber(rawAura.sourceIndex or 0),
        sortKey = 0,
    }

    return normalizedAura
end

function AuraScan.BuildDisplayAuras(rawAuras, unit, groupKey)
    local displayAuras = {}
    if type(rawAuras) ~= "table" then
        return displayAuras
    end

    for index, rawAura in ipairs(rawAuras) do
        local aura = AuraScan.NormalizeAura(rawAura, unit, groupKey, "FULLSCAN")
        local hasSpellId = aura and IsNonZeroValue(aura.spellId)
        local hasIcon = aura and aura.icon ~= nil
        local hasName = aura and HasReadableText(aura.name)
        if aura and (hasSpellId or hasIcon or hasName) then
            aura.sourceIndex = index
            aura.sortKey = index
            displayAuras[#displayAuras + 1] = aura
        end
    end

    return displayAuras
end
