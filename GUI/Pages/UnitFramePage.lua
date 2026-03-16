local _, ns = ...

ns.GUI = ns.GUI or {}
ns.GUI.Pages = ns.GUI.Pages or {}

local AceGUI = LibStub("AceGUI-3.0")
local C = ns.Constants
local KM = ns.KeyMap
local L = ns.L
local Slider = ns.GUI.Widgets.Sliders
local Dropdown = ns.GUI.Widgets.Dropdown

local UnitFramePage = {}
ns.GUI.Pages.UnitFrame = UnitFramePage

function UnitFramePage.Build(container, unitKey, deps)
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

    local function IsUnitDisabled()
        return not ns.GUI.Helpers.OptionValues.Get({ "Units", unitKey, "enabled" }, true)
    end

    local FRAME_TAB_LISTS = ns.GUI.Layouts.UnitFrame.Lists
    local FRAME_TAB_LAYOUT = ns.GUI.Layouts.UnitFrame.FrameTab

    AddPageHeading(container, unitLabel .. " - " .. ns.GetLabel(KM.Tabs, C.Tabs.FRAME))

    local function AddDirectCheckbox(def)
        if not CanBuildLayoutWidget(def) then
            return
        end

        local checkbox = AceGUI:Create("CheckBox")
        local path = ResolveLayoutPath(def.path, unitKey)
        checkbox:SetLabel(ResolveLayoutText(def.label))
        checkbox:SetValue(ns.GUI.Helpers.OptionValues.Get(path, def.fallback) and true or false)
        checkbox:SetFullWidth(true)
        checkbox:SetDisabled(path[3] ~= "enabled" and IsUnitDisabled())
        checkbox:SetCallback("OnValueChanged", function(_, _, newValue)
            if path[3] ~= "enabled" and IsUnitDisabled() then
                return
            end

            ns.GUI.Helpers.OptionValues.Set(path, newValue and true or false)
            ns.GUI.Helpers.OptionRefresh.Live()

            if def.refreshGUI then
                ns.GUI:RefreshOptions()
            end
        end)
        container:AddChild(checkbox)

        if def.description and def.description ~= "" then
            local description = AceGUI:Create("Label")
            description:SetFullWidth(true)
            description:SetText(ResolveLayoutText(def.description))
            container:AddChild(description)
        end
    end

    local function AddDirectLayerDropdown(def)
        local resolvedList = def.list and ResolveLayoutList(FRAME_TAB_LISTS[def.list]) or nil

        if not CanBuildLayoutWidget(def, resolvedList) then
            return
        end

        local dropdown = AceGUI:Create("Dropdown")
        local path = ResolveLayoutPath(def.path, unitKey)
        dropdown:SetLabel(ResolveLayoutText(def.label))
        dropdown:SetList(resolvedList)
        dropdown:SetWidth(220)
        dropdown:SetValue(ns.GUI.Helpers.OptionValues.Get(path, def.fallback))
        dropdown:SetDisabled(IsUnitDisabled())
        dropdown:SetCallback("OnValueChanged", function(_, _, newValue)
            if IsUnitDisabled() then
                return
            end

            ns.GUI.Helpers.OptionValues.Set(path, newValue)
            ns.GUI.Helpers.OptionRefresh.Live()
        end)
        container:AddChild(dropdown)

        if def.description and def.description ~= "" then
            local description = AceGUI:Create("Label")
            description:SetFullWidth(true)
            description:SetText(ResolveLayoutText(def.description))
            container:AddChild(description)
        end
    end

    local function AddDirectLayerSlider(def)
        if not CanBuildLayoutWidget(def) then
            return
        end

        local slider = AceGUI:Create("Slider")
        local path = ResolveLayoutPath(def.path, unitKey)
        slider:SetLabel(ResolveLayoutText(def.label))
        slider:SetSliderValues(def.min, def.max, def.step)
        slider:SetWidth(220)
        slider:SetValue(tonumber(ns.GUI.Helpers.OptionValues.Get(path, def.fallback)) or def.fallback)
        slider:SetDisabled(IsUnitDisabled())
        slider:SetCallback("OnValueChanged", function(_, _, newValue)
            if IsUnitDisabled() then
                return
            end

            ns.GUI.Helpers.OptionValues.Set(path, tonumber(newValue) or def.fallback)
            ns.GUI.Helpers.OptionRefresh.Live()
        end)
        container:AddChild(slider)

        if def.description and def.description ~= "" then
            local description = AceGUI:Create("Label")
            description:SetFullWidth(true)
            description:SetText(ResolveLayoutText(def.description))
            container:AddChild(description)
        end
    end

    local function AddSectionWidget(layout, def)
        local resolvedList = def.list and ResolveLayoutList(FRAME_TAB_LISTS[def.list]) or nil

        if not CanBuildLayoutWidget(def, resolvedList) then
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
                disabled = IsUnitDisabled,
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
                disabled = IsUnitDisabled,
            }), def)
        end
    end

    for _, sectionDef in ipairs(FRAME_TAB_LAYOUT) do
        AddSectionHeading(container, ResolveLayoutText(sectionDef.section))

        if sectionDef.mode == "direct_checkboxes" then
            for _, item in ipairs(sectionDef.items) do
                AddDirectCheckbox(item)
            end
        elseif sectionDef.mode == "direct_layering" then
            for _, item in ipairs(sectionDef.items) do
                if item.widget == "dropdown" then
                    AddDirectLayerDropdown(item)
                elseif item.widget == "slider" then
                    AddDirectLayerSlider(item)
                end
            end
        elseif sectionDef.mode == "section" then
            local layout = CreateSection(container)
            for _, item in ipairs(sectionDef.items) do
                AddSectionWidget(layout, item)
            end
        end
    end
end
