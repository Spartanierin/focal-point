local addonName, ns = ...
local Transfer = {}
ns.LayoutTransfer = Transfer
local FORMAT_VERSION = 1
local UNITS = { player=true, target=true, targettarget=true, pet=true, focus=true, focustarget=true, boss=true }
local POINTS = { TOPLEFT=true, TOP=true, TOPRIGHT=true, LEFT=true, CENTER=true, RIGHT=true, BOTTOMLEFT=true, BOTTOM=true, BOTTOMRIGHT=true }
local STRATA = { BACKGROUND=true, LOW=true, MEDIUM=true, HIGH=true, DIALOG=true, FULLSCREEN=true, FULLSCREEN_DIALOG=true, TOOLTIP=true }

local function OnlyKeys(value, allowed)
    if type(value) ~= "table" then return false end
    for key in pairs(value) do if not allowed[key] then return false end end
    return true
end

-- Use the shipped configuration's field types, including fields inside
-- dynamic text/component records. Unknown extension fields remain plain data.
local function BuildFieldTypes()
    local defaults = ns.GetDefaultDB and ns:GetDefaultDB()
    if not (defaults and defaults.profile and defaults.profile.Units) then return nil end
    local types = {}
    local function Collect(value)
        for key, entry in pairs(value) do
            if type(key) == "string" then
                types[key] = types[key] or {}
                types[key][type(entry)] = true
            end
            if type(entry) == "table" then Collect(entry) end
        end
    end
    Collect(defaults.profile.Units)
    return types
end

local function ValidateConfig(config, types, collection)
    if type(config) ~= "table" then return false end
    for key, value in pairs(config) do
        local kind = type(value)
        if type(key) == "string" and not collection then
            if types[key] and not types[key][kind] then return false end
            if (key == "point" or key == "relativePoint" or key:match("Point$")) and not POINTS[value] then return false end
            if key == "frameStrata" and not STRATA[value] then return false end
        end
        if kind == "number" and math.abs(value) > 1000000000 then return false end
        if kind == "table" then
            if not collection and type(key) == "string" and key:lower():match("color$") then
                for channel, component in pairs(value) do
                    if not ((type(channel) == "number" and channel >= 1 and channel <= 4)
                        or channel == "r" or channel == "g" or channel == "b" or channel == "a")
                        or type(component) ~= "number" then return false end
                end
            end
            if not ValidateConfig(value, types, key == "Texts" or key == "stateTemplates") then return false end
        elseif kind ~= "number" and kind ~= "string" and kind ~= "boolean" then
            return false
        end
    end
    return true
end

local function ValidatePayload(payload)
    if not OnlyKeys(payload, {Units=true, TextTemplates=true}) then return false, "payload-invalid" end
    if type(payload.Units) ~= "table" or not next(payload.Units) then return false, "units-invalid" end
    if type(payload.TextTemplates) ~= "table" then return false, "templates-invalid" end
    local types = BuildFieldTypes()
    if not types then return false, "service-unavailable" end
    for unitKey, config in pairs(payload.Units) do
        if not UNITS[unitKey] or not ValidateConfig(config, types) then return false, "units-invalid" end
        if config.scale ~= nil and config.scale <= 0 then return false, "units-invalid" end
        for key in pairs(config) do if type(key) ~= "string" then return false, "units-invalid" end end
        if config.Texts ~= nil then
            if type(config.Texts) ~= "table" then return false, "units-invalid" end
            for key, record in pairs(config.Texts) do
                if type(key) ~= "string" or type(record) ~= "table" then return false, "units-invalid" end
            end
        end
        if config.decorations ~= nil then
            if type(config.decorations) ~= "table" then return false, "units-invalid" end
            for key, record in pairs(config.decorations) do
                if type(key) ~= "number" or key < 1 or key % 1 ~= 0 or type(record) ~= "table" then return false, "units-invalid" end
            end
        end
    end
    for name, text in pairs(payload.TextTemplates) do
        if type(name) ~= "string" or name == "" or type(text) ~= "string" then return false, "templates-invalid" end
    end
    return true
end

local function ValidateDocument(document)
    if not OnlyKeys(document, {transferSchema=true, addonVersion=true, name=true, formatVersion=true, payload=true}) then
        return false, "document-invalid"
    end
    if document.transferSchema ~= ns.LayoutTransferCodec.SchemaVersion then return false, "transfer-version" end
    if type(document.addonVersion) ~= "string" or document.addonVersion == "" or #document.addonVersion > 128 then
        return false, "document-invalid"
    end
    if type(document.name) ~= "string" or document.name:find("[%c|]") then return false, "name-invalid" end
    local valid, reason = ns.LayoutMutations.ValidateLayoutName(document.name)
    if not valid and reason ~= "duplicate-name" then return false, reason end
    if document.formatVersion ~= FORMAT_VERSION then return false, "layout-version" end
    return ValidatePayload(document.payload)
end

function Transfer.Export(layoutId)
    if type(layoutId) ~= "string" or not layoutId:match("^layout:") then return nil, "user-layout-required" end
    local record = ns.UserLayoutStore.GetRawReadOnly(layoutId)
    if type(record) ~= "table" then return nil, "layout-not-found" end
    local document = {
        transferSchema = ns.LayoutTransferCodec.SchemaVersion,
        addonVersion = C_AddOns and C_AddOns.GetAddOnMetadata(addonName, "Version") or "unknown",
        name = record.name,
        formatVersion = record.formatVersion,
        payload = record.payload,
    }
    -- Serialize before traversing configuration so cycles/metatables and limits
    -- are rejected even for a damaged local record. Export never normalizes it.
    local encoded, reason = ns.LayoutTransferCodec.Encode(document)
    if not encoded then return nil, reason end
    local valid
    valid, reason = ValidateDocument(document)
    if not valid then return nil, reason end
    return encoded
end

function Transfer.Import(text)
    local document, reason = ns.LayoutTransferCodec.Decode(text)
    if document == nil then return false, reason end
    local valid
    valid, reason = ValidateDocument(document)
    if not valid then return false, reason end
    local ok, payload = pcall(ns.LayoutService.CopyPayload, document.payload)
    if not ok then return false, "payload-invalid" end
    valid, reason = ValidatePayload(payload)
    if not valid then return false, reason end
    -- The only persisted operation is the canonical write of one new record.
    -- No resolver, activation, assignment, automation or migration calls.
    local id = ns.UserLayoutStore.GenerateId()
    if type(id) ~= "string" or not id:match("^layout:") or ns.UserLayoutStore.GetRawReadOnly(id) ~= nil then
        return false, "store-write-failed"
    end
    local name
    valid, name = ns.LayoutMutations.ValidateLayoutName(document.name)
    if not valid and name == "duplicate-name" then
        name = ns.LayoutMutations.SuggestLayoutCopyName(document.name)
        valid, name = ns.LayoutMutations.ValidateLayoutName(name)
    end
    if not valid then return false, name end
    local stored = ns.UserLayoutStore.PutRaw(id, {name=name, payload=payload, formatVersion=FORMAT_VERSION})
    if stored ~= id then return false, "store-write-failed" end
    return true, id, name
end
