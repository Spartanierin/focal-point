local _, ns = ...

ns.GUI = ns.GUI or {}
ns.GUI.Pages = ns.GUI.Pages or {}

local AceGUI = LibStub("AceGUI-3.0")
local EditorPage = {}
ns.GUI.Pages.Editor = EditorPage

function EditorPage.Release()
    local controller = ns.GUI and ns.GUI.Editor and ns.GUI.Editor.Controller
    if controller and controller.ReleaseInspector then
        controller.ReleaseInspector()
    end
end

function EditorPage.Build(container, deps)
    EditorPage.Release()
    deps.ResetFlowContainer(container)
    local controller = ns.GUI and ns.GUI.Editor and ns.GUI.Editor.Controller
    if controller and controller.BuildInspector then
        controller.BuildInspector(container, deps)
        return
    end
end
