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
local PICKER_FRAME_LEVEL = 960
local PICKER_BUTTON_FRAME_LEVEL = 970
local PICKER_BUTTON_SIZE = 16
local PICKER_GAP = 2
local PICKER_PADDING = 3
local PICKER_SIZE = 58
local PICKER_OFFSET_Y = -6
local ANCHOR_TOGGLE_SIZE = 18
local ANCHOR_TOGGLE_OFFSET_X = 5
local ANCHOR_TOGGLE_OFFSET_Y = 5

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
local activeAnchorPickerOverlay
local anchorPickerOutsideFrame

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

local function NormalizeTextOffset(value)
    value = tonumber(value) or 0
    if value ~= value or value == math.huge or value == -math.huge then
        value = 0
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

local function GetUnitConfigByKey(unitKey, editable)
    local normalizedUnit = NormalizeUnitKey(unitKey)
    if not normalizedUnit then
        return nil, nil
    end

    if editable == true then
        local resolver = FocalPoint.ActiveLayoutResolver
        if resolver and resolver.GetEditableActiveUnits then
            local units = resolver.GetEditableActiveUnits(FocalPoint.db)
            if type(units) == "table" then
                return units[normalizedUnit], normalizedUnit
            end
        end
        return nil, normalizedUnit
    end

    if UnitUtils.GetUnitDB then
        return UnitUtils.GetUnitDB(normalizedUnit), normalizedUnit
    end

    return nil, normalizedUnit
end

local function IsEditorActive()
    return FocalPoint
        and FocalPoint.framesUnlocked == true
        and FocalPoint.IsEditorActive
        and FocalPoint:IsEditorActive()
end

local function GetEditorStateApi()
    return FocalPoint
        and FocalPoint.GUI
        and FocalPoint.GUI.Editor
        and FocalPoint.GUI.Editor.State
        or nil
end

local function SelectTextObject(frame, textKey)
    return TextEditorOverlay.Select(frame, textKey)
end

local function IsSelectedText(frame, textKey)
    local stateApi = GetEditorStateApi()
    local normalizedUnit = NormalizeUnitKey(frame and frame._fpUnit)
    return stateApi
        and stateApi.IsTextElementSelected
        and stateApi.IsTextElementSelected(normalizedUnit, textKey) == true
        or false
end

local function IsTextInteractionActive(frame, textKey)
    return IsEditorActive() and IsSelectedText(frame, textKey)
end

local function GetTextConfig(frame, textKey)
    local unitConfig = frame and frame.config or nil
    local normalizedUnit = frame and NormalizeUnitKey(frame._fpUnit) or nil
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

local function ResolveTextAnchor(frame, textConfig)
    local factory = FocalPoint and FocalPoint.UnitFrameFactory or nil
    if factory and factory.GetAnchorTarget then
        return factory.GetAnchorTarget(frame, textConfig and textConfig.anchorTo) or frame
    end

    return frame
end

local function ResolveTextHitboxSize(textConfig)
    local fontSize = tonumber(textConfig and textConfig.fontSize) or 12
    local width = math.max(HITBOX_WIDTH, math.floor(fontSize * 8 + 0.5))
    local height = math.max(HITBOX_HEIGHT, math.floor(fontSize + (VISUAL_PADDING_Y * 2) + 0.5))
    return width, height
end

local function IsUsableTextVisualTarget(textObject)
    if not textObject or not textObject.GetObjectType then
        return false
    end
    if textObject.IsShown and not textObject:IsShown() then
        return false
    end
    return true
end

local function PositionSafeTextHitbox(overlay, frame, textConfig)
    if not (overlay and frame and type(textConfig) == "table") then
        return false
    end

    local anchor = ResolveTextAnchor(frame, textConfig)
    if not anchor then
        return false
    end

    local width, height = ResolveTextHitboxSize(textConfig)
    overlay:SetSize(width, height)
    overlay:SetPoint(
        textConfig.point or "CENTER",
        anchor,
        textConfig.relativePoint or "CENTER",
        textConfig.offsetX or 0,
        textConfig.offsetY or 0
    )
    return true
end

local function PositionTextVisualChrome(visual, overlay, textObject)
    if not visual then
        return
    end

    visual:ClearAllPoints()
    if IsUsableTextVisualTarget(textObject) then
        visual:SetPoint("TOPLEFT", textObject, "TOPLEFT", -VISUAL_PADDING_X, VISUAL_PADDING_Y)
        visual:SetPoint("BOTTOMRIGHT", textObject, "BOTTOMRIGHT", VISUAL_PADDING_X, -VISUAL_PADDING_Y)
    else
        visual:SetAllPoints(overlay)
    end
end

local function IsValidAnchorPoint(point)
    return type(point) == "string" and VALID_ANCHOR_POINTS[point] == true
end

local AUTO_ANCHOR_PAIRS = {
    top = { left = { "BOTTOMRIGHT", "TOPLEFT" }, center = { "BOTTOM", "TOP" }, right = { "BOTTOMLEFT", "TOPRIGHT" } },
    center = { left = { "RIGHT", "LEFT" }, center = { "CENTER", "CENTER" }, right = { "LEFT", "RIGHT" } },
    bottom = { left = { "TOPRIGHT", "BOTTOMLEFT" }, center = { "TOP", "BOTTOM" }, right = { "TOPLEFT", "BOTTOMRIGHT" } },
}

local function GetRectAnchor(rect, point)
    local x = (rect.left + rect.right) / 2
    local y = (rect.top + rect.bottom) / 2
    if point:find("LEFT", 1, true) then x = rect.left elseif point:find("RIGHT", 1, true) then x = rect.right end
    if point:find("TOP", 1, true) then y = rect.top elseif point:find("BOTTOM", 1, true) then y = rect.bottom end
    return x, y
end

function TextEditorOverlay.ResolveAutoAnchorGeometry(textRect, ownerRect)
    if type(textRect) ~= "table" or type(ownerRect) ~= "table" then return nil end
    for _, rect in ipairs({ textRect, ownerRect }) do
        if type(rect.left) ~= "number" or type(rect.right) ~= "number" or type(rect.top) ~= "number" or type(rect.bottom) ~= "number" or rect.left >= rect.right or rect.bottom >= rect.top then return nil end
    end
    local centerX = (textRect.left + textRect.right) / 2
    local centerY = (textRect.top + textRect.bottom) / 2
    local width, height = ownerRect.right - ownerRect.left, ownerRect.top - ownerRect.bottom
    local horizontal = centerX < ownerRect.left and "left" or centerX > ownerRect.right and "right" or centerX < ownerRect.left + width / 3 and "left" or centerX > ownerRect.left + width * 2 / 3 and "right" or "center"
    local vertical = centerY < ownerRect.bottom and "bottom" or centerY > ownerRect.top and "top" or centerY < ownerRect.bottom + height / 3 and "bottom" or centerY > ownerRect.bottom + height * 2 / 3 and "top" or "center"
    local pair = AUTO_ANCHOR_PAIRS[vertical][horizontal]
    local textX, textY = GetRectAnchor(textRect, pair[1])
    local ownerX, ownerY = GetRectAnchor(ownerRect, pair[2])
    return { point = pair[1], relativePoint = pair[2], offsetX = textX - ownerX, offsetY = textY - ownerY }
end
local function GetFrameRect(frame)
    if not (frame and frame.GetLeft and frame.GetRight and frame.GetTop and frame.GetBottom) then return nil end
    local left, right, top, bottom = frame:GetLeft(), frame:GetRight(), frame:GetTop(), frame:GetBottom()
    if type(left) ~= "number" or type(right) ~= "number" or type(top) ~= "number" or type(bottom) ~= "number" or left >= right or bottom >= top then return nil end
    return { left = left, right = right, top = top, bottom = bottom }
end
local StyleOverlay
local EndTextDrag
local UpdateAnchorToggleButton
local HideAnchorPicker
local EnsureAnchorPicker
local RefreshAnchorPickerButtons

local function IsMouseOverRegion(region)
    return region
        and region.IsShown
        and region:IsShown()
        and MouseIsOver
        and MouseIsOver(region) == true
        or false
end

local function GetTooltipOwner()
    if GameTooltip and GameTooltip.GetOwner then
        return GameTooltip:GetOwner()
    end
    return nil
end

local function HideTooltipFor(owner)
    if owner and GameTooltip and GameTooltip.Hide and GetTooltipOwner() == owner then
        GameTooltip:Hide()
    end
end

local function HideFrameIfShown(frame)
    if frame and frame.Hide and (not frame.IsShown or frame:IsShown()) then
        frame:Hide()
    end
end

local function HideAnchorTooltipForOverlay(overlay)
    local owner = GetTooltipOwner()
    if not owner or not overlay or not GameTooltip or not GameTooltip.Hide then
        return
    end

    if owner == overlay.AnchorToggleButton then
        GameTooltip:Hide()
        return
    end

    local picker = overlay.AnchorPicker
    for _, button in ipairs((picker and picker.Buttons) or {}) do
        if owner == button then
            GameTooltip:Hide()
            return
        end
    end
end

local function EnsureAnchorPickerOutsideFrame()
    if anchorPickerOutsideFrame then
        return anchorPickerOutsideFrame
    end

    local frame = CreateFrame("Frame")
    frame:SetScript("OnEvent", function(_, event)
        if event ~= "GLOBAL_MOUSE_DOWN" then
            return
        end

        local overlay = activeAnchorPickerOverlay
        if not overlay then
            return
        end

        local picker = overlay.AnchorPicker
        local toggle = overlay.AnchorToggleButton
        if IsMouseOverRegion(picker) or IsMouseOverRegion(toggle) then
            return
        end

        HideAnchorPicker(overlay)
    end)

    anchorPickerOutsideFrame = frame
    return frame
end

local function SetAnchorPickerOutsideActive(active)
    local frame = active and EnsureAnchorPickerOutsideFrame() or anchorPickerOutsideFrame
    if not frame then
        return
    end

    if active then
        frame:RegisterEvent("GLOBAL_MOUSE_DOWN")
    else
        frame:UnregisterEvent("GLOBAL_MOUSE_DOWN")
    end
end

HideAnchorPicker = function(overlay)
    local picker = overlay and overlay.AnchorPicker
    HideFrameIfShown(picker)
    if overlay then
        overlay._focalPointAnchorPickerOpen = false
    end
    if activeAnchorPickerOverlay == overlay then
        activeAnchorPickerOverlay = nil
        SetAnchorPickerOutsideActive(false)
    end
    if UpdateAnchorToggleButton then
        UpdateAnchorToggleButton(overlay, false)
    end
    HideAnchorTooltipForOverlay(overlay)
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

UpdateAnchorToggleButton = function(overlay, hovered)
    local button = overlay and overlay.AnchorToggleButton
    if not button then
        return
    end

    local open = overlay._focalPointAnchorPickerOpen == true
    local bg = button.Background
    local label = button.Label
    if open then
        if bg then
            bg:SetColorTexture(1.00, 0.76, 0.22, 0.92)
        end
        if label then
            label:SetTextColor(0.08, 0.06, 0.02, 1)
        end
    elseif hovered then
        if bg then
            bg:SetColorTexture(0.92, 0.82, 0.52, 0.70)
        end
        if label then
            label:SetTextColor(1.00, 0.94, 0.76, 1)
        end
    else
        if bg then
            bg:SetColorTexture(0.16, 0.17, 0.18, 0.94)
        end
        if label then
            label:SetTextColor(0.92, 0.84, 0.58, 1)
        end
    end
end

local function PositionAnchorPicker(overlay, picker)
    if not overlay or not picker then
        return
    end

    picker:ClearAllPoints()
    if overlay.AnchorToggleButton then
        picker:SetPoint("TOPRIGHT", overlay.AnchorToggleButton, "BOTTOMRIGHT", 0, PICKER_OFFSET_Y)
    elseif overlay.VisualBounds then
        picker:SetPoint("TOPLEFT", overlay.VisualBounds, "BOTTOMLEFT", 0, PICKER_OFFSET_Y)
    else
        picker:SetPoint("TOPLEFT", overlay, "BOTTOMLEFT", 0, PICKER_OFFSET_Y)
    end
end

local function PositionAnchorToggleButton(overlay, button)
    if not overlay or not button then
        return
    end

    button:ClearAllPoints()
    if overlay.VisualBounds then
        button:SetPoint("TOPRIGHT", overlay.VisualBounds, "TOPRIGHT", ANCHOR_TOGGLE_OFFSET_X, ANCHOR_TOGGLE_OFFSET_Y)
    else
        button:SetPoint("TOPRIGHT", overlay, "TOPRIGHT", ANCHOR_TOGGLE_OFFSET_X, ANCHOR_TOGGLE_OFFSET_Y)
    end
end

local function ShowAnchorPicker(overlay)
    if not overlay or IsCombatLocked() or not IsTextInteractionActive(overlay._focalPointOwnerFrame, overlay._focalPointTextKey) then
        return
    end
    if overlay._focalPointSelected ~= true then
        return
    end

    local textConfig = GetTextConfig(overlay._focalPointOwnerFrame, overlay._focalPointTextKey)
    if type(textConfig) ~= "table" or not IsEditorRenderableText(overlay._focalPointOwnerFrame, overlay._focalPointTextKey, textConfig) then
        return
    end

    if activeAnchorPickerOverlay and activeAnchorPickerOverlay ~= overlay then
        HideAnchorPicker(activeAnchorPickerOverlay)
    end

    local picker = EnsureAnchorPicker(overlay)
    if not picker then
        return
    end

    activeAnchorPickerOverlay = overlay
    overlay._focalPointAnchorPickerOpen = true
    picker._focalPointOwnerOverlay = overlay
    PositionAnchorPicker(overlay, picker)
    RefreshAnchorPickerButtons(picker, textConfig)
    if not picker.IsShown or not picker:IsShown() then
        picker:Show()
    end
    UpdateAnchorToggleButton(overlay, false)
    SetAnchorPickerOutsideActive(true)
end

local function ToggleAnchorPicker(overlay)
    if not overlay or activeDragOverlay == overlay then
        return
    end

    if overlay._focalPointAnchorPickerOpen == true then
        HideAnchorPicker(overlay)
    else
        ShowAnchorPicker(overlay)
    end
end

local function EnsureAnchorToggleButton(overlay)
    if not overlay then
        return nil
    end
    if overlay.AnchorToggleButton then
        return overlay.AnchorToggleButton
    end

    local button = CreateFrame("Button", nil, overlay)
    button:SetFrameStrata("FULLSCREEN")
    button:SetFrameLevel(PICKER_BUTTON_FRAME_LEVEL)
    button:SetSize(ANCHOR_TOGGLE_SIZE, ANCHOR_TOGGLE_SIZE)
    button:RegisterForClicks("LeftButtonUp")
    button:EnableMouse(true)
    button:EnableMouseWheel(true)
    button:Hide()

    local bg = button:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(button)
    button.Background = bg
    CreateBorderTextures(button)
    SetFullBorderVisible(button, true)
    SetBorderStyle(button, 0.82, 0.68, 0.32, 0.82, 1)

    local label = button:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    label:SetAllPoints(button)
    label:SetJustifyH("CENTER")
    label:SetJustifyV("MIDDLE")
    label:SetText("A")
    button.Label = label

    button:SetScript("OnEnter", function(self)
        self._focalPointHovered = true
        UpdateAnchorToggleButton(overlay, true)
        if GameTooltip then
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            if GameTooltip.ClearLines then
                GameTooltip:ClearLines()
            end
            GameTooltip:AddLine("Anchors", 1, 1, 1, true)
            GameTooltip:AddLine("Choose the text element's anchor point.", 0.82, 0.84, 0.86, true)
            GameTooltip:AddLine("Click to open or close the anchor picker.", 0.72, 0.74, 0.76, true)
            GameTooltip:Show()
        end
    end)
    button:SetScript("OnLeave", function(self)
        self._focalPointHovered = false
        UpdateAnchorToggleButton(overlay, false)
        HideTooltipFor(self)
    end)
    button:SetScript("OnClick", function(_, buttonName)
        if buttonName ~= "LeftButton" then
            return
        end
        ToggleAnchorPicker(overlay)
    end)
    button:SetScript("OnMouseWheel", function()
    end)

    overlay.AnchorToggleButton = button
    UpdateAnchorToggleButton(overlay, false)
    return button
end

EnsureAnchorPicker = function(overlay)
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
            HideTooltipFor(self)
        end)
        button:SetScript("OnClick", function(self, buttonName)
            if buttonName ~= "LeftButton" then
                return
            end
            HideTooltipFor(self)
            local owner = picker._focalPointOwnerOverlay
            TextEditorOverlay.SetAnchor(owner and owner._focalPointOwnerFrame, owner and owner._focalPointTextKey, self._focalPointAnchorPoint)
            HideAnchorPicker(owner)
        end)
        button:SetScript("OnMouseWheel", function()
        end)

        picker.Buttons[#picker.Buttons + 1] = button
    end

    overlay.AnchorPicker = picker
    picker._focalPointOwnerOverlay = overlay
    return picker
end

RefreshAnchorPickerButtons = function(picker, textConfig)
    if not picker then
        return
    end

    local activePoint = nil
    if type(textConfig) == "table" and textConfig.point == textConfig.relativePoint and IsValidAnchorPoint(textConfig.point) then
        activePoint = textConfig.point
    end

    for _, button in ipairs(picker.Buttons or {}) do
        button._focalPointAnchorActive = button._focalPointAnchorPoint == activePoint
        StylePickerButton(button, button._focalPointAnchorActive == true, button._focalPointAnchorHovered == true)
    end
end

local function UpdateAnchorPicker(overlay, selected, textConfig)
    if not overlay then
        return
    end
    if not selected or IsCombatLocked() or not IsTextInteractionActive(overlay._focalPointOwnerFrame, overlay._focalPointTextKey) or type(textConfig) ~= "table" then
        HideAnchorPicker(overlay)
        if overlay.AnchorToggleButton then
            HideFrameIfShown(overlay.AnchorToggleButton)
        end
        return
    end

    local toggle = EnsureAnchorToggleButton(overlay)
    if toggle then
        PositionAnchorToggleButton(overlay, toggle)
        if not toggle.IsShown or not toggle:IsShown() then
            toggle:Show()
        end
        UpdateAnchorToggleButton(overlay, toggle._focalPointHovered == true)
    end

    local picker = overlay.AnchorPicker
    if picker then
        picker._focalPointOwnerOverlay = overlay
        PositionAnchorPicker(overlay, picker)
    end

    if picker then
        RefreshAnchorPickerButtons(picker, textConfig)

        if overlay._focalPointAnchorPickerOpen == true then
            if not picker.IsShown or not picker:IsShown() then
                picker:Show()
            end
        elseif not picker.IsShown or picker:IsShown() then
            HideFrameIfShown(picker)
        end
    end
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
    overlay:RegisterForDrag("LeftButton")
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
    overlay:SetScript("OnDragStart", function(self)
        TextEditorOverlay.StartDrag(self)
    end)
    overlay:SetScript("OnDragStop", function(self)
        EndTextDrag(self, true)
    end)
    overlay:SetScript("OnEnter", function(self)
        self._focalPointHovered = true
        local canvasHover = FocalPoint.GUI
            and FocalPoint.GUI.Editor
            and FocalPoint.GUI.Editor.CanvasHoverOverlay
        if canvasHover and canvasHover.SetHover then
            canvasHover.SetHover(self, {
                kind = "text",
                unit = self._focalPointOwnerFrame and self._focalPointOwnerFrame.unit or nil,
                textKey = self._focalPointTextKey,
                objectKey = self._focalPointTextKey,
                sectionKey = "texts",
            })
        end
        StyleOverlay(self, self._focalPointSelected == true, true)
    end)
    overlay:SetScript("OnLeave", function(self)
        self._focalPointHovered = false
        local canvasHover = FocalPoint.GUI
            and FocalPoint.GUI.Editor
            and FocalPoint.GUI.Editor.CanvasHoverOverlay
        if canvasHover and canvasHover.Clear then
            canvasHover.Clear(self)
        end
        StyleOverlay(self, self._focalPointSelected == true, false)
    end)
    overlay:SetScript("OnClick", function(self, button)
        if self._focalPointSuppressClick then
            self._focalPointSuppressClick = nil
            return
        end

        if button == "RightButton" then
            local selected = SelectTextObject(self._focalPointOwnerFrame, self._focalPointTextKey)
            local contextMenu = FocalPoint.GUI
                and FocalPoint.GUI.Editor
                and FocalPoint.GUI.Editor.FrameContextMenu
            if selected and contextMenu and contextMenu.ShowForText then
                contextMenu.ShowForText(self._focalPointOwnerFrame, self._focalPointTextKey)
            end
            return
        elseif button == "LeftButton" then
            SelectTextObject(self._focalPointOwnerFrame, self._focalPointTextKey)
        end
    end)
    overlay:SetScript("OnMouseWheel", function(self, delta)
        TextEditorOverlay.AdjustFontSize(self._focalPointOwnerFrame, self._focalPointTextKey, delta)
    end)
    overlay:SetScript("OnHide", function(self)
        EndTextDrag(self, false)
        HideAnchorPicker(self)
        if self.AnchorToggleButton then
            HideFrameIfShown(self.AnchorToggleButton)
        end
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
        if overlay.AnchorToggleButton then
            HideFrameIfShown(overlay.AnchorToggleButton)
        end
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
    elseif FocalPoint.RefreshUnitFrame and frame and frame._fpUnit then
        FocalPoint:RefreshUnitFrame(frame._fpUnit)
    end

    TextEditorOverlay.UpdateFrame(frame)

    if FocalPoint.GUI and FocalPoint.GUI.RequestRefreshOptions then
        FocalPoint.GUI:RequestRefreshOptions("TextEditorOverlay.TextMutation")
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

local function CommitTextAnchorPositionNow(frame, textKey, position)
    local unitConfig, normalizedUnit = GetUnitConfigByKey(frame and frame._fpUnit, true)
    if type(unitConfig) ~= "table" or not normalizedUnit or type(position) ~= "table" then return false end
    local mutations = FocalPoint.InspectorMutations or (FocalPoint.GUI and FocalPoint.GUI.Editor and FocalPoint.GUI.Editor.Inspector and FocalPoint.GUI.Editor.Inspector.Mutations)
    if not (mutations and mutations.SetTextAnchorPosition) then return false end
    local result = mutations.SetTextAnchorPosition({ unitConfig = unitConfig }, textKey, position.point, position.relativePoint, position.offsetX, position.offsetY)
    if result and result.ok == false then return false end
    if result and result.changed then RefreshAfterTextPositionCommit(frame) else TextEditorOverlay.UpdateFrame(frame) end
    return true
end
local function CommitTextPositionNow(frame, textKey, offsetX, offsetY)
    local unitConfig, normalizedUnit = GetUnitConfigByKey(frame and frame._fpUnit, true)
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

local function CommitTextAnchorNow(frame, textKey, point, relativePoint)
    local unitConfig, normalizedUnit = GetUnitConfigByKey(frame and frame._fpUnit, true)
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

local function CommitTextPositionResetNow(frame, textKey)
    local unitConfig, normalizedUnit = GetUnitConfigByKey(frame and frame._fpUnit, true)
    if type(unitConfig) ~= "table" or not normalizedUnit then
        return false
    end

    local mutations = FocalPoint.InspectorMutations
        or (FocalPoint.GUI and FocalPoint.GUI.Editor and FocalPoint.GUI.Editor.Inspector and FocalPoint.GUI.Editor.Inspector.Mutations)
    if not (mutations and mutations.ResetTextPosition) then
        return false
    end

    local result = mutations.ResetTextPosition({
        unitConfig = unitConfig,
        unitKey = normalizedUnit,
    }, textKey)
    if result and result.ok == false then
        return false
    end

    ClearPreviewOffset(frame, textKey)
    if result and result.changed then
        RefreshSingleTextElement(frame, textKey)
        if FocalPoint.GUI and FocalPoint.GUI.RequestRefreshOptions then
            FocalPoint.GUI:RequestRefreshOptions("TextEditorOverlay.TextMutation")
        end
        if FocalPoint.RefreshEditorSelectionVisuals then
            FocalPoint:RefreshEditorSelectionVisuals()
        end
    else
        TextEditorOverlay.UpdateFrame(frame)
    end

    return true
end

local function RequestEditableTextCommit(commit)
    local workflow = FocalPoint.LayoutEditWorkflow
    if not (workflow and workflow.RequestEditableLayoutForMutation) then return false end
    local completed = false
    workflow.RequestEditableLayoutForMutation(function() completed = commit() == true end)
    return completed
end

local function CommitTextAnchorPosition(frame, textKey, position)
    return RequestEditableTextCommit(function() return CommitTextAnchorPositionNow(frame, textKey, position) end)
end
local function CommitTextPosition(frame, textKey, offsetX, offsetY)
    return RequestEditableTextCommit(function() return CommitTextPositionNow(frame, textKey, offsetX, offsetY) end)
end
local function CommitTextAnchor(frame, textKey, point, relativePoint)
    return RequestEditableTextCommit(function() return CommitTextAnchorNow(frame, textKey, point, relativePoint) end)
end
local function CommitTextPositionReset(frame, textKey)
    return RequestEditableTextCommit(function() return CommitTextPositionResetNow(frame, textKey) end)
end
local function CommitTextFontSizeResetNow(frame, textKey)
    local unitConfig, normalizedUnit = GetUnitConfigByKey(frame and frame._fpUnit, true)
    if type(unitConfig) ~= "table" or not normalizedUnit then
        return false
    end

    local mutations = FocalPoint.InspectorMutations
        or (FocalPoint.GUI and FocalPoint.GUI.Editor and FocalPoint.GUI.Editor.Inspector and FocalPoint.GUI.Editor.Inspector.Mutations)
    if not (mutations and mutations.ResetTextFontSize) then
        return false
    end

    local result = mutations.ResetTextFontSize({
        unitConfig = unitConfig,
        unitKey = normalizedUnit,
    }, textKey)
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

local function CommitTextFontSizeReset(frame, textKey)
    return RequestEditableTextCommit(function() return CommitTextFontSizeResetNow(frame, textKey) end)
end

local function CommitTextFontSizeAdjustment(frame, textKey, delta)
    local unitConfig, normalizedUnit = GetUnitConfigByKey(frame and frame._fpUnit, true)
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

    local unitConfig = GetUnitConfigByKey(state.frame and state.frame._fpUnit)
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
    if state.mode == "unit" then
        if state.dragging and FocalPoint.EndEditorUnitFrameDrag then
            FocalPoint:EndEditorUnitFrameDrag(state.frame, commit == true)
        end
        if commit and state.dragging then
            overlay._focalPointSuppressClick = true
            TextEditorOverlay.Select(state.frame, state.textKey)
        end
        return
    end

    if not state.dragging then
        return
    end

    if commit == false or IsCombatLocked() or not IsEditorActive() or not IsDragContextStillValid(state) then
        RestoreTextPositionPreview(state.frame, state.textKey)
        return
    end

    local textObject = state.frame and state.frame.Texts and state.frame.Texts[state.textKey]
    local owner = ResolveTextAnchor(state.frame, state.textConfig)
    local position = TextEditorOverlay.ResolveAutoAnchorGeometry(GetFrameRect(textObject), GetFrameRect(owner))
    if not position then
        RestoreTextPositionPreview(state.frame, state.textKey)
        return
    end

    overlay._focalPointSuppressClick = true
    ClearPreviewOffset(state.frame, state.textKey)
    if not CommitTextAnchorPosition(state.frame, state.textKey, position) then
        RestoreTextPositionPreview(state.frame, state.textKey)
    end
    TextEditorOverlay.Select(state.frame, state.textKey)
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
            if overlay.AnchorToggleButton then
                HideFrameIfShown(overlay.AnchorToggleButton)
            end
            if overlay.VisualBounds and overlay.VisualBounds.Hide then
                overlay.VisualBounds:ClearAllPoints()
                overlay.VisualBounds:Hide()
            end
        end
    end
end

function TextEditorOverlay.UpdateFrame(frame)
    if not frame then
        return
    end

    if not IsEditorActive() then
        TextEditorOverlay.HideFrame(frame)
        return
    end

    local texts = frame.config and frame.config.Texts
    if type(texts) ~= "table" then
        TextEditorOverlay.HideFrame(frame)
        return
    end

    local stateApi = GetEditorStateApi()
    local normalizedUnit = NormalizeUnitKey(frame._fpUnit)
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

                if not PositionSafeTextHitbox(overlay, frame, textConfig) then
                    overlay:SetSize(HITBOX_WIDTH, HITBOX_HEIGHT)
                    overlay:SetPoint("CENTER", frame, "CENTER", 0, 0)
                end

                local visual = overlay.VisualBounds
                if visual then
                    visual:SetFrameStrata("FULLSCREEN")
                    PositionTextVisualChrome(visual, overlay, textObject)
                end

                local selected = stateApi
                    and stateApi.IsTextElementSelected
                    and stateApi.IsTextElementSelected(normalizedUnit, textKey)
                    or false
                overlay._focalPointSelected = selected == true
                StyleOverlay(overlay, overlay._focalPointSelected, overlay._focalPointHovered == true)
                UpdateAnchorPicker(overlay, overlay._focalPointSelected, textConfig)
                overlay:EnableMouse(true)
                overlay:EnableMouseWheel(overlay._focalPointSelected == true and IsTextInteractionActive(frame, textKey))
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
                if overlay.AnchorToggleButton then
                    HideFrameIfShown(overlay.AnchorToggleButton)
                end
                if overlay.VisualBounds and overlay.VisualBounds.Hide then
                    overlay.VisualBounds:ClearAllPoints()
                    overlay.VisualBounds:Hide()
                end
            end
        end
    end
end

function TextEditorOverlay.BeginDrag(overlay)
    if not overlay or IsCombatLocked() or not IsEditorActive() then
        return false
    end
    HideAnchorPicker(overlay)

    local frame = overlay._focalPointOwnerFrame
    local textKey = overlay._focalPointTextKey
    local unitConfig = GetUnitConfigByKey(frame and frame._fpUnit)
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

    local interactionMode = FocalPoint.GUI
        and FocalPoint.GUI.Editor
        and FocalPoint.GUI.Editor.InteractionMode
    local moveText = interactionMode
        and interactionMode.IsShiftDown
        and interactionMode.IsShiftDown()

    local cursorX, cursorY = GetCursorPositionInUiScale()
    if not cursorX or not cursorY then
        return false
    end

    overlay._focalPointSuppressClick = nil
    local dragState = {
        hitTarget = overlay,
        selectionTarget = {
            kind = "text",
            unit = NormalizeUnitKey(frame._fpUnit),
            textKey = textKey,
            objectKey = textKey,
        },
        movementOwner = moveText and overlay or frame,
        mode = moveText and "text" or "unit",
        frame = frame,
        textKey = textKey,
        unitConfig = unitConfig,
        textConfig = textConfig,
        startCursorX = cursorX,
        startCursorY = cursorY,
        startOffsetX = NormalizeTextOffset(textConfig.offsetX),
        startOffsetY = NormalizeTextOffset(textConfig.offsetY),
        currentOffsetX = NormalizeTextOffset(textConfig.offsetX),
        currentOffsetY = NormalizeTextOffset(textConfig.offsetY),
        dragging = false,
    }
    overlay._focalPointTextDragState = dragState
    activeDragOverlay = overlay

    return true
end

function TextEditorOverlay.StartDrag(overlay)
    local dragState = overlay and overlay._focalPointTextDragState
    if not dragState or dragState.dragging or IsCombatLocked() or not IsEditorActive() then
        return false
    end

    if dragState.mode == "unit" then
        if not FocalPoint.BeginEditorUnitFrameDrag
            or not FocalPoint:BeginEditorUnitFrameDrag(dragState.movementOwner, {
                moveOnlyOwner = true,
                gesture = dragState,
            }) then
            EndTextDrag(overlay, false)
            return false
        end

        dragState.dragging = true
        overlay._focalPointSuppressClick = true
        return true
    end

    dragState.dragging = true
    overlay._focalPointSuppressClick = true
    overlay:SetScript("OnUpdate", function(self)
        local dragState = self._focalPointTextDragState
        if not dragState then
            self:SetScript("OnUpdate", nil)
            return
        end
        if IsCombatLocked() or not IsEditorActive() or not IsDragContextStillValid(dragState) then
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
        local nextOffsetX = NormalizeTextOffset(dragState.startOffsetX + deltaX)
        local nextOffsetY = NormalizeTextOffset(dragState.startOffsetY + deltaY)
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
    if IsCombatLocked() or not IsTextInteractionActive(frame, textKey) then
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
    if IsCombatLocked() or not IsTextInteractionActive(frame, textKey) or activeDragOverlay then
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
    local normalizedUnit = NormalizeUnitKey(frame._fpUnit)
    local selected = stateApi
        and stateApi.IsTextElementSelected
        and stateApi.IsTextElementSelected(normalizedUnit, textKey)
        or false
    if selected ~= true then
        return false
    end

    return CommitTextFontSizeAdjustment(frame, textKey, delta)
end

function TextEditorOverlay.ResetPosition(frame, textKey)
    if IsCombatLocked() or not IsTextInteractionActive(frame, textKey) then
        return false
    end
    if not frame or type(textKey) ~= "string" or textKey == "" then
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
    return CommitTextPositionReset(frame, textKey)
end

function TextEditorOverlay.ResetSize(frame, textKey)
    if IsCombatLocked() or not IsTextInteractionActive(frame, textKey) then
        return false
    end
    if not frame or type(textKey) ~= "string" or textKey == "" then
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
    return CommitTextFontSizeReset(frame, textKey)
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
    if type(GetTextConfig(frame, textKey)) ~= "table" then
        return false
    end

    local stateApi = GetEditorStateApi()
    local normalizedUnit = NormalizeUnitKey(frame._fpUnit)
    if not normalizedUnit then
        return false
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

    local objectSelection = FocalPoint.GUI
        and FocalPoint.GUI.Editor
        and FocalPoint.GUI.Editor.ObjectSelection
    if objectSelection and objectSelection.SelectObject then
        if objectSelection.SelectObject({
            kind = "text",
            unit = normalizedUnit,
            textKey = textKey,
            objectKey = textKey,
            sectionKey = "texts",
        }) ~= true then
            return false
        end
        return true
    else
        if FocalPoint.SelectEditorUnit then
            FocalPoint:SelectEditorUnit(normalizedUnit)
        elseif stateApi and stateApi.SetSingleSelection then
            stateApi.SetSingleSelection(normalizedUnit)
        end

        if stateApi and stateApi.SetSelectedTextElement then
            stateApi.SetSelectedTextElement(normalizedUnit, textKey)
        elseif stateApi and stateApi.SetSelectedTextId then
            stateApi.SetSelectedTextId(textKey)
        end
    end

    if FocalPoint.RefreshEditorSelectionVisuals then
        FocalPoint:RefreshEditorSelectionVisuals()
    end
    if FocalPoint.GUI and FocalPoint.GUI.RequestRefreshOptions then
        FocalPoint.GUI:RequestRefreshOptions("TextEditorOverlay.TextMutation")
    end

    return true
end

return TextEditorOverlay
