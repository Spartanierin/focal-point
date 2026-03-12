local addonName, ns = ...

ns.GUI = ns.GUI or {}
ns.GUI.Layouts = ns.GUI.Layouts or {}

ns.GUI.Layouts.UnitBars = ns.GUI.Layouts.UnitBars or {}

ns.GUI.Layouts.UnitBars.HealthBarTab = {
    {
        section = "SECTION_GENERAL",
        mode = "section",
        layout = "list",
        items = {
            { widget = "dropdown", path = { "Units", "$unitKey", "healthBarTexture" }, label = "OPTION_BAR_TEXTURE", list = "textures", fallback = "Interface\\TargetingFrame\\UI-StatusBar", disabled = "unit", refreshGUI = true },
        },
    },
}

ns.GUI.Layouts.UnitBars.PowerBarTab = {
    {
        section = "SECTION_GENERAL",
        mode = "section",
        layout = "list",
        items = {
            { widget = "dropdown", path = { "Units", "$unitKey", "powerBarTexture" }, label = "OPTION_BAR_TEXTURE", list = "textures", fallback = "Interface\\TargetingFrame\\UI-StatusBar", disabled = "unit", refreshGUI = true },
            { widget = "checkbox", path = { "Units", "$unitKey", "showPowerBar" }, label = "OPTION_SHOW_POWER_BAR", description = "OPTION_SHOW_POWER_BAR_DESC", fallback = true, resetText = false, disabled = "unit", refreshGUI = true },
            { widget = "slider", path = { "Units", "$unitKey", "powerBarHeight" }, label = "OPTION_POWER_BAR_HEIGHT", description = "OPTION_POWER_BAR_HEIGHT_DESC", min = 4, max = 30, step = 1, fallback = 8, format = "%d", disabled = "power" },
        },
    },
}

ns.GUI.Layouts.UnitBars.Lists = {
    textures = {
        ["Interface\\TargetingFrame\\UI-StatusBar"] = "VALUE_TEXTURE_BLIZZARD",
        ["Interface\\AddOns\\Portrait\\Media\\Textures\\BetterBlizzard.blp"] = "VALUE_TEXTURE_BETTER_BLIZZARD",
        ["Interface\\AddOns\\Portrait\\Media\\Textures\\Gradient.png"] = "VALUE_TEXTURE_GRADIENT",
    },
}
