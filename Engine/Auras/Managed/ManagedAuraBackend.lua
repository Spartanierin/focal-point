local _, FocalPoint = ...

FocalPoint.ManagedAuraBackend = FocalPoint.ManagedAuraBackend or {}
local Managed = FocalPoint.ManagedAuraBackend

local AuraBlockLayout = FocalPoint.AuraBlockLayout or {}

local CONTAINER_TEMPLATE = "CustomAuraContainerTemplate"
local DEFAULT_MAX_FRAME_COUNT = 40
local DEFAULT_SORT_METHOD_VALUE = 0
local DEFAULT_SORT_DIRECTION_VALUE = 0
local SYSTEM_EXCLUDED_MANAGED_BUFF_SPELL_IDS = {
    [404468] = true, -- Flugstil: Statisch
}
local TryCall
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

local function ResolveManagedMaxDuration(config)
    if not config then
        return nil, "nil"
    end

    if config.hideLongAuras == true then
        local threshold = ToNonNegativeNumber(config.longAuraThreshold, 300)
        if threshold > 0 then
            return threshold, tostring(threshold)
        end
    end

    if config.hidePermanentAuras == true then
        return math.huge, "huge"
    end

    return nil, "nil"
end

local function ResolveMaxFrameCount(config)
    local iconsPerRow = math.max(math.floor(tonumber(config and config.iconsPerRow) or 1), 1)
    local maxRows = math.max(math.floor(tonumber(config and config.maxRows) or 0), 0)
    if maxRows > 0 then
        return math.max(iconsPerRow * maxRows, 1)
    end

    return DEFAULT_MAX_FRAME_COUNT
end

local function ResolveVisualMetrics(config)
    if AuraBlockLayout.CalculateMetrics then
        return AuraBlockLayout.CalculateMetrics(ResolveMaxFrameCount(config), config)
    end

    local iconSize = ToPositiveNumber(config and config.iconSize, 25)
    local spacingX = ToNonNegativeNumber(config and config.spacingX, 0)
    local spacingY = ToNonNegativeNumber(config and config.spacingY, 0)
    local iconsPerRow = math.max(math.floor(tonumber(config and config.iconsPerRow) or 1), 1)
    local maxRows = math.max(math.floor(tonumber(config and config.maxRows) or 0), 0)
    local shownCount = ResolveMaxFrameCount(config)
    local columns = math.min(shownCount, iconsPerRow)
    local rows = maxRows > 0 and maxRows or math.max(math.ceil(shownCount / iconsPerRow), 1)

    local blockWidth = math.max(columns * iconSize + math.max(columns - 1, 0) * spacingX, 1)
    local blockHeight = math.max(rows * iconSize + math.max(rows - 1, 0) * spacingY, 1)
    return {
        shownCount = shownCount,
        columns = columns,
        rows = rows,
        blockWidth = blockWidth,
        blockHeight = blockHeight,
        iconSize = iconSize,
        gridWidth = blockWidth,
        leftOverhang = 0,
        rightOverhang = 0,
        rowHeight = iconSize,
        timerTextHeight = 0,
        timerVisualWidth = iconSize,
        spacingX = spacingX,
        spacingY = spacingY,
        iconsPerRow = iconsPerRow,
        maxRows = maxRows,
    }
end

local function ResolveBlockSize(config)
    local metrics = ResolveVisualMetrics(config)
    return math.max(metrics.blockWidth or 0, 1),
        math.max(metrics.blockHeight or 0, 1),
        metrics.iconSize or ToPositiveNumber(config and config.iconSize, 25),
        metrics.spacingX or ToNonNegativeNumber(config and config.spacingX, 0),
        metrics.spacingY or ToNonNegativeNumber(config and config.spacingY, 0),
        metrics.iconsPerRow or math.max(math.floor(tonumber(config and config.iconsPerRow) or 1), 1),
        metrics
end

local function ResolveTimerReserve(metrics)
    return metrics and metrics.timerTextHeight and metrics.timerTextHeight > 0 and (metrics.timerTextHeight + 2) or 0
end

local function ResolveIconGridHeight(metrics)
    if not metrics then
        return 1
    end
    return math.max((metrics.blockHeight or 0) - ResolveTimerReserve(metrics), metrics.iconSize or 1, 1)
end

local function ResolveIconGridWidth(metrics)
    if not metrics then
        return 1
    end

    return math.max(metrics.gridWidth or 0, metrics.iconSize or 1, 1)
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
    local showStealableOnly = groupKey == "Buffs" and config and config.showStealableOnly == true or false
    local useSystemBuffExclusions = groupKey == "Buffs"
    local maxDuration, maxDurationText = ResolveManagedMaxDuration(config)

    if showOnlyMine then
        candidateFilters.isFromPlayerOrPlayerPet = true
    end
    if showStealableOnly then
        candidateFilters.isStealable = true
    end
    if useSystemBuffExclusions then
        candidateFilters.excludeSpellIDs = SYSTEM_EXCLUDED_MANAGED_BUFF_SPELL_IDS
    end
    if maxDuration then
        candidateFilters.maxDuration = maxDuration
    end

    IncrementManagedCounter("filterSpecBuild")
    RecordManagedFilter({
        unit = unit,
        group = groupKey,
        showOnlyMine = showOnlyMine,
        option = showStealableOnly and "showStealableOnly" or "-",
        systemExcluded = useSystemBuffExclusions and 1 or 0,
        maxDuration = maxDurationText,
    })

    return {
        filterString = filterString,
        candidateFilters = candidateFilters,
        showOnlyMine = showOnlyMine,
        showStealableOnly = showStealableOnly,
        systemExcluded = useSystemBuffExclusions,
        maxDuration = maxDuration,
        signature = table.concat({
            tostring(filterString or ""),
            tostring(showOnlyMine),
            tostring(showStealableOnly),
            tostring(useSystemBuffExclusions),
            tostring(maxDurationText),
        }, "|"),
    }
end

local function RecordManagedLayout(values)
    local AuraDiagnostics = FocalPoint and FocalPoint.AuraDiagnostics or nil
    if AuraDiagnostics and AuraDiagnostics.RecordManagedLayout then
        AuraDiagnostics.RecordManagedLayout(values)
    end
end

local function RecordManagedSort(values)
    local AuraDiagnostics = FocalPoint and FocalPoint.AuraDiagnostics or nil
    if AuraDiagnostics and AuraDiagnostics.RecordManagedSort then
        AuraDiagnostics.RecordManagedSort(values)
    end
end

local function ResolveAuraContainerEnumValue(enumName, key, fallback)
    local enumValues = rawget(_G or {}, enumName)
    if type(enumValues) ~= "table" then
        return fallback
    end

    local value = enumValues[key]
    return type(value) == "number" and value or fallback
end

local function ResolveManagedSortSpec(config)
    local sortMode = config and config.sortMode or "NEWEST_FIRST"
    local methodName = "Default"
    local directionName = "Normal"

    if sortMode == "NEWEST_FIRST" then
        methodName = "AuraInstanceIDOnly"
        directionName = "Reverse"
    elseif sortMode == "OLDEST_FIRST" then
        methodName = "AuraInstanceIDOnly"
        directionName = "Normal"
    elseif sortMode == "TIME_REMAINING_ASC" then
        methodName = "ExpirationOnly"
        directionName = "Normal"
    else
        sortMode = "DEFAULT"
    end

    return {
        mode = sortMode,
        methodName = methodName,
        directionName = directionName,
        method = ResolveAuraContainerEnumValue("AuraContainerSortMethod", methodName, DEFAULT_SORT_METHOD_VALUE),
        direction = ResolveAuraContainerEnumValue("AuraContainerSortDirection", directionName, DEFAULT_SORT_DIRECTION_VALUE),
        signature = table.concat({ tostring(sortMode), tostring(methodName), tostring(directionName) }, "|"),
    }
end

local function ApplyManagedSortMethod(container, definition, config, sortSpec)
    if not (container and definition) then
        return false
    end

    sortSpec = sortSpec or ResolveManagedSortSpec(config)
    RecordManagedSort(sortSpec)
    IncrementManagedCounter("sortApplyAttempt")
    if TryCall(container, "SetAuraGroupSortMethod", definition.auraGroupKey, sortSpec.method, sortSpec.direction) then
        IncrementManagedCounter("sortApplySuccess")
        return true
    end

    IncrementManagedCounter("sortApplyFailed")
    IncrementManagedCounter("sortApplyErrors")
    return false
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
    local visualRoot = state and (state.visualRoot or state.container) or nil
    if not (visualRoot and definition) then
        return
    end

    if not IsAuraDebugEnabled() then
        HideDebugOverlay(state)
        return
    end

    local overlay = EnsureDebugOverlay(visualRoot, definition)
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

function TryCall(target, methodName, ...)
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

    local metrics = select(7, ResolveBlockSize(config))
    local width = ResolveIconGridWidth(metrics)
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

local function CreateManagedVisualRoot(parent)
    if type(CreateFrame) ~= "function" or not parent then
        return nil
    end

    local root = CreateFrame("Frame", nil, parent)
    root:EnableMouse(false)
    root:Hide()
    return root
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

    local iconSize = ToPositiveNumber(config and config.iconSize, 25)
    local stackFontScale = math.max(tonumber(config and config.stackFontScale) or 1, 0.5)
    local fontSize = math.max(math.floor((iconSize * 0.54 * stackFontScale) + 0.5), 10)
    if button.FocalPointApplicationCountText.SetFont then
        button.FocalPointApplicationCountText:SetFont(STANDARD_TEXT_FONT, fontSize, "OUTLINE")
        IncrementManagedCounter("buttonStackScaleApplySuccess")
    else
        IncrementManagedCounter("buttonStackScaleApplyFailed")
        IncrementManagedCounter("buttonStackScaleApplyErrors")
    end
    if button.FocalPointApplicationCountText.SetTextColor then
        button.FocalPointApplicationCountText:SetTextColor(1, 1, 1, 1)
    end
    if button.FocalPointApplicationCountText.SetShadowColor then
        button.FocalPointApplicationCountText:SetShadowColor(0, 0, 0, 1)
    end
    if button.FocalPointApplicationCountText.SetShadowOffset then
        button.FocalPointApplicationCountText:SetShadowOffset(1.5, -1.5)
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

local function ApplyButtonTimerText(button, config)
    if not button then
        return
    end

    if type(button.SetDurationText) ~= "function" then
        IncrementManagedCounter("buttonTimerApplyFailed")
        IncrementManagedCounter("buttonTimerApplyErrors")
        return
    end

    if config and config.showTimerText == false then
        local ok = pcall(button.SetDurationText, button, nil)
        if button.DurationText then
            button.DurationText:SetText("")
            button.DurationText:Hide()
        end
        if ok then
            IncrementManagedCounter("buttonTimerApplySuccess")
        else
            IncrementManagedCounter("buttonTimerApplyFailed")
            IncrementManagedCounter("buttonTimerApplyErrors")
        end
        return
    end

    local iconSize = ToPositiveNumber(config and config.iconSize, 25)
    local timerMetrics = AuraBlockLayout.ResolveTimerTextMetrics and AuraBlockLayout.ResolveTimerTextMetrics(config) or {}
    local fontSize = timerMetrics.fontSize or math.max(math.floor((iconSize * 0.34 * math.max(tonumber(config and config.timerFontScale) or 1, 0.5)) + 0.5), 8)

    if not button.DurationText and button.CreateFontString then
        local text = button:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
        text:SetPoint("TOP", button, "BOTTOM", 0, -1)
        text:SetJustifyH("CENTER")
        text:SetTextColor(1, 1, 1, 1)
        text:SetShadowColor(0, 0, 0, 1)
        text:SetShadowOffset(1, -1)
        button.DurationText = text
    end

    if not button.DurationText then
        IncrementManagedCounter("buttonTimerApplyFailed")
        IncrementManagedCounter("buttonTimerApplyErrors")
        return
    end

    if button.DurationText.SetFont then
        button.DurationText:SetFont(STANDARD_TEXT_FONT, fontSize, "OUTLINE")
    end
    if button.DurationText.SetTextColor then
        button.DurationText:SetTextColor(1, 1, 1, 1)
    end
    if button.DurationText.SetShadowColor then
        button.DurationText:SetShadowColor(0, 0, 0, 1)
    end
    if button.DurationText.SetShadowOffset then
        button.DurationText:SetShadowOffset(1, -1)
    end
    if button.DurationText.ClearAllPoints then
        button.DurationText:ClearAllPoints()
    end
    if button.DurationText.SetPoint then
        button.DurationText:SetPoint("TOP", button, "BOTTOM", 0, -1)
    end
    if button.DurationText.SetJustifyH then
        button.DurationText:SetJustifyH("CENTER")
    end
    if button.DurationText.SetMaxLines then
        button.DurationText:SetMaxLines(1)
    end

    local ok = pcall(button.SetDurationText, button, button.DurationText)
    if ok then
        button.DurationText:Show()
        IncrementManagedCounter("buttonTimerApplySuccess")
    else
        IncrementManagedCounter("buttonTimerApplyFailed")
        IncrementManagedCounter("buttonTimerApplyErrors")
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

    ApplyButtonStackText(button, config)
    ApplyButtonTimerText(button, config)
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
    local _width, _height, iconSize, spacingX, spacingY, _iconsPerRow, metrics = ResolveBlockSize(config)
    local visualLineSpacing = spacingY + ResolveTimerReserve(metrics)

    return {
        elementWidth = iconSize,
        elementHeight = iconSize,
        elementSpacing = spacingX,
        elementSpacingX = spacingX,
        elementSpacingY = visualLineSpacing,
        lineSpacing = visualLineSpacing,
    }
end

local function BuildConfigSignature(config)
    config = config or {}
    return table.concat({
        tostring(config.enabled ~= false),
        tostring(config.showOnlyMine == true),
        tostring(config.showStealableOnly == true),
        tostring(config.hidePermanentAuras == true),
        tostring(config.hideLongAuras == true),
        tostring(config.longAuraThreshold or 300),
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
        tostring(config.stackFontScale or 1),
        tostring(config.showTimerText ~= false),
        tostring(config.timerFontScale or 1),
        tostring(config.sortMode or "NEWEST_FIRST"),
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
    if state and state.visualRoot and state.visualRoot.Hide then
        state.visualRoot:Hide()
    end
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

        local visualRoot = CreateManagedVisualRoot(frame)
        local container = visualRoot and CreateManagedContainer(visualRoot) or nil
        if not container then
            Managed.unavailable = true
            RecordDiagnostic(unit, groupKey, "managed_unavailable", 0, "container_failed", state)
            return false
        end

        state = {
            visualRoot = visualRoot,
            container = container,
            configured = false,
            active = false,
            buttons = setmetatable({}, { __mode = "k" }),
        }
        frame.ManagedAuraBackend[definition.stateKey] = state
        frame.Elements = frame.Elements or {}
        frame.Elements[definition.elementKey] = visualRoot
        state.debugOverlay = EnsureDebugOverlay(visualRoot, definition)
        HideDebugOverlay(state)
    end

    local container = state.container
    local visualRoot = state.visualRoot or container
    if not container then
        RecordDiagnostic(unit, groupKey, "managed_unavailable", 0, "container_failed", state)
        return false
    end
    if not state.debugOverlay and not (InCombatLockdown and InCombatLockdown()) then
        state.debugOverlay = EnsureDebugOverlay(visualRoot, definition)
        HideDebugOverlay(state)
    end

    local filterSpec = BuildManagedFilterSpec(config, definition, unit, groupKey)
    local sortSpec = ResolveManagedSortSpec(config)
    RecordManagedSort(sortSpec)
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
            if visualRoot.Show then
                visualRoot:Show()
            end
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

    local width, height, _iconSize, spacingX, spacingY, iconsPerRow, metrics = ResolveBlockSize(config)
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
    visualRoot:SetSize(width, height)
    visualRoot:SetFrameStrata(frame:GetFrameStrata())
    visualRoot:SetFrameLevel(frame:GetFrameLevel() + 25)
    AuraBlockLayout.ApplyAnchor(visualRoot, frame, config, groupKey)

    container:SetSize(ResolveIconGridWidth(metrics), ResolveIconGridHeight(metrics))
    container:SetFrameStrata(visualRoot:GetFrameStrata())
    container:SetFrameLevel(visualRoot:GetFrameLevel() + 1)
    container:ClearAllPoints()
    local timerReserve = ResolveTimerReserve(metrics)
    local leftOverhang = metrics and metrics.leftOverhang or 0
    local rightOverhang = metrics and metrics.rightOverhang or 0
    local growthX = config and config.growthX or "RIGHT"
    local growthY = config and config.growthY or "DOWN"
    if growthX == "LEFT" and growthY == "UP" then
        container:SetPoint("BOTTOMRIGHT", visualRoot, "BOTTOMRIGHT", -rightOverhang, timerReserve)
    elseif growthX == "LEFT" then
        container:SetPoint("TOPRIGHT", visualRoot, "TOPRIGHT", -rightOverhang, 0)
    elseif growthY == "UP" then
        container:SetPoint("BOTTOMLEFT", visualRoot, "BOTTOMLEFT", leftOverhang, timerReserve)
    else
        container:SetPoint("TOPLEFT", visualRoot, "TOPLEFT", leftOverhang, 0)
    end
    ApplyContainerFlowLayout(container, config)

    if container.SetUnit and (not IsDerivedManagedGroup(unit, groupKey) or state.configured ~= true) then
        if not TryCall(container, "SetUnit", unit) then
            Managed.unavailable = true
            if visualRoot.Hide then
                visualRoot:Hide()
            end
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
            if visualRoot.Hide then
                visualRoot:Hide()
            end
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
    if state.sortSignature ~= sortSpec.signature then
        if ApplyManagedSortMethod(container, definition, config, sortSpec) then
            state.sortSignature = sortSpec.signature
        end
    end
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
    visualRoot:Show()
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
    if state and state.visualRoot and state.visualRoot.Show then
        state.visualRoot:Show()
    end
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
