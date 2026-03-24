local _, ns = ...

ns.GUI = ns.GUI or {}
ns.GUI.Pages = ns.GUI.Pages or {}

local AceGUI = LibStub("AceGUI-3.0")
local C = ns.Constants
local KM = ns.KeyMap
local L = ns.L
local OptionValues = ns.GUI.Helpers.OptionValues
local OptionRefresh = ns.GUI.Helpers.OptionRefresh
local LayoutHelpers = ns.GUI.Helpers.LayoutHelpers
local TextStyles = ns.GUI.Helpers.TextStyles
local ColorPicker = ns.GUI.Widgets.ColorPicker
local Slider = ns.GUI.Widgets.Sliders
local Dropdown = ns.GUI.Widgets.Dropdown
local Checkbox = ns.GUI.Widgets.Checkbox

local UnitBarsPage = {}
ns.GUI.Pages.UnitBars = UnitBarsPage

local function IsUnitDisabled(unitKey)
    return not ns.GUI.Helpers.OptionValues.Get({ "Units", unitKey, "enabled" }, true)
end

function UnitBarsPage.BuildHealth(container, unitKey, deps)
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
    local HEALTH_BAR_LAYOUT = ns.GUI.Layouts.UnitBars.HealthBarTab
    local BAR_LISTS = ns.GUI.Layouts.UnitBars.Lists

    local function IsHealthColorPickerDisabled()
        return IsUnitDisabled(unitKey)
            or ns.GUI.Helpers.OptionValues.Get({ "Units", unitKey, "useClassColorHealth" }, false)
    end

    local function IsHealthBackgroundPickerDisabled()
        return IsUnitDisabled(unitKey)
            or not ns.GUI.Helpers.OptionValues.Get({ "Units", unitKey, "healthBackground" }, true)
    end

    local function ResolveDisabled(def)
        if def.disabled == "unit" then
            return function()
                return IsUnitDisabled(unitKey)
            end
        end

        if def.disabled == "healthColor" then
            return IsHealthColorPickerDisabled
        end

        if def.disabled == "healthBackground" then
            return IsHealthBackgroundPickerDisabled
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

    local function CreateStaticEnabledHandle()
        local group = AceGUI:Create("SimpleGroup")
        group:SetFullWidth(true)
        group:SetLayout("List")

        local row = AceGUI:Create("SimpleGroup")
        row:SetFullWidth(true)
        row:SetLayout("Flow")
        group:AddChild(row)

        local checkbox = AceGUI:Create("CheckBox")
        checkbox:SetLabel(ResolveLayoutText("OPTION_ENABLED"))
        checkbox:SetValue(true)
        checkbox:SetWidth(220)
        checkbox:SetDisabled(true)
        if TextStyles and TextStyles.ApplyInteractiveWidgetText then
            TextStyles.ApplyInteractiveWidgetText(checkbox, "label", false, { size = 12 })
        end
        row:AddChild(checkbox)

        local description = AceGUI:Create("Label")
        description:SetFullWidth(true)
        description:SetText(ResolveLayoutText("OPTION_HEALTH_BAR_ALWAYS_ENABLED_DESC"))
        if TextStyles and TextStyles.ApplyLabelWidget then
            TextStyles.ApplyLabelWidget(description, "help", { size = 11 })
        end
        group:AddChild(description)

        return {
            group = group,
        }
    end

    local function AddSectionWidget(layout, def, state)
        if def.widget == "static_enabled" then
            AddLayoutHandle(layout, CreateStaticEnabledHandle(), def)
            return
        end

        local resolvedList = def.list and ResolveLayoutList(BAR_LISTS[def.list]) or nil
        local fallbackValue = def.fallback
        if def.path and unitKey == "target" then
            local fieldKey = def.path[#def.path]
            if fieldKey == "healthBarReverseFill" or fieldKey == "powerBarReverseFill" then
                fallbackValue = true
            end
        end

        if def.widget == "colorpicker" then
            local picker = ColorPicker.Create({
                path = ResolveLayoutPath(def.path, unitKey),
                label = ResolveLayoutText(def.label),
                description = ResolveLayoutText(def.description),
                hasAlpha = def.hasAlpha == true,
                fallback = fallbackValue,
                resetText = L["OPTION_RESET"],
                disabled = ResolveDisabled(def),
            })
            AddLayoutHandle(layout, picker, def)

            if def.path[#def.path] == "healthColor" then
                state.healthColorPickerHandle = picker
            end

            return
        end

        if not CanBuildLayoutWidget(def, resolvedList) then
            return
        end

        if def.widget == "dropdown" then
            AddLayoutHandle(layout, Dropdown.Create({
                path = ResolveLayoutPath(def.path, unitKey),
                label = ResolveLayoutText(def.label),
                description = ResolveLayoutText(def.description),
                list = resolvedList,
                fallback = fallbackValue,
                showReset = false,
                resetText = def.resetText ~= nil and def.resetText or L["OPTION_RESET"],
                disabled = def.disabled == "unit" and function()
                    return IsUnitDisabled(unitKey)
                end or nil,
                refreshGUI = def.refreshGUI,
            }), def)
            return
        end

        if def.widget == "checkbox" then
            AddLayoutHandle(layout, Checkbox.Create({
                path = ResolveLayoutPath(def.path, unitKey),
                label = ResolveLayoutText(def.label),
                description = ResolveLayoutText(def.description),
                fallback = fallbackValue,
                showReset = false,
                resetText = def.resetText ~= nil and def.resetText or L["OPTION_RESET"],
                disabled = ResolveDisabled(def),
                refreshGUI = def.refreshGUI,
                onChanged = function()
                    if def.onChanged == "refresh_health_color"
                        and state.healthColorPickerHandle
                        and state.healthColorPickerHandle.RefreshState
                    then
                        state.healthColorPickerHandle.RefreshState()
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
                resetText = def.resetText ~= nil and def.resetText or L["OPTION_RESET"],
                disabled = ResolveDisabled(def),
            }), def)
        end
    end

    for _, sectionDef in ipairs(HEALTH_BAR_LAYOUT) do
        AddSectionHeading(container, ResolveLayoutText(sectionDef.section), 0, {
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
                AddSectionWidget(layout, item, sectionState)
            end
        end
    end
end

function UnitBarsPage.BuildPower(container, unitKey, deps)
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
    local POWER_BAR_LAYOUT = ns.GUI.Layouts.UnitBars.PowerBarTab
    local BAR_LISTS = ns.GUI.Layouts.UnitBars.Lists

    local function IsPowerBarDisabled()
        return IsUnitDisabled(unitKey)
            or not ns.GUI.Helpers.OptionValues.Get({ "Units", unitKey, "showPowerBar" }, true)
    end

    local function IsAlternativePowerBarDisabled()
        return IsUnitDisabled(unitKey)
            or not ns.GUI.Helpers.OptionValues.Get({ "Units", unitKey, "showAlternativePowerBar" }, false)
    end

    local function IsPowerColorPickerDisabled()
        return IsPowerBarDisabled()
            or ns.GUI.Helpers.OptionValues.Get({ "Units", unitKey, "useClassColorPower" }, false)
    end

    local function IsPowerBackgroundPickerDisabled()
        return IsPowerBarDisabled()
            or not ns.GUI.Helpers.OptionValues.Get({ "Units", unitKey, "powerBackground" }, true)
    end

    local function ResolveDisabled(def)
        if def.disabled == "unit" then
            return function()
                return IsUnitDisabled(unitKey)
            end
        end

        if def.disabled == "power" then
            return IsPowerBarDisabled
        end

        if def.disabled == "alternativePower" then
            return IsAlternativePowerBarDisabled
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

    local function AddSectionWidget(layout, def, state)
        local resolvedList = def.list and ResolveLayoutList(BAR_LISTS[def.list]) or nil
        local fallbackValue = def.fallback
        if def.path and unitKey == "target" then
            local fieldKey = def.path[#def.path]
            if fieldKey == "healthBarReverseFill" or fieldKey == "powerBarReverseFill" then
                fallbackValue = true
            end
        end

        if def.widget == "colorpicker" then
            local picker = ColorPicker.Create({
                path = ResolveLayoutPath(def.path, unitKey),
                label = ResolveLayoutText(def.label),
                description = ResolveLayoutText(def.description),
                hasAlpha = def.hasAlpha == true,
                fallback = fallbackValue,
                resetText = L["OPTION_RESET"],
                disabled = ResolveDisabled(def),
            })
            AddLayoutHandle(layout, picker, def)

            if def.path[#def.path] == "powerColor" then
                state.powerColorPickerHandle = picker
            end

            return
        end

        if not CanBuildLayoutWidget(def, resolvedList) then
            return
        end

        if def.widget == "dropdown" then
            AddLayoutHandle(layout, Dropdown.Create({
                path = ResolveLayoutPath(def.path, unitKey),
                label = ResolveLayoutText(def.label),
                description = ResolveLayoutText(def.description),
                list = resolvedList,
                fallback = fallbackValue,
                showReset = false,
                resetText = def.resetText ~= nil and def.resetText or L["OPTION_RESET"],
                disabled = ResolveDisabled(def),
                refreshGUI = def.refreshGUI,
            }), def)
            return
        end

        if def.widget == "checkbox" then
            AddLayoutHandle(layout, Checkbox.Create({
                path = ResolveLayoutPath(def.path, unitKey),
                label = ResolveLayoutText(def.label),
                description = ResolveLayoutText(def.description),
                fallback = fallbackValue,
                showReset = false,
                resetText = def.resetText ~= nil and def.resetText or L["OPTION_RESET"],
                disabled = ResolveDisabled(def),
                refreshGUI = def.refreshGUI,
                onChanged = function()
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
                resetText = def.resetText ~= nil and def.resetText or L["OPTION_RESET"],
                disabled = ResolveDisabled(def),
            }), def)
        end
    end

    for _, sectionDef in ipairs(POWER_BAR_LAYOUT) do
        AddSectionHeading(container, ResolveLayoutText(sectionDef.section), 0, {
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
                AddSectionWidget(layout, item, sectionState)
            end
        end
    end
end

function UnitBarsPage.BuildAlternativePower(container, unitKey, deps)
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
    local ALT_POWER_BAR_LAYOUT = ns.GUI.Layouts.UnitBars.AlternativePowerBarTab

    local function IsAlternativePowerBarDisabled()
        return IsUnitDisabled(unitKey)
            or not ns.GUI.Helpers.OptionValues.Get({ "Units", unitKey, "showAlternativePowerBar" }, false)
    end

    local info = AceGUI:Create("Label")
    info:SetFullWidth(true)
    info:SetText(L["INFO_ALTERNATIVE_POWER_BAR_HINT"] or "")
    container:AddChild(info)

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

        if def.disabled == "alternativePower" then
            return IsAlternativePowerBarDisabled
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

    local function AddSectionWidget(layout, def)
        if def.widget == "checkbox" then
            AddLayoutHandle(layout, Checkbox.Create({
                path = ResolveLayoutPath(def.path, unitKey),
                label = ResolveLayoutText(def.label),
                description = ResolveLayoutText(def.description),
                fallback = def.fallback,
                showReset = false,
                resetText = def.resetText ~= nil and def.resetText or L["OPTION_RESET"],
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
                showReset = false,
                resetText = def.resetText ~= nil and def.resetText or L["OPTION_RESET"],
                disabled = ResolveDisabled(def),
            }), def)
        end
    end

    for _, sectionDef in ipairs(ALT_POWER_BAR_LAYOUT) do
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

function UnitBarsPage.BuildCast(container, unitKey, deps)
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
    local CAST_BAR_LAYOUT = ns.GUI.Layouts.UnitBars.CastBarTab
    local BAR_LISTS = ns.GUI.Layouts.UnitBars.Lists

    local function IsCastBarDisabled()
        return IsUnitDisabled(unitKey)
            or not ns.GUI.Helpers.OptionValues.Get({ "Units", unitKey, "showCastBar" }, true)
    end

    local function ResolveDisabled(def)
        if def.disabled == "unit" then
            return function()
                return IsUnitDisabled(unitKey)
            end
        end

        if def.disabled == "cast" then
            return IsCastBarDisabled
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

    local function AddSectionWidget(layout, def)
        local resolvedList = def.list and ResolveLayoutList(BAR_LISTS[def.list]) or nil

        if def.widget == "colorpicker" then
            AddLayoutHandle(layout, ColorPicker.Create({
                path = ResolveLayoutPath(def.path, unitKey),
                label = ResolveLayoutText(def.label),
                description = ResolveLayoutText(def.description),
                hasAlpha = def.hasAlpha == true,
                fallback = def.fallback,
                resetText = L["OPTION_RESET"],
                disabled = ResolveDisabled(def),
            }), def)
            return
        end

        if not CanBuildLayoutWidget(def, resolvedList) then
            return
        end

        if def.widget == "dropdown" then
            AddLayoutHandle(layout, Dropdown.Create({
                path = ResolveLayoutPath(def.path, unitKey),
                label = ResolveLayoutText(def.label),
                description = ResolveLayoutText(def.description),
                list = resolvedList,
                fallback = def.fallback,
                showReset = false,
                resetText = def.resetText ~= nil and def.resetText or L["OPTION_RESET"],
                disabled = ResolveDisabled(def),
                refreshGUI = def.refreshGUI,
            }), def)
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
                showReset = false,
                resetText = def.resetText ~= nil and def.resetText or L["OPTION_RESET"],
                disabled = ResolveDisabled(def),
            }), def)
        end
    end

    for _, sectionDef in ipairs(CAST_BAR_LAYOUT) do
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

function UnitBarsPage.BuildTabs(container, unitKey, deps)
    local GetGUIState = deps.GetGUIState
    local GetBarTabValues = deps.GetBarTabValues
    local BuildScrollableTabContent = deps.BuildScrollableTabContent
    local BuildPlaceholderPage = deps.BuildPlaceholderPage

    container:ReleaseChildren()
    container:SetLayout("Fill")

    local state = GetGUIState()
    state.unitBarTabs[unitKey] = state.unitBarTabs[unitKey] or C.Bars.HEALTH
    state.unitBarScroll[unitKey] = state.unitBarScroll[unitKey] or {}

    local tabGroup = AceGUI:Create("TabGroup")
    tabGroup:SetFullWidth(true)
    tabGroup:SetFullHeight(true)
    tabGroup:SetLayout("Fill")
    tabGroup:SetTabs(GetBarTabValues())

    tabGroup:SetCallback("OnGroupSelected", function(widget, _, barKey)
        state.unitBarTabs[unitKey] = barKey
        state.unitBarScroll[unitKey][barKey] = state.unitBarScroll[unitKey][barKey] or { scrollvalue = 0 }

        BuildScrollableTabContent(widget, state.unitBarScroll[unitKey][barKey], function(content)
            if barKey == C.Bars.HEALTH then
                UnitBarsPage.BuildHealth(content, unitKey, deps)
                return
            end

            if barKey == C.Bars.POWER then
                UnitBarsPage.BuildPower(content, unitKey, deps)
                return
            end

            if barKey == C.Bars.ALT_POWER then
                UnitBarsPage.BuildAlternativePower(content, unitKey, deps)
                return
            end

            if barKey == C.Bars.CAST then
                UnitBarsPage.BuildCast(content, unitKey, deps)
                return
            end

            BuildPlaceholderPage(content, ns.GetLabel(KM.Bars, barKey))
        end)
    end)

    container:AddChild(tabGroup)
    tabGroup:SelectTab(state.unitBarTabs[unitKey] or C.Bars.HEALTH)
end
