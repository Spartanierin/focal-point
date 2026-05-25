local _, FocalPoint = ...

FocalPoint.UnitFrameHealth = FocalPoint.UnitFrameHealth or {}
local Health = FocalPoint.UnitFrameHealth

local Colors = FocalPoint.UnitFrameColors or {}
local Presence = FocalPoint.UnitFramePresence or {}
local Preview = FocalPoint.UnitFramePreview or {}
local State = FocalPoint.UnitFrameState or {}
local Utils = FocalPoint.UnitFrameUtils or {}

local DoesUnitSeemPresent = Presence.DoesUnitSeemPresent
local IsPreviewModeEnabled = Presence.IsPreviewModeEnabled
local GetResolvedHealthBarColor = Colors.GetResolvedHealthBarColor
local ToSafeNumberValue = Utils.ToSafeNumberValue
local FormatDisplayNumber = Utils.FormatDisplayNumber
local ResolveBlizzardAbbreviation = Utils.ResolveBlizzardAbbreviation

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

local function ResolveTotalAbsorb(unit, unitExists, previewValues)
    if previewValues then
        local previewAbsorb = previewValues.absorbTotal or previewValues.absorb or 0
        local absorbSafe = ToSafeNumberValue(previewAbsorb)
        if absorbSafe < 0 then
            absorbSafe = 0
        end
        return previewAbsorb, absorbSafe
    end

    if unitExists and UnitGetTotalAbsorbs then
        local totalAbsorb = UnitGetTotalAbsorbs(unit) or 0
        local absorbSafe = ToSafeNumberValue(totalAbsorb)
        if absorbSafe < 0 then
            absorbSafe = 0
        end
        return totalAbsorb, absorbSafe
    end

    return 0, 0
end

local function UpdateAbsorbOverlay(frame)
    if not frame or not frame.Elements or not frame.Elements.HealthBar then
        return
    end

    local health = frame.Elements.HealthBar
    local absorbOverlay = health.AbsorbOverlay
    if not absorbOverlay then
        return
    end

    local config = FocalPoint.UnitFrameUtils and FocalPoint.UnitFrameUtils.GetUnitDB and FocalPoint.UnitFrameUtils.GetUnitDB(frame.unit)
    if config and config.showAbsorbOverlay == false then
        absorbOverlay:Hide()
        return
    end

    local live = frame.LiveValues or {}
    local maxHealth = ToSafeNumberValue(live.healthMaxSafe or live.healthMaxRaw)
    local currentHealth = ToSafeNumberValue(live.healthCurrentSafe or live.healthCurrentRaw)
    local totalAbsorb = ToSafeNumberValue(live.absorbTotalSafe or live.absorbTotalRaw)

    if maxHealth <= 0 or totalAbsorb <= 0 then
        absorbOverlay:Hide()
        return
    end

    if currentHealth < 0 then
        currentHealth = 0
    elseif currentHealth > maxHealth then
        currentHealth = maxHealth
    end

    local missingHealth = maxHealth - currentHealth
    local effectiveAbsorb = totalAbsorb
    local showFullHealthMarker = false
    if missingHealth <= 0 then
        showFullHealthMarker = true
    else
        effectiveAbsorb = math.min(totalAbsorb, missingHealth)
        if effectiveAbsorb <= 0 then
            absorbOverlay:Hide()
            return
        end
    end

    local barWidth = tonumber(health.GetWidth and health:GetWidth() or 0) or 0
    if barWidth <= 0 then
        absorbOverlay:Hide()
        return
    end

    local healthFraction = math.max(0, math.min(1, currentHealth / maxHealth))
    local absorbFraction = math.max(0, math.min(1, effectiveAbsorb / maxHealth))
    local healthWidth = barWidth * healthFraction
    local absorbWidth = barWidth * absorbFraction

    if showFullHealthMarker then
        local markerMaxFraction = 0.35
        local markerWidth = math.max(2, barWidth * math.min(absorbFraction, markerMaxFraction))
        absorbWidth = math.min(markerWidth, barWidth)
    end

    if absorbWidth < 0.5 then
        absorbOverlay:Hide()
        return
    end

    local reverseFill = health.GetReverseFill and health:GetReverseFill() or false
    local leftOffset
    local rightOffset
    if reverseFill then
        if showFullHealthMarker then
            leftOffset = 0
            rightOffset = absorbWidth
        else
            local boundary = barWidth - healthWidth
            leftOffset = boundary - absorbWidth
            rightOffset = boundary
        end
    else
        if showFullHealthMarker then
            leftOffset = barWidth - absorbWidth
            rightOffset = barWidth
        else
            leftOffset = healthWidth
            rightOffset = healthWidth + absorbWidth
        end
    end

    if rightOffset < leftOffset then
        leftOffset, rightOffset = rightOffset, leftOffset
    end
    leftOffset = math.max(0, leftOffset)
    rightOffset = math.min(barWidth, rightOffset)
    local finalWidth = rightOffset - leftOffset
    if finalWidth < 0.5 then
        absorbOverlay:Hide()
        return
    end

    absorbOverlay:ClearAllPoints()
    absorbOverlay:SetPoint("TOPLEFT", health, "TOPLEFT", leftOffset, 0)
    absorbOverlay:SetPoint("BOTTOMLEFT", health, "BOTTOMLEFT", leftOffset, 0)
    absorbOverlay:SetWidth(finalWidth)
    absorbOverlay:Show()
end

-- Health helpers keep value formatting and health-bar updates together.

function Health.GetCurrentValues(frame)
    if not frame or not frame.unit then
        return 0, 1
    end

    local unit = frame.unit
    local unitExists = DoesUnitSeemPresent(unit)
    local previewValues = IsPreviewModeEnabled() and Preview.GetTestValues(frame) or nil

    if previewValues then
        return previewValues.healthCurrent or 100, previewValues.healthMax or 100
    end

    if unitExists and CreateUnitHealPredictionCalculator and UnitGetDetailedHealPrediction then
        frame.HealthPredictionValues = frame.HealthPredictionValues or CreateUnitHealPredictionCalculator()
        local values = frame.HealthPredictionValues
        if values then
            local updateOk = pcall(UnitGetDetailedHealPrediction, unit, "player", values)
            if updateOk and values.GetCurrentHealth and values.GetMaximumHealth then
                local currentOk, currentHealth = pcall(values.GetCurrentHealth, values)
                local maxOk, maxHealth = pcall(values.GetMaximumHealth, values)
                if currentOk and maxOk and type(currentHealth) == "number" and type(maxHealth) == "number" then
                    return currentHealth, maxHealth
                end
            end
        end
    end

    if unitExists and UnitHealth and UnitHealthMax then
        return UnitHealth(unit) or 0, UnitHealthMax(unit) or 1
    end

    return 0, 1
end

function Health.UpdateBarValue(frame)
    if not frame or not frame.Elements or not frame.Elements.HealthBar then
        return
    end

    frame.LiveValues = frame.LiveValues or {}

    local currentHealth, maxHealth = Health.GetCurrentValues(frame)
    frame.Elements.HealthBar:SetMinMaxValues(0, maxHealth)
    frame.Elements.HealthBar:SetValue(currentHealth)
    local unitExists = DoesUnitSeemPresent(frame.unit)
    local previewValues = IsPreviewModeEnabled() and Preview.GetTestValues(frame) or nil
    local absorbTotalRaw, absorbTotalSafe = ResolveTotalAbsorb(frame.unit, unitExists, previewValues)

    frame.LiveValues.healthCurrentRaw = currentHealth
    frame.LiveValues.healthMaxRaw = maxHealth
    frame.LiveValues.healthCurrentSafe = ToSafeNumberValue(currentHealth)
    frame.LiveValues.healthMaxSafe = ToSafeNumberValue(maxHealth)
    frame.LiveValues.healthBarCurrentSafe = ToSafeNumberValue(frame.Elements.HealthBar:GetValue())
    do
        local _, displayedMax = frame.Elements.HealthBar:GetMinMaxValues()
        frame.LiveValues.healthBarMaxSafe = ToSafeNumberValue(displayedMax)
    end
    if frame.LiveValues.healthBarCurrentSafe <= 0 and frame.LiveValues.healthCurrentSafe > 0 then
        frame.LiveValues.healthBarCurrentSafe = frame.LiveValues.healthCurrentSafe
    end
    if frame.LiveValues.healthBarMaxSafe <= 0 and frame.LiveValues.healthMaxSafe > 0 then
        frame.LiveValues.healthBarMaxSafe = frame.LiveValues.healthMaxSafe
    end
    frame.LiveValues.healthCurrentText = FormatDisplayNumber(currentHealth)
    frame.LiveValues.healthMaxText = FormatDisplayNumber(maxHealth)
    frame.LiveValues.healthCurrentAbbr = ResolveBlizzardAbbreviation(currentHealth, frame.LiveValues.healthCurrentText)
    frame.LiveValues.healthMaxAbbr = ResolveBlizzardAbbreviation(maxHealth, frame.LiveValues.healthMaxText)
    frame.LiveValues.absorbTotalRaw = absorbTotalRaw
    frame.LiveValues.absorbTotalSafe = absorbTotalSafe
    frame.LiveValues.absorbTotalText = FormatDisplayNumber(absorbTotalRaw)
    frame.LiveValues.absorbTotalAbbr = ResolveBlizzardAbbreviation(absorbTotalRaw, frame.LiveValues.absorbTotalText)

    UpdateAbsorbOverlay(frame)
end

function Health.UpdateBarColor(frame)
    if not frame or not frame.Elements or not frame.Elements.HealthBar then
        return
    end

    if Preview.IsPlaceholderPreviewEnabled and Preview.IsPlaceholderPreviewEnabled(frame) then
        local isEnabled = IsPlaceholderUnitEnabled(frame)
        if isEnabled then
            frame.Elements.HealthBar:SetStatusBarColor(0.34, 0.40, 0.48, 0.92)
            frame.Elements.HealthBar:SetAlpha(0.78)
        else
            frame.Elements.HealthBar:SetStatusBarColor(0.34, 0.40, 0.48, 0.28)
            frame.Elements.HealthBar:SetAlpha(0.22)
        end
        return
    end

    local config = FocalPoint.UnitFrameUtils and FocalPoint.UnitFrameUtils.GetUnitDB and FocalPoint.UnitFrameUtils.GetUnitDB(frame.unit)
    if not config then
        return
    end

    local healthR, healthG, healthB, healthA = GetResolvedHealthBarColor(
        frame,
        config,
        frame.LiveValues and frame.LiveValues.healthCurrentRaw,
        frame.LiveValues and frame.LiveValues.healthMaxRaw
    )
    frame.Elements.HealthBar:SetStatusBarColor(healthR, healthG, healthB, 1)
    frame.Elements.HealthBar:SetAlpha(healthA or 1)
    UpdateAbsorbOverlay(frame)
end

function Health.RefreshBar(owner, frame)
    if not frame or not frame.Elements or not frame.Elements.HealthBar then
        return
    end

    Health.UpdateBarValue(frame)
    Health.UpdateBarColor(frame)
end

function Health.RefreshText(owner, frame)
    if not frame then
        return
    end

    if owner.RefreshLiveValues then
        owner:RefreshLiveValues(frame)
    end

    if owner.UpdateTextElement then
        owner:UpdateTextElement(frame, "Health")
    end
end

function Health.Refresh(owner, frame)
    if not frame then
        return
    end

    Health.RefreshBar(owner, frame)
    Health.RefreshText(owner, frame)
end

function Health.RegisterEvents(owner, frame)
    if not frame or frame.HealthBarEventFrame or not frame.Elements or not frame.Elements.HealthBar then
        return
    end

    local eventFrame = CreateFrame("Frame", nil, frame)
    eventFrame.owner = frame
    eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    if frame.unit and eventFrame.RegisterUnitEvent then
        eventFrame:RegisterUnitEvent("UNIT_HEALTH", frame.unit)
        eventFrame:RegisterUnitEvent("UNIT_MAXHEALTH", frame.unit)
        eventFrame:RegisterUnitEvent("UNIT_ABSORB_AMOUNT_CHANGED", frame.unit)
        eventFrame:RegisterUnitEvent("UNIT_HEAL_ABSORB_AMOUNT_CHANGED", frame.unit)
    else
        eventFrame:RegisterEvent("UNIT_HEALTH")
        eventFrame:RegisterEvent("UNIT_MAXHEALTH")
        eventFrame:RegisterEvent("UNIT_ABSORB_AMOUNT_CHANGED")
        eventFrame:RegisterEvent("UNIT_HEAL_ABSORB_AMOUNT_CHANGED")
    end

    if frame.unit == "target" then
        eventFrame:RegisterEvent("PLAYER_TARGET_CHANGED")
    elseif frame.unit == "targettarget" then
        eventFrame:RegisterEvent("PLAYER_TARGET_CHANGED")
        eventFrame:RegisterEvent("UNIT_TARGET")
    elseif frame.unit == "focustarget" then
        eventFrame:RegisterEvent("PLAYER_FOCUS_CHANGED")
        eventFrame:RegisterEvent("UNIT_TARGET")
    elseif frame.unit == "focus" then
        eventFrame:RegisterEvent("PLAYER_FOCUS_CHANGED")
    elseif frame.unit == "pet" then
        eventFrame:RegisterEvent("UNIT_PET")
    end

    eventFrame:SetScript("OnEvent", function(_, event, unit)
        local currentOwner = eventFrame.owner
        if not currentOwner then
            return
        end

        local function Queue(scope)
            if State.QueueRefresh then
                State.QueueRefresh(currentOwner, event, scope)
            else
                owner:Refresh(currentOwner)
            end
        end

        if event == "PLAYER_TARGET_CHANGED" or event == "PLAYER_FOCUS_CHANGED" then
            Queue({ "bars", "texts", "layout" })
            return
        end

        if event == "UNIT_TARGET" then
            if currentOwner.unit ~= "targettarget" or unit ~= "target" then
                if currentOwner.unit ~= "focustarget" or unit ~= "focus" then
                    return
                end
            end
            Queue({ "bars", "texts", "layout" })
            return
        end

        if event == "UNIT_PET" then
            if currentOwner.unit ~= "pet" or unit ~= "player" then
                return
            end
            Queue({ "bars", "texts", "layout" })
            return
        elseif event == "PLAYER_ENTERING_WORLD" and currentOwner.unit ~= "player" then
            Queue({ "bars", "texts", "layout" })
            return
        elseif unit and unit ~= currentOwner.unit then
            return
        end

        Queue({ "bars", "texts" })
    end)

    frame.HealthBarEventFrame = eventFrame
end
