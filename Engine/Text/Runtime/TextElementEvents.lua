local _, FocalPoint = ...

FocalPoint.TextElementEvents = FocalPoint.TextElementEvents or {}

local Events = FocalPoint.TextElementEvents
local RuntimeState = FocalPoint.UnitFrameState or {}
local TextState = FocalPoint.TextElementState or {}
local POWER_TEXT_DEPENDENCIES = {
    power = true,
    altpower = true,
    classpower = true,
}
local CAST_TEXT_DEPENDENCIES = {
    cast = true,
    time = true,
}
local STATUS_TEXT_DEPENDENCIES = {
    status = true,
}
local STATUS_TEXT_REFRESH_OPTIONS = {
    textDependencies = STATUS_TEXT_DEPENDENCIES,
}

-- Owns the runtime event bridge that keeps text values refreshed without
-- forcing the main text module to hold all event plumbing inline.
function Events.Register(frame, deps)
    deps = deps or {}

    local IsPreviewModeEnabled = deps.IsPreviewModeEnabled
    local HasActiveCast = deps.HasActiveCast
    local FrameUsesCastTime = deps.FrameUsesCastTime
    local ResolveCastTimeTextKey = deps.ResolveCastTimeTextKey
    local Refresh = deps.Refresh
    local RefreshCastBar = deps.RefreshCastBar
    local UpdateTextElement = deps.UpdateTextElement

    if not frame or frame.TextEventFrame then
        return
    end

    if TextState.Ensure then
        TextState.Ensure(frame)
    end

    local function QueueTextCommit(reason, scope, options, delay)
        if TextState.QueueRefresh then
            return TextState.QueueRefresh(frame, reason, scope or "texts", options, delay)
        end

        if RuntimeState.QueueRefresh then
            return RuntimeState.QueueRefresh(frame, reason or "texts", scope or "texts", options, delay)
        end

        if Refresh then
            return Refresh(frame)
        end
    end

    -- Keep text update events alive even if the owning unit frame is hidden or
    -- enters a protected combat state.
    local eventFrame = CreateFrame("Frame")
    eventFrame.owner = frame
    eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    eventFrame:RegisterEvent("PLAYER_LEVEL_UP")
    eventFrame:RegisterEvent("PLAYER_FLAGS_CHANGED")
    eventFrame:RegisterEvent("PLAYER_UPDATE_RESTING")
    eventFrame:RegisterEvent("GROUP_ROSTER_UPDATE")
    eventFrame:RegisterEvent("PARTY_LEADER_CHANGED")
    eventFrame:RegisterEvent("PLAYER_ROLES_ASSIGNED")
    eventFrame:RegisterEvent("UNIT_LEVEL")
    eventFrame:RegisterEvent("UNIT_FLAGS")
    eventFrame:RegisterEvent("UNIT_CONNECTION")
    eventFrame:RegisterEvent("UNIT_POWER_UPDATE")
    eventFrame:RegisterEvent("UNIT_MAXPOWER")
    eventFrame:RegisterEvent("UNIT_DISPLAYPOWER")
    eventFrame:RegisterEvent("UNIT_SPELLCAST_START")
    eventFrame:RegisterEvent("UNIT_SPELLCAST_STOP")
    eventFrame:RegisterEvent("UNIT_SPELLCAST_FAILED")
    eventFrame:RegisterEvent("UNIT_SPELLCAST_INTERRUPTED")
    eventFrame:RegisterEvent("UNIT_SPELLCAST_CHANNEL_START")
    eventFrame:RegisterEvent("UNIT_SPELLCAST_CHANNEL_STOP")
    eventFrame:RegisterEvent("UNIT_SPELLCAST_DELAYED")
    eventFrame:RegisterEvent("UNIT_SPELLCAST_CHANNEL_UPDATE")
    eventFrame.elapsed = 0

    if frame._fpUnit == "target" then
        eventFrame:RegisterEvent("PLAYER_TARGET_CHANGED")
    elseif frame._fpUnit == "targettarget" then
        eventFrame:RegisterEvent("PLAYER_TARGET_CHANGED")
        eventFrame:RegisterEvent("UNIT_TARGET")
        eventFrame:RegisterEvent("UNIT_NAME_UPDATE")
    elseif frame._fpUnit == "focustarget" then
        eventFrame:RegisterEvent("PLAYER_FOCUS_CHANGED")
        eventFrame:RegisterEvent("UNIT_TARGET")
        eventFrame:RegisterEvent("UNIT_NAME_UPDATE")
    elseif frame._fpUnit == "focus" then
        eventFrame:RegisterEvent("PLAYER_FOCUS_CHANGED")
    elseif frame._fpUnit == "pet" then
        eventFrame:RegisterEvent("UNIT_PET")
    end

    eventFrame:SetScript("OnUpdate", function(self, elapsed)
        local owner = self.owner
        local castBar = owner and owner.Elements and owner.Elements.CastBar
        local hasPreviewCast = IsPreviewModeEnabled and IsPreviewModeEnabled() and castBar and castBar.isPreview
        if not owner or not FrameUsesCastTime or not FrameUsesCastTime(owner) or (not hasPreviewCast and not (HasActiveCast and HasActiveCast(owner._fpUnit))) then
            self.elapsed = 0
            if TextState.SetCastTickerActive then
                TextState.SetCastTickerActive(owner, false)
            end
            return
        end

        if TextState.SetCastTickerActive then
            TextState.SetCastTickerActive(owner, true)
        end
        self.elapsed = (self.elapsed or 0) + elapsed
        if self.elapsed < 0.05 then
            return
        end

        self.elapsed = 0
        if RefreshCastBar then
            RefreshCastBar(owner)
        end
        if UpdateTextElement then
            local castTimeKey = ResolveCastTimeTextKey and ResolveCastTimeTextKey(owner) or "CastTime"
            if castTimeKey then
                UpdateTextElement(owner, castTimeKey)
            end
        end
    end)

    eventFrame:SetScript("OnEvent", function(_, event, unit)
        local owner = eventFrame.owner
        if not owner then
            return
        end

        if event == "PLAYER_UPDATE_RESTING" then
            if owner._fpUnit == "player" then
                QueueTextCommit(event, "texts", STATUS_TEXT_REFRESH_OPTIONS)
            end
            return
        end

        if event == "GROUP_ROSTER_UPDATE" or event == "PARTY_LEADER_CHANGED" or event == "PLAYER_ROLES_ASSIGNED" then
            QueueTextCommit(event, "texts", STATUS_TEXT_REFRESH_OPTIONS)
            return
        end

        if event == "PLAYER_TARGET_CHANGED" or event == "PLAYER_FOCUS_CHANGED" then
            QueueTextCommit(event, "texts")
            return
        end

        if event == "UNIT_TARGET" then
            if owner._fpUnit ~= "targettarget" or unit ~= "target" then
                if owner._fpUnit ~= "focustarget" or unit ~= "focus" then
                    return
                end
            end
            QueueTextCommit(event, "texts")
            return
        end

        if event == "UNIT_NAME_UPDATE" then
            if (owner._fpUnit == "targettarget" or owner._fpUnit == "focustarget") and unit == owner._fpUnit then
                QueueTextCommit(event, "texts")
            end
            return
        end

        if event == "UNIT_PET" then
            if owner._fpUnit == "pet" and unit == "player" then
                QueueTextCommit(event, "texts")
            end
            return
        end

        if event == "PLAYER_ENTERING_WORLD" and owner._fpUnit ~= "player" then
            QueueTextCommit(event, "texts")
            return
        end

        if unit and unit ~= owner._fpUnit then
            return
        end

        if event == "UNIT_HEALTH" or event == "UNIT_MAXHEALTH" then
            return
        end

        if event == "UNIT_POWER_UPDATE" or event == "UNIT_MAXPOWER" or event == "UNIT_DISPLAYPOWER" then
            QueueTextCommit(event, "texts", { textDependencies = POWER_TEXT_DEPENDENCIES })
            return
        end

        if event == "UNIT_SPELLCAST_START"
            or event == "UNIT_SPELLCAST_STOP"
            or event == "UNIT_SPELLCAST_FAILED"
            or event == "UNIT_SPELLCAST_INTERRUPTED"
            or event == "UNIT_SPELLCAST_CHANNEL_START"
            or event == "UNIT_SPELLCAST_CHANNEL_STOP"
            or event == "UNIT_SPELLCAST_DELAYED"
            or event == "UNIT_SPELLCAST_CHANNEL_UPDATE"
        then
            QueueTextCommit(event, "texts", { textDependencies = CAST_TEXT_DEPENDENCIES })
            return
        end

        QueueTextCommit(event, "texts")
    end)

    frame.TextEventFrame = eventFrame
end
