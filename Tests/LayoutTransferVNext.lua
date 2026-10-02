-- lua54 Tests/LayoutTransferVNext.lua
local ns={L={}};local function Load(p) assert(loadfile(p))('FocalPoint',ns) end
for _, p in ipairs({'Data/Defaults.lua','Data/Themes.lua','Services/LayoutMutations.lua',
    'Engine/Text/Shared/TextTemplateLibrary.lua','Data/BuiltInTextTemplates.lua',
    'Engine/Text/Shared/TextTemplateUsage.lua','Engine/Text/Shared/TextTemplateValidation.lua',
    'Services/TextTemplateEntityMigration.lua','Services/LayoutTransferCodec.lua',
    'Services/LayoutTransfer.lua'}) do Load(p) end
local passed=0
local function Test(name,run) run();passed=passed+1;print('PASS: '..name) end
local codec,L=ns.LayoutTransferCodec,ns.TextTemplateLibrary
local function Copy(x) return assert(codec.Decode(assert(codec.Encode(x)))) end
local function Equal(a,b) assert(assert(codec.Encode(a))==assert(codec.Encode(b)),'data changed') end
local function Count(t) local n=0;for _ in pairs(t) do n=n+1 end;return n end
local function Id(n) return 'tpl:u:'..string.rep('a',32)..':1-2-'..string.rep('b',32)..':'..n end
local A,B,Unused,Missing,Builtin=Id(1),Id(2),Id(3),Id(4),'tpl:b:default-013'
local function Generator() return assert(L.CreateUserTemplateIdGenerator({time=function() return 7 end,
    uptime=function() return 1 end,random=function() return 4 end})) end
local function Fixture()
    local db={global={TextTemplates={[A]={name='Same',content='A'},[B]={name='Same',content='B'},
        [Unused]={name='unused',content='extra'}},UserLayouts={}}}
    local layout={name='Example',formatVersion=2,payload={Units={player={Texts={
        x={templateId=A,tag='inline',stateTemplateIds={dead=B,ghost=Builtin},enabled=false,fontSize=17},
        y={templateId=B,tag='fallback'},z={tag='local'},again={templateId=A}}}}}}
    return db,layout
end
C_AddOns={GetAddOnMetadata=function(addon,key) assert(addon=='FocalPoint' and key=='Version');return 'test-canonical' end}
local Next
Test('isolated vNext module is available',function()
    Load('Services/LayoutTransferVNext.lua'); Next=assert(ns.LayoutTransferVNext)
end)
local function Export(db,layout) return assert(Next.Export(layout,db)) end
local function Prepare(text,db,options)
    local before=Copy(db); local result=Next.PrepareImport(text,db,options)
    Equal(db,before); return result
end
local function Bad(result,code)
    assert(not result.ready and result.preparedLayout==nil and result.recordsToCreate==nil
        and result.remappings==nil and result.idState==nil,'partial candidate exposed')
    if code then
        for _,d in ipairs(result.diagnostics) do if d.errorCode==code then return end end
        error('missing diagnostic: '..code)
    end
end
Test('export exact main/state/disabled graph, same-name IDs and Built-in snapshots',function()
    local db,layout=Fixture();local before=Copy(db);local old=Copy(layout)
    local doc=assert(codec.Decode(Export(db,layout)))
    assert(doc.transferSchema==2 and doc.formatVersion==2 and doc.addonVersion=='test-canonical')
    assert(Count(doc.templates)==3 and doc.templates[Unused]==nil)
    assert(doc.templates[A].name==doc.templates[B].name and doc.templates[A].content~=doc.templates[B].content)
    Equal(doc.templates[Builtin],{name='Cast Time',content='[cast:time]'})
    Equal(doc.payload,layout.payload);Equal(db,before);Equal(layout,old)
    assert(doc.payload.TextTemplates==nil and doc.TextTemplateIdState==nil)
end)
Test('missing export resource and legacy fields block without mutation',function()
    local db,layout=Fixture();layout.payload.Units.player.Texts.y.templateId=Missing
    assert(Next.Export(layout,db)==nil)
    layout.payload.Units.player.Texts.y.templateId=B;layout.payload.TextTemplates={}
    assert(Next.Export(layout,db)==nil)
end)
Test('empty target prepares original User IDs once and reuses matching Built-in',function()
    local source,layout=Fixture(); local db={global={}}
    local result=Prepare(Export(source,layout),db)
    assert(result.ready and #result.conflicts==0 and #result.diagnostics==0)
    assert(Count(result.recordsToCreate)==2 and result.recordsToCreate[Builtin]==nil)
    Equal(result.recordsToCreate[A],source.global.TextTemplates[A]);Equal(result.preparedLayout.payload,layout.payload)
    assert(next(result.remappings)==nil)
end)
Test('known identical ID reuses record; different ID with same name/content never merges',function()
    local source,layout=Fixture();local target={global={TextTemplates={[A]=Copy(source.global.TextTemplates[A]),
        [Unused]=Copy(source.global.TextTemplates[B])}}}
    local result=Prepare(Export(source,layout),target)
    assert(result.ready and result.recordsToCreate[A]==nil and result.recordsToCreate[B])
    assert(result.preparedLayout.payload.Units.player.Texts.y.templateId==B)
end)
Test('known User ID with changed name or content conflicts; never exposes partial commit',function()
    for _,field in ipairs({'name','content'}) do
        local source,layout=Fixture();local target=Copy(source);target.global.TextTemplates[A][field]='different'
        local result=Prepare(Export(source,layout),target)
        Bad(result);assert(#result.conflicts==1 and result.conflicts[1].templateId==A)
        assert(result.conflicts[1].kind=='user')
    end
end)
Test('missing and extra definitions rejected; no name or local-store fallback',function()
    local source,layout=Fixture();local doc=assert(codec.Decode(Export(source,layout)))
    doc.templates[A]=nil
    Bad(Prepare(assert(codec.Encode(doc)),source),'missing_template_entity')
    doc=assert(codec.Decode(Export(source,layout)));doc.templates[Unused]={name='extra',content='unused'}
    Bad(Prepare(assert(codec.Encode(doc)),source),'unused-resource')
end)
Test('Built-in mismatch and unknown ID conflict, approved snapshot fork affects imported FKs only',function()
    for _,id in ipairs({Builtin,'tpl:b:unknown-future'}) do
        local source,layout=Fixture();local doc=assert(codec.Decode(Export(source,layout)))
        doc.payload.Units.player.Texts.x.stateTemplateIds.ghost=id
        doc.templates[Builtin]=nil;doc.templates[id]={name='Remote Built-in',content='remote X'}
        local encoded=assert(codec.Encode(doc));local target=Copy(source)
        target.global.UserLayouts['layout:existing']=Copy(layout)
        local result=Prepare(encoded,target)
        Bad(result);assert(#result.conflicts==1 and result.conflicts[1].templateId==id and result.conflicts[1].kind=='builtin')
        local options={forks={[id]=Copy(doc.templates[id])},generator=Generator()}
        result=Prepare(encoded,target,options);assert(result.ready)
        local newId=assert(result.remappings[id]);assert(L.GetTemplateIdKind(newId)=='user')
        Equal(result.recordsToCreate[newId],doc.templates[id]);assert(result.recordsToCreate[id]==nil)
        assert(result.preparedLayout.payload.Units.player.Texts.x.stateTemplateIds.ghost==newId)
        assert(result.preparedLayout.payload.Units.player.Texts.x.templateId==A and result.idState.namespace)
        assert(L.ResolveTemplateEntity(Builtin,target).content=='[cast:time]')
        options.forks[id].content='stale approval'
        Bad(Prepare(encoded,target,options),'invalid-fork-approval')
    end
end)
Test('User conflict cannot be silently forked; extraneous approvals rejected',function()
    local source,layout=Fixture();local target=Copy(source);target.global.TextTemplates[A].content='local'
    Bad(Prepare(Export(source,layout),target,{forks={[A]=Copy(source.global.TextTemplates[A])},generator=Generator()}),
        'invalid-fork-approval')
end)
Test('malformed local state and failed ID reservation return diagnostics without writes',function()
    local source,layout=Fixture();local doc=assert(codec.Decode(Export(source,layout)))
    doc.templates[Builtin].content='remote fork'
    local text=assert(codec.Encode(doc))
    local options={forks={[Builtin]=Copy(doc.templates[Builtin])},generator=Generator()}
    Bad(Prepare(text,{global={TextTemplateIdState=false}},options),'invalid-id-state')
    options.generator=assert(L.CreateUserTemplateIdGenerator({time=function() error('clock failed') end,
        uptime=function() return 1 end,random=function() return 2 end}))
    Bad(Prepare(text,{global={}},options),'id-source-unavailable')
end)
Test('one approved Built-in fork remaps every imported occurrence and keeps snapshots detached',function()
    local source,layout=Fixture();local doc=assert(codec.Decode(Export(source,layout)))
    doc.payload.Units.player.Texts.y.templateId=Builtin
    doc.templates[Builtin].content='remote fork'
    local target=Copy(source); local options={forks={[Builtin]=Copy(doc.templates[Builtin])},generator=Generator()}
    local result=Prepare(assert(codec.Encode(doc)),target,options);assert(result.ready)
    local id=assert(result.remappings[Builtin]);assert(Count(result.remappings)==1)
    assert(result.preparedLayout.payload.Units.player.Texts.x.stateTemplateIds.ghost==id)
    assert(result.preparedLayout.payload.Units.player.Texts.y.templateId==id)
    result.recordsToCreate[id].content='outside';result.preparedLayout.payload.Units.player.Texts.x.tag='outside'
    Equal(options.forks[Builtin],doc.templates[Builtin]);Equal(target,source)
end)
Test('schema, field types, cycles and transport bounds retain existing protection',function()
    local source,layout=Fixture();local encoded=Export(source,layout)
    for _,edit in ipairs({function(d) d.transferSchema=1 end,function(d) d.formatVersion=1 end,
        function(d) d.cache={} end,function(d) d.payload.Units.player.scale=-1 end,
        function(d) d.payload.Units.player.Texts.x.stateTemplateIds.dead=false end,
        function(d) d.templates[A].extra='bad' end,function(d) d.payload.Units.player.Texts.x.templateName='' end}) do
        local doc=assert(codec.Decode(encoded));edit(doc);Bad(Prepare(assert(codec.Encode(doc)),{}))
    end
    layout.payload.loop=layout.payload;assert(Next.Export(layout,source)==nil)
    Bad(Prepare('invalid',{}),'invalid-header')
    local tooLarge=#'FocalPointLayout:'+ #tostring(codec.SchemaVersion)+1+math.ceil(codec.MaxBytes/3)*4+1
    Bad(Prepare(string.rep('x',tooLarge),{}),'too-large')
end)
Test('E3 prepared to vNext to empty target preserves IDs/FKs/records/tag and state absence',function()
    local old={global={UserLayouts={['layout:a']={name='Raw',formatVersion=1,payload={TextTemplates={
        Health='[hp:cur]',Dead='dead',Unused='unused'},Units={target={Texts={
        Health={tag='inline',templateName='Health'},state={tag='local',stateTemplates={dead='Dead',ghost=false}}}}}}}}}}
    local prepared=ns.TextTemplateEntityMigration.Prepare(old,Generator());assert(prepared.ready)
    local db={global={TextTemplates=prepared.templates}}
    local result=Prepare(Export(db,prepared.layouts['layout:a']),{global={}});assert(result.ready)
    Equal(result.preparedLayout.payload,prepared.layouts['layout:a'].payload)
    assert(Count(result.recordsToCreate)==2)
    for id,record in pairs(result.recordsToCreate) do Equal(record,prepared.templates[id]) end
    assert(result.preparedLayout.payload.Units.target.Texts.Health.stateTemplateIds==nil)
    assert(result.preparedLayout.payload.Units.target.Texts.state.stateTemplateIds.ghost==nil)
end)
Test('legacy entrypoints and codec version remain active and reject vNext explicitly',function()
    local db,layout=Fixture();local ok=ns.LayoutTransfer.Import(Export(db,layout))
    assert(ok==false and codec.SchemaVersion==1)
    local file=assert(io.open('Init.xml'));local init=file:read('*a');file:close()
    assert(not init:find('LayoutTransferVNext',1,true))
end)
print('LayoutTransferVNext: '..passed..' groups passed')
