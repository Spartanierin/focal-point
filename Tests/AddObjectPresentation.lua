-- Real picker, mutations, ObjectSelection and presentation navigation.
-- Reuse the existing detached data/native UI fixture; no SavedVariables writes.
local function Read(path)
    local file = assert(io.open(path)); local source = file:read("*a"); file:close(); return source
end
local source = Read("Tests/SegmentedBarAdd.lua")
local stop = assert(source:find("local count=0", 1, true))
local h, ns, state, toolbar, Setup, FindButton, dialogs = assert(load(source:sub(1, stop - 1) ..
    "\nreturn h,ns,state,toolbar,Setup,FindButton,dialogs", "@AddObjectPresentation/Fixture"))()
local function Load(path) assert(loadfile(path))("FocalPoint", ns) end
local function ClickEntry(widget)
    assert(widget.type=="FocalPointSelectionRow")
    widget.frame:Run("OnMouseDown","LeftButton")
end
Load("GUI/Editor/EditorController.lua")
Load("GUI/Editor/Inspector/InspectorMutations.lua")
-- The reused segmented-bar fixture limits valid selection units to player/target.
ns.Constants.UnitOrder[3] = "pet"
Load("GUI/Editor/ObjectSelection.lua")
local controller, selection = ns.GUI.Editor.Controller, ns.GUI.Editor.ObjectSelection
-- Runtime rendering remains a boundary, now including the newly added pet unit.
ns.RefreshUnitFrame = function(_, unit)
    assert(ns.UnitFrameUtils.GetUnitDB(unit), unit)
end
local function Open(label, globalUnit)
    if globalUnit then toolbar.OpenEntityAddObjectPicker()
    else
        controller.SetPresentation("customize")
        toolbar.OpenComponentAdd({kind="unit",unit="player"},function()return true end)
    end
    local dialog = dialogs[#dialogs]
    return dialog, assert(FindButton(dialog.body, label), label)
end
local function Add(label, globalUnit)
    local dialog, button = Open(label, globalUnit); ClickEntry(button); assert(dialog.released)
end
local count = 0
local function Test(name, fn) fn(); count = count + 1; print("PASS: " .. name) end
Test("Tree child categories select the actual new object in Customize", function()
    local _, unit = Setup()
    unit.powerBarPresent = false
    unit.Portrait = {present = false}
    unit.Buffs = {present = false}
    for _, item in ipairs({
        {"Power Bar", "bar", "PowerBar"},
        {"Portrait", "indicator", "Portrait"},
        {"Buffs", "aura", "Buffs"},
        {"Decoration", "decoration"},
        {"Class Resource Bar", "segmentedBar"},
    }) do
        controller.SetPresentation("customize")
        Add(item[1])
        local selected = selection.GetSelectedObject()
        assert(not state.IsArrange() and selected.kind == item[2] and selected.unit == "player")
        assert(not selected.unavailable)
        if item[3] then assert(selected.objectKey == item[3]) end
        if item[2] == "decoration" then assert(selected.decorationId == unit.decorations[1].id) end
        if item[2] == "segmentedBar" then
            assert(selected.objectKey == unit.segmentedBars[1].id)
            assert(h.BuildInspector():find("Class Resource Bar 1", 1, true))
        end
        assert(state.GetPropertyScope())
    end
end)
Test("Customize repeated Add preserves canonical selection and instance Inspector", function()
    Setup(); controller.SetPresentation("customize")
    for index = 1, 3 do
        Add("Class Resource Bar")
        assert(not state.IsArrange())
        assert(h.BuildInspector():find("Class Resource Bar " .. index, 1, true))
    end
end)
Test("Unit/root Add does not navigate", function()
    local _, unit = Setup()
    local units = ns.ActiveLayoutResolver.GetActiveRuntimeRoot().units
    units.pet = {present = false, Texts = {}}
    controller.SetPresentation("arrange")
    Add("pet", true)
    assert(units.pet.present and state.IsArrange())
    local selected = selection.GetSelectedObject()
    assert(selected.kind == "unit" and selected.unit == "pet", selected.kind .. ":" .. selected.unit)
end)
Test("Tree cancel, combat failure and stale layout callback retain Customize", function()
    Setup(); controller.SetPresentation("customize")
    local dialog = Open("Class Resource Bar"); dialog.window.closebutton:Run("OnClick")
    assert(not state.IsArrange())
    local button; dialog, button = Open("Class Resource Bar")
    local combat = InCombatLockdown; InCombatLockdown = function() return true end
    ClickEntry(button); InCombatLockdown = combat
    assert(not state.IsArrange() and selection.GetSelectedObject().kind == "unit")
    dialog, button = Open("Class Resource Bar")
    local ok, id = ns.LayoutMutations.CopyLayout("layout:existing", nil, {activate = false}); assert(ok)
    assert(ns:ActivateLayout(id)); ClickEntry(button)
    assert(not state.IsArrange() and selection.GetSelectedObject().kind == "unit")
end)
Test("successful mutation without successful canonical selection does not navigate", function()
    Setup(); controller.SetPresentation("customize")
    local select = selection.SelectObject
    selection.SelectObject = function() return false end
    Add("Class Resource Bar")
    selection.SelectObject = select
    assert(not state.IsArrange() and selection.GetSelectedObject().kind == "unit")
end)
for _, path in ipairs({
    "Engine/Text/Shared/TextElementUtils.lua", "Engine/Text/Shared/TextElementRoles.lua",
    "Engine/Text/Shared/TextTemplateResolver.lua", "Engine/Text/Shared/TextTemplateMutations.lua",
    "GUI/Widgets/SelectionRow.lua", "GUI/Editor/TextTemplateLibraryWindow.lua",
}) do Load(path) end
local picker = ns.GUI.Editor.TextTemplateLibraryWindow
local function OpenText(mode, textKey)
    picker.Open({entity = true, mode = mode or "add", unit = "player", textKey = textKey})
    return assert(h.ui.Upvalue(picker.Open, "windowContext"))
end
Test("text Add navigates only after actual creation and canonical text selection", function()
    local _, unit = Setup(); controller.SetPresentation("arrange")
    local context = OpenText()
    assert(state.IsArrange())
    context.primaryButton:Fire("OnClick")
    local selected = selection.GetSelectedObject()
    assert(not state.IsArrange() and selected.kind == "text" and unit.Texts[selected.textKey])
    assert(state.GetPropertyScope().sectionKey == "texts")
    local key = selected.textKey
    context = OpenText("change", key)
    controller.SetPresentation("arrange")
    context.primaryButton:Fire("OnClick")
    assert(state.IsArrange() and selection.GetSelectedObject().textKey == key)
    controller.SetPresentation("customize")
    context = OpenText(); context.primaryButton:Fire("OnClick")
    assert(not state.IsArrange() and selection.GetSelectedObject().textKey ~= key)
end)
Test("text cancel and stale target leave Arrange unchanged", function()
    Setup(); controller.SetPresentation("arrange")
    local context = OpenText(); context.dialog.cancelButton:Fire("OnClick")
    assert(state.IsArrange())
    context = OpenText()
    local ok, id = ns.LayoutMutations.CopyLayout("layout:existing", nil, {activate = false}); assert(ok)
    assert(ns:ActivateLayout(id)); context.primaryButton:Fire("OnClick")
    assert(state.IsArrange() and selection.GetSelectedObject().kind == "unit")
    context.dialog:Close()
end)
assert(#h.ui.env.errors == 0, table.concat(h.ui.env.errors, "\n"))
print("Add Object Presentation: " .. count .. " groups PASS")
