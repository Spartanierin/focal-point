local _, FocalPoint = ...

FocalPoint.GUI = FocalPoint.GUI or {}
FocalPoint.GUI.Editor = FocalPoint.GUI.Editor or {}
FocalPoint.GUI.Editor.Inspector = FocalPoint.GUI.Editor.Inspector or {}

local InspectorTextSelection = {}
FocalPoint.InspectorTextSelection = InspectorTextSelection
FocalPoint.GUI.Editor.Inspector.TextSelection = InspectorTextSelection

local function Result(ok, details)
    details = type(details) == "table" and details or {}
    details.ok = ok and true or false
    return details
end

local function IsValidTextKey(textKey)
    return type(textKey) == "string" and textKey ~= ""
end

function InspectorTextSelection.IsValid(textList, textKey)
    return type(textList) == "table" and IsValidTextKey(textKey) and textList[textKey] ~= nil
end

local function ResolveStoredTextKey(state)
    if type(state) ~= "table" then
        return nil
    end

    if IsValidTextKey(state.selectedTextId) then
        return state.selectedTextId
    end
    if IsValidTextKey(state.selectedTextKey) then
        return state.selectedTextKey
    end

    return nil
end

local function ResolveFallbackTextKey(options, textList)
    if type(options.getFirstTextId) == "function" then
        local ok, textKey = pcall(options.getFirstTextId, textList)
        if ok and IsValidTextKey(textKey) and textList[textKey] ~= nil then
            return textKey
        end
    end

    return nil
end

function InspectorTextSelection.Resolve(options)
    options = type(options) == "table" and options or {}

    local state = options.state
    local textList = type(options.textList) == "table" and options.textList or {}
    local unitConfig = type(options.unitConfig) == "table" and options.unitConfig or nil
    local texts = type(unitConfig) == "table" and unitConfig.Texts or nil
    local storedTextKey = ResolveStoredTextKey(state)
    local effectiveTextKey = storedTextKey
    local usedFallback = false

    if not InspectorTextSelection.IsValid(textList, effectiveTextKey) then
        effectiveTextKey = ResolveFallbackTextKey(options, textList)
        usedFallback = storedTextKey ~= effectiveTextKey
    end

    local textConfig = type(texts) == "table" and type(effectiveTextKey) == "string" and texts[effectiveTextKey] or nil
    if type(textConfig) ~= "table" then
        textConfig = nil
    end

    return Result(true, {
        storedTextKey = storedTextKey,
        effectiveTextKey = effectiveTextKey,
        textConfig = textConfig,
        usedFallback = usedFallback,
    })
end

function InspectorTextSelection.Set(state, textKey, textList)
    if type(state) ~= "table" then
        return Result(false, { errorCode = "invalid_state" })
    end
    if not IsValidTextKey(textKey) then
        return Result(false, { errorCode = "invalid_text_selection" })
    end
    if type(textList) == "table" and textList[textKey] == nil then
        return Result(false, { errorCode = "text_selection_not_found" })
    end

    local changed = state.selectedTextId ~= textKey or state.selectedTextKey ~= textKey
    if changed then
        state.selectedTextId = textKey
        state.selectedTextKey = textKey
    end

    return Result(true, {
        changed = changed,
        textKey = textKey,
    })
end

return InspectorTextSelection
