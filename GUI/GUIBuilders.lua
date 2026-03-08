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

    -- Test Mode
    table.insert(tree, MakeNode(
        C.Nav.TEST_MODE,
        ns.GetLabel(KM.Nav, C.Nav.TEST_MODE)
    ))

    -- Profiles
    table.insert(tree, MakeNode(
        C.Nav.PROFILES,
        ns.GetLabel(KM.Nav, C.Nav.PROFILES)
    ))

    return tree
end

local function AddSectionHeading(container, text)
    local heading = AceGUI:Create("Heading")
    heading:SetFullWidth(true)
    heading:SetText(text)
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

    local title = AceGUI:Create("Heading")
    title:SetFullWidth(true)
    title:SetText(unitLabel .. " - " .. ns.GetLabel(KM.Tabs, C.Tabs.FRAME))
    container:AddChild(title)

    -- General
    AddSectionHeading(container, L["SECTION_GENERAL"])

    local layout = CreateSection(container)

    layout:Add(Checkbox.Create({
        path = { "Units", unitKey, "enabled" },
        label = L["OPTION_ENABLED"],
        description = L["OPTION_ENABLED_DESC"],
        fallback = true,
        resetText = L["OPTION_RESET"],
        refreshGUI = true,
    }))

    layout:Add(Slider.Create({
        path = { "Units", unitKey, "width" },
        label = L["OPTION_WIDTH"],
        description = L["OPTION_WIDTH_DESC"],
        min = 50,
        max = 600,
        step = 1,
        fallback = 220,
        format = "%d",
        resetText = L["OPTION_RESET"],
        disabled = IsUnitDisabled,
    }))

    layout:Add(Slider.Create({
        path = { "Units", unitKey, "height" },
        label = L["OPTION_HEIGHT"],
        description = L["OPTION_HEIGHT_DESC"],
        min = 10,
        max = 200,
        step = 1,
        fallback = 45,
        format = "%d",
        resetText = L["OPTION_RESET"],
        disabled = IsUnitDisabled,
    }))

    layout:Add(Slider.Create({
        path = { "Units", unitKey, "scale" },
        label = L["OPTION_SCALE"],
        description = L["OPTION_SCALE_DESC"],
        min = 0.5,
        max = 2.0,
        step = 0.01,
        fallback = 1.0,
        format = "%.2f",
        resetText = L["OPTION_RESET"],
        disabled = IsUnitDisabled,
    }))

    layout:Add(Slider.Create({
        path = { "Units", unitKey, "alpha" },
        label = L["OPTION_ALPHA"],
        description = L["OPTION_ALPHA_DESC"],
        min = 0.0,
        max = 1.0,
        step = 0.01,
        fallback = 1.0,
        format = "%.2f",
        resetText = L["OPTION_RESET"],
        disabled = IsUnitDisabled,
    }))

    -- Portrait
    AddSectionHeading(container, "Portrait")

    layout = CreateSection(container)

    layout:Add(Checkbox.Create({
        path = { "Units", unitKey, "Portrait", "enabled" },
        label = "Portrait aktivieren",
        description = "Blendet das Portrait für diese Unit ein oder aus.",
        fallback = true,
        resetText = L["OPTION_RESET"],
        disabled = IsUnitDisabled,
        refreshGUI = true,
    }))

    layout:Add(Dropdown.Create({
        path = { "Units", unitKey, "Portrait", "placement" },
        label = "Portrait-Platzierung",
        description = "Bestimmt, ob das Portrait im Frame sitzt oder außen am Frame verankert wird.",
        list = {
            INSIDE = "INSIDE",
            ATTACHED = "ATTACHED",
        },
        fallback = "INSIDE",
        resetText = L["OPTION_RESET"],
        disabled = IsPortraitDisabled,
        refreshGUI = true,
    }))

    layout:Add(Dropdown.Create({
        path = { "Units", unitKey, "Portrait", "mode" },
        label = "Portrait-Modus",
        description = "Wählt zwischen 2D- und 3D-Portrait.",
        list = {
            ["2D"] = "2D",
            ["3D"] = "3D",
        },
        fallback = "2D",
        resetText = L["OPTION_RESET"],
        disabled = IsPortraitDisabled,
        refreshGUI = true,
    }))

    layout:Add(Slider.Create({
        path = { "Units", unitKey, "Portrait", "size" },
        label = "Portrait-Größe",
        description = "Legt die Grundgröße des Portraits fest.",
        min = 16,
        max = 256,
        step = 1,
        fallback = 40,
        format = "%d",
        resetText = L["OPTION_RESET"],
        disabled = IsPortraitDisabled,
    }))

    layout:Add(Slider.Create({
        path = { "Units", unitKey, "Portrait", "scale" },
        label = "Portrait-Skalierung",
        description = "Skaliert das Portrait proportional, ohne es zu verzerren.",
        min = 0.25,
        max = 3.0,
        step = 0.01,
        fallback = 1.0,
        format = "%.2f",
        resetText = L["OPTION_RESET"],
        disabled = IsPortraitDisabled,
    }))

    layout:Add(Slider.Create({
        path = { "Units", unitKey, "Portrait", "padding" },
        label = "Innenabstand",
        description = "Abstand zwischen Portrait und restlichem Frame-Inhalt.",
        min = 0,
        max = 20,
        step = 1,
        fallback = 4,
        format = "%d",
        resetText = L["OPTION_RESET"],
        disabled = IsPortraitInsideDisabled,
    }))

    layout:Add(Dropdown.Create({
        path = { "Units", unitKey, "Portrait", "insideSide" },
        label = "Innenseite",
        description = "Auf welcher Seite das Portrait innerhalb des Frames sitzt.",
        list = {
            LEFT = "LEFT",
            RIGHT = "RIGHT",
        },
        fallback = "LEFT",
        resetText = L["OPTION_RESET"],
        disabled = IsPortraitInsideDisabled,
    }))

    layout:Add(Dropdown.Create({
        path = { "Units", unitKey, "Portrait", "anchorTo" },
        label = "Anchor To",
        description = "An welches Zielelement das Portrait außen angehängt wird.",
        list = {
            Frame = "Frame",
            HealthBar = "HealthBar",
            PowerBar = "PowerBar",
        },
        fallback = "Frame",
        resetText = L["OPTION_RESET"],
        disabled = IsPortraitAttachedDisabled,
    }))

    layout:Add(Dropdown.Create({
        path = { "Units", unitKey, "Portrait", "point" },
        label = "Anchor From",
        description = "Punkt des Portraits, der verankert wird.",
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
        fallback = "LEFT",
        resetText = L["OPTION_RESET"],
        disabled = IsPortraitAttachedDisabled,
    }))

    layout:Add(Dropdown.Create({
        path = { "Units", unitKey, "Portrait", "relativePoint" },
        label = "Anchor To",
        description = "Punkt des Zielelements, an den das Portrait angeheftet wird.",
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
        fallback = "RIGHT",
        resetText = L["OPTION_RESET"],
        disabled = IsPortraitAttachedDisabled,
    }))

    layout:Add(Slider.Create({
        path = { "Units", unitKey, "Portrait", "offsetX" },
        label = "Offset X",
        description = "Horizontaler Versatz des Portraits.",
        min = -500,
        max = 500,
        step = 1,
        fallback = -4,
        format = "%d",
        resetText = L["OPTION_RESET"],
        disabled = IsPortraitAttachedDisabled,
    }))

    layout:Add(Slider.Create({
        path = { "Units", unitKey, "Portrait", "offsetY" },
        label = "Offset Y",
        description = "Vertikaler Versatz des Portraits.",
        min = -500,
        max = 500,
        step = 1,
        fallback = 0,
        format = "%d",
        resetText = L["OPTION_RESET"],
        disabled = IsPortraitAttachedDisabled,
    }))

    -- Position
    AddSectionHeading(container, L["SECTION_POSITION"])

    layout = CreateSection(container)

    layout:Add(Dropdown.Create({
        path = { "Units", unitKey, "point" },
        label = L["OPTION_ANCHOR_FROM"],
        description = L["OPTION_ANCHOR_FROM_DESC"],
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
        fallback = "CENTER",
        resetText = L["OPTION_RESET"],
        disabled = IsUnitDisabled,
    }))

    layout:Add(Dropdown.Create({
        path = { "Units", unitKey, "relativePoint" },
        label = L["OPTION_ANCHOR_TO"],
        description = L["OPTION_ANCHOR_TO_DESC"],
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
        fallback = "CENTER",
        resetText = L["OPTION_RESET"],
        disabled = IsUnitDisabled,
    }))

    layout:Add(Slider.Create({
        path = { "Units", unitKey, "x" },
        label = L["OPTION_X_OFFSET"],
        description = L["OPTION_X_OFFSET_DESC"],
        min = -1000,
        max = 1000,
        step = 1,
        fallback = 0,
        format = "%d",
        resetText = L["OPTION_RESET"],
        disabled = IsUnitDisabled,
    }))

    layout:Add(Slider.Create({
        path = { "Units", unitKey, "y" },
        label = L["OPTION_Y_OFFSET"],
        description = L["OPTION_Y_OFFSET_DESC"],
        min = -1000,
        max = 1000,
        step = 1,
        fallback = 0,
        format = "%d",
        resetText = L["OPTION_RESET"],
        disabled = IsUnitDisabled,
    }))

    -- Layering
    AddSectionHeading(container, L["SECTION_LAYERING"])

    layout = CreateSection(container)

    layout:Add(Dropdown.Create({
        path = { "Units", unitKey, "frameStrata" },
        label = L["OPTION_FRAME_STRATA"],
        description = L["OPTION_FRAME_STRATA_DESC"],
        list = {
            BACKGROUND = "BACKGROUND",
            LOW = "LOW",
            MEDIUM = "MEDIUM",
            HIGH = "HIGH",
            DIALOG = "DIALOG",
            FULLSCREEN = "FULLSCREEN",
            FULLSCREEN_DIALOG = "FULLSCREEN_DIALOG",
            TOOLTIP = "TOOLTIP",
        },
        fallback = "MEDIUM",
        resetText = L["OPTION_RESET"],
        disabled = IsUnitDisabled,
    }))

    layout:Add(Slider.Create({
        path = { "Units", unitKey, "frameLevel" },
        label = L["OPTION_FRAME_LEVEL"],
        description = L["OPTION_FRAME_LEVEL_DESC"],
        min = 0,
        max = 50,
        step = 1,
        fallback = 1,
        format = "%d",
        resetText = L["OPTION_RESET"],
        disabled = IsUnitDisabled,
    }))

    -- Behavior
    AddSectionHeading(container, L["SECTION_BEHAVIOR"])

    layout = CreateSection(container)

    layout:Add(Checkbox.Create({
        path = { "Units", unitKey, "mouseEnabled" },
        label = L["OPTION_MOUSE_ENABLED"],
        description = L["OPTION_MOUSE_ENABLED_DESC"],
        fallback = true,
        resetText = L["OPTION_RESET"],
        disabled = IsUnitDisabled,
    }))

    layout:Add(Checkbox.Create({
        path = { "Units", unitKey, "clickThrough" },
        label = L["OPTION_CLICK_THROUGH"],
        description = L["OPTION_CLICK_THROUGH_DESC"],
        fallback = false,
        resetText = L["OPTION_RESET"],
        disabled = IsUnitDisabled,
    }))

    layout:Add(Checkbox.Create({
        path = { "Units", unitKey, "clampToScreen" },
        label = L["OPTION_CLAMP_TO_SCREEN"],
        description = L["OPTION_CLAMP_TO_SCREEN_DESC"],
        fallback = false,
        resetText = L["OPTION_RESET"],
        disabled = IsUnitDisabled,
    }))

    -- Colors
    AddSectionHeading(container, L["SECTION_COLOR"])

    layout = CreateSection(container)

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

end

function B.BuildUnitHealthBarPage(container, unitKey)
    container:ReleaseChildren()
    container:SetLayout("Flow")

    local unitLabel = ns.GetLabel(KM.Units, unitKey)

    local function IsUnitDisabled()
        return not ns.GUI.Helpers.OptionValues.Get({ "Units", unitKey, "enabled" }, true)
    end

    local title = AceGUI:Create("Heading")
    title:SetFullWidth(true)
    title:SetText(unitLabel .. " - " .. ns.GetLabel(KM.Tabs, C.Tabs.BARS) .. " - " .. ns.GetLabel(KM.Bars, C.Bars.HEALTH))
    container:AddChild(title)

    AddSectionHeading(container, L["SECTION_COLOR"])

    local function IsHealthColorPickerDisabled()
        return IsUnitDisabled()
            or ns.GUI.Helpers.OptionValues.Get({ "Units", unitKey, "useClassColorHealth" }, false)
    end

    local layout = CreateSection(container)

    layout:Add(Checkbox.Create({
        path = { "Units", unitKey, "useClassColorHealth" },
        label = L["OPTION_USE_CLASS_COLORS"],
        description = L["OPTION_USE_CLASS_COLORS_HEALTH_DESC"],
        fallback = false,
        resetText = L["OPTION_RESET"],
        disabled = IsUnitDisabled,
        refreshGUI = true,
    }))

    layout:Add(ColorPicker.Create({
        path = { "Units", unitKey, "healthColor" },
        label = L["OPTION_HEALTH_COLOR"],
        description = L["OPTION_HEALTH_COLOR_DESC"],
        hasAlpha = true,
        resetText = L["OPTION_RESET"],
        disabled = IsHealthColorPickerDisabled,
    }))
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

    AddSectionHeading(container, L["SECTION_GENERAL"])

    local layout = CreateSection(container)

    layout:Add(Checkbox.Create({
        path = { "Units", unitKey, "showPowerBar" },
        label = L["OPTION_SHOW_POWER_BAR"],
        description = L["OPTION_SHOW_POWER_BAR_DESC"],
        fallback = true,
        resetText = L["OPTION_RESET"],
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

    AddSectionHeading(container, L["SECTION_COLOR"])

    local function IsPowerColorPickerDisabled()
        return IsPowerBarDisabled()
            or ns.GUI.Helpers.OptionValues.Get({ "Units", unitKey, "useClassColorPower" }, false)
    end

    layout = CreateSection(container)

    layout:Add(Checkbox.Create({
        path = { "Units", unitKey, "useClassColorPower" },
        label = L["OPTION_USE_CLASS_COLORS"],
        description = L["OPTION_USE_CLASS_COLORS_POWER_DESC"],
        fallback = false,
        resetText = L["OPTION_RESET"],
        disabled = IsPowerBarDisabled,
        refreshGUI = true,
    }))
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

    AddSectionHeading(container, L["SECTION_GENERAL"])

    local layout = CreateSection(container)

    layout:Add(Checkbox.Create({
        path = { "Units", unitKey, "showPowerBar" },
        label = L["OPTION_SHOW_POWER_BAR"],
        description = L["OPTION_SHOW_POWER_BAR_DESC"],
        fallback = true,
        resetText = L["OPTION_RESET"],
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

    AddSectionHeading(container, L["SECTION_COLOR"])

    layout = CreateSection(container)

    layout:Add(ColorPicker.Create({
        path = { "Units", unitKey, "powerColor" },
        label = L["OPTION_POWER_COLOR"],
        description = L["OPTION_POWER_COLOR_DESC"],
        hasAlpha = true,
        resetText = L["OPTION_RESET"],
        disabled = IsPowerColorPickerDisabled,
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

        local unitLabel = ns.GetLabel(KM.Units, unitKey)
        local tabLabel = ns.GetLabel(KM.Tabs, tabKey)
        B.BuildPlaceholderPage(scroll, unitLabel .. " - " .. tabLabel)
    end)

    container:AddChild(tabGroup)
    tabGroup:SelectTab(state.unitTabs[unitKey] or C.Tabs.FRAME)
end