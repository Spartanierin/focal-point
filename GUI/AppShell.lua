local _, ns = ...

ns.GUI = ns.GUI or {}

local AceGUI = LibStub("AceGUI-3.0")
local AppShell = {}
ns.GUI.AppShell = AppShell

local SHELL_SIDEBAR_REL_WIDTH = 0.235
local SHELL_CONTENT_REL_WIDTH = 0.755

local function GetMainHostWidget(addon)
    if not addon then
        return nil
    end

    return addon.guiMainHost
end

local function IsToolPath(addon, path)
    local nav = addon and addon.Constants and addon.Constants.Nav
    if not nav then
        return false
    end

    return path == nav.PROFILES
        or path == nav.TEXT_BUILDER
        or path == nav.TAG_DATABASE
end

function AppShell.ResolveShellMode(addon, path)
    local nav = addon and addon.Constants and addon.Constants.Nav
    if not nav then
        return "tool"
    end

    if path == nav.EDITOR then
        return "editor"
    end

    if IsToolPath(addon, path) then
        return "tool"
    end

    return "tool"
end

function AppShell.ResolveHostChromeMode(shellMode)
    if shellMode == "editor" then
        return "shell"
    end

    if shellMode == "tool" then
        return "window"
    end

    return "window"
end

function AppShell.PrepareContentHost(container, shellMode)
    if not container then
        return
    end

    container:ReleaseChildren()
    container:SetLayout("Fill")
    container._focalPointShellMode = shellMode or "tool"
end

function AppShell.RenderMainContent(container, shellMode, buildFunc)
    AppShell.PrepareContentHost(container, shellMode)
    if type(buildFunc) == "function" then
        buildFunc(container)
    end
end

local function EnsureEditorPresentationHost(addon)
    if not addon then
        return nil
    end

    local host = addon.guiEditorPresentationHost
    if host then
        return host
    end

    host = CreateFrame("Frame", nil, UIParent)
    host:SetAllPoints(UIParent)
    host:SetFrameStrata("BACKGROUND")
    host:EnableMouse(false)
    host:Hide()
    host._focalPointEditorRole = "editor_presentation"

    addon.guiEditorPresentationHost = host
    return host
end

local function EnsureEditorWorkspaceLayer(addon)
    if not addon then
        return nil
    end

    local layer = addon.guiEditorWorkspaceLayer
    if layer then
        return layer
    end

    local presentationHost = EnsureEditorPresentationHost(addon)
    if not presentationHost then
        return nil
    end

    layer = CreateFrame("Frame", nil, presentationHost)
    layer:SetAllPoints(presentationHost)
    layer:SetFrameStrata("BACKGROUND")
    layer:EnableMouse(false)
    layer:Hide()
    layer._focalPointEditorRole = "editor_workspace_layer"

    addon.guiEditorWorkspaceLayer = layer
    return layer
end

local function EnsureEditorInspectorLayer(addon)
    if not addon then
        return nil
    end

    local layer = addon.guiEditorInspectorLayer
    if layer then
        return layer
    end

    local presentationHost = EnsureEditorPresentationHost(addon)
    if not presentationHost then
        return nil
    end

    layer = CreateFrame("Frame", nil, presentationHost)
    layer:SetAllPoints(presentationHost)
    layer:SetFrameStrata("DIALOG")
    layer:EnableMouse(false)
    layer:Hide()
    layer._focalPointEditorRole = "editor_inspector_layer"

    addon.guiEditorInspectorLayer = layer
    return layer
end

local function ShowEditorPresentationHost(addon)
    local host = EnsureEditorPresentationHost(addon)
    if host and host.Show then
        host:Show()
    end

    local workspaceLayer = EnsureEditorWorkspaceLayer(addon)
    if workspaceLayer and workspaceLayer.Show then
        workspaceLayer:Show()
    end

    local inspectorLayer = EnsureEditorInspectorLayer(addon)
    if inspectorLayer and inspectorLayer.Show then
        inspectorLayer:Show()
    end

    return host
end

local function HideEditorPresentationHost(addon)
    local host = addon and addon.guiEditorPresentationHost
    local workspaceLayer = addon and addon.guiEditorWorkspaceLayer
    local inspectorLayer = addon and addon.guiEditorInspectorLayer
    if inspectorLayer and inspectorLayer.Hide then
        inspectorLayer:Hide()
    end
    if workspaceLayer and workspaceLayer.Hide then
        workspaceLayer:Hide()
    end
    if host and host.Hide then
        host:Hide()
    end
end

function AppShell.AssignEditorRuntimeRoles(addon)
    if not addon then
        return
    end

    local presentationHost = ShowEditorPresentationHost(addon)
    addon.guiEditorToolbarHost = addon.guiAppSidebar
    addon.guiEditorWorkspaceHost = addon.guiEditorWorkspaceLayer or presentationHost or addon.guiContentHost
    addon.guiEditorInspectorHost = addon.guiEditorInspectorLayer or presentationHost

    if addon.guiEditorToolbarHost then
        addon.guiEditorToolbarHost._focalPointEditorRole = "editor_toolbar"
        if addon.guiEditorToolbarHost.frame then
            addon.guiEditorToolbarHost.frame._focalPointEditorRole = "editor_toolbar"
        end
    end
end

function AppShell.ClearEditorRuntimeRoles(addon)
    if not addon then
        return
    end

    HideEditorPresentationHost(addon)

    if addon.guiEditorToolbarHost then
        addon.guiEditorToolbarHost._focalPointEditorRole = nil
        if addon.guiEditorToolbarHost.frame then
            addon.guiEditorToolbarHost.frame._focalPointEditorRole = nil
        end
    end

    addon.guiEditorToolbarHost = nil
    addon.guiEditorWorkspaceHost = nil
    addon.guiEditorInspectorHost = nil
end

local function CaptureFrameChromeState(widget)
    if not widget or widget._focalPointChromeState then
        return widget and widget._focalPointChromeState
    end

    local rootFrame = widget.frame or widget
    local contentFrame = widget.content
    if not rootFrame or not contentFrame then
        return nil
    end

    local state = {
        regions = {},
        children = {},
        contentPoints = {},
        closeButton = nil,
        backdropColor = nil,
        backdropBorderColor = nil,
    }

    if rootFrame.GetRegions then
        for _, region in ipairs({ rootFrame:GetRegions() }) do
            state.regions[#state.regions + 1] = {
                object = region,
                shown = region.IsShown and region:IsShown() or true,
            }
        end
    end

    if rootFrame.GetChildren then
        for _, child in ipairs({ rootFrame:GetChildren() }) do
            if child ~= contentFrame then
                state.children[#state.children + 1] = {
                    object = child,
                    shown = child.IsShown and child:IsShown() or true,
                }
            end

            if not state.closeButton
                and child
                and child.GetObjectType
                and child:GetObjectType() == "Button"
                and child.GetText
                and child:GetText() == CLOSE
            then
                state.closeButton = child
            end
        end
    end

    if contentFrame.GetNumPoints and contentFrame.GetPoint then
        for index = 1, contentFrame:GetNumPoints() do
            local point, relativeTo, relativePoint, xOfs, yOfs = contentFrame:GetPoint(index)
            state.contentPoints[#state.contentPoints + 1] = {
                point = point,
                relativeTo = relativeTo,
                relativePoint = relativePoint,
                x = xOfs,
                y = yOfs,
            }
        end
    end

    if rootFrame.GetBackdropColor then
        local r, g, b, a = rootFrame:GetBackdropColor()
        state.backdropColor = { r, g, b, a }
    end

    if rootFrame.GetBackdropBorderColor then
        local r, g, b, a = rootFrame:GetBackdropBorderColor()
        state.backdropBorderColor = { r, g, b, a }
    end

    widget._focalPointChromeState = state
    return state
end

local function ApplyVisualChromeSuppression(rootFrame, state)
    if not rootFrame or not state then
        return
    end

    for _, regionState in ipairs(state.regions) do
        if regionState.object and regionState.object.Hide then
            regionState.object:Hide()
        end
    end

    for _, childState in ipairs(state.children) do
        if childState.object and childState.object.Hide then
            childState.object:Hide()
        end
    end

    if rootFrame.SetBackdropColor then
        rootFrame:SetBackdropColor(0, 0, 0, 0)
    end

    if rootFrame.SetBackdropBorderColor then
        rootFrame:SetBackdropBorderColor(0, 0, 0, 0)
    end
end

local function RestoreVisualChrome(rootFrame, state)
    if not rootFrame or not state then
        return
    end

    for _, regionState in ipairs(state.regions) do
        if regionState.object then
            if regionState.shown and regionState.object.Show then
                regionState.object:Show()
            elseif regionState.object.Hide then
                regionState.object:Hide()
            end
        end
    end

    for _, childState in ipairs(state.children) do
        if childState.object then
            if childState.shown and childState.object.Show then
                childState.object:Show()
            elseif childState.object.Hide then
                childState.object:Hide()
            end
        end
    end

    if rootFrame.SetBackdropColor and state.backdropColor then
        rootFrame:SetBackdropColor(unpack(state.backdropColor))
    end

    if rootFrame.SetBackdropBorderColor and state.backdropBorderColor then
        rootFrame:SetBackdropBorderColor(unpack(state.backdropBorderColor))
    end
end

local function ExpandHostContentToFullscreen(rootFrame, contentFrame)
    if not rootFrame or not contentFrame then
        return
    end

    contentFrame:ClearAllPoints()
    contentFrame:SetPoint("TOPLEFT", rootFrame, "TOPLEFT", 0, 0)
    contentFrame:SetPoint("BOTTOMRIGHT", rootFrame, "BOTTOMRIGHT", 0, 0)
end

local function RestoreHostContentPoints(contentFrame, state)
    if not contentFrame or not state then
        return
    end

    contentFrame:ClearAllPoints()
    for _, pointData in ipairs(state.contentPoints) do
        contentFrame:SetPoint(
            pointData.point,
            pointData.relativeTo,
            pointData.relativePoint,
            pointData.x,
            pointData.y
        )
    end
end

function AppShell.ApplyFrameChromeMode(widget, chromeMode)
    local rootFrame = widget and (widget.frame or widget)
    local contentFrame = widget and widget.content
    if not rootFrame or not contentFrame then
        return
    end

    local state = CaptureFrameChromeState(widget)
    if not state then
        return
    end

    if chromeMode == "shell" then
        if widget._focalPointMinimalChrome then
            return
        end

        ApplyVisualChromeSuppression(rootFrame, state)

        if rootFrame.EnableMouse then
            rootFrame:EnableMouse(false)
        end

        ExpandHostContentToFullscreen(rootFrame, contentFrame)

        widget._focalPointMinimalChrome = true
        return
    end

    if not widget._focalPointMinimalChrome then
        return
    end

    RestoreVisualChrome(rootFrame, state)

    if rootFrame.EnableMouse then
        rootFrame:EnableMouse(true)
    end

    RestoreHostContentPoints(contentFrame, state)

    widget._focalPointMinimalChrome = nil
end

function AppShell.ApplyEditorHostChromeCompensation(widget)
    AppShell.ApplyFrameChromeMode(widget, "shell")
end

function AppShell.ApplyWindowHostChrome(widget)
    AppShell.ApplyFrameChromeMode(widget, "window")
end

local function ApplyEditorShellLayoutCompensation(addon, targetHeight)
    if not addon or not addon.guiAppSidebar or not addon.guiContentHost then
        return
    end

    addon.guiAppSidebar.relWidth = nil
    addon.guiAppSidebar.width = 285
    addon.guiAppSidebar.frame.width = 285
    addon.guiAppSidebar.frame:SetWidth(285)
    addon.guiAppSidebar:SetHeight(targetHeight)
    if addon.guiAppSidebar.frame and addon.guiAppSidebar.frame.SetHeight then
        addon.guiAppSidebar.frame:SetHeight(targetHeight)
    end

    addon.guiContentHost.relWidth = nil
    addon.guiContentHost.width = nil
    addon.guiContentHost.frame.width = nil
end

local function ApplyToolShellLayout(addon, targetHeight)
    if not addon or not addon.guiAppSidebar or not addon.guiContentHost then
        return
    end

    addon.guiAppSidebar.width = nil
    addon.guiAppSidebar.frame.width = nil
    addon.guiAppSidebar:SetRelativeWidth(SHELL_SIDEBAR_REL_WIDTH)
    addon.guiAppSidebar:SetHeight(targetHeight)
    if addon.guiAppSidebar.frame and addon.guiAppSidebar.frame.SetHeight then
        addon.guiAppSidebar.frame:SetHeight(targetHeight)
    end

    addon.guiContentHost.width = nil
    addon.guiContentHost.frame.width = nil
    addon.guiContentHost:SetRelativeWidth(SHELL_CONTENT_REL_WIDTH)
    addon.guiContentHost:SetHeight(targetHeight)
    if addon.guiContentHost.frame and addon.guiContentHost.frame.SetHeight then
        addon.guiContentHost.frame:SetHeight(targetHeight)
    end
end

local function ApplyEditorHostDockingCompensation(widget, rootFrame)
    if not widget or not rootFrame then
        return
    end

    if not widget._focalPointDockedForScreenEdit then
        local point, relativeTo, relativePoint, xOfs, yOfs = rootFrame:GetPoint(1)
        widget._focalPointRestorePoint = {
            point = point or "CENTER",
            relativeTo = relativeTo,
            relativePoint = relativePoint or "CENTER",
            x = xOfs or 0,
            y = yOfs or 0,
        }
        widget._focalPointDockedForScreenEdit = true
    end

    rootFrame:ClearAllPoints()
    rootFrame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 0, 0)
end

local function RestoreHostDockingAfterEditor(widget, rootFrame)
    if not widget or not rootFrame or not widget._focalPointDockedForScreenEdit then
        return
    end

    widget._focalPointDockedForScreenEdit = nil

    local restore = widget._focalPointRestorePoint
    rootFrame:ClearAllPoints()
    if restore then
        rootFrame:SetPoint(
            restore.point or "CENTER",
            restore.relativeTo or UIParent,
            restore.relativePoint or "CENTER",
            restore.x or 0,
            restore.y or 0
        )
    else
        rootFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    end
end

function AppShell.UpdateGeometry(addon, resolvePath)
    local widget = GetMainHostWidget(addon)
    if not widget or type(resolvePath) ~= "function" then
        return
    end

    local rootFrame = widget.frame or widget
    if not rootFrame then
        return
    end

    local selectedPath = resolvePath(addon.GUI and addon.GUI.selectedPath)
    local shellMode = AppShell.ResolveShellMode(addon, selectedPath)
    local editorShellMode = shellMode == "editor"
    addon.guiShellMode = shellMode

    if editorShellMode then
        AppShell.AssignEditorRuntimeRoles(addon)
    else
        AppShell.ClearEditorRuntimeRoles(addon)
    end

    local targetWidth = 1220
    local targetHeight = editorShellMode and ((UIParent and UIParent.GetHeight and UIParent:GetHeight()) or 760) or 760

    if widget.SetWidth then
        widget:SetWidth(targetWidth)
    elseif widget.frame and widget.frame.SetWidth then
        widget.frame:SetWidth(targetWidth)
    end

    if widget.SetHeight then
        widget:SetHeight(targetHeight)
    elseif widget.frame and widget.frame.SetHeight then
        widget.frame:SetHeight(targetHeight)
    end

    if editorShellMode then
        ApplyEditorShellLayoutCompensation(addon, targetHeight)
    else
        ApplyToolShellLayout(addon, targetHeight)
    end

    local hostChromeMode = AppShell.ResolveHostChromeMode(shellMode)
    addon.guiHostChromeMode = hostChromeMode
    if hostChromeMode == "shell" then
        AppShell.ApplyEditorHostChromeCompensation(widget)
    else
        AppShell.ApplyWindowHostChrome(widget)
    end

    if editorShellMode then
        ApplyEditorHostDockingCompensation(widget, rootFrame)
    else
        RestoreHostDockingAfterEditor(widget, rootFrame)
    end

    if addon.guiRoot and addon.guiRoot.DoLayout then
        addon.guiRoot:DoLayout()
    end

    local editorController = addon.GUI and addon.GUI.Editor and addon.GUI.Editor.Controller
    if shellMode ~= "editor" and editorController and editorController.ReleaseInspector then
        editorController.ReleaseInspector()
    elseif editorController and editorController.UpdateActiveInspectorGeometry then
        editorController.UpdateActiveInspectorGeometry()
    end
end

function AppShell.BuildRoot(addon, hostWidget)
    local root = AceGUI:Create("SimpleGroup")
    root:SetFullWidth(true)
    root:SetFullHeight(true)
    root:SetLayout("Flow")
    hostWidget:AddChild(root)

    local appSidebar = AceGUI:Create("SimpleGroup")
    appSidebar:SetRelativeWidth(SHELL_SIDEBAR_REL_WIDTH)
    appSidebar:SetHeight(700)
    appSidebar:SetLayout("Fill")
    root:AddChild(appSidebar)

    if appSidebar.frame then
        local sidebarBg = appSidebar.frame:CreateTexture(nil, "BACKGROUND")
        sidebarBg:SetAllPoints()
        sidebarBg:SetColorTexture(0.05, 0.06, 0.08, 0.84)
        appSidebar._sidebarBg = sidebarBg

        local sidebarBorder = appSidebar.frame:CreateTexture(nil, "BORDER")
        sidebarBorder:SetPoint("TOPRIGHT")
        sidebarBorder:SetPoint("BOTTOMRIGHT")
        sidebarBorder:SetWidth(1)
        sidebarBorder:SetColorTexture(0.16, 0.19, 0.24, 0.9)
        appSidebar._sidebarBorder = sidebarBorder
    end

    local contentHost = AceGUI:Create("SimpleGroup")
    contentHost:SetRelativeWidth(SHELL_CONTENT_REL_WIDTH)
    contentHost:SetHeight(700)
    contentHost:SetLayout("Fill")
    root:AddChild(contentHost)

    addon.guiAppSidebar = appSidebar
    addon.guiContentHost = contentHost

    return root, appSidebar, contentHost
end

function AppShell.RenderToolContent(container, buildFunc)
    if type(buildFunc) == "function" then
        buildFunc(container)
    end
end

return AppShell
