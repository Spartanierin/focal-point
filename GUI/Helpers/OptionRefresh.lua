local _, FocalPoint = ...

FocalPoint.GUI = FocalPoint.GUI or {}
FocalPoint.GUI.Helpers = FocalPoint.GUI.Helpers or {}

local OptionRefresh = {}
local registeredStateWidgets = {}

FocalPoint.GUI.Helpers.OptionRefresh = OptionRefresh

function OptionRefresh.RegisterStateWidget(widget)
    if not widget or type(widget.RefreshState) ~= "function" then
        return
    end

    table.insert(registeredStateWidgets, widget)
end

function OptionRefresh.ClearStateWidgets()
    wipe(registeredStateWidgets)
end

function OptionRefresh.RefreshStateWidgets()
    local hadWidgets = false

    for i = #registeredStateWidgets, 1, -1 do
        local widget = registeredStateWidgets[i]

        if not widget or type(widget.RefreshState) ~= "function" then
            table.remove(registeredStateWidgets, i)
        else
            hadWidgets = true
            pcall(widget.RefreshState)
        end
    end

    return hadWidgets
end

function OptionRefresh.GUI()
    if OptionRefresh.RefreshStateWidgets() then
        return
    end

    if FocalPoint.GUI and FocalPoint.GUI.RefreshOptions then
        FocalPoint.GUI:RefreshOptions()
    end
end

function OptionRefresh.Frames()
    if FocalPoint.RefreshAllFrames then
        FocalPoint:RefreshAllFrames()
    end
end

function OptionRefresh.Preview()
    if FocalPoint.TestEnvironment and FocalPoint.TestEnvironment.Refresh then
        FocalPoint.TestEnvironment:Refresh()
    end
end

function OptionRefresh.Live()
    OptionRefresh.Frames()
    OptionRefresh.Preview()
end

function OptionRefresh.All()
    OptionRefresh.GUI()
    OptionRefresh.Frames()
    OptionRefresh.Preview()
end

return OptionRefresh