local addonName, ns = ...

ns.GUI = ns.GUI or {}
ns.GUI.Editor = ns.GUI.Editor or {}

local EditorSidebarThemeHelpers = {}
ns.GUI.Editor.EditorSidebarThemeHelpers = EditorSidebarThemeHelpers

local L = ns.L or {}

local THEME_ORDER = {
    "default",
    "classic",
    "minimal",
    "modern",
}

local FP_BUTTON_BG_TEXTURE = "Interface\\AddOns\\FocalPoint\\Media\\Textures\\BetterBlizzard.blp"
local FP_BUTTON_BG_TEX_COORD = { 0.05, 0.95, 0.08, 0.92 }

local function SetTextureColor(texture, color)
    if texture and texture.SetVertexColor and color then
        texture:SetVertexColor(color[1] or 1, color[2] or 1, color[3] or 1, color[4] or 1)
    end
end

local FP_BUTTON_STATE_VISUALS = {
    disabled = {
        fill = { 0.08, 0.09, 0.11, 0.92 },
        border = { 0.18, 0.20, 0.23, 0.86 },
        accent = { 0.28, 0.30, 0.34, 0.08 },
        text = { 0.60, 0.63, 0.67, 1.00 },
    },
    normal = {
        fill = { 0.12, 0.15, 0.19, 0.96 },
        border = { 0.29, 0.34, 0.41, 0.90 },
        accent = { 0.46, 0.54, 0.64, 0.10 },
        text = { 0.92, 0.95, 0.99, 1.00 },
    },
    hover = {
        fill = { 0.13, 0.16, 0.20, 0.96 },
        border = { 0.49, 0.41, 0.28, 0.94 },
        accent = { 0.70, 0.60, 0.40, 0.24 },
        text = { 0.94, 0.97, 1.00, 1.00 },
    },
    pressed = {
        fill = { 0.10, 0.13, 0.17, 0.96 },
        border = { 0.56, 0.46, 0.31, 0.95 },
        accent = { 0.74, 0.64, 0.44, 0.26 },
        text = { 0.92, 0.95, 0.99, 1.00 },
    },
    active = {
        fill = { 0.12, 0.15, 0.19, 0.96 },
        border = { 0.44, 0.36, 0.24, 0.93 },
        accent = { 0.62, 0.52, 0.36, 0.24 },
        text = { 0.95, 0.92, 0.84, 1.00 },
    },
}

local FP_BUTTON_ROLE_PRESETS = {
    active = {
        selected = true,
    },
    secondary = {},
    primary_action = {
        selected = true,
        textOverride = { 0.95, 0.92, 0.84, 1.00 },
    },
    utility = {},
    danger = {
        tint = { 0.19, -0.06, -0.12 },
    },
    close = {
        closeOverride = true,
    },
    quiet_utility = {
        closeOverride = true,
    },
}

local FP_CLOSE_STATE_VISUALS = {
    normal = {
        fill = { 0.12, 0.15, 0.19, 0.96 },
        border = { 0.24, 0.33, 0.45, 0.91 },
        accent = { 0.42, 0.55, 0.72, 0.16 },
        text = { 0.92, 0.95, 0.99, 1.00 },
    },
    hover = {
        fill = { 0.13, 0.16, 0.20, 0.96 },
        border = { 0.31, 0.43, 0.58, 0.93 },
        accent = { 0.51, 0.67, 0.88, 0.22 },
        text = { 0.94, 0.97, 1.00, 1.00 },
    },
    pressed = {
        fill = { 0.10, 0.13, 0.17, 0.96 },
        border = { 0.36, 0.50, 0.67, 0.94 },
        accent = { 0.56, 0.72, 0.90, 0.24 },
        text = { 0.92, 0.96, 1.00, 1.00 },
    },
    active = {
        fill = { 0.12, 0.15, 0.19, 0.96 },
        border = { 0.29, 0.40, 0.54, 0.93 },
        accent = { 0.46, 0.62, 0.82, 0.22 },
        text = { 0.93, 0.96, 1.00, 1.00 },
    },
}

-- Global semantic button roles.
-- These roles describe intent; visual mappings may differ by context.
-- danger: destructive/risky/irreversible actions only.
-- close: must use utility (or quiet utility in future), never danger by default.
local BUTTON_VISUAL_ROLE = {
    ACTIVE = "active",
    SECONDARY = "secondary",
    PRIMARY_ACTION = "primary_action",
    UTILITY = "utility",
    QUIET_UTILITY = "quiet_utility",
    DANGER = "danger",
}
ns.GUI.ButtonVisualRole = ns.GUI.ButtonVisualRole or BUTTON_VISUAL_ROLE
EditorSidebarThemeHelpers.ButtonVisualRole = ns.GUI.ButtonVisualRole
EditorSidebarThemeHelpers.SIDEBAR_VISUAL_ROLE = ns.GUI.ButtonVisualRole

local SIDEBAR_ROLE_TO_VARIANT = {
    [BUTTON_VISUAL_ROLE.ACTIVE] = "active",
    [BUTTON_VISUAL_ROLE.SECONDARY] = "secondary",
    [BUTTON_VISUAL_ROLE.PRIMARY_ACTION] = "primary_action",
    [BUTTON_VISUAL_ROLE.UTILITY] = "utility",
    [BUTTON_VISUAL_ROLE.QUIET_UTILITY] = "close",
    [BUTTON_VISUAL_ROLE.DANGER] = "danger",
}

local SIDEBAR_LAYER_KEYS = {
    bg = "__fpSidebarVisualBg",
    texture = "__fpSidebarVisualTexture",
    border = "__fpSidebarVisualBorder",
    accent = "__fpSidebarSelectedAccent",
}

local function EnsureFPButtonVisualLayers(button, layerKeys)
    if not button or not button.frame then
        return nil
    end

    local keys = layerKeys or SIDEBAR_LAYER_KEYS
    local frame = button.frame

    if not button[keys.bg] then
        button[keys.bg] = frame:CreateTexture(nil, "BACKGROUND", nil, 2)
        button[keys.bg]:SetPoint("TOPLEFT", frame, "TOPLEFT", 2, -2)
        button[keys.bg]:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -2, 2)
    end

    if keys.texture and not button[keys.texture] then
        button[keys.texture] = frame:CreateTexture(nil, "ARTWORK", nil, 3)
        button[keys.texture]:SetPoint("TOPLEFT", frame, "TOPLEFT", 2, -2)
        button[keys.texture]:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -2, 2)
    end

    if not button[keys.border] then
        button[keys.border] = frame:CreateTexture(nil, "BORDER", nil, 4)
        button[keys.border]:SetPoint("TOPLEFT", frame, "TOPLEFT", 1, -1)
        button[keys.border]:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -1, 1)
    end

    if not button[keys.accent] then
        button[keys.accent] = frame:CreateTexture(nil, "ARTWORK", nil, 5)
        button[keys.accent]:SetPoint("TOPLEFT", frame, "TOPLEFT", 2, -2)
        button[keys.accent]:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -2, -2)
        button[keys.accent]:SetHeight(1)
    end

    return frame
end

local function EnsureFPButtonHoverHook(button, hoverOptions)
    if not button or not button.frame or type(hoverOptions) ~= "table" or hoverOptions.enabled ~= true then
        return
    end

    local hookKey = hoverOptions.hookKey or "__fpButtonHoverHooked"
    local stateKey = hoverOptions.stateKey or "__fpButtonHovered"
    local pressedKey = hoverOptions.pressedKey or "__fpButtonPressed"
    if button[hookKey] then
        return
    end

    local frame = button.frame
    if not frame.HookScript then
        return
    end

    local onReapply = hoverOptions.onReapply

    frame:HookScript("OnEnter", function()
        button[stateKey] = true
        if type(onReapply) == "function" then
            onReapply(button)
        end
    end)

    frame:HookScript("OnLeave", function()
        button[stateKey] = false
        button[pressedKey] = false
        if type(onReapply) == "function" then
            onReapply(button)
        end
    end)

    frame:HookScript("OnMouseDown", function()
        button[pressedKey] = true
        if type(onReapply) == "function" then
            onReapply(button)
        end
    end)

    frame:HookScript("OnMouseUp", function()
        button[pressedKey] = false
        if type(onReapply) == "function" then
            onReapply(button)
        end
    end)

    frame:HookScript("OnHide", function()
        button[stateKey] = false
        button[pressedKey] = false
        if type(onReapply) == "function" then
            onReapply(button)
        end
    end)

    button[hookKey] = true
end

local function Clamp01(value)
    if value == nil then
        return 0
    end
    if value < 0 then
        return 0
    end
    if value > 1 then
        return 1
    end
    return value
end

local function ApplyTint(color, tint)
    if type(color) ~= "table" then
        return color
    end
    if type(tint) ~= "table" then
        return color
    end
    return {
        Clamp01((color[1] or 0) + (tint[1] or 0)),
        Clamp01((color[2] or 0) + (tint[2] or 0)),
        Clamp01((color[3] or 0) + (tint[3] or 0)),
        Clamp01(color[4] or 1),
    }
end

local function GetEditorButtonVisuals()
    local skins = ns.GUI and ns.GUI.Skins or nil
    local fallback = {
        states = FP_BUTTON_STATE_VISUALS,
        closeStates = FP_CLOSE_STATE_VISUALS,
        texture = FP_BUTTON_BG_TEXTURE,
        texCoord = FP_BUTTON_BG_TEX_COORD,
    }
    if skins and skins.GetEditorButtonVisuals then
        return skins.GetEditorButtonVisuals(fallback) or fallback
    end
    return fallback
end

local function ResolveVisualState(isDisabled, isPressed, isHovered, isSelected, preferSelectedWhenDisabled)
    if isDisabled and not (isSelected and preferSelectedWhenDisabled) then
        return "disabled"
    end
    if isPressed and isHovered then
        return "pressed"
    end
    if isHovered then
        return "hover"
    end
    if isSelected then
        return "active"
    end
    return "normal"
end

local function ResolveStateVisual(rolePresetKey, stateName, editorButtonVisuals)
    local rolePreset = FP_BUTTON_ROLE_PRESETS[rolePresetKey] or {}
    editorButtonVisuals = editorButtonVisuals or GetEditorButtonVisuals()
    local states = editorButtonVisuals.states or FP_BUTTON_STATE_VISUALS
    local closeStates = editorButtonVisuals.closeStates or FP_CLOSE_STATE_VISUALS
    local closeState = closeStates[stateName]
    local base = (rolePreset.closeOverride and closeState) or states[stateName] or states.normal
    local visual = {
        fill = base.fill,
        border = base.border,
        accent = base.accent,
        text = base.text,
    }

    if rolePreset.tint and stateName ~= "disabled" then
        visual.border = ApplyTint(visual.border, rolePreset.tint)
        visual.accent = ApplyTint(visual.accent, rolePreset.tint)
    end

    if rolePreset.textOverride and stateName ~= "disabled" then
        visual.text = rolePreset.textOverride
    end

    if stateName == "disabled" then
        visual.text = states.disabled.text
    end

    return visual
end

local function GetColorSignature(color)
    if type(color) ~= "table" then
        return "-"
    end
    return tostring(color[1]) .. "," .. tostring(color[2]) .. "," .. tostring(color[3]) .. "," .. tostring(color[4])
end

local function GetTexCoordSignature(texCoord)
    if type(texCoord) ~= "table" then
        return "-"
    end
    return tostring(texCoord[1]) .. "," .. tostring(texCoord[2]) .. "," .. tostring(texCoord[3]) .. "," .. tostring(texCoord[4])
end

local function BuildButtonVisualCacheKey(rolePresetKey, stateName, effectiveStyle, options, editorButtonVisuals, accentVisible)
    return table.concat({
        tostring(rolePresetKey),
        tostring(stateName),
        tostring(effectiveStyle and effectiveStyle.height),
        GetColorSignature(effectiveStyle and effectiveStyle.disabledText),
        GetColorSignature(effectiveStyle and effectiveStyle.fill),
        GetColorSignature(effectiveStyle and effectiveStyle.border),
        GetColorSignature(effectiveStyle and effectiveStyle.accent),
        GetColorSignature(effectiveStyle and effectiveStyle.text),
        tostring(options and options.selected == true),
        tostring(options and options.preferSelectedWhenDisabled == true),
        tostring(accentVisible == true),
        tostring(editorButtonVisuals and editorButtonVisuals.texture),
        GetTexCoordSignature(editorButtonVisuals and editorButtonVisuals.texCoord),
    }, "|")
end

local function NeutralizeTemplateTextures(frame)
    if not frame then
        return
    end

    local normal = frame.GetNormalTexture and frame:GetNormalTexture() or nil
    local pushed = frame.GetPushedTexture and frame:GetPushedTexture() or nil
    local highlight = frame.GetHighlightTexture and frame:GetHighlightTexture() or nil
    local disabled = frame.GetDisabledTexture and frame:GetDisabledTexture() or nil

    SetTextureColor(normal, { 1, 1, 1, 0 })
    SetTextureColor(pushed, { 1, 1, 1, 0 })
    SetTextureColor(highlight, { 1, 1, 1, 0 })
    SetTextureColor(disabled, { 1, 1, 1, 0 })

    if normal and normal.SetAlpha then normal:SetAlpha(0) end
    if pushed and pushed.SetAlpha then pushed:SetAlpha(0) end
    if highlight and highlight.SetAlpha then highlight:SetAlpha(0) end
    if disabled and disabled.SetAlpha then disabled:SetAlpha(0) end
end

local function ApplyColorTexture(texture, color, texturePath, texCoord)
    if not texture then
        return
    end
    local c = color or { 0, 0, 0, 0 }
    if texturePath and texture.SetTexture then
        texture:SetTexture(texturePath)
        if texCoord and texture.SetTexCoord then
            texture:SetTexCoord(
                texCoord[1] or 0,
                texCoord[2] or 1,
                texCoord[3] or 0,
                texCoord[4] or 1
            )
        end
        if texture.SetVertexColor then
            texture:SetVertexColor(c[1] or 0, c[2] or 0, c[3] or 0, c[4] or 0)
        end
        return
    end

    if texture.SetColorTexture then
        texture:SetColorTexture(c[1] or 0, c[2] or 0, c[3] or 0, c[4] or 0)
    end
end

function EditorSidebarThemeHelpers.ApplyFPButtonVisualCore(button, style, options)
    if not button or not style then
        return
    end

    local opts = options or {}
    local layerKeys = opts.layerKeys or SIDEBAR_LAYER_KEYS
    local hoverOptions = opts.hover
    local frame = EnsureFPButtonVisualLayers(button, layerKeys)
    if not frame then
        return
    end

    EnsureFPButtonHoverHook(button, hoverOptions)

    local isDisabled = button.disabled == true
    local hovered = false
    local pressed = false
    if type(hoverOptions) == "table" and hoverOptions.enabled == true then
        local stateKey = hoverOptions.stateKey or "__fpButtonHovered"
        local pressedKey = hoverOptions.pressedKey or "__fpButtonPressed"
        hovered = button[stateKey] == true
        pressed = button[pressedKey] == true
    end

    local rolePresetKey = opts.rolePreset or "secondary"
    local rolePreset = FP_BUTTON_ROLE_PRESETS[rolePresetKey] or {}
    local isSelected = opts.selected == true or rolePreset.selected == true
    local stateName = ResolveVisualState(isDisabled, pressed, hovered, isSelected, opts.preferSelectedWhenDisabled == true)
    local editorButtonVisuals = GetEditorButtonVisuals()
    local stateVisual = ResolveStateVisual(rolePresetKey, stateName, editorButtonVisuals)
    local states = editorButtonVisuals.states or FP_BUTTON_STATE_VISUALS

    local effectiveStyle = {
        height = style.height,
        disabledText = style.disabledText or states.disabled.text,
        fill = stateVisual.fill,
        border = stateVisual.border,
        accent = stateVisual.accent,
        text = stateVisual.text,
    }

    local accentVisible = opts.accentVisible == true or stateName == "active"
    local cacheKey = BuildButtonVisualCacheKey(rolePresetKey, stateName, effectiveStyle, opts, editorButtonVisuals, accentVisible)
    if button.__fpButtonVisualCacheKey == cacheKey then
        return
    end
    button.__fpButtonVisualCacheKey = cacheKey

    button:SetHeight(effectiveStyle.height or 22)
    NeutralizeTemplateTextures(frame)

    ApplyColorTexture(button[layerKeys.bg], effectiveStyle.fill)
    if layerKeys.texture then
        ApplyColorTexture(button[layerKeys.texture], { 0.03, 0.04, 0.05, 0.36 }, editorButtonVisuals.texture, editorButtonVisuals.texCoord)
    end
    ApplyColorTexture(button[layerKeys.border], effectiveStyle.border)
    ApplyColorTexture(button[layerKeys.accent], effectiveStyle.accent)

    local accent = button[layerKeys.accent]
    if accentVisible then
        if accent and accent.Show then
            accent:Show()
        end
    elseif accent and accent.Hide then
        accent:Hide()
    end

    local bg = button[layerKeys.bg]
    local bgTexture = layerKeys.texture and button[layerKeys.texture] or nil
    local border = button[layerKeys.border]
    if isDisabled then
        if bg and bg.SetVertexColor then
            bg:SetVertexColor(0.78, 0.78, 0.78, 0.84)
        end
        if bgTexture and bgTexture.SetVertexColor then
            bgTexture:SetVertexColor(0.78, 0.78, 0.78, 0.12)
        end
        if border and border.SetVertexColor then
            border:SetVertexColor(0.78, 0.78, 0.78, 0.82)
        end
    else
        if bg and bg.SetVertexColor then
            local fill = effectiveStyle.fill or { 1, 1, 1, 1 }
            bg:SetVertexColor(fill[1] or 1, fill[2] or 1, fill[3] or 1, fill[4] or 1)
        end
        if bgTexture and bgTexture.SetVertexColor then
            bgTexture:SetVertexColor(0.03, 0.04, 0.05, 0.36)
        end
        if border and border.SetVertexColor then
            border:SetVertexColor(1, 1, 1, 1)
        end
    end

    if button.text and button.text.SetTextColor then
        if button.text.SetDrawLayer then
            button.text:SetDrawLayer("OVERLAY", 1)
        end
        if button.text.GetFont and button.text.SetFont then
            local font, size = button.text:GetFont()
            if font then
                button.text:SetFont(font, size or 12, "")
            end
        end
        if button.text.SetShadowOffset then
            button.text:SetShadowOffset(1, -1)
        end
        if button.text.SetShadowColor then
            button.text:SetShadowColor(0, 0, 0, 0.98)
        end
        local textColor = effectiveStyle.text
        if isDisabled then
            textColor = states.disabled.text
        end
        if textColor then
            button.text:SetTextColor(textColor[1] or 1, textColor[2] or 1, textColor[3] or 1, textColor[4] or 1)
        else
            button.text:SetTextColor(0.89, 0.91, 0.94, 1)
        end
    end

    if frame.SetAlpha then
        frame:SetAlpha(1)
    end
end

local function ReapplySidebarVisualOnHover(button)
    if EditorSidebarThemeHelpers.ApplySidebarButtonVisual then
        EditorSidebarThemeHelpers.ApplySidebarButtonVisual(button, button.__fpSidebarLastRole or "secondary")
    end
end

function EditorSidebarThemeHelpers.ApplySidebarButtonVisual(button, variant)
    if not button then
        return
    end

    button.__fpSidebarLastRole = variant or "secondary"

    local visualRole = SIDEBAR_ROLE_TO_VARIANT[button.__fpSidebarLastRole] or "secondary"
    local editorButtonVisuals = GetEditorButtonVisuals()
    local states = editorButtonVisuals.states or FP_BUTTON_STATE_VISUALS
    local style = {
        height = (visualRole == "active" or visualRole == "primary_action") and 24 or 22,
        disabledText = states.disabled.text,
    }
    if EditorSidebarThemeHelpers.ApplyFPButtonVisualCore then
        EditorSidebarThemeHelpers.ApplyFPButtonVisualCore(button, style, {
            layerKeys = SIDEBAR_LAYER_KEYS,
            rolePreset = visualRole,
            selected = (visualRole == "active"),
            preferSelectedWhenDisabled = (visualRole == "active"),
            hover = {
                enabled = true,
                hookKey = "__fpSidebarHoverHooked",
                stateKey = "__fpSidebarHovered",
                pressedKey = "__fpSidebarPressed",
                onReapply = ReapplySidebarVisualOnHover,
            },
        })
    end
end

function EditorSidebarThemeHelpers.StyleSidebarButton(button, variant)
    EditorSidebarThemeHelpers.ApplySidebarButtonVisual(button, variant)
end

function EditorSidebarThemeHelpers.BuildThemeList(themes)
    local list = {}

    if type(themes) ~= "table" then
        return list
    end

    for _, themeId in ipairs(THEME_ORDER) do
        local theme = themes[themeId]
        if type(theme) == "table" then
            list[themeId] = (theme.labelKey and L[theme.labelKey]) or theme.id or themeId
        end
    end

    for themeId, theme in pairs(themes) do
        if not list[themeId] and type(theme) == "table" then
            list[themeId] = (theme.labelKey and L[theme.labelKey]) or theme.id or themeId
        end
    end

    return list
end

function EditorSidebarThemeHelpers.GetFirstThemeId(themeList)
    for _, themeId in ipairs(THEME_ORDER) do
        if themeList[themeId] then
            return themeId
        end
    end

    for themeId in pairs(themeList) do
        return themeId
    end

    return nil
end

return EditorSidebarThemeHelpers
