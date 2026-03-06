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

function UF:CreateBaseFrame(unit, config)
    local frameName = "Portrait_" .. unit:gsub("^%l", string.upper)
    local frame = CreateFrame("Button", frameName, UIParent, "BackdropTemplate")

    frame.unit = unit
    frame.config = config
    frame.Elements = {}
    frame.Texts = {}
    frame.Tags = {}

    frame:SetSize(config.width or 220, config.height or 40)

    local relativeTo = _G[config.relativeTo or "UIParent"] or UIParent
    frame:SetPoint(
        config.point or "CENTER",
        relativeTo,
        config.relativePoint or "CENTER",
        config.x or 0,
        config.y or 0
    )

    frame:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
        insets = { left = 0, right = 0, top = 0, bottom = 0 },
    })

    frame:SetBackdropColor(0.08, 0.08, 0.08, 0.9)
    frame:SetBackdropBorderColor(0.2, 0.2, 0.2, 1)

    return frame
end

function UF:CreateHealthBar(frame, config)
    local health = CreateFrame("StatusBar", nil, frame)
    health:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
    health:SetMinMaxValues(0, 100)
    health:SetValue(100)

    local powerBarHeight = 0
    if config.showPowerBar then
        powerBarHeight = config.powerBarHeight or 8
    end

    health:SetPoint("TOPLEFT", frame, "TOPLEFT", 1, -1)
    health:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -1, -1)
    health:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 1, 1 + powerBarHeight)
    health:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -1, 1 + powerBarHeight)

    frame.Elements.HealthBar = health
    frame.health = health
end

function UF:CreatePowerBar(frame, config)
    if not config.showPowerBar then
        return
    end

    local powerHeight = config.powerBarHeight or 8

    local power = CreateFrame("StatusBar", nil, frame)
    power:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
    power:SetMinMaxValues(0, 100)
    power:SetValue(65)

    power:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 1, 1)
    power:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -1, 1)
    power:SetHeight(powerHeight)

    frame.Elements.PowerBar = power
    frame.power = power
end

function UF:CreateNameText(frame, config)
    local parent = frame.Elements.HealthBar or frame

    local name = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    name:SetPoint("CENTER", parent, "CENTER", 0, 0)
    name:SetJustifyH("CENTER")
    name:SetText(frame.unit:upper())

    frame.Texts.Name = name
    frame.name = name

    -- Vorbereitung für späteres Tag-System
    frame.Tags.Name = config.nameTag or "[name]"
end

function UF:ApplyTestValues(frame)
    if frame.Elements.HealthBar then
        frame.Elements.HealthBar:SetValue(100)
    end

    if frame.Elements.PowerBar then
        frame.Elements.PowerBar:SetValue(65)
    end

    if frame.Texts.Name then
        frame.Texts.Name:SetText(frame.unit:upper())
    end
end

function UF:Build(unit)
    local config = GetUnitDB(unit)
    if not config or config.enabled == false then
        return nil
    end

    local frame = self:CreateBaseFrame(unit, config)
    self:CreateHealthBar(frame, config)
    self:CreatePowerBar(frame, config)
    self:CreateNameText(frame, config)
    self:ApplyTestValues(frame)

    frame:Show()
    return frame
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