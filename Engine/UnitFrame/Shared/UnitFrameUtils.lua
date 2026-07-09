local _, FocalPoint = ...

FocalPoint.UnitFrameUtils = FocalPoint.UnitFrameUtils or {}
local Utils = FocalPoint.UnitFrameUtils

-- Utility helpers shared by the unit-frame runtime.
-- Keep this file focused on pure value conversion and safe API handling.

function Utils.NormalizeConfigUnitKey(unit)
    if type(unit) ~= "string" or unit == "" then
        return unit
    end

    if unit:match("^boss%d+$") then
        return "boss"
    end

    return unit
end

function Utils.GetBossFrameIndex(unit)
    if type(unit) ~= "string" then
        return nil
    end

    local bossIndex = unit:match("^boss(%d+)$")
    if not bossIndex then
        return nil
    end

    bossIndex = tonumber(bossIndex)
    if type(bossIndex) == "number" and bossIndex >= 1 and bossIndex <= 5 then
        return bossIndex
    end

    return nil
end

local function NormalizeStateTemplates(stateTemplates)
    if type(stateTemplates) ~= "table" then
        return ""
    end

    local entries = {}
    for stateKey, templateName in pairs(stateTemplates) do
        if type(templateName) == "string" and templateName ~= "" then
            entries[#entries + 1] = tostring(stateKey) .. "=" .. templateName
        end
    end

    table.sort(entries)
    return table.concat(entries, "|")
end

local function CountMeaningfulTextFields(textConfig)
    if type(textConfig) ~= "table" then
        return 0
    end

    local count = 0
    for key, value in pairs(textConfig) do
        if key == "templateName" then
            if type(value) == "string" and value ~= "" then
                count = count + 1
            end
        elseif key == "tag" then
            if type(value) == "string" and value ~= "" then
                count = count + 1
            end
        elseif key == "stateTemplates" then
            if NormalizeStateTemplates(value) ~= "" then
                count = count + 1
            end
        elseif key == "enabled" then
            if value ~= nil then
                count = count + 1
            end
        else
            count = count + 1
        end
    end

    return count
end

local function IsMinimalLegacyTemplateReference(textId, textConfig)
    if type(textId) ~= "string" or not textId:match("^Custom%d+$") then
        return false
    end

    return CountMeaningfulTextFields(textConfig) <= 1
end

local function IsGeneratedBuilderTemplateReference(textId, textConfig)
    if type(textId) ~= "string" or not textId:match("^text_%d+$") or type(textConfig) ~= "table" then
        return false
    end

    return textConfig.templateName ~= nil
        and type(textConfig.templateName) == "string"
        and textConfig.templateName ~= ""
        and textConfig.anchorTo == "HealthBar"
        and textConfig.point == "CENTER"
        and textConfig.relativePoint == "CENTER"
        and (tonumber(textConfig.offsetX) or 0) == 0
        and (tonumber(textConfig.offsetY) or 0) == 0
end

local function HasMeaningfulTemplateBinding(textConfig)
    if type(textConfig) ~= "table" then
        return false
    end

    if type(textConfig.templateName) == "string" and textConfig.templateName ~= "" then
        return true
    end

    if NormalizeStateTemplates(textConfig.stateTemplates) ~= "" then
        return true
    end

    if type(textConfig.tag) == "string" and textConfig.tag ~= "" then
        return true
    end

    return false
end

local function BuildTextFingerprint(textConfig)
    if type(textConfig) ~= "table" then
        return nil
    end

    local color = textConfig.color or {}
    local shadowColor = textConfig.shadowColor or {}

    return table.concat({
        tostring(textConfig.templateName or ""),
        tostring(textConfig.tag or ""),
        NormalizeStateTemplates(textConfig.stateTemplates),
        tostring(textConfig.role or ""),
        tostring(textConfig.anchorTo or ""),
        tostring(textConfig.point or ""),
        tostring(textConfig.relativePoint or ""),
        tostring(textConfig.offsetX or 0),
        tostring(textConfig.offsetY or 0),
        tostring(textConfig.font or ""),
        tostring(textConfig.fontSize or ""),
        tostring(textConfig.justifyH or ""),
        tostring(textConfig.overflowMode or ""),
        tostring(textConfig.enabled ~= false),
        tostring(color[1] or color.r or ""),
        tostring(color[2] or color.g or ""),
        tostring(color[3] or color.b or ""),
        tostring(color[4] or color.a or ""),
        tostring(shadowColor[1] or shadowColor.r or ""),
        tostring(shadowColor[2] or shadowColor.g or ""),
        tostring(shadowColor[3] or shadowColor.b or ""),
        tostring(shadowColor[4] or shadowColor.a or ""),
    }, "\31")
end

local function NormalizeUnitTexts(unitConfig)
    local texts = unitConfig and unitConfig.Texts
    if type(texts) ~= "table" then
        return
    end

    local seenFingerprints = {}
    local removals = {}
    local templateOwners = {}

    for textId, textConfig in pairs(texts) do
        if type(textConfig) ~= "table" then
            removals[#removals + 1] = textId
        elseif not HasMeaningfulTemplateBinding(textConfig) then
            if type(textId) == "string" and textId:match("^text_%d+$") then
                removals[#removals + 1] = textId
            end
        else
            local fingerprint = BuildTextFingerprint(textConfig)
            if fingerprint and seenFingerprints[fingerprint] then
                if type(textId) == "string" and textId:match("^text_%d+$") then
                    removals[#removals + 1] = textId
                end
            elseif fingerprint then
                seenFingerprints[fingerprint] = textId
            end
        end
    end

    for textId, textConfig in pairs(texts) do
        if type(textConfig) == "table" then
            local templateName = textConfig.templateName
            if type(templateName) == "string" and templateName ~= "" then
                templateOwners[templateName] = templateOwners[templateName] or {}
                templateOwners[templateName][#templateOwners[templateName] + 1] = textId
            end
        end
    end

    for templateName, owners in pairs(templateOwners) do
        if #owners > 1 then
            local hasCanonicalLegacy = false
            for _, textId in ipairs(owners) do
                if type(textId) == "string"
                    and not textId:match("^text_%d+$")
                    and not textId:match("^Custom%d+$")
                then
                    hasCanonicalLegacy = true
                    break
                end
            end

            if hasCanonicalLegacy then
                for _, textId in ipairs(owners) do
                    local textConfig = texts[textId]
                    if IsMinimalLegacyTemplateReference(textId, textConfig)
                        or IsGeneratedBuilderTemplateReference(textId, textConfig)
                    then
                        removals[#removals + 1] = textId
                    end
                end
            end
        end
    end

    for _, textId in ipairs(removals) do
        texts[textId] = nil
    end
end

function Utils.GetProfileDB()
    local db = FocalPoint.db
    if not db or type(db.profile) ~= "table" then
        return nil
    end

    return db.profile
end

function Utils.GetUnitsDB()
    local profile = Utils.GetProfileDB()
    if not profile or type(profile.Units) ~= "table" then
        return nil
    end

    return profile.Units
end

function Utils.GetGeneralDB()
    local profile = Utils.GetProfileDB()
    if not profile or type(profile.General) ~= "table" then
        return nil
    end

    return profile.General
end

function Utils.GetTextTemplatesDB()
    local profile = Utils.GetProfileDB()
    if not profile or type(profile.TextTemplates) ~= "table" then
        return nil
    end

    return profile.TextTemplates
end

function Utils.GetUnitDB(unit)
    local units = Utils.GetUnitsDB()
    if not units then
        return nil
    end

    local unitConfig = units[Utils.NormalizeConfigUnitKey(unit)]
    if type(unitConfig) == "table" then
        NormalizeUnitTexts(unitConfig)
    end

    return unitConfig
end

function Utils.UnpackColor(color, fallback)
    color = color or fallback or { 1, 1, 1, 1 }

    local r = color[1] or color.r or 1
    local g = color[2] or color.g or 1
    local b = color[3] or color.b or 1
    local a = color[4]
    if a == nil then
        a = color.a
    end
    if a == nil then
        a = 1
    end

    return r, g, b, a
end

function Utils.IsSafeTrue(value)
    return type(value) == "boolean" and not (issecretvalue and issecretvalue(value)) and value
end

function Utils.ResolveInterruptibleState(notInterruptible)
    return Utils.ResolveInterruptState(notInterruptible) == "INTERRUPTIBLE"
end

function Utils.ResolveInterruptState(notInterruptible)
    if type(notInterruptible) == "boolean" and not (issecretvalue and issecretvalue(notInterruptible)) then
        if notInterruptible then
            return "PROTECTED"
        end

        return "INTERRUPTIBLE"
    end

    return "UNKNOWN"
end

function Utils.ToSafeNumberValue(value)
    if value == nil then
        return 0
    end

    if type(value) == "number" and not (issecretvalue and issecretvalue(value)) then
        return value
    end

    local textOk, textValue = pcall(tostring, value)
    if textOk and type(textValue) == "string" then
        local numberOk, numberValue = pcall(tonumber, textValue)
        if numberOk and type(numberValue) == "number" and not (issecretvalue and issecretvalue(numberValue)) then
            return numberValue
        end
    end

    local formattedOk, formattedValue = pcall(string.format, "%.0f", value)
    if formattedOk and type(formattedValue) == "string" then
        local numberOk, numberValue = pcall(tonumber, formattedValue)
        if numberOk and type(numberValue) == "number" and not (issecretvalue and issecretvalue(numberValue)) then
            return numberValue
        end
    end

    return 0
end

function Utils.FormatDisplayNumber(value)
    if value == nil then
        return "0"
    end

    if BreakUpLargeNumbers then
        local ok, result = pcall(BreakUpLargeNumbers, value)
        if ok and type(result) == "string" then
            return result
        end
    end

    local ok, result = pcall(string.format, "%s", value)
    if ok and type(result) == "string" then
        return result
    end

    return "0"
end

function Utils.ResolveBlizzardAbbreviation(rawValue, displayText)
    if type(AbbreviateLargeNumbers) == "function" then
        local ok, abbreviation = pcall(AbbreviateLargeNumbers, rawValue)
        if ok and type(abbreviation) == "string" then
            return abbreviation
        end
    end

    if type(displayText) == "string" then
        return displayText
    end

    return ""
end
