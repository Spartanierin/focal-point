local _, FocalPoint = ...

FocalPoint.UnitFrameLeader = FocalPoint.UnitFrameLeader or {}
local Leader = FocalPoint.UnitFrameLeader

local Presence = FocalPoint.UnitFramePresence or {}
local Preview = FocalPoint.UnitFramePreview or {}
local Indicators = FocalPoint.UnitFrameIndicators or {}
local State = FocalPoint.UnitFrameState or {}

local IsPreviewModeEnabled = Presence.IsPreviewModeEnabled
local IsPreviewIndicatorVisible = Preview.IsIndicatorVisible
local HandleVisibilityTransition = Indicators.HandleVisibilityTransition

-- Leader icon runtime keeps the leader-state evaluation and event wiring
-- isolated from the rest of the indicator logic.

function Leader.Update(owner, frame)
    if not frame or not frame.Elements or not frame.Elements.LeaderIcon then
        return
    end

    local holder = frame.Elements.LeaderIcon
    local icon = holder.Texture or holder
    local config = frame.config
    local leaderConfig = config and config.LeaderIcon or nil

    if Preview.ShouldShowComponent and Preview.ShouldShowComponent("indicators", { frame = frame }) == false then
        HandleVisibilityTransition(owner, frame, holder, false, "_leaderLayoutRefreshQueued")
        return
    end

    if not leaderConfig or leaderConfig.enabled == false then
        HandleVisibilityTransition(owner, frame, holder, false, "_leaderLayoutRefreshQueued")
        return
    end

    local isLeader = false

    if IsPreviewModeEnabled() then
        isLeader = IsPreviewIndicatorVisible(frame, "leader")
    end

    if not isLeader and frame.unit and UnitExists and UnitExists(frame.unit) then
        if UnitLeadsAnyGroup then
            isLeader = UnitLeadsAnyGroup(frame.unit) and true or false
        elseif UnitIsGroupLeader then
            isLeader = UnitIsGroupLeader(frame.unit) and true or false
        end
    end

    if not isLeader then
        HandleVisibilityTransition(owner, frame, holder, false, "_leaderLayoutRefreshQueued")
        return
    end

    if IsPreviewModeEnabled() then
        icon:SetTexture("Interface\\GroupFrame\\UI-Group-LeaderIcon")
        icon:SetTexCoord(0, 1, 0, 1)
    else
        icon:SetAtlas("UI-HUD-UnitFrame-Player-Group-LeaderIcon", true)
    end
    HandleVisibilityTransition(owner, frame, holder, true, "_leaderLayoutRefreshQueued")
end

function Leader.RegisterEvents(owner, frame)
    if not frame or frame.LeaderIconEventFrame then
        return
    end

    local eventFrame = CreateFrame("Frame", nil, frame)
    eventFrame.owner = frame

    eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    eventFrame:RegisterEvent("GROUP_ROSTER_UPDATE")
    eventFrame:RegisterEvent("PARTY_LEADER_CHANGED")
    eventFrame:RegisterEvent("PLAYER_ROLES_ASSIGNED")

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

    eventFrame:SetScript("OnEvent", function(_, event, unit)
        local currentOwner = eventFrame.owner
        if not currentOwner or not currentOwner:IsShown() then
            return
        end

        if event == "UNIT_PET" and unit ~= "player" then
            return
        end

        if event == "UNIT_TARGET" then
            local targetOk = currentOwner.unit == "targettarget" and unit == "target"
            local focusOk = currentOwner.unit == "focustarget" and unit == "focus"
            if not targetOk and not focusOk then
                return
            end
        end

        if State.QueueRefresh then
            State.QueueRefresh(currentOwner, event, "layout")
        else
            C_Timer.After(0, function()
                if currentOwner and currentOwner:IsShown() then
                    owner:UpdateLeaderIcon(currentOwner)
                end
            end)
        end
    end)

    frame.LeaderIconEventFrame = eventFrame
end
