-- Run from the repository root: lua54 Tests/LayoutTransfer.lua
local ns = {L={THEME_DEFAULT="Default"}}
local function Load(path) assert(loadfile(path))("FocalPoint", ns) end
Load("Data/Defaults.lua")
Load("Data/Themes.lua")
Load("Services/CompositionPresenceStorage.lua")
Load("Services/LayoutService.lua")
Load("Engine/UnitFrame/Shared/UnitFrameUtils.lua")
Load("Services/UserLayoutStore.lua")
Load("Services/LayoutMutations.lua")
Load("Services/LayoutTransferCodec.lua")
Load("Services/LayoutTransfer.lua")
C_AddOns = {GetAddOnMetadata=function() return "2.0.5-test" end}
local codec, transfer = ns.LayoutTransferCodec, ns.LayoutTransfer
local function Equal(left, right)
    assert(assert(codec.Encode(left)) == assert(codec.Encode(right)), "data changed")
end
local defaults = ns:GetDefaultDB()
local payload = ns.LayoutService.CopyPayload({Units=defaults.profile.Units, TextTemplates=defaults.profile.TextTemplates})
payload.Units.player.decorations = {{id="decoration1", point="CENTER", texture="fp:decoration:missing", width=99}}
payload.Units.player.Texts.Health.font = "lsm:font:missing"
payload.Units.player.Texts.Color = {enabled=true, tag="[name]", font="lsm:font:missing"}
payload.TextTemplates["Custom ü"] = "[name]\n[hp:cur] | literal \\ \0"
ns.db = {
    profile={General={secret="must stay here"}},
    global={UserLayouts={ ["layout:original"]={name="My Layout", formatVersion=1, payload=payload, createdFrom={id="private-character"}} },
        UserPresets={legacy={metadata={name="Legacy"}, layout={}}}, ProfileAutomation={enabled=true}, LayoutMigration={version=2}},
    char={activeLayoutId="layout:original", LayoutAssignments={specialization={[71]="layout:original"}}},
    profileKeys={private="private"},
}
ns.ActivateLayout = function() error("activation forbidden") end
ns.ProfileTransfer = setmetatable({}, {__index=function() error("legacy transfer forbidden") end})
local before = ns.LayoutService.Clone(ns.db)
local encoded, reason = transfer.Export("layout:original")
assert(encoded, reason)
Equal(before, ns.db)
assert(encoded == transfer.Export("layout:original"), "non-deterministic export")
local document = assert(codec.Decode(encoded))
assert(document.addonVersion == "2.0.5-test")
assert(document.name == "My Layout" and document.formatVersion == 1)
assert(not document.createdFrom and not document.id)
Equal(document.payload, payload)
assert(not transfer.Export("builtin:default"))
assert(not transfer.Export("profile:legacy"))
assert(not transfer.Export("userPreset:legacy"))

local ids = {}
for _ = 1, 3 do
    local ok, id, name = transfer.Import(encoded)
    assert(ok, id)
    assert(id:match("^layout:") and id ~= "layout:original" and not ids[id])
    ids[id] = true
    local record = ns.db.global.UserLayouts[id]
    assert(record.name == name and name ~= "My Layout")
    Equal(record.payload, ns.LayoutService.CopyPayload(payload))
    Equal(before.char, ns.db.char)
    Equal(before.profile, ns.db.profile)
    Equal(before.global.ProfileAutomation, ns.db.global.ProfileAutomation)
    Equal(before.global.LayoutMigration, ns.db.global.LayoutMigration)
    Equal(before.global.UserPresets, ns.db.global.UserPresets)
    Equal(before.global.UserLayouts["layout:original"], ns.db.global.UserLayouts["layout:original"])
end
local names = {}
for _, record in pairs(ns.db.global.UserLayouts) do assert(not names[record.name]); names[record.name]=true end
local collision = ns.LayoutService.Clone(document)
collision.name = "Default"
local ok, id, name = transfer.Import(assert(codec.Encode(collision)))
assert(ok and name ~= "Default", "built-in name collision not handled")

local function Reject(text, expected)
    local snapshot = ns.LayoutService.Clone(ns.db)
    local success, failure = transfer.Import(text)
    assert(not success, "invalid import accepted")
    if expected then assert(failure == expected, tostring(failure) .. " ~= " .. expected) end
    Equal(snapshot, ns.db)
end
local BASE64 = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
local function EncodeBase64(data)
    local output = {}
    for position = 1, #data, 3 do
        local a, b, c = string.byte(data, position, position + 2)
        local number = a * 65536 + (b or 0) * 256 + (c or 0)
        output[#output + 1] = BASE64:sub(math.floor(number / 262144) + 1, math.floor(number / 262144) + 1)
        output[#output + 1] = BASE64:sub(math.floor(number / 4096) % 64 + 1, math.floor(number / 4096) % 64 + 1)
        output[#output + 1] = b and BASE64:sub(math.floor(number / 64) % 64 + 1, math.floor(number / 64) % 64 + 1) or "="
        output[#output + 1] = c and BASE64:sub(number % 64 + 1, number % 64 + 1) or "="
    end
    return table.concat(output)
end
local function RejectRaw(raw, expected)
    local value, reason = codec.Decode("FocalPointLayout:1:" .. EncodeBase64(raw))
    assert(value == nil and reason == expected, tostring(reason) .. " ~= " .. expected)
end
Reject("", "invalid-header")
Reject("return os.execute('bad')", "invalid-header")
Reject(encoded:sub(1, -2), "invalid-transport")
Reject(encoded .. "junk")
Reject(encoded:gsub("FocalPointLayout:1:", "FocalPointLayout:2:"), "transfer-version")
Reject("FocalPointLayout:1:!!!!", "invalid-header")
Reject("FocalPointLayout:1:", "invalid-transport")
RejectRaw("d257:", "too-complex")
RejectRaw("d1:s1:ad0:t1:k2:b1", "invalid-encoding") -- dictionary ID out of range
RejectRaw("d1:s1:ad0:t1:v1:b1", "invalid-encoding") -- value reference used as key
RejectRaw("d1:s1:ad1:s1:bt1:k1:k1:", "invalid-encoding") -- key reference used as value
local dictionaryLimit = codec.MaxDictionaryBytes
codec.MaxDictionaryBytes = 3
RejectRaw("d1:s4:abcdd0:t0:", "too-large")
codec.MaxDictionaryBytes = dictionaryLimit
Reject(string.rep("x", codec.MaxBytes + 1), "too-large")
for _, change in ipairs({
    function(d) d.transferSchema=7 end,
    function(d) d.formatVersion=999 end,
    function(d) d.name=nil end,
    function(d) d.name="  " end,
    function(d) d.name=string.rep("a",65) end,
    function(d) d.payload=nil end,
    function(d) d.payload.Units=nil end,
    function(d) d.payload.Units.player="bad" end,
    function(d) d.payload.Units.player.width="bad" end,
    function(d) d.payload.Units.player.point="invalid" end,
    function(d) d.payload.Units.player.scale=0 end,
    function(d) d.payload.Units.player.backgroundColor={"bad",0,0} end,
    function(d) d.payload.Units.player.Texts={bad=false} end,
    function(d) d.payload.TextTemplates={bad={}} end,
    function(d) d.profileKeys={} end,
    function(d) d.id="layout:original" end,
    function(d) d.payload.General={} end,
}) do
    local invalid = ns.LayoutService.Clone(document)
    change(invalid)
    Reject(assert(codec.Encode(invalid)))
end
local cyclic={}; cyclic.self=cyclic
assert(not codec.Encode(cyclic))
assert(not codec.Encode({fn=function() end}))
assert(not codec.Encode(setmetatable({},{})))
assert(not codec.Encode({bad=math.huge}))
assert(not codec.Encode({tooLong=string.rep("x", codec.MaxBytes / 2 + 1)}))
local deep={}; local nextTable=deep
for _=1,40 do nextTable.child={}; nextTable=nextTable.child end
assert(not codec.Encode(deep))
local repeated = {left={}, right={}}
for index = 1, codec.MaxDictionaryEntries / 2 do
    local key = string.format("repeat%03d", index)
    repeated.left[key], repeated.right[key] = "value", "value"
end
Equal(repeated, assert(codec.Decode(assert(codec.Encode(repeated))))) -- includes dictionary ID 256
Equal({mixed={ [1]="a", [3]="sparse", key=false }, raw="\0\255\n"}, assert(codec.Decode(assert(codec.Encode({mixed={ [1]="a", [3]="sparse", key=false }, raw="\0\255\n"})))))

-- Reloading the transfer code does not migrate, activate or duplicate records.
local snapshot = ns.LayoutService.Clone(ns.db)
Load("Services/LayoutTransfer.lua")
Equal(snapshot, ns.db)
STANDARD_TEXT_FONT = "Fonts\\FRIZQT__.TTF"
Load("Services/MediaRegistry.lua")
for _, mediaType in ipairs({"font", "statusbar", "decoration"}) do
    local resolved = ns.MediaRegistry.ResolveReference("fp:" .. mediaType .. ":missing", mediaType)
    assert(resolved.fallbackUsed and type(resolved.resolvedAsset) == "string" and resolved.resolvedAsset ~= "")
end
print("PASS: layout roundtrip, unique IDs/names, built-ins, active/assignment isolation, payload boundary and malformed/bounded codec cases; " .. #encoded .. " bytes")
Load("Tests/LayoutTransferUI.lua")
