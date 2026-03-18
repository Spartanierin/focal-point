local _, FocalPoint = ...

FocalPoint.TextElementDirectTemplate = FocalPoint.TextElementDirectTemplate or {}

local DirectTemplate = FocalPoint.TextElementDirectTemplate

-- Applies simple bracket-token templates through SetFormattedText so the
-- caller can keep layout concerns separate from token resolution.
function DirectTemplate.Apply(frame, textObject, unit, template, fallbackColor, deps)
    deps = deps or {}

    local IsPreviewModeEnabled = deps.IsPreviewModeEnabled
    local ResolveColorTag = deps.ResolveColorTag
    local ResolveBasicTag = deps.ResolveBasicTag
    local FormatNumber = deps.FormatNumber

    if not frame or not textObject then
        return false
    end

    if not IsPreviewModeEnabled() and (not unit or not UnitExists or not UnitExists(unit)) then
        return false
    end

    local formatString = template and template:gsub("%%", "%%%%") or ""
    local formatArgs = {}
    local hasToken = false

    for token in template:gmatch("%[([^%]]+)%]") do
        local resolved = ResolveColorTag and ResolveColorTag(frame, unit, token, fallbackColor)
        if resolved == nil then
            resolved = ResolveBasicTag and ResolveBasicTag(frame, unit, token)
        end
        if resolved == nil then
            resolved = "[" .. token .. "]"
        elseif type(resolved) ~= "string" then
            resolved = FormatNumber and FormatNumber(resolved) or resolved
        end

        formatArgs[#formatArgs + 1] = resolved
        hasToken = true
    end

    if not hasToken then
        return false
    end

    formatString = formatString:gsub("%[([^%]]+)%]", "%%s")
    textObject:SetFormattedText(formatString, unpack(formatArgs))
    return true
end
