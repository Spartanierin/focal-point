local _, ns = ...

ns.GUI = ns.GUI or {}
ns.GUI.Helpers = ns.GUI.Helpers or {}
ns.GUI.Helpers.TabValues = ns.GUI.Helpers.TabValues or {}

local C = ns.Constants
local KM = ns.KeyMap
local L = ns.L
local OptionValues = ns.GUI.Helpers.OptionValues

local TabValues = ns.GUI.Helpers.TabValues

local TEXT_TAB_DEFS = {
    { value = C.Texts.NAME, configKey = "Name" },
    { value = C.Texts.HEALTH_VALUE, configKey = "Health" },
    { value = C.Texts.POWER_VALUE, configKey = "Power" },
    { value = C.Texts.LEVEL, configKey = "Level" },
    { value = C.Texts.CLASS, configKey = "Class" },
    { value = C.Texts.RACE, configKey = "Race" },
    { value = C.Texts.STATUS, configKey = "Status" },
    { value = C.Texts.CAST_NAME, configKey = "CastName" },
    { value = C.Texts.CAST_TIME, configKey = "CastTime" },
}

local CUSTOM_TEXT_TAB_DEFS = {
    { value = C.Texts.CUSTOM_1, configKey = "Custom1" },
    { value = C.Texts.CUSTOM_2, configKey = "Custom2" },
    { value = C.Texts.CUSTOM_3, configKey = "Custom3" },
}

local function MakeNode(value, text, children)
    local node = {
        value = value,
        text = text,
    }

    if children and #children > 0 then
        node.children = children
    end

    return node
end

function TabValues.CreateNavTree()
    local tree = {}

    table.insert(tree, MakeNode(
        C.Nav.EDITOR,
        ns.GetLabel(KM.Nav, C.Nav.EDITOR)
    ))

    table.insert(tree, MakeNode(
        C.Nav.PROFILES,
        ns.GetLabel(KM.Nav, C.Nav.PROFILES)
    ))

    table.insert(tree, MakeNode(
        C.Nav.TEXT_BUILDER,
        ns.GetLabel(KM.Nav, C.Nav.TEXT_BUILDER)
    ))

    table.insert(tree, MakeNode(
        C.Nav.TAG_DATABASE,
        ns.GetLabel(KM.Nav, C.Nav.TAG_DATABASE)
    ))

    return tree
end

function TabValues.GetBarTabValues()
    return {
        { text = ns.GetLabel(KM.Bars, C.Bars.HEALTH), value = C.Bars.HEALTH },
        { text = ns.GetLabel(KM.Bars, C.Bars.POWER), value = C.Bars.POWER },
        { text = ns.GetLabel(KM.Bars, C.Bars.ALT_POWER), value = C.Bars.ALT_POWER },
        { text = ns.GetLabel(KM.Bars, C.Bars.CAST), value = C.Bars.CAST },
    }
end

function TabValues.GetAuraTabValues()
    return {
        { text = ns.GetLabel(KM.Auras, C.Auras.BUFFS), value = C.Auras.BUFFS },
        { text = ns.GetLabel(KM.Auras, C.Auras.DEBUFFS), value = C.Auras.DEBUFFS },
    }
end

function TabValues.GetElementTabValues()
    return {
        { text = ns.GetLabel(KM.Elements, C.Elements.PORTRAIT), value = C.Elements.PORTRAIT },
        { text = ns.GetLabel(KM.Elements, C.Elements.RAID_TARGET_ICON), value = C.Elements.RAID_TARGET_ICON },
        { text = ns.GetLabel(KM.Elements, C.Elements.LEADER_ICON), value = C.Elements.LEADER_ICON },
        { text = ns.GetLabel(KM.Elements, C.Elements.ROLE_ICON), value = C.Elements.ROLE_ICON },
        { text = ns.GetLabel(KM.Elements, C.Elements.COMBAT_INDICATOR), value = C.Elements.COMBAT_INDICATOR },
        { text = ns.GetLabel(KM.Elements, C.Elements.RESTING_INDICATOR), value = C.Elements.RESTING_INDICATOR },
        { text = ns.GetLabel(KM.Elements, C.Elements.READY_CHECK_INDICATOR), value = C.Elements.READY_CHECK_INDICATOR },
        { text = ns.GetLabel(KM.Elements, C.Elements.CLASSIFICATION_INDICATOR), value = C.Elements.CLASSIFICATION_INDICATOR },
    }
end

function TabValues.GetTextElementLabel(elementIndex)
    local base = L["INFO_UNIT_TEXT_ELEMENT"] or "Text"
    return string.format("%s %d", base, elementIndex or 1)
end

function TabValues.GetTextTabValues(unitKey)
    local tabs = {}
    local visibleIndex = 1
    local templates = ns.db and ns.db.profile and ns.db.profile.TextTemplates or {}

    local function HasTextContent(configValue)
        if type(configValue) ~= "table" then
            return false
        end

        local tag = configValue.tag
        local templateName = configValue.templateName

        return (type(tag) == "string" and tag ~= "")
            or (type(templateName) == "string" and templateName ~= "")
    end

    local function ResolveTemplateTabLabel(configValue, fallbackIndex)
        if type(configValue) ~= "table" then
            return TabValues.GetTextElementLabel(fallbackIndex)
        end

        local templateName = configValue.templateName
        if type(templateName) == "string" and templateName ~= "" and type(templates[templateName]) == "string" then
            return templateName
        end

        local tag = configValue.tag
        if type(tag) == "string" and tag ~= "" then
            for currentTemplateName, templateValue in pairs(templates) do
                if templateValue == tag then
                    return currentTemplateName
                end
            end
        end

        return TabValues.GetTextElementLabel(fallbackIndex)
    end

    for _, def in ipairs(TEXT_TAB_DEFS) do
        local configPath = { "Units", unitKey, "Texts", def.configKey }
        local configValue = OptionValues.Get(configPath, nil)
        if configValue == nil then
            configValue = OptionValues.GetDefault(configPath, nil)
        end

        if HasTextContent(configValue) then
            table.insert(tabs, {
                text = ResolveTemplateTabLabel(configValue, visibleIndex),
                value = def.configKey,
            })
            visibleIndex = visibleIndex + 1
        end
    end

    for _, def in ipairs(CUSTOM_TEXT_TAB_DEFS) do
        local configPath = { "Units", unitKey, "Texts", def.configKey }
        local configValue = OptionValues.Get(configPath, nil)
        if configValue == nil then
            configValue = OptionValues.GetDefault(configPath, nil)
        end

        if HasTextContent(configValue) then
            table.insert(tabs, {
                text = ResolveTemplateTabLabel(configValue, visibleIndex),
                value = def.configKey,
            })
            visibleIndex = visibleIndex + 1
        end
    end

    return tabs
end

function TabValues.GetUnitTabValues()
    local tabs = {}

    for _, tabKey in ipairs(C.TabOrder) do
        table.insert(tabs, {
            text = ns.GetLabel(KM.Tabs, tabKey),
            value = tabKey,
        })
    end

    return tabs
end
