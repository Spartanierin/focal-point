local _, FocalPoint = ...

FocalPoint.GUI = FocalPoint.GUI or {}
FocalPoint.GUI.Widgets = FocalPoint.GUI.Widgets or {}

local AceGUI = LibStub("AceGUI-3.0")

local OptionValues = FocalPoint.GUI.Helpers.OptionValues
local OptionRefresh = FocalPoint.GUI.Helpers.OptionRefresh
local TextStyles = FocalPoint.GUI.Helpers.TextStyles

local ColorPicker = {}
FocalPoint.GUI.Widgets.ColorPicker = ColorPicker

local function CopyColor(color, fallback)
    local source = type(color) == "table" and color or fallback or {}

    local r = tonumber(source.r) or tonumber(source[1]) or 1
    local g = tonumber(source.g) or tonumber(source[2]) or 1
    local b = tonumber(source.b) or tonumber(source[3]) or 1
    local a = tonumber(source.a) or tonumber(source[4]) or 1

    return {
        r = r,
        g = g,
        b = b,
        a = a,
        [1] = r,
        [2] = g,
        [3] = b,
        [4] = a,
    }
end

function ColorPicker.Create(config)
    if type(config) ~= "table" then
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

    local row = AceGUI:Create("SimpleGroup")
    row:SetFullWidth(true)
    row:SetLayout("Flow")
    group:AddChild(row)

    local colorPicker = AceGUI:Create("ColorPicker")
    colorPicker:SetLabel(labelText)
    colorPicker:SetHasAlpha(config.hasAlpha and true or false)
    colorPicker:SetWidth(config.width or 180)
    row:AddChild(colorPicker)

    local resetButton = nil
    if config.showReset ~= false then
        resetButton = AceGUI:Create("Button")
        resetButton:SetText(config.resetText or "Reset")
        resetButton:SetWidth(config.resetWidth or 80)
        row:AddChild(resetButton)
    end

    if descriptionText and descriptionText ~= "" then
        local description = AceGUI:Create("Label")
        description:SetFullWidth(true)
        description:SetText(descriptionText)
        if TextStyles and TextStyles.ApplyLabelWidget then
            TextStyles.ApplyLabelWidget(description, "help", { size = 11 })
        end
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
        if TextStyles and TextStyles.ApplyInteractiveWidgetText then
            TextStyles.ApplyInteractiveWidgetText(colorPicker, "label", not interactive, { size = 12 })
        end

        local description = group.children and group.children[2]
        if description and TextStyles and TextStyles.ApplyLabelWidget then
            TextStyles.ApplyLabelWidget(description, not interactive and "disabled" or "help", { size = 11 })
        end

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

    local function HandleColorChanged(_, _, r, g, b, a)
        if isUpdating then
            return
        end

        SaveValue({
            r = r,
            g = g,
            b = b,
            a = a,
        })
    end

    colorPicker:SetCallback("OnValueChanged", HandleColorChanged)
    colorPicker:SetCallback("OnValueConfirmed", HandleColorChanged)

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
