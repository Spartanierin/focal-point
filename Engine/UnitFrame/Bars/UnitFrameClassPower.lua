local _, FocalPoint = ...

FocalPoint.UnitFrameClassPower = FocalPoint.UnitFrameClassPower or {}
local ClassPower = FocalPoint.UnitFrameClassPower
local Renderer = FocalPoint.UnitFrameSegmentRenderer

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

local function IsPlainNumber(value)
    return not (issecretvalue and issecretvalue(value))
        and type(value) == "number" and value == value and math.abs(value) < math.huge
end

local function GetPlayerAuraApplications(spellID)
    if not (C_UnitAuras and C_UnitAuras.GetPlayerAuraBySpellID and spellID) then
        return nil, false
    end

    local auraInfo = C_UnitAuras.GetPlayerAuraBySpellID(spellID)
    if issecretvalue and issecretvalue(auraInfo) then return nil, false end
    if type(auraInfo) ~= "table" then
        return nil, auraInfo == nil
    end

    return ToSafeNumberValue(auraInfo.applications), IsPlainNumber(auraInfo.applications)
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
        rawCurrent = rawCurrent, rawMax = rawMax,
        currentKnown = IsPlainNumber(rawCurrent),
        maxKnown = IsPlainNumber(rawMax),
    }
end

-- Only the four newly verified Retail resources join the existing Rogue path.
-- An Enum fallback is sufficient for display, never for highlight capability.
local function CanHighlightRetailPower()
    if not GetBuildInfo or type(UnitPower) ~= "function" or type(UnitPowerMax) ~= "function" then return false end
    local _, _, _, interface = GetBuildInfo()
    return type(interface) == "number" and interface >= 120000
        and (not WOW_PROJECT_ID or WOW_PROJECT_ID == WOW_PROJECT_MAINLINE)
end

local function GetAggregateHighlightResource(class, spec)
    if class == "ROGUE" then return POWER_TOKEN_COMBO_POINTS, POWER_ID_COMBO_POINTS end
    if not CanHighlightRetailPower() or not (Enum and Enum.PowerType) then return nil end
    if class == "PALADIN" then return POWER_TOKEN_HOLY_POWER, Enum.PowerType.HolyPower end
    if class == "MONK" and spec == SPEC_MONK_WINDWALKER then return POWER_TOKEN_CHI, Enum.PowerType.Chi end
    if class == "MAGE" and spec == SPEC_MAGE_ARCANE then return POWER_TOKEN_ARCANE_CHARGES, Enum.PowerType.ArcaneCharges end
    if class == "EVOKER" then return POWER_TOKEN_ESSENCE, Enum.PowerType.Essence end
end

local function GetNumericPowerInfo(typeId, token, current, currentKnown)
    if not UnitPowerMax then
        return nil
    end

    local observedMax = UnitPowerMax("player", typeId)
    local observedCurrent = current
    if current == nil and UnitPower then
        observedCurrent = UnitPower("player", typeId)
    end
    local gainToken, gainType = GetAggregateHighlightResource(GetPlayerClassToken(), GetSpecializationIndex())
    -- Validate original API values before display fallback/normalization.
    local gainValid = gainType ~= nil and gainType == typeId and gainToken == token
        and IsPlainNumber(observedCurrent) and IsPlainNumber(observedMax)
        and observedCurrent >= 0 and observedCurrent <= observedMax
        and observedMax >= 1 and observedMax <= 10 and observedMax % 1 == 0
    local max = ToSafeNumberValue(observedMax)
    if current == nil and UnitPower then current = ToSafeNumberValue(observedCurrent) end
    local info = BuildInfo(typeId, token, current, max)
    if info then
        info.aggregateGainValid = gainValid
        info.rawCurrent, info.rawMax = observedCurrent, observedMax
        info.currentKnown = currentKnown ~= false and IsPlainNumber(observedCurrent)
        info.maxKnown = IsPlainNumber(observedMax)
    end
    return info
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
    if not UnitPower then return 0, false end
    local observed = UnitPower("player", POWER_ID_SOUL_SHARDS)
    local known = IsPlainNumber(observed)
    local current = ToSafeNumberValue(observed)
    if GetSpecializationIndex() == SPEC_WARLOCK_DESTRUCTION and UnitPowerDisplayMod then
        local observedMod = UnitPowerDisplayMod(POWER_ID_SOUL_SHARDS)
        local displayMod = ToSafeNumberValue(observedMod)
        known = known and IsPlainNumber(observedMod)
        if displayMod > 0 then
            observed = UnitPower("player", POWER_ID_SOUL_SHARDS, true)
            known = known and IsPlainNumber(observed)
            current = ToSafeNumberValue(observed) / displayMod
        end
    end
    return current, known
end

local function GetShamanMaelstromWeaponInfo()
    if GetSpecializationIndex() ~= SPEC_SHAMAN_ENHANCEMENT or not IsKnownSpell(SPELL_MAELSTROM_WEAPON_TALENT) then
        return nil
    end

    local current, known = GetPlayerAuraApplications(SPELL_MAELSTROM_WEAPON)
    current = current or 0
    local max = C_Spell and C_Spell.GetSpellMaxCumulativeAuraApplications and C_Spell.GetSpellMaxCumulativeAuraApplications(SPELL_MAELSTROM_WEAPON) or 10
    local info = BuildInfo(POWER_ID_MAELSTROM, POWER_TOKEN_MAELSTROM, current, max)
    if info then info.currentKnown = known end
    return info
end

local function GetDemonHunterSoulFragmentsInfo()
    if GetSpecializationIndex() ~= SPEC_DEMONHUNTER_DEVOURER then
        return nil
    end

    local current, known = GetPlayerAuraApplications(SPELL_DARK_HEART)
    if current == nil then
        local metamorphosis, readable = GetPlayerAuraApplications(SPELL_VOID_METAMORPHOSIS)
        if metamorphosis then current, known = 0, known and readable end
    end

    if current == nil then
        return nil
    end

    local max = C_Spell and C_Spell.GetSpellMaxCumulativeAuraApplications and C_Spell.GetSpellMaxCumulativeAuraApplications(SPELL_DARK_HEART) or 5
    local info = BuildInfo(nil, POWER_TOKEN_SOUL_FRAGMENTS, current, max)
    if info then info.currentKnown = known end
    return info
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

function ClassPower.ShouldForcePreview(unit, frame)
    if unit ~= "player" then return false end
    local unitConfig = frame and frame.config or (Utils.GetUnitDB and Utils.GetUnitDB(unit))
    local context = frame or { _fpUnit = unit, config = unitConfig }
    local selectionPreview = VisualPolicy.IsSelectionPreview and VisualPolicy.IsSelectionPreview(context, {
        kind = "bar", unit = unit, objectKey = "ClassPowerBar",
    }) == true
    if type(unitConfig) ~= "table" or unitConfig.classPowerBarPresent ~= true
        or (unitConfig.showClassPowerBar ~= true and not selectionPreview) then
        return false
    end

    -- Resolve the actual context; a fresh proxy has no committed demo runtime.
    local mode = Demo.ResolveMode and Demo.ResolveMode(context, "classPower")
    if mode == "disabled" then return false end
    if mode == "detailed" then return true end
    if VisualPolicy.Resolve then
        local state = VisualPolicy.Resolve(context, "ClassPowerBar", { enabled = true, hasLiveData = false })
        return state == "editor-simulated" or (selectionPreview and state == "selection-simulated")
    end
    return false
end

local function GetPreviewClassPowerInfo(frame, previewMode)
    local classToken = GetPlayerClassToken()
    -- Selection previews the local timer presentation, regardless of the player's
    -- live resource. Detailed mode retains the existing class-specific provider.
    if classToken == "DEATHKNIGHT" or previewMode == "selection" then
        local config = frame and frame.config or nil
        local editorState = FocalPoint.GUI and FocalPoint.GUI.Editor and FocalPoint.GUI.Editor.State
        local scope = previewMode == "selection" and editorState and editorState.GetPropertyScope and editorState.GetPropertyScope() or nil
        local resolver = FocalPoint.ActiveLayoutResolver
        local root = resolver and resolver.GetActiveRuntimeRoot and resolver.GetActiveRuntimeRoot() or nil
        local font = config and config.classPowerRuneTimerFont
        local size = config and config.classPowerRuneTimerFontSize
        local style = config and config.classPowerRuneTimerFontStyle
        local info = frame and frame._classPowerPreviewInfo
        local now = GetTime()
        if not info or info.previewMode ~= previewMode or info.previewScope ~= scope
            or info.previewConfig ~= config or info.previewRoot ~= root or info.previewClass ~= classToken
            or info.previewFont ~= font or info.previewSize ~= size or info.previewStyle ~= style then
            info = BuildInfo(POWER_ID_RUNES, "RUNES", 3, RUNE_COUNT)
            info.previewMode, info.previewScope, info.previewConfig = previewMode, scope, config
            info.previewRoot, info.previewClass = root, classToken
            info.previewFont, info.previewSize, info.previewStyle = font, size, style
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
    if unit ~= "player" then return nil end
    local mode = Demo.ResolveMode and Demo.ResolveMode(frame or { _fpUnit = unit }, "classPower")
    if GetPlayerClassToken() == "DEATHKNIGHT" and mode == "detailed" then
        return GetPreviewClassPowerInfo(frame, "detailed"), "preview"
    end
    local config = frame and frame.config
    if config and config.classPowerBarPresent == true and config.showClassPowerBar == true
        and VisualPolicy.IsSelectionPreview and VisualPolicy.IsSelectionPreview(frame, {
            kind = "bar", unit = unit, objectKey = "ClassPowerBar",
        }) then
        return GetPreviewClassPowerInfo(frame, "selection"), "preview"
    end
    local previous = frame and frame._classPowerPreviewInfo
    if previous and (previous.previewMode == "selection" or previous.previewMode == "detailed") then
        frame._classPowerPreviewInfo = nil
    end
    local liveInfo = GetLiveClassPowerInfo()
    if liveInfo then
        if frame then frame._classPowerPreviewInfo = nil end
        return liveInfo, "live"
    end
    if ClassPower.ShouldForcePreview(unit, frame) then
        return GetPreviewClassPowerInfo(frame, "fallback"), "preview"
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

-- Pure palette resolution: no class/spec/aura reads. Unresolved variant palettes
-- return fallback RGB plus the palette for the existing Legacy wrapper only.
function ClassPower.ResolveResourceColor(info, spec, fallbackR, fallbackG, fallbackB)
    if type(info) ~= "table" then
        return fallbackR, fallbackG, fallbackB
    end

    if info.token == "RUNES" then
        local runeColors = FocalPoint.oUF and FocalPoint.oUF.colors and FocalPoint.oUF.colors.runes
        if IsPlainNumber(spec) and (spec == 1 or spec == 2 or spec == 3) and runeColors then
            -- FP interprets Blizzard Blood/Frost/Unholy atlas art using the existing
            -- oUF rune palette; these are not official Blizzard RGB API values.
            local r, g, b = UnpackColorTable(runeColors[spec])
            if r and g and b then
                return r, g, b
            end
        end
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
        return fallbackR, fallbackG, fallbackB, color
    end

    local r, g, b = UnpackColorTable(color)
    if r and g and b then
        return r, g, b
    end

    return fallbackR, fallbackG, fallbackB
end

-- Preserve Legacy resource-specific observation and nil/true/false mode semantics.
local function GetClassPowerColor(info, fallbackR, fallbackG, fallbackB)
    local spec = type(info) == "table" and info.token == "RUNES"
        and ToSafeNumberValue(GetSpecializationIndex()) or nil
    local r, g, b, variants = ClassPower.ResolveResourceColor(info, spec, fallbackR, fallbackG, fallbackB)
    if variants then
        local metamorphosisActive = GetPlayerAuraApplications(SPELL_VOID_METAMORPHOSIS) ~= nil
        r, g, b = UnpackColorTable(variants[metamorphosisActive and 2 or 1] or variants[1])
        if not (r and g and b) then return fallbackR, fallbackG, fallbackB end
    end
    return r, g, b
end

-- The source owns event evidence and qualification. Holders only present it.
local StopSegmentHighlight = Renderer.StopHighlight
local PlaySegmentHighlight = Renderer.PlayHighlight
local SnapshotContext

local function ResetHighlights(holder)
    if not holder then return end
    holder._readyConsumer = nil
    for _, bar in ipairs(holder.Bars or {}) do StopSegmentHighlight(bar) end
end

local function ResolveSegmentGrowth(value)
    return value == "RIGHT_TO_LEFT" and "RIGHT_TO_LEFT" or "LEFT_TO_RIGHT"
end

local function ClearRuneTiming(frame)
    if not frame then return end
    frame._classPowerPreviewInfo = nil
    if frame.LiveValues then frame.LiveValues.classPowerSegments = nil end
    local holder = frame.Elements and frame.Elements.ClassPowerBar
    if holder then holder._runeSlotBinding = nil end
    Renderer.ClearTiming(holder)
end

-- Context, not elapsed time or a queue token, validates render-only consumers.
-- Every RefreshValues call publishes a fresh observation, including direct refreshes.
SnapshotContext = function(frame)
    local resolver = FocalPoint.ActiveLayoutResolver
    local editor = FocalPoint.GUI and FocalPoint.GUI.Editor and FocalPoint.GUI.Editor.State
    local config = frame.config or {}
    local selection = VisualPolicy.IsSelectionPreview and VisualPolicy.IsSelectionPreview(frame, {
        kind = "bar", unit = frame._fpUnit, objectKey = "ClassPowerBar",
    }) == true
    local mode = Demo.ResolveMode and Demo.ResolveMode(frame, "classPower")
    return {
        unit = frame._fpUnit, config = frame.config,
        root = resolver and resolver.GetActiveRuntimeRoot and resolver.GetActiveRuntimeRoot(),
        class = GetPlayerClassToken(), spec = GetSpecializationIndex(),
        mode = mode, selection = selection,
        scope = selection and editor and editor.GetPropertyScope and editor.GetPropertyScope() or nil,
        unlocked = FocalPoint.framesUnlocked == true, demo = FocalPoint.guiTestModeEnabled == true,
        enabled = config.enabled, present = config.classPowerBarPresent, shown = config.showClassPowerBar,
        -- Only synthetic timer presentation restarts on these style changes.
        font = (selection or mode == "detailed") and config.classPowerRuneTimerFont or nil,
        size = (selection or mode == "detailed") and config.classPowerRuneTimerFontSize or nil,
        style = (selection or mode == "detailed") and config.classPowerRuneTimerFontStyle or nil,
        runeAPI = GetRuneCooldown, powerAPI = UnitPower, maxAPI = UnitPowerMax,
    }
end

local function SameSnapshotContext(a, b)
    for key, value in pairs(a) do if b[key] ~= value then return false end end
    for key, value in pairs(b) do if a[key] ~= value then return false end end
    return true
end

-- This identity contains gameplay source boundaries, never growth, visibility or
-- presentation style. An epoch changes when any of these boundaries changes.
local SOURCE_FIELDS = { "unit", "root", "class", "spec", "mode", "selection", "scope",
    "demo", "runeAPI", "powerAPI", "maxAPI", "source", "token", "typeId" }

local function SourceKey(context, source, info)
    return {
        unit = context.unit, root = context.root, class = context.class, spec = context.spec,
        mode = context.mode, selection = context.selection, scope = context.scope,
        demo = context.demo, runeAPI = context.runeAPI, powerAPI = context.powerAPI,
        maxAPI = context.maxAPI, source = source, token = info and info.token,
        typeId = info and info.typeId,
    }
end

local function SameSourceKey(a, b)
    if not a or not b then return false end
    for _, field in ipairs(SOURCE_FIELDS) do
        if a[field] ~= b[field] then return false end
    end
    return true
end

local function ValidSourceInfo(info, source)
    if source ~= "live" or type(info) ~= "table" then return false end
    if info.token == "RUNES" then
        if info.currentKnown ~= true or info.maxKnown ~= true
            or info.max ~= RUNE_COUNT or type(info.segments) ~= "table" or #info.segments ~= RUNE_COUNT then return false end
        for index = 1, RUNE_COUNT do
            local segment = info.segments[index]
            if type(segment) ~= "table" or segment.index ~= index
                or (issecretvalue and (issecretvalue(segment.ready)
                    or issecretvalue(segment.startTime) or issecretvalue(segment.duration)))
                or type(segment.ready) ~= "boolean" then
                return false
            end
            if (segment.startTime == nil) ~= (segment.duration == nil) then return false end
            if segment.startTime ~= nil and (not IsPlainNumber(segment.startTime)
                or not IsPlainNumber(segment.duration)
                or segment.startTime < 0 or segment.duration < 0) then return false end
        end
        return true
    end
    return info.aggregateGainValid == true and info.currentKnown == true and info.maxKnown == true
        and IsPlainNumber(info.current) and IsPlainNumber(info.max)
        and info.current >= 0 and info.current <= info.max
        and info.max >= 1 and info.max <= 10 and info.max % 1 == 0
end

local function PublishTransitions(frame, context, info, source)
    local values = frame.LiveValues
    local key = SourceKey(context, source, info)
    local state = values.classPowerTransitionState
    if not state or not SameSourceKey(state.key, key) then
        state = { epoch = {}, revision = 0, nextId = 0, key = key }
        values.classPowerTransitionState = state
    end
    state.revision = state.revision + 1
    local transitions = {}
    local valid = context.unit == "player" and context.root ~= nil and not context.demo
        and not (Demo.IsFrameInDemoMode and Demo.IsFrameInDemoMode(frame))
        and ValidSourceInfo(info, source)
    if valid and state.baseline and state.max == info.max and state.eventObserved then
        if info.token == "RUNES" then
            for index = 1, RUNE_COUNT do
                if state.baseline[index].ready == false and info.segments[index].ready then
                    state.nextId = state.nextId + 1
                    transitions[#transitions + 1] = {
                        id = { epoch = state.epoch, sequence = state.nextId },
                        revision = state.revision, apiIndex = index,
                    }
                end
            end
        elseif info.current > state.baseline then
            for index = math.floor(state.baseline) + 1, math.floor(info.current) do
                state.nextId = state.nextId + 1
                transitions[#transitions + 1] = {
                    id = { epoch = state.epoch, sequence = state.nextId },
                    revision = state.revision, apiIndex = index,
                }
            end
        end
    end
    state.baseline = valid and (info.segments or info.current) or nil
    state.max = valid and info.max or nil
    state.eventObserved = false
    return state.epoch, state.revision, transitions, valid
end

local function InvalidateSource(frame)
    if frame.LiveValues then frame.LiveValues.classPowerTransitionState = nil end
end

local function StopSpentHighlights(holder, info)
    if info.token == "RUNES" then
        local binding = holder._runeSlotBinding
        if not binding then
            ResetHighlights(holder)
            return
        end
        for apiIndex = 1, RUNE_COUNT do
            local slot = binding.apiToSlot[apiIndex]
            local bar = slot and holder.Bars[slot]
            if bar and not info.segments[apiIndex].ready and not bar._visualRechargeFlashActive then
                StopSegmentHighlight(bar)
            end
        end
    else
        for index = math.floor(info.current) + 1, #holder.Bars do
            StopSegmentHighlight(holder.Bars[index])
        end
    end
end

-- A bars-only source refresh still stops an observed spent flash immediately.
-- It never claims a transition or advances the consumer's play cursor.
local function StopObservedHighlights(frame, epoch, info, valid)
    local holder = frame.Elements and frame.Elements.ClassPowerBar
    local consumer = holder and holder._readyConsumer
    if not consumer then return end
    if not valid or consumer.epoch ~= epoch or consumer.config ~= frame.config
        or consumer.editor ~= (FocalPoint.framesUnlocked == true) then
        ResetHighlights(holder)
    else
        StopSpentHighlights(holder, info)
    end
end

local function ApplyReadyConsumer(frame, handoff)
    local holder = frame.Elements.ClassPowerBar
    if not holder._highlightLifecycle then
        holder._highlightLifecycle = true
        holder:HookScript("OnHide", function() ResetHighlights(holder) end)
        holder:HookScript("OnShow", function() ResetHighlights(holder) end)
        for _, bar in ipairs(holder.Bars) do
            bar:HookScript("OnHide", function() ResetHighlights(holder) end)
        end
    end
    local snapshot = frame.LiveValues and frame.LiveValues.classPowerSnapshot
    local info = snapshot and snapshot.info
    local config = frame.config
    if not snapshot or snapshot.source ~= "live" or snapshot.sourceInfo ~= info
        or not snapshot.context.root or FocalPoint.guiTestModeEnabled
        or (Demo.IsFrameInDemoMode and Demo.IsFrameInDemoMode(frame))
        or frame._classPowerPreviewInfo
        or not SameSnapshotContext(snapshot.context, SnapshotContext(frame))
        or frame._fpUnit ~= "player" or not holder:IsVisible()
        or not config or config.classPowerBarPresent ~= true or config.showClassPowerBar ~= true
        or not ValidSourceInfo(info, snapshot.source) then
        ResetHighlights(holder)
        return
    end
    local state = holder._readyConsumer
    if not state or state.epoch ~= snapshot.epoch or state.config ~= config
        or state.editor ~= (FocalPoint.framesUnlocked == true) then
        if state then ResetHighlights(holder) end
        -- A newly bound consumer starts at the current revision; it never replays.
        state = { epoch = snapshot.epoch, config = config,
            editor = FocalPoint.framesUnlocked == true, lastRevision = snapshot.revision }
        holder._readyConsumer = state
    else
        local newRevision = snapshot.revision > state.lastRevision
        state.lastRevision = snapshot.revision
        if info.token ~= "RUNES" and newRevision and handoff == snapshot
            and #snapshot.readyTransitions > 0 then
            for _, transition in ipairs(snapshot.readyTransitions) do
                if transition.revision == snapshot.revision then
                    PlaySegmentHighlight(holder.Bars[transition.apiIndex])
                end
            end
        end
    end
    StopSpentHighlights(holder, info)
end

ClassPower.PresentReady = ApplyReadyConsumer

-- Explicit first-apply/context-change initialization. A cached unavailable source
-- is also a valid observation; repeated consumers must not retry its API.
function ClassPower.GetSnapshotInfo(owner, frame)
    if not frame or not frame._fpUnit or not frame.Elements or not frame.Elements.ClassPowerBar then return nil end
    local snapshot = frame.LiveValues and frame.LiveValues.classPowerSnapshot
    if not snapshot or not SameSnapshotContext(snapshot.context, SnapshotContext(frame)) then
        ResetHighlights(frame.Elements.ClassPowerBar)
        return ClassPower.RefreshValues(owner, frame)
    end
    return snapshot.info
end

function ClassPower.RefreshValues(owner, frame)
    if not frame or not frame._fpUnit or not frame.Elements or not frame.Elements.ClassPowerBar then
        return
    end

    local info, source = ClassPower.GetInfo(frame._fpUnit, frame)
    frame.LiveValues = frame.LiveValues or {}
    local context = SnapshotContext(frame)
    local epoch, revision, readyTransitions, valid = PublishTransitions(frame, context, info, source or "unavailable")

    if not info or not info.segments then ClearRuneTiming(frame) end
    frame.LiveValues.classPowerSnapshot = {
        context = context, info = info, source = source or "unavailable",
        epoch = epoch, revision = revision, readyTransitions = readyTransitions,
        -- Synthetic values never become authoritative gameplay data.
        sourceInfo = source == "live" and info or nil,
        available = info ~= nil,
        currentKnown = info ~= nil and info.currentKnown == true,
        maxKnown = info ~= nil and info.maxKnown == true,
    }
    frame.LiveValues.classPowerSegments = info and info.segments or nil
    StopObservedHighlights(frame, epoch, info, valid)
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
    return info
end

function ClassPower.Clear(frame, preserveSnapshot)
    if not frame then return end
    ResetHighlights(frame.Elements and frame.Elements.ClassPowerBar)
    if frame.LiveValues and not preserveSnapshot then
        frame.LiveValues.classPowerSnapshot = nil
        InvalidateSource(frame)
    end
    ClearRuneTiming(frame)
end

-- Only the existing provider/preview snapshots enter here: ready is readable and
-- recharge timing is validated. Sort API indices, never the canonical records.
-- This mapping is local to layout application, not countdown ticks or saved state.
local function GetRuneVisualSlots(segments)
    if not segments then return nil end
    local order, slots = {}, {}
    for index = 1, #segments do order[index] = index end
    table.sort(order, function(a, b)
        local left, right = segments[a], segments[b]
        local leftGroup = left.ready and 1 or (left.startTime and 2 or 3)
        local rightGroup = right.ready and 1 or (right.startTime and 2 or 3)
        if leftGroup ~= rightGroup then return leftGroup < rightGroup end
        if leftGroup == 2 then
            local leftEnd = left.startTime + left.duration
            local rightEnd = right.startTime + right.duration
            if leftEnd ~= rightEnd then return leftEnd < rightEnd end
        end
        return a < b
    end)
    for slot, index in ipairs(order) do slots[index] = slot end
    return slots
end

-- Pure slot projection shared by rune consumers; API-index identity is unchanged.
ClassPower.GetRuneVisualSlots = GetRuneVisualSlots

-- Legacy DK only: the source stays API-indexed while the six widgets stay in
-- fixed growth-order slots. This is a presentation view of one snapshot.
local function ProjectRuneSlots(segments)
    if type(segments) ~= "table" or #segments ~= RUNE_COUNT then return nil end
    for apiIndex = 1, RUNE_COUNT do
        local segment = segments[apiIndex]
        if type(segment) ~= "table"
            or (issecretvalue and (issecretvalue(segment.index) or issecretvalue(segment.ready)
                or issecretvalue(segment.startTime) or issecretvalue(segment.duration)))
            or segment.index ~= apiIndex
            or type(segment.ready) ~= "boolean"
            or (segment.startTime == nil) ~= (segment.duration == nil)
            or (segment.startTime ~= nil and (not IsPlainNumber(segment.startTime)
                or not IsPlainNumber(segment.duration)
                or segment.startTime < 0 or segment.duration <= 0)) then
            return nil
        end
    end
    local apiToSlot = GetRuneVisualSlots(segments)
    local slotToApi, segmentsBySlot, fixedSlots = {}, {}, {}
    for apiIndex = 1, RUNE_COUNT do
        local slot = apiToSlot and apiToSlot[apiIndex]
        if type(slot) ~= "number" or slot % 1 ~= 0 or slot < 1 or slot > RUNE_COUNT
            or slotToApi[slot] then return nil end
        slotToApi[slot] = apiIndex
        segmentsBySlot[slot] = segments[apiIndex]
        fixedSlots[slot] = slot
    end
    for slot = 1, RUNE_COUNT do
        if not slotToApi[slot] then return nil end
    end
    return apiToSlot, slotToApi, segmentsBySlot, fixedSlots
end

function ClassPower.ApplyLayout(frame, options, handoff, deferReadyConsumer)
    if not frame or not frame.Elements or not frame.Elements.ClassPowerBar then
        return
    end

    local holder = frame.Elements.ClassPowerBar
    local bars = holder.Bars or {}
    local isVisible = options.classPowerBarVisible == true

    holder:ClearAllPoints()

    if not isVisible then
        ClassPower.Clear(frame, true)
        holder:Hide()
        for index = 1, #bars do
            bars[index]:Hide()
        end
        return
    end

    if not options.liveClassPowerSegments then
        ClearRuneTiming(frame)
    end

    local width = math.max(40, tonumber(options.classPowerBarWidth) or 100)
    local height = math.max(4, tonumber(options.classPowerBarHeight) or 12)
    local spacing = math.max(0, tonumber(options.classPowerBarSpacing) or 2)
    local rightToLeft = ResolveSegmentGrowth(options.classPowerBarGrowth) == "RIGHT_TO_LEFT"
    local anchorParent = GetAnchorTarget and GetAnchorTarget(frame, options.classPowerBarAnchorTo) or frame
    local isPlaceholder = Demo.IsPlaceholder and Demo.IsPlaceholder(frame)
    local placeholderColors = Demo.GetPlaceholderColors and Demo.GetPlaceholderColors() or {}

    local maxValue = math.max(1, math.floor((options.liveClassPowerMax or 0) + 0.5))
    local currentValue = tonumber(options.liveClassPowerCurrent) or 0
    local r, g, b
    if isPlaceholder then
        r = placeholderColors.barR or 0.24
        g = placeholderColors.barG or 0.28
        b = placeholderColors.barB or 0.34
    elseif options.useBlizzardColorClassPower == false then
        r, g, b = options.classPowerR, options.classPowerG, options.classPowerB
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

    local snapshot = frame.LiveValues and frame.LiveValues.classPowerSnapshot
    local runeLayout = frame._fpUnit == "player" and snapshot and snapshot.context
        and snapshot.context.class == "DEATHKNIGHT" and options.liveClassPowerToken == "RUNES"
    local visualSlots
    local segments = options.liveClassPowerSegments
    local slotToApi, apiToSlot
    if runeLayout then
        if snapshot.available ~= true or (snapshot.source ~= "live" and snapshot.source ~= "preview")
            or (snapshot.source == "live" and (snapshot.sourceInfo ~= snapshot.info
                or not ValidSourceInfo(snapshot.info, snapshot.source)))
            or type(snapshot.info) ~= "table" or snapshot.info.segments ~= segments
            or snapshot.info.max ~= RUNE_COUNT or maxValue ~= RUNE_COUNT then
            ClassPower.Clear(frame, true)
            holder:Hide()
            for _, bar in ipairs(bars) do bar:Hide() end
            return
        end
        local fixedSlots, projected
        apiToSlot, slotToApi, projected, fixedSlots = ProjectRuneSlots(segments)
        if not apiToSlot then
            ClassPower.Clear(frame, true)
            holder:Hide()
            for _, bar in ipairs(bars) do bar:Hide() end
            return
        end
        visualSlots, segments = fixedSlots, projected
        local previous = holder._runeSlotBinding
        local rebound = holder.segments ~= nil and not previous
        if previous then
            for slot = 1, RUNE_COUNT do
                if previous.slotToApi[slot] ~= slotToApi[slot] then
                    StopSegmentHighlight(bars[slot])
                    rebound = true
                end
            end
        end
        if rebound then Renderer.ClearTiming(holder) end
    else
        visualSlots = GetRuneVisualSlots(segments)
    end
    -- A binding is published only after the renderer has painted its slot data.
    holder._runeSlotBinding = nil
    local legacyRuneVisualFlash = frame._fpUnit == "player" and snapshot
        and snapshot.source == "live" and snapshot.sourceInfo == snapshot.info
        and snapshot.context and snapshot.context.class == "DEATHKNIGHT"
        and snapshot.context.root and not snapshot.context.demo and not snapshot.context.selection
        and snapshot.info and snapshot.info.token == "RUNES" and snapshot.info.max == RUNE_COUNT
        and snapshot.info.segments == options.liveClassPowerSegments
        and FocalPoint.guiTestModeEnabled ~= true and not frame._classPowerPreviewInfo
        and not (Demo.IsFrameInDemoMode and Demo.IsFrameInDemoMode(frame))
        and not (VisualPolicy.IsSelectionPreview and VisualPolicy.IsSelectionPreview(frame, {
            kind = "bar", unit = "player", objectKey = "ClassPowerBar",
        }))
    Renderer.Apply(holder, {
        width = width, height = height, spacing = spacing,
        rightToLeft = rightToLeft,
        anchorParent = anchorParent or frame,
        point = options.classPowerBarPoint or "BOTTOMRIGHT",
        relativePoint = options.classPowerBarRelativePoint or "BOTTOMRIGHT",
        x = tonumber(options.classPowerBarOffsetX) or -5,
        y = tonumber(options.classPowerBarOffsetY) or 5,
        max = maxValue, current = currentValue,
        visualSlots = visualSlots,
        legacyRuneVisualFlash = legacyRuneVisualFlash == true,
        legacyRuneFlashEpoch = legacyRuneVisualFlash and snapshot.epoch or nil,
        segments = segments,
        texture = options.classPowerTexture,
        r = r, g = g, b = b,
        a = isPlaceholder and (placeholderColors.barA or 0.62) or (options.classPowerA or 1),
        bgR = isPlaceholder and (placeholderColors.bgR or 0.08) or (options.classPowerBgR or 0),
        bgG = isPlaceholder and (placeholderColors.bgG or 0.10) or (options.classPowerBgG or 0),
        bgB = isPlaceholder and (placeholderColors.bgB or 0.13) or (options.classPowerBgB or 0),
        bgA = isPlaceholder and (placeholderColors.bgA or 0.30) or (options.classPowerBgA or 0.35),
        backgroundShown = options.classPowerBackgroundShown,
        borderR = options.classPowerBorderR or 0,
        borderG = options.classPowerBorderG or 0,
        borderB = options.classPowerBorderB or 0,
        borderA = options.classPowerBorderA or 0.85,
        timerFont = options.classPowerRuneTimerFont,
        timerFontSize = options.classPowerRuneTimerFontSize,
        timerFontStyle = options.classPowerRuneTimerFontStyle,
    })
    if FocalPoint.UnitFrameFactory and FocalPoint.UnitFrameFactory.ApplyBarBorder then
        local config = frame.config or {}
        FocalPoint.UnitFrameFactory.ApplyBarBorder(holder, config.classPowerBarBorderWidth, config.classPowerBarBorderColor, true)
    end
    if runeLayout then
        holder._runeSlotBinding = {
            snapshot = snapshot, apiToSlot = apiToSlot, slotToApi = slotToApi,
        }
    end
    if deferReadyConsumer then
        return true
    end
    ApplyReadyConsumer(frame, handoff)
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
    end
    local class = GetPlayerClassToken()
    if (CanReadRunes() and class == "DEATHKNIGHT") or class == "ROGUE"
        or (CanHighlightRetailPower() and (class == "PALADIN" or class == "MONK" or class == "MAGE" or class == "EVOKER")) then
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

    eventFrame:SetScript("OnEvent", function(_, event, unit, powerToken)
        local currentOwner = eventFrame.owner
        if not currentOwner then
            return
        end

        local isUnitEvent = event == "UNIT_POWER_UPDATE"
            or event == "UNIT_MAXPOWER"
            or event == "UNIT_DISPLAYPOWER"
            or event == "UNIT_POWER_POINT_CHARGE"
            or event == "UNIT_AURA"

        local readableUnit
        if isUnitEvent then
            readableUnit = not (issecretvalue and issecretvalue(unit))
        end
        if isUnitEvent and readableUnit and unit and unit ~= currentOwner._fpUnit then
            return
        end

        local holder = currentOwner.Elements and currentOwner.Elements.ClassPowerBar
        local values = currentOwner.LiveValues
        local snapshot = values and values.classPowerSnapshot
        local state = values and values.classPowerTransitionState
        local valid = snapshot and state and snapshot.epoch == state.epoch
            and state.baseline and snapshot.source == "live"
            and SameSourceKey(state.key, SourceKey(SnapshotContext(currentOwner), snapshot.source, snapshot.info))
        if event == "RUNE_POWER_UPDATE" then
            -- The payload may be secret; only the event and later S1 comparison matter.
            if valid and state.key.token == "RUNES" then state.eventObserved = true end
        elseif event == "UNIT_POWER_UPDATE" and valid and state.key.token ~= "RUNES" then
            if not readableUnit or (issecretvalue and issecretvalue(powerToken))
                or type(unit) ~= "string" or type(powerToken) ~= "string" then
                InvalidateSource(currentOwner)
                ResetHighlights(holder)
            elseif unit == "player" and powerToken == state.key.token then
                state.eventObserved = true
            end
        elseif not isUnitEvent or event == "UNIT_MAXPOWER" or event == "UNIT_DISPLAYPOWER" then
            InvalidateSource(currentOwner)
            ResetHighlights(holder)
        end

        if State.QueueRefresh then
            State.QueueRefresh(currentOwner, event, { "bars", "texts", "layout" })
        else
            if owner.RefreshUnitBarValues then
                owner:RefreshUnitBarValues(currentOwner)
            end
            if owner.ApplyConfig then
                owner:ApplyConfig(currentOwner, currentOwner.LiveValues and currentOwner.LiveValues.classPowerSnapshot)
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
