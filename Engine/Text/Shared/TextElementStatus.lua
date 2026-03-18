local _, FocalPoint = ...

FocalPoint.TextElementStatus = FocalPoint.TextElementStatus or {}
local Status = FocalPoint.TextElementStatus

local TextUtils = FocalPoint.TextElementUtils or {}

local IsSafeTrue = TextUtils.IsSafeTrue

-- Status/name helpers keep textual unit state resolution separate from the
-- larger tag and template runtime.

function Status.GetLocalizedClassName(classToken)
    if type(classToken) ~= "string" or classToken == "" then
        return nil
    end

    classToken = classToken:upper()

    return
        (LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[classToken]) or
        (LOCALIZED_CLASS_NAMES_FEMALE and LOCALIZED_CLASS_NAMES_FEMALE[classToken]) or
        classToken
end

function Status.GetClassificationText(unit)
    if not unit or not UnitClassification then
        return ""
    end

    local classification = UnitClassification(unit)
    if type(classification) ~= "string" or classification == "" or classification == "normal" then
        return ""
    end

    if classification == "worldboss" then
        return BOSS or "Boss"
    elseif classification == "elite" then
        return ELITE or "Elite"
    elseif classification == "rareelite" then
        if ITEM_QUALITY3_DESC and ELITE then
            return ITEM_QUALITY3_DESC .. " " .. ELITE
        end
        return "Rare Elite"
    elseif classification == "rare" then
        return ITEM_QUALITY3_DESC or "Rare"
    elseif classification == "trivial" then
        return MINIMAP_TRACKING_TRIVIAL_QUESTS or "Trivial"
    end

    return classification
end

function Status.GetRoleText(unit)
    if not unit or not UnitGroupRolesAssigned then
        return ""
    end

    local role = UnitGroupRolesAssigned(unit)
    if type(role) ~= "string" or role == "" or role == "NONE" then
        return ""
    end

    if role == "TANK" then
        return TANK or "Tank"
    elseif role == "HEALER" then
        return HEALER or "Healer"
    elseif role == "DAMAGER" then
        return DAMAGER or "Damager"
    end

    return role
end

function Status.GetGhostText()
    return (FocalPoint.L and FocalPoint.L["STATUS_GHOST"]) or PLAYER_STATUS_GHOST or GHOST or "Ghost"
end

function Status.GetDeadText()
    return (FocalPoint.L and FocalPoint.L["STATUS_DEAD"]) or DEAD or "Dead"
end

function Status.GetOfflineText()
    return (FocalPoint.L and FocalPoint.L["STATUS_OFFLINE"]) or PLAYER_OFFLINE or "Offline"
end

function Status.GetCombatText()
    return (FocalPoint.L and FocalPoint.L["STATUS_COMBAT"]) or COMBAT or "Combat"
end

function Status.GetRestingText()
    return (FocalPoint.L and FocalPoint.L["STATUS_RESTING"]) or PLAYER_STATUS_RESTING or "Resting"
end

function Status.GetLeaderText()
    return (FocalPoint.L and FocalPoint.L["STATUS_LEADER"]) or LEADER or "Leader"
end

function Status.GetStatusText(text, fallback)
    local value = text or fallback or ""
    if type(value) ~= "string" or value == "" then
        return ""
    end

    return value
end

function Status.IsUnknownUnitName(name)
    if type(name) ~= "string" or name == "" then
        return true
    end

    local normalized = name:lower()
    local unknownToken = UNKNOWNOBJECT
    if type(unknownToken) == "string" and unknownToken ~= "" then
        local normalizedUnknown = unknownToken:lower()
        if normalized == normalizedUnknown or normalized:find("^" .. normalizedUnknown:gsub("([^%w])", "%%%1")) then
            return true
        end
    end

    return normalized == "unknown" or normalized:find("^unknown[%s<]") ~= nil
end

local function TryUseResolvedName(name)
    if type(name) ~= "string" then
        return nil
    end

    local ok, hasContent = pcall(function()
        return name ~= ""
    end)
    if not ok or not hasContent then
        return nil
    end

    local okUnknown, isUnknown = pcall(Status.IsUnknownUnitName, name)
    if okUnknown and not isUnknown then
        return name
    end

    return nil
end

function Status.GetResolvedUnitName(unit)
    if not unit then
        return ""
    end

    if GetUnitName then
        local fullName = GetUnitName(unit, true)
        local resolvedName = TryUseResolvedName(fullName)
        if resolvedName then
            return resolvedName
        end
    end

    if UnitName then
        local unitName = UnitName(unit)
        local resolvedName = TryUseResolvedName(unitName)
        if resolvedName then
            return resolvedName
        end
    end

    if UnitPVPName then
        local pvpName = UnitPVPName(unit)
        local resolvedName = TryUseResolvedName(pvpName)
        if resolvedName then
            return resolvedName
        end
    end

    if UnitName then
        local fallbackName = UnitName(unit)
        local ok, hasValue = pcall(function()
            return type(fallbackName) == "string"
        end)
        if ok and hasValue then
            return fallbackName
        end
    end

    return ""
end

function Status.FormatStatusTimerValue(seconds)
    local totalSeconds = math.max(0, math.floor(tonumber(seconds) or 0))
    local minutes = math.floor(totalSeconds / 60)
    local remainingSeconds = totalSeconds % 60
    return string.format("(%02d:%02d)", minutes, remainingSeconds)
end

function Status.GetCurrentStatusInfo(unit)
    if not unit then
        return "", ""
    end

    if UnitExists and not IsSafeTrue(UnitExists(unit)) then
        return "", ""
    end

    if UnitIsConnected and not IsSafeTrue(UnitIsConnected(unit)) then
        return "offline", Status.GetStatusText(Status.GetOfflineText(), "Offline")
    end

    if UnitIsDeadOrGhost and IsSafeTrue(UnitIsDeadOrGhost(unit)) then
        if UnitIsGhost and IsSafeTrue(UnitIsGhost(unit)) then
            return "ghost", Status.GetStatusText(Status.GetGhostText(), "Ghost")
        end

        return "dead", Status.GetStatusText(Status.GetDeadText(), "Dead")
    end

    if UnitIsAFK and IsSafeTrue(UnitIsAFK(unit)) then
        return "afk", Status.GetStatusText(AFK, "AFK")
    end

    if UnitIsDND and IsSafeTrue(UnitIsDND(unit)) then
        return "dnd", Status.GetStatusText(DND, "DND")
    end

    return "", ""
end
