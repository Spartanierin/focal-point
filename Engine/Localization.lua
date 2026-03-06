local addonName, ns = ...

function ns.GetLabel(mapTable, key)
    local L = ns.L
    local localeKey = mapTable and mapTable[key]

    if not localeKey then
        return tostring(key)
    end

    return L[localeKey] or localeKey
end