local _, FocalPoint = ...

FocalPoint.UnitFrameVisualIndicator = FocalPoint.UnitFrameVisualIndicator or {}
local VisualIndicator = FocalPoint.UnitFrameVisualIndicator

-- Small, behavior-neutral visual helpers shared by indicator-style elements.

local function ResolveFrameLevel(frame, options)
    options = options or {}
    local baseOffset = tonumber(options.frameLevelOffset) or 20
    local healthOffset = tonumber(options.healthFrameLevelOffset) or 10
    local fallback = frame:GetFrameLevel() + baseOffset
    local health = frame.Elements and frame.Elements.HealthBar
    local healthLevel = health and health.GetFrameLevel and health:GetFrameLevel() + healthOffset or fallback
    return math.max(fallback, healthLevel)
end

local function NormalizeTextureSubLevel(value)
    local subLevel = tonumber(value) or 7
    if subLevel < -8 then
        return -8
    elseif subLevel > 7 then
        return 7
    end
    return subLevel
end

function VisualIndicator.ApplyFrameLayer(holder, frame, options)
    if not holder or not frame then
        return
    end

    holder:SetFrameStrata(frame:GetFrameStrata())
    holder:SetFrameLevel(ResolveFrameLevel(frame, options))
end

function VisualIndicator.CreateHolder(frame, elementKey, options)
    if not frame or not frame.Elements or type(elementKey) ~= "string" or elementKey == "" then
        return nil
    end

    options = options or {}

    local holder = CreateFrame("Frame", nil, frame)
    holder:SetAllPoints(frame)
    holder:SetFrameStrata(frame:GetFrameStrata())
    holder:SetFrameLevel(frame:GetFrameLevel() + (tonumber(options.frameLevelOffset) or 20))
    if holder.EnableMouse then
        holder:EnableMouse(false)
    end
    holder:Hide()

    local texture = holder:CreateTexture(nil, options.textureLayer or "OVERLAY", nil, NormalizeTextureSubLevel(options.textureSubLevel))
    texture:Hide()

    holder.Texture = texture
    frame.Elements[elementKey] = holder
    frame[elementKey] = holder

    return holder
end

function VisualIndicator.ResetHolderVisual(holder, frame)
    if not holder or not frame then
        return nil
    end

    local visual = holder.Texture or holder

    holder:ClearAllPoints()
    holder:SetScale(1)
    VisualIndicator.ApplyFrameLayer(holder, frame)

    if visual.ClearAllPoints then
        visual:ClearAllPoints()
    end
    if visual.SetScale then
        visual:SetScale(1)
    end

    return visual
end

function VisualIndicator.ApplySquareBounds(holder, visual, size)
    if not holder or not visual then
        return
    end

    holder:SetSize(size, size)
    visual:SetAllPoints(holder)
end

function VisualIndicator.ApplyRectBounds(holder, visual, width, height)
    if not holder or not visual then
        return
    end

    holder:SetSize(width, height)
    visual:SetAllPoints(holder)
end

function VisualIndicator.ApplyAnchor(holder, target, point, relativePoint, offsetX, offsetY)
    if not holder or not target then
        return
    end

    holder:SetPoint(point or "CENTER", target, relativePoint or "CENTER", offsetX or 0, offsetY or 0)
end

function VisualIndicator.ApplyAlpha(holder, alpha)
    if not holder or not holder.SetAlpha then
        return
    end

    holder:SetAlpha(alpha == nil and 1 or alpha)
end

function VisualIndicator.HideTexture(holder)
    local texture = holder and holder.Texture
    if not texture then
        return
    end

    texture:SetTexture(nil)
    texture:Hide()
end

function VisualIndicator.Hide(holder)
    if not holder then
        return
    end

    VisualIndicator.HideTexture(holder)
    holder:Hide()
end

function VisualIndicator.Show(holder)
    if not holder then
        return
    end

    holder:Show()
    if holder.Texture then
        holder.Texture:Show()
    end
end
