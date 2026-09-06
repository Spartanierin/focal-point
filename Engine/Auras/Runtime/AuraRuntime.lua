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

    return nil
end

local function GetGroupConfig(frame, groupKey)
    if not frame or not frame._fpUnit or not groupKey then
        return nil
    end

    local unitConfig = frame.config or GetUnitConfig(frame._fpUnit)
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

local function GetSelectedObject()
    local objectSelection = FocalPoint.GUI
        and FocalPoint.GUI.Editor
        and FocalPoint.GUI.Editor.ObjectSelection
        or nil
    return objectSelection and objectSelection.GetSelectedObject and objectSelection.GetSelectedObject() or nil
end

local function IsEditorActive()
    return FocalPoint
        and FocalPoint.framesUnlocked == true
        and FocalPoint.IsEditorActive
        and FocalPoint:IsEditorActive()
        or false
end

local function IsSameSelectionUnit(selectedUnit, frameUnit)
    if type(selectedUnit) ~= "string" or type(frameUnit) ~= "string" then
        return false
    end
    if selectedUnit == frameUnit then
        return true
    end
    return selectedUnit == "boss" and frameUnit:match("^boss%d+$") ~= nil
end

local function IsLocalAuraPreviewSelected(frame, unit, groupKey)
    if groupKey ~= "Buffs" and groupKey ~= "Debuffs" then
        return false
    end
    if not (FocalPoint and FocalPoint.framesUnlocked == true and FocalPoint.guiTestModeEnabled ~= true) then
        return false
    end
    if not (FocalPoint.IsEditorActive and FocalPoint:IsEditorActive()) then
        return false
    end

    local selected = GetSelectedObject()
    return type(selected) == "table"
        and selected.kind == "aura"
        and selected.auraKey == groupKey
        and IsSameSelectionUnit(selected.unit, unit or (frame and frame._fpUnit))
end

local function CollectLiveAurasForRefresh(frame, unit, groupKey)
    local AuraScan = FocalPoint.AuraScan or {}
    if AuraScan.CollectUnitAuras then
        local ok, auras = AuraScan.CollectUnitAuras(unit, groupKey)
        if ok == true and type(auras) == "table" then
            return auras
        end
    end

    local AuraCache = FocalPoint.AuraCache or {}
    return AuraCache.GetAllAuras and AuraCache.GetAllAuras(frame, groupKey) or nil
end

local function ResolveLocalAuraPreview(frame, unit, groupKey)
    if not IsLocalAuraPreviewSelected(frame, unit, groupKey) then
        return nil
    end
    if Demo.IsAurasDisabled and Demo.IsAurasDisabled() then
        return nil
    end

    return Demo.GetAuraPreviewFixtures and Demo.GetAuraPreviewFixtures(frame, groupKey) or nil
end

local function ShouldUseManagedLiveRender(frame, groupKey, liveResult)
    if not (frame and frame._fpUnit == "player" and groupKey == "Buffs") then
        return true
    end
    if FocalPoint and FocalPoint.guiTestModeEnabled == true then
        return true
    end
    if not IsEditorActive() then
        return true
    end

    local sortedAuras = type(liveResult) == "table" and liveResult.sortedAuras or nil
    if type(sortedAuras) ~= "table" or #sortedAuras == 0 then
        return false
    end

    -- While selected, player buffs need the same state-driven editor surface as other aura groups.
    return not IsLocalAuraPreviewSelected(frame, frame._fpUnit, groupKey)
end

local function PrepareAuraResult(frame, groupKey, auraList, groupConfig)
    local AuraFilters = FocalPoint.AuraFilters or {}
    local AuraSorting = FocalPoint.AuraSorting or {}

    local allAuras = type(auraList) == "table" and auraList or {}
    local visibleAuras = AuraFilters.FilterAuras and AuraFilters.FilterAuras(allAuras, groupConfig, groupKey, frame) or allAuras
    local sortedAuras = AuraSorting.SortAuras and AuraSorting.SortAuras(visibleAuras, groupConfig, groupKey) or visibleAuras

    return {
        frame = frame,
        groupKey = groupKey,
        groupConfig = groupConfig,
        allAuras = allAuras,
        visibleAuras = visibleAuras,
        sortedAuras = sortedAuras,
    }
end

local function ApplyPreparedAuraResult(prepared)
    local AuraCache = FocalPoint.AuraCache or {}
    local AuraRenderer = FocalPoint.AuraRenderer or {}
    local BackendResolver = FocalPoint.AuraBackendResolver or {}
    prepared = type(prepared) == "table" and prepared or {}
    local frame = prepared.frame
    local groupKey = prepared.groupKey
    local groupConfig = prepared.groupConfig
    local allAuras = prepared.allAuras or {}
    local visibleAuras = prepared.visibleAuras or {}
    local sortedAuras = prepared.sortedAuras or {}

    local cacheGroup = AuraCache.GetGroup and AuraCache.GetGroup(frame, groupKey)
    if cacheGroup then
        cacheGroup.allAuras = allAuras
        cacheGroup.displayAuras = allAuras
        cacheGroup.visibleAuras = visibleAuras
        cacheGroup.activeAuras = visibleAuras
        cacheGroup.sortedAuras = sortedAuras
    end

    if BackendResolver.ClearManagedGroup then
        BackendResolver.ClearManagedGroup(frame, groupKey)
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
    if not groupConfig or groupConfig.present ~= true or groupConfig.enabled == false then
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

    local liveAuras = nil
    local liveResult = nil

    local function EnsureLiveResult()
        if liveResult then
            return liveResult
        end
        liveAuras = CollectLiveAurasForRefresh(frame, unit, groupKey)
        liveResult = PrepareAuraResult(frame, groupKey, liveAuras, groupConfig)
        return liveResult
    end

    if FocalPoint and FocalPoint.guiTestModeEnabled == true then
        local simulatedAuras = Demo.GetAuras and Demo.GetAuras(frame, groupKey) or nil
        if simulatedAuras == nil then
            simulatedAuras = Preview.GetTestAuras and Preview.GetTestAuras(frame, groupKey) or nil
        end
        if simulatedAuras ~= nil then
            local preparedPreview = PrepareAuraResult(frame, groupKey, simulatedAuras, groupConfig)
            if Demo.TouchDebug then
                Demo.TouchDebug(frame, "auraRefresh")
            end
            return ApplyPreparedAuraResult(preparedPreview)
        end
    end

    local localPreviewAuras = ResolveLocalAuraPreview(frame, unit, groupKey)
    if localPreviewAuras ~= nil then
        local preparedPreview = PrepareAuraResult(frame, groupKey, localPreviewAuras, groupConfig)
        if Demo.TouchDebug then
            Demo.TouchDebug(frame, "auraRefresh")
        end
        return ApplyPreparedAuraResult(preparedPreview)
    end

    EnsureLiveResult()
    if type(liveResult.sortedAuras) == "table" and #liveResult.sortedAuras > 0 then
        if ShouldUseManagedLiveRender(frame, groupKey, liveResult)
            and BackendResolver.RefreshManagedGroup
            and BackendResolver.RefreshManagedGroup(frame, groupKey, groupConfig)
        then
            if AuraRenderer.ClearGroup then
                AuraRenderer.ClearGroup(frame, groupKey)
            end
            return {}
        end
        return ApplyPreparedAuraResult(liveResult)
    end

    return ApplyPreparedAuraResult(liveResult)
end

function AuraRuntime.RefreshAuras(frame, forceFullScan)
    if not frame or not frame._fpUnit then
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
            Buffs = AuraRuntime.RefreshAuraGroup(frame, frame._fpUnit, "Buffs"),
            Debuffs = AuraRuntime.RefreshAuraGroup(frame, frame._fpUnit, "Debuffs"),
        }
    end

    local AuraCache = FocalPoint.AuraCache or {}
    local rootCache = frame.AuraCache
    if AuraCache.MarkRefreshStart then
        AuraCache.MarkRefreshStart(frame, frame._fpUnit, forceFullScan and "fullscan" or "refresh")
    end

    if forceFullScan or not rootCache or not rootCache.allById or not next(rootCache.allById) then
        SyncFullAuraState(frame, frame._fpUnit)
    elseif AuraCache.ReconcileEventAuras then
        AuraCache.ReconcileEventAuras(frame, frame._fpUnit)
    end

    local result = {
        Buffs = AuraRuntime.RefreshAuraGroup(frame, frame._fpUnit, "Buffs"),
        Debuffs = AuraRuntime.RefreshAuraGroup(frame, frame._fpUnit, "Debuffs"),
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
