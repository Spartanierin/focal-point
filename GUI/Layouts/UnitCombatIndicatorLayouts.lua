local addonName, ns = ...

ns.GUI = ns.GUI or {}
ns.GUI.Layouts = ns.GUI.Layouts or {}

ns.GUI.Layouts.UnitCombatIndicator = ns.GUI.Layouts.UnitCombatIndicator or {}

ns.GUI.Layouts.UnitCombatIndicator.CombatIndicatorTab = {
    {
        section = "SECTION_GENERAL",
        mode = "section",
        layout = "list",
        items = {
            { widget = "checkbox", path = { "Units", "$unitKey", "CombatIndicator", "enabled" }, label = "OPTION_COMBAT_INDICATOR_ENABLED", description = "OPTION_COMBAT_INDICATOR_ENABLED_DESC", fallback = true, refreshGUI = true, disabled = "unit" },
            { widget = "dropdown", path = { "Units", "$unitKey", "CombatIndicator", "placement" }, label = "OPTION_COMBAT_INDICATOR_PLACEMENT", description = "OPTION_COMBAT_INDICATOR_PLACEMENT_DESC", list = "placement", fallback = "ATTACHED", refreshGUI = true, disabled = "combat" },
            { widget = "slider", path = { "Units", "$unitKey", "CombatIndicator", "size" }, label = "OPTION_COMBAT_INDICATOR_SIZE", description = "OPTION_COMBAT_INDICATOR_SIZE_DESC", min = 8, max = 64, step = 1, fallback = 16, format = "%d", disabled = "combat" },
            { widget = "slider", path = { "Units", "$unitKey", "CombatIndicator", "scale" }, label = "OPTION_COMBAT_INDICATOR_SCALE", description = "OPTION_COMBAT_INDICATOR_SCALE_DESC", min = 0.25, max = 3.0, step = 0.01, fallback = 1.0, format = "%.2f", disabled = "combat" },
        },
    },
    {
        section = "SECTION_INSIDE",
        mode = "section",
        layout = "list",
        items = {
            { widget = "slider", path = { "Units", "$unitKey", "CombatIndicator", "padding" }, label = "OPTION_PADDING", description = "OPTION_COMBAT_INDICATOR_PADDING_DESC", min = 0, max = 32, step = 1, fallback = 2, format = "%d", disabled = "inside" },
            { widget = "dropdown", path = { "Units", "$unitKey", "CombatIndicator", "insideSide" }, label = "OPTION_INSIDE_SIDE", description = "OPTION_COMBAT_INDICATOR_INSIDE_SIDE_DESC", list = "insideSide", fallback = "RIGHT", disabled = "inside" },
            { widget = "dropdown", path = { "Units", "$unitKey", "CombatIndicator", "insideAnchorTo" }, label = "OPTION_ANCHOR_TO_TARGET", list = "anchorTo", fallback = "Frame", disabled = "inside" },
        },
    },
    {
        section = "SECTION_ATTACHED",
        mode = "section",
        layout = "list",
        items = {
            { widget = "dropdown", path = { "Units", "$unitKey", "CombatIndicator", "anchorTo" }, label = "OPTION_ANCHOR_TO_TARGET", description = "OPTION_COMBAT_INDICATOR_ANCHOR_TO_TARGET_DESC", list = "anchorTo", fallback = "Frame", disabled = "attached" },
            { widget = "dropdown", path = { "Units", "$unitKey", "CombatIndicator", "point" }, label = "OPTION_ANCHOR_FROM", description = "OPTION_COMBAT_INDICATOR_ANCHOR_FROM_DESC", list = "anchorPoints", fallback = "TOP", disabled = "attached" },
            { widget = "dropdown", path = { "Units", "$unitKey", "CombatIndicator", "relativePoint" }, label = "OPTION_ANCHOR_TO", description = "OPTION_COMBAT_INDICATOR_ANCHOR_TO_DESC", list = "anchorPoints", fallback = "TOP", disabled = "attached" },
            { widget = "slider", path = { "Units", "$unitKey", "CombatIndicator", "offsetX" }, label = "OPTION_X_OFFSET", description = "OPTION_COMBAT_INDICATOR_OFFSET_X_DESC", min = -500, max = 500, step = 1, fallback = 0, format = "%d", disabled = "attached" },
            { widget = "slider", path = { "Units", "$unitKey", "CombatIndicator", "offsetY" }, label = "OPTION_Y_OFFSET", description = "OPTION_COMBAT_INDICATOR_OFFSET_Y_DESC", min = -500, max = 500, step = 1, fallback = 0, format = "%d", disabled = "attached" },
        },
    },
}

ns.GUI.Layouts.UnitCombatIndicator.Lists = {
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
