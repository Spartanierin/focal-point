local _, ns = ...

ns.GUI = ns.GUI or {}
ns.GUI.Editor = ns.GUI.Editor or {}

local Presence = {}
ns.GUI.Editor.PresencePolicy = Presence
ns.EditorPresencePolicy = Presence

local PERSISTENT = "persistent"
local CONDITIONAL = "conditional"
Presence.PERSISTENT = PERSISTENT
Presence.CONDITIONAL = CONDITIONAL

local UnitFrameUtils = ns.UnitFrameUtils or {}

local PERSISTENT_TARGETS = {
    Frame = true,
    Unit = true,
    UnitRoot = true,
    HealthBar = true,
    PowerBar = true,
    NormalAbsorbBar = true,
    HealingAbsorbBar = true,
    ClassPowerBar = true,
}

local CONDITIONAL_TARGETS = {
    CastBar = true,
    AlternativePowerBar = true,
    Buffs = true,
    Debuffs = true,
    RaidTargetIcon = true,
    LeaderIcon = true,
    RoleIcon = true,
    CombatIndicator = true,
    RestingIndicator = true,
    ReadyCheckIndicator = true,
    ClassificationIndicator = true,
}

local function NormalizeUnitKey(unitKey)
    if type(unitKey) ~= "string" or unitKey == "" then
        return nil
    end
    if unitKey:match("^boss%d+$") then
        return "boss"
    end
    return unitKey
end

local function Result(presence, details)
    details = type(details) == "table" and details or {}
    details.presence = presence or PERSISTENT
    details.isPersistent = details.presence == PERSISTENT
    details.isConditional = details.presence == CONDITIONAL
    return details
end

local function GetUnitConfig(unitKey)
    if UnitFrameUtils and type(UnitFrameUtils.GetUnitDB) == "function" then
        return UnitFrameUtils.GetUnitDB(unitKey)
    end
    return nil
end

local function ResolveTargetPresence(targetKey)
    if type(targetKey) ~= "string" or targetKey == "" then
        return Result(PERSISTENT, {
            kind = "unit",
            targetKey = "Frame",
            fallback = true,
            reason = "missing-anchor",
        })
    end

    if PERSISTENT_TARGETS[targetKey] then
        return Result(PERSISTENT, {
            kind = "component",
            targetKey = targetKey,
            reason = "persistent-target",
        })
    end

    if CONDITIONAL_TARGETS[targetKey] then
        return Result(CONDITIONAL, {
            kind = "component",
            targetKey = targetKey,
            reason = "conditional-target",
        })
    end

    return Result(PERSISTENT, {
        kind = "unit",
        targetKey = "Frame",
        requestedTargetKey = targetKey,
        fallback = true,
        reason = "unknown-anchor",
    })
end

function Presence.ResolveTarget(targetKey)
    return ResolveTargetPresence(targetKey)
end

function Presence.ResolveText(unitKey, textKey)
    local normalizedUnit = NormalizeUnitKey(unitKey)
    local unitConfig = normalizedUnit and GetUnitConfig(normalizedUnit) or nil
    local texts = type(unitConfig) == "table" and unitConfig.Texts or nil
    local textConfig = type(texts) == "table" and texts[textKey] or nil
    local anchorTo = type(textConfig) == "table" and textConfig.anchorTo or nil
    local resolved = ResolveTargetPresence(anchorTo or "Frame")

    resolved.kind = "text"
    resolved.unit = normalizedUnit
    resolved.textKey = textKey
    resolved.anchorTo = anchorTo or "Frame"
    resolved.textFound = type(textConfig) == "table"
    if not resolved.textFound then
        resolved.fallback = true
        resolved.reason = "text-not-found"
    end
    return resolved
end

function Presence.ResolveObject(unitKey, objectRef)
    local normalizedUnit = NormalizeUnitKey(unitKey or (type(objectRef) == "table" and objectRef.unit))
    if type(objectRef) ~= "table" then
        return Result(PERSISTENT, {
            kind = "unit",
            unit = normalizedUnit,
            targetKey = "Frame",
            fallback = true,
            reason = "missing-object-ref",
        })
    end

    local kind = objectRef.kind
    if kind == "text" then
        return Presence.ResolveText(normalizedUnit, objectRef.textKey or objectRef.objectKey)
    end

    if kind == "aura" then
        local auraKey = objectRef.auraKey or objectRef.objectKey
        local resolved = ResolveTargetPresence(auraKey)
        resolved.kind = "aura"
        resolved.unit = normalizedUnit
        resolved.auraKey = auraKey
        return resolved
    end

    if kind == "indicator" then
        local indicatorKey = objectRef.indicatorKey or objectRef.objectKey
        local resolved = ResolveTargetPresence(indicatorKey)
        resolved.kind = "indicator"
        resolved.unit = normalizedUnit
        resolved.indicatorKey = indicatorKey
        return resolved
    end

    if kind == "decoration" then
        return Result(PERSISTENT, {
            kind = "decoration",
            unit = normalizedUnit,
            decorationId = objectRef.decorationId or objectRef.objectKey,
            targetKey = "Decoration",
            reason = "static-decoration",
        })
    end

    if kind == "bar" then
        local objectKey = objectRef.objectKey
        local resolved = ResolveTargetPresence(objectKey)
        resolved.kind = "bar"
        resolved.unit = normalizedUnit
        resolved.objectKey = objectKey
        return resolved
    end

    return Result(PERSISTENT, {
        kind = "unit",
        unit = normalizedUnit,
        targetKey = "Frame",
        reason = "unit-root",
    })
end

function Presence.ResolveSelectedObject()
    local objectSelection = ns.GUI
        and ns.GUI.Editor
        and ns.GUI.Editor.ObjectSelection
        or nil
    local selected = objectSelection and type(objectSelection.GetSelectedObject) == "function" and objectSelection.GetSelectedObject() or nil
    return Presence.ResolveObject(selected and selected.unit, selected)
end

return Presence
