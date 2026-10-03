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

local function ValidateConfig(config, types, collection, dynamicFields, stateField)
    if type(config) ~= "table" then return false end
    for key, value in pairs(config) do
        local kind = type(value)
        if type(key) == "string" and not collection then
            if not dynamicFields and types[key] and not types[key][kind] then return false end
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
            local isDecorations = key == "decorations"
            if not ValidateConfig(value, types, key == "Texts" or key == stateField or isDecorations, dynamicFields or isDecorations, stateField) then return false end
        elseif kind ~= "number" and kind ~= "string" and kind ~= "boolean" then
            return false
        end
    end
    return true
end

local function ValidateUnits(units, stateField)
    if type(units) ~= "table" or not next(units) then return false, "units-invalid" end
    local types = BuildFieldTypes()
    if not types then return false, "service-unavailable" end
    for unitKey, config in pairs(units) do
        if not UNITS[unitKey] or not ValidateConfig(config, types, nil, nil, stateField) then return false, "units-invalid" end
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
    return true
end

-- E5 explicit target validation, not an alternate active Import/Export dispatch.
function Transfer.ValidateEntityPayload(payload)
    if not OnlyKeys(payload, {Units=true}) then return false, "payload-invalid" end
    return ValidateUnits(payload.Units, "stateTemplateIds")
end

local function ValidatePayload(payload)
    if not OnlyKeys(payload, {Units=true, TextTemplates=true}) then return false, "payload-invalid" end
    if type(payload.Units) ~= "table" or not next(payload.Units) then return false, "units-invalid" end
    if type(payload.TextTemplates) ~= "table" then return false, "templates-invalid" end
    local valid, reason = ValidateUnits(payload.Units, "stateTemplates")
    if not valid then return false, reason end
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
    if record.formatVersion ~= 2 then return nil, "layout-version" end
    return ns.LayoutTransferVNext.Export(record, ns.db)
end

function Transfer.Import(text, options)
    return ns.LayoutTransferVNext.Import(text, ns.db, options)
end
