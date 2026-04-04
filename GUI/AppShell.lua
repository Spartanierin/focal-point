local _, ns = ...

ns.GUI = ns.GUI or {}

local AceGUI = LibStub("AceGUI-3.0")
local AppShell = {}
ns.GUI.AppShell = AppShell

local SHELL_SIDEBAR_WIDTH = 285
local SHELL_COLUMNS = {
    { width = SHELL_SIDEBAR_WIDTH },
    { weight = 1 },
}

local function SetShellSidebarVisualState(sidebar, visible)
    if not sidebar then
        return
    end

    local frame = sidebar.frame
    if frame then
        if frame._sidebar and frame._sidebar.SetShown then
            frame._sidebar:SetShown(visible)
        end
        if frame._sidebarBorder and frame._sidebarBorder.SetShown then
            frame._sidebarBorder:SetShown(visible)
        end
        if frame.SetAlpha then
            frame:SetAlpha(visible and 1 or 0)
        end
    end

    if sidebar.content then
        if sidebar.content.SetAlpha then
            sidebar.content:SetAlpha(visible and 1 or 0)
        end
        if visible then
            sidebar.content:Show()
        else
            sidebar.content:Hide()
        end
    end
end

local function SetToolContentVisualState(contentHost, visible)
    if not contentHost or not contentHost.frame then
        return
    end

    local frame = contentHost.frame
    if frame._toolContentBg and frame._toolContentBg.SetShown then
        frame._toolContentBg:SetShown(visible)
    end
    if frame._toolContentBorderTop and frame._toolContentBorderTop.SetShown then
        frame._toolContentBorderTop:SetShown(visible)
    end
    if frame._toolContentBorderBottom and frame._toolContentBorderBottom.SetShown then
        frame._toolContentBorderBottom:SetShown(visible)
    end
    if frame._toolContentBorderLeft and frame._toolContentBorderLeft.SetShown then
        frame._toolContentBorderLeft:SetShown(visible)
    end
    if frame._toolContentBorderRight and frame._toolContentBorderRight.SetShown then
        frame._toolContentBorderRight:SetShown(visible)
    end
end

local function EnsureSidebarSurface(frame, ownerKey)
    if not frame then
        return
    end

    local bgKey = ownerKey or "_sidebarBg"
    local borderKey = (ownerKey or "_sidebarBg") .. "Border"

    if not frame[bgKey] then
        local sidebarBg = frame:CreateTexture(nil, "BACKGROUND")
        sidebarBg:SetAllPoints()
        sidebarBg:SetColorTexture(0.05, 0.06, 0.08, 0.84)
        frame[bgKey] = sidebarBg
    end

    if not frame[borderKey] then
        local sidebarBorder = frame:CreateTexture(nil, "BORDER")
        sidebarBorder:SetPoint("TOPRIGHT")
        sidebarBorder:SetPoint("BOTTOMRIGHT")
        sidebarBorder:SetWidth(1)
        sidebarBorder:SetColorTexture(0.16, 0.19, 0.24, 0.9)
        frame[borderKey] = sidebarBorder
    end
end

local function EnsureToolContentSurface(frame)
    if not frame then
        return
    end

    if not frame._toolContentBg then
        local bg = frame:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints()
        bg:SetColorTexture(0.05, 0.06, 0.08, 0.84)
        frame._toolContentBg = bg
    end

    if not frame._toolContentBorderTop then
        local top = frame:CreateTexture(nil, "BORDER")
        top:SetPoint("TOPLEFT")
        top:SetPoint("TOPRIGHT")
        top:SetHeight(1)
        top:SetColorTexture(0.16, 0.19, 0.24, 0.9)
        frame._toolContentBorderTop = top
    end

    if not frame._toolContentBorderBottom then
        local bottom = frame:CreateTexture(nil, "BORDER")
        bottom:SetPoint("BOTTOMLEFT")
        bottom:SetPoint("BOTTOMRIGHT")
        bottom:SetHeight(1)
        bottom:SetColorTexture(0.16, 0.19, 0.24, 0.9)
        frame._toolContentBorderBottom = bottom
    end

    if not frame._toolContentBorderLeft then
        local left = frame:CreateTexture(nil, "BORDER")
        left:SetPoint("TOPLEFT")
        left:SetPoint("BOTTOMLEFT")
        left:SetWidth(1)
        left:SetColorTexture(0.16, 0.19, 0.24, 0.0)
        frame._toolContentBorderLeft = left
    end

    if not frame._toolContentBorderRight then
        local right = frame:CreateTexture(nil, "BORDER")
        right:SetPoint("TOPRIGHT")
        right:SetPoint("BOTTOMRIGHT")
        right:SetWidth(1)
        right:SetColorTexture(0.16, 0.19, 0.24, 0.9)
        frame._toolContentBorderRight = right
    end
end

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

local function IsEditorPath(addon, path)
    local nav = addon and addon.Constants and addon.Constants.Nav
    if not nav then
        return false
    end

    if path == nav.EDITOR
        or path == nav.GENERAL
        or path == nav.THEMES
        or path == nav.UNITS
    then
        return true
    end

    if type(path) == "string" and path:match("^units%.([^.]+)$") then
        return true
    end

    return false
end

function AppShell.ResolveShellMode(addon, path)
    if IsEditorPath(addon, path) then
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
        return "tool_shell"
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
    container._focalPointUsesOwnSurface = nil
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

local function EnsureEditorToolbarLayer(addon)
    if not addon then
        return nil
    end

    local layer = addon.guiEditorToolbarLayer
    if layer then
        return layer
    end

    layer = CreateFrame("Frame", nil, UIParent)
    layer:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 0, 0)
    layer:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", 0, 0)
    layer:SetWidth(285)
    layer:SetFrameStrata("FULLSCREEN_DIALOG")
    layer:SetFrameLevel(120)
    if layer.SetAlpha then
        layer:SetAlpha(1)
    end
    if layer.SetIgnoreParentAlpha then
        layer:SetIgnoreParentAlpha(true)
    end
    layer:EnableMouse(false)
    layer:Hide()
    layer._focalPointEditorRole = "editor_toolbar_layer"

    EnsureSidebarSurface(layer, "_editorSidebar")

    addon.guiEditorToolbarLayer = layer
    return layer
end

local function EnsureEditorToolbarContainer(addon)
    if not addon then
        return nil
    end

    local container = addon.guiEditorToolbarContainer
    if container then
        return container
    end

    local layer = EnsureEditorToolbarLayer(addon)
    if not layer then
        return nil
    end

    container = AceGUI:Create("SimpleGroup")
    container:SetFullWidth(true)
    container:SetFullHeight(true)
    container:SetLayout("Flow")
    if container.frame then
        container.frame:SetParent(layer)
        container.frame:ClearAllPoints()
        container.frame:SetAllPoints(layer)
        if layer.GetFrameStrata and container.frame.SetFrameStrata then
            container.frame:SetFrameStrata(layer:GetFrameStrata())
        end
        if layer.GetFrameLevel and container.frame.SetFrameLevel then
            container.frame:SetFrameLevel((layer:GetFrameLevel() or 0) + 1)
        end
        if container.frame.SetAlpha then
            container.frame:SetAlpha(1)
        end
        if container.frame.SetIgnoreParentAlpha then
            container.frame:SetIgnoreParentAlpha(true)
        end
        container.frame:Show()
    end
    if container.content then
        container.content:SetParent(container.frame or layer)
        container.content:ClearAllPoints()
        container.content:SetAllPoints(container.frame or layer)
        if layer.GetFrameLevel and container.content.SetFrameLevel then
            container.content:SetFrameLevel((layer:GetFrameLevel() or 0) + 2)
        end
        if container.content.SetAlpha then
            container.content:SetAlpha(1)
        end
        if container.content.SetIgnoreParentAlpha then
            container.content:SetIgnoreParentAlpha(true)
        end
        container.content:Show()
    end
    container._focalPointEditorRole = "editor_toolbar"

    addon.guiEditorToolbarContainer = container
    return container
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

    local toolbarLayer = EnsureEditorToolbarLayer(addon)
    if toolbarLayer and toolbarLayer.Show then
        toolbarLayer:Show()
    end

    EnsureEditorToolbarContainer(addon)

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
    local toolbarLayer = addon and addon.guiEditorToolbarLayer
    local workspaceLayer = addon and addon.guiEditorWorkspaceLayer
    local inspectorLayer = addon and addon.guiEditorInspectorLayer
    if inspectorLayer and inspectorLayer.Hide then
        inspectorLayer:Hide()
    end
    if workspaceLayer and workspaceLayer.Hide then
        workspaceLayer:Hide()
    end
    if toolbarLayer and toolbarLayer.Hide then
        toolbarLayer:Hide()
    end
    if host and host.Hide then
        host:Hide()
    end
end

function AppShell.GetSidebarBuildHost(addon)
    if not addon then
        return nil
    end

    if addon.guiShellMode == "editor" then
        return addon.guiEditorToolbarHost or addon.guiEditorToolbarContainer or addon.guiAppSidebar
    end

    return addon.guiAppSidebar
end

function AppShell.AssignEditorRuntimeRoles(addon)
    if not addon then
        return
    end

    local presentationHost = ShowEditorPresentationHost(addon)
    addon.guiEditorToolbarHost = addon.guiEditorToolbarContainer or addon.guiAppSidebar
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
        if addon.guiEditorToolbarHost.ReleaseChildren then
            addon.guiEditorToolbarHost:ReleaseChildren()
        end
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
        contentFrame = contentFrame,
        closeButton = nil,
        titleChildren = {},
        statusChildren = {},
        sizerChildren = {},
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

            if child and child.GetScript then
                local onMouseDown = child:GetScript("OnMouseDown")
                local onMouseUp = child:GetScript("OnMouseUp")
                local onEnter = child:GetScript("OnEnter")
                local onLeave = child:GetScript("OnLeave")

                if onEnter or onLeave then
                    state.statusChildren[#state.statusChildren + 1] = child
                elseif onMouseDown and onMouseUp then
                    state.titleChildren[#state.titleChildren + 1] = child
                elseif onMouseDown and not onMouseUp then
                    state.sizerChildren[#state.sizerChildren + 1] = child
                end
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

    if rootFrame.SetAlpha then
        rootFrame:SetAlpha(0)
    end

    for _, regionState in ipairs(state.regions) do
        if regionState.object and regionState.object.Hide then
            regionState.object:Hide()
        end
    end

    if state.closeButton and state.closeButton.Hide then
        state.closeButton:Hide()
    end

    for _, child in ipairs(state.titleChildren or {}) do
        if child and child.Hide then
            child:Hide()
        end
    end

    for _, child in ipairs(state.statusChildren or {}) do
        if child and child.Hide then
            child:Hide()
        end
    end

    for _, child in ipairs(state.sizerChildren or {}) do
        if child and child.Hide then
            child:Hide()
        end
    end

end

local function RestoreVisualChrome(rootFrame, state)
    if not rootFrame or not state then
        return
    end

    if rootFrame.SetAlpha then
        rootFrame:SetAlpha(1)
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

    local currentMode = widget._focalPointChromeMode

    if chromeMode == "shell" or chromeMode == "tool_shell" then
        if widget._focalPointMinimalChrome and currentMode == chromeMode then
            return
        end

        if widget._focalPointMinimalChrome and currentMode and currentMode ~= chromeMode then
            RestoreVisualChrome(rootFrame, state)
            if rootFrame.EnableMouse then
                rootFrame:EnableMouse(true)
            end
            if rootFrame.SetAlpha then
                rootFrame:SetAlpha(1)
            end
            RestoreHostContentPoints(contentFrame, state)
            widget._focalPointMinimalChrome = nil
        end

        ApplyVisualChromeSuppression(rootFrame, state)

        if chromeMode == "shell" then
            if rootFrame.EnableMouse then
                rootFrame:EnableMouse(false)
            end
        else
            if rootFrame.SetBackdropColor then
                rootFrame:SetBackdropColor(0, 0, 0, 0)
            end

            if rootFrame.SetBackdropBorderColor then
                rootFrame:SetBackdropBorderColor(0, 0, 0, 0)
            end

            if rootFrame.SetAlpha then
                rootFrame:SetAlpha(1)
            end
        end

        widget._focalPointMinimalChrome = true
        widget._focalPointChromeMode = chromeMode
        return
    end

    if not widget._focalPointMinimalChrome then
        widget._focalPointChromeMode = chromeMode
        return
    end

    RestoreVisualChrome(rootFrame, state)

    if rootFrame.EnableMouse then
        rootFrame:EnableMouse(true)
    end

    RestoreHostContentPoints(contentFrame, state)

    widget._focalPointMinimalChrome = nil
    widget._focalPointChromeMode = chromeMode
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
    SetShellSidebarVisualState(addon.guiAppSidebar, false)
    SetToolContentVisualState(addon.guiContentHost, false)
    if addon.guiEditorToolbarLayer and addon.guiEditorToolbarLayer.SetHeight then
        addon.guiEditorToolbarLayer:SetHeight(targetHeight)
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
    addon.guiAppSidebar.relWidth = nil
    addon.guiAppSidebar.width = SHELL_SIDEBAR_WIDTH
    addon.guiAppSidebar.frame.width = SHELL_SIDEBAR_WIDTH
    addon.guiAppSidebar.frame:SetWidth(SHELL_SIDEBAR_WIDTH)
    addon.guiAppSidebar:SetHeight(targetHeight)
    if addon.guiAppSidebar.frame and addon.guiAppSidebar.frame.SetHeight then
        addon.guiAppSidebar.frame:SetHeight(targetHeight)
    end
    SetShellSidebarVisualState(addon.guiAppSidebar, true)

    addon.guiContentHost.width = nil
    addon.guiContentHost.frame.width = nil
    addon.guiContentHost.relWidth = nil
    addon.guiContentHost:SetHeight(targetHeight)
    if addon.guiContentHost.frame and addon.guiContentHost.frame.SetHeight then
        addon.guiContentHost.frame:SetHeight(targetHeight)
    end
    SetToolContentVisualState(addon.guiContentHost, not addon.guiContentHost._focalPointUsesOwnSurface)
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
    AppShell.ApplyFrameChromeMode(widget, hostChromeMode)

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
    root:SetLayout("Table")
    root:SetUserData("table", {
        columns = SHELL_COLUMNS,
        space = 0,
        spaceH = 0,
        spaceV = 0,
    })
    hostWidget:AddChild(root)

    local appSidebar = AceGUI:Create("SimpleGroup")
    appSidebar:SetFullWidth(true)
    appSidebar:SetHeight(700)
    appSidebar:SetLayout("Fill")
    root:AddChild(appSidebar)

    if appSidebar.frame then
        EnsureSidebarSurface(appSidebar.frame, "_sidebar")
        appSidebar._sidebarBg = appSidebar.frame._sidebar
        appSidebar._sidebarBorder = appSidebar.frame._sidebarBorder
    end

    local contentHost = AceGUI:Create("SimpleGroup")
    contentHost:SetFullWidth(true)
    contentHost:SetHeight(700)
    contentHost:SetLayout("Fill")
    root:AddChild(contentHost)

    if contentHost.frame then
        EnsureToolContentSurface(contentHost.frame)
    end

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
