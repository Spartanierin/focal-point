local _, FocalPoint = ...

FocalPoint.GUI = FocalPoint.GUI or {}
FocalPoint.GUI.Editor = FocalPoint.GUI.Editor or {}

local FrameUnlockGrid = {}
FocalPoint.GUI.Editor.FrameUnlockGrid = FrameUnlockGrid

local GRID_SIZE = 20
FrameUnlockGrid.GRID_SIZE = GRID_SIZE

local function IsEditorUnlocked()
    return FocalPoint.framesUnlocked == true
        and FocalPoint.IsEditorActive
        and FocalPoint:IsEditorActive()
end

local function IsGridEnabled()
    local general = FocalPoint.db and FocalPoint.db.profile and FocalPoint.db.profile.General
    return type(general) == "table" and general.ShowGrid == true
end

local function GetGridColor()
    local skins = FocalPoint.GUI and FocalPoint.GUI.Skins
    local color = skins and skins.GetBrandColor and skins.GetBrandColor("orangeStrong") or nil
    color = type(color) == "table" and color or { 0.918, 0.459, 0.000, 1 }

    return color[1] or color.r or 0.918,
        color[2] or color.g or 0.459,
        color[3] or color.b or 0.000,
        0.13
end

local function GetPixelSize()
    local scale = UIParent and UIParent.GetEffectiveScale and UIParent:GetEffectiveScale() or 1
    if type(scale) ~= "number" or scale <= 0 then
        scale = 1
    end

    return 1 / scale
end

local function RoundToPixel(value, pixelSize)
    pixelSize = type(pixelSize) == "number" and pixelSize > 0 and pixelSize or GetPixelSize()
    value = type(value) == "number" and value or 0

    return math.floor((value / pixelSize) + 0.5) * pixelSize
end

local function ResolveGridMetrics()
    local pixelSize = GetPixelSize()
    local gridStep = math.max(pixelSize, RoundToPixel(GRID_SIZE, pixelSize))

    return pixelSize, gridStep
end

local function EnsureOverlay()
    if FrameUnlockGrid.overlay then
        return FrameUnlockGrid.overlay
    end

    local overlay = CreateFrame("Frame", nil, UIParent)
    overlay:SetAllPoints(UIParent)
    overlay:SetFrameStrata("BACKGROUND")
    overlay:SetFrameLevel(900)
    overlay:EnableMouse(false)
    overlay.lines = {}
    overlay.lastWidth = 0
    overlay.lastHeight = 0
    overlay:Hide()
    overlay:SetScript("OnSizeChanged", function()
        FrameUnlockGrid.Rebuild()
    end)

    FrameUnlockGrid.overlay = overlay
    return overlay
end

local function EnsureLine(overlay, index)
    overlay.lines = overlay.lines or {}
    if overlay.lines[index] then
        return overlay.lines[index]
    end

    local line = overlay:CreateTexture(nil, "BACKGROUND")
    line:SetColorTexture(GetGridColor())
    overlay.lines[index] = line
    return line
end

local function HideUnusedLines(overlay, firstUnusedIndex)
    if not overlay or type(overlay.lines) ~= "table" then
        return
    end

    for index = firstUnusedIndex, #overlay.lines do
        overlay.lines[index]:Hide()
    end
end

function FrameUnlockGrid.Rebuild()
    local overlay = EnsureOverlay()
    if not overlay:IsShown() then
        return
    end

    local width = UIParent and UIParent.GetWidth and UIParent:GetWidth() or 0
    local height = UIParent and UIParent.GetHeight and UIParent:GetHeight() or 0
    if width <= 0 or height <= 0 then
        HideUnusedLines(overlay, 1)
        return
    end

    local r, g, b, a = GetGridColor()
    local pixelSize, gridStep = ResolveGridMetrics()
    local index = 1
    local centerX = RoundToPixel(width / 2, pixelSize)
    local centerY = RoundToPixel(height / 2, pixelSize)
    local lineThickness = pixelSize
    local snappedWidth = RoundToPixel(width, pixelSize)
    local snappedHeight = RoundToPixel(height, pixelSize)

    for x = 0, centerX, gridStep do
        local snappedX = RoundToPixel(x, pixelSize)
        local rightLine = EnsureLine(overlay, index)
        rightLine:ClearAllPoints()
        rightLine:SetColorTexture(r, g, b, a)
        rightLine:SetSize(lineThickness, snappedHeight)
        rightLine:SetPoint("CENTER", UIParent, "CENTER", snappedX, 0)
        rightLine:Show()
        index = index + 1

        if snappedX > 0 then
            local leftLine = EnsureLine(overlay, index)
            leftLine:ClearAllPoints()
            leftLine:SetColorTexture(r, g, b, a)
            leftLine:SetSize(lineThickness, snappedHeight)
            leftLine:SetPoint("CENTER", UIParent, "CENTER", -snappedX, 0)
            leftLine:Show()
            index = index + 1
        end
    end

    for y = 0, centerY, gridStep do
        local snappedY = RoundToPixel(y, pixelSize)
        local topLine = EnsureLine(overlay, index)
        topLine:ClearAllPoints()
        topLine:SetColorTexture(r, g, b, a)
        topLine:SetSize(snappedWidth, lineThickness)
        topLine:SetPoint("CENTER", UIParent, "CENTER", 0, snappedY)
        topLine:Show()
        index = index + 1

        if snappedY > 0 then
            local bottomLine = EnsureLine(overlay, index)
            bottomLine:ClearAllPoints()
            bottomLine:SetColorTexture(r, g, b, a)
            bottomLine:SetSize(snappedWidth, lineThickness)
            bottomLine:SetPoint("CENTER", UIParent, "CENTER", 0, -snappedY)
            bottomLine:Show()
            index = index + 1
        end
    end

    HideUnusedLines(overlay, index)
    overlay.lastWidth = width
    overlay.lastHeight = height
end

function FrameUnlockGrid.Refresh()
    local overlay = EnsureOverlay()
    if IsEditorUnlocked() and IsGridEnabled() then
        overlay:Show()
        FrameUnlockGrid.Rebuild()
    else
        overlay:Hide()
    end
end

function FrameUnlockGrid.Hide()
    local overlay = FrameUnlockGrid.overlay
    if overlay then
        overlay:Hide()
    end
end

return FrameUnlockGrid
