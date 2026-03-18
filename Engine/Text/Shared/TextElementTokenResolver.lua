local _, FocalPoint = ...

FocalPoint.TextElementTokenResolver = FocalPoint.TextElementTokenResolver or {}

local TokenResolver = FocalPoint.TextElementTokenResolver

-- Resolves the simple token definition table after color tags have already
-- had a chance to short-circuit the request.
function TokenResolver.Resolve(frame, unit, token, deps)
    deps = deps or {}

    local IsPreviewModeEnabled = deps.IsPreviewModeEnabled
    local ResolveColorTag = deps.ResolveColorTag
    local TokenDefinitions = deps.TokenDefinitions or {}
    local FormatNumber = deps.FormatNumber

    if not IsPreviewModeEnabled() and (not unit or not UnitExists or not UnitExists(unit)) then
        local colorToken = ResolveColorTag and ResolveColorTag(frame, unit, token)
        if colorToken ~= nil then
            return colorToken
        end
        return ""
    end

    local colorToken = ResolveColorTag and ResolveColorTag(frame, unit, token)
    if colorToken ~= nil then
        return colorToken
    end

    local def = TokenDefinitions[token]
    if not def then
        return nil
    end

    local value = def.value and def.value(unit, frame) or nil
    local formatter = def.format or FormatNumber
    return formatter and formatter(value) or value
end
