local _, ns = ...

ns.GUI = ns.GUI or {}
ns.GUI.Helpers = ns.GUI.Helpers or {}

local PageDeps = {}
ns.GUI.Helpers.PageDeps = PageDeps

function PageDeps.CreateLayoutDeps()
    local BuilderUI = ns.GUI.Helpers.BuilderUI
    local LayoutHelpers = ns.GUI.Helpers.LayoutHelpers

    return {
        ResetFlowContainer = BuilderUI.ResetFlowContainer,
        AddPageHeading = BuilderUI.AddPageHeading,
        AddSectionHeading = BuilderUI.AddSectionHeading,
        CreateSection = LayoutHelpers.CreateSection,
        AddLayoutHandle = LayoutHelpers.AddLayoutHandle,
        ResolveLayoutText = LayoutHelpers.ResolveLayoutText,
        ResolveLayoutPath = LayoutHelpers.ResolveLayoutPath,
        ResolveLayoutList = LayoutHelpers.ResolveLayoutList,
        CanBuildLayoutWidget = LayoutHelpers.CanBuildLayoutWidget,
    }
end

function PageDeps.CreateProfilesDeps(config)
    local BuilderUI = ns.GUI.Helpers.BuilderUI

    return {
        GetGUIState = config.GetGUIState,
        ResetFlowContainer = BuilderUI.ResetFlowContainer,
        AddPageHeading = BuilderUI.AddPageHeading,
        BuildPlaceholderPage = config.BuildPlaceholderPage,
    }
end

function PageDeps.CreateTagDatabaseDeps(config)
    return {
        GetGUIState = config.GetGUIState,
        BuildScrollableTabContent = config.BuildScrollableTabContent,
        BuildPlaceholderPage = config.BuildPlaceholderPage,
    }
end

function PageDeps.CreateTextBuilderDeps(config)
    local BuilderUI = ns.GUI.Helpers.BuilderUI

    return {
        GetGUIState = config.GetGUIState,
        ResetFlowContainer = BuilderUI.ResetFlowContainer,
    }
end

function PageDeps.CreateEditorDeps(config)
    local BuilderUI = ns.GUI.Helpers.BuilderUI

    return {
        ResetFlowContainer = BuilderUI.ResetFlowContainer,
        AddPageHeading = BuilderUI.AddPageHeading,
        GetEditorState = config.GetEditorState,
        BuildScrollableTabContent = config.BuildScrollableTabContent,
        Sidebar = config.Sidebar,
    }
end
