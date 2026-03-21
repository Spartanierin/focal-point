local _, FocalPoint = ...

FocalPoint.TextElementUpdate = FocalPoint.TextElementUpdate or {}

local Update = FocalPoint.TextElementUpdate
local TextState = FocalPoint.TextElementState or {}

-- Keeps live text refresh logic together while layout/event wiring remains
-- in the orchestrating text module.
function Update.UpdateElement(frame, key, deps)
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
        if livePowerType ~= nil and liveMaxNumber > 0 then
            textObject:SetText(liveCurrentText .. " / " .. liveMaxText)
            textObject:Show()
        elseif altPowerAvailable then
            textObject:SetText((FormatNumber and FormatNumber(altPowerCurrentRaw) or altPowerCurrentRaw) .. " / " .. (FormatNumber and FormatNumber(altPowerMaxRaw) or altPowerMaxRaw))
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
        return
    end

    textObject:SetText(ResolveTextTemplate and ResolveTextTemplate(frame, frame.unit, template) or "")
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
