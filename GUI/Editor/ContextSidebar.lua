local _, ns = ...

ns.GUI = ns.GUI or {}
ns.GUI.Editor = ns.GUI.Editor or {}

local AceGUI = LibStub("AceGUI-3.0")
local ContextSidebar = {}
ns.GUI.Editor.ContextSidebar = ContextSidebar

local C = ns.Constants
local L = ns.L or {}
local Shared = ns.GUI.Editor.SidebarShared or {}

local AddSpacer = Shared.AddSpacer
local CreateSection = Shared.CreateSection
local StyleSidebarButton = Shared.StyleSidebarButton
local AddActiveSidebarItem = Shared.AddActiveSidebarItem
local CompactSidebarText = Shared.CompactSidebarText
local AddCheckBox = Shared.AddCheckBox
local AddDropdown = Shared.AddDropdown
local AddUnitSelector = Shared.AddUnitSelector
local BuildThemeList = Shared.BuildThemeList
local GetFirstThemeId = Shared.GetFirstThemeId

function ContextSidebar.Build(container, state, options)
    container:ReleaseChildren()
    container:SetLayout("Flow")

    local ThemeService = ns.ThemeService or {}
    local BuilderUI = ns.GUI and ns.GUI.Helpers and ns.GUI.Helpers.BuilderUI or {}
    local C = ns.Constants or {}
    local themes = ThemeService.GetThemes and ThemeService.GetThemes() or {}
    local themeList = BuildThemeList(themes)
    local customThemeId = ThemeService.GetCustomThemeId and ThemeService.GetCustomThemeId() or "__custom__"
    local activeThemeId = ns.db and ns.db.profile and ns.db.profile.General and ns.db.profile.General.ActiveThemeId
    local selectedThemeId = state.selectedThemeId
    local versionText = BuilderUI.GetAddonVersionText and BuilderUI.GetAddonVersionText() or "dev"
    local logoPath = "Interface\\AddOns\\FocalPoint\\Media\\Icon.tga"
    local generalConfig = ns.db and ns.db.profile and ns.db.profile.General
    local normalizedCurrent = options.currentPath or (ns.GUI and ns.GUI.selectedPath) or C.Nav.EDITOR
    local shellMode = options.shellMode or "tool"
    local showingToolPage = shellMode == "tool"

    if type(generalConfig) ~= "table" then
        return
    end

    if ThemeService.HasDefaultSnapshot and ThemeService.HasDefaultSnapshot() then
        themeList[customThemeId] = L["THEME_CUSTOM"] or "My Layout"
    end

    if not themeList[selectedThemeId] then
        selectedThemeId = activeThemeId
    end
    if not themeList[selectedThemeId] then
        selectedThemeId = GetFirstThemeId(themeList)
    end
    state.selectedThemeId = selectedThemeId
    state.mode = generalConfig.ExpertMode ~= false and "expert" or "quick"

    local brandGroup = AceGUI:Create("SimpleGroup")
    brandGroup:SetFullWidth(true)
    brandGroup:SetLayout("Flow")
    container:AddChild(brandGroup)

    local brandLine = AceGUI:Create("Label")
    brandLine:SetFullWidth(true)
    brandLine:SetText(string.format(
        "|T%s:24:24:0:0|t  |cff6fd2ff%s|r",
        logoPath,
        L["ADDON_NAME"] or C.ADDON_NAME or "FocalPoint"
    ))
    if brandLine.label and brandLine.label.SetFont then
        brandLine.label:SetFont(STANDARD_TEXT_FONT, 16, "")
        brandLine.label:SetShadowOffset(1, -1)
        brandLine.label:SetShadowColor(0, 0, 0, 0.75)
    end
    brandGroup:AddChild(brandLine)

    local versionLine = AceGUI:Create("Label")
    versionLine:SetFullWidth(true)
    versionLine:SetText(string.format(
        "|cffd8c27a%s|r  |cff4cff88%s|r",
        L["INFO_VERSION"] or "Version",
        versionText
    ))
    if versionLine.label and versionLine.label.SetFont then
        versionLine.label:SetFont(STANDARD_TEXT_FONT, 12, "")
        versionLine.label:SetShadowOffset(1, -1)
        versionLine.label:SetShadowColor(0, 0, 0, 0.75)
    end
    brandGroup:AddChild(versionLine)

    AddSpacer(container, 4)

    local toolsSection = CreateSection(container, L["EDITOR_CONTEXT_TOOLS"] or "Tools", { style = "muted" })

    for _, item in ipairs({
        { path = C.Nav.EDITOR, label = ns.GetLabel and ns.GetLabel(ns.KeyMap.Nav, C.Nav.EDITOR) or "Editor" },
        { path = C.Nav.PROFILES, label = ns.GetLabel and ns.GetLabel(ns.KeyMap.Nav, C.Nav.PROFILES) or "Profiles" },
        { path = C.Nav.TEXT_BUILDER, label = ns.GetLabel and ns.GetLabel(ns.KeyMap.Nav, C.Nav.TEXT_BUILDER) or "Text Builder" },
        { path = C.Nav.TAG_DATABASE, label = ns.GetLabel and ns.GetLabel(ns.KeyMap.Nav, C.Nav.TAG_DATABASE) or "Tag Database" },
    }) do
        if normalizedCurrent == item.path then
            AddActiveSidebarItem(toolsSection, item.label or item.path)
        else
            local button = AceGUI:Create("Button")
            button:SetFullWidth(true)
            button:SetText(item.label or item.path)
            StyleSidebarButton(button, "secondary")
            button:SetCallback("OnClick", function()
                if options.onNavigate then
                    options.onNavigate(item.path)
                end
            end)
            toolsSection:AddChild(button)
        end
    end

    if options.onClose then
        AddSpacer(toolsSection, 2)
        local closeButton = AceGUI:Create("Button")
        closeButton:SetFullWidth(true)
        closeButton:SetText(CLOSE or "Close")
        StyleSidebarButton(closeButton, "danger")
        closeButton:SetCallback("OnClick", function()
            options.onClose()
        end)
        toolsSection:AddChild(closeButton)
    end

    local function AddToolWorkspaceSection()
        local toolContext = CreateSection(container, L["EDITOR_CONTEXT_WORKSPACE"] or "Workspace", { style = "prominent" })

        local toolLabel = AceGUI:Create("Label")
        toolLabel:SetFullWidth(true)
        toolLabel:SetText(L["EDITOR_TOOL_CONTEXT_HINT"] or "Dieses Werkzeug arbeitet in der mittleren Werkzeugflaeche. Fuer Unit-Bearbeitung wechselst du zurueck in den Editor.")
        if toolLabel.label and toolLabel.label.SetFont then
            toolLabel.label:SetFont(STANDARD_TEXT_FONT, 11, "")
            toolLabel.label:SetTextColor(0.72, 0.75, 0.80, 1)
        end
        toolContext:AddChild(toolLabel)

        AddSpacer(toolContext, 2)

        local selectedUnitLabel = AceGUI:Create("Label")
        selectedUnitLabel:SetFullWidth(true)
        selectedUnitLabel:SetText(string.format(
            "%s: |cffE7C44A%s|r",
            L["EDITOR_UNIT"] or "Unit",
            ns.GetLabel and ns.GetLabel(ns.KeyMap.Units, state.selectedUnit or C.Units.PLAYER) or (state.selectedUnit or C.Units.PLAYER)
        ))
        if selectedUnitLabel.label and selectedUnitLabel.label.SetFont then
            selectedUnitLabel.label:SetFont(STANDARD_TEXT_FONT, 12, "")
            selectedUnitLabel.label:SetShadowOffset(1, -1)
            selectedUnitLabel.label:SetShadowColor(0, 0, 0, 0.75)
        end
        toolContext:AddChild(selectedUnitLabel)

        local returnButton = AceGUI:Create("Button")
        returnButton:SetFullWidth(true)
        returnButton:SetText(L["EDITOR_RETURN_TO_EDITOR"] or "Zurueck zum Editor")
        StyleSidebarButton(returnButton, "primary")
        returnButton:SetCallback("OnClick", function()
            if options.onNavigate then
                options.onNavigate(C.Nav.EDITOR)
            end
        end)
        toolContext:AddChild(returnButton)
    end

    local function AddEditorWorkspaceSection()
        local workspace = CreateSection(container, L["EDITOR_CONTEXT_WORKSPACE"] or "Workspace", { style = "prominent" })

        AddUnitSelector(workspace, state.selectedUnit, function(value)
            if options.onUnitChanged then
                options.onUnitChanged(value)
            end
        end)

        AddCheckBox(workspace, L["OPTION_EXPERT_MODE"] or "Expert Mode", generalConfig.ExpertMode ~= false, function(value)
            generalConfig.ExpertMode = value and true or false
            state.mode = generalConfig.ExpertMode and "expert" or "quick"
            if options.onModeChanged then
                options.onModeChanged(state.mode)
            end
        end)
    end

    local function AddEditorPreviewSection()
        local previewSection = CreateSection(container, L["EDITOR_CONTEXT_PREVIEW"] or "Editing", { style = "prominent" })

        local testButton = AceGUI:Create("Button")
        testButton:SetFullWidth(true)
        testButton:SetText((ns.guiTestModeEnabled and (L["GUI_TEST_STOP"] or "Stop Test")) or (L["GUI_TEST_START"] or "Test"))
        StyleSidebarButton(testButton, "primary")
        testButton:SetCallback("OnClick", function()
            if ns.ToggleTestMode then
                ns:ToggleTestMode()
                if options.onGlobalChanged then
                    options.onGlobalChanged()
                end
            end
        end)
        previewSection:AddChild(testButton)

        local unlockButton = AceGUI:Create("Button")
        unlockButton:SetFullWidth(true)
        unlockButton:SetText((ns.framesUnlocked and (L["GUI_UNLOCK_STOP"] or "Lock Frames")) or (L["GUI_UNLOCK_START"] or "Unlock Frames"))
        StyleSidebarButton(unlockButton, "primary")
        unlockButton:SetCallback("OnClick", function()
            if ns.ToggleFrameLock then
                ns:ToggleFrameLock()
                if options.onGlobalChanged then
                    options.onGlobalChanged()
                end
            end
        end)
        previewSection:AddChild(unlockButton)

        local previewHint = AceGUI:Create("Label")
        previewHint:SetFullWidth(true)
        previewHint:SetText(L["EDITOR_PREVIEW_INTERACTION_HINT"] or "")
        if previewHint.label and previewHint.label.SetFont then
            previewHint.label:SetFont(STANDARD_TEXT_FONT, 11, "")
            previewHint.label:SetTextColor(0.67, 0.71, 0.76, 1)
        end
        previewSection:AddChild(previewHint)
    end

    local function AddEditorPresetSection()
        if next(themeList) == nil then
            return
        end

        local presetSection = CreateSection(container, L["EDITOR_CONTEXT_PRESET"] or "Presets")

        local presetIntro = AceGUI:Create("Label")
        presetIntro:SetFullWidth(true)
        presetIntro:SetText(L["EDITOR_PRESET_CONTEXT_HINT"] or "")
        if presetIntro.label and presetIntro.label.SetFont then
            presetIntro.label:SetFont(STANDARD_TEXT_FONT, 11, "")
            presetIntro.label:SetTextColor(0.71, 0.74, 0.78, 1)
        end
        presetSection:AddChild(presetIntro)

        AddDropdown(presetSection, L["EDITOR_PRESET_SELECT"] or L["THEME_SELECT"] or "Select Preset", themeList, selectedThemeId, function(value)
            state.selectedThemeId = value
            if options.onThemeChanged then
                options.onThemeChanged(value)
            end
        end)

        local selectedTheme = themes[selectedThemeId]
        local themeInfo = AceGUI:Create("Label")
        themeInfo:SetFullWidth(true)
        local themeDescription = nil
        if selectedThemeId == customThemeId then
            themeDescription = L["THEME_CUSTOM_DESC"] or (L["INFO_GENERAL_THEMES_DESC"] or "")
        else
            themeDescription = (selectedTheme and selectedTheme.descriptionKey and L[selectedTheme.descriptionKey]) or (L["INFO_GENERAL_THEMES_DESC"] or "")
        end
        themeInfo:SetText(CompactSidebarText(themeDescription, 82))
        if themeInfo.label and themeInfo.label.SetFont then
            themeInfo.label:SetFont(STANDARD_TEXT_FONT, 11, "")
            themeInfo.label:SetTextColor(0.67, 0.70, 0.75, 1)
        end
        presetSection:AddChild(themeInfo)

        local applyButton = AceGUI:Create("Button")
        applyButton:SetText(L["THEME_APPLY"] or L["INFO_GENERAL_THEME_APPLY"] or "Apply Preset")
        applyButton:SetFullWidth(true)
        applyButton:SetDisabled(not selectedThemeId)
        StyleSidebarButton(applyButton, "secondary")
        applyButton:SetCallback("OnClick", function()
            if not selectedThemeId or not ThemeService.ApplyTheme then
                return
            end

            if selectedThemeId ~= customThemeId and ThemeService.HasDefaultSnapshot and ThemeService.CaptureDefaultSnapshot and not ThemeService.HasDefaultSnapshot() then
                ThemeService.CaptureDefaultSnapshot()
            end

            if selectedThemeId ~= customThemeId and ThemeService.CaptureRestoreSnapshot then
                ThemeService.CaptureRestoreSnapshot()
            end

            if ThemeService.ApplyTheme(selectedThemeId) then
                state.selectedThemeId = ns.db and ns.db.profile and ns.db.profile.General and ns.db.profile.General.ActiveThemeId or selectedThemeId
                if options.onThemeApplied then
                    options.onThemeApplied(state.selectedThemeId)
                end
            end
        end)
        presetSection:AddChild(applyButton)

        if ThemeService.CaptureDefaultSnapshot then
            AddSpacer(presetSection, 2)

            local saveCustomButton = AceGUI:Create("Button")
            saveCustomButton:SetText(L["EDITOR_PRESET_SAVE_CUSTOM"] or "Save Current Layout as My Layout")
            saveCustomButton:SetFullWidth(true)
            StyleSidebarButton(saveCustomButton, "ghost")
            saveCustomButton:SetCallback("OnClick", function()
                if ThemeService.CaptureDefaultSnapshot and ThemeService.CaptureDefaultSnapshot() then
                    if options.onThemeApplied then
                        options.onThemeApplied(state.selectedThemeId)
                    end
                end
            end)
            presetSection:AddChild(saveCustomButton)
        end

        if ThemeService.HasRestoreSnapshot and ThemeService.HasRestoreSnapshot() and ThemeService.RestoreSnapshot then
            AddSpacer(presetSection, 2)

            local restoreButton = AceGUI:Create("Button")
            restoreButton:SetText(L["EDITOR_PRESET_RESTORE"] or "Restore Previous Layout")
            restoreButton:SetFullWidth(true)
            StyleSidebarButton(restoreButton, "ghost")
            restoreButton:SetCallback("OnClick", function()
                if ThemeService.RestoreSnapshot and ThemeService.RestoreSnapshot() then
                    state.selectedThemeId = ns.db and ns.db.profile and ns.db.profile.General and ns.db.profile.General.ActiveThemeId or state.selectedThemeId
                    if options.onThemeApplied then
                        options.onThemeApplied(state.selectedThemeId)
                    end
                end
            end)
            presetSection:AddChild(restoreButton)

            local restoreHint = AceGUI:Create("Label")
            restoreHint:SetFullWidth(true)
            restoreHint:SetText(L["EDITOR_PRESET_RESTORE_HINT"] or "")
            if restoreHint.label and restoreHint.label.SetFont then
                restoreHint.label:SetFont(STANDARD_TEXT_FONT, 11, "")
                restoreHint.label:SetTextColor(0.67, 0.70, 0.75, 1)
            end
            presetSection:AddChild(restoreHint)
        end
    end

    local function AddGlobalSection(isToolLayout)
        local globalSection = CreateSection(container, L["EDITOR_CONTEXT_GLOBAL"] or "Addon", { style = "muted" })

        AddCheckBox(globalSection, L["OPTION_HIDE_BLIZZARD_FRAMES"] or "Hide Blizzard Frames", generalConfig.HideBlizzardFrames == true, function(value)
            generalConfig.HideBlizzardFrames = value and true or false

            if ns.ApplyGeneralSettings then
                ns:ApplyGeneralSettings()
            end

            if not generalConfig.HideBlizzardFrames and ns.Info then
                ns:Info(L["INFO_RELOAD_REQUIRED_BLIZZARD_FRAMES"])
            end

            if options.onGlobalChanged then
                options.onGlobalChanged()
            end
        end)

        if not isToolLayout and generalConfig.ExpertMode ~= false then
            AddCheckBox(globalSection, L["OPTION_MOUSE_ENABLED"] or "Mouse Enabled", generalConfig.MouseEnabled ~= false, function(value)
                generalConfig.MouseEnabled = value and true or false

                if ns.RefreshAllUnitFrames then
                    ns:RefreshAllUnitFrames()
                end

                if options.onGlobalChanged then
                    options.onGlobalChanged()
                end
            end)

            AddCheckBox(globalSection, L["OPTION_GLOBAL_CLICKTHROUGH"] or "Global Click Through", generalConfig.GlobalClickThrough == true, function(value)
                generalConfig.GlobalClickThrough = value and true or false

                if ns.RefreshAllUnitFrames then
                    ns:RefreshAllUnitFrames()
                end

                if options.onGlobalChanged then
                    options.onGlobalChanged()
                end
            end)
        end
    end

    local function AddFooterNote(text)
        AddSpacer(container, 2)

        local info = AceGUI:Create("Label")
        info:SetFullWidth(true)
        info:SetText(text or "")
        if info.label and info.label.SetFont then
            info.label:SetFont(STANDARD_TEXT_FONT, 11, "")
            info.label:SetTextColor(0.55, 0.58, 0.63, 1)
        end
        container:AddChild(info)
    end

    if showingToolPage then
        AddToolWorkspaceSection()
        AddGlobalSection(true)
        AddFooterNote(L["EDITOR_PREVIEW_NOTE"] or "")
    else
        AddEditorWorkspaceSection()
        AddEditorPreviewSection()
        AddEditorPresetSection()
        AddGlobalSection(false)
        AddFooterNote(L["EDITOR_PREVIEW_NOTE"] or "")
    end
end


return ContextSidebar
