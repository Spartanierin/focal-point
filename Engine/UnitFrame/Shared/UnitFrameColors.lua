local _, FocalPoint = ...

FocalPoint.UnitFrameColors = FocalPoint.UnitFrameColors or {}
local Colors = FocalPoint.UnitFrameColors

local Utils = FocalPoint.UnitFrameUtils or {}
local IsSafeTrue = Utils.IsSafeTrue
local UnpackColor = Utils.UnpackColor

-- Color helpers stay side-effect free.
-- They resolve health and power colors without touching frame state.

function Colors.IsUnitDeadByHealth(unit)
    if not unit or not UnitHealth or not UnitHealthMax then
        return false
    end

    local ok, result = pcall(function()
        local currentHealth = UnitHealth(unit)
        local maxHealth = UnitHealthMax(unit)
        return type(currentHealth) == "number"
            and type(maxHealth) == "number"
            and maxHealth > 0
            and currentHealth <= 0
    end)

    return ok and result == true
end

function Colors.GetClassColorForUnit(unit, useReactionForNpc)
    if not unit or not UnitExists or not UnitExists(unit) or not UnitClass then
        return nil
    end

    if UnitIsPlayer and UnitIsPlayer(unit) and UnitIsEnemy and IsSafeTrue(UnitIsEnemy("player", unit)) then
        local hostileColor = FACTION_BAR_COLORS and (FACTION_BAR_COLORS[2] or FACTION_BAR_COLORS[1]) or nil
        if hostileColor then
            return hostileColor.r or hostileColor[1], hostileColor.g or hostileColor[2], hostileColor.b or hostileColor[3], 1
        end

        return 1, 0.1, 0.1, 1
    end

    if UnitReaction and FACTION_BAR_COLORS then
        local reaction = UnitReaction("player", unit)
        local color = reaction and FACTION_BAR_COLORS[reaction] or nil

        if UnitIsPlayer and UnitIsPlayer(unit) and UnitCanAttack and IsSafeTrue(UnitCanAttack("player", unit)) and color then
            return color.r or color[1], color.g or color[2], color.b or color[3], 1
        end

        if UnitIsPlayer and not UnitIsPlayer(unit) and useReactionForNpc and color then
            return color.r or color[1], color.g or color[2], color.b or color[3], 1
        end
    end

    if UnitIsPlayer and not UnitIsPlayer(unit) then
        if useReactionForNpc and UnitReaction and FACTION_BAR_COLORS then
            local reaction = UnitReaction("player", unit)
            local color = reaction and FACTION_BAR_COLORS[reaction] or nil
            if color then
                return color.r or color[1], color.g or color[2], color.b or color[3], 1
            end
        end

        return nil
    end

    local _, classToken = UnitClass(unit)
    if not classToken then
        return nil
    end

    local color = nil

    if CUSTOM_CLASS_COLORS and CUSTOM_CLASS_COLORS[classToken] then
        color = CUSTOM_CLASS_COLORS[classToken]
    elseif RAID_CLASS_COLORS and RAID_CLASS_COLORS[classToken] then
        color = RAID_CLASS_COLORS[classToken]
    end

    if not color then
        return nil
    end

    return color.r or color[1], color.g or color[2], color.b or color[3], 1
end

function Colors.GetPowerColorForUnit(unit)
    if not unit or not UnitExists or not UnitExists(unit) or not UnitPowerType then
        return nil
    end

    local powerType = UnitPowerType(unit)
    if powerType == nil then
        return nil
    end

    local color = PowerBarColor and PowerBarColor[powerType]
    if not color then
        return nil
    end

    return color.r or color[1], color.g or color[2], color.b or color[3], color.a or color[4]
end

function Colors.GetResolvedHealthBarColor(frame, config)
    local healthR, healthG, healthB, healthA = UnpackColor(config and config.healthColor, { 0.1, 0.8, 0.1, 1 })

    if config and config.useClassColorHealth then
        local classR, classG, classB = Colors.GetClassColorForUnit(frame and frame.unit, config.useReactionColorNpcHealth)
        if classR and classG and classB then
            healthR, healthG, healthB = classR, classG, classB
        end
    end

    return healthR, healthG, healthB, healthA
end
