-- Actual Components, picker, library, confirmation and mutation modules.
local function Read(path)local f=assert(io.open(path));local s=f:read("*a");f:close();return s end
local source=Read("Tests/CustomizeWorkspace.lua")
local stop=assert(source:find("\nlocal count = 0",1,true))
local h,ns,state,controller,selection,Setup,Build,Drain,Tree=assert(load(source:sub(1,stop)..
    "\nreturn h,ns,state,controller,selection,Setup,Build,Drain,Tree","@ComponentActions/Workspace"))()
-- The reused fixture limits selection to player/target/pet. Rebind real consumers
-- against the production unit catalog for Focus and Boss coverage.
assert(loadfile("Data/Constants.lua"))("FocalPoint",ns)
assert(loadfile("GUI/Editor/ObjectSelection.lua"))("FocalPoint",ns)
selection=ns.GUI.Editor.ObjectSelection
assert(loadfile("GUI/Editor/Inspector/InspectorController.lua"))("FocalPoint",ns)
for _,path in ipairs({"GUI/Layouts/UnitPortraitDefinition.lua","GUI/Editor/Composition/LegacyAssociationMap.lua","GUI/Editor/Composition/CompositionOwnership.lua",
    "GUI/Editor/Composition/CompositionTreeAdapter.lua","GUI/Editor/Composition/CompositionTreeView.lua","GUI/Editor/Toolbar/ToolbarBinding.lua",
    "Engine/Text/Shared/TextElementUtils.lua","Engine/Text/Shared/TextElementRoles.lua","Engine/Text/Shared/TextTemplateResolver.lua",
    "Engine/Text/Shared/TextTemplateMutations.lua","GUI/Widgets/SelectionRow.lua","GUI/Editor/TextTemplateLibraryWindow.lua"})do
    assert(loadfile(path))("FocalPoint",ns)
end
local forms=ns.GUI.Helpers.FormWidgets
local dialogs,confirms={},{}
local form,confirm=forms.CreateCompactFormDialog,forms.CreateCompactConfirmation
forms.CreateCompactFormDialog=function(options)local d=form(options);dialogs[#dialogs+1]=d;return d end
forms.CreateCompactConfirmation=function(options)local d=confirm(options);confirms[#confirms+1]={dialog=d,options=options};return d end
-- Native action buttons are exercised directly; no context-menu substitute.
local window,unit,db
local defaults={};assert(loadfile("Data/Defaults.lua"))("FocalPoint",defaults)
local raidDefaults=defaults:GetDefaultDB().profile.Units.player.RaidTargetIcon
local function PrepareRaid()
    unit.RaidTargetIcon=h.Copy(raidDefaults)
    unit.RaidTargetIcon.present=false
end
local function Start()
    db,unit=Setup();unit.powerBarPresent=true;unit.showPowerBar=true;unit.healthBarPresent=true
    window=Build();assert(window._focalPointCustomizeView=="components")
end
local function Row(kind,key)
    local c=Tree().control
    for i=1,c.count do local r=c.rows[i]
        if r.item.node.type==kind and (not key or r.item.node.inspectorTarget.textKey==key
            or r.item.node.inspectorTarget.objectKey==key or r.item.node.inspectorTarget.indicatorKey==key
            or r.item.node.inspectorTarget.decorationId==key)then return r end
    end
    error("missing card: "..kind)
end
local function CardActions(kind,key)
    local before=h.Copy(selection.GetSelectedObject())
    local row=Row(kind,key)
    local entries={}
    if row.add:IsShown()then
        local click=assert(row.add:GetScript("OnMouseDown"))
        entries.Add=function()click(row.add,"LeftButton")end
        -- Follow the real direct-plus -> catalog Text route.
        entries.Text=function()
            local before=#dialogs
            click(row.add,"LeftButton")
            if #dialogs==before then return end
            local picker=dialogs[#dialogs]
            local function Find(widget)
                if widget.type=="Button" and widget.text:GetText()=="Text" then return widget end
                for _,child in ipairs(widget.children or {})do local found=Find(child);if found then return found end end
            end
            assert(Find(picker.body)):Fire("OnClick")
        end
    end
    if row.item.removable then
        local click=assert(row.remove:GetScript("OnMouseDown"))
        entries.Remove=function()click(row.remove,"LeftButton")end
    end
    assert(window._focalPointCustomizeView=="components")
    h.Equal(selection.GetSelectedObject(),before)
    return entries
end
local function FindButton(widget,label)
    if widget.type=="Button" and widget.text:GetText()==label then return widget end
    for _,child in ipairs(widget.children or {})do local found=FindButton(child,label);if found then return found end end
end
local function AssertTextOnly(entries)
    assert(entries.Add);entries.Add()
    local picker=dialogs[#dialogs]
    assert(FindButton(picker.body,"Text") and not FindButton(picker.body,"Raid Target")
        and not FindButton(picker.body,"Leader") and not FindButton(picker.body,"Role"))
    picker:Close()
end
local function Back()window._focalPointComponentsButton:Fire("OnClick");Drain()end
local count=0
local function Test(name,fn)fn();count=count+1;print("PASS: "..name)end
Test("fixed Unit Add reuses the real catalog, excludes existing singletons and adds without duplicate roots",function()
    Start();unit.powerBarPresent=false;controller.RefreshCompositionTree()
    assert(window._focalPointComponentAddButton==nil)
    local add=Row("unit").add;assert(add:IsShown())
    add:Run("OnMouseDown","LeftButton")
    local picker=dialogs[#dialogs]
    assert(picker.body.children[1].label:GetText()=="Choose what to add to player.")
    assert(not FindButton(picker.body,"Health Bar") and not FindButton(picker.body,"pet"))
    local button=assert(FindButton(picker.body,"Power Bar"));button:Fire("OnClick");Drain()
    assert(unit.powerBarPresent and selection.GetSelectedObject().objectKey=="PowerBar")
    Back();Row("unit").add:Run("OnMouseDown","LeftButton")
    picker=dialogs[#dialogs];assert(not FindButton(picker.body,"Power Bar"));picker:Close()
end)
local textKey
Test("Power Bar plus and catalog Text open the existing template dialog with explicit target and no selection pre-step",function()
    Start();assert(selection.GetSelectedObject().kind=="unit")
    local entries=CardActions("powerbar")
    assert(entries.Text and not entries["Add Child"] and entries.Remove)
    local before=#dialogs
    entries.Text()
    assert(#dialogs==before+2 and dialogs[#dialogs].window.titletext:GetText()=="Add Text")
    local library=ns.GUI.Editor.TextTemplateLibraryWindow
    local context=assert(h.ui.Upvalue(library.Open,"windowContext"))
    assert(context.anchorSelection.objectKey=="PowerBar" and context.targetUnit=="player")
    assert(context.targetLabel==Row("powerbar").item.label)
    assert(context.dialog.body.children[1].label:GetText()=="Add to: "..context.targetLabel)
    assert(selection.GetSelectedObject().kind=="unit" and window._focalPointCustomizeView=="components")
    context.primaryButton:Fire("OnClick");Drain()
    local selected=selection.GetSelectedObject();assert(selected.kind=="text")
    textKey=selected.textKey;assert(unit.Texts[textKey].anchorTo=="PowerBar")
    local parent=ns.CompositionOwnership.ResolveParent(unit,selected);assert(parent.objectKey=="PowerBar")
    Back();assert(Row("textElement",textKey).item.depth==2)
end)
Test("Remove uses confirmation and the existing text mutation once; unsupported parent/root actions stay absent",function()
    local label=Row("textElement",textKey).item.label
    local entries=CardActions("textElement",textKey);assert(not entries.Text and entries.Remove)
    local original=ns.InspectorMutations.DeleteTextInstance;local calls=0
    ns.InspectorMutations.DeleteTextInstance=function(...)calls=calls+1;return original(...)end
    entries.Remove();local pending=confirms[#confirms]
    assert(pending.options.message=='Remove "'..label..'" from the unit frame?')
    pending.options.cancel.onClick(pending.dialog);assert(unit.Texts[textKey] and calls==0)
    pending.options.primary.onClick(pending.dialog);assert(calls==0)
    entries=CardActions("textElement",textKey);entries.Remove();pending=confirms[#confirms]
    pending.options.primary.onClick(pending.dialog);Drain()
    assert(unit.Texts[textKey]==nil and calls==1 and window._focalPointCustomizeView=="components")
    assert(selection.GetSelectedObject().textKey~=textKey)
    ns.InspectorMutations.DeleteTextInstance=original
    entries=CardActions("healthbar");assert(entries.Text and not entries.Remove)
    assert(Row("unit").add:IsShown() and not Row("unit").item.removable)
end)
Test("stale direct actions and picker callbacks reject rebuild, Unit change and Reopen without mutations",function()
    Start();local entries=CardActions("powerbar");local callback=entries.Text
    controller.RefreshCompositionTree()
    local before=#dialogs;callback();assert(#dialogs==before)
    Row("unit").add:Run("OnMouseDown","LeftButton")
    local picker=dialogs[#dialogs];local button=assert(FindButton(picker.body,"Text"));local old=button.events.OnClick
    picker:Close();before=h.Copy(db);old();h.Equal(db,before)
    entries=CardActions("powerbar");callback=entries.Remove
    local units=ns.ActiveLayoutResolver.GetActiveRuntimeRoot().units;units.target=h.Copy(unit)
    assert(selection.SelectObject({kind="unit",unit="target"}));Drain()
    before=#confirms;callback();assert(#confirms==before)
    window.closebutton:GetScript("OnClick")(window.closebutton);Drain();window=Build()
    callback();assert(#confirms==before)
end)
Test("confirmation rejects combat, layout replacement, Release and retained callbacks after reuse",function()
    Start()
    local entries=CardActions("powerbar");entries.Remove()
    local pending=confirms[#confirms];local before=h.Copy(db)
    local combat=InCombatLockdown;InCombatLockdown=function()return true end
    pending.options.primary.onClick(pending.dialog);InCombatLockdown=combat
    h.Equal(db,before)
    entries=CardActions("powerbar");entries.Remove();pending=confirms[#confirms]
    local retained=pending.options.primary.onClick
    h.ui.ace:Release(pending.dialog.window)
    entries=CardActions("powerbar");entries.Remove()
    local fresh=confirms[#confirms];retained(pending.dialog);h.Equal(db,before)
    assert(fresh.dialog.window.frame:IsShown());fresh.options.cancel.onClick(fresh.dialog)
    entries=CardActions("powerbar");entries.Remove();pending=confirms[#confirms]
    ns.ActiveLayoutResolver.InvalidateActiveRuntimeRoot()
    assert(ns.ActiveLayoutResolver.EnsureActiveRuntimeRoot(db))
    pending.options.primary.onClick(pending.dialog);h.Equal(db,before)
end)
Test("Unit Add Text ignores selected bar; stale child library cannot mutate after Unit switch",function()
    Start();Row("powerbar").frame:Run("OnMouseDown","LeftButton");Drain();Back()
    Row("unit").add:Run("OnMouseDown","LeftButton")
    assert(FindButton(dialogs[#dialogs].body,"Text")):Fire("OnClick")
    local library=ns.GUI.Editor.TextTemplateLibraryWindow
    local context=assert(h.ui.Upvalue(library.Open,"windowContext"))
    assert(context.anchorSelection.kind=="unit")
    context.primaryButton:Fire("OnClick");Drain()
    local selected=selection.GetSelectedObject()
    assert(unit.Texts[selected.textKey].anchorTo=="Frame");Back()
    local entries=CardActions("powerbar");entries.Text()
    context=assert(h.ui.Upvalue(library.Open,"windowContext"))
    ns.ActiveLayoutResolver.GetActiveRuntimeRoot().units.target=h.Copy(unit)
    assert(selection.SelectObject({kind="unit",unit="target"}));Drain()
    local before=h.Copy(db);context.primaryButton:Fire("OnClick");Drain();h.Equal(db,before)
    library.Close()
end)
Test("segmented Remove retains anchor-in-use protection and singleton Remove reuses presence mutation",function()
    Start();local mutations=ns.LayoutMutations.SegmentedBars
    local a=mutations.Add(assert(mutations.CaptureContext("player")));assert(a.ok,a.errorCode)
    local b=mutations.Add(assert(mutations.CaptureContext("player")),{enabled=true,dataSource={id="runes",scope="player"},anchorTo="SegmentedBar:"..a.id})
    assert(b.ok,b.errorCode);controller.RefreshCompositionTree()
    local entries=CardActions("segmentedBar",a.id);assert(not entries.Text);entries.Remove()
    local pending=confirms[#confirms];local before=h.Copy(db)
    pending.options.primary.onClick(pending.dialog);h.Equal(db,before);assert(pending.dialog.statusRole=="error")
    pending.options.cancel.onClick(pending.dialog)
    entries=CardActions("segmentedBar",b.id);entries.Remove();pending=confirms[#confirms]
    pending.options.primary.onClick(pending.dialog);Drain();assert(#unit.segmentedBars==1 and unit.segmentedBars[1].id==a.id)
    entries=CardActions("powerbar");entries.Remove();pending=confirms[#confirms]
    pending.options.primary.onClick(pending.dialog);Drain();assert(unit.powerBarPresent==false)
end)
Test("built-in Unit Add uses the existing editable-copy confirmation without changing the source",function()
    Start();assert(ns:ActivateLayout("builtin:default"));Drain();window=Build()
    local resolver=ns.ActiveLayoutResolver
    local source=h.Copy(resolver.GetActiveRuntimeRoot().payload)
    Row("unit").add:Run("OnMouseDown","LeftButton")
    assert(FindButton(dialogs[#dialogs].body,"Class Resource Bar")):Fire("OnClick")
    local pending=confirms[#confirms];pending.options.primary.onClick(pending.dialog);Drain()
    local root=resolver.GetActiveRuntimeRoot()
    assert(root.layoutId:match("^layout:") and root.record.createdFrom.id=="builtin:default")
    assert(#root.units.player.segmentedBars==1)
    assert(ns:ActivateLayout("builtin:default"));h.Equal(resolver.GetActiveRuntimeRoot().payload,source)
end)
Test("all seven eligible bars directly add exactly one correctly anchored text and retain canonical selection and card-to-Properties navigation",function()
    local cases={{"healthbar","HealthBar"},{"powerbar","PowerBar"},{"castbar","CastBar"},
        {"classPowerBar","ClassPowerBar"},{"alternativePowerBar","AlternativePowerBar"},
        {"normalAbsorbBar","NormalAbsorbBar"},{"healingAbsorbBar","HealingAbsorbBar"}}
    for _,case in ipairs(cases)do
        Start()
        for _,field in ipairs({"castBarPresent","classPowerBarPresent","alternativePowerBarPresent","normalAbsorbBarPresent","healingAbsorbBarPresent"})do unit[field]=true end
        controller.RefreshCompositionTree();Drain()
        local before=h.Copy(unit.Texts);local entries=CardActions(case[1]);local opened=#dialogs
        entries.Text();assert(#dialogs==opened+2)
        local library=ns.GUI.Editor.TextTemplateLibraryWindow
        local context=assert(h.ui.Upvalue(library.Open,"windowContext"))
        assert(context.anchorSelection.objectKey==case[2] and context.targetLabel==Row(case[1]).item.label)
        context.primaryButton:Fire("OnClick");Drain()
        local selected=selection.GetSelectedObject();assert(selected.kind=="text" and unit.Texts[selected.textKey].anchorTo==case[2])
        local after=h.Copy(unit.Texts);after[selected.textKey]=nil;h.Equal(after,before)
        assert(state.GetPropertyScope().kind=="text" and state.GetPropertyScope().objectKey==selected.textKey)
        Row("textElement",selected.textKey).frame:Run("OnMouseDown","LeftButton");Drain()
        assert(window._focalPointCustomizeView=="properties" and selection.GetSelectedObject().textKey==selected.textKey)
        local saved=h.Copy(db);context.primaryButton:Fire("OnClick");h.Equal(db,saved)
        Back()
    end
end)
Test("direct template Cancel, replaced dialog, layout replacement and Workspace Close reject retained submissions",function()
    Start();local library=ns.GUI.Editor.TextTemplateLibraryWindow
    local function Open()
        local entries=CardActions("healthbar");entries.Text()
        return assert(h.ui.Upvalue(library.Open,"windowContext"))
    end
    local context=Open();local before=h.Copy(db)
    context.dialog.cancelButton:Fire("OnClick");context.primaryButton:Fire("OnClick");h.Equal(db,before)
    local fresh=Open();context.primaryButton:Fire("OnClick");h.Equal(db,before)
    assert(fresh.dialog.window.frame:IsShown());fresh.dialog:Close()
    context=Open();ns.ActiveLayoutResolver.InvalidateActiveRuntimeRoot();assert(ns.ActiveLayoutResolver.EnsureActiveRuntimeRoot(db))
    context.primaryButton:Fire("OnClick");h.Equal(db,before);context.dialog:Close()
    controller.RefreshCompositionTree();context=Open()
    window.closebutton:GetScript("OnClick")(window.closebutton);Drain();window=Build()
    context.primaryButton:Fire("OnClick");h.Equal(db,before);context.dialog:Close()
end)
Test("existing New Template handoff can reopen the same guarded picker and submit to its original bar",function()
    Start();local entries=CardActions("powerbar");entries.Text()
    local library=ns.GUI.Editor.TextTemplateLibraryWindow
    local context=assert(h.ui.Upvalue(library.Open,"windowContext"))
    local guiController=ns.GUIController;ns.GUIController=ns.GUIController or {}
    local openBuilder=ns.GUIController.OpenTextBuilderWindow;local request
    -- Existing builder navigation is the boundary; real picker suspend/return/submit execute.
    ns.GUIController.OpenTextBuilderWindow=function(value)request=value;return true end
    local before=h.Copy(db);context.dialog.secondaryButton:Fire("OnClick")
    assert(request and request.kind=="new-template" and not context.dialog.window.frame:IsShown())
    context.primaryButton:Fire("OnClick");h.Equal(db,before)
    assert(library.NotifyEntityReturn(request.returnContext,{templateId=context.entries[1].templateId}))
    assert(context.dialog.window.frame:IsShown())
    context.primaryButton:Fire("OnClick");Drain()
    assert(unit.Texts[selection.GetSelectedObject().textKey].anchorTo=="PowerBar")
    ns.GUIController.OpenTextBuilderWindow=openBuilder;ns.GUIController=guiController
    Back()
end)
Test("actual enUS and deDE locale entries describe the context and named Remove without changing identity",function()
    local keys={"COMPONENT_ADD_TEXT","COMPONENT_ADD_TARGET","COMPONENT_ADD_UNIT_DESCRIPTION","COMPONENT_REMOVE_NAMED_DESCRIPTION"}
    local saved={};for _,key in ipairs(keys)do saved[key]=ns.L[key]end
    local getLocale=GetLocale
    for _,locale in ipairs({"enUS","deDE"})do
        GetLocale=function()return locale end
        local localized={L={}};assert(loadfile("Locales/"..locale..".lua"))("FocalPoint",localized)
        for _,key in ipairs(keys)do ns.L[key]=assert(localized.L[key])end
        Start();local label=Row("powerbar").item.label
        local entries=CardActions("powerbar");assert(entries.Text and not entries["Add Child"])
        entries.Text()
        local library=ns.GUI.Editor.TextTemplateLibraryWindow;local context=h.ui.Upvalue(library.Open,"windowContext")
        assert(context.dialog.body.children[1].label:GetText()==string.format(ns.L.COMPONENT_ADD_TARGET,label));context.dialog:Close()
        entries=CardActions("powerbar");entries.Remove();local pending=confirms[#confirms]
        assert(pending.options.message==string.format(ns.L.COMPONENT_REMOVE_NAMED_DESCRIPTION,label))
        pending.options.cancel.onClick(pending.dialog)
    end
    GetLocale=getLocale;for _,key in ipairs(keys)do ns.L[key]=saved[key]end
end)
local function OpenRaidPicker(kind)
    local entries=CardActions(kind)
    assert(entries.Text and entries.Add)
    entries.Add()
    local picker=dialogs[#dialogs]
    assert(picker.body.children[1].label:GetText()=="Add to: "..Row(kind).item.label)
    assert(FindButton(picker.body,"Text"))
    assert(not FindButton(picker.body,"Portrait") and not FindButton(picker.body,"Decoration")
        and not FindButton(picker.body,"Class Resource Bar") and not FindButton(picker.body,"Leader"))
    return picker,assert(FindButton(picker.body,"Raid Target"))
end
Test("Raid Target pilot uses the existing catalog and atomically activates ATTACHED geometry at Health and Power",function()
    for _,case in ipairs({{"healthbar","HealthBar"},{"powerbar","PowerBar"}})do
        Start();PrepareRaid();unit.RaidTargetIcon.enabled=false
        local icon=unit.RaidTargetIcon;local before=h.Copy(unit)
        local picker,button=OpenRaidPicker(case[1]);button:Fire("OnClick");Drain()
        assert(unit.RaidTargetIcon==icon and icon.present and icon.enabled)
        assert(icon.placement=="ATTACHED" and icon.anchorTo==case[2] and icon.point=="CENTER" and icon.relativePoint=="TOP")
        assert(icon.offsetX==0 and icon.offsetY==0 and icon.size==before.RaidTargetIcon.size)
        local unchanged=h.Copy(unit);unchanged.RaidTargetIcon=before.RaidTargetIcon;h.Equal(unchanged,before)
        assert(selection.GetSelectedObject().indicatorKey=="RaidTargetIcon")
        Back();assert(Row("indicatorElement","RaidTargetIcon").item.node.inspectorTarget.indicatorKey=="RaidTargetIcon")
        Row("indicatorElement","RaidTargetIcon").frame:Run("OnMouseDown","LeftButton");Drain()
        assert(window._focalPointCustomizeView=="properties" and state.GetPropertyScope().objectKey=="RaidTargetIcon")
        Back()
        local entries=CardActions(case[1]);AssertTextOnly(entries)
        -- Global reactivation still preserves existing geometry and placement.
        icon.present=false;controller.RefreshCompositionTree();Row("unit").add:Run("OnMouseDown","LeftButton")
        button=assert(FindButton(dialogs[#dialogs].body,"Raid Target"));local geometry=h.Copy(icon)
        button:Fire("OnClick");Drain();geometry.present=true;geometry.enabled=true;h.Equal(icon,geometry)
    end
end)
Test("Raid Target mutation rejects invalid placement, missing references, stale identities and Combat before writes",function()
    Start();PrepareRaid()
    local mutations=ns.InspectorMutations;local root=ns.ActiveLayoutResolver.GetActiveRuntimeRoot()
    local context={unitKey="player",unitConfig=unit,placementTarget={kind="bar",unit="player",objectKey="PowerBar"},
        isCurrent=function()return ns.ActiveLayoutResolver.GetActiveRuntimeRoot()==root end}
    local valid=assert(mutations.GetContextIndicatorAddPlacement({kind="bar",objectKey="PowerBar"}))
    local function Reject(placement,code,ctx,key)
        local before=h.Copy(db);local beforeUnit=h.Copy(unit);local identity=unit.RaidTargetIcon
        local result=mutations.AddComponent(ctx or context,key or "RaidTargetIcon",placement)
        assert(not result.ok and (not code or result.errorCode==code),result.errorCode)
        h.Equal(db,before);h.Equal(unit,beforeUnit);assert(unit.RaidTargetIcon==identity)
    end
    for _,changes in ipairs({{anchorTo="Frame"},{anchorTo="CastBar"},{anchorTo="missing"},{placement="INSIDE"},
        {point="bad"},{relativePoint="bad"},{offsetX=501},{offsetY=math.huge},{offsetX=0/0},{offsetX="3"},{unknown=true}})do
        local input=h.Copy(valid);for k,v in pairs(changes)do input[k]=v end;Reject(input,"invalid_initial_placement")
    end
    local incomplete=h.Copy(valid);incomplete.point=nil;Reject(incomplete,"invalid_initial_placement")
    Reject(valid,"invalid_initial_placement",nil,"Portrait")
    Reject(setmetatable(h.Copy(valid),{__index=function()error("must not inspect metatable input")end}),"invalid_initial_placement")
    context.placementTarget.objectKey="HealthBar";Reject(valid,"reference_mismatch");context.placementTarget.objectKey="PowerBar"
    unit.powerBarPresent=false;Reject(valid,"reference_missing");unit.powerBarPresent=true
    local icon=unit.RaidTargetIcon;unit.RaidTargetIcon=nil;Reject(valid,"component_config_not_found");unit.RaidTargetIcon=icon
    unit.present=false;Reject(valid,"component_config_not_found");unit.present=nil
    local current=context.isCurrent;context.isCurrent=function()return false end;Reject(valid,"stale_context");context.isCurrent=current
    local layoutId=db.char.activeLayoutId;db.char.activeLayoutId="layout:other";Reject(valid,"stale_context");db.char.activeLayoutId=layoutId
    local combat=InCombatLockdown;InCombatLockdown=function()return true end;Reject(valid,"combat_blocked");InCombatLockdown=combat
    icon.present=true;icon.enabled=false;Reject(valid,"already_present");icon.present=false
    local activeUnits=ns.ActiveLayoutResolver.GetActiveRuntimeRoot().units
    activeUnits.player=nil;Reject(valid,"component_config_not_found");activeUnits.player=unit
    context.unitConfig=h.Copy(unit);Reject(valid,"component_config_not_found");context.unitConfig=unit
    -- Pilot validation must not enter getters which can normalize/materialize SavedVariables.
    context.getEditableUnitConfig=function()error("materializing getter reached")end
    local result=mutations.AddComponent(context,"RaidTargetIcon",valid);assert(result.ok and unit.RaidTargetIcon.present)
    ns.ActiveLayoutResolver.InvalidateActiveRuntimeRoot();assert(ns.ActiveLayoutResolver.EnsureActiveRuntimeRoot(db));Reject(valid,"stale_context")
end)
Test("Raid Target Cancel, singleton race and stale Unit/Workspace reject picker actions without partial activation",function()
    Start();PrepareRaid()
    local picker,button=OpenRaidPicker("healthbar");local before=h.Copy(db)
    picker:Close();button:Fire("OnClick");h.Equal(db,before)
    picker,button=OpenRaidPicker("healthbar")
    unit.RaidTargetIcon.present=true;unit.RaidTargetIcon.enabled=false
    before=h.Copy(db);button:Fire("OnClick");Drain();h.Equal(db,before)
    local entries=CardActions("healthbar");AssertTextOnly(entries)
    unit.RaidTargetIcon.present=false;picker,button=OpenRaidPicker("powerbar")
    ns.ActiveLayoutResolver.GetActiveRuntimeRoot().units.target=h.Copy(unit)
    assert(selection.SelectObject({kind="unit",unit="target"}));Drain();before=h.Copy(db)
    button:Fire("OnClick");Drain();h.Equal(db,before)
    assert(selection.SelectObject({kind="unit",unit="player"}));Drain()
    picker,button=OpenRaidPicker("healthbar")
    local root=ns.ActiveLayoutResolver.GetActiveRuntimeRoot()
    ns.ActiveLayoutResolver.InvalidateActiveRuntimeRoot();assert(ns.ActiveLayoutResolver.EnsureActiveRuntimeRoot(db)~=root)
    before=h.Copy(db);button:Fire("OnClick");Drain();h.Equal(db,before)
    controller.RefreshCompositionTree();picker,button=OpenRaidPicker("healthbar")
    local combat=InCombatLockdown;InCombatLockdown=function()return true end
    before=h.Copy(db);button:Fire("OnClick");Drain();h.Equal(db,before);InCombatLockdown=combat
    picker,button=OpenRaidPicker("healthbar")
    window.closebutton:GetScript("OnClick")(window.closebutton);Drain();before=h.Copy(db)
    button:Fire("OnClick");Drain();h.Equal(db,before);window=Build()
end)
Test("Raid Target editable-copy Cancel changes nothing; approved copy receives placement without changing the template",function()
    Start()
    -- Detached fixture source: real preset projection/copy must see the same absent singleton.
    local theme=ns.Themes.default.units.player
    local originalIndicators=theme.indicators
    theme.indicators=h.Copy(originalIndicators or {})
    theme.indicators.RaidTargetIcon={present=false}
    assert(ns:ActivateLayout("builtin:default"));Drain();window=Build()
    local resolver=ns.ActiveLayoutResolver
    local source=h.Copy(resolver.GetActiveRuntimeRoot().payload)
    local picker,button=OpenRaidPicker("healthbar");local before=h.Copy(db)
    button:Fire("OnClick");local pending=confirms[#confirms]
    pending.options.cancel.onClick(pending.dialog);Drain();h.Equal(db,before)
    picker,button=OpenRaidPicker("healthbar");button:Fire("OnClick");pending=confirms[#confirms]
    pending.options.primary.onClick(pending.dialog);Drain()
    local root=resolver.GetActiveRuntimeRoot();assert(root.record.createdFrom.id=="builtin:default")
    local icon=root.units.player.RaidTargetIcon
    assert(icon.present and icon.enabled and icon.placement=="ATTACHED" and icon.anchorTo=="HealthBar")
    assert(selection.GetSelectedObject().indicatorKey=="RaidTargetIcon")
    assert(ns:ActivateLayout("builtin:default"));h.Equal(resolver.GetActiveRuntimeRoot().payload,source)
    theme.indicators=originalIndicators
end)
Test("missing Raid Target record leaves only executable Text in the direct catalog; late removal and mutation reject without writes",function()
    local toolbar=ns.GUI.Editor.CanvasToolbar
    local capture=assert(h.ui.Upvalue(toolbar.OpenComponentCatalog,"CaptureComponentRequest"))
    local openPicker=assert(h.ui.Upvalue(toolbar.OpenComponentCatalog,"OpenAddObjectPicker"))
    for _,case in ipairs({{"healthbar","HealthBar"},{"powerbar","PowerBar"}})do
        Start();PrepareRaid()
        local entries=CardActions(case[1]);local oldAdd=assert(entries.Add)
        local ref={kind="bar",unit="player",objectKey=case[2]}
        local request=assert(capture(ref,function()return controller.GetActiveInspectorHost()==window end,Row(case[1]).item.label))
        request.indicatorPlacement=assert(ns.InspectorMutations.GetContextIndicatorAddPlacement(ref))
        unit.RaidTargetIcon=nil
        local before=h.Copy(db);local countBefore=#dialogs
        oldAdd();assert(#dialogs==countBefore+1);assert(not FindButton(dialogs[#dialogs].body,"Raid Target"));dialogs[#dialogs]:Close();h.Equal(db,before)
        entries=CardActions(case[1]);AssertTextOnly(entries)
        -- Exercise the existing catalog renderer independently of the direct action.
        openPicker(true,request)
        local picker=dialogs[#dialogs]
        assert(not FindButton(picker.body,"Raid Target") and FindButton(picker.body,"Text"))
        picker:Close();h.Equal(db,before)
        local result=ns.InspectorMutations.AddComponent({unitKey="player",unitConfig=unit,
            isCurrent=request.isCurrent,placementTarget=ref},"RaidTargetIcon",request.indicatorPlacement)
        assert(not result.ok and result.errorCode=="component_config_not_found");h.Equal(db,before)
        -- Missing after catalog construction: the retained button must not activate or recreate it.
        PrepareRaid();local button;picker,button=OpenRaidPicker(case[1]);unit.RaidTargetIcon=nil;before=h.Copy(db)
        button:Fire("OnClick");Drain();h.Equal(db,before);assert(unit.RaidTargetIcon==nil)
        -- The previous global catalog and missing-record behavior remain unchanged.
        Row("unit").add:Run("OnMouseDown","LeftButton")
        local global=dialogs[#dialogs];local add=assert(FindButton(global.body,"Raid Target"))
        before=h.Copy(db);add:Fire("OnClick");Drain();h.Equal(db,before)
        PrepareRaid();unit.RaidTargetIcon.present=true;unit.RaidTargetIcon.enabled=false
        entries=CardActions(case[1]);AssertTextOnly(entries)
    end
end)
Test("pilot-created Raid Target survives actual Export/Import and serialized SavedVariables/root reload",function()
    for _,case in ipairs({{"healthbar","HealthBar"},{"powerbar","PowerBar"}})do
        Start();PrepareRaid()
        local picker,button=OpenRaidPicker(case[1]);button:Fire("OnClick");Drain()
        local expected=h.Copy(unit.RaidTargetIcon)
        local encoded=assert(ns.LayoutTransfer.Export("layout:existing"))
        local codec=ns.LayoutTransferCodec
        local document=assert(codec.Decode(encoded));h.Equal(document.payload.Units.player.RaidTargetIcon,expected)
        local ok,id=ns.LayoutTransfer.Import(encoded);assert(ok,id)
        h.Equal(db.global.UserLayouts[id].payload.Units.player.RaidTargetIcon,expected)
        assert(ns:ActivateLayout(id));Drain()
        h.Equal(ns.ActiveLayoutResolver.GetActiveRuntimeRoot().units.player.RaidTargetIcon,expected)
        -- Existing fixture boundary: serialize persisted roots, recreate the AceDB wrapper,
        -- then resolve a fresh runtime root. This does not simulate native pixel geometry.
        local saved=assert(codec.Decode(assert(codec.Encode({global=db.global,char=db.char}))))
        local reloaded={global=saved.global,char=saved.char,sv={global=saved.global}}
        local resolver=ns.ActiveLayoutResolver;local previous=resolver.GetActiveRuntimeRoot()
        ns.db=reloaded;resolver.InvalidateActiveRuntimeRoot()
        local root=assert(resolver.EnsureActiveRuntimeRoot(reloaded));assert(root~=previous and root.layoutId==id)
        h.Equal(root.units.player.RaidTargetIcon,expected)
        assert(root.units.player.RaidTargetIcon.present and root.units.player.RaidTargetIcon.enabled)
    end
end)
local contextIndicators={{key="RaidTargetIcon",label="Raid Target"},{key="LeaderIcon",label="Leader"},{key="RoleIcon",label="Role"}}
local function StartIndicator(key,unitKey)
    Start();unitKey=unitKey or "player"
    if unitKey~="player" then
        local units=ns.ActiveLayoutResolver.GetActiveRuntimeRoot().units
        units[unitKey]=h.Copy(unit);assert(selection.SelectUnitRoot(unitKey));Drain();unit=units[unitKey]
    end
    unit[key]=h.Copy(defaults:GetDefaultDB().profile.Units.player[key]);unit[key].present=false
    controller.RefreshCompositionTree();Drain()
end
local function OpenIndicatorPicker(kind,label)
    local entries=CardActions(kind);assert(entries.Text and entries.Add)
    entries.Add()
    local picker=dialogs[#dialogs]
    assert(FindButton(picker.body,"Text") and not FindButton(picker.body,"Portrait")
        and not FindButton(picker.body,"Combat") and not FindButton(picker.body,"Resting")
        and not FindButton(picker.body,"Ready Check") and not FindButton(picker.body,"Decoration"))
    return picker,assert(FindButton(picker.body,label))
end
Test("only Raid Target, Leader and Role opt into the same context metadata contract",function()
    local expected={RaidTargetIcon=true,LeaderIcon=true,RoleIcon=true};local found=0
    for key,meta in pairs(ns.GUI.Editor.SidebarShared.INDICATOR_META)do
        if meta.contextAttached then assert(expected[key],key);found=found+1 end
    end
    assert(found==3)
    StartIndicator("RoleIcon")
    local meta=ns.GUI.Editor.SidebarShared.INDICATOR_META.RoleIcon;meta.contextAttached=false
    local entries=CardActions("healthbar");AssertTextOnly(entries)
    local before=h.Copy(db)
    local result=ns.InspectorMutations.AddComponent({unitKey="player",unitConfig=unit,
        isCurrent=function()return true end,placementTarget={kind="bar",unit="player",objectKey="HealthBar"}},
        "RoleIcon",assert(ns.InspectorMutations.GetContextIndicatorAddPlacement({kind="bar",objectKey="HealthBar"})))
    assert(not result.ok and result.errorCode=="invalid_initial_placement");h.Equal(db,before);meta.contextAttached=true
end)
Test("18 unit/type/target combinations retain ATTACHED geometry, record identity, Properties and global re-add",function()
    for _,unitKey in ipairs({"player","target","focus"})do
        for _,item in ipairs(contextIndicators)do
            for _,target in ipairs({{"healthbar","HealthBar"},{"powerbar","PowerBar"}})do
                StartIndicator(item.key,unitKey)
                local identity=unit[item.key];local before=h.Copy(unit);local expected=h.Copy(identity)
                expected.placement="ATTACHED";expected.anchorTo=target[2];expected.point="CENTER";expected.relativePoint="TOP"
                expected.offsetX=0;expected.offsetY=0;expected.present=true;expected.enabled=true
                local picker,button=OpenIndicatorPicker(target[1],item.label);button:Fire("OnClick");Drain()
                assert(unit[item.key]==identity);h.Equal(identity,expected);before[item.key]=expected;h.Equal(unit,before)
                assert(selection.GetSelectedObject().indicatorKey==item.key and selection.GetSelectedObject().unit==unitKey)
                Back();Row("indicatorElement",item.key).frame:Run("OnMouseDown","LeftButton");Drain()
                assert(window._focalPointCustomizeView=="properties" and state.GetPropertyScope().objectKey==item.key);Back()
                identity.present=false;controller.RefreshCompositionTree();Row("unit").add:Run("OnMouseDown","LeftButton")
                button=assert(FindButton(dialogs[#dialogs].body,item.label));button:Fire("OnClick");Drain()
                assert(unit[item.key]==identity);h.Equal(identity,expected)
            end
        end
    end
end)
Test("missing records, disabled singletons, Presence races and Boss availability agree between catalog and mutation",function()
    for _,item in ipairs(contextIndicators)do
        for _,target in ipairs({{"healthbar","HealthBar"},{"powerbar","PowerBar"}})do
            StartIndicator(item.key);local picker,button=OpenIndicatorPicker(target[1],item.label)
            unit[item.key]=nil;local before=h.Copy(db);local callback=button.events.OnClick;callback();Drain();h.Equal(db,before)
            local entries=CardActions(target[1]);AssertTextOnly(entries)
            local ref={kind="bar",unit="player",objectKey=target[2]}
            local result=ns.InspectorMutations.AddComponent({unitKey="player",unitConfig=unit,placementTarget=ref,
                isCurrent=function()return true end},item.key,ns.InspectorMutations.GetContextIndicatorAddPlacement(ref))
            assert(not result.ok and result.errorCode=="component_config_not_found");h.Equal(db,before)
            StartIndicator(item.key);picker,button=OpenIndicatorPicker(target[1],item.label)
            unit[item.key].present=true;unit[item.key].enabled=false;before=h.Copy(db)
            button:Fire("OnClick");Drain();h.Equal(db,before)
            entries=CardActions(target[1]);AssertTextOnly(entries)
        end
    end
    for _,item in ipairs({contextIndicators[2],contextIndicators[3]})do
        StartIndicator(item.key,"boss")
        for _,target in ipairs({{"healthbar","HealthBar"},{"powerbar","PowerBar"}})do
            local entries=CardActions(target[1]);AssertTextOnly(entries)
            local ref={kind="bar",unit="boss",objectKey=target[2]};local before=h.Copy(db)
            local result=ns.InspectorMutations.AddComponent({unitKey="boss",unitConfig=unit,placementTarget=ref,
                isCurrent=function()return true end},item.key,ns.InspectorMutations.GetContextIndicatorAddPlacement(ref))
            assert(not result.ok and result.errorCode=="component_unavailable");h.Equal(db,before)
        end
    end
end)
Test("each opted-in type rejects invalid geometry and already-present records before any write",function()
    for _,item in ipairs(contextIndicators)do
        StartIndicator(item.key)
        local root=ns.ActiveLayoutResolver.GetActiveRuntimeRoot()
        local ref={kind="bar",unit="player",objectKey="HealthBar"}
        local context={unitKey="player",unitConfig=unit,placementTarget=ref,
            isCurrent=function()return ns.ActiveLayoutResolver.GetActiveRuntimeRoot()==root end}
        local placement=assert(ns.InspectorMutations.GetContextIndicatorAddPlacement(ref))
        for _,invalid in ipairs({{anchorTo="CastBar"},{placement="INSIDE"},{point="invalid"},{offsetX=math.huge}})do
            local input=h.Copy(placement);for k,v in pairs(invalid)do input[k]=v end
            local before=h.Copy(db);local record=unit[item.key]
            local result=ns.InspectorMutations.AddComponent(context,item.key,input)
            assert(not result.ok and result.errorCode=="invalid_initial_placement");h.Equal(db,before);assert(unit[item.key]==record)
        end
        unit[item.key].present=true;unit[item.key].enabled=false
        local before=h.Copy(db);local result=ns.InspectorMutations.AddComponent(context,item.key,placement)
        assert(not result.ok and result.errorCode=="already_present");h.Equal(db,before)
    end
end)
Test("all three types reject Cancel, replaced picker, Combat and stale Unit/Layout/Workspace callbacks without writes",function()
    for _,item in ipairs(contextIndicators)do
        StartIndicator(item.key);local picker,button=OpenIndicatorPicker("healthbar",item.label)
        local callback=button.events.OnClick;local before=h.Copy(db);picker:Close();callback();h.Equal(db,before)
        picker,button=OpenIndicatorPicker("healthbar",item.label);callback=button.events.OnClick
        local fresh=OpenIndicatorPicker("healthbar",item.label);callback();h.Equal(db,before);assert(fresh.window.frame:IsShown());fresh:Close()
        picker,button=OpenIndicatorPicker("powerbar",item.label)
        local combat=InCombatLockdown;InCombatLockdown=function()return true end
        button:Fire("OnClick");Drain();h.Equal(db,before);InCombatLockdown=combat
        picker,button=OpenIndicatorPicker("healthbar",item.label);callback=button.events.OnClick
        local units=ns.ActiveLayoutResolver.GetActiveRuntimeRoot().units;units.target=h.Copy(unit)
        assert(selection.SelectUnitRoot("target"));Drain();before=h.Copy(db);callback();Drain();h.Equal(db,before)
        StartIndicator(item.key);picker,button=OpenIndicatorPicker("healthbar",item.label);callback=button.events.OnClick
        local ok,id=ns.LayoutMutations.CopyLayout("layout:existing",nil,{activate=false});assert(ok,id)
        assert(ns:ActivateLayout(id));Drain();before=h.Copy(db);callback();Drain();h.Equal(db,before)
        StartIndicator(item.key);picker,button=OpenIndicatorPicker("healthbar",item.label);callback=button.events.OnClick
        window.closebutton:GetScript("OnClick")(window.closebutton);Drain();window=Build()
        before=h.Copy(db);callback();Drain();h.Equal(db,before)
    end
end)
Test("Leader and Role use the real editable-copy Cancel/Confirm contract without changing the source",function()
    for _,item in ipairs({contextIndicators[2],contextIndicators[3]})do
        Start();local theme=ns.Themes.default.units.player;local original=theme.indicators
        theme.indicators=h.Copy(original or {});theme.indicators[item.key]={present=false}
        assert(ns:ActivateLayout("builtin:default"));Drain();window=Build()
        local resolver=ns.ActiveLayoutResolver;local source=h.Copy(resolver.GetActiveRuntimeRoot().payload)
        local picker,button=OpenIndicatorPicker("healthbar",item.label);local before=h.Copy(db)
        button:Fire("OnClick");local pending=confirms[#confirms];pending.options.cancel.onClick(pending.dialog);Drain();h.Equal(db,before)
        picker,button=OpenIndicatorPicker("healthbar",item.label);button:Fire("OnClick");pending=confirms[#confirms]
        pending.options.primary.onClick(pending.dialog);Drain()
        local root=resolver.GetActiveRuntimeRoot();local icon=root.units.player[item.key]
        assert(root.record.createdFrom.id=="builtin:default" and icon.present and icon.enabled
            and icon.placement=="ATTACHED" and icon.anchorTo=="HealthBar")
        assert(selection.GetSelectedObject().indicatorKey==item.key)
        assert(ns:ActivateLayout("builtin:default"));h.Equal(resolver.GetActiveRuntimeRoot().payload,source);theme.indicators=original
    end
end)
Test("Leader and Role retain full records through actual Export/Import and serialized SavedVariables reload at both targets",function()
    for _,item in ipairs({contextIndicators[2],contextIndicators[3]})do
        for _,target in ipairs({"healthbar","powerbar"})do
            StartIndicator(item.key);local picker,button=OpenIndicatorPicker(target,item.label);button:Fire("OnClick");Drain()
            local expected=h.Copy(unit[item.key]);local encoded=assert(ns.LayoutTransfer.Export("layout:existing"))
            local codec=ns.LayoutTransferCodec;local document=assert(codec.Decode(encoded));h.Equal(document.payload.Units.player[item.key],expected)
            local ok,id=ns.LayoutTransfer.Import(encoded);assert(ok,id);h.Equal(db.global.UserLayouts[id].payload.Units.player[item.key],expected)
            assert(ns:ActivateLayout(id));Drain();h.Equal(ns.ActiveLayoutResolver.GetActiveRuntimeRoot().units.player[item.key],expected)
            local saved=assert(codec.Decode(assert(codec.Encode({global=db.global,char=db.char}))))
            local reloaded={global=saved.global,char=saved.char,sv={global=saved.global}}
            local resolver=ns.ActiveLayoutResolver;local previous=resolver.GetActiveRuntimeRoot()
            ns.db=reloaded;resolver.InvalidateActiveRuntimeRoot();local root=assert(resolver.EnsureActiveRuntimeRoot(reloaded))
            assert(root~=previous and root.layoutId==id);h.Equal(root.units.player[item.key],expected)
        end
    end
end)
Test("the single Unit plus shares the tree scroll owner and gives the removed header row to the list",function()
    Start()
    for i=1,45 do unit.Texts["scroll"..i]={tag="[name]",enabled=true}end
    controller.RefreshCompositionTree();Drain()
    local control=Tree().control
    local tree=window._focalPointCompositionHost
    control.frame:SetSize(tree.frame:GetWidth(),tree.frame:GetHeight());assert(control:Layout())
    assert(control.maxScroll>0 and window._focalPointComponentAddButton==nil)
    assert(tree.frame.points.TOPLEFT.y==-36)
    assert(Row("unit").add:GetParent()==Row("unit").frame)
    control:SetScroll(control.maxScroll);assert(control.offset>0)
    Row("powerbar").frame:Run("OnMouseDown","LeftButton");Drain()
    assert(window._focalPointPropertyScroll.parent.frame.points.TOPLEFT.y==-36)
    Back();assert(window._focalPointCustomizeView=="components")
end)
Test("20 expand/actions/reopen cycles keep explicit parents and all five input zones separate",function()
    Start()
    for _=1,20 do
        local before=h.Copy(selection.GetSelectedObject())
        Row("healthbar").disclosure:Run("OnMouseDown","LeftButton");Drain()
        assert(window._focalPointCustomizeView=="components");h.Equal(selection.GetSelectedObject(),before)
        Row("healthbar").disclosure:Run("OnMouseDown","LeftButton");Drain()
        local entries=CardActions("powerbar");assert(entries.Text)
        Row("powerbar").toggle:Run("OnClick","LeftButton");Drain()
        assert(window._focalPointCustomizeView=="components");h.Equal(selection.GetSelectedObject(),before)
        Row("powerbar").frame:Run("OnMouseDown","LeftButton");Drain()
        assert(window._focalPointCustomizeView=="properties" and selection.GetSelectedObject().objectKey=="PowerBar")
        Back();window.closebutton:GetScript("OnClick")(window.closebutton);Drain();window=Build()
    end
end)
Test("direct action visuals, tooltips and narrow card anchors preserve all five input zones",function()
    Start()
    local tooltip,original={lines={}},GameTooltip
    function tooltip:SetOwner(owner)self.owner=owner end
    function tooltip:IsOwned(owner)return self.owner==owner end
    function tooltip:ClearLines()self.lines={}end
    function tooltip:AddLine(text)self.lines[#self.lines+1]=text end
    function tooltip:Show()self.shown=true end
    function tooltip:Hide()self.shown=false;self.owner=nil end
    GameTooltip=tooltip
    local power=Row("powerbar");local health=Row("healthbar")
    assert(health.add:IsShown() and health.remove:IsShown() and not health.remove:IsEnabled())
    assert(power.add:IsShown() and power.remove:IsShown() and power.toggle:IsShown())
    for _,row in ipairs({power,health})do
        assert(row.add:GetWidth()==28 and row.add:GetHeight()==26)
        assert(row.remove:GetWidth()==28 and row.remove:GetHeight()==26)
        local _,size=row.addGlyph:GetFont();assert(size==26 and row.addGlyph:GetText()=="+")
        h.Equal(row.addGlyph.lastSetTextColor,{1,.82,0,1})
        h.Equal(row.removeGlyph.lastSetVertexColor,row.item.removable and {1,.08,.08,1} or {.5,.5,.5,1})
        assert(row.removeGlyph.atlas=="common-icon-delete")
        h.Equal(row.add.lastSetHighlightTexture,{130753,"ADD"})
        h.Equal(row.remove.lastSetPushedTexture,{130753})
        row.add:Run("OnEnter");assert(tooltip.shown and tooltip.owner==row.add and #tooltip.lines==2)
        row.add:Run("OnLeave");assert(not tooltip.shown)
    end
    assert(power.remove.points.RIGHT.relative==power.toggle and power.add.points.RIGHT.relative==power.remove)
    assert(power.label.points.RIGHT.relative==power.add and health.label.points.RIGHT.relative==health.add)
    local originalLabel=power.item.label
    for _,label in ipairs({"Primary Power Bar with a deliberately long component name",
        "Primaere Ressourcenleiste mit besonders langer Komponentenbezeichnung"})do
        power.item.label=label;power.label:SetText(label)
        power.frame:Run("OnEnter");assert(tooltip.lines[1]==label)
        assert(power.label.points.RIGHT.relative==power.add and power.add.points.RIGHT.relative==power.remove)
        power.frame:Run("OnLeave")
    end
    power.item.label=originalLabel;power.label:SetText(originalLabel)
    for _,width in ipairs({320,360})do
        local control=Tree().control;control.frame:SetSize(width,68);control:Layout()
        for i=1,control.count do
            local row=control.rows[i];local item=row.item
            local indent=row.frame.points.TOPLEFT.x
            local actions=(item.addable and 32 or 0)+32
            -- Assert the anchored label budget; native font clipping remains an ingame check.
            local budget=width-10-indent-45-4-36-actions
            assert(budget>=100,"card label budget below 100px")
            if item.removable then assert(row.remove.points.RIGHT.relative==row.toggle)end
        end
        control:SetScroll(control.maxScroll)
        assert(window._focalPointComponentAddButton==nil and Row("unit").add:IsShown())
    end
    power.remove:Run("OnEnter");assert(tooltip.shown and tooltip.lines[2]==(ns.L.INFO_COMMON_REMOVE or "Remove"))
    controller.RefreshCompositionTree();Drain();assert(not tooltip.shown)
    GameTooltip=original
end)
Test("retained direct button scripts reject rebuild, pooling and Combat while fresh buttons remain usable",function()
    Start()
    local row=Row("powerbar");local add,remove=row.add:GetScript("OnMouseDown"),row.remove:GetScript("OnMouseDown")
    local toggle=row.toggle:GetScript("OnClick")
    local before=h.Copy(db);local opened,pending=#dialogs,#confirms
    controller.RefreshCompositionTree();Drain()
    add(row.add,"LeftButton");remove(row.remove,"LeftButton")
    toggle(row.toggle,"LeftButton")
    assert(#dialogs==opened and #confirms==pending);h.Equal(db,before)
    local actions=CardActions("powerbar");local combat=InCombatLockdown
    InCombatLockdown=function()return true end
    actions.Add();actions.Remove();assert(#dialogs==opened and #confirms==pending);h.Equal(db,before)
    InCombatLockdown=combat
    actions.Add();assert(#dialogs==opened+1);dialogs[#dialogs]:Close()
    window.closebutton:GetScript("OnClick")(window.closebutton);Drain();window=Build()
    add(row.add,"LeftButton");remove(row.remove,"LeftButton")
    toggle(row.toggle,"LeftButton")
    assert(#confirms==pending and #dialogs==opened+1);h.Equal(db,before)
    actions=CardActions("powerbar");actions.Remove();assert(#confirms==pending+1)
    confirms[#confirms].options.cancel.onClick(confirms[#confirms].dialog)
end)
Test("the existing direct Text API remains available independently of tree plus and catalog navigation",function()
    Start()
    local toolbar=ns.GUI.Editor.CanvasToolbar
    toolbar.OpenComponentAdd({kind="bar",unit="player",objectKey="HealthBar"},function()return true end,"Health Bar")
    local context=h.ui.Upvalue(ns.GUI.Editor.TextTemplateLibraryWindow.Open,"windowContext")
    assert(context.anchorSelection.objectKey=="HealthBar" and context.targetUnit=="player")
    context.dialog:Close()
end)
Test("child Indicators and Decorations expose only the existing guarded trash action",function()
    StartIndicator("LeaderIcon")
    local picker,button=OpenIndicatorPicker("healthbar","Leader");button:Fire("OnClick");Drain();Back()
    local record=unit.LeaderIcon;local row=Row("indicatorElement","LeaderIcon")
    assert(row.item.depth==2 and row.remove:IsShown() and not row.add:IsShown())
    CardActions("indicatorElement","LeaderIcon").Remove()
    local pending=confirms[#confirms];pending.options.cancel.onClick(pending.dialog)
    assert(unit.LeaderIcon==record and record.present)
    CardActions("indicatorElement","LeaderIcon").Remove();pending=confirms[#confirms]
    pending.options.primary.onClick(pending.dialog);Drain()
    assert(unit.LeaderIcon==record and record.present==false)
    Row("unit").add:Run("OnMouseDown","LeftButton")
    assert(FindButton(dialogs[#dialogs].body,"Decoration")):Fire("OnClick");Drain();Back()
    local id=unit.decorations[#unit.decorations].id
    row=Row("decorationElement",id);assert(row.remove:IsShown() and not row.add:IsShown())
    CardActions("decorationElement",id).Remove();pending=confirms[#confirms]
    pending.options.primary.onClick(pending.dialog);Drain()
    for _,decoration in ipairs(unit.decorations)do assert(decoration.id~=id)end
end)
Test("Unit plus retains the global Unit catalog under a selected Bar and rejects stale and Combat clicks",function()
    Start();PrepareRaid()
    Row("powerbar").frame:Run("OnMouseDown","LeftButton");Drain();Back()
    assert(selection.GetSelectedObject().objectKey=="PowerBar")
    CardActions("unit").Add()
    local picker=dialogs[#dialogs]
    assert(picker.body.children[1].label:GetText()=="Choose what to add to player.")
    assert(FindButton(picker.body,"Decoration") and FindButton(picker.body,"Class Resource Bar"))
    assert(FindButton(picker.body,"Text")):Fire("OnClick")
    local context=h.ui.Upvalue(ns.GUI.Editor.TextTemplateLibraryWindow.Open,"windowContext")
    assert(context.anchorSelection.kind=="unit" and context.targetUnit=="player")
    context.dialog:Close()
    local root=Row("unit");local old=root.add:GetScript("OnMouseDown")
    local opened=#dialogs;local before=h.Copy(db)
    controller.RefreshCompositionTree();Drain();old(root.add,"LeftButton")
    assert(#dialogs==opened);h.Equal(db,before)
    local combat=InCombatLockdown;InCombatLockdown=function()return true end
    CardActions("unit").Add();assert(#dialogs==opened);h.Equal(db,before)
    InCombatLockdown=combat
    local units=ns.ActiveLayoutResolver.GetActiveRuntimeRoot().units;units.target=h.Copy(unit)
    local stale=CardActions("unit").Add
    assert(selection.SelectUnitRoot("target"));Drain();stale();assert(#dialogs==opened)
    CardActions("unit").Add();picker=dialogs[#dialogs]
    assert(picker.body.children[1].label:GetText()=="Choose what to add to target.");picker:Close()
end)
Test("Unit and Health keep passive grey Trash/Show cells while ordinary native checkboxes toggle once",function()
    Start()
    local before=h.Copy(db);local selected=h.Copy(selection.GetSelectedObject());local pending=#confirms
    for _,kind in ipairs({"unit","healthbar"})do
        local row=Row(kind)
        assert(row.add:IsShown() and row.remove:IsShown() and row.toggle:IsShown())
        assert(row.item.addable and not row.item.removable and not row.item.toggleable)
        assert(not row.remove:IsEnabled() and not row.toggle:IsEnabled())
        assert(row.toggle.template=="UICheckButtonArtTemplate" and row.toggle:GetWidth()==26)
        h.Equal(row.toggle.clickButtons,{"LeftButtonDown"})
        for _,button in ipairs({row.remove,row.toggle})do
            assert(not button:GetScript("OnMouseDown") and not button:GetScript("OnClick") and not button:GetScript("OnEnter"))
            button:Run("OnMouseDown","LeftButton");button:Run("OnEnter");button:Run("OnClick")
        end
        assert(#confirms==pending);h.Equal(db,before);h.Equal(selection.GetSelectedObject(),selected)
        assert(row.remove.points.RIGHT.relative==row.toggle and row.add.points.RIGHT.relative==row.remove)
    end
    local power=Row("powerbar");assert(power.toggle:IsEnabled() and power.toggle:GetChecked())
    power.toggle:Run("OnClick","LeftButton");Drain()
    power=Row("powerbar");assert(unit.showPowerBar==false and not power.toggle:GetChecked())
    power.toggle:Run("OnMouseDown","LeftButton");assert(unit.showPowerBar==false)
    power.toggle:Run("OnClick","LeftButton");Drain();assert(unit.showPowerBar==true)
    assert(window._focalPointCustomizeView=="components");h.Equal(selection.GetSelectedObject(),selected)
end)
local restoreUnits={"pet","targettarget","focus","focustarget","boss"}
local function MissingUnits()
    Start()
    local units=ns.ActiveLayoutResolver.GetActiveRuntimeRoot().units
    for _,key in ipairs(restoreUnits)do units[key]=h.Copy(unit);units[key].present=false end
    units.target=h.Copy(unit);units.target.present=true
    window=Build()
    assert(window._focalPointUnitRestoreButton==nil)
    return units
end
local function OpenUnits()
    local opened=#dialogs;ns.GUI.Editor.CanvasToolbar.OpenEntityAddObjectPicker()
    assert(#dialogs==opened+1)
    return dialogs[#dialogs]
end
Test("global Add Unit offers only five supported missing Units and reselects each root in Arrange or Customize",function()
    for index,key in ipairs(restoreUnits)do
        local units=MissingUnits();local arrange=index%2==1
        controller.SetPresentation(arrange and "arrange" or "customize")
        local picker=OpenUnits();assert(picker.window.titletext:GetText()=="Add Unit")
        local entries=0
        for _,child in ipairs(picker.body.children[3].children)do if child.type=="Button"then entries=entries+1 end end
        assert(entries==5 and not FindButton(picker.body,"Text") and not FindButton(picker.body,"Decoration")
            and not FindButton(picker.body,"Power Bar") and not FindButton(picker.body,"Class Resource Bar"))
        local record=units[key]
        assert(FindButton(picker.body,key=="boss" and "Boss Frames" or key)):Fire("OnClick");Drain()
        assert(record.present and ns.ActiveLayoutResolver.GetActiveRuntimeRoot().units[key]==record)
        local selected=selection.GetSelectedObject();assert(selected.kind=="unit" and selected.unit==key)
        assert(state.IsArrange()==arrange)
    end
end)
Test("global Unit catalog filters records and existing Units, and opens nothing when empty",function()
    local units=MissingUnits();units.pet.present=true;units.focus=nil;units.target.present=false
    local picker=OpenUnits()
    assert(not FindButton(picker.body,"pet") and not FindButton(picker.body,"focus")
        and not FindButton(picker.body,"target") and not FindButton(picker.body,"player"))
    picker:Close()
    for _,key in ipairs(restoreUnits)do if units[key]then units[key].present=true end end
    local opened=#dialogs;ns.GUI.Editor.CanvasToolbar.OpenEntityAddObjectPicker();assert(#dialogs==opened)
    assert(Row("unit").add:IsShown())
end)
Test("global Unit Cancel, Combat, Presence race and stale Unit/object/layout/reopen callbacks never write",function()
    MissingUnits();local before=h.Copy(db);local picker=OpenUnits()
    picker.cancelButton:Fire("OnClick");Drain();h.Equal(db,before)
    local combat=InCombatLockdown;InCombatLockdown=function()return true end
    local opened=#dialogs;ns.GUI.Editor.CanvasToolbar.OpenEntityAddObjectPicker();assert(#dialogs==opened)
    InCombatLockdown=combat
    for _,case in ipairs({"combat","presence","unit","object","layout","reopen"})do
        local units=MissingUnits();picker=OpenUnits();local button=assert(FindButton(picker.body,"pet"))
        if case=="combat"then InCombatLockdown=function()return true end
        elseif case=="presence"then units.pet.present=true
        elseif case=="unit"then assert(selection.SelectUnitRoot("target"));Drain()
        elseif case=="object"then Row("powerbar").frame:Run("OnMouseDown","LeftButton");Drain()
        elseif case=="layout"then assert(ns:ActivateLayout("builtin:default"));Drain()
        else ns.CloseConfig();Drain();window=Build() end
        before=h.Copy(db);local selected=h.Copy(selection.GetSelectedObject())
        button:Fire("OnClick");Drain();h.Equal(db,before);h.Equal(selection.GetSelectedObject(),selected)
        InCombatLockdown=combat
    end
end)
Test("global Unit Add uses real editable-copy Cancel/Confirm and preserves the builtin",function()
    Start()
    local getDefaults=ns.GetDefaultDB
    ns.GetDefaultDB=function(self)
        local defaults=h.Copy(getDefaults(self));defaults.profile.Units.pet.present=false;return defaults
    end
    assert(ns:ActivateLayout("builtin:default"));Drain();window=Build();controller.SetPresentation("arrange")
    local source=h.Copy(ns.ActiveLayoutResolver.GetActiveRuntimeRoot().payload)
    local picker=OpenUnits();local before=h.Copy(db)
    assert(FindButton(picker.body,"pet")):Fire("OnClick")
    local pending=confirms[#confirms];pending.options.cancel.onClick(pending.dialog);Drain();h.Equal(db,before)
    picker=OpenUnits();assert(FindButton(picker.body,"pet")):Fire("OnClick")
    pending=confirms[#confirms];pending.options.primary.onClick(pending.dialog);Drain()
    local root=ns.ActiveLayoutResolver.GetActiveRuntimeRoot()
    assert(root.record.createdFrom.id=="builtin:default" and root.units.pet.present)
    assert(selection.GetSelectedObject().unit=="pet" and state.IsArrange())
    assert(ns:ActivateLayout("builtin:default"));h.Equal(ns.ActiveLayoutResolver.GetActiveRuntimeRoot().payload,source)
    ns.GetDefaultDB=getDefaults
end)
assert(#h.ui.env.errors==0,table.concat(h.ui.env.errors,"\n"))
print("Component Actions: "..count.." groups PASS")
