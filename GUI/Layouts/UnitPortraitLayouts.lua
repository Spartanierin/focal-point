local addonName, ns = ...

ns.GUI = ns.GUI or {}
ns.GUI.Layouts = ns.GUI.Layouts or {}

ns.GUI.Layouts.UnitPortrait = ns.GUI.Layouts.UnitPortrait or {}

ns.GUI.Layouts.UnitPortrait.PortraitTab = {
    {
        section = "SECTION_GENERAL",
        mode = "section",
        layout = "list",
        items = {
            { widget = "checkbox", path = { "Units", "$unitKey", "Portrait", "enabled" }, label = "OPTION_PORTRAIT_ENABLED", description = "OPTION_PORTRAIT_ENABLED_DESC", fallback = true, refreshGUI = true, disabled = "unit" },
            { widget = "dropdown", path = { "Units", "$unitKey", "Portrait", "placement" }, label = "OPTION_PORTRAIT_PLACEMENT", description = "OPTION_PORTRAIT_PLACEMENT_DESC", list = "placement", fallback = "INSIDE", refreshGUI = true, disabled = "portrait", placement = "left" },
            { widget = "dropdown", path = { "Units", "$unitKey", "Portrait", "mode" }, label = "OPTION_PORTRAIT_MODE", description = "OPTION_PORTRAIT_MODE_DESC", list = "mode", fallback = "2D", refreshGUI = true, disabled = "portrait", placement = "right" },
            { widget = "slider", path = { "Units", "$unitKey", "Portrait", "size" }, label = "OPTION_PORTRAIT_SIZE", description = "OPTION_PORTRAIT_SIZE_DESC", min = 16, max = 256, step = 1, fallback = 40, format = "%d", disabled = "portrait", placement = "left" },
            { widget = "slider", path = { "Units", "$unitKey", "Portrait", "scale" }, label = "OPTION_PORTRAIT_SCALE", description = "OPTION_PORTRAIT_SCALE_DESC", min = 0.25, max = 3.0, step = 0.01, fallback = 1.0, format = "%.2f", disabled = "portrait", placement = "right" },
        },
    },
    {
        section = "SECTION_INSIDE",
        mode = "section",
        layout = "list",
        items = {
            { widget = "dropdown", path = { "Units", "$unitKey", "Portrait", "insideAnchorTo" }, label = "OPTION_ANCHOR_TO_TARGET", description = "OPTION_INSIDE_ANCHOR_TO_DESC", list = "anchorTo", fallback = "Frame", disabled = "inside", placement = "left" },
            { widget = "dropdown", path = { "Units", "$unitKey", "Portrait", "insideSide" }, label = "OPTION_INSIDE_SIDE", description = "OPTION_PORTRAIT_INSIDE_SIDE_DESC", list = "insideSide", fallback = "LEFT", disabled = "inside", placement = "right" },
            { widget = "slider", path = { "Units", "$unitKey", "Portrait", "padding" }, label = "OPTION_PADDING", description = "OPTION_PORTRAIT_PADDING_DESC", min = 0, max = 20, step = 1, fallback = 4, format = "%d", disabled = "inside", placement = "left" },
        },
    },
    {
        section = "SECTION_ATTACHED",
        mode = "section",
        layout = "list",
        items = {
            { widget = "dropdown", path = { "Units", "$unitKey", "Portrait", "anchorTo" }, label = "OPTION_ANCHOR_TO_TARGET", description = "OPTION_PORTRAIT_ANCHOR_TO_TARGET_DESC", list = "anchorTo", fallback = "Frame", disabled = "attached", placement = "left" },
            { widget = "dropdown", path = { "Units", "$unitKey", "Portrait", "point" }, label = "OPTION_ANCHOR_FROM", description = "OPTION_PORTRAIT_ANCHOR_FROM_DESC", list = "anchorPoints", fallback = "LEFT", disabled = "attached", placement = "right" },
            { widget = "dropdown", path = { "Units", "$unitKey", "Portrait", "relativePoint" }, label = "OPTION_ANCHOR_TO", description = "OPTION_PORTRAIT_ANCHOR_TO_DESC", list = "anchorPoints", fallback = "RIGHT", disabled = "attached", placement = "left" },
            { widget = "slider", path = { "Units", "$unitKey", "Portrait", "offsetX" }, label = "OPTION_X_OFFSET", description = "OPTION_PORTRAIT_OFFSET_X_DESC", min = -500, max = 500, step = 1, fallback = -4, format = "%d", disabled = "attached", placement = "left" },
            { widget = "slider", path = { "Units", "$unitKey", "Portrait", "offsetY" }, label = "OPTION_Y_OFFSET", description = "OPTION_PORTRAIT_OFFSET_Y_DESC", min = -500, max = 500, step = 1, fallback = 0, format = "%d", disabled = "attached", placement = "right" },
        },
    },
}

ns.GUI.Layouts.UnitPortrait.Lists = {
    placement = {
        INSIDE = "VALUE_PORTRAIT_PLACEMENT_INSIDE",
        ATTACHED = "VALUE_PORTRAIT_PLACEMENT_ATTACHED",
    },
    mode = {
        ["2D"] = "VALUE_PORTRAIT_MODE_2D",
        ["3D"] = "VALUE_PORTRAIT_MODE_3D",
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
