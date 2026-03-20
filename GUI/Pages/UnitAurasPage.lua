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

local UnitAurasPage = {}
ns.GUI.Pages.UnitAuras = UnitAurasPage

local function IsUnitDisabled(unitKey)
    return not ns.GUI.Helpers.OptionValues.Get({ "Units", unitKey, "enabled" }, true)
end

local function BuildAuraGroupPage(container, unitKey, auraConfigKey, auraLabel, deps)
    local ResetFlowContainer = deps.ResetFlowContainer
    local AddPageHeading = deps.AddPageHeading
    local AddSectionHeading = deps.AddSectionHeading
    local CreateSection = deps.CreateSection
    local AddLayoutHandle = deps.AddLayoutHandle
    local ResolveLayoutText = deps.ResolveLayoutText
    local ResolveLayoutPath = deps.ResolveLayoutPath
    local ResolveLayoutList = deps.ResolveLayoutList
    local CanBuildLayoutWidget = deps.CanBuildLayoutWidget

    ResetFlowContainer(container)

    local unitLabel = ns.GetLabel(KM.Units, unitKey)
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

    AddPageHeading(container, unitLabel .. " - " .. ns.GetLabel(KM.Tabs, C.Tabs.AURAS) .. " - " .. auraLabel)

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

        return nil
    end

    local function AddSectionWidget(layout, def)
        if type(def.path) == "table" then
            local fieldKey = def.path[#def.path]
            if auraConfigKey == "Buffs" and fieldKey == "showDispellableOnly" then
                return
            end

            if auraConfigKey == "Debuffs" and fieldKey == "showStealableOnly" then
                return
            end
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
                resetText = L["OPTION_RESET"],
                disabled = ResolveDisabled(def),
            }), def)
        end
    end

    for _, sectionDef in ipairs(AURA_LAYOUT) do
        AddSectionHeading(container, ResolveLayoutText(sectionDef.section))

        if sectionDef.mode == "section" then
            local layout = CreateSection(container)
            for _, item in ipairs(sectionDef.items) do
                AddSectionWidget(layout, item)
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
