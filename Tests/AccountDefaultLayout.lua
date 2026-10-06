-- Block A: Account Default/Character Selection are preferences, not active state.
local ns = {L = {THEME_DEFAULT = "Default"}}
local function Load(path) assert(loadfile(path))("FocalPoint", ns) end

for _, path in ipairs({
    "Data/Defaults.lua", "Data/Themes.lua", "Services/CompositionPresenceStorage.lua",
    "Services/LayoutService.lua", "Services/LegacyThemeAdapter.lua", "Services/UserPresetStore.lua",
    "Services/UserLayoutStore.lua", "Services/LayoutMutations.lua", "Services/LayoutTransferCodec.lua",
    "Services/LayoutTransfer.lua", "Services/LayoutMigration.lua", "Services/PresetService.lua",
    "Services/ActiveLayoutResolver.lua", "Services/LayoutAssignmentService.lua",
    "Engine/Text/Shared/TextTemplateLibrary.lua", "Data/BuiltInTextTemplates.lua",
    "Engine/Text/Shared/TextTemplateUsage.lua", "Engine/Text/Shared/TextTemplateValidation.lua",
    "Services/TextTemplateEntityMigration.lua", "Services/LayoutTransferVNext.lua",
}) do Load(path) end
C_AddOns = {GetAddOnMetadata = function() return "2.2.2-test" end}

local assignments = ns.LayoutAssignmentService
local resolver = ns.ActiveLayoutResolver
local transfer = ns.LayoutTransfer
local codec = ns.LayoutTransferCodec
local defaults = ns:GetDefaultDB()
local payload = ns.LayoutService.CopyPayload({
    Units = defaults.profile.Units,
    TextTemplates = defaults.profile.TextTemplates,
})
local userId = "layout:account-default"
local db = {
    profile = {General = {sentinel = true}},
    char = {activeLayoutId = "builtin:default", LayoutAssignments = {specialization = {[71] = "layout:legacy"}}},
    global = {UserLayouts = {[userId] = {name = "Account", formatVersion = 2, payload = payload}}},
}
ns.db = db

-- The feature stores one global ID; no character preference or selection resolver.
assert(assignments.GetCharacterSelection == nil and assignments.SetCharacterSelection == nil)
assert(assignments.ApplyCharacterLayoutOverride == nil and assignments.ApplyAccountDefaultForCurrentCharacter == nil)
assert(resolver.ResolveLayoutSelection == nil)
local char, specialization = db.char, db.char.LayoutAssignments.specialization
local active = char.activeLayoutId
-- Neither reading nor writing the global default may enumerate foreign characters.
db.sv = {char = setmetatable({}, {__pairs=function() error("character fanout") end,
    __index=function() error("foreign character read") end, __newindex=function() error("foreign character write") end})}
for _, id in ipairs({"builtin:classic", userId}) do
    assert(assignments.SetAccountDefaultLayoutId(id, db))
    local value, status = assignments.GetAccountDefaultLayoutId(db)
    assert(value == id and status == "ok")
    assert(db.char == char and char.activeLayoutId == active and char.LayoutAssignments.specialization == specialization)
end
assert(not assignments.SetAccountDefaultLayoutId("layout:missing", db))
assert(db.global.defaultLayoutId == userId)
assert(assignments.SetAccountDefaultLayoutId(nil, db))
local value, status = assignments.GetAccountDefaultLayoutId(db)
assert(value == nil and status == "missing" and char.activeLayoutId == active)
db.global.defaultLayoutId = "layout:missing"
value, status = assignments.GetAccountDefaultLayoutId(db)
assert(value == nil and status == "stale" and db.global.defaultLayoutId == "layout:missing")
-- The early startup resolver retains the original legacy initialization contract.
assert(assignments.SetAccountDefaultLayoutId(userId, db))
assert(resolver.InitializeActiveLayoutId(db) == active)
char.activeLayoutId = "layout:missing"
local initialized, reason = resolver.InitializeActiveLayoutId(db)
assert(initialized == "layout:missing" and reason == "invalid-existing")
char.activeLayoutId = nil
function db.GetCurrentProfile() return "Default" end
db.global.LayoutMigration = {profileMap = {Default = userId}}
initialized, reason = resolver.InitializeActiveLayoutId(db)
assert(initialized == userId and reason == "mapped-profile")
char.activeLayoutId = nil; db.global.LayoutMigration = nil
initialized, reason = resolver.InitializeActiveLayoutId(db)
assert(initialized == "builtin:default" and reason == "default-builtin")
-- Import/export carries layout data, never the account's preference.
db.sv = nil
local encoded = assert(transfer.Export(userId))
local document = assert(codec.Decode(encoded))
assert(document.payload and document.payload.Units and not document.payload.defaultLayoutId)
assert(document.defaultLayoutId == nil and document.characterSelection == nil)
assert(transfer.Import(encoded))
assert(assignments.GetAccountDefaultLayoutId(db) == userId)
assert(db.char == char and char.LayoutAssignments.specialization == specialization)
print("PASS AccountDefaultLayout: single global reference, validation, no character writes, legacy initialization and transfer isolation")
