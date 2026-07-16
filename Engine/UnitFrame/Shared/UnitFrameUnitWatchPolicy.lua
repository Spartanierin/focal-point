local _, FocalPoint = ...

FocalPoint.UnitFrameUnitWatchPolicy = FocalPoint.UnitFrameUnitWatchPolicy or {}
local Policy = FocalPoint.UnitFrameUnitWatchPolicy

local Demo = FocalPoint.UnitFrameDemoEnvironment or {}
local MAX_SYNC_DEBUG_MISMATCHES = 20

local function GetUnit(frameOrUnit, options)
    if type(options) == "table" and type(options.unit) == "string" and options.unit ~= "" then
        return options.unit
    end
    if type(frameOrUnit) == "string" then
        return frameOrUnit
    end
    if type(frameOrUnit) == "table" and type(frameOrUnit.unit) == "string" then
        return frameOrUnit.unit
    end
    return nil
end

local function IsProtectedRoot(frame, options)
    if type(options) == "table" and type(options.protectedRoot) == "boolean" then
        return options.protectedRoot
    end
    return frame
        and frame.IsProtected
        and frame:IsProtected()
        or false
end

local function IsInCombat(options)
    if type(options) == "table" and type(options.inCombat) == "boolean" then
        return options.inCombat
    end
    return InCombatLockdown and InCombatLockdown() or false
end

local function IsPreviewActive(options)
    if type(options) == "table" and type(options.previewActive) == "boolean" then
        return options.previewActive
    end
    return FocalPoint
        and (FocalPoint.guiTestModeEnabled == true or FocalPoint.framesUnlocked == true)
        or false
end

local function ResolveMode(frame, options, previewActive)
    if type(options) == "table" and type(options.mode) == "string" and options.mode ~= "" then
        return options.mode
    end
    if not previewActive then
        return "live"
    end
    if FocalPoint and FocalPoint.guiTestModeEnabled == true then
        if frame and Demo.IsFrameUnitEnabled and not Demo.IsFrameUnitEnabled(frame) then
            return "disabled"
        end
        return "detailed"
    end
    if FocalPoint and FocalPoint.framesUnlocked == true then
        return "placeholder"
    end
    return "preview"
end

local function IsBossUnit(unit)
    return type(unit) == "string" and unit:match("^boss%d+$") ~= nil
end

local function IsDerivedUnit(unit)
    return unit == "targettarget" or unit == "focustarget"
end

function Policy.Resolve(frameOrUnit, options)
    options = type(options) == "table" and options or {}

    local frame = type(frameOrUnit) == "table" and frameOrUnit or nil
    local unit = GetUnit(frameOrUnit, options)
    local protectedRoot = IsProtectedRoot(frame, options)
    local inCombat = IsInCombat(options)
    local protectedCombat = protectedRoot and inCombat
    local previewActive = IsPreviewActive(options)
    local forcePreviewVisible = Demo.ShouldForceFrameVisible and frame and Demo.ShouldForceFrameVisible(frame) or false
    local mode = ResolveMode(frame, options, previewActive)
    local previewOutsideCombat = type(options.previewOutsideCombat) == "boolean"
        and options.previewOutsideCombat
        or (previewActive and not inCombat)

    local result = {
        shouldUse = false,
        reason = "invalid-unit",

        unit = unit,
        mode = mode,

        isPlayer = unit == "player",
        isTarget = unit == "target",
        isBoss = IsBossUnit(unit),
        isDerived = IsDerivedUnit(unit),

        previewActive = previewActive,
        forcePreviewVisible = forcePreviewVisible,

        protectedRoot = protectedRoot,
        inCombat = inCombat,

        canRegisterNow = false,
        canUnregisterNow = frame ~= nil and UnregisterUnitWatch ~= nil and not protectedCombat,
    }

    if type(unit) ~= "string" or unit == "" then
        result.reason = frame and "invalid-frame" or "invalid-unit"
        return result
    end

    if unit == "player" then
        result.reason = "player-excluded"
        return result
    end

    if unit == "target" then
        result.reason = "target-excluded"
        return result
    end

    result.shouldUse = true
    if result.isBoss then
        result.reason = "boss-unit"
    elseif result.isDerived then
        result.reason = "derived-unit"
    elseif previewActive then
        result.reason = "preview-unit"
    else
        result.reason = "live-generic-unit"
    end

    result.canRegisterNow = frame ~= nil
        and RegisterUnitWatch ~= nil
        and not previewOutsideCombat
        and not protectedCombat

    return result
end

function Policy.ShouldUse(frameOrUnit, options)
    return Policy.Resolve(frameOrUnit, options).shouldUse == true
end

local function ResolveSyncAction(result)
    if result.reason == "invalid-frame" then
        result.action = "none"
        result.reason = "invalid-frame"
        return result
    end

    if not result.shouldUse or result.previewOutsideCombat then
        if result.isRegistered then
            if result.canUnregisterNow then
                result.action = "unregister"
                result.reason = result.shouldUse and "preview-outside-combat" or "unitwatch-not-used"
                result.shouldUnregister = true
                result.expectedRegisteredAfter = false
            else
                result.action = "blocked"
                result.reason = result.protectedRoot and result.inCombat and "unregister-protected-combat" or "unregister-unavailable"
                result.blocked = true
            end
        else
            result.action = "none"
            result.reason = result.shouldUse and "preview-outside-combat-not-registered" or "unitwatch-not-used"
        end
        return result
    end

    if result.registeredState == false then
        if result.canRegisterNow then
            result.action = "register"
            result.reason = "unitwatch-register"
            result.shouldRegister = true
            result.expectedRegisteredAfter = true
        else
            result.action = "blocked"
            result.reason = result.protectedRoot and result.inCombat and "register-protected-combat" or "register-unavailable"
            result.blocked = true
        end
        return result
    end

    if result.isRegistered then
        result.action = "keep"
        result.reason = "already-registered"
    else
        result.action = "none"
        result.reason = "registration-state-unknown"
    end
    return result
end

function Policy.ResolveSync(frame, options)
    options = type(options) == "table" and options or {}

    local resolved = Policy.Resolve(frame, options)
    local registeredState = frame and frame._unitWatchRegistered or nil
    local previewOutsideCombat = options.previewOutsideCombat == true

    local result = {
        action = "none",
        reason = "invalid-frame",

        unit = resolved.unit,
        mode = resolved.mode,
        shouldUse = resolved.shouldUse == true,

        isRegistered = registeredState and true or false,
        registeredState = registeredState,
        previewOutsideCombat = previewOutsideCombat,

        protectedRoot = resolved.protectedRoot == true,
        inCombat = resolved.inCombat == true,

        canRegisterNow = resolved.canRegisterNow == true,
        canUnregisterNow = resolved.canUnregisterNow == true,

        shouldRegister = false,
        shouldUnregister = false,
        shouldKeep = false,
        blocked = false,
        expectedRegisteredAfter = registeredState,
    }

    if not frame then
        return result
    end

    result.reason = resolved.reason
    ResolveSyncAction(result)
    result.shouldKeep = result.action == "keep"
    return result
end

local function EnsureSyncDebugState()
    FocalPoint.UnitWatchSyncDebug = FocalPoint.UnitWatchSyncDebug or {
        enabled = false,
        totalComparisons = 0,
        totalMismatches = 0,
        mismatchesByUnit = {},
        mismatchesByAction = {},
        mismatchesByReason = {},
        recentMismatches = {},
        lastMismatch = nil,
    }
    return FocalPoint.UnitWatchSyncDebug
end

local function WipeMap(map)
    if type(map) ~= "table" then
        return {}
    end
    for key in pairs(map) do
        map[key] = nil
    end
    return map
end

function Policy.ResetSyncDebug()
    local state = EnsureSyncDebugState()
    state.totalComparisons = 0
    state.totalMismatches = 0
    state.mismatchesByUnit = WipeMap(state.mismatchesByUnit)
    state.mismatchesByAction = WipeMap(state.mismatchesByAction)
    state.mismatchesByReason = WipeMap(state.mismatchesByReason)
    state.recentMismatches = WipeMap(state.recentMismatches)
    state.lastMismatch = nil
    return state
end

function Policy.SetSyncDebugEnabled(enabled)
    local state = EnsureSyncDebugState()
    state.enabled = enabled == true
    return state.enabled
end

function Policy.IsSyncDebugEnabled()
    local state = FocalPoint and FocalPoint.UnitWatchSyncDebug
    return state and state.enabled == true or false
end

local function BumpCounter(map, key)
    key = tostring(key or "unknown")
    map[key] = (tonumber(map[key]) or 0) + 1
end

function Policy.RecordSyncComparison(legacy, decision)
    if not Policy.IsSyncDebugEnabled() then
        return
    end
    if type(legacy) ~= "table" or type(decision) ~= "table" then
        return
    end

    local state = EnsureSyncDebugState()
    state.totalComparisons = (tonumber(state.totalComparisons) or 0) + 1

    if legacy.action == decision.action then
        return
    end

    state.totalMismatches = (tonumber(state.totalMismatches) or 0) + 1
    local unit = tostring(legacy.unit or decision.unit or "unknown")
    local action = tostring(legacy.action or "?") .. "->" .. tostring(decision.action or "?")
    local reason = tostring(legacy.reason or "?") .. "->" .. tostring(decision.reason or "?")

    BumpCounter(state.mismatchesByUnit, unit)
    BumpCounter(state.mismatchesByAction, action)
    BumpCounter(state.mismatchesByReason, reason)

    local entry = {
        unit = unit,
        legacyAction = legacy.action,
        decisionAction = decision.action,
        legacyReason = legacy.reason,
        decisionReason = decision.reason,
        shouldUse = decision.shouldUse == true,
        previewOutsideCombat = decision.previewOutsideCombat == true,
        isRegisteredBefore = legacy.isRegisteredBefore,
        isRegisteredAfter = legacy.isRegisteredAfter,
        protectedRoot = decision.protectedRoot == true,
        inCombat = decision.inCombat == true,
    }

    state.lastMismatch = entry
    local recent = state.recentMismatches
    recent[#recent + 1] = entry
    while #recent > MAX_SYNC_DEBUG_MISMATCHES do
        table.remove(recent, 1)
    end
end

function Policy.GetSyncDebugStatus()
    local state = EnsureSyncDebugState()
    return {
        enabled = state.enabled == true,
        totalComparisons = tonumber(state.totalComparisons) or 0,
        totalMismatches = tonumber(state.totalMismatches) or 0,
        recentCount = #(state.recentMismatches or {}),
    }
end

local function AppendSortedCounters(lines, title, map)
    lines[#lines + 1] = title
    local entries = {}
    for key, value in pairs(map or {}) do
        entries[#entries + 1] = { key = tostring(key), value = tonumber(value) or 0 }
    end
    table.sort(entries, function(a, b)
        if a.value == b.value then
            return a.key < b.key
        end
        return a.value > b.value
    end)
    if #entries == 0 then
        lines[#lines + 1] = "  none"
        return
    end
    for _, entry in ipairs(entries) do
        lines[#lines + 1] = string.format("  %s: %d", entry.key, entry.value)
    end
end

function Policy.BuildSyncDebugReport()
    local state = EnsureSyncDebugState()
    local totalComparisons = tonumber(state.totalComparisons) or 0
    local totalMismatches = tonumber(state.totalMismatches) or 0
    local mismatchRate = totalComparisons > 0 and ((totalMismatches / totalComparisons) * 100) or 0
    local lines = {
        "UnitWatch sync report",
        string.format("Enabled: %s", tostring(state.enabled == true)),
        string.format("Comparisons: %d", totalComparisons),
        string.format("Mismatches: %d", totalMismatches),
        string.format("Mismatch rate: %.2f%%", mismatchRate),
        "",
    }

    AppendSortedCounters(lines, "By unit:", state.mismatchesByUnit)
    lines[#lines + 1] = ""
    AppendSortedCounters(lines, "By action:", state.mismatchesByAction)
    lines[#lines + 1] = ""
    AppendSortedCounters(lines, "By reason:", state.mismatchesByReason)

    local last = state.lastMismatch
    lines[#lines + 1] = ""
    lines[#lines + 1] = "Last mismatch:"
    if last then
        lines[#lines + 1] = string.format(
            "  unit=%s legacy=%s decision=%s registered=%s/%s previewOutsideCombat=%s protected=%s combat=%s shouldUse=%s",
            tostring(last.unit),
            tostring(last.legacyAction),
            tostring(last.decisionAction),
            tostring(last.isRegisteredBefore),
            tostring(last.isRegisteredAfter),
            tostring(last.previewOutsideCombat),
            tostring(last.protectedRoot),
            tostring(last.inCombat),
            tostring(last.shouldUse)
        )
        lines[#lines + 1] = string.format(
            "  reasons=%s/%s",
            tostring(last.legacyReason),
            tostring(last.decisionReason)
        )
    else
        lines[#lines + 1] = "  none"
    end

    return lines
end
