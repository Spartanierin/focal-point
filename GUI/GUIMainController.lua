local _, FocalPoint = ...

local AceGUI = LibStub("AceGUI-3.0")
local L = FocalPoint.L

FocalPoint.GUI = FocalPoint.GUI or {}

local ShowGUIFrame
local HideGUIFrame

local function GetMainHostWidget(addon)
    if not addon then
        return nil
    end

    return addon.guiMainHost
end

local function GetMainHostFrame(addon)
    local widget = GetMainHostWidget(addon)
    if not widget then
        return nil
    end

    return widget.frame or widget
end

local function IsMainHostVisible(addon)
    local frame = GetMainHostFrame(addon)
    if not frame then
        return false
    end

    if frame.IsShown then
        return frame:IsShown()
    end

    return true
end

local function GetReadyStatusText()
    return (L and L["GUI_STATUS_READY"]) or "Ready"
end

function FocalPoint.GUI:SetStatusText(message)
    local host = GetMainHostWidget(FocalPoint)
    if host and host.SetStatusText then
        host:SetStatusText(message or GetReadyStatusText())
    end
end

function FocalPoint.GUI:ResetStatusText()
    self:SetStatusText(GetReadyStatusText())
end

local function ResolveDefaultGUIPath(path)
    local unitKey = type(path) == "string" and string.match(path, "^units%.([^.]+)$") or nil
    if unitKey then
        local editorState = FocalPoint.GUI and FocalPoint.GUI.Editor and FocalPoint.GUI.Editor.State
        if editorState and editorState.SetSelectedUnit then
            editorState.SetSelectedUnit(unitKey)
        end
        return FocalPoint.Constants.Nav.EDITOR
    end

    if path == "units" then
        return FocalPoint.Constants.Nav.EDITOR
    end

    if path == nil or path == "" or path == "general" or path == FocalPoint.Constants.Nav.THEMES then
        return FocalPoint.Constants.Nav.EDITOR
    end

    return path
end

FocalPoint.GUI.selectedPath = ResolveDefaultGUIPath(FocalPoint.GUI.selectedPath)

local function ArrangeFrameFooter(frame, testButton)
    if not frame or not frame.statustext then
        return
    end

    local statusText = frame.statustext
    local statusBg = statusText:GetParent()
    local rootFrame = frame.frame or (statusBg and statusBg:GetParent())
    local closeButton = frame.closebutton

    if not statusBg or not rootFrame then
        return
    end

    if not closeButton and rootFrame.GetChildren then
        for _, child in ipairs({ rootFrame:GetChildren() }) do
            if child
                and child.GetObjectType
                and child:GetObjectType() == "Button"
                and child.GetText
                and child:GetText() == CLOSE
            then
                closeButton = child
                break
            end
        end
    end

    if testButton then
        testButton:Hide()
    end

    if closeButton then
        closeButton:SetParent(rootFrame)
        closeButton:ClearAllPoints()
        closeButton:SetPoint("TOPRIGHT", rootFrame, "TOPRIGHT", -8, -6)
    end

    statusBg:Hide()
    statusText:Hide()
end

local function HideWindowCloseButton(frameWidget)
    if not frameWidget then
        return
    end

    local rootFrame = frameWidget.frame or frameWidget
    local closeButton = frameWidget.closebutton

    if (not closeButton) and rootFrame and rootFrame.GetChildren then
        for _, child in ipairs({ rootFrame:GetChildren() }) do
            if child
                and child.GetObjectType
                and child:GetObjectType() == "Button"
                and child.GetText
                and child:GetText() == CLOSE
            then
                closeButton = child
                break
            end
        end
    end

    if not closeButton then
        return
    end

    if closeButton.Hide then
        closeButton:Hide()
    end
    if closeButton.EnableMouse then
        closeButton:EnableMouse(false)
    end
    if closeButton.SetScript then
        closeButton:SetScript("OnClick", nil)
    end
end

local function CreateWelcomeSpacer(height)
    local spacer = AceGUI:Create("SimpleGroup")
    spacer:SetFullWidth(true)
    spacer:SetAutoAdjustHeight(false)
    spacer:SetHeight(height or 10)
    return spacer
end

local function ShouldShowEditorWelcomeTip()
    local general = FocalPoint.db and FocalPoint.db.profile and FocalPoint.db.profile.General
    return type(general) == "table" and general.HideEditorWelcomeTip ~= true
end

local function SetEditorWelcomeTipHidden(hidden)
    local general = FocalPoint.db and FocalPoint.db.profile and FocalPoint.db.profile.General
    if type(general) == "table" then
        general.HideEditorWelcomeTip = hidden and true or false
    end
end

local function HideEditorWelcomeTip()
    local tipWindow = FocalPoint.guiEditorWelcomeTip
    if not tipWindow then
        return
    end

    FocalPoint.guiEditorWelcomeTip = nil
    if tipWindow.Release then
        tipWindow:Release()
    elseif tipWindow.frame and tipWindow.frame.Hide then
        tipWindow.frame:Hide()
    end
end

local function ShowEditorWelcomeTip()
    if not ShouldShowEditorWelcomeTip() then
        return
    end

    local existing = FocalPoint.guiEditorWelcomeTip
    if existing then
        ShowGUIFrame(existing)
        return
    end

    local FormWidgets = FocalPoint.GUI and FocalPoint.GUI.Helpers and FocalPoint.GUI.Helpers.FormWidgets
    local FormSectionSurfaceRenderer = FocalPoint.GUI and FocalPoint.GUI.Helpers and FocalPoint.GUI.Helpers.FormSectionSurfaceRenderer
    local headingText = (L and L["EDITOR_WELCOME_HEADING"]) or "Welcome to Focal Point"
    local introText = (L and L["EDITOR_WELCOME_INTRO"]) or "Focal Point works as an editor for your unit frames."
    local stepsTitleText = (L and L["EDITOR_WELCOME_STEPS_TITLE"]) or "How to start:"
    local stepsText = (L and L["EDITOR_WELCOME_STEPS"]) or "1. Click Unlock Frames on the left\n2. Pick a tool on the left like Profiles, Text Builder, or Tag Database\n3. Edit the currently selected unit on the right"
    local noteText = (L and L["EDITOR_WELCOME_NOTE"]) or "Unlock Frames makes unit frames visible and movable."
    local WELCOME_GAP_COMPACT = 8
    local WELCOME_GAP_REGULAR = 12
    local WELCOME_GAP_SECTION = 16

    local tipWindow = AceGUI:Create("Window")
    tipWindow:SetTitle((L and L["EDITOR_WELCOME_TITLE"]) or "Quick Start")
    tipWindow:SetLayout("List")
    tipWindow:SetWidth(600)
    tipWindow:SetHeight(470)
    tipWindow:EnableResize(false)
    tipWindow:SetStatusText("")

    if tipWindow.frame then
        tipWindow.frame:SetFrameStrata("DIALOG")
        tipWindow.frame:SetClampedToScreen(true)
    end

    if FormWidgets and FormWidgets.ApplyWindowChrome then
        FormWidgets.ApplyWindowChrome(tipWindow)
    end
    ArrangeFrameFooter(tipWindow, nil)
    HideWindowCloseButton(tipWindow)

    if tipWindow.frame then
        local fallbackPalette = FocalPoint.GUI
            and FocalPoint.GUI.Layouts
            and FocalPoint.GUI.Layouts.FormElements
            and FocalPoint.GUI.Layouts.FormElements.Palette
        local skins = FocalPoint.GUI and FocalPoint.GUI.Skins or nil
        local palette = skins and skins.GetFormPalette and skins.GetFormPalette(fallbackPalette) or fallbackPalette
        local chromePalette = palette and palette.Chrome
        local welcomeAccent = chromePalette and (chromePalette.headerAccent or chromePalette.accent)
        if not tipWindow.frame._fpWelcomeModalAccent then
            tipWindow.frame._fpWelcomeModalAccent = tipWindow.frame:CreateTexture(nil, "BORDER")
            tipWindow.frame._fpWelcomeModalAccent:SetPoint("TOPLEFT", tipWindow.frame, "TOPLEFT", 14, -32)
            tipWindow.frame._fpWelcomeModalAccent:SetPoint("TOPRIGHT", tipWindow.frame, "TOPRIGHT", -14, -32)
            tipWindow.frame._fpWelcomeModalAccent:SetHeight(2)
        end
        if welcomeAccent then
            tipWindow.frame._fpWelcomeModalAccent:SetColorTexture(unpack(welcomeAccent))
            tipWindow.frame._fpWelcomeModalAccent:Show()
        end
    end

    local content = AceGUI:Create("SimpleGroup")
    content:SetFullWidth(true)
    content:SetFullHeight(true)
    content:SetLayout("List")
    if FormSectionSurfaceRenderer and FormSectionSurfaceRenderer.ApplySectionPadding then
        FormSectionSurfaceRenderer.ApplySectionPadding(content, {
            left = 26,
            right = 26,
            top = 26,
            bottom = 22,
        })
    end
    tipWindow:AddChild(content)

    local heading
    if FormWidgets and FormWidgets.CreateBodyText then
        heading = FormWidgets.CreateBodyText(headingText, "sectionHeader", 18, nil, nil, true)
    else
        heading = AceGUI:Create("Label")
        heading:SetFullWidth(true)
        heading:SetText(headingText)
    end
    content:AddChild(heading)
    content:AddChild(CreateWelcomeSpacer(WELCOME_GAP_REGULAR))

    local intro
    if FormWidgets and FormWidgets.CreateBodyText then
        intro = FormWidgets.CreateBodyText(introText, "description", 13, nil, nil, true)
    else
        intro = AceGUI:Create("Label")
        intro:SetFullWidth(true)
        intro:SetText(introText)
    end
    content:AddChild(intro)
    content:AddChild(CreateWelcomeSpacer(WELCOME_GAP_SECTION))

    local stepsTitle
    if FormWidgets and FormWidgets.CreateBodyText then
        stepsTitle = FormWidgets.CreateBodyText(stepsTitleText, "sectionHeader", 14, nil, nil, true)
    else
        stepsTitle = AceGUI:Create("Label")
        stepsTitle:SetFullWidth(true)
        stepsTitle:SetText(stepsTitleText)
    end
    content:AddChild(stepsTitle)
    content:AddChild(CreateWelcomeSpacer(WELCOME_GAP_COMPACT))

    local steps
    if FormWidgets and FormWidgets.CreateBodyText then
        steps = FormWidgets.CreateBodyText(stepsText, "description", 12, nil, nil, true)
    else
        steps = AceGUI:Create("Label")
        steps:SetFullWidth(true)
        steps:SetText(stepsText)
    end
    content:AddChild(steps)
    content:AddChild(CreateWelcomeSpacer(WELCOME_GAP_SECTION))

    local note
    if FormWidgets and FormWidgets.CreateBodyText then
        note = FormWidgets.CreateBodyText(noteText, "description", 11, nil, nil, true)
    else
        note = AceGUI:Create("Label")
        note:SetFullWidth(true)
        note:SetText(noteText)
    end
    content:AddChild(note)
    content:AddChild(CreateWelcomeSpacer(WELCOME_GAP_REGULAR))

    local hideCheckbox = AceGUI:Create("CheckBox")
    hideCheckbox:SetFullWidth(true)
    hideCheckbox:SetLabel((L and L["EDITOR_WELCOME_DO_NOT_SHOW"]) or "Do not show this tip again")
    hideCheckbox:SetValue(false)
    if FormWidgets and FormWidgets.StyleCheckBox then
        FormWidgets.StyleCheckBox(hideCheckbox, false)
    end
    content:AddChild(hideCheckbox)
    content:AddChild(CreateWelcomeSpacer(WELCOME_GAP_REGULAR))

    local confirmButton
    if FormWidgets and FormWidgets.CreateActionButton then
        confirmButton = FormWidgets.CreateActionButton((L and L["EDITOR_WELCOME_CONFIRM"]) or "Got it", "primary_action", nil, true)
        if FormWidgets.ApplyModalActionButtonVisual then
            FormWidgets.ApplyModalActionButtonVisual(confirmButton, "primary_action")
        end
    else
        confirmButton = AceGUI:Create("Button")
        confirmButton:SetText((L and L["EDITOR_WELCOME_CONFIRM"]) or "Got it")
        confirmButton:SetFullWidth(true)
    end
    content:AddChild(confirmButton)

    local function CloseTip()
        SetEditorWelcomeTipHidden(hideCheckbox.GetValue and hideCheckbox:GetValue())
        HideEditorWelcomeTip()
    end

    confirmButton:SetCallback("OnClick", CloseTip)
    tipWindow:SetCallback("OnClose", CloseTip)

    FocalPoint.guiEditorWelcomeTip = tipWindow
end

local C = FocalPoint.Constants

local function RenderPage(container, path)
    local OptionRefresh = FocalPoint.GUI.Helpers.OptionRefresh
    local EditorController = FocalPoint.GUI and FocalPoint.GUI.Editor and FocalPoint.GUI.Editor.Controller
    local AppShell = FocalPoint.GUI and FocalPoint.GUI.AppShell
    local shellMode = (AppShell and AppShell.ResolveShellMode and AppShell.ResolveShellMode(FocalPoint, path)) or "tool"

    local function RenderInShellMode(targetMode, buildFunc)
        local mode = targetMode or shellMode
        if AppShell and AppShell.RenderMainContent then
            AppShell.RenderMainContent(container, mode, buildFunc)
            return
        end

        if container and container.ReleaseChildren then
            container:ReleaseChildren()
        end
        if container and container.SetLayout then
            container:SetLayout("Fill")
        end
        if type(buildFunc) == "function" then
            buildFunc(container)
        end
    end

    if OptionRefresh and OptionRefresh.ClearStateWidgets then
        OptionRefresh.ClearStateWidgets()
    end

    if shellMode ~= "editor" and EditorController and EditorController.ReleaseInspector then
        EditorController.ReleaseInspector()
    end

    if path == C.Nav.EDITOR then
        RenderInShellMode("editor", function(content)
            FocalPoint.GUIController.BuildEditorPage(content)
        end)
        return
    end

    RenderInShellMode(shellMode, function(content)
        FocalPoint.GUIController.BuildPlaceholderPage(content, path or "Unknown")
    end)
end

    local function BuildAppSidebar(container)
local Toolbar = FocalPoint.GUI and FocalPoint.GUI.Editor and FocalPoint.GUI.Editor.Toolbar
        local EditorState = FocalPoint.GUI and FocalPoint.GUI.Editor and FocalPoint.GUI.Editor.State
        local AppShell = FocalPoint.GUI and FocalPoint.GUI.AppShell
        if not EditorState or not EditorState.Get then
            return
        end

    local function HandleSidebarNavigate(path)
        if path == (FocalPoint.Constants and FocalPoint.Constants.Nav and FocalPoint.Constants.Nav.PROFILES) then
            if FocalPoint.GUIController and FocalPoint.GUIController.OpenProfilesWindow then
                FocalPoint.GUIController.OpenProfilesWindow()
            end
            return
        end

        if path == (FocalPoint.Constants and FocalPoint.Constants.Nav and FocalPoint.Constants.Nav.TAG_DATABASE) then
            if FocalPoint.GUIController and FocalPoint.GUIController.OpenTagDatabaseWindow then
                FocalPoint.GUIController.OpenTagDatabaseWindow()
            end
            return
        end

        if path == (FocalPoint.Constants and FocalPoint.Constants.Nav and FocalPoint.Constants.Nav.TEXT_BUILDER) then
            if FocalPoint.GUIController and FocalPoint.GUIController.OpenTextBuilderWindow then
                FocalPoint.GUIController.OpenTextBuilderWindow()
            end
            return
        end

        local normalizedPath = ResolveDefaultGUIPath(path)
        FocalPoint.GUI.selectedPath = normalizedPath
        if FocalPoint.guiTreeStatus then
            FocalPoint.guiTreeStatus.selected = normalizedPath
        end
        if FocalPoint.GUI and FocalPoint.GUI.RequestRefreshOptions then
            FocalPoint.GUI:RequestRefreshOptions()
        end
    end

    local selectedPath = ResolveDefaultGUIPath(FocalPoint.GUI and FocalPoint.GUI.selectedPath)
    local targetContainer = (AppShell and AppShell.GetSidebarBuildHost and AppShell.GetSidebarBuildHost(FocalPoint)) or container
    if not targetContainer then
        return
    end
    if targetContainer ~= container and container and container.ReleaseChildren then
        container._focalPointSidebarLayout = nil
        container:ReleaseChildren()
    end
    if targetContainer and targetContainer.ReleaseChildren then
        targetContainer._focalPointSidebarLayout = nil
        targetContainer:ReleaseChildren()
    end
    if Toolbar and Toolbar.Open then
        Toolbar.Open(EditorState.Get(), {
            currentPath = selectedPath,
            onNavigate = HandleSidebarNavigate,
            onUnitChanged = function(unitKey)
                if FocalPoint.SelectEditorUnit then
                    FocalPoint:SelectEditorUnit(unitKey)
                elseif EditorState.SetSelectedUnit then
                    EditorState.SetSelectedUnit(unitKey)
                    if FocalPoint.GUI and FocalPoint.GUI.RequestRefreshOptions then
                        FocalPoint.GUI:RequestRefreshOptions()
                    end
                end
            end,
            onModeChanged = function(mode)
                if EditorState.SetMode then
                    EditorState.SetMode(mode)
                end
                local generalConfig = FocalPoint.db and FocalPoint.db.profile and FocalPoint.db.profile.General
                if type(generalConfig) == "table" then
                    generalConfig.ExpertMode = (mode == "expert")
                end
                if FocalPoint.GUI and FocalPoint.GUI.RequestRefreshOptions then
                    FocalPoint.GUI:RequestRefreshOptions()
                end
            end,
            onThemeChanged = function(themeId)
                if EditorState.SetSelectedThemeId then
                    EditorState.SetSelectedThemeId(themeId)
                end
                if FocalPoint.GUI and FocalPoint.GUI.RequestRefreshOptions then
                    FocalPoint.GUI:RequestRefreshOptions()
                end
            end,
            onThemeApplied = function(themeId)
                if EditorState.SetSelectedThemeId then
                    EditorState.SetSelectedThemeId(themeId)
                end
                if FocalPoint.GUI and FocalPoint.GUI.RequestRefreshOptions then
                    FocalPoint.GUI:RequestRefreshOptions()
                end
            end,
            onGlobalChanged = function()
                if FocalPoint.GUI and FocalPoint.GUI.RequestRefreshOptions then
                    FocalPoint.GUI:RequestRefreshOptions()
                end
            end,
            onClose = function()
                if FocalPoint.CloseConfig then
                    FocalPoint:CloseConfig()
                end
            end,
        })
    end
    return

end

local function UpdateAppShellGeometry()
    local shell = FocalPoint.GUI and FocalPoint.GUI.AppShell
    if shell and shell.UpdateGeometry then
        shell.UpdateGeometry(FocalPoint, ResolveDefaultGUIPath)
    end
end

local function StabilizeRenderedShell(expectedPath, refreshSerial)
    local addon = FocalPoint
    if not addon or addon._closingConfig then
        return
    end

    if refreshSerial and addon._guiRefreshSerial ~= refreshSerial then
        return
    end

    local currentPath = ResolveDefaultGUIPath(addon.GUI and addon.GUI.selectedPath)
    if expectedPath and currentPath ~= ResolveDefaultGUIPath(expectedPath) then
        return
    end

    local controller = addon.GUI and addon.GUI.Editor and addon.GUI.Editor.Controller
    if controller and controller.UpdateActiveInspectorGeometry then
        controller.UpdateActiveInspectorGeometry()
    end
end

function FocalPoint.GUI:RequestRefreshOptions()
    local addon = FocalPoint

    if addon._closingConfig then
        return
    end

    addon._pendingRefreshOptions = true

    if addon._refreshingOptions or addon._refreshOptionsScheduled then
        return
    end

    local function RunDeferredRefresh()
        addon._refreshOptionsScheduled = false

        if addon._closingConfig or not addon._pendingRefreshOptions then
            return
        end

        self:RefreshOptions()
    end

    if C_Timer and C_Timer.After then
        addon._refreshOptionsScheduled = true
        C_Timer.After(0, RunDeferredRefresh)
        return
    end

    RunDeferredRefresh()
end

function FocalPoint.GUI:RefreshOptions()
    local addon = FocalPoint

    if addon._closingConfig then
        return
    end

    if not addon.guiContentHost then
        return
    end

    if addon._refreshingOptions then
        addon._pendingRefreshOptions = true
        return
    end

    addon._refreshingOptions = true
    addon._pendingRefreshOptions = nil
    addon._guiRefreshSerial = (addon._guiRefreshSerial or 0) + 1

    local selectedPath = ResolveDefaultGUIPath(self.selectedPath)
    local refreshSerial = addon._guiRefreshSerial
    local ok, err = xpcall(function()
        UpdateAppShellGeometry()
        if addon.guiAppSidebar then
            BuildAppSidebar(addon.guiAppSidebar)
        end
        RenderPage(addon.guiContentHost, selectedPath)
        local textBuilderPage = addon.GUI and addon.GUI.Pages and addon.GUI.Pages.TextBuilder
        if textBuilderPage and textBuilderPage.RefreshWindowState then
            textBuilderPage.RefreshWindowState()
        end
        StabilizeRenderedShell(selectedPath, refreshSerial)

        if C_Timer and C_Timer.After then
            C_Timer.After(0, function()
                StabilizeRenderedShell(selectedPath, refreshSerial)
            end)
        end

        if addon.RefreshEditorSelectionVisuals then
            addon:RefreshEditorSelectionVisuals()
        end
    end, function(message)
        return tostring(message)
    end)

    addon._refreshingOptions = false

    if addon._pendingRefreshOptions then
        self:RequestRefreshOptions()
    end

    if not ok then
        error(err)
    end
end

function FocalPoint:IsEditorActive()
    local frame = GetMainHostFrame(self)
    if not frame then
        return false
    end

    if frame.IsShown and not frame:IsShown() then
        return false
    end

    return ResolveDefaultGUIPath(self.GUI and self.GUI.selectedPath) == self.Constants.Nav.EDITOR
end

function FocalPoint:SelectEditorUnit(unit)
    if type(unit) ~= "string" or unit == "" then
        return
    end

    local previousUnit = nil
    local editorState = self.GUI and self.GUI.Editor and self.GUI.Editor.State
    if editorState and editorState.Get then
        local currentState = editorState.Get()
        previousUnit = currentState and currentState.selectedUnit or nil
    end

    local selectedUnit = unit
    if selectedUnit:match("^boss%d+$") then
        selectedUnit = "boss"
    end

    if editorState and editorState.SetSelectedUnit then
        editorState.SetSelectedUnit(selectedUnit)
    end

    if self.GUI then
        self.GUI.selectedPath = self.Constants.Nav.EDITOR
    end

    if self.guiTreeStatus then
        self.guiTreeStatus.selected = self.Constants.Nav.EDITOR
    end

    if self.GUI and self.GUI.RequestRefreshOptions then
        self.GUI:RequestRefreshOptions()
    elseif self.RefreshEditorSelectionVisuals then
        self:RefreshEditorSelectionVisuals()
    end

    if (self.framesUnlocked or self.guiTestModeEnabled) and self.RefreshAllFrames then
        self:RefreshAllFrames()
    else
        if previousUnit and self.RefreshUnitFrame then
            self:RefreshUnitFrame(previousUnit)
        end
        if selectedUnit and self.RefreshUnitFrame then
            self:RefreshUnitFrame(selectedUnit)
        end
    end

    if self.RefreshEditorSelectionVisuals then
        self:RefreshEditorSelectionVisuals()
    end
end

ShowGUIFrame = function(widget)
    if not widget then
        return
    end

    if widget.frame and widget.frame.Show then
        widget.frame:Show()
        if FocalPoint.GUI and FocalPoint.GUI.RequestRefreshOptions then
            FocalPoint.GUI:RequestRefreshOptions()
        elseif FocalPoint.RefreshEditorSelectionVisuals then
            FocalPoint:RefreshEditorSelectionVisuals()
        end
        return
    end

    if widget.Show then
        widget:Show()
        if FocalPoint.GUI and FocalPoint.GUI.RequestRefreshOptions then
            FocalPoint.GUI:RequestRefreshOptions()
        elseif FocalPoint.RefreshEditorSelectionVisuals then
            FocalPoint:RefreshEditorSelectionVisuals()
        end
    end
end

HideGUIFrame = function(widget)
    if not widget then
        return
    end

    if widget.frame and widget.frame.Hide then
        widget.frame:Hide()
        if FocalPoint.RefreshEditorSelectionVisuals then
            FocalPoint:RefreshEditorSelectionVisuals()
        end
        return
    end

    if widget.Hide then
        widget:Hide()
        if FocalPoint.RefreshEditorSelectionVisuals then
            FocalPoint:RefreshEditorSelectionVisuals()
        end
    end
end

function FocalPoint:CloseConfig()
    if self._closingConfig then
        return
    end

    self._closingConfig = true

    local contextMenu = self.GUI
        and self.GUI.Editor
        and self.GUI.Editor.FrameContextMenu
    if contextMenu and contextMenu.Hide then
        contextMenu.Hide()
    end

    local resizeHandles = self.GUI
        and self.GUI.Editor
        and self.GUI.Editor.FrameResizeHandles
    if resizeHandles and resizeHandles.CancelAll then
        resizeHandles.CancelAll()
    end

    local snapLines = self.GUI
        and self.GUI.Editor
        and self.GUI.Editor.FrameSnapLines
    if snapLines and snapLines.Hide then
        snapLines.Hide()
    end

    local controller = self.GUI and self.GUI.Editor and self.GUI.Editor.Controller
    if controller and controller.ReleaseInspector then
        controller.ReleaseInspector()
    end

    local shell = self.GUI and self.GUI.AppShell
    if shell and shell.ClearEditorRuntimeRoles then
        shell.ClearEditorRuntimeRoles(self)
    end

    if self.guiTestModeEnabled and self.DisableTestMode then
        self:DisableTestMode()
    end

    if self.framesUnlocked then
        self.framesUnlocked = false
        local demo = self.UnitFrameDemoEnvironment or nil
        if demo and demo.ExitTestMode then
            demo.ExitTestMode("config-close-lock")
        end
        if self.ClearAllMoveOverlays then
            self:ClearAllMoveOverlays()
        end
        if self.UpdateAllFrameDragStates then
            self:UpdateAllFrameDragStates()
        end
        if self.RefreshAllFrames then
            self:RefreshAllFrames()
        elseif self.RefreshAllUnitFrames then
            self:RefreshAllUnitFrames()
        end
    end

    if self.RefreshEditorSelectionVisuals then
        self:RefreshEditorSelectionVisuals()
    end

    local profilesPage = self.GUI and self.GUI.Pages and self.GUI.Pages.Profiles
    if profilesPage and profilesPage.HideWindow then
        profilesPage.HideWindow()
    end

    local tagDatabasePage = self.GUI and self.GUI.Pages and self.GUI.Pages.TagDatabase
    if tagDatabasePage and tagDatabasePage.HideWindow then
        tagDatabasePage.HideWindow()
    end

    local textBuilderPage = self.GUI and self.GUI.Pages and self.GUI.Pages.TextBuilder
    if textBuilderPage and textBuilderPage.HideWindow then
        textBuilderPage.HideWindow()
    end

    local toolbar = self.GUI and self.GUI.Editor and self.GUI.Editor.Toolbar
    if toolbar and toolbar.Hide then
        toolbar.Hide()
    end

    HideEditorWelcomeTip()

    if self.RefreshAllUnitFrames then
        self:RefreshAllUnitFrames()
    end

    local hostWidget = GetMainHostWidget(self)
    if hostWidget then
        HideGUIFrame(hostWidget)
    end

    self._closingConfig = false
end

local function CreateMainHostWidget()
    local hostWidget = AceGUI:Create("Frame")
    hostWidget:SetTitle("Focal Point")
    hostWidget:SetStatusText(GetReadyStatusText())
    hostWidget:SetLayout("Fill")
    hostWidget:SetWidth(1220)
    hostWidget:SetHeight(760)
    hostWidget:EnableResize(true)

    return hostWidget
end

function FocalPoint:CreateGUI()
    if self._creatingGUI then
        return
    end

    local existingHost = GetMainHostWidget(self)
    if existingHost then
        ShowGUIFrame(existingHost)
        return
    end

    self._creatingGUI = true

    local hostWidget = CreateMainHostWidget()

    function self:SetTestModeEnabled(enabled)
        local wasEnabled = self.guiTestModeEnabled == true
        self.guiTestModeEnabled = enabled and true or false

        if self.GUI and self.GUI.SetStatusText then
            self.GUI:SetStatusText(self.guiTestModeEnabled and ((L and L["GUI_TEST_ACTIVE"]) or "Test mode active") or GetReadyStatusText())
        end

        if wasEnabled and not self.guiTestModeEnabled then
            local demo = FocalPoint and FocalPoint.UnitFrameDemoEnvironment or nil
            if demo and demo.ExitTestMode then
                demo.ExitTestMode("gui-toggle-off")
            end
        end
    end

    function self:DisableTestMode()
        if not self.guiTestModeEnabled then
            return
        end

        self:SetTestModeEnabled(false)
        FocalPoint._suppressMissingUnitUntil = (GetTime and (GetTime() + 1.0)) or 0

        if self.TestEnvironment then
            if self.TestEnvironment.Disable then
                self.TestEnvironment:Disable()
            elseif self.TestEnvironment.SetEnabled then
                self.TestEnvironment:SetEnabled(false)
            elseif self.TestEnvironment.Toggle then
                self.TestEnvironment:Toggle(false)
            elseif self.TestEnvironment.Refresh then
                self.TestEnvironment:Refresh()
            end
        end

        if FocalPoint.RefreshAllUnitFrames then
            FocalPoint:RefreshAllUnitFrames()
        end
    end

    function self:ToggleTestMode()
        local enabled = not self.guiTestModeEnabled
        self:SetTestModeEnabled(enabled)

        if enabled and FocalPoint.EnsureBossFrames then
            FocalPoint:EnsureBossFrames()
        end

        if self.TestEnvironment then
            if enabled and self.TestEnvironment.Enable then
                self.TestEnvironment:Enable()
            elseif (not enabled) and self.TestEnvironment.Disable then
                self.TestEnvironment:Disable()
            elseif self.TestEnvironment.SetEnabled then
                self.TestEnvironment:SetEnabled(enabled)
            elseif self.TestEnvironment.Toggle then
                self.TestEnvironment:Toggle(enabled)
            elseif self.TestEnvironment.Refresh then
                self.TestEnvironment:Refresh()
            end
        end

        if FocalPoint.RefreshAllUnitFrames then
            FocalPoint:RefreshAllUnitFrames()
        end

        if self.GUI and self.GUI.RequestRefreshOptions then
            self.GUI:RequestRefreshOptions()
        end
    end

    hostWidget:SetCallback("OnClose", function()
        if self.CloseConfig then
            self:CloseConfig()
        end
    end)

    self.guiTreeStatus = self.guiTreeStatus or {
        groups = {},
        selected = ResolveDefaultGUIPath(self.GUI.selectedPath),
    }
    self.guiTreeStatus.selected = ResolveDefaultGUIPath(self.guiTreeStatus.selected)

    local shell = self.GUI and self.GUI.AppShell
    local root, appSidebar, contentHost
    if shell and shell.BuildRoot then
        root, appSidebar, contentHost = shell.BuildRoot(self, hostWidget)
    else
        self._creatingGUI = false
        return
    end

    self.guiMainHost = hostWidget
    self.guiRoot = root

    ArrangeFrameFooter(hostWidget, nil)

    local initialPath = ResolveDefaultGUIPath(self.GUI.selectedPath or self.guiTreeStatus.selected)
    self.GUI.selectedPath = initialPath
    UpdateAppShellGeometry()
    BuildAppSidebar(appSidebar)
    RenderPage(contentHost, initialPath)
    StabilizeRenderedShell(initialPath)

    if C_Timer and C_Timer.After then
        C_Timer.After(0, function()
            StabilizeRenderedShell(initialPath)
        end)
    end

    local function ReflowShellForDisplaySize()
        local widgetFrame = GetMainHostFrame(self)
        if not widgetFrame then
            return
        end
        if widgetFrame.IsShown and not widgetFrame:IsShown() then
            return
        end

        UpdateAppShellGeometry()
        if self.guiRoot and self.guiRoot.DoLayout then
            self.guiRoot:DoLayout()
        end

        local shell = self.GUI and self.GUI.AppShell
        if shell and shell.LayoutEditorToolbarHost then
            shell.LayoutEditorToolbarHost(self)
        end

        local controller = self.GUI and self.GUI.Editor and self.GUI.Editor.Controller
        if controller and controller.UpdateActiveInspectorGeometry then
            controller.UpdateActiveInspectorGeometry()
        end
    end

    if not self.guiResizeWatcher then
        local watcher = CreateFrame("Frame")
        watcher:SetScript("OnEvent", function()
            ReflowShellForDisplaySize()
        end)
        watcher:RegisterEvent("DISPLAY_SIZE_CHANGED")
        watcher:RegisterEvent("UI_SCALE_CHANGED")
        self.guiResizeWatcher = watcher
    end

    local rootFrame = GetMainHostFrame(self)
    if rootFrame and rootFrame.HookScript and not rootFrame._focalPointResizeHooked then
        rootFrame:HookScript("OnSizeChanged", function()
            ReflowShellForDisplaySize()
        end)
        rootFrame._focalPointResizeHooked = true
    end

    self._creatingGUI = false
end

function FocalPoint:OpenConfig()
    local editorPath = self.Constants and self.Constants.Nav and self.Constants.Nav.EDITOR or "editor"
    local alreadyVisible = IsMainHostVisible(self)
    local currentPath = ResolveDefaultGUIPath(self.GUI and self.GUI.selectedPath)

    if self.GUI then
        self.GUI.selectedPath = editorPath
    end
    if self.guiTreeStatus then
        self.guiTreeStatus.selected = editorPath
    end

    if alreadyVisible and currentPath == editorPath and not self._creatingGUI then
        return
    end

    self:CreateGUI()
    ShowEditorWelcomeTip()
end
