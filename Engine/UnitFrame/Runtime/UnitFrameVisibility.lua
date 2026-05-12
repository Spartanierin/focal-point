local _, FocalPoint = ...

FocalPoint.UnitFrameVisibility = FocalPoint.UnitFrameVisibility or {}
local Visibility = FocalPoint.UnitFrameVisibility

local Cast = FocalPoint.UnitFrameCastBar or {}
local Presence = FocalPoint.UnitFramePresence or {}
local State = FocalPoint.UnitFrameState or {}

local DoesUnitSeemPresent = Presence.DoesUnitSeemPresent
local GetTargetPresenceSnapshot = Presence.GetTargetPresenceSnapshot
local MaybeDebugTarget = Presence.MaybeDebugTarget
local ForceDebugTarget = Presence.ForceDebugTarget
local IsPreviewModeEnabled = Presence.IsPreviewModeEnabled

local function IsProtectedFrameInCombat(frame)
    return frame
        and frame.IsProtected
        and frame:IsProtected()
        and InCombatLockdown
        and InCombatLockdown()
end

local function IsMissingDebugSuppressed(frame)
    local now = GetTime and GetTime() or 0
    if frame and frame._suppressMissingUnitDebugUntil and now <= frame._suppressMissingUnitDebugUntil then
        return true
    end
    return FocalPoint and FocalPoint._suppressMissingUnitUntil and now <= FocalPoint._suppressMissingUnitUntil
end

local function ShouldSuppressFramesForSpecialMode()
    local inPetBattle = C_PetBattles
        and C_PetBattles.IsInBattle
        and C_PetBattles.IsInBattle()
    if inPetBattle then
        return true, "pet_battle"
    end

    local hasOverrideActionBar = C_ActionBar
        and C_ActionBar.HasOverrideActionBar
        and C_ActionBar.HasOverrideActionBar()
    if hasOverrideActionBar then
        return true, "override_action_bar"
    end

    local hasVehicleActionBar = C_ActionBar
        and C_ActionBar.HasVehicleActionBar
        and C_ActionBar.HasVehicleActionBar()
    if hasVehicleActionBar then
        return true, "vehicle_action_bar"
    end

    local hasVehicleUi = UnitHasVehicleUI and UnitHasVehicleUI("player")
    if hasVehicleUi then
        return true, "vehicle_ui"
    end

    return false, nil
end

local function QueueTargetRecoveryRefreshes(frame, reason)
    if not frame or frame.unit ~= "target" or not State.QueueRefresh then
        return
    end

    local now = GetTime and GetTime() or 0
    local cooldownUntil = tonumber(frame._targetRecoveryQueuedUntil) or 0
    if now <= cooldownUntil then
        return
    end

    frame._targetRecoveryQueuedUntil = now + 0.40
    local refreshReason = reason or "target_recovery"

    for _, delay in ipairs({ 0.10, 0.20, 0.35 }) do
        State.QueueRefresh(frame, refreshReason, "visibility", nil, delay)
    end
end

local function ShouldTreatMissingTargetAsSuspicious(frame)
    if not frame or frame.unit ~= "target" then
        return false
    end

    if IsProtectedFrameInCombat(frame) then
        return true
    end

    local shown = frame.IsShown and frame:IsShown() or false
    local alpha = tonumber(frame.GetAlpha and frame:GetAlpha() or 0) or 0
    local visiblyStuck = shown and alpha > 0.05

    local now = GetTime and GetTime() or 0
    local lastRelevantAt = tonumber(frame._lastTargetEventAt) or 0
    if visiblyStuck and lastRelevantAt > 0 and (now - lastRelevantAt) <= 1.0 then
        return true
    end

    local lastEvent = tostring(frame._lastVisibilityEvent or "")
    return visiblyStuck and (lastEvent == "PLAYER_TARGET_CHANGED" or lastEvent == "PLAYER_REGEN_ENABLED")
end

-- Visibility helpers handle visual cleanup and delayed refresh scheduling.

function Visibility.ClearFrameVisualState(frame, reason)
    if not frame then
        return
    end

    if frame.Texts then
        for _, textObject in pairs(frame.Texts) do
            if textObject and textObject.SetText then
                textObject:SetText("")
            end
            if textObject and textObject.Hide then
                textObject:Hide()
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

        local classPower = frame.Elements.ClassPowerBar
        if classPower then
            classPower:Hide()
            for index = 1, #(classPower.Bars or {}) do
                local bar = classPower.Bars[index]
                if bar then
                    bar:SetMinMaxValues(0, 1)
                    bar:SetValue(0)
                    bar:Hide()
                    if bar.bg then
                        bar.bg:Hide()
                    end
                end
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
            "ClassificationPortraitOverlay",
            "ClassificationCrest",
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
    if not frame then
        return
    end
    if State.QueueRefresh then
        State.QueueRefresh(frame, "visibility", "visibility", nil, 0)
        State.QueueRefresh(frame, "visibility", "visibility", nil, 0.05)
        QueueTargetRecoveryRefreshes(frame, "visibility_recovery")
        return
    end

    if FocalPoint.UnitFrame and FocalPoint.UnitFrame.Refresh then
        FocalPoint.UnitFrame:Refresh(frame)
    end
end

function Visibility.HandleMissingUnit(frame)
    if not frame then
        return false
    end

    local suppressForSpecialMode, specialModeReason = ShouldSuppressFramesForSpecialMode()
    if suppressForSpecialMode then
        if State.HandleUnitLost then
            State.HandleUnitLost(frame, specialModeReason or "special_mode")
        else
            Visibility.ClearFrameVisualState(frame, specialModeReason or "special_mode")
        end
        if frame.SetAlpha then
            frame:SetAlpha(0)
        end
        if frame.Hide and not IsProtectedFrameInCombat(frame) then
            frame:Hide()
        end
        return true
    end

    local protectedFrame = frame.IsProtected and frame:IsProtected()
    local shouldHideForMissingUnit = not IsPreviewModeEnabled()
        and frame.unit ~= "player"
        and (not DoesUnitSeemPresent(frame.unit))

    if shouldHideForMissingUnit and protectedFrame then
        if IsMissingDebugSuppressed(frame) then
            if State.HandleUnitLost then
                State.HandleUnitLost(frame, "missing_unit_protected_suppressed")
            else
                Visibility.ClearFrameVisualState(frame, "missing_unit_protected_suppressed")
            end
            if frame.SetAlpha then
                frame:SetAlpha(0)
            end
            if frame.Hide and not IsProtectedFrameInCombat(frame) then
                frame:Hide()
            end
            return true
        end

        local suspiciousMissingTarget = ShouldTreatMissingTargetAsSuspicious(frame)

        if suspiciousMissingTarget then
            ForceDebugTarget(frame, IsProtectedFrameInCombat(frame)
                and "Missing target during combat: clearing content, secure root unchanged"
                or "Missing target: clearing content, secure root unchanged", "missing_target", 2.0)
        end
        if State.HandleUnitLost then
            State.HandleUnitLost(frame, "missing_unit_protected")
        else
            Visibility.ClearFrameVisualState(frame, "missing_unit_protected")
        end
        if suspiciousMissingTarget then
            Visibility.QueueRefresh(frame)
        end
        if not IsProtectedFrameInCombat(frame) and frame.Hide then
            frame:Hide()
        end
        return true
    end

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

            if not IsMissingDebugSuppressed(frame) then
                ForceDebugTarget(frame, string.format(
                    "Hide-Kandidat: event=%s exists=%s guid=%s name=%s visible=%s dead=%s dt=%.2f",
                    tostring(frame._lastVisibilityEvent or "?"),
                    tostring(snapshot.exists),
                    tostring(snapshot.guid),
                    tostring(snapshot.name),
                    tostring(snapshot.visible),
                    tostring(snapshot.dead),
                    elapsedMissing
                ), "hide_candidate", 2.0)
            end

            if elapsedMissing < 0.35 then
                if State.HandleUnitLost then
                    State.HandleUnitLost(frame, "target_missing_transition")
                else
                    Visibility.ClearFrameVisualState(frame, "target_missing_transition")
                end
                frame:Hide()
                QueueTargetRecoveryRefreshes(frame, "target_missing_transition")
                return true
            end
        end
    else
        frame._missingUnitSince = nil
    end

    if shouldHideForMissingUnit then
        if IsMissingDebugSuppressed(frame) then
            if State.HandleUnitLost then
                State.HandleUnitLost(frame, "missing_unit_suppressed")
            else
                Visibility.ClearFrameVisualState(frame, "missing_unit_suppressed")
            end
            if frame.SetAlpha then
                frame:SetAlpha(0)
            end
            if frame.Hide then
                frame:Hide()
            end
            return true
        end

        if State.HandleUnitLost then
            State.HandleUnitLost(frame, "missing_unit")
        else
            Visibility.ClearFrameVisualState(frame, "missing_unit")
        end

        if frame.SetAlpha then
            frame:SetAlpha(0)
        end

        if not IsMissingDebugSuppressed(frame) then
            MaybeDebugTarget(frame, "Target-Frame wird jetzt verborgen")
        end
        frame:Hide()
        return true
    end

    return false
end

function Visibility.RegisterEvents(owner, frame)
    if not frame or frame.VisibilityEventFrame then
        return
    end

    -- Keep the event bridge independent from the secure unit frame itself.
    -- If the unit frame is hidden or enters an odd protected state in combat,
    -- we still want target/focus/pet events to keep flowing.
    local eventFrame = CreateFrame("Frame")
    eventFrame.owner = frame
    eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    eventFrame:RegisterEvent("UNIT_HEALTH")
    eventFrame:RegisterEvent("UNIT_MAXHEALTH")
    eventFrame:RegisterEvent("UNIT_FLAGS")
    eventFrame:RegisterEvent("UNIT_NAME_UPDATE")
    eventFrame:RegisterEvent("UNIT_TARGETABLE_CHANGED")
    eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
    eventFrame:RegisterEvent("UNIT_ENTERED_VEHICLE")
    eventFrame:RegisterEvent("UNIT_EXITED_VEHICLE")
    eventFrame:RegisterEvent("UPDATE_BONUS_ACTIONBAR")
    eventFrame:RegisterEvent("UPDATE_VEHICLE_ACTIONBAR")
    eventFrame:RegisterEvent("UPDATE_OVERRIDE_ACTIONBAR")
    eventFrame:RegisterEvent("PET_BATTLE_OPENING_START")
    eventFrame:RegisterEvent("PET_BATTLE_CLOSE")

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

    if type(frame.unit) == "string" and frame.unit:match("^boss%d+$") then
        eventFrame:RegisterEvent("INSTANCE_ENCOUNTER_ENGAGE_UNIT")
    end

    eventFrame:SetScript("OnEvent", function(_, event, unit)
        local currentOwner = eventFrame.owner
        if not currentOwner then
            return
        end

        if event ~= "PLAYER_REGEN_ENABLED"
            and unit
            and unit ~= currentOwner.unit
            and not (event == "UNIT_ENTERED_VEHICLE" and unit == "player")
            and not (event == "UNIT_EXITED_VEHICLE" and unit == "player")
            and not (currentOwner.unit == "targettarget" and event == "UNIT_TARGET" and unit == "target")
            and not (currentOwner.unit == "focustarget" and event == "UNIT_TARGET" and unit == "focus")
            and not (currentOwner.unit == "pet" and event == "UNIT_PET" and unit == "player")
        then
            return
        end

        if event == "UNIT_PET" and unit ~= "player" then
            return
        end

        if (event == "PLAYER_TARGET_CHANGED" or event == "PLAYER_FOCUS_CHANGED" or event == "UNIT_PET" or event == "UNIT_TARGET")
            and State.HandleTargetSwap
        then
            State.HandleTargetSwap(currentOwner, event)
        end

        currentOwner._lastVisibilityEvent = event
        if currentOwner.unit == "target" and (event == "PLAYER_TARGET_CHANGED" or event == "PLAYER_REGEN_ENABLED") then
            currentOwner._lastTargetEventAt = GetTime and GetTime() or 0
        end
        if currentOwner.unit == "target" and event == "PLAYER_TARGET_CHANGED" then
            local snapshot = GetTargetPresenceSnapshot(currentOwner.unit)
            local shown = currentOwner.IsShown and currentOwner:IsShown() or false
            local alpha = tonumber(currentOwner.GetAlpha and currentOwner:GetAlpha() or 0) or 0
            local suspicious = not snapshot.exists
                or not snapshot.guid
                or not snapshot.name
                or not shown
                or alpha < 0.99

            if suspicious then
                ForceDebugTarget(currentOwner, string.format(
                    "Event PLAYER_TARGET_CHANGED: inCombat=%s shown=%s alpha=%.2f exists=%s guid=%s name=%s visible=%s dead=%s",
                    tostring(InCombatLockdown and InCombatLockdown() or false),
                    tostring(shown),
                    alpha,
                    tostring(snapshot.exists),
                    tostring(snapshot.guid),
                    tostring(snapshot.name),
                    tostring(snapshot.visible),
                    tostring(snapshot.dead)
                ), "event_target_changed", 0.50)
            end
        end
        if State.QueueRefresh then
            State.QueueRefresh(currentOwner, event, "visibility")
        else
            owner:Refresh(currentOwner)
        end

        if event == "PLAYER_TARGET_CHANGED" or event == "PLAYER_FOCUS_CHANGED" or event == "UNIT_PET" or event == "UNIT_TARGET" then
            Visibility.QueueRefresh(currentOwner)
            if currentOwner.unit == "target" and event == "PLAYER_TARGET_CHANGED" then
                QueueTargetRecoveryRefreshes(currentOwner, "target_changed_recovery")
            end
        end
    end)

    frame.VisibilityEventFrame = eventFrame
end
