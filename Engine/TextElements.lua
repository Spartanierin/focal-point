local _, FocalPoint = ...

FocalPoint.UnitFrame = FocalPoint.UnitFrame or {}
local UF = FocalPoint.UnitFrame

local function UnpackColor(color, fallback)
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

local function GetFontPath(path)
    if type(path) == "string" and path ~= "" then
        return path
    end
    return STANDARD_TEXT_FONT
end

local function GetLocalizedClassName(classToken)
    if type(classToken) ~= "string" or classToken == "" then
        return nil
    end

    classToken = classToken:upper()

    return
        (LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[classToken]) or
        (LOCALIZED_CLASS_NAMES_FEMALE and LOCALIZED_CLASS_NAMES_FEMALE[classToken]) or
        classToken
end

local function GetClassTextColor(unit, frame)
    if frame and frame.TestValues and frame.TestValues.classToken and (FocalPoint.guiTestModeEnabled or frame.IsTemplatePreview) then
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

local function GetClassificationText(unit)
    if not unit or not UnitClassification then
        return ""
    end

    local classification = UnitClassification(unit)
    if type(classification) ~= "string" or classification == "" or classification == "normal" then
        return ""
    end

    if classification == "worldboss" then
        return BOSS or "Boss"
    elseif classification == "elite" then
        return ELITE or "Elite"
    elseif classification == "rareelite" then
        if ITEM_QUALITY3_DESC and ELITE then
            return ITEM_QUALITY3_DESC .. " " .. ELITE
        end
        return "Rare Elite"
    elseif classification == "rare" then
        return ITEM_QUALITY3_DESC or "Rare"
    elseif classification == "trivial" then
        return MINIMAP_TRACKING_TRIVIAL_QUESTS or "Trivial"
    end

    return classification
end

local function GetRoleText(unit)
    if not unit or not UnitGroupRolesAssigned then
        return ""
    end

    local role = UnitGroupRolesAssigned(unit)
    if type(role) ~= "string" or role == "" or role == "NONE" then
        return ""
    end

    if role == "TANK" then
        return TANK or "Tank"
    elseif role == "HEALER" then
        return HEALER or "Healer"
    elseif role == "DAMAGER" then
        return DAMAGER or "Damager"
    end

    return role
end

local function ClampColorComponent(value)
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

local function BuildColorCode(r, g, b, a)
    return string.format(
        "|c%02x%02x%02x%02x",
        ClampColorComponent(a == nil and 1 or a),
        ClampColorComponent(r),
        ClampColorComponent(g),
        ClampColorComponent(b)
    )
end

local function GetPowerTextColor(unit, frame)
    if frame and frame.TestValues and frame.TestValues.powerToken and (FocalPoint.guiTestModeEnabled or frame.IsTemplatePreview) then
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

local function GetReactionTextColor(unit, frame)
    if frame and frame.TestValues and (FocalPoint.guiTestModeEnabled or frame.IsTemplatePreview) then
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

local function GetBlizzardNamedColor(colorName)
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

    return BuildColorCode(color.r or color[1], color.g or color[2], color.b or color[3], color.a or color[4] or 1)
end

local function GetExplicitColorCode(value)
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

local function ResolveColorTag(frame, unit, token, fallbackColor)
    if token == "rc" or token == "resetcolor" then
        if type(fallbackColor) == "table" then
            local r, g, b, a = UnpackColor(fallbackColor, { 1, 1, 1, 1 })
            return BuildColorCode(r, g, b, a)
        end
        return "|r"
    end

    if token == "classcolor" or token == "raidcolor" then
        local r, g, b, a = GetClassTextColor(unit, frame)
        if r and g and b then
            return BuildColorCode(r, g, b, a)
        end
        return nil
    end

    if token == "powercolor" then
        local r, g, b, a = GetPowerTextColor(unit, frame)
        if r and g and b then
            return BuildColorCode(r, g, b, a)
        end
        return nil
    end

    local colorValue = type(token) == "string" and token:match("^color:(.+)$") or nil
    if colorValue then
        colorValue = colorValue:lower()

        if colorValue == "class" or colorValue == "raid" then
            local r, g, b, a = GetClassTextColor(unit, frame)
            if r and g and b then
                return BuildColorCode(r, g, b, a)
            end
            return nil
        end

        if colorValue == "blizz_pwr" then
            local r, g, b, a = GetPowerTextColor(unit, frame)
            if r and g and b then
                return BuildColorCode(r, g, b, a)
            end
            return nil
        end

        if colorValue == "reaction" then
            local r, g, b, a = GetReactionTextColor(unit, frame)
            if r and g and b then
                return BuildColorCode(r, g, b, a)
            end
            return nil
        end

        local blizzardKey = colorValue:match("^blizz_(.+)$")
        if blizzardKey then
            return GetBlizzardNamedColor(blizzardKey)
        end

        local explicitColor = GetExplicitColorCode(colorValue)
        if explicitColor then
            return explicitColor
        end
    end

    local explicitColor = GetExplicitColorCode(token)
    if explicitColor then
        return explicitColor
    end

    local blizzardColor = type(token) == "string" and token:match("^blizz:([%w_]+)$") or nil
    if blizzardColor then
        return GetBlizzardNamedColor(blizzardColor)
    end

    return nil
end

local function GetTextLayerParent(frame)
    if not frame then
        return nil
    end

    if frame.TextLayerParent then
        return frame.TextLayerParent
    end

    local holder = CreateFrame("Frame", nil, frame)
    holder:SetAllPoints(frame)
    holder:SetFrameStrata(frame:GetFrameStrata())
    holder:SetFrameLevel(frame:GetFrameLevel() + 30)

    frame.TextLayerParent = holder
    return holder
end

local function BuildFontFlags(config)
    local flags = {}

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

local function FormatNumber(value)
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

local function FormatInteger(value)
    if value == nil then
        return "0"
    end

    local ok, result = pcall(string.format, "%d", value)
    if ok and type(result) == "string" then
        return result
    end

    return "0"
end

local function FormatTextValue(value)
    if type(value) == "string" then
        return value
    end

    return FormatInteger(value)
end

local function FormatTimeValue(value)
    if type(value) ~= "number" then
        return ""
    end

    if value < 0 then
        value = 0
    end

    return string.format("%.1f", value)
end

local function IsSafeTrue(value)
    if type(value) == "boolean" and not (issecretvalue and issecretvalue(value)) then
        return value
    end

    return false
end

local function ToSafeNumber(value)
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

local function GetLiveValue(frame, key, fallback)
    if frame and frame.LiveValues and frame.LiveValues[key] ~= nil then
        return frame.LiveValues[key]
    end

    return fallback
end

local SECONDARY_POWER_BAR_SPECS = {
    [258] = 0, -- Shadow Priest -> Mana
    [262] = 0, -- Elemental Shaman -> Mana
}

local function GetPlayerSpecializationID()
    if not GetSpecialization or not GetSpecializationInfo then
        return nil
    end

    local specializationIndex = GetSpecialization()
    if not specializationIndex then
        return nil
    end

    local specializationID = GetSpecializationInfo(specializationIndex)
    if type(specializationID) ~= "number" then
        return nil
    end

    return specializationID
end

local function GetSecondaryPowerTypeForUnit(unit)
    if unit ~= "player" then
        return nil
    end

    local specializationID = GetPlayerSpecializationID()
    if not specializationID then
        return nil
    end

    return SECONDARY_POWER_BAR_SPECS[specializationID]
end

local function GetSecondaryPowerValues(unit)
    local secondaryPowerType = GetSecondaryPowerTypeForUnit(unit)
    if secondaryPowerType == nil or not UnitPower or not UnitPowerMax then
        return nil, 0, 0
    end

    return secondaryPowerType, UnitPower(unit, secondaryPowerType) or 0, UnitPowerMax(unit, secondaryPowerType) or 0
end

local function GetSecondaryPowerDisplayValues(unit)
    local secondaryPowerType, currentValue, maxValue = GetSecondaryPowerValues(unit)
    if secondaryPowerType == nil then
        return nil, "0", "0", 0
    end

    local currentTextOk, currentText = pcall(tostring, currentValue)
    local maxTextOk, maxText = pcall(tostring, maxValue)

    if not currentTextOk or type(currentText) ~= "string" then
        currentText = "0"
    end

    if not maxTextOk or type(maxText) ~= "string" then
        maxText = "0"
    end

    local maxNumberOk, maxNumber = pcall(tonumber, maxText)
    if not maxNumberOk or type(maxNumber) ~= "number" then
        maxNumber = 0
    end

    return secondaryPowerType, currentText, maxText, maxNumber
end

function UF:RefreshLiveValues(frame)
    if not frame or not frame.unit then
        return
    end

    frame.LiveValues = frame.LiveValues or {}

    if FocalPoint.guiTestModeEnabled and frame.TestValues then
        local preview = frame.TestValues
        local healthCurrent = preview.healthCurrent or 100
        local healthMax = preview.healthMax or 100
        local powerCurrent = preview.powerCurrent or 65
        local powerMax = preview.powerMax or 100
        local altPowerCurrent = preview.altPowerCurrent or 0
        local altPowerMax = preview.altPowerMax or 0

        frame.LiveValues.healthCurrent = healthCurrent
        frame.LiveValues.healthMax = healthMax
        frame.LiveValues.healthCurrentText = FormatNumber(healthCurrent)
        frame.LiveValues.healthMaxText = FormatNumber(healthMax)
        frame.LiveValues.healthCurrentSafe = ToSafeNumber(healthCurrent)
        frame.LiveValues.healthMaxSafe = ToSafeNumber(healthMax)
        frame.LiveValues.healthPercentValue = healthMax > 0 and math.floor((healthCurrent / healthMax) * 100) or 0
        frame.LiveValues.healthPercentText = FormatInteger(frame.LiveValues.healthPercentValue)
        frame.LiveValues.healthCurrentRaw = healthCurrent
        frame.LiveValues.healthMaxRaw = healthMax

        frame.LiveValues.powerCurrent = powerCurrent
        frame.LiveValues.powerMax = powerMax
        frame.LiveValues.powerCurrentText = FormatNumber(powerCurrent)
        frame.LiveValues.powerMaxText = FormatNumber(powerMax)
        frame.LiveValues.powerCurrentSafe = ToSafeNumber(powerCurrent)
        frame.LiveValues.powerMaxSafe = ToSafeNumber(powerMax)
        frame.LiveValues.powerCurrentRaw = powerCurrent
        frame.LiveValues.powerMaxRaw = powerMax
        frame.LiveValues.powerPercentValue = powerMax > 0 and math.floor((powerCurrent / powerMax) * 100) or 0
        frame.LiveValues.powerPercentText = FormatInteger(frame.LiveValues.powerPercentValue)

        frame.LiveValues.altPowerCurrent = altPowerCurrent
        frame.LiveValues.altPowerMax = altPowerMax
        frame.LiveValues.altPowerCurrentText = FormatNumber(altPowerCurrent)
        frame.LiveValues.altPowerMaxText = FormatNumber(altPowerMax)
        frame.LiveValues.altPowerCurrentSafe = ToSafeNumber(altPowerCurrent)
        frame.LiveValues.altPowerMaxSafe = ToSafeNumber(altPowerMax)
        frame.LiveValues.altPowerCurrentRaw = altPowerCurrent
        frame.LiveValues.altPowerMaxRaw = altPowerMax
        return
    end

    local unit = frame.unit
    local healthCurrent = UnitHealth and UnitHealth(unit) or 0
    local healthMax = UnitHealthMax and UnitHealthMax(unit) or 0
    local healthPercent = UnitHealthPercent and UnitHealthPercent(unit, true, CurveConstants and CurveConstants.ScaleTo100) or 0
    local powerCurrent = UnitPower and UnitPower(unit) or 0
    local powerMax = UnitPowerMax and UnitPowerMax(unit) or 0
    local altPowerCurrent = 0
    local altPowerMax = 0
    local healthBar = frame.Elements and frame.Elements.HealthBar
    local powerBar = frame.Elements and frame.Elements.PowerBar
    local alternativePowerBar = frame.Elements and frame.Elements.AlternativePowerBar
    local healthBarCurrent = healthBar and healthBar.GetValue and healthBar:GetValue() or nil
    local powerBarCurrent = powerBar and powerBar.GetValue and powerBar:GetValue() or nil
    local alternativePowerBarCurrent = alternativePowerBar and alternativePowerBar.GetValue and alternativePowerBar:GetValue() or nil
    local healthBarMax = nil
    local powerBarMax = nil
    local alternativePowerBarMax = nil

    if healthBar and healthBar.GetMinMaxValues then
        local _, maxValue = healthBar:GetMinMaxValues()
        healthBarMax = maxValue
    end

    if powerBar and powerBar.GetMinMaxValues then
        local _, maxValue = powerBar:GetMinMaxValues()
        powerBarMax = maxValue
    end

    if alternativePowerBar and alternativePowerBar.GetMinMaxValues then
        local _, maxValue = alternativePowerBar:GetMinMaxValues()
        alternativePowerBarMax = maxValue
    end

    local secondaryPowerType = GetSecondaryPowerTypeForUnit(frame.unit)

    if secondaryPowerType ~= nil then
        secondaryPowerType, altPowerCurrent, altPowerMax = GetSecondaryPowerValues(unit)
    end

    frame.LiveValues.healthCurrent = healthCurrent
    frame.LiveValues.healthMax = healthMax
    frame.LiveValues.healthCurrentText = FormatNumber(healthCurrent)
    frame.LiveValues.healthMaxText = FormatNumber(healthMax)
    frame.LiveValues.healthCurrentSafe = ToSafeNumber(healthBarCurrent)
    if frame.LiveValues.healthCurrentSafe <= 0 then
        frame.LiveValues.healthCurrentSafe = ToSafeNumber(healthCurrent)
    end
    frame.LiveValues.healthMaxSafe = ToSafeNumber(healthBarMax)
    if frame.LiveValues.healthMaxSafe <= 0 then
        frame.LiveValues.healthMaxSafe = ToSafeNumber(healthMax)
    end
    frame.LiveValues.healthPercentText = FormatInteger(healthPercent)
    frame.LiveValues.healthPercentValue = 0
    if frame.LiveValues.healthMaxSafe > 0 and frame.LiveValues.healthCurrentSafe >= 0 then
        frame.LiveValues.healthPercentValue = math.floor((frame.LiveValues.healthCurrentSafe / frame.LiveValues.healthMaxSafe) * 100)
    end
    if frame.LiveValues.healthPercentValue <= 0 then
        frame.LiveValues.healthPercentValue = ToSafeNumber(healthPercent)
    end

    frame.LiveValues.powerCurrent = powerCurrent
    frame.LiveValues.powerMax = powerMax
    frame.LiveValues.powerCurrentText = FormatNumber(powerCurrent)
    frame.LiveValues.powerMaxText = FormatNumber(powerMax)
    frame.LiveValues.powerCurrentSafe = ToSafeNumber(powerBarCurrent)
    if frame.LiveValues.powerCurrentSafe <= 0 then
        frame.LiveValues.powerCurrentSafe = ToSafeNumber(powerCurrent)
    end
    frame.LiveValues.powerMaxSafe = ToSafeNumber(powerBarMax)
    if frame.LiveValues.powerMaxSafe <= 0 then
        frame.LiveValues.powerMaxSafe = ToSafeNumber(powerMax)
    end
    frame.LiveValues.powerPercentValue = 0
    if frame.LiveValues.powerMaxSafe > 0 and frame.LiveValues.powerCurrentSafe >= 0 then
        frame.LiveValues.powerPercentValue = math.floor((frame.LiveValues.powerCurrentSafe / frame.LiveValues.powerMaxSafe) * 100)
    end
    frame.LiveValues.powerPercentText = FormatInteger(frame.LiveValues.powerPercentValue)

    local altPowerCurrentSafe = ToSafeNumber(altPowerCurrent)
    local altPowerMaxSafe = ToSafeNumber(altPowerMax)
    local alternativePowerBarCurrentSafe = ToSafeNumber(alternativePowerBarCurrent)
    local alternativePowerBarMaxSafe = ToSafeNumber(alternativePowerBarMax)

    frame.LiveValues.altPowerCurrent = altPowerCurrentSafe
    if frame.LiveValues.altPowerCurrent <= 0 and alternativePowerBarCurrentSafe > 0 then
        frame.LiveValues.altPowerCurrent = alternativePowerBarCurrentSafe
    end

    frame.LiveValues.altPowerMax = altPowerMaxSafe
    if frame.LiveValues.altPowerMax <= 0 and alternativePowerBarMaxSafe > 0 then
        frame.LiveValues.altPowerMax = alternativePowerBarMaxSafe
    end
    frame.LiveValues.altPowerCurrentText = FormatNumber(frame.LiveValues.altPowerCurrent)
    frame.LiveValues.altPowerMaxText = FormatNumber(frame.LiveValues.altPowerMax)
    frame.LiveValues.altPowerCurrentSafe = ToSafeNumber(frame.LiveValues.altPowerCurrent)
    frame.LiveValues.altPowerMaxSafe = ToSafeNumber(frame.LiveValues.altPowerMax)
    frame.LiveValues.altPowerCurrentRaw = frame.LiveValues.altPowerCurrent
    frame.LiveValues.altPowerMaxRaw = frame.LiveValues.altPowerMax
    frame.LiveValues.altPowerType = secondaryPowerType
    frame.LiveValues.altPowerVisible = secondaryPowerType ~= nil and frame.LiveValues.altPowerMaxSafe > 0
end

local TOKEN_DEFS = {
    ["hp:cur"] = {
        value = function(unit, frame)
            return GetLiveValue(frame, "healthCurrentText", GetLiveValue(frame, "healthCurrentRaw", "0"))
        end,
        format = FormatTextValue,
        direct = true,
    },
    ["hp:max"] = {
        value = function(unit, frame)
            return GetLiveValue(frame, "healthMaxText", GetLiveValue(frame, "healthMaxRaw", "0"))
        end,
        format = FormatTextValue,
        direct = true,
    },
    ["hp:cur:abbr"] = {
        value = function(unit, frame)
            return GetLiveValue(frame, "healthCurrentAbbr", "")
        end,
        format = FormatTextValue,
        direct = true,
    },
    ["hp:cur:short"] = {
        value = function(unit, frame)
            return GetLiveValue(frame, "healthCurrentAbbr", "")
        end,
        format = FormatTextValue,
        direct = true,
    },
    ["hp:max:abbr"] = {
        value = function(unit, frame)
            return GetLiveValue(frame, "healthMaxAbbr", "")
        end,
        format = FormatTextValue,
        direct = true,
    },
    ["hp:max:short"] = {
        value = function(unit, frame)
            return GetLiveValue(frame, "healthMaxAbbr", "")
        end,
        format = FormatTextValue,
        direct = true,
    },
    ["hp:perc"] = {
        value = function(unit, frame)
            return GetLiveValue(frame, "healthPercentText", "0")
        end,
        format = FormatTextValue,
        direct = true,
    },
    ["power:cur"] = {
        value = function(unit, frame)
            return GetLiveValue(frame, "powerCurrentText", GetLiveValue(frame, "powerCurrentRaw", "0"))
        end,
        format = FormatTextValue,
        direct = true,
    },
    ["power:max"] = {
        value = function(unit, frame)
            return GetLiveValue(frame, "powerMaxText", GetLiveValue(frame, "powerMaxRaw", "0"))
        end,
        format = FormatTextValue,
        direct = true,
    },
    ["power:perc"] = {
        value = function(unit, frame)
            return GetLiveValue(frame, "powerPercentText", "0")
        end,
        format = FormatTextValue,
        direct = true,
    },
    ["power:cur:abbr"] = {
        value = function(unit, frame)
            return GetLiveValue(frame, "powerCurrentAbbr", "")
        end,
        format = FormatTextValue,
        direct = true,
    },
    ["power:cur:short"] = {
        value = function(unit, frame)
            return GetLiveValue(frame, "powerCurrentAbbr", "")
        end,
        format = FormatTextValue,
        direct = true,
    },
    ["power:max:abbr"] = {
        value = function(unit, frame)
            return GetLiveValue(frame, "powerMaxAbbr", "")
        end,
        format = FormatTextValue,
        direct = true,
    },
    ["power:max:short"] = {
        value = function(unit, frame)
            return GetLiveValue(frame, "powerMaxAbbr", "")
        end,
        format = FormatTextValue,
        direct = true,
    },
    ["altpower:cur"] = {
        value = function(unit, frame)
            return GetLiveValue(frame, "altPowerCurrentText", GetLiveValue(frame, "altPowerCurrentRaw", "0"))
        end,
        format = FormatTextValue,
        direct = true,
    },
    ["altPower:cur"] = {
        value = function(unit, frame)
            return GetLiveValue(frame, "altPowerCurrentText", GetLiveValue(frame, "altPowerCurrentRaw", "0"))
        end,
        format = FormatTextValue,
        direct = true,
    },
    ["altpower:max"] = {
        value = function(unit, frame)
            return GetLiveValue(frame, "altPowerMaxText", GetLiveValue(frame, "altPowerMaxRaw", "0"))
        end,
        format = FormatTextValue,
        direct = true,
    },
    ["altPower:max"] = {
        value = function(unit, frame)
            return GetLiveValue(frame, "altPowerMaxText", GetLiveValue(frame, "altPowerMaxRaw", "0"))
        end,
        format = FormatTextValue,
        direct = true,
    },
    ["altpower:cur:abbr"] = {
        value = function(unit, frame)
            return GetLiveValue(frame, "altPowerCurrentAbbr", "")
        end,
        format = FormatTextValue,
        direct = true,
    },
    ["altpower:max:abbr"] = {
        value = function(unit, frame)
            return GetLiveValue(frame, "altPowerMaxAbbr", "")
        end,
        format = FormatTextValue,
        direct = true,
    },
    ["curhp"] = {
        value = function(unit, frame)
            return GetLiveValue(frame, "healthCurrentText", GetLiveValue(frame, "healthCurrentRaw", "0"))
        end,
        format = FormatTextValue,
        direct = true,
    },
    ["maxhp"] = {
        value = function(unit, frame)
            return GetLiveValue(frame, "healthMaxText", GetLiveValue(frame, "healthMaxRaw", "0"))
        end,
        format = FormatTextValue,
        direct = true,
    },
    ["curhp:abbr"] = {
        value = function(unit, frame)
            return GetLiveValue(frame, "healthCurrentAbbr", "")
        end,
        format = FormatTextValue,
        direct = true,
    },
    ["maxhp:abbr"] = {
        value = function(unit, frame)
            return GetLiveValue(frame, "healthMaxAbbr", "")
        end,
        format = FormatTextValue,
        direct = true,
    },
    ["perhp"] = {
        value = function(unit, frame)
            return GetLiveValue(frame, "healthPercentText", "0")
        end,
        format = FormatTextValue,
        direct = true,
    },
    ["curpp"] = {
        value = function(unit, frame)
            return GetLiveValue(frame, "powerCurrentText", GetLiveValue(frame, "powerCurrentRaw", "0"))
        end,
        format = FormatTextValue,
        direct = true,
    },
    ["maxpp"] = {
        value = function(unit, frame)
            return GetLiveValue(frame, "powerMaxText", GetLiveValue(frame, "powerMaxRaw", "0"))
        end,
        format = FormatTextValue,
        direct = true,
    },
    ["curpp:abbr"] = {
        value = function(unit, frame)
            return GetLiveValue(frame, "powerCurrentAbbr", "")
        end,
        format = FormatTextValue,
        direct = true,
    },
    ["maxpp:abbr"] = {
        value = function(unit, frame)
            return GetLiveValue(frame, "powerMaxAbbr", "")
        end,
        format = FormatTextValue,
        direct = true,
    },
}

local TAG_DATABASE = {
    { token = "[color:class]", category = "INFO_TAG_CATEGORY_FORMAT", description = "INFO_TAG_DESC_COLOR_CLASS", example = "[color:class][name][rc]" },
    { token = "[color:blizz_pwr]", category = "INFO_TAG_CATEGORY_FORMAT", description = "INFO_TAG_DESC_COLOR_BLIZZ_PWR", example = "[color:blizz_pwr][power:cur][rc]" },
    { token = "[color:reaction]", category = "INFO_TAG_CATEGORY_FORMAT", description = "INFO_TAG_DESC_COLOR_REACTION", example = "[color:reaction][name][rc]" },
    { token = "[color:blizz_yellow]", category = "INFO_TAG_CATEGORY_FORMAT", description = "INFO_TAG_DESC_COLOR_BLIZZ", example = "[color:blizz_yellow]Text[rc]" },
    { token = "[color:blizz_red]", category = "INFO_TAG_CATEGORY_FORMAT", description = "INFO_TAG_DESC_COLOR_BLIZZ", example = "[color:blizz_red]Text[rc]" },
    { token = "[color:blizz_green]", category = "INFO_TAG_CATEGORY_FORMAT", description = "INFO_TAG_DESC_COLOR_BLIZZ", example = "[color:blizz_green]Text[rc]" },
    { token = "[color:blizz_highlight]", category = "INFO_TAG_CATEGORY_FORMAT", description = "INFO_TAG_DESC_COLOR_BLIZZ", example = "[color:blizz_highlight]Text[rc]" },
    { token = "[color:ffcc00]", category = "INFO_TAG_CATEGORY_FORMAT", description = "INFO_TAG_DESC_COLOR_EXPLICIT", example = "[color:ffcc00]Text[rc]" },
    { token = "[rc]", category = "INFO_TAG_CATEGORY_FORMAT", description = "INFO_TAG_DESC_COLOR_RESET", example = "[rc]" },
    { token = "[hp:cur]", category = "INFO_TAG_CATEGORY_HEALTH", description = "INFO_TAG_DESC_HP_CUR", example = "154320" },
    { token = "[hp:max]", category = "INFO_TAG_CATEGORY_HEALTH", description = "INFO_TAG_DESC_HP_MAX", example = "154320" },
    { token = "[hp:cur:abbr]", category = "INFO_TAG_CATEGORY_HEALTH", description = "INFO_TAG_DESC_HP_CUR_ABBR", example = "154k" },
    { token = "[hp:max:abbr]", category = "INFO_TAG_CATEGORY_HEALTH", description = "INFO_TAG_DESC_HP_MAX_ABBR", example = "154k" },
    { token = "[hp:perc]", category = "INFO_TAG_CATEGORY_HEALTH", description = "INFO_TAG_DESC_HP_PERC", example = "100" },
    { token = "[power:cur]", category = "INFO_TAG_CATEGORY_POWER", description = "INFO_TAG_DESC_POWER_CUR", example = "100" },
    { token = "[power:max]", category = "INFO_TAG_CATEGORY_POWER", description = "INFO_TAG_DESC_POWER_MAX", example = "100" },
    { token = "[power:cur:abbr]", category = "INFO_TAG_CATEGORY_POWER", description = "INFO_TAG_DESC_POWER_CUR_ABBR", example = "100" },
    { token = "[power:max:abbr]", category = "INFO_TAG_CATEGORY_POWER", description = "INFO_TAG_DESC_POWER_MAX_ABBR", example = "100" },
    { token = "[power:perc]", category = "INFO_TAG_CATEGORY_POWER", description = "INFO_TAG_DESC_POWER_PERC", example = "100" },
    { token = "[altpower:cur]", category = "INFO_TAG_CATEGORY_POWER", description = "INFO_TAG_DESC_POWER_CUR", example = "72" },
    { token = "[altpower:max]", category = "INFO_TAG_CATEGORY_POWER", description = "INFO_TAG_DESC_POWER_MAX", example = "100" },
    { token = "[altpower:cur:abbr]", category = "INFO_TAG_CATEGORY_POWER", description = "INFO_TAG_DESC_POWER_CUR_ABBR", example = "72" },
    { token = "[altpower:max:abbr]", category = "INFO_TAG_CATEGORY_POWER", description = "INFO_TAG_DESC_POWER_MAX_ABBR", example = "100" },
    { token = "[cast:name]", category = "INFO_TAG_CATEGORY_CAST", description = "INFO_TAG_DESC_CAST_NAME", example = "Frostbolt" },
    { token = "[cast:time]", category = "INFO_TAG_CATEGORY_CAST", description = "INFO_TAG_DESC_CAST_TIME", example = "1.8" },
    { token = "[name]", category = "INFO_TAG_CATEGORY_UNIT", description = "INFO_TAG_DESC_NAME", example = "FocalPoint" },
    { token = "[guild]", category = "INFO_TAG_CATEGORY_UNIT", description = "INFO_TAG_DESC_GUILD", example = "Guild Name" },
    { token = "[realm]", category = "INFO_TAG_CATEGORY_UNIT", description = "INFO_TAG_DESC_REALM", example = "Lordaeron" },
    { token = "[level]", category = "INFO_TAG_CATEGORY_UNIT", description = "INFO_TAG_DESC_LEVEL", example = "80" },
    { token = "[class]", category = "INFO_TAG_CATEGORY_UNIT", description = "INFO_TAG_DESC_CLASS", example = "Warrior" },
    { token = "[race]", category = "INFO_TAG_CATEGORY_UNIT", description = "INFO_TAG_DESC_RACE", example = "Human" },
    { token = "[classification]", category = "INFO_TAG_CATEGORY_UNIT", description = "INFO_TAG_DESC_CLASSIFICATION", example = "Elite" },
    { token = "[family]", category = "INFO_TAG_CATEGORY_UNIT", description = "INFO_TAG_DESC_FAMILY", example = "Wolf" },
    { token = "[type]", category = "INFO_TAG_CATEGORY_UNIT", description = "INFO_TAG_DESC_TYPE", example = "Humanoid" },
    { token = "[creature]", category = "INFO_TAG_CATEGORY_UNIT", description = "INFO_TAG_DESC_CREATURE", example = "Humanoid" },
    { token = "[status]", category = "INFO_TAG_CATEGORY_STATUS", description = "INFO_TAG_DESC_STATUS", example = "AFK" },
    { token = "[afk]", category = "INFO_TAG_CATEGORY_STATUS", description = "INFO_TAG_DESC_AFK", example = "AFK" },
    { token = "[dnd]", category = "INFO_TAG_CATEGORY_STATUS", description = "INFO_TAG_DESC_DND", example = "DND" },
    { token = "[dead]", category = "INFO_TAG_CATEGORY_STATUS", description = "INFO_TAG_DESC_DEAD", example = "Dead" },
    { token = "[offline]", category = "INFO_TAG_CATEGORY_STATUS", description = "INFO_TAG_DESC_OFFLINE", example = "Offline" },
    { token = "[pvp]", category = "INFO_TAG_CATEGORY_STATUS", description = "INFO_TAG_DESC_PVP", example = "PvP" },
    { token = "[combat]", category = "INFO_TAG_CATEGORY_STATUS", description = "INFO_TAG_DESC_COMBAT", example = "Combat" },
    { token = "[resting]", category = "INFO_TAG_CATEGORY_STATUS", description = "INFO_TAG_DESC_RESTING", example = "Resting" },
    { token = "[leader]", category = "INFO_TAG_CATEGORY_STATUS", description = "INFO_TAG_DESC_LEADER", example = "Leader" },
    { token = "[role]", category = "INFO_TAG_CATEGORY_STATUS", description = "INFO_TAG_DESC_ROLE", example = "Tank" },
}

function UF:GetTagDatabase()
    return TAG_DATABASE
end

local function GetTagPreviewFallback(token)
    local previewFrame = {
        IsTemplatePreview = true,
        TestValues = {
            classToken = "WARRIOR",
            powerToken = "RAGE",
            reaction = 5,
        },
    }

    local colorToken = ResolveColorTag(previewFrame, "player", token)
    if type(colorToken) == "string" then
        return colorToken
    end

    for _, def in ipairs(TAG_DATABASE) do
        if def.token == "[" .. token .. "]" then
            return def.example or "[" .. token .. "]"
        end
    end

    return "[" .. token .. "]"
end

local function ResolveToken(frame, unit, token)
    if not FocalPoint.guiTestModeEnabled and (not unit or not UnitExists or not UnitExists(unit)) then
        local colorToken = ResolveColorTag(frame, unit, token)
        if colorToken ~= nil then
            return colorToken
        end
        return ""
    end

    local colorToken = ResolveColorTag(frame, unit, token)
    if colorToken ~= nil then
        return colorToken
    end

    local def = TOKEN_DEFS[token]
    if not def then
        return nil
    end

    local value = def.value and def.value(unit, frame) or nil
    local formatter = def.format or FormatNumber
    return formatter(value)
end

local function ResolveBasicTag(frame, unit, token)
    if FocalPoint.guiTestModeEnabled and frame and frame.TestValues then
        local preview = frame.TestValues

        if token == "name" then
            return preview.name or ""
        end

        if token == "level" then
            return preview.level and tostring(preview.level) or ""
        end

        if token == "class" then
            return preview.className or GetLocalizedClassName(preview.classToken) or ""
        end

        if token == "race" then
            return preview.race or ""
        end

        if token == "classification" then
            return preview.classification or ""
        end

        if token == "guild" then
            return preview.guild or ""
        end

        if token == "realm" then
            return preview.realm or ""
        end

        if token == "family" then
            return preview.family or preview.creature or ""
        end

        if token == "type" then
            return preview.type or preview.creature or ""
        end

        if token == "creature" then
            return preview.creature or preview.race or ""
        end

        if token == "status" then
            return preview.status or ""
        end

        if token == "afk" then
            return preview.afk or ""
        end

        if token == "dnd" then
            return preview.dnd or ""
        end

        if token == "dead" then
            return preview.dead or ""
        end

        if token == "offline" then
            return preview.offline or ""
        end

        if token == "pvp" then
            return preview.pvp or ""
        end

        if token == "combat" then
            return preview.combat or ""
        end

        if token == "resting" then
            return preview.resting or ""
        end

        if token == "leader" then
            return preview.leader or ""
        end

        if token == "role" then
            return preview.role or ""
        end

        if token == "cast:name" then
            return preview.castName or ""
        end

        if token == "cast:time" then
            local castBar = frame.Elements and frame.Elements.CastBar
            local now = GetTime and GetTime() or 0
            if castBar and castBar.isCasting and type(castBar.endTime) == "number" then
                return FormatTimeValue(math.max(castBar.endTime - now, 0))
            end

            return type(preview.castDuration) == "number" and FormatTimeValue(preview.castDuration) or ""
        end

        if token == "powercolor" or token == "raidcolor" or token == "resetcolor" or token == "classcolor" or token == "rc" then
            local colorToken = ResolveColorTag(frame, unit, token)
            if colorToken ~= nil then
                return colorToken
            end
            return ""
        end

        if token == "lasthit" then
            return preview.lastHit or ""
        end
    end

    if token == "name" then
        if unit and UnitName then
            return UnitName(unit) or ""
        end

        return ""
    end

    if token == "level" then
        if unit and UnitLevel then
            local level = UnitLevel(unit)
            if type(level) == "number" and level > 0 then
                return tostring(level)
            end

             if type(level) == "number" and level == -1 then
                return "??"
            end
        end

        return ""
    end

    if token == "class" then
        if unit and UnitClass then
            local className, classToken = UnitClass(unit)
            if UnitIsPlayer and UnitIsPlayer(unit) and type(className) == "string" and className ~= "" then
                return className
            end

            if not UnitIsPlayer or not UnitIsPlayer(unit) then
                local localized = GetLocalizedClassName(classToken)

                if type(localized) == "string" and localized ~= "" then
                    return localized
                end

                if type(classToken) == "string" and classToken ~= "" then
                    return classToken
                end
            end
        end

        return ""
    end

    if token == "race" then
        if unit and UnitIsPlayer and UnitIsPlayer(unit) and UnitRace then
            local raceName = UnitRace(unit)
            if type(raceName) == "string" then
                return raceName
            end
        end

        return ""
    end

    if token == "classification" then
        return GetClassificationText(unit)
    end

    if token == "guild" then
        if unit and GetGuildInfo then
            local guildName = GetGuildInfo(unit)
            if type(guildName) == "string" then
                return guildName
            end
        end

        return ""
    end

    if token == "realm" then
        if unit and UnitFullName then
            local _, realmName = UnitFullName(unit)
            if type(realmName) == "string" then
                return realmName
            end
        end

        return ""
    end

    if token == "family" then
        if unit and UnitCreatureFamily then
            local creatureFamily = UnitCreatureFamily(unit)
            if type(creatureFamily) == "string" then
                return creatureFamily
            end
        end

        return ""
    end

    if token == "type" then
        if unit and UnitCreatureType then
            local creatureType = UnitCreatureType(unit)
            if type(creatureType) == "string" then
                return creatureType
            end
        end

        return ""
    end

    if token == "creature" then
        if unit and UnitCreatureFamily then
            local creatureFamily = UnitCreatureFamily(unit)
            if type(creatureFamily) == "string" then
                return creatureFamily
            end
        end

        if unit and UnitCreatureType then
            local creatureType = UnitCreatureType(unit)
            if type(creatureType) == "string" then
                return creatureType
            end
        end

        return ""
    end

    if token == "status" then
        if not unit then
            return ""
        end

        if UnitExists and not IsSafeTrue(UnitExists(unit)) then
            return ""
        end

        if UnitIsConnected and not IsSafeTrue(UnitIsConnected(unit)) then
            return PLAYER_OFFLINE or "Offline"
        end

        if UnitIsDeadOrGhost and IsSafeTrue(UnitIsDeadOrGhost(unit)) then
            if UnitIsGhost and IsSafeTrue(UnitIsGhost(unit)) then
                return DEAD or "Dead"
            end

            return DEAD or "Dead"
        end

        if UnitIsAFK and IsSafeTrue(UnitIsAFK(unit)) then
            return AFK or "AFK"
        end

        if UnitIsDND and IsSafeTrue(UnitIsDND(unit)) then
            return DND or "DND"
        end

        return ""
    end

    if token == "afk" then
        if UnitIsAFK and unit and IsSafeTrue(UnitIsAFK(unit)) then
            return AFK or "AFK"
        end

        return ""
    end

    if token == "dnd" then
        if UnitIsDND and unit and IsSafeTrue(UnitIsDND(unit)) then
            return DND or "DND"
        end

        return ""
    end

    if token == "dead" then
        if UnitIsDeadOrGhost and unit and IsSafeTrue(UnitIsDeadOrGhost(unit)) then
            return DEAD or "Dead"
        end

        return ""
    end

    if token == "offline" then
        if UnitIsConnected and unit and not IsSafeTrue(UnitIsConnected(unit)) then
            return PLAYER_OFFLINE or "Offline"
        end

        return ""
    end

    if token == "pvp" then
        if UnitIsPVP and unit and IsSafeTrue(UnitIsPVP(unit)) then
            return PVP or "PvP"
        end

        return ""
    end

    if token == "combat" then
        if UnitAffectingCombat and unit and IsSafeTrue(UnitAffectingCombat(unit)) then
            return COMBAT or "Combat"
        end

        return ""
    end

    if token == "resting" then
        if unit == "player" and IsResting and IsSafeTrue(IsResting()) then
            return PLAYER_STATUS_RESTING or "Resting"
        end

        return ""
    end

    if token == "leader" then
        if UnitIsGroupLeader and unit and IsSafeTrue(UnitIsGroupLeader(unit)) then
            return LEADER or "Leader"
        end

        return ""
    end

    if token == "role" then
        return GetRoleText(unit)
    end

    if token == "cast:name" then
        if not unit then
            return ""
        end

        if UnitExists and not UnitExists(unit) then
            return ""
        end

        if UnitCastingInfo then
            local castName = UnitCastingInfo(unit)
            if type(castName) == "string" then
                return castName
            end
        end

        if UnitChannelInfo then
            local channelName = UnitChannelInfo(unit)
            if type(channelName) == "string" then
                return channelName
            end
        end

        return ""
    end

    if token == "cast:time" then
        if not unit then
            return ""
        end

        if UnitExists and not UnitExists(unit) then
            return ""
        end

        local now = GetTime and GetTime() or 0
        local castBar = frame and frame.Elements and frame.Elements.CastBar

        if castBar and castBar.isCasting and type(castBar.endTime) == "number" then
            return FormatTimeValue(math.max(castBar.endTime - now, 0))
        end

        if unit == "player" and UnitCastingInfo then
            local _, _, _, startTimeMS, endTimeMS = UnitCastingInfo(unit)
            if type(startTimeMS) == "number" and type(endTimeMS) == "number" then
                local endTime = endTimeMS / 1000
                return FormatTimeValue(endTime - now)
            end
        end

        if unit == "player" and UnitChannelInfo then
            local _, _, _, startTimeMS, endTimeMS = UnitChannelInfo(unit)
            if type(startTimeMS) == "number" and type(endTimeMS) == "number" then
                local remaining = (endTimeMS / 1000) - now
                return FormatTimeValue(remaining)
            end
        end

        return ""
    end

    if token == "powercolor" or token == "raidcolor" or token == "resetcolor" or token == "classcolor" or token == "rc" then
        local colorToken = ResolveColorTag(frame, unit, token)
        if colorToken ~= nil then
            return colorToken
        end
        return ""
    end

    if token == "lasthit" then
        return ""
    end

    return ResolveToken(frame, unit, token)
end

local function HasActiveCast(unit)
    if FocalPoint.guiTestModeEnabled then
        return true
    end

    if not unit then
        return false
    end

    if UnitCastingInfo then
        local castName = UnitCastingInfo(unit)
        if type(castName) == "string" then
            return true
        end
    end

    if UnitChannelInfo then
        local channelName = UnitChannelInfo(unit)
        if type(channelName) == "string" then
            return true
        end
    end

    return false
end

local function FrameUsesCastTime(frame)
    if not frame or not frame.config or not frame.config.Texts then
        return false
    end

    local textConfig = frame.config.Texts.CastTime
    return type(textConfig) == "table" and textConfig.enabled ~= false
end

local function ResolveTextTemplate(frame, unit, template)
    if type(template) ~= "string" or template == "" then
        return ""
    end

    local result = {}
    local cursor = 1

    while true do
        local startPos, endPos, token = template:find("%[([^%]]+)%]", cursor)
        if not startPos then
            result[#result + 1] = template:sub(cursor)
            break
        end

        if startPos > cursor then
            result[#result + 1] = template:sub(cursor, startPos - 1)
        end

        local resolved = ResolveBasicTag(frame, unit, token)
        if resolved ~= nil then
            result[#result + 1] = type(resolved) == "string" and resolved or FormatNumber(resolved)
        else
            result[#result + 1] = "[" .. token .. "]"
        end

        cursor = endPos + 1
    end

    return table.concat(result)
end

local function TemplateContainsToken(template, token)
    if type(template) ~= "string" or template == "" then
        return false
    end

    return template:find("%[" .. token:gsub("([^%w:])", "%%%1") .. "%]") ~= nil
end

local function ResolveConfiguredTemplate(textConfig)
    if type(textConfig) ~= "table" then
        return ""
    end

    local templateName = textConfig.templateName
    local templates = FocalPoint.db and FocalPoint.db.profile and FocalPoint.db.profile.TextTemplates
    if type(templateName) == "string" and templateName ~= "" and type(templates) == "table" then
        local linkedTemplate = templates[templateName]
        if type(linkedTemplate) == "string" and linkedTemplate ~= "" then
            return linkedTemplate
        end
    end

    return textConfig.tag or ""
end

function UF:BuildTemplatePreview(template, unit)
    if type(template) ~= "string" or template == "" then
        return ""
    end

    local parts = {}
    local searchStart = 1

    while true do
        local tokenStart, tokenEnd, token = template:find("%[([^%]]+)%]", searchStart)
        if not tokenStart then
            parts[#parts + 1] = template:sub(searchStart)
            break
        end

        if tokenStart > searchStart then
            parts[#parts + 1] = template:sub(searchStart, tokenStart - 1)
        end

        parts[#parts + 1] = GetTagPreviewFallback(token)

        searchStart = tokenEnd + 1
    end

    return table.concat(parts)
end

local function ApplyDirectTemplate(frame, textObject, unit, template, fallbackColor)
    if not frame or not textObject then
        return false
    end

    if not FocalPoint.guiTestModeEnabled and (not unit or not UnitExists or not UnitExists(unit)) then
        return false
    end

    local formatString = template and template:gsub("%%", "%%%%") or ""
    local formatArgs = {}
    local hasToken = false

    for token in template:gmatch("%[([^%]]+)%]") do
        local resolved = ResolveColorTag(frame, unit, token, fallbackColor)
        if resolved == nil then
            resolved = ResolveBasicTag(frame, unit, token)
        end
        if resolved == nil then
            resolved = "[" .. token .. "]"
        elseif type(resolved) ~= "string" then
            resolved = FormatNumber(resolved)
        end

        formatArgs[#formatArgs + 1] = resolved
        hasToken = true
    end

    if not hasToken then
        return false
    end

    formatString = formatString:gsub("%[([^%]]+)%]", "%%s")
    textObject:SetFormattedText(formatString, unpack(formatArgs))
    return true
end

function UF:CreateTextElement(frame, key, textConfig)
    if not textConfig or textConfig.enabled == false then
        return
    end

    local parent = GetTextLayerParent(frame)
    local text = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    text:SetDrawLayer("OVERLAY", 7)
    text:SetWordWrap(false)
    text:SetJustifyV("MIDDLE")

    frame.Texts[key] = text
    frame.Tags[key] = textConfig.tag or ""
end

function UF:CreateTextElements(frame)
    local texts = frame.config.Texts
    if not texts then
        return
    end

    for key, textConfig in pairs(texts) do
        self:CreateTextElement(frame, key, textConfig)
    end
end

function UF:ApplyTextElementConfig(frame, key, textObject, textConfig)
    if not textObject or not textConfig then
        return
    end

    if textConfig.enabled == false then
        textObject:Hide()
        return
    end

    local anchorParent = self:GetAnchorTarget(frame, textConfig.anchorTo)
    local fontPath = GetFontPath(textConfig.font)
    local fontSize = textConfig.fontSize or 12
    local fontFlags = BuildFontFlags(textConfig)
    local justifyH = textConfig.justifyH or "CENTER"

    local r, g, b, a = UnpackColor(textConfig.color, { 1, 1, 1, 1 })
    local template = ResolveConfiguredTemplate(textConfig)

    if key == "Class" or TemplateContainsToken(template, "class") then
        local classR, classG, classB, classA = GetClassTextColor(frame.unit, frame)
        if classR and classG and classB then
            r, g, b, a = classR, classG, classB, classA or 1
        end
    elseif key == "Level" then
        r, g, b, a = 1.00, 0.82, 0.00, 1.00
    end

    textObject:ClearAllPoints()
    textObject:SetPoint(
        textConfig.point or "CENTER",
        anchorParent,
        textConfig.relativePoint or "CENTER",
        textConfig.offsetX or 0,
        textConfig.offsetY or 0
    )

    if textConfig.anchorTo == "CastBar" and anchorParent and anchorParent.GetWidth then
        local castBarWidth = anchorParent:GetWidth() or 0
        if key == "CastTime" then
            textObject:SetWidth(48)
        elseif key == "CastName" then
            textObject:SetWidth(math.max(castBarWidth - 56, 20))
        else
            textObject:SetWidth(0)
        end
    else
        textObject:SetWidth(0)
    end

    textObject:SetFont(fontPath, fontSize, fontFlags ~= "" and fontFlags or nil)
    textObject:SetTextColor(r, g, b, a)
    textObject:SetJustifyH(justifyH)

    if textConfig.shadowEnabled then
        local sx = textConfig.shadowOffsetX or 1
        local sy = textConfig.shadowOffsetY or -1
        local sr, sg, sb, sa = UnpackColor(textConfig.shadowColor, { 0, 0, 0, 1 })

        textObject:SetShadowOffset(sx, sy)
        textObject:SetShadowColor(sr, sg, sb, sa)
    else
        textObject:SetShadowOffset(0, 0)
        textObject:SetShadowColor(0, 0, 0, 0)
    end

    textObject:Show()
end

function UF:UpdateTextElement(frame, key)
    if not frame or not frame.Texts or not frame.Texts[key] then
        return
    end

    local textObject = frame.Texts[key]
    local textConfig = frame.config and frame.config.Texts and frame.config.Texts[key]
    if not textConfig or textConfig.enabled == false then
        textObject:SetText("")
        textObject:Hide()
        return
    end

    local template = ResolveConfiguredTemplate(textConfig)
    local r, g, b, a = UnpackColor(textConfig.color, { 1, 1, 1, 1 })
    local altPowerType = GetLiveValue(frame, "altPowerType", nil)
    local altPowerMaxRaw = ToSafeNumber(GetLiveValue(frame, "altPowerMaxRaw", 0))
    local altPowerCurrentRaw = ToSafeNumber(GetLiveValue(frame, "altPowerCurrentRaw", 0))
    local altPowerAvailable = altPowerType ~= nil and altPowerMaxRaw > 0

    if key == "AltPower" then
        textObject:SetTextColor(r, g, b, a)
        local livePowerType, liveCurrentText, liveMaxText, liveMaxNumber = GetSecondaryPowerDisplayValues(frame.unit)
        if livePowerType ~= nil and liveMaxNumber > 0 then
            textObject:SetText(liveCurrentText .. " / " .. liveMaxText)
            textObject:Show()
        elseif altPowerAvailable then
            textObject:SetText(FormatNumber(altPowerCurrentRaw) .. " / " .. FormatNumber(altPowerMaxRaw))
            textObject:Show()
        else
            textObject:SetText("")
        end
        return
    end

    if key == "Class" or TemplateContainsToken(template, "class") then
        local classR, classG, classB, classA = GetClassTextColor(frame.unit, frame)
        if classR and classG and classB then
            r, g, b, a = classR, classG, classB, classA or 1
        end
    elseif key == "Level" then
        r, g, b, a = 1.00, 0.82, 0.00, 1.00
    end
    textObject:SetTextColor(r, g, b, a)

    if ApplyDirectTemplate(frame, textObject, frame.unit, template, textConfig.color) then
        return
    end

    textObject:SetText(ResolveTextTemplate(frame, frame.unit, template))
end

function UF:UpdateTextElements(frame)
    if not frame or not frame.config or not frame.config.Texts then
        return
    end

    for key in pairs(frame.config.Texts) do
        self:UpdateTextElement(frame, key)
    end
end

function UF:RegisterTextEvents(frame)
    if not frame or frame.TextEventFrame then
        return
    end

    local eventFrame = CreateFrame("Frame", nil, frame)
    eventFrame.owner = frame
    eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    eventFrame:RegisterEvent("PLAYER_LEVEL_UP")
    eventFrame:RegisterEvent("PLAYER_FLAGS_CHANGED")
    eventFrame:RegisterEvent("UNIT_LEVEL")
    eventFrame:RegisterEvent("UNIT_FLAGS")
    eventFrame:RegisterEvent("UNIT_CONNECTION")
    eventFrame:RegisterEvent("UNIT_POWER_UPDATE")
    eventFrame:RegisterEvent("UNIT_MAXPOWER")
    eventFrame:RegisterEvent("UNIT_DISPLAYPOWER")
    eventFrame:RegisterEvent("UNIT_SPELLCAST_START")
    eventFrame:RegisterEvent("UNIT_SPELLCAST_STOP")
    eventFrame:RegisterEvent("UNIT_SPELLCAST_FAILED")
    eventFrame:RegisterEvent("UNIT_SPELLCAST_INTERRUPTED")
    eventFrame:RegisterEvent("UNIT_SPELLCAST_CHANNEL_START")
    eventFrame:RegisterEvent("UNIT_SPELLCAST_CHANNEL_STOP")
    eventFrame:RegisterEvent("UNIT_SPELLCAST_DELAYED")
    eventFrame:RegisterEvent("UNIT_SPELLCAST_CHANNEL_UPDATE")
    eventFrame.elapsed = 0

    if frame.unit == "target" then
        eventFrame:RegisterEvent("PLAYER_TARGET_CHANGED")
    elseif frame.unit == "focus" then
        eventFrame:RegisterEvent("PLAYER_FOCUS_CHANGED")
    elseif frame.unit == "pet" then
        eventFrame:RegisterEvent("UNIT_PET")
    end

    eventFrame:SetScript("OnUpdate", function(self, elapsed)
        local owner = self.owner
        local castBar = owner and owner.Elements and owner.Elements.CastBar
        local hasPreviewCast = FocalPoint.guiTestModeEnabled and castBar and castBar.isPreview
        if not owner or not FrameUsesCastTime(owner) or (not hasPreviewCast and not HasActiveCast(owner.unit)) then
            self.elapsed = 0
            return
        end

        self.elapsed = (self.elapsed or 0) + elapsed
        if self.elapsed < 0.05 then
            return
        end

        self.elapsed = 0
        if UF.RefreshCastBar then
            UF:RefreshCastBar(owner)
        end
        UF:UpdateTextElement(owner, "CastTime")
    end)

    eventFrame:SetScript("OnEvent", function(_, event, unit)
        local owner = eventFrame.owner
        if not owner then
            return
        end

        if event == "PLAYER_TARGET_CHANGED" or event == "PLAYER_FOCUS_CHANGED" then
            if UF.Refresh then
                UF:Refresh(owner)
            end
            return
        end

        if event == "UNIT_PET" then
            if owner.unit == "pet" and unit == "player" then
                if UF.Refresh then
                    UF:Refresh(owner)
                end
            end
            return
        end

        if event == "PLAYER_ENTERING_WORLD" and owner.unit ~= "player" then
            if UF.Refresh then
                UF:Refresh(owner)
            end
            return
        end

        if unit and unit ~= owner.unit then
            return
        end

        if event == "UNIT_HEALTH" or event == "UNIT_MAXHEALTH" then
            return
        end

        if UF.RefreshUnitBarValues then
            UF:RefreshUnitBarValues(owner)
        end
        if UF.ApplyConfig then
            UF:ApplyConfig(owner)
        end
        if UF.RefreshCastBar then
            UF:RefreshCastBar(owner)
        end
        UF:RefreshLiveValues(owner)
        UF:UpdateTextElements(owner)
        if UF.RefreshCastBar then
            UF:RefreshCastBar(owner)
        end
    end)

    frame.TextEventFrame = eventFrame
end

function UF:ApplyTestTextValues(frame)
    self:RefreshLiveValues(frame)
    self:UpdateTextElements(frame)
end
