local addonName, ns = ...

ns.GUI = ns.GUI or {}
ns.GUI.Layouts = ns.GUI.Layouts or {}

ns.GUI.Layouts.UnitTexts = ns.GUI.Layouts.UnitTexts or {}

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
    overflowMode = {
        NONE = "VALUE_OVERFLOW_NONE",
        CLIP = "VALUE_OVERFLOW_CLIP",
        ELLIPSIS = "VALUE_OVERFLOW_ELLIPSIS",
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
