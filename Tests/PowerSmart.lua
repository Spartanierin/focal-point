-- lua54 Tests/PowerSmart.lua
-- Real live-value preparation, formatter, token rendering and tag discovery.
-- Native APIs/FontStrings are doubles; Midnight taint behavior needs ingame QA.
local file=assert(io.open("Tests/TextTemplateEntityRuntime.lua"))
local source=file:read("*a");file:close()
local boundary=assert(source:find('local A="tpl:u:',1,true))
local f=assert(load(source:sub(1,boundary-1).."\nreturn f","@PowerSmart/Fixture"))()
local ns,Load=f.ns,f.Load
local count=0
local function Test(name,fn) fn();count=count+1;print("PASS: "..name) end
local function Equal(actual,expected) assert(actual==expected,tostring(actual).." ~= "..tostring(expected)) end
local current,maximum,powerType,percent=78,100,0,78
local reads={}
local function Read(key,value) reads[key]=(reads[key] or 0)+1;return value end
UnitPower=function()return Read("current",current)end
UnitPowerMax=function()return Read("max",maximum)end
UnitPowerType=function()return Read("type",powerType)end
local percentAPI=function()return Read("percent",percent)end
UnitPowerPercent=percentAPI
UnitHealthPercent=function()return 100 end
ns.UnitFramePreview.GetSecondaryPowerTypeForUnit=function()return nil end
local configs={Smart={enabled=true,tag="[power:smart]"},SmartMax={enabled=true,tag="[power:smart:max]"},Cur={enabled=true,tag="[power:cur]"},
    Max={enabled=true,tag="[power:max]"},Perc={enabled=true,tag="[power:perc]"}}
ns.db={profile={General={}},char={activeLayoutId="layout:smart"},global={TextTemplates={},UserLayouts={
    ["layout:smart"]={name="Smart",formatVersion=2,payload={Units={player={enabled=true,Texts=configs}}}}}}}
ns.ActiveLayoutResolver.InvalidateActiveRuntimeRoot()
local frame=CreateFrame("Frame");frame._fpUnit="player";frame.config={enabled=true,Texts=configs};frame.Texts={}
for key in pairs(configs)do frame.Texts[key]=frame:CreateFontString()end
frame.LiveValues={healthCurrentRaw=100,healthMaxRaw=100,healthCurrentSafe=100,healthMaxSafe=100}
local function Render(key)
    ns.UnitFrame:UpdateTextElement(frame,key)
    assert(not frame._focalPointTextErrors or not frame._focalPointTextErrors[key])
    return frame.Texts[key]:GetText()
end
local function Refresh(expected)
    ns.TextElementLiveValues.Refresh(frame)
    Equal(frame.LiveValues.powerSmartText,expected)
    Equal(Render("Smart"),expected)
end

Test("Mana includes percent; current/max/percent tags retain their exact format",function()
    Refresh("78%")
    Equal(Render("Cur"),"78");Equal(Render("Max"),"100");Equal(Render("Perc"),"78")
    Equal(reads.type,1);Equal(reads.current,1);Equal(reads.max,1);Equal(reads.percent,1)
    for _=1,10 do Equal(Render("Smart"),"78%") end
    Equal(reads.type,1);Equal(reads.current,1);Equal(reads.percent,1)
end)
Test("rage, energy and true zero; type switches replace cached text",function()
    powerType,current=1,45;Refresh("45")
    powerType,current=3,82;Refresh("82")
    current=0;Refresh("0")
    powerType,percent=0,0;Refresh("0%")
    powerType,current,percent=0,78,78;Refresh("78%")
end)
Test("missing or secret type never reuses the previous resource output",function()
    powerType=nil;Refresh("--")
    local secret={}
    issecretvalue=function(v)return rawequal(v,secret)end
    powerType=secret;Refresh("--")
    issecretvalue=function()return false end
    local original=UnitPowerType;UnitPowerType=nil;Refresh("--");UnitPowerType=original
    powerType=3;Refresh("78")
end)
Test("known Mana accepts a successfully formatted secret percent without extra reads",function()
    -- Numeric labels model API secrecy while Lua's formatter remains executable.
    -- This proves the admission rule, not native secret propagation.
    powerType,current,maximum,percent=0,78,100,78
    issecretvalue=function(v)return rawequal(v,78)end
    local beforeType,beforeCurrent,beforePercent=reads.type,reads.current,reads.percent
    Refresh("78%");Equal(Render("Perc"),"78");Equal(Render("Cur"),"78")
    Equal(reads.type,beforeType+1);Equal(reads.current,beforeCurrent+1)
    Equal(reads.percent,beforePercent+2) -- Existing renderable + numeric fallback queries.
    issecretvalue=function()return false end
end)
Test("known non-Mana accepts successfully formatted secret current",function()
    powerType,current=3,82
    issecretvalue=function(v)return rawequal(v,82)end
    Refresh("82");Equal(Render("Cur"),"82")
    issecretvalue=function()return false end
end)
Test("a renderable API percent survives the legacy displayed-bar fallback",function()
    powerType,current,maximum,percent=0,78,100,78
    issecretvalue=function(v)return rawequal(v,78)end
    frame.Elements={PowerBar={GetValue=function()return 0 end,GetMinMaxValues=function()return 0,100 end}}
    Refresh("78%")
    Equal(Render("Perc"),"0") -- Do not change the old percent tag in this fix.
    frame.Elements=nil;issecretvalue=function()return false end
end)
Test("prepared secret text stays opaque; percent uses only protected formatting",function()
    local secret=setmetatable({},{__tostring=function()error("secret tostring")end,
        __concat=function()error("secret concat")end,__eq=function()error("secret comparison")end})
    local suffixed={}
    local originalType,originalFormat=type,string.format
    issecretvalue=function(v)return rawequal(v,secret) or rawequal(v,suffixed)end
    -- Model secret string handles at the boundary; never simulate their contents.
    type=function(v)if rawequal(v,secret) or rawequal(v,suffixed)then return "string" end;return originalType(v)end
    local formats=0
    string.format=function(pattern,value,...)
        if rawequal(value,secret)then
            assert(pattern=="%s%%");formats=formats+1;return suffixed
        end
        return originalFormat(pattern,value,...)
    end
    local prepare=f.Upvalue(ns.TextElementLiveValues.Refresh,"PrepareSmartPowerText")
    assert(rawequal(prepare(0,secret,secret,true,true),suffixed));Equal(formats,1)
    assert(rawequal(prepare(3,secret,secret,true,true),secret));Equal(formats,1)
    assert(rawequal(prepare(3,secret,nil,true,true,true),secret))
    Equal(prepare(0,secret,nil,true,true,true),"100%")
    Equal(prepare(0,secret,nil,false,true,true),"--")
    Equal(prepare(secret,secret,secret,true,true),"--")
    Equal(prepare(0,secret,secret,true,false),"--");Equal(formats,1)
    string.format=function()error("formatting rejected")end
    Equal(prepare(0,secret,secret,true,true),"--")
    type,string.format=originalType,originalFormat
    issecretvalue=function()return false end
end)
Test("secret/unrenderable inputs and unavailable APIs are not fabricated zero",function()
    local secret=setmetatable({},{__tostring=function()error("secret text")end})
    issecretvalue=function(v)return rawequal(v,secret)end
    powerType,current,maximum,percent=0,secret,secret,secret;Refresh("--")
    Equal(Render("Perc"),"0") -- Preserve the legacy formatter fallback.
    powerType=3;Refresh("--")
    Equal(Render("Cur"),"0")
    issecretvalue=function()return false end
    current,maximum,percent=82,100,82
    local original=UnitPower;UnitPower=nil;Refresh("--");UnitPower=original
    current=nil;Refresh("--");Equal(Render("Cur"),"0")
    for _,invalid in ipairs({math.huge,0/0,{}})do current=invalid;Refresh("--")end
    current=82;Refresh("82")
end)
Test("format failure is distinguished from a successfully formatted real zero",function()
    local format,large=string.format,BreakUpLargeNumbers
    BreakUpLargeNumbers=function()error("formatter unavailable")end
    string.format=function(pattern,value,...)
        if value==45 and (pattern=="%s" or pattern=="%d") then error("unrenderable")end
        return format(pattern,value,...)
    end
    powerType,current,percent=1,45,45;Refresh("--");Equal(Render("Cur"),"0")
    powerType=0;Refresh("--");Equal(Render("Perc"),"0")
    current,percent=0,0;Refresh("0%")
    powerType=1;Refresh("0")
    string.format,BreakUpLargeNumbers=format,large
end)
Test("Forever without percent API reuses the existing canonical numeric fallback",function()
    UnitPowerPercent=nil;powerType,current,maximum=0,78,100;Refresh("78%")
    current=0;Refresh("0%")
    maximum=0;Refresh("--")
    current,maximum=nil,100;Refresh("--")
    UnitPowerPercent=percentAPI;current,maximum,percent=78,100,78
end)
Test("displayed bar values cannot prove unknown power or replace real API values",function()
    UnitPowerPercent=nil;powerType=0
    frame.Elements={PowerBar={GetValue=function()return 0 end,GetMinMaxValues=function()return 0,100 end}}
    local secret={};issecretvalue=function(v)return rawequal(v,secret)end
    current,maximum=secret,secret;Refresh("--")
    Equal(Render("Perc"),"0") -- Existing tag semantics remain untouched.
    issecretvalue=function()return false end
    current,maximum=78,100;Refresh("--") -- Stale bar, known API: no new calculation.
    current=0;Refresh("0%") -- Actual zero corroborates the prepared percent.
    frame.Elements=nil;UnitPowerPercent=percentAPI;current,maximum,percent=78,100,78
end)
Test("smart maximum uses the actual resource maximum and distinguishes missing from zero",function()
    powerType,current,maximum,percent=0,78,120,65;Refresh("65%")
    Equal(Render("SmartMax"),"100%");Equal(Render("Max"),"120")
    powerType,maximum=3,150;Refresh("78");Equal(Render("SmartMax"),"150")
    maximum=0;Refresh("78");Equal(Render("SmartMax"),"0")
    powerType=0;Refresh("65%");Equal(Render("SmartMax"),"--")
    maximum=nil;Refresh("65%");Equal(Render("SmartMax"),"--");Equal(Render("Max"),"0")
    maximum=100;powerType=nil;Refresh("--");Equal(Render("SmartMax"),"--")
    local original=UnitPowerMax;UnitPowerMax=nil;powerType=0;Refresh("65%")
    Equal(Render("SmartMax"),"--");UnitPowerMax=original
    powerType,current,maximum,percent=0,78,100,78
end)
Test("smart maximum accepts renderable secret max but rejects formatting failure",function()
    maximum=150;issecretvalue=function(v)return rawequal(v,150)end
    Refresh("78%");Equal(Render("SmartMax"),"100%")
    powerType=3;Refresh("78");Equal(Render("SmartMax"),"150")
    local secret=setmetatable({},{__tostring=function()error("unrenderable")end})
    maximum=secret;issecretvalue=function(v)return rawequal(v,secret)end
    Refresh("78");Equal(Render("SmartMax"),"--")
    powerType=0;Refresh("78%");Equal(Render("SmartMax"),"--")
    powerType=secret;Refresh("--");Equal(Render("SmartMax"),"--")
    issecretvalue=function()return false end
    for _,invalid in ipairs({math.huge,0/0,-1})do
        powerType,maximum=0,invalid;Refresh("78%");Equal(Render("SmartMax"),"--")
    end
    powerType,maximum=0,100
end)
Test("explicit demo power types prepare both tags without gameplay queries and restore live values",function()
    local before=reads.type
    ns.guiTestModeEnabled=true;frame.TestValues={healthCurrent=100,healthMax=100,powerCurrent=65,powerMax=100}
    Refresh("--");Equal(reads.type,before)
    Equal(Render("Cur"),"65");Equal(Render("Perc"),"65")
    Equal(Render("SmartMax"),"--")
    frame.TestValues.powerType=0;Refresh("65%");Equal(Render("SmartMax"),"100%")
    frame.TestValues.powerType=3;frame.TestValues.powerCurrent=82;frame.TestValues.powerMax=150
    Refresh("82");Equal(Render("SmartMax"),"150");Equal(reads.type,before)
    ns.guiTestModeEnabled=false;frame.TestValues=nil;Refresh("78%")
    Equal(Render("SmartMax"),"100%")
    local beforeType,beforeMax=reads.type,reads.max
    for _=1,10 do Equal(Render("SmartMax"),"100%") end
    Equal(reads.type,beforeType);Equal(reads.max,beforeMax)
    Equal(ns.TextElementPreview.BuildTextElementPreview(configs.Smart),"78%")
    Equal(ns.TextElementPreview.BuildTemplatePreview("[power:smart] / [power:smart:max]"),"78% / 100%")
end)
Test("real detailed and placeholder demo records contain an explicit synthetic resource type",function()
    local demo=ns.UnitFrameDemoEnvironment
    local before={};for key,value in pairs(reads)do before[key]=value end
    local original=demo.GetCommittedMode
    demo.GetCommittedMode=function()return "detailed" end
    frame._fpUnit="target";Refresh("42%");Equal(Render("SmartMax"),"100%")
    frame._fpUnit="player";Refresh("84");Equal(Render("SmartMax"),"100")
    demo.GetCommittedMode=function()return "placeholder" end
    ns.TextElementLiveValues.Refresh(frame)
    Equal(frame.LiveValues.powerSmartText,"0%");Equal(frame.LiveValues.powerSmartMaxText,"100%")
    Equal(Render("Smart"),"") -- Existing unselected placeholder hides texts.
    local represent=ns.UnitFramePreview.ShouldRepresentInEditor
    ns.UnitFramePreview.ShouldRepresentInEditor=function()return true end
    Equal(Render("Smart"),"78%");Equal(Render("SmartMax"),"100%")
    ns.UnitFramePreview.ShouldRepresentInEditor=represent
    for key,value in pairs(reads)do Equal(value,before[key])end
    demo.GetCommittedMode=original;Refresh("78%");Equal(Render("SmartMax"),"100%")
end)
Test("existing display-power events and dependency refresh consume the new token",function()
    ns.UnitFrame:UpdateTextElements(frame)
    assert(ns.TextElementState.GetDependencies(frame,"Smart").power)
    assert(ns.TextElementState.GetDependencies(frame,"SmartMax").power)
    local queued=0
    local original=ns.TextElementState.QueueRefresh
    ns.TextElementState.QueueRefresh=function(owner,reason,scope,options)
        assert(owner==frame and scope=="texts" and options.textDependencies.power)
        queued=queued+1;ns.TextElementLiveValues.Refresh(owner)
        ns.UnitFrame:UpdateTextElements(owner,options.textDependencies)
    end
    ns.TextElementEvents.Register(frame,{})
    local event=frame.TextEventFrame:GetScript("OnEvent")
    powerType,current,maximum=3,82,150;event(frame.TextEventFrame,"UNIT_DISPLAYPOWER","player");Equal(Render("Smart"),"82");Equal(Render("SmartMax"),"150")
    powerType,percent=0,50;event(frame.TextEventFrame,"UNIT_POWER_UPDATE","player");Equal(Render("Smart"),"50%");Equal(Render("SmartMax"),"100%")
    Equal(queued,2);ns.TextElementState.QueueRefresh=original
end)
Test("Tag Library discovers, searches and inserts smart power with both locales",function()
    for _,locale in ipairs({"enUS","deDE"})do
        GetLocale=function()return locale end
        Load("Locales/"..locale..".lua")
        local context,inserted
        ns.GUI.Pages.TagLibraryView={Show=function(c)context=c end,Refresh=function()end}
        Load("GUI/Pages/TagLibrary/TagLibraryController.lua")
        assert(ns.GUI.Pages.TagLibrary.Open({onApply=function(token)inserted=token;return false end}))
        context.callbacks.onSearchChanged("power:smart")
        Equal(#context.state.visibleEntries,2)
        for _,token in ipairs({"[power:smart]","[power:smart:max]"})do
            context.callbacks.onSearchChanged(token)
            Equal(#context.state.visibleEntries,1)
            local item=context.state.visibleEntries[1]
            Equal(item.description,ns.L[token=="[power:smart]" and "INFO_TAG_DESC_POWER_SMART" or "INFO_TAG_DESC_POWER_SMART_MAX"])
            assert(item.description:find("%%"))
            context.callbacks.onApply();Equal(inserted,token)
        end
    end
end)
print("PowerSmart: "..count.." groups passed")
