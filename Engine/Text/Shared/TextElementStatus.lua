local _, FocalPoint = ...

FocalPoint.TextElementStatus = FocalPoint.TextElementStatus or {}
local Status = FocalPoint.TextElementStatus

local TextUtils = FocalPoint.TextElementUtils or {}
local Roles = FocalPoint.TextElementRoles or {}
local Demo = FocalPoint.UnitFrameDemoEnvironment or {}

local IsSafeTrue = TextUtils.IsSafeTrue
local IsPreviewModeEnabled = TextUtils.IsPreviewModeEnabled

-- Status/name helpers keep textual unit state resolution separate from the
-- larger tag and template runtime.

local function IsNonEmptyString(value)
    return type(value) == "string" and value ~= ""
end

local function GetEditorTemplateState(templateName, context)
    if not IsNonEmptyString(templateName) then
        return nil
    end

    if type(context) ~= "table" or type(context.GetTemplate) ~= "function" then
        return "active"
    end

    local ok, templateText = pcall(context.GetTemplate, templateName)
    if ok and IsNonEmptyString(templateText) then
        return "active"
    end

    return "invalid"
end

local function GetStateTemplateState(stateTemplates, context)
    if type(stateTemplates) ~= "table" then
        return nil
    end

    local hasReference = false
    local hasInvalid = false
    for _, templateName in pairs(stateTemplates) do
        local templateState = GetEditorTemplateState(templateName, context)
        if templateState == "active" then
            return "active"
        elseif templateState == "invalid" then
            hasReference = true
            hasInvalid = true
        end
    end

    if hasReference and hasInvalid then
        return "invalid"
    end

    return nil
end

function Status.ResolveOwningComponent(textConfig, context)
    if type(textConfig) ~= "table" then
        return "unit"
    end

    local textKey = type(context) == "table" and context.textKey or nil
    local role = Roles.Resolve and Roles.Resolve(textKey, textConfig) or nil

    if role == "cast_name" or role == "cast_time" then
        return "cast"
    elseif role == "power" then
        return "power"
    elseif role == "altpower" then
        return "altpower"
    elseif role == "classpower" then
        return "classpower"
    elseif role == "health" then
        return "health"
    end

    local anchorTo = textConfig.anchorTo
    if anchorTo == "CastBar" then
        return "cast"
    elseif anchorTo == "PowerBar" then
        return "power"
    elseif anchorTo == "AlternativePowerBar" then
        return "altpower"
    elseif anchorTo == "ClassPowerBar" then
        return "classpower"
    elseif anchorTo == "NormalAbsorbBar" then
        return "normalabsorb"
    elseif anchorTo == "HealingAbsorbBar" then
        return "healingabsorb"
    elseif anchorTo == "HealthBar" then
        return "health"
    end

    return "unit"
end

local function IsOwningComponentEnabled(component, unitConfig)
    if type(unitConfig) ~= "table" then
        return true
    end

    if component == "cast" then
        return unitConfig.showCastBar ~= false
    elseif component == "power" then
        return unitConfig.showPowerBar ~= false
    elseif component == "altpower" then
        return unitConfig.showAlternativePowerBar == true
    elseif component == "classpower" then
        return unitConfig.showClassPowerBar == true
    elseif component == "normalabsorb" then
        return unitConfig.showNormalAbsorbBar ~= false
    elseif component == "healingabsorb" then
        return unitConfig.showHealingAbsorbBar ~= false
    end

    return true
end

function Status.IsRuntimeOwnerAllowed(textConfig, unitConfig)
    if type(textConfig) ~= "table" or type(unitConfig) ~= "table" then
        return true
    end

    local anchorTo = textConfig.anchorTo
    if anchorTo == "PowerBar" then
        return unitConfig.showPowerBar ~= false
    elseif anchorTo == "AlternativePowerBar" then
        return unitConfig.showAlternativePowerBar ~= false
    elseif anchorTo == "ClassPowerBar" then
        return unitConfig.showClassPowerBar ~= false
    elseif anchorTo == "NormalAbsorbBar" then
        return unitConfig.showNormalAbsorbBar ~= false
    elseif anchorTo == "HealingAbsorbBar" then
        return unitConfig.showHealingAbsorbBar ~= false
    end

    return true
end

function Status.ResolveEditorRenderableState(textConfig, context)
    if type(textConfig) ~= "table" then
        return "empty-slot"
    end

    if textConfig.enabled == false then
        return "inactive"
    end

    local stateTemplateState = GetStateTemplateState(textConfig.stateTemplates, context)
    if stateTemplateState then
        return stateTemplateState
    end

    local templateState = GetEditorTemplateState(textConfig.templateName, context)
    if templateState then
        return templateState
    end

    if IsNonEmptyString(textConfig.tag) then
        return "active"
    end

    local textKey = type(context) == "table" and context.textKey or nil
    if Roles.Resolve and IsNonEmptyString(Roles.Resolve(textKey, textConfig)) then
        return "active"
    end

    return "empty-slot"
end

function Status.ResolveEditorAvailability(textConfig, context)
    context = type(context) == "table" and context or {}
    local unitConfig = context.unitConfig

    if type(unitConfig) == "table" and unitConfig.enabled == false then
        return {
            state = "unit-disabled",
            component = "unit",
            renderableState = "inactive",
        }
    end

    local renderableState = Status.ResolveEditorRenderableState(textConfig, context)
    if renderableState ~= "active" and renderableState ~= "invalid" then
        return {
            state = renderableState,
            component = "unit",
            renderableState = renderableState,
        }
    end

    local component = Status.ResolveOwningComponent(textConfig, context)
    if not IsOwningComponentEnabled(component, unitConfig) then
        return {
            state = "component-disabled",
            component = component,
            renderableState = renderableState,
        }
    end

    return {
        state = renderableState == "invalid" and "invalid" or "available",
        component = component,
        renderableState = renderableState,
    }
end

function Status.IsEditorRenderable(textConfig, context)
    local availability = Status.ResolveEditorAvailability(textConfig, context)
    return availability.state == "available" or availability.state == "invalid"
end

function Status.GetLocalizedClassName(classToken)
    if type(classToken) ~= "string" then
        return nil
    end

    local ok, normalizedToken = pcall(function()
        if classToken == "" then
            return nil
        end

        return classToken:upper()
    end)
    if not ok or not normalizedToken then
        return nil
    end

    return
        (LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[normalizedToken]) or
        (LOCALIZED_CLASS_NAMES_FEMALE and LOCALIZED_CLASS_NAMES_FEMALE[normalizedToken])
end

function Status.NormalizeClassToken(value)
    if type(value) ~= "string" then
        return nil
    end

    local ok, token = pcall(function()
        if value == "" then
            return nil
        end

        local normalizedValue = value:upper()
        if
            (RAID_CLASS_COLORS and RAID_CLASS_COLORS[normalizedValue])
            or (CUSTOM_CLASS_COLORS and CUSTOM_CLASS_COLORS[normalizedValue])
            or (LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[normalizedValue])
            or (LOCALIZED_CLASS_NAMES_FEMALE and LOCALIZED_CLASS_NAMES_FEMALE[normalizedValue])
        then
            return normalizedValue
        end

        return nil
    end)

    return ok and token or nil
end

local function TryAddClassCandidate(candidates, value)
    local token = Status.NormalizeClassToken(value)
    if token then
        candidates[#candidates + 1] = token
    end
end

local function TryCollectUnitClass(candidates, unit)
    if not (unit and UnitClass) then
        return nil, nil
    end

    local ok, className, classToken = pcall(UnitClass, unit)
    if not ok then
        return nil, nil
    end

    TryAddClassCandidate(candidates, classToken)

    return className, classToken
end

function Status.ResolveClassColorByToken(classToken)
    classToken = Status.NormalizeClassToken(classToken)
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

    return color.r or color[1], color.g or color[2], color.b or color[3], color.a or color[4] or 1
end

function Status.ResolveUnitClassIdentity(unit, frame)
    local candidates = {}
    local previewValues = (Demo.GetUnitValues and Demo.GetUnitValues(frame)) or (frame and frame.TestValues) or nil

    local rawName, rawToken = TryCollectUnitClass(candidates, unit)

    if frame and previewValues and ((IsPreviewModeEnabled and IsPreviewModeEnabled()) or frame.IsTemplatePreview) then
        TryAddClassCandidate(candidates, previewValues.classToken)
        TryAddClassCandidate(candidates, previewValues.className)
    end

    local token = candidates[1]
    if not token then
        return {
            rawName = rawName,
            rawToken = rawToken,
            safe = false,
        }
    end

    local localizedName = Status.GetLocalizedClassName(token)
    local r, g, b, a = Status.ResolveClassColorByToken(token)

    return {
        token = token,
        localizedName = localizedName,
        color = r and g and b and { r, g, b, a or 1 } or nil,
        rawName = rawName,
        rawToken = rawToken,
        safe = true,
    }
end

function Status.GetUnitClassificationKind(unit)
    if not unit or not UnitClassification then
        return nil
    end

    local ok, kind = pcall(function()
        local classification = UnitClassification(unit)
        if type(classification) ~= "string" or classification == "" or classification == "normal" then
            return nil
        end

        if classification == "worldboss" then
            return "worldboss"
        elseif classification == "elite" then
            return "elite"
        elseif classification == "rareelite" then
            return "rareelite"
        elseif classification == "rare" then
            return "rare"
        elseif classification == "trivial" then
            return "trivial"
        end

        return nil
    end)

    if ok then
        return kind
    end

    return nil
end

function Status.GetClassificationText(unit)
    local classification = Status.GetUnitClassificationKind(unit)
    if not classification then
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

function Status.GetResolvedUnitFullName(unit)
    if not unit then
        return ""
    end

    if UnitPVPName then
        local pvpName = UnitPVPName(unit)
        local resolvedName = TryUseResolvedName(pvpName)
        if resolvedName then
            return resolvedName
        end
    end

    return Status.GetResolvedUnitName(unit)
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
