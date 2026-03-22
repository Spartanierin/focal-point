local addonName, ns = ...

ns.GUI = ns.GUI or {}
ns.GUI.Helpers = ns.GUI.Helpers or {}
ns.GUI.Helpers.BuilderUI = ns.GUI.Helpers.BuilderUI or {}
ns.GUI.Helpers.TitleStyles = ns.GUI.Helpers.TitleStyles or {}

local AceGUI = LibStub("AceGUI-3.0")
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

function BuilderUI.AddSectionHeading(container, text, topSpacing, headerAction)
    if not container then
        return
    end

    container._focalPointPendingSectionTitle = text
    container._focalPointPendingSectionTopSpacing = topSpacing or 0
    container._focalPointPendingSectionHeaderAction = headerAction
end

function BuilderUI.AddPageHeading(container, text, subtitle)
    local headerGroup = AceGUI:Create("SimpleGroup")
    headerGroup:SetFullWidth(true)
    headerGroup:SetLayout("Flow")

    local heading = AceGUI:Create("Label")
    heading:SetFullWidth(true)
    heading:SetText(text or "")
    if heading.label and heading.label.SetJustifyH then
        heading.label:SetJustifyH("CENTER")
    end
    if TextStyles and TextStyles.ApplyLabelWidget then
        TextStyles.ApplyLabelWidget(heading, "label", { size = 15, shadow = true })
    end
    headerGroup:AddChild(heading)

    if type(subtitle) == "string" and subtitle ~= "" then
        local subtitleLabel = AceGUI:Create("Label")
        subtitleLabel:SetFullWidth(true)
        subtitleLabel:SetText(subtitle)
        if subtitleLabel.label and subtitleLabel.label.SetJustifyH then
            subtitleLabel.label:SetJustifyH("CENTER")
        end
        if TextStyles and TextStyles.ApplyLabelWidget then
            TextStyles.ApplyLabelWidget(subtitleLabel, "help", { size = 11 })
        end
        headerGroup:AddChild(subtitleLabel)
    end

    container:AddChild(headerGroup)
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
