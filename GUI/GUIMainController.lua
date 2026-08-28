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
        if editorState and editorState.SetPrimaryUnit then
            editorState.SetPrimaryUnit(unitKey)
        elseif editorState and editorState.SetSelectedUnit then
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
        if normalizedPath == (FocalPoint.Constants and FocalPoint.Constants.Nav and FocalPoint.Constants.Nav.EDITOR)
            and FocalPoint.SetFrameLockEnabled
        then
            FocalPoint:SetFrameLockEnabled(true, {
                reason = "editor-navigate",
                silent = true,
            })
        end
        if FocalPoint.GUI and FocalPoint.GUI.RequestRefreshOptions then
            FocalPoint.GUI:RequestRefreshOptions("Navigation.Sidebar")
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
                        FocalPoint.GUI:RequestRefreshOptions("Toolbar.UnitChangedFallback")
                    end
                end
            end,
            onObjectSelectionChanged = function(changeKind)
                local controller = FocalPoint.GUI
                    and FocalPoint.GUI.Editor
                    and FocalPoint.GUI.Editor.Controller
                    or nil
                if changeKind == "sameUnitObject"
                    and controller
                    and type(controller.RefreshActiveProperties) == "function"
                    and controller.RefreshActiveProperties()
                then
                    return
                end
                if FocalPoint.GUI and FocalPoint.GUI.RequestRefreshOptions then
                    FocalPoint.GUI:RequestRefreshOptions("Toolbar.ObjectSelectionChanged")
                end
            end,
            onModeChanged = function(mode)
                local editorMode = FocalPoint.EditorMode or (FocalPoint.GUI and FocalPoint.GUI.Editor and FocalPoint.GUI.Editor.Mode)
                if editorMode and editorMode.Set then
                    editorMode.Set(EditorState.Get and EditorState.Get(), FocalPoint.db and FocalPoint.db.profile, mode)
                end
                if FocalPoint.GUI and FocalPoint.GUI.RequestRefreshOptions then
                    FocalPoint.GUI:RequestRefreshOptions("Toolbar.ModeChanged")
                end
            end,
            onThemeChanged = function(themeId)
                if EditorState.SetSelectedThemeId then
                    EditorState.SetSelectedThemeId(themeId)
                end
                if FocalPoint.GUI and FocalPoint.GUI.RequestRefreshOptions then
                    FocalPoint.GUI:RequestRefreshOptions("Toolbar.ThemeChanged")
                end
            end,
            onThemeApplied = function(themeId)
                if EditorState.SetSelectedThemeId then
                    EditorState.SetSelectedThemeId(themeId)
                end
                if FocalPoint.GUI and FocalPoint.GUI.RequestRefreshOptions then
                    FocalPoint.GUI:RequestRefreshOptions("Toolbar.ThemeApplied")
                end
            end,
            onGlobalChanged = function()
                if FocalPoint.GUI and FocalPoint.GUI.RequestRefreshOptions then
                    FocalPoint.GUI:RequestRefreshOptions("Toolbar.GlobalChanged")
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

function FocalPoint.GUI:RequestRefreshOptions(reason)
    local perf = FocalPoint and FocalPoint.SelectionPerfDebug
    if perf and perf.Count then
        perf:Count("RequestRefreshOptions")
        if perf.RecordRequestRefreshReason then
            perf:RecordRequestRefreshReason(reason)
        end
    end

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
    local perf = FocalPoint and FocalPoint.SelectionPerfDebug
    local perfStart = perf and perf.Begin and perf:Begin("RefreshOptions")

    local addon = FocalPoint

    if addon._closingConfig then
        if perf and perf.End then
            perf:End("RefreshOptions", perfStart)
        end
        return
    end

    if not addon.guiContentHost then
        if perf and perf.End then
            perf:End("RefreshOptions", perfStart)
        end
        return
    end

    if addon._refreshingOptions then
        addon._pendingRefreshOptions = true
        if perf and perf.End then
            perf:End("RefreshOptions", perfStart)
        end
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
    if perf and perf.End then
        perf:End("RefreshOptions", perfStart)
    end

    if addon._pendingRefreshOptions then
        self:RequestRefreshOptions("RefreshOptions.Reschedule")
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

local function EnsureEditorDesignPresenceForUnit(addon, unit)
    if not (addon and addon.framesUnlocked == true and addon.IsEditorActive and addon:IsEditorActive()) then
        return
    end
    if InCombatLockdown and InCombatLockdown() then
        return
    end
    if type(unit) ~= "string" or unit == "" then
        return
    end

    local utils = addon.UnitFrameUtils
    local configUnit = utils and utils.NormalizeConfigUnitKey and utils.NormalizeConfigUnitKey(unit) or unit
    if type(configUnit) ~= "string" or configUnit == "" then
        return
    end

    local unitConfig = utils and utils.GetUnitDB and utils.GetUnitDB(configUnit) or nil
    if type(unitConfig) ~= "table" then
        return
    end

    addon.frames = addon.frames or {}
    if configUnit == "boss" then
        for bossIndex = 1, 5 do
            local bossUnit = "boss" .. bossIndex
            if not addon.frames[bossUnit] and addon.SpawnUnitFrame then
                addon:SpawnUnitFrame(bossUnit, { allowDisabledForUnlock = true })
            elseif addon.RefreshUnitFrame then
                addon:RefreshUnitFrame(bossUnit)
            end
        end
        return
    end

    if not addon.frames[configUnit] and addon.SpawnUnitFrame then
        addon:SpawnUnitFrame(configUnit, { allowDisabledForUnlock = true })
    elseif addon.RefreshUnitFrame then
        addon:RefreshUnitFrame(configUnit)
    end
end

local function SelectUnitRootObject(unitKey)
    local objectSelection = FocalPoint.GUI and FocalPoint.GUI.Editor and FocalPoint.GUI.Editor.ObjectSelection or nil
    if objectSelection and type(objectSelection.SelectUnitRoot) == "function" then
        return objectSelection.SelectUnitRoot(unitKey) == true
    end

    if objectSelection and type(objectSelection.SelectObject) == "function" then
        return objectSelection.SelectObject({
            kind = "unit",
            unit = unitKey,
        }) == true
    end

    return false
end

function FocalPoint:SelectEditorUnit(unit, options)
    if type(unit) ~= "string" or unit == "" then
        return
    end

    local previousUnit = nil
    local previousUnits = {}
    local editorState = self.GUI and self.GUI.Editor and self.GUI.Editor.State
    if editorState and editorState.Get then
        local currentState = editorState.Get()
        previousUnit = currentState and currentState.selectedUnit or nil
        if editorState.GetSelectedUnits then
            previousUnits = editorState.GetSelectedUnits()
        elseif previousUnit then
            previousUnits = { previousUnit }
        end
    end

    local selectedUnit = unit
    if selectedUnit:match("^boss%d+$") then
        selectedUnit = "boss"
    end

    local toggleSelection = type(options) == "table" and options.toggle == true
    local preserveSelection = type(options) == "table" and options.preserveSelection == true
    if toggleSelection and editorState and editorState.ToggleUnitSelection then
        selectedUnit = editorState.ToggleUnitSelection(selectedUnit)
    elseif preserveSelection and editorState and editorState.SetPrimaryUnit then
        selectedUnit = editorState.SetPrimaryUnit(selectedUnit)
    elseif SelectUnitRootObject(selectedUnit) then
        if editorState and editorState.GetPrimaryUnit then
            selectedUnit = editorState.GetPrimaryUnit() or selectedUnit
        end
    elseif editorState and editorState.SetSingleSelection then
        -- Legacy fallback for early-load states where ObjectSelection is not available yet.
        selectedUnit = editorState.SetSingleSelection(selectedUnit)
    elseif editorState and editorState.SetSelectedUnit then
        editorState.SetSelectedUnit(selectedUnit)
    end

    if self.GUI then
        self.GUI.selectedPath = self.Constants.Nav.EDITOR
    end

    if self.guiTreeStatus then
        self.guiTreeStatus.selected = self.Constants.Nav.EDITOR
    end

    EnsureEditorDesignPresenceForUnit(self, selectedUnit)

    if self.GUI and self.GUI.RequestRefreshOptions then
        self.GUI:RequestRefreshOptions("Editor.SelectUnit")
    elseif self.RefreshEditorSelectionVisuals then
        self:RefreshEditorSelectionVisuals()
    end

    if (self.framesUnlocked or self.guiTestModeEnabled) and self.RefreshAllFrames then
        self:RefreshAllFrames()
    else
        local refreshUnits = {}
        for _, unitKey in ipairs(previousUnits) do
            if type(unitKey) == "string" and unitKey ~= "" then
                refreshUnits[unitKey] = true
            end
        end
        if previousUnit then
            refreshUnits[previousUnit] = true
        end
        if selectedUnit then
            refreshUnits[selectedUnit] = true
        end

        if self.RefreshUnitFrame then
            for unitKey in pairs(refreshUnits) do
                self:RefreshUnitFrame(unitKey)
            end
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
            FocalPoint.GUI:RequestRefreshOptions("GUI.ShowFrame")
        elseif FocalPoint.RefreshEditorSelectionVisuals then
            FocalPoint:RefreshEditorSelectionVisuals()
        end
        return
    end

    if widget.Show then
        widget:Show()
        if FocalPoint.GUI and FocalPoint.GUI.RequestRefreshOptions then
            FocalPoint.GUI:RequestRefreshOptions("GUI.ShowFrame")
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

    local unlockGrid = self.GUI
        and self.GUI.Editor
        and self.GUI.Editor.FrameUnlockGrid
    if unlockGrid and unlockGrid.Hide then
        unlockGrid.Hide()
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

    if self.SetFrameLockEnabled then
        self:SetFrameLockEnabled(false, {
            reason = "config-close-lock",
            silent = true,
        })
    end

    if self.RefreshEditorSelectionVisuals then
        self:RefreshEditorSelectionVisuals()
    end

    local profilesPage = self.GUI and self.GUI.Pages and self.GUI.Pages.Profiles
    if profilesPage and profilesPage.HideWindow then
        profilesPage.HideWindow()
    end

    local textBuilderPage = self.GUI and self.GUI.Pages and self.GUI.Pages.TextBuilder
    if textBuilderPage and textBuilderPage.HideWindow then
        textBuilderPage.HideWindow()
    end

    local layoutManager = self.GUI and self.GUI.Editor and self.GUI.Editor.LayoutManager
    if layoutManager and layoutManager.Close then
        layoutManager.Close()
    end

    local toolbar = self.GUI and self.GUI.Editor and self.GUI.Editor.Toolbar
    if toolbar and toolbar.Hide then
        toolbar.Hide()
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
            self.GUI:RequestRefreshOptions("GUI.TestEnvironmentChanged")
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
        if self.SetFrameLockEnabled then
            self:SetFrameLockEnabled(true, {
                reason = "editor-open",
                silent = true,
            })
        end
        return
    end

    self:CreateGUI()
    if self.SetFrameLockEnabled then
        self:SetFrameLockEnabled(true, {
            reason = "editor-open",
            silent = true,
        })
    end
end
