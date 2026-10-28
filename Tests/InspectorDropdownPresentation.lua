-- Actual AceGUI Dropdown/Pullout/items, Inspector adapter and release; no native pixel assertions.
local function Read(path)local f=assert(io.open(path));local s=f:read("*a");f:close();return s end
local source=Read("Tests/TypographyLabels.lua")
local stop=assert(source:find('local source = Read("GUI/Editor/Inspector/InspectorController.lua")',1,true))
local ns,ace,native,forms,addDropdown,shared,Equal=assert(load(source:sub(1,stop-1)..
    "\nreturn ns,ace,native,widgets,addDropdown,shared,Equal","@Dropdown/NativeBoundary"))()
function native:HookScript(event,callback)
    local previous=self.scripts[event]
    self:SetScript(event,function(owner,...)if previous then previous(owner,...)end;callback(owner,...)end)
end
function native:GetScript(event)return self.scripts[event]end
function native:LockHighlight()self.locked=true end
function native:UnlockHighlight()self.locked=false end
function native:GetNormalTexture()if not self.normal then self.normal=self:CreateTexture()end;return self.normal end
function native:GetPushedTexture()if not self.pushed then self.pushed=self:CreateTexture()end;return self.pushed end
function native:GetHighlightTexture()if not self.highlightTexture then self.highlightTexture=self:CreateTexture()end;return self.highlightTexture end
function native:GetDisabledTexture()if not self.disabledTexture then self.disabledTexture=self:CreateTexture()end;return self.disabledTexture end
assert(loadfile("Libraries/Ace3/AceGUI-3.0/widgets/AceGUIWidget-DropDown-Items.lua"))()
local host=ace:Create("SimpleGroup")
local options={MATCH_FRAME="Match Frame",CUSTOM="Custom"}
local selected,calls="MATCH_FRAME",0
local dropdown
local function Create(disabled)
    dropdown=addDropdown(host,"Width Mode",options,selected,function(value)selected=value;calls=calls+1 end,disabled)
    return dropdown
end
local function Surface()return assert(dropdown:GetUserData("fpInspectorDropdown")).surface end
local count=0
local function Test(name,fn)fn();count=count+1;print("PASS: "..name)end
Test("Inspector opt-in preserves size, values and native click scripts while neutral surface/arrow are visible",function()
    Create();assert(dropdown:GetValue()=="MATCH_FRAME" and dropdown.text:GetText()=="Match Frame")
    local style=forms.ResolveFieldStyle("neutral")
    Equal(Surface().fill.lastSetColorTexture,style.background);Equal(Surface().top.lastSetColorTexture,style.border)
    assert(Surface().top.nativeHeight==1 and Surface().left.nativeWidth==1)
    assert(dropdown.frame.nativeHeight==40 and dropdown.dropdown.points.TOPLEFT.x==-15)
    assert(dropdown.button_cover:GetScript("OnClick") and dropdown.button:GetScript("OnClick"))
    assert(dropdown.button:GetNormalTexture().lastSetVertexColor[1]>.9)
    for _,suffix in ipairs({"Left","Middle","Right"})do assert(_G[dropdown.dropdown:GetName()..suffix]:GetAlpha()==0)end
    assert(calls==0)
end)
Test("hover chains native highlight and changes only local border; leave restores it",function()
    local nativeClick=dropdown.button_cover:GetScript("OnClick")
    dropdown.button_cover:Run("OnEnter")
    assert(dropdown.button.locked)
    Equal(Surface().top.lastSetColorTexture,forms.ResolveFieldStyle("neutral").borderFocus)
    dropdown.button_cover:Run("OnLeave");assert(not dropdown.button.locked)
    Equal(Surface().top.lastSetColorTexture,forms.ResolveFieldStyle("neutral").border)
    assert(dropdown.button_cover:GetScript("OnClick")==nativeClick and selected=="MATCH_FRAME" and calls==0)
end)
Test("actual pullout opens, selects a value and closes; explicit close also retains selected text",function()
    dropdown.button_cover:Run("OnClick");assert(dropdown.open and dropdown.pullout.frame:IsShown())
    local item
    for _,entry in dropdown.pullout:IterateItems()do if entry.userdata.value=="CUSTOM"then item=entry end end
    assert(item);item:Fire("OnValueChanged",true)
    assert(selected=="CUSTOM" and calls==1 and dropdown:GetValue()=="CUSTOM" and dropdown.text:GetText()=="Custom")
    assert(not dropdown.open and not dropdown.pullout.frame:IsShown())
    dropdown.button:Run("OnClick");assert(dropdown.open)
    dropdown:ClearFocus();assert(not dropdown.open and dropdown:GetValue()=="CUSTOM" and calls==1)
    dropdown:SetValue("MATCH_FRAME");assert(dropdown.text:GetText()=="Match Frame" and calls==1)
end)
Test("Disabled and Enabled repaint without changing values/options or dropdown geometry",function()
    local height=dropdown.frame:GetHeight();local click=dropdown.button_cover:GetScript("OnClick")
    dropdown:SetDisabled(true)
    assert(dropdown.disabled and Surface().fill:GetAlpha()==.5)
    Equal(dropdown.text.lastSetTextColor,{.5,.5,.5,1})
    dropdown.button_cover:Run("OnEnter");Equal(Surface().top.lastSetColorTexture,forms.ResolveFieldStyle("neutral").border)
    dropdown:SetDisabled(false);assert(not dropdown.disabled and Surface().fill:GetAlpha()==1)
    assert(dropdown.text.lastSetTextColor[1]>.9 and dropdown.frame:GetHeight()==height)
    assert(dropdown:GetValue()=="MATCH_FRAME" and dropdown.list==options and dropdown.button_cover:GetScript("OnClick")==click)
end)
Test("release restores native artwork and shared non-Inspector consumer stays unchanged after reuse",function()
    local surface=Surface();local old=dropdown;local original=dropdown:GetUserData("fpInspectorDropdown").setDisabled
    ace:Release(dropdown)
    for _,region in pairs(surface)do assert(not region:IsShown())end
    assert(not old:GetUserData("fpInspectorDropdown"))
    assert(old.SetDisabled~=nil)
    for _,suffix in ipairs({"Left","Middle","Right"})do assert(_G[old.dropdown:GetName()..suffix]:GetAlpha()==1)end
    local other=shared.AddDropdown(host,"Other page",options,"CUSTOM",function()end)
    assert(not other:GetUserData("fpInspectorDropdown"))
    if other.button_cover._fpInspectorDropdownSurface then
        for _,region in pairs(other.button_cover._fpInspectorDropdownSurface)do assert(not region:IsShown())end
    end
    other.button_cover:Run("OnEnter");assert(not other:GetUserData("fpInspectorDropdown"))
    assert(other.text:GetText()=="Custom");ace:Release(other)
    for _=1,30 do
        Create();local binding=dropdown:GetUserData("fpInspectorDropdown")
        local wrapper=dropdown.SetDisabled;forms.StyleInspectorDropdown(dropdown)
        assert(dropdown:GetUserData("fpInspectorDropdown")==binding and dropdown.SetDisabled==wrapper)
        dropdown:SetDisabled(true);dropdown:SetDisabled(false);ace:Release(dropdown)
        assert(not dropdown:GetUserData("fpInspectorDropdown"))
    end
end)
print("Inspector Dropdown Presentation: "..count.." groups PASS")
