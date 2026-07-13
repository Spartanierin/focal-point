local _, FocalPoint = ...

FocalPoint.TextElementTemplates = FocalPoint.TextElementTemplates or {}

local Templates = FocalPoint.TextElementTemplates
local TemplateResolver = FocalPoint.TextTemplateResolver or {}

-- Template helpers keep state-template selection and plain token expansion
-- together without pulling the full text-application flow into one file.

local MAX_TEMPLATE_LENGTH = 512

local function NormalizeTemplateText(template)
    if type(template) ~= "string" then
        return ""
    end

    template = template:gsub("[%z\1-\8\11\12\14-\31]", "")
    if #template > MAX_TEMPLATE_LENGTH then
        template = template:sub(1, MAX_TEMPLATE_LENGTH)
    end

    return template
end

Templates.NormalizeTemplateText = NormalizeTemplateText

local function NormalizeResolvedTemplatePart(value, formatNumber)
    if value == nil then
        return ""
    end

    if type(value) == "string" then
        if issecretvalue and issecretvalue(value) then
            local okText, textValue = pcall(tostring, value)
            if okText and type(textValue) == "string" and not (issecretvalue and issecretvalue(textValue)) then
                return textValue
            end
            return ""
        end

        return value
    end

    local formatted = formatNumber and formatNumber(value) or value
    if type(formatted) == "string" then
        if issecretvalue and issecretvalue(formatted) then
            local okText, textValue = pcall(tostring, formatted)
            if okText and type(textValue) == "string" and not (issecretvalue and issecretvalue(textValue)) then
                return textValue
            end
            return ""
        end

        return formatted
    end

    local okText, textValue = pcall(tostring, formatted)
    if okText and type(textValue) == "string" and not (issecretvalue and issecretvalue(textValue)) then
        return textValue
    end

    return ""
end

function Templates.ResolveTextTemplate(frame, unit, template, deps)
    deps = deps or {}

    local ResolveBasicTag = deps.ResolveBasicTag
    local FormatNumber = deps.FormatNumber

    template = NormalizeTemplateText(template)
    if template == "" then
        return ""
    end

    local result = {}
    local cursor = 1

    while true do
        local startPos, endPos, token = template:find("%[([^%]]+)%]", cursor)
        if not startPos then
            result[#result + 1] = template:sub(cursor)
            break
        end

        if startPos > cursor then
            result[#result + 1] = template:sub(cursor, startPos - 1)
        end

        local resolved = ResolveBasicTag and ResolveBasicTag(frame, unit, token) or nil
        if resolved ~= nil then
            result[#result + 1] = NormalizeResolvedTemplatePart(resolved, FormatNumber)
        else
            result[#result + 1] = "[" .. token .. "]"
        end

        cursor = endPos + 1
    end

    return table.concat(result)
end

function Templates.ContainsToken(template, token)
    template = NormalizeTemplateText(template)
    if template == "" then
        return false
    end

    return template:find("%[" .. token:gsub("([^%w:])", "%%%1") .. "%]") ~= nil
end

function Templates.ResolveConfigured(frame, textConfig, deps)
    deps = deps or {}

    local GetLiveValue = deps.GetLiveValue
    local GetTemplate = deps.GetTemplate

    if type(textConfig) ~= "table" then
        return ""
    end

    local statusKey = GetLiveValue and GetLiveValue(frame, "statusKey", "") or ""
    return TemplateResolver.Resolve and TemplateResolver.Resolve(textConfig, statusKey, {
        GetTemplate = GetTemplate,
        NormalizeText = NormalizeTemplateText,
    }) or ""
end

function Templates.BuildPreview(template, deps)
    deps = deps or {}

    local GetTagPreviewFallback = deps.GetTagPreviewFallback

    template = NormalizeTemplateText(template)
    if template == "" then
        return ""
    end

    local parts = {}
    local searchStart = 1

    while true do
        local tokenStart, tokenEnd, token = template:find("%[([^%]]+)%]", searchStart)
        if not tokenStart then
            parts[#parts + 1] = template:sub(searchStart)
            break
        end

        if tokenStart > searchStart then
            parts[#parts + 1] = template:sub(searchStart, tokenStart - 1)
        end

        parts[#parts + 1] = GetTagPreviewFallback and GetTagPreviewFallback(token) or ("[" .. token .. "]")
        searchStart = tokenEnd + 1
    end

    return table.concat(parts)
end
