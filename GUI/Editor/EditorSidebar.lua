local _, ns = ...

ns.GUI = ns.GUI or {}
ns.GUI.Editor = ns.GUI.Editor or {}

local Sidebar = {}
ns.GUI.Editor.Sidebar = Sidebar

function Sidebar.BuildContext(container, state, options)
    local contextSidebar = ns.GUI and ns.GUI.Editor and ns.GUI.Editor.ContextSidebar
    if contextSidebar and contextSidebar.Build then
        return contextSidebar.Build(container, state, options)
    end
end

function Sidebar.Build(container, state, options)
    local inspectorSidebar = ns.GUI and ns.GUI.Editor and ns.GUI.Editor.InspectorSidebar
    if inspectorSidebar and inspectorSidebar.Build then
        return inspectorSidebar.Build(container, state, options)
    end
end

return Sidebar
