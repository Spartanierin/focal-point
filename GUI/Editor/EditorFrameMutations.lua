local _, FocalPoint = ...

FocalPoint.GUI = FocalPoint.GUI or {}
FocalPoint.GUI.Editor = FocalPoint.GUI.Editor or {}

local Mutations = {}
FocalPoint.GUI.Editor.FrameMutations = Mutations

local POSITION_KEYS = { "point", "relativeTo", "relativePoint", "x", "y" }
local SIZE_KEYS = { "width", "height" }

local function CopyValue(value)
    if type(value) == "table" then
        return CopyTable and CopyTable(value) or value
    end

    return value
end

local function NormalizeUnitKey(unitKey)
    local utils = FocalPoint.UnitFrameUtils
    if utils and utils.NormalizeConfigUnitKey then
        return utils.NormalizeConfigUnitKey(unitKey)
    end
    if type(unitKey) ~= "string" or unitKey == "" then
        return nil
    end
    if unitKey:match("^boss%d+$") then
        return "boss"
    end
    return unitKey
end

local function BuildUnitOrderIndex()
    local index = {}
    local unitOrder = FocalPoint.Constants and FocalPoint.Constants.UnitOrder or {}
    for order, unitKey in ipairs(unitOrder) do
        local normalizedUnit = NormalizeUnitKey(unitKey)
        if normalizedUnit and index[normalizedUnit] == nil then
            index[normalizedUnit] = order
        end
    end

    return index
end

local UNIT_ORDER_INDEX = BuildUnitOrderIndex()

local function CompareUnitKeys(left, right)
    local leftOrder = UNIT_ORDER_INDEX[left]
    local rightOrder = UNIT_ORDER_INDEX[right]
    if leftOrder and rightOrder and leftOrder ~= rightOrder then
        return leftOrder < rightOrder
    end
    if leftOrder then
        return true
    end
    if rightOrder then
        return false
    end

    return tostring(left) < tostring(right)
end

local function GetUnitConfig(unitKey)
    local normalizedUnit = NormalizeUnitKey(unitKey)
    if not normalizedUnit then
        return nil, nil
    end

    local utils = FocalPoint.UnitFrameUtils
    if utils and utils.GetUnitDB then
        return utils.GetUnitDB(normalizedUnit), normalizedUnit
    end

    return nil, normalizedUnit
end

local function GetDefaultUnitConfig(unitKey)
    local normalizedUnit = NormalizeUnitKey(unitKey)
    if not normalizedUnit or not FocalPoint.GetDefaultDB then
        return nil
    end

    local defaults = FocalPoint:GetDefaultDB()
    return defaults
        and defaults.profile
        and defaults.profile.Units
        and defaults.profile.Units[normalizedUnit]
end

local function NormalizeUnits(units)
    local result = {}
    local seen = {}

    if type(units) == "string" then
        units = { units }
    end
    if type(units) ~= "table" then
        return result
    end

    for _, unitKey in ipairs(units) do
        local normalizedUnit = NormalizeUnitKey(unitKey)
        if normalizedUnit and not seen[normalizedUnit] then
            seen[normalizedUnit] = true
            result[#result + 1] = normalizedUnit
        end
    end

    table.sort(result, CompareUnitKeys)
    return result
end

local function IsWriteBlockedInCombat()
    return InCombatLockdown and InCombatLockdown()
end

local function ValidateUnits(units)
    local normalizedUnits = NormalizeUnits(units)
    if #normalizedUnits == 0 then
        return nil, "invalid_units"
    end

    local entries = {}
    for _, unitKey in ipairs(normalizedUnits) do
        local config = GetUnitConfig(unitKey)
        local defaults = GetDefaultUnitConfig(unitKey)
        if type(config) ~= "table" or type(defaults) ~= "table" then
            return nil, "invalid_unit"
        end
        entries[#entries + 1] = {
            unit = unitKey,
            config = config,
            defaults = defaults,
        }
    end

    return entries
end

local function RefreshUnits(units)
    if FocalPoint.RefreshUnitFrame then
        for _, unitKey in ipairs(units) do
            FocalPoint:RefreshUnitFrame(unitKey)
        end
    elseif FocalPoint.RefreshAllUnitFrames then
        FocalPoint:RefreshAllUnitFrames()
    end

    if FocalPoint.GUI and FocalPoint.GUI.RequestRefreshOptions then
        FocalPoint.GUI:RequestRefreshOptions()
    end

    if FocalPoint.RefreshEditorSelectionVisuals then
        FocalPoint:RefreshEditorSelectionVisuals()
    end
end

local function ResetEntries(entries, keys)
    for _, entry in ipairs(entries) do
        for _, key in ipairs(keys) do
            if entry.defaults[key] ~= nil then
                entry.config[key] = CopyValue(entry.defaults[key])
            end
        end
    end
end

local function ResetUnits(units, keys)
    if IsWriteBlockedInCombat() then
        return {
            ok = false,
            reason = "combat",
            units = NormalizeUnits(units),
            count = 0,
        }
    end

    local entries, reason = ValidateUnits(units)
    if not entries then
        return {
            ok = false,
            reason = reason,
            units = NormalizeUnits(units),
            count = 0,
        }
    end

    ResetEntries(entries, keys)

    local refreshedUnits = {}
    for _, entry in ipairs(entries) do
        refreshedUnits[#refreshedUnits + 1] = entry.unit
    end
    RefreshUnits(refreshedUnits)

    return {
        ok = true,
        units = refreshedUnits,
        count = #refreshedUnits,
    }
end

function Mutations.ResetUnitPosition(unitKey)
    return Mutations.ResetUnitsPosition({ unitKey })
end

function Mutations.ResetUnitSize(unitKey)
    return Mutations.ResetUnitsSize({ unitKey })
end

function Mutations.ResetUnitsPosition(units)
    return ResetUnits(units, POSITION_KEYS)
end

function Mutations.ResetUnitsSize(units)
    return ResetUnits(units, SIZE_KEYS)
end

return Mutations
