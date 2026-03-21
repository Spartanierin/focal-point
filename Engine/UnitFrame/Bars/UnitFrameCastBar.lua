local _, FocalPoint = ...

FocalPoint.UnitFrameCastBar = FocalPoint.UnitFrameCastBar or {}
local CastBar = FocalPoint.UnitFrameCastBar

local Assets = FocalPoint.UnitFrameAssets or {}
local State = FocalPoint.UnitFrameState or {}
local Utils = FocalPoint.UnitFrameUtils or {}

local UnpackColor = Utils.UnpackColor
local ResolveInterruptState = Utils.ResolveInterruptState

-- Cast bar helpers keep timing/state logic together so runtime refresh code
-- can stay focused on orchestration.

function CastBar.ApplyStateColor(castBar, interruptState, baseColor, interruptibleColor)
    if not castBar then
        return
    end

    if interruptState == "INTERRUPTIBLE" then
        local r, g, b, a = UnpackColor(interruptibleColor, { 0.60, 0.60, 0.60, 1.00 })
        castBar:SetStatusBarColor(r, g, b, 1.00)
        castBar:SetAlpha(a or 1.00)
    else
        local r, g, b, a = UnpackColor(baseColor, { 1.00, 0.72, 0.18, 1.00 })
        castBar:SetStatusBarColor(r, g, b, 1.00)
        castBar:SetAlpha(a or 1.00)
    end
end

function CastBar.GetActiveTiming(unit, castBar)
    if not unit then
        return nil, nil, nil, nil, nil, nil
    end

    local function ResolveFallbackDuration(durationMS, fallbackSeconds)
        if type(durationMS) == "number" and not (issecretvalue and issecretvalue(durationMS)) then
            return durationMS > 100 and (durationMS / 1000) or durationMS
        end

        return fallbackSeconds
    end

    local function ReuseExistingTiming(isChannel, castID, castToken)
        if not castBar or not castBar.isCasting then
            return nil, nil
        end

        if castBar.isChannel ~= isChannel then
            return nil, nil
        end

        if castID ~= nil and castBar.castID == castID then
            return castBar.startTime, castBar.endTime
        end

        local okHasToken, hasToken = pcall(function()
            return type(castToken) == "string" and castToken ~= ""
        end)
        if okHasToken and hasToken then
            local okSameToken, sameToken = pcall(function()
                return castBar.castToken == castToken
            end)
            if okSameToken and sameToken then
                return castBar.startTime, castBar.endTime
            end
        end

        return nil, nil
    end

    if UnitCastingInfo then
        local castName, _, castIcon, startTimeMS, endTimeMS, _, _, notInterruptible, _, castID = UnitCastingInfo(unit)
        if type(castName) == "string" then
            local interruptState = ResolveInterruptState(notInterruptible)
            if type(startTimeMS) == "number"
                and type(endTimeMS) == "number"
                and not (issecretvalue and issecretvalue(startTimeMS))
                and not (issecretvalue and issecretvalue(endTimeMS))
            then
                return false, startTimeMS / 1000, endTimeMS / 1000, castIcon, interruptState, castID
            end

            if UnitCastingDuration then
                local durationMS = UnitCastingDuration(unit)
                local duration = ResolveFallbackDuration(durationMS, nil)
                if duration then
                    if castBar
                        and castBar.isCasting
                        and not castBar.isChannel
                        and castBar.castID == castID
                        and type(castBar.startTime) == "number"
                        and type(castBar.endTime) == "number"
                    then
                        return false, castBar.startTime, castBar.endTime, castIcon, interruptState, castID
                    end

                    local now = GetTime and GetTime() or 0
                    return false, now, now + duration, castIcon, interruptState, castID
                end
            end

            local now = GetTime and GetTime() or 0
            local reusedStart, reusedEnd = ReuseExistingTiming(false, castID, castName)
            if type(reusedStart) == "number" and type(reusedEnd) == "number" then
                return false, reusedStart, reusedEnd, castIcon, interruptState, castID, castName
            end

            return false, now, now + 2.5, castIcon, interruptState, castID, castName
        end
    end

    if UnitChannelInfo then
        local channelName, _, channelIcon, startTimeMS, endTimeMS, _, notInterruptible, _, _, castID = UnitChannelInfo(unit)
        if type(channelName) == "string" then
            local interruptState = ResolveInterruptState(notInterruptible)
            if type(startTimeMS) == "number"
                and type(endTimeMS) == "number"
                and not (issecretvalue and issecretvalue(startTimeMS))
                and not (issecretvalue and issecretvalue(endTimeMS))
            then
                return true, startTimeMS / 1000, endTimeMS / 1000, channelIcon, interruptState, castID
            end

            if UnitChannelDuration then
                local durationMS = UnitChannelDuration(unit)
                local duration = ResolveFallbackDuration(durationMS, nil)
                if duration then
                    if castBar
                        and castBar.isCasting
                        and castBar.isChannel
                        and castBar.castID == castID
                        and type(castBar.startTime) == "number"
                        and type(castBar.endTime) == "number"
                    then
                        return true, castBar.startTime, castBar.endTime, channelIcon, interruptState, castID
                    end

                    local now = GetTime and GetTime() or 0
                    return true, now, now + duration, channelIcon, interruptState, castID
                end
            end

            local now = GetTime and GetTime() or 0
            local reusedStart, reusedEnd = ReuseExistingTiming(true, castID, channelName)
            if type(reusedStart) == "number" and type(reusedEnd) == "number" then
                return true, reusedStart, reusedEnd, channelIcon, interruptState, castID, channelName
            end

            return true, now, now + 2.5, channelIcon, interruptState, castID, channelName
        end
    end

    return nil, nil, nil, nil, nil, nil
end

function CastBar.Start(frame)
    local castBar = frame and frame.Elements and frame.Elements.CastBar
    local unit = frame and frame.unit
    if not castBar or not unit then
        return
    end

    local isChannel, startTime, endTime, spellIcon, interruptState, castID, castToken = CastBar.GetActiveTiming(unit, castBar)

    if type(startTime) ~= "number" or type(endTime) ~= "number" then
        CastBar.Stop(frame)
        return
    end

    castBar.startTime = startTime
    castBar.endTime = endTime
    castBar.isCasting = true
    castBar.isChannel = isChannel and true or false
    castBar.isPreview = false
    castBar.interruptState = interruptState or "UNKNOWN"
    castBar.isInterruptible = castBar.interruptState == "INTERRUPTIBLE"
    castBar.canKick = castBar.interruptState == "INTERRUPTIBLE"
    castBar.castID = castID
    castBar.castToken = castToken
    castBar:SetMinMaxValues(castBar.startTime, castBar.endTime)
    castBar:SetValue(castBar.isChannel and castBar.endTime or castBar.startTime)
    CastBar.ApplyStateColor(
        castBar,
        castBar.interruptState,
        frame.config and frame.config.castBarColor,
        frame.config and (frame.config.castBarInterruptibleColor or frame.config.castBarUninterruptibleColor)
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

    if frame.config and frame.config.showCastBar ~= false then
        castBar:Show()
    end
end

function CastBar.StartPreview(frame)
    local castBar = frame and frame.Elements and frame.Elements.CastBar
    if not castBar then
        return
    end

    local now = GetTime and GetTime() or 0
    castBar.startTime = now
    castBar.endTime = now + 2.5
    castBar.isCasting = true
    castBar.isChannel = false
    castBar.isPreview = true
    castBar.interruptState = "INTERRUPTIBLE"
    castBar.isInterruptible = true
    castBar.canKick = true
    castBar.castID = nil
    castBar.castToken = "preview"
    castBar:SetMinMaxValues(castBar.startTime, castBar.endTime)
    castBar:SetValue(now + 1.25)
    CastBar.ApplyStateColor(
        castBar,
        castBar.interruptState,
        frame.config and frame.config.castBarColor,
        frame.config and (frame.config.castBarInterruptibleColor or frame.config.castBarUninterruptibleColor)
    )

    if castBar.icon then
        if frame.config and frame.config.showCastBarIcon ~= false then
            castBar.icon:SetTexture(136048)
            castBar.icon:Show()
        else
            castBar.icon:SetTexture(nil)
            castBar.icon:Hide()
        end
    end

    if frame.config and frame.config.showCastBar ~= false then
        castBar:Show()
    end
end

function CastBar.Stop(frame)
    local castBar = frame and frame.Elements and frame.Elements.CastBar
    if not castBar then
        return
    end

    castBar.isCasting = false
    castBar.isChannel = false
    castBar.isPreview = false
    castBar.interruptState = "UNKNOWN"
    castBar.isInterruptible = false
    castBar.canKick = false
    castBar.startTime = 0
    castBar.endTime = 0
    castBar.castID = nil
    castBar.castToken = nil
    if castBar.icon then
        castBar.icon:SetTexture(nil)
        castBar.icon:Hide()
    end
    castBar:Hide()
end

function CastBar.QueueRefresh(frame)
    if not frame then
        return
    end

    if State.QueueRefresh then
        State.QueueRefresh(frame, "castbar", "castbar")
        return
    end

    if not C_Timer or not C_Timer.After then
        return
    end

    if frame.castBarRefreshQueued then
        return
    end

    frame.castBarRefreshQueued = true
    C_Timer.After(0, function()
        if not frame then
            return
        end

        frame.castBarRefreshQueued = false

        if FocalPoint.UnitFrame and FocalPoint.UnitFrame.RefreshCastBar then
            FocalPoint.UnitFrame:RefreshCastBar(frame)
        end
    end)
end

function CastBar.ApplyLayout(frame, options)
    local castBar = frame and frame.Elements and frame.Elements.CastBar
    if not castBar then
        return
    end

    local showCastBar = options.showCastBar
    local showCastBarIcon = options.showCastBarIcon
    local castBarHeight = options.castBarHeight
    local castBarIconSize = showCastBarIcon and castBarHeight or 0
    local castBarIconGap = showCastBarIcon and 4 or 0

    castBar:ClearAllPoints()
    castBar:SetFrameStrata(frame:GetFrameStrata())
    castBar:SetFrameLevel(math.max(frame:GetFrameLevel() + 5, (frame.Elements.HealthBar and frame.Elements.HealthBar:GetFrameLevel() + 1) or (frame:GetFrameLevel() + 5)))
    castBar:SetStatusBarTexture(options.castTexture)
    CastBar.ApplyStateColor(
        castBar,
        castBar.interruptState,
        options.castBarColor,
        options.castBarInterruptibleColor or options.castBarUninterruptibleColor
    )

    if castBar.bg then
        castBar.bg:SetTexture(options.castTexture)
        castBar.bg:SetVertexColor(0, 0, 0, 0.35)
    end

    castBar:SetPoint(
        options.castBarPoint,
        frame,
        options.castBarRelativePoint,
        options.castBarOffsetX + options.borderInset + castBarIconSize + castBarIconGap,
        options.castBarOffsetY
    )
    castBar:SetWidth(math.max(options.width - (options.borderInset * 2) - castBarIconSize - castBarIconGap, 20))
    castBar:SetHeight(castBarHeight)

    if castBar.icon then
        castBar.icon:ClearAllPoints()
        castBar.icon:SetSize(castBarHeight, castBarHeight)
        castBar.icon:SetPoint("CENTER", castBar, "LEFT", -((castBarHeight / 2) + castBarIconGap), 0)
        if not showCastBarIcon or not castBar.isCasting then
            castBar.icon:SetTexture(nil)
            castBar.icon:Hide()
        end
    end

    if not showCastBar or not castBar.isCasting then
        castBar:Hide()
    end
end
