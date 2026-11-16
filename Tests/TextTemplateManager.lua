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
Load("Data/KeyMap.lua")
Load("Engine/Localization.lua")
local originalTagDatabase = ns.UnitFrame.GetTagDatabase
ns.UnitFrame.GetTagDatabase = function()
    return {{token = "[absorb:cur:abbr]", description = "INFO_TAG_DESC_ABSORB_CUR_ABBR"}}
end


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
-- Model the native OptionsFrame NineSlice boundary, not its rasterized geometry.
local getLayout, applyNamed = NineSliceUtil.GetLayout, NineSliceUtil.ApplyLayoutByName
local textureAPI, legacyAtlas = C_Texture, GetAtlasInfo
local unique = {
    TopLeftCorner = {atlas = "%s-NineSlice-CornerTopLeft"},
    TopRightCorner = {atlas = "%s-NineSlice-CornerTopRight"},
    BottomLeftCorner = {atlas = "%s-NineSlice-CornerBottomLeft"},
    BottomRightCorner = {atlas = "%s-NineSlice-CornerBottomRight"},
    TopEdge = {atlas = "_%s-NineSlice-EdgeTop"}, BottomEdge = {atlas = "_%s-NineSlice-EdgeBottom"},
    LeftEdge = {atlas = "!%s-NineSlice-EdgeLeft"}, RightEdge = {atlas = "!%s-NineSlice-EdgeRight"},
    Center = {atlas = "%s-NineSlice-Center"},
}
NineSliceUtil.GetLayout = function(name)
    if name == "UniqueCornersLayout" then return unique end
    return getLayout(name)
end
NineSliceUtil.ApplyLayoutByName = function(host, name, kit)
    if name ~= "UniqueCornersLayout" then return applyNamed(host, name, kit) end
    assert(kit == "OptionsFrame")
    host.testLayoutName, host.testTextureKit = name, kit
    for key, piece in pairs(unique) do
        host[key] = host[key] or host:CreateTexture(nil, "BORDER")
        local atlas = string.format(piece.atlas, kit)
        local getInfo = C_Texture and C_Texture.GetAtlasInfo or GetAtlasInfo
        -- Native SetupPieceVisuals only applies an atlas when its info exists.
        if getInfo(atlas) then
            host[key].testAtlas = atlas
            host[key]:SetAtlas(atlas, true)
        end
    end
end
local function AtlasInfo(name)
    if name:find("OptionsFrame", 1, true) then return {width = 32, height = 32} end
    local previous = textureAPI and textureAPI.GetAtlasInfo or legacyAtlas
    return previous and previous(name)
end
C_Texture = {GetAtlasInfo = AtlasInfo}
local createDialog, managerOptions = f.widgets.CreateCompactFormDialog, nil
f.widgets.CreateCompactFormDialog = function(options)
    managerOptions = options
    return createDialog(options)
end
assert(ns.GUIController.OpenTextBuilderWindow()); NoErrors()
f.widgets.CreateCompactFormDialog = createDialog
assert(managerOptions.windowChrome == "editmode")
assert(managerOptions.titleFontSize == 16 and managerOptions.titleOffsetY == -7)
f.Equal(managerOptions.headerDrag, {left = 8, right = 36, top = 0, height = 32})
local manager = assert(Upvalue(window.OpenManager, "managerContext"))
-- The global Options action routes without an object/template context and reuses
-- the existing manager; closing it leaves the editor/options owner available.
local options = ns.GUI.Editor.OptionsDialog
local optionsContext = assert(Upvalue(options.Open, "context"))
local manageButton = assert(optionsContext.widgets.manageTextTemplates)
assert(manageButton.text:GetText() == "Manage Text Templates…")
assert(manageButton.parent == optionsContext.dialog.body and manageButton:IsFullWidth())
local openBuilder, managerOpens = ns.GUIController.OpenTextBuilderWindow, 0
ns.GUIController.OpenTextBuilderWindow = function(...)
    assert(select("#", ...) == 0, "Options must not supply an editing context")
    managerOpens = managerOpens + 1
    return openBuilder(...)
end
local editorState, activeLayout = ns.GUI.Editor.State, ns.db.char.activeLayoutId
for cycle = 1, 3 do
    manager.dialog:Close(); options.Open()
    Click(manageButton)
    assert(managerOpens == cycle and manager.window.frame:IsShown())
    assert(Upvalue(window.OpenManager, "managerContext") == manager)
    assert(Upvalue(builder.RefreshWindowState, "consumerContext") == nil)
    manager.dialog:Close()
    assert(optionsContext.window.frame:IsShown())
    options.Close(); options.Open()
    assert(Upvalue(options.Open, "context") == optionsContext)
    assert(ns.GUI.Editor.State == editorState and ns.db.char.activeLayoutId == activeLayout)
end
options.Open(); Click(manageButton); options.Close()
ns.GUIController.OpenTextBuilderWindow = openBuilder
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
assert(manager.listGroup.LayoutFunc == f.ace:GetLayout("Flow"))
assert(manager.detailGroup.parent == manager.dialog.body and manager.detailGroup:IsFullWidth())
assert(manager.listGroup.frame:GetHeight() == 262 and manager.newButton.frame:GetWidth() == 160)
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
local function FindCaption(root, caption)
    if root.label and root.label:GetText() == caption then return root end
    for _, child in ipairs(root.children or {}) do
        local found = FindCaption(child, caption)
        if found then return found end
    end
end
local optionsHeading = assert(FindCaption(optionsContext.dialog.body, "Editor"))
local function CheckHeadings()
    local _, size = optionsHeading.label:GetFont()
    assert(size == 14)
    for _, title in ipairs({manager.headers.user.children[1], manager.headers.builtin.children[1],
        manager.expressionTitle, manager.previewTitle}) do
        f.Equal({title.label:GetFont()}, {optionsHeading.label:GetFont()})
        f.Equal(title.label.lastSetTextColor, optionsHeading.label.lastSetTextColor)
    end
end
CheckHeadings()
for _, row in pairs(manager.rows) do
    assert(row.frame:GetHeight() == 30 and not row.binding.description and not row.binding.status)
    assert(row.binding.presentation.labelSize == 12 and row.binding.presentation.height == 30)
    f.Equal({row.detail:GetPoint(1)}, {"RIGHT", row.frame, "RIGHT", -8, 0})
    assert(row.label.points.TOP.y == -2 and row.label.points.BOTTOM.y == 2)
    row.frame:GetScript("OnEnter")(row.frame)
    assert(row.hovered and row.frame:GetHeight() == 30)
    f.Equal({row.detail:GetPoint(1)}, {"RIGHT", row.frame, "RIGHT", -8, 0})
    row.frame:GetScript("OnLeave")(row.frame)
    assert(not row.hovered and row.frame:GetHeight() == 30)
    f.Equal({row.detail:GetPoint(1)}, {"RIGHT", row.frame, "RIGHT", -8, 0})
end
assert(manager.rows[userA].binding.detail == "[name]")
assert(manager.previewPanel.Variant == "result_stack" and manager.previewPanel.frame:GetHeight() == 56)
assert(manager.previewPanel:IsFullWidth() and manager.previewPanel.frame.clipsChildren)
assert(manager.previewValue.label.lastSetJustifyH[1] == "CENTER")
assert(manager.expressionScroll.frame:GetHeight() == 48 and manager.expressionScroll.type == "ScrollFrame")
local palette = ns.GUI.Skins.GetFormPalette()
local function CheckSurface(widget, section)
    assert(not widget.frame._fpSectionFill or not widget.frame._fpSectionFill:IsShown())
    for _, edge in ipairs({"Top", "Bottom", "Left", "Right"}) do
        local border = widget.frame["_fpSectionBorder" .. edge]
        if section or edge ~= "Top" then
            assert(not border or not border:IsShown())
        else
            assert(border:IsShown())
            f.Equal(border.lastSetColorTexture, palette.Chrome.sectionBorder)
        end
    end
    if not section then return end
    local box = assert(widget.frame._fpTextManagerGroupBox)
    assert(box:GetParent() == widget.frame:GetParent(), "native corners must not be clipped by the preview/scroll frame")
    assert(box:IsShown() and box.testLayoutName == "UniqueCornersLayout" and box.testTextureKit == "OptionsFrame")
    assert(box.lastEnableMouse == false or box.lastEnableMouse[1] == false)
    for key, piece in pairs(unique) do assert(box[key].testAtlas == string.format(piece.atlas, "OptionsFrame")) end
    f.Equal(box.points.TOPLEFT,
        {relative = widget.frame, relativePoint = "TOPLEFT", x = -16, y = 15})
    f.Equal(box.points.BOTTOMRIGHT,
        {relative = widget.frame, relativePoint = "BOTTOMRIGHT", x = 16, y = -15})
    assert(box:GetAlpha() == 1)
end
CheckSurface(manager.listGroup, true)
CheckSurface(manager.informationGroup, true); CheckSurface(manager.previewGroup, true)
CheckSurface(manager.actionContainer)
local information = manager.nameLabel.parent.parent
assert(information.parent == manager.detailGroup and information.frame:GetHeight() == 110)
assert(manager.typeLabel.parent.parent == information and manager.expressionScroll.parent == information)
-- Both titles belong to the framed content; test source anchors, not fake atlas pixels.
assert(manager.nameLabel.parent == information.children[1])
assert(manager.listGroup.children[1] == manager.headers.user)
assert(manager.headers.user.frame.points.TOPLEFT.relative == manager.listGroup.content)
assert(manager.headers.user.frame.points.TOPLEFT.y == -3)
assert(manager.detailGroup.children[1] == information)
assert(information.frame.points.TOPLEFT.relative == manager.detailGroup.content)
assert(information.frame.points.TOPLEFT.y == 0)
local function CountGroupBoxes(root)
    local box = root.frame and root.frame._fpTextManagerGroupBox
    local count = box and box:IsShown() and 1 or 0
    for _, child in ipairs(root.children or {}) do count = count + CountGroupBoxes(child) end
    return count
end
assert(CountGroupBoxes(manager.dialog.body) == 3)
assert(information == manager.informationGroup)
assert(not manager.detailGroup.frame._fpTextManagerGroupBox or not manager.detailGroup.frame._fpTextManagerGroupBox:IsShown())
assert(not manager.previewPanel.frame._fpTextManagerGroupBox or not manager.previewPanel.frame._fpTextManagerGroupBox:IsShown())
assert(manager.usageLabel.parent.parent == manager.previewGroup)
assert(manager.previewTitle.parent.parent == manager.previewGroup)
assert(manager.previewPanel.parent == manager.previewGroup)
assert(manager.previewGroup.parent == manager.detailGroup and manager.previewGroup.frame:GetHeight() == 114)
local paddedGroups = {manager.headers.user, manager.headers.builtin, information,
    manager.previewTitle.parent, manager.usageLabel.parent, manager.statusTarget.parent}
local function CheckTextPadding()
    for _, group in ipairs(paddedGroups) do
        f.Equal(group._fpSectionPadding, {left = 10, right = 0, top = 0, bottom = 0})
        f.Equal(group.content.points.TOPLEFT,
            {relative = group.frame, relativePoint = "TOPLEFT", x = 10, y = 0})
        f.Equal(group.content.points.BOTTOMRIGHT,
            {relative = group.frame, relativePoint = "BOTTOMRIGHT", x = 0, y = 0})
        assert(group.content:GetWidth() == math.max(0, group.frame:GetWidth() - 10))
    end
    assert(not manager.previewGroup._fpSectionPadding or manager.previewGroup._fpSectionPadding.left == 0)
    assert(manager.previewPanel._fpSectionPadding.left == 8 and manager.previewPanel._fpSectionPadding.right == 8)
    assert(manager.previewValue.label.lastSetJustifyH[1] == "CENTER")
end
CheckTextPadding()
assert(manager.listGroup.scrollframe:GetParent() == manager.listGroup.frame)
assert(manager.listGroup.scrollbar:GetParent() == manager.listGroup.scrollframe)
f.Equal(manager.listGroup.scrollbar.points.BOTTOMLEFT,
    {relative = manager.listGroup.scrollframe, relativePoint = "BOTTOMRIGHT", x = 4, y = 16})
assert(not manager.previewPanel.frame._fpSectionAccent:IsShown())
assert(manager.detailGroup.frame:GetHeight() == 234)
local detailHeight = 0
for _, child in ipairs(manager.detailGroup.children) do detailHeight = detailHeight + child.frame:GetHeight() end
assert(detailHeight == 234)
local plannedHeight = 0
local listTop, detailTop, footerTop
for _, child in ipairs(manager.dialog.body.children) do
    if child == manager.listGroup then listTop = plannedHeight end
    if child == manager.detailGroup then detailTop = plannedHeight end
    if child == manager.actionContainer then footerTop = plannedHeight end
    plannedHeight = plannedHeight + child.frame:GetHeight()
end
assert(plannedHeight == 650, "manager content slots must fit the unchanged window")
assert(listTop == 68 and detailTop == 344 and footerTop == 608)
assert(detailTop - (listTop + manager.listGroup.frame:GetHeight()) == 14)
local informationTop = detailTop
local informationBottom = informationTop + information.frame:GetHeight()
local previewTop = informationBottom + manager.detailGroup.children[2].frame:GetHeight()
local previewBottom = previewTop + manager.previewGroup.frame:GetHeight()
assert(informationBottom == 454 and previewTop == 464 and previewBottom == 578)
assert(listTop + manager.listGroup.frame:GetHeight() < informationTop)
assert(informationBottom < previewTop and previewBottom + 15 < footerTop)
assert(manager.detailGroup.children[3] == manager.previewGroup)
local previewHeight = 0
for _, child in ipairs(manager.previewGroup.children) do previewHeight = previewHeight + child.frame:GetHeight() end
assert(previewHeight == 114)
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
for _, row in pairs(rows) do
    assert(row.frame:GetHeight() == 30)
    f.Equal({row.detail:GetPoint(1)}, {"RIGHT", row.frame, "RIGHT", -8, 0})
end
assert(Count(manager.actionButtons) == 1 and manager.actionButtons.duplicate)
assert(not manager.usage and manager.usageLabel.label:GetText() == "")
assert(manager.typeLabel.label:GetText() == "Built-in \194\183 Read-only")
local beforeMain, beforeState = payload.Units.player.Texts.shared.templateId, payload.Units.player.Texts.state.stateTemplateIds.dead
Select(userB)
assert(manager.expression.label:GetText() == "Custom text\n[hp:cur]" and releases == 0)
assert(payload.Units.player.Texts.shared.templateId == beforeMain and payload.Units.player.Texts.state.stateTemplateIds.dead == beforeState)
local long = string.rep("[name] long expression\n", 100)
ns.db.global.TextTemplates[userB].content = long
window.Refresh(); NoErrors()
assert(manager.expression.label:GetText() == "Custom text\n" .. long and manager.window.frame:GetHeight() == 720)
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
assert(manager.usageLabel.label:GetText():find("Texts: 2 · Saved user layouts: 2",1,true))
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
options.Open(); Click(manageButton)
assert(Consumer() == consumer and not consumer.released)
assert(consumer.contentEdit:GetText() == "discarded" and builder.HasUnsavedChanges())
assert(ns.db.global.TextTemplates[userA].content == "[name]")
options.Close(); window.HideManager()
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
local sourceContent=assert(library.ResolveTemplateEntity(builtInId, ns.db)).content
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
local sectionRegions = {}
for _, widget in ipairs({manager.listGroup, manager.informationGroup, manager.previewGroup, manager.actionContainer}) do
    local frame = widget.frame
    sectionRegions[frame] = {box = frame._fpTextManagerGroupBox, top = frame._fpSectionBorderTop}
end
for _=1,20 do
    window.Refresh(); manager.dialog:Close(); assert(ns.GUIController.OpenTextBuilderWindow()); NoErrors()
    for texture in pairs(Dividers()) do assert(seen[texture],"divider texture accumulated") end
    assert(manager.selectedTemplateId==manager.userEntries[1].templateId)
    for frame, regions in pairs(sectionRegions) do
        assert(regions.box == frame._fpTextManagerGroupBox and regions.top == frame._fpSectionBorderTop)
    end
    CheckSurface(manager.listGroup, true)
    CheckSurface(manager.informationGroup, true); CheckSurface(manager.previewGroup, true)
    assert(CountGroupBoxes(manager.dialog.body) == 3)
    CheckSurface(manager.actionContainer)
    CheckTextPadding()
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
assert(manager.previewPanel.frame:GetAlpha() == 0)
assert(CountGroupBoxes(manager.dialog.body) == 3)
assert(manager.informationGroup.frame._fpTextManagerGroupBox:GetAlpha() == 1)
library.Entity.List=list; ns.db.global.TextTemplates=savedUsers
manager.dialog:Close(); window.OpenManager(); NoErrors()
assert(manager.previewPanel.frame:GetHeight()==56 and manager.window.frame:GetHeight()==720)
print("PASS: repeated refresh/reopen, cached dividers, initial fallback and empty state")

local currentUsers = ns.db.global.TextTemplates
local many = {}
for index = 1, 123 do
    many[Id(index + 100)] = {name = "Same", content = "[name]"}
end
local longId = Id(101)
many[longId].name = string.rep("Long template name ", 20)
ns.db.global.TextTemplates = many
window.Refresh(); Select(longId)
assert(#manager.userEntries == 123)
for _, row in pairs(manager.rows) do assert(row.frame:GetHeight() == 30) end
local listHeight = 0
for _, child in ipairs(manager.listGroup.children) do
    local anchor = child.frame.points.TOPLEFT
    assert(anchor.relative == manager.listGroup.content)
    f.Equal({anchor.relativePoint, anchor.x, anchor.y}, {"TOPLEFT", 0, -(listHeight + 3)})
    listHeight = listHeight + child.frame:GetHeight() + 3
end
local lastEntry = manager.builtinEntries[#manager.builtinEntries]
local lastRow = manager.listGroup.children[#manager.listGroup.children]
assert(lastRow == manager.rows[lastEntry.templateId])
assert(manager.listGroup.content:GetHeight() == listHeight)
manager.listGroup:SetScroll(1000)
assert(manager.listGroup.localstatus.scrollvalue == 1000)
assert(manager.listGroup.localstatus.offset == math.max(0,
    math.floor(listHeight - manager.listGroup.scrollframe:GetHeight())))
assert(manager.nameLabel.label:GetText() == many[longId].name)
assert(manager.nameLabel.label.lastSetMaxLines[1] == 1)
assert(manager.nameLabel.label.lastSetWordWrap[1] == false)
CheckSurface(manager.listGroup, true)
ns.db.global.TextTemplates = currentUsers
window.Refresh(); NoErrors()
print("PASS: 123 templates, duplicate names and bounded selected-name presentation")

-- Eight border assets are required, Center is optional; retain native piece handling.
local decorate = Upvalue(Upvalue(window.OpenManager, "BuildManagerBody"), "ManagerSurface")
local probe = f.ace:Create("SimpleGroup")
C_Texture = {GetAtlasInfo = function(name)
    if name == "OptionsFrame-NineSlice-Center" then return nil end
    return AtlasInfo(name)
end}
decorate(probe, true)
local box = assert(probe.frame._fpTextManagerGroupBox)
assert(box:IsShown() and #box.regions == 9 and box.Center.testAtlas == nil)
for key, piece in pairs(unique) do
    if key ~= "Center" then assert(box[key].testAtlas == string.format(piece.atlas, "OptionsFrame")) end
end
C_Texture = {GetAtlasInfo = function(name)
    if name == "OptionsFrame-NineSlice-Center" then return false end
    return AtlasInfo(name)
end}
decorate(probe, true)
assert(probe.frame._fpTextManagerGroupBox == box and box:IsShown() and #box.regions == 9)
assert(box.Center.testAtlas == nil)
for key, piece in pairs(unique) do
    if key ~= "Center" then
        local missing = string.format(piece.atlas, "OptionsFrame")
        C_Texture = {GetAtlasInfo = function(name)
            if name == missing then return nil end
            return AtlasInfo(name)
        end}
        decorate(probe, true)
        assert(not box:IsShown() and #box.regions == 9, "missing border asset must hide the cached NineSlice: " .. key)
    end
end
C_Texture = nil; GetAtlasInfo = AtlasInfo
decorate(probe, true)
assert(probe.frame._fpTextManagerGroupBox == box)
assert(box:IsShown() and #box.regions == 9)
decorate(probe, true)
assert(probe.frame._fpTextManagerGroupBox == box and #box.regions == 9)
C_Texture = {GetAtlasInfo = function() error("atlas unavailable") end}
decorate(probe, true); assert(not box:IsShown())
C_Texture = {GetAtlasInfo = AtlasInfo}
local nativeNineSlice = NineSliceUtil
NineSliceUtil = nil
decorate(probe, true); assert(not box:IsShown())
NineSliceUtil = nativeNineSlice
local nativeGetLayout = NineSliceUtil.GetLayout
NineSliceUtil.GetLayout = function(name)
    if name == "UniqueCornersLayout" then return nil end
    return nativeGetLayout(name)
end
decorate(probe, true); assert(not box:IsShown())
NineSliceUtil.GetLayout = nativeGetLayout
decorate(probe, true); assert(box:IsShown())
f.ace:Release(probe); assert(not box:IsShown())
print("PASS: native groupbox atlas/API/layout fallback, legacy lookup and exact NineSlice reuse/release")

local listBox = manager.listGroup.frame._fpTextManagerGroupBox
local detailBox = manager.informationGroup.frame._fpTextManagerGroupBox
local previewBox = manager.previewGroup.frame._fpTextManagerGroupBox
C_Texture = {GetAtlasInfo = function(name)
    if name == "OptionsFrame-NineSlice-Center" then return nil end
    return AtlasInfo(name)
end}
manager.dialog:Close(); window.OpenManager(); NoErrors()
assert(CountGroupBoxes(manager.dialog.body) == 3)
assert(manager.listGroup.frame._fpTextManagerGroupBox == listBox)
assert(manager.informationGroup.frame._fpTextManagerGroupBox == detailBox)
assert(manager.previewGroup.frame._fpTextManagerGroupBox == previewBox)
C_Texture = {GetAtlasInfo = function(name)
    if name == "_OptionsFrame-NineSlice-EdgeTop" then return false end
    return AtlasInfo(name)
end}
manager.dialog:Close(); window.OpenManager(); NoErrors()
assert(CountGroupBoxes(manager.dialog.body) == 0)
assert(not listBox:IsShown() and not detailBox:IsShown() and not previewBox:IsShown())
C_Texture = {GetAtlasInfo = AtlasInfo}
detailBox:SetAlpha(0)
previewBox:SetAlpha(0)
window.OpenManager(); NoErrors()
assert(CountGroupBoxes(manager.dialog.body) == 3)
assert(manager.listGroup.frame._fpTextManagerGroupBox == listBox)
assert(manager.informationGroup.frame._fpTextManagerGroupBox == detailBox)
assert(manager.previewGroup.frame._fpTextManagerGroupBox == previewBox)
CheckSurface(manager.listGroup, true); CheckSurface(manager.informationGroup, true); CheckSurface(manager.previewGroup, true)
print("PASS: exactly three groupboxes, unchanged content/footer positions and availability/alpha reset on reopen")

-- Manager-only information: examples, bounded expressions and existing tooltip UX.
local previousTooltip, previousLocale, previousGetLocale = GameTooltip, ns.L, GetLocale
local tooltip = {SetOwner = function(self, owner) self.owner = owner end,
    GetOwner = function(self) return self.owner end,
    SetText = function(self, text) self.text = text end,
    Show = function(self) self.shown = true end, Hide = function(self) self.shown = false end}
GameTooltip = tooltip
assert(manager.previewTitle.type == "InteractiveLabel" and manager.usageLabel.type == "InteractiveLabel")
local savedContent = ns.db.global.TextTemplates[userB].content
local entryCount = #manager.userEntries
for _, case in ipairs({
    {"[name]", "[name]"}, {"", "Empty expression"}, {" \n\t", "Empty expression"},
    {string.rep("ä", 40), string.rep("ä", 24) .. "..."},
    {"[name]\n" .. string.rep("x", 80), "[name] " .. string.rep("x", 17) .. "..."},
    {"|Ttest|t", "||Ttest||t"},
}) do
    ns.db.global.TextTemplates[userB].content = case[1]
    window.Refresh(); Select(userB)
    assert(manager.rows[userB].binding.detail == case[2])
    assert(ns.db.global.TextTemplates[userB].content == case[1] and #manager.userEntries == entryCount)
    assert(manager.rows[userB].frame:GetHeight() == 30)
end
ns.db.global.TextTemplates[userB].content = "[absorb:cur:abbr]"
-- This fixture does not load the full tag runtime: verify the unchanged provider boundary.
local previewProvider = ns.UnitFrame.BuildTemplatePreview
ns.UnitFrame.BuildTemplatePreview = function(_, expression)
    assert(expression == "[absorb:cur:abbr]")
    return "12.5k"
end
window.Refresh(); Select(userB)
assert(manager.previewValue.label:GetText() == "12.5k")
ns.UnitFrame.BuildTemplatePreview = function() return "" end
window.Refresh(); Select(userB)
assert(manager.previewValue.label:GetText() == "[absorb:cur:abbr]")
ns.UnitFrame.BuildTemplatePreview = previewProvider
ns.db.global.TextTemplates[userB].content = savedContent
for _, locale in ipairs({"enUS", "deDE"}) do
    local localized = {L = {}}
    GetLocale = function() return locale end
    assert(loadfile("Locales/" .. locale .. ".lua"))("FocalPoint", localized)
    ns.L = localized.L
    window.Refresh(); Select(userA)
    assert(manager.previewTitle.label:GetText() == localized.L.INFO_TEXT_MANAGER_EXAMPLE_PREVIEW)
    CheckHeadings()
    for _, count in ipairs({0, 1, 2}) do
        local summary = string.format(localized.L.INFO_TEXT_MANAGER_USAGE_SUMMARY, count, count)
        local expected = locale == "enUS" and ("Texts: " .. count .. " · Saved user layouts: " .. count)
            or ("Texte: " .. count .. " · Gespeicherte eigene Layouts: " .. count)
        assert(summary == expected)
    end
    local usage = manager.usage
    assert(manager.usageLabel.label:GetText() == string.format(localized.L.INFO_TEXT_MANAGER_USED_IN,
        "A – " .. ns.GetLabel(ns.KeyMap.Units, "player")) .. string.format(localized.L.INFO_TEXT_MANAGER_MORE_PLACES, 1)
        .. "\n" .. string.format(localized.L.INFO_TEXT_MANAGER_USAGE_SUMMARY, usage.texts, usage.layouts))
    assert(usage.texts == 2 and usage.layouts == 2 and usage.main == 2 and usage.state == 3 and usage.disabled == 1)
    manager.previewTitle:Fire("OnEnter")
    assert(tooltip.shown and tooltip.text == localized.L.INFO_TEXT_MANAGER_PREVIEW_HELP)
    manager.previewTitle:Fire("OnLeave"); assert(not tooltip.shown)
    manager.usageLabel:Fire("OnEnter")
    assert(tooltip.shown and tooltip.text == localized.L.INFO_TEXT_MANAGER_USAGE_HELP .. "\n\n" .. localized.L.INFO_TEXT_MANAGER_SHARED_HELP)
    assert(manager.actionButtons.delete.disabled)
    manager.actionButtons.edit:Fire("OnEnter")
    assert(tooltip.text == localized.L.INFO_TEXT_MANAGER_SHARED_HELP)
    local priorContent = ns.db.global.TextTemplates[userB].content
    for _, expression in ipairs({"[absorb:cur:abbr]", "[absorb:cur:abbr][name]", "[unknown]", "Hello", " [absorb:cur:abbr] "}) do
        ns.db.global.TextTemplates[userB].content = expression
        window.Refresh(); Select(userB)
        local description = expression == "[absorb:cur:abbr]" and localized.L.INFO_TAG_DESC_ABSORB_CUR_ABBR
            or localized.L.INFO_TEXT_MANAGER_CUSTOM_TEXT
        assert(manager.expression.label:GetText() == description .. "\n" .. expression)
        assert(manager.expressionTitle.label:GetText() == localized.L.INFO_TEXT_MANAGER_WHAT_SHOWS)
    end
    ns.db.global.TextTemplates[userB].content = priorContent
    window.Refresh()
    Select(userB)
    assert(manager.usage.texts == 1 and manager.usage.layouts == 1)
    assert(manager.usageLabel.label:GetText():find(string.format(localized.L.INFO_TEXT_MANAGER_USED_IN,
        "A – " .. ns.GetLabel(ns.KeyMap.Units, "player")), 1, true))
    assert(not manager.usageLabel.label:GetText():find("+1", 1, true))
    local originalName = ns.db.global.UserLayouts["layout:a"].name
    ns.db.global.UserLayouts["layout:a"].name = "Renamed"
    window.Refresh(); Select(userA)
    assert(manager.usageLabel.label:GetText():find("Renamed – ", 1, true))
    ns.db.global.UserLayouts["layout:a"].name = string.rep("L", 100)
    Select(userA)
    assert(manager.usageLabel.label:GetText():find(string.rep("L", 14) .. "...", 1, true))
    assert(not manager.usageLabel.label:GetText():find(string.rep("L", 100), 1, true))
    ns.db.global.UserLayouts["layout:a"].name = originalName
    local inactive = ns.db.global.UserLayouts["layout:b"]
    ns.db.global.UserLayouts["layout:b"] = nil
    Select(userA)
    assert(manager.usage.texts == 1 and manager.usage.layouts == 1 and manager.usage.state == 2)
    ns.db.global.UserLayouts["layout:b"] = inactive
    local rawReader = ns.UserLayoutStore.GetRawReadOnly
    ns.UserLayoutStore.GetRawReadOnly = function() return nil end
    Select(userA)
    assert(manager.usageLabel.label:GetText():find(localized.L.INFO_TEXT_MANAGER_UNKNOWN_LAYOUT, 1, true))
    assert(manager.usage.texts == 2 and manager.usage.layouts == 2)
    ns.UserLayoutStore.GetRawReadOnly = rawReader
    ns.db.global.UserLayouts["layout:0"] = {name = "Other", formatVersion = 2,
        payload = {Units = {unresolved = {Texts = {text = {templateId = userA, enabled = false}}}}}}
    Select(userA)
    assert(manager.usageLabel.label:GetText():find(localized.L.INFO_TEXT_MANAGER_UNKNOWN_UNIT, 1, true))
    assert(not manager.usageLabel.label:GetText():find("unresolved", 1, true))
    assert(manager.usage.texts == 3 and manager.usage.layouts == 3 and manager.usage.disabled == 2)
    ns.db.global.UserLayouts["layout:0"] = nil
    window.Refresh(); Select(userA)
    local unusedLocaleId = Id(9998)
    ns.db.global.TextTemplates[unusedLocaleId] = {name = "Unused locale", content = ""}
    window.Refresh(); Select(unusedLocaleId)
    assert(manager.usage.texts == 0 and manager.usage.layouts == 0)
    assert(manager.usageLabel.label:GetText() == localized.L.INFO_TEXT_MANAGER_NOT_USED)
    assert(not manager.actionButtons.delete.disabled)
    ns.db.global.TextTemplates[unusedLocaleId] = nil
    window.Refresh()
    Select(builtInId)
    assert(not tooltip.shown and manager.usageLabel.label:GetText() == "")
    manager.usageLabel:Fire("OnEnter"); assert(not tooltip.shown)
end
ns.L, GetLocale = previousLocale, previousGetLocale
Select(userA)
local usageAPI, usageCalls = library.Entity.Usage, 0
library.Entity.Usage = function(...)
    usageCalls = usageCalls + 1
    return usageAPI(...)
end
window.Refresh(); assert(usageCalls == 1, "list rebuild must not scan usage per row")
Select(userA); assert(usageCalls == 2, "counts and places must share one scan")
library.Entity.Usage = usageAPI
local unusedId = Id(9999)
ns.db.global.TextTemplates[unusedId] = {name = "Unused", content = ""}
window.Refresh(); Select(unusedId)
assert(not manager.actionButtons.delete.disabled)
assert(manager.usageLabel.label:GetText() == ns.L.INFO_TEXT_MANAGER_NOT_USED)
manager.actionButtons.edit:Fire("OnEnter"); assert(not tooltip.shown)
manager.usageLabel:Fire("OnEnter")
assert(tooltip.text == ns.L.INFO_TEXT_MANAGER_USAGE_HELP)
manager.dialog:Close(); assert(not tooltip.shown)
window.OpenManager(); Select(unusedId)
manager.previewTitle:Fire("OnEnter"); assert(tooltip.shown)
window.HideManager(); assert(not tooltip.shown)
window.ShowManager()
ns.db.global.TextTemplates[unusedId] = nil
window.Refresh(); Select(userA); NoErrors()
print("PASS: DE/EN example preview, neutral counts 0/1/2, reference/help semantics and bounded expression rows")

-- Local surface and FontString overrides must not leak to pooled consumers.
local surfaces = {manager.listGroup, manager.detailGroup, information, manager.previewGroup, manager.previewPanel, manager.actionContainer}
local pooledRow = assert(manager.rows[manager.selectedTemplateId])
local _, detailSize = pooledRow.detail:GetFont()
assert(detailSize == 11)
local enter = Upvalue(pooledRow.frame:GetScript("OnEnter"), "original")
local leave = Upvalue(pooledRow.frame:GetScript("OnLeave"), "original")
f.ace:Release(manager.window)
local _, restoredDetailSize = pooledRow.detail:GetFont()
assert(restoredDetailSize == 10)
f.Equal({pooledRow.detail:GetPoint(1)}, {"TOPRIGHT", pooledRow.frame, "TOPRIGHT", -8, -4})
assert(pooledRow.frame:GetScript("OnEnter") == enter and pooledRow.frame:GetScript("OnLeave") == leave)
assert(manager.nameLabel.label.lastSetMaxLines[1] == 0)
assert(not tooltip.shown)
GameTooltip = previousTooltip
ns.UnitFrame.GetTagDatabase = originalTagDatabase
for _, group in ipairs(paddedGroups) do
    f.Equal(group._fpSectionPadding, {left = 0, right = 0, top = 0, bottom = 0})
end
for _, widget in ipairs(surfaces) do
    assert(not widget.frame._fpSectionFill or not widget.frame._fpSectionFill:IsShown())
    assert(not widget.frame._fpTextManagerGroupBox or not widget.frame._fpTextManagerGroupBox:IsShown())
    for _, edge in ipairs({"Top", "Bottom", "Left", "Right"}) do
        local border = widget.frame["_fpSectionBorder" .. edge]
        assert(not border or not border:IsShown())
    end
end
print("PASS: manager-only surfaces hidden on release before widget pooling")
NineSliceUtil.GetLayout, NineSliceUtil.ApplyLayoutByName = getLayout, applyNamed
C_Texture, GetAtlasInfo = textureAPI, legacyAtlas
