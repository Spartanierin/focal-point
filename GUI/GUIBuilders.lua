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

local function GetTextTabValues(unitKey)
    local tabs = {}

    for _, def in ipairs(TEXT_TAB_DEFS) do
        local configPath = { "Units", unitKey, "Texts", def.configKey }
        local configValue = ns.GUI.Helpers.OptionValues.Get(configPath, nil)
        if configValue == nil then
            configValue = ns.GUI.Helpers.OptionValues.GetDefault(configPath, nil)
        end

        if type(configValue) == "table" then
            table.insert(tabs, {
                text = ns.GetLabel(KM.Texts, def.value),
                value = def.configKey,
            })
        end
    end

    for _, def in ipairs(CUSTOM_TEXT_TAB_DEFS) do
        local configPath = { "Units", unitKey, "Texts", def.configKey }
        local configValue = ns.GUI.Helpers.OptionValues.Get(configPath, nil)
        if configValue == nil then
            configValue = ns.GUI.Helpers.OptionValues.GetDefault(configPath, nil)
        end

        local hasTemplate = type(configValue) == "table"
            and type(configValue.tag) == "string"
            and configValue.tag ~= ""

        if type(configValue) == "table" and hasTemplate then
            table.insert(tabs, {
                text = ns.GetLabel(KM.Texts, def.value),
                value = def.configKey,
            })
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

    local tabGroup = AceGUI:Create("TabGroup")
    tabGroup:SetFullWidth(true)
    tabGroup:SetFullHeight(true)
    tabGroup:SetLayout("Fill")
    tabGroup:SetTabs(tabs)

    tabGroup:SetCallback("OnGroupSelected", function(widget, _, categoryKey)
        state.tagDatabaseTab = categoryKey
        state.tagDatabaseScroll[categoryKey] = state.tagDatabaseScroll[categoryKey] or { scrollvalue = 0 }

        BuildScrollableTabContent(widget, state.tagDatabaseScroll[categoryKey], function(content)
            AddPageHeading(content, L["INFO_TAG_DATABASE_TITLE"] or "Tag Database")

            local description = AceGUI:Create("Label")
            description:SetFullWidth(true)
            description:SetText(L["INFO_TAG_DATABASE_DESCRIPTION"] or "")
            content:AddChild(description)

            local hint = AceGUI:Create("Label")
            hint:SetFullWidth(true)
            hint:SetText(L["INFO_TAG_DATABASE_TEMPLATE_HINT"] or "")
            content:AddChild(hint)

            AddSectionHeading(content, L[categoryKey] or categoryKey, 8)

            for _, def in ipairs(grouped[categoryKey] or {}) do
                local row = AceGUI:Create("Label")
                row:SetFullWidth(true)
                row:SetText(string.format(
                    "|cff6fd2ff%s|r  -  %s  |cff999999(%s)|r",
                    def.token,
                    L[def.description] or def.description,
                    def.example or ""
                ))
                content:AddChild(row)
            end
        end)
    end)

    container:AddChild(tabGroup)
    tabGroup:SelectTab(state.tagDatabaseTab or firstTab)
end

function B.BuildTextBuilderPage(container)
    ResetFlowContainer(container)

    local state = GetGUIState()
    state.textBuilder = state.textBuilder or {
        template = "[hp:cur:abbr]/[hp:max:abbr] | [hp:perc]%",
        templateName = "",
        selectedTemplate = "",
        applySlot = "Custom1",
    }

    local function CreateSpacer(height)
        local spacer = AceGUI:Create("Label")
        spacer:SetText(" ")
        spacer:SetFullWidth(true)
        spacer:SetHeight(height or 1)
        return spacer
    end

    AddPageHeading(container, L["INFO_TEXT_BUILDER_TITLE"] or "Text Builder")

    container:AddChild(CreateSpacer(1))

    local description = AceGUI:Create("Label")
    description:SetFullWidth(true)
    if description.SetFont then
        description:SetFont(STANDARD_TEXT_FONT, 12, "")
    end
    description:SetText(string.format("|cffcfd5dd%s|r", L["INFO_TEXT_BUILDER_DESCRIPTION"] or ""))
    container:AddChild(description)

    container:AddChild(CreateSpacer(1))

    local builderGroup = AceGUI:Create("InlineGroup")
    builderGroup:SetFullWidth(true)
    builderGroup:SetLayout("Flow")
    builderGroup:SetTitle(L["INFO_TEXT_BUILDER_TEMPLATE"] or "Template")
    container:AddChild(builderGroup)

    builderGroup:AddChild(CreateSpacer(1))

    local templateEdit = AceGUI:Create("EditBox")
    templateEdit:SetLabel(L["INFO_TEXT_BUILDER_TEMPLATE"] or "Template")
    templateEdit:SetWidth(470)
    templateEdit:DisableButton(true)
    templateEdit:SetText(state.textBuilder.template or "")
    builderGroup:AddChild(templateEdit)

    local updateButton = AceGUI:Create("Button")
    updateButton:SetText(L["INFO_TEXT_BUILDER_APPLY"] or "Update Preview")
    updateButton:SetWidth(140)
    builderGroup:AddChild(updateButton)

    builderGroup:AddChild(CreateSpacer(2))

    local previewGroup = AceGUI:Create("InlineGroup")
    previewGroup:SetFullWidth(true)
    previewGroup:SetLayout("Flow")
    previewGroup:SetTitle(L["INFO_TEXT_BUILDER_PREVIEW"] or "Preview")
    container:AddChild(previewGroup)

    previewGroup:AddChild(CreateSpacer(0))

    local previewLabel = AceGUI:Create("Label")
    previewLabel:SetFullWidth(true)
    if previewLabel.SetFont then
        previewLabel:SetFont(STANDARD_TEXT_FONT, 14, "")
    end
    if previewLabel.label and previewLabel.label.SetJustifyH then
        previewLabel.label:SetJustifyH("CENTER")
    end
    previewLabel:SetText(" ")
    previewGroup:AddChild(previewLabel)

    local templatesGroup = AceGUI:Create("InlineGroup")
    templatesGroup:SetFullWidth(true)
    templatesGroup:SetLayout("Flow")
    templatesGroup:SetTitle(L["INFO_TEXT_BUILDER_TEMPLATES"] or "Templates")
    container:AddChild(templatesGroup)

    templatesGroup:AddChild(CreateSpacer(0))

    local templates = (ns.db and ns.db.profile and ns.db.profile.TextTemplates) or {}

    local templateSelect = AceGUI:Create("Dropdown")
    templateSelect:SetLabel(L["INFO_TEXT_BUILDER_SAVED_TEMPLATES"] or "Saved Templates")
    templateSelect:SetWidth(240)
    templatesGroup:AddChild(templateSelect)

    local templateNameEdit = AceGUI:Create("EditBox")
    templateNameEdit:SetLabel(L["INFO_TEXT_BUILDER_TEMPLATE_NAME"] or "Template Name")
    templateNameEdit:SetWidth(280)
    templateNameEdit:DisableButton(true)
    templateNameEdit:SetText(state.textBuilder.templateName or "")
    templatesGroup:AddChild(templateNameEdit)

    templatesGroup:AddChild(CreateSpacer(0))

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

    templatesGroup:AddChild(CreateSpacer(0))

    local applyGroup = AceGUI:Create("InlineGroup")
    applyGroup:SetFullWidth(true)
    applyGroup:SetLayout("Flow")
    applyGroup:SetTitle(L["INFO_TEXT_BUILDER_APPLY_TO_TEXT"] or "Apply To Text")
    container:AddChild(applyGroup)

    applyGroup:AddChild(CreateSpacer(0))

    local applySlotDropdown = AceGUI:Create("Dropdown")
    applySlotDropdown:SetLabel(L["INFO_TEXT_BUILDER_TARGET_TEXT"] or "Target Text")
    applySlotDropdown:SetWidth(240)
    applySlotDropdown:SetList({
        Custom1 = ns.GetLabel(KM.Texts, C.Texts.CUSTOM_1),
        Custom2 = ns.GetLabel(KM.Texts, C.Texts.CUSTOM_2),
        Custom3 = ns.GetLabel(KM.Texts, C.Texts.CUSTOM_3),
    })
    applySlotDropdown:SetValue(state.textBuilder.applySlot or "Custom1")
    applyGroup:AddChild(applySlotDropdown)

    local applyUnitDropdown = AceGUI:Create("Dropdown")
    applyUnitDropdown:SetLabel(L["INFO_TEXT_BUILDER_UNIT"] or "Unit")
    applyUnitDropdown:SetWidth(240)
    applyUnitDropdown:SetList({
        [C.Units.PLAYER] = ns.GetLabel(KM.Units, C.Units.PLAYER),
        [C.Units.TARGET] = ns.GetLabel(KM.Units, C.Units.TARGET),
        [C.Units.FOCUS] = ns.GetLabel(KM.Units, C.Units.FOCUS),
        [C.Units.PET] = ns.GetLabel(KM.Units, C.Units.PET),
    })
    applyUnitDropdown:SetValue(C.Units.PLAYER)
    applyGroup:AddChild(applyUnitDropdown)

    applyGroup:AddChild(CreateSpacer(0))

    local applyTemplateButton = AceGUI:Create("Button")
    applyTemplateButton:SetText(L["INFO_TEXT_BUILDER_APPLY_TEMPLATE"] or "Apply Template")
    applyTemplateButton:SetWidth(160)
    applyGroup:AddChild(applyTemplateButton)

    applyGroup:AddChild(CreateSpacer(0))

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

    local function RefreshTemplateDropdown()
        local list = {}

        for name in pairs(templates) do
            list[name] = name
        end

        templateSelect:SetList(list)
        templateSelect:SetValue(state.textBuilder.selectedTemplate or nil)
    end

    local function SetStatus(message)
        if ns.guiFrame and ns.guiFrame.SetStatusText then
            ns.guiFrame:SetStatusText(message)
        end
    end

    local function ApplyTemplateToTextSlot()
        local slotKey = state.textBuilder.applySlot or "Custom1"
        local unitKey = applyUnitDropdown:GetValue() or C.Units.PLAYER
        local template = templateEdit:GetText() or ""

        ns.GUI.Helpers.OptionValues.Set({ "Units", unitKey, "Texts", slotKey, "tag" }, template)
        ns.GUI.Helpers.OptionRefresh.Live()

        if ns.GUI and ns.GUI.RefreshOptions then
            ns.GUI:RefreshOptions()
        end

        SetStatus(string.format(
            "%s: %s -> %s",
            L["INFO_TEXT_BUILDER_STATUS_APPLIED_TO"] or "Applied to",
            ns.GetLabel(KM.Texts, slotKey == "Custom1" and C.Texts.CUSTOM_1 or slotKey == "Custom2" and C.Texts.CUSTOM_2 or C.Texts.CUSTOM_3),
            ns.GetLabel(KM.Units, unitKey)
        ))
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

    applySlotDropdown:SetCallback("OnValueChanged", function(_, _, value)
        state.textBuilder.applySlot = value or "Custom1"
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

    AddPageHeading(container, unitLabel .. " - " .. ns.GetLabel(KM.Tabs, C.Tabs.BARS) .. " - " .. ns.GetLabel(KM.Bars, C.Bars.POWER))

    local function ResolveDisabled(def)
        if def.disabled == "unit" then
            return IsUnitDisabled
        end

        if def.disabled == "power" then
            return IsPowerBarDisabled
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

    for _, sectionDef in ipairs(TEXT_TAB_LAYOUT) do
        AddSectionHeading(container, ResolveLayoutText(sectionDef.section))

        if sectionDef.mode == "section" then
            local layout = CreateSection(container)
            for _, item in ipairs(sectionDef.items) do
                AddSectionWidget(layout, item)
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
            for _, def in ipairs(TEXT_TAB_DEFS) do
                if def.configKey == textConfigKey then
                    textLabel = ns.GetLabel(KM.Texts, def.value)
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
