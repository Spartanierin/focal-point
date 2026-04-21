local addonName, ns = ...

ns.GUI = ns.GUI or {}
ns.GUI.Helpers = ns.GUI.Helpers or {}
ns.GUI.Helpers.GUIRuntimeHelpers = ns.GUI.Helpers.GUIRuntimeHelpers or {}

local C = ns.Constants

local GUIRuntimeHelpers = ns.GUI.Helpers.GUIRuntimeHelpers

function GUIRuntimeHelpers.ResetFlowContainer(container)
    container:ReleaseChildren()
    container:SetLayout("Flow")
end

function GUIRuntimeHelpers.GetAddonVersionText()
    local tried = {}
    local addonKeys = {
        addonName,
        C.ADDON_NAME,
    }

    local function TryMetadata(addonKey)
        if type(addonKey) ~= "string" or addonKey == "" or tried[addonKey] then
            return nil
        end

        tried[addonKey] = true

        if C_AddOns and C_AddOns.GetAddOnMetadata then
            local version = C_AddOns.GetAddOnMetadata(addonKey, "Version")
            if type(version) == "string" and version ~= "" then
                return version
            end
        end

        if GetAddOnMetadata then
            local version = GetAddOnMetadata(addonKey, "Version")
            if type(version) == "string" and version ~= "" then
                return version
            end
        end

        return nil
    end

    for _, addonKey in ipairs(addonKeys) do
        local version = TryMetadata(addonKey)
        if version then
            return version
        end
    end

    return "dev"
end
