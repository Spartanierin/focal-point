local _, FocalPoint = ...

FocalPoint.UnitFrameHealth = FocalPoint.UnitFrameHealth or {}
local Health = FocalPoint.UnitFrameHealth

local Colors = FocalPoint.UnitFrameColors or {}
local Presence = FocalPoint.UnitFramePresence or {}
local Preview = FocalPoint.UnitFramePreview or {}
local State = FocalPoint.UnitFrameState or {}
local Utils = FocalPoint.UnitFrameUtils or {}
local Demo = FocalPoint.UnitFrameDemoEnvironment or {}

local DoesUnitSeemPresent = Presence.DoesUnitSeemPresent
local IsPreviewModeEnabled = Presence.IsPreviewModeEnabled
local GetResolvedHealthBarColor = Colors.GetResolvedHealthBarColor
local ToSafeNumberValue = Utils.ToSafeNumberValue
local UnpackColor = Utils.UnpackColor
local FormatDisplayNumber = Utils.FormatDisplayNumber
local ResolveBlizzardAbbreviation = Utils.ResolveBlizzardAbbreviation

local DEFAULT_ABSORB_OVERLAY_COLOR = { 0.66, 0.86, 1.0, 1 }
local DEFAULT_ABSORB_OVERLAY_OPACITY = 0.62

local function IsSecretValue(value)
    return issecretvalue and issecretvalue(value) or false
end

local function ResolveAbsorbSafeNumber(rawValue)
    if rawValue == nil then
        return 0
    end
    return ToSafeNumberValue(rawValue)
end

local function ResolveAbsorbOverlayStyle(config)
    local r, g, b = UnpackColor(config and config.absorbOverlayColor, DEFAULT_ABSORB_OVERLAY_COLOR)
    local opacity = config and config.absorbOverlayOpacity
    if IsSecretValue(opacity) then
        opacity = nil
    end

    opacity = tonumber(opacity)
    if opacity == nil then
        opacity = DEFAULT_ABSORB_OVERLAY_OPACITY
    elseif opacity < 0 then
        opacity = 0
    elseif opacity > 1 then
        opacity = 1
    end

    return r, g, b, opacity
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

local function ResolveTotalAbsorb(frame, unit, unitExists, previewValues)
    if previewValues then
        local previewAbsorb = previewValues.absorbTotal or previewValues.absorb or 0
        local absorbSafe = ResolveAbsorbSafeNumber(previewAbsorb)
        if absorbSafe < 0 then
            absorbSafe = 0
        end
        return previewAbsorb, absorbSafe
    end

    local hpDamageAbsorbRaw = nil
    local hpDamageAbsorbSafe = 0
    local hpDamageAbsorbSecret = nil
    if unitExists and CreateUnitHealPredictionCalculator and UnitGetDetailedHealPrediction then
        frame.HealthPredictionValues = frame.HealthPredictionValues or CreateUnitHealPredictionCalculator()
        local values = frame.HealthPredictionValues
        if values then
            local updateOk = pcall(UnitGetDetailedHealPrediction, unit, "player", values)
            if updateOk and values.GetDamageAbsorbs then
                local absorbOk, damageAbsorbAmount = pcall(values.GetDamageAbsorbs, values)
                if absorbOk then
                    hpDamageAbsorbRaw = damageAbsorbAmount
                    hpDamageAbsorbSecret = IsSecretValue(damageAbsorbAmount)
                    hpDamageAbsorbSafe = ResolveAbsorbSafeNumber(damageAbsorbAmount)
                    if hpDamageAbsorbSafe < 0 then
                        hpDamageAbsorbSafe = 0
                    end
                end
            end
        end
    end

    local totalAbsorb = nil
    local absorbSafe = 0
    local totalAbsorbSecret = nil
    if unitExists and UnitGetTotalAbsorbs then
        local rawOk, rawTotalAbsorb = pcall(UnitGetTotalAbsorbs, unit)
        if not rawOk then
            rawTotalAbsorb = 0
        end
        totalAbsorb = rawTotalAbsorb or 0
        absorbSafe = ResolveAbsorbSafeNumber(totalAbsorb)
        if absorbSafe < 0 then
            absorbSafe = 0
        end
        totalAbsorbSecret = IsSecretValue(totalAbsorb)
        local healAbsorbRaw = nil
        if UnitGetTotalHealAbsorbs then
            local healOk, healValue = pcall(UnitGetTotalHealAbsorbs, unit)
            if healOk then
                healAbsorbRaw = healValue
            end
        end
    end

    if hpDamageAbsorbSafe > 0 then
        return hpDamageAbsorbRaw or hpDamageAbsorbSafe, hpDamageAbsorbSafe
    end
    if totalAbsorb ~= nil then
        return totalAbsorb, absorbSafe
    end
    if hpDamageAbsorbRaw ~= nil then
        return hpDamageAbsorbRaw, hpDamageAbsorbSafe
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

    if Preview.ShouldShowComponent and Preview.ShouldShowComponent("absorbs", { frame = frame }) == false then
        absorbOverlay:Hide()
        if health.AbsorbMinMarker then
            health.AbsorbMinMarker:Hide()
        end
        return
    end

    if Preview.IsPlaceholderPreviewEnabled and Preview.IsPlaceholderPreviewEnabled(frame) then
        absorbOverlay:Hide()
        if health.AbsorbMinMarker then
            health.AbsorbMinMarker:Hide()
        end
        return
    end

    local config = FocalPoint.UnitFrameUtils and FocalPoint.UnitFrameUtils.GetUnitDB and FocalPoint.UnitFrameUtils.GetUnitDB(frame.unit)
    if config and config.showAbsorbOverlay == false then
        absorbOverlay:Hide()
        if health.AbsorbMinMarker then
            health.AbsorbMinMarker:Hide()
        end
        return
    end

    local live = frame.LiveValues or {}
    local _, displayedMax = health:GetMinMaxValues()
    local maxHealthRaw = displayedMax or live.healthMaxRaw
    local maxHealthSafe = ToSafeNumberValue(live.healthMaxSafe or maxHealthRaw)
    local totalAbsorbRaw = live.absorbTotalRaw
    local totalAbsorbSafe = live.absorbTotalSafe

    if maxHealthRaw == nil then
        absorbOverlay:Hide()
        if health.AbsorbMinMarker then
            health.AbsorbMinMarker:Hide()
        end
        return
    end
    if not IsSecretValue(maxHealthRaw) and type(maxHealthRaw) == "number" and maxHealthRaw <= 0 then
        absorbOverlay:Hide()
        if health.AbsorbMinMarker then
            health.AbsorbMinMarker:Hide()
        end
        return
    end

    local healthTexture = health.GetStatusBarTexture and health:GetStatusBarTexture() or nil
    if not healthTexture then
        absorbOverlay:Hide()
        if health.AbsorbMinMarker then
            health.AbsorbMinMarker:Hide()
        end
        return
    end

    local reverseFill = health.GetReverseFill and health:GetReverseFill() or false
    absorbOverlay:ClearAllPoints()
    absorbOverlay:SetPoint("TOP", health, "TOP", 0, 0)
    absorbOverlay:SetPoint("BOTTOM", health, "BOTTOM", 0, 0)
    absorbOverlay:SetWidth(health:GetWidth())
    if reverseFill then
        absorbOverlay:SetPoint("RIGHT", healthTexture, "LEFT", 0, 0)
        absorbOverlay:SetReverseFill(true)
    else
        absorbOverlay:SetPoint("LEFT", healthTexture, "RIGHT", 0, 0)
        absorbOverlay:SetReverseFill(false)
    end

    if type(maxHealthRaw) == "number" then
        absorbOverlay:SetMinMaxValues(0, maxHealthRaw)
    else
        absorbOverlay:SetMinMaxValues(0, maxHealthSafe)
    end
    absorbOverlay:SetStatusBarColor(ResolveAbsorbOverlayStyle(config))
    absorbOverlay:SetValue(totalAbsorbRaw or totalAbsorbSafe or 0)
    absorbOverlay:Show()

    local marker = health.AbsorbMinMarker
    if marker then
        marker:Hide()
        local overlayValue = totalAbsorbSafe or ToSafeNumberValue(totalAbsorbRaw)
        if overlayValue and overlayValue > 0 then
            local overlayTexture = absorbOverlay.GetStatusBarTexture and absorbOverlay:GetStatusBarTexture() or nil
            local overlayWidth = overlayTexture and overlayTexture.GetWidth and overlayTexture:GetWidth() or 0
            local overlayWidthSafe = ToSafeNumberValue(overlayWidth)
            if overlayWidthSafe > 0 and overlayWidthSafe < 2 then
                marker:ClearAllPoints()
                if reverseFill then
                    marker:SetPoint("RIGHT", healthTexture, "LEFT", 0, 0)
                else
                    marker:SetPoint("LEFT", healthTexture, "RIGHT", 0, 0)
                end
                marker:Show()
            end
        end
    end
end

-- Health helpers keep value formatting and health-bar updates together.

function Health.GetCurrentValues(frame)
    if not frame or not frame.unit then
        return 0, 1
    end

    local unit = frame.unit
    local unitExists = DoesUnitSeemPresent(unit)
    local previewValues = (Demo.GetUnitValues and Demo.GetUnitValues(frame)) or (IsPreviewModeEnabled() and Preview.GetTestValues(frame) or nil)

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
    if Demo.IsFrameInDemoMode and Demo.IsFrameInDemoMode(frame) and not (Demo.IsBarSmoothingDisabled and Demo.IsBarSmoothingDisabled()) and Demo.TouchDebug then
        Demo.TouchDebug(frame, "barSmoothingTicks")
    end
    local unitExists = DoesUnitSeemPresent(frame.unit)
    local previewValues = (Demo.GetUnitValues and Demo.GetUnitValues(frame)) or (IsPreviewModeEnabled() and Preview.GetTestValues(frame) or nil)
    local absorbTotalRaw, absorbTotalSafe = ResolveTotalAbsorb(frame, frame.unit, unitExists, previewValues)
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

    local config = FocalPoint.UnitFrameUtils and FocalPoint.UnitFrameUtils.GetUnitDB and FocalPoint.UnitFrameUtils.GetUnitDB(frame.unit)

    if Preview.IsPlaceholderPreviewEnabled and Preview.IsPlaceholderPreviewEnabled(frame) then
        local colors = Demo.GetPlaceholderColors and Demo.GetPlaceholderColors() or {}
        local isEnabled = IsPlaceholderUnitEnabled(frame)
        if isEnabled then
            frame.Elements.HealthBar:SetStatusBarColor(colors.barR or 0.24, colors.barG or 0.28, colors.barB or 0.34, 1)
            frame.Elements.HealthBar:SetAlpha(colors.barA or 0.62)
        else
            frame.Elements.HealthBar:SetStatusBarColor(colors.barR or 0.24, colors.barG or 0.28, colors.barB or 0.34, 1)
            frame.Elements.HealthBar:SetAlpha(colors.disabledBarA or 0.18)
        end
        return
    end

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
