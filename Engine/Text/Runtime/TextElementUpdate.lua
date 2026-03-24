local _, FocalPoint = ...

FocalPoint.TextElementUpdate = FocalPoint.TextElementUpdate or {}

local Update = FocalPoint.TextElementUpdate
local TextState = FocalPoint.TextElementState or {}

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

    if textObject.SetWidth then
        textObject:SetWidth(maxWidth)
    end

    if overflowMode ~= "ELLIPSIS" then
        return
    end

    local currentWidth = textObject.GetStringWidth and textObject:GetStringWidth() or 0
    if currentWidth <= maxWidth then
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
        if (textObject.GetStringWidth and textObject:GetStringWidth() or 0) <= maxWidth then
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
            textObject:SetText("")
            textObject:Hide()
            return
        end

        local template = ResolveConfiguredTemplate and ResolveConfiguredTemplate(frame, textConfig) or ""
        local r, g, b, a = UnpackColor and UnpackColor(textConfig.color, { 1, 1, 1, 1 }) or 1, 1, 1, 1
        local altPowerType = GetLiveValue and GetLiveValue(frame, "altPowerType", nil) or nil
        local altPowerMaxRaw = ToSafeNumber and ToSafeNumber(GetLiveValue and GetLiveValue(frame, "altPowerMaxRaw", 0) or 0) or 0
        local altPowerCurrentRaw = ToSafeNumber and ToSafeNumber(GetLiveValue and GetLiveValue(frame, "altPowerCurrentRaw", 0) or 0) or 0
        local altPowerAvailable = altPowerType ~= nil and altPowerMaxRaw > 0

        if key == "AltPower" then
            textObject:SetTextColor(r, g, b, a)
            local livePowerType, liveCurrentText, liveMaxText, liveMaxNumber = GetSecondaryPowerDisplayValues and GetSecondaryPowerDisplayValues(frame.unit)
            liveMaxNumber = type(liveMaxNumber) == "number" and liveMaxNumber or 0
            liveCurrentText = type(liveCurrentText) == "string" and liveCurrentText or "0"
            liveMaxText = type(liveMaxText) == "string" and liveMaxText or "0"

            if livePowerType ~= nil and liveMaxNumber > 0 then
                ApplyOverflow(textObject, liveCurrentText .. " / " .. liveMaxText, textConfig.overflowMode)
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

        if key == "Class" or (TemplateContainsToken and TemplateContainsToken(template, "class")) then
            local classR, classG, classB, classA = GetClassTextColor and GetClassTextColor(frame.unit, frame)
            if classR and classG and classB then
                r, g, b, a = classR, classG, classB, classA or 1
            end
        elseif key == "Level" then
            r, g, b, a = 1.00, 0.82, 0.00, 1.00
        end
        textObject:SetTextColor(r, g, b, a)

        if ApplyDirectTemplate and ApplyDirectTemplate(frame, textObject, frame.unit, template, textConfig.color) then
            ApplyOverflow(textObject, textObject:GetText() or "", textConfig.overflowMode)
            return
        end

        ApplyOverflow(
            textObject,
            ResolveTextTemplate and ResolveTextTemplate(frame, frame.unit, template) or "",
            textConfig.overflowMode
        )
    end, function(message)
        return tostring(message)
    end)

    if ok then
        return
    end

    if frame and frame.Texts and frame.Texts[key] then
        local textObject = frame.Texts[key]
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
