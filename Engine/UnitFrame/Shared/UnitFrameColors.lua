local _, FocalPoint = ...

FocalPoint.UnitFrameColors = FocalPoint.UnitFrameColors or {}
local Colors = FocalPoint.UnitFrameColors

local Utils = FocalPoint.UnitFrameUtils or {}
local IsSafeTrue = Utils.IsSafeTrue
local UnpackColor = Utils.UnpackColor
local ToSafeNumberValue = Utils.ToSafeNumberValue

-- Color helpers stay side-effect free.
-- They resolve health and power colors without touching frame state.

local function SafeColorComponent(value, fallback)
    if type(value) == "number" and not (issecretvalue and issecretvalue(value)) then
        return value
    end

    if type(fallback) == "number" and not (issecretvalue and issecretvalue(fallback)) then
        return fallback
    end

    return 1
end

local function SanitizeRGBA(r, g, b, a, fallbackR, fallbackG, fallbackB, fallbackA)
    return SafeColorComponent(r, fallbackR),
        SafeColorComponent(g, fallbackG),
        SafeColorComponent(b, fallbackB),
        SafeColorComponent(a, fallbackA)
end

local function IsConfiguredColorComponent(value)
    if issecretvalue and issecretvalue(value) then
        return false
    end

    return type(value) == "number"
end

local function HasConfiguredColor(color)
    if type(color) ~= "table" then
        return false
    end

    return IsConfiguredColorComponent(color.r or color[1] or color["1"])
        and IsConfiguredColorComponent(color.g or color[2] or color["2"])
        and IsConfiguredColorComponent(color.b or color[3] or color["3"])
end

local function UnpackConfiguredColor(color, fallback)
    if type(color) ~= "table" then
        return UnpackColor(color, fallback)
    end

    -- SavedVariables can retain stale numeric color keys. Named r/g/b/a
    -- fields are the authoritative custom color written by the editor/theme.
    local r = color.r
    if r == nil then
        r = color[1] or color["1"]
    end

    local g = color.g
    if g == nil then
        g = color[2] or color["2"]
    end

    local b = color.b
    if b == nil then
        b = color[3] or color["3"]
    end

    local a = color.a
    if a == nil then
        a = color[4] or color["4"]
    end

    local fallbackR, fallbackG, fallbackB, fallbackA = UnpackColor(fallback)
    return SanitizeRGBA(r, g, b, a, fallbackR, fallbackG, fallbackB, fallbackA)
end

function Colors.IsUnitDeadByHealth(unit)
    if not unit or not UnitHealth or not UnitHealthMax then
        return false
    end

    local ok, result = pcall(function()
        local currentHealth = UnitHealth(unit)
        local maxHealth = UnitHealthMax(unit)
        return type(currentHealth) == "number"
            and type(maxHealth) == "number"
            and maxHealth > 0
            and currentHealth <= 0
    end)

    return ok and result == true
end

local function ResolveClassColorByToken(classToken)
    if type(classToken) == "string" then
        classToken = classToken:upper()
    end

    if not classToken or classToken == "" then
        return nil
    end

    local color = nil

    if CUSTOM_CLASS_COLORS and CUSTOM_CLASS_COLORS[classToken] then
        color = CUSTOM_CLASS_COLORS[classToken]
    elseif RAID_CLASS_COLORS and RAID_CLASS_COLORS[classToken] then
        color = RAID_CLASS_COLORS[classToken]
    elseif C_ClassColor and C_ClassColor.GetClassColor then
        color = C_ClassColor.GetClassColor(classToken)
    end

    if not color then
        return nil
    end

    return SanitizeRGBA(
        color.r or color[1],
        color.g or color[2],
        color.b or color[3],
        color.a or color[4] or 1,
        nil,
        nil,
        nil,
        1
    )
end

function Colors.GetClassColorForUnit(unit, useReactionForNpc)
    if not unit or not UnitExists or not UnitExists(unit) or not UnitClass then
        return nil
    end

    local function GetHostileFallbackColor()
        local hostileColor = FACTION_BAR_COLORS and (FACTION_BAR_COLORS[2] or FACTION_BAR_COLORS[1]) or nil
        if hostileColor then
            return SanitizeRGBA(
                hostileColor.r or hostileColor[1],
                hostileColor.g or hostileColor[2],
                hostileColor.b or hostileColor[3],
                1,
                1,
                0.1,
                0.1,
                1
            )
        end

        return 1, 0.1, 0.1, 1
    end

    if UnitIsPlayer and UnitIsPlayer(unit) and UnitIsEnemy and IsSafeTrue(UnitIsEnemy("player", unit)) then
        return GetHostileFallbackColor()
    end

    if UnitReaction and FACTION_BAR_COLORS then
        local reaction = UnitReaction("player", unit)
        local color = reaction and FACTION_BAR_COLORS[reaction] or nil

        if UnitIsPlayer and UnitIsPlayer(unit) and UnitCanAttack and IsSafeTrue(UnitCanAttack("player", unit)) and color then
            return SanitizeRGBA(
                color.r or color[1],
                color.g or color[2],
                color.b or color[3],
                1,
                1,
                1,
                1,
                1
            )
        end

        if UnitIsPlayer and not UnitIsPlayer(unit) and useReactionForNpc and color then
            return SanitizeRGBA(
                color.r or color[1],
                color.g or color[2],
                color.b or color[3],
                1,
                1,
                1,
                1,
                1
            )
        end
    end

    if UnitIsPlayer and not UnitIsPlayer(unit) then
        if unit == "pet" then
            local _, ownerClassToken = UnitClass("player")
            local ownerR, ownerG, ownerB, ownerA = ResolveClassColorByToken(ownerClassToken)
            if ownerR and ownerG and ownerB then
                return SanitizeRGBA(ownerR, ownerG, ownerB, ownerA or 1, 1, 1, 1, 1)
            end
        end

        if type(unit) == "string" and unit:match("^boss%d+$") and UnitCanAttack and IsSafeTrue(UnitCanAttack("player", unit)) then
            return GetHostileFallbackColor()
        end

        if useReactionForNpc and UnitReaction and FACTION_BAR_COLORS then
            local reaction = UnitReaction("player", unit)
            local color = reaction and FACTION_BAR_COLORS[reaction] or nil
            if color then
                return SanitizeRGBA(
                    color.r or color[1],
                    color.g or color[2],
                    color.b or color[3],
                    1,
                    1,
                    1,
                    1,
                    1
                )
            end
        end

        return nil
    end

    local _, classToken = UnitClass(unit)
    return ResolveClassColorByToken(classToken)
end

function Colors.GetPowerColorForUnit(unit)
    if not unit or not UnitExists or not UnitExists(unit) or not UnitPowerType then
        return nil
    end

    local powerType = UnitPowerType(unit)
    if powerType == nil then
        return nil
    end

    local color = PowerBarColor and PowerBarColor[powerType]
    if not color then
        return nil
    end

    return SanitizeRGBA(
        color.r or color[1],
        color.g or color[2],
        color.b or color[3],
        color.a or color[4],
        nil,
        nil,
        nil,
        1
    )
end

local function BuildCurveColor(r, g, b, a)
    if CreateColor then
        local color = CreateColor(r, g, b, a)
        if color then
            return color
        end
    end

    local color = { r = r, g = g, b = b, a = a }
    function color:GetRGBA()
        return self.r, self.g, self.b, self.a
    end
    return color
end

local function ResolveCurveColor(curve, percent, fallbackR, fallbackG, fallbackB, fallbackA)
    if not curve or type(percent) ~= "number" or not curve.Evaluate then
        return fallbackR, fallbackG, fallbackB, fallbackA
    end

    local ok, color = pcall(curve.Evaluate, curve, percent)
    if not ok or not color then
        return fallbackR, fallbackG, fallbackB, fallbackA
    end

    if color.GetRGBA then
        local r, g, b, a = color:GetRGBA()
        if type(r) == "number" and type(g) == "number" and type(b) == "number" then
            return SanitizeRGBA(r, g, b, type(a) == "number" and a or fallbackA, fallbackR, fallbackG, fallbackB, fallbackA)
        end
    end

    local r = color.r or color[1]
    local g = color.g or color[2]
    local b = color.b or color[3]
    local a = color.a or color[4]
    if type(r) == "number" and type(g) == "number" and type(b) == "number" then
        return SanitizeRGBA(r, g, b, type(a) == "number" and a or fallbackA, fallbackR, fallbackG, fallbackB, fallbackA)
    end

    return fallbackR, fallbackG, fallbackB, fallbackA
end

local function ResolveUnitHealthCurveColor(unit, curve, fallbackR, fallbackG, fallbackB, fallbackA)
    if type(unit) ~= "string" or unit == "" or not curve or not UnitHealthPercent then
        return nil
    end

    local ok, color = pcall(UnitHealthPercent, unit, false, curve)
    if not ok or not color then
        return nil
    end

    if color.GetRGBA then
        local r, g, b, a = color:GetRGBA()
        if type(r) == "number" and type(g) == "number" and type(b) == "number" then
            local sr, sg, sb, sa = SanitizeRGBA(r, g, b, type(a) == "number" and a or fallbackA, fallbackR, fallbackG, fallbackB, fallbackA)
            return sr, sg, sb, sa, true
        end
    end

    local r = color.r or color[1]
    local g = color.g or color[2]
    local b = color.b or color[3]
    local a = color.a or color[4]
    if type(r) == "number" and type(g) == "number" and type(b) == "number" then
        local sr, sg, sb, sa = SanitizeRGBA(r, g, b, type(a) == "number" and a or fallbackA, fallbackR, fallbackG, fallbackB, fallbackA)
        return sr, sg, sb, sa, true
    end

    return nil
end

local function ResolvePredictionCurveColor(frame, curve, fallbackR, fallbackG, fallbackB, fallbackA)
    local values = frame and frame.HealthPredictionValues
    if not values or not curve or not values.EvaluateCurrentHealthPercent then
        return nil
    end

    local ok, color = pcall(values.EvaluateCurrentHealthPercent, values, curve)
    if not ok or not color then
        return nil
    end

    if color.GetRGBA then
        local r, g, b, a = color:GetRGBA()
        if type(r) == "number" and type(g) == "number" and type(b) == "number" then
            local sr, sg, sb, sa = SanitizeRGBA(r, g, b, type(a) == "number" and a or fallbackA, fallbackR, fallbackG, fallbackB, fallbackA)
            return sr, sg, sb, sa, true
        end
    end

    local r = color.r or color[1]
    local g = color.g or color[2]
    local b = color.b or color[3]
    local a = color.a or color[4]
    if type(r) == "number" and type(g) == "number" and type(b) == "number" then
        local sr, sg, sb, sa = SanitizeRGBA(r, g, b, type(a) == "number" and a or fallbackA, fallbackR, fallbackG, fallbackB, fallbackA)
        return sr, sg, sb, sa, true
    end

    return nil
end

local function GetHealthPercent(currentHealth, maxHealth)
    local current = ToSafeNumberValue and ToSafeNumberValue(currentHealth) or 0
    local maximum = ToSafeNumberValue and ToSafeNumberValue(maxHealth) or 0
    if maximum <= 0 then
        return nil
    end

    local percent = current / maximum
    if percent < 0 then
        percent = 0
    elseif percent > 1 then
        percent = 1
    end

    return percent
end

function Colors.GetResolvedHealthBarColor(frame, config)
    local hasCustomHealthColor = config
        and config.useClassColorHealth == false
        and HasConfiguredColor(config.healthColor)
    local healthR, healthG, healthB, healthA
    if hasCustomHealthColor then
        healthR, healthG, healthB, healthA = UnpackConfiguredColor(config.healthColor, { 0.1, 0.8, 0.1, 1 })
    else
        healthR, healthG, healthB, healthA = UnpackColor(config and config.healthColor, { 0.1, 0.8, 0.1, 1 })
    end
    healthR, healthG, healthB, healthA = SanitizeRGBA(healthR, healthG, healthB, healthA, 0.1, 0.8, 0.1, 1)

    if config and config.useClassColorHealth then
        local classR, classG, classB = Colors.GetClassColorForUnit(frame and frame.unit, config.useReactionColorNpcHealth)
        if classR and classG and classB then
            healthR, healthG, healthB = classR, classG, classB
        end
    end

    local lowR, lowG, lowB, lowA = UnpackColor(config and config.healthLowColor, { 1.0, 0.12, 0.12, healthA or 1 })
    lowR, lowG, lowB, lowA = SanitizeRGBA(lowR, lowG, lowB, lowA, 1.0, 0.12, 0.12, healthA or 1)

    if C_CurveUtil and C_CurveUtil.CreateColorCurve then
        local curve = C_CurveUtil.CreateColorCurve()
        if curve then
            if curve.SetType and Enum and Enum.LuaCurveType and Enum.LuaCurveType.Linear then
                curve:SetType(Enum.LuaCurveType.Linear)
            end
            curve:AddPoint(0, BuildCurveColor(lowR, lowG, lowB, lowA))
            curve:AddPoint(0.30, BuildCurveColor(lowR, lowG, lowB, lowA))
            curve:AddPoint(0.75, BuildCurveColor(1.0, 0.84, 0.18, math.max(lowA or 1, healthA or 1)))
            curve:AddPoint(1, BuildCurveColor(healthR, healthG, healthB, healthA))

            local resolvedR, resolvedG, resolvedB, resolvedA, resolvedFromPrediction
            if not hasCustomHealthColor then
                resolvedR, resolvedG, resolvedB, resolvedA, resolvedFromPrediction = ResolvePredictionCurveColor(
                    frame,
                    curve,
                    healthR,
                    healthG,
                    healthB,
                    healthA
                )
                if resolvedFromPrediction then
                    return SanitizeRGBA(resolvedR, resolvedG, resolvedB, resolvedA, healthR, healthG, healthB, healthA)
                end
            end

            local percent = GetHealthPercent(
                frame and frame.LiveValues and frame.LiveValues.healthCurrentSafe,
                frame and frame.LiveValues and frame.LiveValues.healthMaxSafe
            )
            if percent then
                return ResolveCurveColor(curve, percent, healthR, healthG, healthB, healthA)
            end

            percent = GetHealthPercent(
                frame and frame.LiveValues and frame.LiveValues.healthBarCurrentSafe,
                frame and frame.LiveValues and frame.LiveValues.healthBarMaxSafe
            )
            if percent then
                return ResolveCurveColor(curve, percent, healthR, healthG, healthB, healthA)
            end

            local resolvedFromUnit
            if not hasCustomHealthColor then
                resolvedR, resolvedG, resolvedB, resolvedA, resolvedFromUnit = ResolveUnitHealthCurveColor(
                    frame and frame.unit,
                    curve,
                    healthR,
                    healthG,
                    healthB,
                    healthA
                )
            end

            if resolvedFromUnit then
                return SanitizeRGBA(resolvedR, resolvedG, resolvedB, resolvedA, healthR, healthG, healthB, healthA)
            end
        end
    end

    return SanitizeRGBA(healthR, healthG, healthB, healthA, 0.1, 0.8, 0.1, 1)
end
