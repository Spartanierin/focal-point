local _, ns = ...

ns.GUI = ns.GUI or {}
ns.GUI.Pages = ns.GUI.Pages or {}

local AceGUI = LibStub("AceGUI-3.0")
local C = ns.Constants
local KM = ns.KeyMap
local L = ns.L
local Checkbox = ns.GUI.Widgets.Checkbox
local OptionValues = ns.GUI.Helpers.OptionValues
local OptionRefresh = ns.GUI.Helpers.OptionRefresh
local Slider = ns.GUI.Widgets.Sliders
local Dropdown = ns.GUI.Widgets.Dropdown
local LayoutHelpers = ns.GUI.Helpers.LayoutHelpers

local UnitFramePage = {}
ns.GUI.Pages.UnitFrame = UnitFramePage

function UnitFramePage.Build(container, unitKey, deps)
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
    local function IsUnitDisabled()
        return not ns.GUI.Helpers.OptionValues.Get({ "Units", unitKey, "enabled" }, true)
    end

    local FRAME_TAB_LISTS = ns.GUI.Layouts.UnitFrame.Lists
    local FRAME_TAB_LAYOUT = ns.GUI.Layouts.UnitFrame.FrameTab

    local function AddSectionWidget(layout, def)
        local resolvedList = def.list and ResolveLayoutList(FRAME_TAB_LISTS[def.list]) or nil

        if not CanBuildLayoutWidget(def, resolvedList) then
            return
        end

        local resolvedPath = ResolveLayoutPath(def.path, unitKey)
        local disabledResolver = IsUnitDisabled
        if def.widget == "checkbox"
            and type(resolvedPath) == "table"
            and resolvedPath[1] == "Units"
            and resolvedPath[#resolvedPath] == "enabled"
        then
            disabledResolver = nil
        end

        if def.widget == "checkbox" then
            AddLayoutHandle(layout, Checkbox.Create({
                path = resolvedPath,
                label = ResolveLayoutText(def.label),
                description = ResolveLayoutText(def.description),
                fallback = def.fallback,
                showReset = false,
                resetText = L["OPTION_RESET"],
                disabled = disabledResolver,
                refreshGUI = def.refreshGUI,
            }), def)
            return
        end

        if def.widget == "slider" then
            AddLayoutHandle(layout, Slider.Create({
                path = resolvedPath,
                label = ResolveLayoutText(def.label),
                description = ResolveLayoutText(def.description),
                min = def.min,
                max = def.max,
                step = def.step,
                fallback = def.fallback,
                format = def.format,
                showReset = false,
                resetText = L["OPTION_RESET"],
                disabled = disabledResolver,
            }), def)
            return
        end

        if def.widget == "dropdown" then
            AddLayoutHandle(layout, Dropdown.Create({
                path = resolvedPath,
                label = ResolveLayoutText(def.label),
                description = ResolveLayoutText(def.description),
                list = resolvedList,
                fallback = def.fallback,
                showReset = false,
                resetText = L["OPTION_RESET"],
                disabled = disabledResolver,
            }), def)
        end
    end

    local function ResetSection(sectionDef)
        local changed = false

        for _, item in ipairs(sectionDef.items or {}) do
            if type(item.path) == "table" then
                local resolvedPath = ResolveLayoutPath(item.path, unitKey)
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

    for _, sectionDef in ipairs(FRAME_TAB_LAYOUT) do
        AddSectionHeading(container, ResolveLayoutText(sectionDef.section), 0, {
            text = L["OPTION_RESET"] or RESET or "Reset",
            width = 112,
            onClick = function()
                ResetSection(sectionDef)
            end,
        })

        local layout = CreateSection(container)
        for _, item in ipairs(sectionDef.items) do
            AddSectionWidget(layout, item)
        end
    end
end
