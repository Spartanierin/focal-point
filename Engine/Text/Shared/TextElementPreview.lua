local _, FocalPoint = ...

FocalPoint.TextElementPreview = FocalPoint.TextElementPreview or {}

local Preview = FocalPoint.TextElementPreview
local Templates = FocalPoint.TextElementTemplates or {}
local TemplateResolver = FocalPoint.TextTemplateResolver or {}
local Roles = FocalPoint.TextElementRoles or {}
local UnitUtils = FocalPoint.UnitFrameUtils or {}

local FALLBACK_BY_ROLE = {
    name = "[Name]",
    health = "[Health]",
    power = "[Power]",
    altpower = "[Alt Power]",
    classpower = "[Class Power]",
    level = "[Level]",
    class = "[Class]",
    cast_name = "[Cast]",
    cast_time = "[Cast Time]",
}

local DEFAULT_FALLBACK = "[Text]"

local function NormalizeUnitKey(unitKey)
    if UnitUtils.NormalizeConfigUnitKey then
        return UnitUtils.NormalizeConfigUnitKey(unitKey)
    end
    if type(unitKey) == "string" and unitKey:match("^boss%d+$") then
        return "boss"
    end
    return unitKey
end

local function IsNonEmptyString(value)
    return type(value) == "string" and value ~= ""
end

local function NormalizeTemplateText(template)
    if Templates.NormalizeTemplateText then
        return Templates.NormalizeTemplateText(template)
    end
    return type(template) == "string" and template or ""
end

local function GetTagDatabase()
    local unitFrame = FocalPoint and FocalPoint.UnitFrame
    if unitFrame and unitFrame.GetTagDatabase then
        return unitFrame:GetTagDatabase()
    end
    return nil
end

local function GetTagPreviewFallback(token)
    local previewFrame = {
        IsTemplatePreview = true,
        TestValues = {
            classToken = "WARRIOR",
            powerToken = "RAGE",
            reaction = 5,
        },
    }

    local colors = FocalPoint.TextElementColors or {}
    local colorToken = colors.ResolveColorTag and colors.ResolveColorTag(previewFrame, "player", token) or nil
    if type(colorToken) == "string" then
        return colorToken
    end

    local tagDatabase = GetTagDatabase()
    if type(tagDatabase) == "table" then
        local tokenText = "[" .. tostring(token or "") .. "]"
        for _, def in ipairs(tagDatabase) do
            if type(def) == "table" and def.token == tokenText then
                return def.example or tokenText
            end
        end
    end

    return "[" .. tostring(token or "") .. "]"
end

local function GetActiveProfileTemplate(templateName)
    if not IsNonEmptyString(templateName) then
        return nil
    end

    local templates = UnitUtils.GetTextTemplatesDB and UnitUtils.GetTextTemplatesDB() or nil
    if type(templates) == "table" then
        return templates[templateName]
    end
    return nil
end

function Preview.BuildTemplatePreview(template)
    template = NormalizeTemplateText(template)
    if template == "" then
        return ""
    end

    if Templates.BuildPreview then
        return Templates.BuildPreview(template, {
            GetTagPreviewFallback = GetTagPreviewFallback,
        })
    end

    return template
end

function Preview.ResolveConfiguredTemplate(textConfig, state)
    if type(textConfig) ~= "table" then
        return ""
    end

    if TemplateResolver.Resolve then
        return TemplateResolver.Resolve(textConfig, state or "", {
            GetTemplate = GetActiveProfileTemplate,
            NormalizeText = NormalizeTemplateText,
        })
    end

    return NormalizeTemplateText(textConfig.tag)
end

function Preview.BuildTextElementPreview(textConfig, options)
    options = type(options) == "table" and options or {}
    if type(textConfig) ~= "table" then
        return DEFAULT_FALLBACK
    end

    local template = options.template
    if not IsNonEmptyString(template) then
        template = Preview.ResolveConfiguredTemplate(textConfig, options.state)
    end

    local previewText = Preview.BuildTemplatePreview(template)
    if IsNonEmptyString(previewText) then
        return previewText
    end

    local textRole = options.textRole
    if not IsNonEmptyString(textRole) and Roles.Resolve then
        textRole = Roles.Resolve(options.textKey, textConfig)
    end

    return FALLBACK_BY_ROLE[textRole] or DEFAULT_FALLBACK
end

function Preview.NormalizeUnitKey(unitKey)
    return NormalizeUnitKey(unitKey)
end

return Preview
