local _, FocalPoint = ...

FocalPoint.GUI = FocalPoint.GUI or {}
FocalPoint.GUI.Editor = FocalPoint.GUI.Editor or {}

local EditorMode = {}
FocalPoint.EditorMode = EditorMode
FocalPoint.GUI.Editor.Mode = EditorMode

local function Result(ok, details)
    details = type(details) == "table" and details or {}
    details.ok = ok and true or false
    return details
end

local function ResolveProfileMode(profile)
    local general = type(profile) == "table" and profile.General or nil
    if type(general) == "table" then
        return general.ExpertMode == true and "expert" or "quick"
    end

    return nil
end

function EditorMode.Normalize(mode)
    return mode == "expert" and "expert" or "quick"
end

function EditorMode.Resolve(state, profile)
    local profileMode = ResolveProfileMode(profile)
    if profileMode then
        return profileMode
    end

    return EditorMode.Normalize(type(state) == "table" and state.mode or nil)
end

function EditorMode.IsQuick(modeOrContext)
    local mode = type(modeOrContext) == "table" and modeOrContext.mode or modeOrContext
    return EditorMode.Normalize(mode) == "quick"
end

function EditorMode.IsExpert(modeOrContext)
    local mode = type(modeOrContext) == "table" and modeOrContext.mode or modeOrContext
    return EditorMode.Normalize(mode) == "expert"
end

function EditorMode.SyncStateFromProfile(state, profile)
    if type(state) ~= "table" then
        return Result(false, { errorCode = "invalid_context" })
    end

    local mode = EditorMode.Resolve(state, profile)
    local oldMode = EditorMode.Normalize(state.mode)
    local changed = oldMode ~= mode
    if changed then
        state.mode = mode
    end

    return Result(true, {
        changed = changed,
        mode = mode,
        expertMode = mode == "expert",
    })
end

function EditorMode.Set(state, profile, mode)
    if type(state) ~= "table" then
        return Result(false, { errorCode = "invalid_context" })
    end

    local general = type(profile) == "table" and profile.General or nil
    if type(general) ~= "table" then
        return Result(false, { errorCode = "general_config_not_found" })
    end

    local normalizedMode = EditorMode.Normalize(mode)
    local expertMode = normalizedMode == "expert"
    local oldMode = EditorMode.Normalize(state.mode)
    local oldExpertMode = general.ExpertMode == true
    local changed = oldMode ~= normalizedMode or oldExpertMode ~= expertMode

    if changed then
        state.mode = normalizedMode
        general.ExpertMode = expertMode
    end

    return Result(true, {
        changed = changed,
        mode = normalizedMode,
        expertMode = expertMode,
    })
end

return EditorMode
