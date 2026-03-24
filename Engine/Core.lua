local _, FocalPoint = ...

function FocalPoint:Init()
    self.frames = self.frames or {}
    self.framesUnlocked = self.framesUnlocked == true
    self:Info("Focal Point loaded.")
end

function FocalPoint:CreatePositionController()
    if self.positionController then
        return self.positionController
    end

    local frame = CreateFrame("Frame", "FocalPointPositionController", UIParent)
    frame:Hide()

    self.positionController = frame
    return frame
end

local function EnsureMoveOverlay(frame)
    if not frame then
        return nil
    end

    if frame.MoveOverlay then
        return frame.MoveOverlay
    end

    local overlay = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    overlay:SetAllPoints(frame)
    overlay:SetFrameStrata(frame:GetFrameStrata())
    overlay:SetFrameLevel(frame:GetFrameLevel() + 40)
    overlay:EnableMouse(false)
    overlay:Hide()
    overlay:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 2,
        insets = { left = 0, right = 0, top = 0, bottom = 0 },
    })
    overlay:SetBackdropColor(0.98, 0.84, 0.24, 0.08)
    overlay:SetBackdropBorderColor(0.98, 0.84, 0.24, 0.95)

    local label = overlay:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    label:SetPoint("CENTER", overlay, "CENTER", 0, 6)
    label:SetFont(STANDARD_TEXT_FONT, 14, "OUTLINE")
    label:SetText("DRAG")
    label:SetTextColor(0.98, 0.84, 0.24, 0.95)
    overlay.Label = label

    local coords = overlay:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    coords:SetPoint("TOPLEFT", overlay, "TOPLEFT", 6, -6)
    coords:SetFont(STANDARD_TEXT_FONT, 14, "OUTLINE")
    coords:SetText("X: 0  Y: 0")
    coords:SetTextColor(0.35, 1.00, 0.45, 0.95)
    if coords.SetJustifyH then
        coords:SetJustifyH("LEFT")
    end
    overlay.Coords = coords

    frame.MoveOverlay = overlay
    return overlay
end

local function GetFrameCenterOffsets(frame)
    if not frame then
        return 0, 0
    end

    if frame.GetCenter and UIParent and UIParent.GetCenter then
        local frameCenterX, frameCenterY = frame:GetCenter()
        local parentCenterX, parentCenterY = UIParent:GetCenter()
        local parentScale = UIParent.GetEffectiveScale and UIParent:GetEffectiveScale() or 1
        local frameScale = frame.GetEffectiveScale and frame:GetEffectiveScale() or 1

        if frameCenterX and frameCenterY and parentCenterX and parentCenterY and parentScale ~= 0 then
            return
                (frameCenterX - parentCenterX) * (frameScale / parentScale),
                (frameCenterY - parentCenterY) * (frameScale / parentScale)
        end
    end

    if frame.GetPoint then
        local _, _, _, pointX, pointY = frame:GetPoint(1)
        return tonumber(pointX) or 0, tonumber(pointY) or 0
    end

    return 0, 0
end

local function UpdateMoveOverlay(frame)
    if not frame or not frame.MoveOverlay or not frame.MoveOverlay.Coords then
        return
    end

    local x, y = GetFrameCenterOffsets(frame)

    x = math.floor((tonumber(x) or 0) + 0.5)
    y = math.floor((tonumber(y) or 0) + 0.5)
    frame.MoveOverlay.Coords:SetText(string.format("X: %d  Y: %d", x, y))
end

local function SaveFramePosition(frame)
    if not frame or not frame.unit then
        return
    end

    local unitConfig = FocalPoint.db
        and FocalPoint.db.profile
        and FocalPoint.db.profile.Units
        and FocalPoint.db.profile.Units[frame.unit]
    if not unitConfig then
        return
    end

    local x, y = GetFrameCenterOffsets(frame)

    unitConfig.point = "CENTER"
    unitConfig.relativePoint = "CENTER"
    unitConfig.relativeTo = "UIParent"
    unitConfig.x = x
    unitConfig.y = y
end

function FocalPoint:ApplyStoredFramePosition(frame)
    if not frame or not frame.unit then
        return
    end

    local unitConfig = self.db
        and self.db.profile
        and self.db.profile.Units
        and self.db.profile.Units[frame.unit]
    if not unitConfig then
        return
    end

    local relativeTo = _G[unitConfig.relativeTo or "UIParent"] or UIParent
    local point = unitConfig.point or "CENTER"
    local relativePoint = unitConfig.relativePoint or "CENTER"
    local x = unitConfig.x or 0
    local y = unitConfig.y or 0

    local relativeScale = relativeTo.GetEffectiveScale and relativeTo:GetEffectiveScale() or 1
    local frameScale = frame.GetEffectiveScale and frame:GetEffectiveScale() or 1
    local adjustedX = x * (relativeScale / frameScale)
    local adjustedY = y * (relativeScale / frameScale)

    frame:ClearAllPoints()
    frame:SetPoint(point, relativeTo, relativePoint, adjustedX, adjustedY)
end

local function BeginFrameDrag(frame)
    if not frame or not frame.unit then
        return
    end

    local unitConfig = FocalPoint.db
        and FocalPoint.db.profile
        and FocalPoint.db.profile.Units
        and FocalPoint.db.profile.Units[frame.unit]
    if not unitConfig then
        return
    end

    local scale = UIParent and UIParent.GetEffectiveScale and UIParent:GetEffectiveScale() or 1
    local cursorX, cursorY = GetCursorPosition()

    local startX, startY = GetFrameCenterOffsets(frame)
    unitConfig.point = "CENTER"
    unitConfig.relativePoint = "CENTER"
    unitConfig.relativeTo = "UIParent"
    unitConfig.x = startX
    unitConfig.y = startY

    frame._focalPointDragState = {
        cursorX = (cursorX or 0) / scale,
        cursorY = (cursorY or 0) / scale,
        startX = tonumber(startX) or 0,
        startY = tonumber(startY) or 0,
    }

    frame:SetScript("OnUpdate", function(movingFrame)
        local dragState = movingFrame._focalPointDragState
        if not dragState then
            return
        end

        local currentX, currentY = GetCursorPosition()
        currentX = (currentX or 0) / scale
        currentY = (currentY or 0) / scale

        unitConfig.x = dragState.startX + (currentX - dragState.cursorX)
        unitConfig.y = dragState.startY + (currentY - dragState.cursorY)
        FocalPoint:ApplyStoredFramePosition(movingFrame)
        UpdateMoveOverlay(movingFrame)
    end)
end

local function EndFrameDrag(frame)
    if not frame then
        return
    end

    frame._focalPointDragState = nil
    frame:SetScript("OnUpdate", nil)
    SaveFramePosition(frame)
    FocalPoint:ApplyStoredFramePosition(frame)
    UpdateMoveOverlay(frame)
end

function FocalPoint:UpdateFrameDragState(frame)
    if not frame then
        return
    end

    local overlay = EnsureMoveOverlay(frame)
    frame:SetMovable(self.framesUnlocked == true)
    frame:SetClampedToScreen(true)

    if self.framesUnlocked then
        if overlay then
            overlay:SetFrameStrata(frame:GetFrameStrata())
            overlay:SetFrameLevel(math.max(frame:GetFrameLevel() + 40, (frame.Elements and frame.Elements.HealthBar and frame.Elements.HealthBar:GetFrameLevel() + 20) or (frame:GetFrameLevel() + 40)))
            overlay:EnableMouse(true)
            overlay:RegisterForDrag("LeftButton")
            overlay:SetScript("OnDragStart", function()
                if not FocalPoint.framesUnlocked then
                    return
                end

                BeginFrameDrag(frame)
            end)
            overlay:SetScript("OnDragStop", function()
                EndFrameDrag(frame)
            end)
            overlay:Show()
            UpdateMoveOverlay(frame)
        end
        frame:RegisterForDrag("LeftButton")
        frame:SetScript("OnDragStart", function(target)
            if not FocalPoint.framesUnlocked then
                return
            end

            BeginFrameDrag(target)
        end)
        frame:SetScript("OnDragStop", function(target)
            EndFrameDrag(target)
        end)
    else
        if overlay then
            overlay:RegisterForDrag()
            overlay:SetScript("OnDragStart", nil)
            overlay:SetScript("OnDragStop", nil)
            overlay:EnableMouse(false)
            overlay:Hide()
        end
        frame:RegisterForDrag()
        frame:SetScript("OnDragStart", nil)
        frame:SetScript("OnDragStop", nil)
        frame:SetScript("OnUpdate", nil)
        frame._focalPointDragState = nil
    end
end

function FocalPoint:UpdateAllFrameDragStates()
    if not self.frames then
        return
    end

    for _, frame in pairs(self.frames) do
        self:UpdateFrameDragState(frame)
    end
end

function FocalPoint:ClearAllMoveOverlays()
    if not self.frames then
        return
    end

    for _, frame in pairs(self.frames) do
        if frame then
            frame._focalPointDragState = nil
            frame:SetScript("OnUpdate", nil)
            frame:RegisterForDrag()
            frame:SetScript("OnDragStart", nil)
            frame:SetScript("OnDragStop", nil)

            local overlay = frame.MoveOverlay
            if overlay then
                overlay:RegisterForDrag()
                overlay:SetScript("OnDragStart", nil)
                overlay:SetScript("OnDragStop", nil)
                overlay:EnableMouse(false)
                overlay:Hide()
            end
        end
    end
end

function FocalPoint:ToggleFrameLock()
    self.framesUnlocked = not self.framesUnlocked

    if self.framesUnlocked and self.SpawnUnitFrame then
        local unitOrder = self.Constants and self.Constants.UnitOrder or {}

        for _, unit in ipairs(unitOrder) do
            local config = self.db
                and self.db.profile
                and self.db.profile.Units
                and self.db.profile.Units[unit]

            if type(config) == "table" and config.enabled ~= false and not self.frames[unit] then
                self:SpawnUnitFrame(unit)
            end
        end
    end

    if self.framesUnlocked then
        if self.RefreshAllFrames then
            self:RefreshAllFrames()
        end
        self:UpdateAllFrameDragStates()
        self:Info("Unit frames unlocked. Drag with left mouse button.")
    else
        self:ClearAllMoveOverlays()
        self:UpdateAllFrameDragStates()
        if self.RefreshAllFrames then
            self:RefreshAllFrames()
        end
        self:Info("Unit frames locked.")
    end
end

function FocalPoint:StartTagTicker()
    if self.tagTicker then
        return
    end

    local interval = self.TAG_UPDATE_INTERVAL or 0.25
    local elapsed = 0

    local frame = CreateFrame("Frame")
    frame:SetScript("OnUpdate", function(_, dt)
        elapsed = elapsed + dt
        if elapsed >= interval then
            elapsed = 0
            if FocalPoint.UpdateAllTags then
                FocalPoint:UpdateAllTags()
            end
        end
    end)

    self.tagTicker = frame
end

function FocalPoint:UpdateAllTags()
    if not self.frames or not self.UnitFrame then
        return
    end

    for _, frame in pairs(self.frames) do
        if frame and frame:IsShown() then
            if self.UnitFrame.RefreshLiveValues then
                self.UnitFrame:RefreshLiveValues(frame)
            end

            if self.UnitFrame.ApplyRangeFade then
                self.UnitFrame:ApplyRangeFade(frame)
            end

            if self.UnitFrame.UpdateTextElements then
                self.UnitFrame:UpdateTextElements(frame)
            end
        end
    end
end

function FocalPoint:RefreshAllFrames()
    if not self.frames then
        return
    end

    for unit, frame in pairs(self.frames) do
        if frame then
            self:RefreshUnitFrame(unit)
        end
    end
end
