local _, FocalPoint = ...

FocalPoint.TextElementColors = FocalPoint.TextElementColors or {}
local Colors = FocalPoint.TextElementColors

local TextUtils = FocalPoint.TextElementUtils or {}

local IsPreviewModeEnabled = TextUtils.IsPreviewModeEnabled
local UnpackColor = TextUtils.UnpackColor

-- Text color helpers keep color resolution and color-tag formatting separate
-- from the main token and template runtime.

function Colors.GetClassTextColor(unit, frame)
    if frame and frame.TestValues and frame.TestValues.classToken and (IsPreviewModeEnabled() or frame.IsTemplatePreview) then
        local classToken = frame.TestValues.classToken:upper()
        local classColor = nil

        if CUSTOM_CLASS_COLORS and CUSTOM_CLASS_COLORS[classToken] then
            classColor = CUSTOM_CLASS_COLORS[classToken]
        elseif RAID_CLASS_COLORS and RAID_CLASS_COLORS[classToken] then
            classColor = RAID_CLASS_COLORS[classToken]
        elseif C_ClassColor and C_ClassColor.GetClassColor then
            classColor = C_ClassColor.GetClassColor(classToken)
        end

        if classColor then
            return classColor.r or classColor[1], classColor.g or classColor[2], classColor.b or classColor[3], classColor.a or 1
        end
    end

    if not unit or not UnitExists or not UnitExists(unit) or not UnitClass then
        return nil
    end

    local _, classToken = UnitClass(unit)
    if not classToken then
        return nil
    end

    if type(classToken) == "string" then
        classToken = classToken:upper()
    end

    local color = nil

    if CUSTOM_CLASS_COLORS and CUSTOM_CLASS_COLORS[classToken] then
        color = CUSTOM_CLASS_COLORS[classToken]
    elseif RAID_CLASS_COLORS and RAID_CLASS_COLORS[classToken] then
        color = RAID_CLASS_COLORS[classToken]
    elseif C_ClassColor and C_ClassColor.GetClassColor then
        local classColor = C_ClassColor.GetClassColor(classToken)
        if classColor then
            return classColor.r or 1, classColor.g or 1, classColor.b or 1, classColor.a or 1
        end
    end

    if not color then
        return nil
    end

    return color.r or color[1], color.g or color[2], color.b or color[3], 1
end

function Colors.ClampColorComponent(value)
    if type(value) ~= "number" then
        return 255
    end

    if value < 0 then
        value = 0
    elseif value > 1 then
        value = 1
    end

    return math.floor((value * 255) + 0.5)
end

function Colors.BuildColorCode(r, g, b, a)
    return string.format(
        "|c%02x%02x%02x%02x",
        Colors.ClampColorComponent(a == nil and 1 or a),
        Colors.ClampColorComponent(r),
        Colors.ClampColorComponent(g),
        Colors.ClampColorComponent(b)
    )
end

function Colors.GetPowerTextColor(unit, frame)
    if frame and frame.TestValues and frame.TestValues.powerToken and (IsPreviewModeEnabled() or frame.IsTemplatePreview) then
        local previewToken = frame.TestValues.powerToken
        local previewColor = PowerBarColor and (PowerBarColor[previewToken] or PowerBarColor[0])
        if previewColor then
            return previewColor.r or previewColor[1], previewColor.g or previewColor[2], previewColor.b or previewColor[3], 1
        end
    end

    if not unit or not UnitPowerType then
        return nil
    end

    local powerType, powerToken, altR, altG, altB = UnitPowerType(unit)
    if type(altR) == "number" and type(altG) == "number" and type(altB) == "number" then
        return altR, altG, altB, 1
    end

    local powerColor = nil
    if PowerBarColor then
        powerColor = (powerToken and PowerBarColor[powerToken]) or PowerBarColor[powerType]
    end

    if not powerColor then
        return nil
    end

    return powerColor.r or powerColor[1], powerColor.g or powerColor[2], powerColor.b or powerColor[3], 1
end

function Colors.GetReactionTextColor(unit, frame)
    if frame and frame.TestValues and (IsPreviewModeEnabled() or frame.IsTemplatePreview) then
        local reaction = frame.TestValues.reaction or 5
        local previewColor = FACTION_BAR_COLORS and FACTION_BAR_COLORS[reaction]
        if previewColor then
            return previewColor.r or previewColor[1], previewColor.g or previewColor[2], previewColor.b or previewColor[3], 1
        end
    end

    if not unit or not UnitReaction or not FACTION_BAR_COLORS then
        return nil
    end

    local reaction = UnitReaction("player", unit)
    local color = reaction and FACTION_BAR_COLORS[reaction] or nil
    if not color then
        return nil
    end

    return color.r or color[1], color.g or color[2], color.b or color[3], 1
end

function Colors.GetBlizzardNamedColor(colorName)
    if type(colorName) ~= "string" or colorName == "" then
        return nil
    end

    colorName = colorName:lower()
    local colorMap = {
        normal = NORMAL_FONT_COLOR,
        highlight = HIGHLIGHT_FONT_COLOR,
        disabled = DISABLED_FONT_COLOR,
        red = RED_FONT_COLOR,
        green = GREEN_FONT_COLOR,
        yellow = YELLOW_FONT_COLOR,
    }

    local color = colorMap[colorName]
    if not color then
        return nil
    end

    return Colors.BuildColorCode(color.r or color[1], color.g or color[2], color.b or color[3], color.a or color[4] or 1)
end

function Colors.GetExplicitColorCode(value)
    local hex = type(value) == "string" and value:match("^#?([0-9A-Fa-f]+)$") or nil
    if not hex then
        return nil
    end

    hex = hex:lower()
    if #hex == 6 then
        return "|cff" .. hex
    end

    if #hex == 8 then
        return "|c" .. hex
    end

    return nil
end

function Colors.ResolveColorTag(frame, unit, token, fallbackColor)
    if token == "rc" or token == "resetcolor" then
        if type(fallbackColor) == "table" then
            local r, g, b, a = UnpackColor(fallbackColor, { 1, 1, 1, 1 })
            return Colors.BuildColorCode(r, g, b, a)
        end
        return "|r"
    end

    if token == "classcolor" or token == "raidcolor" then
        local r, g, b, a = Colors.GetClassTextColor(unit, frame)
        if r and g and b then
            return Colors.BuildColorCode(r, g, b, a)
        end
        return nil
    end

    if token == "powercolor" then
        local r, g, b, a = Colors.GetPowerTextColor(unit, frame)
        if r and g and b then
            return Colors.BuildColorCode(r, g, b, a)
        end
        return nil
    end

    local colorValue = type(token) == "string" and token:match("^color:(.+)$") or nil
    if colorValue then
        colorValue = colorValue:lower()

        if colorValue == "class" or colorValue == "raid" then
            local r, g, b, a = Colors.GetClassTextColor(unit, frame)
            if r and g and b then
                return Colors.BuildColorCode(r, g, b, a)
            end
            return nil
        end

        if colorValue == "blizz_pwr" then
            local r, g, b, a = Colors.GetPowerTextColor(unit, frame)
            if r and g and b then
                return Colors.BuildColorCode(r, g, b, a)
            end
            return nil
        end

        if colorValue == "reaction" then
            local r, g, b, a = Colors.GetReactionTextColor(unit, frame)
            if r and g and b then
                return Colors.BuildColorCode(r, g, b, a)
            end
            return nil
        end

        local blizzardKey = colorValue:match("^blizz_(.+)$")
        if blizzardKey then
            return Colors.GetBlizzardNamedColor(blizzardKey)
        end

        local explicitColor = Colors.GetExplicitColorCode(colorValue)
        if explicitColor then
            return explicitColor
        end
    end

    local explicitColor = Colors.GetExplicitColorCode(token)
    if explicitColor then
        return explicitColor
    end

    local blizzardColor = type(token) == "string" and token:match("^blizz:([%w_]+)$") or nil
    if blizzardColor then
        return Colors.GetBlizzardNamedColor(blizzardColor)
    end

    return nil
end
