local _, ns = ...

ns.GUI = ns.GUI or {}
ns.GUI.Helpers = ns.GUI.Helpers or {}

local PageDeps = {}
ns.GUI.Helpers.PageDeps = PageDeps

function PageDeps.CreateProfilesDeps(config)
    return {
        GetGUIState = config.GetGUIState,
    }
end

function PageDeps.CreateTagDatabaseDeps(config)
    return {
        GetGUIState = config.GetGUIState,
    }
end

function PageDeps.CreateTextBuilderDeps(config)
    return {
        GetGUIState = config.GetGUIState,
    }
end

function PageDeps.CreateEditorDeps(config)
    local BuilderUI = ns.GUI.Helpers.BuilderUI

    return {
        ResetFlowContainer = BuilderUI.ResetFlowContainer,
        GetEditorState = config.GetEditorState,
        BuildScrollableTabContent = config.BuildScrollableTabContent,
    }
end
