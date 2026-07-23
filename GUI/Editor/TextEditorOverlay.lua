local _, FocalPoint = ...

FocalPoint.GUI = FocalPoint.GUI or {}
FocalPoint.GUI.Editor = FocalPoint.GUI.Editor or {}

local TextEditorOverlay = {}
FocalPoint.GUI.Editor.TextEditorOverlay = TextEditorOverlay

local HITBOX_WIDTH = 46
local HITBOX_HEIGHT = 22
local OVERLAY_FRAME_LEVEL = 90

local function NormalizeUnitKey(unitKey)
    if type(unitKey) ~= "string" or unitKey == "" then
        return nil
    end
    if unitKey:match("^boss%d+$") then
        return "boss"
    end
    return unitKey
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
    local texts = frame and frame.config and frame.config.Texts
    if type(texts) ~= "table" or type(textKey) ~= "string" or textKey == "" then
        return nil
    end
    return texts[textKey]
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
    overlay:SetFrameStrata(frame:GetFrameStrata())
    overlay:SetFrameLevel(OVERLAY_FRAME_LEVEL)

    local background = overlay:CreateTexture(nil, "BACKGROUND")
    background:SetAllPoints(overlay)
    background:SetColorTexture(0, 0, 0, 0)
    overlay.Background = background

    local borderTop = overlay:CreateTexture(nil, "ARTWORK")
    borderTop:SetPoint("TOPLEFT", overlay, "TOPLEFT")
    borderTop:SetPoint("TOPRIGHT", overlay, "TOPRIGHT")
    borderTop:SetHeight(1)
    borderTop:SetColorTexture(1.00, 0.82, 0.24, 0.18)
    overlay.BorderTop = borderTop

    local borderBottom = overlay:CreateTexture(nil, "ARTWORK")
    borderBottom:SetPoint("BOTTOMLEFT", overlay, "BOTTOMLEFT")
    borderBottom:SetPoint("BOTTOMRIGHT", overlay, "BOTTOMRIGHT")
    borderBottom:SetHeight(1)
    borderBottom:SetColorTexture(1.00, 0.82, 0.24, 0.18)
    overlay.BorderBottom = borderBottom

    local borderLeft = overlay:CreateTexture(nil, "ARTWORK")
    borderLeft:SetPoint("TOPLEFT", overlay, "TOPLEFT")
    borderLeft:SetPoint("BOTTOMLEFT", overlay, "BOTTOMLEFT")
    borderLeft:SetWidth(1)
    borderLeft:SetColorTexture(1.00, 0.82, 0.24, 0.18)
    overlay.BorderLeft = borderLeft

    local borderRight = overlay:CreateTexture(nil, "ARTWORK")
    borderRight:SetPoint("TOPRIGHT", overlay, "TOPRIGHT")
    borderRight:SetPoint("BOTTOMRIGHT", overlay, "BOTTOMRIGHT")
    borderRight:SetWidth(1)
    borderRight:SetColorTexture(1.00, 0.82, 0.24, 0.18)
    overlay.BorderRight = borderRight

    overlay:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    overlay:SetScript("OnClick", function(self, button)
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
    overlay:Hide()

    frame._focalPointTextEditorOverlays[textKey] = overlay
    return overlay
end

local function StyleOverlay(overlay, selected)
    if not overlay then
        return
    end

    local background = overlay.Background
    local alpha = selected and 1.00 or 0.18
    if background and background.SetColorTexture then
        if selected then
            background:SetColorTexture(0.98, 0.74, 0.18, 0.10)
        else
            background:SetColorTexture(0, 0, 0, 0)
        end
    end
    for _, border in ipairs({
        overlay.BorderTop,
        overlay.BorderBottom,
        overlay.BorderLeft,
        overlay.BorderRight,
    }) do
        if border and border.SetColorTexture then
            border:SetColorTexture(1.00, 0.82, 0.24, alpha)
        end
    end

    if selected then
        overlay.BorderTop:SetHeight(2)
        overlay.BorderBottom:SetHeight(2)
        overlay.BorderLeft:SetWidth(2)
        overlay.BorderRight:SetWidth(2)
    else
        overlay.BorderTop:SetHeight(1)
        overlay.BorderBottom:SetHeight(1)
        overlay.BorderLeft:SetWidth(1)
        overlay.BorderRight:SetWidth(1)
    end
end

function TextEditorOverlay.HideFrame(frame)
    local overlays = frame and frame._focalPointTextEditorOverlays
    if type(overlays) ~= "table" then
        return
    end
    for _, overlay in pairs(overlays) do
        if overlay and overlay.Hide then
            overlay:Hide()
            overlay:EnableMouse(false)
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
        if type(textKey) == "string" and textKey ~= "" and type(textConfig) == "table" then
            seen[textKey] = true
            local textObject = frame.Texts and frame.Texts[textKey]
            local overlay = EnsureOverlay(frame, textKey)
            if overlay then
                overlay._focalPointOwnerFrame = frame
                overlay._focalPointTextKey = textKey
                overlay:SetFrameStrata(frame:GetFrameStrata())
                overlay:SetFrameLevel(OVERLAY_FRAME_LEVEL)
                overlay:ClearAllPoints()

                overlay:SetSize(HITBOX_WIDTH, HITBOX_HEIGHT)
                if textObject and textObject.GetObjectType then
                    overlay:SetPoint("CENTER", textObject, "CENTER", 0, 0)
                else
                    overlay:SetPoint("CENTER", frame, "CENTER", 0, 0)
                end

                local selected = stateApi
                    and stateApi.IsTextElementSelected
                    and stateApi.IsTextElementSelected(normalizedUnit, textKey)
                    or false
                StyleOverlay(overlay, selected)
                overlay:EnableMouse(true)
                overlay:Show()
            end
        end
    end

    local overlays = frame._focalPointTextEditorOverlays
    if type(overlays) == "table" then
        for textKey, overlay in pairs(overlays) do
            if not seen[textKey] and overlay and overlay.Hide then
                overlay:Hide()
                overlay:EnableMouse(false)
            end
        end
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
