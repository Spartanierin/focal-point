local _, ns = ...

ns.GUI = ns.GUI or {}
ns.GUI.Editor = ns.GUI.Editor or {}
ns.GUI.Editor.Composition = ns.GUI.Editor.Composition or {}

local Presence = {}
ns.GUI.Editor.Composition.Presence = Presence
ns.CompositionPresence = Presence

local Ownership = ns.GUI.Editor.Composition.Ownership or ns.CompositionOwnership

local PRESENT_FIELD_BY_BAR = {
    PowerBar = "powerBarPresent",
    CastBar = "castBarPresent",
    ClassPowerBar = "classPowerBarPresent",
    AlternativePowerBar = "alternativePowerBarPresent",
    NormalAbsorbBar = "normalAbsorbBarPresent",
    HealingAbsorbBar = "healingAbsorbBarPresent",
}

local CORE_BARS = {
    HealthBar = true,
}

local AURA_KEYS = {
    Buffs = true,
    Debuffs = true,
}

local INDICATOR_KEYS = {
    Portrait = true,
    RaidTargetIcon = true,
    LeaderIcon = true,
    RoleIcon = true,
    CombatIndicator = true,
    RestingIndicator = true,
    ReadyCheckIndicator = true,
    ClassificationIndicator = true,
}

local function NormalizeUnitKey(unit)
    if type(unit) ~= "string" or unit == "" then
        return nil
    end
    if unit:match("^boss%d+$") then
        return "boss"
    end
    return unit
end

local function GetObjectKey(objectRef)
    if type(objectRef) ~= "table" then
        return nil
    end
    return objectRef.objectKey
        or objectRef.barKey
        or objectRef.textKey
        or objectRef.auraKey
        or objectRef.indicatorKey
        or objectRef.decorationId
end

local function GetTextKey(objectRef)
    if type(objectRef) ~= "table" then
        return nil
    end
    return objectRef.textKey or objectRef.objectKey
end

local function GetAuraKey(objectRef)
    if type(objectRef) ~= "table" then
        return nil
    end
    return objectRef.auraKey or objectRef.objectKey
end

local function GetIndicatorKey(objectRef)
    if type(objectRef) ~= "table" then
        return nil
    end
    return objectRef.indicatorKey or objectRef.objectKey
end

local function GetDecorationId(objectRef)
    if type(objectRef) ~= "table" then
        return nil
    end
    return objectRef.decorationId or objectRef.objectKey
end

local function HasDecoration(unitConfig, decorationId)
    local decorations = type(unitConfig) == "table" and unitConfig.decorations or nil
    if type(decorations) ~= "table" or type(decorationId) ~= "string" or decorationId == "" then
        return false
    end
    for _, decoration in ipairs(decorations) do
        if type(decoration) == "table" and decoration.id == decorationId then
            return true
        end
    end
    return false
end

local function IsBarOwnPresent(unitConfig, barKey)
    if CORE_BARS[barKey] then
        return true
    end

    local presentField = PRESENT_FIELD_BY_BAR[barKey]
    return type(presentField) == "string"
        and type(unitConfig) == "table"
        and unitConfig[presentField] == true
end

local function IsTableComponentPresent(config)
    return type(config) == "table" and config.present == true
end

function Presence.IsOwnPresent(unitConfig, objectRef)
    if type(objectRef) ~= "table" then
        return false
    end

    local kind = objectRef.kind
    if kind == "unit" then
        return NormalizeUnitKey(objectRef.unit) ~= nil
    end

    if type(unitConfig) ~= "table" then
        return false
    end

    if kind == "bar" then
        return IsBarOwnPresent(unitConfig, GetObjectKey(objectRef))
    end

    if kind == "text" then
        local textKey = GetTextKey(objectRef)
        local texts = unitConfig.Texts
        return type(textKey) == "string" and textKey ~= "" and type(texts) == "table" and type(texts[textKey]) == "table"
    end

    if kind == "decoration" then
        return HasDecoration(unitConfig, GetDecorationId(objectRef))
    end

    if kind == "aura" then
        local auraKey = GetAuraKey(objectRef)
        return AURA_KEYS[auraKey] == true and IsTableComponentPresent(unitConfig[auraKey])
    end

    if kind == "indicator" then
        local indicatorKey = GetIndicatorKey(objectRef)
        return INDICATOR_KEYS[indicatorKey] == true and IsTableComponentPresent(unitConfig[indicatorKey])
    end

    return false
end

function Presence.IsPresent(unitConfig, objectRef)
    if type(objectRef) ~= "table" then
        return false
    end

    if objectRef.kind == "unit" then
        return Presence.IsOwnPresent(unitConfig, objectRef)
    end

    if type(unitConfig) ~= "table" then
        return false
    end

    local current = objectRef
    local guard = 0
    while guard < 32 do
        guard = guard + 1
        if not Presence.IsOwnPresent(unitConfig, current) then
            return false
        end

        if not (Ownership and type(Ownership.ResolveParent) == "function") then
            return current.kind == "unit"
        end

        local parent = Ownership.ResolveParent(unitConfig, current)
        if not parent then
            return true
        end
        current = parent
    end

    return false
end

return Presence
