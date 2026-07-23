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

local function NormalizeEditorSelectionUnit(unitKey)
    if type(unitKey) ~= "string" or unitKey == "" then
        return nil
    end

    if unitKey:match("^boss%d+$") then
        return "boss"
    end

    return unitKey
end

local function FrameMatchesSelectionUnit(frame, selectedUnit)
    if not frame or not frame.unit or type(selectedUnit) ~= "string" or selectedUnit == "" then
        return false
    end

    if selectedUnit == "boss" then
        return frame.unit:match("^boss%d+$") ~= nil
    end

    return NormalizeEditorSelectionUnit(frame.unit) == selectedUnit
end

local function IsPrimaryEditorFrame(frame)
    if not frame or not frame.unit or not FocalPoint.IsEditorActive or not FocalPoint:IsEditorActive() then
        return false
    end

    local editorState = FocalPoint.GUI and FocalPoint.GUI.Editor and FocalPoint.GUI.Editor.State
    local state = editorState and editorState.Get and editorState.Get() or nil
    local primaryUnit = editorState and editorState.GetPrimaryUnit and editorState.GetPrimaryUnit() or (state and state.selectedUnit)
    return FrameMatchesSelectionUnit(frame, primaryUnit)
end

local function IsSelectedEditorFrame(frame)
    if not frame or not frame.unit or not FocalPoint.IsEditorActive or not FocalPoint:IsEditorActive() then
        return false
    end

    local editorState = FocalPoint.GUI and FocalPoint.GUI.Editor and FocalPoint.GUI.Editor.State
    if editorState and editorState.IsUnitSelected then
        return editorState.IsUnitSelected(NormalizeEditorSelectionUnit(frame.unit))
    end

    return IsPrimaryEditorFrame(frame)
end

local function IsSecondaryEditorFrame(frame)
    return IsSelectedEditorFrame(frame) and not IsPrimaryEditorFrame(frame)
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
    overlay:SetFrameLevel(math.max(frame:GetFrameLevel() + 45, (frame.MoveOverlay and frame.MoveOverlay:GetFrameLevel() + 5) or (frame:GetFrameLevel() + 45)))

    if IsPrimaryEditorFrame(frame) then
        overlay:SetBackdropColor(0.98, 0.84, 0.24, 0.14)
        overlay:SetBackdropBorderColor(0.98, 0.84, 0.24, 1.00)
        overlay:Show()
    elseif IsSecondaryEditorFrame(frame) then
        overlay:SetBackdropColor(0.98, 0.84, 0.24, 0.04)
        overlay:SetBackdropBorderColor(0.98, 0.84, 0.24, 0.58)
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
    local isSelected = IsPrimaryEditorFrame(frame)
    local isSecondary = IsSecondaryEditorFrame(frame)
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
        if isSecondary then
            if isEnabled then
                overlay:SetBackdropColor(0.18, 0.15, 0.08, 0.94)
                overlay:SetBackdropBorderColor(0.54, 0.43, 0.17, 0.58)
            else
                overlay:SetBackdropColor(0.13, 0.10, 0.05, 0.88)
                overlay:SetBackdropBorderColor(0.54, 0.43, 0.17, 0.34)
            end
        elseif isEnabled then
            overlay:SetBackdropColor(0.11, 0.13, 0.16, 0.94)
            overlay:SetBackdropBorderColor(0.22, 0.25, 0.31, 0.46)
        else
            overlay:SetBackdropColor(0.05, 0.06, 0.08, 0.88)
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

local selectionClickSerial = 0

local function IsControlModifierDown()
    return IsControlKeyDown and IsControlKeyDown() == true
end

local function BeginEditorFrameSelectionClick(frame, button)
    if not frame or button ~= "LeftButton" then
        return
    end

    selectionClickSerial = selectionClickSerial + 1
    frame._focalPointSelectionClick = {
        serial = selectionClickSerial,
        ctrl = IsControlModifierDown(),
        handled = false,
    }
end

local function CompleteEditorFrameSelectionClick(frame, button)
    if not frame or button ~= "LeftButton" then
        return
    end

    if not FocalPoint.IsEditorActive or not FocalPoint:IsEditorActive() then
        return
    end

    local clickState = frame._focalPointSelectionClick
    if type(clickState) ~= "table" then
        BeginEditorFrameSelectionClick(frame, button)
        clickState = frame._focalPointSelectionClick
    end

    if type(clickState) ~= "table" or clickState.handled == true then
        return
    end
    clickState.handled = true

    if FocalPoint.SelectEditorUnit and frame.unit then
        FocalPoint:SelectEditorUnit(frame.unit, {
            toggle = FocalPoint.framesUnlocked == true and clickState.ctrl == true,
        })
    end
end

local function EnsureEditorSelectionHooks(frame)
    if not frame or frame._focalPointEditorSelectHooked then
        return
    end

    if frame.HookScript then
        frame:HookScript("OnMouseDown", function(_, button)
            BeginEditorFrameSelectionClick(frame, button)
        end)
        frame:HookScript("OnMouseUp", function(_, button)
            CompleteEditorFrameSelectionClick(frame, button)
        end)
    end

    local overlay = EnsureMoveOverlay(frame)
    if overlay and overlay.HookScript then
        overlay:HookScript("OnMouseDown", function(_, button)
            BeginEditorFrameSelectionClick(frame, button)
        end)
        overlay:HookScript("OnMouseUp", function(_, button)
            CompleteEditorFrameSelectionClick(frame, button)
        end)
    end

    frame._focalPointEditorSelectHooked = true
end

local function EnsureEditorContextMenuHooks(frame)
    if not frame then
        return
    end

    local contextMenu = FocalPoint.GUI
        and FocalPoint.GUI.Editor
        and FocalPoint.GUI.Editor.FrameContextMenu
    if not contextMenu then
        return
    end

    if contextMenu.AttachFrame then
        contextMenu.AttachFrame(frame)
    end
    if contextMenu.AttachOverlay and frame.MoveOverlay then
        contextMenu.AttachOverlay(frame, frame.MoveOverlay)
    end
end

local function UpdateEditorResizeHandle(frame)
    local resizeHandles = FocalPoint.GUI
        and FocalPoint.GUI.Editor
        and FocalPoint.GUI.Editor.FrameResizeHandles
    if resizeHandles and resizeHandles.UpdateFrame then
        resizeHandles.UpdateFrame(frame)
    end
end

local function HideEditorResizeHandle(frame)
    local resizeHandles = FocalPoint.GUI
        and FocalPoint.GUI.Editor
        and FocalPoint.GUI.Editor.FrameResizeHandles
    if resizeHandles and resizeHandles.HideFrame then
        resizeHandles.HideFrame(frame)
    end
end

local function GetEditorInteractionMode()
    return FocalPoint.GUI
        and FocalPoint.GUI.Editor
        and FocalPoint.GUI.Editor.InteractionMode
        or nil
end

local function IsEditorFrameMode()
    local interactionMode = GetEditorInteractionMode()
    if interactionMode and interactionMode.IsFrameMode then
        return interactionMode.IsFrameMode()
    end

    return FocalPoint.framesUnlocked == true
        and FocalPoint.IsEditorActive
        and FocalPoint:IsEditorActive()
        and not (InCombatLockdown and InCombatLockdown() == true)
end

local function SyncEditorInteractionMode()
    local interactionMode = GetEditorInteractionMode()
    if interactionMode and interactionMode.SyncShiftState then
        interactionMode.SyncShiftState()
    elseif interactionMode and interactionMode.Refresh then
        interactionMode.Refresh(true)
    end
end

local function UpdateTextEditorOverlay(frame)
    local overlay = FocalPoint.GUI
        and FocalPoint.GUI.Editor
        and FocalPoint.GUI.Editor.TextEditorOverlay
    if overlay and overlay.UpdateFrame then
        overlay.UpdateFrame(frame)
    end
end

local function HideTextEditorOverlay(frame)
    local overlay = FocalPoint.GUI
        and FocalPoint.GUI.Editor
        and FocalPoint.GUI.Editor.TextEditorOverlay
    if overlay and overlay.HideFrame then
        overlay.HideFrame(frame)
    end
end

local function CancelEditorResize()
    local resizeHandles = FocalPoint.GUI
        and FocalPoint.GUI.Editor
        and FocalPoint.GUI.Editor.FrameResizeHandles
    if resizeHandles and resizeHandles.CancelAll then
        resizeHandles.CancelAll()
    end
end

local function ApplyEditorSnapLines(frame, x, y)
    local snapLines = FocalPoint.GUI
        and FocalPoint.GUI.Editor
        and FocalPoint.GUI.Editor.FrameSnapLines
    if snapLines and snapLines.Apply then
        return snapLines.Apply(frame, x, y)
    end

    return x, y
end

local function HideEditorSnapLines()
    local snapLines = FocalPoint.GUI
        and FocalPoint.GUI.Editor
        and FocalPoint.GUI.Editor.FrameSnapLines
    if snapLines and snapLines.Hide then
        snapLines.Hide()
    end
end

local UpdateMoveOverlay
local EndFrameDrag

local function GetEditorStateApi()
    return FocalPoint.GUI and FocalPoint.GUI.Editor and FocalPoint.GUI.Editor.State or nil
end

local function ResolveFrameForSelectionUnit(unitKey, draggedFrame)
    local normalizedUnit = NormalizeEditorSelectionUnit(unitKey)
    if not normalizedUnit then
        return nil
    end

    if normalizedUnit == "boss" then
        if draggedFrame and draggedFrame.unit and draggedFrame.unit:match("^boss%d+$") then
            return draggedFrame
        end

        if FocalPoint.frames then
            for bossIndex = 1, 5 do
                local bossFrame = FocalPoint.frames["boss" .. bossIndex]
                if bossFrame then
                    return bossFrame
                end
            end
        end
    end

    return FocalPoint.frames and FocalPoint.frames[normalizedUnit] or nil
end

local function ResolveSelectedDragUnits(draggedFrame)
    local draggedUnit = NormalizeEditorSelectionUnit(draggedFrame and draggedFrame.unit)
    if not draggedUnit then
        return {}
    end

    local editorState = GetEditorStateApi()
    local isSelected = editorState
        and editorState.IsUnitSelected
        and editorState.IsUnitSelected(draggedUnit)

    if isSelected then
        if editorState.SetPrimaryUnit then
            editorState.SetPrimaryUnit(draggedUnit)
        end
        if editorState.GetSelectedUnits then
            return editorState.GetSelectedUnits()
        end
    elseif editorState and editorState.SetSingleSelection then
        editorState.SetSingleSelection(draggedUnit)
    elseif editorState and editorState.SetSelectedUnit then
        editorState.SetSelectedUnit(draggedUnit)
    end

    return { draggedUnit }
end

local function MarkSelectionClickHandled(frame)
    local clickState = frame and frame._focalPointSelectionClick
    if type(clickState) == "table" then
        clickState.handled = true
    end
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

    local unitConfig = GetUnitConfig(frame.unit)
    local x = unitConfig and unitConfig.x
    local y = unitConfig and unitConfig.y
    if x == nil or y == nil then
        x, y = GetFrameCenterOffsets(frame)
    end

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

FocalPoint.SaveFramePosition = SaveFramePosition

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

    if InCombatLockdown and InCombatLockdown() then
        return
    end

    MarkSelectionClickHandled(frame)

    local unitConfig = GetUnitConfig(frame.unit)
    if not unitConfig then
        return
    end

    local selectedUnits = ResolveSelectedDragUnits(frame)
    if FocalPoint.RefreshEditorSelectionVisuals then
        FocalPoint:RefreshEditorSelectionVisuals()
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

    local startPositions = {}
    for _, unitKey in ipairs(selectedUnits) do
        local normalizedUnit = NormalizeEditorSelectionUnit(unitKey)
        local selectedFrame = ResolveFrameForSelectionUnit(normalizedUnit, frame)
        local selectedConfig = GetUnitConfig(normalizedUnit)
        if normalizedUnit and selectedFrame and selectedConfig then
            local selectedX, selectedY = GetFrameCenterOffsets(selectedFrame)
            selectedY = selectedY + GetBossStackOffset(selectedFrame, selectedConfig)
            selectedConfig.point = "CENTER"
            selectedConfig.relativePoint = "CENTER"
            selectedConfig.relativeTo = "UIParent"
            selectedConfig.x = selectedX
            selectedConfig.y = selectedY
            startPositions[normalizedUnit] = {
                x = tonumber(selectedX) or 0,
                y = tonumber(selectedY) or 0,
            }
        end
    end

    frame._focalPointDragState = {
        cursorX = (cursorX or 0) / scale,
        cursorY = (cursorY or 0) / scale,
        startX = tonumber(startX) or 0,
        startY = tonumber(startY) or 0,
        selectedUnits = selectedUnits,
        startPositions = startPositions,
    }

    frame:SetScript("OnUpdate", function(movingFrame)
        local dragState = movingFrame._focalPointDragState
        if not dragState then
            return
        end
        if InCombatLockdown and InCombatLockdown() then
            EndFrameDrag(movingFrame, false)
            return
        end

        local currentX, currentY = GetCursorPosition()
        currentX = (currentX or 0) / scale
        currentY = (currentY or 0) / scale

        local nextX = dragState.startX + (currentX - dragState.cursorX)
        local nextY = dragState.startY + (currentY - dragState.cursorY)
        nextX, nextY = ApplyEditorSnapLines(movingFrame, nextX, nextY)

        local deltaX = nextX - dragState.startX
        local deltaY = nextY - dragState.startY
        for unitKey, startPosition in pairs(dragState.startPositions or {}) do
            local selectedConfig = GetUnitConfig(unitKey)
            local selectedFrame = ResolveFrameForSelectionUnit(unitKey, movingFrame)
            if selectedConfig and selectedFrame then
                selectedConfig.x = (tonumber(startPosition.x) or 0) + deltaX
                selectedConfig.y = (tonumber(startPosition.y) or 0) + deltaY
                if unitKey == "boss" then
                    ApplyBossStackPositions()
                else
                    FocalPoint:ApplyStoredFramePosition(selectedFrame)
                    UpdateMoveOverlay(selectedFrame)
                end
            end
        end
    end)

    UpdateMoveOverlayVisuals(frame)
end

EndFrameDrag = function(frame, commit)
    if not frame then
        return
    end

    commit = commit ~= false
    local dragState = frame._focalPointDragState
    frame._focalPointDragState = nil
    frame:SetScript("OnUpdate", nil)

    if dragState and type(dragState.startPositions) == "table" then
        if not commit then
            for unitKey, startPosition in pairs(dragState.startPositions) do
                local selectedConfig = GetUnitConfig(unitKey)
                local selectedFrame = ResolveFrameForSelectionUnit(unitKey, frame)
                if selectedConfig and selectedFrame then
                    selectedConfig.x = tonumber(startPosition.x) or 0
                    selectedConfig.y = tonumber(startPosition.y) or 0
                    if unitKey == "boss" then
                        ApplyBossStackPositions()
                    else
                        FocalPoint:ApplyStoredFramePosition(selectedFrame)
                        UpdateMoveOverlay(selectedFrame)
                    end
                end
            end
        end
    end

    if commit and dragState and type(dragState.startPositions) == "table" then
        for unitKey in pairs(dragState.startPositions) do
            local selectedFrame = ResolveFrameForSelectionUnit(unitKey, frame)
            if selectedFrame then
                SaveFramePosition(selectedFrame)
                if unitKey == "boss" then
                    ApplyBossStackPositions()
                else
                    FocalPoint:ApplyStoredFramePosition(selectedFrame)
                    UpdateMoveOverlay(selectedFrame)
                end
            end
        end
    elseif commit then
        SaveFramePosition(frame)
        if frame.unit and frame.unit:match("^boss%d+$") then
            ApplyBossStackPositions()
        else
            FocalPoint:ApplyStoredFramePosition(frame)
            UpdateMoveOverlay(frame)
        end
    end
    HideEditorSnapLines()

    if FocalPoint.RefreshEditorSelectionVisuals then
        FocalPoint:RefreshEditorSelectionVisuals()
    else
        UpdateMoveOverlayVisuals(frame)
    end
end

function FocalPoint:UpdateFrameDragState(frame)
    if not frame then
        return
    end

    EnsureEditorSelectionHooks(frame)

    local overlay = EnsureMoveOverlay(frame)
    EnsureEditorContextMenuHooks(frame)
    local frameMode = IsEditorFrameMode()
    frame:SetMovable(self.framesUnlocked == true and frameMode)
    frame:SetClampedToScreen(true)

    if self.framesUnlocked then
        if overlay then
            overlay:SetFrameStrata(frame:GetFrameStrata())
            overlay:SetFrameLevel(math.max(frame:GetFrameLevel() + 40, (frame.Elements and frame.Elements.HealthBar and frame.Elements.HealthBar:GetFrameLevel() + 20) or (frame:GetFrameLevel() + 40)))
            overlay:EnableMouse(frameMode)
            if frameMode then
                overlay:RegisterForDrag("LeftButton")
                overlay:SetScript("OnDragStart", function()
                    if not FocalPoint.framesUnlocked or not IsEditorFrameMode() then
                        return
                    end

                    BeginFrameDrag(frame)
                end)
                overlay:SetScript("OnDragStop", function()
                    EndFrameDrag(frame)
                end)
            else
                overlay:RegisterForDrag()
                overlay:SetScript("OnDragStart", nil)
                overlay:SetScript("OnDragStop", nil)
                if frame._focalPointDragState then
                    EndFrameDrag(frame, false)
                end
                HideEditorSnapLines()
            end
            overlay:Show()
            UpdateMoveOverlay(frame)
            if frameMode then
                UpdateEditorResizeHandle(frame)
            else
                HideEditorResizeHandle(frame)
            end
        end
        if frameMode then
            frame:RegisterForDrag("LeftButton")
            frame:SetScript("OnDragStart", function(target)
                if not FocalPoint.framesUnlocked or not IsEditorFrameMode() then
                    return
                end

                BeginFrameDrag(target)
            end)
            frame:SetScript("OnDragStop", function(target)
                EndFrameDrag(target)
            end)
        else
            frame:RegisterForDrag()
            frame:SetScript("OnDragStart", nil)
            frame:SetScript("OnDragStop", nil)
        end
    else
        if overlay then
            overlay:RegisterForDrag()
            overlay:SetScript("OnDragStart", nil)
            overlay:SetScript("OnDragStop", nil)
            overlay:EnableMouse(false)
            overlay:Hide()
            HideEditorResizeHandle(frame)
        end
        frame:RegisterForDrag()
        frame:SetScript("OnDragStart", nil)
        frame:SetScript("OnDragStop", nil)
        frame:SetScript("OnUpdate", nil)
        frame._focalPointDragState = nil
        HideEditorSnapLines()
        HideTextEditorOverlay(frame)
    end

    UpdateSelectionOverlay(frame)
    UpdateMoveOverlayVisuals(frame)
    UpdateTextEditorOverlay(frame)
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
            if frame._focalPointDragState and EndFrameDrag then
                EndFrameDrag(frame, false)
            else
                frame._focalPointDragState = nil
                frame:SetScript("OnUpdate", nil)
            end
            frame:RegisterForDrag()
            frame:SetScript("OnDragStart", nil)
            frame:SetScript("OnDragStop", nil)
            HideEditorSnapLines()

            local overlay = frame.MoveOverlay
            if overlay then
                overlay:RegisterForDrag()
                overlay:SetScript("OnDragStart", nil)
                overlay:SetScript("OnDragStop", nil)
                overlay:EnableMouse(false)
                overlay:Hide()
            end
            HideEditorResizeHandle(frame)

            local selectionOverlay = frame.SelectionOverlay
            if selectionOverlay then
                selectionOverlay:Hide()
            end
            HideTextEditorOverlay(frame)
        end
    end
end

function FocalPoint:RefreshEditorInteractionVisuals()
    if self.UpdateAllFrameDragStates then
        self:UpdateAllFrameDragStates()
    elseif self.RefreshEditorSelectionVisuals then
        self:RefreshEditorSelectionVisuals()
    end

    if self.frames and self.UnitFrame and self.UnitFrame.UpdateTextElements then
        for _, frame in pairs(self.frames) do
            self.UnitFrame:UpdateTextElements(frame)
        end
    end
end

function FocalPoint:RefreshEditorSelectionVisuals()
    if not self.frames then
        return
    end

    for _, frame in pairs(self.frames) do
        UpdateSelectionOverlay(frame)
        UpdateEditorResizeHandle(frame)
        if frame and frame.MoveOverlay and frame.MoveOverlay.Coords then
            UpdateMoveOverlay(frame)
        else
            UpdateMoveOverlayVisuals(frame)
        end
        UpdateTextEditorOverlay(frame)
    end
end

function FocalPoint:ToggleFrameLock()
    self.framesUnlocked = not self.framesUnlocked
    SyncEditorInteractionMode()

    if self.framesUnlocked and self.SpawnUnitFrame then
        local unitOrder = self.Constants and self.Constants.UnitOrder or {}

        for _, unit in ipairs(unitOrder) do
            local config = GetUnitConfig(unit)

            if unit == "boss" then
                if type(config) == "table" then
                    for bossIndex = 1, 5 do
                        local bossUnit = "boss" .. bossIndex
                        if not self.frames[bossUnit] then
                            self:SpawnUnitFrame(bossUnit, { allowDisabledForUnlock = true })
                        end
                    end
                end
            elseif type(config) == "table" and not self.frames[unit] then
                self:SpawnUnitFrame(unit, { allowDisabledForUnlock = true })
            end
        end
    end

    if self.framesUnlocked then
        if self.RefreshAllFrames then
            self:RefreshAllFrames()
        end
        self:UpdateAllFrameDragStates()
        self:RefreshEditorSelectionVisuals()
        if self.GUI and self.GUI.RequestRefreshOptions then
            self.GUI:RequestRefreshOptions()
        end
        self:Info("Unit frames unlocked. Drag with left mouse button.")
    else
        CancelEditorResize()
        HideEditorSnapLines()

        local contextMenu = self.GUI
            and self.GUI.Editor
            and self.GUI.Editor.FrameContextMenu
        if contextMenu and contextMenu.Hide then
            contextMenu.Hide()
        end

        local demo = self.UnitFrameDemoEnvironment or nil
        if demo and demo.ExitTestMode then
            demo.ExitTestMode("frames-lock-on")
        end
        local editorState = self.GUI and self.GUI.Editor and self.GUI.Editor.State
        if editorState and editorState.ClearSelection then
            editorState.ClearSelection("player")
        elseif editorState and editorState.SetSelectedUnit then
            editorState.SetSelectedUnit("player")
        end
        self:ClearAllMoveOverlays()
        self:UpdateAllFrameDragStates()
        self:RefreshEditorSelectionVisuals()
        if self.RefreshAllFrames then
            self:RefreshAllFrames()
        end
        if self.GUI and self.GUI.RequestRefreshOptions then
            self.GUI:RequestRefreshOptions()
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
