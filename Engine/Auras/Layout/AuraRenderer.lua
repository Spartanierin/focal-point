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

local function CopyConfig(config)
    local result = {}
    for key, value in pairs(config or {}) do
        result[key] = value
    end
    return result
end

local function ResolveRenderConfigs(frame, groupKey, config)
    local BackendResolver = FocalPoint.AuraBackendResolver or {}
    if not (BackendResolver.ShouldUseManagedEditorVisuals and BackendResolver.ShouldUseManagedEditorVisuals(frame, groupKey)) then
        return config, config
    end

    local renderConfig = CopyConfig(config)
    renderConfig._fpUseManagedVisuals = true

    local layoutConfig = CopyConfig(config)
    layoutConfig._fpUseManagedVisuals = true
    layoutConfig.showTimerText = false

    return renderConfig, layoutConfig
end

local function ResolveAnchorOffsets(config)
    config = config or {}

    local offsetX = tonumber(config.offsetX) or 0
    local offsetY = tonumber(config.offsetY) or 0
    local placement = config.placement or "ATTACHED"

    if placement ~= "INSIDE" then
        local blockGapX = tonumber(config.blockGapX)
        if blockGapX == nil then
            blockGapX = 4
        end

        local relativePoint = config.relativePoint or config.point or "TOPLEFT"
        if type(relativePoint) == "string" then
            if string.find(relativePoint, "RIGHT", 1, true) then
                offsetX = offsetX + blockGapX
            elseif string.find(relativePoint, "LEFT", 1, true) then
                offsetX = offsetX - blockGapX
            end
        end
    end

    return offsetX, offsetY
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
        groupFrame.RuntimeState = {
            phase = "cold",
            renderedCount = 0,
            lastReason = nil,
        }
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
    local Demo = FocalPoint.UnitFrameDemoEnvironment or {}

    local groupFrame = frame.Elements[groupKey]
    if not groupFrame or not config or config.enabled == false then
        AuraRenderer.ClearGroup(frame, groupKey)
        return
    end

    local AuraBlockLayout = GetAuraBlockLayout()
    local renderConfig, layoutConfig = ResolveRenderConfigs(frame, groupKey, config)
    local metrics = AuraBlockLayout.CalculateMetrics and AuraBlockLayout.CalculateMetrics(type(auraList) == "table" and #auraList or 0, layoutConfig) or {
        shownCount = 0,
    }
    if metrics.shownCount <= 0 then
        AuraRenderer.ClearGroup(frame, groupKey)
        return
    end

    AuraRenderer.EnsurePool(groupFrame, metrics.shownCount)

    local AuraAnchor = GetAuraAnchor()
    local anchorTarget = AuraAnchor.Resolve and AuraAnchor.Resolve(frame, config, groupKey) or frame
    local offsetX, offsetY = ResolveAnchorOffsets(renderConfig)
    groupFrame:ClearAllPoints()
    groupFrame:SetPoint(
        renderConfig.point or "TOPLEFT",
        anchorTarget,
        renderConfig.relativePoint or renderConfig.point or "TOPLEFT",
        offsetX,
        offsetY
    )

    if AuraBlockLayout.Apply then
        AuraBlockLayout.Apply(groupFrame, auraList, layoutConfig)
    end

    for index = 1, metrics.shownCount do
        local container = groupFrame.pool[index]
        local aura = auraList[index]
        local AuraContainer = GetAuraContainer()
        if AuraContainer.ApplyData then
            AuraContainer.ApplyData(container, aura, renderConfig)
        end
    end

    for index = metrics.shownCount + 1, #groupFrame.pool do
        local AuraContainer = GetAuraContainer()
        if AuraContainer.Clear then
            AuraContainer.Clear(groupFrame.pool[index])
        end
    end

    groupFrame:Show()
    if Demo.IsFrameInDemoMode and Demo.IsFrameInDemoMode(frame) and Demo.TouchDebug then
        Demo.TouchDebug(frame, "auraRender")
    end
    groupFrame.RuntimeState = groupFrame.RuntimeState or {}
    groupFrame.RuntimeState.phase = "rendered"
    groupFrame.RuntimeState.renderedCount = metrics.shownCount
    groupFrame.RuntimeState.lastReason = "render"

    if State.Guard then
        State.Guard(frame, "aura_group_visible_without_items", metrics.shownCount > 0, string.format("group=%s", tostring(groupKey)))
    end
end

function AuraRenderer.ClearGroup(frame, groupKey)
    if not frame or not frame.Elements or not frame.Elements[groupKey] then
        return
    end
    local Demo = FocalPoint.UnitFrameDemoEnvironment or {}

    local groupFrame = frame.Elements[groupKey]
    groupFrame.RuntimeState = groupFrame.RuntimeState or {}
    if groupFrame.RuntimeState.phase == "empty_valid"
        and (tonumber(groupFrame.RuntimeState.renderedCount) or 0) == 0
        and (not groupFrame.IsShown or not groupFrame:IsShown())
    then
        return
    end

    if groupFrame.pool then
        for _, container in ipairs(groupFrame.pool) do
            local AuraContainer = GetAuraContainer()
            if AuraContainer.Clear then
                AuraContainer.Clear(container)
            end
        end
    end

    groupFrame.RuntimeState.phase = "empty_valid"
    groupFrame.RuntimeState.renderedCount = 0
    groupFrame.RuntimeState.lastReason = "clear"
    if Demo.IsFrameInDemoMode and Demo.IsFrameInDemoMode(frame) and Demo.TouchDebug then
        Demo.TouchDebug(frame, "auraClear")
    end
    groupFrame:Hide()
end

AuraRenderer.ResetGroup = AuraRenderer.ClearGroup
