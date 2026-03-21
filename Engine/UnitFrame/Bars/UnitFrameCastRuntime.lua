local _, FocalPoint = ...

FocalPoint.UnitFrameCastRuntime = FocalPoint.UnitFrameCastRuntime or {}
local Runtime = FocalPoint.UnitFrameCastRuntime

local Cast = FocalPoint.UnitFrameCastBar or {}
local Presence = FocalPoint.UnitFramePresence or {}
local State = FocalPoint.UnitFrameState or {}

local ApplyCastBarStateColor = Cast.ApplyStateColor
local GetActiveCastTiming = Cast.GetActiveTiming
local StopCastBar = Cast.Stop
local IsPreviewModeEnabled = Presence.IsPreviewModeEnabled

-- Runtime helpers for cast-bar refresh and event binding.

function Runtime.Refresh(owner, frame)
    local castBar = frame and frame.Elements and frame.Elements.CastBar
    if not castBar then
        return
    end

    if frame.config and frame.config.showCastBar == false then
        StopCastBar(frame)
        return
    end

    local unit = frame.unit
    if not unit then
        StopCastBar(frame)
        return
    end

    local now = GetTime and GetTime() or 0
    local isChannel, startTime, endTime, spellIcon, isInterruptible, castID, castToken = GetActiveCastTiming(unit, castBar)
    local hasCast = type(startTime) == "number" and type(endTime) == "number"

    if hasCast then
        local duration = math.max(endTime - startTime, 0.001)

        castBar.isCasting = true
        castBar.isChannel = isChannel
        castBar.isPreview = false
        castBar.isInterruptible = isInterruptible == true
        castBar.castID = castID
        castBar.castToken = castToken
        castBar.startTime = startTime
        castBar.endTime = endTime
        castBar:SetMinMaxValues(0, duration)

        if isChannel then
            castBar:SetValue(math.max(endTime - now, 0))
        else
            castBar:SetValue(math.max(now - startTime, 0))
        end

        ApplyCastBarStateColor(
            castBar,
            castBar.isInterruptible,
            frame.config and frame.config.castBarColor,
            frame.config and frame.config.castBarUninterruptibleColor
        )

        if castBar.icon then
            if frame.config and frame.config.showCastBarIcon ~= false and spellIcon ~= nil and spellIcon ~= "" then
                castBar.icon:SetTexture(spellIcon)
                castBar.icon:Show()
            else
                castBar.icon:SetTexture(nil)
                castBar.icon:Hide()
            end
        end

        castBar:Show()
    elseif not castBar.isPreview then
        StopCastBar(frame)
    end
end

function Runtime.RegisterEvents(owner, frame)
    if not frame or frame.CastBarEventFrame or not frame.Elements or not frame.Elements.CastBar then
        return
    end

    local eventFrame = CreateFrame("Frame", nil, frame)
    eventFrame.owner = frame
    eventFrame.elapsed = 0

    eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    eventFrame:RegisterEvent("UNIT_SPELLCAST_START")
    eventFrame:RegisterEvent("UNIT_SPELLCAST_STOP")
    eventFrame:RegisterEvent("UNIT_SPELLCAST_FAILED")
    eventFrame:RegisterEvent("UNIT_SPELLCAST_INTERRUPTED")
    eventFrame:RegisterEvent("UNIT_SPELLCAST_DELAYED")
    eventFrame:RegisterEvent("UNIT_SPELLCAST_CHANNEL_START")
    eventFrame:RegisterEvent("UNIT_SPELLCAST_CHANNEL_STOP")
    eventFrame:RegisterEvent("UNIT_SPELLCAST_CHANNEL_UPDATE")

    if frame.unit == "target" then
        eventFrame:RegisterEvent("PLAYER_TARGET_CHANGED")
    elseif frame.unit == "focus" then
        eventFrame:RegisterEvent("PLAYER_FOCUS_CHANGED")
    elseif frame.unit == "pet" then
        eventFrame:RegisterEvent("UNIT_PET")
    end

    eventFrame:SetScript("OnUpdate", function(self, elapsed)
        local currentOwner = self.owner
        local castBar = currentOwner and currentOwner.Elements and currentOwner.Elements.CastBar
        if not currentOwner or not castBar or not castBar.isCasting then
            self.elapsed = 0
            return
        end

        self.elapsed = (self.elapsed or 0) + elapsed
        if self.elapsed < 0.02 then
            return
        end

        self.elapsed = 0

        local now = GetTime and GetTime() or 0
        if castBar.isPreview then
            if not IsPreviewModeEnabled() then
                StopCastBar(currentOwner)
                return
            end

            if now >= castBar.endTime then
                castBar.startTime = now
                castBar.endTime = now + 2.5
                castBar:SetMinMaxValues(castBar.startTime, castBar.endTime)
            end

            castBar:SetValue(now)
            return
        end

        owner:RefreshCastBar(currentOwner)
    end)

    eventFrame:SetScript("OnEvent", function(_, event, unit)
        local currentOwner = eventFrame.owner
        if not currentOwner then
            return
        end

        local function Queue(scope, options)
            if State.QueueRefresh then
                State.QueueRefresh(currentOwner, event, scope, options)
            else
                owner:RefreshCastBar(currentOwner)
            end
        end

        if event == "PLAYER_TARGET_CHANGED" or event == "PLAYER_FOCUS_CHANGED" then
            Queue({ "castbar", "layout" })
            return
        end

        if event == "UNIT_PET" then
            if currentOwner.unit == "pet" and unit == "player" then
                Queue({ "castbar", "layout" })
            end
            return
        end

        if event == "PLAYER_ENTERING_WORLD" then
            Queue({ "castbar", "layout" })
            return
        end

        if unit and unit ~= currentOwner.unit then
            return
        end

        if event == "UNIT_SPELLCAST_STOP"
            or event == "UNIT_SPELLCAST_FAILED"
            or event == "UNIT_SPELLCAST_INTERRUPTED"
            or event == "UNIT_SPELLCAST_CHANNEL_STOP"
        then
            Queue("castbar")
            return
        end

        Queue("castbar")
    end)

    frame.CastBarEventFrame = eventFrame
end
