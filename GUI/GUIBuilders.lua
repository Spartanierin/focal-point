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
local TabValues = ns.GUI.Helpers.TabValues

local GetGUIState = GUIState.GetState
local CreateProfilesDeps = PageDeps.CreateProfilesDeps
local CreateTagDatabaseDeps = PageDeps.CreateTagDatabaseDeps
local CreateTextBuilderDeps = PageDeps.CreateTextBuilderDeps
local CreateEditorDeps = PageDeps.CreateEditorDeps

-- Navigation data is built centrally so the tree and tab order stay consistent.
function B.CreateNavTree()
    return TabValues.CreateNavTree()
end

local BuildScrollableTabContent = LayoutHelpers.BuildScrollableTabContent

-- Shared placeholder used whenever a page module is unavailable.
function B.BuildPlaceholderPage(container, title)
    local page = ns.GUI.Pages and ns.GUI.Pages.Shared and ns.GUI.Pages.Shared.Placeholder
    if page and page.Build then
        page.Build(container, title)
    end
end

function B.BuildProfilesPage(container)
    local page = ns.GUI.Pages and ns.GUI.Pages.Profiles
    if not page or not page.Build then
        B.BuildPlaceholderPage(container, L["NAV_PROFILES"] or "Profiles")
        return
    end

    page.Build(container, CreateProfilesDeps({
        GetGUIState = GetGUIState,
        BuildPlaceholderPage = B.BuildPlaceholderPage,
    }))
end

function B.BuildTagDatabasePage(container)
    local page = ns.GUI.Pages and ns.GUI.Pages.TagDatabase
    if not page or not page.Build then
        B.BuildPlaceholderPage(container, L["INFO_TAG_DATABASE_TITLE"] or "Tag Database")
        return
    end

    page.Build(container, CreateTagDatabaseDeps({
        GetGUIState = GetGUIState,
        BuildScrollableTabContent = BuildScrollableTabContent,
        BuildPlaceholderPage = B.BuildPlaceholderPage,
    }))
end

function B.BuildTextBuilderPage(container)
    local page = ns.GUI.Pages and ns.GUI.Pages.TextBuilder
    if not page or not page.Build then
        B.BuildPlaceholderPage(container, ns.GetLabel(KM.Nav, C.Nav.TEXT_BUILDER))
        return
    end

    page.Build(container, CreateTextBuilderDeps({
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
        Sidebar = ns.GUI.Editor and ns.GUI.Editor.Sidebar,
    }))
end
