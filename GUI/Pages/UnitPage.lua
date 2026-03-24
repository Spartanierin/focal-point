local _, ns = ...

ns.GUI = ns.GUI or {}
ns.GUI.Pages = ns.GUI.Pages or {}

local AceGUI = LibStub("AceGUI-3.0")

local UnitPage = {}
ns.GUI.Pages.UnitPage = UnitPage

function UnitPage.Build(container, unitKey, deps)
    container:ReleaseChildren()
    container:SetLayout("Flow")

    local state = deps.GetGUIState()
    local BuildScrollableTabContent = deps.BuildScrollableTabContent
    state.unitTabs[unitKey] = state.unitTabs[unitKey] or ns.Constants.Tabs.FRAME
    state.unitScroll[unitKey] = state.unitScroll[unitKey] or {}
    local unitLabel = ns.GetLabel(ns.KeyMap.Units, unitKey)

    if deps.AddPageHeading then
        deps.AddPageHeading(container, unitLabel)
    end

    local tabGroup = AceGUI:Create("TabGroup")
    tabGroup:SetFullWidth(true)
    tabGroup:SetFullHeight(true)
    tabGroup:SetLayout("Fill")
    tabGroup:SetTabs(deps.GetUnitTabValues())

    tabGroup:SetCallback("OnGroupSelected", function(widget, _, tabKey)
        state.unitTabs[unitKey] = tabKey

        widget:ReleaseChildren()
        widget:SetLayout("Fill")

        if tabKey == ns.Constants.Tabs.BARS then
            deps.BuildUnitBarsPage(widget, unitKey)
            return
        end

        if tabKey == ns.Constants.Tabs.AURAS then
            deps.BuildUnitAurasPage(widget, unitKey)
            return
        end

        if tabKey == ns.Constants.Tabs.TEXTS then
            deps.BuildUnitTextsPage(widget, unitKey)
            return
        end

        if tabKey == ns.Constants.Tabs.ELEMENTS then
            deps.BuildUnitElementsPage(widget, unitKey)
            return
        end

        state.unitScroll[unitKey][tabKey] = state.unitScroll[unitKey][tabKey] or { scrollvalue = 0 }

        if tabKey == ns.Constants.Tabs.FRAME then
            if BuildScrollableTabContent then
                BuildScrollableTabContent(widget, state.unitScroll[unitKey][tabKey], function(content)
                    deps.BuildUnitFramePage(content, unitKey)
                end)
                return
            end
        end

        local scroll = AceGUI:Create("ScrollFrame")
        scroll:SetFullWidth(true)
        scroll:SetFullHeight(true)
        scroll:SetLayout("Flow")
        scroll:SetStatusTable(state.unitScroll[unitKey][tabKey])
        widget:AddChild(scroll)

        if tabKey == ns.Constants.Tabs.FRAME then
            deps.BuildUnitFramePage(scroll, unitKey)
            return
        end

        if tabKey == ns.Constants.Tabs.COLORS then
            deps.BuildUnitColorsPage(scroll, unitKey)
            return
        end

        local tabLabel = ns.GetLabel(ns.KeyMap.Tabs, tabKey)
        deps.BuildPlaceholderPage(scroll, tabLabel)
    end)

    container:AddChild(tabGroup)
    tabGroup:SelectTab(state.unitTabs[unitKey] or ns.Constants.Tabs.FRAME)
end
