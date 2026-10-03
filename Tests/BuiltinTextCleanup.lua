-- Run from repository root: lua54 Tests/BuiltinTextCleanup.lua [--report]
local ns = {Constants={}, L={}}
LibStub = function() return {} end
local function Load(path) assert(loadfile(path))('FocalPoint', ns) end
for _, path in ipairs({
    'Data/Defaults.lua', 'Data/Themes.lua', 'Services/CompositionPresenceStorage.lua',
    'Services/LayoutService.lua', 'Services/LegacyThemeAdapter.lua', 'Services/PresetService.lua',
    'Engine/Text/Shared/TextTemplateLibrary.lua', 'Data/BuiltInTextTemplates.lua',
    'Engine/Text/Shared/TextElementRoles.lua', 'Engine/Text/Shared/TextTemplateResolver.lua', 'Engine/Text/Shared/TextTemplateMutations.lua',
    'Engine/UnitFrame/Shared/UnitFrameUtils.lua', 'GUI/Editor/SidebarShared.lua',
    'GUI/Editor/Composition/LegacyAssociationMap.lua', 'GUI/Editor/Composition/CompositionOwnership.lua',
    'GUI/Editor/Composition/CompositionPresence.lua', 'GUI/Editor/Composition/CompositionTreeAdapter.lua',
}) do Load(path) end
local fixture = assert(loadfile('Tests/Fixtures/BuiltinTextCleanup.lua'))()
local service, adapter = ns.LayoutService, ns.LegacyThemeAdapter
local Clone = service.Clone
local order = {'default','minimal','classic','modern'}
local units = {'player','target','targettarget','pet','focus','focustarget','boss'}
local approved = {default=22, minimal=26, classic=43, modern=27}
local function Equal(a,b)
    if a==b then return true end
    if type(a)~='table' or type(b)~='table' then return false end
    for k,v in pairs(a) do if not Equal(v,b[k]) then return false end end
    for k in pairs(b) do if a[k]==nil then return false end end
    return true
end
local function Sorted(t)
    local ks={}; for k in pairs(t) do ks[#ks+1]=k end
    table.sort(ks,function(a,b) return type(a)..tostring(a)<type(b)..tostring(b) end)
    return ks
end
local function Serialize(v)
    if type(v)~='table' then return type(v)..':'..tostring(v) end
    local r={'{'}; for _,k in ipairs(Sorted(v)) do r[#r+1]=Serialize(k)..'='..Serialize(v[k])..';' end
    r[#r+1]='}'; return table.concat(r)
end
local function Fingerprint(v)
    local s=Serialize(v); local a,b=1,0
    for i=1,#s do a=(a+s:byte(i))%65521; b=(b+a)%65521 end
    return #s..':'..a..':'..b
end
local function Count(layout)
    local n=0; for _,u in pairs(layout.Units) do for _ in pairs(u.Texts) do n=n+1 end end; return n
end
local function TreeLabels(layout)
    ns.UnitFrameUtils.GetUnitsDB=function() return layout.Units end
    local result={}
    for _,u in ipairs(units) do
        result[u]={}
        local function Visit(node)
            if node.type=='textElement' then result[u][node.inspectorTarget.textKey]=node.label end
            for _,child in ipairs(node.children or {}) do Visit(child) end
        end
        Visit(assert(ns.CompositionTreeAdapter.BuildUnitTree(u), 'missing unit tree: '..u))
    end
    return result
end
local passed=0
local function Test(name,run) run(); passed=passed+1; print('PASS: '..name) end
local defaults=ns:GetDefaultDB()
local defaultsBefore, themesBefore = Clone(defaults), Clone(ns.Themes)
local catalogBefore=ns.BuiltInTextTemplates.ListRecords()
local Historical = dofile("Tests/Fixtures/EntityPresentationBaseline.lua")
local baseline, expected, projected, labels, counts, active = {},{},{},{},{},{}
for _,p in ipairs(order) do
    -- Same historical theme, with only the new object-removal directives disabled.
    -- Pinned pre-change fingerprints ensure no other defaults/theme data drift.
    local originalTheme=Clone(ns.Themes[p])
    for _,u in pairs(originalTheme.units) do u.removeTexts=nil end
    baseline[p]=adapter.MaterializePreviewLayout(originalTheme, defaults)
    expected[p]=Clone(baseline[p]); counts[p]=0; active[p]=0
    projected[p]=service.ProjectPreset({metadata={id=p,source='builtin'},layout=baseline[p]},defaults).payload
    labels[p]=TreeLabels(projected[p])
end
Test('historical baseline is unchanged outside removal directives',function()
    for _,p in ipairs(order) do
        assert(Fingerprint(Historical(ns,baseline[p],p))==fixture.before[p].fingerprint, p..' baseline changed')
        assert(Count(baseline[p])==fixture.before[p].count)
    end
end)
Test('118 explicit mappings, zero missing/ambiguous/duplicate identities',function()
    local seen={}
    assert(#fixture.rows==118)
    for _,r in ipairs(fixture.rows) do
        local id=r.preset..'/'..r.unit..'/'..r.textKey
        assert(not seen[id], 'duplicate identity: '..id); seen[id]=true
        local t=assert(projected[r.preset].Units[r.unit].Texts[r.textKey], 'missing: '..id)
        local matching=0
        for _,label in pairs(labels[r.preset][r.unit]) do if label==r.label then matching=matching+1 end end
        assert(matching==1 and labels[r.preset][r.unit][r.textKey]==r.label, 'ambiguous/missing label: '..id)
        for _,field in ipairs({'enabled','templateName','tag','stateTemplates'}) do
            assert(Equal(Historical(ns,baseline[r.preset],r.preset).Units[r.unit].Texts[r.textKey][field],r[field]), id..' changed '..field)
        end
        assert(t.role==r.explicitRole and ns.TextElementRoles.Resolve(r.textKey,t)==r.role)
        assert(expected[r.preset].Units[r.unit].Texts[r.textKey]~=nil)
        expected[r.preset].Units[r.unit].Texts[r.textKey]=nil
        counts[r.preset]=counts[r.preset]+1
        if t.enabled==true then active[r.preset]=active[r.preset]+1 end
    end
    for _,p in ipairs(order) do assert(counts[p]==approved[p]) end
end)
Test('key Class, label and template name are separate identities',function()
    assert(labels.default.player.Class=='Player Level and Class')
    assert(labels.default.target.Class=='Class')
    assert(projected.classic.Units.target.Texts.Class.templateId==nil)
    assert(labels.classic.target.Race=='Target Level and Class')
    assert(labels.modern.boss.AltPower=='AltPower')
end)
for _,p in ipairs(order) do
    Test(p..': exact removals; every remaining field/template/geometry deep-equal',function()
        local preset=ns.PresetService.GetPreset(p)
        assert(Equal(preset.layout,expected[p]), p..': cleanup differs from approved objects')
        assert(Count(preset.layout)==fixture.before[p].count-approved[p])
        local byUnit={}; for _,r in ipairs(fixture.rows) do if r.preset==p then
            byUnit[r.unit]=byUnit[r.unit] or {}; byUnit[r.unit][r.textKey]=true
        end end
        for u,t in pairs(ns.Themes[p].units) do
            local seen={}
            for _,k in ipairs(t.removeTexts or {}) do
                assert(byUnit[u] and byUnit[u][k] and not seen[k], 'unapproved or repeated directive')
                seen[k]=true
            end
            assert(Equal(seen,byUnit[u] or {}), 'missing removal directive')
        end
        for _,u in pairs(preset.layout.Units) do
            assert(u.removeTexts==nil, 'theme directive leaked into layout')
            for _,k in ipairs({'Custom1','Custom2','Custom3'}) do assert(u.Texts[k]==nil) end
        end
        -- Explicit defaults must not restore absent object identities.
        local expectedProjected=Clone(projected[p])
        for _,r in ipairs(fixture.rows) do if r.preset==p then expectedProjected.Units[r.unit].Texts[r.textKey]=nil end end
        local actualProjected=service.ProjectPreset(preset,defaults).payload
        assert(Equal(actualProjected,expectedProjected), p..': projection restored objects or changed remaining fields')
        for _=1,3 do
            actualProjected=service.NormalizePayload(service.CopyPayload(actualProjected),defaults)
            assert(Equal(actualProjected,expectedProjected), p..': copy/normalize changed composition')
        end
        assert(Equal(ns.PresetService.GetPreset(p).layout,expected[p]), 'repeated build differs')
    end)
end
Test('active approved redundancies disappear; retained displays and dynamic identities survive',function()
    assert(active.classic>0)
    local after=ns.PresetService.GetPreset('classic').layout
    for _,u in ipairs({'target','targettarget','focus','focustarget'}) do
        assert(baseline.classic.Units[u].Texts.Name.enabled==true and after.Units[u].Texts.Name==nil)
        local kept=false
        for k,t in pairs(after.Units[u].Texts) do
            if t.templateId=='tpl:b:classic-004' and t.enabled==true then
                assert(Equal(t,baseline.classic.Units[u].Texts[k])); kept=true
            end
        end
        assert(kept)
    end
    assert(after.Units.player.Texts.text_4==nil) -- explicitly selected dynamic object
    assert(Equal(after.Units.player.Texts.text_1,baseline.classic.Units.player.Texts.text_1))
    assert(Equal(ns.PresetService.GetPreset('default').layout.Units.pet.Texts,baseline.default.Units.pet.Texts))
    assert(ns.PresetService.GetPreset('modern').layout.Units.target.Texts.Class.enabled==true)
end)
Test('existing user layouts retain every original object, regardless of createdFrom',function()
    local db={global={UserLayouts={},TextTemplates={keep={name='User',content='[name]'}}}}
    for _,p in ipairs(order) do
        db.global.UserLayouts[p]={name=p,createdFrom='builtin:'..p,payload=Clone(baseline[p])}
    end
    local before=Clone(db); ns.db=db
    for _,p in ipairs(order) do
        local result=service.ProjectUserLayout('layout:'..p,db.global.UserLayouts[p],defaults)
        for _,u in ipairs(units) do assert(Equal(result.payload.Units[u].Texts,projected[p].Units[u].Texts)) end
        ns.PresetService.GetPreset(p)
    end
    assert(Equal(db,before), 'user data changed')
end)
Test('materialization keeps explicit Texts membership; missing map still gets defaults',function()
    local d=defaults.profile.Units.player
    assert(next(service.MaterializeUnit(d,{Texts={}}).Texts)==nil)
    assert(Equal(service.MaterializeUnit(d,{}).Texts,d.Texts))
    local source={Texts={Health={enabled=false,tag='[custom]'},text_99={enabled=true,tag='[name]'}}}
    local before=Clone(source); local r=service.MaterializeUnit(d,source)
    assert(r.Texts.Name==nil and r.Texts.Health.tag=='[custom]' and r.Texts.Health.font==d.Texts.Health.font)
    assert(Equal(r.Texts.text_99,source.Texts.text_99) and Equal(source,before))
end)
Test('templates, built-in IDs, role support, Add Object and source inputs remain intact',function()
    assert(Equal(defaults,defaultsBefore) and Equal(ns.Themes,themesBefore))
    assert(Equal(ns.BuiltInTextTemplates.ListRecords(),catalogBefore))
    for _,p in ipairs(order) do assert(Equal(ns.PresetService.GetPreset(p).layout.TextTemplates,baseline[p].TextTemplates)) end
    for _,r in ipairs(fixture.rows) do
        assert(ns.TextElementRoles.Resolve(r.textKey,projected[r.preset].Units[r.unit].Texts[r.textKey])==r.role)
    end
    local unit=Clone(expected.classic.Units.player)
    local db={char={activeLayoutId='layout:test'},global={UserLayouts={['layout:test']={formatVersion=2,payload={Units={player=unit}}}}}}
    local context={db=db,expectedLayoutId='layout:test'}
    local result=ns.TextTemplateMutations.CreateTextFromTemplate(context,'player','tpl:b:default-013')
    assert(result.ok and result.textKey=='text_4' and unit.Texts.text_4.templateId=='tpl:b:default-013')
end)
print('BuiltinTextCleanup: '..passed..' groups passed; 118 unique decisions')
if arg and arg[1]=='--report' then
    print('\nBEFORE / REMOVED / AFTER / ACTIVE REMOVED')
    for _,p in ipairs(order) do print(p..' | '..fixture.before[p].count..' | '..approved[p]..' | '..Count(expected[p])..' | '..active[p]) end
    print('\nDROP MAPPING: preset | unit | textKey | UI label | enabled | templateName | tag | stateTemplates | explicitRole | resolvedRole')
    for _,r in ipairs(fixture.rows) do print(table.concat({r.preset,r.unit,r.textKey,r.label,tostring(r.enabled),tostring(r.templateName),tostring(r.tag),Serialize(r.stateTemplates),tostring(r.explicitRole),tostring(r.role)},' | ')) end
    print('\nREMAINING: preset | unit | textKey | UI label | enabled | templateName | tag')
    for _,p in ipairs(order) do
        local layout=service.ProjectPreset(ns.PresetService.GetPreset(p),defaults).payload
        local list=TreeLabels(layout)
        for _,u in ipairs(units) do for _,k in ipairs(Sorted(layout.Units[u].Texts)) do
            local t=layout.Units[u].Texts[k]
            print(table.concat({p,u,k,list[u][k] or '(not present in tree)',tostring(t.enabled),tostring(t.templateName),tostring(t.tag)},' | '))
        end end
    end
end
