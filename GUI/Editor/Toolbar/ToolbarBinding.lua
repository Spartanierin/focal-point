local _, ns = ...

ns.GUI = ns.GUI or {}
ns.GUI.Editor = ns.GUI.Editor or {}

local ToolbarBinding = {}
ns.GUI.Editor.ToolbarBinding = ToolbarBinding

local NAV_WIDGET_IDS = {
    editorButton = { "Nav", "EDITOR" },
    profilesButton = { "Nav", "PROFILES" },
    textBuilderButton = { "Nav", "TEXT_BUILDER" },
    tagDatabaseButton = { "Nav", "TAG_DATABASE" },
}

local UNIT_WIDGET_IDS = {
    playerButton = { "Units", "PLAYER" },
    targetButton = { "Units", "TARGET" },
    targetTargetButton = { "Units", "TARGETTARGET" },
    petButton = { "Units", "PET" },
    focusButton = { "Units", "FOCUS" },
    focusTargetButton = { "Units", "FOCUSTARGET" },
    bossButton = { "Units", "BOSS" },
}

local INTERACTION_MODE_BUTTONS = {
    frame = "frameModeButton",
    text = "textModeButton",
}

local BUILT_IN_PRESET_ORDER = {
    "default",
    "classic",
    "minimal",
    "modern",
}

local CUSTOM_PRESET_ID = "__custom__"
local createProfileDialog

local function ResolveConstantPath(root, path)
    if type(root) ~= "table" or type(path) ~= "table" then
        return nil
    end

    local value = root
    for _, key in ipairs(path) do
        if type(value) ~= "table" then
            return nil
        end
        value = value[key]
    end
    return value
end

local function T(key, fallback, deps)
    local L = deps and deps.L or {}
    return (type(key) == "string" and L[key]) or fallback or ""
end

local ResolveEditorMode

local function ResolveAddon(deps)
    return (deps and deps.ns) or ns or {}
end

local function EnsureGeneralConfig(nsRef)
    local profile = nsRef and nsRef.db and nsRef.db.profile
    if type(profile) ~= "table" then
        return nil
    end

    profile.General = type(profile.General) == "table" and profile.General or {}
    return profile.General
end

local function EnsureMinimapConfig(nsRef)
    local profile = nsRef and nsRef.db and nsRef.db.profile
    if type(profile) ~= "table" then
        return nil
    end

    profile.Minimap = type(profile.Minimap) == "table" and profile.Minimap or {}
    return profile.Minimap
end

local function Trim(value)
    if type(value) ~= "string" then
        return ""
    end
    return (value:gsub("^%s+", ""):gsub("%s+$", ""))
end

local function NotifyGlobalChanged(options, refreshFn)
    if options and options.onGlobalChanged then
        options.onGlobalChanged()
    elseif refreshFn then
        refreshFn()
    end
end

local function ResolvePresetName(preset, deps)
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

local function ResolvePresetDescription(preset, fallback, deps)
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

local function SortByNameThenId(a, b)
    local leftName = string.lower(a.name or "")
    local rightName = string.lower(b.name or "")
    if leftName == rightName then
        return tostring(a.id or "") < tostring(b.id or "")
    end
    return leftName < rightName
end

local function BuildPresetDropdownList(presets, deps, options)
    local list = {}
    local order = {}
    local seen = {}

    local function addPreset(id, preset)
        if type(id) ~= "string" or id == "" or seen[id] or type(preset) ~= "table" then
            return
        end
        local name = ResolvePresetName(preset, deps)
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
                name = ResolvePresetName(preset, deps),
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

local function GetFirstPresetId(order, list)
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

local function OpenCreateProfileDialog(context, deps, refreshFn)
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

    local presetName = ResolvePresetName(preset, deps)
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
            reason = "toolbar-create-profile-from-preset",
        })
        if ok then
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

local function IsExpertMode(deps, state)
    local nsRef = ResolveAddon(deps)
    return ResolveEditorMode(state, nsRef.db and nsRef.db.profile) == "expert"
end

function ToolbarBinding.GetGlobalOptionValue(optionId, deps)
    local nsRef = ResolveAddon(deps)
    local generalConfig = EnsureGeneralConfig(nsRef)
    if type(generalConfig) ~= "table" then
        return nil
    end

    if optionId == "hideBlizzard" then
        return generalConfig.HideBlizzardFrames == true
    elseif optionId == "showMinimapButton" then
        local minimapConfig = nsRef.db and nsRef.db.profile and nsRef.db.profile.Minimap
        return not (type(minimapConfig) == "table" and minimapConfig.hide == true)
    elseif optionId == "mouseEnabled" then
        return generalConfig.MouseEnabled ~= false
    elseif optionId == "clickthrough" then
        return generalConfig.GlobalClickThrough == true
    end

    return nil
end

function ToolbarBinding.ApplyGlobalOptionValue(optionId, value, deps, options)
    local nsRef = ResolveAddon(deps)
    local generalConfig = EnsureGeneralConfig(nsRef)
    if type(generalConfig) ~= "table" then
        return false
    end

    if optionId == "hideBlizzard" then
        generalConfig.HideBlizzardFrames = value and true or false
        if nsRef.ApplyGeneralSettings then
            nsRef:ApplyGeneralSettings()
        end
        if not generalConfig.HideBlizzardFrames and nsRef.Info then
            nsRef:Info(T("INFO_RELOAD_REQUIRED_BLIZZARD_FRAMES", nil, deps))
        end
    elseif optionId == "showMinimapButton" then
        if nsRef.SetMinimapButtonVisible then
            nsRef:SetMinimapButtonVisible(value == true)
        else
            local minimapConfig = EnsureMinimapConfig(nsRef)
            if type(minimapConfig) ~= "table" then
                return false
            end
            minimapConfig.hide = value ~= true
        end
    elseif optionId == "mouseEnabled" then
        generalConfig.MouseEnabled = value and true or false
        if nsRef.RefreshAllUnitFrames then
            nsRef:RefreshAllUnitFrames()
        end
    elseif optionId == "clickthrough" then
        generalConfig.GlobalClickThrough = value and true or false
        if nsRef.RefreshAllUnitFrames then
            nsRef:RefreshAllUnitFrames()
        end
    else
        return false
    end

    NotifyGlobalChanged(options, options and options.refreshFn)
    return true
end

function ResolveEditorMode(state, profile)
    local editorMode = ns.EditorMode or (ns.GUI and ns.GUI.Editor and ns.GUI.Editor.Mode)
    if editorMode and editorMode.Resolve then
        return editorMode.Resolve(state, profile)
    end

    return "quick"
end

local function ResolveItemText(props, deps)
    if not props then
        return ""
    end
    if props.textKey then
        return T(props.textKey, nil, deps)
    end
    return props.text or ""
end

local function ResolveLabelRole(props)
    if not props then
        return "label"
    end

    local variant = props.itemVariant
    if variant == "section_title" or variant == "section_title_large" then
        return "sectionHeader"
    end
    if variant == "group_title" then
        return "groupTitle"
    end
    if variant == "group_description" then
        return "description"
    end
    if variant == "footer_hint_muted" then
        return "muted"
    end
    if variant == "status_value" then
        return "value"
    end

    return props.role or "label"
end

local function IsCombatLocked()
    return InCombatLockdown and InCombatLockdown() == true
end

local function GetInteractionMode(nsRef)
    return nsRef
        and nsRef.GUI
        and nsRef.GUI.Editor
        and nsRef.GUI.Editor.InteractionMode
        or nil
end

local function IsInteractionModeControlDisabled(nsRef)
    return not (nsRef and nsRef.framesUnlocked == true)
        or IsCombatLocked()
        or not (nsRef.IsEditorActive and nsRef:IsEditorActive())
end

local function AttachInteractionModeTooltip(button, titleKey, fallbackTitle, deps)
    if not button or not button.frame or button.__fpInteractionModeTooltipHooked then
        return
    end

    button.__fpInteractionModeTooltipHooked = true
    button.frame:HookScript("OnEnter", function(self)
        local title = T(titleKey, fallbackTitle, deps)
        if type(title) ~= "string" or title == "" or not GameTooltip then
            return
        end

        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        if GameTooltip.ClearLines then
            GameTooltip:ClearLines()
        end
        GameTooltip:AddLine(title, 1, 1, 1, true)
        GameTooltip:AddLine(T("EDITOR_INTERACTION_MODE_TOOLTIP_SHIFT", "Press Shift to toggle modes.", deps), 0.80, 0.76, 0.66, true)
        GameTooltip:Show()
    end)
    button.frame:HookScript("OnLeave", function()
        if GameTooltip and GameTooltip.Hide then
            GameTooltip:Hide()
        end
    end)
end

local function IterateWidgetMap(widgetMap, callback)
    if type(widgetMap) ~= "table" or type(callback) ~= "function" then
        return
    end
    for widgetId, constantPath in pairs(widgetMap) do
        callback(widgetId, constantPath)
    end
end

local function CreateItemWidget(props, deps)
    if not props or not props.widget then
        return nil
    end

    local AceGUI = deps and deps.AceGUI
    local CreateBodyText = deps and deps.CreateBodyText
    local CreateActionButton = deps and deps.CreateActionButton
    local StyleCheckBox = deps and deps.StyleCheckBox
    local StyleDropdown = deps and deps.StyleDropdown
    local ResolveItemColor = deps and deps.ResolveItemColor

    if props.widget == "label" then
        local label = CreateBodyText and CreateBodyText(
            ResolveItemText(props, deps),
            ResolveLabelRole(props),
            props.size or 12,
            ResolveItemColor and ResolveItemColor(props.colorKey),
            props.width,
            props.fullWidth
        )
        if props.justifyH and label and label.label and label.label.SetJustifyH then
            label.label:SetJustifyH(props.justifyH)
        end
        return label
    end

    if props.widget == "button" then
        return CreateActionButton and CreateActionButton(ResolveItemText(props, deps), props.buttonVariant, props.width, props.fullWidth)
    end

    if props.widget == "checkbox" and AceGUI then
        local checkbox = AceGUI:Create("CheckBox")
        if type(props.width) == "number" then
            checkbox:SetFullWidth(false)
            checkbox:SetWidth(props.width)
        elseif props.fullWidth ~= false then
            checkbox:SetFullWidth(true)
        end
        checkbox:SetLabel(ResolveItemText(props, deps))
        checkbox:SetValue(props.checked and true or false)
        if StyleCheckBox then
            StyleCheckBox(checkbox, false)
        end
        return checkbox
    end

    if props.widget == "dropdown" and AceGUI then
        local dropdown = AceGUI:Create("Dropdown")
        dropdown:SetLabel(T(props.labelKey, nil, deps))
        if props.fullWidth ~= false then
            dropdown:SetFullWidth(true)
        end
        if StyleDropdown then
            StyleDropdown(dropdown, props.fieldVariant or "accented")
        end
        return dropdown
    end

    return nil
end

local function RefreshInteractionModeControls(context, deps)
    if not context or not context.widgets then
        return
    end

    local nsRef = deps and deps.ns or {}
    local sidebarThemeHelpers = nsRef.GUI and nsRef.GUI.Editor and nsRef.GUI.Editor.EditorSidebarThemeHelpers or {}
    local SIDEBAR_VISUAL_ROLE = (nsRef.GUI and nsRef.GUI.ButtonVisualRole)
        or sidebarThemeHelpers.ButtonVisualRole
        or sidebarThemeHelpers.SIDEBAR_VISUAL_ROLE
        or {
            ACTIVE = "active",
            SECONDARY = "secondary",
        }
    local ApplySidebarButtonVisual = sidebarThemeHelpers.ApplySidebarButtonVisual or sidebarThemeHelpers.StyleSidebarButton
    local interactionMode = GetInteractionMode(nsRef)
    local isFrameMode = interactionMode and interactionMode.IsFrameMode and interactionMode.IsFrameMode() or false
    local isTextMode = interactionMode and interactionMode.IsTextMode and interactionMode.IsTextMode() or false
    local disabled = IsInteractionModeControlDisabled(nsRef)
    local frameButton = context.widgets[INTERACTION_MODE_BUTTONS.frame]
    local textButton = context.widgets[INTERACTION_MODE_BUTTONS.text]

    if frameButton then
        frameButton:SetText(T("EDITOR_INTERACTION_FRAME_MODE", "Frame", deps))
        frameButton:SetDisabled(disabled)
        if ApplySidebarButtonVisual then
            ApplySidebarButtonVisual(frameButton, isFrameMode and SIDEBAR_VISUAL_ROLE.ACTIVE or SIDEBAR_VISUAL_ROLE.SECONDARY)
        end
        AttachInteractionModeTooltip(frameButton, "EDITOR_INTERACTION_FRAME_MODE_TOOLTIP", "Edit, move and resize unit frames.", deps)
    end

    if textButton then
        textButton:SetText(T("EDITOR_INTERACTION_TEXT_MODE", "Text", deps))
        textButton:SetDisabled(disabled)
        if ApplySidebarButtonVisual then
            ApplySidebarButtonVisual(textButton, isTextMode and SIDEBAR_VISUAL_ROLE.ACTIVE or SIDEBAR_VISUAL_ROLE.SECONDARY)
        end
        AttachInteractionModeTooltip(textButton, "EDITOR_INTERACTION_TEXT_MODE_TOOLTIP", "Select, move, anchor and resize text elements.", deps)
    end
end

local function RefreshWindowState(context, deps)
    if not context or not context.widgets then
        return
    end

    context._suspendCallbacks = true

    local state = context.state or {}
    local options = context.options or {}
    local nsRef = deps and deps.ns or {}
    local C = deps and deps.C or {}
    local KM = deps and deps.KM or {}
    local StyleCheckBox = deps and deps.StyleCheckBox
    local StyleDropdown = deps and deps.StyleDropdown
    local sidebarThemeHelpers = nsRef.GUI and nsRef.GUI.Editor and nsRef.GUI.Editor.EditorSidebarThemeHelpers or {}
    local SIDEBAR_VISUAL_ROLE = (nsRef.GUI and nsRef.GUI.ButtonVisualRole)
        or sidebarThemeHelpers.ButtonVisualRole
        or sidebarThemeHelpers.SIDEBAR_VISUAL_ROLE
        or {
            ACTIVE = "active",
            SECONDARY = "secondary",
            PRIMARY_ACTION = "primary_action",
            UTILITY = "utility",
            QUIET_UTILITY = "quiet_utility",
            DANGER = "danger",
        }
    local ApplySidebarButtonVisual = sidebarThemeHelpers.ApplySidebarButtonVisual or sidebarThemeHelpers.StyleSidebarButton
    local ThemeService = (deps and deps.ThemeService) or nsRef.ThemeService or {}
    local PresetService = (deps and deps.PresetService) or nsRef.PresetService or {}
    local BuilderUI = (deps and deps.BuilderUI) or (nsRef.GUI and nsRef.GUI.Helpers and nsRef.GUI.Helpers.GUIRuntimeHelpers) or {}
    local generalConfig = nsRef.db and nsRef.db.profile and nsRef.db.profile.General
    local customThemeId = ThemeService.GetCustomThemeId and ThemeService.GetCustomThemeId() or "__custom__"
    local presets = PresetService.ListPresets and PresetService.ListPresets() or {}
    local presetList, presetOrder = BuildPresetDropdownList(presets, deps, {
        includeCustom = ThemeService.HasDefaultSnapshot and ThemeService.HasDefaultSnapshot(),
        customId = customThemeId,
    })
    local activeThemeId = generalConfig and generalConfig.ActiveThemeId
    local selectedPresetId = state.selectedThemeId or activeThemeId
    if type(generalConfig) ~= "table" then
        context._suspendCallbacks = false
        return
    end
    local isExpertMode = IsExpertMode(deps, state)

    if not presetList[selectedPresetId] then
        selectedPresetId = activeThemeId
    end
    if not presetList[selectedPresetId] then
        selectedPresetId = GetFirstPresetId(presetOrder, presetList)
    end
    state.selectedThemeId = selectedPresetId
    local selectedPreset = PresetService.GetPreset and PresetService.GetPreset(selectedPresetId) or nil
    local selectedPresetSource = selectedPreset and selectedPreset.metadata and selectedPreset.metadata.source or nil
    local selectedIsBuiltInPreset = selectedPresetSource == "builtin"
    local selectedIsCustomLayout = selectedPresetId == customThemeId

    local versionText = BuilderUI.GetAddonVersionText and BuilderUI.GetAddonVersionText() or "dev"
    local logoPath = "Interface\\AddOns\\FocalPoint\\Media\\icon.tga"
    local normalizedCurrent = options.currentPath or (nsRef.GUI and nsRef.GUI.selectedPath) or ResolveConstantPath(C, { "Nav", "EDITOR" })

    if context.widgets.brandLine then
        local skins = nsRef.GUI and nsRef.GUI.Skins or nil
        local addonName = T("ADDON_NAME", C.ADDON_NAME or "FocalPoint", deps)
        local brandTitle = skins and skins.GetBrandTitle and skins.GetBrandTitle(addonName) or addonName
        context.widgets.brandLine:SetText(string.format("|T%s:24:24:0:0|t  %s", logoPath, brandTitle))
    end
    if context.widgets.versionLine then
        context.widgets.versionLine:SetText(string.format("|cffd8c27a%s|r  |cff4cff88%s|r", T("INFO_VERSION", "Version", deps), versionText))
    end
    if context.widgets.toolsTitle then
        context.widgets.toolsTitle:SetText(T("EDITOR_CONTEXT_TOOLS", "Tools", deps))
    end
    if context.widgets.workspaceTitle then
        context.widgets.workspaceTitle:SetText(T("EDITOR_CONTEXT_WORKSPACE", "Workspace", deps))
    end
    if context.widgets.editingTitle then
        context.widgets.editingTitle:SetText(T("EDITOR_CONTEXT_PREVIEW", "Editing", deps))
    end
    if context.widgets.presetsTitle then
        context.widgets.presetsTitle:SetText(T("EDITOR_CONTEXT_PRESET", "Presets", deps))
    end
    if context.widgets.globalTitle then
        context.widgets.globalTitle:SetText(T("EDITOR_CONTEXT_GLOBAL", "Addon", deps))
    end
    if context.widgets.footerNote then
        context.widgets.footerNote:SetText("")
    end
    if context.widgets.unitLabel then
        context.widgets.unitLabel:SetText(T("EDITOR_UNIT", "Unit", deps))
    end
    if context.widgets.workspaceTitle then
        context.widgets.workspaceTitle:SetText("")
    end

    IterateWidgetMap(NAV_WIDGET_IDS, function(widgetId, constantPath)
        local navPath = ResolveConstantPath(C, constantPath)
        local button = context.widgets[widgetId]
        if button then
            local isActivePath = normalizedCurrent == navPath
            local label = nsRef.GetLabel and nsRef.GetLabel(KM.Nav, navPath) or navPath or ""
            button:SetText(label)
            button:SetDisabled(isActivePath)
            if ApplySidebarButtonVisual then
                ApplySidebarButtonVisual(button, isActivePath and SIDEBAR_VISUAL_ROLE.ACTIVE or SIDEBAR_VISUAL_ROLE.SECONDARY)
            end
        end
    end)

    if context.widgets.closeButton then
        context.widgets.closeButton:SetText(CLOSE or "Close")
        if ApplySidebarButtonVisual then
            ApplySidebarButtonVisual(context.widgets.closeButton, SIDEBAR_VISUAL_ROLE.QUIET_UTILITY or SIDEBAR_VISUAL_ROLE.UTILITY)
        end
    end

    IterateWidgetMap(UNIT_WIDGET_IDS, function(widgetId, constantPath)
        local unitKey = ResolveConstantPath(C, constantPath)
        local button = context.widgets[widgetId]
        if button then
            button:SetText(nsRef.GetLabel and nsRef.GetLabel(KM.Units, unitKey) or unitKey or "")
            if ApplySidebarButtonVisual then
                ApplySidebarButtonVisual(button, unitKey == state.selectedUnit and SIDEBAR_VISUAL_ROLE.ACTIVE or SIDEBAR_VISUAL_ROLE.SECONDARY)
            end
        end
    end)

    if context.widgets.expertMode then
        context.widgets.expertMode:SetLabel(T("OPTION_EXPERT_MODE", "Expert Mode", deps))
        context.widgets.expertMode:SetValue(isExpertMode)
        if StyleCheckBox then
            StyleCheckBox(context.widgets.expertMode, false)
        end
    end

    if context.widgets.demoButton then
        context.widgets.demoButton:SetText((nsRef.guiTestModeEnabled and T("GUI_TEST_STOP", "Stop Test", deps)) or T("GUI_TEST_START", "Test", deps))
        if ApplySidebarButtonVisual then
            ApplySidebarButtonVisual(context.widgets.demoButton, SIDEBAR_VISUAL_ROLE.UTILITY)
        end
    end

    if context.widgets.unlockButton then
        context.widgets.unlockButton:SetText((nsRef.framesUnlocked and T("GUI_UNLOCK_STOP", "Lock Frames", deps)) or T("GUI_UNLOCK_START", "Unlock Frames", deps))
        if ApplySidebarButtonVisual then
            ApplySidebarButtonVisual(context.widgets.unlockButton, SIDEBAR_VISUAL_ROLE.PRIMARY_ACTION)
        end
    end

    RefreshInteractionModeControls(context, deps)

    if context.widgets.editingHint then
        context.widgets.editingHint:SetText(T("EDITOR_PREVIEW_INTERACTION_HINT", nil, deps))
    end

    if context.widgets.presetsIntro then
        context.widgets.presetsIntro:SetText(T("EDITOR_PRESET_CONTEXT_HINT", nil, deps))
    end

    if context.widgets.returnToEditor and ApplySidebarButtonVisual then
        ApplySidebarButtonVisual(context.widgets.returnToEditor, SIDEBAR_VISUAL_ROLE.UTILITY)
    end

    if context.widgets.presetDropdown then
        context.widgets.presetDropdown:SetLabel(T("EDITOR_PRESET_SELECT", T("THEME_SELECT", "Select Preset", deps), deps))
        context.widgets.presetDropdown:SetList(presetList, presetOrder)
        context.widgets.presetDropdown:SetValue(selectedPresetId)
        context.widgets.presetDropdown:SetDisabled(next(presetList) == nil)
        if StyleDropdown then
            StyleDropdown(context.widgets.presetDropdown, "editor_inset")
        end
    end

    if context.widgets.presetThemeInfo then
        local themeDescription
        if selectedIsCustomLayout then
            themeDescription = T("THEME_CUSTOM_DESC", nil, deps)
        else
            themeDescription = ResolvePresetDescription(selectedPreset, T("INFO_GENERAL_THEMES_DESC", nil, deps), deps)
        end
        context.widgets.presetThemeInfo:SetText(themeDescription or "")
    end

    if context.widgets.applyPreset then
        context.widgets.applyPreset:SetText(T("THEME_APPLY", T("INFO_GENERAL_THEME_APPLY", "Apply Preset", deps), deps))
        context.widgets.applyPreset:SetDisabled(not (selectedIsBuiltInPreset or selectedIsCustomLayout))
        if ApplySidebarButtonVisual then
            ApplySidebarButtonVisual(context.widgets.applyPreset, SIDEBAR_VISUAL_ROLE.PRIMARY_ACTION)
        end
    end

    if context.widgets.createProfileFromPreset then
        context.widgets.createProfileFromPreset:SetText(T("PRESET_CREATE_PROFILE", "Create Profile", deps))
        context.widgets.createProfileFromPreset:SetDisabled(not selectedPreset)
        if ApplySidebarButtonVisual then
            ApplySidebarButtonVisual(context.widgets.createProfileFromPreset, SIDEBAR_VISUAL_ROLE.UTILITY)
        end
    end

    if context.widgets.saveCustom then
        context.widgets.saveCustom:SetText(T("EDITOR_PRESET_SAVE_CUSTOM", "Save Current Layout as My Layout", deps))
        context.widgets.saveCustom:SetDisabled(not ThemeService.CaptureDefaultSnapshot)
        if ApplySidebarButtonVisual then
            ApplySidebarButtonVisual(context.widgets.saveCustom, SIDEBAR_VISUAL_ROLE.UTILITY)
        end
    end

    if context.widgets.restoreCustom then
        context.widgets.restoreCustom:SetText(T("EDITOR_PRESET_RESTORE", "Restore Previous Layout", deps))
        context.widgets.restoreCustom:SetDisabled(not (ThemeService.HasRestoreSnapshot and ThemeService.HasRestoreSnapshot() and ThemeService.RestoreSnapshot))
        if ApplySidebarButtonVisual then
            ApplySidebarButtonVisual(context.widgets.restoreCustom, SIDEBAR_VISUAL_ROLE.UTILITY)
        end
    end

    if context.widgets.restoreHint then
        context.widgets.restoreHint:SetText(T("EDITOR_PRESET_RESTORE_HINT", nil, deps))
    end

    if context.widgets.globalOptions then
        context.widgets.globalOptions:SetText(T("OPTION_OPTIONS", "Options", deps))
        if ApplySidebarButtonVisual then
            ApplySidebarButtonVisual(context.widgets.globalOptions, SIDEBAR_VISUAL_ROLE.UTILITY)
        end
    end

    if context.widgets.hideBlizzard then
        context.widgets.hideBlizzard:SetLabel(T("OPTION_HIDE_BLIZZARD_FRAMES", "Hide Blizzard Frames", deps))
        context.widgets.hideBlizzard:SetValue(ToolbarBinding.GetGlobalOptionValue("hideBlizzard", deps) == true)
        if StyleCheckBox then
            StyleCheckBox(context.widgets.hideBlizzard, false)
        end
    end

    if context.widgets.showMinimapButton then
        context.widgets.showMinimapButton:SetLabel(T("OPTION_SHOW_MINIMAP_BUTTON", "Show Minimap Button", deps))
        context.widgets.showMinimapButton:SetValue(ToolbarBinding.GetGlobalOptionValue("showMinimapButton", deps) == true)
        if StyleCheckBox then
            StyleCheckBox(context.widgets.showMinimapButton, false)
        end
    end

    if context.widgets.mouseEnabled then
        context.widgets.mouseEnabled:SetLabel(T("OPTION_MOUSE_ENABLED", "Mouse Enabled", deps))
        context.widgets.mouseEnabled:SetValue(ToolbarBinding.GetGlobalOptionValue("mouseEnabled", deps) == true)
        context.widgets.mouseEnabled:SetDisabled(not isExpertMode)
        if StyleCheckBox then
            StyleCheckBox(context.widgets.mouseEnabled, false)
        end
    end

    if context.widgets.clickthrough then
        context.widgets.clickthrough:SetLabel(T("OPTION_GLOBAL_CLICKTHROUGH", "Global Click Through", deps))
        context.widgets.clickthrough:SetValue(ToolbarBinding.GetGlobalOptionValue("clickthrough", deps) == true)
        context.widgets.clickthrough:SetDisabled(not isExpertMode)
        if StyleCheckBox then
            StyleCheckBox(context.widgets.clickthrough, false)
        end
    end

    if context.window and context.window.DoLayout then
        context.window:DoLayout()
    end
    if context.scroll and context.scroll.FixScroll then
        context.scroll:FixScroll()
    end

    context._suspendCallbacks = false
end

local function WireCallbacks(context, deps, refreshFn)
    local C = deps and deps.C or {}
    local nsRef = deps and deps.ns or {}

    IterateWidgetMap(NAV_WIDGET_IDS, function(widgetId, constantPath)
        local navPath = ResolveConstantPath(C, constantPath)
        local button = context.widgets[widgetId]
        if button then
            button:SetCallback("OnClick", function()
                if context.options and context.options.onNavigate then
                    context.options.onNavigate(navPath)
                end
            end)
        end
    end)

    if context.widgets.closeButton then
        context.widgets.closeButton:SetCallback("OnClick", function()
            if context.options and context.options.onClose then
                context.options.onClose()
            end
        end)
    end

    IterateWidgetMap(UNIT_WIDGET_IDS, function(widgetId, constantPath)
        local unitKey = ResolveConstantPath(C, constantPath)
        local button = context.widgets[widgetId]
        if button then
            button:SetCallback("OnClick", function()
                if context.options and context.options.onUnitChanged then
                    context.options.onUnitChanged(unitKey)
                end
            end)
        end
    end)

    if context.widgets.expertMode then
        context.widgets.expertMode:SetCallback("OnValueChanged", function(_, _, value)
            if context._suspendCallbacks then
                return
            end
            if context.options and context.options.onModeChanged then
                context.options.onModeChanged(value and "expert" or "quick")
            end
        end)
    end

    if context.widgets.demoButton then
        context.widgets.demoButton:SetCallback("OnClick", function()
            if nsRef.ToggleTestMode then
                nsRef:ToggleTestMode()
                if context.options and context.options.onGlobalChanged then
                    context.options.onGlobalChanged()
                end
            end
        end)
    end

    if context.widgets.unlockButton then
        context.widgets.unlockButton:SetCallback("OnClick", function()
            if nsRef.ToggleFrameLock then
                nsRef:ToggleFrameLock()
                if context.options and context.options.onGlobalChanged then
                    context.options.onGlobalChanged()
                end
            end
        end)
    end

    if context.widgets.frameModeButton then
        context.widgets.frameModeButton:SetCallback("OnClick", function()
            if IsInteractionModeControlDisabled(nsRef) then
                return
            end

            local interactionMode = GetInteractionMode(nsRef)
            if interactionMode
                and interactionMode.IsFrameMode
                and interactionMode.IsFrameMode() then
                return
            end
            if interactionMode and interactionMode.SetLatchedTextMode then
                interactionMode.SetLatchedTextMode(false)
            end
        end)
    end

    if context.widgets.textModeButton then
        context.widgets.textModeButton:SetCallback("OnClick", function()
            if IsInteractionModeControlDisabled(nsRef) then
                return
            end

            local interactionMode = GetInteractionMode(nsRef)
            if interactionMode
                and interactionMode.IsTextMode
                and interactionMode.IsTextMode() then
                return
            end
            if interactionMode and interactionMode.SetLatchedTextMode then
                interactionMode.SetLatchedTextMode(true)
            end
        end)
    end

    if context.widgets.presetDropdown then
        context.widgets.presetDropdown:SetCallback("OnValueChanged", function(_, _, value)
            if context._suspendCallbacks then
                return
            end
            context.state.selectedThemeId = value
            if context.options and context.options.onThemeChanged then
                context.options.onThemeChanged(value)
            elseif refreshFn then
                refreshFn()
            end
        end)
    end

    if context.widgets.applyPreset then
        context.widgets.applyPreset:SetCallback("OnClick", function()
            local ThemeService = (deps and deps.ThemeService) or nsRef.ThemeService or {}
            local PresetService = (deps and deps.PresetService) or nsRef.PresetService or {}
            local selectedThemeId = context.state and context.state.selectedThemeId
            local customThemeId = ThemeService.GetCustomThemeId and ThemeService.GetCustomThemeId() or "__custom__"
            local preset = PresetService.GetPreset and PresetService.GetPreset(selectedThemeId) or nil
            local isBuiltInPreset = preset and preset.metadata and preset.metadata.source == "builtin"
            local isCustomLayout = selectedThemeId == customThemeId
            if not selectedThemeId or not ThemeService.ApplyTheme then
                return
            end
            if not isBuiltInPreset and not isCustomLayout then
                return
            end

            if selectedThemeId ~= customThemeId
                and ThemeService.HasDefaultSnapshot
                and ThemeService.CaptureDefaultSnapshot
                and not ThemeService.HasDefaultSnapshot() then
                ThemeService.CaptureDefaultSnapshot()
            end

            if selectedThemeId ~= customThemeId and ThemeService.CaptureRestoreSnapshot then
                ThemeService.CaptureRestoreSnapshot()
            end

            if ThemeService.ApplyTheme(selectedThemeId) then
                local appliedThemeId = nsRef.db and nsRef.db.profile and nsRef.db.profile.General and nsRef.db.profile.General.ActiveThemeId or selectedThemeId
                context.state.selectedThemeId = appliedThemeId
                if context.options and context.options.onThemeApplied then
                    context.options.onThemeApplied(appliedThemeId)
                elseif refreshFn then
                    refreshFn()
                end
            end
        end)
    end

    if context.widgets.createProfileFromPreset then
        context.widgets.createProfileFromPreset:SetCallback("OnClick", function()
            OpenCreateProfileDialog(context, deps, refreshFn)
        end)
    end

    if context.widgets.saveCustom then
        context.widgets.saveCustom:SetCallback("OnClick", function()
            local ThemeService = (deps and deps.ThemeService) or nsRef.ThemeService or {}
            if ThemeService.CaptureDefaultSnapshot and ThemeService.CaptureDefaultSnapshot() then
                if context.options and context.options.onThemeApplied then
                    context.options.onThemeApplied(context.state and context.state.selectedThemeId)
                elseif refreshFn then
                    refreshFn()
                end
            end
        end)
    end

    if context.widgets.restoreCustom then
        context.widgets.restoreCustom:SetCallback("OnClick", function()
            local ThemeService = (deps and deps.ThemeService) or nsRef.ThemeService or {}
            if ThemeService.RestoreSnapshot and ThemeService.RestoreSnapshot() then
                local restoredThemeId = nsRef.db and nsRef.db.profile and nsRef.db.profile.General and nsRef.db.profile.General.ActiveThemeId or (context.state and context.state.selectedThemeId)
                if context.state then
                    context.state.selectedThemeId = restoredThemeId
                end
                if context.options and context.options.onThemeApplied then
                    context.options.onThemeApplied(restoredThemeId)
                elseif refreshFn then
                    refreshFn()
                end
            end
        end)
    end

    if context.widgets.hideBlizzard then
        context.widgets.hideBlizzard:SetCallback("OnValueChanged", function(_, _, value)
            if context._suspendCallbacks then
                return
            end
            ToolbarBinding.ApplyGlobalOptionValue("hideBlizzard", value, deps, { onGlobalChanged = context.options and context.options.onGlobalChanged, refreshFn = refreshFn })
        end)
    end

    if context.widgets.showMinimapButton then
        context.widgets.showMinimapButton:SetCallback("OnValueChanged", function(_, _, value)
            if context._suspendCallbacks then
                return
            end
            ToolbarBinding.ApplyGlobalOptionValue("showMinimapButton", value, deps, { onGlobalChanged = context.options and context.options.onGlobalChanged, refreshFn = refreshFn })
        end)
    end

    if context.widgets.globalOptions then
        context.widgets.globalOptions:SetCallback("OnClick", function()
            if context._suspendCallbacks then
                return
            end
            local optionsDialog = nsRef.GUI
                and nsRef.GUI.Editor
                and nsRef.GUI.Editor.OptionsDialog
            if optionsDialog and optionsDialog.Open then
                optionsDialog.Open()
            end
        end)
    end

    if context.widgets.mouseEnabled then
        context.widgets.mouseEnabled:SetCallback("OnValueChanged", function(_, _, value)
            if context._suspendCallbacks then
                return
            end
            ToolbarBinding.ApplyGlobalOptionValue("mouseEnabled", value, deps, { onGlobalChanged = context.options and context.options.onGlobalChanged, refreshFn = refreshFn })
        end)
    end

    if context.widgets.clickthrough then
        context.widgets.clickthrough:SetCallback("OnValueChanged", function(_, _, value)
            if context._suspendCallbacks then
                return
            end
            ToolbarBinding.ApplyGlobalOptionValue("clickthrough", value, deps, { onGlobalChanged = context.options and context.options.onGlobalChanged, refreshFn = refreshFn })
        end)
    end
end

ToolbarBinding.CreateItemWidget = CreateItemWidget
ToolbarBinding.RefreshInteractionModeControls = RefreshInteractionModeControls
ToolbarBinding.RefreshWindowState = RefreshWindowState
ToolbarBinding.WireCallbacks = WireCallbacks
ToolbarBinding.IsExpertMode = IsExpertMode

return ToolbarBinding
