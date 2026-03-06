local addonName, ns = ...

ns.KeyMap = ns.KeyMap or {}
local KM = ns.KeyMap
local C = ns.Constants

KM.Nav = {
    [C.Nav.GENERAL] = "NAV_GENERAL",
    [C.Nav.PROFILES] = "NAV_PROFILES",
    [C.Nav.THEMES] = "NAV_THEMES",
    [C.Nav.GLOBAL_DEFAULTS] = "NAV_GLOBAL_DEFAULTS",
    [C.Nav.TEST_MODE] = "NAV_TEST_MODE",
    [C.Nav.UNITS] = "NAV_UNITS",
}

KM.Units = {
    [C.Units.PLAYER] = "UNIT_PLAYER",
    [C.Units.TARGET] = "UNIT_TARGET",
    [C.Units.TARGETTARGET] = "UNIT_TARGET_OF_TARGET",
    [C.Units.PET] = "UNIT_PET",
    [C.Units.FOCUS] = "UNIT_FOCUS",
    [C.Units.FOCUSTARGET] = "UNIT_FOCUS_TARGET",
    [C.Units.BOSS] = "UNIT_BOSS",
}

KM.Tabs = {
    [C.Tabs.FRAME] = "TAB_FRAME",
    [C.Tabs.BARS] = "TAB_BARS",
    [C.Tabs.TEXTS] = "TAB_TEXTS",
    [C.Tabs.ELEMENTS] = "TAB_ELEMENTS",
    [C.Tabs.VISIBILITY] = "TAB_VISIBILITY",
}

KM.Bars = {
    [C.Bars.HEALTH] = "BAR_HEALTH",
    [C.Bars.POWER] = "BAR_POWER",
    [C.Bars.ALT_POWER] = "BAR_ALT_POWER",
    [C.Bars.CAST] = "BAR_CAST",
}

KM.Texts = {
    [C.Texts.NAME] = "TEXT_NAME",
    [C.Texts.HEALTH_VALUE] = "TEXT_HEALTH_VALUE",
    [C.Texts.POWER_VALUE] = "TEXT_POWER_VALUE",
    [C.Texts.LEVEL] = "TEXT_LEVEL",
    [C.Texts.STATUS] = "TEXT_STATUS",
    [C.Texts.CAST_NAME] = "TEXT_CAST_NAME",
    [C.Texts.CAST_TIME] = "TEXT_CAST_TIME",
    [C.Texts.CUSTOM_1] = "TEXT_CUSTOM_1",
    [C.Texts.CUSTOM_2] = "TEXT_CUSTOM_2",
    [C.Texts.CUSTOM_3] = "TEXT_CUSTOM_3",
}

KM.Elements = {
    [C.Elements.PORTRAIT] = "ELEMENT_PORTRAIT",
    [C.Elements.BACKGROUND] = "ELEMENT_BACKGROUND",
    [C.Elements.BORDER] = "ELEMENT_BORDER",
    [C.Elements.HIGHLIGHT] = "ELEMENT_HIGHLIGHT",
    [C.Elements.RAID_TARGET_ICON] = "ELEMENT_RAID_TARGET_ICON",
    [C.Elements.LEADER_ICON] = "ELEMENT_LEADER_ICON",
    [C.Elements.ROLE_ICON] = "ELEMENT_ROLE_ICON",
    [C.Elements.COMBAT_INDICATOR] = "ELEMENT_COMBAT_INDICATOR",
    [C.Elements.RESTING_INDICATOR] = "ELEMENT_RESTING_INDICATOR",
    [C.Elements.READY_CHECK_INDICATOR] = "ELEMENT_READY_CHECK_INDICATOR",
    [C.Elements.PVP_INDICATOR] = "ELEMENT_PVP_INDICATOR",
    [C.Elements.INDICATORS] = "ELEMENT_INDICATORS",
}

KM.Sections = {
    [C.Sections.GENERAL] = "SECTION_GENERAL",
    [C.Sections.POSITION] = "SECTION_POSITION",
    [C.Sections.SIZE_POSITION] = "SECTION_SIZE_POSITION",
    [C.Sections.STYLE] = "SECTION_STYLE",
    [C.Sections.BEHAVIOR] = "SECTION_BEHAVIOR",
    [C.Sections.CONTENT] = "SECTION_CONTENT",
    [C.Sections.FONT] = "SECTION_FONT",
    [C.Sections.COLOR] = "SECTION_COLOR",
    [C.Sections.LAYERING] = "SECTION_LAYERING",
    [C.Sections.STATE_RULES] = "SECTION_STATE_RULES",
    [C.Sections.OPACITY_RULES] = "SECTION_OPACITY_RULES",
}