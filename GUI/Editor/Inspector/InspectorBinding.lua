local _, ns = ...

ns.GUI = ns.GUI or {}
ns.GUI.Editor = ns.GUI.Editor or {}
ns.GUI.Editor.Inspector = ns.GUI.Editor.Inspector or {}

local InspectorBinding = {}
ns.GUI.Editor.Inspector.InspectorBinding = InspectorBinding

local FormWidgets = ns.GUI.Helpers and ns.GUI.Helpers.FormWidgets or {}
local ResolveSectionStyle = FormWidgets.ResolveSectionStyle

local FormSectionSurfaceRenderer = ns.GUI.Helpers and ns.GUI.Helpers.FormSectionSurfaceRenderer or {}
local ApplySectionBorder = FormSectionSurfaceRenderer.ApplySectionBorder
local ApplySectionSurface = FormSectionSurfaceRenderer.ApplySectionSurface
local ApplySectionPadding = FormSectionSurfaceRenderer.ApplySectionPadding

local function GetEditorSectionRhythm()
    local skins = ns.GUI and ns.GUI.Skins or nil
    if skins and skins.GetEditorSectionRhythm then
        return skins.GetEditorSectionRhythm() or {}
    end
    return {}
end

local function ResolveInspectorSectionSurfaceStyle(style)
    if style == "prominent" then
        return "result_panel"
    end
    if style == "muted" then
        return "status_panel"
    end
    return "section_panel"
end

local function ResolveInspectorSectionPresentation(style)
    local skins = ns.GUI and ns.GUI.Skins or nil
    local palette = skins and skins.GetFormPalette and skins.GetFormPalette() or nil
    local chrome = palette and palette.Chrome or nil
    if not chrome or not chrome.sectionFill or not chrome.sectionBorder then
        return ResolveSectionStyle and ResolveSectionStyle(ResolveInspectorSectionSurfaceStyle(style)) or nil
    end

    local rhythm = GetEditorSectionRhythm()
    local outerMarginX = rhythm.outerMarginX or 0
    local accentInsetX = rhythm.accentInsetX or 0

    -- Canonical material and geometry; the shared renderer owns all regions.
    return {
        border = not chrome.inspectorSectionSurface and {
            color = chrome.sectionBorder,
            thickness = 1,
            inset = 0,
        } or false,
        surfaceInsets = {
            left = outerMarginX,
            right = outerMarginX,
            top = 0,
            bottom = 0,
        },
        -- Keep the existing 10px AceGUI content rhythm inside the visible
        -- 6px presentation surface without changing the section height.
        contentPadding = {
            left = 16,
            right = 16,
            top = 27,
            bottom = 13,
        },
        surface = chrome.inspectorSectionSurface or {
            fill = chrome.sectionFill,
            accent = {
                color = chrome.sectionAccent,
                edge = "top",
                thickness = 1,
                insetLeft = accentInsetX,
                insetRight = accentInsetX,
            },
        },
    }
end

local function ApplyInspectorSectionHeaderPresentation(section, textPresentation)
    if not FormWidgets.ApplyTextPresentation then
        return
    end

    local presentation = {}
    if type(textPresentation) == "table" then
        for key, value in pairs(textPresentation) do
            presentation[key] = value
        end
    end
    local rhythm = GetEditorSectionRhythm()
    presentation.role = presentation.role or "strongHeading"
    presentation.fontSize = presentation.fontSize or 13
    if presentation.headerInsetX == nil then
        presentation.headerInsetX = rhythm.headerInsetX or 0
    end
    if presentation.headerTopGap == nil then
        presentation.headerTopGap = rhythm.headerTopGap or 0
    end
    FormWidgets.ApplyTextPresentation(section, presentation)
end

local function ApplyInspectorSectionTypography(section, textPresentation, canonicalOnly)
    local preview = ns.GUI.PresentationPreview
    local descriptor = preview and preview.ResolveTypographyPresentation
        and preview.ResolveTypographyPresentation("inspector_section_heading", canonicalOnly)
    if not descriptor then
        ApplyInspectorSectionHeaderPresentation(section, textPresentation)
        return
    end

    local presentation = {}
    if type(textPresentation) == "table" then
        for key, value in pairs(textPresentation) do
            presentation[key] = value
        end
    end
    presentation.role = "strongHeading"
    presentation.fontSize = descriptor.size
    presentation.fontFlags = descriptor.flags
    presentation.alpha = descriptor.alpha
    presentation.shadowEnabled = descriptor.shadowEnabled
    presentation.color = {
        descriptor.color[1], descriptor.color[2], descriptor.color[3], descriptor.alpha,
    }

    if preview.ResolveTypographyFont then
        presentation.fontFace = preview.ResolveTypographyFont(descriptor.font)
    end
    ApplyInspectorSectionHeaderPresentation(section, presentation)
end

-- Shared canonical source for the public baseline and normal section builds.
InspectorBinding.ResolveSectionPresentation = ResolveInspectorSectionPresentation

local sectionTargets = { "inspector_section_surface", "inspector_section_border", "inspector_section_accent" }
local function ApplySectionPresentation(section, style, canonicalOnly, colorsOnly)
    local resolved = ResolveInspectorSectionPresentation(style)
    local composition = ns.GUI.PresentationCompositionPreview
    if composition and composition.Apply("inspector_section", section, resolved, canonicalOnly) then return resolved end
    local preview = ns.GUI.PresentationPreview
    if preview and resolved and resolved.surface then
        -- Only this fresh Inspector descriptor is overlaid, never SectionStyles.
        resolved = ns.GUI.Helpers.FormRenderer.CloneLayoutValue(resolved)
        local api = ns.Ace.PresentationPreview
        local function HasOverride(target)
            return not canonicalOnly and next(api.GetOverrides(target) or {}) ~= nil
        end
        local fillKey = resolved.surface.material == "texture" and "tint" or "fill"
        if HasOverride(sectionTargets[1]) then
            resolved.surface[fillKey] = preview.ResolveColor(sectionTargets[1]) or resolved.surface[fillKey]
        end
        if HasOverride(sectionTargets[2]) then
            local border = preview.ResolveColor(sectionTargets[2])
            if border and border[4] > 0 then
                resolved.border = resolved.border or { thickness = 1, inset = 0 }
                resolved.border.color = border
            else
                resolved.border = false
            end
        end
        if HasOverride(sectionTargets[3]) then
            if resolved.surface.topShade then
                resolved.surface.topShade = preview.ResolveColor(sectionTargets[3]) or resolved.surface.topShade
            elseif resolved.surface.accent then
                resolved.surface.accent.color = preview.ResolveColor(sectionTargets[3]) or resolved.surface.accent.color
            end
        end
    end
    if colorsOnly then
        FormSectionSurfaceRenderer.ApplySectionColors(section, resolved)
        -- An optional border preview may have created regions while the default
        -- has no border. Resolve their presence again on clear, not just RGB.
        if resolved.border and not section.frame._fpSectionBorderTop then
            ApplySectionBorder(section, resolved.border, resolved.surfaceInsets)
        else
            for _, edge in ipairs({ "Top", "Bottom", "Left", "Right" }) do
                local region = section.frame["_fpSectionBorder" .. edge]
                if region then
                    if resolved.border then region:Show() else region:Hide() end
                end
            end
        end
    else
        if ApplySectionSurface then ApplySectionSurface(section, resolved) end
        if ApplySectionBorder then
            ApplySectionBorder(section, resolved and resolved.border, resolved and resolved.surfaceInsets)
        end
    end
    return resolved
end

local function NeutralizeInspectorLegacyBoundary(section)
    local content = section and section.content or nil
    local border = content and content.GetParent and content:GetParent() or nil
    if not border then
        return
    end

    if border.SetBackdropColor then
        border:SetBackdropColor(0, 0, 0, 0)
    end
    if border.SetBackdropBorderColor then
        border:SetBackdropBorderColor(0, 0, 0, 0)
    end
    if border._fpAccent and border._fpAccent.Hide then
        border._fpAccent:Hide()
    end
end

function InspectorBinding.ApplyInspectorSectionStructure(section, style, textPresentation)
    if not section then
        return nil
    end

    local composition = ns.GUI.PresentationCompositionPreview
    if composition then
        composition.Bind("inspector_section", section, function(owner, canonicalOnly)
            ApplySectionPresentation(owner, style, canonicalOnly)
        end)
    end
    local resolved = ApplySectionPresentation(section, style)
    if ns.GUI.PresentationPreview then
        ns.GUI.PresentationPreview.BindWidget(section, sectionTargets, function(owner, canonicalOnly)
            if canonicalOnly and composition then composition.Release("inspector_section", owner) end
            ApplySectionPresentation(owner, style, canonicalOnly, not (canonicalOnly and composition))
        end)
        if ns.GUI.PresentationPreview.BindTypographyWidget then
            ns.GUI.PresentationPreview.BindTypographyWidget(section, { "inspector_section_heading" }, function(owner, canonicalOnly)
                ApplyInspectorSectionTypography(owner, textPresentation, canonicalOnly)
            end)
        end
    end
    ApplyInspectorSectionTypography(section, textPresentation)

    NeutralizeInspectorLegacyBoundary(section)
    if ApplySectionPadding and resolved then
        if resolved.contentPadding ~= nil then
            ApplySectionPadding(section, resolved.contentPadding)
        elseif resolved.padding ~= nil then
            local adjustedPadding = resolved.padding
            if style == "prominent" then
                adjustedPadding = adjustedPadding + 2
            else
                adjustedPadding = adjustedPadding + 1
            end
            ApplySectionPadding(section, adjustedPadding)
        end
    end

    return section
end

function InspectorBinding.CreateInspectorSection(container, createSection, state, sectionKey, title, defaultCollapsed, onToggle, extraOptions)
    local sectionOptions = extraOptions or {}
    sectionOptions.collapsible = true
    sectionOptions.key = sectionKey
    sectionOptions.state = state
    sectionOptions.defaultCollapsed = defaultCollapsed
    sectionOptions.onToggle = onToggle

    local contentBuilder = sectionOptions.localContentBuilder
    local section = createSection(container, title, {
        collapsible = true,
        key = sectionKey,
        state = state,
        defaultCollapsed = defaultCollapsed,
        onToggle = onToggle,
        localContentBuilder = contentBuilder and function(group)
            contentBuilder(group)
            -- Collapse/expand creates a fresh group without rebuilding the Inspector.
            InspectorBinding.ApplyInspectorSectionStructure(group, "default", sectionOptions.textPresentation)
        end,
        layoutRefresh = sectionOptions.layoutRefresh,
        forceExpanded = sectionOptions.forceExpanded,
        persistCollapse = sectionOptions.persistCollapse,
        titleTextRole = "strongHeading",
    })
    if contentBuilder then return section end
    return InspectorBinding.ApplyInspectorSectionStructure(section, "default", sectionOptions.textPresentation)
end

return InspectorBinding
