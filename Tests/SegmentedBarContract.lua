-- lua54 Tests/SegmentedBarContract.lua
-- Detached stores only; real public transfer routing and atomic commit.
local file=assert(io.open("Tests/LayoutTransferEntityCommit.lua","r"));local source=file:read("*a");file:close()
local stop=assert(source:find("for failure=1,3 do",1,true))
local ns,Fixture,Copy,Equal,Target,Generator=assert(load(source:sub(1,stop-1)..
    "\nreturn ns,Fixture,Copy,Equal,Target,Generator","@SegmentedBarContract/Fixture"))()
local S,T,N,C=ns.LayoutService,ns.LayoutTransfer,ns.LayoutTransferVNext,ns.LayoutTransferCodec
local count=0
local function Test(name,fn)fn();count=count+1;print("PASS: "..name)end
local function Records()
    return {
        {id="segmented-bar-main",enabled=true,dataSource={id="runes",scope="player"},anchorTo="Frame",
         width=180,height=14,spacing=2,point="TOPLEFT",relativePoint="BOTTOMLEFT",offsetX=3,offsetY=-9,
         growth="LEFT_TO_RIGHT",color={.2,.3,.4,0}},
        {id="segmented-bar-copy",enabled=false,dataSource={id="runes",scope="player"},
         anchorTo="SegmentedBar:segmented-bar-main",width=220,height=16,growth="RIGHT_TO_LEFT"},
    }
end
local function Layout(records)
    local db,layout=Fixture();layout.payload.Units.player.segmentedBars=records
    return db,layout
end
local function Diagnostic(reason)
    assert(type(reason)=="string" and reason:find("segmented-bars-invalid:",1,true),tostring(reason))
    assert(reason:find("Units.",1,true) and reason:find("segmentedBars",1,true),reason)
end
local function BadPrepared(result)
    assert(not result.ready and not result.preparedLayout and not result.recordsToCreate and not result.document)
    assert(#result.diagnostics>0);Diagnostic(result.diagnostics[1].errorCode)
end
Test("pure validator accepts absence, empty and two ordered records without mutation",function()
    assert(S.ValidateSegmentedBars(nil,"target"));assert(S.ValidateSegmentedBars({},"target"))
    local records=Records();local before=Copy(records)
    assert(S.ValidateSegmentedBars(records,"player"));Equal(records,before)
    records[1].dataSource={id="arcaneCharges",scope="player"}
    assert(S.ValidateSegmentedBars(records,"player"))
    records[1].dataSource={id="chi",scope="player"}
    assert(S.ValidateSegmentedBars(records,"player"))
    records[1].dataSource={id="comboPoints",scope="player"}
    assert(S.ValidateSegmentedBars(records,"player"))
    records=Records()
    records[1].enabled=false;assert(S.ValidateSegmentedBars(records,"player"))
    records[1],records[2]=records[2],records[1];assert(S.ValidateSegmentedBars(records,"player"))
    assert(records[1].id=="segmented-bar-copy")
end)
local invalid={
    function(r)r[2].id=r[1].id end,
    function(r)r[1].id="bad:id"end,
    function(r)r[1]=false end,
    function(r)r[1].enabled="true"end,
    function(r)r[1].dataSource="runes"end,
    function(r)r[1].dataSource.id="unknown-source"end,
    function(r)r[1].dataSource.scope="target"end,
    function(r)r[1].dataSource.spellId=123 end,
    function(r)r[1].anchorTo="SegmentedBar:segmented-bar-missing"end,
    function(r)r[1].anchorTo="SegmentedBar:"..r[1].id end,
    function(r)r[1].anchorTo="SegmentedBar:"..r[2].id end,
    function(r)r[1].anchorTo="HealthBar"end,
    function(r)r[1].width=-1 end,
    function(r)r[1].point="INVALID"end,
    function(r)r[1].growth="UP"end,
    function(r)r[1].color[4]=2 end,
    function(r)r[1].color[5]=0 end,
    function(r)r[1].timer={remaining=5}end,
    function(r)r[1]=nil end,
    function(r)r.extra=true end,
}
Test("all transfer entries reject malformed records and preserve target roots and contents",function()
    for _,change in ipairs(invalid)do
        local records=Records();change(records)
        local db,layout=Layout(records);local original=Copy(layout)
        local ok,reason=T.ValidateEntityPayload(layout.payload);assert(not ok);Diagnostic(reason)
        local encoded,why=N.Export(layout,db);assert(not encoded);Diagnostic(why)
        ns.db=db;db.global.UserLayouts["layout:source"]=layout
        encoded,why=T.Export("layout:source");assert(not encoded);Diagnostic(why)
        local document={transferSchema=2,formatVersion=2,addonVersion="test",name="Invalid",
            payload=layout.payload,templates={}}
        encoded=assert(C.Encode(document))
        local target=Target();local before=Copy(target)
        local layouts,templates=target.global.UserLayouts,target.global.TextTemplates
        BadPrepared(N.PrepareImport(encoded,target));Equal(target,before)
        local imported,err=T.Import(encoded);assert(not imported);Diagnostic(err)
        Equal(target,before);assert(target.global.UserLayouts==layouts and target.global.TextTemplates==templates)
        -- Legacy entry validates only this extension before E3, without changing old text rules.
        local legacy={transferSchema=1,formatVersion=1,addonVersion="old",name="Invalid",
            payload={Units={player={segmentedBars=records}},TextTemplates={}}}
        BadPrepared(N.ConvertLegacyDocument(legacy,target,Generator()))
        BadPrepared(N.PrepareLegacyImport(assert(C.Encode(legacy)),target,Generator()))
        imported,err=T.Import(assert(C.Encode(legacy)),{generator=Generator()});assert(not imported);Diagnostic(err)
        Equal(target,before);Equal(layout,original)
    end
end)
Test("invalid collection, unit, metadata, nonfinite values and long cyclic graph fail closed",function()
    for _,value in ipairs({false,"bad",42})do
        local ok,reason=S.ValidateSegmentedBars(value,"player");assert(not ok);Diagnostic(reason)
        local _,layout=Layout(value);ok,reason=T.ValidateEntityPayload(layout.payload);assert(not ok);Diagnostic(reason)
        assert(not pcall(S.CopyPayload,layout.payload))
    end
    local r=Records();assert(not S.ValidateSegmentedBars(r,"target"))
    local _,layout=Layout(r);layout.payload.Units.target=layout.payload.Units.player;layout.payload.Units.player=nil
    local ok,reason=T.ValidateEntityPayload(layout.payload);assert(not ok);Diagnostic(reason)
    for _,value in ipairs({0/0,math.huge,-math.huge})do r=Records();r[1].offsetX=value;assert(not S.ValidateSegmentedBars(r,"player"))end
    r=Records();setmetatable(r[1],{});assert(not S.ValidateSegmentedBars(r,"player"))
    r=Records();r[1].dataSource=r[1];assert(not S.ValidateSegmentedBars(r,"player"))
    r={};for i=1,500 do r[i]={id="segmented-bar-"..i,enabled=true,dataSource={id="runes",scope="player"},
        anchorTo=i==500 and "Frame" or "SegmentedBar:segmented-bar-"..(i+1)}end
    assert(S.ValidateSegmentedBars(r,"player"));r[500].anchorTo="SegmentedBar:segmented-bar-1"
    assert(not S.ValidateSegmentedBars(r,"player"))
end)
Test("copy and materialization replace collection wholesale; absent stays absent",function()
    local records=Records();local defaults={segmentedBars=Copy(records),decorations={{id="decoration-1"}},Texts={}}
    for _,materialize in ipairs({S.MaterializeUnit,S.MaterializeLegacyUnit})do
        local empty=materialize(defaults,{segmentedBars={}},"player");assert(next(empty.segmentedBars)==nil)
        local absent=materialize(defaults,{},"player");assert(absent.segmentedBars==nil)
        local one={Copy(records[1])};one[1].color=nil;one[1].width=250
        local result=materialize(defaults,{segmentedBars=one},"player")
        Equal(result.segmentedBars,one);assert(result.segmentedBars~=one and result.segmentedBars[1]~=one[1])
        assert(result.segmentedBars[1].color==nil and #result.segmentedBars==1)
    end
    local _,layout=Layout(records);local copied=S.CopyPayload(layout.payload)
    -- CopyPayload retains its existing presence normalization for other fields.
    Equal(copied.Units.player.segmentedBars,records);assert(copied.Units.player.segmentedBars~=records)
    copied.Units.player.segmentedBars[1].width=400;assert(records[1].width==180)
    local normalized=S.NormalizePayload({Units={player={}}},{Units={player=defaults}})
    assert(normalized.Units.player.segmentedBars==nil)
    local merged={ordinary={1,2}};S.MergeInto(merged,{ordinary={}});assert(#merged.ordinary==2)
end)
Test("public and legacy roundtrip preserve records, order, IDs and surrounding extensions",function()
    for _,records in ipairs({{},Records()})do
        local db,layout=Layout(records);layout.payload.Units.player.extension={custom=true}
        layout.payload.Units.player.decorations={{id="decoration-1",enabled=false,anchorTo="HealthBar"}}
        local before=Copy(layout);ns.db=db;db.global.UserLayouts["layout:source"]=layout
        local encoded=assert(T.Export("layout:source"));local target=Target()
        local prepared=N.PrepareImport(encoded,target);assert(prepared.ready)
        local ok,id=T.Import(encoded);assert(ok,id);Equal(target.global.UserLayouts[id].payload,layout.payload)
        Equal(layout,before)
        local legacy={transferSchema=1,formatVersion=1,addonVersion="old",name="Old",
            payload={Units={player={segmentedBars=records,Texts={}}},TextTemplates={}}}
        target=Target();ok,id=T.Import(assert(C.Encode(legacy)),{generator=Generator()});assert(ok,id)
        Equal(target.global.UserLayouts[id].payload.Units.player.segmentedBars,records)
    end
end)
Test("valid collection retains atomic import recovery at every existing publication write",function()
    local db,layout=Layout(Records());local encoded=assert(N.Export(layout,db))
    for failure=1,3 do
        local target=Target();local before=Copy(target);local root=target.global.UserLayouts
        local ok,reason=T.Import(encoded,{testCommitFailureAt=failure})
        assert(not ok and reason=="store-write-failed",tostring(reason));Equal(target,before)
        assert(target.global.UserLayouts==root)
    end
end)
Test("shipped defaults and built-ins gain no implicit instances",function()
    local defaults=ns:GetDefaultDB()
    for _,unit in pairs(defaults.profile.Units)do assert(unit.segmentedBars==nil)end
    local result=S.NormalizePayload({Units={player={}}},defaults)
    for _,unit in pairs(result.Units)do assert(unit.segmentedBars==nil)end
    assert(S.ValidateSegmentedBarPayload(result))
    for _,id in ipairs({"default","classic","minimal","modern"})do
        local preset=assert(ns.PresetService.GetPreset(id),id)
        for _,unit in pairs(preset.layout.Units)do assert(unit.segmentedBars==nil,id)end
        assert(S.ValidateSegmentedBarPayload(preset.layout))
    end
end)
print("Segmented Bar Contract: "..count.." groups PASS")
