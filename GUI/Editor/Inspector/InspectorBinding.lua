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

    -- Keep Inspector grouping color-only; the shared renderer still owns the regions.
    return {
        border = {
            color = chrome.sectionBorder,
            thickness = 1,
            inset = 0,
        },
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
        surface = {
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

    local resolved = ResolveInspectorSectionPresentation(style)
    if ApplySectionSurface then
        ApplySectionSurface(section, resolved)
    end
    if ApplySectionBorder then
        local border = resolved and resolved.border or nil
        ApplySectionBorder(section, border, resolved and resolved.surfaceInsets or nil)
    end
    ApplyInspectorSectionHeaderPresentation(section, textPresentation)

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

    return InspectorBinding.ApplyInspectorSectionStructure(createSection(container, title, {
        collapsible = true,
        key = sectionKey,
        state = state,
        defaultCollapsed = defaultCollapsed,
        onToggle = onToggle,
        localContentBuilder = sectionOptions.localContentBuilder,
        layoutRefresh = sectionOptions.layoutRefresh,
        forceExpanded = sectionOptions.forceExpanded,
        persistCollapse = sectionOptions.persistCollapse,
        titleTextRole = "strongHeading",
    }), "default", sectionOptions.textPresentation)
end

return InspectorBinding
