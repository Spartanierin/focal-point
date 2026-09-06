local _, FocalPoint = ...

FocalPoint.CompositionPresenceStorage = FocalPoint.CompositionPresenceStorage or {}
local Storage = FocalPoint.CompositionPresenceStorage

local FLAT_COMPONENTS = {
    { presentField = "powerBarPresent", showField = "showPowerBar" },
    { presentField = "castBarPresent", showField = "showCastBar" },
    { presentField = "classPowerBarPresent", showField = "showClassPowerBar" },
    { presentField = "alternativePowerBarPresent", showField = "showAlternativePowerBar" },
    { presentField = "normalAbsorbBarPresent", showField = "showNormalAbsorbBar" },
    { presentField = "healingAbsorbBarPresent", showField = "showHealingAbsorbBar" },
}

local TABLE_COMPONENT_KEYS = {
    "Portrait",
    "RaidTargetIcon",
    "LeaderIcon",
    "RoleIcon",
    "CombatIndicator",
    "RestingIndicator",
    "ReadyCheckIndicator",
    "ClassificationIndicator",
    "Buffs",
    "Debuffs",
}

local FLAT_PRESENT_FIELDS = {}
local FLAT_PRESENT_FIELD_SET = {}
for _, component in ipairs(FLAT_COMPONENTS) do
    FLAT_PRESENT_FIELDS[#FLAT_PRESENT_FIELDS + 1] = component.presentField
    FLAT_PRESENT_FIELD_SET[component.presentField] = true
end

local TABLE_COMPONENT_KEY_SET = {}
for _, componentKey in ipairs(TABLE_COMPONENT_KEYS) do
    TABLE_COMPONENT_KEY_SET[componentKey] = true
end

Storage.FlatPresentFields = FLAT_PRESENT_FIELDS
Storage.TableComponentKeys = TABLE_COMPONENT_KEYS

function Storage.IsPresencePath(path)
    if type(path) ~= "table" then
        return false
    end

    local lastKey = path[#path]
    if lastKey == "present" and path[#path - 2] == "Units" then
        return true
    end

    if FLAT_PRESENT_FIELD_SET[lastKey] == true then
        return true
    end

    return lastKey == "present" and TABLE_COMPONENT_KEY_SET[path[#path - 1]] == true
end

function Storage.EnsureUnit(unitConfig)
    if type(unitConfig) ~= "table" then
        return unitConfig
    end

    if unitConfig.present == nil then
        unitConfig.present = true
    end

    for _, component in ipairs(FLAT_COMPONENTS) do
        if unitConfig[component.presentField] == nil and unitConfig[component.showField] ~= nil then
            unitConfig[component.presentField] = true
        end
    end

    for _, componentKey in ipairs(TABLE_COMPONENT_KEYS) do
        local componentConfig = unitConfig[componentKey]
        if type(componentConfig) == "table" and componentConfig.present == nil then
            componentConfig.present = true
        end
    end

    return unitConfig
end

function Storage.MigrateLegacyUnitPresence(unitConfig)
    if type(unitConfig) ~= "table" then
        return unitConfig
    end

    if unitConfig.present == nil then
        unitConfig.present = unitConfig.enabled ~= false
    end

    return unitConfig
end

function Storage.MigrateLegacyUnits(units)
    if type(units) ~= "table" then
        return units
    end

    for _, unitConfig in pairs(units) do
        Storage.MigrateLegacyUnitPresence(unitConfig)
    end

    return units
end

function Storage.MigrateLegacyProfile(profile)
    if type(profile) ~= "table" then
        return profile
    end

    Storage.MigrateLegacyUnits(profile.Units)
    return profile
end

function Storage.MigrateLegacyPayload(payload)
    if type(payload) ~= "table" then
        return payload
    end

    Storage.MigrateLegacyUnits(payload.Units)
    return payload
end

function Storage.EnsureUnits(units)
    if type(units) ~= "table" then
        return units
    end

    for _, unitConfig in pairs(units) do
        Storage.EnsureUnit(unitConfig)
    end

    return units
end

function Storage.EnsureProfile(profile)
    if type(profile) ~= "table" then
        return profile
    end

    Storage.EnsureUnits(profile.Units)
    return profile
end

function Storage.EnsurePayload(payload)
    if type(payload) ~= "table" then
        return payload
    end

    Storage.EnsureUnits(payload.Units)
    return payload
end
