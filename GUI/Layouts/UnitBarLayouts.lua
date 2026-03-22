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
            { widget = "dropdown", path = { "Units", "$unitKey", "healthBarTexture" }, label = "OPTION_BAR_TEXTURE", description = "OPTION_BAR_TEXTURE_DESC", list = "textures", fallback = "Interface\\TargetingFrame\\UI-StatusBar", disabled = "unit", refreshGUI = true, placement = "left" },
            { widget = "checkbox", path = { "Units", "$unitKey", "healthBarReverseFill" }, label = "OPTION_REVERSE_FILL", description = "OPTION_REVERSE_FILL_DESC", fallback = false, disabled = "unit", refreshGUI = true, placement = "right" },
        },
    },
}

ns.GUI.Layouts.UnitBars.PowerBarTab = {
    {
        section = "SECTION_GENERAL",
        mode = "section",
        layout = "list",
        items = {
            { widget = "checkbox", path = { "Units", "$unitKey", "showPowerBar" }, label = "OPTION_SHOW_POWER_BAR", description = "OPTION_SHOW_POWER_BAR_DESC", fallback = true, resetText = false, disabled = "unit", refreshGUI = true, placement = "left" },
            { widget = "dropdown", path = { "Units", "$unitKey", "powerBarTexture" }, label = "OPTION_BAR_TEXTURE", description = "OPTION_BAR_TEXTURE_DESC", list = "textures", fallback = "Interface\\TargetingFrame\\UI-StatusBar", disabled = "unit", refreshGUI = true, placement = "right" },
            { widget = "checkbox", path = { "Units", "$unitKey", "powerBarReverseFill" }, label = "OPTION_REVERSE_FILL", description = "OPTION_REVERSE_FILL_DESC", fallback = false, disabled = "unit", refreshGUI = true, placement = "left" },
            { widget = "slider", path = { "Units", "$unitKey", "powerBarHeight" }, label = "OPTION_POWER_BAR_HEIGHT", description = "OPTION_POWER_BAR_HEIGHT_DESC", min = 4, max = 30, step = 1, fallback = 8, format = "%d", disabled = "power", placement = "right" },
        },
    },
}

ns.GUI.Layouts.UnitBars.AlternativePowerBarTab = {
    {
        section = "SECTION_ALTERNATIVE_POWER",
        mode = "section",
        layout = "list",
        items = {
            { widget = "checkbox", path = { "Units", "$unitKey", "showAlternativePowerBar" }, label = "OPTION_SHOW_ALTERNATIVE_POWER_BAR", description = "OPTION_SHOW_ALTERNATIVE_POWER_BAR_DESC", fallback = false, resetText = false, disabled = "unit", refreshGUI = true, placement = "left" },
            { widget = "slider", path = { "Units", "$unitKey", "alternativePowerBarHeight" }, label = "OPTION_ALTERNATIVE_POWER_BAR_HEIGHT", description = "OPTION_ALTERNATIVE_POWER_BAR_HEIGHT_DESC", min = 4, max = 30, step = 1, fallback = 5, format = "%d", disabled = "alternativePower", placement = "right" },
        },
    },
}

ns.GUI.Layouts.UnitBars.CastBarTab = {
    {
        section = "SECTION_GENERAL",
        mode = "section",
        layout = "list",
        items = {
            { widget = "checkbox", path = { "Units", "$unitKey", "showCastBar" }, label = "OPTION_SHOW_CAST_BAR", description = "OPTION_SHOW_CAST_BAR_DESC", fallback = true, resetText = false, disabled = "unit", refreshGUI = true, placement = "left" },
            { widget = "dropdown", path = { "Units", "$unitKey", "castBarTexture" }, label = "OPTION_BAR_TEXTURE", description = "OPTION_BAR_TEXTURE_DESC", list = "textures", fallback = "Interface\\TargetingFrame\\UI-StatusBar", disabled = "unit", refreshGUI = true, placement = "right" },
            { widget = "checkbox", path = { "Units", "$unitKey", "showCastBarIcon" }, label = "OPTION_SHOW_CAST_BAR_ICON", description = "OPTION_SHOW_CAST_BAR_ICON_DESC", fallback = true, resetText = false, disabled = "cast", refreshGUI = true, placement = "left" },
            { widget = "slider", path = { "Units", "$unitKey", "castBarHeight" }, label = "OPTION_CAST_BAR_HEIGHT", description = "OPTION_CAST_BAR_HEIGHT_DESC", min = 4, max = 30, step = 1, fallback = 10, format = "%d", disabled = "cast", placement = "right" },
            { widget = "colorpicker", path = { "Units", "$unitKey", "castBarColor" }, label = "OPTION_CAST_BAR_COLOR", description = "OPTION_CAST_BAR_COLOR_DESC", hasAlpha = true, disabled = "cast", placement = "left" },
            { widget = "colorpicker", path = { "Units", "$unitKey", "castBarInterruptibleColor" }, label = "OPTION_CAST_BAR_INTERRUPTIBLE_COLOR", description = "OPTION_CAST_BAR_INTERRUPTIBLE_COLOR_DESC", hasAlpha = true, disabled = "cast", placement = "right" },
        },
    },
    {
        section = "SECTION_SIZE_POSITION",
        mode = "section",
        layout = "list",
        items = {
            { widget = "dropdown", path = { "Units", "$unitKey", "castBarPoint" }, label = "OPTION_ANCHOR_FROM", description = "OPTION_ANCHOR_FROM_DESC", list = "anchorPoints", fallback = "BOTTOMLEFT", disabled = "cast", refreshGUI = true, placement = "left" },
            { widget = "dropdown", path = { "Units", "$unitKey", "castBarRelativePoint" }, label = "OPTION_ANCHOR_TO", description = "OPTION_ANCHOR_TO_DESC", list = "anchorPoints", fallback = "TOPLEFT", disabled = "cast", refreshGUI = true, placement = "right" },
            { widget = "slider", path = { "Units", "$unitKey", "castBarOffsetX" }, label = "OPTION_X_OFFSET", description = "OPTION_X_OFFSET_DESC", min = -500, max = 500, step = 1, fallback = 0, format = "%d", disabled = "cast", placement = "left" },
            { widget = "slider", path = { "Units", "$unitKey", "castBarOffsetY" }, label = "OPTION_Y_OFFSET", description = "OPTION_Y_OFFSET_DESC", min = -500, max = 500, step = 1, fallback = 4, format = "%d", disabled = "cast", placement = "right" },
        },
    },
}

ns.GUI.Layouts.UnitBars.Lists = {
    textures = {
        ["Interface\\TargetingFrame\\UI-StatusBar"] = "VALUE_TEXTURE_BLIZZARD",
        ["Interface\\PaperDollInfoFrame\\UI-Character-Skills-Bar"] = "VALUE_TEXTURE_BLIZZARD_CHARACTER_SKILLS_BAR",
        ["Interface\\RaidFrame\\Raid-Bar-Hp-Fill"] = "VALUE_TEXTURE_RAID_HP_FILL",
        ["Interface\\Buttons\\WHITE8X8"] = "VALUE_TEXTURE_FLAT",
        ["Interface\\Buttons\\GreyscaleRamp64"] = "VALUE_TEXTURE_GREYSCALE_RAMP",
        ["Interface\\Cooldown\\star4"] = "VALUE_TEXTURE_STAR4",
        ["Interface\\DialogFrame\\UI-DialogBox-Background"] = "VALUE_TEXTURE_DIALOG_BG",
        ["Interface\\BankFrame\\Bank-Background"] = "VALUE_TEXTURE_BANK_BG",
        ["Interface\\FrameGeneral\\UI-Background-Rock"] = "VALUE_TEXTURE_ROCK",
        ["Interface\\AchievementFrame\\UI-Achievement-Parchment-Horizontal"] = "VALUE_TEXTURE_ACHIEVEMENT_PARCHMENT",
        ["Interface\\AddOns\\FocalPoint\\Media\\Textures\\BetterBlizzard.blp"] = "VALUE_TEXTURE_BETTER_BLIZZARD",
        ["Interface\\AddOns\\FocalPoint\\Media\\Textures\\Gradient.png"] = "VALUE_TEXTURE_GRADIENT",
        ["Interface\\AddOns\\FocalPoint\\Media\\Textures\\Healbot.tga"] = "VALUE_TEXTURE_HEALBOT",
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
