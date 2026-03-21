local _, ns = ...

ns.GUI = ns.GUI or {}
ns.GUI.Preview = ns.GUI.Preview or {}

local ThemePreview = {}
ns.GUI.Preview.ThemePreview = ThemePreview

local SAMPLE_BUFF_ICONS = {
    "Interface\\Icons\\Ability_Warrior_BattleShout",
    "Interface\\Icons\\Ability_Warrior_InnerRage",
    "Interface\\Icons\\Ability_Warrior_ShieldWall",
    "Interface\\Icons\\INV_Sword_27",
}

local SAMPLE_DEBUFF_ICONS = {
    "Interface\\Icons\\Spell_Shadow_ShadowWordPain",
    "Interface\\Icons\\Ability_Creature_Cursed_03",
    "Interface\\Icons\\Spell_Frost_FrostNova",
}

local function UnpackColor(color, fallbackR, fallbackG, fallbackB, fallbackA)
    if type(color) ~= "table" then
        return fallbackR, fallbackG, fallbackB, fallbackA
    end

    local r = color.r or color[1] or fallbackR
    local g = color.g or color[2] or fallbackG
    local b = color.b or color[3] or fallbackB
    local a = color.a or color[4] or fallbackA
    return r, g, b, a
end

local function ApplySolidTexture(texture, color, fallbackR, fallbackG, fallbackB, fallbackA)
    if not texture then
        return
    end

    texture:SetTexture(WHITE8X8)
    texture:SetColorTexture(UnpackColor(color, fallbackR, fallbackG, fallbackB, fallbackA))
end

local function FormatAbbrev(value)
    local numeric = tonumber(value) or 0
    if numeric >= 1000000 then
        return string.format("%.1fm", numeric / 1000000)
    end
    if numeric >= 1000 then
        return string.format("%.0fk", numeric / 1000)
    end
    return tostring(math.floor(numeric + 0.5))
end

local function GetPreviewValues(unit)
    if ns.UnitFramePreview and ns.UnitFramePreview.GetTestValues then
        return ns.UnitFramePreview.GetTestValues({ unit = unit }) or {}
    end

    return {
        name = "Spartanierin",
        healthCurrent = 171000,
        healthMax = 191000,
        powerCurrent = 36,
        powerMax = 100,
    }
end

local function CreateBorder(frame)
    frame.BorderTop = frame:CreateTexture(nil, "BORDER")
    frame.BorderBottom = frame:CreateTexture(nil, "BORDER")
    frame.BorderLeft = frame:CreateTexture(nil, "BORDER")
    frame.BorderRight = frame:CreateTexture(nil, "BORDER")

    frame.BorderTop:SetPoint("TOPLEFT")
    frame.BorderTop:SetPoint("TOPRIGHT")
    frame.BorderTop:SetHeight(1)

    frame.BorderBottom:SetPoint("BOTTOMLEFT")
    frame.BorderBottom:SetPoint("BOTTOMRIGHT")
    frame.BorderBottom:SetHeight(1)

    frame.BorderLeft:SetPoint("TOPLEFT")
    frame.BorderLeft:SetPoint("BOTTOMLEFT")
    frame.BorderLeft:SetWidth(1)

    frame.BorderRight:SetPoint("TOPRIGHT")
    frame.BorderRight:SetPoint("BOTTOMRIGHT")
    frame.BorderRight:SetWidth(1)
end

local function ApplyBorderColor(frame, color, fallbackR, fallbackG, fallbackB, fallbackA)
    local r, g, b, a = UnpackColor(color, fallbackR, fallbackG, fallbackB, fallbackA)
    frame.BorderTop:SetColorTexture(r, g, b, a)
    frame.BorderBottom:SetColorTexture(r, g, b, a)
    frame.BorderLeft:SetColorTexture(r, g, b, a)
    frame.BorderRight:SetColorTexture(r, g, b, a)
end

local function EnsureAuraIcons(container, count)
    container.icons = container.icons or {}
    for index = 1, count do
        local icon = container.icons[index]
        if not icon then
            icon = CreateFrame("Frame", nil, container)
            icon.Texture = icon:CreateTexture(nil, "ARTWORK")
            icon.Texture:SetAllPoints()

            icon.Shade = icon:CreateTexture(nil, "BACKGROUND")
            icon.Shade:SetAllPoints()
            icon.Shade:SetColorTexture(0, 0, 0, 0.22)

            icon.Border = icon:CreateTexture(nil, "OVERLAY")
            icon.Border:SetPoint("TOPLEFT", -1, 1)
            icon.Border:SetPoint("BOTTOMRIGHT", 1, -1)
            icon.Border:SetTexture(WHITE8X8)
            icon.Border:SetColorTexture(0, 0, 0, 0.65)

            icon.Stack = icon:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            icon.Stack:SetPoint("TOPLEFT", 2, -1)
            icon.Stack:SetJustifyH("LEFT")

            icon.Timer = icon:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            icon.Timer:SetPoint("TOP", icon, "BOTTOM", 0, -1)
            icon.Timer:SetJustifyH("CENTER")

            icon.Timer:SetShadowOffset(1, -1)
            icon.Stack:SetShadowOffset(1, -1)
            icon.Timer:SetShadowColor(0, 0, 0, 0.9)
            icon.Stack:SetShadowColor(0, 0, 0, 0.9)

            container.icons[index] = icon
        end
    end
end

local function HideAuraIcons(container)
    if not container or not container.icons then
        return
    end

    for _, icon in ipairs(container.icons) do
        icon:Hide()
    end
end

local function SetTextAnchor(fontString, slotConfig, anchors, fallbackAnchor, fallbackPoint, fallbackRelativePoint, fallbackX, fallbackY)
    local config = type(slotConfig) == "table" and slotConfig or {}
    local anchorFrame = anchors[config.anchorTo] or fallbackAnchor
    local point = config.point or fallbackPoint
    local relativePoint = config.relativePoint or fallbackRelativePoint or point
    local offsetX = tonumber(config.offsetX) or fallbackX or 0
    local offsetY = tonumber(config.offsetY) or fallbackY or 0

    fontString:ClearAllPoints()
    fontString:SetPoint(point, anchorFrame, relativePoint, offsetX, offsetY)
end

local function CreateController(root)
    local controller = {
        root = root,
        currentThemeId = nil,
        currentConfig = nil,
    }

    local stage = CreateFrame("Frame", nil, root)
    stage:SetAllPoints()
    controller.stage = stage

    local shell = CreateFrame("Frame", nil, stage)
    shell:SetPoint("CENTER", 0, -10)
    shell.Background = shell:CreateTexture(nil, "BACKGROUND")
    shell.Background:SetAllPoints()
    shell.Background:SetColorTexture(0.03, 0.04, 0.05, 0.55)
    CreateBorder(shell)
    ApplyBorderColor(shell, nil, 0.14, 0.16, 0.18, 0.9)
    controller.shell = shell

    local unit = CreateFrame("Frame", nil, shell)
    unit.Background = unit:CreateTexture(nil, "BACKGROUND")
    unit.Background:SetAllPoints()
    CreateBorder(unit)

    unit.Health = CreateFrame("StatusBar", nil, unit)
    unit.Health.Background = unit.Health:CreateTexture(nil, "BACKGROUND")
    unit.Health.Background:SetAllPoints()

    unit.Power = CreateFrame("StatusBar", nil, unit)
    unit.Power.Background = unit.Power:CreateTexture(nil, "BACKGROUND")
    unit.Power.Background:SetAllPoints()

    unit.Portrait = CreateFrame("Frame", nil, unit)
    unit.Portrait.Background = unit.Portrait:CreateTexture(nil, "BACKGROUND")
    unit.Portrait.Background:SetAllPoints()
    unit.Portrait.Highlight = unit.Portrait:CreateTexture(nil, "ARTWORK")
    unit.Portrait.Highlight:SetPoint("TOPLEFT", 4, -4)
    unit.Portrait.Highlight:SetPoint("BOTTOMRIGHT", -4, 4)

    unit.Name = unit:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    unit.Name:SetShadowOffset(1, -1)
    unit.Name:SetShadowColor(0, 0, 0, 0.9)

    unit.HealthText = unit:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    unit.HealthText:SetShadowOffset(1, -1)
    unit.HealthText:SetShadowColor(0, 0, 0, 0.9)

    unit.PowerText = unit:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    unit.PowerText:SetShadowOffset(1, -1)
    unit.PowerText:SetShadowColor(0, 0, 0, 0.9)

    unit.Buffs = CreateFrame("Frame", nil, unit)
    unit.Debuffs = CreateFrame("Frame", nil, unit)

    controller.unit = unit

    local function LayoutAuras(container, auraConfig, icons, side)
        HideAuraIcons(container)

        if type(auraConfig) ~= "table" or auraConfig.enabled == false then
            container:Hide()
            return
        end

        container:Show()

        local iconCount = math.min(#icons, tonumber(auraConfig.iconsPerRow) or #icons)
        if iconCount < 1 then
            container:Hide()
            return
        end

        EnsureAuraIcons(container, iconCount)

        local iconSize = tonumber(auraConfig.iconSize) or 22
        local spacing = tonumber(auraConfig.spacingX) or 3
        local timerScale = tonumber(auraConfig.timerFontScale) or 1
        local stackScale = tonumber(auraConfig.stackFontScale) or 1

        local totalWidth = (iconSize * iconCount) + (spacing * math.max(0, iconCount - 1))
        local timerOffset = auraConfig.showTimerText == false and 0 or math.floor(9 * timerScale)

        container:ClearAllPoints()
        container:SetSize(totalWidth, iconSize + timerOffset)
        if side == "LEFT" then
            container:SetPoint("BOTTOMLEFT", unit, "TOPLEFT", 0, 8)
        else
            container:SetPoint("BOTTOMRIGHT", unit, "TOPRIGHT", 0, 8)
        end

        for index = 1, iconCount do
            local icon = container.icons[index]
            icon:SetSize(iconSize, iconSize)
            icon:ClearAllPoints()
            if side == "LEFT" then
                icon:SetPoint("TOPLEFT", (index - 1) * (iconSize + spacing), 0)
            else
                icon:SetPoint("TOPRIGHT", -((index - 1) * (iconSize + spacing)), 0)
            end

            icon.Texture:SetTexture(icons[index])
            icon.Stack:SetFont(STANDARD_TEXT_FONT, math.max(9, math.floor(10 * stackScale)), "OUTLINE")
            icon.Timer:SetFont(STANDARD_TEXT_FONT, math.max(8, math.floor(10 * timerScale)), "OUTLINE")
            icon.Stack:SetText(auraConfig.showStackText == false and "" or (index == 2 and "2" or ""))
            icon.Timer:SetText(auraConfig.showTimerText == false and "" or (index == 1 and "24s" or index == 2 and "8.6" or "1m"))
            icon:Show()
        end
    end

    local function ApplyText(fontString, slotConfig, sampleText, defaultAnchor, defaultPoint, defaultRelativePoint, defaultX, defaultY)
        if type(slotConfig) == "table" and slotConfig.enabled == false then
            fontString:Hide()
            return
        end

        fontString:Show()
        fontString:SetText(sampleText or "")
        fontString:SetFont(STANDARD_TEXT_FONT, math.max(10, tonumber(slotConfig and slotConfig.fontSize) or 12), "")
        SetTextAnchor(
            fontString,
            slotConfig,
            {
                Frame = unit,
                HealthBar = unit.Health,
                PowerBar = unit.Power:IsShown() and unit.Power or unit.Health,
            },
            defaultAnchor,
            defaultPoint,
            defaultRelativePoint,
            defaultX,
            defaultY
        )
    end

    function controller:SetTheme(themeId)
        self.currentThemeId = themeId
        self.currentConfig = ns.ThemeService and ns.ThemeService.BuildPreviewUnitConfig and ns.ThemeService.BuildPreviewUnitConfig(themeId, "player") or nil
        self:Refresh()
    end

    function controller:Refresh()
        local config = self.currentConfig
        local values = GetPreviewValues("player")
        if type(config) ~= "table" then
            self.unit:Hide()
            return
        end

        self.unit:Show()

        local rootWidth = math.max(0, self.root:GetWidth() or 0)
        local rootHeight = math.max(0, self.root:GetHeight() or 0)
        local shellWidth = math.max(260, math.min(rootWidth - 18, 420))
        local shellHeight = math.max(160, math.min(rootHeight - 12, 220))
        self.shell:SetSize(shellWidth, shellHeight)

        local frameWidth = tonumber(config.width) or 260
        local frameHeight = tonumber(config.height) or 60
        local availableWidth = shellWidth - 34
        local availableHeight = shellHeight - 60
        local previewScale = math.min(1, availableWidth / frameWidth, availableHeight / (frameHeight + 40))
        previewScale = math.max(0.55, previewScale)

        self.unit:ClearAllPoints()
        self.unit:SetPoint("CENTER", self.shell, "CENTER", 0, -10)
        self.unit:SetScale(previewScale * (tonumber(config.scale) or 1))
        self.unit:SetAlpha(tonumber(config.alpha) or 1)
        self.unit:SetSize(frameWidth, frameHeight)

        ApplySolidTexture(self.unit.Background, config.backgroundColor, 0.08, 0.08, 0.08, 0.28)
        ApplyBorderColor(self.unit, config.borderColor, 0, 0, 0, 0)

        local powerVisible = config.showPowerBar ~= false
        local powerHeight = powerVisible and math.max(8, tonumber(config.powerBarHeight) or 12) or 0
        local portraitConfig = config.Portrait or {}
        local portraitEnabled = portraitConfig.enabled == true
        local portraitInside = portraitEnabled and portraitConfig.placement == "INSIDE"
        local portraitSize = portraitEnabled and math.max(20, tonumber(portraitConfig.size) or frameHeight) or 0
        local portraitSide = portraitConfig.insideSide == "RIGHT" and "RIGHT" or "LEFT"

        local insetLeft = portraitInside and portraitSide == "LEFT" and (portraitSize + 6) or 0
        local insetRight = portraitInside and portraitSide == "RIGHT" and (portraitSize + 6) or 0

        if portraitEnabled then
            self.unit.Portrait:Show()
            self.unit.Portrait:SetSize(portraitSize, portraitSize)
            self.unit.Portrait:ClearAllPoints()

            if portraitInside then
                local point = portraitSide == "RIGHT" and "TOPRIGHT" or "TOPLEFT"
                local xOffset = portraitSide == "RIGHT" and -3 or 3
                self.unit.Portrait:SetPoint(point, self.unit, point, xOffset, -3)
            else
                local point = portraitSide == "RIGHT" and "LEFT" or "RIGHT"
                local relativePoint = portraitSide == "RIGHT" and "RIGHT" or "LEFT"
                local xOffset = portraitSide == "RIGHT" and 6 or -6
                self.unit.Portrait:SetPoint(point, self.unit, relativePoint, xOffset, 0)
            end

            ApplySolidTexture(self.unit.Portrait.Background, { 0.09, 0.09, 0.11, 0.95 }, 0.09, 0.09, 0.11, 0.95)
            self.unit.Portrait.Highlight:SetTexture("Interface\\Icons\\Achievement_Character_Human_Female")
            self.unit.Portrait.Highlight:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        else
            self.unit.Portrait:Hide()
        end

        self.unit.Health:ClearAllPoints()
        self.unit.Health:SetPoint("TOPLEFT", self.unit, "TOPLEFT", insetLeft, 0)
        self.unit.Health:SetPoint("TOPRIGHT", self.unit, "TOPRIGHT", -insetRight, 0)
        self.unit.Health:SetStatusBarTexture(config.healthBarTexture or "Interface\\TargetingFrame\\UI-StatusBar")
        self.unit.Health:SetMinMaxValues(0, values.healthMax or 100)
        self.unit.Health:SetValue(values.healthCurrent or values.healthMax or 100)
        self.unit.Health:SetHeight(powerVisible and math.max(12, frameHeight - powerHeight) or frameHeight)
        self.unit.Health.Background:SetTexture(WHITE8X8)
        self.unit.Health.Background:SetColorTexture(UnpackColor(config.healthBackgroundColor, 0, 0, 0, 0.55))
        self.unit.Health:SetStatusBarColor(UnpackColor(config.healthColor, 0.19, 0.80, 0.77, 0.8))

        if powerVisible then
            self.unit.Power:Show()
            self.unit.Power:ClearAllPoints()
            self.unit.Power:SetPoint("BOTTOMLEFT", self.unit, "BOTTOMLEFT", insetLeft, 0)
            self.unit.Power:SetPoint("BOTTOMRIGHT", self.unit, "BOTTOMRIGHT", -insetRight, 0)
            self.unit.Power:SetHeight(powerHeight)
            self.unit.Power:SetStatusBarTexture(config.powerBarTexture or "Interface\\TargetingFrame\\UI-StatusBar")
            self.unit.Power:SetMinMaxValues(0, values.powerMax or 100)
            self.unit.Power:SetValue(values.powerCurrent or 0)
            self.unit.Power.Background:SetTexture(WHITE8X8)
            self.unit.Power.Background:SetColorTexture(UnpackColor(config.powerBackgroundColor, 0, 0, 0, 0.35))
            self.unit.Power:SetStatusBarColor(UnpackColor(config.powerColor, 0.76, 0.12, 0.10, 0.8))
        else
            self.unit.Power:Hide()
        end

        local healthText = string.format("%s/%s || %d%%", FormatAbbrev(values.healthCurrent), FormatAbbrev(values.healthMax), math.floor(((values.healthCurrent or 0) / math.max(1, values.healthMax or 1)) * 100 + 0.5))
        local powerText = string.format("%s/%s", values.powerCurrent or 0, values.powerMax or 100)

        ApplyText(self.unit.Name, config.Texts and config.Texts.Name, values.name or "Spartanierin", self.unit, "TOPLEFT", "TOPLEFT", 4, 14)
        ApplyText(self.unit.HealthText, config.Texts and config.Texts.Health, healthText, self.unit.Health, "LEFT", "LEFT", 4, 0)
        ApplyText(self.unit.PowerText, config.Texts and config.Texts.Power, powerText, self.unit.Power:IsShown() and self.unit.Power or self.unit.Health, "LEFT", "LEFT", 4, 0)

        LayoutAuras(self.unit.Buffs, config.Buffs or {}, SAMPLE_BUFF_ICONS, "LEFT")
        LayoutAuras(self.unit.Debuffs, config.Debuffs or {}, SAMPLE_DEBUFF_ICONS, "RIGHT")
    end

    root:SetScript("OnSizeChanged", function()
        controller:Refresh()
    end)

    function controller:Release()
        if self.root then
            self.root:Hide()
            self.root:SetParent(UIParent)
            self.root:ClearAllPoints()
        end
    end

    return controller
end

function ThemePreview.Attach(host, themeId)
    if not host or not host.content then
        return nil
    end

    if host._themePreviewController and host._themePreviewController.Release then
        host._themePreviewController:Release()
    end

    local root = CreateFrame("Frame", nil, host.content)
    root:SetAllPoints(host.content)

    local controller = CreateController(root)
    host._themePreviewController = controller

    if host.SetCallback then
        host:SetCallback("OnRelease", function(widget)
            if widget and widget._themePreviewController and widget._themePreviewController.Release then
                widget._themePreviewController:Release()
                widget._themePreviewController = nil
            end
        end)
    end

    if host.frame and not host.frame._focalPointThemePreviewHooked then
        host.frame:HookScript("OnHide", function(frame)
            local widget = frame and frame.obj
            if widget and widget._themePreviewController and widget._themePreviewController.Release then
                widget._themePreviewController:Release()
            end
        end)
        host.frame._focalPointThemePreviewHooked = true
    end

    if themeId then
        controller:SetTheme(themeId)
    else
        controller:Refresh()
    end

    return controller
end

return ThemePreview
