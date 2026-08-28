local _, FocalPoint = ...

FocalPoint.GUI = FocalPoint.GUI or {}
FocalPoint.GUI.Editor = FocalPoint.GUI.Editor or {}

local Resolver = {}
FocalPoint.GUI.Editor.SelectionGeometryResolver = Resolver

local Factory = FocalPoint.UnitFrameFactory or {}

local BAR_SPECS = {
    HealthBar = { elementKey = "HealthBar" },
    PowerBar = { elementKey = "PowerBar", fallback = "power" },
    CastBar = { elementKey = "CastBar", fallback = "cast" },
    ClassPowerBar = { elementKey = "ClassPowerBar", fallback = "classPower" },
    AlternativePowerBar = { elementKey = "AlternativePowerBar", fallback = "alternativePower" },
    NormalAbsorbBar = { elementKey = "NormalAbsorbBar", absorbPrefix = "normalAbsorbBar" },
    HealingAbsorbBar = { elementKey = "HealingAbsorbBar", absorbPrefix = "healingAbsorbBar" },
}

local function Number(value, fallback)
    local parsed = tonumber(value)
    if parsed == nil then
        return fallback
    end
    return parsed
end

local function HasGeometry(target)
    if not (target and target.GetNumPoints and target:GetNumPoints() > 0) then
        return false
    end
    local width = target.GetWidth and target:GetWidth() or 0
    local height = target.GetHeight and target:GetHeight() or 0
    return Number(width, 0) > 0 and Number(height, 0) > 0
end

local function GetAnchorTarget(frame, anchorTo)
    if Factory.GetAnchorTarget then
        return Factory.GetAnchorTarget(frame, anchorTo)
    end
    return frame
end

local function FrameGeometry(target, source)
    if not HasGeometry(target) then
        return nil
    end
    return {
        source = source or "frame",
        target = target,
    }
end

local function PointGeometry(relativeTo, point, relativePoint, width, height, offsetX, offsetY, source)
    if not (relativeTo and point and relativePoint) then
        return nil
    end
    return {
        source = source or "config",
        width = width,
        height = height,
        points = {
            {
                point = point,
                relativeTo = relativeTo,
                relativePoint = relativePoint,
                offsetX = offsetX or 0,
                offsetY = offsetY or 0,
            },
        },
    }
end

local function StretchGeometry(relativeTo, insetLeft, insetRight, bottomOffset, height, source)
    if not relativeTo then
        return nil
    end
    return {
        source = source or "config",
        height = height,
        points = {
            {
                point = "BOTTOMLEFT",
                relativeTo = relativeTo,
                relativePoint = "BOTTOMLEFT",
                offsetX = insetLeft or 0,
                offsetY = bottomOffset or 0,
            },
            {
                point = "BOTTOMRIGHT",
                relativeTo = relativeTo,
                relativePoint = "BOTTOMRIGHT",
                offsetX = -(insetRight or 0),
                offsetY = bottomOffset or 0,
            },
        },
    }
end

local function ResolvePower(frame, config)
    local borderInset = Number(config and config.borderInset, 1)
    local height = Number(config and config.powerBarHeight, 8)
    local bottomOffset = borderInset
    if config and config.showAlternativePowerBar == true then
        bottomOffset = bottomOffset + Number(config.alternativePowerBarHeight, 5)
    end
    return StretchGeometry(frame, borderInset, borderInset, bottomOffset, height, "power-config")
end

local function ResolveAlternativePower(frame, config)
    local borderInset = Number(config and config.borderInset, 1)
    local height = Number(config and config.alternativePowerBarHeight, 5)
    return StretchGeometry(frame, borderInset, borderInset, borderInset, height, "alternative-power-config")
end

local function ResolveCast(frame, config)
    local height = Number(config and config.castBarHeight, 10)
    local iconSize = (not config or config.showCastBarIcon ~= false) and height or 0
    local iconGap = iconSize > 0 and 4 or 0
    local borderInset = Number(config and config.borderInset, 1)
    local width = math.max(Number(config and config.width, frame.GetWidth and frame:GetWidth() or 0) - (borderInset * 2) - iconSize - iconGap, 20)
    return PointGeometry(
        frame,
        (config and config.castBarPoint) or "BOTTOMLEFT",
        (config and config.castBarRelativePoint) or "TOPLEFT",
        width,
        height,
        Number(config and config.castBarOffsetX, 0) + borderInset + iconSize + iconGap,
        Number(config and config.castBarOffsetY, 4),
        "cast-config"
    )
end

local function ResolveClassPower(frame, config)
    local anchorTarget = GetAnchorTarget(frame, config and config.classPowerBarAnchorTo or "HealthBar") or frame
    return PointGeometry(
        anchorTarget,
        (config and config.classPowerBarPoint) or "BOTTOMRIGHT",
        (config and config.classPowerBarRelativePoint) or "BOTTOMRIGHT",
        math.max(40, Number(config and config.classPowerBarWidth, 100)),
        math.max(4, Number(config and config.classPowerBarHeight, 12)),
        Number(config and config.classPowerBarOffsetX, -5),
        Number(config and config.classPowerBarOffsetY, 5),
        "class-power-config"
    )
end

local function ResolveAbsorb(frame, config, prefix)
    local anchorTarget = GetAnchorTarget(frame, config and config[prefix .. "AnchorTo"] or "HealthBar") or frame
    if config and config[prefix .. "SizeMode"] == "CUSTOM" then
        return PointGeometry(
            anchorTarget,
            config[prefix .. "Point"] or "CENTER",
            config[prefix .. "RelativePoint"] or "CENTER",
            math.max(1, Number(config[prefix .. "Width"], 80)),
            math.max(1, Number(config[prefix .. "Height"], 6)),
            Number(config[prefix .. "OffsetX"], 0),
            Number(config[prefix .. "OffsetY"], 0),
            prefix .. "-config"
        )
    end
    return {
        source = prefix .. "-match-target",
        points = {
            { point = "TOPLEFT", relativeTo = anchorTarget, relativePoint = "TOPLEFT", offsetX = 0, offsetY = 0 },
            { point = "BOTTOMRIGHT", relativeTo = anchorTarget, relativePoint = "BOTTOMRIGHT", offsetX = 0, offsetY = 0 },
        },
    }
end

local function ResolveFallback(frame, objectKey, spec, config)
    if objectKey == "PowerBar" then
        return ResolvePower(frame, config)
    elseif objectKey == "AlternativePowerBar" then
        return ResolveAlternativePower(frame, config)
    elseif objectKey == "CastBar" then
        return ResolveCast(frame, config)
    elseif objectKey == "ClassPowerBar" then
        return ResolveClassPower(frame, config)
    elseif spec.absorbPrefix then
        return ResolveAbsorb(frame, config, spec.absorbPrefix)
    end
    return FrameGeometry(frame, "frame-fallback")
end

function Resolver.Resolve(frame, objectRef)
    if not (frame and objectRef and objectRef.kind == "bar") then
        return nil
    end

    local objectKey = objectRef.objectKey
    local spec = objectKey and BAR_SPECS[objectKey]
    if not spec then
        return nil
    end

    local target = frame.Elements and frame.Elements[spec.elementKey] or nil
    local targetGeometry = FrameGeometry(target, "target-frame")
    if targetGeometry then
        return targetGeometry
    end

    return ResolveFallback(frame, objectKey, spec, frame.config or {})
end
