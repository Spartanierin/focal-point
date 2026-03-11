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

function Checkbox.Create(config)
    if type(config) ~= "table" then
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

    local row = AceGUI:Create("SimpleGroup")
    row:SetFullWidth(true)
    row:SetLayout("Flow")
    group:AddChild(row)

    local checkbox = AceGUI:Create("CheckBox")
    checkbox:SetLabel(labelText)
    checkbox:SetWidth(220)
    row:AddChild(checkbox)

    local resetButton = nil
    -- Checkboxes do not show a reset button by default.
    -- This keeps the UI quieter and avoids redundant reset controls for boolean toggles.
    -- Set showReset = true explicitly if a future checkbox really needs one.
    if config.showReset == true then
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

        checkbox:SetDisabled(not interactive)

        if resetButton then
            resetButton:SetDisabled(not interactive)
        end
    end

    local function UpdateUI(value)
        isUpdating = true
        checkbox:SetValue(value)
        ApplyState()
        isUpdating = false
    end

    local function SaveValue(value)
        if IsDisabled() or IsLocked() then
            return
        end

        local normalized = NormalizeBoolean(value, fallbackValue)

        OptionValues.Set(config.path, normalized)
        UpdateUI(normalized)
        if config.refreshGUI then
            OptionRefresh.All()
        else
            OptionRefresh.Live()
        end

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
            if IsDisabled() or IsLocked() then
                return
            end

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

    local handle = {
        group = group,
        checkbox = checkbox,
        resetButton = resetButton,
        RefreshState = ApplyState,
    }

    OptionRefresh.RegisterStateWidget(handle)

    return handle
end

return Checkbox