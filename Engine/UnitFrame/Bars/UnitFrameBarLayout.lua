local _, FocalPoint = ...

FocalPoint.UnitFrameBarLayout = FocalPoint.UnitFrameBarLayout or {}
local BarLayout = FocalPoint.UnitFrameBarLayout

-- Health and power bar layout stays separate from live value refresh so the
-- main runtime can focus on orchestration.

function BarLayout.ApplyHealthAndPower(owner, frame, options)
    local borderInset = options.borderInset
    local portraitInside = options.portraitInside
    local portraitInsideSide = options.portraitInsideSide
    local portraitReservedSpace = options.portraitReservedSpace
    local alternativePowerBarVisible = options.alternativePowerBarVisible
    local alternativePowerBarHeight = options.alternativePowerBarHeight
    local showPowerBar = options.showPowerBar
    local powerBarHeight = options.powerBarHeight
    local healthBarReverseFill = options.healthBarReverseFill == true
    local powerBarReverseFill = options.powerBarReverseFill == true

    if frame.Elements.HealthBar then
        local health = frame.Elements.HealthBar
        health:ClearAllPoints()
        health:SetStatusBarTexture(options.healthTexture)
        if health.SetReverseFill then
            health:SetReverseFill(healthBarReverseFill)
        end

        if health.bg then
            health.bg:SetTexture(options.healthTexture)
            health.bg:SetVertexColor(options.healthBgR, options.healthBgG, options.healthBgB, options.healthBgA)
            health.bg:SetShown(options.healthBackgroundShown)
        end

        local healthLeftOffset = borderInset
        local healthRightOffset = -borderInset
        local healthBottomY = borderInset
        if alternativePowerBarVisible then
            healthBottomY = healthBottomY + alternativePowerBarHeight
        end
        if showPowerBar then
            healthBottomY = healthBottomY + powerBarHeight
        end

        if portraitInside then
            if portraitInsideSide == "LEFT" then
                healthLeftOffset = borderInset + portraitReservedSpace
            elseif portraitInsideSide == "RIGHT" then
                healthRightOffset = -(borderInset + portraitReservedSpace)
            end
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
        power:SetStatusBarColor(options.powerR, options.powerG, options.powerB, 1)
        power:SetAlpha(options.powerA or 1)

        if power.bg then
            power.bg:SetTexture(options.powerTexture)
            power.bg:SetVertexColor(options.powerBgR, options.powerBgG, options.powerBgB, options.powerBgA)
            power.bg:SetShown(options.powerBackgroundShown and showPowerBar)
        end

        if showPowerBar then
            local powerLeftOffset = borderInset
            local powerRightOffset = -borderInset
            local powerBottomOffset = borderInset + (alternativePowerBarVisible and alternativePowerBarHeight or 0)

            if portraitInside then
                if portraitInsideSide == "LEFT" then
                    powerLeftOffset = borderInset + portraitReservedSpace
                elseif portraitInsideSide == "RIGHT" then
                    powerRightOffset = -(borderInset + portraitReservedSpace)
                end
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
end

function BarLayout.ApplyAlternativePower(frame, options)
    if not frame.Elements.AlternativePowerBar then
        return
    end

    local borderInset = options.borderInset
    local portraitInside = options.portraitInside
    local portraitInsideSide = options.portraitInsideSide
    local portraitReservedSpace = options.portraitReservedSpace
    local alternativePowerBarVisible = options.alternativePowerBarVisible
    local alternativePowerBarHeight = options.alternativePowerBarHeight

    local altPower = frame.Elements.AlternativePowerBar
    local altPowerType = options.liveAltPowerType or (frame.LiveValues and frame.LiveValues.altPowerType) or 0
    local altPowerTypeColor = PowerBarColor and PowerBarColor[altPowerType]
    local altPowerR, altPowerG, altPowerB, altPowerA = options.powerR, options.powerG, options.powerB, options.powerA
    if altPowerTypeColor then
        altPowerR = altPowerTypeColor.r or altPowerTypeColor[1] or altPowerR
        altPowerG = altPowerTypeColor.g or altPowerTypeColor[2] or altPowerG
        altPowerB = altPowerTypeColor.b or altPowerTypeColor[3] or altPowerB
    end

    altPower:ClearAllPoints()
    altPower:SetStatusBarTexture(options.altPowerTexture)
    altPower:SetStatusBarColor(altPowerR, altPowerG, altPowerB, 1)
    altPower:SetAlpha(altPowerA or 1)

    if altPower.bg then
        altPower.bg:SetTexture(options.altPowerTexture)
        altPower.bg:SetVertexColor(options.powerBgR, options.powerBgG, options.powerBgB, options.powerBgA)
        altPower.bg:SetShown(alternativePowerBarVisible and options.powerBackgroundShown)
    end

    if alternativePowerBarVisible then
        local currentAltPower = options.liveAltPowerCurrent or (frame.LiveValues and frame.LiveValues.altPowerCurrentRaw) or 0
        local maxAltPower = options.liveAltPowerMax or (frame.LiveValues and frame.LiveValues.altPowerMaxRaw) or 0

        altPower:SetMinMaxValues(0, math.max(maxAltPower, 1))
        altPower:SetValue(currentAltPower)

        local altPowerLeftOffset = borderInset
        local altPowerRightOffset = -borderInset

        if portraitInside then
            if portraitInsideSide == "LEFT" then
                altPowerLeftOffset = borderInset + portraitReservedSpace
            elseif portraitInsideSide == "RIGHT" then
                altPowerRightOffset = -(borderInset + portraitReservedSpace)
            end
        end

        altPower:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", altPowerLeftOffset, borderInset)
        altPower:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", altPowerRightOffset, borderInset)
        altPower:SetHeight(alternativePowerBarHeight)
        altPower:Show()
    else
        if altPower.bg then
            altPower.bg:Hide()
        end
        altPower:Hide()
    end
end
