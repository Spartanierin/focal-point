local _, FocalPoint = ...

FocalPoint.UnitFrameFactory = FocalPoint.UnitFrameFactory or {}
local Factory = FocalPoint.UnitFrameFactory

-- Factory helpers create the base frame and the core status bar elements.

function Factory.GetAnchorTarget(frame, anchorTo)
    if anchorTo == "HealthBar" then
        return frame.Elements.HealthBar or frame
    elseif anchorTo == "PowerBar" then
        return frame.Elements.PowerBar or frame
    elseif anchorTo == "ClassPowerBar" then
        return frame.Elements.ClassPowerBar or frame
    elseif anchorTo == "AlternativePowerBar" then
        return frame.Elements.AlternativePowerBar or frame
    elseif anchorTo == "CastBar" then
        return frame.Elements.CastBar or frame
    elseif anchorTo == "Frame" then
        return frame
    end

    return frame
end

function Factory.CreateBaseFrame(unit, config)
    local frameName = "FocalPoint_" .. unit:gsub("^%l", string.upper)
    local frame = CreateFrame("Button", frameName, UIParent, "SecureUnitButtonTemplate, BackdropTemplate")

    frame.unit = unit
    frame.config = config
    frame.Elements = {}
    frame.Texts = {}
    frame.Tags = {}
    frame.LiveValues = {}

    frame:RegisterForClicks("AnyUp")
    frame:SetAttribute("unit", unit)
    frame:SetAttribute("*type1", "target")
    frame:SetAttribute("*type2", "togglemenu")
    frame:SetAttribute("toggleForVehicle", true)

    if unit ~= "player" and RegisterUnitWatch then
        RegisterUnitWatch(frame)
        frame._unitWatchRegistered = true
    end

    frame:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
        insets = { left = 0, right = 0, top = 0, bottom = 0 },
    })

    if FocalPoint.UpdateFrameDragState then
        FocalPoint:UpdateFrameDragState(frame)
    end

    return frame
end

function Factory.CreateHealthBar(frame)
    local health = CreateFrame("StatusBar", nil, frame)
    health:SetMinMaxValues(0, 100)

    local bg = health:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetTexture("Interface\\Buttons\\WHITE8X8")
    health.bg = bg

    local absorbOverlay = CreateFrame("StatusBar", nil, frame)
    absorbOverlay:SetFrameStrata(frame:GetFrameStrata() or "MEDIUM")
    absorbOverlay:SetFrameLevel((health:GetFrameLevel() or frame:GetFrameLevel() or 1) + 5)
    absorbOverlay:SetStatusBarTexture("Interface\\Buttons\\WHITE8X8")
    absorbOverlay:SetStatusBarColor(0.66, 0.86, 1.0, 0.62)
    absorbOverlay:SetMinMaxValues(0, 1)
    absorbOverlay:SetValue(0)
    absorbOverlay:Hide()
    health.AbsorbOverlay = absorbOverlay

    local absorbMinMarker = health:CreateTexture(nil, "ARTWORK")
    absorbMinMarker:SetTexture("Interface\\Buttons\\WHITE8X8")
    absorbMinMarker:SetSize(2, 1)
    absorbMinMarker:SetVertexColor(0.66, 0.86, 1.0, 0.95)
    absorbMinMarker:Hide()
    health.AbsorbMinMarker = absorbMinMarker

    frame.Elements.HealthBar = health
    frame.health = health
end

function Factory.CreatePowerBar(frame)
    local power = CreateFrame("StatusBar", nil, frame)
    power:SetMinMaxValues(0, 100)

    local bg = power:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetTexture("Interface\\Buttons\\WHITE8X8")
    power.bg = bg

    frame.Elements.PowerBar = power
    frame.power = power
end

function Factory.CreateAlternativePowerBar(frame)
    local power = CreateFrame("StatusBar", nil, frame)
    power:SetMinMaxValues(0, 100)
    power:SetFrameStrata(frame:GetFrameStrata())
    power:SetFrameLevel(frame:GetFrameLevel() + 3)

    local bg = power:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetTexture("Interface\\Buttons\\WHITE8X8")
    power.bg = bg

    frame.Elements.AlternativePowerBar = power
    frame.alternativePower = power
end

function Factory.CreateClassPowerBar(frame)
    local holder = CreateFrame("Frame", nil, frame)
    holder:SetFrameStrata(frame:GetFrameStrata())
    holder:SetFrameLevel(frame:GetFrameLevel() + 4)
    holder.Bars = {}
    holder:Hide()

    for index = 1, 10 do
        local bar = CreateFrame("StatusBar", nil, holder)
        bar:SetMinMaxValues(0, 1)
        bar:Hide()

        local bg = bar:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints()
        bg:SetTexture("Interface\\Buttons\\WHITE8X8")
        bar.bg = bg

        local border = CreateFrame("Frame", nil, bar, "BackdropTemplate")
        border:SetPoint("TOPLEFT", bar, "TOPLEFT", 0, 0)
        border:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", 0, 0)
        border:SetFrameLevel(bar:GetFrameLevel() + 1)
        border:SetBackdrop({
            edgeFile = "Interface\\Buttons\\WHITE8X8",
            edgeSize = 1,
        })
        bar.border = border

        holder.Bars[index] = bar
    end

    frame.Elements.ClassPowerBar = holder
    frame.classPower = holder
end

function Factory.CreateCastBar(frame)
    local cast = CreateFrame("StatusBar", nil, frame)
    cast:SetMinMaxValues(0, 1)
    cast:SetFrameStrata(frame:GetFrameStrata())
    cast:SetFrameLevel(frame:GetFrameLevel() + 5)
    cast:Hide()

    local bg = cast:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetTexture("Interface\\Buttons\\WHITE8X8")
    cast.bg = bg

    local icon = cast:CreateTexture(nil, "ARTWORK")
    icon:Hide()
    cast.icon = icon

    cast.isCasting = false
    cast.isChannel = false
    cast.startTime = 0
    cast.endTime = 0

    frame.Elements.CastBar = cast
    frame.castBar = cast
end
