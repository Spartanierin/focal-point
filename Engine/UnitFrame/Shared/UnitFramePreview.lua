local _, FocalPoint = ...

FocalPoint.UnitFramePreview = FocalPoint.UnitFramePreview or {}
local Preview = FocalPoint.UnitFramePreview
local Utils = FocalPoint.UnitFrameUtils or {}
local ToSafeNumberValue = Utils.ToSafeNumberValue
local FormatDisplayNumber = Utils.FormatDisplayNumber

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

local TEST_PREVIEW_AURAS = {
    detailed = {
        Buffs = {
            {
                spellId = 17,
                name = "Power Word: Shield",
                icon = "Interface\\Icons\\Spell_Holy_PowerWordShield",
                duration = 15,
                remaining = 11,
                count = 0,
                isMine = true,
                isPlayerCast = true,
            },
            {
                spellId = 2825,
                name = "Bloodlust",
                icon = "Interface\\Icons\\Spell_Nature_BloodLust",
                duration = 40,
                remaining = 26,
                count = 0,
                isMine = false,
                isPlayerCast = false,
            },
            {
                spellId = 6673,
                name = "Battle Shout",
                icon = "Interface\\Icons\\Ability_Warrior_BattleShout",
                duration = 300,
                remaining = 180,
                count = 0,
                isMine = true,
                isPlayerCast = true,
            },
            {
                spellId = 31884,
                name = "Avenging Wrath",
                icon = "Interface\\Icons\\Spell_Holy_AvengineWrath",
                duration = 20,
                remaining = 9,
                count = 0,
                isMine = true,
                isPlayerCast = true,
            },
            {
                spellId = 29166,
                name = "Innervate",
                icon = "Interface\\Icons\\Spell_Nature_Lightning",
                duration = 10,
                remaining = 7,
                count = 0,
                isMine = false,
                isPlayerCast = false,
            },
            {
                spellId = 11426,
                name = "Ice Barrier",
                icon = "Interface\\Icons\\Spell_Ice_Lament",
                duration = 60,
                remaining = 32,
                count = 0,
                isMine = false,
                isPlayerCast = false,
                isStealable = true,
            },
        },
        Debuffs = {
            {
                spellId = 589,
                name = "Shadow Word: Pain",
                icon = "Interface\\Icons\\Spell_Shadow_ShadowWordPain",
                duration = 16,
                remaining = 14,
                count = 0,
                isMine = true,
                isPlayerCast = true,
                dispelName = "Magic",
            },
            {
                spellId = 34914,
                name = "Vampiric Touch",
                icon = "Interface\\Icons\\Spell_Holy_Stoicism",
                duration = 21,
                remaining = 18,
                count = 0,
                isMine = true,
                isPlayerCast = true,
                dispelName = "Magic",
            },
            {
                spellId = 25771,
                name = "Forbearance",
                icon = "Interface\\Icons\\Spell_Holy_RemoveCurse",
                duration = 30,
                remaining = 20,
                count = 0,
                isMine = false,
                isPlayerCast = false,
            },
            {
                spellId = 116,
                name = "Frostbolt",
                icon = "Interface\\Icons\\Spell_Frost_FrostBolt02",
                duration = 8,
                remaining = 5,
                count = 0,
                isMine = false,
                isPlayerCast = false,
                dispelName = "Magic",
            },
            {
                spellId = 20066,
                name = "Repentance",
                icon = "Interface\\Icons\\Spell_Holy_PrayerOfHealing",
                duration = 12,
                remaining = 6,
                count = 0,
                isMine = true,
                isPlayerCast = true,
            },
            {
                spellId = 204242,
                name = "Consecration Burn",
                icon = "Interface\\Icons\\Ability_Paladin_Consecration",
                duration = 9,
                remaining = 4,
                count = 2,
                isMine = true,
                isPlayerCast = true,
                isBossAura = true,
            },
        },
    },
    placeholder = {
        Buffs = {
            {
                spellId = 17,
                name = "Power Word: Shield",
                icon = "Interface\\Icons\\Spell_Holy_PowerWordShield",
                duration = 15,
                remaining = 10,
                count = 0,
                isMine = true,
                isPlayerCast = true,
            },
            {
                spellId = 2825,
                name = "Bloodlust",
                icon = "Interface\\Icons\\Spell_Nature_BloodLust",
                duration = 40,
                remaining = 24,
                count = 0,
                isMine = false,
                isPlayerCast = false,
            },
            {
                spellId = 11426,
                name = "Ice Barrier",
                icon = "Interface\\Icons\\Spell_Ice_Lament",
                duration = 60,
                remaining = 28,
                count = 0,
                isMine = false,
                isPlayerCast = false,
                isStealable = true,
            },
        },
        Debuffs = {
            {
                spellId = 589,
                name = "Shadow Word: Pain",
                icon = "Interface\\Icons\\Spell_Shadow_ShadowWordPain",
                duration = 16,
                remaining = 12,
                count = 0,
                isMine = true,
                isPlayerCast = true,
                dispelName = "Magic",
            },
            {
                spellId = 116,
                name = "Frostbolt",
                icon = "Interface\\Icons\\Spell_Frost_FrostBolt02",
                duration = 8,
                remaining = 5,
                count = 0,
                isMine = false,
                isPlayerCast = false,
                dispelName = "Magic",
            },
            {
                spellId = 204242,
                name = "Consecration Burn",
                icon = "Interface\\Icons\\Ability_Paladin_Consecration",
                duration = 9,
                remaining = 4,
                count = 2,
                isMine = true,
                isPlayerCast = true,
                isBossAura = true,
            },
        },
    },
}

local ALTERNATE_POWER_INDEX = Enum and Enum.PowerType and Enum.PowerType.Alternate or 10
local MANA_POWER_INDEX = Enum and Enum.PowerType and Enum.PowerType.Mana or 0

-- Preview helpers provide stable fake values for test/unlock mode
-- and encapsulate alternate power lookup for both live and editor states.

local function GetSelectedEditorUnit()
    local editorState = FocalPoint.GUI and FocalPoint.GUI.Editor and FocalPoint.GUI.Editor.State
    local state = editorState and editorState.Get and editorState.Get() or nil
    return state and state.selectedUnit or nil
end

function Preview.ShouldForceSecondaryPowerPreview(unit)
    if unit ~= "player" then
        return false
    end

    local unitConfig = FocalPoint.UnitFrameUtils
        and FocalPoint.UnitFrameUtils.GetUnitDB
        and FocalPoint.UnitFrameUtils.GetUnitDB(unit)
    if type(unitConfig) ~= "table" or unitConfig.showAlternativePowerBar ~= true then
        return false
    end

    if FocalPoint.guiTestModeEnabled then
        return true
    end

    return FocalPoint.framesUnlocked and GetSelectedEditorUnit() == "player"
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

local function BuildPreviewAura(definition, frame, groupKey, index)
    if type(definition) ~= "table" or not frame or not groupKey then
        return nil
    end

    local now = (GetTime and GetTime()) or 0
    local duration = tonumber(definition.duration) or 0
    local remaining = tonumber(definition.remaining)
    if remaining == nil then
        remaining = duration
    end
    remaining = math.max(remaining or 0, 0)

    local durationState = duration > 0 and "TIMED" or "PERMANENT"
    local expirationTime = duration > 0 and (now + remaining) or 0
    local isHelpful = groupKey == "Buffs"
    local isHarmful = groupKey == "Debuffs"
    local count = tonumber(definition.count) or 0
    local spellId = tonumber(definition.spellId) or (100000 + index)
    local unitSeed = string.len(tostring(frame.unit or "")) * 1000

    return {
        spellId = spellId,
        auraInstanceId = unitSeed + ((isHelpful and 10000) or 20000) + index,
        name = definition.name or "",
        icon = definition.icon,
        isHelpful = isHelpful,
        isHarmful = isHarmful,
        count = count,
        duration = duration,
        expirationTime = expirationTime,
        remaining = remaining,
        durationObject = nil,
        durationSource = "PREVIEW",
        durationState = durationState,
        timerState = duration > 0 and "READY" or "NONE",
        durationObjectPresent = false,
        timerReadable = duration > 0,
        sourceUnit = definition.sourceUnit or "player",
        sourceGUID = nil,
        isPlayerCast = definition.isPlayerCast ~= false,
        isMine = definition.isMine ~= false,
        isBossAura = definition.isBossAura == true,
        isStealable = definition.isStealable == true,
        dispelName = definition.dispelName,
        canApplyAura = definition.canApplyAura == true,
        durationKnown = true,
        hasDuration = duration > 0,
        hasStacks = count > 1,
        sourceIndex = index,
        sortKey = index,
    }
end

function Preview.GetTestAuras(frame, groupKey)
    if not frame or not frame.unit or (groupKey ~= "Buffs" and groupKey ~= "Debuffs") then
        return nil
    end

    local previewSet = nil
    if Preview.IsDetailedPreviewEnabled(frame) then
        previewSet = TEST_PREVIEW_AURAS.detailed
    elseif Preview.IsPlaceholderPreviewEnabled(frame) then
        previewSet = TEST_PREVIEW_AURAS.placeholder
    else
        return nil
    end

    local definitions = previewSet and previewSet[groupKey] or nil
    if type(definitions) ~= "table" then
        return {}
    end

    local auras = {}
    for index, definition in ipairs(definitions) do
        local aura = BuildPreviewAura(definition, frame, groupKey, index)
        if aura then
            auras[#auras + 1] = aura
        end
    end

    return auras
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

local function GetAlternatePowerBarInfo(unit)
    if type(unit) ~= "string" or unit == "" then
        return nil, nil
    end

    if not UnitPowerBarID or not GetUnitPowerBarInfoByID then
        return nil, nil
    end

    local barID = UnitPowerBarID(unit)
    if not barID then
        return nil, nil
    end

    local barInfo = GetUnitPowerBarInfoByID(barID)
    if type(barInfo) ~= "table" then
        return barID, nil
    end

    return barID, barInfo
end

local function GetManaSecondaryPowerValues(unit)
    if unit ~= "player" or not UnitPowerMax then
        return nil, 0, 0, 0
    end

    local primaryPowerType = UnitPowerType and UnitPowerType(unit) or nil
    if primaryPowerType == MANA_POWER_INDEX then
        return nil, 0, 0, 0
    end

    local maxMana = ToSafeNumberValue(UnitPowerMax(unit, MANA_POWER_INDEX))
    if maxMana <= 0 then
        return nil, 0, 0, 0
    end

    local currentMana = UnitPower and UnitPower(unit, MANA_POWER_INDEX) or 0
    local currentManaSafe = ToSafeNumberValue(currentMana)

    if UnitPower then
        local unmodifiedMana = UnitPower(unit, MANA_POWER_INDEX, true)
        local unmodifiedManaSafe = ToSafeNumberValue(unmodifiedMana)
        if currentManaSafe <= 0 and unmodifiedManaSafe > 0 then
            currentMana = unmodifiedMana
            currentManaSafe = unmodifiedManaSafe
        end
    end

    if currentManaSafe <= 0 and maxMana > 0 and not (issecretvalue and issecretvalue(currentMana)) then
        currentMana = currentManaSafe
    end

    return MANA_POWER_INDEX, currentMana, maxMana, 0
end

local function FormatSecondaryPowerDisplayText(rawValue, safeValue)
    if FormatDisplayNumber then
        local ok, result = pcall(FormatDisplayNumber, rawValue)
        if ok and type(result) == "string" then
            return result
        end
    end

    do
        local ok, result = pcall(tostring, rawValue)
        if ok and type(result) == "string" then
            return result
        end
    end

    if FormatDisplayNumber then
        local ok, result = pcall(FormatDisplayNumber, safeValue)
        if ok and type(result) == "string" then
            return result
        end
    end

    local ok, result = pcall(tostring, safeValue or 0)
    if ok and type(result) == "string" then
        return result
    end

    return "0"
end

local function IsAlternatePowerVisible(unit, barInfo)
    if type(unit) ~= "string" or unit == "" or type(barInfo) ~= "table" then
        return false
    end

    local visibleOnRaid = barInfo.showOnRaid
        and ((UnitInParty and UnitInParty(unit)) or (UnitInRaid and UnitInRaid(unit)))
    local visibleForOthers = not barInfo.hideFromOthers
    local isPlayerUnit = UnitIsUnit and UnitIsUnit(unit, "player")

    return visibleOnRaid or visibleForOthers or isPlayerUnit
end

local function GetForcedSecondaryPowerPreviewValues(unit)
    if not Preview.ShouldForceSecondaryPowerPreview(unit) then
        return nil, 0, 0, 0
    end

    local previewValues = TEST_PREVIEW_VALUES[unit] or TEST_PREVIEW_VALUES.player or {}
    local minPower = tonumber(previewValues.altPowerMin) or 0
    local maxPower = tonumber(previewValues.altPowerMax) or 100
    local currentPower = tonumber(previewValues.altPowerCurrent)

    if type(currentPower) ~= "number" then
        currentPower = maxPower
    end

    return ALTERNATE_POWER_INDEX, currentPower, maxPower, minPower
end

function Preview.GetSecondaryPowerTypeForUnit(unit)
    local _, barInfo = GetAlternatePowerBarInfo(unit)
    if IsAlternatePowerVisible(unit, barInfo) then
        return ALTERNATE_POWER_INDEX
    end

    local manaPowerType = GetManaSecondaryPowerValues(unit)
    if manaPowerType ~= nil then
        return manaPowerType
    end

    local previewPowerType = GetForcedSecondaryPowerPreviewValues(unit)
    return previewPowerType
end

function Preview.GetSecondaryPowerValues(unit)
    local _, barInfo = GetAlternatePowerBarInfo(unit)
    if IsAlternatePowerVisible(unit, barInfo) then
        local minPower = tonumber(barInfo.minPower) or 0
        local currentPower = UnitPower and UnitPower(unit, ALTERNATE_POWER_INDEX) or minPower
        local maxPower = UnitPowerMax and UnitPowerMax(unit, ALTERNATE_POWER_INDEX) or minPower

        return ALTERNATE_POWER_INDEX, currentPower or minPower, maxPower or minPower, minPower
    end

    local manaPowerType, currentMana, maxMana, minMana = GetManaSecondaryPowerValues(unit)
    if manaPowerType ~= nil then
        return manaPowerType, currentMana, maxMana, minMana
    end

    return GetForcedSecondaryPowerPreviewValues(unit)
end

function Preview.GetSecondaryPowerDisplayValues(unit)
    local powerType, currentValue, maxValue = Preview.GetSecondaryPowerValues(unit)
    if powerType == nil then
        return nil, "0", "0", 0, 0, 0
    end

    local safeMax = ToSafeNumberValue(maxValue)
    local safeCurrent = ToSafeNumberValue(currentValue)
    local currentText = FormatSecondaryPowerDisplayText(currentValue, safeCurrent)
    local maxText = FormatSecondaryPowerDisplayText(maxValue, safeMax)

    if safeCurrent <= 0 and safeMax > 0 and UnitPowerMissing then
        local missingValue = ToSafeNumberValue(UnitPowerMissing(unit, powerType))
        if missingValue >= 0 and missingValue <= safeMax then
            safeCurrent = math.max(0, safeMax - missingValue)
        end
    end

    if safeCurrent <= 0 and safeMax > 0 and UnitPowerPercent then
        local percentValue = ToSafeNumberValue(UnitPowerPercent(unit, powerType, false, CurveConstants and CurveConstants.ScaleTo100))
        if percentValue > 0 then
            safeCurrent = math.max(0, math.min(safeMax, math.floor((safeMax * percentValue / 100) + 0.5)))
        end
    end

    return powerType,
        currentText,
        maxText,
        safeMax,
        safeCurrent,
        safeMax
end

function Preview.IsIndicatorVisible(frame, indicatorKey)
    if not frame or not indicatorKey or not frame.unit then
        return false
    end

    return Preview.IsDetailedPreviewEnabled(frame)
end
