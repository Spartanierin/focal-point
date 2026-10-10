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

-- Presentation-only baseline and event evidence; never a second rune provider.
local StopSegmentHighlight = Renderer.StopHighlight
local PlaySegmentHighlight = Renderer.PlayHighlight

local function ResetHighlights(holder)
    if not holder then return end
    holder._readyTransitions = nil
    for _, bar in ipairs(holder.Bars or {}) do StopSegmentHighlight(bar) end
end

local function ResolveSegmentGrowth(value)
    return value == "RIGHT_TO_LEFT" and "RIGHT_TO_LEFT" or "LEFT_TO_RIGHT"
end

local function GetHighlightContext(frame, holder)
    local class, spec = GetPlayerClassToken(), GetSpecializationIndex()
    local token, typeId = GetAggregateHighlightResource(class, spec)
    if class == "DEATHKNIGHT" and CanReadRunes() then token, typeId = "RUNES", POWER_ID_RUNES end
    if frame._fpUnit ~= "player" or not holder:IsVisible()
        or not token or not typeId
        or frame._classPowerPreviewInfo
        or (Demo.IsFrameInDemoMode and Demo.IsFrameInDemoMode(frame))
        or FocalPoint.guiTestModeEnabled
    then return nil end
    local config = frame.config
    if not config or config.classPowerBarPresent ~= true or config.showClassPowerBar ~= true then return nil end
    local resolver = FocalPoint.ActiveLayoutResolver
    local root = resolver and resolver.GetActiveRuntimeRoot and resolver.GetActiveRuntimeRoot()
    if not root then return nil end
    return root, config, spec, FocalPoint.framesUnlocked == true, token, typeId, ResolveSegmentGrowth(config.classPowerBarGrowth)
end

local function MatchHighlightContext(frame, holder)
    local root, config, spec, editor, token, typeId, growth = GetHighlightContext(frame, holder)
    local state = holder._readyTransitions
    if not root or (state and (state.root ~= root or state.config ~= config
        or state.spec ~= spec or state.editor ~= editor or state.unit ~= frame._fpUnit
        or state.class ~= GetPlayerClassToken() or state.token ~= token or state.typeId ~= typeId
        or state.growth ~= growth)) then
        ResetHighlights(holder)
        state = nil
    end
    return state, root, config, spec, editor, token, typeId, growth
end

local function SameRuneSnapshot(previous, current)
    for index = 1, RUNE_COUNT do
        local a, b = previous[index], current[index]
        if a.ready ~= b.ready then return false end
        -- Compare the two existing snapshots, never secret timing or derived Safe values.
        if issecretvalue and (issecretvalue(a.startTime) or issecretvalue(b.startTime)
            or issecretvalue(a.duration) or issecretvalue(b.duration)) then return false end
        if a.startTime ~= b.startTime or a.duration ~= b.duration then return false end
    end
    return true
end

local function ObserveReadySnapshot(frame, segments, max, qualified, current, gainValid, snapshotToken, snapshotType)
    local holder = frame.Elements.ClassPowerBar
    if not holder._highlightLifecycle then
        holder._highlightLifecycle = true
        holder:HookScript("OnHide", function() ResetHighlights(holder) end)
        holder:HookScript("OnShow", function() ResetHighlights(holder) end)
        for _, bar in ipairs(holder.Bars) do
            bar:HookScript("OnHide", function() ResetHighlights(holder) end)
        end
    end
    local state, root, config, spec, editor, token, typeId, growth = MatchHighlightContext(frame, holder)
    if token and token ~= "RUNES" then
        if not root or snapshotToken ~= token or snapshotType ~= typeId or gainValid ~= true or not IsPlainNumber(current) or not IsPlainNumber(max)
            or current < 0 or current > max or max < 1 or max > #holder.Bars or max % 1 ~= 0 then
            ResetHighlights(holder)
            return
        end
        if state and state.max ~= max then ResetHighlights(holder); state = nil end
        if not state then
            state = { root = root, config = config, spec = spec, editor = editor,
                unit = frame._fpUnit, class = GetPlayerClassToken(), token = token, typeId = typeId, growth = growth, max = max }
            holder._readyTransitions = state
        elseif qualified and state.powerEventObserved and current > state.current then
            for index = math.floor(state.current) + 1, math.floor(current) do
                PlaySegmentHighlight(holder.Bars[index])
            end
        end
        state.powerEventObserved = false
        state.current = current
        for index = math.floor(current) + 1, #holder.Bars do StopSegmentHighlight(holder.Bars[index]) end
        return
    end
    if not root or max ~= RUNE_COUNT or type(segments) ~= "table" or #segments ~= RUNE_COUNT then
        ResetHighlights(holder)
        return
    end
    for index = 1, RUNE_COUNT do
        local segment = segments[index]
        if type(segment) ~= "table" or segment.index ~= index
            or (issecretvalue and issecretvalue(segment.ready)) or type(segment.ready) ~= "boolean" then
            ResetHighlights(holder)
            return
        end
    end
    if not state then
        state = { root = root, config = config, spec = spec, editor = editor,
            unit = frame._fpUnit, class = "DEATHKNIGHT", token = token, typeId = typeId, growth = growth, runeEventObserved = false }
        holder._readyTransitions = state
    elseif qualified then
        -- A new value refresh supersedes any unconsumed presentation intent.
        state.pendingReady = nil
        for index = 1, RUNE_COUNT do
            if state.runeEventObserved and state.segments[index].ready == false and segments[index].ready then
                state.pendingReady = state.pendingReady or {}
                state.pendingReady[index] = true
            end
        end
    else
        -- ApplyLayout calls this only after every final anchor and timer update.
        -- Consume once, and only against the matching snapshot/context. No new event.
        local pending = state.pendingReady
        state.pendingReady = nil
        if pending and SameRuneSnapshot(state.segments, segments) then
            -- The canonical snapshot is shared with rendering, so comparing it
            -- with itself cannot detect a rune changing since qualification.
            -- Only a pending DK flash needs this independent, post-anchor check.
            -- It validates S1; it never publishes another source or transition.
            local confirmation = GetRuneInfo()
            if not confirmation or not SameRuneSnapshot(segments, confirmation.segments) then
                ResetHighlights(holder)
                return
            end
            for index = 1, RUNE_COUNT do
                if pending[index] then PlaySegmentHighlight(holder.Bars[index]) end
            end
        end
    end
    -- Consume even an unchanged snapshot: never carry stale evidence forward.
    state.runeEventObserved = false
    for index = 1, RUNE_COUNT do
        if not segments[index].ready then StopSegmentHighlight(holder.Bars[index]) end
    end
    state.segments = segments
end

local function ClearRuneTiming(frame)
    if not frame then return end
    frame._classPowerPreviewInfo = nil
    if frame.LiveValues then frame.LiveValues.classPowerSegments = nil end
    local holder = frame.Elements and frame.Elements.ClassPowerBar
    Renderer.ClearTiming(holder)
end

-- Context, not elapsed time or a queue token, validates render-only consumers.
-- Every RefreshValues call publishes a fresh observation, including direct refreshes.
local function SnapshotContext(frame)
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
    ObserveReadySnapshot(frame, info and info.segments, info and info.max, true,
        info and info.current, info and info.aggregateGainValid, info and info.token, info and info.typeId)

    if not info or not info.segments then ClearRuneTiming(frame) end
    frame.LiveValues.classPowerSnapshot = {
        context = SnapshotContext(frame), info = info, source = source or "unavailable",
        -- Synthetic values never become authoritative gameplay data.
        sourceInfo = source == "live" and info or nil,
        available = info ~= nil,
        currentKnown = info ~= nil and info.currentKnown == true,
        maxKnown = info ~= nil and info.maxKnown == true,
    }
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
    return info
end

function ClassPower.Clear(frame, preserveSnapshot)
    if not frame then return end
    ResetHighlights(frame.Elements and frame.Elements.ClassPowerBar)
    if frame.LiveValues and not preserveSnapshot then frame.LiveValues.classPowerSnapshot = nil end
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

function ClassPower.ApplyLayout(frame, options)
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

    Renderer.Apply(holder, {
        width = width, height = height, spacing = spacing,
        rightToLeft = rightToLeft,
        anchorParent = anchorParent or frame,
        point = options.classPowerBarPoint or "BOTTOMRIGHT",
        relativePoint = options.classPowerBarRelativePoint or "BOTTOMRIGHT",
        x = tonumber(options.classPowerBarOffsetX) or -5,
        y = tonumber(options.classPowerBarOffsetY) or 5,
        max = maxValue, current = currentValue,
        visualSlots = GetRuneVisualSlots(options.liveClassPowerSegments),
        segments = options.liveClassPowerSegments,
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
    -- Render-only snapshots may consume a matching qualified intent after reanchor;
    -- they never independently qualify a transition.
    ObserveReadySnapshot(frame, options.liveClassPowerSegments, options.liveClassPowerMax, false,
        options.liveClassPowerCurrent, options.liveClassPowerGainValid, options.liveClassPowerToken, options.liveClassPowerType)
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
        if holder then
            local transition, _, _, _, _, token = MatchHighlightContext(currentOwner, holder)
            if event == "RUNE_POWER_UPDATE" then
                -- Payload may be secret. The event invalidates the six-rune snapshot;
                -- only its subsequent canonical false -> true comparison can flash.
                if transition then
                    transition.runeEventObserved = true
                end
            elseif event == "UNIT_POWER_UPDATE" and token and token ~= "RUNES" then
                if not readableUnit or (issecretvalue and issecretvalue(powerToken))
                    or type(unit) ~= "string" or type(powerToken) ~= "string" then
                    ResetHighlights(holder)
                elseif unit == "player" and powerToken == token and transition then
                    transition.powerEventObserved = true
                end
            elseif not isUnitEvent or event == "UNIT_MAXPOWER" or event == "UNIT_DISPLAYPOWER" then
                ResetHighlights(holder)
            end
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
