local _, PORTRAIT = ...

PORTRAIT.GUI = PORTRAIT.GUI or {}
PORTRAIT.GUI.Widgets = PORTRAIT.GUI.Widgets or {}

local AceGUI = LibStub("AceGUI-3.0")

local OptionValues = PORTRAIT.GUI.Helpers.OptionValues
local OptionRefresh = PORTRAIT.GUI.Helpers.OptionRefresh

local ColorPicker = {}
PORTRAIT.GUI.Widgets.ColorPicker = ColorPicker

local function CopyColor(color, fallback)
    local source = type(color) == "table" and color or fallback or {}

    return {
        r = tonumber(source.r) or 1,
        g = tonumber(source.g) or 1,
        b = tonumber(source.b) or 1,
        a = tonumber(source.a) or 1,
    }
end

function ColorPicker.Create(container, config)
    if not container or type(config) ~= "table" then
        return nil
    end

    if type(config.path) ~= "table" or #config.path == 0 then
        return nil
    end

    local labelText = config.label or "[Missing Label]"
    local descriptionText = config.description
    local fallbackValue = CopyColor(config.fallback, { r = 1, g = 1, b = 1, a = 1 })

    local group = AceGUI:Create("SimpleGroup")
    group:SetFullWidth(true)
    group:SetLayout("Flow")
    container:AddChild(group)

    local row = AceGUI:Create("SimpleGroup")
    row:SetFullWidth(true)
    row:SetLayout("Flow")
    group:AddChild(row)

    local colorPicker = AceGUI:Create("ColorPicker")
    colorPicker:SetLabel(labelText)
    colorPicker:SetWidth(config.width or 220)
    row:AddChild(colorPicker)

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

        colorPicker:SetDisabled(not interactive)

        if resetButton then
            resetButton:SetDisabled(not interactive)
        end
    end

    local function UpdateUI(color)
        local value = CopyColor(color, fallbackValue)

        isUpdating = true
        colorPicker:SetColor(value.r, value.g, value.b, value.a)
        ApplyState()
        isUpdating = false
    end

    local function SaveValue(color)
        if IsDisabled() or IsLocked() then
            return
        end

        local normalized = CopyColor(color, fallbackValue)

        OptionValues.Set(config.path, normalized)
        UpdateUI(normalized)
        OptionRefresh.All()

        if config.onChanged then
            config.onChanged(normalized)
        end
    end

    local currentValue = CopyColor(OptionValues.Get(config.path, fallbackValue), fallbackValue)
    UpdateUI(currentValue)

    colorPicker:SetCallback("OnValueConfirmed", function(_, _, r, g, b, a)
        if isUpdating then
            return
        end

        SaveValue({
            r = r,
            g = g,
            b = b,
            a = a,
        })
    end)

    if resetButton then
        resetButton:SetCallback("OnClick", function()
            if IsDisabled() or IsLocked() then
                return
            end

            if OptionValues.Reset(config.path) then
                local resetValue = CopyColor(OptionValues.Get(config.path, fallbackValue), fallbackValue)
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
        colorPicker = colorPicker,
        resetButton = resetButton,
        RefreshState = ApplyState,
    }

    OptionRefresh.RegisterStateWidget(handle)

    return handle
end

return ColorPicker