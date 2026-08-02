local _, FocalPoint = ...

FocalPoint.AuraRuntime = FocalPoint.AuraRuntime or {}
local AuraRuntime = FocalPoint.AuraRuntime
local State = FocalPoint.UnitFrameState or {}
local UnitUtils = FocalPoint.UnitFrameUtils or {}
local Preview = FocalPoint.UnitFramePreview or {}
local Demo = FocalPoint.UnitFrameDemoEnvironment or {}

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

local function RecordAuraDiagnostic(entry)
    local AuraDiagnostics = FocalPoint and FocalPoint.AuraDiagnostics or nil
    if AuraDiagnostics and AuraDiagnostics.Record then
        AuraDiagnostics.Record(entry)
    end
end

local function SyncFullAuraState(frame, unit)
    local AuraScan = FocalPoint.AuraScan or {}
    local AuraCache = FocalPoint.AuraCache or {}
    local BackendResolver = FocalPoint.AuraBackendResolver or {}

    if not (AuraScan.CollectUnitAuras and AuraCache.SyncFromScans) then
        return false
    end

    local scansByGroup = {}
    local hasSuccessfulScan = false
    local hasManagedGroup = false

    local buffsManaged = BackendResolver.CanUseManagedPlayerGroup and BackendResolver.CanUseManagedPlayerGroup(frame, "Buffs") == true
    if buffsManaged then
        hasManagedGroup = true
    else
        local buffsOk, buffs = AuraScan.CollectUnitAuras(unit, "Buffs")
        if buffsOk then
            scansByGroup.Buffs = buffs or {}
            hasSuccessfulScan = true
        end
    end

    local debuffsManaged = BackendResolver.CanUseManagedPlayerGroup and BackendResolver.CanUseManagedPlayerGroup(frame, "Debuffs") == true
    if debuffsManaged then
        hasManagedGroup = true
    else
        local debuffsOk, debuffs = AuraScan.CollectUnitAuras(unit, "Debuffs")
        if debuffsOk then
            scansByGroup.Debuffs = debuffs or {}
            hasSuccessfulScan = true
        end
    end

    if not hasSuccessfulScan then
        if hasManagedGroup then
            return true
        end

        RecordAuraDiagnostic({
            unit = unit,
            source = "UNITFRAME_REFRESH",
            scanClassification = "error",
            decision = "preserve",
        })
        return false
    end

    return AuraCache.SyncFromScans(frame, unit, scansByGroup) ~= false
end

local function Log(frame, action, details)
    if State.DebugLog then
        State.DebugLog(frame, "aura-" .. tostring(action or "?"), details)
    end
end

local function ApplyAuraResult(frame, groupKey, auraList, groupConfig)
    local AuraFilters = FocalPoint.AuraFilters or {}
    local AuraSorting = FocalPoint.AuraSorting or {}
    local AuraCache = FocalPoint.AuraCache or {}
    local AuraRenderer = FocalPoint.AuraRenderer or {}

    local allAuras = type(auraList) == "table" and auraList or {}
    local visibleAuras = AuraFilters.FilterAuras and AuraFilters.FilterAuras(allAuras, groupConfig, groupKey, frame) or allAuras
    local sortedAuras = AuraSorting.SortAuras and AuraSorting.SortAuras(visibleAuras, groupConfig, groupKey) or visibleAuras

    local cacheGroup = AuraCache.GetGroup and AuraCache.GetGroup(frame, groupKey)
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

function AuraRuntime.RefreshAuraGroup(frame, unit, groupKey)
    if not frame or not unit or not groupKey then
        return {}
    end

    local AuraCache = FocalPoint.AuraCache or {}
    local AuraRenderer = FocalPoint.AuraRenderer or {}
    local BackendResolver = FocalPoint.AuraBackendResolver or {}

    local groupConfig = GetGroupConfig(frame, groupKey)
    if not groupConfig or groupConfig.enabled == false then
        if BackendResolver.ClearManagedGroup then
            BackendResolver.ClearManagedGroup(frame, groupKey)
        end
        if AuraCache.ClearGroup then
            AuraCache.ClearGroup(frame, groupKey)
        end
        if AuraRenderer.ClearGroup then
            AuraRenderer.ClearGroup(frame, groupKey)
        end
        return {}
    end

    local previewAuras = Demo.GetAuras and Demo.GetAuras(frame, groupKey) or nil
    if previewAuras == nil then
        previewAuras = Preview.GetTestAuras and Preview.GetTestAuras(frame, groupKey) or nil
    end
    if previewAuras ~= nil then
        if BackendResolver.ClearManagedGroup then
            BackendResolver.ClearManagedGroup(frame, groupKey)
        end
        if Demo.TouchDebug then
            Demo.TouchDebug(frame, "auraRefresh")
        end
        return ApplyAuraResult(frame, groupKey, previewAuras, groupConfig)
    end

    if BackendResolver.RefreshManagedGroup and BackendResolver.RefreshManagedGroup(frame, groupKey, groupConfig) then
        if AuraRenderer.ClearGroup then
            AuraRenderer.ClearGroup(frame, groupKey)
        end
        return {}
    end

    local cacheGroup = AuraCache.GetGroup and AuraCache.GetGroup(frame, groupKey)
    local allAuras = AuraCache.GetAllAuras and AuraCache.GetAllAuras(frame, groupKey) or (cacheGroup and cacheGroup.allAuras) or {}
    return ApplyAuraResult(frame, groupKey, allAuras, groupConfig)
end

function AuraRuntime.RefreshAuras(frame, forceFullScan)
    if not frame or not frame.unit then
        return {}
    end

    if Preview.ShouldShowComponent and Preview.ShouldShowComponent("auras", { frame = frame }) == false then
        local AuraRenderer = FocalPoint.AuraRenderer or {}
        local BackendResolver = FocalPoint.AuraBackendResolver or {}
        if BackendResolver.ClearManagedGroup then
            BackendResolver.ClearManagedGroup(frame, "Buffs")
            BackendResolver.ClearManagedGroup(frame, "Debuffs")
        end
        if AuraRenderer.ClearGroup then
            AuraRenderer.ClearGroup(frame, "Buffs")
            AuraRenderer.ClearGroup(frame, "Debuffs")
        end
        return { Buffs = {}, Debuffs = {} }
    end

    if Demo.IsFrameInDemoMode and Demo.IsFrameInDemoMode(frame) then
        if Demo.IsAurasDisabled and Demo.IsAurasDisabled() then
            local AuraRenderer = FocalPoint.AuraRenderer or {}
            local BackendResolver = FocalPoint.AuraBackendResolver or {}
            if BackendResolver.ClearManagedGroup then
                BackendResolver.ClearManagedGroup(frame, "Buffs")
                BackendResolver.ClearManagedGroup(frame, "Debuffs")
            end
            if AuraRenderer.ClearGroup then
                AuraRenderer.ClearGroup(frame, "Buffs")
                AuraRenderer.ClearGroup(frame, "Debuffs")
            end
            return { Buffs = {}, Debuffs = {} }
        end
        if Demo.TouchDebug then
            Demo.TouchDebug(frame, "auraRefresh")
        end
        return {
            Buffs = AuraRuntime.RefreshAuraGroup(frame, frame.unit, "Buffs"),
            Debuffs = AuraRuntime.RefreshAuraGroup(frame, frame.unit, "Debuffs"),
        }
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
        AuraRenderer.Build(frame)
    end

    local BackendResolver = FocalPoint.AuraBackendResolver or {}
    if BackendResolver.EnsureManagedGroup then
        BackendResolver.EnsureManagedGroup(frame, "Buffs", GetGroupConfig(frame, "Buffs"))
        BackendResolver.EnsureManagedGroup(frame, "Debuffs", GetGroupConfig(frame, "Debuffs"))
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

    local BackendResolver = FocalPoint.AuraBackendResolver or {}
    if BackendResolver.ClearManagedGroup then
        BackendResolver.ClearManagedGroup(frame, "Buffs")
        BackendResolver.ClearManagedGroup(frame, "Debuffs")
    end

    Log(frame, "reset")
end
