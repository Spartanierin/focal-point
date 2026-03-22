local addonName, ns = ...

ns.GUI = ns.GUI or {}
ns.GUI.Layouts = ns.GUI.Layouts or {}

ns.GUI.Layouts.UnitFrame = ns.GUI.Layouts.UnitFrame or {}

ns.GUI.Layouts.UnitFrame.FrameTab = {
    {
        section = "SECTION_GENERAL",
        mode = "direct_checkboxes",
        items = {
            { widget = "checkbox", path = { "Units", "$unitKey", "enabled" },       label = "OPTION_ENABLED",         description = "OPTION_ENABLED_DESC",         fallback = true,  refreshGUI = true },
        },
    },
    {
        section = "SECTION_SIZE_POSITION",
        mode = "section",
        layout = "list",
        items = {
            { widget = "slider",   path = { "Units", "$unitKey", "width" },         label = "OPTION_WIDTH",        description = "OPTION_WIDTH_DESC",        min = 50,    max = 600,  step = 1,    fallback = 220, format = "%d", placement = "left" },
            { widget = "slider",   path = { "Units", "$unitKey", "height" },        label = "OPTION_HEIGHT",       description = "OPTION_HEIGHT_DESC",       min = 10,    max = 200,  step = 1,    fallback = 45,  format = "%d", placement = "right" },
            { widget = "slider",   path = { "Units", "$unitKey", "x" },             label = "OPTION_X_OFFSET",     description = "OPTION_X_OFFSET_DESC",     min = -1000, max = 1000, step = 1,    fallback = 0,   format = "%d", placement = "left" },
            { widget = "slider",   path = { "Units", "$unitKey", "y" },             label = "OPTION_Y_OFFSET",     description = "OPTION_Y_OFFSET_DESC",     min = -1000, max = 1000, step = 1,    fallback = 0,   format = "%d", placement = "right" },
            { widget = "dropdown", path = { "Units", "$unitKey", "point" },         label = "OPTION_ANCHOR_FROM",  description = "OPTION_ANCHOR_FROM_DESC",  list = "anchorPoints", fallback = "CENTER", placement = "left" },
            { widget = "dropdown", path = { "Units", "$unitKey", "relativePoint" }, label = "OPTION_ANCHOR_TO",    description = "OPTION_ANCHOR_TO_DESC",    list = "anchorPoints", fallback = "CENTER", placement = "right" },
        },
    },
    {
        section = "SECTION_OPACITY_SCALING",
        mode = "section",
        layout = "list",
        items = {
            { widget = "slider", path = { "Units", "$unitKey", "alpha" }, label = "OPTION_ALPHA", description = "OPTION_ALPHA_DESC", min = 0.0, max = 1.0, step = 0.01, fallback = 1.0, format = "%.2f", placement = "left" },
            { widget = "slider", path = { "Units", "$unitKey", "scale" }, label = "OPTION_SCALE", description = "OPTION_SCALE_DESC", min = 0.5, max = 2.0, step = 0.01, fallback = 1.0, format = "%.2f", placement = "right" },
        },
    },
    {
        section = "SECTION_LAYERING",
        mode = "direct_layering",
        items = {
            { widget = "dropdown", path = { "Units", "$unitKey", "frameStrata" }, label = "OPTION_FRAME_STRATA", description = "OPTION_FRAME_STRATA_DESC", list = "frameStrata", fallback = "MEDIUM" },
            { widget = "slider",   path = { "Units", "$unitKey", "frameLevel" },  label = "OPTION_FRAME_LEVEL",  description = "OPTION_FRAME_LEVEL_DESC",  min = 0, max = 50, step = 1, fallback = 1, format = "%d" },
        },
    },
}

ns.GUI.Layouts.UnitFrame.Lists = {
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
    frameStrata = {
        BACKGROUND = "VALUE_FRAME_STRATA_BACKGROUND",
        LOW = "VALUE_FRAME_STRATA_LOW",
        MEDIUM = "VALUE_FRAME_STRATA_MEDIUM",
        HIGH = "VALUE_FRAME_STRATA_HIGH",
        DIALOG = "VALUE_FRAME_STRATA_DIALOG",
        FULLSCREEN = "VALUE_FRAME_STRATA_FULLSCREEN",
        FULLSCREEN_DIALOG = "VALUE_FRAME_STRATA_FULLSCREEN_DIALOG",
        TOOLTIP = "VALUE_FRAME_STRATA_TOOLTIP",
    },
}
