local _, FocalPoint = ...

FocalPoint.GUI = FocalPoint.GUI or {}
FocalPoint.GUI.Editor = FocalPoint.GUI.Editor or {}

local EditorInteractionMode = {}
FocalPoint.GUI.Editor.InteractionMode = EditorInteractionMode

local state = {
    shiftKeysDown = {},
    latchedTextMode = false,
    lastMode = nil,
}

local function IsEditorUnlocked()
    return FocalPoint
        and FocalPoint.framesUnlocked == true
        and FocalPoint.IsEditorActive
        and FocalPoint:IsEditorActive()
end

local function IsCombatLocked()
    return InCombatLockdown and InCombatLockdown() == true
end

local function ResolveMode()
    if not IsEditorUnlocked() then
        return "inactive"
    end
    if IsCombatLocked() then
        return "combat-blocked"
    end
    if state.latchedTextMode == true then
        return "text"
    end
    return "frame"
end

local function RefreshInteractionVisualsIfChanged(force)
    local mode = ResolveMode()
    if not force and mode == state.lastMode then
        return mode
    end

    state.lastMode = mode
    if FocalPoint and FocalPoint.RefreshEditorInteractionVisuals then
        FocalPoint:RefreshEditorInteractionVisuals()
    elseif FocalPoint and FocalPoint.RefreshEditorSelectionVisuals then
        FocalPoint:RefreshEditorSelectionVisuals()
    end
    return mode
end

local function IsTypingFocusActive()
    if not GetCurrentKeyBoardFocus then
        return false
    end

    local ok, focus = pcall(GetCurrentKeyBoardFocus)
    if not ok then
        return false
    end

    return focus ~= nil
end

local function SetShiftKeyState(key, isDown)
    key = type(key) == "string" and key ~= "" and key or "SHIFT"
    local nextValue = isDown and true or false
    if state.shiftKeysDown[key] == nextValue then
        return false
    end
    state.shiftKeysDown[key] = nextValue or nil
    return true
end

local function IsShiftModifierKey(key)
    return key == "LSHIFT" or key == "RSHIFT" or key == "SHIFT"
end

local function IsModifierDownValue(value)
    return value == 1 or value == true
end

function EditorInteractionMode.SetShiftDown(isDown)
    return SetShiftKeyState("SHIFT", isDown)
end

function EditorInteractionMode.IsShiftDown()
    for _, isDown in pairs(state.shiftKeysDown) do
        if isDown == true then
            return true
        end
    end

    return false
end

function EditorInteractionMode.SetLatchedTextMode(enabled)
    local nextValue = enabled and true or false
    if state.latchedTextMode == nextValue then
        return false
    end
    state.latchedTextMode = nextValue
    RefreshInteractionVisualsIfChanged(false)
    return true
end

function EditorInteractionMode.IsLatchedTextMode()
    return state.latchedTextMode == true
end

function EditorInteractionMode.ToggleTextMode()
    if not IsEditorUnlocked() or IsCombatLocked() or IsTypingFocusActive() then
        return false
    end

    return EditorInteractionMode.SetLatchedTextMode(not state.latchedTextMode)
end

function EditorInteractionMode.ResetToFrameMode(force)
    state.shiftKeysDown = {}
    if state.latchedTextMode ~= false then
        state.latchedTextMode = false
        RefreshInteractionVisualsIfChanged(force == true)
        return true
    end

    if force then
        RefreshInteractionVisualsIfChanged(true)
    end
    return false
end

function EditorInteractionMode.Resolve()
    return ResolveMode()
end

function EditorInteractionMode.IsFrameMode()
    return ResolveMode() == "frame"
end

function EditorInteractionMode.IsTextMode()
    return ResolveMode() == "text"
end

function EditorInteractionMode.SyncShiftState()
    return RefreshInteractionVisualsIfChanged(true)
end

function EditorInteractionMode.Refresh(force)
    return RefreshInteractionVisualsIfChanged(force == true)
end

local eventFrame = CreateFrame and CreateFrame("Frame") or nil
if eventFrame then
    eventFrame:RegisterEvent("MODIFIER_STATE_CHANGED")
    eventFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
    eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
    eventFrame:SetScript("OnEvent", function(_, event, key, down)
        if event == "MODIFIER_STATE_CHANGED" then
            if IsShiftModifierKey(key) then
                local isDown = IsModifierDownValue(down)
                local wasShiftDown = EditorInteractionMode.IsShiftDown()
                local changed = SetShiftKeyState(key, isDown)
                if isDown and changed and not wasShiftDown then
                    EditorInteractionMode.ToggleTextMode()
                end
            end
            return
        end

        RefreshInteractionVisualsIfChanged(true)
    end)
end
state.lastMode = ResolveMode()

return EditorInteractionMode
