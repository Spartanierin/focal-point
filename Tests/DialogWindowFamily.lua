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
Check(f.options,360,373)
CheckText(f.options.body,"Displays a visual alignment grid while editing frames.","help",11)
CheckText(f.options.body,"Snap frames to the screen center and other editable frames while moving them.","help",11)
CheckText(f.options.body,"Show Grid","label",12)
local optionGeometry=f.Geometry(f.options.window)
ns.GUI.Editor.OptionsDialog.Close(); ns.GUI.Editor.OptionsDialog.Open()
Equal(f.Geometry(f.options.window),optionGeometry)

-- Global mouse controls use the real shared setters in both stored modes.
-- Frame refresh is the native boundary; unit overrides and other settings stay intact.
do
    local options=ns.GUI.Editor.OptionsDialog
    local optionsContext=Upvalue(options.Open,"context")
    local savedProfile,savedBinding,savedRefresh=ns.db.profile,ns.GUI.Editor.ToolbarBinding,ns.RefreshAllUnitFrames
    Load("GUI/Editor/Toolbar/ToolbarBinding.lua")
    local binding=ns.GUI.Editor.ToolbarBinding
    local apply=binding.ApplyGlobalOptionValue
    local writes,refreshes=0,0
    binding.ApplyGlobalOptionValue=function(...)
        writes=writes+1
        return apply(...)
    end
    ns.RefreshAllUnitFrames=function(self)
        assert(self==ns)
        refreshes=refreshes+1
    end
    for _,expert in ipairs({false,true})do
        for _,mouse in ipairs({false,true})do
            for _,clickthrough in ipairs({false,true})do
                local profile={General={ExpertMode=expert,MouseEnabled=mouse,GlobalClickThrough=clickthrough,
                    ShowGrid=true,SnappingEnabled=false,ShowUnitTooltips=false,HideBlizzardFrames=false},
                    Units={player={mouseEnabled=false,clickThrough=true},target={mouseEnabled=true,clickThrough=false}}}
                ns.db.profile=profile
                local beforeWrites,beforeRefreshes=writes,refreshes
                options.Close();options.Open()
                local mouseControl=assert(optionsContext.widgets.mouseEnabled)
                local clickControl=assert(optionsContext.widgets.clickthrough)
                assert(not mouseControl.disabled and not clickControl.disabled)
                Equal(mouseControl:GetValue(),mouse);Equal(clickControl:GetValue(),clickthrough)
                Equal(writes,beforeWrites);Equal(refreshes,beforeRefreshes)
                mouseControl:Fire("OnValueChanged",not mouse)
                Equal(profile.General.MouseEnabled,not mouse);Equal(mouseControl:GetValue(),not mouse)
                Equal(writes,beforeWrites+1);Equal(refreshes,beforeRefreshes+1)
                clickControl:Fire("OnValueChanged",not clickthrough)
                Equal(profile.General.GlobalClickThrough,not clickthrough);Equal(clickControl:GetValue(),not clickthrough)
                Equal(writes,beforeWrites+2);Equal(refreshes,beforeRefreshes+2)
                options.Close();options.Open()
                assert(Upvalue(options.Open,"context")==optionsContext)
                assert(not mouseControl.disabled and not clickControl.disabled)
                Equal(mouseControl:GetValue(),not mouse);Equal(clickControl:GetValue(),not clickthrough)
                Equal(profile,{General={ExpertMode=expert,MouseEnabled=not mouse,GlobalClickThrough=not clickthrough,
                    ShowGrid=true,SnappingEnabled=false,ShowUnitTooltips=false,HideBlizzardFrames=false},
                    Units={player={mouseEnabled=false,clickThrough=true},target={mouseEnabled=true,clickThrough=false}}})
                Equal(writes,beforeWrites+2);Equal(refreshes,beforeRefreshes+2)
                Equal(f.Geometry(f.options.window),optionGeometry)
            end
        end
    end
    binding.ApplyGlobalOptionValue=apply
    ns.db.profile,ns.GUI.Editor.ToolbarBinding,ns.RefreshAllUnitFrames=savedProfile,savedBinding,savedRefresh
    options.Open()
    assert(#f.env.errors==0,table.concat(f.env.errors,"\n"))
    print("PASS: global mouse/click-through controls in 8 stored-mode/value combinations, real setters, refresh and reopen")
end

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

-- C1: one contextual global-default action; selecting a row does not activate it.
local accountDefaultId, failDefault
local setterCalls=0
ns.LayoutAssignmentService = {
    GetAccountDefaultLayoutId=function() return accountDefaultId, accountDefaultId and "ok" or "missing" end,
    SetAccountDefaultLayoutId=function(id)
        setterCalls=setterCalls+1
        if failDefault then return false,"layout-unresolvable" end
        accountDefaultId=id; return true
    end,
}
local function LayoutRow(id)
    for _,row in ipairs(context.widgets.scroll.children) do
        if row.item and row.item.id==id then return row end
    end
    error("missing layout row: "..id)
end
context.selectedLayoutId="layout:one"; manager.Refresh()
assert(context.widgets.characterStatus==nil and context.widgets.useSelectedButton==nil)
assert(context.widgets.defaultButton.frame:IsShown(), "default footer button must be explicitly shown")
assert(context.widgets.defaultButton.text:GetText()=="Set default")
local activeBefore=ns.db.char.activeLayoutId
context.widgets.defaultButton:Fire("OnClick")
assert(accountDefaultId=="layout:one" and setterCalls==1 and ns.db.char.activeLayoutId==activeBefore)
assert(context.widgets.defaultButton.text:GetText()=="Unset default")
assert(LayoutRow("layout:one").nameText:GetText()=="One")
assert(LayoutRow("layout:one").statusText:GetText():find("Account default",1,true))
LayoutRow("builtin:default"):Fire("OnClick")
assert(context.widgets.defaultButton.frame:IsShown())
assert(setterCalls==1 and accountDefaultId=="layout:one")
assert(ns.db.char.activeLayoutId==activeBefore)
assert(context.widgets.defaultButton.text:GetText()=="Set default")
LayoutRow("layout:one"):Fire("OnClick")
assert(context.widgets.defaultButton.text:GetText()=="Unset default")
assert(context.widgets.defaultButton.frame:IsShown() and setterCalls==1)
manager.Close(); manager.Open()
LayoutRow("layout:one"):Fire("OnClick")
assert(context.widgets.defaultButton.frame:IsShown())
assert(context.widgets.defaultButton.text:GetText()=="Unset default")
LayoutRow("builtin:default"):Fire("OnClick")
assert(context.widgets.defaultButton.text:GetText()=="Set default")
context.widgets.defaultButton:Fire("OnClick")
assert(accountDefaultId=="builtin:default" and ns.db.char.activeLayoutId==activeBefore)
assert(LayoutRow("layout:one").nameText:GetText()=="One")
assert(LayoutRow("builtin:default").nameText:GetText()=="Default")
assert(LayoutRow("builtin:default").statusText:GetText():find("Account default",1,true))
context.widgets.defaultButton:Fire("OnClick")
assert(accountDefaultId==nil and context.widgets.defaultButton.text:GetText()=="Set default")
assert(not LayoutRow("builtin:default").statusText:GetText():find("Account default",1,true))
assert(context.widgets.defaultButton.frame:IsShown())
assert(LayoutRow("builtin:default").nameText:GetText()=="Default")
failDefault=true; context.widgets.defaultButton:Fire("OnClick")
assert(accountDefaultId==nil and context.dialog.statusRole=="error")
failDefault=false
-- Existing footer geometry remains compact; the fourth action follows Delete for user layouts.
context.selectedLayoutId="layout:one"; manager.Refresh()
assert(context.widgets.defaultButton.frame.points.LEFT.relative==context.widgets.deleteButton.frame)

-- Manager orientation projects selection, active/default IDs and source independently.
do
    local summaries=ns.LayoutService.ListLayoutSummaries
    local activeId,defaultId,selectedId=ns.db.char.activeLayoutId,accountDefaultId,context.selectedLayoutId
    local previousTooltip,previousLocale,previousGetLocale=GameTooltip,ns.L,GetLocale
    local longName=string.rep("W",64)
    ns.LayoutService.ListLayoutSummaries=function() return {
        {id="layout:one",name=longName,source="userLayout"},
        {id="builtin:default",name="Default",source="builtin"},
    } end
    ns.db.char.activeLayoutId="builtin:default"
    accountDefaultId="builtin:default"
    context.selectedLayoutId="builtin:default"
    manager.Refresh()
    Equal(LayoutRow("builtin:default").statusText:GetText(),"Selected | Active | Account default | Read-only")
    assert(context.widgets.description.label:GetText():find("Active: Default",1,true))
    assert(not context.widgets.renameButton.frame:IsShown() and context.widgets.exportButton.disabled)
    context.widgets.copyButton:Fire("OnClick");latest.primaryButton:Fire("OnClick")
    assert(calls.copy[1]=="builtin:default" and calls.copy[3]==true)
    latest.cancelButton:Fire("OnClick")
    LayoutRow("layout:one"):Fire("OnClick")
    Equal(LayoutRow("layout:one").statusText:GetText(),"Selected")
    Equal(LayoutRow("builtin:default").statusText:GetText(),"Active | Account default | Read-only")
    assert(ns.db.char.activeLayoutId=="builtin:default" and accountDefaultId=="builtin:default")
    assert(context.widgets.selectedDescription.label:GetText():find("Selected layout: ",1,true))
    assert(not context.widgets.description.label:GetText():find("Selected",1,true))
    assert(context.widgets.description.label:GetText():find("activate via Canvas Toolbar",1,true))
    assert(not context.widgets.exportButton.disabled and not context.widgets.deleteButton.disabled)
    local tooltip={}
    function tooltip:SetOwner(owner) self.owner=owner end
    function tooltip:GetOwner() return self.owner end
    function tooltip:SetText(text) self.text=text end
    function tooltip:Show() self.shown=true end
    function tooltip:Hide() self.shown=false end
    GameTooltip=tooltip
    context.widgets.selectedDescription:Fire("OnEnter")
    assert(tooltip.shown and tooltip.text:find(longName,1,true))
    context.widgets.description:Fire("OnEnter")
    assert(tooltip.text:find("Active: Default",1,true))
    context.widgets.description:Fire("OnLeave");assert(not tooltip.shown)
    for _,locale in ipairs({"enUS","deDE"}) do
        local localized={L={}}
        GetLocale=function() return locale end
        assert(loadfile("Locales/"..locale..".lua"))("FocalPoint",localized)
        ns.L=localized.L;context.selectedLayoutId="builtin:default";manager.Refresh()
        local status=LayoutRow("builtin:default").statusText:GetText()
        for _,key in ipairs({"LAYOUT_MANAGER_SELECTED","LAYOUT_MANAGER_ACTIVE","LAYOUT_MANAGER_ACCOUNT_DEFAULT","LAYOUT_MANAGER_READ_ONLY"}) do
            assert(status:find(ns.L[key],1,true),locale.." missing state "..key)
        end
        assert(context.widgets.description.label:GetText()==string.format(ns.L.LAYOUT_MANAGER_CONTEXT,"Default"))
        assert(context.widgets.selectedDescription.label:GetText()==string.format(ns.L.LAYOUT_MANAGER_SELECTED_CONTEXT,"Default"))
        Load("GUI/Editor/LayoutManager/LayoutManagerView.lua")
        local localizedManager=ns.GUI.Editor.LayoutManager
        localizedManager.Open()
        local localizedContext=Upvalue(localizedManager.Open,"context")
        local w=localizedContext.widgets
        local originalActiveId=ns.db.char.activeLayoutId
        assert(w.importButton.frame:GetParent()==w.assignmentsButton.frame:GetParent())
        assert(w.exportButton.frame:GetParent()==w.actionContainer.content)
        assert(w.exportButton.frame:GetParent()~=w.importButton.frame:GetParent())
        assert(#w.selectionActions.children==1 and w.selectionActions.children[1]==w.selectedDescription)
        Equal(w.importButton.text:GetText(),ns.L.LAYOUT_MANAGER_IMPORT)
        Equal(w.exportButton.text:GetText(),ns.L.LAYOUT_MANAGER_EXPORT)
        assert(w.importButton.text:GetText()~=ns.L.LAYOUT_TRANSFER_IMPORT)
        local transferActions
        for _,child in ipairs(localizedContext.dialog.body.children) do
            if child.children and child.children[1]==w.importButton then
                assert(not transferActions,"Duplicate transfer action group")
                transferActions=child
            end
        end
        assert(transferActions and #transferActions.children==2 and transferActions.children[2]==w.assignmentsButton)
        localizedContext.selectedLayoutId="layout:one";accountDefaultId="layout:one"
        localizedManager.Refresh()
        local bodyWidth=570 -- width 640 minus unchanged 24 + 28 + 18 anchor insets
        local function CheckFooter()
            w.actionContainer:SetWidth(bodyWidth);w.actionContainer:DoLayout()
            local footerEnd,previous=8,nil
            for _,key in ipairs({"renameButton","copyButton","deleteButton","defaultButton"}) do
                local button=w[key]
                if button.frame:IsShown() then
                    assert(button.frame:GetWidth()>=button.text:GetStringWidth()+30,locale.." clipped "..key)
                    local point=button.frame.points.LEFT
                    assert(point.relative==(previous or w.actionContainer.frame))
                    assert(point.relativePoint==(previous and "RIGHT" or "LEFT"))
                    assert(point.x==(previous and 6 or 8) and point.y==0)
                    footerEnd=footerEnd+button.frame:GetWidth()+(previous and 6 or 0)
                    previous=button.frame
                end
            end
            local export=w.exportButton
            local point=export.frame.points.LEFT
            assert(point.relative==w.actionContainer.content and point.relativePoint=="LEFT")
            assert(point.x+export.frame:GetWidth()==bodyWidth)
            assert(-export.frame.points.TOP.y+export.frame:GetHeight()/2==w.actionContainer.frame:GetHeight()/2)
            assert(export.frame:GetWidth()>=export.text:GetStringWidth()+30)
            assert(footerEnd+8<=point.x,locale.." footer overlaps Export")
        end
        CheckFooter()
        assert(w.importButton.frame:GetWidth()+w.assignmentsButton.frame:GetWidth()+3<=bodyWidth)
        w.selectionActions:SetWidth(bodyWidth);w.selectionActions:DoLayout()
        local nameRight=w.selectedDescription.frame.points.RIGHT.x
        assert(nameRight==bodyWidth)
        assert(w.selectedDescription.label:GetStringWidth()<=nameRight)
        Equal({localizedContext.window.frame:GetWidth(),localizedContext.window.frame:GetHeight()},{640,521})
        Equal(w.scroll.frame:GetHeight(),322)
        assert(not w.exportButton.disabled)
        localizedContext.selectedLayoutId="builtin:default";localizedManager.Refresh()
        assert(w.exportButton.disabled and not w.renameButton.frame:IsShown() and not w.deleteButton.frame:IsShown())
        assert(w.copyButton.frame:GetWidth()>=w.copyButton.text:GetStringWidth()+30)
        for _,id in ipairs({"layout:one","builtin:default"}) do
            for _,isDefault in ipairs({false,true}) do
                for _,isActive in ipairs({false,true}) do
                    localizedContext.selectedLayoutId=id
                    accountDefaultId=isDefault and id or nil
                    ns.db.char.activeLayoutId=isActive and id or (id=="layout:one" and "builtin:default" or "layout:one")
                    localizedManager.Refresh()
                    CheckFooter()
                    Equal(w.exportButton.disabled,id=="builtin:default")
                    Equal(w.deleteButton.disabled,id=="builtin:default" or isActive)
                    Equal(w.copyButton.text:GetText(),ns.L[id=="builtin:default" and "LAYOUT_MANAGER_CREATE_FROM_TEMPLATE" or "LAYOUT_MANAGER_DUPLICATE"])
                    Equal(w.defaultButton.text:GetText(),ns.L[isDefault and "LAYOUT_MANAGER_UNSET_ACCOUNT_DEFAULT" or "LAYOUT_MANAGER_SET_ACCOUNT_DEFAULT"])
                    Equal(ns.db.char.activeLayoutId,isActive and id or (id=="layout:one" and "builtin:default" or "layout:one"))
                end
            end
        end
        ns.db.char.activeLayoutId=originalActiveId
        ace:Release(localizedContext.window)
        assert(w.selectedDescription.events.OnEnter==nil)
        assert(w.exportButton.events.OnClick==nil)
        ns.GUI.Editor.LayoutManager=manager
        accountDefaultId="builtin:default"
    end
    ns.L=previousLocale;GetLocale=previousGetLocale
    ns.db.char.activeLayoutId="layout:one";manager.Refresh()
    Equal(LayoutRow("layout:one").statusText:GetText(),"Active")
    Equal(LayoutRow("builtin:default").statusText:GetText(),"Selected | Account default | Read-only")
    context.widgets.description:Fire("OnEnter")
    assert(tooltip.text:find("Active: "..longName,1,true))
    -- Release the actual context label through the existing factory owner.
    Load("GUI/Editor/LayoutManager/LayoutManagerView.lua")
    local temporaryManager=ns.GUI.Editor.LayoutManager
    temporaryManager.Open()
    local temporaryContext=Upvalue(temporaryManager.Open,"context")
    local description=temporaryContext.widgets.description
    description:Fire("OnEnter");assert(tooltip.shown)
    ace:Release(temporaryContext.window)
    assert(not tooltip.shown and description.events.OnEnter==nil and description.events.OnLeave==nil)
    ns.GUI.Editor.LayoutManager=manager
    GameTooltip=previousTooltip
    ns.LayoutService.ListLayoutSummaries=summaries
    ns.db.char.activeLayoutId=activeId;accountDefaultId=defaultId;context.selectedLayoutId=selectedId
    manager.Refresh()
    print("PASS: independent selected/active/default/read-only states, live context, full-name tooltip, DE/EN, copy intent and context release")
end

-- Transfer uses the actual multiline control and release/focus callbacks.
ns.L.LAYOUT_TRANSFER_IMPORTED="Imported: %s"
local importOK=false
ns.LayoutTransfer={Export=function(id) calls.export=id; return "payload" end,
    Import=function(value) calls.import=value; if importOK then return true,"layout:one","One" end; return false,"invalid-header" end}
context.selectedLayoutId="layout:one"; manager.Refresh()
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
local specCount,currentSpec=3,1
function GetNumSpecializations() return specCount end
C_SpecializationInfo={GetSpecializationInfo=function(i) return i,"Spec "..i end}
ns.LayoutAssignmentService={GetCurrentSpecialization=function() return currentSpec end,
    GetSpecializationAssignment=function() return nil,"missing" end,
    SetSpecializationAssignment=function(spec,value) calls.assignment={spec,value}; return true end,
    EvaluateCurrentSpecializationAssignment=function(reason) calls.evaluate=reason end}
Load("GUI/Editor/LayoutAssignments/LayoutAssignmentView.lua")
local assignmentsAPI=ns.GUI.Editor.LayoutAssignments
local openAssignments=assignmentsAPI.Open
local openCalls=0
assignmentsAPI.Open=function(...)
    Equal(select("#",...),0)
    openCalls=openCalls+1
    return openAssignments(...)
end
local assignmentButton=assert(context.widgets.assignmentsButton)
Equal(assignmentButton.text:GetText(),"Specialization assignments...")
local selectedBeforeAssignments=context.selectedLayoutId
local dialogsBeforeAssignments=#created
local function CheckAssignments(dialog)
    Equal(dialog.window.frame:GetWidth(),520)
    local last=dialog.body.children[#dialog.body.children]
    local bottom=-last.frame.points.TOPLEFT.y+last.frame:GetHeight()
    Equal(dialog.window.frame:GetHeight(),57+6+bottom+8)
    assert(dialog.window.frame._fpModernNineSlice:IsShown())
    Equal(dialog.window.frame._fpModernNineSlice.testLayoutName,"ButtonFrameTemplateNoPortrait")
    assert(dialog.window.frame._fpModernPortraitBackground:IsShown())
    assert(not dialog.window.frame._fpParchmentNineSlice or not dialog.window.frame._fpParchmentNineSlice:IsShown())
    local header=dialog.body.children[3]
    Equal(header:GetUserData("table").columns[1].width,180)
    for index=3,3+specCount do
        local row=dialog.body.children[index]
        row:SetWidth(450);row:DoLayout()
        assert(#row.children==2)
        local left,right=row.children[1],row.children[2]
        Equal(left.frame.points.RIGHT.x-left.frame.points.LEFT.x,180)
        Equal(right.frame.points.RIGHT.x-right.frame.points.LEFT.x,258)
        Equal(right.frame.points.LEFT.x,192)
        assert(right.frame.points.RIGHT.x==450)
    end
end
assignmentButton:Fire("OnClick"); local assignments=latest
Equal(openCalls,1); Equal(#created,dialogsBeforeAssignments+1)
assignmentButton:Fire("OnClick")
Equal(openCalls,2); Equal(#created,dialogsBeforeAssignments+1)
Equal(context.selectedLayoutId,selectedBeforeAssignments)
assert(context.window.frame:IsShown()) -- Manager remains the return destination.
CheckAssignments(assignments)
local dropdown=assert(Find(assignments.body,"Dropdown")); dropdown:Fire("OnValueChanged","layout:one")
Equal(calls.assignment,{1,"layout:one"})
Equal(calls.evaluate,"assignment:ui")
calls.evaluate=nil; currentSpec=2
assignmentsAPI.Refresh()
dropdown=assert(Find(assignments.body,"Dropdown")); dropdown:Fire("OnValueChanged","layout:one")
Equal(calls.assignment,{1,"layout:one"}); Equal(calls.evaluate,nil)
specCount=0; ns.GUI.Editor.LayoutAssignments.Refresh()
CheckText(assignments.body,"No specializations available.","help",11)
assignmentsAPI.Close(); assert(not assignments.window.frame:IsShown())
assignmentButton:Fire("OnClick"); Equal(assignments.window.frame:GetWidth(),520)
Equal(#created,dialogsBeforeAssignments+1)
manager.Close(); manager.Open()
context.widgets.assignmentsButton:Fire("OnClick")
Equal(#created,dialogsBeforeAssignments+1)
assignmentsAPI.Open=openAssignments
do
    local oldLocale,oldGetLocale=ns.L,GetLocale
    local oldGetter=ns.LayoutAssignmentService.GetAccountDefaultLayoutId
    local oldSummaries=ns.LayoutService.ListLayoutSummaries
    local oldTooltip=GameTooltip
    local defaultId,defaultStatus=nil,"missing"
    local longDefaultName=string.rep("Long Layout ",12)
    ns.LayoutAssignmentService.GetAccountDefaultLayoutId=function(db)
        assert(db==ns.db);return defaultId,defaultStatus
    end
    ns.LayoutService.ListLayoutSummaries=function()return {
        {id="layout:one",name=longDefaultName,source="userLayout"},
        {id="builtin:default",name="Default",source="builtin"},
    }end
    GameTooltip={SetOwner=function(self,owner)self.owner=owner end,
        GetOwner=function(self)return self.owner end,
        SetText=function(self,text)self.text=text end,
        Show=function(self)self.shown=true end,Hide=function(self)self.shown=false end}
    for _,locale in ipairs({"enUS","deDE"}) do
        local localized={L={}};GetLocale=function()return locale end
        assert(loadfile("Locales/"..locale..".lua"))("FocalPoint",localized)
        ns.L=localized.L
        if locale=="deDE" then
            assert(ns.L.LAYOUT_ASSIGNMENT_FALLBACK_HINT:find("gültige Zuordnung",1,true),"damaged German assignment hint")
        end
        for _,count in ipairs({2,3,4}) do
            specCount=count
            Load("GUI/Editor/LayoutAssignments/LayoutAssignmentView.lua")
            local api=ns.GUI.Editor.LayoutAssignments
            api.Open();local dialog=latest
            CheckAssignments(dialog)
            Equal(dialog.window.titletext:GetText(),ns.L.LAYOUT_ASSIGNMENT_TITLE)
            local dropdown=assert(Find(dialog.body,"Dropdown"))
            Equal(dropdown.list["__fp_assignment_none__"],ns.L.LAYOUT_ASSIGNMENT_NONE)
            for _,case in ipairs({{status="missing",key="LAYOUT_ASSIGNMENT_DEFAULT_NONE"},
                {status="stale",key="LAYOUT_ASSIGNMENT_DEFAULT_INVALID"},
                {id="layout:one",status="ok",name=longDefaultName},
                {id="builtin:default",status="ok",name="Default"}}) do
                defaultId,defaultStatus=case.id,case.status
                api.Close();api.Open()
                local summary
                for _,child in ipairs(dialog.body.children) do
                    if child.type=="InteractiveLabel" then summary=child end
                end
                assert(summary)
                Equal(summary.label:GetText(),string.format(ns.L.LAYOUT_ASSIGNMENT_DEFAULT_CONTEXT,case.name or ns.L[case.key]))
                assert(summary.frame:GetHeight()>0 and summary.frame:GetHeight()<=24)
                summary:Fire("OnEnter")
                assert(GameTooltip.shown and GameTooltip.text==summary.label:GetText().."\n"..ns.L.LAYOUT_ASSIGNMENT_SPEC_PRIORITY)
                summary:Fire("OnLeave");assert(not GameTooltip.shown)
                for _,key in ipairs({"LAYOUT_ASSIGNMENT_FALLBACK_HINT"}) do
                    CheckText(dialog.body,ns.L[key],"help",11)
                    assert(#ns.L[key]*7<=450*3,"hint exceeds fixture three-line capacity")
                end
            end
            for _=1,20 do api.Close();api.Open();CheckAssignments(dialog) end
            currentSpec=1;calls.evaluate=nil
            dropdown=assert(Find(dialog.body,"Dropdown"))
            dropdown:Fire("OnValueChanged","__fp_assignment_none__")
            Equal(calls.assignment,{1,nil});Equal(calls.evaluate,"assignment:ui")
            Equal(dialog.body.children[3].children[2].label:GetText(),ns.L.LAYOUT_ASSIGNMENT_LAYOUT)
            local before=#created
            api.Close();api.Open();assert(#created==before)
            CheckAssignments(dialog)
            dialog.window.frame:Run("OnKeyDown","ESCAPE");assert(not dialog.window.frame:IsShown())
            api.Open();dialog.window.closebutton:Run("OnClick");assert(not dialog.window.frame:IsShown())
            ace:Release(dialog.window)
            assert(not dialog.window.frame._fpModernNineSlice:IsShown())
            assert(not dialog.window.frame._fpModernPortraitBackground:IsShown())
        end
    end
    ns.L=oldLocale;GetLocale=oldGetLocale
    ns.LayoutAssignmentService.GetAccountDefaultLayoutId=oldGetter
    ns.LayoutService.ListLayoutSummaries=oldSummaries
    GameTooltip=oldTooltip
    ns.GUI.Editor.LayoutAssignments=assignmentsAPI
end

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
Load("GUI/Helpers/FormSectionSurfaceRenderer.lua")
Load("GUI/Helpers/FormRenderer.lua")
Load("GUI/Pages/TextBuilder/TextBuilderDefinition.lua")
Load("GUI/Editor/TextTemplateLibraryWindow.lua")
local templates={}
ns.TextTemplateLibrary={Entity={List=function() return templates end}}
for _,mode in ipairs({"add","change"}) do
    for _,populated in ipairs({false,true}) do
        templates=populated and {{value="tpl:b:default-001",label="Sample",content="Sample preview",readOnly=true}} or {}
        ns.GUI.Editor.TextTemplateLibraryWindow.Open({mode=mode,unit="player",textKey="test"})
        Check(latest,700,367)
        if mode=="change" then
            assert(latest.window.titletext:GetText()=="Choose Template")
        end
        assert(Find(latest.body,"ScrollFrame"))
        CheckText(latest.body,"Templates","sectionHeader",11)
        CheckText(latest.body,"Preview","sectionHeader",11)
        if populated then
            CheckText(latest.body,"Sample","sectionHeader",14)
            CheckText(latest.body,"Details","sectionHeader",11)
            CheckText(latest.body,"Name: Sample","label",10)
            CheckText(latest.body,"Expression","label",10)
            CheckText(latest.body,"Sample preview","highlight",17)
            local pickerContext=Upvalue(ns.GUI.Editor.TextTemplateLibraryWindow.Open,"windowContext")
            local sampleBinding=pickerContext.rowBindings["entity:tpl:b:default-001"]
            assert(sampleBinding.label=="Sample | Built-in")
            assert(not sampleBinding.description and not sampleBinding.detail)
            assert(not Find(latest.body,"Label","Source"))
            assert(pickerContext.previewPanel.Variant=="result_stack")
            assert(pickerContext.previewPanel.frame._fpSectionFill)
            assert(pickerContext.previewPanel._fpSectionPadding)
            assert(pickerContext.previewPanel._fpPaddingAwareWidthWrapped)
            assert(not Find(latest.body,"Button","Edit Template"))
            assert(not Find(latest.body,"Button","View Built-in"))
        end
        latest.cancelButton:Fire("OnClick")
    end
end

-- A Change Text picker keeps the object context captured at open time. A
-- layout switch while it is open must neither retarget nor mutate either
-- layout; a fresh picker on the new layout remains usable.
local picker=ns.GUI.Editor.TextTemplateLibraryWindow
local oldDb,oldMutations=ns.db,ns.TextTemplateMutations
local oldRefresh,oldRequest=ns.RefreshUnitFrame,ns.GUI.RequestRefreshOptions
local oldSelection=ns.GUI.Editor.ObjectSelection
local textA={templateId="tpl:b:default-001"}; local textB={templateId="tpl:b:default-001"}
ns.db={char={activeLayoutId="layout:a"},global={UserLayouts={
    ["layout:a"]={payload={Units={player={Texts={x=textA}}}}},
    ["layout:b"]={payload={Units={player={Texts={x=textB}}}}},
}}}
local entityCalls={}
ns.TextTemplateMutations={Entity={AssignMainTemplate=function(context,unit,textKey,templateId)
    entityCalls[#entityCalls+1]={layoutId=context.expectedLayoutId,unitKey=unit,textKey=textKey,templateId=templateId}
    return {ok=true,changed=true,unitKey=unit,textKey=textKey}
end}}
ns.RefreshUnitFrame=function() end; ns.GUI.RequestRefreshOptions=function() end
ns.GUI.Editor.ObjectSelection={SelectObject=function() return true end}
templates={{value="tpl:b:default-001",label="Current",content="Current",readOnly=true},
    {value="tpl:b:default-002",label="Replacement",content="Replacement",readOnly=true}}
picker.Open({mode="change",unit="player",textKey="x",initialTemplateId="tpl:b:default-001"})
local pickerContext=Upvalue(picker.Open,"windowContext")
pickerContext.rowBindings["entity:tpl:b:default-002"].onSelect("entity:tpl:b:default-002")
ns.db.char.activeLayoutId="layout:b"
latest.primaryButton:Fire("OnClick")
Equal(#entityCalls,0); Equal(textA.templateId,"tpl:b:default-001"); Equal(textB.templateId,"tpl:b:default-001")
templates={{value="tpl:b:default-001",label="Current",content="Current",readOnly=true},
    {value="tpl:b:default-002",label="Replacement",content="Replacement",readOnly=true}}
picker.Open({mode="change",unit="player",textKey="x",initialTemplateId="tpl:b:default-001"})
pickerContext=Upvalue(picker.Open,"windowContext")
pickerContext.rowBindings["entity:tpl:b:default-002"].onSelect("entity:tpl:b:default-002")
latest.primaryButton:Fire("OnClick")
Equal(#entityCalls,1); Equal(entityCalls[1],{layoutId="layout:b",unitKey="player",textKey="x",templateId="tpl:b:default-002"})
ns.db,ns.TextTemplateMutations=oldDb,oldMutations
ns.RefreshUnitFrame,ns.GUI.RequestRefreshOptions=oldRefresh,oldRequest
ns.GUI.Editor.ObjectSelection=oldSelection

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
