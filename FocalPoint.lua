local ADDON_NAME, FocalPoint = ...

FocalPoint.ADDON_NAME = "FocalPoint"
FocalPoint.frames = FocalPoint.frames or {}

local AceLocale = LibStub("AceLocale-3.0")
FocalPoint.L = AceLocale:GetLocale("FocalPoint", true) or FocalPoint.L or {}

local TARGET_RANGE_CHECK_YARDS = 20
FocalPoint.TARGET_RANGE_CHECK_YARDS = TARGET_RANGE_CHECK_YARDS

local function PrintToChat(prefix, message)
    if type(message) ~= "string" or message == "" then
        return
    end

    local text = string.format("|cff6fd2ffFocalPoint|r %s%s", prefix or "", message)
    if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
        DEFAULT_CHAT_FRAME:AddMessage(text)
    end
end

function FocalPoint:Info(message)
    PrintToChat("", message)
end

function FocalPoint:Warn(message)
    PrintToChat("|cffff7b7b|r ", message)
end

function FocalPoint:Success(message)
    PrintToChat("|cff72e06a|r ", message)
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

local function ApplyBlizzardFrameVisibility(hidden)
    if not hidden then
        return
    end

    local oUF = FocalPoint.oUF
    if not (oUF and oUF.DisableBlizzard) then
        return
    end

    if FocalPoint.blizzardFramesDisabled then
        return
    end

    for _, unit in ipairs(BLIZZARD_UNIT_FRAMES) do
        oUF:DisableBlizzard(unit)
    end

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
            return "Sparta's Unit Frame - Name"
        end

        if textKey == "Health" then
            return "Sparta's Unit Frame - Health"
        end

        if textKey == "Power" then
            if unitKey == "player" then
                return "Sparta's Unit Frame - Player Power"
            end

            return "Sparta's Unit Frame - Target Power"
        end

        if textKey == "AltPower" then
            return "Sparta's Unit Frame - Alt Power"
        end

        if textKey == "Status" then
            return "Sparta's Unit Frame - Status"
        end

        if textKey == "CastName" then
            return "Sparta's Unit Frame - Cast Name"
        end

        if textKey == "CastTime" then
            return "Sparta's Unit Frame - Cast Time"
        end

        if textKey == "Race" and unitKey ~= "player" then
            return "Sparta's Unit Frame - Creature"
        end

        return nil
    end

    for unitKey, unitConfig in pairs(units) do
        local texts = type(unitConfig) == "table" and unitConfig.Texts or nil
        local defaultTexts = defaultUnits and defaultUnits[unitKey] and defaultUnits[unitKey].Texts
        if type(texts) == "table" then
            for textKey, textConfig in pairs(texts) do
                if type(textConfig) == "table" then
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
    EnsureCastTextDefaults()
    EnsureAlternativePowerDefaults()
    EnsureTextTemplateDefaults()
    EnsureTextTemplateLinks()
    EnsureNoEmptyTextElements()
    InitRangeCheck()

    FocalPoint.LDS = FocalPoint.LDS or LibStub("LibDualSpec-1.0", true)
    if FocalPoint.LDS then
        FocalPoint.LDS:EnhanceDatabase(FocalPoint.db, "FocalPoint")
    end

    FocalPoint.TAG_UPDATE_INTERVAL = FocalPoint.db.profile.General.TagUpdateInterval or 0.25
    FocalPoint.SEPARATOR = FocalPoint.db.profile.General.Separator or "||"
    FocalPoint.TOT_SEPARATOR = FocalPoint.db.profile.General.ToTSeparator or "»"

    if FocalPoint.InitMinimapIcon then
        FocalPoint:InitMinimapIcon()
    end
end

function FocalPointAddon:OnEnable()
    if FocalPoint.Init then
        FocalPoint:Init()
    end

    if FocalPoint.SetupSlashCommands then
        FocalPoint:SetupSlashCommands()
    end

    if FocalPoint.CreatePositionController then
        FocalPoint:CreatePositionController()
    end

    if FocalPoint.StartTagTicker then
        FocalPoint:StartTagTicker()
    end

    if FocalPoint.SpawnUnitFrame then
        FocalPoint:SpawnUnitFrame("player")
        FocalPoint:SpawnUnitFrame("target")
        FocalPoint:SpawnUnitFrame("pet")
    end

    if FocalPoint.ApplyGeneralSettings then
        FocalPoint:ApplyGeneralSettings()
    end
end

function FocalPoint:RefreshAllUnitFrames()
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
