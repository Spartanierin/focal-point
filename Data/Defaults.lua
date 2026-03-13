local _, Portrait = ...

function Portrait:GetDefaultDB()
    return {
        profile = {
            General = {
                TagUpdateInterval = 0.25,
                Separator = "||",
                ToTSeparator = "»",
                UIScale = 1,
                HideBlizzardFrames = false,
                GlobalClickThrough = false,
            },

            Minimap = {
                hide = false,
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

                    width = 220,
                    height = 40,
                    alpha = 1,
                    scale = 1,
                    frameLevel = 1,
                    frameStrata = "MEDIUM",
                    point = "CENTER",
                    relativeTo = "UIParent",
                    relativePoint = "CENTER",
                    x = -250,
                    y = -180,

                    showPowerBar = true,
                    powerBarHeight = 8,
                    showCastBar = true,
                    showCastBarIcon = true,
                    castBarHeight = 10,
                    castBarPoint = "BOTTOMLEFT",
                    castBarRelativePoint = "TOPLEFT",
                    castBarOffsetX = 0,
                    castBarOffsetY = 4,

                    statusBarTexture = "Interface\\TargetingFrame\\UI-StatusBar",
                    healthBarTexture = "Interface\\TargetingFrame\\UI-StatusBar",
                    powerBarTexture = "Interface\\TargetingFrame\\UI-StatusBar",
                    castBarTexture = "Interface\\TargetingFrame\\UI-StatusBar",

                    backgroundColor = { 0.08, 0.08, 0.08, 0.90 },
                    borderColor = { 0.20, 0.20, 0.20, 1.00 },

                    healthColor = { 0.10, 0.80, 0.10, 1.00 },
                    healthBackground = true,
                    healthBackgroundColor = { 0.00, 0.00, 0.00, 0.35 },
                    useClassColorHealth = false,

                    powerColor = { 0.20, 0.40, 0.90, 1.00 },
                    powerBackground = true,
                    powerBackgroundColor = { 0.00, 0.00, 0.00, 0.35 },
                    useClassColorPower = false,

                    Portrait = {
                        enabled = true,
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
                        size = 18,
                        scale = 1,
                        padding = 2,             -- only relevant for INSIDE
                        insideSide = "RIGHT",   -- LEFT / RIGHT
                        anchorTo = "Frame",
                        point = "TOP",
                        relativePoint = "TOP",
                        offsetX = 0,
                        offsetY = 8,
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
                        relativePoint = "TOP",
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
                        enabled = true,
                        placement = "ATTACHED",
                        size = 16,
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

                            anchorTo = "HealthBar",
                            point = "CENTER",
                            relativePoint = "CENTER",
                            offsetX = 0,
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

                        Health = {
                            enabled = true,
                            tag = "[hp:cur] / [hp:max]",

                            anchorTo = "HealthBar",
                            point = "RIGHT",
                            relativePoint = "RIGHT",
                            offsetX = -6,
                            offsetY = 0,

                            font = STANDARD_TEXT_FONT,
                            fontSize = 11,
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
                            tag = "[power:cur] / [power:max]",

                            anchorTo = "PowerBar",
                            point = "RIGHT",
                            relativePoint = "RIGHT",
                            offsetX = -6,
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

                        Level = {
                            enabled = true,
                            tag = "[level]",

                            anchorTo = "Frame",
                            point = "LEFT",
                            relativePoint = "LEFT",
                            offsetX = 6,
                            offsetY = 0,

                            font = STANDARD_TEXT_FONT,
                            fontSize = 11,
                            justifyH = "LEFT",

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
                            tag = "[class]",

                            anchorTo = "Frame",
                            point = "LEFT",
                            relativePoint = "LEFT",
                            offsetX = 28,
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

                        Race = {
                            enabled = true,
                            tag = "[race]",

                            anchorTo = "Frame",
                            point = "LEFT",
                            relativePoint = "LEFT",
                            offsetX = 70,
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

                        Status = {
                            enabled = true,
                            tag = "[status]",

                            anchorTo = "HealthBar",
                            point = "CENTER",
                            relativePoint = "CENTER",
                            offsetX = 0,
                            offsetY = 0,

                            font = STANDARD_TEXT_FONT,
                            fontSize = 12,
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
                    },
                },

                target = {
                    enabled = false,
                    mouseEnabled = true,
                    clickThrough = false,
                    clampToScreen = true,
                    showInSolo = true,
                    showInParty = true,
                    showInRaid = true,
                    showInArena = true,
                    showInPvp = true,
                    
                    width = 220,
                    height = 40,
                    alpha = 1,
                    scale = 1,
                    frameLevel = 1,
                    frameStrata = "MEDIUM",
                    point = "CENTER",
                    relativeTo = "UIParent",
                    relativePoint = "CENTER",
                    x = 250,
                    y = -180,
                    showPowerBar = false,
                    showCastBar = true,
                    showCastBarIcon = true,
                    castBarHeight = 10,
                    castBarPoint = "BOTTOMLEFT",
                    castBarRelativePoint = "TOPLEFT",
                    castBarOffsetX = 0,
                    castBarOffsetY = 4,
                    castBarTexture = "Interface\\TargetingFrame\\UI-StatusBar",

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
                        size = 18,
                        scale = 1,
                        padding = 2,             -- only relevant for INSIDE
                        insideSide = "RIGHT",   -- LEFT / RIGHT
                        anchorTo = "Frame",
                        point = "TOP",
                        relativePoint = "TOP",
                        offsetX = 0,
                        offsetY = 8,
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
                        relativePoint = "TOP",
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
                        enabled = true,
                        placement = "ATTACHED",
                        size = 16,
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
                    },
                },

                targettarget = { enabled = false },
                focus = { enabled = false },
                focustarget = { enabled = false },
                pet = { enabled = false },
                boss = { enabled = false },
            },
        },
    }
end
