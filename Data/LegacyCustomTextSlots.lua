local _, ns = ...

-- Frozen reset/fingerprint reference, never a Create payload.
-- Source: v2.1.0:Data/Defaults.lua; SHA-256 81F4CEC14A00A36F9EF0587B7A403D4A978A0EEE5ACABA155664C0024871471C
local records = {
    {
        enabled = false,
    },
    {
        anchorTo = "Frame",
        color = {[1] = 1.0, [2] = 1.0, [3] = 1.0, [4] = 1.0},
        enabled = false,
        font = "fp:font:standard",
        fontSize = 11,
        justifyH = "CENTER",
        monochrome = false,
        offsetX = 0,
        offsetY = -8,
        outline = false,
        point = "TOP",
        relativePoint = "BOTTOM",
        shadowColor = {[1] = 0, [2] = 0, [3] = 0, [4] = 1},
        shadowEnabled = true,
        shadowOffsetX = 1,
        shadowOffsetY = -1,
        tag = "",
        thickOutline = false,
    },
    {
        anchorTo = "Frame",
        color = {[1] = 1.0, [2] = 1.0, [3] = 1.0, [4] = 1.0},
        enabled = false,
        font = "fp:font:standard",
        fontSize = 11,
        justifyH = "CENTER",
        monochrome = false,
        offsetX = 0,
        offsetY = -22,
        outline = false,
        point = "TOP",
        relativePoint = "BOTTOM",
        shadowColor = {[1] = 0, [2] = 0, [3] = 0, [4] = 1},
        shadowEnabled = true,
        shadowOffsetX = 1,
        shadowOffsetY = -1,
        tag = "",
        thickOutline = false,
    },
    {
        anchorTo = "Frame",
        color = {[1] = 1.0, [2] = 1.0, [3] = 1.0, [4] = 1.0},
        enabled = false,
        font = "fp:font:standard",
        fontSize = 11,
        justifyH = "CENTER",
        monochrome = false,
        offsetX = 0,
        offsetY = -36,
        outline = false,
        point = "TOP",
        relativePoint = "BOTTOM",
        shadowColor = {[1] = 0, [2] = 0, [3] = 0, [4] = 1},
        shadowEnabled = true,
        shadowOffsetX = 1,
        shadowOffsetY = -1,
        tag = "",
        thickOutline = false,
    },
    {
        anchorTo = "HealthBar",
        color = {[1] = 1.0, [2] = 1.0, [3] = 1.0, [4] = 1.0},
        enabled = false,
        font = "fp:font:standard",
        fontSize = 15,
        justifyH = "LEFT",
        monochrome = false,
        offsetX = 2,
        offsetY = 12,
        outline = false,
        point = "LEFT",
        relativePoint = "LEFT",
        shadowColor = {[1] = 0, [2] = 0, [3] = 0, [4] = 1},
        shadowEnabled = true,
        shadowOffsetX = 1,
        shadowOffsetY = -1,
        tag = "[hp:cur:abbr]/[hp:max:abbr] | [hp:perc]%",
        templateName = "",
        thickOutline = false,
    },
}

local pairsByUnit = {
    boss = {Custom1 = 1, Custom2 = 1, Custom3 = 1},
    focus = {Custom1 = 2, Custom2 = 3, Custom3 = 4},
    focustarget = {Custom1 = 2, Custom2 = 3, Custom3 = 4},
    pet = {Custom1 = 2, Custom2 = 3, Custom3 = 4},
    player = {Custom1 = 5, Custom2 = 3, Custom3 = 4},
    target = {Custom1 = 2, Custom2 = 3, Custom3 = 4},
    targettarget = {Custom1 = 2, Custom2 = 3, Custom3 = 4},
}

local function Copy(value)
    if type(value) ~= 'table' then return value end
    local result = {}
    for key, child in pairs(value) do result[key] = Copy(child) end
    return result
end

ns.LegacyCustomTextSlots = {}
function ns.LegacyCustomTextSlots.Get(unitKey, textKey)
    local slots = pairsByUnit[unitKey]
    local index = slots and slots[textKey]
    return index and Copy(records[index]) or nil
end
