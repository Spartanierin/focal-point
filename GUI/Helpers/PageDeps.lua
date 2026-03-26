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

function PageDeps.CreateTextDeps(config)
    local deps = PageDeps.CreateLayoutDeps()

    deps.GetGUIState = config.GetGUIState
    deps.GetTextElementLabel = config.GetTextElementLabel
    deps.GetTextTabValues = config.GetTextTabValues
    deps.BuildScrollableTabContent = config.BuildScrollableTabContent
    deps.BuildPlaceholderPage = config.BuildPlaceholderPage

    return deps
end

function PageDeps.CreateBarDeps(config)
    local deps = PageDeps.CreateLayoutDeps()

    deps.GetGUIState = config.GetGUIState
    deps.GetBarTabValues = config.GetBarTabValues
    deps.BuildScrollableTabContent = config.BuildScrollableTabContent
    deps.BuildPlaceholderPage = config.BuildPlaceholderPage

    return deps
end

function PageDeps.CreateAuraDeps(config)
    local deps = PageDeps.CreateLayoutDeps()

    deps.GetGUIState = config.GetGUIState
    deps.GetAuraTabValues = config.GetAuraTabValues
    deps.BuildScrollableTabContent = config.BuildScrollableTabContent
    deps.BuildPlaceholderPage = config.BuildPlaceholderPage

    return deps
end

function PageDeps.CreateGeneralDeps()
    local BuilderUI = ns.GUI.Helpers.BuilderUI
    local LayoutHelpers = ns.GUI.Helpers.LayoutHelpers

    return {
        ResetFlowContainer = BuilderUI.ResetFlowContainer,
        GetAddonVersionText = BuilderUI.GetAddonVersionText,
        CreateSection = LayoutHelpers.CreateSection,
    }
end

function PageDeps.CreateThemeDeps()
    local BuilderUI = ns.GUI.Helpers.BuilderUI
    local LayoutHelpers = ns.GUI.Helpers.LayoutHelpers

    return {
        ResetFlowContainer = BuilderUI.ResetFlowContainer,
        AddPageHeading = BuilderUI.AddPageHeading,
        CreateSection = LayoutHelpers.CreateSection,
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

function PageDeps.CreateUnitPageDeps(config)
    local BuilderUI = ns.GUI.Helpers.BuilderUI

    return {
        AddPageHeading = BuilderUI.AddPageHeading,
        GetGUIState = config.GetGUIState,
        GetUnitTabValues = config.GetUnitTabValues,
        BuildUnitBarsPage = config.BuildUnitBarsPage,
        BuildUnitAurasPage = config.BuildUnitAurasPage,
        BuildUnitTextsPage = config.BuildUnitTextsPage,
        BuildUnitElementsPage = config.BuildUnitElementsPage,
        BuildUnitFramePage = config.BuildUnitFramePage,
        BuildUnitColorsPage = config.BuildUnitColorsPage,
        BuildPlaceholderPage = config.BuildPlaceholderPage,
    }
end
