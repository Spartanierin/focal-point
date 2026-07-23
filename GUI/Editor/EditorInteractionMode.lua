local _, FocalPoint = ...

FocalPoint.GUI = FocalPoint.GUI or {}
FocalPoint.GUI.Editor = FocalPoint.GUI.Editor or {}

local EditorInteractionMode = {}
FocalPoint.GUI.Editor.InteractionMode = EditorInteractionMode

local state = {
    shiftDown = false,
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
    if state.shiftDown == true or state.latchedTextMode == true then
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

local function SetShiftState(isDown)
    local nextValue = isDown and true or false
    if state.shiftDown == nextValue then
        return false
    end
    state.shiftDown = nextValue
    return true
end

local function IsShiftModifierKey(key)
    return key == "LSHIFT" or key == "RSHIFT" or key == "SHIFT"
end

local function IsModifierDownValue(value)
    return value == 1 or value == true
end

function EditorInteractionMode.SetShiftDown(isDown)
    local changed = SetShiftState(isDown)
    if changed then
        RefreshInteractionVisualsIfChanged(false)
    end
    return changed
end

function EditorInteractionMode.IsShiftDown()
    return state.shiftDown == true
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
    if IsShiftKeyDown then
        SetShiftState(IsShiftKeyDown() == true)
    end
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
                EditorInteractionMode.SetShiftDown(IsModifierDownValue(down))
            end
            return
        end

        RefreshInteractionVisualsIfChanged(true)
    end)
end

if IsShiftKeyDown then
    state.shiftDown = IsShiftKeyDown() == true
end
state.lastMode = ResolveMode()

return EditorInteractionMode
