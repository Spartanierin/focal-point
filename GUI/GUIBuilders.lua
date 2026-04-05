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

local function PrepareWindowHost(container)
    if not container then
        return
    end

    container:ReleaseChildren()
    container:SetLayout("Fill")
end

local function OpenWindowFromBuilder(container, page, deps, fallbackTitle)
    if not page or not page.OpenWindow then
        B.BuildPlaceholderPage(container, fallbackTitle)
        return
    end

    PrepareWindowHost(container)
    page.OpenWindow(deps)
end

-- Tool builders only keep the host container clean and launch the standalone windows.
function B.BuildProfilesPage(container)
    local page = ns.GUI.Pages and ns.GUI.Pages.Profiles

    OpenWindowFromBuilder(container, page, CreateProfilesDeps({
        GetGUIState = GetGUIState,
    }), L["NAV_PROFILES"] or "Profiles")
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

function B.BuildTagDatabasePage(container)
    local page = ns.GUI.Pages and ns.GUI.Pages.TagDatabase

    OpenWindowFromBuilder(container, page, CreateTagDatabaseDeps({
        GetGUIState = GetGUIState,
    }), L["INFO_TAG_DATABASE_TITLE"] or "Tag Database")
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

function B.BuildTextBuilderPage(container)
    local page = ns.GUI.Pages and ns.GUI.Pages.TextBuilder

    OpenWindowFromBuilder(container, page, CreateTextBuilderDeps({
        GetGUIState = GetGUIState,
    }), ns.GetLabel(KM.Nav, C.Nav.TEXT_BUILDER))
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
        Sidebar = ns.GUI.Editor and ns.GUI.Editor.Sidebar,
    }))
end
