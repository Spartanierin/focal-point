local _, ns = ...

ns.GUI = ns.GUI or {}
ns.GUI.Editor = ns.GUI.Editor or {}
ns.GUI.Editor.LayoutAssignments = ns.GUI.Editor.LayoutAssignments or {}

local AceGUI = LibStub("AceGUI-3.0")
local FormWidgets = ns.GUI.Helpers and ns.GUI.Helpers.FormWidgets or {}
local TextStyles = ns.GUI.Helpers and ns.GUI.Helpers.TextStyles or {}
local LayoutAssignments = {}
ns.GUI.Editor.LayoutAssignments = LayoutAssignments

local WINDOW_WIDTH = 520
local WINDOW_HEIGHT = 320
local NONE_VALUE = "__fp_assignment_none__"

local context

local SECTION_CHROME = {
    fill = { 0.060, 0.068, 0.084, 0.56 },
    border = { 0.25, 0.28, 0.33, 0.54 },
    footerFill = { 0.065, 0.072, 0.088, 0.66 },
    footerBorder = { 0.30, 0.32, 0.36, 0.44 },
}

local function T(key, fallback)
    local L = ns.L or {}
    local value = L[key]
    return type(value) == "string" and value ~= "" and value or fallback or key
end

local function CreateLabel(text, role, size, width)
    local label = AceGUI:Create("Label")
    label:SetText(text or "")
    if width then
        label:SetFullWidth(false)
        label:SetWidth(width)
    else
        label:SetFullWidth(true)
    end
    if FormWidgets.ApplyTextStyle and label.label then
        FormWidgets.ApplyTextStyle(label.label, role or "label", size or 11, 1)
    elseif TextStyles.ApplyLabelWidget then
        TextStyles.ApplyLabelWidget(label, role or "label", { size = size or 11 })
    end
    return label
end

local function CreateSpacer(width, height)
    local spacer = AceGUI:Create("Label")
    spacer:SetText("")
    if width then
        spacer:SetFullWidth(false)
        spacer:SetWidth(width)
    else
        spacer:SetFullWidth(true)
    end
    if height and spacer.SetHeight then
        spacer:SetHeight(height)
    end
    return spacer
end

local function LockContainerHeight(container, height)
    if not container then
        return
    end
    if container.SetAutoAdjustHeight then
        container:SetAutoAdjustHeight(false)
    end
    container:SetHeight(height)
end

local function ApplySectionChrome(widget, colors)
    local frame = widget and widget.frame
    if not (frame and frame.SetBackdrop and colors) then
        return
    end

    frame:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
    })
    frame:SetBackdropColor(colors.fill[1], colors.fill[2], colors.fill[3], colors.fill[4] or 1)
    frame:SetBackdropBorderColor(colors.border[1], colors.border[2], colors.border[3], colors.border[4] or 1)
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

local function FocusWindow(window)
    if FormWidgets.FocusWindow then
        FormWidgets.FocusWindow(window, { centerIfHidden = true, strata = "FULLSCREEN_DIALOG" })
        return
    end
    if window and window.Show then
        window:Show()
    end
end

local function ResolveSpecInfo(specIndex)
    if C_SpecializationInfo and type(C_SpecializationInfo.GetSpecializationInfo) == "function" then
        local ok, specID, name = pcall(C_SpecializationInfo.GetSpecializationInfo, specIndex)
        if ok and type(specID) == "number" and specID > 0 then
            return specID, name
        end
    end
    if type(GetSpecializationInfo) == "function" then
        local ok, specID, name = pcall(GetSpecializationInfo, specIndex)
        if ok and type(specID) == "number" and specID > 0 then
            return specID, name
        end
    end
    return nil
end

local function BuildSpecs()
    local specs = {}
    local count = 0
    if type(GetNumSpecializations) == "function" then
        local ok, value = pcall(GetNumSpecializations)
        if ok and type(value) == "number" then
            count = value
        end
    end
    for index = 1, count do
        local specID, name = ResolveSpecInfo(index)
        if type(specID) == "number" and specID > 0 then
            specs[#specs + 1] = {
                id = specID,
                name = type(name) == "string" and name ~= "" and name or tostring(specID),
                index = index,
            }
        end
    end
    return specs
end

local function ResolveLayoutName(summary)
    if type(summary) ~= "table" then
        return ""
    end
    local L = ns.L or {}
    if type(summary.labelKey) == "string" and L[summary.labelKey] then
        return L[summary.labelKey]
    end
    if type(summary.name) == "string" and summary.name ~= "" then
        return summary.name
    end
    return type(summary.id) == "string" and summary.id or ""
end

local function BuildLayoutDropdownData()
    local values = {
        [NONE_VALUE] = T("LAYOUT_ASSIGNMENT_NONE", "None"),
    }
    local order = { NONE_VALUE }
    local layoutService = ns.LayoutService or {}
    local summaries = layoutService.ListLayoutSummaries and layoutService.ListLayoutSummaries({ db = ns.db }) or {}

    for _, summary in ipairs(summaries) do
        if summary.source == "builtin" or summary.source == "userLayout" then
            values[summary.id] = ResolveLayoutName(summary)
            order[#order + 1] = summary.id
        end
    end
    return values, order
end

local function GetCurrentSpecID()
    local service = ns.LayoutAssignmentService or {}
    if service.GetCurrentSpecialization then
        local specID = service.GetCurrentSpecialization()
        return type(specID) == "number" and specID or nil
    end
    return nil
end

local function ResolveAssignedDropdownValue(specID)
    local service = ns.LayoutAssignmentService or {}
    if not service.GetSpecializationAssignment then
        return NONE_VALUE, "missing"
    end
    local layoutId, status = service.GetSpecializationAssignment(specID)
    if status == "ok" and type(layoutId) == "string" and layoutId ~= "" then
        return layoutId, status
    end
    return NONE_VALUE, status or "missing"
end

local function RefreshRows()
    if not (context and context.widgets and context.widgets.body) then
        return
    end

    context._suspendCallbacks = true
    local body = context.widgets.body
    body:ReleaseChildren()

    local specs = BuildSpecs()
    local layoutValues, layoutOrder = BuildLayoutDropdownData()
    local currentSpecID = GetCurrentSpecID()

    local header = AceGUI:Create("SimpleGroup")
    header:SetLayout("Flow")
    header:SetFullWidth(true)
    LockContainerHeight(header, 24)
    body:AddChild(header)
    header:AddChild(CreateSpacer(8, 1))
    header:AddChild(CreateLabel(T("LAYOUT_ASSIGNMENT_SPEC", "Specialization"), "sectionHeader", 11, 160))
    header:AddChild(CreateSpacer(10, 1))
    header:AddChild(CreateLabel(T("LAYOUT_ASSIGNMENT_LAYOUT", "Layout"), "sectionHeader", 11, 255))

    if #specs == 0 then
        local empty = CreateLabel(T("LAYOUT_ASSIGNMENT_NO_SPECS", "No specializations available."), "help", 11, 455)
        body:AddChild(empty)
        if context.window and context.window.DoLayout then
            context.window:DoLayout()
        end
        context._suspendCallbacks = false
        return
    end

    for _, spec in ipairs(specs) do
        local row = AceGUI:Create("SimpleGroup")
        row:SetLayout("Flow")
        row:SetFullWidth(true)
        LockContainerHeight(row, 42)
        body:AddChild(row)

        row:AddChild(CreateSpacer(8, 1))
        local specLabel = spec.name
        if spec.id == currentSpecID then
            specLabel = specLabel .. "  " .. T("LAYOUT_ASSIGNMENT_CURRENT", "Current")
        end
        row:AddChild(CreateLabel(specLabel, spec.id == currentSpecID and "sectionHeader" or "label", 11, 160))
        row:AddChild(CreateSpacer(10, 1))

        local dropdown = AceGUI:Create("Dropdown")
        dropdown:SetWidth(255)
        dropdown:SetList(layoutValues, layoutOrder)
        local assignedValue = ResolveAssignedDropdownValue(spec.id)
        dropdown:SetValue(assignedValue)
        if FormWidgets.StyleDropdown then
            FormWidgets.StyleDropdown(dropdown, "editor_inset")
        end
        dropdown:SetCallback("OnValueChanged", function(_, _, value)
            if context._suspendCallbacks then
                return
            end
            local service = ns.LayoutAssignmentService or {}
            if not service.SetSpecializationAssignment then
                return
            end
            local nextLayoutId = value ~= NONE_VALUE and value or nil
            local ok = service.SetSpecializationAssignment(spec.id, nextLayoutId)
            if ok and spec.id == GetCurrentSpecID() and service.EvaluateCurrentSpecializationAssignment then
                service.EvaluateCurrentSpecializationAssignment("assignment:ui")
            end
            local canvasToolbar = ns.GUI and ns.GUI.Editor and ns.GUI.Editor.CanvasToolbar or nil
            if canvasToolbar and type(canvasToolbar.Refresh) == "function" then
                canvasToolbar.Refresh()
            end
            RefreshRows()
        end)
        row:AddChild(dropdown)
    end

    if context.window and context.window.DoLayout then
        context.window:DoLayout()
    end
    context._suspendCallbacks = false
end

local function Close()
    if context and context.window and context.window.Hide then
        context.window:Hide()
    end
end

local function CreateWindow()
    local window = AceGUI:Create("Window")
    window:SetTitle(T("LAYOUT_ASSIGNMENT_TITLE", "Assignments"))
    window:SetLayout("Fill")
    window:SetWidth(WINDOW_WIDTH)
    window:SetHeight(WINDOW_HEIGHT)
    window:EnableResize(false)

    if window.frame then
        window.frame:SetClampedToScreen(true)
        window.frame:SetFrameStrata("FULLSCREEN_DIALOG")
    end
    if FormWidgets.ApplyWindowChrome then
        FormWidgets.ApplyWindowChrome(window)
    end
    if FormWidgets.EnsureStandardWindowCloseButton then
        FormWidgets.EnsureStandardWindowCloseButton(window)
    end
    EnableEscapeClose(window)

    local root = AceGUI:Create("SimpleGroup")
    root:SetLayout("Flow")
    root:SetFullWidth(true)
    root:SetFullHeight(true)
    window:AddChild(root)

    local titleRow = AceGUI:Create("SimpleGroup")
    titleRow:SetLayout("Flow")
    titleRow:SetFullWidth(true)
    LockContainerHeight(titleRow, 34)
    root:AddChild(titleRow)
    titleRow:AddChild(CreateSpacer(12, 1))
    titleRow:AddChild(CreateLabel(T("LAYOUT_ASSIGNMENT_DESCRIPTION", "Assign layouts to your current class specializations."), "help", 11, 470))

    local body = AceGUI:Create("SimpleGroup")
    body:SetLayout("Flow")
    body:SetFullWidth(true)
    body:SetHeight(205)
    root:AddChild(body)
    ApplySectionChrome(body, SECTION_CHROME)

    local footer = AceGUI:Create("SimpleGroup")
    footer:SetLayout("Flow")
    footer:SetFullWidth(true)
    LockContainerHeight(footer, 42)
    root:AddChild(footer)
    ApplySectionChrome(footer, {
        fill = SECTION_CHROME.footerFill,
        border = SECTION_CHROME.footerBorder,
    })

    footer:AddChild(CreateSpacer(390, 1))
    local closeButton = FormWidgets.CreateActionButton and FormWidgets.CreateActionButton(T("INFO_COMMON_CLOSE", "Close"), "utility", 105, false) or AceGUI:Create("Button")
    closeButton:SetText(T("INFO_COMMON_CLOSE", "Close"))
    closeButton:SetWidth(105)
    closeButton:SetFullWidth(false)
    if FormWidgets.ApplyModalActionButtonVisual then
        FormWidgets.ApplyModalActionButtonVisual(closeButton, "utility")
    end
    closeButton:SetCallback("OnClick", Close)
    footer:AddChild(closeButton)

    context = {
        window = window,
        widgets = {
            root = root,
            body = body,
            footer = footer,
            closeButton = closeButton,
        },
    }

    window:SetCallback("OnClose", function()
        if GameTooltip and GameTooltip.Hide then
            GameTooltip:Hide()
        end
    end)

    if FormWidgets.CenterWindow then
        FormWidgets.CenterWindow(window)
    end
    FocusWindow(window)
    RefreshRows()
    return window
end

function LayoutAssignments.Open()
    context = context or {}
    if context.window then
        RefreshRows()
        FocusWindow(context.window)
        return true
    end
    CreateWindow()
    return true
end

function LayoutAssignments.Refresh()
    if context and context.window then
        RefreshRows()
    end
end

function LayoutAssignments.Close()
    Close()
end

return LayoutAssignments
