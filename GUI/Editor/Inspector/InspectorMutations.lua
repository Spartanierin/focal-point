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

local MIN_TEXT_FONT_SIZE = 6
local MAX_TEXT_FONT_SIZE = 32
local TEXT_POSITION_KEYS = { "anchorTo", "point", "relativePoint", "offsetX", "offsetY" }

local function NormalizeTextFontSize(value)
    value = tonumber(value) or 12
    if value < MIN_TEXT_FONT_SIZE then
        value = MIN_TEXT_FONT_SIZE
    elseif value > MAX_TEXT_FONT_SIZE then
        value = MAX_TEXT_FONT_SIZE
    end

    return math.floor(value + 0.5)
end

local TEXT_ANCHOR_POINTS = {
    TOPLEFT = true,
    TOP = true,
    TOPRIGHT = true,
    LEFT = true,
    CENTER = true,
    RIGHT = true,
    BOTTOMLEFT = true,
    BOTTOM = true,
    BOTTOMRIGHT = true,
}

local DECORATION_DEFAULTS = {
    id = "primary",
    enabled = false,
    texture = "",
    target = "FRAME",
    point = "CENTER",
    relativePoint = "CENTER",
    offsetX = 0,
    offsetY = 0,
    width = 64,
    height = 64,
    alpha = 1,
    condition = "ALWAYS",
}

local function IsValidTextAnchorPoint(point)
    return type(point) == "string" and TEXT_ANCHOR_POINTS[point] == true
end

local function CopyValue(value)
    if type(value) == "table" then
        return CopyTable and CopyTable(value) or value
    end

    return value
end

local function CopyDecorationDefaults(decorationId)
    local defaults = {}
    for key, value in pairs(DECORATION_DEFAULTS) do
        defaults[key] = CopyValue(value)
    end
    defaults.id = IsValidFieldName(decorationId) and decorationId or DECORATION_DEFAULTS.id
    return defaults
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

local function GetDefaultTextConfig(context, textKey)
    if type(context) ~= "table" or not IsValidFieldName(textKey) or not FocalPoint.GetDefaultDB then
        return nil
    end

    local unitKey = NormalizeUnitKey(context.unitKey or context.unit)
    if not unitKey then
        return nil
    end

    local defaults = FocalPoint:GetDefaultDB()
    return defaults
        and defaults.profile
        and defaults.profile.Units
        and defaults.profile.Units[unitKey]
        and defaults.profile.Units[unitKey].Texts
        and defaults.profile.Units[unitKey].Texts[textKey]
end

local function GetDefaultTextPosition(context, textKey)
    local defaultText = GetDefaultTextConfig(context, textKey)
    if type(defaultText) ~= "table" then
        return nil
    end

    local defaults = {}
    local hasPositionDefault = false
    for _, fieldName in ipairs(TEXT_POSITION_KEYS) do
        if defaultText[fieldName] ~= nil then
            defaults[fieldName] = CopyValue(defaultText[fieldName])
            hasPositionDefault = true
        end
    end

    return hasPositionDefault and defaults or nil
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

local function FindDecorationConfig(decorations, decorationId)
    if type(decorations) ~= "table" or not IsValidFieldName(decorationId) then
        return nil
    end

    for _, decoration in ipairs(decorations) do
        if type(decoration) == "table" and decoration.id == decorationId then
            return decoration
        end
    end

    return nil
end

local function GetDecorationConfig(context, decorationId, create)
    local unitConfig = GetUnitConfig(context)
    if type(unitConfig) ~= "table" or not IsValidFieldName(decorationId) then
        return nil
    end

    local decorations = unitConfig.decorations
    if type(decorations) ~= "table" then
        if not create then
            return nil
        end
        decorations = {}
        unitConfig.decorations = decorations
    end

    local decoration = FindDecorationConfig(decorations, decorationId)
    if not decoration and create then
        decoration = CopyDecorationDefaults(decorationId)
        decorations[#decorations + 1] = decoration
    end

    return decoration
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

local function BuildTextTemplateMutationContext(context)
    return {
        GetTemplates = function()
            local profile = FocalPoint.db and FocalPoint.db.profile or nil
            return profile and profile.TextTemplates or nil
        end,
        GetUnitConfig = function(unitKey)
            if type(context) == "table" and unitKey == context.unitKey and type(context.unitConfig) == "table" then
                return context.unitConfig
            end

            local profile = FocalPoint.db and FocalPoint.db.profile or nil
            local units = profile and profile.Units or nil
            return type(units) == "table" and units[unitKey] or nil
        end,
    }
end

function InspectorMutations.AssignTextStateTemplate(context, textKey, stateKey, templateName)
    local mutations = FocalPoint.TextTemplateMutations
    if type(context) ~= "table" or type(mutations) ~= "table" or type(mutations.AssignStateTemplate) ~= "function" then
        return Result(false, { errorCode = "invalid_context" })
    end
    return mutations.AssignStateTemplate(BuildTextTemplateMutationContext(context), context.unitKey, textKey, stateKey, templateName)
end

function InspectorMutations.UnassignTextStateTemplate(context, textKey, stateKey)
    local mutations = FocalPoint.TextTemplateMutations
    if type(context) ~= "table" or type(mutations) ~= "table" or type(mutations.UnassignStateTemplate) ~= "function" then
        return Result(false, { errorCode = "invalid_context" })
    end
    return mutations.UnassignStateTemplate(BuildTextTemplateMutationContext(context), context.unitKey, textKey, stateKey)
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

function InspectorMutations.SetTextFontSize(context, textKey, fontSize)
    if type(context) ~= "table" then
        return Result(false, { errorCode = "invalid_context" })
    end

    local textConfig = GetTextConfig(context, textKey)
    if type(textConfig) ~= "table" then
        return Result(false, { errorCode = "text_config_not_found" })
    end

    local nextSize = NormalizeTextFontSize(fontSize)
    local oldSize = NormalizeTextFontSize(textConfig.fontSize)
    local changed = oldSize ~= nextSize
    if changed then
        textConfig.fontSize = nextSize
    end

    return Result(true, {
        changed = changed,
        oldValue = oldSize,
        newValue = nextSize,
    })
end

function InspectorMutations.GetTextPositionDefault(context, textKey)
    return GetDefaultTextPosition(context, textKey)
end

function InspectorMutations.GetTextFontSizeDefault(context, textKey)
    local defaultText = GetDefaultTextConfig(context, textKey)
    if type(defaultText) ~= "table" or defaultText.fontSize == nil then
        return nil
    end

    return NormalizeTextFontSize(defaultText.fontSize)
end

function InspectorMutations.ResetTextPosition(context, textKey)
    if type(context) ~= "table" then
        return Result(false, { errorCode = "invalid_context" })
    end

    local textConfig = GetTextConfig(context, textKey)
    if type(textConfig) ~= "table" then
        return Result(false, { errorCode = "text_config_not_found" })
    end

    local defaults = GetDefaultTextPosition(context, textKey)
    if type(defaults) ~= "table" then
        return Result(false, { errorCode = "text_position_default_not_found" })
    end

    local changed = false
    local oldValue = {}
    local newValue = {}
    for _, fieldName in ipairs(TEXT_POSITION_KEYS) do
        if defaults[fieldName] ~= nil then
            local nextValue = CopyValue(defaults[fieldName])
            oldValue[fieldName] = textConfig[fieldName]
            newValue[fieldName] = nextValue
            if textConfig[fieldName] ~= nextValue then
                textConfig[fieldName] = nextValue
                changed = true
            end
        end
    end

    return Result(true, {
        changed = changed,
        oldValue = oldValue,
        newValue = newValue,
    })
end

function InspectorMutations.ResetTextFontSize(context, textKey)
    local defaultFontSize = InspectorMutations.GetTextFontSizeDefault(context, textKey)
    if defaultFontSize == nil then
        return Result(false, { errorCode = "text_font_size_default_not_found" })
    end

    return InspectorMutations.SetTextFontSize(context, textKey, defaultFontSize)
end

function InspectorMutations.AdjustTextFontSize(context, textKey, delta)
    if type(context) ~= "table" then
        return Result(false, { errorCode = "invalid_context" })
    end

    local textConfig = GetTextConfig(context, textKey)
    if type(textConfig) ~= "table" then
        return Result(false, { errorCode = "text_config_not_found" })
    end

    delta = tonumber(delta) or 0
    if delta > 0 then
        delta = 1
    elseif delta < 0 then
        delta = -1
    else
        delta = 0
    end

    return InspectorMutations.SetTextFontSize(context, textKey, NormalizeTextFontSize(textConfig.fontSize) + delta)
end

function InspectorMutations.SetTextAnchor(context, textKey, point, relativePoint)
    if type(context) ~= "table" then
        return Result(false, { errorCode = "invalid_context" })
    end

    local textConfig = GetTextConfig(context, textKey)
    if type(textConfig) ~= "table" then
        return Result(false, { errorCode = "text_config_not_found" })
    end
    if not IsValidTextAnchorPoint(point) or not IsValidTextAnchorPoint(relativePoint) then
        return Result(false, { errorCode = "invalid_anchor" })
    end

    local oldPoint = textConfig.point
    local oldRelativePoint = textConfig.relativePoint
    local changed = oldPoint ~= point or oldRelativePoint ~= relativePoint
    if changed then
        textConfig.point = point
        textConfig.relativePoint = relativePoint
    end

    return Result(true, {
        changed = changed,
        oldValue = {
            point = oldPoint,
            relativePoint = oldRelativePoint,
        },
        newValue = {
            point = point,
            relativePoint = relativePoint,
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

function InspectorMutations.GetDecorationConfig(context, decorationId)
    return GetDecorationConfig(context, decorationId, false) or CopyDecorationDefaults(decorationId)
end

function InspectorMutations.SetDecorationField(context, decorationId, fieldName, value)
    if type(context) ~= "table" then
        return Result(false, { errorCode = "invalid_context" })
    end
    return SetField(GetDecorationConfig(context, decorationId, true), fieldName, value, "decoration_config_not_found")
end

return InspectorMutations
