-- lua54 Tests/TextBuilderEditContext.lua
-- Reuse the real Block-1 native/AceGUI/module fixture, without running its scenarios.
local file=assert(io.open("Tests/TextBuilderDraftSafety.lua"));local source=file:read("*a");file:close()
local stop=assert(source:find('local a, b = Payload("A"), Payload("B")',1,true),"missing Builder fixture boundary")
local f=assert(load(source:sub(1,stop-1).."\nreturn f","@EditContext/Fixture"))()
local ns,Equal=f.ns,f.Equal
f.Load("GUI/Editor/EditorState.lua")
for _,path in ipairs({"Engine/Text/Shared/TextElementRoles.lua","Engine/Text/Shared/TextTemplateResolver.lua",
    "Engine/Text/Shared/TextTemplateValidation.lua","Data/BuiltInTextTemplates.lua",
    "GUI/Pages/TextBuilder/TextBuilderEntity.lua"}) do f.Load(path) end
local builder=ns.GUI.Pages.TextBuilder
local R=builder.EntityBuilder
local A="tpl:u:"..string.rep("a",32)..":1-2-"..string.rep("b",32)..":1"
local text={templateId=A,tag="OLD SNAPSHOT"}
ns.db={profile={General={}},char={activeLayoutId="layout:a"},global={TextTemplates={[A]={name="Same",content="shared"}},UserLayouts={
    ["layout:a"]={name="A",formatVersion=2,payload={Units={player={Texts={shared=text,localText={tag="LOCAL"}}}}}},
    ["layout:b"]={name="B",formatVersion=2,payload={Units={player={Texts={}}}}}}}}
ns.ActiveLayoutResolver.InvalidateActiveRuntimeRoot()
ns.RebuildFramesForActiveProfile=function()end
ns.RefreshEditorSelectionVisuals=function()end
ns.RefreshEditorInteractionVisuals=function()end
ns.GUI.Helpers.OptionRefresh={Live=function()end}
ns.GUI.RequestRefreshOptions=function()builder.RefreshWindowState()end
local c,dialog
local factory=builder.CreateEntityWindow
builder.CreateEntityWindow=function(...)c=factory(...);return c end
local factoryDialog=builder.OpenLayoutDialog
builder.OpenLayoutDialog=function(...)dialog=factoryDialog(...);return dialog end
local function NoErrors()assert(#f.env.errors==0,table.concat(f.env.errors,"\n"))end
local function Click(w)w:Fire("OnClick");NoErrors()end
local function Open(request)
    local ok,reason=ns.GUIController.OpenTextBuilderWindow(request);assert(ok,reason);NoErrors()
    local consumer=f.Upvalue(builder.RefreshWindowState,"consumerContext")
    if consumer then
        c={window=consumer.window,r2Session=consumer.r2Session,templateEdit=consumer.contentEdit,
            templateNameEdit=consumer.nameEdit,saveButton=consumer.dialog.primaryButton,
            cancelButton=consumer.dialog.cancelButton,tagLibraryButton=consumer.tagButton}
    end
    return c.r2Session
end
local function Close()builder.HideWindow();if builder.HasUnsavedChanges()then Click(dialog.discardCloseButton)end end
local function Object(key)return {entity=true,kind="object",layoutId="layout:a",unitKey="player",textKey=key}end
assert(ns.GUIController.OpenTextBuilderWindow());NoErrors()
local managerContext=f.Upvalue(ns.GUI.Editor.TextTemplateLibraryWindow.OpenManager,"managerContext")
assert(managerContext and managerContext.window.frame:IsShown())
ns.GUI.Editor.TextTemplateLibraryWindow.HideManager()
local request=Object("shared");request.callback=function()error("untrusted")end
local s=Open(request);assert(s.content=="shared" and s.context.callback==nil and s.context~=request)
request.textKey="localText";assert(s.context.textKey=="shared")
for _,invalid in ipairs({
    {Object("missing"),"text_element_not_found"},
    {{entity=true,kind="object",layoutId="layout:b",unitKey="player",textKey="shared"},"layout_mismatch"},
    {{entity=true,kind="shared-template",layoutId="layout:a",templateId="Same"},"invalid-template-id"},
    {{entity=true,kind="unknown",layoutId="layout:a"},"invalid_context"},
    {{kind="object",layoutId="layout:a",unitKey="player",textKey="shared"},"entity_path_not_selected"},
}) do
    local capture=R.Capture(s);local before=ns.LayoutService.Clone(ns.db)
    local ok,reason=ns.GUIController.OpenTextBuilderWindow(invalid[1]);assert(not ok and reason==invalid[2],tostring(reason))
    assert(c.r2Session==s and R.Valid(s,capture));Equal(ns.db,before)
end
local cap=R.Capture(s);Open(Object("shared"));assert(not R.Valid(s,cap),"new Open retained old permissions")
s=c.r2Session;c.templateEdit:SetText("dirty");c.templateEdit:Fire("OnTextChanged","dirty")
cap=R.Capture(s);local ok,reason=ns.GUIController.OpenTextBuilderWindow(Object("localText"))
assert(not ok and reason=="unsaved-changes" and R.Valid(s,cap))
ns.GUI.RequestRefreshOptions();assert(R.Valid(s,cap) and c.templateEdit:GetText()=="dirty")
Close();s=Open(Object("localText"));assert(s.content=="LOCAL")
cap=R.Capture(s);assert(ns:ActivateLayout("layout:b","test",{silent=true}))
assert(not R.Valid(s,cap) and not c.window.frame:IsShown())
assert(ns:ActivateLayout("layout:a","test",{silent=true}));Open(Object("localText"))
assert(not R.Valid(s,cap) and not R.Save(s).ok)
Close();NoErrors()
print("PASS: real Entity edit context snapshots, object/shared loading, rejection atomicity, new Open and layout invalidation")
