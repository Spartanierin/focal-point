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

-- Existing characters remain legacy; activeLayoutId is not inferred as inheritance.
local selected, reason = resolver.ResolveLayoutSelection(db)
assert(selected == "builtin:default" and reason == "legacy")
assert(assignments.GetCharacterSelection(db) == nil)

local activeBefore = db.char.activeLayoutId
assert(assignments.SetAccountDefaultLayoutId("builtin:classic", db))
assert(db.char.activeLayoutId == activeBefore)
selected, reason = assignments.GetAccountDefaultLayoutId(db)
assert(selected == "builtin:classic" and reason == "ok")
selected, reason = resolver.ResolveLayoutSelection(db)
assert(selected == activeBefore and reason == "legacy", "builtin:default must not mean inherit")
assert(db.char.LayoutAssignments.specialization[71] == "layout:legacy")
assert(assignments.SetAccountDefaultLayoutId(userId, db))
assert(assignments.GetAccountDefaultLayoutId(db) == userId)
assert(not assignments.SetAccountDefaultLayoutId("layout:missing", db))
assert(db.global.defaultLayoutId == userId and db.char.activeLayoutId == activeBefore)
assert(assignments.SetAccountDefaultLayoutId(nil, db))
assert(assignments.GetAccountDefaultLayoutId(db) == nil)

-- A pre-existing invalid active ID remains visible in legacy mode.
db.char.activeLayoutId = "layout:missing"
selected, reason = resolver.ResolveLayoutSelection(db)
assert(selected == "layout:missing" and reason == "legacy")
local initialized, initializeReason = resolver.InitializeActiveLayoutId(db)
assert(initialized == "layout:missing" and initializeReason == "invalid-existing")
assert(db.char.activeLayoutId == "layout:missing")
db.char.activeLayoutId = activeBefore

-- Inherit uses a valid account default, without applying it.
assert(assignments.SetAccountDefaultLayoutId(userId, db))
assert(assignments.SetCharacterSelection({mode = "accountDefault"}, db))
assert(db.char.activeLayoutId == activeBefore)
local selection, selectionStatus = assignments.GetCharacterSelection(db)
assert(selectionStatus == "ok" and selection.mode == "accountDefault" and selection.layoutId == nil)
selected, reason = resolver.ResolveLayoutSelection(db)
assert(selected == userId and reason == "accountDefault")

-- Override wins over the account default for both built-in and user layouts.
assert(assignments.SetCharacterSelection({mode = "override", layoutId = "builtin:modern"}, db))
selected, reason = resolver.ResolveLayoutSelection(db)
assert(selected == "builtin:modern" and reason == "character")
assert(assignments.SetCharacterSelection({mode = "override", layoutId = userId}, db))
selected, reason = resolver.ResolveLayoutSelection(db)
assert(selected == userId and reason == "character")
assert(not assignments.SetCharacterSelection({mode = "override", layoutId = "layout:missing"}, db))
assert(assignments.SetCharacterSelection({mode = "accountDefault"}, db))

-- Inheritance without a default delegates the existing non-mutating fallback.
assert(assignments.SetAccountDefaultLayoutId(nil, db))
db.char.activeLayoutId = nil
function db.GetCurrentProfile() return "Default" end
db.global.LayoutMigration = {profileMap = {Default = userId}}
local fallbackGlobal = db.global
local fallbackAssignments = db.char.LayoutAssignments
local fallbackActive = db.char.activeLayoutId
selected, reason = resolver.ResolveLayoutSelection(db)
assert(selected == userId and reason == "systemFallback")
assert(db.global == fallbackGlobal and db.char.LayoutAssignments == fallbackAssignments
    and db.char.activeLayoutId == fallbackActive and db.global.defaultLayoutId == nil)

-- Stale and malformed preferences are reported, never treated as absent.
db.global.defaultLayoutId = "layout:missing"
selected, reason = resolver.ResolveLayoutSelection(db)
assert(selected == nil and reason == "stale-account-default")
db.global.defaultLayoutId = userId
db.char.LayoutAssignments.characterSelection = {mode = "override", layoutId = "layout:missing"}
selected, reason = resolver.ResolveLayoutSelection(db)
assert(selected == nil and reason == "stale-character-override")
db.char.LayoutAssignments.characterSelection = {mode = "unexpected"}
selected, reason = resolver.ResolveLayoutSelection(db)
assert(selected == nil and reason == "invalid-character-selection")
db.char.LayoutAssignments.characterSelection = nil
db.char.activeLayoutId = "builtin:default"
db.global.defaultLayoutId = userId

-- Layout transfer carries neither account nor character selection preferences.
local beforePreferences = {defaultLayoutId = db.global.defaultLayoutId,
    characterSelection = {mode = "accountDefault"}}
db.char.LayoutAssignments.characterSelection = {mode = beforePreferences.characterSelection.mode}
local encoded = assert(transfer.Export(userId))
local document = assert(codec.Decode(encoded))
assert(document.payload and document.payload.Units and not document.payload.defaultLayoutId)
assert(document.defaultLayoutId == nil and document.characterSelection == nil)
assert(assignments.GetAccountDefaultLayoutId(db) == beforePreferences.defaultLayoutId)
local imported = assert(transfer.Import(encoded))
assert(imported)
assert(assignments.GetAccountDefaultLayoutId(db) == beforePreferences.defaultLayoutId)
selection, selectionStatus = assignments.GetCharacterSelection(db)
assert(selectionStatus == "ok" and selection.mode == "accountDefault")

print("PASS: Account Default/Character Selection persistence, pure resolution, stale guards, legacy fallback and transfer isolation")
