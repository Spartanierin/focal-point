local _, FocalPoint = ...

FocalPoint.UnitFrameDecoration = FocalPoint.UnitFrameDecoration or {}
local Decoration = FocalPoint.UnitFrameDecoration

-- Passive decoration schema/resolver. Rendering and persistence are intentionally
-- handled by later work packages.

local VALID_TARGETS = {
    FRAME = true,
    PORTRAIT = true,
}

local VALID_CONDITIONS = {
    ALWAYS = true,
    ELITE = true,
    RARE = true,
    RAREELITE = true,
    BOSS = true,
}

local CLASSIFICATION_BY_CONDITION = {
    ELITE = {
        elite = true,
    },
    RARE = {
        rare = true,
    },
    RAREELITE = {
        rareelite = true,
    },
    BOSS = {
        worldboss = true,
    },
}

local function NormalizeEnum(value, validValues, fallback)
    if type(value) ~= "string" then
        return fallback
    end

    local normalized = value:upper()
    return validValues[normalized] and normalized or fallback
end

local function NormalizeNumber(value, fallback, minimum, maximum)
    local numberValue = tonumber(value)
    if not numberValue then
        return fallback
    end
    if minimum and numberValue < minimum then
        numberValue = minimum
    end
    if maximum and numberValue > maximum then
        numberValue = maximum
    end
    return numberValue
end

local function NormalizeId(value, fallback)
    if type(value) == "string" and value ~= "" then
        return value
    end
    return fallback
end

local function NormalizeClassificationKind(value)
    if type(value) ~= "string" or value == "" then
        return nil
    end

    local normalized = value:lower():gsub("[_%s%-]+", "")
    if normalized == "boss" or normalized == "worldboss" then
        return "worldboss"
    elseif normalized == "elite" then
        return "elite"
    elseif normalized == "rareelite" then
        return "rareelite"
    elseif normalized == "rare" then
        return "rare"
    end

    return nil
end

function Decoration.NormalizeDecoration(decoration, index)
    if type(decoration) ~= "table" then
        return nil
    end

    local fallbackId = string.format("decoration%d", tonumber(index) or 1)
    return {
        id = NormalizeId(decoration.id, fallbackId),
        enabled = decoration.enabled ~= false,
        texture = type(decoration.texture) == "string" and decoration.texture or nil,
        target = NormalizeEnum(decoration.target, VALID_TARGETS, "FRAME"),
        point = NormalizeEnum(decoration.point, {
            TOPLEFT = true, TOP = true, TOPRIGHT = true,
            LEFT = true, CENTER = true, RIGHT = true,
            BOTTOMLEFT = true, BOTTOM = true, BOTTOMRIGHT = true,
        }, "CENTER"),
        relativePoint = NormalizeEnum(decoration.relativePoint, {
            TOPLEFT = true, TOP = true, TOPRIGHT = true,
            LEFT = true, CENTER = true, RIGHT = true,
            BOTTOMLEFT = true, BOTTOM = true, BOTTOMRIGHT = true,
        }, "CENTER"),
        offsetX = NormalizeNumber(decoration.offsetX, 0),
        offsetY = NormalizeNumber(decoration.offsetY, 0),
        width = NormalizeNumber(decoration.width, 64, 1),
        height = NormalizeNumber(decoration.height, 64, 1),
        alpha = NormalizeNumber(decoration.alpha, 1, 0, 1),
        condition = NormalizeEnum(decoration.condition, VALID_CONDITIONS, "ALWAYS"),
    }
end

function Decoration.NormalizeDecorationList(decorations)
    if type(decorations) ~= "table" then
        return {}
    end

    local normalized = {}
    local seenIds = {}
    for index, decoration in ipairs(decorations) do
        local item = Decoration.NormalizeDecoration(decoration, index)
        if item then
            local baseId = item.id
            local uniqueId = baseId
            local duplicateIndex = 2
            while seenIds[uniqueId] do
                uniqueId = string.format("%s-%d", baseId, duplicateIndex)
                duplicateIndex = duplicateIndex + 1
            end
            item.id = uniqueId
            seenIds[uniqueId] = true
            normalized[#normalized + 1] = item
        end
    end

    return normalized
end

function Decoration.ResolveTarget(frame, decoration)
    if not frame then
        return nil
    end

    local normalized = Decoration.NormalizeDecoration(decoration or {}, 1)
    local target = normalized and normalized.target or "FRAME"

    if target == "FRAME" then
        return frame
    elseif target == "PORTRAIT" then
        local portrait = frame.Elements and frame.Elements.Portrait or nil
        local portraitConfig = frame.config and frame.config.Portrait or nil
        if portrait and portraitConfig and portraitConfig.enabled ~= false and portrait.IsShown and portrait:IsShown() then
            return portrait
        end
    end

    return nil
end

local function ResolveContextClassification(context)
    if type(context) ~= "table" then
        return nil
    end

    return NormalizeClassificationKind(context.classificationKind)
        or NormalizeClassificationKind(context.classification)
end

local function ResolveDemoClassification(frame, context)
    local Demo = FocalPoint.UnitFrameDemoEnvironment
    if type(Demo) ~= "table" or type(Demo.ResolveMode) ~= "function" then
        return nil
    end

    local mode = context and context.mode or Demo.ResolveMode(frame, "decoration")
    if mode == "live" or mode == "disabled" then
        return nil
    end

    if type(Demo.GetPreviewClassificationKind) == "function" then
        local classification = NormalizeClassificationKind(Demo.GetPreviewClassificationKind(frame, mode))
        if classification then
            return classification
        end
    end

    if type(Demo.GetUnitValues) == "function" then
        local values = Demo.GetUnitValues(frame, mode)
        return NormalizeClassificationKind(values and values.classificationKind)
            or NormalizeClassificationKind(values and values.classification)
    end

    return nil
end

local function ResolveLiveClassification(frame)
    local Status = FocalPoint.TextElementStatus
    if type(Status) == "table" and type(Status.GetUnitClassificationKind) == "function" then
        return Status.GetUnitClassificationKind(frame and frame.unit)
    end
    return nil
end

function Decoration.ResolveCondition(frame, decoration, context)
    local normalized = Decoration.NormalizeDecoration(decoration or {}, 1)
    local condition = normalized and normalized.condition or "ALWAYS"

    if condition == "ALWAYS" then
        return true
    end

    local Demo = FocalPoint.UnitFrameDemoEnvironment
    local mode = context and context.mode or (type(Demo) == "table" and type(Demo.ResolveMode) == "function" and Demo.ResolveMode(frame, "decoration") or nil)
    if type(Demo) == "table" and type(Demo.ShouldBypassDecorationConditions) == "function" and Demo.ShouldBypassDecorationConditions(frame, mode) then
        return true
    end

    local classification = ResolveContextClassification(context)
        or ResolveDemoClassification(frame, context)
        or ResolveLiveClassification(frame)
    local expected = CLASSIFICATION_BY_CONDITION[condition]

    return expected and expected[classification] == true or false
end

Decoration.ValidTargets = VALID_TARGETS
Decoration.ValidConditions = VALID_CONDITIONS
