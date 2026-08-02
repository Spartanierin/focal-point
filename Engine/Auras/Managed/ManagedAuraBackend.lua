local _, FocalPoint = ...

FocalPoint.ManagedAuraBackend = FocalPoint.ManagedAuraBackend or {}
local Managed = FocalPoint.ManagedAuraBackend

local AuraAnchor = FocalPoint.AuraAnchor or {}

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
    },
}

local function GetGroupDefinition(unit, groupKey)
    local unitDefinitions = GROUP_DEFINITIONS[unit]
    return unitDefinitions and unitDefinitions[groupKey] or nil
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

local function ConfigureButton(button, config)
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
end

local function BuildGroupOptions(config, definition)
    return {
        filterString = definition and definition.filter or nil,
        maxFrameCount = ResolveMaxFrameCount(config),
        templateNames = { "CustomAuraButtonTemplate" },
        initializeFrame = function(button)
            ConfigureButton(button, config)
        end,
    }
end

local function BuildLayoutOptions(config)
    local _width, _height, iconSize, spacingX, spacingY, iconsPerRow = ResolveBlockSize(config)
    local growthX = config and config.growthX or "RIGHT"
    local growthY = config and config.growthY or "DOWN"

    return {
        point = "TOPLEFT",
        relativePoint = "TOPLEFT",
        offsetX = 0,
        offsetY = 0,
        iconSize = iconSize,
        spacingX = spacingX,
        spacingY = spacingY,
        stride = iconsPerRow,
        directionX = growthX == "LEFT" and -1 or 1,
        directionY = growthY == "UP" and 1 or -1,
    }
end

local function BuildConfigSignature(config)
    config = config or {}
    return table.concat({
        tostring(config.enabled ~= false),
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
    }, "|")
end

local function AddManagedAuraGroup(container, config, definition)
    if not definition then
        return false
    end

    local options = BuildGroupOptions(config, definition)
    if TryCall(container, "AddAuraGroup", definition.auraGroupKey, options) then
        return true, "options-filterString"
    end

    options = BuildGroupOptions(config, definition)
    if TryCall(container, "AddAuraGroup", definition.auraGroupKey, definition.filter, options) then
        return true, "filter-argument"
    end

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

    local signature = BuildConfigSignature(config)
    if InCombatLockdown and InCombatLockdown() then
        if state.configured and state.active and state.signature == signature then
            if container.Show then
                container:Show()
            end
            RecordDiagnostic(unit, groupKey, "managed_active", 1, "active", state)
            return true
        end

        RecordDiagnostic(unit, groupKey, "managed_active", state.configured == true and 1 or 0, state.configured == true and "active" or "setup_pending", state)
        return state.configured == true
    end

    local width, height = ResolveBlockSize(config)
    container:SetSize(width, height)
    container:SetFrameStrata(frame:GetFrameStrata())
    container:SetFrameLevel(frame:GetFrameLevel() + 25)
    container:ClearAllPoints()

    local anchorTarget = AuraAnchor.Resolve and AuraAnchor.Resolve(frame, config, groupKey) or frame
    local offsetX, offsetY = ResolveAnchorOffsets(config)
    container:SetPoint(
        config and config.point or "TOPLEFT",
        anchorTarget or frame,
        config and (config.relativePoint or config.point) or "TOPLEFT",
        offsetX,
        offsetY
    )

    if container.SetUnit then
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
        local added, addMode = AddManagedAuraGroup(container, config, definition)
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
    end

    local layoutOk = TryCall(container, "SetAuraGroupLayout", definition.auraGroupKey, BuildLayoutOptions(config))

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
