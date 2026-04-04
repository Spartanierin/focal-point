local _, ns = ...

ns.GUI = ns.GUI or {}
ns.GUI.Styles = ns.GUI.Styles or {}

local ToolSurfaceStyles = {}
ns.GUI.Styles.ToolSurfaceStyles = ToolSurfaceStyles

ToolSurfaceStyles.page_surface = {
    background = { 0.07, 0.08, 0.10, 0.74 },
    border = { 0.16, 0.19, 0.24, 0.92 },
    accent = nil,
    header = nil,
    insets = { left = 15, top = 15, right = 15, bottom = 15 },
    content_mode = "dynamic",
}

ToolSurfaceStyles.page_container = {
    background = nil,
    border = nil,
    accent = nil,
    header = nil,
    insets = { left = 0, top = 0, right = 0, bottom = 0 },
    content_mode = "dynamic",
}

ToolSurfaceStyles.none = {
    background = nil,
    border = nil,
    accent = nil,
    header = nil,
    insets = { left = 0, top = 0, right = 0, bottom = 0 },
    content_mode = "dynamic",
}

ToolSurfaceStyles.panel = {
    background = { 0.07, 0.08, 0.10, 0.74 },
    border = { 0.16, 0.19, 0.24, 0.92 },
    accent = nil,
    header = { 0.10, 0.11, 0.14, 0.48 },
    insets = { left = 16, top = 12, right = 16, bottom = 14 },
    content_mode = "box",
}

ToolSurfaceStyles.accent_gold = {
    background = { 0.07, 0.08, 0.10, 0.74 },
    border = { 0.16, 0.19, 0.24, 0.92 },
    accent = { 0.91, 0.77, 0.29, 0.92 },
    header = { 0.10, 0.11, 0.14, 0.48 },
    insets = { left = 16, top = 12, right = 16, bottom = 14 },
    content_mode = "box",
}

ToolSurfaceStyles.subtle = {
    background = { 0.07, 0.08, 0.10, 0.58 },
    border = { 0.16, 0.19, 0.24, 0.72 },
    accent = nil,
    header = nil,
    insets = { left = 16, top = 12, right = 16, bottom = 14 },
    content_mode = "box",
}

function ToolSurfaceStyles.Get(name)
    return ToolSurfaceStyles[name or "none"] or ToolSurfaceStyles.none
end

return ToolSurfaceStyles
