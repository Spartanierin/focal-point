local _, FocalPoint = ...

FocalPoint.GUI = FocalPoint.GUI or {}
FocalPoint.GUI.Editor = FocalPoint.GUI.Editor or {}

local FrameContextMenu = {}
FocalPoint.GUI.Editor.FrameContextMenu = FrameContextMenu

local L = FocalPoint.L or {}

local clipboard = {
    size = nil,
    position = nil,
}

local SIZE_MIN_WIDTH = 120
local SIZE_MAX_WIDTH = 420
local SIZE_MIN_HEIGHT = 24
local SIZE_MAX_HEIGHT = 120

local function ResolveColor(color, fallback)
    color = color or fallback or {}

    return {
        color[1] or color.r or fallback and fallback[1] or 1,
        color[2] or color.g or fallback and fallback[2] or 1,
        color[3] or color.b or fallback and fallback[3] or 1,
        color[4] or color.a or fallback and fallback[4] or 1,
    }
end

local function GetSkinChromeColor(role, fallback)
    local skins = FocalPoint.GUI and FocalPoint.GUI.Skins
    local palette = skins and skins.GetFormPalette and skins.GetFormPalette() or nil
    local chrome = palette and palette.Chrome or nil

    return ResolveColor(chrome and chrome[role], fallback)
end

local function GetSkinBrandColor(role, fallback)
    local skins = FocalPoint.GUI and FocalPoint.GUI.Skins

    return ResolveColor(skins and skins.GetBrandColor and skins.GetBrandColor(role), fallback)
end

local function GetSkinButtonColor(state, role, fallback)
    local skins = FocalPoint.GUI and FocalPoint.GUI.Skins
    local visuals = skins and skins.GetEditorButtonVisuals and skins.GetEditorButtonVisuals() or nil
    local states = visuals and visuals.states or nil
    local stateColors = states and states[state] or nil

    return ResolveColor(stateColors and stateColors[role], fallback)
end

local function SetTextureColor(texture, color)
    if not texture or not color then
        return
    end

    texture:SetVertexColor(color[1], color[2], color[3], color[4])
end

local function SetTextColor(fontString, color)
    if not fontString or not color then
        return
    end

    fontString:SetTextColor(color[1], color[2], color[3], color[4])
end

local function T(key, fallback)
    return L[key] or fallback
end

local function Clamp(value, minValue, maxValue)
    value = tonumber(value)
    if not value then
        return nil
    end

    if value < minValue then
        return minValue
    end

    if value > maxValue then
        return maxValue
    end

    return math.floor(value + 0.5)
end

local function GetUnitKey(frame)
    if not frame or type(frame.unit) ~= "string" or frame.unit == "" then
        return nil
    end

    local utils = FocalPoint.UnitFrameUtils
    if utils and utils.NormalizeConfigUnitKey then
        return utils.NormalizeConfigUnitKey(frame.unit)
    end

    if frame.unit:match("^boss%d+$") then
        return "boss"
    end

    return frame.unit
end

local function ResolveUnitConfig(frame)
    local unitKey = GetUnitKey(frame)
    if not unitKey then
        return nil, nil
    end

    local utils = FocalPoint.UnitFrameUtils
    if utils and utils.GetUnitDB then
        return utils.GetUnitDB(unitKey), unitKey
    end

    return nil, unitKey
end

local function GetDefaultUnitConfig(unitKey)
    if type(unitKey) ~= "string" or unitKey == "" or not FocalPoint.GetDefaultDB then
        return nil
    end

    local defaults = FocalPoint:GetDefaultDB()
    return defaults
        and defaults.profile
        and defaults.profile.Units
        and defaults.profile.Units[unitKey]
end

local function CopyValue(value)
    if type(value) == "table" then
        return CopyTable and CopyTable(value) or value
    end

    return value
end

local function IsEditorUnlocked()
    return FocalPoint.framesUnlocked == true
        and FocalPoint.IsEditorActive
        and FocalPoint:IsEditorActive()
end

local function IsWriteBlockedInCombat()
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

local function SelectFrame(frame)
    if FocalPoint.SelectEditorUnit and frame and frame.unit then
        FocalPoint:SelectEditorUnit(frame.unit)
    end
end

local function CopySize(frame)
    local config, unitKey = ResolveUnitConfig(frame)
    if type(config) ~= "table" then
        return
    end

    clipboard.size = {
        unit = unitKey,
        width = tonumber(config.width) or (frame.GetWidth and frame:GetWidth()) or nil,
        height = tonumber(config.height) or (frame.GetHeight and frame:GetHeight()) or nil,
    }

    PrintMessage(T("EDITOR_CONTEXT_MENU_STATUS_SIZE_COPIED", "frame size copied."))
end

local function PasteSize(frame)
    if not clipboard.size then
        return
    end
    if IsWriteBlockedInCombat() then
        PrintMessage(T("EDITOR_CONTEXT_MENU_STATUS_SIZE_COMBAT", "cannot paste frame size during combat."))
        return
    end

    local config, unitKey = ResolveUnitConfig(frame)
    if type(config) ~= "table" then
        return
    end

    local width = Clamp(clipboard.size.width, SIZE_MIN_WIDTH, SIZE_MAX_WIDTH)
    local height = Clamp(clipboard.size.height, SIZE_MIN_HEIGHT, SIZE_MAX_HEIGHT)
    if width then
        config.width = width
    end
    if height then
        config.height = height
    end

    RefreshEditorForUnit(unitKey)
end

local function CopyPosition(frame)
    local config, unitKey = ResolveUnitConfig(frame)
    if type(config) ~= "table" then
        return
    end

    clipboard.position = {
        unit = unitKey,
        point = config.point or "CENTER",
        relativeTo = config.relativeTo or "UIParent",
        relativePoint = config.relativePoint or "CENTER",
        x = tonumber(config.x) or 0,
        y = tonumber(config.y) or 0,
    }

    PrintMessage(T("EDITOR_CONTEXT_MENU_STATUS_POSITION_COPIED", "frame position copied."))
end

local function PastePosition(frame)
    if not clipboard.position then
        return
    end
    if IsWriteBlockedInCombat() then
        PrintMessage(T("EDITOR_CONTEXT_MENU_STATUS_POSITION_COMBAT", "cannot paste frame position during combat."))
        return
    end

    local config, unitKey = ResolveUnitConfig(frame)
    if type(config) ~= "table" then
        return
    end

    config.point = clipboard.position.point or "CENTER"
    config.relativeTo = clipboard.position.relativeTo or "UIParent"
    config.relativePoint = clipboard.position.relativePoint or "CENTER"
    config.x = tonumber(clipboard.position.x) or 0
    config.y = tonumber(clipboard.position.y) or 0

    if FocalPoint.ApplyStoredFramePosition then
        FocalPoint:ApplyStoredFramePosition(frame)
    end
    RefreshEditorForUnit(unitKey)
end

local function ResetSize(frame)
    if IsWriteBlockedInCombat() then
        PrintMessage(T("EDITOR_CONTEXT_MENU_STATUS_RESET_SIZE_COMBAT", "cannot reset frame size during combat."))
        return
    end

    local config, unitKey = ResolveUnitConfig(frame)
    local defaults = GetDefaultUnitConfig(unitKey)
    if type(config) ~= "table" or type(defaults) ~= "table" then
        return
    end

    config.width = CopyValue(defaults.width)
    config.height = CopyValue(defaults.height)

    RefreshEditorForUnit(unitKey)
end

local function ResetPosition(frame)
    if IsWriteBlockedInCombat() then
        PrintMessage(T("EDITOR_CONTEXT_MENU_STATUS_RESET_POSITION_COMBAT", "cannot reset frame position during combat."))
        return
    end

    local config, unitKey = ResolveUnitConfig(frame)
    local defaults = GetDefaultUnitConfig(unitKey)
    if type(config) ~= "table" or type(defaults) ~= "table" then
        return
    end

    for _, key in ipairs({ "point", "relativeTo", "relativePoint", "x", "y" }) do
        if defaults[key] ~= nil then
            config[key] = CopyValue(defaults[key])
        end
    end

    if FocalPoint.ApplyStoredFramePosition then
        FocalPoint:ApplyStoredFramePosition(frame)
    end
    RefreshEditorForUnit(unitKey)
end

local function EnsureMenu()
    if FrameContextMenu.menu then
        return FrameContextMenu.menu
    end

    local menu = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
    menu:SetSize(178, 154)
    menu:SetFrameStrata("FULLSCREEN_DIALOG")
    menu:SetClampedToScreen(true)
    menu:EnableMouse(true)
    menu:Hide()
    menu:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
        insets = { left = 0, right = 0, top = 0, bottom = 0 },
    })
    local panelBackground = GetSkinChromeColor("panelBackground", { 0.06, 0.07, 0.09, 0.96 })
    local panelBorder = GetSkinBrandColor("orangeStrong", { 0.918, 0.459, 0.000, 0.75 })
    menu:SetBackdropColor(panelBackground[1], panelBackground[2], panelBackground[3], panelBackground[4])
    menu:SetBackdropBorderColor(panelBorder[1], panelBorder[2], panelBorder[3], panelBorder[4])

    local buttons = {}
    menu.buttons = buttons

    local items = {
        { text = T("EDITOR_CONTEXT_MENU_COPY_SIZE", "Copy size"), action = CopySize },
        { text = T("EDITOR_CONTEXT_MENU_PASTE_SIZE", "Paste size"), action = PasteSize, enabled = function() return clipboard.size ~= nil end },
        { text = T("EDITOR_CONTEXT_MENU_COPY_POSITION", "Copy position"), action = CopyPosition },
        { text = T("EDITOR_CONTEXT_MENU_PASTE_POSITION", "Paste position"), action = PastePosition, enabled = function() return clipboard.position ~= nil end },
        { text = T("EDITOR_CONTEXT_MENU_RESET_SIZE", "Reset size"), action = ResetSize },
        { text = T("EDITOR_CONTEXT_MENU_RESET_POSITION", "Reset position"), action = ResetPosition },
    }

    for index, item in ipairs(items) do
        local hoverAccent = GetSkinButtonColor("hover", "accent", { 0.918, 0.459, 0.000, 0.18 })
        local normalText = GetSkinButtonColor("normal", "text", { 0.94, 0.96, 0.98, 1 })
        local button = CreateFrame("Button", nil, menu)
        button:SetHeight(23)
        button:SetPoint("TOPLEFT", menu, "TOPLEFT", 6, -6 - ((index - 1) * 23))
        button:SetPoint("TOPRIGHT", menu, "TOPRIGHT", -6, -6 - ((index - 1) * 23))
        button:SetHighlightTexture("Interface\\Buttons\\WHITE8X8")
        local highlight = button:GetHighlightTexture()
        SetTextureColor(highlight, hoverAccent)

        local label = button:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        label:SetPoint("LEFT", button, "LEFT", 8, 0)
        label:SetJustifyH("LEFT")
        label:SetText(item.text)
        SetTextColor(label, normalText)
        button.label = label
        button.item = item

        button:SetScript("OnClick", function(self)
            if not self._enabled then
                return
            end

            local targetFrame = menu.targetFrame
            menu:Hide()
            SelectFrame(targetFrame)
            self.item.action(targetFrame)
        end)

        buttons[#buttons + 1] = button
    end

    menu:SetScript("OnHide", function(self)
        self.targetFrame = nil
    end)

    FrameContextMenu.menu = menu
    return menu
end

local function UpdateMenuButtons(menu)
    local normalText = GetSkinButtonColor("normal", "text", { 0.94, 0.96, 0.98, 1 })
    local disabledText = GetSkinButtonColor("disabled", "text", { 0.45, 0.48, 0.54, 1 })

    for _, button in ipairs(menu.buttons or {}) do
        local item = button.item
        local enabled = true
        if type(item.enabled) == "function" then
            enabled = item.enabled() and true or false
        end

        button._enabled = enabled
        if enabled then
            SetTextColor(button.label, normalText)
            button:Enable()
        else
            SetTextColor(button.label, disabledText)
            button:Disable()
        end
    end
end

function FrameContextMenu.ShowForFrame(frame)
    if not IsEditorUnlocked() or not frame or not frame.unit then
        return
    end

    local menu = EnsureMenu()
    if menu:IsShown() and menu.targetFrame == frame then
        menu:Hide()
        return
    end

    menu.targetFrame = frame
    UpdateMenuButtons(menu)

    local scale = UIParent and UIParent.GetEffectiveScale and UIParent:GetEffectiveScale() or 1
    local cursorX, cursorY = GetCursorPosition()
    cursorX = (cursorX or 0) / scale
    cursorY = (cursorY or 0) / scale

    menu:ClearAllPoints()
    menu:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", cursorX + 8, cursorY - 8)
    menu:Show()
end

function FrameContextMenu.Hide()
    local menu = FrameContextMenu.menu
    if menu and menu.Hide then
        menu:Hide()
    end
end

local function AttachMouseUpHook(owner, frame)
    if not owner or owner._focalPointContextMenuHooked or not owner.HookScript then
        return
    end

    owner:HookScript("OnMouseUp", function(_, button)
        if button == "RightButton" then
            FrameContextMenu.ShowForFrame(frame)
        end
    end)
    owner._focalPointContextMenuHooked = true
end

function FrameContextMenu.AttachFrame(frame)
    AttachMouseUpHook(frame, frame)
end

function FrameContextMenu.AttachOverlay(frame, overlay)
    AttachMouseUpHook(overlay, frame)
end

function FrameContextMenu.AttachToExistingFrames()
    if not FocalPoint.frames then
        return
    end

    for _, frame in pairs(FocalPoint.frames) do
        FrameContextMenu.AttachFrame(frame)
        if frame and frame.MoveOverlay then
            FrameContextMenu.AttachOverlay(frame, frame.MoveOverlay)
        end
    end
end

return FrameContextMenu
