local _, FocalPoint = ...

FocalPoint.AuraCache = FocalPoint.AuraCache or {}
local AuraCache = FocalPoint.AuraCache
local State = FocalPoint.UnitFrameState or {}

-- Owns the authoritative aura cache for a unit frame. Raw event/fullscan data
-- lands here first; Buff/Debuff lists are derived afterwards.

local GROUP_KEYS = { "Buffs", "Debuffs" }

local function Log(frame, action, details)
    if State.DebugLog then
        State.DebugLog(frame, "aura-" .. tostring(action or "?"), details)
    end
end

local function CountKeys(source)
    local count = 0
    if type(source) ~= "table" then
        return count
    end

    for _ in pairs(source) do
        count = count + 1
    end

    return count
end

local function ToInstanceId(value)
    local ok, result = pcall(function()
        return tonumber(value or 0) or 0
    end)
    if ok and type(result) == "number" then
        return result
    end

    return 0
end

local function StampAura(aura, source)
    if type(aura) ~= "table" then
        return aura
    end

    aura._cacheSource = source or aura._cacheSource or "FULLSCAN"
    aura._cacheSeenAt = (GetTime and GetTime()) or 0
    return aura
end

local function ShouldKeepMissingEventAura(aura, now)
    if type(aura) ~= "table" or aura._cacheSource ~= "EVENT" then
        return false
    end

    local seenAt = tonumber(aura._cacheSeenAt or 0) or 0
    if seenAt <= 0 then
        return false
    end

    return (now - seenAt) <= 1.0
end

local function GetRoot(frame)
    frame.AuraCache = frame.AuraCache or {}
    frame.AuraCache.allById = frame.AuraCache.allById or {}
    frame.AuraCache.rawByGroup = frame.AuraCache.rawByGroup or {}
    frame.AuraCache.unkeyedByGroup = frame.AuraCache.unkeyedByGroup or {}
    frame.AuraCache.groups = frame.AuraCache.groups or {}
    frame.AuraCache.state = frame.AuraCache.state or {
        phase = "cold",
        boundUnit = frame and frame.unit or nil,
        lastReason = nil,
        lastRefreshMode = nil,
        version = 0,
        pendingReconcile = false,
    }
    return frame.AuraCache
end

local function GetRootState(frame)
    local root = GetRoot(frame)
    root.state = root.state or {}
    return root.state
end

local function GetGroupState(group)
    group.state = group.state or {
        phase = "empty_valid",
        lastReason = nil,
        renderedCount = 0,
        visibleCount = 0,
        sortedCount = 0,
        rawCount = 0,
    }
    return group.state
end

local function AuraMatchesGroup(aura, groupKey)
    if type(aura) ~= "table" then
        return false
    end

    if groupKey == "Buffs" then
        return aura.isHelpful == true
    end

    if groupKey == "Debuffs" then
        return aura.isHarmful == true
    end

    return false
end

function AuraCache.GetGroup(frame, groupKey)
    local root = GetRoot(frame)
    root.groups[groupKey] = root.groups[groupKey] or {}
    local group = root.groups[groupKey]
    group.rawAuras = group.rawAuras or {}
    group.allAuras = group.allAuras or {}
    group.activeAuras = group.activeAuras or {}
    group.visibleAuras = group.visibleAuras or {}
    group.sortedAuras = group.sortedAuras or {}
    GetGroupState(group)
    return group
end

function AuraCache.MarkRefreshStart(frame, unit, mode)
    local state = GetRootState(frame)
    state.boundUnit = unit or state.boundUnit
    state.phase = "refreshing"
    state.lastRefreshMode = mode or state.lastRefreshMode or "refresh"
    state.lastReason = mode or state.lastReason
    Log(frame, "refresh-start", string.format("mode=%s unit=%s", tostring(state.lastRefreshMode or "-"), tostring(state.boundUnit or "-")))
end

function AuraCache.MarkReconcileQueued(frame, reason)
    local state = GetRootState(frame)
    state.pendingReconcile = true
    state.lastReason = reason or "reconcile"
    Log(frame, "reconcile-queued", string.format("reason=%s", tostring(state.lastReason or "-")))
end

function AuraCache.MarkRefreshApplied(frame, groupKey, counts)
    local group = AuraCache.GetGroup(frame, groupKey)
    local groupState = GetGroupState(group)
    local rootState = GetRootState(frame)
    counts = type(counts) == "table" and counts or {}

    groupState.phase = (tonumber(counts.sorted or 0) or 0) > 0 and "rendered" or "empty_valid"
    groupState.lastReason = rootState.lastReason
    groupState.rawCount = tonumber(counts.raw or 0) or 0
    groupState.visibleCount = tonumber(counts.visible or 0) or 0
    groupState.sortedCount = tonumber(counts.sorted or 0) or 0
    groupState.renderedCount = tonumber(counts.rendered or counts.sorted or 0) or 0

    rootState.phase = "cache_ready"
    rootState.pendingReconcile = false

    Log(frame, "render-applied", string.format("group=%s raw=%d vis=%d sorted=%d", tostring(groupKey), groupState.rawCount, groupState.visibleCount, groupState.sortedCount))
end

function AuraCache.MarkGroupCleared(frame, groupKey, reason)
    local group = AuraCache.GetGroup(frame, groupKey)
    local groupState = GetGroupState(group)
    groupState.phase = "empty_valid"
    groupState.lastReason = reason or "clear"
    groupState.rawCount = 0
    groupState.visibleCount = 0
    groupState.sortedCount = 0
    groupState.renderedCount = 0
    Log(frame, "group-cleared", string.format("group=%s reason=%s", tostring(groupKey), tostring(groupState.lastReason or "-")))
end

function AuraCache.SyncFromScans(frame, unit, scansByGroup)
    if not frame or not unit or type(scansByGroup) ~= "table" then
        return {}
    end

    local AuraScan = FocalPoint.AuraScan or {}
    local root = GetRoot(frame)
    local rootState = GetRootState(frame)
    local scannedById = {}
    local now = (GetTime and GetTime()) or 0

    for _, groupKey in ipairs(GROUP_KEYS) do
        local rawAuras = type(scansByGroup[groupKey]) == "table" and scansByGroup[groupKey] or {}
        local group = AuraCache.GetGroup(frame, groupKey)
        local groupState = GetGroupState(group)
        local unkeyed = {}

        group.rawAuras = rawAuras
        root.rawByGroup[groupKey] = rawAuras
        groupState.phase = "hydrating"
        groupState.rawCount = #rawAuras

        for index, rawAura in ipairs(rawAuras) do
            local aura = AuraScan.NormalizeAura and AuraScan.NormalizeAura(rawAura, unit, groupKey, "FULLSCAN") or nil
            if aura then
                aura.sourceIndex = index
                aura.sortKey = index

                local auraInstanceId = ToInstanceId(aura.auraInstanceId)
                if auraInstanceId > 0 then
                    scannedById[auraInstanceId] = StampAura(aura, "FULLSCAN")
                else
                    unkeyed[#unkeyed + 1] = StampAura(aura, "FULLSCAN")
                end
            end
        end

        root.unkeyedByGroup[groupKey] = unkeyed
    end

    for auraInstanceId, aura in pairs(scannedById) do
        root.allById[auraInstanceId] = aura
    end

    for auraInstanceId, aura in pairs(root.allById) do
        if not scannedById[auraInstanceId] then
            if not ShouldKeepMissingEventAura(aura, now) then
                root.allById[auraInstanceId] = nil
            end
        end
    end

    rootState.boundUnit = unit
    rootState.phase = "cache_ready"
    rootState.lastRefreshMode = "fullscan"
    rootState.lastReason = "fullscan"
    rootState.pendingReconcile = false
    rootState.version = (tonumber(rootState.version) or 0) + 1
    Log(frame, "cache-sync", string.format("mode=fullscan ids=%d", CountKeys(scannedById)))

    return root.allById
end

function AuraCache.GetAllAuras(frame, groupKey)
    local root = GetRoot(frame)
    local group = AuraCache.GetGroup(frame, groupKey)
    local auraList = {}

    for _, aura in pairs(root.allById) do
        if AuraMatchesGroup(aura, groupKey) then
            auraList[#auraList + 1] = aura
        end
    end

    local unkeyed = root.unkeyedByGroup[groupKey]
    if type(unkeyed) == "table" then
        for _, aura in ipairs(unkeyed) do
            if AuraMatchesGroup(aura, groupKey) then
                auraList[#auraList + 1] = aura
            end
        end
    end

    group.allAuras = auraList
    return auraList
end

function AuraCache.ReconcileEventAuras(frame, unit)
    if not frame or not unit then
        return false
    end

    local AuraScan = FocalPoint.AuraScan or {}
    local root = GetRoot(frame)
    local rootState = GetRootState(frame)
    local changed = false

    if not (AuraScan.GetAuraDataByInstanceID and AuraScan.NormalizeAura) then
        return false
    end

    for auraInstanceId, cachedAura in pairs(root.allById) do
        if type(cachedAura) == "table" and cachedAura._cacheSource == "EVENT" and cachedAura.durationState == "UNKNOWN" then
            local rawAura = AuraScan.GetAuraDataByInstanceID(unit, auraInstanceId)
            if type(rawAura) == "table" then
                local aura = AuraScan.NormalizeAura(rawAura, unit, nil, "EVENT")
                if aura then
                    aura.sourceIndex = cachedAura.sourceIndex or aura.sourceIndex or 0
                    aura.sortKey = cachedAura.sortKey or aura.sortKey or 0
                    root.allById[auraInstanceId] = StampAura(aura, "EVENT")
                    changed = true
                end
            end
        end
    end

    rootState.pendingReconcile = false
    if changed then
        rootState.phase = "cache_ready"
        rootState.lastRefreshMode = "reconcile"
        rootState.lastReason = "reconcile"
        rootState.version = (tonumber(rootState.version) or 0) + 1
        Log(frame, "cache-reconcile", "changed=true")
    end

    return changed
end

function AuraCache.HasUnknownEventAuras(frame)
    if not frame or not frame.AuraCache or type(frame.AuraCache.allById) ~= "table" then
        return false
    end

    for _, aura in pairs(frame.AuraCache.allById) do
        if type(aura) == "table" and aura._cacheSource == "EVENT" and aura.durationState == "UNKNOWN" then
            return true
        end
    end

    return false
end

function AuraCache.ApplyUpdate(frame, unit, updateInfo)
    if not frame or not unit or type(updateInfo) ~= "table" then
        return false
    end

    local AuraScan = FocalPoint.AuraScan or {}
    local root = GetRoot(frame)
    local rootState = GetRootState(frame)
    local changed = false

    local function ResolveGroupHint(rawAura)
        if type(rawAura) ~= "table" or not AuraScan.AuraBelongsToGroup then
            return nil
        end

        if AuraScan.AuraBelongsToGroup(unit, rawAura, "Buffs") then
            return "Buffs"
        end

        if AuraScan.AuraBelongsToGroup(unit, rawAura, "Debuffs") then
            return "Debuffs"
        end

        return nil
    end

    local function UpsertRawAura(rawAura, auraInstanceId)
        auraInstanceId = ToInstanceId(auraInstanceId or (type(rawAura) == "table" and (rawAura.auraInstanceId or rawAura.auraInstanceID)))
        if auraInstanceId <= 0 then
            return false
        end

        if AuraScan.GetAuraDataByInstanceID then
            local resolvedAura = AuraScan.GetAuraDataByInstanceID(unit, auraInstanceId)
            if type(resolvedAura) == "table" then
                rawAura = resolvedAura
            end
        end

        if type(rawAura) ~= "table" then
            if root.allById[auraInstanceId] ~= nil then
                root.allById[auraInstanceId] = nil
                return true
            end
            return false
        end

        local groupHint = ResolveGroupHint(rawAura)
        if AuraScan.NormalizeAura then
            local aura = AuraScan.NormalizeAura(rawAura, unit, groupHint, "EVENT")
            if aura then
                aura.sourceIndex = aura.sourceIndex or 0
                aura.sortKey = aura.sortKey or 0
                root.allById[auraInstanceId] = StampAura(aura, "EVENT")
                return true
            end
        end

        if root.allById[auraInstanceId] ~= nil then
            root.allById[auraInstanceId] = nil
            return true
        end
        return false
    end

    if type(updateInfo.addedAuras) == "table" then
        for _, rawAura in ipairs(updateInfo.addedAuras) do
            changed = UpsertRawAura(rawAura) or changed
        end
    end

    if type(updateInfo.updatedAuraInstanceIDs) == "table" then
        for _, auraInstanceId in ipairs(updateInfo.updatedAuraInstanceIDs) do
            changed = UpsertRawAura(nil, auraInstanceId) or changed
        end
    end

    if type(updateInfo.removedAuraInstanceIDs) == "table" then
        for _, auraInstanceId in ipairs(updateInfo.removedAuraInstanceIDs) do
            auraInstanceId = ToInstanceId(auraInstanceId)
            if auraInstanceId > 0 then
                if root.allById[auraInstanceId] ~= nil then
                    root.allById[auraInstanceId] = nil
                    changed = true
                end
            end
        end
    end

    rootState.boundUnit = unit
    rootState.phase = changed and "dirty_event" or "cache_ready"
    rootState.lastRefreshMode = "event"
    rootState.lastReason = "UNIT_AURA"
    rootState.pendingReconcile = AuraCache.HasUnknownEventAuras(frame)
    if changed then
        rootState.version = (tonumber(rootState.version) or 0) + 1
    end
    Log(frame, "cache-update", string.format("changed=%s pendingReconcile=%s", tostring(changed), tostring(rootState.pendingReconcile == true)))

    return changed
end

function AuraCache.ClearGroup(frame, groupKey)
    if not frame then
        return
    end

    local root = GetRoot(frame)
    root.rawByGroup[groupKey] = nil
    root.unkeyedByGroup[groupKey] = nil
    if root.groups then
        root.groups[groupKey] = nil
    end
    AuraCache.MarkGroupCleared(frame, groupKey, "clear-group")
end

function AuraCache.ClearAll(frame)
    if not frame then
        return
    end

    Log(frame, "cache-reset", "scope=all")
    frame.AuraCache = nil
end
