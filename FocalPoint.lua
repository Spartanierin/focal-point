local ADDON_NAME, FocalPoint = ...

FocalPoint.ADDON_NAME = "FocalPoint"
FocalPoint.frames = FocalPoint.frames or {}

local AceLocale = LibStub("AceLocale-3.0")
FocalPoint.L = AceLocale:GetLocale("FocalPoint", true) or FocalPoint.L or {}

local TARGET_RANGE_CHECK_YARDS = 20
FocalPoint.TARGET_RANGE_CHECK_YARDS = TARGET_RANGE_CHECK_YARDS

local function ToChatSafeString(value)
    local okDirect, directValue = pcall(function()
        if type(value) ~= "string" then
            return nil
        end

        if value == "" then
            return nil
        end

        return value
    end)
    if okDirect and type(directValue) == "string" then
        return directValue
    end

    local okText, textValue = pcall(tostring, value)
    if okText and type(textValue) == "string" then
        local okNonEmpty, isNonEmpty = pcall(function()
            return textValue ~= ""
        end)
        if okNonEmpty and isNonEmpty == true then
            return textValue
        end
    end

    return nil
end

local function PrintToChat(prefix, message)
    local safeMessage = ToChatSafeString(message)
    if not safeMessage then
        return
    end

    local safePrefix = ToChatSafeString(prefix) or ""
    local okText, text = pcall(string.format, "|cff6fd2ffFocalPoint|r %s%s", safePrefix, safeMessage)
    if not okText or type(text) ~= "string" then
        return
    end

    if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
        DEFAULT_CHAT_FRAME:AddMessage(text)
    end
end

function FocalPoint:Info(message)
    PrintToChat("", message)
end

function FocalPoint:Print(message)
    PrintToChat("", message)
end

function FocalPoint:Warn(message)
    PrintToChat("|cffff7b7b|r ", message)
end

function FocalPoint:Success(message)
    PrintToChat("|cff72e06a|r ", message)
end

function FocalPoint:Error(message)
    PrintToChat("|cffff6060|r ", message)
end

function FocalPoint:Debug(message)
    PrintToChat("|cffb7a6ff[Debug]|r ", message)
end

local FocalPointAddon = LibStub("AceAddon-3.0"):NewAddon("FocalPoint")
FocalPoint.Ace = FocalPointAddon

local BLIZZARD_UNIT_FRAMES = {
    "player",
    "target",
    "focus",
    "pet",
}

local BLIZZARD_FRAME_OBJECTS = {
    "PlayerFrame",
    "TargetFrame",
    "TargetFrameContainer",
    "FocusFrame",
    "FocusFrameContainer",
    "PetFrame",
}

local blizzardFrameHider = nil

local function EnsureBlizzardFrameHider()
    if blizzardFrameHider then
        return blizzardFrameHider
    end

    blizzardFrameHider = CreateFrame("Frame", "FocalPointBlizzardFrameHider", UIParent)
    blizzardFrameHider:Hide()
    return blizzardFrameHider
end

local function ApplyDirectBlizzardFrameHide()
    local hiddenParent = EnsureBlizzardFrameHider()

    for _, frameName in ipairs(BLIZZARD_FRAME_OBJECTS) do
        local frame = _G[frameName]
        if frame then
            if frame.UnregisterAllEvents then
                frame:UnregisterAllEvents()
            end
            if frame.SetParent then
                frame:SetParent(hiddenParent)
            end
            if frame.SetAlpha then
                frame:SetAlpha(0)
            end
            if frame.Hide then
                frame:Hide()
            end
            if not frame._focalPointForcedHidden then
                frame:HookScript("OnShow", function(self)
                    if FocalPoint.blizzardFramesDisabled and self.Hide then
                        if self.SetAlpha then
                            self:SetAlpha(0)
                        end
                        self:Hide()
                    end
                end)
                frame._focalPointForcedHidden = true
            end
        end
    end
end

local function ApplyBlizzardFrameVisibility(hidden)
    if not hidden then
        return
    end

    local oUF = FocalPoint.oUF
    if FocalPoint.blizzardFramesDisabled then
        return
    end

    if oUF and oUF.DisableBlizzard then
        for _, unit in ipairs(BLIZZARD_UNIT_FRAMES) do
            oUF:DisableBlizzard(unit)
        end
    end

    ApplyDirectBlizzardFrameHide()
    FocalPoint.blizzardFramesDisabled = true
end

local function RefreshBlizzardFrameMouseState(disabled)
    local frames = {
        _G.PlayerFrame,
        _G.TargetFrame,
        _G.FocusFrame,
        _G.PetFrame,
    }

    for _, frame in ipairs(frames) do
        if frame and frame.EnableMouse then
            frame:EnableMouse(not disabled)
        end
    end
end

local function EnsureImageElementDefaults()
    if not FocalPoint.db or not FocalPoint.db.profile or not FocalPoint.GetDefaultDB then
        return
    end

    local profile = FocalPoint.db.profile
    local defaults = FocalPoint:GetDefaultDB()
    local units = profile and profile.Units
    local defaultUnits = defaults and defaults.profile and defaults.profile.Units

    if not units or not defaultUnits then
        return
    end

    for unitKey, unitDefaults in pairs(defaultUnits) do
        local unitDB = units[unitKey]
        if type(unitDB) == "table" then
            if unitDefaults.RaidTargetIcon then
                if unitDB.RaidTargetIcon == nil then
                    unitDB.RaidTargetIcon = CopyTable(unitDefaults.RaidTargetIcon)
                elseif unitDB.RaidTargetIcon.enabled == nil then
                    unitDB.RaidTargetIcon.enabled = unitDefaults.RaidTargetIcon.enabled
                end
            end
        end
    end
end

local function EnsureBarTextureDefaults()
    if not FocalPoint.db or not FocalPoint.db.profile or not FocalPoint.GetDefaultDB then
        return
    end

    local profile = FocalPoint.db.profile
    local defaults = FocalPoint:GetDefaultDB()
    local units = profile and profile.Units
    local defaultUnits = defaults and defaults.profile and defaults.profile.Units

    if not units or not defaultUnits then
        return
    end

    for unitKey, unitDefaults in pairs(defaultUnits) do
        local unitDB = units[unitKey]
        if type(unitDB) == "table" then
            local sharedTexture = unitDB.statusBarTexture
                or unitDefaults.statusBarTexture
                or "Interface\\TargetingFrame\\UI-StatusBar"

            if unitDB.healthBarTexture == nil then
                unitDB.healthBarTexture = sharedTexture
            end

            if unitDB.powerBarTexture == nil then
                unitDB.powerBarTexture = sharedTexture
            end
        end
    end
end

local function EnsureExpandedUnitDefaults(unitKey)
    if not FocalPoint.db or not FocalPoint.db.profile or not FocalPoint.GetDefaultDB then
        return
    end

    local profile = FocalPoint.db.profile
    local defaults = FocalPoint:GetDefaultDB()
    local units = profile and profile.Units
    local defaultUnits = defaults and defaults.profile and defaults.profile.Units

    if type(units) ~= "table" or type(defaultUnits) ~= "table" then
        return
    end

    local unitDB = units[unitKey]
    local unitDefaults = defaultUnits[unitKey]
    if type(unitDefaults) ~= "table" then
        return
    end

    if unitDB == nil then
        units[unitKey] = CopyTable(unitDefaults)
        return
    end

    if type(unitDB) ~= "table" then
        units[unitKey] = CopyTable(unitDefaults)
        return
    end

    local meaningfulKeys = 0
    for key in pairs(unitDB) do
        if key ~= "enabled" then
            meaningfulKeys = meaningfulKeys + 1
        end
    end

    if meaningfulKeys == 0 then
        units[unitKey] = CopyTable(unitDefaults)
    end
end

local function EnsureDerivedUnitDefaults(unitKey, sourceUnitKey, mutateFn)
    if not FocalPoint.db or not FocalPoint.db.profile or not FocalPoint.GetDefaultDB then
        return
    end

    local profile = FocalPoint.db.profile
    local defaults = FocalPoint:GetDefaultDB()
    local units = profile and profile.Units
    local defaultUnits = defaults and defaults.profile and defaults.profile.Units

    if type(units) ~= "table" or type(defaultUnits) ~= "table" then
        return
    end

    local sourceDefaults = defaultUnits[sourceUnitKey]
    if type(sourceDefaults) ~= "table" then
        return
    end

    local unitDB = units[unitKey]
    local needsInit = type(unitDB) ~= "table"

    if not needsInit then
        local meaningfulKeys = 0
        for key in pairs(unitDB) do
            if key ~= "enabled" then
                meaningfulKeys = meaningfulKeys + 1
            end
        end
        needsInit = meaningfulKeys == 0
    end

    if not needsInit then
        return
    end

    local derivedDefaults = CopyTable(sourceDefaults)
    if type(mutateFn) == "function" then
        mutateFn(derivedDefaults)
    end

    units[unitKey] = derivedDefaults
end

local function ApplyCastTextLayoutDefaults(textConfig, isName)
    if type(textConfig) ~= "table" then
        return
    end

    if isName then
        textConfig.anchorTo = "CastBar"
        textConfig.point = "LEFT"
        textConfig.relativePoint = "LEFT"
        textConfig.offsetX = 4
        textConfig.offsetY = 0
        textConfig.justifyH = "LEFT"
    else
        textConfig.anchorTo = "CastBar"
        textConfig.point = "RIGHT"
        textConfig.relativePoint = "RIGHT"
        textConfig.offsetX = -4
        textConfig.offsetY = 0
        textConfig.justifyH = "RIGHT"
    end
end

local function EnsureCastTextDefaults()
    if not FocalPoint.db or not FocalPoint.db.profile or not FocalPoint.db.profile.Units then
        return
    end

    for _, unitKey in ipairs({ "player", "target" }) do
        local unitDB = FocalPoint.db.profile.Units[unitKey]
        local texts = unitDB and unitDB.Texts
        if type(texts) == "table" then
            local castName = texts.CastName
            if type(castName) == "table"
                and castName.anchorTo == "Frame"
                and castName.point == "TOP"
                and castName.relativePoint == "BOTTOM"
                and (castName.offsetX or 0) == 0
                and (castName.offsetY or 0) == -6
            then
                ApplyCastTextLayoutDefaults(castName, true)
            end

            local castTime = texts.CastTime
            if type(castTime) == "table"
                and castTime.anchorTo == "Frame"
                and castTime.point == "TOP"
                and castTime.relativePoint == "BOTTOM"
                and (castTime.offsetX or 0) == 0
                and (castTime.offsetY or 0) == -20
            then
                ApplyCastTextLayoutDefaults(castTime, false)
            end
        end
    end
end

local function EnsureAlternativePowerDefaults()
    if not FocalPoint.db or not FocalPoint.db.profile or not FocalPoint.GetDefaultDB then
        return
    end

    local profile = FocalPoint.db.profile
    local defaults = FocalPoint:GetDefaultDB()
    local units = profile and profile.Units
    local defaultUnits = defaults and defaults.profile and defaults.profile.Units

    if not units or not defaultUnits then
        return
    end

    local keysToCopy = {
        "showAlternativePowerBar",
        "alternativePowerBarHeight",
        "alternativePowerBarWidth",
        "alternativePowerBarAnchorTo",
        "alternativePowerBarPoint",
        "alternativePowerBarRelativePoint",
        "alternativePowerBarOffsetX",
        "alternativePowerBarOffsetY",
        "alternativePowerBarTexture",
    }

    for unitKey, unitDefaults in pairs(defaultUnits) do
        local unitDB = units[unitKey]
        if type(unitDB) == "table" and type(unitDefaults) == "table" then
            for _, key in ipairs(keysToCopy) do
                if unitDB[key] == nil and unitDefaults[key] ~= nil then
                    unitDB[key] = unitDefaults[key]
                end
            end

            if type(unitDefaults.Texts) == "table" then
                unitDB.Texts = unitDB.Texts or {}
                if unitDB.Texts.AltPower == nil and unitDefaults.Texts.AltPower ~= nil then
                    unitDB.Texts.AltPower = CopyTable(unitDefaults.Texts.AltPower)
                end
            end
        end
    end
end

local function EnsureClassPowerDefaults()
    if not FocalPoint.db or not FocalPoint.db.profile or not FocalPoint.GetDefaultDB then
        return
    end

    local profile = FocalPoint.db.profile
    local defaults = FocalPoint:GetDefaultDB()
    local units = profile and profile.Units
    local defaultUnits = defaults and defaults.profile and defaults.profile.Units

    if not units or not defaultUnits then
        return
    end

    local keysToCopy = {
        "showClassPowerBar",
        "classPowerBarHeight",
        "classPowerBarWidth",
        "classPowerBarSpacing",
        "classPowerBarAnchorTo",
        "classPowerBarPoint",
        "classPowerBarRelativePoint",
        "classPowerBarOffsetX",
        "classPowerBarOffsetY",
        "classPowerBarTexture",
        "classPowerColor",
        "classPowerBackgroundColor",
    }

    for unitKey, unitDefaults in pairs(defaultUnits) do
        local unitDB = units[unitKey]
        if type(unitDB) == "table" and type(unitDefaults) == "table" then
            for _, key in ipairs(keysToCopy) do
                if unitDB[key] == nil and unitDefaults[key] ~= nil then
                    if type(unitDefaults[key]) == "table" then
                        unitDB[key] = CopyTable(unitDefaults[key])
                    else
                        unitDB[key] = unitDefaults[key]
                    end
                end
            end
        end
    end
end

local function EnsureStatusIndicatorEffectDefaults()
    if not FocalPoint.db or not FocalPoint.db.profile or not FocalPoint.GetDefaultDB then
        return
    end

    local profile = FocalPoint.db.profile
    local defaults = FocalPoint:GetDefaultDB()
    local units = profile and profile.Units
    local defaultUnits = defaults and defaults.profile and defaults.profile.Units

    if type(units) ~= "table" or type(defaultUnits) ~= "table" then
        return
    end

    for unitKey, unitDefaults in pairs(defaultUnits) do
        local unitDB = units[unitKey]
        if type(unitDB) == "table" and type(unitDefaults) == "table" then
            for _, indicatorKey in ipairs({ "CombatIndicator", "RestingIndicator" }) do
                local indicatorDB = unitDB[indicatorKey]
                local indicatorDefaults = unitDefaults[indicatorKey]
                if type(indicatorDB) == "table" and type(indicatorDefaults) == "table" and indicatorDB.effect == nil then
                    indicatorDB.effect = indicatorDefaults.effect or "ICON"
                end
            end
        end
    end
end

local function MigrateClassificationIndicatorEffects()
    if not FocalPoint.db or not FocalPoint.db.profile or type(FocalPoint.db.profile.Units) ~= "table" then
        return
    end

    for _, unitDB in pairs(FocalPoint.db.profile.Units) do
        local indicatorConfig = type(unitDB) == "table" and unitDB.ClassificationIndicator or nil
        if type(indicatorConfig) == "table" and indicatorConfig.effect == "NAME_LABEL" then
            indicatorConfig.effect = "PORTRAIT_OVERLAY"
        end
    end
end

local function EnsureCastBarInterruptibleColorDefaults()
    if not FocalPoint.db or not FocalPoint.db.profile or not FocalPoint.GetDefaultDB then
        return
    end

    local profile = FocalPoint.db.profile
    local defaults = FocalPoint:GetDefaultDB()
    local units = profile and profile.Units
    local defaultUnits = defaults and defaults.profile and defaults.profile.Units

    if not units or not defaultUnits then
        return
    end

    for unitKey, unitDefaults in pairs(defaultUnits) do
        local unitDB = units[unitKey]
        if type(unitDB) == "table" and type(unitDefaults) == "table" then
            if unitDB.castBarInterruptibleColor == nil then
                if unitDB.castBarUninterruptibleColor ~= nil then
                    unitDB.castBarInterruptibleColor = CopyTable(unitDB.castBarUninterruptibleColor)
                elseif unitDefaults.castBarInterruptibleColor ~= nil then
                    unitDB.castBarInterruptibleColor = CopyTable(unitDefaults.castBarInterruptibleColor)
                end
            end
        end
    end
end

local function EnsureTextTemplateDefaults()
    if not FocalPoint.db or not FocalPoint.db.profile or not FocalPoint.GetDefaultDB then
        return
    end

    local profile = FocalPoint.db.profile
    local defaults = FocalPoint:GetDefaultDB()
    local defaultTemplates = defaults and defaults.profile and defaults.profile.TextTemplates
    if type(defaultTemplates) ~= "table" then
        return
    end

    profile.TextTemplates = profile.TextTemplates or {}

    for templateName, templateValue in pairs(defaultTemplates) do
        if profile.TextTemplates[templateName] == nil then
            profile.TextTemplates[templateName] = templateValue
        end
    end
end

local function NormalizeLegacyTextTemplateNames()
    if not FocalPoint.db or not FocalPoint.db.profile then
        return
    end

    local profile = FocalPoint.db.profile
    local templates = profile.TextTemplates
    local units = profile.Units
    if type(templates) ~= "table" then
        return
    end

    local renameMap = {
        ["Sparta's Unit Frame - Health"] = "Health",
        ["Sparta's Unit Frame - Alt Power"] = "Alt Power",
        ["Sparta's Unit Frame - Player Level and Class"] = "Player Level and Class",
        ["Sparta's Unit Frame - Creature"] = "Creature",
        ["Sparta's Unit Frame - Status"] = "Status",
        ["Sparta's Unit Frame - Cast Name"] = "Cast Name",
        ["Sparta's Unit Frame - Cast Time"] = "Cast Time",
    }

    for legacyName, newName in pairs(renameMap) do
        if templates[legacyName] ~= nil then
            if templates[newName] == nil then
                templates[newName] = templates[legacyName]
            end
            templates[legacyName] = nil
        end
    end

    if type(units) ~= "table" then
        return
    end

    for _, unitConfig in pairs(units) do
        local texts = type(unitConfig) == "table" and unitConfig.Texts or nil
        if type(texts) == "table" then
            for _, textConfig in pairs(texts) do
                if type(textConfig) == "table" then
                    local templateName = textConfig.templateName
                    if type(templateName) == "string" and renameMap[templateName] then
                        textConfig.templateName = renameMap[templateName]
                    end

                    local stateTemplates = textConfig.stateTemplates
                    if type(stateTemplates) == "table" then
                        for stateKey, stateTemplateName in pairs(stateTemplates) do
                            if type(stateTemplateName) == "string" and renameMap[stateTemplateName] then
                                stateTemplates[stateKey] = renameMap[stateTemplateName]
                            end
                        end
                    end
                end
            end
        end
    end
end

local function EnsureTextTemplateLinks()
    if not FocalPoint.db or not FocalPoint.db.profile then
        return
    end

    local profile = FocalPoint.db.profile
    local templates = profile.TextTemplates
    local units = profile.Units
    local defaults = FocalPoint.GetDefaultDB and FocalPoint:GetDefaultDB()
    local defaultUnits = defaults and defaults.profile and defaults.profile.Units

    if type(templates) ~= "table" or type(units) ~= "table" then
        return
    end

    local function ResolveDefaultTemplateName(unitKey, textKey)
        if textKey == "Name" then
            if unitKey == "player" then
                return "Unit Name Player"
            elseif unitKey == "targettarget" then
                return "Unit Name Target"
            elseif unitKey == "focustarget" then
                return "Unit Name Focus"
            elseif unitKey == "focus" then
                return "Unit Name Focus"
            elseif unitKey == "target" then
                return "Unit Name Target"
            end

            return nil
        end

        if textKey == "Health" then
            return "Health"
        end

        if textKey == "Power" then
            return "Power"
        end

        if textKey == "AltPower" then
            return "Alt Power"
        end

        if textKey == "ClassPower" then
            return "Class Power"
        end

        if textKey == "Class" and unitKey == "player" then
            return "Player Level and Class"
        end

        if textKey == "Status" then
            return "Status"
        end

        if textKey == "CastName" then
            return "Cast Name"
        end

        if textKey == "CastTime" then
            return "Cast Time"
        end

        if textKey == "Race" then
            if unitKey == "target" then
                return "Target Level and Class"
            elseif unitKey == "targettarget" then
                return "Target Level and Class"
            elseif unitKey == "focustarget" then
                return "Focus Level and Class"
            elseif unitKey == "focus" then
                return "Focus Level and Class"
            elseif unitKey ~= "player" then
                return "Creature"
            end
        end

        return nil
    end

    local function IsAutoLinkedLegacyTextKey(textKey)
        return textKey == "Name"
            or textKey == "Health"
            or textKey == "Power"
            or textKey == "AltPower"
            or textKey == "ClassPower"
            or textKey == "Class"
            or textKey == "Status"
            or textKey == "CastName"
            or textKey == "CastTime"
            or textKey == "Race"
    end

    for unitKey, unitConfig in pairs(units) do
        local texts = type(unitConfig) == "table" and unitConfig.Texts or nil
        local defaultTexts = defaultUnits and defaultUnits[unitKey] and defaultUnits[unitKey].Texts
        if type(texts) == "table" then
            for textKey, textConfig in pairs(texts) do
                if type(textConfig) == "table" and IsAutoLinkedLegacyTextKey(textKey) then
                    local currentTemplateName = textConfig.templateName
                    local currentTag = textConfig.tag

                    if (type(currentTemplateName) ~= "string" or currentTemplateName == "")
                        and type(currentTag) == "string"
                        and currentTag ~= ""
                    then
                        for templateName, templateValue in pairs(templates) do
                            if templateValue == currentTag then
                                textConfig.templateName = templateName
                                break
                            end
                        end

                        if (type(textConfig.templateName) ~= "string" or textConfig.templateName == "")
                            and type(defaultTexts) == "table"
                            and type(defaultTexts[textKey]) == "table"
                            and defaultTexts[textKey].tag == currentTag
                        then
                            local mappedTemplateName = ResolveDefaultTemplateName(unitKey, textKey)
                            if type(mappedTemplateName) == "string" and type(templates[mappedTemplateName]) == "string" then
                                textConfig.templateName = mappedTemplateName
                            end
                        end
                    end
                end
            end
        end
    end
end

local function EnsureCoreTextDefaults()
    if not FocalPoint.db or not FocalPoint.db.profile or not FocalPoint.GetDefaultDB then
        return
    end

    local profile = FocalPoint.db.profile
    local defaults = FocalPoint:GetDefaultDB()
    local units = profile and profile.Units
    local defaultUnits = defaults and defaults.profile and defaults.profile.Units

    if type(units) ~= "table" or type(defaultUnits) ~= "table" then
        return
    end

    local function IsCoreLegacyTextKey(textKey)
        return textKey == "Name"
            or textKey == "Health"
            or textKey == "Power"
            or textKey == "AltPower"
            or textKey == "ClassPower"
            or textKey == "Class"
            or textKey == "Race"
            or textKey == "Status"
            or textKey == "CastName"
            or textKey == "CastTime"
    end

    for unitKey, unitDefaults in pairs(defaultUnits) do
        local unitDB = units[unitKey]
        local defaultTexts = type(unitDefaults) == "table" and unitDefaults.Texts or nil
        if type(unitDB) == "table" and type(defaultTexts) == "table" then
            unitDB.Texts = unitDB.Texts or {}

            for textKey, defaultText in pairs(defaultTexts) do
                if type(defaultText) == "table" and IsCoreLegacyTextKey(textKey) then
                    local textDB = unitDB.Texts[textKey]
                    if textDB == nil then
                        unitDB.Texts[textKey] = CopyTable(defaultText)
                    elseif type(textDB) == "table" then
                        local hasTemplate = type(textDB.templateName) == "string" and textDB.templateName ~= ""
                        local hasTag = type(textDB.tag) == "string" and textDB.tag ~= ""
                        local defaultHasTemplate = type(defaultText.templateName) == "string" and defaultText.templateName ~= ""
                        local defaultHasTag = type(defaultText.tag) == "string" and defaultText.tag ~= ""

                        if not hasTemplate and not hasTag then
                            if defaultHasTemplate then
                                textDB.templateName = defaultText.templateName
                            end
                            if defaultHasTag then
                                textDB.tag = defaultText.tag
                            end
                            if textDB.enabled == false and defaultText.enabled == true then
                                textDB.enabled = true
                            end
                        end
                    end
                end
            end
        end
    end
end

local function EnsureNoEmptyTextElements()
    if not FocalPoint.db or not FocalPoint.db.profile or type(FocalPoint.db.profile.Units) ~= "table" then
        return
    end

    for _, unitConfig in pairs(FocalPoint.db.profile.Units) do
        local texts = type(unitConfig) == "table" and unitConfig.Texts or nil
        if type(texts) == "table" then
            for _, textConfig in pairs(texts) do
                if type(textConfig) == "table" then
                    local templateName = textConfig.templateName
                    local tag = textConfig.tag
                    local hasTemplate = type(templateName) == "string" and templateName ~= ""
                    local hasTag = type(tag) == "string" and tag ~= ""

                    if not hasTemplate and not hasTag then
                        textConfig.enabled = false
                    end
                end
            end
        end
    end
end

local function NormalizeStateTemplateSignature(stateTemplates)
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
            if NormalizeStateTemplateSignature(value) ~= "" then
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

local function IsGeneratedTextId(textId)
    return type(textId) == "string" and textId:match("^text_%d+$") ~= nil
end

local function IsLegacyCustomTextId(textId)
    return type(textId) == "string" and textId:match("^Custom%d+$") ~= nil
end

local function RemoveLegacyDuplicateTextElements()
    if not FocalPoint.db or not FocalPoint.db.profile or type(FocalPoint.db.profile.Units) ~= "table" then
        return
    end

    for _, unitConfig in pairs(FocalPoint.db.profile.Units) do
        local texts = type(unitConfig) == "table" and unitConfig.Texts or nil
        if type(texts) == "table" then
            local templateOwners = {}

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
                            and not IsGeneratedTextId(textId)
                            and not IsLegacyCustomTextId(textId)
                        then
                            hasCanonicalLegacy = true
                            break
                        end
                    end

                    if hasCanonicalLegacy then
                        for _, textId in ipairs(owners) do
                            local textConfig = texts[textId]
                            if type(textConfig) == "table" then
                                if IsGeneratedTextId(textId) and textConfig.enabled == false then
                                    texts[textId] = nil
                                elseif IsLegacyCustomTextId(textId) and CountMeaningfulTextFields(textConfig) <= 1 then
                                    texts[textId] = nil
                                end
                            end
                        end
                    end
                end
            end
        end
    end
end

local function InitRangeCheck()
    FocalPoint.RangeCheck = LibStub("LibRangeCheck-3.0", true)
    FocalPoint.targetRangeChecker = nil
    FocalPoint.targetRangeCheckerCombat = nil
end

function FocalPoint:GetTargetRangeChecker()
    if not self.RangeCheck or not self.RangeCheck.GetSmartMaxChecker then
        return nil
    end

    local inCombat = InCombatLockdown and InCombatLockdown() or false
    if self.targetRangeChecker and self.targetRangeCheckerCombat == inCombat then
        return self.targetRangeChecker
    end

    self.targetRangeChecker = self.RangeCheck:GetSmartMaxChecker(TARGET_RANGE_CHECK_YARDS, inCombat)
    self.targetRangeCheckerCombat = inCombat
    return self.targetRangeChecker
end

function FocalPointAddon:OnInitialize()
    FocalPoint.db = LibStub("AceDB-3.0"):New("FocalPointDB", FocalPoint:GetDefaultDB(), true)
    EnsureImageElementDefaults()
    EnsureBarTextureDefaults()
    EnsureExpandedUnitDefaults("targettarget")
    EnsureExpandedUnitDefaults("focus")
    EnsureExpandedUnitDefaults("focustarget")
    EnsureDerivedUnitDefaults("boss", "targettarget", function(unitConfig)
        unitConfig.enabled = true
        unitConfig.point = "TOPRIGHT"
        unitConfig.relativeTo = "UIParent"
        unitConfig.relativePoint = "TOPRIGHT"
        unitConfig.x = -340
        unitConfig.y = -170
        unitConfig.bossSpacing = 10
        unitConfig.Portrait = unitConfig.Portrait or {}
        unitConfig.Portrait.enabled = true
        unitConfig.Portrait.placement = unitConfig.Portrait.placement or "INSIDE"
        unitConfig.Portrait.insideSide = unitConfig.Portrait.insideSide or "LEFT"
    end)
    EnsureCastTextDefaults()
    EnsureAlternativePowerDefaults()
    EnsureClassPowerDefaults()
    EnsureStatusIndicatorEffectDefaults()
    MigrateClassificationIndicatorEffects()
    EnsureCastBarInterruptibleColorDefaults()
    EnsureTextTemplateDefaults()
    NormalizeLegacyTextTemplateNames()
    EnsureTextTemplateLinks()
    EnsureCoreTextDefaults()
    EnsureNoEmptyTextElements()
    RemoveLegacyDuplicateTextElements()
    InitRangeCheck()

    FocalPoint.LDS = FocalPoint.LDS or LibStub("LibDualSpec-1.0", true)
    if FocalPoint.LDS then
        FocalPoint.LDS:EnhanceDatabase(FocalPoint.db, "FocalPoint")
    end

    if FocalPoint.db and FocalPoint.db.RegisterCallback then
        local function HandleProfileRuntimeRefresh()
            if FocalPoint.RebuildFramesForActiveProfile then
                FocalPoint:RebuildFramesForActiveProfile()
            end
        end

        FocalPoint.db.RegisterCallback(FocalPoint, "OnProfileChanged", HandleProfileRuntimeRefresh)
        FocalPoint.db.RegisterCallback(FocalPoint, "OnProfileCopied", HandleProfileRuntimeRefresh)
        FocalPoint.db.RegisterCallback(FocalPoint, "OnProfileReset", HandleProfileRuntimeRefresh)
    end

    FocalPoint.TAG_UPDATE_INTERVAL = FocalPoint.db.profile.General.TagUpdateInterval or 0.25
    FocalPoint.SEPARATOR = FocalPoint.db.profile.General.Separator or "||"
    FocalPoint.TOT_SEPARATOR = FocalPoint.db.profile.General.ToTSeparator or "»"

    if FocalPoint.InitMinimapIcon then
        FocalPoint:InitMinimapIcon()
    end
end

function FocalPointAddon:OnEnable()
    FocalPoint.startupDiagnostics = {}

    local function RunStartupStep(label, fn)
        if type(fn) ~= "function" then
            FocalPoint.startupDiagnostics[tostring(label)] = {
                ok = false,
                message = "missing-function",
            }
            return true
        end

        local ok, err = pcall(fn)
        if not ok then
            FocalPoint.startupDiagnostics[tostring(label)] = {
                ok = false,
                message = tostring(err),
            }
            FocalPoint:Warn(string.format("Startup step failed: %s -> %s", tostring(label), tostring(err)))
            return false
        end

        FocalPoint.startupDiagnostics[tostring(label)] = {
            ok = true,
            message = "ok",
        }
        return true
    end

    RunStartupStep("Init", function()
        FocalPoint:Init()
    end)

    RunStartupStep("SetupSlashCommands", function()
        FocalPoint:SetupSlashCommands()
    end)

    RunStartupStep("CreatePositionController", function()
        FocalPoint:CreatePositionController()
    end)

    RunStartupStep("StartTagTicker", function()
        FocalPoint:StartTagTicker()
    end)

    RunStartupStep("SpawnUnitFrame(player)", function()
        FocalPoint:SpawnUnitFrame("player")
    end)

    RunStartupStep("SpawnUnitFrame(target)", function()
        FocalPoint:SpawnUnitFrame("target")
    end)

    RunStartupStep("SpawnUnitFrame(targettarget)", function()
        FocalPoint:SpawnUnitFrame("targettarget")
    end)

    RunStartupStep("SpawnUnitFrame(focus)", function()
        FocalPoint:SpawnUnitFrame("focus")
    end)

    RunStartupStep("SpawnUnitFrame(focustarget)", function()
        FocalPoint:SpawnUnitFrame("focustarget")
    end)

    RunStartupStep("SpawnUnitFrame(pet)", function()
        FocalPoint:SpawnUnitFrame("pet")
    end)

    for bossIndex = 1, 5 do
        local bossUnit = "boss" .. bossIndex
        RunStartupStep("SpawnUnitFrame(" .. bossUnit .. ")", function()
            FocalPoint:SpawnUnitFrame(bossUnit)
        end)
    end

    RunStartupStep("ApplyGeneralSettings", function()
        FocalPoint:ApplyGeneralSettings()
    end)

    local postWorldInit = CreateFrame("Frame")
    postWorldInit:RegisterEvent("PLAYER_ENTERING_WORLD")
    postWorldInit:SetScript("OnEvent", function(self)
        self:UnregisterAllEvents()
        self:SetScript("OnEvent", nil)

        RunStartupStep("PostWorld ApplyGeneralSettings", function()
            FocalPoint:ApplyGeneralSettings()
        end)

        RunStartupStep("PostWorld RefreshAllUnitFrames", function()
            FocalPoint:RefreshAllUnitFrames()
        end)
    end)
end

function FocalPoint:EnsureBossFrames()
    if not self.SpawnUnitFrame then
        return
    end

    local bossConfig = self.UnitFrameUtils and self.UnitFrameUtils.GetUnitDB and self.UnitFrameUtils.GetUnitDB("boss")
    if type(bossConfig) ~= "table" or bossConfig.enabled == false then
        return
    end

    self.frames = self.frames or {}

    for bossIndex = 1, 5 do
        local bossUnit = "boss" .. bossIndex
        if not self.frames[bossUnit] then
            self:SpawnUnitFrame(bossUnit)
        end
    end
end

function FocalPoint:RefreshAllUnitFrames()
    self:EnsureBossFrames()

    if not self.frames then
        return
    end

    for unit in pairs(self.frames) do
        self:RefreshUnitFrame(unit)
    end
end

function FocalPoint:ApplyGeneralSettings()
    local general = self.db and self.db.profile and self.db.profile.General
    if not general then
        return
    end

    RefreshBlizzardFrameMouseState(general.HideBlizzardFrames == true)
    ApplyBlizzardFrameVisibility(general.HideBlizzardFrames == true)
end

local function SafeBool(value)
    local ok, result = pcall(function()
        return type(value) == "boolean" and not (issecretvalue and issecretvalue(value)) and value or false
    end)
    return ok and result or false
end

local function SafeNumber(value)
    local ok, result = pcall(function()
        return tonumber(value)
    end)
    if ok and type(result) == "number" and not (issecretvalue and issecretvalue(result)) then
        return result
    end
    return nil
end

local function SafePointText(frame)
    if not frame or not frame.GetPoint then
        return "point=?"
    end

    local ok, point, relativeTo, relativePoint, x, y = pcall(frame.GetPoint, frame, 1)
    if not ok then
        return "point=?"
    end

    local relativeName = "?"
    if type(relativeTo) == "table" and relativeTo.GetName then
        relativeName = relativeTo:GetName() or "anonymous"
    elseif type(relativeTo) == "string" then
        relativeName = relativeTo
    end

    x = SafeNumber(x) or 0
    y = SafeNumber(y) or 0

    return string.format("%s->%s@%s(%d,%d)", tostring(point or "?"), tostring(relativeName), tostring(relativePoint or "?"), x, y)
end

function FocalPoint:DumpRuntimeDiagnostics()
    local general = self.db and self.db.profile and self.db.profile.General or {}
    self:Info(string.format(
        "Diag general: hideBlizz=%s mouse=%s unlocked=%s disabled=%s",
        tostring(general.HideBlizzardFrames == true),
        tostring(general.MouseEnabled ~= false),
        tostring(self.framesUnlocked == true),
        tostring(self.blizzardFramesDisabled == true)
    ))

    for _, label in ipairs({
        "Init",
        "SetupSlashCommands",
        "CreatePositionController",
        "StartTagTicker",
        "SpawnUnitFrame(player)",
        "SpawnUnitFrame(target)",
        "SpawnUnitFrame(targettarget)",
        "SpawnUnitFrame(focus)",
        "SpawnUnitFrame(focustarget)",
        "SpawnUnitFrame(pet)",
        "SpawnUnitFrame(boss1)",
        "SpawnUnitFrame(boss2)",
        "SpawnUnitFrame(boss3)",
        "SpawnUnitFrame(boss4)",
        "SpawnUnitFrame(boss5)",
        "ApplyGeneralSettings",
        "PostWorld ApplyGeneralSettings",
        "PostWorld RefreshAllUnitFrames",
    }) do
        local step = self.startupDiagnostics and self.startupDiagnostics[label] or nil
        if step then
            self:Info(string.format(
                "Diag startup %s: ok=%s msg=%s",
                tostring(label),
                tostring(step.ok == true),
                tostring(step.message or "?")
            ))
        end
    end

    for _, unit in ipairs({ "player", "target", "targettarget", "focus", "focustarget", "boss1", "boss2", "boss3", "boss4", "boss5" }) do
        local unitDB = self.UnitFrameUtils and self.UnitFrameUtils.GetUnitDB and self.UnitFrameUtils.GetUnitDB(unit) or {}
        local frame = self.frames and self.frames[unit] or nil
        local exists = UnitExists and SafeBool(UnitExists(unit)) or false
        local shown = frame and frame.IsShown and SafeBool(frame:IsShown()) or false
        local alpha = frame and frame.GetAlpha and SafeNumber(frame:GetAlpha()) or nil
        local spawnDiag = self.spawnDiagnostics and self.spawnDiagnostics[unit] or nil

        self:Info(string.format(
            "Diag %s db: enabled=%s point=%s rel=%s x=%s y=%s scale=%s size=%sx%s",
            unit,
            tostring(type(unitDB) == "table" and unitDB.enabled ~= false),
            tostring(type(unitDB) == "table" and unitDB.point or "?"),
            tostring(type(unitDB) == "table" and unitDB.relativePoint or "?"),
            tostring(type(unitDB) == "table" and unitDB.x or "?"),
            tostring(type(unitDB) == "table" and unitDB.y or "?"),
            tostring(type(unitDB) == "table" and unitDB.scale or "?"),
            tostring(type(unitDB) == "table" and unitDB.width or "?"),
            tostring(type(unitDB) == "table" and unitDB.height or "?")
        ))

        self:Info(string.format(
            "Diag %s frame: exists=%s spawned=%s shown=%s alpha=%s overlay=%s point=%s",
            unit,
            tostring(exists),
            tostring(frame ~= nil),
            tostring(shown),
            alpha and string.format("%.2f", alpha) or "?",
            tostring(frame and frame.MoveOverlay and frame.MoveOverlay:IsShown() or false),
            SafePointText(frame)
        ))

        if spawnDiag then
            self:Info(string.format(
                "Diag %s spawn: ok=%s config=%s enabled=%s reason=%s",
                unit,
                tostring(spawnDiag.ok == true),
                tostring(spawnDiag.hasConfig == true),
                tostring(spawnDiag.enabled == true),
                tostring(spawnDiag.reason or "?")
            ))
        end
    end

    for _, frameName in ipairs({ "PlayerFrame", "TargetFrame", "TargetFrameContainer" }) do
        local frame = _G[frameName]
        if frame then
            local shown = frame.IsShown and SafeBool(frame:IsShown()) or false
            local alpha = frame.GetAlpha and SafeNumber(frame:GetAlpha()) or nil
            local parentName = frame.GetParent and frame:GetParent() and frame:GetParent():GetName() or "?"
            self:Info(string.format(
                "Diag blizz %s: shown=%s alpha=%s parent=%s",
                frameName,
                tostring(shown),
                alpha and string.format("%.2f", alpha) or "?",
                tostring(parentName or "?")
            ))
        end
    end
end
