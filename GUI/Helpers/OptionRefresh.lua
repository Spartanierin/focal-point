local _, PORTRAIT = ...

PORTRAIT.GUI = PORTRAIT.GUI or {}
PORTRAIT.GUI.Helpers = PORTRAIT.GUI.Helpers or {}

local OptionRefresh = {}

PORTRAIT.GUI.Helpers.OptionRefresh = OptionRefresh

function OptionRefresh.GUI()
    if PORTRAIT.GUI and PORTRAIT.GUI.RefreshOptions then
        PORTRAIT.GUI:RefreshOptions()
    end
end

function OptionRefresh.Frames()
    if PORTRAIT.RefreshAllFrames then
        PORTRAIT:RefreshAllFrames()
    end
end

function OptionRefresh.Preview()
    if PORTRAIT.TestEnvironment and PORTRAIT.TestEnvironment.Refresh then
        PORTRAIT.TestEnvironment:Refresh()
    end
end

function OptionRefresh.All()
    OptionRefresh.GUI()
    OptionRefresh.Frames()
    OptionRefresh.Preview()
end

return OptionRefresh