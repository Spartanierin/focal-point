local _, FocalPoint = ...

FocalPoint.UnitFrameClassificationIndicator = FocalPoint.UnitFrameClassificationIndicator or {}
local Classification = FocalPoint.UnitFrameClassificationIndicator

local Presence = FocalPoint.UnitFramePresence or {}
local Preview = FocalPoint.UnitFramePreview or {}
local State = FocalPoint.UnitFrameState or {}

local IsPreviewModeEnabled = Presence.IsPreviewModeEnabled

local PREVIEW_CLASSIFICATION_BY_UNIT = {
    target = "rareelite",
    targettarget = "elite",
    focus = "rare",
    focustarget = "elite",
    boss = "worldboss",
    boss1 = "worldboss",
    boss2 = "worldboss",
    boss3 = "worldboss",
    boss4 = "worldboss",
    boss5 = "worldboss",
}

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

local function NormalizeEffect(effect)
    if effect == "NONE" or effect == "NAME_GLOW" or effect == "NAME_LABEL" or effect == "CORNER_CREST" then
        return effect
    end

    return "PORTRAIT_OVERLAY"
end

local function GetPreviewClassification(frame)
    if not (frame and IsPreviewModeEnabled and IsPreviewModeEnabled()) then
        return nil
    end

    return PREVIEW_CLASSIFICATION_BY_UNIT[frame.unit or ""]
end

local function ResolveSafeClassificationKind(unit)
    local Status = FocalPoint.TextElementStatus
    if Status and Status.GetUnitClassificationKind then
        return Status.GetUnitClassificationKind(unit)
    end

    if not unit or not UnitClassification then
        return nil
    end

    local ok, kind = pcall(function()
        local classification = UnitClassification(unit)
        if type(classification) ~= "string" or classification == "" or classification == "normal" or classification == "trivial" then
            return nil
        end

        if classification == "rare" then
            return "rare"
        elseif classification == "elite" then
            return "elite"
        elseif classification == "rareelite" then
            return "rareelite"
        elseif classification == "worldboss" then
            return "worldboss"
        end

        return nil
    end)

    if ok then
        return kind
    end

    return nil
end

local function GetLiveClassification(frame)
    local unit = frame and frame.unit
    if not unit or not UnitExists or not UnitExists(unit) or not UnitClassification then
        return nil
    end

    return ResolveSafeClassificationKind(unit)
end

local function GetClassificationStyle(classification)
    if classification == "rare" then
        return {
            primary = { 0.32, 0.68, 1.00, 0.96 },
            secondary = { 0.82, 0.93, 1.00, 0.96 },
            tint = { 0.10, 0.26, 0.46, 0.10 },
            thickness = 2,
            cornerSize = 6,
            gemSize = 10,
            crestSize = 18,
        }
    elseif classification == "elite" then
        return {
            primary = { 0.96, 0.76, 0.26, 0.96 },
            secondary = { 1.00, 0.92, 0.62, 0.96 },
            tint = { 0.36, 0.24, 0.04, 0.10 },
            thickness = 2,
            cornerSize = 6,
            gemSize = 10,
            crestSize = 18,
        }
    elseif classification == "rareelite" or classification == "worldboss" then
        return {
            primary = { 0.98, 0.80, 0.30, 0.98 },
            secondary = { 0.34, 0.70, 1.00, 0.98 },
            tint = { 0.22, 0.16, 0.04, 0.12 },
            thickness = 3,
            cornerSize = 7,
            gemSize = 12,
            crestSize = 20,
        }
    end

    return nil
end

local function ApplyPortraitOverlayStyle(holder, style)
    if not holder or not style then
        return
    end

    local primary = style.primary or { 1, 1, 1, 1 }
    local secondary = style.secondary or primary
    local tint = style.tint or { primary[1], primary[2], primary[3], 0.08 }
    local thickness = style.thickness or 2
    local cornerSize = style.cornerSize or 6
    local gemSize = style.gemSize or 10

    holder.BorderTop:ClearAllPoints()
    holder.BorderTop:SetPoint("TOPLEFT", holder, "TOPLEFT", 1, -1)
    holder.BorderTop:SetPoint("TOPRIGHT", holder, "TOPRIGHT", -1, -1)
    holder.BorderTop:SetHeight(thickness)

    holder.BorderBottom:ClearAllPoints()
    holder.BorderBottom:SetPoint("BOTTOMLEFT", holder, "BOTTOMLEFT", 1, 1)
    holder.BorderBottom:SetPoint("BOTTOMRIGHT", holder, "BOTTOMRIGHT", -1, 1)
    holder.BorderBottom:SetHeight(thickness)

    holder.BorderLeft:ClearAllPoints()
    holder.BorderLeft:SetPoint("TOPLEFT", holder, "TOPLEFT", 1, -1)
    holder.BorderLeft:SetPoint("BOTTOMLEFT", holder, "BOTTOMLEFT", 1, 1)
    holder.BorderLeft:SetWidth(thickness)

    holder.BorderRight:ClearAllPoints()
    holder.BorderRight:SetPoint("TOPRIGHT", holder, "TOPRIGHT", -1, -1)
    holder.BorderRight:SetPoint("BOTTOMRIGHT", holder, "BOTTOMRIGHT", -1, 1)
    holder.BorderRight:SetWidth(thickness)

    holder.CornerTL:ClearAllPoints()
    holder.CornerTL:SetPoint("TOPLEFT", holder, "TOPLEFT", -1, 1)
    holder.CornerTL:SetSize(cornerSize, cornerSize)

    holder.CornerTR:ClearAllPoints()
    holder.CornerTR:SetPoint("TOPRIGHT", holder, "TOPRIGHT", 1, 1)
    holder.CornerTR:SetSize(cornerSize, cornerSize)

    holder.CornerBL:ClearAllPoints()
    holder.CornerBL:SetPoint("BOTTOMLEFT", holder, "BOTTOMLEFT", -1, -1)
    holder.CornerBL:SetSize(cornerSize, cornerSize)

    holder.CornerBR:ClearAllPoints()
    holder.CornerBR:SetPoint("BOTTOMRIGHT", holder, "BOTTOMRIGHT", 1, -1)
    holder.CornerBR:SetSize(cornerSize, cornerSize)

    holder.InnerTint:SetAllPoints(holder)
    SetTextureColor(holder.InnerTint, tint[1], tint[2], tint[3], tint[4], "ADD")

    holder.GemShadow:ClearAllPoints()
    holder.GemShadow:SetPoint("TOP", holder, "TOP", 0, 1)
    holder.GemShadow:SetSize(gemSize + 4, gemSize + 4)
    holder.GemShadow:SetRotation(0.78539816339)

    holder.Gem:ClearAllPoints()
    holder.Gem:SetPoint("TOP", holder, "TOP", 0, 0)
    holder.Gem:SetSize(gemSize, gemSize)
    holder.Gem:SetRotation(0.78539816339)

    local wingWidth = math.max(10, gemSize + 4)
    holder.WingLeft:ClearAllPoints()
    holder.WingLeft:SetPoint("TOP", holder, "TOP", -gemSize + 1, -(thickness + 2))
    holder.WingLeft:SetSize(wingWidth, 2)
    holder.WingLeft:SetRotation(-0.55)

    holder.WingRight:ClearAllPoints()
    holder.WingRight:SetPoint("TOP", holder, "TOP", gemSize - 1, -(thickness + 2))
    holder.WingRight:SetSize(wingWidth, 2)
    holder.WingRight:SetRotation(0.55)

    SetTextureColor(holder.BorderTop, primary[1], primary[2], primary[3], primary[4], "ADD")
    SetTextureColor(holder.BorderBottom, primary[1], primary[2], primary[3], primary[4], "ADD")
    SetTextureColor(holder.BorderLeft, primary[1], primary[2], primary[3], primary[4], "ADD")
    SetTextureColor(holder.BorderRight, primary[1], primary[2], primary[3], primary[4], "ADD")
    SetTextureColor(holder.CornerTL, secondary[1], secondary[2], secondary[3], secondary[4], "ADD")
    SetTextureColor(holder.CornerTR, secondary[1], secondary[2], secondary[3], secondary[4], "ADD")
    SetTextureColor(holder.CornerBL, secondary[1], secondary[2], secondary[3], secondary[4], "ADD")
    SetTextureColor(holder.CornerBR, secondary[1], secondary[2], secondary[3], secondary[4], "ADD")
    SetTextureColor(holder.GemShadow, 0, 0, 0, 0.28, "BLEND")
    SetTextureColor(holder.Gem, secondary[1], secondary[2], secondary[3], secondary[4], "ADD")
    SetTextureColor(holder.WingLeft, primary[1], primary[2], primary[3], 0.78, "ADD")
    SetTextureColor(holder.WingRight, primary[1], primary[2], primary[3], 0.78, "ADD")

    holder:Show()
    holder.BorderTop:Show()
    holder.BorderBottom:Show()
    holder.BorderLeft:Show()
    holder.BorderRight:Show()
    holder.CornerTL:Show()
    holder.CornerTR:Show()
    holder.CornerBL:Show()
    holder.CornerBR:Show()
    holder.InnerTint:Show()
    holder.GemShadow:Show()
    holder.Gem:Show()
    holder.WingLeft:Show()
    holder.WingRight:Show()
end

local function ApplyCrestStyle(holder, style)
    if not holder or not style then
        return
    end

    local primary = style.primary or { 1, 1, 1, 1 }
    local secondary = style.secondary or primary
    local size = style.crestSize or 18

    holder:SetSize(size, size)
    holder.Backdrop:SetAllPoints(holder)

    holder.BorderTop:ClearAllPoints()
    holder.BorderTop:SetPoint("TOPLEFT", holder, "TOPLEFT", 1, -1)
    holder.BorderTop:SetPoint("TOPRIGHT", holder, "TOPRIGHT", -1, -1)
    holder.BorderTop:SetHeight(2)

    holder.BorderBottom:ClearAllPoints()
    holder.BorderBottom:SetPoint("BOTTOMLEFT", holder, "BOTTOMLEFT", 1, 1)
    holder.BorderBottom:SetPoint("BOTTOMRIGHT", holder, "BOTTOMRIGHT", -1, 1)
    holder.BorderBottom:SetHeight(2)

    holder.BorderLeft:ClearAllPoints()
    holder.BorderLeft:SetPoint("TOPLEFT", holder, "TOPLEFT", 1, -1)
    holder.BorderLeft:SetPoint("BOTTOMLEFT", holder, "BOTTOMLEFT", 1, 1)
    holder.BorderLeft:SetWidth(2)

    holder.BorderRight:ClearAllPoints()
    holder.BorderRight:SetPoint("TOPRIGHT", holder, "TOPRIGHT", -1, -1)
    holder.BorderRight:SetPoint("BOTTOMRIGHT", holder, "BOTTOMRIGHT", -1, 1)
    holder.BorderRight:SetWidth(2)

    holder.Diamond:ClearAllPoints()
    holder.Diamond:SetPoint("CENTER", holder, "CENTER", 0, 0)
    holder.Diamond:SetSize(size * 0.48, size * 0.48)
    holder.Diamond:SetRotation(0.78539816339)

    holder.DiamondGlow:ClearAllPoints()
    holder.DiamondGlow:SetPoint("CENTER", holder, "CENTER", 0, 0)
    holder.DiamondGlow:SetSize(size * 0.72, size * 0.72)
    holder.DiamondGlow:SetRotation(0.78539816339)

    SetTextureColor(holder.Backdrop, 0.02, 0.03, 0.04, 0.68, "BLEND")
    SetTextureColor(holder.BorderTop, primary[1], primary[2], primary[3], primary[4], "ADD")
    SetTextureColor(holder.BorderBottom, primary[1], primary[2], primary[3], primary[4], "ADD")
    SetTextureColor(holder.BorderLeft, primary[1], primary[2], primary[3], primary[4], "ADD")
    SetTextureColor(holder.BorderRight, primary[1], primary[2], primary[3], primary[4], "ADD")
    SetTextureColor(holder.DiamondGlow, primary[1], primary[2], primary[3], 0.18, "ADD")
    SetTextureColor(holder.Diamond, secondary[1], secondary[2], secondary[3], secondary[4], "ADD")

    holder:Show()
    holder.Backdrop:Show()
    holder.BorderTop:Show()
    holder.BorderBottom:Show()
    holder.BorderLeft:Show()
    holder.BorderRight:Show()
    holder.DiamondGlow:Show()
    holder.Diamond:Show()
end

local function HideClassificationElements(frame)
    if not frame or not frame.Elements then
        return
    end

    local portraitOverlay = frame.Elements.ClassificationPortraitOverlay
    if portraitOverlay then
        portraitOverlay:Hide()
    end

    local crest = frame.Elements.ClassificationCrest
    if crest then
        crest:Hide()
    end
end

function Classification.Hide(frame)
    HideClassificationElements(frame)
end

function Classification.Create(frame)
    local portraitOverlay = CreateFrame("Frame", nil, frame)
    portraitOverlay:SetFrameStrata(frame:GetFrameStrata())
    portraitOverlay:SetFrameLevel(frame:GetFrameLevel() + 26)
    portraitOverlay:Hide()

    portraitOverlay.InnerTint = CreateSolidTexture(portraitOverlay, "BACKGROUND", 0)
    portraitOverlay.BorderTop = CreateSolidTexture(portraitOverlay, "OVERLAY", 1)
    portraitOverlay.BorderBottom = CreateSolidTexture(portraitOverlay, "OVERLAY", 1)
    portraitOverlay.BorderLeft = CreateSolidTexture(portraitOverlay, "OVERLAY", 1)
    portraitOverlay.BorderRight = CreateSolidTexture(portraitOverlay, "OVERLAY", 1)
    portraitOverlay.CornerTL = CreateSolidTexture(portraitOverlay, "OVERLAY", 2)
    portraitOverlay.CornerTR = CreateSolidTexture(portraitOverlay, "OVERLAY", 2)
    portraitOverlay.CornerBL = CreateSolidTexture(portraitOverlay, "OVERLAY", 2)
    portraitOverlay.CornerBR = CreateSolidTexture(portraitOverlay, "OVERLAY", 2)
    portraitOverlay.GemShadow = CreateSolidTexture(portraitOverlay, "OVERLAY", 3)
    portraitOverlay.Gem = CreateSolidTexture(portraitOverlay, "OVERLAY", 4)
    portraitOverlay.WingLeft = CreateSolidTexture(portraitOverlay, "OVERLAY", 3)
    portraitOverlay.WingRight = CreateSolidTexture(portraitOverlay, "OVERLAY", 3)

    local crest = CreateFrame("Frame", nil, frame)
    crest:SetFrameStrata(frame:GetFrameStrata())
    crest:SetFrameLevel(frame:GetFrameLevel() + 27)
    crest:Hide()

    crest.Backdrop = CreateSolidTexture(crest, "BACKGROUND", 0)
    crest.BorderTop = CreateSolidTexture(crest, "OVERLAY", 1)
    crest.BorderBottom = CreateSolidTexture(crest, "OVERLAY", 1)
    crest.BorderLeft = CreateSolidTexture(crest, "OVERLAY", 1)
    crest.BorderRight = CreateSolidTexture(crest, "OVERLAY", 1)
    crest.DiamondGlow = CreateSolidTexture(crest, "OVERLAY", 2)
    crest.Diamond = CreateSolidTexture(crest, "OVERLAY", 3)

    frame.Elements.ClassificationPortraitOverlay = portraitOverlay
    frame.Elements.ClassificationCrest = crest
    frame.ClassificationPortraitOverlay = portraitOverlay
    frame.ClassificationCrest = crest
end

function Classification.ApplyLayout(frame, options)
    if not frame or not frame.Elements then
        return
    end

    local portraitOverlay = frame.Elements.ClassificationPortraitOverlay
    local crest = frame.Elements.ClassificationCrest
    if not portraitOverlay or not crest then
        return
    end

    local effect = NormalizeEffect(options and options.effect)
    local classification = options and options.classification or nil
    if Preview.ShouldShowComponent and Preview.ShouldShowComponent("rareEliteRaid", { frame = frame }) == false then
        HideClassificationElements(frame)
        return
    end

    local style = GetClassificationStyle(classification)
    if not style or effect == "NONE" or effect == "NAME_GLOW" or effect == "NAME_LABEL" then
        HideClassificationElements(frame)
        return
    end

    local portrait = frame.Elements.Portrait
    local portraitShown = portrait and portrait.IsShown and portrait:IsShown() or false

    if effect == "PORTRAIT_OVERLAY" then
        local overlayTarget = portraitShown and portrait or frame
        crest:Hide()
        portraitOverlay:ClearAllPoints()
        portraitOverlay:SetAllPoints(overlayTarget)
        portraitOverlay:SetFrameStrata(overlayTarget:GetFrameStrata())
        portraitOverlay:SetFrameLevel(math.max(overlayTarget:GetFrameLevel() + 6, frame:GetFrameLevel() + 26))
        ApplyPortraitOverlayStyle(portraitOverlay, style)
        return
    end

    portraitOverlay:Hide()
    crest:ClearAllPoints()
    crest:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 4, 4)
    crest:SetFrameStrata(frame:GetFrameStrata())
    crest:SetFrameLevel(math.max(frame:GetFrameLevel() + 27, (frame.Elements.HealthBar and frame.Elements.HealthBar:GetFrameLevel() + 14) or (frame:GetFrameLevel() + 27)))
    ApplyCrestStyle(crest, style)
end

function Classification.GetResolved(frame)
    if Preview.ShouldShowComponent and Preview.ShouldShowComponent("rareEliteRaid", { frame = frame }) == false then
        return nil, "NONE"
    end

    local config = frame and frame.config
    local indicatorConfig = config and config.ClassificationIndicator
    if type(indicatorConfig) ~= "table" then
        return nil, "PORTRAIT_OVERLAY"
    end

    if indicatorConfig.enabled == false then
        return nil, "NONE"
    end

    local effect = NormalizeEffect(indicatorConfig.effect)
    local classification = GetLiveClassification(frame) or GetPreviewClassification(frame)
    return classification, effect
end

function Classification.RegisterEvents(owner, frame)
    if not frame or frame.ClassificationIndicatorEventFrame or not frame.Elements then
        return
    end

    local eventFrame = CreateFrame("Frame", nil, frame)
    eventFrame.owner = frame

    eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    eventFrame:RegisterEvent("UNIT_CLASSIFICATION_CHANGED")
    eventFrame:RegisterEvent("PORTRAITS_UPDATED")
    eventFrame:RegisterEvent("UNIT_PORTRAIT_UPDATE")
    eventFrame:RegisterEvent("UNIT_MODEL_CHANGED")

    if frame.unit == "target" then
        eventFrame:RegisterEvent("PLAYER_TARGET_CHANGED")
    elseif frame.unit == "targettarget" then
        eventFrame:RegisterEvent("PLAYER_TARGET_CHANGED")
        eventFrame:RegisterEvent("UNIT_TARGET")
    elseif frame.unit == "focustarget" then
        eventFrame:RegisterEvent("PLAYER_FOCUS_CHANGED")
        eventFrame:RegisterEvent("UNIT_TARGET")
    elseif frame.unit == "focus" then
        eventFrame:RegisterEvent("PLAYER_FOCUS_CHANGED")
    elseif type(frame.unit) == "string" and frame.unit:match("^boss%d+$") then
        eventFrame:RegisterEvent("INSTANCE_ENCOUNTER_ENGAGE_UNIT")
    end

    eventFrame:SetScript("OnEvent", function(_, event, unit)
        local currentOwner = eventFrame.owner
        if not currentOwner or not currentOwner:IsShown() then
            return
        end

        if event == "UNIT_TARGET" then
            local targetOk = currentOwner.unit == "targettarget" and unit == "target"
            local focusOk = currentOwner.unit == "focustarget" and unit == "focus"
            if not targetOk and not focusOk then
                return
            end
        elseif (event == "UNIT_CLASSIFICATION_CHANGED" or event == "UNIT_PORTRAIT_UPDATE" or event == "UNIT_MODEL_CHANGED")
            and unit
            and unit ~= currentOwner.unit
        then
            return
        end

        if State.QueueRefresh then
            State.QueueRefresh(currentOwner, event, "layout")
        else
            C_Timer.After(0, function()
                if currentOwner and currentOwner:IsShown() and owner and owner.ApplyConfig then
                    owner:ApplyConfig(currentOwner)
                end
            end)
        end
    end)

    frame.ClassificationIndicatorEventFrame = eventFrame
end
