local addonName, ns = ...

ns.GUIBuilders = ns.GUIBuilders or {}
local B = ns.GUIBuilders

local AceGUI = LibStub("AceGUI-3.0")
local C = ns.Constants
local KM = ns.KeyMap
local L = ns.L

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

local function AddCheckbox(container, label, value)
    local cb = AceGUI:Create("CheckBox")
    cb:SetLabel(label)
    cb:SetValue(value and true or false)
    cb:SetFullWidth(true)
    container:AddChild(cb)
    return cb
end

local function AddSlider(container, label, minVal, maxVal, step, value)
    local slider = AceGUI:Create("Slider")
    slider:SetLabel(label)
    slider:SetSliderValues(minVal, maxVal, step)
    slider:SetValue(value or minVal)
    slider:SetFullWidth(true)
    container:AddChild(slider)
    return slider
end

local function AddDropdown(container, label, items, value)
    local dd = AceGUI:Create("Dropdown")
    dd:SetLabel(label)
    dd:SetList(items)
    dd:SetValue(value)
    dd:SetFullWidth(true)
    container:AddChild(dd)
    return dd
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
    AddCheckbox(container, L["OPTION_ENABLED"], true)
    AddSlider(container, L["OPTION_WIDTH"], 50, 600, 1, 220)
    AddSlider(container, L["OPTION_HEIGHT"], 10, 200, 1, 45)
    AddSlider(container, L["OPTION_SCALE"], 0.5, 2.0, 0.01, 1.0)
    AddSlider(container, L["OPTION_ALPHA"], 0.0, 1.0, 0.01, 1.0)

    -- Position
    AddSectionHeading(container, L["SECTION_POSITION"])
    AddDropdown(container, L["OPTION_ANCHOR_FROM"], {
        TOPLEFT = "TOPLEFT",
        TOP = "TOP",
        TOPRIGHT = "TOPRIGHT",
        LEFT = "LEFT",
        CENTER = "CENTER",
        RIGHT = "RIGHT",
        BOTTOMLEFT = "BOTTOMLEFT",
        BOTTOM = "BOTTOM",
        BOTTOMRIGHT = "BOTTOMRIGHT",
    }, "CENTER")

    AddDropdown(container, L["OPTION_ANCHOR_TO"], {
        TOPLEFT = "TOPLEFT",
        TOP = "TOP",
        TOPRIGHT = "TOPRIGHT",
        LEFT = "LEFT",
        CENTER = "CENTER",
        RIGHT = "RIGHT",
        BOTTOMLEFT = "BOTTOMLEFT",
        BOTTOM = "BOTTOM",
        BOTTOMRIGHT = "BOTTOMRIGHT",
    }, "CENTER")

    AddSlider(container, L["OPTION_X_OFFSET"], -1000, 1000, 1, 0)
    AddSlider(container, L["OPTION_Y_OFFSET"], -1000, 1000, 1, 0)

    -- Layering
    AddSectionHeading(container, L["SECTION_LAYERING"])
    AddDropdown(container, L["OPTION_FRAME_STRATA"], {
        BACKGROUND = "BACKGROUND",
        LOW = "LOW",
        MEDIUM = "MEDIUM",
        HIGH = "HIGH",
        DIALOG = "DIALOG",
        FULLSCREEN = "FULLSCREEN",
        FULLSCREEN_DIALOG = "FULLSCREEN_DIALOG",
        TOOLTIP = "TOOLTIP",
    }, "MEDIUM")

    AddSlider(container, L["OPTION_FRAME_LEVEL"], 0, 50, 1, 1)

    -- Behavior
    AddSectionHeading(container, L["SECTION_BEHAVIOR"])
    AddCheckbox(container, "Mouse Enabled", true)
    AddCheckbox(container, "Click Through", false)
    AddCheckbox(container, "Clamp to Screen", false)
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

        if tabKey == C.Tabs.FRAME then
            B.BuildUnitFramePage(widget, unitKey)
            return
        end

        local unitLabel = ns.GetLabel(KM.Units, unitKey)
        local tabLabel = ns.GetLabel(KM.Tabs, tabKey)
        B.BuildPlaceholderPage(widget, unitLabel .. " - " .. tabLabel)
    end)

    container:AddChild(tabGroup)
    tabGroup:SelectTab(C.Tabs.FRAME)
end