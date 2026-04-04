local _, ns = ...

ns.GUI = ns.GUI or {}
ns.GUI.Styles = ns.GUI.Styles or {}

local ToolPageStyles = {}
ns.GUI.Styles.ToolPageStyles = ToolPageStyles

ToolPageStyles.page = {
    width = 880,
    padding = 16,
    section_gap = 12,
}

ToolPageStyles.spacing = {
    xs = 4,
    sm = 8,
    md = 12,
    lg = 16,
}

ToolPageStyles.row = {
    input_height = 64,
    button_height = 42,
}

ToolPageStyles.columns = {
    two = {
        left = 420,
        right = 420,
        gap = 16,
    },
}

ToolPageStyles.buttons = {
    small = 120,
    medium = 150,
    action = 170,
    wide = 200,
}

function ToolPageStyles.Get()
    return ToolPageStyles
end

return ToolPageStyles
