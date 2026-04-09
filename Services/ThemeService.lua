local _, FocalPoint = ...

FocalPoint.ThemeService = FocalPoint.ThemeService or {}
local ThemeService = FocalPoint.ThemeService
local themeRestoreState = nil
local RESTORE_STATE_KEY = "_ThemeRestoreState"
local CUSTOM_THEME_KEY = "_CustomThemeSnapshot"
local CUSTOM_THEME_ID = "__custom__"
local PRESERVED_UNIT_KEYS = {
    "enabled",
    "mouseEnabled",
    "clickThrough",
    "clampToScreen",
    "showInSolo",
    "showInParty",
    "showInRaid",
    "showInArena",
    "showInPvp",
    "point",
    "relativeTo",
    "relativePoint",
    "x",
    "y",
    "frameLevel",
    "frameStrata",
}

local SECTION_MAP = {
    frame = {
        width = "width",
        height = "height",
        alpha = "alpha",
        scale = "scale",
        bossSpacing = "bossSpacing",
        backgroundColor = "backgroundColor",
        borderColor = "borderColor",
        healthColor = "healthColor",
        healthLowColor = "healthLowColor",
        healthBackgroundColor = "healthBackgroundColor",
        powerColor = "powerColor",
        classPowerColor = "classPowerColor",
        powerBackgroundColor = "powerBackgroundColor",
        classPowerBackgroundColor = "classPowerBackgroundColor",
        useClassColorHealth = "useClassColorHealth",
        useClassColorPower = "useClassColorPower",
        useReactionColorNpcHealth = "useReactionColorNpcHealth",
        healthBarTexture = "healthBarTexture",
        powerBarTexture = "powerBarTexture",
    },
    portrait = {
        enabled = { "Portrait", "enabled" },
        placement = { "Portrait", "placement" },
        mode = { "Portrait", "mode" },
        size = { "Portrait", "size" },
        scale = { "Portrait", "scale" },
        padding = { "Portrait", "padding" },
        insideSide = { "Portrait", "insideSide" },
        anchorTo = { "Portrait", "anchorTo" },
        point = { "Portrait", "point" },
        relativePoint = { "Portrait", "relativePoint" },
        offsetX = { "Portrait", "offsetX" },
        offsetY = { "Portrait", "offsetY" },
    },
    bars = {
        showPowerBar = "showPowerBar",
        showAlternativePowerBar = "showAlternativePowerBar",
        showClassPowerBar = "showClassPowerBar",
        powerBarHeight = "powerBarHeight",
        alternativePowerBarHeight = "alternativePowerBarHeight",
        classPowerBarHeight = "classPowerBarHeight",
        classPowerBarWidth = "classPowerBarWidth",
        classPowerBarSpacing = "classPowerBarSpacing",
        classPowerBarTexture = "classPowerBarTexture",
        showCastBar = "showCastBar",
        showCastBarIcon = "showCastBarIcon",
        castBarHeight = "castBarHeight",
        castBarTexture = "castBarTexture",
        castBarColor = "castBarColor",
        castBarInterruptibleColor = "castBarInterruptibleColor",
    },
}

local function CloneValue(value)
    if type(value) ~= "table" then
        return value
    end

    if CopyTable then
        return CopyTable(value)
    end

    local result = {}
    for key, entry in pairs(value) do
        result[key] = CloneValue(entry)
    end
    return result
end

local function MergeInto(target, source)
    if type(target) ~= "table" or type(source) ~= "table" then
        return
    end

    for key, value in pairs(source) do
        if type(value) == "table" then
            target[key] = target[key] or {}
            MergeInto(target[key], value)
        else
            target[key] = value
        end
    end
end

local function SetPath(target, path, value)
    if type(target) ~= "table" or not path then
        return
    end

    if type(path) == "string" then
        target[path] = CloneValue(value)
        return
    end

    local node = target
    for index = 1, #path - 1 do
        local key = path[index]
        node[key] = node[key] or {}
        node = node[key]
    end

    node[path[#path]] = CloneValue(value)
end

local function ApplyMappedSection(unitConfig, sectionData, mapping)
    if type(unitConfig) ~= "table" or type(sectionData) ~= "table" or type(mapping) ~= "table" then
        return
    end

    for sourceKey, targetPath in pairs(mapping) do
        if sectionData[sourceKey] ~= nil then
            SetPath(unitConfig, targetPath, sectionData[sourceKey])
        end
    end
end

local function ApplyTexts(unitConfig, texts)
    if type(unitConfig) ~= "table" or type(texts) ~= "table" then
        return
    end

    unitConfig.Texts = unitConfig.Texts or {}
    for key, textConfig in pairs(texts) do
        unitConfig.Texts[key] = unitConfig.Texts[key] or {}
        if type(textConfig) == "table" then
            MergeInto(unitConfig.Texts[key], textConfig)
        end
    end
end

local function ApplyIndicators(unitConfig, indicators)
    if type(unitConfig) ~= "table" or type(indicators) ~= "table" then
        return
    end

    for key, indicatorConfig in pairs(indicators) do
        unitConfig[key] = unitConfig[key] or {}
        if type(indicatorConfig) == "table" then
            MergeInto(unitConfig[key], indicatorConfig)
        end
    end
end

local function ApplyAuras(unitConfig, auras)
    if type(unitConfig) ~= "table" or type(auras) ~= "table" then
        return
    end

    for key, auraConfig in pairs(auras) do
        unitConfig[key] = unitConfig[key] or {}
        if type(auraConfig) == "table" then
            MergeInto(unitConfig[key], auraConfig)
        end
    end
end

local function ApplyThemeToUnitConfig(unitConfig, unitTheme)
    if type(unitConfig) ~= "table" or type(unitTheme) ~= "table" then
        return unitConfig
    end

    ApplyMappedSection(unitConfig, unitTheme.frame, SECTION_MAP.frame)
    ApplyMappedSection(unitConfig, unitTheme.portrait, SECTION_MAP.portrait)
    ApplyMappedSection(unitConfig, unitTheme.bars, SECTION_MAP.bars)
    ApplyIndicators(unitConfig, unitTheme.indicators)
    ApplyTexts(unitConfig, unitTheme.texts)
    ApplyAuras(unitConfig, unitTheme.auras)

    return unitConfig
end

local function PreserveUnitPlacementAndVisibility(targetConfig, sourceConfig)
    if type(targetConfig) ~= "table" or type(sourceConfig) ~= "table" then
        return
    end

    for _, key in ipairs(PRESERVED_UNIT_KEYS) do
        if sourceConfig[key] ~= nil then
            targetConfig[key] = CloneValue(sourceConfig[key])
        end
    end
end

local function BuildAppliedUnitConfig(unitKey, currentUnitConfig, unitTheme, defaultUnits)
    local baseConfig = CloneValue(defaultUnits and defaultUnits[unitKey]) or {}
    PreserveUnitPlacementAndVisibility(baseConfig, currentUnitConfig)
    return ApplyThemeToUnitConfig(baseConfig, unitTheme)
end

local function GetPersistedRestoreState()
    local profile = FocalPoint.db and FocalPoint.db.profile
    local general = profile and profile.General
    if type(general) ~= "table" then
        return nil
    end

    local persisted = general[RESTORE_STATE_KEY]
    if type(persisted) ~= "table" then
        return nil
    end

    return CloneValue(persisted)
end

local function SetPersistedRestoreState(snapshot)
    local profile = FocalPoint.db and FocalPoint.db.profile
    local general = profile and profile.General
    if type(general) ~= "table" then
        return
    end

    general[RESTORE_STATE_KEY] = snapshot and CloneValue(snapshot) or nil
end

local function GetPersistedDefaultTheme()
    local profile = FocalPoint.db and FocalPoint.db.profile
    local general = profile and profile.General
    if type(general) ~= "table" then
        return nil
    end

    local persisted = general[CUSTOM_THEME_KEY]
    if type(persisted) ~= "table" then
        return nil
    end

    return CloneValue(persisted)
end

local function SetPersistedDefaultTheme(snapshot)
    local profile = FocalPoint.db and FocalPoint.db.profile
    local general = profile and profile.General
    if type(general) ~= "table" then
        return
    end

    general[CUSTOM_THEME_KEY] = snapshot and CloneValue(snapshot) or nil
end

function ThemeService.GetThemes()
    return FocalPoint.Themes or {}
end

function ThemeService.GetTheme(themeId)
    if themeId == CUSTOM_THEME_ID then
        local snapshot = ThemeService.HasDefaultSnapshot and ThemeService.HasDefaultSnapshot()
        if snapshot then
            return {
                id = CUSTOM_THEME_ID,
                labelKey = "THEME_CUSTOM",
                descriptionKey = "THEME_CUSTOM_DESC",
                applyDefaults = false,
                units = {},
            }
        end
    end

    local themes = ThemeService.GetThemes()
    if type(themeId) ~= "string" or themeId == "" then
        return nil
    end

    return themes[themeId]
end

function ThemeService.GetCustomThemeId()
    return CUSTOM_THEME_ID
end

function ThemeService.HasRestoreSnapshot()
    if type(themeRestoreState) == "table" then
        return true
    end

    themeRestoreState = GetPersistedRestoreState()
    return type(themeRestoreState) == "table"
end

function ThemeService.HasDefaultSnapshot()
    return type(GetPersistedDefaultTheme()) == "table"
end

function ThemeService.CaptureDefaultSnapshot()
    local profile = FocalPoint.db and FocalPoint.db.profile
    if not profile or type(profile.Units) ~= "table" then
        return false
    end

    local snapshot = {
        units = CloneValue(profile.Units),
        activeThemeId = profile.General and profile.General.ActiveThemeId or nil,
    }

    SetPersistedDefaultTheme(snapshot)
    return true
end

function ThemeService.RestoreDefaultSnapshot()
    local snapshot = GetPersistedDefaultTheme()
    if type(snapshot) ~= "table" then
        return false
    end

    local profile = FocalPoint.db and FocalPoint.db.profile
    if not profile then
        return false
    end

    if type(snapshot.units) == "table" then
        profile.Units = CloneValue(snapshot.units)
    end

    profile.General = profile.General or {}
    profile.General.ActiveThemeId = snapshot.activeThemeId or profile.General.ActiveThemeId

    if FocalPoint.RefreshAllUnitFrames then
        FocalPoint:RefreshAllUnitFrames()
    end

    return true
end

function ThemeService.CaptureRestoreSnapshot()
    local profile = FocalPoint.db and FocalPoint.db.profile
    if not profile or type(profile.Units) ~= "table" then
        return false
    end

    themeRestoreState = {
        units = CloneValue(profile.Units),
        activeThemeId = profile.General and profile.General.ActiveThemeId or nil,
    }

    SetPersistedRestoreState(themeRestoreState)
    return true
end

function ThemeService.ClearRestoreSnapshot()
    themeRestoreState = nil
    SetPersistedRestoreState(nil)
end

function ThemeService.RestoreSnapshot()
    if type(themeRestoreState) ~= "table" then
        themeRestoreState = GetPersistedRestoreState()
    end

    if type(themeRestoreState) ~= "table" then
        return false
    end

    local profile = FocalPoint.db and FocalPoint.db.profile
    if not profile then
        return false
    end

    if type(themeRestoreState.units) == "table" then
        profile.Units = CloneValue(themeRestoreState.units)
    end

    profile.General = profile.General or {}
    profile.General.ActiveThemeId = themeRestoreState.activeThemeId or profile.General.ActiveThemeId

    if FocalPoint.RefreshAllUnitFrames then
        FocalPoint:RefreshAllUnitFrames()
    end

    ThemeService.ClearRestoreSnapshot()
    return true
end

function ThemeService.BuildPreviewUnitConfig(themeId, unitKey)
    local theme = ThemeService.GetTheme(themeId)
    local defaults = FocalPoint.GetDefaultDB and FocalPoint:GetDefaultDB()
    local defaultUnits = defaults and defaults.profile and defaults.profile.Units
    local baseConfig = CloneValue(defaultUnits and defaultUnits[unitKey])

    if type(baseConfig) ~= "table" then
        return nil
    end

    if type(theme) ~= "table" then
        return baseConfig
    end

    return ApplyThemeToUnitConfig(baseConfig, theme.units and theme.units[unitKey])
end

function ThemeService.ApplyTheme(themeId)
    if themeId == CUSTOM_THEME_ID then
        return ThemeService.RestoreDefaultSnapshot()
    end

    local theme = ThemeService.GetTheme(themeId)
    if not theme then
        if FocalPoint.Warn then
            FocalPoint:Warn("Theme not found: " .. tostring(themeId))
        end
        return false
    end

    local profile = FocalPoint.db and FocalPoint.db.profile
    if not profile or type(profile.Units) ~= "table" then
        return false
    end
    local defaults = FocalPoint.GetDefaultDB and FocalPoint:GetDefaultDB()
    local defaultUnits = defaults and defaults.profile and defaults.profile.Units

    if type(theme.global) == "table" then
        profile.General = profile.General or {}
        MergeInto(profile.General, theme.global)
    end

    if theme.applyDefaults and type(defaultUnits) == "table" then
        for unitKey, defaultUnit in pairs(defaultUnits) do
            if type(defaultUnit) == "table" and type(profile.Units[unitKey]) == "table" then
                profile.Units[unitKey] = BuildAppliedUnitConfig(unitKey, profile.Units[unitKey], theme.units and theme.units[unitKey], defaultUnits)
            end
        end
    else
        for unitKey, unitTheme in pairs(theme.units or {}) do
            local unitConfig = profile.Units[unitKey]
            if type(unitConfig) == "table" and type(unitTheme) == "table" then
                profile.Units[unitKey] = BuildAppliedUnitConfig(unitKey, unitConfig, unitTheme, defaultUnits)
            end
        end
    end

    profile.General = profile.General or {}
    profile.General.ActiveThemeId = theme.id

    if FocalPoint.RefreshAllUnitFrames then
        FocalPoint:RefreshAllUnitFrames()
    end

    if FocalPoint.Info then
        local label = theme.labelKey and FocalPoint.L and FocalPoint.L[theme.labelKey] or theme.id
        FocalPoint:Info((FocalPoint.L and FocalPoint.L["INFO_THEME_APPLIED"] or "Applied theme:") .. " " .. tostring(label))
    end

    return true
end
