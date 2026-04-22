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

local function ResolveInspectorSectionSurfaceStyle(style)
    if style == "prominent" then
        return "result_panel"
    end
    if style == "muted" then
        return "status_panel"
    end
    return "section_panel"
end

function InspectorBinding.ApplyInspectorSectionStructure(section, style)
    if not section then
        return nil
    end

    local resolved = ResolveSectionStyle and ResolveSectionStyle(ResolveInspectorSectionSurfaceStyle(style)) or nil
    if ApplySectionSurface then
        ApplySectionSurface(section, resolved)
    end
    if ApplySectionBorder then
        local border = resolved and resolved.border or nil
        ApplySectionBorder(section, border)
    end
    if ApplySectionPadding and resolved and resolved.padding ~= nil then
        local adjustedPadding = resolved.padding
        if style == "prominent" then
            adjustedPadding = adjustedPadding + 2
        else
            adjustedPadding = adjustedPadding + 1
        end
        ApplySectionPadding(section, adjustedPadding)
    end

    return section
end

function InspectorBinding.CreateInspectorSection(container, createSection, state, sectionKey, title, defaultCollapsed, onToggle)
    return InspectorBinding.ApplyInspectorSectionStructure(createSection(container, title, {
        collapsible = true,
        key = sectionKey,
        state = state,
        defaultCollapsed = defaultCollapsed,
        onToggle = onToggle,
    }), "default")
end

return InspectorBinding
