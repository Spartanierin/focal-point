local _, FocalPoint = ...

FocalPoint.UnitFrameIndicators = FocalPoint.UnitFrameIndicators or {}
local Indicators = FocalPoint.UnitFrameIndicators
local State = FocalPoint.UnitFrameState or {}
local Preview = FocalPoint.UnitFramePreview or {}
local RuntimeActivity = FocalPoint.UnitFrameRuntimeActivity or {}
local VisualIndicator = FocalPoint.UnitFrameVisualIndicator or {}

-- Shared helper logic for non-portrait overlay indicators such as leader,
-- role, combat, resting, and ready check.

local CONDITIONAL_INDICATORS = {
    RaidTargetIcon = true,
    LeaderIcon = true,
    RoleIcon = true,
    CombatIndicator = true,
    RestingIndicator = true,
    ReadyCheckIndicator = true,
    ClassificationIndicator = true,
}

local PRESENCE_GATED_INDICATORS = {
    RaidTargetIcon = true,
    LeaderIcon = true,
    RoleIcon = true,
    CombatIndicator = true,
    RestingIndicator = true,
    ReadyCheckIndicator = true,
}

local function IsEditorActive()
    return FocalPoint.framesUnlocked == true
        and FocalPoint.IsEditorActive
        and FocalPoint:IsEditorActive()
end

local function IsIndicatorEnabled(frame, indicatorKey)
    local config = frame and frame.config
    local indicatorConfig = type(config) == "table" and config[indicatorKey] or nil
    return type(indicatorConfig) == "table" and indicatorConfig.enabled ~= false
end

local function IsIndicatorPresent(frame, indicatorKey)
    local config = frame and frame.config
    local indicatorConfig = type(config) == "table" and config[indicatorKey] or nil
    return type(indicatorConfig) == "table" and indicatorConfig.present == true
end

local function ResolvePresencePolicy()
    return FocalPoint.EditorPresencePolicy
        or (FocalPoint.GUI and FocalPoint.GUI.Editor and FocalPoint.GUI.Editor.PresencePolicy)
        or nil
end

local function ShouldRepresentIndicator(frame, indicatorKey)
    if PRESENCE_GATED_INDICATORS[indicatorKey] and not IsIndicatorPresent(frame, indicatorKey) then
        return false
    end

    if not (IsEditorActive() and CONDITIONAL_INDICATORS[indicatorKey] and IsIndicatorEnabled(frame, indicatorKey)) then
        return false
    end

    local presencePolicy = ResolvePresencePolicy()
    if presencePolicy and type(presencePolicy.ResolveObject) == "function" then
        local resolved = presencePolicy.ResolveObject(frame and frame.unit, {
            kind = "indicator",
            unit = frame and frame.unit,
            indicatorKey = indicatorKey,
            objectKey = indicatorKey,
            sectionKey = "indicators",
        })
        return type(resolved) == "table" and resolved.isConditional == true
    end

    return true
end

function Indicators.ShouldRunPresenceGatedIndicator(frame, indicatorKey)
    if not PRESENCE_GATED_INDICATORS[indicatorKey] then
        return true
    end
    if RuntimeActivity.ShouldRunTableComponent then
        return RuntimeActivity.ShouldRunTableComponent(frame, indicatorKey)
    end
    return IsIndicatorPresent(frame, indicatorKey) and IsIndicatorEnabled(frame, indicatorKey)
end

function Indicators.HideIndicatorVisual(holder)
    Indicators.HideEditorPlaceholder(holder)
    local StatusOverlay = FocalPoint.UnitFrameStatusOverlay or nil
    if StatusOverlay and StatusOverlay.Hide then
        StatusOverlay.Hide(holder)
    end
    if VisualIndicator.Hide then
        VisualIndicator.Hide(holder)
    elseif holder then
        local icon = holder.Texture or holder
        if icon.SetTexture then
            icon:SetTexture(nil)
        end
        if icon.Hide then
            icon:Hide()
        end
        if holder.Hide then
            holder:Hide()
        end
    end
end

local function EnsurePlaceholder(holder)
    if not holder then
        return nil
    end

    if holder.EditorPlaceholder then
        return holder.EditorPlaceholder
    end

    local placeholder = CreateFrame("Frame", nil, holder)
    placeholder:SetAllPoints(holder)
    placeholder:EnableMouse(false)

    local fill = placeholder:CreateTexture(nil, "BACKGROUND", nil, 0)
    fill:SetTexture("Interface\\Buttons\\WHITE8X8")
    fill:SetVertexColor(0.06, 0.08, 0.10, 0.20)
    fill:SetAllPoints(placeholder)

    local borderColor = { 0.70, 0.76, 0.86, 0.42 }
    local top = placeholder:CreateTexture(nil, "OVERLAY", nil, 1)
    local bottom = placeholder:CreateTexture(nil, "OVERLAY", nil, 1)
    local left = placeholder:CreateTexture(nil, "OVERLAY", nil, 1)
    local right = placeholder:CreateTexture(nil, "OVERLAY", nil, 1)
    for _, texture in ipairs({ top, bottom, left, right }) do
        texture:SetTexture("Interface\\Buttons\\WHITE8X8")
        texture:SetVertexColor(borderColor[1], borderColor[2], borderColor[3], borderColor[4])
    end
    top:SetPoint("TOPLEFT", placeholder, "TOPLEFT", 0, 0)
    top:SetPoint("TOPRIGHT", placeholder, "TOPRIGHT", 0, 0)
    top:SetHeight(1)
    bottom:SetPoint("BOTTOMLEFT", placeholder, "BOTTOMLEFT", 0, 0)
    bottom:SetPoint("BOTTOMRIGHT", placeholder, "BOTTOMRIGHT", 0, 0)
    bottom:SetHeight(1)
    left:SetPoint("TOPLEFT", placeholder, "TOPLEFT", 0, 0)
    left:SetPoint("BOTTOMLEFT", placeholder, "BOTTOMLEFT", 0, 0)
    left:SetWidth(1)
    right:SetPoint("TOPRIGHT", placeholder, "TOPRIGHT", 0, 0)
    right:SetPoint("BOTTOMRIGHT", placeholder, "BOTTOMRIGHT", 0, 0)
    right:SetWidth(1)

    placeholder.Fill = fill
    placeholder.BorderTop = top
    placeholder.BorderBottom = bottom
    placeholder.BorderLeft = left
    placeholder.BorderRight = right
    placeholder:Hide()
    holder.EditorPlaceholder = placeholder
    return placeholder
end

function Indicators.HideEditorPlaceholder(holder)
    local placeholder = holder and holder.EditorPlaceholder
    if placeholder then
        placeholder:Hide()
    end
    if holder then
        holder._focalPointEditorPlaceholder = nil
    end
end

function Indicators.ShowEditorPlaceholder(frame, holder, indicatorKey)
    if not (frame and holder and ShouldRepresentIndicator(frame, indicatorKey)) then
        return false
    end

    if VisualIndicator.HideTexture then
        VisualIndicator.HideTexture(holder)
    elseif holder.Texture then
        holder.Texture:SetTexture(nil)
        holder.Texture:Hide()
    end

    local placeholder = EnsurePlaceholder(holder)
    if not placeholder then
        return false
    end

    holder._focalPointEditorPlaceholder = true
    holder:Show()
    placeholder:Show()
    return true
end

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

    if Preview.ShouldShowComponent and Preview.ShouldShowComponent("indicators", { frame = frame }) == false then
        isVisible = false
    end

    if not isVisible then
        if Indicators.ShowEditorPlaceholder(frame, holder, holder and holder._focalPointIndicatorKey) then
            if not wasShown then
                Indicators.QueueLayoutRefresh(owner, frame, stateKey)
            end
            return true
        end

        Indicators.HideEditorPlaceholder(holder)
        if VisualIndicator.Hide then
            VisualIndicator.Hide(holder)
        elseif holder then
            if holder.Texture then
                holder.Texture:SetTexture(nil)
                holder.Texture:Hide()
            end
            holder:Hide()
        end
        if wasShown then
            Indicators.QueueLayoutRefresh(owner, frame, stateKey)
        end
        return false
    end

    Indicators.HideEditorPlaceholder(holder)
    if VisualIndicator.Show then
        VisualIndicator.Show(holder)
    elseif holder then
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
    if VisualIndicator.CreateHolder then
        local holder = VisualIndicator.CreateHolder(frame, elementKey)
        if holder then
            holder._focalPointIndicatorKey = elementKey
        end
        return holder
    end
end

function Indicators.ApplyConfig(owner, frame, holder, options)
    if not holder then
        return
    end

    local icon = VisualIndicator.ResetHolderVisual and VisualIndicator.ResetHolderVisual(holder, frame) or holder.Texture or holder
    holder._focalPointIndicatorKey = options._elementKey or holder._focalPointIndicatorKey

    if options.enabled then
        if options.customLayout then
            if VisualIndicator.HideTexture then
                VisualIndicator.HideTexture(holder)
            elseif icon.SetTexture then
                icon:SetTexture(nil)
                icon:Hide()
            end
            options.updateFunc(frame)
            return
        end

        local effectiveSize = options.size * options.scale
        if VisualIndicator.ApplySquareBounds then
            VisualIndicator.ApplySquareBounds(holder, icon, effectiveSize)
        else
            holder:SetSize(effectiveSize, effectiveSize)
            icon:SetAllPoints(holder)
        end

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
        Indicators.HideIndicatorVisual(holder)
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
            and not options.customLayout
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
