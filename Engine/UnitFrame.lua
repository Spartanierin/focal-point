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
    return color[1] or 1, color[2] or 1, color[3] or 1, color[4] or 1
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
    elseif anchorTo == "Frame" then
        return frame
    end

    return frame
end

function UF:CreateBaseFrame(unit, config)
    local frameName = "Portrait_" .. unit:gsub("^%l", string.upper)
    local frame = CreateFrame("Button", frameName, UIParent, "BackdropTemplate")

    frame.unit = unit
    frame.config = config
    frame.Elements = {}
    frame.Texts = {}
    frame.Tags = {}

    frame:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
        insets = { left = 0, right = 0, top = 0, bottom = 0 },
    })

    return frame
end

function UF:CreateHealthBar(frame)
    local health = CreateFrame("StatusBar", nil, frame)
    health:SetMinMaxValues(0, 100)

    frame.Elements.HealthBar = health
    frame.health = health
end

function UF:CreatePowerBar(frame)
    local power = CreateFrame("StatusBar", nil, frame)
    power:SetMinMaxValues(0, 100)

    frame.Elements.PowerBar = power
    frame.power = power
end

function UF:CreateTextElement(frame, key, textConfig)
    if not textConfig or textConfig.enabled == false then
        return
    end

    local parent = self:GetAnchorTarget(frame, textConfig.anchorTo)
    local text = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    text:SetDrawLayer("OVERLAY", 7)
    text:SetWordWrap(false)
    text:SetJustifyV("MIDDLE")

    frame.Texts[key] = text
    frame.Tags[key] = textConfig.tag or ""
end

function UF:CreateTextElements(frame)
    local texts = frame.config.Texts
    if not texts then
        return
    end

    for key, textConfig in pairs(texts) do
        self:CreateTextElement(frame, key, textConfig)
    end
end

function UF:ApplyTextElementConfig(frame, key, textObject, textConfig)
    if not textObject or not textConfig then
        return
    end

    if textConfig.enabled == false then
        textObject:Hide()
        return
    end

    local anchorParent = self:GetAnchorTarget(frame, textConfig.anchorTo)
    local fontPath = GetFontPath(textConfig.font)
    local fontSize = textConfig.fontSize or 12
    local fontFlags = BuildFontFlags(textConfig)
    local justifyH = textConfig.justifyH or "CENTER"

    local r, g, b, a = UnpackColor(textConfig.color, { 1, 1, 1, 1 })

    textObject:ClearAllPoints()
    textObject:SetPoint(
        textConfig.point or "CENTER",
        anchorParent,
        textConfig.relativePoint or "CENTER",
        textConfig.offsetX or 0,
        textConfig.offsetY or 0
    )

    textObject:SetFont(fontPath, fontSize, fontFlags ~= "" and fontFlags or nil)
    textObject:SetTextColor(r, g, b, a)
    textObject:SetJustifyH(justifyH)

    if textConfig.shadowEnabled then
        local sx = textConfig.shadowOffsetX or 1
        local sy = textConfig.shadowOffsetY or -1
        local sr, sg, sb, sa = UnpackColor(textConfig.shadowColor, { 0, 0, 0, 1 })

        textObject:SetShadowOffset(sx, sy)
        textObject:SetShadowColor(sr, sg, sb, sa)
    else
        textObject:SetShadowOffset(0, 0)
        textObject:SetShadowColor(0, 0, 0, 0)
    end

    textObject:Show()
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
    local borderInset = 1

    local bgR, bgG, bgB, bgA = UnpackColor(config.backgroundColor, { 0.08, 0.08, 0.08, 0.9 })
    local borderR, borderG, borderB, borderA = UnpackColor(config.borderColor, { 0.2, 0.2, 0.2, 1 })
    local healthR, healthG, healthB, healthA = UnpackColor(config.healthColor, { 0.1, 0.8, 0.1, 1 })
    local powerR, powerG, powerB, powerA = UnpackColor(config.powerColor, { 0.2, 0.4, 0.9, 1 })

    local texture = GetStatusBarTexture(config.statusBarTexture)

    frame:ClearAllPoints()
    frame:SetSize(width, height)
    frame:SetAlpha(alpha)
    frame:SetScale(scale)
    frame:SetFrameLevel(frameLevel)
    frame:SetFrameStrata(frameStrata)
    frame:SetShown(config.enabled ~= false)
    frame:EnableMouse(config.mouseEnabled ~= false)
    frame:SetMouseClickEnabled(not config.clickThrough)
    frame:SetClampedToScreen(config.clampToScreen == true)

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

    if frame.Elements.HealthBar then
        local health = frame.Elements.HealthBar
        health:ClearAllPoints()
        health:SetStatusBarTexture(texture)
        health:SetStatusBarColor(healthR, healthG, healthB, healthA)

        health:SetPoint("TOPLEFT", frame, "TOPLEFT", borderInset, -borderInset)
        health:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -borderInset, -borderInset)

        if showPowerBar then
            health:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", borderInset, borderInset + powerBarHeight)
            health:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -borderInset, borderInset + powerBarHeight)
        else
            health:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", borderInset, borderInset)
            health:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -borderInset, borderInset)
        end

        health:Show()
    end

    if frame.Elements.PowerBar then
        local power = frame.Elements.PowerBar
        power:ClearAllPoints()
        power:SetStatusBarTexture(texture)
        power:SetStatusBarColor(powerR, powerG, powerB, powerA)

        if showPowerBar then
            power:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", borderInset, borderInset)
            power:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -borderInset, borderInset)
            power:SetHeight(powerBarHeight)
            power:Show()
        else
            power:Hide()
        end
    end

    if config.Texts then
        for key, textConfig in pairs(config.Texts) do
            self:ApplyTextElementConfig(frame, key, frame.Texts[key], textConfig)
        end
    end
end

function UF:ApplyTestValues(frame)
    if frame.Elements.HealthBar then
        frame.Elements.HealthBar:SetValue(100)
    end

    if frame.Elements.PowerBar then
        frame.Elements.PowerBar:SetValue(65)
    end

    if frame.Texts.Name then
        local cfg = frame.config and frame.config.Texts and frame.config.Texts.Name
        frame.Texts.Name:SetText((cfg and cfg.tag) or "[name]")
    end

    if frame.Texts.Health then
        local cfg = frame.config and frame.config.Texts and frame.config.Texts.Health
        frame.Texts.Health:SetText((cfg and cfg.tag) or "[hp:cur]")
    end
end

function UF:Build(unit)
    local config = GetUnitDB(unit)
    if not config or config.enabled == false then
        return nil
    end

    local frame = self:CreateBaseFrame(unit, config)
    self:CreateHealthBar(frame)
    self:CreatePowerBar(frame)
    self:CreateTextElements(frame)

    self:ApplyConfig(frame)
    self:ApplyTestValues(frame)

    frame:Show()
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

    frame.config = config
    self:ApplyConfig(frame)
    self:ApplyTestValues(frame)
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