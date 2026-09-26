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
            -- Same canonical gold as sectionHeader / visual.BrandGold.
            hex = "E8C166",
            wow = "|cffE8C166",
            r = 0.910,
            g = 0.757,
            b = 0.400,
        },
        parchmentSecondary = {
            -- Same warm secondary family as visual.TextSecondary.
            hex = "B3AD9E",
            wow = "|cffB3AD9E",
            r = 0.70,
            g = 0.68,
            b = 0.62,
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
        CanvasInteraction = {
            selection = {
                unitPrimary = {
                    fill = { 0.98, 0.84, 0.24, 0.14 },
                    border = { 0.98, 0.84, 0.24, 1.00 },
                },
                unitSecondary = {
                    fill = { 0.98, 0.84, 0.24, 0.025 },
                    border = { 0.98, 0.84, 0.24, 0.32 },
                },
                unitPrimaryTextMode = {
                    fill = { 0.00, 0.00, 0.00, 0.00 },
                    border = { 0.98, 0.84, 0.24, 0.42 },
                },
                unitSecondaryTextMode = {
                    fill = { 0.00, 0.00, 0.00, 0.00 },
                    border = { 0.98, 0.84, 0.24, 0.20 },
                },
                object = {
                    fill = { 0.98, 0.84, 0.24, 0.10 },
                    border = { 0.98, 0.84, 0.24, 0.95 },
                },
            },
            hover = {
                object = {
                    fill = { 0.29, 0.25, 0.19, 0.035 },
                    border = { 0.54, 0.43, 0.17, 0.54 },
                },
            },
            placeholder = {
                aura = {
                    fill = { 0.045, 0.039, 0.034, 0.20 },
                    border = { 0.29, 0.25, 0.19, 0.38 },
                    text = { 0.70, 0.68, 0.62, 0.72 },
                },
                unitFrame = {
                    bar = {
                        color = { 0.29, 0.25, 0.19 },
                        enabledAlpha = 0.62,
                        disabledAlpha = 0.18,
                    },
                    background = {
                        color = { 0.045, 0.039, 0.034 },
                        enabledAlpha = 0.30,
                        disabledAlpha = 0.10,
                    },
                },
            },
            text = {
                selection = {
                    fill = { 0.98, 0.74, 0.18, 0.08 },
                    border = { 1.00, 0.82, 0.24, 0.98 },
                    borderThickness = 2,
                },
                hover = {
                    fill = { 0.98, 0.74, 0.18, 0.02 },
                    border = { 1.00, 0.82, 0.24, 0.70 },
                    borderThickness = 1,
                },
            },
            move = {
                coordinates = {
                    text = { 0.35, 1.00, 0.45, 0.95 },
                },
                placeholder = {
                    unselected = {
                        enabled = {
                            fill = { 0.045, 0.039, 0.034, 0.94 },
                            border = { 0.29, 0.25, 0.19, 0.46 },
                        },
                        disabled = {
                            fill = { 0.045, 0.039, 0.034, 0.88 },
                            border = { 0.29, 0.25, 0.19, 0.24 },
                        },
                    },
                    secondary = {
                        enabled = {
                            fill = { 0.18, 0.15, 0.08, 0.94 },
                            border = { 0.54, 0.43, 0.17, 0.58 },
                        },
                        disabled = {
                            fill = { 0.13, 0.10, 0.05, 0.88 },
                            border = { 0.54, 0.43, 0.17, 0.34 },
                        },
                    },
                    accent = {
                        enabled = { 0.78, 0.65, 0.24, 0.42 },
                        disabled = { 0.78, 0.65, 0.24, 0.10 },
                    },
                    text = {
                        enabled = { 0.70, 0.68, 0.62, 0.96 },
                        disabled = { 0.494, 0.459, 0.392, 0.38 },
                    },
                    shadow = { 0.00, 0.00, 0.00, 0.75 },
                },
            },
            resize = {
                handle = {
                    fill = { 0.08, 0.07, 0.05, 0.94 },
                    border = { 0.910, 0.757, 0.400, 0.85 },
                    gripPrimary = { 0.910, 0.757, 0.400, 0.72 },
                    gripSecondary = { 0.910, 0.757, 0.400, 0.46 },
                },
                label = {
                    text = { 0.918, 0.459, 0.000, 0.98 },
                    shadow = { 0.00, 0.00, 0.00, 0.85 },
                },
            },
        },
        CompactDialogContent = {
            parchment = {
                material = "texture",
                textureId = "fp:texture:fp-forged-metal-128x128",
                tint = { 0.40, 0.40, 0.40, 0.96 },
                headerTint = { 0.16, 0.16, 0.16, 1.00 },
                tile = false,
            },
        },
        ItemColors = {
            pageIntro = { 0.80, 0.76, 0.68, 1.00 },
            description = { 0.70, 0.68, 0.62 },
            sectionDescription = { 0.67, 0.65, 0.59, 1.00 },
            hint = { 0.72, 0.70, 0.64 },
            statusMuted = { 0.56, 0.54, 0.49, 1.00 },
            footerHint = { 0.64, 0.62, 0.57 },
            footerMuted = { 0.50, 0.48, 0.44, 1.00 },
            value = { 0.93, 0.90, 0.80 },
            valueEmphasis = { 0.97, 0.95, 0.91, 1.00 },
            checkbox = { 0.94, 0.90, 0.82, 1.00 },
            checkboxDisabled = { 0.50, 0.50, 0.50, 1.00 },
        },
        Checkbox = {
            box = { 1.00, 1.00, 1.00, 1.00 },
            checkmark = { 1.00, 1.00, 1.00, 1.00 },
            highlight = { 1.00, 1.00, 1.00, 1.00 },
            retail = {
                normal = "UI-HUD-ActionBar-IconFrame",
                highlight = "UI-HUD-ActionBar-IconFrame-Highlight",
                checked = "UI-HUD-ActionBar-IconFrame-Checked",
            },
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
        -- Canonical colors for LayoutManager, MediaLibrary and SelectionRow.
        ListSelectionRow = {
            fill = { 0.065, 0.056, 0.048, 0.86 },
            fillHover = { 0.105, 0.085, 0.060, 0.94 },
            fillSelected = { 0.205, 0.145, 0.055, 0.98 },
            border = { 0.23, 0.20, 0.16, 0.54 },
            borderHover = { 0.48, 0.37, 0.20, 0.78 },
            borderSelected = { 0.96, 0.73, 0.22, 0.98 },
            marker = { 1.00, 0.80, 0.24, 1.00 },
            markerMuted = { 0.58, 0.53, 0.42, 0.36 },
            name = { 0.93, 0.91, 0.84, 1.00 },
            nameSelected = { 1.00, 0.98, 0.88, 1.00 },
        },
        CompositionTree = {
            surface = { 0.060, 0.052, 0.044, 0.97 },
            rowHover = { 0.105, 0.085, 0.060, 0.94 },
            rowSelected = { 0.205, 0.145, 0.055, 0.98 },
            scrollbar = {
                thumb = { 0.29, 0.25, 0.19, 0.55 },
            },
            text = {
                normal = { 0.70, 0.68, 0.62, 1.00 },
                selected = { 0.949, 0.902, 0.788, 1.00 },
                disabled = { 0.494, 0.459, 0.392, 1.00 },
                disclosure = { 0.70, 0.68, 0.62, 1.00 },
            },
            toggle = {
                disabled = { 0.494, 0.459, 0.392, 0.14 },
                fallback = { 0.29, 0.25, 0.19, 0.38 },
            },
            icon = {
                unit = { 1.00, 0.72, 0.18 },
                bar = { 0.20, 0.62, 1.00 },
                text = { 1.00, 0.86, 0.35 },
                aura = { 0.76, 0.28, 1.00 },
                decoration = { 0.45, 0.55, 1.00 },
                indicator = { 1.00, 0.30, 0.10 },
                portrait = { 1.00, 0.55, 0.18 },
                fallback = { 0.45, 0.70, 1.00 },
                disabled = { 0.42, 0.44, 0.48, 0.42 },
                selectedBrightness = 1.18,
                selectedAlpha = 1.00,
                hoverBrightness = 1.05,
                hoverAlpha = 0.94,
                normalBrightness = 1.00,
                normalAlpha = 0.90,
            },
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
