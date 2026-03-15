local ADDON_NAME, PORTRAIT = ...

PORTRAIT.ADDON_NAME = ADDON_NAME
PORTRAIT.frames = PORTRAIT.frames or {}

local AceLocale = LibStub("AceLocale-3.0")
PORTRAIT.L = AceLocale:GetLocale("Portrait", true) or {}

local PortraitAddon = LibStub("AceAddon-3.0"):NewAddon("Portrait")
PORTRAIT.Ace = PortraitAddon

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

    local oUF = PORTRAIT.oUF
    if not (oUF and oUF.DisableBlizzard) then
        return
    end

    if PORTRAIT.blizzardFramesDisabled then
        return
    end

    for _, unit in ipairs(BLIZZARD_UNIT_FRAMES) do
        oUF:DisableBlizzard(unit)
    end

    PORTRAIT.blizzardFramesDisabled = true
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
    if not PORTRAIT.db or not PORTRAIT.db.profile or not PORTRAIT.GetDefaultDB then
        return
    end

    local profile = PORTRAIT.db.profile
    local defaults = PORTRAIT:GetDefaultDB()
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
    if not PORTRAIT.db or not PORTRAIT.db.profile or not PORTRAIT.GetDefaultDB then
        return
    end

    local profile = PORTRAIT.db.profile
    local defaults = PORTRAIT:GetDefaultDB()
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
    if not PORTRAIT.db or not PORTRAIT.db.profile or not PORTRAIT.db.profile.Units then
        return
    end

    for _, unitKey in ipairs({ "player", "target" }) do
        local unitDB = PORTRAIT.db.profile.Units[unitKey]
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
    if not PORTRAIT.db or not PORTRAIT.db.profile or not PORTRAIT.GetDefaultDB then
        return
    end

    local profile = PORTRAIT.db.profile
    local defaults = PORTRAIT:GetDefaultDB()
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
    if not PORTRAIT.db or not PORTRAIT.db.profile or not PORTRAIT.GetDefaultDB then
        return
    end

    local profile = PORTRAIT.db.profile
    local defaults = PORTRAIT:GetDefaultDB()
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
    if not PORTRAIT.db or not PORTRAIT.db.profile then
        return
    end

    local profile = PORTRAIT.db.profile
    local templates = profile.TextTemplates
    local units = profile.Units
    local defaults = PORTRAIT.GetDefaultDB and PORTRAIT:GetDefaultDB()
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
    if not PORTRAIT.db or not PORTRAIT.db.profile or type(PORTRAIT.db.profile.Units) ~= "table" then
        return
    end

    for _, unitConfig in pairs(PORTRAIT.db.profile.Units) do
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

function PortraitAddon:OnInitialize()
    PORTRAIT.db = LibStub("AceDB-3.0"):New("PortraitDB", PORTRAIT:GetDefaultDB(), true)
    EnsureImageElementDefaults()
    EnsureBarTextureDefaults()
    EnsureCastTextDefaults()
    EnsureAlternativePowerDefaults()
    EnsureTextTemplateDefaults()
    EnsureTextTemplateLinks()
    EnsureNoEmptyTextElements()

    PORTRAIT.LDS = PORTRAIT.LDS or LibStub("LibDualSpec-1.0", true)
    if PORTRAIT.LDS then
        PORTRAIT.LDS:EnhanceDatabase(PORTRAIT.db, "Portrait")
    end

    PORTRAIT.TAG_UPDATE_INTERVAL = PORTRAIT.db.profile.General.TagUpdateInterval or 0.25
    PORTRAIT.SEPARATOR = PORTRAIT.db.profile.General.Separator or "||"
    PORTRAIT.TOT_SEPARATOR = PORTRAIT.db.profile.General.ToTSeparator or "»"

    if PORTRAIT.InitMinimapIcon then
        PORTRAIT:InitMinimapIcon()
    end
end

function PortraitAddon:OnEnable()
    if PORTRAIT.Init then
        PORTRAIT:Init()
    end

    if PORTRAIT.SetupSlashCommands then
        PORTRAIT:SetupSlashCommands()
    end

    if PORTRAIT.CreatePositionController then
        PORTRAIT:CreatePositionController()
    end

    if PORTRAIT.StartTagTicker then
        PORTRAIT:StartTagTicker()
    end

    if PORTRAIT.SpawnUnitFrame then
        PORTRAIT:SpawnUnitFrame("player")
        PORTRAIT:SpawnUnitFrame("target")
        PORTRAIT:SpawnUnitFrame("pet")
    end

    if PORTRAIT.ApplyGeneralSettings then
        PORTRAIT:ApplyGeneralSettings()
    end
end

function PORTRAIT:RefreshAllUnitFrames()
    if not self.frames then
        return
    end

    for unit in pairs(self.frames) do
        self:RefreshUnitFrame(unit)
    end
end

function PORTRAIT:ApplyGeneralSettings()
    local general = self.db and self.db.profile and self.db.profile.General
    if not general then
        return
    end

    RefreshBlizzardFrameMouseState(general.HideBlizzardFrames == true)
    ApplyBlizzardFrameVisibility(general.HideBlizzardFrames == true)
end
