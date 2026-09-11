local _, FocalPoint = ...

FocalPoint.UnitFramePortrait = FocalPoint.UnitFramePortrait or {}
local Portrait = FocalPoint.UnitFramePortrait
local RuntimeActivity = FocalPoint.UnitFrameRuntimeActivity or {}
local State = FocalPoint.UnitFrameState or {}
local VisualPolicy = FocalPoint.EditorVisualPolicy or {}

local function IsSelectionPreview(frame)
    return VisualPolicy.IsSelectionPreview and VisualPolicy.IsSelectionPreview(frame, {
        kind = "indicator",
        unit = frame and frame._fpUnit,
        indicatorKey = "Portrait",
        objectKey = "Portrait",
    }) == true
end

-- Portrait helpers encapsulate creation, texture refresh, and portrait-specific
-- event registration without pulling in the full unit-frame runtime.

function Portrait.Create(frame)
    local portraitHolder = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    if portraitHolder and portraitHolder.SetBackdrop then
        portraitHolder:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Buttons\\WHITE8X8",
            edgeSize = 1,
            insets = { left = 0, right = 0, top = 0, bottom = 0 },
        })
    end

    local portraitTexture = portraitHolder:CreateTexture(nil, "ARTWORK")
    portraitTexture:SetAllPoints()
    portraitTexture:SetTexCoord(0.07, 0.93, 0.07, 0.93)

    portraitHolder.Texture = portraitTexture

    frame.Elements.Portrait = portraitHolder
    frame.Portrait = portraitHolder
end

function Portrait.UpdateTexture(frame)
    if not frame or not frame.Elements or not frame.Elements.Portrait then
        return
    end

    local portrait = frame.Elements.Portrait
    local texture = portrait.Texture
    local config = frame.config
    local portraitConfig = config and config.Portrait or nil

    if not texture then
        return
    end

    if RuntimeActivity.ShouldRunTableComponent and not RuntimeActivity.ShouldRunTableComponent(frame, "Portrait") then
        texture:SetTexture(nil)
        texture:Hide()
        return
    end

    if not portraitConfig or portraitConfig.present ~= true or (portraitConfig.enabled == false and not IsSelectionPreview(frame)) then
        texture:SetTexture(nil)
        texture:Hide()
        return
    end

    texture:SetTexCoord(0.07, 0.93, 0.07, 0.93)

    if frame._fpUnit and UnitExists(frame._fpUnit) then
        SetPortraitTexture(texture, frame._fpUnit)
    else
        texture:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
    end

    texture:Show()
end

function Portrait.RegisterEvents(frame)
    if not frame or frame.PortraitEventFrame then
        return
    end

    local eventFrame = CreateFrame("Frame", nil, frame)
    eventFrame.owner = frame

    eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    eventFrame:RegisterEvent("PORTRAITS_UPDATED")
    eventFrame:RegisterEvent("UNIT_PORTRAIT_UPDATE")
    eventFrame:RegisterEvent("UNIT_MODEL_CHANGED")

    if frame._fpUnit == "target" then
        eventFrame:RegisterEvent("PLAYER_TARGET_CHANGED")
    elseif frame._fpUnit == "targettarget" then
        eventFrame:RegisterEvent("PLAYER_TARGET_CHANGED")
        eventFrame:RegisterEvent("UNIT_TARGET")
    elseif frame._fpUnit == "focustarget" then
        eventFrame:RegisterEvent("PLAYER_FOCUS_CHANGED")
        eventFrame:RegisterEvent("UNIT_TARGET")
    end

    eventFrame:SetScript("OnEvent", function(_, event, unit)
        local owner = eventFrame.owner
        if not owner or not owner:IsShown() then
            return
        end

        if event == "UNIT_PORTRAIT_UPDATE" or event == "UNIT_MODEL_CHANGED" then
            if unit ~= owner._fpUnit then
                return
            end
        end

        if event == "UNIT_TARGET" then
            local targetOk = owner._fpUnit == "targettarget" and unit == "target"
            local focusOk = owner._fpUnit == "focustarget" and unit == "focus"
            if not targetOk and not focusOk then
                return
            end
        end

        if State.QueueRefresh then
            State.QueueRefresh(owner, event, "layout")
        else
            C_Timer.After(0, function()
                if owner and owner:IsShown() then
                    Portrait.UpdateTexture(owner)
                end
            end)
        end
    end)

    frame.PortraitEventFrame = eventFrame
end

function Portrait.ApplyLayout(owner, frame, options)
    if not frame or not frame.Elements or not frame.Elements.Portrait then
        return
    end

    local portrait = frame.Elements.Portrait
    portrait:ClearAllPoints()
    portrait:SetScale(1)

    if options.portraitEnabled then
        portrait:SetBackdropColor(0.05, 0.05, 0.05, 0.9)
        portrait:SetBackdropBorderColor(options.borderR, options.borderG, options.borderB, options.borderA)
        portrait:SetSize(options.portraitEffectiveSize, options.portraitEffectiveSize)

        if options.portraitInside then
            if options.portraitInsideSide == "RIGHT" then
                portrait:SetPoint("RIGHT", frame, "RIGHT", -options.borderInset, 0)
            else
                portrait:SetPoint("LEFT", frame, "LEFT", options.borderInset, 0)
            end
        else
            local portraitAnchorParent = owner:GetAnchorTarget(frame, options.portraitAnchorTo) or frame
            portrait:SetPoint(
                options.portraitPoint,
                portraitAnchorParent,
                options.portraitRelativePoint,
                options.portraitOffsetX,
                options.portraitOffsetY
            )
        end

        owner:UpdatePortraitTexture(frame)
        portrait:Show()
    else
        if portrait.Texture then
            portrait.Texture:SetTexture(nil)
            portrait.Texture:Hide()
        end
        portrait:Hide()
    end
end
