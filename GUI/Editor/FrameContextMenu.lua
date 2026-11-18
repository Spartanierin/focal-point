local _, FocalPoint = ...

FocalPoint.GUI = FocalPoint.GUI or {}
FocalPoint.GUI.Editor = FocalPoint.GUI.Editor or {}

local FrameContextMenu = {}
FocalPoint.GUI.Editor.FrameContextMenu = FrameContextMenu

local L = FocalPoint.L or {}
local nativeMenu

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
    if not frame or type(frame._fpUnit) ~= "string" or frame._fpUnit == "" then
        return nil
    end

    local utils = FocalPoint.UnitFrameUtils
    if utils and utils.NormalizeConfigUnitKey then
        return utils.NormalizeConfigUnitKey(frame._fpUnit)
    end

    if frame._fpUnit:match("^boss%d+$") then
        return "boss"
    end

    return frame._fpUnit
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

local function ResolveEditableUnitConfigByKey(unitKey)
    if not unitKey then
        return nil, nil
    end

    local resolver = FocalPoint.ActiveLayoutResolver
    if resolver and resolver.GetEditableActiveUnits then
        local units = resolver.GetEditableActiveUnits(FocalPoint.db)
        if type(units) == "table" then
            return units[unitKey], unitKey
        end
    end

    return nil, unitKey
end

local function RequestEditableContextMutation(action)
    local workflow = FocalPoint.LayoutEditWorkflow
    if not (workflow and workflow.RequestEditableLayoutForMutation) then
        return false
    end

    local completed = false
    workflow.RequestEditableLayoutForMutation(function()
        action()
        completed = true
    end)
    return completed
end

local function IsEditorUnlocked()
    return FocalPoint.framesUnlocked == true
        and FocalPoint.IsEditorActive
        and FocalPoint:IsEditorActive()
        and not (FocalPoint.GUI.Editor.InteractionMode
            and FocalPoint.GUI.Editor.InteractionMode.IsCanvasInteractionBlocked
            and FocalPoint.GUI.Editor.InteractionMode.IsCanvasInteractionBlocked())
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
        FocalPoint.GUI:RequestRefreshOptions("FrameContextMenu.Action")
    end

    if FocalPoint.RefreshEditorSelectionVisuals then
        FocalPoint:RefreshEditorSelectionVisuals()
    end
end

local function SelectFrame(frame)
    if FocalPoint.SelectEditorUnit and frame and frame._fpUnit then
        FocalPoint:SelectEditorUnit(frame._fpUnit)
    end
end

local function GetEditorStateApi()
    return FocalPoint.GUI
        and FocalPoint.GUI.Editor
        and FocalPoint.GUI.Editor.State
        or nil
end

local function GetFrameMutations()
    return FocalPoint.GUI
        and FocalPoint.GUI.Editor
        and FocalPoint.GUI.Editor.FrameMutations
        or nil
end

local function IsFrameUnitSelected(frame)
    local unitKey = GetUnitKey(frame)
    local editorState = GetEditorStateApi()
    return unitKey ~= nil
        and editorState
        and editorState.IsUnitSelected
        and editorState.IsUnitSelected(unitKey) == true
end

local function GetSelectedResetUnits(frame)
    local unitKey = GetUnitKey(frame)
    if not unitKey then
        return {}, false
    end

    local editorState = GetEditorStateApi()
    if not (editorState and editorState.GetSelectedUnits and editorState.GetSelectedUnitCount) then
        return { unitKey }, false
    end

    local selectedCount = tonumber(editorState.GetSelectedUnitCount()) or 0
    if selectedCount > 1 and IsFrameUnitSelected(frame) then
        return editorState.GetSelectedUnits(), true
    end

    return { unitKey }, false
end

local function SnapshotUnitKeys(units)
    local snapshot = {}
    for index, unitKey in ipairs(units or {}) do
        snapshot[index] = unitKey
    end
    return snapshot
end

local function GetSelectedResetCount(frame)
    local units, isBatch = GetSelectedResetUnits(frame)
    return isBatch and #units or 1
end

local function PrintResetFailure(kind, result)
    local reason = result and result.reason
    if reason == "combat" then
        if kind == "size" then
            PrintMessage(T("EDITOR_CONTEXT_MENU_STATUS_RESET_SIZE_COMBAT", "Cannot reset frame size during combat."))
        else
            PrintMessage(T("EDITOR_CONTEXT_MENU_STATUS_RESET_POSITION_COMBAT", "Cannot reset frame position during combat."))
        end
        return
    end

    PrintMessage(T("EDITOR_CONTEXT_MENU_STATUS_RESET_FAILED", "Could not reset the selected unit frames."))
end

local function IsAlignSelectionAvailable(menu)
    if not IsFrameUnitSelected(menu and menu.targetFrame) then
        return false
    end

    local editorState = GetEditorStateApi()
    if not (editorState
        and editorState.GetSelectedUnitCount
        and editorState.GetPrimaryUnit
        and editorState.IsUnitSelected)
    then
        return false
    end

    local selectedCount = tonumber(editorState.GetSelectedUnitCount()) or 0
    local primaryUnit = editorState.GetPrimaryUnit()
    return selectedCount >= 2
        and type(primaryUnit) == "string"
        and primaryUnit ~= ""
        and editorState.IsUnitSelected(primaryUnit) == true
end

local function PrintAlignFailure(result)
    local reason = result and result.reason
    if reason == "combat" then
        PrintMessage(T("EDITOR_CONTEXT_MENU_STATUS_ALIGN_COMBAT", "Cannot align selected frames during combat."))
        return
    end

    PrintMessage(T("EDITOR_CONTEXT_MENU_STATUS_ALIGN_FAILED", "Could not align the selected unit frames."))
end

local function AlignSelected(mode)
    local mutations = GetFrameMutations()
    local editorState = GetEditorStateApi()
    if not (mutations and mutations.AlignUnits and editorState and editorState.GetSelectedUnits and editorState.GetPrimaryUnit) then
        return
    end

    local units = SnapshotUnitKeys(editorState.GetSelectedUnits())
    local primaryUnit = editorState.GetPrimaryUnit()

    RequestEditableContextMutation(function()
        local result = mutations.AlignUnits(units, primaryUnit, mode)
        if not (result and result.ok == true) then
            PrintAlignFailure(result)
        end
    end)
end

local function GetInspectorMutations()
    return FocalPoint.InspectorMutations
        or (FocalPoint.GUI
            and FocalPoint.GUI.Editor
            and FocalPoint.GUI.Editor.Inspector
            and FocalPoint.GUI.Editor.Inspector.Mutations)
        or nil
end

local function GetTextOverlay()
    return FocalPoint.GUI
        and FocalPoint.GUI.Editor
        and FocalPoint.GUI.Editor.TextEditorOverlay
        or nil
end

local function IsShiftDown()
    local interactionMode = FocalPoint.GUI
        and FocalPoint.GUI.Editor
        and FocalPoint.GUI.Editor.InteractionMode
    return interactionMode
        and interactionMode.IsShiftDown
        and interactionMode.IsShiftDown() == true
        or false
end

local function GetTextTarget(menu)
    if not menu or menu.contextKind ~= "text" then
        return nil, nil, nil, nil
    end

    local frame = menu.targetFrame
    local textKey = menu.targetTextKey
    if not frame or type(textKey) ~= "string" or textKey == "" then
        return nil, nil, nil, nil
    end

    local unitConfig, unitKey = ResolveUnitConfig(frame)
    if type(unitConfig) ~= "table" or not unitKey then
        return nil, nil, nil, nil
    end

    local texts = unitConfig.Texts
    if type(texts) ~= "table" or type(texts[textKey]) ~= "table" then
        return nil, nil, nil, nil
    end

    return frame, textKey, unitConfig, unitKey
end

local function IsTextTargetSelected(menu)
    local _, textKey, _, unitKey = GetTextTarget(menu)
    if not unitKey or not textKey then
        return false
    end

    local editorState = GetEditorStateApi()
    return editorState
        and editorState.IsTextElementSelected
        and editorState.IsTextElementSelected(unitKey, textKey) == true
        or false
end

local function BuildTextMutationContext(menu)
    local _, _, unitConfig, unitKey = GetTextTarget(menu)
    if type(unitConfig) ~= "table" or not unitKey then
        return nil
    end

    return {
        unitConfig = unitConfig,
        unitKey = unitKey,
    }
end

local function IsTextPositionResetAvailable(menu)
    if IsWriteBlockedInCombat() or not IsEditorUnlocked() or not IsTextTargetSelected(menu) then
        return false
    end

    local _, textKey = GetTextTarget(menu)
    local mutations = GetInspectorMutations()
    local context = BuildTextMutationContext(menu)
    return mutations
        and mutations.GetTextPositionDefault
        and type(mutations.GetTextPositionDefault(context, textKey)) == "table"
        or false
end

local function IsTextSizeResetAvailable(menu)
    if IsWriteBlockedInCombat() or not IsEditorUnlocked() or not IsTextTargetSelected(menu) then
        return false
    end

    local _, textKey = GetTextTarget(menu)
    local mutations = GetInspectorMutations()
    local context = BuildTextMutationContext(menu)
    return mutations
        and mutations.GetTextFontSizeDefault
        and mutations.GetTextFontSizeDefault(context, textKey) ~= nil
        or false
end

local function ResetTextPosition(menu)
    local frame, textKey = GetTextTarget(menu)
    local overlay = GetTextOverlay()
    if overlay and overlay.ResetPosition then
        overlay.ResetPosition(frame, textKey)
    end
end

local function ResetTextSize(menu)
    local frame, textKey = GetTextTarget(menu)
    local overlay = GetTextOverlay()
    if overlay and overlay.ResetSize then
        overlay.ResetSize(frame, textKey)
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

    local width = Clamp(clipboard.size.width, SIZE_MIN_WIDTH, SIZE_MAX_WIDTH)
    local height = Clamp(clipboard.size.height, SIZE_MIN_HEIGHT, SIZE_MAX_HEIGHT)
    local unitKey = GetUnitKey(frame)
    if not unitKey then
        return
    end

    RequestEditableContextMutation(function()
        local config = ResolveEditableUnitConfigByKey(unitKey)
        if type(config) ~= "table" then
            return
        end
        if width then
            config.width = width
        end
        if height then
            config.height = height
        end

        RefreshEditorForUnit(unitKey)
    end)
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

    local unitKey = GetUnitKey(frame)
    if not unitKey then
        return
    end
    local position = {
        point = clipboard.position.point or "CENTER",
        relativeTo = clipboard.position.relativeTo or "UIParent",
        relativePoint = clipboard.position.relativePoint or "CENTER",
        x = tonumber(clipboard.position.x) or 0,
        y = tonumber(clipboard.position.y) or 0,
    }

    RequestEditableContextMutation(function()
        local config = ResolveEditableUnitConfigByKey(unitKey)
        if type(config) ~= "table" then
            return
        end

        config.point = position.point
        config.relativeTo = position.relativeTo
        config.relativePoint = position.relativePoint
        config.x = position.x
        config.y = position.y

        if FocalPoint.ApplyStoredFramePosition then
            local targetFrame = FocalPoint.frames and FocalPoint.frames[unitKey] or frame
            FocalPoint:ApplyStoredFramePosition(targetFrame)
        end
        RefreshEditorForUnit(unitKey)
    end)
end

local function ResetSize(frame)
    local mutations = GetFrameMutations()
    if not (mutations and mutations.ResetUnitsSize) then
        return
    end

    local selectedUnits = SnapshotUnitKeys(GetSelectedResetUnits(frame))
    RequestEditableContextMutation(function()
        local result = mutations.ResetUnitsSize(selectedUnits)
        if not (result and result.ok == true) then
            PrintResetFailure("size", result)
        end
    end)
end

local function ResetPosition(frame)
    local mutations = GetFrameMutations()
    if not (mutations and mutations.ResetUnitsPosition) then
        return
    end

    local selectedUnits = SnapshotUnitKeys(GetSelectedResetUnits(frame))
    RequestEditableContextMutation(function()
        local result = mutations.ResetUnitsPosition(selectedUnits)
        if not (result and result.ok == true) then
            PrintResetFailure("position", result)
        end
    end)
end

local function ResetTextContextPosition(menu)
    if menu and menu.resetPositionTarget == "frame" then
        ResetPosition(menu.targetFrame)
        return
    end

    ResetTextPosition(menu)
end

local function GetResetSizeLabel(menu)
    local count = GetSelectedResetCount(menu and menu.targetFrame)
    if count > 1 then
        return string.format(T("EDITOR_CONTEXT_MENU_RESET_SIZE_MULTI", "Reset sizes (%d)"), count)
    end
    return T("EDITOR_CONTEXT_MENU_RESET_SIZE", "Reset size")
end

local function GetResetPositionLabel(menu)
    local count = GetSelectedResetCount(menu and menu.targetFrame)
    if count > 1 then
        return string.format(T("EDITOR_CONTEXT_MENU_RESET_POSITION_MULTI", "Reset positions (%d)"), count)
    end
    return T("EDITOR_CONTEXT_MENU_RESET_POSITION", "Reset position")
end

local function GetResetSizeTooltip(menu)
    local count = GetSelectedResetCount(menu and menu.targetFrame)
    if count > 1 then
        return T("EDITOR_CONTEXT_MENU_RESET_SIZE_TOOLTIP_MULTI", "Resets the size of all selected unit frames.")
    end
    return T("EDITOR_CONTEXT_MENU_RESET_SIZE_TOOLTIP", "Resets the size of this unit frame.")
end

local function GetResetPositionTooltip(menu)
    local count = GetSelectedResetCount(menu and menu.targetFrame)
    if count > 1 then
        return T("EDITOR_CONTEXT_MENU_RESET_POSITION_TOOLTIP_MULTI", "Resets the position of all selected unit frames.")
    end
    return T("EDITOR_CONTEXT_MENU_RESET_POSITION_TOOLTIP", "Resets the position of this unit frame.")
end

local function GetAlignTooltip()
    return T("EDITOR_CONTEXT_MENU_ALIGN_TOOLTIP", "Aligns secondary selected unit frames to the primary selection.")
end

local function GetTextResetPositionTooltip(menu)
    if menu and menu.resetPositionTarget == "frame" then
        return GetResetPositionTooltip(menu)
    end
    return T("EDITOR_CONTEXT_MENU_RESET_TEXT_POSITION_TOOLTIP", "Restore this text element's default anchor and offsets.")
end

local function IsTextContextPositionResetAvailable(menu)
    if menu and menu.resetPositionTarget == "frame" then
        local mutations = GetFrameMutations()
        return menu.targetFrame ~= nil
            and mutations
            and mutations.ResetUnitsPosition ~= nil
    end

    return IsTextPositionResetAvailable(menu)
end

local function GetTextResetSizeTooltip()
    return T("EDITOR_CONTEXT_MENU_RESET_TEXT_SIZE_TOOLTIP", "Restore this text element's default font size.")
end

local function HideTooltip()
    if GameTooltip then
        GameTooltip:Hide()
    end
end

local function IsMouseOverMenu(menu)
    if not menu then
        return false
    end

    if menu.IsMouseOver and menu:IsMouseOver() then
        return true
    end

    return MouseIsOver and MouseIsOver(menu) == true
end

local function ReleaseNativeMenu(state)
    if state.owner and state.owner.HandlesGlobalMouseEvent == state.mouseHandler then
        state.owner.HandlesGlobalMouseEvent = state.previousMouseHandler
    end
    if nativeMenu == state then nativeMenu = nil end
    state.proxy, state.manager, state.context, state.owner = nil, nil, nil, nil
    state.mouseHandler, state.previousMouseHandler = nil, nil
end

local function CloseNativeMenu()
    local state = nativeMenu
    if not state then return end
    local proxy, manager = state.proxy, state.manager
    ReleaseNativeMenu(state)
    if proxy then manager:CloseMenu(proxy) end
end

local function CloseMenu(menu)
    CloseNativeMenu()
    menu = menu or FrameContextMenu.menu
    HideTooltip()
    if menu and menu.Hide then
        menu:Hide()
    end
end

local function ExecuteMenuItem(item, context, validate)
    local captured = {
        contextKind = context.contextKind,
        targetFrame = context.targetFrame,
        targetTextKey = context.targetTextKey,
        resetPositionTarget = context.resetPositionTarget,
    }
    CloseMenu()
    if validate and not validate(context) then return end
    if item and not item.preserveSelection then SelectFrame(captured.targetFrame) end
    if item and item.action then
        item.action(captured.contextKind == "text" and captured or captured.targetFrame)
    end
end

local function GetSelectionSnapshot()
    local editor = GetEditorStateApi()
    if not editor then return {} end
    local textUnit, textKey
    if editor.GetSelectedTextElement then textUnit, textKey = editor.GetSelectedTextElement() end
    local scope = editor.GetPropertyScope and editor.GetPropertyScope()
    return {
        primary = editor.GetPrimaryUnit and editor.GetPrimaryUnit(),
        units = editor.GetSelectedUnits and table.concat(editor.GetSelectedUnits(), "\0"),
        textUnit = textUnit, textKey = textKey,
        section = scope and scope.sectionKey, objectKey = scope and scope.objectKey,
    }
end

local function GetActiveLayoutId()
    local resolver = FocalPoint.ActiveLayoutResolver
    return resolver and resolver.GetStoredActiveLayoutId and resolver.GetStoredActiveLayoutId(FocalPoint.db)
end

local function IsNativeContextCurrent(context)
    if not IsEditorUnlocked() or context.targetFrame._fpUnit ~= context.unitKey
        or GetActiveLayoutId() ~= context.layoutId
        or ResolveUnitConfig(context.targetFrame) ~= context.unitConfig then return false end
    local selection = GetSelectionSnapshot()
    for key, value in pairs(context.selection) do if selection[key] ~= value then return false end end
    for key, value in pairs(selection) do if context.selection[key] ~= value then return false end end
    if context.contextKind == "text" then
        local texts = context.unitConfig and context.unitConfig.Texts
        if not texts or texts[context.targetTextKey] ~= context.textConfig then return false end
    end
    return true
end

local frameItems = {
    { text = T("EDITOR_CONTEXT_MENU_COPY_SIZE", "Copy size"), action = CopySize },
    { text = T("EDITOR_CONTEXT_MENU_PASTE_SIZE", "Paste size"), action = PasteSize, enabled = function() return clipboard.size ~= nil end },
    { text = GetResetSizeLabel, tooltip = GetResetSizeTooltip, action = ResetSize, preserveSelection = true },
    { text = T("EDITOR_CONTEXT_MENU_COPY_POSITION", "Copy position"), action = CopyPosition, dividerBefore = true },
    { text = T("EDITOR_CONTEXT_MENU_PASTE_POSITION", "Paste position"), action = PastePosition, enabled = function() return clipboard.position ~= nil end },
    { text = GetResetPositionLabel, tooltip = GetResetPositionTooltip, action = ResetPosition, preserveSelection = true },
    { text = T("EDITOR_CONTEXT_MENU_ALIGN_SELECTED", "Align selected"), enabled = function() return false end, dividerBefore = true },
    { text = T("EDITOR_CONTEXT_MENU_ALIGN_LEFT", "Align left"), tooltip = GetAlignTooltip, action = function() AlignSelected("left") end, enabled = IsAlignSelectionAvailable, preserveSelection = true },
    { text = T("EDITOR_CONTEXT_MENU_ALIGN_RIGHT", "Align right"), tooltip = GetAlignTooltip, action = function() AlignSelected("right") end, enabled = IsAlignSelectionAvailable, preserveSelection = true },
    { text = T("EDITOR_CONTEXT_MENU_ALIGN_TOP", "Align top"), tooltip = GetAlignTooltip, action = function() AlignSelected("top") end, enabled = IsAlignSelectionAvailable, preserveSelection = true },
    { text = T("EDITOR_CONTEXT_MENU_ALIGN_BOTTOM", "Align bottom"), tooltip = GetAlignTooltip, action = function() AlignSelected("bottom") end, enabled = IsAlignSelectionAvailable, preserveSelection = true },
    { text = T("EDITOR_CONTEXT_MENU_ALIGN_HORIZONTAL_CENTER", "Align horizontal center"), tooltip = GetAlignTooltip, action = function() AlignSelected("horizontalCenter") end, enabled = IsAlignSelectionAvailable, preserveSelection = true },
    { text = T("EDITOR_CONTEXT_MENU_ALIGN_VERTICAL_CENTER", "Align vertical center"), tooltip = GetAlignTooltip, action = function() AlignSelected("verticalCenter") end, enabled = IsAlignSelectionAvailable, preserveSelection = true },
}
local textItems = {
    { text = T("EDITOR_CONTEXT_MENU_RESET_POSITION", "Reset position"), tooltip = GetTextResetPositionTooltip, action = ResetTextContextPosition, enabled = IsTextContextPositionResetAvailable, preserveSelection = true },
    { text = T("EDITOR_CONTEXT_MENU_RESET_SIZE", "Reset size"), tooltip = GetTextResetSizeTooltip, action = ResetTextSize, enabled = IsTextSizeResetAvailable, preserveSelection = true },
}

local function EnsureMenu()
    if FrameContextMenu.menu then
        return FrameContextMenu.menu
    end

    local menu = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
    menu:SetSize(214, 315)
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

    menu.frameItems = frameItems
    menu.textItems = textItems
    menu:SetSize(214, 12 + (#frameItems * 23))

    for index = 1, math.max(#frameItems, #textItems) do
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
        label:SetText("")
        SetTextColor(label, normalText)
        button.label = label

        button:SetScript("OnClick", function(self)
            if not self._enabled then
                return
            end

            ExecuteMenuItem(self.item, menu)
        end)

        button:SetScript("OnEnter", function(self)
            local item = self.item
            local tooltip = item and item.tooltip
            if type(tooltip) == "function" then
                tooltip = tooltip(menu)
            end
            if type(tooltip) ~= "string" or tooltip == "" or not GameTooltip then
                return
            end
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            if GameTooltip.ClearLines then
                GameTooltip:ClearLines()
            end
            GameTooltip:AddLine(tooltip, 1, 1, 1, true)
            GameTooltip:Show()
        end)

        button:SetScript("OnLeave", function()
            HideTooltip()
        end)

        buttons[#buttons + 1] = button
    end

    menu:SetScript("OnShow", function(self)
        self:RegisterEvent("GLOBAL_MOUSE_DOWN")
    end)

    menu:SetScript("OnEvent", function(self, event, button)
        if event ~= "GLOBAL_MOUSE_DOWN" or button ~= "LeftButton" then
            return
        end
        if IsMouseOverMenu(self) then
            return
        end

        CloseMenu(self)
    end)

    menu:SetScript("OnHide", function(self)
        self:UnregisterEvent("GLOBAL_MOUSE_DOWN")
        HideTooltip()
        self.targetFrame = nil
        self.targetTextKey = nil
        self.contextKind = nil
        self.resetPositionTarget = nil
    end)

    FrameContextMenu.menu = menu
    return menu
end

local function GetActiveMenuItems(menu)
    if menu and menu.contextKind == "text" then
        return textItems
    end

    return frameItems
end

local function UpdateMenuButtons(menu)
    local normalText = GetSkinButtonColor("normal", "text", { 0.94, 0.96, 0.98, 1 })
    local disabledText = GetSkinButtonColor("disabled", "text", { 0.45, 0.48, 0.54, 1 })
    local items = GetActiveMenuItems(menu)

    for index, button in ipairs(menu.buttons or {}) do
        local item = items[index]
        button.item = item
        if not item then
            button._enabled = false
            button:Hide()
        else
            button:Show()
        end

        local enabled = true
        local text = item and item.text or ""
        if type(text) == "function" then
            text = text(menu)
        end
        if item and type(item.enabled) == "function" then
            enabled = item.enabled(menu) and true or false
        elseif not item then
            enabled = false
        end

        button._enabled = enabled
        button.label:SetText(text)
        if enabled then
            SetTextColor(button.label, normalText)
            button:Enable()
        else
            SetTextColor(button.label, disabledText)
            button:Disable()
        end
    end

    menu:SetSize(214, 12 + (#items * 23))
end

local function OpenNativeMenu(context)
    if not (MenuUtil and type(MenuUtil.CreateContextMenu) == "function"
        and Menu and type(Menu.GetManager) == "function"
        and type(GetMouseFoci) == "function") then return false end
    local manager = Menu.GetManager()
    if not manager or type(manager.CloseMenu) ~= "function" then return false end
    local previous = nativeMenu and nativeMenu.context
    if previous and previous.contextKind == context.contextKind
        and previous.targetFrame == context.targetFrame and previous.targetTextKey == context.targetTextKey then
        CloseMenu()
        return true
    end

    CloseMenu()
    context.unitKey = context.targetFrame._fpUnit
    context.unitConfig = ResolveUnitConfig(context.targetFrame)
    context.layoutId = GetActiveLayoutId()
    context.selection = GetSelectionSnapshot()
    context.textConfig = context.unitConfig and context.unitConfig.Texts and context.unitConfig.Texts[context.targetTextKey]
    local owner = GetMouseFoci()[1] or context.targetFrame
    local state = { context = context, owner = owner, manager = manager }
    nativeMenu = state
    state.previousMouseHandler = owner.HandlesGlobalMouseEvent
    state.mouseHandler = function(self, buttonName, event)
        -- Blizzard's dropdowns use this same contract to preserve click toggling.
        if nativeMenu == state and event == "GLOBAL_MOUSE_DOWN" and buttonName == "RightButton" then return true end
        if state.previousMouseHandler then return state.previousMouseHandler(self, buttonName, event) end
    end
    owner.HandlesGlobalMouseEvent = state.mouseHandler
    local proxy = MenuUtil.CreateContextMenu(owner, function(_, root)
        root:AddMenuReleasedCallback(function() ReleaseNativeMenu(state) end)
        for _, item in ipairs(GetActiveMenuItems(context)) do
            if item.dividerBefore then root:CreateDivider() end
            local function IsEnabled()
                return nativeMenu == state and IsNativeContextCurrent(context)
                    and (not item.enabled or item.enabled(context))
            end
            local text = type(item.text) == "function" and item.text(context) or item.text
            local entry = root:CreateButton(text, function()
                if nativeMenu ~= state or not state.proxy then return end
                if not IsEnabled() then CloseNativeMenu(); return end
                ExecuteMenuItem(item, context, IsNativeContextCurrent)
            end)
            entry:SetEnabled(IsEnabled)
            if item.tooltip then
                entry:SetTooltip(function(tooltip)
                    if nativeMenu ~= state then return end
                    local text = type(item.tooltip) == "function" and item.tooltip(context) or item.tooltip
                    if type(text) == "string" and text ~= "" then tooltip:AddLine(text, 1, 1, 1, true) end
                end)
            end
        end
    end)
    if not proxy then
        ReleaseNativeMenu(state)
        return false
    end
    if nativeMenu == state then state.proxy = proxy end
    return true
end

local function ShowMenu(context)
    local menu = FrameContextMenu.menu
    if menu and menu:IsShown() and menu.contextKind == context.contextKind
        and menu.targetFrame == context.targetFrame and menu.targetTextKey == context.targetTextKey then
        CloseMenu(menu)
        return
    end
    if OpenNativeMenu(context) then return end
    CloseNativeMenu()
    menu = EnsureMenu()
    menu.contextKind = context.contextKind
    menu.targetFrame = context.targetFrame
    menu.targetTextKey = context.targetTextKey
    menu.resetPositionTarget = context.resetPositionTarget
    UpdateMenuButtons(menu)

    local scale = UIParent and UIParent.GetEffectiveScale and UIParent:GetEffectiveScale() or 1
    local cursorX, cursorY = GetCursorPosition()
    cursorX = (cursorX or 0) / scale
    cursorY = (cursorY or 0) / scale
    menu:ClearAllPoints()
    menu:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", cursorX + 8, cursorY - 8)
    menu:Show()
end

function FrameContextMenu.ShowForFrame(frame)
    if not IsEditorUnlocked() or not frame or not frame._fpUnit then return end
    ShowMenu({contextKind = "frame", targetFrame = frame})
end

function FrameContextMenu.ShowForText(frame, textKey)
    if not IsEditorUnlocked() or not frame or not frame._fpUnit or type(textKey) ~= "string" or textKey == "" then return end
    ShowMenu({contextKind = "text", targetFrame = frame, targetTextKey = textKey,
        resetPositionTarget = IsShiftDown() and "text" or "frame"})
end

function FrameContextMenu.Hide()
    CloseMenu()
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
