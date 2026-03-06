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

    if config.nameOutline then
        flags[#flags + 1] = "OUTLINE"
    end

    if config.nameThickOutline then
        flags[#flags + 1] = "THICKOUTLINE"
    end

    if config.nameMonochrome then
        flags[#flags + 1] = "MONOCHROME"
    end

    return table.concat(flags, ",")
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

function UF:CreateNameText(frame)
    local parent = frame.Elements.HealthBar or frame

    local name = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    name:SetDrawLayer("OVERLAY", 7)
    name:SetJustifyV("MIDDLE")
    name:SetWordWrap(false)

    frame.Texts.Name = name
    frame.name = name

    -- Vorbereitung fürs spätere Tag-System
    frame.Tags.Name = frame.config.nameTag or "[name]"
end

function UF:ApplyConfig(frame)
    local config = frame.config
    if not config then
        return
    end

    local width = config.width or 220
    local height = config.height or 40
    local showPowerBar = config.showPowerBar and true or false
    local powerBarHeight = showPowerBar and (config.powerBarHeight or 8) or 0
    local borderInset = 1

    local bgR, bgG, bgB, bgA = UnpackColor(config.backgroundColor, { 0.08, 0.08, 0.08, 0.9 })
    local borderR, borderG, borderB, borderA = UnpackColor(config.borderColor, { 0.2, 0.2, 0.2, 1 })
    local healthR, healthG, healthB, healthA = UnpackColor(config.healthColor, { 0.1, 0.8, 0.1, 1 })
    local powerR, powerG, powerB, powerA = UnpackColor(config.powerColor, { 0.2, 0.4, 0.9, 1 })
    local nameR, nameG, nameB, nameA = UnpackColor(config.nameColor, { 1, 1, 1, 1 })

    local texture = GetStatusBarTexture(config.statusBarTexture)

    frame:ClearAllPoints()
    frame:SetSize(width, height)

    local relativeTo = _G[config.relativeTo or "UIParent"] or UIParent
    frame:SetPoint(
        config.point or "CENTER",
        relativeTo,
        config.relativePoint or "CENTER",
        config.x or 0,
        config.y or 0
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

    if frame.Texts.Name then
        local name = frame.Texts.Name
        local anchorParent = frame.Elements.HealthBar or frame
        local fontPath = GetFontPath(config.nameFont)
        local fontSize = config.nameFontSize or 12
        local fontFlags = BuildFontFlags(config)
        local justifyH = config.nameJustifyH or "CENTER"

        name:ClearAllPoints()
        name:SetPoint("CENTER", anchorParent, "CENTER", config.nameOffsetX or 0, config.nameOffsetY or 0)
        name:SetTextColor(nameR, nameG, nameB, nameA)
        name:SetJustifyH(justifyH)

        name:SetFont(fontPath, fontSize, fontFlags ~= "" and fontFlags or nil)

        if config.nameShadowEnabled then
            local sx = config.nameShadowOffsetX or 1
            local sy = config.nameShadowOffsetY or -1
            local sr, sg, sb, sa = UnpackColor(config.nameShadowColor, { 0, 0, 0, 1 })

            name:SetShadowOffset(sx, sy)
            name:SetShadowColor(sr, sg, sb, sa)
        else
            name:SetShadowOffset(0, 0)
            name:SetShadowColor(0, 0, 0, 0)
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
        frame.Texts.Name:SetText("PORTRAIT TEST")
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
    self:CreateNameText(frame)

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