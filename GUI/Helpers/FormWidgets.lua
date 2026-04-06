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

local function GetSectionStyles()
    return (ns.GUI.Layouts and ns.GUI.Layouts.FormElements and ns.GUI.Layouts.FormElements.SectionStyles) or {}
end

local function GetButtonStyles()
    return (ns.GUI.Layouts and ns.GUI.Layouts.FormElements and ns.GUI.Layouts.FormElements.ButtonStyles) or {}
end

local function GetFieldStyles()
    return (ns.GUI.Layouts and ns.GUI.Layouts.FormElements and ns.GUI.Layouts.FormElements.FieldStyles) or {}
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

function FormWidgets.ResolveSectionStyle(style)
    if type(style) == "table" then
        return style
    end

    return type(style) == "string" and GetSectionStyles()[style] or nil
end

function FormWidgets.ResolveButtonStyle(variant)
    return GetButtonStyles()[variant or "primary"] or {}
end

function FormWidgets.ResolveFieldStyle(variant)
    return GetFieldStyles()[variant or "accented"] or {}
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
    local color = type(border) == "table" and (border.color or FormWidgets.ResolveItemColor(border.colorKey)) or chromeColors.sectionBorder

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

function FormWidgets.ApplySectionSurface(group, sectionStyle)
    if not group or not group.frame then
        return
    end

    local style = FormWidgets.ResolveSectionStyle(sectionStyle)
    local surface = style and style.surface or nil
    local frame = group.frame

    local function HideTexture(name)
        if frame[name] and frame[name].Hide then
            frame[name]:Hide()
        end
    end

    if not surface then
        HideTexture("_fpSectionFill")
        HideTexture("_fpSectionTopShade")
        HideTexture("_fpSectionBottomShade")
        HideTexture("_fpSectionAccent")
        HideTexture("_fpSectionDivider")
        return
    end

    local function EnsureTexture(name, layer, subLevel)
        if not frame[name] then
            frame[name] = frame:CreateTexture(nil, layer or "BACKGROUND", nil, subLevel or 0)
        end
        frame[name]:Show()
        return frame[name]
    end

    if surface.fill then
        local fill = EnsureTexture("_fpSectionFill", "BACKGROUND")
        fill:SetAllPoints(frame)
        fill:SetColorTexture(unpack(surface.fill))
    else
        HideTexture("_fpSectionFill")
    end

    if surface.topShade then
        local topShade = EnsureTexture("_fpSectionTopShade", "ARTWORK")
        topShade:SetPoint("TOPLEFT", frame, "TOPLEFT", 1, -1)
        topShade:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -1, -1)
        topShade:SetHeight(1)
        topShade:SetColorTexture(unpack(surface.topShade))
    else
        HideTexture("_fpSectionTopShade")
    end

    if surface.bottomShade then
        local bottomShade = EnsureTexture("_fpSectionBottomShade", "ARTWORK")
        bottomShade:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 1, 1)
        bottomShade:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -1, 1)
        bottomShade:SetHeight(1)
        bottomShade:SetColorTexture(unpack(surface.bottomShade))
    else
        HideTexture("_fpSectionBottomShade")
    end

    if surface.accent then
        local accent = EnsureTexture("_fpSectionAccent", "BORDER")
        local edge = surface.accent.edge or "top"
        local thickness = surface.accent.thickness or 1
        local insetLeft = surface.accent.insetLeft or 0
        local insetRight = surface.accent.insetRight or 0
        accent:ClearAllPoints()
        if edge == "bottom" then
            accent:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", insetLeft, 0)
            accent:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -insetRight, 0)
        else
            accent:SetPoint("TOPLEFT", frame, "TOPLEFT", insetLeft, 0)
            accent:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -insetRight, 0)
        end
        accent:SetHeight(thickness)
        accent:SetColorTexture(unpack(surface.accent.color or {}))
    else
        HideTexture("_fpSectionAccent")
    end

    if surface.divider and surface.divider.mode == "center_vertical" then
        local divider = EnsureTexture("_fpSectionDivider", "BORDER")
        local thickness = surface.divider.thickness or 1
        local insetTop = surface.divider.insetTop or 0
        local insetBottom = surface.divider.insetBottom or 0
        divider:ClearAllPoints()
        divider:SetPoint("TOP", frame, "TOP", 0, -insetTop)
        divider:SetPoint("BOTTOM", frame, "BOTTOM", 0, insetBottom)
        divider:SetWidth(thickness)
        divider:SetColorTexture(unpack(surface.divider.color or {}))
    else
        HideTexture("_fpSectionDivider")
    end
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

    local style = FormWidgets.ResolveButtonStyle(variant)
    local sidebarShared = GetSidebarShared()
    if sidebarShared and sidebarShared.StyleSidebarButton then
        sidebarShared.StyleSidebarButton(button, style.sidebarVariant or variant or "primary")
    end

    button:SetHeight(style.height or 24)

    if button.text then
        FormWidgets.ApplyTextStyle(button.text, style.textRole or "label", 12, 1)
        if button.text.SetTextColor then
            local textColor = style.textColor or { 0.95, 0.91, 0.88, 1.00 }
            button.text:SetTextColor(textColor[1] or 1, textColor[2] or 1, textColor[3] or 1, textColor[4] or 1)
        end
    end

    local frame = button.frame
    local normal = frame.GetNormalTexture and frame:GetNormalTexture() or nil
    local pushed = frame.GetPushedTexture and frame:GetPushedTexture() or nil
    local highlight = frame.GetHighlightTexture and frame:GetHighlightTexture() or nil
    local disabled = frame.GetDisabledTexture and frame:GetDisabledTexture() or nil

    SetTextureColor(normal, style.normal)
    SetTextureColor(pushed, style.pushed or style.normal)
    SetTextureColor(highlight, style.highlight or style.normal)
    SetTextureColor(disabled, style.disabled or style.normal)
end

local function ApplyInsetSurface(frame, style, prefix)
    if not frame then
        return
    end

    local topColor = style and style.insetTop
    local bottomColor = style and style.insetBottom
    local topKey = prefix .. "TopShade"
    local bottomKey = prefix .. "BottomShade"

    if topColor then
        if not frame[topKey] then
            frame[topKey] = frame:CreateTexture(nil, "ARTWORK")
        end
        frame[topKey]:ClearAllPoints()
        frame[topKey]:SetPoint("TOPLEFT", frame, "TOPLEFT", 2, -2)
        frame[topKey]:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -2, -2)
        frame[topKey]:SetHeight(1)
        frame[topKey]:SetColorTexture(unpack(topColor))
        frame[topKey]:Show()
    elseif frame[topKey] and frame[topKey].Hide then
        frame[topKey]:Hide()
    end

    if bottomColor then
        if not frame[bottomKey] then
            frame[bottomKey] = frame:CreateTexture(nil, "ARTWORK")
        end
        frame[bottomKey]:ClearAllPoints()
        frame[bottomKey]:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 2, 2)
        frame[bottomKey]:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -2, 2)
        frame[bottomKey]:SetHeight(1)
        frame[bottomKey]:SetColorTexture(unpack(bottomColor))
        frame[bottomKey]:Show()
    elseif frame[bottomKey] and frame[bottomKey].Hide then
        frame[bottomKey]:Hide()
    end
end

function FormWidgets.StyleDropdown(dropdown, variant)
    if not dropdown then
        return
    end

    local chromeColors = GetChromeColors()
    local style = FormWidgets.ResolveFieldStyle(variant)

    FormWidgets.ApplyTextStyle(dropdown.label, "label", 12, 1)
    if dropdown.text and dropdown.text.SetTextColor then
        local valueColor = style.valueColor or GetItemColors().value
        dropdown.text:SetTextColor(valueColor[1] or 1, valueColor[2] or 1, valueColor[3] or 1, 1)
    end

    if dropdown.dropdown then
        local name = dropdown.dropdown:GetName()
        if name then
            SetTextureColor(_G[name .. "Left"], style.border or chromeColors.fieldBorder)
            SetTextureColor(_G[name .. "Middle"], style.background or chromeColors.fieldBackground)
            SetTextureColor(_G[name .. "Right"], style.border or chromeColors.fieldBorder)
        end
        ApplyInsetSurface(dropdown.dropdown, style, "_fpDropdown")
    end

    if dropdown.button then
        local buttonNormal = dropdown.button.GetNormalTexture and dropdown.button:GetNormalTexture() or nil
        local buttonPushed = dropdown.button.GetPushedTexture and dropdown.button:GetPushedTexture() or nil
        local buttonHighlight = dropdown.button.GetHighlightTexture and dropdown.button:GetHighlightTexture() or nil
        SetTextureColor(buttonNormal, style.buttonNormal or style.border or chromeColors.fieldBorder)
        SetTextureColor(buttonPushed, style.buttonPushed or style.buttonNormal or style.border or chromeColors.fieldBorder)
        SetTextureColor(buttonHighlight, style.buttonHighlight or style.buttonNormal or style.border or chromeColors.fieldBorder)
    end
end

local function ColorEditBoxRegions(target, color)
    if not target or not color then
        return
    end

    for _, region in ipairs({ target:GetRegions() }) do
        if region and region.GetObjectType and region:GetObjectType() == "Texture" then
            SetTextureColor(region, color)
        end
    end
end

function FormWidgets.StyleEditBox(editBox, variant)
    if not editBox then
        return
    end

    local chromeColors = GetChromeColors()
    local style = FormWidgets.ResolveFieldStyle(variant)

    FormWidgets.ApplyTextStyle(editBox.label, "label", 12, 1)

    if editBox.editbox then
        if editBox.editbox.SetTextColor then
            local valueColor = style.valueColor or GetItemColors().value
            editBox.editbox:SetTextColor(valueColor[1] or 1, valueColor[2] or 1, valueColor[3] or 1, 1)
        end

        ColorEditBoxRegions(editBox.editbox, style.border or chromeColors.fieldBorder)
        ApplyInsetSurface(editBox.editbox, style, "_fpEditBox")

        if not editBox.editbox._fpFieldStyleHooked and editBox.editbox.HookScript then
            editBox.editbox:HookScript("OnEditFocusGained", function(self)
                local activeStyle = self._fpFieldStyle or {}
                ColorEditBoxRegions(self, activeStyle.borderFocus or activeStyle.border or chromeColors.fieldBorderFocus or chromeColors.fieldBorder)
            end)
            editBox.editbox:HookScript("OnEditFocusLost", function(self)
                local activeStyle = self._fpFieldStyle or {}
                ColorEditBoxRegions(self, activeStyle.border or chromeColors.fieldBorder)
            end)
            editBox.editbox._fpFieldStyleHooked = true
        end
        editBox.editbox._fpFieldStyle = style
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

    if not frame._fpPanelTopShade then
        frame._fpPanelTopShade = frame:CreateTexture(nil, "ARTWORK")
        frame._fpPanelTopShade:SetPoint("TOPLEFT", frame, "TOPLEFT", 13, -31)
        frame._fpPanelTopShade:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -13, -31)
        frame._fpPanelTopShade:SetHeight(1)
    end
    frame._fpPanelTopShade:SetColorTexture(unpack(chromeColors.panelTopShade or {}))

    if not frame._fpPanelBottomShade then
        frame._fpPanelBottomShade = frame:CreateTexture(nil, "ARTWORK")
        frame._fpPanelBottomShade:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 13, 13)
        frame._fpPanelBottomShade:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -13, 13)
        frame._fpPanelBottomShade:SetHeight(1)
    end
    frame._fpPanelBottomShade:SetColorTexture(unpack(chromeColors.panelBottomShade or {}))

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

    local function EnsureInnerBorder(name)
        if not frame[name] then
            frame[name] = frame:CreateTexture(nil, "BORDER")
        end
        frame[name]:SetColorTexture(unpack(chromeColors.panelInnerBorder or chromeColors.sectionBorder or {}))
        frame[name]:Show()
    end

    EnsureInnerBorder("_fpPanelInnerTop")
    frame._fpPanelInnerTop:SetPoint("TOPLEFT", frame, "TOPLEFT", 13, -31)
    frame._fpPanelInnerTop:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -13, -31)
    frame._fpPanelInnerTop:SetHeight(1)

    EnsureInnerBorder("_fpPanelInnerBottom")
    frame._fpPanelInnerBottom:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 13, 13)
    frame._fpPanelInnerBottom:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -13, 13)
    frame._fpPanelInnerBottom:SetHeight(1)

    EnsureInnerBorder("_fpPanelInnerLeft")
    frame._fpPanelInnerLeft:SetPoint("TOPLEFT", frame, "TOPLEFT", 13, -31)
    frame._fpPanelInnerLeft:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 13, 13)
    frame._fpPanelInnerLeft:SetWidth(1)

    EnsureInnerBorder("_fpPanelInnerRight")
    frame._fpPanelInnerRight:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -13, -31)
    frame._fpPanelInnerRight:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -13, 13)
    frame._fpPanelInnerRight:SetWidth(1)

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
