local _, FocalPoint = ...

FocalPoint.GUI = FocalPoint.GUI or {}
FocalPoint.GUI.Editor = FocalPoint.GUI.Editor or {}

local Resolver = {}
FocalPoint.GUI.Editor.SelectionGeometryResolver = Resolver

local Factory = FocalPoint.UnitFrameFactory or {}
local Decoration = FocalPoint.UnitFrameDecoration or {}
local AuraBlockLayout = FocalPoint.AuraBlockLayout or {}

local BAR_SPECS = {
    HealthBar = { elementKey = "HealthBar" },
    PowerBar = { elementKey = "PowerBar" },
    CastBar = { elementKey = "CastBar" },
    ClassPowerBar = { elementKey = "ClassPowerBar" },
    AlternativePowerBar = { elementKey = "AlternativePowerBar" },
    NormalAbsorbBar = { elementKey = "NormalAbsorbBar", absorbPrefix = "normalAbsorbBar" },
    HealingAbsorbBar = { elementKey = "HealingAbsorbBar", absorbPrefix = "healingAbsorbBar" },
}

local INDICATOR_SPECS = {
    Portrait = { elementKey = "Portrait", defaults = { enabled = false, size = 40, scale = 1, placement = "INSIDE", insideSide = "LEFT", insideAnchorTo = "Frame", point = "RIGHT", relativePoint = "LEFT", offsetX = -4, offsetY = 0, anchorTo = "Frame" } },
    RaidTargetIcon = { elementKey = "RaidTargetIcon", defaults = { size = 18, scale = 1, placement = "ATTACHED", insideSide = "RIGHT", insideAnchorTo = "Frame", point = "TOP", relativePoint = "TOP", offsetX = 0, offsetY = 8, anchorTo = "Frame", padding = 2 } },
    LeaderIcon = { elementKey = "LeaderIcon", defaults = { size = 16, scale = 1, placement = "ATTACHED", insideSide = "LEFT", insideAnchorTo = "Frame", point = "TOPLEFT", relativePoint = "TOP", offsetX = 0, offsetY = 0, anchorTo = "Frame", padding = 2 } },
    RoleIcon = { elementKey = "RoleIcon", defaults = { size = 16, scale = 1, placement = "ATTACHED", insideSide = "RIGHT", insideAnchorTo = "Frame", point = "TOPRIGHT", relativePoint = "TOP", offsetX = 0, offsetY = 0, anchorTo = "Frame", padding = 2 } },
    CombatIndicator = { elementKey = "CombatIndicator", defaults = { size = 16, scale = 1, placement = "ATTACHED", insideSide = "RIGHT", insideAnchorTo = "Frame", point = "TOP", relativePoint = "TOP", offsetX = 0, offsetY = 0, anchorTo = "Frame", padding = 2 } },
    RestingIndicator = { elementKey = "RestingIndicator", defaults = { size = 16, scale = 1, placement = "ATTACHED", insideSide = "LEFT", insideAnchorTo = "Frame", point = "TOPLEFT", relativePoint = "TOP", offsetX = 0, offsetY = 0, anchorTo = "Frame", padding = 2 } },
    ReadyCheckIndicator = { elementKey = "ReadyCheckIndicator", defaults = { size = 16, scale = 1, placement = "ATTACHED", insideSide = "RIGHT", insideAnchorTo = "Frame", point = "TOPRIGHT", relativePoint = "TOP", offsetX = 0, offsetY = 0, anchorTo = "Frame", padding = 2 } },
    ClassificationIndicator = { elementKey = "ClassificationPortraitOverlay", defaults = { effect = "PORTRAIT_OVERLAY" } },
}

local VALID_DECORATION_POINTS = {
    TOPLEFT = true, TOP = true, TOPRIGHT = true,
    LEFT = true, CENTER = true, RIGHT = true,
    BOTTOMLEFT = true, BOTTOM = true, BOTTOMRIGHT = true,
}

local function Number(value, fallback)
    local parsed = tonumber(value)
    if parsed == nil then
        return fallback
    end
    return parsed
end

local function Enum(value, valid, fallback)
    if type(value) == "string" and valid[value] then
        return value
    end
    return fallback
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

local function AllPointsGeometry(relativeTo, source)
    if not relativeTo then
        return nil
    end
    return {
        source = source or "match-target",
        points = {
            { point = "TOPLEFT", relativeTo = relativeTo, relativePoint = "TOPLEFT", offsetX = 0, offsetY = 0 },
            { point = "BOTTOMRIGHT", relativeTo = relativeTo, relativePoint = "BOTTOMRIGHT", offsetX = 0, offsetY = 0 },
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
    return AllPointsGeometry(anchorTarget, prefix .. "-match-target")
end

local function ResolveBarFallback(frame, objectKey, spec, config)
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

local function ResolveBar(frame, objectRef, config)
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

    return ResolveBarFallback(frame, objectKey, spec, config)
end

local function MergeConfig(config, key, defaults)
    local result = {}
    for field, value in pairs(defaults or {}) do
        result[field] = value
    end
    local source = type(config) == "table" and config[key] or nil
    if type(source) == "table" then
        for field, value in pairs(source) do
            result[field] = value
        end
    end
    return result
end

local function ResolvePortrait(frame, config)
    local portrait = frame.Elements and frame.Elements.Portrait or nil
    local targetGeometry = FrameGeometry(portrait, "portrait-frame")
    if targetGeometry then
        return targetGeometry
    end

    local portraitConfig = MergeConfig(config, "Portrait", INDICATOR_SPECS.Portrait.defaults)
    local size = math.max(1, Number(portraitConfig.size, 40) * Number(portraitConfig.scale, 1))
    local placement = portraitConfig.placement or "INSIDE"
    local borderInset = Number(config and config.borderInset, 1)
    if placement == "INSIDE" then
        if portraitConfig.insideSide == "RIGHT" then
            return PointGeometry(frame, "RIGHT", "RIGHT", size, size, -borderInset, 0, "portrait-inside-config")
        end
        return PointGeometry(frame, "LEFT", "LEFT", size, size, borderInset, 0, "portrait-inside-config")
    end

    local anchorTarget = GetAnchorTarget(frame, portraitConfig.anchorTo or "Frame") or frame
    return PointGeometry(
        anchorTarget,
        portraitConfig.point or "RIGHT",
        portraitConfig.relativePoint or "LEFT",
        size,
        size,
        Number(portraitConfig.offsetX, -4),
        Number(portraitConfig.offsetY, 0),
        "portrait-config"
    )
end

local function ResolveInsideIndicator(frame, indicatorConfig, size, source)
    local borderInset = Number(frame.config and frame.config.borderInset, 1)
    local anchorTo = indicatorConfig.insideAnchorTo or "Frame"
    local anchorParent = frame
    if anchorTo == "HealthBar" and frame.Elements and frame.Elements.HealthBar then
        anchorParent = frame.Elements.HealthBar
    elseif anchorTo == "PowerBar" and frame.Elements and frame.Elements.PowerBar and HasGeometry(frame.Elements.PowerBar) then
        anchorParent = frame.Elements.PowerBar
    end

    if indicatorConfig.insideSide == "LEFT" then
        return PointGeometry(anchorParent, "TOPLEFT", "TOPLEFT", size, size, Number(indicatorConfig.padding, 2), -borderInset, source)
    end
    return PointGeometry(anchorParent, "TOPRIGHT", "TOPRIGHT", size, size, -Number(indicatorConfig.padding, 2), -borderInset, source)
end

local function ResolveClassification(frame, objectRef, config)
    local requestedElement = objectRef.elementKey
    local classificationConfig = MergeConfig(config, "ClassificationIndicator", INDICATOR_SPECS.ClassificationIndicator.defaults)
    local effect = classificationConfig.effect or "PORTRAIT_OVERLAY"
    local activeElement = effect == "CORNER_CREST" and "ClassificationCrest" or "ClassificationPortraitOverlay"
    if requestedElement and requestedElement ~= activeElement then
        return nil
    end

    local target = frame.Elements and frame.Elements[activeElement] or nil
    local targetGeometry = FrameGeometry(target, "classification-frame")
    if targetGeometry then
        return targetGeometry
    end

    if activeElement == "ClassificationCrest" then
        return PointGeometry(frame, "TOPRIGHT", "TOPRIGHT", 18, 18, 4, 4, "classification-crest-config")
    end

    local portrait = frame.Elements and frame.Elements.Portrait or nil
    local overlayTarget = HasGeometry(portrait) and portrait or frame
    return AllPointsGeometry(overlayTarget, "classification-portrait-overlay-config")
end

local function ResolveIndicator(frame, objectRef, config)
    local indicatorKey = objectRef.indicatorKey or objectRef.objectKey
    if indicatorKey == "Portrait" then
        return ResolvePortrait(frame, config)
    end
    if indicatorKey == "ClassificationIndicator" then
        return ResolveClassification(frame, objectRef, config)
    end

    local spec = indicatorKey and INDICATOR_SPECS[indicatorKey]
    if not spec then
        return nil
    end

    local holder = frame.Elements and frame.Elements[spec.elementKey] or nil
    local holderGeometry = FrameGeometry(holder, "indicator-frame")
    if holderGeometry then
        return holderGeometry
    end

    local indicatorConfig = MergeConfig(config, indicatorKey, spec.defaults)
    if indicatorConfig.effect == "FRAME_OVERLAY" then
        return FrameGeometry(frame, indicatorKey .. "-frame-overlay")
    end

    local size = math.max(1, Number(indicatorConfig.size, spec.defaults.size or 16) * Number(indicatorConfig.scale, spec.defaults.scale or 1))
    if indicatorConfig.placement == "INSIDE" then
        return ResolveInsideIndicator(frame, indicatorConfig, size, indicatorKey .. "-inside-config")
    end

    local anchorTarget = GetAnchorTarget(frame, indicatorConfig.anchorTo or "Frame") or frame
    return PointGeometry(
        anchorTarget,
        indicatorConfig.point or "CENTER",
        indicatorConfig.relativePoint or "CENTER",
        size,
        size,
        Number(indicatorConfig.offsetX, 0),
        Number(indicatorConfig.offsetY, 0),
        indicatorKey .. "-config"
    )
end

local function FindDecorationConfig(config, decorationId)
    local decorations = type(config) == "table" and config.decorations or nil
    if type(decorations) ~= "table" then
        return nil
    end
    for index, decoration in ipairs(decorations) do
        if type(decoration) == "table" and decoration.id == decorationId then
            if Decoration.NormalizeDecoration then
                return Decoration.NormalizeDecoration(decoration, index)
            end
            return decoration
        end
    end
    return nil
end

local function ResolveDecoration(frame, objectRef, config)
    local decorationId = objectRef.decorationId or objectRef.objectKey
    if type(decorationId) ~= "string" or decorationId == "" then
        return nil
    end

    local entry = frame.DecorationIndicators and frame.DecorationIndicators[decorationId] or nil
    local holderGeometry = FrameGeometry(entry and entry.holder, "decoration-frame")
    if holderGeometry then
        return holderGeometry
    end

    local decorationConfig = FindDecorationConfig(config, decorationId)
    if type(decorationConfig) ~= "table" then
        return nil
    end

    local target = frame
    if decorationConfig.target == "PORTRAIT" then
        local portrait = frame.Elements and frame.Elements.Portrait or nil
        target = HasGeometry(portrait) and portrait or frame
    end

    return PointGeometry(
        target,
        Enum(decorationConfig.point, VALID_DECORATION_POINTS, "CENTER"),
        Enum(decorationConfig.relativePoint, VALID_DECORATION_POINTS, "CENTER"),
        math.max(1, Number(decorationConfig.width, 64)),
        math.max(1, Number(decorationConfig.height, 64)),
        Number(decorationConfig.offsetX, 0),
        Number(decorationConfig.offsetY, 0),
        "decoration-config"
    )
end

local function ResolveAura(frame, objectRef, config)
    local auraKey = objectRef.auraKey or objectRef.objectKey
    local auraConfig = auraKey and config[auraKey] or nil
    if type(auraConfig) ~= "table" then
        return nil
    end

    local metrics = AuraBlockLayout.ResolveEditorMetrics and AuraBlockLayout.ResolveEditorMetrics(auraConfig) or nil
    local groupFrame = frame.Elements and frame.Elements[auraKey] or nil
    local width = Number(metrics and metrics.blockWidth, 0)
    local height = Number(metrics and metrics.blockHeight, 0)
    if width <= 0 or height <= 0 then
        return FrameGeometry(groupFrame, "aura-frame")
    end

    local anchorTarget = AuraBlockLayout.ResolveAnchorTarget
        and AuraBlockLayout.ResolveAnchorTarget(frame, auraConfig, auraKey)
        or frame
    local offsetX, offsetY
    if AuraBlockLayout.ResolveAnchorOffsets then
        offsetX, offsetY = AuraBlockLayout.ResolveAnchorOffsets(auraConfig, frame, auraKey)
    else
        offsetX = Number(auraConfig.offsetX, 0)
        offsetY = Number(auraConfig.offsetY, 0)
    end

    return PointGeometry(
        anchorTarget or frame,
        auraConfig.point or "TOPLEFT",
        auraConfig.relativePoint or auraConfig.point or "TOPLEFT",
        width,
        height,
        offsetX,
        offsetY,
        "aura-layout-config"
    )
end

function Resolver.Resolve(frame, objectRef)
    if not (frame and objectRef) then
        return nil
    end

    local config = frame.config or {}
    if objectRef.kind == "bar" then
        return ResolveBar(frame, objectRef, config)
    elseif objectRef.kind == "indicator" then
        return ResolveIndicator(frame, objectRef, config)
    elseif objectRef.kind == "decoration" then
        return ResolveDecoration(frame, objectRef, config)
    elseif objectRef.kind == "aura" then
        return ResolveAura(frame, objectRef, config)
    end

    return nil
end
