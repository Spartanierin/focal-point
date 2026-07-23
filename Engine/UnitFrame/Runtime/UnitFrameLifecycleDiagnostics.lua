local _, FocalPoint = ...

FocalPoint.UnitFrameLifecycleDiagnostics = FocalPoint.UnitFrameLifecycleDiagnostics or {}
local Lifecycle = FocalPoint.UnitFrameLifecycleDiagnostics

local RING_LIMIT = 150
local REPORT_LIMIT = 35

local function GetTimeValue()
    return GetTime and GetTime() or 0
end

local function EnsureState()
    Lifecycle.state = Lifecycle.state or {
        enabled = false,
        nextFrameId = 0,
        entries = {},
        warnings = {},
        counters = {},
    }
    local state = Lifecycle.state
    state.entries = state.entries or {}
    state.warnings = state.warnings or {}
    state.counters = state.counters or {}
    state.nextFrameId = tonumber(state.nextFrameId) or 0
    return state
end

local function AppendRing(buffer, entry, limit)
    buffer[#buffer + 1] = entry
    while #buffer > limit do
        table.remove(buffer, 1)
    end
end

local function BumpCounter(state, key)
    key = tostring(key or "unknown")
    state.counters[key] = (tonumber(state.counters[key]) or 0) + 1
end

function Lifecycle.IsEnabled()
    local state = EnsureState()
    return state.enabled == true
end

function Lifecycle.SetEnabled(enabled)
    local state = EnsureState()
    state.enabled = enabled == true
end

function Lifecycle.Reset()
    local state = EnsureState()
    state.entries = {}
    state.warnings = {}
    state.counters = {}
end

function Lifecycle.GetFrameId(frame)
    if not frame then
        return nil
    end
    if not frame._focalPointLifecycleDebugId then
        local state = EnsureState()
        state.nextFrameId = (tonumber(state.nextFrameId) or 0) + 1
        frame._focalPointLifecycleDebugId = state.nextFrameId
    end
    return frame._focalPointLifecycleDebugId
end

local function FindFrameInMap(map, frame)
    if type(map) ~= "table" or not frame then
        return nil
    end
    for unit, candidate in pairs(map) do
        if candidate == frame then
            return unit
        end
    end
    return nil
end

local function IsRegionShown(region)
    return region and region.IsShown and region:IsShown() == true or false
end

local function GetFrameAlpha(frame)
    if frame and frame.GetAlpha then
        return tonumber(frame:GetAlpha())
    end
    return nil
end

local function IsUnitPresent(unit)
    if unit == "player" then
        return true
    end
    if type(unit) == "string" and unit ~= "" and UnitExists then
        return UnitExists(unit) and true or false
    end
    return false
end

local function IsOverlayVisible(frame)
    return IsRegionShown(frame and frame.SelectionOverlay) or IsRegionShown(frame and frame.MoveOverlay)
end

local function CountShownMap(map)
    local count = 0
    if type(map) ~= "table" then
        return 0
    end
    for _, region in pairs(map) do
        if IsRegionShown(region) then
            count = count + 1
        end
    end
    return count
end

local function CountShownAuraIcons(frame)
    local count = 0
    local containers = frame and frame.AuraContainers
    if type(containers) ~= "table" then
        return 0
    end
    for _, container in pairs(containers) do
        local icons = container and container.icons
        if type(icons) == "table" then
            count = count + CountShownMap(icons)
        end
    end
    return count
end

local function HasLiveContent(frame)
    if not frame then
        return false
    end
    if CountShownMap(frame.Texts) > 0 then
        return true
    end
    if CountShownMap(frame.Indicators) > 0 then
        return true
    end
    if CountShownAuraIcons(frame) > 0 then
        return true
    end
    local castBar = frame.Elements and frame.Elements.CastBar or nil
    if IsRegionShown(castBar) then
        return true
    end
    return false
end

local function BuildSnapshot(event, frame, values)
    values = type(values) == "table" and values or {}
    local activeUnit = FindFrameInMap(FocalPoint and FocalPoint.frames, frame)
    local pooledUnit = FindFrameInMap(FocalPoint and FocalPoint.framePool, frame)
    local runtimeState = frame and frame.FocalPointRuntimeState or nil
    local unit = values.unit or activeUnit or pooledUnit or frame and frame.unit

    return {
        time = GetTimeValue(),
        event = event,
        unit = unit,
        frameId = Lifecycle.GetFrameId(frame),
        frameUnit = frame and frame.unit or nil,
        shown = IsRegionShown(frame),
        alpha = GetFrameAlpha(frame),
        inFrames = activeUnit ~= nil,
        inPool = pooledUnit ~= nil,
        poolUnit = pooledUnit,
        frameUnitKey = activeUnit,
        unitWatch = frame and frame._unitWatchRegistered == true or false,
        runtimePending = runtimeState and runtimeState.pendingCommit == true or false,
        mode = runtimeState and runtimeState.mode or values.mode,
        reason = values.reason,
        warning = values.warning,
        overlayVisible = IsOverlayVisible(frame),
        pendingVisibility = frame and frame._focalPointPendingVisibilityIntent ~= nil or false,
        pendingLiveReentry = frame and frame._focalPointPendingUnitWatchLiveReentry ~= nil or false,
        missingSince = runtimeState and runtimeState.missingSince or nil,
        targetRecovery = frame and frame._targetRecoveryQueuedUntil ~= nil or false,
        protectedRecovery = frame and frame._protectedMissingTargetRecoveryQueued == true or false,
        liveContent = HasLiveContent(frame),
    }
end

local function FormatBool(value)
    if value == nil then
        return "nil"
    end
    return tostring(value == true)
end

local function FormatNumber(value)
    local number = tonumber(value)
    if not number then
        return "nil"
    end
    return string.format("%.3f", number)
end

local function FormatEntry(entry)
    return string.format(
        "t=%s event=%s unit=%s frame=%s frameUnit=%s shown=%s alpha=%s inFrames=%s inPool=%s unitWatch=%s pending=%s mode=%s reason=%s%s",
        FormatNumber(entry.time),
        tostring(entry.event or "?"),
        tostring(entry.unit or "nil"),
        tostring(entry.frameId or "nil"),
        tostring(entry.frameUnit or "nil"),
        FormatBool(entry.shown),
        FormatNumber(entry.alpha),
        FormatBool(entry.inFrames),
        FormatBool(entry.inPool),
        FormatBool(entry.unitWatch),
        FormatBool(entry.runtimePending),
        tostring(entry.mode or "nil"),
        tostring(entry.reason or "nil"),
        entry.warning and (" warning=" .. tostring(entry.warning)) or ""
    )
end

function Lifecycle.Record(event, frame, values)
    local state = EnsureState()
    if state.enabled ~= true then
        return nil
    end
    local entry = BuildSnapshot(event, frame, values)
    AppendRing(state.entries, entry, RING_LIMIT)
    BumpCounter(state, event)
    if entry.warning then
        AppendRing(state.warnings, entry, RING_LIMIT)
        BumpCounter(state, entry.warning)
    end
    return entry
end

function Lifecycle.RecordWarning(warning, frame, values)
    values = type(values) == "table" and values or {}
    values.warning = warning
    return Lifecycle.Record(values.event or "warning", frame, values)
end

function Lifecycle.CheckDeactivateExit(frame, unit, reason)
    if not Lifecycle.IsEnabled() then
        return
    end
    Lifecycle.Record("deactivate-exit", frame, { unit = unit, reason = reason })
    local pooledUnit = FindFrameInMap(FocalPoint and FocalPoint.framePool, frame)
    if not pooledUnit then
        return
    end
    if IsRegionShown(frame) then
        Lifecycle.RecordWarning("pooled-frame-visible", frame, { unit = unit, reason = reason })
    end
    if frame and frame._unitWatchRegistered == true then
        Lifecycle.RecordWarning("pooled-frame-unitwatch", frame, { unit = unit, reason = reason })
    end
    local runtimeState = frame and frame.FocalPointRuntimeState or nil
    if runtimeState and runtimeState.pendingCommit == true then
        Lifecycle.RecordWarning("pooled-frame-pending-commit", frame, { unit = unit, reason = reason })
    end
    if IsOverlayVisible(frame) then
        Lifecycle.RecordWarning("pooled-frame-editor-overlay", frame, { unit = unit, reason = reason })
    end
    if HasLiveContent(frame) then
        Lifecycle.RecordWarning("pooled-frame-live-content", frame, { unit = unit, reason = reason })
    end
end

local function ShouldExpectVisibleLive(frame, unit)
    if FocalPoint and (FocalPoint.framesUnlocked == true or FocalPoint.guiTestModeEnabled == true) then
        return false
    end
    local config = frame and frame.config
    if type(config) == "table" and config.enabled == false then
        return false
    end
    if not IsUnitPresent(unit) then
        return false
    end
    local Visibility = FocalPoint and FocalPoint.UnitFrameVisibility or nil
    if Visibility and Visibility.ResolveRootDecision then
        local decision = Visibility.ResolveRootDecision(frame, "lifecycle-reuse-check", { config = config })
        return decision and decision.shouldShowRoot == true
    end
    return true
end

function Lifecycle.CheckReuseExit(frame, expectedUnit, reason)
    if not Lifecycle.IsEnabled() then
        return
    end
    Lifecycle.Record("reuse-exit", frame, { unit = expectedUnit, reason = reason })
    if frame and frame.unit ~= expectedUnit then
        Lifecycle.RecordWarning("reuse-unit-mismatch", frame, { unit = expectedUnit, reason = reason })
    end
    if ShouldExpectVisibleLive(frame, expectedUnit) then
        local alpha = GetFrameAlpha(frame)
        if alpha ~= nil and alpha <= 0 then
            Lifecycle.RecordWarning("reuse-alpha-zero-live", frame, { unit = expectedUnit, reason = reason })
        end
        if not IsRegionShown(frame) then
            Lifecycle.RecordWarning("reuse-hidden-live", frame, { unit = expectedUnit, reason = reason })
        end
    end
    if IsOverlayVisible(frame) and not (FocalPoint and FocalPoint.framesUnlocked == true) then
        Lifecycle.RecordWarning("reuse-stale-overlay", frame, { unit = expectedUnit, reason = reason })
    end
end

function Lifecycle.MarkDelayedRefresh(frame, reason, scope, delay)
    if not Lifecycle.IsEnabled() then
        return nil
    end
    return {
        frameId = Lifecycle.GetFrameId(frame),
        unit = frame and frame.unit or nil,
        reason = reason,
        scope = scope,
        delay = delay,
        scheduledAt = GetTimeValue(),
    }
end

function Lifecycle.RecordDelayedRefreshFired(frame, marker)
    if not Lifecycle.IsEnabled() then
        return
    end
    Lifecycle.Record("delayed-refresh-fired", frame, {
        unit = marker and marker.unit or frame and frame.unit,
        reason = marker and marker.reason or nil,
    })
    local activeUnit = FindFrameInMap(FocalPoint and FocalPoint.frames, frame)
    local pooledUnit = FindFrameInMap(FocalPoint and FocalPoint.framePool, frame)
    if not activeUnit then
        Lifecycle.RecordWarning("delayed-refresh-after-deactivate", frame, {
            unit = marker and marker.unit or nil,
            reason = marker and marker.reason or nil,
        })
    end
    if pooledUnit then
        Lifecycle.RecordWarning("delayed-refresh-on-pooled-frame", frame, {
            unit = marker and marker.unit or nil,
            reason = marker and marker.reason or nil,
        })
    end
    if marker and marker.unit and frame and frame.unit ~= marker.unit then
        Lifecycle.RecordWarning("delayed-refresh-unit-mismatch", frame, {
            unit = marker.unit,
            reason = marker.reason,
        })
    end
end

function Lifecycle.RecordDelayedRefreshSkipped(frame, marker, reason)
    if not Lifecycle.IsEnabled() then
        return
    end
    Lifecycle.Record("delayed-refresh-skipped", frame, {
        unit = marker and marker.unit or frame and frame.unit,
        reason = reason or marker and marker.reason or nil,
    })
end

function Lifecycle.RecordAuraReconcile(owner, event, reason)
    if not Lifecycle.IsEnabled() then
        return
    end
    Lifecycle.Record(event or "aura-reconcile", owner, { reason = reason })
    local activeUnit = FindFrameInMap(FocalPoint and FocalPoint.frames, owner)
    local pooledUnit = FindFrameInMap(FocalPoint and FocalPoint.framePool, owner)
    if not activeUnit then
        Lifecycle.RecordWarning("aura-reconcile-after-deactivate", owner, { reason = reason })
    end
    if pooledUnit then
        Lifecycle.RecordWarning("aura-reconcile-on-pooled-frame", owner, { reason = reason })
    end
end

local function AppendSortedCounters(lines, counters)
    local entries = {}
    for key, value in pairs(counters or {}) do
        entries[#entries + 1] = { key = tostring(key), value = tonumber(value) or 0 }
    end
    table.sort(entries, function(a, b)
        if a.value == b.value then
            return a.key < b.key
        end
        return a.value > b.value
    end)
    if #entries == 0 then
        lines[#lines + 1] = "Counters: none"
        return
    end
    lines[#lines + 1] = "Counters:"
    for _, entry in ipairs(entries) do
        lines[#lines + 1] = string.format("  %s: %d", entry.key, entry.value)
    end
end

local function BuildPooledFrameLines(summary)
    local lines = {}
    local pool = FocalPoint and FocalPoint.framePool
    if type(pool) ~= "table" then
        return lines
    end
    local units = {}
    for unit in pairs(pool) do
        units[#units + 1] = tostring(unit)
    end
    table.sort(units)
    for _, unit in ipairs(units) do
        local frame = pool[unit]
        local runtimeState = frame and frame.FocalPointRuntimeState or nil
        local shown = IsRegionShown(frame)
        local unitWatch = frame and frame._unitWatchRegistered == true or false
        local pending = runtimeState and runtimeState.pendingCommit == true or false
        local overlay = IsOverlayVisible(frame)

        summary.total = summary.total + 1
        if shown then
            summary.visible = summary.visible + 1
        end
        if unitWatch then
            summary.unitWatch = summary.unitWatch + 1
        end
        if pending then
            summary.pendingCommit = summary.pendingCommit + 1
        end
        if overlay then
            summary.overlay = summary.overlay + 1
        end
        if HasLiveContent(frame) then
            summary.liveContent = summary.liveContent + 1
        end

        lines[#lines + 1] = string.format(
            "  unit=%s frame=%s shown=%s alpha=%s unitWatch=%s pending=%s pendingVisibility=%s pendingLiveReentry=%s missingSince=%s recovery=%s/%s overlay=%s",
            unit,
            tostring(Lifecycle.GetFrameId(frame) or "nil"),
            FormatBool(shown),
            FormatNumber(GetFrameAlpha(frame)),
            FormatBool(unitWatch),
            FormatBool(pending),
            FormatBool(frame and frame._focalPointPendingVisibilityIntent ~= nil or false),
            FormatBool(frame and frame._focalPointPendingUnitWatchLiveReentry ~= nil or false),
            FormatNumber(runtimeState and runtimeState.missingSince or nil),
            FormatBool(frame and frame._targetRecoveryQueuedUntil ~= nil or false),
            FormatBool(frame and frame._protectedMissingTargetRecoveryQueued == true or false),
            FormatBool(overlay)
        )
    end
    return lines
end

function Lifecycle.BuildReport()
    local state = EnsureState()
    local summary = {
        total = 0,
        visible = 0,
        unitWatch = 0,
        pendingCommit = 0,
        overlay = 0,
        liveContent = 0,
    }
    local pooledLines = BuildPooledFrameLines(summary)
    local warningCount = #(state.warnings or {})
    local lines = {
        "Lifecycle diagnostics report",
        string.format("Enabled: %s", tostring(state.enabled == true)),
        string.format(
            "Pooled frames: total=%d visible=%d unitWatch=%d pendingCommit=%d overlay=%d liveContent=%d",
            summary.total,
            summary.visible,
            summary.unitWatch,
            summary.pendingCommit,
            summary.overlay,
            summary.liveContent
        ),
        string.format("Warnings: %d", warningCount),
    }

    local hasCurrentPoolIssue = summary.visible > 0
        or summary.unitWatch > 0
        or summary.pendingCommit > 0
        or summary.overlay > 0
        or summary.liveContent > 0
    if warningCount == 0 and not hasCurrentPoolIssue then
        lines[#lines + 1] = "Lifecycle diagnostics: no mismatches detected."
    end

    if #pooledLines > 0 then
        lines[#lines + 1] = "Pooled frame state:"
        for _, line in ipairs(pooledLines) do
            lines[#lines + 1] = line
        end
    end

    AppendSortedCounters(lines, state.counters)

    lines[#lines + 1] = "Recent warnings/events:"
    local source = warningCount > 0 and state.warnings or state.entries
    local first = math.max(1, #source - REPORT_LIMIT + 1)
    if #source == 0 then
        lines[#lines + 1] = "  none"
    else
        for index = first, #source do
            lines[#lines + 1] = "  " .. FormatEntry(source[index])
        end
    end

    return lines
end

function Lifecycle.GetStatus()
    local state = EnsureState()
    return {
        enabled = state.enabled == true,
        entries = #(state.entries or {}),
        warnings = #(state.warnings or {}),
    }
end

return Lifecycle
