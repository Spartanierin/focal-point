local addonName, ns = ...

ns.GUIBuilders = ns.GUIBuilders or {}
local B = ns.GUIBuilders

local AceGUI = LibStub("AceGUI-3.0")
local C = ns.Constants
local KM = ns.KeyMap
local L = ns.L
local ColorPicker = ns.GUI.Widgets.ColorPicker
local Slider = ns.GUI.Widgets.Sliders
local Dropdown = ns.GUI.Widgets.Dropdown
local Checkbox = ns.GUI.Widgets.Checkbox
local LayoutHelpers = ns.GUI.Helpers.LayoutHelpers

local function GetGUIState()
    ns.GUI._state = ns.GUI._state or {
        unitTabs = {},
        unitScroll = {},
        unitBarTabs = {},
        unitBarScroll = {},
        unitTextTabs = {},
        unitTextScroll = {},
        unitElementTabs = {},
        unitElementScroll = {},
        textBuilder = {
            template = "[hp:cur:abbr]/[hp:max:abbr] | [hp:perc]%",
        },
    }

    return ns.GUI._state
end

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

function B.CreateNavTree()
    local tree = {}

    -- General
    table.insert(tree, MakeNode(
        C.Nav.GENERAL,
        ns.GetLabel(KM.Nav, C.Nav.GENERAL)
    ))

    -- Units
    local unitChildren = {}

    for _, unitKey in ipairs(C.UnitOrder) do
        table.insert(unitChildren, MakeNode(
            "units." .. unitKey,
            ns.GetLabel(KM.Units, unitKey)
        ))
    end

    table.insert(tree, MakeNode(
        C.Nav.UNITS,
        ns.GetLabel(KM.Nav, C.Nav.UNITS),
        unitChildren
    ))

    -- Profiles
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

local function AddSectionHeading(container, text, topSpacing)
    local spacer = AceGUI:Create("Label")
    spacer:SetText(" ")
    spacer:SetFullWidth(true)
    spacer:SetHeight(topSpacing or 0)
    container:AddChild(spacer)

    local heading = AceGUI:Create("Heading")
    heading:SetText(text)
    heading:SetFullWidth(true)
    container:AddChild(heading)
end

local function AddPageHeading(container, text)
    local heading = AceGUI:Create("Heading")
    heading:SetFullWidth(true)
    heading:SetText(text)
    container:AddChild(heading)
end

local function ResetFlowContainer(container)
    container:ReleaseChildren()
    container:SetLayout("Flow")
end

local function GetAddonVersionText()
    local tried = {}
    local addonKeys = {
        addonName,
        C.ADDON_NAME,
        "Portrait",
    }

    local function TryMetadata(addonKey)
        if type(addonKey) ~= "string" or addonKey == "" or tried[addonKey] then
            return nil
        end

        tried[addonKey] = true

        if C_AddOns and C_AddOns.GetAddOnMetadata then
            local version = C_AddOns.GetAddOnMetadata(addonKey, "Version")
            if type(version) == "string" and version ~= "" then
                return version
            end
        end

        if GetAddOnMetadata then
            local version = GetAddOnMetadata(addonKey, "Version")
            if type(version) == "string" and version ~= "" then
                return version
            end
        end

        return nil
    end

    for _, addonKey in ipairs(addonKeys) do
        local version = TryMetadata(addonKey)
        if version then
            return version
        end
    end

    return "dev"
end

local CreateSection = LayoutHelpers.CreateSection
local AddLayoutHandle = LayoutHelpers.AddLayoutHandle
local BuildScrollableTabContent = LayoutHelpers.BuildScrollableTabContent

local function GetBarTabValues()
    return {
        { text = ns.GetLabel(KM.Bars, C.Bars.HEALTH), value = C.Bars.HEALTH },
        { text = ns.GetLabel(KM.Bars, C.Bars.POWER), value = C.Bars.POWER },
        { text = ns.GetLabel(KM.Bars, C.Bars.ALT_POWER), value = C.Bars.ALT_POWER },
        { text = ns.GetLabel(KM.Bars, C.Bars.CAST), value = C.Bars.CAST },
    }
end

local function GetElementTabValues()
    return {
        { text = ns.GetLabel(KM.Elements, C.Elements.PORTRAIT), value = C.Elements.PORTRAIT },
        { text = ns.GetLabel(KM.Elements, C.Elements.RAID_TARGET_ICON), value = C.Elements.RAID_TARGET_ICON },
        { text = ns.GetLabel(KM.Elements, C.Elements.LEADER_ICON), value = C.Elements.LEADER_ICON },
        { text = ns.GetLabel(KM.Elements, C.Elements.ROLE_ICON), value = C.Elements.ROLE_ICON },
        { text = ns.GetLabel(KM.Elements, C.Elements.COMBAT_INDICATOR), value = C.Elements.COMBAT_INDICATOR },
        { text = ns.GetLabel(KM.Elements, C.Elements.RESTING_INDICATOR), value = C.Elements.RESTING_INDICATOR },
        { text = ns.GetLabel(KM.Elements, C.Elements.READY_CHECK_INDICATOR), value = C.Elements.READY_CHECK_INDICATOR },
    }
end

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

local function GetTextElementLabel(elementIndex)
    local base = L["INFO_UNIT_TEXT_ELEMENT"] or "Text"
    return string.format("%s %d", base, elementIndex or 1)
end

local function GetTextTabValues(unitKey)
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
            return GetTextElementLabel(fallbackIndex)
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

        return GetTextElementLabel(fallbackIndex)
    end

    for _, def in ipairs(TEXT_TAB_DEFS) do
        local configPath = { "Units", unitKey, "Texts", def.configKey }
        local configValue = ns.GUI.Helpers.OptionValues.Get(configPath, nil)
        if configValue == nil then
            configValue = ns.GUI.Helpers.OptionValues.GetDefault(configPath, nil)
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
        local configValue = ns.GUI.Helpers.OptionValues.Get(configPath, nil)
        if configValue == nil then
            configValue = ns.GUI.Helpers.OptionValues.GetDefault(configPath, nil)
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

local ResolveLayoutText = LayoutHelpers.ResolveLayoutText
local ResolveLayoutPath = LayoutHelpers.ResolveLayoutPath
local ResolveLayoutList = LayoutHelpers.ResolveLayoutList
local CanBuildLayoutWidget = LayoutHelpers.CanBuildLayoutWidget

local function BuildStandardElementLayoutPage(container, unitKey, config)
    ResetFlowContainer(container)

    local unitLabel = ns.GetLabel(KM.Units, unitKey)

    local function IsUnitDisabled()
        return not ns.GUI.Helpers.OptionValues.Get({ "Units", unitKey, "enabled" }, true)
    end

    local function IsElementDisabled()
        if type(config.isUnavailable) == "function" and config.isUnavailable(unitKey) then
            return true
        end

        return IsUnitDisabled()
            or not ns.GUI.Helpers.OptionValues.Get({ "Units", unitKey, config.optionKey, "enabled" }, true)
    end

    local function IsInsideDisabled()
        return IsElementDisabled()
            or ns.GUI.Helpers.OptionValues.Get({ "Units", unitKey, config.optionKey, "placement" }, "ATTACHED") ~= "INSIDE"
    end

    local function IsAttachedDisabled()
        return IsElementDisabled()
            or ns.GUI.Helpers.OptionValues.Get({ "Units", unitKey, config.optionKey, "placement" }, "ATTACHED") ~= "ATTACHED"
    end

    local function ResolveDisabled(def)
        if def.disabled == "unit" then
            return IsUnitDisabled
        end

        if def.disabled == config.disabledKey then
            return IsElementDisabled
        end

        if def.disabled == "inside" then
            return IsInsideDisabled
        end

        if def.disabled == "attached" then
            return IsAttachedDisabled
        end

        return nil
    end

    local function AddSectionWidget(layout, def)
        local resolvedList = def.list and ResolveLayoutList(config.lists[def.list]) or nil

        if not CanBuildLayoutWidget(def, resolvedList) then
            return
        end

        if def.widget == "checkbox" then
            AddLayoutHandle(layout, Checkbox.Create({
                path = ResolveLayoutPath(def.path, unitKey),
                label = ResolveLayoutText(def.label),
                description = ResolveLayoutText(def.description),
                fallback = def.fallback,
                resetText = L["OPTION_RESET"],
                disabled = ResolveDisabled(def),
                refreshGUI = def.refreshGUI,
            }), def)
            return
        end

        if def.widget == "dropdown" then
            AddLayoutHandle(layout, Dropdown.Create({
                path = ResolveLayoutPath(def.path, unitKey),
                label = ResolveLayoutText(def.label),
                description = ResolveLayoutText(def.description),
                list = resolvedList,
                fallback = def.fallback,
                resetText = L["OPTION_RESET"],
                disabled = ResolveDisabled(def),
                refreshGUI = def.refreshGUI,
            }), def)
            return
        end

        if def.widget == "slider" then
            AddLayoutHandle(layout, Slider.Create({
                path = ResolveLayoutPath(def.path, unitKey),
                label = ResolveLayoutText(def.label),
                description = ResolveLayoutText(def.description),
                min = def.min,
                max = def.max,
                step = def.step,
                fallback = def.fallback,
                format = def.format,
                resetText = L["OPTION_RESET"],
                disabled = ResolveDisabled(def),
            }), def)
        end
    end

    AddPageHeading(container, unitLabel .. " - " .. ns.GetLabel(KM.Tabs, C.Tabs.ELEMENTS) .. " - " .. ns.GetLabel(KM.Elements, config.elementKey))

    for _, sectionDef in ipairs(config.layout) do
        AddSectionHeading(container, ResolveLayoutText(sectionDef.section))

        if sectionDef.mode == "section" then
            local layout = CreateSection(container)
            for _, item in ipairs(sectionDef.items) do
                AddSectionWidget(layout, item)
            end
        end
    end
end

local function BuildUnitPortraitElementPage(container, unitKey)
    BuildStandardElementLayoutPage(container, unitKey, {
        optionKey = "Portrait",
        disabledKey = "portrait",
        elementKey = C.Elements.PORTRAIT,
        lists = ns.GUI.Layouts.UnitPortrait.Lists,
        layout = ns.GUI.Layouts.UnitPortrait.PortraitTab,
    })
end

local function BuildUnitRaidTargetElementPage(container, unitKey)
    BuildStandardElementLayoutPage(container, unitKey, {
        optionKey = "RaidTargetIcon",
        disabledKey = "rtm",
        elementKey = C.Elements.RAID_TARGET_ICON,
        lists = ns.GUI.Layouts.UnitRaidTarget.Lists,
        layout = ns.GUI.Layouts.UnitRaidTarget.RaidTargetTab,
    })
end

local function BuildUnitLeaderIconElementPage(container, unitKey)
    BuildStandardElementLayoutPage(container, unitKey, {
        optionKey = "LeaderIcon",
        disabledKey = "leader",
        elementKey = C.Elements.LEADER_ICON,
        lists = ns.GUI.Layouts.UnitLeaderIcon.Lists,
        layout = ns.GUI.Layouts.UnitLeaderIcon.LeaderIconTab,
    })
end

local function BuildUnitRoleIconElementPage(container, unitKey)
    BuildStandardElementLayoutPage(container, unitKey, {
        optionKey = "RoleIcon",
        disabledKey = "role",
        elementKey = C.Elements.ROLE_ICON,
        lists = ns.GUI.Layouts.UnitRoleIcon.Lists,
        layout = ns.GUI.Layouts.UnitRoleIcon.RoleIconTab,
    })
end

local function BuildUnitCombatIndicatorElementPage(container, unitKey)
    BuildStandardElementLayoutPage(container, unitKey, {
        optionKey = "CombatIndicator",
        disabledKey = "combat",
        elementKey = C.Elements.COMBAT_INDICATOR,
        lists = ns.GUI.Layouts.UnitCombatIndicator.Lists,
        layout = ns.GUI.Layouts.UnitCombatIndicator.CombatIndicatorTab,
    })
end

local function BuildUnitRestingIndicatorElementPage(container, unitKey)
    BuildStandardElementLayoutPage(container, unitKey, {
        optionKey = "RestingIndicator",
        disabledKey = "resting",
        elementKey = C.Elements.RESTING_INDICATOR,
        lists = ns.GUI.Layouts.UnitRestingIndicator.Lists,
        layout = ns.GUI.Layouts.UnitRestingIndicator.RestingIndicatorTab,
        isUnavailable = function(currentUnitKey)
            return currentUnitKey ~= "player"
        end,
    })
end

local function BuildUnitReadyCheckIndicatorElementPage(container, unitKey)
    BuildStandardElementLayoutPage(container, unitKey, {
        optionKey = "ReadyCheckIndicator",
        disabledKey = "readycheck",
        elementKey = C.Elements.READY_CHECK_INDICATOR,
        lists = ns.GUI.Layouts.UnitReadyCheckIndicator.Lists,
        layout = ns.GUI.Layouts.UnitReadyCheckIndicator.ReadyCheckIndicatorTab,
    })
end



function B.BuildPlaceholderPage(container, title)
    container:ReleaseChildren()
    container:SetLayout("Fill")

    local label = AceGUI:Create("Label")
    if title and title ~= "" then
        label:SetText(title .. " - " .. L["INFO_NOT_IMPLEMENTED_YET"])
    else
        label:SetText(L["INFO_NOT_IMPLEMENTED_YET"])
    end
    label:SetFullWidth(true)
    container:AddChild(label)
end

function B.BuildGeneralPage(container)
    local page = ns.GUI.Pages and ns.GUI.Pages.General
    if not page or not page.Build then
        B.BuildPlaceholderPage(container, ns.GetLabel(KM.Nav, C.Nav.GENERAL))
        return
    end

    page.Build(container, {
        ResetFlowContainer = ResetFlowContainer,
        GetAddonVersionText = GetAddonVersionText,
        CreateSection = CreateSection,
    })
end

function B.BuildProfilesPage(container)
    local page = ns.GUI.Pages and ns.GUI.Pages.Profiles
    if not page or not page.Build then
        B.BuildPlaceholderPage(container, L["NAV_PROFILES"] or "Profiles")
        return
    end

    page.Build(container, {
        GetGUIState = GetGUIState,
        ResetFlowContainer = ResetFlowContainer,
        AddPageHeading = AddPageHeading,
        BuildPlaceholderPage = B.BuildPlaceholderPage,
    })
end

function B.BuildTagDatabasePage(container)
    local page = ns.GUI.Pages and ns.GUI.Pages.TagDatabase
    if not page or not page.Build then
        B.BuildPlaceholderPage(container, L["INFO_TAG_DATABASE_TITLE"] or "Tag Database")
        return
    end

    page.Build(container, {
        GetGUIState = GetGUIState,
        BuildScrollableTabContent = BuildScrollableTabContent,
        BuildPlaceholderPage = B.BuildPlaceholderPage,
    })
end

function B.BuildTextBuilderPage(container)
    local page = ns.GUI.Pages and ns.GUI.Pages.TextBuilder
    if not page or not page.Build then
        B.BuildPlaceholderPage(container, ns.GetLabel(KM.Nav, C.Nav.TEXT_BUILDER))
        return
    end

    page.Build(container, {
        GetGUIState = GetGUIState,
        ResetFlowContainer = ResetFlowContainer,
    })
end

function B.BuildUnitFramePage(container, unitKey)
    local page = ns.GUI.Pages and ns.GUI.Pages.UnitFrame
    if not page or not page.Build then
        B.BuildPlaceholderPage(container, ns.GetLabel(KM.Tabs, C.Tabs.FRAME))
        return
    end

    page.Build(container, unitKey, {
        ResetFlowContainer = ResetFlowContainer,
        AddPageHeading = AddPageHeading,
        AddSectionHeading = AddSectionHeading,
        CreateSection = CreateSection,
        AddLayoutHandle = AddLayoutHandle,
        ResolveLayoutText = ResolveLayoutText,
        ResolveLayoutPath = ResolveLayoutPath,
        ResolveLayoutList = ResolveLayoutList,
        CanBuildLayoutWidget = CanBuildLayoutWidget,
    })
end

function B.BuildUnitElementsPage(container, unitKey)
    container:ReleaseChildren()
    container:SetLayout("Fill")

    local state = GetGUIState()
    state.unitElementTabs[unitKey] = state.unitElementTabs[unitKey] or C.Elements.PORTRAIT
    state.unitElementScroll[unitKey] = state.unitElementScroll[unitKey] or {}

    local tabGroup = AceGUI:Create("TabGroup")
    tabGroup:SetFullWidth(true)
    tabGroup:SetFullHeight(true)
    tabGroup:SetLayout("Fill")
    tabGroup:SetTabs(GetElementTabValues())

    tabGroup:SetCallback("OnGroupSelected", function(widget, _, elementKey)
        state.unitElementTabs[unitKey] = elementKey
        state.unitElementScroll[unitKey][elementKey] = state.unitElementScroll[unitKey][elementKey] or { scrollvalue = 0 }

        BuildScrollableTabContent(widget, state.unitElementScroll[unitKey][elementKey], function(content)
            if elementKey == C.Elements.PORTRAIT then
                BuildUnitPortraitElementPage(content, unitKey)
                return
            elseif elementKey == C.Elements.RAID_TARGET_ICON then
                BuildUnitRaidTargetElementPage(content, unitKey)
                return
            elseif elementKey == C.Elements.LEADER_ICON then
                BuildUnitLeaderIconElementPage(content, unitKey)
                return
            elseif elementKey == C.Elements.ROLE_ICON then
                BuildUnitRoleIconElementPage(content, unitKey)
                return
            elseif elementKey == C.Elements.COMBAT_INDICATOR then
                BuildUnitCombatIndicatorElementPage(content, unitKey)
                return
            elseif elementKey == C.Elements.RESTING_INDICATOR then
                BuildUnitRestingIndicatorElementPage(content, unitKey)
                return
            elseif elementKey == C.Elements.READY_CHECK_INDICATOR then
                BuildUnitReadyCheckIndicatorElementPage(content, unitKey)
                return
            end

            B.BuildPlaceholderPage(content, ns.GetLabel(KM.Elements, elementKey))
        end)
    end)

    container:AddChild(tabGroup)
    tabGroup:SelectTab(state.unitElementTabs[unitKey] or C.Elements.PORTRAIT)
end

function B.BuildUnitColorsPage(container, unitKey)
    local page = ns.GUI.Pages and ns.GUI.Pages.UnitColors
    if not page or not page.Build then
        B.BuildPlaceholderPage(container, ns.GetLabel(KM.Tabs, C.Tabs.COLORS))
        return
    end

    page.Build(container, unitKey, {
        ResetFlowContainer = ResetFlowContainer,
        AddPageHeading = AddPageHeading,
        AddSectionHeading = AddSectionHeading,
        CreateSection = CreateSection,
        AddLayoutHandle = AddLayoutHandle,
        ResolveLayoutText = ResolveLayoutText,
        ResolveLayoutPath = ResolveLayoutPath,
    })
end

function B.BuildUnitHealthBarPage(container, unitKey)
    local page = ns.GUI.Pages and ns.GUI.Pages.UnitBars
    if not page or not page.BuildHealth then
        B.BuildPlaceholderPage(container, ns.GetLabel(KM.Bars, C.Bars.HEALTH))
        return
    end

    page.BuildHealth(container, unitKey, {
        ResetFlowContainer = ResetFlowContainer,
        AddPageHeading = AddPageHeading,
        AddSectionHeading = AddSectionHeading,
        CreateSection = CreateSection,
        AddLayoutHandle = AddLayoutHandle,
        ResolveLayoutText = ResolveLayoutText,
        ResolveLayoutPath = ResolveLayoutPath,
        ResolveLayoutList = ResolveLayoutList,
        CanBuildLayoutWidget = CanBuildLayoutWidget,
    })
end

function B.BuildUnitPowerBarPage(container, unitKey)
    local page = ns.GUI.Pages and ns.GUI.Pages.UnitBars
    if not page or not page.BuildPower then
        B.BuildPlaceholderPage(container, ns.GetLabel(KM.Bars, C.Bars.POWER))
        return
    end

    page.BuildPower(container, unitKey, {
        ResetFlowContainer = ResetFlowContainer,
        AddPageHeading = AddPageHeading,
        AddSectionHeading = AddSectionHeading,
        CreateSection = CreateSection,
        AddLayoutHandle = AddLayoutHandle,
        ResolveLayoutText = ResolveLayoutText,
        ResolveLayoutPath = ResolveLayoutPath,
        ResolveLayoutList = ResolveLayoutList,
        CanBuildLayoutWidget = CanBuildLayoutWidget,
    })
end

function B.BuildUnitAlternativePowerBarPage(container, unitKey)
    local page = ns.GUI.Pages and ns.GUI.Pages.UnitBars
    if not page or not page.BuildAlternativePower then
        B.BuildPlaceholderPage(container, ns.GetLabel(KM.Bars, C.Bars.ALT_POWER))
        return
    end

    page.BuildAlternativePower(container, unitKey, {
        ResetFlowContainer = ResetFlowContainer,
        AddPageHeading = AddPageHeading,
        AddSectionHeading = AddSectionHeading,
        CreateSection = CreateSection,
        AddLayoutHandle = AddLayoutHandle,
        ResolveLayoutText = ResolveLayoutText,
        ResolveLayoutPath = ResolveLayoutPath,
    })
end

function B.BuildUnitCastBarPage(container, unitKey)
    local page = ns.GUI.Pages and ns.GUI.Pages.UnitBars
    if not page or not page.BuildCast then
        B.BuildPlaceholderPage(container, ns.GetLabel(KM.Bars, C.Bars.CAST))
        return
    end

    page.BuildCast(container, unitKey, {
        ResetFlowContainer = ResetFlowContainer,
        AddPageHeading = AddPageHeading,
        AddSectionHeading = AddSectionHeading,
        CreateSection = CreateSection,
        AddLayoutHandle = AddLayoutHandle,
        ResolveLayoutText = ResolveLayoutText,
        ResolveLayoutPath = ResolveLayoutPath,
        ResolveLayoutList = ResolveLayoutList,
        CanBuildLayoutWidget = CanBuildLayoutWidget,
    })
end

function B.BuildUnitTextsPage(container, unitKey)
    local page = ns.GUI.Pages and ns.GUI.Pages.UnitTexts
    if not page or not page.Build then
        B.BuildPlaceholderPage(container, ns.GetLabel(KM.Tabs, C.Tabs.TEXTS))
        return
    end

    page.Build(container, unitKey, {
        GetGUIState = GetGUIState,
        GetTextElementLabel = GetTextElementLabel,
        GetTextTabValues = GetTextTabValues,
        ResetFlowContainer = ResetFlowContainer,
        AddPageHeading = AddPageHeading,
        CreateSection = CreateSection,
        AddLayoutHandle = AddLayoutHandle,
        BuildScrollableTabContent = BuildScrollableTabContent,
        ResolveLayoutText = ResolveLayoutText,
        ResolveLayoutPath = ResolveLayoutPath,
        ResolveLayoutList = ResolveLayoutList,
        CanBuildLayoutWidget = CanBuildLayoutWidget,
        BuildPlaceholderPage = B.BuildPlaceholderPage,
    })
end

function B.BuildUnitBarsPage(container, unitKey)
    local page = ns.GUI.Pages and ns.GUI.Pages.UnitBars
    if not page or not page.BuildTabs then
        B.BuildPlaceholderPage(container, ns.GetLabel(KM.Tabs, C.Tabs.BARS))
        return
    end

    page.BuildTabs(container, unitKey, {
        GetGUIState = GetGUIState,
        GetBarTabValues = GetBarTabValues,
        BuildScrollableTabContent = BuildScrollableTabContent,
        BuildPlaceholderPage = B.BuildPlaceholderPage,
        ResetFlowContainer = ResetFlowContainer,
        AddPageHeading = AddPageHeading,
        AddSectionHeading = AddSectionHeading,
        CreateSection = CreateSection,
        AddLayoutHandle = AddLayoutHandle,
        ResolveLayoutText = ResolveLayoutText,
        ResolveLayoutPath = ResolveLayoutPath,
        ResolveLayoutList = ResolveLayoutList,
        CanBuildLayoutWidget = CanBuildLayoutWidget,
    })
end

local function GetUnitTabValues()
    local tabs = {}

    for _, tabKey in ipairs(C.TabOrder) do
        table.insert(tabs, {
            text = ns.GetLabel(KM.Tabs, tabKey),
            value = tabKey,
        })
    end

    return tabs
end

function B.BuildUnitPage(container, unitKey)
    container:ReleaseChildren()
    container:SetLayout("Fill")

    local state = GetGUIState()
    state.unitTabs[unitKey] = state.unitTabs[unitKey] or C.Tabs.FRAME
    state.unitScroll[unitKey] = state.unitScroll[unitKey] or {}

    local tabGroup = AceGUI:Create("TabGroup")
    tabGroup:SetFullWidth(true)
    tabGroup:SetFullHeight(true)
    tabGroup:SetLayout("Fill")
    tabGroup:SetTabs(GetUnitTabValues())

    tabGroup:SetCallback("OnGroupSelected", function(widget, _, tabKey)
        state.unitTabs[unitKey] = tabKey

        widget:ReleaseChildren()
        widget:SetLayout("Fill")

        if tabKey == C.Tabs.BARS then
            B.BuildUnitBarsPage(widget, unitKey)
            return
        end

        if tabKey == C.Tabs.TEXTS then
            B.BuildUnitTextsPage(widget, unitKey)
            return
        end

        if tabKey == C.Tabs.ELEMENTS then
            B.BuildUnitElementsPage(widget, unitKey)
            return
        end

        state.unitScroll[unitKey][tabKey] = state.unitScroll[unitKey][tabKey] or { scrollvalue = 0 }

        local scroll = AceGUI:Create("ScrollFrame")
        scroll:SetFullWidth(true)
        scroll:SetFullHeight(true)
        scroll:SetLayout("Flow")
        scroll:SetStatusTable(state.unitScroll[unitKey][tabKey])
        widget:AddChild(scroll)

        if tabKey == C.Tabs.FRAME then
            B.BuildUnitFramePage(scroll, unitKey)
            return
        end

        if tabKey == C.Tabs.COLORS then
            B.BuildUnitColorsPage(scroll, unitKey)
            return
        end

        local unitLabel = ns.GetLabel(KM.Units, unitKey)
        local tabLabel = ns.GetLabel(KM.Tabs, tabKey)
        B.BuildPlaceholderPage(scroll, unitLabel .. " - " .. tabLabel)
    end)

    container:AddChild(tabGroup)
    tabGroup:SelectTab(state.unitTabs[unitKey] or C.Tabs.FRAME)
end
