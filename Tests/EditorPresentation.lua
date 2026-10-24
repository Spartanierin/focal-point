-- lua54 Tests/EditorPresentation.lua
-- Real session state, Open/Close, refresh queue, AppShell, Canvas toolbar,
-- ObjectSelection and Inspector owner. Detailed section rendering and unit
-- runtime are boundaries; native hit testing/combat remain ingame checks.
local input = assert(io.open("Tests/DialogWindowFamily.lua"))
local source = input:read("*a"); input:close()
local boundary = assert(source:find("local created,latest=", 1, true))
local f = assert(load(source:sub(1, boundary - 1) .. "\nreturn f", "@EditorPresentation/Fixture"))()
local ns, Load, Equal, ace = f.ns, f.Load, f.Equal, f.ace
function f.native:RegisterEvent(event)
    self.registeredEvents = self.registeredEvents or {}; self.registeredEvents[event] = true
end
Load("Libraries/Ace3/AceGUI-3.0/widgets/AceGUIContainer-Frame.lua")
Load("Data/Constants.lua")
Load("GUI/Editor/EditorState.lua")
Load("GUI/Helpers/GUIState.lua")
Load("GUI/Helpers/LayoutHelpers.lua")
Load("GUI/Helpers/GUIRuntimeHelpers.lua")
Load("GUI/Helpers/PageDependencyFactory.lua")
Load("GUI/Editor/Toolbar/ToolbarBinding.lua")
Load("GUI/Editor/EditorController.lua")
Load("GUI/Editor/CanvasToolbar.lua")
Load("GUI/AppShell.lua")
Load("GUI/GUIController.lua")
local state, controller, shell = ns.GUI.Editor.State, ns.GUI.Editor.Controller, ns.GUI.AppShell
local pending = {}
C_Timer = { After = function(_, callback) pending[#pending + 1] = callback end }
local function Drain()
    local passes = 0
    while #pending > 0 do
        passes = passes + 1; assert(passes < 20, "unsettled presentation refresh")
        local batch = pending; pending = {}
        for _, callback in ipairs(batch) do callback() end
    end
end
local function Copy(value)
    if type(value) ~= "table" then return value end
    local result = {}; for key, item in pairs(value) do result[key] = Copy(item) end; return result
end
local units = { player = { present = true, enabled = true, width = 120, height = 40, Texts = {} },
    target = { present = true, enabled = true, width = 140, height = 45, Texts = {} } }
ns.UnitFrameUtils = { GetUnitDB = function(unit) return units[unit] end }
ns.frames = {}
ns.db.profile = ns.db.profile or {}; ns.db.profile.General = ns.db.profile.General or {}
local saved = Copy(ns.db)
local runtimeRefreshes = {}
function ns:RefreshUnitFrame(unit) runtimeRefreshes[#runtimeRefreshes + 1] = unit end
function ns:SetFrameLockEnabled(enabled) self.framesUnlocked = enabled end
-- Legacy toolbar must remain hidden; section rendering is the Inspector boundary.
local detail = ace:Create("Window")
detail.frame:Hide()
local projectedState, propertyBuilds
ns.GUI.Editor.Toolbar = {
    Open = function(currentState) projectedState = currentState; detail.frame:Show() end,
    Hide = function() detail.frame:Hide() end,
}
ns.GUI.Editor.Inspector = {
    BuildProperties = function(container, currentState)
        propertyBuilds = (propertyBuilds or 0) + 1
        projectedState = currentState
        container:ReleaseChildren()
        local label = ace:Create("Label")
        label:SetText(currentState.selectedUnit); container:AddChild(label)
    end,
}
Load("GUI/Editor/ObjectSelection.lua")
Load("GUI/Editor/EditorInteractionMode.lua")
Load("GUI/Editor/CanvasHoverOverlay.lua")
Load("GUI/Editor/TextEditorOverlay.lua")
local textInteractionActive = f.Upvalue(ns.GUI.Editor.TextEditorOverlay.UpdateFrame, "IsEditorActive")
Load("GUI/GUIMainController.lua")
local toolbar = ns.GUI.Editor.CanvasToolbar
local ensure = f.Upvalue(toolbar.UpdateGeometry, "EnsureHost")
local function CheckArrange()
    assert(state.IsArrange())
    assert(not detail.frame:IsShown())
    assert(not ns.guiEditorToolbarLayer:IsShown())
    assert(not controller.GetActiveInspectorHost())
    assert(not ns.GUI.Editor.CanvasHoverOverlay.IsEditorActive() and not textInteractionActive())
    local inspector = ns.GUI.Editor._persistentInspector
    assert(not inspector or not inspector.frame:IsShown())
    local current = ensure()
    assert(current.host:IsShown())
    Equal(current.host.points.TOP.x, 0)
    Equal(current.widgets.presentationButton.text:GetText(), "Customize")
end
local function CheckCustomize()
    assert(not state.IsArrange() and not detail.frame:IsShown())
    assert(not ns.guiEditorToolbarLayer:IsShown())
    assert(controller.GetActiveInspectorHost().frame:IsShown())
    assert(ns.GUI.Editor.CanvasHoverOverlay.IsEditorActive() and textInteractionActive())
    assert(projectedState == state.Get())
    Equal(ensure().widgets.presentationButton.text:GetText(), "Arrange")
end
ns:OpenConfig(); Drain(); CheckArrange()
assert(state.GetPrimaryUnit() == "player" and not propertyBuilds)
local controls = ensure().widgets
controls.presentationButton:Fire("OnClick"); Drain(); CheckCustomize()
local inspector = controller.GetActiveInspectorHost()
local function Select(ref)
    assert(ns.GUI.Editor.ObjectSelection.SelectObject(ref)); Drain()
end
Select({ kind = "bar", unit = "target", objectKey = "HealthBar" })
local selectedScope = state.GetPropertyScope()
assert(selectedScope and selectedScope.sectionKey == "health")
local selectedUnits = state.Get().selectedUnits
for _ = 1, 20 do
    controls.presentationButton:Fire("OnClick"); Drain(); CheckArrange()
    assert(state.GetPropertyScope() == selectedScope and state.Get().selectedUnits == selectedUnits)
    -- Selection projection must not create hidden property widgets in Arrange.
    local builds = propertyBuilds
    controller.ApplyObjectSelectionProjection("sameUnitObject", "target", {kind="bar"}, "bar")
    assert(propertyBuilds == builds and not controller.RefreshActiveProperties())
    controls.presentationButton:Fire("OnClick"); Drain(); CheckCustomize()
    assert(controller.GetActiveInspectorHost() == inspector)
    assert(state.GetPropertyScope() == selectedScope and state.Get().selectedUnits == selectedUnits)
end
-- A queued Customize build followed by Arrange cannot resurrect the Inspector.
controls.presentationButton:Fire("OnClick")
controls.presentationButton:Fire("OnClick")
controls.presentationButton:Fire("OnClick")
Drain(); CheckArrange()
Select({ kind = "unit", unit = "player" }); CheckArrange()
assert(state.GetPrimaryUnit() == "player")
controls.presentationButton:Fire("OnClick"); Drain(); CheckCustomize()
ns:OpenConfig(); Drain(); CheckCustomize() -- Already-open entry keeps the current level.
for _ = 1, 20 do
    controls.closeButton:Fire("OnClick"); Drain()
    assert(not ns:IsEditorActive() and state.IsArrange())
    ns:OpenConfig(); Drain(); CheckArrange()
    controls.presentationButton:Fire("OnClick"); Drain(); CheckCustomize()
end
-- Existing window/toolbar instances are reused; layout refresh does not reset the level.
local host = ns.guiMainHost
ns.GUI:RequestRefreshOptions("EditorPresentation.LayoutChanged"); Drain(); CheckCustomize()
assert(ns.guiMainHost == host and controller.GetActiveInspectorHost() == inspector)
Equal(ns.db, saved)
assert(not state.SetPresentation("invalid") and not state.IsArrange())
controls.closeButton:Fire("OnClick"); Drain()
Equal(ns.db, saved)
assert(#f.env.errors == 0, table.concat(f.env.errors, "\n"))
print("PASS: Arrange entry, real toolbar navigation, selection identity, deferred guards, 20 toggles + 20 reopen cycles and unchanged layout data")
