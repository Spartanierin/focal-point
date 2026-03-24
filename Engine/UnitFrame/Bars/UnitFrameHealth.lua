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
end

function Health.UpdateBarColor(frame)
    if not frame or not frame.Elements or not frame.Elements.HealthBar then
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
    else
        eventFrame:RegisterEvent("UNIT_HEALTH")
        eventFrame:RegisterEvent("UNIT_MAXHEALTH")
    end

    if frame.unit == "target" then
        eventFrame:RegisterEvent("PLAYER_TARGET_CHANGED")
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
