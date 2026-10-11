local _, ns = ...

local Bars = {}
ns.UnitFrameSegmentedBars = Bars
local Renderer = ns.UnitFrameSegmentRenderer
local Factory = ns.UnitFrameFactory
local ClassPower = ns.UnitFrameClassPower
local TEXTURE = "Interface\\Buttons\\WHITE8X8"

local function PlainNumber(value)
    return not (issecretvalue and issecretvalue(value)) and type(value) == "number"
        and value == value and math.abs(value) < math.huge
end

local function SnapshotClass(snapshot, frame)
    local context = snapshot and snapshot.context
    if not context or context.config ~= frame.config or context.unit ~= "player" then return nil end
    local class = context.class
    if (issecretvalue and issecretvalue(class)) or type(class) ~= "string" then return nil end
    return class
end

local ResolveAutoSource

-- Fixed bindings keep their identity; Automatic consumes only the published observation.
-- Inspector and runtime share this mapping without fetching gameplay state.
function Bars.ResolveDataSource(record, frame)
    local source = record and record.dataSource
    if not source or source.scope ~= "player" then return nil end
    if source.id == "runes" or source.id == "holyPower" or source.id == "arcaneCharges"
        or source.id == "chi" or source.id == "comboPoints" then return source.id end
    if source.id ~= "auto" then return nil end
    local snapshot = frame and frame.LiveValues and frame.LiveValues.classPowerSnapshot
    return ResolveAutoSource(snapshot, frame)
end

-- Holy Power consumes only the published live observation, never a synthetic
-- selection/demo fallback or the legacy Safe=0 compatibility projection.
local function HasHolyPower(snapshot, info, frame)
    local context = snapshot and snapshot.context
    return info and snapshot.source == "live" and snapshot.sourceInfo == info
        and context and context.unit == "player" and SnapshotClass(snapshot, frame) == "PALADIN" and context.config == frame.config
        and info.token == "HOLY_POWER" and info.typeId == (Enum and Enum.PowerType and Enum.PowerType.HolyPower or 9)
        and snapshot.currentKnown == true and snapshot.maxKnown == true
        and info.currentKnown == true and info.maxKnown == true
        and PlainNumber(info.current) and PlainNumber(info.max)
        and info.max >= 1 and info.max % 1 == 0 and info.current >= 0 and info.current <= info.max
end

local function HasArcaneCharges(snapshot, info, frame)
    local context = snapshot and snapshot.context
    if not info or not context or snapshot.source ~= "live" or snapshot.sourceInfo ~= info
        or context.unit ~= "player" or context.config ~= frame.config
        or SnapshotClass(snapshot, frame) ~= "MAGE" or not PlainNumber(context.spec)
        or context.spec ~= (_G.SPEC_MAGE_ARCANE or 1)
        or (issecretvalue and (issecretvalue(info.token) or issecretvalue(info.typeId)))
        or info.token ~= "ARCANE_CHARGES"
        or info.typeId ~= (Enum and Enum.PowerType and Enum.PowerType.ArcaneCharges or 16)
        or snapshot.currentKnown ~= true or snapshot.maxKnown ~= true
        or info.currentKnown ~= true or info.maxKnown ~= true
        or not PlainNumber(info.rawCurrent) or not PlainNumber(info.rawMax)
        or not PlainNumber(info.current) or not PlainNumber(info.max) then return false end
    return info.current == info.rawCurrent and info.max == info.rawMax
        and info.max >= 1 and info.max <= 6 and info.max % 1 == 0
        and info.current >= 0 and info.current <= info.max and info.current % 1 == 0
end

local function HasChi(snapshot, info, frame)
    local context = snapshot and snapshot.context
    if not info or not context or snapshot.source ~= "live" or snapshot.sourceInfo ~= info
        or context.unit ~= "player" or context.config ~= frame.config
        or SnapshotClass(snapshot, frame) ~= "MONK" or not PlainNumber(context.spec)
        or context.spec ~= (_G.SPEC_MONK_WINDWALKER or 3)
        or (issecretvalue and (issecretvalue(info.token) or issecretvalue(info.typeId)))
        or info.token ~= "CHI"
        or info.typeId ~= (Enum and Enum.PowerType and Enum.PowerType.Chi or 12)
        or snapshot.currentKnown ~= true or snapshot.maxKnown ~= true
        or info.currentKnown ~= true or info.maxKnown ~= true
        or not PlainNumber(info.rawCurrent) or not PlainNumber(info.rawMax)
        or not PlainNumber(info.current) or not PlainNumber(info.max) then return false end
    return info.current == info.rawCurrent and info.max == info.rawMax
        and info.max >= 1 and info.max <= 6 and info.max % 1 == 0
        and info.current >= 0 and info.current <= info.max and info.current % 1 == 0
end

local function HasComboPoints(snapshot, info, frame)
    local context = snapshot and snapshot.context
    local class = SnapshotClass(snapshot, frame)
    -- The Druid Energy/Shred gate runs in the sole live provider before this
    -- snapshot is published; it is not re-read by this visual consumer.
    if not info or not context or snapshot.source ~= "live" or snapshot.sourceInfo ~= info
        or context.unit ~= "player" or context.config ~= frame.config
        or (class ~= "ROGUE" and class ~= "DRUID")
        or (issecretvalue and (issecretvalue(info.token) or issecretvalue(info.typeId)))
        or info.token ~= "COMBO_POINTS"
        or info.typeId ~= (Enum and Enum.PowerType and Enum.PowerType.ComboPoints or 4)
        or snapshot.currentKnown ~= true or snapshot.maxKnown ~= true
        or info.currentKnown ~= true or info.maxKnown ~= true
        or not PlainNumber(info.rawCurrent) or not PlainNumber(info.rawMax)
        or not PlainNumber(info.current) or not PlainNumber(info.max) then return false end
    return info.current == info.rawCurrent and info.max == info.rawMax
        and info.max >= 1 and info.max <= 6 and info.max % 1 == 0
        and info.current >= 0 and info.current <= info.max and info.current % 1 == 0
end

ResolveAutoSource = function(snapshot, frame)
    local info = snapshot and snapshot.info
    local class = frame and SnapshotClass(snapshot, frame)
    if not info or snapshot.available ~= true or snapshot.currentKnown ~= true
        or snapshot.maxKnown ~= true or not class then return nil end
    if issecretvalue and (issecretvalue(info.token) or issecretvalue(info.typeId)) then return nil end
    if class == "DEATHKNIGHT" then
        if (snapshot.source == "live" and snapshot.sourceInfo == info or snapshot.source == "preview")
            and not (issecretvalue and issecretvalue(info.segments))
            and info.token == "RUNES" and type(info.segments) == "table" and #info.segments == 6
            and PlainNumber(info.current) and PlainNumber(info.max) and info.max == 6
            and info.current >= 0 and info.current <= 6 and info.current % 1 == 0 then
            return "runes"
        end
    elseif class == "PALADIN" then
        if HasHolyPower(snapshot, info, frame) and PlainNumber(info.rawCurrent) and PlainNumber(info.rawMax)
            and info.current == info.rawCurrent and info.max == info.rawMax
            and info.max <= 6 and info.current % 1 == 0 then
            return "holyPower"
        end
    elseif class == "MAGE" then
        if HasArcaneCharges(snapshot, info, frame) then return "arcaneCharges" end
    elseif class == "MONK" then
        if HasChi(snapshot, info, frame) then return "chi" end
    elseif class == "ROGUE" or class == "DRUID" then
        if HasComboPoints(snapshot, info, frame) then return "comboPoints" end
    end
    return nil
end

local function ClearHolder(holder)
    Renderer.ClearTiming(holder)
    holder._segmentedBarRendered = false
    holder:Hide()
end

-- Local visual state only. Never clear the shared snapshot or Legacy consumer.
function Bars.Clear(frame)
    local state = frame and frame._segmentedBars
    if not state then return end
    for _, holder in pairs(state.byId) do ClearHolder(holder) end
end

-- Canvas consumes the very same anchored holder, never a second geometry model.
function Bars.GetVisibleHolder(frame, id)
    local state = frame and frame._segmentedBars
    local holder = state and id and state.byId[id]
    if not holder or state.config ~= frame.config or not holder._segmentedBarRendered then return nil end
    local record = ns.CompositionOwnership.FindSegmentedBar(frame.config, id)
    if record ~= holder._segmentedBarRecord or not record.enabled or not holder:IsVisible() then return nil end
    return holder
end

function Bars.Apply(frame)
    local config = frame and frame.config
    local records = config and config.segmentedBars
    if not frame then return end
    if frame._fpUnit ~= "player" or not records then
        Bars.Clear(frame)
        return
    end
    -- Reuse the canonical contract, including missing-target/cycle rejection.
    if not ns.LayoutService.ValidateSegmentedBars(records, frame._fpUnit) then
        Bars.Clear(frame)
        return
    end
    local state = frame._segmentedBars
    if not state then
        state = {byId = {}, pool = {}}
        frame._segmentedBars = state
    end
    state.config = config
    local present = {}
    for _, record in ipairs(records) do present[record.id] = true end
    -- Detach first: a valid new anchor graph must not cross an old graph mid-apply.
    for id, holder in pairs(state.byId) do
        holder:ClearAllPoints()
        if not present[id] then
            ClearHolder(holder)
            holder._segmentedBarRecord = nil
            state.byId[id] = nil
            state.pool[#state.pool + 1] = holder
        end
    end
    for _, record in ipairs(records) do
        local holder = state.byId[record.id]
        if not holder then
            holder = table.remove(state.pool) or Factory.CreateSegmentedBar(frame)
            state.byId[record.id] = holder
        end
        holder._segmentedBarRecord = record
        holder:SetFrameStrata(frame:GetFrameStrata())
        holder:SetFrameLevel(frame:GetFrameLevel() + 4)
        holder:SetSize(record.width or 100, record.height or 12)
    end
    -- Consume the existing observation only. Rune preview remains unchanged;
    -- the second source is live-only and must carry readable current/max values.
    local snapshot = frame.LiveValues and frame.LiveValues.classPowerSnapshot
    local info = snapshot and snapshot.available and snapshot.info
    local hasRunes = info and info.token == "RUNES" and info.segments and #info.segments == 6
    local slots = hasRunes and ClassPower.GetRuneVisualSlots(info.segments) or nil
    local hasHolyPower = HasHolyPower(snapshot, info, frame)
    local hasArcaneCharges = HasArcaneCharges(snapshot, info, frame)
    local hasChi = HasChi(snapshot, info, frame)
    local hasComboPoints = HasComboPoints(snapshot, info, frame)
    for _, record in ipairs(records) do
        local holder = state.byId[record.id]
        local anchor = record.anchorTo
        local target = (not anchor or anchor == "Frame") and frame
            or state.byId[anchor:match("^SegmentedBar:(.+)$")]
        -- No fallback to Frame for an unresolved instance target.
        if target then
            local point, relativePoint = record.point or "TOPLEFT", record.relativePoint or "TOPLEFT"
            local x, y = record.offsetX or 0, record.offsetY or 0
            holder:SetPoint(point, target, relativePoint, x, y)
            local width, height, spacing = record.width or 100, record.height or 12, record.spacing or 2
            local source = record.dataSource
            local resolvedSource = Bars.ResolveDataSource(record, frame)
            if source.id == "auto" and (not snapshot or snapshot.currentKnown ~= true or snapshot.maxKnown ~= true
                or (snapshot.source ~= "preview" and (snapshot.source ~= "live" or snapshot.sourceInfo ~= info))) then
                resolvedSource = nil
            end
            local runes = resolvedSource == "runes" and hasRunes
            local holyPower = resolvedSource == "holyPower" and hasHolyPower
            local arcaneCharges = resolvedSource == "arcaneCharges" and hasArcaneCharges
            local chi = resolvedSource == "chi" and hasChi
            local comboPoints = resolvedSource == "comboPoints" and hasComboPoints
            local max = runes and 6 or ((holyPower or arcaneCharges or chi or comboPoints) and info.max)
            -- The storage contract permits oversized spacing; do not pass negative
            -- segment widths into native widgets or silently change saved geometry.
            if record.enabled and config.enabled ~= false and source.scope == "player"
                and max and max <= #holder.Bars and width > (max - 1) * spacing then
                -- Clear before painting aggregate fills, including a recycled rune holder.
                if not runes then Renderer.ClearTiming(holder) end
                local color, background = record.color, record.backgroundColor
                local r, g, b, a = color and color[1] or 1, color and color[2] or 1,
                    color and color[3] or 1, color and color[4] or 1
                if record.useBlizzardColor == true then
                    r, g, b = ClassPower.ResolveResourceColor(info, snapshot.context and snapshot.context.spec, r, g, b)
                end
                local texture = TEXTURE
                if record.texture and ns.UnitFrameAssets then
                    texture = ns.UnitFrameAssets.GetStatusBarTexture(record.texture)
                end
                Renderer.Apply(holder, {
                    width = width, height = height, spacing = spacing,
                    point = point, anchorParent = target, relativePoint = relativePoint, x = x, y = y,
                    rightToLeft = record.growth == "RIGHT_TO_LEFT",
                    max = max, current = info.current, segments = runes and info.segments or nil, visualSlots = runes and slots or nil,
                    r = r, g = g, b = b, a = a,
                    texture = texture, backgroundShown = record.background ~= false,
                    bgR = background and background[1] or 0, bgG = background and background[2] or 0,
                    bgB = background and background[3] or 0, bgA = background and background[4] or .35,
                    borderR = 0, borderG = 0, borderB = 0, borderA = .85,
                    timerFont = record.runeTimerFont, timerFontSize = record.runeTimerFontSize,
                    timerFontStyle = record.runeTimerFontStyle,
                })
                holder._segmentedBarRendered = true
            else
                ClearHolder(holder)
            end
        else
            ClearHolder(holder)
        end
    end
end
