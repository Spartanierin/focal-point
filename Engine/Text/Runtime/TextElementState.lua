local _, FocalPoint = ...

FocalPoint.TextElementState = FocalPoint.TextElementState or {}

local TextState = FocalPoint.TextElementState
local RuntimeState = FocalPoint.UnitFrameState or {}

local function CopyDirty(dirty)
    local result = {}
    if type(dirty) ~= "table" then
        return result
    end

    for key, value in pairs(dirty) do
        result[key] = value == true
    end

    return result
end

local function MergeDirty(dirty, scope)
    if type(dirty) ~= "table" then
        return
    end

    if type(scope) == "string" and scope ~= "" then
        dirty[scope] = true
        return
    end

    if type(scope) == "table" then
        for _, entry in ipairs(scope) do
            if type(entry) == "string" and entry ~= "" then
                dirty[entry] = true
            end
        end
        return
    end

    dirty.texts = true
end

local function ScopeTouchesTextModel(scope)
    if scope == nil then
        return true
    end

    if type(scope) == "string" then
        return scope == "texts" or scope == "full" or scope == "layout"
    end

    if type(scope) == "table" then
        for _, entry in ipairs(scope) do
            if ScopeTouchesTextModel(entry) then
                return true
            end
        end
    end

    return false
end

local function ScopeInvalidatesTextDependencies(scope)
    if scope == nil then
        return true
    end

    if type(scope) == "string" then
        return scope == "full" or scope == "layout"
    end

    if type(scope) == "table" then
        for _, entry in ipairs(scope) do
            if ScopeInvalidatesTextDependencies(entry) then
                return true
            end
        end
    end

    return false
end

local function CountVisibleTexts(frame)
    local count = 0
    if not frame or type(frame.Texts) ~= "table" then
        return count
    end

    for _, textObject in pairs(frame.Texts) do
        if textObject and textObject.IsShown and textObject:IsShown() then
            count = count + 1
        end
    end

    return count
end

local function CopyDependencies(dependencies)
    local result = {}
    if type(dependencies) ~= "table" then
        return result
    end

    for dependency, enabled in pairs(dependencies) do
        if enabled == true and type(dependency) == "string" and dependency ~= "" then
            result[dependency] = true
        end
    end

    return result
end

function TextState.DebugLog(frame, action, details)
    if RuntimeState.DebugLog then
        RuntimeState.DebugLog(frame, "text-" .. tostring(action or "?"), details)
    end
end

function TextState.Ensure(frame)
    if not frame then
        return nil
    end

    frame.TextRuntimeState = frame.TextRuntimeState or {
        phase = "cold",
        dirty = {},
        lastReason = nil,
        liveValuesVersion = 0,
        textModelVersion = 0,
        castTimeBindingDirty = true,
        usesCastTime = false,
        castTimeTextKey = nil,
        castTickerActive = false,
        visibleTextCount = 0,
        lastCommittedScopes = {},
        dependencyBindings = {},
    }

    local state = frame.TextRuntimeState
    state.dirty = state.dirty or {}
    state.lastCommittedScopes = state.lastCommittedScopes or {}
    state.dependencyBindings = state.dependencyBindings or {}
    if state.castTimeBindingDirty == nil then
        state.castTimeBindingDirty = true
    end
    if state.usesCastTime == nil then
        state.usesCastTime = false
    end
    return state
end

function TextState.SetPhase(frame, phase)
    local state = TextState.Ensure(frame)
    if state and type(phase) == "string" and phase ~= "" then
        state.phase = phase
    end
end

function TextState.MarkDirty(frame, reason, scope, options)
    local state = TextState.Ensure(frame)
    if not state then
        return nil
    end

    MergeDirty(state.dirty, scope)
    state.lastReason = reason or state.lastReason
    if state.phase ~= "suspended" then
        state.phase = "pending_refresh"
    end
    if ScopeTouchesTextModel(scope) then
        state.castTimeBindingDirty = true
    end
    if ScopeInvalidatesTextDependencies(scope) or (type(options) == "table" and options.invalidateTextDependencies == true) then
        state.dependencyBindings = {}
    end
    TextState.DebugLog(frame, "dirty", string.format("reason=%s", tostring(state.lastReason or "-")))
    return state
end

function TextState.GetCastTimeBinding(frame, resolveCastTimeTextKey)
    local state = TextState.Ensure(frame)
    if not state then
        return false, nil
    end

    if state.castTimeBindingDirty then
        local textKey = type(resolveCastTimeTextKey) == "function" and resolveCastTimeTextKey(frame) or nil
        local textConfig = textKey and frame and frame.config and frame.config.Texts and frame.config.Texts[textKey]
        local usesCastTime = type(textConfig) == "table" and textConfig.enabled ~= false

        state.usesCastTime = usesCastTime
        state.castTimeTextKey = usesCastTime and textKey or nil
        state.castTimeBindingDirty = false
    end

    return state.usesCastTime == true, state.castTimeTextKey
end

function TextState.SetDependencies(frame, textKey, dependencies)
    local state = TextState.Ensure(frame)
    if not state or type(textKey) ~= "string" or textKey == "" then
        return nil
    end

    state.dependencyBindings[textKey] = CopyDependencies(dependencies)
    return state.dependencyBindings[textKey]
end

function TextState.GetDependencies(frame, textKey)
    local state = TextState.Ensure(frame)
    if not state or type(textKey) ~= "string" or textKey == "" then
        return nil
    end

    return state.dependencyBindings[textKey]
end

function TextState.InvalidateDependencies(frame, textKey)
    local state = TextState.Ensure(frame)
    if not state then
        return
    end

    if type(textKey) == "string" and textKey ~= "" then
        state.dependencyBindings[textKey] = nil
        return
    end

    state.dependencyBindings = {}
end

function TextState.QueueRefresh(frame, reason, scope, options, delay)
    local state = TextState.MarkDirty(frame, reason, scope, options)
    if not state then
        return false
    end

    if RuntimeState.QueueRefresh then
        return RuntimeState.QueueRefresh(frame, reason or "texts", scope or "texts", options, delay)
    end

    return false
end

function TextState.MarkLiveValuesFresh(frame)
    local state = TextState.Ensure(frame)
    if not state then
        return
    end

    state.liveValuesVersion = (tonumber(state.liveValuesVersion) or 0) + 1
    state.phase = "live_ready"
end

function TextState.MarkRenderApplied(frame)
    local state = TextState.Ensure(frame)
    if not state then
        return
    end

    state.textModelVersion = (tonumber(state.textModelVersion) or 0) + 1
    state.visibleTextCount = CountVisibleTexts(frame)
    state.lastCommittedScopes = CopyDirty(state.dirty)
    state.dirty = {}
    state.phase = state.visibleTextCount > 0 and "rendered" or "empty_valid"
    TextState.DebugLog(frame, "render-applied", string.format("visible=%d", state.visibleTextCount))
end

function TextState.SetCastTickerActive(frame, isActive)
    local state = TextState.Ensure(frame)
    if not state then
        return
    end

    local nextValue = isActive == true
    if state.castTickerActive == nextValue then
        return
    end

    state.castTickerActive = nextValue
    TextState.DebugLog(frame, nextValue and "cast-ticker-on" or "cast-ticker-off")
end

function TextState.Reset(frame)
    if not frame then
        return
    end

    frame.TextRuntimeState = {
        phase = "empty_valid",
        dirty = {},
        lastReason = nil,
        liveValuesVersion = 0,
        textModelVersion = 0,
        castTimeBindingDirty = true,
        usesCastTime = false,
        castTimeTextKey = nil,
        castTickerActive = false,
        visibleTextCount = 0,
        lastCommittedScopes = {},
        dependencyBindings = {},
    }

    TextState.DebugLog(frame, "reset")
end
