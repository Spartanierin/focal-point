local _, FocalPoint = ...

FocalPoint.TextElementUpdate = FocalPoint.TextElementUpdate or {}

local Update = FocalPoint.TextElementUpdate
local Preview = FocalPoint.UnitFramePreview or {}
local TextState = FocalPoint.TextElementState or {}
local Status = FocalPoint.TextElementStatus or {}
local UnitUtils = FocalPoint.UnitFrameUtils or {}

local animatedNameTexts = {}
local animatedNameTicker = nil

local function ResolveTextRole(textConfig, key)
    if type(textConfig) == "table" and type(textConfig.role) == "string" and textConfig.role ~= "" then
        return textConfig.role
    end

    if key == "Name" then
        return "name"
    elseif key == "AltPower" then
        return "altpower"
    elseif key == "ClassPower" then
        return "classpower"
    elseif key == "CastName" then
        return "cast_name"
    elseif key == "CastTime" then
        return "cast_time"
    elseif key == "Class" then
        return "class"
    elseif key == "Level" then
        return "level"
    end

    return nil
end

local function GetClassificationIndicatorEffect(frame)
    local unit = frame and frame.unit
    local unitConfig = UnitUtils.GetUnitDB and UnitUtils.GetUnitDB(unit)
    local indicatorConfig = unitConfig and unitConfig.ClassificationIndicator

    if indicatorConfig == nil then
        return "PORTRAIT_OVERLAY"
    end

    if type(indicatorConfig) ~= "table" then
        return "PORTRAIT_OVERLAY"
    end

    if indicatorConfig.enabled == false then
        return "NONE"
    end

    return indicatorConfig.effect or "PORTRAIT_OVERLAY"
end

local function IsClassificationNameGlowEnabled(frame)
    return GetClassificationIndicatorEffect(frame) == "NAME_GLOW"
end

local function StripTextMarkup(text)
    if type(text) ~= "string" then
        return ""
    end

    local ok, stripped = pcall(function()
        if text == "" then
            return ""
        end

        local value = text:gsub("|c%x%x%x%x%x%x%x%x", "")
        value = value:gsub("|r", "")
        value = value:gsub("|T.-|t", "")
        return value
    end)

    if not ok or type(stripped) ~= "string" then
        return ""
    end

    return stripped
end

local function SplitUtf8Characters(text)
    local chars = {}
    if type(text) ~= "string" then
        return chars
    end

    local ok, parts = pcall(function()
        if text == "" then
            return {}
        end

        local result = {}
        local index = 1
        local length = #text

        while index <= length do
            local byte = text:byte(index)
            local charLength = 1

            if byte and byte >= 240 then
                charLength = 4
            elseif byte and byte >= 224 then
                charLength = 3
            elseif byte and byte >= 192 then
                charLength = 2
            end

            result[#result + 1] = text:sub(index, math.min(index + charLength - 1, length))
            index = index + charLength
        end

        return result
    end)

    if not ok or type(parts) ~= "table" then
        return chars
    end

    return parts
end

local function ClampColorComponent(value)
    if type(value) ~= "number" then
        return 0
    end

    if value < 0 then
        return 0
    end

    if value > 1 then
        return 1
    end

    return value
end

local function BlendColorStops(colorA, colorB, t)
    t = ClampColorComponent(t)
    return
        colorA[1] + (colorB[1] - colorA[1]) * t,
        colorA[2] + (colorB[2] - colorA[2]) * t,
        colorA[3] + (colorB[3] - colorA[3]) * t
end

local function ToColorCode(r, g, b)
    return string.format(
        "|cff%02x%02x%02x",
        math.floor(ClampColorComponent(r) * 255 + 0.5),
        math.floor(ClampColorComponent(g) * 255 + 0.5),
        math.floor(ClampColorComponent(b) * 255 + 0.5)
    )
end

local function GetClassificationLabelStyle(unit)
    if not unit or not UnitClassification then
        return nil
    end

    local classification = UnitClassification(unit)
    if classification == "rare" then
        return {
            label = Status.GetClassificationText and Status.GetClassificationText(unit) or "Rare",
            color = { 0.38, 0.70, 1.00 },
        }
    elseif classification == "elite" then
        return {
            label = Status.GetClassificationText and Status.GetClassificationText(unit) or "Elite",
            color = { 0.98, 0.74, 0.26 },
        }
    elseif classification == "rareelite" or classification == "worldboss" then
        return {
            label = Status.GetClassificationText and Status.GetClassificationText(unit) or "Rare Elite",
            color = { 1.00, 0.88, 0.40 },
        }
    end

    return nil
end

local function GetClassificationAnimationStyle(unit)
    if not unit or not UnitClassification then
        return nil
    end

    local classification = UnitClassification(unit)
    if classification == "rare" then
        return {
            speed = 1.2,
            stride = 0.55,
            sharpness = 2.8,
            colors = {
                { 0.26, 0.56, 1.00 },
                { 0.72, 0.88, 1.00 },
            },
            shadowColor = { 0.56, 0.78, 1.00 },
            shadowSpeed = 1.75,
            shadowMinAlpha = 0.18,
            shadowMaxAlpha = 0.72,
        }
    elseif classification == "elite" then
        return {
            speed = 0.95,
            stride = 0.48,
            sharpness = 2.8,
            colors = {
                { 0.62, 0.66, 0.74 },
                { 0.93, 0.95, 1.00 },
            },
            shadowColor = { 0.88, 0.90, 0.96 },
            shadowSpeed = 1.45,
            shadowMinAlpha = 0.14,
            shadowMaxAlpha = 0.58,
        }
    elseif classification == "rareelite" or classification == "worldboss" then
        return {
            speed = 1.1,
            stride = 0.52,
            sharpness = 2.6,
            colors = {
                { 1.00, 0.76, 0.18 },
                { 1.00, 0.93, 0.52 },
            },
            shadowColor = { 1.00, 0.90, 0.44 },
            shadowSpeed = 1.60,
            shadowMinAlpha = 0.22,
            shadowMaxAlpha = 0.82,
        }
    end

    return nil
end

local function ApplyClassificationNameLabel(frame, textRole, renderedText, template, templateContainsToken)
    if textRole ~= "name" or type(renderedText) ~= "string" or renderedText == "" then
        return renderedText
    end

    if GetClassificationIndicatorEffect(frame) ~= "NAME_LABEL" then
        return renderedText
    end

    if templateContainsToken and templateContainsToken(template, "classification") then
        return renderedText
    end

    local style = GetClassificationLabelStyle(frame and frame.unit)
    if not style or type(style.label) ~= "string" or style.label == "" then
        return renderedText
    end

    local color = style.color or { 1, 1, 1 }
    return string.format(
        "%s[%s]|r %s",
        ToColorCode(color[1] or 1, color[2] or 1, color[3] or 1),
        style.label,
        renderedText
    )
end

local function BuildAnimatedNameText(rawText, style, now)
    local plainText = StripTextMarkup(rawText)
    if plainText == "" or type(style) ~= "table" then
        return plainText
    end

    local chars = SplitUtf8Characters(plainText)
    if #chars == 0 then
        return plainText
    end

    local parts = {}
    local speed = style.speed or 1
    local stride = style.stride or 0.5
    local sharpness = style.sharpness or 2.4
    local colorA = style.colors and style.colors[1] or { 1, 1, 1 }
    local colorB = style.colors and style.colors[2] or { 0.8, 0.8, 0.8 }
    now = type(now) == "number" and now or 0

    for index, char in ipairs(chars) do
        if char:match("%s") then
            parts[#parts + 1] = char
        else
            local phase = (now * speed) - ((index - 1) * stride)
            local wave = (math.sin(phase) + 1) * 0.5
            wave = math.pow(wave, sharpness)
            local r, g, b = BlendColorStops(colorA, colorB, wave)
            parts[#parts + 1] = ToColorCode(r, g, b) .. char .. "|r"
        end
    end

    return table.concat(parts)
end

local function RefreshAnimatedNameText(textObject, entry)
    if not textObject or not entry then
        return
    end

    local okStyled, styledText = pcall(BuildAnimatedNameText, entry.rawText, entry.style, GetTime and GetTime() or 0)
    if not okStyled or type(styledText) ~= "string" then
        StopAnimatedNameText(textObject)
        if entry.rawText ~= nil then
            textObject:SetText(entry.rawText)
        end
        return
    end

    if styledText ~= entry.lastText then
        entry.lastText = styledText
        textObject:SetText(styledText)
    end

    local style = entry.style or {}
    local now = GetTime and GetTime() or 0
    local shadowWave = (math.sin(now * (style.shadowSpeed or 1)) + 1) * 0.5
    local shadowAlpha = (style.shadowMinAlpha or 0.16) + ((style.shadowMaxAlpha or 0.64) - (style.shadowMinAlpha or 0.16)) * shadowWave
    local shadowColor = style.shadowColor or { 1, 1, 1 }

    textObject:SetTextColor(entry.baseColor[1] or 1, entry.baseColor[2] or 1, entry.baseColor[3] or 1, entry.baseAlpha or 1)
    textObject:SetShadowColor(shadowColor[1] or 1, shadowColor[2] or 1, shadowColor[3] or 1, shadowAlpha)
end

local function EnsureAnimatedNameTicker()
    if animatedNameTicker then
        return animatedNameTicker
    end

    animatedNameTicker = CreateFrame("Frame")
    animatedNameTicker.elapsed = 0
    animatedNameTicker:SetScript("OnUpdate", function(self, elapsed)
        self.elapsed = (self.elapsed or 0) + elapsed
        if self.elapsed < 0.08 then
            return
        end

        self.elapsed = 0

        local hasEntries = false
        for textObject, entry in pairs(animatedNameTexts) do
            if textObject and entry and textObject.IsShown and textObject:IsShown() then
                hasEntries = true
                RefreshAnimatedNameText(textObject, entry)
            else
                animatedNameTexts[textObject] = nil
            end
        end

        if not hasEntries then
            self:Hide()
        end
    end)
    animatedNameTicker:Hide()
    return animatedNameTicker
end

local function StopAnimatedNameText(textObject)
    if not textObject then
        return
    end

    local entry = animatedNameTexts[textObject]
    if entry and entry.baseColor then
        textObject:SetTextColor(
            entry.baseColor[1] or 1,
            entry.baseColor[2] or 1,
            entry.baseColor[3] or 1,
            entry.baseAlpha or 1
        )
        if entry.rawText ~= nil then
            textObject:SetText(entry.rawText)
        end
        if entry.baseShadowColor then
            textObject:SetShadowColor(
                entry.baseShadowColor[1] or 0,
                entry.baseShadowColor[2] or 0,
                entry.baseShadowColor[3] or 0,
                entry.baseShadowColor[4] or 0
            )
        end
    end

    animatedNameTexts[textObject] = nil
end

local function ApplyAnimatedNameText(frame, textRole, textObject, renderedText, r, g, b, a)
    if not textObject then
        return
    end

    if textRole ~= "name" then
        StopAnimatedNameText(textObject)
        return
    end

    if InCombatLockdown and InCombatLockdown() then
        StopAnimatedNameText(textObject)
        textObject:SetTextColor(r, g, b, a)
        return
    end

    local style = frame and frame.unit and IsClassificationNameGlowEnabled(frame) and GetClassificationAnimationStyle(frame.unit) or nil
    if not style then
        StopAnimatedNameText(textObject)
        textObject:SetTextColor(r, g, b, a)
        return
    end

    local entry = animatedNameTexts[textObject] or {}
    entry.rawText = renderedText or ""
    entry.style = style
    entry.lastText = nil
    entry.baseColor = { r or 1, g or 1, b or 1 }
    entry.baseAlpha = a or 1
    if textObject.GetShadowColor then
        local sr, sg, sb, sa = textObject:GetShadowColor()
        entry.baseShadowColor = { sr or 0, sg or 0, sb or 0, sa or 0 }
    else
        entry.baseShadowColor = { 0, 0, 0, 0 }
    end
    animatedNameTexts[textObject] = entry

    RefreshAnimatedNameText(textObject, entry)
    local ticker = EnsureAnimatedNameTicker()
    if ticker then
        ticker:Show()
    end
end

-- Keeps live text refresh logic together while layout/event wiring remains
-- in the orchestrating text module.
local function TokenizeStyledText(text)
    local tokens = {}
    if type(text) ~= "string" or text == "" then
        return tokens
    end

    local index = 1
    local length = #text

    while index <= length do
        local current = text:sub(index, index)
        local nextTwo = text:sub(index, index + 1)

        if nextTwo == "|r" then
            tokens[#tokens + 1] = { text = "|r", visible = false, closesColor = true }
            index = index + 2
        elseif nextTwo == "|c" then
            local colorCode = text:sub(index, index + 9)
            if #colorCode == 10 then
                tokens[#tokens + 1] = { text = colorCode, visible = false, opensColor = true }
                index = index + 10
            else
                tokens[#tokens + 1] = { text = current, visible = true }
                index = index + 1
            end
        elseif nextTwo == "|T" then
            local closeIndex = text:find("|t", index + 2, true)
            if closeIndex then
                tokens[#tokens + 1] = { text = text:sub(index, closeIndex + 1), visible = false }
                index = closeIndex + 2
            else
                tokens[#tokens + 1] = { text = current, visible = true }
                index = index + 1
            end
        else
            local byte = text:byte(index)
            local charLength = 1

            if byte and byte >= 240 then
                charLength = 4
            elseif byte and byte >= 224 then
                charLength = 3
            elseif byte and byte >= 192 then
                charLength = 2
            end

            tokens[#tokens + 1] = {
                text = text:sub(index, math.min(index + charLength - 1, length)),
                visible = true,
            }
            index = index + charLength
        end
    end

    return tokens
end

local function BuildEllipsisCandidate(tokens, visibleLimit)
    local parts = {}
    local visibleCount = 0
    local colorDepth = 0

    for _, token in ipairs(tokens) do
        if token.visible then
            if visibleCount >= visibleLimit then
                break
            end
            visibleCount = visibleCount + 1
            parts[#parts + 1] = token.text
        else
            parts[#parts + 1] = token.text
            if token.opensColor then
                colorDepth = colorDepth + 1
            elseif token.closesColor and colorDepth > 0 then
                colorDepth = colorDepth - 1
            end
        end
    end

    parts[#parts + 1] = "..."
    while colorDepth > 0 do
        parts[#parts + 1] = "|r"
        colorDepth = colorDepth - 1
    end

    return table.concat(parts)
end

local function ApplyOverflow(textObject, renderedText, mode)
    if not textObject then
        return
    end

    local overflowMode = mode or textObject.FocalPointOverflowMode or "NONE"
    local maxWidth = textObject.FocalPointOverflowWidth or 0

    textObject:SetText(renderedText or "")

    if overflowMode == "NONE" or maxWidth <= 0 then
        return
    end

    if InCombatLockdown and InCombatLockdown() then
        return
    end

    if textObject.SetWidth then
        textObject:SetWidth(maxWidth)
    end

    if overflowMode ~= "ELLIPSIS" then
        return
    end

    local currentWidth = 0
    if textObject.GetStringWidth then
        local okWidth, measuredWidth = pcall(textObject.GetStringWidth, textObject)
        if not okWidth or type(measuredWidth) ~= "number" then
            return
        end
        currentWidth = measuredWidth
    end

    local okFitsCurrent, fitsCurrent = pcall(function()
        return currentWidth <= maxWidth
    end)
    if not okFitsCurrent or fitsCurrent then
        return
    end

    local tokens = TokenizeStyledText(renderedText or "")
    local visibleCount = 0
    for _, token in ipairs(tokens) do
        if token.visible then
            visibleCount = visibleCount + 1
        end
    end

    for limit = math.max(visibleCount - 1, 0), 0, -1 do
        local candidate = limit > 0 and BuildEllipsisCandidate(tokens, limit) or "..."
        textObject:SetText(candidate)
        local candidateWidth = 0
        if textObject.GetStringWidth then
            local okWidth, measuredWidth = pcall(textObject.GetStringWidth, textObject)
            if not okWidth or type(measuredWidth) ~= "number" then
                return
            end
            candidateWidth = measuredWidth
        end

        local okFitsCandidate, fitsCandidate = pcall(function()
            return candidateWidth <= maxWidth
        end)
        if not okFitsCandidate then
            return
        end

        if fitsCandidate then
            return
        end
    end
end

function Update.UpdateElement(frame, key, deps)
    local ok, err = xpcall(function()
        deps = deps or {}

        local ResolveConfiguredTemplate = deps.ResolveConfiguredTemplate
        local UnpackColor = deps.UnpackColor
        local GetLiveValue = deps.GetLiveValue
        local ToSafeNumber = deps.ToSafeNumber
        local GetSecondaryPowerDisplayValues = deps.GetSecondaryPowerDisplayValues
        local FormatNumber = deps.FormatNumber
        local TemplateContainsToken = deps.TemplateContainsToken
        local GetClassTextColor = deps.GetClassTextColor
        local ApplyDirectTemplate = deps.ApplyDirectTemplate
        local ResolveTextTemplate = deps.ResolveTextTemplate

        if not frame or not frame.Texts or not frame.Texts[key] then
            return
        end

        local textObject = frame.Texts[key]
        local textConfig = frame.config and frame.config.Texts and frame.config.Texts[key]
        if not textConfig or textConfig.enabled == false then
            StopAnimatedNameText(textObject)
            textObject:SetText("")
            textObject:Hide()
            return
        end

        if Preview.IsPlaceholderPreviewEnabled and Preview.IsPlaceholderPreviewEnabled(frame) then
            StopAnimatedNameText(textObject)
            textObject:SetText("")
            textObject:Hide()
            return
        end

        local template = ResolveConfiguredTemplate and ResolveConfiguredTemplate(frame, textConfig) or ""
        local textRole = ResolveTextRole(textConfig, key)
        local r, g, b, a = UnpackColor and UnpackColor(textConfig.color, { 1, 1, 1, 1 }) or 1, 1, 1, 1
        local altPowerType = GetLiveValue and GetLiveValue(frame, "altPowerType", nil) or nil
        local altPowerMaxRaw = ToSafeNumber and ToSafeNumber(GetLiveValue and GetLiveValue(frame, "altPowerMaxRaw", 0) or 0) or 0
        local altPowerCurrentRaw = ToSafeNumber and ToSafeNumber(GetLiveValue and GetLiveValue(frame, "altPowerCurrentRaw", 0) or 0) or 0
        local altPowerVisible = GetLiveValue and GetLiveValue(frame, "altPowerVisible", false) or false
        local altPowerCurrentSafe = ToSafeNumber and ToSafeNumber(GetLiveValue and GetLiveValue(frame, "altPowerCurrentSafe", 0) or 0) or 0
        local altPowerMaxSafe = ToSafeNumber and ToSafeNumber(GetLiveValue and GetLiveValue(frame, "altPowerMaxSafe", 0) or 0) or 0
        local altPowerCurrentText = GetLiveValue and GetLiveValue(frame, "altPowerCurrentText", nil) or nil
        local altPowerMaxText = GetLiveValue and GetLiveValue(frame, "altPowerMaxText", nil) or nil
        local altPowerAvailable = altPowerType ~= nil and altPowerMaxRaw > 0
        local classPowerVisible = GetLiveValue and GetLiveValue(frame, "classPowerVisible", false) or false
        local classPowerMaxSafe = ToSafeNumber and ToSafeNumber(GetLiveValue and GetLiveValue(frame, "classPowerMaxSafe", 0) or 0) or 0
        local classPowerCurrentSafe = ToSafeNumber and ToSafeNumber(GetLiveValue and GetLiveValue(frame, "classPowerCurrentSafe", 0) or 0) or 0
        local classPowerCurrentText = GetLiveValue and GetLiveValue(frame, "classPowerCurrentText", nil) or nil
        local classPowerMaxText = GetLiveValue and GetLiveValue(frame, "classPowerMaxText", nil) or nil

        if textRole == "altpower" then
            StopAnimatedNameText(textObject)
            textObject:SetTextColor(r, g, b, a)
            local livePowerType, liveCurrentText, liveMaxText, liveMaxNumber = GetSecondaryPowerDisplayValues and GetSecondaryPowerDisplayValues(frame.unit)
            liveMaxNumber = type(liveMaxNumber) == "number" and liveMaxNumber or 0
            liveCurrentText = type(liveCurrentText) == "string" and liveCurrentText or "0"
            liveMaxText = type(liveMaxText) == "string" and liveMaxText or "0"

            if livePowerType ~= nil and liveMaxNumber > 0 then
                ApplyOverflow(textObject, liveCurrentText .. " / " .. liveMaxText, textConfig.overflowMode)
                textObject:Show()
            elseif altPowerVisible and altPowerMaxSafe > 0 then
                ApplyOverflow(
                    textObject,
                    (type(altPowerCurrentText) == "string" and altPowerCurrentText or (FormatNumber and FormatNumber(altPowerCurrentSafe) or altPowerCurrentSafe))
                        .. " / " ..
                    (type(altPowerMaxText) == "string" and altPowerMaxText or (FormatNumber and FormatNumber(altPowerMaxSafe) or altPowerMaxSafe)),
                    textConfig.overflowMode
                )
                textObject:Show()
            elseif altPowerAvailable then
                ApplyOverflow(
                    textObject,
                    (FormatNumber and FormatNumber(altPowerCurrentRaw) or altPowerCurrentRaw) .. " / " .. (FormatNumber and FormatNumber(altPowerMaxRaw) or altPowerMaxRaw),
                    textConfig.overflowMode
                )
                textObject:Show()
            else
                textObject:SetText("")
            end
            return
        end

        if textRole == "classpower" then
            StopAnimatedNameText(textObject)
            textObject:SetTextColor(r, g, b, a)

            if classPowerVisible and classPowerMaxSafe > 0 then
                ApplyOverflow(
                    textObject,
                    (type(classPowerCurrentText) == "string" and classPowerCurrentText or (FormatNumber and FormatNumber(classPowerCurrentSafe) or classPowerCurrentSafe))
                        .. " / " ..
                    (type(classPowerMaxText) == "string" and classPowerMaxText or (FormatNumber and FormatNumber(classPowerMaxSafe) or classPowerMaxSafe)),
                    textConfig.overflowMode
                )
                textObject:Show()
            else
                textObject:SetText("")
            end
            return
        end

        if textRole == "class" or (TemplateContainsToken and TemplateContainsToken(template, "class")) then
            local classR, classG, classB, classA = GetClassTextColor and GetClassTextColor(frame.unit, frame)
            if classR and classG and classB then
                r, g, b, a = classR, classG, classB, classA or 1
            end
        elseif textRole == "level" then
            r, g, b, a = 1.00, 0.82, 0.00, 1.00
        end
        textObject:SetTextColor(r, g, b, a)

        if ApplyDirectTemplate and ApplyDirectTemplate(frame, textObject, frame.unit, template, textConfig.color) then
            local renderedText = textObject:GetText() or ""
            renderedText = ApplyClassificationNameLabel(frame, textRole, renderedText, template, TemplateContainsToken)
            ApplyOverflow(textObject, renderedText, textConfig.overflowMode)
            ApplyAnimatedNameText(frame, textRole, textObject, renderedText, r, g, b, a)
            textObject:Show()
            return
        end

        local renderedText = ResolveTextTemplate and ResolveTextTemplate(frame, frame.unit, template) or ""
        renderedText = ApplyClassificationNameLabel(frame, textRole, renderedText, template, TemplateContainsToken)
        ApplyOverflow(
            textObject,
            renderedText,
            textConfig.overflowMode
        )
        ApplyAnimatedNameText(frame, textRole, textObject, renderedText, r, g, b, a)
        textObject:Show()
    end, function(message)
        return tostring(message)
    end)

    if ok then
        return
    end

    if frame and frame.Texts and frame.Texts[key] then
        local textObject = frame.Texts[key]
        StopAnimatedNameText(textObject)
        textObject:SetText("")
        textObject:Hide()
    end

    frame._focalPointTextErrors = frame._focalPointTextErrors or {}
    if frame._focalPointTextErrors[key] ~= err then
        frame._focalPointTextErrors[key] = err
        if FocalPoint and FocalPoint.Warn then
            FocalPoint:Warn(string.format("Text render failed for %s.%s: %s", tostring(frame.unit or "?"), tostring(key), tostring(err)))
        end
    end
end

function Update.UpdateAll(frame, deps)
    if not frame or not frame.config or not frame.config.Texts then
        return
    end

    local updateElement = deps and deps.UpdateElement
    if not updateElement then
        return
    end

    for key in pairs(frame.config.Texts) do
        updateElement(frame, key)
    end

    if TextState.MarkRenderApplied then
        TextState.MarkRenderApplied(frame)
    end
end
