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
                ns.GUI:RefreshConfig()
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
        slider:SetWidth(320)
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

        return ResolveLayoutText(sectionKey)
    end

    local function ResolveColorDisabled(def)
        if def.disabled == "unit" then
            return IsUnitDisabled
        end

        if def.disabled == "power" then
            return IsPowerBarDisabled
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

    AddPageHeading(container, unitLabel .. " - " .. ns.GetLabel(KM.Tabs, C.Tabs.BARS) .. " - " .. ns.GetLabel(KM.Bars, C.Bars.HEALTH))

    local label = AceGUI:Create("Label")
    label:SetFullWidth(true)
    label:SetText(L["INFO_HEALTH_BAR_COLORS_MOVED"])
    container:AddChild(label)
end

function B.BuildUnitPowerBarPage(container, unitKey)
    ResetFlowContainer(container)

    local unitLabel = ns.GetLabel(KM.Units, unitKey)
    local POWER_BAR_LAYOUT = ns.GUI.Layouts.UnitBars.PowerBarTab

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
        if not CanBuildLayoutWidget(def) then
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
                ns.GUI:RefreshConfig()
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
                ns.GUI:RefreshConfig()
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
