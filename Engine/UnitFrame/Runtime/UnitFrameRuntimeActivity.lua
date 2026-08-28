local _, FocalPoint = ...

FocalPoint.UnitFrameRuntimeActivity = FocalPoint.UnitFrameRuntimeActivity or {}
local RuntimeActivity = FocalPoint.UnitFrameRuntimeActivity

local Utils = FocalPoint.UnitFrameUtils or {}

local function NormalizeUnitKey(unit)
    if type(unit) ~= "string" or unit == "" then
        return nil
    end
    if unit:match("^boss%d+$") then
        return "boss"
    end
    return unit
end

local function GetUnitConfig(frame)
    if type(frame) ~= "table" then
        return nil
    end
    if type(frame.config) == "table" then
        return frame.config
    end
    if Utils.GetUnitDB then
        return Utils.GetUnitDB(NormalizeUnitKey(frame.unit))
    end
    return nil
end

local function BuildBarRef(frame, objectKey)
    local unit = NormalizeUnitKey(frame and frame.unit)
    if not unit or type(objectKey) ~= "string" or objectKey == "" then
        return nil
    end
    return {
        kind = "bar",
        unit = unit,
        objectKey = objectKey,
    }
end

function RuntimeActivity.ShouldRunComponent(frame, objectRef)
    local unitConfig = GetUnitConfig(frame)
    if type(unitConfig) ~= "table" then
        return false
    end

    if type(objectRef) == "string" then
        objectRef = BuildBarRef(frame, objectRef)
    end
    if type(objectRef) ~= "table" then
        return false
    end

    local Presence = FocalPoint.CompositionPresence
    if Presence and type(Presence.IsPresent) == "function" then
        return Presence.IsPresent(unitConfig, objectRef) == true
    end

    return true
end

function RuntimeActivity.ClearComponentVisual(frame, objectKey)
    local element = frame and frame.Elements and frame.Elements[objectKey]
    if not element then
        return false
    end
    if element.SetMinMaxValues then
        element:SetMinMaxValues(0, 1)
    end
    if element.SetValue then
        element:SetValue(0)
    end
    if element.bg and element.bg.Hide then
        element.bg:Hide()
    end
    if element.icon then
        if element.icon.SetTexture then
            element.icon:SetTexture(nil)
        end
        if element.icon.Hide then
            element.icon:Hide()
        end
    end
    if element.Hide then
        element:Hide()
    end
    return true
end

return RuntimeActivity
