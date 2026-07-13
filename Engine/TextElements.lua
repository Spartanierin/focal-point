local _, FocalPoint = ...

FocalPoint.UnitFrame = FocalPoint.UnitFrame or {}
local UF = FocalPoint.UnitFrame

-- Shared text modules.
local TextUtils = FocalPoint.TextElementUtils or {}
local TextStatus = FocalPoint.TextElementStatus or {}
local TextColors = FocalPoint.TextElementColors or {}
local TextPower = FocalPoint.TextElementPower or {}
local TextBasicTags = FocalPoint.TextElementBasicTags or {}
local TextTokenResolver = FocalPoint.TextElementTokenResolver or {}
local TextTemplates = FocalPoint.TextElementTemplates or {}
local TextDirectTemplate = FocalPoint.TextElementDirectTemplate or {}
local TextFactory = FocalPoint.TextElementFactory or {}
local TextUpdate = FocalPoint.TextElementUpdate or {}
local TextEvents = FocalPoint.TextElementEvents or {}
local TextApply = FocalPoint.TextElementApply or {}
local TextLiveValues = FocalPoint.TextElementLiveValues or {}
local UnitUtils = FocalPoint.UnitFrameUtils or {}

-- Shared utility aliases.
local IsPreviewModeEnabled = TextUtils.IsPreviewModeEnabled
local UnpackColor = TextUtils.UnpackColor
local GetFontPath = TextUtils.GetFontPath
local BuildFontFlags = TextUtils.BuildFontFlags
local FormatNumber = TextUtils.FormatNumber
local FormatTextValue = TextUtils.FormatTextValue
local FormatTimeValue = TextUtils.FormatTimeValue
local IsSafeTrue = TextUtils.IsSafeTrue
local ToSafeNumber = TextUtils.ToSafeNumber

-- Shared status/tag resolver aliases.
local GetLocalizedClassName = TextStatus.GetLocalizedClassName
local GetClassificationText = TextStatus.GetClassificationText
local GetRoleText = TextStatus.GetRoleText
local GetGhostText = TextStatus.GetGhostText
local GetDeadText = TextStatus.GetDeadText
local GetOfflineText = TextStatus.GetOfflineText
local GetCombatText = TextStatus.GetCombatText
local GetRestingText = TextStatus.GetRestingText
local GetLeaderText = TextStatus.GetLeaderText
local GetStatusText = TextStatus.GetStatusText
local GetResolvedUnitName = TextStatus.GetResolvedUnitName
local FormatStatusTimerValue = TextStatus.FormatStatusTimerValue
local GetCurrentStatusInfo = TextStatus.GetCurrentStatusInfo

-- Shared color resolver aliases.
local GetClassTextColor = TextColors.GetClassTextColor
local ResolveColorTag = TextColors.ResolveColorTag

-- Shared live-value aliases.
local GetLiveValue = TextPower.GetLiveValue
local GetSecondaryPowerDisplayValues = TextPower.GetSecondaryPowerDisplayValues

-- Orchestrator aliases for extracted modules.
local ResolveBasicTagShared = TextBasicTags.Resolve
local ResolveTokenShared = TextTokenResolver.Resolve
local ResolveTextTemplateShared = TextTemplates.ResolveTextTemplate
local TemplateContainsTokenShared = TextTemplates.ContainsToken
local ResolveConfiguredTemplateShared = TextTemplates.ResolveConfigured
local BuildTemplatePreviewShared = TextTemplates.BuildPreview
local NormalizeTemplateTextShared = TextTemplates.NormalizeTemplateText
local ApplyDirectTemplateShared = TextDirectTemplate.Apply
local CreateTextElementShared = TextFactory.CreateElement
local CreateTextElementsShared = TextFactory.CreateAll
local UpdateTextElementShared = TextUpdate.UpdateElement
local UpdateTextElementsShared = TextUpdate.UpdateAll
local RegisterTextEventsShared = TextEvents.Register
local ApplyTextElementConfigShared = TextApply.ApplyElementConfig
local ApplyTestTextValuesShared = TextApply.ApplyTestValues
local RefreshLiveValues = TextLiveValues.Refresh

-- Keeps font strings above the main unit frame layers.
local function GetTextLayerParent(frame)
    if not frame then
        return nil
    end

    if frame.TextLayerParent then
        return frame.TextLayerParent
    end

    local holder = CreateFrame("Frame", nil, frame)
    holder:SetAllPoints(frame)
    holder:SetFrameStrata(frame:GetFrameStrata())
    holder:SetFrameLevel(frame:GetFrameLevel() + 30)

    frame.TextLayerParent = holder
    return holder
end

function UF:RefreshLiveValues(frame)
    return RefreshLiveValues(frame)
end

-- Simple token definitions that map directly to cached live values.
local TOKEN_DEFS = {
    ["hp:cur"] = {
        value = function(unit, frame)
            return GetLiveValue(frame, "healthCurrentText", GetLiveValue(frame, "healthCurrentRaw", "0"))
        end,
        format = FormatTextValue,
        direct = true,
    },
    ["hp:max"] = {
        value = function(unit, frame)
            return GetLiveValue(frame, "healthMaxText", GetLiveValue(frame, "healthMaxRaw", "0"))
        end,
        format = FormatTextValue,
        direct = true,
    },
    ["hp:cur:abbr"] = {
        value = function(unit, frame)
            return GetLiveValue(frame, "healthCurrentAbbr", "")
        end,
        format = FormatTextValue,
        direct = true,
    },
    ["hp:cur:short"] = {
        value = function(unit, frame)
            return GetLiveValue(frame, "healthCurrentAbbr", "")
        end,
        format = FormatTextValue,
        direct = true,
    },
    ["hp:max:abbr"] = {
        value = function(unit, frame)
            return GetLiveValue(frame, "healthMaxAbbr", "")
        end,
        format = FormatTextValue,
        direct = true,
    },
    ["hp:max:short"] = {
        value = function(unit, frame)
            return GetLiveValue(frame, "healthMaxAbbr", "")
        end,
        format = FormatTextValue,
        direct = true,
    },
    ["hp:perc"] = {
        value = function(unit, frame)
            return GetLiveValue(frame, "healthPercentText", "0")
        end,
        format = FormatTextValue,
        direct = true,
    },
    ["power:cur"] = {
        value = function(unit, frame)
            return GetLiveValue(frame, "powerCurrentText", GetLiveValue(frame, "powerCurrentRaw", "0"))
        end,
        format = FormatTextValue,
        direct = true,
    },
    ["power:max"] = {
        value = function(unit, frame)
            return GetLiveValue(frame, "powerMaxText", GetLiveValue(frame, "powerMaxRaw", "0"))
        end,
        format = FormatTextValue,
        direct = true,
    },
    ["power:perc"] = {
        value = function(unit, frame)
            return GetLiveValue(frame, "powerPercentText", "0")
        end,
        format = FormatTextValue,
        direct = true,
    },
    ["power:cur:abbr"] = {
        value = function(unit, frame)
            return GetLiveValue(frame, "powerCurrentAbbr", "")
        end,
        format = FormatTextValue,
        direct = true,
    },
    ["power:cur:short"] = {
        value = function(unit, frame)
            return GetLiveValue(frame, "powerCurrentAbbr", "")
        end,
        format = FormatTextValue,
        direct = true,
    },
    ["power:max:abbr"] = {
        value = function(unit, frame)
            return GetLiveValue(frame, "powerMaxAbbr", "")
        end,
        format = FormatTextValue,
        direct = true,
    },
    ["power:max:short"] = {
        value = function(unit, frame)
            return GetLiveValue(frame, "powerMaxAbbr", "")
        end,
        format = FormatTextValue,
        direct = true,
    },
    ["altpower:cur"] = {
        value = function(unit, frame)
            return GetLiveValue(frame, "altPowerCurrentText", GetLiveValue(frame, "altPowerCurrentRaw", "0"))
        end,
        format = FormatTextValue,
        direct = true,
    },
    ["altPower:cur"] = {
        value = function(unit, frame)
            return GetLiveValue(frame, "altPowerCurrentText", GetLiveValue(frame, "altPowerCurrentRaw", "0"))
        end,
        format = FormatTextValue,
        direct = true,
    },
    ["altpower:max"] = {
        value = function(unit, frame)
            return GetLiveValue(frame, "altPowerMaxText", GetLiveValue(frame, "altPowerMaxRaw", "0"))
        end,
        format = FormatTextValue,
        direct = true,
    },
    ["altPower:max"] = {
        value = function(unit, frame)
            return GetLiveValue(frame, "altPowerMaxText", GetLiveValue(frame, "altPowerMaxRaw", "0"))
        end,
        format = FormatTextValue,
        direct = true,
    },
    ["altpower:cur:abbr"] = {
        value = function(unit, frame)
            return GetLiveValue(frame, "altPowerCurrentAbbr", "")
        end,
        format = FormatTextValue,
        direct = true,
    },
    ["altpower:max:abbr"] = {
        value = function(unit, frame)
            return GetLiveValue(frame, "altPowerMaxAbbr", "")
        end,
        format = FormatTextValue,
        direct = true,
    },
    ["classpower:cur"] = {
        value = function(unit, frame)
            return GetLiveValue(frame, "classPowerCurrentText", GetLiveValue(frame, "classPowerCurrentRaw", "0"))
        end,
        format = FormatTextValue,
        direct = true,
    },
    ["classpower:max"] = {
        value = function(unit, frame)
            return GetLiveValue(frame, "classPowerMaxText", GetLiveValue(frame, "classPowerMaxRaw", "0"))
        end,
        format = FormatTextValue,
        direct = true,
    },
    ["classpower:cur:abbr"] = {
        value = function(unit, frame)
            return GetLiveValue(frame, "classPowerCurrentAbbr", "")
        end,
        format = FormatTextValue,
        direct = true,
    },
    ["classpower:max:abbr"] = {
        value = function(unit, frame)
            return GetLiveValue(frame, "classPowerMaxAbbr", "")
        end,
        format = FormatTextValue,
        direct = true,
    },
    ["curhp"] = {
        value = function(unit, frame)
            return GetLiveValue(frame, "healthCurrentText", GetLiveValue(frame, "healthCurrentRaw", "0"))
        end,
        format = FormatTextValue,
        direct = true,
    },
    ["maxhp"] = {
        value = function(unit, frame)
            return GetLiveValue(frame, "healthMaxText", GetLiveValue(frame, "healthMaxRaw", "0"))
        end,
        format = FormatTextValue,
        direct = true,
    },
    ["curhp:abbr"] = {
        value = function(unit, frame)
            return GetLiveValue(frame, "healthCurrentAbbr", "")
        end,
        format = FormatTextValue,
        direct = true,
    },
    ["maxhp:abbr"] = {
        value = function(unit, frame)
            return GetLiveValue(frame, "healthMaxAbbr", "")
        end,
        format = FormatTextValue,
        direct = true,
    },
    ["perhp"] = {
        value = function(unit, frame)
            return GetLiveValue(frame, "healthPercentText", "0")
        end,
        format = FormatTextValue,
        direct = true,
    },
    ["curpp"] = {
        value = function(unit, frame)
            return GetLiveValue(frame, "powerCurrentText", GetLiveValue(frame, "powerCurrentRaw", "0"))
        end,
        format = FormatTextValue,
        direct = true,
    },
    ["maxpp"] = {
        value = function(unit, frame)
            return GetLiveValue(frame, "powerMaxText", GetLiveValue(frame, "powerMaxRaw", "0"))
        end,
        format = FormatTextValue,
        direct = true,
    },
    ["curpp:abbr"] = {
        value = function(unit, frame)
            return GetLiveValue(frame, "powerCurrentAbbr", "")
        end,
        format = FormatTextValue,
        direct = true,
    },
    ["maxpp:abbr"] = {
        value = function(unit, frame)
            return GetLiveValue(frame, "powerMaxAbbr", "")
        end,
        format = FormatTextValue,
        direct = true,
    },
}

local TAG_DATABASE = {
    { token = "[color:class]", category = "INFO_TAG_CATEGORY_FORMAT", description = "INFO_TAG_DESC_COLOR_CLASS", example = "[color:class][name][rc]" },
    { token = "[color:blizz_pwr]", category = "INFO_TAG_CATEGORY_FORMAT", description = "INFO_TAG_DESC_COLOR_BLIZZ_PWR", example = "[color:blizz_pwr][power:cur][rc]" },
    { token = "[color:reaction]", category = "INFO_TAG_CATEGORY_FORMAT", description = "INFO_TAG_DESC_COLOR_REACTION", example = "[color:reaction][name][rc]" },
    { token = "[color:blizz_yellow]", category = "INFO_TAG_CATEGORY_FORMAT", description = "INFO_TAG_DESC_COLOR_BLIZZ", example = "[color:blizz_yellow]Text[rc]" },
    { token = "[color:blizz_red]", category = "INFO_TAG_CATEGORY_FORMAT", description = "INFO_TAG_DESC_COLOR_BLIZZ", example = "[color:blizz_red]Text[rc]" },
    { token = "[color:blizz_green]", category = "INFO_TAG_CATEGORY_FORMAT", description = "INFO_TAG_DESC_COLOR_BLIZZ", example = "[color:blizz_green]Text[rc]" },
    { token = "[color:blizz_highlight]", category = "INFO_TAG_CATEGORY_FORMAT", description = "INFO_TAG_DESC_COLOR_BLIZZ", example = "[color:blizz_highlight]Text[rc]" },
    { token = "[color:ffcc00]", category = "INFO_TAG_CATEGORY_FORMAT", description = "INFO_TAG_DESC_COLOR_EXPLICIT", example = "[color:ffcc00]Text[rc]" },
    { token = "[rc]", category = "INFO_TAG_CATEGORY_FORMAT", description = "INFO_TAG_DESC_COLOR_RESET", example = "[rc]" },
    { token = "[hp:cur]", category = "INFO_TAG_CATEGORY_HEALTH", description = "INFO_TAG_DESC_HP_CUR", example = "154320" },
    { token = "[hp:max]", category = "INFO_TAG_CATEGORY_HEALTH", description = "INFO_TAG_DESC_HP_MAX", example = "154320" },
    { token = "[hp:cur:abbr]", category = "INFO_TAG_CATEGORY_HEALTH", description = "INFO_TAG_DESC_HP_CUR_ABBR", example = "154k" },
    { token = "[hp:max:abbr]", category = "INFO_TAG_CATEGORY_HEALTH", description = "INFO_TAG_DESC_HP_MAX_ABBR", example = "154k" },
    { token = "[hp:perc]", category = "INFO_TAG_CATEGORY_HEALTH", description = "INFO_TAG_DESC_HP_PERC", example = "100" },
    { token = "[power:cur]", category = "INFO_TAG_CATEGORY_POWER", description = "INFO_TAG_DESC_POWER_CUR", example = "100" },
    { token = "[power:max]", category = "INFO_TAG_CATEGORY_POWER", description = "INFO_TAG_DESC_POWER_MAX", example = "100" },
    { token = "[power:cur:abbr]", category = "INFO_TAG_CATEGORY_POWER", description = "INFO_TAG_DESC_POWER_CUR_ABBR", example = "100" },
    { token = "[power:max:abbr]", category = "INFO_TAG_CATEGORY_POWER", description = "INFO_TAG_DESC_POWER_MAX_ABBR", example = "100" },
    { token = "[power:perc]", category = "INFO_TAG_CATEGORY_POWER", description = "INFO_TAG_DESC_POWER_PERC", example = "100" },
    { token = "[altpower:cur]", category = "INFO_TAG_CATEGORY_POWER", description = "INFO_TAG_DESC_POWER_CUR", example = "72" },
    { token = "[altpower:max]", category = "INFO_TAG_CATEGORY_POWER", description = "INFO_TAG_DESC_POWER_MAX", example = "100" },
    { token = "[altpower:cur:abbr]", category = "INFO_TAG_CATEGORY_POWER", description = "INFO_TAG_DESC_POWER_CUR_ABBR", example = "72" },
    { token = "[altpower:max:abbr]", category = "INFO_TAG_CATEGORY_POWER", description = "INFO_TAG_DESC_POWER_MAX_ABBR", example = "100" },
    { token = "[classpower:cur]", category = "INFO_TAG_CATEGORY_POWER", description = "INFO_TAG_DESC_POWER_CUR", example = "4" },
    { token = "[classpower:max]", category = "INFO_TAG_CATEGORY_POWER", description = "INFO_TAG_DESC_POWER_MAX", example = "5" },
    { token = "[classpower:cur:abbr]", category = "INFO_TAG_CATEGORY_POWER", description = "INFO_TAG_DESC_POWER_CUR_ABBR", example = "4" },
    { token = "[classpower:max:abbr]", category = "INFO_TAG_CATEGORY_POWER", description = "INFO_TAG_DESC_POWER_MAX_ABBR", example = "5" },
    { token = "[cast:name]", category = "INFO_TAG_CATEGORY_CAST", description = "INFO_TAG_DESC_CAST_NAME", example = "Frostbolt" },
    { token = "[cast:time]", category = "INFO_TAG_CATEGORY_CAST", description = "INFO_TAG_DESC_CAST_TIME", example = "1.8" },
    { token = "[name]", category = "INFO_TAG_CATEGORY_UNIT", description = "INFO_TAG_DESC_NAME", example = "FocalPoint" },
    { token = "[guild]", category = "INFO_TAG_CATEGORY_UNIT", description = "INFO_TAG_DESC_GUILD", example = "Guild Name" },
    { token = "[realm]", category = "INFO_TAG_CATEGORY_UNIT", description = "INFO_TAG_DESC_REALM", example = "Lordaeron" },
    { token = "[level]", category = "INFO_TAG_CATEGORY_UNIT", description = "INFO_TAG_DESC_LEVEL", example = "80" },
    { token = "[class]", category = "INFO_TAG_CATEGORY_UNIT", description = "INFO_TAG_DESC_CLASS", example = "Warrior" },
    { token = "[race]", category = "INFO_TAG_CATEGORY_UNIT", description = "INFO_TAG_DESC_RACE", example = "Human" },
    { token = "[classification]", category = "INFO_TAG_CATEGORY_UNIT", description = "INFO_TAG_DESC_CLASSIFICATION", example = "Elite" },
    { token = "[family]", category = "INFO_TAG_CATEGORY_UNIT", description = "INFO_TAG_DESC_FAMILY", example = "Wolf" },
    { token = "[type]", category = "INFO_TAG_CATEGORY_UNIT", description = "INFO_TAG_DESC_TYPE", example = "Humanoid" },
    { token = "[creature]", category = "INFO_TAG_CATEGORY_UNIT", description = "INFO_TAG_DESC_CREATURE", example = "Humanoid" },
    { token = "[status]", category = "INFO_TAG_CATEGORY_STATUS", description = "INFO_TAG_DESC_STATUS", example = "AFK" },
    { token = "[status:timer]", category = "INFO_TAG_CATEGORY_STATUS", description = "INFO_TAG_DESC_STATUS_TIMER", example = "(00:12)" },
    { token = "[dead:timer]", category = "INFO_TAG_CATEGORY_STATUS", description = "INFO_TAG_DESC_DEAD_TIMER", example = "(00:12)" },
    { token = "[afk]", category = "INFO_TAG_CATEGORY_STATUS", description = "INFO_TAG_DESC_AFK", example = "AFK" },
    { token = "[dnd]", category = "INFO_TAG_CATEGORY_STATUS", description = "INFO_TAG_DESC_DND", example = "DND" },
    { token = "[dead]", category = "INFO_TAG_CATEGORY_STATUS", description = "INFO_TAG_DESC_DEAD", example = "Dead" },
    { token = "[ghost]", category = "INFO_TAG_CATEGORY_STATUS", description = "INFO_TAG_DESC_GHOST", example = "Ghost" },
    { token = "[offline]", category = "INFO_TAG_CATEGORY_STATUS", description = "INFO_TAG_DESC_OFFLINE", example = "Offline" },
    { token = "[pvp]", category = "INFO_TAG_CATEGORY_STATUS", description = "INFO_TAG_DESC_PVP", example = "PvP" },
    { token = "[combat]", category = "INFO_TAG_CATEGORY_STATUS", description = "INFO_TAG_DESC_COMBAT", example = "Combat" },
    { token = "[resting]", category = "INFO_TAG_CATEGORY_STATUS", description = "INFO_TAG_DESC_RESTING", example = "Resting" },
    { token = "[leader]", category = "INFO_TAG_CATEGORY_STATUS", description = "INFO_TAG_DESC_LEADER", example = "Leader" },
    { token = "[role]", category = "INFO_TAG_CATEGORY_STATUS", description = "INFO_TAG_DESC_ROLE", example = "Tank" },
}

function UF:GetTagDatabase()
    return TAG_DATABASE
end

-- Preview builder for the text builder and GUI preview surfaces.
local function GetTagPreviewFallback(token)
    local previewFrame = {
        IsTemplatePreview = true,
        TestValues = {
            classToken = "WARRIOR",
            powerToken = "RAGE",
            reaction = 5,
        },
    }

    local colorToken = ResolveColorTag(previewFrame, "player", token)
    if type(colorToken) == "string" then
        return colorToken
    end

    for _, def in ipairs(TAG_DATABASE) do
        if def.token == "[" .. token .. "]" then
            return def.example or "[" .. token .. "]"
        end
    end

    return "[" .. token .. "]"
end

local function ResolveToken(frame, unit, token)
    return ResolveTokenShared(frame, unit, token, {
        IsPreviewModeEnabled = IsPreviewModeEnabled,
        ResolveColorTag = ResolveColorTag,
        TokenDefinitions = TOKEN_DEFS,
        FormatNumber = FormatNumber,
    })
end

-- Basic built-in tag resolver before the lower-level token table is queried.
local function ResolveBasicTag(frame, unit, token)
    return ResolveBasicTagShared(frame, unit, token, {
        IsPreviewModeEnabled = IsPreviewModeEnabled,
        FormatTimeValue = FormatTimeValue,
        ResolveColorTag = ResolveColorTag,
        GetLocalizedClassName = GetLocalizedClassName,
        GetClassificationText = GetClassificationText,
        GetCurrentStatusInfo = GetCurrentStatusInfo,
        GetStatusText = GetStatusText,
        GetGhostText = GetGhostText,
        GetDeadText = GetDeadText,
        GetOfflineText = GetOfflineText,
        GetCombatText = GetCombatText,
        GetRestingText = GetRestingText,
        GetLeaderText = GetLeaderText,
        GetRoleText = GetRoleText,
        GetLiveValue = GetLiveValue,
        FormatStatusTimerValue = FormatStatusTimerValue,
        GetResolvedUnitName = GetResolvedUnitName,
        IsSafeTrue = IsSafeTrue,
        ResolveToken = ResolveToken,
    })
end

-- Small local helper for cast-time text updates.
local function HasActiveCast(unit)
    if IsPreviewModeEnabled() then
        return true
    end

    if not unit then
        return false
    end

    if UnitCastingInfo then
        local castName = UnitCastingInfo(unit)
        if type(castName) == "string" then
            return true
        end
    end

    if UnitChannelInfo then
        local channelName = UnitChannelInfo(unit)
        if type(channelName) == "string" then
            return true
        end
    end

    return false
end

local function FindTextKeyByRole(frame, role, legacyKey)
    if not frame or not frame.config or not frame.config.Texts then
        return nil
    end

    local Roles = FocalPoint.TextElementRoles or {}
    return Roles.FindTextKeyByRole and Roles.FindTextKeyByRole(frame.config.Texts, role, legacyKey) or nil
end

-- Checks whether the current frame actually uses a CastTime text element.
local function FrameUsesCastTime(frame)
    local castTimeKey = FindTextKeyByRole(frame, "cast_time", "CastTime")
    local textConfig = castTimeKey and frame.config and frame.config.Texts and frame.config.Texts[castTimeKey]
    return type(textConfig) == "table" and textConfig.enabled ~= false
end

local function ResolveCastTimeTextKey(frame)
    return FindTextKeyByRole(frame, "cast_time", "CastTime")
end

-- Local wrappers keep the public UF methods stable while delegating logic out.
local function ResolveTextTemplate(frame, unit, template)
    return ResolveTextTemplateShared(frame, unit, template, {
        ResolveBasicTag = ResolveBasicTag,
        FormatNumber = FormatNumber,
    })
end

local function TemplateContainsToken(template, token)
    return TemplateContainsTokenShared(template, token)
end

local function ResolveConfiguredTemplate(frame, textConfig)
    return ResolveConfiguredTemplateShared(frame, textConfig, {
        GetLiveValue = GetLiveValue,
        GetTemplate = function(templateName)
            local templates = UnitUtils.GetTextTemplatesDB and UnitUtils.GetTextTemplatesDB() or nil
            return type(templates) == "table" and templates[templateName] or nil
        end,
    })
end

function UF:BuildTemplatePreview(template, unit)
    return BuildTemplatePreviewShared(template, {
        GetTagPreviewFallback = GetTagPreviewFallback,
    })
end

-- Public UF facade methods used by the unit-frame runtime.
local function ApplyDirectTemplate(frame, textObject, unit, template, fallbackColor)
    return ApplyDirectTemplateShared(frame, textObject, unit, template, fallbackColor, {
        IsPreviewModeEnabled = IsPreviewModeEnabled,
        ResolveColorTag = ResolveColorTag,
        ResolveBasicTag = ResolveBasicTag,
        FormatNumber = FormatNumber,
        NormalizeTemplateText = NormalizeTemplateTextShared,
    })
end

function UF:CreateTextElement(frame, key, textConfig)
    return CreateTextElementShared(frame, key, textConfig, {
        GetTextLayerParent = GetTextLayerParent,
    })
end

function UF:CreateTextElements(frame)
    return CreateTextElementsShared(frame, {
        CreateElement = function(targetFrame, key, textConfig)
            return self:CreateTextElement(targetFrame, key, textConfig)
        end,
    })
end

function UF:ApplyTextElementConfig(frame, key, textObject, textConfig)
    return ApplyTextElementConfigShared(frame, key, textObject, textConfig, {
        GetAnchorTarget = function(targetFrame, anchorTo)
            return self:GetAnchorTarget(targetFrame, anchorTo)
        end,
        GetFontPath = GetFontPath,
        BuildFontFlags = BuildFontFlags,
        UnpackColor = UnpackColor,
        ResolveConfiguredTemplate = ResolveConfiguredTemplate,
        TemplateContainsToken = TemplateContainsToken,
        GetClassTextColor = GetClassTextColor,
    })
end

function UF:UpdateTextElement(frame, key)
    return UpdateTextElementShared(frame, key, {
        ResolveConfiguredTemplate = ResolveConfiguredTemplate,
        UnpackColor = UnpackColor,
        GetLiveValue = GetLiveValue,
        ToSafeNumber = ToSafeNumber,
        GetSecondaryPowerDisplayValues = GetSecondaryPowerDisplayValues,
        FormatNumber = FormatNumber,
        TemplateContainsToken = TemplateContainsToken,
        GetClassTextColor = GetClassTextColor,
        ApplyDirectTemplate = ApplyDirectTemplate,
        ResolveTextTemplate = ResolveTextTemplate,
    })
end

function UF:UpdateTextElements(frame)
    return UpdateTextElementsShared(frame, {
        UpdateElement = function(targetFrame, key)
            return self:UpdateTextElement(targetFrame, key)
        end,
    })
end

function UF:RegisterTextEvents(frame)
    return RegisterTextEventsShared(frame, {
        IsPreviewModeEnabled = IsPreviewModeEnabled,
        HasActiveCast = HasActiveCast,
        FrameUsesCastTime = FrameUsesCastTime,
        ResolveCastTimeTextKey = ResolveCastTimeTextKey,
        Refresh = function(targetFrame)
            if UF.Refresh then
                return UF:Refresh(targetFrame)
            end
        end,
        RefreshUnitBarValues = function(targetFrame)
            if UF.RefreshUnitBarValues then
                return UF:RefreshUnitBarValues(targetFrame)
            end
        end,
        ApplyConfig = function(targetFrame)
            if UF.ApplyConfig then
                return UF:ApplyConfig(targetFrame)
            end
        end,
        RefreshCastBar = function(targetFrame)
            if UF.RefreshCastBar then
                return UF:RefreshCastBar(targetFrame)
            end
        end,
        RefreshLiveValues = function(targetFrame)
            return UF:RefreshLiveValues(targetFrame)
        end,
        UpdateTextElement = function(targetFrame, key)
            return UF:UpdateTextElement(targetFrame, key)
        end,
        UpdateTextElements = function(targetFrame)
            return UF:UpdateTextElements(targetFrame)
        end,
    })
end

function UF:ApplyTestTextValues(frame)
    return ApplyTestTextValuesShared(frame, {
        RefreshLiveValues = function(targetFrame)
            return self:RefreshLiveValues(targetFrame)
        end,
        UpdateTextElements = function(targetFrame)
            return self:UpdateTextElements(targetFrame)
        end,
    })
end
