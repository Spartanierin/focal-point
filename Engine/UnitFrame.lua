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

    local r = color[1] or color.r or 1
    local g = color[2] or color.g or 1
    local b = color[3] or color.b or 1
    local a = color[4]
    if a == nil then
        a = color.a
    end
    if a == nil then
        a = 1
    end

    return r, g, b, a
end

local function GetClassColorForUnit(unit)
    if not unit or not UnitExists or not UnitExists(unit) or not UnitClass then
        return nil
    end

    local _, classToken = UnitClass(unit)
    if not classToken then
        return nil
    end

    local color = nil

    if CUSTOM_CLASS_COLORS and CUSTOM_CLASS_COLORS[classToken] then
        color = CUSTOM_CLASS_COLORS[classToken]
    elseif RAID_CLASS_COLORS and RAID_CLASS_COLORS[classToken] then
        color = RAID_CLASS_COLORS[classToken]
    end

    if not color then
        return nil
    end

    return color.r or color[1], color.g or color[2], color.b or color[3], 1
end

local function GetPowerColorForUnit(unit)
    if not unit or not UnitExists or not UnitExists(unit) or not UnitPowerType then
        return nil
    end

    local powerType = UnitPowerType(unit)
    if powerType == nil then
        return nil
    end

    local color = PowerBarColor and PowerBarColor[powerType]
    if not color then
        return nil
    end

    return color.r or color[1], color.g or color[2], color.b or color[3], 1
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


-- Frame
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

-- HealthBar
function UF:CreateHealthBar(frame)
    local health = CreateFrame("StatusBar", nil, frame)
    health:SetMinMaxValues(0, 100)

    local bg = health:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetTexture("Interface\\Buttons\\WHITE8X8")
    health.bg = bg

    frame.Elements.HealthBar = health
    frame.health = health
end

-- PowerBar
function UF:CreatePowerBar(frame)
    local power = CreateFrame("StatusBar", nil, frame)
    power:SetMinMaxValues(0, 100)

    local bg = power:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetTexture("Interface\\Buttons\\WHITE8X8")
    power.bg = bg

    frame.Elements.PowerBar = power
    frame.power = power
end

-- Raid Target Icon
function UF:CreateRaidTargetIcon(frame)
    -- Use a dedicated overlay frame so the RTM can reliably sit above bars.
    -- A plain texture on the base frame can end up visually behind child
    -- frames like HealthBar/PowerBar when frame levels differ.
    local holder = CreateFrame("Frame", nil, frame)
    holder:SetAllPoints(frame)
    holder:SetFrameStrata(frame:GetFrameStrata())
    holder:SetFrameLevel(frame:GetFrameLevel() + 20)
    holder:Hide()

    local texture = holder:CreateTexture(nil, "OVERLAY", nil, 7)
    texture:SetTexture("Interface\\TargetingFrame\\UI-RaidTargetingIcons")
    texture:Hide()

    holder.Texture = texture
    frame.Elements.RaidTargetIcon = holder
    frame.RaidTargetIcon = holder
end

local function CreateOverlayIndicatorHolder(frame, elementKey)
    local holder = CreateFrame("Frame", nil, frame)
    holder:SetAllPoints(frame)
    holder:SetFrameStrata(frame:GetFrameStrata())
    holder:SetFrameLevel(frame:GetFrameLevel() + 20)
    holder:Hide()

    local texture = holder:CreateTexture(nil, "OVERLAY", nil, 7)
    texture:Hide()

    holder.Texture = texture
    frame.Elements[elementKey] = holder
    frame[elementKey] = holder
end

local function ApplyOverlayIndicatorConfig(owner, frame, holder, options)
    if not holder then
        return
    end

    local icon = holder.Texture or holder

    holder:ClearAllPoints()
    holder:SetScale(1)
    holder:SetFrameStrata(frame:GetFrameStrata())
    holder:SetFrameLevel(math.max(frame:GetFrameLevel() + 20, (frame.Elements.HealthBar and frame.Elements.HealthBar:GetFrameLevel() + 10) or (frame:GetFrameLevel() + 20)))
    icon:ClearAllPoints()
    icon:SetScale(1)

    if options.enabled then
        local effectiveSize = options.size * options.scale
        holder:SetSize(effectiveSize, effectiveSize)
        icon:SetAllPoints(holder)

        if options.placement == "INSIDE" then
            if options.insideSide == "LEFT" then
                holder:SetPoint("TOPLEFT", frame, "TOPLEFT", options.borderInset + options.padding, -(options.borderInset + options.padding))
            else
                holder:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -(options.borderInset + options.padding), -(options.borderInset + options.padding))
            end
        else
            local anchorParent = owner:GetAnchorTarget(frame, options.anchorTo) or frame
            holder:SetPoint(
                options.point,
                anchorParent,
                options.relativePoint,
                options.offsetX,
                options.offsetY
            )
        end

        options.updateFunc(frame)
    else
        icon:SetTexture(nil)
        icon:Hide()
        holder:Hide()
    end
end

function UF:CreateLeaderIcon(frame)
    CreateOverlayIndicatorHolder(frame, "LeaderIcon")
end

function UF:CreateRoleIcon(frame)
    CreateOverlayIndicatorHolder(frame, "RoleIcon")
end

function UF:CreateCombatIndicator(frame)
    CreateOverlayIndicatorHolder(frame, "CombatIndicator")
end

function UF:CreateRestingIndicator(frame)
    CreateOverlayIndicatorHolder(frame, "RestingIndicator")
end

function UF:CreateReadyCheckIndicator(frame)
    CreateOverlayIndicatorHolder(frame, "ReadyCheckIndicator")
end


function UF:UpdateRaidTargetIcon(frame)
    if not frame or not frame.Elements or not frame.Elements.RaidTargetIcon then
        return
    end

    local holder = frame.Elements.RaidTargetIcon
    local icon = holder.Texture or holder
    local config = frame.config
    local rtmConfig = config and config.RaidTargetIcon or nil

    if not rtmConfig or rtmConfig.enabled == false then
        icon:SetTexture(nil)
        icon:Hide()
        holder:Hide()
        return
    end

    local index = frame.unit and GetRaidTargetIndex and GetRaidTargetIndex(frame.unit) or nil

    if not index then
        icon:SetTexture(nil)
        icon:Hide()
        holder:Hide()
        return
    end

    icon:SetTexture("Interface\\TargetingFrame\\UI-RaidTargetingIcons")
    SetRaidTargetIconTexture(icon, index)
    holder:Show()
    icon:Show()
end

function UF:RegisterRaidTargetEvents(frame)
    if not frame or frame.RaidTargetEventFrame then
        return
    end

    local eventFrame = CreateFrame("Frame", nil, frame)
    eventFrame.owner = frame

    eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    eventFrame:RegisterEvent("RAID_TARGET_UPDATE")
    eventFrame:RegisterEvent("GROUP_ROSTER_UPDATE")
    eventFrame:RegisterEvent("UNIT_TARGET")

    if frame.unit == "target" then
        eventFrame:RegisterEvent("PLAYER_TARGET_CHANGED")
    elseif frame.unit == "focus" then
        eventFrame:RegisterEvent("PLAYER_FOCUS_CHANGED")
    elseif frame.unit == "pet" then
        eventFrame:RegisterEvent("UNIT_PET")
    end

    eventFrame:SetScript("OnEvent", function(_, event, unit)
        local owner = eventFrame.owner
        if not owner or not owner:IsShown() then
            return
        end

        if event == "UNIT_TARGET" then
            if owner.unit ~= "targettarget" and owner.unit ~= "focustarget" then
                return
            end

            local expectedUnit = owner.unit == "targettarget" and "target" or "focus"
            if unit ~= expectedUnit then
                return
            end
        elseif event == "UNIT_PET" and unit ~= "player" then
            return
        end

        C_Timer.After(0, function()
            if owner and owner:IsShown() then
                UF:UpdateRaidTargetIcon(owner)
            end
        end)
    end)

    frame.RaidTargetEventFrame = eventFrame
end

function UF:UpdateLeaderIcon(frame)
    if not frame or not frame.Elements or not frame.Elements.LeaderIcon then
        return
    end

    local holder = frame.Elements.LeaderIcon
    local icon = holder.Texture or holder
    local config = frame.config
    local leaderConfig = config and config.LeaderIcon or nil

    if not leaderConfig or leaderConfig.enabled == false then
        icon:SetTexture(nil)
        icon:Hide()
        holder:Hide()
        return
    end

    local isLeader = false

    if frame.unit and UnitExists and UnitExists(frame.unit) then
        if UnitLeadsAnyGroup then
            isLeader = UnitLeadsAnyGroup(frame.unit) and true or false
        elseif UnitIsGroupLeader then
            isLeader = UnitIsGroupLeader(frame.unit) and true or false
        end
    end

    if not isLeader then
        icon:SetTexture(nil)
        icon:Hide()
        holder:Hide()
        return
    end

    icon:SetAtlas("UI-HUD-UnitFrame-Player-Group-LeaderIcon", true)
    holder:Show()
    icon:Show()
end

function UF:RegisterLeaderIconEvents(frame)
    if not frame or frame.LeaderIconEventFrame then
        return
    end

    local eventFrame = CreateFrame("Frame", nil, frame)
    eventFrame.owner = frame

    eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    eventFrame:RegisterEvent("GROUP_ROSTER_UPDATE")
    eventFrame:RegisterEvent("PARTY_LEADER_CHANGED")
    eventFrame:RegisterEvent("PLAYER_ROLES_ASSIGNED")

    if frame.unit == "target" then
        eventFrame:RegisterEvent("PLAYER_TARGET_CHANGED")
    elseif frame.unit == "focus" then
        eventFrame:RegisterEvent("PLAYER_FOCUS_CHANGED")
    elseif frame.unit == "pet" then
        eventFrame:RegisterEvent("UNIT_PET")
    end

    eventFrame:SetScript("OnEvent", function(_, event, unit)
        local owner = eventFrame.owner
        if not owner or not owner:IsShown() then
            return
        end

        if event == "UNIT_PET" and unit ~= "player" then
            return
        end

        C_Timer.After(0, function()
            if owner and owner:IsShown() then
                UF:UpdateLeaderIcon(owner)
            end
        end)
    end)

    frame.LeaderIconEventFrame = eventFrame
end

function UF:UpdateRoleIcon(frame)
    if not frame or not frame.Elements or not frame.Elements.RoleIcon then
        return
    end

    local holder = frame.Elements.RoleIcon
    local icon = holder.Texture or holder
    local config = frame.config
    local roleConfig = config and config.RoleIcon or nil

    if not roleConfig or roleConfig.enabled == false then
        icon:SetTexture(nil)
        icon:Hide()
        holder:Hide()
        return
    end

    local role = frame.unit and UnitGroupRolesAssigned and UnitGroupRolesAssigned(frame.unit) or nil

    if role == "TANK" then
        icon:SetAtlas("UI-LFG-RoleIcon-Tank-Micro-Raid", true)
    elseif role == "HEALER" then
        icon:SetAtlas("UI-LFG-RoleIcon-Healer-Micro-Raid", true)
    elseif role == "DAMAGER" then
        icon:SetAtlas("UI-LFG-RoleIcon-DPS-Micro-Raid", true)
    else
        icon:SetTexture(nil)
        icon:Hide()
        holder:Hide()
        return
    end

    holder:Show()
    icon:Show()
end

function UF:RegisterRoleIconEvents(frame)
    if not frame or frame.RoleIconEventFrame then
        return
    end

    local eventFrame = CreateFrame("Frame", nil, frame)
    eventFrame.owner = frame

    eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    eventFrame:RegisterEvent("GROUP_ROSTER_UPDATE")
    eventFrame:RegisterEvent("PLAYER_ROLES_ASSIGNED")

    if frame.unit == "target" then
        eventFrame:RegisterEvent("PLAYER_TARGET_CHANGED")
    elseif frame.unit == "focus" then
        eventFrame:RegisterEvent("PLAYER_FOCUS_CHANGED")
    elseif frame.unit == "pet" then
        eventFrame:RegisterEvent("UNIT_PET")
    end

    eventFrame:SetScript("OnEvent", function(_, event, unit)
        local owner = eventFrame.owner
        if not owner or not owner:IsShown() then
            return
        end

        if event == "UNIT_PET" and unit ~= "player" then
            return
        end

        C_Timer.After(0, function()
            if owner and owner:IsShown() then
                UF:UpdateRoleIcon(owner)
            end
        end)
    end)

    frame.RoleIconEventFrame = eventFrame
end

function UF:UpdateCombatIndicator(frame)
    if not frame or not frame.Elements or not frame.Elements.CombatIndicator then
        return
    end

    local holder = frame.Elements.CombatIndicator
    local icon = holder.Texture or holder
    local config = frame.config
    local combatConfig = config and config.CombatIndicator or nil

    if not combatConfig or combatConfig.enabled == false then
        icon:SetTexture(nil)
        icon:Hide()
        holder:Hide()
        return
    end

    local inCombat = frame.unit and UnitAffectingCombat and UnitAffectingCombat(frame.unit) or false

    if not inCombat then
        icon:SetTexture(nil)
        icon:Hide()
        holder:Hide()
        return
    end

    icon:SetAtlas("UI-HUD-UnitFrame-Player-CombatIcon", true)
    holder:Show()
    icon:Show()
end

function UF:RegisterCombatIndicatorEvents(frame)
    if not frame or frame.CombatIndicatorEventFrame then
        return
    end

    local eventFrame = CreateFrame("Frame", nil, frame)
    eventFrame.owner = frame

    eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    eventFrame:RegisterEvent("UNIT_FLAGS")
    eventFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
    eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")

    if frame.unit == "target" then
        eventFrame:RegisterEvent("PLAYER_TARGET_CHANGED")
    elseif frame.unit == "focus" then
        eventFrame:RegisterEvent("PLAYER_FOCUS_CHANGED")
    elseif frame.unit == "pet" then
        eventFrame:RegisterEvent("UNIT_PET")
    end

    eventFrame:SetScript("OnEvent", function(_, event, unit)
        local owner = eventFrame.owner
        if not owner or not owner:IsShown() then
            return
        end

        if event == "UNIT_FLAGS" and unit ~= owner.unit then
            return
        end

        if event == "UNIT_PET" and unit ~= "player" then
            return
        end

        C_Timer.After(0, function()
            if owner and owner:IsShown() then
                UF:UpdateCombatIndicator(owner)
            end
        end)
    end)

    frame.CombatIndicatorEventFrame = eventFrame
end

function UF:UpdateRestingIndicator(frame)
    if not frame or not frame.Elements or not frame.Elements.RestingIndicator then
        return
    end

    local holder = frame.Elements.RestingIndicator
    local icon = holder.Texture or holder
    local config = frame.config
    local restingConfig = config and config.RestingIndicator or nil

    if not restingConfig or restingConfig.enabled == false then
        icon:SetTexture(nil)
        icon:Hide()
        holder:Hide()
        return
    end

    if frame.unit ~= "player" or not IsResting or not IsResting() then
        icon:SetTexture(nil)
        icon:Hide()
        holder:Hide()
        return
    end

    icon:SetTexture("Interface\\CharacterFrame\\UI-StateIcon")
    icon:SetTexCoord(0, 0.5, 0, 0.421875)
    holder:Show()
    icon:Show()
end

function UF:RegisterRestingIndicatorEvents(frame)
    if not frame or frame.RestingIndicatorEventFrame then
        return
    end

    local eventFrame = CreateFrame("Frame", nil, frame)
    eventFrame.owner = frame

    eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    eventFrame:RegisterEvent("PLAYER_UPDATE_RESTING")

    eventFrame:SetScript("OnEvent", function()
        local owner = eventFrame.owner
        if not owner or not owner:IsShown() then
            return
        end

        C_Timer.After(0, function()
            if owner and owner:IsShown() then
                UF:UpdateRestingIndicator(owner)
            end
        end)
    end)

    frame.RestingIndicatorEventFrame = eventFrame
end

function UF:UpdateReadyCheckIndicator(frame)
    if not frame or not frame.Elements or not frame.Elements.ReadyCheckIndicator then
        return
    end

    local holder = frame.Elements.ReadyCheckIndicator
    local icon = holder.Texture or holder
    local config = frame.config
    local readyCheckConfig = config and config.ReadyCheckIndicator or nil

    if not readyCheckConfig or readyCheckConfig.enabled == false then
        icon:SetTexture(nil)
        icon:Hide()
        holder:Hide()
        return
    end

    local status = frame.unit and GetReadyCheckStatus and GetReadyCheckStatus(frame.unit) or nil

    if status == "ready" then
        icon:SetTexture("Interface\\RaidFrame\\ReadyCheck-Ready")
    elseif status == "notready" then
        icon:SetTexture("Interface\\RaidFrame\\ReadyCheck-NotReady")
    elseif status == "waiting" then
        icon:SetTexture("Interface\\RaidFrame\\ReadyCheck-Waiting")
    else
        icon:SetTexture(nil)
        icon:Hide()
        holder:Hide()
        return
    end

    icon:SetTexCoord(0, 1, 0, 1)
    holder:Show()
    icon:Show()
end

function UF:RegisterReadyCheckIndicatorEvents(frame)
    if not frame or frame.ReadyCheckIndicatorEventFrame then
        return
    end

    local eventFrame = CreateFrame("Frame", nil, frame)
    eventFrame.owner = frame

    eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    eventFrame:RegisterEvent("READY_CHECK")
    eventFrame:RegisterEvent("READY_CHECK_CONFIRM")
    eventFrame:RegisterEvent("READY_CHECK_FINISHED")
    eventFrame:RegisterEvent("GROUP_ROSTER_UPDATE")

    if frame.unit == "target" then
        eventFrame:RegisterEvent("PLAYER_TARGET_CHANGED")
    elseif frame.unit == "focus" then
        eventFrame:RegisterEvent("PLAYER_FOCUS_CHANGED")
    elseif frame.unit == "pet" then
        eventFrame:RegisterEvent("UNIT_PET")
    end

    eventFrame:SetScript("OnEvent", function(_, event, unit)
        local owner = eventFrame.owner
        if not owner or not owner:IsShown() then
            return
        end

        if event == "UNIT_PET" and unit ~= "player" then
            return
        end

        C_Timer.After(0, function()
            if owner and owner:IsShown() then
                UF:UpdateReadyCheckIndicator(owner)
            end
        end)
    end)

    frame.ReadyCheckIndicatorEventFrame = eventFrame
end

-- Portrait
function UF:CreatePortrait(frame)
    local portraitHolder = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    portraitHolder:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
        insets = { left = 0, right = 0, top = 0, bottom = 0 },
    })

    local portraitTexture = portraitHolder:CreateTexture(nil, "ARTWORK")
    portraitTexture:SetAllPoints()
    portraitTexture:SetTexCoord(0.07, 0.93, 0.07, 0.93)

    portraitHolder.Texture = portraitTexture

    frame.Elements.Portrait = portraitHolder
    frame.Portrait = portraitHolder
end

function UF:UpdatePortraitTexture(frame)
    if not frame or not frame.Elements or not frame.Elements.Portrait then
        return
    end

    local portrait = frame.Elements.Portrait
    local texture = portrait.Texture
    local config = frame.config
    local portraitConfig = config and config.Portrait or nil

    if not texture then
        return
    end

    if not portraitConfig or portraitConfig.enabled == false then
        texture:SetTexture(nil)
        return
    end

    texture:SetTexCoord(0.07, 0.93, 0.07, 0.93)

    if frame.unit and UnitExists(frame.unit) then
        SetPortraitTexture(texture, frame.unit)
    else
        texture:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
    end

    texture:Show()
end

function UF:RegisterPortraitEvents(frame)
    if not frame or frame.PortraitEventFrame then
        return
    end

    local eventFrame = CreateFrame("Frame", nil, frame)
    eventFrame.owner = frame

    eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    eventFrame:RegisterEvent("PORTRAITS_UPDATED")
    eventFrame:RegisterEvent("UNIT_PORTRAIT_UPDATE")
    eventFrame:RegisterEvent("UNIT_MODEL_CHANGED")

    if frame.unit == "target" then
        eventFrame:RegisterEvent("PLAYER_TARGET_CHANGED")
    end

    eventFrame:SetScript("OnEvent", function(_, event, unit)
        local owner = eventFrame.owner
        if not owner or not owner:IsShown() then
            return
        end

        if event == "UNIT_PORTRAIT_UPDATE" or event == "UNIT_MODEL_CHANGED" then
            if unit ~= owner.unit then
                return
            end
        end

        C_Timer.After(0, function()
            if owner and owner:IsShown() then
                UF:UpdatePortraitTexture(owner)
            end
        end)
    end)

    frame.PortraitEventFrame = eventFrame
end

-- Texts
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

    local portraitConfig = config.Portrait or {}
    local raidTargetConfig = config.RaidTargetIcon or {}
    local leaderConfig = config.LeaderIcon or {}
    local roleConfig = config.RoleIcon or {}
    local combatConfig = config.CombatIndicator or {}
    local restingConfig = config.RestingIndicator or {}
    local readyCheckConfig = config.ReadyCheckIndicator or {}
    local portraitEnabled = portraitConfig.enabled and true or false
    local portraitPlacement = portraitConfig.placement or "INSIDE"
    local portraitMode = portraitConfig.mode or "2D"
    local portraitSize = tonumber(portraitConfig.size) or 40
    local portraitScale = tonumber(portraitConfig.scale) or 1
    local portraitPadding = tonumber(portraitConfig.padding) or 4
    local portraitInsideSide = portraitConfig.insideSide or "LEFT"

    local portraitPoint = portraitConfig.point or "RIGHT"
    local portraitRelativePoint = portraitConfig.relativePoint or "LEFT"
    local portraitOffsetX = tonumber(portraitConfig.offsetX) or -4
    local portraitOffsetY = tonumber(portraitConfig.offsetY) or 0
    local portraitAnchorTo = portraitConfig.anchorTo or "Frame"

    local portraitEffectiveSize = portraitEnabled and (portraitSize * portraitScale) or 0
    local portraitInside = portraitEnabled and portraitPlacement == "INSIDE"
    local portraitAttached = portraitEnabled and portraitPlacement == "ATTACHED"
    local portraitReservedSpace = portraitInside and (portraitEffectiveSize + portraitPadding) or 0

    -- Important: GUI uses fallback=true for new RTM configs. Treat a missing
    -- enabled flag as active as well, otherwise the UI can look enabled while
    -- the engine silently considers the element disabled on older profiles.
    local raidTargetEnabled = raidTargetConfig.enabled ~= false
    local raidTargetSize = tonumber(raidTargetConfig.size) or 18
    local raidTargetScale = tonumber(raidTargetConfig.scale) or 1
    local raidTargetPoint = raidTargetConfig.point or "TOP"
    local raidTargetRelativePoint = raidTargetConfig.relativePoint or "TOP"
    local raidTargetOffsetX = tonumber(raidTargetConfig.offsetX) or 0
    local raidTargetOffsetY = tonumber(raidTargetConfig.offsetY) or 8
    local raidTargetAnchorTo = raidTargetConfig.anchorTo or "Frame"

    local leaderEnabled = leaderConfig.enabled ~= false
    local leaderPlacement = leaderConfig.placement or "ATTACHED"
    local leaderSize = tonumber(leaderConfig.size) or 16
    local leaderScale = tonumber(leaderConfig.scale) or 1
    local leaderPadding = tonumber(leaderConfig.padding) or 2
    local leaderInsideSide = leaderConfig.insideSide or "LEFT"
    local leaderPoint = leaderConfig.point or "TOPLEFT"
    local leaderRelativePoint = leaderConfig.relativePoint or "TOP"
    local leaderOffsetX = tonumber(leaderConfig.offsetX) or 0
    local leaderOffsetY = tonumber(leaderConfig.offsetY) or 0
    local leaderAnchorTo = leaderConfig.anchorTo or "Frame"

    local roleEnabled = roleConfig.enabled ~= false
    local rolePlacement = roleConfig.placement or "ATTACHED"
    local roleSize = tonumber(roleConfig.size) or 16
    local roleScale = tonumber(roleConfig.scale) or 1
    local rolePadding = tonumber(roleConfig.padding) or 2
    local roleInsideSide = roleConfig.insideSide or "RIGHT"
    local rolePoint = roleConfig.point or "TOPRIGHT"
    local roleRelativePoint = roleConfig.relativePoint or "TOP"
    local roleOffsetX = tonumber(roleConfig.offsetX) or 0
    local roleOffsetY = tonumber(roleConfig.offsetY) or 0
    local roleAnchorTo = roleConfig.anchorTo or "Frame"

    local combatEnabled = combatConfig.enabled ~= false
    local combatPlacement = combatConfig.placement or "ATTACHED"
    local combatSize = tonumber(combatConfig.size) or 16
    local combatScale = tonumber(combatConfig.scale) or 1
    local combatPadding = tonumber(combatConfig.padding) or 2
    local combatInsideSide = combatConfig.insideSide or "RIGHT"
    local combatPoint = combatConfig.point or "TOP"
    local combatRelativePoint = combatConfig.relativePoint or "TOP"
    local combatOffsetX = tonumber(combatConfig.offsetX) or 0
    local combatOffsetY = tonumber(combatConfig.offsetY) or 0
    local combatAnchorTo = combatConfig.anchorTo or "Frame"

    local restingEnabled = restingConfig.enabled ~= false
    local restingPlacement = restingConfig.placement or "ATTACHED"
    local restingSize = tonumber(restingConfig.size) or 16
    local restingScale = tonumber(restingConfig.scale) or 1
    local restingPadding = tonumber(restingConfig.padding) or 2
    local restingInsideSide = restingConfig.insideSide or "LEFT"
    local restingPoint = restingConfig.point or "TOPLEFT"
    local restingRelativePoint = restingConfig.relativePoint or "TOP"
    local restingOffsetX = tonumber(restingConfig.offsetX) or 0
    local restingOffsetY = tonumber(restingConfig.offsetY) or 0
    local restingAnchorTo = restingConfig.anchorTo or "Frame"

    local readyCheckEnabled = readyCheckConfig.enabled ~= false
    local readyCheckPlacement = readyCheckConfig.placement or "ATTACHED"
    local readyCheckSize = tonumber(readyCheckConfig.size) or 16
    local readyCheckScale = tonumber(readyCheckConfig.scale) or 1
    local readyCheckPadding = tonumber(readyCheckConfig.padding) or 2
    local readyCheckInsideSide = readyCheckConfig.insideSide or "RIGHT"
    local readyCheckPoint = readyCheckConfig.point or "TOPRIGHT"
    local readyCheckRelativePoint = readyCheckConfig.relativePoint or "TOP"
    local readyCheckOffsetX = tonumber(readyCheckConfig.offsetX) or 0
    local readyCheckOffsetY = tonumber(readyCheckConfig.offsetY) or 0
    local readyCheckAnchorTo = readyCheckConfig.anchorTo or "Frame"

    local bgR, bgG, bgB, bgA = UnpackColor(config.backgroundColor, { 0.08, 0.08, 0.08, 0.9 })
    local borderR, borderG, borderB, borderA = UnpackColor(config.borderColor, { 0.2, 0.2, 0.2, 1 })
    local healthR, healthG, healthB, healthA = UnpackColor(config.healthColor, { 0.1, 0.8, 0.1, 1 })
    local powerR, powerG, powerB, powerA = UnpackColor(config.powerColor, { 0.2, 0.4, 0.9, 1 })

    local healthBackgroundEnabled = config.healthBackground ~= false
    local healthBgR, healthBgG, healthBgB, healthBgA = UnpackColor(config.healthBackgroundColor, { 0, 0, 0, 0.35 })
    local healthBackgroundShown = healthBackgroundEnabled and (healthBgA or 0) > 0.001

    local powerBackgroundEnabled = config.powerBackground ~= false
    local powerBgR, powerBgG, powerBgB, powerBgA = UnpackColor(config.powerBackgroundColor, { 0, 0, 0, 0.35 })
    local powerBackgroundShown = powerBackgroundEnabled and (powerBgA or 0) > 0.001

    if config.useClassColorHealth then
        local classR, classG, classB, classA = GetClassColorForUnit(frame.unit)
        if classR and classG and classB then
            healthR, healthG, healthB, healthA = classR, classG, classB, classA or 1
        end
    end

    if config.useClassColorPower then
        local resourceR, resourceG, resourceB, resourceA = GetPowerColorForUnit(frame.unit)
        if resourceR and resourceG and resourceB then
            powerR, powerG, powerB, powerA = resourceR, resourceG, resourceB, resourceA or 1
        end
    end

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

     -- HealthBar
    if frame.Elements.HealthBar then
        local health = frame.Elements.HealthBar
        health:ClearAllPoints()
        health:SetStatusBarTexture(texture)
        health:SetStatusBarColor(healthR, healthG, healthB, healthA)

        if health.bg then
            health.bg:SetTexture(texture)
            health.bg:SetVertexColor(healthBgR, healthBgG, healthBgB, healthBgA)
            health.bg:SetShown(healthBackgroundShown)
        end

        local healthLeftOffset = borderInset
        local healthRightOffset = -borderInset
        local healthBottomY = showPowerBar and (borderInset + powerBarHeight) or borderInset

        if portraitInside then
            if portraitInsideSide == "LEFT" then
                healthLeftOffset = borderInset + portraitReservedSpace
            elseif portraitInsideSide == "RIGHT" then
                healthRightOffset = -(borderInset + portraitReservedSpace)
            end
        end

        health:SetPoint("TOPLEFT", frame, "TOPLEFT", healthLeftOffset, -borderInset)
        health:SetPoint("TOPRIGHT", frame, "TOPRIGHT", healthRightOffset, -borderInset)
        health:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", healthLeftOffset, healthBottomY)
        health:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", healthRightOffset, healthBottomY)

        health:Show()
    end

    -- PowerBar
    if frame.Elements.PowerBar then
        local power = frame.Elements.PowerBar
        power:ClearAllPoints()
        power:SetStatusBarTexture(texture)
        power:SetStatusBarColor(powerR, powerG, powerB, powerA)

        if power.bg then
            power.bg:SetTexture(texture)
            power.bg:SetVertexColor(powerBgR, powerBgG, powerBgB, powerBgA)
            power.bg:SetShown(powerBackgroundShown and showPowerBar)
        end

        if showPowerBar then
            local powerLeftOffset = borderInset
            local powerRightOffset = -borderInset

            if portraitInside then
                if portraitInsideSide == "LEFT" then
                    powerLeftOffset = borderInset + portraitReservedSpace
                elseif portraitInsideSide == "RIGHT" then
                    powerRightOffset = -(borderInset + portraitReservedSpace)
                end
            end

            power:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", powerLeftOffset, borderInset)
            power:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", powerRightOffset, borderInset)
            power:SetHeight(powerBarHeight)
            power:Show()
        else
            if power.bg then
                power.bg:Hide()
            end
            power:Hide()
        end
    end

    -- Portrait
    if frame.Elements.Portrait then
        local portrait = frame.Elements.Portrait
        portrait:ClearAllPoints()
        portrait:SetScale(1)

        if portraitEnabled then
            portrait:SetBackdropColor(0.05, 0.05, 0.05, 0.9)
            portrait:SetBackdropBorderColor(borderR, borderG, borderB, borderA)
            portrait:SetSize(portraitEffectiveSize, portraitEffectiveSize)

            if portraitInside then
                if portraitInsideSide == "RIGHT" then
                    portrait:SetPoint("RIGHT", frame, "RIGHT", -borderInset, 0)
                else
                    portrait:SetPoint("LEFT", frame, "LEFT", borderInset, 0)
                end
            else
                local portraitAnchorParent = self:GetAnchorTarget(frame, portraitAnchorTo) or frame
                portrait:SetPoint(
                    portraitPoint,
                    portraitAnchorParent,
                    portraitRelativePoint,
                    portraitOffsetX,
                    portraitOffsetY
                )
            end

            self:UpdatePortraitTexture(frame)

            portrait:Show()
        else
            if portrait.Texture then
                portrait.Texture:SetTexture(nil)
            end
            portrait:Hide()
        end
    end

    -- Raid Target Icon
    if frame.Elements.RaidTargetIcon then
        local holder = frame.Elements.RaidTargetIcon
        local icon = holder.Texture or holder
        local raidTargetPlacement = raidTargetConfig.placement or "ATTACHED"
        local raidTargetPadding = tonumber(raidTargetConfig.padding) or 2
        local raidTargetInsideSide = raidTargetConfig.insideSide or "RIGHT"

        holder:ClearAllPoints()
        holder:SetScale(1)
        holder:SetFrameStrata(frame:GetFrameStrata())
        holder:SetFrameLevel(math.max(frame:GetFrameLevel() + 20, (frame.Elements.HealthBar and frame.Elements.HealthBar:GetFrameLevel() + 10) or (frame:GetFrameLevel() + 20)))
        icon:ClearAllPoints()
        icon:SetScale(1)

        if raidTargetEnabled then
            local effectiveSize = raidTargetSize * raidTargetScale
            holder:SetSize(effectiveSize, effectiveSize)
            icon:SetAllPoints(holder)

            if raidTargetPlacement == "INSIDE" then
                if raidTargetInsideSide == "LEFT" then
                    holder:SetPoint("TOPLEFT", frame, "TOPLEFT", borderInset + raidTargetPadding, -(borderInset + raidTargetPadding))
                else
                    holder:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -(borderInset + raidTargetPadding), -(borderInset + raidTargetPadding))
                end
            else
                local anchorParent = self:GetAnchorTarget(frame, raidTargetAnchorTo) or frame
                holder:SetPoint(
                    raidTargetPoint,
                    anchorParent,
                    raidTargetRelativePoint,
                    raidTargetOffsetX,
                    raidTargetOffsetY
                )
            end

            self:UpdateRaidTargetIcon(frame)
        else
            icon:SetTexture(nil)
            icon:Hide()
            holder:Hide()
        end
    end

    ApplyOverlayIndicatorConfig(self, frame, frame.Elements.LeaderIcon, {
        enabled = leaderEnabled,
        placement = leaderPlacement,
        size = leaderSize,
        scale = leaderScale,
        padding = leaderPadding,
        insideSide = leaderInsideSide,
        anchorTo = leaderAnchorTo,
        point = leaderPoint,
        relativePoint = leaderRelativePoint,
        offsetX = leaderOffsetX,
        offsetY = leaderOffsetY,
        borderInset = borderInset,
        updateFunc = function(targetFrame)
            self:UpdateLeaderIcon(targetFrame)
        end,
    })

    ApplyOverlayIndicatorConfig(self, frame, frame.Elements.RoleIcon, {
        enabled = roleEnabled,
        placement = rolePlacement,
        size = roleSize,
        scale = roleScale,
        padding = rolePadding,
        insideSide = roleInsideSide,
        anchorTo = roleAnchorTo,
        point = rolePoint,
        relativePoint = roleRelativePoint,
        offsetX = roleOffsetX,
        offsetY = roleOffsetY,
        borderInset = borderInset,
        updateFunc = function(targetFrame)
            self:UpdateRoleIcon(targetFrame)
        end,
    })

    ApplyOverlayIndicatorConfig(self, frame, frame.Elements.CombatIndicator, {
        enabled = combatEnabled,
        placement = combatPlacement,
        size = combatSize,
        scale = combatScale,
        padding = combatPadding,
        insideSide = combatInsideSide,
        anchorTo = combatAnchorTo,
        point = combatPoint,
        relativePoint = combatRelativePoint,
        offsetX = combatOffsetX,
        offsetY = combatOffsetY,
        borderInset = borderInset,
        updateFunc = function(targetFrame)
            self:UpdateCombatIndicator(targetFrame)
        end,
    })

    ApplyOverlayIndicatorConfig(self, frame, frame.Elements.RestingIndicator, {
        enabled = restingEnabled,
        placement = restingPlacement,
        size = restingSize,
        scale = restingScale,
        padding = restingPadding,
        insideSide = restingInsideSide,
        anchorTo = restingAnchorTo,
        point = restingPoint,
        relativePoint = restingRelativePoint,
        offsetX = restingOffsetX,
        offsetY = restingOffsetY,
        borderInset = borderInset,
        updateFunc = function(targetFrame)
            self:UpdateRestingIndicator(targetFrame)
        end,
    })

    ApplyOverlayIndicatorConfig(self, frame, frame.Elements.ReadyCheckIndicator, {
        enabled = readyCheckEnabled,
        placement = readyCheckPlacement,
        size = readyCheckSize,
        scale = readyCheckScale,
        padding = readyCheckPadding,
        insideSide = readyCheckInsideSide,
        anchorTo = readyCheckAnchorTo,
        point = readyCheckPoint,
        relativePoint = readyCheckRelativePoint,
        offsetX = readyCheckOffsetX,
        offsetY = readyCheckOffsetY,
        borderInset = borderInset,
        updateFunc = function(targetFrame)
            self:UpdateReadyCheckIndicator(targetFrame)
        end,
    })

    -- Texts
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
    self:CreatePortrait(frame)
    self:RegisterPortraitEvents(frame)
    self:CreateRaidTargetIcon(frame)
    self:RegisterRaidTargetEvents(frame)
    self:CreateLeaderIcon(frame)
    self:RegisterLeaderIconEvents(frame)
    self:CreateRoleIcon(frame)
    self:RegisterRoleIconEvents(frame)
    self:CreateCombatIndicator(frame)
    self:RegisterCombatIndicatorEvents(frame)
    self:CreateRestingIndicator(frame)
    self:RegisterRestingIndicatorEvents(frame)
    self:CreateReadyCheckIndicator(frame)
    self:RegisterReadyCheckIndicatorEvents(frame)
    self:CreateTextElements(frame)

    self:ApplyConfig(frame)
    self:ApplyTestValues(frame)

    frame:Show()
    self:ApplyConfig(frame)

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
