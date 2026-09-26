-- lua54 Tests/ListSelectionRow.lua
-- Reuse the LayoutTransfer UI doubles, but register/execute the actual row widget.
-- Window/native drawing are simulated; palette lookup, row states and manager
-- open/refresh/selection/reopen are production code.
local ns = { L = {} }
local f = assert(io.open("Tests/LayoutTransferUI.lua"))
local source = f:read("*a"); f:close()
local boundary = assert(source:find('Load("GUI/Editor/LayoutManager/LayoutManagerView.lua")', 1, true))
local ace, Frame, dialogs = assert(load(source:sub(1, boundary - 1)
    .. "\nreturn AceGUI, Frame, dialogs", "@ListSelectionRow/UIFixture"))("FocalPoint", ns)
STANDARD_TEXT_FONT = "Fonts\\FRIZQT__.TTF"
unpack = table.unpack
local function Load(path) assert(loadfile(path))("FocalPoint", ns) end
Load("GUI/GUISkin.lua")
local palette = ns.GUI.Skins.GetFormPalette()
local colors = assert(palette.ListSelectionRow, "canonical ListSelectionRow palette missing")
local function Equal(a, b)
    if type(a) ~= "table" then assert(a == b, tostring(a) .. " ~= " .. tostring(b)); return end
    assert(type(b) == "table")
    for k, v in pairs(a) do Equal(v, b[k]) end
    for k in pairs(b) do assert(a[k] ~= nil, "extra field " .. tostring(k)) end
end
local function Copy(value)
    if type(value) ~= "table" then return value end
    local result = {}; for k, v in pairs(value) do result[k] = Copy(v) end; return result
end
-- Accepted existing WIP values, not a new palette or runtime fallback.
Equal(colors, {
    fill = { 0.065, 0.056, 0.048, 0.86 },
    fillHover = { 0.105, 0.085, 0.060, 0.94 },
    fillSelected = { 0.205, 0.145, 0.055, 0.98 },
    border = { 0.23, 0.20, 0.16, 0.54 },
    borderHover = { 0.48, 0.37, 0.20, 0.78 },
    borderSelected = { 0.96, 0.73, 0.22, 0.98 },
    marker = { 1.00, 0.80, 0.24, 1.00 },
    markerMuted = { 0.58, 0.53, 0.42, 0.36 },
    name = { 0.93, 0.91, 0.84, 1.00 },
    nameSelected = { 1.00, 0.98, 0.88, 1.00 },
})
local paletteBefore = Copy(palette)
function CreateFrame()
    local frame = Frame()
    frame.scripts = {}
    function frame:CreateFontString() return CreateFrame() end
    function frame:CreateTexture() return CreateFrame() end
    function frame:SetScript(event, callback) self.scripts[event] = callback end
    for _, method in ipairs({ "SetBackdropColor", "SetBackdropBorderColor", "SetColorTexture", "SetTextColor" }) do
        frame[method] = function(self, ...)
            local rgba = { ... }; assert(#rgba == 4, method .. " requires RGBA")
            for i = 1, 4 do assert(type(rgba[i]) == "number" and rgba[i] >= 0 and rgba[i] <= 1) end
            self["last" .. method] = rgba
        end
    end
    function frame:SetText(text) self.text = text end
    function frame:SetWidth(width) self.width = width end
    function frame:SetAlpha(alpha) self.alpha = alpha end
    return frame
end
UIParent = CreateFrame()
local constructors, versions = {}, {}
function ace:GetWidgetVersion(kind) return versions[kind] end
function ace:RegisterWidgetType(kind, constructor, version) constructors[kind], versions[kind] = constructor, version end
local baseCreate, baseRelease = ace.Create, ace.Release
local widgetMeta = getmetatable(ace:Create("Label"))
function ace:RegisterAsWidget(widget) return setmetatable(widget, widgetMeta) end
function ace:Create(kind)
    if not constructors[kind] then return baseCreate(self, kind) end
    local widget = constructors[kind]()
    widget.kind, widget.children, widget.callbacks = kind, {}, {}
    widget:OnAcquire()
    return widget
end
function ace:Release(widget)
    baseRelease(self, widget)
    if widget.OnRelease then widget:OnRelease() end
end
function ace:ClearFocus() end
ns.db = { char = { activeLayoutId = "layout:active" } }
ns.LayoutService = { ListLayoutSummaries = function() return {
    { id = "layout:active", name = "Active", source = "userLayout" },
    { id = "layout:other", name = "Other", source = "userLayout" },
    { id = "builtin:default", name = "Default", source = "builtin" },
} end }
Load("GUI/Editor/LayoutManager/LayoutManagerView.lua")
local manager = ns.GUI.Editor.LayoutManager
assert(manager.Open())
local library = dialogs[1]
local function Row(id)
    for _, child in ipairs(library.body.children) do
        for _, row in ipairs(child.children or {}) do
            if row.item and row.item.id == id then return row end
        end
    end
    error("missing layout row " .. id)
end
local function Painted(row, fill, border, name, marker, width, alpha)
    Equal(row.frame.lastSetBackdropColor, colors[fill])
    Equal(row.frame.lastSetBackdropBorderColor, colors[border])
    Equal(row.nameText.lastSetTextColor, colors[name])
    Equal(row.marker.lastSetColorTexture, colors[marker])
    Equal(row.marker.width, width); Equal(row.marker.alpha, alpha)
end
local row = Row("layout:other")
Painted(row, "fill", "border", "name", "markerMuted", 2, 0.55)
row.frame.scripts.OnEnter(row.frame)
Painted(row, "fillHover", "borderHover", "name", "markerMuted", 2, 1)
row.frame.scripts.OnLeave(row.frame)
Painted(row, "fill", "border", "name", "markerMuted", 2, 0.55)
Painted(Row("layout:active"), "fillSelected", "borderSelected", "nameSelected", "marker", 6, 1)
row.frame.scripts.OnMouseDown(row.frame, "LeftButton") -- real selection + list rebuild
assert(row.released and row.item == nil)
row = Row("layout:other")
Painted(row, "fillSelected", "borderSelected", "nameSelected", "marker", 6, 1)
row.frame.scripts.OnEnter(row.frame)
Painted(row, "fillSelected", "borderSelected", "nameSelected", "marker", 6, 1)
Painted(Row("layout:active"), "fill", "border", "name", "marker", 4, 1)
Equal(Row("layout:active").statusText.text, "Active")
Equal(Row("builtin:default").statusText.text, "Read-only")
Equal(ns.db.char.activeLayoutId, "layout:active")
manager.Close(); assert(not library.window.frame:IsShown())
assert(manager.Open()); assert(library.window.frame:IsShown()); Equal(#dialogs, 1)
Painted(Row("layout:active"), "fillSelected", "borderSelected", "nameSelected", "marker", 6, 1)
Equal(palette, paletteBefore)
print("PASS: canonical ten-field RGBA palette, real LayoutManager rows normal/hover/selected/active, selection rebuild, release/reopen and palette immutability")
