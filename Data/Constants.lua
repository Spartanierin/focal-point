local addonName, ns = ...

ns.Constants = ns.Constants or {}
local C = ns.Constants

-- AddOn
C.ADDON_NAME = "FocalPoint"

-- Navigation
C.Nav = {
    GENERAL = "general",
    EDITOR = "editor",
    TAG_DATABASE = "tag_database",
    TEXT_BUILDER = "text_builder",
    PROFILES = "profiles",
    THEMES = "themes",
    GLOBAL_DEFAULTS = "global_defaults",
    TEST_MODE = "test_mode",
    UNITS = "units",
}

-- Units
C.Units = {
    PLAYER = "player",
    TARGET = "target",
    TARGETTARGET = "targettarget",
    PET = "pet",
    FOCUS = "focus",
    FOCUSTARGET = "focustarget",
    BOSS = "boss",
}

C.UnitOrder = {
    C.Units.PLAYER,
    C.Units.TARGET,
    C.Units.TARGETTARGET,
    C.Units.PET,
    C.Units.FOCUS,
    C.Units.FOCUSTARGET,
    C.Units.BOSS,
}

-- Main Tabs
C.Tabs = {
    FRAME = "frame",
    BARS = "bars",
    AURAS = "auras",
    TEXTS = "texts",
    ELEMENTS = "elements",
    VISIBILITY = "visibility",
    COLORS = "colors",
}

C.TabOrder = {
    C.Tabs.FRAME,
    C.Tabs.BARS,
    C.Tabs.AURAS,
    C.Tabs.TEXTS,
    C.Tabs.ELEMENTS,
    C.Tabs.VISIBILITY,
}

-- Auras
C.Auras = {
    BUFFS = "buffs",
    DEBUFFS = "debuffs",
}

C.AuraOrder = {
    C.Auras.BUFFS,
    C.Auras.DEBUFFS,
}

-- Bars
C.Bars = {
    HEALTH = "health_bar",
    POWER = "power_bar",
    ALT_POWER = "alt_power_bar",
    CLASS_POWER = "class_power_bar",
    CAST = "cast_bar",
}

C.BarOrder = {
    C.Bars.HEALTH,
    C.Bars.POWER,
    C.Bars.ALT_POWER,
    C.Bars.CLASS_POWER,
    C.Bars.CAST,
}

-- Texts
C.Texts = {
    NAME = "name_text",
    HEALTH_VALUE = "health_value_text",
    POWER_VALUE = "power_value_text",
    LEVEL = "level_text",
    CLASS = "class_text",
    RACE = "race_text",
    STATUS = "status_text",
    CAST_NAME = "cast_name_text",
    CAST_TIME = "cast_time_text",
    CUSTOM_1 = "custom_text_1",
    CUSTOM_2 = "custom_text_2",
    CUSTOM_3 = "custom_text_3",
}

C.TextOrder = {
    C.Texts.NAME,
    C.Texts.HEALTH_VALUE,
    C.Texts.POWER_VALUE,
    C.Texts.LEVEL,
    C.Texts.CLASS,
    C.Texts.RACE,
    C.Texts.STATUS,
    C.Texts.CAST_NAME,
    C.Texts.CAST_TIME,
    C.Texts.CUSTOM_1,
    C.Texts.CUSTOM_2,
    C.Texts.CUSTOM_3,
}

-- Elements
C.Elements = {
    PORTRAIT = "portrait",
    BACKGROUND = "background",
    BORDER = "border",
    HIGHLIGHT = "highlight",
    RAID_TARGET_ICON = "raid_target_icon",
    LEADER_ICON = "leader_icon",
    ROLE_ICON = "role_icon",
    COMBAT_INDICATOR = "combat_indicator",
    RESTING_INDICATOR = "resting_indicator",
    READY_CHECK_INDICATOR = "ready_check_indicator",
    CLASSIFICATION_INDICATOR = "classification_indicator",
    PVP_INDICATOR = "pvp_indicator",
    INDICATORS = "indicators",
}

C.ElementOrder = {
    C.Elements.PORTRAIT,
    C.Elements.BACKGROUND,
    C.Elements.BORDER,
    C.Elements.HIGHLIGHT,
    C.Elements.RAID_TARGET_ICON,
    C.Elements.LEADER_ICON,
    C.Elements.ROLE_ICON,
    C.Elements.COMBAT_INDICATOR,
    C.Elements.RESTING_INDICATOR,
    C.Elements.READY_CHECK_INDICATOR,
    C.Elements.CLASSIFICATION_INDICATOR,
    C.Elements.PVP_INDICATOR,
}

-- Reusable Sections
C.Sections = {
    GENERAL = "general",
    POSITION = "position",
    SIZE_POSITION = "size_position",
    STYLE = "style",
    BEHAVIOR = "behavior",
    CONTENT = "content",
    FONT = "font",
    COLOR = "color",
    LAYERING = "layering",
    STATE_RULES = "state_rules",
    OPACITY_RULES = "opacity_rules",
}

-- Common Options
C.Options = {
    ENABLED = "enabled",
    WIDTH = "width",
    HEIGHT = "height",
    SCALE = "scale",
    ALPHA = "alpha",
    ANCHOR_FROM = "anchor_from",
    ANCHOR_TO = "anchor_to",
    X_OFFSET = "x_offset",
    Y_OFFSET = "y_offset",
    FRAME_STRATA = "frame_strata",
    FRAME_LEVEL = "frame_level",
    FONT = "font",
    FONT_SIZE = "font_size",
    FONT_OUTLINE = "font_outline",
    FONT_MONOCHROME = "font_monochrome",
    FONT_SHADOW = "font_shadow",
    COLOR = "color",
    BACKGROUND_COLOR = "background_color",
    ORIENTATION = "orientation",
    REVERSE_FILL = "reverse_fill",
    SHOW_BACKGROUND = "show_background",
    TAG = "tag",
    PREFIX = "prefix",
    SUFFIX = "suffix",
    MAX_LENGTH = "max_length",
    JUSTIFY_H = "justify_h",
    JUSTIFY_V = "justify_v",
}

-- Visibility / Logic
C.VisibilityOptions = {
    SHOW_IN_SOLO = "show_in_solo",
    SHOW_IN_PARTY = "show_in_party",
    SHOW_IN_RAID = "show_in_raid",
    SHOW_IN_ARENA = "show_in_arena",
    SHOW_IN_PVP = "show_in_pvp",
    IN_COMBAT_ONLY = "in_combat_only",
    OUT_OF_COMBAT_ONLY = "out_of_combat_only",
    HAS_TARGET = "has_target",
    ALIVE_ONLY = "alive_only",
    NORMAL_ALPHA = "normal_alpha",
    FADED_ALPHA = "faded_alpha",
    RANGE_FADE = "range_fade",
    CONDITIONAL_FADE = "conditional_fade",
}

-- Theme / Test
C.Theme = {
    SELECT = "select_theme",
    PREVIEW = "preview_theme",
    APPLY = "apply_theme",
    IMPORT = "import_theme",
    EXPORT = "export_theme",
}

C.TestMode = {
    ENABLE = "enable_test_mode",
    UNIT_DATA = "test_unit_data",
    SIMULATE_STATUS = "simulate_status",
    RESET = "reset_simulation",
}
