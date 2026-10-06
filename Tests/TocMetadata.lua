-- lua54 Tests/TocMetadata.lua
-- Release guard for the canonical addon TOC metadata.
local file = assert(io.open("FocalPoint.toc", "r"))
local metadata, order = {}, {}
for line in file:lines() do
    local key, value = line:match("^## ([%w%-]+):%s*(.*)$")
    if key then
        assert(metadata[key] == nil, "duplicate TOC metadata: " .. key)
        metadata[key] = value
        order[#order + 1] = key
    end
end
file:close()

local function Require(key, expected)
    assert(type(metadata[key]) == "string" and metadata[key] ~= "", "missing TOC metadata: " .. key)
    if expected then
        assert(metadata[key] == expected,
            string.format("TOC %s expected %q, got %q", key, expected, metadata[key]))
    end
end

local function RequirePresent(key)
    assert(type(metadata[key]) == "string", "missing TOC metadata: " .. key)
end

Require("Title", "Focal Point")
Require("Interface", "120100, 16001")
Require("Version", "2.2.2")
Require("Author", "Spartanierin")
Require("Notes")
Require("SavedVariables", "FocalPointDB")
Require("Category", "Unit Frames")
Require("IconTexture", "Interface\\AddOns\\FocalPoint\\Media\\icon.tga")
Require("X-oUF", "FocalPoint")
Require("X-Curse-Project-ID", "1542419")
RequirePresent("X-Wago-ID")

local interfaceIndex, versionIndex
for index, key in ipairs(order) do
    if key == "Interface" then interfaceIndex = index end
    if key == "Version" then versionIndex = index end
end
assert(interfaceIndex and versionIndex and interfaceIndex < versionIndex,
    "TOC Interface must precede Version")
assert(metadata.Interface == "120100, 16001",
    "TOC Interface order must be Retail 120100, Forever 16001")

print("PASS: canonical TOC Interface, Version and release metadata")
