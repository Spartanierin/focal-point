local _, Portrait = ...

Portrait.UnitFrame = Portrait.UnitFrame or {}
local UF = Portrait.UnitFrame

local function GetUnitDB(unit)
    local db = Portrait.db
    if not db or not db.profile or not db.profile.Units then
        return nil
    end
    return db.profile.Units[unit]
end

local function UnpackColor(color, fallback)
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

local function IsSafeTrue(value)
    return type(value) == "boolean" and not (issecretvalue and issecretvalue(value)) and value
end

local function ToSafeNumberValue(value)
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

local function FormatDisplayNumber(value)
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

local function ResolveBlizzardAbbreviation(rawValue, displayText)
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

local function IsUnitDeadByHealth(unit)
    if not unit or not UnitHealth or not UnitHealthMax then
        return false
    end

    local ok, result = pcall(function()
        local currentHealth = UnitHealth(unit)
        local maxHealth = UnitHealthMax(unit)
        return type(currentHealth) == "number"
            and type(maxHealth) == "number"
            and maxHealth > 0
            and currentHealth <= 0
    end)

    return ok and result == true
end

local function GetClassColorForUnit(unit, useReactionForNpc)
    if not unit or not UnitExists or not UnitExists(unit) or not UnitClass then
        return nil
    end

    if UnitIsPlayer and not UnitIsPlayer(unit) then
        if useReactionForNpc and UnitReaction and FACTION_BAR_COLORS then
            local reaction = UnitReaction("player", unit)
            local color = reaction and FACTION_BAR_COLORS[reaction] or nil
            if color then
                return color.r or color[1], color.g or color[2], color.b or color[3], 1
            end
        end

        return nil
    end

    local _, classToken = UnitClass(unit)
    if not classToken then
        return nil
    end

    local color = nil

    if CUSTOM_CLASS_COLORS and CUSTOM_CLASS_COLORS[classToken] then
        color = CUSTOM_CLASS_COLORS[classToken]
    elseif RAID_CLASS_COLORS and RAID_CLASS_COLORS[classToken] then
        color = RAID_CLASS_COLORS[classToken]
    end

    if not color then
        return nil
    end

    return color.r or color[1], color.g or color[2], color.b or color[3], 1
end

local function GetPowerColorForUnit(unit)
    if not unit or not UnitExists or not UnitExists(unit) or not UnitPowerType then
        return nil
    end

    local powerType = UnitPowerType(unit)
    if powerType == nil then
        return nil
    end

    local color = PowerBarColor and PowerBarColor[powerType]
    if not color then
        return nil
    end

    return color.r or color[1], color.g or color[2], color.b or color[3], 1
end

local function GetResolvedHealthBarColor(frame, config, currentHealth, maxHealth)
    local healthR, healthG, healthB, healthA = UnpackColor(config and config.healthColor, { 0.1, 0.8, 0.1, 1 })

    if config and config.useClassColorHealth then
        local classR, classG, classB, classA = GetClassColorForUnit(frame and frame.unit, config.useReactionColorNpcHealth)
        if classR and classG and classB then
            healthR, healthG, healthB, healthA = classR, classG, classB, classA or 1
        end
    end

    return healthR, healthG, healthB, healthA
end

local function GetCurrentHealthValues(frame)
    if not frame or not frame.unit then
        return 0, 1
    end

    local unit = frame.unit
    local unitExists = UnitExists and UnitExists(unit)
    local previewValues = Portrait.guiTestModeEnabled and UF:GetTestPreviewValues(frame) or nil

    if previewValues then
        return previewValues.healthCurrent or 100, previewValues.healthMax or 100
    end

    if unitExists and UnitHealth and UnitHealthMax then
        return UnitHealth(unit) or 0, UnitHealthMax(unit) or 1
    end

    return 0, 1
end

function UF:UpdateHealthBarValue(frame)
    if not frame or not frame.Elements or not frame.Elements.HealthBar then
        return
    end

    frame.LiveValues = frame.LiveValues or {}

    local currentHealth, maxHealth = GetCurrentHealthValues(frame)
    frame.Elements.HealthBar:SetMinMaxValues(0, maxHealth)
    frame.Elements.HealthBar:SetValue(currentHealth)

    frame.LiveValues.healthCurrentRaw = currentHealth
    frame.LiveValues.healthMaxRaw = maxHealth
    frame.LiveValues.healthCurrentSafe = ToSafeNumberValue(currentHealth)
    frame.LiveValues.healthMaxSafe = ToSafeNumberValue(maxHealth)
    frame.LiveValues.healthCurrentText = FormatDisplayNumber(currentHealth)
    frame.LiveValues.healthMaxText = FormatDisplayNumber(maxHealth)
    frame.LiveValues.healthCurrentAbbr = ResolveBlizzardAbbreviation(currentHealth, frame.LiveValues.healthCurrentText)
    frame.LiveValues.healthMaxAbbr = ResolveBlizzardAbbreviation(maxHealth, frame.LiveValues.healthMaxText)
end

function UF:UpdateHealthBarColor(frame)
    if not frame or not frame.Elements or not frame.Elements.HealthBar then
        return
    end

    local config = GetUnitDB(frame.unit)
    if not config then
        return
    end

    local healthR, healthG, healthB, healthA = GetResolvedHealthBarColor(
        frame,
        config,
        frame.LiveValues and frame.LiveValues.healthCurrentRaw,
        frame.LiveValues and frame.LiveValues.healthMaxRaw
    )
    frame.Elements.HealthBar:SetStatusBarColor(healthR, healthG, healthB, healthA)
end

function UF:RefreshHealthBar(frame)
    if not frame or not frame.Elements or not frame.Elements.HealthBar then
        return
    end

    self:UpdateHealthBarValue(frame)
    self:UpdateHealthBarColor(frame)
end

function UF:RefreshHealthText(frame)
    if not frame then
        return
    end

    if self.RefreshLiveValues then
        self:RefreshLiveValues(frame)
    end

    if self.UpdateTextElement then
        self:UpdateTextElement(frame, "Health")
    end
end

function UF:RefreshHealth(frame)
    if not frame then
        return
    end

    self:RefreshHealthBar(frame)
    self:RefreshHealthText(frame)
end

local function GetStatusBarTexture(path)
    if type(path) == "string" and path ~= "" then
        return path
    end
    return "Interface\\TargetingFrame\\UI-StatusBar"
end

local function GetFontPath(path)
    if type(path) == "string" and path ~= "" then
        return path
    end
    return STANDARD_TEXT_FONT
end

local TEST_PREVIEW_VALUES = {
    player = {
        healthCurrent = 146000,
        healthMax = 146000,
        powerCurrent = 84,
        powerMax = 100,
        altPowerCurrent = 72,
        altPowerMax = 100,
        name = "Spartanierin",
        level = 84,
        classToken = "WARRIOR",
        race = "Mensch",
        castName = "Schildschlag",
        castDuration = 2.5,
    },
    target = {
        healthCurrent = 108000,
        healthMax = 146000,
        powerCurrent = 42,
        powerMax = 100,
        altPowerCurrent = 0,
        altPowerMax = 0,
        name = "Zielattrappe",
        level = 83,
        classToken = "PALADIN",
        creature = "Humanoid",
        castName = "Frostblitz",
        castDuration = 2.5,
    },
    focus = {
        healthCurrent = 92000,
        healthMax = 120000,
        powerCurrent = 55,
        powerMax = 100,
        altPowerCurrent = 0,
        altPowerMax = 0,
        name = "Fokusziel",
        level = 83,
        classToken = "PRIEST",
        creature = "Humanoid",
        castName = "Heilung",
        castDuration = 2.5,
    },
    pet = {
        healthCurrent = 72000,
        healthMax = 90000,
        powerCurrent = 70,
        powerMax = 100,
        altPowerCurrent = 0,
        altPowerMax = 0,
        name = "Begleiter",
        level = 83,
        creature = "Wildtier",
    },
}

function UF:GetTestPreviewValues(frame)
    if not frame or not frame.unit then
        return nil
    end

    return TEST_PREVIEW_VALUES[frame.unit] or TEST_PREVIEW_VALUES.target or TEST_PREVIEW_VALUES.player
end

local SECONDARY_POWER_BAR_SPECS = {
    [258] = 0, -- Shadow Priest -> Mana
    [262] = 0, -- Elemental Shaman -> Mana
}

local function GetPlayerSpecializationID()
    if not GetSpecialization or not GetSpecializationInfo then
        return nil
    end

    local specializationIndex = GetSpecialization()
    if not specializationIndex then
        return nil
    end

    local specializationID = GetSpecializationInfo(specializationIndex)
    if type(specializationID) ~= "number" then
        return nil
    end

    return specializationID
end

local function GetSecondaryPowerTypeForUnit(unit)
    if unit ~= "player" then
        return nil
    end

    local specializationID = GetPlayerSpecializationID()
    if not specializationID then
        return nil
    end

    return SECONDARY_POWER_BAR_SPECS[specializationID]
end

local function GetSecondaryPowerValues(unit)
    local secondaryPowerType = GetSecondaryPowerTypeForUnit(unit)
    if secondaryPowerType == nil or not UnitPower or not UnitPowerMax then
        return nil, 0, 0
    end

    return secondaryPowerType, UnitPower(unit, secondaryPowerType) or 0, UnitPowerMax(unit, secondaryPowerType) or 0
end

local function ApplyCastBarStateColor(castBar, isInterruptible, baseColor)
    if not castBar then
        return
    end

    if isInterruptible == false then
        castBar:SetStatusBarColor(0.60, 0.60, 0.60, 1.00)
    else
        local r, g, b, a = UnpackColor(baseColor, { 1.00, 0.72, 0.18, 1.00 })
        castBar:SetStatusBarColor(r, g, b, a)
    end
end

local function BuildFontFlags(config)
    local flags = {}

    if config.outline then
        flags[#flags + 1] = "OUTLINE"
    end

    if config.thickOutline then
        flags[#flags + 1] = "THICKOUTLINE"
    end

    if config.monochrome then
        flags[#flags + 1] = "MONOCHROME"
    end

    return table.concat(flags, ",")
end

function UF:GetAnchorTarget(frame, anchorTo)
    if anchorTo == "HealthBar" then
        return frame.Elements.HealthBar or frame
    elseif anchorTo == "PowerBar" then
        return frame.Elements.PowerBar or frame
    elseif anchorTo == "AlternativePowerBar" then
        return frame.Elements.AlternativePowerBar or frame
    elseif anchorTo == "CastBar" then
        return frame.Elements.CastBar or frame
    elseif anchorTo == "Frame" then
        return frame
    end

    return frame
end


-- Frame
function UF:CreateBaseFrame(unit, config)
    local frameName = "Portrait_" .. unit:gsub("^%l", string.upper)
    local frame = CreateFrame("Button", frameName, UIParent, "SecureUnitButtonTemplate, BackdropTemplate")

    frame.unit = unit
    frame.config = config
    frame.Elements = {}
    frame.Texts = {}
    frame.Tags = {}
    frame.LiveValues = {}

    frame:RegisterForClicks("AnyUp")
    frame:SetAttribute("unit", unit)
    frame:SetAttribute("*type1", "target")
    frame:SetAttribute("*type2", "togglemenu")
    frame:SetAttribute("toggleForVehicle", true)
    frame:Hide()

    frame:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
        insets = { left = 0, right = 0, top = 0, bottom = 0 },
    })

    return frame
end

-- HealthBar
function UF:CreateHealthBar(frame)
    local health = CreateFrame("StatusBar", nil, frame)
    health:SetMinMaxValues(0, 100)

    local bg = health:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetTexture("Interface\\Buttons\\WHITE8X8")
    health.bg = bg

    frame.Elements.HealthBar = health
    frame.health = health
end

-- PowerBar
function UF:CreatePowerBar(frame)
    local power = CreateFrame("StatusBar", nil, frame)
    power:SetMinMaxValues(0, 100)

    local bg = power:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetTexture("Interface\\Buttons\\WHITE8X8")
    power.bg = bg

    frame.Elements.PowerBar = power
    frame.power = power
end

function UF:CreateAlternativePowerBar(frame)
    local power = CreateFrame("StatusBar", nil, frame)
    power:SetMinMaxValues(0, 100)
    power:SetFrameStrata(frame:GetFrameStrata())
    power:SetFrameLevel(frame:GetFrameLevel() + 3)

    local bg = power:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetTexture("Interface\\Buttons\\WHITE8X8")
    power.bg = bg

    frame.Elements.AlternativePowerBar = power
    frame.alternativePower = power
end

function UF:CreateCastBar(frame)
    local cast = CreateFrame("StatusBar", nil, frame)
    cast:SetMinMaxValues(0, 1)
    cast:SetFrameStrata(frame:GetFrameStrata())
    cast:SetFrameLevel(frame:GetFrameLevel() + 5)
    cast:Hide()

    local bg = cast:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetTexture("Interface\\Buttons\\WHITE8X8")
    cast.bg = bg

    local icon = cast:CreateTexture(nil, "ARTWORK")
    icon:Hide()
    cast.icon = icon

    cast.isCasting = false
    cast.isChannel = false
    cast.startTime = 0
    cast.endTime = 0

    frame.Elements.CastBar = cast
    frame.castBar = cast
end

function UF:RefreshUnitBarValues(frame)
    if not frame or not frame.unit then
        return
    end

    local unit = frame.unit
    local unitExists = UnitExists and UnitExists(unit)
    local previewValues = Portrait.guiTestModeEnabled and self:GetTestPreviewValues(frame) or nil
    frame.LiveValues = frame.LiveValues or {}
    frame.TestValues = previewValues
    local previousAltPowerVisible = frame.LiveValues.altPowerVisible

    if frame.Elements.HealthBar then
        self:RefreshHealthBar(frame)
    end

    if frame.Elements.PowerBar then
        local currentPower = 0
        local maxPower = 1

        if previewValues then
            currentPower = previewValues.powerCurrent or 65
            maxPower = previewValues.powerMax or 100
        elseif unitExists and UnitPower and UnitPowerMax then
            currentPower = UnitPower(unit) or 0
            maxPower = UnitPowerMax(unit) or 1
        end

        frame.Elements.PowerBar:SetMinMaxValues(0, maxPower)
        frame.Elements.PowerBar:SetValue(currentPower)

        frame.LiveValues.powerCurrentRaw = currentPower
        frame.LiveValues.powerMaxRaw = maxPower
        frame.LiveValues.powerCurrentText = FormatDisplayNumber(currentPower)
        frame.LiveValues.powerMaxText = FormatDisplayNumber(maxPower)
        frame.LiveValues.powerCurrentSafe = ToSafeNumberValue(currentPower)
        frame.LiveValues.powerMaxSafe = ToSafeNumberValue(maxPower)
        frame.LiveValues.powerCurrentAbbr = ResolveBlizzardAbbreviation(currentPower, frame.LiveValues.powerCurrentText)
        frame.LiveValues.powerMaxAbbr = ResolveBlizzardAbbreviation(maxPower, frame.LiveValues.powerMaxText)
    end

    if frame.Elements.AlternativePowerBar then
        local currentAltPower = 0
        local maxAltPower = 0
        local showAltPower = false

        local secondaryPowerType = GetSecondaryPowerTypeForUnit(unit)

        if previewValues then
            currentAltPower = previewValues.altPowerCurrent or 0
            maxAltPower = previewValues.altPowerMax or 0
            showAltPower = secondaryPowerType ~= nil and maxAltPower > 0
        elseif secondaryPowerType ~= nil and unitExists then
            _, currentAltPower, maxAltPower = GetSecondaryPowerValues(unit)
            showAltPower = maxAltPower > 0
        end

        frame.Elements.AlternativePowerBar:SetMinMaxValues(0, math.max(maxAltPower, 1))
        frame.Elements.AlternativePowerBar:SetValue(currentAltPower)

        frame.LiveValues.altPowerCurrentRaw = currentAltPower
        frame.LiveValues.altPowerMaxRaw = maxAltPower
        frame.LiveValues.altPowerCurrentText = FormatDisplayNumber(currentAltPower)
        frame.LiveValues.altPowerMaxText = FormatDisplayNumber(maxAltPower)
        frame.LiveValues.altPowerVisible = showAltPower
        frame.LiveValues.altPowerType = secondaryPowerType
        frame.LiveValues.altPowerCurrentSafe = ToSafeNumberValue(currentAltPower)
        frame.LiveValues.altPowerMaxSafe = ToSafeNumberValue(maxAltPower)
        frame.LiveValues.altPowerCurrentAbbr = ResolveBlizzardAbbreviation(currentAltPower, frame.LiveValues.altPowerCurrentText)
        frame.LiveValues.altPowerMaxAbbr = ResolveBlizzardAbbreviation(maxAltPower, frame.LiveValues.altPowerMaxText)

        if previousAltPowerVisible ~= nil
            and previousAltPowerVisible ~= showAltPower
            and not frame.isApplyingAltPowerLayout
        then
            frame.isApplyingAltPowerLayout = true
            self:ApplyConfig(frame)
            frame.isApplyingAltPowerLayout = false
        end
    end
end

local function GetActiveCastTiming(unit, castBar)
    if not unit then
        return nil, nil, nil, nil, nil, nil
    end

    if UnitCastingInfo then
        local castName, _, castIcon, startTimeMS, endTimeMS, _, _, notInterruptible, _, castID = UnitCastingInfo(unit)
        if type(castName) == "string" then
            if unit == "player"
                and type(startTimeMS) == "number"
                and type(endTimeMS) == "number"
            then
                return false, startTimeMS / 1000, endTimeMS / 1000, castIcon, not notInterruptible, castID
            end

            if UnitCastingDuration then
                local durationMS = UnitCastingDuration(unit)
                if type(durationMS) == "number" then
                    local duration = durationMS > 100 and (durationMS / 1000) or durationMS
                    if castBar
                        and castBar.isCasting
                        and not castBar.isChannel
                        and castBar.castID == castID
                        and type(castBar.startTime) == "number"
                        and type(castBar.endTime) == "number"
                    then
                        return false, castBar.startTime, castBar.endTime, castIcon, not notInterruptible, castID
                    end

                    local now = GetTime and GetTime() or 0
                    return false, now, now + duration, castIcon, not notInterruptible, castID
                end
            end
        end
    end

    if UnitChannelInfo then
        local channelName, _, channelIcon, startTimeMS, endTimeMS, _, notInterruptible, _, _, castID = UnitChannelInfo(unit)
        if type(channelName) == "string" then
            if unit == "player"
                and type(startTimeMS) == "number"
                and type(endTimeMS) == "number"
            then
                return true, startTimeMS / 1000, endTimeMS / 1000, channelIcon, not notInterruptible, castID
            end

            if UnitChannelDuration then
                local durationMS = UnitChannelDuration(unit)
                if type(durationMS) == "number" then
                    local duration = durationMS > 100 and (durationMS / 1000) or durationMS
                    if castBar
                        and castBar.isCasting
                        and castBar.isChannel
                        and castBar.castID == castID
                        and type(castBar.startTime) == "number"
                        and type(castBar.endTime) == "number"
                    then
                        return true, castBar.startTime, castBar.endTime, channelIcon, not notInterruptible, castID
                    end

                    local now = GetTime and GetTime() or 0
                    return true, now, now + duration, channelIcon, not notInterruptible, castID
                end
            end
        end
    end

    return nil, nil, nil, nil, nil, nil
end

local function StartCastBar(frame)
    local castBar = frame and frame.Elements and frame.Elements.CastBar
    local unit = frame and frame.unit
    if not castBar or not unit then
        return
    end

    local isChannel, startTime, endTime, spellIcon, isInterruptible, castID = GetActiveCastTiming(unit, castBar)

    if type(startTime) ~= "number" or type(endTime) ~= "number" then
        castBar.isCasting = false
        castBar.isPreview = false
        castBar:Hide()
        return
    end

    castBar.startTime = startTime
    castBar.endTime = endTime
    castBar.isCasting = true
    castBar.isChannel = isChannel and true or false
    castBar.isPreview = false
    castBar.isInterruptible = isInterruptible ~= false
    castBar.castID = castID
    castBar:SetMinMaxValues(castBar.startTime, castBar.endTime)
    castBar:SetValue(castBar.isChannel and castBar.endTime or castBar.startTime)
    ApplyCastBarStateColor(castBar, castBar.isInterruptible, frame.config and frame.config.castBarColor)

    if castBar.icon then
        if frame.config and frame.config.showCastBarIcon ~= false and spellIcon ~= nil and spellIcon ~= "" then
            castBar.icon:SetTexture(spellIcon)
            castBar.icon:Show()
        else
            castBar.icon:SetTexture(nil)
            castBar.icon:Hide()
        end
    end

    if frame.config and frame.config.showCastBar ~= false then
        castBar:Show()
    end
end

local function StartCastBarPreview(frame)
    local castBar = frame and frame.Elements and frame.Elements.CastBar
    if not castBar then
        return
    end

    local now = GetTime and GetTime() or 0
    castBar.startTime = now
    castBar.endTime = now + 2.5
    castBar.isCasting = true
    castBar.isChannel = false
    castBar.isPreview = true
    castBar.isInterruptible = true
    castBar.castID = nil
    castBar:SetMinMaxValues(castBar.startTime, castBar.endTime)
    castBar:SetValue(now + 1.25)
    ApplyCastBarStateColor(castBar, true, frame.config and frame.config.castBarColor)

    if castBar.icon then
        if frame.config and frame.config.showCastBarIcon ~= false then
            castBar.icon:SetTexture(136048)
            castBar.icon:Show()
        else
            castBar.icon:SetTexture(nil)
            castBar.icon:Hide()
        end
    end

    if frame.config and frame.config.showCastBar ~= false then
        castBar:Show()
    end
end

local function StopCastBar(frame)
    local castBar = frame and frame.Elements and frame.Elements.CastBar
    if not castBar then
        return
    end

    castBar.isCasting = false
    castBar.isChannel = false
    castBar.isPreview = false
    castBar.isInterruptible = true
    castBar.startTime = 0
    castBar.endTime = 0
    castBar.castID = nil
    if castBar.icon then
        castBar.icon:SetTexture(nil)
        castBar.icon:Hide()
    end
    castBar:Hide()
end

local function QueueCastBarRefresh(frame)
    if not frame or not C_Timer or not C_Timer.After then
        return
    end

    if frame.castBarRefreshQueued then
        return
    end

    frame.castBarRefreshQueued = true
    C_Timer.After(0, function()
        if not frame then
            return
        end

        frame.castBarRefreshQueued = false

        if UF.RefreshCastBar then
            UF:RefreshCastBar(frame)
        end
    end)
end

function UF:RefreshCastBar(frame)
    local castBar = frame and frame.Elements and frame.Elements.CastBar
    if not castBar then
        return
    end

    if frame.config and frame.config.showCastBar == false then
        StopCastBar(frame)
        return
    end

    local unit = frame.unit
    if not unit then
        StopCastBar(frame)
        return
    end

    local now = GetTime and GetTime() or 0
    local isChannel, startTime, endTime, spellIcon, isInterruptible, castID = GetActiveCastTiming(unit, castBar)
    local hasCast = type(startTime) == "number" and type(endTime) == "number"

    if hasCast then
        local duration = math.max(endTime - startTime, 0.001)

        castBar.isCasting = true
        castBar.isChannel = isChannel
        castBar.isPreview = false
        castBar.isInterruptible = isInterruptible ~= false
        castBar.castID = castID
        castBar.startTime = startTime
        castBar.endTime = endTime
        castBar:SetMinMaxValues(0, duration)

        if isChannel then
            castBar:SetValue(math.max(endTime - now, 0))
        else
            castBar:SetValue(math.max(now - startTime, 0))
        end

        ApplyCastBarStateColor(castBar, castBar.isInterruptible, frame.config and frame.config.castBarColor)

        if castBar.icon then
            if frame.config and frame.config.showCastBarIcon ~= false and spellIcon ~= nil and spellIcon ~= "" then
                castBar.icon:SetTexture(spellIcon)
                castBar.icon:Show()
            else
                castBar.icon:SetTexture(nil)
                castBar.icon:Hide()
            end
        end

        castBar:Show()
    elseif not castBar.isPreview then
        StopCastBar(frame)
    end
end

function UF:RegisterCastBarEvents(frame)
    if not frame or frame.CastBarEventFrame or not frame.Elements or not frame.Elements.CastBar then
        return
    end

    local eventFrame = CreateFrame("Frame", nil, frame)
    eventFrame.owner = frame
    eventFrame.elapsed = 0

    eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    eventFrame:RegisterEvent("UNIT_SPELLCAST_START")
    eventFrame:RegisterEvent("UNIT_SPELLCAST_STOP")
    eventFrame:RegisterEvent("UNIT_SPELLCAST_FAILED")
    eventFrame:RegisterEvent("UNIT_SPELLCAST_INTERRUPTED")
    eventFrame:RegisterEvent("UNIT_SPELLCAST_DELAYED")
    eventFrame:RegisterEvent("UNIT_SPELLCAST_CHANNEL_START")
    eventFrame:RegisterEvent("UNIT_SPELLCAST_CHANNEL_STOP")
    eventFrame:RegisterEvent("UNIT_SPELLCAST_CHANNEL_UPDATE")

    if frame.unit == "target" then
        eventFrame:RegisterEvent("PLAYER_TARGET_CHANGED")
    elseif frame.unit == "focus" then
        eventFrame:RegisterEvent("PLAYER_FOCUS_CHANGED")
    elseif frame.unit == "pet" then
        eventFrame:RegisterEvent("UNIT_PET")
    end

    eventFrame:SetScript("OnUpdate", function(self, elapsed)
        local owner = self.owner
        local castBar = owner and owner.Elements and owner.Elements.CastBar
        if not owner or not castBar or not castBar.isCasting then
            self.elapsed = 0
            return
        end

        self.elapsed = (self.elapsed or 0) + elapsed
        if self.elapsed < 0.02 then
            return
        end

        self.elapsed = 0

        local now = GetTime and GetTime() or 0
        if castBar.isPreview then
            if not Portrait.guiTestModeEnabled then
                StopCastBar(owner)
                return
            end

            if now >= castBar.endTime then
                castBar.startTime = now
                castBar.endTime = now + 2.5
                castBar:SetMinMaxValues(castBar.startTime, castBar.endTime)
            end

            castBar:SetValue(now)
            return
        end

        UF:RefreshCastBar(owner)
    end)

    eventFrame:SetScript("OnEvent", function(_, event, unit)
        local owner = eventFrame.owner
        if not owner then
            return
        end

        if event == "PLAYER_TARGET_CHANGED" or event == "PLAYER_FOCUS_CHANGED" then
            UF:RefreshCastBar(owner)
            QueueCastBarRefresh(owner)
            return
        end

        if event == "UNIT_PET" then
            if owner.unit == "pet" and unit == "player" then
                UF:RefreshCastBar(owner)
                QueueCastBarRefresh(owner)
            end
            return
        end

        if event == "PLAYER_ENTERING_WORLD" then
            UF:RefreshCastBar(owner)
            QueueCastBarRefresh(owner)
            return
        end

        if unit and unit ~= owner.unit then
            return
        end

        if event == "UNIT_SPELLCAST_STOP"
            or event == "UNIT_SPELLCAST_FAILED"
            or event == "UNIT_SPELLCAST_INTERRUPTED"
            or event == "UNIT_SPELLCAST_CHANNEL_STOP"
        then
            StopCastBar(owner)
            return
        end

        UF:RefreshCastBar(owner)
        QueueCastBarRefresh(owner)
    end)

    frame.CastBarEventFrame = eventFrame
end

-- Raid Target Icon
function UF:CreateRaidTargetIcon(frame)
    -- Use a dedicated overlay frame so the RTM can reliably sit above bars.
    -- A plain texture on the base frame can end up visually behind child
    -- frames like HealthBar/PowerBar when frame levels differ.
    local holder = CreateFrame("Frame", nil, frame)
    holder:SetAllPoints(frame)
    holder:SetFrameStrata(frame:GetFrameStrata())
    holder:SetFrameLevel(frame:GetFrameLevel() + 20)
    holder:Hide()

    local texture = holder:CreateTexture(nil, "OVERLAY", nil, 7)
    texture:SetTexture("Interface\\TargetingFrame\\UI-RaidTargetingIcons")
    texture:Hide()

    holder.Texture = texture
    frame.Elements.RaidTargetIcon = holder
    frame.RaidTargetIcon = holder
end

local function CreateOverlayIndicatorHolder(frame, elementKey)
    local holder = CreateFrame("Frame", nil, frame)
    holder:SetAllPoints(frame)
    holder:SetFrameStrata(frame:GetFrameStrata())
    holder:SetFrameLevel(frame:GetFrameLevel() + 20)
    holder:Hide()

    local texture = holder:CreateTexture(nil, "OVERLAY", nil, 7)
    texture:Hide()

    holder.Texture = texture
    frame.Elements[elementKey] = holder
    frame[elementKey] = holder
end

local function ApplyOverlayIndicatorConfig(owner, frame, holder, options)
    if not holder then
        return
    end

    local icon = holder.Texture or holder

    holder:ClearAllPoints()
    holder:SetScale(1)
    holder:SetFrameStrata(frame:GetFrameStrata())
    holder:SetFrameLevel(math.max(frame:GetFrameLevel() + 20, (frame.Elements.HealthBar and frame.Elements.HealthBar:GetFrameLevel() + 10) or (frame:GetFrameLevel() + 20)))
    icon:ClearAllPoints()
    icon:SetScale(1)

    if options.enabled then
        local effectiveSize = options.size * options.scale
        holder:SetSize(effectiveSize, effectiveSize)
        icon:SetAllPoints(holder)

        if options.placement == "INSIDE" then
            if options.insideSide == "LEFT" then
                holder:SetPoint("TOPLEFT", frame, "TOPLEFT", options.borderInset + options.padding, -(options.borderInset + options.padding))
            else
                holder:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -(options.borderInset + options.padding), -(options.borderInset + options.padding))
            end
        else
            local anchorParent = owner:GetAnchorTarget(frame, options.anchorTo) or frame
            holder:SetPoint(
                options.point,
                anchorParent,
                options.relativePoint,
                options.offsetX,
                options.offsetY
            )
        end

        options.updateFunc(frame)
    else
        icon:SetTexture(nil)
        icon:Hide()
        holder:Hide()
    end
end

function UF:CreateLeaderIcon(frame)
    CreateOverlayIndicatorHolder(frame, "LeaderIcon")
end

function UF:CreateRoleIcon(frame)
    CreateOverlayIndicatorHolder(frame, "RoleIcon")
end

function UF:CreateCombatIndicator(frame)
    CreateOverlayIndicatorHolder(frame, "CombatIndicator")
end

function UF:CreateRestingIndicator(frame)
    CreateOverlayIndicatorHolder(frame, "RestingIndicator")
end

function UF:CreateReadyCheckIndicator(frame)
    CreateOverlayIndicatorHolder(frame, "ReadyCheckIndicator")
end


function UF:UpdateRaidTargetIcon(frame)
    if not frame or not frame.Elements or not frame.Elements.RaidTargetIcon then
        return
    end

    local holder = frame.Elements.RaidTargetIcon
    local icon = holder.Texture or holder
    local config = frame.config
    local rtmConfig = config and config.RaidTargetIcon or nil

    if not rtmConfig or rtmConfig.enabled == false then
        icon:SetTexture(nil)
        icon:Hide()
        holder:Hide()
        return
    end

    local index = frame.unit and GetRaidTargetIndex and GetRaidTargetIndex(frame.unit) or nil

    if not index then
        icon:SetTexture(nil)
        icon:Hide()
        holder:Hide()
        return
    end

    icon:SetTexture("Interface\\TargetingFrame\\UI-RaidTargetingIcons")
    SetRaidTargetIconTexture(icon, index)
    holder:Show()
    icon:Show()
end

function UF:RegisterRaidTargetEvents(frame)
    if not frame or frame.RaidTargetEventFrame then
        return
    end

    local eventFrame = CreateFrame("Frame", nil, frame)
    eventFrame.owner = frame

    eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    eventFrame:RegisterEvent("RAID_TARGET_UPDATE")
    eventFrame:RegisterEvent("GROUP_ROSTER_UPDATE")
    eventFrame:RegisterEvent("UNIT_TARGET")

    if frame.unit == "target" then
        eventFrame:RegisterEvent("PLAYER_TARGET_CHANGED")
    elseif frame.unit == "focus" then
        eventFrame:RegisterEvent("PLAYER_FOCUS_CHANGED")
    elseif frame.unit == "pet" then
        eventFrame:RegisterEvent("UNIT_PET")
    end

    eventFrame:SetScript("OnEvent", function(_, event, unit)
        local owner = eventFrame.owner
        if not owner or not owner:IsShown() then
            return
        end

        if event == "UNIT_TARGET" then
            if owner.unit ~= "targettarget" and owner.unit ~= "focustarget" then
                return
            end

            local expectedUnit = owner.unit == "targettarget" and "target" or "focus"
            if unit ~= expectedUnit then
                return
            end
        elseif event == "UNIT_PET" and unit ~= "player" then
            return
        end

        C_Timer.After(0, function()
            if owner and owner:IsShown() then
                UF:UpdateRaidTargetIcon(owner)
            end
        end)
    end)

    frame.RaidTargetEventFrame = eventFrame
end

function UF:UpdateLeaderIcon(frame)
    if not frame or not frame.Elements or not frame.Elements.LeaderIcon then
        return
    end

    local holder = frame.Elements.LeaderIcon
    local icon = holder.Texture or holder
    local config = frame.config
    local leaderConfig = config and config.LeaderIcon or nil

    if not leaderConfig or leaderConfig.enabled == false then
        icon:SetTexture(nil)
        icon:Hide()
        holder:Hide()
        return
    end

    local isLeader = false

    if frame.unit and UnitExists and UnitExists(frame.unit) then
        if UnitLeadsAnyGroup then
            isLeader = UnitLeadsAnyGroup(frame.unit) and true or false
        elseif UnitIsGroupLeader then
            isLeader = UnitIsGroupLeader(frame.unit) and true or false
        end
    end

    if not isLeader then
        icon:SetTexture(nil)
        icon:Hide()
        holder:Hide()
        return
    end

    icon:SetAtlas("UI-HUD-UnitFrame-Player-Group-LeaderIcon", true)
    holder:Show()
    icon:Show()
end

function UF:RegisterLeaderIconEvents(frame)
    if not frame or frame.LeaderIconEventFrame then
        return
    end

    local eventFrame = CreateFrame("Frame", nil, frame)
    eventFrame.owner = frame

    eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    eventFrame:RegisterEvent("GROUP_ROSTER_UPDATE")
    eventFrame:RegisterEvent("PARTY_LEADER_CHANGED")
    eventFrame:RegisterEvent("PLAYER_ROLES_ASSIGNED")

    if frame.unit == "target" then
        eventFrame:RegisterEvent("PLAYER_TARGET_CHANGED")
    elseif frame.unit == "focus" then
        eventFrame:RegisterEvent("PLAYER_FOCUS_CHANGED")
    elseif frame.unit == "pet" then
        eventFrame:RegisterEvent("UNIT_PET")
    end

    eventFrame:SetScript("OnEvent", function(_, event, unit)
        local owner = eventFrame.owner
        if not owner or not owner:IsShown() then
            return
        end

        if event == "UNIT_PET" and unit ~= "player" then
            return
        end

        C_Timer.After(0, function()
            if owner and owner:IsShown() then
                UF:UpdateLeaderIcon(owner)
            end
        end)
    end)

    frame.LeaderIconEventFrame = eventFrame
end

function UF:UpdateRoleIcon(frame)
    if not frame or not frame.Elements or not frame.Elements.RoleIcon then
        return
    end

    local holder = frame.Elements.RoleIcon
    local icon = holder.Texture or holder
    local config = frame.config
    local roleConfig = config and config.RoleIcon or nil

    if not roleConfig or roleConfig.enabled == false then
        icon:SetTexture(nil)
        icon:Hide()
        holder:Hide()
        return
    end

    local role = frame.unit and UnitGroupRolesAssigned and UnitGroupRolesAssigned(frame.unit) or nil

    if role == "TANK" then
        icon:SetAtlas("UI-LFG-RoleIcon-Tank-Micro-Raid", true)
    elseif role == "HEALER" then
        icon:SetAtlas("UI-LFG-RoleIcon-Healer-Micro-Raid", true)
    elseif role == "DAMAGER" then
        icon:SetAtlas("UI-LFG-RoleIcon-DPS-Micro-Raid", true)
    else
        icon:SetTexture(nil)
        icon:Hide()
        holder:Hide()
        return
    end

    holder:Show()
    icon:Show()
end

function UF:RegisterRoleIconEvents(frame)
    if not frame or frame.RoleIconEventFrame then
        return
    end

    local eventFrame = CreateFrame("Frame", nil, frame)
    eventFrame.owner = frame

    eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    eventFrame:RegisterEvent("GROUP_ROSTER_UPDATE")
    eventFrame:RegisterEvent("PLAYER_ROLES_ASSIGNED")

    if frame.unit == "target" then
        eventFrame:RegisterEvent("PLAYER_TARGET_CHANGED")
    elseif frame.unit == "focus" then
        eventFrame:RegisterEvent("PLAYER_FOCUS_CHANGED")
    elseif frame.unit == "pet" then
        eventFrame:RegisterEvent("UNIT_PET")
    end

    eventFrame:SetScript("OnEvent", function(_, event, unit)
        local owner = eventFrame.owner
        if not owner or not owner:IsShown() then
            return
        end

        if event == "UNIT_PET" and unit ~= "player" then
            return
        end

        C_Timer.After(0, function()
            if owner and owner:IsShown() then
                UF:UpdateRoleIcon(owner)
            end
        end)
    end)

    frame.RoleIconEventFrame = eventFrame
end

function UF:UpdateCombatIndicator(frame)
    if not frame or not frame.Elements or not frame.Elements.CombatIndicator then
        return
    end

    local holder = frame.Elements.CombatIndicator
    local icon = holder.Texture or holder
    local config = frame.config
    local combatConfig = config and config.CombatIndicator or nil

    if not combatConfig or combatConfig.enabled == false then
        icon:SetTexture(nil)
        icon:Hide()
        holder:Hide()
        return
    end

    local inCombat = frame.unit and UnitAffectingCombat and UnitAffectingCombat(frame.unit) or false

    if not inCombat then
        icon:SetTexture(nil)
        icon:Hide()
        holder:Hide()
        return
    end

    icon:SetAtlas("UI-HUD-UnitFrame-Player-CombatIcon", true)
    holder:Show()
    icon:Show()
end

function UF:RegisterCombatIndicatorEvents(frame)
    if not frame or frame.CombatIndicatorEventFrame then
        return
    end

    local eventFrame = CreateFrame("Frame", nil, frame)
    eventFrame.owner = frame

    eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    eventFrame:RegisterEvent("UNIT_FLAGS")
    eventFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
    eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")

    if frame.unit == "target" then
        eventFrame:RegisterEvent("PLAYER_TARGET_CHANGED")
    elseif frame.unit == "focus" then
        eventFrame:RegisterEvent("PLAYER_FOCUS_CHANGED")
    elseif frame.unit == "pet" then
        eventFrame:RegisterEvent("UNIT_PET")
    end

    eventFrame:SetScript("OnEvent", function(_, event, unit)
        local owner = eventFrame.owner
        if not owner or not owner:IsShown() then
            return
        end

        if event == "UNIT_FLAGS" and unit ~= owner.unit then
            return
        end

        if event == "UNIT_PET" and unit ~= "player" then
            return
        end

        C_Timer.After(0, function()
            if owner and owner:IsShown() then
                UF:UpdateCombatIndicator(owner)
            end
        end)
    end)

    frame.CombatIndicatorEventFrame = eventFrame
end

function UF:UpdateRestingIndicator(frame)
    if not frame or not frame.Elements or not frame.Elements.RestingIndicator then
        return
    end

    local holder = frame.Elements.RestingIndicator
    local icon = holder.Texture or holder
    local config = frame.config
    local restingConfig = config and config.RestingIndicator or nil

    if not restingConfig or restingConfig.enabled == false then
        icon:SetTexture(nil)
        icon:Hide()
        holder:Hide()
        return
    end

    if frame.unit ~= "player" or not IsResting or not IsResting() then
        icon:SetTexture(nil)
        icon:Hide()
        holder:Hide()
        return
    end

    icon:SetTexture("Interface\\CharacterFrame\\UI-StateIcon")
    icon:SetTexCoord(0, 0.5, 0, 0.421875)
    holder:Show()
    icon:Show()
end

function UF:RegisterRestingIndicatorEvents(frame)
    if not frame or frame.RestingIndicatorEventFrame then
        return
    end

    local eventFrame = CreateFrame("Frame", nil, frame)
    eventFrame.owner = frame

    eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    eventFrame:RegisterEvent("PLAYER_UPDATE_RESTING")

    eventFrame:SetScript("OnEvent", function()
        local owner = eventFrame.owner
        if not owner or not owner:IsShown() then
            return
        end

        C_Timer.After(0, function()
            if owner and owner:IsShown() then
                UF:UpdateRestingIndicator(owner)
            end
        end)
    end)

    frame.RestingIndicatorEventFrame = eventFrame
end

function UF:UpdateReadyCheckIndicator(frame)
    if not frame or not frame.Elements or not frame.Elements.ReadyCheckIndicator then
        return
    end

    local holder = frame.Elements.ReadyCheckIndicator
    local icon = holder.Texture or holder
    local config = frame.config
    local readyCheckConfig = config and config.ReadyCheckIndicator or nil

    if not readyCheckConfig or readyCheckConfig.enabled == false then
        icon:SetTexture(nil)
        icon:Hide()
        holder:Hide()
        return
    end

    local status = frame.unit and GetReadyCheckStatus and GetReadyCheckStatus(frame.unit) or nil

    if status == "ready" then
        icon:SetTexture("Interface\\RaidFrame\\ReadyCheck-Ready")
    elseif status == "notready" then
        icon:SetTexture("Interface\\RaidFrame\\ReadyCheck-NotReady")
    elseif status == "waiting" then
        icon:SetTexture("Interface\\RaidFrame\\ReadyCheck-Waiting")
    else
        icon:SetTexture(nil)
        icon:Hide()
        holder:Hide()
        return
    end

    icon:SetTexCoord(0, 1, 0, 1)
    holder:Show()
    icon:Show()
end

function UF:RegisterReadyCheckIndicatorEvents(frame)
    if not frame or frame.ReadyCheckIndicatorEventFrame then
        return
    end

    local eventFrame = CreateFrame("Frame", nil, frame)
    eventFrame.owner = frame

    eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    eventFrame:RegisterEvent("READY_CHECK")
    eventFrame:RegisterEvent("READY_CHECK_CONFIRM")
    eventFrame:RegisterEvent("READY_CHECK_FINISHED")
    eventFrame:RegisterEvent("GROUP_ROSTER_UPDATE")

    if frame.unit == "target" then
        eventFrame:RegisterEvent("PLAYER_TARGET_CHANGED")
    elseif frame.unit == "focus" then
        eventFrame:RegisterEvent("PLAYER_FOCUS_CHANGED")
    elseif frame.unit == "pet" then
        eventFrame:RegisterEvent("UNIT_PET")
    end

    eventFrame:SetScript("OnEvent", function(_, event, unit)
        local owner = eventFrame.owner
        if not owner or not owner:IsShown() then
            return
        end

        if event == "UNIT_PET" and unit ~= "player" then
            return
        end

        C_Timer.After(0, function()
            if owner and owner:IsShown() then
                UF:UpdateReadyCheckIndicator(owner)
            end
        end)
    end)

    frame.ReadyCheckIndicatorEventFrame = eventFrame
end

-- Portrait
function UF:CreatePortrait(frame)
    local portraitHolder = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    portraitHolder:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
        insets = { left = 0, right = 0, top = 0, bottom = 0 },
    })

    local portraitTexture = portraitHolder:CreateTexture(nil, "ARTWORK")
    portraitTexture:SetAllPoints()
    portraitTexture:SetTexCoord(0.07, 0.93, 0.07, 0.93)

    portraitHolder.Texture = portraitTexture

    frame.Elements.Portrait = portraitHolder
    frame.Portrait = portraitHolder
end

function UF:UpdatePortraitTexture(frame)
    if not frame or not frame.Elements or not frame.Elements.Portrait then
        return
    end

    local portrait = frame.Elements.Portrait
    local texture = portrait.Texture
    local config = frame.config
    local portraitConfig = config and config.Portrait or nil

    if not texture then
        return
    end

    if not portraitConfig or portraitConfig.enabled == false then
        texture:SetTexture(nil)
        return
    end

    texture:SetTexCoord(0.07, 0.93, 0.07, 0.93)

    if frame.unit and UnitExists(frame.unit) then
        SetPortraitTexture(texture, frame.unit)
    else
        texture:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
    end

    texture:Show()
end

function UF:RegisterPortraitEvents(frame)
    if not frame or frame.PortraitEventFrame then
        return
    end

    local eventFrame = CreateFrame("Frame", nil, frame)
    eventFrame.owner = frame

    eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    eventFrame:RegisterEvent("PORTRAITS_UPDATED")
    eventFrame:RegisterEvent("UNIT_PORTRAIT_UPDATE")
    eventFrame:RegisterEvent("UNIT_MODEL_CHANGED")

    if frame.unit == "target" then
        eventFrame:RegisterEvent("PLAYER_TARGET_CHANGED")
    end

    eventFrame:SetScript("OnEvent", function(_, event, unit)
        local owner = eventFrame.owner
        if not owner or not owner:IsShown() then
            return
        end

        if event == "UNIT_PORTRAIT_UPDATE" or event == "UNIT_MODEL_CHANGED" then
            if unit ~= owner.unit then
                return
            end
        end

        C_Timer.After(0, function()
            if owner and owner:IsShown() then
                UF:UpdatePortraitTexture(owner)
            end
        end)
    end)

    frame.PortraitEventFrame = eventFrame
end

function UF:ApplyConfig(frame)
    local config = frame.config
    if not config then
        return
    end

    local width = config.width or 220
    local height = config.height or 40
    local alpha = config.alpha or 1
    local scale = config.scale or 1
    local frameLevel = config.frameLevel or 1
    local frameStrata = config.frameStrata or "MEDIUM"
    local showPowerBar = config.showPowerBar and true or false
    local powerBarHeight = showPowerBar and (config.powerBarHeight or 8) or 0
    local showAlternativePowerBar = config.showAlternativePowerBar and true or false
    local alternativePowerBarHeight = showAlternativePowerBar and (config.alternativePowerBarHeight or 5) or 0
    local liveAltPowerType, liveAltPowerCurrent, liveAltPowerMax = GetSecondaryPowerValues(frame.unit)
    local alternativePowerBarVisible = showAlternativePowerBar and liveAltPowerType ~= nil and liveAltPowerMax > 0
    local borderInset = 1

    local portraitConfig = config.Portrait or {}
    local raidTargetConfig = config.RaidTargetIcon or {}
    local leaderConfig = config.LeaderIcon or {}
    local roleConfig = config.RoleIcon or {}
    local combatConfig = config.CombatIndicator or {}
    local restingConfig = config.RestingIndicator or {}
    local readyCheckConfig = config.ReadyCheckIndicator or {}
    local portraitEnabled = portraitConfig.enabled and true or false
    local portraitPlacement = portraitConfig.placement or "INSIDE"
    local portraitMode = portraitConfig.mode or "2D"
    local portraitSize = tonumber(portraitConfig.size) or 40
    local portraitScale = tonumber(portraitConfig.scale) or 1
    local portraitPadding = tonumber(portraitConfig.padding) or 4
    local portraitInsideSide = portraitConfig.insideSide or "LEFT"

    local portraitPoint = portraitConfig.point or "RIGHT"
    local portraitRelativePoint = portraitConfig.relativePoint or "LEFT"
    local portraitOffsetX = tonumber(portraitConfig.offsetX) or -4
    local portraitOffsetY = tonumber(portraitConfig.offsetY) or 0
    local portraitAnchorTo = portraitConfig.anchorTo or "Frame"

    local portraitEffectiveSize = portraitEnabled and (portraitSize * portraitScale) or 0
    local portraitInside = portraitEnabled and portraitPlacement == "INSIDE"
    local portraitAttached = portraitEnabled and portraitPlacement == "ATTACHED"
    local portraitReservedSpace = portraitInside and (portraitEffectiveSize + portraitPadding) or 0

    -- Important: GUI uses fallback=true for new RTM configs. Treat a missing
    -- enabled flag as active as well, otherwise the UI can look enabled while
    -- the engine silently considers the element disabled on older profiles.
    local raidTargetEnabled = raidTargetConfig.enabled ~= false
    local raidTargetSize = tonumber(raidTargetConfig.size) or 18
    local raidTargetScale = tonumber(raidTargetConfig.scale) or 1
    local raidTargetPoint = raidTargetConfig.point or "TOP"
    local raidTargetRelativePoint = raidTargetConfig.relativePoint or "TOP"
    local raidTargetOffsetX = tonumber(raidTargetConfig.offsetX) or 0
    local raidTargetOffsetY = tonumber(raidTargetConfig.offsetY) or 8
    local raidTargetAnchorTo = raidTargetConfig.anchorTo or "Frame"

    local leaderEnabled = leaderConfig.enabled ~= false
    local leaderPlacement = leaderConfig.placement or "ATTACHED"
    local leaderSize = tonumber(leaderConfig.size) or 16
    local leaderScale = tonumber(leaderConfig.scale) or 1
    local leaderPadding = tonumber(leaderConfig.padding) or 2
    local leaderInsideSide = leaderConfig.insideSide or "LEFT"
    local leaderPoint = leaderConfig.point or "TOPLEFT"
    local leaderRelativePoint = leaderConfig.relativePoint or "TOP"
    local leaderOffsetX = tonumber(leaderConfig.offsetX) or 0
    local leaderOffsetY = tonumber(leaderConfig.offsetY) or 0
    local leaderAnchorTo = leaderConfig.anchorTo or "Frame"

    local roleEnabled = roleConfig.enabled ~= false
    local rolePlacement = roleConfig.placement or "ATTACHED"
    local roleSize = tonumber(roleConfig.size) or 16
    local roleScale = tonumber(roleConfig.scale) or 1
    local rolePadding = tonumber(roleConfig.padding) or 2
    local roleInsideSide = roleConfig.insideSide or "RIGHT"
    local rolePoint = roleConfig.point or "TOPRIGHT"
    local roleRelativePoint = roleConfig.relativePoint or "TOP"
    local roleOffsetX = tonumber(roleConfig.offsetX) or 0
    local roleOffsetY = tonumber(roleConfig.offsetY) or 0
    local roleAnchorTo = roleConfig.anchorTo or "Frame"

    local combatEnabled = combatConfig.enabled ~= false
    local combatPlacement = combatConfig.placement or "ATTACHED"
    local combatSize = tonumber(combatConfig.size) or 16
    local combatScale = tonumber(combatConfig.scale) or 1
    local combatPadding = tonumber(combatConfig.padding) or 2
    local combatInsideSide = combatConfig.insideSide or "RIGHT"
    local combatPoint = combatConfig.point or "TOP"
    local combatRelativePoint = combatConfig.relativePoint or "TOP"
    local combatOffsetX = tonumber(combatConfig.offsetX) or 0
    local combatOffsetY = tonumber(combatConfig.offsetY) or 0
    local combatAnchorTo = combatConfig.anchorTo or "Frame"

    local restingEnabled = restingConfig.enabled ~= false
    local restingPlacement = restingConfig.placement or "ATTACHED"
    local restingSize = tonumber(restingConfig.size) or 16
    local restingScale = tonumber(restingConfig.scale) or 1
    local restingPadding = tonumber(restingConfig.padding) or 2
    local restingInsideSide = restingConfig.insideSide or "LEFT"
    local restingPoint = restingConfig.point or "TOPLEFT"
    local restingRelativePoint = restingConfig.relativePoint or "TOP"
    local restingOffsetX = tonumber(restingConfig.offsetX) or 0
    local restingOffsetY = tonumber(restingConfig.offsetY) or 0
    local restingAnchorTo = restingConfig.anchorTo or "Frame"

    local readyCheckEnabled = readyCheckConfig.enabled ~= false
    local readyCheckPlacement = readyCheckConfig.placement or "ATTACHED"
    local readyCheckSize = tonumber(readyCheckConfig.size) or 16
    local readyCheckScale = tonumber(readyCheckConfig.scale) or 1
    local readyCheckPadding = tonumber(readyCheckConfig.padding) or 2
    local readyCheckInsideSide = readyCheckConfig.insideSide or "RIGHT"
    local readyCheckPoint = readyCheckConfig.point or "TOPRIGHT"
    local readyCheckRelativePoint = readyCheckConfig.relativePoint or "TOP"
    local readyCheckOffsetX = tonumber(readyCheckConfig.offsetX) or 0
    local readyCheckOffsetY = tonumber(readyCheckConfig.offsetY) or 0
    local readyCheckAnchorTo = readyCheckConfig.anchorTo or "Frame"

    local bgR, bgG, bgB, bgA = UnpackColor(config.backgroundColor, { 0.08, 0.08, 0.08, 0.9 })
    local borderR, borderG, borderB, borderA = UnpackColor(config.borderColor, { 0.2, 0.2, 0.2, 1 })
    local healthR, healthG, healthB, healthA = UnpackColor(config.healthColor, { 0.1, 0.8, 0.1, 1 })
    local powerR, powerG, powerB, powerA = UnpackColor(config.powerColor, { 0.2, 0.4, 0.9, 1 })

    local healthBackgroundEnabled = config.healthBackground ~= false
    local healthBgR, healthBgG, healthBgB, healthBgA = UnpackColor(config.healthBackgroundColor, { 0, 0, 0, 0.35 })
    local healthBackgroundShown = healthBackgroundEnabled and (healthBgA or 0) > 0.001

    local powerBackgroundEnabled = config.powerBackground ~= false
    local powerBgR, powerBgG, powerBgB, powerBgA = UnpackColor(config.powerBackgroundColor, { 0, 0, 0, 0.35 })
    local powerBackgroundShown = powerBackgroundEnabled and (powerBgA or 0) > 0.001

    if config.useClassColorPower then
        local resourceR, resourceG, resourceB, resourceA = GetPowerColorForUnit(frame.unit)
        if resourceR and resourceG and resourceB then
            powerR, powerG, powerB, powerA = resourceR, resourceG, resourceB, resourceA or 1
        end
    end

    local healthTexture = GetStatusBarTexture(config.healthBarTexture)
    local powerTexture = GetStatusBarTexture(config.powerBarTexture)
    local castTexture = GetStatusBarTexture(config.castBarTexture)
    local altPowerTexture = GetStatusBarTexture(config.alternativePowerBarTexture or config.powerBarTexture)
    local globalClickThrough = Portrait.db
        and Portrait.db.profile
        and Portrait.db.profile.General
        and Portrait.db.profile.General.GlobalClickThrough == true
    local globalMouseEnabled = Portrait.db
        and Portrait.db.profile
        and Portrait.db.profile.General
        and Portrait.db.profile.General.MouseEnabled
    local globalClampToScreen = Portrait.db
        and Portrait.db.profile
        and Portrait.db.profile.General
        and Portrait.db.profile.General.ClampToScreen
    local mouseEnabled = globalMouseEnabled
    local clampToScreen = globalClampToScreen

    if mouseEnabled == nil then
        mouseEnabled = config.mouseEnabled ~= false
    end

    if clampToScreen == nil then
        clampToScreen = config.clampToScreen == true
    end

    frame:ClearAllPoints()
    frame:SetSize(width, height)
    frame:SetAlpha(alpha)
    frame:SetScale(scale)
    frame:SetFrameLevel(frameLevel)
    frame:SetFrameStrata(frameStrata)
    frame:SetShown(config.enabled ~= false)
    frame:EnableMouse(mouseEnabled ~= false)
    frame:SetMouseClickEnabled(not (config.clickThrough or globalClickThrough))
    frame:SetClampedToScreen(clampToScreen == true)

    local relativeTo = _G[config.relativeTo or "UIParent"] or UIParent
    local point = config.point or "CENTER"
    local relativePoint = config.relativePoint or "CENTER"
    local x = config.x or 0
    local y = config.y or 0

    local relativeScale = 1
    if relativeTo.GetEffectiveScale then
        relativeScale = relativeTo:GetEffectiveScale()
    end

    local frameScale = frame:GetEffectiveScale() or 1

    local adjustedX = x * (relativeScale / frameScale)
    local adjustedY = y * (relativeScale / frameScale)

    frame:SetPoint(
        point,
        relativeTo,
        relativePoint,
        adjustedX,
        adjustedY
    )

    frame:SetBackdropColor(bgR, bgG, bgB, bgA)
    frame:SetBackdropBorderColor(borderR, borderG, borderB, borderA)

     -- HealthBar
    if frame.Elements.HealthBar then
        local health = frame.Elements.HealthBar
        health:ClearAllPoints()
        health:SetStatusBarTexture(healthTexture)

        if health.bg then
            health.bg:SetTexture(healthTexture)
            health.bg:SetVertexColor(healthBgR, healthBgG, healthBgB, healthBgA)
            health.bg:SetShown(healthBackgroundShown)
        end

        local healthLeftOffset = borderInset
        local healthRightOffset = -borderInset
        local healthBottomY = borderInset
        if alternativePowerBarVisible then
            healthBottomY = healthBottomY + alternativePowerBarHeight
        end
        if showPowerBar then
            healthBottomY = healthBottomY + powerBarHeight
        end

        if portraitInside then
            if portraitInsideSide == "LEFT" then
                healthLeftOffset = borderInset + portraitReservedSpace
            elseif portraitInsideSide == "RIGHT" then
                healthRightOffset = -(borderInset + portraitReservedSpace)
            end
        end

        health:SetPoint("TOPLEFT", frame, "TOPLEFT", healthLeftOffset, -borderInset)
        health:SetPoint("TOPRIGHT", frame, "TOPRIGHT", healthRightOffset, -borderInset)
        health:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", healthLeftOffset, healthBottomY)
        health:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", healthRightOffset, healthBottomY)

        health:Show()
        self:UpdateHealthBarColor(frame)
    end

    -- PowerBar
    if frame.Elements.PowerBar then
        local power = frame.Elements.PowerBar
        power:ClearAllPoints()
        power:SetStatusBarTexture(powerTexture)
        power:SetStatusBarColor(powerR, powerG, powerB, powerA)

        if power.bg then
            power.bg:SetTexture(powerTexture)
            power.bg:SetVertexColor(powerBgR, powerBgG, powerBgB, powerBgA)
            power.bg:SetShown(powerBackgroundShown and showPowerBar)
        end

        if showPowerBar then
            local powerLeftOffset = borderInset
            local powerRightOffset = -borderInset
            local powerBottomOffset = borderInset + (alternativePowerBarVisible and alternativePowerBarHeight or 0)

            if portraitInside then
                if portraitInsideSide == "LEFT" then
                    powerLeftOffset = borderInset + portraitReservedSpace
                elseif portraitInsideSide == "RIGHT" then
                    powerRightOffset = -(borderInset + portraitReservedSpace)
                end
            end

            power:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", powerLeftOffset, powerBottomOffset)
            power:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", powerRightOffset, powerBottomOffset)
            power:SetHeight(powerBarHeight)
            power:Show()
        else
            if power.bg then
                power.bg:Hide()
            end
            power:Hide()
        end
    end

    if frame.Elements.AlternativePowerBar then
        local altPower = frame.Elements.AlternativePowerBar
        local altPowerType = liveAltPowerType or (frame.LiveValues and frame.LiveValues.altPowerType) or 0
        local altPowerTypeColor = PowerBarColor and PowerBarColor[altPowerType]
        local altPowerR, altPowerG, altPowerB, altPowerA = powerR, powerG, powerB, powerA
        if altPowerTypeColor then
            altPowerR = altPowerTypeColor.r or altPowerTypeColor[1] or altPowerR
            altPowerG = altPowerTypeColor.g or altPowerTypeColor[2] or altPowerG
            altPowerB = altPowerTypeColor.b or altPowerTypeColor[3] or altPowerB
            altPowerA = 1
        end

        altPower:ClearAllPoints()
        altPower:SetStatusBarTexture(altPowerTexture)
        altPower:SetStatusBarColor(altPowerR, altPowerG, altPowerB, altPowerA or 1)

        if altPower.bg then
            altPower.bg:SetTexture(altPowerTexture)
            altPower.bg:SetVertexColor(powerBgR, powerBgG, powerBgB, powerBgA)
            altPower.bg:SetShown(alternativePowerBarVisible and powerBackgroundShown)
        end

        if alternativePowerBarVisible then
            local currentAltPower = liveAltPowerCurrent or (frame.LiveValues and frame.LiveValues.altPowerCurrentRaw) or 0
            local maxAltPower = liveAltPowerMax or (frame.LiveValues and frame.LiveValues.altPowerMaxRaw) or 0

            altPower:SetMinMaxValues(0, math.max(maxAltPower, 1))
            altPower:SetValue(currentAltPower)

            local altPowerLeftOffset = borderInset
            local altPowerRightOffset = -borderInset

            if portraitInside then
                if portraitInsideSide == "LEFT" then
                    altPowerLeftOffset = borderInset + portraitReservedSpace
                elseif portraitInsideSide == "RIGHT" then
                    altPowerRightOffset = -(borderInset + portraitReservedSpace)
                end
            end

            altPower:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", altPowerLeftOffset, borderInset)
            altPower:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", altPowerRightOffset, borderInset)
            altPower:SetHeight(alternativePowerBarHeight)
            altPower:Show()
        else
            if altPower.bg then
                altPower.bg:Hide()
            end
            altPower:Hide()
        end
    end

    if frame.Elements.CastBar then
        local castBar = frame.Elements.CastBar
        local showCastBar = config.showCastBar ~= false
        local showCastBarIcon = config.showCastBarIcon ~= false
        local castBarHeight = tonumber(config.castBarHeight) or 10
        local castBarIconSize = showCastBarIcon and castBarHeight or 0
        local castBarIconGap = showCastBarIcon and 4 or 0
        local castBarPoint = config.castBarPoint or "BOTTOMLEFT"
        local castBarRelativePoint = config.castBarRelativePoint or "TOPLEFT"
        local castBarOffsetX = tonumber(config.castBarOffsetX) or 0
        local castBarOffsetY = tonumber(config.castBarOffsetY) or 4

        castBar:ClearAllPoints()
        castBar:SetFrameStrata(frame:GetFrameStrata())
        castBar:SetFrameLevel(math.max(frame:GetFrameLevel() + 5, (frame.Elements.HealthBar and frame.Elements.HealthBar:GetFrameLevel() + 1) or (frame:GetFrameLevel() + 5)))
        castBar:SetStatusBarTexture(castTexture)
        ApplyCastBarStateColor(castBar, castBar.isInterruptible, config.castBarColor)

        if castBar.bg then
            castBar.bg:SetTexture(castTexture)
            castBar.bg:SetVertexColor(0, 0, 0, 0.35)
        end

        castBar:SetPoint(
            castBarPoint,
            frame,
            castBarRelativePoint,
            castBarOffsetX + borderInset + castBarIconSize + castBarIconGap,
            castBarOffsetY
        )
        castBar:SetWidth(math.max(width - (borderInset * 2) - castBarIconSize - castBarIconGap, 20))
        castBar:SetHeight(castBarHeight)

        if castBar.icon then
            castBar.icon:ClearAllPoints()
            castBar.icon:SetSize(castBarHeight, castBarHeight)
            castBar.icon:SetPoint("CENTER", castBar, "LEFT", -((castBarHeight / 2) + castBarIconGap), 0)
            if not showCastBarIcon or not castBar.isCasting then
                castBar.icon:SetTexture(nil)
                castBar.icon:Hide()
            end
        end

        if not showCastBar or not castBar.isCasting then
            castBar:Hide()
        end
    end

    -- Portrait
    if frame.Elements.Portrait then
        local portrait = frame.Elements.Portrait
        portrait:ClearAllPoints()
        portrait:SetScale(1)

        if portraitEnabled then
            portrait:SetBackdropColor(0.05, 0.05, 0.05, 0.9)
            portrait:SetBackdropBorderColor(borderR, borderG, borderB, borderA)
            portrait:SetSize(portraitEffectiveSize, portraitEffectiveSize)

            if portraitInside then
                if portraitInsideSide == "RIGHT" then
                    portrait:SetPoint("RIGHT", frame, "RIGHT", -borderInset, 0)
                else
                    portrait:SetPoint("LEFT", frame, "LEFT", borderInset, 0)
                end
            else
                local portraitAnchorParent = self:GetAnchorTarget(frame, portraitAnchorTo) or frame
                portrait:SetPoint(
                    portraitPoint,
                    portraitAnchorParent,
                    portraitRelativePoint,
                    portraitOffsetX,
                    portraitOffsetY
                )
            end

            self:UpdatePortraitTexture(frame)

            portrait:Show()
        else
            if portrait.Texture then
                portrait.Texture:SetTexture(nil)
            end
            portrait:Hide()
        end
    end

    -- Raid Target Icon
    if frame.Elements.RaidTargetIcon then
        local holder = frame.Elements.RaidTargetIcon
        local icon = holder.Texture or holder
        local raidTargetPlacement = raidTargetConfig.placement or "ATTACHED"
        local raidTargetPadding = tonumber(raidTargetConfig.padding) or 2
        local raidTargetInsideSide = raidTargetConfig.insideSide or "RIGHT"

        holder:ClearAllPoints()
        holder:SetScale(1)
        holder:SetFrameStrata(frame:GetFrameStrata())
        holder:SetFrameLevel(math.max(frame:GetFrameLevel() + 20, (frame.Elements.HealthBar and frame.Elements.HealthBar:GetFrameLevel() + 10) or (frame:GetFrameLevel() + 20)))
        icon:ClearAllPoints()
        icon:SetScale(1)

        if raidTargetEnabled then
            local effectiveSize = raidTargetSize * raidTargetScale
            holder:SetSize(effectiveSize, effectiveSize)
            icon:SetAllPoints(holder)

            if raidTargetPlacement == "INSIDE" then
                if raidTargetInsideSide == "LEFT" then
                    holder:SetPoint("TOPLEFT", frame, "TOPLEFT", borderInset + raidTargetPadding, -(borderInset + raidTargetPadding))
                else
                    holder:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -(borderInset + raidTargetPadding), -(borderInset + raidTargetPadding))
                end
            else
                local anchorParent = self:GetAnchorTarget(frame, raidTargetAnchorTo) or frame
                holder:SetPoint(
                    raidTargetPoint,
                    anchorParent,
                    raidTargetRelativePoint,
                    raidTargetOffsetX,
                    raidTargetOffsetY
                )
            end

            self:UpdateRaidTargetIcon(frame)
        else
            icon:SetTexture(nil)
            icon:Hide()
            holder:Hide()
        end
    end

    ApplyOverlayIndicatorConfig(self, frame, frame.Elements.LeaderIcon, {
        enabled = leaderEnabled,
        placement = leaderPlacement,
        size = leaderSize,
        scale = leaderScale,
        padding = leaderPadding,
        insideSide = leaderInsideSide,
        anchorTo = leaderAnchorTo,
        point = leaderPoint,
        relativePoint = leaderRelativePoint,
        offsetX = leaderOffsetX,
        offsetY = leaderOffsetY,
        borderInset = borderInset,
        updateFunc = function(targetFrame)
            self:UpdateLeaderIcon(targetFrame)
        end,
    })

    ApplyOverlayIndicatorConfig(self, frame, frame.Elements.RoleIcon, {
        enabled = roleEnabled,
        placement = rolePlacement,
        size = roleSize,
        scale = roleScale,
        padding = rolePadding,
        insideSide = roleInsideSide,
        anchorTo = roleAnchorTo,
        point = rolePoint,
        relativePoint = roleRelativePoint,
        offsetX = roleOffsetX,
        offsetY = roleOffsetY,
        borderInset = borderInset,
        updateFunc = function(targetFrame)
            self:UpdateRoleIcon(targetFrame)
        end,
    })

    ApplyOverlayIndicatorConfig(self, frame, frame.Elements.CombatIndicator, {
        enabled = combatEnabled,
        placement = combatPlacement,
        size = combatSize,
        scale = combatScale,
        padding = combatPadding,
        insideSide = combatInsideSide,
        anchorTo = combatAnchorTo,
        point = combatPoint,
        relativePoint = combatRelativePoint,
        offsetX = combatOffsetX,
        offsetY = combatOffsetY,
        borderInset = borderInset,
        updateFunc = function(targetFrame)
            self:UpdateCombatIndicator(targetFrame)
        end,
    })

    ApplyOverlayIndicatorConfig(self, frame, frame.Elements.RestingIndicator, {
        enabled = restingEnabled,
        placement = restingPlacement,
        size = restingSize,
        scale = restingScale,
        padding = restingPadding,
        insideSide = restingInsideSide,
        anchorTo = restingAnchorTo,
        point = restingPoint,
        relativePoint = restingRelativePoint,
        offsetX = restingOffsetX,
        offsetY = restingOffsetY,
        borderInset = borderInset,
        updateFunc = function(targetFrame)
            self:UpdateRestingIndicator(targetFrame)
        end,
    })

    ApplyOverlayIndicatorConfig(self, frame, frame.Elements.ReadyCheckIndicator, {
        enabled = readyCheckEnabled,
        placement = readyCheckPlacement,
        size = readyCheckSize,
        scale = readyCheckScale,
        padding = readyCheckPadding,
        insideSide = readyCheckInsideSide,
        anchorTo = readyCheckAnchorTo,
        point = readyCheckPoint,
        relativePoint = readyCheckRelativePoint,
        offsetX = readyCheckOffsetX,
        offsetY = readyCheckOffsetY,
        borderInset = borderInset,
        updateFunc = function(targetFrame)
            self:UpdateReadyCheckIndicator(targetFrame)
        end,
    })

    -- Texts
    if config.Texts then
        for key, textConfig in pairs(config.Texts) do
            self:ApplyTextElementConfig(frame, key, frame.Texts[key], textConfig)
        end
    end
end

function UF:ApplyTestValues(frame)
    self:RefreshUnitBarValues(frame)

    if Portrait.guiTestModeEnabled
        and frame
        and frame.unit == "player"
        and frame.config
        and frame.config.showAlternativePowerBar
        and frame.Elements
        and frame.Elements.AlternativePowerBar
        and GetSecondaryPowerTypeForUnit(frame.unit) ~= nil
    then
        local previewValues = self:GetTestPreviewValues(frame) or {}
        local currentAltPower = previewValues.altPowerCurrent or 72
        local maxAltPower = previewValues.altPowerMax or 100

        frame.LiveValues = frame.LiveValues or {}
        frame.LiveValues.altPowerVisible = maxAltPower > 0
        frame.LiveValues.altPowerType = GetSecondaryPowerTypeForUnit(frame.unit)
        frame.LiveValues.altPowerCurrentRaw = currentAltPower
        frame.LiveValues.altPowerMaxRaw = maxAltPower
        frame.LiveValues.altPowerCurrentText = FormatDisplayNumber(currentAltPower)
        frame.LiveValues.altPowerMaxText = FormatDisplayNumber(maxAltPower)
        frame.LiveValues.altPowerCurrentSafe = ToSafeNumberValue(currentAltPower)
        frame.LiveValues.altPowerMaxSafe = ToSafeNumberValue(maxAltPower)
        frame.LiveValues.altPowerCurrentAbbr = ResolveBlizzardAbbreviation(currentAltPower, frame.LiveValues.altPowerCurrentText)
        frame.LiveValues.altPowerMaxAbbr = ResolveBlizzardAbbreviation(maxAltPower, frame.LiveValues.altPowerMaxText)

        frame.Elements.AlternativePowerBar:SetMinMaxValues(0, math.max(maxAltPower, 1))
        frame.Elements.AlternativePowerBar:SetValue(currentAltPower)
        self:ApplyConfig(frame)
    end

    if Portrait.guiTestModeEnabled then
        StartCastBarPreview(frame)
    else
        StartCastBar(frame)
    end

    if self.ApplyTestTextValues then
        self:ApplyTestTextValues(frame)
    end
end

function UF:RegisterVisibilityEvents(frame)
    if not frame or frame.VisibilityEventFrame or frame.unit == "player" then
        return
    end

    local eventFrame = CreateFrame("Frame", nil, frame)
    eventFrame.owner = frame
    eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    eventFrame:RegisterEvent("UNIT_HEALTH")
    eventFrame:RegisterEvent("UNIT_MAXHEALTH")
    eventFrame:RegisterEvent("UNIT_FLAGS")
    eventFrame:RegisterEvent("UNIT_NAME_UPDATE")
    eventFrame:RegisterEvent("UNIT_TARGETABLE_CHANGED")

    if frame.unit == "target" then
        eventFrame:RegisterEvent("PLAYER_TARGET_CHANGED")
    elseif frame.unit == "focus" then
        eventFrame:RegisterEvent("PLAYER_FOCUS_CHANGED")
    elseif frame.unit == "pet" then
        eventFrame:RegisterEvent("UNIT_PET")
    end

    eventFrame:SetScript("OnEvent", function(_, event, unit)
        local owner = eventFrame.owner
        if not owner then
            return
        end

        if unit and unit ~= owner.unit and not (owner.unit == "pet" and event == "UNIT_PET" and unit == "player") then
            return
        end

        if event == "UNIT_PET" and unit ~= "player" then
            return
        end

        UF:Refresh(owner)
    end)

    frame.VisibilityEventFrame = eventFrame
end

function UF:RegisterHealthBarEvents(frame)
    if not frame or frame.HealthBarEventFrame or not frame.Elements or not frame.Elements.HealthBar then
        return
    end

    local eventFrame = CreateFrame("Frame", nil, frame)
    eventFrame.owner = frame
    eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    if frame.unit and eventFrame.RegisterUnitEvent then
        eventFrame:RegisterUnitEvent("UNIT_HEALTH", frame.unit)
        eventFrame:RegisterUnitEvent("UNIT_MAXHEALTH", frame.unit)
    else
        eventFrame:RegisterEvent("UNIT_HEALTH")
        eventFrame:RegisterEvent("UNIT_MAXHEALTH")
    end

    if frame.unit == "target" then
        eventFrame:RegisterEvent("PLAYER_TARGET_CHANGED")
    elseif frame.unit == "focus" then
        eventFrame:RegisterEvent("PLAYER_FOCUS_CHANGED")
    elseif frame.unit == "pet" then
        eventFrame:RegisterEvent("UNIT_PET")
    end

    eventFrame:SetScript("OnEvent", function(_, event, unit)
        local owner = eventFrame.owner
        if not owner then
            return
        end

        if event == "PLAYER_TARGET_CHANGED" or event == "PLAYER_FOCUS_CHANGED" then
            UF:Refresh(owner)
            return
        end

        if event == "UNIT_PET" then
            if owner.unit ~= "pet" or unit ~= "player" then
                return
            end
            UF:Refresh(owner)
            return
        elseif event == "PLAYER_ENTERING_WORLD" and owner.unit ~= "player" then
            UF:Refresh(owner)
            return
        elseif unit and unit ~= owner.unit then
            return
        end

        UF:RefreshHealth(owner)
    end)

    frame.HealthBarEventFrame = eventFrame
end

function UF:RegisterAlternativePowerEvents(frame)
    if not frame or frame.AlternativePowerEventFrame or frame.unit ~= "player" then
        return
    end

    local eventFrame = CreateFrame("Frame", nil, frame)
    eventFrame.owner = frame
    eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    eventFrame:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
    eventFrame:RegisterUnitEvent("UNIT_POWER_UPDATE", "player")
    eventFrame:RegisterUnitEvent("UNIT_MAXPOWER", "player")
    eventFrame:RegisterUnitEvent("UNIT_DISPLAYPOWER", "player")

    eventFrame:SetScript("OnEvent", function(_, event, unit)
        local owner = eventFrame.owner
        if not owner then
            return
        end

        if unit and unit ~= owner.unit then
            return
        end

        UF:RefreshUnitBarValues(owner)
        UF:ApplyConfig(owner)
        if UF.RefreshLiveValues then
            UF:RefreshLiveValues(owner)
        end
        if UF.UpdateTextElements then
            UF:UpdateTextElements(owner)
        end
    end)

    frame.AlternativePowerEventFrame = eventFrame
end

function UF:Build(unit)
    local config = GetUnitDB(unit)
    if not config or config.enabled == false then
        return nil
    end

    if unit == "player" and config.showAlternativePowerBar then
        config.Texts = config.Texts or {}
        if config.Texts.AltPower == nil and Portrait.GetDefaultDB then
            local defaults = Portrait:GetDefaultDB()
            local defaultAltPowerText = defaults
                and defaults.profile
                and defaults.profile.Units
                and defaults.profile.Units.player
                and defaults.profile.Units.player.Texts
                and defaults.profile.Units.player.Texts.AltPower

            if defaultAltPowerText ~= nil then
                config.Texts.AltPower = CopyTable(defaultAltPowerText)
            end
        end
    end

    local frame = self:CreateBaseFrame(unit, config)
    self:CreateHealthBar(frame)
    self:CreatePowerBar(frame)
    self:CreateAlternativePowerBar(frame)
    self:CreateCastBar(frame)
    self:CreatePortrait(frame)
    self:RegisterPortraitEvents(frame)
    self:CreateRaidTargetIcon(frame)
    self:RegisterRaidTargetEvents(frame)
    self:CreateLeaderIcon(frame)
    self:RegisterLeaderIconEvents(frame)
    self:CreateRoleIcon(frame)
    self:RegisterRoleIconEvents(frame)
    self:CreateCombatIndicator(frame)
    self:RegisterCombatIndicatorEvents(frame)
    self:CreateRestingIndicator(frame)
    self:RegisterRestingIndicatorEvents(frame)
    self:CreateReadyCheckIndicator(frame)
    self:RegisterReadyCheckIndicatorEvents(frame)
    self:RegisterCastBarEvents(frame)
    self:CreateTextElements(frame)
    self:RegisterTextEvents(frame)
    self:RegisterVisibilityEvents(frame)
    self:RegisterHealthBarEvents(frame)
    self:RegisterAlternativePowerEvents(frame)

    self:ApplyConfig(frame)
    self:ApplyTestValues(frame)
    self:Refresh(frame)

    return frame
end

function UF:Refresh(frame)
    if not frame then
        return
    end

    local config = GetUnitDB(frame.unit)
    if not config then
        return
    end

    local isDeadUnit = false

    if not Portrait.guiTestModeEnabled and frame.unit ~= "player" and UnitIsDeadOrGhost then
        isDeadUnit = IsSafeTrue(UnitIsDeadOrGhost(frame.unit))
    end

    if not isDeadUnit and not Portrait.guiTestModeEnabled and frame.unit ~= "player" then
        isDeadUnit = IsUnitDeadByHealth(frame.unit)
    end

    local shouldHideForMissingUnit = not Portrait.guiTestModeEnabled
        and frame.unit ~= "player"
        and (
            (UnitExists and not UnitExists(frame.unit))
            or isDeadUnit
        )

    if shouldHideForMissingUnit then
        if frame.Texts then
            for _, textObject in pairs(frame.Texts) do
                if textObject and textObject.SetText then
                    textObject:SetText("")
                end
            end
        end

        if frame.Elements and frame.Elements.CastBar then
            StopCastBar(frame)
        end

        if frame.SetAlpha then
            frame:SetAlpha(0)
        end

        frame:Hide()
        return
    end

    frame.config = config
    self:RefreshUnitBarValues(frame)
    self:ApplyConfig(frame)
    self:ApplyTestValues(frame)
    if self.RefreshLiveValues then
        self:RefreshLiveValues(frame)
    end
    if self.UpdateTextElements then
        self:UpdateTextElements(frame)
    end
    if frame.SetAlpha then
        frame:SetAlpha(1)
    end
    frame:Show()
end

function Portrait:SpawnUnitFrame(unit)
    self.frames = self.frames or {}

    if self.frames[unit] then
        self.frames[unit]:Hide()
        self.frames[unit] = nil
    end

    local frame = UF:Build(unit)
    if frame then
        self.frames[unit] = frame
        if self.Success then
            self:Success("Spawned frame for " .. unit)
        end
    else
        if self.Warn then
            self:Warn("Could not spawn frame for " .. tostring(unit))
        end
    end

    return frame
end

function Portrait:RefreshUnitFrame(unit)
    if not self.frames or not self.frames[unit] then
        return
    end

    UF:Refresh(self.frames[unit])
end
