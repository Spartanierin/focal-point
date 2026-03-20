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
local CreateBarDeps = PageDeps.CreateBarDeps
local CreateAuraDeps = PageDeps.CreateAuraDeps
local CreateGeneralDeps = PageDeps.CreateGeneralDeps
local CreateLayoutDeps = PageDeps.CreateLayoutDeps
local CreateProfilesDeps = PageDeps.CreateProfilesDeps
local CreateTagDatabaseDeps = PageDeps.CreateTagDatabaseDeps
local CreateTextBuilderDeps = PageDeps.CreateTextBuilderDeps
local CreateTextDeps = PageDeps.CreateTextDeps
local CreateUnitPageDeps = PageDeps.CreateUnitPageDeps
local GetBarTabValues = TabValues.GetBarTabValues
local GetAuraTabValues = TabValues.GetAuraTabValues
local GetElementTabValues = TabValues.GetElementTabValues
local GetTextElementLabel = TabValues.GetTextElementLabel
local GetTextTabValues = TabValues.GetTextTabValues
local GetUnitTabValues = TabValues.GetUnitTabValues

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

-- Top-level pages
function B.BuildGeneralPage(container)
    local page = ns.GUI.Pages and ns.GUI.Pages.General
    if not page or not page.Build then
        B.BuildPlaceholderPage(container, ns.GetLabel(KM.Nav, C.Nav.GENERAL))
        return
    end

    page.Build(container, CreateGeneralDeps())
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

-- Unit subpages
function B.BuildUnitFramePage(container, unitKey)
    local page = ns.GUI.Pages and ns.GUI.Pages.UnitFrame
    if not page or not page.Build then
        B.BuildPlaceholderPage(container, ns.GetLabel(KM.Tabs, C.Tabs.FRAME))
        return
    end

    page.Build(container, unitKey, CreateLayoutDeps())
end

function B.BuildUnitElementsPage(container, unitKey)
    local page = ns.GUI.Pages and ns.GUI.Pages.UnitElements
    if not page or not page.Build then
        B.BuildPlaceholderPage(container, ns.GetLabel(KM.Tabs, C.Tabs.ELEMENTS))
        return
    end

    page.Build(container, unitKey, {
        GetGUIState = GetGUIState,
        GetElementTabValues = GetElementTabValues,
        BuildScrollableTabContent = BuildScrollableTabContent,
        BuildPlaceholderPage = B.BuildPlaceholderPage,
    })
end

function B.BuildUnitColorsPage(container, unitKey)
    local page = ns.GUI.Pages and ns.GUI.Pages.UnitColors
    if not page or not page.Build then
        B.BuildPlaceholderPage(container, ns.GetLabel(KM.Tabs, C.Tabs.COLORS))
        return
    end

    page.Build(container, unitKey, CreateLayoutDeps())
end

function B.BuildUnitHealthBarPage(container, unitKey)
    local page = ns.GUI.Pages and ns.GUI.Pages.UnitBars
    if not page or not page.BuildHealth then
        B.BuildPlaceholderPage(container, ns.GetLabel(KM.Bars, C.Bars.HEALTH))
        return
    end

    page.BuildHealth(container, unitKey, CreateLayoutDeps())
end

function B.BuildUnitPowerBarPage(container, unitKey)
    local page = ns.GUI.Pages and ns.GUI.Pages.UnitBars
    if not page or not page.BuildPower then
        B.BuildPlaceholderPage(container, ns.GetLabel(KM.Bars, C.Bars.POWER))
        return
    end

    page.BuildPower(container, unitKey, CreateLayoutDeps())
end

function B.BuildUnitAlternativePowerBarPage(container, unitKey)
    local page = ns.GUI.Pages and ns.GUI.Pages.UnitBars
    if not page or not page.BuildAlternativePower then
        B.BuildPlaceholderPage(container, ns.GetLabel(KM.Bars, C.Bars.ALT_POWER))
        return
    end

    page.BuildAlternativePower(container, unitKey, CreateLayoutDeps())
end

function B.BuildUnitCastBarPage(container, unitKey)
    local page = ns.GUI.Pages and ns.GUI.Pages.UnitBars
    if not page or not page.BuildCast then
        B.BuildPlaceholderPage(container, ns.GetLabel(KM.Bars, C.Bars.CAST))
        return
    end

    page.BuildCast(container, unitKey, CreateLayoutDeps())
end

function B.BuildUnitTextsPage(container, unitKey)
    local page = ns.GUI.Pages and ns.GUI.Pages.UnitTexts
    if not page or not page.Build then
        B.BuildPlaceholderPage(container, ns.GetLabel(KM.Tabs, C.Tabs.TEXTS))
        return
    end

    page.Build(container, unitKey, CreateTextDeps({
        GetGUIState = GetGUIState,
        GetTextElementLabel = GetTextElementLabel,
        GetTextTabValues = GetTextTabValues,
        BuildScrollableTabContent = BuildScrollableTabContent,
        BuildPlaceholderPage = B.BuildPlaceholderPage,
    }))
end

function B.BuildUnitBarsPage(container, unitKey)
    local page = ns.GUI.Pages and ns.GUI.Pages.UnitBars
    if not page or not page.BuildTabs then
        B.BuildPlaceholderPage(container, ns.GetLabel(KM.Tabs, C.Tabs.BARS))
        return
    end

    page.BuildTabs(container, unitKey, CreateBarDeps({
        GetGUIState = GetGUIState,
        GetBarTabValues = GetBarTabValues,
        BuildScrollableTabContent = BuildScrollableTabContent,
        BuildPlaceholderPage = B.BuildPlaceholderPage,
    }))
end

function B.BuildUnitAurasPage(container, unitKey)
    local page = ns.GUI.Pages and ns.GUI.Pages.UnitAuras
    if not page or not page.BuildTabs then
        B.BuildPlaceholderPage(container, ns.GetLabel(KM.Tabs, C.Tabs.AURAS))
        return
    end

    page.BuildTabs(container, unitKey, CreateAuraDeps({
        GetGUIState = GetGUIState,
        GetAuraTabValues = GetAuraTabValues,
        BuildScrollableTabContent = BuildScrollableTabContent,
        BuildPlaceholderPage = B.BuildPlaceholderPage,
    }))
end

function B.BuildUnitPage(container, unitKey)
    local page = ns.GUI.Pages and ns.GUI.Pages.UnitPage
    if not page or not page.Build then
        B.BuildPlaceholderPage(container, ns.GetLabel(KM.Nav, C.Nav.UNITS))
        return
    end

    page.Build(container, unitKey, CreateUnitPageDeps({
        GetGUIState = GetGUIState,
        GetUnitTabValues = GetUnitTabValues,
        BuildUnitBarsPage = B.BuildUnitBarsPage,
        BuildUnitAurasPage = B.BuildUnitAurasPage,
        BuildUnitTextsPage = B.BuildUnitTextsPage,
        BuildUnitElementsPage = B.BuildUnitElementsPage,
        BuildUnitFramePage = B.BuildUnitFramePage,
        BuildUnitColorsPage = B.BuildUnitColorsPage,
        BuildPlaceholderPage = B.BuildPlaceholderPage,
    }))
end
