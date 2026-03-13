local ADDON_NAME, PORTRAIT = ...

PORTRAIT.ADDON_NAME = ADDON_NAME
PORTRAIT.frames = PORTRAIT.frames or {}

local AceLocale = LibStub("AceLocale-3.0")
PORTRAIT.L = AceLocale:GetLocale("Portrait", true) or {}

local PortraitAddon = LibStub("AceAddon-3.0"):NewAddon("Portrait", "AceConsole-3.0")
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

function PortraitAddon:OnInitialize()
    PORTRAIT.db = LibStub("AceDB-3.0"):New("PortraitDB", PORTRAIT:GetDefaultDB(), true)
    EnsureImageElementDefaults()
    EnsureBarTextureDefaults()
    EnsureCastTextDefaults()

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
