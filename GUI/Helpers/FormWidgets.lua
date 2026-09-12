local _, ns = ...

ns.GUI = ns.GUI or {}
ns.GUI.Helpers = ns.GUI.Helpers or {}

local AceGUI = LibStub("AceGUI-3.0")
local CreateFrame = CreateFrame

local FormWidgets = {}
ns.GUI.Helpers.FormWidgets = FormWidgets

local function GetLayoutFormPalette()
    return (ns.GUI.Layouts and ns.GUI.Layouts.FormElements and ns.GUI.Layouts.FormElements.Palette) or {}
end

local function GetFormPalette()
    local fallback = GetLayoutFormPalette()
    local skins = ns.GUI and ns.GUI.Skins or nil
    if skins and skins.GetFormPalette then
        return skins.GetFormPalette(fallback) or fallback
    end
    return fallback
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

local function GetComponentStyle(component)
    if type(component) ~= "string" then
        return nil
    end

    local componentStyles = ns.GUI.Layouts
        and ns.GUI.Layouts.FormElements
        and ns.GUI.Layouts.FormElements.ComponentStyles
        or nil
    if type(componentStyles) ~= "table" then
        return nil
    end

    for _, family in pairs(componentStyles) do
        local style = type(family) == "table" and family[component] or nil
        if type(style) == "table" then
            return style
        end
    end

    return nil
end

FormWidgets.GetComponentStyle = GetComponentStyle


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

local FP_MODAL_BUTTON_VISUALS = {
    primary_action = {
        height = 24,
        disabledText = { 0.46, 0.38, 0.28, 1.00 },
    },
    secondary = {
        height = 22,
        disabledText = { 0.50, 0.55, 0.60, 1.00 },
    },
    utility = {
        height = 22,
        disabledText = { 0.49, 0.55, 0.61, 1.00 },
    },
    danger = {
        height = 22,
        disabledText = { 0.62, 0.47, 0.48, 1.00 },
    },
}

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
    local componentStyle = GetComponentStyle(variant)
    local resolvedVariant = (componentStyle and componentStyle.buttonStyle) or variant or "primary"
    return GetButtonStyles()[resolvedVariant] or {}
end

local function ResolveButtonVariantFromRole(variant)
    local role = variant or "primary"
    local roles = ns.GUI and ns.GUI.ButtonVisualRole or nil

    local activeRole = (roles and roles.ACTIVE) or "active"
    local secondaryRole = (roles and roles.SECONDARY) or "secondary"
    local primaryActionRole = (roles and roles.PRIMARY_ACTION) or "primary_action"
    local utilityRole = (roles and roles.UTILITY) or "utility"
    local dangerRole = (roles and roles.DANGER) or "danger"

    if role == primaryActionRole then
        return "primary"
    end
    if role == utilityRole then
        return "secondary"
    end
    if role == secondaryRole then
        return "secondary"
    end
    if role == activeRole then
        return "primary"
    end
    if role == dangerRole then
        return "danger"
    end

    return role
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
    label._fpOwnerGroup = nil
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

    if not label._fpOriginalSetText then
        label._fpOriginalSetText = label.SetText
    end
    if not label._fpSetTextRelayoutWrapped then
        label.SetText = function(self, value)
            local originalSetText = self._fpOriginalSetText
            if type(originalSetText) ~= "function" then
                return
            end

            local previousHeight = self.frame and self.frame:GetHeight() or 0
            originalSetText(self, value)
            local updatedHeight = self.frame and self.frame:GetHeight() or 0
            if math.abs(updatedHeight - previousHeight) > 0.5 then
                RequestOwnerRelayout(self._fpOwnerGroup)
            end
        end
        label._fpSetTextRelayoutWrapped = true
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

    if FormWidgets.ResetInspectorButtonState then
        FormWidgets.ResetInspectorButtonState(button)
    end

    local resolvedVariant = ResolveButtonVariantFromRole(variant)
    local style = FormWidgets.ResolveButtonStyle(resolvedVariant)

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

function FormWidgets.ApplyModalActionButtonVisual(button, role, options)
    if not button or not button.frame then
        return
    end

    options = type(options) == "table" and options or {}
    if not options.preserveInspectorButtonState and FormWidgets.ResetInspectorButtonState then
        FormWidgets.ResetInspectorButtonState(button)
    end
    if not options.preserveInspectorButtonState then
        button.__fpModalHovered = false
        button.__fpModalPressed = false
    end

    local sidebarThemeHelpers = ns.GUI and ns.GUI.Editor and ns.GUI.Editor.EditorSidebarThemeHelpers or {}
    local ApplyFPButtonVisualCore = sidebarThemeHelpers.ApplyFPButtonVisualCore

    local componentStyle = GetComponentStyle(role)
    local resolvedRole = ResolveButtonVariantFromRole((componentStyle and componentStyle.buttonStyle) or role)
    if resolvedRole == "primary" then
        resolvedRole = "primary_action"
    elseif resolvedRole ~= "primary_action" and resolvedRole ~= "secondary" and resolvedRole ~= "utility" and resolvedRole ~= "danger" then
        resolvedRole = "secondary"
    end

    button.__fpModalLastRole = resolvedRole
    local style = FP_MODAL_BUTTON_VISUALS[resolvedRole] or FP_MODAL_BUTTON_VISUALS.secondary
    if not ApplyFPButtonVisualCore then
        return
    end

    local function ReapplyModalVisualOnHover(targetButton)
        FormWidgets.ApplyModalActionButtonVisual(targetButton, targetButton.__fpModalLastRole or "secondary", {
            preserveInspectorButtonState = true,
        })
    end

    ApplyFPButtonVisualCore(button, style, {
        layerKeys = {
            bg = "__fpActionVisualBg",
            texture = "__fpActionVisualTexture",
            border = "__fpActionVisualBorder",
            accent = "__fpActionVisualAccent",
        },
        rolePreset = resolvedRole,
        selected = (resolvedRole == "primary_action"),
        preferSelectedWhenDisabled = false,
        accentVisible = (resolvedRole == "primary_action"),
        hover = {
            enabled = true,
            hookKey = "__fpModalHoverHooked",
            stateKey = "__fpModalHovered",
            pressedKey = "__fpModalPressed",
            onReapply = ReapplyModalVisualOnHover,
        },
    })
end

local function SetInspectorGlyphColor(frame, hovered)
    local text = frame and frame.__fpInspectorGlyphText or nil
    if not text or not text.SetTextColor then
        return
    end

    local alpha = frame.__fpInspectorGlyphDisabled and 0.45 or 1
    if hovered then
        text:SetTextColor(1, 0.98, 0.82, alpha)
    else
        text:SetTextColor(1, 0.95, 0.78, alpha)
    end
end

local function EnsureInspectorButtonHooks(button)
    local frame = button and button.frame or nil
    if not frame or frame.__fpInspectorButtonHooks then
        return
    end

    frame.__fpInspectorButtonHooks = true
    frame:HookScript("OnEnter", function(self)
        if self.__fpInspectorTooltip and GameTooltip then
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:ClearLines()
            GameTooltip:AddLine(self.__fpInspectorTooltip, 1, 1, 1, true)
            GameTooltip:Show()
        end
        if self.__fpInspectorGlyphActive then
            SetInspectorGlyphColor(self, true)
        end
    end)
    frame:HookScript("OnLeave", function(self)
        if self.__fpInspectorTooltip and GameTooltip then
            GameTooltip:Hide()
        end
        if self.__fpInspectorGlyphActive then
            SetInspectorGlyphColor(self, false)
        end
    end)
    frame:HookScript("OnMouseDown", function(self)
        local text = self.__fpInspectorGlyphText
        if self.__fpInspectorGlyphActive and text and text.SetPoint then
            text:ClearAllPoints()
            text:SetPoint("CENTER", self, "CENTER", 1, -1)
        end
    end)
    frame:HookScript("OnMouseUp", function(self)
        local text = self.__fpInspectorGlyphText
        if self.__fpInspectorGlyphActive and text and text.SetPoint then
            text:ClearAllPoints()
            text:SetPoint("CENTER", self, "CENTER", 0, 0)
        end
    end)
end

function FormWidgets.ResetInspectorButtonState(button)
    local frame = button and button.frame or nil
    if not frame then
        return
    end

    frame.__fpInspectorTooltip = nil
    frame.__fpInspectorGlyphActive = false
    frame.__fpInspectorGlyph = nil
    frame.__fpInspectorGlyphDisabled = false

    local glyphText = frame.__fpInspectorGlyphText
    if glyphText then
        glyphText:SetText("")
        if glyphText.Hide then
            glyphText:Hide()
        end
    end
    local legacyGlyphText = frame.__fpDecorationGlyphText
    if legacyGlyphText then
        legacyGlyphText:SetText("")
        if legacyGlyphText.Hide then
            legacyGlyphText:Hide()
        end
    end
    frame.__fpDecorationGlyph = nil
    frame.__fpDecorationGlyphDisabled = false

    if button.text then
        if button.text.Show then
            button.text:Show()
        end
        if button.text.SetAlpha then
            button.text:SetAlpha(1)
        end
        if button.text.ClearAllPoints and button.text.SetPoint then
            button.text:ClearAllPoints()
            button.text:SetPoint("TOPLEFT", 15, -1)
            button.text:SetPoint("BOTTOMRIGHT", -15, 1)
        end
        if button.text.SetJustifyV then
            button.text:SetJustifyV("MIDDLE")
        end
    end
end

function FormWidgets.SetInspectorButtonTooltip(button, text)
    local frame = button and button.frame or nil
    if not frame then
        return
    end

    EnsureInspectorButtonHooks(button)
    frame.__fpInspectorTooltip = type(text) == "string" and text ~= "" and text or nil
end

function FormWidgets.ApplyInspectorGlyphButton(button, glyph, disabled)
    local frame = button and button.frame or nil
    if not frame then
        return
    end

    EnsureInspectorButtonHooks(button)

    if button.text then
        button.text:SetText("")
        if button.text.SetAlpha then
            button.text:SetAlpha(0)
        end
        if button.text.Hide then
            button.text:Hide()
        end
    end

    local glyphText = frame.__fpInspectorGlyphText
    if not glyphText then
        glyphText = frame:CreateFontString(nil, "OVERLAY")
        frame.__fpInspectorGlyphText = glyphText
    end

    glyphText:ClearAllPoints()
    glyphText:SetPoint("CENTER", frame, "CENTER", 0, 0)
    if glyphText.SetDrawLayer then
        glyphText:SetDrawLayer("OVERLAY", 7)
    end
    if glyphText.SetFont then
        glyphText:SetFont(STANDARD_TEXT_FONT, 15, "OUTLINE")
    end
    if glyphText.SetJustifyH then
        glyphText:SetJustifyH("CENTER")
    end
    if glyphText.SetJustifyV then
        glyphText:SetJustifyV("MIDDLE")
    end
    if glyphText.SetShadowColor then
        glyphText:SetShadowColor(0, 0, 0, 0.85)
    end
    if glyphText.SetShadowOffset then
        glyphText:SetShadowOffset(1, -1)
    end

    frame.__fpInspectorGlyphActive = true
    frame.__fpInspectorGlyph = glyph or ""
    frame.__fpInspectorGlyphDisabled = disabled and true or false
    glyphText:SetText(frame.__fpInspectorGlyph)
    SetInspectorGlyphColor(frame, false)
    glyphText:Show()
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

function FormWidgets.EnsureStandardWindowCloseButton(window)
    local closeButton = window and window.closebutton
    if not closeButton then
        return
    end

    if closeButton.Show then
        closeButton:Show()
    end
    if closeButton.EnableMouse then
        closeButton:EnableMouse(true)
    end
    if closeButton.GetScript and closeButton.SetScript and not closeButton:GetScript("OnClick") then
        closeButton:SetScript("OnClick", function(button)
            local owner = button and button.obj
            if owner and owner.Hide then
                owner:Hide()
            end
        end)
    end
end

function FormWidgets.CenterWindow(window)
    local frame = window and window.frame
    if not frame then
        return
    end

    frame:ClearAllPoints()
    frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
end

function FormWidgets.FocusWindow(window, options)
    local frame = window and window.frame
    if not frame then
        return
    end

    options = options or {}
    if options.centerIfHidden and frame.IsShown and not frame:IsShown() then
        FormWidgets.CenterWindow(window)
    end

    if window.Show then
        window:Show()
    elseif frame.Show then
        frame:Show()
    end

    if frame.SetFrameStrata then
        frame:SetFrameStrata(options.strata or "FULLSCREEN_DIALOG")
    end
    if frame.SetToplevel then
        frame:SetToplevel(options.toplevel ~= false)
    end
    if frame.Raise then
        frame:Raise()
    end
end

local function EnableCompactDialogEscapeClose(window)
    local frame = window and window.frame
    if not frame or not frame.SetScript then
        return
    end

    frame:EnableKeyboard(true)
    if frame.SetPropagateKeyboardInput then
        frame:SetPropagateKeyboardInput(true)
    end
    frame:SetScript("OnKeyDown", function(_, key)
        if key == "ESCAPE" and window.Hide then
            window:Hide()
        end
    end)
end

local function AddCompactDialogSpacer(parent, height)
    local spacer = AceGUI:Create("Label")
    spacer:SetText(" ")
    spacer:SetFullWidth(true)
    spacer:SetHeight(height or 6)
    parent:AddChild(spacer)
    return spacer
end

local function EnsureCompactDialogTexture(frame, key, layer)
    if not frame then
        return nil
    end

    if not frame[key] then
        frame[key] = frame:CreateTexture(nil, layer or "BACKGROUND")
    end
    frame[key]:Show()
    return frame[key]
end

local function SetCompactDialogColor(texture, color)
    if texture and texture.SetColorTexture and color then
        texture:SetColorTexture(color[1] or 1, color[2] or 1, color[3] or 1, color[4] or 1)
    end
end

local function SetCompactDialogPointPair(texture, startPoint, startRelative, startX, startY, endPoint, endRelative, endX, endY)
    if not texture then
        return
    end

    texture:ClearAllPoints()
    texture:SetPoint(startPoint, startRelative, startPoint, startX or 0, startY or 0)
    texture:SetPoint(endPoint, endRelative, endPoint, endX or 0, endY or 0)
end

local function ApplyCompactDialogWindowChrome(window)
    local frame = window and window.frame
    if not frame then
        return
    end

    local chromeColors = GetChromeColors()
    local outerInset = 8

    local fill = EnsureCompactDialogTexture(frame, "_fpCompactDialogOuterFill", "ARTWORK")
    SetCompactDialogPointPair(fill, "TOPLEFT", frame, outerInset, -outerInset, "BOTTOMRIGHT", frame, -outerInset, outerInset)
    SetCompactDialogColor(fill, chromeColors.panelBackground)

    local header = EnsureCompactDialogTexture(frame, "_fpCompactDialogHeaderFill", "ARTWORK")
    SetCompactDialogPointPair(header, "TOPLEFT", frame, outerInset, -outerInset, "TOPRIGHT", frame, -outerInset, -outerInset)
    header:SetHeight(24)
    SetCompactDialogColor(header, chromeColors.panelHeader)

    local headerDivider = EnsureCompactDialogTexture(frame, "_fpCompactDialogHeaderDivider", "ARTWORK")
    SetCompactDialogPointPair(headerDivider, "TOPLEFT", frame, outerInset, -32, "TOPRIGHT", frame, -outerInset, -32)
    headerDivider:SetHeight(1)
    SetCompactDialogColor(headerDivider, chromeColors.panelTopShade or chromeColors.panelInnerBorder)

    local bottomShade = EnsureCompactDialogTexture(frame, "_fpCompactDialogBottomShade", "ARTWORK")
    SetCompactDialogPointPair(bottomShade, "BOTTOMLEFT", frame, outerInset, outerInset, "BOTTOMRIGHT", frame, -outerInset, outerInset)
    bottomShade:SetHeight(1)
    SetCompactDialogColor(bottomShade, chromeColors.panelBottomShade)

    local borderColor = chromeColors.panelBorder
    local innerBorderColor = chromeColors.panelInnerBorder or chromeColors.sectionBorder

    local borderTop = EnsureCompactDialogTexture(frame, "_fpCompactDialogBorderTop", "OVERLAY")
    SetCompactDialogPointPair(borderTop, "TOPLEFT", frame, 7, -7, "TOPRIGHT", frame, -7, -7)
    borderTop:SetHeight(1)
    SetCompactDialogColor(borderTop, borderColor)

    local borderBottom = EnsureCompactDialogTexture(frame, "_fpCompactDialogBorderBottom", "OVERLAY")
    SetCompactDialogPointPair(borderBottom, "BOTTOMLEFT", frame, 7, 7, "BOTTOMRIGHT", frame, -7, 7)
    borderBottom:SetHeight(1)
    SetCompactDialogColor(borderBottom, borderColor)

    local borderLeft = EnsureCompactDialogTexture(frame, "_fpCompactDialogBorderLeft", "OVERLAY")
    SetCompactDialogPointPair(borderLeft, "TOPLEFT", frame, 7, -7, "BOTTOMLEFT", frame, 7, 7)
    borderLeft:SetWidth(1)
    SetCompactDialogColor(borderLeft, borderColor)

    local borderRight = EnsureCompactDialogTexture(frame, "_fpCompactDialogBorderRight", "OVERLAY")
    SetCompactDialogPointPair(borderRight, "TOPRIGHT", frame, -7, -7, "BOTTOMRIGHT", frame, -7, 7)
    borderRight:SetWidth(1)
    SetCompactDialogColor(borderRight, borderColor)

    local innerTop = EnsureCompactDialogTexture(frame, "_fpCompactDialogInnerTop", "BORDER")
    SetCompactDialogPointPair(innerTop, "TOPLEFT", frame, outerInset, -outerInset, "TOPRIGHT", frame, -outerInset, -outerInset)
    innerTop:SetHeight(1)
    SetCompactDialogColor(innerTop, innerBorderColor)

    local innerBottom = EnsureCompactDialogTexture(frame, "_fpCompactDialogInnerBottom", "BORDER")
    SetCompactDialogPointPair(innerBottom, "BOTTOMLEFT", frame, outerInset, outerInset, "BOTTOMRIGHT", frame, -outerInset, outerInset)
    innerBottom:SetHeight(1)
    SetCompactDialogColor(innerBottom, innerBorderColor)

    local innerLeft = EnsureCompactDialogTexture(frame, "_fpCompactDialogInnerLeft", "BORDER")
    SetCompactDialogPointPair(innerLeft, "TOPLEFT", frame, outerInset, -outerInset, "BOTTOMLEFT", frame, outerInset, outerInset)
    innerLeft:SetWidth(1)
    SetCompactDialogColor(innerLeft, innerBorderColor)

    local innerRight = EnsureCompactDialogTexture(frame, "_fpCompactDialogInnerRight", "BORDER")
    SetCompactDialogPointPair(innerRight, "TOPRIGHT", frame, -outerInset, -outerInset, "BOTTOMRIGHT", frame, -outerInset, outerInset)
    innerRight:SetWidth(1)
    SetCompactDialogColor(innerRight, innerBorderColor)
end

local function ApplyCompactDialogSurface(widget, key, options)
    local frame = widget and widget.frame
    if not frame then
        return
    end

    options = options or {}
    local chromeColors = GetChromeColors()
    local prefix = "_fpCompactDialog" .. (key or "Surface")

    local fill = EnsureCompactDialogTexture(frame, prefix .. "Fill", "BACKGROUND")
    SetCompactDialogPointPair(fill, "TOPLEFT", frame, 0, 0, "BOTTOMRIGHT", frame, 0, 0)
    SetCompactDialogColor(fill, options.fill or chromeColors.sectionFill)

    local topShade = EnsureCompactDialogTexture(frame, prefix .. "TopShade", "BORDER")
    SetCompactDialogPointPair(topShade, "TOPLEFT", frame, 1, -1, "TOPRIGHT", frame, -1, -1)
    topShade:SetHeight(1)
    SetCompactDialogColor(topShade, options.topShade or chromeColors.sectionInsetTop)

    local bottomShade = EnsureCompactDialogTexture(frame, prefix .. "BottomShade", "BORDER")
    SetCompactDialogPointPair(bottomShade, "BOTTOMLEFT", frame, 1, 1, "BOTTOMRIGHT", frame, -1, 1)
    bottomShade:SetHeight(1)
    SetCompactDialogColor(bottomShade, options.bottomShade or chromeColors.sectionInsetBottom)

    local borderColor = options.border or chromeColors.sectionBorder or chromeColors.panelInnerBorder
    local borderTop = EnsureCompactDialogTexture(frame, prefix .. "BorderTop", "BORDER")
    SetCompactDialogPointPair(borderTop, "TOPLEFT", frame, 0, 0, "TOPRIGHT", frame, 0, 0)
    borderTop:SetHeight(1)
    SetCompactDialogColor(borderTop, borderColor)

    local borderBottom = EnsureCompactDialogTexture(frame, prefix .. "BorderBottom", "BORDER")
    SetCompactDialogPointPair(borderBottom, "BOTTOMLEFT", frame, 0, 0, "BOTTOMRIGHT", frame, 0, 0)
    borderBottom:SetHeight(1)
    SetCompactDialogColor(borderBottom, borderColor)

    local borderLeft = EnsureCompactDialogTexture(frame, prefix .. "BorderLeft", "BORDER")
    SetCompactDialogPointPair(borderLeft, "TOPLEFT", frame, 0, 0, "BOTTOMLEFT", frame, 0, 0)
    borderLeft:SetWidth(1)
    SetCompactDialogColor(borderLeft, borderColor)

    local borderRight = EnsureCompactDialogTexture(frame, prefix .. "BorderRight", "BORDER")
    SetCompactDialogPointPair(borderRight, "TOPRIGHT", frame, 0, 0, "BOTTOMRIGHT", frame, 0, 0)
    borderRight:SetWidth(1)
    SetCompactDialogColor(borderRight, borderColor)
end

function FormWidgets.CalculateCompactPickerContentHeight(rowHeights, options)
    options = options or {}

    local contentHeight = tonumber(options.padding) or 6
    if type(rowHeights) == "table" then
        for _, rowHeight in ipairs(rowHeights) do
            if type(rowHeight) == "number" and rowHeight > 0 then
                contentHeight = contentHeight + rowHeight
            end
        end
    end

    local minHeight = tonumber(options.minHeight) or 72
    local maxHeight = tonumber(options.maxHeight) or 252
    return math.max(minHeight, math.min(maxHeight, contentHeight))
end
local SMALL_WINDOW_REGION_TYPE = "FocalPointSmallWindowRegion"
local SMALL_WINDOW_REGION_VERSION = 1

local function RegisterSmallWindowRegion()
    if AceGUI:GetWidgetVersion(SMALL_WINDOW_REGION_TYPE) then
        return
    end

    local function Constructor()
        local frame = CreateFrame("Frame", nil, UIParent)
        local content = CreateFrame("Frame", nil, frame)
        content:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
        content:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)

        local widget = {
            type = SMALL_WINDOW_REGION_TYPE,
            frame = frame,
            content = content,
        }

        function widget:OnAcquire()
            self:SetLayout("List")
            self:SetAutoAdjustHeight(false)
            self.frame:Show()
        end

        function widget:OnRelease()
            self.frame:Hide()
        end

        function widget:LayoutFinished()
            -- The shell owns region geometry; child layout must not resize it.
        end

        AceGUI:RegisterAsContainer(widget)
        return widget
    end

    AceGUI:RegisterWidgetType(SMALL_WINDOW_REGION_TYPE, Constructor, SMALL_WINDOW_REGION_VERSION)
end

local function CreateSmallWindowRegion(parent, layout, anchors)
    local region = AceGUI:Create(SMALL_WINDOW_REGION_TYPE)
    region.frame:SetParent(parent)
    region.frame:ClearAllPoints()
    for _, anchor in ipairs(anchors) do
        region.frame:SetPoint(unpack(anchor))
    end
    region:SetLayout(layout)
    return region
end

local function CreateSmallWindowScrollRegion(parent, layout, anchors)
    local region = AceGUI:Create("ScrollFrame")
    region.frame:SetParent(parent)
    region.frame:ClearAllPoints()
    for _, anchor in ipairs(anchors) do
        region.frame:SetPoint(unpack(anchor))
    end
    region:SetLayout(layout or "List")
    if region.SetAutoAdjustHeight then
        region:SetAutoAdjustHeight(false)
    end
    return region
end
local function CreateCompactFormShell(window, options)
    RegisterSmallWindowRegion()

    local previousShell = window.frame._fpCompactFormShell
    if previousShell and previousShell.Release then
        previousShell:Release()
    end

    local contentInset = options.contentInset or 14
    local footerHeight = options.footerHeight or 38
    local statusHeight = options.statusHeight or 22
    local isMessageDialog = options.mode == "message" or options.showBody == false or options.bodyHeight == 0
    local isPickerDialog = options.mode == "picker"
    local headerHeight = not isMessageDialog and type(options.description) == "string" and options.description ~= "" and (options.descriptionHeight or 32) or 0
    local shellFrames = window.frame._fpCompactFormShellFrames
    if not shellFrames then
        shellFrames = {}
        window.frame._fpCompactFormShellFrames = shellFrames
    end

    local function AcquireShellFrame(key, parent)
        local frame = shellFrames[key]
        if not frame then
            frame = CreateFrame("Frame", nil, parent)
            shellFrames[key] = frame
        else
            frame:SetParent(parent)
            frame:ClearAllPoints()
        end
        frame:Show()
        return frame
    end

    local shellFrame = AcquireShellFrame("shell", window.content)
    shellFrame:ClearAllPoints()
    shellFrame:SetPoint("TOPLEFT", window.content, "TOPLEFT", 0, 0)
    shellFrame:SetPoint("BOTTOMRIGHT", window.content, "BOTTOMRIGHT", 0, 0)

    local footerFrame = AcquireShellFrame("footer", shellFrame)
    footerFrame:SetPoint("BOTTOMLEFT", shellFrame, "BOTTOMLEFT", 0, 0)
    footerFrame:SetPoint("BOTTOMRIGHT", shellFrame, "BOTTOMRIGHT", 0, 0)
    footerFrame:SetHeight(footerHeight)

    local statusFrame = AcquireShellFrame("status", shellFrame)
    statusFrame:SetPoint("BOTTOMLEFT", footerFrame, "TOPLEFT", contentInset, 0)
    statusFrame:SetPoint("BOTTOMRIGHT", footerFrame, "TOPRIGHT", -contentInset, 0)
    statusFrame:SetHeight(statusHeight)

    local headerFrame = shellFrames.header
    if headerHeight > 0 then
        headerFrame = AcquireShellFrame("header", shellFrame)
        headerFrame:SetPoint("TOPLEFT", shellFrame, "TOPLEFT", contentInset, 0)
        headerFrame:SetPoint("TOPRIGHT", shellFrame, "TOPRIGHT", -contentInset, 0)
        headerFrame:SetHeight(headerHeight)
    elseif headerFrame then
        headerFrame:Hide()
        headerFrame = nil
    end

    local contentFrame = AcquireShellFrame("content", shellFrame)
    local function UpdateContentBounds(statusVisible)
        contentFrame:ClearAllPoints()
        if headerFrame then
            contentFrame:SetPoint("TOPLEFT", headerFrame, "BOTTOMLEFT", 0, 0)
            contentFrame:SetPoint("TOPRIGHT", headerFrame, "BOTTOMRIGHT", 0, 0)
        else
            contentFrame:SetPoint("TOPLEFT", shellFrame, "TOPLEFT", contentInset, 0)
            contentFrame:SetPoint("TOPRIGHT", shellFrame, "TOPRIGHT", -contentInset, 0)
        end
        local bottomFrame = statusVisible and statusFrame or footerFrame
        contentFrame:SetPoint("BOTTOMLEFT", bottomFrame, "TOPLEFT", 0, 0)
        contentFrame:SetPoint("BOTTOMRIGHT", bottomFrame, "TOPRIGHT", 0, 0)
    end

    local statusVisible = options.showStatus == true
    UpdateContentBounds(statusVisible)
    if statusVisible then
        statusFrame:Show()
    else
        statusFrame:Hide()
    end

    local transparent = { 0, 0, 0, 0 }
    ApplyCompactDialogSurface({ frame = contentFrame }, "Body", {
        fill = isMessageDialog and transparent or options.bodyFill,
        topShade = isMessageDialog and transparent or nil,
        bottomShade = isMessageDialog and transparent or nil,
        border = isMessageDialog and transparent or options.bodyBorder,
    })
    ApplyCompactDialogSurface({ frame = footerFrame }, "Footer", {
        fill = options.footerFill or GetChromeColors().sectionFillStrong,
        border = options.footerBorder,
    })

    local header
    if headerFrame then
        header = CreateSmallWindowRegion(headerFrame, "List", {
            { "TOPLEFT", headerFrame, "TOPLEFT", 0, 0 },
            { "BOTTOMRIGHT", headerFrame, "BOTTOMRIGHT", 0, 0 },
        })
    end

    local body
    local message
    if isMessageDialog then
        message = CreateSmallWindowRegion(contentFrame, "List", {
            { "TOPLEFT", contentFrame, "TOPLEFT", 0, -8 },
            { "BOTTOMRIGHT", contentFrame, "BOTTOMRIGHT", 0, 0 },
        })
    elseif isPickerDialog and options.pickerScrollable ~= false then
        body = CreateSmallWindowScrollRegion(contentFrame, options.bodyLayout or "List", {
            { "TOPLEFT", contentFrame, "TOPLEFT", 0, -6 },
            { "BOTTOMRIGHT", contentFrame, "BOTTOMRIGHT", 0, 0 },
        })
    else
        body = CreateSmallWindowRegion(contentFrame, options.bodyLayout or "List", {
            { "TOPLEFT", contentFrame, "TOPLEFT", 9, -6 },
            { "BOTTOMRIGHT", contentFrame, "BOTTOMRIGHT", -9, 0 },
        })
    end
    local statusRegion = CreateSmallWindowRegion(statusFrame, "List", {
        { "TOPLEFT", statusFrame, "TOPLEFT", 0, 0 },
        { "BOTTOMRIGHT", statusFrame, "BOTTOMRIGHT", 0, 0 },
    })
    local footer = CreateSmallWindowRegion(footerFrame, "Flow", {
        { "TOPLEFT", footerFrame, "TOPLEFT", contentInset, 4 },
        { "BOTTOMRIGHT", footerFrame, "BOTTOMRIGHT", -contentInset, -4 },
    })

    local shell = {
        frame = shellFrame,
        header = header,
        body = body,
        message = message,
        status = statusRegion,
        footer = footer,
        contentWidth = math.max(1, (options.width or 420) - (contentInset * 2)),
    }

    function shell:SetStatusVisible(visible)
        visible = visible == true
        if statusVisible == visible then
            return
        end
        statusVisible = visible
        if statusVisible then
            statusFrame:Show()
        else
            statusFrame:Hide()
        end
        UpdateContentBounds(statusVisible)
    end

    function shell:Release()
        for _, region in ipairs({ self.header, self.body, self.message, self.status, self.footer }) do
            if region then
                AceGUI:Release(region)
            end
        end
        self.frame:Hide()
    end

    window.frame._fpCompactFormShell = shell

    return shell
end

local function CalculateCompactDialogHeight(options, isPickerDialog)
    local contentHeight
    if isPickerDialog then
        contentHeight = options.pickerContentHeight
    elseif options.mode == "message" or options.showBody == false or options.bodyHeight == 0 then
        contentHeight = options.messageContentHeight
    else
        contentHeight = options.formContentHeight
    end

    if type(contentHeight) ~= "number" then
        return options.height or (isPickerDialog and 0 or 216)
    end

    local isMessageDialog = options.mode == "message" or options.showBody == false or options.bodyHeight == 0
    local headerHeight = not isMessageDialog and type(options.description) == "string" and options.description ~= "" and (options.descriptionHeight or 32) or 0
    local footerHeight = options.footerHeight or 38
    local statusHeight = (options.showStatus == true or options.reserveStatusSpace == true) and (options.statusHeight or 22) or 0
    local contentTopPadding = isMessageDialog and 8 or 6
    -- AceGUI Window reserves 57 px around its content frame.
    local calculatedHeight = 57 + headerHeight + contentHeight + footerHeight + statusHeight + contentTopPadding
    return math.max(options.height or 0, calculatedHeight)
end

function FormWidgets.CreateCompactFormDialog(options)
    options = options or {}

    local window = AceGUI:Create("Window")
    local width = options.width or 420
    local isPickerDialog = options.mode == "picker"
    local height = CalculateCompactDialogHeight(options, isPickerDialog)

    window:SetTitle(options.title or "")
    window:SetLayout("Fill")
    window:SetWidth(width)
    window:SetHeight(height)
    window:EnableResize(false)

    if window.frame then
        window.frame:SetClampedToScreen(true)
        window.frame:SetFrameStrata(options.strata or "FULLSCREEN_DIALOG")
    end

    FormWidgets.ApplyWindowChrome(window)
    ApplyCompactDialogWindowChrome(window)
    FormWidgets.EnsureStandardWindowCloseButton(window)
    EnableCompactDialogEscapeClose(window)

    local shell = CreateCompactFormShell(window, options)
    local isMessageDialog = options.mode == "message" or options.showBody == false or options.bodyHeight == 0
    local description
    if shell.header then
        description = AceGUI:Create("Label")
        description:SetText(options.description)
        description:SetFullWidth(true)
        description:SetHeight(options.descriptionTextHeight or 24)
        if FormWidgets.ApplyTextStyle then
            FormWidgets.ApplyTextStyle(description.label, "help", 11, 1)
        end
        shell.header:AddChild(description)
    elseif shell.message then
        description = FormWidgets.CreateBodyText(options.description or "", "label", options.messageTextSize or 12, nil, shell.contentWidth, false)
        shell.message:AddChild(description)
        if type(options.messageHint) == "string" and options.messageHint ~= "" then
            local hint = FormWidgets.CreateBodyText(options.messageHint, "help", options.messageHintTextSize or 11, nil, shell.contentWidth, false)
            shell.message:AddChild(hint)
        end
    end

    if shell.body and options.mode ~= "picker" and options.addBodySpacer ~= false then
        AddCompactDialogSpacer(shell.body, 6)
    end

    local status = AceGUI:Create("Label")
    status:SetText(" ")
    status:SetFullWidth(true)
    status:SetHeight(options.statusTextHeight or 16)
    if FormWidgets.ApplyTextStyle then
        FormWidgets.ApplyTextStyle(status.label, "help", 10, 1)
    end
    shell.status:AddChild(status)

    local dialog = {
        window = window,
        root = shell,
        description = description,
        bodyShell = shell.body and { frame = shell.body.frame } or nil,
        body = shell.body,
        status = status,
        footerShell = { frame = shell.footer.frame },
        footer = shell.footer,
        contentWidth = shell.contentWidth,
        shell = shell,
        isMessageDialog = isMessageDialog,
    }

    function dialog:SetStatus(message)
        local hasMessage = type(message) == "string" and message ~= ""
        self.status:SetText(hasMessage and message or " ")
        if self.shell and self.shell.SetStatusVisible then
            self.shell:SetStatusVisible(hasMessage or options.showStatus == true)
        end
        if self.shell and self.shell.status and self.shell.status.DoLayout then
            self.shell.status:DoLayout()
        end
    end

    function dialog:SetActions(actions)
        actions = actions or {}
        self.footer:ReleaseChildren()
        self.primaryButton = nil
        self.secondaryButton = nil
        self.cancelButton = nil

        local primary = actions.primary
        local secondary = actions.secondary
        local cancel = actions.cancel
        local actionButtons = {}

        local function AddAction(key, action, defaultRole, defaultWidth)
            if not action then
                return
            end

            table.insert(actionButtons, {
                key = key,
                action = action,
                role = action.role or defaultRole,
                width = math.max(action.width or defaultWidth, action.minWidth or 0),
            })
        end

        AddAction("primary", primary, "primary_action", 120)
        AddAction("secondary", secondary, "utility", 110)
        AddAction("cancel", cancel, "utility", 110)

        local measuredFooterWidth = self.footer.frame:GetWidth()
        local footerWidth = actions.footerWidth or (measuredFooterWidth and measuredFooterWidth > 0 and measuredFooterWidth) or self.contentWidth or 388
        local gap = actions.gap or 8
        local groupWidth = 0
        for index, entry in ipairs(actionButtons) do
            groupWidth = groupWidth + entry.width
            if index > 1 then
                groupWidth = groupWidth + gap
            end
        end

        for index, entry in ipairs(actionButtons) do
            local button = FormWidgets.CreateActionButton(entry.action.text or "", entry.role, entry.width, false)
            FormWidgets.ApplyModalActionButtonVisual(button, entry.role)
            button:SetCallback("OnClick", function()
                if entry.action.onClick then
                    entry.action.onClick(self)
                end
            end)
            self.footer:AddChild(button)
            entry.button = button

            if entry.key == "primary" then
                self.primaryButton = button
            elseif entry.key == "secondary" then
                self.secondaryButton = button
            elseif entry.key == "cancel" then
                self.cancelButton = button
            end
        end

        if self.footer.DoLayout then
            self.footer:DoLayout()
        end

        local groupStart = 0
        if #actionButtons == 1 then
            groupStart = math.max(0, math.floor((footerWidth - groupWidth) / 2))
        elseif #actionButtons > 1 then
            groupStart = math.max(0, footerWidth - groupWidth)
        end

        local actionX = groupStart
        for _, entry in ipairs(actionButtons) do
            local frame = entry.button and entry.button.frame or nil
            if frame then
                frame:ClearAllPoints()
                -- LEFT-to-LEFT anchors use the vertical midpoint of the footer.
                frame:SetPoint("LEFT", self.footer.frame, "LEFT", actionX, 0)
            end
            actionX = actionX + entry.width + gap
        end
    end

    function dialog:Show()
        FormWidgets.FocusWindow(self.window, { centerIfHidden = true, strata = options.strata or "FULLSCREEN_DIALOG" })
    end

    function dialog:Close()
        if self.window and self.window.Hide then
            self.window:Hide()
        end
    end

    return dialog
end

function FormWidgets.ApplySidebarChrome(window)
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

    if not frame._fpSidebarPanelFill then
        frame._fpSidebarPanelFill = frame:CreateTexture(nil, "ARTWORK")
        frame._fpSidebarPanelFill:SetPoint("TOPLEFT", frame, "TOPLEFT", 12, -12)
        frame._fpSidebarPanelFill:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -12, 12)
    end
    frame._fpSidebarPanelFill:SetColorTexture(unpack(chromeColors.panelBackground or {}))

    if not frame._fpSidebarPanelHeaderFill then
        frame._fpSidebarPanelHeaderFill = frame:CreateTexture(nil, "ARTWORK")
        frame._fpSidebarPanelHeaderFill:SetPoint("TOPLEFT", frame, "TOPLEFT", 12, -12)
        frame._fpSidebarPanelHeaderFill:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -12, -12)
        frame._fpSidebarPanelHeaderFill:SetHeight(26)
    end
    frame._fpSidebarPanelHeaderFill:SetColorTexture(unpack(chromeColors.panelHeader or {}))

    if not frame._fpSidebarPanelTopShade then
        frame._fpSidebarPanelTopShade = frame:CreateTexture(nil, "ARTWORK")
        frame._fpSidebarPanelTopShade:SetPoint("TOPLEFT", frame, "TOPLEFT", 13, -13)
        frame._fpSidebarPanelTopShade:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -13, -13)
        frame._fpSidebarPanelTopShade:SetHeight(1)
    end
    frame._fpSidebarPanelTopShade:SetColorTexture(unpack(chromeColors.panelTopShade or {}))

    if not frame._fpSidebarPanelBottomShade then
        frame._fpSidebarPanelBottomShade = frame:CreateTexture(nil, "ARTWORK")
        frame._fpSidebarPanelBottomShade:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 13, 13)
        frame._fpSidebarPanelBottomShade:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -13, 13)
        frame._fpSidebarPanelBottomShade:SetHeight(1)
    end
    frame._fpSidebarPanelBottomShade:SetColorTexture(unpack(chromeColors.panelBottomShade or {}))

    local function EnsureBorder(name)
        if not frame[name] then
            frame[name] = frame:CreateTexture(nil, "BORDER")
        end
        frame[name]:SetColorTexture(unpack(chromeColors.panelBorder or {}))
        frame[name]:Show()
    end

    EnsureBorder("_fpSidebarPanelBorderTop")
    frame._fpSidebarPanelBorderTop:SetPoint("TOPLEFT", frame, "TOPLEFT", 12, -12)
    frame._fpSidebarPanelBorderTop:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -12, -12)
    frame._fpSidebarPanelBorderTop:SetHeight(1)

    EnsureBorder("_fpSidebarPanelBorderBottom")
    frame._fpSidebarPanelBorderBottom:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 12, 12)
    frame._fpSidebarPanelBorderBottom:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -12, 12)
    frame._fpSidebarPanelBorderBottom:SetHeight(1)

    EnsureBorder("_fpSidebarPanelBorderLeft")
    frame._fpSidebarPanelBorderLeft:SetPoint("TOPLEFT", frame, "TOPLEFT", 12, -12)
    frame._fpSidebarPanelBorderLeft:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 12, 12)
    frame._fpSidebarPanelBorderLeft:SetWidth(1)

    EnsureBorder("_fpSidebarPanelBorderRight")
    frame._fpSidebarPanelBorderRight:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -12, -12)
    frame._fpSidebarPanelBorderRight:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -12, 12)
    frame._fpSidebarPanelBorderRight:SetWidth(1)

    local function EnsureInnerBorder(name)
        if not frame[name] then
            frame[name] = frame:CreateTexture(nil, "BORDER")
        end
        frame[name]:SetColorTexture(unpack(chromeColors.panelInnerBorder or chromeColors.sectionBorder or {}))
        frame[name]:Show()
    end

    EnsureInnerBorder("_fpSidebarPanelInnerTop")
    frame._fpSidebarPanelInnerTop:SetPoint("TOPLEFT", frame, "TOPLEFT", 13, -13)
    frame._fpSidebarPanelInnerTop:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -13, -13)
    frame._fpSidebarPanelInnerTop:SetHeight(1)

    EnsureInnerBorder("_fpSidebarPanelInnerBottom")
    frame._fpSidebarPanelInnerBottom:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 13, 13)
    frame._fpSidebarPanelInnerBottom:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -13, 13)
    frame._fpSidebarPanelInnerBottom:SetHeight(1)

    EnsureInnerBorder("_fpSidebarPanelInnerLeft")
    frame._fpSidebarPanelInnerLeft:SetPoint("TOPLEFT", frame, "TOPLEFT", 13, -13)
    frame._fpSidebarPanelInnerLeft:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 13, 13)
    frame._fpSidebarPanelInnerLeft:SetWidth(1)

    EnsureInnerBorder("_fpSidebarPanelInnerRight")
    frame._fpSidebarPanelInnerRight:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -13, -13)
    frame._fpSidebarPanelInnerRight:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -13, 13)
    frame._fpSidebarPanelInnerRight:SetWidth(1)

    if content then
        content:ClearAllPoints()
        content:SetPoint("TOPLEFT", frame, "TOPLEFT", 12, -12)
        content:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -12, 12)

        if not content._fpSidebarAccent then
            content._fpSidebarAccent = content:CreateTexture(nil, "BORDER")
            content._fpSidebarAccent:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -2)
            content._fpSidebarAccent:SetPoint("TOPRIGHT", content, "TOPRIGHT", 0, -2)
            content._fpSidebarAccent:SetHeight(1)
        end
        content._fpSidebarAccent:SetColorTexture(unpack(chromeColors.accent or {}))
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
