local _, FocalPoint = ...

FocalPoint.GUI = FocalPoint.GUI or {}
FocalPoint.GUI.Editor = FocalPoint.GUI.Editor or {}

local FrameSnapLines = {}
FocalPoint.GUI.Editor.FrameSnapLines = FrameSnapLines

local SNAP_THRESHOLD = 6
FrameSnapLines.SNAP_THRESHOLD = SNAP_THRESHOLD

local function ResolveColor(color, fallback)
    color = color or fallback or {}

    return {
        color[1] or color.r or fallback and fallback[1] or 1,
        color[2] or color.g or fallback and fallback[2] or 1,
        color[3] or color.b or fallback and fallback[3] or 1,
        color[4] or color.a or fallback and fallback[4] or 1,
    }
end

local function GetLineColor()
    local skins = FocalPoint.GUI and FocalPoint.GUI.Skins
    local color = skins and skins.GetBrandColor and skins.GetBrandColor("orangeStrong") or nil

    color = ResolveColor(color, { 0.918, 0.459, 0.000, 0.85 })
    color[4] = math.max(color[4] or 0, 0.82)
    return color
end

local function IsEditorUnlocked()
    return FocalPoint.framesUnlocked == true
        and FocalPoint.IsEditorActive
        and FocalPoint:IsEditorActive()
end

local function IsCombatLocked()
    return InCombatLockdown and InCombatLockdown()
end

local function IsSnappingEnabled()
    local general = FocalPoint.db and FocalPoint.db.profile and FocalPoint.db.profile.General
    return not (type(general) == "table" and general.SnappingEnabled == false)
end

function FrameSnapLines.IsSnappingEnabled()
    return IsSnappingEnabled()
end

local function GetFrameCenterOffsets(frame)
    if not frame or not frame.GetCenter or not UIParent or not UIParent.GetCenter then
        return nil, nil
    end

    local frameCenterX, frameCenterY = frame:GetCenter()
    local parentCenterX, parentCenterY = UIParent:GetCenter()
    local parentScale = UIParent.GetEffectiveScale and UIParent:GetEffectiveScale() or 1
    local frameScale = frame.GetEffectiveScale and frame:GetEffectiveScale() or 1

    if not frameCenterX or not frameCenterY or not parentCenterX or not parentCenterY or parentScale == 0 then
        return nil, nil
    end

    return
        (frameCenterX - parentCenterX) * (frameScale / parentScale),
        (frameCenterY - parentCenterY) * (frameScale / parentScale)
end

local function GetBossStackOffset(frame)
    if not frame or not frame.unit then
        return 0
    end

    local utils = FocalPoint.UnitFrameUtils
    local bossIndex = utils and utils.GetBossFrameIndex and utils.GetBossFrameIndex(frame.unit)
    if not bossIndex or bossIndex <= 1 then
        return 0
    end

    local unitConfig = utils and utils.GetUnitDB and utils.GetUnitDB(frame.unit) or nil
    local height = frame.GetHeight and frame:GetHeight() or 0
    local stackGap = type(unitConfig) == "table" and (tonumber(unitConfig.bossSpacing) or 10) or 10
    return (bossIndex - 1) * ((tonumber(height) or 0) + stackGap)
end

local function EnsureLine(key, orientation)
    FrameSnapLines.lines = FrameSnapLines.lines or {}
    if FrameSnapLines.lines[key] then
        return FrameSnapLines.lines[key]
    end

    local line = CreateFrame("Frame", nil, UIParent)
    line:SetFrameStrata("FULLSCREEN_DIALOG")
    line:SetFrameLevel(9000)
    line:Hide()

    local shadow = line:CreateTexture(nil, "BORDER")
    shadow:SetAllPoints()
    shadow:SetColorTexture(0, 0, 0, 0.48)
    line.shadow = shadow

    local texture = line:CreateTexture(nil, "ARTWORK")
    texture:SetAllPoints()
    line.texture = texture
    line.orientation = orientation

    FrameSnapLines.lines[key] = line
    return line
end

local function ShowVerticalLine(offset)
    local line = EnsureLine("vertical", "vertical")
    local color = GetLineColor()
    local height = UIParent and UIParent.GetHeight and UIParent:GetHeight() or 1080

    line:ClearAllPoints()
    line:SetSize(2, height)
    line:SetPoint("CENTER", UIParent, "CENTER", offset or 0, 0)
    line.texture:SetColorTexture(color[1], color[2], color[3], color[4])
    line:Show()
end

local function ShowHorizontalLine(offset)
    local line = EnsureLine("horizontal", "horizontal")
    local color = GetLineColor()
    local width = UIParent and UIParent.GetWidth and UIParent:GetWidth() or 1920

    line:ClearAllPoints()
    line:SetSize(width, 2)
    line:SetPoint("CENTER", UIParent, "CENTER", 0, offset or 0)
    line.texture:SetColorTexture(color[1], color[2], color[3], color[4])
    line:Show()
end

local function HideLine(key)
    local line = FrameSnapLines.lines and FrameSnapLines.lines[key] or nil
    if line then
        line:Hide()
    end
end

local function GetBestCandidate(value, candidates)
    local best
    for _, candidate in ipairs(candidates) do
        local distance = math.abs(value - candidate.value)
        if distance <= SNAP_THRESHOLD and (not best or distance < best.distance) then
            best = {
                value = candidate.value,
                guide = candidate.guide,
                distance = distance,
            }
        end
    end
    return best
end

local function AddFrameCandidates(candidatesX, candidatesY, movingFrame)
    if not FocalPoint.frames then
        return
    end

    local movingWidth = movingFrame.GetWidth and movingFrame:GetWidth() or 0
    local movingHeight = movingFrame.GetHeight and movingFrame:GetHeight() or 0

    for _, frame in pairs(FocalPoint.frames) do
        if frame ~= movingFrame
            and frame.IsShown and frame:IsShown()
            and frame.GetCenter and frame.GetWidth and frame.GetHeight
        then
            local centerX, centerY = GetFrameCenterOffsets(frame)
            if centerX and centerY then
                local width = frame:GetWidth() or 0
                local height = frame:GetHeight() or 0
                local left = centerX - (width / 2)
                local right = centerX + (width / 2)
                local top = centerY + (height / 2)
                local bottom = centerY - (height / 2)

                candidatesX[#candidatesX + 1] = { value = centerX, guide = centerX }
                candidatesX[#candidatesX + 1] = { value = left + (movingWidth / 2), guide = left }
                candidatesX[#candidatesX + 1] = { value = right - (movingWidth / 2), guide = right }

                candidatesY[#candidatesY + 1] = { value = centerY, guide = centerY }
                candidatesY[#candidatesY + 1] = { value = top - (movingHeight / 2), guide = top }
                candidatesY[#candidatesY + 1] = { value = bottom + (movingHeight / 2), guide = bottom }
            end
        end
    end
end

function FrameSnapLines.Apply(frame, proposedX, proposedY)
    if not IsEditorUnlocked() or IsCombatLocked() or not frame or not IsSnappingEnabled() then
        FrameSnapLines.Hide()
        return proposedX, proposedY
    end

    proposedX = tonumber(proposedX) or 0
    proposedY = tonumber(proposedY) or 0

    local stackOffset = GetBossStackOffset(frame)
    local visualY = proposedY - stackOffset
    local candidatesX = {
        { value = 0, guide = 0 },
    }
    local candidatesY = {
        { value = 0, guide = 0 },
    }

    AddFrameCandidates(candidatesX, candidatesY, frame)

    local snapX = GetBestCandidate(proposedX, candidatesX)
    local snapY = GetBestCandidate(visualY, candidatesY)

    if snapX then
        proposedX = snapX.value
        ShowVerticalLine(snapX.guide)
    else
        HideLine("vertical")
    end

    if snapY then
        proposedY = snapY.value + stackOffset
        ShowHorizontalLine(snapY.guide)
    else
        HideLine("horizontal")
    end

    return proposedX, proposedY
end

function FrameSnapLines.Hide()
    HideLine("vertical")
    HideLine("horizontal")
end

return FrameSnapLines
