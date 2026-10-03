-- lua54 Tests/TextBuilderDraftSafety.lua
-- Real AceGUI controls, Builder, activation, resolver/store and text mutations.
-- Only native WoW APIs/rendering and unit-frame rebuilding are simulated.
local file = assert(io.open("Tests/DialogWindowFamily.lua"))
local source = file:read("*a"); file:close()
local stop = assert(source:find("local created,latest=", 1, true))
local f = assert(load(source:sub(1, stop - 1) .. "\nreturn f", "@Builder/NativeFixture"))()
local ns, Load, Equal = f.ns, f.Load, f.Equal
function f.native:SetStatusBarColor(...) self.lastSetStatusBarColor = {...} end
function f.native:SetStatusBarTexture(...) self.lastSetStatusBarTexture = {...} end
function f.native:RegisterEvent(event) self.registeredEvents=self.registeredEvents or {}; self.registeredEvents[event]=true end
for _, path in ipairs({
    "Data/Constants.lua", "Data/Defaults.lua", "Data/Themes.lua", "Locales/enUS.lua",
    "Services/CompositionPresenceStorage.lua", "Services/LayoutService.lua", "Services/LegacyThemeAdapter.lua",
    "Services/PresetService.lua", "Services/UserLayoutStore.lua",
    "Services/ActiveLayoutResolver.lua", "Engine/UnitFrame/Shared/UnitFrameUtils.lua",
    "Engine/Text/Shared/TextElementUtils.lua", "Engine/Text/Shared/TextTemplateLibrary.lua",
    "Engine/Text/Shared/TextTemplateUsage.lua", "Engine/Text/Shared/TextTemplateMutations.lua",
    "GUI/Helpers/GUIState.lua", "GUI/Helpers/LayoutHelpers.lua", "GUI/Helpers/PageDependencyFactory.lua", "GUI/GUIController.lua",
    "GUI/Helpers/FormSectionSurfaceRenderer.lua", "GUI/Helpers/FormRenderer.lua",
    "GUI/Pages/TextBuilder/TextBuilderDefinition.lua", "GUI/Pages/TextBuilder/TextBuilderController.lua",
    "Services/LayoutAssignmentService.lua", "Engine/UnitFrame.lua",
}) do Load(path) end
local function Payload(text)
    return { TextTemplates = {Shared=text, Other="other", Unused="delete me"},
        Units = {player={Texts={}}, target={Texts={}}} }
end
local a, b = Payload("A"), Payload("B") -- fixture boundary retained for dependent suites
-- E6 replaces the retired name-list/bulk-apply model with the canonical entity window.
for _,path in ipairs({"Engine/Text/Shared/TextElementRoles.lua", "Engine/Text/Shared/TextTemplateResolver.lua",
    "Engine/Text/Shared/TextTemplateValidation.lua", "Data/BuiltInTextTemplates.lua",
    "GUI/Pages/TextBuilder/TextBuilderEntity.lua"}) do Load(path) end
local builder=ns.GUI.Pages.TextBuilder
local R=builder.EntityBuilder
local function Id(n) return "tpl:u:"..string.rep("a",32)..":1-2-"..string.rep("b",32)..":"..n end
local A,B=Id(1),Id(2)
a={Units={player={Texts={shared={templateId=A},localText={tag="local"}}}}}
b={Units={player={Texts={shared={templateId=A}}}}}
ns.db={profile={General={}},char={activeLayoutId="layout:a"},global={TextTemplates={
    [A]={name="Same",content="A"},[B]={name="Same",content="B"}},UserLayouts={
    ["layout:a"]={name="A",formatVersion=2,payload=a},["layout:b"]={name="B",formatVersion=2,payload=b}}}}
R.SetIdGenerator(assert(ns.TextTemplateLibrary.CreateUserTemplateIdGenerator({time=function()return 10 end,uptime=function()return 1 end,random=function()return 3 end})))
ns.ActiveLayoutResolver.InvalidateActiveRuntimeRoot()
local combat,failResync,refreshes=false,false,0
function InCombatLockdown()return combat end
ns.GUI.RequestRefreshOptions=function() refreshes=refreshes+1;builder.RefreshWindowState() end
ns.RefreshAllUnitFrames=function()refreshes=refreshes+1 end
ns.RebuildFramesForActiveProfile=function() if failResync then error("rebuild failure") end end
ns.RefreshEditorSelectionVisuals=function()end
ns.RefreshEditorInteractionVisuals=function()end
ns.GUI.Helpers.OptionRefresh={Live=function()end}
local function NoErrors()assert(#f.env.errors==0,table.concat(f.env.errors,"\n"))end
local c,dialog
local create=builder.CreateEntityWindow
builder.CreateEntityWindow=function(...) c=create(...);return c end
local openDialog=builder.OpenLayoutDialog
builder.OpenLayoutDialog=function(...)dialog=openDialog(...);return dialog end
local function Open(kind,key)
    local request=kind and {entity=true,kind=kind,layoutId=ns.db.char.activeLayoutId,
        unitKey=kind=="object" and "player" or nil,textKey=kind=="object" and key or nil,
        templateId=kind=="shared-template" and key or nil}
    local ok,reason=ns.GUIController.OpenTextBuilderWindow(request);assert(ok,reason);NoErrors();return c.r2Session
end
local function Click(w)assert(w);w:Fire("OnClick");NoErrors()end
local function Edit(w,text)w:SetText(text);w:Fire("OnTextChanged",text);NoErrors()end
local function Close()
    builder.HideWindow();if builder.HasUnsavedChanges()then Click(dialog.discardCloseButton)end
    assert(not builder.HasUnsavedChanges() and not c.window.frame:IsShown())
end
local function Activate(id,options)local ok,why=ns:ActivateLayout(id,"test",options);assert(ok,why);NoErrors()end
Activate("layout:b",{silent=true});Activate("layout:a",{silent=true})
local s=Open();assert(s.kind=="new-template")
Edit(c.templateNameEdit,"Same");Edit(c.templateEdit,"new");local count=refreshes
Click(c.saveButton);assert(c.r2Session.templateId and refreshes>count)
local created=c.r2Session.templateId
count=refreshes;Click(c.saveButton);assert(refreshes==count,"no-op refreshed")
Edit(c.templateNameEdit,"Renamed");Click(c.updateTemplateButton)
assert(ns.db.global.TextTemplates[created].name=="Renamed" and c.r2Session.templateId==created)
Click(c.applyTemplateButton);local copied=c.r2Session.templateId;assert(copied~=created)
Click(c.deleteTemplateButton);Click(dialog.deleteConfirmButton)
assert(ns.db.global.TextTemplates[copied]==nil and c.r2Session.kind=="new-template")
Open("object","shared");Edit(c.templateEdit,"all layouts");Click(c.saveButton)
assert(dialog.widgets.all and ns.db.global.TextTemplates[A].content=="A")
Click(dialog.widgets.all);assert(ns.db.global.TextTemplates[A].content=="all layouts")
assert(a.Units.player.Texts.shared.templateId==A and b.Units.player.Texts.shared.templateId==A)
Edit(c.templateEdit,"fork");Click(c.saveButton);Click(dialog.widgets.copy)
assert(a.Units.player.Texts.shared.templateId~=A and b.Units.player.Texts.shared.templateId==A)
Close();s=Open("object","localText")
Edit(c.templateEdit,"dirty")
for _,options in ipairs({{},{silent=true}})do
    local ok,why=ns:ActivateLayout("layout:b","direct",options);assert(not ok and why=="unsaved-changes")
end
combat=true;local ok,why=ns:ActivateLayout("layout:b","combat");assert(not ok and why=="unsaved-changes");combat=false
builder.HideWindow();Click(dialog.cancelButton);assert(builder.HasUnsavedChanges())
builder.HideWindow();Click(dialog.saveCloseButton);assert(a.Units.player.Texts.localText.tag=="dirty" and not c.window.frame:IsShown())
-- Tag callbacks and dialogs own one session, even for A -> B -> A.
local tagApply
ns.GUI.Pages.TagLibrary={Open=function(options)tagApply=options.onApply end}
s=Open("object","localText");Click(c.tagLibraryButton);assert(tagApply("[name]"))
Close();s=Open("object","localText");Click(c.tagLibraryButton);local staleTag=tagApply
local capture=R.Capture(s);Open("shared-template",B);assert(not R.Valid(s,capture) and not staleTag("stale"))
Click(c.deleteTemplateButton);local staleDelete=dialog.deleteConfirmButton.events.OnClick
Open("object","localText");staleDelete();assert(ns.db.global.TextTemplates[B])
-- Specialization, queue-time and post-combat activation use the same guard.
function GetSpecialization()return 1 end
C_SpecializationInfo={GetSpecializationInfo=function()return 71 end}
assert(ns.LayoutAssignmentService.SetSpecializationAssignment(71,"layout:b"))
Edit(c.templateEdit,"spec dirty")
ok,why=ns.LayoutAssignmentService.EvaluateCurrentSpecializationAssignment("test");assert(not ok and why=="dirty-text-builder",tostring(why))
Close();Open("object","localText");combat=true
ok,why=ns.LayoutAssignmentService.EvaluateCurrentSpecializationAssignment("test");assert(not ok and why=="pending",tostring(why))
Edit(c.templateEdit,"queued dirty");combat=false
ns._layoutActivationEventFrame:Run("OnEvent","PLAYER_REGEN_ENABLED")
assert(ns.db.char.activeLayoutId=="layout:a" and ns._pendingLayoutActivation==nil)
Close();s=Open("object","localText");capture=R.Capture(s)
failResync=true;ok,why=ns:ActivateLayout("layout:b","rollback");failResync=false
assert(not ok and why=="resync-error" and R.Valid(s,capture))
combat=true;ok,why=ns:ActivateLayout("layout:b","queue",{silent=true});assert(not ok and why=="pending")
combat=false;ns._layoutActivationEventFrame:Run("OnEvent","PLAYER_REGEN_ENABLED")
assert(ns.db.char.activeLayoutId=="layout:b" and not R.Valid(s,capture))
Activate("layout:a")
for i=1,30 do
    s=Open("object","localText");capture=R.Capture(s);Click(c.tagLibraryButton);local old=tagApply
    Edit(c.templateEdit,"cycle "..i);Close()
    Activate("layout:b",{silent=i%2==0});Open("shared-template",A)
    assert(c.templateEdit:GetText()=="all layouts");Close();Activate("layout:a")
    assert(not R.Valid(s,capture) and not old("stale"))
end
-- A synchronous refresh may switch layout and open a new window session.
-- The completed save stays committed; its old Close continuation owns nothing.
s=Open("object","localText");Edit(c.templateEdit,"saved before refresh switch")
builder.HideWindow()
local refresh=ns.GUI.RequestRefreshOptions
ns.GUI.RequestRefreshOptions=function()
    ns.GUI.RequestRefreshOptions=refresh
    Activate("layout:b",{silent=true});Open("shared-template",A)
end
Click(dialog.saveCloseButton)
assert(a.Units.player.Texts.localText.tag=="saved before refresh switch")
assert(c.window.frame:IsShown() and c.r2Session.activeLayoutId=="layout:b")
Close();Activate("layout:a")
Open("shared-template","tpl:b:default-013");assert(c.templateEdit.disabled and c.saveButton.disabled)
assert(not builder.InsertTextIntoDraft("forbidden"));Close()
local function NoDraft(value)
    if type(value)~="table" then return end
    assert(value.draftToken==nil and value.baseline==nil and value.editContext==nil)
    for _,v in pairs(value)do NoDraft(v)end
end
NoDraft(ns.db);NoErrors()
print("PASS: real Entity Builder CRUD/fork/local/tag/save-close, stale callbacks, direct/spec/combat/rollback and 30 lifecycle cycles")
