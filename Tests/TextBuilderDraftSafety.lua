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
local a, b = Payload("A"), Payload("B")
ns.db = {profile={General={}, TextTemplates={Legacy="legacy"}, Units={}},
    char={activeLayoutId="layout:a"}, global={UserLayouts={
        ["layout:a"]={name="A",formatVersion=1,payload=a},
        ["layout:b"]={name="B",formatVersion=1,payload=b},
    }}, GetCurrentProfile=function() return "Same profile" end}
local resolver, mutations, builder = ns.ActiveLayoutResolver, ns.TextTemplateMutations, ns.GUI.Pages.TextBuilder
resolver.InvalidateActiveRuntimeRoot()
local combat, failResync, refreshes = false, false, 0
function InCombatLockdown() return combat end
ns.GUI.RequestRefreshOptions = function() refreshes=refreshes+1; builder.RefreshWindowState() end
ns.RebuildFramesForActiveProfile = function()
    if failResync then error("simulated frame rebuild failure") end
end
ns.RefreshEditorSelectionVisuals = function() end
ns.GUI.Helpers.OptionRefresh = {Live=function() end}
ns.RefreshEditorInteractionVisuals = function() end
local function Closure(fn, name, seen)
    seen=seen or {}; if seen[fn] then return end; seen[fn]=true
    local children={}
    for i=1,200 do
        local key,value=debug.getupvalue(fn,i); if not key then break end
        if key==name then return value end
        if type(value)=="function" then children[#children+1]=value end
    end
    for _,child in ipairs(children) do local value=Closure(child,name,seen); if value then return value end end
end
local function NoErrors() assert(#f.env.errors==0,table.concat(f.env.errors,"\n")) end
local c
local function Open()
    ns.GUIController.OpenTextBuilderWindow()
    c=assert(f.Upvalue(builder.OpenWindow,"windowContext"))
    NoErrors()
end
local function Click(widget) assert(widget); widget:Fire("OnClick"); NoErrors() end
local function Edit(widget,text) widget:SetText(text); widget:Fire("OnTextChanged",text); NoErrors() end
local function Select(name)
    local key=table.concat({"profile","Same profile","Same profile","",name},"\031")
    c.templateSelect:Fire("OnValueChanged",key); NoErrors()
end
local function Dialog(name) return assert(Closure(builder.HideWindow,name) or Closure(builder.OpenWindow,name)) end
local function Discard()
    builder.HideWindow(); NoErrors()
    if builder.HasUnsavedChanges() then Click(Dialog("unsavedCloseDialogContext").discardCloseButton) end
    assert(not builder.HasUnsavedChanges() and not c.window.frame:IsShown())
    assert(c.state.editingLayoutId==nil and c.state.draftBaseline==nil)
    Equal(c.state.applyUnits,{}); Equal(c.templateEdit:GetText(),"")
    Equal(c.state.selectedTemplate,""); Equal(c.state.templateName,"")
end
local function Activate(id, options)
    local ok, reason=ns:ActivateLayout(id,"test",options); assert(ok,reason); NoErrors()
    Equal(ns.db.char.activeLayoutId,id); Equal(resolver.GetActiveRuntimeRoot().layoutId,id)
end
local function RejectActivation(id, options)
    local root=resolver.GetActiveRuntimeRoot(); local token=c.state.draftToken
    local ok,reason=ns:ActivateLayout(id,"test",options)
    assert(not ok and reason=="unsaved-changes", tostring(reason))
    Equal(resolver.GetActiveRuntimeRoot(),root); assert(c.state.draftToken==token)
    Equal(ns.db.char.activeLayoutId,"layout:a"); Equal(b.TextTemplates.Shared,"B")
end

-- No initialized Builder context: the general boundary must permit activation.
assert(ns.GUIController.CanActivateLayout())
Activate("layout:b",{silent=true}); Activate("layout:a",{silent=true})
assert(f.Upvalue(builder.OpenWindow,"windowContext")==nil)
Open(); assert(not builder.HasUnsavedChanges()); Equal(c.state.editingLayoutId,"layout:a")
Select("Shared"); Equal(c.templateEdit:GetText(),"A")
local baseline, token=c.state.draftBaseline,c.state.draftToken
Edit(c.templateEdit,"A draft"); assert(builder.HasUnsavedChanges())
assert(c.state.draftBaseline==baseline); assert(c.state.draftToken==token)
RejectActivation("layout:b"); RejectActivation("layout:b",{silent=true})
combat=true; RejectActivation("layout:b"); assert(ns._pendingLayoutActivation==nil); combat=false
Click(c.newTemplateButton); Equal(c.templateEdit:GetText(),"A draft")
Select("Other"); Equal(c.state.selectedTemplate,"Shared"); Equal(c.templateEdit:GetText(),"A draft")
Click(c.deleteTemplateButton); Equal(c.templateEdit:GetText(),"A draft")
builder.HideWindow(); Click(Dialog("unsavedCloseDialogContext").cancelButton)
assert(c.state.draftToken==token); Equal(c.templateEdit:GetText(),"A draft"); assert(builder.HasUnsavedChanges())
Edit(c.templateEdit,"A"); assert(not builder.HasUnsavedChanges())
Select("Shared"); assert(c.state.draftToken==token) -- same selection is not a new lifecycle
Edit(c.templateEdit,"saved A"); Click(c.saveButton)
Equal(a.TextTemplates.Shared,"saved A"); assert(not builder.HasUnsavedChanges())
assert(c.state.draftToken~=token)
Edit(c.templateEdit,"discard saved draft"); Discard(); Open(); Equal(c.templateEdit:GetText(),"")

Click(c.newTemplateButton); Equal(c.templateEdit:GetText(),""); assert(not builder.HasUnsavedChanges())
Edit(c.templateNameEdit,"New display"); assert(builder.HasUnsavedChanges())
Edit(c.templateNameEdit,""); assert(not builder.HasUnsavedChanges())
Edit(c.templateEdit,"new body"); assert(builder.HasUnsavedChanges()); Discard(); Open()
Equal(c.templateEdit:GetText(),"")
Click(c.newTemplateButton); Edit(c.templateNameEdit,"Created"); Edit(c.templateEdit,"created body")
Click(c.saveButton); Equal(a.TextTemplates.Created,"created body"); assert(not builder.HasUnsavedChanges())
-- Rename preserves unsaved content and its baseline while expiring callbacks.
local oldBaseline=c.state.draftBaseline; local oldToken=c.state.draftToken
Edit(c.templateEdit,"unsaved after rename"); Edit(c.templateNameEdit,"Renamed")
Click(c.updateTemplateButton)
assert(a.TextTemplates.Created==nil); Equal(a.TextTemplates.Renamed,"created body")
Equal(c.templateEdit:GetText(),"unsaved after rename"); assert(c.state.draftBaseline==oldBaseline)
assert(c.state.draftToken~=oldToken and builder.HasUnsavedChanges())
Click(c.saveButton); Equal(a.TextTemplates.Renamed,"unsaved after rename")
Click(c.deleteTemplateButton); Click(Dialog("deleteDialogContext").deleteConfirmButton)
assert(a.TextTemplates.Renamed==nil and not builder.HasUnsavedChanges())

-- A clean switch always invalidates, even without a GUI refresh.
Select("Shared"); token=c.state.draftToken
local beforeRefresh=refreshes
Activate("layout:b",{silent=true}); Equal(refreshes,beforeRefresh)
assert(c.state.draftToken~=token); Equal(c.state.selectedTemplate,""); Equal(c.templateEdit:GetText(),"")
Equal(c.state.editingLayoutId,"layout:b"); Select("Shared"); Equal(c.templateEdit:GetText(),"B")
Activate("layout:a"); Select("Shared")

-- Capture real dialog closures, then return to the same layout/template: no ABA revival.
Click(c.deleteTemplateButton)
local deleteDialog=Dialog("deleteDialogContext"); local oldDelete=deleteDialog.deleteConfirmButton.events.OnClick
Click(deleteDialog.cancelButton)
Edit(c.templateEdit,"pending edit"); Click(c.applyTemplateButton)
local applyDialog=Dialog("unsavedApplyDialogContext")
local oldApply,oldSaveApply=applyDialog.applyStoredButton.events.OnClick,applyDialog.saveApplyButton.events.OnClick
Click(applyDialog.cancelButton)
builder.HideWindow(); local closeDialog=Dialog("unsavedCloseDialogContext")
local oldDiscard,oldSaveClose=closeDialog.discardCloseButton.events.OnClick,closeDialog.saveCloseButton.events.OnClick
Click(closeDialog.discardCloseButton)
Activate("layout:b"); Activate("layout:a"); Open(); Select("Shared")
local snapshot=ns.LayoutService.Clone(a); token=c.state.draftToken
for _,callback in ipairs({oldDelete,oldApply,oldSaveApply,oldDiscard,oldSaveClose}) do callback() end
Equal(a,snapshot); assert(c.state.draftToken==token); assert(c.window.frame:IsShown()); NoErrors()
-- Saving expires another open decision; cancellation/reopening cannot revive its closure.
Edit(c.templateEdit,"next save"); builder.HideWindow(); oldDiscard=Dialog("unsavedCloseDialogContext").discardCloseButton.events.OnClick
Click(c.saveButton); token=c.state.draftToken
Edit(c.templateEdit,"after save"); builder.HideWindow(); oldDiscard()
assert(c.state.draftToken==token); Equal(c.templateEdit:GetText(),"after save"); assert(builder.HasUnsavedChanges())
Click(Dialog("unsavedCloseDialogContext").discardCloseButton); Open(); Select("Shared")

-- Unexpected layout writes bypassing ActivateLayout must never redirect mutations.
Edit(c.templateEdit,"must never reach B"); Click(c.applyTemplateButton)
applyDialog=Dialog("unsavedApplyDialogContext")
local staleSaveApply=applyDialog.saveApplyButton.events.OnClick
ns.db.char.activeLayoutId="layout:b"; resolver.SetActiveRuntimeRoot(assert(resolver.ResolveRuntimeRoot(ns.db,"layout:b")))
snapshot=ns.LayoutService.Clone(b)
Click(c.saveButton); Click(c.deleteTemplateButton); Click(c.applyTemplateButton); staleSaveApply()
Equal(b,snapshot); Equal(c.state.editingLayoutId,"layout:a"); assert(builder.HasUnsavedChanges())
Discard(); Open(); Equal(c.state.editingLayoutId,"layout:b"); Equal(c.templateEdit:GetText(),"")
Activate("layout:a"); Select("Shared")

-- Real spec service calls the same activation path; its early dirty feedback remains.
GetSpecialization=function() return 1 end
GetSpecializationInfo=function() return 71,"Arms" end
assert(ns.LayoutAssignmentService.SetSpecializationAssignment(71,"layout:b"))
Edit(c.templateEdit,"spec dirty")
local ok,reason=ns.LayoutAssignmentService.EvaluateCurrentSpecializationAssignment("test-spec")
assert(not ok and reason=="dirty-text-builder"); Equal(ns.db.char.activeLayoutId,"layout:a")
Edit(c.templateEdit,a.TextTemplates.Shared)
combat=true
ok,reason=ns.LayoutAssignmentService.EvaluateCurrentSpecializationAssignment("test-spec")
assert(not ok and reason=="pending"); Equal(ns._pendingLayoutActivation.layoutId,"layout:b")
Edit(c.templateEdit,"dirty after queue"); combat=false
ns._layoutActivationEventFrame:Run("OnEvent","PLAYER_REGEN_ENABLED")
assert(ns._pendingLayoutActivation==nil); Equal(ns.db.char.activeLayoutId,"layout:a")
Click(c.saveButton); ns._layoutActivationEventFrame:Run("OnEvent","PLAYER_REGEN_ENABLED")
Equal(ns.db.char.activeLayoutId,"layout:a")
combat=true; ok,reason=ns:ActivateLayout("layout:b","test",{silent=true}); assert(not ok and reason=="pending")
token=c.state.draftToken; combat=false; ns._layoutActivationEventFrame:Run("OnEvent","PLAYER_REGEN_ENABLED")
Equal(ns.db.char.activeLayoutId,"layout:b"); assert(c.state.draftToken~=token and ns._pendingLayoutActivation==nil)
Activate("layout:a"); Select("Shared")

-- Real unit assignment mutations: Save & Apply retains its existing deferred
-- checkbox resync behavior, but failed saves and stale contexts cannot apply.
local applyCalls=0
local realApply=mutations.ApplyTemplateToUnits
mutations.ApplyTemplateToUnits=function(...)
    applyCalls=applyCalls+1
    return realApply(...)
end
c.usageCheckboxes.player:Fire("OnValueChanged",true)
Click(c.applyTemplateButton); assert(applyCalls==1)
local usage=ns.TextTemplateUsage.GetTemplateUsage(mutations.CreateActiveLayoutContext(ns.db),"Shared")
assert(#usage.references>0)
Edit(c.templateEdit,"save and apply")
c.usageCheckboxes.target:Fire("OnValueChanged",true)
Click(c.applyTemplateButton); Click(Dialog("unsavedApplyDialogContext").saveApplyButton)
Equal(a.TextTemplates.Shared,"save and apply"); assert(not builder.HasUnsavedChanges())
assert(c.state.applyUnits.target==false and next(a.Units.target.Texts)==nil,
    "deferred Save & Apply checkbox behavior changed")
local callsBefore=applyCalls
Edit(c.templateEdit,""); Click(c.applyTemplateButton)
Click(Dialog("unsavedApplyDialogContext").saveApplyButton)
Equal(applyCalls,callsBefore); Equal(a.TextTemplates.Shared,"save and apply")
Click(Dialog("unsavedApplyDialogContext").cancelButton)
Edit(c.templateEdit,a.TextTemplates.Shared)
-- A pending tag-library insertion also belongs to its captured draft.
local tagApply
ns.GUI.Pages.TagLibrary={Open=function(options) tagApply=options.onApply end,Close=function() end}
Click(c.tagLibraryButton); assert(tagApply)
Select("Other"); local draft=c.templateEdit:GetText()
assert(not tagApply("[name]")); Equal(c.templateEdit:GetText(),draft)
Select("Shared")

-- A synchronous refresh following Save must not authorize Apply/Close in a
-- different context. The completed save stays in A; its continuation is rejected.
Edit(c.templateEdit,"saved before context change"); Click(c.applyTemplateButton)
local afterSaveApply=Dialog("unsavedApplyDialogContext").saveApplyButton
callsBefore=applyCalls; snapshot=ns.LayoutService.Clone(b)
ns.RefreshEditorInteractionVisuals=function() Activate("layout:b",{silent=true}) end
Click(afterSaveApply)
ns.RefreshEditorInteractionVisuals=function() end
Equal(a.TextTemplates.Shared,"saved before context change"); Equal(b,snapshot); Equal(applyCalls,callsBefore)
Equal(c.state.editingLayoutId,"layout:b"); assert(c.window.frame:IsShown())
Activate("layout:a"); Select("Shared")

-- A failed activation restores root/ID and does not rebind or clear a clean draft.
local root=resolver.GetActiveRuntimeRoot(); token=c.state.draftToken; baseline=c.state.draftBaseline
failResync=true; ok,reason=ns:ActivateLayout("layout:b","rollback"); failResync=false
assert(not ok and reason=="resync-error"); Equal(ns.db.char.activeLayoutId,"layout:a")
assert(resolver.GetActiveRuntimeRoot()==root and c.state.draftToken==token and c.state.draftBaseline==baseline)
Equal(c.state.editingLayoutId,"layout:a"); Equal(c.templateEdit:GetText(),a.TextTemplates.Shared)
ok,reason=ns:ActivateLayout("layout:a"); assert(not ok and reason=="same-layout"); assert(c.state.draftToken==token)

-- Built-ins remain inspectable and cannot create writable drafts or copies.
Activate("builtin:default"); local builtin=assert(resolver.GetActivePayloadRoot(ns.db))
local builtinName=next(builtin.TextTemplates); assert(builtinName); Select(builtinName)
assert(c.templateEdit.disabled and c.templateNameEdit.disabled and c.newTemplateButton.disabled)
assert(c.saveButton.disabled and c.deleteTemplateButton.disabled and c.applyTemplateButton.disabled)
assert(not c.templateSelect.disabled); Equal(c.templateEdit:GetText(),builtin.TextTemplates[builtinName])
snapshot=ns.LayoutService.Clone(ns.db.global.UserLayouts)
Click(c.newTemplateButton); Click(c.saveButton); Click(c.updateTemplateButton); Click(c.deleteTemplateButton); Click(c.applyTemplateButton)
assert(not builder.InsertTextIntoDraft("forbidden")); Equal(ns.db.global.UserLayouts,snapshot)
assert(not builder.HasUnsavedChanges()); Discard(); Activate("layout:a"); Open()

-- Repeated real widget/context lifecycle; no persisted draft fields or pending actions.
for i=1,20 do
    Select("Shared"); Edit(c.templateEdit,"cycle "..i); Discard()
    Activate("layout:b",{silent=i%2==0}); Open(); Select("Shared"); Equal(c.templateEdit:GetText(),"B")
    Discard(); Activate("layout:a"); Open(); Equal(c.templateEdit:GetText(),"")
    assert(not builder.HasUnsavedChanges())
end
-- Existing concrete Add Object / Change Text / state-template mutation contracts.
local mutationContext=mutations.CreateActiveLayoutContext(ns.db)
local result=mutations.CreateTextFromTemplate(mutationContext,"target","Other",{anchorTo="HealthBar"})
assert(result.ok,result.errorCode)
local textKey=result.textKey
Equal(a.Units.target.Texts[textKey].templateName,"Other")
Equal(a.Units.target.Texts[textKey].anchorTo,"HealthBar")
assert(mutations.AssignTemplate(mutationContext,"target",textKey,"Shared").ok)
assert(mutations.AssignStateTemplate(mutationContext,"target",textKey,"dead","Other").ok)
assert(mutations.RenameTemplate(mutationContext,"Other","Other renamed").ok)
Equal(a.Units.target.Texts[textKey].templateName,"Shared")
Equal(a.Units.target.Texts[textKey].stateTemplates.dead,"Other renamed")
assert(mutations.UpdateTemplate(mutationContext,"Other renamed","updated").ok)
local blockedDelete=mutations.DeleteTemplate(mutationContext,"Other renamed")
assert(not blockedDelete.ok and blockedDelete.errorCode=="template_in_use")
assert(mutations.UnassignStateTemplate(mutationContext,"target",textKey,"dead").ok)
assert(mutations.DeleteTemplate(mutationContext,"Other renamed").ok)
local function NoDraftFields(value)
    if type(value)~="table" then return end
    assert(value.draftToken==nil and value.draftBaseline==nil and value.editingLayoutId==nil)
    for _,child in pairs(value) do NoDraftFields(child) end
end
NoDraftFields(ns.db); NoErrors()
print("PASS: TextBuilder layout/draft/readonly safety, stale dialogs, direct/silent/spec/combat/rollback and 20 lifecycle cycles")
