local _, FocalPoint = ...

FocalPoint.TextElementApply = FocalPoint.TextElementApply or {}

local Apply = FocalPoint.TextElementApply
local Roles = FocalPoint.TextElementRoles or {}

-- Applies layout and style settings to text elements while leaving template
-- and live update logic in their dedicated modules.
local function ResolveOverflowWidth(key, textConfig, anchorParent)
    if not textConfig then
        return 0
    end

    local anchorTo = textConfig.anchorTo
    local justifyH = textConfig.justifyH or "CENTER"
    local point = textConfig.point or "CENTER"
    local relativePoint = textConfig.relativePoint or "CENTER"
    local overflowMode = textConfig.overflowMode or "NONE"
    local anchorWidth = anchorParent and anchorParent.GetWidth and anchorParent:GetWidth() or 0
    local textRole = Roles.Resolve and Roles.Resolve(key, textConfig) or nil

    if anchorTo == "CastBar" and anchorWidth > 0 then
        if textRole == "cast_time" then
            return 48
        end

        if textRole == "cast_name" then
            return math.max(anchorWidth - 56, 20)
        end
    end

    if overflowMode == "NONE" or anchorWidth <= 0 then
        return 0
    end

    local edgeAnchored = justifyH == "LEFT"
        or justifyH == "RIGHT"
        or point:find("LEFT", 1, true) ~= nil
        or point:find("RIGHT", 1, true) ~= nil
        or relativePoint:find("LEFT", 1, true) ~= nil
        or relativePoint:find("RIGHT", 1, true) ~= nil

    if edgeAnchored then
        -- Be a bit more generous for side-anchored texts. A strict half-width
        -- avoids overlap, but truncates common label/status texts too early.
        return math.max(math.floor(anchorWidth * 0.65) - 6, 24)
    end

    return math.max(anchorWidth - 12, 24)
end

function Apply.ApplyElementConfig(frame, key, textObject, textConfig, deps)
    deps = deps or {}

    local GetAnchorTarget = deps.GetAnchorTarget
    local GetFontPath = deps.GetFontPath
    local BuildFontFlags = deps.BuildFontFlags
    local UnpackColor = deps.UnpackColor
    local ResolveConfiguredTemplate = deps.ResolveConfiguredTemplate
    local TemplateContainsToken = deps.TemplateContainsToken
    local GetClassTextColor = deps.GetClassTextColor
    local offsetOverride = type(deps.offsetOverride) == "table" and deps.offsetOverride or nil

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
    local textRole = Roles.Resolve and Roles.Resolve(key, textConfig) or nil

    local r, g, b, a = UnpackColor and UnpackColor(textConfig.color, { 1, 1, 1, 1 }) or 1, 1, 1, 1
    local template = ResolveConfiguredTemplate and ResolveConfiguredTemplate(frame, textConfig) or ""

    if textRole == "class" or (TemplateContainsToken and TemplateContainsToken(template, "class")) then
        local classR, classG, classB, classA = GetClassTextColor and GetClassTextColor(frame.unit, frame)
        if classR and classG and classB then
            r, g, b, a = classR, classG, classB, classA or 1
        end
    elseif textRole == "level" then
        r, g, b, a = 1.00, 0.82, 0.00, 1.00
    end

    textObject:ClearAllPoints()
    textObject:SetPoint(
        textConfig.point or "CENTER",
        anchorParent,
        textConfig.relativePoint or "CENTER",
        offsetOverride and offsetOverride.offsetX or textConfig.offsetX or 0,
        offsetOverride and offsetOverride.offsetY or textConfig.offsetY or 0
    )

    local overflowWidth = ResolveOverflowWidth(key, textConfig, anchorParent)
    textObject:SetWidth(overflowWidth)
    textObject.FocalPointOverflowMode = textConfig.overflowMode or "NONE"
    textObject.FocalPointOverflowWidth = overflowWidth
    if textObject.SetMaxLines then
        textObject:SetMaxLines(1)
    end
    if textObject.SetWordWrap then
        textObject:SetWordWrap(false)
    end
    if textObject.SetNonSpaceWrap then
        textObject:SetNonSpaceWrap(false)
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
