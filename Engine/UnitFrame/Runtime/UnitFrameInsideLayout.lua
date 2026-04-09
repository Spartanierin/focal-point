local _, FocalPoint = ...

FocalPoint.UnitFrameInsideLayout = FocalPoint.UnitFrameInsideLayout or {}
local InsideLayout = FocalPoint.UnitFrameInsideLayout
local DEFAULT_LANE_SPACING = 3

-- Centralizes reserve bookkeeping for elements that live inside the frame,
-- health bar, or power bar. This keeps the orchestration layer from owning
-- low-level left/right reserve math inline.

local function GetEntryEffectiveSize(entry)
    local options = (entry and entry.options) or {}
    return (tonumber(options.size) or 0) * (tonumber(options.scale) or 1)
end

local function GetEntrySpacing(entry)
    local options = (entry and entry.options) or {}
    return math.max(tonumber(options.padding) or 0, 0)
end

function InsideLayout.AccumulateReserve(currentReserve, enabled, placement, insideSide, size, scale, padding)
    if not enabled or placement ~= "INSIDE" or not insideSide then
        return currentReserve or 0
    end

    local effectiveSize = (tonumber(size) or 0) * (tonumber(scale) or 1)
    local effectivePadding = tonumber(padding) or 0
    local requiredReserve = effectiveSize + effectivePadding
    return math.max(currentReserve or 0, requiredReserve)
end

function InsideLayout.ApplyReserveToArea(frameReserve, healthReserve, powerReserve, area, side, enabled, placement, size, scale, padding)
    if area == "HealthBar" then
        if side == "LEFT" then
            healthReserve.left = InsideLayout.AccumulateReserve(healthReserve.left, enabled, placement, side, size, scale, padding)
        else
            healthReserve.right = InsideLayout.AccumulateReserve(healthReserve.right, enabled, placement, side, size, scale, padding)
        end
        return
    end

    if area == "PowerBar" then
        if side == "LEFT" then
            powerReserve.left = InsideLayout.AccumulateReserve(powerReserve.left, enabled, placement, side, size, scale, padding)
        else
            powerReserve.right = InsideLayout.AccumulateReserve(powerReserve.right, enabled, placement, side, size, scale, padding)
        end
        return
    end

    if side == "LEFT" then
        frameReserve.left = InsideLayout.AccumulateReserve(frameReserve.left, enabled, placement, side, size, scale, padding)
    else
        frameReserve.right = InsideLayout.AccumulateReserve(frameReserve.right, enabled, placement, side, size, scale, padding)
    end
end

function InsideLayout.GetAreaReserveForVisibility(frameReserve, healthReserve, powerReserve, area)
    if area == "HealthBar" then
        return healthReserve
    end
    if area == "PowerBar" then
        return powerReserve
    end
    return frameReserve
end

function InsideLayout.ApplyVisibleReserve(frameReserve, healthReserve, powerReserve, area, side, holder, size, scale, padding)
    if not holder or not holder.IsShown or not holder:IsShown() then
        return
    end

    local targetReserve = InsideLayout.GetAreaReserveForVisibility(frameReserve, healthReserve, powerReserve, area)
    local effectiveSize = (tonumber(size) or 0) * (tonumber(scale) or 1)
    local effectivePadding = tonumber(padding) or 0
    local requiredReserve = effectiveSize + effectivePadding

    if side == "LEFT" then
        targetReserve.left = (targetReserve.left or 0) + requiredReserve
    else
        targetReserve.right = (targetReserve.right or 0) + requiredReserve
    end
end

function InsideLayout.ResolveAnchor(frame, area, reserves)
    reserves = reserves or {}

    if area == "HealthBar" and frame and frame.Elements and frame.Elements.HealthBar then
        return frame.Elements.HealthBar,
            math.max(tonumber(reserves.frameLeftReserve) or 0, tonumber(reserves.healthLeftReserve) or 0),
            math.max(tonumber(reserves.frameRightReserve) or 0, tonumber(reserves.healthRightReserve) or 0)
    end

    if area == "PowerBar" and frame and frame.Elements and frame.Elements.PowerBar and frame.Elements.PowerBar:IsShown() then
        return frame.Elements.PowerBar,
            math.max(tonumber(reserves.frameLeftReserve) or 0, tonumber(reserves.powerLeftReserve) or 0),
            math.max(tonumber(reserves.frameRightReserve) or 0, tonumber(reserves.powerRightReserve) or 0)
    end

    return frame, 0, 0
end

function InsideLayout.BuildHorizontalLaneBlock(entries)
    local block = {
        width = 0,
        items = {},
    }

    if not entries then
        return block
    end

    local visibleIndex = 0
    for _, entry in ipairs(entries) do
        local holder = entry and entry.holder
        local options = entry and entry.options or {}
        if holder
            and holder.IsShown
            and holder:IsShown()
            and options.enabled
            and not options.customLayout
            and options.placement == "INSIDE"
        then
            visibleIndex = visibleIndex + 1

            local spacingBefore = 0
            if visibleIndex > 1 then
                spacingBefore = DEFAULT_LANE_SPACING + GetEntrySpacing(entry)
                block.width = block.width + spacingBefore
            end

            local effectiveSize = GetEntryEffectiveSize(entry)
            local edgeOffset = block.width
            block.width = block.width + effectiveSize

            table.insert(block.items, {
                entry = entry,
                holder = holder,
                options = options,
                effectiveSize = effectiveSize,
                spacingBefore = spacingBefore,
                edgeOffset = edgeOffset,
            })
        end
    end

    return block
end

function InsideLayout.ApplyVisibleEntryReserves(frameReserve, healthReserve, powerReserve, entries)
    if not entries then
        return
    end

    local grouped = {}

    for _, entry in ipairs(entries) do
        local holder = entry and entry.holder
        local options = entry and entry.options or {}
        if holder
            and holder.IsShown
            and holder:IsShown()
            and options.enabled
            and options.placement == "INSIDE"
        then
            local area = options.insideAnchorTo or "Frame"
            local side = options.insideSide or "RIGHT"
            local key = tostring(area) .. ":" .. tostring(side)

            grouped[key] = grouped[key] or {
                area = area,
                side = side,
                entries = {},
            }
            table.insert(grouped[key].entries, entry)
        end
    end

    for _, group in pairs(grouped) do
        local block = InsideLayout.BuildHorizontalLaneBlock(group.entries)
        local targetReserve = InsideLayout.GetAreaReserveForVisibility(frameReserve, healthReserve, powerReserve, group.area)
        if group.side == "LEFT" then
            targetReserve.left = (targetReserve.left or 0) + block.width
        else
            targetReserve.right = (targetReserve.right or 0) + block.width
        end
    end
end

function InsideLayout.ApplyHorizontalLane(frame, entries, area, side)
    if not frame or not entries then
        return
    end

    local laneBlock = InsideLayout.BuildHorizontalLaneBlock(entries)
    local sampleOptions = entries[1] and entries[1].options or {}
    local areaParent = select(1, InsideLayout.ResolveAnchor(frame, area, sampleOptions))
    areaParent = areaParent or frame

    local laneYOffset = 0
    if areaParent and areaParent.GetCenter and frame.GetCenter then
        local _, anchorY = areaParent:GetCenter()
        local _, frameY = frame:GetCenter()
        if anchorY and frameY then
            laneYOffset = anchorY - frameY
        end
    end

    local horizontalAnchor = frame
    local horizontalInset = tonumber(sampleOptions.borderInset) or 0
    if area == "HealthBar" or area == "PowerBar" then
        if side == "LEFT" then
            horizontalInset = horizontalInset + (tonumber(sampleOptions.frameLeftReserve) or 0)
        else
            horizontalInset = horizontalInset + (tonumber(sampleOptions.frameRightReserve) or 0)
        end
    end

    local previousHolder = nil

    for _, item in ipairs(laneBlock.items) do
        local holder = item.holder
        local options = item.options or {}
        holder:ClearAllPoints()

        if side == "LEFT" then
            if previousHolder then
                holder:SetPoint("LEFT", previousHolder, "RIGHT", item.spacingBefore, 0)
            else
                holder:SetPoint("LEFT", horizontalAnchor, "LEFT", horizontalInset, laneYOffset)
            end
        else
            if previousHolder then
                holder:SetPoint("RIGHT", previousHolder, "LEFT", -item.spacingBefore, 0)
            else
                holder:SetPoint("RIGHT", horizontalAnchor, "RIGHT", -horizontalInset, laneYOffset)
            end
        end

        previousHolder = holder
    end
end
