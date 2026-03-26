local _, FocalPoint = ...

FocalPoint.AuraRuntime = FocalPoint.AuraRuntime or {}
local AuraRuntime = FocalPoint.AuraRuntime
local State = FocalPoint.UnitFrameState or {}
local UnitUtils = FocalPoint.UnitFrameUtils or {}

-- Public facade for the aura pipeline.

local function GetUnitConfig(unit)
    if UnitUtils.GetUnitDB then
        return UnitUtils.GetUnitDB(unit)
    end

    local db = FocalPoint.db
    if not db or not db.profile or not db.profile.Units then
        return nil
    end

    return db.profile.Units[unit]
end

local function GetGroupConfig(frame, groupKey)
    if not frame or not frame.unit or not groupKey then
        return nil
    end

    local unitConfig = frame.config or GetUnitConfig(frame.unit)
    if not unitConfig then
        return nil
    end

    return unitConfig[groupKey]
end

local function SyncFullAuraState(frame, unit)
    local AuraScan = FocalPoint.AuraScan or {}
    local AuraCache = FocalPoint.AuraCache or {}

    if not (AuraScan.CollectUnitAuras and AuraCache.SyncFromScans) then
        return
    end

    local scansByGroup = {
        Buffs = AuraScan.CollectUnitAuras(unit, "Buffs"),
        Debuffs = AuraScan.CollectUnitAuras(unit, "Debuffs"),
    }

    AuraCache.SyncFromScans(frame, unit, scansByGroup)
end

local function Log(frame, action, details)
    if State.DebugLog then
        State.DebugLog(frame, "aura-" .. tostring(action or "?"), details)
    end
end

function AuraRuntime.RefreshAuraGroup(frame, unit, groupKey)
    if not frame or not unit or not groupKey then
        return {}
    end

    local AuraFilters = FocalPoint.AuraFilters or {}
    local AuraSorting = FocalPoint.AuraSorting or {}
    local AuraCache = FocalPoint.AuraCache or {}
    local AuraRenderer = FocalPoint.AuraRenderer or {}

    local groupConfig = GetGroupConfig(frame, groupKey)
    if not groupConfig or groupConfig.enabled == false then
        if AuraCache.ClearGroup then
            AuraCache.ClearGroup(frame, groupKey)
        end
        if AuraRenderer.ClearGroup then
            AuraRenderer.ClearGroup(frame, groupKey)
        end
        return {}
    end

    local cacheGroup = AuraCache.GetGroup and AuraCache.GetGroup(frame, groupKey)
    local allAuras = AuraCache.GetAllAuras and AuraCache.GetAllAuras(frame, groupKey) or (cacheGroup and cacheGroup.allAuras) or {}

    local visibleAuras = AuraFilters.FilterAuras and AuraFilters.FilterAuras(allAuras, groupConfig, groupKey, frame) or allAuras
    local sortedAuras = AuraSorting.SortAuras and AuraSorting.SortAuras(visibleAuras, groupConfig, groupKey) or visibleAuras

    cacheGroup = AuraCache.GetGroup and AuraCache.GetGroup(frame, groupKey)
    if cacheGroup then
        cacheGroup.allAuras = allAuras
        cacheGroup.displayAuras = allAuras
        cacheGroup.visibleAuras = visibleAuras
        cacheGroup.activeAuras = visibleAuras
        cacheGroup.sortedAuras = sortedAuras
    end

    if AuraRenderer.RenderGroup then
        AuraRenderer.RenderGroup(frame, groupKey, sortedAuras, groupConfig)
    end

    if AuraCache.MarkRefreshApplied then
        AuraCache.MarkRefreshApplied(frame, groupKey, {
            raw = type(allAuras) == "table" and #allAuras or 0,
            visible = type(visibleAuras) == "table" and #visibleAuras or 0,
            sorted = type(sortedAuras) == "table" and #sortedAuras or 0,
            rendered = type(sortedAuras) == "table" and #sortedAuras or 0,
        })
    end

    return sortedAuras
end

function AuraRuntime.RefreshAuras(frame, forceFullScan)
    if not frame or not frame.unit then
        return {}
    end

    local AuraCache = FocalPoint.AuraCache or {}
    local rootCache = frame.AuraCache
    if AuraCache.MarkRefreshStart then
        AuraCache.MarkRefreshStart(frame, frame.unit, forceFullScan and "fullscan" or "refresh")
    end

    if forceFullScan or not rootCache or not rootCache.allById or not next(rootCache.allById) then
        SyncFullAuraState(frame, frame.unit)
    elseif AuraCache.ReconcileEventAuras then
        AuraCache.ReconcileEventAuras(frame, frame.unit)
    end

    local result = {
        Buffs = AuraRuntime.RefreshAuraGroup(frame, frame.unit, "Buffs"),
        Debuffs = AuraRuntime.RefreshAuraGroup(frame, frame.unit, "Debuffs"),
    }

    Log(frame, "refresh-applied", string.format("mode=%s buffs=%d debuffs=%d", tostring(forceFullScan and "fullscan" or "refresh"), #(result.Buffs or {}), #(result.Debuffs or {})))
    return result
end

function AuraRuntime.BuildAuraContainers(frame)
    local AuraRenderer = FocalPoint.AuraRenderer or {}
    if AuraRenderer.Build then
        return AuraRenderer.Build(frame)
    end

    return nil
end

function AuraRuntime.RegisterAuraEvents(frame)
    local AuraEvents = FocalPoint.AuraEvents or {}
    if AuraEvents.Register then
        return AuraEvents.Register(frame, AuraRuntime.RefreshAuras)
    end

    return nil
end

function AuraRuntime.Reset(frame)
    if not frame then
        return
    end

    local AuraCache = FocalPoint.AuraCache or {}
    local AuraRenderer = FocalPoint.AuraRenderer or {}

    if AuraCache.ClearAll then
        AuraCache.ClearAll(frame)
    end

    if AuraRenderer.ClearGroup then
        AuraRenderer.ClearGroup(frame, "Buffs")
        AuraRenderer.ClearGroup(frame, "Debuffs")
    end

    Log(frame, "reset")
end
