-- Real Workspace, property projection, callbacks and AceGUI pooling; synthetic atlas metadata.
local function Read(path)local f=assert(io.open(path));local s=f:read("*a");f:close();return s end
local source=Read("Tests/NormalAbsorbPropertyGroups.lua")
local stop=assert(source:find("\nlocal count=0",1,true))
local h,ns,state,controller,selection,Build,Drain,Tabs,Select,Body,Init,Host,Counts=assert(load(source:sub(1,stop)..[[
return h,ns,state,controller,selection,Build,Drain,Tabs,Select,Body,
function()db,unit=Setup();unit.normalAbsorbBarPresent=true;unit.showNormalAbsorbBar=true;window=Build();Select("NormalAbsorbBar");return db,unit end,
function()return window end,function()return acquired,released,timers end
]],"@CustomizeTabArt/Workspace"))()
local native=h.ui.native
local oldRotation,oldAtlas=native.SetRotation,C_Texture
function native:SetRotation(angle)self.rotation=angle end
local missing,invalid,throwAtlas
local function Atlas(name)
    if name==throwAtlas then error("unavailable atlas")end
    if name==missing then return nil end
    if name==invalid then return {width=0,height=26}end
    return {width=20,height=26} -- Matches existing native SetAtlas boundary, not live asset dimensions.
end
C_Texture={GetAtlasInfo=Atlas}
local specs={
    {"artLeftActive","uiframe-activetab-left",true},
    {"artMiddleActive","_uiframe-activetab-center",true},
    {"artRightActive","uiframe-activetab-right",true},
    {"artLeft","uiframe-tab-left",false},
    {"artMiddle","_uiframe-tab-center",false},
    {"artRight","uiframe-tab-right",false},
}
local function Check(active,art)
    local tabs,order=Tabs();assert(table.concat(order,",")=="appearance,geometry,behavior")
    local width=0
    for key,tab in pairs(tabs)do
        local s=tab.frame._fpNormalAbsorbTab
        assert((tab.text:GetText() or "")=="" and s.label:IsShown())
        -- The native boundary stores LEFT/RIGHT anchors without solving GetWidth().
        local left,right=tab.frame.points.LEFT,tab.frame.points.RIGHT
        local tabWidth=right.x-left.x
        assert(tabWidth>=s.label:GetStringWidth()+8)
        local _,size=s.label:GetFont();assert(size==14 and tab.frame:GetHeight()==30)
        width=width+tabWidth
        for _,spec in ipairs(specs)do assert(not s[spec[1]] or not s[spec[1]]:IsShown(),"atlas visible in fixed navigation")end
        for _,name in ipairs({"fill","top","left","right"})do assert(not s[name]:IsShown())end
        assert(s.bottom:IsShown()==(key==active))
        local yellow=NORMAL_FONT_COLOR or {r=1,g=.82,b=0}
        h.Equal(s.label.lastSetTextColor,{key==active and yellow.r or 1,key==active and yellow.g or 1,
            key==active and yellow.b or 1,tab.disabled and .35 or 1})
        h.Equal(s.bottom.lastSetColorTexture,{yellow.r,yellow.g,yellow.b,1})
        assert(s.label.points.LEFT.y==0 and s.label.points.RIGHT.y==0)
    end
    local navigation=tabs.appearance.parent
    assert(navigation.frame:GetHeight()-tabs.appearance.frame:GetHeight()==10,
        "tab strip must reserve exactly 10px before Properties")
    assert(navigation.parent==Host()._focalPointPropertyNavigation)
    assert(navigation.parent.parent==Host()._focalPointPropertyScroll.parent)
    assert(navigation:GetUserData("table").spaceH==0)
    for _,column in ipairs(navigation:GetUserData("table").columns)do assert(column.weight==1)end
    for _,tab in pairs(tabs)do
        assert(math.abs(tab.frame.points.RIGHT.x-tab.frame.points.LEFT.x-navigation.frame:GetWidth()/3)<.5)
    end
    assert(not navigation.frame._fpNormalAbsorbTabBaseline:IsShown())
    assert(math.abs(navigation.frame:GetWidth()-width)<.5,
        "tabs must fill Properties width without overflowing")
    assert(state.Get().inspectorPropertyGroup==active)
end
local function Click(key)Tabs()[key]:Fire("OnClick");Drain()end
local function Refresh()controller.RefreshActiveProperties();Drain()end
local count=0
local function Test(name,fn)fn();count=count+1;print("PASS: "..name)end
local db,unit
Test("fixed navigation uses equal columns, white/yellow captions and one active underline",function()
    db,unit=Init();Check("appearance",true)
    local data=h.Copy(db);local body=Body();local a,r,t=Counts()
    for _=1,20 do
        for _,key in ipairs({"geometry","behavior","appearance","appearance"})do Click(key);Check(key,true)end
    end
    local aa,rr,tt=Counts();assert(a==aa and r==rr and t==tt and Body()==body)
    h.Equal(db,data)
end)
Test("disabled category stays visible and refuses clicks without changing canonical state",function()
    Select("HealthBar");Check("appearance",true)
    assert(Tabs().geometry.disabled and not Tabs().behavior.disabled)
    Click("geometry");Check("appearance",true)
    Select("NormalAbsorbBar");Check("appearance",true)
end)
Test("fixed navigation remains flat with available, missing, invalid or throwing atlas APIs",function()
    local data=h.Copy(db)
    for _,spec in ipairs(specs)do
        missing=spec[2];Refresh();Check("appearance",false)
        Click("geometry");Check("geometry",false);Click("appearance")
        missing=nil;Refresh();Check("appearance",true)
    end
    invalid=specs[1][2];Refresh();Check("appearance",false);invalid=nil
    throwAtlas=specs[2][2];Refresh();Check("appearance",false);throwAtlas=nil
    C_Texture=nil;Refresh();Check("appearance",false)
    C_Texture={GetAtlasInfo=Atlas};Refresh();Check("appearance",true);h.Equal(db,data)
end)
Test("German labels fit stable equal columns in a narrow Workspace",function()
    local old={ns.L.EDITOR_PROPERTY_APPEARANCE,ns.L.SECTION_SIZE_POSITION,ns.L.SECTION_BEHAVIOR}
    ns.L.EDITOR_PROPERTY_APPEARANCE="Aussehen";ns.L.SECTION_SIZE_POSITION="Größe & Position";ns.L.SECTION_BEHAVIOR="Verhalten"
    local width=UIParent:GetWidth();UIParent:SetWidth(600);Build();Drain();Check("appearance",true)
    assert(Tabs().geometry.frame._fpNormalAbsorbTab.label:GetText()=="Größe & Position")
    UIParent:SetWidth(width)
    ns.L.EDITOR_PROPERTY_APPEARANCE,ns.L.SECTION_SIZE_POSITION,ns.L.SECTION_BEHAVIOR=table.unpack(old)
    Build();Drain();Check("appearance",true)
end)
Test("release hides all art, stale clicks remain invalid, pooled ordinary Buttons retain native chrome",function()
    local old=Tabs();local click=old.geometry.events.OnClick
    -- Root now has tabs too; release the existing property owner before testing reuse.
    Host()._focalPointPropertyNavigation:ReleaseChildren()
    Body():ReleaseChildren()
    for _,tab in pairs(old)do
        for _,r in pairs(tab.frame._fpNormalAbsorbTab)do assert(not r:IsShown())end
        assert(tab.text:GetAlpha()==1)
    end
    local before=state.Get().inspectorPropertyGroup;click();assert(state.Get().inspectorPropertyGroup==before)
    local ordinary=h.ui.ace:Create("Button");ordinary:SetText("Ordinary")
    assert(ordinary.text:GetAlpha()==1 and ordinary.text:GetText()=="Ordinary")
    if ordinary.frame._fpNormalAbsorbTab then
        for _,r in pairs(ordinary.frame._fpNormalAbsorbTab)do assert(not r:IsShown())end
    end
    h.ui.ace:Release(ordinary);Refresh();Check("appearance",true)
end)
Test("Close/Reopen, Arrange and regular rebuild preserve one owner and current tab projection",function()
    local host=Host();Click("geometry");Refresh();Check("geometry",true)
    host.closebutton:GetScript("OnClick")(host.closebutton);Drain();assert(Build()==host);Drain();Check("geometry",true)
    host.closebutton:GetScript("OnClick")(host.closebutton);Drain();assert(Build()==host);Drain();Check("geometry",true)
end)
Test("scrolling only moves property content below the fixed navigation",function()
    local width,height=UIParent:GetWidth(),UIParent:GetHeight()
    UIParent:SetSize(620,300);Build();Drain();Click("appearance");Check("appearance",false)
    local host=Host();local navigation=host._focalPointPropertyNavigation
    local scroll=host._focalPointPropertyScroll
    local before={}
    for i=1,navigation.frame:GetNumPoints()do before[i]={navigation.frame:GetPoint(i)}end
    scroll:SetScroll(1000)
    assert(scroll.status.offset>0,"test must move the property content, not just set an inert scroll value")
    assert(navigation.frame:GetNumPoints()==#before)
    for i,point in ipairs(before)do
        local actual={navigation.frame:GetPoint(i)}
        for j=1,5 do assert(actual[j]==point[j],"scroll moved fixed navigation anchors")end
    end
    assert(navigation.frame:GetParent()==scroll.frame:GetParent())
    assert(scroll.frame.points.TOPLEFT.relative==navigation.frame)
    Click("geometry");Check("geometry",false)
    assert(scroll.status.scrollvalue==0)
    UIParent:SetSize(width,height);Build();Drain()
end)
Test("non-fixed property navigation preserves native atlas and fallback presentation",function()
    Select("NormalAbsorbBar")
    local ace=h.ui.ace
    for _,available in ipairs({true,false})do
        missing=not available and specs[1][2] or nil
        local host=ace:Create("SimpleGroup");host:SetWidth(568)
        ns.GUI.Editor.Inspector.BuildProperties(host,state.Get(),{isCurrentBuild=function()return true end})
        local found=0
        local function Walk(w)
            local key=w:GetUserData("normalAbsorbPropertyTab")
            if key then
                found=found+1
                local s=w.frame._fpNormalAbsorbTab
                for _,spec in ipairs(specs)do
                    local r=s[spec[1]]
                    if available then
                        assert(r and r.atlas==spec[2] and r.rotation==math.pi)
                        assert(r:IsShown()==(spec[3]==(key==state.Get().inspectorPropertyGroup)))
                    else assert(not r or not r:IsShown())end
                end
                assert(s.fill:IsShown()==not available)
            end
            for _,c in ipairs(w.children or {})do Walk(c)end
        end
        Walk(host);assert(found==3);ace:Release(host)
    end
    missing=nil;Refresh();Check(state.Get().inspectorPropertyGroup,false)
end)
C_Texture=oldAtlas;native.SetRotation=oldRotation
assert(#h.ui.env.errors==0,table.concat(h.ui.env.errors,"\n"))
print("Customize Tab Art: "..count.." groups PASS")
