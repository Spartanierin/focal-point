-- Run from the repository root: lua54 Tests/TextTemplateEntities.lua
local path = "Engine/Text/Shared/TextTemplateLibrary.lua"
local function Load(db)
    local ns = {db = db}
    assert(loadfile(path))("FocalPoint", ns)
    return ns.TextTemplateLibrary
end
local library = Load()
local passed = 0
local function Test(name, run)
    run()
    passed = passed + 1
    print("PASS: " .. name)
end
local function Equal(a, b)
    if a == b then return true end
    if type(a) ~= "table" or type(b) ~= "table" then return false end
    for k, v in pairs(a) do if not Equal(v, b[k]) then return false end end
    for k in pairs(b) do if a[k] == nil then return false end end
    return true
end
local function Sources(byte)
    return {time = function() return 1700000000 end, uptime = function() return 12.345 end,
        random = function(low, high) assert(low == 0 and high == 255); return byte end}
end
local namespace = string.rep("ab", 16)
local function DB()
    return {global = {TextTemplateIdState = {namespace = namespace}}}
end
local function Id(counter, byte)
    return "tpl:u:" .. namespace .. ":1700000000-12345-" .. string.rep(string.format("%02x", byte or 1), 16) .. ":" .. counter
end
local function Generator(byte) return assert(library.CreateUserTemplateIdGenerator(Sources(byte or 1))) end
local record = {name = "Health Value", content = "[hp:cur]"}

Test("ID contract and user/builtin separation", function()
    local id = assert(Generator():Reserve(DB(), {}))
    assert(id == Id(1) and library.GetTemplateIdKind(id) == "user")
    assert(library.GetTemplateIdKind("tpl:b:health-value") == "builtin")
    for _, value in ipairs({"", " ", "tpl:u:", "tpl:b:", "tpl:b:has space", "layout:A", Id(0), Id("01"), Id("9007199254740992")}) do
        assert(library.GetTemplateIdKind(value) == nil, value)
    end
    assert(library.GetTemplateIdKind(false) == nil)
    assert(not id:find(record.name, 1, true) and not id:find(record.content, 1, true))
end)
Test("same time, increasing counter, reservations and lazy namespace", function()
    local db, reserved, generator = {}, {}, Generator(2)
    assert(next(db) == nil)
    local first = assert(generator:Reserve(db, reserved))
    local second = assert(generator:Reserve(db, reserved))
    assert(first ~= second and first:match(":1$") and second:match(":2$"))
    assert(reserved[first] and reserved[second])
    assert(Equal(db, {global = {TextTemplateIdState = {namespace = string.rep("02", 16)}}}))
end)
Test("copied SavedVariables and reload do not restore session nonce/counter", function()
    local a, b = DB(), DB()
    local first = assert(Generator(1):Reserve(a, {}))
    local second = assert(Generator(2):Reserve(b, {}))
    local reloaded = assert(Generator(3):Reserve(a, {}))
    assert(first == Id(1, 1) and second == Id(1, 2) and reloaded == Id(1, 3))
    assert(Equal(a, b) and a.global.TextTemplateIdState.namespace == namespace)
end)
Test("existing and operation-reserved candidates are skipped", function()
    local db = DB()
    db.global.TextTemplates = {[Id(1)] = record}
    local reserved = {[Id(2)] = false} -- presence, not truthiness, reserves an ID
    local generator = Generator()
    assert(generator:Reserve(db, reserved) == Id(3))
    assert(generator:Reserve(db, reserved) == Id(4))
    assert(reserved[Id(3)] and reserved[Id(4)])
    assert(db.global.TextTemplates[Id(1)] == record and db.global.TextTemplates[Id(3)] == nil)
end)
Test("deterministic injected sources and changed clock/uptime", function()
    assert(Generator():Reserve(DB(), {}) == Generator():Reserve(DB(), {}))
    local sources = Sources(1)
    sources.uptime = function() return 12.346 end
    assert(assert(library.CreateUserTemplateIdGenerator(sources)):Reserve(DB(), {}) ~= Id(1))
    sources = Sources(1); sources.time = function() return 1700000001 end
    assert(assert(library.CreateUserTemplateIdGenerator(sources)):Reserve(DB(), {}) ~= Id(1))
end)
Test("bounded collision failure preserves reservations and advances counter", function()
    local db, reserved, generator = DB(), {}, Generator()
    for i = 1, 128 do reserved[Id(i)] = true end
    local id, reason = generator:Reserve(db, reserved)
    assert(id == nil and reason == "id-collision-limit")
    assert(db.global.TextTemplates == nil and reserved[Id(129)] == nil)
    assert(generator:Reserve(db, reserved) == Id(129))
end)
Test("invalid entropy and invalid state do not persist partial initialization", function()
    for _, key in ipairs({"time", "uptime", "random"}) do
        local sources, db, reserved = Sources(1), {}, {}
        sources[key] = function() error("unavailable") end
        local generator = assert(library.CreateUserTemplateIdGenerator(sources))
        local id, reason = generator:Reserve(db, reserved)
        assert(id == nil and reason == "id-source-unavailable" and next(db) == nil and next(reserved) == nil)
    end
    local sources = Sources(1); sources.random = function() return 256 end
    local db = {}; assert(assert(library.CreateUserTemplateIdGenerator(sources)):Reserve(db, {}) == nil)
    assert(next(db) == nil)
    db = {global = {TextTemplateIdState = {namespace = "broken"}}}
    assert(Generator():Reserve(db, {}) == nil and db.global.TextTemplateIdState.namespace == "broken")
    db = {global = {TextTemplates = "broken"}}
    assert(Generator():Reserve(db, {}) == nil and db.global.TextTemplateIdState == nil)
    assert(Generator():Reserve({}, setmetatable({}, {})) == nil)
end)
Test("module load and ordinary legacy reads are inert; default sources never reseed", function()
    local oldTime, oldUptime, oldRandom, oldSeed = time, GetTime, math.random, math.randomseed
    local calls, db = 0, {}
    local ok, reason = pcall(function()
        time = function() calls = calls + 1; return 1700000000 end
        GetTime = function() calls = calls + 1; return 12.345 end
        math.random = function() calls = calls + 1; return 1 end
        math.randomseed = function() error("must never reseed") end
        local current = Load(db)
        current.ListIntegratedTemplateDefinitions()
        assert(calls == 0 and next(db) == nil)
        local first = assert(current.ReserveUserTemplateId(db, {}))
        assert(current.ReserveUserTemplateId(db, {}) ~= first and calls > 0)
        assert(db.global.TextTemplates == nil)
        local unavailable = Load({}); time = nil
        assert(unavailable.ReserveUserTemplateId({}, {}) == nil)
    end)
    time, GetTime, math.random, math.randomseed = oldTime, oldUptime, oldRandom, oldSeed
    assert(ok, reason)
end)
Test("strict records, lossless content and defensive copies", function()
    assert(library.ValidateTemplateRecord(record))
    local raw = {name = "  Name  ", content = "\0\n  "}
    local copy = assert(library.CopyTemplateRecord(raw))
    assert(copy ~= raw and Equal(copy, raw))
    assert(library.ValidateTemplateRecord({name = "Empty", content = ""})) -- data contract, not editor validation
    for _, bad in ipairs({{}, {name = false, content = "x"}, {name = " ", content = "x"},
        {name = "x", content = false}, {name = "x", content = "y", readOnly = true},
        {name = "x", content = "y", templateId = Id(1)}, setmetatable({name = "x", content = "y"}, {})}) do
        assert(not library.ValidateTemplateRecord(bad) and library.CopyTemplateRecord(bad) == nil)
    end
    assert(library.TemplateRecordsEqual(record, {name = record.name, content = record.content}))
    assert(not library.TemplateRecordsEqual(record, {name = "different", content = record.content}))
    assert(not library.TemplateRecordsEqual(record, {name = record.name, content = "different"}))
end)
Test("same names/content remain independent IDs; no active layout changes", function()
    local payload = {TextTemplates = {Old = "[name]"}, Units = {player = {Texts = {text_1 = {templateName = "Old"}}}}}
    local db = {global = {UserLayouts = {L = {payload = payload}}}}
    for n, value in ipairs({record, {name = record.name, content = "different"},
        {name = "different", content = record.content}, record}) do
        assert(library.CreateUserTemplateRecord(Id(n), value, db))
    end
    assert(db.global.UserLayouts.L.payload == payload and payload.TextTemplates.Old == "[name]")
    assert(payload.Units.player.Texts.text_1.templateName == "Old")
    assert(db.global.TextTemplateIdState == nil)
    assert(not library.CreateUserTemplateRecord(Id(1), record, db))
    assert(not library.CreateUserTemplateRecord("tpl:b:health", record, db))
    local snapshot = assert(library.GetUserTemplateRecord(Id(1), db))
    snapshot.content = "outside"
    assert(db.global.TextTemplates[Id(1)].content == record.content)
end)
Test("rename/edit keep ID; stale expected record rejected; copy needs fresh ID", function()
    local db = {}
    assert(library.CreateUserTemplateRecord(Id(1), record, db))
    local baseline = assert(library.GetUserTemplateRecord(Id(1), db))
    assert(library.UpdateUserTemplateRecord(Id(1), baseline, {name = "Renamed"}, db))
    local ok, reason = library.UpdateUserTemplateRecord(Id(1), baseline, {content = "stale"}, db)
    assert(not ok and reason == "template-conflict")
    baseline = assert(library.GetUserTemplateRecord(Id(1), db))
    assert(library.UpdateUserTemplateRecord(Id(1), baseline, {content = "Updated"}, db))
    assert(not library.UpdateUserTemplateRecord(Id(1), baseline, {readOnly = true}, db))
    assert(not library.CopyUserTemplateRecord(Id(1), Id(1), db))
    assert(library.CopyUserTemplateRecord(Id(1), Id(2), db))
    local a, b = library.GetUserTemplateRecord(Id(1), db), library.GetUserTemplateRecord(Id(2), db)
    assert(library.TemplateRecordsEqual(a, b) and a ~= b)
    assert(Equal(db.global.TextTemplates, {[Id(1)] = a, [Id(2)] = b}))
    assert(db.global.TextTemplates[Id(1)] ~= db.global.TextTemplates[Id(2)])
end)
Test("rejected store writes are inert", function()
    local db = {}
    assert(not library.CreateUserTemplateRecord(Id(1), {name = "", content = "x"}, db))
    assert(not library.UpdateUserTemplateRecord(Id(1), record, {content = "x"}, db))
    assert(not library.CopyUserTemplateRecord(Id(1), Id(2), db))
    assert(library.GetUserTemplateRecord(Id(1), db) == nil and next(db) == nil)
end)
Test("real AceDB lazy global section persists namespace and entities", function()
    strmatch = string.match
    function CreateFrame() return {RegisterEvent = function() end, SetScript = function() end} end
    function GetRealmName() return "Test realm" end
    function UnitName() return "Test player" end
    function UnitClass() return "Mage", "MAGE" end
    function UnitRace() return "Human", "Human" end
    function UnitFactionGroup() return "Alliance" end
    function GetLocale() return "enUS" end
    function GetCurrentRegion() return 3 end
    dofile("Libraries/LibStub/LibStub.lua")
    dofile("Libraries/CallbackHandler-1.0/CallbackHandler-1.0.lua")
    dofile("Libraries/Ace3/AceDB-3.0/AceDB-3.0.lua")
    local saved = {}
    local db = LibStub("AceDB-3.0"):New(saved, {global = {UserLayouts = {}}}, true)
    assert(rawget(db, "global") == nil)
    assert(library.GetUserTemplateRecord(Id(1), db) == nil and saved.global == nil)
    local id = assert(Generator():Reserve(db, {}))
    assert(saved.global.TextTemplateIdState.namespace and db.global == saved.global)
    assert(library.CreateUserTemplateRecord(id, record, db))
    assert(Equal(saved.global.TextTemplates[id], record))
    local reopened = LibStub("AceDB-3.0"):New(saved, nil, true)
    assert(Equal(library.GetUserTemplateRecord(id, reopened), record))
    assert(Generator(2):Reserve(reopened, {}) ~= id)
    assert(saved.global.TextTemplateIdState.namespace == string.rep("01", 16))
end)
print("TextTemplateEntities: " .. passed .. " passed")
