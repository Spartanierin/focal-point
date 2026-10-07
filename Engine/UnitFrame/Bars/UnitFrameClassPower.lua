local _, FocalPoint = ...

FocalPoint.UnitFrameClassPower = FocalPoint.UnitFrameClassPower or {}
local ClassPower = FocalPoint.UnitFrameClassPower

local Factory = FocalPoint.UnitFrameFactory or {}
local State = FocalPoint.UnitFrameState or {}
local Utils = FocalPoint.UnitFrameUtils or {}
local Demo = FocalPoint.UnitFrameDemoEnvironment or {}
local VisualPolicy = FocalPoint.EditorVisualPolicy or {}

local GetAnchorTarget = Factory.GetAnchorTarget
local FormatDisplayNumber = Utils.FormatDisplayNumber
local ResolveBlizzardAbbreviation = Utils.ResolveBlizzardAbbreviation
local ToSafeNumberValue = Utils.ToSafeNumberValue

local SPEC_DEMONHUNTER_DEVOURER = _G.SPEC_DEMONHUNTER_DEVOURER or 3
local SPEC_MAGE_ARCANE = _G.SPEC_MAGE_ARCANE or 1
local SPEC_MONK_WINDWALKER = _G.SPEC_MONK_WINDWALKER or 3
local SPEC_SHAMAN_ENHANCEMENT = 2
local SPEC_WARLOCK_DESTRUCTION = _G.SPEC_WARLOCK_DESTRUCTION or 3

local POWER_ID_ARCANE_CHARGES = Enum and Enum.PowerType and Enum.PowerType.ArcaneCharges or 16
local POWER_ID_CHI = Enum and Enum.PowerType and Enum.PowerType.Chi or 12
local POWER_ID_COMBO_POINTS = Enum and Enum.PowerType and Enum.PowerType.ComboPoints or 4
local POWER_ID_ENERGY = Enum and Enum.PowerType and Enum.PowerType.Energy or 3
local POWER_ID_ESSENCE = Enum and Enum.PowerType and Enum.PowerType.Essence or 19
local POWER_ID_HOLY_POWER = Enum and Enum.PowerType and Enum.PowerType.HolyPower or 9
local POWER_ID_MAELSTROM = Enum and Enum.PowerType and Enum.PowerType.Maelstrom or 11
local POWER_ID_RUNES = Enum and Enum.PowerType and Enum.PowerType.Runes or 5
local RUNE_COUNT = 6

local POWER_ID_SOUL_SHARDS = Enum and Enum.PowerType and Enum.PowerType.SoulShards or 7

local POWER_TOKEN_ARCANE_CHARGES = "ARCANE_CHARGES"
local POWER_TOKEN_CHI = "CHI"
local POWER_TOKEN_COMBO_POINTS = "COMBO_POINTS"
local POWER_TOKEN_ESSENCE = "ESSENCE"
local POWER_TOKEN_HOLY_POWER = "HOLY_POWER"
local POWER_TOKEN_MAELSTROM = "MAELSTROM"
local POWER_TOKEN_SOUL_FRAGMENTS = "SOUL_FRAGMENTS"
local POWER_TOKEN_SOUL_SHARDS = "SOUL_SHARDS"

local SPELL_DARK_HEART = 1225789
local SPELL_MAELSTROM_WEAPON = 344179
local SPELL_MAELSTROM_WEAPON_TALENT = 187880
local SPELL_SHRED = 5221
local SPELL_VOID_METAMORPHOSIS = 1217607

local PREVIEW_INFO_BY_CLASS = {
    DEMONHUNTER = { current = 4, max = 5, typeId = nil, token = POWER_TOKEN_SOUL_FRAGMENTS },
    DRUID = { current = 3, max = 5, typeId = POWER_ID_COMBO_POINTS, token = POWER_TOKEN_COMBO_POINTS },
    EVOKER = { current = 4, max = 6, typeId = POWER_ID_ESSENCE, token = POWER_TOKEN_ESSENCE },
    MAGE = { current = 3, max = 4, typeId = POWER_ID_ARCANE_CHARGES, token = POWER_TOKEN_ARCANE_CHARGES },
    MONK = { current = 4, max = 6, typeId = POWER_ID_CHI, token = POWER_TOKEN_CHI },
    PALADIN = { current = 3, max = 5, typeId = POWER_ID_HOLY_POWER, token = POWER_TOKEN_HOLY_POWER },
    ROGUE = { current = 4, max = 5, typeId = POWER_ID_COMBO_POINTS, token = POWER_TOKEN_COMBO_POINTS },
    SHAMAN = { current = 6, max = 10, typeId = POWER_ID_MAELSTROM, token = POWER_TOKEN_MAELSTROM },
    WARLOCK = { current = 4, max = 5, typeId = POWER_ID_SOUL_SHARDS, token = POWER_TOKEN_SOUL_SHARDS },
}

local function GetPlayerClassToken()
    if UnitClassBase then
        return UnitClassBase("player")
    end

    if UnitClass then
        local _, classToken = UnitClass("player")
        return classToken
    end

    return nil
end

local function GetSpecializationIndex()
    if C_SpecializationInfo and C_SpecializationInfo.GetSpecialization then
        return C_SpecializationInfo.GetSpecialization()
    end

    if GetSpecialization then
        return GetSpecialization()
    end

    return nil
end

local function IsKnownSpell(spellID)
    return C_SpellBook and C_SpellBook.IsSpellKnown and spellID and C_SpellBook.IsSpellKnown(spellID) or false
end

local function GetPlayerAuraApplications(spellID)
    if not (C_UnitAuras and C_UnitAuras.GetPlayerAuraBySpellID and spellID) then
        return nil
    end

    local auraInfo = C_UnitAuras.GetPlayerAuraBySpellID(spellID)
    if type(auraInfo) ~= "table" then
        return nil
    end

    return ToSafeNumberValue(auraInfo.applications)
end

local function BuildInfo(typeId, token, current, max)
    local rawCurrent = current
    local rawMax = max
    local safeCurrent = ToSafeNumberValue(current)
    local safeMax = ToSafeNumberValue(max)
    if safeMax <= 0 then
        return nil
    end

    return {
        typeId = typeId,
        token = token,
        current = rawCurrent,
        max = rawMax,
        safeCurrent = safeCurrent,
        safeMax = safeMax,
    }
end

local function GetNumericPowerInfo(typeId, token, current)
    if not UnitPowerMax then
        return nil
    end

    local max = ToSafeNumberValue(UnitPowerMax("player", typeId))
    if current == nil and UnitPower then
        current = ToSafeNumberValue(UnitPower("player", typeId))
    end

    return BuildInfo(typeId, token, current, max)
end

-- Verified Retail PlayerScript/RuneFrame contract: API indices 1..6, seconds,
-- ready flag, and possibly a depleted rune whose recharge has not started yet.
-- Forever (Interface 16001) is deliberately excluded until its contract is verified.
local function CanReadRunes()
    if type(GetRuneCooldown) ~= "function" or not GetBuildInfo then return false end
    local _, _, _, interface = GetBuildInfo()
    return type(interface) == "number" and interface >= 120000
        and (not WOW_PROJECT_ID or WOW_PROJECT_ID == WOW_PROJECT_MAINLINE)
end

local function IsPlainNumber(value)
    return not (issecretvalue and issecretvalue(value))
        and type(value) == "number" and value == value and math.abs(value) < math.huge
end

local function GetRuneInfo()
    if not CanReadRunes() then return nil end
    local segments, current = {}, 0
    for index = 1, RUNE_COUNT do
        local ok, start, duration, ready = pcall(GetRuneCooldown, index)
        if not ok or (issecretvalue and issecretvalue(ready)) or type(ready) ~= "boolean" then
            return nil
        end
        if issecretvalue and (issecretvalue(start) or issecretvalue(duration)) then return nil end
        local segment = { index = index, ready = ready }
        if ready then
            current = current + 1
        elseif start ~= nil then
            if not IsPlainNumber(start) or not IsPlainNumber(duration) or start < 0 or duration < 0 then
                return nil
            end
            if duration > 0 then
                segment.startTime, segment.duration = start, duration
            end
        end
        segments[index] = segment
    end
    local info = BuildInfo(POWER_ID_RUNES, "RUNES", current, RUNE_COUNT)
    info.segments = segments
    return info
end

local function GetWarlockSoulShards()
    if not UnitPower then
        return 0
    end

    local current = ToSafeNumberValue(UnitPower("player", POWER_ID_SOUL_SHARDS))
    if GetSpecializationIndex() == SPEC_WARLOCK_DESTRUCTION and UnitPowerDisplayMod then
        local displayMod = ToSafeNumberValue(UnitPowerDisplayMod(POWER_ID_SOUL_SHARDS))
        if displayMod > 0 then
            current = ToSafeNumberValue(UnitPower("player", POWER_ID_SOUL_SHARDS, true)) / displayMod
        end
    end

    return current
end

local function GetShamanMaelstromWeaponInfo()
    if GetSpecializationIndex() ~= SPEC_SHAMAN_ENHANCEMENT or not IsKnownSpell(SPELL_MAELSTROM_WEAPON_TALENT) then
        return nil
    end

    local current = GetPlayerAuraApplications(SPELL_MAELSTROM_WEAPON) or 0
    local max = C_Spell and C_Spell.GetSpellMaxCumulativeAuraApplications and C_Spell.GetSpellMaxCumulativeAuraApplications(SPELL_MAELSTROM_WEAPON) or 10
    return BuildInfo(POWER_ID_MAELSTROM, POWER_TOKEN_MAELSTROM, current, max)
end

local function GetDemonHunterSoulFragmentsInfo()
    if GetSpecializationIndex() ~= SPEC_DEMONHUNTER_DEVOURER then
        return nil
    end

    local current = GetPlayerAuraApplications(SPELL_DARK_HEART)
    if current == nil and GetPlayerAuraApplications(SPELL_VOID_METAMORPHOSIS) then
        current = 0
    end

    if current == nil then
        return nil
    end

    local max = C_Spell and C_Spell.GetSpellMaxCumulativeAuraApplications and C_Spell.GetSpellMaxCumulativeAuraApplications(SPELL_DARK_HEART) or 5
    return BuildInfo(nil, POWER_TOKEN_SOUL_FRAGMENTS, current, max)
end

local function GetLiveClassPowerInfo()
    local classToken = GetPlayerClassToken()
    if type(classToken) ~= "string" or classToken == "" then
        return nil
    end

    if classToken == "DEATHKNIGHT" then
        return GetRuneInfo()
    elseif classToken == "DEMONHUNTER" then
        return GetDemonHunterSoulFragmentsInfo()
    elseif classToken == "DRUID" then
        if UnitPowerType and UnitPowerType("player") == POWER_ID_ENERGY and IsKnownSpell(SPELL_SHRED) then
            return GetNumericPowerInfo(POWER_ID_COMBO_POINTS, POWER_TOKEN_COMBO_POINTS)
        end
        return nil
    elseif classToken == "EVOKER" then
        return GetNumericPowerInfo(POWER_ID_ESSENCE, POWER_TOKEN_ESSENCE)
    elseif classToken == "MAGE" then
        if GetSpecializationIndex() == SPEC_MAGE_ARCANE then
            return GetNumericPowerInfo(POWER_ID_ARCANE_CHARGES, POWER_TOKEN_ARCANE_CHARGES)
        end
        return nil
    elseif classToken == "MONK" then
        if GetSpecializationIndex() == SPEC_MONK_WINDWALKER then
            return GetNumericPowerInfo(POWER_ID_CHI, POWER_TOKEN_CHI)
        end
        return nil
    elseif classToken == "PALADIN" then
        return GetNumericPowerInfo(POWER_ID_HOLY_POWER, POWER_TOKEN_HOLY_POWER)
    elseif classToken == "ROGUE" then
        return GetNumericPowerInfo(POWER_ID_COMBO_POINTS, POWER_TOKEN_COMBO_POINTS)
    elseif classToken == "SHAMAN" then
        return GetShamanMaelstromWeaponInfo()
    elseif classToken == "WARLOCK" then
        return GetNumericPowerInfo(POWER_ID_SOUL_SHARDS, POWER_TOKEN_SOUL_SHARDS, GetWarlockSoulShards())
    end

    return nil
end

function ClassPower.ShouldForcePreview(unit)
    if unit ~= "player" then
        return false
    end

    local unitConfig = FocalPoint.UnitFrameUtils
        and FocalPoint.UnitFrameUtils.GetUnitDB
        and FocalPoint.UnitFrameUtils.GetUnitDB(unit)
    local selectionPreview = VisualPolicy.IsSelectionPreview and VisualPolicy.IsSelectionPreview({
        _fpUnit = unit,
        config = unitConfig,
    }, {
        kind = "bar",
        unit = unit,
        objectKey = "ClassPowerBar",
    }) == true
    if type(unitConfig) ~= "table"
        or unitConfig.classPowerBarPresent ~= true
        or (unitConfig.showClassPowerBar ~= true and not selectionPreview)
    then
        return false
    end

    if Demo.IsDetailed and Demo.IsDetailed({ unit = "player" }) then
        return true
    end

    if VisualPolicy.Resolve then
        local state = VisualPolicy.Resolve({ unit = unit, config = unitConfig }, "ClassPowerBar", {
            enabled = true,
            hasLiveData = false,
        })
        return state == "editor-simulated"
    end

    return false
end

local function GetPreviewClassPowerInfo(frame)
    local classToken = GetPlayerClassToken()
    if classToken == "DEATHKNIGHT" then
        local info = frame and frame._classPowerPreviewInfo
        local now = GetTime()
        if not info then
            info = BuildInfo(POWER_ID_RUNES, "RUNES", 3, RUNE_COUNT)
            info.segments = {}
            for index = 1, RUNE_COUNT do
                info.segments[index] = { index = index, ready = index <= 3,
                    startTime = index > 3 and (now - (index - 4) * 2) or nil,
                    duration = index > 3 and 10 or nil }
            end
            if frame then frame._classPowerPreviewInfo = info end
        end
        local current = 0
        for _, segment in ipairs(info.segments) do
            if not segment.ready and now >= segment.startTime + segment.duration then
                segment.ready, segment.startTime, segment.duration = true, nil, nil
            end
            if segment.ready then current = current + 1 end
        end
        info.current, info.safeCurrent = current, current
        return info
    end
    local previewInfo = PREVIEW_INFO_BY_CLASS[classToken or ""] or {
        current = 3,
        max = 5,
        typeId = POWER_ID_COMBO_POINTS,
        token = POWER_TOKEN_COMBO_POINTS,
    }

    return BuildInfo(previewInfo.typeId, previewInfo.token, previewInfo.current, previewInfo.max)
end

function ClassPower.GetInfo(unit, frame)
    if unit ~= "player" then
        return nil
    end

    -- Detailed DK preview owns a stable synthetic snapshot, independent of APIs.
    if GetPlayerClassToken() == "DEATHKNIGHT" and Demo.IsDetailed and Demo.IsDetailed(frame or { unit = unit }) then
        return GetPreviewClassPowerInfo(frame)
    end
    local liveInfo = GetLiveClassPowerInfo()
    if liveInfo then
        if frame then frame._classPowerPreviewInfo = nil end
        return liveInfo
    end

    if ClassPower.ShouldForcePreview(unit) then
        return GetPreviewClassPowerInfo(frame)
    end
    if frame then frame._classPowerPreviewInfo = nil end
    return nil
end

local function UnpackColorTable(color)
    if type(color) ~= "table" then
        return nil, nil, nil
    end

    if color.GetRGB then
        local ok, r, g, b = pcall(color.GetRGB, color)
        if ok then
            return r, g, b
        end
    end

    local r = color.r or color[1]
    local g = color.g or color[2]
    local b = color.b or color[3]
    if type(r) == "number" and type(g) == "number" and type(b) == "number" then
        return r, g, b
    end

    return nil, nil, nil
end

local function GetClassPowerColor(info, fallbackR, fallbackG, fallbackB)
    if type(info) ~= "table" then
        return fallbackR, fallbackG, fallbackB
    end

    -- Named resource tokens are canonical; numeric aliases may name a different resource.
    local color = PowerBarColor and info.token and PowerBarColor[info.token] or nil
    if not color and PowerBarColor and info.typeId then
        color = PowerBarColor[info.typeId]
    end
    if not color and FocalPoint.oUF and FocalPoint.oUF.colors and FocalPoint.oUF.colors.power then
        color = FocalPoint.oUF.colors.power[info.token] or FocalPoint.oUF.colors.power[info.typeId]
    end

    if type(color) == "table" and type(color[1]) == "table" then
        local metamorphosisActive = GetPlayerAuraApplications(SPELL_VOID_METAMORPHOSIS) ~= nil
        color = color[metamorphosisActive and 2 or 1] or color[1]
    end

    local r, g, b = UnpackColorTable(color)
    if r and g and b then
        return r, g, b
    end

    return fallbackR, fallbackG, fallbackB
end

function ClassPower.RefreshValues(owner, frame)
    if not frame or not frame._fpUnit or not frame.Elements or not frame.Elements.ClassPowerBar then
        return
    end

    local info = ClassPower.GetInfo(frame._fpUnit, frame)
    frame.LiveValues = frame.LiveValues or {}

    if not info or not info.segments then ClassPower.Clear(frame) end
    frame.LiveValues.classPowerSegments = info and info.segments or nil
    if not info then
        frame.LiveValues.classPowerVisible = false
        frame.LiveValues.classPowerCurrentRaw = 0
        frame.LiveValues.classPowerMaxRaw = 0
        frame.LiveValues.classPowerCurrentText = "0"
        frame.LiveValues.classPowerMaxText = "0"
        frame.LiveValues.classPowerCurrentSafe = 0
        frame.LiveValues.classPowerMaxSafe = 0
        frame.LiveValues.classPowerCurrentAbbr = "0"
        frame.LiveValues.classPowerMaxAbbr = "0"
        frame.LiveValues.classPowerType = nil
        frame.LiveValues.classPowerToken = nil
        return
    end

    frame.LiveValues.classPowerVisible = true
    frame.LiveValues.classPowerCurrentRaw = info.current
    frame.LiveValues.classPowerMaxRaw = info.max
    frame.LiveValues.classPowerCurrentText = FormatDisplayNumber(info.safeCurrent)
    frame.LiveValues.classPowerMaxText = FormatDisplayNumber(info.safeMax)
    frame.LiveValues.classPowerCurrentSafe = info.safeCurrent
    frame.LiveValues.classPowerMaxSafe = info.safeMax
    frame.LiveValues.classPowerCurrentAbbr = ResolveBlizzardAbbreviation(info.current, frame.LiveValues.classPowerCurrentText)
    frame.LiveValues.classPowerMaxAbbr = ResolveBlizzardAbbreviation(info.max, frame.LiveValues.classPowerMaxText)
    frame.LiveValues.classPowerType = info.typeId
    frame.LiveValues.classPowerToken = info.token
end

-- Same local visual-driver pattern as CastRuntime: cached timing only, no API,
-- DB, templates, allocations of state tables, or global refresh in OnUpdate.
local function UpdateSegments(holder)
    local segments = holder.segments
    if not segments or not holder:IsVisible() then
        holder:SetScript("OnUpdate", nil)
        return
    end
    local now, active = GetTime(), false
    for index = 1, #segments do
        local segment, bar = segments[index], holder.Bars[index]
        local remaining = segment.startTime and math.max(0, segment.startTime + segment.duration - now) or nil
        local charging = not segment.ready and remaining and remaining > 0
        if charging then
            bar:SetValue(math.max(0, math.min(1, (now - segment.startTime) / segment.duration)))
            local seconds = math.ceil(remaining)
            if bar._countdownSeconds ~= seconds then
                bar.Countdown:SetText(tostring(seconds))
                bar._countdownSeconds = seconds
            end
            bar.Countdown:Show()
            active = true
        else
            bar:SetValue((segment.ready or remaining == 0) and 1 or 0)
            bar.Countdown:SetText("")
            bar.Countdown:Hide()
            bar._countdownSeconds = nil
        end
    end
    holder:SetScript("OnUpdate", active and UpdateSegments or nil)
end

function ClassPower.Clear(frame)
    if not frame then return end
    frame._classPowerPreviewInfo = nil
    if frame.LiveValues then frame.LiveValues.classPowerSegments = nil end
    local holder = frame.Elements and frame.Elements.ClassPowerBar
    if not holder or not holder._segmentTimingInitialized then return end
    local hadSegments = holder.segments ~= nil
    holder.segments = nil
    holder:SetScript("OnUpdate", nil)
    for _, bar in ipairs(holder.Bars or {}) do
        if hadSegments then bar:SetValue(0) end
        bar._countdownSeconds = nil
        if bar.Countdown then
            bar.Countdown:SetText("")
            bar.Countdown:Hide()
        end
    end
end

local function PrepareSegmentWidgets(holder)
    if holder._segmentTimingInitialized then return end
    holder._segmentTimingInitialized = true
    -- FontStrings belong to the existing bars, never to frame.Texts or entities.
    for _, bar in ipairs(holder.Bars) do
        local text = bar:CreateFontString(nil, "OVERLAY")
        text:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", 10, "OUTLINE")
        text:SetPoint("CENTER", bar, "CENTER", 0, 0)
        text:SetTextColor(1, 1, 1, 1)
        text:Hide()
        bar.Countdown = text
    end
    holder:HookScript("OnHide", function(self) self:SetScript("OnUpdate", nil) end)
    holder:HookScript("OnShow", UpdateSegments)
end

function ClassPower.ApplyLayout(frame, options)
    if not frame or not frame.Elements or not frame.Elements.ClassPowerBar then
        return
    end

    local holder = frame.Elements.ClassPowerBar
    local bars = holder.Bars or {}
    local isVisible = options.classPowerBarVisible == true

    holder:ClearAllPoints()

    if not isVisible then
        ClassPower.Clear(frame)
        holder:Hide()
        for index = 1, #bars do
            bars[index]:Hide()
        end
        return
    end

    if not options.liveClassPowerSegments then
        ClassPower.Clear(frame)
    end

    local width = math.max(40, tonumber(options.classPowerBarWidth) or 100)
    local height = math.max(4, tonumber(options.classPowerBarHeight) or 12)
    local spacing = math.max(0, tonumber(options.classPowerBarSpacing) or 2)
    local anchorParent = GetAnchorTarget and GetAnchorTarget(frame, options.classPowerBarAnchorTo) or frame
    local isPlaceholder = Demo.IsPlaceholder and Demo.IsPlaceholder(frame)
    local placeholderColors = Demo.GetPlaceholderColors and Demo.GetPlaceholderColors() or {}

    holder:SetSize(width, height)
    holder:SetPoint(
        options.classPowerBarPoint or "BOTTOMRIGHT",
        anchorParent or frame,
        options.classPowerBarRelativePoint or "BOTTOMRIGHT",
        tonumber(options.classPowerBarOffsetX) or -5,
        tonumber(options.classPowerBarOffsetY) or 5
    )
    holder:Show()

    local maxValue = math.max(1, math.floor((options.liveClassPowerMax or 0) + 0.5))
    local currentValue = tonumber(options.liveClassPowerCurrent) or 0
    local r, g, b
    if isPlaceholder then
        r = placeholderColors.barR or 0.24
        g = placeholderColors.barG or 0.28
        b = placeholderColors.barB or 0.34
    else
        r, g, b = GetClassPowerColor(
            {
                typeId = options.liveClassPowerType,
                token = options.liveClassPowerToken,
            },
            options.classPowerR,
            options.classPowerG,
            options.classPowerB
        )
    end

    local usableWidth = width - ((maxValue - 1) * spacing)
    local segmentWidth = maxValue > 0 and (usableWidth / maxValue) or usableWidth
    local numActive = currentValue + 0.9
    local borderR = options.classPowerBorderR or 0
    local borderG = options.classPowerBorderG or 0
    local borderB = options.classPowerBorderB or 0
    local borderA = options.classPowerBorderA or 0.85

    for index = 1, #bars do
        local bar = bars[index]
        bar:ClearAllPoints()

        if index <= maxValue then
            if index == 1 then
                bar:SetPoint("TOPLEFT", holder, "TOPLEFT", 0, 0)
            else
                bar:SetPoint("TOPLEFT", bars[index - 1], "TOPRIGHT", spacing, 0)
            end

            bar:SetWidth(segmentWidth)
            bar:SetHeight(height)
            bar:SetStatusBarTexture(options.classPowerTexture)
            bar:SetStatusBarColor(r or 1, g or 1, b or 1, isPlaceholder and (placeholderColors.barA or 0.62) or (options.classPowerA or 1))
            if bar.bg then
                bar.bg:SetTexture(options.classPowerTexture)
                if isPlaceholder then
                    bar.bg:SetVertexColor(placeholderColors.bgR or 0.08, placeholderColors.bgG or 0.10, placeholderColors.bgB or 0.13, placeholderColors.bgA or 0.30)
                else
                    bar.bg:SetVertexColor(options.classPowerBgR or 0, options.classPowerBgG or 0, options.classPowerBgB or 0, options.classPowerBgA or 0.35)
                end
                bar.bg:SetShown(options.classPowerBackgroundShown ~= false)
            end
            if bar.border then
                bar.border:SetBackdropBorderColor(borderR, borderG, borderB, borderA)
                bar.border:Show()
            end

            if index > numActive then
                bar:SetValue(0)
            else
                bar:SetValue(math.max(0, math.min(1, currentValue - index + 1)))
            end

            bar:Show()
        else
            if bar.border then
                bar.border:Hide()
            end
            bar:Hide()
        end
    end
    if options.liveClassPowerSegments then
        PrepareSegmentWidgets(holder)
        holder.segments = options.liveClassPowerSegments
        UpdateSegments(holder)
    end
end

function ClassPower.RegisterEvents(owner, frame)
    if not frame or frame.ClassPowerEventFrame or frame._fpUnit ~= "player" or not frame.Elements or not frame.Elements.ClassPowerBar then
        return
    end

    local eventFrame = CreateFrame("Frame", nil, frame)
    eventFrame.owner = frame
    eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    if CanReadRunes() and GetPlayerClassToken() == "DEATHKNIGHT" then
        eventFrame:RegisterEvent("RUNE_POWER_UPDATE")
        eventFrame:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
        eventFrame:RegisterEvent("PLAYER_ALIVE")
        eventFrame:RegisterEvent("PLAYER_UNGHOST")
    end
    eventFrame:RegisterEvent("PLAYER_LEVEL_UP")
    eventFrame:RegisterEvent("SPELLS_CHANGED")
    eventFrame:RegisterEvent("TRAIT_CONFIG_UPDATED")
    eventFrame:RegisterUnitEvent("UNIT_POWER_UPDATE", "player")
    eventFrame:RegisterUnitEvent("UNIT_MAXPOWER", "player")
    eventFrame:RegisterUnitEvent("UNIT_DISPLAYPOWER", "player")
    eventFrame:RegisterUnitEvent("UNIT_POWER_POINT_CHARGE", "player")
    eventFrame:RegisterUnitEvent("UNIT_AURA", "player")

    eventFrame:SetScript("OnEvent", function(_, event, unit)
        local currentOwner = eventFrame.owner
        if not currentOwner then
            return
        end

        local isUnitEvent = event == "UNIT_POWER_UPDATE"
            or event == "UNIT_MAXPOWER"
            or event == "UNIT_DISPLAYPOWER"
            or event == "UNIT_POWER_POINT_CHARGE"
            or event == "UNIT_AURA"

        if isUnitEvent and unit and unit ~= currentOwner._fpUnit then
            return
        end

        if State.QueueRefresh then
            State.QueueRefresh(currentOwner, event, { "bars", "texts", "layout" })
        else
            if owner.RefreshUnitBarValues then
                owner:RefreshUnitBarValues(currentOwner)
            end
            if owner.ApplyConfig then
                owner:ApplyConfig(currentOwner)
            end
            if owner.RefreshLiveValues then
                owner:RefreshLiveValues(currentOwner)
            end
            if owner.UpdateTextElements then
                owner:UpdateTextElements(currentOwner)
            end
        end
    end)

    frame.ClassPowerEventFrame = eventFrame
end
