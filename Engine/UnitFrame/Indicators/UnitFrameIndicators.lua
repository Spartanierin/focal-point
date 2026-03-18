local _, FocalPoint = ...

FocalPoint.UnitFrameIndicators = FocalPoint.UnitFrameIndicators or {}
local Indicators = FocalPoint.UnitFrameIndicators

-- Shared helper logic for non-portrait overlay indicators such as leader,
-- role, combat, resting, and ready check.

function Indicators.CreateHolder(frame, elementKey)
    local holder = CreateFrame("Frame", nil, frame)
    holder:SetAllPoints(frame)
    holder:SetFrameStrata(frame:GetFrameStrata())
    holder:SetFrameLevel(frame:GetFrameLevel() + 20)
    holder:Hide()

    local texture = holder:CreateTexture(nil, "OVERLAY", nil, 7)
    texture:Hide()

    holder.Texture = texture
    frame.Elements[elementKey] = holder
    frame[elementKey] = holder
end

function Indicators.ApplyConfig(owner, frame, holder, options)
    if not holder then
        return
    end

    local icon = holder.Texture or holder

    holder:ClearAllPoints()
    holder:SetScale(1)
    holder:SetFrameStrata(frame:GetFrameStrata())
    holder:SetFrameLevel(math.max(frame:GetFrameLevel() + 20, (frame.Elements.HealthBar and frame.Elements.HealthBar:GetFrameLevel() + 10) or (frame:GetFrameLevel() + 20)))
    icon:ClearAllPoints()
    icon:SetScale(1)

    if options.enabled then
        local effectiveSize = options.size * options.scale
        holder:SetSize(effectiveSize, effectiveSize)
        icon:SetAllPoints(holder)

        if options.placement == "INSIDE" then
            if options.insideSide == "LEFT" then
                holder:SetPoint("TOPLEFT", frame, "TOPLEFT", options.borderInset + options.padding, -(options.borderInset + options.padding))
            else
                holder:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -(options.borderInset + options.padding), -(options.borderInset + options.padding))
            end
        else
            local anchorParent = owner:GetAnchorTarget(frame, options.anchorTo) or frame
            holder:SetPoint(
                options.point,
                anchorParent,
                options.relativePoint,
                options.offsetX,
                options.offsetY
            )
        end

        options.updateFunc(frame)
    else
        icon:SetTexture(nil)
        icon:Hide()
        holder:Hide()
    end
end

function Indicators.ApplyBatch(owner, frame, entries)
    if not entries then
        return
    end

    for _, entry in ipairs(entries) do
        Indicators.ApplyConfig(owner, frame, entry.holder, entry.options)
    end
end
