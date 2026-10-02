-- lua54 Tests/TextTemplateEntityLookup.lua
local ns = {}
local function Load(path) assert(loadfile(path))("FocalPoint", ns) end
Load("Data/Defaults.lua")
Load("Data/Themes.lua")
Load("Engine/Text/Shared/TextTemplateLibrary.lua")
local library, passed = ns.TextTemplateLibrary, 0
local function Test(name, run) run(); passed = passed + 1; print("PASS: " .. name) end
local function Equal(a, b)
    if a == b then return true end
    if type(a) ~= "table" or type(b) ~= "table" then return false end
    for k, v in pairs(a) do if not Equal(v, b[k]) then return false end end
    for k in pairs(b) do if a[k] == nil then return false end end
    return true
end
local function Record(name, content) return {name = name, content = content} end
local function Entry(id, name, content) return {templateId = id, record = Record(name, content)} end
local userId = "tpl:u:" .. string.rep("a", 32) .. ":1700000000-1000-" .. string.rep("b", 32) .. ":1"
local defaults = ns:GetDefaultDB().profile.TextTemplates
local expected = {
    {"tpl:b:default-001", "Alt Power"}, {"tpl:b:default-002", "Class Power"},
    {"tpl:b:default-003", "Unit Name Focus"}, {"tpl:b:default-004", "Unit Name Target"},
    {"tpl:b:default-005", "Dead/Ghost Timer"}, {"tpl:b:default-006", "Cast Name"},
    {"tpl:b:default-007", "Power"}, {"tpl:b:default-008", "Absorb Value"},
    {"tpl:b:default-009", "Healing Absorb Value"}, {"tpl:b:default-010", "Unit Name Player"},
    {"tpl:b:default-011", "Health"}, {"tpl:b:default-012", "Player Level and Class"},
    {"tpl:b:default-013", "Cast Time"}, {"tpl:b:default-014", "Status"},
    {"tpl:b:default-015", "Dead Target"}, {"tpl:b:default-016", "Focus Level and Class"},
    {"tpl:b:default-017", "Target Level and Class"}, {"tpl:b:default-018", "Creature"},
    {"tpl:b:classic-001", "Health current", "classic"},
    {"tpl:b:classic-002", "Health w/o perc", "classic"},
    {"tpl:b:classic-003", "Power perc", "classic"},
    {"tpl:b:classic-004", "Unit Name w/o status", "classic"},
}
Test("catalog detects duplicates and snapshots identical records under independent IDs", function()
    local rows = {Entry("tpl:b:a", "Same", "Same"), Entry("tpl:b:b", "Same", "Same")}
    local catalog = assert(library.CreateBuiltInTemplateCatalog(rows))
    rows[1].record.content = "outside"
    assert(catalog.GetRecord("tpl:b:a").content == "Same")
    local one = catalog.GetRecord("tpl:b:a"); one.name = "outside"
    local all = catalog.ListRecords(); all["tpl:b:a"].content = "outside"
    assert(Equal(catalog.GetRecord("tpl:b:a"), Record("Same", "Same")))
    assert(catalog.GetRecord(userId) == nil)
    local duplicate, err = library.CreateBuiltInTemplateCatalog({rows[1], rows[1]})
    assert(duplicate == nil and err.errorCode == "duplicate-builtin-template-id")
    for _, bad in ipairs({{Entry(userId, "User", "x")}, {Entry("bad", "x", "x")},
        {Entry("tpl:b:a", " ", "x")}, {[2] = rows[1]}, {rows[1], false}}) do
        assert(library.CreateBuiltInTemplateCatalog(bad) == nil)
    end
end)
ns.db = setmetatable({}, {__index = function() error("unexpected database read") end,
    __newindex = function() error("unexpected database write") end})
Load("Data/BuiltInTextTemplates.lua")
Test("22 fixed IDs cover all declared sources without heuristic merging", function()
    local records, seen, count = ns.BuiltInTextTemplates.ListRecords(), {}, 0
    for _, spec in ipairs(expected) do
        local source = spec[3] and ns.Themes[spec[3]].textTemplates or defaults
        assert(not seen[spec[1]] and library.GetTemplateIdKind(spec[1]) == "builtin")
        seen[spec[1]] = true
        assert(library.ValidateTemplateRecord(records[spec[1]]))
        assert(Equal(records[spec[1]], Record(spec[2], source[spec[2]])))
    end
    for id in pairs(records) do assert(seen[id]); count = count + 1 end
    assert(count == 22)
    local function CheckSource(source, themeId)
        for name in pairs(source or {}) do
            local found = false
            for _, spec in ipairs(expected) do
                if spec[3] == themeId and spec[2] == name then found = true end
            end
            assert(found, "unmapped source template: " .. name)
        end
    end
    CheckSource(defaults)
    for themeId, theme in pairs(ns.Themes) do CheckSource(theme.textTemplates, themeId) end
    assert(records["tpl:b:default-016"].content == records["tpl:b:default-017"].content)
end)
Test("builtin lookup is a snapshot and independent of database state", function()
    local result = assert(library.ResolveTemplateEntity("tpl:b:default-013"))
    assert(Equal(result, {templateId = "tpl:b:default-013", name = "Cast Time",
        content = "[cast:time]", kind = "builtin", readOnly = true}))
    result.content = "outside"
    assert(library.ResolveTemplateEntity(result.templateId).content == "[cast:time]")
end)
Test("user lookup uses E1 and old snapshots survive store changes", function()
    local db = {}
    assert(library.CreateUserTemplateRecord(userId, Record("Health", "[name]"), db))
    local old = assert(library.ResolveTemplateEntity(userId, db))
    assert(old.templateId == userId and old.kind == "user" and old.readOnly == false)
    assert(old.name == "Health" and old.content == "[name]")
    assert(library.UpdateUserTemplateRecord(userId, Record(old.name, old.content), {content = "new"}, db))
    assert(old.content == "[name]" and library.ResolveTemplateEntity(userId, db).content == "new")
    old.name = "outside"
    assert(db.global.TextTemplates[userId].name == "Health")
end)
Test("structured errors and strict namespaces; no name/profile/layout fallback", function()
    local missing = userId:gsub(":1$", ":2")
    local db = {profile = {TextTemplates = {[missing] = "profile", Health = "name fallback"}},
        global = {UserLayouts = {L = {payload = {TextTemplates = {[missing] = "layout"}}}},
            TextTemplates = {["tpl:b:unknown"] = Record("forged", "forged"),
                ["tpl:b:default-013"] = Record("override", "override")}}}
    for _, case in ipairs({{"Health", "invalid-template-id"}, {"", "invalid-template-id"},
        {"tpl:b:", "invalid-template-id"}, {"layout:A", "invalid-template-id"},
        {"tpl:b:unknown", "builtin-template-not-found"}, {missing, "user-template-not-found"}}) do
        local value, err = library.ResolveTemplateEntity(case[1], db)
        assert(value == nil and type(err) == "table" and err.errorCode == case[2] and err.templateId == case[1])
    end
    assert(library.ResolveTemplateEntity(false, db) == nil and library.ResolveTemplateEntity(nil, db) == nil)
    assert(library.ResolveTemplateEntity("tpl:b:default-013", db).content == "[cast:time]")
    local empty = {}; assert(library.ResolveTemplateEntity(missing, empty) == nil and next(empty) == nil)
    db.global.TextTemplates[missing] = {name = "bad", content = false}
    local _, err = library.ResolveTemplateEntity(missing, db)
    assert(err.errorCode == "invalid-template-content")
end)
Test("user create/update/copy cannot enter builtin namespace", function()
    local db = {}
    assert(library.CreateUserTemplateRecord(userId, Record("User", "x"), db))
    assert(not library.CreateUserTemplateRecord("tpl:b:default-013", Record("x", "x"), db))
    assert(not library.UpdateUserTemplateRecord("tpl:b:default-013", Record("Cast Time", "[cast:time]"), {content = "x"}, db))
    assert(not library.CopyUserTemplateRecord(userId, "tpl:b:default-013", db))
    assert(not library.CopyUserTemplateRecord("tpl:b:default-013", userId, db))
    assert(library.GetUserTemplateRecord("tpl:b:default-013", db) == nil)
    assert(db.global.TextTemplates["tpl:b:default-013"] == nil)
end)
Test("fixture rename/content preserve ID; equality is only name/content", function()
    local rows = {Entry("tpl:b:a", "Same", "x"), Entry("tpl:b:b", "Same", "x")}
    local before = assert(library.CreateBuiltInTemplateCatalog(rows))
    assert(library.TemplateRecordsEqual(before.GetRecord("tpl:b:a"), before.GetRecord("tpl:b:b")))
    rows[1].record = Record("Renamed", "changed")
    local after = assert(library.CreateBuiltInTemplateCatalog(rows))
    assert(after.GetRecord("tpl:b:a").name == "Renamed" and after.GetRecord("tpl:b:b").name == "Same")
    assert(before.GetRecord("tpl:b:a").content == "x")
    local value = library.ResolveTemplateEntity("tpl:b:default-013")
    assert(library.TemplateRecordsEqual(Record(value.name, value.content), Record("Cast Time", "[cast:time]")))
end)
Test("data is derived once without content double maintenance or snapshot aliasing", function()
    local before = library.ResolveTemplateEntity("tpl:b:classic-001")
    local original = ns.Themes.classic.textTemplates["Health current"]
    ns.Themes.classic.textTemplates["Health current"] = "changed fixture"
    assert(library.ResolveTemplateEntity(before.templateId).content == original)
    Load("Data/BuiltInTextTemplates.lua")
    assert(library.ResolveTemplateEntity(before.templateId).content == "changed fixture" and before.content == original)
    ns.Themes.classic.textTemplates["Health current"] = original
    Load("Data/BuiltInTextTemplates.lua")
end)
Test("manifest order, unchanged legacy definitions and no persistence side effects", function()
    local f = assert(io.open("Init.xml")); local xml = f:read("*a"); f:close()
    local data = assert(xml:find('file="Data/BuiltInTextTemplates.lua"', 1, true))
    assert(xml:find('file="Data/Defaults.lua"', 1, true) < data)
    assert(xml:find('file="Data/Themes.lua"', 1, true) < data)
    assert(xml:find('file="Engine/Text/Shared/TextTemplateLibrary.lua"', 1, true) < data)
    assert(#library.ListIntegratedTemplateDefinitions() == 22)
    assert(Equal(ns:GetDefaultDB().profile.TextTemplates, defaults) and next(ns.db) == nil)
end)
print("TextTemplateEntityLookup: " .. passed .. " passed")