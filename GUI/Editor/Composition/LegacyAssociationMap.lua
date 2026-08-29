local _, ns = ...

ns.GUI = ns.GUI or {}
ns.GUI.Editor = ns.GUI.Editor or {}
ns.GUI.Editor.Composition = ns.GUI.Editor.Composition or {}

local LegacyAssociationMap = {}
ns.GUI.Editor.Composition.LegacyAssociationMap = LegacyAssociationMap
ns.LegacyAssociationMap = LegacyAssociationMap

local TEXT_ANCHOR_PARENT_BAR = {
    HealthBar = "HealthBar",
    PowerBar = "PowerBar",
    CastBar = "CastBar",
    ClassPowerBar = "ClassPowerBar",
    AlternativePowerBar = "AlternativePowerBar",
    NormalAbsorbBar = "NormalAbsorbBar",
    HealingAbsorbBar = "HealingAbsorbBar",
}

local BAR_SECTION_BY_KEY = {
    HealthBar = "health",
    PowerBar = "power",
    CastBar = "cast",
    ClassPowerBar = "class_power",
    AlternativePowerBar = "alt_power",
    NormalAbsorbBar = "absorbs",
    HealingAbsorbBar = "absorbs",
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

local function GetTextKey(objectRef)
    if type(objectRef) ~= "table" then
        return nil
    end
    return objectRef.textKey or objectRef.objectKey
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
    local normalizedUnit = NormalizeUnitKey(unit)
    local sectionKey = BAR_SECTION_BY_KEY[barKey]
    if not normalizedUnit or not sectionKey then
        return nil
    end
    return {
        kind = "bar",
        unit = normalizedUnit,
        objectKey = barKey,
        sectionKey = sectionKey,
    }
end

local function ResolveTextParent(unitConfig, objectRef)
    local unit = NormalizeUnitKey(objectRef and objectRef.unit)
    local textKey = GetTextKey(objectRef)
    local texts = type(unitConfig) == "table" and unitConfig.Texts or nil
    local textConfig = type(texts) == "table" and texts[textKey] or nil
    if not unit or type(textConfig) ~= "table" then
        return nil
    end

    local anchorTo = textConfig.anchorTo
    if anchorTo == nil or anchorTo == "" or anchorTo == "Frame" or anchorTo == "Unit" then
        return BuildUnitRootRef(unit)
    end

    local parentBar = TEXT_ANCHOR_PARENT_BAR[anchorTo]
    if parentBar then
        return BuildBarRef(unit, parentBar)
    end

    -- Unknown legacy values remain editable and project safely under the unit root.
    return BuildUnitRootRef(unit)
end

function LegacyAssociationMap.Resolve(unitConfig, objectRef)
    if type(objectRef) ~= "table" then
        return nil
    end

    if objectRef.kind == "text" then
        return ResolveTextParent(unitConfig, objectRef)
    end

    return nil
end

function LegacyAssociationMap.ResolveTextParent(unitConfig, objectRef)
    if type(objectRef) ~= "table" or objectRef.kind ~= "text" then
        return nil
    end
    return ResolveTextParent(unitConfig, objectRef)
end

return LegacyAssociationMap
