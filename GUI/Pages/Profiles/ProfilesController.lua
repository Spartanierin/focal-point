local _, ns = ...

ns.GUI = ns.GUI or {}
ns.GUI.Pages = ns.GUI.Pages or {}

local AceGUI = LibStub("AceGUI-3.0")
local C = ns.Constants
local L = ns.L
local FormWidgets = ns.GUI.Helpers and ns.GUI.Helpers.FormWidgets
local FormRenderer = ns.GUI.Helpers and ns.GUI.Helpers.FormRenderer
local ProfilesLayouts = ns.GUI.Layouts and ns.GUI.Layouts.Profile or {}
local ProfilesDefinition = ProfilesLayouts.Form

local ProfilesController = {}
ns.GUI.Pages.Profiles = ProfilesController

local fallbackRootState = {}
local windowContext
local exportDialogContext
local importDialogContext
local overwriteDialogContext
local savePresetDialogContext
local profileWindowHiddenForTransfer = false

local CreateBodyText = FormWidgets.CreateBodyText
local StyleDropdown = FormWidgets.StyleDropdown
local StyleEditBox = FormWidgets.StyleEditBox
local ApplyWindowChrome = FormWidgets.ApplyWindowChrome
local EnsureStandardWindowCloseButton = FormWidgets.EnsureStandardWindowCloseButton
local CreateActionButton = FormWidgets.CreateActionButton
local ApplyModalActionButtonVisual = FormWidgets.ApplyModalActionButtonVisual
local ResolveItemColor = FormWidgets.ResolveItemColor
local StyleCheckBox = FormWidgets.StyleCheckBox
local RefreshWindowState
local GetProfileList

local UNASSIGNED_PROFILE_VALUE = "__fp_profile_automation_unassigned__"
local DEFAULT_LAYOUTS_SUBPAGE = "profiles"

local VALID_LAYOUTS_SUBPAGES = {
    profiles = true,
    presets = true,
    automation = true,
}

local LAYOUTS_SHELL_SECTIONS = {
    Root = true,
    Header = true,
    Subnav = true,
    ContentHost = true,
}

local LAYOUTS_PROFILE_SECTIONS = {
    ActiveProfile = true,
    ColumnContainer = true,
    LeftColumn = true,
    RightColumn = true,
    BottomBlock = true,
    ActionRow = true,
    BottomHint = true,
}

local function NormalizeLayoutsSubpage(value)
    if VALID_LAYOUTS_SUBPAGES[value] then
        return value
    end
    return DEFAULT_LAYOUTS_SUBPAGE
end

local function T(key, fallback)
    return (L and L[key]) or fallback or ""
end

local function Trim(value)
    if type(value) ~= "string" then
        return ""
    end

    return (value:gsub("^%s+", ""):gsub("%s+$", ""))
end

local function GetProfilesState(deps)
    local rootState = (deps and deps.GetGUIState and deps.GetGUIState()) or fallbackRootState
    rootState.profiles = rootState.profiles or {}
    rootState.layouts = rootState.layouts or {}

    local state = rootState.profiles
    state.layouts = rootState.layouts
    local activeSubpage = NormalizeLayoutsSubpage(state.layouts.activeSubpage)
    if state.layouts.activeSubpage ~= activeSubpage then
        state.layouts.activeSubpage = activeSubpage
    end
    local db = ns.db

    if state.selectedProfile == nil and db and db.GetCurrentProfile then
        state.selectedProfile = db:GetCurrentProfile()
    end

    if state.newProfileName == nil then
        state.newProfileName = ""
    end

    return state
end

local function SetStatus(message)
    if ns.GUI and ns.GUI.SetStatusText then
        ns.GUI:SetStatusText(message)
    end
end

local function SelectPresetInToolbar(presetId)
    if type(presetId) ~= "string" or presetId == "" then
        return
    end

    local editorState = ns.GUI and ns.GUI.Editor and ns.GUI.Editor.State
    if editorState and editorState.SetSelectedThemeId then
        editorState.SetSelectedThemeId(presetId)
    end
end

local function ResolveSavePresetError(errorCode)
    if errorCode == "invalid-name" then
        return T("PRESET_NAME_REQUIRED", "Please enter a preset name.")
    elseif errorCode == "duplicate-name" then
        return T("PRESET_NAME_EXISTS", "A preset with this name already exists.")
    elseif errorCode == "store-unavailable" then
        return T("PRESET_STORAGE_UNAVAILABLE", "Preset storage is unavailable.")
    end

    return T("PRESET_CREATE_FAILED", "Preset could not be created.")
end

local function RefreshProfileUI()
    if ns.GUI and ns.GUI.RequestRefreshOptions then
        ns.GUI:RequestRefreshOptions()
    end
end

local function SyncActiveProfile(reason)
    if ns.HandleActiveProfileChanged then
        ns:HandleActiveProfileChanged(reason or "profiles-ui-sync")
    elseif ns.RebuildFramesForActiveProfile then
        ns:RebuildFramesForActiveProfile()
    end
end

local function SetProfileAndLetCallbackSync(db, profileName, reason, options)
    if ns.ActivateProfile then
        ns:ActivateProfile(profileName, reason, options)
        return
    end

    local previousProfileName = db and db.GetCurrentProfile and db:GetCurrentProfile() or nil
    db:SetProfile(profileName)

    -- AceDB fires OnProfileChanged for real profile switches. If the requested
    -- profile is already active, run the same central sync path explicitly.
    if previousProfileName == profileName then
        SyncActiveProfile(reason)
    end
end

local function GetProfileAutomation()
    return ns.ProfileAutomation
end

local function BuildAutomationDropdownList(profileList)
    local dropdownList = {
        [UNASSIGNED_PROFILE_VALUE] = T("INFO_PROFILE_AUTOMATION_UNASSIGNED", "Unassigned"),
    }
    for profileName in pairs(profileList or {}) do
        dropdownList[profileName] = profileName
    end
    return dropdownList
end

local function ResolveAutomationRowData(automation, spec, profileList)
    local specID = spec and spec.id
    local assignedProfile = automation and automation.GetAssignedProfile and automation.GetAssignedProfile(specID) or nil
    local assignedExists = type(assignedProfile) == "string" and assignedProfile ~= "" and profileList and profileList[assignedProfile] ~= nil
    local statusText = ""

    if assignedProfile and not assignedExists then
        statusText = string.format(T("INFO_PROFILE_AUTOMATION_MISSING_PROFILE", "Missing profile: %s"), assignedProfile)
    end

    return {
        spec = spec,
        assignedProfile = assignedProfile,
        assignedExists = assignedExists,
        value = assignedExists and assignedProfile or UNASSIGNED_PROFILE_VALUE,
        statusText = statusText,
    }
end

local function BuildAutomationViewData(profileList)
    local automation = GetProfileAutomation()
    if not automation then
        return nil
    end

    local data = {
        enabled = automation.IsEnabled and automation.IsEnabled() == true,
        dropdownList = BuildAutomationDropdownList(profileList),
        rows = {},
    }

    local specs = automation.GetAvailableSpecs and automation.GetAvailableSpecs() or {}
    for _, spec in ipairs(specs) do
        data.rows[#data.rows + 1] = ResolveAutomationRowData(automation, spec, profileList)
    end

    return data
end

local function CreateProfileAutomationBlock(root, automationData)
    local automation = GetProfileAutomation()
    if not root or not automation then
        return nil
    end
    automationData = automationData or BuildAutomationViewData({})

    local title = CreateBodyText(
        T("INFO_PROFILE_AUTOMATION_TITLE", "Automatic Profile Switching"),
        "sectionHeader",
        13,
        nil,
        nil,
        true
    )
    root:AddChild(title)

    local enabled = AceGUI:Create("CheckBox")
    enabled:SetFullWidth(true)
    enabled:SetLabel(T("INFO_PROFILE_AUTOMATION_ENABLE", "Switch profiles automatically by specialization"))
    enabled:SetValue(automationData.enabled)
    if StyleCheckBox then
        StyleCheckBox(enabled, false)
    end
    root:AddChild(enabled)

    local hint = CreateBodyText(
        T("INFO_PROFILE_AUTOMATION_HINT", "Unassigned keeps the current profile."),
        "muted",
        11,
        nil,
        nil,
        true
    )
    root:AddChild(hint)

    local rows = {}
    local tableGroup
    if #(automationData.rows or {}) > 0 then
        tableGroup = AceGUI:Create("SimpleGroup")
        tableGroup:SetFullWidth(true)
        tableGroup:SetLayout("Table")
        tableGroup:SetUserData("table", {
            columns = {
                { width = 170 },
                { width = 280 },
                { weight = 1 },
            },
            spaceH = 12,
            spaceV = 0,
            align = "TOPLEFT",
            alignV = "start",
            alignH = "start",
        })
    end

    for _, rowData in ipairs(automationData.rows or {}) do
        local spec = rowData.spec

        local label = CreateBodyText(spec.name or tostring(spec.id), "label", 12, nil, nil, true)
        tableGroup:AddChild(label)

        local dropdown = AceGUI:Create("Dropdown")
        dropdown:SetFullWidth(true)
        dropdown:SetLabel("")
        dropdown:SetList(automationData.dropdownList)
        dropdown:SetDisabled(not automationData.enabled)
        dropdown:SetValue(rowData.value)
        StyleDropdown(dropdown, "accented")
        tableGroup:AddChild(dropdown)

        local stateLabel = CreateBodyText(rowData.statusText, "muted", 11, nil, nil, true)
        tableGroup:AddChild(stateLabel)

        rows[#rows + 1] = {
            spec = spec,
            dropdown = dropdown,
            stateLabel = stateLabel,
        }
    end

    if #rows == 0 then
        root:AddChild(CreateBodyText(T("INFO_PROFILE_AUTOMATION_NO_SPECS", "No specializations are available yet."), "muted", 11, nil, nil, true))
    elseif tableGroup then
        root:AddChild(tableGroup)
    end

    return {
        group = tableGroup,
        enabled = enabled,
        rows = rows,
    }
end

local function BuildLayoutsDefinition(includeSections, options)
    options = options or {}
    local result = {}
    for _, definition in ipairs(ProfilesDefinition or {}) do
        if includeSections[definition.section] then
            local entry = options.clone and FormRenderer.CloneLayoutValue(definition) or definition
            if options.detachContentHost
                and entry
                and entry.properties
                and entry.properties.parentSection == "ContentHost"
            then
                entry.properties.parentSection = nil
            end
            result[#result + 1] = entry
        end
    end
    return result
end

local function BuildLayoutsShellDefinition()
    return BuildLayoutsDefinition(LAYOUTS_SHELL_SECTIONS)
end

local function BuildProfilesContentDefinition()
    return BuildLayoutsDefinition(LAYOUTS_PROFILE_SECTIONS, {
        clone = true,
        detachContentHost = true,
    })
end

local function ApplyLayoutsTabButton(button, label, active)
    if not button then
        return
    end

    button:SetText(label or "")
    button:SetDisabled(false)
    if ApplyModalActionButtonVisual then
        ApplyModalActionButtonVisual(button, active and "primary_action" or "secondary")
    elseif FormWidgets and FormWidgets.StyleActionButton then
        FormWidgets.StyleActionButton(button, active and "primary" or "secondary")
    end
end

local function RefreshLayoutsSubnav(context)
    local activeSubpage = NormalizeLayoutsSubpage(context and context.state and context.state.layouts and context.state.layouts.activeSubpage)
    ApplyLayoutsTabButton(context and context.profilesTabButton, T("LAYOUTS_PROFILES", "Profiles"), activeSubpage == "profiles")
    ApplyLayoutsTabButton(context and context.presetsTabButton, T("LAYOUTS_PRESETS", "Presets"), activeSubpage == "presets")
    ApplyLayoutsTabButton(context and context.automationTabButton, T("LAYOUTS_AUTOMATION", "Automation"), activeSubpage == "automation")
end

local function CreatePresetsPlaceholderBlock(root)
    if not root then
        return nil
    end

    local group = AceGUI:Create("InlineGroup")
    group:SetTitle(T("LAYOUTS_PRESETS", "Presets"))
    group:SetFullWidth(true)
    group:SetLayout("Flow")
    root:AddChild(group)

    group:AddChild(CreateBodyText(
        T("LAYOUTS_PRESETS_PLACEHOLDER", "Preset tools are currently available in the Editor toolbar."),
        "muted",
        12,
        nil,
        680,
        true
    ))

    return group
end

local function RefreshProfileAutomationBlock(context, profileList)
    local automation = GetProfileAutomation()
    local block = context and context.profileAutomation
    if not automation or not block then
        return
    end

    local data = BuildAutomationViewData(profileList)
    if not data then
        return
    end

    context.suspendAutomationCallbacks = true
    block.enabled:SetValue(data.enabled)

    local rowsBySpecID = {}
    for _, rowData in ipairs(data.rows or {}) do
        if rowData.spec and rowData.spec.id then
            rowsBySpecID[rowData.spec.id] = rowData
        end
    end
    for _, row in ipairs(block.rows or {}) do
        local specID = row.spec and row.spec.id
        local rowData = rowsBySpecID[specID]

        row.dropdown:SetList(data.dropdownList)
        row.dropdown:SetDisabled(not data.enabled)
        row.dropdown:SetValue(rowData and rowData.value or UNASSIGNED_PROFILE_VALUE)
        row.stateLabel:SetText(rowData and rowData.statusText or "")
    end
    context.suspendAutomationCallbacks = false
end

local function WireProfileAutomationBlock(context)
    local automation = GetProfileAutomation()
    local block = context and context.profileAutomation
    if not automation or not block then
        return
    end

    block.enabled:SetCallback("OnValueChanged", function(_, _, value)
        if context.suspendAutomationCallbacks then
            return
        end
        if automation.SetEnabled then
            automation.SetEnabled(value == true)
        end
        if value == true and automation.Apply then
            automation.Apply("profile-automation-ui-enabled")
        end
        RefreshProfileUI()
        RefreshWindowState()
    end)

    for _, row in ipairs(block.rows or {}) do
        row.dropdown:SetCallback("OnValueChanged", function(_, _, value)
            if context.suspendAutomationCallbacks then
                return
            end
            if automation.SetAssignedProfile then
                automation.SetAssignedProfile(row.spec and row.spec.id, value ~= UNASSIGNED_PROFILE_VALUE and value or nil)
            end
            if automation.IsEnabled and automation.IsEnabled() and automation.Apply then
                automation.Apply("profile-automation-ui-mapping")
            end
            RefreshProfileUI()
            RefreshWindowState()
        end)
    end
end

function GetProfileList(db)
    local list = {}
    if not db or not db.GetProfiles then
        return list
    end

    local profiles = db:GetProfiles({})
    for _, profileName in ipairs(profiles or {}) do
        list[profileName] = profileName
    end

    return list
end

local function CenterWindow(window)
    local frame = window and window.frame
    if not frame then
        return
    end

    frame:ClearAllPoints()
    frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
end

local function FocusWindow(window)
    local frame = window and window.frame
    if not frame then
        return
    end

    if frame.IsShown and not frame:IsShown() then
        CenterWindow(window)
    end

    if window.Show then
        window:Show()
    elseif frame.Show then
        frame:Show()
    end

    frame:SetFrameStrata("FULLSCREEN_DIALOG")
    frame:SetToplevel(true)
    if frame.Raise then
        frame:Raise()
    end
end

local function HideProfileWindowForTransfer()
    if not windowContext or not windowContext.window or not windowContext.window.Hide then
        return
    end

    profileWindowHiddenForTransfer = true
    windowContext.window:Hide()
end

local function RestoreProfileWindowAfterTransfer()
    if not profileWindowHiddenForTransfer then
        return
    end

    profileWindowHiddenForTransfer = false
    if not windowContext or not windowContext.window then
        return
    end

    RefreshWindowState()
    FocusWindow(windowContext.window)
end

local function FocusTransferEditBox(editBox)
    if not editBox then
        return
    end

    if editBox.SetFocus then
        editBox:SetFocus()
    end
    if editBox.HighlightText then
        editBox:HighlightText()
    end

    local input = editBox.editBox or editBox.editbox
    if input then
        if input.SetFocus then
            input:SetFocus()
        end
        if input.HighlightText then
            input:HighlightText()
        end
    end
end

local function QueueFocusTransferEditBox(editBox)
    if C_Timer and C_Timer.After then
        C_Timer.After(0, function()
            FocusTransferEditBox(editBox)
        end)
        return
    end

    FocusTransferEditBox(editBox)
end

local CreateItemWidget

local function CreateTransferItemWidget(group, item, props, state)
    if not props or not props.widget then
        return nil
    end

    if props.widget == "multilineeditbox" then
        local editBox = AceGUI:Create("MultiLineEditBox")
        editBox:SetLabel(props.hideLabel and "" or T(props.labelKey))
        if props.fullWidth ~= false then
            editBox:SetFullWidth(true)
        end
        editBox:SetNumLines(props.numLines or 8)
        if props.disableButton ~= false then
            editBox:DisableButton(true)
        end
        editBox:SetText(props.stateKey and state and state[props.stateKey] or props.text or "")
        StyleEditBox(editBox, props.fieldVariant or "editor_inset")
        return editBox
    end

    return CreateItemWidget(group, item, props, state)
end

local function ApplyLayoutDialogState(context, state)
    if not context or type(state) ~= "table" then
        return
    end

    if context.editBox and state.transferText ~= nil then
        context.editBox:SetText(state.transferText or "")
    end
    if context.profileNameEdit and state.profileName ~= nil then
        context.profileNameEdit:SetText(state.profileName or "")
    end
    if context.statusText and state.statusText ~= nil then
        context.statusText:SetText(state.statusText or "")
    end
    if context.widgets and context.widgets.message and state.message ~= nil then
        context.widgets.message:SetText(state.message or "")
    end
end

local function WireLayoutDialogActions(context, options)
    if not context then
        return
    end

    options = options or {}
    if ApplyModalActionButtonVisual then
        local buttonRoles = options.buttonRoles or {}
        if context.selectAllButton then
            ApplyModalActionButtonVisual(context.selectAllButton, buttonRoles.selectAllButton or "utility")
        end
        if context.okButton then
            ApplyModalActionButtonVisual(context.okButton, buttonRoles.okButton or "primary_action")
        end
        if context.overwriteButton then
            ApplyModalActionButtonVisual(context.overwriteButton, buttonRoles.overwriteButton or "danger")
        end
        if context.cancelButton then
            ApplyModalActionButtonVisual(context.cancelButton, buttonRoles.cancelButton or "utility")
        end
    end

    if context.selectAllButton then
        context.selectAllButton:SetCallback("OnClick", function()
            FocusTransferEditBox(context.editBox)
        end)
    end

    if context.okButton then
        context.okButton:SetCallback("OnClick", function()
            local shouldClose = true
            if type(options.onOk) == "function" then
                local importString = context.editBox and context.editBox:GetText() or ""
                local profileName = context.profileNameEdit and context.profileNameEdit:GetText() or nil
                shouldClose = options.onOk(importString, profileName) ~= false
            end
            if shouldClose and context.window and context.window.Hide then
                context.window:Hide()
            end
        end)
    end

    if context.cancelButton then
        context.cancelButton:SetCallback("OnClick", function()
            if context.window and context.window.Hide then
                context.window:Hide()
            end
        end)
    end
end

local function OpenLayoutDialog(existingContext, layoutDefinition, options)
    options = options or {}

    if existingContext and existingContext.window and existingContext.window.frame then
        existingContext.window:SetTitle(options.title or "")
        existingContext.window:SetWidth(options.windowWidth or 620)
        existingContext.window:SetHeight(options.windowHeight or 410)
        existingContext.window:SetCallback("OnClose", options.restoreProfileOnClose and RestoreProfileWindowAfterTransfer or nil)
        ApplyLayoutDialogState(existingContext, options.state)
        WireLayoutDialogActions(existingContext, options)
        FocusWindow(existingContext.window)
        if options.autoSelectText then
            QueueFocusTransferEditBox(existingContext.editBox)
        end
        return existingContext
    end

    local window = AceGUI:Create("Window")
    window:SetTitle(options.title or "")
    window:SetLayout("Fill")
    window:SetWidth(options.windowWidth or 620)
    window:SetHeight(options.windowHeight or 410)
    window:EnableResize(false)

    if window.frame then
        window.frame:SetClampedToScreen(true)
    end
    window:SetCallback("OnClose", options.restoreProfileOnClose and RestoreProfileWindowAfterTransfer or nil)

    ApplyWindowChrome(window)
    if EnsureStandardWindowCloseButton then
        EnsureStandardWindowCloseButton(window)
    end
    CenterWindow(window)

    local groups, widgets = FormRenderer.BuildLayout(window, layoutDefinition, {
        state = options.state or {},
        createItemWidget = options.createItemWidget or CreateTransferItemWidget,
    })

    local context = {
        window = window,
        groups = groups,
        widgets = widgets,
        editBox = widgets.transferText,
        profileNameEdit = widgets.profileNameEdit,
        statusText = widgets.statusText,
        okButton = widgets.okButton,
        selectAllButton = widgets.selectAllButton,
        overwriteButton = widgets.overwriteButton,
        cancelButton = widgets.cancelButton,
    }

    WireLayoutDialogActions(context, options)

    FocusWindow(window)
    if options.autoSelectText then
        QueueFocusTransferEditBox(context.editBox)
    end

    return context
end

local function SetTransferDialogStatus(context, message)
    if context and context.statusText and context.statusText.SetText then
        context.statusText:SetText(message or "")
    end
    SetStatus(message)
end

local function UpdateSavePresetDialogState(context)
    if not context or not context.okButton or not context.profileNameEdit then
        return
    end

    context.okButton:SetDisabled(Trim(context.profileNameEdit:GetText() or "") == "")
end

local function OpenSavePresetDialog(context)
    local db = ns.db
    local currentProfile = db and db.GetCurrentProfile and db:GetCurrentProfile() or ""
    savePresetDialogContext = OpenLayoutDialog(savePresetDialogContext, ProfilesLayouts.SavePreset, {
        title = T("PRESET_SAVE_TITLE", "Save as Preset"),
        windowWidth = 420,
        windowHeight = 190,
        state = {
            profileName = currentProfile,
            statusText = "",
        },
        buttonRoles = {
            okButton = "primary_action",
            cancelButton = "utility",
        },
        onOk = function(_, presetName)
            local mutations = ns.PresetMutations
            if not mutations or not mutations.CreateUserPresetFromProfile then
                SetTransferDialogStatus(savePresetDialogContext, T("PRESET_CREATE_FAILED", "Preset could not be created."))
                return false
            end

            local ok, presetOrError = mutations.CreateUserPresetFromProfile(presetName)
            if not ok then
                SetTransferDialogStatus(savePresetDialogContext, ResolveSavePresetError(presetOrError))
                UpdateSavePresetDialogState(savePresetDialogContext)
                return false
            end

            local presetId = presetOrError and presetOrError.metadata and presetOrError.metadata.id
            SelectPresetInToolbar(presetId)
            RefreshProfileUI()
            RefreshWindowState()
            SetStatus(T("PRESET_SAVED", "Preset saved."))
            return true
        end,
    })

    if savePresetDialogContext and savePresetDialogContext.profileNameEdit then
        local editBox = savePresetDialogContext.profileNameEdit
        editBox:SetCallback("OnTextChanged", function()
            SetTransferDialogStatus(savePresetDialogContext, "")
            UpdateSavePresetDialogState(savePresetDialogContext)
        end)
        editBox:SetCallback("OnEnterPressed", function()
            if savePresetDialogContext and savePresetDialogContext.okButton and Trim(editBox:GetText() or "") ~= "" then
                savePresetDialogContext.okButton:Fire("OnClick")
            end
        end)
        QueueFocusTransferEditBox(editBox)
    end

    if savePresetDialogContext and savePresetDialogContext.window and savePresetDialogContext.window.frame then
        local frame = savePresetDialogContext.window.frame
        frame:EnableKeyboard(true)
        if frame.SetPropagateKeyboardInput then
            frame:SetPropagateKeyboardInput(true)
        end
        frame:SetScript("OnKeyDown", function(_, key)
            if key == "ESCAPE"
                and savePresetDialogContext
                and savePresetDialogContext.window
                and savePresetDialogContext.window.Hide
            then
                savePresetDialogContext.window:Hide()
            end
        end)
    end

    UpdateSavePresetDialogState(savePresetDialogContext)
end

local function SyncImportProfileNameFromString(context)
    if not context or not context.editBox or not context.profileNameEdit then
        return
    end

    local transfer = ns.ProfileTransfer
    if not transfer or not transfer.GetProfileNameFromString then
        return
    end

    local suggestedProfileName = transfer.GetProfileNameFromString(context.editBox:GetText() or "")
    if not suggestedProfileName or suggestedProfileName == "" then
        return
    end

    local currentProfileName = Trim(context.profileNameEdit:GetText() or "")
    local previousSuggestion = context.importSuggestedProfileName or ""
    if context.profileNameUserEdited and currentProfileName ~= "" and currentProfileName ~= previousSuggestion then
        return
    end

    context.suspendProfileNameCallback = true
    context.profileNameEdit:SetText(suggestedProfileName)
    context.suspendProfileNameCallback = false
    context.importSuggestedProfileName = suggestedProfileName
    context.profileNameUserEdited = false
end

local function OpenOverwriteConfirmDialog(profileName, onConfirm)
    overwriteDialogContext = OpenLayoutDialog(overwriteDialogContext, ProfilesLayouts.TransferOverwriteConfirm, {
        title = T("INFO_PROFILES_IMPORT_OVERWRITE_TITLE", "Overwrite Profile"),
        windowWidth = 460,
        windowHeight = 230,
        state = {
            message = string.format(T("INFO_PROFILES_IMPORT_OVERWRITE_PROMPT", "Profile \"%s\" already exists. Overwrite it?"), profileName),
        },
    })

    if overwriteDialogContext and overwriteDialogContext.overwriteButton then
        overwriteDialogContext.overwriteButton:SetCallback("OnClick", function()
            if overwriteDialogContext.window and overwriteDialogContext.window.Hide then
                overwriteDialogContext.window:Hide()
            end
            if type(onConfirm) == "function" then
                onConfirm()
            end
        end)
    end

    if overwriteDialogContext and overwriteDialogContext.cancelButton then
        overwriteDialogContext.cancelButton:SetCallback("OnClick", function()
            if overwriteDialogContext.window and overwriteDialogContext.window.Hide then
                overwriteDialogContext.window:Hide()
            end
        end)
    end
end

local function ResolveItemText(item)
    if not item then
        return ""
    end

    if item.textKey then
        return T(item.textKey)
    end

    return item.text or ""
end

function CreateItemWidget(group, item, props, state)
    if not props or not props.widget then
        return nil
    end

    if props.widget == "label" then
        local label = CreateBodyText(
            props.stateKey and state and state[props.stateKey] or ResolveItemText(props),
            props.role or "label",
            props.size or 12,
            ResolveItemColor(props.colorKey),
            props.width,
            props.fullWidth
        )
        if props.justifyH and label.label and label.label.SetJustifyH then
            label.label:SetJustifyH(props.justifyH)
        end
        return label
    end

    if props.widget == "dropdown" then
        local dropdown = AceGUI:Create("Dropdown")
        dropdown:SetLabel(T(props.labelKey))
        if props.fullWidth ~= false then
            dropdown:SetFullWidth(true)
        end
        StyleDropdown(dropdown, props.fieldVariant or "accented")
        return dropdown
    end

    if props.widget == "editbox" then
        local editBox = AceGUI:Create("EditBox")
        editBox:SetLabel(T(props.labelKey))
        if props.fullWidth ~= false then
            editBox:SetFullWidth(true)
        end
        if props.disableButton then
            editBox:DisableButton(true)
        end
        local text = props.stateKey and state and state[props.stateKey] or props.text or ""
        editBox:SetText(text)
        StyleEditBox(editBox, props.fieldVariant)
        return editBox
    end

    if props.widget == "button" then
        return CreateActionButton(ResolveItemText(props), props.buttonVariant, props.width, props.fullWidth)
    end

    return nil
end

local function SyncNameEditText(context, text)
    if not context or not context.nameEdit then
        return
    end

    local value = text or ""
    if context.nameEdit:GetText() == value then
        return
    end

    context.suspendNameCallbacks = true
    context.nameEdit:SetText(value)
    context.suspendNameCallbacks = false
end

local function SyncDropdownValue(context, value)
    if not context or not context.profileSelect then
        return
    end

    context.suspendProfileCallbacks = true
    context.profileSelect:SetValue(value)
    context.suspendProfileCallbacks = false
end

local function ClearLayoutsContentRefs(context)
    if not context then
        return
    end

    context.activeProfileValue = nil
    context.savePresetButton = nil
    context.profileSelect = nil
    context.nameEdit = nil
    context.activateButton = nil
    context.copyButton = nil
    context.createButton = nil
    context.createState = nil
    context.exportButton = nil
    context.importButton = nil
    context.resetButton = nil
    context.deleteButton = nil
    context.sourceState = nil
    context.maintenanceHint = nil
    context.profileAutomation = nil
    context.presetsPlaceholder = nil
    context.suspendNameCallbacks = false
    context.suspendProfileCallbacks = false
    context.suspendAutomationCallbacks = false
end

local function ReleaseLayoutsContent(context)
    local contentHost = context and context.contentHost
    if contentHost and contentHost.ReleaseChildren then
        contentHost:ReleaseChildren()
    end
end

local function RenderProfilesSubpage(context)
    local contentHost = context and context.contentHost
    if not contentHost then
        return
    end

    local _, widgets = FormRenderer.BuildLayout(contentHost, BuildProfilesContentDefinition(), {
        state = context.state,
        createItemWidget = CreateItemWidget,
    })

    context.activeProfileValue = widgets.activeProfileValue
    context.savePresetButton = widgets.savePresetButton
    context.profileSelect = widgets.profileSelect
    context.nameEdit = widgets.nameEdit
    context.activateButton = widgets.activateButton
    context.copyButton = widgets.copyButton
    context.createButton = widgets.createButton
    context.createState = widgets.createState
    context.exportButton = widgets.exportButton
    context.importButton = widgets.importButton
    context.resetButton = widgets.resetButton
    context.deleteButton = widgets.deleteButton
    context.sourceState = widgets.sourceState
    context.maintenanceHint = widgets.maintenanceHint
end

local function RenderActiveLayoutsSubpage(context)
    if not context then
        return
    end

    ClearLayoutsContentRefs(context)
    context.activeSubpage = NormalizeLayoutsSubpage(context.state and context.state.layouts and context.state.layouts.activeSubpage)

    if context.activeSubpage == "profiles" then
        RenderProfilesSubpage(context)
    elseif context.activeSubpage == "automation" then
        local profileList = ns.db and GetProfileList(ns.db) or {}
        context.profileAutomation = CreateProfileAutomationBlock(context.contentHost, BuildAutomationViewData(profileList))
    elseif context.activeSubpage == "presets" then
        context.presetsPlaceholder = CreatePresetsPlaceholderBlock(context.contentHost)
    end
end

function RefreshWindowState()
    local context = windowContext
    if not context then
        return
    end

    local db = ns.db
    local state = context.state or {}
    RefreshLayoutsSubnav(context)

    if context.activeSubpage ~= "profiles" then
        if context.profileAutomation then
            RefreshProfileAutomationBlock(context, db and GetProfileList(db) or {})
        end
        if context.window and context.window.DoLayout then
            context.window:DoLayout()
        end
        return
    end

    local function ApplyProfilesButtonVisuals()
        if not ApplyModalActionButtonVisual then
            return
        end

        ApplyModalActionButtonVisual(context.activateButton, "primary_action")
        ApplyModalActionButtonVisual(context.savePresetButton, "utility")
        ApplyModalActionButtonVisual(context.copyButton, "utility")
        ApplyModalActionButtonVisual(context.createButton, "utility")
        ApplyModalActionButtonVisual(context.exportButton, "utility")
        ApplyModalActionButtonVisual(context.importButton, "utility")
        ApplyModalActionButtonVisual(context.resetButton, "utility")
        ApplyModalActionButtonVisual(context.deleteButton, "danger")
    end

    if not db then
        context.activeProfileValue:SetText(T("INFO_COMMON_UNAVAILABLE"))
        context.savePresetButton:SetDisabled(true)
        context.profileSelect:SetList({})
        SyncDropdownValue(context, nil)
        context.profileSelect:SetDisabled(true)
        context.nameEdit:SetDisabled(true)
        context.activateButton:SetDisabled(true)
        context.copyButton:SetDisabled(true)
        context.createButton:SetDisabled(true)
        context.exportButton:SetDisabled(true)
        context.importButton:SetDisabled(true)
        context.resetButton:SetDisabled(true)
        context.deleteButton:SetDisabled(true)
        ApplyProfilesButtonVisuals()
        context.sourceState:SetText(T("INFO_COMMON_UNAVAILABLE"))
        context.createState:SetText(T("INFO_COMMON_UNAVAILABLE"))
        context.maintenanceHint:SetText(T("INFO_COMMON_UNAVAILABLE"))
        if context.window and context.window.DoLayout then
            context.window:DoLayout()
        end
        return
    end

    local currentProfile = db:GetCurrentProfile() or "Default"
    local profileList = GetProfileList(db)
    local selectedProfile = state.selectedProfile or currentProfile

    if type(selectedProfile) ~= "string" or selectedProfile == "" or not profileList[selectedProfile] then
        selectedProfile = currentProfile
        state.selectedProfile = selectedProfile
    end

    local newProfileName = Trim(state.newProfileName or context.nameEdit:GetText() or "")
    local sameAsCurrent = selectedProfile == currentProfile
    local hasSelectedProfile = type(selectedProfile) == "string" and selectedProfile ~= ""
    local hasNewProfileName = newProfileName ~= ""
    local newProfileExists = hasNewProfileName and profileList[newProfileName] ~= nil

    context.activeProfileValue:SetText(currentProfile)
    context.savePresetButton:SetText(T("PRESET_SAVE_AS", "Save as Preset"))
    context.savePresetButton:SetDisabled(currentProfile == nil or currentProfile == "")
    context.profileSelect:SetList(profileList)
    context.profileSelect:SetDisabled(false)
    SyncDropdownValue(context, selectedProfile)
    RefreshProfileAutomationBlock(context, profileList)

    context.nameEdit:SetDisabled(false)
    SyncNameEditText(context, state.newProfileName or "")

    context.activateButton:SetDisabled(not hasSelectedProfile or sameAsCurrent)
    context.copyButton:SetDisabled(not hasSelectedProfile or sameAsCurrent)
    context.exportButton:SetDisabled(false)
    context.importButton:SetDisabled(false)
    context.deleteButton:SetDisabled(not hasSelectedProfile or sameAsCurrent)
    context.resetButton:SetDisabled(currentProfile == nil or currentProfile == "")
    context.createButton:SetDisabled(not hasNewProfileName or newProfileExists)
    ApplyProfilesButtonVisuals()

    if hasSelectedProfile then
        context.sourceState:SetText(string.format(
            "%s: %s",
            T("INFO_PROFILES_SELECTED_SOURCE_SHORT"),
            selectedProfile
        ))
    else
        context.sourceState:SetText(T("INFO_PROFILES_SOURCE_SUMMARY_NONE"))
    end

    if newProfileExists then
        context.createState:SetText(T("INFO_PROFILES_CREATE_NAME_EXISTS"))
    else
        context.createState:SetText(T("INFO_PROFILES_CREATE_EMPTY_SUMMARY"))
    end

    if sameAsCurrent or not hasSelectedProfile then
        context.maintenanceHint:SetText(T(
            "INFO_PROFILES_MAINTENANCE_IDLE_SHORT",
            "Zuruecksetzen betrifft das aktive Profil. Zum Loeschen erst eine andere Quelle waehlen."
        ))
    else
        context.maintenanceHint:SetText(string.format(
            "%s %s",
            T("INFO_PROFILES_MAINTENANCE_TARGET_SHORT"),
            selectedProfile
        ))
    end

    if context.window and context.window.DoLayout then
        context.window:DoLayout()
    end
end

local function CreateWindowContent(window, state)
    local groups, widgets = FormRenderer.BuildLayout(window, BuildLayoutsShellDefinition(), {
        state = state,
        createItemWidget = CreateItemWidget,
    })

    local context = {
        window = window,
        state = state,
        root = groups.Root,
        contentHost = groups.ContentHost,
        activeSubpage = NormalizeLayoutsSubpage(state and state.layouts and state.layouts.activeSubpage),
        profilesTabButton = widgets.profilesTabButton,
        presetsTabButton = widgets.presetsTabButton,
        automationTabButton = widgets.automationTabButton,
        suspendNameCallbacks = false,
        suspendProfileCallbacks = false,
        suspendAutomationCallbacks = false,
        shellCallbacksWired = false,
    }

    RenderActiveLayoutsSubpage(context)
    return context
end

local function WireWindowCallbacks(context)
    if not context then
        return
    end

    local function SwitchLayoutsSubpage(subpage)
        if not context.state or not context.state.layouts then
            return
        end
        subpage = NormalizeLayoutsSubpage(subpage)
        if context.state.layouts.activeSubpage == subpage then
            return
        end

        context.state.layouts.activeSubpage = subpage
        ReleaseLayoutsContent(context)
        RenderActiveLayoutsSubpage(context)
        WireWindowCallbacks(context)
        RefreshWindowState()
    end

    if not context.shellCallbacksWired then
        if context.profilesTabButton then
            context.profilesTabButton:SetCallback("OnClick", function()
                SwitchLayoutsSubpage("profiles")
            end)
        end
        if context.presetsTabButton then
            context.presetsTabButton:SetCallback("OnClick", function()
                SwitchLayoutsSubpage("presets")
            end)
        end
        if context.automationTabButton then
            context.automationTabButton:SetCallback("OnClick", function()
                SwitchLayoutsSubpage("automation")
            end)
        end
        context.shellCallbacksWired = true
    end

    if context.activeSubpage ~= "profiles" then
        WireProfileAutomationBlock(context)
        return
    end

    if not context.profileSelect or not context.nameEdit then
        return
    end

    context.profileSelect:SetCallback("OnValueChanged", function(_, _, value)
        local db = ns.db
        if not db then
            return
        end

        if context.suspendProfileCallbacks then
            return
        end

        context.state.selectedProfile = value or db:GetCurrentProfile()
        RefreshWindowState()
    end)

    context.nameEdit:SetCallback("OnTextChanged", function(_, _, value)
        if context.suspendNameCallbacks then
            return
        end

        context.state.newProfileName = value or ""
        RefreshWindowState()
    end)

    context.nameEdit:SetCallback("OnEnterPressed", function(widget, _, value)
        if context.suspendNameCallbacks then
            return
        end

        context.state.newProfileName = value or ""
        widget:ClearFocus()
        RefreshWindowState()
    end)

    context.nameEdit:SetCallback("OnFocusLost", function(widget)
        if context.suspendNameCallbacks then
            return
        end

        context.state.newProfileName = widget:GetText() or ""
        RefreshWindowState()
    end)

    WireProfileAutomationBlock(context)

    context.savePresetButton:SetCallback("OnClick", function()
        OpenSavePresetDialog(context)
    end)

    context.activateButton:SetCallback("OnClick", function()
        local db = ns.db
        if not db then
            return
        end

        local profileName = context.state.selectedProfile or db:GetCurrentProfile()
        if not profileName or profileName == "" then
            return
        end

        SetProfileAndLetCallbackSync(db, profileName, "profiles-activate-current")
        context.state.selectedProfile = profileName
        RefreshProfileUI()
        RefreshWindowState()
        SetStatus((T("INFO_PROFILES_STATUS_ACTIVATED")) .. " " .. profileName)
    end)

    context.copyButton:SetCallback("OnClick", function()
        local db = ns.db
        if not db then
            return
        end

        local profileName = context.state.selectedProfile or db:GetCurrentProfile()
        if not profileName or profileName == "" then
            return
        end

        if profileName == db:GetCurrentProfile() then
            SetStatus(T("INFO_PROFILES_STATUS_COPY_SAME"))
            return
        end

        db:CopyProfile(profileName)
        SyncActiveProfile("profiles-copy")
        RefreshProfileUI()
        RefreshWindowState()
        SetStatus((T("INFO_PROFILES_STATUS_COPIED")) .. " " .. profileName)
    end)

    context.exportButton:SetCallback("OnClick", function()
        local transfer = ns.ProfileTransfer
        if not transfer or not transfer.ExportCurrentProfile then
            SetStatus(T("INFO_PROFILES_EXPORT_UNAVAILABLE", "Profile export is not available."))
            return
        end

        local exportString = transfer.ExportCurrentProfile(ns.db)
        if not exportString then
            SetStatus(T("INFO_PROFILES_EXPORT_FAILED", "Profile export failed."))
            return
        end

        HideProfileWindowForTransfer()
        exportDialogContext = OpenLayoutDialog(exportDialogContext, ProfilesLayouts.TransferExport, {
            title = T("INFO_PROFILES_EXPORT_TITLE", "Export Profile"),
            windowWidth = 760,
            windowHeight = 380,
            state = {
                transferText = exportString,
            },
            buttonRoles = {
                selectAllButton = "primary_action",
                okButton = "utility",
            },
            autoSelectText = true,
            restoreProfileOnClose = true,
        })
        SetStatus(T("INFO_PROFILES_EXPORT_READY", "Profile export string created."))
    end)

    context.importButton:SetCallback("OnClick", function()
        local function CompleteImport(profileName, previousProfileName)
            context.state.selectedProfile = profileName
            context.state.newProfileName = ""
            if previousProfileName == profileName then
                SyncActiveProfile("profiles-import-current")
            end
            RefreshProfileUI()
            RefreshWindowState()
            SetTransferDialogStatus(importDialogContext, string.format(T("INFO_PROFILES_IMPORT_DONE", "Profile \"%s\" was imported."), profileName))
        end

        HideProfileWindowForTransfer()
        importDialogContext = OpenLayoutDialog(
            importDialogContext,
            ProfilesLayouts.TransferImport,
            {
                title = T("INFO_PROFILES_IMPORT_TITLE", "Import Profile"),
                windowWidth = 620,
                windowHeight = 400,
                state = {
                    transferText = "",
                    profileName = "",
                },
                buttonRoles = {
                    okButton = "primary_action",
                    cancelButton = "utility",
                },
                restoreProfileOnClose = true,
                onOk = function(importString, targetProfileName)
                    local transfer = ns.ProfileTransfer
                    if not transfer or not transfer.ImportProfileString then
                        SetTransferDialogStatus(importDialogContext, T("INFO_PROFILES_IMPORT_UNAVAILABLE", "Profile import is not available."))
                        return false
                    end

                    local previousProfileName = ns.db and ns.db.GetCurrentProfile and ns.db:GetCurrentProfile() or nil
                    local ok, profileName, errorCode, existingProfileName = pcall(transfer.ImportProfileString, ns.db, importString, targetProfileName)
                    if not ok then
                        SetTransferDialogStatus(importDialogContext, string.format(T("INFO_PROFILES_IMPORT_FAILED_DETAIL", "Profile import failed: %s"), tostring(profileName)))
                        return false
                    end
                    if errorCode == "profile-exists" then
                        SetTransferDialogStatus(importDialogContext, string.format(T("INFO_PROFILES_IMPORT_EXISTS", "Profile \"%s\" already exists."), existingProfileName or targetProfileName or ""))
                        OpenOverwriteConfirmDialog(existingProfileName or targetProfileName or "", function()
                            local overwritePreviousProfileName = ns.db and ns.db.GetCurrentProfile and ns.db:GetCurrentProfile() or nil
                            local overwriteOk, overwrittenProfileName, overwriteErrorCode = pcall(transfer.ImportProfileString, ns.db, importString, targetProfileName, { overwrite = true })
                            if not overwriteOk or not overwrittenProfileName then
                                SetTransferDialogStatus(importDialogContext, string.format(T("INFO_PROFILES_IMPORT_FAILED_DETAIL", "Profile import failed: %s"), tostring(overwriteErrorCode or overwrittenProfileName)))
                                return
                            end

                            if importDialogContext and importDialogContext.window and importDialogContext.window.Hide then
                                importDialogContext.window:Hide()
                            end
                            CompleteImport(overwrittenProfileName, overwritePreviousProfileName)
                        end)
                        return false
                    end
                    if not profileName then
                        SetTransferDialogStatus(importDialogContext, string.format(T("INFO_PROFILES_IMPORT_FAILED_DETAIL", "Profile import failed: %s"), tostring(errorCode or "unknown")))
                        return false
                    end

                    CompleteImport(profileName, previousProfileName)
                    return true
                end,
            }
        )

        if importDialogContext and importDialogContext.profileNameEdit then
            importDialogContext.profileNameUserEdited = false
            importDialogContext.importSuggestedProfileName = ""
            importDialogContext.profileNameEdit:SetCallback("OnTextChanged", function()
                if importDialogContext.suspendProfileNameCallback then
                    return
                end
                importDialogContext.profileNameUserEdited = true
            end)
        end
        if importDialogContext and importDialogContext.editBox then
            importDialogContext.editBox:SetCallback("OnTextChanged", function()
                SyncImportProfileNameFromString(importDialogContext)
            end)
        end
    end)

    context.deleteButton:SetCallback("OnClick", function()
        local db = ns.db
        if not db then
            return
        end

        local profileName = context.state.selectedProfile or db:GetCurrentProfile()
        if not profileName or profileName == "" or profileName == db:GetCurrentProfile() then
            return
        end

        db:DeleteProfile(profileName, true)
        local automation = GetProfileAutomation()
        if automation and automation.ReconcileProfileDeleted then
            automation.ReconcileProfileDeleted(profileName)
        end
        context.state.selectedProfile = db:GetCurrentProfile()
        RefreshProfileUI()
        RefreshWindowState()
        SetStatus((T("INFO_PROFILES_STATUS_DELETED")) .. " " .. profileName)
    end)

    context.resetButton:SetCallback("OnClick", function()
        local db = ns.db
        if not db then
            return
        end

        local currentProfile = db:GetCurrentProfile()
        if not currentProfile or currentProfile == "" then
            return
        end

        db:ResetProfile()
        SyncActiveProfile("profiles-reset")
        RefreshProfileUI()
        RefreshWindowState()
        SetStatus((T("INFO_PROFILES_STATUS_RESET")) .. " " .. currentProfile)
    end)

    context.createButton:SetCallback("OnClick", function()
        local db = ns.db
        if not db then
            return
        end

        local profileName = Trim(context.nameEdit:GetText() or "")
        if profileName == "" then
            return
        end

        if db.GetProfiles then
            local profiles = GetProfileList(db)
            if profiles[profileName] then
                SetStatus(T("INFO_PROFILES_CREATE_NAME_EXISTS"))
                return
            end
        end

        SetProfileAndLetCallbackSync(db, profileName, "profiles-create-current", { allowCreate = true })
        context.state.selectedProfile = profileName
        context.state.newProfileName = ""
        RefreshProfileUI()
        RefreshWindowState()
        SetStatus((T("INFO_PROFILES_STATUS_CREATED")) .. " " .. profileName)
    end)
end

local function CreateWindow(state)
    local window = AceGUI:Create("Window")
    window:SetTitle(T("LAYOUTS_TITLE", "Layouts"))
    window:SetLayout("Fill")
    window:SetWidth(760)
    window:SetHeight(720)
    window:EnableResize(false)

    if window.frame then
        window.frame:SetClampedToScreen(true)
    end

    ApplyWindowChrome(window)
    if EnsureStandardWindowCloseButton then
        EnsureStandardWindowCloseButton(window)
    end
    CenterWindow(window)

    local context = CreateWindowContent(window, state)
    windowContext = context
    WireWindowCallbacks(context)

    window:SetCallback("OnClose", function()
        if ns.GUI and ns.GUI.ResetStatusText then
            ns.GUI:ResetStatusText()
        end
    end)

    return context
end

function ProfilesController.OpenWindow(deps)
    local state = GetProfilesState(deps)

    if not windowContext or not windowContext.window or not windowContext.window.frame then
        CreateWindow(state)
    else
        windowContext.state = state
    end

    RefreshWindowState()
    FocusWindow(windowContext.window)
end

function ProfilesController.HideWindow()
    if exportDialogContext and exportDialogContext.window and exportDialogContext.window.Hide then
        exportDialogContext.window:Hide()
    end
    if importDialogContext and importDialogContext.window and importDialogContext.window.Hide then
        importDialogContext.window:Hide()
    end
    if overwriteDialogContext and overwriteDialogContext.window and overwriteDialogContext.window.Hide then
        overwriteDialogContext.window:Hide()
    end
    if savePresetDialogContext and savePresetDialogContext.window and savePresetDialogContext.window.Hide then
        savePresetDialogContext.window:Hide()
    end

    if not windowContext or not windowContext.window then
        return
    end

    if windowContext.window.Hide then
        windowContext.window:Hide()
    elseif windowContext.window.frame and windowContext.window.frame.Hide then
        windowContext.window.frame:Hide()
    end
end

return ProfilesController
