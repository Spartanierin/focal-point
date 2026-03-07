local _, PORTRAIT = ...

PORTRAIT.GUI = PORTRAIT.GUI or {}
PORTRAIT.GUI.Widgets = PORTRAIT.GUI.Widgets or {}

local AceGUI = LibStub("AceGUI-3.0")

local OptionValues = PORTRAIT.GUI.Helpers.OptionValues
local OptionRefresh = PORTRAIT.GUI.Helpers.OptionRefresh

local Dropdown = {}
PORTRAIT.GUI.Widgets.Dropdown = Dropdown

local function NormalizeList(list)
    if type(list) ~= "table" then
        return {}
    end

    return list
end

local function GetFallbackValue(list, fallback)
    if fallback ~= nil and list[fallback] ~= nil then
        return fallback
    end

    for key in pairs(list) do
        return key
    end

    return nil
end

function Dropdown.Create(container, config)
    if not container or type(config) ~= "table" then
        return nil
    end

    if type(config.path) ~= "table" or #config.path == 0 then
        return nil
    end

    local labelText = config.label or "[Missing Label]"
    local descriptionText = config.description
    local list = NormalizeList(config.list)
    local fallbackValue = GetFallbackValue(list, config.fallback)

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

    local dropdown = AceGUI:Create("Dropdown")
    dropdown:SetLabel("")
    dropdown:SetList(list)
    dropdown:SetWidth(220)
    row:AddChild(dropdown)

    local resetButton = nil
    if config.showReset ~= false then
        resetButton = AceGUI:Create("Button")
        resetButton:SetText(config.resetText or "Reset")
        resetButton:SetWidth(100)
        row:AddChild(resetButton)
    end

    local isUpdating = false

    local function NormalizeValue(value)
        if value ~= nil and list[value] ~= nil then
            return value
        end

        return fallbackValue
    end

    local function UpdateUI(value)
        isUpdating = true
        dropdown:SetValue(value)
        isUpdating = false
    end

    local function SaveValue(value)
        local normalized = NormalizeValue(value)

        if normalized == nil then
            return
        end

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

    dropdown:SetCallback("OnValueChanged", function(_, _, value)
        if isUpdating then
            return
        end

        SaveValue(value)
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
            else
                local normalized = NormalizeValue(fallbackValue)
                if normalized ~= nil then
                    SaveValue(normalized)
                end
            end
        end)
    end

    return {
        group = group,
        dropdown = dropdown,
        resetButton = resetButton,
    }
end

return Dropdown