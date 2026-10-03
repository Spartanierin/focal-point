-- lua54 Tests/LayoutTransferLegacyEntities.lua
local ns={L={}};local function Load(path) assert(loadfile(path))('FocalPoint',ns) end
for _, path in ipairs({'Data/Defaults.lua','Data/Themes.lua','Services/LayoutService.lua',
    'Services/LegacyThemeAdapter.lua','Services/LayoutMutations.lua','Services/UserLayoutStore.lua','Engine/UnitFrame/Shared/UnitFrameUtils.lua',
    'Engine/Text/Shared/TextTemplateLibrary.lua','Data/BuiltInTextTemplates.lua',
    'Engine/Text/Shared/TextTemplateResolver.lua','Engine/Text/Shared/TextTemplateUsage.lua',
    'Engine/Text/Shared/TextTemplateValidation.lua','Services/TextTemplateEntityMigration.lua',
    'Services/LayoutTransferCodec.lua','Services/LayoutTransfer.lua','Services/LayoutTransferVNext.lua'}) do Load(path) end
local Codec,Next,L=ns.LayoutTransferCodec,ns.LayoutTransferVNext,ns.TextTemplateLibrary
local passed=0
local function Test(name,run) run();passed=passed+1;print('PASS: '..name) end
local function Copy(value) return assert(Codec.Decode(assert(Codec.Encode(value)))) end
local function Equal(a,b) assert(assert(Codec.Encode(a))==assert(Codec.Encode(b)),'data changed') end
local function Count(t) local n=0;for _ in pairs(t or {}) do n=n+1 end;return n end
local function Generator() return assert(L.CreateUserTemplateIdGenerator({time=function() return 1700000000 end,
    uptime=function() return 1 end,random=function() return 6 end})) end
local function Fixture()
    return {transferSchema=1,formatVersion=1,addonVersion='2.0.6',name='Legacy',
        payload={TextTemplates={Health='[hp:cur]'},Units={target={Texts={Health={
            templateName='Health',tag='fallback',enabled=false,role='health',anchorTo='HealthBar',
            fontSize=17,color={1,.5,0},point='CENTER',offsetX=3}}}}}}
end
local function Convert(doc,db,generator)
    db=db or {};local before,dbBefore=Copy(doc),Copy(db)
    local result=Next.ConvertLegacyDocument(doc,db,generator or Generator())
    Equal(doc,before);Equal(db,dbBefore);return result
end
local function Prepare(doc,db,generator)
    db=db or {};local before=Copy(db)
    local result=Next.PrepareLegacyImport(assert(Codec.Encode(doc)),db,generator or Generator())
    Equal(db,before);return result
end
local function Bad(result,code)
    assert(not result.ready and result.document==nil and result.mappings==nil and result.importLibraryRecords==nil
        and result.preparedLayout==nil and result.recordsToCreate==nil and result.remappings==nil and result.idState==nil,
        'partial candidate exposed')
    if code then
        for _,issue in ipairs(result.diagnostics) do if issue.errorCode==code then return issue end end
        error('missing diagnostic '..code)
    end
end
Test('explicit Legacy conversion and preparation contracts exist',function()
    assert(Next.ConvertLegacyDocument and Next.PrepareLegacyImport,'E5b contracts missing')
end)
Test('minimal legacy main becomes a fresh User FK and exact dependency',function()
    local source=Fixture();local result=Convert(source);assert(result.ready)
    local id=assert(result.mappings.Health);assert(L.GetTemplateIdKind(id)=='user')
    assert(result.document.transferSchema==2 and result.document.formatVersion==2)
    assert(result.document.addonVersion==source.addonVersion and result.document.name==source.name)
    Equal(result.document.templates[id],{name='Health',content='[hp:cur]'})
    local text=result.document.payload.Units.target.Texts.Health
    assert(text.templateId==id and text.templateName==nil and text.stateTemplates==nil)
    local restored=Copy(text);restored.templateId=nil;restored.templateName='Health'
    Equal(restored,source.payload.Units.target.Texts.Health)
    assert(result.document.payload.TextTemplates==nil and result.importLibraryRecords==nil)
end)
Test('object-local empty or absent main keeps tag without creating a FK',function()
    for _,empty in ipairs({true,false}) do
        local source=Fixture();local text=source.payload.Units.target.Texts.Health
        text.templateName=empty and '' or nil
        local result=Convert(source);assert(result.ready)
        text=result.document.payload.Units.target.Texts.Health
        assert(text.templateId==nil and text.tag=='fallback' and Count(result.document.templates)==0)
        assert(result.importLibraryRecords==nil and Count(result.mappings)==0)
    end
end)
Test('all concrete states map locally; duplicate usage creates one entity per name',function()
    local source=Fixture();source.payload.TextTemplates.Dead='[dead]'
    source.payload.Units.target.Texts.Health.stateTemplates={dead='Dead',ghost='Dead',offline='Dead',afk='Dead',dnd='Dead'}
    source.payload.Units.target.Texts.duplicate={templateName='Health'}
    local result=Convert(source);assert(result.ready and Count(result.mappings)==2 and Count(result.document.templates)==2)
    for _,id in pairs(result.document.payload.Units.target.Texts.Health.stateTemplateIds) do assert(id==result.mappings.Dead) end
    assert(result.document.payload.Units.target.Texts.duplicate.templateId==result.mappings.Health)
end)
Test('whole-map false and nil create no State FK; entry false preserves ghost-to-dead runtime fallback',function()
    for _,mode in ipairs({'nil','false','entry'}) do
        local source=Fixture();local text=source.payload.Units.target.Texts.Health
        source.payload.TextTemplates['Dead Target']='[dead]'
        if mode=='false' then text.stateTemplates=false
        elseif mode=='entry' then text.stateTemplates={dead='Dead Target',ghost=false} end
        local result=Prepare(source);assert(result.ready)
        local target=result.preparedLayout.payload.Units.target.Texts.Health
        local runtime={global={TextTemplates=result.recordsToCreate}}
        assert(target.stateTemplates==nil)
        if mode=='entry' then
            assert(target.stateTemplateIds.dead and target.stateTemplateIds.ghost==nil)
            assert(ns.TextTemplateResolver.Entity.Resolve(target,'ghost',{db=runtime})=='[dead]')
        else
            assert(target.stateTemplateIds==nil and result.mappings['Dead Target']==nil)
            assert(Count(result.recordsToCreate)==1)
        end
    end
end)
Test('missing concrete main/state block despite identical global or Built-in records',function()
    local existing='tpl:u:'..string.rep('a',32)..':1-2-'..string.rep('b',32)..':1'
    local db={global={TextTemplates={[existing]={name='Dead Target',content='[dead]'}}}}
    local source=Fixture();source.payload.Units.target.Texts.Health.templateName='Dead Target'
    Bad(Convert(source,db),'missing-main-template-reference')
    source.payload.Units.target.Texts.Health.templateName='Health'
    source.payload.Units.target.Texts.Health.stateTemplates={dead='Dead Target'}
    local issue=Bad(Convert(source,db),'missing-state-template-reference')
    assert(issue.unitKey=='target' and issue.textKey=='Health' and issue.stateKey=='dead')
end)
Test('invalid main/state types are rejected; historical false is the only boolean exception',function()
    for _,value in ipairs({true,12,'',{}, {dead=true},{dead=7},{dead=''},{dead={}},{[1]=false}}) do
        local source=Fixture();source.payload.Units.target.Texts.Health.stateTemplates=value
        if type(value)=='table' and next(value)==nil then assert(Convert(source).ready)
        else Bad(Convert(source)) end
    end
    for _,value in ipairs({false,12,{}}) do
        local source=Fixture();source.payload.Units.target.Texts.Health.templateName=value;Bad(Convert(source))
    end
end)
Test('no name/content merge; E1 excludes occupied target IDs; documents get independent IDs',function()
    local seed=Generator();local db={global={TextTemplates={}}}
    local occupied=assert(seed:Reserve(db,{}));assert(L.CreateUserTemplateRecord(occupied,{name='Health',content='[hp:cur]'},db))
    local source=Fixture();local generator=Generator()
    local a=Convert(source,db,generator);local b=Convert(source,db,generator)
    assert(a.ready and b.ready and a.mappings.Health~=occupied and a.mappings.Health~=b.mappings.Health)
    db.global.TextTemplates[occupied].content='different'
    local c=Convert(source,db,generator);assert(c.ready and c.mappings.Health~=occupied)
end)
Test('legacy name/content matching a Built-in always becomes a User entity',function()
    local source=Fixture();source.payload.TextTemplates={['Dead Target']='[dead]'}
    source.payload.Units.target.Texts.Health.templateName='Dead Target'
    local result=Convert(source);assert(result.ready)
    local id=result.mappings['Dead Target'];assert(L.GetTemplateIdKind(id)=='user' and id~='tpl:b:default-015')
end)
Test('unreferenced records never reserve IDs or enter the converted/prepared graph',function()
    local source=Fixture()
    source.payload.TextTemplates.Custom1='old 1';source.payload.TextTemplates.Custom2='old 2'
    source.payload.TextTemplates.SameContent='[hp:cur]';source.payload.TextTemplates.Unused=''
    local calls=0;local generator=Generator()
    local counted={Reserve=function(_,db,reserved) calls=calls+1;return generator:Reserve(db,reserved) end}
    local converted=Convert(source,{},counted)
    assert(converted.ready and calls==1 and Count(converted.mappings)==1 and Count(converted.document.templates)==1)
    assert(converted.mappings.Health and converted.mappings.Custom1==nil and converted.mappings.Custom2==nil)
    assert(converted.mappings.SameContent==nil and converted.mappings.Unused==nil and converted.importLibraryRecords==nil)
    calls=0
    local prepared=Prepare(source,{},counted)
    assert(prepared.ready and calls==1 and Count(prepared.recordsToCreate)==1 and Count(prepared.mappings)==1)
    assert(prepared.importLibraryRecords==nil)
    Equal(prepared.recordsToCreate[prepared.mappings.Health],{name='Health',content='[hp:cur]'})
    local direct=Next.PrepareImport(assert(Codec.Encode(converted.document)),{})
    assert(direct.ready and Count(direct.recordsToCreate)==1)
    Equal(direct.preparedLayout.payload,converted.document.payload)
end)
Test('disabled Custom1 is a dependency while unreferenced Health is not',function()
    local source=Fixture();source.payload.TextTemplates.Custom1='used'
    source.payload.Units.target.Texts.Health.templateName='Custom1'
    local result=Prepare(source);assert(result.ready and Count(result.recordsToCreate)==1)
    assert(result.mappings.Health==nil and L.GetTemplateIdKind(result.mappings.Custom1)=='user')
    local text=result.preparedLayout.payload.Units.target.Texts.Health
    assert(text.enabled==false and text.templateId==result.mappings.Custom1)
    Equal(result.recordsToCreate[result.mappings.Custom1],{name='Custom1',content='used'})
end)
Test('state-only references across units and arbitrary states include disabled objects',function()
    local source=Fixture();source.payload.TextTemplates.StateOnly='state'
    source.payload.Units.target.Texts.Health.templateName=''
    source.payload.Units.focus={Texts={x={enabled=false,stateTemplates={customState='StateOnly'}}}}
    source.payload.Units.player={Texts={y={stateTemplates={offline='StateOnly'}}}}
    local result=Prepare(source);assert(result.ready and Count(result.recordsToCreate)==1)
    assert(result.mappings.Health==nil)
    local id=assert(result.mappings.StateOnly)
    assert(result.preparedLayout.payload.Units.focus.Texts.x.stateTemplateIds.customState==id)
    assert(result.preparedLayout.payload.Units.player.Texts.y.stateTemplateIds.offline==id)
end)
Test('false/nil/tag-only layouts allocate no IDs despite existing local records',function()
    for _,mode in ipairs({'nil','whole','entry'}) do
        local source=Fixture();local text=source.payload.Units.target.Texts.Health
        text.templateName=nil;text.tag='Health' -- a matching literal is not a reference
        if mode=='whole' then text.stateTemplates=false
        elseif mode=='entry' then text.stateTemplates={dead=false,ghost=false} end
        local calls=0;local fail={Reserve=function() calls=calls+1;error('unexpected reservation') end}
        local converted=Convert(source,{},fail);assert(converted.ready and calls==0)
        assert(Count(converted.mappings)==0 and Count(converted.document.templates)==0 and converted.importLibraryRecords==nil)
        local prepared=Prepare(source,{},fail);assert(prepared.ready and calls==0 and Count(prepared.recordsToCreate)==0)
        assert(prepared.idState==nil and prepared.preparedLayout.payload.Units.target.Texts.Health.tag=='Health')
    end
end)
Test('unreferenced malformed container records are ignored without repairing referenced data',function()
    local source=Fixture();source.payload.TextTemplates.Custom1=false;source.payload.TextTemplates.Custom2={old='data'}
    local result=Prepare(source);assert(result.ready and Count(result.recordsToCreate)==1)
    source.payload.Units.target.Texts.Health.templateName='Custom1'
    Bad(Convert(source),'invalid-template-record')
end)
Test('raw absence never projects Defaults and no normalization helper is called',function()
    assert(ns:GetDefaultDB().profile.Units.target.Texts.Health.stateTemplateIds.dead)
    local normalize,copy,project=ns.LayoutService.NormalizePayload,ns.LayoutService.CopyPayload,ns.LayoutService.ProjectUserLayout
    local function Forbidden() error('projection/normalization forbidden') end
    ns.LayoutService.NormalizePayload=Forbidden;ns.LayoutService.CopyPayload=Forbidden;ns.LayoutService.ProjectUserLayout=Forbidden
    local result=Prepare(Fixture());assert(result.ready)
    local units=result.preparedLayout.payload.Units
    assert(Count(units)==1 and Count(units.target.Texts)==1 and units.target.Texts.Health.stateTemplateIds==nil)
    ns.LayoutService.NormalizePayload=normalize;ns.LayoutService.CopyPayload=copy;ns.LayoutService.ProjectUserLayout=project
end)
Test('explicit versions, payload/header shape and non-text configuration remain validated',function()
    for _,edit in ipairs({function(d) d.transferSchema=2 end,function(d) d.formatVersion=2 end,
        function(d) d.transferSchema=nil end,function(d) d.formatVersion=nil end,function(d) d.extra={} end,
        function(d) d.payload.extra={} end,function(d) d.addonVersion='' end,function(d) d.name='bad|name' end,
        function(d) d.payload.Units.target.scale=-1 end,function(d) d.payload.Units.target.Texts.Health.point='INVALID' end,
        function(d) d.payload.Units.target.Texts.Health.templateId='tpl:b:default-011' end,
        function(d) d.payload.Units.target.Texts.Health.stateTemplateIds={} end,
        function(d) d.payload.TextTemplates=nil end,function(d) d.payload.TextTemplates.Health=false end}) do
        local source=Fixture();edit(source);Bad(Convert(source))
    end
    Bad(Next.PrepareLegacyImport('invalid',{}),'invalid-header')
    local source=Fixture();source.payload.loop=source.payload
    Bad(Next.ConvertLegacyDocument(source,{},Generator()),'invalid-data')
end)
Test('conversion and preparation never alias or mutate source/target storage',function()
    local source=Fixture();source.payload.TextTemplates.Unused='Keep'
    local db={global={TextTemplates={},UserLayouts={['layout:existing']={name='Existing',payload={Units={}}}}}}
    local before=Copy(db);local original=Copy(source)
    local converted=Convert(source,db)
    converted.document.payload.Units.target.Texts.Health.tag='outside'
    assert(converted.importLibraryRecords==nil and converted.mappings.Unused==nil)
    converted.document.templates[converted.mappings.Health].content='outside'
    Equal(source,original);Equal(db,before)
    local prepared=Prepare(source,db);assert(prepared.ready)
    prepared.recordsToCreate[prepared.mappings.Health].content='outside'
    prepared.preparedLayout.payload.Units.target.Texts.Health.tag='outside'
    Equal(source,original);Equal(db,before)
end)
Test('Legacy encode/decode to shared preparation to E4 validation/resolver roundtrip',function()
    local source=Fixture();source.payload.TextTemplates.Dead='[dead]';source.payload.TextTemplates.Custom1='unused'
    source.payload.Units.target.Texts.Health.stateTemplates={dead='Dead',ghost=false}
    local result=Prepare(source);assert(result.ready and Count(result.recordsToCreate)==2 and result.mappings.Custom1==nil)
    local db={global={TextTemplates=result.recordsToCreate,UserLayouts={['layout:import']=result.preparedLayout}}}
    assert(ns.TextTemplateValidation.ValidateEntityLayouts(db.global.UserLayouts,db).valid)
    local text=result.preparedLayout.payload.Units.target.Texts.Health
    assert(ns.TextTemplateResolver.Entity.Resolve(text,nil,{db=db})=='[hp:cur]')
    assert(ns.TextTemplateResolver.Entity.Resolve(text,'ghost',{db=db})=='[dead]')
    assert(text.tag=='fallback' and text.enabled==false and text.stateTemplateIds.ghost==nil)
    local encoded=assert(Next.Export(result.preparedLayout,db));local again=Next.PrepareImport(encoded,{})
    assert(again.ready);Equal(again.preparedLayout,result.preparedLayout);Equal(again.recordsToCreate,result.recordsToCreate)
end)
Test('Default snapshot and shipped Classic text overrides preserve historical false',function()
    local defaults=ns:GetDefaultDB().profile
    local historical=dofile('Tests/Fixtures/LegacyTextBindings.lua')
    defaults.TextTemplates=historical.defaultTemplates
    for unit, config in pairs(defaults.Units) do
        for key, text in pairs(config.Texts) do
            text.templateId=nil;text.stateTemplateIds=nil
            local old=historical.defaults[unit][key] or {}
            text.templateName=old.templateName;text.stateTemplates=old.stateTemplates
        end
    end
    for _,kind in ipairs({'default','classic'}) do
        local payload={Units=Copy(defaults.Units),TextTemplates=Copy(defaults.TextTemplates)}
        if kind=='classic' then
            -- Complete Classic theme data also contains string-number color
            -- channels rejected by the pre-existing layout-transfer contract.
            -- That unrelated limitation must not be silently repaired here.
            local full=ns.LegacyThemeAdapter.MaterializePreviewLayout(ns.Themes.classic,ns:GetDefaultDB())
            Bad(Convert({transferSchema=1,formatVersion=1,addonVersion='2.0.6',name='Classic full',payload={Units=full.Units,TextTemplates=historical.defaultTemplates}}))
            -- Exercise actual shipped text overrides on valid layout frame data.
            for unitKey,themeUnit in pairs(ns.Themes.classic.units) do
                for key, old in pairs(historical.classic[unitKey] or {}) do
                    local text=payload.Units[unitKey].Texts[key] or {};payload.Units[unitKey].Texts[key]=text
                    ns.LayoutService.MergeInto(text,old)
                end
            end
            ns.LayoutService.MergeInto(payload.TextTemplates,historical.classicTemplates)
            local maps,entries=0,0
            for _,unit in pairs(payload.Units) do
                for _,text in pairs(unit.Texts or {}) do
                    if text.stateTemplates==false then maps=maps+1
                    elseif type(text.stateTemplates)=='table' then
                        for _,name in pairs(text.stateTemplates) do if name==false then entries=entries+1 end end
                    end
                end
            end
            assert(maps>0 and entries>0,'shipped false examples must actually be present')
        end
        local doc={transferSchema=1,formatVersion=1,addonVersion='2.0.6',name=kind,payload=payload}
        local result=Prepare(doc);assert(result.ready,result.diagnostics[1] and result.diagnostics[1].errorCode)
        local referenced={}
        for _,unit in pairs(payload.Units) do
            for _,text in pairs(unit.Texts or {}) do
                if type(text.templateName)=='string' and text.templateName~='' then referenced[text.templateName]=true end
                if type(text.stateTemplates)=='table' then
                    for _,name in pairs(text.stateTemplates) do if type(name)=='string' and name~='' then referenced[name]=true end end
                end
            end
        end
        assert(Count(result.recordsToCreate)==Count(referenced) and Count(result.mappings)==Count(referenced))
        for name in pairs(payload.TextTemplates) do
            assert((result.mappings[name]~=nil)==(referenced[name]==true))
        end
    end
end)
Test('historical encoded document remains accepted while legacy export is disabled',function()
    local source=Fixture();local db={global={UserLayouts={['layout:export']={
        name=source.name,formatVersion=1,payload=source.payload}}}}
    local oldDb=ns.db;ns.db=db;local before=Copy(db)
    assert(ns.LayoutTransfer.Export('layout:export')==nil)
    local encoded=assert(Codec.Encode(source))
    local result=Next.PrepareLegacyImport(encoded,{},Generator());assert(result.ready)
    Equal(db,before);ns.db=oldDb
    assert(result.preparedLayout.payload.Units.target.Texts.Health.tag=='fallback')
end)
Test('non-document input and generator failure expose diagnostics without partial candidates',function()
    for _,value in ipairs({false,true,1,'text'}) do
        Bad(Next.ConvertLegacyDocument(value,{},Generator()),'document-invalid')
        Bad(Next.PrepareLegacyImport(assert(Codec.Encode(value)),{},Generator()),'document-invalid')
    end
    local fail=assert(L.CreateUserTemplateIdGenerator({time=function() error('no clock') end,
        uptime=function() return 1 end,random=function() return 6 end}))
    Bad(Convert(Fixture(),{},fail),'id-reservation-failure')
end)
Test('versioned Legacy reader is loaded for the common Entity import path',function()
    local source=Fixture();source.payload.Units.target.Texts.Health.stateTemplates=false
    local ok,reason=ns.LayoutTransfer.Import(assert(Codec.Encode(source)))
    assert(ok==false and reason=='invalid-global')
    assert(Next.PrepareLegacyImport(assert(Codec.Encode(source)),{},Generator()).ready)
    local f=assert(io.open('Init.xml'));local init=f:read('*a');f:close()
    assert(init:find('LayoutTransferVNext',1,true) and init:find('TextTemplateEntityMigration',1,true))
end)
print('LayoutTransferLegacyEntities: '..passed..' groups passed')
