local _, FocalPoint = ...

FocalPoint.GUI = FocalPoint.GUI or {}
FocalPoint.GUI.Editor = FocalPoint.GUI.Editor or {}

local Mutations = {}
FocalPoint.GUI.Editor.FrameMutations = Mutations

local POSITION_KEYS = { "point", "relativeTo", "relativePoint", "x", "y" }
local SIZE_KEYS = { "width", "height" }
local ALIGN_MODES = {
    left = true,
    right = true,
    top = true,
    bottom = true,
    horizontalCenter = true,
    verticalCenter = true,
}

local function CopyValue(value)
    if type(value) == "table" then
        return CopyTable and CopyTable(value) or value
    end

    return value
end

local function NormalizeUnitKey(unitKey)
    local utils = FocalPoint.UnitFrameUtils
    if utils and utils.NormalizeConfigUnitKey then
        return utils.NormalizeConfigUnitKey(unitKey)
    end
    if type(unitKey) ~= "string" or unitKey == "" then
        return nil
    end
    if unitKey:match("^boss%d+$") then
        return "boss"
    end
    return unitKey
end

local function BuildUnitOrderIndex()
    local index = {}
    local unitOrder = FocalPoint.Constants and FocalPoint.Constants.UnitOrder or {}
    for order, unitKey in ipairs(unitOrder) do
        local normalizedUnit = NormalizeUnitKey(unitKey)
        if normalizedUnit and index[normalizedUnit] == nil then
            index[normalizedUnit] = order
        end
    end

    return index
end

local UNIT_ORDER_INDEX = BuildUnitOrderIndex()

local function CompareUnitKeys(left, right)
    local leftOrder = UNIT_ORDER_INDEX[left]
    local rightOrder = UNIT_ORDER_INDEX[right]
    if leftOrder and rightOrder and leftOrder ~= rightOrder then
        return leftOrder < rightOrder
    end
    if leftOrder then
        return true
    end
    if rightOrder then
        return false
    end

    return tostring(left) < tostring(right)
end

local function GetUnitConfig(unitKey)
    local normalizedUnit = NormalizeUnitKey(unitKey)
    if not normalizedUnit then
        return nil, nil
    end

    local utils = FocalPoint.UnitFrameUtils
    if utils and utils.GetUnitDB then
        return utils.GetUnitDB(normalizedUnit), normalizedUnit
    end

    return nil, normalizedUnit
end

local function GetDefaultUnitConfig(unitKey)
    local normalizedUnit = NormalizeUnitKey(unitKey)
    if not normalizedUnit or not FocalPoint.GetDefaultDB then
        return nil
    end

    local defaults = FocalPoint:GetDefaultDB()
    return defaults
        and defaults.profile
        and defaults.profile.Units
        and defaults.profile.Units[normalizedUnit]
end

local function NormalizeUnits(units)
    local result = {}
    local seen = {}

    if type(units) == "string" then
        units = { units }
    end
    if type(units) ~= "table" then
        return result
    end

    for _, unitKey in ipairs(units) do
        local normalizedUnit = NormalizeUnitKey(unitKey)
        if normalizedUnit and not seen[normalizedUnit] then
            seen[normalizedUnit] = true
            result[#result + 1] = normalizedUnit
        end
    end

    table.sort(result, CompareUnitKeys)
    return result
end

local function IsWriteBlockedInCombat()
    return InCombatLockdown and InCombatLockdown()
end

local function ValidateUnits(units)
    local normalizedUnits = NormalizeUnits(units)
    if #normalizedUnits == 0 then
        return nil, "invalid_units"
    end

    local entries = {}
    for _, unitKey in ipairs(normalizedUnits) do
        local config = GetUnitConfig(unitKey)
        local defaults = GetDefaultUnitConfig(unitKey)
        if type(config) ~= "table" or type(defaults) ~= "table" then
            return nil, "invalid_unit"
        end
        entries[#entries + 1] = {
            unit = unitKey,
            config = config,
            defaults = defaults,
        }
    end

    return entries
end

local function RefreshUnits(units)
    if FocalPoint.RefreshUnitFrame then
        for _, unitKey in ipairs(units) do
            FocalPoint:RefreshUnitFrame(unitKey)
        end
    elseif FocalPoint.RefreshAllUnitFrames then
        FocalPoint:RefreshAllUnitFrames()
    end

    if FocalPoint.GUI and FocalPoint.GUI.RequestRefreshOptions then
        FocalPoint.GUI:RequestRefreshOptions()
    end

    if FocalPoint.RefreshEditorSelectionVisuals then
        FocalPoint:RefreshEditorSelectionVisuals()
    end

    local snapLines = FocalPoint.GUI
        and FocalPoint.GUI.Editor
        and FocalPoint.GUI.Editor.FrameSnapLines
    if snapLines and snapLines.Hide then
        snapLines.Hide()
    end
end

local function GetSelectedUnits()
    local editorState = FocalPoint.GUI
        and FocalPoint.GUI.Editor
        and FocalPoint.GUI.Editor.State
        or nil

    if editorState and editorState.GetSelectedUnits then
        return editorState.GetSelectedUnits()
    end

    return {}
end

local function GetPrimaryUnit()
    local editorState = FocalPoint.GUI
        and FocalPoint.GUI.Editor
        and FocalPoint.GUI.Editor.State
        or nil

    if editorState and editorState.GetPrimaryUnit then
        return NormalizeUnitKey(editorState.GetPrimaryUnit())
    end

    return nil
end

local function ResolveFrameForUnit(unitKey)
    local normalizedUnit = NormalizeUnitKey(unitKey)
    if not normalizedUnit or not FocalPoint.frames then
        return nil
    end

    if normalizedUnit == "boss" then
        local fallbackFrame = nil
        for bossIndex = 1, 5 do
            local bossFrame = FocalPoint.frames["boss" .. bossIndex]
            if bossFrame then
                fallbackFrame = fallbackFrame or bossFrame
                if bossFrame.IsShown and bossFrame:IsShown() then
                    return bossFrame
                end
            end
        end
        return fallbackFrame
    end

    return FocalPoint.frames[normalizedUnit]
end

local function IsFiniteNumber(value)
    return type(value) == "number" and value == value and value ~= math.huge and value ~= -math.huge
end

local function ReadFrameGeometry(frame)
    if not frame
        or not frame.GetLeft
        or not frame.GetRight
        or not frame.GetTop
        or not frame.GetBottom
        or not frame.GetCenter
        or not frame.GetWidth
        or not frame.GetHeight
    then
        return nil
    end

    local okLeft, left = pcall(frame.GetLeft, frame)
    local okRight, right = pcall(frame.GetRight, frame)
    local okTop, top = pcall(frame.GetTop, frame)
    local okBottom, bottom = pcall(frame.GetBottom, frame)
    local okCenter, centerX, centerY = pcall(frame.GetCenter, frame)
    local okWidth, width = pcall(frame.GetWidth, frame)
    local okHeight, height = pcall(frame.GetHeight, frame)
    if not (okLeft and okRight and okTop and okBottom and okCenter and okWidth and okHeight) then
        return nil
    end

    if not (IsFiniteNumber(left)
        and IsFiniteNumber(right)
        and IsFiniteNumber(top)
        and IsFiniteNumber(bottom)
        and IsFiniteNumber(centerX)
        and IsFiniteNumber(centerY)
        and IsFiniteNumber(width)
        and IsFiniteNumber(height))
    then
        return nil
    end

    return {
        left = left,
        right = right,
        top = top,
        bottom = bottom,
        centerX = centerX,
        centerY = centerY,
        width = width,
        height = height,
    }
end

local function GetAlignmentDelta(primaryGeometry, secondaryGeometry, mode)
    if mode == "left" then
        return primaryGeometry.left - secondaryGeometry.left, 0
    elseif mode == "right" then
        return primaryGeometry.right - secondaryGeometry.right, 0
    elseif mode == "top" then
        return 0, primaryGeometry.top - secondaryGeometry.top
    elseif mode == "bottom" then
        return 0, primaryGeometry.bottom - secondaryGeometry.bottom
    elseif mode == "horizontalCenter" then
        return primaryGeometry.centerX - secondaryGeometry.centerX, 0
    elseif mode == "verticalCenter" then
        return 0, primaryGeometry.centerY - secondaryGeometry.centerY
    end

    return nil, nil
end

local function SetFrameCenter(frame, centerX, centerY)
    if not (frame and frame.ClearAllPoints and frame.SetPoint and UIParent) then
        return false
    end

    frame:ClearAllPoints()
    frame:SetPoint("CENTER", UIParent, "BOTTOMLEFT", centerX, centerY)
    return true
end

local function ValidateAlignment(units, primaryUnit, mode)
    if not ALIGN_MODES[mode] then
        return nil, "invalid_mode"
    end
    if not FocalPoint.SaveFramePosition then
        return nil, "position_helper_unavailable"
    end

    local normalizedUnits = NormalizeUnits(units)
    local normalizedPrimary = NormalizeUnitKey(primaryUnit)
    if #normalizedUnits < 2 or not normalizedPrimary then
        return nil, "invalid_selection", normalizedUnits
    end

    local primarySelected = false
    for _, unitKey in ipairs(normalizedUnits) do
        if unitKey == normalizedPrimary then
            primarySelected = true
            break
        end
    end
    if not primarySelected then
        return nil, "invalid_primary", normalizedUnits
    end

    local primaryFrame = ResolveFrameForUnit(normalizedPrimary)
    local primaryGeometry = ReadFrameGeometry(primaryFrame)
    if not primaryGeometry then
        return nil, "geometry_unavailable", normalizedUnits
    end

    local entries = {}
    for _, unitKey in ipairs(normalizedUnits) do
        if unitKey ~= normalizedPrimary then
            local config = GetUnitConfig(unitKey)
            if type(config) ~= "table" then
                return nil, "invalid_unit", normalizedUnits
            end

            local frame = ResolveFrameForUnit(unitKey)
            local geometry = ReadFrameGeometry(frame)
            if not geometry or not (frame.ClearAllPoints and frame.SetPoint and UIParent) then
                return nil, "geometry_unavailable", normalizedUnits
            end

            local deltaX, deltaY = GetAlignmentDelta(primaryGeometry, geometry, mode)
            if not (IsFiniteNumber(deltaX) and IsFiniteNumber(deltaY)) then
                return nil, "geometry_unavailable", normalizedUnits
            end

            entries[#entries + 1] = {
                unit = unitKey,
                frame = frame,
                centerX = geometry.centerX + deltaX,
                centerY = geometry.centerY + deltaY,
            }
        end
    end

    if #entries == 0 then
        return nil, "invalid_selection", normalizedUnits
    end

    return {
        units = normalizedUnits,
        primaryUnit = normalizedPrimary,
        entries = entries,
    }
end

local function AlignEntries(alignment)
    local refreshedUnits = {}
    local seen = {}

    for _, entry in ipairs(alignment.entries) do
        if not SetFrameCenter(entry.frame, entry.centerX, entry.centerY) then
            return nil, "geometry_unavailable"
        end

        FocalPoint.SaveFramePosition(entry.frame)

        if not seen[entry.unit] then
            seen[entry.unit] = true
            refreshedUnits[#refreshedUnits + 1] = entry.unit
        end
    end

    return refreshedUnits
end

local function ResetEntries(entries, keys)
    for _, entry in ipairs(entries) do
        for _, key in ipairs(keys) do
            if entry.defaults[key] ~= nil then
                entry.config[key] = CopyValue(entry.defaults[key])
            end
        end
    end
end

local function ResetUnits(units, keys)
    if IsWriteBlockedInCombat() then
        return {
            ok = false,
            reason = "combat",
            units = NormalizeUnits(units),
            count = 0,
        }
    end

    local entries, reason = ValidateUnits(units)
    if not entries then
        return {
            ok = false,
            reason = reason,
            units = NormalizeUnits(units),
            count = 0,
        }
    end

    ResetEntries(entries, keys)

    local refreshedUnits = {}
    for _, entry in ipairs(entries) do
        refreshedUnits[#refreshedUnits + 1] = entry.unit
    end
    RefreshUnits(refreshedUnits)

    return {
        ok = true,
        units = refreshedUnits,
        count = #refreshedUnits,
    }
end

function Mutations.ResetUnitPosition(unitKey)
    return Mutations.ResetUnitsPosition({ unitKey })
end

function Mutations.ResetUnitSize(unitKey)
    return Mutations.ResetUnitsSize({ unitKey })
end

function Mutations.ResetUnitsPosition(units)
    return ResetUnits(units, POSITION_KEYS)
end

function Mutations.ResetUnitsSize(units)
    return ResetUnits(units, SIZE_KEYS)
end

function Mutations.AlignUnits(units, primaryUnit, mode)
    if IsWriteBlockedInCombat() then
        return {
            ok = false,
            reason = "combat",
            units = NormalizeUnits(units),
            primaryUnit = NormalizeUnitKey(primaryUnit),
            count = 0,
        }
    end

    local alignment, reason, normalizedUnits = ValidateAlignment(units, primaryUnit, mode)
    if not alignment then
        return {
            ok = false,
            reason = reason,
            units = normalizedUnits or NormalizeUnits(units),
            primaryUnit = NormalizeUnitKey(primaryUnit),
            count = 0,
        }
    end

    local refreshedUnits, applyReason = AlignEntries(alignment)
    if not refreshedUnits then
        return {
            ok = false,
            reason = applyReason or "alignment_failed",
            units = alignment.units,
            primaryUnit = alignment.primaryUnit,
            count = 0,
        }
    end

    RefreshUnits(refreshedUnits)

    return {
        ok = true,
        units = refreshedUnits,
        primaryUnit = alignment.primaryUnit,
        count = #refreshedUnits,
    }
end

function Mutations.AlignSelectedUnits(mode)
    return Mutations.AlignUnits(GetSelectedUnits(), GetPrimaryUnit(), mode)
end

return Mutations
