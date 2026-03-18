local _, ns = ...

ns.GUI = ns.GUI or {}
ns.GUI.Pages = ns.GUI.Pages or {}
ns.GUI.Pages.Shared = ns.GUI.Pages.Shared or {}
ns.GUI.Pages.Shared.Placeholder = ns.GUI.Pages.Shared.Placeholder or {}

local AceGUI = LibStub("AceGUI-3.0")
local L = ns.L

local Page = ns.GUI.Pages.Shared.Placeholder

function Page.Build(container, title)
    container:ReleaseChildren()
    container:SetLayout("Fill")

    local label = AceGUI:Create("Label")
    if title and title ~= "" then
        label:SetText(title .. " - " .. L["INFO_NOT_IMPLEMENTED_YET"])
    else
        label:SetText(L["INFO_NOT_IMPLEMENTED_YET"])
    end
    label:SetFullWidth(true)
    container:AddChild(label)
end
