local _, FocalPoint = ...

FocalPoint.AuraSorting = FocalPoint.AuraSorting or {}
local AuraSorting = FocalPoint.AuraSorting
local ToSafeNumber = function(value)
    local okDirect, directValue = pcall(function()
        if type(value) == "number" and not (issecretvalue and issecretvalue(value)) then
            return value
        end

        return nil
    end)
    if okDirect and type(directValue) == "number" then
        return directValue
    end

    local ok, parsed = pcall(tonumber, value)
    if ok and type(parsed) == "number" and not (issecretvalue and issecretvalue(parsed)) then
        return parsed
    end

    return 0
end

-- Owns ordering rules for visible aura records.

local function IsTimedAura(aura)
    return type(aura) == "table" and aura.durationState == "TIMED"
end

local function ToSafeString(value)
    local okDirect, directValue = pcall(function()
        if type(value) ~= "string" then
            return nil
        end

        if value == "" or (issecretvalue and issecretvalue(value)) then
            return nil
        end

        return value
    end)
    if okDirect and type(directValue) == "string" then
        return directValue
    end

    local okText, textValue = pcall(tostring, value)
    if okText and type(textValue) == "string" then
        local okParsed, parsedValue = pcall(function()
            if textValue == "" or (issecretvalue and issecretvalue(textValue)) then
                return nil
            end

            return textValue
        end)
        if okParsed and type(parsedValue) == "string" then
            return parsedValue
        end
    end

    return ""
end

local function CompareTimedBeforePermanent(left, right)
    local leftTimed = IsTimedAura(left)
    local rightTimed = IsTimedAura(right)
    if leftTimed ~= rightTimed then
        return leftTimed and not rightTimed
    end

    return nil
end

local function CompareNumberAsc(leftValue, rightValue)
    leftValue = ToSafeNumber(leftValue)
    rightValue = ToSafeNumber(rightValue)

    if leftValue ~= rightValue then
        return leftValue < rightValue
    end

    return nil
end

local function CompareNumberDesc(leftValue, rightValue)
    leftValue = ToSafeNumber(leftValue)
    rightValue = ToSafeNumber(rightValue)

    if leftValue ~= rightValue then
        return leftValue > rightValue
    end

    return nil
end

function AuraSorting.SortAuras(auraList, config, groupKey)
    if type(auraList) ~= "table" then
        return {}
    end

    local sorted = {}
    for index, aura in ipairs(auraList) do
        sorted[index] = aura
    end

    local sortMode = config and config.sortMode or "NEWEST_FIRST"

    table.sort(sorted, function(left, right)
        local timedDecision = CompareTimedBeforePermanent(left, right)
        if timedDecision ~= nil then
            return timedDecision
        end

        if sortMode == "OLDEST_FIRST" then
            local decision = CompareNumberAsc(left.sourceIndex or 0, right.sourceIndex or 0)
            if decision ~= nil then
                return decision
            end
        elseif sortMode == "TIME_REMAINING_ASC" then
            if IsTimedAura(left) and IsTimedAura(right) then
                local decision = CompareNumberAsc(left.remaining or 0, right.remaining or 0)
                if decision ~= nil then
                    return decision
                end
            end

            local decision = CompareNumberDesc(left.sourceIndex or 0, right.sourceIndex or 0)
            if decision ~= nil then
                return decision
            end
        else
            local decision = CompareNumberDesc(left.sourceIndex or 0, right.sourceIndex or 0)
            if decision ~= nil then
                return decision
            end
        end

        local leftSpellId = ToSafeNumber(left.spellId or 0)
        local rightSpellId = ToSafeNumber(right.spellId or 0)
        if leftSpellId ~= rightSpellId then
            return leftSpellId < rightSpellId
        end

        local leftName = ToSafeString(left.name)
        local rightName = ToSafeString(right.name)
        if leftName ~= rightName then
            return leftName < rightName
        end

        local leftInstanceId = ToSafeNumber(left.auraInstanceId or 0)
        local rightInstanceId = ToSafeNumber(right.auraInstanceId or 0)
        return leftInstanceId < rightInstanceId
    end)

    return sorted
end
