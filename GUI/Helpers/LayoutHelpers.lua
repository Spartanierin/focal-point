local _, ns = ...

ns.GUI = ns.GUI or {}
ns.GUI.Helpers = ns.GUI.Helpers or {}

local AceGUI = LibStub("AceGUI-3.0")

local LayoutHelpers = {}
ns.GUI.Helpers.LayoutHelpers = LayoutHelpers

function LayoutHelpers.BuildScrollableTabContent(widget, statusTable, buildFunc)
    widget:ReleaseChildren()
    widget:SetLayout("Fill")
    widget._focalPointScrollBuildSerial = (widget._focalPointScrollBuildSerial or 0) + 1
    local buildSerial = widget._focalPointScrollBuildSerial

    local scroll = AceGUI:Create("ScrollFrame")
    scroll:SetLayout("Flow")
    scroll:SetFullWidth(true)
    scroll:SetFullHeight(true)
    scroll:SetStatusTable(statusTable)
    widget:AddChild(scroll)

    buildFunc(scroll)

    if scroll.DoLayout then
        scroll:DoLayout()
    end

    if scroll.FixScroll then
        scroll:FixScroll()
    end

    if widget.DoLayout then
        widget:DoLayout()
    end

    if C_Timer and C_Timer.After then
        C_Timer.After(0, function()
            if not widget or widget._focalPointScrollBuildSerial ~= buildSerial then
                return
            end

            if not widget.children or widget.children[1] ~= scroll then
                return
            end

            if scroll and scroll.DoLayout then
                scroll:DoLayout()
            end

            if scroll and scroll.FixScroll then
                scroll:FixScroll()
            end

            if widget and widget.DoLayout then
                widget:DoLayout()
            end
        end)
    end
end
