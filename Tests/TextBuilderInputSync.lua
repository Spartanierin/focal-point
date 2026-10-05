-- lua54 Tests/TextBuilderInputSync.lua
-- Real Builder bindings and AceGUI callbacks. Assert writes, not native caret behavior.
local file = assert(io.open("Tests/TextBuilderDraftSafety.lua"))
local source = file:read("*a"); file:close()
local stop = assert(source:find('local a, b = Payload("A"), Payload("B")', 1, true))
local f = assert(load(source:sub(1, stop - 1) .. "\nreturn f", "@InputSync/Fixture"))()
local ns, Load, Upvalue = f.ns, f.Load, f.Upvalue
for _, path in ipairs({
    "Engine/Text/Shared/TextElementRoles.lua", "Engine/Text/Shared/TextTemplateResolver.lua",
    "Engine/Text/Shared/TextTemplateValidation.lua", "Data/BuiltInTextTemplates.lua",
    "GUI/Pages/TextBuilder/TextBuilderEntity.lua",
}) do Load(path) end
local builder = ns.GUI.Pages.TextBuilder
local R2 = builder.EntityBuilder
ns.db = {char = {activeLayoutId = "layout:a"}, global = {
    TextTemplates = {}, UserLayouts = {["layout:a"] = {name = "A", formatVersion = 2, payload = {Units = {}}}},
}}
local function NoErrors() assert(#f.env.errors == 0, table.concat(f.env.errors, "\n")) end
local function CheckBindings(context, name, content, nameFlag, contentFlag)
    local session = context.r2Session
    local writes = {name = 0, content = 0}
    local originals = {name = name.SetText, content = content.SetText}
    local function Watch(widget, key, flag)
        widget.SetText = function(self, value)
            writes[key] = writes[key] + 1
            assert(context[flag] == true, "programmatic write must keep its reentrancy guard")
            local token = session.draftToken
            originals[key](self, value)
            -- Explicitly exercise a callback during sync; the native fixture does not emit it.
            self:Fire("OnTextChanged", value)
            assert(session.draftToken == token, "programmatic sync must not mutate the draft again")
        end
    end
    Watch(name, "name", nameFlag); Watch(content, "content", contentFlag)
    local function Input(widget, value)
        local token = session.draftToken
        widget.editbox:SetText(value)
        widget.editbox:Run("OnTextChanged")
        NoErrors()
        assert(session.draftToken ~= token, "user input must still update the draft")
    end
    Input(name, "health"); Input(content, "hello world")
    assert(session.name == "health" and session.content == "hello world")
    assert(session.nameDirty and session.contentDirty and R2.IsDirty(session))
    builder.RefreshWindowState(); NoErrors()
    assert(writes.name == 0 and writes.content == 0, "identical input must not be written back")
    assert(not context[nameFlag] and not context[contentFlag])

    assert(R2.SetName(session, "programmatic name"))
    local token = session.draftToken
    builder.RefreshWindowState(); NoErrors()
    assert(name:GetText() == session.name and writes.name == 1 and writes.content == 0)
    assert(session.draftToken == token and context[nameFlag] == false)
    assert(R2.SetContent(session, "programmatic expression"))
    token = session.draftToken
    builder.RefreshWindowState(); NoErrors()
    assert(content:GetText() == session.content and writes.name == 1 and writes.content == 1)
    assert(session.draftToken == token and context[contentFlag] == false)
    builder.RefreshWindowState(); NoErrors()
    assert(writes.name == 1 and writes.content == 1, "stable refresh must be write-free")
    name.SetText, content.SetText = originals.name, originals.content
end

assert(ns.GUIController.OpenTextBuilderWindow({entity = true, kind = "new-template", layoutId = "layout:a"}))
local consumer = assert(Upvalue(builder.RefreshWindowState, "consumerContext"))
CheckBindings(consumer, consumer.nameEdit, consumer.contentEdit, "nameSync", "contentSync")
assert(not consumer.dialog.primaryButton.disabled)
assert(consumer.preview.label:GetText() == consumer.r2Session.content)
local applyTag
ns.GUI.Pages.TagLibrary = {Open = function(options) applyTag = options.onApply end}
consumer.tagButton:Fire("OnClick"); NoErrors()
-- Supply an insertion offset only; native cursor movement remains an ingame test.
local native = consumer.contentEdit.editbox
local oldGetCursor = native.GetCursorPosition
native.GetCursorPosition = function() return 4 end
assert(applyTag("[name]")); NoErrors()
assert(consumer.r2Session.content == "prog[name]rammatic expression")
assert(consumer.contentEdit:GetText() == consumer.r2Session.content)
native.GetCursorPosition = oldGetCursor
print("PASS: Consumer name/content non-redundant sync, draft, preview, create status and tag insert")

-- Return the draft to its baseline so closing does not need a discard dialog.
assert(R2.SetName(consumer.r2Session, "")); assert(R2.SetContent(consumer.r2Session, ""))
builder.HideWindow(); NoErrors(); assert(consumer.released)

-- Exercise the existing full Entity-Builder binding with an editable new-template session.
-- The normal New Template route above covers the consumer UI; no extra UI route is introduced.
local session = assert(R2.Open({entity = true, kind = "new-template", layoutId = "layout:a"}, ns.db))
local context = assert(builder.CreateEntityWindow())
local bind = assert(Upvalue(R2.OpenWindow, "BindR2Window"))
bind(context, session); NoErrors()
CheckBindings(context, context.templateNameEdit, context.templateEdit, "r2NameSync", "r2Sync")
assert(not context.saveButton.disabled)
print("PASS: Entity-Builder name/content non-redundant sync, programmatic changes and reentrancy")
