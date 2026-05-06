local _, FocalPoint = ...

FocalPoint.UnitFramePower = FocalPoint.UnitFramePower or {}
local Power = FocalPoint.UnitFramePower

local Presence = FocalPoint.UnitFramePresence or {}
local Preview = FocalPoint.UnitFramePreview or {}
local State = FocalPoint.UnitFrameState or {}
local Utils = FocalPoint.UnitFrameUtils or {}

local DoesUnitSeemPresent = Presence.DoesUnitSeemPresent
local IsPreviewModeEnabled = Presence.IsPreviewModeEnabled
local ToSafeNumberValue = Utils.ToSafeNumberValue
local FormatDisplayNumber = Utils.FormatDisplayNumber
local ResolveBlizzardAbbreviation = Utils.ResolveBlizzardAbbreviation
local GetSecondaryPowerTypeForUnit = Preview.GetSecondaryPowerTypeForUnit
local GetSecondaryPowerValues = Preview.GetSecondaryPowerValues
local GetSecondaryPowerDisplayValues = Preview.GetSecondaryPowerDisplayValues

-- Power helpers keep resource/alt-power value refresh together.

local function IsSecretValue(value)
    return issecretvalue and issecretvalue(value) or false
end

local function ResolveBarNumber(rawValue)
    if type(rawValue) == "number" then
        return rawValue, IsSecretValue(rawValue)
    end

    return ToSafeNumberValue(rawValue), false
end

function Power.RefreshUnitBarValues(owner, frame)
    if not frame or not frame.unit then
        return
    end

    local unit = frame.unit
    local unitExists = DoesUnitSeemPresent(unit)
    local previewValues = IsPreviewModeEnabled() and Preview.GetTestValues(frame) or nil
    frame.LiveValues = frame.LiveValues or {}
    frame.TestValues = previewValues

    if frame.Elements.HealthBar and owner and owner.RefreshHealthBar then
        owner:RefreshHealthBar(frame)
    end

    if frame.Elements.PowerBar then
        local currentPower = 0
        local maxPower = 1

        if previewValues then
            currentPower = previewValues.powerCurrent or 65
            maxPower = previewValues.powerMax or 100
        elseif unitExists and UnitPower and UnitPowerMax then
            currentPower = UnitPower(unit) or 0
            maxPower = UnitPowerMax(unit) or 1
        end

        local currentPowerBarValue, currentPowerIsSecret = ResolveBarNumber(currentPower)
        local maxPowerBarValue, maxPowerIsSecret = ResolveBarNumber(maxPower)

        if type(maxPowerBarValue) ~= "number" then
            maxPowerBarValue = 1
            maxPowerIsSecret = false
        end

        if not maxPowerIsSecret and maxPowerBarValue < 1 then
            maxPowerBarValue = 1
        end

        if type(currentPowerBarValue) ~= "number" then
            currentPowerBarValue = 0
            currentPowerIsSecret = false
        end

        if not currentPowerIsSecret and not maxPowerIsSecret then
            if currentPowerBarValue < 0 then
                currentPowerBarValue = 0
            elseif currentPowerBarValue > maxPowerBarValue then
                currentPowerBarValue = maxPowerBarValue
            end
        end

        frame.Elements.PowerBar:SetMinMaxValues(0, maxPowerBarValue)
        frame.Elements.PowerBar:SetValue(currentPowerBarValue)

        frame.LiveValues.powerCurrentRaw = currentPower
        frame.LiveValues.powerMaxRaw = maxPower
        frame.LiveValues.powerCurrentText = FormatDisplayNumber(currentPower)
        frame.LiveValues.powerMaxText = FormatDisplayNumber(maxPower)
        frame.LiveValues.powerCurrentSafe = ToSafeNumberValue(currentPower)
        frame.LiveValues.powerMaxSafe = ToSafeNumberValue(maxPower)
        frame.LiveValues.powerCurrentAbbr = ResolveBlizzardAbbreviation(currentPower, frame.LiveValues.powerCurrentText)
        frame.LiveValues.powerMaxAbbr = ResolveBlizzardAbbreviation(maxPower, frame.LiveValues.powerMaxText)
    end

    if frame.Elements.AlternativePowerBar then
        local minAltPower = 0
        local currentAltPower = 0
        local maxAltPower = 0
        local showAltPower = false

        local secondaryPowerType = GetSecondaryPowerTypeForUnit(unit)

        if previewValues then
            minAltPower = previewValues.altPowerMin or 0
            currentAltPower = previewValues.altPowerCurrent or 0
            maxAltPower = previewValues.altPowerMax or 0
            showAltPower = secondaryPowerType ~= nil
        elseif secondaryPowerType ~= nil and unitExists then
            _, currentAltPower, maxAltPower, minAltPower = GetSecondaryPowerValues(unit)
            showAltPower = true
        end

        local minAltPowerBarValue, minAltPowerIsSecret = ResolveBarNumber(minAltPower)
        local currentAltPowerBarValue, currentAltPowerIsSecret = ResolveBarNumber(currentAltPower)
        local maxAltPowerBarValue, maxAltPowerIsSecret = ResolveBarNumber(maxAltPower)
        local maxAltPowerEffective = maxAltPowerBarValue

        if not minAltPowerIsSecret and not maxAltPowerIsSecret then
            maxAltPowerEffective = math.max(maxAltPowerBarValue, minAltPowerBarValue + 1)
        end

        if not currentAltPowerIsSecret and not minAltPowerIsSecret then
            if currentAltPowerBarValue < minAltPowerBarValue then
                currentAltPowerBarValue = minAltPowerBarValue
            end
        end

        if not currentAltPowerIsSecret and not maxAltPowerIsSecret then
            if currentAltPowerBarValue > maxAltPowerEffective then
                currentAltPowerBarValue = maxAltPowerEffective
            end
        end

        frame.Elements.AlternativePowerBar:SetMinMaxValues(minAltPowerBarValue, maxAltPowerEffective)
        frame.Elements.AlternativePowerBar:SetValue(currentAltPowerBarValue)

        local _, altCurrentText, altMaxText, _, altCurrentSafe, altMaxSafe = GetSecondaryPowerDisplayValues and GetSecondaryPowerDisplayValues(unit) or nil
        if type(altCurrentText) ~= "string" then
            altCurrentText = FormatDisplayNumber(currentAltPower)
        end
        if type(altMaxText) ~= "string" then
            altMaxText = FormatDisplayNumber(maxAltPower)
        end
        if type(altCurrentSafe) ~= "number" then
            altCurrentSafe = ToSafeNumberValue(currentAltPower)
        end
        if type(altMaxSafe) ~= "number" then
            altMaxSafe = ToSafeNumberValue(maxAltPower)
        end

        frame.LiveValues.altPowerMinRaw = minAltPower
        frame.LiveValues.altPowerCurrentRaw = currentAltPower
        frame.LiveValues.altPowerMaxRaw = maxAltPower
        frame.LiveValues.altPowerCurrentText = altCurrentText
        frame.LiveValues.altPowerMaxText = altMaxText
        frame.LiveValues.altPowerVisible = showAltPower
        frame.LiveValues.altPowerType = secondaryPowerType
        frame.LiveValues.altPowerCurrentSafe = altCurrentSafe
        frame.LiveValues.altPowerMaxSafe = altMaxSafe
        frame.LiveValues.altPowerCurrentAbbr = ResolveBlizzardAbbreviation(currentAltPower, frame.LiveValues.altPowerCurrentText)
        frame.LiveValues.altPowerMaxAbbr = ResolveBlizzardAbbreviation(maxAltPower, frame.LiveValues.altPowerMaxText)
    end
end

function Power.RegisterAlternativeEvents(owner, frame)
    if not frame or frame.AlternativePowerEventFrame or frame.unit ~= "player" then
        return
    end

    local eventFrame = CreateFrame("Frame", nil, frame)
    eventFrame.owner = frame
    eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    eventFrame:RegisterEvent("UNIT_POWER_BAR_SHOW")
    eventFrame:RegisterEvent("UNIT_POWER_BAR_HIDE")
    eventFrame:RegisterUnitEvent("UNIT_POWER_UPDATE", "player")
    eventFrame:RegisterUnitEvent("UNIT_MAXPOWER", "player")
    eventFrame:RegisterUnitEvent("UNIT_DISPLAYPOWER", "player")

    eventFrame:SetScript("OnEvent", function(_, event, unit)
        local currentOwner = eventFrame.owner
        if not currentOwner then
            return
        end

        if unit and unit ~= currentOwner.unit then
            return
        end

        if State.QueueRefresh then
            State.QueueRefresh(currentOwner, event, { "bars", "texts", "layout" })
        else
            owner:RefreshUnitBarValues(currentOwner)
            owner:ApplyConfig(currentOwner)
            if owner.RefreshLiveValues then
                owner:RefreshLiveValues(currentOwner)
            end
            if owner.UpdateTextElements then
                owner:UpdateTextElements(currentOwner)
            end
        end
    end)

    frame.AlternativePowerEventFrame = eventFrame
end
