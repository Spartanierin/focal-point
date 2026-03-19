local _, FocalPoint = ...

FocalPoint.TextElementEvents = FocalPoint.TextElementEvents or {}

local Events = FocalPoint.TextElementEvents

-- Owns the runtime event bridge that keeps text values refreshed without
-- forcing the main text module to hold all event plumbing inline.
function Events.Register(frame, deps)
    deps = deps or {}

    local IsPreviewModeEnabled = deps.IsPreviewModeEnabled
    local HasActiveCast = deps.HasActiveCast
    local FrameUsesCastTime = deps.FrameUsesCastTime
    local Refresh = deps.Refresh
    local RefreshUnitBarValues = deps.RefreshUnitBarValues
    local ApplyConfig = deps.ApplyConfig
    local RefreshCastBar = deps.RefreshCastBar
    local RefreshLiveValues = deps.RefreshLiveValues
    local UpdateTextElement = deps.UpdateTextElement
    local UpdateTextElements = deps.UpdateTextElements

    if not frame or frame.TextEventFrame then
        return
    end

    -- Keep text update events alive even if the owning unit frame is hidden or
    -- enters a protected combat state.
    local eventFrame = CreateFrame("Frame")
    eventFrame.owner = frame
    eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    eventFrame:RegisterEvent("PLAYER_LEVEL_UP")
    eventFrame:RegisterEvent("PLAYER_FLAGS_CHANGED")
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

    if frame.unit == "target" then
        eventFrame:RegisterEvent("PLAYER_TARGET_CHANGED")
    elseif frame.unit == "focus" then
        eventFrame:RegisterEvent("PLAYER_FOCUS_CHANGED")
    elseif frame.unit == "pet" then
        eventFrame:RegisterEvent("UNIT_PET")
    end

    eventFrame:SetScript("OnUpdate", function(self, elapsed)
        local owner = self.owner
        local castBar = owner and owner.Elements and owner.Elements.CastBar
        local hasPreviewCast = IsPreviewModeEnabled and IsPreviewModeEnabled() and castBar and castBar.isPreview
        if not owner or not FrameUsesCastTime or not FrameUsesCastTime(owner) or (not hasPreviewCast and not (HasActiveCast and HasActiveCast(owner.unit))) then
            self.elapsed = 0
            return
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
            UpdateTextElement(owner, "CastTime")
        end
    end)

    eventFrame:SetScript("OnEvent", function(_, event, unit)
        local owner = eventFrame.owner
        if not owner then
            return
        end

        if event == "PLAYER_TARGET_CHANGED" or event == "PLAYER_FOCUS_CHANGED" then
            if Refresh then
                Refresh(owner)
            end
            return
        end

        if event == "UNIT_PET" then
            if owner.unit == "pet" and unit == "player" and Refresh then
                Refresh(owner)
            end
            return
        end

        if event == "PLAYER_ENTERING_WORLD" and owner.unit ~= "player" then
            if Refresh then
                Refresh(owner)
            end
            return
        end

        if unit and unit ~= owner.unit then
            return
        end

        if event == "UNIT_HEALTH" or event == "UNIT_MAXHEALTH" then
            return
        end

        if RefreshUnitBarValues then
            RefreshUnitBarValues(owner)
        end
        if ApplyConfig then
            ApplyConfig(owner)
        end
        if RefreshCastBar then
            RefreshCastBar(owner)
        end
        if RefreshLiveValues then
            RefreshLiveValues(owner)
        end
        if UpdateTextElements then
            UpdateTextElements(owner)
        end
        if RefreshCastBar then
            RefreshCastBar(owner)
        end
    end)

    frame.TextEventFrame = eventFrame
end
