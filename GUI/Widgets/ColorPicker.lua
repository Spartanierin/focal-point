local _, PORTRAIT = ...

PORTRAIT.GUI = PORTRAIT.GUI or {}
PORTRAIT.GUI.Widgets = PORTRAIT.GUI.Widgets or {}

local AceGUI = LibStub("AceGUI-3.0")

local OptionValues = PORTRAIT.GUI.Helpers.OptionValues
local OptionRefresh = PORTRAIT.GUI.Helpers.OptionRefresh

local ColorPicker = {}
PORTRAIT.GUI.Widgets.ColorPicker = ColorPicker

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

local function NormalizeColor(color, fallback)
    fallback = fallback or { 1, 1, 1, 1 }

    if type(color) ~= "table" then
        return {
            fallback[1] or 1,
            fallback[2] or 1,
            fallback[3] or 1,
            fallback[4] or 1,
        }
    end

    return {
        Clamp(color[1] or fallback[1] or 1, 0, 1),
        Clamp(color[2] or fallback[2] or 1, 0, 1),
        Clamp(color[3] or fallback[3] or 1, 0, 1),
        Clamp(color[4] or fallback[4] or 1, 0, 1),
    }
end

local function FloatToByte(value)
    return math.floor(Clamp(value or 0, 0, 1) * 255 + 0.5)
end

local function ByteToFloat(value)
    return Clamp((value or 0) / 255, 0, 1)
end

local function ColorToHex(color)
    local r = FloatToByte(color[1])
    local g = FloatToByte(color[2])
    local b = FloatToByte(color[3])

    return string.format("%02X%02X%02X", r, g, b)
end

local function HexToColor(hex, alpha)
    if type(hex) ~= "string" then
        return nil
    end

    local cleaned = hex:gsub("#", ""):gsub("%s+", ""):upper()

    if cleaned:match("^[0-9A-F]+$") == nil then
        return nil
    end

    if #cleaned == 3 then
        cleaned = cleaned:sub(1, 1) .. cleaned:sub(1, 1)
            .. cleaned:sub(2, 2) .. cleaned:sub(2, 2)
            .. cleaned:sub(3, 3) .. cleaned:sub(3, 3)
    end

    if #cleaned ~= 6 then
        return nil
    end

    local r = tonumber(cleaned:sub(1, 2), 16)
    local g = tonumber(cleaned:sub(3, 4), 16)
    local b = tonumber(cleaned:sub(5, 6), 16)

    if not r or not g or not b then
        return nil
    end

    return {
        ByteToFloat(r),
        ByteToFloat(g),
        ByteToFloat(b),
        Clamp(alpha or 1, 0, 1),
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
    local hasAlpha = config.hasAlpha and true or false
    local fallbackColor = NormalizeColor(config.fallback, { 1, 1, 1, 1 })

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

    local button = AceGUI:Create("ColorPicker")
    button:SetLabel("")
    button:SetHasAlpha(hasAlpha)
    button:SetWidth(80)
    row:AddChild(button)

    local hexInput = AceGUI:Create("EditBox")
    hexInput:SetLabel("")
    hexInput:SetWidth(120)
    row:AddChild(hexInput)

    local resetButton = nil
    if config.showReset ~= false then
        resetButton = AceGUI:Create("Button")
        resetButton:SetText(config.resetText or "Reset")
        resetButton:SetWidth(100)
        row:AddChild(resetButton)
    end

    local isUpdating = false

    local function UpdateUI(color)
        isUpdating = true
        button:SetColor(color[1], color[2], color[3], color[4])
        hexInput:SetText(ColorToHex(color))
        isUpdating = false
    end

    local function SaveColor(color)
        local normalized = NormalizeColor(color, fallbackColor)

        if not hasAlpha then
            normalized[4] = 1
        end

        OptionValues.Set(config.path, normalized)
        UpdateUI(normalized)
        OptionRefresh.All()

        if config.onChanged then
            config.onChanged(normalized)
        end
    end

    local currentColor = NormalizeColor(OptionValues.Get(config.path), fallbackColor)
    UpdateUI(currentColor)

    button:SetCallback("OnValueChanged", function(_, _, r, g, b, a)
        if isUpdating then
            return
        end

        SaveColor({
            r or 1,
            g or 1,
            b or 1,
            a or 1,
        })
    end)

    button:SetCallback("OnValueConfirmed", function(_, _, r, g, b, a)
        if isUpdating then
            return
        end

        SaveColor({
            r or 1,
            g or 1,
            b or 1,
            a or 1,
        })
    end)

    hexInput:SetCallback("OnEnterPressed", function(_, _, value)
        if isUpdating then
            return
        end

        local current = NormalizeColor(OptionValues.Get(config.path), fallbackColor)
        local parsed = HexToColor(value, current[4])

        if parsed then
            SaveColor(parsed)
        else
            UpdateUI(current)
        end
    end)

    hexInput:SetCallback("OnTextChanged", function()
        -- bewusst leer; Commit nur bei Enter/OK
    end)

    if resetButton then
        resetButton:SetCallback("OnClick", function()
            if OptionValues.Reset(config.path) then
                local resetColor = NormalizeColor(OptionValues.Get(config.path), fallbackColor)
                UpdateUI(resetColor)
                OptionRefresh.All()

                if config.onChanged then
                    config.onChanged(resetColor)
                end
            end
        end)
    end

    return {
        group = group,
        button = button,
        hexInput = hexInput,
        resetButton = resetButton,
    }
end

return ColorPicker