local addonName, ns = ...

ns.GUI = ns.GUI or {}
ns.GUI.Layouts = ns.GUI.Layouts or {}

ns.GUI.Layouts.UnitColors = ns.GUI.Layouts.UnitColors or {}

ns.GUI.Layouts.UnitColors.ColorTab = {
    {
        section = "Frame",
        mode = "section",
        layout = "list",
        items = {
            { widget = "colorpicker", path = { "Units", "$unitKey", "backgroundColor" }, label = "OPTION_BACKGROUND_COLOR", description = "OPTION_BACKGROUND_COLOR_DESC", hasAlpha = true, disabled = "unit", placement = "left" },
            { widget = "colorpicker", path = { "Units", "$unitKey", "borderColor" }, label = "OPTION_BORDER_COLOR", description = "OPTION_BORDER_COLOR_DESC", hasAlpha = true, disabled = "unit", placement = "right" },
        },
    },
    {
        section = "$healthBar",
        mode = "section",
        layout = "list",
        items = {
            { widget = "checkbox", path = { "Units", "$unitKey", "useClassColorHealth" }, label = "OPTION_USE_CLASS_COLORS", description = "OPTION_USE_CLASS_COLORS_HEALTH_DESC", fallback = false, resetText = false, disabled = "unit", refreshGUI = true, onChanged = "refresh_health_color", placement = "left" },
            { widget = "checkbox", path = { "Units", "$unitKey", "useReactionColorNpcHealth" }, label = "OPTION_USE_REACTION_COLORS_NPC_HEALTH", description = "OPTION_USE_REACTION_COLORS_NPC_HEALTH_DESC", fallback = false, resetText = false, disabled = "unit", refreshGUI = true, onChanged = "refresh_health_color", placement = "right" },
            { widget = "colorpicker", path = { "Units", "$unitKey", "healthColor" }, label = "OPTION_HEALTH_COLOR", description = "OPTION_HEALTH_COLOR_DESC", hasAlpha = true, disabled = "healthColor", placement = "left" },
            { widget = "slider", path = { "Units", "$unitKey", "healthColor", 4 }, label = "OPTION_ALPHA", description = "OPTION_HEALTH_ALPHA_DESC", min = 0.0, max = 1.0, step = 0.01, fallback = 1.0, format = "%.2f", disabled = "unit", placement = "right" },
            { widget = "checkbox", path = { "Units", "$unitKey", "healthBackground" }, label = "OPTION_SHOW_BACKGROUND", description = "OPTION_HEALTH_BACKGROUND_DESC", fallback = true, resetText = false, disabled = "unit", refreshGUI = true, placement = "left" },
            { widget = "colorpicker", path = { "Units", "$unitKey", "healthBackgroundColor" }, label = "OPTION_BACKGROUND_COLOR", description = "OPTION_HEALTH_BACKGROUND_COLOR_DESC", hasAlpha = true, disabled = "healthBackground", placement = "right" },
        },
    },
    {
        section = "$powerBar",
        mode = "section",
        layout = "list",
        items = {
            { widget = "checkbox", path = { "Units", "$unitKey", "useClassColorPower" }, label = "OPTION_USE_CLASS_COLORS", description = "OPTION_USE_CLASS_COLORS_POWER_DESC", fallback = false, resetText = false, disabled = "power", refreshGUI = true, onChanged = "refresh_power_color", placement = "left" },
            { widget = "colorpicker", path = { "Units", "$unitKey", "powerColor" }, label = "OPTION_POWER_COLOR", description = "OPTION_POWER_COLOR_DESC", hasAlpha = true, disabled = "powerColor", placement = "left" },
            { widget = "slider", path = { "Units", "$unitKey", "powerColor", 4 }, label = "OPTION_ALPHA", description = "OPTION_POWER_ALPHA_DESC", min = 0.0, max = 1.0, step = 0.01, fallback = 1.0, format = "%.2f", disabled = "power", placement = "right" },
            { widget = "checkbox", path = { "Units", "$unitKey", "powerBackground" }, label = "OPTION_SHOW_BACKGROUND", description = "OPTION_POWER_BACKGROUND_DESC", fallback = true, resetText = false, disabled = "power", refreshGUI = true, placement = "left" },
            { widget = "colorpicker", path = { "Units", "$unitKey", "powerBackgroundColor" }, label = "OPTION_BACKGROUND_COLOR", description = "OPTION_POWER_BACKGROUND_COLOR_DESC", hasAlpha = true, disabled = "powerBackground", placement = "right" },
        },
    },
    {
        section = "$castBar",
        mode = "section",
        layout = "list",
        items = {
            { widget = "colorpicker", path = { "Units", "$unitKey", "castBarColor" }, label = "OPTION_CAST_BAR_COLOR", description = "OPTION_CAST_BAR_COLOR_DESC", hasAlpha = true, disabled = "cast", placement = "left" },
            { widget = "colorpicker", path = { "Units", "$unitKey", "castBarInterruptibleColor" }, label = "OPTION_CAST_BAR_INTERRUPTIBLE_COLOR", description = "OPTION_CAST_BAR_INTERRUPTIBLE_COLOR_DESC", hasAlpha = true, disabled = "cast", placement = "right" },
        },
    },
}
