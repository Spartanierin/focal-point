local _, FocalPoint = ...

FocalPoint.LegacyThemeAdapter = FocalPoint.LegacyThemeAdapter or {}
local Adapter = FocalPoint.LegacyThemeAdapter

local LayoutService = FocalPoint.LayoutService or {}

local SECTION_MAP = {
    frame = {
        width = "width",
        height = "height",
        alpha = "alpha",
        scale = "scale",
        bossSpacing = "bossSpacing",
        point = "point",
        relativeTo = "relativeTo",
        relativePoint = "relativePoint",
        x = "x",
        y = "y",
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
        alternativePowerBarTexture = "alternativePowerBarTexture",
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

local function Clone(value)
    return LayoutService.Clone and LayoutService.Clone(value) or value
end

local function MergeInto(target, source)
    if LayoutService.MergeInto then
        return LayoutService.MergeInto(target, source)
    end
    return target
end

local function SetPath(target, path, value)
    if type(target) ~= "table" or not path then
        return
    end

    if type(path) == "string" then
        target[path] = Clone(value)
        return
    end

    local node = target
    for index = 1, #path - 1 do
        local key = path[index]
        node[key] = type(node[key]) == "table" and node[key] or {}
        node = node[key]
    end

    node[path[#path]] = Clone(value)
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

function Adapter.ApplyThemeToUnitConfig(unitConfig, unitTheme)
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

function Adapter.MaterializePreviewLayout(theme, defaults)
    local defaultProfile = defaults and defaults.profile or defaults
    local defaultUnits = defaultProfile and defaultProfile.Units
    local layout = {
        Units = {},
        TextTemplates = Clone(defaultProfile and defaultProfile.TextTemplates) or {},
    }

    if type(defaultUnits) ~= "table" then
        return layout
    end

    for unitKey, defaultUnit in pairs(defaultUnits) do
        local unitConfig = Clone(defaultUnit) or {}
        if type(theme) == "table" then
            Adapter.ApplyThemeToUnitConfig(unitConfig, theme.units and theme.units[unitKey])
        end
        layout.Units[unitKey] = unitConfig
    end

    if type(theme) == "table" and type(theme.textTemplates) == "table" then
        MergeInto(layout.TextTemplates, theme.textTemplates)
    end

    return layout
end

function Adapter.MaterializeApplyUnit(defaultUnit, unitTheme)
    local unitConfig = Clone(defaultUnit) or {}
    return Adapter.ApplyThemeToUnitConfig(unitConfig, unitTheme)
end

function Adapter.GetThemeUnitKeys(theme, defaultUnits)
    local keys = {}

    if type(theme) == "table" and theme.applyDefaults and type(defaultUnits) == "table" then
        for unitKey, defaultUnit in pairs(defaultUnits) do
            if type(defaultUnit) == "table" then
                keys[#keys + 1] = unitKey
            end
        end
    elseif type(theme) == "table" and type(theme.units) == "table" then
        for unitKey in pairs(theme.units) do
            keys[#keys + 1] = unitKey
        end
    end

    table.sort(keys)
    return keys
end

return Adapter
