local _, FocalPoint = ...

FocalPoint.AuraRenderer = FocalPoint.AuraRenderer or {}
local AuraRenderer = FocalPoint.AuraRenderer
local State = FocalPoint.UnitFrameState or {}

local function GetAuraContainer()
    return FocalPoint.AuraContainer or {}
end

local function GetAuraBlockLayout()
    return FocalPoint.AuraBlockLayout or {}
end

local function GetAuraAnchor()
    return FocalPoint.AuraAnchor or {}
end

-- Maps prepared aura records onto reusable aura containers.

function AuraRenderer.Build(frame)
    if not frame then
        return
    end

    frame.Elements = frame.Elements or {}

    local function EnsureGroup(groupKey, frameLevelOffset)
        if frame.Elements[groupKey] then
            return frame.Elements[groupKey]
        end

        local groupFrame = CreateFrame("Frame", nil, frame)
        groupFrame:SetFrameStrata(frame:GetFrameStrata())
        groupFrame:SetFrameLevel(frame:GetFrameLevel() + frameLevelOffset)
        groupFrame:EnableMouse(false)
        groupFrame.pool = {}
        groupFrame.groupKey = groupKey
        groupFrame:Hide()

        frame.Elements[groupKey] = groupFrame
        return groupFrame
    end

    EnsureGroup("Buffs", 25)
    EnsureGroup("Debuffs", 26)
end

function AuraRenderer.EnsurePool(groupFrame, requiredCount)
    if not groupFrame then
        return
    end

    groupFrame.pool = groupFrame.pool or {}
    while #groupFrame.pool < requiredCount do
        local AuraContainer = GetAuraContainer()
        local container = AuraContainer.Create and AuraContainer.Create(groupFrame)
        groupFrame.pool[#groupFrame.pool + 1] = container
    end
end

function AuraRenderer.RenderGroup(frame, groupKey, auraList, config)
    if not frame or not frame.Elements then
        return
    end

    local groupFrame = frame.Elements[groupKey]
    if not groupFrame or not config or config.enabled == false then
        AuraRenderer.ClearGroup(frame, groupKey)
        return
    end

    local AuraBlockLayout = GetAuraBlockLayout()
    local metrics = AuraBlockLayout.CalculateMetrics and AuraBlockLayout.CalculateMetrics(type(auraList) == "table" and #auraList or 0, config) or {
        shownCount = 0,
    }
    if metrics.shownCount <= 0 then
        AuraRenderer.ClearGroup(frame, groupKey)
        return
    end

    AuraRenderer.EnsurePool(groupFrame, metrics.shownCount)

    local AuraAnchor = GetAuraAnchor()
    local anchorTarget = AuraAnchor.Resolve and AuraAnchor.Resolve(frame, config, groupKey) or frame
    groupFrame:ClearAllPoints()
    groupFrame:SetPoint(
        config.point or "TOPLEFT",
        anchorTarget,
        config.relativePoint or config.point or "TOPLEFT",
        tonumber(config.offsetX) or 0,
        tonumber(config.offsetY) or 0
    )

    if AuraBlockLayout.Apply then
        AuraBlockLayout.Apply(groupFrame, auraList, config)
    end

    for index = 1, metrics.shownCount do
        local container = groupFrame.pool[index]
        local aura = auraList[index]
        local AuraContainer = GetAuraContainer()
        if AuraContainer.ApplyData then
            AuraContainer.ApplyData(container, aura, config)
        end
    end

    for index = metrics.shownCount + 1, #groupFrame.pool do
        local AuraContainer = GetAuraContainer()
        if AuraContainer.Clear then
            AuraContainer.Clear(groupFrame.pool[index])
        end
    end

    groupFrame:Show()

    if State.Guard then
        State.Guard(frame, "aura_group_visible_without_items", metrics.shownCount > 0, string.format("group=%s", tostring(groupKey)))
    end
end

function AuraRenderer.ClearGroup(frame, groupKey)
    if not frame or not frame.Elements or not frame.Elements[groupKey] then
        return
    end

    local groupFrame = frame.Elements[groupKey]
    if groupFrame.pool then
        for _, container in ipairs(groupFrame.pool) do
            local AuraContainer = GetAuraContainer()
            if AuraContainer.Clear then
                AuraContainer.Clear(container)
            end
        end
    end

    groupFrame:Hide()
end

AuraRenderer.ResetGroup = AuraRenderer.ClearGroup
