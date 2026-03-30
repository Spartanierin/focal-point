local _, FocalPoint = ...

FocalPoint.UnitFramePreview = FocalPoint.UnitFramePreview or {}
local Preview = FocalPoint.UnitFramePreview

local TEST_PREVIEW_VALUES = {
    player = {
        healthCurrent = 146000,
        healthMax = 146000,
        powerCurrent = 84,
        powerMax = 100,
        altPowerCurrent = 72,
        altPowerMax = 100,
        name = "Spartanierin",
        level = 84,
        classToken = "WARRIOR",
        role = "DAMAGER",
        race = "Mensch",
        castName = "Schildschlag",
        castDuration = 2.5,
    },
    target = {
        healthCurrent = 108000,
        healthMax = 146000,
        powerCurrent = 42,
        powerMax = 100,
        altPowerCurrent = 0,
        altPowerMax = 0,
        name = "Zielattrappe",
        level = 83,
        classToken = "PALADIN",
        role = "TANK",
        creature = "Humanoid",
        castName = "Frostblitz",
        castDuration = 2.5,
    },
    focus = {
        healthCurrent = 92000,
        healthMax = 120000,
        powerCurrent = 55,
        powerMax = 100,
        altPowerCurrent = 0,
        altPowerMax = 0,
        name = "Fokusziel",
        level = 83,
        classToken = "PRIEST",
        role = "HEALER",
        creature = "Humanoid",
        castName = "Heilung",
        castDuration = 2.5,
    },
    pet = {
        healthCurrent = 72000,
        healthMax = 90000,
        powerCurrent = 70,
        powerMax = 100,
        altPowerCurrent = 0,
        altPowerMax = 0,
        name = "Begleiter",
        level = 83,
        role = "DAMAGER",
        creature = "Wildtier",
    },
    boss1 = {
        healthCurrent = 125000,
        healthMax = 160000,
        powerCurrent = 45,
        powerMax = 100,
        altPowerCurrent = 0,
        altPowerMax = 0,
        name = "Boss Eins",
        level = -1,
        creature = "Boss",
        castName = "Verheerender Schlag",
        castDuration = 2.5,
    },
    boss2 = {
        healthCurrent = 98000,
        healthMax = 160000,
        powerCurrent = 62,
        powerMax = 100,
        altPowerCurrent = 0,
        altPowerMax = 0,
        name = "Boss Zwei",
        level = -1,
        creature = "Boss",
        castName = "Leerennova",
        castDuration = 2.1,
    },
    boss3 = {
        healthCurrent = 76000,
        healthMax = 160000,
        powerCurrent = 28,
        powerMax = 100,
        altPowerCurrent = 0,
        altPowerMax = 0,
        name = "Boss Drei",
        level = -1,
        creature = "Boss",
        castName = "Seelensog",
        castDuration = 1.7,
    },
    boss4 = {
        healthCurrent = 141000,
        healthMax = 160000,
        powerCurrent = 84,
        powerMax = 100,
        altPowerCurrent = 0,
        altPowerMax = 0,
        name = "Boss Vier",
        level = -1,
        creature = "Boss",
        castName = "Schattenlanze",
        castDuration = 2.8,
    },
    boss5 = {
        healthCurrent = 112000,
        healthMax = 160000,
        powerCurrent = 51,
        powerMax = 100,
        altPowerCurrent = 0,
        altPowerMax = 0,
        name = "Boss Fuenf",
        level = -1,
        creature = "Boss",
        castName = "Kettenblitz",
        castDuration = 2.2,
    },
}

local PLACEHOLDER_PREVIEW_VALUES = {
    player = {
        healthCurrent = 100,
        healthMax = 100,
        powerCurrent = 0,
        powerMax = 100,
        name = "Spieler",
    },
    target = {
        healthCurrent = 100,
        healthMax = 100,
        powerCurrent = 0,
        powerMax = 100,
        name = "Ziel",
    },
    focus = {
        healthCurrent = 100,
        healthMax = 100,
        powerCurrent = 0,
        powerMax = 100,
        name = "Fokus",
    },
    targettarget = {
        healthCurrent = 100,
        healthMax = 100,
        powerCurrent = 0,
        powerMax = 100,
        name = "Ziel des Ziels",
    },
    focustarget = {
        healthCurrent = 100,
        healthMax = 100,
        powerCurrent = 0,
        powerMax = 100,
        name = "Fokusziel",
    },
    pet = {
        healthCurrent = 100,
        healthMax = 100,
        powerCurrent = 0,
        powerMax = 100,
        name = "Begleiter",
    },
    boss = {
        healthCurrent = 100,
        healthMax = 100,
        powerCurrent = 0,
        powerMax = 100,
        name = "Boss",
    },
    boss1 = {
        healthCurrent = 100,
        healthMax = 100,
        powerCurrent = 0,
        powerMax = 100,
        name = "Boss 1",
    },
    boss2 = {
        healthCurrent = 100,
        healthMax = 100,
        powerCurrent = 0,
        powerMax = 100,
        name = "Boss 2",
    },
    boss3 = {
        healthCurrent = 100,
        healthMax = 100,
        powerCurrent = 0,
        powerMax = 100,
        name = "Boss 3",
    },
    boss4 = {
        healthCurrent = 100,
        healthMax = 100,
        powerCurrent = 0,
        powerMax = 100,
        name = "Boss 4",
    },
    boss5 = {
        healthCurrent = 100,
        healthMax = 100,
        powerCurrent = 0,
        powerMax = 100,
        name = "Boss 5",
    },
}

local SECONDARY_POWER_BAR_SPECS = {
    [258] = 0, -- Shadow Priest -> Mana
    [262] = 0, -- Elemental Shaman -> Mana
}

-- Preview helpers provide stable fake values for test/unlock mode
-- and encapsulate the small amount of secondary power lookup logic.

local function GetSelectedEditorUnit()
    local editorState = FocalPoint.GUI and FocalPoint.GUI.Editor and FocalPoint.GUI.Editor.State
    local state = editorState and editorState.Get and editorState.Get() or nil
    return state and state.selectedUnit or nil
end

local function IsSelectedEditorFrame(frame)
    if not frame or not frame.unit then
        return false
    end

    local selectedUnit = GetSelectedEditorUnit()
    if type(selectedUnit) ~= "string" or selectedUnit == "" then
        return false
    end

    if selectedUnit == "boss" then
        return frame.unit:match("^boss%d+$") ~= nil
    end

    return frame.unit == selectedUnit
end

function Preview.IsDetailedPreviewEnabled(frame)
    if FocalPoint.guiTestModeEnabled then
        return true
    end

    if FocalPoint.framesUnlocked then
        return IsSelectedEditorFrame(frame)
    end

    return false
end

function Preview.IsPlaceholderPreviewEnabled(frame)
    return FocalPoint.framesUnlocked and not FocalPoint.guiTestModeEnabled and not Preview.IsDetailedPreviewEnabled(frame)
end

function Preview.GetTestValues(frame)
    if not frame or not frame.unit then
        return nil
    end

    if Preview.IsDetailedPreviewEnabled(frame) then
        return TEST_PREVIEW_VALUES[frame.unit] or TEST_PREVIEW_VALUES.target or TEST_PREVIEW_VALUES.player
    end

    if Preview.IsPlaceholderPreviewEnabled(frame) then
        return PLACEHOLDER_PREVIEW_VALUES[frame.unit]
            or PLACEHOLDER_PREVIEW_VALUES.boss
            or PLACEHOLDER_PREVIEW_VALUES.target
            or PLACEHOLDER_PREVIEW_VALUES.player
    end

    return nil
end

function Preview.GetRaidTargetIndex(frame)
    local previewMap = {
        player = 1,
        target = 8,
        focus = 3,
        pet = 2,
        targettarget = 7,
        focustarget = 4,
        boss = 6,
        boss1 = 1,
        boss2 = 2,
        boss3 = 3,
        boss4 = 4,
        boss5 = 5,
    }

    return previewMap[frame and frame.unit or ""] or 1
end

function Preview.GetPlayerSpecializationID()
    if not GetSpecialization or not GetSpecializationInfo then
        return nil
    end

    local specializationIndex = GetSpecialization()
    if not specializationIndex then
        return nil
    end

    local specializationID = GetSpecializationInfo(specializationIndex)
    if type(specializationID) ~= "number" then
        return nil
    end

    return specializationID
end

function Preview.GetSecondaryPowerTypeForUnit(unit)
    if unit ~= "player" then
        return nil
    end

    local specializationID = Preview.GetPlayerSpecializationID()
    if not specializationID then
        return nil
    end

    return SECONDARY_POWER_BAR_SPECS[specializationID]
end

function Preview.GetSecondaryPowerValues(unit)
    local secondaryPowerType = Preview.GetSecondaryPowerTypeForUnit(unit)
    if secondaryPowerType == nil or not UnitPower or not UnitPowerMax then
        return nil, 0, 0
    end

    return secondaryPowerType, UnitPower(unit, secondaryPowerType) or 0, UnitPowerMax(unit, secondaryPowerType) or 0
end

function Preview.IsIndicatorVisible(frame, indicatorKey)
    if not frame or not indicatorKey or not frame.unit then
        return false
    end

    return Preview.IsDetailedPreviewEnabled(frame)
end
