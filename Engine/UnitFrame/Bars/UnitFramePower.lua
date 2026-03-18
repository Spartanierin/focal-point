local _, FocalPoint = ...

FocalPoint.UnitFramePower = FocalPoint.UnitFramePower or {}
local Power = FocalPoint.UnitFramePower

local Presence = FocalPoint.UnitFramePresence or {}
local Preview = FocalPoint.UnitFramePreview or {}
local Utils = FocalPoint.UnitFrameUtils or {}

local DoesUnitSeemPresent = Presence.DoesUnitSeemPresent
local IsPreviewModeEnabled = Presence.IsPreviewModeEnabled
local ToSafeNumberValue = Utils.ToSafeNumberValue
local FormatDisplayNumber = Utils.FormatDisplayNumber
local ResolveBlizzardAbbreviation = Utils.ResolveBlizzardAbbreviation
local GetSecondaryPowerTypeForUnit = Preview.GetSecondaryPowerTypeForUnit
local GetSecondaryPowerValues = Preview.GetSecondaryPowerValues

-- Power helpers keep resource/alt-power value refresh together.

function Power.RefreshUnitBarValues(owner, frame)
    if not frame or not frame.unit then
        return
    end

    local unit = frame.unit
    local unitExists = DoesUnitSeemPresent(unit)
    local previewValues = IsPreviewModeEnabled() and Preview.GetTestValues(frame) or nil
    frame.LiveValues = frame.LiveValues or {}
    frame.TestValues = previewValues
    local previousAltPowerVisible = frame.LiveValues.altPowerVisible

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

        frame.Elements.PowerBar:SetMinMaxValues(0, maxPower)
        frame.Elements.PowerBar:SetValue(currentPower)

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
        local currentAltPower = 0
        local maxAltPower = 0
        local showAltPower = false

        local secondaryPowerType = GetSecondaryPowerTypeForUnit(unit)

        if previewValues then
            currentAltPower = previewValues.altPowerCurrent or 0
            maxAltPower = previewValues.altPowerMax or 0
            showAltPower = secondaryPowerType ~= nil and maxAltPower > 0
        elseif secondaryPowerType ~= nil and unitExists then
            _, currentAltPower, maxAltPower = GetSecondaryPowerValues(unit)
            showAltPower = maxAltPower > 0
        end

        frame.Elements.AlternativePowerBar:SetMinMaxValues(0, math.max(maxAltPower, 1))
        frame.Elements.AlternativePowerBar:SetValue(currentAltPower)

        frame.LiveValues.altPowerCurrentRaw = currentAltPower
        frame.LiveValues.altPowerMaxRaw = maxAltPower
        frame.LiveValues.altPowerCurrentText = FormatDisplayNumber(currentAltPower)
        frame.LiveValues.altPowerMaxText = FormatDisplayNumber(maxAltPower)
        frame.LiveValues.altPowerVisible = showAltPower
        frame.LiveValues.altPowerType = secondaryPowerType
        frame.LiveValues.altPowerCurrentSafe = ToSafeNumberValue(currentAltPower)
        frame.LiveValues.altPowerMaxSafe = ToSafeNumberValue(maxAltPower)
        frame.LiveValues.altPowerCurrentAbbr = ResolveBlizzardAbbreviation(currentAltPower, frame.LiveValues.altPowerCurrentText)
        frame.LiveValues.altPowerMaxAbbr = ResolveBlizzardAbbreviation(maxAltPower, frame.LiveValues.altPowerMaxText)

        if previousAltPowerVisible ~= nil
            and previousAltPowerVisible ~= showAltPower
            and not frame.isApplyingAltPowerLayout
        then
            frame.isApplyingAltPowerLayout = true
            owner:ApplyConfig(frame)
            frame.isApplyingAltPowerLayout = false
        end
    end
end

function Power.RegisterAlternativeEvents(owner, frame)
    if not frame or frame.AlternativePowerEventFrame or frame.unit ~= "player" then
        return
    end

    local eventFrame = CreateFrame("Frame", nil, frame)
    eventFrame.owner = frame
    eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    eventFrame:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
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

        owner:RefreshUnitBarValues(currentOwner)
        owner:ApplyConfig(currentOwner)
        if owner.RefreshLiveValues then
            owner:RefreshLiveValues(currentOwner)
        end
        if owner.UpdateTextElements then
            owner:UpdateTextElements(currentOwner)
        end
    end)

    frame.AlternativePowerEventFrame = eventFrame
end
