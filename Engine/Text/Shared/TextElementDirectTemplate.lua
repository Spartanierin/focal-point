local _, FocalPoint = ...

FocalPoint.TextElementDirectTemplate = FocalPoint.TextElementDirectTemplate or {}

local DirectTemplate = FocalPoint.TextElementDirectTemplate

local function IsSecretValue(value)
    return issecretvalue and issecretvalue(value)
end

local function IsEmptyTokenArgument(value)
    if value == nil then
        return true
    end
    if IsSecretValue(value) then
        return false
    end
    if type(value) == "string" then
        return value == ""
    end

    return false
end

local function WouldRenderOnlySeparators(template, formatArgs)
    local hasRenderableArgument = false
    for i = 1, #formatArgs do
        if not IsEmptyTokenArgument(formatArgs[i]) then
            hasRenderableArgument = true
            break
        end
    end
    if hasRenderableArgument then
        return false
    end

    local staticText = template:gsub("%[[^%]]+%]", "")
    staticText = staticText:gsub("%s+", "")

    return staticText == "" or staticText:match("^[%/%-%:%(%)%[%]%%]+$") ~= nil
end

-- Applies simple bracket-token templates through SetFormattedText so the
-- caller can keep layout concerns separate from token resolution.
function DirectTemplate.Apply(frame, textObject, unit, template, fallbackColor, deps)
    deps = deps or {}

    local IsPreviewModeEnabled = deps.IsPreviewModeEnabled
    local ResolveColorTag = deps.ResolveColorTag
    local ResolveBasicTag = deps.ResolveBasicTag
    local FormatNumber = deps.FormatNumber
    local NormalizeTemplateText = deps.NormalizeTemplateText

    if not frame or not textObject then
        return false
    end

    template = NormalizeTemplateText and NormalizeTemplateText(template) or (type(template) == "string" and template or "")
    if template == "" then
        return false
    end

    local previewMode = type(IsPreviewModeEnabled) == "function" and IsPreviewModeEnabled() or false
    if not previewMode and (not unit or not UnitExists or not UnitExists(unit)) then
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
    if WouldRenderOnlySeparators(template, formatArgs) then
        return true
    end

    local ok = pcall(function()
        textObject:SetFormattedText(formatString, unpack(formatArgs))
    end)

    if ok then
        return true
    end

    return false
end
