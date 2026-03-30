local _, FocalPoint = ...

local AceGUI = LibStub("AceGUI-3.0")
local L = FocalPoint.L

FocalPoint.GUI = FocalPoint.GUI or {}

local ShowGUIFrame
local HideGUIFrame

local function GetMainHostWidget(addon)
    if not addon then
        return nil
    end

    return addon.guiMainHost
end

local function GetMainHostFrame(addon)
    local widget = GetMainHostWidget(addon)
    if not widget then
        return nil
    end

    return widget.frame or widget
end

local function GetReadyStatusText()
    return (L and L["GUI_STATUS_READY"]) or "Ready"
end

function FocalPoint.GUI:SetStatusText(message)
    local host = GetMainHostWidget(FocalPoint)
    if host and host.SetStatusText then
        host:SetStatusText(message or GetReadyStatusText())
    end
end

function FocalPoint.GUI:ResetStatusText()
    self:SetStatusText(GetReadyStatusText())
end

local function ResolveDefaultGUIPath(path)
    local unitKey = type(path) == "string" and string.match(path, "^units%.([^.]+)$") or nil
    if unitKey then
        local editorState = FocalPoint.GUI and FocalPoint.GUI.Editor and FocalPoint.GUI.Editor.State
        if editorState and editorState.SetSelectedUnit then
            editorState.SetSelectedUnit(unitKey)
        end
        return FocalPoint.Constants.Nav.EDITOR
    end

    if path == "units" then
        return FocalPoint.Constants.Nav.EDITOR
    end

    if path == nil or path == "" or path == "general" or path == FocalPoint.Constants.Nav.THEMES then
        return FocalPoint.Constants.Nav.EDITOR
    end

    return path
end

FocalPoint.GUI.selectedPath = ResolveDefaultGUIPath(FocalPoint.GUI.selectedPath)

local NAV_TREE = FocalPoint.GUIBuilders.CreateNavTree()

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
    return FocalPoint.db and FocalPoint.db.profile
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
    if FocalPoint.RefreshUnitFrame then
        FocalPoint:RefreshUnitFrame(unit)
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
    local rootFrame = frame.frame or (statusBg and statusBg:GetParent())
    local closeButton = frame.closebutton

    if not statusBg or not rootFrame then
        return
    end

    if not closeButton and rootFrame.GetChildren then
        for _, child in ipairs({ rootFrame:GetChildren() }) do
            if child
                and child.GetObjectType
                and child:GetObjectType() == "Button"
                and child.GetText
                and child:GetText() == CLOSE
            then
                closeButton = child
                break
            end
        end
    end

    if testButton then
        testButton:Hide()
    end

    if closeButton then
        closeButton:SetParent(rootFrame)
        closeButton:ClearAllPoints()
        closeButton:SetPoint("TOPRIGHT", rootFrame, "TOPRIGHT", -8, -6)
    end

    statusBg:Hide()
    statusText:Hide()
end

local function SnapToWholePixel(value)
    if type(value) ~= "number" then
        return value
    end

    return math.floor(value + 0.5)
end

local function ApplyFocalPointTreePixelSnap(treeGroup)
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
    FocalPoint.GUIBuilders.BuildGeneralPage(container)
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

local C = FocalPoint.Constants

local function ParseUnitPath(path)
    local unitKey = string.match(path or "", "^units%.([^.]+)$")
    return unitKey
end

local function RenderToolContent(container, buildFunc)
    if type(buildFunc) == "function" then
        buildFunc(container)
    end
end

local function RenderPage(container, path)
    local OptionRefresh = FocalPoint.GUI.Helpers.OptionRefresh
    local EditorPage = FocalPoint.GUI and FocalPoint.GUI.Pages and FocalPoint.GUI.Pages.Editor
    local AppShell = FocalPoint.GUI and FocalPoint.GUI.AppShell
    local shellMode = (AppShell and AppShell.ResolveShellMode and AppShell.ResolveShellMode(FocalPoint, path)) or "tool"

    local function RenderInShellMode(targetMode, buildFunc)
        local mode = targetMode or shellMode
        if AppShell and AppShell.RenderMainContent then
            AppShell.RenderMainContent(container, mode, buildFunc)
            return
        end

        if container and container.ReleaseChildren then
            container:ReleaseChildren()
        end
        if container and container.SetLayout then
            container:SetLayout("Fill")
        end
        if type(buildFunc) == "function" then
            buildFunc(container)
        end
    end

    if OptionRefresh and OptionRefresh.ClearStateWidgets then
        OptionRefresh.ClearStateWidgets()
    end

    if shellMode ~= "editor" and EditorPage and EditorPage.Release then
        EditorPage.Release()
    end

    if path == "general" then
        RenderInShellMode("editor", function(content)
            FocalPoint.GUIBuilders.BuildEditorPage(content)
        end)
        return
    end

    if path == C.Nav.EDITOR then
        RenderInShellMode("editor", function(content)
            FocalPoint.GUIBuilders.BuildEditorPage(content)
        end)
        return
    end

    if path == C.Nav.TAG_DATABASE then
        RenderInShellMode("tool", function(content)
            RenderToolContent(content, function(panel)
                FocalPoint.GUIBuilders.BuildTagDatabasePage(panel)
            end)
        end)
        return
    end

    if path == C.Nav.TEXT_BUILDER then
        RenderInShellMode("tool", function(content)
            RenderToolContent(content, function(panel)
                FocalPoint.GUIBuilders.BuildTextBuilderPage(panel)
            end)
        end)
        return
    end

    if path == C.Nav.THEMES then
        RenderInShellMode("editor", function(content)
            FocalPoint.GUIBuilders.BuildEditorPage(content)
        end)
        return
    end

    if path == "profiles" then
        RenderInShellMode("tool", function(content)
            RenderToolContent(content, function(panel)
                FocalPoint.GUIBuilders.BuildProfilesPage(panel)
            end)
        end)
        return
    end


    if path == "units" then
        RenderInShellMode("editor", function(content)
            FocalPoint.GUIBuilders.BuildEditorPage(content)
        end)
        return
    end

    local unitKey = ParseUnitPath(path)
    if unitKey then
        local editorState = FocalPoint.GUI.Editor and FocalPoint.GUI.Editor.State
        if editorState and editorState.SetSelectedUnit then
            editorState.SetSelectedUnit(unitKey)
        end

        RenderInShellMode("editor", function(content)
            FocalPoint.GUIBuilders.BuildEditorPage(content)
        end)
        return
    end

    RenderInShellMode(shellMode, function(content)
        FocalPoint.GUIBuilders.BuildPlaceholderPage(content, path or "Unknown")
    end)
end

local function BuildAppSidebar(container)
    local Sidebar = FocalPoint.GUI and FocalPoint.GUI.Editor and FocalPoint.GUI.Editor.ContextSidebar
    if not Sidebar or not Sidebar.Build then
        Sidebar = FocalPoint.GUI and FocalPoint.GUI.Editor and FocalPoint.GUI.Editor.Sidebar
    end
    local EditorState = FocalPoint.GUI and FocalPoint.GUI.Editor and FocalPoint.GUI.Editor.State
    local AppShell = FocalPoint.GUI and FocalPoint.GUI.AppShell
    if not Sidebar or not EditorState or not EditorState.Get then
        return
    end

    local selectedPath = ResolveDefaultGUIPath(FocalPoint.GUI and FocalPoint.GUI.selectedPath)
    local shellMode = (AppShell and AppShell.ResolveShellMode and AppShell.ResolveShellMode(FocalPoint, selectedPath)) or "tool"

    Sidebar.Build(container, EditorState.Get(), {
        shellMode = shellMode,
        currentPath = selectedPath,
        onNavigate = function(path)
            local normalizedPath = ResolveDefaultGUIPath(path)
            FocalPoint.GUI.selectedPath = normalizedPath
            if FocalPoint.guiTreeStatus then
                FocalPoint.guiTreeStatus.selected = normalizedPath
            end
            if FocalPoint.GUI and FocalPoint.GUI.RefreshOptions then
                FocalPoint.GUI:RefreshOptions()
            end
        end,
        onUnitChanged = function(unitKey)
            if EditorState.SetSelectedUnit then
                EditorState.SetSelectedUnit(unitKey)
            end
            if FocalPoint.GUI and FocalPoint.GUI.RefreshOptions then
                FocalPoint.GUI:RefreshOptions()
            end
        end,
        onModeChanged = function(mode)
            if EditorState.SetMode then
                EditorState.SetMode(mode)
            end
            if FocalPoint.GUI and FocalPoint.GUI.RefreshOptions then
                FocalPoint.GUI:RefreshOptions()
            end
        end,
        onThemeChanged = function(themeId)
            if EditorState.SetSelectedThemeId then
                EditorState.SetSelectedThemeId(themeId)
            end
            BuildAppSidebar(container)
        end,
        onThemeApplied = function(themeId)
            if EditorState.SetSelectedThemeId then
                EditorState.SetSelectedThemeId(themeId)
            end
            if FocalPoint.GUI and FocalPoint.GUI.RefreshOptions then
                FocalPoint.GUI:RefreshOptions()
            end
        end,
        onGlobalChanged = function()
            if FocalPoint.GUI and FocalPoint.GUI.RefreshOptions then
                FocalPoint.GUI:RefreshOptions()
            end
        end,
        onClose = function()
            if FocalPoint.CloseConfig then
                FocalPoint:CloseConfig()
            end
        end,
    })
end

local function UpdateAppShellGeometry()
    local shell = FocalPoint.GUI and FocalPoint.GUI.AppShell
    if shell and shell.UpdateGeometry then
        shell.UpdateGeometry(FocalPoint, ResolveDefaultGUIPath)
    end
end

function FocalPoint.GUI:RefreshOptions()
    local addon = FocalPoint

    if addon._closingConfig then
        return
    end

    if not addon.guiContentHost then
        return
    end

    local selectedPath = ResolveDefaultGUIPath(self.selectedPath)
    UpdateAppShellGeometry()
    if addon.guiAppSidebar then
        BuildAppSidebar(addon.guiAppSidebar)
    end
    RenderPage(addon.guiContentHost, selectedPath)

    if addon.RefreshEditorSelectionVisuals then
        addon:RefreshEditorSelectionVisuals()
    end
end

function FocalPoint:IsEditorActive()
    local frame = GetMainHostFrame(self)
    if not frame then
        return false
    end

    if frame.IsShown and not frame:IsShown() then
        return false
    end

    return ResolveDefaultGUIPath(self.GUI and self.GUI.selectedPath) == self.Constants.Nav.EDITOR
end

function FocalPoint:SelectEditorUnit(unit)
    if type(unit) ~= "string" or unit == "" then
        return
    end

    local previousUnit = nil
    local editorState = self.GUI and self.GUI.Editor and self.GUI.Editor.State
    if editorState and editorState.Get then
        local currentState = editorState.Get()
        previousUnit = currentState and currentState.selectedUnit or nil
    end

    local selectedUnit = unit
    if selectedUnit:match("^boss%d+$") then
        selectedUnit = "boss"
    end

    if editorState and editorState.SetSelectedUnit then
        editorState.SetSelectedUnit(selectedUnit)
    end

    if self.GUI then
        self.GUI.selectedPath = self.Constants.Nav.EDITOR
    end

    if self.guiTreeStatus then
        self.guiTreeStatus.selected = self.Constants.Nav.EDITOR
    end

    if self.GUI and self.GUI.RefreshOptions then
        self.GUI:RefreshOptions()
    elseif self.RefreshEditorSelectionVisuals then
        self:RefreshEditorSelectionVisuals()
    end

    if (self.framesUnlocked or self.guiTestModeEnabled) and self.RefreshAllFrames then
        self:RefreshAllFrames()
    else
        if previousUnit and self.RefreshUnitFrame then
            self:RefreshUnitFrame(previousUnit)
        end
        if selectedUnit and self.RefreshUnitFrame then
            self:RefreshUnitFrame(selectedUnit)
        end
    end

    if self.RefreshEditorSelectionVisuals then
        self:RefreshEditorSelectionVisuals()
    end
end

ShowGUIFrame = function(widget)
    if not widget then
        return
    end

    if widget.frame and widget.frame.Show then
        widget.frame:Show()
        if FocalPoint.GUI and FocalPoint.GUI.RefreshOptions then
            FocalPoint.GUI:RefreshOptions()
        elseif FocalPoint.RefreshEditorSelectionVisuals then
            FocalPoint:RefreshEditorSelectionVisuals()
        end
        return
    end

    if widget.Show then
        widget:Show()
        if FocalPoint.GUI and FocalPoint.GUI.RefreshOptions then
            FocalPoint.GUI:RefreshOptions()
        elseif FocalPoint.RefreshEditorSelectionVisuals then
            FocalPoint:RefreshEditorSelectionVisuals()
        end
    end
end

HideGUIFrame = function(widget)
    if not widget then
        return
    end

    if widget.frame and widget.frame.Hide then
        widget.frame:Hide()
        if FocalPoint.RefreshEditorSelectionVisuals then
            FocalPoint:RefreshEditorSelectionVisuals()
        end
        return
    end

    if widget.Hide then
        widget:Hide()
        if FocalPoint.RefreshEditorSelectionVisuals then
            FocalPoint:RefreshEditorSelectionVisuals()
        end
    end
end

function FocalPoint:CloseConfig()
    if self._closingConfig then
        return
    end

    self._closingConfig = true

    local controller = self.GUI and self.GUI.Editor and self.GUI.Editor.Controller
    if controller and controller.ReleaseInspector then
        controller.ReleaseInspector()
    end

    local shell = self.GUI and self.GUI.AppShell
    if shell and shell.ClearEditorRuntimeRoles then
        shell.ClearEditorRuntimeRoles(self)
    end

    if self.guiTestModeEnabled and self.DisableTestMode then
        self:DisableTestMode()
    end

    if self.framesUnlocked then
        self.framesUnlocked = false
        if self.ClearAllMoveOverlays then
            self:ClearAllMoveOverlays()
        end
        if self.UpdateAllFrameDragStates then
            self:UpdateAllFrameDragStates()
        end
        if self.RefreshAllFrames then
            self:RefreshAllFrames()
        elseif self.RefreshAllUnitFrames then
            self:RefreshAllUnitFrames()
        end
    end

    if self.RefreshEditorSelectionVisuals then
        self:RefreshEditorSelectionVisuals()
    end

    if self.RefreshAllUnitFrames then
        self:RefreshAllUnitFrames()
    end

    local hostWidget = GetMainHostWidget(self)
    if hostWidget then
        HideGUIFrame(hostWidget)
    end

    self._closingConfig = false
end

local function CreateMainHostWidget()
    local hostWidget = AceGUI:Create("Frame")
    hostWidget:SetTitle("Focal Point")
    hostWidget:SetStatusText(GetReadyStatusText())
    hostWidget:SetLayout("Fill")
    hostWidget:SetWidth(1220)
    hostWidget:SetHeight(760)
    hostWidget:EnableResize(true)

    return hostWidget
end

function FocalPoint:CreateGUI()
    local existingHost = GetMainHostWidget(self)
    if existingHost then
        ShowGUIFrame(existingHost)
        return
    end

    local hostWidget = CreateMainHostWidget()

    function self:SetTestModeEnabled(enabled)
        self.guiTestModeEnabled = enabled and true or false

        if self.GUI and self.GUI.SetStatusText then
            self.GUI:SetStatusText(self.guiTestModeEnabled and ((L and L["GUI_TEST_ACTIVE"]) or "Test mode active") or GetReadyStatusText())
        end
    end

    function self:DisableTestMode()
        if not self.guiTestModeEnabled then
            return
        end

        self:SetTestModeEnabled(false)
        FocalPoint._suppressMissingUnitUntil = (GetTime and (GetTime() + 1.0)) or 0

        if self.TestEnvironment then
            if self.TestEnvironment.Disable then
                self.TestEnvironment:Disable()
            elseif self.TestEnvironment.SetEnabled then
                self.TestEnvironment:SetEnabled(false)
            elseif self.TestEnvironment.Toggle then
                self.TestEnvironment:Toggle(false)
            elseif self.TestEnvironment.Refresh then
                self.TestEnvironment:Refresh()
            end
        end

        local visibility = FocalPoint and FocalPoint.UnitFrameVisibility
        local clearVisuals = visibility and visibility.ClearFrameVisualState
        local unitExists = UnitExists
        if clearVisuals and FocalPoint and FocalPoint.frames then
            for unit, frame in pairs(FocalPoint.frames) do
                if frame and unit ~= "player" then
                    clearVisuals(frame)

                    local hasLiveUnit = unitExists and unitExists(unit)

                    if not hasLiveUnit
                        and frame.SetAlpha
                    then
                        frame:SetAlpha(0)
                    end

                    if not hasLiveUnit
                        and frame.Hide
                        and not (InCombatLockdown and InCombatLockdown())
                    then
                        frame:Hide()
                    end
                end
            end
        end

        if FocalPoint and FocalPoint.frames and FocalPoint.RefreshUnitFrame then
            C_Timer.After(0, function()
                if not FocalPoint or not FocalPoint.frames or not FocalPoint.RefreshUnitFrame then
                    return
                end

                for unit in pairs(FocalPoint.frames) do
                    if unit == "player" or (unitExists and unitExists(unit)) then
                        FocalPoint:RefreshUnitFrame(unit)
                    end
                end
            end)
        elseif FocalPoint.RefreshAllUnitFrames then
            FocalPoint:RefreshAllUnitFrames()
        end
    end

    function self:ToggleTestMode()
        local enabled = not self.guiTestModeEnabled
        self:SetTestModeEnabled(enabled)

        if enabled and FocalPoint.EnsureBossFrames then
            FocalPoint:EnsureBossFrames()
        end

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

        if FocalPoint.RefreshAllUnitFrames then
            FocalPoint:RefreshAllUnitFrames()
        end

        if self.GUI and self.GUI.RefreshOptions then
            self.GUI:RefreshOptions()
        end
    end

    hostWidget:SetCallback("OnClose", function()
        if self.CloseConfig then
            self:CloseConfig()
        end
    end)

    self.guiTreeStatus = self.guiTreeStatus or {
        groups = {},
        selected = ResolveDefaultGUIPath(self.GUI.selectedPath),
    }
    self.guiTreeStatus.selected = ResolveDefaultGUIPath(self.guiTreeStatus.selected)

    local shell = self.GUI and self.GUI.AppShell
    local root, appSidebar, contentHost
    if shell and shell.BuildRoot then
        root, appSidebar, contentHost = shell.BuildRoot(self, hostWidget)
    else
        return
    end

    self.guiMainHost = hostWidget
    self.guiRoot = root

    ArrangeFrameFooter(hostWidget, nil)

    local initialPath = ResolveDefaultGUIPath(self.GUI.selectedPath or self.guiTreeStatus.selected)
    self.GUI.selectedPath = initialPath
    UpdateAppShellGeometry()
    BuildAppSidebar(appSidebar)
    RenderPage(contentHost, initialPath)

    local function ReflowShellForDisplaySize()
        local widgetFrame = GetMainHostFrame(self)
        if not widgetFrame then
            return
        end
        if widgetFrame.IsShown and not widgetFrame:IsShown() then
            return
        end

        UpdateAppShellGeometry()
        if self.guiRoot and self.guiRoot.DoLayout then
            self.guiRoot:DoLayout()
        end

        local controller = self.GUI and self.GUI.Editor and self.GUI.Editor.Controller
        if controller and controller.UpdateActiveInspectorGeometry then
            controller.UpdateActiveInspectorGeometry()
        end
    end

    if not self.guiResizeWatcher then
        local watcher = CreateFrame("Frame")
        watcher:SetScript("OnEvent", function()
            ReflowShellForDisplaySize()
        end)
        watcher:RegisterEvent("DISPLAY_SIZE_CHANGED")
        watcher:RegisterEvent("UI_SCALE_CHANGED")
        self.guiResizeWatcher = watcher
    end

    local rootFrame = GetMainHostFrame(self)
    if rootFrame and rootFrame.HookScript and not rootFrame._focalPointResizeHooked then
        rootFrame:HookScript("OnSizeChanged", function()
            ReflowShellForDisplaySize()
        end)
        rootFrame._focalPointResizeHooked = true
    end
end

function FocalPoint:OpenConfig()
    if self.GUI then
        self.GUI.selectedPath = self.Constants and self.Constants.Nav and self.Constants.Nav.EDITOR or "editor"
    end
    if self.guiTreeStatus then
        self.guiTreeStatus.selected = self.Constants and self.Constants.Nav and self.Constants.Nav.EDITOR or "editor"
    end
    self:CreateGUI()
end
