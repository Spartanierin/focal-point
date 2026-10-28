-- Real Inspector sections, tree, mutations and selection in the existing Window.
-- Native geometry/hit testing remain client checks; data is detached.
local function Read(path)
    local file = assert(io.open(path)); local source = file:read("*a"); file:close(); return source
end
local source = Read("Tests/AddObjectPresentation.lua")
local stop = assert(source:find("local count = 0", 1, true))
local h, ns, state, controller, selection, Setup, Add = assert(load(source:sub(1, stop - 1) ..
    "\nreturn h,ns,state,controller,selection,Setup,Add", "@CustomizeWorkspace/Fixture"))()
ns.Ace = h.ui.ns.Ace
assert(loadfile("Libraries/Ace3/AceGUI-3.0/widgets/AceGUIWidget-InteractiveLabel.lua"))()
assert(loadfile("Libraries/Ace3/AceGUI-3.0/widgets/AceGUIWidget-Slider.lua"))()
assert(loadfile("GUI/Editor/Inspector/InspectorTextSelection.lua"))("FocalPoint", ns)
assert(loadfile("GUI/Editor/Inspector/InspectorBinding.lua"))("FocalPoint", ns)
assert(loadfile("GUI/Editor/Inspector/InspectorController.lua"))("FocalPoint", ns)
local pending = {}
function h.ui.native:SetObeyStepOnDrag(value) self.obeyStepOnDrag = value end
function h.ui.native:RegisterForDrag(...) self.dragButtons = {...} end
function h.ui.native:GetValue() return self.value or 0 end
function h.ui.native:SetHighlightTexture(...) self.lastSetHighlightTexture={...} end
function h.ui.native:SetPushedTexture(...) self.lastSetPushedTexture={...} end
function h.ui.native:RegisterForClicks(...) self.clickButtons={...} end
function h.ui.native:GetNormalTexture()
    if not self.normalTexture then self.normalTexture=self:CreateTexture();self.normalTexture:SetTexture(130755) end
    return self.normalTexture
end
function h.ui.native:GetCheckedTexture()
    if not self.checkedTexture then self.checkedTexture=self:CreateTexture();self.checkedTexture:SetTexture(130751) end
    return self.checkedTexture
end
function h.ui.native:SetChecked(checked) self.checked=checked;self:GetCheckedTexture():SetShown(checked) end
function h.ui.native:GetChecked() return self.checked end
function h.ui.native:Enable() self.nativeEnabled=true end
function h.ui.native:Disable() self.nativeEnabled=false end
function h.ui.native:IsEnabled() return self.nativeEnabled~=false end
C_Timer = {After = function(_, callback) pending[#pending + 1] = callback end}
local function Drain()
    local passes = 0
    while #pending > 0 do
        passes = passes + 1; assert(passes < 20)
        local batch = pending; pending = {}
        for _, callback in ipairs(batch) do callback() end
    end
end
local open = true
ns.GUI.RequestRefreshOptions = function()
    pending[#pending + 1] = function()
        if open then controller.BuildInspector(nil, {GetEditorState = state.Get}) end
    end
end
ns.CloseConfig = function()
    open = false; controller.ReleaseInspector(); state.SetPresentation("arrange")
end
local function Build()
    open = true; controller.SetPresentation("customize")
    controller.BuildInspector(nil, {GetEditorState = state.Get}); Drain()
    return assert(controller.GetActiveInspectorHost())
end
local function Tree()
    return assert(ns.CompositionTreeView._keyboardBindingContext)
end
local function Node(kind, key)
    for _, row in ipairs(Tree().options.visibleRows) do
        local node = row.node
        if node.inspectorTarget.kind == kind and (not key or node.inspectorTarget.objectKey == key
            or node.inspectorTarget.textKey == key) then return node end
    end
    error("missing node: " .. kind .. ":" .. tostring(key))
end
local function Labels(widget)
    local result = {}
    local function Walk(child)
        if child.type == "Label" then result[#result + 1] = child.label:GetText() or "" end
        for _, nested in ipairs(child.children or {}) do Walk(nested) end
    end
    Walk(widget); return table.concat(result, "\n")
end
local count = 0
local function Test(name, fn) fn(); count = count + 1; print("PASS: " .. name) end
local window, unit
Test("first open has one Window with current unit, tree and actual properties", function()
    local db; db, unit = Setup()
    window = Build()
    local body = window._focalPointInspectorContent
    assert(window.type == "Window" and #body.children == 3)
    assert(window._focalPointCompositionHost.parent == body)
    assert(window._focalPointPropertyScroll.parent.parent == body)
    assert(window.frame:GetWidth() == 392 and window.frame:GetHeight() == 620)
    assert(window.titletext:GetText():find("player", 1, true))
    local header=body.children[1]
    assert(header:GetUserData("table").columns[3].weight==1)
    assert(header.frame:IsShown() and #header.children==3)
    assert(not window._focalPointArrangeButton and not window._focalPointCloseButton)
    assert(Tree().state == state.Get() and Tree().tree.unit == "player")
    assert(selection.GetSelectedObject().kind == "unit")
    assert(window._focalPointCompositionHost.frame.points.TOPLEFT.x == 0)
    assert(window._focalPointCompositionHost.frame:GetWidth() == math.min(360, window._focalPointInspectorContent.frame:GetWidth()))
    assert(window._focalPointPropertyScroll.parent.frame.points.TOPLEFT.x == 0)
    assert(window._focalPointCompositionHost.frame:IsShown())
    assert(not window._focalPointPropertyScroll.parent.frame:IsShown())
end)
Test("real Add Object, tree and canvas selection share one Inspector", function()
    controller.SetPresentation("arrange"); Drain()
    Add("Class Resource Bar"); Drain()
    assert(controller.GetActiveInspectorHost() == window and not state.IsArrange())
    local id = unit.segmentedBars[1].id
    assert(selection.GetSelectedObject().objectKey == id)
    assert(not Labels(window._focalPointPropertyScroll):find("player / Class Resource Bar 1", 1, true))
    assert(state.GetPropertyScope().kind == "segmentedBar")
    local node = Node("segmentedBar", id)
    Tree().control.callbacks.onToggle(node, false); Drain()
    assert(unit.segmentedBars[1].enabled == false)
    assert(Node("segmentedBar", id).enabled == false)
    Tree().control.callbacks.onSelect(Node("unit")); Drain()
    assert(selection.GetSelectedObject().kind == "unit")
    Tree().control.callbacks.onSelect(Node("segmentedBar", id)); Drain()
    assert(selection.GetSelectedObject().objectKey == id and not selection.GetSelectedObject().unavailable)
    -- Canvas uses the same public entry; no alternate selection in this fixture.
    assert(selection.SelectObject({kind = "text", unit = "player", textKey = "localText"})); Drain()
    assert(state.GetPropertyScope().sectionKey == "texts")
    assert(Tree().state.selectedTextElementId == "localText")
end)
Test("geometry refresh preserves moved Window; properties rebuild keeps one owner", function()
    window.frame:ClearAllPoints(); window.frame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 75, -80)
    controller.UpdateActiveInspectorGeometry()
    assert(window.frame.points.TOPLEFT.x == 75 and window.frame.points.TOPLEFT.y == -80)
    local body = window._focalPointInspectorContent
    local treeHost = window._focalPointCompositionHost
    local scroll = window._focalPointPropertyScroll
    controller.RefreshActiveProperties(); Drain()
    assert(window._focalPointPropertyScroll == scroll and window._focalPointCompositionHost == treeHost)
    assert(#body.children == 3 and scroll.status == state.Get().editorSidebarScroll)
    assert(scroll.status.scrollvalue == 0)
end)
Test("same-context rebuild reuses scroll state; selection resets it without moving Window", function()
    local scroll = window._focalPointPropertyScroll
    scroll:SetScroll(300)
    scroll.scrollbar:SetValue(300)
    local status = state.Get().editorSidebarScroll
    controller.BuildInspector(nil, {GetEditorState = state.Get}); Drain()
    assert(window._focalPointPropertyScroll.status == status)
    assert(#window._focalPointPropertyScroll.children > 0)
    -- This native double does not resolve the scroll viewport's anchored height.
    -- Exact offset retention is a client check, not a synthetic pixel assertion.
    -- A read-only HEAD/WIP comparison produced identical clamping in this fixture.
    controller.RefreshActiveProperties(); Drain()
    assert(status.scrollvalue == 0)
    assert(window.frame.points.TOPLEFT.x == 75 and window.frame.points.TOPLEFT.y == -80)
end)
Test("Arrange and Close reject retained callbacks and deferred UI restores", function()
    local treeCallback = Tree().control.callbacks.onSelect
    local node = Node("segmentedBar", unit.segmentedBars[1].id)
    local properties = ns.GUI.Editor._activeInspectorRefreshProperties
    local before = selection.GetSelectedObject().textKey
    window.closebutton:GetScript("OnClick")(window.closebutton)
    treeCallback(node); properties(); Drain()
    assert(state.IsArrange() and not window.frame:IsShown() and not controller.GetActiveInspectorHost())
    assert(selection.GetSelectedObject().textKey == before)
    Build()
    local oldBack = window._focalPointComponentsButton.events.OnClick
    controller.BuildInspector(nil, {GetEditorState = state.Get}); Drain()
    oldBack(); assert(open and controller.GetActiveInspectorHost() == window)
    window.closebutton:GetScript("OnClick")(window.closebutton); Drain()
    assert(open and state.IsArrange() and not window.frame:IsShown())
end)
Test("30 reopen/mode cycles reuse the Window and release old tree controls", function()
    for _ = 1, 30 do
        assert(Build() == window)
        local old = Tree().control.callbacks.onSelect
        local node = Node("unit")
        local scope = state.GetPropertyScope()
        window.closebutton:GetScript("OnClick")(window.closebutton); Drain()
        old(node); assert(state.GetPropertyScope() == scope)
        assert(not window.frame:IsShown())
    end
end)
Test("layout validation projects replacement unit data without new initial selection", function()
    local db = Setup(); Build()
    assert(selection.SelectObject({kind = "text", unit = "player", textKey = "localText"})); Drain()
    local ok, id = ns.LayoutMutations.CopyLayout("layout:existing", nil, {activate = false}); assert(ok)
    assert(ns:ActivateLayout(id))
    state.ValidateSelection(function(key) return ns.UnitFrameUtils.GetUnitDB(key) ~= nil end)
    controller.BuildInspector(nil, {GetEditorState = state.Get}); Drain()
    assert(state.GetPrimaryUnit() == "player" and selection.GetSelectedObject().textKey == "localText")
    assert(Tree().tree.unit == "player" and window._focalPointPropertyScroll)
    ns:CloseConfig(); Drain()
end)
Test("unit selection updates title, tree and properties in the same Window", function()
    local _, player = Setup(); Build()
    local units = ns.ActiveLayoutResolver.GetActiveRuntimeRoot().units
    units.target = h.Copy(player)
    assert(selection.SelectObject({kind = "unit", unit = "target"})); Drain()
    assert(controller.GetActiveInspectorHost() == window)
    assert(window.titletext:GetText():find("target", 1, true))
    assert(Tree().tree.unit == "target" and state.GetPrimaryUnit() == "target")
    Tree().control.callbacks.onSelect(Node("text", "localText")); Drain()
    local selected = selection.GetSelectedObject()
    assert(selected.unit == "target" and selected.textKey == "localText")
    assert(state.GetPropertyScope().sectionKey == "texts")
    assert(#window._focalPointPropertyScroll.children > 0)
    ns:CloseConfig(); Drain()
end)
assert(#h.ui.env.errors == 0, table.concat(h.ui.env.errors, "\n"))
print("Customize Workspace: " .. count .. " groups PASS")
