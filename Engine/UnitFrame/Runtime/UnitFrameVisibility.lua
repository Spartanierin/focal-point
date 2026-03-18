local _, FocalPoint = ...

FocalPoint.UnitFrameVisibility = FocalPoint.UnitFrameVisibility or {}
local Visibility = FocalPoint.UnitFrameVisibility

local Cast = FocalPoint.UnitFrameCastBar or {}
local Presence = FocalPoint.UnitFramePresence or {}

local DoesUnitSeemPresent = Presence.DoesUnitSeemPresent
local GetTargetPresenceSnapshot = Presence.GetTargetPresenceSnapshot
local MaybeDebugTarget = Presence.MaybeDebugTarget
local IsPreviewModeEnabled = Presence.IsPreviewModeEnabled

-- Visibility helpers handle visual cleanup and delayed refresh scheduling.

function Visibility.ClearFrameVisualState(frame)
    if not frame then
        return
    end

    if frame.Texts then
        for _, textObject in pairs(frame.Texts) do
            if textObject and textObject.SetText then
                textObject:SetText("")
            end
        end
    end

    if frame.Elements then
        local health = frame.Elements.HealthBar
        if health then
            health:SetMinMaxValues(0, 1)
            health:SetValue(0)
            health:Hide()
            if health.bg then
                health.bg:Hide()
            end
        end

        local power = frame.Elements.PowerBar
        if power then
            power:SetMinMaxValues(0, 1)
            power:SetValue(0)
            power:Hide()
            if power.bg then
                power.bg:Hide()
            end
        end

        local altPower = frame.Elements.AlternativePowerBar
        if altPower then
            altPower:SetMinMaxValues(0, 1)
            altPower:SetValue(0)
            altPower:Hide()
            if altPower.bg then
                altPower.bg:Hide()
            end
        end

        if frame.Elements.CastBar then
            Cast.Stop(frame)
        end

        local portrait = frame.Elements.Portrait
        if portrait then
            portrait:Hide()
            if portrait.Texture then
                portrait.Texture:SetTexture(nil)
            end
        end

        for _, key in ipairs({
            "RaidTargetIcon",
            "LeaderIcon",
            "RoleIcon",
            "CombatIndicator",
            "RestingIndicator",
            "ReadyCheckIndicator",
        }) do
            local holder = frame.Elements[key]
            if holder then
                holder:Hide()
                local texture = holder.Texture or holder
                if texture and texture.SetTexture then
                    texture:SetTexture(nil)
                end
            end
        end
    end

    if frame.SetBackdropColor then
        frame:SetBackdropColor(0, 0, 0, 0)
    end
    if frame.SetBackdropBorderColor then
        frame:SetBackdropBorderColor(0, 0, 0, 0)
    end

    frame._rangeCurrentAlpha = 0
    frame._rangeTargetAlpha = 0
    if frame.RangeFadeDriver then
        frame.RangeFadeDriver:Hide()
    end
end

function Visibility.QueueRefresh(frame)
    if not frame or not C_Timer or not C_Timer.After then
        return
    end

    frame.visibilityRefreshQueued = frame.visibilityRefreshQueued or {}

    local function QueueAfter(delay)
        if frame.visibilityRefreshQueued[delay] then
            return
        end

        frame.visibilityRefreshQueued[delay] = true
        C_Timer.After(delay, function()
            if not frame then
                return
            end

            if frame.visibilityRefreshQueued then
                frame.visibilityRefreshQueued[delay] = nil
            end

            if FocalPoint.UnitFrame and FocalPoint.UnitFrame.Refresh then
                FocalPoint.UnitFrame:Refresh(frame)
            end
        end)
    end

    QueueAfter(0)
    QueueAfter(0.05)
end

function Visibility.HandleMissingUnit(frame)
    if not frame then
        return false
    end

    local shouldHideForMissingUnit = not IsPreviewModeEnabled()
        and frame.unit ~= "player"
        and (not DoesUnitSeemPresent(frame.unit))

    if shouldHideForMissingUnit then
        if frame.EnableMouse then
            frame:EnableMouse(false)
        end
        if frame.SetMouseClickEnabled then
            frame:SetMouseClickEnabled(false)
        end

        frame._missingUnitSince = frame._missingUnitSince or (GetTime and GetTime() or 0)

        if frame.unit == "target" then
            local now = GetTime and GetTime() or 0
            local elapsedMissing = now - (frame._missingUnitSince or now)
            local snapshot = GetTargetPresenceSnapshot(frame.unit)

            MaybeDebugTarget(frame, string.format(
                "Hide-Kandidat: event=%s exists=%s guid=%s name=%s visible=%s dead=%s dt=%.2f",
                tostring(frame._lastVisibilityEvent or "?"),
                tostring(snapshot.exists),
                tostring(snapshot.guid),
                tostring(snapshot.name),
                tostring(snapshot.visible),
                tostring(snapshot.dead),
                elapsedMissing
            ))

            if elapsedMissing < 0.35 then
                Visibility.ClearFrameVisualState(frame)
                frame:Hide()
                return true
            end
        end
    else
        frame._missingUnitSince = nil
    end

    if shouldHideForMissingUnit then
        Visibility.ClearFrameVisualState(frame)

        if frame.SetAlpha then
            frame:SetAlpha(0)
        end

        MaybeDebugTarget(frame, "Target-Frame wird jetzt verborgen")
        frame:Hide()
        return true
    end

    return false
end

function Visibility.RegisterEvents(owner, frame)
    if not frame or frame.VisibilityEventFrame or frame.unit == "player" then
        return
    end

    local eventFrame = CreateFrame("Frame", nil, frame)
    eventFrame.owner = frame
    eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    eventFrame:RegisterEvent("UNIT_HEALTH")
    eventFrame:RegisterEvent("UNIT_MAXHEALTH")
    eventFrame:RegisterEvent("UNIT_FLAGS")
    eventFrame:RegisterEvent("UNIT_NAME_UPDATE")
    eventFrame:RegisterEvent("UNIT_TARGETABLE_CHANGED")

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

        if unit and unit ~= currentOwner.unit and not (currentOwner.unit == "pet" and event == "UNIT_PET" and unit == "player") then
            return
        end

        if event == "UNIT_PET" and unit ~= "player" then
            return
        end

        currentOwner._lastVisibilityEvent = event
        owner:Refresh(currentOwner)

        if event == "PLAYER_TARGET_CHANGED" or event == "PLAYER_FOCUS_CHANGED" or event == "UNIT_PET" then
            Visibility.QueueRefresh(currentOwner)
        end
    end)

    frame.VisibilityEventFrame = eventFrame
end
