local _, FocalPoint = ...

FocalPoint.ManagedAuraBackend = FocalPoint.ManagedAuraBackend or {}
local Managed = FocalPoint.ManagedAuraBackend

local AuraAnchor = FocalPoint.AuraAnchor or {}
local AuraBlockLayout = FocalPoint.AuraBlockLayout or {}

local CONTAINER_TEMPLATE = "CustomAuraContainerTemplate"
local DEFAULT_MAX_FRAME_COUNT = 40
local GROUP_DEFINITIONS = {
    player = {
        Buffs = {
            auraGroupKey = "FocalPointPlayerBuffs",
            filter = "HELPFUL",
            filterClass = "helpful",
            stateKey = "PlayerBuffs",
            elementKey = "ManagedBuffs",
            label = "BUFFS",
            color = { 0.1, 0.85, 0.25, 0.28 },
            textColor = { 0.55, 1, 0.65, 1 },
        },
        Debuffs = {
            auraGroupKey = "FocalPointPlayerDebuffs",
            filter = "HARMFUL",
            filterClass = "harmful",
            stateKey = "PlayerDebuffs",
            elementKey = "ManagedDebuffs",
            label = "DEBUFFS",
            color = { 0.95, 0.12, 0.12, 0.28 },
            textColor = { 1, 0.55, 0.55, 1 },
        },
    },
    target = {
        Buffs = {
            auraGroupKey = "FocalPointTargetBuffs",
            filter = "HELPFUL",
            filterClass = "helpful",
            stateKey = "TargetBuffs",
            elementKey = "ManagedTargetBuffs",
            label = "TARGET BUFFS",
            color = { 0.15, 0.55, 1, 0.28 },
            textColor = { 0.62, 0.82, 1, 1 },
        },
        Debuffs = {
            auraGroupKey = "FocalPointTargetDebuffs",
            filter = "HARMFUL",
            filterClass = "harmful",
            stateKey = "TargetDebuffs",
            elementKey = "ManagedTargetDebuffs",
            label = "TARGET DEBUFFS",
            color = { 0.95, 0.22, 0.18, 0.28 },
            textColor = { 1, 0.6, 0.55, 1 },
        },
    },
    focus = {
        Buffs = {
            auraGroupKey = "FocalPointFocusBuffs",
            filter = "HELPFUL",
            filterClass = "helpful",
            stateKey = "FocusBuffs",
            elementKey = "ManagedFocusBuffs",
            label = "FOCUS BUFFS",
            color = { 0.45, 0.35, 1, 0.28 },
            textColor = { 0.78, 0.72, 1, 1 },
        },
        Debuffs = {
            auraGroupKey = "FocalPointFocusDebuffs",
            filter = "HARMFUL",
            filterClass = "harmful",
            stateKey = "FocusDebuffs",
            elementKey = "ManagedFocusDebuffs",
            label = "FOCUS DEBUFFS",
            color = { 0.95, 0.22, 0.42, 0.28 },
            textColor = { 1, 0.62, 0.72, 1 },
        },
    },
    focustarget = {
        Buffs = {
            auraGroupKey = "FocalPointFocusTargetBuffs",
            filter = "HELPFUL",
            filterClass = "helpful",
            stateKey = "FocusTargetBuffs",
            elementKey = "ManagedFocusTargetBuffs",
            label = "FOCUS TARGET BUFFS",
            color = { 0.35, 0.55, 1, 0.24 },
            textColor = { 0.72, 0.84, 1, 1 },
        },
        Debuffs = {
            auraGroupKey = "FocalPointFocusTargetDebuffs",
            filter = "HARMFUL",
            filterClass = "harmful",
            stateKey = "FocusTargetDebuffs",
            elementKey = "ManagedFocusTargetDebuffs",
            label = "FOCUS TARGET DEBUFFS",
            color = { 0.95, 0.22, 0.32, 0.24 },
            textColor = { 1, 0.6, 0.65, 1 },
        },
    },
    targettarget = {
        Buffs = {
            auraGroupKey = "FocalPointTargetTargetBuffs",
            filter = "HELPFUL",
            filterClass = "helpful",
            stateKey = "TargetTargetBuffs",
            elementKey = "ManagedTargetTargetBuffs",
            label = "TOT BUFFS",
            color = { 0.15, 0.65, 1, 0.24 },
            textColor = { 0.68, 0.88, 1, 1 },
        },
        Debuffs = {
            auraGroupKey = "FocalPointTargetTargetDebuffs",
            filter = "HARMFUL",
            filterClass = "harmful",
            stateKey = "TargetTargetDebuffs",
            elementKey = "ManagedTargetTargetDebuffs",
            label = "TOT DEBUFFS",
            color = { 0.95, 0.22, 0.18, 0.24 },
            textColor = { 1, 0.6, 0.55, 1 },
        },
    },
}

local BOSS_BUFF_DEFINITIONS = {
    boss1 = {
        auraGroupKey = "FocalPointBoss1Buffs",
        stateKey = "Boss1Buffs",
        elementKey = "ManagedBoss1Buffs",
        label = "BOSS1 BUFFS",
    },
    boss2 = {
        auraGroupKey = "FocalPointBoss2Buffs",
        stateKey = "Boss2Buffs",
        elementKey = "ManagedBoss2Buffs",
        label = "BOSS2 BUFFS",
    },
    boss3 = {
        auraGroupKey = "FocalPointBoss3Buffs",
        stateKey = "Boss3Buffs",
        elementKey = "ManagedBoss3Buffs",
        label = "BOSS3 BUFFS",
    },
    boss4 = {
        auraGroupKey = "FocalPointBoss4Buffs",
        stateKey = "Boss4Buffs",
        elementKey = "ManagedBoss4Buffs",
        label = "BOSS4 BUFFS",
    },
    boss5 = {
        auraGroupKey = "FocalPointBoss5Buffs",
        stateKey = "Boss5Buffs",
        elementKey = "ManagedBoss5Buffs",
        label = "BOSS5 BUFFS",
    },
}

local BOSS_DEBUFF_DEFINITIONS = {
    boss1 = {
        auraGroupKey = "FocalPointBoss1Debuffs",
        stateKey = "Boss1Debuffs",
        elementKey = "ManagedBoss1Debuffs",
        label = "BOSS1 DEBUFFS",
    },
    boss2 = {
        auraGroupKey = "FocalPointBoss2Debuffs",
        stateKey = "Boss2Debuffs",
        elementKey = "ManagedBoss2Debuffs",
        label = "BOSS2 DEBUFFS",
    },
    boss3 = {
        auraGroupKey = "FocalPointBoss3Debuffs",
        stateKey = "Boss3Debuffs",
        elementKey = "ManagedBoss3Debuffs",
        label = "BOSS3 DEBUFFS",
    },
    boss4 = {
        auraGroupKey = "FocalPointBoss4Debuffs",
        stateKey = "Boss4Debuffs",
        elementKey = "ManagedBoss4Debuffs",
        label = "BOSS4 DEBUFFS",
    },
    boss5 = {
        auraGroupKey = "FocalPointBoss5Debuffs",
        stateKey = "Boss5Debuffs",
        elementKey = "ManagedBoss5Debuffs",
        label = "BOSS5 DEBUFFS",
    },
}

for unit, bossDefinition in pairs(BOSS_BUFF_DEFINITIONS) do
    GROUP_DEFINITIONS[unit] = {
        Buffs = {
            auraGroupKey = bossDefinition.auraGroupKey,
            filter = "HELPFUL",
            filterClass = "helpful",
            stateKey = bossDefinition.stateKey,
            elementKey = bossDefinition.elementKey,
            label = bossDefinition.label,
            color = { 0.9, 0.62, 0.18, 0.28 },
            textColor = { 1, 0.82, 0.5, 1 },
        },
        Debuffs = {
            auraGroupKey = BOSS_DEBUFF_DEFINITIONS[unit].auraGroupKey,
            filter = "HARMFUL",
            filterClass = "harmful",
            stateKey = BOSS_DEBUFF_DEFINITIONS[unit].stateKey,
            elementKey = BOSS_DEBUFF_DEFINITIONS[unit].elementKey,
            label = BOSS_DEBUFF_DEFINITIONS[unit].label,
            color = { 0.95, 0.18, 0.18, 0.28 },
            textColor = { 1, 0.58, 0.58, 1 },
        },
    }
end

local function GetGroupDefinition(unit, groupKey)
    local unitDefinitions = GROUP_DEFINITIONS[unit]
    return unitDefinitions and unitDefinitions[groupKey] or nil
end

local function IsDerivedManagedGroup(unit, groupKey)
    return (unit == "targettarget" or unit == "focustarget") and (groupKey == "Buffs" or groupKey == "Debuffs")
end

local function GetDerivedCounterPrefix(unit, groupKey)
    local unitPrefix
    if unit == "targettarget" then
        unitPrefix = "targetTarget"
    elseif unit == "focustarget" then
        unitPrefix = "focusTarget"
    else
        return nil
    end

    if groupKey == "Buffs" then
        return unitPrefix .. "BuffsUpdateAll"
    end
    if groupKey == "Debuffs" then
        return unitPrefix .. "DebuffsUpdateAll"
    end
    return nil
end

local function GetDerivedErrorCounter(unit)
    if unit == "targettarget" then
        return "targetTargetUpdateAllErrors"
    end
    if unit == "focustarget" then
        return "focusTargetUpdateAllErrors"
    end
    return nil
end

local function RecordDiagnostic(unit, group, decision, groupCount, backendStatus, state)
    local AuraDiagnostics = FocalPoint and FocalPoint.AuraDiagnostics or nil
    local definition = GetGroupDefinition(unit, group)
    if AuraDiagnostics and AuraDiagnostics.Record then
        AuraDiagnostics.Record({
            unit = unit,
            group = group,
            source = "AURA_BACKEND",
            backend = "managed",
            decision = decision,
            filterClass = definition and definition.filterClass or "-",
            backendStatus = backendStatus or "unknown",
            groupCount = groupCount or 0,
            containerCreated = state and state.container ~= nil or false,
            groupRegistered = state and state.configured == true or false,
        })
    end
end

local function ToPositiveNumber(value, fallback)
    local number = tonumber(value)
    if type(number) ~= "number" or number <= 0 then
        return fallback
    end
    return number
end

local function ToNonNegativeNumber(value, fallback)
    local number = tonumber(value)
    if type(number) ~= "number" or number < 0 then
        return fallback
    end
    return number
end

local function ResolveMaxFrameCount(config)
    local iconsPerRow = math.max(math.floor(tonumber(config and config.iconsPerRow) or 1), 1)
    local maxRows = math.max(math.floor(tonumber(config and config.maxRows) or 0), 0)
    if maxRows > 0 then
        return math.max(iconsPerRow * maxRows, 1)
    end

    return DEFAULT_MAX_FRAME_COUNT
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

local function ResolveBlockSize(config)
    if AuraBlockLayout.CalculateMetrics then
        local layoutConfig = {}
        for key, value in pairs(config or {}) do
            layoutConfig[key] = value
        end
        layoutConfig.showTimerText = false
        local metrics = AuraBlockLayout.CalculateMetrics(ResolveMaxFrameCount(config), layoutConfig)
        return math.max(metrics.blockWidth or 0, 1),
            math.max(metrics.blockHeight or 0, 1),
            metrics.iconSize or ToPositiveNumber(config and config.iconSize, 25),
            metrics.spacingX or ToNonNegativeNumber(config and config.spacingX, 0),
            metrics.spacingY or ToNonNegativeNumber(config and config.spacingY, 0),
            metrics.iconsPerRow or math.max(math.floor(tonumber(config and config.iconsPerRow) or 1), 1)
    end

    local iconSize = ToPositiveNumber(config and config.iconSize, 25)
    local spacingX = ToNonNegativeNumber(config and config.spacingX, 0)
    local spacingY = ToNonNegativeNumber(config and config.spacingY, 0)
    local iconsPerRow = math.max(math.floor(tonumber(config and config.iconsPerRow) or 1), 1)
    local maxRows = math.max(math.floor(tonumber(config and config.maxRows) or 0), 0)
    local shownCount = ResolveMaxFrameCount(config)
    local columns = math.min(shownCount, iconsPerRow)
    local rows = maxRows > 0 and maxRows or math.max(math.ceil(shownCount / iconsPerRow), 1)

    return math.max(columns * iconSize + math.max(columns - 1, 0) * spacingX, 1),
        math.max(rows * iconSize + math.max(rows - 1, 0) * spacingY, 1),
        iconSize,
        spacingX,
        spacingY,
        iconsPerRow
end

local function IsAuraDebugEnabled()
    local AuraDiagnostics = FocalPoint and FocalPoint.AuraDiagnostics or nil
    return AuraDiagnostics and AuraDiagnostics.IsEnabled and AuraDiagnostics.IsEnabled() == true
end

local function IncrementManagedCounter(key)
    local AuraDiagnostics = FocalPoint and FocalPoint.AuraDiagnostics or nil
    if AuraDiagnostics and AuraDiagnostics.IncrementManagedCounter then
        AuraDiagnostics.IncrementManagedCounter(key)
    end
end

local function RecordManagedFilter(values)
    local AuraDiagnostics = FocalPoint and FocalPoint.AuraDiagnostics or nil
    if AuraDiagnostics and AuraDiagnostics.RecordManagedFilter then
        AuraDiagnostics.RecordManagedFilter(values)
    end
end

local function BuildManagedFilterSpec(config, definition, unit, groupKey)
    local filterString = definition and definition.filter or nil
    local candidateFilters = {}
    local showOnlyMine = config and config.showOnlyMine == true or false

    if showOnlyMine then
        candidateFilters.isFromPlayerOrPlayerPet = true
    end

    IncrementManagedCounter("filterSpecBuild")
    RecordManagedFilter({
        unit = unit,
        group = groupKey,
        showOnlyMine = showOnlyMine,
    })

    return {
        filterString = filterString,
        candidateFilters = candidateFilters,
        showOnlyMine = showOnlyMine,
        signature = table.concat({
            tostring(filterString or ""),
            tostring(showOnlyMine),
        }, "|"),
    }
end

local function RecordManagedLayout(values)
    local AuraDiagnostics = FocalPoint and FocalPoint.AuraDiagnostics or nil
    if AuraDiagnostics and AuraDiagnostics.RecordManagedLayout then
        AuraDiagnostics.RecordManagedLayout(values)
    end
end

local function HideDebugOverlay(state)
    if state and state.debugOverlay and state.debugOverlay.Hide then
        state.debugOverlay:Hide()
    end
end

local function EnsureDebugOverlay(container, definition)
    if not (container and definition) then
        return nil
    end

    if not container.FocalPointDebugOverlay then
        if InCombatLockdown and InCombatLockdown() then
            return nil
        end

        local overlay = CreateFrame("Frame", nil, container)
        overlay:EnableMouse(false)
        overlay:SetAllPoints(container)
        overlay:SetFrameLevel((container:GetFrameLevel() or 1) + 50)

        local bg = overlay:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints(overlay)
        overlay.Background = bg

        local label = overlay:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        label:SetPoint("CENTER", overlay, "CENTER", 0, 0)
        label:SetText(definition.label or "")
        label:SetJustifyH("CENTER")
        overlay.Label = label

        container.FocalPointDebugOverlay = overlay
    end

    return container.FocalPointDebugOverlay
end

local function UpdateDebugOverlay(state, definition, config)
    if not (state and state.container and definition) then
        return
    end

    if not IsAuraDebugEnabled() then
        HideDebugOverlay(state)
        return
    end

    local overlay = EnsureDebugOverlay(state.container, definition)
    if not overlay then
        return
    end

    local width, height = ResolveBlockSize(config)
    overlay:SetSize(width, height)

    local color = definition.color or { 1, 1, 1, 0.25 }
    if overlay.Background then
        overlay.Background:SetColorTexture(color[1] or 1, color[2] or 1, color[3] or 1, color[4] or 0.25)
    end

    local textColor = definition.textColor or { 1, 1, 1, 1 }
    if overlay.Label then
        overlay.Label:SetText(definition.label or "")
        overlay.Label:SetTextColor(textColor[1] or 1, textColor[2] or 1, textColor[3] or 1, textColor[4] or 1)
    end

    state.debugOverlay = overlay
    overlay:Show()
end

local function TryCall(target, methodName, ...)
    local method = target and target[methodName]
    if type(method) ~= "function" then
        return false
    end

    local ok = pcall(method, target, ...)
    return ok == true
end

local function ResolveFlowDirectionX(growthX)
    if not AnchorUtil or not AnchorUtil.FlowDirection then
        return nil
    end

    return growthX == "LEFT" and AnchorUtil.FlowDirection.Left or AnchorUtil.FlowDirection.Right
end

local function ResolveFlowDirectionY(growthY)
    if not AnchorUtil or not AnchorUtil.FlowDirection then
        return nil
    end

    return growthY == "UP" and AnchorUtil.FlowDirection.Up or AnchorUtil.FlowDirection.Down
end

local function ResolveFlowAnchorPoint(growthX, growthY)
    if growthX == "LEFT" and growthY == "UP" then
        return "BOTTOMRIGHT"
    elseif growthX == "LEFT" then
        return "TOPRIGHT"
    elseif growthY == "UP" then
        return "BOTTOMLEFT"
    end

    return "TOPLEFT"
end

local function ApplyContainerFlowLayout(container, config)
    if not container then
        return
    end

    local width, _height, iconSize, _spacingX, _spacingY, _iconsPerRow = ResolveBlockSize(config)
    local growthX = config and config.growthX or "RIGHT"
    local growthY = config and config.growthY or "DOWN"
    local flowAnchorPoint = ResolveFlowAnchorPoint(growthX, growthY)
    local horizontal = ResolveFlowDirectionX(growthX)
    local vertical = ResolveFlowDirectionY(growthY)

    if AnchorUtil and AnchorUtil.FlowLayoutAxis then
        local axis = (growthY == "UP" or growthY == "DOWN")
            and AnchorUtil.FlowLayoutAxis.Horizontal
            or nil
        if axis then
            TryCall(container, "SetFlowLayoutAxis", axis)
        end
    end
    TryCall(container, "SetFlowLayoutAnchorPoint", flowAnchorPoint)
    if horizontal and vertical then
        TryCall(container, "SetFlowLayoutGrowthDirection", horizontal, vertical)
    end
    TryCall(container, "SetFlowLayoutMaximumLineSize", width)
end

local function CreateManagedContainer(parent)
    if type(CreateFrame) ~= "function" or not parent then
        return nil
    end

    local ok, container = pcall(CreateFrame, "AuraContainer", nil, parent, CONTAINER_TEMPLATE)
    if not ok or not container then
        return nil
    end

    if type(container.AddAuraGroup) ~= "function" then
        if container.Hide then
            container:Hide()
        end
        return nil
    end

    return container
end

local function RegisterManagedButton(state, button)
    if not (state and button) then
        return
    end

    if not state.buttons then
        state.buttons = setmetatable({}, { __mode = "k" })
    end
    state.buttons[button] = true
end

local function ApplyButtonStackText(button, config)
    if not button then
        return
    end

    if type(button.SetApplicationCount) ~= "function" then
        IncrementManagedCounter("buttonStackApplyFailed")
        IncrementManagedCounter("buttonStackApplyErrors")
        return
    end

    if config and config.showStackText == false then
        local ok = pcall(button.SetApplicationCount, button, nil)
        if button.FocalPointApplicationCountText then
            button.FocalPointApplicationCountText:SetText("")
            button.FocalPointApplicationCountText:Hide()
        end
        if ok then
            IncrementManagedCounter("buttonStackApplySuccess")
        else
            IncrementManagedCounter("buttonStackApplyFailed")
            IncrementManagedCounter("buttonStackApplyErrors")
        end
        return
    end

    if not button.FocalPointApplicationCountText and button.CreateFontString then
        local text = button:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
        text:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", 1, -1)
        text:SetJustifyH("RIGHT")
        text:SetTextColor(1, 1, 1, 1)
        text:SetShadowColor(0, 0, 0, 1)
        text:SetShadowOffset(1, -1)
        button.FocalPointApplicationCountText = text
    end

    if not button.FocalPointApplicationCountText then
        IncrementManagedCounter("buttonStackApplyFailed")
        IncrementManagedCounter("buttonStackApplyErrors")
        return
    end

    local ok = pcall(button.SetApplicationCount, button, button.FocalPointApplicationCountText)
    if ok then
        button.FocalPointApplicationCountText:Show()
        IncrementManagedCounter("buttonStackApplySuccess")
    else
        IncrementManagedCounter("buttonStackApplyFailed")
        IncrementManagedCounter("buttonStackApplyErrors")
    end
end

local function ApplyButtonConfig(button, config)
    if not button then
        return
    end

    local iconSize = ToPositiveNumber(config and config.iconSize, 25)
    if button.SetSize then
        pcall(button.SetSize, button, iconSize, iconSize)
    end

    if button.SetIcon and not button.Icon and button.CreateTexture then
        local icon = button:CreateTexture(nil, "ARTWORK")
        icon:SetAllPoints(button)
        icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        button.Icon = icon
        pcall(button.SetIcon, button, icon)
    end

    if button.SetDurationText and not button.DurationText and button.CreateFontString then
        local text = button:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
        text:SetPoint("TOP", button, "BOTTOM", 0, -1)
        text:SetJustifyH("CENTER")
        text:SetTextColor(1, 1, 1, 1)
        text:SetShadowColor(0, 0, 0, 1)
        text:SetShadowOffset(1, -1)
        button.DurationText = text
        pcall(button.SetDurationText, button, text)
    end

    ApplyButtonStackText(button, config)
end

local function ConfigureButton(button, config, state)
    if not button then
        return
    end

    IncrementManagedCounter("buttonInitialize")
    RegisterManagedButton(state, button)
    ApplyButtonConfig(button, config)
end

local function ReconfigureManagedButtons(state, config)
    if not (state and type(state.buttons) == "table") then
        return
    end

    for button in pairs(state.buttons) do
        if button then
            IncrementManagedCounter("buttonReconfigure")
            ApplyButtonConfig(button, config)
        end
    end
end

local function BuildGroupOptions(config, definition, filterSpec, state)
    filterSpec = filterSpec or BuildManagedFilterSpec(config, definition)
    return {
        filterString = filterSpec.filterString,
        maxFrameCount = ResolveMaxFrameCount(config),
        templateNames = { "CustomAuraButtonTemplate" },
        candidateFilters = filterSpec.candidateFilters,
        initializeFrame = function(button)
            ConfigureButton(button, config, state)
        end,
    }
end

local function BuildLayoutOptions(config)
    local _width, _height, iconSize, spacingX, spacingY = ResolveBlockSize(config)

    return {
        elementWidth = iconSize,
        elementHeight = iconSize,
        elementSpacingX = spacingX,
        elementSpacingY = spacingY,
        lineSpacing = spacingY,
    }
end

local function BuildConfigSignature(config)
    config = config or {}
    return table.concat({
        tostring(config.enabled ~= false),
        tostring(config.showOnlyMine == true),
        tostring(config.placement or "ATTACHED"),
        tostring(config.anchorTo or "Frame"),
        tostring(config.insideAnchorTo or "Frame"),
        tostring(config.point or "TOPLEFT"),
        tostring(config.relativePoint or config.point or "TOPLEFT"),
        tostring(config.offsetX or 0),
        tostring(config.offsetY or 0),
        tostring(config.iconSize or 25),
        tostring(config.spacingX or 0),
        tostring(config.spacingY or 0),
        tostring(config.iconsPerRow or 1),
        tostring(config.maxRows or 0),
        tostring(config.growthX or "RIGHT"),
        tostring(config.growthY or "DOWN"),
        tostring(config.showStackText ~= false),
    }, "|")
end

local function ApplyManagedFilterSpec(container, definition, filterSpec)
    if not (container and definition and filterSpec) then
        return false
    end

    IncrementManagedCounter("filterApplyAttempt")
    if TryCall(container, "SetAuraGroupCandidateFilters", definition.auraGroupKey, filterSpec.candidateFilters or {}) then
        IncrementManagedCounter("filterApplySuccess")
        return true
    end

    IncrementManagedCounter("filterApplyFailed")
    IncrementManagedCounter("filterRebuildRequired")
    return false
end

local function AddManagedAuraGroup(container, config, definition, filterSpec, state)
    if not definition then
        return false
    end

    filterSpec = filterSpec or BuildManagedFilterSpec(config, definition)
    local options = BuildGroupOptions(config, definition, filterSpec, state)
    IncrementManagedCounter("groupAddAttempt")
    if TryCall(container, "AddAuraGroup", definition.auraGroupKey, options) then
        IncrementManagedCounter("groupAddSuccess")
        return true, "options-filterString"
    end

    options = BuildGroupOptions(config, definition, filterSpec, state)
    IncrementManagedCounter("groupAddAttempt")
    if TryCall(container, "AddAuraGroup", definition.auraGroupKey, filterSpec.filterString, options) then
        IncrementManagedCounter("groupAddSuccess")
        return true, "filter-argument"
    end

    IncrementManagedCounter("groupAddFailed")
    return false
end

function Managed.IsAvailable()
    return type(CreateFrame) == "function" and Managed.unavailable ~= true
end

function Managed.IsGroupAvailable(unit, groupKey)
    if not Managed.IsAvailable() then
        return false
    end

    return GetGroupDefinition(unit, groupKey) ~= nil
        and not (Managed.unavailableGroups and Managed.unavailableGroups[unit .. "/" .. groupKey] == true)
end

function Managed.IsGroupActive(frame, groupKey)
    local unit = frame and frame.unit
    local definition = GetGroupDefinition(unit, groupKey)
    return frame
        and definition ~= nil
        and frame.ManagedAuraBackend
        and frame.ManagedAuraBackend[definition.stateKey]
        and frame.ManagedAuraBackend[definition.stateKey].active == true
end

function Managed.ClearGroup(frame, groupKey)
    local unit = frame and frame.unit
    local definition = GetGroupDefinition(unit, groupKey)
    if not (frame and definition) then
        return
    end

    local state = frame.ManagedAuraBackend and frame.ManagedAuraBackend[definition.stateKey]
    if state and state.container and state.container.Hide then
        state.container:Hide()
    end
    if state then
        state.active = false
    end
    HideDebugOverlay(state)
end

function Managed.EnsureGroup(frame, groupKey, config)
    local unit = frame and frame.unit
    local definition = GetGroupDefinition(unit, groupKey)
    if not (frame and unit and definition) then
        return false
    end

    frame.ManagedAuraBackend = frame.ManagedAuraBackend or {}
    local state = frame.ManagedAuraBackend[definition.stateKey]
    if not state then
        if InCombatLockdown and InCombatLockdown() then
            RecordDiagnostic(unit, groupKey, "managed_unavailable", 0, "unavailable", state)
            return true
        end

        local container = CreateManagedContainer(frame)
        if not container then
            Managed.unavailable = true
            RecordDiagnostic(unit, groupKey, "managed_unavailable", 0, "container_failed", state)
            return false
        end

        state = {
            container = container,
            configured = false,
            active = false,
            buttons = setmetatable({}, { __mode = "k" }),
        }
        frame.ManagedAuraBackend[definition.stateKey] = state
        frame.Elements = frame.Elements or {}
        frame.Elements[definition.elementKey] = container
        state.debugOverlay = EnsureDebugOverlay(container, definition)
        HideDebugOverlay(state)
    end

    local container = state.container
    if not container then
        RecordDiagnostic(unit, groupKey, "managed_unavailable", 0, "container_failed", state)
        return false
    end
    if not state.debugOverlay and not (InCombatLockdown and InCombatLockdown()) then
        state.debugOverlay = EnsureDebugOverlay(container, definition)
        HideDebugOverlay(state)
    end

    local filterSpec = BuildManagedFilterSpec(config, definition, unit, groupKey)
    local signature = BuildConfigSignature(config)
    local signatureChanged = state.configured == true and state.signature ~= signature
    if signatureChanged then
        IncrementManagedCounter("configSignatureChanged")
        IncrementManagedCounter("ensureReconfigure")
    elseif state.configured == true then
        IncrementManagedCounter("ensureFastPath")
    end
    if InCombatLockdown and InCombatLockdown() then
        if state.configured and state.active and state.signature == signature then
            if container.Show then
                container:Show()
            end
            RecordDiagnostic(unit, groupKey, "managed_active", 1, "active", state)
            return true
        end

        if state.configured and state.filterSignature ~= filterSpec.signature then
            state.filterDirty = true
            state.pendingFilterSignature = filterSpec.signature
            IncrementManagedCounter("filterDeferred")
        end
        RecordDiagnostic(unit, groupKey, "managed_active", state.configured == true and 1 or 0, state.configured == true and "active" or "setup_pending", state)
        return state.configured == true
    end

    local width, height, _iconSize, spacingX, spacingY, iconsPerRow = ResolveBlockSize(config)
    local maxFrameCount = ResolveMaxFrameCount(config)
    local maxRows = math.max(math.floor(tonumber(config and config.maxRows) or 0), 0)
    RecordManagedLayout({
        iconsPerRow = iconsPerRow,
        maxRows = maxRows,
        maxFrameCount = maxFrameCount,
        width = width,
        height = height,
        spacingX = spacingX,
        spacingY = spacingY,
        errors = 0,
    })
    container:SetSize(width, height)
    container:SetFrameStrata(frame:GetFrameStrata())
    container:SetFrameLevel(frame:GetFrameLevel() + 25)
    container:ClearAllPoints()
    ApplyContainerFlowLayout(container, config)

    local anchorTarget = AuraAnchor.Resolve and AuraAnchor.Resolve(frame, config, groupKey) or frame
    local offsetX, offsetY = ResolveAnchorOffsets(config)
    container:SetPoint(
        config and config.point or "TOPLEFT",
        anchorTarget or frame,
        config and (config.relativePoint or config.point) or "TOPLEFT",
        offsetX,
        offsetY
    )

    if container.SetUnit and (not IsDerivedManagedGroup(unit, groupKey) or state.configured ~= true) then
        if not TryCall(container, "SetUnit", unit) then
            Managed.unavailable = true
            if container.Hide then
                container:Hide()
            end
            RecordDiagnostic(unit, groupKey, "managed_unavailable", 0, "unavailable", state)
            return false
        end
    end

    if not state.configured then
        local added, addMode = AddManagedAuraGroup(container, config, definition, filterSpec, state)
        if not added then
            Managed.unavailableGroups = Managed.unavailableGroups or {}
            Managed.unavailableGroups[unit .. "/" .. groupKey] = true
            if container.Hide then
                container:Hide()
            end
            RecordDiagnostic(unit, groupKey, "managed_unavailable", 0, "setup_failed", state)
            return false
        end
        state.configured = true
        state.addMode = addMode
        state.filterSignature = filterSpec.signature
    end
    if signatureChanged then
        ReconfigureManagedButtons(state, config)
    end

    TryCall(container, "SetAuraGroupMaxFrameCount", definition.auraGroupKey, maxFrameCount)
    if state.filterDirty == true or state.filterSignature ~= filterSpec.signature then
        if ApplyManagedFilterSpec(container, definition, filterSpec) then
            state.filterSignature = filterSpec.signature
            state.filterDirty = false
            state.pendingFilterSignature = nil
        end
    end
    IncrementManagedCounter("layoutApplyAttempt")
    local layoutOk = TryCall(container, "SetAuraGroupLayout", definition.auraGroupKey, BuildLayoutOptions(config))
    if layoutOk then
        IncrementManagedCounter("layoutApplySuccess")
    else
        IncrementManagedCounter("layoutApplyFailed")
    end

    state.active = true
    state.signature = signature
    container:Show()
    UpdateDebugOverlay(state, definition, config)
    RecordDiagnostic(unit, groupKey, "managed_active", 1, layoutOk and "active" or "layout_failed", state)
    return true
end

function Managed.RefreshGroup(frame, groupKey, config)
    if not Managed.EnsureGroup(frame, groupKey, config) then
        return false
    end

    local definition = GetGroupDefinition(frame and frame.unit, groupKey)
    local state = definition and frame.ManagedAuraBackend and frame.ManagedAuraBackend[definition.stateKey]
    if state and state.container and state.container.Show then
        state.container:Show()
    end

    return true
end

function Managed.UpdateAllAuras(frame, groupKey)
    local unit = frame and frame.unit
    local definition = GetGroupDefinition(unit, groupKey)
    local state = definition and frame and frame.ManagedAuraBackend and frame.ManagedAuraBackend[definition.stateKey]
    local container = state and state.container or nil
    local derivedCounterPrefix = GetDerivedCounterPrefix(unit, groupKey)
    local derivedErrorCounter = GetDerivedErrorCounter(unit)

    if derivedCounterPrefix then
        IncrementManagedCounter(derivedCounterPrefix .. "Attempt")
    end

    if not (container and container.UpdateAllAuras) then
        if derivedCounterPrefix then
            IncrementManagedCounter(derivedCounterPrefix .. "Failed")
            IncrementManagedCounter(derivedErrorCounter)
        end
        RecordDiagnostic(unit, groupKey, "managed_update_failed", 0, "container_missing", state)
        return false
    end

    if TryCall(container, "UpdateAllAuras") then
        if derivedCounterPrefix then
            IncrementManagedCounter(derivedCounterPrefix .. "Success")
        end
        RecordDiagnostic(unit, groupKey, "managed_active", 1, "active", state)
        return true
    end

    if derivedCounterPrefix then
        IncrementManagedCounter(derivedCounterPrefix .. "Failed")
        IncrementManagedCounter(derivedErrorCounter)
    end
    RecordDiagnostic(unit, groupKey, "managed_update_failed", 0, "update_failed", state)
    return false
end

function Managed.RefreshDebugOverlays()
    local frames = FocalPoint and FocalPoint.frames or nil
    if type(frames) ~= "table" then
        return
    end

    for unit, unitDefinitions in pairs(GROUP_DEFINITIONS) do
        local frame = frames[unit]
        if frame and frame.ManagedAuraBackend then
            for groupKey, definition in pairs(unitDefinitions) do
                local state = frame.ManagedAuraBackend[definition.stateKey]
                if state and state.container then
                    if IsAuraDebugEnabled() then
                        UpdateDebugOverlay(state, definition, frame.config and frame.config[groupKey])
                    else
                        HideDebugOverlay(state)
                    end
                end
            end
        end
    end
end
