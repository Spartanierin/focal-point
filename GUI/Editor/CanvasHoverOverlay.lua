local _, FocalPoint = ...

FocalPoint.GUI = FocalPoint.GUI or {}
FocalPoint.GUI.Editor = FocalPoint.GUI.Editor or {}

local CanvasHoverOverlay = {}
FocalPoint.GUI.Editor.CanvasHoverOverlay = CanvasHoverOverlay

local SelectionGeometryResolver = FocalPoint.GUI.Editor.SelectionGeometryResolver or {}

local HOVER_FRAME_LEVEL = 910

local BAR_TARGETS = {
    { objectKey = "HealthBar", elementKey = "HealthBar", sectionKey = "health", level = 30, movesUnit = true },
    { objectKey = "NormalAbsorbBar", elementKey = "NormalAbsorbBar", sectionKey = "absorbs", level = 34, movesUnit = true },
    { objectKey = "HealingAbsorbBar", elementKey = "HealingAbsorbBar", sectionKey = "absorbs", level = 35, movesUnit = true },
    { objectKey = "PowerBar", elementKey = "PowerBar", sectionKey = "power", level = 30, movesUnit = true },
    { objectKey = "AlternativePowerBar", elementKey = "AlternativePowerBar", sectionKey = "alt_power", level = 31, movesUnit = true },
    { objectKey = "ClassPowerBar", elementKey = "ClassPowerBar", sectionKey = "class_power", level = 32, movesUnit = true },
    { objectKey = "CastBar", elementKey = "CastBar", sectionKey = "cast", level = 33, movesUnit = true },
}

local AURA_TARGETS = {
    { auraKey = "Buffs", elementKey = "Buffs", level = 40, movesUnit = true },
    { auraKey = "Debuffs", elementKey = "Debuffs", level = 41, movesUnit = true },
}

local INDICATOR_TARGETS = {
    { indicatorKey = "Portrait", elementKey = "Portrait", level = 50, movesUnit = true },
    { indicatorKey = "RaidTargetIcon", elementKey = "RaidTargetIcon", level = 51, movesUnit = true },
    { indicatorKey = "LeaderIcon", elementKey = "LeaderIcon", level = 51, movesUnit = true },
    { indicatorKey = "RoleIcon", elementKey = "RoleIcon", level = 51, movesUnit = true },
    { indicatorKey = "CombatIndicator", elementKey = "CombatIndicator", level = 51, movesUnit = true },
    { indicatorKey = "RestingIndicator", elementKey = "RestingIndicator", level = 51, movesUnit = true },
    { indicatorKey = "ReadyCheckIndicator", elementKey = "ReadyCheckIndicator", level = 51, movesUnit = true },
    { indicatorKey = "ClassificationIndicator", elementKey = "ClassificationCrest", level = 52, movesUnit = true },
    { indicatorKey = "ClassificationIndicator", elementKey = "ClassificationPortraitOverlay", level = 52, movesUnit = true },
}

local currentHover = nil

local DIRECT_MOVE_LIMIT = 500

local function NormalizeUnitKey(unitKey)
    if type(unitKey) ~= "string" or unitKey == "" then
        return nil
    end
    if unitKey:match("^boss%d+$") then
        return "boss"
    end
    return unitKey
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

local function ApplyZoneChrome(zone, selected)
    if not zone or not zone.SetBackdropColor then
        return
    end

    if selected then
        zone:SetBackdropColor(0.98, 0.84, 0.24, 0.10)
        zone:SetBackdropBorderColor(0.98, 0.84, 0.24, 0.95)
    else
        zone:SetBackdropColor(0, 0, 0, 0)
        zone:SetBackdropBorderColor(0, 0, 0, 0)
    end
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

local function SetZoneMouseEnabled(zone, enabled)
    if not zone then
        return
    end
    zone:EnableMouse(enabled == true)
end

local function GetCursorPositionInUiScale()
    local scale = UIParent and UIParent.GetEffectiveScale and UIParent:GetEffectiveScale() or 1
    if not scale or scale == 0 then
        scale = 1
    end
    local cursorX, cursorY = GetCursorPosition()
    return (cursorX or 0) / scale, (cursorY or 0) / scale
end

local function IsShiftDown()
    local interactionMode = FocalPoint.GUI
        and FocalPoint.GUI.Editor
        and FocalPoint.GUI.Editor.InteractionMode
    return interactionMode and interactionMode.IsShiftDown and interactionMode.IsShiftDown() == true
end

local function GetEditableUnitConfig(frame)
    local unitKey = NormalizeUnitKey(frame and frame._fpUnit)
    if not unitKey then
        return nil, nil
    end

    local resolver = FocalPoint.ActiveLayoutResolver
    if resolver and resolver.GetEditableActiveUnits then
        local units = resolver.GetEditableActiveUnits(FocalPoint.db)
        if type(units) == "table" and type(units[unitKey]) == "table" then
            return units[unitKey], unitKey
        end
    end

    local unitUtils = FocalPoint.UnitFrameUtils
    if unitUtils and unitUtils.GetUnitDB then
        return unitUtils.GetUnitDB(unitKey), unitKey
    end

    return nil, unitKey
end

local function FindDecorationConfig(unitConfig, decorationId)
    local decorations = type(unitConfig) == "table" and unitConfig.decorations or nil
    if type(decorations) ~= "table" then
        return nil
    end
    for _, decoration in ipairs(decorations) do
        if type(decoration) == "table" and decoration.id == decorationId then
            return decoration
        end
    end
    return nil
end

local function ResolveDirectMoveDescriptor(frame, objectRef)
    local unitConfig, unitKey = GetEditableUnitConfig(frame)
    if type(unitConfig) ~= "table" or type(objectRef) ~= "table" then
        return nil
    end

    if objectRef.kind == "bar" then
        local objectKey = objectRef.objectKey
        if objectKey == "CastBar" then
            return { kind = "unit", unitConfig = unitConfig, unitKey = unitKey, offsetXField = "castBarOffsetX", offsetYField = "castBarOffsetY" }
        end
        if objectKey == "ClassPowerBar" then
            return { kind = "unit", unitConfig = unitConfig, unitKey = unitKey, offsetXField = "classPowerBarOffsetX", offsetYField = "classPowerBarOffsetY" }
        end
        local prefix = objectKey == "NormalAbsorbBar" and "normalAbsorbBar" or objectKey == "HealingAbsorbBar" and "healingAbsorbBar" or nil
        if prefix and unitConfig[prefix .. "SizeMode"] == "CUSTOM" then
            return { kind = "unit", unitConfig = unitConfig, unitKey = unitKey, offsetXField = prefix .. "OffsetX", offsetYField = prefix .. "OffsetY" }
        end
        return nil
    end

    if objectRef.kind == "indicator" then
        local indicatorKey = objectRef.indicatorKey
        if indicatorKey == "ClassificationIndicator" then
            return nil
        end
        local shared = FocalPoint.GUI and FocalPoint.GUI.Editor and FocalPoint.GUI.Editor.SidebarShared
        local indicatorMeta = shared and shared.INDICATOR_META or nil
        local meta = type(indicatorMeta) == "table" and indicatorMeta[indicatorKey] or nil
        local indicatorConfig = type(meta) == "table" and unitConfig[meta.optionKey] or nil
        if type(indicatorConfig) == "table" and indicatorConfig.placement ~= "INSIDE" then
            return { kind = "indicator", unitConfig = unitConfig, unitKey = unitKey, indicatorKey = indicatorKey, indicatorMeta = indicatorMeta, offsetXField = "offsetX", offsetYField = "offsetY" }
        end
        return nil
    end

    if objectRef.kind == "aura" then
        local auraConfig = unitConfig[objectRef.auraKey]
        if type(auraConfig) == "table" and auraConfig.placement ~= "INSIDE" then
            return { kind = "aura", unitConfig = unitConfig, unitKey = unitKey, auraKey = objectRef.auraKey, auraConfig = auraConfig, offsetXField = "offsetX", offsetYField = "offsetY" }
        end
        return nil
    end

    if objectRef.kind == "decoration" then
        local decorationConfig = FindDecorationConfig(unitConfig, objectRef.decorationId)
        if decorationConfig then
            return { kind = "decoration", unitConfig = unitConfig, unitKey = unitKey, decorationId = objectRef.decorationId, offsetXField = "offsetX", offsetYField = "offsetY" }
        end
    end

    return nil
end

local function ClampDirectMoveOffset(value)
    return math.max(-DIRECT_MOVE_LIMIT, math.min(DIRECT_MOVE_LIMIT, math.floor((tonumber(value) or 0) + 0.5)))
end

local function GetDirectMoveOffsetConfig(descriptor)
    if descriptor and descriptor.kind == "aura" then
        return descriptor.auraConfig or {}
    end
    return descriptor and descriptor.unitConfig or {}
end

local function ShowZone(zone)
    if not zone then
        return
    end
    zone:Show()
end

local function HideZoneFrame(zone)
    if not zone then
        return
    end
    zone:Hide()
end

local function SelectObjectRef(source, objectRef)
    local objectSelection = FocalPoint.GUI
        and FocalPoint.GUI.Editor
        and FocalPoint.GUI.Editor.ObjectSelection
    if objectSelection and objectSelection.SelectObject then
        return objectSelection.SelectObject(objectRef)
    end

    return false
end

local function EndOwnerDrag(zone, commit)
    if not (zone and zone._focalPointOwnerDragActive) then
        return
    end

    zone._focalPointOwnerDragActive = nil
    if FocalPoint.EndEditorUnitFrameDrag then
        FocalPoint:EndEditorUnitFrameDrag(zone._focalPointOwnerFrame, commit)
    end
end

local function CaptureFramePoints(target)
    if not (target and target.GetNumPoints and target.GetPoint) then
        return nil
    end

    local points = {}
    for index = 1, target:GetNumPoints() do
        local point, relativeTo, relativePoint, offsetX, offsetY = target:GetPoint(index)
        if point and relativeTo and relativePoint then
            points[#points + 1] = {
                point = point,
                relativeTo = relativeTo,
                relativePoint = relativePoint,
                offsetX = offsetX or 0,
                offsetY = offsetY or 0,
            }
        end
    end
    return #points > 0 and points or nil
end

local function ApplyDirectMovePreview(state, offsetX, offsetY)
    local target = state and state.target
    if not (target and state.points and target.ClearAllPoints and target.SetPoint) then
        return false
    end

    target:ClearAllPoints()
    for _, point in ipairs(state.points) do
        target:SetPoint(point.point, point.relativeTo, point.relativePoint, point.offsetX + offsetX, point.offsetY + offsetY)
    end
    return true
end

local function RestoreDirectMovePreview(state)
    return ApplyDirectMovePreview(state, 0, 0)
end

local function ApplyAuraDirectMovePreview(state, offsetX, offsetY)
    local descriptor = state and state.descriptor
    local layout = FocalPoint.AuraBlockLayout
    if not (descriptor and descriptor.kind == "aura" and layout and layout.SetPreviewOffsets and layout.ApplyAnchor) then
        return false
    end

    layout.SetPreviewOffsets(state.frame, descriptor.auraKey, offsetX, offsetY)
    layout.ApplyAnchor(state.target, state.frame, descriptor.auraConfig, descriptor.auraKey)
    return true
end

local function ClearAuraDirectMovePreview(state)
    local descriptor = state and state.descriptor
    local layout = FocalPoint.AuraBlockLayout
    if not (descriptor and descriptor.kind == "aura" and layout and layout.ClearPreviewOffsets) then
        return false
    end

    layout.ClearPreviewOffsets(state.frame, descriptor.auraKey)
    return true
end

local function CommitDirectMove(state)
    local mutations = FocalPoint.InspectorMutations
        or (FocalPoint.GUI and FocalPoint.GUI.Editor and FocalPoint.GUI.Editor.Inspector and FocalPoint.GUI.Editor.Inspector.Mutations)
    if not (state and state.descriptor and mutations) then
        return false
    end

    local descriptor = state.descriptor
    local context = { unitConfig = descriptor.unitConfig }
    local setField
    if descriptor.kind == "unit" then
        setField = function(fieldName, value)
            return mutations.SetUnitField and mutations.SetUnitField(context, fieldName, value)
        end
    elseif descriptor.kind == "indicator" then
        context.indicatorMeta = descriptor.indicatorMeta
        setField = function(fieldName, value)
            return mutations.SetIndicatorField and mutations.SetIndicatorField(context, descriptor.indicatorKey, fieldName, value)
        end
    elseif descriptor.kind == "aura" then
        setField = function(fieldName, value)
            return mutations.SetAuraField and mutations.SetAuraField(context, descriptor.auraKey, fieldName, value)
        end
    elseif descriptor.kind == "decoration" then
        setField = function(fieldName, value)
            return mutations.SetDecorationField and mutations.SetDecorationField(context, descriptor.decorationId, fieldName, value)
        end
    end
    if not setField then
        return false
    end

    local resultX = setField(descriptor.offsetXField, state.currentOffsetX)
    local resultY = setField(descriptor.offsetYField, state.currentOffsetY)
    return resultX and resultX.ok ~= false and resultY and resultY.ok ~= false
end

local function EndDirectMoveDrag(zone, commit)
    local state = zone and zone._focalPointDirectDragState
    if not state then
        return
    end

    zone._focalPointDirectDragState = nil
    zone:SetScript("OnUpdate", nil)
    if commit ~= true or not state.dragging or not CommitDirectMove(state) then
        if ClearAuraDirectMovePreview(state) then
            local layout = FocalPoint.AuraBlockLayout
            layout.ApplyAnchor(state.target, state.frame, state.descriptor.auraConfig, state.descriptor.auraKey)
        else
            RestoreDirectMovePreview(state)
        end
        return
    end

    ClearAuraDirectMovePreview(state)
    if FocalPoint.RefreshUnitFrame then
        FocalPoint:RefreshUnitFrame(state.descriptor.unitKey)
    end
    CanvasHoverOverlay.UpdateFrame(state.frame)
end

local function BeginDirectMoveDrag(zone, gesture)
    local descriptor = gesture and gesture.directMove
    local target = zone and zone._focalPointVisualTarget
    if not descriptor or not target or (InCombatLockdown and InCombatLockdown()) then
        return false
    end

    local cursorX, cursorY = GetCursorPositionInUiScale()
    local points = descriptor.kind ~= "aura" and CaptureFramePoints(target) or nil
    if descriptor.kind ~= "aura" and not points then
        return false
    end

    local state = {
        frame = zone._focalPointOwnerFrame,
        target = target,
        descriptor = descriptor,
        points = points,
        startCursorX = cursorX,
        startCursorY = cursorY,
        startOffsetX = tonumber(GetDirectMoveOffsetConfig(descriptor)[descriptor.offsetXField]) or 0,
        startOffsetY = tonumber(GetDirectMoveOffsetConfig(descriptor)[descriptor.offsetYField]) or 0,
        currentOffsetX = tonumber(GetDirectMoveOffsetConfig(descriptor)[descriptor.offsetXField]) or 0,
        currentOffsetY = tonumber(GetDirectMoveOffsetConfig(descriptor)[descriptor.offsetYField]) or 0,
        dragging = true,
    }
    zone._focalPointDirectDragState = state
    zone:SetScript("OnUpdate", function(self)
        local activeState = self._focalPointDirectDragState
        if not activeState then
            self:SetScript("OnUpdate", nil)
            return
        end
        if not CanvasHoverOverlay.IsEditorActive() or (InCombatLockdown and InCombatLockdown()) then
            EndDirectMoveDrag(self, false)
            return
        end
        if IsMouseButtonDown and not IsMouseButtonDown("LeftButton") then
            EndDirectMoveDrag(self, true)
            return
        end

        local cursorX, cursorY = GetCursorPositionInUiScale()
        local offsetX = ClampDirectMoveOffset(activeState.startOffsetX + cursorX - activeState.startCursorX)
        local offsetY = ClampDirectMoveOffset(activeState.startOffsetY + cursorY - activeState.startCursorY)
        if offsetX == activeState.currentOffsetX and offsetY == activeState.currentOffsetY then
            return
        end
        activeState.currentOffsetX = offsetX
        activeState.currentOffsetY = offsetY
        if activeState.descriptor.kind == "aura" then
            ApplyAuraDirectMovePreview(activeState, offsetX, offsetY)
        else
            ApplyDirectMovePreview(activeState, offsetX - activeState.startOffsetX, offsetY - activeState.startOffsetY)
        end
    end)
    return true
end

local function CompleteOwnerGesture(zone, commit)
    local gesture = zone and zone._focalPointGesture
    if not gesture then
        return
    end

    zone._focalPointGesture = nil
    if gesture.mode == "direct" then
        EndDirectMoveDrag(zone, commit)
    else
        EndOwnerDrag(zone, commit)
    end
    if commit then
        SelectObjectRef(zone, gesture.selectionTarget)
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

    zone = CreateFrame("Button", nil, frame.MoveOverlay, "BackdropTemplate")
    zone:SetFrameStrata(frame.MoveOverlay:GetFrameStrata())
    zone:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 2,
        insets = { left = 0, right = 0, top = 0, bottom = 0 },
    })
    ApplyZoneChrome(zone, false)
    SetZoneMouseEnabled(zone, false)
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
    zone:SetScript("OnMouseUp", function(self, button)
        if button == "LeftButton" then
            if self._focalPointMovesUnit then
                CompleteOwnerGesture(self, true)
            else
                SelectObjectRef(self, self._focalPointObjectRef)
            end
        end
        if button == "RightButton" then
            local contextMenu = FocalPoint.GUI
                and FocalPoint.GUI.Editor
                and FocalPoint.GUI.Editor.FrameContextMenu
            if contextMenu and contextMenu.ShowForFrame and self._focalPointOwnerFrame then
                contextMenu.ShowForFrame(self._focalPointOwnerFrame)
            end
        end
    end)
    zone:SetScript("OnMouseDown", function(self, button)
        if button == "LeftButton" and self._focalPointMovesUnit then
            local directMove = IsShiftDown() and ResolveDirectMoveDescriptor(self._focalPointOwnerFrame, self._focalPointObjectRef) or nil
            local gesture = {
                hitTarget = self,
                selectionTarget = self._focalPointObjectRef,
                movementOwner = directMove and self._focalPointVisualTarget or self._focalPointOwnerFrame,
                mode = directMove and "direct" or "unit",
                directMove = directMove,
            }
            self._focalPointGesture = gesture
        end
    end)
    zone:SetScript("OnDragStart", function(self)
        local gesture = self._focalPointGesture
        if not gesture or not self._focalPointMovesUnit then
            return
        end

        if gesture.mode == "direct" then
            BeginDirectMoveDrag(self, gesture)
            return
        end

        if not FocalPoint.BeginEditorUnitFrameDrag then
            return
        end

        self._focalPointOwnerDragActive = FocalPoint:BeginEditorUnitFrameDrag(
            gesture.movementOwner,
            { moveOnlyOwner = true, gesture = gesture }
        ) == true
    end)
    zone:SetScript("OnDragStop", function(self)
        CompleteOwnerGesture(self, true)
    end)
    HideZoneFrame(zone)

    frame._focalPointCanvasHoverZones[key] = zone
    return zone
end

local function ResolveZoneGeometry(frame, target, objectRef, isSelected)
    if objectRef and (objectRef.kind == "aura" or (isSelected and (objectRef.kind == "bar" or objectRef.kind == "indicator" or objectRef.kind == "decoration"))) and SelectionGeometryResolver.Resolve then
        return SelectionGeometryResolver.Resolve(frame, objectRef)
    end
    if IsFrameShown(target) then
        return { target = target }
    end
    return nil
end

local function ApplyZoneGeometry(zone, geometry)
    if not (zone and geometry) then
        return false
    end

    zone:ClearAllPoints()
    if geometry.target then
        zone:SetPoint("TOPLEFT", geometry.target, "TOPLEFT", 0, 0)
        zone:SetPoint("BOTTOMRIGHT", geometry.target, "BOTTOMRIGHT", 0, 0)
        return true
    end

    if geometry.width then
        zone:SetWidth(geometry.width)
    end
    if geometry.height then
        zone:SetHeight(geometry.height)
    end

    local points = geometry.points
    if type(points) ~= "table" or #points == 0 then
        return false
    end
    for _, point in ipairs(points) do
        if not (point.point and point.relativeTo and point.relativePoint) then
            return false
        end
        zone:SetPoint(point.point, point.relativeTo, point.relativePoint, point.offsetX or 0, point.offsetY or 0)
    end
    return true
end

local function PositionZone(zone, frame, target, objectRef, level, movesUnit)
    local isSelected = IsSelectedObject(objectRef)
    local geometry = ResolveZoneGeometry(frame, target, objectRef, isSelected)
    if not (zone and frame and objectRef and geometry) then
        if zone then
            HideZoneFrame(zone)
            SetZoneMouseEnabled(zone, false)
        end
        return
    end

    zone._focalPointForwardOverlay = frame.MoveOverlay
    zone._focalPointOwnerFrame = frame
    zone._focalPointObjectRef = objectRef
    zone._focalPointVisualTarget = target
    zone._focalPointMovesUnit = movesUnit == true
    zone:SetFrameLevel((frame.MoveOverlay:GetFrameLevel() or 0) + (tonumber(level) or 1))
    if not ApplyZoneGeometry(zone, geometry) then
        HideZoneFrame(zone)
        SetZoneMouseEnabled(zone, false)
        return
    end
    ApplyZoneChrome(zone, isSelected)
    SetZoneMouseEnabled(zone, true)
    ShowZone(zone)
end

local function HideZone(zone)
    if not zone then
        return
    end
    if currentHover and currentHover.target == zone then
        CanvasHoverOverlay.Clear(zone)
    end
    CompleteOwnerGesture(zone, false)
    SetZoneMouseEnabled(zone, false)
    ApplyZoneChrome(zone, false)
    HideZoneFrame(zone)
    zone._focalPointObjectRef = nil
    zone._focalPointVisualTarget = nil
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
            unit = frame._fpUnit,
            objectKey = item.objectKey,
            sectionKey = item.sectionKey,
        }, item.level, item.movesUnit)
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
            unit = frame._fpUnit,
            auraKey = item.auraKey,
            objectKey = item.auraKey,
            sectionKey = "auras",
        }, item.level, item.movesUnit)
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
            unit = frame._fpUnit,
            indicatorKey = item.indicatorKey,
            objectKey = item.indicatorKey,
            elementKey = item.elementKey,
            sectionKey = "indicators",
        }, item.level, item.movesUnit)
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
            unit = frame._fpUnit,
            decorationId = decorationId,
            objectKey = decorationId,
            sectionKey = "decoration",
        }, 60, true)
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
            unit = frame._fpUnit,
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
            unit = frame._fpUnit,
            sectionKey = "frame",
        }
    end

    local active = CanvasHoverOverlay.IsEditorActive() and overlay and overlay:IsShown()
    if not active then
        local zones = frame._focalPointCanvasHoverZones
        if type(zones) == "table" then
            for _, zone in pairs(zones) do
                HideZoneFrame(zone)
                SetZoneMouseEnabled(zone, false)
            end
        end
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
