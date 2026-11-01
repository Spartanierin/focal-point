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
        assert(tabWidth>=s.label:GetStringWidth()+16)
        local _,size=s.label:GetFont();assert(size==13 and tab.frame:GetHeight()==30)
        width=width+tabWidth
        for _,spec in ipairs(specs)do
            local r=s[spec[1]]
            if art then
                assert(r and r.atlas==spec[2] and r.rotation==math.pi)
                assert(r:IsShown()==(spec[3]==(key==active)))
                assert(r:GetAlpha()==(tab.disabled and .35 or 1))
            else assert(not r or not r:IsShown(),"art leaked into fallback")end
        end
        assert(s.fill:IsShown()==not art)
        assert(s.bottom:IsShown()==(not art and key~=active))
        if art then
            assert(s.artRightActive.points.BOTTOMLEFT.relative==tab.frame and s.artRightActive.points.BOTTOMLEFT.x==-7)
            assert(s.artRight.points.BOTTOMLEFT.x==-6)
            assert(s.artMiddleActive.points.LEFT.relative==s.artRightActive)
            assert(s.artMiddleActive.points.RIGHT.relative==s.artLeftActive)
            assert(s.artMiddleActive.lastSetHorizTile[1] and not s.artMiddleActive.lastSetVertTile[1])
            assert(s.label.points.LEFT.y==(key==active and 0 or -3))
        end
    end
    local navigation=tabs.appearance.parent
    assert(navigation.frame:GetHeight()-tabs.appearance.frame:GetHeight()==10,
        "tab strip must reserve exactly 10px before Properties")
    assert(navigation:GetUserData("table").spaceH==(art and 1 or 0))
    assert(navigation.frame._fpNormalAbsorbTabBaseline:IsShown()==not art)
    assert(math.abs(navigation.frame:GetWidth()-width-(art and 2 or 0))<.5,
        "tabs must fill Properties width without overflowing")
    assert(state.Get().inspectorPropertyGroup==active)
end
local function Click(key)Tabs()[key]:Fire("OnClick");Drain()end
local function Refresh()controller.RefreshActiveProperties();Drain()end
local count=0
local function Test(name,fn)fn();count=count+1;print("PASS: "..name)end
local db,unit
Test("first build uses top-oriented Blizzard art and one caption with canonical selection",function()
    db,unit=Init();Check("appearance",true)
    local data=h.Copy(db);local body=Body();local a,r,t=Counts()
    for _=1,20 do
        for _,key in ipairs({"geometry","behavior","appearance","appearance"})do Click(key);Check(key,true)end
    end
    local aa,rr,tt=Counts();assert(a==aa and r==rr and t==tt and Body()==body)
    h.Equal(db,data)
end)
Test("disabled group retains inactive art and refuses clicks without changing canonical state",function()
    Select("HealthBar");Check("appearance",true)
    assert(Tabs().geometry.disabled and not Tabs().behavior.disabled)
    Click("geometry");Check("appearance",true)
    Select("NormalAbsorbBar");Check("appearance",true)
end)
Test("every missing atlas, invalid metadata, API errors and missing API fall back as a complete strip",function()
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
Test("German labels fit a narrow Workspace without fixed profession widths",function()
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
C_Texture=oldAtlas;native.SetRotation=oldRotation
assert(#h.ui.env.errors==0,table.concat(h.ui.env.errors,"\n"))
print("Customize Tab Art: "..count.." groups PASS")
