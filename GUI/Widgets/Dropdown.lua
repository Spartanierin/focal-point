local _, PORTRAIT = ...

PORTRAIT.GUI = PORTRAIT.GUI or {}
PORTRAIT.GUI.Widgets = PORTRAIT.GUI.Widgets or {}

local AceGUI = LibStub("AceGUI-3.0")

local OptionValues = PORTRAIT.GUI.Helpers.OptionValues
local OptionRefresh = PORTRAIT.GUI.Helpers.OptionRefresh

local Dropdown = {}
PORTRAIT.GUI.Widgets.Dropdown = Dropdown

function Dropdown.Create(config)
    if type(config) ~= "table" then
        return nil
    end

    if type(config.path) ~= "table" or #config.path == 0 then
        return nil
    end

    local labelText = config.label or "[Missing Label]"
    local descriptionText = config.description
    local fallbackValue = config.fallback
    local listValues = config.list or config.values or {}

    local group = AceGUI:Create("SimpleGroup")
    group:SetFullWidth(true)
    group:SetLayout("Flow")

    local row = AceGUI:Create("SimpleGroup")
    row:SetFullWidth(true)
    row:SetLayout("Flow")
    group:AddChild(row)

    local dropdown = AceGUI:Create("Dropdown")
    dropdown:SetLabel(labelText)
    dropdown:SetList(listValues)
    dropdown:SetWidth(config.width or 220)
    row:AddChild(dropdown)

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

        dropdown:SetDisabled(not interactive)

        if resetButton then
            resetButton:SetDisabled(not interactive)
        end
    end

    local function UpdateUI(value)
        isUpdating = true
        dropdown:SetValue(value)
        ApplyState()
        isUpdating = false
    end

    local function SaveValue(value)
        if IsDisabled() or IsLocked() then
            return
        end

        OptionValues.Set(config.path, value)
        UpdateUI(value)
        OptionRefresh.All()

        if config.onChanged then
            config.onChanged(value)
        end
    end

    local currentValue = OptionValues.Get(config.path, fallbackValue)
    UpdateUI(currentValue)

    dropdown:SetCallback("OnValueChanged", function(_, _, value)
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
                local resetValue = OptionValues.Get(config.path, fallbackValue)
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

    local handle = {
        group = group,
        dropdown = dropdown,
        resetButton = resetButton,
        RefreshState = ApplyState,
    }

    OptionRefresh.RegisterStateWidget(handle)

    return handle
end

return Dropdown