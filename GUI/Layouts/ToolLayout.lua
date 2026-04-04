local _, ns = ...

ns.GUI = ns.GUI or {}
ns.GUI.Layouts = ns.GUI.Layouts or {}

local ToolLayout = {}
ns.GUI.Layouts.ToolLayout = ToolLayout

ToolLayout.PAGE = {
    surface_width = 1000,
    container_width = 840,
    outer_padding = 0,
    section_gap = 10,
}

ToolLayout.SECTIONS = {
    single = {
        columns = 1,
        gap = 0,
    },
    two_column = {
        columns = 2,
        gap = 16,
        widths = { 412, 412 },
    },
    three_column = {
        columns = 3,
        gap = 16,
        widths = { 269, 269, 269 },
    },
}

ToolLayout.CELLS = {
    full = {
        content_layout = "List",
    },
    stack = {
        content_layout = "List",
    },
    inline = {
        content_layout = "Flow",
    },
}

ToolLayout.CONTROLS = {
    field_widths = {
        narrow = 220,
        compact = 280,
        medium = 360,
        wide = 376,
        full = 736,
    },
    button_widths = {
        small = 160,
        medium = 180,
        wide = 200,
        action = 220,
    },
}

function ToolLayout.GetSection(name)
    return ToolLayout.SECTIONS[name]
end

function ToolLayout.GetCell(name)
    return ToolLayout.CELLS[name]
end

return ToolLayout
