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

local SECTION = {
    frame = "frame",
    health = "health",
    absorbs = "absorbs",
    power = "power",
    cast = "cast",
    texts = "texts",
    auras = "auras",
}

local AURA_LABELS = {
    Buffs = "AURA_BUFFS",
    Debuffs = "AURA_DEBUFFS",
}

local function GetProfileUnits()
    local profile = ns.db and ns.db.profile or nil
    return type(profile) == "table" and profile.Units or nil
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

local function BuildNode(id, nodeType, unit, parentId, label, order, core, inspectorTarget)
    return {
        id = id,
        type = nodeType,
        unit = unit,
        parentId = parentId,
        label = label,
        order = order,
        core = core == true,
        inspectorTarget = inspectorTarget,
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

local function HasChildren(node)
    return type(node) == "table" and type(node.children) == "table" and #node.children > 0
end

local function IsEnabled(config)
    return type(config) == "table" and config.enabled ~= false
end

local function IsShown(unitConfig, fieldName)
    return type(unitConfig) == "table" and unitConfig[fieldName] ~= false
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

local function GetSortedTextIds(texts)
    local ids = {}
    if type(texts) ~= "table" then
        return ids
    end
    for textId, textConfig in pairs(texts) do
        if type(textId) == "string" and IsEnabled(textConfig) then
            ids[#ids + 1] = textId
        end
    end
    table.sort(ids, function(left, right)
        return tostring(GetTextLabel(left, texts[left])) < tostring(GetTextLabel(right, texts[right]))
    end)
    return ids
end

local function AddHealthBranch(root, unit, unitConfig)
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

    AddChild(health, BuildNode(
        health.id .. "/healthbar",
        "healthbar",
        unit,
        health.id,
        L["ELEMENT_HEALTH_BAR"] or "Health Bar",
        10,
        true,
        { kind = "unit", sectionKey = SECTION.health }
    ))

    if IsShown(unitConfig, "showNormalAbsorbBar") then
        AddChild(health, BuildNode(
            health.id .. "/normalabsorb",
            "normalAbsorbBar",
            unit,
            health.id,
            L["OPTION_NORMAL_ABSORB"] or "Normal Absorb",
            20,
            false,
            { kind = "unit", sectionKey = SECTION.absorbs }
        ))
    end

    if IsShown(unitConfig, "showHealingAbsorbBar") then
        AddChild(health, BuildNode(
            health.id .. "/healingabsorb",
            "healingAbsorbBar",
            unit,
            health.id,
            L["OPTION_HEALING_ABSORB"] or "Healing Absorb",
            30,
            false,
            { kind = "unit", sectionKey = SECTION.absorbs }
        ))
    end
end

local function AddPowerBranch(root, unit, unitConfig)
    if not IsShown(unitConfig, "showPowerBar") then
        return
    end

    local power = AddChild(root, BuildNode(
        root.id .. "/power",
        "power",
        unit,
        root.id,
        L["EDITOR_SECTION_POWER"] or "Power",
        20,
        false,
        { kind = "unit", sectionKey = SECTION.power }
    ))

    AddChild(power, BuildNode(
        power.id .. "/powerbar",
        "powerbar",
        unit,
        power.id,
        L["ELEMENT_POWER_BAR"] or "Power Bar",
        10,
        false,
        { kind = "unit", sectionKey = SECTION.power }
    ))
end

local function AddCastBranch(root, unit, unitConfig)
    if not IsShown(unitConfig, "showCastBar") then
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

    AddChild(cast, BuildNode(
        cast.id .. "/castbar",
        "castbar",
        unit,
        cast.id,
        L["ELEMENT_CAST_BAR"] or "Cast Bar",
        10,
        false,
        { kind = "unit", sectionKey = SECTION.cast }
    ))
end

local function AddTextBranch(root, unit, unitConfig)
    local texts = type(unitConfig) == "table" and unitConfig.Texts or nil
    local textIds = GetSortedTextIds(texts)
    if #textIds == 0 then
        return
    end
    local textLabels = type(SidebarShared.BuildTextList) == "function" and SidebarShared.BuildTextList(texts) or {}

    local textRoot = AddChild(root, BuildNode(
        root.id .. "/texts",
        "texts",
        unit,
        root.id,
        L["EDITOR_SECTION_TEXT"] or "Texts",
        40,
        false,
        { kind = "text", sectionKey = SECTION.texts }
    ))

    for index, textId in ipairs(textIds) do
        local textConfig = texts[textId]
        AddChild(textRoot, BuildNode(
            textRoot.id .. ":" .. textId,
            "textElement",
            unit,
            textRoot.id,
            textLabels[textId] or GetTextLabel(textId, textConfig),
            index,
            false,
            { kind = "text", sectionKey = SECTION.texts, textKey = textId }
        ))
    end
end

local function AddAuraBranch(root, unit, unitConfig)
    local auraRoot
    for index, auraKey in ipairs({ "Buffs", "Debuffs" }) do
        local auraConfig = type(unitConfig) == "table" and unitConfig[auraKey] or nil
        if IsEnabled(auraConfig) then
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
                { kind = "aura", sectionKey = SECTION.auras, auraKey = auraKey }
            ))
        end
    end
end

function Adapter.GetRootUnits()
    local units = GetProfileUnits()
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
    local units = GetProfileUnits()
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

    AddHealthBranch(root, normalizedUnit, unitConfig)
    AddPowerBranch(root, normalizedUnit, unitConfig)
    AddCastBranch(root, normalizedUnit, unitConfig)
    AddTextBranch(root, normalizedUnit, unitConfig)
    AddAuraBranch(root, normalizedUnit, unitConfig)

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
