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
local PICKER_FRAME_LEVEL = 960
local PICKER_BUTTON_FRAME_LEVEL = 970
local PICKER_BUTTON_SIZE = 16
local PICKER_GAP = 2
local PICKER_PADDING = 3
local PICKER_SIZE = 58
local PICKER_OFFSET_Y = -6

local ANCHOR_POINTS = {
    { key = "TOPLEFT", label = "TL", row = 0, col = 0 },
    { key = "TOP", label = "T", row = 0, col = 1 },
    { key = "TOPRIGHT", label = "TR", row = 0, col = 2 },
    { key = "LEFT", label = "L", row = 1, col = 0 },
    { key = "CENTER", label = "C", row = 1, col = 1 },
    { key = "RIGHT", label = "R", row = 1, col = 2 },
    { key = "BOTTOMLEFT", label = "BL", row = 2, col = 0 },
    { key = "BOTTOM", label = "B", row = 2, col = 1 },
    { key = "BOTTOMRIGHT", label = "BR", row = 2, col = 2 },
}

local VALID_ANCHOR_POINTS = {}
for _, anchorMeta in ipairs(ANCHOR_POINTS) do
    VALID_ANCHOR_POINTS[anchorMeta.key] = true
end

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

local function IsValidAnchorPoint(point)
    return type(point) == "string" and VALID_ANCHOR_POINTS[point] == true
end

local StyleOverlay
local EndTextDrag

local function HideAnchorPicker(overlay)
    local picker = overlay and overlay.AnchorPicker
    if picker and picker.Hide then
        picker:Hide()
    end
    if GameTooltip and GameTooltip.Hide then
        GameTooltip:Hide()
    end
end

local function StylePickerButton(button, active, hovered)
    if not button then
        return
    end

    local bg = button.Background
    local label = button.Label
    if active then
        if bg then
            bg:SetColorTexture(1.00, 0.76, 0.22, 0.88)
        end
        if label then
            label:SetTextColor(0.08, 0.06, 0.02, 1)
        end
    elseif hovered then
        if bg then
            bg:SetColorTexture(0.92, 0.82, 0.52, 0.58)
        end
        if label then
            label:SetTextColor(1.00, 0.94, 0.76, 1)
        end
    else
        if bg then
            bg:SetColorTexture(0.16, 0.17, 0.18, 0.90)
        end
        if label then
            label:SetTextColor(0.72, 0.74, 0.74, 1)
        end
    end
end

local function EnsureAnchorPicker(overlay)
    if not overlay then
        return nil
    end

    if overlay.AnchorPicker then
        return overlay.AnchorPicker
    end

    local picker = CreateFrame("Frame", nil, overlay)
    picker:SetFrameStrata("FULLSCREEN")
    picker:SetFrameLevel(PICKER_FRAME_LEVEL)
    picker:SetSize(PICKER_SIZE, PICKER_SIZE)
    picker:EnableMouse(true)
    picker:EnableMouseWheel(true)
    picker:SetScript("OnMouseWheel", function()
    end)
    picker:Hide()

    local background = picker:CreateTexture(nil, "BACKGROUND")
    background:SetAllPoints(picker)
    background:SetColorTexture(0.04, 0.045, 0.05, 0.92)
    picker.Background = background
    CreateBorderTextures(picker)
    SetFullBorderVisible(picker, true)
    SetBorderStyle(picker, 0.82, 0.68, 0.32, 0.72, 1)

    picker.Buttons = {}
    for _, anchorMeta in ipairs(ANCHOR_POINTS) do
        local button = CreateFrame("Button", nil, picker)
        button:SetFrameStrata("FULLSCREEN")
        button:SetFrameLevel(PICKER_BUTTON_FRAME_LEVEL)
        button:SetSize(PICKER_BUTTON_SIZE, PICKER_BUTTON_SIZE)
        button:SetPoint(
            "TOPLEFT",
            picker,
            "TOPLEFT",
            PICKER_PADDING + anchorMeta.col * (PICKER_BUTTON_SIZE + PICKER_GAP),
            -(PICKER_PADDING + anchorMeta.row * (PICKER_BUTTON_SIZE + PICKER_GAP))
        )
        button:RegisterForClicks("LeftButtonUp")
        button:EnableMouseWheel(true)
        button._focalPointAnchorPoint = anchorMeta.key

        local buttonBackground = button:CreateTexture(nil, "BACKGROUND")
        buttonBackground:SetAllPoints(button)
        button.Background = buttonBackground

        local label = button:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        label:SetAllPoints(button)
        label:SetJustifyH("CENTER")
        label:SetJustifyV("MIDDLE")
        label:SetText(anchorMeta.label)
        button.Label = label

        button:SetScript("OnEnter", function(self)
            self._focalPointAnchorHovered = true
            StylePickerButton(self, self._focalPointAnchorActive == true, true)
            if GameTooltip and self._focalPointAnchorPoint then
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                if GameTooltip.ClearLines then
                    GameTooltip:ClearLines()
                end
                GameTooltip:AddLine(self._focalPointAnchorPoint, 1, 1, 1, true)
                GameTooltip:Show()
            end
        end)
        button:SetScript("OnLeave", function(self)
            self._focalPointAnchorHovered = false
            StylePickerButton(self, self._focalPointAnchorActive == true, false)
            if GameTooltip and GameTooltip.Hide then
                GameTooltip:Hide()
            end
        end)
        button:SetScript("OnClick", function(self, buttonName)
            if buttonName ~= "LeftButton" then
                return
            end
            if GameTooltip and GameTooltip.Hide then
                GameTooltip:Hide()
            end
            local owner = picker._focalPointOwnerOverlay
            TextEditorOverlay.SetAnchor(owner and owner._focalPointOwnerFrame, owner and owner._focalPointTextKey, self._focalPointAnchorPoint)
        end)
        button:SetScript("OnMouseWheel", function()
        end)

        picker.Buttons[#picker.Buttons + 1] = button
    end

    overlay.AnchorPicker = picker
    picker._focalPointOwnerOverlay = overlay
    return picker
end

local function UpdateAnchorPicker(overlay, selected, textConfig)
    if not overlay then
        return
    end
    if not selected or IsCombatLocked() or not IsTextModeActive() or type(textConfig) ~= "table" then
        HideAnchorPicker(overlay)
        return
    end

    local picker = EnsureAnchorPicker(overlay)
    if not picker then
        return
    end

    picker._focalPointOwnerOverlay = overlay
    picker:ClearAllPoints()
    if overlay.VisualBounds then
        picker:SetPoint("TOPLEFT", overlay.VisualBounds, "BOTTOMLEFT", 0, PICKER_OFFSET_Y)
    else
        picker:SetPoint("TOPLEFT", overlay, "BOTTOMLEFT", 0, PICKER_OFFSET_Y)
    end

    local activePoint = nil
    if textConfig.point == textConfig.relativePoint and IsValidAnchorPoint(textConfig.point) then
        activePoint = textConfig.point
    end

    for _, button in ipairs(picker.Buttons or {}) do
        button._focalPointAnchorActive = button._focalPointAnchorPoint == activePoint
        StylePickerButton(button, button._focalPointAnchorActive == true, button._focalPointAnchorHovered == true)
    end

    picker:Show()
end

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
    overlay:EnableMouseWheel(false)
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
    overlay:SetScript("OnMouseWheel", function(self, delta)
        TextEditorOverlay.AdjustFontSize(self._focalPointOwnerFrame, self._focalPointTextKey, delta)
    end)
    overlay:SetScript("OnHide", function(self)
        EndTextDrag(self, false)
        HideAnchorPicker(self)
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
        HideAnchorPicker(overlay)
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

local function RefreshSingleTextElement(frame, textKey)
    local unitFrame = FocalPoint.UnitFrame
    local textConfig = GetTextConfig(frame, textKey)
    local textObject = frame and frame.Texts and frame.Texts[textKey]
    if unitFrame and unitFrame.ApplyTextElementConfig and textConfig and textObject then
        unitFrame:ApplyTextElementConfig(frame, textKey, textObject, textConfig)
    end
    if unitFrame and unitFrame.UpdateTextElement then
        unitFrame:UpdateTextElement(frame, textKey)
    end

    TextEditorOverlay.UpdateFrame(frame)
end

local function SyncInspectorTextFontSize(unitKey, textKey, fontSize)
    local inspector = FocalPoint
        and FocalPoint.GUI
        and FocalPoint.GUI.Editor
        and FocalPoint.GUI.Editor.Inspector
    if inspector and inspector.SetActiveTextFontSizeValue then
        inspector.SetActiveTextFontSizeValue(unitKey, textKey, fontSize)
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

local function CommitTextAnchor(frame, textKey, point, relativePoint)
    local unitConfig, normalizedUnit = GetUnitConfigByKey(frame and frame.unit)
    if type(unitConfig) ~= "table" or not normalizedUnit then
        return false
    end

    local mutations = FocalPoint.InspectorMutations
        or (FocalPoint.GUI and FocalPoint.GUI.Editor and FocalPoint.GUI.Editor.Inspector and FocalPoint.GUI.Editor.Inspector.Mutations)
    if not (mutations and mutations.SetTextAnchor) then
        return false
    end

    local result = mutations.SetTextAnchor({
        unitConfig = unitConfig,
    }, textKey, point, relativePoint)
    if result and result.ok == false then
        return false
    end

    ClearPreviewOffset(frame, textKey)
    if result and result.changed then
        RefreshAfterTextPositionCommit(frame)
    else
        TextEditorOverlay.UpdateFrame(frame)
    end

    return true
end

local function CommitTextFontSizeAdjustment(frame, textKey, delta)
    local unitConfig, normalizedUnit = GetUnitConfigByKey(frame and frame.unit)
    if type(unitConfig) ~= "table" or not normalizedUnit then
        return false
    end

    local mutations = FocalPoint.InspectorMutations
        or (FocalPoint.GUI and FocalPoint.GUI.Editor and FocalPoint.GUI.Editor.Inspector and FocalPoint.GUI.Editor.Inspector.Mutations)
    if not (mutations and mutations.AdjustTextFontSize) then
        return false
    end

    local result = mutations.AdjustTextFontSize({
        unitConfig = unitConfig,
    }, textKey, delta)
    if result and result.ok == false then
        return false
    end

    if result and result.changed then
        ClearPreviewOffset(frame, textKey)
        RefreshSingleTextElement(frame, textKey)
        SyncInspectorTextFontSize(normalizedUnit, textKey, result.newValue)
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
            overlay:EnableMouseWheel(false)
            HideAnchorPicker(overlay)
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
                UpdateAnchorPicker(overlay, overlay._focalPointSelected, textConfig)
                overlay:EnableMouse(true)
                overlay:EnableMouseWheel(overlay._focalPointSelected == true)
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
                overlay:EnableMouseWheel(false)
                HideAnchorPicker(overlay)
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

function TextEditorOverlay.SetAnchor(frame, textKey, anchorPoint)
    if IsCombatLocked() or not IsTextModeActive() then
        return false
    end
    if not frame or type(textKey) ~= "string" or textKey == "" or not IsValidAnchorPoint(anchorPoint) then
        return false
    end

    local textConfig = GetTextConfig(frame, textKey)
    if type(textConfig) ~= "table" or not IsEditorRenderableText(frame, textKey, textConfig) then
        return false
    end

    if activeDragOverlay then
        EndTextDrag(activeDragOverlay, false)
    end

    TextEditorOverlay.Select(frame, textKey)
    return CommitTextAnchor(frame, textKey, anchorPoint, anchorPoint)
end

function TextEditorOverlay.RefreshTextElementByUnit(unitKey, textKey)
    local frames = FocalPoint and FocalPoint.frames
    if type(frames) ~= "table" or type(textKey) ~= "string" or textKey == "" then
        return false
    end

    local frame = frames[unitKey]
    if not frame and NormalizeUnitKey(unitKey) == "boss" then
        for index = 1, 5 do
            frame = frames["boss" .. index]
            if frame then
                break
            end
        end
    end
    if not frame then
        return false
    end

    RefreshSingleTextElement(frame, textKey)
    return true
end

function TextEditorOverlay.AdjustFontSize(frame, textKey, delta)
    if IsCombatLocked() or not IsTextModeActive() or activeDragOverlay then
        return false
    end
    if not frame or type(textKey) ~= "string" or textKey == "" then
        return false
    end

    local textConfig = GetTextConfig(frame, textKey)
    if type(textConfig) ~= "table" or not IsEditorRenderableText(frame, textKey, textConfig) then
        return false
    end

    local stateApi = GetEditorStateApi()
    local normalizedUnit = NormalizeUnitKey(frame.unit)
    local selected = stateApi
        and stateApi.IsTextElementSelected
        and stateApi.IsTextElementSelected(normalizedUnit, textKey)
        or false
    if selected ~= true then
        return false
    end

    return CommitTextFontSizeAdjustment(frame, textKey, delta)
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
