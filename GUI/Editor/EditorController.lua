local _, ns = ...

ns.GUI = ns.GUI or {}
ns.GUI.Editor = ns.GUI.Editor or {}

local AceGUI = LibStub("AceGUI-3.0")
local EditorController = {}
ns.GUI.Editor.Controller = EditorController
local FormWidgets = ns.GUI.Helpers and ns.GUI.Helpers.FormWidgets
local ApplySidebarChrome = FormWidgets and FormWidgets.ApplySidebarChrome
local CUSTOMIZE_SHELL = "editmode" -- A/B pilot: "blizzard" (Metal) or "editmode" (translucent).
local CUSTOMIZE_WORLD_DIM_ALPHA = .28
local COMPONENT_LIST_WIDTH = 360
local customizeBackdrop
local ComputeInspectorGeometry, ApplyInspectorGeometry

local function ResolveCustomizeShell()
    if CUSTOMIZE_SHELL == "editmode" and FormWidgets.CanApplyCustomizeEditModeShell() then return "editmode" end
    return (CUSTOMIZE_SHELL == "blizzard" or CUSTOMIZE_SHELL == "editmode") and FormWidgets.CanApplyCustomizeBlizzardShell()
        and "blizzard" or "navigator"
end

local function ApplyCustomizeTitle(owner)
    -- Reuse the native drag owner, entirely above the content/breadcrumb reserve.
    local drag = owner and owner.title
    if drag then
        drag:ClearAllPoints()
        drag:SetPoint("TOPLEFT", owner.frame, "TOPLEFT", 12, -8)
        drag:SetPoint("BOTTOMRIGHT", owner.frame, "TOPRIGHT", -48, -56)
    end
    local title = owner and owner.titletext
    if not title then return end
    if GameFontHighlightLarge and title.SetFontObject then title:SetFontObject(GameFontHighlightLarge) end
    FormWidgets.ApplyTextStyle(title, "identity", 18, 1)
    title:SetTextColor(1, 1, 1, 1)
    title:SetJustifyH("CENTER")
    title:ClearAllPoints()
    title:SetPoint("TOPLEFT", owner.frame, "TOPLEFT", 36, -18)
    title:SetPoint("TOPRIGHT", owner.frame, "TOPRIGHT", -36, -18)
end

local function ApplyInspectorShellComposition(owner, canonicalOnly)
    local composition = ns.GUI.PresentationCompositionPreview
    if not owner then return end
    FormWidgets.NeutralizeCustomizeBlizzardShell(owner)
    owner._fpNavigatorBrassEnabled = true
    if ApplySidebarChrome then ApplySidebarChrome(owner, "inspector_shell") end
    local active = composition and composition.Apply("inspector_shell", owner, nil, canonicalOnly)
    if active then
        owner._fpNavigatorBrassEnabled = false
        ApplyCustomizeTitle(owner)
        return ApplyInspectorGeometry(owner, ComputeInspectorGeometry(owner._focalPointCustomizeView))
    end
    local shell = ResolveCustomizeShell()
    if shell == "blizzard" or shell == "editmode" then
        owner._fpNavigatorBrassEnabled = false
        FormWidgets.ApplyCustomizeBlizzardShell(owner, shell == "editmode")
    end
    ApplyCustomizeTitle(owner)
    return ApplyInspectorGeometry(owner, ComputeInspectorGeometry(owner._focalPointCustomizeView))
end

local SidebarGeometry = ns.GUI.Editor and ns.GUI.Editor.SidebarGeometry

local INSPECTOR_WIDTH = (SidebarGeometry and (SidebarGeometry.inspectorWidth or SidebarGeometry.width)) or 285
local INSPECTOR_OFFSET_X = -16
local INSPECTOR_OFFSET_Y = -120
local INSPECTOR_CONTEXT_HEIGHT_RATIO = 0.34
local INSPECTOR_CONTEXT_MIN_HEIGHT = 100
local INSPECTOR_PROPERTY_MIN_HEIGHT = 320
local INSPECTOR_CONTEXT_GAP = 10

local function GetEditorPresentationAnchor()
    return UIParent
end

ComputeInspectorGeometry = function(view)
    local width = math.min(view == "properties" and 600 or COMPONENT_LIST_WIDTH + 32, UIParent:GetWidth() - 32)
    local height = math.min(view == "properties" and 520 or 620, UIParent:GetHeight() - 100)
    local insetLeft = 16
    local insetRight = 16
    local insetTop = 64 -- Shared title reserve, independent of the selected shell.
    local insetBottom = 16
    local workspaceTop = 36 -- Existing 30px Properties back row plus 6px separation.
    local contentHeight = height - insetTop - insetBottom

    return {
        width = width,
        height = height,
        anchorHost = GetEditorPresentationAnchor(),
        point = "CENTER",
        relativePoint = "CENTER",
        offsetX = 0,
        offsetY = 0,
        insetLeft = insetLeft,
        insetRight = insetRight,
        insetTop = insetTop,
        insetBottom = insetBottom,
        contentWidth = width - insetLeft - insetRight,
        contentHeight = contentHeight,
        workspaceTop = workspaceTop,
        workspaceHeight = math.max(1, math.floor(contentHeight) - workspaceTop),
        componentTop = workspaceTop, -- The Unit row now owns the existing global Add entry.
        componentHeight = math.max(1, math.floor(contentHeight) - workspaceTop),
    }
end

ApplyInspectorGeometry = function(inspector, geometry)
    if not inspector or not inspector.frame or not geometry then
        return
    end

    if inspector.SetWidth then
        inspector:SetWidth(geometry.width)
    end
    if inspector.SetHeight then
        inspector:SetHeight(geometry.height)
    end
    if inspector.frame.SetWidth then
        inspector.frame:SetWidth(geometry.width)
    end
    if inspector.frame.SetHeight then
        inspector.frame:SetHeight(geometry.height)
    end

    local anchorHost = geometry.anchorHost
    if inspector.frame.SetParent then
        inspector.frame:SetParent(anchorHost)
    end
    -- The native Window title owns dragging. Refreshes must not reset its position.
    if not inspector._focalPointWorkspacePositioned then
        inspector.frame:ClearAllPoints()
        inspector.frame:SetPoint(geometry.point, anchorHost, geometry.relativePoint, geometry.offsetX, geometry.offsetY)
        inspector._focalPointWorkspacePositioned = true
    end

    local inspectorContent = inspector._focalPointInspectorContent
    if inspectorContent then
        if inspectorContent.SetWidth then
            inspectorContent:SetWidth(geometry.contentWidth)
        end
        if inspectorContent.SetHeight then
            inspectorContent:SetHeight(geometry.contentHeight)
        end
    end

    local inspectorInset = inspector._focalPointInspectorInset
    if inspectorInset then
        inspectorInset:ClearAllPoints()
        inspectorInset:SetPoint("TOPLEFT", inspector.frame, "TOPLEFT", geometry.insetLeft, -geometry.insetTop)
        inspectorInset:SetPoint("BOTTOMRIGHT", inspector.frame, "BOTTOMRIGHT", -geometry.insetRight, geometry.insetBottom)
        -- Fill always targets the Window's actual content host. Keep that host
        -- inside the same inset instead of relying on the Body's parent alone.
        local content = inspector.content
        content:ClearAllPoints()
        content:SetPoint("TOPLEFT", inspectorInset, "TOPLEFT", 0, 0)
        content:SetPoint("BOTTOMRIGHT", inspectorInset, "BOTTOMRIGHT", 0, 0)
        content:SetWidth(geometry.contentWidth)
        content:SetHeight(geometry.contentHeight)
        content.width, content.height = geometry.contentWidth, geometry.contentHeight
    end
    -- Resize only the current workspace children; no retained geometry/state copy.
    local children = inspectorContent and inspectorContent.children
    if children and #children >= 3 then
        local header, treeHost, propertyRoot = children[1], children[2], children[3]
        local changed = treeHost.frame:GetHeight() ~= geometry.componentHeight
        header:SetWidth(geometry.contentWidth)
        local objectLabel = inspector._focalPointObjectBreadcrumb
        local back = inspector._focalPointComponentsButton
        if objectLabel and objectLabel.parent == header and back then
            -- Label's FontString needs an explicit width as well as Table anchors.
            objectLabel:SetWidth(math.max(1, geometry.contentWidth - back.frame:GetWidth() - 4 - 32))
        end
        treeHost:SetWidth(math.min(COMPONENT_LIST_WIDTH, geometry.contentWidth))
        treeHost:SetHeight(geometry.componentHeight)
        treeHost.frame:ClearAllPoints()
        treeHost.frame:SetPoint("TOPLEFT", inspectorContent.frame, "TOPLEFT", 0, -geometry.componentTop)
        propertyRoot:SetWidth(geometry.contentWidth)
        propertyRoot:SetHeight(geometry.workspaceHeight)
        local scroll = inspector._focalPointPropertyScroll
        if scroll and scroll.parent == propertyRoot then scroll:SetHeight(geometry.workspaceHeight) end
        return changed
    end
    return false
end

local function ResolveInspectorContextHeight(geometry)
    local contentHeight = tonumber(geometry and geometry.contentHeight) or 0
    if contentHeight <= 0 then
        return INSPECTOR_CONTEXT_MIN_HEIGHT
    end

    local minContextHeight = math.min(INSPECTOR_CONTEXT_MIN_HEIGHT, math.max(80, math.floor(contentHeight * 0.25)))
    local desiredHeight = math.max(minContextHeight, math.floor(contentHeight * INSPECTOR_CONTEXT_HEIGHT_RATIO))
    local maxHeightWithPropertyBudget = math.max(minContextHeight, contentHeight - INSPECTOR_PROPERTY_MIN_HEIGHT - INSPECTOR_CONTEXT_GAP)
    return math.min(desiredHeight, maxHeightWithPropertyBudget)
end

local function GetPersistentInspector()
    return ns.GUI and ns.GUI.Editor and ns.GUI.Editor._persistentInspector
end

local function SetPersistentInspector(widget)
    ns.GUI = ns.GUI or {}
    ns.GUI.Editor = ns.GUI.Editor or {}
    ns.GUI.Editor._persistentInspector = widget
end

function EditorController.GetActiveInspectorHost()
    return ns.GUI and ns.GUI.Editor and ns.GUI.Editor._activeInspectorHost
end

function EditorController.SetActiveInspectorHost(widget)
    ns.guiEditorInspectorHost = widget
    ns.GUI.Editor._activeInspectorHost = widget
    ns.GUI.Editor._activeInspector = widget
end

local function UpdateCustomizeBackdrop(inspector)
    local stateApi = ns.GUI.Editor.State
    local visible = inspector and inspector == EditorController.GetActiveInspectorHost()
        and inspector.frame:IsShown() and stateApi and stateApi.Get().presentation == "customize"
    if visible then
        -- No protected frame is moved or raised. Avoid ambiguous ordering with level-zero UnitFrames.
        for _, frame in pairs(ns.frames or {}) do
            if frame.GetFrameStrata and frame.GetFrameLevel and frame:GetFrameStrata() == "BACKGROUND"
                and frame:GetFrameLevel() <= 0 then visible = false; break end
        end
    end
    if not visible then
        if customizeBackdrop then customizeBackdrop:Hide() end
        return
    end
    if not customizeBackdrop then
        customizeBackdrop = CreateFrame("Frame", nil, UIParent)
        customizeBackdrop:Hide()
        customizeBackdrop:SetAllPoints(UIParent)
        customizeBackdrop:SetFrameStrata("BACKGROUND")
        customizeBackdrop:SetFrameLevel(0)
        customizeBackdrop:EnableMouse(false)
        customizeBackdrop:EnableMouseWheel(false)
        customizeBackdrop:EnableKeyboard(false)
        local fill = customizeBackdrop:CreateTexture(nil, "BACKGROUND", nil, -8)
        fill:SetAllPoints(customizeBackdrop)
        fill:SetColorTexture(0, 0, 0, CUSTOMIZE_WORLD_DIM_ALPHA)
    end
    customizeBackdrop:Show()
end

function EditorController.UpdateActiveInspectorGeometry()
    local inspector = EditorController.GetActiveInspectorHost()
    if not inspector or not inspector.frame then
        return
    end

    -- Shell/composition can rewrite Window.content; the shared geometry runs last.
    local workspaceChanged = ApplyInspectorShellComposition(inspector)
    if workspaceChanged then EditorController.RefreshCompositionTree() end
    UpdateCustomizeBackdrop(inspector)
end

function EditorController.ReleaseInspector()
    if customizeBackdrop then customizeBackdrop:Hide() end
    local inspector = EditorController.GetActiveInspectorHost()
    if not inspector then
        return
    end

    if inspector.frame and inspector.frame.Hide then
        inspector.frame:Hide()
    end

    ns.guiEditorInspectorHost = nil
    ns.GUI.Editor._activeInspectorHost = nil
    ns.GUI.Editor._activeInspector = nil
    ns.GUI.Editor._activeInspectorRefreshProperties = nil
    ns.GUI.Editor._activeInspectorRefreshTree = nil
end

function EditorController.RefreshCompositionTree()
    local refresh = ns.GUI.Editor._activeInspectorRefreshTree
    if refresh then refresh() end
end

function EditorController.RefreshActiveProperties()
    local stateApi = ns.GUI.Editor.State
    if stateApi and stateApi.IsArrange and stateApi.IsArrange() then
        return false
    end
    local refreshProperties = ns.GUI
        and ns.GUI.Editor
        and ns.GUI.Editor._activeInspectorRefreshProperties
        or nil
    if type(refreshProperties) ~= "function" then
        return false
    end
    refreshProperties()
    return true
end

function EditorController.SetPresentation(presentation)
    local stateApi = ns.GUI.Editor.State
    if not (stateApi and stateApi.SetPresentation and stateApi.SetPresentation(presentation)) then
        return false
    end
    if stateApi.IsArrange() then
        EditorController.ReleaseInspector()
    end
    -- Re-evaluate current regular alpha for active frames; never restore a cache.
    if ns.UnitFrame and ns.UnitFrame.ApplyRangeFade then
        for _, frame in pairs(ns.frames or {}) do
            ns.UnitFrame:ApplyRangeFade(frame)
        end
    end
    if ns.GUI.RequestRefreshOptions then
        ns.GUI:RequestRefreshOptions("Editor.Presentation")
    end
    return true
end

local function RefreshUnitRuntime(unitKey)
    if not (ns.RefreshUnitFrame and type(unitKey) == "string" and unitKey ~= "") then
        return
    end
    ns:RefreshUnitFrame(unitKey == "boss" and "boss" or unitKey)
end

local function RefreshSelectedUnitRuntime()
    local stateApi = ns.GUI and ns.GUI.Editor and ns.GUI.Editor.State
    local state = stateApi and type(stateApi.Get) == "function" and stateApi.Get() or nil
    RefreshUnitRuntime(state and state.selectedUnit or nil)
end

function EditorController.ApplyObjectSelectionProjection(changeKind, previousUnit, previousObject, nextKind, selectionContext)
    if ns.RefreshEditorInteractionVisuals then
        ns:RefreshEditorInteractionVisuals()
    elseif ns.RefreshEditorSelectionVisuals then
        ns:RefreshEditorSelectionVisuals()
    end

    local stateApi = ns.GUI and ns.GUI.Editor and ns.GUI.Editor.State or nil
    local state = stateApi and type(stateApi.Get) == "function" and stateApi.Get() or nil
    local selectedUnit = state and state.selectedUnit or nil
    if type(previousUnit) == "string" and previousUnit ~= selectedUnit then
        RefreshUnitRuntime(previousUnit)
    end
    RefreshSelectedUnitRuntime()

    if stateApi and stateApi.IsArrange and stateApi.IsArrange() then
        return
    end

    if changeKind == "sameUnitObject" then
        EditorController.RefreshActiveProperties()
        local inspector = EditorController.GetActiveInspectorHost()
        if inspector and inspector._focalPointSetCustomizeView then
            inspector._focalPointSetCustomizeView(nextKind == "unit" and previousObject
                and previousObject.kind ~= "unit" and "components" or "properties")
        end
        local treeView = ns.CompositionTreeView or (ns.GUI and ns.GUI.Editor and ns.GUI.Editor.Composition and ns.GUI.Editor.Composition.TreeView) or nil
        if treeView and type(treeView.RefreshKeyboardBinding) == "function" then
            treeView.RefreshKeyboardBinding()
        end
        return
    end

    if selectionContext and selectionContext.surfaceRefreshOwnedByCaller == true
        and changeKind == "unitChanged" and nextKind == "unit"
        and previousObject and previousObject.kind == "unit"
    then
        -- The SelectEditorUnit owner requests the surface after its final projection.
        return true
    end
    if ns.GUI and ns.GUI.RequestRefreshOptions then
        ns.GUI:RequestRefreshOptions("EditorController.ObjectSelection")
    end
end

local function EnsureInspector()
    local inspector = GetPersistentInspector()
    if inspector and inspector.frame then
        return inspector
    end

    inspector = AceGUI:Create("Window")
    local content = inspector.content
    local contentPoints = {}
    for i = 1, content:GetNumPoints() do contentPoints[i] = {content:GetPoint(i)} end
    local contentSize = {content:GetWidth(), content:GetHeight(), content.width, content.height}
    local drag = inspector.title
    local dragPoints = {}
    local dragSize = drag and {drag:GetWidth(), drag:GetHeight()}
    if drag then
        for i = 1, drag:GetNumPoints() do dragPoints[i] = {drag:GetPoint(i)} end
    end
    local title = inspector.titletext
    local titleFont = title and {title:GetFont()}
    local titleFontObject = title and title.GetFontObject and title:GetFontObject()
    local titleColor = title and {title:GetTextColor()}
    local titleJustify = title and title.GetJustifyH and title:GetJustifyH() or "LEFT"
    local titlePoints = {}
    if title then
        for i = 1, title:GetNumPoints() do titlePoints[i] = {title:GetPoint(i)} end
    end
    local closeScript = inspector.closebutton and inspector.closebutton:GetScript("OnClick")
    local geometry = ComputeInspectorGeometry()
    inspector:SetTitle("Inspector")
    inspector:SetWidth(geometry.width)
    inspector:SetHeight(geometry.height)
    inspector:SetLayout("Fill")
    inspector:EnableResize(false)
    inspector._focalPointEditorRole = "editor_inspector"

    local inspectorContent = AceGUI:Create("SimpleGroup")
    inspectorContent:SetFullWidth(true)
    inspectorContent:SetFullHeight(true)
    inspectorContent:SetLayout("Fill")
    inspector:AddChild(inspectorContent)
    inspector._focalPointInspectorContent = inspectorContent

    if inspector.frame then
        local anchorHost = GetEditorPresentationAnchor()
        if inspector.frame.SetParent then
            inspector.frame:SetParent(anchorHost)
        end
        if inspector.frame.SetFrameStrata then
            inspector.frame:SetFrameStrata("FULLSCREEN_DIALOG")
        end
        if inspector.frame.SetToplevel then
            inspector.frame:SetToplevel(true)
        end
        if inspector.frame.SetClampedToScreen then
            inspector.frame:SetClampedToScreen(true)
        end
        if inspector.closebutton and inspector.closebutton.Show then
            inspector.closebutton:Show()
            inspector.closebutton:SetScript("OnClick", function()
                if EditorController.GetActiveInspectorHost() == inspector then EditorController.SetPresentation("arrange") end
            end)
        end

        if ApplySidebarChrome then
            ApplySidebarChrome(inspector, "inspector_shell")
            FormWidgets.BindNavigatorBrassWindow(inspector, "inspector_shell")
            local composition = ns.GUI.PresentationCompositionPreview
            if composition then
                composition.Bind("inspector_shell", inspector, ApplyInspectorShellComposition)
            end
            ApplyInspectorShellComposition(inspector)
        end
    end

    if inspector.frame and inspectorContent.frame and not inspector._focalPointInspectorInset then
        local inspectorInset = CreateFrame("Frame", nil, inspector.frame)
        inspector._focalPointInspectorInset = inspectorInset

        inspectorContent.frame:ClearAllPoints()
        inspectorContent.frame:SetParent(inspectorInset)
        inspectorContent.frame:SetPoint("TOPLEFT", inspectorInset, "TOPLEFT", 0, 0)
        inspectorContent.frame:SetPoint("BOTTOMRIGHT", inspectorInset, "BOTTOMRIGHT", 0, 0)
    end

    ApplyInspectorGeometry(inspector, geometry)
    inspector.frame:HookScript("OnShow", function() UpdateCustomizeBackdrop(inspector) end)
    inspector.frame:HookScript("OnHide", function() if customizeBackdrop then customizeBackdrop:Hide() end end)
    local release = inspector.events and inspector.events.OnRelease
    inspector:SetCallback("OnRelease", function(owner, event)
        if release then release(owner, event) end
        content:ClearAllPoints()
        for _, point in ipairs(contentPoints) do content:SetPoint(unpack(point)) end
        content:SetWidth(contentSize[1]); content:SetHeight(contentSize[2])
        content.width, content.height = contentSize[3], contentSize[4]
        if drag then
            drag:ClearAllPoints()
            drag:SetSize(unpack(dragSize))
            for _, point in ipairs(dragPoints) do drag:SetPoint(unpack(point)) end
        end
        if title then
            if titleFontObject then title:SetFontObject(titleFontObject) end
            title:SetFont(unpack(titleFont))
            title:SetTextColor(unpack(titleColor))
            title:SetJustifyH(titleJustify)
            title:ClearAllPoints()
            for _, point in ipairs(titlePoints) do title:SetPoint(unpack(point)) end
        end
        if owner.closebutton then owner.closebutton:SetScript("OnClick", closeScript) end
        if EditorController.GetActiveInspectorHost() == owner then EditorController.ReleaseInspector() end
        if GetPersistentInspector() == owner then SetPersistentInspector(nil) end
    end)
    SetPersistentInspector(inspector)
    return inspector
end

function EditorController.BuildInspector(container, deps)
    local stateApi = ns.GUI.Editor.State
    if stateApi and stateApi.IsArrange and stateApi.IsArrange() then
        EditorController.ReleaseInspector()
        return
    end
    local state = deps.GetEditorState()
    local Inspector = ns.GUI and ns.GUI.Editor and ns.GUI.Editor.Inspector
    local inspector = EnsureInspector()
    local inspectorContent = inspector and inspector._focalPointInspectorContent
    if not inspector or not inspectorContent then
        return
    end
    local resolver = ns.ActiveLayoutResolver
    local runtimeRoot = resolver and resolver.GetActiveRuntimeRoot and resolver.GetActiveRuntimeRoot()
    if EditorController.GetActiveInspectorHost() ~= inspector
        or inspector._focalPointCustomizeUnit ~= state.selectedUnit
        or inspector._focalPointCustomizeRoot ~= runtimeRoot then
        inspector._focalPointCustomizeView = "components"
    end
    inspector._focalPointCustomizeUnit, inspector._focalPointCustomizeRoot = state.selectedUnit, runtimeRoot

    ns.GUI.Editor._inspectorBuildSerial = (ns.GUI.Editor._inspectorBuildSerial or 0) + 1
    local buildSerial = ns.GUI.Editor._inspectorBuildSerial

    EditorController.SetActiveInspectorHost(inspector)

    if inspectorContent.ReleaseChildren then
        inspectorContent:ReleaseChildren()
    end

    EditorController.UpdateActiveInspectorGeometry()
    if inspector.frame and inspector.frame.Show then
        inspector.frame:Show()
        inspector.frame:Raise()
    end
    UpdateCustomizeBackdrop(inspector)
    local function IsCurrentBuild()
        return ns.GUI.Editor._inspectorBuildSerial == buildSerial
            and EditorController.GetActiveInspectorHost() == inspector
            and not (stateApi and stateApi.IsArrange and stateApi.IsArrange())
    end

    local unitLabel = ns.GetLabel and ns.KeyMap and ns.KeyMap.Units
        and ns.GetLabel(ns.KeyMap.Units, state.selectedUnit) or state.selectedUnit
    inspector:SetTitle(string.format(ns.L and ns.L.EDITOR_CUSTOMIZE_FRAME or "Customize %s Frame", unitLabel or ""))
    ApplyCustomizeTitle(inspector)
    if inspector.titletext then inspector.titletext:Show() end
    if inspector.closebutton then inspector.closebutton:Show() end

    state.editorSidebarScroll = state.editorSidebarScroll or { scrollvalue = 0 }
    local propertyScrollWidget

    local function ResetPropertyScroll()
        state.editorSidebarScroll.scrollvalue = 0
        state.editorSidebarScroll.offset = nil
        state.editorSidebarScroll.visibleAnchorSectionKey = nil
        state.editorSidebarScroll.visibleAnchorRole = nil
        state.editorSidebarScroll.visibleAnchorChildIndex = nil
        state.editorSidebarScroll.visibleAnchorChildKey = nil
        state.editorSidebarScroll.visibleAnchorOffset = nil
        if propertyScrollWidget and propertyScrollWidget.SetScroll then
            propertyScrollWidget:SetScroll(0)
        end
    end

    local function GetScrollWidget()
        if propertyScrollWidget then
            return propertyScrollWidget
        end
        if not inspectorContent or not inspectorContent.children then
            return nil
        end

        return inspectorContent.children[1]
    end

    local GetClampedSidebarScrollValue

    local function FindSectionWidget(scrollWidget, sectionKey, sectionRole)
        if type(sectionKey) ~= "string" or sectionKey == "" or not scrollWidget or type(scrollWidget.children) ~= "table" then
            return nil
        end

        for _, child in ipairs(scrollWidget.children) do
            if child and child.GetUserData and child:GetUserData("focalPointSectionKey") == sectionKey then
                if sectionRole == nil or child:GetUserData("focalPointSectionRole") == sectionRole then
                    return child
                end
            end
        end

        if sectionRole ~= nil then
            for _, child in ipairs(scrollWidget.children) do
                if child and child.GetUserData and child:GetUserData("focalPointSectionKey") == sectionKey then
                    return child
                end
            end
        end

        return nil
    end

    local function GetVisibleAnchorCandidate(scrollWidget, child, visibleTop, visibleBottom)
        if not child or not child.GetUserData or not child.frame or not child.frame.IsShown or not child.frame:IsShown()
            or not child.frame.GetTop or not child.frame.GetBottom
        then
            return nil
        end

        local sectionKey = child:GetUserData("focalPointSectionKey")
        local sectionRole = child:GetUserData("focalPointSectionRole") or "header"
        if type(sectionKey) ~= "string" or sectionKey == "" then
            return nil
        end

        local top = child.frame:GetTop()
        local bottom = child.frame:GetBottom()
        if not top or not bottom or bottom > visibleTop or top < visibleBottom then
            return nil
        end

        local offset = visibleTop - top
        return {
            sectionKey = sectionKey,
            sectionRole = sectionRole,
            offset = offset,
            distance = math.abs(offset),
        }
    end

    local function GetVisibleChildAnchorCandidate(contentWidget, visibleTop, visibleBottom)
        if not contentWidget or type(contentWidget.children) ~= "table" then
            return nil
        end

        local bestCandidate
        for index, child in ipairs(contentWidget.children) do
            if child and child.frame and child.frame.IsShown and child.frame:IsShown()
                and child.frame.GetTop and child.frame.GetBottom
            then
                local top = child.frame:GetTop()
                local bottom = child.frame:GetBottom()
                if top and bottom and bottom <= visibleTop and top >= visibleBottom then
                    local offset = visibleTop - top
                    local candidate = {
                        sectionKey = contentWidget:GetUserData("focalPointSectionKey"),
                        sectionRole = "child",
                        childIndex = index,
                        anchorKey = child.GetUserData and child:GetUserData("focalPointAnchorKey") or nil,
                        offset = offset,
                        distance = math.abs(offset),
                    }
                    if not bestCandidate or candidate.distance < bestCandidate.distance then
                        bestCandidate = candidate
                    end
                end
            end
        end

        return bestCandidate
    end

    local function CaptureVisibleSectionAnchor(scrollWidget)
        if not scrollWidget or not scrollWidget.frame or type(scrollWidget.children) ~= "table"
            or not scrollWidget.frame.GetTop or not scrollWidget.frame.GetBottom
        then
            state.editorSidebarScroll.visibleAnchorSectionKey = nil
            state.editorSidebarScroll.visibleAnchorRole = nil
            state.editorSidebarScroll.visibleAnchorChildIndex = nil
            state.editorSidebarScroll.visibleAnchorChildKey = nil
            state.editorSidebarScroll.visibleAnchorOffset = nil
            return
        end

        local visibleTop = scrollWidget.frame:GetTop()
        local visibleBottom = scrollWidget.frame:GetBottom()
        if not visibleTop or not visibleBottom then
            state.editorSidebarScroll.visibleAnchorSectionKey = nil
            state.editorSidebarScroll.visibleAnchorRole = nil
            state.editorSidebarScroll.visibleAnchorChildIndex = nil
            state.editorSidebarScroll.visibleAnchorChildKey = nil
            state.editorSidebarScroll.visibleAnchorOffset = nil
            return
        end

        local bestCandidate
        for _, child in ipairs(scrollWidget.children) do
            local candidate = GetVisibleAnchorCandidate(scrollWidget, child, visibleTop, visibleBottom)
            if candidate then
                if candidate.sectionRole == "content" then
                    local childCandidate = GetVisibleChildAnchorCandidate(child, visibleTop, visibleBottom)
                    if childCandidate then
                        candidate = childCandidate
                    end
                end

                if not bestCandidate
                    or candidate.distance < bestCandidate.distance
                    or (candidate.distance == bestCandidate.distance and candidate.sectionRole == "child" and bestCandidate.sectionRole ~= "child")
                    or (candidate.distance == bestCandidate.distance and candidate.sectionRole == "content" and bestCandidate.sectionRole == "header")
                then
                    bestCandidate = candidate
                end
            end
        end

        state.editorSidebarScroll.visibleAnchorSectionKey = bestCandidate and bestCandidate.sectionKey or nil
        state.editorSidebarScroll.visibleAnchorRole = bestCandidate and bestCandidate.sectionRole or nil
        state.editorSidebarScroll.visibleAnchorChildIndex = bestCandidate and bestCandidate.childIndex or nil
        state.editorSidebarScroll.visibleAnchorChildKey = bestCandidate and bestCandidate.anchorKey or nil
        state.editorSidebarScroll.visibleAnchorOffset = bestCandidate and bestCandidate.offset or nil
    end

    local function CaptureSidebarScroll()
        local scrollWidget = GetScrollWidget()
        if not scrollWidget then
            return
        end

        CaptureVisibleSectionAnchor(scrollWidget)

        if scrollWidget.scrollbar and scrollWidget.scrollbar.GetValue then
            state.editorSidebarScroll.scrollvalue = scrollWidget.scrollbar:GetValue() or state.editorSidebarScroll.scrollvalue or 0
        end

        local status = scrollWidget.status or scrollWidget.localstatus
        if status then
            if state.editorSidebarScroll.scrollvalue == nil and status.scrollvalue ~= nil then
                state.editorSidebarScroll.scrollvalue = status.scrollvalue
            end

            if status.offset ~= nil then
                state.editorSidebarScroll.offset = status.offset
            end
            return
        end
    end

    local function ApplyVisibleSectionAnchor(scrollWidget)
        local sectionKey = state.editorSidebarScroll.visibleAnchorSectionKey
        local sectionRole = state.editorSidebarScroll.visibleAnchorRole
        local childIndex = state.editorSidebarScroll.visibleAnchorChildIndex
        local childKey = state.editorSidebarScroll.visibleAnchorChildKey
        if type(sectionKey) ~= "string" or sectionKey == "" or not scrollWidget or not scrollWidget.frame
            or not scrollWidget.frame.GetTop
        then
            return false
        end

        local sectionWidget
        if sectionRole == "child" then
            local contentWidget = FindSectionWidget(scrollWidget, sectionKey, "content")
            if contentWidget and type(contentWidget.children) == "table" then
                if type(childKey) == "string" and childKey ~= "" then
                    for _, child in ipairs(contentWidget.children) do
                        if child and child.GetUserData and child:GetUserData("focalPointAnchorKey") == childKey then
                            sectionWidget = child
                            break
                        end
                    end
                end

                if (not sectionWidget or not sectionWidget.frame or not sectionWidget.frame.GetTop) and type(childIndex) == "number" then
                    sectionWidget = contentWidget.children[childIndex]
                end
            end

            if not sectionWidget or not sectionWidget.frame or not sectionWidget.frame.GetTop then
                sectionWidget = FindSectionWidget(scrollWidget, sectionKey, "content")
            end

            if not sectionWidget or not sectionWidget.frame or not sectionWidget.frame.GetTop then
                sectionWidget = FindSectionWidget(scrollWidget, sectionKey, "header")
            end
        else
            sectionWidget = FindSectionWidget(scrollWidget, sectionKey, sectionRole)
        end

        if not sectionWidget or not sectionWidget.frame or not sectionWidget.frame.GetTop then
            return false
        end

        local visibleTop = scrollWidget.frame:GetTop()
        local anchorTop = sectionWidget.frame:GetTop()
        if not visibleTop or not anchorTop then
            return false
        end

        local currentScroll = GetClampedSidebarScrollValue(scrollWidget)
        local currentOffset = visibleTop - anchorTop
        local targetOffset = tonumber(state.editorSidebarScroll.visibleAnchorOffset)
        if not targetOffset then
            return false
        end

        state.editorSidebarScroll.scrollvalue = currentScroll + (currentOffset - targetOffset)
        return true
    end

    GetClampedSidebarScrollValue = function(scrollWidget)
        local value = tonumber(state.editorSidebarScroll.scrollvalue) or 0
        if not scrollWidget or not scrollWidget.scrollbar or not scrollWidget.scrollbar.GetMinMaxValues then
            return value
        end

        local minValue, maxValue = scrollWidget.scrollbar:GetMinMaxValues()
        minValue = tonumber(minValue) or 0
        maxValue = tonumber(maxValue) or value

        if value < minValue then
            return minValue
        end

        if value > maxValue then
            return maxValue
        end

        return value
    end

    local function RestoreSidebarScroll()
        local scrollWidget = GetScrollWidget()
        if not scrollWidget then
            return
        end

        ApplyVisibleSectionAnchor(scrollWidget)

        local scrollValue = GetClampedSidebarScrollValue(scrollWidget)
        state.editorSidebarScroll.scrollvalue = scrollValue

        local status = scrollWidget.status or scrollWidget.localstatus
        if status then
            status.scrollvalue = scrollValue
            status.offset = nil
        end

        if scrollWidget.SetScroll then
            scrollWidget:SetScroll(scrollValue)
        end

        if scrollWidget.scrollbar and scrollWidget.scrollbar.SetValue then
            scrollWidget.scrollbar:SetValue(scrollValue)
        end

        if scrollWidget.FixScroll then
            scrollWidget:FixScroll()
        end
    end

    local function ScheduleSidebarScrollRestore(buildSerial)
        if not C_Timer or not C_Timer.After then
            return
        end

        local restoreDelays = { 0, 0.05, 0.15 }
        for _, delay in ipairs(restoreDelays) do
            C_Timer.After(delay, function()
                if ns.GUI and ns.GUI.Editor and ns.GUI.Editor._inspectorBuildSerial == buildSerial
                    and EditorController.GetActiveInspectorHost() == inspector
                then
                    RestoreSidebarScroll()
                end
            end)
        end
    end

    local function RefreshLiveUnit(unitKey)
        if not ns.RefreshUnitFrame then
            return
        end

        if unitKey == "boss" then
            ns:RefreshUnitFrame("boss")
        else
            ns:RefreshUnitFrame(unitKey)
        end
    end

    local function SyncUnitFrameLifecycle()
        if ns.RebuildFramesForActiveProfile then
            ns:RebuildFramesForActiveProfile()
        else
            RefreshLiveUnit(state.selectedUnit)
        end
    end

    local function BuildInspectorCallbacks(rebuildContext, rebuildSidebar, refreshProperties)
        return {
            isCurrentBuild = IsCurrentBuild,
            onPropertyGroupChanged = ResetPropertyScroll,
            onConfigChanged = function()
                RefreshLiveUnit(state.selectedUnit)
            end,
            onCompositionTreeChanged = function()
                EditorController.RefreshCompositionTree()
            end,
            onUnitEnabledChanged = function()
                SyncUnitFrameLifecycle()
            end,
            onSidebarChanged = function()
                RefreshLiveUnit(state.selectedUnit)
                rebuildSidebar()
            end,
            onSelectionChanged = function(changeKind)
                if changeKind == "sameUnitObject" and type(refreshProperties) == "function" then
                    refreshProperties()
                    return
                end
                RefreshLiveUnit(state.selectedUnit)
                rebuildSidebar()
            end,
            onContextChanged = rebuildContext,
        }
    end

    local function BuildPropertyInspectorContent(rebuildSidebar)
        inspectorContent:ReleaseChildren()
        local workspaceActive = true
        local function IsCurrentWorkspace() return workspaceActive and IsCurrentBuild() end
        -- Only these local views own their anchors; AceGUI still owns release.
        inspectorContent:PauseLayout()

        local geometry = ComputeInspectorGeometry(inspector._focalPointCustomizeView)
        local propertyHeight = geometry.workspaceHeight

        local header = AceGUI:Create("SimpleGroup")
        header:SetWidth(geometry.contentWidth)
        header:SetHeight(30)
        header:SetAutoAdjustHeight(false)
        header:SetLayout("Table")
        local componentsText = ns.L and ns.L.EDITOR_COMPONENTS or "Components"
        local back = AceGUI:Create("Button")
        back:SetText(ns.L and ns.L.EDITOR_BACK_TO_COMPONENTS or "<- Back")
        local backWidth = 110
        back:SetWidth(backWidth)
        back:SetHeight(30)
        local backFont, _, backFlags = back.text:GetFont()
        back.text:SetFont(backFont, 13, backFlags)
        back.text:SetJustifyH("CENTER")
        back.text:SetJustifyV("MIDDLE")
        header:SetUserData("table", {columns={backWidth,{weight=1}},spaceH=4,spaceV=0,alignH="start",alignV="center"})
        header:SetCallback("OnRelease", function() workspaceActive = false end)
        inspectorContent:AddChild(header)
        header.frame:ClearAllPoints()
        header.frame:SetPoint("TOPLEFT", inspectorContent.frame, "TOPLEFT", 0, 0)
        header:AddChild(back)
        local componentsLabel = AceGUI:Create("Label")
        componentsLabel:SetText(componentsText)
        componentsLabel:SetFullWidth(true)
        componentsLabel:SetUserData("cell", {colspan=2})
        FormWidgets.ApplyTextStyle(componentsLabel.label, "strongHeading", 14, 1)
        componentsLabel.label:SetWordWrap(false)
        componentsLabel.label:SetMaxLines(1)
        header:AddChild(componentsLabel)
        local contextLabel = AceGUI:Create("Label")
        contextLabel:SetWidth(math.max(1, geometry.contentWidth - backWidth - 4 - 32))
        contextLabel:SetUserData("cell", {alignH="start",alignV="center"})
        FormWidgets.ApplyTextStyle(contextLabel.label, "identity", 13, 1)
        contextLabel.label:SetWordWrap(false)
        contextLabel.label:SetMaxLines(1)
        contextLabel.label:SetJustifyH("RIGHT")
        contextLabel.label:SetJustifyV("MIDDLE")
        header:AddChild(contextLabel)
        inspector._focalPointObjectBreadcrumb = contextLabel
        inspector._focalPointComponentsButton = back
        inspector._focalPointArrangeButton, inspector._focalPointCloseButton = nil, nil

        local treeHost = AceGUI:Create("SimpleGroup")
        treeHost:SetWidth(math.min(COMPONENT_LIST_WIDTH, geometry.contentWidth))
        treeHost:SetHeight(geometry.componentHeight)
        treeHost:SetLayout("List")
        treeHost:SetAutoAdjustHeight(false)
        inspectorContent:AddChild(treeHost)
        treeHost.frame:ClearAllPoints()
        treeHost.frame:SetPoint("TOPLEFT", inspectorContent.frame, "TOPLEFT", 0, -geometry.componentTop)
        local treeContext = {state = state, widgets = {compositionTree = treeHost},
            treeHeight = geometry.componentHeight, isCurrent = IsCurrentWorkspace}
        local toolbar=ns.GUI.Editor.CanvasToolbar
        treeContext.canAdd=function(ref)
            if ref and ref.kind == "unit" then return toolbar and toolbar.OpenComponentAdd ~= nil or false end
            return toolbar and toolbar.CanAddComponentAt and toolbar.CanAddComponentAt(ref) or false
        end
        treeContext.canRemove=function(ref)
            local mutations = ns.InspectorMutations
            return mutations and mutations.CanRemoveObject and mutations.CanRemoveObject(ref) or false
        end
        treeContext.onAdd=function(ref,isCurrentRow,displayName)
            if ref.kind == "unit" then
                if toolbar and toolbar.OpenComponentAdd then
                    toolbar.OpenComponentAdd(ref,function()return IsCurrentWorkspace() and isCurrentRow()end,displayName)
                end
                return
            end
            if toolbar and toolbar.OpenComponentCatalog then
                toolbar.OpenComponentCatalog(ref,function()return IsCurrentWorkspace() and isCurrentRow()end,displayName)
            end
        end
        treeContext.onRemove=function(ref,isCurrentRow,displayName)
            if toolbar and toolbar.OpenComponentRemove then
                toolbar.OpenComponentRemove(ref,function()return IsCurrentWorkspace() and isCurrentRow()end,displayName)
            end
        end
        local function RefreshTree()
            if not IsCurrentWorkspace() then return end
            treeContext.treeHeight = treeHost.frame:GetHeight()
            local binding = ns.GUI.Editor.ToolbarBinding
            if binding and binding.RefreshCompositionTree then
                binding.RefreshCompositionTree(treeContext, {ns = ns})
            end
        end
        ns.GUI.Editor._activeInspectorRefreshTree = RefreshTree
        inspector._focalPointCompositionHost = treeHost

        local root = AceGUI:Create("SimpleGroup")
        root:SetWidth(geometry.contentWidth)
        root:SetHeight(propertyHeight)
        root:SetAutoAdjustHeight(false)
        root:SetLayout("Flow")
        inspectorContent:AddChild(root)
        root.frame:ClearAllPoints()
        root.frame:SetPoint("TOPLEFT", inspectorContent.frame, "TOPLEFT", 0, -geometry.workspaceTop)

        propertyScrollWidget = AceGUI:Create("ScrollFrame")
        propertyScrollWidget:SetLayout("Flow")
        propertyScrollWidget:SetFullWidth(true)
        propertyScrollWidget:SetHeight(propertyHeight)
        propertyScrollWidget:SetStatusTable(state.editorSidebarScroll)
        root:AddChild(propertyScrollWidget)
        inspector._focalPointPropertyScroll = propertyScrollWidget
        inspector._focalPointComponentAddButton=nil
        local function SetView(view)
            if not IsCurrentWorkspace() then return end
            local treeView = ns.CompositionTreeView
            local node = treeView and treeView.GetSelectedNode and treeView.GetSelectedNode()
            local selection = ns.GUI.Editor.ObjectSelection
            local selected = selection and selection.GetSelectedObject and selection.GetSelectedObject()
            if view ~= "properties" or not node or not selected or selected.unavailable then view = "components" end
            inspector._focalPointCustomizeView = view
            ApplyInspectorGeometry(inspector, ComputeInspectorGeometry(view))
            header.frame:Show()
            back:SetDisabled(view ~= "properties")
            back.frame:SetShown(view == "properties")
            componentsLabel.frame:SetShown(view == "components")
            contextLabel.frame:SetShown(view == "properties")
            contextLabel:SetText(view == "properties" and (node.label or "") or "")
            header:DoLayout()
            treeHost.frame:SetShown(view == "components")
            root.frame:SetShown(view == "properties")
            if treeView and treeView._keyboardBindingContext and view == "properties" then
                treeView._keyboardBindingContext.control:SetKeyboardActive(false)
            end
        end
        inspector._focalPointSetCustomizeView = SetView
        back:SetCallback("OnClick", function() SetView("components") end)
        treeContext.onSelect = function() SetView("properties") end
        -- Bind the callback through the existing TreeView option contract.
        RefreshTree()

        local function RebuildProperties()
            if not IsCurrentWorkspace() or not propertyScrollWidget then
                return
            end

            ResetPropertyScroll()

            Inspector.BuildProperties(propertyScrollWidget, state, BuildInspectorCallbacks(nil, rebuildSidebar, RebuildProperties))
            if propertyScrollWidget.DoLayout then
                propertyScrollWidget:DoLayout()
            end
            if propertyScrollWidget.FixScroll then
                propertyScrollWidget:FixScroll()
            end
            if root.DoLayout then
                root:DoLayout()
            end
            if inspectorContent.DoLayout then
                inspectorContent:DoLayout()
            end
            SetView(inspector._focalPointCustomizeView)
        end

        ns.GUI.Editor._activeInspectorRefreshProperties = RebuildProperties
        Inspector.BuildProperties(propertyScrollWidget, state, BuildInspectorCallbacks(nil, rebuildSidebar, RebuildProperties))

        if propertyScrollWidget.DoLayout then
            propertyScrollWidget:DoLayout()
        end
        if propertyScrollWidget.FixScroll then
            propertyScrollWidget:FixScroll()
        end
        if root.DoLayout then
            root:DoLayout()
        end
        if inspectorContent.DoLayout then
            inspectorContent:DoLayout()
        end
        SetView(inspector._focalPointCustomizeView)
    end

    local RebuildSidebar
    RebuildSidebar = function()
        if not IsCurrentBuild() then return end
        CaptureSidebarScroll()
        BuildPropertyInspectorContent(RebuildSidebar)
        RestoreSidebarScroll()
        ScheduleSidebarScrollRestore(buildSerial)
    end

    RebuildSidebar()
    return inspector
end

return EditorController

