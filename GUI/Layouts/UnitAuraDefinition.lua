local addonName, ns = ...

ns.GUI = ns.GUI or {}
ns.GUI.Layouts = ns.GUI.Layouts or {}

ns.GUI.Layouts.UnitAuras = ns.GUI.Layouts.UnitAuras or {}

ns.GUI.Layouts.UnitAuras.Lists = {
    placement = {
        INSIDE = "VALUE_PORTRAIT_PLACEMENT_INSIDE",
        ATTACHED = "VALUE_PORTRAIT_PLACEMENT_ATTACHED",
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
    insideSide = {
        LEFT = "VALUE_SIDE_LEFT",
        RIGHT = "VALUE_SIDE_RIGHT",
        TOP = "VALUE_SIDE_TOP",
        BOTTOM = "VALUE_SIDE_BOTTOM",
    },
    growthX = {
        LEFT = "VALUE_SIDE_LEFT",
        RIGHT = "VALUE_SIDE_RIGHT",
    },
    growthY = {
        UP = "VALUE_DIRECTION_UP",
        DOWN = "VALUE_DIRECTION_DOWN",
    },
    sortMode = {
        NEWEST_FIRST = "VALUE_AURA_SORT_NEWEST_FIRST",
        OLDEST_FIRST = "VALUE_AURA_SORT_OLDEST_FIRST",
        TIME_REMAINING_ASC = "VALUE_AURA_SORT_TIME_REMAINING",
    },
}
