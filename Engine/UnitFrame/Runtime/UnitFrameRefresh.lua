local _, FocalPoint = ...

FocalPoint.UnitFrameRefresh = FocalPoint.UnitFrameRefresh or {}
local Refresh = FocalPoint.UnitFrameRefresh
local Presence = FocalPoint.UnitFramePresence or {}
local Demo = FocalPoint.UnitFrameDemoEnvironment or {}

local IsPreviewModeEnabled = Presence.IsPreviewModeEnabled

local function IsProtectedRoot(frame)
    return frame and frame.IsProtected and frame:IsProtected()
end

local function ShouldUseUnitWatch(frame)
    local unit = frame and frame.unit
    -- Target visibility is managed by Focal Point directly. Letting UnitWatch
    -- hide the secure target root during combat can leave it hidden until combat
    -- ends, even after PLAYER_TARGET_CHANGED reports a valid target again.
    return unit ~= "player" and unit ~= "target"
end

local function SyncPreviewUnitWatch(frame, previewOutsideCombat)
    if not frame then
        return
    end

    if not ShouldUseUnitWatch(frame) or previewOutsideCombat then
        if frame._unitWatchRegistered
            and UnregisterUnitWatch
            and not (IsProtectedRoot(frame) and InCombatLockdown and InCombatLockdown())
        then
            UnregisterUnitWatch(frame)
            frame._unitWatchRegistered = false
        end
        return
    end

    if frame._unitWatchRegistered == false and RegisterUnitWatch then
        RegisterUnitWatch(frame)
        frame._unitWatchRegistered = true
    end
end

local function HasScope(refreshRequest, scope)
    local scopes = refreshRequest and refreshRequest.scopes
    return type(scopes) == "table" and scopes[scope] == true
end

local function IsScopedRefresh(refreshRequest)
    local scopes = refreshRequest and refreshRequest.scopes
    return type(scopes) == "table" and next(scopes) ~= nil and refreshRequest.forceFullRefresh ~= true
end

-- Refresh orchestration keeps the normal live-update path together so the
-- main unit-frame runtime only handles guards and high-level delegation.

function Refresh.Apply(owner, frame, config, refreshRequest)
    if not owner or not frame or not config then
        return
    end

    if Demo.TouchDebug then
        Demo.TouchDebug(frame, "refreshApply")
    end

    frame.config = config
    local mode, modeReason = "live", "live-no-resolve"
    if Demo.ResolveMode then
        mode, modeReason = Demo.ResolveMode(frame, "refresh")
    end
    if Demo.CommitMode then
        Demo.CommitMode(frame, mode, modeReason)
    end

    local demoApplied = Demo.ApplyFrameSnapshot and Demo.ApplyFrameSnapshot(owner, frame, refreshRequest, mode, modeReason) or false
    if demoApplied then
        if Demo.ShouldProcessFrame and not Demo.ShouldProcessFrame(frame) then
            if frame.Hide then
                frame:Hide()
            end
            if Demo.ReportDebug then
                Demo.ReportDebug(frame)
            end
            return
        end
        local shouldApplyConfig = Demo.ShouldApplyConfig and Demo.ShouldApplyConfig(frame, refreshRequest, mode, modeReason) or true
        if shouldApplyConfig and owner.ApplyConfig then
            if Demo.TouchDebug then
                Demo.TouchDebug(frame, "applyConfig")
            end
            owner:ApplyConfig(frame)
        end
        if Demo.ApplyRuntimePreview then
            Demo.ApplyRuntimePreview(owner, frame, refreshRequest, mode, modeReason)
        end
        if not (Demo.IsRangeFadeDisabled and Demo.IsRangeFadeDisabled()) then
            owner:ApplyRangeFade(frame)
        end

        local protectedRoot = IsProtectedRoot(frame)
        local previewOutsideCombat = IsPreviewModeEnabled
            and IsPreviewModeEnabled()
            and not (InCombatLockdown and InCombatLockdown())
        local outsideCombat = not (InCombatLockdown and InCombatLockdown())

        SyncPreviewUnitWatch(frame, previewOutsideCombat)

        if not protectedRoot or previewOutsideCombat or outsideCombat then
            frame:Show()
        end
        if Demo.ReportDebug then
            Demo.ReportDebug(frame)
        end
        return
    end

    local scopedRefresh = IsScopedRefresh(refreshRequest)
    local needsFull = not scopedRefresh
    local needsLayout = needsFull or HasScope(refreshRequest, "layout")
    local needsBars = needsFull or HasScope(refreshRequest, "bars")
    local needsTexts = needsFull or HasScope(refreshRequest, "texts")
    local needsAuras = needsFull or HasScope(refreshRequest, "auras")
    local needsCastbar = needsFull or HasScope(refreshRequest, "castbar")
    local needsVisibility = needsFull or HasScope(refreshRequest, "visibility")

    if needsBars and owner.RefreshUnitBarValues then
        owner:RefreshUnitBarValues(frame)
    end
    if needsLayout and owner.ApplyConfig then
        owner:ApplyConfig(frame)
    end
    if needsFull and owner.ApplyTestValues then
        owner:ApplyTestValues(frame)
    end

    if needsCastbar and owner.RefreshCastBar then
        owner:RefreshCastBar(frame)
    end
    if needsTexts and owner.RefreshLiveValues then
        owner:RefreshLiveValues(frame)
    end
    if needsAuras and owner.RefreshAuras then
        owner:RefreshAuras(frame, refreshRequest and refreshRequest.forceAuraFullScan == true)
    end
    if needsTexts and owner.UpdateTextElements then
        owner:UpdateTextElements(frame)
    end

    if needsVisibility and owner.ApplyRangeFade then
        owner:ApplyRangeFade(frame)
    end

    local protectedRoot = IsProtectedRoot(frame)
    local previewOutsideCombat = IsPreviewModeEnabled
        and IsPreviewModeEnabled()
        and not (InCombatLockdown and InCombatLockdown())
    local outsideCombat = not (InCombatLockdown and InCombatLockdown())

    SyncPreviewUnitWatch(frame, previewOutsideCombat)

    local skipShowForAbsentTarget = frame.unit == "target"
        and not previewOutsideCombat
        and UnitExists
        and not UnitExists("target")

    if (not protectedRoot or previewOutsideCombat or outsideCombat) and not skipShowForAbsentTarget then
        frame:Show()
    end

    if Demo.ReportDebug then
        Demo.ReportDebug(frame)
    end
end
