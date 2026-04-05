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

local TREE_PATH_SEPARATOR = "\001"

local function NormalizeGroupValue(group)
    if type(group) ~= "string" then
        return group
    end

    if group:find(TREE_PATH_SEPARATOR, 1, true) then
        local lastValue
        for value in string.gmatch(group, "([^" .. TREE_PATH_SEPARATOR .. "]+)") do
            lastValue = value
        end
        return lastValue or group
    end

    return group
end

local C = FocalPoint.Constants

local function ParseUnitPath(path)
    local unitKey = string.match(path or "", "^units%.([^.]+)$")
    return unitKey
end

local function RenderToolContent(container, buildFunc)
    if type(buildFunc) == "function" then
        buildFunc(container)
    end
end

local function RenderPage(container, path)
    local OptionRefresh = FocalPoint.GUI.Helpers.OptionRefresh
    local EditorPage = FocalPoint.GUI and FocalPoint.GUI.Pages and FocalPoint.GUI.Pages.Editor
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

    if shellMode ~= "editor" and EditorPage and EditorPage.Release then
        EditorPage.Release()
    end

    if path == "general" then
        RenderInShellMode("editor", function(content)
            FocalPoint.GUIBuilders.BuildEditorPage(content)
        end)
        return
    end

    if path == C.Nav.EDITOR then
        RenderInShellMode("editor", function(content)
            FocalPoint.GUIBuilders.BuildEditorPage(content)
        end)
        return
    end

    if path == C.Nav.TAG_DATABASE then
        RenderInShellMode("tool", function(content)
            RenderToolContent(content, function(panel)
                FocalPoint.GUIBuilders.BuildTagDatabasePage(panel)
            end)
        end)
        return
    end

    if path == C.Nav.TEXT_BUILDER then
        RenderInShellMode("tool", function(content)
            RenderToolContent(content, function(panel)
                FocalPoint.GUIBuilders.BuildTextBuilderPage(panel)
            end)
        end)
        return
    end

    if path == C.Nav.THEMES then
        RenderInShellMode("editor", function(content)
            FocalPoint.GUIBuilders.BuildEditorPage(content)
        end)
        return
    end

    if path == "profiles" then
        RenderInShellMode("tool", function(content)
            RenderToolContent(content, function(panel)
                FocalPoint.GUIBuilders.BuildProfilesPage(panel)
            end)
        end)
        return
    end


    if path == "units" then
        RenderInShellMode("editor", function(content)
            FocalPoint.GUIBuilders.BuildEditorPage(content)
        end)
        return
    end

    local unitKey = ParseUnitPath(path)
    if unitKey then
        local editorState = FocalPoint.GUI.Editor and FocalPoint.GUI.Editor.State
        if editorState and editorState.SetSelectedUnit then
            editorState.SetSelectedUnit(unitKey)
        end

        RenderInShellMode("editor", function(content)
            FocalPoint.GUIBuilders.BuildEditorPage(content)
        end)
        return
    end

    RenderInShellMode(shellMode, function(content)
        FocalPoint.GUIBuilders.BuildPlaceholderPage(content, path or "Unknown")
    end)
end

local function BuildAppSidebar(container)
    local Sidebar = FocalPoint.GUI and FocalPoint.GUI.Editor and FocalPoint.GUI.Editor.ContextSidebar
    if not Sidebar or not Sidebar.Build then
        Sidebar = FocalPoint.GUI and FocalPoint.GUI.Editor and FocalPoint.GUI.Editor.Sidebar
    end
    local EditorState = FocalPoint.GUI and FocalPoint.GUI.Editor and FocalPoint.GUI.Editor.State
    local AppShell = FocalPoint.GUI and FocalPoint.GUI.AppShell
    if not Sidebar or not EditorState or not EditorState.Get then
        return
    end

    local selectedPath = ResolveDefaultGUIPath(FocalPoint.GUI and FocalPoint.GUI.selectedPath)
    local shellMode = (AppShell and AppShell.ResolveShellMode and AppShell.ResolveShellMode(FocalPoint, selectedPath)) or "tool"
    local targetContainer = (AppShell and AppShell.GetSidebarBuildHost and AppShell.GetSidebarBuildHost(FocalPoint)) or container
    if not targetContainer then
        return
    end
    if targetContainer ~= container and container and container.ReleaseChildren then
        container:ReleaseChildren()
    end

    Sidebar.Build(targetContainer, EditorState.Get(), {
        shellMode = shellMode,
        currentPath = selectedPath,
        onNavigate = function(path)
            if path == (FocalPoint.Constants and FocalPoint.Constants.Nav and FocalPoint.Constants.Nav.PROFILES) then
                if FocalPoint.GUIBuilders and FocalPoint.GUIBuilders.OpenProfilesWindow then
                    FocalPoint.GUIBuilders.OpenProfilesWindow()
                end
                return
            end

            if path == (FocalPoint.Constants and FocalPoint.Constants.Nav and FocalPoint.Constants.Nav.TAG_DATABASE) then
                if FocalPoint.GUIBuilders and FocalPoint.GUIBuilders.OpenTagDatabaseWindow then
                    FocalPoint.GUIBuilders.OpenTagDatabaseWindow()
                end
                return
            end

            if path == (FocalPoint.Constants and FocalPoint.Constants.Nav and FocalPoint.Constants.Nav.TEXT_BUILDER) then
                if FocalPoint.GUIBuilders and FocalPoint.GUIBuilders.OpenTextBuilderWindow then
                    FocalPoint.GUIBuilders.OpenTextBuilderWindow()
                end
                return
            end

            local normalizedPath = ResolveDefaultGUIPath(path)
            FocalPoint.GUI.selectedPath = normalizedPath
            if FocalPoint.guiTreeStatus then
                FocalPoint.guiTreeStatus.selected = normalizedPath
            end
            if FocalPoint.GUI and FocalPoint.GUI.RefreshOptions then
                FocalPoint.GUI:RefreshOptions()
            end
        end,
        onUnitChanged = function(unitKey)
            if EditorState.SetSelectedUnit then
                EditorState.SetSelectedUnit(unitKey)
            end
            if FocalPoint.GUI and FocalPoint.GUI.RefreshOptions then
                FocalPoint.GUI:RefreshOptions()
            end
        end,
        onModeChanged = function(mode)
            if EditorState.SetMode then
                EditorState.SetMode(mode)
            end
            if FocalPoint.GUI and FocalPoint.GUI.RefreshOptions then
                FocalPoint.GUI:RefreshOptions()
            end
        end,
        onThemeChanged = function(themeId)
            if EditorState.SetSelectedThemeId then
                EditorState.SetSelectedThemeId(themeId)
            end
            BuildAppSidebar(targetContainer)
        end,
        onThemeApplied = function(themeId)
            if EditorState.SetSelectedThemeId then
                EditorState.SetSelectedThemeId(themeId)
            end
            if FocalPoint.GUI and FocalPoint.GUI.RefreshOptions then
                FocalPoint.GUI:RefreshOptions()
            end
        end,
        onGlobalChanged = function()
            if FocalPoint.GUI and FocalPoint.GUI.RefreshOptions then
                FocalPoint.GUI:RefreshOptions()
            end
        end,
        onClose = function()
            if FocalPoint.CloseConfig then
                FocalPoint:CloseConfig()
            end
        end,
    })
end

local function UpdateAppShellGeometry()
    local shell = FocalPoint.GUI and FocalPoint.GUI.AppShell
    if shell and shell.UpdateGeometry then
        shell.UpdateGeometry(FocalPoint, ResolveDefaultGUIPath)
    end
end

local function StabilizeRenderedShell(expectedPath)
    local addon = FocalPoint
    if not addon or addon._closingConfig then
        return
    end

    local currentPath = ResolveDefaultGUIPath(addon.GUI and addon.GUI.selectedPath)
    if expectedPath and currentPath ~= ResolveDefaultGUIPath(expectedPath) then
        return
    end

    UpdateAppShellGeometry()

    if addon.guiRoot and addon.guiRoot.DoLayout then
        addon.guiRoot:DoLayout()
    end

    local controller = addon.GUI and addon.GUI.Editor and addon.GUI.Editor.Controller
    if controller and controller.UpdateActiveInspectorGeometry then
        controller.UpdateActiveInspectorGeometry()
    end
end

function FocalPoint.GUI:RefreshOptions()
    local addon = FocalPoint

    if addon._closingConfig then
        return
    end

    if not addon.guiContentHost then
        return
    end

    local selectedPath = ResolveDefaultGUIPath(self.selectedPath)
    UpdateAppShellGeometry()
    if addon.guiAppSidebar then
        BuildAppSidebar(addon.guiAppSidebar)
    end
    RenderPage(addon.guiContentHost, selectedPath)
    StabilizeRenderedShell(selectedPath)

    if C_Timer and C_Timer.After then
        C_Timer.After(0, function()
            StabilizeRenderedShell(selectedPath)
        end)
    end

    if addon.RefreshEditorSelectionVisuals then
        addon:RefreshEditorSelectionVisuals()
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

    if self.GUI and self.GUI.RefreshOptions then
        self.GUI:RefreshOptions()
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
        if FocalPoint.GUI and FocalPoint.GUI.RefreshOptions then
            FocalPoint.GUI:RefreshOptions()
        elseif FocalPoint.RefreshEditorSelectionVisuals then
            FocalPoint:RefreshEditorSelectionVisuals()
        end
        return
    end

    if widget.Show then
        widget:Show()
        if FocalPoint.GUI and FocalPoint.GUI.RefreshOptions then
            FocalPoint.GUI:RefreshOptions()
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
    local existingHost = GetMainHostWidget(self)
    if existingHost then
        ShowGUIFrame(existingHost)
        return
    end

    local hostWidget = CreateMainHostWidget()

    function self:SetTestModeEnabled(enabled)
        self.guiTestModeEnabled = enabled and true or false

        if self.GUI and self.GUI.SetStatusText then
            self.GUI:SetStatusText(self.guiTestModeEnabled and ((L and L["GUI_TEST_ACTIVE"]) or "Test mode active") or GetReadyStatusText())
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

        local visibility = FocalPoint and FocalPoint.UnitFrameVisibility
        local clearVisuals = visibility and visibility.ClearFrameVisualState
        local unitExists = UnitExists
        if clearVisuals and FocalPoint and FocalPoint.frames then
            for unit, frame in pairs(FocalPoint.frames) do
                if frame and unit ~= "player" then
                    clearVisuals(frame)

                    local hasLiveUnit = unitExists and unitExists(unit)

                    if not hasLiveUnit
                        and frame.SetAlpha
                    then
                        frame:SetAlpha(0)
                    end

                    if not hasLiveUnit
                        and frame.Hide
                        and not (InCombatLockdown and InCombatLockdown())
                    then
                        frame:Hide()
                    end
                end
            end
        end

        if FocalPoint and FocalPoint.frames and FocalPoint.RefreshUnitFrame then
            C_Timer.After(0, function()
                if not FocalPoint or not FocalPoint.frames or not FocalPoint.RefreshUnitFrame then
                    return
                end

                for unit in pairs(FocalPoint.frames) do
                    if unit == "player" or (unitExists and unitExists(unit)) then
                        FocalPoint:RefreshUnitFrame(unit)
                    end
                end
            end)
        elseif FocalPoint.RefreshAllUnitFrames then
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

        if self.GUI and self.GUI.RefreshOptions then
            self.GUI:RefreshOptions()
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
end

function FocalPoint:OpenConfig()
    if self.GUI then
        self.GUI.selectedPath = self.Constants and self.Constants.Nav and self.Constants.Nav.EDITOR or "editor"
    end
    if self.guiTreeStatus then
        self.guiTreeStatus.selected = self.Constants and self.Constants.Nav and self.Constants.Nav.EDITOR or "editor"
    end
    self:CreateGUI()
end
