local _, FocalPoint = ...

FocalPoint.ThemeService = FocalPoint.ThemeService or {}
local ThemeService = FocalPoint.ThemeService

local SECTION_MAP = {
    frame = {
        width = "width",
        height = "height",
        alpha = "alpha",
        scale = "scale",
        backgroundColor = "backgroundColor",
        borderColor = "borderColor",
        healthBackgroundColor = "healthBackgroundColor",
        powerBackgroundColor = "powerBackgroundColor",
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
        powerBarHeight = "powerBarHeight",
        alternativePowerBarHeight = "alternativePowerBarHeight",
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

function ThemeService.GetThemes()
    return FocalPoint.Themes or {}
end

function ThemeService.GetTheme(themeId)
    local themes = ThemeService.GetThemes()
    if type(themeId) ~= "string" or themeId == "" then
        return nil
    end

    return themes[themeId]
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

    if type(theme.global) == "table" then
        profile.General = profile.General or {}
        MergeInto(profile.General, theme.global)
    end

    for unitKey, unitTheme in pairs(theme.units or {}) do
        local unitConfig = profile.Units[unitKey]
        if type(unitConfig) == "table" and type(unitTheme) == "table" then
            ApplyThemeToUnitConfig(unitConfig, unitTheme)
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
