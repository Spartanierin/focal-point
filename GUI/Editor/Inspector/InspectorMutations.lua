local _, FocalPoint = ...

FocalPoint.GUI = FocalPoint.GUI or {}
FocalPoint.GUI.Editor = FocalPoint.GUI.Editor or {}
FocalPoint.GUI.Editor.Inspector = FocalPoint.GUI.Editor.Inspector or {}

local InspectorMutations = {}
FocalPoint.InspectorMutations = InspectorMutations
FocalPoint.GUI.Editor.Inspector.Mutations = InspectorMutations

local function Result(ok, details)
    details = type(details) == "table" and details or {}
    details.ok = ok and true or false
    return details
end

local function IsValidFieldName(fieldName)
    return type(fieldName) == "string" and fieldName ~= ""
end

local function SetField(target, fieldName, value, missingCode)
    if type(target) ~= "table" then
        return Result(false, { errorCode = missingCode or "invalid_context" })
    end
    if not IsValidFieldName(fieldName) then
        return Result(false, { errorCode = "invalid_field" })
    end

    local oldValue = target[fieldName]
    local changed = oldValue ~= value
    if changed then
        target[fieldName] = value
    end

    return Result(true, {
        changed = changed,
        oldValue = oldValue,
        newValue = value,
    })
end

local function NormalizeOffset(value)
    value = tonumber(value) or 0
    if value < -100 then
        value = -100
    elseif value > 100 then
        value = 100
    end

    return math.floor(value + 0.5)
end

local function GetUnitConfig(context)
    if type(context) ~= "table" or type(context.unitConfig) ~= "table" then
        return nil
    end

    return context.unitConfig
end

local function GetTextConfig(context, textKey)
    local unitConfig = GetUnitConfig(context)
    local texts = type(unitConfig) == "table" and unitConfig.Texts or nil
    if type(texts) ~= "table" or not IsValidFieldName(textKey) then
        return nil
    end

    return texts[textKey]
end

local function GetIndicatorConfig(context, indicatorKey)
    local unitConfig = GetUnitConfig(context)
    local meta = type(context) == "table" and context.indicatorMeta or nil
    local indicatorMeta = type(meta) == "table" and meta[indicatorKey] or nil
    if type(unitConfig) ~= "table" or type(indicatorMeta) ~= "table" then
        return nil
    end

    return unitConfig[indicatorMeta.optionKey]
end

local function GetAuraConfig(context, auraKey)
    local unitConfig = GetUnitConfig(context)
    if type(unitConfig) ~= "table" or not IsValidFieldName(auraKey) then
        return nil
    end

    return unitConfig[auraKey]
end

function InspectorMutations.SetUnitField(context, fieldName, value)
    if type(context) ~= "table" then
        return Result(false, { errorCode = "invalid_context" })
    end
    return SetField(GetUnitConfig(context), fieldName, value, "unit_config_not_found")
end

function InspectorMutations.SetTextField(context, textKey, fieldName, value)
    if type(context) ~= "table" then
        return Result(false, { errorCode = "invalid_context" })
    end
    return SetField(GetTextConfig(context, textKey), fieldName, value, "text_config_not_found")
end

function InspectorMutations.SetTextPositionOffsets(context, textKey, offsetX, offsetY)
    if type(context) ~= "table" then
        return Result(false, { errorCode = "invalid_context" })
    end

    local textConfig = GetTextConfig(context, textKey)
    if type(textConfig) ~= "table" then
        return Result(false, { errorCode = "text_config_not_found" })
    end

    local nextX = NormalizeOffset(offsetX)
    local nextY = NormalizeOffset(offsetY)
    local oldX = NormalizeOffset(textConfig.offsetX)
    local oldY = NormalizeOffset(textConfig.offsetY)
    local changed = oldX ~= nextX or oldY ~= nextY
    if changed then
        textConfig.offsetX = nextX
        textConfig.offsetY = nextY
    end

    return Result(true, {
        changed = changed,
        oldValue = {
            offsetX = oldX,
            offsetY = oldY,
        },
        newValue = {
            offsetX = nextX,
            offsetY = nextY,
        },
    })
end

function InspectorMutations.SetIndicatorField(context, indicatorKey, fieldName, value)
    if type(context) ~= "table" then
        return Result(false, { errorCode = "invalid_context" })
    end
    return SetField(GetIndicatorConfig(context, indicatorKey), fieldName, value, "indicator_config_not_found")
end

function InspectorMutations.SetAuraField(context, auraKey, fieldName, value)
    if type(context) ~= "table" then
        return Result(false, { errorCode = "invalid_context" })
    end
    return SetField(GetAuraConfig(context, auraKey), fieldName, value, "aura_config_not_found")
end

return InspectorMutations
