local addonName, ns = ...

ns.GUIController = ns.GUIController or {}
local B = ns.GUIController

-- This file acts as the GUI orchestrator.
-- It does not build detailed widget trees itself anymore; instead it routes to
-- page modules and passes the dependency bundles they need.

local C = ns.Constants
local KM = ns.KeyMap
local L = ns.L
local LayoutHelpers = ns.GUI.Helpers.LayoutHelpers
local GUIState = ns.GUI.Helpers.GUIState
local PageDependencyFactory = ns.GUI.Helpers.PageDependencyFactory

local GetGUIState = GUIState.GetState
local CreateProfilesDeps = PageDependencyFactory.CreateProfilesDeps
local CreateTagDatabaseDeps = PageDependencyFactory.CreateTagDatabaseDeps
local CreateTextBuilderDeps = PageDependencyFactory.CreateTextBuilderDeps
local CreateEditorDeps = PageDependencyFactory.CreateEditorDeps

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
    local deps = CreateEditorDeps({
        GetEditorState = ns.GUI.Editor and ns.GUI.Editor.State and ns.GUI.Editor.State.Get,
        BuildScrollableTabContent = BuildScrollableTabContent,
    })
    if not deps then
        B.BuildPlaceholderPage(container, ns.GetLabel(KM.Nav, C.Nav.EDITOR))
        return
    end

    local controller = ns.GUI and ns.GUI.Editor and ns.GUI.Editor.Controller
    if controller and controller.ReleaseInspector then
        controller.ReleaseInspector()
    end

    deps.ResetFlowContainer(container)
    container._focalPointEditorWorkspaceRole = "editor_workspace"

    local generalConfig = ns.db and ns.db.profile and ns.db.profile.General
    local editorStateApi = ns.GUI and ns.GUI.Editor and ns.GUI.Editor.State
    local editorMode = ns.EditorMode or (ns.GUI and ns.GUI.Editor and ns.GUI.Editor.Mode)
    if type(generalConfig) == "table" and editorStateApi then
        local state = editorStateApi.Get and editorStateApi.Get()
        if editorMode and editorMode.SyncStateFromProfile then
            editorMode.SyncStateFromProfile(state, ns.db and ns.db.profile)
        end
    end

    if ns and ns.guiEditorWorkspaceHost then
        ns.guiEditorWorkspaceHost._focalPointEditorRole = "editor_workspace"
    end

    if controller and controller.BuildInspector then
        if container and container.ReleaseChildren then
            container:ReleaseChildren()
        end
        controller.BuildInspector(nil, deps)
        return
    end

    B.BuildPlaceholderPage(container, ns.GetLabel(KM.Nav, C.Nav.EDITOR))
end
