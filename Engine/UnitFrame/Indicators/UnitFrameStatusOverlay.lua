local _, FocalPoint = ...

FocalPoint.UnitFrameStatusOverlay = FocalPoint.UnitFrameStatusOverlay or {}
local StatusOverlay = FocalPoint.UnitFrameStatusOverlay

local function CreateSolidTexture(parent, layer, subLevel)
    local texture = parent:CreateTexture(nil, layer or "OVERLAY", nil, subLevel or 0)
    texture:SetTexture("Interface\\Buttons\\WHITE8X8")
    return texture
end

local function SetTextureColor(texture, r, g, b, a, blendMode)
    if not texture then
        return
    end

    texture:SetTexture("Interface\\Buttons\\WHITE8X8")
    texture:SetVertexColor(r or 1, g or 1, b or 1, a or 1)
    if texture.SetBlendMode and blendMode then
        texture:SetBlendMode(blendMode)
    end
end

local function EnsurePulseAnimation(overlay)
    if not overlay or overlay.PulseGroup then
        return
    end

    local pulseGroup = overlay:CreateAnimationGroup()
    pulseGroup:SetLooping("REPEAT")

    local fadeIn = pulseGroup:CreateAnimation("Alpha")
    fadeIn:SetOrder(1)
    fadeIn:SetDuration(3.3)
    fadeIn:SetSmoothing("IN_OUT")
    fadeIn:SetFromAlpha(0.00)
    fadeIn:SetToAlpha(0.75)

    local fadeOut = pulseGroup:CreateAnimation("Alpha")
    fadeOut:SetOrder(2)
    fadeOut:SetDuration(3.3)
    fadeOut:SetSmoothing("IN_OUT")
    fadeOut:SetFromAlpha(0.75)
    fadeOut:SetToAlpha(0.00)

    overlay.PulseGroup = pulseGroup
end

local function EnsureOverlay(holder)
    if not holder then
        return nil
    end

    local overlay = holder.StatusOverlay
    if overlay then
        return overlay
    end

    overlay = CreateFrame("Frame", nil, holder)
    overlay:SetAllPoints(holder)
    overlay:Hide()

    overlay.PulseLayer = CreateFrame("Frame", nil, overlay)
    overlay.PulseLayer:SetAllPoints(overlay)

    overlay.InnerTint = CreateSolidTexture(overlay.PulseLayer, "BACKGROUND", 0)
    overlay.GlowTop = CreateSolidTexture(overlay.PulseLayer, "OVERLAY", 1)
    overlay.GlowBottom = CreateSolidTexture(overlay.PulseLayer, "OVERLAY", 1)
    overlay.GlowLeft = CreateSolidTexture(overlay.PulseLayer, "OVERLAY", 1)
    overlay.GlowRight = CreateSolidTexture(overlay.PulseLayer, "OVERLAY", 1)

    overlay.BorderTop = CreateSolidTexture(overlay, "OVERLAY", 2)
    overlay.BorderBottom = CreateSolidTexture(overlay, "OVERLAY", 2)
    overlay.BorderLeft = CreateSolidTexture(overlay, "OVERLAY", 2)
    overlay.BorderRight = CreateSolidTexture(overlay, "OVERLAY", 2)
    overlay.CornerTL = CreateSolidTexture(overlay, "OVERLAY", 3)
    overlay.CornerTR = CreateSolidTexture(overlay, "OVERLAY", 3)
    overlay.CornerBL = CreateSolidTexture(overlay, "OVERLAY", 3)
    overlay.CornerBR = CreateSolidTexture(overlay, "OVERLAY", 3)
    overlay.GemShadow = CreateSolidTexture(overlay, "OVERLAY", 4)
    overlay.Gem = CreateSolidTexture(overlay, "OVERLAY", 5)
    overlay.WingLeft = CreateSolidTexture(overlay, "OVERLAY", 4)
    overlay.WingRight = CreateSolidTexture(overlay, "OVERLAY", 4)

    EnsurePulseAnimation(overlay)

    holder.StatusOverlay = overlay
    return overlay
end

local function ApplyAccentLayout(overlay, style)
    local thickness = style.thickness or 2
    local gemSize = style.gemSize or 0

    if gemSize <= 0 then
        overlay.GemShadow:Hide()
        overlay.Gem:Hide()
        overlay.WingLeft:Hide()
        overlay.WingRight:Hide()
        return
    end

    overlay.GemShadow:ClearAllPoints()
    overlay.GemShadow:SetPoint("TOP", overlay, "TOP", 0, 1)
    overlay.GemShadow:SetSize(gemSize + 4, gemSize + 4)
    overlay.GemShadow:SetRotation(0.78539816339)

    overlay.Gem:ClearAllPoints()
    overlay.Gem:SetPoint("TOP", overlay, "TOP", 0, 0)
    overlay.Gem:SetSize(gemSize, gemSize)
    overlay.Gem:SetRotation(0.78539816339)

    local wingWidth = math.max(10, gemSize + 6)
    overlay.WingLeft:ClearAllPoints()
    overlay.WingLeft:SetPoint("TOP", overlay, "TOP", -gemSize + 1, -(thickness + 2))
    overlay.WingLeft:SetSize(wingWidth, 2)
    overlay.WingLeft:SetRotation(-0.45)

    overlay.WingRight:ClearAllPoints()
    overlay.WingRight:SetPoint("TOP", overlay, "TOP", gemSize - 1, -(thickness + 2))
    overlay.WingRight:SetSize(wingWidth, 2)
    overlay.WingRight:SetRotation(0.45)

    overlay.GemShadow:Show()
    overlay.Gem:Show()
    overlay.WingLeft:Show()
    overlay.WingRight:Show()
end

local function ApplyOverlayStyle(overlay, style)
    if not overlay or not style then
        return
    end

    local primary = style.primary or { 1, 1, 1, 1 }
    local secondary = style.secondary or primary
    local tint = style.tint or { primary[1], primary[2], primary[3], 0.08 }
    local glow = style.glow or { primary[1], primary[2], primary[3], 0.16 }
    local thickness = style.thickness or 2
    local cornerSize = style.cornerSize or 6
    local glowThickness = style.glowThickness or (thickness + 5)
    local inset = style.inset or 0

    overlay.BorderTop:ClearAllPoints()
    overlay.BorderTop:SetPoint("TOPLEFT", overlay, "TOPLEFT", inset, -inset)
    overlay.BorderTop:SetPoint("TOPRIGHT", overlay, "TOPRIGHT", -inset, -inset)
    overlay.BorderTop:SetHeight(thickness)

    overlay.BorderBottom:ClearAllPoints()
    overlay.BorderBottom:SetPoint("BOTTOMLEFT", overlay, "BOTTOMLEFT", inset, inset)
    overlay.BorderBottom:SetPoint("BOTTOMRIGHT", overlay, "BOTTOMRIGHT", -inset, inset)
    overlay.BorderBottom:SetHeight(thickness)

    overlay.BorderLeft:ClearAllPoints()
    overlay.BorderLeft:SetPoint("TOPLEFT", overlay, "TOPLEFT", inset, -inset)
    overlay.BorderLeft:SetPoint("BOTTOMLEFT", overlay, "BOTTOMLEFT", inset, inset)
    overlay.BorderLeft:SetWidth(thickness)

    overlay.BorderRight:ClearAllPoints()
    overlay.BorderRight:SetPoint("TOPRIGHT", overlay, "TOPRIGHT", -inset, -inset)
    overlay.BorderRight:SetPoint("BOTTOMRIGHT", overlay, "BOTTOMRIGHT", -inset, inset)
    overlay.BorderRight:SetWidth(thickness)

    overlay.CornerTL:ClearAllPoints()
    overlay.CornerTL:SetPoint("TOPLEFT", overlay, "TOPLEFT", inset - 1, 1 - inset)
    overlay.CornerTL:SetSize(cornerSize, cornerSize)

    overlay.CornerTR:ClearAllPoints()
    overlay.CornerTR:SetPoint("TOPRIGHT", overlay, "TOPRIGHT", 1 - inset, 1 - inset)
    overlay.CornerTR:SetSize(cornerSize, cornerSize)

    overlay.CornerBL:ClearAllPoints()
    overlay.CornerBL:SetPoint("BOTTOMLEFT", overlay, "BOTTOMLEFT", inset - 1, inset - 1)
    overlay.CornerBL:SetSize(cornerSize, cornerSize)

    overlay.CornerBR:ClearAllPoints()
    overlay.CornerBR:SetPoint("BOTTOMRIGHT", overlay, "BOTTOMRIGHT", 1 - inset, inset - 1)
    overlay.CornerBR:SetSize(cornerSize, cornerSize)

    overlay.InnerTint:SetAllPoints(overlay)

    overlay.GlowTop:ClearAllPoints()
    overlay.GlowTop:SetPoint("TOPLEFT", overlay, "TOPLEFT", inset + 3, glowThickness / 2 - inset)
    overlay.GlowTop:SetPoint("TOPRIGHT", overlay, "TOPRIGHT", -(inset + 3), glowThickness / 2 - inset)
    overlay.GlowTop:SetHeight(glowThickness)

    overlay.GlowBottom:ClearAllPoints()
    overlay.GlowBottom:SetPoint("BOTTOMLEFT", overlay, "BOTTOMLEFT", inset + 3, -(glowThickness / 2) + inset)
    overlay.GlowBottom:SetPoint("BOTTOMRIGHT", overlay, "BOTTOMRIGHT", -(inset + 3), -(glowThickness / 2) + inset)
    overlay.GlowBottom:SetHeight(glowThickness)

    overlay.GlowLeft:ClearAllPoints()
    overlay.GlowLeft:SetPoint("TOPLEFT", overlay, "TOPLEFT", -(glowThickness / 2) + inset, -(inset + 3))
    overlay.GlowLeft:SetPoint("BOTTOMLEFT", overlay, "BOTTOMLEFT", -(glowThickness / 2) + inset, inset + 3)
    overlay.GlowLeft:SetWidth(glowThickness)

    overlay.GlowRight:ClearAllPoints()
    overlay.GlowRight:SetPoint("TOPRIGHT", overlay, "TOPRIGHT", glowThickness / 2 - inset, -(inset + 3))
    overlay.GlowRight:SetPoint("BOTTOMRIGHT", overlay, "BOTTOMRIGHT", glowThickness / 2 - inset, inset + 3)
    overlay.GlowRight:SetWidth(glowThickness)

    ApplyAccentLayout(overlay, style)

    SetTextureColor(overlay.InnerTint, tint[1], tint[2], tint[3], tint[4], "ADD")
    SetTextureColor(overlay.GlowTop, glow[1], glow[2], glow[3], glow[4], "ADD")
    SetTextureColor(overlay.GlowBottom, glow[1], glow[2], glow[3], glow[4], "ADD")
    SetTextureColor(overlay.GlowLeft, glow[1], glow[2], glow[3], glow[4], "ADD")
    SetTextureColor(overlay.GlowRight, glow[1], glow[2], glow[3], glow[4], "ADD")
    SetTextureColor(overlay.BorderTop, primary[1], primary[2], primary[3], primary[4], "ADD")
    SetTextureColor(overlay.BorderBottom, primary[1], primary[2], primary[3], primary[4], "ADD")
    SetTextureColor(overlay.BorderLeft, primary[1], primary[2], primary[3], primary[4], "ADD")
    SetTextureColor(overlay.BorderRight, primary[1], primary[2], primary[3], primary[4], "ADD")
    SetTextureColor(overlay.CornerTL, secondary[1], secondary[2], secondary[3], secondary[4], "ADD")
    SetTextureColor(overlay.CornerTR, secondary[1], secondary[2], secondary[3], secondary[4], "ADD")
    SetTextureColor(overlay.CornerBL, secondary[1], secondary[2], secondary[3], secondary[4], "ADD")
    SetTextureColor(overlay.CornerBR, secondary[1], secondary[2], secondary[3], secondary[4], "ADD")

    if (style.gemSize or 0) > 0 then
        SetTextureColor(overlay.GemShadow, 0, 0, 0, 0.28, "BLEND")
        SetTextureColor(overlay.Gem, secondary[1], secondary[2], secondary[3], secondary[4], "ADD")
        SetTextureColor(overlay.WingLeft, primary[1], primary[2], primary[3], 0.72, "ADD")
        SetTextureColor(overlay.WingRight, primary[1], primary[2], primary[3], 0.72, "ADD")
    end

    overlay:Show()
    overlay.PulseLayer:Show()
    overlay.BorderTop:Show()
    overlay.BorderBottom:Show()
    overlay.BorderLeft:Show()
    overlay.BorderRight:Show()
    overlay.CornerTL:Show()
    overlay.CornerTR:Show()
    overlay.CornerBL:Show()
    overlay.CornerBR:Show()
end

local STYLE_BY_KIND = {
    combat = {
        primary = { 0.82, 0.18, 0.22, 0.92 },
        secondary = { 0.98, 0.46, 0.30, 0.88 },
        tint = { 0.24, 0.03, 0.05, 0.08 },
        glow = { 0.82, 0.16, 0.18, 0.14 },
        thickness = 2,
        cornerSize = 6,
        glowThickness = 7,
        gemSize = 0,
        pulse = false,
    },
    resting = {
        primary = { 0.92, 0.76, 0.30, 0.94 },
        secondary = { 1.00, 0.92, 0.62, 0.92 },
        tint = { 0.32, 0.24, 0.07, 0.08 },
        glow = { 0.98, 0.82, 0.28, 0.18 },
        thickness = 2,
        cornerSize = 7,
        glowThickness = 8,
        gemSize = 10,
        pulse = true,
    },
}

function StatusOverlay.Hide(holder)
    if not holder then
        return
    end

    if holder.Texture then
        holder.Texture:SetTexture(nil)
        holder.Texture:Hide()
    end

    local overlay = holder.StatusOverlay
    if not overlay then
        return
    end

    if overlay.PulseGroup and overlay.PulseGroup:IsPlaying() then
        overlay.PulseGroup:Stop()
    end

    overlay:SetAlpha(1)

    overlay:Hide()
end

function StatusOverlay.Apply(holder, frame, kind)
    if not holder or not frame then
        return
    end

    local style = STYLE_BY_KIND[kind]
    if not style then
        StatusOverlay.Hide(holder)
        return
    end

    local overlay = EnsureOverlay(holder)
    if not overlay then
        return
    end

    local portrait = frame.Elements and frame.Elements.Portrait or nil
    local portraitShown = portrait and portrait.IsShown and portrait:IsShown() or false
    local overlayTarget = portraitShown and portrait or frame

    holder:ClearAllPoints()
    holder:SetAllPoints(overlayTarget)
    holder:SetFrameStrata(overlayTarget:GetFrameStrata())
    holder:SetFrameLevel(math.max(overlayTarget:GetFrameLevel() + 6, frame:GetFrameLevel() + 24))
    holder:Show()

    if holder.Texture then
        holder.Texture:SetTexture(nil)
        holder.Texture:Hide()
    end

    overlay:ClearAllPoints()
    overlay:SetAllPoints(holder)
    ApplyOverlayStyle(overlay, style)

    if style.pulse and overlay.PulseGroup then
        overlay:SetAlpha(0)
        if not overlay.PulseGroup:IsPlaying() then
            overlay.PulseGroup:Play()
        end
    else
        if overlay.PulseGroup and overlay.PulseGroup:IsPlaying() then
            overlay.PulseGroup:Stop()
        end
        overlay:SetAlpha(1)
    end
end
