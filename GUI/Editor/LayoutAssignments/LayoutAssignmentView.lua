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
local WINDOW_CHROME_HEIGHT = 57
local WINDOW_DESCRIPTION_TEXT_HEIGHT = 24
local WINDOW_DESCRIPTION_GAP = 8
local WINDOW_CONTENT_PADDING = 12
local WINDOW_TABLE_HEADER_HEIGHT = 24
local WINDOW_SPEC_ROW_HEIGHT = 42
local NONE_VALUE = "__fp_assignment_none__"

local context

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

local function CalculateWindowHeight(body)
    local height = WINDOW_CHROME_HEIGHT + 6 + 8 -- body top inset and bottom margin
    for _, child in ipairs(body.children) do
        height = height + child.frame:GetHeight() + 3 -- existing full-width Flow spacing
    end
    return height
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
        [NONE_VALUE] = T("LAYOUT_ASSIGNMENT_NONE", "No assignment"),
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

local function AddDefaultContext(body, layoutValues)
    local service = ns.LayoutAssignmentService or {}
    local layoutId, status
    if service.GetAccountDefaultLayoutId then
        layoutId, status = service.GetAccountDefaultLayoutId(ns.db)
    end
    local name = layoutId and (layoutValues[layoutId] or layoutId)
        or T(status == "stale" and "LAYOUT_ASSIGNMENT_DEFAULT_INVALID" or "LAYOUT_ASSIGNMENT_DEFAULT_NONE",
            status == "stale" and "Unavailable (invalid reference)" or "Not set")
    local text = string.format(T("LAYOUT_ASSIGNMENT_DEFAULT_CONTEXT", "Account default: %s"), name)
    local tooltip = text .. "\n" .. T("LAYOUT_ASSIGNMENT_SPEC_PRIORITY", "A valid specialization assignment takes priority.")
    body:AddChild(CreateSpacer(nil, 8))
    local label = AceGUI:Create("InteractiveLabel")
    label:SetText(text)
    label:SetFullWidth(true)
    label:SetHeight(24)
    local wordWrap = label.label.CanWordWrap and label.label:CanWordWrap()
    local maxLines = label.label.GetMaxLines and label.label:GetMaxLines()
    if wordWrap ~= nil then label.label:SetWordWrap(false) end
    if maxLines ~= nil then label.label:SetMaxLines(1) end
    if FormWidgets.ApplyTextStyle then FormWidgets.ApplyTextStyle(label.label, "label", 11, 1) end
    label:SetCallback("OnEnter", function(widget)
        if GameTooltip then
            GameTooltip:SetOwner(widget.frame, "ANCHOR_RIGHT")
            GameTooltip:SetText(tooltip, 1, 1, 1, 1, true)
            GameTooltip:Show()
        end
    end)
    label:SetCallback("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
    label:SetCallback("OnRelease", function()
        if GameTooltip and GameTooltip:GetOwner() == label.frame then GameTooltip:Hide() end
        if wordWrap ~= nil then label.label:SetWordWrap(wordWrap) end
        if maxLines ~= nil then label.label:SetMaxLines(maxLines) end
    end)
    body:AddChild(label)
    local hint = CreateLabel(T("LAYOUT_ASSIGNMENT_FALLBACK_HINT",
        "Without an assignment, specialization changes keep the current layout. At login, the account default is used if no valid assignment exists."), "help", 11)
    body:AddChild(hint)
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

    local description = CreateLabel(T("LAYOUT_ASSIGNMENT_DESCRIPTION", "Assign layouts to your current class specializations."), "help", 11)
    description:SetHeight(WINDOW_DESCRIPTION_TEXT_HEIGHT)
    body:AddChild(description)
    body:AddChild(CreateSpacer(nil, WINDOW_DESCRIPTION_GAP))

    local header = AceGUI:Create("SimpleGroup")
    header:SetUserData("table", {
        columns = { { width = 180, alignH = "fill" }, { weight = 1, alignH = "fill" } },
        spaceH = 12, alignV = "middle",
    })
    header:SetLayout("Table")
    header:SetFullWidth(true)
    LockContainerHeight(header, 24)
    body:AddChild(header)
    header:AddChild(CreateLabel(T("LAYOUT_ASSIGNMENT_SPEC", "Specialization"), "sectionHeader", 12))
    header:AddChild(CreateLabel(T("LAYOUT_ASSIGNMENT_LAYOUT", "Assigned layout"), "sectionHeader", 12))

    if #specs == 0 then
        local empty = CreateLabel(T("LAYOUT_ASSIGNMENT_NO_SPECS", "No specializations available."), "help", 11, 455)
        body:AddChild(empty)
        AddDefaultContext(body, layoutValues)
        body:AddChild(CreateSpacer(nil, WINDOW_CONTENT_PADDING))
        if context.window and context.window.DoLayout then
            context.window:DoLayout()
            context.window:SetHeight(CalculateWindowHeight(body))
        end
        context._suspendCallbacks = false
        return
    end

    for _, spec in ipairs(specs) do
        local row = AceGUI:Create("SimpleGroup")
        row:SetUserData("table", {
            columns = { { width = 180, alignH = "fill" }, { weight = 1, alignH = "fill" } },
            spaceH = 12, alignV = "middle",
        })
        row:SetLayout("Table")
        row:SetFullWidth(true)
        LockContainerHeight(row, 42)
        body:AddChild(row)

        local specLabel = spec.name
        if spec.id == currentSpecID then
            specLabel = specLabel .. "  " .. T("LAYOUT_ASSIGNMENT_CURRENT", "Current")
        end
        local label = CreateLabel(specLabel, spec.id == currentSpecID and "sectionHeader" or "label", 11)
        label:SetHeight(32)
        row:AddChild(label)

        local dropdown = AceGUI:Create("Dropdown")
        dropdown:SetFullWidth(true)
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

    AddDefaultContext(body, layoutValues)
    body:AddChild(CreateSpacer(nil, WINDOW_CONTENT_PADDING))

    if context.window and context.window.DoLayout then
        context.window:DoLayout()
        context.window:SetHeight(CalculateWindowHeight(body))
    end
    context._suspendCallbacks = false
end

local function CreateWindow()
    local dialog = FormWidgets.CreateCompactFormDialog({
        title = T("LAYOUT_ASSIGNMENT_TITLE", "Specialization Assignments"),
        width = WINDOW_WIDTH,
        height = WINDOW_CHROME_HEIGHT + WINDOW_TABLE_HEADER_HEIGHT + WINDOW_SPEC_ROW_HEIGHT,
        bodyLayout = "Flow",
        contentRoot = true,
        windowChrome = "modern",
        portrait = false,
        background = "blizzard",
        topTileStreaks = true,
    })
    context = {
        window = dialog.window,
        widgets = {
            body = dialog.body,
        },
    }

    dialog.window:SetCallback("OnClose", function()
        if GameTooltip and GameTooltip.Hide then
            GameTooltip:Hide()
        end
    end)

    if FormWidgets.CenterWindow then
        FormWidgets.CenterWindow(dialog.window)
    end
    FocusWindow(dialog.window)
    RefreshRows()
    return dialog.window
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
    if context and context.window and context.window.Hide then
        context.window:Hide()
    end
end

return LayoutAssignments
