local _, ns = ...

ns.GUI = ns.GUI or {}
ns.GUI.Helpers = ns.GUI.Helpers or {}

local AceGUI = LibStub("AceGUI-3.0")

local FormWidgets = {}
ns.GUI.Helpers.FormWidgets = FormWidgets

local function GetFormPalette()
    return (ns.GUI.Layouts and ns.GUI.Layouts.FormElements and ns.GUI.Layouts.FormElements.Palette) or {}
end

local function GetChromeColors()
    return GetFormPalette().Chrome or {}
end

local function GetButtonColors()
    return GetFormPalette().Buttons or {}
end

local function GetItemColors()
    return GetFormPalette().ItemColors or {}
end

local function GetTextStyles()
    return ns.GUI.Helpers and ns.GUI.Helpers.TextStyles or nil
end

local function GetSidebarShared()
    return ns.GUI.Editor and ns.GUI.Editor.SidebarShared or nil
end

local function SetTextureColor(texture, color)
    if texture and texture.SetVertexColor and color then
        texture:SetVertexColor(color[1] or 1, color[2] or 1, color[3] or 1, color[4] or 1)
    end
end

local function HideDefaultWindowChrome(frame)
    if not frame or frame._fpDefaultChromeHidden then
        return
    end

    for _, region in ipairs({ frame:GetRegions() }) do
        if region and region.GetObjectType and region:GetObjectType() == "Texture" then
            region:Hide()
            if region.SetAlpha then
                region:SetAlpha(0)
            end
        end
    end

    frame._fpDefaultChromeHidden = true
end

function FormWidgets.ResolveItemColor(colorKey)
    return colorKey and GetItemColors()[colorKey] or nil
end

local function CanRelayout(container)
    if not container or not container.DoLayout then
        return false
    end

    local tableLayout = AceGUI:GetLayout("Table")
    if container.LayoutFunc == tableLayout and container.GetUserData then
        return type(container:GetUserData("table")) == "table"
    end

    return true
end

local function RequestOwnerRelayout(container)
    local current = container
    while current do
        if CanRelayout(current) then
            current:DoLayout()
        end
        current = current._fpOwnerGroup
    end
end

function FormWidgets.ApplySectionBorder(group, border)
    if not group or not group.frame then
        return
    end

    local frame = group.frame
    local chromeColors = GetChromeColors()
    local color = chromeColors.sectionBorder

    if border == false or not color then
        for _, name in ipairs({
            "_fpSectionBorderTop",
            "_fpSectionBorderBottom",
            "_fpSectionBorderLeft",
            "_fpSectionBorderRight",
        }) do
            if frame[name] and frame[name].Hide then
                frame[name]:Hide()
            end
        end
        return
    end

    local thickness = type(border) == "table" and (border.thickness or 1) or 1
    local inset = type(border) == "table" and (border.inset or 0) or 0

    local function EnsureBorder(name)
        if not frame[name] then
            frame[name] = frame:CreateTexture(nil, "BORDER")
        end
        frame[name]:SetColorTexture(unpack(color))
        frame[name]:Show()
    end

    EnsureBorder("_fpSectionBorderTop")
    frame._fpSectionBorderTop:SetPoint("TOPLEFT", frame, "TOPLEFT", inset, -inset)
    frame._fpSectionBorderTop:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -inset, -inset)
    frame._fpSectionBorderTop:SetHeight(thickness)

    EnsureBorder("_fpSectionBorderBottom")
    frame._fpSectionBorderBottom:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", inset, inset)
    frame._fpSectionBorderBottom:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -inset, inset)
    frame._fpSectionBorderBottom:SetHeight(thickness)

    EnsureBorder("_fpSectionBorderLeft")
    frame._fpSectionBorderLeft:SetPoint("TOPLEFT", frame, "TOPLEFT", inset, -inset)
    frame._fpSectionBorderLeft:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", inset, inset)
    frame._fpSectionBorderLeft:SetWidth(thickness)

    EnsureBorder("_fpSectionBorderRight")
    frame._fpSectionBorderRight:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -inset, -inset)
    frame._fpSectionBorderRight:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -inset, inset)
    frame._fpSectionBorderRight:SetWidth(thickness)
end

function FormWidgets.ApplySectionPadding(group, padding)
    if not group or not group.content or group.type == "ScrollFrame" then
        return
    end

    local anchor = group.frame
    local content = group.content
    local left = 0
    local right = 0
    local top = 0
    local bottom = 0

    if type(padding) == "number" then
        left, right, top, bottom = padding, padding, padding, padding
    elseif type(padding) == "table" then
        left = padding.left or padding.x or 0
        right = padding.right or padding.x or 0
        top = padding.top or padding.y or 0
        bottom = padding.bottom or padding.y or 0
    end

    content:ClearAllPoints()
    content:SetPoint("TOPLEFT", anchor, "TOPLEFT", left, -top)
    content:SetPoint("BOTTOMRIGHT", anchor, "BOTTOMRIGHT", -right, bottom)
end

function FormWidgets.ApplyTextStyle(target, role, size, alpha)
    if not target then
        return
    end

    local textStyles = GetTextStyles()
    if textStyles and textStyles.ApplyFontString then
        textStyles.ApplyFontString(target, role, {
            size = size,
            alpha = alpha,
        })
    end
end

function FormWidgets.CreateBodyText(text, role, size, color, width, fullWidth)
    local label = AceGUI:Create("Label")
    local originalSetText = label.SetText
    if type(width) == "number" then
        label:SetWidth(width)
    elseif fullWidth ~= false then
        label:SetFullWidth(true)
        if label.frame then
            label.frame.width = nil
        end
    end
    FormWidgets.ApplyTextStyle(label.label, role or "label", size or 12, 1)

    if color and label.label and label.label.SetTextColor then
        label.label:SetTextColor(color[1] or 1, color[2] or 1, color[3] or 1, color[4] or 1)
    end

    label.SetText = function(self, value)
        local previousHeight = self.frame and self.frame:GetHeight() or 0
        originalSetText(self, value)
        local updatedHeight = self.frame and self.frame:GetHeight() or 0
        if math.abs(updatedHeight - previousHeight) > 0.5 then
            RequestOwnerRelayout(self._fpOwnerGroup)
        end
    end

    -- Re-apply the text after styling so AceGUI recalculates the label height
    -- using the final font metrics instead of the initial widget default font.
    label:SetText(text or "")

    return label
end

function FormWidgets.CreateSectionTitle(text, size)
    return FormWidgets.CreateBodyText(text, "sectionHeader", size or 13, nil, nil, true)
end

function FormWidgets.StyleActionButton(button, variant)
    if not button or not button.frame then
        return
    end

    local sidebarShared = GetSidebarShared()
    if sidebarShared and sidebarShared.StyleSidebarButton then
        sidebarShared.StyleSidebarButton(button, variant == "danger" and "danger" or "primary")
    end

    local buttonColors = GetButtonColors()

    button:SetHeight(26)

    if button.text then
        FormWidgets.ApplyTextStyle(button.text, variant == "danger" and "danger" or "label", 12, 1)
        if button.text.SetTextColor then
            local textColor = buttonColors.text
            button.text:SetTextColor(textColor[1] or 1, textColor[2] or 1, textColor[3] or 1, textColor[4] or 1)
        end
    end

    local frame = button.frame
    local normal = frame.GetNormalTexture and frame:GetNormalTexture() or nil
    local pushed = frame.GetPushedTexture and frame:GetPushedTexture() or nil
    local highlight = frame.GetHighlightTexture and frame:GetHighlightTexture() or nil
    local disabled = frame.GetDisabledTexture and frame:GetDisabledTexture() or nil

    SetTextureColor(normal, buttonColors.primary)
    SetTextureColor(pushed, buttonColors.pressed)
    SetTextureColor(highlight, buttonColors.highlight)
    SetTextureColor(disabled, buttonColors.disabled)
end

function FormWidgets.StyleDropdown(dropdown, variant)
    if not dropdown then
        return
    end

    local chromeColors = GetChromeColors()
    local buttonColors = GetButtonColors()
    local itemColors = GetItemColors()

    FormWidgets.ApplyTextStyle(dropdown.label, "label", 12, 1)
    if dropdown.text and dropdown.text.SetTextColor then
        local valueColor = itemColors.value
        dropdown.text:SetTextColor(valueColor[1] or 1, valueColor[2] or 1, valueColor[3] or 1, 1)
    end

    if dropdown.dropdown then
        local name = dropdown.dropdown:GetName()
        if name then
            SetTextureColor(_G[name .. "Left"], chromeColors.fieldBorder)
            SetTextureColor(_G[name .. "Middle"], chromeColors.fieldBackground)
            SetTextureColor(_G[name .. "Right"], chromeColors.fieldBorder)
        end
    end

    if dropdown.button then
        local buttonNormal = dropdown.button.GetNormalTexture and dropdown.button:GetNormalTexture() or nil
        local buttonPushed = dropdown.button.GetPushedTexture and dropdown.button:GetPushedTexture() or nil
        local buttonHighlight = dropdown.button.GetHighlightTexture and dropdown.button:GetHighlightTexture() or nil
        SetTextureColor(buttonNormal, chromeColors.fieldBorder)
        if variant == "neutral" then
            SetTextureColor(buttonPushed, chromeColors.fieldBorder)
            SetTextureColor(buttonHighlight, chromeColors.fieldBorder)
        else
            SetTextureColor(buttonPushed, buttonColors.pressed)
            SetTextureColor(buttonHighlight, buttonColors.highlight)
        end
    end
end

function FormWidgets.StyleEditBox(editBox)
    if not editBox then
        return
    end

    local chromeColors = GetChromeColors()
    local itemColors = GetItemColors()

    FormWidgets.ApplyTextStyle(editBox.label, "label", 12, 1)

    if editBox.editbox then
        if editBox.editbox.SetTextColor then
            local valueColor = itemColors.value
            editBox.editbox:SetTextColor(valueColor[1] or 1, valueColor[2] or 1, valueColor[3] or 1, 1)
        end

        for _, region in ipairs({ editBox.editbox:GetRegions() }) do
            if region and region.GetObjectType and region:GetObjectType() == "Texture" then
                SetTextureColor(region, chromeColors.fieldBorder)
            end
        end
    end
end

function FormWidgets.StyleCheckBox(checkbox, disabled)
    if not checkbox then
        return
    end

    local itemColors = GetItemColors()

    if checkbox.text and checkbox.text.SetTextColor then
        local color = disabled and itemColors.checkboxDisabled or itemColors.checkbox
        checkbox.text:SetTextColor(color[1] or 1, color[2] or 1, color[3] or 1, color[4] or 1)
    end

    local textStyles = GetTextStyles()
    if textStyles and textStyles.ApplyInteractiveWidgetText then
        textStyles.ApplyInteractiveWidgetText(checkbox, "label", disabled and true or false, { size = 12 })
    end
end

function FormWidgets.ApplyWindowChrome(window)
    if not window or not window.frame then
        return
    end

    local chromeColors = GetChromeColors()
    local frame = window.frame
    local content = window.content

    HideDefaultWindowChrome(frame)

    if window.titletext then
        FormWidgets.ApplyTextStyle(window.titletext, "sectionHeader", 15, 1)
    end

    if not frame._fpPanelFill then
        frame._fpPanelFill = frame:CreateTexture(nil, "ARTWORK")
        frame._fpPanelFill:SetPoint("TOPLEFT", frame, "TOPLEFT", 12, -30)
        frame._fpPanelFill:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -12, 12)
    end
    frame._fpPanelFill:SetColorTexture(unpack(chromeColors.panelBackground or {}))

    if not frame._fpPanelHeaderFill then
        frame._fpPanelHeaderFill = frame:CreateTexture(nil, "ARTWORK")
        frame._fpPanelHeaderFill:SetPoint("TOPLEFT", frame, "TOPLEFT", 12, -30)
        frame._fpPanelHeaderFill:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -12, -30)
        frame._fpPanelHeaderFill:SetHeight(26)
    end
    frame._fpPanelHeaderFill:SetColorTexture(unpack(chromeColors.panelHeader or {}))

    local function EnsureBorder(name)
        if not frame[name] then
            frame[name] = frame:CreateTexture(nil, "BORDER")
        end
        frame[name]:SetColorTexture(unpack(chromeColors.panelBorder or {}))
        frame[name]:Show()
    end

    EnsureBorder("_fpPanelBorderTop")
    frame._fpPanelBorderTop:SetPoint("TOPLEFT", frame, "TOPLEFT", 12, -30)
    frame._fpPanelBorderTop:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -12, -30)
    frame._fpPanelBorderTop:SetHeight(1)

    EnsureBorder("_fpPanelBorderBottom")
    frame._fpPanelBorderBottom:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 12, 12)
    frame._fpPanelBorderBottom:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -12, 12)
    frame._fpPanelBorderBottom:SetHeight(1)

    EnsureBorder("_fpPanelBorderLeft")
    frame._fpPanelBorderLeft:SetPoint("TOPLEFT", frame, "TOPLEFT", 12, -30)
    frame._fpPanelBorderLeft:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 12, 12)
    frame._fpPanelBorderLeft:SetWidth(1)

    EnsureBorder("_fpPanelBorderRight")
    frame._fpPanelBorderRight:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -12, -30)
    frame._fpPanelBorderRight:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -12, 12)
    frame._fpPanelBorderRight:SetWidth(1)

    if content then
        if not content._fpAccent then
            content._fpAccent = content:CreateTexture(nil, "BORDER")
            content._fpAccent:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -2)
            content._fpAccent:SetPoint("TOPRIGHT", content, "TOPRIGHT", 0, -2)
            content._fpAccent:SetHeight(1)
        end
        content._fpAccent:SetColorTexture(unpack(chromeColors.accent or {}))
    end
end

function FormWidgets.CreateActionButton(text, variant, width, fullWidth)
    local button = AceGUI:Create("Button")
    button:SetText(text or "")
    if fullWidth == false and width then
        button:SetWidth(width)
    else
        button:SetFullWidth(true)
    end
    FormWidgets.StyleActionButton(button, variant)
    return button
end

return FormWidgets
