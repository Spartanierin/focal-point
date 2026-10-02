local _, FocalPoint = ...

-- E3 is an explicit, offline preparation step. Not loaded by Init.xml and never
-- called by startup migration. E6 must deliberately integrate and publish it.
FocalPoint.TextTemplateEntityMigration = FocalPoint.TextTemplateEntityMigration or {}
local Migration = FocalPoint.TextTemplateEntityMigration

local function IsTable(value) return type(value) == 'table' and getmetatable(value) == nil end
local function IsKey(value) return type(value) == 'string' and value ~= '' end

-- Do not preserve source aliases: two layouts may reference the same table but
-- must still receive distinct identities. Cycles/metatables are not saved data.
local function Copy(value, visiting)
    if type(value) ~= 'table' then
        local kind = type(value)
        assert(kind == 'nil' or kind == 'string' or kind == 'number' or kind == 'boolean', 'invalid saved value')
        return value
    end
    visiting = visiting or {}
    assert(IsTable(value) and not visiting[value], 'invalid saved table')
    visiting[value] = true
    local result = {}
    for key, entry in pairs(value) do
        assert(type(key) == 'string' or type(key) == 'number', 'invalid saved key')
        result[key] = Copy(entry, visiting)
    end
    visiting[value] = nil
    return result
end

local function Equal(left, right)
    if left == right then return true end
    if type(left) ~= 'table' or type(right) ~= 'table' then return false end
    for key, value in pairs(left) do if not Equal(value, right[key]) then return false end end
    for key in pairs(right) do if left[key] == nil then return false end end
    return true
end

local function Keys(source)
    local keys = {}; for key in pairs(source) do keys[#keys + 1] = key end
    table.sort(keys, function(a, b)
        if type(a) ~= type(b) then return type(a) < type(b) end
        return a < b
    end)
    return keys
end

local function Add(result, code, layoutId, unitKey, textKey, stateKey, oldName)
    result.diagnostics[#result.diagnostics + 1] = {
        errorCode = code, layoutId = layoutId, unitKey = unitKey,
        textKey = textKey, stateKey = stateKey, oldName = oldName,
    }
end

local function Finish(result)
    result.ready = #result.diagnostics == 0
    if not result.ready then
        -- Never expose a partial candidate as a usable migration result.
        result.templates, result.layouts, result.mappings, result.idState = nil, nil, nil, nil
    end
    return result
end

-- The active modern UserLayout runtime reads bindings and records from the
-- same raw payload. Do not combine projected state names with a raw template map.
local function MaterializeStateIds(result, text, layoutId, unitKey, textKey, mapping)
    local stored = text.stateTemplates
    if stored == nil or stored == false then return nil end
    if not IsTable(stored) then
        Add(result, 'invalid-layout-payload', layoutId, unitKey, textKey)
        return nil
    end
    local ids = {}
    for _, stateKey in ipairs(Keys(stored)) do
        local name = stored[stateKey]
        if not IsKey(stateKey) or (name ~= false and not IsKey(name)) then
            Add(result, 'invalid-state-template-reference', layoutId, unitKey, textKey, stateKey, name)
        elseif name ~= false then
            if not mapping[name] then
                Add(result, 'missing-state-template-reference', layoutId, unitKey, textKey, stateKey, name)
            else
                ids[stateKey] = mapping[name]
            end
        end
    end
    -- No ghost->dead duplication: fallback remains a runtime concern.
    return next(ids) ~= nil and ids or nil
end

-- Prepared states are fully materialized: absence means no explicit binding,
-- never "fill from defaults later". E4/E6 must preserve this boundary.
function Migration.ValidatePreparedStateIds(stateIds, templates)
    if stateIds == nil then return true end
    if not IsTable(stateIds) or not IsTable(templates) then return false end
    local library = FocalPoint.TextTemplateLibrary
    for stateKey, id in pairs(stateIds) do
        if not IsKey(stateKey) or library.GetTemplateIdKind(id) ~= 'user'
            or not library.ValidateTemplateRecord(templates[id]) then return false end
    end
    return true
end

-- Only explicit sourceDb is accepted; raw peeks avoid AceDB defaulting writes.
-- templates includes copies of existing E1 records plus the newly mapped ones.
-- idState is the prepared E1 namespace, for the later atomic E6 publication.
-- Optional generator uses the E1 :Reserve contract for deterministic tests.
function Migration.Prepare(sourceDb, generator)
    local result = {ready = false, diagnostics = {}, templates = {}, layouts = {}, mappings = {}}
    local library = FocalPoint.TextTemplateLibrary
    local global = type(sourceDb) == 'table' and rawget(sourceDb, 'global') or nil
    if global == nil and type(sourceDb) == 'table' then
        local saved = rawget(sourceDb, 'sv')
        global = type(saved) == 'table' and rawget(saved, 'global') or nil
    end
    local layouts = type(global) == 'table' and rawget(global, 'UserLayouts') or nil
    if not IsTable(layouts) then
        Add(result, 'invalid-layout-payload'); return Finish(result)
    end
    local existing = rawget(global, 'TextTemplates')
    local idState = rawget(global, 'TextTemplateIdState')
    if existing ~= nil and not IsTable(existing) then
        Add(result, 'invalid-template-record'); return Finish(result)
    end
    local ok, snapshot = pcall(Copy, {layouts = layouts, templates = existing, idState = idState})
    if not ok then
        Add(result, 'invalid-layout-payload'); return Finish(result)
    end
    result.layouts, result.templates = Copy(snapshot.layouts), Copy(snapshot.templates or {})
    local reservationDb = {global = {TextTemplates = result.templates, TextTemplateIdState = Copy(snapshot.idState)}}
    local reserved = {}
    for id, record in pairs(result.templates) do
        if library.GetTemplateIdKind(id) ~= 'user' then Add(result, 'prepared-id-invariant-failure') end
        if not library.ValidateTemplateRecord(record) then Add(result, 'invalid-template-record') end
    end
    if #result.diagnostics > 0 then return Finish(result) end

    -- Canonical raw UserLayouts only: no defaults/projection, legacy reimport,
    -- createdFrom inference, merging of identities or builtin matching.
    for _, layoutId in ipairs(Keys(result.layouts)) do
        local layout = result.layouts[layoutId]
        local payload = IsTable(layout) and layout.payload or nil
        if not IsKey(layoutId) or not IsTable(payload) or not IsTable(payload.TextTemplates) or not IsTable(payload.Units) then
            Add(result, 'invalid-layout-payload', layoutId)
        else
            local mapping = {}; result.mappings[layoutId] = mapping
            for _, name in ipairs(Keys(payload.TextTemplates)) do
                local record = {name = name, content = payload.TextTemplates[name]}
                if not library.ValidateTemplateRecord(record) then
                    Add(result, 'invalid-template-record', layoutId, nil, nil, nil, name)
                else
                    local id
                    if generator then id = generator:Reserve(reservationDb, reserved)
                    else id = library.ReserveUserTemplateId(reservationDb, reserved) end
                    if id == nil then
                        Add(result, 'id-reservation-failure', layoutId, nil, nil, nil, name)
                    elseif library.GetTemplateIdKind(id) ~= 'user' or result.templates[id] ~= nil then
                        Add(result, 'prepared-id-invariant-failure', layoutId, nil, nil, nil, name)
                    else
                        mapping[name], result.templates[id] = id, record
                    end
                end
            end
            for _, unitKey in ipairs(Keys(payload.Units)) do
                local unit = payload.Units[unitKey]
                if not IsKey(unitKey) or not IsTable(unit) or (unit.Texts ~= nil and not IsTable(unit.Texts)) then
                    Add(result, 'invalid-layout-payload', layoutId, unitKey)
                else
                    for _, textKey in ipairs(Keys(unit.Texts or {})) do
                        local text = unit.Texts[textKey]
                        if not IsKey(textKey) or not IsTable(text) or text.templateId ~= nil or text.stateTemplateIds ~= nil
                            or (text.templateName ~= nil and type(text.templateName) ~= 'string')
                            or (text.stateTemplates ~= nil and text.stateTemplates ~= false and not IsTable(text.stateTemplates)) then
                            Add(result, 'invalid-layout-payload', layoutId, unitKey, textKey)
                        else
                            local name = text.templateName
                            if name ~= nil and name ~= '' then
                                text.templateId = mapping[name]
                                if not text.templateId then Add(result, 'missing-main-template-reference', layoutId, unitKey, textKey, nil, name) end
                            end
                            text.stateTemplateIds = MaterializeStateIds(result, text, layoutId, unitKey,
                                textKey, mapping)
                            text.templateName, text.stateTemplates = nil, nil
                        end
                    end
                end
            end
            payload.TextTemplates = nil
        end
    end
    if #result.diagnostics > 0 then return Finish(result) end
    result.idState = Copy(reservationDb.global.TextTemplateIdState)

    -- Validate bijection/records and every FK, then reverse only the specified
    -- representation changes on a copy. Exact equality proves key/cardinality,
    -- tag, styling, composition and metadata preservation without normalization.
    local seen = {}
    for layoutId, original in pairs(snapshot.layouts) do
        local target, mapping = result.layouts[layoutId], result.mappings[layoutId]
        local restored = Copy(target)
        restored.payload.TextTemplates = Copy(original.payload.TextTemplates)
        for name, content in pairs(original.payload.TextTemplates) do
            local id = mapping[name]
            if not id or seen[id] or (snapshot.templates and snapshot.templates[id])
                or not library.TemplateRecordsEqual(result.templates[id], {name = name, content = content}) then
                Add(result, 'prepared-id-invariant-failure', layoutId, nil, nil, nil, name)
            else seen[id] = true end
        end
        for unitKey, unit in pairs(original.payload.Units) do
            for textKey, old in pairs(unit.Texts or {}) do
                local text = target.payload.Units[unitKey].Texts[textKey]
                local expected = old.templateName and old.templateName ~= '' and mapping[old.templateName] or nil
                if text.templateName ~= nil or text.stateTemplates ~= nil or text.templateId ~= expected
                    or (text.templateId and not result.templates[text.templateId]) then
                    Add(result, 'prepared-id-invariant-failure', layoutId, unitKey, textKey)
                end
                local expectedStates = MaterializeStateIds(result, old, layoutId, unitKey,
                    textKey, mapping)
                if not Migration.ValidatePreparedStateIds(text.stateTemplateIds, result.templates)
                    or not Equal(text.stateTemplateIds, expectedStates) then
                    Add(result, 'prepared-id-invariant-failure', layoutId, unitKey, textKey)
                end
                local reverse = restored.payload.Units[unitKey].Texts[textKey]
                reverse.templateId, reverse.stateTemplateIds = nil, nil
                reverse.templateName, reverse.stateTemplates = old.templateName, Copy(old.stateTemplates)
            end
        end
        if target.payload.TextTemplates ~= nil or not Equal(restored, original) then Add(result, 'prepared-id-invariant-failure', layoutId) end
    end
    for id, record in pairs(result.templates) do
        local prior = snapshot.templates and snapshot.templates[id]
        if library.GetTemplateIdKind(id) ~= 'user' or not library.ValidateTemplateRecord(record)
            or (prior and not Equal(record, prior)) or (not prior and not seen[id]) then
            Add(result, 'prepared-id-invariant-failure')
        end
    end
    if not Equal(layouts, snapshot.layouts) or not Equal(existing, snapshot.templates) or not Equal(idState, snapshot.idState) then
        Add(result, 'source-mutated')
    end
    return Finish(result)
end

return Migration
