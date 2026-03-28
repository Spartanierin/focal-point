local _, ns = ...

ns.GUI = ns.GUI or {}
ns.GUI.Editor = ns.GUI.Editor or {}

local AceGUI = LibStub("AceGUI-3.0")
local EditorController = {}
ns.GUI.Editor.Controller = EditorController

function EditorController.ReleaseInspector()
    local inspectorSidebar = ns.GUI and ns.GUI.Editor and ns.GUI.Editor._activeInspectorSidebar
    if not inspectorSidebar then
        return
    end

    if inspectorSidebar.frame and inspectorSidebar.frame.Hide then
        inspectorSidebar.frame:Hide()
    end

    ns.GUI.Editor._activeInspectorSidebar = nil
end

function EditorController.BuildInspector(container, deps)
    local state = deps.GetEditorState()
    local BuildScrollableTabContent = deps.BuildScrollableTabContent
    local Sidebar = (ns.GUI and ns.GUI.Editor and ns.GUI.Editor.InspectorSidebar) or deps.Sidebar

    local inspectorSidebar = AceGUI:Create("SimpleGroup")
    inspectorSidebar:SetRelativeWidth(1.0)
    inspectorSidebar:SetHeight(700)
    inspectorSidebar:SetLayout("Fill")
    container:AddChild(inspectorSidebar)

    local inspectorContent = AceGUI:Create("SimpleGroup")
    inspectorContent:SetFullWidth(true)
    inspectorContent:SetFullHeight(true)
    inspectorContent:SetLayout("Fill")
    inspectorSidebar:AddChild(inspectorContent)

    if inspectorSidebar.frame then
        local inspectorBg = inspectorSidebar.frame:CreateTexture(nil, "BACKGROUND")
        inspectorBg:SetAllPoints()
        inspectorBg:SetColorTexture(0.05, 0.06, 0.08, 0.76)
        inspectorSidebar._inspectorBg = inspectorBg

        local inspectorBorder = inspectorSidebar.frame:CreateTexture(nil, "BORDER")
        inspectorBorder:SetPoint("TOPLEFT")
        inspectorBorder:SetPoint("BOTTOMLEFT")
        inspectorBorder:SetWidth(1)
        inspectorBorder:SetColorTexture(0.16, 0.19, 0.24, 0.9)
        inspectorSidebar._inspectorBorder = inspectorBorder

        local inspectorAccent = inspectorSidebar.frame:CreateTexture(nil, "ARTWORK")
        inspectorAccent:SetPoint("TOPLEFT")
        inspectorAccent:SetPoint("TOPRIGHT")
        inspectorAccent:SetHeight(2)
        inspectorAccent:SetColorTexture(0.78, 0.65, 0.24, 0.50)
        inspectorSidebar._inspectorAccent = inspectorAccent
    end

    ns.GUI.Editor._activeInspectorSidebar = inspectorSidebar

    local function PositionInspectorForEditorShell()
        if not inspectorSidebar or not inspectorSidebar.frame then
            return
        end

        inspectorSidebar.frame:ClearAllPoints()
        inspectorSidebar.frame:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", 0, 0)
        inspectorSidebar.frame:SetWidth(285)
        inspectorSidebar.frame:SetHeight((UIParent and UIParent.GetHeight and UIParent:GetHeight()) or 760)
    end

    PositionInspectorForEditorShell()
    if C_Timer and C_Timer.After then
        C_Timer.After(0, PositionInspectorForEditorShell)
        C_Timer.After(0.05, PositionInspectorForEditorShell)
    end

    local inspectorInset = nil
    if inspectorSidebar.frame and inspectorContent.frame then
        inspectorInset = CreateFrame("Frame", nil, inspectorSidebar.frame)
        inspectorInset:SetPoint("TOPLEFT", inspectorSidebar.frame, "TOPLEFT", 16, -10)
        inspectorInset:SetPoint("BOTTOMRIGHT", inspectorSidebar.frame, "BOTTOMRIGHT", -16, 10)

        inspectorContent.frame:ClearAllPoints()
        inspectorContent.frame:SetParent(inspectorInset)
        inspectorContent.frame:SetPoint("TOPLEFT", inspectorInset, "TOPLEFT", 0, 0)
        inspectorContent.frame:SetPoint("BOTTOMRIGHT", inspectorInset, "BOTTOMRIGHT", 0, 0)
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
                Sidebar.Build(content, state, {
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
                C_Timer.After(0, RestoreSidebarScroll)
                C_Timer.After(0.05, RestoreSidebarScroll)
            end
            return
        end

        Sidebar.Build(inspectorSidebar, state, {
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
            C_Timer.After(0, RestoreSidebarScroll)
            C_Timer.After(0.05, RestoreSidebarScroll)
        end
    end

    RebuildSidebar()
    return inspectorSidebar
end

return EditorController
