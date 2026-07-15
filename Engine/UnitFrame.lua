local _, FocalPoint = ...

FocalPoint.UnitFrame = FocalPoint.UnitFrame or {}
local UF = FocalPoint.UnitFrame

-- UnitFrame.lua is now the public facade and high-level orchestrator for the
-- split unit-frame runtime. Detailed responsibilities live in the grouped
-- submodules under Engine/UnitFrame/.

-- Runtime modules
local Cast = FocalPoint.UnitFrameCastBar or {}
local CastRuntime = FocalPoint.UnitFrameCastRuntime or {}
local Factory = FocalPoint.UnitFrameFactory or {}
local Health = FocalPoint.UnitFrameHealth or {}
local BuildRuntime = FocalPoint.UnitFrameBuild or {}
local RefreshRuntime = FocalPoint.UnitFrameRefresh or {}
local StateRuntime = FocalPoint.UnitFrameState or {}
local InsideLayout = FocalPoint.UnitFrameInsideLayout or {}
local Layout = FocalPoint.UnitFrameLayout or {}
local BarLayout = FocalPoint.UnitFrameBarLayout or {}
local Power = FocalPoint.UnitFramePower or {}
local ClassPower = FocalPoint.UnitFrameClassPower or {}
local Portrait = FocalPoint.UnitFramePortrait or {}

-- Indicator modules
local Indicators = FocalPoint.UnitFrameIndicators or {}
local RaidTarget = FocalPoint.UnitFrameRaidTarget or {}
local Leader = FocalPoint.UnitFrameLeader or {}
local Role = FocalPoint.UnitFrameRole or {}
local Combat = FocalPoint.UnitFrameCombat or {}
local Resting = FocalPoint.UnitFrameResting or {}
local ReadyCheck = FocalPoint.UnitFrameReadyCheck or {}
local ClassificationIndicator = FocalPoint.UnitFrameClassificationIndicator or {}

-- Shared helpers
local Visibility = FocalPoint.UnitFrameVisibility or {}
local Utils = FocalPoint.UnitFrameUtils or {}
local Assets = FocalPoint.UnitFrameAssets or {}
local Colors = FocalPoint.UnitFrameColors or {}
local Presence = FocalPoint.UnitFramePresence or {}
local Preview = FocalPoint.UnitFramePreview or {}
local Range = FocalPoint.UnitFrameRange or {}
local StopCastBar

-- Shared aliases used directly by the coordinating runtime below.
local GetUnitDB = Utils.GetUnitDB
local UnpackColor = Utils.UnpackColor
local ResolveInterruptibleState = Utils.ResolveInterruptibleState
local GetPowerColorForUnit = Colors.GetPowerColorForUnit
local GetStatusBarTexture = Assets.GetStatusBarTexture
local GetFontPath = Assets.GetFontPath
local BuildFontFlags = Assets.BuildFontFlags
local ApplyCastBarStateColor = Cast.ApplyStateColor
local ApplyCastBarLayout = Cast.ApplyLayout
local DoesUnitSeemPresent = Presence.DoesUnitSeemPresent
local GetTargetPresenceSnapshot = Presence.GetTargetPresenceSnapshot
local ToSafeNumberValue = Utils.ToSafeNumberValue
local FormatDisplayNumber = Utils.FormatDisplayNumber
local ResolveBlizzardAbbreviation = Utils.ResolveBlizzardAbbreviation
local IsPreviewModeEnabled = Presence.IsPreviewModeEnabled
local GetActiveCastTiming = Cast.GetActiveTiming
local GetPreviewRaidTargetIndex = Preview.GetRaidTargetIndex
local GetSecondaryPowerTypeForUnit = Preview.GetSecondaryPowerTypeForUnit
local GetSecondaryPowerValues = Preview.GetSecondaryPowerValues
local IsDetailedPreviewEnabled = Preview.IsDetailedPreviewEnabled
local StartCastBar = Cast.Start
local StartCastBarPreview = Cast.StartPreview
local QueueCastBarRefresh = Cast.QueueRefresh
local GetAnchorTarget = Factory.GetAnchorTarget
local CreateBaseFrame = Factory.CreateBaseFrame
local CreateHealthBar = Factory.CreateHealthBar
local CreatePowerBar = Factory.CreatePowerBar
local CreateClassPowerBar = Factory.CreateClassPowerBar
local CreateAlternativePowerBar = Factory.CreateAlternativePowerBar
local CreateCastBar = Factory.CreateCastBar
local CreateOverlayIndicatorHolder = Indicators.CreateHolder
local ApplyOverlayIndicatorConfig = Indicators.ApplyConfig
local ApplyOverlayIndicatorBatch = Indicators.ApplyBatch
local CreatePortrait = Portrait.Create
local ApplyPortraitLayout = Portrait.ApplyLayout
local UpdatePortraitTexture = Portrait.UpdateTexture
local RegisterPortraitEvents = Portrait.RegisterEvents
local CreateRaidTargetIcon = RaidTarget.Create
local UpdateRaidTargetIcon = RaidTarget.Update
local RegisterRaidTargetEvents = RaidTarget.RegisterEvents
local UpdateLeaderIcon = Leader.Update
local RegisterLeaderIconEvents = Leader.RegisterEvents
local UpdateRoleIcon = Role.Update
local RegisterRoleIconEvents = Role.RegisterEvents
local UpdateCombatIndicator = Combat.Update
local RegisterCombatIndicatorEvents = Combat.RegisterEvents
local UpdateRestingIndicator = Resting.Update
local RegisterRestingIndicatorEvents = Resting.RegisterEvents
local UpdateReadyCheckIndicator = ReadyCheck.Update
local RegisterReadyCheckIndicatorEvents = ReadyCheck.RegisterEvents
local ApplyClassificationIndicatorLayout = ClassificationIndicator.ApplyLayout
local RegisterClassificationIndicatorEvents = ClassificationIndicator.RegisterEvents
local ApplyBaseFrameLayout = Layout.ApplyBaseFrame
local ApplyHealthAndPowerLayout = BarLayout.ApplyHealthAndPower
local ApplyAlternativePowerLayout = BarLayout.ApplyAlternativePower
local ApplyClassPowerLayout = ClassPower.ApplyLayout
local EnsurePlayerAltPowerText = BuildRuntime.EnsurePlayerAltPowerText
local EnsurePlayerClassPowerText = BuildRuntime.EnsurePlayerClassPowerText
local BuildElements = BuildRuntime.CreateElements
local RegisterBuildEvents = BuildRuntime.RegisterEvents
local ApplyRefreshFlow = RefreshRuntime.Apply
local HandleMissingUnit = Visibility.HandleMissingUnit
local RegisterVisibilityEvents = Visibility.RegisterEvents
local ClearFrameVisualState = Visibility.ClearFrameVisualState
local QueueVisibilityRefresh = Visibility.QueueRefresh
local GetRangeFadeMultiplier = Range.GetFadeMultiplier
local EnsureRangeFadeDriver = Range.EnsureFadeDriver
local AccumulateInsideReserve = InsideLayout.AccumulateReserve
local ApplyReserveToArea = InsideLayout.ApplyReserveToArea
local ApplyVisibleReserve = InsideLayout.ApplyVisibleReserve
local ApplyVisibleEntryReserves = InsideLayout.ApplyVisibleEntryReserves

local function IsProtectedFrameInCombat(frame)
    return frame
        and frame.IsProtected
        and frame:IsProtected()
        and InCombatLockdown
        and InCombatLockdown()
end

-- Health and bar coordination wrappers
function UF:UpdateHealthBarValue(frame)
    return Health.UpdateBarValue(frame)
end

function UF:UpdateHealthBarColor(frame)
    return Health.UpdateBarColor(frame)
end

function UF:RefreshHealthBar(frame)
    return Health.RefreshBar(self, frame)
end

function UF:RefreshHealthText(frame)
    return Health.RefreshText(self, frame)
end

function UF:RefreshHealth(frame)
    return Health.Refresh(self, frame)
end

function UF:RefreshAuras(frame)
    local AuraRuntime = FocalPoint.AuraRuntime or {}
    if AuraRuntime.RefreshAuras then
        return AuraRuntime.RefreshAuras(frame)
    end

    return {}
end

function UF:BuildAuraElements(frame)
    local AuraRuntime = FocalPoint.AuraRuntime or {}
    if AuraRuntime.BuildAuraContainers then
        return AuraRuntime.BuildAuraContainers(frame)
    end

    return nil
end

function UF:RegisterAuraEvents(frame)
    local AuraRuntime = FocalPoint.AuraRuntime or {}
    if AuraRuntime.RegisterAuraEvents then
        return AuraRuntime.RegisterAuraEvents(frame)
    end

    return nil
end

function UF:GetTestPreviewValues(frame)
    return Preview.GetTestValues(frame)
end

function UF:GetAnchorTarget(frame, anchorTo)
    return GetAnchorTarget(frame, anchorTo)
end

function UF:CreateBaseFrame(unit, config)
    return CreateBaseFrame(unit, config)
end

function UF:CreateHealthBar(frame)
    return CreateHealthBar(frame)
end

function UF:CreatePowerBar(frame)
    return CreatePowerBar(frame)
end

function UF:CreateClassPowerBar(frame)
    return CreateClassPowerBar(frame)
end

function UF:CreateAlternativePowerBar(frame)
    return CreateAlternativePowerBar(frame)
end

function UF:CreateCastBar(frame)
    return CreateCastBar(frame)
end

function UF:RefreshUnitBarValues(frame)
    Power.RefreshUnitBarValues(self, frame)
    return ClassPower.RefreshValues(self, frame)
end

StopCastBar = Cast.Stop

-- Cast bar runtime wrappers
function UF:RefreshCastBar(frame)
    return CastRuntime.Refresh(self, frame)
end

function UF:RegisterCastBarEvents(frame)
    return CastRuntime.RegisterEvents(self, frame)
end

-- Overlay indicator creation helpers
function UF:CreateRaidTargetIcon(frame)
    return CreateRaidTargetIcon(frame)
end

function UF:CreateLeaderIcon(frame)
    CreateOverlayIndicatorHolder(frame, "LeaderIcon")
end

function UF:CreateRoleIcon(frame)
    CreateOverlayIndicatorHolder(frame, "RoleIcon")
end

function UF:CreateCombatIndicator(frame)
    CreateOverlayIndicatorHolder(frame, "CombatIndicator")
end

function UF:CreateRestingIndicator(frame)
    CreateOverlayIndicatorHolder(frame, "RestingIndicator")
end

function UF:CreateReadyCheckIndicator(frame)
    CreateOverlayIndicatorHolder(frame, "ReadyCheckIndicator")
end

function UF:CreateClassificationIndicator(frame)
    return ClassificationIndicator.Create(frame)
end

-- Overlay indicator runtime wrappers
function UF:UpdateRaidTargetIcon(frame)
    return UpdateRaidTargetIcon(self, frame)
end

function UF:RegisterRaidTargetEvents(frame)
    return RegisterRaidTargetEvents(self, frame)
end

function UF:UpdateLeaderIcon(frame)
    return UpdateLeaderIcon(self, frame)
end

function UF:RegisterLeaderIconEvents(frame)
    return RegisterLeaderIconEvents(self, frame)
end

function UF:UpdateRoleIcon(frame)
    return UpdateRoleIcon(self, frame)
end

function UF:RegisterRoleIconEvents(frame)
    return RegisterRoleIconEvents(self, frame)
end

function UF:UpdateCombatIndicator(frame)
    return UpdateCombatIndicator(self, frame)
end

function UF:RegisterCombatIndicatorEvents(frame)
    return RegisterCombatIndicatorEvents(self, frame)
end

function UF:UpdateRestingIndicator(frame)
    return UpdateRestingIndicator(self, frame)
end

function UF:RegisterRestingIndicatorEvents(frame)
    return RegisterRestingIndicatorEvents(self, frame)
end

function UF:UpdateReadyCheckIndicator(frame)
    return UpdateReadyCheckIndicator(self, frame)
end

function UF:RegisterReadyCheckIndicatorEvents(frame)
    return RegisterReadyCheckIndicatorEvents(self, frame)
end

function UF:RegisterClassificationIndicatorEvents(frame)
    return RegisterClassificationIndicatorEvents(self, frame)
end

-- Portrait
function UF:CreatePortrait(frame)
    return CreatePortrait(frame)
end

function UF:UpdatePortraitTexture(frame)
    return UpdatePortraitTexture(frame)
end

function UF:RegisterPortraitEvents(frame)
    return RegisterPortraitEvents(frame)
end

function UF:ApplyConfig(frame)
    local config = frame.config
    if not config then
        return
    end
    local protectedInCombat = IsProtectedFrameInCombat(frame)

    local width = config.width or 220
    local height = config.height or 40
    local alpha = config.alpha or 1
    local scale = config.scale or 1
    local frameLevel = config.frameLevel or 1
    local frameStrata = config.frameStrata or "MEDIUM"
    local showPowerBar = config.showPowerBar and true or false
    local powerBarHeight = showPowerBar and (config.powerBarHeight or 8) or 0
    local healthBarReverseFill = config.healthBarReverseFill
    local powerBarReverseFill = config.powerBarReverseFill
    local alternativePowerBarReverseFill = config.alternativePowerBarReverseFill
    local showAlternativePowerBar = config.showAlternativePowerBar and true or false
    local alternativePowerBarHeight = showAlternativePowerBar and (config.alternativePowerBarHeight or 5) or 0
    local showClassPowerBar = config.showClassPowerBar and true or false
    local classPowerBarHeight = showClassPowerBar and (config.classPowerBarHeight or 12) or 0
    local classPowerBarWidth = tonumber(config.classPowerBarWidth) or 100
    local classPowerBarSpacing = tonumber(config.classPowerBarSpacing) or 2
    local classPowerBarAnchorTo = config.classPowerBarAnchorTo or "HealthBar"
    local classPowerBarPoint = config.classPowerBarPoint or "BOTTOMRIGHT"
    local classPowerBarRelativePoint = config.classPowerBarRelativePoint or "BOTTOMRIGHT"
    local classPowerBarOffsetX = tonumber(config.classPowerBarOffsetX) or -5
    local classPowerBarOffsetY = tonumber(config.classPowerBarOffsetY) or 5
    local liveAltPowerType, liveAltPowerCurrent, liveAltPowerMax, liveAltPowerMin = GetSecondaryPowerValues(frame.unit)
    local alternativePowerBarVisible = showAlternativePowerBar and liveAltPowerType ~= nil
    local liveClassPowerInfo = ClassPower.GetInfo and ClassPower.GetInfo(frame.unit) or nil
    local classPowerBarVisible = showClassPowerBar and liveClassPowerInfo ~= nil
    local borderInset = 1

    local portraitConfig = config.Portrait or {}
    local raidTargetConfig = config.RaidTargetIcon or {}
    local leaderConfig = config.LeaderIcon or {}
    local roleConfig = config.RoleIcon or {}
    local combatConfig = config.CombatIndicator or {}
    local restingConfig = config.RestingIndicator or {}
    local readyCheckConfig = config.ReadyCheckIndicator or {}
    local classificationConfig = config.ClassificationIndicator or {}
    local portraitEnabled = portraitConfig.enabled and true or false
    local portraitPlacement = portraitConfig.placement or "INSIDE"
    local portraitMode = portraitConfig.mode or "2D"
    local portraitSize = tonumber(portraitConfig.size) or 40
    local portraitScale = tonumber(portraitConfig.scale) or 1
    local portraitPadding = tonumber(portraitConfig.padding) or 4
    local portraitInsideSide = portraitConfig.insideSide or "LEFT"
    local portraitInsideAnchorTo = portraitConfig.insideAnchorTo or "Frame"

    local portraitPoint = portraitConfig.point or "RIGHT"
    local portraitRelativePoint = portraitConfig.relativePoint or "LEFT"
    local portraitOffsetX = tonumber(portraitConfig.offsetX) or -4
    local portraitOffsetY = tonumber(portraitConfig.offsetY) or 0
    local portraitAnchorTo = portraitConfig.anchorTo or "Frame"

    local portraitEffectiveSize = portraitEnabled and (portraitSize * portraitScale) or 0
    local portraitInside = portraitEnabled and portraitPlacement == "INSIDE"
    local portraitAttached = portraitEnabled and portraitPlacement == "ATTACHED"
    local portraitReservedSpace = portraitInside and (portraitEffectiveSize + portraitPadding) or 0

    -- Important: GUI uses fallback=true for new RTM configs. Treat a missing
    -- enabled flag as active as well, otherwise the UI can look enabled while
    -- the engine silently considers the element disabled on older profiles.
    local raidTargetEnabled = raidTargetConfig.enabled ~= false
    local raidTargetSize = tonumber(raidTargetConfig.size) or 18
    local raidTargetScale = tonumber(raidTargetConfig.scale) or 1
    local raidTargetPoint = raidTargetConfig.point or "TOP"
    local raidTargetRelativePoint = raidTargetConfig.relativePoint or "TOP"
    local raidTargetOffsetX = tonumber(raidTargetConfig.offsetX) or 0
    local raidTargetOffsetY = tonumber(raidTargetConfig.offsetY) or 8
    local raidTargetAnchorTo = raidTargetConfig.anchorTo or "Frame"

    local leaderEnabled = leaderConfig.enabled ~= false
    local leaderPlacement = leaderConfig.placement or "ATTACHED"
    local leaderSize = tonumber(leaderConfig.size) or 16
    local leaderScale = tonumber(leaderConfig.scale) or 1
    local leaderPadding = tonumber(leaderConfig.padding) or 2
    local leaderInsideSide = leaderConfig.insideSide or "LEFT"
    local leaderPoint = leaderConfig.point or "TOPLEFT"
    local leaderRelativePoint = leaderConfig.relativePoint or "TOP"
    local leaderOffsetX = tonumber(leaderConfig.offsetX) or 0
    local leaderOffsetY = tonumber(leaderConfig.offsetY) or 0
    local leaderAnchorTo = leaderConfig.anchorTo or "Frame"

    local roleEnabled = roleConfig.enabled ~= false
    local rolePlacement = roleConfig.placement or "ATTACHED"
    local roleSize = tonumber(roleConfig.size) or 16
    local roleScale = tonumber(roleConfig.scale) or 1
    local rolePadding = tonumber(roleConfig.padding) or 2
    local roleInsideSide = roleConfig.insideSide or "RIGHT"
    local rolePoint = roleConfig.point or "TOPRIGHT"
    local roleRelativePoint = roleConfig.relativePoint or "TOP"
    local roleOffsetX = tonumber(roleConfig.offsetX) or 0
    local roleOffsetY = tonumber(roleConfig.offsetY) or 0
    local roleAnchorTo = roleConfig.anchorTo or "Frame"

    local combatEnabled = combatConfig.enabled ~= false
    local combatEffect = combatConfig.effect or "ICON"
    local combatUsesOverlay = combatEffect == "FRAME_OVERLAY"
    local combatPlacement = combatConfig.placement or "ATTACHED"
    local combatSize = tonumber(combatConfig.size) or 16
    local combatScale = tonumber(combatConfig.scale) or 1
    local combatPadding = tonumber(combatConfig.padding) or 2
    local combatInsideSide = combatConfig.insideSide or "RIGHT"
    local combatPoint = combatConfig.point or "TOP"
    local combatRelativePoint = combatConfig.relativePoint or "TOP"
    local combatOffsetX = tonumber(combatConfig.offsetX) or 0
    local combatOffsetY = tonumber(combatConfig.offsetY) or 0
    local combatAnchorTo = combatConfig.anchorTo or "Frame"

    local restingEnabled = restingConfig.enabled ~= false
    local restingEffect = restingConfig.effect or "ICON"
    local restingUsesOverlay = restingEffect == "FRAME_OVERLAY"
    local restingPlacement = restingConfig.placement or "ATTACHED"
    local restingSize = tonumber(restingConfig.size) or 16
    local restingScale = tonumber(restingConfig.scale) or 1
    local restingPadding = tonumber(restingConfig.padding) or 2
    local restingInsideSide = restingConfig.insideSide or "LEFT"
    local restingPoint = restingConfig.point or "TOPLEFT"
    local restingRelativePoint = restingConfig.relativePoint or "TOP"
    local restingOffsetX = tonumber(restingConfig.offsetX) or 0
    local restingOffsetY = tonumber(restingConfig.offsetY) or 0
    local restingAnchorTo = restingConfig.anchorTo or "Frame"

    local readyCheckEnabled = readyCheckConfig.enabled ~= false
    local readyCheckPlacement = readyCheckConfig.placement or "ATTACHED"
    local readyCheckSize = tonumber(readyCheckConfig.size) or 16
    local readyCheckScale = tonumber(readyCheckConfig.scale) or 1
    local readyCheckPadding = tonumber(readyCheckConfig.padding) or 2
    local readyCheckInsideSide = readyCheckConfig.insideSide or "RIGHT"
    local readyCheckPoint = readyCheckConfig.point or "TOPRIGHT"
    local readyCheckRelativePoint = readyCheckConfig.relativePoint or "TOP"
    local readyCheckOffsetX = tonumber(readyCheckConfig.offsetX) or 0
    local readyCheckOffsetY = tonumber(readyCheckConfig.offsetY) or 0
    local readyCheckAnchorTo = readyCheckConfig.anchorTo or "Frame"
    local classificationEnabled = classificationConfig.enabled ~= false
    local classificationEffect = classificationConfig.effect or "PORTRAIT_OVERLAY"
    local liveClassification = nil
    if ClassificationIndicator.GetResolved then
        local resolvedClassification, resolvedEffect = ClassificationIndicator.GetResolved(frame)
        if resolvedEffect ~= nil then
            classificationEffect = resolvedEffect
        end
        liveClassification = resolvedClassification
    end
    if not classificationEnabled then
        classificationEffect = "NONE"
        liveClassification = nil
    end

    local frameReserve = { left = 0, right = 0 }
    local healthReserve = { left = 0, right = 0 }
    local powerReserve = { left = 0, right = 0 }

    if portraitInside then
        ApplyReserveToArea(frameReserve, healthReserve, powerReserve, portraitInsideAnchorTo, portraitInsideSide, true, "INSIDE", portraitEffectiveSize, 1, portraitPadding)
    end

    if raidTargetEnabled then
        local raidTargetPlacement = raidTargetConfig.placement or "ATTACHED"
        ApplyReserveToArea(frameReserve, healthReserve, powerReserve, raidTargetConfig.insideAnchorTo or "Frame", raidTargetConfig.insideSide or "RIGHT", true, raidTargetPlacement, raidTargetSize, raidTargetScale, tonumber(raidTargetConfig.padding) or 2)
    end

    ApplyReserveToArea(frameReserve, healthReserve, powerReserve, leaderConfig.insideAnchorTo or "Frame", leaderInsideSide, leaderEnabled, leaderPlacement, leaderSize, leaderScale, leaderPadding)
    ApplyReserveToArea(frameReserve, healthReserve, powerReserve, roleConfig.insideAnchorTo or "Frame", roleInsideSide, roleEnabled, rolePlacement, roleSize, roleScale, rolePadding)
    ApplyReserveToArea(frameReserve, healthReserve, powerReserve, combatConfig.insideAnchorTo or "Frame", combatInsideSide, combatEnabled and not combatUsesOverlay, combatPlacement, combatSize, combatScale, combatPadding)
    ApplyReserveToArea(frameReserve, healthReserve, powerReserve, restingConfig.insideAnchorTo or "Frame", restingInsideSide, restingEnabled and not restingUsesOverlay, restingPlacement, restingSize, restingScale, restingPadding)
    ApplyReserveToArea(frameReserve, healthReserve, powerReserve, readyCheckConfig.insideAnchorTo or "Frame", readyCheckInsideSide, readyCheckEnabled, readyCheckPlacement, readyCheckSize, readyCheckScale, readyCheckPadding)

    local healthR, healthG, healthB, healthA = UnpackColor(config.healthColor, { 0.1, 0.8, 0.1, 1 })
    local powerR, powerG, powerB, powerA = UnpackColor(config.powerColor, { 0.2, 0.4, 0.9, 1 })
    local classPowerR, classPowerG, classPowerB, classPowerA = UnpackColor(config.classPowerColor, { powerR, powerG, powerB, powerA })

    local healthBackgroundEnabled = config.healthBackground ~= false
    local healthBgR, healthBgG, healthBgB, healthBgA = UnpackColor(config.healthBackgroundColor, { 0, 0, 0, 0.35 })
    local healthBackgroundShown = healthBackgroundEnabled and (healthBgA or 0) > 0.001

    local powerBackgroundEnabled = config.powerBackground ~= false
    local powerBgR, powerBgG, powerBgB, powerBgA = UnpackColor(config.powerBackgroundColor, { 0, 0, 0, 0.35 })
    local alternativePowerBackgroundEnabled = config.alternativePowerBackground
    if alternativePowerBackgroundEnabled == nil then
        alternativePowerBackgroundEnabled = powerBackgroundEnabled
    else
        alternativePowerBackgroundEnabled = alternativePowerBackgroundEnabled ~= false
    end
    local altPowerBgR, altPowerBgG, altPowerBgB, altPowerBgA = UnpackColor(config.alternativePowerBackgroundColor, { powerBgR, powerBgG, powerBgB, powerBgA })
    local altPowerColorR, altPowerColorG, altPowerColorB, altPowerColorA = UnpackColor(config.alternativePowerColor, { powerR, powerG, powerB, powerA })
    local classPowerBgR, classPowerBgG, classPowerBgB, classPowerBgA = UnpackColor(config.classPowerBackgroundColor, { powerBgR, powerBgG, powerBgB, powerBgA })
    local powerBackgroundShown = powerBackgroundEnabled and (powerBgA or 0) > 0.001
    local altPowerBackgroundShown = alternativePowerBackgroundEnabled and (altPowerBgA or 0) > 0.001
    local classPowerBackgroundShown = (classPowerBgA or 0) > 0.001

    local borderR, borderG, borderB, borderA = UnpackColor(config.borderColor, { 0, 0, 0, 0 })
    local classPowerBorderR = borderR
    local classPowerBorderG = borderG
    local classPowerBorderB = borderB
    local classPowerBorderA = borderA

    if (classPowerBorderA or 0) <= 0.001 then
        classPowerBorderR, classPowerBorderG, classPowerBorderB, classPowerBorderA = 0, 0, 0, 0.85
    end

    if config.useClassColorPower then
        local resourceR, resourceG, resourceB, resourceA = GetPowerColorForUnit(frame.unit)
        if resourceR and resourceG and resourceB then
            powerR, powerG, powerB = resourceR, resourceG, resourceB
        end
    end

    local healthTexture = GetStatusBarTexture(config.healthBarTexture)
    local powerTexture = GetStatusBarTexture(config.powerBarTexture)
    local castTexture = GetStatusBarTexture(config.castBarTexture)
    local classPowerTexture = GetStatusBarTexture(config.classPowerBarTexture or config.powerBarTexture)
    local altPowerTexture = GetStatusBarTexture(config.alternativePowerBarTexture or config.powerBarTexture)
    local bottomExtensionHeight = alternativePowerBarVisible and alternativePowerBarHeight or 0

    if healthBarReverseFill == nil then
        healthBarReverseFill = frame.unit == "target"
    end

    if powerBarReverseFill == nil then
        powerBarReverseFill = frame.unit == "target"
    end

    if alternativePowerBarReverseFill == nil then
        alternativePowerBarReverseFill = powerBarReverseFill
    end

    local layoutAlpha = alpha
    if frame.unit == "target"
        and not IsPreviewModeEnabled()
        and UnitExists
        and not UnitExists("target")
    then
        layoutAlpha = 0
    end
    if frame.unit == "targettarget"
        and not IsPreviewModeEnabled()
        and UnitExists
        and not UnitExists("targettarget")
    then
        layoutAlpha = 0
    end
    if frame.unit == "focustarget"
        and not IsPreviewModeEnabled()
        and UnitExists
        and not UnitExists("focustarget")
    then
        layoutAlpha = 0
    end
    if type(frame.unit) == "string"
        and frame.unit:match("^boss%d+$")
        and not IsPreviewModeEnabled()
        and UnitExists
        and not UnitExists(frame.unit)
    then
        layoutAlpha = 0
    end

    if not protectedInCombat then
        ApplyBaseFrameLayout(self, frame, config, {
            width = width,
            height = height,
            bottomExtensionHeight = bottomExtensionHeight,
            alpha = layoutAlpha,
            scale = scale,
            frameLevel = frameLevel,
            frameStrata = frameStrata,
        })
    end

    local barLayoutOptions = {
        borderInset = borderInset,
        alternativePowerBarVisible = alternativePowerBarVisible,
        alternativePowerBarHeight = alternativePowerBarHeight,
        showPowerBar = showPowerBar,
        powerBarHeight = powerBarHeight,
        healthBarReverseFill = healthBarReverseFill,
        powerBarReverseFill = powerBarReverseFill,
        frameLeftReserve = frameReserve.left,
        frameRightReserve = frameReserve.right,
        healthLeftReserve = healthReserve.left,
        healthRightReserve = healthReserve.right,
        powerLeftReserve = powerReserve.left,
        powerRightReserve = powerReserve.right,
        healthTexture = healthTexture,
        healthBgR = healthBgR,
        healthBgG = healthBgG,
        healthBgB = healthBgB,
        healthBgA = healthBgA,
        healthBackgroundShown = healthBackgroundShown,
        powerTexture = powerTexture,
        powerR = powerR,
        powerG = powerG,
        powerB = powerB,
        powerA = powerA,
        powerBgR = powerBgR,
        powerBgG = powerBgG,
        powerBgB = powerBgB,
        powerBgA = powerBgA,
        powerBackgroundShown = powerBackgroundShown,
    }

    ApplyHealthAndPowerLayout(self, frame, barLayoutOptions)

    self:ApplyRangeFade(frame)

    local alternativePowerLayoutOptions = {
        borderInset = borderInset,
        frameLeftReserve = frameReserve.left,
        frameRightReserve = frameReserve.right,
        powerLeftReserve = powerReserve.left,
        powerRightReserve = powerReserve.right,
        alternativePowerBarVisible = alternativePowerBarVisible,
        alternativePowerBarHeight = alternativePowerBarHeight,
        liveAltPowerType = liveAltPowerType,
        liveAltPowerCurrent = liveAltPowerCurrent,
        liveAltPowerMax = liveAltPowerMax,
        liveAltPowerMin = liveAltPowerMin,
        altPowerTexture = altPowerTexture,
        altPowerReverseFill = alternativePowerBarReverseFill,
        altPowerR = altPowerColorR,
        altPowerG = altPowerColorG,
        altPowerB = altPowerColorB,
        altPowerA = altPowerColorA,
        altPowerHasCustomColor = type(config.alternativePowerColor) == "table",
        altPowerBgR = altPowerBgR,
        altPowerBgG = altPowerBgG,
        altPowerBgB = altPowerBgB,
        altPowerBgA = altPowerBgA,
        altPowerBackgroundShown = altPowerBackgroundShown,
        powerR = powerR,
        powerG = powerG,
        powerB = powerB,
        powerA = powerA,
        powerBgR = powerBgR,
        powerBgG = powerBgG,
        powerBgB = powerBgB,
        powerBgA = powerBgA,
        powerBackgroundShown = powerBackgroundShown,
    }

    ApplyAlternativePowerLayout(frame, alternativePowerLayoutOptions)

    ApplyClassPowerLayout(frame, {
        classPowerBarVisible = classPowerBarVisible,
        classPowerBarHeight = classPowerBarHeight,
        classPowerBarWidth = classPowerBarWidth,
        classPowerBarSpacing = classPowerBarSpacing,
        classPowerBarAnchorTo = classPowerBarAnchorTo,
        classPowerBarPoint = classPowerBarPoint,
        classPowerBarRelativePoint = classPowerBarRelativePoint,
        classPowerBarOffsetX = classPowerBarOffsetX,
        classPowerBarOffsetY = classPowerBarOffsetY,
        liveClassPowerType = liveClassPowerInfo and liveClassPowerInfo.typeId or nil,
        liveClassPowerToken = liveClassPowerInfo and liveClassPowerInfo.token or nil,
        liveClassPowerCurrent = liveClassPowerInfo and liveClassPowerInfo.current or 0,
        liveClassPowerMax = liveClassPowerInfo and liveClassPowerInfo.max or 0,
        classPowerTexture = classPowerTexture,
        classPowerR = classPowerR,
        classPowerG = classPowerG,
        classPowerB = classPowerB,
        classPowerA = classPowerA,
        classPowerBgR = classPowerBgR,
        classPowerBgG = classPowerBgG,
        classPowerBgB = classPowerBgB,
        classPowerBgA = classPowerBgA,
        classPowerBackgroundShown = classPowerBackgroundShown,
        classPowerBorderR = classPowerBorderR,
        classPowerBorderG = classPowerBorderG,
        classPowerBorderB = classPowerBorderB,
        classPowerBorderA = classPowerBorderA,
    })

    if frame.Elements.CastBar then
        local showCastBar = config.showCastBar ~= false
        local showCastBarIcon = config.showCastBarIcon ~= false
        local castBarHeight = tonumber(config.castBarHeight) or 10
        local castBarPoint = config.castBarPoint or "BOTTOMLEFT"
        local castBarRelativePoint = config.castBarRelativePoint or "TOPLEFT"
        local castBarOffsetX = tonumber(config.castBarOffsetX) or 0
        local castBarOffsetY = tonumber(config.castBarOffsetY) or 4

        ApplyCastBarLayout(frame, {
            showCastBar = showCastBar,
            showCastBarIcon = showCastBarIcon,
            castBarHeight = castBarHeight,
            castBarPoint = castBarPoint,
            castBarRelativePoint = castBarRelativePoint,
            castBarOffsetX = castBarOffsetX,
            castBarOffsetY = castBarOffsetY,
            castTexture = castTexture,
            castBarColor = config.castBarColor,
            castBarInterruptibleColor = config.castBarInterruptibleColor or config.castBarUninterruptibleColor,
            borderInset = borderInset,
            width = width,
        })
    end

    -- Portrait
    if frame.Elements.Portrait then
        ApplyPortraitLayout(self, frame, {
            portraitEnabled = portraitEnabled,
            portraitEffectiveSize = portraitEffectiveSize,
            portraitInside = portraitInside,
            portraitInsideSide = portraitInsideSide,
            portraitInsideAnchorTo = portraitInsideAnchorTo,
            frameLeftReserve = frameReserve.left,
            frameRightReserve = frameReserve.right,
            healthLeftReserve = healthReserve.left,
            healthRightReserve = healthReserve.right,
            powerLeftReserve = powerReserve.left,
            powerRightReserve = powerReserve.right,
            portraitAnchorTo = portraitAnchorTo,
            portraitPoint = portraitPoint,
            portraitRelativePoint = portraitRelativePoint,
            portraitOffsetX = portraitOffsetX,
            portraitOffsetY = portraitOffsetY,
            borderInset = borderInset,
            borderR = borderR,
            borderG = borderG,
            borderB = borderB,
            borderA = borderA,
        })
    end

    local overlayEntries = {
        {
            holder = frame.Elements.RaidTargetIcon,
            options = {
                enabled = raidTargetEnabled,
                placement = raidTargetConfig.placement or "ATTACHED",
                size = raidTargetSize,
                scale = raidTargetScale,
                padding = tonumber(raidTargetConfig.padding) or 2,
                insideSide = raidTargetConfig.insideSide or "RIGHT",
                insideAnchorTo = raidTargetConfig.insideAnchorTo or "Frame",
                frameLeftReserve = frameReserve.left,
                frameRightReserve = frameReserve.right,
                healthLeftReserve = healthReserve.left,
                healthRightReserve = healthReserve.right,
                powerLeftReserve = powerReserve.left,
                powerRightReserve = powerReserve.right,
                anchorTo = raidTargetAnchorTo,
                point = raidTargetPoint,
                relativePoint = raidTargetRelativePoint,
                offsetX = raidTargetOffsetX,
                offsetY = raidTargetOffsetY,
                borderInset = borderInset,
                _elementKey = "RaidTargetIcon",
                updateFunc = function(targetFrame)
                    self:UpdateRaidTargetIcon(targetFrame)
                end,
            },
        },
        {
            holder = frame.Elements.LeaderIcon,
            options = {
                enabled = leaderEnabled,
                placement = leaderPlacement,
                size = leaderSize,
                scale = leaderScale,
                padding = leaderPadding,
                insideSide = leaderInsideSide,
                insideAnchorTo = leaderConfig.insideAnchorTo or "Frame",
                frameLeftReserve = frameReserve.left,
                frameRightReserve = frameReserve.right,
                healthLeftReserve = healthReserve.left,
                healthRightReserve = healthReserve.right,
                powerLeftReserve = powerReserve.left,
                powerRightReserve = powerReserve.right,
                anchorTo = leaderAnchorTo,
                point = leaderPoint,
                relativePoint = leaderRelativePoint,
                offsetX = leaderOffsetX,
                offsetY = leaderOffsetY,
                borderInset = borderInset,
                _elementKey = "LeaderIcon",
                updateFunc = function(targetFrame)
                    self:UpdateLeaderIcon(targetFrame)
                end,
            },
        },
        {
            holder = frame.Elements.RoleIcon,
            options = {
                enabled = roleEnabled,
                placement = rolePlacement,
                size = roleSize,
                scale = roleScale,
                padding = rolePadding,
                insideSide = roleInsideSide,
                insideAnchorTo = roleConfig.insideAnchorTo or "Frame",
                frameLeftReserve = frameReserve.left,
                frameRightReserve = frameReserve.right,
                healthLeftReserve = healthReserve.left,
                healthRightReserve = healthReserve.right,
                powerLeftReserve = powerReserve.left,
                powerRightReserve = powerReserve.right,
                anchorTo = roleAnchorTo,
                point = rolePoint,
                relativePoint = roleRelativePoint,
                offsetX = roleOffsetX,
                offsetY = roleOffsetY,
                borderInset = borderInset,
                _elementKey = "RoleIcon",
                updateFunc = function(targetFrame)
                    self:UpdateRoleIcon(targetFrame)
                end,
            },
        },
        {
            holder = frame.Elements.CombatIndicator,
            options = {
                enabled = combatEnabled,
                placement = combatPlacement,
                size = combatSize,
                scale = combatScale,
                padding = combatPadding,
                insideSide = combatInsideSide,
                insideAnchorTo = combatConfig.insideAnchorTo or "Frame",
                frameLeftReserve = frameReserve.left,
                frameRightReserve = frameReserve.right,
                healthLeftReserve = healthReserve.left,
                healthRightReserve = healthReserve.right,
                powerLeftReserve = powerReserve.left,
                powerRightReserve = powerReserve.right,
                anchorTo = combatAnchorTo,
                point = combatPoint,
                relativePoint = combatRelativePoint,
                offsetX = combatOffsetX,
                offsetY = combatOffsetY,
                borderInset = borderInset,
                customLayout = combatUsesOverlay,
                _elementKey = "CombatIndicator",
                updateFunc = function(targetFrame)
                    self:UpdateCombatIndicator(targetFrame)
                end,
            },
        },
        {
            holder = frame.Elements.RestingIndicator,
            options = {
                enabled = restingEnabled,
                placement = restingPlacement,
                size = restingSize,
                scale = restingScale,
                padding = restingPadding,
                insideSide = restingInsideSide,
                insideAnchorTo = restingConfig.insideAnchorTo or "Frame",
                frameLeftReserve = frameReserve.left,
                frameRightReserve = frameReserve.right,
                healthLeftReserve = healthReserve.left,
                healthRightReserve = healthReserve.right,
                powerLeftReserve = powerReserve.left,
                powerRightReserve = powerReserve.right,
                anchorTo = restingAnchorTo,
                point = restingPoint,
                relativePoint = restingRelativePoint,
                offsetX = restingOffsetX,
                offsetY = restingOffsetY,
                borderInset = borderInset,
                customLayout = restingUsesOverlay,
                _elementKey = "RestingIndicator",
                updateFunc = function(targetFrame)
                    self:UpdateRestingIndicator(targetFrame)
                end,
            },
        },
        {
            holder = frame.Elements.ReadyCheckIndicator,
            options = {
                enabled = readyCheckEnabled,
                placement = readyCheckPlacement,
                size = readyCheckSize,
                scale = readyCheckScale,
                padding = readyCheckPadding,
                insideSide = readyCheckInsideSide,
                insideAnchorTo = readyCheckConfig.insideAnchorTo or "Frame",
                frameLeftReserve = frameReserve.left,
                frameRightReserve = frameReserve.right,
                healthLeftReserve = healthReserve.left,
                healthRightReserve = healthReserve.right,
                powerLeftReserve = powerReserve.left,
                powerRightReserve = powerReserve.right,
                anchorTo = readyCheckAnchorTo,
                point = readyCheckPoint,
                relativePoint = readyCheckRelativePoint,
                offsetX = readyCheckOffsetX,
                offsetY = readyCheckOffsetY,
                borderInset = borderInset,
                _elementKey = "ReadyCheckIndicator",
                updateFunc = function(targetFrame)
                    self:UpdateReadyCheckIndicator(targetFrame)
                end,
            },
        },
    }

    ApplyOverlayIndicatorBatch(self, frame, overlayEntries)

    local visibleFrameReserve = { left = 0, right = 0 }
    local visibleHealthReserve = { left = 0, right = 0 }
    local visiblePowerReserve = { left = 0, right = 0 }

    if portraitInside and frame.Elements.Portrait and frame.Elements.Portrait:IsShown() then
        ApplyVisibleReserve(
            visibleFrameReserve,
            visibleHealthReserve,
            visiblePowerReserve,
            portraitInsideAnchorTo,
            portraitInsideSide,
            frame.Elements.Portrait,
            portraitEffectiveSize,
            1,
            portraitPadding
        )
    end

    ApplyVisibleEntryReserves(visibleFrameReserve, visibleHealthReserve, visiblePowerReserve, overlayEntries)

    barLayoutOptions.frameLeftReserve = visibleFrameReserve.left
    barLayoutOptions.frameRightReserve = visibleFrameReserve.right
    barLayoutOptions.healthLeftReserve = visibleHealthReserve.left
    barLayoutOptions.healthRightReserve = visibleHealthReserve.right
    barLayoutOptions.powerLeftReserve = visiblePowerReserve.left
    barLayoutOptions.powerRightReserve = visiblePowerReserve.right
    ApplyHealthAndPowerLayout(self, frame, barLayoutOptions)

    alternativePowerLayoutOptions.frameLeftReserve = visibleFrameReserve.left
    alternativePowerLayoutOptions.frameRightReserve = visibleFrameReserve.right
    alternativePowerLayoutOptions.powerLeftReserve = visiblePowerReserve.left
    alternativePowerLayoutOptions.powerRightReserve = visiblePowerReserve.right
    ApplyAlternativePowerLayout(frame, alternativePowerLayoutOptions)

    if frame.Elements.Portrait then
        ApplyPortraitLayout(self, frame, {
            portraitEnabled = portraitEnabled,
            portraitEffectiveSize = portraitEffectiveSize,
            portraitInside = portraitInside,
            portraitInsideSide = portraitInsideSide,
            portraitInsideAnchorTo = portraitInsideAnchorTo,
            frameLeftReserve = visibleFrameReserve.left,
            frameRightReserve = visibleFrameReserve.right,
            healthLeftReserve = visibleHealthReserve.left,
            healthRightReserve = visibleHealthReserve.right,
            powerLeftReserve = visiblePowerReserve.left,
            powerRightReserve = visiblePowerReserve.right,
            portraitAnchorTo = portraitAnchorTo,
            portraitPoint = portraitPoint,
            portraitRelativePoint = portraitRelativePoint,
            portraitOffsetX = portraitOffsetX,
            portraitOffsetY = portraitOffsetY,
            borderInset = borderInset,
            borderR = borderR,
            borderG = borderG,
            borderB = borderB,
            borderA = borderA,
        })
    end

    for _, entry in ipairs(overlayEntries) do
        local options = entry.options
        options.frameLeftReserve = visibleFrameReserve.left
        options.frameRightReserve = visibleFrameReserve.right
        options.healthLeftReserve = visibleHealthReserve.left
        options.healthRightReserve = visibleHealthReserve.right
        options.powerLeftReserve = visiblePowerReserve.left
        options.powerRightReserve = visiblePowerReserve.right
    end

    ApplyOverlayIndicatorBatch(self, frame, overlayEntries)

    ApplyClassificationIndicatorLayout(frame, {
        effect = classificationEffect,
        classification = liveClassification,
    })

    -- Texts
    local newTexts = config.Texts or {}
    frame.Texts = frame.Texts or {}
    frame.Tags = frame.Tags or {}

    local staleTextKeys = {}
    for key in pairs(frame.Texts) do
        if newTexts[key] == nil then
            staleTextKeys[#staleTextKeys + 1] = key
        end
    end

    for _, key in ipairs(staleTextKeys) do
        if self.UpdateTextElement then
            self:UpdateTextElement(frame, key)
        elseif frame.Texts[key] then
            frame.Texts[key]:SetText("")
            frame.Texts[key]:Hide()
        end
        frame.Texts[key] = nil
        frame.Tags[key] = nil
        if frame._focalPointTextErrors then
            frame._focalPointTextErrors[key] = nil
        end
    end

    if config.Texts then
        for key, textConfig in pairs(newTexts) do
            if textConfig
                and textConfig.enabled ~= false
                and not frame.Texts[key]
                and self.CreateTextElement
            then
                self:CreateTextElement(frame, key, textConfig)
            end
            self:ApplyTextElementConfig(frame, key, frame.Texts[key], textConfig)
        end
    end

end

function UF:ApplyRangeFade(frame)
    if not frame then
        return
    end

    if frame.unit == "target"
        and not IsPreviewModeEnabled()
        and UnitExists
        and not UnitExists("target")
    then
        frame._rangeCurrentAlpha = 0
        frame._rangeTargetAlpha = 0
        if frame.RangeFadeDriver then
            frame.RangeFadeDriver:Hide()
        end
        frame:SetAlpha(0)
        return
    end

    if frame.unit == "targettarget"
        and not IsPreviewModeEnabled()
        and UnitExists
        and not UnitExists("targettarget")
    then
        frame._rangeCurrentAlpha = 0
        frame._rangeTargetAlpha = 0
        if frame.RangeFadeDriver then
            frame.RangeFadeDriver:Hide()
        end
        frame:SetAlpha(0)
        return
    end

    if frame.unit == "focustarget"
        and not IsPreviewModeEnabled()
        and UnitExists
        and not UnitExists("focustarget")
    then
        frame._rangeCurrentAlpha = 0
        frame._rangeTargetAlpha = 0
        if frame.RangeFadeDriver then
            frame.RangeFadeDriver:Hide()
        end
        frame:SetAlpha(0)
        return
    end

    if type(frame.unit) == "string"
        and frame.unit:match("^boss%d+$")
        and not IsPreviewModeEnabled()
        and UnitExists
        and not UnitExists(frame.unit)
    then
        frame._rangeCurrentAlpha = 0
        frame._rangeTargetAlpha = 0
        if frame.RangeFadeDriver then
            frame.RangeFadeDriver:Hide()
        end
        frame:SetAlpha(0)
        return
    end

    local config = frame.config or GetUnitDB(frame.unit)
    local baseAlpha = (config and config.alpha) or 1
    local rangeMultiplier = GetRangeFadeMultiplier(frame)
    local targetAlpha = baseAlpha * rangeMultiplier

    if frame.unit ~= "target" or not frame:IsShown() then
        frame._rangeCurrentAlpha = targetAlpha
        frame._rangeTargetAlpha = targetAlpha
        frame:SetAlpha(targetAlpha)
        if frame.RangeFadeDriver then
            frame.RangeFadeDriver:Hide()
        end
        return
    end

    frame._rangeTargetAlpha = targetAlpha
    if type(frame._rangeCurrentAlpha) ~= "number" then
        frame._rangeCurrentAlpha = targetAlpha
        frame:SetAlpha(targetAlpha)
        if frame.RangeFadeDriver then
            frame.RangeFadeDriver:Hide()
        end
        return
    end

    local driver = EnsureRangeFadeDriver(frame)
    if not driver then
        frame._rangeCurrentAlpha = targetAlpha
        frame:SetAlpha(targetAlpha)
        return
    end

    if math.abs(frame._rangeCurrentAlpha - targetAlpha) < 0.01 then
        frame._rangeCurrentAlpha = targetAlpha
        frame:SetAlpha(targetAlpha)
        driver:Hide()
        return
    end

    driver:Show()
end

function UF:ApplyTestValues(frame)
    self:RefreshUnitBarValues(frame)

    if IsPreviewModeEnabled()
        and frame
        and frame.unit == "player"
        and frame.config
        and frame.config.showAlternativePowerBar
        and frame.Elements
        and frame.Elements.AlternativePowerBar
        and GetSecondaryPowerTypeForUnit(frame.unit) ~= nil
    then
        local previewValues = self:GetTestPreviewValues(frame) or {}
        local minAltPower = previewValues.altPowerMin or 0
        local currentAltPower = previewValues.altPowerCurrent or 72
        local maxAltPower = previewValues.altPowerMax or 100
        local minAltPowerSafe = ToSafeNumberValue(minAltPower)
        local currentAltPowerSafe = ToSafeNumberValue(currentAltPower)
        local maxAltPowerSafe = ToSafeNumberValue(maxAltPower)
        local maxAltPowerEffective = math.max(maxAltPowerSafe, minAltPowerSafe + 1)
        if currentAltPowerSafe < minAltPowerSafe then
            currentAltPowerSafe = minAltPowerSafe
        elseif currentAltPowerSafe > maxAltPowerEffective then
            currentAltPowerSafe = maxAltPowerEffective
        end

        frame.LiveValues = frame.LiveValues or {}
        frame.LiveValues.altPowerVisible = true
        frame.LiveValues.altPowerType = GetSecondaryPowerTypeForUnit(frame.unit)
        frame.LiveValues.altPowerMinRaw = minAltPower
        frame.LiveValues.altPowerCurrentRaw = currentAltPower
        frame.LiveValues.altPowerMaxRaw = maxAltPower
        frame.LiveValues.altPowerCurrentText = FormatDisplayNumber(currentAltPower)
        frame.LiveValues.altPowerMaxText = FormatDisplayNumber(maxAltPower)
        frame.LiveValues.altPowerCurrentSafe = ToSafeNumberValue(currentAltPower)
        frame.LiveValues.altPowerMaxSafe = ToSafeNumberValue(maxAltPower)
        frame.LiveValues.altPowerCurrentAbbr = ResolveBlizzardAbbreviation(currentAltPower, frame.LiveValues.altPowerCurrentText)
        frame.LiveValues.altPowerMaxAbbr = ResolveBlizzardAbbreviation(maxAltPower, frame.LiveValues.altPowerMaxText)

        frame.Elements.AlternativePowerBar:SetMinMaxValues(minAltPowerSafe, maxAltPowerEffective)
        frame.Elements.AlternativePowerBar:SetValue(currentAltPowerSafe)
        self:ApplyConfig(frame)
    end

    local castBar = frame and frame.Elements and frame.Elements.CastBar
    local shouldRunPreviewCast = IsPreviewModeEnabled() and IsDetailedPreviewEnabled and IsDetailedPreviewEnabled(frame)

    if shouldRunPreviewCast then
        frame._fpPreviewCastState = frame._fpPreviewCastState or "off"
        if frame._fpPreviewCastState ~= "preview_running" then
            StartCastBarPreview(frame)
            frame._fpPreviewCastState = "preview_running"
        elseif not (castBar and castBar.isPreview and castBar.isCasting) then
            StartCastBarPreview(frame)
            frame._fpPreviewCastState = "preview_running"
        end
    else
        if frame._fpPreviewCastState == "preview_running" then
            StopCastBar(frame)
            frame._fpPreviewCastState = "off"
        end

        if not IsPreviewModeEnabled() then
            StartCastBar(frame)
        end
    end

    if self.ApplyTestTextValues then
        self:ApplyTestTextValues(frame)
    end
end

function UF:RegisterVisibilityEvents(frame)
    return RegisterVisibilityEvents(self, frame)
end

function UF:RegisterHealthBarEvents(frame)
    return Health.RegisterEvents(self, frame)
end

function UF:RegisterAlternativePowerEvents(frame)
    return Power.RegisterAlternativeEvents(self, frame)
end

function UF:RegisterClassPowerEvents(frame)
    return ClassPower.RegisterEvents(self, frame)
end

function UF:Build(unit, options)
    options = options or {}
    local config = GetUnitDB(unit)
    if not config or (config.enabled == false and not options.allowDisabledForUnlock) then
        return nil
    end

    local function RunBuildStep(label, fn)
        local ok, result = xpcall(fn, function(err)
            return tostring(err)
        end)
        if not ok then
            error(string.format("Build step failed for %s [%s]: %s", tostring(unit), tostring(label), tostring(result)))
        end
        return result
    end

    if unit == "player" and config.showAlternativePowerBar then
        EnsurePlayerAltPowerText(config)
    end
    if unit == "player" and config.showClassPowerBar then
        EnsurePlayerClassPowerText(config)
    end

    local frame = RunBuildStep("CreateBaseFrame", function()
        return self:CreateBaseFrame(unit, config)
    end)
    if not frame then
        error(string.format("Build step failed for %s [CreateBaseFrame]: returned nil", tostring(unit)))
    end
    if StateRuntime.Ensure then
        RunBuildStep("StateRuntime.Ensure", function()
            StateRuntime.Ensure(frame)
        end)
    end
    if StateRuntime.SetPhase then
        RunBuildStep("StateRuntime.SetPhase(built)", function()
            StateRuntime.SetPhase(frame, "built")
        end)
    end
    RunBuildStep("BuildElements", function()
        BuildElements(self, frame)
    end)
    RunBuildStep("RegisterBuildEvents", function()
        RegisterBuildEvents(self, frame)
    end)

    RunBuildStep("ApplyConfig", function()
        self:ApplyConfig(frame)
    end)
    RunBuildStep("ApplyTestValues", function()
        self:ApplyTestValues(frame)
    end)
    RunBuildStep("Refresh", function()
        self:Refresh(frame)
    end)

    return frame
end

function UF:Refresh(frame, refreshRequest)
    if not frame then
        return
    end

    local config = GetUnitDB(frame.unit)
    if not config then
        return
    end
    if config.enabled == false and not (FocalPoint and FocalPoint.framesUnlocked == true) then
        if ClearFrameVisualState then
            ClearFrameVisualState(frame, "disabled_live_refresh")
        end
        if frame.EnableMouse then
            frame:EnableMouse(false)
        end
        if frame.SetMouseClickEnabled then
            pcall(frame.SetMouseClickEnabled, frame, false)
        end
        if frame.SetAlpha then
            frame:SetAlpha(0)
        end
        if frame.Hide and not IsProtectedFrameInCombat(frame) then
            frame:Hide()
        end
        if StateRuntime.SetPhase then
            StateRuntime.SetPhase(frame, "disabled")
        end
        return
    end

    if StateRuntime.Ensure then
        StateRuntime.Ensure(frame)
    end
    if StateRuntime.SetPhase then
        StateRuntime.SetPhase(frame, "bound")
    end

    if HandleMissingUnit(frame) then
        if StateRuntime.SetPhase then
            StateRuntime.SetPhase(frame, "empty_valid")
        end
        return
    end

    ApplyRefreshFlow(self, frame, config, refreshRequest)

    if StateRuntime.Guard and frame.unit ~= "player" and not IsPreviewModeEnabled() then
        local shouldExist = DoesUnitSeemPresent and DoesUnitSeemPresent(frame.unit)
        local shown = frame.IsShown and frame:IsShown() or false
        StateRuntime.Guard(frame, "visible_missing_unit", not (shown and not shouldExist), "frame visible while unit seems absent")
    end

    if StateRuntime.SetPhase then
        local shown = frame.IsShown and frame:IsShown()
        StateRuntime.SetPhase(frame, shown and "visible" or "bound")
    end
end

local function ExpandActiveProfileUnits(owner)
    local orderedUnits = {}
    local activeUnits = {}
    local unitOrder = owner and owner.Constants and owner.Constants.UnitOrder or {}
    local includeDisabledForUnlock = owner and owner.framesUnlocked == true

    for _, unitKey in ipairs(unitOrder or {}) do
        local unitConfig = GetUnitDB(unitKey)
        local enabled = type(unitConfig) == "table" and unitConfig.enabled ~= false

        if enabled or (includeDisabledForUnlock and type(unitConfig) == "table") then
            if unitKey == "boss" then
                for bossIndex = 1, 5 do
                    local bossUnit = "boss" .. bossIndex
                    orderedUnits[#orderedUnits + 1] = bossUnit
                    activeUnits[bossUnit] = true
                end
            else
                orderedUnits[#orderedUnits + 1] = unitKey
                activeUnits[unitKey] = true
            end
        end
    end

    return orderedUnits, activeUnits
end

function FocalPoint:DeactivateUnitFrame(unit, preserveForReuse)
    if not unit then
        return nil
    end

    self.frames = self.frames or {}
    self.framePool = self.framePool or {}

    local frame = self.frames[unit]
    if not frame then
        return nil
    end

    if frame._unitWatchRegistered and UnregisterUnitWatch then
        UnregisterUnitWatch(frame)
        frame._unitWatchRegistered = false
    end

    if ClearFrameVisualState then
        ClearFrameVisualState(frame)
    end

    if frame.SelectionOverlay and frame.SelectionOverlay.Hide then
        frame.SelectionOverlay:Hide()
    end
    if frame.MoveOverlay and frame.MoveOverlay.Hide then
        frame.MoveOverlay:Hide()
    end
    if frame.EnableMouse then
        frame:EnableMouse(false)
    end
    if frame.SetMouseClickEnabled then
        pcall(frame.SetMouseClickEnabled, frame, false)
    end
    if frame.SetAlpha then
        frame:SetAlpha(0)
    end
    if frame.Hide then
        frame:Hide()
    end

    self.frames[unit] = nil
    if preserveForReuse then
        self.framePool[unit] = frame
    else
        self.framePool[unit] = nil
    end

    return frame
end

function FocalPoint:SpawnUnitFrame(unit, options)
    options = options or {}
    self.frames = self.frames or {}
    self.framePool = self.framePool or {}
    self.spawnDiagnostics = self.spawnDiagnostics or {}
    local unitDB = GetUnitDB(unit)

    if self.frames[unit] then
        self.spawnDiagnostics[unit] = {
            ok = true,
            hasConfig = type(unitDB) == "table",
            enabled = type(unitDB) == "table" and unitDB.enabled ~= false or false,
            reason = "active_reused",
        }
        self:RefreshUnitFrame(unit)
        return self.frames[unit]
    end

    if self.framePool[unit] then
        local recycledFrame = self.framePool[unit]
        self.framePool[unit] = nil
        self.frames[unit] = recycledFrame
        self.spawnDiagnostics[unit] = {
            ok = true,
            hasConfig = type(unitDB) == "table",
            enabled = type(unitDB) == "table" and unitDB.enabled ~= false or false,
            reason = "pooled_reused",
        }
        self:RefreshUnitFrame(unit)
        return recycledFrame
    end

    local buildOk, frameOrError = xpcall(function()
        return UF:Build(unit, options)
    end, function(err)
        return tostring(err)
    end)

    if not buildOk then
        self.spawnDiagnostics[unit] = {
            ok = false,
            hasConfig = type(unitDB) == "table",
            enabled = type(unitDB) == "table" and unitDB.enabled ~= false or false,
            reason = frameOrError,
        }
        if self.Warn then
            self:Warn("Spawn failed for " .. tostring(unit) .. ": " .. tostring(frameOrError))
        end
        return nil
    end

    local frame = frameOrError
    if frame then
        self.frames[unit] = frame
        self.spawnDiagnostics[unit] = {
            ok = true,
            hasConfig = true,
            enabled = type(unitDB) == "table" and unitDB.enabled ~= false or false,
            reason = type(unitDB) == "table" and unitDB.enabled == false and options.allowDisabledForUnlock and "spawned_editor_disabled" or "spawned",
        }
    else
        local reason = "UF:Build returned nil unexpectedly"
        if type(unitDB) ~= "table" then
            reason = "unit config missing"
        elseif unitDB.enabled == false then
            reason = "unit disabled in config"
        end

        self.spawnDiagnostics[unit] = {
            ok = false,
            hasConfig = type(unitDB) == "table",
            enabled = type(unitDB) == "table" and unitDB.enabled ~= false or false,
            reason = reason,
        }
        if reason == "UF:Build returned nil unexpectedly" and self.Warn then
            self:Warn("Could not spawn frame for " .. tostring(unit) .. " (" .. tostring(reason) .. ")")
        end
    end

    return frame
end

function FocalPoint:RebuildFramesForActiveProfile()
    local general = self.db and self.db.profile and self.db.profile.General or {}
    self.TAG_UPDATE_INTERVAL = general.TagUpdateInterval or 0.25
    self.SEPARATOR = general.Separator or "||"
    self.TOT_SEPARATOR = general.ToTSeparator or "»"

    if self.ApplyGeneralSettings then
        self:ApplyGeneralSettings()
    end

    self.frames = self.frames or {}
    self.framePool = self.framePool or {}

    local orderedUnits, activeUnits = ExpandActiveProfileUnits(self)
    local unitsToDeactivate = {}

    for unit in pairs(self.frames) do
        if not activeUnits[unit] then
            unitsToDeactivate[#unitsToDeactivate + 1] = unit
        end
    end

    for _, unit in ipairs(unitsToDeactivate) do
        self:DeactivateUnitFrame(unit, true)
    end

    for _, unit in ipairs(orderedUnits) do
        if self.frames[unit] then
            self:RefreshUnitFrame(unit)
        elseif self.framePool[unit] then
            local recycledFrame = self.framePool[unit]
            self.framePool[unit] = nil
            self.frames[unit] = recycledFrame
            self:RefreshUnitFrame(unit)
        elseif self.SpawnUnitFrame then
            self:SpawnUnitFrame(unit, { allowDisabledForUnlock = self.framesUnlocked == true })
        end
    end

    if self.RefreshEditorSelectionVisuals then
        self:RefreshEditorSelectionVisuals()
    end
end

local function GetActiveProfileUnitConfig(addon, unitKey)
    local profile = addon and addon.db and addon.db.profile
    local units = profile and profile.Units
    if type(units) ~= "table" or type(unitKey) ~= "string" or unitKey == "" then
        return nil
    end

    return units[unitKey]
end

local function ValidateEditorSelectionForProfile(addon)
    local editorStateApi = addon
        and addon.GUI
        and addon.GUI.Editor
        and addon.GUI.Editor.State
    local state = editorStateApi and editorStateApi.Get and editorStateApi.Get()
    local profile = addon and addon.db and addon.db.profile
    if type(state) ~= "table" or type(profile) ~= "table" then
        return
    end

    local editorMode = addon.EditorMode or (addon.GUI and addon.GUI.Editor and addon.GUI.Editor.Mode)
    if editorMode and editorMode.SyncStateFromProfile then
        editorMode.SyncStateFromProfile(state, profile)
    end

    local general = profile.General or {}
    local activeThemeId = general.ActiveThemeId
    if type(activeThemeId) ~= "string" or activeThemeId == "" then
        activeThemeId = "default"
    end
    if editorStateApi.SetSelectedThemeId then
        editorStateApi.SetSelectedThemeId(activeThemeId)
    else
        state.selectedThemeId = activeThemeId
    end

    local selectedUnit = state.selectedUnit
    if type(GetActiveProfileUnitConfig(addon, selectedUnit)) ~= "table" then
        selectedUnit = "player"
        if editorStateApi.SetSelectedUnit then
            editorStateApi.SetSelectedUnit(selectedUnit)
        else
            state.selectedUnit = selectedUnit
        end
    end

    local unitConfig = GetActiveProfileUnitConfig(addon, selectedUnit)
    local texts = type(unitConfig) == "table" and unitConfig.Texts or nil
    local selectedTextId = state.selectedTextId or state.selectedTextKey
    if type(texts) ~= "table" or type(texts[selectedTextId]) ~= "table" then
        state.selectedTextId = nil
        state.selectedTextKey = nil
    end

    local selectedIndicatorKey = state.selectedIndicatorKey
    if selectedIndicatorKey == nil or type(selectedIndicatorKey) ~= "string" or selectedIndicatorKey == "" then
        state.selectedIndicatorKey = "Portrait"
    elseif type(unitConfig) == "table" and selectedIndicatorKey ~= "Portrait" and type(unitConfig[selectedIndicatorKey]) ~= "table" then
        state.selectedIndicatorKey = "Portrait"
    end

    local selectedAuraKey = state.selectedAuraKey
    if type(unitConfig) ~= "table" or type(unitConfig[selectedAuraKey]) ~= "table" then
        if type(unitConfig) == "table" and type(unitConfig.Buffs) == "table" then
            state.selectedAuraKey = "Buffs"
        elseif type(unitConfig) == "table" and type(unitConfig.Debuffs) == "table" then
            state.selectedAuraKey = "Debuffs"
        else
            state.selectedAuraKey = nil
        end
    end
end

function FocalPoint:HandleActiveProfileChanged(reason)
    ValidateEditorSelectionForProfile(self)

    if self.RebuildFramesForActiveProfile then
        self:RebuildFramesForActiveProfile()
    end

    if self.RefreshEditorSelectionVisuals then
        self:RefreshEditorSelectionVisuals()
    end

    if self.GUI and self.GUI.RequestRefreshOptions then
        self.GUI:RequestRefreshOptions()
    end
end

function FocalPoint:RefreshUnitFrame(unit)
    if unit == "boss" then
        if self.EnsureBossFrames then
            self:EnsureBossFrames()
        end

        if not self.frames then
            return
        end

        for bossIndex = 1, 5 do
            local bossUnit = "boss" .. bossIndex
            if self.frames[bossUnit] then
                UF:Refresh(self.frames[bossUnit])
            end
        end
        return
    end

    if not self.frames or not self.frames[unit] then
        return
    end

    UF:Refresh(self.frames[unit])
end
