-- Run with:
-- lua54 Tests/LayoutMigrationGolden.lua D:/FocalPoint-Dev/test-fixtures/migration/issue-7-shadowhand-original.lua

local fixturePath = arg and arg[1]
assert(type(fixturePath) == "string" and fixturePath ~= "", "missing Issue #7 fixture path")

local FocalPoint = {}

local function Load(path)
    local chunk = assert(loadfile(path))
    chunk("FocalPoint", FocalPoint)
end

local function LoadFixture(path)
    local environment = {}
    local chunk = assert(loadfile(path, "t", environment))
    chunk()
    return assert(environment.FocalPointDB, "fixture does not define FocalPointDB")
end

local function CountEntries(value)
    local count = 0
    for _ in pairs(value or {}) do
        count = count + 1
    end
    return count
end

local function AssertEqual(actual, expected, label)
    assert(actual == expected, string.format("%s: expected %s, got %s", label, tostring(expected), tostring(actual)))
end

local function DeepEqual(left, right)
    if left == right then
        return true
    end
    if type(left) ~= type(right) or type(left) ~= "table" then
        return false
    end
    for key, value in pairs(left) do
        if not DeepEqual(value, right[key]) then
            return false
        end
    end
    for key in pairs(right) do
        if left[key] == nil then
            return false
        end
    end
    return true
end

local function Report(unitKey, objectName, details)
    print(string.format("%s\n  %s\n    %s\n    OK", unitKey, objectName, details))
end

Load("Data/Defaults.lua")
Load("Services/CompositionPresenceStorage.lua")
Load("Services/LayoutService.lua")
Load("Services/UserLayoutStore.lua")
Load("Services/LayoutMigration.lua")

local function NewDatabase(profile)
    local database = {
        profile = profile,
        profiles = { Default = profile },
        global = {},
    }

    function database:GetCurrentProfile()
        return "Default"
    end

    function database:GetProfiles()
        return { "Default" }
    end

    return database
end

local function MigrateProfile(profile)
    local database = NewDatabase(profile)
    FocalPoint.db = database
    assert(FocalPoint.LayoutMigration.EnsureBackup(database) == true, "backup failed")
    local result = FocalPoint.LayoutMigration.MigrateAll(database)
    assert(result.complete == true, "migration incomplete")
    local layoutId = database.global.LayoutMigration.profileMap.Default
    local record = database.global.UserLayouts[layoutId]
    assert(type(record) == "table", "missing migrated layout")
    return database, record.payload
end

local fixture = LoadFixture(fixturePath)
local sourceProfile = assert(fixture.profiles and fixture.profiles.Default, "fixture missing Default profile")
local sourceBefore = FocalPoint.LayoutService.Clone(sourceProfile)
local database, payload = MigrateProfile(sourceProfile)
local target = assert(payload.Units.target, "Target must migrate")

local normalPayload = FocalPoint.LayoutService.MaterializeFromProfile(
    { Units = { target = {} } },
    FocalPoint:GetDefaultDB()
)
assert(normalPayload.Units.player ~= nil, "normal 2.0 materialization must keep the default unit baseline")
assert(normalPayload.Units.target.castBarPresent == true, "normal 2.0 materialization must keep default presence")

AssertEqual(CountEntries(payload.Units), CountEntries(sourceProfile.Units), "legacy unit count")
AssertEqual(target.width, 327, "Target width")
AssertEqual(target.height, 32, "Target height")
AssertEqual(target.Portrait.placement, "ATTACHED", "Target portrait placement")
AssertEqual(target.Portrait.size, 48, "Target portrait size")
AssertEqual(target.showCastBar, false, "Target cast bar show")
AssertEqual(target.castBarPresent, true, "Target cast bar presence")
assert(target.Texts.CastName == nil, "missing legacy CastName must stay absent")
assert(target.Texts.CastTime == nil, "missing legacy CastTime must stay absent")
assert(target.Buffs.present == true and target.Debuffs.present == true, "legacy aura groups must stay present")
assert(DeepEqual(sourceProfile, sourceBefore), "migration mutated legacy source")
Report("Target", "CastBar", "legacy evidence: yes; legacy show: false; migrated present: true; migrated show: false")
Report("Target", "CastTime", "legacy evidence: no; migrated present: false / absent")

local secondResult = FocalPoint.LayoutMigration.MigrateAll(database)
AssertEqual(secondResult.migratedProfiles, 0, "second migration profile count")
AssertEqual(CountEntries(database.global.UserLayouts), 1, "second migration layout count")
local verification = FocalPoint.LayoutMigration.VerifyUserLayouts(database)
assert(verification.complete == true, "migration verification failed")

local _, noEvidencePayload = MigrateProfile({ Units = { target = {} } })
local noEvidenceTarget = noEvidencePayload.Units.target
assert(noEvidenceTarget.castBarPresent == false, "missing cast evidence must stay absent")
assert(noEvidenceTarget.Buffs.present == false and noEvidenceTarget.Debuffs.present == false, "missing aura evidence must stay absent")
assert(noEvidenceTarget.Portrait.present == false, "missing portrait evidence must stay absent")
assert(noEvidenceTarget.Texts.CastTime == nil, "missing CastTime must stay absent")
Report("Synthetic Target", "Optional objects", "missing evidence: all optional objects remain absent")

local _, hiddenCastPayload = MigrateProfile({ Units = { target = { showCastBar = false } } })
AssertEqual(hiddenCastPayload.Units.target.castBarPresent, true, "hidden cast bar presence")
AssertEqual(hiddenCastPayload.Units.target.showCastBar, false, "hidden cast bar show")

local _, disabledTextPayload = MigrateProfile({
    Units = {
        target = {
            Texts = {
                CastTime = { enabled = false, tag = "[cast:time]" },
            },
        },
    },
})
AssertEqual(disabledTextPayload.Units.target.Texts.CastTime.enabled, false, "disabled CastTime")

local _, decorationPayload = MigrateProfile({
    Units = {
        target = {
            decorations = {
                { id = "legacy-decoration", texture = "Interface\\Icons\\INV_Misc_QuestionMark" },
            },
        },
    },
})
AssertEqual(#decorationPayload.Units.target.decorations, 1, "legacy decoration count")

local existing = {
    name = "Existing",
    payload = { Units = {} },
    createdFrom = { source = "profile", id = "Default" },
}
local existingDatabase = NewDatabase({ Units = { target = {} } })
existingDatabase.global = {
    UserLayouts = { existing = existing },
    LayoutMigration = {
        version = 1,
        profileMap = { Default = "existing" },
        userPresetMap = {},
    },
}
FocalPoint.db = existingDatabase
local existingResult = FocalPoint.LayoutMigration.MigrateAll(existingDatabase)
AssertEqual(existingResult.migratedProfiles, 0, "existing layout migration count")
assert(existingDatabase.global.UserLayouts.existing == existing, "existing user layout was overwritten")

print("Layout migration golden test: PASS")
