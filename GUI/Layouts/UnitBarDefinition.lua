local addonName, ns = ...

ns.GUI = ns.GUI or {}
ns.GUI.Layouts = ns.GUI.Layouts or {}

ns.GUI.Layouts.UnitBars = ns.GUI.Layouts.UnitBars or {}

ns.GUI.Layouts.UnitBars.Lists = {
    textures = {
        ["Interface\\TargetingFrame\\UI-StatusBar"] = "VALUE_TEXTURE_BLIZZARD",
        ["Interface\\RaidFrame\\Raid-Bar-Hp-Fill"] = "VALUE_TEXTURE_RAID_HP_FILL",
        ["Interface\\Buttons\\WHITE8X8"] = "VALUE_TEXTURE_FLAT",
        ["Interface\\Buttons\\GreyscaleRamp64"] = "VALUE_TEXTURE_GREYSCALE_RAMP",
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
