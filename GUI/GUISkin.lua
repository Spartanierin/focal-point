local _, ns = ...

ns.GUI = ns.GUI or {}

local Skins = ns.GUI.Skins or {}
ns.GUI.Skins = Skins

Skins.Builtin = Skins.Builtin or {}

local DEFAULT_BUTTON_TEXTURE = "Interface\\AddOns\\FocalPoint\\Media\\Textures\\shadow1.png"

local function NavigatorColor(color, alpha)
    return { color[1], color[2], color[3], alpha or color[4] }
end

local NAVIGATOR = {
    mahogany = { 0.251, 0.125, 0.114, 0.97 },
    darkWalnut = { 0.106, 0.090, 0.078, 0.92 },
    blackenedMetal = { 0.090, 0.098, 0.102, 1.00 },
    agedBrass = { 0.690, 0.541, 0.243, 1.00 },
    focusBrass = { 0.816, 0.667, 0.322, 1.00 },
    warmText = { 0.906, 0.875, 0.788, 1.00 },
    secondary = { 0.651, 0.616, 0.541, 1.00 },
}

Skins.Builtin.default = Skins.Builtin.default or {
    id = "default",
    label = "Focal Point",
    brand = {
        white = {
            hex = "FFFFFF",
            wow = "|cffFFFFFF",
            r = 1.000,
            g = 1.000,
            b = 1.000,
        },
        orange = {
            hex = "E8C166",
            wow = "|cffE8C166",
            r = 0.910,
            g = 0.757,
            b = 0.400,
        },
        orangeSoft = { 0.910, 0.757, 0.400, 0.22 },
        orangeMedium = { 0.910, 0.757, 0.400, 0.38 },
        orangeStrong = { 0.910, 0.757, 0.400, 0.85 },
        titleFocal = {
            r = 0.8274510502815247,
            g = 0.6784313917160034,
            b = 0.4078431725502014,
        },
        titlePoint = {
            hex = "EA7500",
            wow = "|cffEA7500",
            r = 0.918,
            g = 0.459,
            b = 0.000,
        },
    },
    visual = {
        -- Global semantic roles.
        BrandGold = { 0.910, 0.757, 0.400, 1.00 },
        TextSecondary = { 0.70, 0.68, 0.62, 1.00 },
        SurfaceExplorer = { 0.045, 0.040, 0.035, 0.94 },
        DestructiveRed = { 0.48, 0.18, 0.18, 0.95 },
        -- Shared base primitives; controls may tune local state intensity.
        TextPrimary = { 0.949, 0.902, 0.788, 1.00 },
        TextDisabled = { 0.494, 0.459, 0.392, 1.00 },
        SurfaceBase = { 0.055, 0.048, 0.042, 0.96 },
        SurfaceInset = { 0.085, 0.075, 0.065, 0.98 },
        BorderSoft = { 0.29, 0.25, 0.19, 0.62 },
    },
    fonts = {
        default = STANDARD_TEXT_FONT,
    },
    textures = {
        editorButtonBackground = DEFAULT_BUTTON_TEXTURE,
        editorButtonTexCoord = { 0, 1, 0, 1 },
    },
    textColors = {
        sectionHeader = {
            hex = "E8C166",
            wow = "|cffE8C166",
            r = 0.910,
            g = 0.757,
            b = 0.400,
        },
        strongHeading = {
            hex = "F2D05C",
            wow = "|cffF2D05C",
            r = 0.949,
            g = 0.816,
            b = 0.361,
        },
        identity = {
            hex = "F7F2E8",
            wow = "|cffF7F2E8",
            r = 0.969,
            g = 0.949,
            b = 0.910,
        },
        contextHighlight = {
            hex = "F2D05C",
            wow = "|cffF2D05C",
            r = 0.949,
            g = 0.816,
            b = 0.361,
        },
        label = {
            hex = "F2E6C9",
            wow = "|cffF2E6C9",
            r = 0.949,
            g = 0.902,
            b = 0.788,
        },
        value = {
            hex = "EDE6CC",
            wow = "|cffEDE6CC",
            r = 0.929,
            g = 0.902,
            b = 0.800,
        },
        help = {
            hex = "B8AD95",
            wow = "|cffB8AD95",
            r = 0.722,
            g = 0.678,
            b = 0.584,
        },
        statusError = {
            hex = "C96B62",
            wow = "|cffC96B62",
            r = 0.788,
            g = 0.420,
            b = 0.384,
        },
        statusSuccess = {
            hex = "70A86A",
            wow = "|cff70A86A",
            r = 0.439,
            g = 0.659,
            b = 0.416,
        },
        highlight = {
            hex = "8FC7FF",
            wow = "|cff8FC7FF",
            r = 0.561,
            g = 0.780,
            b = 1.000,
        },
        parchmentSectionHeader = {
            hex = "573B1F",
            wow = "|cff573B1F",
            r = 0.34,
            g = 0.23,
            b = 0.12,
        },
        parchmentSecondary = {
            hex = "664D2B",
            wow = "|cff664D2B",
            r = 0.40,
            g = 0.30,
            b = 0.17,
        },
        parchmentMuted = {
            hex = "7A613D",
            wow = "|cff7A613D",
            r = 0.48,
            g = 0.38,
            b = 0.24,
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
        Navigator = {
            navigatorMahogany = NAVIGATOR.mahogany,
            navigatorDarkWalnut = NAVIGATOR.darkWalnut,
            navigatorBlackenedMetal = NAVIGATOR.blackenedMetal,
            navigatorAgedBrass = NAVIGATOR.agedBrass,
            navigatorFocusBrass = NAVIGATOR.focusBrass,
            navigatorWarmText = NAVIGATOR.warmText,
            navigatorSecondary = NAVIGATOR.secondary,
        },
        Chrome = {
            navigatorShellSurface = {
                material = "texture",
                textureId = "fp:texture:fp-forged-metal-128x128",
                tint = { 0.3137255012989044, 0.3137255012989044, 0.3137255012989044, 0.92 },
            },
            inspectorSectionSurface = {
                material = "texture",
                textureId = "fp:texture:fp-mahagony-128x128",
                tint = { 0.2117647230625153, 0.2117647230625153, 0.2117647230625153, 0.9 },
                topShade = { 0.9490196704864502, 0.8156863451004028, 0.3607843220233917, 0.4 },
                bottomShade = { 0.9490196704864502, 0.8156863451004028, 0.3607843220233917, 0.4 },
            },
            panelBackground = NAVIGATOR.mahogany,
            panelBorder = NavigatorColor(NAVIGATOR.agedBrass, 0.82),
            panelInnerBorder = NavigatorColor(NAVIGATOR.blackenedMetal, 0.90),
            panelHeader = NavigatorColor(NAVIGATOR.darkWalnut, 0.92),
            panelTopShade = { 1.00, 1.00, 1.00, 0.05 },
            panelBottomShade = { 0.00, 0.00, 0.00, 0.42 },
            fieldBackground = { 0.055, 0.047, 0.040, 0.99 },
            fieldBorder = { 0.25, 0.22, 0.18, 0.78 },
            fieldBorderFocus = { 0.91, 0.70, 0.30, 0.98 },
            fieldInsetTop = { 1.00, 1.00, 1.00, 0.04 },
            fieldInsetBottom = { 0.00, 0.00, 0.00, 0.28 },
            accent = { 0.910, 0.757, 0.400, 0.20 },
            sectionBorder = NavigatorColor(NAVIGATOR.agedBrass, 0.48),
            sectionFill = NavigatorColor(NAVIGATOR.darkWalnut, 0.68),
            sectionFillStrong = NavigatorColor(NAVIGATOR.darkWalnut, 0.78),
            sectionInsetTop = { 1.00, 1.00, 1.00, 0.035 },
            sectionInsetBottom = { 0.00, 0.00, 0.00, 0.26 },
            sectionAccent = NavigatorColor(NAVIGATOR.agedBrass, 0.24),
            headerAccent = NavigatorColor(NAVIGATOR.focusBrass, 0.38),
            EditorSectionRhythm = {
                outerMarginX = 6,
                headerInsetX = 8,
                headerTopGap = 8,
                accentInsetX = 8,
            },
            workspaceDivider = { 0.42, 0.34, 0.23, 0.24 },
            canvasToolbarBackground = { 0.045, 0.040, 0.035, 0.94 },
            canvasToolbarBorder = { 0.82, 0.58, 0.20, 0.42 },
            canvasToolbarInset = { 0.070, 0.060, 0.050, 0.94 },
        },
        CompactDialogContent = {
            parchment = {
                material = "texture",
                texture = "Interface\\AddOns\\FocalPoint\\Media\\Textures\\fp_window_background.jpg",
                tint = { 1.00, 1.00, 1.00, 1.00 },
                tile = false,
            },
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
        CompactSlider = {
            track = {
                leftAtlas = "Minimal_SliderBar_Left",
                middleAtlas = "_Minimal_SliderBar_Middle",
                rightAtlas = "Minimal_SliderBar_Right",
            },
            thumb = {
                atlas = "Minimal_SliderBar_Button",
                alpha = 1.00,
                disabledAlpha = 0.45,
            },
            input = {
                backgroundTexture = "Interface\\ChatFrame\\ChatFrameBackground",
                borderTexture = "Interface\\ChatFrame\\ChatFrameBackground",
                backgroundColor = { 0.00, 0.00, 0.00, 0.50 },
                border = { 0.30, 0.30, 0.30, 0.80 },
                borderHover = { 0.50, 0.50, 0.50, 1.00 },
            },
            text = {
                normal = { 1.00, 1.00, 1.00, 1.00 },
                disabled = { 0.50, 0.50, 0.50, 1.00 },
            },
        },
    },
    editorButtonVisuals = {
        states = {
            parchmentSectionHeader = {
            hex = "573B1F",
            wow = "|cff573B1F",
            r = 0.34,
            g = 0.23,
            b = 0.12,
        },
        parchmentSecondary = {
            hex = "664D2B",
            wow = "|cff664D2B",
            r = 0.40,
            g = 0.30,
            b = 0.17,
        },
        parchmentMuted = {
            hex = "7A613D",
            wow = "|cff7A613D",
            r = 0.48,
            g = 0.38,
            b = 0.24,
        },
        disabled = {
                fill = { 0.08, 0.09, 0.11, 0.92 },
                border = { 0.18, 0.20, 0.23, 0.86 },
                accent = { 0.28, 0.30, 0.34, 0.08 },
                text = { 0.60, 0.63, 0.67, 1.00 },
            },
            normal = {
                fill = { 0.10, 0.12, 0.15, 0.96 },
                border = { 0.28, 0.32, 0.38, 0.90 },
                accent = { 0.45, 0.50, 0.58, 0.08 },
                text = { 0.94, 0.96, 0.98, 1.00 },
            },
            hover = {
                fill = { 0.12, 0.16, 0.21, 0.96 },
                border = { 0.35, 0.51, 0.68, 0.75 },
                accent = { 0.45, 0.63, 0.82, 0.16 },
                text = { 0.95, 0.97, 1.00, 1.00 },
            },
            pressed = {
                fill = { 0.09, 0.13, 0.19, 0.96 },
                border = { 0.42, 0.60, 0.80, 0.82 },
                accent = { 0.50, 0.69, 0.90, 0.22 },
                text = { 0.94, 0.97, 1.00, 1.00 },
            },
            active = {
                fill = { 0.13, 0.20, 0.29, 0.96 },
                border = { 0.43, 0.62, 0.82, 0.95 },
                accent = { 0.50, 0.70, 0.92, 0.24 },
                text = { 0.95, 0.98, 1.00, 1.00 },
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

function Skins.GetEditorSectionRhythm(fallback)
    local palette = Skins.GetFormPalette()
    local defaultPalette = Skins.Builtin.default and Skins.Builtin.default.formPalette or nil
    return (palette and palette.Chrome and palette.Chrome.EditorSectionRhythm)
        or (defaultPalette and defaultPalette.Chrome and defaultPalette.Chrome.EditorSectionRhythm)
        or fallback
        or {}
end

function Skins.GetCanvasInteractionPresentation(fallback)
    local skin = Skins.GetActiveSkin()
    local palette = skin and skin.formPalette or nil
    local defaultPalette = Skins.Builtin.default and Skins.Builtin.default.formPalette or nil
    return (palette and palette.CanvasInteraction)
        or (defaultPalette and defaultPalette.CanvasInteraction)
        or fallback
        or {}
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

function Skins.GetBrandColor(role, fallback)
    local skin = Skins.GetActiveSkin()
    local brand = skin and skin.brand or nil
    return (brand and brand[role]) or fallback
end

function Skins.GetBrandTitle(defaultText)
    if type(defaultText) == "string" and defaultText ~= "" and defaultText ~= "Focal Point" then
        return defaultText
    end
    -- RGB belongs exclusively to the Brand typography descriptor, including reset.
    return "FOCAL POINT"
end

-- Canonical identity typography, independent of section headings and live regions.
function Skins.GetBrandTypography()
    local color = Skins.GetBrandColor("titleFocal") or Skins.GetBrandColor("white") or {}
    return {
        font = "fp:font:cinzel-decorative-bold",
        size = 19,
        flags = "",
        color = { color.r or 1, color.g or 1, color.b or 1 },
        alpha = 0.9,
        shadowEnabled = true,
    }
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
