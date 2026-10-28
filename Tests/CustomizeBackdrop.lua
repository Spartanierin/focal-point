-- Existing real Workspace/Window lifecycle; native draw ordering remains an ingame gate.
local function Read(path)local f=assert(io.open(path));local s=f:read("*a");f:close();return s end
local source=Read("Tests/CustomizeWorkspace.lua")
local stop=assert(source:find("\nlocal count = 0",1,true))
local h,ns,state,controller,selection,Setup,Build,Drain=assert(load(source:sub(1,stop)..
    "\nreturn h,ns,state,controller,selection,Setup,Build,Drain","@CustomizeBackdrop/Workspace"))()
-- The existing native boundary dispatches OnHide, but not OnShow; mirror that native event here.
local nativeShow=h.ui.native.Show
function h.ui.native:Show()
    local shown=self:IsShown();nativeShow(self)
    if not shown then self:Run("OnShow")end
end
local function Backdrop()
    for i=1,30 do local name,value=debug.getupvalue(controller.ReleaseInspector,i)
        if name=="customizeBackdrop"then return value end
        if not name then break end
    end
end
local count=0
local function Test(name,fn)fn();count=count+1;print("PASS: "..name)end
local window,dim,db
Test("Arrange creates no dimmer; visible Customize creates one non-interactive background-level decoration",function()
    db=Setup();state.SetPresentation("arrange")
    controller.BuildInspector(nil,{GetEditorState=state.Get});assert(not Backdrop())
    local data=h.Copy(db);window=Build();dim=assert(Backdrop())
    assert(dim:IsShown() and dim:GetParent()==UIParent)
    assert(dim.lastSetAllPoints[1]==UIParent and dim.lastSetFrameStrata[1]=="BACKGROUND" and dim:GetFrameLevel()==0)
    assert(dim.lastEnableMouse[1]==false and dim.lastEnableMouseWheel[1]==false and dim.lastEnableKeyboard[1]==false)
    assert(not dim:GetScript("OnUpdate") and not dim:GetScript("OnMouseDown"))
    local regions={dim:GetRegions()};assert(#regions==1)
    local fill=regions[1];h.Equal(fill.lastSetColorTexture,{0,0,0,.28})
    local layer,sub=fill:GetDrawLayer();assert(layer=="BACKGROUND" and sub==-8)
    h.Equal(db,data)
end)
Test("host hide/show, Arrange and Close all remove dimming without a parallel mode",function()
    window.frame:Hide();assert(not dim:IsShown())
    assert(state.Get().presentation=="customize")
    window.frame:Show();assert(dim:IsShown())
    controller.SetPresentation("arrange");Drain();assert(not dim:IsShown())
    window.frame:Show();assert(not dim:IsShown(),"stale Window show must not enable the backdrop")
    assert(Build()==window);assert(dim:IsShown())
    window.closebutton:GetScript("OnClick")(window.closebutton);Drain();assert(not dim:IsShown() and state.IsArrange())
    assert(Build()==window);assert(dim:IsShown())
end)
Test("background level-zero UnitFrames suppress the decoration; no protected frame setters are used",function()
    local frames=ns.frames;local strata,level="MEDIUM",1
    local unitFrame={
        GetFrameStrata=function()return strata end,GetFrameLevel=function()return level end,
        SetFrameStrata=function()error("protected strata mutation")end,
        SetFrameLevel=function()error("protected level mutation")end,
        SetParent=function()error("protected reparent")end,
        SetAlpha=function()error("protected alpha mutation")end,
    }
    ns.frames={player=unitFrame}
    controller.UpdateActiveInspectorGeometry();assert(dim:IsShown())
    strata,level="BACKGROUND",0;controller.UpdateActiveInspectorGeometry();assert(not dim:IsShown())
    level=1;controller.UpdateActiveInspectorGeometry();assert(dim:IsShown())
    strata,level="MEDIUM",0;controller.UpdateActiveInspectorGeometry();assert(dim:IsShown())
    ns.frames=frames
end)
Test("30 mode/reopen cycles and regular selection rebuild reuse one dimmer without saved-data changes",function()
    local data=h.Copy(db);local hostAlpha=window.frame:GetAlpha();local unit=ns.UnitFrameUtils.GetUnitDB("player")
    local units=ns.ActiveLayoutResolver.GetActiveRuntimeRoot().units
    units.target=h.Copy(unit);data=h.Copy(db)
    for _=1,30 do
        controller.SetPresentation("arrange");Drain();assert(not dim:IsShown())
        assert(Build()==window and Backdrop()==dim and dim:IsShown())
        assert(selection.SelectObject({kind="unit",unit="target"}));Drain();assert(dim:IsShown())
        assert(selection.SelectObject({kind="unit",unit="player"}));Drain();assert(dim:IsShown())
        assert(window.frame:GetAlpha()==hostAlpha)
    end
    assert(select('#',dim:GetRegions())==1);h.Equal(db,data)
end)
Test("reapply schedules no new timer and cleanup works even without an active Inspector reference",function()
    local after=C_Timer.After;local timers=0
    C_Timer.After=function(...)timers=timers+1;return after(...)end
    for _=1,20 do controller.UpdateActiveInspectorGeometry()end
    assert(timers==0 and Backdrop()==dim)
    C_Timer.After=after
    controller.ReleaseInspector();assert(not dim:IsShown())
    controller.ReleaseInspector();assert(not dim:IsShown())
    state.SetPresentation("arrange");controller.BuildInspector(nil,{GetEditorState=state.Get})
    assert(not dim:IsShown())
end)
assert(#h.ui.env.errors==0,table.concat(h.ui.env.errors,"\n"))
h.ui.native.Show=nativeShow
print("Customize Backdrop: "..count.." groups PASS")
