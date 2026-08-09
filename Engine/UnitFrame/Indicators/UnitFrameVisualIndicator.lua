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
    holder:Hide()

    local texture = holder:CreateTexture(nil, options.textureLayer or "OVERLAY", nil, options.textureSubLevel or 7)
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

