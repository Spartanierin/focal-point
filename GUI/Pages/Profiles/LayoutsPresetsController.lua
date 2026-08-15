local _, ns = ...

ns.GUI = ns.GUI or {}
ns.GUI.Pages = ns.GUI.Pages or {}

local AceGUI = LibStub("AceGUI-3.0")
local L = ns.L or {}
local FormWidgets = ns.GUI.Helpers and ns.GUI.Helpers.FormWidgets or {}
local PresetUI = ns.GUI.Editor and ns.GUI.Editor.PresetUI or {}

local LayoutsPresetsController = {}
ns.GUI.Pages.LayoutsPresets = LayoutsPresetsController

local CreateBodyText = FormWidgets.CreateBodyText
local CreateActionButton = FormWidgets.CreateActionButton
local StyleDropdown = FormWidgets.StyleDropdown
local ApplyModalActionButtonVisual = FormWidgets.ApplyModalActionButtonVisual

local function T(key, fallback)
    return (type(key) == "string" and L[key]) or fallback or ""
end

local function RequestRefreshOptions()
    if ns.GUI and ns.GUI.RequestRefreshOptions then
        ns.GUI:RequestRefreshOptions()
    end
end

local function GetEditorPresetState()
    local editorState = ns.GUI and ns.GUI.Editor and ns.GUI.Editor.State
    if editorState and editorState.Get then
        return editorState.Get()
    end
    return nil
end

local function BuildPresetContext()
    return {
        state = GetEditorPresetState(),
    }
end

local function BuildDeps()
    return {
        AceGUI = AceGUI,
        L = L,
        ns = ns,
        ThemeService = ns.ThemeService or {},
        PresetService = ns.PresetService or {},
        ProfileLayoutService = ns.ProfileLayoutService or {},
        CreateBodyText = CreateBodyText,
        CreateActionButton = CreateActionButton,
        StyleDropdown = StyleDropdown,
        StyleEditBox = FormWidgets.StyleEditBox,
        ApplyWindowChrome = FormWidgets.ApplyWindowChrome,
        EnsureStandardWindowCloseButton = FormWidgets.EnsureStandardWindowCloseButton,
    }
end

local function AddText(root, text, role, size, width)
    local widget = CreateBodyText
        and CreateBodyText(text or "", role or "label", size or 12, nil, width, true)
        or AceGUI:Create("Label")
    widget:SetFullWidth(true)
    widget:SetText(text or "")
    root:AddChild(widget)
    return widget
end

local function AddActionButton(row, text, variant, width)
    local button = CreateActionButton
        and CreateActionButton(text, variant or "utility", width or 130, false)
        or AceGUI:Create("Button")
    button:SetText(text or "")
    button:SetWidth(width or 130)
    row:AddChild(button)
    if ApplyModalActionButtonVisual then
        ApplyModalActionButtonVisual(button, variant or "utility")
    end
    return button
end

function LayoutsPresetsController.Render(root, context)
    if not root or not context then
        return nil
    end

    local deps = BuildDeps()
    local presetContext = BuildPresetContext()
    local view = PresetUI.BuildPresetViewData
        and PresetUI.BuildPresetViewData(presetContext.state, deps, {
            includeCustom = false,
            descriptionFallback = "",
        })
        or {}

    AddText(root, T("LAYOUTS_PRESETS", "Presets"), "sectionHeader", 13)
    AddText(root, T("EDITOR_PRESET_CONTEXT_HINT", "Presets define the starting layout and visual direction. Every property remains freely editable afterwards."), "muted", 11)

    local dropdown = AceGUI:Create("Dropdown")
    dropdown:SetFullWidth(true)
    dropdown:SetLabel(T("EDITOR_PRESET_SELECT", T("THEME_SELECT", "Select Preset")))
    dropdown:SetList(view.presetList or {}, view.presetOrder)
    dropdown:SetValue(view.selectedPresetId)
    dropdown:SetDisabled(next(view.presetList or {}) == nil)
    if StyleDropdown then
        StyleDropdown(dropdown, "accented")
    end
    root:AddChild(dropdown)

    local description = nil
    if type(view.description) == "string" and view.description ~= "" then
        description = AddText(root, view.description, "muted", 11)
    end

    local row = AceGUI:Create("SimpleGroup")
    row:SetLayout("Flow")
    row:SetFullWidth(true)
    root:AddChild(row)

    local previewButton = AddActionButton(row, T("THEME_PREVIEW", "Preview Preset"), "utility", 130)
    local applyButton = nil
    if view.selectedIsBuiltInPreset then
        applyButton = AddActionButton(row, T("THEME_APPLY", T("INFO_GENERAL_THEME_APPLY", "Apply Preset")), "primary_action", 150)
    end
    local createProfileButton = AddActionButton(row, T("PRESET_CREATE_PROFILE", "Create Profile"), "utility", 140)

    context.layoutsPresets = {
        dropdown = dropdown,
        description = description,
        previewButton = previewButton,
        applyButton = applyButton,
        createProfileButton = createProfileButton,
        view = view,
        deps = deps,
        presetContext = presetContext,
    }

    return context.layoutsPresets
end

function LayoutsPresetsController.Refresh(context)
    local block = context and context.layoutsPresets
    if not block then
        return
    end

    local view = PresetUI.BuildPresetViewData
        and PresetUI.BuildPresetViewData(GetEditorPresetState(), block.deps, {
            includeCustom = false,
            descriptionFallback = "",
        })
        or block.view
        or {}

    block.view = view
    if block.dropdown then
        block.dropdown:SetList(view.presetList or {}, view.presetOrder)
        block.dropdown:SetValue(view.selectedPresetId)
        block.dropdown:SetDisabled(next(view.presetList or {}) == nil)
    end
    if block.description then
        block.description:SetText(view.description or "")
    end
    if block.previewButton then
        block.previewButton:SetDisabled(not view.selectedPresetId)
        if ApplyModalActionButtonVisual then
            ApplyModalActionButtonVisual(block.previewButton, "utility")
        end
    end
    if block.applyButton then
        block.applyButton:SetDisabled(not view.selectedIsBuiltInPreset)
        if ApplyModalActionButtonVisual then
            ApplyModalActionButtonVisual(block.applyButton, "primary_action")
        end
    end
    if block.createProfileButton then
        block.createProfileButton:SetDisabled(not view.selectedPreset)
        if ApplyModalActionButtonVisual then
            ApplyModalActionButtonVisual(block.createProfileButton, "utility")
        end
    end
end

function LayoutsPresetsController.Wire(context, rerender)
    local block = context and context.layoutsPresets
    if not block then
        return
    end

    block.dropdown:SetCallback("OnValueChanged", function(_, _, value)
        if PresetUI.SelectPreset then
            PresetUI.SelectPreset(block.presetContext or BuildPresetContext(), value, block.deps, RequestRefreshOptions)
        end
        if type(rerender) == "function" then
            rerender()
        end
    end)

    block.previewButton:SetCallback("OnClick", function()
        local presetContext = block.presetContext or BuildPresetContext()
        local selectedPresetId = presetContext and presetContext.state and presetContext.state.selectedThemeId
        if PresetUI.SelectPreset then
            PresetUI.SelectPreset(presetContext, selectedPresetId, block.deps, RequestRefreshOptions)
        else
            RequestRefreshOptions()
        end
    end)

    if block.applyButton then
        block.applyButton:SetCallback("OnClick", function()
            if PresetUI.ApplyPresetToCurrent then
                PresetUI.ApplyPresetToCurrent(block.presetContext or BuildPresetContext(), block.deps, RequestRefreshOptions, {
                    allowCustomLayout = false,
                })
            end
            if type(rerender) == "function" then
                rerender()
            end
        end)
    end

    block.createProfileButton:SetCallback("OnClick", function()
        if PresetUI.OpenCreateProfileDialog then
            PresetUI.OpenCreateProfileDialog(block.presetContext or BuildPresetContext(), block.deps, function()
                RequestRefreshOptions()
                if type(rerender) == "function" then
                    rerender()
                end
            end)
        end
    end)
end

return LayoutsPresetsController
