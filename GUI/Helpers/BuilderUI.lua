local addonName, ns = ...

ns.GUI = ns.GUI or {}
ns.GUI.Helpers = ns.GUI.Helpers or {}
ns.GUI.Helpers.BuilderUI = ns.GUI.Helpers.BuilderUI or {}
ns.GUI.Helpers.TitleStyles = ns.GUI.Helpers.TitleStyles or {}

local C = ns.Constants
local TextStyles = ns.GUI.Helpers.TextStyles

local BuilderUI = ns.GUI.Helpers.BuilderUI
local TitleStyles = ns.GUI.Helpers.TitleStyles

function TitleStyles.FormatPage(text)
    return TextStyles and TextStyles.Wrap and TextStyles.Wrap(text, "sectionHeader") or text
end

function TitleStyles.FormatGroup(text)
    return TextStyles and TextStyles.Wrap and TextStyles.Wrap(text, "sectionHeader") or text
end

function TitleStyles.FormatSubsection(text)
    return TextStyles and TextStyles.Wrap and TextStyles.Wrap(text, "label") or text
end

function BuilderUI.ResetFlowContainer(container)
    container:ReleaseChildren()
    container:SetLayout("Flow")
end

function BuilderUI.GetAddonVersionText()
    local tried = {}
    local addonKeys = {
        addonName,
        C.ADDON_NAME,
        "Portrait",
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
