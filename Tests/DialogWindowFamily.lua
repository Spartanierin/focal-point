-- lua54 Tests/DialogWindowFamily.lua
-- Real factories/consumer builders; WoW frames are supplied by the native fixture.
local f=dofile("Tests/ParchmentWindow.lua")
local ns,ace,native,Equal,Load,Upvalue=f.ns,f.ace,f.native,f.Equal,f.Load,f.Upvalue
local forms=f.widgets
local names=0
function native:GetChildren() end
function native:GetName()
    if not self.testName then
        names=names+1; self.testName="DialogFixture"..names
        for _,suffix in ipairs({"Left","Middle","Right","Button","ScrollBar"}) do
            _G[self.testName..suffix]=CreateFrame("Frame",nil,self)
        end
        _G[self.testName.."Text"]=self:CreateFontString()
    end
    return self.testName
end
for _,method in ipairs({"SetMultiLine","SetMaxLetters","SetTextInsets","SetSpacing","SetIndentedWordWrap",
    "SetHyperlinksEnabled","SetIndentedWordWrap","SetNumeric","SetJustifyV","SetHitRectInsets",
    "SetCursorPosition","SetMaxBytes","SetCountInvisibleLetters","SetAltArrowKeyMode","HighlightText"}) do
    native[method]=native[method] or function(self,...) self["last"..method]={...} end
end
for _,file in ipairs({"AceGUIWidget-EditBox","AceGUIWidget-MultiLineEditBox","AceGUIWidget-DropDown-Items","AceGUIWidget-DropDown",
    "AceGUIContainer-InlineGroup"}) do Load("Libraries/Ace3/AceGUI-3.0/widgets/"..file..".lua") end
local created,latest={},nil
local create=forms.CreateCompactFormDialog
forms.CreateCompactFormDialog=function(options)
    latest=create(options); created[#created+1]=latest; return latest
end
local function Find(root,kind,text)
    if root.type==kind and (not text or root.label and root.label:GetText()==text) then return root end
    for _,child in ipairs(root.children or {}) do local found=Find(child,kind,text); if found then return found end end
end
local function Check(dialog,width,height)
    f.Check(dialog)
    Equal({dialog.window.frame:GetWidth(),dialog.window.frame:GetHeight()},{width,height})
end
local function CheckText(root,text,role,size)
    local function Visit(widget)
        local label=widget.label
        if label and label:GetText()==text and label.font and label.font[2]==size then return label end
        for _,child in ipairs(widget.children or {}) do local found=Visit(child); if found then return found end end
    end
    local label=assert(Visit(root),text)
    local color=ns.GUI.Helpers.TextStyles.Get(role)
    Equal(label.lastSetTextColor,{color.r,color.g,color.b,1})
    Equal(label.font,{STANDARD_TEXT_FONT,size,""}); Equal(label.lastSetShadowOffset,{1,-1})
end
Check(f.options,360,349)
CheckText(f.options.body,"Displays a visual alignment grid while editing frames.","help",11)
CheckText(f.options.body,"Snap frames to the screen center and other editable frames while moving them.","help",11)
CheckText(f.options.body,"Show Grid","label",12)
local optionGeometry=f.Geometry(f.options.window)
ns.GUI.Editor.OptionsDialog.Close(); ns.GUI.Editor.OptionsDialog.Open()
Equal(f.Geometry(f.options.window),optionGeometry)

-- Real manager name/confirmation consumers and their existing mutation callbacks.
local manager=ns.GUI.Editor.LayoutManager
local context=Upvalue(manager.Open,"context")
local calls={}
ns.LayoutMutations={
    RenameUserLayout=function(id,name) calls.rename={id,name}; return false,"invalid-name" end,
    CopyLayout=function(id,name,opts) calls.copy={id,name,opts.activate}; return false,"invalid-name" end,
    DeleteUserLayout=function(id) calls.delete=id; return false,"delete-failed" end,
}
context.selectedLayoutId="layout:one"; manager.Refresh()
context.widgets.renameButton:Fire("OnClick")
assert(#f.env.errors==0,table.concat(f.env.errors,"\n"))
Check(latest,420,209); latest.nameEdit:SetText("Renamed"); latest.primaryButton:Fire("OnClick")
Equal(calls.rename,{"layout:one","Renamed"}); Equal(latest.statusRole,"error")
latest.cancelButton:Fire("OnClick")
context.widgets.copyButton:Fire("OnClick")
Check(latest,420,209); latest.nameEdit:SetText("Copy"); latest.primaryButton:Fire("OnClick")
Equal(calls.copy,{"layout:one","Copy",false}); latest.cancelButton:Fire("OnClick")
context.activeLayoutId="layout:other"
context.widgets.deleteButton:Fire("OnClick")
Check(latest,430,173); latest.primaryButton:Fire("OnClick"); Equal(calls.delete,"layout:one")
Equal(latest.statusRole,"error"); latest.cancelButton:Fire("OnClick")

-- Transfer uses the actual multiline control and release/focus callbacks.
ns.L.LAYOUT_TRANSFER_IMPORTED="Imported: %s"
local importOK=false
ns.LayoutTransfer={Export=function(id) calls.export=id; return "payload" end,
    Import=function(value) calls.import=value; if importOK then return true,"layout:one","One" end; return false,"invalid-header" end}
context.widgets.exportButton:Fire("OnClick")
assert(#f.env.errors==0,table.concat(f.env.errors,"\n"))
Check(latest,560,375)
local transferEdit=assert(Find(latest.body,"MultiLineEditBox"))
Equal(transferEdit:GetText(),"payload"); Equal(calls.export,"layout:one")
latest.primaryButton:Fire("OnClick"); Equal(ace.FocusedWidget,transferEdit)
latest.cancelButton:Fire("OnClick"); assert(latest.released); Equal(ace.FocusedWidget,nil)
context.widgets.importButton:Fire("OnClick"); Check(latest,560,375)
transferEdit=assert(Find(latest.body,"MultiLineEditBox"))
transferEdit:SetText("bad"); transferEdit:Fire("OnTextChanged")
latest.primaryButton:Fire("OnClick"); Equal(calls.import,"bad"); Equal(latest.statusRole,"error")
importOK=true; latest.primaryButton:Fire("OnClick")
Equal(latest.statusRole,"success"); Equal(transferEdit:GetText(),"")
latest.cancelButton:Fire("OnClick"); assert(latest.released)

-- New Layout's real form, validation and create/cancel wiring.
local ensureHost=Upvalue(ns.GUI.Editor.CanvasToolbar.UpdateGeometry,"EnsureHost")
local openNew=Upvalue(ensureHost,"OpenNewLayoutDialog")
ns.LayoutMutations.CreateUserLayoutFromSource=function(source,name) calls.new={source,name}; return false,"invalid-name" end
openNew(); Check(latest,420,229)
local name=assert(Find(latest.body,"EditBox")); local source=assert(Find(latest.body,"Dropdown"))
source:SetValue("layout:one")
name:SetText("New"); name:Fire("OnTextChanged","New")
latest.primaryButton:Fire("OnClick"); assert(calls.new); Equal(latest.statusRole,"error")
latest.cancelButton:Fire("OnClick")

-- Actual specialization table and empty state retain their calculated bounds.
local specCount=3
function GetNumSpecializations() return specCount end
C_SpecializationInfo={GetSpecializationInfo=function(i) return i,"Spec "..i end}
ns.LayoutAssignmentService={GetCurrentSpecialization=function() return 1 end,
    GetSpecializationAssignment=function() return nil,"missing" end,
    SetSpecializationAssignment=function(spec,value) calls.assignment={spec,value}; return true end}
Load("GUI/Editor/LayoutAssignments/LayoutAssignmentView.lua")
ns.GUI.Editor.LayoutAssignments.Open(); local assignments=latest
Check(assignments,520,264)
local dropdown=assert(Find(assignments.body,"Dropdown")); dropdown:Fire("OnValueChanged","layout:one")
Equal(calls.assignment,{1,"layout:one"})
specCount=0; ns.GUI.Editor.LayoutAssignments.Refresh()
CheckText(assignments.body,"No specializations available.","help",11)
ns.GUI.Editor.LayoutAssignments.Close(); ns.GUI.Editor.LayoutAssignments.Open(); Check(assignments,520,264)

-- Actual editable-template confirmation preserves pending/ready semantics.
ns.ActiveLayoutResolver={GetStoredActiveLayoutId=function() return "builtin:default" end,
    ResolveLayout=function() return {name="Default"} end}
Load("GUI/Editor/LayoutEditWorkflow.lua")
local ready=0
ns.LayoutEditWorkflow.RequestEditableLayoutForMutation(function() ready=ready+1 end)
Check(latest,440,185); latest.cancelButton:Fire("OnClick"); Equal(ready,0)
ns.LayoutMutations.CreateUserLayoutFromSource=function() return true,"layout:new" end
ns.LayoutEditWorkflow.RequestEditableLayoutForMutation(function() ready=ready+1 end)
latest.primaryButton:Fire("OnClick"); Equal(ready,1)

-- Run the unchanged Inspector confirmation closures with selection/mutation
-- boundaries supplied; keep their real factory, status and action callbacks.
local inspectorFile=assert(io.open("GUI/Editor/Inspector/InspectorController.lua"))
local inspectorSource=inspectorFile:read("*a"); inspectorFile:close()
local function InspectorConfirmation(name,env)
    local first=assert(inspectorSource:find("local function "..name.."(",1,true))
    local show=assert(inspectorSource:find("dialog:Show()",first,true))
    local last=assert(inspectorSource:find("end",show,true))+2
    return assert(load(inspectorSource:sub(first,last).."\nreturn "..name,"@Inspector/"..name,"t",setmetatable(env,{__index=_G})))()
end
local mutationOK=false; local deletes=0
local function Delete() deletes=deletes+1; return {ok=mutationOK,changed=mutationOK} end
local function CloseConfirmation() latest:Close() end
local function Noop() end
local common={ns=ns,L={},FormWidgets=forms,InspectorMutations={DeleteTextInstance=Delete,DeleteDecoration=Delete},
    ResolveMutationErrorMessage=function() return "Fixture error" end,
    CloseDeleteTextInstanceDialog=CloseConfirmation,CloseDeleteDecorationDialog=CloseConfirmation,
    IsSelectedTextObject=function() return true end,RequestEditableMutation=function(fn) return fn() end,
    NotifyCompositionTreeChanged=Noop,SelectUnitRootAfterTextDelete=Noop,NotifySidebarChanged=Noop,
    selectedDecorationId="decoration1",DeleteDecoration=Delete}
for _,spec in ipairs({{"OpenDeleteTextInstanceConfirmDialog",173},{"OpenDeleteDecorationConfirmDialog",165}}) do
    local open=InspectorConfirmation(spec[1],common)
    mutationOK=false; open("player","test"); Check(latest,420,spec[2])
    if spec[2]==173 then CheckText(latest.body,"The text template is not deleted.","help",11) end
    local before=deletes; latest.primaryButton:Fire("OnClick"); Equal(deletes,before+1)
    Equal(latest.statusRole,"error"); assert(latest.window.frame:IsShown())
    latest.cancelButton:Fire("OnClick"); Equal(deletes,before+1)
    open("player","test"); mutationOK=true; latest.primaryButton:Fire("OnClick")
    assert(not latest.window.frame:IsShown())
end

-- Real picker builders, rows, preview and both modes/empty state.
Load("GUI/Widgets/SelectionRow.lua")
Load("GUI/Editor/TextTemplateLibraryWindow.lua")
local templates={}
ns.ActiveLayoutResolver.GetActiveTextTemplates=function() return templates end
for _,mode in ipairs({"add","change"}) do
    for _,populated in ipairs({false,true}) do
        templates=populated and {Sample="Sample preview"} or {}
        ns.GUI.Editor.TextTemplateLibraryWindow.Open({mode=mode,unit="player",textKey="test"})
        Check(latest,700,367)
        assert(Find(latest.body,"ScrollFrame"))
        CheckText(latest.body,"Templates","sectionHeader",11)
        CheckText(latest.body,"Preview","sectionHeader",11)
        if populated then
            CheckText(latest.body,"Sample","sectionHeader",14)
            CheckText(latest.body,"Template","label",10)
            CheckText(latest.body,"Sample preview","highlight",17)
        end
        latest.cancelButton:Fire("OnClick")
    end
end

-- Direct utility chrome has no dependency on a Compact shell or its children.
Load("Data/Constants.lua")
ns.KeyMap=ns.KeyMap or {}
Load("GUI/Helpers/FormSectionSurfaceRenderer.lua")
Load("GUI/Helpers/FormRenderer.lua")
Load("GUI/Pages/TextBuilder/TextBuilderDefinition.lua")
Load("GUI/Pages/TextBuilder/TextBuilderController.lua")
local function Closure(fn,name,seen)
    seen=seen or {}; if seen[fn] then return end; seen[fn]=true
    local children={}
    for i=1,100 do
        local key,value=debug.getupvalue(fn,i); if not key then break end
        if key==name then return value end
        if type(value)=="function" then children[#children+1]=value end
    end
    for _,child in ipairs(children) do local found=Closure(child,name,seen); if found then return found end end
end
local controller=ns.GUI.Pages.TextBuilder
local openUtility=assert(Closure(controller.HideWindow,"OpenTextBuilderLayoutDialog"))
for _,spec in ipairs({{"DeleteConfirm",420,210},{"UnsavedApplyConfirm",560,230},{"UnsavedCloseConfirm",560,230}}) do
    local definition=ns.GUI.Layouts.TextBuilder[spec[1]]
    local opts={title=spec[1],windowWidth=spec[2],windowHeight=spec[3],state={message="Fixture message"}}
    local ctx=openUtility(nil,definition,opts)
    assert(ctx.groups.Message and ctx.widgets.message and ctx.cancelButton)
    assert(ctx.groups.Message.frame._fpSectionFill)
    assert(ctx.window.frame._fpParchmentNineSlice:IsShown())
    Equal(ctx.window.frame._fpCompactFormShell,nil)
    Equal({ctx.window.frame:GetWidth(),ctx.window.frame:GetHeight()},{spec[2],spec[3]})
    local bounds=f.Geometry(ctx.window); local children=#ctx.window.children; local count=f.Count()
    for _=1,10 do
        ctx.window.frame:Run("OnKeyDown","ESCAPE"); assert(not ctx.window.frame:IsShown())
        Equal(openUtility(ctx,definition,opts),ctx); assert(ctx.window.frame:IsShown())
        Equal(f.Geometry(ctx.window),bounds); Equal(#ctx.window.children,children)
    end
    Equal(f.Count(),count)
    ctx.window:Fire("OnClose"); ace:Release(ctx.window)
end

-- Existing utility action wiring; fake only persistence/apply boundaries.
local function Replace(fn,name,value)
    for i=1,100 do
        local key=debug.getupvalue(fn,i); if not key then break end
        if key==name then debug.setupvalue(fn,i,value); return end
    end
    error("missing boundary "..name)
end
local openApply=assert(Closure(controller.OpenWindow,"OpenUnsavedApplyConfirmDialog"))
local openClose=assert(Closure(controller.HideWindow,"OpenUnsavedCloseConfirmDialog"))
local openDelete=assert(Closure(controller.OpenWindow,"OpenDeleteTemplateConfirmDialog"))
local saveOK=false; local saves,applies=0,{}
Replace(openApply,"SaveCurrentTemplate",function() saves=saves+1; return saveOK end)
Replace(openApply,"ApplyTemplateToTextElement",function(_,opts) applies[#applies+1]=opts and "stored" or "saved" end)
local parent={window=ace:Create("Window"),templateEdit=ace:Create("EditBox"),
    templateNameEdit=ace:Create("EditBox"),templateSelect=ace:Create("Dropdown"),
    previewValue=ace:Create("Label")}
ns.ActiveLayoutResolver={
    GetStoredActiveLayoutId=function() return "layout:dialog-fixture" end,
    EnsureEditableForMutation=function() return {},"layout:dialog-fixture" end,
}
local function BeginDialogDraft()
    parent.state={editingLayoutId="layout:dialog-fixture",draftToken={},
        draftBaseline={template="",templateName=""},selectedTemplate="",template="",templateName=""}
end
BeginDialogDraft()
openApply(parent)
local apply=Upvalue(openApply,"unsavedApplyDialogContext")
apply.saveApplyButton:Fire("OnClick"); Equal(saves,1); Equal(#applies,0); assert(apply.window.frame:IsShown())
saveOK=true; apply.saveApplyButton:Fire("OnClick"); Equal(applies,{"saved"}); assert(not apply.window.frame:IsShown())
openApply(parent); apply.applyStoredButton:Fire("OnClick"); Equal(applies,{"saved","stored"})
openApply(parent); apply.cancelButton:Fire("OnClick"); Equal(#applies,2)
for _,button in ipairs({"saveCloseButton","discardCloseButton","cancelButton"}) do
    BeginDialogDraft()
    parent.window:Show(); openClose(parent)
    local close=Upvalue(openClose,"unsavedCloseDialogContext")
    close[button]:Fire("OnClick")
    Equal(parent.window.frame:IsShown(),button=="cancelButton")
    assert(not close.window.frame:IsShown())
end
Replace(openDelete,"GetTemplates",function() return {Sample="[name]"} end)
local mutations=Upvalue(openDelete,"TextTemplateMutations")
mutations.DeleteTemplate=function(_,name) calls.templateDelete=name; return {ok=true} end
ns.L.INFO_TEXT_BUILDER_DELETE_CONFIRM_PROMPT="Delete %s?"
openDelete(parent,"Sample")
local deletion=Upvalue(openDelete,"deleteDialogContext")
Equal(deletion.widgets.message.label:GetText(),"Delete Sample?")
deletion.cancelButton:Fire("OnClick"); Equal(calls.templateDelete,nil)
openDelete(parent,"Sample"); deletion.deleteConfirmButton:Fire("OnClick"); Equal(calls.templateDelete,"Sample")
assert(not deletion.window.frame:IsShown())

local utility=ace:Create("Window"); utility:SetWidth(560); utility:SetHeight(230); utility:EnableResize(false)
forms.ApplyWindowChrome(utility)
local geometry=f.Geometry(utility); local released=0
utility:SetCallback("OnRelease",function() released=released+1 end)
forms.ApplyWindowChrome(utility,{focalPointDialog=true})
Equal(f.Geometry(utility),geometry); Equal(utility.frame._fpCompactFormShell,nil)
local count=f.Count(); local callback=utility.events.OnRelease
for _=1,50 do
    utility:Hide(); utility:Show(); forms.ApplyWindowChrome(utility,{focalPointDialog=true})
    Equal(f.Geometry(utility),geometry); Equal(utility.events.OnRelease,callback)
end
Equal(f.Count(),count)
forms.ApplyWindowChrome(utility)
assert(not utility.frame._fpParchmentNineSlice:IsShown()); Equal(utility.frame._fpPanelFill:GetTexture(),nil)
forms.ApplyWindowChrome(utility,{focalPointDialog=true})
forms.ApplyModernWindowChrome(utility,{nineSlice=true,portrait=true,portraitTexture="portrait.png"})
assert(not utility.frame._fpParchmentNineSlice:IsShown()); assert(utility.frame._fpModernNineSlice:IsShown())
forms.ApplyWindowChrome(utility,{focalPointDialog=true})
assert(not utility.frame._fpModernNineSlice:IsShown()); assert(not utility.frame._fpModernPortraitBackground:IsShown())
ace:Release(utility); Equal(released,1)
assert(not utility.frame._fpParchmentNineSlice:IsShown())
-- Repeat real AceGUI release/acquire across the three presentations. After
-- warming each pooled host, neither regions nor release callbacks accumulate.
local pooledCount
for cycle=1,20 do
    for _,mode in ipairs({"compact","neutral","direct"}) do
        local window
        if mode=="direct" then
            window=ace:Create("Window"); forms.ApplyWindowChrome(window,{focalPointDialog=true})
            Equal(window.frame._fpCompactFormShell,nil)
        else
            local dialog=create({title="Pool",width=420,height=210,dialogPresentation=mode=="compact"})
            window=dialog.window
        end
        ace:Release(window)
        Equal(window.frame._fpCompactFormShell,nil)
        assert(not window.frame._fpParchmentNineSlice:IsShown())
    end
    if cycle==1 then pooledCount=f.Count() else Equal(f.Count(),pooledCount) end
end
forms.CreateCompactFormDialog=create
assert(#f.env.errors==0,table.concat(f.env.errors,"\n"))
print("PASS: Dialog family, Options, Layout/Transfer workflows, Assignments, all confirmations, both pickers, three direct utilities/actions, neutral/Modern transitions, 50 reapply and 60 pooling cycles")
