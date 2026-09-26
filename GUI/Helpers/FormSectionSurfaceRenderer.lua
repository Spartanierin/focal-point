local _, ns = ...

ns.GUI = ns.GUI or {}
ns.GUI.Helpers = ns.GUI.Helpers or {}

local FormSectionSurfaceRenderer = {}
ns.GUI.Helpers.FormSectionSurfaceRenderer = FormSectionSurfaceRenderer

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

local function GetItemColors()
    return GetFormPalette().ItemColors or {}
end

local function GetSectionStyles()
    return (ns.GUI.Layouts and ns.GUI.Layouts.FormElements and ns.GUI.Layouts.FormElements.SectionStyles) or {}
end

local function ResolveItemColor(colorKey)
    return colorKey and GetItemColors()[colorKey] or nil
end

local function ResolveSectionStyle(style)
    if type(style) == "table" then
        return style
    end

    return type(style) == "string" and GetSectionStyles()[style] or nil
end

local function ResolveSurfaceInsets(insets)
    if type(insets) ~= "table" then
        return 0, 0, 0, 0
    end

    return insets.left or 0, insets.right or 0, insets.top or 0, insets.bottom or 0
end

local function SetSurfaceBounds(region, frame, left, right, top, bottom)
    region:ClearAllPoints()
    region:SetPoint("TOPLEFT", frame, "TOPLEFT", left, -top)
    region:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -right, bottom)
end

function FormSectionSurfaceRenderer.ApplySectionBorder(group, border, surfaceInsets)
    if not group or not group.frame then
        return
    end

    local frame = group.frame
    local chromeColors = GetChromeColors()
    local color = type(border) == "table" and (border.color or ResolveItemColor(border.colorKey)) or chromeColors.sectionBorder
    local left, right, top, bottom = ResolveSurfaceInsets(surfaceInsets)

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
    left = left + inset
    right = right + inset
    top = top + inset
    bottom = bottom + inset

    local function EnsureBorder(name)
        if not frame[name] then
            frame[name] = frame:CreateTexture(nil, "BORDER")
        end
        frame[name]:SetColorTexture(unpack(color))
        frame[name]:Show()
    end

    EnsureBorder("_fpSectionBorderTop")
    frame._fpSectionBorderTop:ClearAllPoints()
    frame._fpSectionBorderTop:SetPoint("TOPLEFT", frame, "TOPLEFT", left, -top)
    frame._fpSectionBorderTop:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -right, -top)
    frame._fpSectionBorderTop:SetHeight(thickness)

    EnsureBorder("_fpSectionBorderBottom")
    frame._fpSectionBorderBottom:ClearAllPoints()
    frame._fpSectionBorderBottom:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", left, bottom)
    frame._fpSectionBorderBottom:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -right, bottom)
    frame._fpSectionBorderBottom:SetHeight(thickness)

    EnsureBorder("_fpSectionBorderLeft")
    frame._fpSectionBorderLeft:ClearAllPoints()
    frame._fpSectionBorderLeft:SetPoint("TOPLEFT", frame, "TOPLEFT", left, -top)
    frame._fpSectionBorderLeft:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", left, bottom)
    frame._fpSectionBorderLeft:SetWidth(thickness)

    EnsureBorder("_fpSectionBorderRight")
    frame._fpSectionBorderRight:ClearAllPoints()
    frame._fpSectionBorderRight:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -right, -top)
    frame._fpSectionBorderRight:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -right, bottom)
    frame._fpSectionBorderRight:SetWidth(thickness)
end

function FormSectionSurfaceRenderer.ApplySectionSurface(group, sectionStyle)
    if not group or not group.frame then
        return
    end

    local style = ResolveSectionStyle(sectionStyle)
    local surface = style and style.surface or nil
    local frame = group.frame
    local left, right, top, bottom = ResolveSurfaceInsets(style and style.surfaceInsets)

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

    local surfaceMaterial = surface.material or "color"
    local texture = surface.texture
    if surfaceMaterial == "texture" and surface.textureId then
        local registry = ns.MediaRegistry
        local resolved = registry and registry.ResolveReference(surface.textureId, "texture")
        texture = resolved and resolved.available and resolved.resolvedAsset or nil
    end
    if surfaceMaterial == "texture" and type(texture) == "string" then
        local fill = EnsureTexture("_fpSectionFill", "BACKGROUND")
        SetSurfaceBounds(fill, frame, left, right, top, bottom)
        fill:SetTexture(texture)
        fill:SetTexCoord(0, 1, 0, 1)
        fill:SetBlendMode("BLEND")
        fill:SetVertexColor(unpack(surface.tint or { 1, 1, 1, 1 }))
    elseif surface.fill then
        local fill = EnsureTexture("_fpSectionFill", "BACKGROUND")
        SetSurfaceBounds(fill, frame, left, right, top, bottom)
        fill:SetTexCoord(0, 1, 0, 1)
        fill:SetBlendMode("BLEND")
        fill:SetVertexColor(1, 1, 1, 1)
        fill:SetColorTexture(unpack(surface.fill))
    else
        HideTexture("_fpSectionFill")
    end

    if surface.topShade then
        local topShade = EnsureTexture("_fpSectionTopShade", "ARTWORK")
        topShade:ClearAllPoints()
        topShade:SetPoint("TOPLEFT", frame, "TOPLEFT", left, -top)
        topShade:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -right, -top)
        topShade:SetHeight(1)
        topShade:SetColorTexture(unpack(surface.topShade))
    else
        HideTexture("_fpSectionTopShade")
    end

    if surface.bottomShade then
        local bottomShade = EnsureTexture("_fpSectionBottomShade", "ARTWORK")
        bottomShade:ClearAllPoints()
        bottomShade:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", left, bottom)
        bottomShade:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -right, bottom)
        bottomShade:SetHeight(1)
        bottomShade:SetColorTexture(unpack(surface.bottomShade))
    else
        HideTexture("_fpSectionBottomShade")
    end

    if surface.accent then
        local accent = EnsureTexture("_fpSectionAccent", "BORDER")
        local edge = surface.accent.edge or "top"
        local thickness = surface.accent.thickness or 1
        local insetLeft = left + (surface.accent.insetLeft or 0)
        local insetRight = right + (surface.accent.insetRight or 0)
        accent:ClearAllPoints()
        if edge == "bottom" then
            accent:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", insetLeft, bottom)
            accent:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -insetRight, bottom)
        else
            accent:SetPoint("TOPLEFT", frame, "TOPLEFT", insetLeft, -top)
            accent:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -insetRight, -top)
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
        local material = surface.divider.material or "color"
        divider:ClearAllPoints()
        divider:SetPoint("TOP", frame, "TOP", 0, -insetTop)
        divider:SetPoint("BOTTOM", frame, "BOTTOM", 0, insetBottom)
        divider:SetWidth(thickness)

        -- The section owns divider geometry; the style chooses only its material.
        divider:SetBlendMode("BLEND")
        if material == "texture" and type(surface.divider.texture) == "string" then
            divider:SetTexture(surface.divider.texture)
            divider:SetTexCoord(0, 1, 0, 1)
            divider:SetVertexColor(unpack(surface.divider.color or { 1, 1, 1, 1 }))
        elseif material == "atlas" and type(surface.divider.atlas) == "string" then
            divider:SetAtlas(surface.divider.atlas, false)
            divider:SetVertexColor(unpack(surface.divider.color or { 1, 1, 1, 1 }))
        else
            -- Legacy definitions remain color dividers without a migration.
            divider:SetColorTexture(unpack(surface.divider.color or {}))
        end
    else
        HideTexture("_fpSectionDivider")
    end
end

-- Recolor the canonical material without touching anchors or padding.
function FormSectionSurfaceRenderer.ApplySectionColors(group, style)
    local frame = group and group.frame
    local surface = style and style.surface
    if not frame or not surface then return end
    local function ColorRegion(name, color)
        if frame[name] and color then frame[name]:SetColorTexture(unpack(color)) end
    end
    if surface.material == "texture" then
        if frame._fpSectionFill and surface.tint then frame._fpSectionFill:SetVertexColor(unpack(surface.tint)) end
    else
        ColorRegion("_fpSectionFill", surface.fill)
    end
    ColorRegion("_fpSectionTopShade", surface.topShade)
    ColorRegion("_fpSectionBottomShade", surface.bottomShade)
    ColorRegion("_fpSectionAccent", surface.accent and surface.accent.color)
    local border = style.border
    if type(border) == "table" then
        local color = border.color or ResolveItemColor(border.colorKey)
        for _, edge in ipairs({ "Top", "Bottom", "Left", "Right" }) do
            ColorRegion("_fpSectionBorder" .. edge, color)
        end
    elseif border == false then
        for _, edge in ipairs({ "Top", "Bottom", "Left", "Right" }) do
            ColorRegion("_fpSectionBorder" .. edge, { 0, 0, 0, 0 })
        end
    end
end

local function ResolvePadding(padding)
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

    return left, right, top, bottom
end

local function ApplyPaddingAwareContentWidth(group, outerWidth)
    if not group or not group.content or type(outerWidth) ~= "number" then
        return
    end

    local padding = group._fpSectionPadding
    if not padding then
        return
    end

    local innerWidth = math.max(0, outerWidth - (padding.left or 0) - (padding.right or 0))
    group.content:SetWidth(innerWidth)
    group.content.width = innerWidth
end

local function EnsurePaddingAwareWidth(group)
    if not group or group._fpPaddingAwareWidthWrapped then
        return
    end

    local originalOnWidthSet = group.OnWidthSet
    group._fpOriginalOnWidthSet = originalOnWidthSet
    group.OnWidthSet = function(widget, width)
        if type(widget._fpOriginalOnWidthSet) == "function" then
            widget._fpOriginalOnWidthSet(widget, width)
        end
        ApplyPaddingAwareContentWidth(widget, width)
    end
    group._fpPaddingAwareWidthWrapped = true
end

function FormSectionSurfaceRenderer.ApplySectionPadding(group, padding)
    if not group or not group.content or group.type == "ScrollFrame" then
        return
    end

    local anchor = group.frame
    local content = group.content
    local left, right, top, bottom = ResolvePadding(padding)
    group._fpSectionPadding = {
        left = left,
        right = right,
        top = top,
        bottom = bottom,
    }
    EnsurePaddingAwareWidth(group)

    content:ClearAllPoints()
    content:SetPoint("TOPLEFT", anchor, "TOPLEFT", left, -top)
    content:SetPoint("BOTTOMRIGHT", anchor, "BOTTOMRIGHT", -right, bottom)

    local outerWidth = group.frame and group.frame.GetWidth and group.frame:GetWidth() or nil
    ApplyPaddingAwareContentWidth(group, outerWidth)
end

return FormSectionSurfaceRenderer
