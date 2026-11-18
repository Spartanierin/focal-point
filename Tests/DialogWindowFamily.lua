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
    local window=dialog.window
    Equal({window.frame:GetWidth(),window.frame:GetHeight()},{width,height})
    Equal({window.titletext:GetFont()},{STANDARD_TEXT_FONT,16,""})
    Equal(window.titletext.lastSetTextColor,{1,1,1,1})
    Equal({window.titletext.points.TOPLEFT.y,window.titletext.points.TOPRIGHT.y},{-15,-15})
    Equal(window.frame._fpModernPortraitBackground.lastSetColorTexture,{0,0,0,.8})
    assert(not window.frame._fpParchmentNineSlice or not window.frame._fpParchmentNineSlice:IsShown())
    Equal({window.title.points.TOPLEFT.x,window.title.points.TOPLEFT.y,
        window.title.points.BOTTOMRIGHT.x,window.title.points.BOTTOMRIGHT.y},
        {8,0,-math.max(36,window.closebutton:GetWidth()+4),-32})
    if dialog.primaryButton and dialog.cancelButton then
        local actions=dialog.primaryButton.parent
        Equal(actions,dialog.cancelButton.parent)
        Equal(actions.LayoutFunc,ace:GetLayout("Table"))
        dialog.body.content:SetWidth(width-70); dialog.body:DoLayout()
        actions.content:SetWidth(actions.frame:GetWidth()); actions:DoLayout()
        for _=1,3 do
            dialog.body:DoLayout(); actions:DoLayout()
            local primary,cancel=dialog.primaryButton.frame,dialog.cancelButton.frame
            assert(primary.points.LEFT.relative==actions.content and cancel.points.LEFT.relative==actions.content)
            Equal(primary.points.LEFT.x,0)
            Equal(cancel.points.LEFT.x+cancel:GetWidth(),actions.content:GetWidth())
        end
        local total=0
        for _,child in ipairs(dialog.body.children) do total=total+child.frame:GetHeight() end
        Equal(window.frame:GetHeight(),57+6+total)
        Equal(dialog.body.children[#dialog.body.children].frame:GetHeight(),6)
        Equal(actions.frame:GetHeight(),30)
        assert(actions.frame.points.TOPLEFT.relative==dialog.body.children[#dialog.body.children-2].frame)
        Equal(actions.frame.points.TOPLEFT.relativePoint,"BOTTOMLEFT")
    end
end
local function CheckHeaderDrag(window)
    local points=window.title.points
    assert(points.TOPLEFT.relative==window.frame and points.BOTTOMRIGHT.relative==window.frame)
    Equal({points.TOPLEFT.relativePoint,points.BOTTOMRIGHT.relativePoint},{"TOPLEFT","TOPRIGHT"})
    Equal({points.TOPLEFT.x,points.TOPLEFT.y,points.BOTTOMRIGHT.x,points.BOTTOMRIGHT.y},
        {8,0,-math.max(36,window.closebutton:GetWidth()+4),-32})
    Equal({window.closebutton.points.TOPRIGHT.x,window.closebutton.points.TOPRIGHT.y},{2,1})
end
local function CheckUnsaved(context)
    local window,root=context.window,context.groups.Root
    local buttons={context.saveCloseButton,context.discardCloseButton,context.cancelButton}
    local actions=buttons[1].parent
    Equal(actions,context.groups.ActionRow)
    Equal(actions.LayoutFunc,ace:GetLayout("Table"));Equal(#actions.children,3)
    local required=24
    for i,button in ipairs(buttons) do
        Equal(actions.children[i],button)
        Equal(button.frame:GetWidth(),button.text:GetStringWidth()+30)
        required=required+button.frame:GetWidth()
    end
    local padding=root._fpSectionPadding
    Equal(padding,{left=16,right=16,top=6,bottom=6})
    local inset=window.frame:GetWidth()-window.content:GetWidth()
    Equal(window.frame:GetWidth(),math.max(560,required+32+inset))
    -- The native double does not resolve stretched frame anchors automatically.
    actions.content:SetWidth(window.content:GetWidth()-padding.left-padding.right)
    actions:DoLayout()
    Equal(buttons[1].frame.points.LEFT.x,0)
    Equal(buttons[2].frame.points.LEFT.x,buttons[1].frame:GetWidth()+12)
    Equal(buttons[3].frame.points.LEFT.x+buttons[3].frame:GetWidth(),actions.content:GetWidth())
    assert(buttons[3].frame.points.LEFT.x>=buttons[2].frame.points.LEFT.x+buttons[2].frame:GetWidth()+12)
    Equal(actions.frame:GetHeight(),30)
    local height=padding.top+padding.bottom
    for _,child in ipairs(root.children) do height=height+child.frame:GetHeight() end
    Equal(window.frame:GetHeight(),57+height)
    Equal(root.children[2].frame:GetHeight(),12)
    for _,group in ipairs({root,context.groups.Message,actions}) do
        for _,edge in ipairs({"Top","Bottom","Left","Right"}) do
            local border=group.frame["_fpSectionBorder"..edge]
            assert(not border or not border:IsShown(),"Unsaved section border remains visible: "..edge)
        end
        assert(not group.frame._fpSectionFill or not group.frame._fpSectionFill:IsShown())
    end
    Equal({window.titletext:GetFont()},{STANDARD_TEXT_FONT,16,""})
    Equal(window.titletext.lastSetTextColor,{1,1,1,1})
    CheckHeaderDrag(window)
end

local function CheckLayoutForm(dialog,width,height)
    local w=dialog.window
    Equal({w.frame:GetWidth(),w.frame:GetHeight()},{width,height})
    Equal({w.titletext:GetFont()},{STANDARD_TEXT_FONT,16,""})
    Equal(w.titletext.lastSetTextColor,{1,1,1,1})
    Equal({w.titletext.points.TOPLEFT.x,w.titletext.points.TOPLEFT.y,
        w.titletext.points.TOPRIGHT.x,w.titletext.points.TOPRIGHT.y},{12,-15,-32,-15})
    CheckHeaderDrag(w)
    local background=assert(w.frame._fpModernPortraitBackground)
    assert(background:IsShown())
    Equal(background.lastSetColorTexture,{0,0,0,.8})
    assert(not w.frame._fpParchmentNineSlice or not w.frame._fpParchmentNineSlice:IsShown())
    assert(not w.frame._fpModernPortraitTopTileStreaks or not w.frame._fpModernPortraitTopTileStreaks:IsShown())
    Equal(dialog.body.frame:GetParent()._fpCompactDialogBodyFill.lastSetColorTexture,{0,0,0,0})
    Equal({w.content.points.TOPLEFT.x,w.content.points.TOPLEFT.y,
        w.content.points.BOTTOMRIGHT.x,w.content.points.BOTTOMRIGHT.y},{12,-32,-12,13})
    assert(not w.sizer_se:IsShown())
    local actions=dialog.body.children[#dialog.body.children-1]
    Equal(actions.LayoutFunc,ace:GetLayout("Table"))
    local columns=actions:GetUserData("table").columns
    assert(columns[1].weight==1 and columns[1].alignH=="left")
    assert(columns[2].weight==1 and columns[2].alignH=="right")
    Equal(actions.frame:GetHeight(),30)
    Equal({dialog.primaryButton.frame:GetWidth(),dialog.cancelButton.frame:GetWidth()},{120,110})
    -- Resolve stretch widths explicitly, as in the New Layout geometry check.
    for _,bodyWidth in ipairs({280,width-70}) do
        dialog.body.content:SetWidth(bodyWidth);dialog.body:DoLayout()
        actions.content:SetWidth(actions.frame:GetWidth());actions:DoLayout()
        local primary,cancel=dialog.primaryButton.frame,dialog.cancelButton.frame
        assert(primary.points.LEFT.relative==actions.content and cancel.points.LEFT.relative==actions.content)
        Equal(primary.points.LEFT.x,0)
        Equal(cancel.points.LEFT.x+cancel:GetWidth(),actions.content:GetWidth())
        assert(primary.points.LEFT.x+primary:GetWidth()<cancel.points.LEFT.x)
    end
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
f.CheckOptions(f.options)
CheckText(f.options.body,"Displays a visual alignment grid while editing frames.","parchmentSecondary",12)
CheckText(f.options.body,"Snap frames to the screen center and other editable frames while moving them.","parchmentSecondary",12)
CheckText(f.options.body,"Show Grid","identity",14)
for _,text in ipairs({"Editor","Addon"}) do
    local label=assert(Find(f.options.body,"Label",text)).label
    Equal({label:GetFont()},{STANDARD_TEXT_FONT,14,""})
    local color=NORMAL_FONT_COLOR or {r=1,g=.82,b=0}
    Equal(label.lastSetTextColor,{color.r,color.g,color.b,1})
end
local optionGeometry=f.Geometry(f.options.window)
ns.GUI.Editor.OptionsDialog.Close(); ns.GUI.Editor.OptionsDialog.Open()
Equal(f.Geometry(f.options.window),optionGeometry)
f.CheckOptions(f.options)

-- Model wrapped native text metrics; the local height must follow the measured children.
do
    local hint=assert(Find(f.options.body,"Label","Displays a visual alignment grid while editing frames."))
    local name=assert(Find(f.options.body,"Label","Show Grid"))
    local hintHeight,nameHeight=hint.label.GetStringHeight,name.label.GetStringHeight
    local originalHeight=f.options.window.frame:GetHeight()
    hint.label.GetStringHeight=function() return 56 end
    name.label.GetStringHeight=function() return 48 end
    hint:SetText(hint.label:GetText());name:SetText(name.label:GetText())
    ns.GUI.Editor.OptionsDialog.Open()
    assert(name.parent.frame:GetHeight()>=48)
    assert(f.options.window.frame:GetHeight()>originalHeight)
    f.CheckOptions(f.options)
    local children=f.options.body.children
    Equal(children[#children-1].frame:GetHeight(),8)
    Equal(children[#children].frame:GetHeight(),22)
    hint.label.GetStringHeight,name.label.GetStringHeight=hintHeight,nameHeight
    hint:SetText(hint.label:GetText());name:SetText(name.label:GetText())
    ns.GUI.Editor.OptionsDialog.Close();ns.GUI.Editor.OptionsDialog.Open()
    Equal(f.options.window.frame:GetHeight(),originalHeight)
end

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
    ns.db.profile={General={ShowGrid=false,SnappingEnabled=true,MouseEnabled=true,
        GlobalClickThrough=false,ShowUnitTooltips=true,HideBlizzardFrames=false},Minimap={hide=false}}
    local fields={showGrid="ShowGrid",snappingEnabled="SnappingEnabled",mouseEnabled="MouseEnabled",
        clickthrough="GlobalClickThrough",showUnitTooltips="ShowUnitTooltips",hideBlizzard="HideBlizzardFrames"}
    for _,checkbox in pairs(optionsContext.widgets) do
        if checkbox.type=="CheckBox" then
            local label=checkbox.parent.children[1].label
            Equal({label:GetFont()},{STANDARD_TEXT_FONT,14,""})
            local color=ns.GUI.Helpers.TextStyles.Get("identity")
            Equal(label.lastSetTextColor,{color.r,color.g,color.b,1})
        end
    end
    for _,id in ipairs({"showGrid","snappingEnabled","mouseEnabled","clickthrough","showMinimapButton","showUnitTooltips","hideBlizzard"}) do
        for _=1,2 do
            options.Open()
            local checkbox=assert(optionsContext.widgets[id])
            local function CheckAlignment()
                local left,right=checkbox.text.points.LEFT,checkbox.text.points.RIGHT
                assert(left.relative==checkbox.checkbg and right.relative==checkbox.frame)
                Equal({left.relativePoint,left.x,left.y,right.relativePoint,right.x,right.y},{"RIGHT",0,0,"RIGHT",0,0})
            end
            CheckAlignment()
            local expected=not checkbox:GetValue()
            checkbox.frame:Run("OnMouseDown","LeftButton")
            checkbox.frame:Run("OnMouseUp","LeftButton")
            Equal(checkbox:GetValue(),expected)
            Equal({checkbox.checkbg:GetWidth(),checkbox.checkbg:GetHeight(),checkbox.frame:GetHeight()},{32,32,32})
            local color=expected and (NORMAL_FONT_COLOR or {r=1,g=.82,b=0}) or ns.GUI.Helpers.TextStyles.Get("parchmentSecondary")
            Equal(checkbox.text.lastSetTextColor,{color.r,color.g,color.b,1})
            CheckAlignment()
            options.Open();CheckAlignment() -- Refresh the retained window without closing it.
            local stored
            if id=="showMinimapButton" then stored=not ns.db.profile.Minimap.hide
            else stored=ns.db.profile.General[fields[id]] end
            Equal(stored,expected)
            Equal(checkbox.text:GetText(),expected and (ns.L.OPTION_ON or "On") or (ns.L.OPTION_OFF or "Off"))
            options.Close();options.Open();Equal(checkbox:GetValue(),expected)
            CheckAlignment();f.CheckOptions(optionsContext.dialog)
            Equal(checkbox.checkbg:GetTexture(),130755)
            Equal(checkbox.check:GetTexture(),130751)
        end
    end
    local refreshOptions=Upvalue(options.Open,"Refresh")
    local setBoolean=Upvalue(refreshOptions,"SetBooleanControlValue")
    local styleCheckbox=Upvalue(setBoolean,"StyleCheckBox")
    local disabledCheckbox=ace:Create("CheckBox")
    disabledCheckbox:SetValue(true);disabledCheckbox:SetDisabled(true)
    styleCheckbox(disabledCheckbox,true)
    local disabledColor=ns.GUI.Helpers.TextStyles.Get("disabled")
    Equal(disabledCheckbox.text.lastSetTextColor,{disabledColor.r,disabledColor.g,disabledColor.b,1})
    Equal(disabledCheckbox.frame:GetHeight(),32)
    local disabledChanges=0
    disabledCheckbox:SetCallback("OnValueChanged",function() disabledChanges=disabledChanges+1 end)
    disabledCheckbox.frame:Run("OnMouseUp","LeftButton")
    Equal(disabledChanges,0);assert(disabledCheckbox:GetValue()==true)
    ace:Release(disabledCheckbox)
    local ordinaryCheckbox=ace:Create("CheckBox")
    Equal({ordinaryCheckbox.checkbg:GetWidth(),ordinaryCheckbox.checkbg:GetHeight(),ordinaryCheckbox.frame:GetHeight()},{24,24,24})
    ace:Release(ordinaryCheckbox)
    binding.ApplyGlobalOptionValue=apply
    ns.db.profile,ns.GUI.Editor.ToolbarBinding,ns.RefreshAllUnitFrames=savedProfile,savedBinding,savedRefresh
    options.Open()
    assert(#f.env.errors==0,table.concat(f.env.errors,"\n"))
    print("PASS: global mouse/click-through in 8 stored-mode/value combinations; all 7 Options controls toggle through real mouse handlers, persist and reopen")
end

-- Real manager name/confirmation consumers and their existing mutation callbacks.
local manager=ns.GUI.Editor.LayoutManager
local context=Upvalue(manager.Open,"context")
CheckHeaderDrag(context.window)
local calls={}
ns.LayoutMutations={
    RenameUserLayout=function(id,name) calls.rename={id,name}; return false,"invalid-name" end,
    CopyLayout=function(id,name,opts) calls.copy={id,name,opts.activate}; return false,"invalid-name" end,
    DeleteUserLayout=function(id) calls.delete=id; return false,"delete-failed" end,
}
context.selectedLayoutId="layout:one"; manager.Refresh()
context.widgets.renameButton:Fire("OnClick")
assert(#f.env.errors==0,table.concat(f.env.errors,"\n"))
CheckLayoutForm(latest,420,209); latest.nameEdit:SetText("Renamed"); latest.primaryButton:Fire("OnClick")
Equal(calls.rename,{"layout:one","Renamed"}); Equal(latest.statusRole,"error")
latest.cancelButton:Fire("OnClick")
context.widgets.copyButton:Fire("OnClick")
CheckLayoutForm(latest,420,209); latest.nameEdit:SetText("Copy"); latest.primaryButton:Fire("OnClick")
Equal(calls.copy,{"layout:one","Copy",false}); latest.cancelButton:Fire("OnClick")
context.activeLayoutId="layout:other"
context.widgets.deleteButton:Fire("OnClick")
Check(latest,430,139); latest.primaryButton:Fire("OnClick"); Equal(calls.delete,"layout:one")
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
    context.widgets.copyButton:Fire("OnClick");CheckLayoutForm(latest,420,209);latest.primaryButton:Fire("OnClick")
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
CheckLayoutForm(latest,560,375)
local transferEdit=assert(Find(latest.body,"MultiLineEditBox"))
local function CheckTransferGeometry(dialog,edit)
    local children=dialog.body.children
    Equal(#children,5)
    assert(children[2]==edit and children[1].children[1].type=="Label" and children[3].children[1].type=="Label")
    assert(children[1].frame:GetHeight()>=children[1].children[1].frame:GetHeight()+6)
    assert(children[3].frame:GetHeight()>=children[3].children[1].frame:GetHeight()+6)
    Equal(children[5].frame:GetHeight(),2)
    local height=0
    for _,child in ipairs(children) do height=height+child.frame:GetHeight() end
    Equal(dialog.window.frame:GetHeight(),63+height)
    assert(edit.frame:GetHeight()>=159)
end
CheckTransferGeometry(latest,transferEdit)
Equal(transferEdit.frame:GetHeight(),212)
Equal(transferEdit:GetText(),"payload"); Equal(calls.export,"layout:one")
latest.primaryButton:Fire("OnClick"); Equal(ace.FocusedWidget,transferEdit)
latest.cancelButton:Fire("OnClick"); assert(latest.released); Equal(ace.FocusedWidget,nil)
context.widgets.importButton:Fire("OnClick"); CheckLayoutForm(latest,560,375)
transferEdit=assert(Find(latest.body,"MultiLineEditBox"))
CheckTransferGeometry(latest,transferEdit)
local longTransferText=string.rep("encoded-layout-payload",4000)
transferEdit:SetText(longTransferText);transferEdit:Fire("OnTextChanged")
Equal(transferEdit:GetText(),longTransferText)
CheckTransferGeometry(latest,transferEdit)
transferEdit:SetText("bad"); transferEdit:Fire("OnTextChanged")
latest.primaryButton:Fire("OnClick"); Equal(calls.import,"bad"); Equal(latest.statusRole,"error")
do
    local description=latest.body.children[1].children[1]
    local status=latest.body.children[3].children[1]
    local descriptionHeight,statusHeight=description.label.GetStringHeight,status.label.GetStringHeight
    description.label.GetStringHeight=function() return 60 end
    status.label.GetStringHeight=function() return 160 end
    latest.primaryButton:Fire("OnClick")
    CheckTransferGeometry(latest,transferEdit)
    Equal(transferEdit.frame:GetHeight(),159)
    assert(latest.window.frame:GetHeight()>375)
    description.label.GetStringHeight,status.label.GetStringHeight=descriptionHeight,statusHeight
    transferEdit:Fire("OnTextChanged")
    CheckTransferGeometry(latest,transferEdit)
    Equal(latest.window.frame:GetHeight(),375)
end
importOK=true; latest.primaryButton:Fire("OnClick")
Equal(latest.statusRole,"success"); Equal(transferEdit:GetText(),"")
CheckTransferGeometry(latest,transferEdit)
latest.cancelButton:Fire("OnClick"); assert(latest.released)
context.widgets.exportButton:Fire("OnClick");CheckLayoutForm(latest,560,375)
CheckTransferGeometry(latest,assert(Find(latest.body,"MultiLineEditBox")))
latest.window:Hide();assert(latest.released)

-- New Layout's real form, validation and create/cancel wiring.
local ensureHost=Upvalue(ns.GUI.Editor.CanvasToolbar.UpdateGeometry,"EnsureHost")
local openNew=Upvalue(ensureHost,"OpenNewLayoutDialog")
ns.LayoutMutations.CreateUserLayoutFromSource=function(source,name) calls.new={source,name}; return false,"invalid-name" end
local function CheckNewLayoutGeometry(dialog)
    local children=dialog.body.children
    -- The fixture does not resolve widths from native stretch anchors.
    dialog.body.content:SetWidth(340);dialog.body:DoLayout()
    local actionRow=children[#children-1]
    actionRow.content:SetWidth(actionRow.frame:GetWidth());actionRow:DoLayout()
    local name,source=assert(Find(dialog.body,"EditBox")),assert(Find(dialog.body,"Dropdown"))
    for _,label in ipairs({name.label,source.label}) do
        Equal({label:GetFont()},{STANDARD_TEXT_FONT,13,""})
        local color=NORMAL_FONT_COLOR or {r=1,g=.82,b=0}
        Equal(label.lastSetTextColor,{color.r,color.g,color.b,1})
    end
    Equal(dialog.window.frame:GetWidth(),420)
    Equal(name.frame:GetHeight(),52);Equal(source.frame:GetHeight(),49)
    local fill=assert(name.frame._fpNewLayoutInputFill)
    assert(fill:IsShown() and fill.lastSetAllPoints[1]==name.editbox)
    Equal(fill.lastSetColorTexture,forms.ResolveFieldStyle("editor_inset").background)
    local valueColor=forms.ResolveFieldStyle("editor_inset").valueColor
    Equal(name.editbox.lastSetTextColor,valueColor)
    Equal(name.editbox.points.TOPLEFT.y,-26)
    assert(-name.editbox.points.TOPLEFT.y>=-name.label.points.TOPLEFT.y+name.label:GetHeight()+6)
    assert(source.frame:GetHeight()-25>=source.label:GetHeight()+6)
    local previous,contentHeight=nil,0
    for _,child in ipairs(children) do
        local point=child.frame.points.TOPLEFT
        assert(point.relative==(previous and previous.frame or dialog.body.content))
        if previous then Equal(point.relativePoint,"BOTTOMLEFT") end
        contentHeight=contentHeight+child.frame:GetHeight()
        previous=child
    end
    Equal(dialog.window.frame:GetHeight(),57+6+contentHeight)
    Equal(children[#children].frame:GetHeight(),2)
    local actions=children[#children-1]
    Equal(actions.frame:GetHeight(),30)
    local primary,cancel=dialog.primaryButton,dialog.cancelButton
    Equal({primary.frame:GetWidth(),cancel.frame:GetWidth()},{120,110})
    assert(primary.frame.points.LEFT.relative==actions.content)
    Equal(primary.frame.points.LEFT.x,0)
    assert(cancel.frame.points.LEFT.relative==actions.content)
    Equal(cancel.frame.points.LEFT.x+cancel.frame:GetWidth(),actions.content:GetWidth())
    assert(primary.frame.points.LEFT.x+primary.frame:GetWidth()<cancel.frame.points.LEFT.x)
    local control=source:GetUserData("nativePropertyDropdown")
    if control then
        Equal(control:GetHeight(),25)
        assert(control.points.LEFT.relative==source.button_cover and control.points.RIGHT.relative==source.button_cover)
    end
end
openNew()
CheckNewLayoutGeometry(latest)
Equal({latest.window.titletext:GetFont()},{STANDARD_TEXT_FONT,16,""})
Equal(latest.window.titletext.lastSetTextColor,{1,1,1,1})
local newTitlePoints=latest.window.titletext.points
Equal({newTitlePoints.TOPLEFT.x,newTitlePoints.TOPLEFT.y,newTitlePoints.TOPRIGHT.x,newTitlePoints.TOPRIGHT.y},{12,-15,-32,-15})
CheckHeaderDrag(latest.window)
local newBackground=assert(latest.window.frame._fpModernPortraitBackground)
assert(newBackground:IsShown());Equal(newBackground.lastSetColorTexture,{0,0,0,.8})
Equal({newBackground:GetDrawLayer()},{"BACKGROUND",-5})
assert(not latest.window.frame._fpParchmentNineSlice or not latest.window.frame._fpParchmentNineSlice:IsShown())
local name=assert(Find(latest.body,"EditBox")); local source=assert(Find(latest.body,"Dropdown"))
source:SetValue("layout:one")
name:SetText("New"); name:Fire("OnTextChanged","New")
latest.primaryButton:Fire("OnClick"); assert(calls.new); Equal(latest.statusRole,"error")
CheckNewLayoutGeometry(latest)
do
    local description=latest.body.children[1]
    local originalMetric=description.label.GetStringHeight
    local before=latest.window.frame:GetHeight()
    description.label.GetStringHeight=function() return 64 end
    description:SetText(description.label:GetText())
    name:Fire("OnTextChanged","New")
    CheckNewLayoutGeometry(latest)
    assert(latest.window.frame:GetHeight()>before)
    description.label.GetStringHeight=originalMetric
end
latest.cancelButton:Fire("OnClick")

-- Actual specialization table and empty state retain their calculated bounds.
local assignmentAtlasAPI,assignmentLegacyAtlasAPI=C_Texture,GetAtlasInfo
C_Texture={GetAtlasInfo=function() return {width=32,height=32} end}
-- Model only the Blizzard template/menu boundary; keep the real Assignment builder.
local assignmentCreateFrame,assignmentButtonMixin,assignmentStyleMixin=CreateFrame,DropdownButtonMixin,WowStyle1DropdownMixin
local assignmentTemplateFails=false
local assignmentPopup=CreateFrame("Frame",nil,UIParent);assignmentPopup:Hide()
DropdownButtonMixin={
    SetupMenu=function(self,generator)
        self.entries={}
        generator(self,{
            AddMenuAcquiredCallback=function(_,callback) self.acquired=callback end,
            CreateRadio=function(_,text,selected,callback)
                self.entries[#self.entries+1]={text=text,selected=selected,callback=callback}
            end,
        })
    end,
    ClearMenuState=function(self) self:CloseMenu();self.entries=nil;self.acquired=nil end,
}
WowStyle1DropdownMixin={}
function CreateFrame(kind,name,parent,template)
    if kind~="DropdownButton" then return assignmentCreateFrame(kind,name,parent,template) end
    assert(template=="WowStyle1DropdownTemplate")
    if assignmentTemplateFails then error("Unavailable dropdown template") end
    local frame=assignmentCreateFrame(kind,name,parent)
    frame.SetupMenu=DropdownButtonMixin.SetupMenu;frame.ClearMenuState=DropdownButtonMixin.ClearMenuState
    function frame:SetDefaultText(text) self.defaultText=text end
    function frame:SetEnabled(enabled) self.enabled=enabled end
    function frame:CloseMenu() self.menuOpen=false;assignmentPopup:Hide() end
    function frame:OpenMenu()
        if not self.enabled then return end
        self.menuOpen=true;self.acquired(assignmentPopup);assignmentPopup:Show()
    end
    return frame
end
local function PickAssignment(dropdown,value)
    local native=assert(dropdown:GetUserData("nativePropertyDropdown"))
    Equal(native.defaultText,dropdown.list[dropdown.value])
    native:OpenMenu();Equal(assignmentPopup.lastSetFrameStrata,{"TOOLTIP"})
    local index=0
    for _,item in dropdown.pullout:IterateItems() do
        index=index+1
        if item.userdata.value==value then
            local callback=native.entries[index].callback
            callback()
            assert(not native.menuOpen and not assignmentPopup:IsShown())
            return callback
        end
    end
    error("Missing assignment option: "..tostring(value))
end
-- The same native API boundary drives New Layout; AceGUI remains its value owner.
do
    local savedBlank,savedCreate=ns.CreateBlankLayout,ns.LayoutMutations.CreateUserLayoutFromSource
    local function SourceCallback(owner,key)
        local control=assert(owner:GetUserData("nativePropertyDropdown"))
        Equal(control.defaultText,owner.list[owner:GetValue()])
        control:OpenMenu();Equal(assignmentPopup.lastSetFrameStrata,{"TOOLTIP"})
        local index,found=0,nil
        for _,item in owner.pullout:IterateItems() do
            index=index+1
            Equal(control.entries[index].text,owner.list[item.userdata.value])
            if item.userdata.value==key then found=control.entries[index].callback end
        end
        Equal(#control.entries,index)
        return assert(found),control
    end
    for _,key in ipairs({"blank","builtin:default","layout:one"}) do
        local submitted,changes=nil,0
        ns.CreateBlankLayout=function(self,text,options)
            assert(self==ns);submitted={"blank",text,options.reason};return true,"layout:new"
        end
        ns.LayoutMutations.CreateUserLayoutFromSource=function(id,text,options)
            submitted={id,text,options.activate,options.reason};return true,"layout:new"
        end
        openNew();local dialog=latest
        CheckNewLayoutGeometry(dialog)
        local owner=assert(Find(dialog.body,"Dropdown"))
        owner:SetCallback("OnValueChanged",function(_,_,value)
            changes=changes+1;Equal(owner:GetValue(),value)
        end)
        local callback,control=SourceCallback(owner,key)
        callback();control:CloseMenu() -- Blizzard closes a radio menu after activation.
        Equal(owner:GetValue(),key);Equal(changes,1);Equal(submitted,nil)
        Equal(control.defaultText,owner.list[key])
        local edit=assert(Find(dialog.body,"EditBox"));edit:SetText("Native source")
        dialog.primaryButton:Fire("OnClick")
        if key=="blank" then Equal(submitted,{key,"Native source","create-layout"})
        else Equal(submitted,{key,"Native source",true,"create-layout-from-source"}) end
        assert(not dialog.window.frame:IsShown())
        callback();Equal(changes,1) -- Closed dialog cannot process native selection.
        openNew();local replacement=latest
        dialog.window:Show() -- Identity must also reject a replaced but shown window.
        callback();Equal(changes,1)
        dialog.window:Hide()
        local replacementOwner=assert(Find(replacement.body,"Dropdown"))
        Equal(replacementOwner:GetValue(),"blank")
        replacement.cancelButton:Fire("OnClick")
        ace:Release(dialog.window);ace:Release(replacement.window)
        assert(not control:IsShown() and control.entries==nil)
        assert(not edit.frame._fpNewLayoutInputFill:IsShown())
    end
    local nativeMixin=DropdownButtonMixin
    DropdownButtonMixin=nil
    openNew();local fallbackDialog=latest
    local fallbackOwner=assert(Find(fallbackDialog.body,"Dropdown"))
    CheckNewLayoutGeometry(fallbackDialog)
    assert(not fallbackOwner:GetUserData("nativePropertyDropdown"))
    assert(fallbackOwner.dropdown:IsShown() and fallbackOwner.button_cover:IsShown())
    fallbackOwner:SetValue("layout:one");Equal(fallbackOwner:GetValue(),"layout:one")
    fallbackDialog.cancelButton:Fire("OnClick");ace:Release(fallbackDialog.window)
    DropdownButtonMixin=nativeMixin
    ns.CreateBlankLayout,ns.LayoutMutations.CreateUserLayoutFromSource=savedBlank,savedCreate
    print("PASS: New Layout native Blank/builtin/user selection, canonical Create source, stale/closed guards, reopen/release and AceGUI fallback")
end
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
    Equal({dialog.window.titletext:GetFont()},{STANDARD_TEXT_FONT,16,""})
    local titlePoints=dialog.window.titletext.points
    Equal({titlePoints.TOPLEFT.x,titlePoints.TOPLEFT.y,titlePoints.TOPRIGHT.x,titlePoints.TOPRIGHT.y},{12,-15,-32,-15})
    CheckHeaderDrag(dialog.window)
    local last=dialog.body.children[#dialog.body.children]
    local bottom=-last.frame.points.TOPLEFT.y+last.frame:GetHeight()
    Equal(dialog.window.frame:GetHeight(),57+6+bottom+8)
    local frame=dialog.window.frame
    assert(not frame._fpModernNineSlice or not frame._fpModernNineSlice:IsShown())
    assert(not frame._fpPanelFill:IsShown())
    local editAtlases={Left="UI-Frame-DiamondMetal-CornerTopLeft",Right="UI-Frame-DiamondMetal-CornerTopRight",
        BottomLeft="UI-Frame-DiamondMetal-CornerBottomLeft",BottomRight="UI-Frame-DiamondMetal-CornerBottomRight",
        Center="_UI-Frame-DiamondMetal-EdgeTop",BottomCenter="_UI-Frame-DiamondMetal-EdgeBottom",
        SideLeft="!UI-Frame-DiamondMetal-EdgeLeft",SideRight="!UI-Frame-DiamondMetal-EdgeRight"}
    for slot,atlas in pairs(editAtlases) do
        local region=assert(frame["_fpModernTitle"..slot])
        assert(region:IsShown());Equal(region.atlas,atlas)
        Equal({region:GetDrawLayer()},{"BORDER",0})
    end
    local background=assert(frame._fpModernPortraitBackground)
    assert(background:IsShown());Equal(background:GetTexture(),nil)
    Equal(background.lastSetColorTexture,{0,0,0,.8})
    Equal({background:GetDrawLayer()},{"BACKGROUND",-5})
    assert(not frame._fpModernPortraitTopTileStreaks or not frame._fpModernPortraitTopTileStreaks:IsShown())
    assert(not dialog.window.frame._fpParchmentNineSlice or not dialog.window.frame._fpParchmentNineSlice:IsShown())
    local header=dialog.body.children[3]
    Equal(header:GetUserData("table").columns[1].width,180)
    for _,label in ipairs(header.children) do
        Equal({label.label:GetFont()},{STANDARD_TEXT_FONT,12,""})
        local color=NORMAL_FONT_COLOR or {r=1,g=.82,b=0}
        Equal(label.label.lastSetTextColor,{color.r,color.g,color.b,1})
    end
    CheckText(dialog.body,ns.L.LAYOUT_ASSIGNMENT_DESCRIPTION or "Assign layouts to your current class specializations.","parchmentSecondary",11)
    for index=3,3+specCount do
        local row=dialog.body.children[index]
        row:SetWidth(450);row:DoLayout()
        assert(#row.children==2)
        local left,right=row.children[1],row.children[2]
        if index>3 then
            Equal(row.frame:GetHeight(),42)
            Equal(left.frame:GetHeight(),32)
            CheckText(row,left.label:GetText(),"identity",14)
        end
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
assignments.window.title:Run("OnMouseDown","LeftButton")
assignments.window.title:Run("OnMouseUp","LeftButton")
assert(assignments.window.frame.lastStartMoving and assignments.window.frame.lastStopMovingOrSizing)
local dropdown=assert(Find(assignments.body,"Dropdown"))
local staleAssignment=PickAssignment(dropdown,"layout:one")
Equal(calls.assignment,{1,"layout:one"})
Equal(calls.evaluate,"assignment:ui")
calls.assignment=nil;staleAssignment();Equal(calls.assignment,nil)
calls.evaluate=nil; currentSpec=2
assignmentsAPI.Refresh()
dropdown=assert(Find(assignments.body,"Dropdown"));PickAssignment(dropdown,"layout:one")
Equal(calls.assignment,{1,"layout:one"}); Equal(calls.evaluate,nil)
local nativeAssignmentMixin=DropdownButtonMixin
DropdownButtonMixin=nil;assignmentsAPI.Refresh()
dropdown=assert(Find(assignments.body,"Dropdown"))
assert(not dropdown:GetUserData("nativePropertyDropdown") and dropdown.dropdown:IsShown() and dropdown.button_cover:IsShown())
dropdown:Fire("OnValueChanged","__fp_assignment_none__");Equal(calls.assignment,{1,nil});Equal(calls.evaluate,nil)
DropdownButtonMixin=nativeAssignmentMixin
-- Exercise unavailable XML separately from the missing API case.
assignmentTemplateFails=true
local fallback=ace:Create("Dropdown");fallback:SetList({x="X"});fallback:SetValue("x")
assert(not forms.BindNativeDropdown(fallback,{}))
assert(fallback.dropdown:IsShown() and fallback.button_cover:IsShown())
ace:Release(fallback);assignmentTemplateFails=false
assignmentsAPI.Refresh()
dropdown=assert(Find(assignments.body,"Dropdown"))
local assignmentNative=assert(dropdown:GetUserData("nativePropertyDropdown"))
local blockedAssignment=assignmentNative.entries[1].callback
calls.assignment=nil
assignmentNative:OpenMenu();dropdown:SetDisabled(true)
assert(not assignmentNative.enabled and not assignmentNative.menuOpen)
blockedAssignment();Equal(calls.assignment,nil)
dropdown:SetDisabled(false);assert(assignmentNative.enabled)
assignmentNative:OpenMenu();dropdown.frame:Hide()
assert(not assignmentNative.menuOpen and not assignmentPopup:IsShown())
dropdown.frame:Show()
assignmentNative:OpenMenu();assignmentsAPI.Close()
blockedAssignment();Equal(calls.assignment,nil)
assignmentsAPI.Open();assert(not assignmentPopup:IsShown())
specCount=0; ns.GUI.Editor.LayoutAssignments.Refresh()
CheckText(assignments.body,"No specializations available.","parchmentSecondary",11)
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
                CheckText(dialog.body,summary.label:GetText(),"parchmentSecondary",11)
                Equal(summary.label:GetText(),string.format(ns.L.LAYOUT_ASSIGNMENT_DEFAULT_CONTEXT,case.name or ns.L[case.key]))
                assert(summary.frame:GetHeight()>0 and summary.frame:GetHeight()<=24)
                summary:Fire("OnEnter")
                assert(GameTooltip.shown and GameTooltip.text==summary.label:GetText().."\n"..ns.L.LAYOUT_ASSIGNMENT_SPEC_PRIORITY)
                summary:Fire("OnLeave");assert(not GameTooltip.shown)
                for _,key in ipairs({"LAYOUT_ASSIGNMENT_FALLBACK_HINT"}) do
                    CheckText(dialog.body,ns.L[key],"parchmentSecondary",11)
                    assert(#ns.L[key]*7<=450*3,"hint exceeds fixture three-line capacity")
                end
            end
            for _=1,20 do api.Close();api.Open();CheckAssignments(dialog) end
            currentSpec=1;calls.evaluate=nil
            dropdown=assert(Find(dialog.body,"Dropdown"))
            PickAssignment(dropdown,"__fp_assignment_none__")
            Equal(calls.assignment,{1,nil});Equal(calls.evaluate,"assignment:ui")
            Equal(dialog.body.children[3].children[2].label:GetText(),ns.L.LAYOUT_ASSIGNMENT_LAYOUT)
            local before=#created
            api.Close();api.Open();assert(#created==before)
            CheckAssignments(dialog)
            dialog.window.frame:Run("OnKeyDown","ESCAPE");assert(not dialog.window.frame:IsShown())
            api.Open();dialog.window.closebutton:Run("OnClick");assert(not dialog.window.frame:IsShown())
            ace:Release(dialog.window)
            local restoredDrag=dialog.window.title.points
            local titleBackground=restoredDrag.TOPLEFT.relative
            assert(titleBackground~=dialog.window.frame and titleBackground==restoredDrag.BOTTOMRIGHT.relative)
            Equal({restoredDrag.TOPLEFT.x,restoredDrag.TOPLEFT.y,restoredDrag.BOTTOMRIGHT.x,restoredDrag.BOTTOMRIGHT.y},{0,0,0,0})
            Equal({titleBackground.points.TOPLEFT.x,titleBackground.points.TOPLEFT.y,
                titleBackground.points.BOTTOMRIGHT.x,titleBackground.points.BOTTOMRIGHT.y},{9,-6,-28,-24})
            assert(not dialog.window.frame._fpModernNineSlice or not dialog.window.frame._fpModernNineSlice:IsShown())
            assert(not dialog.window.frame._fpModernPortraitBackground:IsShown())
            for _,slot in ipairs({"Left","Right","BottomLeft","BottomRight","Center","BottomCenter","SideLeft","SideRight"}) do
                assert(not dialog.window.frame["_fpModernTitle"..slot]:IsShown())
            end
        end
    end
    ns.L=oldLocale;GetLocale=oldGetLocale
    ns.LayoutAssignmentService.GetAccountDefaultLayoutId=oldGetter
    ns.LayoutService.ListLayoutSummaries=oldSummaries
    GameTooltip=oldTooltip
    ns.GUI.Editor.LayoutAssignments=assignmentsAPI
end
C_Texture,GetAtlasInfo=assignmentAtlasAPI,assignmentLegacyAtlasAPI
CreateFrame,DropdownButtonMixin,WowStyle1DropdownMixin=assignmentCreateFrame,assignmentButtonMixin,assignmentStyleMixin

-- Actual editable-template confirmation preserves pending/ready semantics.
ns.ActiveLayoutResolver={GetStoredActiveLayoutId=function() return "builtin:default" end,
    ResolveLayout=function() return {name="Default"} end}
Load("GUI/Editor/LayoutEditWorkflow.lua")
local ready=0
ns.LayoutEditWorkflow.RequestEditableLayoutForMutation(function() ready=ready+1 end)
Check(latest,440,139); latest.cancelButton:Fire("OnClick"); Equal(ready,0)
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
for _,spec in ipairs({{"OpenDeleteTextInstanceConfirmDialog",157},{"OpenDeleteDecorationConfirmDialog",139}}) do
    local open=InspectorConfirmation(spec[1],common)
    mutationOK=false; open("player","test"); Check(latest,420,spec[2])
    if spec[2]==157 then CheckText(latest.body,"The text template is not deleted.","help",11) end
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
local pickerAtlasAPI=C_Texture
C_Texture={GetAtlasInfo=function() return {width=32,height=32} end}
for _,mode in ipairs({"add","change"}) do
    for _,populated in ipairs({false,true}) do
        templates=populated and {{value="tpl:b:default-001",label="Sample",content="Sample preview",readOnly=true}} or {}
        ns.GUI.Editor.TextTemplateLibraryWindow.Open({mode=mode,unit="player",textKey="test",targetLabel="Health Bar"})
        Equal(latest.window.frame:GetWidth(),700)
        local height=0
        for _,child in ipairs(latest.body.children) do height=height+child.frame:GetHeight() end
        Equal(latest.window.frame:GetHeight(),63+height)
        Equal({latest.window.titletext:GetFont()},{STANDARD_TEXT_FONT,16,""})
        Equal(latest.window.titletext.lastSetTextColor,{1,1,1,1})
        local titlePoints=latest.window.titletext.points
        Equal({titlePoints.TOPLEFT.x,titlePoints.TOPLEFT.y,titlePoints.TOPRIGHT.x,titlePoints.TOPRIGHT.y},{12,-15,-32,-15})
        CheckHeaderDrag(latest.window)
        local frame=latest.window.frame
        assert(not frame._fpParchmentNineSlice or not frame._fpParchmentNineSlice:IsShown())
        assert(not frame._fpPanelFill:IsShown())
        assert(frame._fpModernTitleLeft:IsShown())
        Equal(frame._fpModernTitleLeft.atlas,"UI-Frame-DiamondMetal-CornerTopLeft")
        local material=latest.shell.frame._fpCompactDialogWindowContentSurface
        assert(not material or not material:IsShown())
        if mode=="change" then
            assert(latest.window.titletext:GetText()=="Choose Template")
        end
        assert(Find(latest.body,"ScrollFrame"))
        local pickerContext=Upvalue(ns.GUI.Editor.TextTemplateLibraryWindow.Open,"windowContext")
        Equal(pickerContext.listGroup.parent.frame:GetWidth(),280)
        Equal(pickerContext.previewColumn.frame:GetWidth(),340)
        Equal(pickerContext.listGroup.frame:GetHeight(),300)
        Equal(pickerContext.previewGroup.frame:GetWidth(),328)
        assert(pickerContext.contentGroup.frame:GetHeight()>=pickerContext.previewGroup.frame:GetHeight())
        CheckText(latest.body,mode=="add" and "Add to: Health Bar" or "Choose a text template for this text object.","identity",13)
        local heading=assert(Find(latest.body,"Label","Templates"))
        Equal(select(2,heading.label:GetFont()),14)
        local color=NORMAL_FONT_COLOR or {r=1,g=.82,b=0}
        Equal(heading.label.lastSetTextColor,{color.r,color.g,color.b,1})
        Equal(pickerContext.actionContainer.LayoutFunc,ace:GetLayout("Table"))
        local columns=pickerContext.actionContainer:GetUserData("table").columns
        assert(columns[1].alignH=="left" and columns[2].alignH=="left" and columns[3].alignH=="right")
        assert(latest.primaryButton.disabled==not populated)
        assert(latest.primaryButton.text:GetText()==(mode=="add" and "Add" or "Change"))
        if populated then
            CheckText(latest.body,"Sample","identity",14)
            CheckText(latest.body,"Built-in · Read-only","parchmentSecondary",12)
            CheckText(latest.body,"Custom text","label",12)
            CheckText(latest.body,"Sample preview","identity",12)
            assert(Find(latest.body,"Label","Example Preview"))
            assert(not Find(latest.body,"Label","Name: Sample"))
            CheckText(latest.body,"Sample preview","highlight",17)
            local sampleBinding=pickerContext.rowBindings["entity:tpl:b:default-001"]
            assert(sampleBinding.label=="Sample" and sampleBinding.detail=="Built-in")
            assert(not sampleBinding.description and sampleBinding.presentation.height==30)
            local row=pickerContext.rowWidgets[sampleBinding.key]
            assert(row.frame:GetWidth()<=pickerContext.listGroup.frame:GetWidth())
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
-- Same names remain separate IDs; long expressions are retained inside a scroll viewport.
local picker=ns.GUI.Editor.TextTemplateLibraryWindow
local savedUnitFrame=ns.UnitFrame
ns.UnitFrame=ns.UnitFrame or {}
local savedTagDatabase=ns.UnitFrame.GetTagDatabase
local savedDescription=ns.L.PICKER_TEST_DESCRIPTION
ns.L.PICKER_TEST_DESCRIPTION="Canonical picker description"
ns.UnitFrame.GetTagDatabase=function() return {{token="[picker:test]",description="PICKER_TEST_DESCRIPTION"}} end
templates={}
for i=1,123 do
    templates[i]={value="tpl:u:picker-"..i,label="Same name",content=i==2 and "[picker:test]" or string.rep("long expression ",60),readOnly=i%2==0}
end
picker.Open({unit="player",targetLabel="Health Bar"})
local manyPicker=Upvalue(picker.Open,"windowContext")
assert(#manyPicker.entries==123 and #manyPicker.listGroup.children==123)
local first,middle=templates[1],templates[2]
manyPicker.rowBindings["entity:"..middle.value].onSelect("entity:"..middle.value)
assert(manyPicker.selectedTemplateKey=="entity:"..middle.value)
CheckText(latest.body,"Canonical picker description","label",12)
manyPicker.rowBindings["entity:"..first.value].onSelect("entity:"..first.value)
assert(manyPicker.selectedTemplateKey=="entity:"..first.value)
assert(manyPicker.expressionScroll.children[1].label:GetText()==first.content)
CheckText(latest.body,"User Template","parchmentSecondary",12)
for _,row in pairs(manyPicker.rowWidgets) do
    assert(row.frame:GetHeight()==30 and row.frame:GetWidth()<=manyPicker.listGroup.frame:GetWidth())
end
local last=templates[#templates]
manyPicker.listGroup:SetScroll(1000)
manyPicker.rowBindings["entity:"..last.value].onSelect("entity:"..last.value)
assert(manyPicker.selectedTemplateKey=="entity:"..last.value)
for _=1,20 do
    latest.cancelButton:Fire("OnClick")
    picker.Open({mode="change",unit="player",textKey="test",initialTemplateId=middle.value})
    local current=Upvalue(picker.Open,"windowContext")
    assert(current.selectedTemplateKey=="entity:"..middle.value and #current.listGroup.children==123)
    assert(current.previewPanel and current.expressionScroll)
end
latest.cancelButton:Fire("OnClick")
ns.UnitFrame.GetTagDatabase=savedTagDatabase
ns.UnitFrame=savedUnitFrame
ns.L.PICKER_TEST_DESCRIPTION=savedDescription
C_Texture=pickerAtlasAPI

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

-- The new confirmation presentation is explicit; the default remains unchanged.
do
    local ordinary=forms.CreateCompactConfirmation({title="Default",message="Unchanged",
        primary={text="Confirm"},cancel={text="Cancel"}})
    f.Check(ordinary)
    assert(ordinary.primaryButton.frame.points.LEFT.x>0)
    assert(not ordinary.cancelButton.frame.points.RIGHT)
    ace:Release(ordinary.window)
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
    if spec[1]=="UnsavedCloseConfirm" then
        -- This fixture has no locale prompt initially; reuse applies its explicit state text.
        Equal(ctx.window.frame:GetHeight(),112)
        Equal(openUtility(ctx,definition,opts),ctx)
    end
    assert(ctx.groups.Message and ctx.widgets.message and ctx.cancelButton)
    if spec[1]=="UnsavedCloseConfirm" then
        assert(not ctx.groups.Message.frame._fpSectionFill or not ctx.groups.Message.frame._fpSectionFill:IsShown())
        assert(not ctx.window.frame._fpParchmentNineSlice or not ctx.window.frame._fpParchmentNineSlice:IsShown())
        Equal({ctx.window.titletext:GetFont()},{STANDARD_TEXT_FONT,16,""})
        Equal(ctx.window.frame._fpModernPortraitBackground.lastSetColorTexture,{0,0,0,.8})
        assert(not ctx.widgets.title) -- the window title already identifies the decision
        CheckUnsaved(ctx)
        Equal(ctx.window.frame:GetHeight(),125)
    else
        assert(ctx.groups.Message.frame._fpSectionFill)
        assert(ctx.window.frame._fpParchmentNineSlice:IsShown())
    end
    Equal(ctx.window.frame._fpCompactFormShell,nil)
    if spec[1]~="UnsavedCloseConfirm" then
        Equal({ctx.window.frame:GetWidth(),ctx.window.frame:GetHeight()},{spec[2],spec[3]})
    end
    local bounds=f.Geometry(ctx.window); local children=#ctx.window.children; local count=f.Count()
    for _=1,10 do
        ctx.window.frame:Run("OnKeyDown","ESCAPE"); assert(not ctx.window.frame:IsShown())
        Equal(openUtility(ctx,definition,opts),ctx); assert(ctx.window.frame:IsShown())
        Equal(f.Geometry(ctx.window),bounds); Equal(#ctx.window.children,children)
    end
    Equal(f.Count(),count)
    ctx.window:Fire("OnClose"); ace:Release(ctx.window)
end

-- Real Unsaved layout in both locales: native label auto-width, wrapping and retained-window fit.
for _,values in ipairs({
    {"Unsaved Changes","This template has unsaved changes.\nDo you want to save them before closing?","Save & Close","Close Without Saving","Cancel"},
    {"Ungespeicherte ?nderungen","Diese Textvorlage enth?lt ungespeicherte ?nderungen.\nM?chtest du sie vor dem Schlie?en speichern?","Speichern & Schlie?en","Ohne Speichern schlie?en","Abbrechen"},
}) do
    local keys={"INFO_TEXT_BUILDER_UNSAVED_CLOSE_TITLE","INFO_TEXT_BUILDER_UNSAVED_CLOSE_PROMPT",
        "INFO_TEXT_BUILDER_UNSAVED_SAVE_CLOSE","INFO_TEXT_BUILDER_UNSAVED_DISCARD_CLOSE","INFO_COMMON_CANCEL"}
    local saved={}
    for i,key in ipairs(keys)do saved[i]=ns.L[key];ns.L[key]=values[i] end
    local definition=ns.GUI.Layouts.TextBuilder.UnsavedCloseConfirm
    local opts={title=values[1],windowWidth=560,windowHeight=230,state={message=values[2]}}
    local ctx=openUtility(nil,definition,opts)
    Equal(ctx.saveCloseButton.text:GetText(),values[3]);Equal(ctx.discardCloseButton.text:GetText(),values[4])
    Equal(ctx.cancelButton.text:GetText(),values[5]);Equal(ctx.widgets.message.label:GetText(),values[2])
    CheckUnsaved(ctx)
    local message=ctx.widgets.message.label
    message.GetStringHeight=function()return 28 end -- two measured lines
    Equal(openUtility(ctx,definition,opts),ctx);CheckUnsaved(ctx);Equal(ctx.window.frame:GetHeight(),139)
    local shortWidth=ctx.window.frame:GetWidth()
    for cycle=1,20 do
        local long=cycle%2==0
        message.GetStringHeight=function()return long and 84 or 28 end
        opts.state.message=long and string.rep(values[2],3) or values[2]
        Equal(openUtility(ctx,definition,opts),ctx);CheckUnsaved(ctx)
        Equal(ctx.window.frame:GetHeight(),long and 195 or 139);Equal(ctx.window.frame:GetWidth(),shortWidth)
        ctx.window.frame:Run("OnKeyDown","ENTER");assert(ctx.window.frame:IsShown())
        ctx.window.frame:Run("OnKeyDown","ESCAPE");assert(not ctx.window.frame:IsShown())
    end
    message.GetStringHeight=nil
    ace:Release(ctx.window)
    for i,key in ipairs(keys)do ns.L[key]=saved[i] end
end
print("PASS: Unsaved auto-sized EN/DE captions, unframed measured text, three stable footer slots and 20 short/long reopen cycles per locale")

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
    Equal({close.window.titletext:GetFont()},{STANDARD_TEXT_FONT,16,""})
    Equal(close.window.frame._fpModernPortraitBackground.lastSetColorTexture,{0,0,0,.8})
    assert(not close.window.frame._fpParchmentNineSlice or not close.window.frame._fpParchmentNineSlice:IsShown())
    assert(close.widgets.saveCloseButton.parent==close.widgets.cancelButton.parent)
    CheckUnsaved(close)
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
-- Simulated wrapped native metrics exercise local fitting, not guessed atlas dimensions.
for _,text in ipairs({
    {title="Remove Component?",message=string.rep("Remove the selected component from this unit frame? ",4),hint="The template is retained."},
    {title="Komponente entfernen?",message=string.rep("Die ausgew?hlte Komponente aus diesem Einheitenfenster entfernen? ",4),hint="Die Vorlage bleibt erhalten."},
}) do
    local confirmed,cancelled=0,0
    local dialog=forms.CreateCompactConfirmation({title=text.title,message=text.message,hint=text.hint,
        windowChrome="editmode",titleFontSize=16,titleOffsetY=-7,headerDrag={left=8,right=36,top=0,height=32},
        primary={text="Remove",role="danger",width=210,onClick=function() confirmed=confirmed+1 end},
        cancel={text="Cancel",width=110,onClick=function(owner)cancelled=cancelled+1;owner:Close()end}})
    local message=assert(Find(dialog.body,"Label",text.message))
    local hint=assert(Find(dialog.body,"Label",text.hint))
    message.label.GetStringHeight=function()return 56 end
    hint.label.GetStringHeight=function()return 28 end
    dialog.confirmationStatus.label.GetStringHeight=function(owner)return owner:GetText()==" " and 14 or 42 end
    dialog:Show();Check(dialog,420,213)
    dialog:SetStatus("A multi-line failure remains visible.","error",dialog.confirmationStatus)
    Check(dialog,420,241)
    dialog:SetStatus("",nil,dialog.confirmationStatus);Check(dialog,420,213)
    for _=1,20 do
        dialog:Show();dialog.body:DoLayout();Check(dialog,420,213)
        dialog.window.frame:Run("OnKeyDown","ENTER");Equal(confirmed,0)
        dialog.window.frame:Run("OnKeyDown","ESCAPE");assert(not dialog.window.frame:IsShown())
    end
    dialog:Show();dialog.cancelButton:Fire("OnClick");Equal(cancelled,1);Equal(confirmed,0)
    dialog:Show();dialog.window.closebutton:Run("OnClick");Equal(confirmed,0)
    dialog:Show();dialog.primaryButton:Fire("OnClick");Equal(confirmed,1)
    -- Font metrics belong to this test case, never the next pooled Label owner.
    message.label.GetStringHeight=nil;hint.label.GetStringHeight=nil
    dialog.confirmationStatus.label.GetStringHeight=nil
    ace:Release(dialog.window)
end
print("PASS: confirmation Table footer survives reflow; measured EN/DE content/status, 20 reopen cycles, Cancel/X/Escape and no Enter confirmation")
-- Real component-removal handler, with only mutation/refresh boundaries supplied.
do
    local file=assert(io.open("GUI/Editor/CanvasToolbar.lua"));local source=file:read("*a");file:close()
    local first=assert(source:find("local function OpenComponentRemove(request)",1,true))
    local last=assert(source:find("function CanvasToolbar.OpenComponentCatalog",first,true))
    local removed=0
    local fixtureNS={InspectorMutations={CanRemoveObject=function()return true end,
        RemoveObject=function(_,ref)removed=removed+1;Equal(ref.unit,"player");return {ok=true,changed=true}end},
        LayoutMutations={},LayoutEditWorkflow={RequestEditableLayoutForMutation=function(fn)fn()end},
        GUI={Editor={ObjectSelection={GetSelectedObject=function()end},Composition={},Controller={
            RefreshCompositionTree=function()end,RefreshActiveProperties=function()end,GetActiveInspectorHost=function()end}}}}
    local open=assert(load(source:sub(first,last-1).."\nreturn OpenComponentRemove","@Canvas/ComponentConfirmation","t",
        setmetatable({ns=fixtureNS,FormWidgets=forms,T=function(_,fallback)return fallback end,
            BuildDecorationMutationContext=function()return {}end,RequestEditorRefresh=function()end},{__index=_G})))()
    local current=true
    local request={parentRef={unit="player",kind="health"},displayName="Health",isCurrent=function()return current end}
    open(request);local cancelled=latest;Check(cancelled,420,139)
    cancelled.cancelButton:Fire("OnClick");Equal(removed,0)
    cancelled.primaryButton:Fire("OnClick");Equal(removed,0);ace:Release(cancelled.window)
    open(request);local stale=latest;current=false
    stale.primaryButton:Fire("OnClick");Equal(removed,0);assert(not stale.window.frame:IsShown());ace:Release(stale.window)
    current=true;open(request);local confirmed=latest;Check(confirmed,420,139)
    confirmed.primaryButton:Fire("OnClick");Equal(removed,1);assert(not confirmed.window.frame:IsShown());ace:Release(confirmed.window)
end
print("PASS: real component confirmation Cancel/stale guard, explicit Remove and shared measured Table footer")
forms.CreateCompactFormDialog=create
assert(#f.env.errors==0,table.concat(f.env.errors,"\n"))
print("PASS: Dialog family, Options, Layout/Transfer workflows, Assignments, all confirmations, both pickers, three direct utilities/actions, neutral/Modern transitions, 50 reapply and 60 pooling cycles")
