local _, FocalPoint = ...

FocalPoint.GUI = FocalPoint.GUI or {}
FocalPoint.GUI.Editor = FocalPoint.GUI.Editor or {}

local CanvasHoverOverlay = {}
FocalPoint.GUI.Editor.CanvasHoverOverlay = CanvasHoverOverlay

local HOVER_FRAME_LEVEL = 910

local BAR_TARGETS = {
    { objectKey = "HealthBar", elementKey = "HealthBar", sectionKey = "health", level = 30 },
    { objectKey = "NormalAbsorbBar", elementKey = "NormalAbsorbBar", sectionKey = "absorbs", level = 34 },
    { objectKey = "HealingAbsorbBar", elementKey = "HealingAbsorbBar", sectionKey = "absorbs", level = 35 },
    { objectKey = "PowerBar", elementKey = "PowerBar", sectionKey = "power", level = 30 },
    { objectKey = "AlternativePowerBar", elementKey = "AlternativePowerBar", sectionKey = "alt_power", level = 31 },
    { objectKey = "ClassPowerBar", elementKey = "ClassPowerBar", sectionKey = "class_power", level = 32 },
    { objectKey = "CastBar", elementKey = "CastBar", sectionKey = "cast", level = 33 },
}

local AURA_TARGETS = {
    { auraKey = "Buffs", elementKey = "Buffs", level = 40 },
    { auraKey = "Debuffs", elementKey = "Debuffs", level = 41 },
}

local INDICATOR_TARGETS = {
    { indicatorKey = "Portrait", elementKey = "Portrait", level = 50 },
    { indicatorKey = "RaidTargetIcon", elementKey = "RaidTargetIcon", level = 51 },
    { indicatorKey = "LeaderIcon", elementKey = "LeaderIcon", level = 51 },
    { indicatorKey = "RoleIcon", elementKey = "RoleIcon", level = 51 },
    { indicatorKey = "CombatIndicator", elementKey = "CombatIndicator", level = 51 },
    { indicatorKey = "RestingIndicator", elementKey = "RestingIndicator", level = 51 },
    { indicatorKey = "ReadyCheckIndicator", elementKey = "ReadyCheckIndicator", level = 51 },
    { indicatorKey = "ClassificationIndicator", elementKey = "ClassificationCrest", level = 52 },
    { indicatorKey = "ClassificationIndicator", elementKey = "ClassificationPortraitOverlay", level = 52 },
}

local currentHover = nil

local function NormalizeUnitKey(unitKey)
    if type(unitKey) ~= "string" or unitKey == "" then
        return nil
    end
    if unitKey:match("^boss%d+$") then
        return "boss"
    end
    return unitKey
end

local function IsEditorFrameMode()
    if not CanvasHoverOverlay.IsEditorActive() then
        return false
    end

    local interactionMode = FocalPoint.GUI
        and FocalPoint.GUI.Editor
        and FocalPoint.GUI.Editor.InteractionMode
    if interactionMode and interactionMode.IsFrameMode then
        return interactionMode.IsFrameMode()
    end

    return not (InCombatLockdown and InCombatLockdown() == true)
end

function CanvasHoverOverlay.IsEditorActive()
    return FocalPoint.framesUnlocked == true
        and FocalPoint.IsEditorActive
        and FocalPoint:IsEditorActive()
end

local function IsFrameShown(frame)
    return frame and (not frame.IsShown or frame:IsShown())
end

local function GetRefObjectKey(ref)
    if type(ref) ~= "table" then
        return nil
    end
    return ref.objectKey or ref.textKey or ref.auraKey or ref.indicatorKey or ref.decorationId
end

local function RefsEqual(left, right)
    if type(left) ~= "table" or type(right) ~= "table" then
        return false
    end
    return left.kind == right.kind
        and NormalizeUnitKey(left.unit) == NormalizeUnitKey(right.unit)
        and GetRefObjectKey(left) == GetRefObjectKey(right)
end

local function IsSelectedObject(ref)
    local objectSelection = FocalPoint.GUI
        and FocalPoint.GUI.Editor
        and FocalPoint.GUI.Editor.ObjectSelection
    local selected = objectSelection and objectSelection.GetSelectedObject and objectSelection.GetSelectedObject() or nil
    return RefsEqual(ref, selected)
end

local function EnsureHoverFrame()
    if CanvasHoverOverlay.Frame then
        return CanvasHoverOverlay.Frame
    end

    local frame = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
    frame:SetFrameStrata("FULLSCREEN")
    frame:SetFrameLevel(HOVER_FRAME_LEVEL)
    frame:EnableMouse(false)
    frame:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
        insets = { left = 0, right = 0, top = 0, bottom = 0 },
    })
    frame:SetBackdropColor(0.75, 0.86, 1.00, 0.035)
    frame:SetBackdropBorderColor(0.72, 0.82, 1.00, 0.54)
    frame:Hide()

    CanvasHoverOverlay.Frame = frame
    return frame
end

local function ApplyHoverChrome(target)
    local frame = EnsureHoverFrame()
    frame:ClearAllPoints()
    frame:SetPoint("TOPLEFT", target, "TOPLEFT", 0, 0)
    frame:SetPoint("BOTTOMRIGHT", target, "BOTTOMRIGHT", 0, 0)
    frame:Show()
end

local function ShouldUseGenericChrome(objectRef)
    return type(objectRef) ~= "table" or objectRef.kind ~= "text"
end

function CanvasHoverOverlay.SetHover(target, objectRef)
    if not target or type(objectRef) ~= "table" or not CanvasHoverOverlay.IsEditorActive() or not IsFrameShown(target) then
        CanvasHoverOverlay.Clear()
        return
    end

    objectRef.unit = NormalizeUnitKey(objectRef.unit)
    if IsSelectedObject(objectRef) then
        CanvasHoverOverlay.Clear()
        return
    end

    currentHover = {
        target = target,
        objectRef = objectRef,
    }
    if ShouldUseGenericChrome(objectRef) then
        ApplyHoverChrome(target)
    elseif CanvasHoverOverlay.Frame then
        CanvasHoverOverlay.Frame:Hide()
    end
end

function CanvasHoverOverlay.Clear(target)
    if target and currentHover and currentHover.target ~= target then
        return
    end

    currentHover = nil
    if CanvasHoverOverlay.Frame then
        CanvasHoverOverlay.Frame:Hide()
    end
end

function CanvasHoverOverlay.GetHoveredObject()
    return currentHover and currentHover.objectRef or nil
end

local function ForwardScript(source, scriptName)
    local overlay = source and source._focalPointForwardOverlay
    if not overlay then
        return
    end

    if scriptName == "OnMouseDown" and overlay._focalPointEditorForwardMouseDown then
        overlay._focalPointEditorForwardMouseDown(source._focalPointForwardButton)
    elseif scriptName == "OnMouseUp" and overlay._focalPointEditorForwardMouseUp then
        overlay._focalPointEditorForwardMouseUp(source._focalPointForwardButton)
    elseif scriptName == "OnDragStart" and overlay._focalPointEditorForwardDragStart then
        overlay._focalPointEditorForwardDragStart()
    elseif scriptName == "OnDragStop" and overlay._focalPointEditorForwardDragStop then
        overlay._focalPointEditorForwardDragStop()
    end
end

local function EnsureHitZone(frame, key)
    if not (frame and frame.MoveOverlay and type(key) == "string" and key ~= "") then
        return nil
    end

    frame._focalPointCanvasHoverZones = frame._focalPointCanvasHoverZones or {}
    local zone = frame._focalPointCanvasHoverZones[key]
    if zone then
        return zone
    end

    zone = CreateFrame("Button", nil, frame.MoveOverlay)
    zone:SetFrameStrata(frame.MoveOverlay:GetFrameStrata())
    zone:EnableMouse(false)
    zone:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    zone:RegisterForDrag("LeftButton")
    zone:SetScript("OnEnter", function(self)
        CanvasHoverOverlay.SetHover(self, self._focalPointObjectRef)
    end)
    zone:SetScript("OnLeave", function(self)
        CanvasHoverOverlay.Clear(self)
        local overlay = self._focalPointForwardOverlay
        if overlay and overlay.IsMouseOver and overlay:IsMouseOver() then
            CanvasHoverOverlay.SetHover(overlay, overlay._focalPointObjectRef)
        end
    end)
    zone:SetScript("OnMouseDown", function(self, button)
        self._focalPointForwardButton = button
        ForwardScript(self, "OnMouseDown")
    end)
    zone:SetScript("OnMouseUp", function(self, button)
        self._focalPointForwardButton = button
        ForwardScript(self, "OnMouseUp")
        if button == "RightButton" then
            local contextMenu = FocalPoint.GUI
                and FocalPoint.GUI.Editor
                and FocalPoint.GUI.Editor.FrameContextMenu
            if contextMenu and contextMenu.ShowForFrame and self._focalPointOwnerFrame then
                contextMenu.ShowForFrame(self._focalPointOwnerFrame)
            end
        end
        self._focalPointForwardButton = nil
    end)
    zone:SetScript("OnDragStart", function(self)
        ForwardScript(self, "OnDragStart")
    end)
    zone:SetScript("OnDragStop", function(self)
        ForwardScript(self, "OnDragStop")
    end)
    zone:Hide()

    frame._focalPointCanvasHoverZones[key] = zone
    return zone
end

local function PositionZone(zone, frame, target, objectRef, level)
    if not (zone and frame and target and objectRef and IsFrameShown(target)) then
        if zone then
            zone:Hide()
            zone:EnableMouse(false)
        end
        return
    end

    zone._focalPointForwardOverlay = frame.MoveOverlay
    zone._focalPointOwnerFrame = frame
    zone._focalPointObjectRef = objectRef
    zone:SetFrameLevel((frame.MoveOverlay:GetFrameLevel() or 0) + (tonumber(level) or 1))
    zone:ClearAllPoints()
    zone:SetPoint("TOPLEFT", target, "TOPLEFT", 0, 0)
    zone:SetPoint("BOTTOMRIGHT", target, "BOTTOMRIGHT", 0, 0)
    zone:EnableMouse(true)
    zone:Show()
end

local function HideZone(zone)
    if not zone then
        return
    end
    if currentHover and currentHover.target == zone then
        CanvasHoverOverlay.Clear(zone)
    end
    zone._focalPointObjectRef = nil
    zone:EnableMouse(false)
    zone:Hide()
end

local function UpdateBars(frame, seen)
    local elements = frame and frame.Elements or nil
    for _, item in ipairs(BAR_TARGETS) do
        local target = elements and elements[item.elementKey] or nil
        local key = "bar:" .. item.objectKey
        local zone = EnsureHitZone(frame, key)
        seen[key] = true
        PositionZone(zone, frame, target, {
            kind = "bar",
            unit = frame.unit,
            objectKey = item.objectKey,
            sectionKey = item.sectionKey,
        }, item.level)
    end
end

local function UpdateAuras(frame, seen)
    local elements = frame and frame.Elements or nil
    for _, item in ipairs(AURA_TARGETS) do
        local target = elements and elements[item.elementKey] or nil
        local key = "aura:" .. item.auraKey
        local zone = EnsureHitZone(frame, key)
        seen[key] = true
        PositionZone(zone, frame, target, {
            kind = "aura",
            unit = frame.unit,
            auraKey = item.auraKey,
            objectKey = item.auraKey,
            sectionKey = "auras",
        }, item.level)
    end
end

local function UpdateIndicators(frame, seen)
    local elements = frame and frame.Elements or nil
    for _, item in ipairs(INDICATOR_TARGETS) do
        local target = elements and elements[item.elementKey] or nil
        local key = "indicator:" .. item.indicatorKey .. ":" .. item.elementKey
        local zone = EnsureHitZone(frame, key)
        seen[key] = true
        PositionZone(zone, frame, target, {
            kind = "indicator",
            unit = frame.unit,
            indicatorKey = item.indicatorKey,
            objectKey = item.indicatorKey,
            sectionKey = "indicators",
        }, item.level)
    end
end

local function UpdateDecorations(frame, seen)
    local registry = frame and frame.DecorationIndicators
    if type(registry) ~= "table" then
        return
    end

    for decorationId, entry in pairs(registry) do
        local target = type(entry) == "table" and entry.holder or nil
        local key = "decoration:" .. tostring(decorationId)
        local zone = EnsureHitZone(frame, key)
        seen[key] = true
        PositionZone(zone, frame, target, {
            kind = "decoration",
            unit = frame.unit,
            decorationId = decorationId,
            objectKey = decorationId,
            sectionKey = "decoration",
        }, 60)
    end
end

function CanvasHoverOverlay.UpdateFrame(frame)
    if not frame then
        return
    end

    if currentHover and IsSelectedObject(currentHover.objectRef) then
        CanvasHoverOverlay.Clear()
    end

    local overlay = frame.MoveOverlay
    if overlay and not overlay._focalPointCanvasHoverHooked then
        overlay._focalPointCanvasHoverHooked = true
        overlay._focalPointObjectRef = {
            kind = "unit",
            unit = frame.unit,
            sectionKey = "frame",
        }
        overlay:HookScript("OnEnter", function(self)
            CanvasHoverOverlay.SetHover(self, self._focalPointObjectRef)
        end)
        overlay:HookScript("OnLeave", function(self)
            CanvasHoverOverlay.Clear(self)
        end)
    elseif overlay then
        overlay._focalPointObjectRef = {
            kind = "unit",
            unit = frame.unit,
            sectionKey = "frame",
        }
    end

    local active = IsEditorFrameMode() and overlay and overlay:IsShown()
    if not active then
        CanvasHoverOverlay.HideFrame(frame)
        return
    end

    local seen = {}
    UpdateBars(frame, seen)
    UpdateAuras(frame, seen)
    UpdateIndicators(frame, seen)
    UpdateDecorations(frame, seen)

    local zones = frame._focalPointCanvasHoverZones
    if type(zones) == "table" then
        for key, zone in pairs(zones) do
            if not seen[key] then
                HideZone(zone)
            end
        end
    end
end

function CanvasHoverOverlay.HideFrame(frame)
    local zones = frame and frame._focalPointCanvasHoverZones
    if type(zones) == "table" then
        for _, zone in pairs(zones) do
            HideZone(zone)
        end
    end

    if currentHover and (not frame or currentHover.target == frame or currentHover.target == frame.MoveOverlay) then
        CanvasHoverOverlay.Clear()
    end
end
