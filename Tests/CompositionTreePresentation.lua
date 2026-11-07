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
    assert(height==34)
    local control=Tree().control
    assert(control.rows[1].item.node.type=="unit","selectable Frame root was lost")
    for i=1,control.count do
        local row=control.rows[i]
        local root=row.item.node.type=="unit"
        local top=(i-1)*34+(i>1 and 10 or 0)
        assert(row.frame:GetHeight()==(root and 36 or 30))
        assert(row.frame.points.TOPLEFT.y==-top and row.frame.points.TOPRIGHT.y==-top)
        assert(row.frame.points.TOPLEFT.x==math.max(0,row.item.depth-1)*16)
        assert(row.disclosure.points.LEFT.x==0)
        assert(row.disclosure:GetWidth()==26 and row.disclosure:GetHeight()==26)
        assert(#row.edges==4 and row.background:IsShown())
        for _,edge in ipairs(row.edges)do assert(edge:IsShown())end
        assert(row.toggle.points.RIGHT.relative==row.frame and row.toggle.points.RIGHT.x==-6)
        local _,size=row.label:GetFont();assert(size==(root and 16 or 13))
        if row.item.node.enabled==false then
            h.Equal(row.label.lastSetTextColor,palette.text.disabled)
        elseif row.item.depth==1 then
            local color=NORMAL_FONT_COLOR or ns.GUI.Helpers.TextStyles.Get("strongHeading")
            h.Equal(row.label.lastSetTextColor,{color.r,color.g,color.b})
        else
            h.Equal(row.label.lastSetTextColor,{1,1,1,1})
        end
        assert(row.frame:GetScript("OnMouseDown"))
        if row.icon:IsShown()then
            local path=row.icon:GetTexture()
            local relative=assert(path:match("Interface\\AddOns\\FocalPoint\\(.+)")):gsub("\\","/")
            local f=assert(io.open(relative,"rb"),path);f:close()
            assert(row.icon:GetWidth()==16 and row.icon:GetHeight()==16)
        end
    end
    local child=Row("textElement","localText")
    assert(child.item.depth==Row("healthbar").item.depth+1)
end)
Test("hover and warm selection consume the existing palette without data mutation",function()
    local before=h.Copy(db)
    local row=Row("healthbar")
    row.frame:Run("OnEnter");assert(row.background:IsShown());h.Equal(row.background.lastSetColorTexture,palette.rowHover)
    row.frame:Run("OnLeave");assert(row.background:IsShown());h.Equal(row.background.lastSetColorTexture,palette.surface)
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
    h.Equal(row.toggleCheck.lastSetVertexColor,{1,1,1,1})
    assert(row.toggle.template=="UICheckButtonArtTemplate" and row.toggle:GetWidth()==26)
    assert(not row.toggleCheck:IsShown())
    row.frame:Run("OnLeave");assert(not tooltip.shown)
    h.Equal(db,before)
    row.toggle:Run("OnEnter");assert(tooltip.lines[2]==(ns.L.OPTION_OFF or "Off"))
    row.toggle:Run("OnClick","LeftButton");Drain()
    assert(unit.Texts.localText.enabled==true)
    row=Row("textElement","localText");assert(row.toggleCheck:IsShown())
    assert(selection.GetSelectedObject().textKey==selected.textKey)
    row.toggle:Run("OnClick","LeftButton");Drain();assert(unit.Texts.localText.enabled==false)
    row=Row("textElement","localText");assert(not row.toggleCheck:IsShown())
    row.frame:Run("OnEnter");controller.RefreshCompositionTree();Drain();assert(not tooltip.shown)
end)
Test("long lists use actual row height for scrolling and keep the selected row visible",function()
    for i=1,45 do unit.Texts["extra"..i]={tag="test",enabled=true}end
    controller.RefreshCompositionTree();Drain()
    local control=Tree().control
    control.frame:SetSize(200,66);assert(control:Layout())
    assert(control.maxScroll==control.count*height+10-66)
    control:SetScroll(0);control.frame:Run("OnMouseWheel",-1);assert(control.offset==height*3)
    Click("textElement","extra9")
    control=Tree().control;local _,index=Row("textElement","extra9")
    assert(control.offset<=(index-1)*height+10 and control.offset+control.frame:GetHeight()>=index*height+10)
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
    window.closebutton:GetScript("OnClick")(window.closebutton);Drain();assert(Build()==window);Drain()
    assert(Tree().tree.unit=="player" and Row("unit").frame:IsShown())
end)
Test("card, disclosure and checkbox clicks remain distinct through 20 navigation cycles",function()
    db,unit=Setup();unit.healthBarPresent=true;unit.powerBarPresent=true;unit.showPowerBar=true
    unit.Texts.localText.anchorTo="HealthBar";unit.Texts.localText.enabled=false
    window=Build()
    local function Back()
        window._focalPointComponentsButton:Fire("OnClick");Drain()
        assert(window._focalPointCustomizeView=="components")
    end
    local before=h.Copy(selection.GetSelectedObject())
    Row("healthbar").disclosure:Run("OnMouseDown","LeftButton");Drain()
    assert(window._focalPointCustomizeView=="components")
    h.Equal(selection.GetSelectedObject(),before)
    Row("healthbar").disclosure:Run("OnMouseDown","LeftButton");Drain()
    Row("powerbar").toggle:Run("OnClick","LeftButton");Drain()
    assert(unit.showPowerBar==false and window._focalPointCustomizeView=="components")
    h.Equal(selection.GetSelectedObject(),before)
    for _=1,20 do
        Click("healthbar");assert(window._focalPointCustomizeView=="properties")
        assert(selection.GetSelectedObject().objectKey=="HealthBar");Back()
        local parent=Row("healthbar")
        for _,edge in ipairs(parent.edges)do h.Equal(edge.lastSetColorTexture,palette.text.selected)end
        Click("textElement","localText");assert(window._focalPointCustomizeView=="properties")
        assert(selection.GetSelectedObject().textKey=="localText");Back()
        local child=Row("textElement","localText")
        assert(child.frame.points.TOPLEFT.x==parent.frame.points.TOPLEFT.x+16)
        assert(child.item.node.enabled==false and child.background:IsShown())
    end
end)
Test("Unit root is a distinct 36px header with 16px identity text and an 8px card gap",function()
    db,unit=Setup();unit.healthBarPresent=true;unit.powerBarPresent=true
    unit.Texts.localText.anchorTo="HealthBar";window=Build()
    Click("healthbar")
    local root=Row("unit");local first=Tree().control.rows[2]
    assert(root.frame:GetHeight()==36 and first.frame.points.TOPLEFT.y==-44)
    assert(-first.frame.points.TOPLEFT.y-root.frame:GetHeight()==8)
    assert(root.textRole=="identity")
    local _,size=root.label:GetFont();assert(size==16)
    h.Equal(root.background.lastSetColorTexture,ns.GUI.Skins.GetFormPalette().Chrome.panelHeader)
    assert(root.add:IsShown() and root.remove:IsShown() and not root.remove:IsEnabled())
    assert(root.frame:GetScript("OnMouseDown"))
    root.frame:Run("OnEnter");h.Equal(root.background.lastSetColorTexture,palette.rowHover)
    root.frame:Run("OnLeave");h.Equal(root.background.lastSetColorTexture,ns.GUI.Skins.GetFormPalette().Chrome.panelHeader)
    Click("unit");assert(selection.GetSelectedObject().kind=="unit")
    h.Equal(Row("unit").background.lastSetColorTexture,palette.rowSelected)
end)
Test("gold expand controls preserve the original 45px label start and all action zones at 320/360px",function()
    db,unit=Setup();unit.healthBarPresent=true;unit.powerBarPresent=true;unit.showPowerBar=true
    unit.Texts.localText.anchorTo="HealthBar";window=Build()
    local before=h.Copy(selection.GetSelectedObject())
    for _,width in ipairs({320,360})do
        local control=Tree().control;control.frame:SetSize(width,68);control:Layout()
        for i=1,control.count do
            local row=control.rows[i]
            assert(row.disclosure:GetWidth()==26 and row.disclosure:GetHeight()==26)
            assert(row.disclosureGlyph:GetWidth()==18 and row.disclosureGlyph:GetHeight()==18)
            h.Equal(row.disclosureGlyph.lastSetVertexColor,{1,.82,0,1})
            assert(not row.disclosure.lastSetHighlightTexture and not row.disclosure.lastSetPushedTexture)
            assert(row.disclosure:IsShown()==row.item.expandable)
            assert(row.disclosure.points.LEFT.x+row.disclosure:GetWidth()+row.icon.points.LEFT.x+row.icon:GetWidth()+row.label.points.LEFT.x==45)
            assert(row.icon.points.LEFT.relative==row.disclosure and row.label.points.LEFT.relative==row.icon)
            assert(row.add:GetWidth()==28 and row.add:GetHeight()==26)
            assert(row.remove:GetWidth()==28 and row.remove:GetHeight()==26)
        end
        local parent=Row("healthbar");local child=Row("textElement","localText")
        assert(child.frame.points.TOPLEFT.x==parent.frame.points.TOPLEFT.x+16)
        assert(not child.disclosure:IsShown())
        local name=parent.item.label
        for _,long in ipairs({"Health Bar with a deliberately long component name",
            "Gesundheitsleiste mit besonders langer Komponentenbezeichnung"})do
            parent.item.label=long;parent.label:SetText(long)
            parent.disclosure:Run("OnEnter");assert(tooltip.lines[1]==long)
            parent.disclosure:Run("OnLeave")
        end
        parent.item.label=name;parent.label:SetText(name)
        parent.disclosure:Run("OnMouseDown","LeftButton")
        assert(not Row("healthbar").item.expanded and window._focalPointCustomizeView=="components")
        h.Equal(selection.GetSelectedObject(),before)
        Row("healthbar").disclosure:Run("OnMouseDown","LeftButton")
        assert(Row("healthbar").item.expanded)
    end
end)
Test("expanded header geometry scrolls and resizes consistently; old expand scripts cannot alter rebound rows",function()
    local control=Tree().control;local row=Row("healthbar")
    local old=row.disclosure:GetScript("OnMouseDown")
    local countBefore=control.count
    controller.RefreshCompositionTree();Drain()
    old(row.disclosure,"LeftButton");assert(Tree().control.count==countBefore and Row("healthbar").item.expanded)
    control=Tree().control;control.frame:SetSize(320,60);control:Layout()
    control:SetScroll(20);local saved=control.offset
    local items={};for i=1,control.count do items[i]=control.rows[i].item end
    control:SetRows(items);assert(control.offset==saved)
    controller.RefreshCompositionTree();Drain()
    -- A full rebuild retains the existing auto-reveal of the selected Unit root.
    assert(selection.GetSelectedObject().kind=="unit" and Tree().control.offset==0)
    control=Tree().control;control.frame:SetSize(360,80);control:Layout()
    assert(control.content:GetHeight()==control.count*34+10)
    local _,last=Row("textElement","localText");control:EnsureVisible(last)
    assert(control.offset<=(last-1)*34+10 and control.offset+80>=last*34+10)
    local root=Row("unit");root.disclosure:Run("OnMouseDown","LeftButton")
    control=Tree().control;assert(control.count==1 and control.content:GetHeight()==44)
    assert(not Row("unit").item.expanded)
    Row("unit").disclosure:Run("OnMouseDown","LeftButton")
    assert(Row("unit").item.expanded and Row("healthbar").item.expanded)
    window.closebutton:GetScript("OnClick")(window.closebutton);Drain();window=Build()
    local fresh=Tree().control.count
    old(row.disclosure,"LeftButton");assert(Tree().control.count==fresh)
    assert(Row("healthbar").item.expanded)
end)
Test("native MinimalScrollBar art preserves the existing Slider, drag, wheel and short-list lifecycle",function()
    db,unit=Setup();unit.healthBarPresent=true
    for i=1,40 do unit.Texts["scroll"..i]={tag="[name]",enabled=true}end
    window=Build();local control=Tree().control
    control.frame:SetSize(320,100);control:Layout()
    assert(control.scrollbar.kind=="Slider" and control.scrollbar:GetWidth()==8)
    assert(control.content:GetWidth()==310 and control.scrollbar:IsShown())
    assert(control.thumbTop.atlas=="minimal-scrollbar-small-thumb-top")
    assert(control.thumbMiddle.atlas=="minimal-scrollbar-small-thumb-middle")
    assert(control.thumbBottom.atlas=="minimal-scrollbar-small-thumb-bottom")
    local found={};for _,region in ipairs(control.scrollbar.regions or {})do if region.atlas then found[region.atlas]=true end end
    assert(found["minimal-scrollbar-track-top"] and found["!minimal-scrollbar-track-middle"] and found["minimal-scrollbar-track-bottom"])
    control.thumbDragHandle:Run("OnEnter");assert(control.thumbMiddle.atlas=="minimal-scrollbar-small-thumb-middle-over")
    control.thumbDragHandle:Run("OnLeave");assert(control.thumbMiddle.atlas=="minimal-scrollbar-small-thumb-middle")
    local cursor,scale=GetCursorPosition,control.scrollbar.GetEffectiveScale
    control.scrollbar:SetHeight(100) -- The native double does not resolve the Slider's TOP/BOTTOM anchors.
    local y=100;GetCursorPosition=function()return 0,y end
    control.scrollbar.GetEffectiveScale=function()return 1 end
    control:SetScroll(0);control.thumbDragHandle:Run("OnMouseDown","LeftButton")
    assert(control._thumbDrag and control.thumbMiddle.atlas=="minimal-scrollbar-small-thumb-middle-down")
    y=80;control.thumbDragHandle:Run("OnUpdate");assert(control.offset>0)
    control.thumbDragHandle:Run("OnMouseUp","LeftButton")
    assert(not control._thumbDrag and not control.thumbDragHandle:GetScript("OnUpdate"))
    assert(control.thumbMiddle.atlas=="minimal-scrollbar-small-thumb-middle")
    GetCursorPosition=cursor;control.scrollbar.GetEffectiveScale=scale
    control:SetScroll(0);control.frame:Run("OnMouseWheel",-1);assert(control.offset==102)
    local saved=control.offset;local rows={};for i=1,control.count do rows[i]=control.rows[i].item end
    control:SetRows(rows);assert(control.offset==saved)
    control.frame:SetSize(360,120);control:Layout();assert(control.offset==saved)
    Row("unit").disclosure:Run("OnMouseDown","LeftButton")
    assert(Tree().control.count==1 and not Tree().control.scrollbar:IsShown() and Tree().control.offset==0)
    Row("unit").disclosure:Run("OnMouseDown","LeftButton")
    window.closebutton:GetScript("OnClick")(window.closebutton);Drain();window=Build()
    assert(not Tree().control._thumbDrag and Tree().control.thumbMiddle.atlas=="minimal-scrollbar-small-thumb-middle")
end)
Test("localized edit tooltips preserve single-line names, IDs and independent action zones through release/reuse",function()
    local savedTooltip=ns.L.COMPONENT_EDIT_TOOLTIP
    local originalLocale=GetLocale
    for _,locale in ipairs({"enUS","deDE"})do
        GetLocale=function()return locale end
        local localized={L={}};assert(loadfile("Locales/"..locale..".lua"))("FocalPoint",localized)
        ns.L.COMPONENT_EDIT_TOOLTIP=assert(localized.L.COMPONENT_EDIT_TOOLTIP)
        db,unit=Setup();unit.healthBarPresent=true;window=Build()
        local control=Tree().control
        local before=h.Copy(db)
        for i=1,control.count do
            local row=control.rows[i];local item=row.item
            assert(row.editHint==nil and row.label:GetText()==item.label and not row.hovered)
            assert(row.label.points.LEFT.x==3 and row.label.points.LEFT.y==0 and row.label.points.RIGHT.y==0)
            row.frame:Run("OnEnter")
            assert(tooltip.lines[1]==item.label and tooltip.lines[2]==ns.L.COMPONENT_EDIT_TOOLTIP and #tooltip.lines==2)
            row.frame:Run("OnLeave");assert(not tooltip.shown)
            for _,action in ipairs({row.add,row.remove,row.toggle,row.disclosure})do
                if action:GetScript("OnEnter")then
                    action:Run("OnEnter");assert(tooltip.lines[1]==item.label and tooltip.lines[2]~=ns.L.COMPONENT_EDIT_TOOLTIP)
                    action:Run("OnLeave");assert(not tooltip.shown)
                end
            end
        end
        h.Equal(db,before)
        -- Renderer-only family coverage; real selection/mutations are exercised above.
        local types={"unit","healthbar","powerbar","textElement","decorationElement","segmentedBar","buffs","debuffs","indicatorElement"}
        local items={}
        for i,kind in ipairs(types)do
            items[i]={node={id="tooltip:"..i,type=kind,enabled=false},depth=i==1 and 0 or 2,
                label="Very long component name / Sehr langer Komponentenname "..i,
                clickable=true,toggleable=i>2,removable=i>2,expandable=true,addable=true}
        end
        local renderer=ns.GUI.Editor.Composition.TreeControl
        local selected,added,removed,toggled,expanded
        local callbacks={onSelect=function(node)selected=node end,onAdd=function(node)added=node end,
            onRemove=function(node)removed=node end,onToggle=function(node)toggled=node end,
            onExpand=function(node)expanded=node end}
        local function Verify(c)
            for _,width in ipairs({320,360})do
                c.frame:SetSize(width,100);c:SetRows(items)
                for i,item in ipairs(items)do
                    local row=c.rows[i]
                    assert(row.item.node==item.node and row.item.node.id=="tooltip:"..i)
                    assert(row.editHint==nil and row.label:GetText()==item.label and not row.hovered)
                    local _,nameSize=row.label:GetFont()
                    assert(nameSize==(i==1 and 16 or 13) and row.frame:GetHeight()==(i==1 and 36 or 30))
                    assert(row.label.points.LEFT.y==0 and row.label.points.RIGHT.y==0)
                    assert(row.label.points.LEFT.relative==row.icon and row.label.points.LEFT.x==3)
                    assert(row.label.points.RIGHT.relative==row.add and row.label.points.RIGHT.x==-4)
                    assert(row.add.points.RIGHT.relative==row.remove and row.remove.points.RIGHT.relative==row.toggle)
                    row.frame:Run("OnEnter");assert(tooltip.lines[1]==item.label and tooltip.lines[2]==ns.L.COMPONENT_EDIT_TOOLTIP)
                    row.frame:Run("OnLeave")
                    row.frame:Run("OnMouseDown","LeftButton");assert(selected==item.node)
                    selected=nil
                    row.add:Run("OnMouseDown","LeftButton");assert(added==item.node and selected==nil)
                    row.disclosure:Run("OnMouseDown","LeftButton");assert(expanded==item.node and selected==nil)
                    if item.removable then row.remove:Run("OnMouseDown","LeftButton");assert(removed==item.node and selected==nil)end
                    if item.toggleable then row.toggle:Run("OnClick","LeftButton");assert(toggled==item.node and selected==nil)end
                end
            end
        end
        local c=renderer.Acquire(window.frame,{scrollvalue=0},callbacks)
        -- A freshly constructed row has exactly its original name and Plus glyph;
        -- no additional FontString for a second visible line may be created.
        local createFontString=h.ui.native.CreateFontString
        local strings={}
        h.ui.native.CreateFontString=function(self,...)
            local text=createFontString(self,...);strings[#strings+1]=text;return text
        end
        local fresh=c:AcquireRow(#c.rows+1)
        h.ui.native.CreateFontString=createFontString
        assert(#strings==2 and strings[1]==fresh.label and strings[2]==fresh.addGlyph)
        Verify(c);c:Release()
        for _,row in ipairs(c.rows)do assert(row.editHint==nil and row.label:GetText()=="" and not row.frame:GetScript("OnMouseDown"))end
        c=renderer.Acquire(window.frame,{scrollvalue=0},callbacks);Verify(c);c:Release()
    end
    GetLocale=originalLocale
    ns.L.COMPONENT_EDIT_TOOLTIP=savedTooltip
end)
Test("remove icons use the shared Blizzard texture and preserve removable, disabled and reused action zones",function()
    db,unit=Setup();window=Build()
    local renderer=ns.GUI.Editor.Composition.TreeControl
    local originalCombat=InCombatLockdown
    local combat=false
    InCombatLockdown=function()return combat end
    local removed,selected
    local c=renderer.Acquire(window.frame,{scrollvalue=0},{
        onRemove=function(node)removed=node end,onSelect=function(node)selected=node end})
    for _,locked in ipairs({false,true})do
        combat=locked
        for _,removable in ipairs({true,false})do
            for _,enabled in ipairs({true,false})do
                local node={id="delete-icon",type="decorationElement",enabled=enabled}
                c:SetRows({{node=node,depth=1,label="Decoration",clickable=true,removable=removable}})
                local row=c.rows[1]
                assert(row.removeGlyph:GetTexture()==130821 and row.removeGlyph.atlas==nil)
                assert(row.removeGlyph:GetWidth()==20 and row.removeGlyph:GetHeight()==20)
                assert(row.removeGlyph.points.CENTER.relative==row.remove)
                assert(row.remove:IsShown() and row.remove:IsEnabled()==removable)
                assert(row.remove:GetAlpha()==(removable and (locked and .4 or 1) or .35))
                h.Equal(row.removeGlyph.lastSetVertexColor,removable and {1,.08,.08,1} or {.5,.5,.5,1})
                removed=nil;selected=nil
                row.remove:Run("OnMouseDown","LeftButton")
                assert(removed==(removable and node or nil) and selected==nil)
                assert((row.remove:GetScript("OnEnter")~=nil)==removable)
                if removable then
                    row.remove:Run("OnEnter");assert(tooltip.owner==row.remove and tooltip.shown)
                    row.remove:Run("OnLeave");assert(not tooltip.shown)
                end
            end
        end
    end
    c:SetRows({})
    assert(not c.rows[1].remove:IsShown() and not c.rows[1].remove:GetScript("OnMouseDown"))
    c:Release()
    InCombatLockdown=originalCombat
end)
assert(#h.ui.env.errors==0,table.concat(h.ui.env.errors,"\n"))
GameTooltip=oldTooltip
print("Composition Tree Presentation: "..count.." groups PASS")
