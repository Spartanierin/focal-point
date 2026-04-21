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

    local targetWidth = INSPECTOR_WIDTH
    local targetHeight = (UIParent and UIParent.GetHeight and UIParent:GetHeight()) or 760

    if inspector.SetWidth then
        inspector:SetWidth(targetWidth)
    end
    if inspector.SetHeight then
        inspector:SetHeight(targetHeight)
    end
    if inspector.frame.SetWidth then
        inspector.frame:SetWidth(targetWidth)
    end
    if inspector.frame.SetHeight then
        inspector.frame:SetHeight(targetHeight)
    end

    local anchorHost = GetEditorPresentationAnchor()
    if inspector.frame.SetParent then
        inspector.frame:SetParent(anchorHost)
    end
    inspector.frame:ClearAllPoints()
    inspector.frame:SetPoint("TOPRIGHT", anchorHost, "TOPRIGHT", SidebarGeometry.right or 0, SidebarGeometry.top or 0)

    local inspectorContent = inspector._focalPointInspectorContent
    if inspectorContent then
        if inspectorContent.SetWidth then
            inspectorContent:SetWidth(targetWidth - 32)
        end
        if inspectorContent.SetHeight then
            inspectorContent:SetHeight(targetHeight - 20)
        end
    end

    local inspectorInset = inspector._focalPointInspectorInset
    if inspectorInset then
        inspectorInset:ClearAllPoints()
        inspectorInset:SetPoint("TOPLEFT", inspector.frame, "TOPLEFT", 16, -10)
        inspectorInset:SetPoint("BOTTOMRIGHT", inspector.frame, "BOTTOMRIGHT", -16, 10)
    end
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
    inspector:SetTitle("Inspector")
    inspector:SetWidth(INSPECTOR_WIDTH)
    inspector:SetHeight((UIParent and UIParent.GetHeight and math.max(760, math.floor(UIParent:GetHeight() - 24))) or 760)
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
        inspectorInset:SetPoint("TOPLEFT", inspector.frame, "TOPLEFT", 16, -10)
        inspectorInset:SetPoint("BOTTOMRIGHT", inspector.frame, "BOTTOMRIGHT", -16, 10)
        inspector._focalPointInspectorInset = inspectorInset

        inspectorContent.frame:ClearAllPoints()
        inspectorContent.frame:SetParent(inspectorInset)
        inspectorContent.frame:SetPoint("TOPLEFT", inspectorInset, "TOPLEFT", 0, 0)
        inspectorContent.frame:SetPoint("BOTTOMRIGHT", inspectorInset, "BOTTOMRIGHT", 0, 0)
    end

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

    local function CaptureSidebarScroll()
        local scrollWidget = GetScrollWidget()
        if not scrollWidget then
            return
        end

        local status = scrollWidget.status or scrollWidget.localstatus
        if status then
            if status.scrollvalue ~= nil then
                state.editorSidebarScroll.scrollvalue = status.scrollvalue
            elseif scrollWidget.scrollbar and scrollWidget.scrollbar.GetValue then
                state.editorSidebarScroll.scrollvalue = scrollWidget.scrollbar:GetValue() or state.editorSidebarScroll.scrollvalue or 0
            end

            if status.offset ~= nil then
                state.editorSidebarScroll.offset = status.offset
            end
            return
        end

        if scrollWidget.scrollbar and scrollWidget.scrollbar.GetValue then
            state.editorSidebarScroll.scrollvalue = scrollWidget.scrollbar:GetValue() or state.editorSidebarScroll.scrollvalue or 0
        end
    end

    local function RestoreSidebarScroll()
        local scrollWidget = GetScrollWidget()
        if not scrollWidget then
            return
        end

        local status = scrollWidget.status or scrollWidget.localstatus
        if status then
            if state.editorSidebarScroll.scrollvalue ~= nil then
                status.scrollvalue = state.editorSidebarScroll.scrollvalue
            end
            if state.editorSidebarScroll.offset ~= nil then
                status.offset = state.editorSidebarScroll.offset
            end
        end

        if scrollWidget.SetScroll and state.editorSidebarScroll.scrollvalue ~= nil then
            scrollWidget:SetScroll(state.editorSidebarScroll.scrollvalue)
        end

        if scrollWidget.scrollbar and scrollWidget.scrollbar.SetValue and state.editorSidebarScroll.scrollvalue ~= nil then
            scrollWidget.scrollbar:SetValue(state.editorSidebarScroll.scrollvalue)
        end

        if scrollWidget.FixScroll then
            scrollWidget:FixScroll()
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

    local RebuildSidebar
    RebuildSidebar = function()
        CaptureSidebarScroll()

        if BuildScrollableTabContent then
            BuildScrollableTabContent(inspectorContent, state.editorSidebarScroll, function(content)
                Inspector.Build(content, state, {
                    onConfigChanged = function()
                        RefreshLiveUnit(state.selectedUnit)
                    end,
                    onSidebarChanged = function()
                        RefreshLiveUnit(state.selectedUnit)
                        RebuildSidebar()
                    end,
                })
            end)
            RestoreSidebarScroll()
            if C_Timer and C_Timer.After then
                C_Timer.After(0, function()
                    if ns.GUI and ns.GUI.Editor and ns.GUI.Editor._inspectorBuildSerial == buildSerial
                        and EditorController.GetActiveInspectorHost() == inspector
                    then
                        RestoreSidebarScroll()
                    end
                end)
                C_Timer.After(0.05, function()
                    if ns.GUI and ns.GUI.Editor and ns.GUI.Editor._inspectorBuildSerial == buildSerial
                        and EditorController.GetActiveInspectorHost() == inspector
                    then
                        RestoreSidebarScroll()
                    end
                end)
            end
            return
        end

        Inspector.Build(inspector, state, {
            onConfigChanged = function()
                RefreshLiveUnit(state.selectedUnit)
            end,
            onSidebarChanged = function()
                RefreshLiveUnit(state.selectedUnit)
                RebuildSidebar()
            end,
        })
        RestoreSidebarScroll()
        if C_Timer and C_Timer.After then
            C_Timer.After(0, function()
                if ns.GUI and ns.GUI.Editor and ns.GUI.Editor._inspectorBuildSerial == buildSerial
                    and EditorController.GetActiveInspectorHost() == inspector
                then
                    RestoreSidebarScroll()
                end
            end)
            C_Timer.After(0.05, function()
                if ns.GUI and ns.GUI.Editor and ns.GUI.Editor._inspectorBuildSerial == buildSerial
                    and EditorController.GetActiveInspectorHost() == inspector
                then
                    RestoreSidebarScroll()
                end
            end)
        end
    end

    RebuildSidebar()
    return inspector
end

return EditorController

