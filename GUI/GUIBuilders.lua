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

local function CreateSection(container)
    return SectionLayout.CreateTwoColumn(container, {
        gutter = 16,
        minColumnWidth = 300,
    })
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
    }
end

local function BuildUnitPortraitElementPage(container, unitKey)
    container:ReleaseChildren()
    container:SetLayout("Flow")

    local unitLabel = ns.GetLabel(KM.Units, unitKey)

    local function IsUnitDisabled()
        return not ns.GUI.Helpers.OptionValues.Get({ "Units", unitKey, "enabled" }, true)
    end

    local function IsPortraitDisabled()
        return IsUnitDisabled()
            or not ns.GUI.Helpers.OptionValues.Get({ "Units", unitKey, "Portrait", "enabled" }, true)
    end

    local function IsPortraitInsideDisabled()
        return IsPortraitDisabled()
            or ns.GUI.Helpers.OptionValues.Get({ "Units", unitKey, "Portrait", "placement" }, "INSIDE") ~= "INSIDE"
    end

    local function IsPortraitAttachedDisabled()
        return IsPortraitDisabled()
            or ns.GUI.Helpers.OptionValues.Get({ "Units", unitKey, "Portrait", "placement" }, "INSIDE") ~= "ATTACHED"
    end

    local PORTRAIT_TAB_LISTS = ns.GUI.Layouts.UnitPortrait.Lists
    local PORTRAIT_TAB_LAYOUT = ns.GUI.Layouts.UnitPortrait.PortraitTab

    local function ResolveText(value)
        if type(value) ~= "string" then
            return value
        end

        return L[value] or value
    end

    local function ResolvePath(path)
        if type(path) ~= "table" then
            return path
        end

        local resolved = {}
        for i, part in ipairs(path) do
            if part == "$unitKey" then
                resolved[i] = unitKey
            else
                resolved[i] = part
            end
        end
        return resolved
    end

    local function ResolveList(list)
        if type(list) ~= "table" then
            return list
        end

        local resolved = {}
        for key, value in pairs(list) do
            resolved[key] = ResolveText(value)
        end
        return resolved
    end

    local function ResolveDisabled(def)
        if def.disabled == "unit" then
            return IsUnitDisabled
        end

        if def.disabled == "portrait" then
            return IsPortraitDisabled
        end

        if def.disabled == "inside" then
            return IsPortraitInsideDisabled
        end

        if def.disabled == "attached" then
            return IsPortraitAttachedDisabled
        end

        return nil
    end

    local function AddSectionWidget(layout, def)
        if def.widget == "checkbox" then
            layout:Add(Checkbox.Create({
                path = ResolvePath(def.path),
                label = ResolveText(def.label),
                description = ResolveText(def.description),
                fallback = def.fallback,
                resetText = L["OPTION_RESET"],
                disabled = ResolveDisabled(def),
                refreshGUI = def.refreshGUI,
            }))
            return
        end

        if def.widget == "dropdown" then
            layout:Add(Dropdown.Create({
                path = ResolvePath(def.path),
                label = ResolveText(def.label),
                description = ResolveText(def.description),
                list = ResolveList(PORTRAIT_TAB_LISTS[def.list]),
                fallback = def.fallback,
                resetText = L["OPTION_RESET"],
                disabled = ResolveDisabled(def),
                refreshGUI = def.refreshGUI,
            }))
            return
        end

        if def.widget == "slider" then
            layout:Add(Slider.Create({
                path = ResolvePath(def.path),
                label = ResolveText(def.label),
                description = ResolveText(def.description),
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

    local title = AceGUI:Create("Heading")
    title:SetFullWidth(true)
    title:SetText(unitLabel .. " - " .. ns.GetLabel(KM.Tabs, C.Tabs.ELEMENTS) .. " - " .. ns.GetLabel(KM.Elements, C.Elements.PORTRAIT))
    container:AddChild(title)

    for _, sectionDef in ipairs(PORTRAIT_TAB_LAYOUT) do
        AddSectionHeading(container, ResolveText(sectionDef.section))

        if sectionDef.mode == "section" then
            local layout = CreateSection(container)
            for _, item in ipairs(sectionDef.items) do
                AddSectionWidget(layout, item)
            end
        end
    end
end

local function BuildUnitRaidTargetElementPage(container, unitKey)
    container:ReleaseChildren()
    container:SetLayout("Flow")

    local unitLabel = ns.GetLabel(KM.Units, unitKey)

    local function IsUnitDisabled()
        return not ns.GUI.Helpers.OptionValues.Get({ "Units", unitKey, "enabled" }, true)
    end

    local function IsRTMDisabled()
        return IsUnitDisabled()
            or not ns.GUI.Helpers.OptionValues.Get({ "Units", unitKey, "RaidTargetIcon", "enabled" }, true)
    end

    local function IsRTMInsideDisabled()
        return IsRTMDisabled()
            or ns.GUI.Helpers.OptionValues.Get({ "Units", unitKey, "RaidTargetIcon", "placement" }, "ATTACHED") ~= "INSIDE"
    end

    local function IsRTMAttachedDisabled()
        return IsRTMDisabled()
            or ns.GUI.Helpers.OptionValues.Get({ "Units", unitKey, "RaidTargetIcon", "placement" }, "ATTACHED") ~= "ATTACHED"
    end

    local title = AceGUI:Create("Heading")
    title:SetFullWidth(true)
    title:SetText(unitLabel .. " - " .. ns.GetLabel(KM.Tabs, C.Tabs.ELEMENTS) .. " - " .. ns.GetLabel(KM.Elements, C.Elements.RAID_TARGET_ICON))
    container:AddChild(title)

    AddSectionHeading(container, ns.GetLabel(KM.Elements, C.Elements.RAID_TARGET_ICON))

    local layout = CreateSection(container)

    layout:Add(Checkbox.Create({
        path = { "Units", unitKey, "RaidTargetIcon", "enabled" },
        label = "RTM aktivieren",
        description = "Blendet das Schlachtzugszielsymbol für diese Unit ein oder aus.",
        fallback = true,
        resetText = false,
        disabled = IsUnitDisabled,
        refreshGUI = true,
    }))

    layout:Add(Dropdown.Create({
        path = { "Units", unitKey, "RaidTargetIcon", "placement" },
        label = "RTM-Platzierung",
        description = "Bestimmt, ob das RTM innerhalb des Frames oder außen angeheftet sitzt.",
        list = {
            INSIDE = "INSIDE",
            ATTACHED = "ATTACHED",
        },
        fallback = "ATTACHED",
        resetText = L["OPTION_RESET"],
        disabled = IsRTMDisabled,
        refreshGUI = true,
    }))

    layout:Add(Slider.Create({
        path = { "Units", unitKey, "RaidTargetIcon", "size" },
        label = "RTM-Größe",
        description = "Legt die Grundgröße des Schlachtzugszielsymbols fest.",
        min = 8,
        max = 128,
        step = 1,
        fallback = 18,
        format = "%d",
        resetText = L["OPTION_RESET"],
        disabled = IsRTMDisabled,
    }))

    layout:Add(Slider.Create({
        path = { "Units", unitKey, "RaidTargetIcon", "scale" },
        label = "RTM-Skalierung",
        description = "Skaliert das Schlachtzugszielsymbol proportional.",
        min = 0.25,
        max = 3.0,
        step = 0.01,
        fallback = 1.0,
        format = "%.2f",
        resetText = L["OPTION_RESET"],
        disabled = IsRTMDisabled,
    }))

    layout:Add(Slider.Create({
        path = { "Units", unitKey, "RaidTargetIcon", "padding" },
        label = "Padding",
        description = "Abstand des RTM innerhalb des Frames zur gewählten Seite.",
        min = 0,
        max = 64,
        step = 1,
        fallback = 2,
        format = "%d",
        resetText = L["OPTION_RESET"],
        disabled = IsRTMInsideDisabled,
    }))

    layout:Add(Dropdown.Create({
        path = { "Units", unitKey, "RaidTargetIcon", "insideSide" },
        label = "Innenseite",
        description = "Auf welcher Seite das RTM innerhalb des Frames sitzt.",
        list = {
            LEFT = "LEFT",
            RIGHT = "RIGHT",
        },
        fallback = "RIGHT",
        resetText = L["OPTION_RESET"],
        disabled = IsRTMInsideDisabled,
    }))

    layout:Add(Dropdown.Create({
        path = { "Units", unitKey, "RaidTargetIcon", "anchorTo" },
        label = "Anchor To",
        description = "An welches Zielelement das Schlachtzugszielsymbol angehängt wird.",
        list = {
            Frame = "Frame",
            HealthBar = "HealthBar",
            PowerBar = "PowerBar",
        },
        fallback = "Frame",
        resetText = L["OPTION_RESET"],
        disabled = IsRTMAttachedDisabled,
    }))

    layout:Add(Dropdown.Create({
        path = { "Units", unitKey, "RaidTargetIcon", "point" },
        label = "Anchor From",
        description = "Punkt des Schlachtzugszielsymbols, der verankert wird.",
        list = {
            TOPLEFT = "TOPLEFT",
            TOP = "TOP",
            TOPRIGHT = "TOPRIGHT",
            LEFT = "LEFT",
            CENTER = "CENTER",
            RIGHT = "RIGHT",
            BOTTOMLEFT = "BOTTOMLEFT",
            BOTTOM = "BOTTOM",
            BOTTOMRIGHT = "BOTTOMRIGHT",
        },
        fallback = "TOP",
        resetText = L["OPTION_RESET"],
        disabled = IsRTMAttachedDisabled,
    }))

    layout:Add(Dropdown.Create({
        path = { "Units", unitKey, "RaidTargetIcon", "relativePoint" },
        label = "Anchor To",
        description = "Punkt des Zielelements, an den das Schlachtzugszielsymbol angeheftet wird.",
        list = {
            TOPLEFT = "TOPLEFT",
            TOP = "TOP",
            TOPRIGHT = "TOPRIGHT",
            LEFT = "LEFT",
            CENTER = "CENTER",
            RIGHT = "RIGHT",
            BOTTOMLEFT = "BOTTOMLEFT",
            BOTTOM = "BOTTOM",
            BOTTOMRIGHT = "BOTTOMRIGHT",
        },
        fallback = "TOP",
        resetText = L["OPTION_RESET"],
        disabled = IsRTMAttachedDisabled,
    }))

    layout:Add(Slider.Create({
        path = { "Units", unitKey, "RaidTargetIcon", "offsetX" },
        label = "Offset X",
        description = "Horizontaler Versatz des Schlachtzugszielsymbols.",
        min = -500,
        max = 500,
        step = 1,
        fallback = 0,
        format = "%d",
        resetText = L["OPTION_RESET"],
        disabled = IsRTMAttachedDisabled,
    }))

    layout:Add(Slider.Create({
        path = { "Units", unitKey, "RaidTargetIcon", "offsetY" },
        label = "Offset Y",
        description = "Vertikaler Versatz des Schlachtzugszielsymbols.",
        min = -500,
        max = 500,
        step = 1,
        fallback = 8,
        format = "%d",
        resetText = L["OPTION_RESET"],
        disabled = IsRTMAttachedDisabled,
    }))
end


function B.BuildPlaceholderPage(container, title)
    container:ReleaseChildren()
    container:SetLayout("Fill")

    local label = AceGUI:Create("Label")
    label:SetText((title or "TODO") .. " (TODO)")
    label:SetFullWidth(true)
    container:AddChild(label)
end

function B.BuildUnitFramePage(container, unitKey)
    container:ReleaseChildren()
    container:SetLayout("Flow")

    local unitLabel = ns.GetLabel(KM.Units, unitKey)

    local function IsUnitDisabled()
        return not ns.GUI.Helpers.OptionValues.Get({ "Units", unitKey, "enabled" }, true)
    end

    local FRAME_TAB_LISTS = ns.GUI.Layouts.UnitFrame.Lists
    local FRAME_TAB_LAYOUT = ns.GUI.Layouts.UnitFrame.FrameTab

    local function ResolveText(value)
        if type(value) ~= "string" then
            return value
        end

        return L[value] or value
    end

    local function ResolvePath(path)
        if type(path) ~= "table" then
            return path
        end

        local resolved = {}
        for i, part in ipairs(path) do
            if part == "$unitKey" then
                resolved[i] = unitKey
            else
                resolved[i] = part
            end
        end
        return resolved
    end

    local function ResolveList(list)
        if type(list) ~= "table" then
            return list
        end

        local resolved = {}
        for key, value in pairs(list) do
            resolved[key] = ResolveText(value)
        end
        return resolved
    end

    local title = AceGUI:Create("Heading")
    title:SetFullWidth(true)
    title:SetText(unitLabel .. " - " .. ns.GetLabel(KM.Tabs, C.Tabs.FRAME))
    container:AddChild(title)

    local function AddDirectCheckbox(def)
        local checkbox = AceGUI:Create("CheckBox")
        local path = ResolvePath(def.path)
        checkbox:SetLabel(ResolveText(def.label))
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
            description:SetText(ResolveText(def.description))
            container:AddChild(description)
        end
    end

    local function AddDirectLayerDropdown(def)
        local dropdown = AceGUI:Create("Dropdown")
        local path = ResolvePath(def.path)
        dropdown:SetLabel(ResolveText(def.label))
        dropdown:SetList(ResolveList(FRAME_TAB_LISTS[def.list]))
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
            description:SetText(ResolveText(def.description))
            container:AddChild(description)
        end
    end

    local function AddDirectLayerSlider(def)
        local slider = AceGUI:Create("Slider")
        local path = ResolvePath(def.path)
        slider:SetLabel(ResolveText(def.label))
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
            description:SetText(ResolveText(def.description))
            container:AddChild(description)
        end
    end

    local function AddSectionWidget(layout, def)  
        if def.widget == "slider" then
            layout:Add(Slider.Create({
                path = ResolvePath(def.path),
                label = ResolveText(def.label),
                description = ResolveText(def.description),
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
                path = ResolvePath(def.path),
                label = ResolveText(def.label),
                description = ResolveText(def.description),
                list = ResolveList(FRAME_TAB_LISTS[def.list]),
                fallback = def.fallback,
                resetText = L["OPTION_RESET"],
                disabled = IsUnitDisabled,
            }))
        end
    end

    for _, sectionDef in ipairs(FRAME_TAB_LAYOUT) do
        AddSectionHeading(container, ResolveText(sectionDef.section))

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

        widget:ReleaseChildren()
        widget:SetLayout("Fill")

        local scroll = AceGUI:Create("ScrollFrame")
        scroll:SetFullWidth(true)
        scroll:SetFullHeight(true)
        scroll:SetLayout("Flow")
        scroll:SetStatusTable(state.unitElementScroll[unitKey][elementKey])
        widget:AddChild(scroll)

        if elementKey == C.Elements.PORTRAIT then
            BuildUnitPortraitElementPage(scroll, unitKey)
            return
        elseif elementKey == C.Elements.RAID_TARGET_ICON then
            BuildUnitRaidTargetElementPage(scroll, unitKey)
            return
        end

        B.BuildPlaceholderPage(scroll, ns.GetLabel(KM.Elements, elementKey))
    end)

    container:AddChild(tabGroup)
    tabGroup:SelectTab(state.unitElementTabs[unitKey] or C.Elements.PORTRAIT)
end

function B.BuildUnitColorsPage(container, unitKey)
    container:ReleaseChildren()
    container:SetLayout("Flow")

    local unitLabel = ns.GetLabel(KM.Units, unitKey)

    local function IsUnitDisabled()
        return not ns.GUI.Helpers.OptionValues.Get({ "Units", unitKey, "enabled" }, true)
    end

    local function IsPowerBarDisabled()
        return IsUnitDisabled()
            or not ns.GUI.Helpers.OptionValues.Get({ "Units", unitKey, "showPowerBar" }, true)
    end

    local title = AceGUI:Create("Heading")
    title:SetFullWidth(true)
    title:SetText(unitLabel .. " - " .. ns.GetLabel(KM.Tabs, C.Tabs.COLORS))
    container:AddChild(title)

    AddSectionHeading(container, "Frame")

    local layout = CreateSection(container)

    layout:Add(ColorPicker.Create({
        path = { "Units", unitKey, "backgroundColor" },
        label = L["OPTION_BACKGROUND_COLOR"],
        description = L["OPTION_BACKGROUND_COLOR_DESC"],
        hasAlpha = true,
        resetText = L["OPTION_RESET"],
        disabled = IsUnitDisabled,
    }))

    layout:Add(ColorPicker.Create({
        path = { "Units", unitKey, "borderColor" },
        label = L["OPTION_BORDER_COLOR"],
        description = L["OPTION_BORDER_COLOR_DESC"],
        hasAlpha = true,
        resetText = L["OPTION_RESET"],
        disabled = IsUnitDisabled,
    }))

    AddSectionHeading(container, ns.GetLabel(KM.Bars, C.Bars.HEALTH))

    local function IsHealthColorPickerDisabled()
        return IsUnitDisabled()
            or ns.GUI.Helpers.OptionValues.Get({ "Units", unitKey, "useClassColorHealth" }, false)
    end

    local function IsHealthBackgroundPickerDisabled()
        return IsUnitDisabled()
            or not ns.GUI.Helpers.OptionValues.Get({ "Units", unitKey, "healthBackground" }, true)
    end

    layout = CreateSection(container)

    local healthColorPickerHandle = ColorPicker.Create({
        path = { "Units", unitKey, "healthColor" },
        label = L["OPTION_HEALTH_COLOR"],
        description = L["OPTION_HEALTH_COLOR_DESC"],
        hasAlpha = true,
        resetText = L["OPTION_RESET"],
        disabled = IsHealthColorPickerDisabled,
    })

    layout:Add(Checkbox.Create({
        path = { "Units", unitKey, "useClassColorHealth" },
        label = L["OPTION_USE_CLASS_COLORS"],
        description = L["OPTION_USE_CLASS_COLORS_HEALTH_DESC"],
        fallback = false,
        resetText = false,
        disabled = IsUnitDisabled,
        refreshGUI = true,
        onChanged = function()
            if healthColorPickerHandle and healthColorPickerHandle.RefreshState then
                healthColorPickerHandle.RefreshState()
            end
        end,
    }))

    layout:Add(healthColorPickerHandle)

    layout:Add(Checkbox.Create({
        path = { "Units", unitKey, "healthBackground" },
        label = L["OPTION_SHOW_BACKGROUND"],
        description = L["OPTION_HEALTH_BACKGROUND_DESC"],
        fallback = true,
        resetText = false,
        disabled = IsUnitDisabled,
        refreshGUI = true,
    }))

    layout:Add(ColorPicker.Create({
        path = { "Units", unitKey, "healthBackgroundColor" },
        label = L["OPTION_BACKGROUND_COLOR"],
        description = L["OPTION_HEALTH_BACKGROUND_COLOR_DESC"],
        hasAlpha = true,
        resetText = L["OPTION_RESET"],
        disabled = IsHealthBackgroundPickerDisabled,
    }))

    AddSectionHeading(container, ns.GetLabel(KM.Bars, C.Bars.POWER))

    local function IsPowerColorPickerDisabled()
        return IsPowerBarDisabled()
            or ns.GUI.Helpers.OptionValues.Get({ "Units", unitKey, "useClassColorPower" }, false)
    end

    local function IsPowerBackgroundPickerDisabled()
        return IsPowerBarDisabled()
            or not ns.GUI.Helpers.OptionValues.Get({ "Units", unitKey, "powerBackground" }, true)
    end

    layout = CreateSection(container)

    local powerColorPickerHandle = ColorPicker.Create({
        path = { "Units", unitKey, "powerColor" },
        label = L["OPTION_POWER_COLOR"],
        description = L["OPTION_POWER_COLOR_DESC"],
        hasAlpha = true,
        resetText = L["OPTION_RESET"],
        disabled = IsPowerColorPickerDisabled,
    })

    layout:Add(Checkbox.Create({
        path = { "Units", unitKey, "useClassColorPower" },
        label = L["OPTION_USE_CLASS_COLORS"],
        description = L["OPTION_USE_CLASS_COLORS_POWER_DESC"],
        fallback = false,
        resetText = L["OPTION_RESET"],
        disabled = IsPowerBarDisabled,
        refreshGUI = true,
        onChanged = function()
            if powerColorPickerHandle and powerColorPickerHandle.RefreshState then
                powerColorPickerHandle.RefreshState()
            end
        end,
    }))

    layout:Add(powerColorPickerHandle)

    layout:Add(Checkbox.Create({
        path = { "Units", unitKey, "powerBackground" },
        label = L["OPTION_SHOW_BACKGROUND"],
        description = L["OPTION_POWER_BACKGROUND_DESC"],
        fallback = true,
        resetText = L["OPTION_RESET"],
        disabled = IsPowerBarDisabled,
        refreshGUI = true,
    }))

    layout:Add(ColorPicker.Create({
        path = { "Units", unitKey, "powerBackgroundColor" },
        label = L["OPTION_BACKGROUND_COLOR"],
        description = L["OPTION_POWER_BACKGROUND_COLOR_DESC"],
        hasAlpha = true,
        resetText = L["OPTION_RESET"],
        disabled = IsPowerBackgroundPickerDisabled,
    }))
end

function B.BuildUnitHealthBarPage(container, unitKey)
    container:ReleaseChildren()
    container:SetLayout("Flow")

    local unitLabel = ns.GetLabel(KM.Units, unitKey)

    local title = AceGUI:Create("Heading")
    title:SetFullWidth(true)
    title:SetText(unitLabel .. " - " .. ns.GetLabel(KM.Tabs, C.Tabs.BARS) .. " - " .. ns.GetLabel(KM.Bars, C.Bars.HEALTH))
    container:AddChild(title)

    local label = AceGUI:Create("Label")
    label:SetFullWidth(true)
    label:SetText([[Farboptionen für den Gesundheitsbalken findest du jetzt im Tab "Farben".]])
    container:AddChild(label)
end

function B.BuildUnitPowerBarPage(container, unitKey)
    container:ReleaseChildren()
    container:SetLayout("Flow")

    local unitLabel = ns.GetLabel(KM.Units, unitKey)

    local function IsUnitDisabled()
        return not ns.GUI.Helpers.OptionValues.Get({ "Units", unitKey, "enabled" }, true)
    end

    local function IsPowerBarDisabled()
        return IsUnitDisabled()
            or not ns.GUI.Helpers.OptionValues.Get({ "Units", unitKey, "showPowerBar" }, true)
    end

    local title = AceGUI:Create("Heading")
    title:SetFullWidth(true)
    title:SetText(unitLabel .. " - " .. ns.GetLabel(KM.Tabs, C.Tabs.BARS) .. " - " .. ns.GetLabel(KM.Bars, C.Bars.POWER))
    container:AddChild(title)

    -- General
    AddSectionHeading(container, L["SECTION_GENERAL"])

    local layout = CreateSection(container)

    layout:Add(Checkbox.Create({
        path = { "Units", unitKey, "showPowerBar" },
        label = L["OPTION_SHOW_POWER_BAR"],
        description = L["OPTION_SHOW_POWER_BAR_DESC"],
        fallback = true,
        resetText = false,
        disabled = IsUnitDisabled,
        refreshGUI = true,
    }))

    layout:Add(Slider.Create({
        path = { "Units", unitKey, "powerBarHeight" },
        label = L["OPTION_POWER_BAR_HEIGHT"],
        description = L["OPTION_POWER_BAR_HEIGHT_DESC"],
        min = 4,
        max = 30,
        step = 1,
        fallback = 8,
        format = "%d",
        resetText = L["OPTION_RESET"],
        disabled = IsPowerBarDisabled,
    }))
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

        widget:ReleaseChildren()
        widget:SetLayout("Fill")

        local scroll = AceGUI:Create("ScrollFrame")
        scroll:SetFullWidth(true)
        scroll:SetFullHeight(true)
        scroll:SetLayout("Flow")
        scroll:SetStatusTable(state.unitBarScroll[unitKey][barKey])
        widget:AddChild(scroll)

        if barKey == C.Bars.HEALTH then
            B.BuildUnitHealthBarPage(scroll, unitKey)
            return
        end

        if barKey == C.Bars.POWER then
            B.BuildUnitPowerBarPage(scroll, unitKey)
            return
        end

        B.BuildPlaceholderPage(scroll, ns.GetLabel(KM.Bars, barKey))
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