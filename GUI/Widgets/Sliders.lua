local _, PORTRAIT = ...

PORTRAIT.GUI = PORTRAIT.GUI or {}
PORTRAIT.GUI.Widgets = PORTRAIT.GUI.Widgets or {}

local AceGUI = LibStub("AceGUI-3.0")

local OptionValues = PORTRAIT.GUI.Helpers.OptionValues
local OptionRefresh = PORTRAIT.GUI.Helpers.OptionRefresh

local Sliders = {}
PORTRAIT.GUI.Widgets.Sliders = Sliders

local function NormalizeNumber(value, fallback)
    if type(value) == "number" then
        return value
    end

    if type(fallback) == "number" then
        return fallback
    end

    return 0
end

function Sliders.Create(config)
    if type(config) ~= "table" then
        return nil
    end

    if type(config.path) ~= "table" or #config.path == 0 then
        return nil
    end

    local labelText = config.label or "[Missing Label]"
    local descriptionText = config.description
    local fallbackValue = NormalizeNumber(config.fallback, 0)

    local minValue = tonumber(config.min) or 0
    local maxValue = tonumber(config.max) or 100
    local stepValue = tonumber(config.step) or 1

    local group = AceGUI:Create("SimpleGroup")
    group:SetFullWidth(true)
    group:SetLayout("Flow")

    local row = AceGUI:Create("SimpleGroup")
    row:SetFullWidth(true)
    row:SetLayout("Flow")
    group:AddChild(row)

    local slider = AceGUI:Create("Slider")
    slider:SetLabel(labelText)
    slider:SetSliderValues(minValue, maxValue, stepValue)
    slider:SetWidth(config.width or 220)
    row:AddChild(slider)

    local resetButton = nil
    if config.showReset ~= false then
        resetButton = AceGUI:Create("Button")
        resetButton:SetText(config.resetText or "Reset")
        resetButton:SetWidth(config.resetWidth or 100)
        row:AddChild(resetButton)
    end

    if descriptionText and descriptionText ~= "" then
        local description = AceGUI:Create("Label")
        description:SetFullWidth(true)
        description:SetText(descriptionText)
        group:AddChild(description)
    end

    local isUpdating = false

    local function IsDisabled()
        return OptionValues.ResolveState(config.disabled, config)
    end

    local function IsLocked()
        return OptionValues.ResolveState(config.locked, config)
    end

    local function ApplyState()
        local disabled = IsDisabled()
        local locked = IsLocked()
        local interactive = not disabled and not locked

        slider:SetDisabled(not interactive)

        if resetButton then
            resetButton:SetDisabled(not interactive)
        end
    end

    local function UpdateUI(value)
        isUpdating = true
        slider:SetValue(value)
        ApplyState()
        isUpdating = false
    end

    local function SaveValue(value)
        if IsDisabled() or IsLocked() then
            return
        end

        local normalized = NormalizeNumber(value, fallbackValue)

        OptionValues.Set(config.path, normalized)
        UpdateUI(normalized)
        OptionRefresh.Live()

        if config.onChanged then
            config.onChanged(normalized)
        end
    end

    local currentValue = NormalizeNumber(OptionValues.Get(config.path, fallbackValue), fallbackValue)
    UpdateUI(currentValue)

    slider:SetCallback("OnValueChanged", function(_, _, value)
        if isUpdating then
            return
        end

        SaveValue(value)
    end)

    if resetButton then
        resetButton:SetCallback("OnClick", function()
            if IsDisabled() or IsLocked() then
                return
            end

            if OptionValues.Reset(config.path) then
                local resetValue = NormalizeNumber(OptionValues.Get(config.path, fallbackValue), fallbackValue)
                UpdateUI(resetValue)
                OptionRefresh.Live()

                if config.onChanged then
                    config.onChanged(resetValue)
                end
            else
                SaveValue(fallbackValue)
            end
        end)
    end

    local handle = {
        group = group,
        slider = slider,
        resetButton = resetButton,
        RefreshState = ApplyState,
    }

    OptionRefresh.RegisterStateWidget(handle)

    return handle
end

return Sliders
