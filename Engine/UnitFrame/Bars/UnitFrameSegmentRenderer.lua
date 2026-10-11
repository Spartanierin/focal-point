local _, FocalPoint = ...

local Renderer = {}
FocalPoint.UnitFrameSegmentRenderer = Renderer

-- Holder-local presentation for the existing Class Power consumer.
-- Apply receives resolved geometry/colors, validated timing and optional visual
-- slots keyed by segment identity. No gameplay, layout, event or LiveValues access.
-- The consumer owns availability, sorting policy and highlight qualification.

local function StopSegmentHighlight(bar)
    if not bar.ReadyHighlight then return end
    bar.ReadyHighlight.animation:Stop()
    bar.ReadyHighlight:SetAlpha(0)
    bar.ReadyHighlight:Hide()
    bar._visualRechargeFlashActive = nil
end

local function PlaySegmentHighlight(bar)
    if not bar or not bar:IsVisible() then
        return
    end
    local r, g, b, a = bar:GetStatusBarColor()
    if not a or a <= 0 then return end
    local texture = bar.ReadyHighlight
    if not texture then
        texture = bar:CreateTexture(nil, "OVERLAY")
        texture:SetTexture("Interface\\Buttons\\WHITE8X8")
        texture:SetAllPoints(bar)
        local animation = texture:CreateAnimationGroup()
        animation:SetLooping("NONE")
        local fadeIn = animation:CreateAnimation("Alpha")
        fadeIn:SetOrder(1)
        fadeIn:SetDuration(0.025)
        fadeIn:SetFromAlpha(0)
        fadeIn:SetToAlpha(0.65)
        local fadeOut = animation:CreateAnimation("Alpha")
        fadeOut:SetOrder(2)
        fadeOut:SetDuration(0.100)
        fadeOut:SetFromAlpha(0.65)
        fadeOut:SetToAlpha(0)
        animation:SetScript("OnFinished", function()
            texture:SetAlpha(0); texture:Hide()
            bar._visualRechargeFlashActive = nil
        end)
        texture.animation = animation
        bar.ReadyHighlight = texture
    end
    StopSegmentHighlight(bar)
    -- Tint comes from the already painted segment; vertex alpha preserves config alpha.
    texture:SetVertexColor(r + (1 - r) * 0.6, g + (1 - g) * 0.6, b + (1 - b) * 0.6, a)
    texture:SetAlpha(0)
    texture:Show()
    texture.animation:Play()
    return true
end

Renderer.StopHighlight = StopSegmentHighlight
Renderer.PlayHighlight = PlaySegmentHighlight

function Renderer.ClearTiming(holder)
    if not holder or not holder._segmentTimingInitialized then return end
    local hadSegments = holder.segments ~= nil
    holder.segments = nil
    holder._legacyRuneVisualFlash = nil
    holder._legacyRuneFlashEpoch = nil
    holder:SetScript("OnUpdate", nil)
    for _, bar in ipairs(holder.Bars or {}) do
        bar._visualRechargeStart, bar._visualRechargeDuration = nil, nil
        bar._visualRechargePositive, bar._visualRechargeFired = nil, nil
        if hadSegments then bar:SetValue(0) end
        bar._countdownSeconds = nil
        if bar.Countdown then
            bar.Countdown:SetText("")
            bar.Countdown:Hide()
        end
    end
end

-- Same local visual-driver pattern as CastRuntime: cached timing only, no API,
-- DB, templates, allocations of state tables, or global refresh in OnUpdate.
local VisualTick
local function UpdateSegments(holder, fromTick)
    local segments = holder.segments
    if not segments or not holder:IsVisible() then
        holder:SetScript("OnUpdate", nil)
        return
    end
    local now, active = GetTime(), false
    for index = 1, #segments do
        local segment, bar = segments[index], holder.Bars[index]
        local start, duration = segment.startTime, segment.duration
        local validTime = not (issecretvalue and (issecretvalue(start) or issecretvalue(duration)))
            and type(start) == "number" and type(duration) == "number"
            and start == start and duration == duration and start < math.huge
            and duration < math.huge and start >= 0 and duration > 0
        local remaining = validTime and math.max(0, start + duration - now) or nil
        if holder._legacyRuneVisualFlash and validTime and not segment.ready then
            if bar._visualRechargeStart ~= start or bar._visualRechargeDuration ~= duration then
                if bar._visualRechargeFlashActive then StopSegmentHighlight(bar) end
                bar._visualRechargeStart, bar._visualRechargeDuration = start, duration
                bar._visualRechargePositive, bar._visualRechargeFired = nil, nil
            end
        else
            bar._visualRechargeStart, bar._visualRechargeDuration = nil, nil
            bar._visualRechargePositive, bar._visualRechargeFired = nil, nil
        end
        local charging = not segment.ready and remaining and remaining > 0
        if charging then
            bar:SetValue(math.max(0, math.min(1, (now - segment.startTime) / segment.duration)))
            -- Cache the displayed tenth; positive recharge never displays 0.0.
            local seconds = math.max(0.1, math.floor(remaining * 10 + 0.5) / 10)
            if bar._countdownSeconds ~= seconds then
                bar.Countdown:SetText(string.format("%.1f", seconds))
                bar._countdownSeconds = seconds
            end
            bar.Countdown:Show()
            if holder._legacyRuneVisualFlash then bar._visualRechargePositive = true end
            active = true
        else
            bar:SetValue((segment.ready or remaining == 0) and 1 or 0)
            bar.Countdown:SetText("")
            bar.Countdown:Hide()
            bar._countdownSeconds = nil
            if holder._legacyRuneVisualFlash and remaining == 0
                and not segment.ready and bar._visualRechargePositive
                and not bar._visualRechargeFired then
                bar._visualRechargeFired = true
                if fromTick and PlaySegmentHighlight(bar) then
                    bar._visualRechargeFlashActive = true
                end
            end
        end
    end
    holder:SetScript("OnUpdate", active and VisualTick or nil)
end
VisualTick = function(holder) UpdateSegments(holder, true) end

-- Layout-only styling: countdown ticks continue to consume only rune timing.
local function ApplyTimerStyle(holder, options)
    local fallbackFont = STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF"
    local font = fallbackFont
    local reference = options.timerFont
    local media = FocalPoint.MediaRegistry
    if type(reference) == "string" and reference ~= "" and media and media.ResolveReference then
        local resolved = media.ResolveReference(reference, "font", "fp:font:standard")
        if resolved and resolved.available and type(resolved.resolvedAsset) == "string" and resolved.resolvedAsset ~= "" then
            font = resolved.resolvedAsset
        end
    end
    local size = options.timerFontSize
    if type(size) ~= "number" or not (size >= 6 and size <= 32) then size = 10 end
    local style = options.timerFontStyle
    if style ~= "NONE" and style ~= "OUTLINE" and style ~= "THICKOUTLINE"
        and style ~= "MONOCHROME" and style ~= "OUTLINE_MONOCHROME" and style ~= "THICKOUTLINE_MONOCHROME" then
        style = "OUTLINE"
    end
    -- Loaded after this module in Init.xml; resolve the pure helper at apply time.
    local utils = FocalPoint.TextElementUtils
    local flags = utils and utils.BuildFontFlags and utils.BuildFontFlags({fontStyle = style}) or "OUTLINE"
    for _, bar in ipairs(holder.Bars) do
        local text = bar.Countdown
        local currentFont, currentSize, currentFlags = text:GetFont()
        if currentFont ~= font or currentSize ~= size or (currentFlags or "") ~= flags then
            local ok, applied = pcall(text.SetFont, text, font, size, flags ~= "" and flags or nil)
            if not ok or applied == false then
                ok, applied = pcall(text.SetFont, text, fallbackFont, size, flags ~= "" and flags or nil)
                if not ok or applied == false then
                    text:SetFont("Fonts\\FRIZQT__.TTF", 10, "OUTLINE")
                end
            end
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
    holder:HookScript("OnHide", function(self)
        self:SetScript("OnUpdate", nil)
        for _, bar in ipairs(self.Bars) do
            bar._visualRechargePositive, bar._visualRechargeFired = nil, nil
        end
    end)
    holder:HookScript("OnShow", UpdateSegments)
end

function Renderer.Apply(holder, options)
    local bars = holder.Bars or {}
    local width, height, spacing = options.width, options.height, options.spacing
    local rightToLeft = options.rightToLeft
    local maxValue, currentValue = options.max, options.current
    local r, g, b = options.r, options.g, options.b
    holder:SetSize(width, height)
    holder:SetPoint(options.point, options.anchorParent, options.relativePoint, options.x, options.y)
    holder:Show()

    local usableWidth = width - ((maxValue - 1) * spacing)
    local segmentWidth = maxValue > 0 and (usableWidth / maxValue) or usableWidth
    local visualSlots = options.visualSlots
    local visualFlash = options.legacyRuneVisualFlash == true
    if (holder._legacyRuneVisualFlash or visualFlash)
        and (not visualFlash or holder._legacyRuneFlashEpoch ~= options.legacyRuneFlashEpoch) then
        for _, bar in ipairs(bars) do
            if bar._visualRechargeFlashActive then StopSegmentHighlight(bar) end
            bar._visualRechargeStart, bar._visualRechargeDuration = nil, nil
            bar._visualRechargePositive, bar._visualRechargeFired = nil, nil
        end
    end
    holder._legacyRuneVisualFlash = visualFlash
    holder._legacyRuneFlashEpoch = visualFlash and options.legacyRuneFlashEpoch or nil
    local numActive = currentValue + 0.9
    local borderR = options.borderR
    local borderG = options.borderG
    local borderB = options.borderB
    local borderA = options.borderA

    for index = 1, #bars do
        local bar = bars[index]
        bar:ClearAllPoints()

        if index <= maxValue then
            -- Bars[index] keeps its resource/rune identity; only its position moves.
            if visualSlots then
                -- The consumer supplies slot order; segment/widget identity stays fixed.
                -- Direct holder anchors avoid transient cycles when slots exchange.
                local offset = (visualSlots[index] - 1) * (segmentWidth + spacing)
                local point = rightToLeft and "TOPRIGHT" or "TOPLEFT"
                bar:SetPoint(point, holder, point, rightToLeft and -offset or offset, 0)
            elseif rightToLeft then
                if index == 1 then
                    bar:SetPoint("TOPRIGHT", holder, "TOPRIGHT", 0, 0)
                else
                    bar:SetPoint("TOPRIGHT", bars[index - 1], "TOPLEFT", -spacing, 0)
                end
            elseif index == 1 then
                bar:SetPoint("TOPLEFT", holder, "TOPLEFT", 0, 0)
            else
                bar:SetPoint("TOPLEFT", bars[index - 1], "TOPRIGHT", spacing, 0)
            end

            bar:SetWidth(segmentWidth)
            bar:SetHeight(height)
            bar:SetStatusBarTexture(options.texture)
            bar:SetStatusBarColor(r or 1, g or 1, b or 1, options.a)
            if bar.ReadyHighlight then
                local cr, cg, cb, ca = bar:GetStatusBarColor()
                bar.ReadyHighlight:SetVertexColor(cr + (1 - cr) * 0.6, cg + (1 - cg) * 0.6, cb + (1 - cb) * 0.6, ca)
                if ca <= 0 then StopSegmentHighlight(bar) end
            end
            if bar.bg then
                bar.bg:SetTexture(options.texture)
                bar.bg:SetVertexColor(options.bgR, options.bgG, options.bgB, options.bgA)
                bar.bg:SetShown(options.backgroundShown ~= false)
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
    if options.segments then
        PrepareSegmentWidgets(holder)
        ApplyTimerStyle(holder, options)
        holder.segments = options.segments
        UpdateSegments(holder)
    end
end
