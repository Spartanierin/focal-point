local _, PORTRAIT = ...

PORTRAIT.GUI = PORTRAIT.GUI or {}
PORTRAIT.GUI.Helpers = PORTRAIT.GUI.Helpers or {}

local OptionPaths = PORTRAIT.GUI.Helpers.OptionPaths
local OptionValues = {}

PORTRAIT.GUI.Helpers.OptionValues = OptionValues

local function GetProfileDB()
    if not PORTRAIT.db or not PORTRAIT.db.profile then
        return nil
    end

    return PORTRAIT.db.profile
end

local function GetDefaultsDB()
    if not PORTRAIT.GetDefaultDB then
        return nil
    end

    local defaults = PORTRAIT:GetDefaultDB()

    if not defaults or not defaults.profile then
        return nil
    end

    return defaults.profile
end

function OptionValues.Get(path, fallback)
    local db = GetProfileDB()
    local value = OptionPaths.Get(db, path)

    if value == nil then
        return fallback
    end

    return value
end

function OptionValues.GetDefault(path, fallback)
    local defaults = GetDefaultsDB()
    local value = OptionPaths.Get(defaults, path)

    if value == nil then
        return fallback
    end

    return value
end

function OptionValues.Set(path, value)
    local db = GetProfileDB()

    if not db then
        return false
    end

    return OptionPaths.Set(db, path, value)
end

function OptionValues.Reset(path)
    local db = GetProfileDB()
    local defaults = GetDefaultsDB()

    if not db or not defaults then
        return false
    end

    local defaultValue = OptionPaths.Get(defaults, path)

    if defaultValue == nil then
        return false
    end

    if type(defaultValue) == "table" then
        return OptionPaths.Set(db, path, CopyTable(defaultValue))
    end

    return OptionPaths.Set(db, path, defaultValue)
end

function OptionValues.IsDefault(path)
    local currentValue = OptionValues.Get(path)
    local defaultValue = OptionValues.GetDefault(path)

    if type(currentValue) == "table" or type(defaultValue) == "table" then
        return false
    end

    return currentValue == defaultValue
end

function OptionValues.ResolveState(state, context)
    if type(state) == "function" then
        local ok, result = pcall(state, context)

        if not ok then
            return false
        end

        return result and true or false
    end

    return state and true or false
end

return OptionValues