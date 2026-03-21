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
        castTickerActive = false,
        visibleTextCount = 0,
        lastCommittedScopes = {},
    }

    local state = frame.TextRuntimeState
    state.dirty = state.dirty or {}
    state.lastCommittedScopes = state.lastCommittedScopes or {}
    return state
end

function TextState.SetPhase(frame, phase)
    local state = TextState.Ensure(frame)
    if state and type(phase) == "string" and phase ~= "" then
        state.phase = phase
    end
end

function TextState.MarkDirty(frame, reason, scope)
    local state = TextState.Ensure(frame)
    if not state then
        return nil
    end

    MergeDirty(state.dirty, scope)
    state.lastReason = reason or state.lastReason
    if state.phase ~= "suspended" then
        state.phase = "pending_refresh"
    end
    TextState.DebugLog(frame, "dirty", string.format("reason=%s", tostring(state.lastReason or "-")))
    return state
end

function TextState.QueueRefresh(frame, reason, scope, options, delay)
    local state = TextState.MarkDirty(frame, reason, scope)
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
        castTickerActive = false,
        visibleTextCount = 0,
        lastCommittedScopes = {},
    }

    TextState.DebugLog(frame, "reset")
end
