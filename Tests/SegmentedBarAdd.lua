-- Actual Add Object dialog -> editable workflow -> C1b -> tree/selection/Inspector.
-- Detached stores and native UI doubles; no SavedVariables or files are written.
local function Read(path)local f=assert(io.open(path));local s=f:read("*a");f:close();return s end
local h=assert(load(Read("Tests/SegmentedBarSelection.lua")..
    "\nreturn {ns=ns,Setup=Setup,ui=ui,state=state,selection=selection,Nodes=Nodes,BuildInspector=BuildInspector,Copy=Copy,Equal=Equal}",
    "@SegmentedBarAdd/Fixture"))()
local ns,ui,state=h.ns,h.ui,h.state
local R,M=ns.ActiveLayoutResolver,ns.LayoutMutations.SegmentedBars
assert(loadfile("GUI/Editor/CanvasToolbar.lua"))("FocalPoint",ns)
local toolbar=ns.GUI.Editor.CanvasToolbar
local dialogs,confirmations,errors={},{},{}
local widgets=ns.GUI.Helpers.FormWidgets
local form,confirm=widgets.CreateCompactFormDialog,widgets.CreateCompactConfirmation
widgets.CreateCompactFormDialog=function(options)local d=form(options);dialogs[#dialogs+1]=d;return d end
widgets.CreateCompactConfirmation=function(options)local d=confirm(options);confirmations[#confirmations+1]={dialog=d,options=options};return d end
ns.Info=function(_,message)errors[#errors+1]=message end
local refreshes=0
ns.RefreshUnitFrame=function(_,unit)assert(unit=="player");refreshes=refreshes+1 end
ns.GUI.RequestRefreshOptions=function()end
-- Activation boundary only: the real copy, store, resolver and workflow execute.
ns.ActivateLayout=function(_,id)
    ns.db.char.activeLayoutId=id;R.InvalidateActiveRuntimeRoot()
    return R.EnsureActiveRuntimeRoot(ns.db)~=nil
end
local function Activate(id)assert(ns:ActivateLayout(id))end
local function Setup()
    local db,unit=h.Setup();state.SetSingleSelection("player");state.ClearPropertyScope()
    errors={};refreshes=0;return db,unit
end
local function FindButton(widget,label)
    if widget.type=="Button" and widget.text and widget.text:GetText()==label then return widget end
    for _,child in ipairs(widget.children or {})do local found=FindButton(child,label);if found then return found end end
end
local function Open()
    toolbar.OpenEntityAddObjectPicker()
    local dialog=assert(dialogs[#dialogs]);local button=FindButton(dialog.body,"Segmented Bar")
    return dialog,button
end
local function ClickAdd()
    local dialog,button=Open();assert(button,"missing Segmented Bar entry")
    button:Fire("OnClick");assert(dialog.released)
end
local count=0
local function Test(name,fn)fn();count=count+1;print("PASS: "..name)end
local exported,expected
Test("real picker adds two IDs and selects each; record/tree/Inspector and disabled selection agree",function()
    local db,unit=Setup();ClickAdd();local a=unit.segmentedBars[1].id
    assert(h.selection.GetSelectedObject().objectKey==a);assert(h.BuildInspector():find(a,1,true))
    ClickAdd();local b=unit.segmentedBars[2].id;assert(a~=b)
    h.Equal(unit.segmentedBars[1].dataSource,{id="auto",scope="player"});assert(unit.segmentedBars[1].useBlizzardColor==true)
    assert(#h.Nodes()==2 and h.Nodes()[1].inspectorTarget.objectKey==a and h.Nodes()[2].inspectorTarget.objectKey==b)
    assert(h.selection.GetSelectedObject().objectKey==b and h.BuildInspector():find(b,1,true))
    assert(refreshes==2 and #errors==0)
    assert(M.SetEnabled(assert(M.CaptureContext("player")),a,false).ok)
    assert(h.selection.SelectObject({kind="segmentedBar",unit="player",objectKey=a}))
    assert(h.BuildInspector():find("Disabled",1,true) and h.Nodes()[1].enabled==false)
    assert(M.SetEnabled(assert(M.CaptureContext("player")),a,true).ok)
    exported=assert(ns.LayoutTransfer.Export("layout:existing"));expected=h.Copy(unit.segmentedBars)
    local ok,id=ns.LayoutTransfer.Import(exported);assert(ok,id)
    h.Equal(db.global.UserLayouts[id].payload.Units.player.segmentedBars,expected)
    local copied,copyId=ns.LayoutMutations.CopyLayout(id,nil,{activate=false});assert(copied,copyId)
    Activate(copyId);assert(h.selection.GetSelectedObject().unavailable)
    h.Equal(R.GetActiveRuntimeRoot().units.player.segmentedBars,expected)
    Activate("layout:existing");h.Equal(R.GetActiveRuntimeRoot().units.player.segmentedBars,expected)
end)
Test("no Segmented Bar entry on any non-player unit",function()
    Setup()
    for _,unit in ipairs({"target","targettarget","focus","focustarget","boss","pet"})do
        state.SetSingleSelection(unit);state.ClearPropertyScope()
        local dialog,button=Open();assert(not button,unit);dialog.cancelButton:Fire("OnClick")
    end
end)
Test("cancel and released/replaced picker callbacks do not mutate",function()
    local db=Setup();local before=h.Copy(db)
    local dialog,button=Open();local callback=button.events.OnClick
    dialog.cancelButton:Fire("OnClick");callback();h.Equal(db,before);assert(refreshes==0)
    dialog,button=Open();callback=button.events.OnClick
    local fresh=Open();callback();h.Equal(db,before);assert(not fresh.released)
    fresh.cancelButton:Fire("OnClick");assert(refreshes==0)
end)
Test("layout A-B-A/root replacement and stale collection reject old picker context",function()
    local db,unit=Setup();local dialog,button=Open();local callback=button.events.OnClick
    local ok,id=ns.LayoutMutations.CopyLayout("layout:existing",nil,{activate=false});assert(ok,id)
    Activate(id);Activate("layout:existing");local before=h.Copy(db)
    callback();h.Equal(db,before);assert(refreshes==0 and #errors==1)
    dialog,button=Open();assert(M.Add(assert(M.CaptureContext("player"))).ok)
    before=h.Copy(db);button:Fire("OnClick");h.Equal(db,before);assert(refreshes==0 and #errors==2)
    assert(h.selection.GetSelectedObject().kind=="unit")
end)
Test("combat failure creates neither record nor selection/refresh",function()
    local db,unit=Setup();local before=h.Copy(db);local dialog,button=Open()
    local combat=InCombatLockdown;InCombatLockdown=function()return true end
    button:Fire("OnClick");InCombatLockdown=combat
    h.Equal(db,before);assert(unit.segmentedBars==nil and refreshes==0 and #errors==1)
    assert(h.selection.GetSelectedObject().kind=="unit")
end)
Test("built-in copy workflow cancels cleanly then creates an editable copy before Add",function()
    local db=Setup();Activate("builtin:default");local source=h.Copy(R.GetActiveRuntimeRoot().payload)
    local before=h.Copy(db);ClickAdd();local c=confirmations[#confirmations]
    c.options.cancel.onClick();h.Equal(db,before);assert(refreshes==0)
    ClickAdd();c=confirmations[#confirmations];c.options.primary.onClick(c.dialog)
    local root=R.GetActiveRuntimeRoot();assert(root.layoutId:match("^layout:"))
    assert(root.record.createdFrom.id=="builtin:default" and #root.units.player.segmentedBars==1)
    assert(h.selection.GetSelectedObject().objectKey==root.units.player.segmentedBars[1].id and refreshes==1)
    Activate("builtin:default");h.Equal(R.GetActiveRuntimeRoot().payload,source)
end)
Test("layout switch during built-in confirmation does not add to another layout",function()
    local db=Setup();Activate("builtin:default");ClickAdd();local c=confirmations[#confirmations]
    Activate("layout:existing");local before=h.Copy(db)
    c.options.primary.onClick(c.dialog);h.Equal(db,before);assert(refreshes==0)
end)

-- Reload model: decoded/validated transferred records enter a fresh actual DK
-- runtime fixture, independent from the UI's ephemeral selection/context handles.
local runtime=assert(load(Read("Tests/SegmentedBarRuntime.lua")..
    "\nreturn {ns=ns,UF=UF,Setup=Setup,f=f}","@SegmentedBarAdd/Reload"))()
Test("UI-created transfer records materialize after reload through the existing runtime/canvas",function()
    local decoded=assert(ns.LayoutTransferCodec.Decode(exported))
    h.Equal(decoded.payload.Units.player.segmentedBars,expected)
    local frame=runtime.Setup();frame.config.segmentedBars=runtime.ns.LayoutService.Clone(expected)
    local api=GetRuneCooldown;local reads=0;GetRuneCooldown=function(i)reads=reads+1;return api(i)end
    runtime.UF:Refresh(frame);assert(reads==6)
    local resolve=runtime.ns.GUI.Editor.SelectionGeometryResolver.Resolve
    for _,record in ipairs(expected)do
        local holder=assert(frame._segmentedBars.byId[record.id]);assert(holder:IsVisible())
        assert(resolve(frame,{kind="segmentedBar",unit="player",objectKey=record.id}).target==holder)
        assert(holder.segments==frame.LiveValues.classPowerSnapshot.info.segments)
        assert(holder.Bars[2].Countdown:GetText()=="5.0" and not holder.Bars[2].ReadyHighlight)
    end
    GetRuneCooldown=api
end)
print("Segmented Bar Add: "..count.." groups PASS")
