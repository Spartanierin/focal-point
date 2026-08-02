local _, FocalPoint = ...

FocalPoint.AuraScan = FocalPoint.AuraScan or {}
local AuraScan = FocalPoint.AuraScan
local UnitUtils = FocalPoint.UnitFrameUtils or {}
local IsSecretValue = UnitUtils.IsSecretValue
local MAX_AURA_SLOT_PAGES = 64
local MAX_AURA_INDEX_SCAN = 255
local MAX_AURA_DEBUG_EVENTS = 120

FocalPoint.AuraDiagnostics = FocalPoint.AuraDiagnostics or {}
local AuraDiagnostics = FocalPoint.AuraDiagnostics
AuraDiagnostics.state = AuraDiagnostics.state or {
    enabled = false,
    events = {},
}

local function IsSecret(value)
    return IsSecretValue and IsSecretValue(value) or false
end

local function SafeDebugText(value, fallback)
    if type(value) == "string" and value ~= "" then
        return value
    end

    return fallback or "-"
end

local function SafeDebugNumber(value)
    return tonumber(value) or 0
end

local function IncrementCounter(counters, key)
    key = SafeDebugText(key, "-")
    counters[key] = (tonumber(counters[key]) or 0) + 1
end

function AuraDiagnostics.SetEnabled(enabled)
    AuraDiagnostics.state.enabled = enabled == true
end

function AuraDiagnostics.IsEnabled()
    return AuraDiagnostics.state and AuraDiagnostics.state.enabled == true
end

function AuraDiagnostics.Reset()
    AuraDiagnostics.state = {
        enabled = AuraDiagnostics.IsEnabled(),
        events = {},
    }
end

function AuraDiagnostics.Record(entry)
    local state = AuraDiagnostics.state
    if not (state and state.enabled == true and type(entry) == "table") then
        return
    end

    local event = {
        time = SafeDebugNumber((GetTime and GetTime()) or 0),
        unit = SafeDebugText(entry.unit, "-"),
        group = SafeDebugText(entry.group, "-"),
        source = SafeDebugText(entry.source, "-"),
        backend = SafeDebugText(entry.backend, "-"),
        inCombat = InCombatLockdown and InCombatLockdown() == true or false,
        payloadClassification = SafeDebugText(entry.payloadClassification, "-"),
        scanClassification = SafeDebugText(entry.scanClassification, "-"),
        decision = SafeDebugText(entry.decision, "-"),
        filterClass = SafeDebugText(entry.filterClass, "-"),
        groupCount = SafeDebugNumber(entry.groupCount),
        safeAuraCount = SafeDebugNumber(entry.safeAuraCount),
        safeUpdatedCount = SafeDebugNumber(entry.safeUpdatedCount),
        safeAddedCount = SafeDebugNumber(entry.safeAddedCount),
        safeRemovedCount = SafeDebugNumber(entry.safeRemovedCount),
        skippedCount = SafeDebugNumber(entry.skippedCount),
    }

    state.events[#state.events + 1] = event
    if #state.events > MAX_AURA_DEBUG_EVENTS then
        table.remove(state.events, 1)
    end
end

local function AppendCounterLines(lines, label, counters)
    local keys = {}
    for key in pairs(counters) do
        keys[#keys + 1] = key
    end
    table.sort(keys)

    local parts = {}
    for _, key in ipairs(keys) do
        parts[#parts + 1] = string.format("%s=%d", key, SafeDebugNumber(counters[key]))
    end

    lines[#lines + 1] = string.format("%s: %s", label, #parts > 0 and table.concat(parts, ", ") or "-")
end

function AuraDiagnostics.BuildReport()
    local state = AuraDiagnostics.state or {}
    local events = state.events or {}
    local lines = {
        string.format("Aura diagnostics enabled=%s events=%d/%d", tostring(state.enabled == true), #events, MAX_AURA_DEBUG_EVENTS),
    }

    local bySource = {}
    local byBackend = {}
    local byPayload = {}
    local byScan = {}
    local byDecision = {}
    for _, event in ipairs(events) do
        IncrementCounter(bySource, event.source)
        IncrementCounter(byBackend, event.backend)
        IncrementCounter(byPayload, event.payloadClassification)
        IncrementCounter(byScan, event.scanClassification)
        IncrementCounter(byDecision, event.decision)
    end

    AppendCounterLines(lines, "By source", bySource)
    AppendCounterLines(lines, "By backend", byBackend)
    AppendCounterLines(lines, "By payload", byPayload)
    AppendCounterLines(lines, "By scan", byScan)
    AppendCounterLines(lines, "By decision", byDecision)

    local startIndex = math.max(1, #events - 19)
    for index = startIndex, #events do
        local event = events[index]
        lines[#lines + 1] = string.format(
            "%03d t=%.2f unit=%s group=%s combat=%s source=%s backend=%s filter=%s groups=%d payload=%s scan=%s decision=%s auras=%d added=%d updated=%d removed=%d skipped=%d",
            index,
            SafeDebugNumber(event.time),
            SafeDebugText(event.unit, "-"),
            SafeDebugText(event.group, "-"),
            tostring(event.inCombat == true),
            SafeDebugText(event.source, "-"),
            SafeDebugText(event.backend, "-"),
            SafeDebugText(event.filterClass, "-"),
            SafeDebugNumber(event.groupCount),
            SafeDebugText(event.payloadClassification, "-"),
            SafeDebugText(event.scanClassification, "-"),
            SafeDebugText(event.decision, "-"),
            SafeDebugNumber(event.safeAuraCount),
            SafeDebugNumber(event.safeAddedCount),
            SafeDebugNumber(event.safeUpdatedCount),
            SafeDebugNumber(event.safeRemovedCount),
            SafeDebugNumber(event.skippedCount)
        )
    end

    return lines
end

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

local function SafeGetAuraSlots(unit, filterToken, maxSlots, continuationToken)
    if not (C_UnitAuras and C_UnitAuras.GetAuraSlots) or IsSecret(continuationToken) then
        return false, nil, nil, "secret"
    end

    local ok, resultCount, results = pcall(function()
        local function CaptureReturns(...)
            local count = select("#", ...)
            local values = {}
            for index = 1, count do
                values[index] = select(index, ...)
            end

            return count, values
        end

        return CaptureReturns(C_UnitAuras.GetAuraSlots(unit, filterToken, maxSlots, continuationToken))
    end)
    if not ok or type(resultCount) ~= "number" or IsSecret(results) or type(results) ~= "table" then
        return false, nil, nil, ok and "secret" or "forbidden"
    end

    for index = 1, resultCount do
        if IsSecret(results[index]) then
            return false, nil, nil, "secret"
        end
    end

    return true, resultCount, results
end

local function SafeGetAuraDataBySlot(unit, slot)
    if not (C_UnitAuras and C_UnitAuras.GetAuraDataBySlot) or IsSecret(slot) then
        return false, nil, "secret"
    end

    local ok, auraData = pcall(C_UnitAuras.GetAuraDataBySlot, unit, slot)
    if not ok or IsSecret(auraData) then
        return false, nil, ok and "secret" or "forbidden"
    end

    if auraData == nil then
        return true, nil
    end

    if type(auraData) ~= "table" then
        return false, nil
    end

    return true, auraData
end

local function SafeGetAuraDataByIndex(unit, index, filterToken)
    if not (C_UnitAuras and C_UnitAuras.GetAuraDataByIndex) then
        return false, nil, "error"
    end

    local ok, auraData = pcall(C_UnitAuras.GetAuraDataByIndex, unit, index, filterToken)
    if not ok or IsSecret(auraData) then
        return false, nil, ok and "secret" or "forbidden"
    end

    if auraData == nil then
        return true, nil
    end

    if type(auraData) ~= "table" then
        return false, nil
    end

    return true, auraData
end

local function SafeGetAuraDataByAuraInstanceID(unit, auraInstanceId)
    if not (C_UnitAuras and C_UnitAuras.GetAuraDataByAuraInstanceID) or IsSecret(auraInstanceId) then
        return false, nil, "secret"
    end

    local ok, auraData = pcall(C_UnitAuras.GetAuraDataByAuraInstanceID, unit, auraInstanceId)
    if not ok or IsSecret(auraData) then
        return false, nil, ok and "secret" or "forbidden"
    end

    if auraData == nil then
        return true, nil
    end

    if type(auraData) ~= "table" then
        return false, nil
    end

    return true, auraData
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
        AuraDiagnostics.Record({
            unit = unit,
            group = groupKey,
            source = "FULL_REFRESH",
            scanClassification = "success",
            decision = "full_commit",
            safeAuraCount = 0,
        })
        return true, auraList
    end

    local filterToken, isHelpful, isHarmful = GetGroupFilter(groupKey)

    if C_UnitAuras then
        if C_UnitAuras.GetAuraSlots and C_UnitAuras.GetAuraDataBySlot then
            local continuationToken = nil
            local pageCount = 0
            repeat
                pageCount = pageCount + 1
                if pageCount > MAX_AURA_SLOT_PAGES then
                    AuraDiagnostics.Record({
                        unit = unit,
                        group = groupKey,
                        source = "FULL_REFRESH",
                        scanClassification = "error",
                        decision = "preserve",
                    })
                    return false, nil
                end

                local slotsOk, slotResultCount, slots, slotsStatus = SafeGetAuraSlots(unit, filterToken, 40, continuationToken)
                if not slotsOk then
                    AuraDiagnostics.Record({
                        unit = unit,
                        group = groupKey,
                        source = "FULL_REFRESH",
                        scanClassification = slotsStatus or "error",
                        decision = "preserve",
                    })
                    return false, nil
                end

                continuationToken = slots[1]

                for index = 2, slotResultCount do
                    local auraDataOk, auraData, auraDataStatus = SafeGetAuraDataBySlot(unit, slots[index])
                    if not auraDataOk then
                        AuraDiagnostics.Record({
                            unit = unit,
                            group = groupKey,
                            source = "FULL_REFRESH",
                            scanClassification = auraDataStatus or "error",
                            decision = "preserve",
                            safeAuraCount = #auraList,
                        })
                        return false, nil
                    end

                    if auraData then
                        auraList[#auraList + 1] = auraData
                    end
                end

            until continuationToken == nil or continuationToken == false

            AuraDiagnostics.Record({
                unit = unit,
                group = groupKey,
                source = "FULL_REFRESH",
                scanClassification = "success",
                decision = "full_commit",
                safeAuraCount = #auraList,
            })
            return true, auraList
        end

        if C_UnitAuras.GetAuraDataByIndex then
            for index = 1, MAX_AURA_INDEX_SCAN do
                local auraDataOk, auraData, auraDataStatus = SafeGetAuraDataByIndex(unit, index, filterToken)
                if not auraDataOk then
                    AuraDiagnostics.Record({
                        unit = unit,
                        group = groupKey,
                        source = "FULL_REFRESH",
                        scanClassification = auraDataStatus or "error",
                        decision = "preserve",
                        safeAuraCount = #auraList,
                    })
                    return false, nil
                end

                if not auraData then
                    AuraDiagnostics.Record({
                        unit = unit,
                        group = groupKey,
                        source = "FULL_REFRESH",
                        scanClassification = "success",
                        decision = "full_commit",
                        safeAuraCount = #auraList,
                    })
                    return true, auraList
                end

                auraList[#auraList + 1] = auraData
            end

            AuraDiagnostics.Record({
                unit = unit,
                group = groupKey,
                source = "FULL_REFRESH",
                scanClassification = "error",
                decision = "preserve",
                safeAuraCount = #auraList,
            })
            return false, nil
        end
    end

    -- Legacy compatibility for pre-Midnight clients only. Focal Point 1.0.6
    -- targets Midnight, where C_UnitAuras is expected and this path stays off.
    if IsMidnightClient() then
        AuraDiagnostics.Record({
            unit = unit,
            group = groupKey,
            source = "FULL_REFRESH",
            scanClassification = "success",
            decision = "full_commit",
            safeAuraCount = 0,
        })
        return true, auraList
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

    AuraDiagnostics.Record({
        unit = unit,
        group = groupKey,
        source = "FULL_REFRESH",
        scanClassification = "success",
        decision = "full_commit",
        safeAuraCount = #auraList,
    })
    return true, auraList
end

function AuraScan.TryGetAuraDataByInstanceID(unit, auraInstanceId)
    auraInstanceId = ToSafeNumber(auraInstanceId)
    if ComparePositive(auraInstanceId) ~= true or not (C_UnitAuras and C_UnitAuras.GetAuraDataByAuraInstanceID) then
        return true, nil
    end

    return SafeGetAuraDataByAuraInstanceID(unit, auraInstanceId)
end

function AuraScan.GetAuraDataByInstanceID(unit, auraInstanceId)
    local ok, auraData = AuraScan.TryGetAuraDataByInstanceID(unit, auraInstanceId)
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
