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

    return renderConfig, layoutConfig
end

local function IsEditorAuraPlaceholderAllowed(frame)
    if not (FocalPoint and FocalPoint.framesUnlocked == true) then
        return false
    end
    if FocalPoint.guiTestModeEnabled == true then
        return false
    end
    if not (FocalPoint.IsEditorActive and FocalPoint:IsEditorActive()) then
        return false
    end

    local Preview = FocalPoint.UnitFramePreview or {}
    if Preview.ShouldShowComponent and Preview.ShouldShowComponent("auras", { frame = frame }) == false then
        return false
    end

    return true
end

local function GetGroupLabel(groupKey)
    if groupKey == "Buffs" then
        return "Buffs"
    end
    if groupKey == "Debuffs" then
        return "Debuffs"
    end
    return tostring(groupKey or "Auras")
end

local function EnsurePlaceholder(groupFrame)
    if not groupFrame then
        return nil
    end
    if groupFrame.Placeholder then
        return groupFrame.Placeholder
    end

    local placeholder = CreateFrame("Frame", nil, groupFrame, "BackdropTemplate")
    placeholder:SetAllPoints(groupFrame)
    placeholder:EnableMouse(false)
    if placeholder.SetBackdrop then
        placeholder:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Buttons\\WHITE8X8",
            edgeSize = 1,
            insets = { left = 0, right = 0, top = 0, bottom = 0 },
        })
        placeholder:SetBackdropColor(0.06, 0.08, 0.10, 0.20)
        placeholder:SetBackdropBorderColor(0.70, 0.76, 0.86, 0.38)
    end

    local label = placeholder:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    label:SetPoint("CENTER", placeholder, "CENTER", 0, 0)
    label:SetJustifyH("CENTER")
    label:SetTextColor(0.72, 0.78, 0.88, 0.72)
    label:SetShadowColor(0, 0, 0, 0.85)
    label:SetShadowOffset(1, -1)
    placeholder.Label = label

    placeholder:Hide()
    groupFrame.Placeholder = placeholder
    return placeholder
end

local function HidePlaceholder(groupFrame)
    local placeholder = groupFrame and groupFrame.Placeholder
    if not placeholder then
        return
    end
    if placeholder.Label then
        placeholder.Label:SetText("")
    end
    placeholder:Hide()
end

local function ClearPooledContainers(groupFrame)
    if not (groupFrame and groupFrame.pool) then
        return
    end

    for _, container in ipairs(groupFrame.pool) do
        local AuraContainer = GetAuraContainer()
        if AuraContainer.Clear then
            AuraContainer.Clear(container)
        end
    end
end

local function ResolvePlaceholderAuraCount(config)
    local iconsPerRow = math.max(math.floor(tonumber(config and config.iconsPerRow) or 1), 1)
    local maxRows = math.max(math.floor(tonumber(config and config.maxRows) or 1), 1)
    return math.max(1, iconsPerRow * maxRows)
end

function AuraRenderer.ShowGeometryPlaceholder(frame, groupKey, renderConfig, layoutConfig)
    if not (frame and frame.Elements and IsEditorAuraPlaceholderAllowed(frame)) then
        return false
    end

    local groupFrame = frame.Elements[groupKey]
    if not groupFrame then
        return false
    end

    local AuraBlockLayout = GetAuraBlockLayout()
    if AuraBlockLayout.ApplyAnchor then
        AuraBlockLayout.ApplyAnchor(groupFrame, frame, renderConfig, groupKey)
    end

    local placeholderCount = ResolvePlaceholderAuraCount(layoutConfig)
    local metrics = AuraBlockLayout.CalculateMetrics and AuraBlockLayout.CalculateMetrics(placeholderCount, layoutConfig) or nil
    local width = math.max(1, tonumber(metrics and metrics.blockWidth) or tonumber(layoutConfig and layoutConfig.iconSize) or 1)
    local height = math.max(1, tonumber(metrics and metrics.blockHeight) or tonumber(layoutConfig and layoutConfig.iconSize) or 1)

    ClearPooledContainers(groupFrame)
    groupFrame:SetSize(width, height)

    local placeholder = EnsurePlaceholder(groupFrame)
    if not placeholder then
        return false
    end
    placeholder:ClearAllPoints()
    placeholder:SetAllPoints(groupFrame)
    if placeholder.Label then
        placeholder.Label:SetText(GetGroupLabel(groupKey))
    end
    placeholder:Show()
    groupFrame:Show()

    groupFrame.RuntimeState = groupFrame.RuntimeState or {}
    groupFrame.RuntimeState.phase = "editor_placeholder"
    groupFrame.RuntimeState.renderedCount = 0
    groupFrame.RuntimeState.placeholderCount = placeholderCount
    groupFrame.RuntimeState.lastReason = "editor-placeholder"

    return true
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
        if AuraRenderer.ShowGeometryPlaceholder(frame, groupKey, renderConfig, layoutConfig) then
            return
        end
        AuraRenderer.ClearGroup(frame, groupKey)
        return
    end

    HidePlaceholder(groupFrame)
    AuraRenderer.EnsurePool(groupFrame, metrics.shownCount)

    if AuraBlockLayout.ApplyAnchor then
        AuraBlockLayout.ApplyAnchor(groupFrame, frame, renderConfig, groupKey)
    end

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

    HidePlaceholder(groupFrame)
    ClearPooledContainers(groupFrame)

    groupFrame.RuntimeState.phase = "empty_valid"
    groupFrame.RuntimeState.renderedCount = 0
    groupFrame.RuntimeState.lastReason = "clear"
    if Demo.IsFrameInDemoMode and Demo.IsFrameInDemoMode(frame) and Demo.TouchDebug then
        Demo.TouchDebug(frame, "auraClear")
    end
    groupFrame:Hide()
end

AuraRenderer.ResetGroup = AuraRenderer.ClearGroup
