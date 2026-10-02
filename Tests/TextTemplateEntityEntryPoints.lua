-- lua54 Tests/TextTemplateEntityEntryPoints.lua
-- R3 explicit Entity consumer contracts. Legacy callers remain covered by the existing suites.
local file = assert(io.open("Tests/TextBuilderDraftSafety.lua"))
local source = file:read("*a"); file:close()
local stop = assert(source:find('local a, b = Payload("A"), Payload("B")', 1, true))
local f = assert(load(source:sub(1, stop - 1) .. "\nreturn f", "@R3/EntryPointFixture"))()
local ns, Load = f.ns, f.Load
for _, path in ipairs({
    "Engine/Text/Shared/TextElementRoles.lua",
    "Engine/Text/Shared/TextTemplateResolver.lua",
    "Engine/Text/Shared/TextTemplateValidation.lua",
    "Data/BuiltInTextTemplates.lua",
    "GUI/Pages/TextBuilder/TextBuilderEntity.lua",
    "GUI/Editor/Inspector/InspectorMutations.lua",
}) do Load(path) end

local L = assert(ns.TextTemplateLibrary)
local E = assert(ns.TextTemplateMutations.Entity)
local R2 = assert(ns.GUI.Pages.TextBuilder.EntityBuilder)
local function Id(n) return "tpl:u:" .. string.rep("a", 32) .. ":1-2-" .. string.rep("b", 32) .. ":" .. n end
local A, B = Id(1), Id(2)
local long = string.rep("x", 520)
local builtin = "tpl:b:default-013"
local function assertOk(result)
    assert(type(result) == "table" and result.ok, result and result.errorCode or "mutation failed")
    return result
end
local function assertSame(left, right, message)
    assert(left == right, message or "values differ")
end
local payload = {Units = {player = {Texts = {}}}}
local db = {char = {activeLayoutId = "layout:a"}, global = {
    TextTemplates = {[A] = {name = "Same", content = "A"}, [B] = {name = "Same", content = "B"}},
    UserLayouts = { ["layout:a"] = {payload = payload}, ["layout:b"] = {payload = {Units = {player = {Texts = {}}}}} },
}}
ns.db = db
R2.SetIdGenerator(assert(L.CreateUserTemplateIdGenerator({time=function() return 10 end, uptime=function() return 1 end, random=function() return 3 end})))

local rows = assert(L.Entity.List(db))
local seen = {}
for _, row in ipairs(rows) do seen[row.value] = row end
assert(seen[A] and seen[B] and seen[A].label == "Same" and seen[B].label == "Same")
assert(seen[builtin] and seen[builtin].readOnly == true)
assert(L.Entity.Selection(db, "Same") == nil)

Load("GUI/Widgets/SelectionRow.lua")
Load("GUI/Editor/TextTemplateLibraryWindow.lua")
local picker = assert(ns.GUI.Editor.TextTemplateLibraryWindow)
local openBuilder = ns.GUIController.OpenTextBuilderWindow
local rejectedRequest
ns.GUIController.OpenTextBuilderWindow = function(request)
    rejectedRequest = request
    return false, "unsaved-changes"
end
picker.Open({entity = true, mode = "add", unit = "player"})
local pickerContext = assert(f.Upvalue(picker.Open, "windowContext"))
assert(pickerContext.entity and pickerContext.entries[1].templateId)
pickerContext.dialog.secondaryButton:Fire("OnClick")
assert(rejectedRequest and rejectedRequest.entity == true and pickerContext.dialog.window.frame:IsShown())
ns.GUIController.OpenTextBuilderWindow = function(request)
    rejectedRequest = request
    return true
end
pickerContext.dialog.secondaryButton:Fire("OnClick")
assert(rejectedRequest.returnContext and rejectedRequest.returnContext.originToken == pickerContext.originToken)
ns.GUIController.OpenTextBuilderWindow = openBuilder

local mutationContext = {db = db, expectedLayoutId = "layout:a",
    GetUnits = function() return payload.Units end,
    GetUnitConfig = function(unitKey) return payload.Units[unitKey] end}
local add = assertOk(E.CreateTextFromTemplate(mutationContext, "player", builtin, {anchorTo = "Frame"}))
local added = payload.Units.player.Texts[add.textKey]
assert(added and added.templateId == builtin and added.templateName == nil)
assert(added.tag == "[cast:time]" and added.anchorTo == "Frame")
assert(add.textKey == "text_1")

local styled = {templateId = A, stateTemplateIds = {ghost = B}, tag = "local",
    enabled = false, font = "fp:font:test", point = "TOP", relativePoint = "BOTTOM", offsetX = 7, offsetY = -4}
payload.Units.player.Texts.bound = styled
local assigned = assertOk(E.AssignMainTemplate(mutationContext, "player", "bound", B))
assert(assigned.changed and styled.templateId == B and styled.stateTemplateIds.ghost == B)
assert(styled.tag == "" and styled.enabled == false and styled.font == "fp:font:test")
assert(styled.point == "TOP" and styled.relativePoint == "BOTTOM" and styled.offsetX == 7 and styled.offsetY == -4)
local noop = assertOk(E.AssignMainTemplate(mutationContext, "player", "bound", B))
assert(noop.changed == false)

local mainBefore = styled.templateId
assertOk(E.AssignStateTemplate(mutationContext, "player", "bound", "dead", A))
assert(styled.stateTemplateIds.dead == A and styled.templateId == mainBefore)
assertOk(E.UnassignStateTemplate(mutationContext, "player", "bound", "dead"))
assert(styled.stateTemplateIds.dead == nil and styled.templateId == mainBefore)
assert(styled.stateTemplateIds.ghost == B)

local localText = {tag = long, enabled = true, font = "fp:font:test", point = "LEFT", offsetX = 11}
payload.Units.player.Texts.localText = localText
local session = assert(R2.Open({entity = true, kind = "object", layoutId = "layout:a", unitKey = "player", textKey = "localText"}, db, "layout:a"))
assertSame(session.content, long, "local draft was not lossless")
assert(select(1, R2.SetContent(session, long .. "!")))
local saved = assertOk(R2.Save(session))
assert(saved.changed == true and localText.tag == long .. "!")
assert(localText.templateId == nil and localText.font == "fp:font:test" and localText.point == "LEFT" and localText.offsetX == 11)
assert(select(1, R2.SetContent(session, long .. "!")))
assert(R2.Save(session).changed == false)

local token = {}
local newSession = assert(R2.Open({entity = true, kind = "new-template", layoutId = "layout:a",
    returnContext = {pickerMode = "add", layoutId = "layout:a", unitKey = "player", originToken = token}}, db, "layout:a"))
assert(newSession.returnContext.originToken == token)
assert(select(1, R2.SetName(newSession, "New Entity")))
assert(select(1, R2.SetContent(newSession, "created")))
local created = assertOk(R2.Save(newSession))
assert(created.created and created.templateId and newSession.kind == "shared-template")
assert(newSession.returnContext.originToken == token)

local copySource = assert(R2.Open({entity = true, kind = "shared-template", layoutId = "layout:a", templateId = builtin}, db, "layout:a"))
local copied = assertOk(R2.Copy(copySource))
assert(copied.copied and copied.templateId ~= builtin)
assert(L.GetTemplateIdKind(copied.templateId) == "user")
assert(payload.Units.player.Texts.bound.templateId == mainBefore)

local stale = {db = db, expectedLayoutId = "layout:a", expectedTextConfig = styled}
db.char.activeLayoutId = "layout:b"
local rejected = E.AssignStateTemplate(stale, "player", "bound", "dead", A)
assert(rejected.ok == false and rejected.errorCode == "layout_mismatch")
db.char.activeLayoutId = "layout:a"
payload.Units.player.Texts.bound = nil
local deleted = E.AssignStateTemplate(mutationContext, "player", "bound", "dead", A)
assert(deleted.ok == false and deleted.errorCode == "text_element_not_found")

print("TextTemplateEntityEntryPoints: explicit ID consumers, Builder return/origin, Add/Change/State and stale-context contracts passed")