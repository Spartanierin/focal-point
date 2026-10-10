-- D2: real Inspector widgets -> guarded mutation -> persisted source selection.
local function Read(path)local f=assert(io.open(path));local s=f:read("*a");f:close();return s end
local h=assert(load(Read("Tests/SegmentedBarSelection.lua")..
    "\nreturn {ns=ns,Setup=Setup,Add=Add,Context=Context,M=M,Copy=Copy,Equal=Equal,ui=ui,state=state,Select=Select,Nodes=Nodes,Build=BuildInspector}",
    "@SourceInspector/Fixture"))()
local ns,M,R=h.ns,h.M,h.ns.ActiveLayoutResolver
local count=0
local function Test(name,fn)fn();count=count+1;print("PASS: "..name)end
local function Scan(container)
    local c,labels={},{}
    local function Walk(w)
        local key=w.GetUserData and w:GetUserData("focalPointAnchorKey")
        if key and key:match("^segmentedBar_")then c[key:sub(14)]=w end
        if w.type=="Label"then labels[#labels+1]=w.label:GetText()end
        for _,child in ipairs(w.children or {})do Walk(child)end
    end
    Walk(container);return c,table.concat(labels,"\n")
end
local function Setup()
    local db,u=h.Setup();h.state.SetSingleSelection("player");h.state.ClearPropertyScope()
    local a,b=h.Add(),h.Add();h.Select(h.Nodes()[1]);return db,u,a,b
end
local function Pick(c,source)c.dataSource:SetValue(source);c.dataSource:Fire("OnValueChanged",source)end
local function Options(c)
    local n=0;for _ in pairs(c.dataSource.list)do n=n+1 end;assert(n==3);assert(c.dataSource.list.auto=="Automatic (Class Resource)")
    assert(c.dataSource.list.runes=="Runes (Death Knight)")
    assert(c.dataSource.list.holyPower=="Holy Power (Paladin)")
end
Test("both class-labelled sources available on DK/Paladin without gameplay reads; local rebuild only",function()
    for _,class in ipairs({"DEATHKNIGHT","PALADIN"})do
        local db,u=Setup();local other=h.Copy(u.segmentedBars[2]);local applies=0
        ns.frames={player={config=u,LiveValues={classPowerSnapshot={context={class=class}}}}}
        local adapter,refresh=ns.UnitFrameSegmentedBars,ns.RefreshUnitFrame
        ns.UnitFrameSegmentedBars={Apply=function(frame)assert(frame==ns.frames.player);applies=applies+1 end}
        ns.RefreshUnitFrame=function()error("source picker requested gameplay refresh")end
        local rune,power,max,unitClass=GetRuneCooldown,UnitPower,UnitPowerMax,UnitClass
        local function Forbidden()error("source picker queried gameplay")end
        GetRuneCooldown,UnitPower,UnitPowerMax,UnitClass=Forbidden,Forbidden,Forbidden,Forbidden
        local _,c,container=h.Build(true);Options(c);assert(c.runeTimerFont and c.dataSource:GetValue()=="runes")
        local old=c.dataSource;local callback=old.events.OnValueChanged
        Pick(c,"holyPower");c=Scan(container);Options(c)
        assert(c.dataSource:GetValue()=="holyPower" and not c.runeTimerFont and not c.runeTimerFontSize and not c.runeTimerFontStyle)
        local _,labels=Scan(container);assert(labels:find("Paladin",1,true) and labels:find("stays hidden",1,true))
        local saved=h.Copy(db);callback(old,"OnValueChanged","runes");h.Equal(db,saved)
        assert(applies==1);Pick(c,"holyPower");assert(applies==1)
        Pick(c,"runes");c=Scan(container);assert(c.runeTimerFont and c.dataSource:GetValue()=="runes" and applies==2)
        h.Equal(u.segmentedBars[2],other)
        GetRuneCooldown,UnitPower,UnitPowerMax,UnitClass=rune,power,max,unitClass
        ns.RefreshUnitFrame,ns.UnitFrameSegmentedBars=refresh,adapter;ns.frames=nil
        h.ui.ace:Release(container)
    end
end)
Test("source mutation preserves independent styles/geometry/alpha zero and edits disabled instances",function()
    local _,u,a=Setup();assert(M.SetStyle(h.Context(),a,{color={.2,.4,.6,0},runeTimerFontSize=23}).ok)
    local original=h.Copy(u.segmentedBars);local _,c,container=h.Build(true)
    c.enabled:Fire("OnValueChanged",false);assert(not c.dataSource.disabled)
    Pick(c,"holyPower");c=Scan(container);assert(not c.dataSource.disabled and c.color.disabled)
    original[1].enabled=false;original[1].dataSource={id="holyPower",scope="player"};h.Equal(u.segmentedBars,original)
    c.enabled:Fire("OnValueChanged",true);Pick(c,"runes");c=Scan(container)
    assert(c.runeTimerFontSize:GetValue()==23 and u.segmentedBars[1].color[4]==0)
    h.ui.ace:Release(container);h.Select(h.Nodes()[2]);local _,second,nextContainer=h.Build(true)
    Pick(second,"holyPower");assert(u.segmentedBars[1].dataSource.id=="runes" and u.segmentedBars[2].dataSource.id=="holyPower")
    h.ui.ace:Release(nextContainer)
end)
Test("combat, invalid value, stale selection and replaced collection reject callbacks and resync",function()
    local db,u,a,b=Setup();local _,c,container=h.Build(true);local saved=h.Copy(db)
    local combat=InCombatLockdown;InCombatLockdown=function()return true end
    Pick(c,"holyPower");h.Equal(db,saved);assert(c.dataSource:GetValue()=="runes")
    InCombatLockdown=combat;Pick(c,"chi");h.Equal(db,saved);assert(c.dataSource:GetValue()=="runes")
    assert(M.SetDataSource(h.Context(),a,{id="holyPower",scope="player"}).ok)
    saved=h.Copy(db);Pick(c,"runes");h.Equal(db,saved);assert(c.dataSource:GetValue()=="holyPower")
    h.ui.ace:Release(container);local _,fresh,nextContainer=h.Build(true)
    h.Select(h.Nodes()[2]);h.Select(h.Nodes()[1]);saved=h.Copy(db)
    Pick(fresh,"runes");h.Equal(db,saved);h.ui.ace:Release(nextContainer)
    local _,latest,last=h.Build(true);Pick(latest,"runes");assert(u.segmentedBars[1].dataSource.id=="runes")
    h.ui.ace:Release(last)
end)
local exported,expected
Test("reopen, copied layout, transfer and reload retain UI-selected sources and styles",function()
    local db,u=Setup();local _,c,container=h.Build(true);Pick(c,"holyPower");h.ui.ace:Release(container)
    local _,fresh,reopen=h.Build(true);assert(fresh.dataSource:GetValue()=="holyPower" and not fresh.runeTimerFont)
    expected=h.Copy(u.segmentedBars);exported=assert(ns.LayoutTransfer.Export("layout:existing"))
    local ok,id=ns.LayoutTransfer.Import(exported);assert(ok,id)
    h.Equal(db.global.UserLayouts[id].payload.Units.player.segmentedBars,expected)
    local copied,copyId=ns.LayoutMutations.CopyLayout(id,nil,{activate=false});assert(copied,copyId)
    local callback=fresh.dataSource.events.OnValueChanged
    db.char.activeLayoutId=copyId;R.InvalidateActiveRuntimeRoot();assert(R.EnsureActiveRuntimeRoot(db))
    local saved=h.Copy(db);callback(fresh.dataSource,"OnValueChanged","runes");h.Equal(db,saved)
    h.ui.ace:Release(reopen);h.Select(h.Nodes()[1]);local _,copy,view=h.Build(true)
    assert(copy.dataSource:GetValue()=="holyPower");h.ui.ace:Release(view)
    ns.db=h.Copy(db);R.InvalidateActiveRuntimeRoot();assert(R.EnsureActiveRuntimeRoot(ns.db))
    h.Select(h.Nodes()[1]);local _,reload,last=h.Build(true);assert(reload.dataSource:GetValue()=="holyPower")
    h.Equal(R.GetActiveRuntimeRoot().units.player.segmentedBars,expected);h.ui.ace:Release(last)
end)
Test("built-in remains immutable; its explicit editable copy accepts source selection",function()
    local db=Setup();db.char.activeLayoutId="builtin:default";R.InvalidateActiveRuntimeRoot();assert(R.EnsureActiveRuntimeRoot(db))
    local original=h.Copy(R.GetActiveRuntimeRoot().payload);assert(not M.CaptureContext("player"))
    local ok,id=ns.LayoutMutations.CopyLayout("builtin:default",nil,{activate=false});assert(ok,id)
    db.char.activeLayoutId=id;R.InvalidateActiveRuntimeRoot();assert(R.EnsureActiveRuntimeRoot(db))
    assert(M.Add(assert(M.CaptureContext("player"))).ok);h.Select(h.Nodes()[1])
    local _,c,container=h.Build(true);Pick(c,"holyPower")
    assert(R.GetActiveRuntimeRoot().units.player.segmentedBars[1].dataSource.id=="holyPower")
    h.ui.ace:Release(container);db.char.activeLayoutId="builtin:default"
    R.InvalidateActiveRuntimeRoot();assert(R.EnsureActiveRuntimeRoot(db));h.Equal(R.GetActiveRuntimeRoot().payload,original)
end)

-- UI-created transfer payload enters the actual runtime, not a mock source selector.
local r=assert(load(Read("Tests/SegmentedBarSources.lua")..
    "\nreturn {r=r,Setup=Setup,NoTiming=NoTiming}","@SourceInspector/Runtime"))()
Test("UI source selections resolve live on matching classes only after transfer/reload",function()
    local frame,_,live,restore=r.Setup();local runtime=r.r
    frame.config.segmentedBars=runtime.ns.LayoutService.Clone(expected)
    runtime.UF:Refresh(frame);local holders=frame._segmentedBars.byId
    assert(holders[expected[1].id]:IsShown() and not holders[expected[2].id]:IsShown())
    r.NoTiming(holders[expected[1].id]);r.NoTiming(holders[expected[2].id]);restore()
    frame=runtime.Setup("DEATHKNIGHT");frame.config.segmentedBars=runtime.ns.LayoutService.Clone(expected)
    runtime.UF:Refresh(frame);holders=frame._segmentedBars.byId
    assert(not holders[expected[1].id]:IsShown() and holders[expected[2].id]:IsShown())
    r.NoTiming(holders[expected[1].id]);runtime.f.Equal(frame.config.segmentedBars,expected)
end)
print("Segmented Bar Source Inspector: "..count.." groups PASS")
