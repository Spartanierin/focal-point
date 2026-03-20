local _, FocalPoint = ...

FocalPoint.AuraAnchor = FocalPoint.AuraAnchor or {}
local AuraAnchor = FocalPoint.AuraAnchor

-- Resolves attached and inside anchor targets for aura blocks.

function AuraAnchor.Resolve(frame, config, groupKey)
    if not frame then
        return nil, "Frame"
    end

    config = config or {}
    local placement = config.placement or "ATTACHED"
    local anchorTo = placement == "INSIDE" and (config.insideAnchorTo or "Frame") or (config.anchorTo or "Frame")

    if anchorTo == "HealthBar" then
        return frame.Elements and frame.Elements.HealthBar or frame, anchorTo
    end

    if anchorTo == "PowerBar" then
        return frame.Elements and frame.Elements.PowerBar or frame, anchorTo
    end

    return frame, anchorTo
end
