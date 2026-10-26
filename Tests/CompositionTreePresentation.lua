-- Real Workspace, TreeView/Control, ObjectSelection and native UI boundary.
local function Read(path)local f=assert(io.open(path));local s=f:read("*a");f:close();return s end
local source=Read("Tests/CustomizeWorkspace.lua")
local stop=assert(source:find("\nlocal count = 0",1,true))
local h,ns,state,controller,selection,Setup,Build,Drain,Tree=assert(load(source:sub(1,stop)..
    "\nreturn h,ns,state,controller,selection,Setup,Build,Drain,Tree","@TreePresentation/Workspace"))()
-- The shared fixture omits legacy text-parent projection; load the actual production chain.
for _,path in ipairs({"GUI/Editor/Composition/LegacyAssociationMap.lua",
    "GUI/Editor/Composition/CompositionOwnership.lua","GUI/Editor/Composition/CompositionTreeAdapter.lua",
    "GUI/Editor/Composition/CompositionTreeView.lua","GUI/Editor/Toolbar/ToolbarBinding.lua"})do assert(loadfile(path))("FocalPoint",ns)end
local palette=ns.GUI.Skins.GetFormPalette().CompositionTree
local height=ns.GUI.Editor.Composition.TreeControl.ROW_HEIGHT
local oldTooltip=GameTooltip
local tooltip={lines={},shown=false}
function tooltip:SetOwner(owner)self.owner=owner end
function tooltip:IsOwned(owner)return self.owner==owner end
function tooltip:ClearLines()self.lines={}end
function tooltip:AddLine(text)self.lines[#self.lines+1]=text end
function tooltip:Show()self.shown=true end
function tooltip:Hide()self.shown=false;self.owner=nil end
GameTooltip=tooltip
local function Row(kind,key)
    local control=Tree().control
    assert(not control.background:IsShown(),"Tree adds an opaque surface over the Customize host")
    for i=1,control.count do
        local row=control.rows[i];local target=row.item.node.inspectorTarget
        if row.item.node.type==kind and (not key or target.textKey==key or target.objectKey==key)then return row,i end
    end
    error("missing row: "..kind..":"..tostring(key))
end
local function Click(kind,key)Row(kind,key).frame:Run("OnMouseDown","LeftButton");Drain()end
local count=0
local function Test(name,fn)fn();count=count+1;print("PASS: "..name)end
local db,unit,window
Test("uniform readable rows retain original hierarchy, mapped icons and full-row hit targets",function()
    db,unit=Setup()
    unit.healthBarPresent=true
    unit.Texts.localText.anchorTo="HealthBar"
    unit.Texts.localText.enabled=false
    window=Build()
    assert(height==22)
    local control=Tree().control
    assert(control.rows[1].item.node.type=="unit","selectable Frame root was lost")
    for i=1,control.count do
        local row=control.rows[i]
        assert(row.frame:GetHeight()==22)
        assert(row.frame.points.TOPLEFT.y==-(i-1)*22 and row.frame.points.TOPRIGHT.y==-(i-1)*22)
        assert(row.disclosure.points.LEFT.x==3+row.item.depth*14)
        assert(row.disclosure:GetWidth()==16 and row.disclosure:GetHeight()==22)
        local _,size=row.label:GetFont();assert(size==12)
        assert(row.frame:GetScript("OnMouseDown"))
        if row.icon:IsShown()then
            local path=row.icon:GetTexture()
            local relative=assert(path:match("Interface\\AddOns\\FocalPoint\\(.+)")):gsub("\\","/")
            local f=assert(io.open(relative,"rb"),path);f:close()
            assert(row.icon:GetWidth()==14 and row.icon:GetHeight()==14)
        end
    end
    local child=Row("textElement","localText")
    assert(child.item.depth==Row("healthbar").item.depth+1)
end)
Test("hover and warm selection consume the existing palette without data mutation",function()
    local before=h.Copy(db)
    local row=Row("healthbar")
    row.frame:Run("OnEnter");assert(row.background:IsShown());h.Equal(row.background.lastSetColorTexture,palette.rowHover)
    row.frame:Run("OnLeave");assert(not row.background:IsShown())
    Click("healthbar");row=Row("healthbar")
    assert(selection.GetSelectedObject().objectKey=="HealthBar" and row.item.selected)
    h.Equal(row.background.lastSetColorTexture,palette.rowSelected)
    row.frame:Run("OnEnter");row.frame:Run("OnLeave")
    assert(row.background:IsShown());h.Equal(row.background.lastSetColorTexture,palette.rowSelected)
    h.Equal(db,before)
end)
Test("disabled children remain selectable and disclosure preserves canonical object navigation",function()
    Click("textElement","localText")
    assert(selection.GetSelectedObject().textKey=="localText")
    assert(Row("textElement","localText").item.node.enabled==false)
    assert(state.GetPropertyScope().sectionKey=="texts" and #window._focalPointPropertyScroll.children>0)
    Click("healthbar")
    local row=Row("healthbar");assert(row.disclosureGlyph:GetTexture()==130940)
    h.Equal(row.disclosureGlyph.lastSetTexCoord,{0,1,1,1,0,0,1,0})
    row.disclosure:Run("OnMouseDown","LeftButton")
    row=Row("healthbar");h.Equal(row.disclosureGlyph.lastSetTexCoord,{0,1,0,1})
    assert(not pcall(Row,"textElement","localText"))
    row.disclosure:Run("OnMouseDown","LeftButton")
    h.Equal(Row("healthbar").disclosureGlyph.lastSetTexCoord,{0,1,1,1,0,0,1,0})
    Click("textElement","localText");assert(selection.GetSelectedObject().textKey=="localText")
    Click("unit");assert(selection.GetSelectedObject().kind=="unit")
    assert(not state.GetPropertyScope() or state.GetPropertyScope().sectionKey=="frame")
end)
Test("full-name tooltip and checkbox expose existing identity and toggle semantics without changing row selection",function()
    Click("textElement","localText")
    local row=Row("textElement","localText")
    local before=h.Copy(db);local selected=selection.GetSelectedObject()
    row.frame:Run("OnEnter")
    assert(tooltip.shown and tooltip.owner==row.frame and tooltip.lines[1]==row.item.label)
    assert(row.toggleGlyph:GetTexture()==130755 and row.toggleCheck:GetTexture()==130751)
    assert(not row.toggleCheck:IsShown())
    row.frame:Run("OnLeave");assert(not tooltip.shown)
    h.Equal(db,before)
    row.toggle:Run("OnEnter");assert(tooltip.lines[2]==(ns.L.OPTION_OFF or "Off"))
    row.toggle:Run("OnMouseDown","LeftButton");Drain()
    assert(unit.Texts.localText.enabled==true)
    row=Row("textElement","localText");assert(row.toggleCheck:IsShown())
    assert(selection.GetSelectedObject().textKey==selected.textKey)
    row.toggle:Run("OnMouseDown","LeftButton");Drain();assert(unit.Texts.localText.enabled==false)
    row=Row("textElement","localText");assert(not row.toggleCheck:IsShown())
    row.frame:Run("OnEnter");controller.RefreshCompositionTree();Drain();assert(not tooltip.shown)
end)
Test("long lists use actual row height for scrolling and keep the selected row visible",function()
    for i=1,45 do unit.Texts["extra"..i]={tag="test",enabled=true}end
    controller.RefreshCompositionTree();Drain()
    local control=Tree().control
    control.frame:SetSize(200,66);assert(control:Layout())
    assert(control.maxScroll==control.count*height-66)
    control:SetScroll(0);control.frame:Run("OnMouseWheel",-1);assert(control.offset==height*3)
    Click("textElement","extra9")
    control=Tree().control;local _,index=Row("textElement","extra9")
    assert(control.offset<=(index-1)*height and control.offset+control.frame:GetHeight()>=index*height)
    assert(selection.GetSelectedObject().textKey=="extra9")
    local row=Row("textElement","extra9");row.frame:Run("OnEnter")
    assert(tooltip.lines[1]==row.item.label)
    row.frame:Hide();assert(not tooltip.shown)
end)
Test("unit changes, close/reopen and repeated pooling bind only current rows",function()
    local units=ns.ActiveLayoutResolver.GetActiveRuntimeRoot().units
    units.target=h.Copy(unit)
    for _=1,20 do
        local old=Tree().control
        local tail=old.rows[old.count]
        assert(selection.SelectObject({kind="unit",unit="target"}));Drain()
        assert(Tree().tree.unit=="target")
        Click("textElement","localText");assert(selection.GetSelectedObject().unit=="target")
        assert(selection.SelectObject({kind="unit",unit="player"}));Drain()
        assert(Tree().tree.unit=="player")
        -- Removed tail rows must never retain input scripts after a shorter projection.
        Click("unit");Row("unit").disclosure:Run("OnMouseDown","LeftButton")
        assert(Tree().control.count==1)
        if tail~=Tree().control.rows[1]then assert(not tail.frame:IsShown() and not tail.frame:GetScript("OnMouseDown"))end
        Row("unit").disclosure:Run("OnMouseDown","LeftButton")
    end
    window._focalPointCloseButton:Fire("OnClick");Drain();assert(Build()==window);Drain()
    assert(Tree().tree.unit=="player" and Row("unit").frame:IsShown())
end)
assert(#h.ui.env.errors==0,table.concat(h.ui.env.errors,"\n"))
GameTooltip=oldTooltip
print("Composition Tree Presentation: "..count.." groups PASS")
