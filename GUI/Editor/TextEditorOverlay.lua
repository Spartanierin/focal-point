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

    local visual = overlay.VisualBounds
    if selected then
        overlay:SetFrameLevel(SELECTED_CLICK_FRAME_LEVEL)
        if visual then
            visual:SetFrameLevel(SELECTED_VISUAL_FRAME_LEVEL)
            if visual.Background then
                visual.Background:SetColorTexture(0.98, 0.74, 0.18, 0.08)
            end
            SetBorderStyle(visual, 1.00, 0.82, 0.24, 0.98, 2)
        end
    else
        overlay:SetFrameLevel(CLICK_FRAME_LEVEL)
        if visual then
            visual:SetFrameLevel(VISUAL_FRAME_LEVEL)
            if visual.Background then
                visual.Background:SetColorTexture(0, 0, 0, 0)
            end
            SetBorderStyle(visual, 1.00, 0.82, 0.24, 0.30, 1)
        end
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

                overlay:SetSize(HITBOX_WIDTH, HITBOX_HEIGHT)
                if textObject and textObject.GetObjectType then
                    overlay:SetPoint("CENTER", textObject, "CENTER", 0, 0)
                else
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
                StyleOverlay(overlay, selected)
                overlay:EnableMouse(true)
                if visual then
                    visual:Show()
                end
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
                if overlay.VisualBounds and overlay.VisualBounds.Hide then
                    overlay.VisualBounds:Hide()
                end
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
