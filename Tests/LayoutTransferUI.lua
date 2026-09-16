-- Controller integration with a widget double; run via Tests/LayoutTransfer.lua.
-- Native rendering, clipboard behavior and pixel geometry still need in-game QA.
local _, ns = ...
local dialogs, windowPool = {}, {}
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
function forms.FocusWindow(window) window:Show() end
function forms.CreateCompactFormDialog(options)
    local dialog = {window=AceGUI:Create("Window"), body=AceGUI:Create("Region"), footer=AceGUI:Create("Region"), status=AceGUI:Create("Label"), options=options}
    dialog.shell={header=AceGUI:Create("Region"), status=AceGUI:Create("Region"), frame=Frame()}
    dialog.shell.status:AddChild(dialog.status)
    dialog.window.frame._fpCompactFormShell=dialog.shell
    function dialog:SetStatus(text) self.status:SetText(text) end
    function dialog:SetActions(actions)
        for key, action in pairs(actions) do
            local button=AceGUI:Create("Button")
            button:SetCallback("OnClick", action.onClick)
            self[key .. "Button"]=button; self.footer:AddChild(button)
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
local actions, list=library.body.children[1], library.body.children[2]
local importButton, exportButton=actions.children[1], actions.children[2]
local function Row(id)
    for _, row in ipairs(list.children) do if row.item and row.item.id==id then return row end end
end
local function Snapshot() return assert(ns.LayoutTransferCodec.Encode(ns.db)) end
local function Click(button) assert(not button.disabled); button:Fire("OnClick") end
local before=Snapshot()
Click(Row("builtin:default"))
assert(exportButton.disabled)
Click(Row("layout:original"))
Click(exportButton)
local export=dialogs[#dialogs]
local exportEdit=export.body.children[1]
assert(exportEdit.highlighted)
local encoded=exportEdit:GetText()
assert(encoded==ns.LayoutTransfer.Export("layout:original"))
Click(export.cancelButton)
assert(export.window.released and export.body.released and export.footer.released and export.shell.status.released)
assert(AceGUI.FocusedWidget==nil and before==Snapshot())
local active=assert(ns.LayoutTransferCodec.Encode(ns.db.char))
for _=1,3 do
    Click(importButton)
    local dialog=dialogs[#dialogs]
    local edit=dialog.body.children[1]
    assert(dialog.primaryButton.disabled)
    edit:SetText("broken")
    before=Snapshot()
    Click(dialog.primaryButton)
    assert(before==Snapshot() and dialog.status:GetText()~="")
    edit:SetText(encoded)
    Click(dialog.primaryButton)
    assert(dialog.status:GetText():match("Imported:") and dialog.primaryButton.disabled)
    assert(active==ns.LayoutTransferCodec.Encode(ns.db.char))
    local selected
    for _, row in ipairs(list.children) do if row.selected then selected=row.item end end
    assert(selected and selected.source=="userLayout" and selected.id~="layout:original" and not selected.active)
    assert(ns.UserLayoutStore.GetRawReadOnly(selected.id))
    manager.Close()
    assert(dialog.window.released and dialog.body.released and dialog.footer.released and dialog.shell.status.released)
    assert(AceGUI.FocusedWidget==nil)
    assert(manager.Open())
end
manager.Close()
print("PASS: manager export gating, import error/success, selection without activation, close/reopen and transfer widget release")
