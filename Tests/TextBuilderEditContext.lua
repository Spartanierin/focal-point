-- lua54 Tests/TextBuilderEditContext.lua
-- Reuse the real Block-1 native/AceGUI/module fixture, without running its scenarios.
local file=assert(io.open("Tests/TextBuilderDraftSafety.lua"));local source=file:read("*a");file:close()
local stop=assert(source:find('local a, b = Payload("A"), Payload("B")',1,true),"missing Builder fixture boundary")
local f=assert(load(source:sub(1,stop-1).."\nreturn f","@EditContext/Fixture"))()
local ns,Equal=f.ns,f.Equal
f.Load("GUI/Editor/EditorState.lua")
local builder=ns.GUI.Pages.TextBuilder
local function Payload(value)
    return {TextTemplates={Shared=value,Other="other",Unused="unused"},Units={player={Texts={
        text_1={templateName="Shared",tag="OLD SNAPSHOT",enabled=true},text_2={tag="LOCAL",templateName=""}},
        },target={Texts={}}}}
end
local a,b=Payload("A"),Payload("B")
ns.db={profile={General={}},char={activeLayoutId="layout:a"},global={UserLayouts={
    ["layout:a"]={name="A",formatVersion=1,payload=a},["layout:b"]={name="B",formatVersion=1,payload=b}}},
    GetCurrentProfile=function() return "Context fixture" end}
ns.ActiveLayoutResolver.InvalidateActiveRuntimeRoot()
ns.RebuildFramesForActiveProfile=function() end
ns.RefreshEditorSelectionVisuals=function() end
ns.RefreshEditorInteractionVisuals=function() end
ns.GUI.Helpers.OptionRefresh={Live=function() end}
ns.GUI.RequestRefreshOptions=function() builder.RefreshWindowState() end
local function NoErrors() assert(#f.env.errors==0,table.concat(f.env.errors,"\n")) end
local function Closure(fn,name,seen)
    seen=seen or {};if seen[fn] then return end;seen[fn]=true
    local children={}
    for i=1,200 do
        local key,value=debug.getupvalue(fn,i);if not key then break end
        if key==name then return value end
        if type(value)=="function" then children[#children+1]=value end
    end
    for _,child in ipairs(children) do local value=Closure(child,name,seen);if value then return value end end
end
local c
local function Open(target)
    local ok,reason=ns.GUIController.OpenTextBuilderWindow(target)
    assert(ok==true,tostring(reason));NoErrors()
    c=assert(f.Upvalue(builder.OpenWindow,"windowContext"))
    assert(c.state.editContext and c.state.editingLayoutId==c.state.editContext.layoutId)
end
local function Click(widget) assert(widget);widget:Fire("OnClick");NoErrors() end
local function Edit(widget,value) widget:SetText(value);widget:Fire("OnTextChanged",value);NoErrors() end
local function Dialog(name) return assert(Closure(builder.HideWindow,name) or Closure(builder.OpenWindow,name)) end
local function Select(name)
    c.templateSelect:Fire("OnValueChanged",table.concat({"profile","Context fixture","Context fixture","",name},"\031"));NoErrors()
end
local function Close()
    local token=c.state.draftToken
    builder.HideWindow()
    if builder.HasUnsavedChanges() then Click(Dialog("unsavedCloseDialogContext").discardCloseButton) end
    assert(not c.window.frame:IsShown() and c.state.editContext==nil and c.state.editingLayoutId==nil)
    assert(c.state.draftToken~=token);NoErrors()
end
local objectA={kind="object",layoutId="layout:a",unitKey="player",textKey="text_1"}
local objectB={kind="object",layoutId="layout:a",unitKey="player",textKey="text_2"}
local shared={kind="shared-template",layoutId="layout:a",templateName="Shared"}
local new={kind="new-template",layoutId="layout:a"}
-- Argumentless entry remains a normal template tool, including read-only built-ins.
Open();Equal(c.state.editContext,new);Close()
local before=ns.LayoutService.Clone(ns.db)
local external=ns.LayoutService.Clone(objectA);external.callback=function() error("must not retain") end
Open(external)
Equal(c.state.editContext,objectA);assert(c.state.editContext~=external)
external.textKey="text_2";external.layoutId="layout:b"
Equal(c.state.editContext,objectA)
Equal(c.templateEdit:GetText(),"");Equal(c.state.selectedTemplate,"") -- no OBJECT draft loading
Equal(ns.db,before)
-- Validation must leave an existing draft/lifecycle exactly intact.
local invalid={
    {{kind="object",unitKey="player",textKey="text_1"},"invalid_context"},
    {{kind="object",layoutId="layout:b",unitKey="player",textKey="text_1"},"layout_mismatch"},
    {{kind="object",layoutId="layout:a",unitKey="unknown",textKey="text_1"},"unit_not_found"},
    {{kind="object",layoutId="layout:a",unitKey="player",textKey="missing"},"text_element_not_found"},
    {{kind="object",layoutId="layout:a",unitKey="player",textKey="Health"},"text_element_not_found"}, -- only in projected defaults
    {{kind="shared-template",layoutId="layout:a",templateName="Missing"},"template_not_found"},
    {{kind="shared-template",layoutId="layout:a",templateName=""},"invalid_context"},
    {{kind="unknown",layoutId="layout:a"},"invalid_context"},
    {false,"invalid_context"},
}
for _,case in ipairs(invalid) do
    local target,token,baseline=c.state.editContext,c.state.draftToken,c.state.draftBaseline
    local draft=c.templateEdit:GetText();local snapshot=ns.LayoutService.Clone(ns.db)
    local ok,reason=ns.GUIController.OpenTextBuilderWindow(case[1])
    assert(ok==false and reason==case[2],tostring(reason))
    assert(c.state.editContext==target and c.state.draftToken==token and c.state.draftBaseline==baseline)
    Equal(c.templateEdit:GetText(),draft);Equal(ns.db,snapshot);NoErrors()
end
for _,target in ipairs({objectA,objectB,shared,new}) do
    Open(target)
    local owned,token,baseline=c.state.editContext,c.state.draftToken,c.state.draftBaseline
    local usage=ns.LayoutService.Clone(c.state.applyUnits)
    Open(ns.LayoutService.Clone(target));assert(c.state.editContext==owned and c.state.draftToken==token)
    assert(c.state.draftBaseline==baseline)
    Edit(c.templateEdit,"dirty content")
    Open(target);Open() -- same explicit target and argumentless picker/sidebar reopen
    assert(c.state.editContext==owned and c.state.draftToken==token and c.state.draftBaseline==baseline)
    Equal(c.templateEdit:GetText(),"dirty content");Equal(c.state.applyUnits,usage)
    local other=target.kind=="new-template" and objectA or new
    local ok,reason=ns.GUIController.OpenTextBuilderWindow(other)
    assert(ok==false and reason=="unsaved-changes")
    assert(c.state.editContext==owned and c.state.draftToken==token and c.state.draftBaseline==baseline)
    Equal(c.templateEdit:GetText(),"dirty content")
    builder.HideWindow();Click(Dialog("unsavedCloseDialogContext").cancelButton)
    assert(c.state.editContext==owned and c.state.draftToken==token and builder.HasUnsavedChanges())
    ns.GUI.Editor.State.SetSelectedUnit("target")
    ns.GUI:RequestRefreshOptions("context test")
    assert(c.state.editContext==owned and c.state.draftToken==token)
    Equal(c.templateEdit:GetText(),"dirty content")
    Close()
end
-- Clean target changes expire both dialog and tag-library callbacks.
Open(objectA)
local staleApply
ns.GUI.Pages.TagLibrary={Open=function(options) staleApply=options.onApply end,Close=function() end}
Click(c.tagLibraryButton)
local token=c.state.draftToken
Open(objectB);assert(c.state.draftToken~=token and not staleApply("[name]"))
token=c.state.draftToken;Open(shared);assert(c.state.draftToken~=token)
Equal(c.templateEdit:GetText(),"");Equal(c.state.selectedTemplate,"") -- no explicit SHARED load
Open(new)
-- Existing legacy workflows establish their own explicit target identities.
Select("Shared");Equal(c.state.editContext,shared)
Edit(c.templateEdit,"updated");Click(c.saveButton)
Equal(a.TextTemplates.Shared,"updated");Equal(c.state.editContext,shared)
Edit(c.templateNameEdit,"Renamed");Click(c.updateTemplateButton)
assert(c.state.editContext.templateName=="Renamed" and a.TextTemplates.Renamed=="updated")
Select("Unused");Click(c.deleteTemplateButton)
local deleteDialog=Dialog("deleteDialogContext")
local staleDelete=deleteDialog.deleteConfirmButton.events.OnClick
Open(objectA);staleDelete(deleteDialog.deleteConfirmButton)
assert(a.TextTemplates.Unused=="unused")
Select("Unused");Click(c.deleteTemplateButton);Click(Dialog("deleteDialogContext").deleteConfirmButton)
assert(a.TextTemplates.Unused==nil);Equal(c.state.editContext,new)
Click(c.newTemplateButton);Equal(c.state.editContext,new)
Edit(c.templateNameEdit,"Other");Edit(c.templateEdit,"created")
local failedContext,failedToken,failedBaseline=c.state.editContext,c.state.draftToken,c.state.draftBaseline
Click(c.saveButton) -- existing name: preserve the rejected draft and its ownership
assert(builder.HasUnsavedChanges() and c.state.editContext==failedContext)
assert(c.state.draftToken==failedToken and c.state.draftBaseline==failedBaseline)
Edit(c.templateNameEdit,"Created");Click(c.saveButton)
assert(a.TextTemplates.Created=="created" and c.state.editContext.kind=="shared-template")
Equal(c.state.editContext.templateName,"Created")
-- Existing central activation guard and successful-layout hook remain authoritative.
Open(objectA);Edit(c.templateEdit,"layout-guard draft")
local owned=c.state.editContext;token=c.state.draftToken
local ok,reason=ns:ActivateLayout("layout:b","test",{silent=true})
assert(not ok and reason=="unsaved-changes" and c.state.editContext==owned and c.state.draftToken==token)
Close();Open(objectA);Click(c.tagLibraryButton)
local oldApply=staleApply;token=c.state.draftToken
assert(ns:ActivateLayout("layout:b","test",{silent=true}))
assert(c.state.editContext==nil and c.state.draftToken~=token and c.state.editingLayoutId=="layout:b")
-- The visible legacy tool can still acquire a draft after layout invalidation.
-- Argumentless reopen must focus that draft without inventing/replacing a target.
Edit(c.templateEdit,"unbound legacy draft")
local unboundToken,unboundBaseline=c.state.draftToken,c.state.draftBaseline
assert(ns.GUIController.OpenTextBuilderWindow()==true)
assert(c.state.editContext==nil and c.state.draftToken==unboundToken and c.state.draftBaseline==unboundBaseline)
Equal(c.templateEdit:GetText(),"unbound legacy draft")
Close()
assert(ns:ActivateLayout("layout:a","test",{silent=true}))
Open(objectA);assert(c.state.draftToken~=token and not oldApply("[name]"))
assert(ns:ActivateLayout("builtin:default","test",{silent=true}))
Open();assert(c.state.editContext.kind=="new-template" and c.templateEdit.disabled)
Close();assert(ns:ActivateLayout("layout:a","test",{silent=true}))
for i=1,20 do
    Open(objectA);local oldContext=c.state.editContext;local oldToken=c.state.draftToken
    Open(objectB);assert(c.state.editContext~=oldContext and c.state.draftToken~=oldToken)
    assert(c.state.editContext.layoutId==c.state.editingLayoutId)
    Close();Open(objectA);assert(c.state.draftToken~=oldToken);Close()
end
local function NoPersistedContext(value)
    if type(value)~="table" then return end
    assert(value.editContext==nil and value.draftToken==nil and value.draftBaseline==nil and value.editingLayoutId==nil)
    for _,child in pairs(value) do NoPersistedContext(child) end
end
NoPersistedContext(ns.db);NoErrors()
print("PASS: explicit edit-context transport, canonical validation, copied identity, dirty/same/clean opens, legacy save/rename/delete, layout/refresh/callback safety and 20 lifecycle cycles")
