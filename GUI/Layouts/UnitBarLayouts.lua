local addonName, ns = ...

ns.GUI = ns.GUI or {}
ns.GUI.Layouts = ns.GUI.Layouts or {}

ns.GUI.Layouts.UnitBars = ns.GUI.Layouts.UnitBars or {}

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
