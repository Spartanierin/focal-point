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
            { widget = "colorpicker", path = { "Units", "$unitKey", "backgroundColor" }, label = "OPTION_BACKGROUND_COLOR", description = "OPTION_BACKGROUND_COLOR_DESC", hasAlpha = true, disabled = "unit" },
            { widget = "colorpicker", path = { "Units", "$unitKey", "borderColor" }, label = "OPTION_BORDER_COLOR", description = "OPTION_BORDER_COLOR_DESC", hasAlpha = true, disabled = "unit" },
        },
    },
    {
        section = "$healthBar",
        mode = "section",
        layout = "list",
        items = {
            { widget = "checkbox", path = { "Units", "$unitKey", "useClassColorHealth" }, label = "OPTION_USE_CLASS_COLORS", description = "OPTION_USE_CLASS_COLORS_HEALTH_DESC", fallback = false, resetText = false, disabled = "unit", refreshGUI = true, onChanged = "refresh_health_color" },
            { widget = "colorpicker", path = { "Units", "$unitKey", "healthColor" }, label = "OPTION_HEALTH_COLOR", description = "OPTION_HEALTH_COLOR_DESC", hasAlpha = true, disabled = "healthColor" },
            { widget = "checkbox", path = { "Units", "$unitKey", "healthBackground" }, label = "OPTION_SHOW_BACKGROUND", description = "OPTION_HEALTH_BACKGROUND_DESC", fallback = true, resetText = false, disabled = "unit", refreshGUI = true },
            { widget = "colorpicker", path = { "Units", "$unitKey", "healthBackgroundColor" }, label = "OPTION_BACKGROUND_COLOR", description = "OPTION_HEALTH_BACKGROUND_COLOR_DESC", hasAlpha = true, disabled = "healthBackground" },
        },
    },
    {
        section = "$powerBar",
        mode = "section",
        layout = "list",
        items = {
            { widget = "checkbox", path = { "Units", "$unitKey", "useClassColorPower" }, label = "OPTION_USE_CLASS_COLORS", description = "OPTION_USE_CLASS_COLORS_POWER_DESC", fallback = false, resetText = false, disabled = "power", refreshGUI = true, onChanged = "refresh_power_color" },
            { widget = "colorpicker", path = { "Units", "$unitKey", "powerColor" }, label = "OPTION_POWER_COLOR", description = "OPTION_POWER_COLOR_DESC", hasAlpha = true, disabled = "powerColor" },
            { widget = "checkbox", path = { "Units", "$unitKey", "powerBackground" }, label = "OPTION_SHOW_BACKGROUND", description = "OPTION_POWER_BACKGROUND_DESC", fallback = true, resetText = false, disabled = "power", refreshGUI = true },
            { widget = "colorpicker", path = { "Units", "$unitKey", "powerBackgroundColor" }, label = "OPTION_BACKGROUND_COLOR", description = "OPTION_POWER_BACKGROUND_COLOR_DESC", hasAlpha = true, disabled = "powerBackground" },
        },
    },
}
