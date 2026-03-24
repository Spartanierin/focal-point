local _, ns = ...

ns.GUI = ns.GUI or {}
ns.GUI.Layouts = ns.GUI.Layouts or {}

ns.GUI.Layouts.UnitClassificationIndicator = ns.GUI.Layouts.UnitClassificationIndicator or {}

ns.GUI.Layouts.UnitClassificationIndicator.ClassificationIndicatorTab = {
    {
        section = "SECTION_GENERAL",
        mode = "section",
        layout = "list",
        items = {
            { widget = "checkbox", path = { "Units", "$unitKey", "ClassificationIndicator", "enabled" }, label = "OPTION_CLASSIFICATION_INDICATOR_ENABLED", description = "OPTION_CLASSIFICATION_INDICATOR_ENABLED_DESC", fallback = true, refreshGUI = true, disabled = "unit" },
            { widget = "dropdown", path = { "Units", "$unitKey", "ClassificationIndicator", "effect" }, label = "OPTION_CLASSIFICATION_INDICATOR_EFFECT", description = "OPTION_CLASSIFICATION_INDICATOR_EFFECT_DESC", list = "effect", fallback = "NAME_GLOW", disabled = "classification", placement = "left" },
        },
    },
}

ns.GUI.Layouts.UnitClassificationIndicator.Lists = {
    effect = {
        NONE = "VALUE_INDICATOR_EFFECT_NONE",
        NAME_GLOW = "VALUE_INDICATOR_EFFECT_NAME_GLOW",
    },
}
