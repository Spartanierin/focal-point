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

function Utils.NormalizeUnitTexts(unitConfig)
    local texts = type(unitConfig) == "table" and unitConfig.Texts or nil
    if type(texts) ~= "table" then
        return
    end

    local resolver = FocalPoint.TextTemplateResolver
    if resolver and type(resolver.InvalidateUnitTexts) == "function" then
        resolver.InvalidateUnitTexts(unitConfig)
    end

    -- Each key owns an independent composition object, regardless of its content.
    for textKey, textConfig in pairs(texts) do
        if type(textConfig) ~= "table" then
            texts[textKey] = nil
        end
    end
end

function Utils.NormalizeAllUnitTexts(units)
    if type(units) ~= "table" then
        return
    end

    for _, unitConfig in pairs(units) do
        Utils.NormalizeUnitTexts(unitConfig)
    end
end

function Utils.GetProfileDB()
    local db = FocalPoint.db
    if not db or type(db.profile) ~= "table" then
        return nil
    end

    return db.profile
end

function Utils.GetUnitsDB()
    local resolver = FocalPoint.ActiveLayoutResolver
    if resolver and resolver.GetActiveUnits then
        return resolver.GetActiveUnits(FocalPoint.db)
    end

    return nil
end

function Utils.GetGeneralDB()
    local profile = Utils.GetProfileDB()
    if not profile or type(profile.General) ~= "table" then
        return nil
    end

    return profile.General
end

function Utils.GetTextTemplatesDB()
    local resolver = FocalPoint.ActiveLayoutResolver
    if resolver and resolver.GetActiveTextTemplates then
        return resolver.GetActiveTextTemplates(FocalPoint.db)
    end

    return nil
end

function Utils.GetUnitDB(unit)
    local units = Utils.GetUnitsDB()
    if not units then
        return nil
    end

    return units[Utils.NormalizeConfigUnitKey(unit)]
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

local function IsSecretValue(value)
    return issecretvalue and issecretvalue(value) or false
end

function Utils.IsSecretValue(value)
    return IsSecretValue(value)
end

function Utils.IsSafeTrue(value)
    if IsSecretValue(value) then
        return false
    end

    return type(value) == "boolean" and value or false
end

function Utils.ResolveInterruptibleState(notInterruptible)
    return Utils.ResolveInterruptState(notInterruptible) == "INTERRUPTIBLE"
end

function Utils.ResolveInterruptState(notInterruptible)
    if not IsSecretValue(notInterruptible) and type(notInterruptible) == "boolean" then
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

    if not IsSecretValue(value) and type(value) == "number" then
        return value
    end

    local textOk, textValue = pcall(tostring, value)
    if textOk and type(textValue) == "string" then
        local numberOk, numberValue = pcall(tonumber, textValue)
        if numberOk and not IsSecretValue(numberValue) and type(numberValue) == "number" then
            return numberValue
        end
    end

    local formattedOk, formattedValue = pcall(string.format, "%.0f", value)
    if formattedOk and type(formattedValue) == "string" then
        local numberOk, numberValue = pcall(tonumber, formattedValue)
        if numberOk and not IsSecretValue(numberValue) and type(numberValue) == "number" then
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
