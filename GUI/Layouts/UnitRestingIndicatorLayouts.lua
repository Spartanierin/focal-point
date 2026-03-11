local addonName, ns = ...

ns.GUI = ns.GUI or {}
ns.GUI.Layouts = ns.GUI.Layouts or {}

ns.GUI.Layouts.UnitRestingIndicator = ns.GUI.Layouts.UnitRestingIndicator or {}

ns.GUI.Layouts.UnitRestingIndicator.RestingIndicatorTab = {
    {
        section = "SECTION_GENERAL",
        mode = "section",
        layout = "list",
        items = {
            { widget = "checkbox", path = { "Units", "$unitKey", "RestingIndicator", "enabled" }, label = "OPTION_RESTING_INDICATOR_ENABLED", description = "OPTION_RESTING_INDICATOR_ENABLED_DESC", fallback = true, refreshGUI = true, disabled = "unit" },
            { widget = "dropdown", path = { "Units", "$unitKey", "RestingIndicator", "placement" }, label = "OPTION_RESTING_INDICATOR_PLACEMENT", description = "OPTION_RESTING_INDICATOR_PLACEMENT_DESC", list = "placement", fallback = "ATTACHED", refreshGUI = true, disabled = "resting" },
            { widget = "slider", path = { "Units", "$unitKey", "RestingIndicator", "size" }, label = "OPTION_RESTING_INDICATOR_SIZE", description = "OPTION_RESTING_INDICATOR_SIZE_DESC", min = 8, max = 64, step = 1, fallback = 16, format = "%d", disabled = "resting" },
            { widget = "slider", path = { "Units", "$unitKey", "RestingIndicator", "scale" }, label = "OPTION_RESTING_INDICATOR_SCALE", description = "OPTION_RESTING_INDICATOR_SCALE_DESC", min = 0.25, max = 3.0, step = 0.01, fallback = 1.0, format = "%.2f", disabled = "resting" },
        },
    },
    {
        section = "SECTION_INSIDE",
        mode = "section",
        layout = "list",
        items = {
            { widget = "slider", path = { "Units", "$unitKey", "RestingIndicator", "padding" }, label = "OPTION_PADDING", description = "OPTION_RESTING_INDICATOR_PADDING_DESC", min = 0, max = 32, step = 1, fallback = 2, format = "%d", disabled = "inside" },
            { widget = "dropdown", path = { "Units", "$unitKey", "RestingIndicator", "insideSide" }, label = "OPTION_INSIDE_SIDE", description = "OPTION_RESTING_INDICATOR_INSIDE_SIDE_DESC", list = "insideSide", fallback = "LEFT", disabled = "inside" },
        },
    },
    {
        section = "SECTION_ATTACHED",
        mode = "section",
        layout = "list",
        items = {
            { widget = "dropdown", path = { "Units", "$unitKey", "RestingIndicator", "anchorTo" }, label = "OPTION_ANCHOR_TO_TARGET", description = "OPTION_RESTING_INDICATOR_ANCHOR_TO_TARGET_DESC", list = "anchorTo", fallback = "Frame", disabled = "attached" },
            { widget = "dropdown", path = { "Units", "$unitKey", "RestingIndicator", "point" }, label = "OPTION_ANCHOR_FROM", description = "OPTION_RESTING_INDICATOR_ANCHOR_FROM_DESC", list = "anchorPoints", fallback = "TOPLEFT", disabled = "attached" },
            { widget = "dropdown", path = { "Units", "$unitKey", "RestingIndicator", "relativePoint" }, label = "OPTION_ANCHOR_TO", description = "OPTION_RESTING_INDICATOR_ANCHOR_TO_DESC", list = "anchorPoints", fallback = "TOP", disabled = "attached" },
            { widget = "slider", path = { "Units", "$unitKey", "RestingIndicator", "offsetX" }, label = "OPTION_X_OFFSET", description = "OPTION_RESTING_INDICATOR_OFFSET_X_DESC", min = -500, max = 500, step = 1, fallback = 0, format = "%d", disabled = "attached" },
            { widget = "slider", path = { "Units", "$unitKey", "RestingIndicator", "offsetY" }, label = "OPTION_Y_OFFSET", description = "OPTION_RESTING_INDICATOR_OFFSET_Y_DESC", min = -500, max = 500, step = 1, fallback = 0, format = "%d", disabled = "attached" },
        },
    },
}

ns.GUI.Layouts.UnitRestingIndicator.Lists = {
    placement = {
        INSIDE = "VALUE_PORTRAIT_PLACEMENT_INSIDE",
        ATTACHED = "VALUE_PORTRAIT_PLACEMENT_ATTACHED",
    },
    insideSide = {
        LEFT = "VALUE_SIDE_LEFT",
        RIGHT = "VALUE_SIDE_RIGHT",
    },
    anchorTo = {
        Frame = "VALUE_ANCHOR_TARGET_FRAME",
        HealthBar = "VALUE_ANCHOR_TARGET_HEALTH_BAR",
        PowerBar = "VALUE_ANCHOR_TARGET_POWER_BAR",
    },
    anchorPoints = {
        TOPLEFT = "VALUE_ANCHOR_TOPLEFT",
        TOP = "VALUE_ANCHOR_TOP",
        TOPRIGHT = "VALUE_ANCHOR_TOPRIGHT",
        LEFT = "VALUE_ANCHOR_LEFT",
        CENTER = "VALUE_ANCHOR_CENTER",
        RIGHT = "VALUE_ANCHOR_RIGHT",
        BOTTOMLEFT = "VALUE_ANCHOR_BOTTOMLEFT",
        BOTTOM = "VALUE_ANCHOR_BOTTOM",
        BOTTOMRIGHT = "VALUE_ANCHOR_BOTTOMRIGHT",
    },
}
