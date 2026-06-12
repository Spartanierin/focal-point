local _, ns = ...

ns.GUI = ns.GUI or {}

local Skins = ns.GUI.Skins or {}
ns.GUI.Skins = Skins

Skins.Builtin = Skins.Builtin or {}

local DEFAULT_BUTTON_TEXTURE = "Interface\\AddOns\\FocalPoint\\Media\\Textures\\BetterBlizzard.blp"

Skins.Builtin.default = Skins.Builtin.default or {
    id = "default",
    label = "Focal Point",
    fonts = {
        default = STANDARD_TEXT_FONT,
    },
    textures = {
        editorButtonBackground = DEFAULT_BUTTON_TEXTURE,
        editorButtonTexCoord = { 0.05, 0.95, 0.08, 0.92 },
    },
    textColors = {
        sectionHeader = {
            hex = "E7C44A",
            wow = "|cffE7C44A",
            r = 0.906,
            g = 0.769,
            b = 0.290,
        },
        label = {
            hex = "F2E6C9",
            wow = "|cffF2E6C9",
            r = 0.949,
            g = 0.902,
            b = 0.788,
        },
        help = {
            hex = "B7AA8A",
            wow = "|cffB7AA8A",
            r = 0.718,
            g = 0.667,
            b = 0.541,
        },
        highlight = {
            hex = "8FC7FF",
            wow = "|cff8FC7FF",
            r = 0.561,
            g = 0.780,
            b = 1.000,
        },
        disabled = {
            hex = "7E7564",
            wow = "|cff7E7564",
            r = 0.494,
            g = 0.459,
            b = 0.392,
        },
    },
    formPalette = {
        Chrome = {
            panelBackground = { 0.06, 0.07, 0.09, 0.94 },
            panelBorder = { 0.42, 0.38, 0.26, 0.92 },
            panelInnerBorder = { 0.18, 0.20, 0.24, 0.92 },
            panelHeader = { 0.11, 0.12, 0.15, 0.82 },
            panelTopShade = { 1.00, 1.00, 1.00, 0.05 },
            panelBottomShade = { 0.00, 0.00, 0.00, 0.42 },
            fieldBackground = { 0.10, 0.11, 0.14, 0.96 },
            fieldBorder = { 0.31, 0.34, 0.39, 0.95 },
            fieldBorderFocus = { 0.74, 0.61, 0.26, 0.95 },
            fieldInsetTop = { 1.00, 1.00, 1.00, 0.04 },
            fieldInsetBottom = { 0.00, 0.00, 0.00, 0.28 },
            accent = { 0.83, 0.70, 0.30, 0.22 },
            sectionBorder = { 0.30, 0.33, 0.38, 0.56 },
            sectionFill = { 0.09, 0.10, 0.12, 0.52 },
            sectionFillStrong = { 0.11, 0.12, 0.15, 0.66 },
            sectionInsetTop = { 1.00, 1.00, 1.00, 0.035 },
            sectionInsetBottom = { 0.00, 0.00, 0.00, 0.26 },
            sectionAccent = { 0.83, 0.70, 0.30, 0.26 },
            headerAccent = { 0.90, 0.78, 0.34, 0.42 },
            workspaceDivider = { 0.34, 0.37, 0.42, 0.24 },
        },
        ItemColors = {
            pageIntro = { 0.78, 0.75, 0.69, 1.00 },
            description = { 0.68, 0.70, 0.75 },
            sectionDescription = { 0.65, 0.67, 0.72, 1.00 },
            hint = { 0.70, 0.73, 0.78 },
            statusMuted = { 0.58, 0.61, 0.66, 1.00 },
            footerHint = { 0.62, 0.65, 0.70 },
            footerMuted = { 0.52, 0.55, 0.60, 1.00 },
            value = { 0.93, 0.90, 0.80 },
            valueEmphasis = { 0.97, 0.95, 0.91, 1.00 },
            checkbox = { 0.94, 0.90, 0.82, 1.00 },
            checkboxDisabled = { 0.50, 0.50, 0.50, 1.00 },
        },
    },
    editorButtonVisuals = {
        states = {
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
        },
        closeStates = {
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
        },
    },
}

local activeSkinId = Skins.activeSkinId or "default"
Skins.activeSkinId = activeSkinId

function Skins.Register(id, skin)
    if type(id) ~= "string" or id == "" or type(skin) ~= "table" then
        return false
    end

    skin.id = skin.id or id
    Skins.Builtin[id] = skin
    return true
end

function Skins.SetActiveSkin(id)
    if type(id) ~= "string" or not Skins.Builtin[id] then
        return false
    end

    activeSkinId = id
    Skins.activeSkinId = id
    return true
end

function Skins.GetActiveSkinId()
    return activeSkinId
end

function Skins.GetActiveSkin()
    return Skins.Builtin[activeSkinId] or Skins.Builtin.default
end

function Skins.GetFormPalette(fallback)
    local skin = Skins.GetActiveSkin()
    return (skin and skin.formPalette) or fallback or {}
end

function Skins.GetTextColor(role, fallback)
    local skin = Skins.GetActiveSkin()
    local colors = skin and skin.textColors
    return (colors and colors[role]) or fallback
end

function Skins.GetDefaultFont(fallback)
    local skin = Skins.GetActiveSkin()
    return (skin and skin.fonts and skin.fonts.default) or fallback or STANDARD_TEXT_FONT
end

function Skins.GetEditorButtonVisuals(fallback)
    local skin = Skins.GetActiveSkin()
    local visuals = skin and skin.editorButtonVisuals or nil
    local textures = skin and skin.textures or nil

    return {
        states = (visuals and visuals.states) or (fallback and fallback.states),
        closeStates = (visuals and visuals.closeStates) or (fallback and fallback.closeStates),
        texture = (textures and textures.editorButtonBackground) or (fallback and fallback.texture),
        texCoord = (textures and textures.editorButtonTexCoord) or (fallback and fallback.texCoord),
    }
end

return Skins
