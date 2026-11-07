-- Real text cache, tag rendering and preview; Blizzard supplies the abbreviation text.
local file=assert(io.open("Tests/TextTemplateEntityRuntime.lua"))
local source=file:read("*a");file:close()
local boundary=assert(source:find('local A="tpl:u:',1,true))
local f=assert(load(source:sub(1,boundary-1).."\nreturn f","@SimulatedHealth/Fixture"))()
local ns=f.ns
local count=0
local function Test(name,fn)fn();count=count+1;print("PASS: "..name)end
local function Eq(a,b)assert(a==b,tostring(a).." ~= "..tostring(b))end
local configs={
    raw={enabled=true,tag="[hp:cur]|[hp:max]|[curhp]|[maxhp]"},
    abbr={enabled=true,tag="[hp:cur:abbr] / [hp:max:abbr]"},
    short={enabled=true,tag="[hp:cur:short]|[hp:max:short]|[curhp:abbr]|[maxhp:abbr]"},
    percent={enabled=true,tag="[hp:perc]"},
    power={enabled=true,tag="[power:cur]|[power:max]"},
}
local unit={enabled=true,Texts=configs}
ns.db={profile={General={}},char={activeLayoutId="layout:health"},global={TextTemplates={},UserLayouts={
    ["layout:health"]={name="Health",formatVersion=2,payload={Units={player=unit}}}}}}
ns.ActiveLayoutResolver.InvalidateActiveRuntimeRoot()
assert(ns.ActiveLayoutResolver.EnsureActiveRuntimeRoot(ns.db))
local frame=CreateFrame("Frame");frame._fpUnit="player";frame.config=unit;frame.Texts={}
for key in pairs(configs)do frame.Texts[key]=frame:CreateFontString()end
local simulation={healthCurrent=12000,healthMax=30000,powerCurrent=55,powerMax=100,powerType=0}
local demo=ns.UnitFrameDemoEnvironment
local originalValues=demo.GetUnitValues
demo.GetUnitValues=function(target)assert(target==frame);return simulation end
local calls={}
local function Native(value)
    assert(type(value)=="number","native abbreviation received formatted text")
    calls[#calls+1]=value
    return "Blizzard("..tostring(value)..")"
end
AbbreviateNumbers=Native
local function Refresh()ns.TextElementLiveValues.Refresh(frame)end
local function Render(key)
    ns.UnitFrame:UpdateTextElement(frame,key)
    assert(not frame._focalPointTextErrors or not frame._focalPointTextErrors[key])
    return frame.Texts[key]:GetText()
end
Test("simulation keeps numeric raw values and all explicit raw/percent tags",function()
    local before=ns.LayoutService.Clone(ns.db)
    UnitHealth=function()error("simulation queried live health")end
    UnitHealthMax=function()error("simulation queried live maximum")end
    Refresh()
    Eq(type(simulation.healthCurrent),"number");Eq(simulation.healthCurrent,12000)
    Eq(frame.LiveValues.healthCurrentRaw,12000);Eq(frame.LiveValues.healthMaxRaw,30000)
    Eq(Render("raw"),"12000|30000|12000|30000");Eq(Render("percent"),"40")
    Eq(Render("power"),"55|100")
    f.Equal(ns.db,before)
end)
Test("abbreviated and short aliases consume exactly Blizzard's returned strings",function()
    Eq(Render("abbr"),"Blizzard(12000) / Blizzard(30000)")
    Eq(Render("short"),"Blizzard(12000)|Blizzard(30000)|Blizzard(12000)|Blizzard(30000)")
    Eq(calls[1],12000);Eq(calls[2],30000)
    for _,value in ipairs({0,999,12000,1000000,1000000000})do
        simulation.healthCurrent=value;Refresh()
        Eq(frame.LiveValues.healthCurrentRaw,value)
        Eq(frame.LiveValues.healthCurrentAbbr,"Blizzard("..tostring(value)..")")
    end
    simulation.healthCurrent=12000;Refresh()
end)
Test("real simulated snapshot and text refresh keep raw values numeric and update abbreviated tags",function()
    local before=ns.LayoutService.Clone(ns.db)
    assert(demo.ApplyFrameSnapshot(nil,frame,{},"detailed","test"))
    Eq(type(frame.TestValues.healthCurrent),"number");Eq(frame.TestValues.healthCurrent,12000)
    ns.UnitFrame:ApplyTestTextValues(frame)
    Eq(Render("abbr"),"Blizzard(12000) / Blizzard(30000)")
    Eq(Render("raw"),"12000|30000|12000|30000")
    Eq(frame.LiveValues.healthCurrentRaw,12000);Eq(frame.LiveValues.healthMaxRaw,30000)
    f.Equal(ns.db,before)
end)
Test("native locale text is retained verbatim and unavailable APIs use existing raw formatting",function()
    AbbreviateNumbers=function()return "12,0 Tsd. "end
    Refresh();Eq(frame.LiveValues.healthCurrentAbbr,"12,0 Tsd. ")
    AbbreviateNumbers=nil;Refresh();Eq(Render("abbr"),"12000 / 30000")
    AbbreviateNumbers=function()error("unavailable formatter")end
    Refresh();Eq(Render("short"),"12000|30000|12000|30000")
    AbbreviateNumbers=function()return {}end;Refresh();Eq(Render("abbr"),"12000 / 30000")
    Eq(frame.LiveValues.healthCurrentRaw,12000);Eq(frame.LiveValues.healthMaxRaw,30000)
    AbbreviateNumbers=Native;Refresh()
end)
Test("template and selected-text preview use native formatting of existing numeric examples",function()
    local before=ns.LayoutService.Clone(ns.UnitFrame:GetTagDatabase())
    Eq(ns.TextElementPreview.BuildTemplatePreview(configs.abbr.tag),"Blizzard(154320) / Blizzard(154320)")
    Eq(ns.UnitFrame:BuildTemplatePreview(configs.short.tag),"Blizzard(154320)|Blizzard(154320)|Blizzard(154320)|Blizzard(154320)")
    Eq(ns.TextElementPreview.BuildTemplatePreview(configs.raw.tag),"154320|154320|[curhp]|[maxhp]")
    local selected=ns.EditorVisualPolicy.IsSelectionPreview
    ns.EditorVisualPolicy.IsSelectionPreview=function(_,ref)return ref.kind=="text" and ref.textKey=="abbr"end
    Eq(Render("abbr"),"Blizzard(154320) / Blizzard(154320)")
    ns.EditorVisualPolicy.IsSelectionPreview=selected
    f.Equal(ns.UnitFrame:GetTagDatabase(),before)
    local n=#calls
    Eq(ns.TextElementPreview.BuildTemplatePreview("[power:cur:abbr]|[hp:perc]"),"100|100")
    Eq(#calls,n)
end)
Test("template fallback and numeric samples remain intact if native abbreviation is unavailable",function()
    AbbreviateNumbers=nil
    Eq(ns.TextElementPreview.BuildTemplatePreview(configs.abbr.tag),"154k / 154k")
    Eq(ns.TextElementPreview.BuildTemplatePreview("[unknown:option]"),"[unknown:option]")
    Eq(type(simulation.healthCurrent),"number")
    AbbreviateNumbers=Native
end)
Test("live prepared health output never calls the simulation formatter",function()
    demo.GetUnitValues=function()return nil end
    ns.guiTestModeEnabled=false;ns.framesUnlocked=false
    frame.TestValues=nil
    frame.LiveValues.healthCurrentAbbr="LIVE CURRENT"
    frame.LiveValues.healthMaxAbbr="LIVE MAXIMUM"
    local n=#calls
    AbbreviateNumbers=function()error("live path used preview abbreviation")end
    UnitHealthPercent=function()return 40 end
    Refresh();Eq(Render("abbr"),"LIVE CURRENT / LIVE MAXIMUM");Eq(#calls,n)
    demo.GetUnitValues=originalValues
end)
assert(#f.env.errors==0,table.concat(f.env.errors,"\n"))
print("Simulated Health Formatting: "..count.." groups PASS")
