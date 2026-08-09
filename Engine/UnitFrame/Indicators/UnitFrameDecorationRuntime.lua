local _, FocalPoint = ...

FocalPoint.UnitFrameDecorationRuntime = FocalPoint.UnitFrameDecorationRuntime or {}
local Runtime = FocalPoint.UnitFrameDecorationRuntime

local Decoration = FocalPoint.UnitFrameDecoration or {}
local VisualIndicator = FocalPoint.UnitFrameVisualIndicator or {}
local MEDIA_TYPE_DECORATION = "decoration"
local DEFAULT_DECORATION_REFERENCE = "fp:decoration:shadow1"

-- First decoration runtime slice. Persistent product data lives on the unit
-- config; frame-local test data remains available for isolated diagnostics.

local function SanitizeId(id)
    id = type(id) == "string" and id or "decoration"
    local sanitized = id:gsub("[^%w_%-]", "_")
    if sanitized == "" then
        sanitized = "decoration"
    end
    return sanitized
end

local function GetRegistry(frame)
    if not frame then
        return nil
    end

    frame.DecorationIndicators = frame.DecorationIndicators or {}
    return frame.DecorationIndicators
end

local function EnsureHolder(frame, decoration)
    local registry = GetRegistry(frame)
    if not registry or not decoration then
        return nil
    end

    local id = decoration.id
    local entry = registry[id]
    if entry and entry.holder then
        return entry.holder, entry
    end

    local elementKey = "DecorationIndicator_" .. SanitizeId(id)
    local holder = VisualIndicator.CreateHolder and VisualIndicator.CreateHolder(frame, elementKey, {
        frameLevelOffset = 28,
        textureLayer = "OVERLAY",
        textureSubLevel = 7,
    })
    if not holder then
        return nil
    end

    entry = {
        holder = holder,
        elementKey = elementKey,
    }
    registry[id] = entry

    return holder, entry
end

local function HideEntry(entry)
    if entry and entry.holder and VisualIndicator.Hide then
        VisualIndicator.Hide(entry.holder)
    elseif entry and entry.holder then
        entry.holder:Hide()
    end
end

local function HideStaleEntries(frame, activeIds)
    local registry = frame and frame.DecorationIndicators
    if type(registry) ~= "table" then
        return
    end

    for id, entry in pairs(registry) do
        if not activeIds[id] then
            HideEntry(entry)
        end
    end
end

local function ResolveDecorationTexture(reference)
    local MediaRegistry = FocalPoint.MediaRegistry
    if MediaRegistry and type(MediaRegistry.ResolveReference) == "function" then
        local result = MediaRegistry.ResolveReference(reference, MEDIA_TYPE_DECORATION, DEFAULT_DECORATION_REFERENCE)
        if result and type(result.resolvedAsset) == "string" and result.resolvedAsset ~= "" then
            return result.resolvedAsset
        end
    end

    return type(reference) == "string" and reference ~= "" and reference or nil
end

function Runtime.GetTestDecorations(frame)
    if not frame or type(frame.FocalPointDecorationTestConfig) ~= "table" then
        return {}
    end

    return frame.FocalPointDecorationTestConfig
end

function Runtime.GetDecorations(frame)
    local decorations = frame
        and frame.config
        and frame.config.decorations
        or nil
    if type(decorations) == "table" then
        return decorations
    end

    return Runtime.GetTestDecorations(frame)
end

function Runtime.SetTestDecorations(frame, decorations)
    if not frame then
        return false
    end

    if type(decorations) == "table" then
        frame.FocalPointDecorationTestConfig = decorations
    else
        frame.FocalPointDecorationTestConfig = nil
    end

    return true
end

function Runtime.Apply(frame, decorations, context)
    if not frame or type(Decoration.NormalizeDecorationList) ~= "function" then
        return
    end

    local normalized = Decoration.NormalizeDecorationList(decorations or Runtime.GetDecorations(frame))
    local activeIds = {}

    for _, decoration in ipairs(normalized) do
        activeIds[decoration.id] = true

        local holder = EnsureHolder(frame, decoration)
        local visual = holder and VisualIndicator.ResetHolderVisual and VisualIndicator.ResetHolderVisual(holder, frame) or nil
        local texture = holder and holder.Texture or nil
        local target = Decoration.ResolveTarget and Decoration.ResolveTarget(frame, decoration) or nil
        local conditionOk = Decoration.ResolveCondition and Decoration.ResolveCondition(frame, decoration, context) or false
        local texturePath = ResolveDecorationTexture(decoration.texture)

        if not holder or not visual or not texture or not decoration.enabled or not texturePath or not target or not conditionOk then
            if holder then
                VisualIndicator.Hide(holder)
            end
        else
            if VisualIndicator.ApplyFrameLayer then
                VisualIndicator.ApplyFrameLayer(holder, frame, { frameLevelOffset = 28, healthFrameLevelOffset = 18 })
            end
            if VisualIndicator.ApplyRectBounds then
                VisualIndicator.ApplyRectBounds(holder, visual, decoration.width, decoration.height)
            else
                holder:SetSize(decoration.width, decoration.height)
                visual:SetAllPoints(holder)
            end
            if VisualIndicator.ApplyAnchor then
                VisualIndicator.ApplyAnchor(holder, target, decoration.point, decoration.relativePoint, decoration.offsetX, decoration.offsetY)
            else
                holder:SetPoint(decoration.point, target, decoration.relativePoint, decoration.offsetX, decoration.offsetY)
            end
            if VisualIndicator.ApplyAlpha then
                VisualIndicator.ApplyAlpha(holder, decoration.alpha)
            else
                holder:SetAlpha(decoration.alpha)
            end

            texture:SetTexture(texturePath)
            texture:SetTexCoord(0, 1, 0, 1)
            VisualIndicator.Show(holder)
        end
    end

    HideStaleEntries(frame, activeIds)
end

FocalPoint.UnitFrameDecoration = Decoration
Decoration.SetTestDecorations = Runtime.SetTestDecorations
Decoration.GetTestDecorations = Runtime.GetTestDecorations
Decoration.GetDecorations = Runtime.GetDecorations
Decoration.ApplyTestDecorations = Runtime.Apply
