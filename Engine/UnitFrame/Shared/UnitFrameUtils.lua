local _, FocalPoint = ...

FocalPoint.UnitFrameUtils = FocalPoint.UnitFrameUtils or {}
local Utils = FocalPoint.UnitFrameUtils

-- Utility helpers shared by the unit-frame runtime.
-- Keep this file focused on pure value conversion and safe API handling.

function Utils.NormalizeConfigUnitKey(unit)
    if type(unit) ~= "string" or unit == "" then
        return unit
    end

    if unit:match("^boss%d+$") then
        return "boss"
    end

    return unit
end

function Utils.GetBossFrameIndex(unit)
    if type(unit) ~= "string" then
        return nil
    end

    local bossIndex = unit:match("^boss(%d+)$")
    if not bossIndex then
        return nil
    end

    bossIndex = tonumber(bossIndex)
    if type(bossIndex) == "number" and bossIndex >= 1 and bossIndex <= 5 then
        return bossIndex
    end

    return nil
end

function Utils.GetUnitDB(unit)
    local db = FocalPoint.db
    if not db or not db.profile or not db.profile.Units then
        return nil
    end

    return db.profile.Units[Utils.NormalizeConfigUnitKey(unit)]
end

function Utils.UnpackColor(color, fallback)
    color = color or fallback or { 1, 1, 1, 1 }

    local r = color[1] or color.r or 1
    local g = color[2] or color.g or 1
    local b = color[3] or color.b or 1
    local a = color[4]
    if a == nil then
        a = color.a
    end
    if a == nil then
        a = 1
    end

    return r, g, b, a
end

function Utils.IsSafeTrue(value)
    return type(value) == "boolean" and not (issecretvalue and issecretvalue(value)) and value
end

function Utils.ResolveInterruptibleState(notInterruptible)
    return Utils.ResolveInterruptState(notInterruptible) == "INTERRUPTIBLE"
end

function Utils.ResolveInterruptState(notInterruptible)
    if type(notInterruptible) == "boolean" and not (issecretvalue and issecretvalue(notInterruptible)) then
        if notInterruptible then
            return "PROTECTED"
        end

        return "INTERRUPTIBLE"
    end

    return "UNKNOWN"
end

function Utils.ToSafeNumberValue(value)
    if value == nil then
        return 0
    end

    if type(value) == "number" and not (issecretvalue and issecretvalue(value)) then
        return value
    end

    local textOk, textValue = pcall(tostring, value)
    if textOk and type(textValue) == "string" then
        local numberOk, numberValue = pcall(tonumber, textValue)
        if numberOk and type(numberValue) == "number" and not (issecretvalue and issecretvalue(numberValue)) then
            return numberValue
        end
    end

    local formattedOk, formattedValue = pcall(string.format, "%.0f", value)
    if formattedOk and type(formattedValue) == "string" then
        local numberOk, numberValue = pcall(tonumber, formattedValue)
        if numberOk and type(numberValue) == "number" and not (issecretvalue and issecretvalue(numberValue)) then
            return numberValue
        end
    end

    return 0
end

function Utils.FormatDisplayNumber(value)
    if value == nil then
        return "0"
    end

    if BreakUpLargeNumbers then
        local ok, result = pcall(BreakUpLargeNumbers, value)
        if ok and type(result) == "string" then
            return result
        end
    end

    local ok, result = pcall(string.format, "%s", value)
    if ok and type(result) == "string" then
        return result
    end

    return "0"
end

function Utils.ResolveBlizzardAbbreviation(rawValue, displayText)
    if type(AbbreviateLargeNumbers) == "function" then
        local ok, abbreviation = pcall(AbbreviateLargeNumbers, rawValue)
        if ok and type(abbreviation) == "string" then
            return abbreviation
        end
    end

    if type(displayText) == "string" then
        return displayText
    end

    return ""
end
