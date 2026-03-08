local _, Portrait = ...

function Portrait:GetDefaultDB()
    return {
        profile = {
            General = {
                TagUpdateInterval = 0.25,
                Separator = "||",
                ToTSeparator = "»",
                UIScale = 1,
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

                    statusBarTexture = "Interface\\TargetingFrame\\UI-StatusBar",

                    backgroundColor = { 0.08, 0.08, 0.08, 0.90 },
                    borderColor = { 0.20, 0.20, 0.20, 1.00 },
                    healthColor = { 0.10, 0.80, 0.10, 1.00 },
                    powerColor = { 0.20, 0.40, 0.90, 1.00 },
                    useClassColorHealth = false,
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
                            tag = "[hp:cur]",

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
                    },
                },

                target = {
                    enabled = false,
                    mouseEnabled = true,
                    clickThrough = false,
                    clampToScreen = true,
                    
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