local _, FocalPoint = ...

FocalPoint.UnitFrameFactory = FocalPoint.UnitFrameFactory or {}
local Factory = FocalPoint.UnitFrameFactory
local UnitWatchPolicy = FocalPoint.UnitFrameUnitWatchPolicy or {}
local AbsorbBars = FocalPoint.UnitFrameAbsorbBars or {}

-- Factory helpers create the base frame and the core status bar elements.

local function LayoutBarBorder(owner, border, width, height)
    -- Full owner geometry only, never the secret-dependent status-bar fill.
    if (issecretvalue and (issecretvalue(width) or issecretvalue(height)))
        or type(width) ~= "number" or type(height) ~= "number"
        or width ~= width or height ~= height or width <= 0 or height <= 0
        or width == math.huge or height == math.huge or border.requestedWidth == 0 then
        border:Hide()
        return
    end
    local thickness = math.min(border.requestedWidth, width / 2, height / 2)
    local top, bottom, left, right = border.edges[1], border.edges[2], border.edges[3], border.edges[4]
    top:SetHeight(thickness)
    bottom:SetHeight(thickness)
    -- Top/bottom own the corners; the side strips never overlap them.
    left:ClearAllPoints()
    left:SetPoint("TOPLEFT", owner, "TOPLEFT", 0, -thickness)
    left:SetPoint("BOTTOMLEFT", owner, "BOTTOMLEFT", 0, thickness)
    left:SetWidth(thickness)
    right:ClearAllPoints()
    right:SetPoint("TOPRIGHT", owner, "TOPRIGHT", 0, -thickness)
    right:SetPoint("BOTTOMRIGHT", owner, "BOTTOMRIGHT", 0, thickness)
    right:SetWidth(thickness)
    top:Show(); bottom:Show()
    left:SetShown(height > 2 * thickness)
    right:SetShown(height > 2 * thickness)
    border:Show()
end

function Factory.ApplyBarBorder(owner, width, color, allowNamedColor)
    if not owner then return end
    local border = owner.BarBorder
    -- Preserve the zero-cost legacy path, including fixtures without layout data.
    if width == nil or width == 0 then
        if border then
            border.requestedWidth = 0
            for _, edge in ipairs(border.edges) do edge:Hide() end
            border:Hide()
        end
        return
    end
    local resolvedWidth, rgba = FocalPoint.LayoutService.ResolveBarBorder(width, color, allowNamedColor)
    if not resolvedWidth then
        Factory.ApplyBarBorder(owner, 0)
        return
    end
    if not border then
        border = CreateFrame("Frame", nil, owner)
        border:SetAllPoints(owner)
        border:EnableMouse(false)
        border.edges = {}
        for index = 1, 4 do
            local edge = border:CreateTexture(nil, "OVERLAY")
            edge:SetTexture("Interface\\Buttons\\WHITE8X8")
            border.edges[index] = edge
        end
        local top, bottom = border.edges[1], border.edges[2]
        top:SetPoint("TOPLEFT", owner, "TOPLEFT", 0, 0)
        top:SetPoint("TOPRIGHT", owner, "TOPRIGHT", 0, 0)
        bottom:SetPoint("BOTTOMLEFT", owner, "BOTTOMLEFT", 0, 0)
        bottom:SetPoint("BOTTOMRIGHT", owner, "BOTTOMRIGHT", 0, 0)
        owner.BarBorder = border
        -- Anchor resolution and later owner resizing need no polling or new timer.
        owner:HookScript("OnSizeChanged", function(self, w, h)
            LayoutBarBorder(self, border, w, h)
        end)
    end
    border.requestedWidth = resolvedWidth
    border:SetFrameStrata(owner:GetFrameStrata())
    local level = owner:GetFrameLevel()
    for _, segment in ipairs(owner.Bars or {}) do
        level = math.max(level, segment:GetFrameLevel())
        if segment.border then level = math.max(level, segment.border:GetFrameLevel()) end
    end
    border:SetFrameLevel(level + 1)
    for _, edge in ipairs(border.edges) do edge:SetVertexColor(rgba[1], rgba[2], rgba[3], rgba[4]) end
    LayoutBarBorder(owner, border, owner:GetWidth(), owner:GetHeight())
end

local function ShouldUseUnitWatch(unit)
    return UnitWatchPolicy.ShouldUse and UnitWatchPolicy.ShouldUse(unit) or false
end

local function HideUnitTooltip(frame)
    if GameTooltip and GameTooltip.Hide then
        if GameTooltip.GetOwner and GameTooltip:GetOwner() ~= frame then
            return
        end
        GameTooltip:Hide()
    end
end

local function ShowUnitTooltip(frame)
    if FocalPoint.framesUnlocked == true then
        return
    end
    local general = FocalPoint.db and FocalPoint.db.profile and FocalPoint.db.profile.General
    if type(general) == "table" and general.ShowUnitTooltips == false then
        return
    end
    if not (frame and frame._fpUnit and GameTooltip and GameTooltip.SetOwner and GameTooltip.SetUnit) then
        return
    end
    if UnitExists and not UnitExists(frame._fpUnit) then
        return
    end

    GameTooltip:SetOwner(frame, "ANCHOR_RIGHT")
    GameTooltip:SetUnit(frame._fpUnit)
end

function Factory.GetAnchorTarget(frame, anchorTo)
    if anchorTo == "HealthBar" then
        return frame.Elements.HealthBar or frame
    elseif anchorTo == "NormalAbsorbBar" then
        return frame.Elements.NormalAbsorbBar or frame
    elseif anchorTo == "HealingAbsorbBar" then
        return frame.Elements.HealingAbsorbBar or frame
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
    local frame = CreateFrame("Button", frameName, UIParent, "SecureUnitButtonTemplate, PingableUnitFrameTemplate, BackdropTemplate")

    frame._fpUnit = unit
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
    frame:SetScript("OnEnter", ShowUnitTooltip)
    frame:SetScript("OnLeave", HideUnitTooltip)

    if ShouldUseUnitWatch(unit) and RegisterUnitWatch then
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

    frame.Elements.HealthBar = health
    frame.health = health

    if AbsorbBars.CreateNormalAbsorbBar then
        AbsorbBars.CreateNormalAbsorbBar(frame)
    end
    if AbsorbBars.CreateHealingAbsorbBar then
        AbsorbBars.CreateHealingAbsorbBar(frame)
    end
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

local function CreateSegmentHolder(frame, count)
    local holder = CreateFrame("Frame", nil, frame)
    holder:SetFrameStrata(frame:GetFrameStrata())
    holder:SetFrameLevel(frame:GetFrameLevel() + 4)
    holder.Bars = {}
    holder:Hide()

    for index = 1, count do
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

    return holder
end

function Factory.CreateSegmentedBar(frame)
    return CreateSegmentHolder(frame, 6)
end

function Factory.CreateClassPowerBar(frame)
    local holder = CreateSegmentHolder(frame, 10)
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
