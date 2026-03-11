local _, ns = ...

local AceGUI = LibStub("AceGUI-3.0")

ns.GUI = ns.GUI or {}
ns.GUI.Widgets = ns.GUI.Widgets or {}

local Widgets = ns.GUI.Widgets

function Widgets.CreateSectionHeader(text)
    local group = AceGUI:Create("SimpleGroup")
    group:SetFullWidth(true)
    group:SetHeight(26)

    local fs = group.frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    fs:SetPoint("LEFT", group.frame, "LEFT", 0, 0)
    fs:SetPoint("RIGHT", group.frame, "RIGHT", 0, 0)
    fs:SetJustifyH("LEFT")
    fs:SetText("|cffFFD100" .. text .. "|r")
    fs:SetFont(STANDARD_TEXT_FONT, 18, "")

    local line = group.frame:CreateTexture(nil, "ARTWORK")
    line:SetHeight(1)
    line:SetPoint("BOTTOMLEFT", group.frame, "BOTTOMLEFT", 0, 0)
    line:SetPoint("BOTTOMRIGHT", group.frame, "BOTTOMRIGHT", 0, 0)
    line:SetColorTexture(1, 0.82, 0, 0.35)

    return group
end