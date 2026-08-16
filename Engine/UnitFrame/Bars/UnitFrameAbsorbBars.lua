local _, FocalPoint = ...

FocalPoint.UnitFrameAbsorbBars = FocalPoint.UnitFrameAbsorbBars or {}
local AbsorbBars = FocalPoint.UnitFrameAbsorbBars

local Assets = FocalPoint.UnitFrameAssets or {}
local Utils = FocalPoint.UnitFrameUtils or {}

local GetStatusBarTexture = Assets.GetStatusBarTexture
local ToSafeNumberValue = Utils.ToSafeNumberValue
local UnpackColor = Utils.UnpackColor

local DEFAULT_TEXTURE = "Interface\\TargetingFrame\\UI-StatusBar"
local DEFAULT_BAR_COLOR = { 0.66, 0.86, 1.0, 0.62 }
local DEFAULT_HEALING_BAR_COLOR = { 0.75, 0.20, 1.0, 0.62 }
local DEFAULT_BACKGROUND_COLOR = { 0, 0, 0, 0 }
local DEFAULT_SIZE_MODE = "MATCH_TARGET"
local DEFAULT_WIDTH = 120
local DEFAULT_HEIGHT = 8

local NORMAL_SPEC = {
    elementKey = "NormalAbsorbBar",
    valueKey = "absorbTotalRaw",
    showKey = "showNormalAbsorbBar",
    configPrefix = "normalAbsorbBar",
    colorFallback = DEFAULT_BAR_COLOR,
    frameLevelOffset = 6,
}

local HEALING_SPEC = {
    elementKey = "HealingAbsorbBar",
    valueKey = "healAbsorbTotalRaw",
    showKey = "showHealingAbsorbBar",
    configPrefix = "healingAbsorbBar",
    colorFallback = DEFAULT_HEALING_BAR_COLOR,
    frameLevelOffset = 7,
}

local function IsSecretValue(value)
    return issecretvalue and issecretvalue(value) or false
end

local function ResolveBarNumber(value, fallback)
    local resolved = ToSafeNumberValue and ToSafeNumberValue(value) or tonumber(value)
    if type(resolved) ~= "number" or IsSecretValue(resolved) then
        return fallback
    end
    return resolved
end

local function ResolvePositiveNumber(value, fallback)
    local resolved = ResolveBarNumber(value, fallback)
    if resolved <= 0 then
        return fallback
    end
    return resolved
end

local function GetConfigValue(config, spec, suffix)
    return config and config[spec.configPrefix .. suffix]
end

local function ApplyBarColor(bar, color, fallback)
    local r, g, b, a
    if UnpackColor then
        r, g, b, a = UnpackColor(color, fallback)
    else
        r, g, b, a = fallback[1], fallback[2], fallback[3], fallback[4]
    end
    bar:SetStatusBarColor(r, g, b, a or 1)
end

local function ApplyBackgroundColor(bar, color, fallback)
    if not bar.bg then
        return
    end

    local r, g, b, a
    if UnpackColor then
        r, g, b, a = UnpackColor(color, fallback)
    else
        r, g, b, a = fallback[1], fallback[2], fallback[3], fallback[4]
    end
    bar.bg:SetVertexColor(r, g, b, a or 0)
    bar.bg:SetShown((a or 0) > 0)
end

local function ApplyGrowth(bar, growth)
    if bar.SetReverseFill then
        bar:SetReverseFill(growth == "RIGHT_TO_LEFT")
    end
end

local function ResolveAnchorTarget(frame, config, spec)
    local Factory = FocalPoint.UnitFrameFactory or {}
    local getAnchorTarget = Factory.GetAnchorTarget
    return getAnchorTarget and getAnchorTarget(frame, GetConfigValue(config, spec, "AnchorTo")) or frame
end

local function ApplyFrameLayer(frame, bar, spec)
    if not frame or not bar then
        return
    end

    if bar.SetFrameStrata and frame.GetFrameStrata then
        bar:SetFrameStrata(frame:GetFrameStrata())
    end

    local health = frame.Elements and frame.Elements.HealthBar
    local baseLevel = health and health.GetFrameLevel and health:GetFrameLevel()
        or (frame.GetFrameLevel and frame:GetFrameLevel())
        or 1
    if bar.SetFrameLevel then
        bar:SetFrameLevel(baseLevel + (tonumber(spec.frameLevelOffset) or 6))
    end
end

local function CreateAbsorbBar(frame, spec)
    if not frame or not frame.Elements then
        return nil
    end

    if frame.Elements[spec.elementKey] then
        return frame.Elements[spec.elementKey]
    end

    local bar = CreateFrame("StatusBar", nil, frame)
    ApplyFrameLayer(frame, bar, spec)
    bar:SetMinMaxValues(0, 1)
    bar:SetValue(0)
    bar:Hide()

    local bg = bar:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetTexture("Interface\\Buttons\\WHITE8X8")
    bg:Hide()
    bar.bg = bg

    frame.Elements[spec.elementKey] = bar
    return bar
end

local function ApplyAbsorbBarStyle(frame, config, spec)
    local bar = frame and frame.Elements and frame.Elements[spec.elementKey]
    if not bar then
        return false
    end

    ApplyFrameLayer(frame, bar, spec)

    local texture = GetStatusBarTexture
        and GetStatusBarTexture(GetConfigValue(config, spec, "Texture"), {
            unit = frame.unit,
            field = spec.configPrefix .. "Texture",
        })
        or DEFAULT_TEXTURE
    bar:SetStatusBarTexture(texture)

    if bar.bg then
        bar.bg:SetTexture(texture)
    end

    ApplyBarColor(bar, GetConfigValue(config, spec, "Color"), spec.colorFallback or DEFAULT_BAR_COLOR)
    ApplyBackgroundColor(bar, GetConfigValue(config, spec, "BackgroundColor"), DEFAULT_BACKGROUND_COLOR)
    ApplyGrowth(bar, GetConfigValue(config, spec, "Growth"))

    return true
end

local function ApplyAbsorbBarGeometry(frame, config, spec)
    local bar = frame and frame.Elements and frame.Elements[spec.elementKey]
    if not bar then
        return false
    end

    local target = ResolveAnchorTarget(frame, config, spec)
    if not target then
        return false
    end

    local sizeMode = GetConfigValue(config, spec, "SizeMode") or DEFAULT_SIZE_MODE
    bar:ClearAllPoints()

    if sizeMode == "CUSTOM" then
        local width = ResolvePositiveNumber(GetConfigValue(config, spec, "Width"), DEFAULT_WIDTH)
        local height = ResolvePositiveNumber(GetConfigValue(config, spec, "Height"), DEFAULT_HEIGHT)
        local point = GetConfigValue(config, spec, "Point") or "LEFT"
        local relativePoint = GetConfigValue(config, spec, "RelativePoint") or point
        local offsetX = ResolveBarNumber(GetConfigValue(config, spec, "OffsetX"), 0)
        local offsetY = ResolveBarNumber(GetConfigValue(config, spec, "OffsetY"), 0)

        bar:SetSize(width, height)
        bar:SetPoint(point, target, relativePoint, offsetX, offsetY)
    else
        bar:SetAllPoints(target)
    end

    return true
end

local function UpdateAbsorbBarValue(frame, spec)
    local bar = frame and frame.Elements and frame.Elements[spec.elementKey]
    if not bar then
        return false
    end

    local live = frame.LiveValues or {}
    local maxHealth = live.healthMaxRaw or 1
    local absorb = live[spec.valueKey] or 0

    bar:SetMinMaxValues(0, maxHealth)
    bar:SetValue(absorb)
    return true
end

local function ApplyAbsorbBarVisibility(frame, config, spec)
    local bar = frame and frame.Elements and frame.Elements[spec.elementKey]
    if not bar then
        return false
    end

    if config and config[spec.showKey] == false then
        bar:Hide()
    else
        bar:Show()
    end

    return true
end

local function ClearAbsorbBar(frame, spec)
    local bar = frame and frame.Elements and frame.Elements[spec.elementKey]
    if not bar then
        return false
    end

    bar:SetMinMaxValues(0, 1)
    bar:SetValue(0)
    bar:Hide()
    if bar.bg then
        bar.bg:Hide()
    end
    return true
end

local function ResetAbsorbBarValue(frame, spec)
    local bar = frame and frame.Elements and frame.Elements[spec.elementKey]
    if not bar then
        return false
    end

    bar:SetMinMaxValues(0, 1)
    bar:SetValue(0)
    return true
end

function AbsorbBars.CreateNormalAbsorbBar(frame)
    return CreateAbsorbBar(frame, NORMAL_SPEC)
end

function AbsorbBars.ApplyNormalAbsorbBarStyle(frame, config)
    return ApplyAbsorbBarStyle(frame, config, NORMAL_SPEC)
end

function AbsorbBars.ApplyNormalAbsorbBarAnchor(frame, config)
    return ApplyAbsorbBarGeometry(frame, config, NORMAL_SPEC)
end

function AbsorbBars.UpdateNormalAbsorbBarValue(frame)
    return UpdateAbsorbBarValue(frame, NORMAL_SPEC)
end

function AbsorbBars.ApplyNormalAbsorbBarVisibility(frame, config)
    return ApplyAbsorbBarVisibility(frame, config, NORMAL_SPEC)
end

function AbsorbBars.ClearNormalAbsorbBar(frame)
    return ClearAbsorbBar(frame, NORMAL_SPEC)
end

function AbsorbBars.ResetNormalAbsorbBarValue(frame)
    return ResetAbsorbBarValue(frame, NORMAL_SPEC)
end

function AbsorbBars.CreateHealingAbsorbBar(frame)
    return CreateAbsorbBar(frame, HEALING_SPEC)
end

function AbsorbBars.ApplyHealingAbsorbBarStyle(frame, config)
    return ApplyAbsorbBarStyle(frame, config, HEALING_SPEC)
end

function AbsorbBars.ApplyHealingAbsorbBarAnchor(frame, config)
    return ApplyAbsorbBarGeometry(frame, config, HEALING_SPEC)
end

function AbsorbBars.UpdateHealingAbsorbBarValue(frame)
    return UpdateAbsorbBarValue(frame, HEALING_SPEC)
end

function AbsorbBars.ApplyHealingAbsorbBarVisibility(frame, config)
    return ApplyAbsorbBarVisibility(frame, config, HEALING_SPEC)
end

function AbsorbBars.ClearHealingAbsorbBar(frame)
    return ClearAbsorbBar(frame, HEALING_SPEC)
end

function AbsorbBars.ResetHealingAbsorbBarValue(frame)
    return ResetAbsorbBarValue(frame, HEALING_SPEC)
end

return AbsorbBars
