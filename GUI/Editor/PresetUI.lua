local _, ns = ...

ns.GUI = ns.GUI or {}
ns.GUI.Editor = ns.GUI.Editor or {}

local PresetUI = {}
ns.GUI.Editor.PresetUI = PresetUI

local BUILT_IN_PRESET_ORDER = {
    "default",
    "classic",
    "minimal",
    "modern",
}

local CUSTOM_PRESET_ID = "__custom__"
local DELETE_DIALOG_WIDTH = 440
local DELETE_DIALOG_HEIGHT = 198
local DELETE_DIALOG_TEXT_WIDTH = 388
local DELETE_DIALOG_INSET_WIDTH = 10
local DELETE_DIALOG_FOOTER_SPACER_WIDTH = 152
local createProfileDialog
local renamePresetDialog
local deletePresetDialog

local function T(key, fallback, deps)
    local L = (deps and deps.L) or ns.L or {}
    return (type(key) == "string" and L[key]) or fallback or ""
end

local function Trim(value)
    if type(value) ~= "string" then
        return ""
    end
    return (value:gsub("^%s+", ""):gsub("%s+$", ""))
end

local function ResolveAddon(deps)
    return (deps and deps.ns) or ns or {}
end

local function CloneValue(value, deps)
    local nsRef = ResolveAddon(deps)
    local LayoutService = nsRef.LayoutService or {}
    if LayoutService.Clone then
        return LayoutService.Clone(value)
    end
    if type(value) ~= "table" then
        return value
    end
    if CopyTable then
        return CopyTable(value)
    end
    local result = {}
    for key, entry in pairs(value) do
        result[key] = CloneValue(entry, deps)
    end
    return result
end

local function RaiseDialogAboveOwner(window, ownerWindow)
    local frame = window and window.frame
    if not frame then
        return
    end

    local ownerFrame = ownerWindow and ownerWindow.frame or ownerWindow
    if ownerFrame and ownerFrame.GetFrameStrata and frame.SetFrameStrata then
        frame:SetFrameStrata(ownerFrame:GetFrameStrata() or "FULLSCREEN_DIALOG")
    elseif frame.SetFrameStrata then
        frame:SetFrameStrata("FULLSCREEN_DIALOG")
    end

    if ownerFrame and ownerFrame.GetFrameLevel and frame.SetFrameLevel then
        frame:SetFrameLevel((ownerFrame:GetFrameLevel() or 1) + 20)
    end
    if frame.Raise then
        frame:Raise()
    end
end

local function SortByNameThenId(a, b)
    local leftName = string.lower(a.name or "")
    local rightName = string.lower(b.name or "")
    if leftName == rightName then
        return tostring(a.id or "") < tostring(b.id or "")
    end
    return leftName < rightName
end

local function FocusEditBox(editBox)
    if not editBox then
        return
    end
    if editBox.SetFocus then
        editBox:SetFocus()
    end
    if editBox.HighlightText then
        editBox:HighlightText()
    end
    local input = editBox.editbox or editBox.editBox
    if input then
        if input.SetFocus then
            input:SetFocus()
        end
        if input.HighlightText then
            input:HighlightText()
        end
    end
end

local function AddFixedSpacer(row, width, aceGui)
    local spacer = aceGui:Create("Label")
    spacer:SetText("")
    spacer:SetWidth(width or 0)
    row:AddChild(spacer)
    return spacer
end

local function AddInsetDialogText(window, widget, width, aceGui)
    local row = aceGui:Create("SimpleGroup")
    row:SetLayout("Flow")
    row:SetFullWidth(true)
    window:AddChild(row)

    AddFixedSpacer(row, DELETE_DIALOG_INSET_WIDTH, aceGui)
    widget:SetWidth(width or DELETE_DIALOG_TEXT_WIDTH)
    row:AddChild(widget)
    return row
end

function PresetUI.ResolvePresetName(preset, deps)
    local metadata = type(preset) == "table" and preset.metadata or nil
    if type(metadata) ~= "table" then
        return ""
    end
    if type(metadata.labelKey) == "string" then
        local label = T(metadata.labelKey, nil, deps)
        if label ~= "" then
            return label
        end
    end
    if type(metadata.name) == "string" and metadata.name ~= "" then
        return metadata.name
    end
    return metadata.id or ""
end

function PresetUI.ResolvePresetDescription(preset, fallback, deps)
    local metadata = type(preset) == "table" and preset.metadata or nil
    if type(metadata) ~= "table" then
        return fallback or ""
    end
    if type(metadata.descriptionKey) == "string" then
        local description = T(metadata.descriptionKey, nil, deps)
        if description ~= "" then
            return description
        end
    end
    if type(metadata.description) == "string" and metadata.description ~= "" then
        return metadata.description
    end
    return fallback or ""
end

function PresetUI.BuildPresetDropdownList(presets, deps, options)
    local list = {}
    local order = {}
    local seen = {}

    local function addPreset(id, preset)
        if type(id) ~= "string" or id == "" or seen[id] or type(preset) ~= "table" then
            return
        end
        local name = PresetUI.ResolvePresetName(preset, deps)
        if name == "" then
            name = id
        end
        list[id] = name
        order[#order + 1] = id
        seen[id] = true
    end

    for _, id in ipairs(BUILT_IN_PRESET_ORDER) do
        addPreset(id, presets and presets[id])
    end

    local extraBuiltIns = {}
    local userPresets = {}
    for id, preset in pairs(presets or {}) do
        if not seen[id] then
            local metadata = type(preset) == "table" and preset.metadata or {}
            local entry = {
                id = id,
                preset = preset,
                name = PresetUI.ResolvePresetName(preset, deps),
            }
            if metadata.source == "user" then
                userPresets[#userPresets + 1] = entry
            else
                extraBuiltIns[#extraBuiltIns + 1] = entry
            end
        end
    end

    table.sort(extraBuiltIns, SortByNameThenId)
    for _, entry in ipairs(extraBuiltIns) do
        addPreset(entry.id, entry.preset)
    end

    table.sort(userPresets, SortByNameThenId)
    for _, entry in ipairs(userPresets) do
        addPreset(entry.id, entry.preset)
    end

    if options and options.includeCustom then
        list[options.customId or CUSTOM_PRESET_ID] = T("THEME_CUSTOM", "My Layout", deps)
        order[#order + 1] = options.customId or CUSTOM_PRESET_ID
    end

    return list, order
end

function PresetUI.GetFirstPresetId(order, list)
    if type(order) == "table" then
        for _, id in ipairs(order) do
            if list and list[id] then
                return id
            end
        end
    end
    for id in pairs(list or {}) do
        return id
    end
    return nil
end

function PresetUI.BuildPresetViewData(state, deps, options)
    options = type(options) == "table" and options or {}

    local nsRef = ResolveAddon(deps)
    local ThemeService = (deps and deps.ThemeService) or nsRef.ThemeService or {}
    local PresetService = (deps and deps.PresetService) or nsRef.PresetService or {}
    local generalConfig = nsRef.db and nsRef.db.profile and nsRef.db.profile.General
    local customThemeId = ThemeService.GetCustomThemeId and ThemeService.GetCustomThemeId() or CUSTOM_PRESET_ID
    local presets = PresetService.ListPresets and PresetService.ListPresets() or {}
    local presetList, presetOrder = PresetUI.BuildPresetDropdownList(presets, deps, {
        includeCustom = options.includeCustom == true,
        customId = customThemeId,
    })
    local activeThemeId = generalConfig and generalConfig.ActiveThemeId
    local selectedPresetId = state and state.selectedThemeId or activeThemeId

    if not presetList[selectedPresetId] then
        selectedPresetId = activeThemeId
    end
    if not presetList[selectedPresetId] then
        selectedPresetId = PresetUI.GetFirstPresetId(presetOrder, presetList)
    end
    if state then
        state.selectedThemeId = selectedPresetId
    end

    local selectedPreset = PresetService.GetPreset and PresetService.GetPreset(selectedPresetId) or nil
    local selectedPresetSource = selectedPreset and selectedPreset.metadata and selectedPreset.metadata.source or nil
    local selectedIsCustomLayout = selectedPresetId == customThemeId
    local selectedIsBuiltInPreset = selectedPresetSource == "builtin"
    local selectedIsUserPreset = selectedPresetSource == "user"
    local description

    if selectedIsCustomLayout then
        description = T("THEME_CUSTOM_DESC", nil, deps)
    elseif selectedPreset then
        description = PresetUI.ResolvePresetDescription(selectedPreset, options.descriptionFallback, deps)
    else
        description = options.descriptionFallback or ""
    end

    return {
        activeThemeId = activeThemeId,
        customThemeId = customThemeId,
        presetList = presetList,
        presetOrder = presetOrder,
        selectedPresetId = selectedPresetId,
        selectedPreset = selectedPreset,
        selectedPresetSource = selectedPresetSource,
        selectedIsBuiltInPreset = selectedIsBuiltInPreset,
        selectedIsUserPreset = selectedIsUserPreset,
        selectedIsCustomLayout = selectedIsCustomLayout,
        description = description or "",
    }
end

function PresetUI.SelectPreset(context, presetId, deps, refreshFn)
    if not context or type(presetId) ~= "string" or presetId == "" then
        return
    end

    if context.state then
        context.state.selectedThemeId = presetId
    end

    local editorState = ns.GUI and ns.GUI.Editor and ns.GUI.Editor.State
    if editorState and editorState.SetSelectedThemeId then
        editorState.SetSelectedThemeId(presetId)
    end

    if context.options and context.options.onThemeChanged then
        context.options.onThemeChanged(presetId)
    elseif refreshFn then
        refreshFn()
    end
end

function PresetUI.PreviewPreset(context, presetId, deps, refreshFn)
    if not context or type(presetId) ~= "string" or presetId == "" then
        return false
    end

    local nsRef = ResolveAddon(deps)
    local ThemeService = (deps and deps.ThemeService) or nsRef.ThemeService or {}
    local PresetService = (deps and deps.PresetService) or nsRef.PresetService or {}
    local preset = PresetService.GetPreset and PresetService.GetPreset(presetId) or nil
    local profile = nsRef.db and nsRef.db.profile or nil
    if type(preset) ~= "table" or type(preset.layout) ~= "table" or type(profile) ~= "table" then
        return false
    end

    if ThemeService.HasRestoreSnapshot
        and ThemeService.CaptureRestoreSnapshot
        and not ThemeService.HasRestoreSnapshot()
    then
        ThemeService.CaptureRestoreSnapshot()
    end

    if type(preset.layout.Units) == "table" then
        profile.Units = CloneValue(preset.layout.Units, deps)
    end
    if type(preset.layout.TextTemplates) == "table" then
        profile.TextTemplates = CloneValue(preset.layout.TextTemplates, deps)
    end
    profile.General = type(profile.General) == "table" and profile.General or {}
    profile.General.ActiveThemeId = presetId

    PresetUI.SelectPreset(context, presetId, deps, nil)
    if nsRef.RefreshAllUnitFrames then
        nsRef:RefreshAllUnitFrames()
    end
    if refreshFn then
        refreshFn()
    end
    return true
end

function PresetUI.ApplyPresetToCurrent(context, deps, refreshFn, options)
    options = type(options) == "table" and options or {}

    local nsRef = ResolveAddon(deps)
    local ThemeService = (deps and deps.ThemeService) or nsRef.ThemeService or {}
    local PresetService = (deps and deps.PresetService) or nsRef.PresetService or {}
    local selectedThemeId = context and context.state and context.state.selectedThemeId
    local customThemeId = ThemeService.GetCustomThemeId and ThemeService.GetCustomThemeId() or CUSTOM_PRESET_ID
    local preset = PresetService.GetPreset and PresetService.GetPreset(selectedThemeId) or nil
    local isBuiltInPreset = preset and preset.metadata and preset.metadata.source == "builtin"
    local isCustomLayout = options.allowCustomLayout == true and selectedThemeId == customThemeId

    if not selectedThemeId or not ThemeService.ApplyTheme then
        return false
    end
    if not isBuiltInPreset and not isCustomLayout then
        return false
    end

    if selectedThemeId ~= customThemeId
        and ThemeService.HasDefaultSnapshot
        and ThemeService.CaptureDefaultSnapshot
        and not ThemeService.HasDefaultSnapshot()
    then
        ThemeService.CaptureDefaultSnapshot()
    end

    if selectedThemeId ~= customThemeId and ThemeService.CaptureRestoreSnapshot then
        ThemeService.CaptureRestoreSnapshot()
    end

    if ThemeService.ApplyTheme(selectedThemeId) then
        local appliedThemeId = nsRef.db and nsRef.db.profile and nsRef.db.profile.General and nsRef.db.profile.General.ActiveThemeId or selectedThemeId
        if context and context.state then
            context.state.selectedThemeId = appliedThemeId
        end
        local editorState = ns.GUI and ns.GUI.Editor and ns.GUI.Editor.State
        if editorState and editorState.SetSelectedThemeId then
            editorState.SetSelectedThemeId(appliedThemeId)
        end
        if context and context.options and context.options.onThemeApplied then
            context.options.onThemeApplied(appliedThemeId)
        elseif refreshFn then
            refreshFn()
        end
        return true
    end

    return false
end

local function ResolveCreateProfileError(errorKey, deps)
    if errorKey == "invalid-profile-name" then
        return T("PROFILE_NAME_REQUIRED", "Please enter a profile name.", deps)
    elseif errorKey == "profile-exists" then
        return T("PROFILE_NAME_EXISTS", "A profile with this name already exists.", deps)
    elseif errorKey == "preset-not-found" then
        return T("PRESET_NOT_AVAILABLE", "Preset is no longer available.", deps)
    elseif errorKey == "combat-blocked" then
        return T("PROFILE_CREATE_COMBAT_BLOCKED", "Create profiles outside combat.", deps)
    end

    return T("PROFILE_CREATE_FAILED", "Profile could not be created.", deps)
end

local function ResolveRenamePresetError(errorKey, deps)
    if errorKey == "invalid-name" then
        return T("PRESET_NAME_REQUIRED", "Please enter a preset name.", deps)
    elseif errorKey == "name-too-long" then
        return T("PRESET_NAME_TOO_LONG", "Preset name is too long.", deps)
    elseif errorKey == "duplicate-name" then
        return T("PRESET_NAME_EXISTS", "A preset with this name already exists.", deps)
    elseif errorKey == "reserved-name" then
        return T("PRESET_NAME_RESERVED", "This name is reserved for a built-in preset.", deps)
    elseif errorKey == "not-found" then
        return T("PRESET_NOT_AVAILABLE", "Preset is no longer available.", deps)
    elseif errorKey == "read-only" then
        return T("PRESET_READ_ONLY", "Built-in presets cannot be changed.", deps)
    end

    return T("PRESET_RENAME_FAILED", "Preset could not be renamed.", deps)
end

local function ResolveDeletePresetError(errorKey, deps)
    if errorKey == "not-found" then
        return T("PRESET_NOT_AVAILABLE", "Preset is no longer available.", deps)
    elseif errorKey == "read-only" then
        return T("PRESET_READ_ONLY", "Built-in presets cannot be changed.", deps)
    end

    return T("PRESET_DELETE_FAILED", "Preset could not be deleted.", deps)
end

local function RefreshAfterPresetMutation(context, deps, refreshFn)
    local view = PresetUI.BuildPresetViewData and PresetUI.BuildPresetViewData(context and context.state, deps, {
        includeCustom = false,
        descriptionFallback = "",
    }) or nil
    local selectedPresetId = view and view.selectedPresetId
    if selectedPresetId and context and context.state then
        PresetUI.SelectPreset(context, selectedPresetId, deps, refreshFn)
        return
    end
    if refreshFn then
        refreshFn()
    end
end

function PresetUI.OpenRenamePresetDialog(context, deps, refreshFn)
    local AceGUI = deps and deps.AceGUI
    local PresetService = (deps and deps.PresetService) or {}
    local PresetMutations = (deps and deps.PresetMutations) or ns.PresetMutations or {}
    local CreateBodyText = deps and deps.CreateBodyText
    local CreateActionButton = deps and deps.CreateActionButton
    local StyleEditBox = deps and deps.StyleEditBox
    local ApplyWindowChrome = deps and deps.ApplyWindowChrome
    local EnsureStandardWindowCloseButton = deps and deps.EnsureStandardWindowCloseButton
    if not AceGUI or not PresetMutations.RenameUserPreset then
        return
    end

    local presetId = context and context.state and context.state.selectedThemeId
    local preset = PresetService.GetPreset and PresetService.GetPreset(presetId) or nil
    if type(preset) ~= "table" or not (preset.metadata and preset.metadata.source == "user") then
        return
    end

    if renamePresetDialog and renamePresetDialog.window and renamePresetDialog.window.Hide then
        renamePresetDialog.window:Hide()
    end

    local presetName = PresetUI.ResolvePresetName(preset, deps)
    local window = AceGUI:Create("Window")
    window:SetTitle(T("PRESET_RENAME_TITLE", "Rename Preset", deps))
    window:SetLayout("List")
    window:SetWidth(420)
    window:SetHeight(190)
    window:EnableResize(false)
    if window.frame then
        window.frame:SetClampedToScreen(true)
        window.frame:SetFrameStrata("FULLSCREEN_DIALOG")
    end
    RaiseDialogAboveOwner(window, context and context.ownerWindow)
    if ApplyWindowChrome then
        ApplyWindowChrome(window)
    end
    if EnsureStandardWindowCloseButton then
        EnsureStandardWindowCloseButton(window)
    end

    local nameEdit = AceGUI:Create("EditBox")
    nameEdit:SetLabel(T("PRESET_NAME", "Preset Name", deps))
    nameEdit:SetFullWidth(true)
    nameEdit:SetText(presetName)
    if StyleEditBox then
        StyleEditBox(nameEdit, "editor_inset")
    end
    window:AddChild(nameEdit)

    local statusText = CreateBodyText
        and CreateBodyText("", "description", 11, nil, nil, true)
        or AceGUI:Create("Label")
    statusText:SetFullWidth(true)
    statusText:SetText(" ")
    window:AddChild(statusText)

    local row = AceGUI:Create("SimpleGroup")
    row:SetLayout("Flow")
    row:SetFullWidth(true)
    window:AddChild(row)

    local renameButton = CreateActionButton
        and CreateActionButton(T("PRESET_RENAME", "Rename", deps), "primary_action", 120, false)
        or AceGUI:Create("Button")
    renameButton:SetText(T("PRESET_RENAME", "Rename", deps))
    renameButton:SetWidth(120)
    row:AddChild(renameButton)

    local cancelButton = CreateActionButton
        and CreateActionButton(T("INFO_COMMON_CANCEL", "Cancel", deps), "utility", 110, false)
        or AceGUI:Create("Button")
    cancelButton:SetText(T("INFO_COMMON_CANCEL", "Cancel", deps))
    cancelButton:SetWidth(110)
    row:AddChild(cancelButton)

    local function setStatus(message)
        statusText:SetText(message and message ~= "" and message or " ")
        if window.DoLayout then
            window:DoLayout()
        end
    end

    local function updateButton()
        renameButton:SetDisabled(Trim(nameEdit:GetText()) == "")
    end

    local function confirm()
        local ok, presetOrError = PresetMutations.RenameUserPreset(presetId, nameEdit:GetText())
        if ok then
            if context and context.state then
                context.state.selectedThemeId = presetId
            end
            if window.Hide then
                window:Hide()
            end
            RefreshAfterPresetMutation(context, deps, refreshFn)
            return
        end
        setStatus(ResolveRenamePresetError(presetOrError, deps))
        updateButton()
    end

    nameEdit:SetCallback("OnTextChanged", function()
        setStatus("")
        updateButton()
    end)
    nameEdit:SetCallback("OnEnterPressed", function()
        if Trim(nameEdit:GetText()) ~= "" then
            confirm()
        end
    end)
    renameButton:SetCallback("OnClick", confirm)
    cancelButton:SetCallback("OnClick", function()
        if window.Hide then
            window:Hide()
        end
    end)
    window:SetCallback("OnClose", function()
        renamePresetDialog = nil
    end)

    renamePresetDialog = {
        window = window,
        presetId = presetId,
    }
    updateButton()
    if window.Show then
        window:Show()
    end
    FocusEditBox(nameEdit)
end

function PresetUI.OpenDeletePresetDialog(context, deps, refreshFn)
    local AceGUI = deps and deps.AceGUI
    local PresetService = (deps and deps.PresetService) or {}
    local PresetMutations = (deps and deps.PresetMutations) or ns.PresetMutations or {}
    local CreateBodyText = deps and deps.CreateBodyText
    local CreateActionButton = deps and deps.CreateActionButton
    local ApplyWindowChrome = deps and deps.ApplyWindowChrome
    local EnsureStandardWindowCloseButton = deps and deps.EnsureStandardWindowCloseButton
    if not AceGUI or not PresetMutations.DeleteUserPreset then
        return
    end

    local presetId = context and context.state and context.state.selectedThemeId
    local preset = PresetService.GetPreset and PresetService.GetPreset(presetId) or nil
    if type(preset) ~= "table" or not (preset.metadata and preset.metadata.source == "user") then
        return
    end

    if deletePresetDialog and deletePresetDialog.window and deletePresetDialog.window.Hide then
        deletePresetDialog.window:Hide()
    end

    local presetName = PresetUI.ResolvePresetName(preset, deps)
    local window = AceGUI:Create("Window")
    window:SetTitle(T("PRESET_DELETE_TITLE", "Delete Preset", deps))
    window:SetLayout("List")
    window:SetWidth(DELETE_DIALOG_WIDTH)
    window:SetHeight(DELETE_DIALOG_HEIGHT)
    window:EnableResize(false)
    if window.frame then
        window.frame:SetClampedToScreen(true)
        window.frame:SetFrameStrata("FULLSCREEN_DIALOG")
    end
    RaiseDialogAboveOwner(window, context and context.ownerWindow)
    if ApplyWindowChrome then
        ApplyWindowChrome(window)
    end
    if EnsureStandardWindowCloseButton then
        EnsureStandardWindowCloseButton(window)
    end

    local prompt = string.format(T("PRESET_DELETE_CONFIRM_PROMPT", "Delete preset \"%s\"?\nProfiles created from it remain unchanged.", deps), presetName)
    local message = CreateBodyText
        and CreateBodyText(prompt, "description", 12, nil, DELETE_DIALOG_TEXT_WIDTH, false)
        or AceGUI:Create("Label")
    message:SetText(prompt)
    AddInsetDialogText(window, message, DELETE_DIALOG_TEXT_WIDTH, AceGUI)

    local statusText = CreateBodyText
        and CreateBodyText("", "description", 11, nil, DELETE_DIALOG_TEXT_WIDTH, false)
        or AceGUI:Create("Label")
    statusText:SetText(" ")
    AddInsetDialogText(window, statusText, DELETE_DIALOG_TEXT_WIDTH, AceGUI)

    local row = AceGUI:Create("SimpleGroup")
    row:SetLayout("Flow")
    row:SetFullWidth(true)
    window:AddChild(row)

    local deleteButton = CreateActionButton
        and CreateActionButton(T("PRESET_DELETE", "Delete", deps), "danger", 120, false)
        or AceGUI:Create("Button")
    deleteButton:SetText(T("PRESET_DELETE", "Delete", deps))
    deleteButton:SetWidth(120)
    row:AddChild(deleteButton)
    AddFixedSpacer(row, DELETE_DIALOG_FOOTER_SPACER_WIDTH, AceGUI)

    local cancelButton = CreateActionButton
        and CreateActionButton(T("INFO_COMMON_CANCEL", "Cancel", deps), "utility", 110, false)
        or AceGUI:Create("Button")
    cancelButton:SetText(T("INFO_COMMON_CANCEL", "Cancel", deps))
    cancelButton:SetWidth(110)
    row:AddChild(cancelButton)

    local function setStatus(messageText)
        statusText:SetText(messageText and messageText ~= "" and messageText or " ")
        if window.DoLayout then
            window:DoLayout()
        end
    end

    deleteButton:SetCallback("OnClick", function()
        local ok, errorKey = PresetMutations.DeleteUserPreset(presetId)
        if ok then
            if context and context.state and context.state.selectedThemeId == presetId then
                context.state.selectedThemeId = nil
            end
            if window.Hide then
                window:Hide()
            end
            RefreshAfterPresetMutation(context, deps, refreshFn)
            return
        end
        setStatus(ResolveDeletePresetError(errorKey, deps))
    end)
    cancelButton:SetCallback("OnClick", function()
        if window.Hide then
            window:Hide()
        end
    end)
    window:SetCallback("OnClose", function()
        deletePresetDialog = nil
    end)

    deletePresetDialog = {
        window = window,
        presetId = presetId,
    }
    if window.Show then
        window:Show()
    end
end

function PresetUI.OpenCreateProfileDialog(context, deps, refreshFn)
    local AceGUI = deps and deps.AceGUI
    local ProfileLayoutService = (deps and deps.ProfileLayoutService) or {}
    local PresetService = (deps and deps.PresetService) or {}
    local CreateBodyText = deps and deps.CreateBodyText
    local CreateActionButton = deps and deps.CreateActionButton
    local StyleEditBox = deps and deps.StyleEditBox
    local ApplyWindowChrome = deps and deps.ApplyWindowChrome
    local EnsureStandardWindowCloseButton = deps and deps.EnsureStandardWindowCloseButton
    if not AceGUI or not ProfileLayoutService.CreateProfileFromPreset then
        return
    end

    local presetId = context and context.state and context.state.selectedThemeId
    local preset = PresetService.GetPreset and PresetService.GetPreset(presetId) or nil
    if type(preset) ~= "table" then
        return
    end

    if createProfileDialog and createProfileDialog.window and createProfileDialog.window.Hide then
        createProfileDialog.window:Hide()
    end

    local presetName = PresetUI.ResolvePresetName(preset, deps)
    local window = AceGUI:Create("Window")
    window:SetTitle(T("PRESET_CREATE_PROFILE_TITLE", "Create Profile from Preset", deps))
    window:SetLayout("List")
    window:SetWidth(420)
    window:SetHeight(190)
    window:EnableResize(false)
    if window.frame then
        window.frame:SetClampedToScreen(true)
        window.frame:SetFrameStrata("FULLSCREEN_DIALOG")
    end
    RaiseDialogAboveOwner(window, context and context.ownerWindow)
    if ApplyWindowChrome then
        ApplyWindowChrome(window)
    end
    if EnsureStandardWindowCloseButton then
        EnsureStandardWindowCloseButton(window)
    end

    local hint = CreateBodyText
        and CreateBodyText(presetName, "description", 12, nil, nil, true)
        or AceGUI:Create("Label")
    hint:SetFullWidth(true)
    hint:SetText(presetName)
    window:AddChild(hint)

    local nameEdit = AceGUI:Create("EditBox")
    nameEdit:SetLabel(T("PROFILE_NAME", "Profile Name", deps))
    nameEdit:SetFullWidth(true)
    nameEdit:SetText(presetName)
    if StyleEditBox then
        StyleEditBox(nameEdit, "editor_inset")
    end
    window:AddChild(nameEdit)

    local statusText = CreateBodyText
        and CreateBodyText("", "description", 11, nil, nil, true)
        or AceGUI:Create("Label")
    statusText:SetFullWidth(true)
    statusText:SetText(" ")
    window:AddChild(statusText)

    local row = AceGUI:Create("SimpleGroup")
    row:SetLayout("Flow")
    row:SetFullWidth(true)
    window:AddChild(row)

    local createButton = CreateActionButton
        and CreateActionButton(T("PRESET_CREATE_PROFILE", "Create Profile", deps), "primary_action", 150, false)
        or AceGUI:Create("Button")
    createButton:SetText(T("PRESET_CREATE_PROFILE", "Create Profile", deps))
    createButton:SetWidth(150)
    row:AddChild(createButton)

    local cancelButton = CreateActionButton
        and CreateActionButton(T("INFO_COMMON_CANCEL", "Cancel", deps), "utility", 110, false)
        or AceGUI:Create("Button")
    cancelButton:SetText(T("INFO_COMMON_CANCEL", "Cancel", deps))
    cancelButton:SetWidth(110)
    row:AddChild(cancelButton)

    local function setStatus(message)
        statusText:SetText(message and message ~= "" and message or " ")
        if window.DoLayout then
            window:DoLayout()
        end
    end

    local function updateCreateButton()
        createButton:SetDisabled(Trim(nameEdit:GetText()) == "")
    end

    local function confirm()
        local ok, resultOrError = ProfileLayoutService.CreateProfileFromPreset(presetId, nameEdit:GetText(), {
            reason = "preset-ui-create-profile-from-preset",
        })
        if ok then
            if context and context.state then
                context.state.selectedThemeId = presetId
            end
            local editorState = ns.GUI and ns.GUI.Editor and ns.GUI.Editor.State
            if editorState and editorState.SetSelectedThemeId then
                editorState.SetSelectedThemeId(presetId)
            end
            if window.Hide then
                window:Hide()
            end
            if context and context.options and context.options.onProfileCreated then
                context.options.onProfileCreated(resultOrError)
            elseif context and context.options and context.options.onGlobalChanged then
                context.options.onGlobalChanged()
            elseif refreshFn then
                refreshFn()
            end
            return
        end
        setStatus(ResolveCreateProfileError(resultOrError, deps))
        updateCreateButton()
    end

    nameEdit:SetCallback("OnTextChanged", function()
        setStatus("")
        updateCreateButton()
    end)
    nameEdit:SetCallback("OnEnterPressed", function()
        if Trim(nameEdit:GetText()) ~= "" then
            confirm()
        end
    end)
    createButton:SetCallback("OnClick", confirm)
    cancelButton:SetCallback("OnClick", function()
        if window.Hide then
            window:Hide()
        end
    end)
    window:SetCallback("OnClose", function()
        createProfileDialog = nil
    end)

    if window.frame and window.frame.SetScript then
        window.frame:EnableKeyboard(true)
        if window.frame.SetPropagateKeyboardInput then
            window.frame:SetPropagateKeyboardInput(true)
        end
        window.frame:SetScript("OnKeyDown", function(_, key)
            if key == "ESCAPE" and window.Hide then
                window:Hide()
            end
        end)
    end

    createProfileDialog = {
        window = window,
        presetId = presetId,
    }
    updateCreateButton()
    if window.Show then
        window:Show()
    end
    FocusEditBox(nameEdit)
end

return PresetUI
