local _, FocalPoint = ...

FocalPoint.AuraEvents = FocalPoint.AuraEvents or {}
local AuraEvents = FocalPoint.AuraEvents
local State = FocalPoint.UnitFrameState or {}

local function Log(frame, action, details)
    if State.DebugLog then
        State.DebugLog(frame, "aura-" .. tostring(action or "?"), details)
    end
end

-- Event registration shim for the aura runtime.

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
            if updateInfo and updateInfo.isFullUpdate then
                BumpReconcileToken(owner)
                if AuraCache.ClearAll then
                    AuraCache.ClearAll(owner)
                end
                Log(owner, "event", "UNIT_AURA full")
                QueueAuraRefresh(owner, refreshFunc, 0, true)
                return
            end

            if AuraCache.ApplyUpdate then
                AuraCache.ApplyUpdate(owner, owner.unit, updateInfo)
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
