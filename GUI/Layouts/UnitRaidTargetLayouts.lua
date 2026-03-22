local addonName, ns = ...

ns.GUI = ns.GUI or {}
ns.GUI.Layouts = ns.GUI.Layouts or {}

ns.GUI.Layouts.UnitRaidTarget = ns.GUI.Layouts.UnitRaidTarget or {}

ns.GUI.Layouts.UnitRaidTarget.RaidTargetTab = {
    {
        section = "SECTION_GENERAL",
        mode = "section",
        layout = "list",
        items = {
            { widget = "checkbox", path = { "Units", "$unitKey", "RaidTargetIcon", "enabled" }, label = "OPTION_RTM_ENABLED", description = "OPTION_RTM_ENABLED_DESC", fallback = true, refreshGUI = true, disabled = "unit" },
            { widget = "dropdown", path = { "Units", "$unitKey", "RaidTargetIcon", "placement" }, label = "OPTION_RTM_PLACEMENT", description = "OPTION_RTM_PLACEMENT_DESC", list = "placement", fallback = "ATTACHED", refreshGUI = true, disabled = "rtm", placement = "left" },
            { widget = "slider", path = { "Units", "$unitKey", "RaidTargetIcon", "size" }, label = "OPTION_RTM_SIZE", description = "OPTION_RTM_SIZE_DESC", min = 8, max = 128, step = 1, fallback = 18, format = "%d", disabled = "rtm", placement = "right" },
            { widget = "slider", path = { "Units", "$unitKey", "RaidTargetIcon", "scale" }, label = "OPTION_RTM_SCALE", description = "OPTION_RTM_SCALE_DESC", min = 0.25, max = 3.0, step = 0.01, fallback = 1.0, format = "%.2f", disabled = "rtm", placement = "left" },
        },
    },
    {
        section = "SECTION_INSIDE",
        mode = "section",
        layout = "list",
        items = {
            { widget = "dropdown", path = { "Units", "$unitKey", "RaidTargetIcon", "insideAnchorTo" }, label = "OPTION_ANCHOR_TO_TARGET", description = "OPTION_INSIDE_ANCHOR_TO_DESC", list = "anchorTo", fallback = "Frame", disabled = "inside", placement = "left" },
            { widget = "dropdown", path = { "Units", "$unitKey", "RaidTargetIcon", "insideSide" }, label = "OPTION_INSIDE_SIDE", description = "OPTION_RTM_INSIDE_SIDE_DESC", list = "insideSide", fallback = "RIGHT", disabled = "inside", placement = "right" },
            { widget = "slider", path = { "Units", "$unitKey", "RaidTargetIcon", "padding" }, label = "OPTION_PADDING", description = "OPTION_RTM_PADDING_DESC", min = 0, max = 64, step = 1, fallback = 2, format = "%d", disabled = "inside", placement = "left" },
        },
    },
    {
        section = "SECTION_ATTACHED",
        mode = "section",
        layout = "list",
        items = {
            { widget = "dropdown", path = { "Units", "$unitKey", "RaidTargetIcon", "anchorTo" }, label = "OPTION_ANCHOR_TO_TARGET", description = "OPTION_RTM_ANCHOR_TO_TARGET_DESC", list = "anchorTo", fallback = "Frame", disabled = "attached", placement = "left" },
            { widget = "dropdown", path = { "Units", "$unitKey", "RaidTargetIcon", "point" }, label = "OPTION_ANCHOR_FROM", description = "OPTION_RTM_ANCHOR_FROM_DESC", list = "anchorPoints", fallback = "TOP", disabled = "attached", placement = "right" },
            { widget = "dropdown", path = { "Units", "$unitKey", "RaidTargetIcon", "relativePoint" }, label = "OPTION_ANCHOR_TO", description = "OPTION_RTM_ANCHOR_TO_DESC", list = "anchorPoints", fallback = "TOP", disabled = "attached", placement = "left" },
            { widget = "slider", path = { "Units", "$unitKey", "RaidTargetIcon", "offsetX" }, label = "OPTION_X_OFFSET", description = "OPTION_RTM_OFFSET_X_DESC", min = -500, max = 500, step = 1, fallback = 0, format = "%d", disabled = "attached", placement = "left" },
            { widget = "slider", path = { "Units", "$unitKey", "RaidTargetIcon", "offsetY" }, label = "OPTION_Y_OFFSET", description = "OPTION_RTM_OFFSET_Y_DESC", min = -500, max = 500, step = 1, fallback = 8, format = "%d", disabled = "attached", placement = "right" },
        },
    },
}

ns.GUI.Layouts.UnitRaidTarget.Lists = {
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
