local _, FocalPoint = ...

FocalPoint.GUI = FocalPoint.GUI or {}
FocalPoint.GUI.Editor = FocalPoint.GUI.Editor or {}

local FrameResizeHandles = {}
FocalPoint.GUI.Editor.FrameResizeHandles = FrameResizeHandles

local L = FocalPoint.L or {}

local MIN_WIDTH = 120
local MAX_WIDTH = 420
local MIN_HEIGHT = 24
local MAX_HEIGHT = 120
local HANDLE_SIZE = 14

local activeHandle

local function T(key, fallback)
    return L[key] or fallback
end

local function ResolveColor(color, fallback)
    color = color or fallback or {}

    return {
        color[1] or color.r or fallback and fallback[1] or 1,
        color[2] or color.g or fallback and fallback[2] or 1,
        color[3] or color.b or fallback and fallback[3] or 1,
        color[4] or color.a or fallback and fallback[4] or 1,
    }
end

local function GetSkinColor(role, fallback)
    local skins = FocalPoint.GUI and FocalPoint.GUI.Skins
    local color = skins and skins.GetBrandColor and skins.GetBrandColor(role) or nil

    return ResolveColor(color, fallback)
end

local function Clamp(value, minValue, maxValue)
    value = tonumber(value) or minValue
    if value < minValue then
        return minValue
    end
    if value > maxValue then
        return maxValue
    end
    return math.floor(value + 0.5)
end

local function NormalizeUnitKey(unit)
    local utils = FocalPoint.UnitFrameUtils
    if utils and utils.NormalizeConfigUnitKey then
        return utils.NormalizeConfigUnitKey(unit)
    end
    if type(unit) == "string" and unit:match("^boss%d+$") then
        return "boss"
    end
    return unit
end

local function GetUnitConfig(frame)
    local unitKey = frame and NormalizeUnitKey(frame.unit) or nil
    if type(unitKey) ~= "string" or unitKey == "" then
        return nil, nil
    end

    local utils = FocalPoint.UnitFrameUtils
    if utils and utils.GetUnitDB then
        return utils.GetUnitDB(unitKey), unitKey
    end

    return FocalPoint.db
        and FocalPoint.db.profile
        and FocalPoint.db.profile.Units
        and FocalPoint.db.profile.Units[unitKey], unitKey
end

local function IsEditorUnlocked()
    return FocalPoint.framesUnlocked == true
        and FocalPoint.IsEditorActive
        and FocalPoint:IsEditorActive()
end

local function IsCombatLocked()
    return InCombatLockdown and InCombatLockdown()
end

local function PrintMessage(message)
    if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
        DEFAULT_CHAT_FRAME:AddMessage("|cffEA7500Focal Point|r " .. tostring(message))
    elseif print then
        print("Focal Point " .. tostring(message))
    end
end

local function RefreshEditorForUnit(unitKey)
    if FocalPoint.RefreshUnitFrame then
        FocalPoint:RefreshUnitFrame(unitKey)
    elseif FocalPoint.RefreshAllFrames then
        FocalPoint:RefreshAllFrames()
    end

    if FocalPoint.GUI and FocalPoint.GUI.RequestRefreshOptions then
        FocalPoint.GUI:RequestRefreshOptions()
    end

    if FocalPoint.RefreshEditorSelectionVisuals then
        FocalPoint:RefreshEditorSelectionVisuals()
    end
end

local function SelectFrameForResize(frame)
    if not frame or type(frame.unit) ~= "string" then
        return
    end

    local unitKey = NormalizeUnitKey(frame.unit)
    local editorState = FocalPoint.GUI and FocalPoint.GUI.Editor and FocalPoint.GUI.Editor.State
    local currentState = editorState and editorState.Get and editorState.Get() or nil
    if currentState and currentState.selectedUnit ~= unitKey and FocalPoint.SelectEditorUnit then
        FocalPoint:SelectEditorUnit(unitKey)
        return
    end

    if editorState and editorState.SetSelectedUnit then
        editorState.SetSelectedUnit(unitKey)
    end

    if FocalPoint.RefreshEditorSelectionVisuals then
        FocalPoint:RefreshEditorSelectionVisuals()
    end
end

local function ApplyPreviewSize(frame, width, baseHeight, bottomExtension)
    if not frame or not frame.SetSize then
        return
    end

    frame:SetSize(width, baseHeight + bottomExtension)
end

local function UpdateHandleVisual(handle)
    if not handle then
        return
    end

    local orange = GetSkinColor("orangeStrong", { 0.918, 0.459, 0.000, 0.85 })

    if handle.bg then
        handle.bg:SetColorTexture(0.08, 0.07, 0.05, 0.94)
    end
    if handle.border then
        handle.border:SetBackdropBorderColor(orange[1], orange[2], orange[3], orange[4])
    end
    if handle.diagonalA then
        handle.diagonalA:SetColorTexture(orange[1], orange[2], orange[3], 0.72)
    end
    if handle.diagonalB then
        handle.diagonalB:SetColorTexture(orange[1], orange[2], orange[3], 0.46)
    end
end

local function EnsureSizeLabel(frame)
    local overlay = frame and frame.MoveOverlay
    if not overlay then
        return nil
    end

    if overlay.ResizeSizeLabel then
        return overlay.ResizeSizeLabel
    end

    local label = overlay:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    label:SetPoint("TOPLEFT", overlay, "TOPLEFT", 6, -24)
    label:SetFont(STANDARD_TEXT_FONT, 14, "OUTLINE")
    label:SetTextColor(0.918, 0.459, 0.000, 0.98)
    label:SetShadowOffset(1, -1)
    label:SetShadowColor(0, 0, 0, 0.85)
    label:Hide()
    if label.SetJustifyH then
        label:SetJustifyH("LEFT")
    end

    overlay.ResizeSizeLabel = label
    return label
end

local function SetSizeLabel(frame, width, height, shown)
    local label = EnsureSizeLabel(frame)
    if not label then
        return
    end

    if shown then
        label:SetText(string.format(T("EDITOR_RESIZE_SIZE_LABEL", "W: %d  H: %d"), width or 0, height or 0))
        label:Show()
    else
        label:Hide()
    end
end

local function EndResize(handle, commit)
    if not handle or not handle._resizeState then
        return
    end

    local state = handle._resizeState
    local frame = state.frame
    local config = state.config
    local unitKey = state.unitKey
    handle._resizeState = nil
    handle:SetScript("OnUpdate", nil)
    activeHandle = nil
    SetSizeLabel(frame, state.currentWidth or state.startWidth, state.currentHeight or state.startHeight, false)

    if commit and frame and type(config) == "table" and unitKey then
        config.width = state.currentWidth or state.startWidth
        config.height = state.currentHeight or state.startHeight
        RefreshEditorForUnit(unitKey)
    elseif frame then
        ApplyPreviewSize(frame, state.startWidth, state.startHeight, state.bottomExtension)
    end
end

local function BeginResize(handle)
    if not handle or not handle._targetFrame then
        return
    end

    if not IsEditorUnlocked() then
        return
    end

    if IsCombatLocked() then
        PrintMessage(T("EDITOR_RESIZE_STATUS_COMBAT", "Frame resizing is not available during combat."))
        return
    end

    local frame = handle._targetFrame
    local config, unitKey = GetUnitConfig(frame)
    if type(config) ~= "table" then
        return
    end

    SelectFrameForResize(frame)

    local contextMenu = FocalPoint.GUI
        and FocalPoint.GUI.Editor
        and FocalPoint.GUI.Editor.FrameContextMenu
    if contextMenu and contextMenu.Hide then
        contextMenu.Hide()
    end

    local scale = UIParent and UIParent.GetEffectiveScale and UIParent:GetEffectiveScale() or 1
    local cursorX, cursorY = GetCursorPosition()
    local startWidth = Clamp(config.width or (frame.GetWidth and frame:GetWidth()) or MIN_WIDTH, MIN_WIDTH, MAX_WIDTH)
    local visibleHeight = tonumber(frame.GetHeight and frame:GetHeight()) or tonumber(config.height) or MIN_HEIGHT
    local startHeight = Clamp(config.height or visibleHeight, MIN_HEIGHT, MAX_HEIGHT)
    local bottomExtension = math.max(0, visibleHeight - startHeight)

    handle._resizeState = {
        frame = frame,
        config = config,
        unitKey = unitKey,
        cursorX = (cursorX or 0) / scale,
        cursorY = (cursorY or 0) / scale,
        startWidth = startWidth,
        startHeight = startHeight,
        currentWidth = startWidth,
        currentHeight = startHeight,
        bottomExtension = bottomExtension,
    }
    activeHandle = handle
    SetSizeLabel(frame, startWidth, startHeight, true)

    handle:SetScript("OnUpdate", function(resizeHandle)
        local state = resizeHandle._resizeState
        if not state then
            return
        end
        if IsCombatLocked() then
            EndResize(resizeHandle, false)
            PrintMessage(T("EDITOR_RESIZE_STATUS_COMBAT", "Frame resizing is not available during combat."))
            return
        end

        local currentX, currentY = GetCursorPosition()
        currentX = (currentX or 0) / scale
        currentY = (currentY or 0) / scale

        local newWidth = Clamp(state.startWidth + (currentX - state.cursorX), MIN_WIDTH, MAX_WIDTH)
        local newHeight = Clamp(state.startHeight - (currentY - state.cursorY), MIN_HEIGHT, MAX_HEIGHT)
        state.currentWidth = newWidth
        state.currentHeight = newHeight

        ApplyPreviewSize(state.frame, newWidth, newHeight, state.bottomExtension)
        SetSizeLabel(state.frame, newWidth, newHeight, true)
    end)
end

local function CreateHandle(frame, overlay)
    local handle = CreateFrame("Button", nil, overlay, "BackdropTemplate")
    handle:SetSize(HANDLE_SIZE, HANDLE_SIZE)
    handle:SetPoint("BOTTOMRIGHT", overlay, "BOTTOMRIGHT", -2, 2)
    handle:SetFrameLevel((overlay.GetFrameLevel and overlay:GetFrameLevel() or 1) + 20)
    handle:EnableMouse(true)
    handle:RegisterForDrag("LeftButton")
    handle:Hide()
    handle._targetFrame = frame

    local bg = handle:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    handle.bg = bg

    handle.border = CreateFrame("Frame", nil, handle, "BackdropTemplate")
    handle.border:SetAllPoints()
    handle.border:SetBackdrop({
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
    })

    local diagonalA = handle:CreateTexture(nil, "ARTWORK")
    diagonalA:SetSize(8, 2)
    diagonalA:SetPoint("BOTTOMRIGHT", handle, "BOTTOMRIGHT", -2, 3)
    diagonalA:SetRotation(math.rad(-45))
    handle.diagonalA = diagonalA

    local diagonalB = handle:CreateTexture(nil, "ARTWORK")
    diagonalB:SetSize(5, 2)
    diagonalB:SetPoint("BOTTOMRIGHT", handle, "BOTTOMRIGHT", -2, 7)
    diagonalB:SetRotation(math.rad(-45))
    handle.diagonalB = diagonalB

    handle:SetScript("OnMouseDown", function(self, button)
        if button == "LeftButton" then
            BeginResize(self)
        end
    end)
    handle:SetScript("OnDragStart", function(self)
        if not self._resizeState then
            BeginResize(self)
        end
    end)
    handle:SetScript("OnMouseUp", function(self, button)
        if button == "LeftButton" then
            EndResize(self, true)
        elseif button == "RightButton" then
            local contextMenu = FocalPoint.GUI
                and FocalPoint.GUI.Editor
                and FocalPoint.GUI.Editor.FrameContextMenu
            if contextMenu and contextMenu.ShowForFrame then
                contextMenu.ShowForFrame(frame)
            end
        end
    end)
    handle:SetScript("OnDragStop", function(self)
        EndResize(self, true)
    end)
    handle:SetScript("OnHide", function(self)
        EndResize(self, false)
    end)

    UpdateHandleVisual(handle)
    return handle
end

function FrameResizeHandles.UpdateFrame(frame)
    if not frame or not frame.MoveOverlay then
        return
    end

    local overlay = frame.MoveOverlay
    local handle = frame.ResizeHandle
    if not handle and not IsCombatLocked() then
        handle = CreateHandle(frame, overlay)
        frame.ResizeHandle = handle
    end

    if not handle then
        return
    end

    handle:SetFrameLevel((overlay.GetFrameLevel and overlay:GetFrameLevel() or 1) + 20)
    UpdateHandleVisual(handle)

    if IsEditorUnlocked() and not IsCombatLocked() then
        handle:Show()
    else
        handle:Hide()
    end
end

function FrameResizeHandles.HideFrame(frame)
    if frame and frame.ResizeHandle then
        frame.ResizeHandle:Hide()
    end
end

function FrameResizeHandles.CancelAll()
    if activeHandle then
        EndResize(activeHandle, false)
    end

    if not FocalPoint.frames then
        return
    end

    for _, frame in pairs(FocalPoint.frames) do
        FrameResizeHandles.HideFrame(frame)
    end
end

return FrameResizeHandles
