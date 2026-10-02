-- lua54 Tests/TextTemplateEntityConsumers.lua
local file = assert(io.open('Tests/TextBuilderDraftSafety.lua'))
local source = file:read('*a'); file:close()
local stop = assert(source:find('local a, b = Payload("A"), Payload("B")', 1, true))
local f = assert(load(source:sub(1, stop - 1) .. '\nreturn f', '@E5/BuilderFixture'))()
local ns = f.ns
f.Load('Data/BuiltInTextTemplates.lua')
f.Load('Engine/Text/Shared/TextTemplateValidation.lua')
f.Load('Engine/Text/Shared/TextElementRoles.lua')
f.Load('Engine/Text/Shared/TextTemplateResolver.lua')
local L = ns.TextTemplateLibrary
local VM, Context = L.Entity, ns.GUI.Pages.TextBuilder.EntityContext
local function Id(n) return 'tpl:u:' .. string.rep('a',32) .. ':1-2-' .. string.rep('b',32) .. ':' .. n end
local a,b,missing = Id(1),Id(2),Id(3)
local db = {global={TextTemplates={[a]={name='Same',content='A'},[b]={name='Same',content='B'}}}}
local layouts = {}
layouts['layout:a'] = {payload={Units={player={Texts={
    x={templateId=a,stateTemplateIds={dead=b},enabled=false}, y={templateId=missing},
}}}}}
layouts['layout:b'] = {payload={Units={target={Texts={x={templateId=a}}}}}}
local function Test(name, run) run(); print('PASS: '..name) end
Test('ID view model and explicit Builder context exist', function()
    assert(VM and Context, 'E5 isolated consumer contracts missing')
end)
Test('equal labels never merge ID selections; lookup has no name fallback', function()
    local rows = assert(VM.List(db)); local found = {}
    for _, row in ipairs(rows) do found[row.value] = row end
    assert(found[a].label == 'Same' and found[b].label == 'Same' and found[a].value ~= found[b].value)
    assert(found[a].content=='A' and found[b].content=='B' and found['tpl:b:default-013'].readOnly)
    found[a].content='outside'; assert(L.GetUserTemplateRecord(a,db).content=='A')
    assert(VM.Selection(db,'Same')==nil and VM.Selection(db,missing)==nil)
end)
Test('Inspector resolves labels/missing by ID and includes disabled main/state usage', function()
    local detail = assert(VM.InspectText(layouts,db,'layout:a','player','x'))
    assert(#detail.references==2 and #detail.issues==0)
    assert(detail.references[1].templateId==a and detail.references[1].label=='Same')
    assert(detail.references[2].templateId==b and detail.references[2].label=='Same')
    assert(detail.references[1].enabled==false)
    local broken=assert(VM.InspectText(layouts,db,'layout:a','player','y'))
    assert(broken.references[1].isMissing and broken.references[1].label==nil)
    assert(broken.references[1].templateId==missing and #broken.issues==1)
    assert(#VM.Usage(layouts,db,a)==2 and #VM.Usage(layouts,db,b)==1)
end)
Test('shared context snapshots whitelist fields and use ID instead of name', function()
    local req={kind='shared-template',templateId=a,layoutId='layout:a',templateName='lie',callback=function() end}
    local ca=assert(Context.Snapshot(req,db,'layout:a'))
    req.templateId=b
    assert(ca.templateId==a and ca.templateName==nil and ca.callback==nil)
    local cb=assert(Context.Snapshot(req,db,'layout:a'))
    assert(not Context.Same(ca,cb))
    assert(Context.Same(ca,assert(Context.Snapshot({kind='shared-template',templateId=a},db))))
    assert(Context.Snapshot({kind='shared-template',templateName='Same'},db)==nil)
    assert(Context.Snapshot({kind='shared-template',templateId=missing},db)==nil)
    assert(Context.Snapshot({kind='shared-template',templateId=a,layoutId='layout:b'},db,'layout:a')==nil)
    assert(L.UpdateUserTemplateRecord(a,L.GetUserTemplateRecord(a,db),{name='Renamed',content='Changed'},db))
    assert(Context.Same(ca,assert(Context.Snapshot({kind='shared-template',templateId=a},db))))
end)
Test('existing draft snapshots reject stale tokens, A-B-A, layout and lifecycle changes', function()
    local ca=assert(Context.Snapshot({kind='shared-template',templateId=a},db))
    local cb=assert(Context.Snapshot({kind='shared-template',templateId=b},db))
    local state={draftToken={},editingLayoutId='layout:a',selectedTemplate=a,editContext=ca}
    local context={state=state}; local captured=Context.CaptureDraft(context)
    assert(Context.IsCurrentDraft(context,captured,'layout:a'))
    state.editContext=cb;state.selectedTemplate=b;state.draftToken={}
    assert(not Context.IsCurrentDraft(context,captured,'layout:a'))
    state.editContext=ca;state.selectedTemplate=a;state.draftToken={}
    assert(not Context.IsCurrentDraft(context,captured,'layout:a'))
    captured=Context.CaptureDraft(context)
    state.draftBaseline={name='save updated baseline'}
    assert(Context.IsCurrentDraft(context,captured,'layout:a'))
    assert(not Context.IsCurrentDraft(context,captured,'layout:b'))
    state.draftToken={}; state.editContext=nil; state.editingLayoutId=nil
    assert(not Context.IsCurrentDraft(context,captured,'layout:a'))
end)

Test('R1 contexts separate edit, binding and whitelisted return addresses', function()
    db.char={activeLayoutId='layout:a'}; db.global.UserLayouts=layouts
    local object=assert(Context.Snapshot({kind='object',layoutId='layout:a',unitKey='player',textKey='x'},db,'layout:a'))
    assert(object.kind=='object' and object.templateId==nil)
    assert(Context.Snapshot({kind='new-template'},db,'layout:a').kind=='new-template')
    local token={}; local request={kind='shared-template',templateId=a,layoutId='layout:a',
        bindingTarget={layoutId='layout:a',unitKey='player',textKey='x',expectedTemplateId=a,widget={}},
        returnContext={pickerMode='change',layoutId='layout:a',unitKey='player',textKey='x',originToken=token,
            callback=function() end,widget={},anchorContext={kind='text',objectKey='x',widget={}}}}
    local snapshot=assert(Context.Snapshot(request,db,'layout:a'))
    assert(snapshot.bindingTarget~=request.bindingTarget and snapshot.bindingTarget.widget==nil)
    assert(snapshot.returnContext~=request.returnContext and snapshot.returnContext.callback==nil and snapshot.returnContext.widget==nil)
    assert(snapshot.returnContext.originToken==token and snapshot.returnContext.anchorContext.widget==nil)
    request.bindingTarget.textKey='outside'; request.returnContext.anchorContext.objectKey='outside'
    assert(snapshot.bindingTarget.textKey=='x' and snapshot.returnContext.anchorContext.objectKey=='x')
    local layoutOnly=assert(Context.Snapshot({kind='shared-template',templateId=a,layoutId='layout:a'},db,'layout:a'))
    assert(layoutOnly.bindingTarget==nil and not Context.SameSession(snapshot,layoutOnly))
    assert(Context.GetBindingTarget(layoutOnly,'layout:a')==nil)
    local mutation,unit,key,source=Context.GetBindingTarget(snapshot,'layout:a')
    assert(mutation.db==db and mutation.expectedLayoutId=='layout:a')
    assert(mutation.expectedTextConfig==layouts['layout:a'].payload.Units.player.Texts.x)
    assert(unit=='player' and key=='x' and source==a)
    assert(Context.Snapshot({kind='shared-template',templateId=a,bindingTarget={layoutId='layout:a'}},db,'layout:a')==nil)
    assert(Context.Snapshot({kind='shared-template',templateId=a,bindingTarget={layoutId='layout:a',unitKey='player',textKey='x',expectedTemplateId=b}},db,'layout:a')==nil)
    assert(Context.Snapshot({kind='new-template',returnContext={originToken={widget={}}}},db,'layout:a')==nil)
end)
Test('R1 entity equality differs from edit-session equality and is rename-stable', function()
    local texts=layouts['layout:a'].payload.Units.player.Texts
    texts.z={templateId=a}
    local function Shared(key,token)
        return assert(Context.Snapshot({kind='shared-template',templateId=a,
            bindingTarget={layoutId='layout:a',unitKey='player',textKey=key,expectedTemplateId=a},
            returnContext={pickerMode='change',originToken=token}},db,'layout:a'))
    end
    local token={}; local x=Shared('x',token); local z=Shared('z',token)
    assert(Context.Same(x,z) and not Context.SameSession(x,z))
    assert(not Context.SameSession(x,Shared('x',{})))
    assert(Context.SameSession(x,Shared('x',token)))
    assert(L.UpdateUserTemplateRecord(a,L.GetUserTemplateRecord(a,db),{name='Renamed again'},db))
    assert(Context.SameSession(x,Shared('x',token)))
end)
Test('R1 twenty reopen cycles, A-B-A, binding changes and delete/recreate reject stale callbacks', function()
    local function Snapshot(kind,key)
        local request={kind=kind}
        if kind=='object' then request.layoutId='layout:a';request.unitKey='player';request.textKey=key
        elseif kind=='shared-template' then request.templateId=a;request.bindingTarget={layoutId='layout:a',unitKey='player',textKey=key,expectedTemplateId=a} end
        return assert(Context.Snapshot(request,db,'layout:a'))
    end
    local state={editingLayoutId='layout:a',draftToken={},editContext=Snapshot('object','x')}
    local window={state=state}; local stale=Context.CaptureDraft(window)
    for i=1,20 do
        state.editContext=Snapshot(i%2==0 and 'object' or 'shared-template',i%3==0 and 'z' or 'x')
        state.draftToken={}
        assert(not Context.IsCurrentDraft(window,stale,'layout:a'))
        local fresh=Context.CaptureDraft(window)
        assert(Context.IsCurrentDraft(window,fresh,'layout:a'))
        stale=fresh
    end
    for _,kind in ipairs({'object','shared-template'}) do
        state.editContext=Snapshot(kind,'x');state.draftToken={}
        local old=Context.CaptureDraft(window)
        local texts=layouts['layout:a'].payload.Units.player.Texts
        texts.x={templateId=a,stateTemplateIds={dead=b},enabled=false}
        assert(not Context.IsCurrentDraft(window,old,'layout:a'),'recreated object authorized stale callback')
        assert(Context.GetBindingTarget(state.editContext,'layout:a')==nil)
        local replacement=Snapshot(kind,'x')
        assert(not Context.SameSession(state.editContext,replacement))
        state.editContext=replacement;state.draftToken={}
        local fresh=Context.CaptureDraft(window)
        assert(Context.IsCurrentDraft(window,fresh,'layout:a'))
        texts.x.templateId=b
        assert(not Context.IsCurrentDraft(window,fresh,'layout:a'))
        texts.x.templateId=a
    end
    state.editContext=Snapshot('new-template');state.draftToken={}
    assert(Context.IsCurrentDraft(window,Context.CaptureDraft(window),'layout:a'))
end)

Test('R1 binding context feeds the canonical fork and cannot authorize a replacement object', function()
    local request={kind='shared-template',templateId=a,bindingTarget={layoutId='layout:a',unitKey='player',textKey='x',expectedTemplateId=a}}
    local snapshot=assert(Context.Snapshot(request,db,'layout:a'))
    local mutation,unit,key,source=Context.GetBindingTarget(snapshot,'layout:a')
    local expected=assert(L.GetUserTemplateRecord(source,db))
    local generator=assert(L.CreateUserTemplateIdGenerator({time=function() return 10 end,
        uptime=function() return 1 end,random=function() return 3 end}))
    local result=ns.TextTemplateMutations.Entity.ForkMainTemplate(mutation,unit,key,source,expected,'forked',generator)
    assert(result.ok,result.errorCode)
    assert(result.changed and layouts['layout:a'].payload.Units.player.Texts.x.templateId==result.templateId)
    assert(Context.GetBindingTarget(snapshot,'layout:a')==nil)
    assert(L.GetUserTemplateRecord(a,db).content==expected.content)
    assert(layouts['layout:a'].payload.Units.player.Texts.z.templateId==a)
    -- Even a previously handed-out mutation context retains the old raw identity.
    layouts['layout:a'].payload.Units.player.Texts.x={templateId=a}
    local rejected=ns.TextTemplateMutations.Entity.ForkMainTemplate(mutation,unit,key,source,expected,'stale',
        {Reserve=function() error('stale object reached reservation') end})
    assert(not rejected.ok and layouts['layout:a'].payload.Units.player.Texts.x.templateId==a)
end)
print('TextTemplateEntityConsumers: 9 groups passed')
