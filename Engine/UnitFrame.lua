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
local InsideLayout = FocalPoint.UnitFrameInsideLayout or {}
local Layout = FocalPoint.UnitFrameLayout or {}
local BarLayout = FocalPoint.UnitFrameBarLayout or {}
local Power = FocalPoint.UnitFramePower or {}
local Portrait = FocalPoint.UnitFramePortrait or {}

-- Indicator modules
local Indicators = FocalPoint.UnitFrameIndicators or {}
local RaidTarget = FocalPoint.UnitFrameRaidTarget or {}
local Leader = FocalPoint.UnitFrameLeader or {}
local Role = FocalPoint.UnitFrameRole or {}
local Combat = FocalPoint.UnitFrameCombat or {}
local Resting = FocalPoint.UnitFrameResting or {}
local ReadyCheck = FocalPoint.UnitFrameReadyCheck or {}

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
local StartCastBar = Cast.Start
local StartCastBarPreview = Cast.StartPreview
local QueueCastBarRefresh = Cast.QueueRefresh
local GetAnchorTarget = Factory.GetAnchorTarget
local CreateBaseFrame = Factory.CreateBaseFrame
local CreateHealthBar = Factory.CreateHealthBar
local CreatePowerBar = Factory.CreatePowerBar
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
local ApplyBaseFrameLayout = Layout.ApplyBaseFrame
local ApplyHealthAndPowerLayout = BarLayout.ApplyHealthAndPower
local ApplyAlternativePowerLayout = BarLayout.ApplyAlternativePower
local EnsurePlayerAltPowerText = BuildRuntime.EnsurePlayerAltPowerText
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

function UF:CreateAlternativePowerBar(frame)
    return CreateAlternativePowerBar(frame)
end

function UF:CreateCastBar(frame)
    return CreateCastBar(frame)
end

function UF:RefreshUnitBarValues(frame)
    return Power.RefreshUnitBarValues(self, frame)
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
    local showAlternativePowerBar = config.showAlternativePowerBar and true or false
    local alternativePowerBarHeight = showAlternativePowerBar and (config.alternativePowerBarHeight or 5) or 0
    local liveAltPowerType, liveAltPowerCurrent, liveAltPowerMax = GetSecondaryPowerValues(frame.unit)
    local alternativePowerBarVisible = showAlternativePowerBar and liveAltPowerType ~= nil and liveAltPowerMax > 0
    local borderInset = 1

    local portraitConfig = config.Portrait or {}
    local raidTargetConfig = config.RaidTargetIcon or {}
    local leaderConfig = config.LeaderIcon or {}
    local roleConfig = config.RoleIcon or {}
    local combatConfig = config.CombatIndicator or {}
    local restingConfig = config.RestingIndicator or {}
    local readyCheckConfig = config.ReadyCheckIndicator or {}
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
    ApplyReserveToArea(frameReserve, healthReserve, powerReserve, combatConfig.insideAnchorTo or "Frame", combatInsideSide, combatEnabled, combatPlacement, combatSize, combatScale, combatPadding)
    ApplyReserveToArea(frameReserve, healthReserve, powerReserve, restingConfig.insideAnchorTo or "Frame", restingInsideSide, restingEnabled, restingPlacement, restingSize, restingScale, restingPadding)
    ApplyReserveToArea(frameReserve, healthReserve, powerReserve, readyCheckConfig.insideAnchorTo or "Frame", readyCheckInsideSide, readyCheckEnabled, readyCheckPlacement, readyCheckSize, readyCheckScale, readyCheckPadding)

    local healthR, healthG, healthB, healthA = UnpackColor(config.healthColor, { 0.1, 0.8, 0.1, 1 })
    local powerR, powerG, powerB, powerA = UnpackColor(config.powerColor, { 0.2, 0.4, 0.9, 1 })

    local healthBackgroundEnabled = config.healthBackground ~= false
    local healthBgR, healthBgG, healthBgB, healthBgA = UnpackColor(config.healthBackgroundColor, { 0, 0, 0, 0.35 })
    local healthBackgroundShown = healthBackgroundEnabled and (healthBgA or 0) > 0.001

    local powerBackgroundEnabled = config.powerBackground ~= false
    local powerBgR, powerBgG, powerBgB, powerBgA = UnpackColor(config.powerBackgroundColor, { 0, 0, 0, 0.35 })
    local powerBackgroundShown = powerBackgroundEnabled and (powerBgA or 0) > 0.001

    local borderR, borderG, borderB, borderA = UnpackColor(config.borderColor, { 0, 0, 0, 0 })

    if config.useClassColorPower then
        local resourceR, resourceG, resourceB, resourceA = GetPowerColorForUnit(frame.unit)
        if resourceR and resourceG and resourceB then
            powerR, powerG, powerB = resourceR, resourceG, resourceB
        end
    end

    local healthTexture = GetStatusBarTexture(config.healthBarTexture)
    local powerTexture = GetStatusBarTexture(config.powerBarTexture)
    local castTexture = GetStatusBarTexture(config.castBarTexture)
    local altPowerTexture = GetStatusBarTexture(config.alternativePowerBarTexture or config.powerBarTexture)

    if healthBarReverseFill == nil then
        healthBarReverseFill = frame.unit == "target"
    end

    if powerBarReverseFill == nil then
        powerBarReverseFill = frame.unit == "target"
    end

    if not protectedInCombat then
        ApplyBaseFrameLayout(self, frame, config, {
            width = width,
            height = height,
            alpha = alpha,
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
        altPowerTexture = altPowerTexture,
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
            castBarUninterruptibleColor = config.castBarUninterruptibleColor,
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

    -- Texts
    if config.Texts then
        for key, textConfig in pairs(config.Texts) do
            if textConfig
                and textConfig.enabled ~= false
                and (not frame.Texts or not frame.Texts[key])
                and self.CreateTextElement
            then
                frame.Texts = frame.Texts or {}
                frame.Tags = frame.Tags or {}
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
        local currentAltPower = previewValues.altPowerCurrent or 72
        local maxAltPower = previewValues.altPowerMax or 100

        frame.LiveValues = frame.LiveValues or {}
        frame.LiveValues.altPowerVisible = maxAltPower > 0
        frame.LiveValues.altPowerType = GetSecondaryPowerTypeForUnit(frame.unit)
        frame.LiveValues.altPowerCurrentRaw = currentAltPower
        frame.LiveValues.altPowerMaxRaw = maxAltPower
        frame.LiveValues.altPowerCurrentText = FormatDisplayNumber(currentAltPower)
        frame.LiveValues.altPowerMaxText = FormatDisplayNumber(maxAltPower)
        frame.LiveValues.altPowerCurrentSafe = ToSafeNumberValue(currentAltPower)
        frame.LiveValues.altPowerMaxSafe = ToSafeNumberValue(maxAltPower)
        frame.LiveValues.altPowerCurrentAbbr = ResolveBlizzardAbbreviation(currentAltPower, frame.LiveValues.altPowerCurrentText)
        frame.LiveValues.altPowerMaxAbbr = ResolveBlizzardAbbreviation(maxAltPower, frame.LiveValues.altPowerMaxText)

        frame.Elements.AlternativePowerBar:SetMinMaxValues(0, math.max(maxAltPower, 1))
        frame.Elements.AlternativePowerBar:SetValue(currentAltPower)
        self:ApplyConfig(frame)
    end

    if IsPreviewModeEnabled() then
        StartCastBarPreview(frame)
    else
        StartCastBar(frame)
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

function UF:Build(unit)
    local config = GetUnitDB(unit)
    if not config or config.enabled == false then
        return nil
    end

    if unit == "player" and config.showAlternativePowerBar then
        EnsurePlayerAltPowerText(config)
    end

    local frame = self:CreateBaseFrame(unit, config)
    BuildElements(self, frame)
    RegisterBuildEvents(self, frame)

    self:ApplyConfig(frame)
    self:ApplyTestValues(frame)
    self:Refresh(frame)

    return frame
end

function UF:Refresh(frame)
    if not frame then
        return
    end

    local config = GetUnitDB(frame.unit)
    if not config then
        return
    end

    if HandleMissingUnit(frame) then
        return
    end

    ApplyRefreshFlow(self, frame, config)
end

function FocalPoint:SpawnUnitFrame(unit)
    self.frames = self.frames or {}

    if self.frames[unit] then
        self.frames[unit]:Hide()
        self.frames[unit] = nil
    end

    local frame = UF:Build(unit)
    if frame then
        self.frames[unit] = frame
        if self.Success then
            self:Success("Spawned frame for " .. unit)
        end
    else
        if self.Warn then
            self:Warn("Could not spawn frame for " .. tostring(unit))
        end
    end

    return frame
end

function FocalPoint:RefreshUnitFrame(unit)
    if not self.frames or not self.frames[unit] then
        return
    end

    UF:Refresh(self.frames[unit])
end
