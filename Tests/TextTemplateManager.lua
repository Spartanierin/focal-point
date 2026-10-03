-- lua54 Tests/TextTemplateManager.lua
-- Texts Manager route and global-template administration; no object binding.
local file = assert(io.open("Tests/TextBuilderDraftSafety.lua"))
local source = file:read("*a"); file:close()
local stop = assert(source:find('local a, b = Payload("A"), Payload("B")', 1, true))
local f = assert(load(source:sub(1, stop - 1) .. "\nreturn f", "@TextsManager/Fixture"))()
local ns, Load, Upvalue = f.ns, f.Load, f.Upvalue

for _, path in ipairs({
    "Engine/Text/Shared/TextElementRoles.lua", "Engine/Text/Shared/TextTemplateResolver.lua",
    "Engine/Text/Shared/TextTemplateValidation.lua", "Data/BuiltInTextTemplates.lua",
    "GUI/Pages/TextBuilder/TextBuilderEntity.lua",
}) do Load(path) end

local function Id(n) return "tpl:u:" .. string.rep("a", 32) .. ":1-2-" .. string.rep("b", 32) .. ":" .. n end
local userA, userB = Id(1), Id(2)
local payload = {Units = {player = {Texts = {
    shared = {templateId = userA}, state = {stateTemplateIds = {dead = userB}},
}}}}
ns.db = {char = {activeLayoutId = "layout:a"}, global = {
    TextTemplates = {
        [userA] = {name = "Same", content = "[name]"},
        [userB] = {name = "Same", content = "[hp:cur]"},
    },
    UserLayouts = { ["layout:a"] = {name = "A", formatVersion = 2, payload = payload} },
}}
local library = assert(ns.TextTemplateLibrary)
local builder = assert(ns.GUI.Pages.TextBuilder)
local R2 = assert(builder.EntityBuilder)
R2.SetIdGenerator(assert(library.CreateUserTemplateIdGenerator({
    time = function() return 10 end, uptime = function() return 1 end, random = function() return 3 end,
})))
local window = assert(ns.GUI.Editor.TextTemplateLibraryWindow)


local function NoErrors() assert(#f.env.errors == 0, table.concat(f.env.errors, "\n")) end
local function Click(widget) assert(widget); widget:Fire("OnClick"); NoErrors() end
local function Contains(root, target)
    if root == target then return true end
    for _, child in ipairs(root.children or {}) do if Contains(child, target) then return true end end
    return false
end
local function Count(t) local n=0; for _ in pairs(t) do n=n+1 end; return n end
local function Consumer() return assert(Upvalue(builder.RefreshWindowState, "consumerContext")) end
local function Input(widget, text) widget:SetText(text); widget:Fire("OnTextChanged", text); NoErrors() end
function f.native:SetClipsChildren(value) self.clipsChildren = value end
assert(ns.GUIController.OpenTextBuilderWindow()); NoErrors()
local manager = assert(Upvalue(window.OpenManager, "managerContext"))
local function Select(id)
    local row = assert(manager.rows[id]); row.onSelect(row.key); NoErrors()
    assert(manager.selectedTemplateId == id)
end
assert(manager.window.frame:IsShown())
assert(manager.window.titletext:GetText() == "Texts Manager")
assert(manager.window.frame:GetWidth() == 560 and manager.window.frame:GetHeight() == 720)
assert(not manager.window.sizer_se:IsShown() and not manager.window.sizer_s:IsShown() and not manager.window.sizer_e:IsShown())
assert(manager.dialog.body.LayoutFunc == f.ace:GetLayout("List"))
assert(manager.listGroup.type == "ScrollFrame" and manager.listGroup.parent == manager.dialog.body)
assert(manager.detailGroup.parent == manager.dialog.body and manager.detailGroup:IsFullWidth())
assert(manager.listGroup.frame:GetHeight() == 242 and manager.newButton.frame:GetWidth() == 160)
assert(#manager.userEntries == 2 and #manager.builtinEntries > 0)
assert(manager.selectedTemplateId == userA and manager.userEntries[2].templateId == userB)
assert(Upvalue(builder.RefreshWindowState, "consumerContext") == nil)
local headings = {}
for _, child in ipairs(manager.listGroup.children) do
    if child.type == "SimpleGroup" and child.children[1] and child.children[1].label then
        headings[#headings+1] = child.children[1].label:GetText()
    end
end
assert(headings[1] == "My Templates (2)")
assert(headings[2] == "Built-in Templates (" .. #manager.builtinEntries .. ")")
for _, row in pairs(manager.rows) do
    assert(row.frame:GetHeight() == 22 and not row.binding.description and not row.binding.status)
end
assert(manager.rows[userA].binding.detail == "My Template")
assert(manager.previewPanel.Variant == "result_stack" and manager.previewPanel.frame:GetHeight() == 80)
assert(manager.previewPanel:IsFullWidth() and manager.previewPanel.frame.clipsChildren)
assert(manager.previewValue.label.lastSetJustifyH[1] == "CENTER")
assert(manager.expressionScroll.frame:GetHeight() == 48 and manager.expressionScroll.type == "ScrollFrame")
assert(Count(manager.actionButtons) == 4 and manager.actionButtons.delete.disabled)
print("PASS: fixed vertical 560x720 manager, shared compact list and canonical full-width preview")

-- Selection must not release/recreate the list or touch its scroll state.
local releases, release = 0, manager.listGroup.ReleaseChildren
manager.listGroup.ReleaseChildren = function(self) releases=releases+1; return release(self) end
manager.listGroup.localstatus.offset = 73
manager.listGroup.localstatus.scrollvalue = 300
local rows = manager.rows
local builtInId = manager.builtinEntries[1].templateId
Select(builtInId)
assert(manager.rows == rows and releases == 0)
assert(manager.listGroup.localstatus.offset == 73 and manager.listGroup.localstatus.scrollvalue == 300)
assert(rows[builtInId].binding.selected and not rows[userA].binding.selected)
assert(rows[builtInId].binding.detail == "Read-only")
assert(Count(manager.actionButtons) == 1 and manager.actionButtons.duplicate)
assert(not manager.usage and manager.usageLabel.label:GetText() == "")
assert(manager.typeLabel.label:GetText() == "Built-in \194\183 Read-only")
local beforeMain, beforeState = payload.Units.player.Texts.shared.templateId, payload.Units.player.Texts.state.stateTemplateIds.dead
Select(userB)
assert(manager.expression.label:GetText() == "[hp:cur]" and releases == 0)
assert(payload.Units.player.Texts.shared.templateId == beforeMain and payload.Units.player.Texts.state.stateTemplateIds.dead == beforeState)
local long = string.rep("[name] long expression\n", 100)
ns.db.global.TextTemplates[userB].content = long
window.Refresh(); NoErrors()
assert(manager.expression.label:GetText() == long and manager.window.frame:GetHeight() == 720)
ns.db.global.TextTemplates[userB].content = "[hp:cur]"
print("PASS: ID selection without list rebuild/scroll reset, read-only Built-ins and complete long expression")

-- Same object in main and multiple states counts once, including disabled texts.
payload.Units.player.Texts.shared.stateTemplateIds = {dead=userA, ghost=userA}
payload.Units.player.Texts.shared.enabled = false
ns.db.global.UserLayouts["layout:b"] = {name="B",formatVersion=2,payload={Units={target={Texts={
    shared={templateId=userA,stateTemplateIds={dead=userA}},
}}}}}
Select(userA)
local u=manager.usage
assert(u.texts==2 and u.layouts==2 and u.main==2 and u.state==3 and u.disabled==1)
assert(manager.usageLabel.label:GetText():find("Used by 2 texts in 2 layouts",1,true))
Click(manager.actionButtons.delete); assert(not manager.deleteDialog)
print("PASS: distinct text/layout usage, main/state references and distinct disabled texts")

-- Clean Cancel of New/Edit retains selection and releases the consumer.
Click(manager.newButton)
local consumer=Consumer()
assert(not manager.window.frame:IsShown() and consumer.window.frame:IsShown())
Click(consumer.dialog.cancelButton)
assert(consumer.released and manager.window.frame:IsShown() and manager.selectedTemplateId==userA)
Click(manager.actionButtons.edit); consumer=Consumer()
assert(consumer.r2Session.kind=="shared-template")
Click(consumer.dialog.cancelButton)
assert(consumer.released and manager.selectedTemplateId==userA)
-- Discarding a dirty New/Edit also returns to the previous ID.
Click(manager.newButton); consumer=Consumer()
Input(consumer.nameEdit,"Discarded New"); Input(consumer.contentEdit,"discarded")
Click(consumer.dialog.cancelButton)
local closeDialog=assert(Upvalue(builder.InvalidateLayoutContext,"r2CloseDialog"))
Click(closeDialog.discardCloseButton)
assert(consumer.released and manager.selectedTemplateId==userA)
Click(manager.actionButtons.edit); consumer=Consumer()
Input(consumer.contentEdit,"discarded edit"); Click(consumer.dialog.cancelButton)
closeDialog=assert(Upvalue(builder.InvalidateLayoutContext,"r2CloseDialog"))
Click(closeDialog.discardCloseButton)
assert(consumer.released and manager.selectedTemplateId==userA and ns.db.global.TextTemplates[userA].content=="[name]")
Click(manager.newButton); consumer=Consumer()
Input(consumer.nameEdit,"Manager Created"); Input(consumer.contentEdit,"[level]")
Click(consumer.dialog.primaryButton)
local createdId=manager.selectedTemplateId
assert(createdId~=userA and ns.db.global.TextTemplates[createdId].content=="[level]")
assert(consumer.released and manager.window.frame:IsShown())
assert(Count(manager.actionButtons)==4 and not manager.actionButtons.delete.disabled)
Click(manager.actionButtons.edit); consumer=Consumer()
Input(consumer.contentEdit,"[level:cur]"); Click(consumer.dialog.primaryButton)
assert(manager.selectedTemplateId==createdId and ns.db.global.TextTemplates[createdId].content=="[level:cur]")
print("PASS: existing New/Edit workflows, save/return and clean Cancel selection retention")

-- Rename must act on a live edit field in the actual visible dialog tree.
Click(manager.actionButtons.rename)
local rename, edit, status=manager.renameDialog,manager.renameEdit,manager.renameStatus
assert(rename.window.frame:IsShown() and edit.frame:IsShown() and Contains(rename.body,edit))
assert(Contains(rename.body,status) and edit.parent==rename.body)
assert(rename.primaryButton.parent~=rename.body)
Input(edit,"   "); Click(rename.primaryButton)
assert(not rename.released and status.label:GetText()~=" " and status.label:GetText()~="")
assert(ns.db.global.TextTemplates[createdId].name=="Manager Created")
Input(edit,"Manager Renamed"); Click(rename.primaryButton)
assert(rename.released and not manager.renameDialog and not manager.renameEdit)
assert(manager.selectedTemplateId==createdId and ns.db.global.TextTemplates[createdId].name=="Manager Renamed")
Click(manager.actionButtons.rename)
rename,edit=manager.renameDialog,manager.renameEdit
assert(Contains(rename.body,edit) and edit:GetText()=="Manager Renamed")
Input(edit,"Cancelled")
local staleRename=rename.primaryButton.events.OnClick
Click(rename.cancelButton); staleRename(); NoErrors()
assert(rename.released and manager.selectedTemplateId==createdId)
assert(ns.db.global.TextTemplates[createdId].name=="Manager Renamed")
Click(manager.actionButtons.rename); rename=manager.renameDialog
rename:Close(); NoErrors(); assert(rename.released)
Click(manager.actionButtons.rename); rename=manager.renameDialog
Input(manager.renameEdit,"Stale rename")
ns.db.char.activeLayoutId="layout:b"
Click(rename.primaryButton)
assert(ns.db.global.TextTemplates[createdId].name=="Manager Renamed")
rename:Close(); ns.db.char.activeLayoutId="layout:a"
print("PASS: Rename live dialog children, visible validation, save/cancel/reopen and stale layout guard")

-- Duplicate uses Copy: both source types produce new IDs without binding edits.
Select(builtInId)
local sourceContent=manager.expression.label:GetText()
Click(manager.actionButtons.duplicate)
local builtinCopy=manager.selectedTemplateId
assert(ns.db.global.TextTemplates[builtinCopy].content==sourceContent)
Select(createdId); Click(manager.actionButtons.duplicate)
local duplicateId=manager.selectedTemplateId
assert(duplicateId~=createdId and ns.db.global.TextTemplates[duplicateId].content=="[level:cur]")
assert(payload.Units.player.Texts.shared.templateId==beforeMain and payload.Units.player.Texts.state.stateTemplateIds.dead==beforeState)
-- Old confirmations cannot act after selection/layout changes or release.
Click(manager.actionButtons.delete)
local oldDelete=manager.deleteDialog
ns.db.char.activeLayoutId="layout:b"; Click(oldDelete.primaryButton)
assert(ns.db.global.TextTemplates[duplicateId])
oldDelete:Close(); ns.db.char.activeLayoutId="layout:a"
Click(manager.actionButtons.delete); oldDelete=manager.deleteDialog
local staleDelete=oldDelete.primaryButton.events.OnClick
oldDelete:Close(); staleDelete(); NoErrors()
assert(ns.db.global.TextTemplates[duplicateId])
-- A newly added reference after opening confirmation is still guarded by Delete.
Click(manager.actionButtons.delete)
local deletion=manager.deleteDialog
payload.Units.player.Texts.late={templateId=duplicateId}
Click(deletion.primaryButton)
assert(not deletion.released and ns.db.global.TextTemplates[duplicateId])
manager.deleteDialog:Close(); payload.Units.player.Texts.late=nil
window.Refresh(); Click(manager.actionButtons.delete)
local expected
for index,entry in ipairs(manager.userEntries) do
    if entry.templateId==duplicateId then
        expected=(manager.userEntries[index+1] or manager.userEntries[index-1] or manager.builtinEntries[1]).templateId
    end
end
Click(manager.deleteDialog.primaryButton)
assert(not ns.db.global.TextTemplates[duplicateId] and manager.selectedTemplateId==expected)
print("PASS: Built-in/User Copy without FK mutation, Delete guard and neighboring selection")

-- Cache divider textures across actual refresh/close/reopen and pool reuse.
local function Dividers()
    local result={}
    for _,row in ipairs(manager.listGroup.children) do
        for _,child in ipairs(row.children or {}) do
            if child._fpDivider then result[child._fpDivider]=true end
        end
    end
    assert(Count(result)==2); return result
end
window.Refresh(); local seen=Dividers()
for _=1,20 do
    window.Refresh(); manager.dialog:Close(); assert(ns.GUIController.OpenTextBuilderWindow()); NoErrors()
    for texture in pairs(Dividers()) do assert(seen[texture],"divider texture accumulated") end
    assert(manager.selectedTemplateId==manager.userEntries[1].templateId)
end
-- No User rows: built-in fallback. No entries: neutral state and no actions.
local savedUsers=ns.db.global.TextTemplates
ns.db.global.TextTemplates={}; manager.dialog:Close(); window.OpenManager(); NoErrors()
assert(#manager.userEntries==0 and manager.selectedTemplateId==builtInId)
local list=library.Entity.List
library.Entity.List=function()return{}end
window.Refresh(); NoErrors()
assert(manager.selectedTemplateId==nil and Count(manager.actionButtons)==0)
assert(manager.expression.label:GetText()=="" and manager.usageLabel.label:GetText()=="")
library.Entity.List=list; ns.db.global.TextTemplates=savedUsers
manager.dialog:Close(); window.OpenManager(); NoErrors()
assert(manager.previewPanel.frame:GetHeight()==80 and manager.window.frame:GetHeight()==720)
print("PASS: repeated refresh/reopen, cached dividers, initial fallback and empty state")
