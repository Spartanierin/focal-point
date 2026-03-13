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

ns.GUI.Layouts.UnitBars.CastBarTab = {
    {
        section = "SECTION_GENERAL",
        mode = "section",
        layout = "list",
        items = {
            { widget = "dropdown", path = { "Units", "$unitKey", "castBarTexture" }, label = "OPTION_BAR_TEXTURE", list = "textures", fallback = "Interface\\TargetingFrame\\UI-StatusBar", disabled = "unit", refreshGUI = true },
            { widget = "checkbox", path = { "Units", "$unitKey", "showCastBar" }, label = "OPTION_SHOW_CAST_BAR", description = "OPTION_SHOW_CAST_BAR_DESC", fallback = true, resetText = false, disabled = "unit", refreshGUI = true },
            { widget = "checkbox", path = { "Units", "$unitKey", "showCastBarIcon" }, label = "OPTION_SHOW_CAST_BAR_ICON", description = "OPTION_SHOW_CAST_BAR_ICON_DESC", fallback = true, resetText = false, disabled = "cast", refreshGUI = true },
            { widget = "slider", path = { "Units", "$unitKey", "castBarHeight" }, label = "OPTION_CAST_BAR_HEIGHT", description = "OPTION_CAST_BAR_HEIGHT_DESC", min = 4, max = 30, step = 1, fallback = 10, format = "%d", disabled = "cast" },
        },
    },
    {
        section = "SECTION_SIZE_POSITION",
        mode = "section",
        layout = "list",
        items = {
            { widget = "dropdown", path = { "Units", "$unitKey", "castBarPoint" }, label = "OPTION_ANCHOR_FROM", list = "anchorPoints", fallback = "BOTTOMLEFT", disabled = "cast", refreshGUI = true },
            { widget = "dropdown", path = { "Units", "$unitKey", "castBarRelativePoint" }, label = "OPTION_ANCHOR_TO", list = "anchorPoints", fallback = "TOPLEFT", disabled = "cast", refreshGUI = true },
            { widget = "slider", path = { "Units", "$unitKey", "castBarOffsetX" }, label = "OPTION_X_OFFSET", min = -500, max = 500, step = 1, fallback = 0, format = "%d", disabled = "cast" },
            { widget = "slider", path = { "Units", "$unitKey", "castBarOffsetY" }, label = "OPTION_Y_OFFSET", min = -500, max = 500, step = 1, fallback = 4, format = "%d", disabled = "cast" },
        },
    },
}

ns.GUI.Layouts.UnitBars.Lists = {
    textures = {
        ["Interface\\TargetingFrame\\UI-StatusBar"] = "VALUE_TEXTURE_BLIZZARD",
        ["Interface\\AddOns\\Portrait\\Media\\Textures\\BetterBlizzard.blp"] = "VALUE_TEXTURE_BETTER_BLIZZARD",
        ["Interface\\AddOns\\Portrait\\Media\\Textures\\Gradient.png"] = "VALUE_TEXTURE_GRADIENT",
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
