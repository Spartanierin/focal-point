local _, FocalPoint = ...

FocalPoint.TextElementUtils = FocalPoint.TextElementUtils or {}
local Utils = FocalPoint.TextElementUtils

-- Shared text utilities keep formatting and safe value conversion out of the
-- larger tag and template runtime.

function Utils.IsPreviewModeEnabled()
    local presence = FocalPoint.UnitFramePresence
    if presence and presence.IsPreviewModeEnabled then
        return presence.IsPreviewModeEnabled()
    end
    return false
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

function Utils.GetFontPath(path)
    if type(path) == "string" and path ~= "" then
        return path
    end
    return STANDARD_TEXT_FONT
end

function Utils.BuildFontFlags(config)
    local flags = {}
    local fontStyle = type(config) == "table" and config.fontStyle or nil

    if fontStyle == "OUTLINE" then
        flags[#flags + 1] = "OUTLINE"
    elseif fontStyle == "THICKOUTLINE" then
        flags[#flags + 1] = "THICKOUTLINE"
    elseif fontStyle == "MONOCHROME" then
        flags[#flags + 1] = "MONOCHROME"
    elseif fontStyle == "OUTLINE_MONOCHROME" then
        flags[#flags + 1] = "OUTLINE"
        flags[#flags + 1] = "MONOCHROME"
    elseif fontStyle == "THICKOUTLINE_MONOCHROME" then
        flags[#flags + 1] = "THICKOUTLINE"
        flags[#flags + 1] = "MONOCHROME"
    elseif fontStyle ~= nil then
        return ""
    end

    if fontStyle ~= nil then
        return table.concat(flags, ",")
    end

    if config.outline then
        flags[#flags + 1] = "OUTLINE"
    end

    if config.thickOutline then
        flags[#flags + 1] = "THICKOUTLINE"
    end

    if config.monochrome then
        flags[#flags + 1] = "MONOCHROME"
    end

    return table.concat(flags, ",")
end

function Utils.FormatNumber(value)
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

function Utils.FormatInteger(value)
    if value == nil then
        return "0"
    end

    local ok, result = pcall(string.format, "%d", value)
    if ok and type(result) == "string" then
        return result
    end

    return "0"
end

function Utils.FormatTextValue(value)
    if type(value) == "string" then
        return value
    end

    return Utils.FormatInteger(value)
end

function Utils.IsSecret(value)
    return issecretvalue and issecretvalue(value) or false
end

function Utils.AsSafeNumber(value)
    if type(value) == "number" and not Utils.IsSecret(value) then
        return value
    end

    return nil
end

function Utils.FormatRenderableInteger(value, fallback)
    local ok, formatted = pcall(Utils.FormatInteger, value)
    if ok then
        return formatted
    end

    return fallback
end

function Utils.FormatRenderableNumber(value, fallback)
    local ok, formatted = pcall(Utils.FormatNumber, value)
    if ok then
        return formatted
    end

    return fallback
end

function Utils.AsRenderableText(value, fallback)
    if value == nil then
        return fallback
    end

    if type(value) == "string" then
        return value
    end

    return fallback
end

function Utils.FormatTimeValue(value)
    if type(value) ~= "number" then
        return ""
    end

    if value < 0 then
        value = 0
    end

    return string.format("%.1f", value)
end

function Utils.IsSafeTrue(value)
    if type(value) == "boolean" and not (issecretvalue and issecretvalue(value)) then
        return value
    end

    return false
end

function Utils.ToSafeNumber(value)
    if value == nil then
        return 0
    end

    if type(value) == "number" and not (issecretvalue and issecretvalue(value)) then
        return value
    end

    local directOk, directValue = pcall(tonumber, value)
    if directOk and type(directValue) == "number" and not (issecretvalue and issecretvalue(directValue)) then
        return directValue
    end

    local textOk, textValue = pcall(tostring, value)
    if textOk and type(textValue) == "string" then
        local parsedOk, parsedValue = pcall(tonumber, textValue)
        if parsedOk and type(parsedValue) == "number" and not (issecretvalue and issecretvalue(parsedValue)) then
            return parsedValue
        end
    end

    local ok, formatted = pcall(string.format, "%.0f", value)
    if ok and type(formatted) == "string" and not (issecretvalue and issecretvalue(formatted)) then
        return tonumber(formatted) or 0
    end

    return 0
end
