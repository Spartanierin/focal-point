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
                    width = 220,
                    height = 40,
                    point = "CENTER",
                    relativeTo = "UIParent",
                    relativePoint = "CENTER",
                    x = -250,
                    y = -180,

                    showPowerBar = true,
                    powerBarHeight = 8,

                    nameTag = "[name]",
                    nameOffsetX = 0,
                    nameOffsetY = 0,
                    nameJustifyH = "CENTER",

                    nameFont = STANDARD_TEXT_FONT,
                    nameFontSize = 12,
                    nameOutline = false,
                    nameThickOutline = false,
                    nameMonochrome = false,

                    nameShadowEnabled = true,
                    nameShadowOffsetX = 1,
                    nameShadowOffsetY = -1,
                    nameShadowColor = { 0, 0, 0, 1 },

                    statusBarTexture = "Interface\\TargetingFrame\\UI-StatusBar",

                    backgroundColor = { 0.08, 0.08, 0.08, 0.90 },
                    borderColor = { 0.20, 0.20, 0.20, 1.00 },
                    healthColor = { 0.10, 0.80, 0.10, 1.00 },
                    powerColor = { 0.20, 0.40, 0.90, 1.00 },
                    nameColor = { 1.00, 1.00, 1.00, 1.00 },
                },

                target = {
                    enabled = false,
                    width = 220,
                    height = 40,
                    point = "CENTER",
                    relativeTo = "UIParent",
                    relativePoint = "CENTER",
                    x = 250,
                    y = -180,
                    showPowerBar = false,
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