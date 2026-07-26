local _, FocalPoint = ...

FocalPoint.UnitFrameRaidTarget = FocalPoint.UnitFrameRaidTarget or {}
local RaidTarget = FocalPoint.UnitFrameRaidTarget

local Presence = FocalPoint.UnitFramePresence or {}
local Preview = FocalPoint.UnitFramePreview or {}
local State = FocalPoint.UnitFrameState or {}
local InsideLayout = FocalPoint.UnitFrameInsideLayout or {}

local IsPreviewModeEnabled = Presence.IsPreviewModeEnabled
local IsPreviewIndicatorVisible = Preview.IsIndicatorVisible
local GetPreviewRaidTargetIndex = Preview.GetRaidTargetIndex
local ResolveInsideAnchor = InsideLayout.ResolveAnchor

local function QueueLayoutRefresh(owner, frame)
    if not owner or not frame or frame._raidTargetLayoutRefreshQueued then
        return
    end

    frame._raidTargetLayoutRefreshQueued = true
    if State.QueueRefresh then
        State.QueueRefresh(frame, "raid_target_layout", "layout")
        C_Timer.After(0.01, function()
            if frame then
                frame._raidTargetLayoutRefreshQueued = nil
            end
        end)
        return
    end

    C_Timer.After(0, function()
        if frame then
            frame._raidTargetLayoutRefreshQueued = nil
        end
        if owner and frame and frame.config and owner.ApplyConfig then
            owner:ApplyConfig(frame)
        end
    end)
end

-- Raid target marker uses a dedicated overlay frame so it can sit reliably
-- above the unit bars even when frame levels change.

function RaidTarget.Create(frame)
    local holder = CreateFrame("Frame", nil, frame)
    holder:SetAllPoints(frame)
    holder:SetFrameStrata(frame:GetFrameStrata())
    holder:SetFrameLevel(frame:GetFrameLevel() + 20)
    holder:Hide()

    local texture = holder:CreateTexture(nil, "OVERLAY", nil, 7)
    texture:SetTexture("Interface\\TargetingFrame\\UI-RaidTargetingIcons")
    texture:Hide()

    holder.Texture = texture
    frame.Elements.RaidTargetIcon = holder
    frame.RaidTargetIcon = holder
end

function RaidTarget.Update(owner, frame)
    if not frame or not frame.Elements or not frame.Elements.RaidTargetIcon then
        return
    end

    local holder = frame.Elements.RaidTargetIcon
    local icon = holder.Texture or holder
    local config = frame.config
    local rtmConfig = config and config.RaidTargetIcon or nil
    local wasShown = holder.IsShown and holder:IsShown() or false

    if Preview.ShouldShowComponent and Preview.ShouldShowComponent("rareEliteRaid", { frame = frame }) == false then
        icon:SetTexture(nil)
        icon:Hide()
        holder:Hide()
        if wasShown then
            QueueLayoutRefresh(owner, frame)
        end
        return
    end

    if not rtmConfig or rtmConfig.enabled == false then
        icon:SetTexture(nil)
        icon:Hide()
        holder:Hide()
        if wasShown then
            QueueLayoutRefresh(owner, frame)
        end
        return
    end

    local index = frame.unit and GetRaidTargetIndex and GetRaidTargetIndex(frame.unit) or nil

    if not index and IsPreviewModeEnabled() and IsPreviewIndicatorVisible(frame, "raidTarget") then
        index = GetPreviewRaidTargetIndex(frame)
    end

    if not index then
        icon:SetTexture(nil)
        icon:Hide()
        holder:Hide()
        if wasShown then
            QueueLayoutRefresh(owner, frame)
        end
        return
    end

    icon:SetTexture("Interface\\TargetingFrame\\UI-RaidTargetingIcons")
    SetRaidTargetIconTexture(icon, index)
    holder:Show()
    icon:Show()
    if not wasShown then
        QueueLayoutRefresh(owner, frame)
    end
end

function RaidTarget.RegisterEvents(owner, frame)
    if not frame or frame.RaidTargetEventFrame then
        return
    end

    local eventFrame = CreateFrame("Frame", nil, frame)
    eventFrame.owner = frame

    eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    eventFrame:RegisterEvent("RAID_TARGET_UPDATE")
    eventFrame:RegisterEvent("GROUP_ROSTER_UPDATE")
    eventFrame:RegisterEvent("UNIT_TARGET")

    if frame.unit == "target" then
        eventFrame:RegisterEvent("PLAYER_TARGET_CHANGED")
    elseif frame.unit == "focus" then
        eventFrame:RegisterEvent("PLAYER_FOCUS_CHANGED")
    elseif frame.unit == "pet" then
        eventFrame:RegisterEvent("UNIT_PET")
    end

    eventFrame:SetScript("OnEvent", function(_, event, unit)
        local currentOwner = eventFrame.owner
        if not currentOwner or not currentOwner:IsShown() then
            return
        end

        if event == "UNIT_TARGET" then
            if currentOwner.unit ~= "targettarget" and currentOwner.unit ~= "focustarget" then
                return
            end

            local expectedUnit = currentOwner.unit == "targettarget" and "target" or "focus"
            if unit ~= expectedUnit then
                return
            end
        elseif event == "UNIT_PET" and unit ~= "player" then
            return
        end

        if State.QueueRefresh then
            State.QueueRefresh(currentOwner, event, "layout")
        else
            C_Timer.After(0, function()
                if currentOwner and currentOwner:IsShown() then
                    owner:UpdateRaidTargetIcon(currentOwner)
                end
            end)
        end
    end)

    frame.RaidTargetEventFrame = eventFrame
end

function RaidTarget.ApplyLayout(owner, frame, options)
    if not frame or not frame.Elements or not frame.Elements.RaidTargetIcon then
        return
    end

    local holder = frame.Elements.RaidTargetIcon
    local icon = holder.Texture or holder

    holder:ClearAllPoints()
    holder:SetScale(1)
    holder:SetFrameStrata(frame:GetFrameStrata())
    holder:SetFrameLevel(math.max(frame:GetFrameLevel() + 20, (frame.Elements.HealthBar and frame.Elements.HealthBar:GetFrameLevel() + 10) or (frame:GetFrameLevel() + 20)))
    icon:ClearAllPoints()
    icon:SetScale(1)

    if options.raidTargetEnabled then
        local effectiveSize = options.raidTargetSize * options.raidTargetScale
        holder:SetSize(effectiveSize, effectiveSize)
        icon:SetAllPoints(holder)

        if options.raidTargetPlacement == "INSIDE" then
            local anchorParent, leftReserve, rightReserve = ResolveInsideAnchor and ResolveInsideAnchor(frame, options.raidTargetInsideAnchorTo or "Frame", options)
            anchorParent = anchorParent or frame
            leftReserve = tonumber(leftReserve) or 0
            rightReserve = tonumber(rightReserve) or 0
            if options.raidTargetInsideSide == "LEFT" then
                holder:SetPoint("TOPLEFT", anchorParent, "TOPLEFT", leftReserve + options.raidTargetPadding, -(options.borderInset or 0))
            else
                holder:SetPoint("TOPRIGHT", anchorParent, "TOPRIGHT", -(rightReserve + options.raidTargetPadding), -(options.borderInset or 0))
            end
        else
            local anchorParent = owner:GetAnchorTarget(frame, options.raidTargetAnchorTo) or frame
            holder:SetPoint(
                options.raidTargetPoint,
                anchorParent,
                options.raidTargetRelativePoint,
                options.raidTargetOffsetX,
                options.raidTargetOffsetY
            )
        end

        owner:UpdateRaidTargetIcon(frame)
    else
        icon:SetTexture(nil)
        icon:Hide()
        holder:Hide()
    end
end
