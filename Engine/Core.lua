local _, FocalPoint = ...

local function GetUnitConfig(unit)
    if type(unit) == "string" and unit:match("^boss%d+$") then
        unit = "boss"
    end

    local utils = FocalPoint.UnitFrameUtils
    if utils and utils.GetUnitDB then
        return utils.GetUnitDB(unit)
    end

    return FocalPoint.db
        and FocalPoint.db.profile
        and FocalPoint.db.profile.Units
        and FocalPoint.db.profile.Units[unit]
end

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
        edgeSize = 1,
        insets = { left = 0, right = 0, top = 0, bottom = 0 },
    })
    overlay:SetBackdropColor(0, 0, 0, 0)
    overlay:SetBackdropBorderColor(0, 0, 0, 0)

    local coords = overlay:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    coords:SetPoint("TOPLEFT", overlay, "TOPLEFT", 6, -6)
    coords:SetFont(STANDARD_TEXT_FONT, 14, "OUTLINE")
    coords:SetText("X: 0  Y: 0")
    coords:SetTextColor(0.35, 1.00, 0.45, 0.95)
    coords:Hide()
    if coords.SetJustifyH then
        coords:SetJustifyH("LEFT")
    end
    overlay.Coords = coords

    local accent = overlay:CreateTexture(nil, "ARTWORK")
    accent:SetPoint("TOPLEFT", overlay, "TOPLEFT", 1, -1)
    accent:SetPoint("TOPRIGHT", overlay, "TOPRIGHT", -1, -1)
    accent:SetHeight(2)
    accent:SetColorTexture(0.78, 0.65, 0.24, 0.42)
    accent:Hide()
    overlay.Accent = accent

    local placeholderLabel = overlay:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    placeholderLabel:SetPoint("CENTER", overlay, "CENTER", 0, 0)
    placeholderLabel:SetFont(STANDARD_TEXT_FONT, 14, "")
    placeholderLabel:SetTextColor(0.93, 0.94, 0.96, 0.96)
    if placeholderLabel.SetJustifyH then
        placeholderLabel:SetJustifyH("CENTER")
    end
    placeholderLabel:SetShadowOffset(1, -1)
    placeholderLabel:SetShadowColor(0, 0, 0, 0.75)
    placeholderLabel:Hide()
    overlay.PlaceholderLabel = placeholderLabel

    frame.MoveOverlay = overlay
    return overlay
end

local function EnsureSelectionOverlay(frame)
    if not frame then
        return nil
    end

    if frame.SelectionOverlay then
        return frame.SelectionOverlay
    end

    local overlay = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    overlay:SetAllPoints(frame)
    overlay:SetFrameStrata(frame:GetFrameStrata())
    overlay:SetFrameLevel(frame:GetFrameLevel() + 30)
    overlay:EnableMouse(false)
    overlay:Hide()
    overlay:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 3,
        insets = { left = 0, right = 0, top = 0, bottom = 0 },
    })
    overlay:SetBackdropColor(0.98, 0.84, 0.24, 0.14)
    overlay:SetBackdropBorderColor(0.98, 0.84, 0.24, 1.00)

    frame.SelectionOverlay = overlay
    return overlay
end

local function IsSelectedEditorFrame(frame)
    if not frame or not frame.unit or not FocalPoint.IsEditorActive or not FocalPoint:IsEditorActive() then
        return false
    end

    local editorState = FocalPoint.GUI and FocalPoint.GUI.Editor and FocalPoint.GUI.Editor.State
    local state = editorState and editorState.Get and editorState.Get() or nil
    local selectedUnit = state and state.selectedUnit
    if type(selectedUnit) ~= "string" or selectedUnit == "" then
        return false
    end

    if selectedUnit == "boss" then
        return frame.unit:match("^boss%d+$") ~= nil
    end

    return frame.unit == selectedUnit
end

local function UpdateSelectionOverlay(frame)
    if not frame then
        return
    end

    local overlay = EnsureSelectionOverlay(frame)
    if not overlay then
        return
    end

    overlay:SetFrameStrata(frame:GetFrameStrata())
    overlay:SetFrameLevel(math.max(frame:GetFrameLevel() + 30, (frame.MoveOverlay and frame.MoveOverlay:GetFrameLevel() - 5) or (frame:GetFrameLevel() + 30)))

    if IsSelectedEditorFrame(frame) then
        overlay:Show()
    else
        overlay:Hide()
    end
end

local function UpdateMoveOverlayVisuals(frame)
    if not frame or not frame.MoveOverlay then
        return
    end

    local overlay = frame.MoveOverlay
    local coords = overlay.Coords
    local accent = overlay.Accent
    local placeholderLabel = overlay.PlaceholderLabel
    local isSelected = IsSelectedEditorFrame(frame)
    local isDragging = frame._focalPointDragState ~= nil
    local isPlaceholder = FocalPoint.framesUnlocked
        and not FocalPoint.guiTestModeEnabled
        and FocalPoint.IsEditorActive
        and FocalPoint:IsEditorActive()
        and not isSelected
        and not isDragging

    local preview = FocalPoint.UnitFramePreview and FocalPoint.UnitFramePreview.GetTestValues and FocalPoint.UnitFramePreview.GetTestValues(frame) or nil
    local placeholderName = preview and preview.name or (frame.unit or "")
    local unitConfig = GetUnitConfig(frame.unit)
    local isEnabled = type(unitConfig) ~= "table" or unitConfig.enabled ~= false

    if isPlaceholder then
        if isEnabled then
            overlay:SetBackdropColor(0.05, 0.06, 0.08, 0.72)
            overlay:SetBackdropBorderColor(0.22, 0.25, 0.31, 0.82)
        else
            overlay:SetBackdropColor(0.05, 0.06, 0.08, 0.18)
            overlay:SetBackdropBorderColor(0.22, 0.25, 0.31, 0.24)
        end
        if accent then
            if isEnabled then
                accent:SetColorTexture(0.78, 0.65, 0.24, 0.42)
            else
                accent:SetColorTexture(0.78, 0.65, 0.24, 0.10)
            end
            accent:Show()
        end
        if placeholderLabel then
            placeholderLabel:SetText(placeholderName)
            if isEnabled then
                placeholderLabel:SetTextColor(0.93, 0.94, 0.96, 0.96)
            else
                placeholderLabel:SetTextColor(0.82, 0.84, 0.88, 0.38)
            end
            placeholderLabel:Show()
        end
    else
        overlay:SetBackdropColor(0, 0, 0, 0)
        overlay:SetBackdropBorderColor(0, 0, 0, 0)
        if accent then
            accent:Hide()
        end
        if placeholderLabel then
            placeholderLabel:Hide()
        end
    end

    if coords then
        if (isSelected and FocalPoint.framesUnlocked) or isDragging then
            coords:Show()
        else
            coords:Hide()
        end
    end
end

local function EnsureEditorSelectionHooks(frame)
    if not frame or frame._focalPointEditorSelectHooked then
        return
    end

    local function HandleSelection()
        if not FocalPoint.IsEditorActive or not FocalPoint:IsEditorActive() then
            return
        end

        if FocalPoint.SelectEditorUnit and frame.unit then
            FocalPoint:SelectEditorUnit(frame.unit)
        end
    end

    if frame.HookScript then
        frame:HookScript("OnMouseUp", function(_, button)
            if button == "LeftButton" then
                HandleSelection()
            end
        end)
    end

    local overlay = EnsureMoveOverlay(frame)
    if overlay and overlay.HookScript then
        overlay:HookScript("OnMouseUp", function(_, button)
            if button == "LeftButton" then
                HandleSelection()
            end
        end)
    end

    frame._focalPointEditorSelectHooked = true
end

local UpdateMoveOverlay

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

local function GetBossStackOffset(frame, unitConfig)
    if not frame or not frame.unit then
        return 0
    end

    local utils = FocalPoint.UnitFrameUtils
    local bossIndex = utils and utils.GetBossFrameIndex and utils.GetBossFrameIndex(frame.unit)
    if not bossIndex or bossIndex <= 1 then
        return 0
    end

    local height = frame.GetHeight and frame:GetHeight() or 0
    local stackGap = type(unitConfig) == "table" and (tonumber(unitConfig.bossSpacing) or 10) or 10
    return (bossIndex - 1) * ((tonumber(height) or 0) + stackGap)
end

local function ApplyBossStackPositions()
    if not FocalPoint.frames then
        return
    end

    for bossIndex = 1, 5 do
        local bossUnit = "boss" .. bossIndex
        local bossFrame = FocalPoint.frames[bossUnit]
        if bossFrame then
            FocalPoint:ApplyStoredFramePosition(bossFrame)
            UpdateMoveOverlay(bossFrame)
        end
    end
end

UpdateMoveOverlay = function(frame)
    if not frame or not frame.MoveOverlay or not frame.MoveOverlay.Coords then
        return
    end

    local x, y = GetFrameCenterOffsets(frame)

    x = math.floor((tonumber(x) or 0) + 0.5)
    y = math.floor((tonumber(y) or 0) + 0.5)
    frame.MoveOverlay.Coords:SetText(string.format("X: %d  Y: %d", x, y))
    UpdateMoveOverlayVisuals(frame)
end

local function SaveFramePosition(frame)
    if not frame or not frame.unit then
        return
    end

    local unitConfig = GetUnitConfig(frame.unit)
    if not unitConfig then
        return
    end

    local x, y = GetFrameCenterOffsets(frame)
    local bossStackOffset = GetBossStackOffset(frame, unitConfig)

    unitConfig.point = "CENTER"
    unitConfig.relativePoint = "CENTER"
    unitConfig.relativeTo = "UIParent"
    unitConfig.x = x
    unitConfig.y = y + bossStackOffset
end

function FocalPoint:ApplyStoredFramePosition(frame)
    if not frame or not frame.unit then
        return
    end

    local unitConfig = GetUnitConfig(frame.unit)
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
    local bossStackOffset = GetBossStackOffset(frame, unitConfig)
    if bossStackOffset ~= 0 then
        adjustedY = adjustedY - (bossStackOffset * (relativeScale / frameScale))
    end

    frame:ClearAllPoints()
    frame:SetPoint(point, relativeTo, relativePoint, adjustedX, adjustedY)
end

local function BeginFrameDrag(frame)
    if not frame or not frame.unit then
        return
    end

    local unitConfig = GetUnitConfig(frame.unit)
    if not unitConfig then
        return
    end

    local scale = UIParent and UIParent.GetEffectiveScale and UIParent:GetEffectiveScale() or 1
    local cursorX, cursorY = GetCursorPosition()

    local startX, startY = GetFrameCenterOffsets(frame)
    local bossStackOffset = GetBossStackOffset(frame, unitConfig)
    if bossStackOffset ~= 0 then
        startY = startY + bossStackOffset
    end
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
        if movingFrame.unit and movingFrame.unit:match("^boss%d+$") then
            ApplyBossStackPositions()
        else
            FocalPoint:ApplyStoredFramePosition(movingFrame)
            UpdateMoveOverlay(movingFrame)
        end
    end)

    UpdateMoveOverlayVisuals(frame)
end

local function EndFrameDrag(frame)
    if not frame then
        return
    end

    frame._focalPointDragState = nil
    frame:SetScript("OnUpdate", nil)
    SaveFramePosition(frame)
    if frame.unit and frame.unit:match("^boss%d+$") then
        ApplyBossStackPositions()
    else
        FocalPoint:ApplyStoredFramePosition(frame)
        UpdateMoveOverlay(frame)
    end

    UpdateMoveOverlayVisuals(frame)
end

function FocalPoint:UpdateFrameDragState(frame)
    if not frame then
        return
    end

    EnsureEditorSelectionHooks(frame)

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

    UpdateSelectionOverlay(frame)
    UpdateMoveOverlayVisuals(frame)
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

            local selectionOverlay = frame.SelectionOverlay
            if selectionOverlay then
                selectionOverlay:Hide()
            end
        end
    end
end

function FocalPoint:RefreshEditorSelectionVisuals()
    if not self.frames then
        return
    end

    for _, frame in pairs(self.frames) do
        UpdateSelectionOverlay(frame)
        UpdateMoveOverlayVisuals(frame)
    end
end

function FocalPoint:ToggleFrameLock()
    self.framesUnlocked = not self.framesUnlocked

    if self.framesUnlocked and self.SpawnUnitFrame then
        local unitOrder = self.Constants and self.Constants.UnitOrder or {}

        for _, unit in ipairs(unitOrder) do
            local config = GetUnitConfig(unit)

            if unit == "boss" then
                if type(config) == "table" and config.enabled ~= false then
                    for bossIndex = 1, 5 do
                        local bossUnit = "boss" .. bossIndex
                        if not self.frames[bossUnit] then
                            self:SpawnUnitFrame(bossUnit)
                        end
                    end
                end
            elseif type(config) == "table" and config.enabled ~= false and not self.frames[unit] then
                self:SpawnUnitFrame(unit)
            end
        end
    end

    if self.framesUnlocked then
        if self.RefreshAllFrames then
            self:RefreshAllFrames()
        end
        self:UpdateAllFrameDragStates()
        self:RefreshEditorSelectionVisuals()
        if self.GUI and self.GUI.RefreshOptions then
            self.GUI:RefreshOptions()
        end
        self:Info("Unit frames unlocked. Drag with left mouse button.")
    else
        self:ClearAllMoveOverlays()
        self:UpdateAllFrameDragStates()
        self:RefreshEditorSelectionVisuals()
        if self.RefreshAllFrames then
            self:RefreshAllFrames()
        end
        if self.GUI and self.GUI.RefreshOptions then
            self.GUI:RefreshOptions()
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
