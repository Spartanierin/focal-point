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
local PREVIEW_FONT_SIZE = 20

local function T(key, fallback)
    return L[key] or fallback or key
end

local function IsNonEmptyString(value)
    return type(value) == "string" and value:gsub("^%s+", ""):gsub("%s+$", "") ~= ""
end

local methods = {}

local function TryApplyFont(fontString, fontPath, fontSize, fontFlags)
    if not fontString or not IsNonEmptyString(fontPath) then
        return false, false, false
    end

    local ok, applied = pcall(fontString.SetFont, fontString, fontPath, fontSize or PREVIEW_FONT_SIZE, fontFlags)
    return ok == true and applied ~= false, ok == true, applied == true
end

local function GetStringWidth(fontString)
    if not (fontString and fontString.GetStringWidth) then
        return 0
    end

    local ok, width = pcall(fontString.GetStringWidth, fontString)
    if ok and type(width) == "number" then
        return width
    end

    return 0
end

local function GetStringHeight(fontString)
    if not (fontString and fontString.GetStringHeight) then
        return 0
    end

    local ok, height = pcall(fontString.GetStringHeight, fontString)
    if ok and type(height) == "number" then
        return height
    end

    return 0
end

local function GetRegionWidth(region)
    if not (region and region.GetWidth) then
        return 0
    end

    local ok, width = pcall(region.GetWidth, region)
    if ok and type(width) == "number" then
        return width
    end

    return 0
end

local function GetRegionHeight(region)
    if not (region and region.GetHeight) then
        return 0
    end

    local ok, height = pcall(region.GetHeight, region)
    if ok and type(height) == "number" then
        return height
    end

    return 0
end

local function IsRegionShown(region)
    if not (region and region.IsShown) then
        return false
    end

    local ok, shown = pcall(region.IsShown, region)
    return ok == true and shown == true
end

local function GetFontPath(fontString)
    if not (fontString and fontString.GetFont) then
        return nil
    end

    local ok, fontPath = pcall(fontString.GetFont, fontString)
    if ok and type(fontPath) == "string" then
        return fontPath
    end

    return nil
end

local function GetText(fontString)
    if not (fontString and fontString.GetText) then
        return nil
    end

    local ok, text = pcall(fontString.GetText, fontString)
    if ok then
        return text
    end

    return nil
end

local function GetRegionAlpha(region)
    if not (region and region.GetAlpha) then
        return nil
    end

    local ok, alpha = pcall(region.GetAlpha, region)
    if ok and type(alpha) == "number" then
        return alpha
    end

    return nil
end

local function GetEffectiveAlpha(region)
    if not (region and region.GetEffectiveAlpha) then
        return nil
    end

    local ok, alpha = pcall(region.GetEffectiveAlpha, region)
    if ok and type(alpha) == "number" then
        return alpha
    end

    return nil
end

local function IsRegionVisible(region)
    if not (region and region.IsVisible) then
        return false
    end

    local ok, visible = pcall(region.IsVisible, region)
    return ok == true and visible == true
end

local function GetTextColor(fontString)
    if not (fontString and fontString.GetTextColor) then
        return nil, nil, nil, nil
    end

    local ok, r, g, b, a = pcall(fontString.GetTextColor, fontString)
    if ok then
        return r, g, b, a
    end

    return nil, nil, nil, nil
end

local function GetClipsChildren(frame)
    if not (frame and frame.GetClipsChildren) then
        return nil
    end

    local ok, clips = pcall(frame.GetClipsChildren, frame)
    if ok then
        return clips == true
    end

    return nil
end

local function GetFrameLevel(frame)
    if not (frame and frame.GetFrameLevel) then
        return nil
    end

    local ok, level = pcall(frame.GetFrameLevel, frame)
    if ok and type(level) == "number" then
        return level
    end

    return nil
end

local function GetFrameStrata(frame)
    if not (frame and frame.GetFrameStrata) then
        return nil
    end

    local ok, strata = pcall(frame.GetFrameStrata, frame)
    if ok then
        return strata
    end

    return nil
end

local function RefreshFontPreviewText(fontString, sampleText)
    if not fontString then
        return false
    end

    fontString:SetText("")
    fontString:SetText(sampleText or "")
    return true
end

local function PublishFontPreviewDiagnostics(self)
    local Preview = ns.GUI
        and ns.GUI.Editor
        and ns.GUI.Editor.MediaLibrary
        and ns.GUI.Editor.MediaLibrary.MediaLibraryPreview
    if Preview then
        Preview.lastPreviewDiagnostics = self.lastFontPreviewDiagnostics
    end
end

local function UpdateFontPreviewDiagnostics(self, detail)
    if type(detail) ~= "table" then
        return
    end

    detail.widgetShown = IsRegionShown(self.frame)
    detail.widgetWidth = GetRegionWidth(self.frame)
    detail.widgetHeight = GetRegionHeight(self.frame)
    detail.fontContainerShown = IsRegionShown(self.fontContainer)
    detail.fontContainerWidth = GetRegionWidth(self.fontContainer)
    detail.fontContainerHeight = GetRegionHeight(self.fontContainer)
    detail.fontStringShown = IsRegionShown(self.fontText)
    detail.fontStringWidth = GetStringWidth(self.fontText)
    detail.fontStringHeight = GetStringHeight(self.fontText)
    detail.fontAfterSetFont = GetFontPath(self.fontText)
    detail.textAfter = GetText(self.fontText)
    detail.fontObjectSame = detail.fontBeforeSetFont ~= nil and detail.fontBeforeSetFont == detail.fontAfterSetFont
    detail.textWasIdentical = detail.textBefore ~= nil and detail.textBefore == detail.textAfter
    detail.isVisible = IsRegionVisible(self.fontText)
    detail.alpha = GetRegionAlpha(self.fontText)
    detail.effectiveAlpha = GetEffectiveAlpha(self.fontText)
    local r, g, b, a = GetTextColor(self.fontText)
    detail.textColorR = r
    detail.textColorG = g
    detail.textColorB = b
    detail.textColorA = a
    detail.containerClipsChildren = GetClipsChildren(self.fontContainer)
    detail.widgetFrameLevel = GetFrameLevel(self.frame)
    detail.containerFrameLevel = GetFrameLevel(self.fontContainer)
    detail.widgetFrameStrata = GetFrameStrata(self.frame)

    self.lastFontPreviewDiagnostics = detail
    PublishFontPreviewDiagnostics(self)
end

local function HideStatusBarPreview(self)
    self.statusBar:Hide()
    self.barBackground:Hide()
    self.statusBarContainer:Hide()
end

local function HideFontPreview(self)
    self.fontText:SetText("")
    self.fontText:Hide()
    self.fontContainer:Hide()
end

local function HideArtworkPreview(self)
    self.artworkTexture:SetTexture(nil)
    self.artworkTexture:Hide()
    self.artworkContainer:Hide()
end

function methods:OnAcquire()
    self.previewGeneration = (self.previewGeneration or 0) + 1
    self:SetFullWidth(true)
    self:SetHeight(PREVIEW_HEIGHT)
    self:ClearPreview()
end

function methods:OnRelease()
    self.previewGeneration = (self.previewGeneration or 0) + 1
    self.item = nil
    self.asset = nil
    self.fallbackUsed = nil
    self.lastFontPreviewDiagnostics = nil
    if self.statusBar then
        pcall(self.statusBar.SetStatusBarTexture, self.statusBar, nil)
    end
    if self.fontText then
        TryApplyFont(self.fontText, STANDARD_TEXT_FONT, PREVIEW_FONT_SIZE, nil)
    end
    if self.artworkTexture then
        pcall(self.artworkTexture.SetTexture, self.artworkTexture, nil)
    end
    self:ClearPreview()
end

function methods:SetTitle(text)
    self.title:SetText(text or T("MEDIA_LIBRARY_PREVIEW", "Preview"))
end

function methods:ClearPreview(message)
    self.previewGeneration = (self.previewGeneration or 0) + 1
    self.item = nil
    self.asset = nil
    self.fallbackUsed = nil
    self.lastFontPreviewDiagnostics = nil
    self.title:SetText(T("MEDIA_LIBRARY_PREVIEW", "Preview"))
    self.statusText:SetText(message or T("MEDIA_LIBRARY_NO_PREVIEW_AVAILABLE", "No preview available"))
    self.statusBar:SetValue(70)
    self.statusBar:SetAlpha(1)
    HideStatusBarPreview(self)
    HideFontPreview(self)
    HideArtworkPreview(self)
end

function methods:SetNoPreview(message)
    self:ClearPreview(message or T("MEDIA_LIBRARY_NO_PREVIEW_AVAILABLE", "No preview available"))
end

function methods:SetStatusBarPreview(item, asset, fallbackUsed)
    self.previewGeneration = (self.previewGeneration or 0) + 1
    self.item = item
    self.asset = asset
    self.fallbackUsed = fallbackUsed == true
    self.lastFontPreviewDiagnostics = nil
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
    self.statusBarContainer:SetBackdropBorderColor(0.34, 0.36, 0.40, 0.86)
    self.statusBarContainer:Show()
    HideFontPreview(self)
    HideArtworkPreview(self)

    if self.fallbackUsed then
        self.statusText:SetText(T("MEDIA_LIBRARY_FALLBACK_PREVIEW", "Fallback preview"))
    else
        self.statusText:SetText(T("MEDIA_LIBRARY_PREVIEW_STATUS_READY", "Preview ready"))
    end
end

local function FinalizeFontPreview(self, generation, detail, sampleText, fontPath, fontSize, fontFlags, retryNeeded)
    if generation ~= self.previewGeneration or self.item ~= detail.item then
        return
    end

    detail.retryStillCurrent = true
    local finalSucceeded = detail.primarySucceeded == true

    if retryNeeded then
        detail.attempt = 2
        detail.retryExecuted = true
        self.fontText:SetText("")
        local retriedSucceeded, retryPcallOk, retryApplied = TryApplyFont(self.fontText, fontPath, fontSize, fontFlags)
        detail.refreshExecuted = RefreshFontPreviewText(self.fontText, sampleText)
        finalSucceeded = retriedSucceeded == true
        detail.pcallOk = retryPcallOk == true
        detail.setFontApplied = retryApplied == true
        detail.retryPcallOk = retryPcallOk == true
        detail.retrySetFontApplied = retryApplied == true
        detail.retrySucceeded = retriedSucceeded == true
    end

    UpdateFontPreviewDiagnostics(self, detail)
    detail.afterLayoutStringWidth = detail.fontStringWidth
    detail.afterLayoutStringHeight = detail.fontStringHeight
    detail.afterLayoutContainerWidth = detail.fontContainerWidth
    detail.afterLayoutContainerHeight = detail.fontContainerHeight

    if finalSucceeded and detail.fontStringWidth > 0 then
        self.fallbackUsed = false
        detail.fallbackAttempted = false
        detail.fallbackApplied = false
        detail.finalPreviewKind = "font"
        self.statusText:SetText(T("MEDIA_LIBRARY_PREVIEW_STATUS_READY", "Preview ready"))
        UpdateFontPreviewDiagnostics(self, detail)
        detail.finalStringWidth = detail.fontStringWidth
        detail.finalStringHeight = detail.fontStringHeight
        UpdateFontPreviewDiagnostics(self, detail)
        return
    end

    detail.fallbackAttempted = true
    self.fontText:SetText("")
    detail.fallbackApplied = TryApplyFont(self.fontText, STANDARD_TEXT_FONT, fontSize, nil)
    detail.refreshExecuted = RefreshFontPreviewText(self.fontText, sampleText)
    self.fallbackUsed = true
    detail.finalPreviewKind = "fallback"
    self.statusText:SetText(T("MEDIA_LIBRARY_FALLBACK_PREVIEW", "Fallback preview"))
    UpdateFontPreviewDiagnostics(self, detail)
    detail.finalStringWidth = detail.fontStringWidth
    detail.finalStringHeight = detail.fontStringHeight
    UpdateFontPreviewDiagnostics(self, detail)
end

local function ScheduleFontPreviewFinalization(self, generation, detail, sampleText, fontPath, fontSize, fontFlags, retryNeeded)
    local timer = C_Timer and C_Timer.After
    if type(timer) ~= "function" then
        FinalizeFontPreview(self, generation, detail, sampleText, fontPath, fontSize, fontFlags, retryNeeded)
        return
    end

    timer(0, function()
        FinalizeFontPreview(self, generation, detail, sampleText, fontPath, fontSize, fontFlags, retryNeeded)
    end)
end

function methods:SetFontPreview(item, fontPath, options)
    self.previewGeneration = (self.previewGeneration or 0) + 1
    local generation = self.previewGeneration
    options = type(options) == "table" and options or {}
    self.item = item
    self.asset = fontPath
    self.fallbackUsed = options.fallbackUsed == true
    self.title:SetText(T("MEDIA_LIBRARY_PREVIEW", "Preview"))

    HideStatusBarPreview(self)
    HideArtworkPreview(self)

    local sampleText = options.sampleText or T("MEDIA_LIBRARY_FONT_SAMPLE_TEXT", "Focal Point Font Preview\nAa Bb Cc 0123456789")
    local fontSize = tonumber(options.fontSize) or PREVIEW_FONT_SIZE
    local fontFlags = options.fontFlags
    local fontBeforeSetFont = GetFontPath(self.fontText)
    local textBefore = GetText(self.fontText)
    self.fontText:SetText("")
    local primarySucceeded, primaryPcallOk, primaryApplied = TryApplyFont(self.fontText, fontPath, fontSize, fontFlags)

    local refreshExecuted = RefreshFontPreviewText(self.fontText, sampleText)
    self.fontText:SetAlpha(1)
    self.fontContainer:SetBackdropBorderColor(0.34, 0.36, 0.40, 0.86)
    self.fontContainer:Show()
    self.fontText:Show()

    local retryNeeded = primarySucceeded ~= true
    local detail = {
        selectionSequence = generation,
        attempt = 1,
        itemValue = item and item.value or nil,
        itemName = item and item.name or nil,
        itemSource = item and item.source or nil,
        item = item,
        resolvedAsset = fontPath,
        fontBeforeSetFont = fontBeforeSetFont,
        textBefore = textBefore,
        pcallOk = primaryPcallOk == true,
        setFontApplied = primaryApplied == true,
        primarySucceeded = primarySucceeded == true,
        retryScheduled = retryNeeded == true,
        retryExecuted = false,
        retryStillCurrent = nil,
        fallbackAttempted = false,
        fallbackApplied = false,
        finalPreviewKind = primarySucceeded == true and "font" or "pending",
        fontStringText = sampleText,
        refreshMethod = "clear-text-before-setfont",
        refreshExecuted = refreshExecuted == true,
    }
    UpdateFontPreviewDiagnostics(self, detail)
    detail.immediateStringWidth = detail.fontStringWidth
    detail.immediateStringHeight = detail.fontStringHeight
    detail.immediateContainerWidth = detail.fontContainerWidth
    detail.immediateContainerHeight = detail.fontContainerHeight
    UpdateFontPreviewDiagnostics(self, detail)

    if primarySucceeded then
        self.fallbackUsed = false
        self.statusText:SetText(T("MEDIA_LIBRARY_PREVIEW_STATUS_READY", "Preview ready"))
    end

    ScheduleFontPreviewFinalization(self, generation, detail, sampleText, fontPath, fontSize, fontFlags, retryNeeded)
end

function methods:SetArtworkPreview(item, asset, fallbackUsed)
    self.previewGeneration = (self.previewGeneration or 0) + 1
    self.item = item
    self.asset = asset
    self.fallbackUsed = fallbackUsed == true
    self.lastFontPreviewDiagnostics = nil
    self.title:SetText(T("MEDIA_LIBRARY_PREVIEW", "Preview"))

    HideStatusBarPreview(self)
    HideFontPreview(self)

    local applied = false
    if IsNonEmptyString(asset) then
        applied = pcall(self.artworkTexture.SetTexture, self.artworkTexture, asset) == true
    end

    if not applied then
        self.artworkTexture:SetTexture("Interface\\Buttons\\WHITE8X8")
        self.fallbackUsed = true
    end

    self.artworkTexture:SetTexCoord(0, 1, 0, 1)
    self.artworkTexture:SetVertexColor(1, 1, 1, 1)
    self.artworkTexture:Show()
    self.artworkContainer:SetBackdropBorderColor(0.34, 0.36, 0.40, 0.86)
    self.artworkContainer:Show()

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

    local statusBarContainer = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    statusBarContainer:SetPoint("TOPLEFT", frame, "TOPLEFT", 10, -22)
    statusBarContainer:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -10, -22)
    statusBarContainer:SetHeight(64)
    statusBarContainer:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
    })
    statusBarContainer:SetBackdropColor(0.035, 0.040, 0.050, 0.96)
    statusBarContainer:SetBackdropBorderColor(0.24, 0.26, 0.30, 0.70)

    local barBackground = statusBarContainer:CreateTexture(nil, "BACKGROUND")
    barBackground:SetPoint("TOPLEFT", statusBarContainer, "TOPLEFT", 14, -16)
    barBackground:SetPoint("BOTTOMRIGHT", statusBarContainer, "BOTTOMRIGHT", -14, 16)
    barBackground:SetColorTexture(0.02, 0.025, 0.03, 0.95)

    local statusBar = CreateFrame("StatusBar", nil, statusBarContainer)
    statusBar:SetPoint("TOPLEFT", statusBarContainer, "TOPLEFT", 14, -16)
    statusBar:SetPoint("BOTTOMRIGHT", statusBarContainer, "BOTTOMRIGHT", -14, 16)
    statusBar:SetFrameLevel(statusBarContainer:GetFrameLevel() + 1)
    statusBar:SetMinMaxValues(0, 100)
    statusBar:SetValue(70)
    statusBar:SetStatusBarColor(0.72, 0.78, 0.86, 1.00)

    local fontContainer = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    fontContainer:SetPoint("TOPLEFT", frame, "TOPLEFT", 10, -22)
    fontContainer:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -10, -22)
    fontContainer:SetHeight(64)
    fontContainer:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
    })
    fontContainer:SetBackdropColor(0.035, 0.040, 0.050, 0.96)
    fontContainer:SetBackdropBorderColor(0.24, 0.26, 0.30, 0.70)

    local fontText = fontContainer:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    fontText:SetPoint("TOPLEFT", fontContainer, "TOPLEFT", 14, -10)
    fontText:SetPoint("BOTTOMRIGHT", fontContainer, "BOTTOMRIGHT", -14, 10)
    fontText:SetJustifyH("CENTER")
    fontText:SetJustifyV("MIDDLE")
    fontText:SetTextColor(0.88, 0.91, 0.96, 1)
    TryApplyFont(fontText, STANDARD_TEXT_FONT, PREVIEW_FONT_SIZE, nil)

    local artworkContainer = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    artworkContainer:SetPoint("TOPLEFT", frame, "TOPLEFT", 10, -22)
    artworkContainer:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -10, -22)
    artworkContainer:SetHeight(64)
    artworkContainer:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
    })
    artworkContainer:SetBackdropColor(0.035, 0.040, 0.050, 0.96)
    artworkContainer:SetBackdropBorderColor(0.24, 0.26, 0.30, 0.70)

    local artworkTexture = artworkContainer:CreateTexture(nil, "ARTWORK")
    artworkTexture:SetPoint("TOP", artworkContainer, "TOP", 0, -8)
    artworkTexture:SetPoint("BOTTOM", artworkContainer, "BOTTOM", 0, 8)
    artworkTexture:SetWidth(64)
    artworkTexture:SetTexCoord(0, 1, 0, 1)

    local statusText = frame:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    statusText:SetPoint("TOPLEFT", statusBarContainer, "BOTTOMLEFT", 0, -6)
    statusText:SetPoint("TOPRIGHT", statusBarContainer, "BOTTOMRIGHT", 0, -6)
    statusText:SetJustifyH("LEFT")

    local widget = {
        frame = frame,
        type = Type,
        title = title,
        statusBarContainer = statusBarContainer,
        barBackground = barBackground,
        statusBar = statusBar,
        fontContainer = fontContainer,
        fontText = fontText,
        artworkContainer = artworkContainer,
        artworkTexture = artworkTexture,
        statusText = statusText,
    }
    for method, func in pairs(methods) do
        widget[method] = func
    end

    return AceGUI:RegisterAsWidget(widget)
end

AceGUI:RegisterWidgetType(Type, Constructor, Version)
