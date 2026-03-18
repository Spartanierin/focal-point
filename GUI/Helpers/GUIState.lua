local _, ns = ...

ns.GUI = ns.GUI or {}
ns.GUI.Helpers = ns.GUI.Helpers or {}
ns.GUI.Helpers.GUIState = ns.GUI.Helpers.GUIState or {}

local GUIState = ns.GUI.Helpers.GUIState

function GUIState.GetState()
    ns.GUI._state = ns.GUI._state or {
        unitTabs = {},
        unitScroll = {},
        unitBarTabs = {},
        unitBarScroll = {},
        unitTextTabs = {},
        unitTextScroll = {},
        unitElementTabs = {},
        unitElementScroll = {},
        textBuilder = {
            template = "[hp:cur:abbr]/[hp:max:abbr] | [hp:perc]%",
        },
    }

    return ns.GUI._state
end
