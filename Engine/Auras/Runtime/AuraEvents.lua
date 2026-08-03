local _, FocalPoint = ...

FocalPoint.AuraEvents = FocalPoint.AuraEvents or {}
local AuraEvents = FocalPoint.AuraEvents
local State = FocalPoint.UnitFrameState or {}
local UnitUtils = FocalPoint.UnitFrameUtils or {}
local IsSecretValue = UnitUtils.IsSecretValue

local function Log(frame, action, details)
    if State.DebugLog then
        State.DebugLog(frame, "aura-" .. tostring(action or "?"), details)
    end
end

-- Event registration shim for the aura runtime.

local function IsSecret(value)
    return IsSecretValue and IsSecretValue(value) or false
end

local function ClassifyAuraUpdateInfo(updateInfo)
    if IsSecret(updateInfo) then
        return "secret"
    end

    if updateInfo == nil then
        return "incremental", nil
    end

    if type(updateInfo) ~= "table" then
        return "invalid"
    end

    local isFullUpdate = updateInfo.isFullUpdate
    if IsSecret(isFullUpdate) then
        return "secret"
    end

    if type(isFullUpdate) == "boolean" and isFullUpdate == true then
        return "full", updateInfo
    end

    local addedAuras = updateInfo.addedAuras
    if IsSecret(addedAuras) then
        return "secret"
    end

    local updatedAuraInstanceIDs = updateInfo.updatedAuraInstanceIDs
    if IsSecret(updatedAuraInstanceIDs) then
        return "secret"
    end

    local removedAuraInstanceIDs = updateInfo.removedAuraInstanceIDs
    if IsSecret(removedAuraInstanceIDs) then
        return "secret"
    end

    return "incremental", updateInfo
end

local function CountSafeList(list)
    if type(list) ~= "table" then
        return 0
    end

    return #list
end

local function RecordAuraDiagnostic(entry)
    local AuraDiagnostics = FocalPoint and FocalPoint.AuraDiagnostics or nil
    if AuraDiagnostics and AuraDiagnostics.Record then
        AuraDiagnostics.Record(entry)
    end
end

local function QueueAuraRefresh(owner, refreshFunc, delay, forceFullScan)
    if not owner then
        return
    end

    delay = tonumber(delay) or 0
    if State.QueueRefresh then
        State.QueueRefresh(owner, "auras", "auras", {
            forceAuraFullScan = forceFullScan == true,
        }, delay)
        return
    end

    if type(refreshFunc) ~= "function" then
        return
    end

    C_Timer.After(delay, function()
        if owner and owner.config then
            refreshFunc(owner, forceFullScan)
        end
    end)
end

local function BumpReconcileToken(owner)
    if not owner then
        return 0
    end

    owner._auraReconcileToken = (owner._auraReconcileToken or 0) + 1
    return owner._auraReconcileToken
end

local function QueueUnknownAuraReconcile(owner, refreshFunc)
    if not owner or type(refreshFunc) ~= "function" then
        return
    end

    local AuraCache = FocalPoint.AuraCache or {}
    if not (AuraCache.HasUnknownEventAuras and AuraCache.HasUnknownEventAuras(owner)) then
        return
    end

    if AuraCache.MarkReconcileQueued then
        AuraCache.MarkReconcileQueued(owner, "unknown-event-auras")
    end

    local token = BumpReconcileToken(owner)
    local delays = { 0.05, 0.15, 0.30 }

    for _, delay in ipairs(delays) do
        C_Timer.After(delay, function()
            local lifecycle = FocalPoint and FocalPoint.UnitFrameLifecycleDiagnostics or nil
            if lifecycle and lifecycle.RecordAuraReconcile then
                lifecycle.RecordAuraReconcile(owner, "aura-reconcile-fired", "unknown-event-auras")
            end
            if not owner or not owner.config or owner._auraReconcileToken ~= token then
                return
            end

            local currentAuraCache = FocalPoint.AuraCache or {}
            if currentAuraCache.HasUnknownEventAuras and currentAuraCache.HasUnknownEventAuras(owner) then
                QueueAuraRefresh(owner, refreshFunc, 0, false)
            end
        end)
    end
end

local function RefreshManagedTargetTargetGroups(owner)
    if not (owner and owner.unit == "targettarget") then
        return false
    end

    local BackendResolver = FocalPoint and FocalPoint.AuraBackendResolver or nil
    if not (BackendResolver and BackendResolver.UpdateManagedGroupAuras) then
        return false
    end

    local updated = false
    updated = BackendResolver.UpdateManagedGroupAuras(owner, "Buffs") == true or updated
    updated = BackendResolver.UpdateManagedGroupAuras(owner, "Debuffs") == true or updated
    return updated
end

function AuraEvents.Register(frame, refreshFunc)
    if not frame or frame.AuraEventFrame then
        return
    end

    local eventFrame = CreateFrame("Frame", nil, frame)
    eventFrame.owner = frame

    eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    eventFrame:RegisterEvent("UNIT_AURA")

    if frame.unit == "target" then
        eventFrame:RegisterEvent("PLAYER_TARGET_CHANGED")
    elseif frame.unit == "targettarget" then
        eventFrame:RegisterEvent("PLAYER_TARGET_CHANGED")
        eventFrame:RegisterEvent("UNIT_TARGET")
    elseif frame.unit == "focustarget" then
        eventFrame:RegisterEvent("PLAYER_FOCUS_CHANGED")
        eventFrame:RegisterEvent("UNIT_TARGET")
    elseif frame.unit == "focus" then
        eventFrame:RegisterEvent("PLAYER_FOCUS_CHANGED")
    elseif frame.unit == "pet" then
        eventFrame:RegisterEvent("UNIT_PET")
    end

    eventFrame:SetScript("OnEvent", function(_, event, unit, updateInfo)
        local owner = eventFrame.owner
        if not owner or not owner.config then
            return
        end

        if event == "UNIT_AURA" and unit ~= owner.unit then
            return
        end

        if event == "UNIT_PET" and unit ~= "player" then
            return
        end

        if event == "UNIT_TARGET" then
            local targetOk = owner.unit == "targettarget" and unit == "target"
            local focusOk = owner.unit == "focustarget" and unit == "focus"
            if not targetOk and not focusOk then
                return
            end
            if targetOk then
                RefreshManagedTargetTargetGroups(owner)
            end
        end

        if event == "PLAYER_TARGET_CHANGED" and owner.unit == "targettarget" then
            RefreshManagedTargetTargetGroups(owner)
        end

        if event == "PLAYER_ENTERING_WORLD" then
            local AuraCache = FocalPoint.AuraCache or {}
            BumpReconcileToken(owner)
            if AuraCache.ClearAll then
                AuraCache.ClearAll(owner)
            end
            Log(owner, "event", "PLAYER_ENTERING_WORLD fullscan")
            QueueAuraRefresh(owner, refreshFunc, 0, true)
            QueueAuraRefresh(owner, refreshFunc, 0.15, true)
            return
        end

        if event == "UNIT_AURA" then
            local AuraCache = FocalPoint.AuraCache or {}
            local auraUpdateKind, safeUpdateInfo = ClassifyAuraUpdateInfo(updateInfo)
            local payloadClassification = auraUpdateKind == "full" and "normal_full"
                or auraUpdateKind == "incremental" and "normal_incremental"
                or auraUpdateKind

            if auraUpdateKind == "secret" or auraUpdateKind == "invalid" then
                RecordAuraDiagnostic({
                    unit = owner.unit,
                    source = "UNIT_AURA",
                    payloadClassification = payloadClassification,
                    scanClassification = "not_attempted",
                    decision = "preserve",
                })
                Log(owner, "event", "UNIT_AURA preserve")
                return
            end

            if auraUpdateKind == "full" then
                RecordAuraDiagnostic({
                    unit = owner.unit,
                    source = "UNIT_AURA",
                    payloadClassification = payloadClassification,
                    scanClassification = "not_attempted",
                    decision = "full_commit",
                })
                BumpReconcileToken(owner)
                if AuraCache.ClearAll then
                    AuraCache.ClearAll(owner)
                end
                Log(owner, "event", "UNIT_AURA full")
                QueueAuraRefresh(owner, refreshFunc, 0, true)
                return
            end

            RecordAuraDiagnostic({
                unit = owner.unit,
                source = "UNIT_AURA",
                payloadClassification = payloadClassification,
                scanClassification = "not_attempted",
                decision = "incremental_commit",
                safeAddedCount = safeUpdateInfo and CountSafeList(safeUpdateInfo.addedAuras) or 0,
                safeUpdatedCount = safeUpdateInfo and CountSafeList(safeUpdateInfo.updatedAuraInstanceIDs) or 0,
                safeRemovedCount = safeUpdateInfo and CountSafeList(safeUpdateInfo.removedAuraInstanceIDs) or 0,
            })

            if AuraCache.ApplyUpdate then
                AuraCache.ApplyUpdate(owner, owner.unit, safeUpdateInfo)
            end

            Log(owner, "event", "UNIT_AURA incremental")
            QueueAuraRefresh(owner, refreshFunc, 0, false)
            QueueUnknownAuraReconcile(owner, refreshFunc)

            return
        end

        if type(refreshFunc) == "function" then
            local AuraCache = FocalPoint.AuraCache or {}
            BumpReconcileToken(owner)
            if AuraCache.ClearAll then
                AuraCache.ClearAll(owner)
            end
            Log(owner, "event", string.format("%s fullscan", tostring(event)))
            QueueAuraRefresh(owner, refreshFunc, 0, true)
        end
    end)

    frame.AuraEventFrame = eventFrame

    local AuraCache = FocalPoint.AuraCache or {}
    BumpReconcileToken(frame)
    if AuraCache.ClearAll then
        AuraCache.ClearAll(frame)
    end
    QueueAuraRefresh(frame, refreshFunc, 0, true)
    QueueAuraRefresh(frame, refreshFunc, 0.15, true)
end
