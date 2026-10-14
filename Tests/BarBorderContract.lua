-- Pure Border v1 data/API tests; detached stores, no renderer or filesystem writes.
local function Read(path)
    local file = assert(io.open(path, "r")); local source = file:read("*a"); file:close(); return source
end
local source = Read("Tests/SegmentedBarContract.lua")
local boundary = assert(source:find('Test("pure validator', 1, true))
local ns, S, T, N, C, Records, Layout, Target, Generator, Copy, Equal = assert(load(source:sub(1, boundary - 1) ..
    "\nreturn ns,S,T,N,C,Records,Layout,Target,Generator,Copy,Equal", "@BarBorderContract/Fixture"))()
assert(loadfile("GUI/Editor/Inspector/InspectorMutations.lua"))("FocalPoint", ns)
local I = ns.InspectorMutations
local prefixes = {"healthBar", "powerBar", "alternativePowerBar", "classPowerBar", "castBar",
    "normalAbsorbBar", "healingAbsorbBar"}
local count = 0
local function Test(name, run) run(); count = count + 1; print("PASS: " .. name) end
local function Valid(unit) return S.ValidateBarBorderPayload({Units={player=unit}}) end
local function NoBorderFields(unit)
    for _, prefix in ipairs(prefixes) do
        assert(unit[prefix .. "BorderWidth"] == nil and unit[prefix .. "BorderColor"] == nil)
    end
end

Test("optional defaults are pure, detached and absent from shipped defaults and built-ins", function()
    local before = Copy(ns:GetDefaultDB())
    local width, color = S.ResolveBarBorder(nil, nil)
    assert(width == 0); Equal(color, {0, 0, 0, 1}); color[4] = 0
    local _, fresh = S.ResolveBarBorder(nil, nil); assert(fresh[4] == 1)
    Equal(ns:GetDefaultDB(), before)
    for _, unit in pairs(before.profile.Units) do NoBorderFields(unit) end
    for _, id in ipairs({"default", "classic", "minimal", "modern"}) do
        for _, unit in pairs(ns.PresetService.GetPreset(id).layout.Units) do NoBorderFields(unit) end
    end
    local payload = S.CopyPayload({Units={player={Texts={}}}})
    NoBorderFields(payload.Units.player); assert(Valid(payload.Units.player))
end)

Test("all seven classic bars and instance styles accept absent, 0, 1 and 5", function()
    for _, width in ipairs({0, 1, 5}) do
        for _, prefix in ipairs(prefixes) do
            local unit = {[prefix .. "BorderWidth"]=width, [prefix .. "BorderColor"]={.1, .2, .3, 0}}
            local before = Copy(unit); assert(Valid(unit)); Equal(unit, before)
            local resolved, rgba = S.ResolveBarBorder(width, unit[prefix .. "BorderColor"], true)
            assert(resolved == width and rgba[4] == 0)
            local copy = S.CopyPayload({Units={player=unit}}).Units.player
            assert(copy[prefix .. "BorderWidth"] == width and copy[prefix .. "BorderColor"][4] == 0)
        end
        local records = Records(); records[1].borderWidth = width; records[1].borderColor = {0, 0, 0, 0}
        assert(S.ValidateSegmentedBars(records, "player"))
        local _, layout = Layout(records); Equal(S.CopyPayload(layout.payload).Units.player.segmentedBars, records)
    end
    assert(S.ValidateSegmentedBars(Records(), "player"))
end)

local badWidths = {-1, 6, .5, "1", false, {}, 0/0, math.huge, -math.huge}
Test("invalid widths including NaN and infinities reject without writes or rounding", function()
    for _, value in ipairs(badWidths) do
        assert(not S.ValidateBarBorder(value)); assert(S.ResolveBarBorder(value) == nil)
        for _, prefix in ipairs(prefixes) do
            local field = prefix .. "BorderWidth"
            local bad = {[field]=value}
            assert(not Valid(bad)); assert(not pcall(S.CopyPayload, {Units={player=bad}}))
            assert(not pcall(S.MaterializeUnit, {}, bad, "player"))
            assert(not pcall(S.MaterializeLegacyUnit, {}, bad, "player"))
            local unit = {[field]=1}; local before = Copy(unit)
            local result = I.SetUnitField({unitKey="player", unitConfig=unit}, field, value)
            assert(not result.ok); Equal(unit, before)
        end
        local records = Records(); records[1].borderWidth = value
        assert(not S.ValidateSegmentedBars(records, "player"))
    end
end)

Test("RGBA uses classic named-channel precedence, strict instance arrays and alpha zero", function()
    local colors = {{0, .5, 1, 0}, {r=0, g=.5, b=1, a=0},
        {[1]=1, [2]=1, [3]=1, [4]=1, r=0, g=.5, b=1, a=0}}
    for _, color in ipairs(colors) do
        local before = Copy(color)
        local width, rgba = S.ResolveBarBorder(nil, color, true)
        assert(width == 0); Equal(rgba, {0, .5, 1, 0}); Equal(color, before)
        for _, prefix in ipairs(prefixes) do assert(Valid({[prefix .. "BorderColor"]=color})) end
    end
    assert(not S.ValidateBarBorder(1, colors[2]))
    local invalid = {false, "white", {}, {1, 1, 1}, {1, 1, 1, -1}, {1, 1, 1, 2}, {1, 1, 1, 0, 0},
        {1, "1", 1, 1}, {1, 1, 1, 0/0}, {1, 1, math.huge, 1}, {r=1, g=1, b=1},
        {r=1, g=1, b=1, a=0, extra=1}, setmetatable({1, 1, 1, 1}, {})}
    for _, color in ipairs(invalid) do
        for _, prefix in ipairs(prefixes) do assert(not Valid({[prefix .. "BorderColor"]=color})) end
        local records = Records(); records[1].borderColor = color
        assert(not S.ValidateSegmentedBars(records, "player"))
    end
end)

Test("classic SetUnitField validates before publication and detaches caller colors", function()
    for _, prefix in ipairs(prefixes) do
        local unit = {}; local context = {unitKey="player", unitConfig=unit}
        local field = prefix .. "BorderColor"; local color = {r=.2, g=.3, b=.4, a=0}
        assert(I.SetUnitField(context, field, color).ok)
        color.r = 1; assert(unit[field].r == .2 and unit[field].a == 0)
        local before = Copy(unit)
        assert(not I.SetUnitField(context, field, {1, 1, 1, -1}).ok); Equal(unit, before)
        assert(I.SetUnitField(context, field, nil).ok); assert(unit[field] == nil)
        assert(I.SetUnitField(context, prefix .. "BorderWidth", 5).ok)
        assert(I.SetUnitField(context, prefix .. "BorderWidth", nil).ok); NoBorderFields(unit)
        assert(I.SetUnitField(context, "unrelated", "unchanged contract").ok)
    end
end)

Test("border fields never supply component presence or alter legacy default materialization", function()
    local defaults = ns:GetDefaultDB().profile.Units.player
    for _, materialize in ipairs({S.MaterializeUnit, S.MaterializeLegacyUnit}) do
        local baseline = materialize(defaults, {}, "player")
        local sourceUnit = {}
        for _, prefix in ipairs(prefixes) do
            sourceUnit[prefix .. "BorderWidth"] = 5; sourceUnit[prefix .. "BorderColor"] = {1, 0, 0, 0}
        end
        local before = Copy(sourceUnit); local result = materialize(defaults, sourceUnit, "player")
        for _, prefix in ipairs(prefixes) do
            assert(result[prefix .. "BorderWidth"] == 5)
            result[prefix .. "BorderWidth"], result[prefix .. "BorderColor"] = nil, nil
        end
        Equal(result, baseline); Equal(sourceUnit, before)
    end
    local unit = {classPowerBarPresent=false, showClassPowerBar=false, classPowerBarBorderWidth=5}
    local result = S.CopyPayload({Units={player=unit}}).Units.player
    assert(result.classPowerBarPresent == false and result.showClassPowerBar == false and result.segmentedBars == nil)
end)

Test("copy and public vNext/legacy roundtrip preserve all borders without format changes", function()
    local records = Records()
    records[1].borderWidth=1; records[1].borderColor={.2,.3,.4,0}
    records[2].borderWidth=5; records[2].borderColor={.8,.7,.6,1}
    local db, layout = Layout(records); local unit = layout.payload.Units.player
    for index, prefix in ipairs(prefixes) do
        unit[prefix .. "BorderWidth"] = index % 6
        unit[prefix .. "BorderColor"] = index % 2 == 0 and {r=.1,g=.2,b=.3,a=0} or {.1,.2,.3,0}
    end
    layout.payload.Units.target = Copy(unit)
    layout.payload.Units.target.segmentedBars = nil
    local before = Copy(layout); local copy = S.CopyPayload(layout.payload)
    copy.Units.player.segmentedBars[1].borderColor[1] = 1; Equal(layout, before)
    ns.db=db; db.global.UserLayouts["layout:source"]=layout
    local encoded=assert(T.Export("layout:source")); local document=assert(C.Decode(encoded))
    assert(document.transferSchema==2 and document.formatVersion==2)
    local target=Target(); local ok,id=T.Import(encoded); assert(ok,id)
    Equal(target.global.UserLayouts[id].payload, layout.payload); Equal(layout, before)
    local legacyUnit=Copy(unit); legacyUnit.Texts={}
    local legacy={transferSchema=1,formatVersion=1,addonVersion="old",name="Borders",
        payload={Units={player=legacyUnit},TextTemplates={}}}
    target=Target(); ok,id=T.Import(assert(C.Encode(legacy)),{generator=Generator()}); assert(ok,id)
    local imported=target.global.UserLayouts[id].payload.Units.player
    for _, prefix in ipairs(prefixes) do
        assert(imported[prefix .. "BorderWidth"] == unit[prefix .. "BorderWidth"])
        Equal(imported[prefix .. "BorderColor"],unit[prefix .. "BorderColor"])
    end
    Equal(imported.segmentedBars, records)
end)

Test("malformed borders reject export and both import routes without publishing partial state", function()
    local changes = {}
    for _, prefix in ipairs(prefixes) do
        changes[#changes+1] = function(unit) unit[prefix .. "BorderWidth"] = 6 end
        changes[#changes+1] = function(unit) unit[prefix .. "BorderColor"] = {1,1,1,-1} end
    end
    changes[#changes+1] = function(unit) unit.segmentedBars[1].borderWidth = .5 end
    changes[#changes+1] = function(unit) unit.segmentedBars[1].borderColor = {1,1,1,2} end
    for _, change in ipairs(changes) do
        local db, layout=Layout(Records()); change(layout.payload.Units.player)
        local before=Copy(layout)
        assert(not T.ValidateEntityPayload(layout.payload)); assert(not N.Export(layout,db))
        ns.db=db; db.global.UserLayouts["layout:source"]=layout; assert(not T.Export("layout:source"))
        assert(not pcall(S.CopyPayload,layout.payload)); assert(not pcall(S.NormalizeLegacyPayload,layout.payload))
        local document={transferSchema=2,formatVersion=2,addonVersion="test",name="Invalid",
            payload=Copy(layout.payload),templates={}}
        local target=Target(); local saved=Copy(target); local root=target.global.UserLayouts
        local ok=T.Import(assert(C.Encode(document))); assert(not ok); Equal(target,saved)
        document.transferSchema=1; document.formatVersion=1; document.templates=nil
        document.payload.TextTemplates={}; document.payload.Units.player.Texts={}
        ok=T.Import(assert(C.Encode(document)),{generator=Generator()}); assert(not ok)
        Equal(target,saved); assert(target.global.UserLayouts==root)
        Equal(layout,before)
    end
end)

-- Reuse the existing real mutation/store/workflow fixture, without running its suites.
source=Read("Tests/SegmentedBarMutations.lua")
boundary=assert(source:find('Test("add, independent',1,true))
local m=assert(load(source:sub(1,boundary-1)..
    "\nreturn {ns=ns,M=M,R=R,Setup=Setup,Context=Context,Add=Add,Reject=Reject}",
    "@BarBorderContract/Mutations"))()
Test("atomic instance styles, duplicate independence, stale contexts and combat protection", function()
    local _,unit=m.Setup(); local a=m.Add(); local b=m.Add(); local stale=m.Context()
    local color={.1,.2,.3,0}
    assert(m.M.SetStyle(m.Context(),a,{borderWidth=1,borderColor=color}).ok)
    color[1]=1; assert(unit.segmentedBars[1].borderColor[1]==.1)
    m.Reject(function()return m.M.SetStyle(stale,a,{borderWidth=5})end,"stale-context")
    assert(m.M.SetStyle(m.Context(),b,{borderWidth=5,borderColor={.8,.7,.6,1}}).ok)
    local duplicate=m.M.Duplicate(m.Context(),a); assert(duplicate.ok)
    assert(m.M.SetStyle(m.Context(),duplicate.id,{borderColor={1,1,1,1}}).ok)
    assert(unit.segmentedBars[1].borderColor[1]==.1)
    local widths={}; for _,record in ipairs(unit.segmentedBars) do widths[record.id]=record.borderWidth end
    assert(widths[a]==1 and widths[b]==5 and widths[duplicate.id]==1)
    for _,value in ipairs(badWidths) do
        m.Reject(function()return m.M.SetStyle(m.Context(),a,{borderWidth=value})end)
    end
    m.Reject(function()return m.M.SetStyle(m.Context(),a,{borderColor={r=1,g=1,b=1,a=0}})end)
    local context=m.Context(); local previous=InCombatLockdown
    InCombatLockdown=function()return true end
    m.Reject(function()return m.M.SetStyle(context,a,{borderWidth=5})end,"combat-blocked")
    InCombatLockdown=previous
    assert(m.M.SetStyle(m.Context(),a,{borderWidth=0}).ok)
end)

print("Bar Border Contract: " .. count .. " groups PASS")
