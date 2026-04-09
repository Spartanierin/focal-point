local _, ns = ...

ns.GUI = ns.GUI or {}
ns.GUI.Layouts = ns.GUI.Layouts or {}

ns.GUI.Layouts.UnitClassificationIndicator = ns.GUI.Layouts.UnitClassificationIndicator or {}
ns.GUI.Layouts.UnitStatusIndicator = ns.GUI.Layouts.UnitStatusIndicator or {}

ns.GUI.Layouts.UnitClassificationIndicator.Lists = {
    effect = {
        NONE = "VALUE_INDICATOR_EFFECT_NONE",
        PORTRAIT_OVERLAY = "VALUE_INDICATOR_EFFECT_PORTRAIT_OVERLAY",
        CORNER_CREST = "VALUE_INDICATOR_EFFECT_CORNER_CREST",
        NAME_GLOW = "VALUE_INDICATOR_EFFECT_NAME_GLOW",
        NAME_LABEL = "VALUE_INDICATOR_EFFECT_NAME_LABEL",
    },
}

ns.GUI.Layouts.UnitStatusIndicator.Lists = {
    effect = {
        ICON = "VALUE_STATUS_INDICATOR_EFFECT_ICON",
        FRAME_OVERLAY = "VALUE_STATUS_INDICATOR_EFFECT_FRAME_OVERLAY",
    },
}
