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
}
