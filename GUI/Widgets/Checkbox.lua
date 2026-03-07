local _, PORTRAIT = ...

PORTRAIT.GUI = PORTRAIT.GUI or {}
PORTRAIT.GUI.Widgets = PORTRAIT.GUI.Widgets or {}

local AceGUI = LibStub("AceGUI-3.0")

local OptionValues = PORTRAIT.GUI.Helpers.OptionValues
local OptionRefresh = PORTRAIT.GUI.Helpers.OptionRefresh

local Checkbox = {}
PORTRAIT.GUI.Widgets.Checkbox = Checkbox

local function NormalizeBoolean(value, fallback)
    if type(value) == "boolean" then
        return value
    end

    if fallback == nil then
        return false
    end

    return fallback and true or false
end

function Checkbox.Create(container, config)
    if not container or type(config) ~= "table" then
        return nil
    end

    if type(config.path) ~= "table" or #config.path == 0 then
        return nil
    end

    local labelText = config.label or "[Missing Label]"
    local descriptionText = config.description
    local fallbackValue = NormalizeBoolean(config.fallback, false)

    local group = AceGUI:Create("SimpleGroup")
    group:SetFullWidth(true)
    group:SetLayout("Flow")
    container:AddChild(group)

    local row = AceGUI:Create("SimpleGroup")
    row:SetFullWidth(true)
    row:SetLayout("Flow")
    group:AddChild(row)

    local checkbox = AceGUI:Create("CheckBox")
    checkbox:SetLabel(labelText)
    checkbox:SetWidth(220)
    row:AddChild(checkbox)

    local resetButton = nil
    if config.showReset ~= false then
        resetButton = AceGUI:Create("Button")
        resetButton:SetText(config.resetText or "Reset")
        resetButton:SetWidth(100)
        row:AddChild(resetButton)
    end

    if descriptionText and descriptionText ~= "" then
        local description = AceGUI:Create("Label")
        description:SetFullWidth(true)
        description:SetText(descriptionText)
        group:AddChild(description)
    end

    local isUpdating = false

    local function UpdateUI(value)
        isUpdating = true
        checkbox:SetValue(value)
        isUpdating = false
    end

    local function SaveValue(value)
        local normalized = NormalizeBoolean(value, fallbackValue)

        OptionValues.Set(config.path, normalized)
        UpdateUI(normalized)
        OptionRefresh.All()

        if config.onChanged then
            config.onChanged(normalized)
        end
    end

    local currentValue = NormalizeBoolean(OptionValues.Get(config.path, fallbackValue), fallbackValue)
    UpdateUI(currentValue)

    checkbox:SetCallback("OnValueChanged", function(_, _, value)
        if isUpdating then
            return
        end

        SaveValue(value)
    end)

    if resetButton then
        resetButton:SetCallback("OnClick", function()
            if OptionValues.Reset(config.path) then
                local resetValue = NormalizeBoolean(OptionValues.Get(config.path, fallbackValue), fallbackValue)
                UpdateUI(resetValue)
                OptionRefresh.All()

                if config.onChanged then
                    config.onChanged(resetValue)
                end
            else
                SaveValue(fallbackValue)
            end
        end)
    end

    return {
        group = group,
        checkbox = checkbox,
        resetButton = resetButton,
    }
end

return Checkbox