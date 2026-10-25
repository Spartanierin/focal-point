-- Real Inspector controls/mutations in the existing detached UI/data fixture.
-- The media-picker boundary returns an item; native layout remains an ingame check.
local f = assert(io.open("Tests/BarBorderInspector.lua"))
local source = f:read("*a"); f:close()
local stop = assert(source:find("\nlocal count=0", 1, true))
local ns, Setup, Copy, Equal, ui, state, selection = assert(load(source:sub(1, stop) ..
    "\nreturn ns,Setup,Copy,Equal,ui,state,selection", "@HealingAbsorb/Fixture"))()
ns.Ace = ui.ns.Ace
for _, path in ipairs({"GUI/Editor/Inspector/InspectorTextSelection.lua",
    "GUI/Editor/Inspector/InspectorBinding.lua", "GUI/Editor/Inspector/InspectorController.lua"}) do
    assert(loadfile(path))("FocalPoint", ns)
end
local media
ns.GUI.Editor.MediaLibrary = {Open = function(options) media = options end}
local container = ui.ace:Create("SimpleGroup")
local unit, db
local function Select(key)
    assert(selection.SelectObject({kind="bar", unit="player", objectKey=key}))
end
local function Build()
    ns.GUI.Editor.Inspector.BuildProperties(container, state.Get(), {getUnitConfig=ns.UnitFrameUtils.GetUnitDB})
end
local function Scan()
    local groups, rows, shows = {}, {}, {}
    local function Walk(w, group)
        if w.type == "InlineGroup" then
            group = w.titletext:GetText(); groups[#groups + 1] = group
        end
        if w.type == "CheckBox" then
            local row = w.parent and w.parent.parent
            local label = row and row.children and row.children[1]
            if label and label.type == "Label" and label.label:GetText() == "Show" then
                shows[#shows + 1] = w
            end
        end
        local children = w.children or {}
        if children[1] and children[1].type == "Label" and children[2] and children[2].type == "SimpleGroup" then
            local label = children[1].label:GetText()
            rows[label] = {group=group, widget=children[2]}
            rows[tostring(group).."|"..label] = rows[label]
        end
        for _, child in ipairs(children) do Walk(child, group) end
    end
    Walk(container)
    return groups, rows, shows
end
local function Control(label, kind, group)
    local _, rows = Scan(); local row = assert(rows[group and (group.."|"..label) or label], label)
    local function Find(w)
        if w.type == kind then return w end
        for _, child in ipairs(w.children or {}) do local result=Find(child); if result then return result end end
    end
    return assert(Find(row.widget), label .. ":" .. kind), row.group
end
local count = 0
local function Test(name, run) run(); count=count+1; print("PASS: " .. name) end
Test("Healing Absorb retains General Show and separate Appearance/Background groups", function()
    db, unit = Setup(); state.SetSingleSelection("player"); state.ClearPropertyScope()
    unit.healingAbsorbBarPresent=true; unit.showHealingAbsorbBar=true
    state.SetMode("expert"); Select("HealingAbsorbBar")
    local before=Copy(db); Build(); Equal(db,before)
    local groups, _, shows = Scan()
    assert(table.concat(groups, ",") == "General,Appearance,Background,Geometry,Position,Behavior,Actions")
    local root=container.children[#container.children]
    assert(container.children[#container.children-1].frame:GetHeight()==10,"stable outer spacing changed")
    assert(root.children[2].frame:GetHeight()==6,"stable header spacing changed")
    for i,child in ipairs(root.children[3].children) do
        if child.type=="InlineGroup" and i>1 then
            assert(root.children[3].children[i-1].frame:GetHeight()==8,"stable framed-group spacing changed")
        end
    end
    assert(#shows == 1 and shows[1].type == "CheckBox" and shows[1]:GetValue())
    local _, showGroup=Control("Show","CheckBox"); assert(showGroup=="General")
    local _, colorGroup=Control("Color","ColorPicker","Appearance"); assert(colorGroup=="Appearance")
    for _, label in ipairs({"Color","Border Color"}) do
        local _, group=Control(label,"ColorPicker","Background"); assert(group=="Background")
    end
    local _, group=Control("Texture","Button"); assert(group=="Appearance")
    local _, widthGroup=Control("Width","FPCompactSlider"); assert(widthGroup=="Geometry")
    Control("Size Mode","Dropdown"); Control("Height","FPCompactSlider")
    Control("Anchor Target","Dropdown"); Control("Offset X","FPCompactSlider")
    Control("Offset Y","FPCompactSlider"); Control("Growth Direction","Dropdown")
end)
Test("General Show and separate colors use existing fields and survive refresh", function()
    local _,_,shows=Scan(); shows[1]:Fire("OnValueChanged",false)
    assert(unit.showHealingAbsorbBar==false)
    local _,_,current=Scan(); assert(#current==1 and not current[1]:GetValue())
    current[1]:Fire("OnValueChanged",true); assert(unit.showHealingAbsorbBar)
    Control("Texture","Button"):Fire("OnClick"); assert(media and media.onApply)
    media.onApply("fp:statusbar:flat-white"); assert(unit.healingAbsorbBarTexture=="fp:statusbar:flat-white")
    Control("Color","ColorPicker","Appearance"):Fire("OnValueConfirmed",.2,.3,.4,.5)
    Control("Color","ColorPicker","Background"):Fire("OnValueConfirmed",.1,.2,.3,.4)
    Control("Border Width","FPCompactSlider"):Fire("OnValueChanged",3)
    Control("Border Color","ColorPicker"):Fire("OnValueConfirmed",.4,.3,.2,0)
    assert(unit.healingAbsorbBarColor[4]==.5 and unit.healingAbsorbBarBackgroundColor[4]==.4)
    assert(unit.healingAbsorbBarBorderWidth==3 and unit.healingAbsorbBarBorderColor[4]==0)
    Build(); assert(Control("Border Width","FPCompactSlider"):GetValue()==3)
    assert(Control("Border Color","ColorPicker").a==0)
    Control("Texture","Button"):Fire("OnClick"); assert(media.currentValue==unit.healingAbsorbBarTexture)
end)
Test("size mode, dimensions and lower properties retain mutation semantics", function()
    Control("Size Mode","Dropdown"):Fire("OnValueChanged","CUSTOM")
    assert(unit.healingAbsorbBarSizeMode=="CUSTOM")
    assert(not Control("Width","FPCompactSlider").disabled)
    Control("Width","FPCompactSlider"):Fire("OnValueChanged",180)
    Control("Height","FPCompactSlider"):Fire("OnValueChanged",11)
    Control("Offset X","FPCompactSlider"):Fire("OnValueChanged",7)
    Control("Offset Y","FPCompactSlider"):Fire("OnValueChanged",-5)
    Control("Growth Direction","Dropdown"):Fire("OnValueChanged","LEFT_TO_RIGHT")
    assert(unit.healingAbsorbBarWidth==180 and unit.healingAbsorbBarHeight==11)
    assert(unit.healingAbsorbBarOffsetX==7 and unit.healingAbsorbBarOffsetY==-5)
    assert(unit.healingAbsorbBarGrowth=="LEFT_TO_RIGHT")
    Build(); assert(Control("Height","FPCompactSlider"):GetValue()==11)
    Control("Size Mode","Dropdown"):Fire("OnValueChanged","MATCH_TARGET")
    assert(Control("Width","FPCompactSlider").disabled and Control("Height","FPCompactSlider").disabled)
end)
Test("other bars retain their groups; selection and layout rebuild rebind General Show", function()
    local _,_,shows=Scan(); local old=shows[1].events.OnValueChanged
    for _, item in ipairs({{"NormalAbsorbBar","normalAbsorbBarPresent"},{"HealthBar","healthBarPresent"},
        {"PowerBar","powerBarPresent"}}) do
        unit[item[2]]=true; Select(item[1]); Build()
        local groups=Scan(); local found={}; for _,name in ipairs(groups) do found[name]=true end
        assert(found.Background and found.Appearance)
        if item[1]~="HealthBar" then assert(found.General) end
    end
    -- AceGUI may pool the same widget for another field. The old event binding
    -- must be gone; manually invoking a retained function is not a widget event.
    assert(shows[1].events.OnValueChanged~=old)
    assert(selection.SelectObject({kind="text",unit="player",textKey="localText"})); Build()
    local textGroups,_,textShows=Scan(); local found={}
    for _,name in ipairs(textGroups) do found[name]=true end
    assert(found.Content and found.Appearance and found.Position and found.Actions and #textShows==0)
    local before=Copy(db); Build(); Equal(db,before)
    assert(selection.GetSelectedObject().textKey=="localText")
    Select("HealingAbsorbBar"); Build()
    local _,_,current=Scan(); assert(#current==1 and current[1]:GetValue())
    local ok,id=ns.LayoutMutations.CopyLayout("layout:existing",nil,{activate=false}); assert(ok)
    ns.db.char.activeLayoutId=id; ns.ActiveLayoutResolver.InvalidateActiveRuntimeRoot()
    assert(ns.ActiveLayoutResolver.EnsureActiveRuntimeRoot(ns.db))
    Build()
    local _,_,rebuilt=Scan(); assert(#rebuilt==1 and rebuilt[1]:GetValue())
    rebuilt[1]:Fire("OnValueChanged",false)
    local active=ns.UnitFrameUtils.GetUnitDB("player")
    assert(active~=unit and active.showHealingAbsorbBar==false and unit.showHealingAbsorbBar==true)
end)
assert(#ui.env.errors==0,table.concat(ui.env.errors,"\n"))
ui.ace:Release(container)
print("Healing Absorb Properties: " .. count .. " groups PASS")
