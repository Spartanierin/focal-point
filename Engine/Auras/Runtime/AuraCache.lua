local _, FocalPoint = ...

FocalPoint.AuraCache = FocalPoint.AuraCache or {}
local AuraCache = FocalPoint.AuraCache

-- Owns the authoritative aura cache for a unit frame. Raw event/fullscan data
-- lands here first; Buff/Debuff lists are derived afterwards.

local GROUP_KEYS = { "Buffs", "Debuffs" }

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
    return frame.AuraCache
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
    return group
end

function AuraCache.SyncFromScans(frame, unit, scansByGroup)
    if not frame or not unit or type(scansByGroup) ~= "table" then
        return {}
    end

    local AuraScan = FocalPoint.AuraScan or {}
    local root = GetRoot(frame)
    local scannedById = {}
    local now = (GetTime and GetTime()) or 0

    for _, groupKey in ipairs(GROUP_KEYS) do
        local rawAuras = type(scansByGroup[groupKey]) == "table" and scansByGroup[groupKey] or {}
        local group = AuraCache.GetGroup(frame, groupKey)
        local unkeyed = {}

        group.rawAuras = rawAuras
        root.rawByGroup[groupKey] = rawAuras

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
            root.allById[auraInstanceId] = nil
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

        root.allById[auraInstanceId] = nil
        return false
    end

    if type(updateInfo.addedAuras) == "table" then
        for _, rawAura in ipairs(updateInfo.addedAuras) do
            UpsertRawAura(rawAura)
        end
    end

    if type(updateInfo.updatedAuraInstanceIDs) == "table" then
        for _, auraInstanceId in ipairs(updateInfo.updatedAuraInstanceIDs) do
            UpsertRawAura(nil, auraInstanceId)
        end
    end

    if type(updateInfo.removedAuraInstanceIDs) == "table" then
        for _, auraInstanceId in ipairs(updateInfo.removedAuraInstanceIDs) do
            auraInstanceId = ToInstanceId(auraInstanceId)
            if auraInstanceId > 0 then
                root.allById[auraInstanceId] = nil
            end
        end
    end

    return true
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
end

function AuraCache.ClearAll(frame)
    if not frame then
        return
    end

    frame.AuraCache = nil
end
