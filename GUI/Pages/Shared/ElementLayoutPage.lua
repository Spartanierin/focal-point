local _, ns = ...

ns.GUI = ns.GUI or {}
ns.GUI.Pages = ns.GUI.Pages or {}
ns.GUI.Pages.Shared = ns.GUI.Pages.Shared or {}
ns.GUI.Pages.Shared.ElementLayout = ns.GUI.Pages.Shared.ElementLayout or {}

local L = ns.L
local LayoutHelpers = ns.GUI.Helpers.LayoutHelpers
local Checkbox = ns.GUI.Widgets.Checkbox
local Dropdown = ns.GUI.Widgets.Dropdown
local Slider = ns.GUI.Widgets.Sliders

local CreateSection = LayoutHelpers.CreateSection
local AddLayoutHandle = LayoutHelpers.AddLayoutHandle
local ResolveLayoutText = LayoutHelpers.ResolveLayoutText
local ResolveLayoutPath = LayoutHelpers.ResolveLayoutPath
local ResolveLayoutList = LayoutHelpers.ResolveLayoutList
local CanBuildLayoutWidget = LayoutHelpers.CanBuildLayoutWidget

local Page = ns.GUI.Pages.Shared.ElementLayout

function Page.Build(container, unitKey, config, deps)
    deps.ResetFlowContainer(container)

    local unitLabel = ns.GetLabel(ns.KeyMap.Units, unitKey)

    local function IsUnitDisabled()
        return not ns.GUI.Helpers.OptionValues.Get({ "Units", unitKey, "enabled" }, true)
    end

    local function IsElementDisabled()
        if type(config.isUnavailable) == "function" and config.isUnavailable(unitKey) then
            return true
        end

        return IsUnitDisabled()
            or not ns.GUI.Helpers.OptionValues.Get({ "Units", unitKey, config.optionKey, "enabled" }, true)
    end

    local function IsInsideDisabled()
        return IsElementDisabled()
            or ns.GUI.Helpers.OptionValues.Get({ "Units", unitKey, config.optionKey, "placement" }, "ATTACHED") ~= "INSIDE"
    end

    local function IsAttachedDisabled()
        return IsElementDisabled()
            or ns.GUI.Helpers.OptionValues.Get({ "Units", unitKey, config.optionKey, "placement" }, "ATTACHED") ~= "ATTACHED"
    end

    local function ResolveDisabled(def)
        if def.disabled == "unit" then
            return IsUnitDisabled
        end

        if def.disabled == config.disabledKey then
            return IsElementDisabled
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
        local resolvedList = def.list and ResolveLayoutList(config.lists[def.list]) or nil

        if not CanBuildLayoutWidget(def, resolvedList) then
            return
        end

        if def.widget == "checkbox" then
            AddLayoutHandle(layout, Checkbox.Create({
                path = ResolveLayoutPath(def.path, unitKey),
                label = ResolveLayoutText(def.label),
                description = ResolveLayoutText(def.description),
                fallback = def.fallback,
                resetText = L["OPTION_RESET"],
                disabled = ResolveDisabled(def),
                refreshGUI = def.refreshGUI,
            }), def)
            return
        end

        if def.widget == "dropdown" then
            AddLayoutHandle(layout, Dropdown.Create({
                path = ResolveLayoutPath(def.path, unitKey),
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
                path = ResolveLayoutPath(def.path, unitKey),
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

    deps.AddPageHeading(container, unitLabel .. " - " .. ns.GetLabel(ns.KeyMap.Tabs, ns.Constants.Tabs.ELEMENTS) .. " - " .. ns.GetLabel(ns.KeyMap.Elements, config.elementKey))

    for _, sectionDef in ipairs(config.layout) do
        deps.AddSectionHeading(container, ResolveLayoutText(sectionDef.section))

        if sectionDef.mode == "section" then
            local layout = CreateSection(container)
            for _, item in ipairs(sectionDef.items) do
                AddSectionWidget(layout, item)
            end
        end
    end
end
