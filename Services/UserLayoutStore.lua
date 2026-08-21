local _, FocalPoint = ...

FocalPoint.UserLayoutStore = FocalPoint.UserLayoutStore or {}
local Store = FocalPoint.UserLayoutStore

local LayoutService = FocalPoint.LayoutService or {}

local function Clone(value)
    return LayoutService.Clone and LayoutService.Clone(value) or value
end

local function ResolveDB(db)
    return type(db) == "table" and db or FocalPoint.db
end

local function PeekStore(db)
    db = ResolveDB(db)
    local global = type(db) == "table" and rawget(db, "global") or nil
    local layouts = type(global) == "table" and rawget(global, "UserLayouts") or nil
    return type(layouts) == "table" and layouts or nil
end

function Store.PeekStore(db)
    return PeekStore(db)
end

function Store.ListRawReadOnly(db)
    return PeekStore(db) or {}
end

function Store.GetRawReadOnly(id, db)
    local layouts = PeekStore(db)
    if type(layouts) ~= "table" or type(id) ~= "string" or id == "" then
        return nil
    end

    return layouts[id]
end

function Store.EnsureStore()
    local db = FocalPoint.db
    if type(db) ~= "table" then
        return nil
    end

    db.global = type(db.global) == "table" and db.global or {}
    db.global.UserLayouts = type(db.global.UserLayouts) == "table" and db.global.UserLayouts or {}

    return db.global.UserLayouts
end

function Store.GetRaw(id)
    local layouts = Store.EnsureStore()
    if type(layouts) ~= "table" or type(id) ~= "string" or id == "" then
        return nil
    end

    return layouts[id]
end

function Store.ListRaw()
    local layouts = Store.EnsureStore()
    if type(layouts) ~= "table" then
        return {}
    end

    return layouts
end

function Store.GenerateId()
    local layouts = Store.EnsureStore() or {}
    local timestamp = date and date("!%Y%m%d%H%M%S") or tostring(time and time() or 0)
    local counter = 1
    local id

    repeat
        id = string.format("layout:%s:%03d", tostring(timestamp), counter)
        counter = counter + 1
    until layouts[id] == nil

    return id
end

function Store.PutRaw(id, record)
    if type(id) ~= "string" or id == "" or type(record) ~= "table" then
        return nil
    end

    local layouts = Store.EnsureStore()
    if type(layouts) ~= "table" then
        return nil
    end

    layouts[id] = Clone(record)
    return id
end

function Store.RemoveRaw(id)
    local layouts = Store.EnsureStore()
    if type(layouts) ~= "table" or type(id) ~= "string" or id == "" then
        return false
    end

    layouts[id] = nil
    return true
end

return Store
