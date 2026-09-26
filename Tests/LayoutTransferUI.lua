-- Controller integration with a widget double; run via Tests/LayoutTransfer.lua.
-- Native rendering, clipboard behavior and pixel geometry still need in-game QA.
local _, ns = ...
local dialogs, windowPool = {}, {}
local statusTargets = {}
local AceGUI = {}
local function Noop() end
local function Frame()
    return setmetatable({shown=true}, {__index=function(_, key)
        if key == "CreateTexture" then return Frame end
        if key == "IsShown" then return function(self) return self.shown end end
        if key == "Show" then return function(self) self.shown=true end end
        if key == "Hide" then return function(self) self.shown=false end end
        return Noop
    end})
end
local methods = {}
for _, key in ipairs({"SetLayout", "SetFullWidth", "SetFullHeight", "SetWidth", "SetHeight", "SetAutoAdjustHeight", "SetNumLines", "SetLabel", "DisableButton", "DoLayout", "FixScroll"}) do
    methods[key] = Noop
end
function methods:SetCallback(event, callback) self.callbacks[event]=callback end
function methods:Fire(event) if self.callbacks[event] then return self.callbacks[event](self, event) end end
function methods:SetText(value) self.text=value; self:Fire("OnTextChanged") end
function methods:GetText() return self.text end
function methods:SetDisabled(value) self.disabled=value end
function methods:AddChild(child) self.children[#self.children+1]=child end
function methods:ReleaseChildren()
    for _, child in ipairs(self.children) do AceGUI:Release(child) end
    self.children={}
end
function methods:SetItem(item, selected) self.item=item; self.selected=item.id==selected end
function methods:Show() self.frame:Show() end
function methods:Hide()
    if not self.frame:IsShown() then return end
    self.frame:Hide(); self:Fire("OnClose")
end
function methods:SetFocus() AceGUI.FocusedWidget=self end
function methods:ClearFocus() self.focusCleared=true end
function methods:HighlightText() self.highlighted=true end
function AceGUI:Create(kind)
    local widget = kind == "Window" and table.remove(windowPool) or nil
    widget = widget or setmetatable({frame=Frame()}, {__index=methods})
    widget.kind=kind; widget.children={}; widget.callbacks={}; widget.released=false
    widget.frame:Show()
    return widget
end
function AceGUI:Release(widget)
    assert(not widget.released, "double release")
    widget:ReleaseChildren(); widget:Hide(); widget.released=true
    if widget.kind == "Window" then windowPool[#windowPool+1]=widget end
end
function AceGUI:GetWidgetVersion() return 1 end -- row painting is outside this test
function AceGUI:ClearFocus() self.FocusedWidget:ClearFocus(); self.FocusedWidget=nil end
LibStub = function(name) assert(name=="AceGUI-3.0"); return AceGUI end
local forms = {}
local function ContainsWidget(parent, target)
    for _, child in ipairs(parent.children or {}) do
        if child == target or ContainsWidget(child, target) then return true end
    end
    return false
end
function forms.FocusWindow(window) window:Show() end
function forms.CreateCompactFormDialog(options)
    local body=AceGUI:Create("Region")
    local dialog = {window=AceGUI:Create("Window"), body=body, contentRoot=body, options=options}
    dialog.shell={body=body, contentRoot=body, frame=Frame()}
    function dialog.shell:Release() AceGUI:Release(self.body); self.frame:Hide() end
    dialog.window.frame._fpCompactFormShell=dialog.shell
    function dialog:SetStatus(text, role, target)
        assert(target, "SetStatus requires the dialog's explicit status target")
        assert(ContainsWidget(self.body, target), "SetStatus target does not belong to this dialog")
        statusTargets[self] = target
        self.statusRole = (role == "error" or role == "success") and role or "neutral"
        target:SetText(text)
    end
    function dialog:SetActions(actions, actionContainer)
        assert(actionContainer)
        for key, action in pairs(actions) do
            local button=AceGUI:Create("Button")
            button:SetCallback("OnClick", action.onClick)
            self[key .. "Button"]=button; actionContainer:AddChild(button)
        end
    end
    function dialog:Close() self.window:Hide() end
    function dialog:Show() self.window:Show() end
    dialogs[#dialogs+1]=dialog
    return dialog
end
ns.GUI = {Helpers={FormWidgets=forms}}
ns.L.LAYOUT_TRANSFER_IMPORTED="Imported: %s"
local function Load(path) assert(loadfile(path))("FocalPoint", ns) end
Load("GUI/Editor/LayoutManager/LayoutManagerView.lua")
local manager=ns.GUI.Editor.LayoutManager
assert(manager.Open())
local library=dialogs[1]
local actions, list, importButton, exportButton
local function FindLibraryAreas(widget)
    local importAction, exportAction, hasLayoutRows
    for _, child in ipairs(widget.children or {}) do
        if child.kind == "Button" then
            if child:GetText() == (ns.L.LAYOUT_TRANSFER_IMPORT or "LAYOUT_TRANSFER_IMPORT") then importAction=child end
            if child:GetText() == (ns.L.LAYOUT_TRANSFER_EXPORT or "LAYOUT_TRANSFER_EXPORT") then exportAction=child end
        elseif child.kind == "FocalPointLayoutManagerRow" and child.item and child.item.id then
            hasLayoutRows=true
        end
    end
    if widget.kind == "SimpleGroup" and importAction and exportAction then
        assert(not actions, "multiple Layout Manager import/export action areas found")
        actions, importButton, exportButton=widget, importAction, exportAction
    end
    if widget.kind == "ScrollFrame" and hasLayoutRows then
        assert(not list, "multiple Layout Manager layout lists found")
        list=widget
    end
    for _, child in ipairs(widget.children or {}) do FindLibraryAreas(child) end
end
FindLibraryAreas(library.body)
assert(actions, "Layout Manager import/export action area not found")
assert(list, "Layout Manager ScrollFrame with layout rows not found")
local function Row(id)
    for _, row in ipairs(list.children) do if row.item and row.item.id==id then return row end end
end
local function Snapshot() return assert(ns.LayoutTransferCodec.Encode(ns.db)) end
local function FindChild(widget, kind)
    for _, child in ipairs(widget.children or {}) do
        if child.kind == kind then return child end
        local nested = FindChild(child, kind)
        if nested then return nested end
    end
end
local function Click(button) assert(not button.disabled); button:Fire("OnClick") end
local before=Snapshot()
Click(Row("builtin:default"))
assert(exportButton.disabled)
Click(Row("layout:original"))
Click(exportButton)
local export=dialogs[#dialogs]
local exportEdit=FindChild(export.body, "MultiLineEditBox")
assert(exportEdit.highlighted)
local encoded=exportEdit:GetText()
assert(encoded==ns.LayoutTransfer.Export("layout:original"))
Click(export.cancelButton)
assert(export.window.released and export.body.released)
assert(AceGUI.FocusedWidget==nil and before==Snapshot())
local active=assert(ns.LayoutTransferCodec.Encode(ns.db.char))
for _=1,3 do
    Click(importButton)
    local dialog=dialogs[#dialogs]
    local edit=FindChild(dialog.body, "MultiLineEditBox")
    assert(dialog.primaryButton.disabled)
    edit:SetText("broken")
    before=Snapshot()
    Click(dialog.primaryButton)
    local statusTarget=assert(statusTargets[dialog], "import error did not address a status target")
    assert(before==Snapshot() and statusTarget:GetText()~="" and dialog.statusRole=="error")
    edit:SetText(encoded)
    Click(dialog.primaryButton)
    assert(statusTargets[dialog]==statusTarget, "import error and success used different status widgets")
    assert(statusTarget:GetText():match("Imported:") and dialog.primaryButton.disabled and dialog.statusRole=="success")
    assert(active==ns.LayoutTransferCodec.Encode(ns.db.char))
    local selected
    for _, row in ipairs(list.children) do if row.selected then selected=row.item end end
    assert(selected and selected.source=="userLayout" and selected.id~="layout:original" and not selected.active)
    assert(ns.UserLayoutStore.GetRawReadOnly(selected.id))
    manager.Close()
    assert(dialog.window.released and dialog.body.released)
    assert(AceGUI.FocusedWidget==nil)
    assert(manager.Open())
end
manager.Close()
print("PASS: manager export gating, import error/success, selection without activation, close/reopen and transfer widget release")
