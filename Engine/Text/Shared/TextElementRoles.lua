local _, FocalPoint = ...

FocalPoint.TextElementRoles = FocalPoint.TextElementRoles or {}
local Roles = FocalPoint.TextElementRoles

local legacyRoleByKey = {
    Name = "name",
    Health = "health",
    Power = "power",
    Class = "class",
    Race = "race",
    Level = "level",
    Status = "status",
    AltPower = "altpower",
    ClassPower = "classpower",
    CastName = "cast_name",
    CastTime = "cast_time",
}

function Roles.Resolve(textKey, textConfig)
    if type(textConfig) == "table" and type(textConfig.role) == "string" and textConfig.role ~= "" then
        return textConfig.role
    end

    if type(textKey) == "string" then
        return legacyRoleByKey[textKey]
    end

    return nil
end

function Roles.FindTextKeyByRole(texts, role, legacyKey)
    if type(texts) ~= "table" or type(role) ~= "string" or role == "" then
        return nil
    end

    if type(legacyKey) == "string"
        and legacyKey ~= ""
        and texts[legacyKey] ~= nil
        and Roles.Resolve(legacyKey, texts[legacyKey]) == role
    then
        return legacyKey
    end

    local sortedKeys = {}
    for textKey in pairs(texts) do
        if type(textKey) == "string" then
            sortedKeys[#sortedKeys + 1] = textKey
        end
    end

    table.sort(sortedKeys)

    for _, textKey in ipairs(sortedKeys) do
        if Roles.Resolve(textKey, texts[textKey]) == role then
            return textKey
        end
    end

    return nil
end

function Roles.HasRole(texts, role, legacyKey)
    return Roles.FindTextKeyByRole(texts, role, legacyKey) ~= nil
end

function Roles.IsCastRole(role)
    return role == "cast_name" or role == "cast_time"
end
