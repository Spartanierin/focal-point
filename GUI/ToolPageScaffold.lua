local _, ns = ...

ns.GUI = ns.GUI or {}

local AceGUI = LibStub("AceGUI-3.0")
local ToolPageScaffold = {}
ns.GUI.ToolPageScaffold = ToolPageScaffold

function ToolPageScaffold.Render(container, buildFunc)
    if type(buildFunc) ~= "function" then
        return
    end

    container:ReleaseChildren()
    container:SetLayout("Fill")

    local toolHost = AceGUI:Create("SimpleGroup")
    toolHost:SetFullWidth(true)
    toolHost:SetFullHeight(true)
    toolHost:SetLayout("Fill")
    container:AddChild(toolHost)

    local toolPanel = AceGUI:Create("SimpleGroup")
    toolPanel:SetFullWidth(false)
    toolPanel:SetFullHeight(false)
    toolPanel:SetLayout("Flow")
    toolHost:AddChild(toolPanel)

    local toolContent = AceGUI:Create("SimpleGroup")
    toolContent:SetFullWidth(true)
    toolContent:SetFullHeight(true)
    toolContent:SetLayout("Flow")
    toolPanel:AddChild(toolContent)

    local function PositionToolPanel()
        if not toolHost.frame or not toolPanel.frame then
            return
        end

        local hostWidth = toolHost.frame:GetWidth() or 0
        local hostHeight = toolHost.frame:GetHeight() or 0

        local panelWidth = math.min(math.max(hostWidth - 120, 720), 860)
        local panelHeight = math.min(math.max(hostHeight - 84, 580), 780)

        toolPanel:SetWidth(panelWidth)
        toolPanel:SetHeight(panelHeight)
        toolPanel.frame:ClearAllPoints()
        toolPanel.frame:SetPoint("TOP", toolHost.frame, "TOP", 0, -40)

        if toolContent.frame then
            toolContent.frame:ClearAllPoints()
            toolContent.frame:SetPoint("TOPLEFT", toolPanel.frame, "TOPLEFT", 18, -18)
            toolContent.frame:SetPoint("BOTTOMRIGHT", toolPanel.frame, "BOTTOMRIGHT", -18, 18)
        end
    end

    if toolPanel.frame then
        PositionToolPanel()

        local bg = toolPanel.frame:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints()
        bg:SetColorTexture(0.06, 0.07, 0.09, 0.90)
        toolPanel._panelBg = bg

        local border = toolPanel.frame:CreateTexture(nil, "BORDER")
        border:SetAllPoints()
        border:SetColorTexture(0, 0, 0, 0)
        toolPanel._panelBorder = border

        local leftEdge = toolPanel.frame:CreateTexture(nil, "BORDER")
        leftEdge:SetPoint("TOPLEFT")
        leftEdge:SetPoint("BOTTOMLEFT")
        leftEdge:SetWidth(1)
        leftEdge:SetColorTexture(0.16, 0.19, 0.24, 0.95)
        toolPanel._leftEdge = leftEdge

        local rightEdge = toolPanel.frame:CreateTexture(nil, "BORDER")
        rightEdge:SetPoint("TOPRIGHT")
        rightEdge:SetPoint("BOTTOMRIGHT")
        rightEdge:SetWidth(1)
        rightEdge:SetColorTexture(0.16, 0.19, 0.24, 0.95)
        toolPanel._rightEdge = rightEdge

        local topEdge = toolPanel.frame:CreateTexture(nil, "BORDER")
        topEdge:SetPoint("TOPLEFT")
        topEdge:SetPoint("TOPRIGHT")
        topEdge:SetHeight(1)
        topEdge:SetColorTexture(0.20, 0.23, 0.28, 0.95)
        toolPanel._topEdge = topEdge

        local accent = toolPanel.frame:CreateTexture(nil, "ARTWORK")
        accent:SetPoint("TOPLEFT", toolPanel.frame, "TOPLEFT", 0, 0)
        accent:SetPoint("TOPRIGHT", toolPanel.frame, "TOPRIGHT", 0, 0)
        accent:SetHeight(2)
        accent:SetColorTexture(0.78, 0.65, 0.24, 0.65)
        toolPanel._accent = accent

        local bottomEdge = toolPanel.frame:CreateTexture(nil, "BORDER")
        bottomEdge:SetPoint("BOTTOMLEFT")
        bottomEdge:SetPoint("BOTTOMRIGHT")
        bottomEdge:SetHeight(1)
        bottomEdge:SetColorTexture(0.10, 0.12, 0.15, 0.95)
        toolPanel._bottomEdge = bottomEdge
    end

    toolPanel:SetLayout("Flow")
    buildFunc(toolContent)

    PositionToolPanel()
    if C_Timer and C_Timer.After then
        C_Timer.After(0, PositionToolPanel)
        C_Timer.After(0.05, PositionToolPanel)
    end
end

return ToolPageScaffold
