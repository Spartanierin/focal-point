local _, ns = ...

local AceGUI = LibStub and LibStub("AceGUI-3.0", true)
if not AceGUI then
    return
end

ns.GUI = ns.GUI or {}
ns.GUI.Editor = ns.GUI.Editor or {}
ns.GUI.Editor.MediaLibrary = ns.GUI.Editor.MediaLibrary or {}

local Type, Version = "FocalPointMediaPreview", 1
if (AceGUI:GetWidgetVersion(Type) or 0) >= Version then
    return
end

local L = ns.L or {}

local PREVIEW_HEIGHT = 112

local function T(key, fallback)
    return L[key] or fallback or key
end

local function IsNonEmptyString(value)
    return type(value) == "string" and value:gsub("^%s+", ""):gsub("%s+$", "") ~= ""
end

local methods = {}

function methods:OnAcquire()
    self:SetFullWidth(true)
    self:SetHeight(PREVIEW_HEIGHT)
    self:ClearPreview()
end

function methods:OnRelease()
    self.item = nil
    self.asset = nil
    self.fallbackUsed = nil
    if self.statusBar then
        pcall(self.statusBar.SetStatusBarTexture, self.statusBar, nil)
    end
    self:ClearPreview()
end

function methods:SetTitle(text)
    self.title:SetText(text or T("MEDIA_LIBRARY_PREVIEW", "Preview"))
end

function methods:ClearPreview(message)
    self.item = nil
    self.asset = nil
    self.fallbackUsed = nil
    self.title:SetText(T("MEDIA_LIBRARY_PREVIEW", "Preview"))
    self.statusText:SetText(message or T("MEDIA_LIBRARY_NO_PREVIEW_AVAILABLE", "No preview available"))
    self.statusBar:SetValue(70)
    self.statusBar:SetAlpha(1)
    self.statusBar:Hide()
    self.barBackground:Hide()
    self.container:SetBackdropBorderColor(0.24, 0.26, 0.30, 0.70)
end

function methods:SetNoPreview(message)
    self:ClearPreview(message or T("MEDIA_LIBRARY_NO_PREVIEW_AVAILABLE", "No preview available"))
end

function methods:SetStatusBarPreview(item, asset, fallbackUsed)
    self.item = item
    self.asset = asset
    self.fallbackUsed = fallbackUsed == true
    self.title:SetText(T("MEDIA_LIBRARY_PREVIEW", "Preview"))

    local applied = false
    if IsNonEmptyString(asset) then
        applied = pcall(self.statusBar.SetStatusBarTexture, self.statusBar, asset) == true
    end

    if not applied then
        self.statusBar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
        self.fallbackUsed = true
    end

    self.statusBar:SetMinMaxValues(0, 100)
    self.statusBar:SetValue(70)
    self.statusBar:SetStatusBarColor(0.72, 0.78, 0.86, 1.00)
    self.statusBar:SetAlpha(1)
    self.barBackground:Show()
    self.statusBar:Show()
    self.container:SetBackdropBorderColor(0.34, 0.36, 0.40, 0.86)

    if self.fallbackUsed then
        self.statusText:SetText(T("MEDIA_LIBRARY_FALLBACK_PREVIEW", "Fallback preview"))
    else
        self.statusText:SetText(T("MEDIA_LIBRARY_PREVIEW_STATUS_READY", "Preview ready"))
    end
end

local function Constructor()
    local frame = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
    frame:Hide()
    frame:SetHeight(PREVIEW_HEIGHT)

    local title = frame:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    title:SetPoint("TOPLEFT", frame, "TOPLEFT", 2, -2)
    title:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -2, -2)
    title:SetJustifyH("LEFT")

    local container = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    container:SetPoint("TOPLEFT", frame, "TOPLEFT", 10, -22)
    container:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -10, -22)
    container:SetHeight(64)
    container:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
    })
    container:SetBackdropColor(0.035, 0.040, 0.050, 0.96)
    container:SetBackdropBorderColor(0.24, 0.26, 0.30, 0.70)

    local barBackground = container:CreateTexture(nil, "BACKGROUND")
    barBackground:SetPoint("TOPLEFT", container, "TOPLEFT", 14, -16)
    barBackground:SetPoint("BOTTOMRIGHT", container, "BOTTOMRIGHT", -14, 16)
    barBackground:SetColorTexture(0.02, 0.025, 0.03, 0.95)

    local statusBar = CreateFrame("StatusBar", nil, container)
    statusBar:SetPoint("TOPLEFT", container, "TOPLEFT", 14, -16)
    statusBar:SetPoint("BOTTOMRIGHT", container, "BOTTOMRIGHT", -14, 16)
    statusBar:SetFrameLevel(container:GetFrameLevel() + 1)
    statusBar:SetMinMaxValues(0, 100)
    statusBar:SetValue(70)
    statusBar:SetStatusBarColor(0.72, 0.78, 0.86, 1.00)

    local statusText = frame:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    statusText:SetPoint("TOPLEFT", container, "BOTTOMLEFT", 0, -6)
    statusText:SetPoint("TOPRIGHT", container, "BOTTOMRIGHT", 0, -6)
    statusText:SetJustifyH("LEFT")

    local widget = {
        frame = frame,
        type = Type,
        title = title,
        container = container,
        barBackground = barBackground,
        statusBar = statusBar,
        statusText = statusText,
    }
    for method, func in pairs(methods) do
        widget[method] = func
    end

    return AceGUI:RegisterAsWidget(widget)
end

AceGUI:RegisterWidgetType(Type, Constructor, Version)
