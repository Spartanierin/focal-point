local _, FocalPoint = ...

FocalPoint.UserPresetStore = FocalPoint.UserPresetStore or {}
local Store = FocalPoint.UserPresetStore

local LayoutService = FocalPoint.LayoutService or {}

local function Clone(value)
    return LayoutService.Clone and LayoutService.Clone(value) or value
end

function Store.EnsureStore()
    local db = FocalPoint.db
    if type(db) ~= "table" then
        return nil
    end

    db.global = type(db.global) == "table" and db.global or {}
    db.global.UserPresets = type(db.global.UserPresets) == "table" and db.global.UserPresets or {}

    return db.global.UserPresets
end

function Store.GetRaw(id)
    local presets = Store.EnsureStore()
    if type(presets) ~= "table" or type(id) ~= "string" or id == "" then
        return nil
    end

    return presets[id]
end

function Store.ListRaw()
    local presets = Store.EnsureStore()
    if type(presets) ~= "table" then
        return {}
    end

    return presets
end

function Store.GenerateId()
    local presets = Store.EnsureStore() or {}
    local timestamp = date and date("!%Y%m%d%H%M%S") or tostring(time and time() or 0)
    local counter = 1
    local id

    repeat
        id = string.format("user:%s:%03d", tostring(timestamp), counter)
        counter = counter + 1
    until presets[id] == nil

    return id
end

function Store.PutRaw(preset)
    if type(preset) ~= "table" or type(preset.metadata) ~= "table" then
        return nil
    end

    local id = preset.metadata.id
    if type(id) ~= "string" or id == "" then
        return nil
    end

    local presets = Store.EnsureStore()
    if type(presets) ~= "table" then
        return nil
    end

    presets[id] = Clone(preset)
    return id
end

function Store.RemoveRaw(id)
    local presets = Store.EnsureStore()
    if type(presets) ~= "table" or type(id) ~= "string" or id == "" then
        return false
    end

    presets[id] = nil
    return true
end

return Store
