local _, ns = ...

ns.GUI = ns.GUI or {}
ns.GUI.Pages = ns.GUI.Pages or {}
local Builder = ns.GUI.Pages.TextBuilder
local Context = Builder.EntityContext
local Library = ns.TextTemplateLibrary
local Entity = ns.TextTemplateMutations and ns.TextTemplateMutations.Entity
local AceGUI = LibStub("AceGUI-3.0")
local FormWidgets = ns.GUI.Helpers and ns.GUI.Helpers.FormWidgets or {}
local FormRenderer = ns.GUI.Helpers and ns.GUI.Helpers.FormRenderer or {}
local R2 = {}
Builder.EntityBuilder = R2

local function T(key, fallback)
    local value = ns.L and ns.L[key]
    return type(value) == "string" and value ~= "" and value or fallback or key
end

local function GetResultPanelDefinition()
    local layouts = ns.GUI and ns.GUI.Layouts and ns.GUI.Layouts.TextBuilder
    for _, definition in ipairs(layouts and layouts.Form or {}) do
        if definition.section == "Preview" then
            return definition
        end
    end
end

local function CreateResultPanel(host)
    local definition = GetResultPanelDefinition()
    if not definition or type(FormRenderer.CreateLayoutGroup) ~= "function" then
        return nil
    end
    return FormRenderer.CreateLayoutGroup(host, definition)
end

local function Copy(record)
    return type(record) == "table" and {name=record.name, content=record.content} or nil
end
local function Record(db, id)
    local e, err = Library.ResolveTemplateEntity(id, db)
    if not e then return nil, err and err.errorCode or "template_not_found" end
    return {name=e.name, content=e.content, readOnly=e.readOnly, kind=e.kind}
end
local function Text(db, c)
    local g=type(db)=="table" and rawget(db,"global")
    local l=type(g)=="table" and rawget(g,"UserLayouts")
    local r=type(l)=="table" and rawget(l,c.layoutId)
    local p=type(r)=="table" and rawget(r,"payload")
    local u=type(p)=="table" and rawget(p,"Units")
    local unit=type(u)=="table" and rawget(u,c.unitKey)
    local ts=type(unit)=="table" and rawget(unit,"Texts")
    return type(ts)=="table" and rawget(ts,c.textKey) or nil
end
local function Current(s)
    if not s or s.invalidated then return false end
    local char = type(s.db) == "table" and rawget(s.db, "char")
    if type(char) ~= "table" or rawget(char, "activeLayoutId") ~= s.activeLayoutId then return false end
    if s.kind=="new-template" then return true end
    if s.kind=="shared-template" then
        local r=Record(s.db,s.templateId)
        return r and (not s.expected or (r.name==s.expected.name and r.content==s.expected.content)) or false
    end
    local t=Text(s.db,s.context)
    return t==s.text and (rawget(t,"templateId")==s.templateId)
end
local function Renew(s) s.draftToken={} end
local function Snap(s,c)
    return Context.Snapshot(c,s.db,s.activeLayoutId)
end
local function Open(request,db,active)
    if type(request)~="table" or request.entity~=true then return nil,"entity_path_not_selected" end
    db=db or ns.db; active=active or (ns.ActiveLayoutResolver and ns.ActiveLayoutResolver.GetStoredActiveLayoutId and ns.ActiveLayoutResolver.GetStoredActiveLayoutId(db))
    local c,err=Context.Snapshot(request,db,active)
    if not c then return nil,err end
    local s={db=db,activeLayoutId=active,context=c,kind=c.kind,draftToken={},returnContext=c.returnContext}
    if c.kind=="object" then
        s.text=Text(db,c); if not s.text then return nil,"text_element_not_found" end
        s.templateId=rawget(s.text,"templateId")
        if s.templateId then
            local r,e=Record(db,s.templateId); if not r then return nil,e end
            s.name,s.content,s.readOnly=r.name,r.content,r.readOnly;s.expected=Copy(r)
        else
            s.name,s.content,s.readOnly="",rawget(s.text,"tag") or "",false
        end
    elseif c.kind=="shared-template" then
        s.templateId=c.templateId
        local r,e=Record(db,s.templateId); if not r then return nil,e end
        s.name,s.content,s.readOnly=r.name,r.content,r.readOnly;s.expected=Copy(r)
    else s.name,s.content,s.readOnly="","",false end
    s.baseline={name=s.name,content=s.content}; s.nameDirty=false;s.contentDirty=false
    return s
end
local function PublishReturn(session, result)
    local returnContext = session and session.returnContext
    local libraryWindow = ns.GUI and ns.GUI.Editor and ns.GUI.Editor.TextTemplateLibraryWindow
    if libraryWindow and type(libraryWindow.NotifyEntityReturn) == "function" then
        local accepted, reopened = libraryWindow.NotifyEntityReturn(returnContext, result)
        return accepted == true and reopened == true
    end
    return false
end

function R2.SetIdGenerator(generator) R2.idGenerator=generator end
function R2.IsRequest(r) return type(r)=="table" and r.entity==true end
function R2.Open(r,db,active) return Open(r,db,active) end
function R2.Capture(s)
    return {session=s,token=s.draftToken,context=s.context,content=s.content,name=s.name,
        expected=Copy(s.expected),templateId=s.templateId}
end
function R2.Valid(s,a)
    return type(s)=="table" and type(a)=="table" and a.session==s and a.token==s.draftToken
        and a.context==s.context and a.content==s.content and a.name==s.name
        and a.templateId==s.templateId and Current(s)
end
function R2.SetContent(s,v)
    if not Current(s) then return false,"stale_context" end
    if type(v)~="string" then return false,"invalid_template_content" end
    if s.readOnly then return false,"read_only" end
    if s.nameDirty and s.kind=="shared-template" then return false,"name_unconfirmed" end
    s.content=v;s.contentDirty=v~=s.baseline.content;Renew(s);return true,s.contentDirty
end
function R2.SetName(s,v)
    if not Current(s) then return false,"stale_context" end
    if type(v)~="string" then return false,"invalid_template_name" end
    if s.readOnly then return false,"read_only" end
    s.name=v;s.nameDirty=v~=s.baseline.name;Renew(s);return true,s.nameDirty
end
function R2.IsDirty(s) return s and (s.nameDirty or s.contentDirty) or false end
function R2.Usage(s)
    if not s.templateId then return {main=0,state=0,disabled=0,references={}} end
    local g=rawget(s.db,"global") or {};local refs=Library.Entity.Usage(g.UserLayouts or {},s.db,s.templateId) or {}
    local u={main=0,state=0,disabled=0,references=refs}
    for _,r in ipairs(refs) do if r.referenceKind=="state" then u.state=u.state+1 else u.main=u.main+1 end;if r.enabled==false then u.disabled=u.disabled+1 end end
    return u
end
function R2.List(db) return Library.Entity.List(db or ns.db) end
function R2.Selection(db,id) return Library.Entity.Selection(db or ns.db,id) end
function R2.Save(s)
    if not Current(s) then return {ok=false,errorCode="invalid_context"} end
    if s.nameDirty and s.kind=="shared-template" then return {ok=false,errorCode="name_unconfirmed"} end
    if s.kind=="object" and not s.templateId then
        if s.content==s.baseline.content then return {ok=true,changed=false} end
        local result=Entity.SetLocalMainContent({db=s.db,expectedLayoutId=s.activeLayoutId,expectedTextConfig=s.text},s.context.unitKey,s.context.textKey,s.content)
        if not result or not result.ok then return result or {ok=false,errorCode="operation_failed"} end
        s.baseline.content=s.content;s.contentDirty=false;Renew(s);return {ok=true,changed=result.changed,refresh=result.changed}
    elseif s.kind=="object" then
        if s.content==s.baseline.content then return {ok=true,changed=false} end
        return {ok=true,changed=false,decisionRequired=true}
    elseif s.kind=="shared-template" then
        if s.readOnly then return {ok=false,errorCode="read_only"} end
        if s.content==s.baseline.content then return {ok=true,changed=false} end
        local result=Entity.UpdateTemplate(s.db,s.templateId,s.expected,s.content)
        if not result or not result.ok then return result or {ok=false,errorCode="operation_failed"} end
        s.expected.content=s.content;s.baseline.content=s.content;s.contentDirty=false;Renew(s);return {ok=true,changed=result.changed,refresh=true}
    end
    if not s.name:find("%S") then return {ok=false,errorCode="invalid_template_name"} end
    if s.content=="" then return {ok=false,errorCode="invalid_template_content"} end
    local result=Entity.CreateTemplate(s.db,s.name,s.content,R2.idGenerator)
    if not result or not result.ok then return result or {ok=false,errorCode="operation_failed"} end
    local c,e=Snap(s,{entity=true,kind="shared-template",layoutId=s.activeLayoutId,templateId=result.templateId,returnContext=s.returnContext})
    if not c then return {ok=false,errorCode=e} end
    s.context=c;s.kind=c.kind;s.templateId=result.templateId;s.expected=Copy({name=s.name,content=s.content})
    s.baseline={name=s.name,content=s.content};s.nameDirty=false;s.contentDirty=false;Renew(s)
    local returnedToPicker = PublishReturn(s,result)
    if returnedToPicker and Builder.HideWindow then Builder.HideWindow() end
    return {ok=true,changed=true,created=true,templateId=result.templateId,refresh=true}
end
function R2.Decide(s,decision,capture)
    if not R2.Valid(s,capture) or s.kind~="object" or not s.templateId then return {ok=false,errorCode="stale_context"} end
    if decision=="all" then
        if s.readOnly then return {ok=false,errorCode="read_only"} end
        local r=Entity.UpdateTemplate(s.db,s.templateId,s.expected,s.content);if not r or not r.ok then return r end
        s.expected.content=s.content;s.baseline.content=s.content;s.contentDirty=false;Renew(s);return {ok=true,changed=r.changed,refresh=true}
    elseif decision=="copy" then
        local target={db=s.db,expectedLayoutId=s.activeLayoutId,expectedTextConfig=s.text}
        local r=Entity.ForkMainTemplate(target,s.context.unitKey,s.context.textKey,s.templateId,s.expected,s.content,R2.idGenerator,s.readOnly==true)
        if not r or not r.ok then return r end
        local nc,ne=Snap(s,{entity=true,kind="object",layoutId=s.activeLayoutId,unitKey=s.context.unitKey,textKey=s.context.textKey,returnContext=s.returnContext})
        if not nc then return {ok=false,errorCode=ne} end
        s.context=nc;s.templateId=r.templateId;s.text=Text(s.db,s.context);local rec=Record(s.db,s.templateId)
        s.name,s.content,s.readOnly,s.expected=rec.name,rec.content,rec.readOnly,Copy(rec);s.baseline={name=s.name,content=s.content};s.contentDirty=false;Renew(s)
        return {ok=true,changed=r.changed,forked=true,templateId=r.templateId,refresh=true}
    end
    return {ok=false,errorCode="invalid_decision"}
end
function R2.Rename(s)
    if not Current(s) then return {ok=false,errorCode="stale_context"} end
    if s.kind~="shared-template" or not s.templateId then return {ok=false,errorCode="invalid_context"} end
    if s.readOnly then return {ok=false,errorCode="read_only"} end
    if s.name==s.baseline.name then return {ok=true,changed=false} end
    local r=Entity.RenameTemplate(s.db,s.templateId,s.expected,s.name);if not r or not r.ok then return r end
    s.expected.name=s.name;s.baseline.name=s.name;s.nameDirty=false;Renew(s);return {ok=true,changed=r.changed,refresh=true}
end
function R2.Delete(s)
    if not Current(s) then return {ok=false,errorCode="stale_context"} end
    if s.kind~="shared-template" or not s.templateId then return {ok=false,errorCode="invalid_context"} end
    if s.readOnly then return {ok=false,errorCode="read_only"} end
    if R2.IsDirty(s) then return {ok=false,errorCode="dirty_draft"} end
    local r=Entity.DeleteTemplate(s.db,s.templateId,s.expected);if not r or not r.ok then return r end
    local n,e=Open({entity=true,kind="new-template",layoutId=s.activeLayoutId,returnContext=s.returnContext},s.db,s.activeLayoutId)
    if not n then return {ok=false,errorCode=e} end
    return {ok=true,changed=true,session=n,refresh=true}
end
function R2.Copy(s)
    if not Current(s) then return {ok=false,errorCode="stale_context"} end
    if s.kind~="shared-template" or not s.templateId then return {ok=false,errorCode="invalid_context"} end
    local r=Entity.CopyTemplate(s.db,s.templateId,R2.idGenerator);if not r or not r.ok then return r end
    local n,e=Open({entity=true,kind="shared-template",layoutId=s.activeLayoutId,templateId=r.templateId,returnContext=s.returnContext},s.db,s.activeLayoutId)
    if not n then return {ok=false,errorCode=e} end
    local returnedToPicker = PublishReturn(s,{templateId=r.templateId,changed=true})
    if returnedToPicker and Builder.HideWindow then Builder.HideWindow() end
    return {ok=true,changed=true,copied=true,templateId=r.templateId,session=n,refresh=true}
end


-- Canonical Entity window; reuses only the existing presentation factory.
local r2Window
local r2Decision
local r2CloseDialog
local r2DeleteDialog
local r2Closing = false
local consumerContext
local consumerClosing = false
local CloseConsumer
local OpenConsumerDialog
local function InvalidateSession(context)
    if context and context.r2Session then
        context.r2Session.invalidated = true
        Renew(context.r2Session)
        context.r2Session = nil
    end
end
local function RefreshResult(result)
    if result and result.ok and result.refresh and result.changed then
        if ns.RefreshAllUnitFrames then ns:RefreshAllUnitFrames() end
        if ns.GUI and ns.GUI.RequestRefreshOptions then ns.GUI:RequestRefreshOptions("TextBuilder.Entity") end
        local library = ns.GUI and ns.GUI.Editor and ns.GUI.Editor.TextTemplateLibraryWindow
        if library and library.Refresh then library.Refresh() end
    end
    return result
end

local function R2Text(context, value)
    context.r2Sync = true
    context.templateEdit:SetText(value or "")
    context.r2Sync = false
end

local function R2Name(context, value)
    context.r2NameSync = true
    context.templateNameEdit:SetText(value or "")
    context.r2NameSync = false
end

local function R2Status(message)
    if ns.GUI and ns.GUI.SetStatusText then ns.GUI:SetStatusText(message or "") end
end

local function R2Refresh(context)
    local s=context and context.r2Session
    if not s then return end
    local isObject = s.kind == "object"
    local hasEntity = s.templateId ~= nil
    local rows=R2.List(s.db) or {};local list={}
    for _,row in ipairs(rows) do list[row.value]=row.label end
    context.r2ListSync=true
    context.templateSelect:SetList(list)
    context.templateSelect:SetValue(s.templateId)
    context.r2ListSync=false
    R2Text(context,s.content);R2Name(context,s.name)
    context.templateEdit:SetDisabled(s.readOnly)
    if context.templatesTitle then
        context.templatesTitle:SetText(T("INFO_TEXT_BUILDER_TEMPLATES", "Text Templates"))
    end
    if context.templateSelect.SetLabel then
        context.templateSelect:SetLabel(T("INFO_TEXT_BUILDER_SAVED_TEMPLATES", "Text Template"))
    end
    if context.templateNameEdit.SetLabel then
        context.templateNameEdit:SetLabel(T("INFO_TEXT_BUILDER_TEMPLATE_NAME", "Template Name"))
    end
    context.newTemplateButton:SetDisabled(false)
    context.saveButton:SetDisabled(s.readOnly and s.kind~="new-template" or not R2.IsDirty(s))
    context.updateTemplateButton:SetDisabled(s.kind~="shared-template" or s.readOnly or not s.nameDirty)
    context.deleteTemplateButton:SetDisabled(s.kind~="shared-template" or s.readOnly or R2.IsDirty(s))
    context.applyTemplateButton:SetDisabled(s.kind~="shared-template" or R2.IsDirty(s))
    if context.applyTemplateButton.SetText then
        context.applyTemplateButton:SetText(T("INFO_TEXT_BUILDER_APPLY_TEMPLATE", "Make a Copy"))
    end
    if context.templateOwnerLabel then
        local label=s.kind=="object" and (s.templateId and "Wiederverwendete Vorlage" or "Eigener lokaler Text")
            or s.kind=="new-template" and "Neue Entity" or (s.readOnly and "Built-in / schreibgeschützt" or "Eigene Entity")
        context.templateOwnerLabel:SetText(label)
    end
    local usage=R2.Usage(s)
    for unit,checkbox in pairs(context.usageCheckboxes or {}) do
        checkbox:SetDisabled(true);checkbox:SetValue(false)
    end
    if context.usageTitle then
        context.usageTitle:SetText(T("INFO_TEXT_BUILDER_TEMPLATE_USAGE", "Usage"))
    end
    if context.usageLead then
        context.usageLead:SetText(T("INFO_TEXT_BUILDER_USAGE_LEAD", "Used by"))
    end
    if context.usageHint then
        context.usageHint:SetText(string.format(
            T("INFO_TEXT_BUILDER_USAGE_SUMMARY", "Used by %d references across your layouts"),
            usage.main + usage.state) .. "\n" .. string.format(
            T("INFO_TEXT_BUILDER_USAGE_DETAIL", "Main: %d | State: %d | Disabled: %d"),
            usage.main, usage.state, usage.disabled))
    end
    if context.previewValue and ns.TextElementPreview then
        context.previewValue:SetText(ns.TextElementPreview.BuildTemplatePreview(s.content))
    end
    if context.window and context.window.DoLayout then context.window:DoLayout() end
end

local function R2InstallDecisionLayout()
    ns.GUI.Layouts = ns.GUI.Layouts or {}
    ns.GUI.Layouts.TextBuilder = ns.GUI.Layouts.TextBuilder or {}
    ns.GUI.Layouts.TextBuilder.SharedDecision = {
        {section="Root",properties={sectionKind="root",type="stack_block",variant="window_content"},items={}},
        {section="Message",properties={parentSection="Root",sectionKind="section",type="stack_block",variant="section_stack"},items={
            {id="message",widget="label",text=T("INFO_TEXT_BUILDER_SHARED_DECISION_MESSAGE", "This template is used by other texts. What should be saved?")}}},
        {section="Actions",properties={parentSection="Root",sectionKind="widget_group",type="action_row",variant="triple_button"},items={
            {id="all",widget="button",text=T("INFO_TEXT_BUILDER_SHARED_UPDATE_ALL", "Change Template Everywhere")},
            {id="copy",widget="button",text=T("INFO_TEXT_BUILDER_SHARED_FORK", "Change Only This Text")},
            {id="cancel",widget="button",text=T("INFO_COMMON_CANCEL", "Cancel")}}},
    }
end

local function OpenR2Decision(context, closeAfter)
    R2InstallDecisionLayout()
    local openDialog=Builder.OpenLayoutDialog
    if not openDialog then R2Status("Shared-Decision-Dialog nicht verfügbar");return end
    local s=context.r2Session;local capture=R2.Capture(s);s.pendingCapture=capture
    r2Decision=openDialog(r2Decision,ns.GUI.Layouts.TextBuilder.SharedDecision,{
        title="Shared-Text speichern",windowWidth=560,windowHeight=230})
    if not r2Decision then return end
    local function Decide(which)
        if not R2.Valid(s,capture) then return end
        local result=RefreshResult(R2.Decide(s,which,capture))
        if context.r2Session ~= s or not Current(s) then return end
        if not result or not result.ok then R2Status("Speichern fehlgeschlagen");return end
        r2Decision.window:Hide();R2Refresh(context);R2Status("Gespeichert")
        if closeAfter then InvalidateSession(context);r2Closing=true;context.window:Hide();r2Closing=false end
    end
    r2Decision.widgets.all:SetCallback("OnClick",function() Decide("all") end)
    r2Decision.widgets.copy:SetCallback("OnClick",function() Decide("copy") end)
    r2Decision.widgets.cancel:SetCallback("OnClick",function() r2Decision.window:Hide() end)
end

local function BindR2Window(context, session)
    context.r2Session=session;r2Window=context
    context.templateEdit:SetCallback("OnTextChanged",function(_,_,value)
        if context.r2Sync then return end
        local ok,reason=R2.SetContent(session,value or "")
        if not ok then R2Status(reason=="name_unconfirmed" and "Rename zuerst bestätigen" or "Text nicht editierbar") end
        R2Refresh(context)
    end)
    context.templateNameEdit:SetCallback("OnTextChanged",function(_,_,value)
        if context.r2NameSync then return end
        local ok=R2.SetName(session,value or "")
        if not ok then R2Status("Name nicht editierbar") end
        R2Refresh(context)
    end)
    context.templateSelect:SetCallback("OnValueChanged",function(_,_,id)
        if session.kind == "object" then return end
        if context.r2ListSync or id==session.templateId then return end
        if R2.IsDirty(session) then R2Status("Ungespeicherte Entity-Änderungen");R2Refresh(context);return end
        local next,reason=R2.Open({entity=true,kind="shared-template",layoutId=session.activeLayoutId,templateId=id},session.db,session.activeLayoutId)
        if not next then R2Status("Auswahl ungültig: "..tostring(reason));return end
        InvalidateSession(context);context.r2Session=next;session=next;R2Refresh(context)
    end)
    context.newTemplateButton:SetCallback("OnClick",function()
        if R2.IsDirty(session) then R2Status("Unsaved changes");return end
        local next,reason=R2.Open({entity=true,kind="new-template",layoutId=session.activeLayoutId,returnContext=session.returnContext},session.db,session.activeLayoutId)
        if not next then R2Status(tostring(reason));return end
        InvalidateSession(context);context.r2Session=next;session=next;R2Refresh(context)
    end)
    context.saveButton:SetCallback("OnClick",function()
        local result=RefreshResult(R2.Save(session))
        if result and result.decisionRequired then OpenR2Decision(context,false)
        elseif result and result.ok then R2Refresh(context);R2Status("Gespeichert")
        else R2Status("Speichern fehlgeschlagen") end
    end)
    context.updateTemplateButton:SetCallback("OnClick",function()
        local result=RefreshResult(R2.Rename(session))
        if result and result.ok then R2Refresh(context);R2Status("Gespeichert") else R2Status("Rename fehlgeschlagen") end
    end)
    context.deleteTemplateButton:SetCallback("OnClick",function() R2.OpenDeleteConfirm(context) end)
    context.applyTemplateButton:SetCallback("OnClick",function()
        local result=RefreshResult(R2.Copy(session))
        if context.r2Session ~= session or not Current(session) then return end
        if result and result.ok then
            if result.session then
                InvalidateSession(context);session=result.session;context.r2Session=session
            end
            R2Refresh(context);R2Status("Kopie erstellt")
        else R2Status("Kopie fehlgeschlagen") end
    end)
    R2Refresh(context)
end

local function OpenR2CloseConfirm(context)
    local openDialog=Builder.OpenLayoutDialog
    local layout=ns.GUI.Layouts and ns.GUI.Layouts.TextBuilder and ns.GUI.Layouts.TextBuilder.UnsavedCloseConfirm
    if not openDialog or not layout then return end
    local s=context.r2Session;local capture=R2.Capture(s)
    r2CloseDialog=openDialog(r2CloseDialog,layout,{title=context.consumer and T("INFO_TEXT_UNSAVED_TITLE", "Unsaved Changes") or "Ungespeicherte Entity-Änderungen",
        windowWidth=560,windowHeight=230,state={message=context.consumer and T("INFO_TEXT_UNSAVED_CLOSE_PROMPT", "This text has unsaved changes. Do you want to save them before closing?") or nil}})
    if not r2CloseDialog then return end
    r2CloseDialog.saveCloseButton:SetCallback("OnClick",function()
        if not R2.Valid(s,capture) then return end
        local result=RefreshResult(R2.Save(s))
        if context.r2Session ~= s or not Current(s) then return end
        if result and result.decisionRequired then
            r2CloseDialog.window:Hide();OpenR2Decision(context,true)
        elseif result and result.ok then
            r2CloseDialog.window:Hide()
            if context.consumer then
                CloseConsumer(context)
            else
                InvalidateSession(context);r2Closing=true;context.window:Hide();r2Closing=false
            end
        end
    end)
    r2CloseDialog.discardCloseButton:SetCallback("OnClick",function()
        if not R2.Valid(s,capture) then return end
        r2CloseDialog.window:Hide()
        if context.consumer then
            CloseConsumer(context)
        else
            InvalidateSession(context);r2Closing=true;context.window:Hide();r2Closing=false;r2Window=nil
        end
    end)
    r2CloseDialog.cancelButton:SetCallback("OnClick",function() r2CloseDialog.window:Hide();context.window:Show() end)
end

local function ConsumerText(text, role, size, height)
    local label = FormWidgets.CreateBodyText
        and FormWidgets.CreateBodyText(text or "", role or "label", size or 11, nil, nil, true)
        or AceGUI:Create("Label")
    label:SetText(text or "")
    label:SetFullWidth(true)
    if height then label:SetHeight(height) end
    return label
end

local function ConsumerStatus(context, message, role)
    if context and context.status then
        context.status:SetText(message or " ")
        if FormWidgets.ApplyTextStyle and context.status.label then
            FormWidgets.ApplyTextStyle(context.status.label, role == "error" and "statusError" or "help", 10, 1)
        end
    end
end

local function ConsumerRefresh(context)
    local session = context and context.r2Session
    if not session then return end
    if context.nameEdit then
        context.nameSync = true
        context.nameEdit:SetText(session.name or "")
        context.nameSync = false
    end
    context.contentSync = true
    context.contentEdit:SetText(session.content or "")
    context.contentSync = false
    context.preview:SetText(ns.TextElementPreview and ns.TextElementPreview.BuildTemplatePreview(session.content or "") or session.content or "")
    local valid = session.kind == "new-template"
        and type(session.name) == "string" and session.name:find("%S")
        and type(session.content) == "string" and session.content ~= ""
        or session.kind == "shared-template" and not session.readOnly
        or session.kind == "object" and session.templateId == nil
    context.dialog.primaryButton:SetDisabled(not valid)
end

local function ConsumerInsert(context, token)
    local session = context and context.r2Session
    if type(token) ~= "string" or not session or not R2.Valid(session, context.tagCapture) then
        return false
    end
    local edit = context.contentEdit.editbox
    local cursor = edit and edit.GetCursorPosition and edit:GetCursorPosition() or #(session.content or "")
    cursor = math.max(0, math.min(cursor, #(session.content or "")))
    local value = (session.content or ""):sub(1, cursor) .. token .. (session.content or ""):sub(cursor + 1)
    local ok = R2.SetContent(session, value)
    if not ok then return false end
    ConsumerRefresh(context)
    if edit and edit.SetCursorPosition then edit:SetCursorPosition(cursor + #token) end
    return true
end

CloseConsumer = function(context)
    if not context or consumerContext ~= context or context.released then return end
    local returnManager = context.returnManager == true
    local selectedTemplateId = context.r2Session and context.r2Session.templateId
    context.released = true
    consumerClosing = true
    InvalidateSession(context)
    context.r2Session = nil
    consumerContext = nil
    if context.window and not context.window.isQueuedForRelease then
        AceGUI:Release(context.window)
    end
    consumerClosing = false
    if returnManager then
        local library = ns.GUI and ns.GUI.Editor and ns.GUI.Editor.TextTemplateLibraryWindow
        if library and library.ShowManager then library.ShowManager(selectedTemplateId) end
    end
end

local function CancelConsumer(context)
    if not context or context.released or not context.r2Session then return end
    if R2.IsDirty(context.r2Session) then
        OpenR2CloseConfirm(context)
    else
        CloseConsumer(context)
    end
end

OpenConsumerDialog = function(session, mode, returnManager)
    if consumerContext and consumerContext.dialog and consumerContext.dialog.window.frame:IsShown() then
        return false, "unsaved-changes"
    end
    local isNew = mode == "new-template"
    local isTemplateEdit = mode == "edit-template"
    local dialog = FormWidgets.CreateCompactFormDialog and FormWidgets.CreateCompactFormDialog({
        title = isNew and T("INFO_TEXT_NEW_TEMPLATE_TITLE", "New Template")
            or isTemplateEdit and T("INFO_TEXT_MANAGER_EDIT", "Edit")
            or T("INFO_TEXT_EDIT_TEXT_TITLE", "Edit Text"),
        description = isNew and T("INFO_TEXT_NEW_TEMPLATE_DESCRIPTION", "Create a text template.")
            or isTemplateEdit and T("INFO_TEXT_MANAGER_EDIT_DESCRIPTION", "Edit this template.")
            or T("INFO_TEXT_EDIT_TEXT_DESCRIPTION", "Edit this local text."),
        width = 520,
        height = isNew and 340 or 430,
        formContentHeight = isNew and 276 or 366,
        bodyLayout = "List",
        contentRoot = true,
    }) or nil
    if not dialog then return false, "consumer_dialog_unavailable" end

    local context = {dialog = dialog, window = dialog.window, r2Session = session, consumer = true, returnManager = returnManager == true}
    local body = dialog.body
    body:ReleaseChildren()
    body:SetLayout("List")

    if isNew then
        local nameEdit = AceGUI:Create("EditBox")
        nameEdit:SetLabel(T("INFO_TEXT_TEMPLATE_NAME", "Template Name"))
        nameEdit:SetFullWidth(true)
        context.nameEdit = nameEdit
        body:AddChild(nameEdit)
    end

    local contentEdit = AceGUI:Create("EditBox")
    contentEdit:SetLabel(T("INFO_TEXT_EXPRESSION", "Expression"))
    contentEdit:SetFullWidth(true)
    context.contentEdit = contentEdit
    body:AddChild(contentEdit)

    local tagButton = FormWidgets.CreateActionButton and FormWidgets.CreateActionButton(
        T("INFO_TEXT_BUILDER_ADD_TAG", "+ Add Tag"), "secondary", 180, false) or AceGUI:Create("Button")
    tagButton:SetText(T("INFO_TEXT_BUILDER_ADD_TAG", "+ Add Tag"))
    tagButton:SetFullWidth(false)
    tagButton:SetWidth(180)
    context.tagButton = tagButton
    body:AddChild(tagButton)

    local previewSurface = CreateResultPanel(body)
    if not previewSurface then
        AceGUI:Release(dialog.window)
        return false, "result_panel_unavailable"
    end
    previewSurface:SetFullWidth(true)
    local preview = ConsumerText(" ", "highlight", 16, 94)
    context.preview = preview
    context.previewSurface = previewSurface
    previewSurface:AddChild(ConsumerText(T("INFO_TEXT_BUILDER_PREVIEW", "Preview"), "sectionHeader", 11, 18))
    previewSurface:AddChild(preview)
    body:AddChild(previewSurface)

    local status = ConsumerText(" ", "help", 10, 18)
    context.status = status
    body:AddChild(status)

    local actions = AceGUI:Create("SimpleGroup")
    actions:SetLayout("Flow")
    actions:SetFullWidth(true)
    actions:SetHeight(30)
    context.actionContainer = actions
    body:AddChild(actions)
    dialog:SetActions({
        primary = {text = isNew and T("INFO_TEXT_CREATE", "Create") or T("INFO_TEXT_SAVE", "Save"), role = "primary_action", width = 110,
            onClick = function()
                local result = RefreshResult(R2.Save(session))
                if not result or not result.ok then
                    ConsumerStatus(context, T("INFO_TEXT_STATUS_SAVE_FAILED", "Could not save the text."), "error")
                    return
                end
                CloseConsumer(context)
            end},
        cancel = {text = T("INFO_COMMON_CANCEL", "Cancel"), role = "utility", width = 100,
            onClick = function() CancelConsumer(context) end},
    }, actions)

    if context.nameEdit then
        context.nameEdit:SetCallback("OnTextChanged", function(_, _, value)
            if context.nameSync then return end
            local ok = R2.SetName(session, value or "")
            if not ok then ConsumerStatus(context, T("INFO_TEXT_STATUS_INVALID_NAME", "Enter a template name."), "error") end
            ConsumerRefresh(context)
        end)
    end
    contentEdit:SetCallback("OnTextChanged", function(_, _, value)
        if context.contentSync then return end
        local ok = R2.SetContent(session, value or "")
        if not ok then ConsumerStatus(context, T("INFO_TEXT_STATUS_EDIT_FAILED", "This text cannot be edited."), "error") end
        ConsumerRefresh(context)
    end)
    tagButton:SetCallback("OnClick", function()
        local tags = ns.GUI and ns.GUI.Pages and ns.GUI.Pages.TagLibrary
        if not tags or not tags.Open then return end
        context.tagCapture = R2.Capture(session)
        tags.Open({owner = "TextBuilder", onApply = function(token)
            return ConsumerInsert(context, token)
        end})
    end)
    dialog.window:SetCallback("OnClose", function()
        if consumerClosing or consumerContext ~= context or context.released then return end
        if not context.r2Session then
            CloseConsumer(context)
            return
        end
        CancelConsumer(context)
    end)
    consumerContext = context
    ConsumerRefresh(context)
    dialog:Show()
    return true
end

function R2.OpenTemplateEditor(templateId, returnManager)
    local active = ns.ActiveLayoutResolver.GetStoredActiveLayoutId(ns.db)
    local session, reason = R2.Open({entity=true, kind="shared-template", layoutId=active, templateId=templateId}, ns.db, active)
    if not session then return false, reason end
    if returnManager then
        local library = ns.GUI and ns.GUI.Editor and ns.GUI.Editor.TextTemplateLibraryWindow
        if library and library.HideManager then library.HideManager() end
    end
    return OpenConsumerDialog(session, "edit-template", returnManager)
end

function R2.OpenWindow(deps, request)
    if r2Window and R2.IsDirty(r2Window.r2Session) then return false, "unsaved-changes" end
    local active = ns.ActiveLayoutResolver.GetStoredActiveLayoutId(ns.db)
    local explicitRequest = request ~= nil
    local returnManager = type(request) == "table" and request.managerReturn == true
    if not explicitRequest then
        local library = ns.GUI and ns.GUI.Editor and ns.GUI.Editor.TextTemplateLibraryWindow
        if library and library.OpenManager then return library.OpenManager() end
    end
    request = request or {entity=true,kind="new-template",layoutId=active}
    local session, reason = R2.Open(request, ns.db)
    if not session then return false, reason end
    if consumerContext then
        if R2.IsDirty(consumerContext.r2Session) then return false, "unsaved-changes" end
        CloseConsumer(consumerContext)
    end
    if r2Window then
        local oldWindow = r2Window
        InvalidateSession(oldWindow)
        if oldWindow.window then
            r2Closing = true
            oldWindow.window:Hide()
            r2Closing = false
        end
        r2Window = nil
    end
    if explicitRequest and session.kind == "new-template" then
        if returnManager then
            local library = ns.GUI and ns.GUI.Editor and ns.GUI.Editor.TextTemplateLibraryWindow
            if library and library.HideManager then library.HideManager() end
        end
        return OpenConsumerDialog(session, "new-template", returnManager)
    end
    if explicitRequest and session.kind == "shared-template" then
        if session.readOnly then return false, "read_only" end
        if returnManager then
            local library = ns.GUI and ns.GUI.Editor and ns.GUI.Editor.TextTemplateLibraryWindow
            if library and library.HideManager then library.HideManager() end
        end
        return OpenConsumerDialog(session, "edit-template", returnManager)
    end
    if explicitRequest and session.kind == "object" and session.templateId == nil then
        return OpenConsumerDialog(session, "edit-text")
    end
    local context = Builder.CreateEntityWindow(deps)
    if not context then return false, "builder_window_unavailable" end
    InvalidateSession(context)
    BindR2Window(context,session)
    context.window:SetCallback("OnClose",function()
        if r2Closing then return end
        if R2.IsDirty(context.r2Session) then context.window:Show();OpenR2CloseConfirm(context)
        else InvalidateSession(context);r2Window=nil end
    end)
    if context.tagLibraryButton then
        context.tagLibraryButton:SetCallback("OnClick",function()
            local capture=R2.Capture(context.r2Session)
            local session=context.r2Session
            local tags=ns.GUI.Pages.TagLibrary
            if tags and tags.Open then tags.Open({owner="TextBuilder",onApply=function(token)
                if not R2.Valid(session,capture) then return false end
                return Builder.InsertTextIntoDraft(token)
            end}) end
        end)
    end
    return true
end
Builder.OpenWindow=R2.OpenWindow
Builder.HasUnsavedChanges=function()
    return (r2Window and R2.IsDirty(r2Window.r2Session))
        or (consumerContext and R2.IsDirty(consumerContext.r2Session)) or false
end
Builder.HideWindow=function()
    if consumerContext then
        CancelConsumer(consumerContext)
        return consumerContext == nil
    end
    local context=r2Window
    if not context then return true end
    if R2.IsDirty(context.r2Session) then OpenR2CloseConfirm(context);return false end
    InvalidateSession(context);r2Closing=true;context.window:Hide();r2Closing=false;r2Window=nil
    return true
end
Builder.InvalidateLayoutContext=function()
    if consumerContext then CloseConsumer(consumerContext) end
    if r2Decision then r2Decision.window:Hide() end
    if r2CloseDialog then r2CloseDialog.window:Hide() end
    if r2DeleteDialog then r2DeleteDialog.window:Hide() end
    InvalidateSession(r2Window)
    Builder.HideWindow()
end
Builder.RefreshWindowState=function()
    if consumerContext then ConsumerRefresh(consumerContext) end
    if r2Window then R2Refresh(r2Window) end
end
Builder.InsertTextIntoDraft=function(text)
    if consumerContext then
        consumerContext.tagCapture = R2.Capture(consumerContext.r2Session)
        return ConsumerInsert(consumerContext, text)
    end
    local context=r2Window;local session=context and context.r2Session
    if type(text)~="string" or not Current(session) or session.readOnly then return false end
    local edit=context.templateEdit.editbox
    local cursor=edit and edit.GetCursorPosition and edit:GetCursorPosition() or #session.content
    cursor=math.max(0,math.min(cursor,#session.content))
    local ok=R2.SetContent(session,session.content:sub(1,cursor)..text..session.content:sub(cursor+1))
    if not ok then return false end
    R2Refresh(context)
    if edit and edit.SetCursorPosition then edit:SetCursorPosition(cursor+#text) end
    return true
end

function R2.OpenDeleteConfirm(context)
    local openDialog=Builder.OpenLayoutDialog
    local layout=ns.GUI.Layouts and ns.GUI.Layouts.TextBuilder and ns.GUI.Layouts.TextBuilder.DeleteConfirm
    local s=context and context.r2Session
    if not openDialog or not layout or not s then return end
    local capture=R2.Capture(s)
    r2DeleteDialog=openDialog(r2DeleteDialog,layout,{title="Entity loeschen",windowWidth=420,windowHeight=210,
        state={message="Diese Entity wirklich loeschen? Verwendung wird vorher geprueft."}})
    if not r2DeleteDialog then return end
    r2DeleteDialog.deleteConfirmButton:SetCallback("OnClick",function()
        if not R2.Valid(s,capture) then return end
        local result=RefreshResult(R2.Delete(s))
        if context.r2Session ~= s then return end
        if not result or not result.ok then R2Status("Loeschen blockiert");return end
        r2DeleteDialog.window:Hide();InvalidateSession(context);BindR2Window(context,result.session);R2Status("Deleted")
    end)
    r2DeleteDialog.cancelButton:SetCallback("OnClick",function() r2DeleteDialog.window:Hide() end)
end

