local _, FocalPoint = ...

FocalPoint.ManagedAuraBackend = FocalPoint.ManagedAuraBackend or {}
local Managed = FocalPoint.ManagedAuraBackend

local AuraAnchor = FocalPoint.AuraAnchor or {}

local GROUP_KEY = "FocalPointPlayerBuffs"
local PUBLIC_GROUP_KEY = "Buffs"
local UNIT = "player"
local FILTER = "HELPFUL"
local CONTAINER_TEMPLATE = "CustomAuraContainerTemplate"
local DEFAULT_MAX_FRAME_COUNT = 40

local function RecordDiagnostic(unit, group, decision, groupCount)
    local AuraDiagnostics = FocalPoint and FocalPoint.AuraDiagnostics or nil
    if AuraDiagnostics and AuraDiagnostics.Record then
        AuraDiagnostics.Record({
            unit = unit,
            group = group,
            source = "AURA_BACKEND",
            backend = "managed",
            decision = decision,
            filterClass = "helpful",
            groupCount = groupCount or 0,
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

local function BuildGroupOptions(config)
    return {
        filterString = FILTER,
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

local function AddManagedAuraGroup(container, config)
    local options = BuildGroupOptions(config)
    if TryCall(container, "AddAuraGroup", GROUP_KEY, options) then
        return true, "options-filterString"
    end

    options = BuildGroupOptions(config)
    if TryCall(container, "AddAuraGroup", GROUP_KEY, FILTER, options) then
        return true, "filter-argument"
    end

    return false
end

function Managed.IsAvailable()
    return type(CreateFrame) == "function" and Managed.unavailable ~= true
end

function Managed.IsGroupActive(frame, groupKey)
    return frame
        and frame.unit == UNIT
        and groupKey == PUBLIC_GROUP_KEY
        and frame.ManagedAuraBackend
        and frame.ManagedAuraBackend.PlayerBuffs
        and frame.ManagedAuraBackend.PlayerBuffs.active == true
end

function Managed.ClearGroup(frame, groupKey)
    if not (frame and groupKey == PUBLIC_GROUP_KEY) then
        return
    end

    local state = frame.ManagedAuraBackend and frame.ManagedAuraBackend.PlayerBuffs
    if state and state.container and state.container.Hide then
        state.container:Hide()
    end
    if state then
        state.active = false
    end
end

function Managed.EnsureGroup(frame, groupKey, config)
    if not (frame and frame.unit == UNIT and groupKey == PUBLIC_GROUP_KEY) then
        return false
    end

    frame.ManagedAuraBackend = frame.ManagedAuraBackend or {}
    local state = frame.ManagedAuraBackend.PlayerBuffs
    if not state then
        if InCombatLockdown and InCombatLockdown() then
            RecordDiagnostic(UNIT, PUBLIC_GROUP_KEY, "managed_unavailable")
            return true
        end

        local container = CreateManagedContainer(frame)
        if not container then
            Managed.unavailable = true
            RecordDiagnostic(UNIT, PUBLIC_GROUP_KEY, "managed_unavailable")
            return false
        end

        state = {
            container = container,
            configured = false,
            active = false,
        }
        frame.ManagedAuraBackend.PlayerBuffs = state
        frame.Elements = frame.Elements or {}
        frame.Elements.ManagedBuffs = container
    end

    local container = state.container
    if not container then
        RecordDiagnostic(UNIT, PUBLIC_GROUP_KEY, "managed_unavailable")
        return false
    end

    local signature = BuildConfigSignature(config)
    if InCombatLockdown and InCombatLockdown() then
        if state.configured and state.active and state.signature == signature then
            if container.Show then
                container:Show()
            end
            RecordDiagnostic(UNIT, PUBLIC_GROUP_KEY, "managed_active")
            return true
        end

        RecordDiagnostic(UNIT, PUBLIC_GROUP_KEY, "managed_active")
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
        if not TryCall(container, "SetUnit", UNIT) then
            Managed.unavailable = true
            if container.Hide then
                container:Hide()
            end
            RecordDiagnostic(UNIT, PUBLIC_GROUP_KEY, "managed_unavailable")
            return false
        end
    end

    if not state.configured then
        local added, addMode = AddManagedAuraGroup(container, config)
        if not added then
            Managed.unavailable = true
            if container.Hide then
                container:Hide()
            end
            RecordDiagnostic(UNIT, PUBLIC_GROUP_KEY, "managed_unavailable")
            return false
        end
        state.configured = true
        state.addMode = addMode
    end

    TryCall(container, "SetAuraGroupLayout", GROUP_KEY, BuildLayoutOptions(config))

    state.active = true
    state.signature = signature
    container:Show()
    RecordDiagnostic(UNIT, PUBLIC_GROUP_KEY, "managed_active", 1)
    return true
end

function Managed.RefreshGroup(frame, groupKey, config)
    if not Managed.EnsureGroup(frame, groupKey, config) then
        return false
    end

    local state = frame.ManagedAuraBackend and frame.ManagedAuraBackend.PlayerBuffs
    if state and state.container and state.container.Show then
        state.container:Show()
    end

    return true
end
