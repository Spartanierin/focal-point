local _, FocalPoint = ...

FocalPoint.GUI = FocalPoint.GUI or {}
FocalPoint.GUI.Editor = FocalPoint.GUI.Editor or {}

local TextEditorOverlay = {}
FocalPoint.GUI.Editor.TextEditorOverlay = TextEditorOverlay

local TextStatus = FocalPoint.TextElementStatus or {}
local UnitUtils = FocalPoint.UnitFrameUtils or {}

local HITBOX_WIDTH = 46
local HITBOX_HEIGHT = 22
local VISUAL_FRAME_LEVEL = 920
local SELECTED_VISUAL_FRAME_LEVEL = 930
local CLICK_FRAME_LEVEL = 940
local SELECTED_CLICK_FRAME_LEVEL = 950
local VISUAL_PADDING_X = 4
local VISUAL_PADDING_Y = 4
local DRAG_THRESHOLD = 4
local MIN_TEXT_OFFSET = -100
local MAX_TEXT_OFFSET = 100

local activeDragOverlay

local function NormalizeUnitKey(unitKey)
    if type(unitKey) ~= "string" or unitKey == "" then
        return nil
    end
    if unitKey:match("^boss%d+$") then
        return "boss"
    end
    return unitKey
end

local function IsCombatLocked()
    return InCombatLockdown and InCombatLockdown() == true
end

local function ClampOffset(value)
    value = tonumber(value) or 0
    if value < MIN_TEXT_OFFSET then
        value = MIN_TEXT_OFFSET
    elseif value > MAX_TEXT_OFFSET then
        value = MAX_TEXT_OFFSET
    end

    return math.floor(value + 0.5)
end

local function GetCursorPositionInUiScale()
    if not GetCursorPosition then
        return nil, nil
    end

    local scale = UIParent and UIParent.GetEffectiveScale and UIParent:GetEffectiveScale() or 1
    if not scale or scale == 0 then
        scale = 1
    end

    local cursorX, cursorY = GetCursorPosition()
    return (cursorX or 0) / scale, (cursorY or 0) / scale
end

local function GetUnitConfigByKey(unitKey)
    local normalizedUnit = NormalizeUnitKey(unitKey)
    if not normalizedUnit then
        return nil, nil
    end

    if UnitUtils.GetUnitDB then
        return UnitUtils.GetUnitDB(normalizedUnit), normalizedUnit
    end

    return nil, normalizedUnit
end

local function IsTextModeActive()
    local interactionMode = FocalPoint
        and FocalPoint.GUI
        and FocalPoint.GUI.Editor
        and FocalPoint.GUI.Editor.InteractionMode
    if interactionMode and interactionMode.IsTextMode then
        return interactionMode.IsTextMode()
    end

    return false
end

local function GetEditorStateApi()
    return FocalPoint
        and FocalPoint.GUI
        and FocalPoint.GUI.Editor
        and FocalPoint.GUI.Editor.State
        or nil
end

local function GetTextConfig(frame, textKey)
    local unitConfig = frame and frame.config or nil
    local normalizedUnit = frame and NormalizeUnitKey(frame.unit) or nil
    if normalizedUnit then
        unitConfig = GetUnitConfigByKey(normalizedUnit) or unitConfig
    end

    local texts = unitConfig and unitConfig.Texts
    if type(texts) ~= "table" or type(textKey) ~= "string" or textKey == "" then
        return nil
    end
    return texts[textKey]
end

local function GetActiveProfileTemplate(templateName)
    if type(templateName) ~= "string" or templateName == "" then
        return nil
    end

    local templates = UnitUtils.GetTextTemplatesDB and UnitUtils.GetTextTemplatesDB() or nil
    if type(templates) == "table" then
        return templates[templateName]
    end

    return nil
end

local function IsEditorRenderableText(frame, textKey, textConfig)
    if TextStatus.IsEditorRenderable then
        return TextStatus.IsEditorRenderable(textConfig, {
            textKey = textKey,
            unitConfig = frame and frame.config,
            GetTemplate = GetActiveProfileTemplate,
        })
    end

    return type(textConfig) == "table" and textConfig.enabled ~= false
end

local function CreateBorderTextures(owner)
    local borderTop = owner:CreateTexture(nil, "ARTWORK")
    borderTop:SetPoint("TOPLEFT", owner, "TOPLEFT")
    borderTop:SetPoint("TOPRIGHT", owner, "TOPRIGHT")
    borderTop:SetHeight(1)
    owner.BorderTop = borderTop

    local borderBottom = owner:CreateTexture(nil, "ARTWORK")
    borderBottom:SetPoint("BOTTOMLEFT", owner, "BOTTOMLEFT")
    borderBottom:SetPoint("BOTTOMRIGHT", owner, "BOTTOMRIGHT")
    borderBottom:SetHeight(1)
    owner.BorderBottom = borderBottom

    local borderLeft = owner:CreateTexture(nil, "ARTWORK")
    borderLeft:SetPoint("TOPLEFT", owner, "TOPLEFT")
    borderLeft:SetPoint("BOTTOMLEFT", owner, "BOTTOMLEFT")
    borderLeft:SetWidth(1)
    owner.BorderLeft = borderLeft

    local borderRight = owner:CreateTexture(nil, "ARTWORK")
    borderRight:SetPoint("TOPRIGHT", owner, "TOPRIGHT")
    borderRight:SetPoint("BOTTOMRIGHT", owner, "BOTTOMRIGHT")
    borderRight:SetWidth(1)
    owner.BorderRight = borderRight
end

local function SetFullBorderVisible(owner, visible)
    if not owner then
        return
    end

    for _, texture in ipairs({
        owner.BorderTop,
        owner.BorderBottom,
        owner.BorderLeft,
        owner.BorderRight,
    }) do
        if texture then
            if visible and texture.Show then
                texture:Show()
            elseif not visible and texture.Hide then
                texture:Hide()
            end
        end
    end
end

local function SetBorderStyle(owner, r, g, b, a, thickness)
    if not owner then
        return
    end

    for _, border in ipairs({
        owner.BorderTop,
        owner.BorderBottom,
        owner.BorderLeft,
        owner.BorderRight,
    }) do
        if border and border.SetColorTexture then
            border:SetColorTexture(r, g, b, a)
        end
    end

    thickness = thickness or 1
    if owner.BorderTop then owner.BorderTop:SetHeight(thickness) end
    if owner.BorderBottom then owner.BorderBottom:SetHeight(thickness) end
    if owner.BorderLeft then owner.BorderLeft:SetWidth(thickness) end
    if owner.BorderRight then owner.BorderRight:SetWidth(thickness) end
end

local function HasUsableTextObject(textObject)
    if not textObject or not textObject.GetObjectType then
        return false
    end
    if textObject.IsShown and not textObject:IsShown() then
        return false
    end
    return true
end

local StyleOverlay
local EndTextDrag

local function EnsureOverlay(frame, textKey)
    if not frame or type(textKey) ~= "string" or textKey == "" then
        return nil
    end

    frame._focalPointTextEditorOverlays = frame._focalPointTextEditorOverlays or {}
    local overlay = frame._focalPointTextEditorOverlays[textKey]
    if overlay then
        return overlay
    end

    overlay = CreateFrame("Button", nil, frame)
    overlay:SetFrameStrata("FULLSCREEN")
    overlay:SetFrameLevel(CLICK_FRAME_LEVEL)

    local visualBounds = CreateFrame("Frame", nil, frame)
    visualBounds:SetFrameStrata("FULLSCREEN")
    visualBounds:SetFrameLevel(VISUAL_FRAME_LEVEL)
    visualBounds:EnableMouse(false)
    visualBounds:Hide()
    local visualBackground = visualBounds:CreateTexture(nil, "BACKGROUND")
    visualBackground:SetAllPoints(visualBounds)
    visualBackground:SetColorTexture(0, 0, 0, 0)
    visualBounds.Background = visualBackground
    CreateBorderTextures(visualBounds)
    overlay.VisualBounds = visualBounds

    overlay:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    overlay:SetScript("OnMouseDown", function(self, button)
        if button == "LeftButton" then
            TextEditorOverlay.BeginDrag(self)
        end
    end)
    overlay:SetScript("OnMouseUp", function(self, button)
        if button == "LeftButton" then
            EndTextDrag(self, true)
        end
    end)
    overlay:SetScript("OnEnter", function(self)
        self._focalPointHovered = true
        StyleOverlay(self, self._focalPointSelected == true, true)
    end)
    overlay:SetScript("OnLeave", function(self)
        self._focalPointHovered = false
        StyleOverlay(self, self._focalPointSelected == true, false)
    end)
    overlay:SetScript("OnClick", function(self, button)
        if self._focalPointSuppressClick then
            self._focalPointSuppressClick = nil
            return
        end

        if button == "RightButton" then
            local contextMenu = FocalPoint.GUI
                and FocalPoint.GUI.Editor
                and FocalPoint.GUI.Editor.FrameContextMenu
            if contextMenu and contextMenu.ShowForFrame then
                contextMenu.ShowForFrame(self._focalPointOwnerFrame)
            end
            return
        elseif button == "LeftButton" then
            TextEditorOverlay.Select(self._focalPointOwnerFrame, self._focalPointTextKey)
        end
    end)
    overlay:SetScript("OnHide", function(self)
        EndTextDrag(self, false)
    end)
    overlay:Hide()

    frame._focalPointTextEditorOverlays[textKey] = overlay
    return overlay
end

StyleOverlay = function(overlay, selected, hovered)
    if not overlay then
        return
    end

    local visual = overlay.VisualBounds
    if selected then
        overlay:SetFrameLevel(SELECTED_CLICK_FRAME_LEVEL)
        if visual then
            visual:SetFrameLevel(SELECTED_VISUAL_FRAME_LEVEL)
            if visual.Background then
                visual.Background:SetColorTexture(0.98, 0.74, 0.18, 0.08)
            end
            SetFullBorderVisible(visual, true)
            SetBorderStyle(visual, 1.00, 0.82, 0.24, 0.98, 2)
            visual:Show()
        end
    else
        overlay:SetFrameLevel(CLICK_FRAME_LEVEL)
        if visual then
            visual:SetFrameLevel(VISUAL_FRAME_LEVEL)
            if visual.Background then
                if hovered then
                    visual.Background:SetColorTexture(0.98, 0.74, 0.18, 0.02)
                else
                    visual.Background:SetColorTexture(0, 0, 0, 0)
                end
            end

            if hovered then
                SetFullBorderVisible(visual, true)
                SetBorderStyle(visual, 1.00, 0.82, 0.24, 0.70, 1)
                visual:Show()
            else
                SetFullBorderVisible(visual, false)
                visual:Hide()
            end
        end
    end
end

local function ClearPreviewOffset(frame, textKey)
    local offsets = frame and frame._focalPointTextDragPreviewOffsets
    if type(offsets) ~= "table" then
        return
    end

    offsets[textKey] = nil
    if next(offsets) == nil then
        frame._focalPointTextDragPreviewOffsets = nil
    end
end

local function ApplyPreviewOffset(frame, textKey, offsetX, offsetY)
    local textConfig = GetTextConfig(frame, textKey)
    local textObject = frame and frame.Texts and frame.Texts[textKey]
    if type(textConfig) ~= "table" or not textObject then
        return false
    end

    frame._focalPointTextDragPreviewOffsets = frame._focalPointTextDragPreviewOffsets or {}
    frame._focalPointTextDragPreviewOffsets[textKey] = {
        offsetX = offsetX,
        offsetY = offsetY,
    }

    local unitFrame = FocalPoint.UnitFrame
    if unitFrame and unitFrame.ApplyTextElementConfig then
        unitFrame:ApplyTextElementConfig(frame, textKey, textObject, textConfig)
    end

    TextEditorOverlay.UpdateFrame(frame)
    return true
end

local function RestoreTextPositionPreview(frame, textKey)
    ClearPreviewOffset(frame, textKey)

    local unitFrame = FocalPoint.UnitFrame
    local textConfig = GetTextConfig(frame, textKey)
    local textObject = frame and frame.Texts and frame.Texts[textKey]
    if unitFrame and unitFrame.ApplyTextElementConfig and textConfig and textObject then
        unitFrame:ApplyTextElementConfig(frame, textKey, textObject, textConfig)
    end

    TextEditorOverlay.UpdateFrame(frame)
end

local function RefreshAfterTextPositionCommit(frame)
    local unitFrame = FocalPoint.UnitFrame
    if unitFrame and unitFrame.UpdateTextElements then
        unitFrame:UpdateTextElements(frame)
    elseif FocalPoint.RefreshUnitFrame and frame and frame.unit then
        FocalPoint:RefreshUnitFrame(frame.unit)
    end

    TextEditorOverlay.UpdateFrame(frame)

    if FocalPoint.GUI and FocalPoint.GUI.RequestRefreshOptions then
        FocalPoint.GUI:RequestRefreshOptions()
    end
    if FocalPoint.RefreshEditorSelectionVisuals then
        FocalPoint:RefreshEditorSelectionVisuals()
    end
end

local function CommitTextPosition(frame, textKey, offsetX, offsetY)
    local unitConfig, normalizedUnit = GetUnitConfigByKey(frame and frame.unit)
    if type(unitConfig) ~= "table" or not normalizedUnit then
        return false
    end

    local mutations = FocalPoint.InspectorMutations
        or (FocalPoint.GUI and FocalPoint.GUI.Editor and FocalPoint.GUI.Editor.Inspector and FocalPoint.GUI.Editor.Inspector.Mutations)
    if not (mutations and mutations.SetTextPositionOffsets) then
        return false
    end

    local result = mutations.SetTextPositionOffsets({
        unitConfig = unitConfig,
    }, textKey, offsetX, offsetY)
    if result and result.ok == false then
        return false
    end

    if result and result.changed then
        RefreshAfterTextPositionCommit(frame)
    else
        TextEditorOverlay.UpdateFrame(frame)
    end

    return true
end

local function IsDragContextStillValid(state)
    if type(state) ~= "table" then
        return false
    end

    local unitConfig = GetUnitConfigByKey(state.frame and state.frame.unit)
    local textConfig = GetTextConfig(state.frame, state.textKey)
    return unitConfig == state.unitConfig
        and textConfig == state.textConfig
        and IsEditorRenderableText(state.frame, state.textKey, textConfig)
end

EndTextDrag = function(overlay, commit)
    local state = overlay and overlay._focalPointTextDragState
    if not state then
        return
    end

    overlay._focalPointTextDragState = nil
    overlay:SetScript("OnUpdate", nil)
    if activeDragOverlay == overlay then
        activeDragOverlay = nil
    end

    if not state.dragging then
        return
    end

    if commit == false or IsCombatLocked() or not IsTextModeActive() or not IsDragContextStillValid(state) then
        RestoreTextPositionPreview(state.frame, state.textKey)
        return
    end

    overlay._focalPointSuppressClick = true
    ClearPreviewOffset(state.frame, state.textKey)
    if not CommitTextPosition(state.frame, state.textKey, state.currentOffsetX or state.startOffsetX, state.currentOffsetY or state.startOffsetY) then
        RestoreTextPositionPreview(state.frame, state.textKey)
    end
end

function TextEditorOverlay.HideFrame(frame)
    local overlays = frame and frame._focalPointTextEditorOverlays
    if type(overlays) ~= "table" then
        return
    end
    for _, overlay in pairs(overlays) do
        if overlay and overlay.Hide then
            EndTextDrag(overlay, false)
            overlay._focalPointHovered = false
            overlay._focalPointSelected = false
            overlay:Hide()
            overlay:EnableMouse(false)
            if overlay.VisualBounds and overlay.VisualBounds.Hide then
                overlay.VisualBounds:Hide()
            end
        end
    end
end

function TextEditorOverlay.UpdateFrame(frame)
    if not frame then
        return
    end

    if not IsTextModeActive() then
        TextEditorOverlay.HideFrame(frame)
        return
    end

    local texts = frame.config and frame.config.Texts
    if type(texts) ~= "table" then
        TextEditorOverlay.HideFrame(frame)
        return
    end

    local stateApi = GetEditorStateApi()
    local normalizedUnit = NormalizeUnitKey(frame.unit)
    local seen = {}

    for textKey, textConfig in pairs(texts) do
        if type(textKey) == "string"
            and textKey ~= ""
            and type(textConfig) == "table"
            and IsEditorRenderableText(frame, textKey, textConfig)
        then
            seen[textKey] = true
            local textObject = frame.Texts and frame.Texts[textKey]
            local overlay = EnsureOverlay(frame, textKey)
            if overlay then
                overlay._focalPointOwnerFrame = frame
                overlay._focalPointTextKey = textKey
                overlay:SetFrameStrata("FULLSCREEN")
                overlay:ClearAllPoints()

                if HasUsableTextObject(textObject) then
                    overlay:SetPoint("TOPLEFT", textObject, "TOPLEFT", -VISUAL_PADDING_X, VISUAL_PADDING_Y)
                    overlay:SetPoint("BOTTOMRIGHT", textObject, "BOTTOMRIGHT", VISUAL_PADDING_X, -VISUAL_PADDING_Y)
                else
                    overlay:SetSize(HITBOX_WIDTH, HITBOX_HEIGHT)
                    overlay:SetPoint("CENTER", frame, "CENTER", 0, 0)
                end

                local visual = overlay.VisualBounds
                if visual then
                    visual:SetFrameStrata("FULLSCREEN")
                    visual:ClearAllPoints()
                    if HasUsableTextObject(textObject) then
                        visual:SetPoint("TOPLEFT", textObject, "TOPLEFT", -VISUAL_PADDING_X, VISUAL_PADDING_Y)
                        visual:SetPoint("BOTTOMRIGHT", textObject, "BOTTOMRIGHT", VISUAL_PADDING_X, -VISUAL_PADDING_Y)
                    else
                        visual:SetAllPoints(overlay)
                    end
                end

                local selected = stateApi
                    and stateApi.IsTextElementSelected
                    and stateApi.IsTextElementSelected(normalizedUnit, textKey)
                    or false
                overlay._focalPointSelected = selected == true
                StyleOverlay(overlay, overlay._focalPointSelected, overlay._focalPointHovered == true)
                overlay:EnableMouse(true)
                overlay:Show()
            end
        end
    end

    local overlays = frame._focalPointTextEditorOverlays
    if type(overlays) == "table" then
        for textKey, overlay in pairs(overlays) do
            if not seen[textKey] and overlay and overlay.Hide then
                EndTextDrag(overlay, false)
                overlay._focalPointHovered = false
                overlay._focalPointSelected = false
                overlay:Hide()
                overlay:EnableMouse(false)
                if overlay.VisualBounds and overlay.VisualBounds.Hide then
                    overlay.VisualBounds:Hide()
                end
            end
        end
    end
end

function TextEditorOverlay.BeginDrag(overlay)
    if not overlay or IsCombatLocked() or not IsTextModeActive() then
        return false
    end

    local frame = overlay._focalPointOwnerFrame
    local textKey = overlay._focalPointTextKey
    local unitConfig = GetUnitConfigByKey(frame and frame.unit)
    local textConfig = GetTextConfig(frame, textKey)
    if not frame or type(unitConfig) ~= "table" or type(textKey) ~= "string" or textKey == "" or type(textConfig) ~= "table" then
        return false
    end
    if not IsEditorRenderableText(frame, textKey, textConfig) then
        return false
    end

    if activeDragOverlay and activeDragOverlay ~= overlay then
        EndTextDrag(activeDragOverlay, false)
    end

    TextEditorOverlay.Select(frame, textKey)

    local cursorX, cursorY = GetCursorPositionInUiScale()
    if not cursorX or not cursorY then
        return false
    end

    overlay._focalPointSuppressClick = nil
    overlay._focalPointTextDragState = {
        frame = frame,
        textKey = textKey,
        unitConfig = unitConfig,
        textConfig = textConfig,
        startCursorX = cursorX,
        startCursorY = cursorY,
        startOffsetX = ClampOffset(textConfig.offsetX),
        startOffsetY = ClampOffset(textConfig.offsetY),
        currentOffsetX = ClampOffset(textConfig.offsetX),
        currentOffsetY = ClampOffset(textConfig.offsetY),
        dragging = false,
    }
    activeDragOverlay = overlay

    overlay:SetScript("OnUpdate", function(self)
        local dragState = self._focalPointTextDragState
        if not dragState then
            self:SetScript("OnUpdate", nil)
            return
        end
        if IsCombatLocked() or not IsTextModeActive() or not IsDragContextStillValid(dragState) then
            EndTextDrag(self, false)
            return
        end
        if IsMouseButtonDown and not IsMouseButtonDown("LeftButton") then
            EndTextDrag(self, true)
            return
        end

        local currentX, currentY = GetCursorPositionInUiScale()
        if not currentX or not currentY then
            return
        end

        local deltaX = currentX - dragState.startCursorX
        local deltaY = currentY - dragState.startCursorY
        if not dragState.dragging then
            if math.abs(deltaX) < DRAG_THRESHOLD and math.abs(deltaY) < DRAG_THRESHOLD then
                return
            end
            dragState.dragging = true
            self._focalPointSuppressClick = true
        end

        local nextOffsetX = ClampOffset(dragState.startOffsetX + deltaX)
        local nextOffsetY = ClampOffset(dragState.startOffsetY + deltaY)
        if nextOffsetX == dragState.currentOffsetX and nextOffsetY == dragState.currentOffsetY then
            return
        end

        dragState.currentOffsetX = nextOffsetX
        dragState.currentOffsetY = nextOffsetY
        ApplyPreviewOffset(dragState.frame, dragState.textKey, nextOffsetX, nextOffsetY)
    end)

    return true
end

function TextEditorOverlay.CancelActiveDrag()
    if activeDragOverlay then
        EndTextDrag(activeDragOverlay, false)
    end
end

function TextEditorOverlay.RefreshAll()
    local frames = FocalPoint and FocalPoint.frames
    if type(frames) ~= "table" then
        return
    end
    for _, frame in pairs(frames) do
        TextEditorOverlay.UpdateFrame(frame)
    end
end

function TextEditorOverlay.Select(frame, textKey)
    if not frame or type(textKey) ~= "string" or textKey == "" then
        return false
    end
    if not IsTextModeActive() then
        return false
    end
    if type(GetTextConfig(frame, textKey)) ~= "table" then
        return false
    end

    local stateApi = GetEditorStateApi()
    local normalizedUnit = NormalizeUnitKey(frame.unit)
    if not normalizedUnit then
        return false
    end

    local alreadySelected = stateApi
        and stateApi.IsUnitSelected
        and stateApi.IsUnitSelected(normalizedUnit)
        or false
    if FocalPoint.SelectEditorUnit then
        FocalPoint:SelectEditorUnit(frame.unit, { preserveSelection = alreadySelected })
    elseif stateApi and stateApi.SetPrimaryUnit then
        stateApi.SetPrimaryUnit(normalizedUnit)
    end

    if stateApi and stateApi.SetSelectedTextElement then
        stateApi.SetSelectedTextElement(normalizedUnit, textKey)
    elseif stateApi and stateApi.SetSelectedTextId then
        stateApi.SetSelectedTextId(textKey)
    end

    if stateApi and stateApi.SetSectionCollapsed then
        stateApi.SetSectionCollapsed("texts", false)
    end
    if stateApi and stateApi.Get then
        local state = stateApi.Get()
        if type(state) == "table" then
            state.editorSidebarScroll = state.editorSidebarScroll or {}
            state.editorSidebarScroll.visibleAnchorSectionKey = "texts"
            state.editorSidebarScroll.visibleAnchorRole = "header"
            state.editorSidebarScroll.visibleAnchorChildIndex = nil
            state.editorSidebarScroll.visibleAnchorChildKey = nil
            state.editorSidebarScroll.visibleAnchorOffset = 0
        end
    end

    if FocalPoint.RefreshEditorSelectionVisuals then
        FocalPoint:RefreshEditorSelectionVisuals()
    end
    if FocalPoint.GUI and FocalPoint.GUI.RequestRefreshOptions then
        FocalPoint.GUI:RequestRefreshOptions()
    end

    return true
end

return TextEditorOverlay
