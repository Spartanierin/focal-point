local _, FocalPoint = ...

function FocalPoint:GetDefaultDB()
    return {
        profile = {
            General = {
                TagUpdateInterval = 0.125,
                Separator = "||",
                ToTSeparator = "»",
                UIScale = 0.7551622418879056,
                ExpertMode = true,
                HideBlizzardFrames = true,
                GlobalClickThrough = false,
                MouseEnabled = true,
                ClampToScreen = true,
            },

            Minimap = {
                hide = false,
            },

            TextTemplates = {
                ["Sparta's Unit Frame - Name"] = "[name]",
                ["Sparta's Unit Frame - Health"] = "[hp:cur:abbr]/[hp:max:abbr] | [hp:perc]%",
                ["Sparta's Unit Frame - Player Power"] = "[power:cur]/[power:max]",
                ["Sparta's Unit Frame - Target Power"] = "[power:cur:abbr]/[power:max:abbr]",
                ["Sparta's Unit Frame - Alt Power"] = "[altpower:cur] / [altpower:max]",
                ["Sparta's Unit Frame - Player Level and Class"] = "[color:blizz_yellow][level][rc] [color:class][class][rc] [race]",
                ["Sparta's Unit Frame - Creature"] = "[creature]",
                ["Sparta's Unit Frame - Status"] = "[status][dead][dead:timer]",
                ["Sparta's Unit Frame - Cast Name"] = "[cast:name]",
                ["Sparta's Unit Frame - Cast Time"] = "[cast:time]",
            },

            Units = {
                player = {
                    enabled = true,
                    mouseEnabled = true,
                    clickThrough = false,
                    clampToScreen = true,
                    showInSolo = true,
                    showInParty = true,
                    showInRaid = true,
                    showInArena = true,
                    showInPvp = true,

                    width = 260,
                    height = 65,
                    alpha = 0.9,
                    scale = 1,
                    frameLevel = 0,
                    frameStrata = "MEDIUM",
                    point = "CENTER",
                    relativeTo = "UIParent",
                    relativePoint = "CENTER",
                    x = -270,
                    y = -290,

                    showPowerBar = true,
                    powerBarHeight = 20,
                    showAlternativePowerBar = true,
                    alternativePowerBarHeight = 20,
                    alternativePowerBarWidth = 100,
                    alternativePowerBarAnchorTo = "HealthBar",
                    alternativePowerBarPoint = "BOTTOMLEFT",
                    alternativePowerBarRelativePoint = "BOTTOMLEFT",
                    alternativePowerBarOffsetX = 5,
                    alternativePowerBarOffsetY = 5,
                    showCastBar = true,
                    showCastBarIcon = true,
                    castBarHeight = 20,
                    castBarPoint = "BOTTOMLEFT",
                    castBarRelativePoint = "BOTTOMLEFT",
                    castBarOffsetX = 0,
                    castBarOffsetY = -20,

                    statusBarTexture = "Interface\\TargetingFrame\\UI-StatusBar",
                    healthBarTexture = "Interface\\AddOns\\FocalPoint\\Media\\Textures\\Healbot.tga",
                    powerBarTexture = "Interface\\AddOns\\FocalPoint\\Media\\Textures\\Healbot.tga",
                    alternativePowerBarTexture = "Interface\\TargetingFrame\\UI-StatusBar",
                    castBarTexture = "Interface\\AddOns\\FocalPoint\\Media\\Textures\\Healbot.tga",
                    castBarColor = { 0.7686275243759155, 0.7411764860153198, 0.2156862914562225, 1.00 },

                    backgroundColor = { 0.0784313753247261, 0.0784313753247261, 0.0784313753247261, 0.3164066076278687 },
                    borderColor = { 0.00, 0.00, 0.00, 0.00 },

                    healthColor = { 0.1882353127002716, 0.8000000715255737, 0.7686275243759155, 0.65 },
                    healthBackground = true,
                    healthBackgroundColor = { 0.00, 0.00, 0.00, 0.65234375 },
                    useClassColorHealth = true,

                    powerColor = { 0.8000000715255737, 0.01176470704376698, 0.00, 0.65 },
                    powerBackground = true,
                    powerBackgroundColor = { 0.05490196496248245, 0.05882353335618973, 0.05882353335618973, 0.3945313394069672 },
                    useClassColorPower = true,
                    useReactionColorNpcHealth = false,

                    Portrait = {
                        enabled = false,
                        placement = "INSIDE",   -- INSIDE / ATTACHED
                        mode = "2D",            -- 2D / 3D
                        size = 60,
                        scale = 1,
                        padding = 4,            -- nur relevant für INSIDE
                        insideSide = "LEFT",    -- LEFT / RIGHT
                        anchorTo = "Frame",     -- für ATTACHED
                        point = "RIGHT",
                        relativePoint = "LEFT",
                        offsetX = -4,
                        offsetY = 0,
                    },

                    RaidTargetIcon = {
                        enabled = true,
                        placement = "ATTACHED", -- INSIDE / ATTACHED
                        size = 50,
                        scale = 0.92,
                        padding = 2,             -- only relevant for INSIDE
                        insideSide = "LEFT",
                        anchorTo = "Frame",
                        point = "BOTTOM",
                        relativePoint = "BOTTOM",
                        offsetX = 98,
                        offsetY = 18,
                    },

                    LeaderIcon = {
                        enabled = true,
                        placement = "ATTACHED",
                        size = 20,
                        scale = 1,
                        padding = 2,
                        insideSide = "LEFT",
                        anchorTo = "Frame",
                        point = "TOPLEFT",
                        relativePoint = "TOPLEFT",
                        offsetX = -116,
                        offsetY = 18,
                    },

                    RoleIcon = {
                        enabled = true,
                        placement = "ATTACHED",
                        size = 20,
                        scale = 1,
                        padding = 2,
                        insideSide = "RIGHT",
                        anchorTo = "Frame",
                        point = "TOPRIGHT",
                        relativePoint = "TOPRIGHT",
                        offsetX = 127,
                        offsetY = 18,
                    },

                    CombatIndicator = {
                        enabled = true,
                        placement = "ATTACHED",
                        size = 20,
                        scale = 1,
                        padding = 2,
                        insideSide = "RIGHT",
                        anchorTo = "Frame",
                        point = "TOPRIGHT",
                        relativePoint = "BOTTOMRIGHT",
                        offsetX = -15,
                        offsetY = -11,
                    },

                    RestingIndicator = {
                        enabled = true,
                        placement = "ATTACHED",
                        size = 25,
                        scale = 1,
                        padding = 2,
                        insideSide = "LEFT",
                        anchorTo = "Frame",
                        point = "BOTTOMRIGHT",
                        relativePoint = "BOTTOMRIGHT",
                        offsetX = 12,
                        offsetY = -12,
                    },

                    ReadyCheckIndicator = {
                        enabled = true,
                        placement = "ATTACHED",
                        size = 16,
                        scale = 1,
                        padding = 2,
                        insideSide = "RIGHT",
                        anchorTo = "Frame",
                        point = "TOPRIGHT",
                        relativePoint = "TOP",
                        offsetX = 0,
                        offsetY = 0,
                    },

                    Texts = {
                        Name = {
                            enabled = true,
                            tag = "[name] [status] [status:timer]",

                            anchorTo = "Frame",
                            point = "TOPRIGHT",
                            relativePoint = "TOPRIGHT",
                            offsetX = 0,
                            offsetY = 20,

                            font = STANDARD_TEXT_FONT,
                            fontSize = 16,
                            justifyH = "LEFT",

                            color = { 1.00, 1.00, 1.00, 1.00 },

                            shadowEnabled = true,
                            shadowOffsetX = 2,
                            shadowOffsetY = -2,
                            shadowColor = { 0, 0, 0, 1 },

                            outline = false,
                            thickOutline = false,
                            monochrome = false,
                        },

                        Health = {
                            enabled = true,
                            tag = "[hp:cur:abbr]/[hp:max:abbr] || [hp:perc]%",

                            anchorTo = "HealthBar",
                            point = "LEFT",
                            relativePoint = "LEFT",
                            offsetX = 2,
                            offsetY = 0,

                            font = STANDARD_TEXT_FONT,
                            fontSize = 15,
                            justifyH = "LEFT",

                            color = { 1.00, 1.00, 1.00, 1.00 },

                            shadowEnabled = true,
                            shadowOffsetX = 1,
                            shadowOffsetY = -1,
                            shadowColor = { 0, 0, 0, 1 },

                            outline = false,
                            thickOutline = false,
                            monochrome = false,
                        },

                        Power = {
                            enabled = true,
                            tag = "[power:cur]/[power:max]",

                            anchorTo = "PowerBar",
                            point = "LEFT",
                            relativePoint = "LEFT",
                            offsetX = 2,
                            offsetY = 0,

                            font = STANDARD_TEXT_FONT,
                            fontSize = 12,
                            justifyH = "LEFT",

                            color = { 1.00, 1.00, 1.00, 1.00 },

                            shadowEnabled = true,
                            shadowOffsetX = 1,
                            shadowOffsetY = -1,
                            shadowColor = { 0, 0, 0, 1 },

                            outline = false,
                            thickOutline = false,
                            monochrome = false,
                        },

                        AltPower = {
                            enabled = true,
                            tag = "[altpower:cur] / [altpower:max]",

                            anchorTo = "AlternativePowerBar",
                            point = "LEFT",
                            relativePoint = "LEFT",
                            offsetX = 2,
                            offsetY = 0,

                            font = STANDARD_TEXT_FONT,
                            fontSize = 13,
                            justifyH = "LEFT",

                            color = { 1.00, 1.00, 1.00, 1.00 },

                            shadowEnabled = true,
                            shadowOffsetX = 1,
                            shadowOffsetY = -1,
                            shadowColor = { 0, 0, 0, 1 },

                            outline = false,
                            thickOutline = false,
                            monochrome = false,
                        },

                        Level = {
                            enabled = false,
                            tag = "",

                            anchorTo = "PowerBar",
                            point = "RIGHT",
                            relativePoint = "CENTER",
                            offsetX = -5,
                            offsetY = 0,

                            font = STANDARD_TEXT_FONT,
                            fontSize = 13,
                            justifyH = "CENTER",

                            color = { 1.00, 0.82, 0.00, 1.00 },

                            shadowEnabled = true,
                            shadowOffsetX = 1,
                            shadowOffsetY = -1,
                            shadowColor = { 0, 0, 0, 1 },

                            outline = false,
                            thickOutline = false,
                            monochrome = false,
                        },


                        Class = {
                            enabled = true,
                            tag = "[color:blizz_yellow][level][rc] [color:class][class][rc] [race]",

                            anchorTo = "PowerBar",
                            point = "RIGHT",
                            relativePoint = "RIGHT",
                            offsetX = -5,
                            offsetY = 0,

                            font = STANDARD_TEXT_FONT,
                            fontSize = 12,
                            justifyH = "CENTER",

                            color = { 1.00, 1.00, 1.00, 1.00 },

                            shadowEnabled = true,
                            shadowOffsetX = 1,
                            shadowOffsetY = -1,
                            shadowColor = { 0, 0, 0, 1 },

                            outline = false,
                            thickOutline = false,
                            monochrome = false,
                        },

                        Race = {
                            enabled = false,
                            tag = "",

                            anchorTo = "PowerBar",
                            point = "RIGHT",
                            relativePoint = "RIGHT",
                            offsetX = -7,
                            offsetY = 0,

                            font = STANDARD_TEXT_FONT,
                            fontSize = 13,
                            justifyH = "CENTER",

                            color = { 1.00, 1.00, 1.00, 1.00 },

                            shadowEnabled = true,
                            shadowOffsetX = 1,
                            shadowOffsetY = -1,
                            shadowColor = { 0, 0, 0, 1 },

                            outline = false,
                            thickOutline = false,
                            monochrome = false,
                        },

                        Status = {
                            enabled = false,
                            tag = "",

                            anchorTo = "HealthBar",
                            point = "RIGHT",
                            relativePoint = "RIGHT",
                            offsetX = -41,
                            offsetY = 0,

                            font = STANDARD_TEXT_FONT,
                            fontSize = 15,
                            justifyH = "RIGHT",

                            color = { 1.00, 0.82, 0.20, 1.00 },

                            shadowEnabled = true,
                            shadowOffsetX = 1,
                            shadowOffsetY = 1,
                            shadowColor = { 0, 0, 0, 1 },

                            outline = false,
                            thickOutline = false,
                            monochrome = false,
                        },

                        CastName = {
                            enabled = true,
                            tag = "[cast:name]",

                            anchorTo = "CastBar",
                            point = "LEFT",
                            relativePoint = "LEFT",
                            offsetX = 4,
                            offsetY = 0,

                            font = STANDARD_TEXT_FONT,
                            fontSize = 12,
                            justifyH = "LEFT",

                            color = { 1.00, 1.00, 1.00, 1.00 },

                            shadowEnabled = true,
                            shadowOffsetX = 1,
                            shadowOffsetY = -1,
                            shadowColor = { 0, 0, 0, 1 },

                            outline = false,
                            thickOutline = false,
                            monochrome = false,
                        },

                        CastTime = {
                            enabled = true,
                            tag = "[cast:time]",

                            anchorTo = "CastBar",
                            point = "RIGHT",
                            relativePoint = "RIGHT",
                            offsetX = -4,
                            offsetY = 0,

                            font = STANDARD_TEXT_FONT,
                            fontSize = 12,
                            justifyH = "RIGHT",

                            color = { 1.00, 1.00, 1.00, 1.00 },

                            shadowEnabled = true,
                            shadowOffsetX = 1,
                            shadowOffsetY = -1,
                            shadowColor = { 0, 0, 0, 1 },

                            outline = false,
                            thickOutline = false,
                            monochrome = false,
                        },

                        Custom1 = {
                            enabled = false,
                            tag = "[hp:cur:abbr]/[hp:max:abbr] | [hp:perc]%",

                            anchorTo = "HealthBar",
                            point = "LEFT",
                            relativePoint = "LEFT",
                            offsetX = 2,
                            offsetY = 12,

                            font = STANDARD_TEXT_FONT,
                            fontSize = 15,
                            justifyH = "LEFT",

                            color = { 1.00, 1.00, 1.00, 1.00 },

                            shadowEnabled = true,
                            shadowOffsetX = 1,
                            shadowOffsetY = -1,
                            shadowColor = { 0, 0, 0, 1 },

                            outline = false,
                            thickOutline = false,
                            monochrome = false,
                        },

                        Custom2 = {
                            enabled = false,
                            tag = "",

                            anchorTo = "Frame",
                            point = "TOP",
                            relativePoint = "BOTTOM",
                            offsetX = 0,
                            offsetY = -22,

                            font = STANDARD_TEXT_FONT,
                            fontSize = 11,
                            justifyH = "CENTER",

                            color = { 1.00, 1.00, 1.00, 1.00 },

                            shadowEnabled = true,
                            shadowOffsetX = 1,
                            shadowOffsetY = -1,
                            shadowColor = { 0, 0, 0, 1 },

                            outline = false,
                            thickOutline = false,
                            monochrome = false,
                        },

                        Custom3 = {
                            enabled = false,
                            tag = "",

                            anchorTo = "Frame",
                            point = "TOP",
                            relativePoint = "BOTTOM",
                            offsetX = 0,
                            offsetY = -36,

                            font = STANDARD_TEXT_FONT,
                            fontSize = 11,
                            justifyH = "CENTER",

                            color = { 1.00, 1.00, 1.00, 1.00 },

                            shadowEnabled = true,
                            shadowOffsetX = 1,
                            shadowOffsetY = -1,
                            shadowColor = { 0, 0, 0, 1 },

                            outline = false,
                            thickOutline = false,
                            monochrome = false,
                        },
                    },
                },

                target = {
                    enabled = true,
                    mouseEnabled = true,
                    clickThrough = false,
                    clampToScreen = true,
                    showInSolo = true,
                    showInParty = true,
                    showInRaid = true,
                    showInArena = true,
                    showInPvp = true,
                    
                    width = 260,
                    height = 65,
                    alpha = 0.9,
                    scale = 1,
                    frameLevel = 1,
                    frameStrata = "MEDIUM",
                    point = "CENTER",
                    relativeTo = "UIParent",
                    relativePoint = "CENTER",
                    x = 270,
                    y = -290,
                    showPowerBar = true,
                    powerBarHeight = 20,
                    showAlternativePowerBar = false,
                    alternativePowerBarHeight = 5,
                    alternativePowerBarWidth = 100,
                    alternativePowerBarAnchorTo = "HealthBar",
                    alternativePowerBarPoint = "BOTTOMLEFT",
                    alternativePowerBarRelativePoint = "BOTTOMLEFT",
                    alternativePowerBarOffsetX = 5,
                    alternativePowerBarOffsetY = 5,
                    showCastBar = true,
                    showCastBarIcon = true,
                    castBarHeight = 20,
                    castBarPoint = "BOTTOMLEFT",
                    castBarRelativePoint = "BOTTOMLEFT",
                    castBarOffsetX = 0,
                    castBarOffsetY = -20,
                    statusBarTexture = "Interface\\TargetingFrame\\UI-StatusBar",
                    healthBarTexture = "Interface\\AddOns\\FocalPoint\\Media\\Textures\\Healbot.tga",
                    powerBarTexture = "Interface\\AddOns\\FocalPoint\\Media\\Textures\\Healbot.tga",
                    alternativePowerBarTexture = "Interface\\TargetingFrame\\UI-StatusBar",
                    castBarTexture = "Interface\\AddOns\\FocalPoint\\Media\\Textures\\Healbot.tga",
                    castBarColor = { 1.00, 0.72, 0.18, 1.00 },

                    backgroundColor = { 0.0784313753247261, 0.0784313753247261, 0.0784313753247261, 0.3164066076278687 },
                    borderColor = { 0.00, 0.00, 0.00, 0.00 },

                    healthColor = { 0.10, 0.80, 0.10, 0.65 },
                    healthBackground = true,
                    healthBackgroundColor = { 0.00, 0.00, 0.00, 0.65234375 },
                    useClassColorHealth = true,

                    powerColor = { 0.20, 0.40, 0.90, 0.65 },
                    powerBackground = true,
                    powerBackgroundColor = { 0.05490196496248245, 0.05882353335618973, 0.05882353335618973, 0.3945313394069672 },
                    useClassColorPower = true,
                    useReactionColorNpcHealth = true,

                    Portrait = {
                        enabled = false,
                        placement = "INSIDE",   -- INSIDE / ATTACHED
                        mode = "2D",            -- 2D / 3D
                        size = 40,
                        scale = 1,
                        padding = 4,            -- nur relevant für INSIDE
                        insideSide = "LEFT",    -- LEFT / RIGHT
                        anchorTo = "Frame",     -- für ATTACHED
                        point = "RIGHT",
                        relativePoint = "LEFT",
                        offsetX = -4,
                        offsetY = 0,
                    },

                    RaidTargetIcon = {
                        enabled = true,
                        placement = "ATTACHED", -- INSIDE / ATTACHED
                        size = 45,
                        scale = 1,
                        padding = 2,             -- only relevant for INSIDE
                        insideSide = "RIGHT",   -- LEFT / RIGHT
                        anchorTo = "HealthBar",
                        point = "TOPLEFT",
                        relativePoint = "TOPLEFT",
                        offsetX = 5,
                        offsetY = 0,
                    },

                    LeaderIcon = {
                        enabled = true,
                        placement = "ATTACHED",
                        size = 16,
                        scale = 1,
                        padding = 2,
                        insideSide = "LEFT",
                        anchorTo = "Frame",
                        point = "TOPLEFT",
                        relativePoint = "TOPLEFT",
                        offsetX = 0,
                        offsetY = 0,
                    },

                    RoleIcon = {
                        enabled = true,
                        placement = "ATTACHED",
                        size = 16,
                        scale = 1,
                        padding = 2,
                        insideSide = "RIGHT",
                        anchorTo = "Frame",
                        point = "TOPRIGHT",
                        relativePoint = "TOP",
                        offsetX = 0,
                        offsetY = 0,
                    },

                    CombatIndicator = {
                        enabled = false,
                        placement = "ATTACHED",
                        size = 16,
                        scale = 1,
                        padding = 2,
                        insideSide = "RIGHT",
                        anchorTo = "Frame",
                        point = "TOPLEFT",
                        relativePoint = "TOPLEFT",
                        offsetX = 0,
                        offsetY = 0,
                    },

                    RestingIndicator = {
                        enabled = true,
                        placement = "ATTACHED",
                        size = 16,
                        scale = 1,
                        padding = 2,
                        insideSide = "LEFT",
                        anchorTo = "Frame",
                        point = "TOPLEFT",
                        relativePoint = "TOP",
                        offsetX = 0,
                        offsetY = 0,
                    },

                    ReadyCheckIndicator = {
                        enabled = true,
                        placement = "ATTACHED",
                        size = 16,
                        scale = 1,
                        padding = 2,
                        insideSide = "RIGHT",
                        anchorTo = "Frame",
                        point = "TOPRIGHT",
                        relativePoint = "TOP",
                        offsetX = 0,
                        offsetY = 0,
                    },

                    Texts = {
                        Name = {
                            enabled = true,
                            tag = "[name]",

                            anchorTo = "Frame",
                            point = "TOPLEFT",
                            relativePoint = "TOPLEFT",
                            offsetX = 0,
                            offsetY = 20,

                            font = STANDARD_TEXT_FONT,
                            fontSize = 16,
                            justifyH = "CENTER",

                            color = { 1.00, 1.00, 1.00, 1.00 },

                            shadowEnabled = true,
                            shadowOffsetX = 1,
                            shadowOffsetY = -1,
                            shadowColor = { 0, 0, 0, 1 },

                            outline = false,
                            thickOutline = false,
                            monochrome = false,
                        },

                        Health = {
                            enabled = true,
                            tag = "[hp:cur:abbr]/[hp:max:abbr] || [hp:perc]%",

                            anchorTo = "HealthBar",
                            point = "RIGHT",
                            relativePoint = "RIGHT",
                            offsetX = -2,
                            offsetY = 0,

                            font = STANDARD_TEXT_FONT,
                            fontSize = 15,
                            justifyH = "RIGHT",

                            color = { 1.00, 1.00, 1.00, 1.00 },

                            shadowEnabled = true,
                            shadowOffsetX = 1,
                            shadowOffsetY = -1,
                            shadowColor = { 0, 0, 0, 1 },

                            outline = false,
                            thickOutline = false,
                            monochrome = false,
                        },

                        Power = {
                            enabled = true,
                            tag = "[power:cur:abbr]/[power:max:abbr]",

                            anchorTo = "PowerBar",
                            point = "RIGHT",
                            relativePoint = "RIGHT",
                            offsetX = -6,
                            offsetY = 0,

                            font = STANDARD_TEXT_FONT,
                            fontSize = 12,
                            justifyH = "RIGHT",

                            color = { 1.00, 1.00, 1.00, 1.00 },

                            shadowEnabled = true,
                            shadowOffsetX = 1,
                            shadowOffsetY = -1,
                            shadowColor = { 0, 0, 0, 1 },

                            outline = false,
                            thickOutline = false,
                            monochrome = false,
                        },

                        AltPower = {
                            enabled = true,
                            tag = "[altpower:cur] / [altpower:max]",

                            anchorTo = "AlternativePowerBar",
                            point = "RIGHT",
                            relativePoint = "RIGHT",
                            offsetX = -2,
                            offsetY = 0,

                            font = STANDARD_TEXT_FONT,
                            fontSize = 13,
                            justifyH = "RIGHT",

                            color = { 1.00, 1.00, 1.00, 1.00 },

                            shadowEnabled = true,
                            shadowOffsetX = 1,
                            shadowOffsetY = -1,
                            shadowColor = { 0, 0, 0, 1 },

                            outline = false,
                            thickOutline = false,
                            monochrome = false,
                        },

                        Level = {
                            enabled = false,
                            tag = "",

                            anchorTo = "PowerBar",
                            point = "LEFT",
                            relativePoint = "LEFT",
                            offsetX = 0,
                            offsetY = 0,

                            font = STANDARD_TEXT_FONT,
                            fontSize = 13,
                            justifyH = "RIGHT",

                            color = { 1.00, 0.82, 0.00, 1.00 },

                            shadowEnabled = true,
                            shadowOffsetX = 1,
                            shadowOffsetY = -1,
                            shadowColor = { 0, 0, 0, 1 },

                            outline = false,
                            thickOutline = false,
                            monochrome = false,
                        },

                        Class = {
                            enabled = false,
                            tag = "",

                            anchorTo = "PowerBar",
                            point = "LEFT",
                            relativePoint = "LEFT",
                            offsetX = 25,
                            offsetY = 0,

                            font = STANDARD_TEXT_FONT,
                            fontSize = 13,
                            justifyH = "CENTER",

                            color = { 1.00, 1.00, 1.00, 1.00 },

                            shadowEnabled = true,
                            shadowOffsetX = 1,
                            shadowOffsetY = -1,
                            shadowColor = { 0, 0, 0, 1 },

                            outline = false,
                            thickOutline = false,
                            monochrome = false,
                        },

                        Race = {
                            enabled = true,
                            tag = "[color:blizz_yellow][level][rc] [color:class][class][rc] [creature]",

                            anchorTo = "PowerBar",
                            point = "LEFT",
                            relativePoint = "LEFT",
                            offsetX = 2,
                            offsetY = 0,

                            font = STANDARD_TEXT_FONT,
                            fontSize = 12,
                            justifyH = "LEFT",

                            color = { 1.00, 1.00, 1.00, 1.00 },

                            shadowEnabled = true,
                            shadowOffsetX = 1,
                            shadowOffsetY = -1,
                            shadowColor = { 0, 0, 0, 1 },

                            outline = false,
                            thickOutline = false,
                            monochrome = false,
                        },

                        Status = {
                            enabled = false,
                            tag = "",

                            anchorTo = "HealthBar",
                            point = "LEFT",
                            relativePoint = "LEFT",
                            offsetX = 10,
                            offsetY = 2,

                            font = STANDARD_TEXT_FONT,
                            fontSize = 22,
                            justifyH = "LEFT",

                            color = { 1.00, 0.82, 0.20, 1.00 },

                            shadowEnabled = true,
                            shadowOffsetX = 1,
                            shadowOffsetY = -1,
                            shadowColor = { 0, 0, 0, 1 },

                            outline = false,
                            thickOutline = false,
                            monochrome = false,
                        },

                        CastName = {
                            enabled = true,
                            tag = "[cast:name]",

                            anchorTo = "CastBar",
                            point = "LEFT",
                            relativePoint = "LEFT",
                            offsetX = 4,
                            offsetY = 0,

                            font = STANDARD_TEXT_FONT,
                            fontSize = 11,
                            justifyH = "LEFT",

                            color = { 1.00, 0.82, 0.20, 1.00 },

                            shadowEnabled = true,
                            shadowOffsetX = 1,
                            shadowOffsetY = -1,
                            shadowColor = { 0, 0, 0, 1 },

                            outline = false,
                            thickOutline = false,
                            monochrome = false,
                        },

                        CastTime = {
                            enabled = true,
                            tag = "[cast:time]",

                            anchorTo = "CastBar",
                            point = "RIGHT",
                            relativePoint = "RIGHT",
                            offsetX = -4,
                            offsetY = 0,

                            font = STANDARD_TEXT_FONT,
                            fontSize = 10,
                            justifyH = "RIGHT",

                            color = { 1.00, 1.00, 1.00, 1.00 },

                            shadowEnabled = true,
                            shadowOffsetX = 1,
                            shadowOffsetY = -1,
                            shadowColor = { 0, 0, 0, 1 },

                            outline = false,
                            thickOutline = false,
                            monochrome = false,
                        },

                        Custom1 = {
                            enabled = false,
                            tag = "",

                            anchorTo = "Frame",
                            point = "TOP",
                            relativePoint = "BOTTOM",
                            offsetX = 0,
                            offsetY = -8,

                            font = STANDARD_TEXT_FONT,
                            fontSize = 11,
                            justifyH = "CENTER",

                            color = { 1.00, 1.00, 1.00, 1.00 },

                            shadowEnabled = true,
                            shadowOffsetX = 1,
                            shadowOffsetY = -1,
                            shadowColor = { 0, 0, 0, 1 },

                            outline = false,
                            thickOutline = false,
                            monochrome = false,
                        },

                        Custom2 = {
                            enabled = false,
                            tag = "",

                            anchorTo = "Frame",
                            point = "TOP",
                            relativePoint = "BOTTOM",
                            offsetX = 0,
                            offsetY = -22,

                            font = STANDARD_TEXT_FONT,
                            fontSize = 11,
                            justifyH = "CENTER",

                            color = { 1.00, 1.00, 1.00, 1.00 },

                            shadowEnabled = true,
                            shadowOffsetX = 1,
                            shadowOffsetY = -1,
                            shadowColor = { 0, 0, 0, 1 },

                            outline = false,
                            thickOutline = false,
                            monochrome = false,
                        },

                        Custom3 = {
                            enabled = false,
                            tag = "",

                            anchorTo = "Frame",
                            point = "TOP",
                            relativePoint = "BOTTOM",
                            offsetX = 0,
                            offsetY = -36,

                            font = STANDARD_TEXT_FONT,
                            fontSize = 11,
                            justifyH = "CENTER",

                            color = { 1.00, 1.00, 1.00, 1.00 },

                            shadowEnabled = true,
                            shadowOffsetX = 1,
                            shadowOffsetY = -1,
                            shadowColor = { 0, 0, 0, 1 },

                            outline = false,
                            thickOutline = false,
                            monochrome = false,
                        },
                    },
                },

                targettarget = { enabled = false },
                focus = { enabled = false },
                focustarget = { enabled = false },
                pet = {
                    enabled = true,
                    mouseEnabled = true,
                    clampToScreen = true,
                    clickThrough = false,

                    relativeTo = "FocalPoint_Player",
                    point = "TOPLEFT",
                    relativePoint = "TOPLEFT",
                    x = -100,
                    y = 150,
                    width = 195,
                    height = 50,
                    alpha = 0.85,
                    scale = 1,
                    frameStrata = "MEDIUM",
                    frameLevel = 0,
                    borderInset = 1,

                    showPowerBar = true,
                    powerBarHeight = 15,
                    showAlternativePowerBar = false,
                    alternativePowerBarHeight = 5,
                    alternativePowerBarWidth = 75,
                    alternativePowerBarAnchorTo = "HealthBar",
                    alternativePowerBarPoint = "BOTTOMLEFT",
                    alternativePowerBarRelativePoint = "BOTTOMLEFT",
                    alternativePowerBarOffsetX = 5,
                    alternativePowerBarOffsetY = 5,
                    showCastBar = false,
                    showCastBarIcon = false,
                    castBarHeight = 10,
                    castBarPoint = "BOTTOMLEFT",
                    castBarRelativePoint = "TOPLEFT",
                    castBarOffsetX = 0,
                    castBarOffsetY = 4,
                    statusBarTexture = "Interface\\TargetingFrame\\UI-StatusBar",
                    healthBarTexture = "Interface\\AddOns\\FocalPoint\\Media\\Textures\\Healbot.tga",
                    powerBarTexture = "Interface\\AddOns\\FocalPoint\\Media\\Textures\\Healbot.tga",
                    alternativePowerBarTexture = "Interface\\TargetingFrame\\UI-StatusBar",
                    castBarTexture = "Interface\\AddOns\\FocalPoint\\Media\\Textures\\Healbot.tga",
                    castBarColor = { 1.00, 0.72, 0.18, 1.00 },

                    backgroundColor = { 0.0784313753247261, 0.0784313753247261, 0.0784313753247261, 0.3164066076278687 },
                    borderColor = { 0.00, 0.00, 0.00, 0.00 },

                    healthColor = { 0.1882353127002716, 0.8000000715255737, 0.7686275243759155, 1.00 },
                    healthBackground = true,
                    healthBackgroundColor = { 0.00, 0.00, 0.00, 0.65234375 },
                    useClassColorHealth = true,

                    powerColor = { 0.8000000715255737, 0.01176470704376698, 0.00, 0.58203125 },
                    powerBackground = true,
                    powerBackgroundColor = { 0.05490196496248245, 0.05882353335618973, 0.05882353335618973, 0.3945313394069672 },
                    useClassColorPower = true,

                    Portrait = {
                        enabled = false,
                        placement = "INSIDE",
                        mode = "2D",
                        size = 45,
                        scale = 1,
                        padding = 5,
                        insideSide = "LEFT",
                        anchorTo = "Frame",
                        point = "RIGHT",
                        relativePoint = "LEFT",
                        offsetX = -4,
                        offsetY = 0,
                    },

                    RaidTargetIcon = {
                        enabled = false,
                        placement = "ATTACHED",
                        size = 16,
                        scale = 1,
                        padding = 2,
                        insideSide = "RIGHT",
                        anchorTo = "Frame",
                        point = "TOP",
                        relativePoint = "TOP",
                        offsetX = 0,
                        offsetY = 6,
                    },

                    LeaderIcon = {
                        enabled = false,
                        placement = "ATTACHED",
                        size = 14,
                        scale = 1,
                        padding = 2,
                        insideSide = "LEFT",
                        anchorTo = "Frame",
                        point = "TOPLEFT",
                        relativePoint = "TOP",
                        offsetX = 0,
                        offsetY = 0,
                    },

                    RoleIcon = {
                        enabled = false,
                        placement = "ATTACHED",
                        size = 14,
                        scale = 1,
                        padding = 2,
                        insideSide = "RIGHT",
                        anchorTo = "Frame",
                        point = "TOPRIGHT",
                        relativePoint = "TOP",
                        offsetX = 0,
                        offsetY = 0,
                    },

                    CombatIndicator = {
                        enabled = false,
                        placement = "ATTACHED",
                        size = 14,
                        scale = 1,
                        padding = 2,
                        insideSide = "RIGHT",
                        anchorTo = "Frame",
                        point = "TOP",
                        relativePoint = "TOP",
                        offsetX = 0,
                        offsetY = 0,
                    },

                    RestingIndicator = {
                        enabled = false,
                        placement = "ATTACHED",
                        size = 14,
                        scale = 1,
                        padding = 2,
                        insideSide = "LEFT",
                        anchorTo = "Frame",
                        point = "TOPLEFT",
                        relativePoint = "TOP",
                        offsetX = 0,
                        offsetY = 0,
                    },

                    ReadyCheckIndicator = {
                        enabled = false,
                        placement = "ATTACHED",
                        size = 14,
                        scale = 1,
                        padding = 2,
                        insideSide = "RIGHT",
                        anchorTo = "Frame",
                        point = "TOPRIGHT",
                        relativePoint = "TOP",
                        offsetX = 0,
                        offsetY = 0,
                    },

                    Texts = {
                        Name = {
                            enabled = true,
                            tag = "[name]",
                            anchorTo = "Frame",
                            point = "TOPRIGHT",
                            relativePoint = "TOPRIGHT",
                            offsetX = 0,
                            offsetY = 15,
                            font = STANDARD_TEXT_FONT,
                            fontSize = 14,
                            justifyH = "LEFT",
                            color = { 1.00, 1.00, 1.00, 1.00 },
                            shadowEnabled = true,
                            shadowOffsetX = 2,
                            shadowOffsetY = -2,
                            shadowColor = { 0, 0, 0, 1 },
                            outline = false,
                            thickOutline = false,
                            monochrome = false,
                        },

                        Health = {
                            enabled = true,
                            tag = "[hp:cur:abbr]/[hp:max:abbr] || [hp:perc]%",
                            anchorTo = "HealthBar",
                            point = "LEFT",
                            relativePoint = "LEFT",
                            offsetX = 0,
                            offsetY = 0,
                            font = STANDARD_TEXT_FONT,
                            fontSize = 11,
                            justifyH = "LEFT",
                            color = { 1.00, 1.00, 1.00, 1.00 },
                            shadowEnabled = true,
                            shadowOffsetX = 1,
                            shadowOffsetY = -1,
                            shadowColor = { 0, 0, 0, 1 },
                            outline = false,
                            thickOutline = false,
                            monochrome = false,
                        },

                        Power = {
                            enabled = true,
                            tag = "[power:cur]/[power:max]",
                            anchorTo = "PowerBar",
                            point = "LEFT",
                            relativePoint = "LEFT",
                            offsetX = 0,
                            offsetY = 0,
                            font = STANDARD_TEXT_FONT,
                            fontSize = 10,
                            justifyH = "LEFT",
                            color = { 1.00, 1.00, 1.00, 1.00 },
                            shadowEnabled = true,
                            shadowOffsetX = 1,
                            shadowOffsetY = -1,
                            shadowColor = { 0, 0, 0, 1 },
                            outline = false,
                            thickOutline = false,
                            monochrome = false,
                        },

                        Level = {
                            enabled = true,
                            tag = "[level]",
                            anchorTo = "PowerBar",
                            point = "RIGHT",
                            relativePoint = "CENTER",
                            offsetX = -5,
                            offsetY = 0,
                            font = STANDARD_TEXT_FONT,
                            fontSize = 10,
                            justifyH = "CENTER",
                            color = { 1.00, 0.82, 0.00, 1.00 },
                            shadowEnabled = true,
                            shadowOffsetX = 1,
                            shadowOffsetY = -1,
                            shadowColor = { 0, 0, 0, 1 },
                            outline = false,
                            thickOutline = false,
                            monochrome = false,
                        },

                        Race = {
                            enabled = true,
                            tag = "[creature]",
                            anchorTo = "PowerBar",
                            point = "RIGHT",
                            relativePoint = "RIGHT",
                            offsetX = -5,
                            offsetY = 0,
                            font = STANDARD_TEXT_FONT,
                            fontSize = 10,
                            justifyH = "CENTER",
                            color = { 1.00, 1.00, 1.00, 1.00 },
                            shadowEnabled = true,
                            shadowOffsetX = 1,
                            shadowOffsetY = -1,
                            shadowColor = { 0, 0, 0, 1 },
                            outline = false,
                            thickOutline = false,
                            monochrome = false,
                        },

                        Status = {
                            enabled = true,
                            tag = "[status][dead][dead:timer]",
                            anchorTo = "HealthBar",
                            point = "CENTER",
                            relativePoint = "CENTER",
                            offsetX = 75,
                            offsetY = 0,
                            font = STANDARD_TEXT_FONT,
                            fontSize = 11,
                            justifyH = "CENTER",
                            color = { 1.00, 0.82, 0.20, 1.00 },
                            shadowEnabled = true,
                            shadowOffsetX = 1,
                            shadowOffsetY = -1,
                            shadowColor = { 0, 0, 0, 1 },
                            outline = false,
                            thickOutline = false,
                            monochrome = false,
                        },

                        CastName = {
                            enabled = false,
                            tag = "[cast:name]",
                            anchorTo = "CastBar",
                            point = "LEFT",
                            relativePoint = "LEFT",
                            offsetX = 4,
                            offsetY = 0,
                            font = STANDARD_TEXT_FONT,
                            fontSize = 10,
                            justifyH = "LEFT",
                            color = { 1.00, 0.82, 0.20, 1.00 },
                            shadowEnabled = true,
                            shadowOffsetX = 1,
                            shadowOffsetY = -1,
                            shadowColor = { 0, 0, 0, 1 },
                            outline = false,
                            thickOutline = false,
                            monochrome = false,
                        },

                        CastTime = {
                            enabled = false,
                            tag = "[cast:time]",
                            anchorTo = "CastBar",
                            point = "RIGHT",
                            relativePoint = "RIGHT",
                            offsetX = -4,
                            offsetY = 0,
                            font = STANDARD_TEXT_FONT,
                            fontSize = 9,
                            justifyH = "RIGHT",
                            color = { 1.00, 1.00, 1.00, 1.00 },
                            shadowEnabled = true,
                            shadowOffsetX = 1,
                            shadowOffsetY = -1,
                            shadowColor = { 0, 0, 0, 1 },
                            outline = false,
                            thickOutline = false,
                            monochrome = false,
                        },

                        Custom1 = {
                            enabled = false,
                            tag = "",
                            anchorTo = "Frame",
                            point = "TOP",
                            relativePoint = "BOTTOM",
                            offsetX = 0,
                            offsetY = -8,
                            font = STANDARD_TEXT_FONT,
                            fontSize = 11,
                            justifyH = "CENTER",
                            color = { 1.00, 1.00, 1.00, 1.00 },
                            shadowEnabled = true,
                            shadowOffsetX = 1,
                            shadowOffsetY = -1,
                            shadowColor = { 0, 0, 0, 1 },
                            outline = false,
                            thickOutline = false,
                            monochrome = false,
                        },

                        Custom2 = {
                            enabled = false,
                            tag = "",
                            anchorTo = "Frame",
                            point = "TOP",
                            relativePoint = "BOTTOM",
                            offsetX = 0,
                            offsetY = -22,
                            font = STANDARD_TEXT_FONT,
                            fontSize = 11,
                            justifyH = "CENTER",
                            color = { 1.00, 1.00, 1.00, 1.00 },
                            shadowEnabled = true,
                            shadowOffsetX = 1,
                            shadowOffsetY = -1,
                            shadowColor = { 0, 0, 0, 1 },
                            outline = false,
                            thickOutline = false,
                            monochrome = false,
                        },

                        Custom3 = {
                            enabled = false,
                            tag = "",
                            anchorTo = "Frame",
                            point = "TOP",
                            relativePoint = "BOTTOM",
                            offsetX = 0,
                            offsetY = -36,
                            font = STANDARD_TEXT_FONT,
                            fontSize = 11,
                            justifyH = "CENTER",
                            color = { 1.00, 1.00, 1.00, 1.00 },
                            shadowEnabled = true,
                            shadowOffsetX = 1,
                            shadowOffsetY = -1,
                            shadowColor = { 0, 0, 0, 1 },
                            outline = false,
                            thickOutline = false,
                            monochrome = false,
                        },
                    },
                },
                boss = { enabled = false },
            },
        },
    }
end
