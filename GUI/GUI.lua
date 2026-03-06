local _, Portrait = ...

function Portrait:CreateGUI()
    if self.guiFrame then
        self.guiFrame:Show()
        return
    end

    local AceGUI = LibStub("AceGUI-3.0")
    local frame = AceGUI:Create("Frame")
    frame:SetTitle("Portrait")
    frame:SetStatusText("Test GUI")
    frame:SetLayout("Flow")
    frame:SetWidth(400)
    frame:SetHeight(220)

    local slider = AceGUI:Create("Slider")
    slider:SetLabel("Name Font Size")
    slider:SetSliderValues(6, 32, 1)
    slider:SetValue(self.db.profile.Units.player.nameFontSize or 12)
    slider:SetFullWidth(true)
    slider:SetCallback("OnValueChanged", function(_, _, value)
        value = math.floor(value + 0.5)
        Portrait.db.profile.Units.player.nameFontSize = value
        Portrait:RefreshUnitFrame("player")
    end)

    frame:AddChild(slider)

    self.guiFrame = frame
end