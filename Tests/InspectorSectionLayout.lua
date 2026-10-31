-- Actual Workspace, builders, selection, mutations and AceGUI pooling.
local function Read(path)
    local f=assert(io.open(path));local text=f:read("*a");f:close();return text
end
local source=Read("Tests/ClassResourcePropertyGroups.lua")
local stop=assert(source:find("\nlocal count=0",1,true))
local p,Start,Body,Click,Current=assert(load(source:sub(1,stop)..[[
return p,Start,Body,Click,function()return window,unit,db end
]],"@InspectorSectionLayout/Workspace"))()
local function Headings(section,tab)
    local result={}
    for _,group in ipairs(Body(section).children)do
        if group:GetUserData("normalAbsorbPropertyGroup")==tab then
            for i,child in ipairs(group.children)do
                local title=child:GetUserData("flatPropertyHeading")
                if title then
                    result[#result+1]=title
                    local following=group.children[i+1]
                    assert(following and not following:GetUserData("flatPropertyHeading"),"empty section")
                    assert(child.type=="Label" and child.frame:GetHeight()>0)
                    local _,size=child.label:GetFont();assert(size==14,"section titles must use 14px")
                    assert(not child.frame._fpFlatSectionLine,"decorative section divider returned")
                    if i>1 then
                        assert(group.children[i-1].frame:GetHeight()==8,"subsection needs space before its title")
                    end
                    local color=NORMAL_FONT_COLOR or p.ns.GUI.Helpers.TextStyles.Get("strongHeading")
                    p.h.Equal(child.label.lastSetTextColor,{color.r,color.g,color.b,1})
                end
            end
        end
    end
    return table.concat(result,",")
end
local count=0
local function Test(name,fn)fn();count=count+1;print("PASS: "..name)end
Test("Class Power sections follow Size, Anchor, Position, Growth without changing field bindings",function()
    Start("expert");Click("geometry")
    assert(Headings("class_power","geometry")=="Size,Anchor,Position,Growth")
    p.Control("Height","FPCompactSlider"):Fire("OnValueChanged",23);p.Drain()
    local _,unit=Current();assert(unit.classPowerBarHeight==23)
    p.Control("Anchor From","Dropdown"):Fire("OnValueChanged","LEFT");p.Drain()
    assert(unit.classPowerBarPoint=="LEFT")
    p.Control("Offset X","FPCompactSlider"):Fire("OnValueChanged",16);p.Drain()
    assert(unit.classPowerBarOffsetX==16)
end)
Test("tab switches allocate no headings and actions remain outside every property tab",function()
    local window,_,db=Current();local before=p.h.Copy(db)
    local a,r,t=p.Stats()
    for _=1,20 do
        for _,key in ipairs({"appearance","geometry","behavior"})do
            Click(key)
            assert(Headings("class_power","geometry")=="Size,Anchor,Position,Growth")
            local actions=0
            for _,group in ipairs(Body("class_power").children)do
                if group:GetUserData("normalAbsorbObjectActions")then
                    actions=actions+1;assert(group.frame:IsShown())
                    assert(not group:GetUserData("normalAbsorbPropertyGroup"))
                    p.Walk(group,function(w)assert(not w:GetUserData("flatPropertyHeading"))end)
                end
            end
            assert(actions==1)
        end
    end
    local aa,rr,tt=p.Stats();assert(a==aa and r==rr and t==tt)
    p.h.Equal(db,before)
    assert(window==Current())
end)
Test("conditional and single-control groups produce no empty or redundant headings",function()
    Start("quick")
    assert(Headings("class_power","geometry")=="Size,Anchor,Position,Growth")
    assert(Headings("class_power","behavior")=="")
    local window,unit=Current()
    unit.alternativePowerBarPresent=true;unit.showAlternativePowerBar=true
    unit.castBarPresent=true;unit.showCastBar=true
    for _,item in ipairs({{"HealthBar","health"},{"PowerBar","power"},{"AlternativePowerBar","alt_power"},
        {"NormalAbsorbBar","absorbs"},{"HealingAbsorbBar","absorbs"},{"CastBar","cast"}})do
        p.Select(item[1])
        for _,key in ipairs({"appearance","geometry","behavior"})do Headings(item[2],key)end
        assert(Headings(item[2],"behavior")=="")
    end
    p.Select("NormalAbsorbBar")
    assert(Headings("absorbs","geometry")=="Size,Anchor,Position,Growth")
    window.closebutton:GetScript("OnClick")(window.closebutton);p.Drain()
    p.Build();p.Select("ClassPowerBar")
    assert(Headings("class_power","geometry")=="Size,Anchor,Position,Growth")
end)
Test("instances use the same sections and reuse ordinary Labels without divider regions",function()
    Start("expert")
    local m=p.ns.LayoutMutations.SegmentedBars
    local result=m.Add(assert(m.CaptureContext("player")),{enabled=true,dataSource={id="runes",scope="player"},anchorTo="Frame"})
    assert(result.ok,result.errorCode)
    assert(p.selection.SelectObject({kind="segmentedBar",unit="player",objectKey=result.id}));p.Drain()
    assert(Headings("segmented_bars","geometry")=="Size,Anchor,Position,Growth")
    for _=1,10 do
        p.controller.RefreshActiveProperties();p.Drain()
        assert(Headings("segmented_bars","geometry")=="Size,Anchor,Position,Growth")
        p.Select("HealthBar");p.Select("ClassPowerBar")
        assert(Headings("class_power","geometry")=="Size,Anchor,Position,Growth")
        assert(p.selection.SelectObject({kind="segmentedBar",unit="player",objectKey=result.id}));p.Drain()
    end
    local window=Current()
    p.Walk(window._focalPointPropertyScroll,function(w)
        if w.type=="Label" then
            assert(not w.frame._fpFlatSectionLine,"section divider leaked into a pooled Label")
        end
    end)
end)
print("Inspector Section Layout: "..count.." groups PASS")
