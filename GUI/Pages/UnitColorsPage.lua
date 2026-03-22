local _, ns = ...

ns.GUI = ns.GUI or {}
ns.GUI.Pages = ns.GUI.Pages or {}

local C = ns.Constants
local KM = ns.KeyMap
local L = ns.L
local OptionValues = ns.GUI.Helpers.OptionValues
local OptionRefresh = ns.GUI.Helpers.OptionRefresh
local LayoutHelpers = ns.GUI.Helpers.LayoutHelpers
local ColorPicker = ns.GUI.Widgets.ColorPicker
local Checkbox = ns.GUI.Widgets.Checkbox
local Slider = ns.GUI.Widgets.Sliders

local UnitColorsPage = {}
ns.GUI.Pages.UnitColors = UnitColorsPage

function UnitColorsPage.Build(container, unitKey, deps)
    local ResetFlowContainer = deps.ResetFlowContainer
    local AddSectionHeading = deps.AddSectionHeading
    local CreateSection = deps.CreateSection
    local AddLayoutHandle = deps.AddLayoutHandle
    local ResolveLayoutText = deps.ResolveLayoutText
    local ResolveLayoutPath = deps.ResolveLayoutPath

    ResetFlowContainer(container)
    if LayoutHelpers and LayoutHelpers.ApplyUnitLayoutDefaults then
        LayoutHelpers.ApplyUnitLayoutDefaults(container)
    end
    local COLORS_TAB_LAYOUT = ns.GUI.Layouts.UnitColors.ColorTab

    local function IsUnitDisabled()
        return not ns.GUI.Helpers.OptionValues.Get({ "Units", unitKey, "enabled" }, true)
    end

    local function IsPowerBarDisabled()
        return IsUnitDisabled()
            or not ns.GUI.Helpers.OptionValues.Get({ "Units", unitKey, "showPowerBar" }, true)
    end

    local function IsAlternativePowerBarDisabled()
        return IsUnitDisabled()
            or not ns.GUI.Helpers.OptionValues.Get({ "Units", unitKey, "showAlternativePowerBar" }, false)
    end

    local function IsCastBarDisabled()
        return IsUnitDisabled()
            or not ns.GUI.Helpers.OptionValues.Get({ "Units", unitKey, "showCastBar" }, true)
    end

    local function IsHealthColorPickerDisabled()
        return IsUnitDisabled()
            or ns.GUI.Helpers.OptionValues.Get({ "Units", unitKey, "useClassColorHealth" }, false)
    end

    local function IsHealthBackgroundPickerDisabled()
        return IsUnitDisabled()
            or not ns.GUI.Helpers.OptionValues.Get({ "Units", unitKey, "healthBackground" }, true)
    end

    local function IsPowerColorPickerDisabled()
        return IsPowerBarDisabled()
            or ns.GUI.Helpers.OptionValues.Get({ "Units", unitKey, "useClassColorPower" }, false)
    end

    local function IsPowerBackgroundPickerDisabled()
        return IsPowerBarDisabled()
            or not ns.GUI.Helpers.OptionValues.Get({ "Units", unitKey, "powerBackground" }, true)
    end

    local function ResolveColorSectionHeading(sectionKey)
        if sectionKey == "$healthBar" then
            return ns.GetLabel(KM.Bars, C.Bars.HEALTH)
        end

        if sectionKey == "$powerBar" then
            return ns.GetLabel(KM.Bars, C.Bars.POWER)
        end

        if sectionKey == "$castBar" then
            return ns.GetLabel(KM.Bars, C.Bars.CAST)
        end

        if sectionKey == "$texts" then
            return ns.GetLabel(KM.Tabs, C.Tabs.TEXTS)
        end

        return ResolveLayoutText(sectionKey)
    end

    local function ResolveColorDisabled(def)
        if def.disabled == "unit" then
            return IsUnitDisabled
        end

        if def.disabled == "power" then
            return IsPowerBarDisabled
        end

        if def.disabled == "cast" then
            return IsCastBarDisabled
        end

        if def.disabled == "healthColor" then
            return IsHealthColorPickerDisabled
        end

        if def.disabled == "healthBackground" then
            return IsHealthBackgroundPickerDisabled
        end

        if def.disabled == "powerColor" then
            return IsPowerColorPickerDisabled
        end

        if def.disabled == "powerBackground" then
            return IsPowerBackgroundPickerDisabled
        end

        return nil
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

    local function AddColorSectionWidget(layout, def, state)
        if type(def) ~= "table" or type(def.path) ~= "table" then
            return
        end

        if def.widget == "colorpicker" then
            local picker = ColorPicker.Create({
                path = ResolveLayoutPath(def.path, unitKey),
                label = ResolveLayoutText(def.label),
                description = ResolveLayoutText(def.description),
                hasAlpha = def.hasAlpha == true,
                resetText = L["OPTION_RESET"],
                disabled = ResolveColorDisabled(def),
            })

            AddLayoutHandle(layout, picker, def)

            if def.path[#def.path] == "healthColor" then
                state.healthColorPickerHandle = picker
            end

            if def.path[#def.path] == "powerColor" then
                state.powerColorPickerHandle = picker
            end

            return
        end

        if def.widget == "checkbox" then
            AddLayoutHandle(layout, Checkbox.Create({
                path = ResolveLayoutPath(def.path, unitKey),
                label = ResolveLayoutText(def.label),
                description = ResolveLayoutText(def.description),
                fallback = def.fallback,
                showReset = false,
                resetText = def.resetText ~= nil and def.resetText or L["OPTION_RESET"],
                disabled = ResolveColorDisabled(def),
                refreshGUI = def.refreshGUI,
                onChanged = function()
                    if def.onChanged == "refresh_health_color"
                        and state.healthColorPickerHandle
                        and state.healthColorPickerHandle.RefreshState
                    then
                        state.healthColorPickerHandle.RefreshState()
                    end

                    if def.onChanged == "refresh_power_color"
                        and state.powerColorPickerHandle
                        and state.powerColorPickerHandle.RefreshState
                    then
                        state.powerColorPickerHandle.RefreshState()
                    end
                end,
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
                showReset = false,
                resetText = L["OPTION_RESET"],
                disabled = ResolveColorDisabled(def),
            }), def)
        end
    end

    for _, sectionDef in ipairs(COLORS_TAB_LAYOUT) do
        AddSectionHeading(container, ResolveColorSectionHeading(sectionDef.section), 0, {
            text = L["OPTION_RESET"] or RESET or "Reset",
            width = 112,
            onClick = function()
                ResetSection(sectionDef)
            end,
        })

        if sectionDef.mode == "section" then
            local layout = CreateSection(container)
            local sectionState = {}

            for _, item in ipairs(sectionDef.items) do
                AddColorSectionWidget(layout, item, sectionState)
            end
        end
    end
end
