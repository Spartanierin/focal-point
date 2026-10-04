-- lua54 Tests/AuraAnchorMigration.lua
-- No external SavedVariables or live APIs. Exercise the actual shared geometry,
-- transformation, persistence, copy/projection and both transfer boundaries.
local ns={L={}}
local function Load(path) assert(loadfile(path))("FocalPoint",ns) end
for _,path in ipairs({"Data/Defaults.lua","Data/Themes.lua","Services/CompositionPresenceStorage.lua",
    "Services/LayoutService.lua","Services/UserLayoutStore.lua","Services/LayoutMigration.lua",
    "Services/LayoutMutations.lua","Engine/UnitFrame/Shared/UnitFramePreview.lua",
    "Engine/UnitFrame/Runtime/UnitFrameLayout.lua","Engine/UnitFrame/Runtime/UnitFrameInsideLayout.lua",
    "Engine/UnitFrame/Bars/UnitFrameBarLayout.lua","Engine/Text/Shared/TextTemplateLibrary.lua",
    "Data/BuiltInTextTemplates.lua","Engine/Text/Shared/TextTemplateUsage.lua",
    "Engine/Text/Shared/TextTemplateValidation.lua","Services/TextTemplateEntityMigration.lua",
    "Services/LayoutTransferCodec.lua","Services/LayoutTransfer.lua","Services/LayoutTransferVNext.lua",
    "Engine/Auras/Layout/AuraAnchor.lua","Engine/Auras/Layout/AuraBlockLayout.lua"}) do Load(path) end
local S,B,G=ns.LayoutService,ns.UnitFrameBarLayout,ns.UnitFrameLayout
local Copy=S.Clone
local function Equal(a,b,label)
    label=label or "value"
    if type(a)~="table" or type(b)~="table" then assert(a==b,label..": "..tostring(a).." ~= "..tostring(b)); return end
    for k,v in pairs(a) do Equal(v,b[k],label.."."..tostring(k)) end
    for k in pairs(b) do assert(a[k]~=nil,label..": extra "..tostring(k)) end
end
local function Aura(target,placement,enabled)
    return {present=true,enabled=enabled,placement=placement,anchorTo=placement=="INSIDE" and "Frame" or target,
        insideAnchorTo=placement=="INSIDE" and target or "PowerBar",point="TOPLEFT",relativePoint="RIGHT",
        offsetX=7,offsetY=-3,growthX="RIGHT",growthY="DOWN",iconSize=30,spacingX=2,spacingY=2,iconsPerRow=8}
end
local function Payload(unit) return {Units={target=unit}} end
local function Component(size,side,area,scale,padding)
    return {present=true,enabled=true,placement="INSIDE",insideSide=side,insideAnchorTo=area,
        size=size,scale=scale or 1,padding=padding or 2}
end
local base={width=220,height=40,powerBarPresent=true,showPowerBar=true,powerBarHeight=8}
local fixtures={}
local function Fixture(name,modify,unit)
    local c=Copy(base); if modify then modify(c) end
    fixtures[#fixtures+1]={name=name,config=c,unit=unit or "target"}
end
Fixture("no reserves")
Fixture("left",function(c)c.Portrait=Component(20,"LEFT","Frame")end)
Fixture("right golden",function(c)c.RaidTargetIcon=Component(40,"RIGHT","HealthBar")end)
Fixture("symmetric",function(c)c.LeaderIcon=Component(15,"LEFT","HealthBar");c.RoleIcon=Component(15,"RIGHT","HealthBar")end)
Fixture("lanes",function(c)
    c.Portrait=Component(10,"LEFT","Frame",1.25,0.5)
    c.RaidTargetIcon=Component(15,"RIGHT","HealthBar")
    c.LeaderIcon=Component(4,"RIGHT","HealthBar",2,0.5)
    c.RoleIcon=Component(6,"LEFT","PowerBar",0.5)
end)
Fixture("alternative player",function(c)c.alternativePowerBarPresent=true;c.showAlternativePowerBar=true;c.alternativePowerBarHeight=5 end,"player")
Fixture("alternative target no fallback",function(c)c.alternativePowerBarPresent=true;c.showAlternativePowerBar=true end)
Fixture("power disabled",function(c)c.showPowerBar=false end)
Fixture("power absent",function(c)c.powerBarPresent=false end)
Fixture("aura disabled",function(c)c.fixtureDisabled=true end)
Fixture("fractions",function(c)c.width=221.5;c.height=40.25;c.powerBarHeight=8.75;c.RaidTargetIcon=Component(13.5,"RIGHT","HealthBar",1.5,0.25)end)
Fixture("latent plus alternative",function(c)c.showPowerBar=false;c.alternativePowerBarPresent=true;c.showAlternativePowerBar=true end,"player")
local points={"TOPLEFT","TOP","TOPRIGHT","LEFT","CENTER","RIGHT","BOTTOMLEFT","BOTTOM","BOTTOMRIGHT"}
local count=0
for _,fixture in ipairs(fixtures) do
    for _,target in ipairs({"HealthBar","PowerBar"}) do
        for _,point in ipairs(points) do for _,relativePoint in ipairs(points) do
            local c=Copy(fixture.config); local enabled=not c.fixtureDisabled; c.fixtureDisabled=nil
            c.Buffs=Aura(target,"ATTACHED",enabled);c.Debuffs=Aura(target,"INSIDE",enabled)
            c.Debuffs.anchorTo=target=="PowerBar" and "HealthBar" or "PowerBar"
            for _,key in ipairs({"Buffs","Debuffs"}) do
                c[key].point=point;c[key].relativePoint=relativePoint
                if key=="Debuffs" then c[key].offsetX=-7.25;c[key].offsetY=3.5 end
            end
            local before=Copy(c); local rects=B.ComputeCanonicalRects(c,fixture.unit)
            local payload={Units={[fixture.unit]=c}}
            local ok,changed=S.CanonicalizeAuraAnchors(payload);assert(ok and changed)
            for _,key in ipairs({"Buffs","Debuffs"}) do
                local old,new=before[key],c[key]
                local ox,oy=G.GetRectAnchor(rects[target],relativePoint)
                local nx,ny=G.GetRectAnchor(rects.Frame,relativePoint)
                Equal({ox+old.offsetX,oy+old.offsetY},{nx+new.offsetX,ny+new.offsetY},fixture.name)
                local expected=Copy(old)
                expected.offsetX,expected.offsetY=new.offsetX,new.offsetY
                expected.anchorTo,expected.insideAnchorTo="Frame","Frame"
                if target=="PowerBar" and not rects.powerBarEnabled then expected.enabled=false end
                Equal(new,expected,"only allowed aura fields")
            end
            before.Buffs,before.Debuffs=c.Buffs,c.Debuffs;Equal(c,before,"other components unchanged")
            local saved=Copy(payload);ok,changed=S.CanonicalizeAuraAnchors(payload)
            assert(ok and not changed);Equal(payload,saved,"idempotent")
            count=count+1
        end end
    end
end
assert(count==162*#fixtures)

local golden=Copy(fixtures[3].config);golden.Buffs=Aura("HealthBar","ATTACHED",true)
local source=Payload(golden);local saved=Copy(source)
assert(S.CanonicalizeAuraAnchors(source))
Equal({golden.Buffs.offsetX,golden.Buffs.offsetY},{-34,1})
Equal({220+golden.Buffs.offsetX,20+golden.Buffs.offsetY},{186,21})
-- The inactive PowerBar target never disables an effective Frame/HealthBar aura.
for _,placement in ipairs({"ATTACHED","INSIDE"}) do
    local c=Copy(base);c.showPowerBar=false;c.Buffs=Aura("Frame",placement,true)
    if placement=="INSIDE" then c.Buffs.anchorTo="PowerBar" end
    c.Buffs.offsetX=nil;c.Buffs.offsetY=nil
    assert(S.CanonicalizeAuraAnchors(Payload(c)))
    assert(c.Buffs.enabled and c.Buffs.offsetX==nil and c.Buffs.offsetY==nil)
    c.Buffs=Aura("HealthBar",placement,true)
    assert(S.CanonicalizeAuraAnchors(Payload(c)));assert(c.Buffs.enabled)
end
local fallbacks=Copy(base);fallbacks.Buffs={anchorTo="HealthBar"}
assert(S.CanonicalizeAuraAnchors(Payload(fallbacks)))
Equal({fallbacks.Buffs.offsetX,fallbacks.Buffs.offsetY},{1,-1})
assert(fallbacks.Buffs.point==nil and fallbacks.Buffs.relativePoint==nil)

-- Prepare all groups before writes, including an error after another candidate.
local invalid=Copy(saved);invalid.Units.target.Debuffs={anchorTo="Other"}
local invalidBefore=Copy(invalid)
assert(not S.CanonicalizeAuraAnchors(invalid));Equal(invalid,invalidBefore)
local store={global={UserLayouts={
    ["layout:test:1"]={name="Existing 2.2.0",formatVersion=2,payload=Copy(saved)},
    ["layout:test:2"]={name="Power disabled",formatVersion=2,payload=Payload(Copy(base))},
}}}
store.global.UserLayouts["layout:test:2"].payload.Units.target.showPowerBar=false
store.global.UserLayouts["layout:test:2"].payload.Units.target.Buffs=Aura("PowerBar","INSIDE",true)
local root=store.global.UserLayouts
store.global.UserLayouts.bad={formatVersion=2,payload=invalid}
local original=Copy(store)
assert(not ns.LayoutMigration.CanonicalizeAuraAnchors(store));assert(store.global.UserLayouts==root);Equal(store,original)
store.global.UserLayouts.bad=nil
local ok,changed=ns.LayoutMigration.CanonicalizeAuraAnchors(store);assert(ok and changed)
Equal(store.global.UserLayouts["layout:test:1"].payload,source)
assert(not store.global.UserLayouts["layout:test:2"].payload.Units.target.Buffs.enabled)
root=store.global.UserLayouts;original=Copy(store)
ok,changed=ns.LayoutMigration.CanonicalizeAuraAnchors(store);assert(ok and not changed)
assert(store.global.UserLayouts==root);Equal(store,original)
-- Existing boundaries must all delegate to the same transform.
local old=Copy(saved)
Equal(S.CopyPayload(old).Units.target.Buffs,source.Units.target.Buffs)
Equal(S.ProjectUserLayout("layout:test:1",{name="Old",payload=old}).payload.Units.target.Buffs,source.Units.target.Buffs)
Equal(S.BuildPreviewUnitConfig(old,"target").Buffs,source.Units.target.Buffs)
Equal(old,saved,"copy/projection input")

local codec,nextTransfer=ns.LayoutTransferCodec,ns.LayoutTransferVNext
local function Generator()
    return assert(ns.TextTemplateLibrary.CreateUserTemplateIdGenerator({time=function()return 7 end,
        uptime=function()return 1 end,random=function()return 4 end}))
end
for _,version in ipairs({1,2}) do
    for _,fixture in ipairs({fixtures[3],fixtures[8],fixtures[9]}) do
        local c=Copy(fixture.config); c.Buffs=Aura(fixture==fixtures[3] and "HealthBar" or "PowerBar","ATTACHED",true)
        c.Texts={Local={tag="[name]",anchorTo="HealthBar"}}
        local payload=Payload(c)
        local expected=Copy(payload);assert(S.CanonicalizeAuraAnchors(expected))
        local doc={transferSchema=version,formatVersion=version,addonVersion="2.2.0",name="Old Export",payload=payload}
        if version==2 then doc.templates={} else payload.TextTemplates={} end
        local encoded=assert(codec.Encode(doc));local db={global={UserLayouts={},TextTemplates={}}}
        local before=Copy(db)
        local prepared=version==2 and nextTransfer.PrepareImport(encoded,db)
            or nextTransfer.PrepareLegacyImport(encoded,db,Generator())
        assert(prepared.ready,prepared.diagnostics[1] and prepared.diagnostics[1].errorCode)
        Equal(prepared.preparedLayout.payload,expected,"import target");Equal(db,before,"prepare read-only")
        local success,id=nextTransfer.Import(encoded,db,{generator=Generator()});assert(success,id)
        Equal(db.global.UserLayouts[id].payload,expected,"common commit")
        local exported=assert(codec.Decode(assert(nextTransfer.Export(db.global.UserLayouts[id],db))))
        Equal(exported.payload,expected,"canonical export")
        local again=nextTransfer.PrepareImport(assert(codec.Encode(exported)),db);assert(again.ready)
        Equal(again.preparedLayout.payload,expected,"reimport no delta")
    end
end
-- Export also canonicalizes a detached old record, without writing its source.
local record={name="Old raw",formatVersion=2,payload=Copy(saved)}
local output=assert(codec.Decode(assert(nextTransfer.Export(record,{global={TextTemplates={}}}))))
Equal(output.payload,source);Equal(record.payload,saved)

-- Current anchor application consumes the migrated result without target offsets.
local frame={Elements={HealthBar={},PowerBar={}}};local block={}
function block:ClearAllPoints()end
function block:SetPoint(...)self.point={...}end
ns.AuraBlockLayout.ApplyAnchor(block,frame,golden.Buffs,"Buffs")
Equal(block.point,{"TOPLEFT",frame,"RIGHT",-34,1})

-- Execute the real Inspector position-building branch (both existing UI modes),
-- rather than asserting that matching source strings happen to exist.
local function Read(path)
    local f=assert(io.open(path));local s=f:read("*a");f:close();return s
end
local inspector=Read("GUI/Editor/Inspector/InspectorController.lua")
local first=assert(inspector:find('        if not isQuick then\n            local inside = (auraConfig.placement',1,true))
local last=assert(inspector:find('    local function ResolveSelectedAuraInspectorTitle()',first,true))
for _,scoped in ipairs({true,false}) do for _,placement in ipairs({"INSIDE","ATTACHED"}) do
    local controls={}
    local c=Copy(golden.Buffs);c.placement=placement
    local env=setmetatable({L={},isScopedObject=scoped,isQuick=false,auraConfig=c,
        selectedAuraKey="Buffs",auraAnchorPointList=points,auraInsideSideList={},state={selectedUnit="target"},
        IsActiveCanvasDirectMoveOffsetControlSuppressed=function()return false end,
        RegisterActiveCanvasDirectMoveOffsetControls=function()end,
        SetAuraField=function(_,key,value)c[key]=value end}, {__index=_G})
    env.AddPropertyDropdownRow=function(_,_,options)
        controls[options.anchorKey]={value=options.value,change=options.onChanged}
    end
    env.AddDropdown=function(_,_,_,value,change,_,key)controls[key]={value=value,change=change}end
    local function Slider(_,_,_,_,_,value,change,_,key)
        controls[key]={value=value,change=change};return controls[key]
    end
    env.AddSlider=Slider;env.AddPropertyCompactSliderRow=Slider
    local render=assert(load("return function()\n"..inspector:sub(first,last-1),"@AuraInspector","t",env))()
    render()
    for _,key in ipairs({"aura_point","aura_relative_point","aura_offset_x","aura_offset_y"}) do assert(controls[key],placement..":"..key) end
    assert(not controls.aura_anchor_to and not controls.aura_inside_anchor_to)
    Equal({controls.aura_offset_x.value,controls.aura_offset_y.value},{-34,1})
    controls.aura_point.change("BOTTOMRIGHT");controls.aura_relative_point.change("CENTER")
    controls.aura_offset_x.change(11);controls.aura_offset_y.change(-5)
    Equal({c.point,c.relativePoint,c.offsetX,c.offsetY},{"BOTTOMRIGHT","CENTER",11,-5})
    assert(c.anchorTo=="Frame" and c.insideAnchorTo=="Frame")
end end

-- Actual Runtime -> Renderer -> BlockLayout with native widgets represented by
-- small doubles. Live/demo data changes cannot move the Frame-anchored group.
local function Widget()
    local w={}
    function w:ClearAllPoints()self.point=nil end
    function w:SetPoint(...)self.point={...}end
    function w:SetSize(x,y)self.width=x;self.height=y end
    function w:Show()self.shown=true end
    function w:Hide()self.shown=false end
    function w:IsShown()return self.shown end
    return w
end
local group=Widget();group.pool={Widget(),Widget()}
ns.AuraContainer={ApplyData=function(w,a)w.aura=a;w:Show()end,Clear=function(w)w:Hide()end}
ns.UnitFrameDemoEnvironment={GetAuras=function()return {{spellId=1},{spellId=2}}end}
ns.AuraScan={CollectUnitAuras=function()return true,{{spellId=3},{spellId=4}}end}
Load("Engine/Auras/Layout/AuraRenderer.lua");Load("Engine/Auras/Runtime/AuraRuntime.lua")
local runtime={_fpUnit="target",config={Buffs=Copy(golden.Buffs)},Elements={Buffs=group,HealthBar={}}}
for _,demo in ipairs({false,true,false}) do
    ns.guiTestModeEnabled=demo
    ns.AuraRuntime.RefreshAuraGroup(runtime,"target","Buffs")
    assert(group.shown and group.RuntimeState.renderedCount==2)
    assert(group.point[2]==runtime);Equal({group.point[4],group.point[5]},{-34,1})
    local metrics=ns.AuraBlockLayout.CalculateMetrics(2,runtime.config.Buffs)
    Equal({group.width,group.height},{metrics.blockWidth,metrics.blockHeight})
end
runtime.config.Buffs.enabled=false
ns.AuraRuntime.RefreshAuraGroup(runtime,"target","Buffs");assert(not group.shown)
runtime.config.Buffs.enabled=true
ns.AuraRuntime.RefreshAuraGroup(runtime,"target","Buffs");assert(group.shown and group.point[2]==runtime)

-- Reuse the existing actual AceDB/OnInitialize harness, adding geometry modules
-- and detached Legacy/complete-state fixtures. Never open real SavedVariables.
local startup=Read("Tests/TextTemplateEntityStartup.lua")
local boundary=assert(startup:find("local result=Start(LegacyDB())",1,true))
local app,appLoad,LegacyDB,Start=assert(load(startup:sub(1,boundary-1)..
    "\nreturn ns,Load,LegacyDB,Start","@AuraStartupHarness"))()
for _,path in ipairs({"Engine/UnitFrame/Shared/UnitFramePreview.lua","Engine/UnitFrame/Runtime/UnitFrameLayout.lua",
    "Engine/UnitFrame/Runtime/UnitFrameInsideLayout.lua","Engine/UnitFrame/Bars/UnitFrameBarLayout.lua"}) do appLoad(path) end
local legacy=LegacyDB()
legacy.global.UserLayouts["layout:A:001"].payload.Units.target=Copy(saved.Units.target)
assert(Start(legacy).ok and app.entityStartupReady)
Equal(app.db.global.UserLayouts["layout:A:001"].payload.Units.target.Buffs,golden.Buffs)
local backup=Copy(app.db.global.TextTemplateEntityMigrationBackup)
local refs=app.db.global.UserLayouts
local snapshot=Copy(app.db.sv)
assert(Start(app.db.sv).ok and app.entityStartupReady)
Equal(app.db.sv,snapshot);assert(app.db.global.UserLayouts==refs)
Equal(app.db.global.TextTemplateEntityMigrationBackup,backup)
-- A completed E6A store from 2.2.0 must still receive this separate aura step.
app.db.global.UserLayouts["layout:A:001"].payload.Units.target=Copy(saved.Units.target)
assert(Start(app.db.sv).ok and app.entityStartupReady)
Equal(app.db.global.UserLayouts["layout:A:001"].payload.Units.target.Buffs,golden.Buffs)
Equal(app.db.global.TextTemplateEntityMigrationBackup,backup)
-- E6A succeeds, but invalid Aura geometry still keeps runtime/GUI closed.
app.db.global.UserLayouts["layout:A:001"].payload.Units.target.Buffs.anchorTo="Unknown"
refs=app.db.global.UserLayouts;snapshot=Copy(refs)
assert(Start(app.db.sv).ok and app.entityStartupReady==false)
assert(app.db.global.UserLayouts==refs);Equal(refs,snapshot)
FocalPointDB=nil
print("PASS AuraAnchorMigration: "..#fixtures.." fixtures x 162 = "..count..
    " combinations, Buffs+Debuffs / ATTACHED+INSIDE; golden, idempotence, startup/reload/fail-closed, copy, preview, vNext/Legacy import/export, Inspector and Aura runtime/renderer")
