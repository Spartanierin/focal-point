local _, FocalPoint = ...

FocalPoint.AuraBackendResolver = FocalPoint.AuraBackendResolver or {}
local Resolver = FocalPoint.AuraBackendResolver

local MANAGED_UNIT = "player"
local MANAGED_GROUPS = {
    Buffs = true,
    Debuffs = true,
}

local function GetManagedBackend()
    return FocalPoint.ManagedAuraBackend or {}
end

function Resolver.CanUseManagedPlayerGroup(frame, groupKey)
    if not frame or frame.unit ~= MANAGED_UNIT or MANAGED_GROUPS[groupKey] ~= true then
        return false
    end

    local Demo = FocalPoint.UnitFrameDemoEnvironment or {}
    if Demo.IsFrameInDemoMode and Demo.IsFrameInDemoMode(frame) then
        return false
    end

    local Preview = FocalPoint.UnitFramePreview or {}
    if Preview.GetTestAuras and Preview.GetTestAuras(frame, groupKey) ~= nil then
        return false
    end

    local backend = GetManagedBackend()
    if not (backend.IsAvailable and backend.IsAvailable() == true) then
        return false
    end

    if backend.IsGroupAvailable then
        return backend.IsGroupAvailable(groupKey) == true
    end

    return true
end

function Resolver.CanUseManagedPlayerBuffs(frame, groupKey)
    return groupKey == "Buffs" and Resolver.CanUseManagedPlayerGroup(frame, groupKey) == true
end

function Resolver.IsManagedGroupActive(frame, groupKey, config)
    if not Resolver.CanUseManagedPlayerGroup(frame, groupKey) then
        return false
    end

    if config and config.enabled == false then
        return false
    end

    local backend = GetManagedBackend()
    return backend.IsGroupActive and backend.IsGroupActive(frame, groupKey) == true
end

function Resolver.EnsureManagedGroup(frame, groupKey, config)
    if not Resolver.CanUseManagedPlayerGroup(frame, groupKey) then
        return false
    end

    if config and config.enabled == false then
        local backend = GetManagedBackend()
        if backend.ClearGroup then
            backend.ClearGroup(frame, groupKey)
        end
        return false
    end

    local backend = GetManagedBackend()
    if backend.EnsureGroup then
        return backend.EnsureGroup(frame, groupKey, config) == true
    end

    return false
end

function Resolver.RefreshManagedGroup(frame, groupKey, config)
    if not Resolver.EnsureManagedGroup(frame, groupKey, config) then
        return false
    end

    local backend = GetManagedBackend()
    if backend.RefreshGroup then
        return backend.RefreshGroup(frame, groupKey, config) == true
    end

    return true
end

function Resolver.ClearManagedGroup(frame, groupKey)
    local backend = GetManagedBackend()
    if backend.ClearGroup then
        backend.ClearGroup(frame, groupKey)
    end
end
