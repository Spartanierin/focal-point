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

    return ResolveToken(frame, unit, token)
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

    textObject:ClearAllPoints()
    textObject:SetPoint(
        textConfig.point or "CENTER",
        anchorParent,
        textConfig.relativePoint or "CENTER",
        textConfig.offsetX or 0,
        textConfig.offsetY or 0
    )

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
    eventFrame:RegisterEvent("UNIT_HEALTH")
    eventFrame:RegisterEvent("UNIT_MAXHEALTH")
    eventFrame:RegisterEvent("UNIT_POWER_UPDATE")
    eventFrame:RegisterEvent("UNIT_MAXPOWER")
    eventFrame:RegisterEvent("UNIT_DISPLAYPOWER")

    if frame.unit == "target" then
        eventFrame:RegisterEvent("PLAYER_TARGET_CHANGED")
    elseif frame.unit == "focus" then
        eventFrame:RegisterEvent("PLAYER_FOCUS_CHANGED")
    elseif frame.unit == "pet" then
        eventFrame:RegisterEvent("UNIT_PET")
    end

    eventFrame:SetScript("OnEvent", function(_, event, unit)
        local owner = eventFrame.owner
        if not owner then
            return
        end

        if event == "PLAYER_TARGET_CHANGED" or event == "PLAYER_FOCUS_CHANGED" then
            if UF.RefreshUnitBarValues then
                UF:RefreshUnitBarValues(owner)
            end
            UF:RefreshLiveValues(owner)
            UF:UpdateTextElements(owner)
            return
        end

        if event == "UNIT_PET" then
            if owner.unit == "pet" and unit == "player" then
                if UF.RefreshUnitBarValues then
                    UF:RefreshUnitBarValues(owner)
                end
                UF:RefreshLiveValues(owner)
                UF:UpdateTextElements(owner)
            end
            return
        end

        if unit and unit ~= owner.unit then
            return
        end

        if UF.RefreshUnitBarValues then
            UF:RefreshUnitBarValues(owner)
        end
        UF:RefreshLiveValues(owner)
        UF:UpdateTextElements(owner)
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
