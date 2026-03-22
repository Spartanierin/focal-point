local _, ns = ...

ns.GUI = ns.GUI or {}
ns.GUI.Pages = ns.GUI.Pages or {}

local AceGUI = LibStub("AceGUI-3.0")
local C = ns.Constants
local KM = ns.KeyMap
local L = ns.L
local Checkbox = ns.GUI.Widgets.Checkbox
local Dropdown = ns.GUI.Widgets.Dropdown
local Slider = ns.GUI.Widgets.Sliders
local OptionValues = ns.GUI.Helpers.OptionValues
local OptionRefresh = ns.GUI.Helpers.OptionRefresh
local LayoutHelpers = ns.GUI.Helpers.LayoutHelpers

local UnitAurasPage = {}
ns.GUI.Pages.UnitAuras = UnitAurasPage

local function IsUnitDisabled(unitKey)
    return not ns.GUI.Helpers.OptionValues.Get({ "Units", unitKey, "enabled" }, true)
end

local function BuildAuraGroupPage(container, unitKey, auraConfigKey, auraLabel, deps)
    local ResetFlowContainer = deps.ResetFlowContainer
    local AddSectionHeading = deps.AddSectionHeading
    local CreateSection = deps.CreateSection
    local AddLayoutHandle = deps.AddLayoutHandle
    local ResolveLayoutText = deps.ResolveLayoutText
    local ResolveLayoutPath = deps.ResolveLayoutPath
    local ResolveLayoutList = deps.ResolveLayoutList
    local CanBuildLayoutWidget = deps.CanBuildLayoutWidget

    ResetFlowContainer(container)
    if LayoutHelpers and LayoutHelpers.ApplyUnitLayoutDefaults then
        LayoutHelpers.ApplyUnitLayoutDefaults(container)
    end
    local AURA_LAYOUT = ns.GUI.Layouts.UnitAuras.AuraTab
    local AURA_LISTS = ns.GUI.Layouts.UnitAuras.Lists
    local replacements = { ["$auraKey"] = auraConfigKey }

    local function IsAuraDisabled()
        return IsUnitDisabled(unitKey)
            or not ns.GUI.Helpers.OptionValues.Get({ "Units", unitKey, auraConfigKey, "enabled" }, true)
    end

    local function IsInsideDisabled()
        return IsAuraDisabled()
            or ns.GUI.Helpers.OptionValues.Get({ "Units", unitKey, auraConfigKey, "placement" }, "ATTACHED") ~= "INSIDE"
    end

    local function IsAttachedDisabled()
        return IsAuraDisabled()
            or ns.GUI.Helpers.OptionValues.Get({ "Units", unitKey, auraConfigKey, "placement" }, "ATTACHED") ~= "ATTACHED"
    end

    local function IsLongAuraThresholdDisabled()
        return IsAuraDisabled()
            or ns.GUI.Helpers.OptionValues.Get({ "Units", unitKey, auraConfigKey, "hideLongAuras" }, true) ~= true
    end

    local function ShouldRenderSection(sectionKey)
        local placement = ns.GUI.Helpers.OptionValues.Get({ "Units", unitKey, auraConfigKey, "placement" }, "ATTACHED")

        if sectionKey == "SECTION_ATTACHED" then
            return placement == "ATTACHED"
        end

        if sectionKey == "SECTION_INSIDE" then
            return placement == "INSIDE"
        end

        return true
    end

    local function ShouldSkipItem(def)
        if type(def) ~= "table" or type(def.path) ~= "table" then
            return false
        end

        local fieldKey = def.path[#def.path]
        if auraConfigKey == "Buffs" and fieldKey == "showDispellableOnly" then
            return true
        end

        if auraConfigKey == "Debuffs" and fieldKey == "showStealableOnly" then
            return true
        end

        return false
    end

    local function ResetSection(sectionDef)
        local changed = false

        for _, item in ipairs(sectionDef.items or {}) do
            if not ShouldSkipItem(item) and type(item.path) == "table" then
                local resolvedPath = ResolveLayoutPath(item.path, unitKey, replacements)
                changed = OptionValues.Reset(resolvedPath) or changed
            end
        end

        if changed then
            OptionRefresh.All()
            if ns.GUI and ns.GUI.RefreshOptions then
                ns.GUI:RefreshOptions()
            end
        end
    end

    local intro = AceGUI:Create("Label")
    intro:SetFullWidth(true)
    intro:SetText(L["INFO_AURA_V1_HINT"] or "")
    container:AddChild(intro)

    local spacer = AceGUI:Create("Label")
    spacer:SetFullWidth(true)
    spacer:SetText(" ")
    spacer:SetHeight(6)
    container:AddChild(spacer)

    local function ResolveDisabled(def)
        if def.disabled == "unit" then
            return function()
                return IsUnitDisabled(unitKey)
            end
        end

        if def.disabled == "aura" then
            return IsAuraDisabled
        end

        if def.disabled == "inside" then
            return IsInsideDisabled
        end

        if def.disabled == "attached" then
            return IsAttachedDisabled
        end

        if def.disabled == "longAuraThreshold" then
            return IsLongAuraThresholdDisabled
        end

        return nil
    end

    local function AddSectionWidget(layout, def)
        if ShouldSkipItem(def) then
            return
        end

        local resolvedList = def.list and ResolveLayoutList(AURA_LISTS[def.list]) or nil
        if not CanBuildLayoutWidget(def, resolvedList) then
            return
        end

        if def.widget == "checkbox" then
            AddLayoutHandle(layout, Checkbox.Create({
                path = ResolveLayoutPath(def.path, unitKey, replacements),
                label = ResolveLayoutText(def.label),
                description = ResolveLayoutText(def.description),
                fallback = def.fallback,
                disabled = ResolveDisabled(def),
                refreshGUI = def.refreshGUI,
            }), def)
            return
        end

        if def.widget == "dropdown" then
            AddLayoutHandle(layout, Dropdown.Create({
                path = ResolveLayoutPath(def.path, unitKey, replacements),
                label = ResolveLayoutText(def.label),
                description = ResolveLayoutText(def.description),
                list = resolvedList,
                fallback = def.fallback,
                showReset = false,
                resetText = L["OPTION_RESET"],
                disabled = ResolveDisabled(def),
                refreshGUI = def.refreshGUI,
            }), def)
            return
        end

        if def.widget == "slider" then
            AddLayoutHandle(layout, Slider.Create({
                path = ResolveLayoutPath(def.path, unitKey, replacements),
                label = ResolveLayoutText(def.label),
                description = ResolveLayoutText(def.description),
                min = def.min,
                max = def.max,
                step = def.step,
                fallback = def.fallback,
                format = def.format,
                showReset = false,
                resetText = L["OPTION_RESET"],
                disabled = ResolveDisabled(def),
            }), def)
        end
    end

    for _, sectionDef in ipairs(AURA_LAYOUT) do
        if ShouldRenderSection(sectionDef.section) then
            AddSectionHeading(container, ResolveLayoutText(sectionDef.section), 0, {
                text = L["OPTION_RESET"] or RESET or "Reset",
                width = 112,
                onClick = function()
                    ResetSection(sectionDef)
                end,
            })

            if sectionDef.mode == "section" then
                local layout = CreateSection(container)
                for _, item in ipairs(sectionDef.items) do
                    AddSectionWidget(layout, item)
                end
            end
        end
    end
end

function UnitAurasPage.BuildTabs(container, unitKey, deps)
    local GetGUIState = deps.GetGUIState
    local GetAuraTabValues = deps.GetAuraTabValues
    local BuildScrollableTabContent = deps.BuildScrollableTabContent
    local BuildPlaceholderPage = deps.BuildPlaceholderPage

    container:ReleaseChildren()
    container:SetLayout("Fill")

    local state = GetGUIState()
    state.unitAuraTabs[unitKey] = state.unitAuraTabs[unitKey] or C.Auras.BUFFS
    state.unitAuraScroll[unitKey] = state.unitAuraScroll[unitKey] or {}

    local tabGroup = AceGUI:Create("TabGroup")
    tabGroup:SetFullWidth(true)
    tabGroup:SetFullHeight(true)
    tabGroup:SetLayout("Fill")
    tabGroup:SetTabs(GetAuraTabValues())

    tabGroup:SetCallback("OnGroupSelected", function(widget, _, auraKey)
        state.unitAuraTabs[unitKey] = auraKey
        state.unitAuraScroll[unitKey][auraKey] = state.unitAuraScroll[unitKey][auraKey] or { scrollvalue = 0 }

        BuildScrollableTabContent(widget, state.unitAuraScroll[unitKey][auraKey], function(content)
            if auraKey == C.Auras.BUFFS then
                BuildAuraGroupPage(content, unitKey, "Buffs", ns.GetLabel(KM.Auras, C.Auras.BUFFS), deps)
                return
            end

            if auraKey == C.Auras.DEBUFFS then
                BuildAuraGroupPage(content, unitKey, "Debuffs", ns.GetLabel(KM.Auras, C.Auras.DEBUFFS), deps)
                return
            end

            BuildPlaceholderPage(content, tostring(auraKey))
        end)
    end)

    container:AddChild(tabGroup)
    tabGroup:SelectTab(state.unitAuraTabs[unitKey] or C.Auras.BUFFS)
end
