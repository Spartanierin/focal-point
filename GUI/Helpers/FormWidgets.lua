local _, ns = ...

ns.GUI = ns.GUI or {}
ns.GUI.Helpers = ns.GUI.Helpers or {}

local AceGUI = LibStub("AceGUI-3.0")
local CreateFrame = CreateFrame

local FormWidgets = {}
ns.GUI.Helpers.FormWidgets = FormWidgets

local function GetFormPalette()
    local skins = ns.GUI and ns.GUI.Skins or nil
    if skins and skins.GetFormPalette then
        return skins.GetFormPalette() or {}
    end
    return {}
end

local function GetChromeColors()
    return GetFormPalette().Chrome or {}
end

local function GetCompactDialogContentSurface(name)
    local surfaces = GetFormPalette().CompactDialogContent or {}
    return type(name) == "string" and surfaces[name] or nil
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

local function GetCheckboxPresentation()
    return GetFormPalette().Checkbox or {}
end

local function GetStandardSliderPresentation()
    return GetFormPalette().StandardSlider or {}
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

local FP_WINDOW_PANEL_REGION_KEYS = {
    "_fpPanelFill",
    "_fpPanelHeaderFill",
    "_fpPanelTopShade",
    "_fpPanelBottomShade",
    "_fpPanelBorderTop",
    "_fpPanelBorderBottom",
    "_fpPanelBorderLeft",
    "_fpPanelBorderRight",
    "_fpPanelInnerTop",
    "_fpPanelInnerBottom",
    "_fpPanelInnerLeft",
    "_fpPanelInnerRight",
    "_fpPanelHeaderSeparator",
}

local FP_MODERN_WINDOW_SLOTS = {
    topLeft = {
        key = "_fpModernTitleLeft",
        atlas = "UI-Frame-PortraitMetal-CornerTopLeft",
    },
    topCenter = {
        key = "_fpModernTitleCenter",
        atlas = "_UI-Frame-Metal-EdgeTop",
    },
    topRight = {
        key = "_fpModernTitleRight",
        atlas = "UI-Frame-Metal-CornerTopRight",
    },
    bottomLeft = {
        key = "_fpModernTitleBottomLeft",
        atlas = "UI-Frame-Metal-CornerBottomLeft",
    },
    bottomCenter = {
        key = "_fpModernTitleBottomCenter",
        atlas = "_UI-Frame-Metal-EdgeBottom",
    },
    bottomRight = {
        key = "_fpModernTitleBottomRight",
        atlas = "UI-Frame-Metal-CornerBottomRight",
    },
    left = {
        key = "_fpModernTitleSideLeft",
        atlas = "!UI-Frame-Metal-EdgeLeft",
    },
    right = {
        key = "_fpModernTitleSideRight",
        atlas = "!UI-Frame-Metal-EdgeRight",
    },
}

local FP_MODERN_WINDOW_SLOT_KEYS = {
    "_fpModernTitleLeft",
    "_fpModernTitleCenter",
    "_fpModernTitleRight",
    "_fpModernTitleBottomLeft",
    "_fpModernTitleBottomCenter",
    "_fpModernTitleBottomRight",
    "_fpModernTitleSideLeft",
    "_fpModernTitleSideRight",
}

local NATIVE_TITLE_BACKGROUND_TEXTURE = 251966
local NATIVE_DIALOG_BACKGROUND_TEXTURE = 137056
local NATIVE_BORDER_TEXTURE = 251963

local function FindNativeTitleBackground(frame)
    if not frame then
        return nil
    end

    for _, region in ipairs({ frame:GetRegions() }) do
        if region and region.GetObjectType and region:GetObjectType() == "Texture" and region.GetTexture
            and region:GetTexture() == NATIVE_TITLE_BACKGROUND_TEXTURE then
            return region
        end
    end

    return nil
end

local function FindNativeDialogBackground(frame)
    if not frame then
        return nil
    end

    for _, region in ipairs({ frame:GetRegions() }) do
        if region and region.GetObjectType and region:GetObjectType() == "Texture" and region.GetTexture
            and region:GetTexture() == NATIVE_DIALOG_BACKGROUND_TEXTURE then
            return region
        end
    end

    return nil
end

local function FindNativeBorderRegions(frame)
    if not frame then
        return {}
    end

    local regions = {}
    for _, region in ipairs({ frame:GetRegions() }) do
        if region and region.GetObjectType and region:GetObjectType() == "Texture" and region.GetTexture
            and region:GetTexture() == NATIVE_BORDER_TEXTURE then
            table.insert(regions, region)
        end
    end
    return regions
end

local function EnsureModernWindowRegion(frame, key)
    if not frame[key] then
        frame[key] = frame:CreateTexture(nil, "ARTWORK")
    end
    return frame[key]
end

local function EnsureModernWindowPortrait(frame, texturePath)
    local container = frame._fpModernPortraitContainer
    if not container then
        container = CreateFrame("Frame", nil, frame)
        container:SetSize(1, 1)
        container:SetPoint("TOPLEFT", frame, "TOPLEFT")
        container:EnableMouse(false)
        frame._fpModernPortraitContainer = container

        local portrait = container:CreateTexture(nil, "ARTWORK")
        portrait:SetSize(62, 62)
        portrait:SetPoint("TOPLEFT", container, "TOPLEFT", -5, 7)
        portrait:SetBlendMode("BLEND")
        container._fpPortrait = portrait

        local mask = container:CreateMaskTexture()
        mask:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask")
        mask:SetPoint("TOPLEFT", portrait, "TOPLEFT", 2, 0)
        mask:SetPoint("BOTTOMRIGHT", portrait, "BOTTOMRIGHT", -2, 4)
        portrait:AddMaskTexture(mask)
        container._fpPortraitMask = mask
    end

    if texturePath and container._fpPortrait then
        container._fpPortrait:SetTexture(texturePath)
    end
    container:Show()
    container._fpPortrait:Show()
    container._fpPortraitMask:Show()
    return container
end

local function EnsureModernWindowBackground(frame)
    local background = frame._fpModernPortraitBackground
    if not background then
        background = frame:CreateTexture(nil, "BACKGROUND", nil, -6)
        frame._fpModernPortraitBackground = background
    end

    background:ClearAllPoints()
    background:SetPoint("TOPLEFT", frame, "TOPLEFT", 2, -21)
    background:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -2, 2)
    background:SetTexture("Interface\\FrameGeneral\\UI-Background-Rock")
    background:SetHorizTile(true)
    background:SetVertTile(true)
    background:SetVertexColor(1, 1, 1, 1)
    background:SetAlpha(1)
    background:SetBlendMode("BLEND")
    background:Show()
    return background
end

local function EnsureModernWindowTopTileStreaks(frame)
    local streaks = frame._fpModernPortraitTopTileStreaks
    if not streaks then
        streaks = frame:CreateTexture(nil, "BORDER")
        frame._fpModernPortraitTopTileStreaks = streaks
    end

    streaks:ClearAllPoints()
    streaks:SetPoint("TOPLEFT", frame, "TOPLEFT", 6, -21)
    streaks:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -2, -21)
    streaks:SetAtlas("_UI-Frame-TopTileStreaks", true)
    streaks:SetHorizTile(true)
    streaks:SetVertTile(false)
    streaks:SetVertexColor(1, 1, 1, 1)
    streaks:SetAlpha(1)
    streaks:SetBlendMode("BLEND")
    streaks:Show()
    return streaks
end

local function ApplyModernPortraitBackground(frame)
    EnsureModernWindowBackground(frame)
    EnsureModernWindowTopTileStreaks(frame)

    local dialogBackground = frame._fpModernDialogBackground
    if not dialogBackground then
        local region = FindNativeDialogBackground(frame)
        if region then
            local r, g, b, a = region:GetVertexColor()
            dialogBackground = {
                region = region,
                shown = region:IsShown(),
                alpha = region:GetAlpha(),
                color = { r, g, b, a },
            }
            frame._fpModernDialogBackground = dialogBackground
        end
    end
    if dialogBackground and dialogBackground.region then
        dialogBackground.region:Hide()
        dialogBackground.region:SetAlpha(0)
    end
end

local function ResetModernPortraitBackground(frame)
    if not frame then
        return
    end

    if frame._fpModernPortraitBackground then
        frame._fpModernPortraitBackground:Hide()
    end
    if frame._fpModernPortraitTopTileStreaks then
        frame._fpModernPortraitTopTileStreaks:SetHorizTile(false)
        frame._fpModernPortraitTopTileStreaks:Hide()
    end

    local dialogBackground = frame._fpModernDialogBackground
    if dialogBackground and dialogBackground.region then
        if dialogBackground.color then
            dialogBackground.region:SetVertexColor(unpack(dialogBackground.color))
        end
        dialogBackground.region:SetAlpha(dialogBackground.alpha)
        if dialogBackground.shown then
            dialogBackground.region:Show()
        else
            dialogBackground.region:Hide()
        end
    end
end

local function ResetModernWindowPortrait(frame)
    local container = frame and frame._fpModernPortraitContainer
    if not container then
        return
    end
    container:Hide()
    if container._fpPortrait then
        container._fpPortrait:Hide()
    end
    if container._fpPortraitMask then
        container._fpPortraitMask:Hide()
    end
end

local function ResetModernWindowTitleBar(frame)
    if not frame then
        return
    end

    for _, key in ipairs(FP_MODERN_WINDOW_SLOT_KEYS) do
        local region = frame[key]
        if region then
            if region.SetHorizTile then
                region:SetHorizTile(false)
            end
            if region.SetVertTile then
                region:SetVertTile(false)
            end
            region:Hide()
        end
    end

    local titleBackground = frame._fpModernTitleNativeBackground
    if titleBackground and titleBackground.region then
        if titleBackground.region.SetAlpha then
            titleBackground.region:SetAlpha(titleBackground.alpha)
        end
        if titleBackground.shown then
            titleBackground.region:Show()
        else
            titleBackground.region:Hide()
        end
    end

    for _, snapshot in ipairs(frame._fpModernTitleNativeBorders or {}) do
        local region = snapshot.region
        if region then
            if region.SetAlpha then
                region:SetAlpha(snapshot.alpha)
            end
            if snapshot.shown then
                region:Show()
            else
                region:Hide()
            end
        end
    end

    local titleText = frame._fpModernTitleNativeText
    if titleText and titleText.region and titleText.drawLayer and titleText.region.SetDrawLayer then
        titleText.region:SetDrawLayer(titleText.drawLayer, titleText.sublevel)
    end
    if titleText and titleText.region and titleText.points then
        if titleText.parent and titleText.region.SetParent then
            titleText.region:SetParent(titleText.parent)
        end
        titleText.region:ClearAllPoints()
        for _, point in ipairs(titleText.points) do
            titleText.region:SetPoint(point.point, point.relativeTo, point.relativePoint, point.x, point.y)
        end
    end

    local closeButton = frame._fpModernTitleNativeCloseButton
    if closeButton and closeButton.region and closeButton.points then
        if closeButton.frameLevel and closeButton.region.SetFrameLevel then
            closeButton.region:SetFrameLevel(closeButton.frameLevel)
        end
        closeButton.region:ClearAllPoints()
        for _, point in ipairs(closeButton.points) do
            closeButton.region:SetPoint(point.point, point.relativeTo, point.relativePoint, point.x, point.y)
        end
    end

    local titleButton = frame._fpModernTitleDragButton
    if titleButton and titleButton.region and titleButton.frameLevel and titleButton.region.SetFrameLevel then
        titleButton.region:SetFrameLevel(titleButton.frameLevel)
    end
end

local function HideDefaultWindowChrome(frame)
    if not frame or frame._fpDefaultChromeHidden then
        return
    end

    local regions = frame._fpDefaultChromeRegions
    if not regions then
        regions = {}
        for _, region in ipairs({ frame:GetRegions() }) do
            if region and region.GetObjectType and region:GetObjectType() == "Texture" then
                table.insert(regions, {
                    region = region,
                    shown = region:IsShown(),
                    alpha = region:GetAlpha(),
                })
            end
        end
        frame._fpDefaultChromeRegions = regions
    end

    for _, snapshot in ipairs(regions) do
        local region = snapshot.region
        if region then
            region:Hide()
            if region.SetAlpha then
                region:SetAlpha(0)
            end
        end
    end

    frame._fpDefaultChromeHidden = true
end

function FormWidgets.RestoreDefaultWindowChrome(window)
    local frame = window and window.frame
    if not frame then
        return
    end

    ResetModernWindowTitleBar(frame)
    ResetModernPortraitBackground(frame)
    ResetModernWindowPortrait(frame)

    if frame._fpModernNineSlice then
        frame._fpModernNineSlice:Hide()
    end

    for _, key in ipairs(FP_WINDOW_PANEL_REGION_KEYS) do
        if frame[key] then
            frame[key]:Hide()
        end
    end
    if window.content and window.content._fpAccent then
        window.content._fpAccent:Hide()
    end

    for _, snapshot in ipairs(frame._fpDefaultChromeRegions or {}) do
        local region = snapshot.region
        if region then
            if region.SetAlpha then
                region:SetAlpha(snapshot.alpha)
            end
            if snapshot.shown then
                region:Show()
            else
                region:Hide()
            end
        end
    end
    frame._fpDefaultChromeHidden = nil

    if window.titletext then
        if GameFontNormal and window.titletext.SetFontObject then
            window.titletext:SetFontObject(GameFontNormal)
        end
        if window.titletext.Show then
            window.titletext:Show()
        end
    end
end

-- Shared border-only host. Modern chrome retains its title/portrait behavior;
-- Navigator uses the same NineSlice engine without entering that broader path.
local function ApplyWindowNineSlice(frame, key, layout)
    local nineSlice = frame[key]
    if not nineSlice then
        nineSlice = CreateFrame("Frame", nil, frame, "NineSlicePanelTemplate")
        nineSlice:SetAllPoints(frame)
        frame[key] = nineSlice
    end
    nineSlice:EnableMouse(false)
    if nineSlice.SetFrameLevel and frame.GetFrameLevel then
        nineSlice:SetFrameLevel(frame:GetFrameLevel() + 3)
    end
    if type(layout) == "string" then
        NineSliceUtil.ApplyLayoutByName(nineSlice, layout)
    else
        NineSliceUtil.ApplyLayout(nineSlice, layout)
    end
    return nineSlice
end

local navigatorTextureRoot = "Interface\\AddOns\\FocalPoint\\Media\\Textures\\Window\\"
local function SetupNavigatorBrassPiece(_, piece, setup, definition)
    piece:SetTexture(navigatorTextureRoot .. definition.file,
        setup.tileHorizontal and "REPEAT" or "CLAMP", setup.tileVertical and "REPEAT" or "CLAMP")
    piece:SetSize(definition.width, definition.height)
    piece:SetTexCoord(setup.mirrorHorizontal and 1 or 0, setup.mirrorHorizontal and 0 or 1,
        setup.mirrorVertical and 1 or 0, setup.mirrorVertical and 0 or 1)
    piece:SetHorizTile(setup.tileHorizontal == true)
    piece:SetVertTile(setup.tileVertical == true)
    piece:SetVertexColor(1, 1, 1, 1)
    piece:SetBlendMode("BLEND")
end
local navigatorCorner = { file = "fp_navigator_brass_corner.tga", width = 56, height = 56, layer = "OVERLAY" }
local navigatorHorizontal = { file = "fp_navigator_brass_horizontal.tga", width = 112, height = 56, layer = "OVERLAY" }
local navigatorVertical = { file = "fp_navigator_brass_vertical.tga", width = 56, height = 112, layer = "OVERLAY" }
local navigatorBrassLayout = {
    setupPieceVisualsFunction = SetupNavigatorBrassPiece,
    TopLeftCorner = navigatorCorner, TopRightCorner = navigatorCorner,
    BottomLeftCorner = navigatorCorner, BottomRightCorner = navigatorCorner,
    TopEdge = navigatorHorizontal, BottomEdge = navigatorHorizontal,
    LeftEdge = navigatorVertical, RightEdge = navigatorVertical,
    -- Deliberately no Center: material remains owned by shell composition.
}
local navigatorBorderColors = {
    _fpSidebarPanelBorderTop = "panelBorder", _fpSidebarPanelBorderBottom = "panelBorder",
    _fpSidebarPanelBorderLeft = "panelBorder", _fpSidebarPanelBorderRight = "panelBorder",
    _fpSidebarPanelInnerTop = "panelInnerBorder", _fpSidebarPanelInnerBottom = "panelInnerBorder",
    _fpSidebarPanelInnerLeft = "panelInnerBorder", _fpSidebarPanelInnerRight = "panelInnerBorder",
    _fpSidebarPanelTopShade = "panelTopShade", _fpSidebarPanelBottomShade = "panelBottomShade",
}

function FormWidgets.ApplyNavigatorBrassBorder(window)
    local frame = window and window.frame
    local target = window and window._fpNavigatorBrassTarget
    if not frame or not target then return false end
    local enabled = window._fpNavigatorBrassEnabled
    if enabled then
        if not NineSliceUtil or not NineSliceUtil.ApplyLayout then return false end
        ApplyWindowNineSlice(frame, "_fpNavigatorBrassNineSlice", navigatorBrassLayout):Show()
    elseif frame._fpNavigatorBrassNineSlice then
        frame._fpNavigatorBrassNineSlice:Hide()
    end
    local composition = ns.GUI.PresentationCompositionPreview
    local composed = composition and composition.GetColorConflictReason(target) ~= nil
    local colors = GetChromeColors()
    for key, colorKey in pairs(navigatorBorderColors) do
        local region = frame[key]
        if region then
            if enabled or composed then
                region:Hide()
            else
                local color = colors[colorKey] or (colorKey == "panelInnerBorder" and colors.sectionBorder)
                if color then region:SetColorTexture(unpack(color)) end
                region:Show()
            end
        end
    end
    return true
end

-- Internal acceptance/reset entry point; no persisted style, new UI or queue.
function FormWidgets.SetNavigatorBrassEnabled(window, enabled)
    if InCombatLockdown and InCombatLockdown() then return false, "combat" end
    if not window or not window._fpNavigatorBrassTarget then return false, "not_navigator_window" end
    if type(enabled) ~= "boolean" then return false, "invalid_enabled" end
    window._fpNavigatorBrassEnabled = enabled
    return FormWidgets.ApplyNavigatorBrassBorder(window)
end

function FormWidgets.BindNavigatorBrassWindow(window, target)
    if not window or not window.frame or (target ~= "sidebar_shell" and target ~= "inspector_shell") then return end
    if not window:GetUserData("fpNavigatorBrass") then
        local previousRelease = window.events and window.events.OnRelease
        window:SetUserData("fpNavigatorBrass", true)
        window:SetCallback("OnRelease", function(owner, event)
            local composition = ns.GUI.PresentationCompositionPreview
            if composition then composition.Release(owner._fpNavigatorBrassTarget, owner) end
            owner._fpNavigatorBrassEnabled = false
            FormWidgets.ApplyNavigatorBrassBorder(owner)
            owner._fpNavigatorBrassTarget, owner._fpNavigatorBrassEnabled = nil, nil
            owner._fpSidebarCompositionBound = nil
            if previousRelease then previousRelease(owner, event) end
        end)
        window._fpNavigatorBrassEnabled = true
    end
    window._fpNavigatorBrassTarget = target
    FormWidgets.ApplyNavigatorBrassBorder(window)
end

function FormWidgets.ApplyModernWindowChrome(window, options)
    local frame = window and window.frame
    if not frame then
        return
    end

    local useNineSlice = options and options.nineSlice == true
    local usePortrait = options and options.portrait == true
    local nineSliceLayout = usePortrait and "PortraitFrameTemplate" or "ButtonFrameTemplateNoPortrait"
    if useNineSlice then
        if not NineSliceUtil or not NineSliceUtil.ApplyLayoutByName then
            return
        end
        if NineSliceUtil.GetLayout and not NineSliceUtil.GetLayout(nineSliceLayout) then
            return
        end
    end

    FormWidgets.RestoreDefaultWindowChrome(window)

    if usePortrait then
        ApplyModernPortraitBackground(frame)
    end

    local nativeTitleBackground = FindNativeTitleBackground(frame)
    if nativeTitleBackground and not frame._fpModernTitleNativeBackground then
        frame._fpModernTitleNativeBackground = {
            region = nativeTitleBackground,
            shown = nativeTitleBackground:IsShown(),
            alpha = nativeTitleBackground:GetAlpha(),
        }
    end
    if nativeTitleBackground and frame._fpModernTitleNativeBackground then
        nativeTitleBackground:Hide()
        nativeTitleBackground:SetAlpha(0)
    end

    if not frame._fpModernTitleNativeBorders then
        frame._fpModernTitleNativeBorders = {}
        for _, region in ipairs(FindNativeBorderRegions(frame)) do
            table.insert(frame._fpModernTitleNativeBorders, {
                region = region,
                shown = region:IsShown(),
                alpha = region:GetAlpha(),
            })
        end
    end
    for _, snapshot in ipairs(frame._fpModernTitleNativeBorders) do
        snapshot.region:Hide()
        snapshot.region:SetAlpha(0)
    end

    if window.titletext and not frame._fpModernTitleNativeText and window.titletext.GetDrawLayer then
        local drawLayer, sublevel = window.titletext:GetDrawLayer()
        local points = {}
        for index = 1, window.titletext:GetNumPoints() do
            local point, relativeTo, relativePoint, x, y = window.titletext:GetPoint(index)
            table.insert(points, {
                point = point,
                relativeTo = relativeTo,
                relativePoint = relativePoint,
                x = x,
                y = y,
            })
        end
        frame._fpModernTitleNativeText = {
            region = window.titletext,
            drawLayer = drawLayer,
            sublevel = sublevel,
            parent = window.titletext.GetParent and window.titletext:GetParent() or frame,
            points = points,
        }
    end
    if window.titletext and window.titletext.SetDrawLayer then
        window.titletext:SetDrawLayer("OVERLAY", 7)
    end

    local closeButton = window.closebutton
    if closeButton and not frame._fpModernTitleNativeCloseButton then
        local points = {}
        for index = 1, closeButton:GetNumPoints() do
            local point, relativeTo, relativePoint, x, y = closeButton:GetPoint(index)
            table.insert(points, {
                point = point,
                relativeTo = relativeTo,
                relativePoint = relativePoint,
                x = x,
                y = y,
            })
        end
        frame._fpModernTitleNativeCloseButton = {
            region = closeButton,
            points = points,
            frameLevel = closeButton.GetFrameLevel and closeButton:GetFrameLevel() or nil,
        }
    end
    local titleButton = window.title
    if titleButton and not frame._fpModernTitleDragButton then
        frame._fpModernTitleDragButton = {
            region = titleButton,
            frameLevel = titleButton.GetFrameLevel and titleButton:GetFrameLevel() or nil,
        }
    end
    if useNineSlice then
        local nineSlice = ApplyWindowNineSlice(frame, "_fpModernNineSlice", nineSliceLayout)
        if usePortrait then
            local portraitTexture = options.portraitTexture
            local portrait = EnsureModernWindowPortrait(frame, portraitTexture)
            if portrait.SetFrameLevel and frame.GetFrameLevel then
                portrait:SetFrameLevel(frame:GetFrameLevel() + 2)
            end
        end
        if window.title and window.title.SetFrameLevel and frame.GetFrameLevel then
            window.title:SetFrameLevel(frame:GetFrameLevel() + 4)
        end
        if closeButton and closeButton.SetFrameLevel and frame.GetFrameLevel then
            closeButton:SetFrameLevel(frame:GetFrameLevel() + 5)
        end
        nineSlice:Show()
        if window.titletext then
            if window.title and window.titletext.SetParent then
                window.titletext:SetParent(window.title)
            end
            window.titletext:ClearAllPoints()
            local titleLeft = usePortrait and 58 or 0
            local titleRight = usePortrait and -24 or 0
            window.titletext:SetPoint("TOPLEFT", frame, "TOPLEFT", titleLeft, -6)
            window.titletext:SetPoint("TOPRIGHT", frame, "TOPRIGHT", titleRight, -6)
            window.titletext:Show()
            window.titletext:SetAlpha(1)
        end
        return
    end

    local topLeft = FP_MODERN_WINDOW_SLOTS.topLeft
    local left = EnsureModernWindowRegion(frame, topLeft.key)
    left:ClearAllPoints()
    left:SetPoint("TOPLEFT", frame, "TOPLEFT", 7, -5)
    left:SetAtlas(topLeft.atlas, true)
    left:SetHorizTile(false)
    left:SetVertTile(false)
    left:Show()

    local topRight = FP_MODERN_WINDOW_SLOTS.topRight
    local right = EnsureModernWindowRegion(frame, topRight.key)
    right:ClearAllPoints()
    right:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -3, -5)
    right:SetAtlas(topRight.atlas, true)
    right:SetHorizTile(false)
    right:SetVertTile(false)
    right:Show()

    local topCenter = FP_MODERN_WINDOW_SLOTS.topCenter
    local center = EnsureModernWindowRegion(frame, topCenter.key)
    center:ClearAllPoints()
    center:SetPoint("TOPLEFT", left, "TOPRIGHT")
    center:SetPoint("BOTTOMRIGHT", right, "BOTTOMLEFT")
    center:SetAtlas(topCenter.atlas, false)
    center:SetHorizTile(true)
    center:SetVertTile(false)
    center:Show()

    local bottomLeft = FP_MODERN_WINDOW_SLOTS.bottomLeft
    local bottomLeftRegion = EnsureModernWindowRegion(frame, bottomLeft.key)
    bottomLeftRegion:ClearAllPoints()
    bottomLeftRegion:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 7, 5)
    bottomLeftRegion:SetAtlas(bottomLeft.atlas, true)
    bottomLeftRegion:SetHorizTile(false)
    bottomLeftRegion:SetVertTile(false)
    bottomLeftRegion:Show()

    local bottomRight = FP_MODERN_WINDOW_SLOTS.bottomRight
    local bottomRightRegion = EnsureModernWindowRegion(frame, bottomRight.key)
    bottomRightRegion:ClearAllPoints()
    bottomRightRegion:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -3, 5)
    bottomRightRegion:SetAtlas(bottomRight.atlas, true)
    bottomRightRegion:SetHorizTile(false)
    bottomRightRegion:SetVertTile(false)
    bottomRightRegion:Show()

    local bottomCenter = FP_MODERN_WINDOW_SLOTS.bottomCenter
    local bottomCenterRegion = EnsureModernWindowRegion(frame, bottomCenter.key)
    bottomCenterRegion:ClearAllPoints()
    bottomCenterRegion:SetPoint("BOTTOMLEFT", bottomLeftRegion, "BOTTOMRIGHT")
    bottomCenterRegion:SetPoint("TOPRIGHT", bottomRightRegion, "TOPLEFT")
    bottomCenterRegion:SetAtlas(bottomCenter.atlas, false)
    bottomCenterRegion:SetHorizTile(true)
    bottomCenterRegion:SetVertTile(false)
    bottomCenterRegion:Show()

    local sideLeft = FP_MODERN_WINDOW_SLOTS.left
    local sideLeftRegion = EnsureModernWindowRegion(frame, sideLeft.key)
    sideLeftRegion:ClearAllPoints()
    sideLeftRegion:SetPoint("TOPLEFT", left, "BOTTOMLEFT")
    sideLeftRegion:SetPoint("BOTTOMRIGHT", bottomLeftRegion, "TOPRIGHT")
    sideLeftRegion:SetAtlas(sideLeft.atlas, false)
    sideLeftRegion:SetHorizTile(false)
    sideLeftRegion:SetVertTile(true)
    sideLeftRegion:Show()

    local sideRight = FP_MODERN_WINDOW_SLOTS.right
    local sideRightRegion = EnsureModernWindowRegion(frame, sideRight.key)
    sideRightRegion:ClearAllPoints()
    sideRightRegion:SetPoint("TOPRIGHT", right, "BOTTOMRIGHT")
    sideRightRegion:SetPoint("BOTTOMLEFT", bottomRightRegion, "TOPLEFT")
    sideRightRegion:SetAtlas(sideRight.atlas, false)
    sideRightRegion:SetHorizTile(false)
    sideRightRegion:SetVertTile(true)
    sideRightRegion:Show()
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

-- Semantic opt-in only: the style name "label" is also used by values/help.
-- Context contains product semantics, never snapshots of a rendered FontString.
local labelTypographyKey = "fpLabelTypography"
function FormWidgets.ApplyLabelTypography(widget, canonicalOnly)
    local binding = widget and widget.GetUserData and widget:GetUserData(labelTypographyKey)
    if not binding then return end
    local preview = ns.GUI.PresentationPreview
    local descriptor = preview.ResolveTypographyPresentation(binding.target, canonicalOnly)
    local textStyles = GetTextStyles()
    local slot = widget[binding.slot]
    if not descriptor or not textStyles or not slot then return end
    local api = ns.Ace and ns.Ace.PresentationPreview
    local overrides = not canonicalOnly and api and api.GetTypographyOverrides(binding.target) or {}
    local skins = ns.GUI.Skins
    local resolvedFont = preview.ResolveTypographyFont(descriptor.font)
    local font = overrides.font and resolvedFont
        or (skins and skins.GetDefaultFont and skins.GetDefaultFont(resolvedFont))
        or resolvedFont or STANDARD_TEXT_FONT
    local role = binding.disabledRole and binding.disabled and "disabled" or "label"
    local color = overrides.color or (role == "disabled" and textStyles.Get(role)) or descriptor.color
    textStyles.ApplyFontString(slot, role, {
        font = font, size = descriptor.size, flags = descriptor.flags,
        alpha = descriptor.alpha, shadow = descriptor.shadowEnabled,
    })
    slot:SetTextColor(color[1] or color.r, color[2] or color.g, color[3] or color.b, descriptor.alpha)
end

function FormWidgets.BindLabelTypography(widget, slot, target, disabledRole)
    local preview = ns.GUI.PresentationPreview
    if not preview or not preview.BindTypographyWidget or not widget or not widget[slot]
        or (target ~= "inspector_label" and target ~= "sidebar_label") then return end
    local binding = widget:GetUserData(labelTypographyKey)
    if not binding then
        binding = { originalSetDisabled = widget.SetDisabled, onRelease = widget.events and widget.events.OnRelease }
        widget:SetUserData(labelTypographyKey, binding)
        if binding.originalSetDisabled then
            binding.setDisabled = function(owner, disabled)
                local result = binding.originalSetDisabled(owner, disabled)
                binding.disabled = disabled == true
                FormWidgets.ApplyLabelTypography(owner)
                return result
            end
            widget.SetDisabled = binding.setDisabled
        end
        widget:SetCallback("OnRelease", function(owner, event)
            if owner.SetDisabled == binding.setDisabled then owner.SetDisabled = binding.originalSetDisabled end
            owner:SetUserData(labelTypographyKey, nil)
            if binding.onRelease then binding.onRelease(owner, event) end
        end)
    end
    binding.slot, binding.target = slot, target
    binding.disabledRole, binding.disabled = disabledRole == true, widget.disabled == true
    preview.BindTypographyWidget(widget, { target }, FormWidgets.ApplyLabelTypography)
    FormWidgets.ApplyLabelTypography(widget)
end

function FormWidgets.ApplyTextPresentation(owner, presentation)
    if not owner then
        return nil
    end

    presentation = type(presentation) == "table" and presentation or {}
    local target = owner.titletext or owner.label
    local frame = owner.frame
    if not target then
        return nil
    end

    local role = presentation.role or "label"
    local skins = ns.GUI and ns.GUI.Skins or nil
    local defaultFont = skins and skins.GetDefaultFont and skins.GetDefaultFont(STANDARD_TEXT_FONT) or STANDARD_TEXT_FONT
    local fontFace = presentation.fontFace or defaultFont
    local fontSize = presentation.fontSize or 13
    local fontFlags = presentation.fontFlags or ""
    local textStyles = GetTextStyles()
    if textStyles and textStyles.ApplyFontString then
        textStyles.ApplyFontString(target, role, {
            font = fontFace,
            size = fontSize,
            flags = fontFlags,
            alpha = presentation.alpha ~= nil and presentation.alpha or 1,
            shadow = presentation.shadowEnabled,
        })
    elseif target.SetFont then
        target:SetFont(fontFace, fontSize, fontFlags)
    end

    if presentation.color and target.SetTextColor then
        local color = presentation.color
        target:SetTextColor(
            color[1] or 1,
            color[2] or 1,
            color[3] or 1,
            presentation.alpha ~= nil and presentation.alpha or (color[4] ~= nil and color[4] or 1)
        )
    end

    local headerInsetX = presentation.headerInsetX
    local headerTopGap = presentation.headerTopGap
    local offsetX = presentation.offsetX or 0
    local offsetY = presentation.offsetY or 0
    if frame and target.ClearAllPoints
        and (headerInsetX ~= nil or headerTopGap ~= nil or presentation.offsetX ~= nil or presentation.offsetY ~= nil)
    then
        local x = (headerInsetX or 0) + offsetX
        local y = (headerTopGap or 0) + offsetY
        target:ClearAllPoints()
        target:SetPoint("TOPLEFT", frame, "TOPLEFT", x, -y)
        target:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -x, -y)
    end

    return target
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

    -- AceGUI's native Button textures are the canonical presentation.
    -- Keep this helper for sizing/text compatibility, but do not replace the
    -- widget's normal, pushed, highlight, or disabled regions.

    if FormWidgets.ResetInspectorButtonState then
        FormWidgets.ResetInspectorButtonState(button)
    end

    local resolvedVariant = ResolveButtonVariantFromRole(variant)
    local style = FormWidgets.ResolveButtonStyle(resolvedVariant)

    button:SetHeight(style.height or 24)

    local frame = button.frame
    local nativeTextures = {
        frame.GetNormalTexture and frame:GetNormalTexture() or nil,
        frame.GetPushedTexture and frame:GetPushedTexture() or nil,
        frame.GetHighlightTexture and frame:GetHighlightTexture() or nil,
        frame.GetDisabledTexture and frame:GetDisabledTexture() or nil,
    }
    for _, texture in ipairs(nativeTextures) do
        if texture then
            if texture.SetVertexColor then texture:SetVertexColor(1, 1, 1, 1) end
            if texture.SetAlpha then texture:SetAlpha(1) end
            if texture.Show then texture:Show() end
        end
    end
    for _, key in ipairs({
        "__fpActionVisualBg", "__fpActionVisualTexture",
        "__fpActionVisualBorder", "__fpActionVisualAccent",
        "__fpForgedCenter", "__fpForgedLeftEndcap",
        "__fpForgedRightEndcap", "__fpForgedIcon",
    }) do
        local region = button[key]
        if region and region.Hide then region:Hide() end
    end
    button.__fpModalLastRole = nil
    button.__fpModalForgedMetal = nil
    button.__fpModalIcon = nil
end

function FormWidgets.ApplyModalActionButtonVisual(button, role)
    if not button or not button.frame then
        return
    end

    button.__fpModalHovered = false
    button.__fpModalPressed = false
    FormWidgets.StyleActionButton(button, role)
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

function FormWidgets.StyleDropdown(dropdown, variant, valueRole)
    if not dropdown then
        return
    end

    local chromeColors = GetChromeColors()
    local style = FormWidgets.ResolveFieldStyle(variant)

    FormWidgets.ApplyTextStyle(dropdown.label, "label", 12, 1)
    if dropdown.text and dropdown.text.SetTextColor then
        if valueRole and FormWidgets.ApplyTextStyle then
            FormWidgets.ApplyTextStyle(dropdown.text, valueRole, nil, 1)
        else
            local valueColor = style.valueColor or GetItemColors().value
            dropdown.text:SetTextColor(valueColor[1] or 1, valueColor[2] or 1, valueColor[3] or 1, 1)
        end
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
    FormWidgets.ApplyLabelTypography(dropdown)
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

function FormWidgets.StyleEditBox(editBox, variant, valueRole)
    if not editBox then
        return
    end

    local chromeColors = GetChromeColors()
    local style = FormWidgets.ResolveFieldStyle(variant)

    FormWidgets.ApplyTextStyle(editBox.label, "label", 12, 1)

    if editBox.editbox then
        if editBox.editbox.SetTextColor then
            if valueRole and FormWidgets.ApplyTextStyle then
                FormWidgets.ApplyTextStyle(editBox.editbox, valueRole, nil, 1)
            else
                local valueColor = style.valueColor or GetItemColors().value
                editBox.editbox:SetTextColor(valueColor[1] or 1, valueColor[2] or 1, valueColor[3] or 1, 1)
            end
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
    local binding = checkbox.GetUserData and checkbox:GetUserData(labelTypographyKey)
    if binding then binding.disabled = disabled == true end
    FormWidgets.ApplyLabelTypography(checkbox)
end

function FormWidgets.ApplyWindowChrome(window, options)
    if not window or not window.frame then
        return
    end

    options = options or {}
    if options.nativeFrameShell then
        options = {
            shellInset = 0,
            headerHeight = 24,
            headerSeparator = true,
            showContentAccent = false,
        }
    end
    local chromeColors = GetChromeColors()
    local frame = window.frame
    local content = window.content
    local hasShellInset = options.shellInset ~= nil
    local shellInset = hasShellInset and options.shellInset or 12
    local shellTopInset = hasShellInset and -shellInset or -30
    local shellBottomInset = hasShellInset and shellInset or 12
    local headerHeight = options.headerHeight or 26

    ResetModernWindowTitleBar(frame)
    HideDefaultWindowChrome(frame)

    if window.titletext then
        FormWidgets.ApplyTextStyle(window.titletext, "sectionHeader", 15, 1)
    end

    if not frame._fpPanelFill then
        frame._fpPanelFill = frame:CreateTexture(nil, "ARTWORK")
    end
    frame._fpPanelFill:ClearAllPoints()
    frame._fpPanelFill:SetPoint("TOPLEFT", frame, "TOPLEFT", shellInset, shellTopInset)
    frame._fpPanelFill:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -shellInset, shellBottomInset)
    frame._fpPanelFill:SetColorTexture(unpack(chromeColors.panelBackground or {}))
    frame._fpPanelFill:Show()

    if not frame._fpPanelHeaderFill then
        frame._fpPanelHeaderFill = frame:CreateTexture(nil, "ARTWORK")
    end
    frame._fpPanelHeaderFill:ClearAllPoints()
    frame._fpPanelHeaderFill:SetPoint("TOPLEFT", frame, "TOPLEFT", shellInset, shellTopInset)
    frame._fpPanelHeaderFill:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -shellInset, shellTopInset)
    frame._fpPanelHeaderFill:SetHeight(headerHeight)
    frame._fpPanelHeaderFill:SetColorTexture(unpack(chromeColors.panelHeader or {}))
    frame._fpPanelHeaderFill:Show()

    if not frame._fpPanelTopShade then
        frame._fpPanelTopShade = frame:CreateTexture(nil, "ARTWORK")
    end
    frame._fpPanelTopShade:ClearAllPoints()
    frame._fpPanelTopShade:SetPoint("TOPLEFT", frame, "TOPLEFT", shellInset + 1, shellTopInset - 1)
    frame._fpPanelTopShade:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -(shellInset + 1), shellTopInset - 1)
    frame._fpPanelTopShade:SetHeight(1)
    frame._fpPanelTopShade:SetColorTexture(unpack(chromeColors.panelTopShade or {}))
    frame._fpPanelTopShade:Show()

    if not frame._fpPanelBottomShade then
        frame._fpPanelBottomShade = frame:CreateTexture(nil, "ARTWORK")
    end
    frame._fpPanelBottomShade:ClearAllPoints()
    frame._fpPanelBottomShade:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", shellInset + 1, shellBottomInset + 1)
    frame._fpPanelBottomShade:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -(shellInset + 1), shellBottomInset + 1)
    frame._fpPanelBottomShade:SetHeight(1)
    frame._fpPanelBottomShade:SetColorTexture(unpack(chromeColors.panelBottomShade or {}))
    frame._fpPanelBottomShade:Show()

    local function EnsureBorder(name)
        if not frame[name] then
            frame[name] = frame:CreateTexture(nil, "BORDER")
        end
        frame[name]:SetColorTexture(unpack(chromeColors.panelBorder or {}))
        frame[name]:Show()
    end

    EnsureBorder("_fpPanelBorderTop")
    frame._fpPanelBorderTop:ClearAllPoints()
    frame._fpPanelBorderTop:SetPoint("TOPLEFT", frame, "TOPLEFT", shellInset, shellTopInset)
    frame._fpPanelBorderTop:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -shellInset, shellTopInset)
    frame._fpPanelBorderTop:SetHeight(1)

    EnsureBorder("_fpPanelBorderBottom")
    frame._fpPanelBorderBottom:ClearAllPoints()
    frame._fpPanelBorderBottom:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", shellInset, shellBottomInset)
    frame._fpPanelBorderBottom:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -shellInset, shellBottomInset)
    frame._fpPanelBorderBottom:SetHeight(1)

    EnsureBorder("_fpPanelBorderLeft")
    frame._fpPanelBorderLeft:ClearAllPoints()
    frame._fpPanelBorderLeft:SetPoint("TOPLEFT", frame, "TOPLEFT", shellInset, shellTopInset)
    frame._fpPanelBorderLeft:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", shellInset, shellBottomInset)
    frame._fpPanelBorderLeft:SetWidth(1)

    EnsureBorder("_fpPanelBorderRight")
    frame._fpPanelBorderRight:ClearAllPoints()
    frame._fpPanelBorderRight:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -shellInset, shellTopInset)
    frame._fpPanelBorderRight:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -shellInset, shellBottomInset)
    frame._fpPanelBorderRight:SetWidth(1)

    local function EnsureInnerBorder(name)
        if not frame[name] then
            frame[name] = frame:CreateTexture(nil, "BORDER")
        end
        frame[name]:SetColorTexture(unpack(chromeColors.panelInnerBorder or chromeColors.sectionBorder or {}))
        frame[name]:Show()
    end

    EnsureInnerBorder("_fpPanelInnerTop")
    frame._fpPanelInnerTop:ClearAllPoints()
    frame._fpPanelInnerTop:SetPoint("TOPLEFT", frame, "TOPLEFT", shellInset + 1, shellTopInset - 1)
    frame._fpPanelInnerTop:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -(shellInset + 1), shellTopInset - 1)
    frame._fpPanelInnerTop:SetHeight(1)

    EnsureInnerBorder("_fpPanelInnerBottom")
    frame._fpPanelInnerBottom:ClearAllPoints()
    frame._fpPanelInnerBottom:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", shellInset + 1, shellBottomInset + 1)
    frame._fpPanelInnerBottom:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -(shellInset + 1), shellBottomInset + 1)
    frame._fpPanelInnerBottom:SetHeight(1)

    EnsureInnerBorder("_fpPanelInnerLeft")
    frame._fpPanelInnerLeft:ClearAllPoints()
    frame._fpPanelInnerLeft:SetPoint("TOPLEFT", frame, "TOPLEFT", shellInset + 1, shellTopInset - 1)
    frame._fpPanelInnerLeft:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", shellInset + 1, shellBottomInset + 1)
    frame._fpPanelInnerLeft:SetWidth(1)

    EnsureInnerBorder("_fpPanelInnerRight")
    frame._fpPanelInnerRight:ClearAllPoints()
    frame._fpPanelInnerRight:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -(shellInset + 1), shellTopInset - 1)
    frame._fpPanelInnerRight:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -(shellInset + 1), shellBottomInset + 1)
    frame._fpPanelInnerRight:SetWidth(1)

    if options.headerSeparator then
        if not frame._fpPanelHeaderSeparator then
            frame._fpPanelHeaderSeparator = frame:CreateTexture(nil, "BORDER")
        end
        frame._fpPanelHeaderSeparator:ClearAllPoints()
        frame._fpPanelHeaderSeparator:SetPoint("TOPLEFT", frame, "TOPLEFT", shellInset + 1, shellTopInset - headerHeight)
        frame._fpPanelHeaderSeparator:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -(shellInset + 1), shellTopInset - headerHeight)
        frame._fpPanelHeaderSeparator:SetHeight(1)
        frame._fpPanelHeaderSeparator:SetColorTexture(unpack(chromeColors.panelInnerBorder or chromeColors.sectionBorder or {}))
        frame._fpPanelHeaderSeparator:Show()
    elseif frame._fpPanelHeaderSeparator then
        frame._fpPanelHeaderSeparator:Hide()
    end

    if content and options.showContentAccent ~= false then
        if not content._fpAccent then
            content._fpAccent = content:CreateTexture(nil, "BORDER")
            content._fpAccent:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -2)
            content._fpAccent:SetPoint("TOPRIGHT", content, "TOPRIGHT", 0, -2)
            content._fpAccent:SetHeight(1)
        end
        content._fpAccent:SetColorTexture(unpack(chromeColors.accent or {}))
        content._fpAccent:Show()
    elseif content and content._fpAccent then
        content._fpAccent:Hide()
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

local function SetCompactDialogTiling(texture, enabled)
    if texture and texture.SetHorizTile then
        texture:SetHorizTile(enabled == true)
    end
    if texture and texture.SetVertTile then
        texture:SetVertTile(enabled == true)
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

local function HideCompactDialogWindowChrome(window)
    local frame = window and window.frame
    if not frame then
        return
    end

    for _, key in ipairs({
        "_fpCompactDialogOuterFill",
        "_fpCompactDialogHeaderFill",
        "_fpCompactDialogHeaderDivider",
        "_fpCompactDialogBottomShade",
        "_fpCompactDialogBorderTop",
        "_fpCompactDialogBorderBottom",
        "_fpCompactDialogBorderLeft",
        "_fpCompactDialogBorderRight",
        "_fpCompactDialogInnerTop",
        "_fpCompactDialogInnerBottom",
        "_fpCompactDialogInnerLeft",
        "_fpCompactDialogInnerRight",
    }) do
        if frame[key] then
            frame[key]:Hide()
        end
    end
end

function FormWidgets.ApplySurfacePresentation(widget, key, options)
    local frame = widget and widget.frame
    if not frame then
        return
    end

    options = options or {}
    local chromeColors = GetChromeColors()
    local prefix = (options.prefix or "_fpSurface") .. (key or "Surface")

    local fill = EnsureCompactDialogTexture(frame, prefix .. "Fill", "BACKGROUND")
    SetCompactDialogPointPair(fill, "TOPLEFT", frame, 0, 0, "BOTTOMRIGHT", frame, 0, 0)
    local material = options.material
    if material and material.material == "texture" and material.texture and fill.SetTexture then
        fill:SetTexture(material.texture)
        fill:SetTexCoord(0, 1, 0, 1)
        SetCompactDialogTiling(fill, material.tile)
        fill:SetVertexColor(unpack(material.tint or { 1, 1, 1, 1 }))
    else
        SetCompactDialogTiling(fill, false)
        SetCompactDialogColor(fill, options.fill or (options.actionBar and chromeColors.sectionFillStrong) or chromeColors.sectionFill)
    end

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

local function ApplyCompactDialogWindowContentSurface(frame, material)
    if not frame then
        return
    end

    local surface = EnsureCompactDialogTexture(frame, "_fpCompactDialogWindowContentSurface", "BACKGROUND")
    SetCompactDialogPointPair(surface, "TOPLEFT", frame, 0, 0, "BOTTOMRIGHT", frame, 0, 0)
    if material and material.material == "texture" and material.texture and surface.SetTexture then
        surface:SetTexture(material.texture)
        surface:SetTexCoord(0, 1, 0, 1)
        SetCompactDialogTiling(surface, material.tile)
        surface:SetVertexColor(unpack(material.tint or { 1, 1, 1, 1 }))
        surface:Show()
        return
    end

    SetCompactDialogTiling(surface, false)
    surface:SetTexture(nil)
    surface:Hide()
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
    if previousShell and previousShell.Release then previousShell:Release() end
    local contentInset = options.contentInset or 14
    local shellFrames = window.frame._fpCompactFormShellFrames
    if not shellFrames then shellFrames = {}; window.frame._fpCompactFormShellFrames = shellFrames end
    local function AcquireShellFrame(key, parent)
        local frame = shellFrames[key]
        if not frame then frame = CreateFrame("Frame", nil, parent); shellFrames[key] = frame
        else frame:SetParent(parent); frame:ClearAllPoints() end
        frame:Show()
        return frame
    end
    local shellFrame = AcquireShellFrame("shell", window.content)
    shellFrame:ClearAllPoints()
    shellFrame:SetPoint("TOPLEFT", window.content, "TOPLEFT", 0, 0)
    shellFrame:SetPoint("BOTTOMRIGHT", window.content, "BOTTOMRIGHT", 0, 0)
    local contentFrame = AcquireShellFrame("content", shellFrame)
    contentFrame:SetPoint("TOPLEFT", shellFrame, "TOPLEFT", contentInset, 0)
    contentFrame:SetPoint("BOTTOMRIGHT", shellFrame, "BOTTOMRIGHT", -contentInset, 0)
    local contentMaterial = GetCompactDialogContentSurface(options.contentSurface)
    local transparent = { 0, 0, 0, 0 }
    ApplyCompactDialogWindowContentSurface(shellFrame, contentMaterial)
    FormWidgets.ApplySurfacePresentation({ frame = contentFrame }, "Body", {
        prefix = "_fpCompactDialog",
        fill = contentMaterial and transparent or options.bodyFill,
        topShade = contentMaterial and transparent or nil,
        bottomShade = contentMaterial and transparent or nil,
        border = contentMaterial and transparent or options.bodyBorder,
    })
    local body = CreateSmallWindowRegion(contentFrame, options.bodyLayout or "List", {
        { "TOPLEFT", contentFrame, "TOPLEFT", 9, -6 },
        { "BOTTOMRIGHT", contentFrame, "BOTTOMRIGHT", -9, 0 },
    })
    local shell = {
        frame = shellFrame,
        body = body,
        contentRoot = body,
        contentWidth = math.max(1, (options.width or 420) - (contentInset * 2)),
    }
    function shell:Release()
        if self.body then AceGUI:Release(self.body) end
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

    local contentTopPadding = 6
    -- AceGUI Window reserves 57 px around its content frame.
    local calculatedHeight = 57 + contentHeight + contentTopPadding
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

    local useCanonicalWindowShell = options.useCanonicalWindowShell ~= false
    FormWidgets.ApplyWindowChrome(window, useCanonicalWindowShell and { nativeFrameShell = true } or nil)
    if useCanonicalWindowShell then
        HideCompactDialogWindowChrome(window)
    else
        ApplyCompactDialogWindowChrome(window)
    end
    FormWidgets.EnsureStandardWindowCloseButton(window)
    EnableCompactDialogEscapeClose(window)

    local shell = CreateCompactFormShell(window, options)
    local statusTextRoles = {
        neutral = "help",
        error = "statusError",
        success = "statusSuccess",
    }

    local function ApplyStatusStyle(target, role)
        local textRole = statusTextRoles[role] or statusTextRoles.neutral
        if target and FormWidgets.ApplyTextStyle then
            FormWidgets.ApplyTextStyle(target.label, textRole, 10, 1)
        end
    end

    local dialog = {
        window = window,
        root = shell,
        bodyShell = shell.body and { frame = shell.body.frame } or nil,
        body = shell.body,
        contentRoot = shell.contentRoot,
        contentWidth = shell.contentWidth,
        shell = shell,
    }

    function dialog:SetStatus(message, role, statusTarget)
        local hasMessage = type(message) == "string" and message ~= ""
        role = hasMessage and (statusTextRoles[role] and role or "neutral") or "neutral"
        local target = statusTarget
        ApplyStatusStyle(target, role)
        self.statusRole = role
        if target then
            target:SetText(hasMessage and message or " ")
        end
    end

    function dialog:SetActions(actions, actionContainer)
        actions = actions or {}
        local container = actionContainer
        if not container then
            error("CreateCompactFormDialog:SetActions requires an actionContainer")
        end
        container:ReleaseChildren()
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
                icon = action.icon,
            })
        end

        AddAction("primary", primary, "primary_action", 120)
        AddAction("secondary", secondary, "utility", 110)
        AddAction("cancel", cancel, "utility", 110)

        local measuredContainerWidth = container.frame:GetWidth()
        local containerWidth = (measuredContainerWidth and measuredContainerWidth > 0 and measuredContainerWidth) or self.contentWidth or 388
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
            FormWidgets.ApplyModalActionButtonVisual(button, entry.role, {
                icon = entry.icon,
            })
            button:SetCallback("OnClick", function()
                if entry.action.onClick then
                    entry.action.onClick(self)
                end
            end)
            container:AddChild(button)
            entry.button = button

            if entry.key == "primary" then
                self.primaryButton = button
            elseif entry.key == "secondary" then
                self.secondaryButton = button
            elseif entry.key == "cancel" then
                self.cancelButton = button
            end
        end

        if container.DoLayout then
            container:DoLayout()
        end

        local groupStart = 0
        if #actionButtons == 1 then
            groupStart = math.max(0, math.floor((containerWidth - groupWidth) / 2))
        elseif #actionButtons > 1 then
            groupStart = math.max(0, containerWidth - groupWidth)
        end

        local actionX = groupStart
        for _, entry in ipairs(actionButtons) do
            local frame = entry.button and entry.button.frame or nil
            if frame then
                frame:ClearAllPoints()
                -- LEFT-to-LEFT anchors use the vertical midpoint of the action container.
                frame:SetPoint("LEFT", container.frame, "LEFT", actionX, 0)
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

function FormWidgets.CreateCompactConfirmation(options)
    options = options or {}

    local messageHeight = options.messageHeight or 44
    local hintHeight = type(options.hint) == "string" and options.hint ~= "" and (options.hintHeight or 16) or 0
    local messageHintGap = hintHeight > 0 and (options.messageHintGap or 4) or 0
    local messageStatusGap = options.messageStatusGap or 6
    local statusHeight = options.statusHeight or 16
    local statusActionGap = options.statusActionGap or 6
    local actionHeight = options.actionHeight or 30
    local bottomPadding = options.bottomPadding or 6
    local dialog = FormWidgets.CreateCompactFormDialog({
        title = options.title or "",
        width = options.width or 420,
        height = 57 + messageHeight + messageHintGap + hintHeight + messageStatusGap + statusHeight + statusActionGap + actionHeight + bottomPadding,
        bodyLayout = "List",
        addBodySpacer = false,
        contentRoot = true,
    })
    if not dialog then
        return nil
    end

    local function AddSpacer(height)
        local spacer = AceGUI:Create("Label")
        spacer:SetText("")
        spacer:SetFullWidth(true)
        spacer:SetHeight(height)
        dialog.body:AddChild(spacer)
    end

    local message = FormWidgets.CreateBodyText(options.message or "", "label", 12, nil, dialog.contentWidth, false)
    message:SetFullWidth(true)
    message:SetHeight(messageHeight)
    dialog.body:AddChild(message)

    if hintHeight > 0 then
        AddSpacer(messageHintGap)
        local hint = FormWidgets.CreateBodyText(options.hint, "help", 11, nil, dialog.contentWidth, false)
        hint:SetFullWidth(true)
        hint:SetHeight(hintHeight)
        dialog.body:AddChild(hint)
    end

    AddSpacer(messageStatusGap)

    local status = AceGUI:Create("Label")
    status:SetText(" ")
    status:SetFullWidth(true)
    status:SetHeight(statusHeight)
    if FormWidgets.ApplyTextStyle and status.label then
        FormWidgets.ApplyTextStyle(status.label, "help", 10, 1)
    end
    dialog.body:AddChild(status)

    AddSpacer(statusActionGap)

    local actionContainer = AceGUI:Create("SimpleGroup")
    actionContainer:SetFullWidth(true)
    actionContainer:SetHeight(actionHeight)
    actionContainer:SetLayout("Flow")
    if actionContainer.SetAutoAdjustHeight then
        actionContainer:SetAutoAdjustHeight(false)
    end
    dialog.body:AddChild(actionContainer)
    AddSpacer(bottomPadding)

    dialog.confirmationStatus = status
    dialog:SetActions({
        primary = options.primary,
        cancel = options.cancel,
    }, actionContainer)

    return dialog
end
function FormWidgets.GetSidebarShellFill()
    local palette = GetFormPalette()
    local surface = palette.Chrome and palette.Chrome.navigatorShellSurface
    if surface and surface.material == "texture" then return surface.tint end
    return (palette.Chrome and palette.Chrome.panelBackground)
        or { 0.05, 0.06, 0.08, 0.84 }
end

function FormWidgets.ApplySidebarShellFill(window, target, canonicalOnly)
    local fill = window.frame and window.frame._fpSidebarPanelFill
    if not fill then return end
    local preview = ns.GUI.PresentationPreview
    local color = target and preview and preview.ResolveColor(target, canonicalOnly)
        or FormWidgets.GetSidebarShellFill()
    local surface = GetChromeColors().navigatorShellSurface
    if surface and surface.material == "texture" then
        fill:SetVertexColor(unpack(color))
    else
        fill:SetVertexColor(1, 1, 1, 1)
        fill:SetColorTexture(unpack(color))
    end
    fill:SetAlpha(1)
    fill:Show()
end

function FormWidgets.ApplySidebarChrome(window, previewTarget)
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
    local shellSurface = chromeColors.navigatorShellSurface
    if shellSurface and shellSurface.material == "texture" then
        local fill = frame._fpSidebarPanelFill
        local resolved = ns.MediaRegistry and ns.MediaRegistry.ResolveReference(shellSurface.textureId, "texture")
        local inset = previewTarget == "sidebar_shell" and 0 or 12
        fill:ClearAllPoints()
        fill:SetPoint("TOPLEFT", frame, "TOPLEFT", inset, -inset)
        fill:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -inset, inset)
        fill:SetTexture(resolved and resolved.available and resolved.resolvedAsset or nil, "CLAMP", "CLAMP")
        fill:SetTexCoord(0, 1, 0, 1)
        fill:SetHorizTile(false)
        fill:SetVertTile(false)
        fill:SetBlendMode("BLEND")
        fill:SetDrawLayer("BACKGROUND", -8)
    end
    FormWidgets.ApplySidebarShellFill(window, previewTarget)
    if previewTarget and ns.GUI.PresentationPreview then
        ns.GUI.PresentationPreview.BindWidget(window, { previewTarget }, function(owner, canonicalOnly)
            FormWidgets.ApplySidebarShellFill(owner, previewTarget, canonicalOnly)
        end)
    end

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
    if GetChromeColors().navigatorShellSurface then
        -- Match the material-only shell formerly shown by Composition. Content
        -- anchors stay at 12; only the Sidebar surface reaches the Window bounds.
        for _, key in ipairs({ "_fpSidebarPanelHeaderFill", "_fpSidebarPanelTopShade",
            "_fpSidebarPanelBottomShade", "_editorSidebar", "_editorSidebarBorder" }) do
            if frame[key] then frame[key]:Hide() end
        end
        if content and content._fpSidebarAccent then content._fpSidebarAccent:Hide() end
    end
    if window._fpNavigatorBrassTarget then FormWidgets.ApplyNavigatorBrassBorder(window) end
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
