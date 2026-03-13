local _, Portrait = ...

Portrait.UnitFrame = Portrait.UnitFrame or {}
local UF = Portrait.UnitFrame

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

local function GetClassTextColor(unit)
    if not unit or not UnitExists or not UnitExists(unit) or not UnitClass then
        return nil
    end

    local _, classToken = UnitClass(unit)
    if not classToken then
        return nil
    end

    local color = nil

    if CUSTOM_CLASS_COLORS and CUSTOM_CLASS_COLORS[classToken] then
        color = CUSTOM_CLASS_COLORS[classToken]
    elseif RAID_CLASS_COLORS and RAID_CLASS_COLORS[classToken] then
        color = RAID_CLASS_COLORS[classToken]
    end

    if not color then
        return nil
    end

    return color.r or color[1], color.g or color[2], color.b or color[3], 1
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

local ABBREV_DATA = {
    breakpointData = {
        { breakpoint = 1e12, abbreviation = "B", significandDivisor = 1e10, fractionDivisor = 100, abbreviationIsGlobal = false },
        { breakpoint = 1e11, abbreviation = "B", significandDivisor = 1e9, fractionDivisor = 1, abbreviationIsGlobal = false },
        { breakpoint = 1e10, abbreviation = "B", significandDivisor = 1e8, fractionDivisor = 10, abbreviationIsGlobal = false },
        { breakpoint = 1e9, abbreviation = "B", significandDivisor = 1e7, fractionDivisor = 100, abbreviationIsGlobal = false },
        { breakpoint = 1e8, abbreviation = "M", significandDivisor = 1e6, fractionDivisor = 1, abbreviationIsGlobal = false },
        { breakpoint = 1e7, abbreviation = "M", significandDivisor = 1e5, fractionDivisor = 10, abbreviationIsGlobal = false },
        { breakpoint = 1e6, abbreviation = "M", significandDivisor = 1e4, fractionDivisor = 100, abbreviationIsGlobal = false },
        { breakpoint = 1e5, abbreviation = "K", significandDivisor = 1000, fractionDivisor = 1, abbreviationIsGlobal = false },
        { breakpoint = 1e4, abbreviation = "K", significandDivisor = 100, fractionDivisor = 10, abbreviationIsGlobal = false },
    },
}

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

local function TrimFormattedDecimal(value)
    if type(value) ~= "string" then
        return "0"
    end

    value = value:gsub("(%..-)0+$", "%1")
    value = value:gsub("%.$", "")
    return value
end

local function FormatAbbreviatedNumber(value)
    local safeValue = ToSafeNumber(value)

    for _, data in ipairs(ABBREV_DATA.breakpointData) do
        if safeValue >= data.breakpoint then
            local scaled = math.floor(safeValue / data.significandDivisor) / data.fractionDivisor
            local decimals = 0

            if data.fractionDivisor == 10 then
                decimals = 1
            elseif data.fractionDivisor == 100 then
                decimals = 2
            end

            local formatString = "%." .. decimals .. "f"
            return TrimFormattedDecimal(string.format(formatString, scaled)) .. data.abbreviation
        end
    end

    return FormatNumber(value)
end

local function GetLiveValue(frame, key, fallback)
    if frame and frame.LiveValues and frame.LiveValues[key] ~= nil then
        return frame.LiveValues[key]
    end

    return fallback
end

function UF:RefreshLiveValues(frame)
    if not frame or not frame.unit then
        return
    end

    frame.LiveValues = frame.LiveValues or {}

    local unit = frame.unit
    local healthCurrent = UnitHealth and UnitHealth(unit) or 0
    local healthMax = UnitHealthMax and UnitHealthMax(unit) or 0
    local healthPercent = UnitHealthPercent and UnitHealthPercent(unit, true, CurveConstants and CurveConstants.ScaleTo100) or 0
    local powerCurrent = UnitPower and UnitPower(unit) or 0
    local powerMax = UnitPowerMax and UnitPowerMax(unit) or 0
    local healthBar = frame.Elements and frame.Elements.HealthBar
    local powerBar = frame.Elements and frame.Elements.PowerBar
    local healthBarCurrent = healthBar and healthBar.GetValue and healthBar:GetValue() or nil
    local powerBarCurrent = powerBar and powerBar.GetValue and powerBar:GetValue() or nil
    local healthBarMax = nil
    local powerBarMax = nil

    if healthBar and healthBar.GetMinMaxValues then
        local _, maxValue = healthBar:GetMinMaxValues()
        healthBarMax = maxValue
    end

    if powerBar and powerBar.GetMinMaxValues then
        local _, maxValue = powerBar:GetMinMaxValues()
        powerBarMax = maxValue
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
end

local TOKEN_DEFS = {
    ["hp:cur"] = {
        value = function(unit, frame)
            return GetLiveValue(frame, "healthCurrentRaw", GetLiveValue(frame, "healthCurrent", UnitHealth and UnitHealth(unit) or 0))
        end,
        format = FormatNumber,
        direct = true,
        passRaw = true,
    },
    ["hp:max"] = {
        value = function(unit, frame)
            return GetLiveValue(frame, "healthMaxRaw", GetLiveValue(frame, "healthMax", UnitHealthMax and UnitHealthMax(unit) or 0))
        end,
        format = FormatNumber,
        direct = true,
        passRaw = true,
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
            return GetLiveValue(frame, "healthPercentText", FormatInteger(UnitHealthPercent and UnitHealthPercent(unit, true, CurveConstants and CurveConstants.ScaleTo100) or 0))
        end,
        format = FormatTextValue,
        direct = true,
    },
    ["power:cur"] = {
        value = function(unit, frame)
            return GetLiveValue(frame, "powerCurrentRaw", GetLiveValue(frame, "powerCurrent", UnitPower and UnitPower(unit) or 0))
        end,
        format = FormatNumber,
        direct = true,
        passRaw = true,
    },
    ["power:max"] = {
        value = function(unit, frame)
            return GetLiveValue(frame, "powerMaxRaw", GetLiveValue(frame, "powerMax", UnitPowerMax and UnitPowerMax(unit) or 0))
        end,
        format = FormatNumber,
        direct = true,
        passRaw = true,
    },
    ["power:perc"] = {
        value = function(unit, frame)
            local percent = UnitPowerDisplayMod and UnitPowerDisplayMod(unit)
            if type(percent) == "number" and percent > 0 then
                return FormatInteger(percent)
            end

            return "0"
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
}

local TAG_DATABASE = {
    { token = "[hp:cur]", category = "INFO_TAG_CATEGORY_HEALTH", description = "INFO_TAG_DESC_HP_CUR", example = "154320" },
    { token = "[hp:max]", category = "INFO_TAG_CATEGORY_HEALTH", description = "INFO_TAG_DESC_HP_MAX", example = "154320" },
    { token = "[hp:cur:abbr]", category = "INFO_TAG_CATEGORY_HEALTH", description = "INFO_TAG_DESC_HP_CUR_ABBR", example = "154K" },
    { token = "[hp:max:abbr]", category = "INFO_TAG_CATEGORY_HEALTH", description = "INFO_TAG_DESC_HP_MAX_ABBR", example = "154K" },
    { token = "[hp:perc]", category = "INFO_TAG_CATEGORY_HEALTH", description = "INFO_TAG_DESC_HP_PERC", example = "100" },
    { token = "[power:cur]", category = "INFO_TAG_CATEGORY_POWER", description = "INFO_TAG_DESC_POWER_CUR", example = "100" },
    { token = "[power:max]", category = "INFO_TAG_CATEGORY_POWER", description = "INFO_TAG_DESC_POWER_MAX", example = "100" },
    { token = "[power:cur:abbr]", category = "INFO_TAG_CATEGORY_POWER", description = "INFO_TAG_DESC_POWER_CUR_ABBR", example = "100" },
    { token = "[power:max:abbr]", category = "INFO_TAG_CATEGORY_POWER", description = "INFO_TAG_DESC_POWER_MAX_ABBR", example = "100" },
    { token = "[power:perc]", category = "INFO_TAG_CATEGORY_POWER", description = "INFO_TAG_DESC_POWER_PERC", example = "100" },
    { token = "[cast:name]", category = "INFO_TAG_CATEGORY_CAST", description = "INFO_TAG_DESC_CAST_NAME", example = "Frostbolt" },
    { token = "[cast:time]", category = "INFO_TAG_CATEGORY_CAST", description = "INFO_TAG_DESC_CAST_TIME", example = "1.8" },
    { token = "[name]", category = "INFO_TAG_CATEGORY_UNIT", description = "INFO_TAG_DESC_NAME", example = "Portrait" },
    { token = "[level]", category = "INFO_TAG_CATEGORY_UNIT", description = "INFO_TAG_DESC_LEVEL", example = "80" },
    { token = "[class]", category = "INFO_TAG_CATEGORY_UNIT", description = "INFO_TAG_DESC_CLASS", example = "Warrior" },
    { token = "[race]", category = "INFO_TAG_CATEGORY_UNIT", description = "INFO_TAG_DESC_RACE", example = "Human" },
    { token = "[status]", category = "INFO_TAG_CATEGORY_STATUS", description = "INFO_TAG_DESC_STATUS", example = "AFK" },
}

function UF:GetTagDatabase()
    return TAG_DATABASE
end

local function GetTagPreviewFallback(token)
    for _, def in ipairs(TAG_DATABASE) do
        if def.token == "[" .. token .. "]" then
            return def.example or "[" .. token .. "]"
        end
    end

    return "[" .. token .. "]"
end

local function ResolveToken(frame, unit, token)
    if not unit or not UnitExists or not UnitExists(unit) then
        return ""
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
        end

        return ""
    end

    if token == "class" then
        if unit and UnitClass then
            local className = UnitClass(unit)
            return className or ""
        end

        return ""
    end

    if token == "race" then
        if unit and UnitRace then
            local raceName = UnitRace(unit)
            return raceName or ""
        end

        return ""
    end

    if token == "status" then
        if not unit then
            return ""
        end

        if UnitExists and not UnitExists(unit) then
            return ""
        end

        if UnitIsConnected and not UnitIsConnected(unit) then
            return PLAYER_OFFLINE or "Offline"
        end

        if UnitIsDeadOrGhost and UnitIsDeadOrGhost(unit) then
            if UnitIsGhost and UnitIsGhost(unit) then
                return DEAD or "Dead"
            end

            return DEAD or "Dead"
        end

        if UnitIsAFK and UnitIsAFK(unit) then
            return AFK or "AFK"
        end

        if UnitIsDND and UnitIsDND(unit) then
            return DND or "DND"
        end

        return ""
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
            if type(castName) == "string" and castName ~= "" then
                return castName
            end
        end

        if UnitChannelInfo then
            local channelName = UnitChannelInfo(unit)
            if type(channelName) == "string" and channelName ~= "" then
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

        if UnitCastingInfo then
            local _, _, _, startTimeMS, endTimeMS = UnitCastingInfo(unit)
            if type(startTimeMS) == "number" and type(endTimeMS) == "number" then
                local endTime = endTimeMS / 1000
                return FormatTimeValue(endTime - now)
            end
        end

        if UnitChannelInfo then
            local _, _, _, startTimeMS, endTimeMS = UnitChannelInfo(unit)
            if type(startTimeMS) == "number" and type(endTimeMS) == "number" then
                local remaining = (endTimeMS / 1000) - now
                return FormatTimeValue(remaining)
            end
        end

        return ""
    end

    return ResolveToken(frame, unit, token)
end

local function HasActiveCast(unit)
    if not unit then
        return false
    end

    if UnitCastingInfo then
        local castName = UnitCastingInfo(unit)
        if type(castName) == "string" and castName ~= "" then
            return true
        end
    end

    if UnitChannelInfo then
        local channelName = UnitChannelInfo(unit)
        if type(channelName) == "string" and channelName ~= "" then
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

    return (template:gsub("%[([^%]]+)%]", function(token)
        local resolved = ResolveBasicTag(frame, unit, token)
        if resolved ~= nil then
            return type(resolved) == "string" and resolved or FormatNumber(resolved)
        end

        return "[" .. token .. "]"
    end))
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

local function ApplyDirectTemplate(frame, textObject, unit, template)
    if not frame or not textObject or not unit or not UnitExists or not UnitExists(unit) then
        return false
    end

    local formatString = template and template:gsub("%%", "%%%%") or ""
    local formatArgs = {}
    local hasDirectToken = false

    for token in template:gmatch("%[([^%]]+)%]") do
        local def = TOKEN_DEFS[token]
        if not def or not def.direct then
            return false
        end

        local value = def.value and def.value(unit, frame) or nil
        local formatter = def.format or FormatNumber
        local directValue = def.passRaw and value or formatter(value)

        formatArgs[#formatArgs + 1] = directValue
        hasDirectToken = true
    end

    if not hasDirectToken then
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
    if key == "Class" then
        local classR, classG, classB, classA = GetClassTextColor(frame.unit)
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

    local template = textConfig.tag or ""
    if ApplyDirectTemplate(frame, textObject, frame.unit, template) then
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
    eventFrame:RegisterEvent("UNIT_HEALTH")
    eventFrame:RegisterEvent("UNIT_MAXHEALTH")
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
        if not owner or not FrameUsesCastTime(owner) or not HasActiveCast(owner.unit) then
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
            if UF.RefreshUnitBarValues then
                UF:RefreshUnitBarValues(owner)
            end
            if UF.RefreshCastBar then
                UF:RefreshCastBar(owner)
            end
            UF:RefreshLiveValues(owner)
            UF:UpdateTextElements(owner)
            if UF.RefreshCastBar then
                UF:RefreshCastBar(owner)
            end
            return
        end

        if event == "UNIT_PET" then
            if owner.unit == "pet" and unit == "player" then
                if UF.RefreshUnitBarValues then
                    UF:RefreshUnitBarValues(owner)
                end
                if UF.RefreshCastBar then
                    UF:RefreshCastBar(owner)
                end
                UF:RefreshLiveValues(owner)
                UF:UpdateTextElements(owner)
                if UF.RefreshCastBar then
                    UF:RefreshCastBar(owner)
                end
            end
            return
        end

        if unit and unit ~= owner.unit then
            return
        end

        if UF.RefreshUnitBarValues then
            UF:RefreshUnitBarValues(owner)
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
    if self.RefreshUnitBarValues then
        self:RefreshUnitBarValues(frame)
    end
    self:RefreshLiveValues(frame)
    self:UpdateTextElements(frame)
end
