local _, FocalPoint = ...

FocalPoint.UnitFrameIndicators = FocalPoint.UnitFrameIndicators or {}
local Indicators = FocalPoint.UnitFrameIndicators
local State = FocalPoint.UnitFrameState or {}

-- Shared helper logic for non-portrait overlay indicators such as leader,
-- role, combat, resting, and ready check.

local function GetInsideLayout()
    return FocalPoint.UnitFrameInsideLayout or {}
end

local function ResolveHorizontalLaneSide(options)
    options = options or {}

    if options.placement == "INSIDE" then
        return options.insideSide or "RIGHT"
    end

    local point = tostring(options.point or "")
    local relativePoint = tostring(options.relativePoint or "")

    if string.find(point, "RIGHT", 1, true) or string.find(relativePoint, "RIGHT", 1, true) then
        return "RIGHT"
    end

    if string.find(point, "LEFT", 1, true) or string.find(relativePoint, "LEFT", 1, true) then
        return "LEFT"
    end

    return nil
end

local function GetInsideAnchor(holderFrame, options)
    local area = options.insideAnchorTo or "Frame"
    if area == "HealthBar" and holderFrame.Elements and holderFrame.Elements.HealthBar then
        return holderFrame.Elements.HealthBar, math.max(options.frameLeftReserve or 0, options.healthLeftReserve or 0), math.max(options.frameRightReserve or 0, options.healthRightReserve or 0)
    end
    if area == "PowerBar" and holderFrame.Elements and holderFrame.Elements.PowerBar and holderFrame.Elements.PowerBar:IsShown() then
        return holderFrame.Elements.PowerBar, math.max(options.frameLeftReserve or 0, options.powerLeftReserve or 0), math.max(options.frameRightReserve or 0, options.powerRightReserve or 0)
    end
    return holderFrame, 0, 0
end

function Indicators.QueueLayoutRefresh(owner, frame, stateKey)
    if not owner or not frame then
        return
    end

    stateKey = stateKey or "_overlayLayoutRefreshQueued"
    if frame[stateKey] then
        return
    end

    frame[stateKey] = true

    if State.QueueRefresh then
        State.QueueRefresh(frame, "indicator_layout", "layout")
        C_Timer.After(0.01, function()
            if frame then
                frame[stateKey] = nil
            end
        end)
        return
    end

    C_Timer.After(0, function()
        if frame then
            frame[stateKey] = nil
        end

        if owner and frame and frame.config and owner.ApplyConfig then
            owner:ApplyConfig(frame)
        end
    end)
end

function Indicators.HandleVisibilityTransition(owner, frame, holder, isVisible, stateKey)
    local wasShown = holder and holder.IsShown and holder:IsShown() or false

    if not isVisible then
        if holder and holder.Texture then
            holder.Texture:SetTexture(nil)
            holder.Texture:Hide()
        end
        if holder then
            holder:Hide()
        end
        if wasShown then
            Indicators.QueueLayoutRefresh(owner, frame, stateKey)
        end
        return false
    end

    if holder then
        holder:Show()
        if holder.Texture then
            holder.Texture:Show()
        end
    end

    if not wasShown then
        Indicators.QueueLayoutRefresh(owner, frame, stateKey)
    end

    return true
end

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
            local anchorParent, leftReserve, rightReserve = GetInsideAnchor(frame, options)
            if options.insideSide == "LEFT" then
                holder:SetPoint("TOPLEFT", anchorParent, "TOPLEFT", -leftReserve + options.padding, -(options.borderInset or 0))
            else
                holder:SetPoint("TOPRIGHT", anchorParent, "TOPRIGHT", rightReserve - options.padding, -(options.borderInset or 0))
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

    local insideGroups = {}
    local attachedGroups = {}

    for _, entry in ipairs(entries) do
        local holder = entry.holder
        local options = entry.options or {}
        if holder
            and holder.IsShown
            and holder:IsShown()
            and options.enabled
        then
            if options.placement == "INSIDE" then
                local groupKey = table.concat({
                    tostring(options.insideAnchorTo or "Frame"),
                    tostring(options.insideSide or "RIGHT"),
                }, ":")

                local group = insideGroups[groupKey]
                if not group then
                    group = {
                        entries = {},
                    }
                    insideGroups[groupKey] = group
                end

                table.insert(group.entries, {
                    holder = holder,
                    options = options,
                })
            else
                local laneSide = ResolveHorizontalLaneSide(options)
                if laneSide then
                    local groupKey = table.concat({
                        tostring(laneSide),
                    }, ":")

                    local group = attachedGroups[groupKey]
                    if not group then
                        group = {
                            entries = {},
                        }
                        attachedGroups[groupKey] = group
                    end

                    table.insert(group.entries, {
                        holder = holder,
                        options = options,
                    })
                end
            end
        end
    end

    for groupKey, group in pairs(insideGroups) do
        local insideLayout = GetInsideLayout()
        local applyHorizontalLane = insideLayout.ApplyHorizontalLane
        local buildHorizontalLaneBlock = insideLayout.BuildHorizontalLaneBlock

        local laneArea, laneSide = string.match(groupKey, "^(.-):([^:]+)$")
        if applyHorizontalLane then
            applyHorizontalLane(frame, group.entries, laneArea, laneSide)
        else
            local laneBlock = buildHorizontalLaneBlock and buildHorizontalLaneBlock(group.entries) or { width = 0, items = {} }
            local previousHolder = nil

            for _, item in ipairs(laneBlock.items) do
                local holder = item.holder
                local options = item.options
                holder:ClearAllPoints()

                if laneSide == "LEFT" then
                    if previousHolder then
                        holder:SetPoint("LEFT", previousHolder, "RIGHT", item.spacingBefore, 0)
                    else
                        holder:SetPoint("LEFT", frame, "LEFT", (options.borderInset or 0), 0)
                    end
                else
                    if previousHolder then
                        holder:SetPoint("RIGHT", previousHolder, "LEFT", -item.spacingBefore, 0)
                    else
                        holder:SetPoint("RIGHT", frame, "RIGHT", -(options.borderInset or 0), 0)
                    end
                end

                previousHolder = holder
            end
        end
    end

    for _, group in pairs(attachedGroups) do
        if #group.entries > 1 then
            local insideLayout = GetInsideLayout()
            local buildHorizontalLaneBlock = insideLayout.BuildHorizontalLaneBlock
            local laneBlock = buildHorizontalLaneBlock and buildHorizontalLaneBlock(group.entries) or { items = {} }
            local previousHolder = nil
            local firstOptions = group.entries[1] and group.entries[1].options or {}
            local firstAnchor = owner:GetAnchorTarget(frame, firstOptions.anchorTo) or frame
            local firstPoint = firstOptions.point or "CENTER"
            local firstRelativePoint = firstOptions.relativePoint or "CENTER"
            local firstOffsetX = tonumber(firstOptions.offsetX) or 0
            local firstOffsetY = tonumber(firstOptions.offsetY) or 0
            local laneSide = ResolveHorizontalLaneSide(firstOptions)

            for _, item in ipairs(laneBlock.items) do
                local holder = item.holder
                holder:ClearAllPoints()

                if not previousHolder then
                    holder:SetPoint(firstPoint, firstAnchor, firstRelativePoint, firstOffsetX, firstOffsetY)
                elseif laneSide == "RIGHT" then
                    holder:SetPoint("RIGHT", previousHolder, "LEFT", -item.spacingBefore, 0)
                else
                    holder:SetPoint("LEFT", previousHolder, "RIGHT", item.spacingBefore, 0)
                end

                previousHolder = holder
            end
        end
    end
end
