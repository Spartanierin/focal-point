local _, FocalPoint = ...

FocalPoint.UnitFramePresence = FocalPoint.UnitFramePresence or {}
local Presence = FocalPoint.UnitFramePresence

local Utils = FocalPoint.UnitFrameUtils or {}
local IsSafeTrue = Utils.IsSafeTrue

local function GetDemoEnvironment()
    return FocalPoint.UnitFrameDemoEnvironment
end

-- Presence helpers are intentionally lightweight.
-- They answer "does this unit appear to exist right now?" and support
-- target-specific debug output plus preview/test mode checks.

function Presence.DoesUnitSeemPresent(unit)
    if not unit then
        return false
    end

    if UnitExists and IsSafeTrue(UnitExists(unit)) then
        return true
    end

    if UnitGUID then
        local guid = UnitGUID(unit)
        local okGuid, hasGuid = pcall(function()
            return type(guid) == "string" and guid ~= "" and not (issecretvalue and issecretvalue(guid))
        end)
        if okGuid and hasGuid then
            return true
        end
    end

    if UnitName then
        local name = UnitName(unit)
        local okName, hasName = pcall(function()
            return type(name) == "string" and name ~= "" and not (issecretvalue and issecretvalue(name))
        end)
        if okName and hasName then
            return true
        end
    end

    if UnitIsVisible and IsSafeTrue(UnitIsVisible(unit)) then
        return true
    end

    return false
end

function Presence.GetTargetPresenceSnapshot(unit)
    local snapshot = {
        exists = false,
        guid = false,
        name = false,
        visible = false,
        dead = false,
    }

    if not unit then
        return snapshot
    end

    if UnitExists then
        snapshot.exists = IsSafeTrue(UnitExists(unit))
    end

    if UnitGUID then
        local guid = UnitGUID(unit)
        local okGuid, hasGuid = pcall(function()
            return type(guid) == "string" and guid ~= "" and not (issecretvalue and issecretvalue(guid))
        end)
        snapshot.guid = okGuid and hasGuid or false
    end

    if UnitName then
        local name = UnitName(unit)
        local okName, hasName = pcall(function()
            return type(name) == "string" and name ~= "" and not (issecretvalue and issecretvalue(name))
        end)
        snapshot.name = okName and hasName or false
    end

    if UnitIsVisible then
        snapshot.visible = IsSafeTrue(UnitIsVisible(unit))
    end

    if UnitIsDeadOrGhost then
        snapshot.dead = IsSafeTrue(UnitIsDeadOrGhost(unit))
    end

    return snapshot
end

function Presence.MaybeDebugTarget(frame, message)
    if not (FocalPoint and FocalPoint.debugTargetVisibility and frame and frame.unit == "target" and FocalPoint.Debug) then
        return
    end

    local now = GetTime and GetTime() or 0
    if frame._targetDebugLastMessage == message
        and frame._targetDebugLastAt
        and (now - frame._targetDebugLastAt) < 3.0
    then
        return
    end

    if frame._targetDebugLastAt and (now - frame._targetDebugLastAt) < 0.50 then
        return
    end

    frame._targetDebugLastMessage = message
    frame._targetDebugLastAt = now
    FocalPoint:Debug(message)
end

function Presence.ForceDebugTarget(frame, message, key, cooldown)
    if not (FocalPoint and FocalPoint.debugTargetVisibility and frame and frame.unit == "target" and FocalPoint.Debug) then
        return
    end

    local now = GetTime and GetTime() or 0
    key = key or "__force"
    cooldown = tonumber(cooldown) or 0

    frame._targetDebugByKey = frame._targetDebugByKey or {}
    local lastAt = frame._targetDebugByKey[key]
    if lastAt and (now - lastAt) < cooldown then
        return
    end

    frame._targetDebugByKey[key] = now
    frame._targetDebugLastAt = now
    FocalPoint:Debug(message)
end

function Presence.IsPreviewModeEnabled()
    local demo = GetDemoEnvironment()
    return demo and demo.IsDemoActive and demo.IsDemoActive() or false
end

function Presence.ShouldForceFrameVisible(frame)
    local demo = GetDemoEnvironment()
    return demo and demo.ShouldForceFrameVisible and demo.ShouldForceFrameVisible(frame) or false
end
