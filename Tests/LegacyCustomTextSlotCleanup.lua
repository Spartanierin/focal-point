-- lua54 Tests/LegacyCustomTextSlotCleanup.lua [read-only SavedVariables path]
local ns = {}
local function Load(path) assert(loadfile(path))('FocalPoint', ns) end
for _, p in ipairs({'Data/Defaults.lua', 'Data/Themes.lua', 'Services/LayoutService.lua',
    'Services/LegacyThemeAdapter.lua', 'Services/PresetService.lua'}) do Load(p) end
Load('Engine/Text/Shared/TextTemplateLibrary.lua')
Load('Data/BuiltInTextTemplates.lua')
local Historical = dofile('Tests/Fixtures/EntityPresentationBaseline.lua')
local Copy = ns.LayoutService.Clone
local function Equal(a, b)
    if a == b then return true end
    if type(a) ~= 'table' or type(b) ~= 'table' then return false end
    for k, v in pairs(a) do if not Equal(v, b[k]) then return false end end
    for k in pairs(b) do if a[k] == nil then return false end end
    return true
end
local function Count(t) local n=0; for _ in pairs(t or {}) do n=n+1 end; return n end
local function NoAliases(a, b)
    local seen = {}
    local function Collect(t) if type(t) ~= 'table' or seen[t] then return end
        seen[t]=true; for _,v in pairs(t) do Collect(v) end end
    local function Check(t) if type(t) ~= 'table' then return end
        assert(not seen[t], 'source/result alias'); for _,v in pairs(t) do Check(v) end end
    Collect(a); Check(b)
end
local passed=0
local function Test(name, run) run(); passed=passed+1; print('PASS: '..name) end
local function Serialize(v)
    if type(v) ~= 'table' then return type(v)..':'..tostring(v) end
    local ks={}; for k in pairs(v) do ks[#ks+1]=k end
    table.sort(ks,function(a,b) return type(a)..tostring(a)<type(b)..tostring(b) end)
    local r={'{'}; for _,k in ipairs(ks) do r[#r+1]=Serialize(k)..'='..Serialize(v[k])..';' end
    r[#r+1]='}'; return table.concat(r)
end
local function Fingerprint(v)
    local s=Serialize(v); local a,b=1,0
    for i=1,#s do a=(a+s:byte(i))%65521; b=(b+a)%65521 end
    return #s..':'..a..':'..b
end
-- The historical payload predates the later CastBar width defaults.  Project
-- only those two unit-level fields out of an independent analysis copy; all
-- text, template and other layout fields remain part of the frozen contract.
local function HistoricalFingerprintProjection(layout)
    local projected=Copy(layout)
    for _,unit in pairs(projected.Units or {}) do
        unit.castBarWidthMode=nil
        unit.castBarWidth=nil
    end
    return projected
end
-- Captured before this change; covers every other payload field and template.
local golden={default='110545:27395:44286', classic='127572:61586:63094',
    minimal='111418:15423:22279', modern='111660:26567:31254'}
Test('Create defaults and all shipped presets omit Custom1-3', function()
    for _,u in pairs(ns:GetDefaultDB().profile.Units) do
        for _,k in ipairs({'Custom1','Custom2','Custom3'}) do assert(u.Texts[k]==nil, 'Create default still contains '..k) end
    end
    local before=Copy(ns.Themes)
    for id,preset in pairs(ns.PresetService.GetBuiltInPresets()) do
        for _,u in pairs(preset.layout.Units) do
            for _,k in ipairs({'Custom1','Custom2','Custom3'}) do assert(u.Texts[k]==nil, id..' contains '..k) end
        end
        -- Block 2 adds explicit removal directives; preserve the frozen Block 1 baseline.
        local historicalTheme=Copy(ns.Themes[id])
        for _,unit in pairs(historicalTheme.units) do unit.removeTexts=nil end
        local historical=ns.LegacyThemeAdapter.MaterializePreviewLayout(historicalTheme,ns:GetDefaultDB())
        local historicalPayload=Historical(ns,historical,id)
        local originalWidthMode=historicalPayload.Units.player.castBarWidthMode
        local originalWidth=historicalPayload.Units.player.castBarWidth
        local projected=HistoricalFingerprintProjection(historicalPayload)
        assert(Fingerprint(projected)==golden[id], id..' historical baseline changed')
        assert(historicalPayload.Units.player.castBarWidthMode==originalWidthMode
            and historicalPayload.Units.player.castBarWidth==originalWidth,
            id..' historical projection mutated its source')
        local probe=Copy(projected)
        local probeKey=id=='classic' and 'text_1' or 'Name'
        local probeText=probe.Units.player.Texts[probeKey]
        assert(probeText, id..' historical regression probe text missing')
        probeText.tag=(probeText.tag or '')..'|legacy-fingerprint-probe'
        assert(Fingerprint(probe)~=golden[id], id..' protected legacy text structure not detected')
    end
    assert(Equal(before,ns.Themes))
end)
Load('Data/LegacyCustomTextSlots.lua')
Load('Services/LegacyCustomTextSlotCleanup.lua')
Load('GUI/Editor/Inspector/InspectorMutations.lua')
Load('Engine/Text/Shared/TextTemplateMutations.lua')
Load('Engine/Text/Shared/TextElementRoles.lua')
Load('Engine/Text/Shared/TextTemplateResolver.lua')
Load('Engine/UnitFrame/Runtime/UnitFrameBuild.lua')
Load('Engine/Text/Shared/TextTemplateLibrary.lua')
Load('Services/TextTemplateEntityMigration.lua')
local snapshot, cleanup = ns.LegacyCustomTextSlots, ns.LegacyCustomTextSlotCleanup
local function DB()
    return {global={UserLayouts={['layout:A']={name='Example', metadata={keep=true}, payload={
        Units={player={Texts={Custom1=snapshot.Get('player','Custom1')}}}, TextTemplates={Unused='[name]'}}}}}}
end
local function Text(db) return db.global.UserLayouts['layout:A'].payload.Units.player.Texts.Custom1 end
Test('frozen snapshot is independent and reset fallback remains available', function()
    local first=snapshot.Get('player','Custom1'); first.offsetX=900
    assert(snapshot.Get('player','Custom1').offsetX==2)
    assert(snapshot.Get('unknown','Custom1')==nil and snapshot.Get('player','text_1')==nil)
    assert(ns.InspectorMutations.GetTextPositionDefault({unitKey='player'},'Custom1').offsetX==2)
    assert(ns.InspectorMutations.GetTextFontSizeDefault({unitKey='player'},'Custom1')==15)
end)
Test('exact historical pairs planned, detached and applied idempotently', function()
    local db=DB(); local texts={}
    for _,u in ipairs({'player','target','targettarget','focus','focustarget','pet','boss'}) do
        local unit={Texts={}}
        for _,k in ipairs({'Custom1','Custom2','Custom3'}) do unit.Texts[k]=snapshot.Get(u,k) end
        db.global.UserLayouts['layout:A'].payload.Units[u]=unit
    end
    local before=Copy(db); local plan=cleanup.Prepare(db)
    assert(plan.ready and #plan.removals==21 and #plan.diagnostics==0)
    assert(Equal(db,before)); NoAliases(db,plan)
    local result=cleanup.ApplyCopy(db); assert(result.ready and #result.removals==21)
    local expected=Copy(db)
    for _,u in pairs(expected.global.UserLayouts['layout:A'].payload.Units) do u.Texts={} end
    assert(Equal(result.db,expected)); assert(Equal(db,before)); NoAliases(db,result)
    local again=cleanup.ApplyCopy(result.db); assert(again.ready and #again.removals==0 and Equal(again.db,result.db))
end)
for _,case in ipairs({
    {'enabled',function(t)t.enabled=true end}, {'missing enabled',function(t)t.enabled=nil end},
    {'tag',function(t)t.tag='[name]' end}, {'main',function(t)t.templateName='Shared' end},
    {'state',function(t)t.stateTemplates={dead='Dead'} end}, {'false state',function(t)t.stateTemplates=false end},
    {'empty states',function(t)t.stateTemplates={} end}, {'role',function(t)t.role='health' end},
    {'empty role',function(t)t.role='' end}, {'font',function(t)t.fontSize=31 end},
    {'position',function(t)t.offsetX=99 end}, {'nested style',function(t)t.color[1]=0.3 end},
    {'unknown field',function(t)t.custom=true end}, {'nil versus empty',function(t)t.templateName=nil end},
}) do
    Test('KEEP '..case[1],function()
        local db=DB(); case[2](Text(db)); local before=Copy(db); local r=cleanup.ApplyCopy(db)
        assert(r.ready and #r.removals==0 and #r.kept==1); assert(Equal(r.db,before) and Equal(db,before))
    end)
end
Test('foreign reference protects exact slot',function()
    local db=DB(); db.global.UserLayouts['layout:A'].payload.Units.player.Texts.text_1={enabled=true,anchorTo='Custom1'}
    local r=cleanup.Prepare(db); assert(r.ready and #r.removals==0 and r.kept[1].reason=='referenced')
end)
Test('runtime role prevents cleanup even for an exact historical slot',function()
    local resolve=ns.TextElementRoles.Resolve
    ns.TextElementRoles.Resolve=function(k,t) if k=='Custom1' then return 'reserved' end; return resolve(k,t) end
    local r=cleanup.Prepare(DB())
    ns.TextElementRoles.Resolve=resolve
    assert(r.ready and #r.removals==0 and r.kept[1].reason=='runtime-role')
end)
Test('all other keys and unknown units preserved even with identical config',function()
    local db=DB(); local unit=db.global.UserLayouts['layout:A'].payload.Units.player
    for _,k in ipairs({'Name','Health','Power','AltPower','ClassPower','CastName','CastTime',
        'NormalAbsorb','HealingAbsorb','Class','Race','Level','Status','text_1','text_2','Custom4'}) do unit.Texts[k]=Copy(Text(db)) end
    unit.Texts.Custom1=nil
    db.global.UserLayouts['layout:A'].payload.Units.unknown={Texts={Custom1=snapshot.Get('player','Custom1')}}
    local r=cleanup.ApplyCopy(db); assert(r.ready and #r.removals==0 and Equal(r.db,db))
end)
Test('copy/projection and normalization never regenerate slots or delete custom users',function()
    local db=DB(); Text(db).tag='[custom:user]'
    local projected=ns.LayoutService.ProjectUserLayout('layout:A',db.global.UserLayouts['layout:A'],ns:GetDefaultDB())
    assert(Equal(projected.payload.Units.player.Texts.Custom1,Text(db)))
    local clean=ns.LayoutService.NormalizePayload({Units={player={Texts={}}}},ns:GetDefaultDB())
    for _,unit in pairs(clean.Units) do assert(unit.Texts.Custom1==nil and unit.Texts.Custom2==nil and unit.Texts.Custom3==nil) end
    local copy=ns.LayoutService.CopyPayload(clean); assert(Equal(clean,copy))
end)
Test('Activate-and-go and Add Object remain intact',function()
    CopyTable=function(value)
        if type(value)~='table' then return value end
        local result={}; for k,v in pairs(value) do result[k]=CopyTable(v) end; return result
    end
    local unit={showAlternativePowerBar=true,showClassPowerBar=true,Texts={}}
    ns.UnitFrameBuild.EnsurePlayerAltPowerText(unit); ns.UnitFrameBuild.EnsurePlayerClassPowerText(unit)
    assert(unit.Texts.AltPower and unit.Texts.ClassPower and Count(unit.Texts)==2)
    local db={char={activeLayoutId='layout:test'},global={UserLayouts={['layout:test']={formatVersion=2,payload={Units={player=unit}}}}}}
    local context={db=db,expectedLayoutId='layout:test'}
    local r=ns.TextTemplateMutations.CreateTextFromTemplate(context,'player','tpl:b:default-013')
    assert(r.ok and r.textKey=='text_1' and unit.Texts.text_1.templateId=='tpl:b:default-013')
end)
Test('invalid/cyclic source fails without partial copy',function()
    for _,db in ipairs({{}, {global={UserLayouts=false}}}) do local r=cleanup.ApplyCopy(db); assert(not r.ready and r.db==nil) end
    local db=DB(); db.cycle=db; local r=cleanup.ApplyCopy(db); assert(not r.ready and r.db==nil)
end)
local function Measure(db)
    local s={layouts=0,texts=0,custom=0,dynamic=0,templates=0,main=0,state=0}
    for _,l in pairs(db.global.UserLayouts) do
        s.layouts=s.layouts+1; s.templates=s.templates+Count(l.payload.TextTemplates)
        for _,u in pairs(l.payload.Units) do for k,t in pairs(u.Texts or {}) do
            s.texts=s.texts+1
            if k=='Custom1' or k=='Custom2' or k=='Custom3' then s.custom=s.custom+1 end
            if k:match('^text_%d+$') then s.dynamic=s.dynamic+1 end
            if type(t.templateName)=='string' and t.templateName~='' then s.main=s.main+1 end
            if type(t.stateTemplates)=='table' then for _,n in pairs(t.stateTemplates) do
                if type(n)=='string' and n~='' then s.state=s.state+1 end end end
        end end
    end
    return s
end
local function VerifyMigration(db)
    local before=Copy(db); local generator=assert(ns.TextTemplateLibrary.CreateUserTemplateIdGenerator({
        time=function()return 1700000000 end,uptime=function()return 1 end,random=function()return 1 end}))
    local r=ns.TextTemplateEntityMigration.Prepare(db,generator)
    assert(r.ready and #r.diagnostics==0); assert(Equal(db,before))
    local main,state,entities=0,0,0; local seen={}
    for id,l in pairs(db.global.UserLayouts) do
        for name,content in pairs(l.payload.TextTemplates) do
            local tid=r.mappings[id][name]; assert(tid and not seen[tid]); seen[tid]=true; entities=entities+1
            assert(Equal(r.templates[tid],{name=name,content=content}))
        end
        assert(r.layouts[id].payload.TextTemplates==nil)
        for u,unit in pairs(l.payload.Units) do
            assert(Count(r.layouts[id].payload.Units[u].Texts)==Count(unit.Texts))
            for k,t in pairs(unit.Texts or {}) do
            local n=r.layouts[id].payload.Units[u].Texts[k]; assert(n and n.tag==t.tag)
            assert(n.templateName==nil and n.stateTemplates==nil)
            if n.templateId then
                assert(r.templates[n.templateId] and n.templateId==r.mappings[id][t.templateName]); main=main+1
            end
            for stateKey,tid in pairs(n.stateTemplateIds or {}) do
                assert(r.templates[tid] and tid==r.mappings[id][t.stateTemplates[stateKey]]); state=state+1
            end
        end end
    end
    local expected=Measure(db); assert(entities==expected.templates and main==expected.main and state==expected.state)
    print('E3 ready=true diagnostics=0 entities='..entities..' mainFKs='..main..' stateFKs='..state)
end
Test('cleanup copy feeds unchanged E3 contract',function()
    local db=DB(); db.global.UserLayouts['layout:A'].payload.Units.player.Texts.text_1={enabled=false,templateName='Unused',stateTemplates={dead='Unused'}}
    local r=cleanup.ApplyCopy(db); assert(r.ready); VerifyMigration(r.db)
end)
if arg and arg[1] then
    local env={}; assert(loadfile(arg[1],'t',env))(); local source=assert(env.FocalPointDB); local before=Copy(source)
    local plan=cleanup.Prepare(source); assert(plan.ready and #plan.removals==63,'STOP: real candidate count differs from audit')
    local r=cleanup.ApplyCopy(source); assert(r.ready); assert(Equal(source,before)); NoAliases(source,r.db)
    local expected=Copy(source)
    for _,entry in ipairs(plan.removals) do expected.global.UserLayouts[entry.layoutId].payload.Units[entry.unitKey].Texts[entry.textKey]=nil end
    assert(Equal(expected,r.db),'STOP: unrelated data changed')
    for id,stats in pairs(plan.stats.byLayout) do print('PLAN '..id..' '..source.global.UserLayouts[id].name..' removals='..stats.removals..' custom='..stats.custom) end
    for k,n in pairs(plan.stats.byKey) do print('REMOVE '..k..'='..n) end
    for _,entry in ipairs(plan.kept) do print('KEEP '..entry.layoutId..' '..entry.unitKey..' '..entry.textKey..' '..entry.reason) end
    local a,b=Measure(source),Measure(r.db)
    print('BEFORE '..Serialize(a)); print('AFTER '..Serialize(b))
    assert(a.templates==b.templates and a.main==b.main and a.state==b.state and a.dynamic==b.dynamic)
    assert(b.custom==0 and b.texts==a.texts-#plan.removals)
    VerifyMigration(r.db)
    print('REAL PASS: source unchanged; copy detached; all unplanned data deep-equal')
end
print('LegacyCustomTextSlotCleanup: '..passed..' groups passed')
