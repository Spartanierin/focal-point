local addonName, ns = ...

ns.GUIBuilders = ns.GUIBuilders or {}
local B = ns.GUIBuilders

local AceGUI = LibStub("AceGUI-3.0")
local C = ns.Constants
local KM = ns.KeyMap
local L = ns.L
local ColorPicker = ns.GUI.Widgets.ColorPicker
local Slider = ns.GUI.Widgets.Slider
local Dropdown = ns.GUI.Widgets.Dropdown
local Checkbox = ns.GUI.Widgets.Checkbox

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

    local title = AceGUI:Create("Heading")
    title:SetFullWidth(true)
    title:SetText(unitLabel .. " - " .. ns.GetLabel(KM.Tabs, C.Tabs.FRAME))
    container:AddChild(title)

    -- General
    AddSectionHeading(container, L["SECTION_GENERAL"])
    
    Checkbox.Create(container, {
        path = { "Units", unitKey, "enabled" },
        label = L["OPTION_ENABLED"],
        description = L["OPTION_ENABLED_DESC"],
        fallback = true,
        resetText = L["OPTION_RESET"],
    })
    
    Slider.Create(container, {
        path = { "Units", unitKey, "width" },
        label = L["OPTION_WIDTH"],
        description = L["OPTION_WIDTH_DESC"],
        min = 50,
        max = 600,
        step = 1,
        fallback = 220,
        format = "%d",
        resetText = L["OPTION_RESET"],
    })
    
    Slider.Create(container, {
        path = { "Units", unitKey, "height" },
        label = L["OPTION_HEIGHT"],
        description = L["OPTION_HEIGHT_DESC"],
        min = 10,
        max = 200,
        step = 1,
        fallback = 45,
        format = "%d",
        resetText = L["OPTION_RESET"],
    })
    
    Slider.Create(container, {
        path = { "Units", unitKey, "scale" },
        label = L["OPTION_SCALE"],
        description = L["OPTION_SCALE_DESC"],
        min = 0.5,
        max = 2.0,
        step = 0.01,
        fallback = 1.0,
        format = "%.2f",
        resetText = L["OPTION_RESET"],
    })
    
    Slider.Create(container, {
        path = { "Units", unitKey, "alpha" },
        label = L["OPTION_ALPHA"],
        description = L["OPTION_ALPHA_DESC"],
        min = 0.0,
        max = 1.0,
        step = 0.01,
        fallback = 1.0,
        format = "%.2f",
        resetText = L["OPTION_RESET"],
    })

    -- Position
    AddSectionHeading(container, L["SECTION_POSITION"])
    
    Dropdown.Create(container, {
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
    })

    Dropdown.Create(container, {
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
    })

    Slider.Create(container, {
        path = { "Units", unitKey, "x" },
        label = L["OPTION_X_OFFSET"],
        description = L["OPTION_X_OFFSET_DESC"],
        min = -1000,
        max = 1000,
        step = 1,
        fallback = 0,
        format = "%d",
        resetText = L["OPTION_RESET"],
    })

    Slider.Create(container, {
        path = { "Units", unitKey, "y" },
        label = L["OPTION_Y_OFFSET"],
        description = L["OPTION_Y_OFFSET_DESC"],
        min = -1000,
        max = 1000,
        step = 1,
        fallback = 0,
        format = "%d",
        resetText = L["OPTION_RESET"],
    })

    -- Layering
    AddSectionHeading(container, L["SECTION_LAYERING"])
    
    Dropdown.Create(container, {
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
    })

    Slider.Create(container, {
        path = { "Units", unitKey, "frameLevel" },
        label = L["OPTION_FRAME_LEVEL"],
        description = L["OPTION_FRAME_LEVEL_DESC"],
        min = 0,
        max = 50,
        step = 1,
        fallback = 1,
        format = "%d",
        resetText = L["OPTION_RESET"],
    })

    -- Behavior
    AddSectionHeading(container, L["SECTION_BEHAVIOR"])
    
    Checkbox.Create(container, {
        path = { "Units", unitKey, "mouseEnabled" },
        label = L["OPTION_MOUSE_ENABLED"],
        description = L["OPTION_MOUSE_ENABLED_DESC"],
        fallback = true,
        resetText = L["OPTION_RESET"],
    })

    Checkbox.Create(container, {
        path = { "Units", unitKey, "clickThrough" },
        label = L["OPTION_CLICK_THROUGH"],
        description = L["OPTION_CLICK_THROUGH_DESC"],
        fallback = false,
        resetText = L["OPTION_RESET"],
    })
    
    Checkbox.Create(container, {
        path = { "Units", unitKey, "clampToScreen" },
        label = L["OPTION_CLAMP_TO_SCREEN"],
        description = L["OPTION_CLAMP_TO_SCREEN_DESC"],
        fallback = false,
        resetText = L["OPTION_RESET"],
    })

    -- Colors
    AddSectionHeading(container, L["SECTION_COLOR"])

    ColorPicker.Create(container, {
        path = { "Units", unitKey, "backgroundColor" },
        label = L["OPTION_BACKGROUND_COLOR"],
        description = L["OPTION_BACKGROUND_COLOR_DESC"],
        hasAlpha = true,
        resetText = L["OPTION_RESET"],
    })

    ColorPicker.Create(container, {
        path = { "Units", unitKey, "borderColor" },
        label = L["OPTION_BORDER_COLOR"],
        description = L["OPTION_BORDER_COLOR_DESC"],
        hasAlpha = true,
        resetText = L["OPTION_RESET"],
    })

    ColorPicker.Create(container, {
        path = { "Units", unitKey, "healthColor" },
        label = L["OPTION_HEALTH_COLOR"],
        description = L["OPTION_HEALTH_COLOR_DESC"],
        hasAlpha = true,
        resetText = L["OPTION_RESET"],
    })

    ColorPicker.Create(container, {
        path = { "Units", unitKey, "powerColor" },
        label = L["OPTION_POWER_COLOR"],
        description = L["OPTION_POWER_COLOR_DESC"],
        hasAlpha = true,
        resetText = L["OPTION_RESET"],
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

    local tabGroup = AceGUI:Create("TabGroup")
    tabGroup:SetFullWidth(true)
    tabGroup:SetFullHeight(true)
    tabGroup:SetLayout("Fill")
    tabGroup:SetTabs(GetUnitTabValues())

    tabGroup:SetCallback("OnGroupSelected", function(widget, _, tabKey)
        widget:ReleaseChildren()
        widget:SetLayout("Fill")

        local scroll = AceGUI:Create("ScrollFrame")
        scroll:SetFullWidth(true)
        scroll:SetFullHeight(true)
        scroll:SetLayout("Flow")
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
    tabGroup:SelectTab(C.Tabs.FRAME)
end