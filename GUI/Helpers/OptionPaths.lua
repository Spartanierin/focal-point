local AddonName, ns = ...

ns.GUI = ns.GUI or {}
ns.GUI.Helpers = ns.GUI.Helpers or {}

local OptionPaths = {}
ns.GUI.Helpers.OptionPaths = OptionPaths

local function IsValidPath(path)
    return type(path) == "table" and #path > 0
end

function OptionPaths.Get(tbl, path)
    if type(tbl) ~= "table" or not IsValidPath(path) then
        return nil
    end

    local current = tbl

    for i = 1, #path do
        if type(current) ~= "table" then
            return nil
        end

        current = current[path[i]]

        if current == nil then
            return nil
        end
    end

    return current
end

function OptionPaths.Set(tbl, path, value)
    if type(tbl) ~= "table" or not IsValidPath(path) then
        return false
    end

    local current = tbl

    for i = 1, #path - 1 do
        local key = path[i]

        if type(current[key]) ~= "table" then
            current[key] = {}
        end

        current = current[key]
    end

    current[path[#path]] = value
    return true
end

function OptionPaths.Exists(tbl, path)
    return OptionPaths.Get(tbl, path) ~= nil
end

function OptionPaths.CopyPath(path)
    if type(path) ~= "table" then
        return nil
    end

    local copy = {}

    for i = 1, #path do
        copy[i] = path[i]
    end

    return copy
end

function OptionPaths.Append(path, key)
    if type(path) ~= "table" or key == nil then
        return nil
    end

    local newPath = OptionPaths.CopyPath(path)
    newPath[#newPath + 1] = key
    return newPath
end

return OptionPaths