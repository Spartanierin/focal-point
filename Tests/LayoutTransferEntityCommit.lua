-- E6B: public transfer routing and common atomic publication, detached fixtures.
local file=assert(io.open("Tests/LayoutTransferVNext.lua"));local source=file:read("*a");file:close()
local stop=assert(source:find("local Next",1,true))
local ns,Load,Fixture,Generator,Copy,Equal,Id=assert(load(source:sub(1,stop-1).."\nreturn ns,Load,Fixture,Generator,Copy,Equal,Id"))()
for _,path in ipairs({"Services/CompositionPresenceStorage.lua","Services/LayoutService.lua","Services/UserLayoutStore.lua",
    "Services/LegacyThemeAdapter.lua","Services/PresetService.lua","Services/ActiveLayoutResolver.lua",
    "Services/LayoutTransferVNext.lua"})do Load(path)end
local codec,Next=ns.LayoutTransferCodec,ns.LayoutTransferVNext
local sourceDB,layout=Fixture()
local encoded=assert(Next.Export(layout,sourceDB))
local function Target()
    local db={global={UserLayouts={['layout:existing']={name='Existing',formatVersion=2,payload={Units={player={Texts={localText={tag='keep'}}}}}}},TextTemplates={}}}
    db.sv={global=db.global};ns.db=db;return db
end
for failure=1,3 do
    local db=Target();local before=Copy(db);local g=db.global
    local layouts,templates,state=g.UserLayouts,g.TextTemplates,g.TextTemplateIdState
    local ok,reason=ns.LayoutTransfer.Import(encoded,{testCommitFailureAt=failure})
    assert(not ok and reason=='store-write-failed',tostring(reason))
    Equal(db,before);assert(db.global==g and g.UserLayouts==layouts and g.TextTemplates==templates and g.TextTemplateIdState==state)
end
local db=Target();local original=db.global.UserLayouts['layout:existing'];local text=original.payload.Units.player.Texts.localText
local ok,id,name=ns.LayoutTransfer.Import(encoded);assert(ok,id)
assert(db.global.UserLayouts['layout:existing']==original and original.payload.Units.player.Texts.localText==text)
assert(db.global.UserLayouts[id].formatVersion==2 and db.global.UserLayouts[id].payload.TextTemplates==nil)
Equal(db.global.UserLayouts[id].payload,layout.payload)
local exported=assert(ns.LayoutTransfer.Export(id));local doc=assert(codec.Decode(exported));assert(doc.transferSchema==2 and doc.formatVersion==2)
local ok2,id2,name2=ns.LayoutTransfer.Import(encoded);assert(ok2 and id2~=id and name2~=name)
-- Legacy schema enters preparation, then exactly the same rollback/commit boundary.
local legacy=assert(codec.Encode({transferSchema=1,formatVersion=1,name='Legacy',addonVersion='old',
    payload={TextTemplates={Main='[name]',Dead='dead'},Units={player={Texts={x={templateName='Main',stateTemplates={dead='Dead'},tag='local'}}}}}}))
for failure=1,3 do
    db=Target();local before=Copy(db);local root=db.global.UserLayouts
    ok,id=ns.LayoutTransfer.Import(legacy,{generator=Generator(),testCommitFailureAt=failure})
    assert(not ok and id=='store-write-failed',tostring(id));Equal(db,before);assert(db.global.UserLayouts==root)
end
db=Target();ok,id=ns.LayoutTransfer.Import(legacy,{generator=Generator()});assert(ok,id)
local imported=db.global.UserLayouts[id].payload.Units.player.Texts.x
assert(imported.templateName==nil and imported.stateTemplates==nil and imported.tag=='local')
assert(db.global.TextTemplates[imported.templateId].content=='[name]')
assert(db.global.TextTemplates[imported.stateTemplateIds.dead].content=='dead')
-- Built-in conflict is read-only until an exact resource snapshot is approved.
doc=assert(codec.Decode(encoded));local builtin='tpl:b:default-013';doc.templates[builtin].content='remote variant'
local conflicting=assert(codec.Encode(doc));db=Target();local before=Copy(db)
local _,reason,_,prepared=ns.LayoutTransfer.Import(conflicting)
assert(reason=='resource-conflict' and #prepared.conflicts==1);Equal(db,before)
ok,id=ns.LayoutTransfer.Import(conflicting,{generator=Generator(),forks={[builtin]={name='Cast Time',content='stale'}}})
assert(not ok);Equal(db,before)
ok,id=ns.LayoutTransfer.Import(conflicting,{generator=Generator(),forks={[builtin]=doc.templates[builtin]}});assert(ok,id)
local fork=db.global.UserLayouts[id].payload.Units.player.Texts.x.stateTemplateIds.ghost
assert(fork~=builtin and db.global.TextTemplates[fork].content=='remote variant')
assert(ns.TextTemplateLibrary.ResolveTemplateEntity(builtin,db).content=='[cast:time]')
-- Reentrant ID source changes the live store: preserve its change, publish nothing.
db=Target();local root=db.global.UserLayouts;local templates=db.global.TextTemplates
local real=Generator();local changed=false
local generator={Reserve=function(_,working,reserved)
    if not changed then changed=true;root['layout:existing'].name='Concurrent' end
    return real:Reserve(working,reserved)
end}
ok,reason=ns.LayoutTransfer.Import(legacy,{generator=generator})
assert(not ok and reason=='live-conflict' and db.global.UserLayouts==root and db.global.TextTemplates==templates)
assert(root['layout:existing'].name=='Concurrent' and next(templates)==nil)
for _,value in ipairs({false,true,1,'scalar',{transferSchema=2,formatVersion=1},{transferSchema=1,formatVersion=2}})do
    local before=Copy(db);local called,result,err=pcall(ns.LayoutTransfer.Import,assert(codec.Encode(value)))
    assert(called and result==false and err=='transfer-version',tostring(err));Equal(db,before)
end
print('PASS: public vNext/legacy import, all commit rollback positions, identity retention, unique names/IDs, conflict/fork approval, live recheck and explicit version routing')
