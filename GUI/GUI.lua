local _, Portrait = ...

local AceGUI = LibStub("AceGUI-3.0")
local L = Portrait.L

Portrait.GUI = Portrait.GUI or {}
Portrait.GUI.selectedPath = Portrait.GUI.selectedPath or "general"

local NAV_TREE = Portrait.GUIBuilders.CreateNavTree()

local POINTS = {
    CENTER = "CENTER",
    TOP = "TOP",
    BOTTOM = "BOTTOM",
    LEFT = "LEFT",
    RIGHT = "RIGHT",
    TOPLEFT = "TOPLEFT",
    TOPRIGHT = "TOPRIGHT",
    BOTTOMLEFT = "BOTTOMLEFT",
    BOTTOMRIGHT = "BOTTOMRIGHT",
}

local ANCHOR_TARGETS = {
    Frame = "Frame",
    HealthBar = "HealthBar",
    PowerBar = "PowerBar",
}

local JUSTIFY_H = {
    LEFT = "LEFT",
    CENTER = "CENTER",
    RIGHT = "RIGHT",
}

local function EnsureColorTable(color, fallback)
    if type(color) ~= "table" then
        if type(fallback) == "table" then
            return { fallback[1] or 1, fallback[2] or 1, fallback[3] or 1, fallback[4] or 1 }
        end
        return { 1, 1, 1, 1 }
    end

    if color[4] == nil then
        color[4] = 1
    end

    return color
end

local function ColorToHex(color)
    color = EnsureColorTable(color, { 1, 1, 1, 1 })

    local r = math.floor((color[1] or 1) * 255 + 0.5)
    local g = math.floor((color[2] or 1) * 255 + 0.5)
    local b = math.floor((color[3] or 1) * 255 + 0.5)

    return string.format("#%02X%02X%02X", r, g, b)
end

local function AlphaToPercent(color)
    color = EnsureColorTable(color, { 1, 1, 1, 1 })
    return math.floor((color[4] or 1) * 100 + 0.5)
end

local function GetProfile()
    return Portrait.db and Portrait.db.profile
end

local function GetUnitConfig(unit)
    local profile = GetProfile()
    return profile and profile.Units and profile.Units[unit]
end

local function GetTextConfig(unit, textKey)
    local unitConfig = GetUnitConfig(unit)
    return unitConfig and unitConfig.Texts and unitConfig.Texts[textKey]
end

local function SafeRefreshUnit(unit)
    if Portrait.RefreshUnitFrame then
        Portrait:RefreshUnitFrame(unit)
    end
end

local function AddSpacer(container, height)
    local spacer = AceGUI:Create("Label")
    spacer:SetText(" ")
    spacer:SetFullWidth(true)
    spacer:SetHeight(height or 8)
    container:AddChild(spacer)
end

local function AddHeading(container, text)
    local heading = AceGUI:Create("Heading")
    heading:SetText(text)
    heading:SetFullWidth(true)
    container:AddChild(heading)
end

local function AddLabel(container, text)
    local label = AceGUI:Create("Label")
    label:SetText(text or "")
    label:SetFullWidth(true)
    container:AddChild(label)
    return label
end

local function AddCheckBox(container, label, value, onChanged)
    local widget = AceGUI:Create("CheckBox")
    widget:SetLabel(label)
    widget:SetValue(value and true or false)
    widget:SetFullWidth(true)
    widget:SetCallback("OnValueChanged", function(_, _, newValue)
        onChanged(newValue and true or false)
    end)
    container:AddChild(widget)
    return widget
end

local function AddSlider(container, label, minValue, maxValue, step, value, onChanged)
    local widget = AceGUI:Create("Slider")
    widget:SetLabel(label)
    widget:SetSliderValues(minValue, maxValue, step)
    widget:SetValue(value or minValue)
    widget:SetFullWidth(true)
    widget:SetCallback("OnValueChanged", function(_, _, newValue)
        if step == 1 then
            newValue = math.floor(newValue + 0.5)
        end
        onChanged(newValue)
    end)
    container:AddChild(widget)
    return widget
end

local function AddDropdown(container, label, list, value, onChanged)
    local widget = AceGUI:Create("Dropdown")
    widget:SetLabel(label)
    widget:SetList(list)
    widget:SetValue(value)
    widget:SetFullWidth(true)
    widget:SetCallback("OnValueChanged", function(_, _, newValue)
        onChanged(newValue)
    end)
    container:AddChild(widget)
    return widget
end

local function AddEditBox(container, label, value, onChanged)
    local widget = AceGUI:Create("EditBox")
    widget:SetLabel(label)
    widget:SetText(value or "")
    widget:SetFullWidth(true)
    widget:SetCallback("OnEnterPressed", function(editBox, _, newValue)
        onChanged(newValue)
        editBox:ClearFocus()
    end)
    container:AddChild(widget)
    return widget
end

local function AddScrollTabContent(container, buildFunc)
    container:ReleaseChildren()
    container:SetLayout("Fill")

    local scroll = AceGUI:Create("ScrollFrame")
    scroll:SetLayout("Fill")
    scroll:SetFullWidth(true)
    scroll:SetFullHeight(true)
    container:AddChild(scroll)

    local content = AceGUI:Create("SimpleGroup")
    content:SetFullWidth(true)
    content:SetLayout("Flow")
    scroll:AddChild(content)

    buildFunc(content)
end

local function CloneColor(color)
    color = color or { 1, 1, 1, 1 }
    return {
        color[1] or 1,
        color[2] or 1,
        color[3] or 1,
        color[4] or 1,
    }
end

local function OpenColorPicker(initialColor, hasAlpha, onChanged)
    local color = CloneColor(initialColor)

    local function FireCallback()
        if onChanged then
            onChanged(color)
        end
    end

    if ColorPickerFrame and ColorPickerFrame.SetupColorPickerAndShow then
        ColorPickerFrame:SetFrameStrata("TOOLTIP")
        ColorPickerFrame:SetToplevel(true)
        ColorPickerFrame:Raise()        
        
        local info = {
            r = color[1],
            g = color[2],
            b = color[3],
            opacity = hasAlpha and (1 - (color[4] or 1)) or 0,
            hasOpacity = hasAlpha and true or false,
            swatchFunc = function()
                local r, g, b = ColorPickerFrame:GetColorRGB()
                color[1], color[2], color[3] = r, g, b

                if hasAlpha then
                    local opacity = ColorPickerFrame:GetColorAlpha()
                    color[4] = opacity and (1 - opacity) or color[4]
                end

                FireCallback()
            end,
            opacityFunc = function()
                if hasAlpha then
                    local opacity = ColorPickerFrame:GetColorAlpha()
                    color[4] = opacity and (1 - opacity) or color[4]
                    FireCallback()
                end
            end,
            cancelFunc = function(previousValues)
                if not previousValues then
                    return
                end

                color[1] = previousValues.r or color[1]
                color[2] = previousValues.g or color[2]
                color[3] = previousValues.b or color[3]

                if hasAlpha then
                    local oldOpacity = previousValues.opacity
                    if oldOpacity ~= nil then
                        color[4] = 1 - oldOpacity
                    end
                end

                FireCallback()
            end,
        }

        ColorPickerFrame:SetupColorPickerAndShow(info)
        return
    end

    if not ColorPickerFrame then
        return
    end

    ColorPickerFrame:SetFrameStrata("TOOLTIP")
    ColorPickerFrame:SetToplevel(true)
    ColorPickerFrame:Raise()

    local previous = CloneColor(color)

    ColorPickerFrame.hasOpacity = hasAlpha and true or false
    ColorPickerFrame.opacity = hasAlpha and (1 - (color[4] or 1)) or 0

    ColorPickerFrame:SetColorRGB(color[1], color[2], color[3])

    ColorPickerFrame.func = function()
        local r, g, b = ColorPickerFrame:GetColorRGB()
        color[1], color[2], color[3] = r, g, b

        if hasAlpha and OpacitySliderFrame then
            color[4] = 1 - OpacitySliderFrame:GetValue()
        end

        FireCallback()
    end

    ColorPickerFrame.opacityFunc = function()
        if hasAlpha and OpacitySliderFrame then
            color[4] = 1 - OpacitySliderFrame:GetValue()
            FireCallback()
        end
    end

    ColorPickerFrame.cancelFunc = function()
        color[1], color[2], color[3], color[4] = unpack(previous)
        FireCallback()
    end

    ColorPickerFrame:Hide()
    ColorPickerFrame:Show()
end

local function AddColorPickerRow(container, labelText, colorTable, onChanged, defaultColor)
    colorTable = EnsureColorTable(colorTable, defaultColor or { 1, 1, 1, 1 })
    local defaults = EnsureColorTable(defaultColor or { 1, 1, 1, 1 }, { 1, 1, 1, 1 })

    local row = AceGUI:Create("SimpleGroup")
    row:SetFullWidth(true)
    row:SetHeight(28)
    row:SetLayout("Fill")
    container:AddChild(row)

    local frame = row.frame
    frame:SetHeight(28)

    local label = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    label:SetPoint("LEFT", frame, "LEFT", 0, 0)
    label:SetWidth(140)
    label:SetJustifyH("LEFT")
    label:SetText(labelText)

    local swatchButton = CreateFrame("Button", nil, frame)
    swatchButton:SetSize(20, 20)
    swatchButton:SetPoint("LEFT", frame, "LEFT", 150, 0)

    local swatchBorder = swatchButton:CreateTexture(nil, "BACKGROUND")
    swatchBorder:SetAllPoints()
    swatchBorder:SetColorTexture(0, 0, 0, 1)

    local swatchFill = swatchButton:CreateTexture(nil, "ARTWORK")
    swatchFill:SetPoint("TOPLEFT", swatchButton, "TOPLEFT", 1, -1)
    swatchFill:SetPoint("BOTTOMRIGHT", swatchButton, "BOTTOMRIGHT", -1, 1)

    local hexText = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    hexText:SetPoint("LEFT", swatchButton, "RIGHT", 12, 0)
    hexText:SetWidth(80)
    hexText:SetJustifyH("LEFT")

    local alphaText = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    alphaText:SetPoint("LEFT", hexText, "RIGHT", 10, 0)
    alphaText:SetWidth(45)
    alphaText:SetJustifyH("LEFT")

    local resetButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    resetButton:SetSize(80, 22)
    resetButton:SetPoint("LEFT", alphaText, "RIGHT", 12, 0)
    resetButton:SetText("Reset")

    local function RefreshRow()
        swatchFill:SetColorTexture(
            colorTable[1] or 1,
            colorTable[2] or 1,
            colorTable[3] or 1,
            colorTable[4] or 1
        )

        hexText:SetText(ColorToHex(colorTable))
        alphaText:SetText(string.format("%d%%", AlphaToPercent(colorTable)))
    end

    local function ApplyChangedColor(newColor)
        colorTable[1] = newColor[1]
        colorTable[2] = newColor[2]
        colorTable[3] = newColor[3]
        colorTable[4] = newColor[4]

        RefreshRow()

        if onChanged then
            onChanged(colorTable)
        end
    end

    swatchButton:SetScript("OnClick", function()
        OpenColorPicker(colorTable, true, ApplyChangedColor)
    end)

    resetButton:SetScript("OnClick", function()
        colorTable[1] = defaults[1]
        colorTable[2] = defaults[2]
        colorTable[3] = defaults[3]
        colorTable[4] = defaults[4]

        RefreshRow()

        if onChanged then
            onChanged(colorTable)
        end
    end)

    RefreshRow()
end

local function ArrangeFrameFooter(frame, testButton)
    if not frame or not frame.statustext then
        return
    end

    local statusText = frame.statustext
    local statusBg = statusText:GetParent()
    local closeButton = frame.closebutton
    local footerParent = statusBg and statusBg:GetParent()

    if not statusBg or not footerParent then
        return
    end

    if testButton then
        testButton:SetParent(footerParent)
        testButton:ClearAllPoints()
        testButton:SetSize(110, 20)
        testButton:SetPoint("BOTTOMLEFT", footerParent, "BOTTOMLEFT", 15, 17)
    end

    if closeButton then
        closeButton:ClearAllPoints()
        closeButton:SetPoint("BOTTOMRIGHT", footerParent, "BOTTOMRIGHT", -27, 17)
    end

    statusBg:ClearAllPoints()

    if testButton and closeButton then
        statusBg:SetPoint("BOTTOMLEFT", testButton, "BOTTOMRIGHT", 10, -2)
        statusBg:SetPoint("BOTTOMRIGHT", closeButton, "BOTTOMLEFT", -10, -2)
    elseif testButton then
        statusBg:SetPoint("BOTTOMLEFT", testButton, "BOTTOMRIGHT", 10, -2)
        statusBg:SetPoint("BOTTOMRIGHT", footerParent, "BOTTOMRIGHT", -132, 15)
    elseif closeButton then
        statusBg:SetPoint("BOTTOMLEFT", footerParent, "BOTTOMLEFT", 15, 15)
        statusBg:SetPoint("BOTTOMRIGHT", closeButton, "BOTTOMLEFT", -10, -2)
    else
        statusBg:SetPoint("BOTTOMLEFT", footerParent, "BOTTOMLEFT", 15, 15)
        statusBg:SetPoint("BOTTOMRIGHT", footerParent, "BOTTOMRIGHT", -132, 15)
    end

    statusBg:SetHeight(24)

    statusText:ClearAllPoints()
    statusText:SetPoint("TOPLEFT", statusBg, "TOPLEFT", 10, -2)
    statusText:SetPoint("BOTTOMRIGHT", statusBg, "BOTTOMRIGHT", -10, 2)
    statusText:SetJustifyH("LEFT")
    statusText:SetJustifyV("MIDDLE")
end

local function SnapToWholePixel(value)
    if type(value) ~= "number" then
        return value
    end

    return math.floor(value + 0.5)
end

local function ApplyPortraitTreePixelSnap(treeGroup)
    if not treeGroup or treeGroup._portraitTreeDebugDone then
        return
    end

    local originalRefreshTree = treeGroup.RefreshTree
    if type(originalRefreshTree) ~= "function" then
        return
    end

    treeGroup.RefreshTree = function(self, ...)
        originalRefreshTree(self, ...)

        for _, button in ipairs(self.buttons or {}) do
            if button and button:IsShown() then
                local left = button.GetLeft and button:GetLeft() or nil
                local top = button.GetTop and button:GetTop() or nil

                if left and top then
                    button:ClearAllPoints()
                    button:SetPoint("TOPLEFT", self.treeframe, "BOTTOMLEFT", SnapToWholePixel(left - (self.treeframe:GetLeft() or 0)), SnapToWholePixel(top - (self.treeframe:GetBottom() or 0)))
                end

                if button.text and button.text.GetPoint and button.level == 1 then
                    local point, relativeTo, relativePoint, xOfs, yOfs = button.text:GetPoint(1)
                    if point then
                        button.text:ClearAllPoints()
                        button.text:SetPoint(point, relativeTo, relativePoint, SnapToWholePixel(xOfs), SnapToWholePixel(yOfs))
                    end
                end
            end
        end
    end

    treeGroup._portraitTreeDebugDone = true
end


local function RenderPlaceholderPage(container, title, text)
    container:ReleaseChildren()
    container:SetLayout("Flow")

    AddHeading(container, title)
    AddSpacer(container, 10)
    AddLabel(container, text or "This page is not implemented yet.")
end

local function BuildGeneralPage(container)
    Portrait.GUIBuilders.BuildGeneralPage(container)
end

local function BuildPlayerHealthBarTabGeneral(container)
    local unitConfig = GetUnitConfig("player")
    if not unitConfig then
        AddLabel(container, "Missing config: Units.player")
        return
    end

    AddCheckBox(container, "Enable Player Frame", unitConfig.enabled, function(newValue)
        unitConfig.enabled = newValue
        SafeRefreshUnit("player")
    end)

    AddCheckBox(container, "Show Power Bar", unitConfig.showPowerBar, function(newValue)
        unitConfig.showPowerBar = newValue
        SafeRefreshUnit("player")
    end)

    AddSlider(container, "Frame Width", 100, 500, 1, unitConfig.width or 220, function(newValue)
        unitConfig.width = newValue
        SafeRefreshUnit("player")
    end)

    AddSlider(container, "Frame Height", 20, 120, 1, unitConfig.height or 40, function(newValue)
        unitConfig.height = newValue
        SafeRefreshUnit("player")
    end)

    AddSlider(container, "Power Bar Height", 4, 30, 1, unitConfig.powerBarHeight or 8, function(newValue)
        unitConfig.powerBarHeight = newValue
        SafeRefreshUnit("player")
    end)

    AddEditBox(container, "StatusBar Texture", unitConfig.statusBarTexture or "", function(newValue)
        unitConfig.statusBarTexture = newValue
        SafeRefreshUnit("player")
    end)
end

local function BuildPlayerHealthBarTabPosition(container)
    local unitConfig = GetUnitConfig("player")
    if not unitConfig then
        AddLabel(container, "Missing config: Units.player")
        return
    end

    AddDropdown(container, "Point", POINTS, unitConfig.point or "CENTER", function(newValue)
        unitConfig.point = newValue
        SafeRefreshUnit("player")
    end)

    AddDropdown(container, "Relative Point", POINTS, unitConfig.relativePoint or "CENTER", function(newValue)
        unitConfig.relativePoint = newValue
        SafeRefreshUnit("player")
    end)

    AddSlider(container, "Position X", -1000, 1000, 1, unitConfig.x or 0, function(newValue)
        unitConfig.x = newValue
        SafeRefreshUnit("player")
    end)

    AddSlider(container, "Position Y", -1000, 1000, 1, unitConfig.y or 0, function(newValue)
        unitConfig.y = newValue
        SafeRefreshUnit("player")
    end)
end

local function BuildPlayerHealthBarTabColors(container)
    local unitConfig = GetUnitConfig("player")
    if not unitConfig then
        AddLabel(container, "Missing config: Units.player")
        return
    end

    unitConfig.backgroundColor = EnsureColorTable(unitConfig.backgroundColor, { 0.08, 0.08, 0.08, 0.90 })
    unitConfig.borderColor     = EnsureColorTable(unitConfig.borderColor,     { 0.20, 0.20, 0.20, 1.00 })
    unitConfig.healthColor     = EnsureColorTable(unitConfig.healthColor,     { 0.10, 0.80, 0.10, 1.00 })
    unitConfig.powerColor      = EnsureColorTable(unitConfig.powerColor,      { 0.20, 0.40, 0.90, 1.00 })

    AddLabel(container, "Choose the colors for the player frame.")
    AddSpacer(container, 8)

    AddColorPickerRow(container, "Background", unitConfig.backgroundColor, function()
        SafeRefreshUnit("player")
    end, { 0.08, 0.08, 0.08, 0.90 })

    AddSpacer(container, 4)

    AddColorPickerRow(container, "Border", unitConfig.borderColor, function()
        SafeRefreshUnit("player")
    end, { 0.20, 0.20, 0.20, 1.00 })

    AddSpacer(container, 4)

    AddSpacer(container, 4)

    ColorPicker.Create(container, {
        path = { "Units", "player", "healthColor" },
        label = "Health",
        description = "Sets the health bar color.",
        hasAlpha = true,
        resetText = "Reset",
        onChanged = function()
            SafeRefreshUnit("player")
        end,
    })

AddSpacer(container, 4)

    AddSpacer(container, 4)

    AddColorPickerRow(container, "Power", unitConfig.powerColor, function()
        SafeRefreshUnit("player")
    end, { 0.20, 0.40, 0.90, 1.00 })
end

local function BuildPlayerHealthBarPage(container)
    container:ReleaseChildren()
    container:SetLayout("Fill")

    local tabs = AceGUI:Create("TabGroup")
    tabs:SetFullWidth(true)
    tabs:SetFullHeight(true)
    tabs:SetTabs({
        { text = "General", value = "general" },
        { text = "Position", value = "position" },
        { text = "Colors", value = "colors" },
    })

    tabs:SetCallback("OnGroupSelected", function(tabGroup, _, group)
        AddScrollTabContent(tabGroup, function(content)
            if group == "general" then
                BuildPlayerHealthBarTabGeneral(content)
            elseif group == "position" then
                BuildPlayerHealthBarTabPosition(content)
            elseif group == "colors" then
                BuildPlayerHealthBarTabColors(content)
            end
        end)
    end)

    container:AddChild(tabs)
    tabs:SelectTab("general")
end

local function BuildTextGeneralTab(container, unit, textKey)
    local textConfig = GetTextConfig(unit, textKey)
    if not textConfig then
        AddLabel(container, "Missing config: Units." .. unit .. ".Texts." .. textKey)
        return
    end

    AddCheckBox(container, "Enabled", textConfig.enabled, function(newValue)
        textConfig.enabled = newValue
        SafeRefreshUnit(unit)
    end)

    AddEditBox(container, "Tag", textConfig.tag or "", function(newValue)
        textConfig.tag = newValue
        SafeRefreshUnit(unit)
    end)

    AddDropdown(container, "Anchor To", ANCHOR_TARGETS, textConfig.anchorTo or "HealthBar", function(newValue)
        textConfig.anchorTo = newValue
        SafeRefreshUnit(unit)
    end)

    AddDropdown(container, "Point", POINTS, textConfig.point or "CENTER", function(newValue)
        textConfig.point = newValue
        SafeRefreshUnit(unit)
    end)

    AddDropdown(container, "Relative Point", POINTS, textConfig.relativePoint or "CENTER", function(newValue)
        textConfig.relativePoint = newValue
        SafeRefreshUnit(unit)
    end)
end

local function BuildTextFontTab(container, unit, textKey)
    local textConfig = GetTextConfig(unit, textKey)
    if not textConfig then
        AddLabel(container, "Missing config: Units." .. unit .. ".Texts." .. textKey)
        return
    end

    AddEditBox(container, "Font Path", textConfig.font or "", function(newValue)
        textConfig.font = newValue
        SafeRefreshUnit(unit)
    end)

    AddSlider(container, "Font Size", 6, 32, 1, textConfig.fontSize or 12, function(newValue)
        textConfig.fontSize = newValue
        SafeRefreshUnit(unit)
    end)

    AddDropdown(container, "Justify H", JUSTIFY_H, textConfig.justifyH or "CENTER", function(newValue)
        textConfig.justifyH = newValue
        SafeRefreshUnit(unit)
    end)

    AddCheckBox(container, "Outline", textConfig.outline, function(newValue)
        textConfig.outline = newValue
        SafeRefreshUnit(unit)
    end)

    AddCheckBox(container, "Thick Outline", textConfig.thickOutline, function(newValue)
        textConfig.thickOutline = newValue
        SafeRefreshUnit(unit)
    end)

    AddCheckBox(container, "Monochrome", textConfig.monochrome, function(newValue)
        textConfig.monochrome = newValue
        SafeRefreshUnit(unit)
    end)
end

local function BuildTextPositionTab(container, unit, textKey)
    local textConfig = GetTextConfig(unit, textKey)
    if not textConfig then
        AddLabel(container, "Missing config: Units." .. unit .. ".Texts." .. textKey)
        return
    end

    AddSlider(container, "Offset X", -100, 100, 1, textConfig.offsetX or 0, function(newValue)
        textConfig.offsetX = newValue
        SafeRefreshUnit(unit)
    end)

    AddSlider(container, "Offset Y", -100, 100, 1, textConfig.offsetY or 0, function(newValue)
        textConfig.offsetY = newValue
        SafeRefreshUnit(unit)
    end)
end

local function BuildTextEffectsTab(container, unit, textKey)
    local textConfig = GetTextConfig(unit, textKey)
    if not textConfig then
        AddLabel(container, "Missing config: Units." .. unit .. ".Texts." .. textKey)
        return
    end

    textConfig.color = EnsureColorTable(textConfig.color, { 1, 1, 1, 1 })
    textConfig.shadowColor = EnsureColorTable(textConfig.shadowColor, { 0, 0, 0, 1 })

    AddCheckBox(container, "Shadow Enabled", textConfig.shadowEnabled, function(newValue)
        textConfig.shadowEnabled = newValue
        SafeRefreshUnit(unit)
    end)

    AddSlider(container, "Shadow Offset X", -10, 10, 1, textConfig.shadowOffsetX or 1, function(newValue)
        textConfig.shadowOffsetX = newValue
        SafeRefreshUnit(unit)
    end)

    AddSlider(container, "Shadow Offset Y", -10, 10, 1, textConfig.shadowOffsetY or -1, function(newValue)
        textConfig.shadowOffsetY = newValue
        SafeRefreshUnit(unit)
    end)

    AddSpacer(container, 8)

    AddColorPickerRow(container, "Text Color", textConfig.color, function()
        SafeRefreshUnit(unit)
    end, { 1, 1, 1, 1 })

    AddSpacer(container, 4)

    AddColorPickerRow(container, "Shadow Color", textConfig.shadowColor, function()
        SafeRefreshUnit(unit)
    end, { 0, 0, 0, 1 })
end

local function BuildTextPage(container, unit, textKey, title)
    container:ReleaseChildren()
    container:SetLayout("Fill")

    local tabs = AceGUI:Create("TabGroup")
    tabs:SetFullWidth(true)
    tabs:SetFullHeight(true)
    tabs:SetTabs({
        { text = "General", value = "general" },
        { text = "Font", value = "font" },
        { text = "Position", value = "position" },
        { text = "Effects", value = "effects" },
    })

    tabs:SetCallback("OnGroupSelected", function(tabGroup, _, group)
        AddScrollTabContent(tabGroup, function(content)
            AddHeading(content, title)
            AddSpacer(content, 8)

            if group == "general" then
                BuildTextGeneralTab(content, unit, textKey)
            elseif group == "font" then
                BuildTextFontTab(content, unit, textKey)
            elseif group == "position" then
                BuildTextPositionTab(content, unit, textKey)
            elseif group == "effects" then
                BuildTextEffectsTab(content, unit, textKey)
            end
        end)
    end)

    container:AddChild(tabs)
    tabs:SelectTab("general")
end

local TREE_PATH_SEPARATOR = "\001"

local function NormalizeGroupValue(group)
    if type(group) ~= "string" then
        return group
    end

    if group:find(TREE_PATH_SEPARATOR, 1, true) then
        local lastValue
        for value in string.gmatch(group, "([^" .. TREE_PATH_SEPARATOR .. "]+)") do
            lastValue = value
        end
        return lastValue or group
    end

    return group
end

local C = Portrait.Constants

local function ParseUnitPath(path)
    local unitKey = string.match(path or "", "^units%.([^.]+)$")
    return unitKey
end

local function RenderPage(container, path)
    local OptionRefresh = Portrait.GUI.Helpers.OptionRefresh
    if OptionRefresh and OptionRefresh.ClearStateWidgets then
        OptionRefresh.ClearStateWidgets()
    end
    if path == "general" then
        BuildGeneralPage(container)
        return
    end

    if path == C.Nav.TAG_DATABASE then
        Portrait.GUIBuilders.BuildTagDatabasePage(container)
        return
    end

    if path == C.Nav.TEXT_BUILDER then
        Portrait.GUIBuilders.BuildTextBuilderPage(container)
        return
    end

    if path == "profiles" then
        Portrait.GUIBuilders.BuildPlaceholderPage(container, "Profiles")
        return
    end


    if path == "units" then
        Portrait.GUIBuilders.BuildPlaceholderPage(container, "Units")
        return
    end

    local unitKey = ParseUnitPath(path)
    if unitKey then
        Portrait.GUIBuilders.BuildUnitPage(container, unitKey)
        return
    end

    Portrait.GUIBuilders.BuildPlaceholderPage(container, path or "Unknown")
end

function Portrait.GUI:RefreshOptions()
    local addon = Portrait

    if not addon.guiTreeGroup then
        return
    end

    local selectedPath = self.selectedPath or "general"
    RenderPage(addon.guiTreeGroup, selectedPath)
end

function Portrait:CreateGUI()
    if self.guiFrame then
        self.guiFrame:Show()
        return
    end

    local frame = AceGUI:Create("Frame")
    frame:SetTitle("Portrait")
    frame:SetStatusText((L and L["GUI_STATUS_READY"]) or "Ready")
    frame:SetLayout("Fill")
    frame:SetWidth(980)
    frame:SetHeight(640)
    frame:EnableResize(true)

    function self:SetTestModeEnabled(enabled)
        self.guiTestModeEnabled = enabled and true or false

        if self.guiTestButton then
            self.guiTestButton:SetText(self.guiTestModeEnabled and ((L and L["GUI_TEST_STOP"]) or "Stop Test") or ((L and L["GUI_TEST_START"]) or "Test"))
        end

        if self.guiFrame then
            self.guiFrame:SetStatusText(self.guiTestModeEnabled and ((L and L["GUI_TEST_ACTIVE"]) or "Test mode active") or ((L and L["GUI_STATUS_READY"]) or "Ready"))
        end
    end

    function self:ToggleTestMode()
        local enabled = not self.guiTestModeEnabled
        self:SetTestModeEnabled(enabled)

        if self.TestEnvironment then
            if enabled and self.TestEnvironment.Enable then
                self.TestEnvironment:Enable()
            elseif (not enabled) and self.TestEnvironment.Disable then
                self.TestEnvironment:Disable()
            elseif self.TestEnvironment.SetEnabled then
                self.TestEnvironment:SetEnabled(enabled)
            elseif self.TestEnvironment.Toggle then
                self.TestEnvironment:Toggle(enabled)
            elseif self.TestEnvironment.Refresh then
                self.TestEnvironment:Refresh()
            end
        end

        if Portrait.RefreshAllUnitFrames then
            Portrait:RefreshAllUnitFrames()
        end
    end

    frame:SetCallback("OnClose", function(widget)
        if Portrait.guiTestModeEnabled then
            Portrait:SetTestModeEnabled(false)
            if Portrait.TestEnvironment then
                if Portrait.TestEnvironment.Disable then
                    Portrait.TestEnvironment:Disable()
                elseif Portrait.TestEnvironment.SetEnabled then
                    Portrait.TestEnvironment:SetEnabled(false)
                end
            end
        end
        widget:Hide()
    end)

    self.guiTreeStatus = self.guiTreeStatus or {
        groups = {
            [Portrait.Constants.Nav.UNITS] = true,
        },
        selected = self.GUI.selectedPath or "general",
    }

    local treeGroup = AceGUI:Create("TreeGroup")
    treeGroup:SetFullWidth(true)
    treeGroup:SetFullHeight(true)
    treeGroup:SetLayout("Fill")
    treeGroup:SetStatusTable(self.guiTreeStatus)
    treeGroup:SetTree(NAV_TREE)

    treeGroup.localstatus.groups = treeGroup.localstatus.groups or {}
    treeGroup.localstatus.groups[Portrait.Constants.Nav.UNITS] = true

    treeGroup:SetCallback("OnGroupSelected", function(widget, _, group)
        local normalizedGroup = NormalizeGroupValue(group)
        Portrait.GUI.selectedPath = normalizedGroup
        Portrait.guiTreeStatus.selected = normalizedGroup
        RenderPage(widget, normalizedGroup)
    end)

    frame:AddChild(treeGroup)
    self.guiFrame = frame
    self.guiTreeGroup = treeGroup

    local statusBg = frame.statustext and frame.statustext:GetParent()
    if statusBg and not self.guiTestButton then
        local button = CreateFrame("Button", nil, statusBg, "UIPanelButtonTemplate")
        button:SetText(self.guiTestModeEnabled and ((L and L["GUI_TEST_STOP"]) or "Stop Test") or ((L and L["GUI_TEST_START"]) or "Test"))
        button:SetScript("OnClick", function()
            Portrait:ToggleTestMode()
        end)
        self.guiTestButton = button
    end

    ArrangeFrameFooter(frame, self.guiTestButton)

    local initialPath = self.GUI.selectedPath or "general"
    treeGroup:SelectByValue(initialPath)
    ApplyPortraitTreePixelSnap(treeGroup)
end

function Portrait:OpenConfig()
    self:CreateGUI()
end
