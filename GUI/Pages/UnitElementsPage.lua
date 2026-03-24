local _, ns = ...

ns.GUI = ns.GUI or {}
ns.GUI.Pages = ns.GUI.Pages or {}

local AceGUI = LibStub("AceGUI-3.0")
local C = ns.Constants

local UnitElementsPage = {}
ns.GUI.Pages.UnitElements = UnitElementsPage

local function BuildStandardElementLayoutPage(container, unitKey, config)
    local sharedElementLayoutPage = ns.GUI.Pages and ns.GUI.Pages.Shared and ns.GUI.Pages.Shared.ElementLayout
    if sharedElementLayoutPage and sharedElementLayoutPage.Build then
        sharedElementLayoutPage.Build(container, unitKey, config, {
            ResetFlowContainer = ns.GUI.Helpers.BuilderUI.ResetFlowContainer,
            AddPageHeading = ns.GUI.Helpers.BuilderUI.AddPageHeading,
            AddSectionHeading = ns.GUI.Helpers.BuilderUI.AddSectionHeading,
        })
    end
end

local function BuildElementPage(container, unitKey, elementKey)
    if elementKey == C.Elements.PORTRAIT then
        BuildStandardElementLayoutPage(container, unitKey, {
            optionKey = "Portrait",
            disabledKey = "portrait",
            elementKey = C.Elements.PORTRAIT,
            lists = ns.GUI.Layouts.UnitPortrait.Lists,
            layout = ns.GUI.Layouts.UnitPortrait.PortraitTab,
        })
        return true
    elseif elementKey == C.Elements.RAID_TARGET_ICON then
        BuildStandardElementLayoutPage(container, unitKey, {
            optionKey = "RaidTargetIcon",
            disabledKey = "rtm",
            elementKey = C.Elements.RAID_TARGET_ICON,
            lists = ns.GUI.Layouts.UnitRaidTarget.Lists,
            layout = ns.GUI.Layouts.UnitRaidTarget.RaidTargetTab,
        })
        return true
    elseif elementKey == C.Elements.LEADER_ICON then
        BuildStandardElementLayoutPage(container, unitKey, {
            optionKey = "LeaderIcon",
            disabledKey = "leader",
            elementKey = C.Elements.LEADER_ICON,
            lists = ns.GUI.Layouts.UnitLeaderIcon.Lists,
            layout = ns.GUI.Layouts.UnitLeaderIcon.LeaderIconTab,
        })
        return true
    elseif elementKey == C.Elements.ROLE_ICON then
        BuildStandardElementLayoutPage(container, unitKey, {
            optionKey = "RoleIcon",
            disabledKey = "role",
            elementKey = C.Elements.ROLE_ICON,
            lists = ns.GUI.Layouts.UnitRoleIcon.Lists,
            layout = ns.GUI.Layouts.UnitRoleIcon.RoleIconTab,
        })
        return true
    elseif elementKey == C.Elements.COMBAT_INDICATOR then
        BuildStandardElementLayoutPage(container, unitKey, {
            optionKey = "CombatIndicator",
            disabledKey = "combat",
            elementKey = C.Elements.COMBAT_INDICATOR,
            lists = ns.GUI.Layouts.UnitCombatIndicator.Lists,
            layout = ns.GUI.Layouts.UnitCombatIndicator.CombatIndicatorTab,
        })
        return true
    elseif elementKey == C.Elements.RESTING_INDICATOR then
        BuildStandardElementLayoutPage(container, unitKey, {
            optionKey = "RestingIndicator",
            disabledKey = "resting",
            elementKey = C.Elements.RESTING_INDICATOR,
            lists = ns.GUI.Layouts.UnitRestingIndicator.Lists,
            layout = ns.GUI.Layouts.UnitRestingIndicator.RestingIndicatorTab,
            isUnavailable = function(currentUnitKey)
                return currentUnitKey ~= "player"
            end,
        })
        return true
    elseif elementKey == C.Elements.READY_CHECK_INDICATOR then
        BuildStandardElementLayoutPage(container, unitKey, {
            optionKey = "ReadyCheckIndicator",
            disabledKey = "readycheck",
            elementKey = C.Elements.READY_CHECK_INDICATOR,
            lists = ns.GUI.Layouts.UnitReadyCheckIndicator.Lists,
            layout = ns.GUI.Layouts.UnitReadyCheckIndicator.ReadyCheckIndicatorTab,
        })
        return true
    elseif elementKey == C.Elements.CLASSIFICATION_INDICATOR then
        BuildStandardElementLayoutPage(container, unitKey, {
            optionKey = "ClassificationIndicator",
            disabledKey = "classification",
            elementKey = C.Elements.CLASSIFICATION_INDICATOR,
            lists = ns.GUI.Layouts.UnitClassificationIndicator.Lists,
            layout = ns.GUI.Layouts.UnitClassificationIndicator.ClassificationIndicatorTab,
            isUnavailable = function(currentUnitKey)
                return currentUnitKey == "player" or currentUnitKey == "pet"
            end,
        })
        return true
    end

    return false
end

function UnitElementsPage.Build(container, unitKey, deps)
    container:ReleaseChildren()
    container:SetLayout("Fill")

    local state = deps.GetGUIState()
    state.unitElementTabs[unitKey] = state.unitElementTabs[unitKey] or C.Elements.PORTRAIT
    state.unitElementScroll[unitKey] = state.unitElementScroll[unitKey] or {}

    local tabGroup = AceGUI:Create("TabGroup")
    tabGroup:SetFullWidth(true)
    tabGroup:SetFullHeight(true)
    tabGroup:SetLayout("Fill")
    tabGroup:SetTabs(deps.GetElementTabValues())

    tabGroup:SetCallback("OnGroupSelected", function(widget, _, elementKey)
        state.unitElementTabs[unitKey] = elementKey
        state.unitElementScroll[unitKey][elementKey] = state.unitElementScroll[unitKey][elementKey] or { scrollvalue = 0 }

        deps.BuildScrollableTabContent(widget, state.unitElementScroll[unitKey][elementKey], function(content)
            if BuildElementPage(content, unitKey, elementKey) then
                return
            end

            deps.BuildPlaceholderPage(content, ns.GetLabel(ns.KeyMap.Elements, elementKey))
        end)
    end)

    container:AddChild(tabGroup)
    tabGroup:SelectTab(state.unitElementTabs[unitKey] or C.Elements.PORTRAIT)
end
