local addonName, ns = ...

ns.GUI = ns.GUI or {}
ns.GUI.Layouts = ns.GUI.Layouts or {}

ns.GUI.Layouts.UnitAuras = ns.GUI.Layouts.UnitAuras or {}

ns.GUI.Layouts.UnitAuras.AuraTab = {
    {
        section = "SECTION_GENERAL",
        mode = "section",
        layout = "list",
        items = {
            { widget = "checkbox", path = { "Units", "$unitKey", "$auraKey", "enabled" }, label = "OPTION_AURA_ENABLED", description = "OPTION_AURA_ENABLED_DESC", fallback = true, refreshGUI = true, disabled = "unit", placement = "left", rowType = "standalone" },
            { widget = "dropdown", path = { "Units", "$unitKey", "$auraKey", "placement" }, label = "OPTION_AURA_PLACEMENT", description = "OPTION_AURA_PLACEMENT_DESC", list = "placement", fallback = "ATTACHED", refreshGUI = true, disabled = "aura", placement = "left" },
            { widget = "slider", path = { "Units", "$unitKey", "$auraKey", "iconSize" }, label = "OPTION_AURA_ICON_SIZE", description = "OPTION_AURA_ICON_SIZE_DESC", min = 12, max = 64, step = 1, fallback = 30, format = "%d", disabled = "aura", placement = "right" },
            { widget = "slider", path = { "Units", "$unitKey", "$auraKey", "iconsPerRow" }, label = "OPTION_AURA_ICONS_PER_ROW", description = "OPTION_AURA_ICONS_PER_ROW_DESC", min = 1, max = 20, step = 1, fallback = 5, format = "%d", disabled = "aura", placement = "left" },
            { widget = "slider", path = { "Units", "$unitKey", "$auraKey", "maxRows" }, label = "OPTION_AURA_MAX_ROWS", description = "OPTION_AURA_MAX_ROWS_DESC", min = 0, max = 10, step = 1, fallback = 0, format = "%d", disabled = "aura", placement = "right" },
        },
    },
    {
        section = "SECTION_STYLE",
        mode = "section",
        layout = "list",
        items = {
            { widget = "slider", path = { "Units", "$unitKey", "$auraKey", "spacingX" }, label = "OPTION_AURA_SPACING_X", description = "OPTION_AURA_SPACING_X_DESC", min = 0, max = 20, step = 1, fallback = 3, format = "%d", disabled = "aura", placement = "left" },
            { widget = "slider", path = { "Units", "$unitKey", "$auraKey", "spacingY" }, label = "OPTION_AURA_SPACING_Y", description = "OPTION_AURA_SPACING_Y_DESC", min = 0, max = 20, step = 1, fallback = 3, format = "%d", disabled = "aura", placement = "right" },
            { widget = "dropdown", path = { "Units", "$unitKey", "$auraKey", "growthX" }, label = "OPTION_AURA_GROWTH_X", description = "OPTION_AURA_GROWTH_X_DESC", list = "growthX", fallback = "RIGHT", disabled = "aura", placement = "left" },
            { widget = "dropdown", path = { "Units", "$unitKey", "$auraKey", "growthY" }, label = "OPTION_AURA_GROWTH_Y", description = "OPTION_AURA_GROWTH_Y_DESC", list = "growthY", fallback = "DOWN", disabled = "aura", placement = "right" },
            { widget = "dropdown", path = { "Units", "$unitKey", "$auraKey", "sortMode" }, label = "OPTION_AURA_SORT_MODE", description = "OPTION_AURA_SORT_MODE_DESC", list = "sortMode", fallback = "NEWEST_FIRST", disabled = "aura", placement = "left" },
            { widget = "slider", path = { "Units", "$unitKey", "$auraKey", "stackFontScale" }, label = "OPTION_AURA_STACK_FONT_SCALE", description = "OPTION_AURA_STACK_FONT_SCALE_DESC", min = 0.5, max = 2.0, step = 0.05, fallback = 1, format = "%.2f", disabled = "aura", placement = "left" },
            { widget = "slider", path = { "Units", "$unitKey", "$auraKey", "timerFontScale" }, label = "OPTION_AURA_TIMER_FONT_SCALE", description = "OPTION_AURA_TIMER_FONT_SCALE_DESC", min = 0.5, max = 2.0, step = 0.05, fallback = 1, format = "%.2f", disabled = "aura", placement = "right" },
        },
    },
    {
        section = "SECTION_BEHAVIOR",
        mode = "section",
        layout = "list",
        items = {
            { widget = "checkbox", path = { "Units", "$unitKey", "$auraKey", "showOnlyMine" }, label = "OPTION_AURA_SHOW_ONLY_MINE", description = "OPTION_AURA_SHOW_ONLY_MINE_DESC", fallback = false, disabled = "aura", placement = "left" },
            { widget = "checkbox", path = { "Units", "$unitKey", "$auraKey", "showBossAuras" }, label = "OPTION_AURA_SHOW_BOSS", description = "OPTION_AURA_SHOW_BOSS_DESC", fallback = true, disabled = "aura", placement = "right" },
            { widget = "checkbox", path = { "Units", "$unitKey", "$auraKey", "hidePermanentAuras" }, label = "OPTION_AURA_HIDE_PERMANENT", description = "OPTION_AURA_HIDE_PERMANENT_DESC", fallback = true, disabled = "aura", placement = "left" },
            { widget = "checkbox", path = { "Units", "$unitKey", "$auraKey", "hideLongAuras" }, label = "OPTION_AURA_HIDE_LONG", description = "OPTION_AURA_HIDE_LONG_DESC", fallback = true, disabled = "aura", placement = "right" },
            { widget = "slider", path = { "Units", "$unitKey", "$auraKey", "longAuraThreshold" }, label = "OPTION_AURA_LONG_THRESHOLD", description = "OPTION_AURA_LONG_THRESHOLD_DESC", min = 0, max = 3600, step = 5, fallback = 300, format = "%d", disabled = "longAuraThreshold", placement = "left" },
            { widget = "checkbox", path = { "Units", "$unitKey", "$auraKey", "showStealableOnly" }, label = "OPTION_AURA_SHOW_STEALABLE_ONLY", description = "OPTION_AURA_SHOW_STEALABLE_ONLY_DESC", fallback = false, disabled = "aura", placement = "right" },
            { widget = "checkbox", path = { "Units", "$unitKey", "$auraKey", "showDispellableOnly" }, label = "OPTION_AURA_SHOW_DISPELLABLE_ONLY", description = "OPTION_AURA_SHOW_DISPELLABLE_ONLY_DESC", fallback = false, disabled = "aura", placement = "right" },
            { widget = "checkbox", path = { "Units", "$unitKey", "$auraKey", "showStackText" }, label = "OPTION_AURA_SHOW_STACKS", description = "OPTION_AURA_SHOW_STACKS_DESC", fallback = true, disabled = "aura", placement = "left" },
            { widget = "checkbox", path = { "Units", "$unitKey", "$auraKey", "showTimerText" }, label = "OPTION_AURA_SHOW_TIMER", description = "OPTION_AURA_SHOW_TIMER_DESC", fallback = true, disabled = "aura", placement = "right" },
        },
    },
    {
        section = "SECTION_ATTACHED",
        mode = "section",
        layout = "list",
        items = {
            { widget = "dropdown", path = { "Units", "$unitKey", "$auraKey", "anchorTo" }, label = "OPTION_ANCHOR_TO_TARGET", description = "OPTION_AURA_ANCHOR_TO_DESC", list = "anchorTo", fallback = "Frame", disabled = "attached", placement = "left" },
            { widget = "dropdown", path = { "Units", "$unitKey", "$auraKey", "point" }, label = "OPTION_ANCHOR_FROM", description = "OPTION_AURA_POINT_DESC", list = "anchorPoints", fallback = "BOTTOMLEFT", disabled = "attached", placement = "right" },
            { widget = "dropdown", path = { "Units", "$unitKey", "$auraKey", "relativePoint" }, label = "OPTION_ANCHOR_TO", description = "OPTION_AURA_RELATIVE_POINT_DESC", list = "anchorPoints", fallback = "TOPLEFT", disabled = "attached", placement = "left" },
            { widget = "slider", path = { "Units", "$unitKey", "$auraKey", "offsetX" }, label = "OPTION_X_OFFSET", description = "OPTION_AURA_OFFSET_X_DESC", min = -500, max = 500, step = 1, fallback = 0, format = "%d", disabled = "attached", placement = "left" },
            { widget = "slider", path = { "Units", "$unitKey", "$auraKey", "offsetY" }, label = "OPTION_Y_OFFSET", description = "OPTION_AURA_OFFSET_Y_DESC", min = -500, max = 500, step = 1, fallback = 4, format = "%d", disabled = "attached", placement = "right" },
        },
    },
    {
        section = "SECTION_INSIDE",
        mode = "section",
        layout = "list",
        items = {
            { widget = "dropdown", path = { "Units", "$unitKey", "$auraKey", "insideAnchorTo" }, label = "OPTION_ANCHOR_TO_TARGET", description = "OPTION_AURA_INSIDE_ANCHOR_TO_DESC", list = "anchorTo", fallback = "Frame", disabled = "inside", placement = "left" },
            { widget = "dropdown", path = { "Units", "$unitKey", "$auraKey", "insideSide" }, label = "OPTION_INSIDE_SIDE", description = "OPTION_AURA_INSIDE_SIDE_DESC", list = "insideSide", fallback = "LEFT", disabled = "inside", placement = "right" },
        },
    },
}

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
