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