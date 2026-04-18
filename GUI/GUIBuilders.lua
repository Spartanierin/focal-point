local addonName, ns = ...

ns.GUIBuilders = ns.GUIBuilders or {}
local B = ns.GUIBuilders

-- This file acts as the GUI orchestrator.
-- It does not build detailed widget trees itself anymore; instead it routes to
-- page modules and passes the dependency bundles they need.

local C = ns.Constants
local KM = ns.KeyMap
local L = ns.L
local LayoutHelpers = ns.GUI.Helpers.LayoutHelpers
local GUIState = ns.GUI.Helpers.GUIState
local PageDeps = ns.GUI.Helpers.PageDeps

local GetGUIState = GUIState.GetState
local CreateProfilesDeps = PageDeps.CreateProfilesDeps
local CreateTagDatabaseDeps = PageDeps.CreateTagDatabaseDeps
local CreateTextBuilderDeps = PageDeps.CreateTextBuilderDeps
local CreateEditorDeps = PageDeps.CreateEditorDeps

local BuildScrollableTabContent = LayoutHelpers.BuildScrollableTabContent

-- Shared placeholder used whenever a page module is unavailable.
function B.BuildPlaceholderPage(container, title)
    local page = ns.GUI.Pages and ns.GUI.Pages.Shared and ns.GUI.Pages.Shared.Placeholder
    if page and page.Build then
        page.Build(container, title)
    end
end

function B.OpenProfilesWindow()
    local page = ns.GUI.Pages and ns.GUI.Pages.Profiles
    if not page or not page.OpenWindow then
        return
    end

    page.OpenWindow(CreateProfilesDeps({
        GetGUIState = GetGUIState,
    }))
end

function B.OpenTagDatabaseWindow()
    local page = ns.GUI.Pages and ns.GUI.Pages.TagDatabase
    if not page or not page.OpenWindow then
        return
    end

    page.OpenWindow(CreateTagDatabaseDeps({
        GetGUIState = GetGUIState,
    }))
end

function B.OpenTextBuilderWindow()
    local page = ns.GUI.Pages and ns.GUI.Pages.TextBuilder
    if not page or not page.OpenWindow then
        return
    end

    page.OpenWindow(CreateTextBuilderDeps({
        GetGUIState = GetGUIState,
    }))
end

function B.BuildEditorPage(container)
    local page = ns.GUI.Pages and ns.GUI.Pages.Editor
    if not page or not page.Build then
        B.BuildPlaceholderPage(container, ns.GetLabel(KM.Nav, C.Nav.EDITOR))
        return
    end

    page.Build(container, CreateEditorDeps({
        GetEditorState = ns.GUI.Editor and ns.GUI.Editor.State and ns.GUI.Editor.State.Get,
        BuildScrollableTabContent = BuildScrollableTabContent,
    }))
end
