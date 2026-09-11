local _, FocalPoint = ...

FocalPoint.UnitFramePower = FocalPoint.UnitFramePower or {}
local Power = FocalPoint.UnitFramePower

local Presence = FocalPoint.UnitFramePresence or {}
local Preview = FocalPoint.UnitFramePreview or {}
local State = FocalPoint.UnitFrameState or {}
local Utils = FocalPoint.UnitFrameUtils or {}
local Demo = FocalPoint.UnitFrameDemoEnvironment or {}
local VisualPolicy = FocalPoint.EditorVisualPolicy or {}
local RuntimeActivity = FocalPoint.UnitFrameRuntimeActivity or {}

local DoesUnitSeemPresent = Presence.DoesUnitSeemPresent
local IsPreviewModeEnabled = Presence.IsPreviewModeEnabled
local ToSafeNumberValue = Utils.ToSafeNumberValue
local FormatDisplayNumber = Utils.FormatDisplayNumber
local ResolveBlizzardAbbreviation = Utils.ResolveBlizzardAbbreviation
local GetSecondaryPowerTypeForUnit = Preview.GetSecondaryPowerTypeForUnit
local GetSecondaryPowerValues = Preview.GetSecondaryPowerValues
local GetSecondaryPowerDisplayValues = Preview.GetSecondaryPowerDisplayValues
local GetLiveSecondaryPowerValues = Preview.GetLiveSecondaryPowerValues

-- Power helpers keep resource/alt-power value refresh together.

local function IsSecretValue(value)
    return issecretvalue and issecretvalue(value) or false
end

local function HasUsableLivePower(unit, unitExists)
    if not (unitExists == true and UnitPower and UnitPowerMax) then
        return false
    end

    local current = UnitPower(unit)
    local maximum = UnitPowerMax(unit)
    return type(current) == "number"
        and type(maximum) == "number"
        and not IsSecretValue(current)
        and not IsSecretValue(maximum)
        and maximum > 0
end

local function ResolveBarVisualState(frame, componentKey, enabled, hasLiveData)
    if VisualPolicy.Resolve then
        return VisualPolicy.Resolve(frame, componentKey, {
            enabled = enabled,
            hasLiveData = hasLiveData,
        })
    end

    return nil
end

local function ResolveSimulationValues(frame, state)
    if VisualPolicy.GetSimulationValues then
        return VisualPolicy.GetSimulationValues(frame, state)
    end
    return Demo.GetUnitValues and Demo.GetUnitValues(frame) or nil
end

local function ResolveBarNumber(rawValue)
    if type(rawValue) == "number" then
        return rawValue, IsSecretValue(rawValue)
    end

    return ToSafeNumberValue(rawValue), false
end

function Power.RefreshUnitBarValues(owner, frame)
    if not frame or not frame._fpUnit then
        return
    end

    local unit = frame._fpUnit
    local unitExists = DoesUnitSeemPresent(unit)
    local powerEnabled = not (frame.config and frame.config.showPowerBar == false)
    local hasLivePower = HasUsableLivePower(unit, unitExists)
    local visualState = ResolveBarVisualState(frame, "PowerBar", powerEnabled, hasLivePower)
    local previewValues = nil
    if VisualPolicy.IsSimulatedState and VisualPolicy.IsSimulatedState(visualState) then
        previewValues = ResolveSimulationValues(frame, visualState)
    else
        previewValues = (Demo.GetUnitValues and Demo.GetUnitValues(frame)) or (IsPreviewModeEnabled() and Preview.GetTestValues(frame) or nil)
    end
    frame.LiveValues = frame.LiveValues or {}
    -- Legacy compatibility write-through for older text/bar readers.
    frame.TestValues = previewValues

    if frame.Elements.HealthBar and owner and owner.RefreshHealthBar then
        owner:RefreshHealthBar(frame)
    end

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

    frame.LiveValues.powerCurrentRaw = currentPower
    frame.LiveValues.powerMaxRaw = maxPower
    frame.LiveValues.powerCurrentText = FormatDisplayNumber(currentPower)
    frame.LiveValues.powerMaxText = FormatDisplayNumber(maxPower)
    frame.LiveValues.powerCurrentSafe = ToSafeNumberValue(currentPower)
    frame.LiveValues.powerMaxSafe = ToSafeNumberValue(maxPower)
    frame.LiveValues.powerCurrentAbbr = ResolveBlizzardAbbreviation(currentPower, frame.LiveValues.powerCurrentText)
    frame.LiveValues.powerMaxAbbr = ResolveBlizzardAbbreviation(maxPower, frame.LiveValues.powerMaxText)

    if frame.Elements.PowerBar then
        if RuntimeActivity.ShouldRunComponent and not RuntimeActivity.ShouldRunComponent(frame, "PowerBar") then
            if RuntimeActivity.ClearComponentVisual then
                RuntimeActivity.ClearComponentVisual(frame, "PowerBar")
            else
                frame.Elements.PowerBar:Hide()
            end
        else
            frame.Elements.PowerBar:SetMinMaxValues(0, maxPowerBarValue)
            frame.Elements.PowerBar:SetValue(currentPowerBarValue)
            if Demo.IsFrameInDemoMode and Demo.IsFrameInDemoMode(frame) and not (Demo.IsBarSmoothingDisabled and Demo.IsBarSmoothingDisabled()) and Demo.TouchDebug then
                Demo.TouchDebug(frame, "barSmoothingTicks")
            end
        end
    end

    if frame.Elements.AlternativePowerBar then
        local minAltPower = 0
        local currentAltPower = 0
        local maxAltPower = 0
        local showAltPower = false

        local liveSecondaryPowerType, liveAltPowerCurrent, liveAltPowerMax, liveAltPowerMin = nil, 0, 0, 0
        if GetLiveSecondaryPowerValues then
            liveSecondaryPowerType, liveAltPowerCurrent, liveAltPowerMax, liveAltPowerMin = GetLiveSecondaryPowerValues(unit)
        end
        local secondaryPowerType = liveSecondaryPowerType or GetSecondaryPowerTypeForUnit(unit)
        local altPowerEnabled = frame.config and frame.config.showAlternativePowerBar == true
        local hasLiveAltPower = unitExists == true and liveSecondaryPowerType ~= nil
        local altVisualState = ResolveBarVisualState(frame, "AlternativePowerBar", altPowerEnabled, hasLiveAltPower)
        local altPreviewValues = previewValues
        if VisualPolicy.IsSimulatedState and VisualPolicy.IsSimulatedState(altVisualState) then
            altPreviewValues = ResolveSimulationValues(frame, altVisualState)
        end

        if altPreviewValues and secondaryPowerType ~= nil then
            minAltPower = altPreviewValues.altPowerMin or 0
            currentAltPower = altPreviewValues.altPowerCurrent or 0
            maxAltPower = altPreviewValues.altPowerMax or 0
            showAltPower = true
        elseif liveSecondaryPowerType ~= nil and unitExists then
            currentAltPower = liveAltPowerCurrent
            maxAltPower = liveAltPowerMax
            minAltPower = liveAltPowerMin
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
        if Demo.IsFrameInDemoMode and Demo.IsFrameInDemoMode(frame) and not (Demo.IsBarSmoothingDisabled and Demo.IsBarSmoothingDisabled()) and Demo.TouchDebug then
            Demo.TouchDebug(frame, "barSmoothingTicks")
        end

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
    if not frame or frame.AlternativePowerEventFrame or frame._fpUnit ~= "player" then
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

        if unit and unit ~= currentOwner._fpUnit then
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
