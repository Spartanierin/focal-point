local _, PORTRAIT = ...

PORTRAIT.GUI = PORTRAIT.GUI or {}
PORTRAIT.GUI.Widgets = PORTRAIT.GUI.Widgets or {}

local AceGUI = LibStub("AceGUI-3.0")

local OptionValues = PORTRAIT.GUI.Helpers.OptionValues
local OptionRefresh = PORTRAIT.GUI.Helpers.OptionRefresh

local Slider = {}
PORTRAIT.GUI.Widgets.Slider = Slider

local function Clamp(value, minValue, maxValue)
    if type(value) ~= "number" then
        return minValue
    end

    if value < minValue then
        return minValue
    end

    if value > maxValue then
        return maxValue
    end

    return value
end

local function RoundToStep(value, minValue, step)
    if type(value) ~= "number" then
        return minValue
    end

    if not step or step <= 0 then
        return value
    end

    local steps = math.floor(((value - minValue) / step) + 0.5)
    return minValue + (steps * step)
end

local function FormatValue(value, formatString)
    if type(value) ~= "number" then
        return ""
    end

    if type(formatString) == "string" and formatString ~= "" then
        return string.format(formatString, value)
    end

    if math.abs(value - math.floor(value)) < 0.0001 then
        return tostring(math.floor(value))
    end

    return string.format("%.2f", value)
end

local function ParseNumber(text)
    if type(text) ~= "string" then
        return nil
    end

    local cleaned = text:gsub(",", "."):gsub("%s+", "")
    local value = tonumber(cleaned)

    return value
end

function Slider.Create(container, config)
    if not container or type(config) ~= "table" then
        return nil
    end

    if type(config.path) ~= "table" or #config.path == 0 then
        return nil
    end

    local labelText = config.label or "[Missing Label]"
    local descriptionText = config.description
    local minValue = tonumber(config.min) or 0
    local maxValue = tonumber(config.max) or 100
    local stepValue = tonumber(config.step) or 1
    local formatString = config.format

    if maxValue < minValue then
        minValue, maxValue = maxValue, minValue
    end

    if stepValue <= 0 then
        stepValue = 1
    end

    local fallbackValue = tonumber(config.fallback)
    if fallbackValue == nil then
        fallbackValue = minValue
    end

    local group = AceGUI:Create("SimpleGroup")
    group:SetFullWidth(true)
    group:SetLayout("Flow")
    container:AddChild(group)

    local label = AceGUI:Create("Label")
    label:SetFullWidth(true)
    label:SetText(labelText)
    group:AddChild(label)

    if descriptionText and descriptionText ~= "" then
        local description = AceGUI:Create("Label")
        description:SetFullWidth(true)
        description:SetText(descriptionText)
        group:AddChild(description)
    end

    local row = AceGUI:Create("SimpleGroup")
    row:SetFullWidth(true)
    row:SetLayout("Flow")
    group:AddChild(row)

    local slider = AceGUI:Create("Slider")
    slider:SetLabel("")
    slider:SetSliderValues(minValue, maxValue, stepValue)
    slider:SetWidth(220)
    row:AddChild(slider)

    local valueInput = AceGUI:Create("EditBox")
    valueInput:SetLabel("")
    valueInput:SetWidth(90)
    row:AddChild(valueInput)

    local resetButton = nil
    if config.showReset ~= false then
        resetButton = AceGUI:Create("Button")
        resetButton:SetText(config.resetText or "Reset")
        resetButton:SetWidth(100)
        row:AddChild(resetButton)
    end

    local isUpdating = false

    local function NormalizeValue(value)
        local numeric = tonumber(value)

        if numeric == nil then
            numeric = fallbackValue
        end

        numeric = Clamp(numeric, minValue, maxValue)
        numeric = RoundToStep(numeric, minValue, stepValue)
        numeric = Clamp(numeric, minValue, maxValue)

        return numeric
    end

    local function UpdateUI(value)
        isUpdating = true
        slider:SetValue(value)
        valueInput:SetText(FormatValue(value, formatString))
        isUpdating = false
    end

    local function SaveValue(value)
        local normalized = NormalizeValue(value)

        OptionValues.Set(config.path, normalized)
        UpdateUI(normalized)
        OptionRefresh.All()

        if config.onChanged then
            config.onChanged(normalized)
        end
    end

    local currentValue = OptionValues.Get(config.path, fallbackValue)
    currentValue = NormalizeValue(currentValue)
    UpdateUI(currentValue)

    slider:SetCallback("OnValueChanged", function(_, _, value)
        if isUpdating then
            return
        end

        SaveValue(value)
    end)

    slider:SetCallback("OnMouseUp", function()
        if isUpdating then
            return
        end

        local liveValue = OptionValues.Get(config.path, fallbackValue)
        UpdateUI(NormalizeValue(liveValue))
    end)

    valueInput:SetCallback("OnEnterPressed", function(_, _, text)
        if isUpdating then
            return
        end

        local parsed = ParseNumber(text)

        if parsed ~= nil then
            SaveValue(parsed)
        else
            local current = OptionValues.Get(config.path, fallbackValue)
            UpdateUI(NormalizeValue(current))
        end
    end)

    valueInput:SetCallback("OnTextChanged", function()
        -- bewusst leer; Commit nur bei Enter/OK
    end)

    if resetButton then
        resetButton:SetCallback("OnClick", function()
            if OptionValues.Reset(config.path) then
                local resetValue = OptionValues.Get(config.path, fallbackValue)
                resetValue = NormalizeValue(resetValue)
                UpdateUI(resetValue)
                OptionRefresh.All()

                if config.onChanged then
                    config.onChanged(resetValue)
                end
            end
        end)
    end

    return {
        group = group,
        slider = slider,
        valueInput = valueInput,
        resetButton = resetButton,
    }
end

return Slider