local _, FocalPoint = ...

FocalPoint.UnitFrameLayout = FocalPoint.UnitFrameLayout or {}
local Layout = FocalPoint.UnitFrameLayout

local Utils = FocalPoint.UnitFrameUtils or {}

local UnpackColor = Utils.UnpackColor
local GetBossFrameIndex = Utils.GetBossFrameIndex

local function IsProtectedRoot(frame)
    return frame and frame.IsProtected and frame:IsProtected()
end

local function ResolveBottomExtensionHeight(frame, config, metrics)
    if type(metrics) == "table" and metrics.bottomExtensionHeight ~= nil then
        return math.max(0, tonumber(metrics.bottomExtensionHeight) or 0)
    end

    local baseHeight = tonumber(config and config.height)
    local rootHeight = frame and frame.GetHeight and tonumber(frame:GetHeight()) or nil
    if baseHeight and rootHeight then
        return math.max(0, rootHeight - baseHeight)
    end

    return 0
end

local function ResolveVerticalExtensionOffset(point, bottomExtensionHeight, scaleRatio)
    local extension = math.max(0, tonumber(bottomExtensionHeight) or 0)
    if extension <= 0 then
        return 0
    end

    local normalizedPoint = type(point) == "string" and point:upper() or "CENTER"
    local scaledExtension = extension * (tonumber(scaleRatio) or 1)
    if normalizedPoint:find("BOTTOM", 1, true) then
        return -scaledExtension
    end
    if not normalizedPoint:find("TOP", 1, true) then
        return -(scaledExtension / 2)
    end

    return 0
end

function Layout.ProjectConfigToRootAnchor(frame, config, metrics, positionX, positionY)
    config = type(config) == "table" and config or {}

    local relativeTo = _G[config.relativeTo or "UIParent"] or UIParent
    local point = config.point or "CENTER"
    local relativePoint = config.relativePoint or "CENTER"
    local x = tonumber(positionX)
    local y = tonumber(positionY)
    x = x == nil and (tonumber(config.x) or 0) or x
    y = y == nil and (tonumber(config.y) or 0) or y

    local relativeScale = relativeTo and relativeTo.GetEffectiveScale and relativeTo:GetEffectiveScale() or 1
    local frameScale = frame and frame.GetEffectiveScale and frame:GetEffectiveScale() or 1
    local scaleRatio = relativeScale / frameScale
    local bottomExtensionHeight = ResolveBottomExtensionHeight(frame, config, metrics)

    return {
        relativeTo = relativeTo,
        point = point,
        relativePoint = relativePoint,
        x = x,
        y = y,
        adjustedX = x * scaleRatio,
        adjustedY = y * scaleRatio + ResolveVerticalExtensionOffset(point, bottomExtensionHeight, scaleRatio),
    }
end

function Layout.ProjectConfigCenterToRootCenter(frame, config, positionX, positionY)
    local bottomExtensionHeight = ResolveBottomExtensionHeight(frame, config)
    return tonumber(positionX) or 0,
        (tonumber(positionY) or 0) + ResolveVerticalExtensionOffset("CENTER", bottomExtensionHeight, 1)
end

function Layout.ProjectRootCenterToConfigCenter(frame, config, rootX, rootY)
    local bottomExtensionHeight = ResolveBottomExtensionHeight(frame, config)
    return tonumber(rootX) or 0,
        (tonumber(rootY) or 0) - ResolveVerticalExtensionOffset("CENTER", bottomExtensionHeight, 1)
end

-- Base frame layout keeps the generic frame visibility, position, and
-- backdrop setup isolated from the more detailed element configuration.

function Layout.ApplyBaseFrame(owner, frame, config, metrics)
    local width = metrics.width
    local baseHeight = metrics.height
    local bottomExtensionHeight = tonumber(metrics.bottomExtensionHeight) or 0
    local height = baseHeight + math.max(0, bottomExtensionHeight)
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
    local mouseEnabled = globalMouseEnabled

    if mouseEnabled == nil then
        mouseEnabled = config.mouseEnabled ~= false
    end

    -- Visibility for non-player units is handled centrally by the refresh/
    -- missing-unit pipeline. Keeping presence checks out of base layout avoids
    -- a second hide path with slightly different timing during target swaps.
    local shouldBeShown = config.enabled ~= false
    local protectedRoot = IsProtectedRoot(frame)
    local inCombat = InCombatLockdown and InCombatLockdown() or false
    local layoutReason = "layout-config"
    if config.enabled == false then
        layoutReason = "layout-disabled"
    elseif protectedRoot and inCombat then
        layoutReason = "layout-protected-combat"
    end

    local alphaDecision = FocalPoint.UnitFrameVisibility
        and FocalPoint.UnitFrameVisibility.ResolveRootAlphaDecision
        and FocalPoint.UnitFrameVisibility.ResolveRootAlphaDecision(frame, {
            source = "layout",
            config = config,
            configAlpha = alpha,
            missingUnitAlphaGuard = false,
            rangeMultiplier = 1,
        })
        or nil
    local resolvedAlpha = alpha
    if type(alphaDecision) == "table"
        and alphaDecision.writesImmediately == true
        and type(alphaDecision.finalAlpha) == "number"
    then
        resolvedAlpha = alphaDecision.finalAlpha
    end

    if FocalPoint.RootAlphaDebug
        and FocalPoint.RootAlphaDebug.enabled == true
        and FocalPoint.UnitFrame
        and FocalPoint.UnitFrame.RecordRootAlphaLayoutShadow
    then
        FocalPoint.UnitFrame.RecordRootAlphaLayoutShadow(frame, {
            alpha = alpha,
            baseAlpha = alpha,
            configAlpha = alpha,
            reason = layoutReason,
            config = config,
            enabled = shouldBeShown,
            protectedRoot = protectedRoot,
            inCombat = inCombat,
            setShownAttempted = not protectedRoot,
            setShownValue = protectedRoot and nil or shouldBeShown,
            laterOverriddenByPlaceholder = FocalPoint.framesUnlocked == true
                and FocalPoint.guiTestModeEnabled ~= true,
            shouldForceZero = false,
        }, alphaDecision)
    end

    frame:ClearAllPoints()
    frame:SetSize(width, height)
    frame:SetAlpha(resolvedAlpha)
    frame:SetScale(scale)
    frame:SetFrameLevel(frameLevel)
    frame:SetFrameStrata(frameStrata)
    if not protectedRoot then
        frame:SetShown(shouldBeShown)
    end
    frame:EnableMouse(mouseEnabled ~= false)
    frame:SetMouseClickEnabled(not (config.clickThrough or globalClickThrough))
    frame:SetClampedToScreen(true)

    local projection = Layout.ProjectConfigToRootAnchor(frame, config, metrics)
    local relativeTo = projection.relativeTo
    local point = projection.point
    local relativePoint = projection.relativePoint
    local x = projection.x
    local y = projection.y
    local adjustedX = projection.adjustedX
    local adjustedY = projection.adjustedY
    local relativeScale = relativeTo.GetEffectiveScale and relativeTo:GetEffectiveScale() or 1
    local frameScale = frame:GetEffectiveScale() or 1
    local bossIndex = GetBossFrameIndex and GetBossFrameIndex(frame and frame._fpUnit)
    if bossIndex and bossIndex > 1 then
        local stackGap = tonumber(config.bossSpacing) or 10
        local stackOffset = (bossIndex - 1) * ((height + stackGap) * (relativeScale / frameScale))
        adjustedY = adjustedY - stackOffset
    end

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
