local _, FocalPoint = ...

FocalPoint.UnitFramePresence = FocalPoint.UnitFramePresence or {}
local Presence = FocalPoint.UnitFramePresence

local Utils = FocalPoint.UnitFrameUtils or {}
local IsSafeTrue = Utils.IsSafeTrue

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
        if type(guid) == "string" and guid ~= "" and not (issecretvalue and issecretvalue(guid)) then
            return true
        end
    end

    if UnitName then
        local name = UnitName(unit)
        if type(name) == "string" and name ~= "" and not (issecretvalue and issecretvalue(name)) then
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
        snapshot.guid = type(guid) == "string" and guid ~= "" and not (issecretvalue and issecretvalue(guid))
    end

    if UnitName then
        local name = UnitName(unit)
        snapshot.name = type(name) == "string" and name ~= "" and not (issecretvalue and issecretvalue(name))
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
    if frame._targetDebugLastAt and (now - frame._targetDebugLastAt) < 0.20 then
        return
    end

    frame._targetDebugLastAt = now
    FocalPoint:Debug(message)
end

function Presence.IsPreviewModeEnabled()
    return FocalPoint.guiTestModeEnabled or FocalPoint.framesUnlocked
end
