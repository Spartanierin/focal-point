local addonName, ns = ...

ns.GUI = ns.GUI or {}
ns.GUI.Helpers = ns.GUI.Helpers or {}
ns.GUI.Helpers.BuilderUI = ns.GUI.Helpers.BuilderUI or {}
ns.GUI.Helpers.TitleStyles = ns.GUI.Helpers.TitleStyles or {}

local AceGUI = LibStub("AceGUI-3.0")
local C = ns.Constants

local BuilderUI = ns.GUI.Helpers.BuilderUI
local TitleStyles = ns.GUI.Helpers.TitleStyles

local function WrapColor(text, color)
    if type(text) ~= "string" or text == "" then
        return text or ""
    end

    return string.format("|cff%s%s|r", color, text)
end

function TitleStyles.FormatPage(text)
    return WrapColor(text, "d8c27a")
end

function TitleStyles.FormatGroup(text)
    return WrapColor(text, "e7dcc4")
end

function TitleStyles.FormatSubsection(text)
    return WrapColor(text, "8fa8bf")
end

function BuilderUI.AddSectionHeading(container, text, topSpacing)
    local spacer = AceGUI:Create("Label")
    spacer:SetText(" ")
    spacer:SetFullWidth(true)
    spacer:SetHeight(topSpacing or 0)
    container:AddChild(spacer)

    local heading = AceGUI:Create("Heading")
    heading:SetText(TitleStyles.FormatGroup(text))
    heading:SetFullWidth(true)
    container:AddChild(heading)
end

function BuilderUI.AddPageHeading(container, text)
    local heading = AceGUI:Create("Heading")
    heading:SetFullWidth(true)
    heading:SetText(TitleStyles.FormatPage(text))
    container:AddChild(heading)
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
