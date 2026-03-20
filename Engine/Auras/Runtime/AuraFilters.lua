local _, FocalPoint = ...

FocalPoint.AuraFilters = FocalPoint.AuraFilters or {}
local AuraFilters = FocalPoint.AuraFilters

-- Owns visibility decisions for normalized aura records.

local function IsTimedAura(aura)
    return type(aura) == "table" and aura.durationState == "TIMED"
end

local function ToPlainNumber(value)
    local ok, result = pcall(function()
        return tonumber(value)
    end)
    if ok and type(result) == "number" and not (issecretvalue and issecretvalue(result)) then
        return result
    end

    return nil
end

local function IsGreaterThan(value, threshold)
    local ok, result = pcall(function()
        return value > threshold
    end)
    if ok and type(result) == "boolean" then
        return result
    end

    local plainValue = ToPlainNumber(value)
    if type(plainValue) == "number" then
        return plainValue > threshold
    end

    return false
end

function AuraFilters.ShouldShowAura(aura, config, groupKey, frame)
    if type(aura) ~= "table" then
        return false
    end

    if groupKey == "Buffs" and not aura.isHelpful then
        return false
    end

    if groupKey == "Debuffs" and not aura.isHarmful then
        return false
    end

    config = config or {}
    local hideLongAuras = config.hideLongAuras
    if hideLongAuras == nil then
        hideLongAuras = true
    end
    local longAuraThreshold = math.max(tonumber(config.longAuraThreshold) or 300, 0)

    if aura.isBossAura and config.showBossAuras then
        return true
    end

    if config.showOnlyMine and not aura.isMine then
        return false
    end

    if config.hidePermanentAuras and aura.durationState == "PERMANENT" then
        return false
    end

    if hideLongAuras and IsTimedAura(aura) and longAuraThreshold > 0 and IsGreaterThan(aura.duration or 0, longAuraThreshold) then
        return false
    end

    if groupKey == "Buffs" and config.showStealableOnly and not aura.isStealable then
        return false
    end

    if groupKey == "Debuffs" and config.showDispellableOnly and not aura.dispelName then
        return false
    end

    return true
end

function AuraFilters.FilterAuras(auraList, config, groupKey, frame)
    local filtered = {}
    if type(auraList) ~= "table" then
        return filtered
    end

    for _, aura in ipairs(auraList) do
        if AuraFilters.ShouldShowAura(aura, config, groupKey, frame) then
            filtered[#filtered + 1] = aura
        end
    end

    return filtered
end
