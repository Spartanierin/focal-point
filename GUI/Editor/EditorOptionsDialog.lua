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

local function CreateLabel(text, role, size)
    local label = AceGUI:Create("Label")
    label:SetFullWidth(true)
    label:SetText(text or "")
    ApplyLabelText(label, role or "label", { size = size or 12 })
    return label
end

local function CreateSpacer(height)
    local spacer = AceGUI:Create("Label")
    spacer:SetFullWidth(true)
    spacer:SetText("")
    spacer:SetHeight(height or 6)
    return spacer
end

local function CreateSectionHeader(text)
    local group = AceGUI:Create("SimpleGroup")
    group:SetFullWidth(true)
    group:SetHeight(22)
    group:SetLayout("Flow")

    local frame = group.frame
    if frame then
        local label = frame:CreateFontString(nil, "ARTWORK")
        label:SetPoint("LEFT", frame, "LEFT", 0, 0)
        TextStyles.ApplyFontString(label, "sectionHeader", { size = 13 })
        label:SetText(text or "")
        frame._fpOptionsHeaderLabel = label

        local line = frame:CreateTexture(nil, "BORDER")
        line:SetPoint("LEFT", label, "RIGHT", 10, 0)
        line:SetPoint("RIGHT", frame, "RIGHT", 0, 0)
        line:SetHeight(1)
        line:SetColorTexture(0.906, 0.769, 0.290, 0.30)
        frame._fpOptionsHeaderLine = line
    end

    return group
end

local function CreateIndentedDescription(text)
    local group = AceGUI:Create("SimpleGroup")
    group:SetFullWidth(true)
    group:SetLayout("Flow")

    local indent = AceGUI:Create("Label")
    indent:SetText("")
    indent:SetWidth(24)
    group:AddChild(indent)

    local description = AceGUI:Create("Label")
    description:SetText(text or "")
    description:SetWidth(246)
    ApplyLabelText(description, "muted", { size = 11 })
    group:AddChild(description)

    return group
end

local function CreateButton(text, role, width)
    local button = AceGUI:Create("Button")
    button:SetText(text or "")
    button:SetFullWidth(false)
    button:SetWidth(width or 96)
    if FormWidgets.ApplyModalActionButtonVisual then
        FormWidgets.ApplyModalActionButtonVisual(button, role or "utility")
    end
    return button
end

local function ApplyContentInsets(window)
    local frame = window and window.frame
    local content = window and window.content
    if not frame or not content or not content.ClearAllPoints or not content.SetPoint then
        return
    end

    content:ClearAllPoints()
    content:SetPoint("TOPLEFT", frame, "TOPLEFT", 22, -46)
    content:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -22, 42)
end

local function StyleCheckBox(widget)
    if FormWidgets.StyleCheckBox then
        FormWidgets.StyleCheckBox(widget, false)
    end
end

local function CreateCheckBox(label, widgetId)
    local checkbox = AceGUI:Create("CheckBox")
    checkbox:SetFullWidth(true)
    checkbox:SetLabel(label or "")
    StyleCheckBox(checkbox)
    if context and context.widgets and widgetId then
        context.widgets[widgetId] = checkbox
    end
    return checkbox
end

local CenterWindow = FormWidgets.CenterWindow

local function FocusWindow(window)
    FormWidgets.FocusWindow(window)
end

local function EnableEscapeClose(window)
    local frame = window and window.frame
    if not frame then
        return
    end

    if frame.EnableKeyboard then
        frame:EnableKeyboard(true)
    end
    if frame.SetScript then
        frame:SetScript("OnKeyDown", function(_, key)
            if key == "ESCAPE" and window.Hide then
                window:Hide()
            end
        end)
    end
end

function Refresh()
    if not context or not context.widgets then
        return
    end

    local isExpert = IsExpertMode()
    if context.widgets.snappingEnabled then
        context.suspendCallbacks = true
        context.widgets.snappingEnabled:SetValue(IsSnappingEnabled())
        context.suspendCallbacks = false
    end
    if context.widgets.showGrid then
        context.suspendCallbacks = true
        context.widgets.showGrid:SetValue(IsGridEnabled())
        context.suspendCallbacks = false
    end

    context.suspendCallbacks = true
    if context.widgets.mouseEnabled then
        context.widgets.mouseEnabled:SetValue(GetGlobalOptionValue("mouseEnabled") == true)
        context.widgets.mouseEnabled:SetDisabled(not isExpert)
    end
    if context.widgets.clickthrough then
        context.widgets.clickthrough:SetValue(GetGlobalOptionValue("clickthrough") == true)
        context.widgets.clickthrough:SetDisabled(not isExpert)
    end
    if context.widgets.showMinimapButton then
        context.widgets.showMinimapButton:SetValue(GetGlobalOptionValue("showMinimapButton") == true)
    end
    if context.widgets.hideBlizzard then
        context.widgets.hideBlizzard:SetValue(GetGlobalOptionValue("hideBlizzard") == true)
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

    local closeButton = context.widgets.closeButton
    if closeButton then
        closeButton:SetCallback("OnClick", function()
            if context and context.window and context.window.Hide then
                context.window:Hide()
            end
        end)
    end
end

local function CreateWindow()
    local window = AceGUI:Create("Window")
    window:SetTitle(T("EDITOR_OPTIONS_TITLE", "Focal Point Options"))
    window:SetLayout("Flow")
    window:SetWidth(340)
    window:SetHeight(348)
    window:EnableResize(false)

    if window.frame then
        window.frame:SetClampedToScreen(true)
    end
    if FormWidgets.ApplyWindowChrome then
        FormWidgets.ApplyWindowChrome(window)
    end
    if FormWidgets.EnsureStandardWindowCloseButton then
        FormWidgets.EnsureStandardWindowCloseButton(window)
    end
    ApplyContentInsets(window)
    EnableEscapeClose(window)

    local widgets = {}
    context = {
        window = window,
        widgets = widgets,
        suspendCallbacks = false,
    }

    window:AddChild(CreateSectionHeader(T("EDITOR_OPTIONS_SECTION_EDITOR", "Editor")))

    local showGrid = CreateCheckBox(T("OPTION_SHOW_GRID", "Show Grid"), "showGrid")
    window:AddChild(showGrid)
    window:AddChild(CreateIndentedDescription(T("OPTION_SHOW_GRID_DESC", "Displays a visual alignment grid while frames are unlocked.")))
    window:AddChild(CreateSpacer(4))

    local snapping = CreateCheckBox(T("OPTION_ENABLE_SNAPPING", "Enable Snapping"), "snappingEnabled")
    window:AddChild(snapping)

    window:AddChild(CreateIndentedDescription(T("OPTION_ENABLE_SNAPPING_DESC", "Snap frames to the screen center and other editable frames while moving them.")))
    window:AddChild(CreateSpacer(4))

    local mouseEnabled = CreateCheckBox(T("OPTION_MOUSE_ENABLED", "Mouse Enabled"), "mouseEnabled")
    window:AddChild(mouseEnabled)

    local clickthrough = CreateCheckBox(T("OPTION_GLOBAL_CLICKTHROUGH", "Global Click Through"), "clickthrough")
    window:AddChild(clickthrough)

    window:AddChild(CreateSpacer(8))
    window:AddChild(CreateSectionHeader(T("EDITOR_CONTEXT_GLOBAL", "Addon")))

    local showMinimapButton = CreateCheckBox(T("OPTION_SHOW_MINIMAP_BUTTON", "Show Minimap Button"), "showMinimapButton")
    window:AddChild(showMinimapButton)

    local hideBlizzard = CreateCheckBox(T("OPTION_HIDE_BLIZZARD_FRAMES", "Hide Blizzard Frames"), "hideBlizzard")
    window:AddChild(hideBlizzard)

    window:AddChild(CreateSpacer(6))

    local footer = AceGUI:Create("SimpleGroup")
    footer:SetLayout("Flow")
    footer:SetFullWidth(true)
    footer:SetHeight(28)
    window:AddChild(footer)

    local footerSpacer = AceGUI:Create("Label")
    footerSpacer:SetText("")
    footerSpacer:SetWidth(178)
    footer:AddChild(footerSpacer)

    local closeButton = CreateButton(T("OPTION_CLOSE", "Close"), "utility", 96)
    footer:AddChild(closeButton)
    widgets.closeButton = closeButton

    window:SetCallback("OnClose", function()
        HideSnapLines()
    end)

    WireCallbacks()
    CenterWindow(window)
    return window
end

function OptionsDialog.Open()
    if context and context.window then
        Refresh()
        FocusWindow(context.window)
        return true
    end

    local window = CreateWindow()
    Refresh()
    FocusWindow(window)
    return true
end

function OptionsDialog.Close()
    if context and context.window and context.window.Hide then
        context.window:Hide()
    end
end

return OptionsDialog
