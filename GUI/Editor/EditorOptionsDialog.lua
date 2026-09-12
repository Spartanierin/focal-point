local _, FocalPoint = ...

FocalPoint.GUI = FocalPoint.GUI or {}
FocalPoint.GUI.Editor = FocalPoint.GUI.Editor or {}

local AceGUI = LibStub("AceGUI-3.0")
local L = FocalPoint.L or {}
local FormWidgets = FocalPoint.GUI.Helpers and FocalPoint.GUI.Helpers.FormWidgets or {}
local TextStyles = FocalPoint.GUI.Helpers and FocalPoint.GUI.Helpers.TextStyles or {}

local OptionsDialog = {}
FocalPoint.GUI.Editor.OptionsDialog = OptionsDialog

local context
local Refresh

local OPTION_LABEL_WIDTH = 166
local OPTION_ROW_HEIGHT = 24
local SECTION_GAP = 16
local ROW_GAP = 4

local function T(key, fallback)
    return L[key] or fallback or key
end

local function GetGeneralConfig()
    local profile = FocalPoint.db and FocalPoint.db.profile
    if type(profile) ~= "table" then
        return nil
    end

    profile.General = type(profile.General) == "table" and profile.General or {}
    return profile.General
end

local function IsSnappingEnabled()
    local general = GetGeneralConfig()
    return not (type(general) == "table" and general.SnappingEnabled == false)
end

local function IsGridEnabled()
    local general = GetGeneralConfig()
    return type(general) == "table" and general.ShowGrid == true
end

local function GetDeps()
    return {
        ns = FocalPoint,
        L = L,
    }
end

local function GetToolbarBinding()
    return FocalPoint.GUI
        and FocalPoint.GUI.Editor
        and FocalPoint.GUI.Editor.ToolbarBinding
end

local function IsExpertMode()
    local toolbarBinding = GetToolbarBinding()
    if toolbarBinding and toolbarBinding.IsExpertMode then
        return toolbarBinding.IsExpertMode(GetDeps())
    end

    local editorMode = FocalPoint.EditorMode or (FocalPoint.GUI and FocalPoint.GUI.Editor and FocalPoint.GUI.Editor.Mode)
    if editorMode and editorMode.Resolve then
        return editorMode.Resolve(nil, FocalPoint.db and FocalPoint.db.profile) == "expert"
    end

    local general = GetGeneralConfig()
    return type(general) == "table" and general.ExpertMode == true
end

local function GetGlobalOptionValue(optionId)
    local toolbarBinding = GetToolbarBinding()
    if toolbarBinding and toolbarBinding.GetGlobalOptionValue then
        return toolbarBinding.GetGlobalOptionValue(optionId, GetDeps())
    end

    return nil
end

local function ApplyGlobalOptionValue(optionId, value)
    local toolbarBinding = GetToolbarBinding()
    if toolbarBinding and toolbarBinding.ApplyGlobalOptionValue then
        return toolbarBinding.ApplyGlobalOptionValue(optionId, value, GetDeps(), { onGlobalChanged = Refresh })
    end

    return false
end

local function HideSnapLines()
    local snapLines = FocalPoint.GUI
        and FocalPoint.GUI.Editor
        and FocalPoint.GUI.Editor.FrameSnapLines
    if snapLines and snapLines.Hide then
        snapLines.Hide()
    end
end

local function RefreshUnlockGrid()
    local grid = FocalPoint.GUI
        and FocalPoint.GUI.Editor
        and FocalPoint.GUI.Editor.FrameUnlockGrid
    if grid and grid.Refresh then
        grid.Refresh()
    end
end

local function ApplyLabelText(widget, role, options)
    if TextStyles.ApplyLabelWidget then
        TextStyles.ApplyLabelWidget(widget, role or "label", options)
    elseif TextStyles.ApplyWidgetText then
        TextStyles.ApplyWidgetText(widget, role or "label", options)
    end
end

local function CreateLabel(text, role, size, width, fullWidth)
    if FormWidgets.CreateBodyText then
        return FormWidgets.CreateBodyText(text or "", role or "label", size or 12, nil, width, fullWidth)
    end

    local label = AceGUI:Create("Label")
    if type(width) == "number" then
        label:SetWidth(width)
    elseif fullWidth ~= false then
        label:SetFullWidth(true)
    end
    label:SetText(text or "")
    ApplyLabelText(label, role or "label", { size = size or 12 })
    return label
end

local function CreateVerticalGap(height)
    local spacer = AceGUI:Create("SimpleGroup")
    spacer:SetFullWidth(true)
    spacer:SetLayout("List")
    spacer:SetAutoAdjustHeight(false)
    spacer:SetHeight(height)
    return spacer
end

local function CreateSectionHeader(text)
    return CreateLabel(text, "sectionHeader", 13, nil, true)
end

local function StyleCheckBox(widget, disabled)
    if FormWidgets.StyleCheckBox then
        FormWidgets.StyleCheckBox(widget, disabled == true)
    end
end

local function ResolveBooleanLabel(value)
    return value and (T("OPTION_ON", "On")) or T("OPTION_OFF", "Off")
end

local function SetBooleanControlValue(widget, value, disabled)
    if not widget then
        return
    end

    widget:SetValue(value == true)
    widget:SetLabel(ResolveBooleanLabel(value == true))
    widget:SetDisabled(disabled == true)
    StyleCheckBox(widget, disabled == true)
end

local function CreateOptionRow(parent, labelText, widgetId)
    local row = AceGUI:Create("SimpleGroup")
    row:SetFullWidth(true)
    row:SetHeight(OPTION_ROW_HEIGHT)
    row:SetLayout("Table")
    row:SetUserData("table", {
        columns = {
            { width = OPTION_LABEL_WIDTH },
            { weight = 1 },
        },
        spaceH = 8,
        spaceV = 0,
        align = "TOPLEFT",
        alignV = "center",
        alignH = "start",
    })
    parent:AddChild(row)

    row:AddChild(CreateLabel(labelText, "label", 12, OPTION_LABEL_WIDTH, false))

    local checkbox = AceGUI:Create("CheckBox")
    checkbox:SetFullWidth(false)
    checkbox:SetWidth(72)
    StyleCheckBox(checkbox)
    if context and context.widgets and widgetId then
        context.widgets[widgetId] = checkbox
    end
    row:AddChild(checkbox)
    return checkbox
end

local function CreateOptionHint(text)
    return CreateLabel(text, "muted", 11, nil, true)
end

function Refresh()
    if not context or not context.widgets then
        return
    end

    local isExpert = IsExpertMode()
    context.suspendCallbacks = true
    SetBooleanControlValue(context.widgets.snappingEnabled, IsSnappingEnabled())
    SetBooleanControlValue(context.widgets.showGrid, IsGridEnabled())
    if context.widgets.mouseEnabled then
        SetBooleanControlValue(context.widgets.mouseEnabled, GetGlobalOptionValue("mouseEnabled") == true, not isExpert)
    end
    if context.widgets.showUnitTooltips then
        SetBooleanControlValue(context.widgets.showUnitTooltips, GetGlobalOptionValue("showUnitTooltips") == true)
    end
    if context.widgets.clickthrough then
        SetBooleanControlValue(context.widgets.clickthrough, GetGlobalOptionValue("clickthrough") == true, not isExpert)
    end
    if context.widgets.showMinimapButton then
        SetBooleanControlValue(context.widgets.showMinimapButton, GetGlobalOptionValue("showMinimapButton") == true)
    end
    if context.widgets.hideBlizzard then
        SetBooleanControlValue(context.widgets.hideBlizzard, GetGlobalOptionValue("hideBlizzard") == true)
    end
    context.suspendCallbacks = false
end

local function WireCallbacks()
    if not context or not context.widgets then
        return
    end

    local showGrid = context.widgets.showGrid
    if showGrid then
        showGrid:SetCallback("OnValueChanged", function(_, _, value)
            if context.suspendCallbacks then
                return
            end
            local general = GetGeneralConfig()
            if type(general) ~= "table" then
                return
            end

            general.ShowGrid = value == true
            RefreshUnlockGrid()
            Refresh()
        end)
    end

    local snapping = context.widgets.snappingEnabled
    if snapping then
        snapping:SetCallback("OnValueChanged", function(_, _, value)
            if context.suspendCallbacks then
                return
            end
            local general = GetGeneralConfig()
            if type(general) ~= "table" then
                return
            end

            general.SnappingEnabled = value ~= false
            if value == false then
                HideSnapLines()
            end
            Refresh()
        end)
    end

    local globalOptions = {
        mouseEnabled = "mouseEnabled",
        showUnitTooltips = "showUnitTooltips",
        clickthrough = "clickthrough",
        showMinimapButton = "showMinimapButton",
        hideBlizzard = "hideBlizzard",
    }
    for widgetId, optionId in pairs(globalOptions) do
        local checkbox = context.widgets[widgetId]
        if checkbox then
            checkbox:SetCallback("OnValueChanged", function(_, _, value)
                if context.suspendCallbacks then
                    return
                end
                ApplyGlobalOptionValue(optionId, value == true)
            end)
        end
    end

end

local function CreateWindow()
    local dialog = FormWidgets.CreateCompactFormDialog({
        title = T("EDITOR_OPTIONS_TITLE", "Focal Point Options"),
        width = 360,
        formContentHeight = 286,
        footerHeight = 40,
        contentInset = 14,
        addBodySpacer = false,
        bodyLayout = "List",
    })
    local window = dialog.window
    local body = dialog.body

    local widgets = {}
    context = {
        window = window,
        dialog = dialog,
        widgets = widgets,
        suspendCallbacks = false,
    }

    body:AddChild(CreateSectionHeader(T("EDITOR_OPTIONS_SECTION_EDITOR", "Editor")))
    CreateOptionRow(body, T("OPTION_SHOW_GRID", "Show Grid"), "showGrid")
    body:AddChild(CreateOptionHint(T("OPTION_SHOW_GRID_DESC", "Displays a visual alignment grid while editing frames.")))
    body:AddChild(CreateVerticalGap(ROW_GAP))
    CreateOptionRow(body, T("OPTION_ENABLE_SNAPPING", "Enable Snapping"), "snappingEnabled")
    body:AddChild(CreateOptionHint(T("OPTION_ENABLE_SNAPPING_DESC", "Snap frames to the screen center and other editable frames while moving them.")))
    body:AddChild(CreateVerticalGap(ROW_GAP))
    CreateOptionRow(body, T("OPTION_MOUSE_ENABLED", "Mouse Enabled"), "mouseEnabled")
    body:AddChild(CreateVerticalGap(ROW_GAP))
    CreateOptionRow(body, T("OPTION_GLOBAL_CLICKTHROUGH", "Global Click Through"), "clickthrough")
    body:AddChild(CreateVerticalGap(SECTION_GAP))
    body:AddChild(CreateSectionHeader(T("EDITOR_CONTEXT_GLOBAL", "Addon")))
    CreateOptionRow(body, T("OPTION_SHOW_MINIMAP_BUTTON", "Show Minimap Button"), "showMinimapButton")
    body:AddChild(CreateVerticalGap(ROW_GAP))
    CreateOptionRow(body, T("OPTION_SHOW_UNIT_TOOLTIPS", "Show Unit Tooltips"), "showUnitTooltips")
    body:AddChild(CreateVerticalGap(ROW_GAP))
    CreateOptionRow(body, T("OPTION_HIDE_BLIZZARD_FRAMES", "Hide Blizzard Frames"), "hideBlizzard")
    body:AddChild(CreateVerticalGap(ROW_GAP))

    dialog:SetActions({
        cancel = {
            text = T("OPTION_CLOSE", "Close"),
            width = 96,
            onClick = function()
                dialog:Close()
            end,
        },
    })

    window:SetCallback("OnClose", function()
        HideSnapLines()
    end)

    WireCallbacks()
    return dialog
end

function OptionsDialog.Open()
    if context and context.dialog then
        Refresh()
        context.dialog:Show()
        return true
    end

    local dialog = CreateWindow()
    Refresh()
    dialog:Show()
    return true
end

function OptionsDialog.Close()
    if context and context.window and context.window.Hide then
        context.window:Hide()
    end
end

return OptionsDialog
