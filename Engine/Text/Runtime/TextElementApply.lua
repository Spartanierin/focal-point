local _, FocalPoint = ...

FocalPoint.TextElementApply = FocalPoint.TextElementApply or {}

local Apply = FocalPoint.TextElementApply

-- Applies layout and style settings to text elements while leaving template
-- and live update logic in their dedicated modules.
function Apply.ApplyElementConfig(frame, key, textObject, textConfig, deps)
    deps = deps or {}

    local GetAnchorTarget = deps.GetAnchorTarget
    local GetFontPath = deps.GetFontPath
    local BuildFontFlags = deps.BuildFontFlags
    local UnpackColor = deps.UnpackColor
    local ResolveConfiguredTemplate = deps.ResolveConfiguredTemplate
    local TemplateContainsToken = deps.TemplateContainsToken
    local GetClassTextColor = deps.GetClassTextColor

    if not textObject or not textConfig then
        return
    end

    if textConfig.enabled == false then
        textObject:Hide()
        return
    end

    local anchorParent = GetAnchorTarget and GetAnchorTarget(frame, textConfig.anchorTo)
    local fontPath = GetFontPath and GetFontPath(textConfig.font)
    local fontSize = textConfig.fontSize or 12
    local fontFlags = BuildFontFlags and BuildFontFlags(textConfig)
    local justifyH = textConfig.justifyH or "CENTER"

    local r, g, b, a = UnpackColor and UnpackColor(textConfig.color, { 1, 1, 1, 1 }) or 1, 1, 1, 1
    local template = ResolveConfiguredTemplate and ResolveConfiguredTemplate(frame, textConfig) or ""

    if key == "Class" or (TemplateContainsToken and TemplateContainsToken(template, "class")) then
        local classR, classG, classB, classA = GetClassTextColor and GetClassTextColor(frame.unit, frame)
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
        local sr, sg, sb, sa = UnpackColor and UnpackColor(textConfig.shadowColor, { 0, 0, 0, 1 }) or 0, 0, 0, 1

        textObject:SetShadowOffset(sx, sy)
        textObject:SetShadowColor(sr, sg, sb, sa)
    else
        textObject:SetShadowOffset(0, 0)
        textObject:SetShadowColor(0, 0, 0, 0)
    end

    textObject:Show()
end

function Apply.ApplyTestValues(frame, deps)
    deps = deps or {}

    local RefreshLiveValues = deps.RefreshLiveValues
    local UpdateTextElements = deps.UpdateTextElements

    if RefreshLiveValues then
        RefreshLiveValues(frame)
    end
    if UpdateTextElements then
        UpdateTextElements(frame)
    end
end
