local addonName, ns = ...

ns.GUI = ns.GUI or {}
ns.GUI.Layouts = ns.GUI.Layouts or {}

ns.GUI.Layouts.UnitPortrait = ns.GUI.Layouts.UnitPortrait or {}

ns.GUI.Layouts.UnitPortrait.Lists = {
    placement = {
        INSIDE = "VALUE_PORTRAIT_PLACEMENT_INSIDE",
        ATTACHED = "VALUE_PORTRAIT_PLACEMENT_ATTACHED",
    },
    mode = {
        ["2D"] = "VALUE_PORTRAIT_MODE_2D",
        ["3D"] = "VALUE_PORTRAIT_MODE_3D",
    },
    insideSide = {
        LEFT = "VALUE_SIDE_LEFT",
        RIGHT = "VALUE_SIDE_RIGHT",
    },
    anchorTo = {
        Frame = "VALUE_ANCHOR_TARGET_FRAME",
        HealthBar = "VALUE_ANCHOR_TARGET_HEALTH_BAR",
        PowerBar = "VALUE_ANCHOR_TARGET_POWER_BAR",
    },
    anchorPoints = {
        TOPLEFT = "VALUE_ANCHOR_TOPLEFT",
        TOP = "VALUE_ANCHOR_TOP",
        TOPRIGHT = "VALUE_ANCHOR_TOPRIGHT",
        LEFT = "VALUE_ANCHOR_LEFT",
        CENTER = "VALUE_ANCHOR_CENTER",
        RIGHT = "VALUE_ANCHOR_RIGHT",
        BOTTOMLEFT = "VALUE_ANCHOR_BOTTOMLEFT",
        BOTTOM = "VALUE_ANCHOR_BOTTOM",
        BOTTOMRIGHT = "VALUE_ANCHOR_BOTTOMRIGHT",
    },
}
