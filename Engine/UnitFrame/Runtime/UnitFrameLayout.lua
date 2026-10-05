local _, FocalPoint = ...

FocalPoint.UnitFrameLayout = FocalPoint.UnitFrameLayout or {}
local Layout = FocalPoint.UnitFrameLayout

local Utils = FocalPoint.UnitFrameUtils or {}

local UnpackColor = Utils.UnpackColor
local GetBossFrameIndex = Utils.GetBossFrameIndex

local function GetScaleToParent(frame, parent)
    local parentScale = parent.GetEffectiveScale and parent:GetEffectiveScale() or 1
    local frameScale = frame.GetEffectiveScale and frame:GetEffectiveScale() or 1
    if parentScale == 0 then return nil end
    return frameScale / parentScale
end

-- GetCenter coordinates and local extents must enter the parent's units before
-- subtraction or edge comparisons. These helpers do not alter anchors/config.
function Layout.GetFrameCenterOffsets(frame, parent)
    if not (frame and frame.GetCenter and parent and parent.GetCenter) then return nil end
    local x, y = frame:GetCenter()
    local parentX, parentY = parent:GetCenter()
    local ratio = GetScaleToParent(frame, parent)
    if not (x and y and parentX and parentY and ratio) then return nil end
    return x * ratio - parentX, y * ratio - parentY
end

function Layout.GetFrameSizeInParent(frame, parent)
    if not (frame and parent) then return nil end
    local ratio = GetScaleToParent(frame, parent)
    if not ratio then return nil end
    return (frame.GetWidth and frame:GetWidth() or 0) * ratio,
        (frame.GetHeight and frame:GetHeight() or 0) * ratio
end

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

-- Local UI coordinates, before the owner's effective scale is applied.
function Layout.ComputeFrameRect(metrics)
    return {
        left = 0, bottom = 0, right = metrics.width,
        top = metrics.height + math.max(0, tonumber(metrics.bottomExtensionHeight) or 0),
    }
end

function Layout.GetRectAnchor(rect, point)
    local x = point:find("LEFT", 1, true) and rect.left or point:find("RIGHT", 1, true) and rect.right or (rect.left + rect.right) / 2
    local y = point:find("TOP", 1, true) and rect.top or point:find("BOTTOM", 1, true) and rect.bottom or (rect.top + rect.bottom) / 2
    return x, y
end

-- Base frame layout keeps the generic frame visibility, position, and
-- backdrop setup isolated from the more detailed element configuration.

function Layout.ApplyBaseFrame(owner, frame, config, metrics)
    local rect = Layout.ComputeFrameRect(metrics)
    local width = rect.right
    local height = rect.top
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
