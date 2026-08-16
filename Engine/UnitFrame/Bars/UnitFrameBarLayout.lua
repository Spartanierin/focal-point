local _, FocalPoint = ...

FocalPoint.UnitFrameBarLayout = FocalPoint.UnitFrameBarLayout or {}
local BarLayout = FocalPoint.UnitFrameBarLayout
local Demo = FocalPoint.UnitFrameDemoEnvironment or {}
local Preview = FocalPoint.UnitFramePreview or {}
local AbsorbBars = FocalPoint.UnitFrameAbsorbBars or {}

local function ApplyAbsorbBarLayout(frame)
    if not frame then
        return
    end

    local config = FocalPoint.UnitFrameUtils
        and FocalPoint.UnitFrameUtils.GetUnitDB
        and FocalPoint.UnitFrameUtils.GetUnitDB(frame.unit)
    if type(config) ~= "table" then
        return
    end

    if AbsorbBars.ApplyNormalAbsorbBarStyle then
        AbsorbBars.ApplyNormalAbsorbBarStyle(frame, config)
    end
    if AbsorbBars.ApplyNormalAbsorbBarAnchor then
        AbsorbBars.ApplyNormalAbsorbBarAnchor(frame, config)
    end
    if AbsorbBars.ApplyNormalAbsorbBarVisibility then
        AbsorbBars.ApplyNormalAbsorbBarVisibility(frame, config)
    end
    if AbsorbBars.ApplyHealingAbsorbBarStyle then
        AbsorbBars.ApplyHealingAbsorbBarStyle(frame, config)
    end
    if AbsorbBars.ApplyHealingAbsorbBarAnchor then
        AbsorbBars.ApplyHealingAbsorbBarAnchor(frame, config)
    end
    if AbsorbBars.ApplyHealingAbsorbBarVisibility then
        AbsorbBars.ApplyHealingAbsorbBarVisibility(frame, config)
    end
end

local function IsPlaceholderUnitEnabled(frame)
    if not frame or not frame.unit then
        return true
    end

    local unitKey = frame.unit
    if type(unitKey) == "string" and unitKey:match("^boss%d+$") then
        unitKey = "boss"
    end

    local config = FocalPoint.UnitFrameUtils and FocalPoint.UnitFrameUtils.GetUnitDB and FocalPoint.UnitFrameUtils.GetUnitDB(unitKey)
    return type(config) ~= "table" or config.enabled ~= false
end

local function IsSecretValue(value)
    return issecretvalue and issecretvalue(value) or false
end

-- Health and power bar layout stays separate from live value refresh so the
-- main runtime can focus on orchestration.

function BarLayout.ApplyHealthAndPower(owner, frame, options)
    local borderInset = options.borderInset
    local showPowerBar = options.showPowerBar
    local powerBarHeight = options.powerBarHeight
    local alternativePowerBarVisible = options.alternativePowerBarVisible
    local alternativePowerBarHeight = options.alternativePowerBarHeight
    local healthBarReverseFill = options.healthBarReverseFill == true
    local powerBarReverseFill = options.powerBarReverseFill == true
    local frameLeftReserve = tonumber(options.frameLeftReserve) or 0
    local frameRightReserve = tonumber(options.frameRightReserve) or 0
    local healthLeftReserve = tonumber(options.healthLeftReserve) or 0
    local healthRightReserve = tonumber(options.healthRightReserve) or 0
    local powerLeftReserve = tonumber(options.powerLeftReserve) or 0
    local powerRightReserve = tonumber(options.powerRightReserve) or 0
    local isPlaceholder = Preview.IsPlaceholderPreviewEnabled and Preview.IsPlaceholderPreviewEnabled(frame)
    local isEnabledPlaceholder = isPlaceholder and IsPlaceholderUnitEnabled(frame)
    local placeholderColors = Demo.GetPlaceholderColors and Demo.GetPlaceholderColors() or {}

    if frame.Elements.HealthBar then
        local health = frame.Elements.HealthBar
        health:ClearAllPoints()
        health:SetStatusBarTexture(options.healthTexture)
        if health.SetReverseFill then
            health:SetReverseFill(healthBarReverseFill)
        end

        if health.bg then
            health.bg:SetTexture(options.healthTexture)
            if isPlaceholder then
                if isEnabledPlaceholder then
                    health.bg:SetVertexColor(placeholderColors.bgR or 0.08, placeholderColors.bgG or 0.10, placeholderColors.bgB or 0.13, placeholderColors.bgA or 0.30)
                else
                    health.bg:SetVertexColor(placeholderColors.bgR or 0.08, placeholderColors.bgG or 0.10, placeholderColors.bgB or 0.13, placeholderColors.disabledBgA or 0.10)
                end
            else
                health.bg:SetVertexColor(options.healthBgR, options.healthBgG, options.healthBgB, options.healthBgA)
            end
            health.bg:SetShown(options.healthBackgroundShown)
        end

        local healthLeftOffset = borderInset + frameLeftReserve + healthLeftReserve
        local healthRightOffset = -(borderInset + frameRightReserve + healthRightReserve)
        local healthBottomY = borderInset
        if showPowerBar then
            healthBottomY = healthBottomY + powerBarHeight
        end
        if alternativePowerBarVisible then
            healthBottomY = healthBottomY + alternativePowerBarHeight
        end

        health:SetPoint("TOPLEFT", frame, "TOPLEFT", healthLeftOffset, -borderInset)
        health:SetPoint("TOPRIGHT", frame, "TOPRIGHT", healthRightOffset, -borderInset)
        health:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", healthLeftOffset, healthBottomY)
        health:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", healthRightOffset, healthBottomY)

        health:Show()
        owner:UpdateHealthBarColor(frame)
    end

    if frame.Elements.PowerBar then
        local power = frame.Elements.PowerBar
        power:ClearAllPoints()
        power:SetStatusBarTexture(options.powerTexture)
        if power.SetReverseFill then
            power:SetReverseFill(powerBarReverseFill)
        end
        if isPlaceholder then
            if isEnabledPlaceholder then
                power:SetStatusBarColor(placeholderColors.barR or 0.24, placeholderColors.barG or 0.28, placeholderColors.barB or 0.34, 1)
                power:SetAlpha(placeholderColors.barA or 0.62)
            else
                power:SetStatusBarColor(placeholderColors.barR or 0.24, placeholderColors.barG or 0.28, placeholderColors.barB or 0.34, 1)
                power:SetAlpha(placeholderColors.disabledBarA or 0.18)
            end
        else
            power:SetStatusBarColor(options.powerR, options.powerG, options.powerB, 1)
            power:SetAlpha(options.powerA or 1)
        end

        if power.bg then
            power.bg:SetTexture(options.powerTexture)
            if isPlaceholder then
                if isEnabledPlaceholder then
                    power.bg:SetVertexColor(placeholderColors.bgR or 0.08, placeholderColors.bgG or 0.10, placeholderColors.bgB or 0.13, placeholderColors.bgA or 0.30)
                else
                    power.bg:SetVertexColor(placeholderColors.bgR or 0.08, placeholderColors.bgG or 0.10, placeholderColors.bgB or 0.13, placeholderColors.disabledBgA or 0.10)
                end
            else
                power.bg:SetVertexColor(options.powerBgR, options.powerBgG, options.powerBgB, options.powerBgA)
            end
            power.bg:SetShown(options.powerBackgroundShown and showPowerBar)
        end

        if showPowerBar then
            local powerLeftOffset = borderInset + frameLeftReserve + powerLeftReserve
            local powerRightOffset = -(borderInset + frameRightReserve + powerRightReserve)
            local powerBottomOffset = borderInset
            if alternativePowerBarVisible then
                powerBottomOffset = powerBottomOffset + alternativePowerBarHeight
            end

            power:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", powerLeftOffset, powerBottomOffset)
            power:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", powerRightOffset, powerBottomOffset)
            power:SetHeight(powerBarHeight)
            power:Show()
        else
            if power.bg then
                power.bg:Hide()
            end
            power:Hide()
        end
    end

    ApplyAbsorbBarLayout(frame)
end

function BarLayout.ApplyAlternativePower(frame, options)
    if not frame.Elements.AlternativePowerBar then
        return
    end

    local borderInset = options.borderInset
    local frameLeftReserve = tonumber(options.frameLeftReserve) or 0
    local frameRightReserve = tonumber(options.frameRightReserve) or 0
    local powerLeftReserve = tonumber(options.powerLeftReserve) or 0
    local powerRightReserve = tonumber(options.powerRightReserve) or 0
    local alternativePowerBarVisible = options.alternativePowerBarVisible
    local alternativePowerBarHeight = options.alternativePowerBarHeight

    local altPower = frame.Elements.AlternativePowerBar
    local isPlaceholder = Preview.IsPlaceholderPreviewEnabled and Preview.IsPlaceholderPreviewEnabled(frame)
    local isEnabledPlaceholder = isPlaceholder and IsPlaceholderUnitEnabled(frame)
    local placeholderColors = Demo.GetPlaceholderColors and Demo.GetPlaceholderColors() or {}
    local altPowerType = options.liveAltPowerType or (frame.LiveValues and frame.LiveValues.altPowerType) or 0
    local altPowerTypeColor = PowerBarColor and PowerBarColor[altPowerType]
    local altPowerR, altPowerG, altPowerB, altPowerA = options.powerR, options.powerG, options.powerB, options.powerA
    if options.altPowerHasCustomColor == true then
        altPowerR = options.altPowerR
        altPowerG = options.altPowerG
        altPowerB = options.altPowerB
        altPowerA = options.altPowerA
    elseif altPowerTypeColor then
        altPowerR = altPowerTypeColor.r or altPowerTypeColor[1] or altPowerR
        altPowerG = altPowerTypeColor.g or altPowerTypeColor[2] or altPowerG
        altPowerB = altPowerTypeColor.b or altPowerTypeColor[3] or altPowerB
    end

    altPower:ClearAllPoints()
    altPower:SetStatusBarTexture(options.altPowerTexture)
    if altPower.SetReverseFill then
        altPower:SetReverseFill(options.altPowerReverseFill == true)
    end
    if isPlaceholder then
        if isEnabledPlaceholder then
            altPower:SetStatusBarColor(placeholderColors.barR or 0.24, placeholderColors.barG or 0.28, placeholderColors.barB or 0.34, 1)
            altPower:SetAlpha(placeholderColors.barA or 0.62)
        else
            altPower:SetStatusBarColor(placeholderColors.barR or 0.24, placeholderColors.barG or 0.28, placeholderColors.barB or 0.34, 1)
            altPower:SetAlpha(placeholderColors.disabledBarA or 0.18)
        end
    else
        altPower:SetStatusBarColor(altPowerR, altPowerG, altPowerB, 1)
        altPower:SetAlpha(altPowerA or 1)
    end

    if altPower.bg then
        altPower.bg:SetTexture(options.altPowerTexture)
        if isPlaceholder then
            if isEnabledPlaceholder then
                altPower.bg:SetVertexColor(placeholderColors.bgR or 0.08, placeholderColors.bgG or 0.10, placeholderColors.bgB or 0.13, placeholderColors.bgA or 0.30)
            else
                altPower.bg:SetVertexColor(placeholderColors.bgR or 0.08, placeholderColors.bgG or 0.10, placeholderColors.bgB or 0.13, placeholderColors.disabledBgA or 0.10)
            end
        else
            altPower.bg:SetVertexColor(options.altPowerBgR, options.altPowerBgG, options.altPowerBgB, options.altPowerBgA)
        end
        altPower.bg:SetShown(alternativePowerBarVisible and options.altPowerBackgroundShown)
    end

    if alternativePowerBarVisible then
        local minAltPower = options.liveAltPowerMin or (frame.LiveValues and frame.LiveValues.altPowerMinRaw) or 0
        local currentAltPower = options.liveAltPowerCurrent or (frame.LiveValues and frame.LiveValues.altPowerCurrentRaw) or 0
        local maxAltPower = options.liveAltPowerMax or (frame.LiveValues and frame.LiveValues.altPowerMaxRaw) or 0
        local maxAltPowerEffective = maxAltPower

        if type(minAltPower) == "number"
            and type(maxAltPower) == "number"
            and not IsSecretValue(minAltPower)
            and not IsSecretValue(maxAltPower)
        then
            maxAltPowerEffective = math.max(maxAltPower, minAltPower + 1)
        end

        altPower:SetMinMaxValues(minAltPower, maxAltPowerEffective)
        altPower:SetValue(currentAltPower)

        local powerLeftOffset = borderInset + frameLeftReserve + powerLeftReserve
        local powerRightOffset = -(borderInset + frameRightReserve + powerRightReserve)
        local altPowerBottomOffset = borderInset

        altPower:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", powerLeftOffset, altPowerBottomOffset)
        altPower:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", powerRightOffset, altPowerBottomOffset)
        altPower:SetHeight(alternativePowerBarHeight)
        altPower:Show()
    else
        if altPower.bg then
            altPower.bg:Hide()
        end
        altPower:Hide()
    end
end
