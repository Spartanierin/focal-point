local _, FocalPoint = ...

FocalPoint.UnitFrameLayout = FocalPoint.UnitFrameLayout or {}
local Layout = FocalPoint.UnitFrameLayout

local Presence = FocalPoint.UnitFramePresence or {}
local Utils = FocalPoint.UnitFrameUtils or {}

local DoesUnitSeemPresent = Presence.DoesUnitSeemPresent
local IsPreviewModeEnabled = Presence.IsPreviewModeEnabled
local UnpackColor = Utils.UnpackColor

-- Base frame layout keeps the generic frame visibility, position, and
-- backdrop setup isolated from the more detailed element configuration.

function Layout.ApplyBaseFrame(owner, frame, config, metrics)
    local width = metrics.width
    local height = metrics.height
    local alpha = metrics.alpha
    local scale = metrics.scale
    local frameLevel = metrics.frameLevel
    local frameStrata = metrics.frameStrata

    local bgR, bgG, bgB, bgA = UnpackColor(config.backgroundColor, { 0.08, 0.08, 0.08, 0.9 })
    local borderR, borderG, borderB, borderA = UnpackColor(config.borderColor, { 0.2, 0.2, 0.2, 1 })

    local globalClickThrough = FocalPoint.db
        and FocalPoint.db.profile
        and FocalPoint.db.profile.General
        and FocalPoint.db.profile.General.GlobalClickThrough == true
    local globalMouseEnabled = FocalPoint.db
        and FocalPoint.db.profile
        and FocalPoint.db.profile.General
        and FocalPoint.db.profile.General.MouseEnabled
    local globalClampToScreen = FocalPoint.db
        and FocalPoint.db.profile
        and FocalPoint.db.profile.General
        and FocalPoint.db.profile.General.ClampToScreen
    local mouseEnabled = globalMouseEnabled
    local clampToScreen = globalClampToScreen

    if mouseEnabled == nil then
        mouseEnabled = config.mouseEnabled ~= false
    end

    if clampToScreen == nil then
        clampToScreen = config.clampToScreen == true
    end

    local shouldBeShown = config.enabled ~= false
    if shouldBeShown and not IsPreviewModeEnabled() and frame.unit ~= "player" then
        shouldBeShown = DoesUnitSeemPresent(frame.unit)
    end

    frame:ClearAllPoints()
    frame:SetSize(width, height)
    frame:SetAlpha(alpha)
    frame:SetScale(scale)
    frame:SetFrameLevel(frameLevel)
    frame:SetFrameStrata(frameStrata)
    frame:SetShown(shouldBeShown)
    frame:EnableMouse(mouseEnabled ~= false)
    frame:SetMouseClickEnabled(not (config.clickThrough or globalClickThrough))
    frame:SetClampedToScreen(clampToScreen == true)

    local relativeTo = _G[config.relativeTo or "UIParent"] or UIParent
    local point = config.point or "CENTER"
    local relativePoint = config.relativePoint or "CENTER"
    local x = config.x or 0
    local y = config.y or 0

    local relativeScale = 1
    if relativeTo.GetEffectiveScale then
        relativeScale = relativeTo:GetEffectiveScale()
    end

    local frameScale = frame:GetEffectiveScale() or 1

    local adjustedX = x * (relativeScale / frameScale)
    local adjustedY = y * (relativeScale / frameScale)

    frame:SetPoint(
        point,
        relativeTo,
        relativePoint,
        adjustedX,
        adjustedY
    )

    frame:SetBackdropColor(bgR, bgG, bgB, bgA)
    frame:SetBackdropBorderColor(borderR, borderG, borderB, borderA)

    return shouldBeShown
end
