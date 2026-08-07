local _, FocalPoint = ...

FocalPoint.AuraContainer = FocalPoint.AuraContainer or {}
local AuraContainer = FocalPoint.AuraContainer
local State = FocalPoint.UnitFrameState or {}
local Demo = FocalPoint.UnitFrameDemoEnvironment or {}

-- Defines the inner aura widget: icon, swipe, stack text, and border.

local function IsTimedAura(aura)
    return type(aura) == "table" and aura.durationState == "TIMED"
end

local function ToPlainNumber(value)
    local ok, result = pcall(function()
        return tonumber(value)
    end)
    if ok and type(result) == "number" and not (issecretvalue and issecretvalue(result)) then
        return result
    end

    return nil
end

local function IsGreaterThan(value, threshold)
    local ok, result = pcall(function()
        return value > threshold
    end)
    if ok and type(result) == "boolean" then
        return result
    end

    local plain = ToPlainNumber(value)
    if type(plain) == "number" then
        return plain > threshold
    end

    return false
end

local function SetCooldownCountdownVisibility(container, shouldShow)
    if not container or not container.Cooldown then
        return
    end

    if container.Cooldown.SetHideCountdownNumbers then
        container.Cooldown:SetHideCountdownNumbers(not shouldShow)
    end

    if container.Cooldown.noCooldownCount ~= nil then
        container.Cooldown.noCooldownCount = not shouldShow
    end
end

local function GetAuraRemainingSeconds(aura)
    local expirationTime = ToPlainNumber(aura and aura.expirationTime)
    if not expirationTime then
        return nil
    end

    return math.max(expirationTime - ((GetTime and GetTime()) or 0), 0)
end

local function ApplyManagedEditorTimerSuffix(container, aura, isEnabled)
    if not container then
        return
    end

    if not isEnabled or not container.CooldownText then
        container:SetScript("OnUpdate", nil)
        return
    end

    container:SetScript("OnUpdate", function(self)
        local remaining = GetAuraRemainingSeconds(self.AuraData)
        if not remaining or remaining >= 60 then
            return
        end

        local text = self.CooldownText and self.CooldownText:GetText() or nil
        if type(text) == "string" and text:match("^%d+$") then
            self.CooldownText:SetText(text .. " s")
        end
    end)
end

function AuraContainer.Create(parent)
    local frame = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    frame:Hide()

    if frame.SetBackdrop then
        frame:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Buttons\\WHITE8X8",
            edgeSize = 1,
            insets = { left = 0, right = 0, top = 0, bottom = 0 },
        })
        frame:SetBackdropColor(0, 0, 0, 0.35)
        frame:SetBackdropBorderColor(0, 0, 0, 0.85)
    end

    local icon = frame:CreateTexture(nil, "ARTWORK")
    icon:SetAllPoints(frame)
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    frame.Icon = icon

    local cooldown = CreateFrame("Cooldown", nil, frame, "CooldownFrameTemplate")
    cooldown:SetAllPoints(frame)
    cooldown:SetDrawEdge(false)
    cooldown:SetDrawSwipe(true)
    if cooldown.SetReverse then
        cooldown:SetReverse(true)
    end
    if cooldown.SetHideCountdownNumbers then
        cooldown:SetHideCountdownNumbers(true)
    end
    cooldown.noCooldownCount = true
    cooldown:Hide()
    frame.Cooldown = cooldown
    if cooldown.GetCountdownFontString then
        frame.CooldownText = cooldown:GetCountdownFontString()
    end
    cooldown:SetScript("OnUpdate", nil)

    local textOverlay = CreateFrame("Frame", nil, frame)
    textOverlay:SetAllPoints(frame)
    textOverlay:SetFrameStrata(frame:GetFrameStrata())
    textOverlay:SetFrameLevel(frame:GetFrameLevel() + 10)
    textOverlay:EnableMouse(false)
    frame.TextOverlay = textOverlay

    local countText = textOverlay:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
    countText:SetPoint("BOTTOMRIGHT", textOverlay, "BOTTOMRIGHT", -1, 1)
    countText:SetJustifyH("RIGHT")
    countText:SetTextColor(1, 1, 1, 1)
    countText:SetShadowColor(0, 0, 0, 1)
    countText:SetShadowOffset(1.5, -1.5)
    countText:Hide()
    frame.CountText = countText

    return frame
end

function AuraContainer.ApplyLayout(container, config)
    if not container then
        return
    end

    local iconSize = math.max(tonumber(config and config.iconSize) or 30, 1)
    container:SetSize(iconSize, iconSize)

    if container.CountText then
        local stackFontScale = math.max(tonumber(config and config.stackFontScale) or 1, 0.5)
        local fontSize = math.max(math.floor((iconSize * 0.54 * stackFontScale) + 0.5), 10)
        container.CountText:SetFont(STANDARD_TEXT_FONT, fontSize, "OUTLINE")
        container.CountText:ClearAllPoints()
        if config and config._fpUseManagedVisuals == true then
            container.CountText:SetPoint("BOTTOMRIGHT", container, "BOTTOMRIGHT", 1, -1)
        else
            container.CountText:SetPoint("BOTTOMRIGHT", container, "BOTTOMRIGHT", -1, 1)
        end
        container.CountText:SetTextColor(1, 1, 1, 1)
        container.CountText:SetShadowColor(0, 0, 0, 1)
        container.CountText:SetShadowOffset(1.5, -1.5)
    end

    if container.CooldownText then
        local timerFontScale = math.max(tonumber(config and config.timerFontScale) or 1, 0.5)
        local fontSize = math.max(math.floor((iconSize * 0.34 * timerFontScale) + 0.5), 8)
        container.CooldownText:SetFont(STANDARD_TEXT_FONT, fontSize, "OUTLINE")
        container.CooldownText:SetTextColor(1, 1, 1, 1)
        container.CooldownText:SetShadowColor(0, 0, 0, 1)
        container.CooldownText:SetShadowOffset(1, -1)
        container.CooldownText:ClearAllPoints()
        container.CooldownText:SetPoint("TOP", container, "BOTTOM", 0, -1)
        container.CooldownText:SetJustifyH("CENTER")
        container.CooldownText:SetMaxLines(1)
    end
end

function AuraContainer.ApplyData(container, aura, config)
    if not container or type(aura) ~= "table" then
        return
    end

    AuraContainer.ApplyLayout(container, config)
    container.AuraData = aura
    container.BoundAuraInstanceId = aura.auraInstanceId or 0
    container.RenderState = "bound"

    if container.Icon then
        container.Icon:SetTexture(aura.icon)
        container.Icon:Show()
    end

    if container.CountText then
        local showStackText = config and config.showStackText
        if showStackText == nil and config and config._fpUseManagedVisuals == true then
            showStackText = true
        end
        if showStackText and IsGreaterThan(aura.count or 0, 1) then
            container.CountText:SetText(tostring(aura.count))
            container.CountText:Show()
        else
            container.CountText:SetText("")
            container.CountText:Hide()
        end
    end

    local cooldownActive = false
    local disableAuraTimers = Demo.IsAuraTimersDisabled and Demo.IsAuraTimersDisabled() and Demo.IsFrameInDemoMode and Demo.IsFrameInDemoMode(container:GetParent() and container:GetParent():GetParent() or nil)
    if container.Cooldown then
        if disableAuraTimers then
            if container.Cooldown.SetCooldown then
                container.Cooldown:SetCooldown(0, 0)
            end
            container.Cooldown:Hide()
            cooldownActive = false
        elseif aura.durationObject and container.Cooldown.SetCooldownFromDurationObject then
            local ok = pcall(container.Cooldown.SetCooldownFromDurationObject, container.Cooldown, aura.durationObject)
            if ok then
                container.Cooldown:Show()
                cooldownActive = true
            else
                container.Cooldown:Hide()
            end
        elseif IsTimedAura(aura) and IsGreaterThan(aura.duration or 0, 0) and IsGreaterThan(aura.expirationTime or 0, 0) then
            local duration = ToPlainNumber(aura.duration)
            local expirationTime = ToPlainNumber(aura.expirationTime)
            if duration and expirationTime then
                local startTime = expirationTime - duration
                container.Cooldown:SetCooldown(startTime, duration)
                container.Cooldown:Show()
                cooldownActive = true
            else
                container.Cooldown:Hide()
            end
        else
            if container.Cooldown.SetCooldown then
                container.Cooldown:SetCooldown(0, 0)
            end
            container.Cooldown:Hide()
        end
    end

    container:SetScript("OnUpdate", nil)
    if container.Cooldown then
        container.Cooldown:SetScript("OnUpdate", nil)
    end

    local showTimerText = config and config.showTimerText
    if showTimerText == nil then
        showTimerText = true
    end
    SetCooldownCountdownVisibility(container, showTimerText and cooldownActive)
    ApplyManagedEditorTimerSuffix(
        container,
        aura,
        config and config._fpUseManagedVisuals == true and showTimerText and cooldownActive
    )

    local ownerFrame = container:GetParent() and container:GetParent():GetParent() or nil
    if cooldownActive
        and Demo.IsDebugEnabled and Demo.IsDebugEnabled()
        and Demo.IsFrameInDemoMode and Demo.IsFrameInDemoMode(ownerFrame)
        and container.Cooldown
        and Demo.TouchDebug
    then
        container.Cooldown:SetScript("OnUpdate", function(self)
            Demo.TouchDebug(ownerFrame, "auraCooldownUpdates")
            local cooldownDuration = self.GetCooldownDuration and self:GetCooldownDuration() or nil
            if IsGreaterThan(cooldownDuration, 0) then
                Demo.TouchDebug(ownerFrame, "auraTimerTextUpdates")
            end
        end)
    end

    container:Show()

    if State.Guard then
        State.Guard(container:GetParent() and container:GetParent():GetParent() or nil, "aura_button_missing_id", aura.auraInstanceId ~= nil or aura.icon ~= nil, "rendered aura button without key/icon")
    end
end

function AuraContainer.Clear(container)
    if not container then
        return
    end

    if container.Icon then
        container.Icon:SetTexture(nil)
    end

    if container.Cooldown then
        if container.Cooldown.SetCooldown then
            container.Cooldown:SetCooldown(0, 0)
        end
        SetCooldownCountdownVisibility(container, false)
        container.Cooldown:SetScript("OnUpdate", nil)
        container.Cooldown:Hide()
    end

    if container.CountText then
        container.CountText:SetText("")
        container.CountText:Hide()
    end

    container:SetScript("OnUpdate", nil)
    container.AuraData = nil
    container.BoundAuraInstanceId = 0
    container.RenderState = "cleared"
    container:Hide()

    if State.Guard then
        local ownerFrame = container:GetParent() and container:GetParent():GetParent() or nil
        State.Guard(ownerFrame, "aura_button_cleared_state", (not container:IsShown()) and container.AuraData == nil and (container.BoundAuraInstanceId or 0) == 0, "button clear left stale state")
    end
end

AuraContainer.Reset = AuraContainer.Clear
