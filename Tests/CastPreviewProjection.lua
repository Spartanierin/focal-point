-- lua54 Tests/CastPreviewProjection.lua
-- Real Core projections, Open/Close/refresh queue, interaction mode and CastBar
-- policy/layout/runtime. Unrelated chrome, UI builders and non-cast runtime
-- work are test boundaries; native rendering remains an ingame smoke gate.
local file = assert(io.open("Tests/CastBarSelectionPreview.lua"))
local source = file:read("*a"); file:close()
local boundary = assert(source:find("local heightPolicy =", 1, true))
local f = assert(load(source:sub(1, boundary - 1) .. [[
return {ns=ns, Load=Load, MakeFrame=MakeFrame, Options=Options,
    SetLive=function(value) liveCast=value end}
]], "@CastProjection/Fixture"))()
local ns = f.ns
local function Load(path) f.Load(path, ns) end
local function Noop() end
local function Equal(actual, expected, label)
    assert(actual == expected, label .. ": " .. tostring(actual) .. " ~= " .. tostring(expected))
end
local function Native()
    local frame = {shown=true, scripts={}}
    function frame:Show() self.shown=true end
    function frame:Hide() self.shown=false end
    function frame:IsShown() return self.shown end
    function frame:SetScript(key, fn) self.scripts[key]=fn end
    for _, key in ipairs({"RegisterEvent", "HookScript", "RegisterForDrag", "SetMovable", "SetClampedToScreen"}) do
        frame[key]=Noop
    end
    return frame
end
CreateFrame = Native
local function Widget()
    local widget = {frame=Native()}
    for _, key in ipairs({"SetTitle", "SetStatusText", "SetLayout", "SetWidth", "SetHeight", "EnableResize",
        "SetCallback", "ReleaseChildren", "DoLayout"}) do widget[key]=Noop end
    return widget
end
LibStub = function() return {Create=Widget} end
local queue = {}
C_Timer = {After=function(_, fn) queue[#queue+1]=fn end}
local function Drain()
    local iterations=0
    while #queue>0 do
        iterations=iterations+1; assert(iterations<20, "unsettled UI refresh queue")
        local batch=queue; queue={}
        for _,fn in ipairs(batch) do fn() end
    end
end
InCombatLockdown = function() return false end
ns.GUI.Helpers={}
Load("Data/Constants.lua")
Load("GUI/Editor/EditorState.lua")
local selected
ns.GUI.Editor.ObjectSelection.GetSelectedObject=function()
    return selected or {kind="unit",unit=ns.GUI.Editor.State.GetPrimaryUnit()}
end
local shell, toolbar = {}, {}
ns.GUI.AppShell=shell; ns.GUI.Editor.Toolbar=toolbar
function shell.BuildRoot(addon)
    addon.guiAppSidebar,addon.guiContentHost=Widget(),Widget()
    return Widget(),addon.guiAppSidebar,addon.guiContentHost
end
function shell.ResolveShellMode() return "editor" end
function shell.UpdateGeometry(addon) addon.guiShellMode="editor" end
function shell.RenderMainContent(container, _, build) build(container) end
local sidebarVisible, inspectorVisible
function toolbar.Open() sidebarVisible=true end
function toolbar.Hide() sidebarVisible=false end
ns.GUI.Editor.Controller={ReleaseInspector=function() inspectorVisible=false end}
ns.GUIController={BuildEditorPage=function() inspectorVisible=true end}
function ns:IsEditorActive() return self.guiMainHost and self.guiMainHost.frame:IsShown() or false end
local units={}
ns.UnitFrameUtils.GetUnitDB=function(unit) return units[unit:match("^boss%d+$") and "boss" or unit] end
ns.CompositionPresence={IsPresent=function(config) return config.castBarPresent~=false end}
Load("Engine/UnitFrame/Runtime/UnitFrameRuntimeActivity.lua")
Load("Engine/UnitFrame/Bars/UnitFrameCastRuntime.lua")
Load("Engine/Core.lua")
Load("GUI/Editor/EditorInteractionMode.lua")
Load("GUI/GUIMainController.lua")
-- Replace only unrelated native chrome helpers, retaining the real frame loops,
-- cast cleanup helper and presentation cleanup helper in both projections.
local function Replace(fn, name, replacement)
    for i=1,100 do
        local key=debug.getupvalue(fn,i)
        if not key then break end
        if key==name then debug.setupvalue(fn,i,replacement); return end
    end
    error("missing projection boundary: "..name)
end
for _,name in ipairs({"EnsureEditorSelectionHooks", "EnsureMoveOverlay", "EnsureEditorContextMenuHooks",
    "UpdateRootTransformOverlay", "UpdateSelectionOverlay", "UpdateMoveOverlayVisuals",
    "UpdateTextEditorOverlay", "UpdateCanvasHoverOverlay", "HideEditorSnapLines",
    "HideTextEditorOverlay", "HideCanvasHoverOverlay"}) do Replace(ns.UpdateFrameDragState,name,Noop) end
Replace(ns.RefreshEditorSelectionVisuals,"UpdateEditorResizeHandle",Noop)
local function Find(fn,name)
    for i=1,100 do local key,value=debug.getupvalue(fn,i); if not key then break end
        if key==name then return value end end
    error("missing helper: "..name)
end
local projectCast=Find(ns.UpdateFrameDragState,"UpdateTextEditCastPreview")
local coreRefreshes, clears, layoutWrites = 0,0,0
local clearsByUnit={}
local cast=ns.UnitFrameCastBar
local clear=cast.ClearTextEditPreview
cast.ClearTextEditPreview=function(frame)
    clears=clears+1
    local unit=frame and frame._fpUnit or "missing"
    clearsByUnit[unit]=(clearsByUnit[unit] or 0)+1
    return clear(frame)
end
ns.UnitFrame={}
local function RefreshCast(frame)
    layoutWrites=layoutWrites+1
    cast.ApplyLayout(frame,f.Options(frame.config))
    if ns.guiTestModeEnabled then cast.StartPreview(frame)
    else ns.UnitFrameCastRuntime.Refresh(ns.UnitFrame,frame) end
end
function ns:RefreshUnitFrame(unit)
    coreRefreshes=coreRefreshes+1
    RefreshCast(assert(self.frames[unit]))
end
ns.frames={}
ns.framesUnlocked=false
local function Make(unit,enabled)
    local config={showCastBar=enabled,showCastBarIcon=true,castBarPresent=true}
    units[unit:match("^boss%d+$") and "boss" or unit]=config
    local frame=f.MakeFrame(config); frame._fpUnit=unit; frame.scripts={}
    local native=Native()
    for _,key in ipairs({"SetScript","RegisterForDrag","SetMovable","SetClampedToScreen"}) do frame[key]=native[key] end
    ns.frames[unit]=frame
    return frame
end
local enabledUnits={"player","target","targettarget","focus","focustarget"}
for _,unit in ipairs(enabledUnits) do Make(unit,true) end
Make("pet",false)
for i=1,5 do Make("boss"..i,false) end
local function AssertPreview(frame)
    local bar=frame.Elements.CastBar
    assert(bar.shown and bar.isTextEditPreview and bar.isPreview, frame._fpUnit..": preview lost")
    Equal(bar.value,1.25,"static preview progress")
    Equal(bar.statusTexture,"configured-texture","cast texture")
    Equal(bar.bg.texture,"configured-texture","background texture")
    assert(bar.icon.shown and bar.icon.texture==136048,"preview icon lost")
end
local function Project(label,fn)
    local beforeRefresh,beforeLayout,beforeClear=coreRefreshes,layoutWrites,clears
    local beforeActiveClear={}
    for _,unit in ipairs(enabledUnits) do beforeActiveClear[unit]=clearsByUnit[unit] or 0 end
    fn()
    Equal(coreRefreshes,beforeRefresh,label..": redundant full refresh")
    Equal(layoutWrites,beforeLayout,label..": redundant layout write")
    -- Disabled frames may be checked for cleanup; active previews must stay intact.
    for _,unit in ipairs(enabledUnits) do
        Equal(clearsByUnit[unit] or 0,beforeActiveClear[unit],label..": active preview cleared for "..unit)
        AssertPreview(ns.frames[unit])
    end
    return clears-beforeClear
end
local function Open()
    local before=coreRefreshes
    ns:OpenConfig()
    local afterRuntime=coreRefreshes
    assert(afterRuntime>before,"unlock must retain its runtime refresh")
    Project("deferred selection",Drain)
    Project("drag projection",function() ns:UpdateAllFrameDragStates() end)
    Project("synchronous selection",function() ns:RefreshEditorSelectionVisuals() end)
    Project("repeated selection",function() ns:RefreshEditorSelectionVisuals() end)
    assert(sidebarVisible and inspectorVisible and ns.framesUnlocked)
    for _,unit in ipairs({"pet","boss1","boss2","boss3","boss4","boss5"}) do
        assert(not ns.frames[unit].Elements.CastBar.shown,unit..": phantom cast")
    end
end
local function Close()
    selected=nil
    ns:CloseConfig(); Drain()
    assert(not ns.framesUnlocked and not ns:IsEditorActive())
    for _,frame in pairs(ns.frames) do
        assert(not frame.Elements.CastBar.isTextEditPreview and not frame.Elements.CastBar.shown,
            "editor exit did not clean up static preview")
    end
end
Open()
local host=ns.guiMainHost
Close()
for i=1,50 do Open(); assert(ns.guiMainHost==host,"host rebuilt"); Close() end
Open()
-- Explicit regression sequence: full runtime establishes preview, all following
-- projection phases preserve it without a full refresh. No fixed global count.
ns:RefreshAllFrames()
Project("post-runtime drag",function() ns:UpdateAllFrameDragStates() end)
Project("post-runtime selection",function() ns:RefreshEditorSelectionVisuals() end)
ns.GUI:RequestRefreshOptions("CastPreviewProjection.Test")
Project("post-runtime deferred UI",Drain)
-- Selection-simulated, CastName/CastTime selection and leaving those selections.
local player=ns.frames.player
for _,ref in ipairs({{kind="bar",unit="player",objectKey="CastBar"},
    {kind="text",unit="player",textKey="CastName"}, {kind="text",unit="player",textKey="CastTime"},
    {kind="unit",unit="player"}}) do
    selected=ref
    Project("selection switch",function() ns:RefreshEditorSelectionVisuals() end)
    assert(not player._fpTextEditPresentationActive,"legacy text presentation resurrected")
end
-- Disabling/removing the component must still clear its old static preview.
selected=nil
for _,field in ipairs({"showCastBar","castBarPresent"}) do
    player.config[field]=false
    local before=coreRefreshes
    projectCast(player)
    Equal(coreRefreshes,before+1,"invalidated preview cleanup")
    assert(not player.Elements.CastBar.shown,"disabled/absent preview remained visible")
    projectCast(player)
    Equal(coreRefreshes,before+1,"cleanup repeated after preview was gone")
    player.config[field]=true; RefreshCast(player); AssertPreview(player)
end
-- Live cast after a static preview: projection must preserve live icon/timing.
f.SetLive(true)
ns.UnitFrameCastRuntime.Refresh(ns.UnitFrame,player)
local live=player.Elements.CastBar
local liveValue,liveStart,liveEnd=live.value,live.startTime,live.endTime
local before=coreRefreshes
projectCast(player)
Equal(coreRefreshes,before,"live cast projection refresh")
assert(live.shown and live.isCasting and not live.isPreview and live.icon.texture==98765)
Equal(live.value,liveValue,"live progress"); Equal(live.startTime,liveStart,"live start"); Equal(live.endTime,liveEnd,"live end")
f.SetLive(false)
-- Clean transition into detailed demo retains its existing cleanup/reapply path.
ns.guiTestModeEnabled=true
projectCast(player)
local detailed=player.Elements.CastBar
assert(detailed.shown and detailed.isPreview and not detailed.isTextEditPreview)
local value,token=detailed.value,detailed.castToken
before=coreRefreshes; projectCast(player)
Equal(coreRefreshes,before,"detailed preview projection refresh")
Equal(detailed.value,value,"detailed progress"); Equal(detailed.castToken,token,"detailed token")
ns.guiTestModeEnabled=false; RefreshCast(player); AssertPreview(player)
-- Icon setting and absent native CastBar remain supported.
player.config.showCastBarIcon=false; RefreshCast(player)
before=coreRefreshes; projectCast(player); Equal(coreRefreshes,before,"icon-off projection refresh")
assert(not player.Elements.CastBar.icon.shown)
projectCast({_fpUnit="player",config=player.config,Elements={}})
Close()
print("PASS CastPreviewProjection: real Core drag/selection/queue, five enabled + pet/boss, 50 reopen cycles, cleanup, live/detailed, texture/icon and text-selection contracts")
