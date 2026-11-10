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
        if group:GetUserData("normalAbsorbPropertyGroup")==tab and group:GetUserData("normalAbsorbPropertyContent")then
            assert(group.type=="InlineGroup" and #group.children>0,"missing or empty frame")
            local padding=assert(group._fpSectionPadding)
            assert(padding.left==16 and padding.right==16 and padding.top==27 and padding.bottom==13)
            assert(group.frame:IsShown()==(p.state.Get().inspectorPropertyGroup==tab))
            result[#result+1]=group.titletext:GetText()
            p.Walk(group,function(w)assert(not w:GetUserData("flatPropertyHeading"),"duplicate flat section title")end)
        end
    end
    return table.concat(result,",")
end

local count=0
local function Test(name,fn)fn();count=count+1;print("PASS: "..name)end
Test("Class Power frames follow Size, Anchor and Growth without changing field bindings",function()
    Start("expert");Click("geometry")
    assert(Headings("class_power","geometry")=="Size,Anchor,Growth")
    p.Control("Height","FPCompactSlider"):Fire("OnValueChanged",23);p.Drain()
    local _,unit=Current();assert(unit.classPowerBarHeight==23)
    p.Control("Anchor From","Dropdown"):Fire("OnValueChanged","LEFT");p.Drain()
    assert(unit.classPowerBarPoint=="LEFT")
    p.Control("Offset X","FPCompactSlider"):Fire("OnValueChanged",16);p.Drain()
    assert(unit.classPowerBarOffsetX==16)
end)
Test("tab switches allocate no headings and create no singleton Actions area",function()
    local window,_,db=Current();local before=p.h.Copy(db)
    local a,r,t=p.Stats()
    for _=1,20 do
        for _,key in ipairs({"appearance","geometry","behavior"})do
            Click(key)
            assert(Headings("class_power","geometry")=="Size,Anchor,Growth")
            local actions=0
            for _,group in ipairs(Body("class_power").children)do
                if group:GetUserData("normalAbsorbObjectActions")then
                    actions=actions+1;assert(group.frame:IsShown())
                    assert(not group:GetUserData("normalAbsorbPropertyGroup"))
                    p.Walk(group,function(w)assert(not w:GetUserData("flatPropertyHeading"))end)
                end
            end
            assert(actions==0)
        end
    end
    local aa,rr,tt=p.Stats();assert(a==aa and r==rr and t==tt)
    p.h.Equal(db,before)
    assert(window==Current())
end)
Test("conditional and single-control groups retain one nonempty Behavior frame",function()
    Start("quick")
    assert(Headings("class_power","geometry")=="Size,Anchor,Growth")
    assert(Headings("class_power","behavior")=="Behavior")
    local window,unit=Current()
    unit.alternativePowerBarPresent=true;unit.showAlternativePowerBar=true
    unit.castBarPresent=true;unit.showCastBar=true
    for _,item in ipairs({{"HealthBar","health"},{"PowerBar","power"},{"AlternativePowerBar","alt_power"},
        {"NormalAbsorbBar","absorbs"},{"HealingAbsorbBar","absorbs"},{"CastBar","cast"}})do
        p.Select(item[1])
        for _,key in ipairs({"appearance","geometry","behavior"})do Headings(item[2],key)end
        assert(Headings(item[2],"behavior")=="Behavior")
        local expected={health="",power="Size,Anchor",alt_power="Size",absorbs="Size,Anchor,Growth",cast="Size,Anchor"}
        assert(Headings(item[2],"geometry")==expected[item[2]],item[1].." geometry frames")
    end
    p.Select("NormalAbsorbBar")
    assert(Headings("absorbs","geometry")=="Size,Anchor,Growth")
    window.closebutton:GetScript("OnClick")(window.closebutton);p.Drain()
    p.Build();p.Select("ClassPowerBar")
    assert(Headings("class_power","geometry")=="Size,Anchor,Growth")
end)
Test("all singleton tabs keep framed order and original Behavior rows in both stored modes",function()
    for _,expert in ipairs({false,true})do
        Start(expert and "quick" or "expert")
        local _,unit,db=Current()
        db.profile={General={ExpertMode=expert}}
        unit.alternativePowerBarPresent=true;unit.showAlternativePowerBar=true
        unit.castBarPresent=true;unit.showCastBar=true
        p.controller.RefreshActiveProperties();p.Drain()
        for _,item in ipairs({
            {"HealthBar","health","","Reverse Fill"},
            {"PowerBar","power","Size,Anchor","Show,Reverse Fill"},
            {"AlternativePowerBar","alt_power","Size","Show,Reverse Fill"},
            {"NormalAbsorbBar","absorbs","Size,Anchor,Growth","Show"},
            {"HealingAbsorbBar","absorbs","Size,Anchor,Growth","Show"},
            {"ClassPowerBar","class_power","Size,Anchor,Growth","Show"},
            {"CastBar","cast","Size,Anchor","Show,Show Cast Bar Icon"},
        })do
            p.Select(item[1]);Click("behavior")
            assert(Headings(item[2],"behavior")=="Behavior")
            assert(Headings(item[2],"geometry")==item[3])
            local labels={}
            for _,group in ipairs(Body(item[2]).children)do
                if group:GetUserData("normalAbsorbPropertyGroup")=="behavior" and group:GetUserData("normalAbsorbPropertyContent")then
                    for _,row in ipairs(group.children)do
                        local label=(row.children or {})[1]
                        assert(label and label.type=="Label")
                        labels[#labels+1]=label.label:GetText()
                    end
                end
            end
            assert(table.concat(labels,",")==item[4],item[1].." Behavior controls")
            local before=p.h.Copy(db);local a,r,t=p.Stats()
            for _,tab in ipairs({"appearance","geometry","behavior"})do Click(tab)end
            local aa,rr,tt=p.Stats();assert(a==aa and r==rr and t==tt)
            p.h.Equal(db,before)
        end
        assert(db.profile.General.ExpertMode==expert)
    end
end)
Test("instances use the same Health frames without duplicate flat section labels",function()
    Start("expert")
    local m=p.ns.LayoutMutations.SegmentedBars
    local result=m.Add(assert(m.CaptureContext("player")),{enabled=true,dataSource={id="runes",scope="player"},anchorTo="Frame"})
    assert(result.ok,result.errorCode)
    assert(p.selection.SelectObject({kind="segmentedBar",unit="player",objectKey=result.id}));p.Drain()
    assert(Headings("segmented_bars","geometry")=="Size,Anchor,Growth")
    for _=1,10 do
        p.controller.RefreshActiveProperties();p.Drain()
        assert(Headings("segmented_bars","geometry")=="Size,Anchor,Growth")
        p.Select("HealthBar");p.Select("ClassPowerBar")
        assert(Headings("class_power","geometry")=="Size,Anchor,Growth")
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
