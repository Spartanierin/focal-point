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
local SectionLayout = ns.GUI.Layouts.SectionLayout

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
            unit = C.Units.PLAYER,
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

local function CreateSection(container)
    return SectionLayout.CreateTwoColumn(container, {
        gutter = 16,
        minColumnWidth = 300,
    })
end

local function BuildScrollableTabContent(widget, statusTable, buildFunc)
    widget:ReleaseChildren()
    widget:SetLayout("Fill")

    local scroll = AceGUI:Create("ScrollFrame")
    scroll:SetLayout("Flow")
    scroll:SetFullWidth(true)
    scroll:SetFullHeight(true)
    scroll:SetStatusTable(statusTable)
    widget:AddChild(scroll)

    buildFunc(scroll)

    if scroll.DoLayout then
        scroll:DoLayout()
    end

    if scroll.FixScroll then
        scroll:FixScroll()
    end

    if widget.DoLayout then
        widget:DoLayout()
    end

    if C_Timer and C_Timer.After then
        C_Timer.After(0, function()
            if scroll and scroll.DoLayout then
                scroll:DoLayout()
            end

            if scroll and scroll.FixScroll then
                scroll:FixScroll()
            end

            if widget and widget.DoLayout then
                widget:DoLayout()
            end
        end)
    end
end

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

local function ResolveLayoutText(value)
    if type(value) ~= "string" then
        return value
    end

    return L[value] or value
end

local function ResolveLayoutPath(path, unitKey, replacements)
    if type(path) ~= "table" then
        return path
    end

    local resolved = {}

    for i, part in ipairs(path) do
        if part == "$unitKey" then
            resolved[i] = unitKey
        elseif replacements and replacements[part] ~= nil then
            resolved[i] = replacements[part]
        else
            resolved[i] = part
        end
    end

    return resolved
end

local function ResolveLayoutList(list)
    if type(list) ~= "table" then
        return list
    end

    local resolved = {}

    for key, value in pairs(list) do
        resolved[key] = ResolveLayoutText(value)
    end

    return resolved
end

local function LayoutWidgetRequiresPath(widgetType)
    return widgetType == "checkbox"
        or widgetType == "dropdown"
        or widgetType == "slider"
end

local function IsSupportedLayoutWidget(widgetType)
    return widgetType == "checkbox"
        or widgetType == "dropdown"
        or widgetType == "slider"
end

local function CanBuildLayoutWidget(def, resolvedList)
    if type(def) ~= "table" then
        return false
    end

    if not IsSupportedLayoutWidget(def.widget) then
        return false
    end

    if LayoutWidgetRequiresPath(def.widget) and type(def.path) ~= "table" then
        return false
    end

    if def.widget == "dropdown" and type(resolvedList) ~= "table" then
        return false
    end

    return true
end

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
            layout:Add(Checkbox.Create({
                path = ResolveLayoutPath(def.path, unitKey),
                label = ResolveLayoutText(def.label),
                description = ResolveLayoutText(def.description),
                fallback = def.fallback,
                resetText = L["OPTION_RESET"],
                disabled = ResolveDisabled(def),
                refreshGUI = def.refreshGUI,
            }))
            return
        end

        if def.widget == "dropdown" then
            layout:Add(Dropdown.Create({
                path = ResolveLayoutPath(def.path, unitKey),
                label = ResolveLayoutText(def.label),
                description = ResolveLayoutText(def.description),
                list = resolvedList,
                fallback = def.fallback,
                resetText = L["OPTION_RESET"],
                disabled = ResolveDisabled(def),
                refreshGUI = def.refreshGUI,
            }))
            return
        end

        if def.widget == "slider" then
            layout:Add(Slider.Create({
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
            }))
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
    ResetFlowContainer(container)

    local version = GetAddonVersionText()
    local logoPath = "Interface\\AddOns\\Portrait\\Media\\Icon.tga"
    local function CreateSpacer(height)
        local spacer = AceGUI:Create("Label")
        spacer:SetText(" ")
        spacer:SetFullWidth(true)
        spacer:SetHeight(height or 1)
        return spacer
    end

    local function CreateStyledGeneralOption(config)
        local handle = Checkbox.Create(config)
        if not handle or not handle.group then
            return handle
        end

        if handle.checkbox then
            handle.checkbox:SetWidth(240)
            if handle.checkbox.text and handle.checkbox.text.SetFontObject then
                handle.checkbox.text:SetFontObject(GameFontHighlight)
            end
        end

        local children = handle.group.children or {}
        local row = children[1]
        local description = children[2]
        if row and row.SetFullWidth then
            row:SetFullWidth(true)
        end

        if description and description.SetText then
            if description.SetFont then
                description:SetFont(STANDARD_TEXT_FONT, 10, "")
            end
            description:SetText(string.format("|cff8f98a3    %s|r", config.description or ""))
        end

        handle.group:AddChild(CreateSpacer(6))
        return handle
    end

    local aboutGroup = AceGUI:Create("InlineGroup")
    aboutGroup:SetFullWidth(true)
    aboutGroup:SetLayout("Flow")
    aboutGroup:SetTitle(" ")
    if aboutGroup.titletext and aboutGroup.titletext.SetText then
        aboutGroup.titletext:SetText(" ")
    end
    container:AddChild(aboutGroup)

    aboutGroup:AddChild(CreateSpacer(6))

    local brandLine = AceGUI:Create("Label")
    brandLine:SetFullWidth(true)
    if brandLine.SetFont then
        brandLine:SetFont(STANDARD_TEXT_FONT, 16, "")
    end
    brandLine:SetText(string.format(
        "|T%s:24:24:0:0|t  |cff6fd2ff%s|r",
        logoPath,
        L["ADDON_NAME"] or C.ADDON_NAME
    ))
    aboutGroup:AddChild(brandLine)

    local versionLine = AceGUI:Create("Label")
    versionLine:SetFullWidth(true)
    if versionLine.SetFont then
        versionLine:SetFont(STANDARD_TEXT_FONT, 12, "")
    end
    versionLine:SetText(string.format(
        "|cffd8c27a%s|r  |cff4cff88%s|r",
        L["INFO_VERSION"] or "Version",
        version
    ))
    aboutGroup:AddChild(versionLine)

    aboutGroup:AddChild(CreateSpacer(6))

    local welcome = AceGUI:Create("Label")
    welcome:SetFullWidth(true)
    if welcome.SetFont then
        welcome:SetFont(STANDARD_TEXT_FONT, 13, "")
    end
    welcome:SetText(string.format("|cfff2e4b8%s|r", L["INFO_GENERAL_WELCOME"] or "Welcome to Portrait."))
    aboutGroup:AddChild(welcome)

    aboutGroup:AddChild(CreateSpacer(3))

    local description = AceGUI:Create("Label")
    description:SetFullWidth(true)
    if description.SetFont then
        description:SetFont(STANDARD_TEXT_FONT, 12, "")
    end
    description:SetText(string.format(
        "|cffd7dbe0%s|r",
        L["INFO_GENERAL_DESCRIPTION"] or "Portrait is a modular unit frame addon with configurable frames, bars, texts, and elements."
    ))
    aboutGroup:AddChild(description)

    aboutGroup:AddChild(CreateSpacer(5))

    local hint = AceGUI:Create("Label")
    hint:SetFullWidth(true)
    if hint.SetFont then
        hint:SetFont(STANDARD_TEXT_FONT, 11, "")
    end
    hint:SetText(string.format(
        "|cff9ea8b3%s|r",
        L["INFO_GENERAL_HINT"] or "Use the navigation on the left to configure units, bars, texts, colors, and elements."
    ))
    aboutGroup:AddChild(hint)

    aboutGroup:AddChild(CreateSpacer(8))

    local modeGroup = AceGUI:Create("InlineGroup")
    modeGroup:SetFullWidth(true)
    modeGroup:SetLayout("Flow")
    modeGroup:SetTitle(L["INFO_GENERAL_MODE"] or "Workflow Mode")
    container:AddChild(modeGroup)

    modeGroup:AddChild(CreateSpacer(6))

    local modeLayout = CreateSection(modeGroup)
    modeLayout:Add(CreateStyledGeneralOption({
        path = { "General", "ExpertMode" },
        label = L["OPTION_EXPERT_MODE"] or "Expert Mode",
        description = L["OPTION_EXPERT_MODE_DESC"] or "Enabled: maximum configurability. Disabled = Quick Mode for a faster path to a good result through a template or theme.",
        fallback = true,
        refreshGUI = true,
    }))

    local settingsGroup = AceGUI:Create("InlineGroup")
    settingsGroup:SetFullWidth(true)
    settingsGroup:SetLayout("Flow")
    settingsGroup:SetTitle(L["INFO_GENERAL_SETTINGS"] or "General Settings")
    container:AddChild(settingsGroup)

    settingsGroup:AddChild(CreateSpacer(8))

    local settingsLayout = CreateSection(settingsGroup)

    settingsLayout:Add(CreateStyledGeneralOption({
        path = { "General", "HideBlizzardFrames" },
        label = L["OPTION_HIDE_BLIZZARD_FRAMES"],
        description = L["OPTION_HIDE_BLIZZARD_FRAMES_DESC"],
        fallback = false,
        onChanged = function()
            if ns.ApplyGeneralSettings then
                ns:ApplyGeneralSettings()
            end

            local hideBlizzardFrames = ns.db
                and ns.db.profile
                and ns.db.profile.General
                and ns.db.profile.General.HideBlizzardFrames == true

            if not hideBlizzardFrames and ns.Info then
                ns:Info(L["INFO_RELOAD_REQUIRED_BLIZZARD_FRAMES"])
            end
        end,
    }))

    settingsLayout:Add(CreateStyledGeneralOption({
        path = { "General", "GlobalClickThrough" },
        label = L["OPTION_GLOBAL_CLICKTHROUGH"],
        description = L["OPTION_GLOBAL_CLICKTHROUGH_DESC"],
        fallback = false,
        onChanged = function()
            if ns.RefreshAllUnitFrames then
                ns:RefreshAllUnitFrames()
            end
        end,
    }))

    settingsLayout:Add(CreateStyledGeneralOption({
        path = { "General", "MouseEnabled" },
        label = L["OPTION_MOUSE_ENABLED"],
        description = L["OPTION_MOUSE_ENABLED_DESC"],
        fallback = true,
        onChanged = function()
            if ns.RefreshAllUnitFrames then
                ns:RefreshAllUnitFrames()
            end
        end,
    }))

    settingsLayout:Add(CreateStyledGeneralOption({
        path = { "General", "ClampToScreen" },
        label = L["OPTION_CLAMP_TO_SCREEN"],
        description = L["OPTION_CLAMP_TO_SCREEN_DESC"],
        fallback = true,
        onChanged = function()
            if ns.RefreshAllUnitFrames then
                ns:RefreshAllUnitFrames()
            end
        end,
    }))
end

function B.BuildProfilesPage(container)
    ResetFlowContainer(container)

    local db = ns.db
    if not db then
        B.BuildPlaceholderPage(container, L["NAV_PROFILES"] or "Profiles")
        return
    end

    local function CreateSpacer(height)
        local spacer = AceGUI:Create("Label")
        spacer:SetText(" ")
        spacer:SetFullWidth(true)
        spacer:SetHeight(height or 1)
        return spacer
    end

    local function RefreshProfileUI()
        if ns.GUI and ns.GUI.RefreshOptions then
            ns.GUI:RefreshOptions()
        end
    end

    local function RebuildFramesForProfile()
        if ns.ApplyGeneralSettings then
            ns:ApplyGeneralSettings()
        end

        ns.frames = ns.frames or {}

        for _, unitKey in ipairs(C.UnitOrder) do
            local unitDB = db.profile and db.profile.Units and db.profile.Units[unitKey]
            local enabled = type(unitDB) == "table" and unitDB.enabled ~= false

            if enabled then
                if ns.SpawnUnitFrame then
                    ns:SpawnUnitFrame(unitKey)
                end
            elseif ns.frames[unitKey] then
                ns.frames[unitKey]:Hide()
                ns.frames[unitKey] = nil
            end
        end
    end

    local function SetStatus(message)
        if ns.guiFrame and ns.guiFrame.SetStatusText then
            ns.guiFrame:SetStatusText(message)
        end
    end

    local state = GetGUIState()
    state.profiles = state.profiles or {
        selectedProfile = db:GetCurrentProfile(),
        newProfileName = "",
    }

    local function GetProfileList()
        local list = {}
        local profiles = db:GetProfiles({})
        for _, profileName in ipairs(profiles) do
            list[profileName] = profileName
        end
        return list
    end

    AddPageHeading(container, L["NAV_PROFILES"] or "Profiles")
    container:AddChild(CreateSpacer(2))

    local description = AceGUI:Create("Label")
    description:SetFullWidth(true)
    description:SetText(L["INFO_PROFILES_DESCRIPTION"] or "Manage shared settings across characters.")
    container:AddChild(description)

    container:AddChild(CreateSpacer(4))

    local currentGroup = AceGUI:Create("InlineGroup")
    currentGroup:SetFullWidth(true)
    currentGroup:SetLayout("Flow")
    currentGroup:SetTitle(L["INFO_PROFILES_CURRENT"] or "Current Profile")
    container:AddChild(currentGroup)

    local currentLabel = AceGUI:Create("Label")
    currentLabel:SetFullWidth(true)
    currentLabel:SetText(string.format(
        "|cff6fd2ff%s|r",
        db:GetCurrentProfile() or "Default"
    ))
    currentGroup:AddChild(currentLabel)

    local switchGroup = AceGUI:Create("InlineGroup")
    switchGroup:SetFullWidth(true)
    switchGroup:SetLayout("Flow")
    switchGroup:SetTitle(L["INFO_PROFILES_SWITCH"] or "Switch / Manage")
    container:AddChild(switchGroup)

    local profileSelect = AceGUI:Create("Dropdown")
    profileSelect:SetLabel(L["INFO_PROFILES_SAVED"] or "Saved Profiles")
    profileSelect:SetWidth(260)
    profileSelect:SetList(GetProfileList())
    profileSelect:SetValue(state.profiles.selectedProfile or db:GetCurrentProfile())
    switchGroup:AddChild(profileSelect)

    local activateButton = AceGUI:Create("Button")
    activateButton:SetText(L["INFO_PROFILES_ACTIVATE"] or "Activate")
    activateButton:SetWidth(120)
    switchGroup:AddChild(activateButton)

    local copyButton = AceGUI:Create("Button")
    copyButton:SetText(L["INFO_PROFILES_COPY_FROM"] or "Copy From")
    copyButton:SetWidth(120)
    switchGroup:AddChild(copyButton)

    local deleteButton = AceGUI:Create("Button")
    deleteButton:SetText(L["INFO_PROFILES_DELETE"] or "Delete")
    deleteButton:SetWidth(120)
    switchGroup:AddChild(deleteButton)

    local resetButton = AceGUI:Create("Button")
    resetButton:SetText(L["INFO_PROFILES_RESET"] or "Reset")
    resetButton:SetWidth(120)
    switchGroup:AddChild(resetButton)

    switchGroup:AddChild(CreateSpacer(2))

    local createGroup = AceGUI:Create("InlineGroup")
    createGroup:SetFullWidth(true)
    createGroup:SetLayout("Flow")
    createGroup:SetTitle(L["INFO_PROFILES_CREATE"] or "Create / Switch")
    container:AddChild(createGroup)

    local nameEdit = AceGUI:Create("EditBox")
    nameEdit:SetLabel(L["INFO_PROFILES_NAME"] or "Profile Name")
    nameEdit:SetWidth(260)
    nameEdit:DisableButton(true)
    nameEdit:SetText(state.profiles.newProfileName or "")
    createGroup:AddChild(nameEdit)

    local createButton = AceGUI:Create("Button")
    createButton:SetText(L["INFO_PROFILES_CREATE_AND_SWITCH"] or "Create and Switch")
    createButton:SetWidth(160)
    createGroup:AddChild(createButton)

    profileSelect:SetCallback("OnValueChanged", function(_, _, value)
        state.profiles.selectedProfile = value or db:GetCurrentProfile()
    end)

    nameEdit:SetCallback("OnEnterPressed", function(widget, _, value)
        state.profiles.newProfileName = value or ""
        widget:ClearFocus()
    end)

    nameEdit:SetCallback("OnFocusLost", function(widget)
        state.profiles.newProfileName = widget:GetText() or ""
    end)

    activateButton:SetCallback("OnClick", function()
        local profileName = state.profiles.selectedProfile or db:GetCurrentProfile()
        if not profileName or profileName == "" then
            return
        end

        db:SetProfile(profileName)
        state.profiles.selectedProfile = profileName
        RebuildFramesForProfile()
        RefreshProfileUI()
        SetStatus((L["INFO_PROFILES_STATUS_ACTIVATED"] or "Activated profile:") .. " " .. profileName)
    end)

    copyButton:SetCallback("OnClick", function()
        local profileName = state.profiles.selectedProfile or db:GetCurrentProfile()
        if not profileName or profileName == "" then
            return
        end

        if profileName == db:GetCurrentProfile() then
            SetStatus(L["INFO_PROFILES_STATUS_COPY_SAME"] or "Source and destination profile are identical.")
            return
        end

        db:CopyProfile(profileName)
        RebuildFramesForProfile()
        RefreshProfileUI()
        SetStatus((L["INFO_PROFILES_STATUS_COPIED"] or "Copied profile:") .. " " .. profileName)
    end)

    deleteButton:SetCallback("OnClick", function()
        local profileName = state.profiles.selectedProfile or db:GetCurrentProfile()
        if not profileName or profileName == "" or profileName == db:GetCurrentProfile() then
            return
        end

        db:DeleteProfile(profileName, true)
        state.profiles.selectedProfile = db:GetCurrentProfile()
        RefreshProfileUI()
        SetStatus((L["INFO_PROFILES_STATUS_DELETED"] or "Deleted profile:") .. " " .. profileName)
    end)

    resetButton:SetCallback("OnClick", function()
        local currentProfile = db:GetCurrentProfile()
        db:ResetProfile()
        RebuildFramesForProfile()
        RefreshProfileUI()
        SetStatus((L["INFO_PROFILES_STATUS_RESET"] or "Reset profile:") .. " " .. currentProfile)
    end)

    createButton:SetCallback("OnClick", function()
        local profileName = (nameEdit:GetText() or ""):gsub("^%s+", ""):gsub("%s+$", "")
        if profileName == "" then
            return
        end

        db:SetProfile(profileName)
        state.profiles.selectedProfile = profileName
        state.profiles.newProfileName = profileName
        RebuildFramesForProfile()
        RefreshProfileUI()
        SetStatus((L["INFO_PROFILES_STATUS_CREATED"] or "Created profile:") .. " " .. profileName)
    end)
end

function B.BuildTagDatabasePage(container)
    container:ReleaseChildren()
    container:SetLayout("Fill")

    local state = GetGUIState()
    local tagDatabase = ns.UnitFrame and ns.UnitFrame.GetTagDatabase and ns.UnitFrame:GetTagDatabase() or {}
    local grouped = {}
    local categoryOrder = {
        "INFO_TAG_CATEGORY_FORMAT",
        "INFO_TAG_CATEGORY_HEALTH",
        "INFO_TAG_CATEGORY_POWER",
        "INFO_TAG_CATEGORY_CAST",
        "INFO_TAG_CATEGORY_UNIT",
        "INFO_TAG_CATEGORY_STATUS",
    }

    for _, def in ipairs(tagDatabase) do
        grouped[def.category] = grouped[def.category] or {}
        table.insert(grouped[def.category], def)
    end

    local tabs = {}
    for _, categoryKey in ipairs(categoryOrder) do
        if grouped[categoryKey] and #grouped[categoryKey] > 0 then
            table.insert(tabs, {
                text = L[categoryKey] or categoryKey,
                value = categoryKey,
            })
        end
    end

    local firstTab = tabs[1] and tabs[1].value or nil
    if not firstTab then
        B.BuildPlaceholderPage(container, L["INFO_TAG_DATABASE_TITLE"] or "Tag Database")
        return
    end

    state.tagDatabaseTab = state.tagDatabaseTab or firstTab
    state.tagDatabaseScroll = state.tagDatabaseScroll or {}

    local function CreateLocalSpacer(height)
        local spacer = AceGUI:Create("Label")
        spacer:SetText(" ")
        spacer:SetFullWidth(true)
        spacer:SetHeight(height or 1)
        return spacer
    end

    local function ResolveTagAppliesTo(def)
        local token = type(def.token) == "string" and def.token or ""

        if token == "[guild]" or token == "[realm]" or token == "[race]" then
            return L["INFO_TAG_DATABASE_APPLIES_PLAYERS"] or "Players"
        end

        if token == "[color:class]" or token == "[color:blizz_pwr]" or token == "[color:blizz_yellow]" or token == "[color:blizz_red]" or token == "[color:blizz_green]" or token == "[color:blizz_highlight]" or token == "[color:ffcc00]" or token == "[rc]" then
            return L["INFO_TAG_DATABASE_APPLIES_TEMPLATES"] or "Templates"
        end

        if token == "[color:reaction]" then
            return L["INFO_TAG_DATABASE_APPLIES_REACTION"] or "Units with Reaction"
        end

        if token == "[classification]" or token == "[family]" or token == "[type]" or token == "[creature]" then
            return L["INFO_TAG_DATABASE_APPLIES_NPCS"] or "NPCs / Pets"
        end

        if token == "[cast:name]" or token == "[cast:time]" then
            return L["INFO_TAG_DATABASE_APPLIES_CAST"] or "Casting Units"
        end

        if token == "[resting]" or token == "[combat]" or token == "[pvp]" or token == "[afk]" or token == "[dnd]" or token == "[dead]" or token == "[offline]" or token == "[leader]" or token == "[role]" then
            return L["INFO_TAG_DATABASE_APPLIES_STATUS"] or "Units with State"
        end

        if token == "[altpower:cur]" or token == "[altpower:max]" or token == "[altpower:cur:abbr]" or token == "[altpower:max:abbr]" then
            return L["INFO_TAG_DATABASE_APPLIES_PLAYER_ALT"] or "Player (AltPower)"
        end

        return L["INFO_TAG_DATABASE_APPLIES_ALL"] or "All"
    end

    local root = AceGUI:Create("SimpleGroup")
    root:SetFullWidth(true)
    root:SetFullHeight(true)
    root:SetLayout("Flow")
    container:AddChild(root)

    local introGroup = AceGUI:Create("InlineGroup")
    introGroup:SetFullWidth(true)
    introGroup:SetLayout("Flow")
    introGroup:SetTitle(L["INFO_TAG_DATABASE_TITLE"] or "Tag Database")
    root:AddChild(introGroup)

    local description = AceGUI:Create("Label")
    description:SetFullWidth(true)
    if description.SetFont then
        description:SetFont(STANDARD_TEXT_FONT, 12, "")
    end
    description:SetText(string.format("|cffcfd5dd%s|r", L["INFO_TAG_DATABASE_DESCRIPTION"] or ""))
    introGroup:AddChild(description)

    introGroup:AddChild(CreateLocalSpacer(2))

    local hint = AceGUI:Create("Label")
    hint:SetFullWidth(true)
    if hint.SetFont then
        hint:SetFont(STANDARD_TEXT_FONT, 12, "")
    end
    hint:SetText(string.format("|cff6fd2ff%s|r", L["INFO_TAG_DATABASE_TEMPLATE_HINT"] or ""))
    introGroup:AddChild(hint)

    root:AddChild(CreateLocalSpacer(2))

    local referenceGroup = AceGUI:Create("InlineGroup")
    referenceGroup:SetFullWidth(true)
    referenceGroup:SetFullHeight(true)
    referenceGroup:SetLayout("Fill")
    referenceGroup:SetTitle(L["INFO_TAG_DATABASE_REFERENCE"] or "Reference")
    root:AddChild(referenceGroup)

    local tabGroup = AceGUI:Create("TabGroup")
    tabGroup:SetFullWidth(true)
    tabGroup:SetFullHeight(true)
    tabGroup:SetLayout("Fill")
    tabGroup:SetTabs(tabs)

    tabGroup:SetCallback("OnGroupSelected", function(widget, _, categoryKey)
        state.tagDatabaseTab = categoryKey
        state.tagDatabaseScroll[categoryKey] = state.tagDatabaseScroll[categoryKey] or { scrollvalue = 0 }

        BuildScrollableTabContent(widget, state.tagDatabaseScroll[categoryKey], function(content)
            local categoryLabel = AceGUI:Create("Label")
            categoryLabel:SetFullWidth(true)
            if categoryLabel.SetFont then
                categoryLabel:SetFont(STANDARD_TEXT_FONT, 13, "")
            end
            categoryLabel:SetText(string.format("|cffe6d6a8%s|r", L[categoryKey] or categoryKey))
            content:AddChild(categoryLabel)

            content:AddChild(CreateLocalSpacer(2))

            local headerRow = AceGUI:Create("SimpleGroup")
            headerRow:SetFullWidth(true)
            headerRow:SetLayout("Flow")
            content:AddChild(headerRow)

            local function AddHeaderCell(text, width)
                local label = AceGUI:Create("Label")
                label:SetWidth(width)
                if label.SetFont then
                    label:SetFont(STANDARD_TEXT_FONT, 11, "")
                end
                label:SetText(string.format("|cff9a9a9a%s|r", text))
                headerRow:AddChild(label)
            end

            AddHeaderCell(L["INFO_TAG_DATABASE_COL_TAG"] or "Tag", 170)
            AddHeaderCell(L["INFO_TAG_DATABASE_COL_DESC"] or "Description", 320)
            AddHeaderCell(L["INFO_TAG_DATABASE_COL_EXAMPLE"] or "Example", 120)
            AddHeaderCell(L["INFO_TAG_DATABASE_COL_APPLIES"] or "Applies To", 160)

            content:AddChild(CreateLocalSpacer(1))

            for _, def in ipairs(grouped[categoryKey] or {}) do
                local row = AceGUI:Create("SimpleGroup")
                row:SetFullWidth(true)
                row:SetLayout("Flow")
                content:AddChild(row)

                local tokenLabel = AceGUI:Create("Label")
                tokenLabel:SetWidth(170)
                if tokenLabel.SetFont then
                    tokenLabel:SetFont(STANDARD_TEXT_FONT, 12, "")
                end
                tokenLabel:SetText(string.format("|cff6fd2ff%s|r", def.token))
                row:AddChild(tokenLabel)

                local descriptionLabel = AceGUI:Create("Label")
                descriptionLabel:SetWidth(320)
                if descriptionLabel.SetFont then
                    descriptionLabel:SetFont(STANDARD_TEXT_FONT, 11, "")
                end
                descriptionLabel:SetText(string.format("|cffd7d2c8%s|r", L[def.description] or def.description))
                row:AddChild(descriptionLabel)

                local exampleLabel = AceGUI:Create("Label")
                exampleLabel:SetWidth(120)
                if exampleLabel.SetFont then
                    exampleLabel:SetFont(STANDARD_TEXT_FONT, 11, "")
                end
                exampleLabel:SetText(string.format("|cffe6d6a8%s|r", def.example or ""))
                row:AddChild(exampleLabel)

                local appliesLabel = AceGUI:Create("Label")
                appliesLabel:SetWidth(160)
                if appliesLabel.SetFont then
                    appliesLabel:SetFont(STANDARD_TEXT_FONT, 11, "")
                end
                appliesLabel:SetText(string.format("|cff9a9a9a%s|r", ResolveTagAppliesTo(def)))
                row:AddChild(appliesLabel)
            end
        end)
    end)

    referenceGroup:AddChild(tabGroup)
    tabGroup:SelectTab(state.tagDatabaseTab or firstTab)
end

function B.BuildTextBuilderPage(container)
    ResetFlowContainer(container)

    local state = GetGUIState()
    state.textBuilder = state.textBuilder or {
        template = "[hp:cur:abbr]/[hp:max:abbr] | [hp:perc]%",
        templateName = "",
        selectedTemplate = "",
        applyUnits = {
            [C.Units.PLAYER] = true,
            [C.Units.TARGET] = false,
            [C.Units.FOCUS] = false,
            [C.Units.PET] = false,
        },
    }

    local function CreateSpacer(height)
        local spacer = AceGUI:Create("Label")
        spacer:SetText(" ")
        spacer:SetFullWidth(true)
        spacer:SetHeight(height or 1)
        return spacer
    end

    local introGroup = AceGUI:Create("InlineGroup")
    introGroup:SetFullWidth(true)
    introGroup:SetLayout("Flow")
    introGroup:SetTitle(L["INFO_TEXT_BUILDER_TITLE"] or "Text Builder")
    container:AddChild(introGroup)

    local description = AceGUI:Create("Label")
    description:SetFullWidth(true)
    if description.SetFont then
        description:SetFont(STANDARD_TEXT_FONT, 12, "")
    end
    description:SetText(string.format("|cffcfd5dd%s|r", L["INFO_TEXT_BUILDER_DESCRIPTION"] or ""))
    introGroup:AddChild(description)

    introGroup:AddChild(CreateSpacer(2))

    local hint = AceGUI:Create("Label")
    hint:SetFullWidth(true)
    if hint.SetFont then
        hint:SetFont(STANDARD_TEXT_FONT, 12, "")
    end
    hint:SetText(string.format("|cff6fd2ff%s|r", L["INFO_TEXT_BUILDER_TEMPLATE_HINT"] or ""))
    introGroup:AddChild(hint)

    container:AddChild(CreateSpacer(3))

    local builderGroup = AceGUI:Create("InlineGroup")
    builderGroup:SetFullWidth(true)
    builderGroup:SetLayout("Flow")
    builderGroup:SetTitle(L["INFO_TEXT_BUILDER_TEMPLATE"] or "Template")
    container:AddChild(builderGroup)

    local templateEdit = AceGUI:Create("EditBox")
    templateEdit:SetLabel(L["INFO_TEXT_BUILDER_TEMPLATE"] or "Template")
    templateEdit:SetWidth(520)
    templateEdit:DisableButton(true)
    templateEdit:SetText(state.textBuilder.template or "")
    builderGroup:AddChild(templateEdit)

    local updateButton = AceGUI:Create("Button")
    updateButton:SetText(L["INFO_TEXT_BUILDER_APPLY"] or "Update Preview")
    updateButton:SetWidth(150)
    builderGroup:AddChild(updateButton)

    container:AddChild(CreateSpacer(2))

    local previewGroup = AceGUI:Create("InlineGroup")
    previewGroup:SetFullWidth(true)
    previewGroup:SetLayout("Flow")
    previewGroup:SetTitle(L["INFO_TEXT_BUILDER_PREVIEW"] or "Preview")
    container:AddChild(previewGroup)

    local previewLabel = AceGUI:Create("Label")
    previewLabel:SetFullWidth(true)
    if previewLabel.SetFont then
        previewLabel:SetFont(STANDARD_TEXT_FONT, 14, "")
    end
    if previewLabel.label and previewLabel.label.SetJustifyH then
        previewLabel.label:SetJustifyH("LEFT")
    end
    if previewLabel.label and previewLabel.label.SetJustifyV then
        previewLabel.label:SetJustifyV("MIDDLE")
    end
    previewLabel:SetHeight(28)
    previewLabel:SetText(" ")
    previewGroup:AddChild(previewLabel)

    container:AddChild(CreateSpacer(2))

    local templatesGroup = AceGUI:Create("InlineGroup")
    templatesGroup:SetFullWidth(true)
    templatesGroup:SetLayout("Flow")
    templatesGroup:SetTitle(L["INFO_TEXT_BUILDER_TEMPLATES"] or "Templates")
    container:AddChild(templatesGroup)

    local templates = (ns.db and ns.db.profile and ns.db.profile.TextTemplates) or {}

    local templateSelect = AceGUI:Create("Dropdown")
    templateSelect:SetLabel(L["INFO_TEXT_BUILDER_SAVED_TEMPLATES"] or "Saved Templates")
    templateSelect:SetWidth(260)
    templatesGroup:AddChild(templateSelect)

    local templateNameEdit = AceGUI:Create("EditBox")
    templateNameEdit:SetLabel(L["INFO_TEXT_BUILDER_TEMPLATE_NAME"] or "Template Name")
    templateNameEdit:SetWidth(300)
    templateNameEdit:DisableButton(true)
    templateNameEdit:SetText(state.textBuilder.templateName or "")
    templatesGroup:AddChild(templateNameEdit)

    local saveButton = AceGUI:Create("Button")
    saveButton:SetText(L["INFO_TEXT_BUILDER_SAVE"] or "Save")
    saveButton:SetWidth(110)
    templatesGroup:AddChild(saveButton)

    local updateTemplateButton = AceGUI:Create("Button")
    updateTemplateButton:SetText(L["INFO_TEXT_BUILDER_UPDATE"] or "Update")
    updateTemplateButton:SetWidth(110)
    templatesGroup:AddChild(updateTemplateButton)

    local deleteTemplateButton = AceGUI:Create("Button")
    deleteTemplateButton:SetText(L["INFO_TEXT_BUILDER_DELETE"] or "Delete")
    deleteTemplateButton:SetWidth(110)
    templatesGroup:AddChild(deleteTemplateButton)

    container:AddChild(CreateSpacer(2))

    local usageGroup = AceGUI:Create("InlineGroup")
    usageGroup:SetFullWidth(true)
    usageGroup:SetLayout("Flow")
    usageGroup:SetTitle(L["INFO_TEXT_BUILDER_TEMPLATE_USAGE"] or "Template Usage")
    container:AddChild(usageGroup)

    local usageHint = AceGUI:Create("Label")
    usageHint:SetFullWidth(true)
    usageHint:SetText(L["INFO_TEXT_BUILDER_TEMPLATE_USAGE_HINT"] or "Checked units already use the selected template. Uncheck to remove the template link from that unit.")
    usageGroup:AddChild(usageHint)

    local usageRow = AceGUI:Create("SimpleGroup")
    usageRow:SetFullWidth(true)
    usageRow:SetLayout("Flow")
    usageGroup:AddChild(usageRow)

    local usageCheckboxes = {}

    container:AddChild(CreateSpacer(2))

    local applyGroup = AceGUI:Create("InlineGroup")
    applyGroup:SetFullWidth(true)
    applyGroup:SetLayout("Flow")
    applyGroup:SetTitle(L["INFO_TEXT_BUILDER_APPLY_TO_TEXT"] or "Apply To Text")
    container:AddChild(applyGroup)

    local applyTemplateButton = AceGUI:Create("Button")
    applyTemplateButton:SetText(L["INFO_TEXT_BUILDER_APPLY_TEMPLATE"] or "Apply Template")
    applyTemplateButton:SetWidth(160)
    applyGroup:AddChild(applyTemplateButton)

    local function RefreshPreview()
        local template = state.textBuilder.template or ""
        local previewText = ""

        if ns.UnitFrame and ns.UnitFrame.BuildTemplatePreview then
            previewText = ns.UnitFrame:BuildTemplatePreview(template)
        end

        if previewText == "" then
            previewText = template
        end

        previewLabel:SetText(previewText)
    end

    local function SetStatus(message)
        if ns.guiFrame and ns.guiFrame.SetStatusText then
            ns.guiFrame:SetStatusText(message)
        end
    end

    local function TextConfigUsesTemplate(textConfig, templateName, templateValue)
        if type(textConfig) ~= "table" then
            return false
        end

        if type(templateName) == "string" and templateName ~= "" and textConfig.templateName == templateName then
            return true
        end

        if type(templateValue) == "string" and templateValue ~= "" and textConfig.tag == templateValue then
            return true
        end

        return false
    end

    local function GetTemplateUsageCounts(templateName)
        local usage = {
            [C.Units.PLAYER] = 0,
            [C.Units.TARGET] = 0,
            [C.Units.FOCUS] = 0,
            [C.Units.PET] = 0,
        }
        local templateValue = templates[templateName]

        if type(templateName) ~= "string" or templateName == "" then
            return usage
        end

        local units = ns.db and ns.db.profile and ns.db.profile.Units or {}
        for unitKey, unitConfig in pairs(units) do
            local texts = type(unitConfig) == "table" and unitConfig.Texts or nil
            if type(texts) == "table" and usage[unitKey] ~= nil then
                for _, textConfig in pairs(texts) do
                    if TextConfigUsesTemplate(textConfig, templateName, templateValue) then
                        usage[unitKey] = usage[unitKey] + 1
                    end
                end
            end
        end

        return usage
    end

    local function SyncDesiredTemplateUsage()
        local selectedTemplateName = state.textBuilder.selectedTemplate or ""
        local usageCounts = GetTemplateUsageCounts(selectedTemplateName)

        state.textBuilder.applyUnits = state.textBuilder.applyUnits or {}
        for _, unitKey in ipairs({ C.Units.PLAYER, C.Units.TARGET, C.Units.FOCUS, C.Units.PET }) do
            state.textBuilder.applyUnits[unitKey] = (usageCounts[unitKey] or 0) > 0
        end
    end

    local function UnlinkTemplateFromUnit(unitKey, templateName)
        local unitConfig = ns.db and ns.db.profile and ns.db.profile.Units and ns.db.profile.Units[unitKey]
        local texts = unitConfig and unitConfig.Texts
        local changed = false
        local templateValue = templates[templateName]

        if type(texts) ~= "table" then
            return false
        end

        for _, textConfig in pairs(texts) do
            if TextConfigUsesTemplate(textConfig, templateName, templateValue) then
                textConfig.templateName = ""
                if type(templateValue) == "string" and templateValue ~= "" and textConfig.tag == templateValue then
                    textConfig.tag = ""
                end
                if (textConfig.templateName == nil or textConfig.templateName == "")
                    and (textConfig.tag == nil or textConfig.tag == "")
                then
                    textConfig.enabled = false
                end
                changed = true
            end
        end

        return changed
    end

    local function RefreshTemplateUsageState()
        local selectedTemplateName = state.textBuilder.selectedTemplate or ""
        local usageCounts = GetTemplateUsageCounts(selectedTemplateName)

        for unitKey, checkbox in pairs(usageCheckboxes) do
            local count = usageCounts[unitKey] or 0
            local label = ns.GetLabel(KM.Units, unitKey)
            if count > 0 then
                label = string.format("%s (%d)", label, count)
            end
            checkbox:SetLabel(label)
            checkbox:SetValue(state.textBuilder.applyUnits and state.textBuilder.applyUnits[unitKey] == true)
            checkbox:SetDisabled(selectedTemplateName == "")
        end
    end

    local function CreateTemplateUsageCheckbox(unitKey)
        local checkbox = AceGUI:Create("CheckBox")
        checkbox:SetWidth(140)
        checkbox:SetLabel(ns.GetLabel(KM.Units, unitKey))
        checkbox:SetValue(false)
        checkbox:SetDisabled(true)
        checkbox:SetCallback("OnValueChanged", function(widget, _, value)
            local selectedTemplateName = state.textBuilder.selectedTemplate or ""

            if selectedTemplateName == "" then
                widget:SetValue(false)
                return
            end

            state.textBuilder.applyUnits = state.textBuilder.applyUnits or {}
            state.textBuilder.applyUnits[unitKey] = value and true or false
            RefreshTemplateUsageState()
        end)
        usageRow:AddChild(checkbox)
        usageCheckboxes[unitKey] = checkbox
    end

    CreateTemplateUsageCheckbox(C.Units.PLAYER)
    CreateTemplateUsageCheckbox(C.Units.TARGET)
    CreateTemplateUsageCheckbox(C.Units.FOCUS)
    CreateTemplateUsageCheckbox(C.Units.PET)

    local function RefreshTemplateDropdown()
        local list = {}

        for name in pairs(templates) do
            list[name] = name
        end

        templateSelect:SetList(list)
        templateSelect:SetValue(state.textBuilder.selectedTemplate or nil)
        SyncDesiredTemplateUsage()
        RefreshTemplateUsageState()
    end

    local function GetNextTextElementSlot(unitKey)
        local candidateSlots = { "Custom1", "Custom2", "Custom3" }

        for _, slotKey in ipairs(candidateSlots) do
            local textConfig = ns.GUI.Helpers.OptionValues.Get({ "Units", unitKey, "Texts", slotKey }, {}) or {}
            local hasTemplateName = type(textConfig.templateName) == "string" and textConfig.templateName ~= ""
            local hasTag = type(textConfig.tag) == "string" and textConfig.tag ~= ""
            local isEnabled = textConfig.enabled == true

            if (not isEnabled) or (not hasTemplateName and not hasTag) then
                return slotKey
            end
        end

        return nil
    end

    local function ApplyTemplateToTextSlot()
        local template = templateEdit:GetText() or ""
        local selectedTemplateName = state.textBuilder.selectedTemplate or ""
        local linkedTemplateName = ""
        local unitsToAdd = {}
        local unitsToRemove = {}
        local usageCounts = GetTemplateUsageCounts(selectedTemplateName)

        if type(templates[selectedTemplateName]) == "string" and templates[selectedTemplateName] == template then
            linkedTemplateName = selectedTemplateName
        else
            local currentName = state.textBuilder.templateName or ""
            if type(templates[currentName]) == "string" and templates[currentName] == template then
                linkedTemplateName = currentName
            end
        end

        for _, unitKey in ipairs({ C.Units.PLAYER, C.Units.TARGET, C.Units.FOCUS, C.Units.PET }) do
            local wantsLinked = state.textBuilder.applyUnits and state.textBuilder.applyUnits[unitKey] == true
            local isLinked = (usageCounts[unitKey] or 0) > 0

            if wantsLinked and not isLinked then
                unitsToAdd[#unitsToAdd + 1] = unitKey
            elseif (not wantsLinked) and isLinked then
                unitsToRemove[#unitsToRemove + 1] = unitKey
            end
        end

        if #unitsToAdd == 0 and #unitsToRemove == 0 then
            SetStatus(L["INFO_TEXT_BUILDER_STATUS_SELECT_UNIT"] or "Select at least one unit.")
            return
        end

        local appliedEntries = {}
        local removedEntries = {}
        local skippedUnits = {}

        for _, unitKey in ipairs(unitsToAdd) do
            local slotKey = GetNextTextElementSlot(unitKey)
            if not slotKey then
                skippedUnits[#skippedUnits + 1] = ns.GetLabel(KM.Units, unitKey)
            else
                ns.GUI.Helpers.OptionValues.Set({ "Units", unitKey, "Texts", slotKey, "enabled" }, true)
                ns.GUI.Helpers.OptionValues.Set({ "Units", unitKey, "Texts", slotKey, "tag" }, template)
                ns.GUI.Helpers.OptionValues.Set({ "Units", unitKey, "Texts", slotKey, "templateName" }, linkedTemplateName)
                appliedEntries[#appliedEntries + 1] = string.format("%s -> %s", ns.GetLabel(KM.Units, unitKey), slotKey)
            end
        end

        for _, unitKey in ipairs(unitsToRemove) do
            if UnlinkTemplateFromUnit(unitKey, selectedTemplateName) then
                removedEntries[#removedEntries + 1] = ns.GetLabel(KM.Units, unitKey)
            end
        end

        ns.GUI.Helpers.OptionRefresh.Live()

        if ns.GUI and ns.GUI.RefreshOptions then
            ns.GUI:RefreshOptions()
        end

        local statusParts = {}

        if #appliedEntries > 0 then
            statusParts[#statusParts + 1] = (L["INFO_TEXT_BUILDER_STATUS_APPLIED_TO"] or "Applied to") .. ": " .. table.concat(appliedEntries, ", ")
        end

        if #removedEntries > 0 then
            statusParts[#statusParts + 1] = (L["INFO_TEXT_BUILDER_TEMPLATE_USAGE_UNLINKED"] or "Template unlinked from") .. ": " .. table.concat(removedEntries, ", ")
        end

        local statusText = table.concat(statusParts, " | ")
        if linkedTemplateName ~= "" and statusText ~= "" then
            statusText = statusText .. " (" .. linkedTemplateName .. ")"
        end
        if #appliedEntries == 0 and #removedEntries == 0 then
            statusText = L["INFO_TEXT_BUILDER_STATUS_NO_FREE_SLOT"] or "No free text element available for the selected units."
        elseif #skippedUnits > 0 then
            statusText = statusText .. " | " .. (L["INFO_TEXT_BUILDER_STATUS_SKIPPED_UNITS"] or "Skipped") .. ": " .. table.concat(skippedUnits, ", ")
        end

        SetStatus(statusText)
        SyncDesiredTemplateUsage()
        RefreshTemplateUsageState()
    end

    templateEdit:SetCallback("OnEnterPressed", function(widget, _, value)
        state.textBuilder.template = value or ""
        RefreshPreview()
        widget:ClearFocus()
    end)

    templateEdit:SetCallback("OnFocusLost", function(widget)
        state.textBuilder.template = widget:GetText() or ""
        RefreshPreview()
    end)

    updateButton:SetCallback("OnClick", function()
        state.textBuilder.template = templateEdit:GetText() or ""
        RefreshPreview()
    end)

    applyTemplateButton:SetCallback("OnClick", function()
        ApplyTemplateToTextSlot()
    end)

    templateNameEdit:SetCallback("OnEnterPressed", function(widget, _, value)
        state.textBuilder.templateName = value or ""
        widget:ClearFocus()
    end)

    templateNameEdit:SetCallback("OnFocusLost", function(widget)
        state.textBuilder.templateName = widget:GetText() or ""
    end)

    templateSelect:SetCallback("OnValueChanged", function(_, _, value)
        local selectedName = value or ""
        local selectedTemplate = templates[selectedName]

        state.textBuilder.selectedTemplate = selectedName
        state.textBuilder.templateName = selectedName
        templateNameEdit:SetText(selectedName)

        if type(selectedTemplate) == "string" then
            state.textBuilder.template = selectedTemplate
            templateEdit:SetText(selectedTemplate)
            RefreshPreview()
        end

        SyncDesiredTemplateUsage()
        RefreshTemplateUsageState()
    end)

    saveButton:SetCallback("OnClick", function()
        local name = (templateNameEdit:GetText() or ""):gsub("^%s+", ""):gsub("%s+$", "")
        local template = templateEdit:GetText() or ""

        if name == "" then
            SetStatus(L["INFO_TEXT_BUILDER_STATUS_NAME_REQUIRED"] or "Please enter a template name.")
            return
        end

        templates[name] = template
        state.textBuilder.selectedTemplate = name
        state.textBuilder.templateName = name
        state.textBuilder.template = template
        RefreshTemplateDropdown()
        SetStatus((L["INFO_TEXT_BUILDER_STATUS_SAVED"] or "Template saved:") .. " " .. name)
    end)

    updateTemplateButton:SetCallback("OnClick", function()
        local selectedName = state.textBuilder.selectedTemplate or ""
        local template = templateEdit:GetText() or ""

        if selectedName == "" or type(templates[selectedName]) ~= "string" then
            SetStatus(L["INFO_TEXT_BUILDER_STATUS_SELECT_TEMPLATE"] or "Select a saved template first.")
            return
        end

        templates[selectedName] = template
        state.textBuilder.template = template
        RefreshTemplateDropdown()
        SetStatus((L["INFO_TEXT_BUILDER_STATUS_UPDATED"] or "Template updated:") .. " " .. selectedName)
    end)

    deleteTemplateButton:SetCallback("OnClick", function()
        local selectedName = state.textBuilder.selectedTemplate or ""

        if selectedName == "" or type(templates[selectedName]) ~= "string" then
            SetStatus(L["INFO_TEXT_BUILDER_STATUS_SELECT_TEMPLATE"] or "Select a saved template first.")
            return
        end

        templates[selectedName] = nil
        state.textBuilder.selectedTemplate = ""
        state.textBuilder.templateName = ""
        templateNameEdit:SetText("")
        RefreshTemplateDropdown()
        SetStatus((L["INFO_TEXT_BUILDER_STATUS_DELETED"] or "Template deleted:") .. " " .. selectedName)
    end)

    RefreshTemplateDropdown()
    RefreshPreview()
    SyncDesiredTemplateUsage()
    RefreshTemplateUsageState()
end

function B.BuildUnitFramePage(container, unitKey)
    ResetFlowContainer(container)

    local unitLabel = ns.GetLabel(KM.Units, unitKey)

    local function IsUnitDisabled()
        return not ns.GUI.Helpers.OptionValues.Get({ "Units", unitKey, "enabled" }, true)
    end

    local FRAME_TAB_LISTS = ns.GUI.Layouts.UnitFrame.Lists
    local FRAME_TAB_LAYOUT = ns.GUI.Layouts.UnitFrame.FrameTab

    AddPageHeading(container, unitLabel .. " - " .. ns.GetLabel(KM.Tabs, C.Tabs.FRAME))

    local function AddDirectCheckbox(def)
        if not CanBuildLayoutWidget(def) then
            return
        end

        local checkbox = AceGUI:Create("CheckBox")
        local path = ResolveLayoutPath(def.path, unitKey)
        checkbox:SetLabel(ResolveLayoutText(def.label))
        checkbox:SetValue(ns.GUI.Helpers.OptionValues.Get(path, def.fallback) and true or false)
        checkbox:SetFullWidth(true)
        checkbox:SetDisabled(path[3] ~= "enabled" and IsUnitDisabled())
        checkbox:SetCallback("OnValueChanged", function(_, _, newValue)
            if path[3] ~= "enabled" and IsUnitDisabled() then
                return
            end

            ns.GUI.Helpers.OptionValues.Set(path, newValue and true or false)
            ns.GUI.Helpers.OptionRefresh.Live()

            if def.refreshGUI then
                ns.GUI:RefreshOptions()
            end
        end)
        container:AddChild(checkbox)

        if def.description and def.description ~= "" then
            local description = AceGUI:Create("Label")
            description:SetFullWidth(true)
            description:SetText(ResolveLayoutText(def.description))
            container:AddChild(description)
        end
    end

    local function AddDirectLayerDropdown(def)
        local resolvedList = def.list and ResolveLayoutList(FRAME_TAB_LISTS[def.list]) or nil

        if not CanBuildLayoutWidget(def, resolvedList) then
            return
        end

        local dropdown = AceGUI:Create("Dropdown")
        local path = ResolveLayoutPath(def.path, unitKey)
        dropdown:SetLabel(ResolveLayoutText(def.label))
        dropdown:SetList(resolvedList)
        dropdown:SetWidth(220)
        dropdown:SetValue(ns.GUI.Helpers.OptionValues.Get(path, def.fallback))
        dropdown:SetDisabled(IsUnitDisabled())
        dropdown:SetCallback("OnValueChanged", function(_, _, newValue)
            if IsUnitDisabled() then
                return
            end

            ns.GUI.Helpers.OptionValues.Set(path, newValue)
            ns.GUI.Helpers.OptionRefresh.Live()
        end)
        container:AddChild(dropdown)

        if def.description and def.description ~= "" then
            local description = AceGUI:Create("Label")
            description:SetFullWidth(true)
            description:SetText(ResolveLayoutText(def.description))
            container:AddChild(description)
        end
    end

    local function AddDirectLayerSlider(def)
        if not CanBuildLayoutWidget(def) then
            return
        end

        local slider = AceGUI:Create("Slider")
        local path = ResolveLayoutPath(def.path, unitKey)
        slider:SetLabel(ResolveLayoutText(def.label))
        slider:SetSliderValues(def.min, def.max, def.step)
        slider:SetWidth(220)
        slider:SetValue(tonumber(ns.GUI.Helpers.OptionValues.Get(path, def.fallback)) or def.fallback)
        slider:SetDisabled(IsUnitDisabled())
        slider:SetCallback("OnValueChanged", function(_, _, newValue)
            if IsUnitDisabled() then
                return
            end

            ns.GUI.Helpers.OptionValues.Set(path, tonumber(newValue) or def.fallback)
            ns.GUI.Helpers.OptionRefresh.Live()
        end)
        container:AddChild(slider)

        if def.description and def.description ~= "" then
            local description = AceGUI:Create("Label")
            description:SetFullWidth(true)
            description:SetText(ResolveLayoutText(def.description))
            container:AddChild(description)
        end
    end

    local function AddSectionWidget(layout, def)  
        local resolvedList = def.list and ResolveLayoutList(FRAME_TAB_LISTS[def.list]) or nil

        if not CanBuildLayoutWidget(def, resolvedList) then
            return
        end

        if def.widget == "slider" then
            layout:Add(Slider.Create({
                path = ResolveLayoutPath(def.path, unitKey),
                label = ResolveLayoutText(def.label),
                description = ResolveLayoutText(def.description),
                min = def.min,
                max = def.max,
                step = def.step,
                fallback = def.fallback,
                format = def.format,
                resetText = L["OPTION_RESET"],
                disabled = IsUnitDisabled,
            }))
            return
        end

        if def.widget == "dropdown" then
            layout:Add(Dropdown.Create({
                path = ResolveLayoutPath(def.path, unitKey),
                label = ResolveLayoutText(def.label),
                description = ResolveLayoutText(def.description),
                list = resolvedList,
                fallback = def.fallback,
                resetText = L["OPTION_RESET"],
                disabled = IsUnitDisabled,
            }))
        end
    end

    for _, sectionDef in ipairs(FRAME_TAB_LAYOUT) do
        AddSectionHeading(container, ResolveLayoutText(sectionDef.section))

        if sectionDef.mode == "direct_checkboxes" then
            for _, item in ipairs(sectionDef.items) do
                AddDirectCheckbox(item)
            end
        elseif sectionDef.mode == "direct_layering" then
            for _, item in ipairs(sectionDef.items) do
                if item.widget == "dropdown" then
                    AddDirectLayerDropdown(item)
                elseif item.widget == "slider" then
                    AddDirectLayerSlider(item)
                end
            end
        elseif sectionDef.mode == "section" then
            local layout = CreateSection(container)
            for _, item in ipairs(sectionDef.items) do
                AddSectionWidget(layout, item)
            end
        end
    end
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
    ResetFlowContainer(container)

    local unitLabel = ns.GetLabel(KM.Units, unitKey)
    local COLORS_TAB_LAYOUT = ns.GUI.Layouts.UnitColors.ColorTab

    local function IsUnitDisabled()
        return not ns.GUI.Helpers.OptionValues.Get({ "Units", unitKey, "enabled" }, true)
    end

    local function IsPowerBarDisabled()
        return IsUnitDisabled()
            or not ns.GUI.Helpers.OptionValues.Get({ "Units", unitKey, "showPowerBar" }, true)
    end

    local function IsAlternativePowerBarDisabled()
        return IsUnitDisabled()
            or not ns.GUI.Helpers.OptionValues.Get({ "Units", unitKey, "showAlternativePowerBar" }, false)
    end

    local function IsCastBarDisabled()
        return IsUnitDisabled()
            or not ns.GUI.Helpers.OptionValues.Get({ "Units", unitKey, "showCastBar" }, true)
    end

    local function IsHealthColorPickerDisabled()
        return IsUnitDisabled()
            or ns.GUI.Helpers.OptionValues.Get({ "Units", unitKey, "useClassColorHealth" }, false)
    end

    local function IsHealthBackgroundPickerDisabled()
        return IsUnitDisabled()
            or not ns.GUI.Helpers.OptionValues.Get({ "Units", unitKey, "healthBackground" }, true)
    end

    local function IsPowerColorPickerDisabled()
        return IsPowerBarDisabled()
            or ns.GUI.Helpers.OptionValues.Get({ "Units", unitKey, "useClassColorPower" }, false)
    end

    local function IsPowerBackgroundPickerDisabled()
        return IsPowerBarDisabled()
            or not ns.GUI.Helpers.OptionValues.Get({ "Units", unitKey, "powerBackground" }, true)
    end

    AddPageHeading(container, unitLabel .. " - " .. ns.GetLabel(KM.Tabs, C.Tabs.COLORS))

    local function ResolveColorSectionHeading(sectionKey)
        if sectionKey == "$healthBar" then
            return ns.GetLabel(KM.Bars, C.Bars.HEALTH)
        end

        if sectionKey == "$powerBar" then
            return ns.GetLabel(KM.Bars, C.Bars.POWER)
        end

        if sectionKey == "$castBar" then
            return ns.GetLabel(KM.Bars, C.Bars.CAST)
        end

        if sectionKey == "$texts" then
            return ns.GetLabel(KM.Tabs, C.Tabs.TEXTS)
        end

        return ResolveLayoutText(sectionKey)
    end

    local function ResolveColorDisabled(def)
        if def.disabled == "unit" then
            return IsUnitDisabled
        end

        if def.disabled == "power" then
            return IsPowerBarDisabled
        end

        if def.disabled == "cast" then
            return IsCastBarDisabled
        end

        if def.disabled == "healthColor" then
            return IsHealthColorPickerDisabled
        end

        if def.disabled == "healthBackground" then
            return IsHealthBackgroundPickerDisabled
        end

        if def.disabled == "powerColor" then
            return IsPowerColorPickerDisabled
        end

        if def.disabled == "powerBackground" then
            return IsPowerBackgroundPickerDisabled
        end

        return nil
    end

    local function AddColorSectionWidget(layout, def, state)
        if type(def) ~= "table" or type(def.path) ~= "table" then
            return
        end

        if def.widget == "colorpicker" then
            local picker = ColorPicker.Create({
                path = ResolveLayoutPath(def.path, unitKey),
                label = ResolveLayoutText(def.label),
                description = ResolveLayoutText(def.description),
                hasAlpha = def.hasAlpha == true,
                resetText = L["OPTION_RESET"],
                disabled = ResolveColorDisabled(def),
            })

            layout:Add(picker)

            if def.path[#def.path] == "healthColor" then
                state.healthColorPickerHandle = picker
            end

            if def.path[#def.path] == "powerColor" then
                state.powerColorPickerHandle = picker
            end

            return
        end

        if def.widget == "checkbox" then
            layout:Add(Checkbox.Create({
                path = ResolveLayoutPath(def.path, unitKey),
                label = ResolveLayoutText(def.label),
                description = ResolveLayoutText(def.description),
                fallback = def.fallback,
                resetText = def.resetText ~= nil and def.resetText or L["OPTION_RESET"],
                disabled = ResolveColorDisabled(def),
                refreshGUI = def.refreshGUI,
                onChanged = function()
                    if def.onChanged == "refresh_health_color"
                        and state.healthColorPickerHandle
                        and state.healthColorPickerHandle.RefreshState
                    then
                        state.healthColorPickerHandle.RefreshState()
                    end

                    if def.onChanged == "refresh_power_color"
                        and state.powerColorPickerHandle
                        and state.powerColorPickerHandle.RefreshState
                    then
                        state.powerColorPickerHandle.RefreshState()
                    end
                end,
            }))
        end
    end

    for _, sectionDef in ipairs(COLORS_TAB_LAYOUT) do
        AddSectionHeading(container, ResolveColorSectionHeading(sectionDef.section))

        if sectionDef.mode == "section" then
            local layout = CreateSection(container)
            local sectionState = {}

            for _, item in ipairs(sectionDef.items) do
                AddColorSectionWidget(layout, item, sectionState)
            end
        end
    end
end

function B.BuildUnitHealthBarPage(container, unitKey)
    ResetFlowContainer(container)

    local unitLabel = ns.GetLabel(KM.Units, unitKey)
    local HEALTH_BAR_LAYOUT = ns.GUI.Layouts.UnitBars.HealthBarTab
    local BAR_LISTS = ns.GUI.Layouts.UnitBars.Lists

    AddPageHeading(container, unitLabel .. " - " .. ns.GetLabel(KM.Tabs, C.Tabs.BARS) .. " - " .. ns.GetLabel(KM.Bars, C.Bars.HEALTH))

    local function IsUnitDisabled()
        return not ns.GUI.Helpers.OptionValues.Get({ "Units", unitKey, "enabled" }, true)
    end

    local function AddSectionWidget(layout, def)
        local resolvedList = def.list and ResolveLayoutList(BAR_LISTS[def.list]) or nil
        if def.widget == "colorpicker" then
            layout:Add(ColorPicker.Create({
                path = ResolveLayoutPath(def.path, unitKey),
                label = ResolveLayoutText(def.label),
                description = ResolveLayoutText(def.description),
                hasAlpha = def.hasAlpha == true,
                fallback = def.fallback,
                resetText = L["OPTION_RESET"],
                disabled = ResolveDisabled(def),
            }))
            return
        end

        if not CanBuildLayoutWidget(def, resolvedList) then
            return
        end

        if def.widget == "dropdown" then
            layout:Add(Dropdown.Create({
                path = ResolveLayoutPath(def.path, unitKey),
                label = ResolveLayoutText(def.label),
                description = ResolveLayoutText(def.description),
                list = resolvedList,
                fallback = def.fallback,
                resetText = def.resetText ~= nil and def.resetText or L["OPTION_RESET"],
                disabled = def.disabled == "unit" and IsUnitDisabled or nil,
                refreshGUI = def.refreshGUI,
            }))
        end
    end

    for _, sectionDef in ipairs(HEALTH_BAR_LAYOUT) do
        AddSectionHeading(container, ResolveLayoutText(sectionDef.section))

        if sectionDef.mode == "section" then
            local layout = CreateSection(container)
            for _, item in ipairs(sectionDef.items) do
                AddSectionWidget(layout, item)
            end
        end
    end

    local label = AceGUI:Create("Label")
    label:SetFullWidth(true)
    label:SetText(L["INFO_HEALTH_BAR_COLORS_MOVED"])
    container:AddChild(label)
end

function B.BuildUnitPowerBarPage(container, unitKey)
    ResetFlowContainer(container)

    local unitLabel = ns.GetLabel(KM.Units, unitKey)
    local POWER_BAR_LAYOUT = ns.GUI.Layouts.UnitBars.PowerBarTab
    local BAR_LISTS = ns.GUI.Layouts.UnitBars.Lists

    local function IsUnitDisabled()
        return not ns.GUI.Helpers.OptionValues.Get({ "Units", unitKey, "enabled" }, true)
    end

    local function IsPowerBarDisabled()
        return IsUnitDisabled()
            or not ns.GUI.Helpers.OptionValues.Get({ "Units", unitKey, "showPowerBar" }, true)
    end

    local function IsAlternativePowerBarDisabled()
        return IsUnitDisabled()
            or not ns.GUI.Helpers.OptionValues.Get({ "Units", unitKey, "showAlternativePowerBar" }, false)
    end

    AddPageHeading(container, unitLabel .. " - " .. ns.GetLabel(KM.Tabs, C.Tabs.BARS) .. " - " .. ns.GetLabel(KM.Bars, C.Bars.POWER))

    local function ResolveDisabled(def)
        if def.disabled == "unit" then
            return IsUnitDisabled
        end

        if def.disabled == "power" then
            return IsPowerBarDisabled
        end

        if def.disabled == "alternativePower" then
            return IsAlternativePowerBarDisabled
        end

        return nil
    end

    local function AddSectionWidget(layout, def)
        local resolvedList = def.list and ResolveLayoutList(BAR_LISTS[def.list]) or nil
        if def.widget == "colorpicker" then
            layout:Add(ColorPicker.Create({
                path = ResolveLayoutPath(def.path, unitKey),
                label = ResolveLayoutText(def.label),
                description = ResolveLayoutText(def.description),
                hasAlpha = def.hasAlpha == true,
                fallback = def.fallback,
                resetText = L["OPTION_RESET"],
                disabled = ResolveDisabled(def),
            }))
            return
        end

        if not CanBuildLayoutWidget(def, resolvedList) then
            return
        end

        if def.widget == "dropdown" then
            layout:Add(Dropdown.Create({
                path = ResolveLayoutPath(def.path, unitKey),
                label = ResolveLayoutText(def.label),
                description = ResolveLayoutText(def.description),
                list = resolvedList,
                fallback = def.fallback,
                resetText = def.resetText ~= nil and def.resetText or L["OPTION_RESET"],
                disabled = ResolveDisabled(def),
                refreshGUI = def.refreshGUI,
            }))
            return
        end

        if def.widget == "checkbox" then
            layout:Add(Checkbox.Create({
                path = ResolveLayoutPath(def.path, unitKey),
                label = ResolveLayoutText(def.label),
                description = ResolveLayoutText(def.description),
                fallback = def.fallback,
                resetText = def.resetText ~= nil and def.resetText or L["OPTION_RESET"],
                disabled = ResolveDisabled(def),
                refreshGUI = def.refreshGUI,
            }))
            return
        end

        if def.widget == "slider" then
            layout:Add(Slider.Create({
                path = ResolveLayoutPath(def.path, unitKey),
                label = ResolveLayoutText(def.label),
                description = ResolveLayoutText(def.description),
                min = def.min,
                max = def.max,
                step = def.step,
                fallback = def.fallback,
                format = def.format,
                resetText = def.resetText ~= nil and def.resetText or L["OPTION_RESET"],
                disabled = ResolveDisabled(def),
            }))
        end
    end

    for _, sectionDef in ipairs(POWER_BAR_LAYOUT) do
        AddSectionHeading(container, ResolveLayoutText(sectionDef.section))

        if sectionDef.mode == "section" then
            local layout = CreateSection(container)
            for _, item in ipairs(sectionDef.items) do
                AddSectionWidget(layout, item)
            end
        end
    end
end

function B.BuildUnitAlternativePowerBarPage(container, unitKey)
    ResetFlowContainer(container)

    local unitLabel = ns.GetLabel(KM.Units, unitKey)
    local ALT_POWER_BAR_LAYOUT = ns.GUI.Layouts.UnitBars.AlternativePowerBarTab

    local function IsUnitDisabled()
        return not ns.GUI.Helpers.OptionValues.Get({ "Units", unitKey, "enabled" }, true)
    end

    local function IsAlternativePowerBarDisabled()
        return IsUnitDisabled()
            or not ns.GUI.Helpers.OptionValues.Get({ "Units", unitKey, "showAlternativePowerBar" }, false)
    end

    AddPageHeading(container, unitLabel .. " - " .. ns.GetLabel(KM.Tabs, C.Tabs.BARS) .. " - " .. ns.GetLabel(KM.Bars, C.Bars.ALT_POWER))

    local info = AceGUI:Create("Label")
    info:SetFullWidth(true)
    info:SetText(L["INFO_ALTERNATIVE_POWER_BAR_HINT"] or "")
    container:AddChild(info)

    local spacer = AceGUI:Create("Label")
    spacer:SetFullWidth(true)
    spacer:SetText(" ")
    spacer:SetHeight(6)
    container:AddChild(spacer)

    local function ResolveDisabled(def)
        if def.disabled == "unit" then
            return IsUnitDisabled
        end

        if def.disabled == "alternativePower" then
            return IsAlternativePowerBarDisabled
        end

        return nil
    end

    local function AddSectionWidget(layout, def)
        if def.widget == "checkbox" then
            layout:Add(Checkbox.Create({
                path = ResolveLayoutPath(def.path, unitKey),
                label = ResolveLayoutText(def.label),
                description = ResolveLayoutText(def.description),
                fallback = def.fallback,
                resetText = def.resetText ~= nil and def.resetText or L["OPTION_RESET"],
                disabled = ResolveDisabled(def),
                refreshGUI = def.refreshGUI,
            }))
            return
        end

        if def.widget == "slider" then
            layout:Add(Slider.Create({
                path = ResolveLayoutPath(def.path, unitKey),
                label = ResolveLayoutText(def.label),
                description = ResolveLayoutText(def.description),
                min = def.min,
                max = def.max,
                step = def.step,
                fallback = def.fallback,
                format = def.format,
                resetText = def.resetText ~= nil and def.resetText or L["OPTION_RESET"],
                disabled = ResolveDisabled(def),
            }))
        end
    end

    for _, sectionDef in ipairs(ALT_POWER_BAR_LAYOUT) do
        AddSectionHeading(container, ResolveLayoutText(sectionDef.section))

        if sectionDef.mode == "section" then
            local layout = CreateSection(container)
            for _, item in ipairs(sectionDef.items) do
                AddSectionWidget(layout, item)
            end
        end
    end
end

function B.BuildUnitCastBarPage(container, unitKey)
    ResetFlowContainer(container)

    local unitLabel = ns.GetLabel(KM.Units, unitKey)
    local CAST_BAR_LAYOUT = ns.GUI.Layouts.UnitBars.CastBarTab
    local BAR_LISTS = ns.GUI.Layouts.UnitBars.Lists

    local function IsUnitDisabled()
        return not ns.GUI.Helpers.OptionValues.Get({ "Units", unitKey, "enabled" }, true)
    end

    local function IsCastBarDisabled()
        return IsUnitDisabled()
            or not ns.GUI.Helpers.OptionValues.Get({ "Units", unitKey, "showCastBar" }, true)
    end

    AddPageHeading(container, unitLabel .. " - " .. ns.GetLabel(KM.Tabs, C.Tabs.BARS) .. " - " .. ns.GetLabel(KM.Bars, C.Bars.CAST))

    local function ResolveDisabled(def)
        if def.disabled == "unit" then
            return IsUnitDisabled
        end

        if def.disabled == "cast" then
            return IsCastBarDisabled
        end

        return nil
    end

    local function AddSectionWidget(layout, def)
        local resolvedList = def.list and ResolveLayoutList(BAR_LISTS[def.list]) or nil
        if not CanBuildLayoutWidget(def, resolvedList) then
            return
        end

        if def.widget == "dropdown" then
            layout:Add(Dropdown.Create({
                path = ResolveLayoutPath(def.path, unitKey),
                label = ResolveLayoutText(def.label),
                description = ResolveLayoutText(def.description),
                list = resolvedList,
                fallback = def.fallback,
                resetText = def.resetText ~= nil and def.resetText or L["OPTION_RESET"],
                disabled = ResolveDisabled(def),
                refreshGUI = def.refreshGUI,
            }))
            return
        end

        if def.widget == "checkbox" then
            layout:Add(Checkbox.Create({
                path = ResolveLayoutPath(def.path, unitKey),
                label = ResolveLayoutText(def.label),
                description = ResolveLayoutText(def.description),
                fallback = def.fallback,
                resetText = def.resetText ~= nil and def.resetText or L["OPTION_RESET"],
                disabled = ResolveDisabled(def),
                refreshGUI = def.refreshGUI,
            }))
            return
        end

        if def.widget == "slider" then
            layout:Add(Slider.Create({
                path = ResolveLayoutPath(def.path, unitKey),
                label = ResolveLayoutText(def.label),
                description = ResolveLayoutText(def.description),
                min = def.min,
                max = def.max,
                step = def.step,
                fallback = def.fallback,
                format = def.format,
                resetText = def.resetText ~= nil and def.resetText or L["OPTION_RESET"],
                disabled = ResolveDisabled(def),
            }))
        end
    end

    for _, sectionDef in ipairs(CAST_BAR_LAYOUT) do
        AddSectionHeading(container, ResolveLayoutText(sectionDef.section))

        if sectionDef.mode == "section" then
            local layout = CreateSection(container)
            for _, item in ipairs(sectionDef.items) do
                AddSectionWidget(layout, item)
            end
        end
    end
end

local function BuildUnitTextPage(container, unitKey, textConfigKey, textLabel)
    ResetFlowContainer(container)

    local unitLabel = ns.GetLabel(KM.Units, unitKey)
    local TEXT_TAB_LAYOUT = ns.GUI.Layouts.UnitTexts.TextTab
    local TEXT_TAB_LISTS = ns.GUI.Layouts.UnitTexts.Lists
    local tokenReplacements = {
        ["$textKey"] = textConfigKey,
    }

    local function IsUnitDisabled()
        return not ns.GUI.Helpers.OptionValues.Get({ "Units", unitKey, "enabled" }, true)
    end

    local function IsTextDisabled()
        return IsUnitDisabled()
            or not ns.GUI.Helpers.OptionValues.Get({ "Units", unitKey, "Texts", textConfigKey, "enabled" }, true)
    end

    local function IsShadowDisabled()
        return IsTextDisabled()
            or not ns.GUI.Helpers.OptionValues.Get({ "Units", unitKey, "Texts", textConfigKey, "shadowEnabled" }, true)
    end

    local function IsExpertModeEnabled()
        return ns.GUI.Helpers.OptionValues.Get({ "General", "ExpertMode" }, true) == true
    end

    local function GetTextConfig()
        return ns.GUI.Helpers.OptionValues.Get({ "Units", unitKey, "Texts", textConfigKey }, {}) or {}
    end

    local function GetTemplateList()
        local list = {}
        local templates = ns.db and ns.db.profile and ns.db.profile.TextTemplates or {}

        for templateName in pairs(templates) do
            list[templateName] = templateName
        end

        return list, templates
    end

    local function SetStatus(message)
        if ns.guiFrame and ns.guiFrame.SetStatusText then
            ns.guiFrame:SetStatusText(message)
        end
    end

    local function ResolveCurrentTemplateName(textConfig, templates)
        if type(textConfig) ~= "table" then
            return ""
        end

        if type(textConfig.templateName) == "string" and textConfig.templateName ~= "" and type(templates[textConfig.templateName]) == "string" then
            return textConfig.templateName
        end

        local currentTag = textConfig.tag or ""
        if currentTag == "" then
            return ""
        end

        for templateName, templateValue in pairs(templates) do
            if templateValue == currentTag then
                return templateName
            end
        end

        return ""
    end

    local function ResolveCurrentTemplateText(textConfig, templates)
        local currentTemplateName = ResolveCurrentTemplateName(textConfig, templates)
        if currentTemplateName ~= "" then
            return templates[currentTemplateName] or ""
        end

        return textConfig.tag or ""
    end

    local function ResolveDisabled(def)
        if def.disabled == "unit" then
            return IsUnitDisabled
        end

        if def.disabled == "text" then
            return IsTextDisabled
        end

        if def.disabled == "shadow" then
            return IsShadowDisabled
        end

        return nil
    end

    local function AddEditBoxWidget(layout, def)
        local path = ResolveLayoutPath(def.path, unitKey, tokenReplacements)
        local disabled = ResolveDisabled(def)
        local group = AceGUI:Create("SimpleGroup")
        group:SetFullWidth(true)
        group:SetLayout("Flow")

        local editBox = AceGUI:Create("EditBox")
        editBox:SetLabel(ResolveLayoutText(def.label))
        editBox:SetWidth(def.width or 320)
        editBox:DisableButton(true)
        editBox:SetText(ns.GUI.Helpers.OptionValues.Get(path, def.fallback or ""))
        editBox:SetDisabled(ns.GUI.Helpers.OptionValues.ResolveState(disabled, def))
        editBox:SetCallback("OnEnterPressed", function(widget, _, newValue)
            if ns.GUI.Helpers.OptionValues.ResolveState(disabled, def) then
                return
            end

            ns.GUI.Helpers.OptionValues.Set(path, newValue or "")
            ns.GUI.Helpers.OptionRefresh.Live()

            if def.refreshGUI then
                ns.GUI:RefreshOptions()
            end

            widget:ClearFocus()
        end)
        editBox:SetCallback("OnFocusLost", function(widget)
            if ns.GUI.Helpers.OptionValues.ResolveState(disabled, def) then
                return
            end

            ns.GUI.Helpers.OptionValues.Set(path, widget:GetText() or "")
            ns.GUI.Helpers.OptionRefresh.Live()

            if def.refreshGUI then
                ns.GUI:RefreshOptions()
            end
        end)
        group:AddChild(editBox)

        if def.description and def.description ~= "" then
            local description = AceGUI:Create("Label")
            description:SetFullWidth(true)
            description:SetText(ResolveLayoutText(def.description))
            group:AddChild(description)
        end

        layout:Add({ group = group })
    end

    local function AddSectionWidget(layout, def)
        local resolvedList = def.list and ResolveLayoutList(TEXT_TAB_LISTS[def.list]) or nil

        if def.widget == "editbox" then
            AddEditBoxWidget(layout, def)
            return
        end

        if def.widget == "fontstyle" then
            local path = ResolveLayoutPath(def.path, unitKey, tokenReplacements)
            local disabled = ResolveDisabled(def)
            local group = AceGUI:Create("SimpleGroup")
            group:SetFullWidth(true)
            group:SetLayout("Flow")
            local dropdown = AceGUI:Create("Dropdown")
            local textConfig = ns.GUI.Helpers.OptionValues.Get(path, {}) or {}
            local currentStyle = "NONE"

            if textConfig.thickOutline and textConfig.monochrome then
                currentStyle = "THICKOUTLINE_MONOCHROME"
            elseif textConfig.outline and textConfig.monochrome then
                currentStyle = "OUTLINE_MONOCHROME"
            elseif textConfig.thickOutline then
                currentStyle = "THICKOUTLINE"
            elseif textConfig.outline then
                currentStyle = "OUTLINE"
            elseif textConfig.monochrome then
                currentStyle = "MONOCHROME"
            end

            dropdown:SetLabel(ResolveLayoutText(def.label))
            dropdown:SetList(resolvedList)
            dropdown:SetWidth(220)
            dropdown:SetValue(currentStyle)
            dropdown:SetDisabled(ns.GUI.Helpers.OptionValues.ResolveState(disabled, def))
            dropdown:SetCallback("OnValueChanged", function(_, _, newValue)
                if ns.GUI.Helpers.OptionValues.ResolveState(disabled, def) then
                    return
                end

                local stylePath = path
                local isOutline = newValue == "OUTLINE" or newValue == "OUTLINE_MONOCHROME"
                local isThickOutline = newValue == "THICKOUTLINE" or newValue == "THICKOUTLINE_MONOCHROME"
                local isMonochrome = newValue == "MONOCHROME" or newValue == "OUTLINE_MONOCHROME" or newValue == "THICKOUTLINE_MONOCHROME"

                ns.GUI.Helpers.OptionValues.Set({ stylePath[1], stylePath[2], stylePath[3], stylePath[4], "outline" }, isOutline)
                ns.GUI.Helpers.OptionValues.Set({ stylePath[1], stylePath[2], stylePath[3], stylePath[4], "thickOutline" }, isThickOutline)
                ns.GUI.Helpers.OptionValues.Set({ stylePath[1], stylePath[2], stylePath[3], stylePath[4], "monochrome" }, isMonochrome)
                ns.GUI.Helpers.OptionRefresh.Live()
            end)
            group:AddChild(dropdown)
            layout:Add({
                group = group,
            })
            return
        end

        if def.widget == "colorpicker" then
            layout:Add(ColorPicker.Create({
                path = ResolveLayoutPath(def.path, unitKey, tokenReplacements),
                label = ResolveLayoutText(def.label),
                description = ResolveLayoutText(def.description),
                hasAlpha = def.hasAlpha == true,
                fallback = def.fallback,
                resetText = L["OPTION_RESET"],
                disabled = ResolveDisabled(def),
            }))
            return
        end

        if not CanBuildLayoutWidget(def, resolvedList) then
            return
        end

        if def.widget == "checkbox" then
            layout:Add(Checkbox.Create({
                path = ResolveLayoutPath(def.path, unitKey, tokenReplacements),
                label = ResolveLayoutText(def.label),
                description = ResolveLayoutText(def.description),
                fallback = def.fallback,
                resetText = def.resetText ~= nil and def.resetText or L["OPTION_RESET"],
                disabled = ResolveDisabled(def),
                refreshGUI = def.refreshGUI,
            }))
            return
        end

        if def.widget == "dropdown" then
            layout:Add(Dropdown.Create({
                path = ResolveLayoutPath(def.path, unitKey, tokenReplacements),
                label = ResolveLayoutText(def.label),
                description = ResolveLayoutText(def.description),
                list = resolvedList,
                fallback = def.fallback,
                resetText = def.resetText ~= nil and def.resetText or L["OPTION_RESET"],
                disabled = ResolveDisabled(def),
                refreshGUI = def.refreshGUI,
            }))
            return
        end

        if def.widget == "slider" then
            layout:Add(Slider.Create({
                path = ResolveLayoutPath(def.path, unitKey, tokenReplacements),
                label = ResolveLayoutText(def.label),
                description = ResolveLayoutText(def.description),
                min = def.min,
                max = def.max,
                step = def.step,
                fallback = def.fallback,
                format = def.format,
                resetText = def.resetText ~= nil and def.resetText or L["OPTION_RESET"],
                disabled = ResolveDisabled(def),
            }))
        end
    end

    AddPageHeading(container, unitLabel .. " - " .. ns.GetLabel(KM.Tabs, C.Tabs.TEXTS) .. " - " .. textLabel)

    local templatesList, templates = GetTemplateList()
    local textConfig = GetTextConfig()
    local currentTemplateName = ResolveCurrentTemplateName(textConfig, templates)
    local currentTemplateText = ResolveCurrentTemplateText(textConfig, templates)

    local templateGroup = AceGUI:Create("InlineGroup")
    templateGroup:SetFullWidth(true)
    templateGroup:SetLayout("Flow")
    templateGroup:SetTitle(L["INFO_UNIT_TEXT_TEMPLATE_GROUP"] or "Template")
    container:AddChild(templateGroup)

    local templateHint = AceGUI:Create("Label")
    templateHint:SetFullWidth(true)
    if templateHint.SetFont then
        templateHint:SetFont(STANDARD_TEXT_FONT, 11, "")
    end
    templateHint:SetText(string.format("|cff9ea8b3%s|r", L["INFO_UNIT_TEXT_TEMPLATE_HINT"] or "Choose a template for this text element. Layout, font, and effects stay on this page."))
    templateGroup:AddChild(templateHint)

    local templateDropdown = AceGUI:Create("Dropdown")
    templateDropdown:SetLabel(L["INFO_UNIT_TEXT_TEMPLATE_SELECT"] or "Template")
    templateDropdown:SetWidth(320)
    templateDropdown:SetList(templatesList)
    templateDropdown:SetValue(currentTemplateName ~= "" and currentTemplateName or nil)
    templateDropdown:SetDisabled(IsUnitDisabled())
    templateGroup:AddChild(templateDropdown)

    if IsExpertModeEnabled() then
        local rawTemplateEdit = AceGUI:Create("EditBox")
        rawTemplateEdit:SetLabel(L["OPTION_TAG"] or "Tag")
        rawTemplateEdit:SetWidth(320)
        rawTemplateEdit:DisableButton(true)
        rawTemplateEdit:SetText(textConfig.tag or "")
        rawTemplateEdit:SetDisabled(IsUnitDisabled())
        rawTemplateEdit:SetCallback("OnEnterPressed", function(widget, _, newValue)
            if IsUnitDisabled() then
                return
            end

            ns.GUI.Helpers.OptionValues.Set({ "Units", unitKey, "Texts", textConfigKey, "tag" }, newValue or "")
            ns.GUI.Helpers.OptionRefresh.Live()
            widget:ClearFocus()
        end)
        rawTemplateEdit:SetCallback("OnFocusLost", function(widget)
            if IsUnitDisabled() then
                return
            end

            ns.GUI.Helpers.OptionValues.Set({ "Units", unitKey, "Texts", textConfigKey, "tag" }, widget:GetText() or "")
            ns.GUI.Helpers.OptionRefresh.Live()
        end)
        templateGroup:AddChild(rawTemplateEdit)

        local expertInfo = AceGUI:Create("Label")
        expertInfo:SetFullWidth(true)
        if expertInfo.SetFont then
            expertInfo:SetFont(STANDARD_TEXT_FONT, 10, "")
        end
        expertInfo:SetText(string.format("|cff8f98a3%s|r", L["INFO_UNIT_TEXT_TEMPLATE_EXPERT_HINT"] or "Expert Mode: you can still edit the raw template string below."))
        templateGroup:AddChild(expertInfo)
    end

    local previewHeader = AceGUI:Create("Label")
    previewHeader:SetFullWidth(true)
    previewHeader:SetText(string.format("|cffe6d6a8%s|r", L["INFO_UNIT_TEXT_TEMPLATE_PREVIEW"] or "Preview"))
    templateGroup:AddChild(previewHeader)

    local previewBox = AceGUI:Create("Label")
    previewBox:SetFullWidth(true)
    previewBox:SetText((ns.UnitFrame and ns.UnitFrame.BuildTemplatePreview and ns.UnitFrame:BuildTemplatePreview(currentTemplateText)) or currentTemplateText or " ")
    templateGroup:AddChild(previewBox)

    local actionGroup = AceGUI:Create("SimpleGroup")
    actionGroup:SetFullWidth(true)
    actionGroup:SetLayout("Flow")
    templateGroup:AddChild(actionGroup)

    local deleteTextButton = AceGUI:Create("Button")
    deleteTextButton:SetText(L["INFO_UNIT_TEXT_TEMPLATE_DELETE"] or "Delete Text")
    deleteTextButton:SetWidth(150)
    deleteTextButton:SetDisabled(IsUnitDisabled())
    actionGroup:AddChild(deleteTextButton)

    local openBuilderButton = AceGUI:Create("Button")
    openBuilderButton:SetText(L["INFO_UNIT_TEXT_TEMPLATE_OPEN_BUILDER"] or "Open in Text Builder")
    openBuilderButton:SetWidth(170)
    openBuilderButton:SetDisabled(IsUnitDisabled())
    actionGroup:AddChild(openBuilderButton)

    templateDropdown:SetCallback("OnValueChanged", function(_, _, value)
        if IsUnitDisabled() then
            return
        end

        local selectedName = value or ""
        local selectedTemplate = templates[selectedName]
        if type(selectedTemplate) ~= "string" then
            return
        end

        ns.GUI.Helpers.OptionValues.Set({ "Units", unitKey, "Texts", textConfigKey, "templateName" }, selectedName)
        ns.GUI.Helpers.OptionValues.Set({ "Units", unitKey, "Texts", textConfigKey, "tag" }, selectedTemplate)
        ns.GUI.Helpers.OptionRefresh.Live()
        ns.GUI:RefreshOptions()
    end)

    deleteTextButton:SetCallback("OnClick", function()
        if IsUnitDisabled() then
            return
        end

        ns.GUI.Helpers.OptionValues.Set({ "Units", unitKey, "Texts", textConfigKey, "templateName" }, "")
        ns.GUI.Helpers.OptionValues.Set({ "Units", unitKey, "Texts", textConfigKey, "tag" }, "")
        ns.GUI.Helpers.OptionValues.Set({ "Units", unitKey, "Texts", textConfigKey, "enabled" }, false)
        ns.GUI.Helpers.OptionRefresh.Live()
        ns.GUI:RefreshOptions()
        SetStatus((L["INFO_UNIT_TEXT_TEMPLATE_STATUS_DELETED"] or "Text deleted:") .. " " .. textLabel)
    end)

    openBuilderButton:SetCallback("OnClick", function()
        if IsUnitDisabled() then
            return
        end

        local state = GetGUIState()
        state.textBuilder = state.textBuilder or {}
        state.textBuilder.template = currentTemplateText or ""
        state.textBuilder.templateName = currentTemplateName or ""
        state.textBuilder.selectedTemplate = currentTemplateName or ""

        if ns.GUI then
            ns.GUI.selectedPath = C.Nav.TEXT_BUILDER
        end

        if ns.guiTreeGroup and ns.guiTreeGroup.SelectByValue then
            ns.guiTreeGroup:SelectByValue(C.Nav.TEXT_BUILDER)
        elseif ns.GUI and ns.GUI.RefreshOptions then
            ns.GUI:RefreshOptions()
        end
    end)

    local basicsGroup = AceGUI:Create("InlineGroup")
    basicsGroup:SetFullWidth(true)
    basicsGroup:SetLayout("Flow")
    basicsGroup:SetTitle(ResolveLayoutText("SECTION_GENERAL"))
    container:AddChild(basicsGroup)

    local basicsLayout = CreateSection(basicsGroup)
    basicsLayout:Add(Checkbox.Create({
        path = { "Units", unitKey, "Texts", textConfigKey, "enabled" },
        label = ResolveLayoutText("OPTION_ENABLED"),
        fallback = true,
        resetText = L["OPTION_RESET"],
        disabled = IsUnitDisabled,
        refreshGUI = true,
    }))
    basicsLayout:Add(ColorPicker.Create({
        path = { "Units", unitKey, "Texts", textConfigKey, "color" },
        label = ResolveLayoutText("OPTION_COLOR"),
        hasAlpha = true,
        fallback = { 1, 1, 1, 1 },
        resetText = L["OPTION_RESET"],
        disabled = IsTextDisabled,
    }))

    local sectionOrder = {
        "SECTION_POSITION",
        "SECTION_FONT",
        "SECTION_EFFECTS",
    }

    local sectionDefsByKey = {}
    for _, sectionDef in ipairs(TEXT_TAB_LAYOUT) do
        sectionDefsByKey[sectionDef.section] = sectionDefsByKey[sectionDef.section] or sectionDef
    end

    for _, sectionKey in ipairs(sectionOrder) do
        local sectionDef = sectionDefsByKey[sectionKey]
        if sectionDef and sectionDef.mode == "section" then
            local sectionGroup = AceGUI:Create("InlineGroup")
            sectionGroup:SetFullWidth(true)
            sectionGroup:SetLayout("Flow")
            sectionGroup:SetTitle(ResolveLayoutText(sectionDef.section))
            container:AddChild(sectionGroup)

            local layout = CreateSection(sectionGroup)
            for _, item in ipairs(sectionDef.items) do
                if sectionKey == "SECTION_EFFECTS"
                    and item.widget == "colorpicker"
                    and type(item.path) == "table"
                    and item.path[#item.path] == "color"
                then
                    -- Base text color is grouped with the basic text state above.
                else
                AddSectionWidget(layout, item)
                end
            end
        end
    end
end

function B.BuildUnitTextsPage(container, unitKey)
    container:ReleaseChildren()
    container:SetLayout("Fill")

    local state = GetGUIState()
    local tabs = GetTextTabValues(unitKey)
    local firstTab = tabs[1] and tabs[1].value or nil

    if not firstTab then
        B.BuildPlaceholderPage(container, ns.GetLabel(KM.Tabs, C.Tabs.TEXTS))
        return
    end

    state.unitTextTabs[unitKey] = state.unitTextTabs[unitKey] or firstTab
    state.unitTextScroll[unitKey] = state.unitTextScroll[unitKey] or {}

    local tabGroup = AceGUI:Create("TabGroup")
    tabGroup:SetFullWidth(true)
    tabGroup:SetFullHeight(true)
    tabGroup:SetLayout("Fill")
    tabGroup:SetTabs(tabs)

    tabGroup:SetCallback("OnGroupSelected", function(widget, _, textConfigKey)
        state.unitTextTabs[unitKey] = textConfigKey
        state.unitTextScroll[unitKey][textConfigKey] = state.unitTextScroll[unitKey][textConfigKey] or { scrollvalue = 0 }

        BuildScrollableTabContent(widget, state.unitTextScroll[unitKey][textConfigKey], function(content)
            local textLabel = textConfigKey
            for index, tab in ipairs(tabs) do
                if tab.value == textConfigKey then
                    textLabel = GetTextElementLabel(index)
                    break
                end
            end

            BuildUnitTextPage(content, unitKey, textConfigKey, textLabel)
        end)
    end)

    container:AddChild(tabGroup)
    tabGroup:SelectTab(state.unitTextTabs[unitKey] or firstTab)
end

function B.BuildUnitBarsPage(container, unitKey)
    container:ReleaseChildren()
    container:SetLayout("Fill")

    local state = GetGUIState()
    state.unitBarTabs[unitKey] = state.unitBarTabs[unitKey] or C.Bars.HEALTH
    state.unitBarScroll[unitKey] = state.unitBarScroll[unitKey] or {}

    local tabGroup = AceGUI:Create("TabGroup")
    tabGroup:SetFullWidth(true)
    tabGroup:SetFullHeight(true)
    tabGroup:SetLayout("Fill")
    tabGroup:SetTabs(GetBarTabValues())

    tabGroup:SetCallback("OnGroupSelected", function(widget, _, barKey)
        state.unitBarTabs[unitKey] = barKey
        state.unitBarScroll[unitKey][barKey] = state.unitBarScroll[unitKey][barKey] or { scrollvalue = 0 }

        BuildScrollableTabContent(widget, state.unitBarScroll[unitKey][barKey], function(content)
            if barKey == C.Bars.HEALTH then
                B.BuildUnitHealthBarPage(content, unitKey)
                return
            end

            if barKey == C.Bars.POWER then
                B.BuildUnitPowerBarPage(content, unitKey)
                return
            end

            if barKey == C.Bars.ALT_POWER then
                B.BuildUnitAlternativePowerBarPage(content, unitKey)
                return
            end

            if barKey == C.Bars.CAST then
                B.BuildUnitCastBarPage(content, unitKey)
                return
            end

            B.BuildPlaceholderPage(content, ns.GetLabel(KM.Bars, barKey))
        end)
    end)

    container:AddChild(tabGroup)
    tabGroup:SelectTab(state.unitBarTabs[unitKey] or C.Bars.HEALTH)
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
