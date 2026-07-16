local _, FocalPoint = ...

FocalPoint.UnitFrameUnitWatchPolicy = FocalPoint.UnitFrameUnitWatchPolicy or {}
local Policy = FocalPoint.UnitFrameUnitWatchPolicy

local Demo = FocalPoint.UnitFrameDemoEnvironment or {}

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
    local previewOutsideCombat = previewActive and not inCombat

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
