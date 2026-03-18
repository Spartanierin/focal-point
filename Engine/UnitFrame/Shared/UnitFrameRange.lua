local _, FocalPoint = ...

FocalPoint.UnitFrameRange = FocalPoint.UnitFrameRange or {}
local Range = FocalPoint.UnitFrameRange

local Presence = FocalPoint.UnitFramePresence or {}
local Utils = FocalPoint.UnitFrameUtils or {}

local DoesUnitSeemPresent = Presence.DoesUnitSeemPresent
local IsPreviewModeEnabled = Presence.IsPreviewModeEnabled
local IsSafeTrue = Utils.IsSafeTrue

local TARGET_OUT_OF_RANGE_ALPHA = 0.5
local TARGET_RANGE_FADE_SPEED = 16

-- Range fading is intentionally narrow in scope for now:
-- target only, soft alpha transition, no GUI dependency.

function Range.GetFadeMultiplier(frame)
    local rangeThreshold = tonumber(FocalPoint and FocalPoint.TARGET_RANGE_CHECK_YARDS) or 40

    if not frame or frame.unit ~= "target" or IsPreviewModeEnabled() then
        return 1
    end

    if not DoesUnitSeemPresent(frame.unit) then
        return 1
    end

    if UnitIsDeadOrGhost and IsSafeTrue(UnitIsDeadOrGhost(frame.unit)) then
        return 1
    end

    if UnitIsConnected and not IsSafeTrue(UnitIsConnected(frame.unit)) then
        return 1
    end

    if UnitCanAttack and UnitCanAssist then
        local isHostile = IsSafeTrue(UnitCanAttack("player", frame.unit))
        local isFriendly = IsSafeTrue(UnitCanAssist("player", frame.unit))
        if isFriendly and not isHostile then
            return 1
        end
    end

    if not (FocalPoint and FocalPoint.RangeCheck) then
        return 1
    end

    if FocalPoint.RangeCheck.GetRange then
        local ok, minRange, maxRange = pcall(FocalPoint.RangeCheck.GetRange, FocalPoint.RangeCheck, frame.unit, true, false, 0.15)
        if ok and type(minRange) == "number" then
            if type(maxRange) == "number" and maxRange <= rangeThreshold then
                return 1
            end

            if minRange > rangeThreshold then
                return TARGET_OUT_OF_RANGE_ALPHA
            end

            if maxRange == nil and minRange >= rangeThreshold then
                return TARGET_OUT_OF_RANGE_ALPHA
            end

            return 1
        end
    end

    if not FocalPoint.GetTargetRangeChecker then
        return 1
    end

    local checker = FocalPoint:GetTargetRangeChecker()
    if type(checker) ~= "function" then
        return 1
    end

    local ok, inRange = pcall(checker, frame.unit)
    if not ok or type(inRange) ~= "boolean" or (issecretvalue and issecretvalue(inRange)) then
        return 1
    end

    return inRange and 1 or TARGET_OUT_OF_RANGE_ALPHA
end

function Range.EnsureFadeDriver(frame)
    if not frame or frame.RangeFadeDriver then
        return frame and frame.RangeFadeDriver or nil
    end

    local driver = CreateFrame("Frame", nil, frame)
    driver:Hide()
    driver.owner = frame
    driver:SetScript("OnUpdate", function(self, elapsed)
        local owner = self.owner
        if not owner or not owner:IsShown() then
            self:Hide()
            return
        end

        local targetAlpha = owner._rangeTargetAlpha
        local currentAlpha = owner._rangeCurrentAlpha
        if type(targetAlpha) ~= "number" or type(currentAlpha) ~= "number" then
            self:Hide()
            return
        end

        local delta = targetAlpha - currentAlpha
        if math.abs(delta) < 0.01 then
            owner._rangeCurrentAlpha = targetAlpha
            owner:SetAlpha(targetAlpha)
            self:Hide()
            return
        end

        local step = math.min(1, (elapsed or 0) * TARGET_RANGE_FADE_SPEED)
        currentAlpha = currentAlpha + (delta * step)
        owner._rangeCurrentAlpha = currentAlpha
        owner:SetAlpha(currentAlpha)
    end)

    frame.RangeFadeDriver = driver
    return driver
end
