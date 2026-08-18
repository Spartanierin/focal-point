local _, ns = ...

ns.GUI = ns.GUI or {}
ns.GUI.Editor = ns.GUI.Editor or {}

local AceGUI = LibStub("AceGUI-3.0")
local EditorController = {}
ns.GUI.Editor.Controller = EditorController
local FormWidgets = ns.GUI.Helpers and ns.GUI.Helpers.FormWidgets
local ApplySidebarChrome = FormWidgets and FormWidgets.ApplySidebarChrome
local SidebarGeometry = ns.GUI.Editor and ns.GUI.Editor.SidebarGeometry

local INSPECTOR_WIDTH = (SidebarGeometry and SidebarGeometry.width) or 285
local INSPECTOR_OFFSET_X = -16
local INSPECTOR_OFFSET_Y = -120

local function GetEditorPresentationAnchor()
    return UIParent
end

local function ComputeInspectorGeometry()
    local width = INSPECTOR_WIDTH
    local height = (UIParent and UIParent.GetHeight and UIParent:GetHeight()) or 760
    local insetLeft = 16
    local insetRight = 16
    local insetTop = 10
    local insetBottom = 10

    return {
        width = width,
        height = height,
        anchorHost = GetEditorPresentationAnchor(),
        point = "TOPRIGHT",
        relativePoint = "TOPRIGHT",
        offsetX = (SidebarGeometry and SidebarGeometry.right) or 0,
        offsetY = (SidebarGeometry and SidebarGeometry.top) or 0,
        insetLeft = insetLeft,
        insetRight = insetRight,
        insetTop = insetTop,
        insetBottom = insetBottom,
        contentWidth = width - insetLeft - insetRight,
        contentHeight = height - insetTop - insetBottom,
    }
end

local function ApplyInspectorGeometry(inspector, geometry)
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
    inspector.frame:ClearAllPoints()
    inspector.frame:SetPoint(
        geometry.point,
        anchorHost,
        geometry.relativePoint,
        geometry.offsetX,
        geometry.offsetY
    )

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
    end
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

function EditorController.UpdateActiveInspectorGeometry()
    local inspector = EditorController.GetActiveInspectorHost()
    if not inspector or not inspector.frame then
        return
    end

    ApplyInspectorGeometry(inspector, ComputeInspectorGeometry())
end

function EditorController.ReleaseInspector()
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
end

local function EnsureInspector()
    local inspector = GetPersistentInspector()
    if inspector and inspector.frame then
        return inspector
    end

    inspector = AceGUI:Create("Window")
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
        if inspector.titletext and inspector.titletext.Hide then
            inspector.titletext:Hide()
        end
        if inspector.closebutton and inspector.closebutton.Hide then
            inspector.closebutton:Hide()
        end

        if ApplySidebarChrome then
            ApplySidebarChrome(inspector)
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
    SetPersistentInspector(inspector)
    return inspector
end

function EditorController.BuildInspector(container, deps)
    local state = deps.GetEditorState()
    local BuildScrollableTabContent = deps.BuildScrollableTabContent
    local Inspector = ns.GUI and ns.GUI.Editor and ns.GUI.Editor.Inspector
    local inspector = EnsureInspector()
    local inspectorContent = inspector and inspector._focalPointInspectorContent
    if not inspector or not inspectorContent then
        return
    end

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
    if C_Timer and C_Timer.After then
        C_Timer.After(0, function()
            if ns.GUI and ns.GUI.Editor and ns.GUI.Editor._inspectorBuildSerial == buildSerial
                and EditorController.GetActiveInspectorHost() == inspector
            then
                EditorController.UpdateActiveInspectorGeometry()
            end
        end)
        C_Timer.After(0.05, function()
            if ns.GUI and ns.GUI.Editor and ns.GUI.Editor._inspectorBuildSerial == buildSerial
                and EditorController.GetActiveInspectorHost() == inspector
            then
                EditorController.UpdateActiveInspectorGeometry()
            end
        end)
    end

    state.editorSidebarScroll = state.editorSidebarScroll or { scrollvalue = 0 }

    local function GetScrollWidget()
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

    local RebuildSidebar
    RebuildSidebar = function()
        CaptureSidebarScroll()

        if BuildScrollableTabContent then
            BuildScrollableTabContent(inspectorContent, state.editorSidebarScroll, function(content)
                Inspector.Build(content, state, {
                    onConfigChanged = function()
                        RefreshLiveUnit(state.selectedUnit)
                    end,
                    onUnitEnabledChanged = function()
                        SyncUnitFrameLifecycle()
                    end,
                    onSidebarChanged = function()
                        RefreshLiveUnit(state.selectedUnit)
                        RebuildSidebar()
                    end,
                })
            end)
            RestoreSidebarScroll()
            ScheduleSidebarScrollRestore(buildSerial)
            return
        end

        Inspector.Build(inspector, state, {
            onConfigChanged = function()
                RefreshLiveUnit(state.selectedUnit)
            end,
            onUnitEnabledChanged = function()
                SyncUnitFrameLifecycle()
            end,
            onSidebarChanged = function()
                RefreshLiveUnit(state.selectedUnit)
                RebuildSidebar()
            end,
        })
        RestoreSidebarScroll()
        ScheduleSidebarScrollRestore(buildSerial)
    end

    RebuildSidebar()
    return inspector
end

return EditorController

