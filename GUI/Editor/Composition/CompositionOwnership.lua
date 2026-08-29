local _, ns = ...

ns.GUI = ns.GUI or {}
ns.GUI.Editor = ns.GUI.Editor or {}
ns.GUI.Editor.Composition = ns.GUI.Editor.Composition or {}

local Ownership = {}
ns.GUI.Editor.Composition.Ownership = Ownership
ns.CompositionOwnership = Ownership

local LegacyAssociationMap = ns.GUI.Editor.Composition.LegacyAssociationMap or ns.LegacyAssociationMap

local BAR_SECTION_BY_KEY = {
    HealthBar = "health",
    PowerBar = "power",
    CastBar = "cast",
    ClassPowerBar = "class_power",
    AlternativePowerBar = "alt_power",
    NormalAbsorbBar = "absorbs",
    HealingAbsorbBar = "absorbs",
}

local BAR_ORDER = {
    "HealthBar",
    "PowerBar",
    "CastBar",
    "ClassPowerBar",
    "AlternativePowerBar",
    "NormalAbsorbBar",
    "HealingAbsorbBar",
}

local AURA_KEYS = {
    Buffs = true,
    Debuffs = true,
}

local AURA_ORDER = {
    "Buffs",
    "Debuffs",
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

local INDICATOR_ORDER = {
    "Portrait",
    "RaidTargetIcon",
    "LeaderIcon",
    "RoleIcon",
    "CombatIndicator",
    "RestingIndicator",
    "ReadyCheckIndicator",
    "ClassificationIndicator",
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

local function BuildUnitRootRef(unit)
    local normalizedUnit = NormalizeUnitKey(unit)
    if not normalizedUnit then
        return nil
    end
    return {
        kind = "unit",
        unit = normalizedUnit,
        sectionKey = "frame",
    }
end

local function BuildBarRef(unit, barKey)
    local sectionKey = BAR_SECTION_BY_KEY[barKey]
    if not sectionKey then
        return nil
    end
    return {
        kind = "bar",
        unit = unit,
        objectKey = barKey,
        sectionKey = sectionKey,
    }
end

local function BuildTextRef(unit, textKey)
    return {
        kind = "text",
        unit = unit,
        textKey = textKey,
        objectKey = textKey,
        sectionKey = "texts",
    }
end

local function BuildAuraRef(unit, auraKey)
    return {
        kind = "aura",
        unit = unit,
        auraKey = auraKey,
        objectKey = auraKey,
        sectionKey = "auras",
    }
end

local function BuildIndicatorRef(unit, indicatorKey)
    return {
        kind = "indicator",
        unit = unit,
        indicatorKey = indicatorKey,
        objectKey = indicatorKey,
        sectionKey = "indicators",
    }
end

local function BuildDecorationRef(unit, decorationId)
    return {
        kind = "decoration",
        unit = unit,
        decorationId = decorationId,
        objectKey = decorationId,
        sectionKey = "decoration",
    }
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

local function BuildCurrentObjects(unitConfig, unit)
    local objects = {}
    for _, barKey in ipairs(BAR_ORDER) do
        local child = BuildBarRef(unit, barKey)
        if child then
            objects[#objects + 1] = child
        end
    end

    local texts = type(unitConfig) == "table" and unitConfig.Texts or nil
    if type(texts) == "table" then
        local textKeys = {}
        for textKey, textConfig in pairs(texts) do
            if type(textKey) == "string" and textKey ~= "" and type(textConfig) == "table" then
                textKeys[#textKeys + 1] = textKey
            end
        end
        table.sort(textKeys)
        for _, textKey in ipairs(textKeys) do
            objects[#objects + 1] = BuildTextRef(unit, textKey)
        end
    end

    for _, auraKey in ipairs(AURA_ORDER) do
        if type(unitConfig[auraKey]) == "table" then
            objects[#objects + 1] = BuildAuraRef(unit, auraKey)
        end
    end

    for _, indicatorKey in ipairs(INDICATOR_ORDER) do
        if type(unitConfig[indicatorKey]) == "table" then
            objects[#objects + 1] = BuildIndicatorRef(unit, indicatorKey)
        end
    end

    local decorations = unitConfig.decorations
    if type(decorations) == "table" then
        for _, decoration in ipairs(decorations) do
            local decorationId = type(decoration) == "table" and decoration.id or nil
            if type(decorationId) == "string" and decorationId ~= "" then
                objects[#objects + 1] = BuildDecorationRef(unit, decorationId)
            end
        end
    end

    return objects
end

local function IsSameObject(left, right)
    if type(left) ~= "table" or type(right) ~= "table" then
        return false
    end
    local leftKind = left.kind
    if leftKind ~= right.kind then
        return false
    end
    local leftUnit = NormalizeUnitKey(left.unit)
    local rightUnit = NormalizeUnitKey(right.unit)
    if not leftUnit or leftUnit ~= rightUnit then
        return false
    end
    if leftKind == "unit" then
        return true
    end
    if leftKind == "text" then
        return GetTextKey(left) == GetTextKey(right)
    end
    if leftKind == "aura" then
        return GetAuraKey(left) == GetAuraKey(right)
    end
    if leftKind == "indicator" then
        return GetIndicatorKey(left) == GetIndicatorKey(right)
    end
    if leftKind == "decoration" then
        return GetDecorationId(left) == GetDecorationId(right)
    end
    if leftKind == "bar" then
        return GetObjectKey(left) == GetObjectKey(right)
    end
    return false
end

local function IsKnownCurrentObject(unitConfig, objectRef)
    if type(unitConfig) ~= "table" or type(objectRef) ~= "table" then
        return false
    end

    local kind = objectRef.kind
    if kind == "unit" then
        return true
    end
    if kind == "bar" then
        return BAR_SECTION_BY_KEY[GetObjectKey(objectRef)] ~= nil
    end
    if kind == "text" then
        local textKey = GetTextKey(objectRef)
        local texts = unitConfig.Texts
        return type(textKey) == "string" and textKey ~= "" and type(texts) == "table" and type(texts[textKey]) == "table"
    end
    if kind == "aura" then
        local auraKey = GetAuraKey(objectRef)
        return AURA_KEYS[auraKey] == true and type(unitConfig[auraKey]) == "table"
    end
    if kind == "indicator" then
        local indicatorKey = GetIndicatorKey(objectRef)
        return INDICATOR_KEYS[indicatorKey] == true and type(unitConfig[indicatorKey]) == "table"
    end
    if kind == "decoration" then
        return HasDecoration(unitConfig, GetDecorationId(objectRef))
    end
    return false
end

local function IsLegacyParentPresent(unitConfig, parentRef)
    if type(parentRef) ~= "table" then
        return false
    end
    if parentRef.kind == "unit" then
        return true
    end

    local presence = ns.GUI
        and ns.GUI.Editor
        and ns.GUI.Editor.Composition
        and ns.GUI.Editor.Composition.Presence
        or ns.CompositionPresence
    if presence and type(presence.IsOwnPresent) == "function" then
        return presence.IsOwnPresent(unitConfig, parentRef) == true
    end

    return IsKnownCurrentObject(unitConfig, parentRef)
end

function Ownership.BuildUnitRootRef(unit)
    return BuildUnitRootRef(unit)
end

function Ownership.IsSameObject(left, right)
    return IsSameObject(left, right)
end

function Ownership.ResolveParent(unitConfig, objectRef)
    if type(objectRef) ~= "table" then
        return nil
    end

    local unit = NormalizeUnitKey(objectRef.unit)
    if not unit or not IsKnownCurrentObject(unitConfig, objectRef) then
        return nil
    end

    if objectRef.kind == "unit" then
        return nil
    end

    if LegacyAssociationMap and type(LegacyAssociationMap.Resolve) == "function" then
        local legacyParent = LegacyAssociationMap.Resolve(unitConfig, objectRef)
        if type(legacyParent) == "table" then
            if IsKnownCurrentObject(unitConfig, legacyParent) and IsLegacyParentPresent(unitConfig, legacyParent) then
                return legacyParent
            end
            return BuildUnitRootRef(unit)
        end
    end

    -- Fixed default: current composition objects are owned directly by the unit root.
    return BuildUnitRootRef(unit)
end

function Ownership.GetChildren(unitConfig, parentRef)
    local unit = type(parentRef) == "table" and NormalizeUnitKey(parentRef.unit) or nil
    if type(unitConfig) ~= "table" or not unit or type(parentRef) ~= "table" or not IsKnownCurrentObject(unitConfig, parentRef) then
        return {}
    end

    local children = {}
    for _, child in ipairs(BuildCurrentObjects(unitConfig, unit)) do
        local parent = Ownership.ResolveParent(unitConfig, child)
        if IsSameObject(parent, parentRef) then
            children[#children + 1] = child
        end
    end

    return children
end

function Ownership.IsDescendantOf(unitConfig, objectRef, ancestorRef)
    if type(objectRef) ~= "table" or type(ancestorRef) ~= "table" or IsSameObject(objectRef, ancestorRef) then
        return false
    end

    local current = objectRef
    local guard = 0
    while guard < 32 do
        guard = guard + 1
        local parent = Ownership.ResolveParent(unitConfig, current)
        if not parent then
            return false
        end
        if IsSameObject(parent, ancestorRef) then
            return true
        end
        current = parent
    end

    return false
end

return Ownership
