local ADDON_NAME, PORTRAIT = ...

PORTRAIT.ADDON_NAME = ADDON_NAME
PORTRAIT.frames = PORTRAIT.frames or {}

local AceLocale = LibStub("AceLocale-3.0")
PORTRAIT.L = AceLocale:GetLocale("Portrait", true) or {}

local PortraitAddon = LibStub("AceAddon-3.0"):NewAddon("Portrait", "AceConsole-3.0")
PORTRAIT.Ace = PortraitAddon

function PortraitAddon:OnInitialize()
    PORTRAIT.db = LibStub("AceDB-3.0"):New("PortraitDB", PORTRAIT:GetDefaultDB(), true)

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
end