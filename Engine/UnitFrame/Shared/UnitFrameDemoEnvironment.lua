local _, FocalPoint = ...

FocalPoint.UnitFrameDemoEnvironment = FocalPoint.UnitFrameDemoEnvironment or {}
local Demo = FocalPoint.UnitFrameDemoEnvironment
local Utils = FocalPoint.UnitFrameUtils or {}
local Visibility = FocalPoint.UnitFrameVisibility or {}
local ToSafeNumberValue = Utils.ToSafeNumberValue
local FormatDisplayNumber = Utils.FormatDisplayNumber
local ResolveBlizzardAbbreviation = Utils.ResolveBlizzardAbbreviation

local PLACEHOLDER_COLORS = {
    barR = 0.24,
    barG = 0.28,
    barB = 0.34,
    barA = 0.62,
    disabledBarA = 0.18,
    bgR = 0.08,
    bgG = 0.10,
    bgB = 0.13,
    bgA = 0.30,
    disabledBgA = 0.10,
}

local EXIT_TRACE_DETAIL_LIMIT = 20
local EXIT_TRACE_RESULT_ORDER = {
    "present-after-handle",
    "missing-alpha-only",
    "missing-alpha-and-hide",
    "missing-hide-skipped-combat",
    "missing-still-visible",
}
local EXIT_TRACE_UNIT_ORDER = {
    "target",
    "targettarget",
    "focus",
    "focustarget",
    "pet",
    "boss1-boss5",
}
local EXIT_TRACE_CLEANUP_ORDER = {
    "target-exit-cleanup",
    "boss-exit-cleanup",
    "derived-exit-cleanup",
    "pet-exit-cleanup",
}

function Demo.IsDebugEnabled()
    return FocalPoint and FocalPoint.debugDemoRuntime == true
end

function Demo.GetPlaceholderColors()
    return PLACEHOLDER_COLORS
end

local function ResolveDecisionAlpha(decision, fallback)
    if decision
        and decision.writesImmediately == true
        and type(decision.finalAlpha) == "number"
    then
        return decision.finalAlpha
    end

    return fallback
end

local function EnsureDemoDebug(frame)
    if not frame then
        return nil
    end
    frame.FocalPointDemoDebug = frame.FocalPointDemoDebug or {
        refreshApply = 0,
        snapshotApply = 0,
        runtimeApply = 0,
        applyConfig = 0,
        castStartPreview = 0,
        castStop = 0,
        auraRefresh = 0,
        auraRender = 0,
        auraClear = 0,
        cleanup = 0,
        cleanupAttempt = 0,
        cleanupBlocked = 0,
        cleanupExecuted = 0,
        modeChanges = 0,
        lastMode = nil,
        lastReport = 0,
        modeReason = "unknown",
        cleanupReason = "unknown",
        configReason = "unknown",
        castStartReason = "unknown",
        testModeExitCount = 0,
        testModeExitReason = "unknown",
        visibilityResyncCount = 0,
        framesHiddenOnExit = 0,
        framesStillVisibleMissingUnit = 0,
        exitCleanup = 0,
        hiddenOnExit = false,
        missingUnitAfterExit = false,
        modeTransitions = "",
        resolveCalls = 0,
        resolveFromRefresh = 0,
        resolveFromSnapshot = 0,
        resolveFromRuntime = 0,
        resolveFromCleanup = 0,
        resolveFromVisibility = 0,
        resolveFromText = 0,
        resolveFromAura = 0,
        resolveFromCast = 0,
        resolveFromOther = 0,
        commitCalls = 0,
        modeResolvedThisApply = "unknown",
        modeCommittedThisApply = "unknown",
        castbarOnUpdateTicks = 0,
        castbarValueUpdates = 0,
        castbarPreviewValueUpdates = 0,
        castbarPreviewElapsed = 0,
        castbarPreviewDuration = 0,
        castbarPreviewUpdateMode = "unknown",
        auraCooldownUpdates = 0,
        auraTimerTextUpdates = 0,
        barSmoothingTicks = 0,
        rangeFadeTicks = 0,
    }
    return frame.FocalPointDemoDebug
end

local function EnsureExitTraceDebug()
    FocalPoint.DemoExitTestModeTrace = FocalPoint.DemoExitTestModeTrace or {
        comparisons = 0,
        byResult = {},
        byUnit = {},
        byReason = {},
        byCleanup = {},
        handleMissingResult = {},
        additionalAlphaZeroWrites = 0,
        additionalHideAttempts = 0,
        hideSkippedByCombat = 0,
        stillVisibleMissingAfterExit = 0,
        recent = {},
    }
    return FocalPoint.DemoExitTestModeTrace
end

local function ResetExitTraceDebug()
    FocalPoint.DemoExitTestModeTrace = nil
    EnsureExitTraceDebug()
end

local function IncrementCounter(bucket, key)
    if type(bucket) ~= "table" then
        return
    end
    key = tostring(key or "unknown")
    bucket[key] = (tonumber(bucket[key]) or 0) + 1
end

local function IsBossUnit(unit)
    return type(unit) == "string" and unit:match("^boss%d+$") ~= nil
end

local function IsDerivedUnit(unit)
    return unit == "targettarget" or unit == "focustarget"
end

local function ResolveExitTraceUnitBucket(unit)
    if unit == "target" or unit == "targettarget" or unit == "focus" or unit == "focustarget" or unit == "pet" then
        return unit
    end
    if IsBossUnit(unit) then
        return "boss1-boss5"
    end
    return tostring(unit or "unknown")
end

local function ResolveExitTraceResult(trace)
    if trace.existsAfterHandle == true then
        return "present-after-handle"
    end
    if trace.exitHideSkippedCombat == true then
        return "missing-hide-skipped-combat"
    end
    if trace.exitSetAlphaZero == true and trace.exitHideAttempted == true then
        return "missing-alpha-and-hide"
    end
    if trace.exitSetAlphaZero == true then
        return "missing-alpha-only"
    end
    return "missing-still-visible"
end

local function FormatTraceAlpha(value)
    if type(value) == "number" then
        return string.format("%.3f", value)
    end
    return "n/a"
end

local function AppendCounterLine(lines, label, bucket, order)
    local parts = {}
    local seen = {}
    for _, key in ipairs(order or {}) do
        seen[key] = true
        parts[#parts + 1] = string.format("%s=%d", key, tonumber(bucket and bucket[key]) or 0)
    end
    local extraKeys = {}
    if type(bucket) == "table" then
        for key in pairs(bucket) do
            if not seen[key] then
                extraKeys[#extraKeys + 1] = key
            end
        end
    end
    table.sort(extraKeys)
    for _, key in ipairs(extraKeys) do
        parts[#parts + 1] = string.format("%s=%d", tostring(key), tonumber(bucket[key]) or 0)
    end
    lines[#lines + 1] = string.format("%s: %s", label, (#parts > 0 and table.concat(parts, " ") or "-"))
end

local function RecordExitTestModeTrace(trace)
    if not Demo.IsDebugEnabled() or type(trace) ~= "table" then
        return
    end

    local state = EnsureExitTraceDebug()
    local result = ResolveExitTraceResult(trace)
    trace.result = result
    state.comparisons = (tonumber(state.comparisons) or 0) + 1
    IncrementCounter(state.byResult, result)
    IncrementCounter(state.byUnit, ResolveExitTraceUnitBucket(trace.unit))
    IncrementCounter(state.byReason, trace.reason)
    IncrementCounter(state.handleMissingResult, tostring(trace.handleMissingResult == true))

    if trace.wasTarget == true then
        IncrementCounter(state.byCleanup, "target-exit-cleanup")
    end
    if trace.wasBoss == true then
        IncrementCounter(state.byCleanup, "boss-exit-cleanup")
    end
    if trace.wasDerived == true then
        IncrementCounter(state.byCleanup, "derived-exit-cleanup")
    end
    if trace.wasPet == true then
        IncrementCounter(state.byCleanup, "pet-exit-cleanup")
    end
    if trace.exitSetAlphaZero == true then
        state.additionalAlphaZeroWrites = (tonumber(state.additionalAlphaZeroWrites) or 0) + 1
    end
    if trace.exitHideAttempted == true then
        state.additionalHideAttempts = (tonumber(state.additionalHideAttempts) or 0) + 1
    end
    if trace.exitHideSkippedCombat == true then
        state.hideSkippedByCombat = (tonumber(state.hideSkippedByCombat) or 0) + 1
    end
    if trace.existsAfterHandle ~= true and trace.shownAfterExit == true then
        state.stillVisibleMissingAfterExit = (tonumber(state.stillVisibleMissingAfterExit) or 0) + 1
    end

    local detail = string.format(
        "detail unit=%s reason=%s result=%s handleMissingResult=%s existsAfterHandle=%s shownAfterHandle=%s exitSetAlphaZero=%s exitHideAttempted=%s exitHideSkippedCombat=%s shownAfterExit=%s protectedRoot=%s inCombat=%s wasTarget=%s wasBoss=%s wasDerived=%s wasPet=%s alphaBeforeExitFallback=%s alphaAfterExitFallback=%s",
        tostring(trace.unit or "?"),
        tostring(trace.reason or "unknown"),
        tostring(result),
        tostring(trace.handleMissingResult == true),
        tostring(trace.existsAfterHandle == true),
        tostring(trace.shownAfterHandle == true),
        tostring(trace.exitSetAlphaZero == true),
        tostring(trace.exitHideAttempted == true),
        tostring(trace.exitHideSkippedCombat == true),
        tostring(trace.shownAfterExit == true),
        tostring(trace.protectedRoot == true),
        tostring(trace.inCombat == true),
        tostring(trace.wasTarget == true),
        tostring(trace.wasBoss == true),
        tostring(trace.wasDerived == true),
        tostring(trace.wasPet == true),
        FormatTraceAlpha(trace.alphaBeforeExitFallback),
        FormatTraceAlpha(trace.alphaAfterExitFallback)
    )
    state.recent[#state.recent + 1] = detail
    while #state.recent > EXIT_TRACE_DETAIL_LIMIT do
        table.remove(state.recent, 1)
    end
end

function Demo.TouchDebug(frame, key)
    if not Demo.IsDebugEnabled() then
        return
    end
    local debugState = EnsureDemoDebug(frame)
    if not debugState or type(key) ~= "string" then
        return
    end
    debugState[key] = (tonumber(debugState[key]) or 0) + 1
end

function Demo.SetDebugValue(frame, key, value)
    if not Demo.IsDebugEnabled() then
        return
    end
    local debugState = EnsureDemoDebug(frame)
    if not debugState or type(key) ~= "string" then
        return
    end
    debugState[key] = value
end

function Demo.ResetDebug(frame)
    if not frame then
        return
    end
    frame.FocalPointDemoDebug = nil
    EnsureDemoDebug(frame)
end

function Demo.ResetAllDebug()
    local frames = FocalPoint and FocalPoint.frames or nil
    if type(frames) ~= "table" then
        ResetExitTraceDebug()
        return 0
    end
    local count = 0
    for _, frame in pairs(frames) do
        if frame then
            Demo.ResetDebug(frame)
            count = count + 1
        end
    end
    ResetExitTraceDebug()
    return count
end

function Demo.BuildExitTestModeTraceReport()
    local state = EnsureExitTraceDebug()
    local lines = {}
    lines[#lines + 1] = "ExitTestMode trace"
    lines[#lines + 1] = string.format("Comparisons: %d", tonumber(state.comparisons) or 0)
    AppendCounterLine(lines, "By result", state.byResult, EXIT_TRACE_RESULT_ORDER)
    AppendCounterLine(lines, "By unit", state.byUnit, EXIT_TRACE_UNIT_ORDER)
    AppendCounterLine(lines, "By reason", state.byReason, nil)
    AppendCounterLine(lines, "HandleMissingResult", state.handleMissingResult, { "true", "false" })
    AppendCounterLine(lines, "Unit cleanup buckets", state.byCleanup, EXIT_TRACE_CLEANUP_ORDER)
    lines[#lines + 1] = string.format("Additional alpha zero writes: %d", tonumber(state.additionalAlphaZeroWrites) or 0)
    lines[#lines + 1] = string.format("Additional hide attempts: %d", tonumber(state.additionalHideAttempts) or 0)
    lines[#lines + 1] = string.format("Hide skipped by combat: %d", tonumber(state.hideSkippedByCombat) or 0)
    lines[#lines + 1] = string.format("Still visible missing after exit: %d", tonumber(state.stillVisibleMissingAfterExit) or 0)
    lines[#lines + 1] = string.format("Detail cases: %d/%d", #(state.recent or {}), EXIT_TRACE_DETAIL_LIMIT)

    for _, detail in ipairs(state.recent or {}) do
        lines[#lines + 1] = detail
    end

    return lines
end

function Demo.ReportDebug(frame)
    if not (FocalPoint and FocalPoint.debugDemoRuntime == true) then
        return
    end
    local d = EnsureDemoDebug(frame)
    if not d then
        return
    end
    local now = GetTime and GetTime() or 0
    if (now - (tonumber(d.lastReport) or 0)) < 5 then
        return
    end
    d.lastReport = now

    local mode = d.modeCommittedThisApply or d.lastMode or "unknown"
    local flags = {}
    if d.modeChanges >= 5 then
        flags[#flags + 1] = "mode-flap?"
    end
    if d.applyConfig > 0 and d.refreshApply > 0 and d.applyConfig >= (d.refreshApply * 0.8) then
        flags[#flags + 1] = "config-spam?"
    end
    if d.castStartPreview >= 3 or d.castStop > 0 then
        flags[#flags + 1] = "cast-reset?"
    end
    if d.auraClear > 0 and d.auraRender > 0 then
        flags[#flags + 1] = "aura-clear-after-render?"
    end
    if d.cleanupExecuted > 0 and mode ~= "live" then
        flags[#flags + 1] = "cleanup-while-demo?"
    end

    local resolveBy = string.format(
        "refresh:%d,snapshot:%d,runtime:%d,cleanup:%d,aura:%d,cast:%d,text:%d,visibility:%d,other:%d",
        d.resolveFromRefresh or 0,
        d.resolveFromSnapshot or 0,
        d.resolveFromRuntime or 0,
        d.resolveFromCleanup or 0,
        d.resolveFromAura or 0,
        d.resolveFromCast or 0,
        d.resolveFromText or 0,
        d.resolveFromVisibility or 0,
        d.resolveFromOther or 0
    )

    local message = string.format(
        "[FP DemoDebug] unit=%s mode=%s modeReason=%s configReason=%s castStartReason=%s cleanupReason=%s testModeExitCount=%d testModeExitReason=%s visibilityResyncCount=%d framesHiddenOnExit=%d framesStillVisibleMissingUnit=%d exitCleanup=%d hiddenOnExit=%s missingUnitAfterExit=%s flagsRaw=test=%s unlocked=%s active=%s resolved=%s committed=%s resolveCalls=%d resolveBy=%s commitCalls=%d refresh=%d snapshot=%d runtime=%d config=%d castStart=%d castStop=%d auraRefresh=%d auraRender=%d auraClear=%d cleanupAttempt=%d cleanupBlocked=%d cleanupExecuted=%d castbarOnUpdateTicks=%d castbarValueUpdates=%d castbarPreviewValueUpdates=%d castbarPreviewElapsed=%.3f castbarPreviewDuration=%.3f castbarPreviewUpdateMode=%s auraCooldownUpdates=%d auraTimerTextUpdates=%d barSmoothingTicks=%d rangeFadeTicks=%d modeChanges=%d modeTransitions=%s flags=%s",
        tostring(frame and frame.unit or "?"),
        tostring(mode),
        tostring(d.modeReason or "unknown"),
        tostring(d.configReason or "unknown"),
        tostring(d.castStartReason or "unknown"),
        tostring(d.cleanupReason or "unknown"),
        d.testModeExitCount or 0,
        tostring(d.testModeExitReason or "unknown"),
        d.visibilityResyncCount or 0,
        d.framesHiddenOnExit or 0,
        d.framesStillVisibleMissingUnit or 0,
        d.exitCleanup or 0,
        tostring(d.hiddenOnExit == true),
        tostring(d.missingUnitAfterExit == true),
        tostring(FocalPoint and FocalPoint.guiTestModeEnabled == true),
        tostring(FocalPoint and FocalPoint.framesUnlocked == true),
        tostring(Demo.IsDemoActive and Demo.IsDemoActive() or false),
        tostring(d.modeResolvedThisApply or "unknown"),
        tostring(d.modeCommittedThisApply or "unknown"),
        d.resolveCalls or 0,
        tostring(resolveBy),
        d.commitCalls or 0,
        d.refreshApply or 0,
        d.snapshotApply or 0,
        d.runtimeApply or 0,
        d.applyConfig or 0,
        d.castStartPreview or 0,
        d.castStop or 0,
        d.auraRefresh or 0,
        d.auraRender or 0,
        d.auraClear or 0,
        d.cleanupAttempt or 0,
        d.cleanupBlocked or 0,
        d.cleanupExecuted or 0,
        d.castbarOnUpdateTicks or 0,
        d.castbarValueUpdates or 0,
        d.castbarPreviewValueUpdates or 0,
        tonumber(d.castbarPreviewElapsed) or 0,
        tonumber(d.castbarPreviewDuration) or 0,
        tostring(d.castbarPreviewUpdateMode or "unknown"),
        d.auraCooldownUpdates or 0,
        d.auraTimerTextUpdates or 0,
        d.barSmoothingTicks or 0,
        d.rangeFadeTicks or 0,
        d.modeChanges or 0,
        tostring(d.modeTransitions or "-"),
        (#flags > 0 and table.concat(flags, ",") or "-")
    )

    if FocalPoint.Debug then
        FocalPoint:Debug(message)
    else
        print(message)
    end
end

local TEST_PREVIEW_VALUES = {
    player = {
        healthCurrent = 146000,
        healthMax = 146000,
        absorbTotal = 26000,
        healAbsorbTotal = 18000,
        powerCurrent = 84,
        powerMax = 100,
        altPowerCurrent = 72,
        altPowerMax = 100,
        name = "Preview Player",
        fullName = "Preview Player the Example",
        level = 84,
        classToken = "WARRIOR",
        role = "DAMAGER",
        race = "Human",
        castName = "Shield Slam",
        castDuration = 2.5,
    },
    target = {
        healthCurrent = 108000,
        healthMax = 146000,
        absorbTotal = 19000,
        healAbsorbTotal = 15000,
        powerCurrent = 42,
        powerMax = 100,
        altPowerCurrent = 0,
        altPowerMax = 0,
        name = "Training Target",
        level = 83,
        classToken = "PALADIN",
        role = "TANK",
        creature = "Humanoid",
        castName = "Frostbolt",
        castDuration = 2.5,
    },
    focus = {
        healthCurrent = 92000,
        healthMax = 120000,
        absorbTotal = 12000,
        healAbsorbTotal = 14000,
        powerCurrent = 55,
        powerMax = 100,
        altPowerCurrent = 0,
        altPowerMax = 0,
        name = "Focus Target",
        level = 83,
        classToken = "PRIEST",
        role = "HEALER",
        creature = "Humanoid",
        castName = "Heal",
        castDuration = 2.5,
    },
    pet = {
        healthCurrent = 72000,
        healthMax = 90000,
        absorbTotal = 8000,
        healAbsorbTotal = 9000,
        powerCurrent = 70,
        powerMax = 100,
        altPowerCurrent = 0,
        altPowerMax = 0,
        name = "Companion",
        level = 83,
        role = "DAMAGER",
        creature = "Beast",
    },
    boss1 = {
        healthCurrent = 125000,
        healthMax = 160000,
        absorbTotal = 18000,
        healAbsorbTotal = 22000,
        powerCurrent = 45,
        powerMax = 100,
        altPowerCurrent = 0,
        altPowerMax = 0,
        name = "Boss One",
        level = -1,
        creature = "Boss",
        castName = "Crushing Strike",
        castDuration = 2.5,
    },
    boss2 = {
        healthCurrent = 98000,
        healthMax = 160000,
        absorbTotal = 10000,
        healAbsorbTotal = 18000,
        powerCurrent = 62,
        powerMax = 100,
        altPowerCurrent = 0,
        altPowerMax = 0,
        name = "Boss Two",
        level = -1,
        creature = "Boss",
        castName = "Void Nova",
        castDuration = 2.1,
    },
    boss3 = {
        healthCurrent = 76000,
        healthMax = 160000,
        absorbTotal = 6000,
        healAbsorbTotal = 16000,
        powerCurrent = 28,
        powerMax = 100,
        altPowerCurrent = 0,
        altPowerMax = 0,
        name = "Boss Three",
        level = -1,
        creature = "Boss",
        castName = "Soul Drain",
        castDuration = 1.7,
    },
    boss4 = {
        healthCurrent = 141000,
        healthMax = 160000,
        absorbTotal = 22000,
        healAbsorbTotal = 24000,
        powerCurrent = 84,
        powerMax = 100,
        altPowerCurrent = 0,
        altPowerMax = 0,
        name = "Boss Four",
        level = -1,
        creature = "Boss",
        castName = "Shadow Lance",
        castDuration = 2.8,
    },
    boss5 = {
        healthCurrent = 112000,
        healthMax = 160000,
        absorbTotal = 14000,
        healAbsorbTotal = 20000,
        powerCurrent = 51,
        powerMax = 100,
        altPowerCurrent = 0,
        altPowerMax = 0,
        name = "Boss Five",
        level = -1,
        creature = "Boss",
        castName = "Chain Lightning",
        castDuration = 2.2,
    },
}

local TEST_PREVIEW_NAME_OVERRIDES = {
    targettarget = "Target of Target",
    focustarget = "Focus Target's Target",
    pettarget = "Companion's Target",
}

local PREVIEW_CLASSIFICATION_BY_UNIT = {
    target = "rareelite",
    targettarget = "elite",
    focus = "rare",
    focustarget = "elite",
    boss = "worldboss",
    boss1 = "worldboss",
    boss2 = "worldboss",
    boss3 = "worldboss",
    boss4 = "worldboss",
    boss5 = "worldboss",
}

local PLACEHOLDER_PREVIEW_VALUES = {
    player = { healthCurrent = 100, healthMax = 100, powerCurrent = 0, powerMax = 100, name = "Player" },
    target = { healthCurrent = 100, healthMax = 100, powerCurrent = 0, powerMax = 100, name = "Target" },
    focus = { healthCurrent = 100, healthMax = 100, powerCurrent = 0, powerMax = 100, name = "Focus" },
    targettarget = { healthCurrent = 100, healthMax = 100, powerCurrent = 0, powerMax = 100, name = "Target of Target" },
    focustarget = { healthCurrent = 100, healthMax = 100, powerCurrent = 0, powerMax = 100, name = "Focus Target" },
    pet = { healthCurrent = 100, healthMax = 100, powerCurrent = 0, powerMax = 100, name = "Companion" },
    boss = { healthCurrent = 100, healthMax = 100, powerCurrent = 0, powerMax = 100, name = "Boss" },
    boss1 = { healthCurrent = 100, healthMax = 100, powerCurrent = 0, powerMax = 100, name = "Boss 1" },
    boss2 = { healthCurrent = 100, healthMax = 100, powerCurrent = 0, powerMax = 100, name = "Boss 2" },
    boss3 = { healthCurrent = 100, healthMax = 100, powerCurrent = 0, powerMax = 100, name = "Boss 3" },
    boss4 = { healthCurrent = 100, healthMax = 100, powerCurrent = 0, powerMax = 100, name = "Boss 4" },
    boss5 = { healthCurrent = 100, healthMax = 100, powerCurrent = 0, powerMax = 100, name = "Boss 5" },
}

local TEST_PREVIEW_AURAS = {
    detailed = {
        Buffs = {
            { spellId = 17, name = "Power Word: Shield", icon = "Interface\\Icons\\Spell_Holy_PowerWordShield", duration = 15, remaining = 11, count = 0, isMine = true, isPlayerCast = true },
            { spellId = 2825, name = "Bloodlust", icon = "Interface\\Icons\\Spell_Nature_BloodLust", duration = 40, remaining = 26, count = 0, isMine = false, isPlayerCast = false },
            { spellId = 6673, name = "Battle Shout", icon = "Interface\\Icons\\Ability_Warrior_BattleShout", duration = 300, remaining = 180, count = 0, isMine = true, isPlayerCast = true },
            { spellId = 31884, name = "Avenging Wrath", icon = "Interface\\Icons\\Spell_Holy_AvengineWrath", duration = 20, remaining = 9, count = 0, isMine = true, isPlayerCast = true },
            { spellId = 29166, name = "Innervate", icon = "Interface\\Icons\\Spell_Nature_Lightning", duration = 10, remaining = 7, count = 0, isMine = false, isPlayerCast = false },
            { spellId = 11426, name = "Ice Barrier", icon = "Interface\\Icons\\Spell_Ice_Lament", duration = 60, remaining = 32, count = 0, isMine = false, isPlayerCast = false, isStealable = true },
        },
        Debuffs = {
            { spellId = 589, name = "Shadow Word: Pain", icon = "Interface\\Icons\\Spell_Shadow_ShadowWordPain", duration = 16, remaining = 14, count = 0, isMine = true, isPlayerCast = true, dispelName = "Magic" },
            { spellId = 34914, name = "Vampiric Touch", icon = "Interface\\Icons\\Spell_Holy_Stoicism", duration = 21, remaining = 18, count = 0, isMine = true, isPlayerCast = true, dispelName = "Magic" },
            { spellId = 25771, name = "Forbearance", icon = "Interface\\Icons\\Spell_Holy_RemoveCurse", duration = 30, remaining = 20, count = 0, isMine = false, isPlayerCast = false },
            { spellId = 116, name = "Frostbolt", icon = "Interface\\Icons\\Spell_Frost_FrostBolt02", duration = 8, remaining = 5, count = 0, isMine = false, isPlayerCast = false, dispelName = "Magic" },
            { spellId = 20066, name = "Repentance", icon = "Interface\\Icons\\Spell_Holy_PrayerOfHealing", duration = 12, remaining = 6, count = 0, isMine = true, isPlayerCast = true },
            { spellId = 204242, name = "Consecration Burn", icon = "Interface\\Icons\\Ability_Paladin_Consecration", duration = 9, remaining = 4, count = 2, isMine = true, isPlayerCast = true, isBossAura = true },
        },
    },
    placeholder = {
        Buffs = {
            { spellId = 17, name = "Power Word: Shield", icon = "Interface\\Icons\\Spell_Holy_PowerWordShield", duration = 15, remaining = 10, count = 0, isMine = true, isPlayerCast = true },
            { spellId = 2825, name = "Bloodlust", icon = "Interface\\Icons\\Spell_Nature_BloodLust", duration = 40, remaining = 24, count = 0, isMine = false, isPlayerCast = false },
            { spellId = 11426, name = "Ice Barrier", icon = "Interface\\Icons\\Spell_Ice_Lament", duration = 60, remaining = 28, count = 0, isMine = false, isPlayerCast = false, isStealable = true },
        },
        Debuffs = {
            { spellId = 589, name = "Shadow Word: Pain", icon = "Interface\\Icons\\Spell_Shadow_ShadowWordPain", duration = 16, remaining = 12, count = 0, isMine = true, isPlayerCast = true, dispelName = "Magic" },
            { spellId = 116, name = "Frostbolt", icon = "Interface\\Icons\\Spell_Frost_FrostBolt02", duration = 8, remaining = 5, count = 0, isMine = false, isPlayerCast = false, dispelName = "Magic" },
            { spellId = 204242, name = "Consecration Burn", icon = "Interface\\Icons\\Ability_Paladin_Consecration", duration = 9, remaining = 4, count = 2, isMine = true, isPlayerCast = true, isBossAura = true },
        },
    },
}

local PREVIEW_RAID_TARGETS = {
    player = 1, target = 8, focus = 3, pet = 2, targettarget = 7, focustarget = 4,
    boss = 6, boss1 = 1, boss2 = 2, boss3 = 3, boss4 = 4, boss5 = 5,
}

local function GetRuntimeState(frame)
    if not frame then
        return nil
    end
    frame.FocalPointDemoRuntime = frame.FocalPointDemoRuntime or {
        mode = nil,
        castbarStarted = false,
        castbarConfigSignature = nil,
        auras = {},
        lastRuntimeApply = 0,
        configApplied = false,
    }
    return frame.FocalPointDemoRuntime
end

local function ResetRuntimeState(frame)
    local state = GetRuntimeState(frame)
    if not state then
        return
    end
    state.mode = nil
    state.castbarStarted = false
    state.castbarConfigSignature = nil
    state.auras = {}
    state.lastRuntimeApply = 0
    state.configApplied = false
    state.lastConfigSignature = nil
    state.lastConfigMode = nil
    state.firstLiveObservedAt = nil
end

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

function Demo.IsFrameUnitEnabled(frame)
    local unit = frame and frame.unit
    if type(unit) ~= "string" or unit == "" then
        return false
    end

    local units = Utils.GetUnitsDB and Utils.GetUnitsDB() or nil
    if type(units) ~= "table" then
        return true
    end

    local configKey = Utils.NormalizeConfigUnitKey and Utils.NormalizeConfigUnitKey(unit) or unit
    local config = units[configKey]
    if type(config) ~= "table" then
        return true
    end

    return config.enabled ~= false
end

function Demo.ShouldProcessFrame(frame)
    if not frame or not frame.unit then
        return false
    end
    local onlyUnit = FocalPoint and FocalPoint.debugDemoOnlyUnit or nil
    if type(onlyUnit) == "string" and onlyUnit ~= "" then
        return frame.unit == onlyUnit
    end
    return true
end

function Demo.IsCastbarDisabled()
    return FocalPoint and FocalPoint.debugDemoDisableCastbar == true
end

function Demo.IsAurasDisabled()
    return FocalPoint and FocalPoint.debugDemoDisableAuras == true
end

function Demo.IsAuraTimersDisabled()
    return FocalPoint and FocalPoint.debugDemoDisableAuraTimers == true
end

function Demo.IsTextsDisabled()
    return FocalPoint and FocalPoint.debugDemoDisableTexts == true
end

function Demo.IsRangeFadeDisabled()
    return FocalPoint and FocalPoint.debugDemoDisableRangeFade == true
end

function Demo.IsBarSmoothingDisabled()
    return FocalPoint and FocalPoint.debugDemoDisableBarSmoothing == true
end

function Demo.GetMode(frame, caller)
    local mode = Demo.ResolveMode(frame, caller)
    return mode
end

function Demo.GetCommittedMode(frame)
    local state = GetRuntimeState(frame)
    local mode = state and state.mode or nil
    if mode == "detailed" or mode == "placeholder" or mode == "live" then
        return mode
    end
    return "live"
end

function Demo.IsFrameInDemoMode(frame)
    local mode = Demo.GetCommittedMode(frame)
    return mode ~= "live"
end

local function TouchResolveCaller(debugState, caller)
    if not debugState then
        return
    end
    local key = "resolveFromOther"
    if caller == "refresh" then
        key = "resolveFromRefresh"
    elseif caller == "snapshot" then
        key = "resolveFromSnapshot"
    elseif caller == "runtime" then
        key = "resolveFromRuntime"
    elseif caller == "cleanup" then
        key = "resolveFromCleanup"
    elseif caller == "visibility" then
        key = "resolveFromVisibility"
    elseif caller == "text" then
        key = "resolveFromText"
    elseif caller == "aura" then
        key = "resolveFromAura"
    elseif caller == "cast" then
        key = "resolveFromCast"
    end
    debugState[key] = (tonumber(debugState[key]) or 0) + 1
end

function Demo.ResolveMode(frame, caller)
    local d = Demo.IsDebugEnabled() and EnsureDemoDebug(frame) or nil
    if d then
        d.resolveCalls = (d.resolveCalls or 0) + 1
        TouchResolveCaller(d, caller)
    end

    local hasFrame = frame and frame.unit
    if FocalPoint.guiTestModeEnabled == true then
        if hasFrame then
            if not Demo.IsFrameUnitEnabled(frame) then
                return "disabled", "demo-disabled-unit"
            end
            return "detailed", "global-demo-detailed"
        end
        return "live", "live-invalid-frame"
    end

    if FocalPoint.framesUnlocked == true then
        if not hasFrame then
            return "live", "live-invalid-frame"
        end
        if not Demo.IsFrameUnitEnabled(frame) then
            return "placeholder", "unlock-disabled-placeholder"
        end
        if IsSelectedEditorFrame(frame) then
            return "detailed", "unlock-selected-detailed"
        end
        return "placeholder", "unlock-placeholder"
    end

    if not hasFrame then
        return "live", "live-invalid-frame"
    end
    return "live", "live-no-demo"
end

function Demo.CommitMode(frame, mode, reason)
    local d = EnsureDemoDebug(frame)
    if not d then
        return
    end
    d.commitCalls = (d.commitCalls or 0) + 1
    d.modeResolvedThisApply = tostring(mode or "unknown")
    d.modeCommittedThisApply = tostring(mode or "unknown")
    d.modeReason = tostring(reason or "unknown")
    if d.lastMode ~= nil and d.lastMode ~= mode then
        d.modeChanges = (d.modeChanges or 0) + 1
        local transition = tostring(d.lastMode or "?") .. ">" .. tostring(mode)
        if type(d.modeTransitions) ~= "string" or d.modeTransitions == "" then
            d.modeTransitions = transition
        else
            local parts = { strsplit("|", d.modeTransitions) }
            if #parts >= 8 then
                table.remove(parts, 1)
            end
            parts[#parts + 1] = transition
            d.modeTransitions = table.concat(parts, "|")
        end
    end
    d.lastMode = mode
end

function Demo.IsDemoActive()
    return FocalPoint.guiTestModeEnabled or FocalPoint.framesUnlocked
end

function Demo.IsDetailed(frame)
    return Demo.GetCommittedMode(frame) == "detailed"
end

function Demo.IsPlaceholder(frame)
    return Demo.GetCommittedMode(frame) == "placeholder"
end

function Demo.ShouldForceFrameVisible(frame)
    if not frame or not frame.unit then
        return false
    end

    if not Demo.IsFrameUnitEnabled(frame) then
        if FocalPoint.framesUnlocked == true and FocalPoint.guiTestModeEnabled ~= true then
            return true
        end
        return false
    end

    return Demo.IsFrameInDemoMode(frame)
end

function Demo.GetDetailedValuesForUnit(unit)
    local values = TEST_PREVIEW_VALUES[unit]
    if values then
        return values
    end

    local nameOverride = TEST_PREVIEW_NAME_OVERRIDES[unit]
    local fallbackValues = TEST_PREVIEW_VALUES.target or TEST_PREVIEW_VALUES.player
    if nameOverride and fallbackValues then
        local result = {}
        for key, value in pairs(fallbackValues) do
            result[key] = value
        end
        result.name = nameOverride
        return result
    end

    return fallbackValues
end

function Demo.GetUnitValues(frame, mode)
    if not frame or not frame.unit then
        return nil
    end

    mode = mode or Demo.GetCommittedMode(frame)
    if mode == "disabled" or not Demo.IsFrameUnitEnabled(frame) then
        return nil
    end
    if mode == "detailed" then
        return Demo.GetDetailedValuesForUnit(frame.unit)
    end
    if mode == "placeholder" then
        return PLACEHOLDER_PREVIEW_VALUES[frame.unit]
            or PLACEHOLDER_PREVIEW_VALUES.boss
            or PLACEHOLDER_PREVIEW_VALUES.target
            or PLACEHOLDER_PREVIEW_VALUES.player
    end
    return nil
end

function Demo.GetPreviewClassificationKind(frame, mode)
    if not frame or not frame.unit then
        return nil
    end

    mode = mode or Demo.GetCommittedMode(frame)
    if mode == "live" or mode == "disabled" or not Demo.IsFrameUnitEnabled(frame) then
        return nil
    end

    return PREVIEW_CLASSIFICATION_BY_UNIT[frame.unit]
end

function Demo.ShouldBypassDecorationConditions(frame, mode)
    if not frame or not frame.unit then
        return false
    end

    mode = mode or Demo.ResolveMode(frame, "decoration")
    if mode ~= "detailed" and mode ~= "placeholder" then
        return false
    end

    -- Unlock is an editor layout mode: show every enabled decoration so users can
    -- position and compare condition variants side by side.
    return FocalPoint.framesUnlocked == true and FocalPoint.guiTestModeEnabled ~= true
end

local function BuildPreviewAura(definition, frame, groupKey, index)
    if type(definition) ~= "table" or not frame or not groupKey then
        return nil
    end
    local duration = tonumber(definition.duration) or 0
    local remaining = tonumber(definition.remaining)
    if remaining == nil then remaining = duration end
    remaining = math.max(remaining or 0, 0)

    local durationState = duration > 0 and "TIMED" or "PERMANENT"
    local expirationTime = duration > 0 and remaining or 0
    local isHelpful = groupKey == "Buffs"
    local isHarmful = groupKey == "Debuffs"
    local count = tonumber(definition.count) or 0
    local spellId = tonumber(definition.spellId) or (100000 + index)
    local unitSeed = string.len(tostring(frame.unit or "")) * 1000

    return {
        spellId = spellId, auraInstanceId = unitSeed + ((isHelpful and 10000) or 20000) + index,
        name = definition.name or "", icon = definition.icon, isHelpful = isHelpful, isHarmful = isHarmful,
        count = count, duration = duration, expirationTime = expirationTime, remaining = remaining,
        durationObject = nil, durationSource = "PREVIEW", durationState = durationState,
        timerState = duration > 0 and "READY" or "NONE", durationObjectPresent = false,
        timerReadable = duration > 0, sourceUnit = definition.sourceUnit or "player", sourceGUID = nil,
        isPlayerCast = definition.isPlayerCast ~= false, isMine = definition.isMine ~= false,
        isBossAura = definition.isBossAura == true, isStealable = definition.isStealable == true,
        dispelName = definition.dispelName, canApplyAura = definition.canApplyAura == true,
        durationKnown = true, hasDuration = duration > 0, hasStacks = count > 1, sourceIndex = index, sortKey = index,
    }
end

function Demo.GetAuras(frame, groupKey)
    if not frame or not frame.unit or (groupKey ~= "Buffs" and groupKey ~= "Debuffs") then
        return nil
    end
    if Demo.IsAurasDisabled() then
        return {}
    end
    if not Demo.ShouldProcessFrame(frame) then
        return {}
    end

    local mode = Demo.GetCommittedMode(frame)
    if mode == "placeholder" then
        -- Unlock-placeholder frames keep placeholder bars/text but should not
        -- render synthetic demo auras; only the selected detailed frame gets them.
        return {}
    end

    local previewSet = mode == "detailed" and TEST_PREVIEW_AURAS.detailed
        or nil
    if not previewSet then
        return nil
    end

    local definitions = previewSet[groupKey]
    if type(definitions) ~= "table" then
        return {}
    end

    local state = GetRuntimeState(frame)
    state.auras = state.auras or {}
    local signature = tostring(frame.unit or "") .. ":" .. tostring(mode) .. ":" .. tostring(groupKey) .. ":" .. tostring(#definitions)
    local cached = state.auras[groupKey]
    if not cached or cached.signature ~= signature then
        local now = (GetTime and GetTime()) or 0
        local built = {}
        for index, definition in ipairs(definitions) do
            local aura = BuildPreviewAura(definition, frame, groupKey, index)
            if aura then
                if (tonumber(aura.duration) or 0) > 0 then
                    aura.expirationTime = now + math.max(tonumber(definition.remaining) or tonumber(definition.duration) or 0, 0)
                end
                built[#built + 1] = aura
            end
        end
        cached = { signature = signature, data = built }
        state.auras[groupKey] = cached
    end

    local now = (GetTime and GetTime()) or 0
    for _, aura in ipairs(cached.data or {}) do
        if aura.durationState == "TIMED" and (tonumber(aura.duration) or 0) > 0 then
            aura.remaining = math.max((tonumber(aura.expirationTime) or 0) - now, 0)
        end
    end
    return cached.data or {}
end

function Demo.GetIndicatorState(frame, indicatorKey)
    if not frame or not frame.unit or not indicatorKey then
        return false
    end
    return Demo.IsDetailed(frame)
end

function Demo.GetRaidTargetIndex(frame)
    return PREVIEW_RAID_TARGETS[frame and frame.unit or ""] or 1
end

local function PrepareSnapshotText(value)
    if FormatDisplayNumber then
        local ok, result = pcall(FormatDisplayNumber, value)
        if ok and type(result) == "string" then
            return result
        end
    end

    local ok, result = pcall(tostring, value or 0)
    if ok and type(result) == "string" then
        return result
    end

    return "0"
end

local function FillSnapshotLiveValues(frame, values)
    frame.LiveValues = frame.LiveValues or {}
    local live = frame.LiveValues

    local healthCurrent = values.healthCurrent or 100
    local healthMax = values.healthMax or 100
    local powerCurrent = values.powerCurrent or 0
    local powerMax = values.powerMax or 100
    local altPowerCurrent = values.altPowerCurrent or 0
    local altPowerMax = values.altPowerMax or 0
    local absorbTotal = values.absorbTotal or values.absorb or 0
    local healAbsorbTotal = values.healAbsorbTotal or values.healAbsorb or 0

    local healthCurrentSafe = ToSafeNumberValue and ToSafeNumberValue(healthCurrent) or tonumber(healthCurrent) or 0
    local healthMaxSafe = ToSafeNumberValue and ToSafeNumberValue(healthMax) or tonumber(healthMax) or 0
    local powerCurrentSafe = ToSafeNumberValue and ToSafeNumberValue(powerCurrent) or tonumber(powerCurrent) or 0
    local powerMaxSafe = ToSafeNumberValue and ToSafeNumberValue(powerMax) or tonumber(powerMax) or 0
    local altPowerCurrentSafe = ToSafeNumberValue and ToSafeNumberValue(altPowerCurrent) or tonumber(altPowerCurrent) or 0
    local altPowerMaxSafe = ToSafeNumberValue and ToSafeNumberValue(altPowerMax) or tonumber(altPowerMax) or 0
    local absorbTotalSafe = ToSafeNumberValue and ToSafeNumberValue(absorbTotal) or tonumber(absorbTotal) or 0
    local healAbsorbTotalSafe = ToSafeNumberValue and ToSafeNumberValue(healAbsorbTotal) or tonumber(healAbsorbTotal) or 0

    live.healthCurrentRaw = healthCurrent
    live.healthMaxRaw = healthMax
    live.healthCurrentSafe = healthCurrentSafe
    live.healthMaxSafe = healthMaxSafe
    live.healthCurrentText = PrepareSnapshotText(healthCurrent)
    live.healthMaxText = PrepareSnapshotText(healthMax)
    live.healthCurrentAbbr = ResolveBlizzardAbbreviation and ResolveBlizzardAbbreviation(healthCurrent, live.healthCurrentText) or live.healthCurrentText
    live.healthMaxAbbr = ResolveBlizzardAbbreviation and ResolveBlizzardAbbreviation(healthMax, live.healthMaxText) or live.healthMaxText

    live.powerCurrentRaw = powerCurrent
    live.powerMaxRaw = powerMax
    live.powerCurrentSafe = powerCurrentSafe
    live.powerMaxSafe = powerMaxSafe
    live.powerCurrentText = PrepareSnapshotText(powerCurrent)
    live.powerMaxText = PrepareSnapshotText(powerMax)
    live.powerCurrentAbbr = ResolveBlizzardAbbreviation and ResolveBlizzardAbbreviation(powerCurrent, live.powerCurrentText) or live.powerCurrentText
    live.powerMaxAbbr = ResolveBlizzardAbbreviation and ResolveBlizzardAbbreviation(powerMax, live.powerMaxText) or live.powerMaxText

    live.altPowerCurrentRaw = altPowerCurrent
    live.altPowerMaxRaw = altPowerMax
    live.altPowerCurrentSafe = altPowerCurrentSafe
    live.altPowerMaxSafe = altPowerMaxSafe
    live.altPowerCurrentText = PrepareSnapshotText(altPowerCurrent)
    live.altPowerMaxText = PrepareSnapshotText(altPowerMax)
    live.altPowerCurrentAbbr = ResolveBlizzardAbbreviation and ResolveBlizzardAbbreviation(altPowerCurrent, live.altPowerCurrentText) or live.altPowerCurrentText
    live.altPowerMaxAbbr = ResolveBlizzardAbbreviation and ResolveBlizzardAbbreviation(altPowerMax, live.altPowerMaxText) or live.altPowerMaxText
    live.altPowerVisible = altPowerMaxSafe > 0

    live.absorbTotalRaw = absorbTotal
    live.absorbTotalSafe = absorbTotalSafe
    live.absorbTotalText = PrepareSnapshotText(absorbTotal)
    live.absorbTotalAbbr = ResolveBlizzardAbbreviation and ResolveBlizzardAbbreviation(absorbTotal, live.absorbTotalText) or live.absorbTotalText
    live.healAbsorbTotalRaw = healAbsorbTotal
    live.healAbsorbTotalSafe = healAbsorbTotalSafe
    live.healAbsorbTotalText = PrepareSnapshotText(healAbsorbTotal)
    live.healAbsorbTotalAbbr = ResolveBlizzardAbbreviation and ResolveBlizzardAbbreviation(healAbsorbTotal, live.healAbsorbTotalText) or live.healAbsorbTotalText
end

local function ApplyPreviewCastState(frame, mode)
    if not frame then
        return
    end

    local shouldRunPreviewCast = mode == "detailed"
    local castBar = frame.Elements and frame.Elements.CastBar
    local castRuntime = FocalPoint.UnitFrameCastBar or {}
    local showCastBarEnabled = not (frame and frame.config and frame.config.showCastBar == false)
    local state = GetRuntimeState(frame)
    local castSig = table.concat({
        tostring(showCastBarEnabled),
        tostring(frame and frame.config and frame.config.castBarHeight or ""),
        tostring(frame and frame.config and frame.config.castBarPoint or ""),
        tostring(frame and frame.config and frame.config.castBarRelativePoint or ""),
    }, "|")
    local modeChanged = state and state.mode ~= mode

    if Demo.IsCastbarDisabled() then
        if castRuntime.Stop then
            castRuntime.Stop(frame)
        end
        frame._fpPreviewCastState = "off"
        if state then
            state.castbarStarted = false
            state.castbarConfigSignature = nil
        end
        return
    end

    if shouldRunPreviewCast then
        frame._fpPreviewCastState = frame._fpPreviewCastState or "off"
        local previewRunning = castBar and castBar.isPreview and castBar.isCasting
        local needsRestart = modeChanged
            or (state and state.castbarConfigSignature ~= castSig)
            or (frame._fpPreviewCastState ~= "preview_running" and not (state and state.castbarStarted == true))
            or (not previewRunning and not (state and state.castbarStarted == true))
        if showCastBarEnabled and needsRestart then
            local d = EnsureDemoDebug(frame)
            if d then
                local reason = "unknown"
                if not state or state.castbarStarted ~= true then
                    reason = "first-start"
                elseif modeChanged then
                    reason = "mode-changed"
                elseif state.castbarConfigSignature ~= castSig then
                    reason = "config-signature-changed"
                elseif frame._fpPreviewCastState ~= "preview_running" then
                    reason = "no-preview-state"
                end
                d.castStartReason = reason
            end
            if castRuntime.StartPreview then
                Demo.TouchDebug(frame, "castStartPreview")
                castRuntime.StartPreview(frame)
            end
            frame._fpPreviewCastState = "preview_running"
            if state then
                state.castbarStarted = true
                state.castbarConfigSignature = castSig
            end
        end
    else
        if frame._fpPreviewCastState == "preview_running" then
            if castRuntime.Stop then
                Demo.TouchDebug(frame, "castStop")
                castRuntime.Stop(frame)
            end
            frame._fpPreviewCastState = "off"
        end
        if state then
            state.castbarStarted = false
            state.castbarConfigSignature = nil
        end
    end
end

function Demo.ApplyFrameSnapshot(owner, frame, refreshRequest, mode, modeReason)
    mode = mode or Demo.ResolveMode(frame, "snapshot")
    if mode == "disabled" then
        local state = GetRuntimeState(frame)
        if state then
            state.mode = "disabled"
            state.auras = {}
            state.castbarStarted = false
            state.castbarConfigSignature = nil
            state.firstLiveObservedAt = nil
        end
        frame.TestValues = nil
        local visibility = FocalPoint and FocalPoint.UnitFrameVisibility or nil
        if visibility and visibility.ClearFrameContentValuesOnly then
            visibility.ClearFrameContentValuesOnly(frame, modeReason or "demo-disabled-unit")
        end
        if frame.SetAlpha then
            local alphaDecision = Visibility.ResolveRootAlphaDecision
                and Visibility.ResolveRootAlphaDecision(frame, {
                    source = "demo-snapshot",
                    rangeMultiplier = 1,
                    missingUnitAlphaGuard = false,
                    visibilityOptions = {
                        mode = mode,
                        modeReason = modeReason,
                    },
                })
                or nil
            if FocalPoint.RootAlphaDebug
                and FocalPoint.RootAlphaDebug.enabled == true
                and FocalPoint.UnitFrame
                and FocalPoint.UnitFrame.RecordRootAlphaOverrideShadow
            then
                FocalPoint.UnitFrame.RecordRootAlphaOverrideShadow(frame, {
                    callsite = "demo-snapshot",
                    reason = "preview-disabled",
                    alpha = 0,
                    shouldForceZero = true,
                    mode = mode,
                    modeReason = modeReason,
                }, alphaDecision)
            end
            frame:SetAlpha(ResolveDecisionAlpha(alphaDecision, 0))
        end
        if frame.EnableMouse then
            frame:EnableMouse(false)
        end
        if frame.SetMouseClickEnabled then
            frame:SetMouseClickEnabled(false)
        end
        local protectedRoot = frame.IsProtected and frame:IsProtected()
        local inCombat = InCombatLockdown and InCombatLockdown()
        if frame.Hide and not (protectedRoot and inCombat) then
            frame:Hide()
        end
        return true
    end

    if mode == "live" and not Demo.IsDemoActive() then
        Demo.CleanupFrameRuntime(frame, "mode-live")
        return false
    end
    if mode == "live" then
        return false
    end
    if not Demo.ShouldProcessFrame(frame) then
        local visibility = FocalPoint and FocalPoint.UnitFrameVisibility or nil
        if visibility and visibility.ClearFrameVisualState then
            visibility.ClearFrameVisualState(frame, "demo-only-unit-filter")
        end
        if frame.Hide then
            frame:Hide()
        end
        return true
    end

    local state = GetRuntimeState(frame)
    if state and state.mode and state.mode ~= mode then
        state.auras = {}
        state.castbarStarted = false
        state.castbarConfigSignature = nil
    end
    if state then
        state.mode = mode
        state.firstLiveObservedAt = nil
    end

    local values = Demo.GetUnitValues(frame, mode) or {}
    -- Legacy compatibility path: downstream modules may still read frame.TestValues.
    -- Primary demo data source is Demo.GetUnitValues()/snapshot runtime state.
    frame.TestValues = values
    Demo.TouchDebug(frame, "snapshotApply")
    FillSnapshotLiveValues(frame, values)
    Demo.TouchDebug(frame, "barSmoothingTicks")

    if owner and owner.RefreshUnitBarValues then
        owner:RefreshUnitBarValues(frame)
    end

    return true
end

function Demo.ApplyRuntimePreview(owner, frame, refreshRequest, mode, modeReason)
    mode = mode or Demo.ResolveMode(frame, "runtime")
    if mode == "live" then
        return false
    end
    if not Demo.ShouldProcessFrame(frame) then
        return true
    end

    Demo.TouchDebug(frame, "runtimeApply")
    Demo.SetDebugValue(frame, "castbarPreviewUpdateMode", "preview-refresh")
    ApplyPreviewCastState(frame, mode)

    local auraRuntime = FocalPoint.AuraRuntime or {}
    local auraResult = nil
    if auraRuntime.RefreshAuras then
        auraResult = auraRuntime.RefreshAuras(frame, refreshRequest and refreshRequest.forceAuraFullScan == true)
    elseif owner and owner.RefreshAuras then
        auraResult = owner:RefreshAuras(frame, refreshRequest and refreshRequest.forceAuraFullScan == true)
    end
    if owner and owner.RefreshLiveValues then
        owner:RefreshLiveValues(frame)
    end
    if owner and owner.UpdateTextElements and not Demo.IsTextsDisabled() then
        owner:UpdateTextElements(frame)
    end

    local State = FocalPoint.UnitFrameState or {}
    if State.DebugLog then
        local buffs = Demo.GetAuras(frame, "Buffs") or {}
        local debuffs = Demo.GetAuras(frame, "Debuffs") or {}
        State.DebugLog(
            frame,
            "demo-runtime-preview",
            string.format(
                "mode=%s castPreview=%s showCast=%s buffs=%d debuffs=%d",
                tostring(mode),
                tostring(mode == "detailed"),
                tostring(not (frame and frame.config and frame.config.showCastBar == false)),
                #buffs,
                #debuffs
            )
        )
        if auraResult then
            State.DebugLog(
                frame,
                "demo-runtime-auras",
                string.format("rendered buffs=%d debuffs=%d", #(auraResult.Buffs or {}), #(auraResult.Debuffs or {}))
            )
        end
    end

    local runtimeState = GetRuntimeState(frame)
    if runtimeState then
        runtimeState.lastRuntimeApply = (GetTime and GetTime()) or 0
        runtimeState.mode = mode
    end

    return true
end

function Demo.ShouldApplyConfig(frame, refreshRequest, mode, modeReason)
    mode = mode or Demo.ResolveMode(frame, "runtime")
    if mode == "live" then
        return true
    end

    local state = GetRuntimeState(frame)
    if not state then
        return true
    end

    local config = frame and frame.config or nil
    local decorationSignatureParts = {}
    local decorations = config and config.decorations or nil
    if type(decorations) == "table" then
        for index, decoration in ipairs(decorations) do
            decorationSignatureParts[#decorationSignatureParts + 1] = table.concat({
                tostring(index),
                tostring(decoration.id or ""),
                tostring(decoration.enabled ~= false),
                tostring(decoration.texture or ""),
                tostring(decoration.target or ""),
                tostring(decoration.point or ""),
                tostring(decoration.relativePoint or ""),
                tostring(decoration.offsetX or ""),
                tostring(decoration.offsetY or ""),
                tostring(decoration.width or ""),
                tostring(decoration.height or ""),
                tostring(decoration.alpha or ""),
                tostring(decoration.condition or ""),
            }, ":")
        end
    end
    local signature = table.concat({
        tostring(mode),
        tostring(config and config.width or ""),
        tostring(config and config.height or ""),
        tostring(config and config.scale or ""),
        tostring(config and config.alpha or ""),
        tostring(config and config.showCastBar ~= false),
        tostring(config and config.castBarPoint or ""),
        tostring(config and config.castBarRelativePoint or ""),
        tostring(config and config.castBarOffsetX or ""),
        tostring(config and config.castBarOffsetY or ""),
        tostring(config and config.castBarHeight or ""),
        table.concat(decorationSignatureParts, ";"),
    }, "|")

    if state.configApplied ~= true then
        local d = EnsureDemoDebug(frame)
        if d then d.configReason = "first-apply" end
        state.configApplied = true
        state.mode = mode
        state.lastConfigMode = mode
        state.lastConfigSignature = signature
        return true
    end

    if state.lastConfigMode ~= mode then
        local d = EnsureDemoDebug(frame)
        if d then d.configReason = "mode-changed" end
        state.lastConfigMode = mode
        state.lastConfigSignature = signature
        state.mode = mode
        return true
    end

    if state.lastConfigSignature ~= signature then
        local d = EnsureDemoDebug(frame)
        if d then d.configReason = "config-signature-changed" end
        state.lastConfigSignature = signature
        return true
    end
    local d = EnsureDemoDebug(frame)
    if d then d.configReason = "unchanged" end

    return false
end

function Demo.CleanupFrameRuntime(frame, reason)
    if not frame then
        return
    end

    Demo.TouchDebug(frame, "cleanupAttempt")

    local rawTest = (FocalPoint and FocalPoint.guiTestModeEnabled == true)
    local rawUnlocked = (FocalPoint and FocalPoint.framesUnlocked == true)
    local rawActive = rawTest or rawUnlocked
    if rawActive then
        Demo.TouchDebug(frame, "cleanupBlocked")
        local d = EnsureDemoDebug(frame)
        if d then d.cleanupReason = "raw-active-hard-block-before-execute" end
        return false
    end

    local mode = Demo.ResolveMode(frame, "cleanup")
    if mode ~= "live" then
        Demo.TouchDebug(frame, "cleanupBlocked")
        local d = EnsureDemoDebug(frame)
        if d then d.cleanupReason = "mode-not-live-blocked" end
        return false
    end

    local state = GetRuntimeState(frame)
    local now = (GetTime and GetTime()) or 0
    state.firstLiveObservedAt = state.firstLiveObservedAt or now
    if (now - state.firstLiveObservedAt) < 0.20 then
        Demo.TouchDebug(frame, "cleanupBlocked")
        local d = EnsureDemoDebug(frame)
        if d then d.cleanupReason = "live-not-stable-blocked" end
        return false
    end

    Demo.TouchDebug(frame, "cleanup")
    local rawTestBeforeExecute = (FocalPoint and FocalPoint.guiTestModeEnabled == true)
    local rawUnlockedBeforeExecute = (FocalPoint and FocalPoint.framesUnlocked == true)
    local rawActiveBeforeExecute = rawTestBeforeExecute or rawUnlockedBeforeExecute
    if rawActiveBeforeExecute then
        Demo.TouchDebug(frame, "cleanupBlocked")
        local d = EnsureDemoDebug(frame)
        if d then d.cleanupReason = "raw-active-hard-block-before-execute" end
        return false
    end
    Demo.TouchDebug(frame, "cleanupExecuted")
    local debugState = EnsureDemoDebug(frame)
    if debugState then
        debugState.cleanupReason = reason or "mode-live"
    end
    local castRuntime = FocalPoint.UnitFrameCastBar or {}
    if frame._fpPreviewCastState == "preview_running" and castRuntime.Stop then
        Demo.TouchDebug(frame, "castStop")
        castRuntime.Stop(frame)
    end
    frame._fpPreviewCastState = "off"
    frame.TestValues = nil
    ResetRuntimeState(frame)
    return true
end

function Demo.ExitTestMode(reason)
    local frames = FocalPoint and FocalPoint.frames or nil
    if type(frames) ~= "table" then
        return 0, 0, 0
    end

    local visibility = FocalPoint and FocalPoint.UnitFrameVisibility or nil
    local refreshRuntime = FocalPoint and FocalPoint.UnitFrameRefresh or nil
    local unitFrameRuntime = FocalPoint and FocalPoint.UnitFrame or nil
    local castRuntime = FocalPoint and FocalPoint.UnitFrameCastBar or nil
    local hiddenCount = 0
    local stillVisibleMissingCount = 0
    local frameCount = 0
    local exitReason = tostring(reason or "unknown")
    local inCombat = InCombatLockdown and InCombatLockdown()

    for unit, frame in pairs(frames) do
        if frame then
            frameCount = frameCount + 1
            local d = EnsureDemoDebug(frame)
            if d then
                d.testModeExitCount = (tonumber(d.testModeExitCount) or 0) + 1
                d.testModeExitReason = exitReason
                d.visibilityResyncCount = (tonumber(d.visibilityResyncCount) or 0) + 1
                d.hiddenOnExit = false
                d.missingUnitAfterExit = false
            end

            local cleaned = Demo.CleanupFrameRuntime(frame, "testmode-disabled")
            if d and cleaned then
                d.exitCleanup = (tonumber(d.exitCleanup) or 0) + 1
            end

            local state = GetRuntimeState(frame)
            state.mode = "live"
            state.firstLiveObservedAt = nil

            if refreshRuntime and refreshRuntime.SyncLiveUnitWatchReentry then
                refreshRuntime.SyncLiveUnitWatchReentry(unitFrameRuntime, frame, exitReason)
            end

            if castRuntime and castRuntime.Stop then
                castRuntime.Stop(frame)
            end

            frame.TestValues = nil

            local handleMissingResult = false
            if visibility and visibility.HandleMissingUnit then
                handleMissingResult = visibility.HandleMissingUnit(frame) == true
            end

            local exists = (unit == "player") or (UnitExists and UnitExists(unit))
            local shown = frame.IsShown and frame:IsShown() or false
            local shownAfterHandle = shown
            local exitSetAlphaZero = false
            local exitHideAttempted = false
            local exitHideSkippedCombat = false
            local protectedRoot = frame.IsProtected and frame:IsProtected() or false
            local alphaBeforeExitFallback = frame.GetAlpha and frame:GetAlpha() or nil
            if (not exists) and unit ~= "player" then
                if frame.SetAlpha then
                    exitSetAlphaZero = true
                    frame:SetAlpha(0)
                end
                if frame.Hide and not inCombat then
                    exitHideAttempted = true
                    frame:Hide()
                elseif frame.Hide and inCombat then
                    exitHideSkippedCombat = true
                end
                shown = frame.IsShown and frame:IsShown() or false
                if d then
                    d.missingUnitAfterExit = true
                end
            end
            local alphaAfterExitFallback = frame.GetAlpha and frame:GetAlpha() or nil

            if d then
                d.hiddenOnExit = (not shown)
            end
            if (not shown) and unit ~= "player" then
                hiddenCount = hiddenCount + 1
            end
            if (not exists) and shown and unit ~= "player" then
                stillVisibleMissingCount = stillVisibleMissingCount + 1
            end
            RecordExitTestModeTrace({
                unit = unit,
                reason = exitReason,
                handleMissingResult = handleMissingResult,
                existsAfterHandle = exists == true,
                shownAfterHandle = shownAfterHandle == true,
                exitSetAlphaZero = exitSetAlphaZero,
                exitHideAttempted = exitHideAttempted,
                exitHideSkippedCombat = exitHideSkippedCombat,
                shownAfterExit = shown == true,
                protectedRoot = protectedRoot == true,
                inCombat = inCombat == true,
                wasTarget = unit == "target",
                wasBoss = IsBossUnit(unit),
                wasDerived = IsDerivedUnit(unit),
                wasPet = unit == "pet",
                alphaBeforeExitFallback = alphaBeforeExitFallback,
                alphaAfterExitFallback = alphaAfterExitFallback,
            })
        end
    end

    for _, frame in pairs(frames) do
        local d = EnsureDemoDebug(frame)
        if d then
            d.framesHiddenOnExit = hiddenCount
            d.framesStillVisibleMissingUnit = stillVisibleMissingCount
        end
    end

    if FocalPoint and FocalPoint.RefreshAllUnitFrames then
        C_Timer.After(0, function()
            if FocalPoint and FocalPoint.RefreshAllUnitFrames then
                FocalPoint:RefreshAllUnitFrames()
            end
        end)
    end

    if FocalPoint and FocalPoint.debugDemoRuntime == true then
        local message = string.format(
            "[FP DemoDebug] testModeExit reason=%s frames=%d hidden=%d stillVisibleMissing=%d",
            exitReason,
            frameCount,
            hiddenCount,
            stillVisibleMissingCount
        )
        if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
            DEFAULT_CHAT_FRAME:AddMessage(message)
        else
            print(message)
        end
    end

    return frameCount, hiddenCount, stillVisibleMissingCount
end
