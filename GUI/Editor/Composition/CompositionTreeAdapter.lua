local _, ns = ...

ns.GUI = ns.GUI or {}
ns.GUI.Editor = ns.GUI.Editor or {}
ns.GUI.Editor.Composition = ns.GUI.Editor.Composition or {}

local Adapter = {}
ns.GUI.Editor.Composition.TreeAdapter = Adapter
ns.CompositionTreeAdapter = Adapter

local C = ns.Constants or {}
local L = ns.L or {}
local SidebarShared = ns.GUI.Editor.SidebarShared or {}
local PresencePolicy = ns.EditorPresencePolicy
local CompositionOwnership = ns.GUI.Editor.Composition.Ownership or ns.CompositionOwnership
local CompositionPresence = ns.GUI.Editor.Composition.Presence or ns.CompositionPresence

local SECTION = {
    frame = "frame",
    health = "health",
    absorbs = "absorbs",
    power = "power",
    alt_power = "alt_power",
    class_power = "class_power",
    cast = "cast",
    texts = "texts",
    auras = "auras",
    indicators = "indicators",
    decoration = "decoration",
}

local AURA_LABELS = {
    Buffs = "AURA_BUFFS",
    Debuffs = "AURA_DEBUFFS",
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

local function GetActiveUnits()
    local utils = ns.UnitFrameUtils
    local units = utils and utils.GetUnitsDB and utils.GetUnitsDB() or nil
    return type(units) == "table" and units or nil
end

local function NormalizeUnitKey(unit)
    if type(unit) ~= "string" or unit == "" then
        return nil
    end
    if unit:match("^boss%d+$") then
        return "boss"
    end
    return unit
end

local function BuildNode(id, nodeType, unit, parentId, label, order, core, inspectorTarget, enabled)
    return {
        id = id,
        type = nodeType,
        unit = unit,
        parentId = parentId,
        label = label,
        order = order,
        core = core == true,
        inspectorTarget = inspectorTarget,
        enabled = enabled,
        children = {},
    }
end

local function AddChild(parent, child)
    if type(parent) ~= "table" or type(child) ~= "table" then
        return nil
    end
    parent.children[#parent.children + 1] = child
    return child
end

local function RegisterAnchorNode(anchorNodes, anchorKey, node)
    if type(anchorNodes) == "table" and type(anchorKey) == "string" and anchorKey ~= "" and type(node) == "table" then
        anchorNodes[anchorKey] = node
    end
    return node
end

local function HasChildren(node)
    return type(node) == "table" and type(node.children) == "table" and #node.children > 0
end

local function IsEnabled(config)
    return type(config) == "table" and config.enabled ~= false
end

local function IsPresent(unitConfig, objectRef)
    if CompositionPresence and type(CompositionPresence.IsPresent) == "function" then
        return CompositionPresence.IsPresent(unitConfig, objectRef) == true
    end
    return true
end

local function BuildBarTarget(sectionKey, objectKey)
    local target = {
        kind = "unit",
        sectionKey = sectionKey,
    }
    if objectKey then
        target.objectKey = objectKey
    end
    return target
end

local function BuildBarRef(unit, objectKey)
    return {
        kind = "bar",
        unit = unit,
        objectKey = objectKey,
    }
end

local function BuildAuraRef(unit, auraKey)
    return {
        kind = "aura",
        unit = unit,
        auraKey = auraKey,
        objectKey = auraKey,
    }
end

local function BuildIndicatorRef(unit, indicatorKey)
    return {
        kind = "indicator",
        unit = unit,
        indicatorKey = indicatorKey,
        objectKey = indicatorKey,
    }
end

local function BuildTextRef(unit, textId)
    return {
        kind = "text",
        unit = unit,
        textKey = textId,
        objectKey = textId,
    }
end

local function BuildDecorationRef(unit, decorationId)
    return {
        kind = "decoration",
        unit = unit,
        decorationId = decorationId,
        objectKey = decorationId,
    }
end

local function GetUnitLabel(unit)
    local keyMap = ns.KeyMap and ns.KeyMap.Units or nil
    if ns.GetLabel and keyMap then
        return ns.GetLabel(keyMap, unit) or unit
    end
    return unit
end

local function GetTextLabel(textId, textConfig)
    if type(textConfig) == "table" and type(textConfig.templateName) == "string" and textConfig.templateName ~= "" then
        return textConfig.templateName
    end
    return tostring(textId)
end

local function GetDecorationLabel(decoration, index)
    if type(decoration) == "table" and type(decoration.id) == "string" and decoration.id ~= "" then
        return string.format("%s %d", L["EDITOR_SECTION_DECORATION"] or "Decoration", index or 1)
    end
    return L["EDITOR_SECTION_DECORATION"] or "Decoration"
end

local function GetSortedTextIds(texts)
    local ids = {}
    if type(texts) ~= "table" then
        return ids
    end
    for textId, textConfig in pairs(texts) do
        if type(textId) == "string" and type(textConfig) == "table" then
            ids[#ids + 1] = textId
        end
    end
    table.sort(ids, function(left, right)
        return tostring(GetTextLabel(left, texts[left])) < tostring(GetTextLabel(right, texts[right]))
    end)
    return ids
end

local function AddHealthBranch(root, unit, unitConfig, anchorNodes)
    local health = AddChild(root, BuildNode(
        root.id .. "/health",
        "health",
        unit,
        root.id,
        L["EDITOR_SECTION_HEALTH"] or "Health",
        10,
        true,
        { kind = "unit", sectionKey = SECTION.health }
    ))

    RegisterAnchorNode(anchorNodes, "HealthBar", AddChild(health, BuildNode(
        health.id .. "/healthbar",
        "healthbar",
        unit,
        health.id,
        L["ELEMENT_HEALTH_BAR"] or "Health Bar",
        10,
        true,
        BuildBarTarget(SECTION.health),
        true
    )))

    if IsPresent(unitConfig, BuildBarRef(unit, "NormalAbsorbBar")) then
        RegisterAnchorNode(anchorNodes, "NormalAbsorbBar", AddChild(health, BuildNode(
            health.id .. "/normalabsorb",
            "normalAbsorbBar",
            unit,
            health.id,
            L["OPTION_NORMAL_ABSORB"] or "Normal Absorb",
            20,
            false,
            BuildBarTarget(SECTION.absorbs, "NormalAbsorbBar"),
            true
        )))
    end

    if IsPresent(unitConfig, BuildBarRef(unit, "HealingAbsorbBar")) then
        RegisterAnchorNode(anchorNodes, "HealingAbsorbBar", AddChild(health, BuildNode(
            health.id .. "/healingabsorb",
            "healingAbsorbBar",
            unit,
            health.id,
            L["OPTION_HEALING_ABSORB"] or "Healing Absorb",
            30,
            false,
            BuildBarTarget(SECTION.absorbs, "HealingAbsorbBar"),
            true
        )))
    end
end

local function AddPowerBranch(root, unit, unitConfig, anchorNodes)
    local power

    local function EnsurePower()
        if not power then
            power = AddChild(root, BuildNode(
                root.id .. "/power",
                "power",
                unit,
                root.id,
                L["EDITOR_SECTION_POWER"] or "Power",
                20,
                false,
                { kind = "unit", sectionKey = SECTION.power }
            ))
        end
        return power
    end

    if IsPresent(unitConfig, BuildBarRef(unit, "PowerBar")) then
        power = EnsurePower()
        RegisterAnchorNode(anchorNodes, "PowerBar", AddChild(power, BuildNode(
            power.id .. "/powerbar",
            "powerbar",
            unit,
            power.id,
            L["ELEMENT_POWER_BAR"] or "Power Bar",
            10,
            false,
            BuildBarTarget(SECTION.power),
            true
        )))
    end

    if unit == "player" then
        if IsPresent(unitConfig, BuildBarRef(unit, "ClassPowerBar")) then
            power = EnsurePower()
            RegisterAnchorNode(anchorNodes, "ClassPowerBar", AddChild(power, BuildNode(
                power.id .. "/classpower",
                "classPowerBar",
                unit,
                power.id,
                L["BAR_CLASS_POWER"] or "Class Power",
                20,
                false,
                BuildBarTarget(SECTION.class_power),
                true
            )))
        end

        if IsPresent(unitConfig, BuildBarRef(unit, "AlternativePowerBar")) then
            power = EnsurePower()
            RegisterAnchorNode(anchorNodes, "AlternativePowerBar", AddChild(power, BuildNode(
                power.id .. "/alternativepower",
                "alternativePowerBar",
                unit,
                power.id,
                L["BAR_ALT_POWER"] or "Alt Power",
                30,
                false,
                BuildBarTarget(SECTION.alt_power),
                true
            )))
        end
    end
end

local function AddCastBranch(root, unit, unitConfig, anchorNodes)
    if not IsPresent(unitConfig, BuildBarRef(unit, "CastBar")) then
        return
    end

    local cast = AddChild(root, BuildNode(
        root.id .. "/cast",
        "cast",
        unit,
        root.id,
        L["EDITOR_SECTION_CAST"] or "Cast",
        30,
        false,
        { kind = "unit", sectionKey = SECTION.cast }
    ))

    RegisterAnchorNode(anchorNodes, "CastBar", AddChild(cast, BuildNode(
        cast.id .. "/castbar",
        "castbar",
        unit,
        cast.id,
        L["ELEMENT_CAST_BAR"] or "Cast Bar",
        10,
        false,
        BuildBarTarget(SECTION.cast),
        true
    )))
end

local function ResolveTextParent(root, anchorNodes, textConfig)
    if not (CompositionOwnership and type(CompositionOwnership.ResolveParent) == "function") then
        return root
    end

    local parentRef = CompositionOwnership.ResolveParent(textConfig.unitConfig, textConfig.objectRef)
    if type(parentRef) ~= "table" or parentRef.kind == "unit" then
        return root
    end

    return type(anchorNodes) == "table" and anchorNodes[parentRef.objectKey] or root
end

local function AddTextBranch(root, unit, unitConfig, anchorNodes)
    local texts = type(unitConfig) == "table" and unitConfig.Texts or nil
    local textIds = GetSortedTextIds(texts)
    if #textIds == 0 then
        return
    end
    local textLabels = type(SidebarShared.BuildTextList) == "function" and SidebarShared.BuildTextList(texts) or {}

    for index, textId in ipairs(textIds) do
        local textConfig = texts[textId]
        if IsPresent(unitConfig, BuildTextRef(unit, textId)) then
            local parent = ResolveTextParent(root, anchorNodes, {
                unitConfig = unitConfig,
                objectRef = BuildTextRef(unit, textId),
            })
            local node = BuildNode(
                root.id .. "/text:" .. textId,
                "textElement",
                unit,
                parent.id,
                textLabels[textId] or GetTextLabel(textId, textConfig),
                index,
                false,
                { kind = "text", sectionKey = SECTION.texts, textKey = textId },
                IsEnabled(textConfig)
            )
            if PresencePolicy and type(PresencePolicy.ResolveText) == "function" then
                node.presence = PresencePolicy.ResolveText(unit, textId)
            end
            AddChild(parent, node)
        end
    end
end

local function AddAuraBranch(root, unit, unitConfig)
    local auraRoot
    for index, auraKey in ipairs({ "Buffs", "Debuffs" }) do
        local auraRef = BuildAuraRef(unit, auraKey)
        if IsPresent(unitConfig, auraRef) then
            if not auraRoot then
                auraRoot = AddChild(root, BuildNode(
                    root.id .. "/auras",
                    "auras",
                    unit,
                    root.id,
                    L["EDITOR_SECTION_AURAS"] or "Auras",
                    50,
                    false,
                    { kind = "aura", sectionKey = SECTION.auras }
                ))
            end
            AddChild(auraRoot, BuildNode(
                auraRoot.id .. "/" .. string.lower(auraKey),
                auraKey == "Buffs" and "buffs" or "debuffs",
                unit,
                auraRoot.id,
                L[AURA_LABELS[auraKey]] or auraKey,
                index,
                false,
                { kind = "aura", sectionKey = SECTION.auras, auraKey = auraKey },
                true
            ))
        end
    end
end

local function ResolveIndicatorParent(root, anchorNodes, indicatorConfig)
    local anchorTo = type(indicatorConfig) == "table" and indicatorConfig.anchorTo or nil
    if anchorTo == "Frame" or anchorTo == nil or anchorTo == "" then
        return root
    end
    return type(anchorNodes) == "table" and anchorNodes[anchorTo] or root
end

local function AddIndicatorBranch(root, unit, unitConfig, anchorNodes)
    local indicatorList = type(SidebarShared.BuildIndicatorList) == "function" and SidebarShared.BuildIndicatorList(unit) or {}
    local meta = SidebarShared.INDICATOR_META or {}

    for index, indicatorKey in ipairs(INDICATOR_ORDER) do
        local label = indicatorList[indicatorKey]
        local entry = meta[indicatorKey]
        local config = type(unitConfig) == "table" and type(entry) == "table" and unitConfig[entry.optionKey] or nil
        if type(label) == "string" and type(config) == "table" and IsPresent(unitConfig, BuildIndicatorRef(unit, indicatorKey)) then
            local parent = ResolveIndicatorParent(root, anchorNodes, config)
            local node = BuildNode(
                root.id .. "/indicator:" .. indicatorKey,
                "indicatorElement",
                unit,
                parent.id,
                label,
                index,
                false,
                { kind = "indicator", sectionKey = SECTION.indicators, indicatorKey = indicatorKey },
                true
            )
            if PresencePolicy and type(PresencePolicy.ResolveObject) == "function" then
                node.presence = PresencePolicy.ResolveObject(unit, node.inspectorTarget)
            end
            AddChild(parent, node)
        end
    end
end

local function ResolveDecorationParent(root, anchorNodes, decorationConfig)
    local anchorTo = type(decorationConfig) == "table" and decorationConfig.anchorTo or nil
    if anchorTo == "Frame" or anchorTo == nil or anchorTo == "" then
        return root
    end
    return type(anchorNodes) == "table" and anchorNodes[anchorTo] or root
end

local function AddDecorationBranch(root, unit, unitConfig, anchorNodes)
    local decorations = type(unitConfig) == "table" and unitConfig.decorations or nil
    if type(decorations) ~= "table" or #decorations == 0 then
        return
    end

    for index, decoration in ipairs(decorations) do
        local decorationId = type(decoration) == "table" and decoration.id or nil
        if type(decorationId) == "string" and decorationId ~= "" and IsPresent(unitConfig, BuildDecorationRef(unit, decorationId)) then
            local parent = ResolveDecorationParent(root, anchorNodes, decoration)
            local node = BuildNode(
                root.id .. "/decoration:" .. decorationId,
                "decorationElement",
                unit,
                parent.id,
                GetDecorationLabel(decoration, index),
                index,
                false,
                { kind = "decoration", sectionKey = SECTION.decoration, decorationId = decorationId },
                IsEnabled(decoration)
            )
            if PresencePolicy and type(PresencePolicy.ResolveObject) == "function" then
                node.presence = PresencePolicy.ResolveObject(unit, node.inspectorTarget)
            end
            AddChild(parent, node)
        end
    end
end

function Adapter.GetRootUnits()
    local units = GetActiveUnits()
    local roots = {}
    local seen = {}
    local unitOrder = C.UnitOrder or {}

    for _, unit in ipairs(unitOrder) do
        local normalizedUnit = NormalizeUnitKey(unit)
        if normalizedUnit and not seen[normalizedUnit] and type(units) == "table" and type(units[normalizedUnit]) == "table" then
            roots[#roots + 1] = normalizedUnit
            seen[normalizedUnit] = true
        end
    end

    if type(units) == "table" then
        local extraUnits = {}
        for unit in pairs(units) do
            local normalizedUnit = NormalizeUnitKey(unit)
            if normalizedUnit and not seen[normalizedUnit] then
                extraUnits[#extraUnits + 1] = normalizedUnit
                seen[normalizedUnit] = true
            end
        end
        table.sort(extraUnits)
        for _, unit in ipairs(extraUnits) do
            roots[#roots + 1] = unit
        end
    end

    return roots
end

function Adapter.BuildUnitTree(unit)
    local normalizedUnit = NormalizeUnitKey(unit)
    local units = GetActiveUnits()
    local unitConfig = normalizedUnit and type(units) == "table" and units[normalizedUnit] or nil
    if type(unitConfig) ~= "table" then
        return nil
    end

    local root = BuildNode(
        "unit:" .. normalizedUnit,
        "unit",
        normalizedUnit,
        nil,
        GetUnitLabel(normalizedUnit),
        0,
        true,
        { kind = "unit", sectionKey = SECTION.frame }
    )

    local anchorNodes = {
        Frame = root,
    }

    AddHealthBranch(root, normalizedUnit, unitConfig, anchorNodes)
    AddPowerBranch(root, normalizedUnit, unitConfig, anchorNodes)
    AddCastBranch(root, normalizedUnit, unitConfig, anchorNodes)
    AddTextBranch(root, normalizedUnit, unitConfig, anchorNodes)
    AddAuraBranch(root, normalizedUnit, unitConfig)
    AddIndicatorBranch(root, normalizedUnit, unitConfig, anchorNodes)
    AddDecorationBranch(root, normalizedUnit, unitConfig, anchorNodes)

    return root
end

function Adapter.FindNode(tree, nodeId)
    if type(tree) ~= "table" or type(nodeId) ~= "string" then
        return nil
    end
    if tree.id == nodeId then
        return tree
    end
    for _, child in ipairs(tree.children or {}) do
        local found = Adapter.FindNode(child, nodeId)
        if found then
            return found
        end
    end
    return nil
end

function Adapter.HasChildren(node)
    return HasChildren(node)
end

return Adapter
