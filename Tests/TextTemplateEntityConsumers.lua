-- lua54 Tests/TextTemplateEntityConsumers.lua
local file = assert(io.open('Tests/TextBuilderDraftSafety.lua'))
local source = file:read('*a'); file:close()
local stop = assert(source:find('local a, b = Payload("A"), Payload("B")', 1, true))
local f = assert(load(source:sub(1, stop - 1) .. '\nreturn f', '@E5/BuilderFixture'))()
local ns = f.ns
f.Load('Data/BuiltInTextTemplates.lua')
f.Load('Engine/Text/Shared/TextTemplateValidation.lua')
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
print('TextTemplateEntityConsumers: 5 groups passed')
