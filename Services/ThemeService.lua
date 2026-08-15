local _, FocalPoint = ...

FocalPoint.ThemeService = FocalPoint.ThemeService or {}
local ThemeService = FocalPoint.ThemeService
local LayoutService = FocalPoint.LayoutService or {}
local LegacyThemeAdapter = FocalPoint.LegacyThemeAdapter or {}
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

local function CloneValue(value)
    if LayoutService.Clone then
        return LayoutService.Clone(value)
    end

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
    if LayoutService.MergeInto then
        return LayoutService.MergeInto(target, source)
    end

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

local function BuildClassicCollisionName(templateName, templateValue, templates)
    local baseName = tostring(templateName or "")
    local candidate = baseName .. " (Classic)"
    local suffix = 2

    while templates[candidate] ~= nil do
        if templates[candidate] == templateValue then
            return candidate
        end

        candidate = baseName .. " (Classic " .. tostring(suffix) .. ")"
        suffix = suffix + 1
    end

    return candidate
end

local function InstallThemeTextTemplates(profile, theme)
    local themeTemplates = theme and theme.textTemplates
    if type(profile) ~= "table" or type(themeTemplates) ~= "table" then
        return nil
    end

    profile.TextTemplates = profile.TextTemplates or {}
    local profileTemplates = profile.TextTemplates
    local templateNameMap = {}

    for templateName, templateValue in pairs(themeTemplates) do
        if type(templateName) == "string" and templateName ~= "" and type(templateValue) == "string" then
            local existingValue = profileTemplates[templateName]
            if existingValue == nil then
                profileTemplates[templateName] = templateValue
                templateNameMap[templateName] = templateName
            elseif existingValue == templateValue then
                templateNameMap[templateName] = templateName
            else
                local collisionName = BuildClassicCollisionName(templateName, templateValue, profileTemplates)
                if profileTemplates[collisionName] == nil then
                    profileTemplates[collisionName] = templateValue
                end
                templateNameMap[templateName] = collisionName
            end
        end
    end

    return templateNameMap
end

local function RemapTextTemplateReference(templateNameMap, templateName)
    if type(templateNameMap) ~= "table" or type(templateName) ~= "string" or templateName == "" then
        return templateName
    end

    return templateNameMap[templateName] or templateName
end

local function RemapThemeUnitTextTemplates(unitTheme, templateNameMap)
    if type(unitTheme) ~= "table" or type(unitTheme.texts) ~= "table" or type(templateNameMap) ~= "table" then
        return
    end

    for _, textConfig in pairs(unitTheme.texts) do
        if type(textConfig) == "table" then
            textConfig.templateName = RemapTextTemplateReference(templateNameMap, textConfig.templateName)

            if type(textConfig.stateTemplates) == "table" then
                for stateKey, stateTemplateName in pairs(textConfig.stateTemplates) do
                    textConfig.stateTemplates[stateKey] = RemapTextTemplateReference(templateNameMap, stateTemplateName)
                end
            end
        end
    end
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
    if LegacyThemeAdapter.MaterializeApplyUnit then
        return LegacyThemeAdapter.MaterializeApplyUnit(baseConfig, unitTheme)
    end
    return baseConfig
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
    local layout = LegacyThemeAdapter.MaterializePreviewLayout
        and LegacyThemeAdapter.MaterializePreviewLayout(theme, defaults)
        or nil

    if LayoutService.BuildPreviewUnitConfig then
        return LayoutService.BuildPreviewUnitConfig(layout, unitKey)
    end

    return nil
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
    local templateNameMap = InstallThemeTextTemplates(profile, theme)

    if type(theme.global) == "table" then
        profile.General = profile.General or {}
        MergeInto(profile.General, theme.global)
    end

    local themeUnitKeys = LegacyThemeAdapter.GetThemeUnitKeys
        and LegacyThemeAdapter.GetThemeUnitKeys(theme, defaultUnits)
        or {}
    local layout = {
        Units = {},
        TextTemplates = CloneValue(profile.TextTemplates) or {},
    }

    for _, unitKey in ipairs(themeUnitKeys) do
        local unitConfig = profile.Units[unitKey]
        if type(unitConfig) == "table" then
            local unitTheme = CloneValue(theme.units and theme.units[unitKey])
            RemapThemeUnitTextTemplates(unitTheme, templateNameMap)
            layout.Units[unitKey] = BuildAppliedUnitConfig(unitKey, unitConfig, unitTheme, defaultUnits)
        end
    end

    for unitKey, unitConfig in pairs(layout.Units) do
        profile.Units[unitKey] = unitConfig
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
