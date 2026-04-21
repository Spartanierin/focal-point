local _, ns = ...

ns.GUI = ns.GUI or {}
ns.GUI.Helpers = ns.GUI.Helpers or {}

local PageDependencyFactory = {}
ns.GUI.Helpers.PageDependencyFactory = PageDependencyFactory

function PageDependencyFactory.CreateProfilesDeps(config)
    return {
        GetGUIState = config.GetGUIState,
    }
end

function PageDependencyFactory.CreateTagDatabaseDeps(config)
    return {
        GetGUIState = config.GetGUIState,
    }
end

function PageDependencyFactory.CreateTextBuilderDeps(config)
    return {
        GetGUIState = config.GetGUIState,
    }
end

function PageDependencyFactory.CreateEditorDeps(config)
    local BuilderUI = ns.GUI.Helpers.GUIRuntimeHelpers

    return {
        ResetFlowContainer = BuilderUI.ResetFlowContainer,
        GetEditorState = config.GetEditorState,
        BuildScrollableTabContent = config.BuildScrollableTabContent,
    }
end
