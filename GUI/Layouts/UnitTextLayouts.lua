local addonName, ns = ...

ns.GUI = ns.GUI or {}
ns.GUI.Layouts = ns.GUI.Layouts or {}

ns.GUI.Layouts.UnitTexts = ns.GUI.Layouts.UnitTexts or {}

ns.GUI.Layouts.UnitTexts.TextTab = {
    {
        section = "SECTION_GENERAL",
        mode = "section",
        layout = "list",
        items = {
            { widget = "checkbox", path = { "Units", "$unitKey", "Texts", "$textKey", "enabled" }, label = "OPTION_ENABLED", fallback = true, refreshGUI = true, disabled = "unit" },
            { widget = "editbox", path = { "Units", "$unitKey", "Texts", "$textKey", "tag" }, label = "OPTION_TAG", fallback = "" },
        },
    },
    {
        section = "SECTION_FONT",
        mode = "section",
        layout = "list",
        items = {
            { widget = "dropdown", path = { "Units", "$unitKey", "Texts", "$textKey", "font" }, label = "OPTION_FONT", list = "fonts", fallback = STANDARD_TEXT_FONT, disabled = "text" },
            { widget = "slider", path = { "Units", "$unitKey", "Texts", "$textKey", "fontSize" }, label = "OPTION_FONT_SIZE", min = 6, max = 32, step = 1, fallback = 12, format = "%d", disabled = "text" },
            { widget = "dropdown", path = { "Units", "$unitKey", "Texts", "$textKey", "justifyH" }, label = "OPTION_JUSTIFY_H", list = "justifyH", fallback = "CENTER", disabled = "text" },
            { widget = "fontstyle", path = { "Units", "$unitKey", "Texts", "$textKey" }, label = "OPTION_FONT_STYLE", list = "fontStyles", fallback = "NONE", disabled = "text" },
        },
    },
    {
        section = "SECTION_POSITION",
        mode = "section",
        layout = "list",
        items = {
            { widget = "dropdown", path = { "Units", "$unitKey", "Texts", "$textKey", "anchorTo" }, label = "OPTION_ANCHOR_TO_TARGET", list = "anchorTo", fallback = "HealthBar", disabled = "text" },
            { widget = "dropdown", path = { "Units", "$unitKey", "Texts", "$textKey", "point" }, label = "OPTION_ANCHOR_FROM", list = "anchorPoints", fallback = "CENTER", disabled = "text" },
            { widget = "dropdown", path = { "Units", "$unitKey", "Texts", "$textKey", "relativePoint" }, label = "OPTION_ANCHOR_TO", list = "anchorPoints", fallback = "CENTER", disabled = "text" },
            { widget = "slider", path = { "Units", "$unitKey", "Texts", "$textKey", "offsetX" }, label = "OPTION_X_OFFSET", min = -100, max = 100, step = 1, fallback = 0, format = "%d", disabled = "text" },
            { widget = "slider", path = { "Units", "$unitKey", "Texts", "$textKey", "offsetY" }, label = "OPTION_Y_OFFSET", min = -100, max = 100, step = 1, fallback = 0, format = "%d", disabled = "text" },
        },
    },
    {
        section = "SECTION_EFFECTS",
        mode = "section",
        layout = "list",
        items = {
            { widget = "checkbox", path = { "Units", "$unitKey", "Texts", "$textKey", "shadowEnabled" }, label = "OPTION_FONT_SHADOW", fallback = true, disabled = "text" },
            { widget = "slider", path = { "Units", "$unitKey", "Texts", "$textKey", "shadowOffsetX" }, label = "OPTION_SHADOW_OFFSET_X", min = -10, max = 10, step = 1, fallback = 1, format = "%d", disabled = "shadow" },
            { widget = "slider", path = { "Units", "$unitKey", "Texts", "$textKey", "shadowOffsetY" }, label = "OPTION_SHADOW_OFFSET_Y", min = -10, max = 10, step = 1, fallback = -1, format = "%d", disabled = "shadow" },
            { widget = "colorpicker", path = { "Units", "$unitKey", "Texts", "$textKey", "color" }, label = "OPTION_COLOR", hasAlpha = true, fallback = { 1, 1, 1, 1 }, disabled = "text" },
            { widget = "colorpicker", path = { "Units", "$unitKey", "Texts", "$textKey", "shadowColor" }, label = "OPTION_SHADOW_COLOR", hasAlpha = true, fallback = { 0, 0, 0, 1 }, disabled = "shadow" },
        },
    },
}

ns.GUI.Layouts.UnitTexts.Lists = {
    fonts = {
        [STANDARD_TEXT_FONT] = "VALUE_FONT_STANDARD",
        ["Fonts\\ARIALN.TTF"] = "VALUE_FONT_ARIAL_NARROW",
        ["Fonts\\MORPHEUS.ttf"] = "VALUE_FONT_MORPHEUS",
        ["Fonts\\SKURRI.ttf"] = "VALUE_FONT_SKURRI",
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
    justifyH = {
        LEFT = "VALUE_JUSTIFY_LEFT",
        CENTER = "VALUE_JUSTIFY_CENTER",
        RIGHT = "VALUE_JUSTIFY_RIGHT",
    },
    fontStyles = {
        NONE = "VALUE_FONT_STYLE_NONE",
        OUTLINE = "VALUE_FONT_STYLE_OUTLINE",
        THICKOUTLINE = "VALUE_FONT_STYLE_THICK_OUTLINE",
        MONOCHROME = "VALUE_FONT_STYLE_MONOCHROME",
        OUTLINE_MONOCHROME = "VALUE_FONT_STYLE_OUTLINE_MONOCHROME",
        THICKOUTLINE_MONOCHROME = "VALUE_FONT_STYLE_THICK_OUTLINE_MONOCHROME",
    },
}
