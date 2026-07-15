local _, FocalPoint = ...

FocalPoint.GUI = FocalPoint.GUI or {}
FocalPoint.GUI.Editor = FocalPoint.GUI.Editor or {}
FocalPoint.GUI.Editor.Inspector = FocalPoint.GUI.Editor.Inspector or {}

local InspectorContext = {}
FocalPoint.InspectorContext = InspectorContext
FocalPoint.GUI.Editor.Inspector.Context = InspectorContext
local EditorMode = FocalPoint.EditorMode or (FocalPoint.GUI.Editor and FocalPoint.GUI.Editor.Mode) or {}
local InspectorTextSelection = FocalPoint.InspectorTextSelection or (FocalPoint.GUI.Editor.Inspector and FocalPoint.GUI.Editor.Inspector.TextSelection) or {}
local InspectorIndicatorSelection = FocalPoint.InspectorIndicatorSelection or (FocalPoint.GUI.Editor.Inspector and FocalPoint.GUI.Editor.Inspector.IndicatorSelection) or {}

local function ResolveLinkedTemplateName(textConfig)
    if type(textConfig) ~= "table" then
        return nil
    end

    local templateName = textConfig.templateName
    if type(templateName) == "string" and templateName ~= "" then
        return templateName
    end

    local stateTemplates = textConfig.stateTemplates
    if type(stateTemplates) ~= "table" then
        return nil
    end

    local stateKeys = {}
    for stateKey in pairs(stateTemplates) do
        stateKeys[#stateKeys + 1] = stateKey
    end
    table.sort(stateKeys, function(left, right)
        return tostring(left) < tostring(right)
    end)

    for _, stateKey in ipairs(stateKeys) do
        local stateTemplateName = stateTemplates[stateKey]
        if type(stateTemplateName) == "string" and stateTemplateName ~= "" then
            return stateTemplateName
        end
    end

    return nil
end

local function ResolveUnitKey(state)
    if type(state) ~= "table" then
        return nil
    end

    local unitKey = state.selectedUnit
    if type(unitKey) ~= "string" or unitKey == "" then
        return nil
    end

    return unitKey
end

local function ResolveUnitConfig(context, unitKey)
    if not unitKey or type(context.getUnitConfig) ~= "function" then
        return nil
    end

    local ok, unitConfig = pcall(context.getUnitConfig, unitKey)
    if ok and type(unitConfig) == "table" then
        return unitConfig
    end

    return nil
end

local function ResolveTextList(context, unitKey, unitConfig)
    if type(context.buildTextList) ~= "function" then
        return {}
    end

    local ok, textList = pcall(context.buildTextList, unitKey, unitConfig)
    if ok and type(textList) == "table" then
        return textList
    end

    return {}
end

local function ResolveIndicatorList(context, unitKey, unitConfig)
    if type(context.buildIndicatorList) ~= "function" then
        return {}
    end

    local ok, indicatorList = pcall(context.buildIndicatorList, unitKey, unitConfig)
    if ok and type(indicatorList) == "table" then
        return indicatorList
    end

    return {}
end

local function ResolveAuraList(context, unitKey, unitConfig)
    if type(context.buildAuraList) ~= "function" then
        return {}
    end

    local ok, auraList = pcall(context.buildAuraList, unitKey, unitConfig)
    if ok and type(auraList) == "table" then
        return auraList
    end

    return {}
end

function InspectorContext.GetMode(context)
    return context and context.mode or "quick"
end

function InspectorContext.IsQuick(context)
    if EditorMode.IsQuick then
        return EditorMode.IsQuick(context)
    end
    return context and context.isQuick == true or false
end

function InspectorContext.IsExpert(context)
    if EditorMode.IsExpert then
        return EditorMode.IsExpert(context)
    end
    return context and context.isExpert == true or false
end

function InspectorContext.GetSelectedUnit(context)
    return context and context.unitKey or nil
end

function InspectorContext.GetUnitConfig(context)
    return context and context.unitConfig or nil
end

function InspectorContext.GetTextList(context)
    return context and context.textList or {}
end

function InspectorContext.GetIndicatorList(context)
    return context and context.indicatorList or {}
end

function InspectorContext.GetAuraList(context)
    return context and context.auraList or {}
end

function InspectorContext.GetTextSelection(context)
    if type(context) ~= "table" then
        return nil, nil, nil, nil
    end

    local result = context.textSelection
    if type(result) ~= "table" and type(InspectorTextSelection.Resolve) == "function" then
        result = InspectorTextSelection.Resolve({
            state = context.state,
            textList = context.textList,
            unitConfig = context.unitConfig,
            getFirstTextId = context.getFirstTextId,
        })
    end

    local selectedTextId = type(result) == "table" and result.effectiveTextKey or nil
    local textConfig = type(result) == "table" and result.textConfig or nil
    return selectedTextId, textConfig, ResolveLinkedTemplateName(textConfig), result
end

function InspectorContext.GetIndicatorSelection(context)
    if type(context) ~= "table" then
        return nil, nil, nil, nil
    end

    local result = context.indicatorSelection
    if type(result) ~= "table" and type(InspectorIndicatorSelection.Resolve) == "function" then
        result = InspectorIndicatorSelection.Resolve({
            state = context.state,
            indicatorList = context.indicatorList,
            indicatorMeta = context.indicatorMeta,
            unitConfig = context.unitConfig,
            unitKey = context.unitKey,
            getFirstIndicatorKey = context.getFirstIndicatorKey,
        })
    end

    local selectedIndicatorKey = type(result) == "table" and result.effectiveIndicatorKey or nil
    local indicatorMeta = type(result) == "table" and result.indicatorMetaEntry or nil
    local indicatorConfig = type(result) == "table" and result.indicatorConfig or nil
    return selectedIndicatorKey, indicatorMeta, indicatorConfig, result
end

function InspectorContext.GetAuraSelection(context)
    if type(context) ~= "table" then
        return nil, nil
    end

    local state = context.state
    local auraList = context.auraList or {}
    local selectedAuraKey = type(state) == "table" and state.selectedAuraKey or nil
    if not auraList[selectedAuraKey] and type(context.getFirstAuraKey) == "function" then
        selectedAuraKey = context.getFirstAuraKey(auraList)
    end

    local auraConfig = type(context.unitConfig) == "table" and context.unitConfig[selectedAuraKey] or nil
    return selectedAuraKey, auraConfig
end

function InspectorContext.Create(options)
    options = type(options) == "table" and options or {}

    local state = options.state
    local mode = EditorMode.Resolve and EditorMode.Resolve(state, options.profile) or "quick"
    local unitKey = ResolveUnitKey(state)
    local context = {
        state = state,
        mode = mode,
        isQuick = mode == "quick",
        isExpert = mode == "expert",

        unitKey = unitKey,

        getUnitConfig = options.getUnitConfig,
        buildTextList = options.buildTextList,
        getFirstTextId = options.getFirstTextId,
        buildIndicatorList = options.buildIndicatorList,
        getFirstIndicatorKey = options.getFirstIndicatorKey,
        indicatorMeta = options.indicatorMeta,
        buildAuraList = options.buildAuraList,
        getFirstAuraKey = options.getFirstAuraKey,
    }

    context.unitConfig = ResolveUnitConfig(context, unitKey)
    context.textList = ResolveTextList(context, unitKey, context.unitConfig)
    if type(InspectorTextSelection.Resolve) == "function" then
        context.textSelection = InspectorTextSelection.Resolve({
            state = state,
            textList = context.textList,
            unitConfig = context.unitConfig,
            getFirstTextId = context.getFirstTextId,
        })
    end
    context.indicatorList = ResolveIndicatorList(context, unitKey, context.unitConfig)
    if type(InspectorIndicatorSelection.Resolve) == "function" then
        context.indicatorSelection = InspectorIndicatorSelection.Resolve({
            state = state,
            indicatorList = context.indicatorList,
            indicatorMeta = context.indicatorMeta,
            unitConfig = context.unitConfig,
            unitKey = unitKey,
            getFirstIndicatorKey = context.getFirstIndicatorKey,
        })
    end
    context.auraList = ResolveAuraList(context, unitKey, context.unitConfig)

    context.selectedTextId, context.textConfig, context.linkedTemplateName = InspectorContext.GetTextSelection(context)
    context.selectedIndicatorKey, context.indicatorMetaEntry, context.indicatorConfig = InspectorContext.GetIndicatorSelection(context)
    context.selectedAuraKey, context.auraConfig = InspectorContext.GetAuraSelection(context)

    return context
end

return InspectorContext
