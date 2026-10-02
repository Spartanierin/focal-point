local addonName, ns = ...

-- E5 preparation only. Intentionally absent from Init.xml; no active buttons,
-- store writes, activation or automatic format detection live here.
local Next = {SchemaVersion = 2, FormatVersion = 2}
ns.LayoutTransferVNext = Next
local Codec, Library = ns.LayoutTransferCodec, ns.TextTemplateLibrary
local Usage, Validation = ns.TextTemplateUsage, ns.TextTemplateValidation

local function Keys(map)
    local keys = {}; for key in pairs(map) do keys[#keys + 1] = key end
    table.sort(keys); return keys
end
local function OnlyKeys(value, allowed)
    if type(value) ~= "table" or getmetatable(value) then return false end
    for key in pairs(value) do if not allowed[key] then return false end end
    return true
end
local function Snapshot(value)
    local text, reason = Codec.Encode(value)
    if not text then return nil, reason end
    return Codec.Decode(text)
end
local function Layouts(payload) return {['layout:transfer'] = {payload = payload}} end
local function Record(entity) return {name = entity.name, content = entity.content} end
local function Diagnose(result, code, id)
    result.diagnostics[#result.diagnostics + 1] = {errorCode = code, templateId = id}
end

local function ValidateHeader(document)
    if not OnlyKeys(document, {transferSchema=true, formatVersion=true, addonVersion=true,
        name=true, payload=true, templates=true}) then return false, "document-invalid" end
    if document.transferSchema ~= Next.SchemaVersion then return false, "transfer-version" end
    if document.formatVersion ~= Next.FormatVersion then return false, "layout-version" end
    if type(document.addonVersion) ~= "string" or document.addonVersion == "" or #document.addonVersion > 128 then
        return false, "document-invalid"
    end
    if type(document.name) ~= "string" or document.name:find("[%c|]") then return false, "name-invalid" end
    local valid, reason = ns.LayoutMutations.ValidateLayoutName(document.name)
    if not valid and reason ~= "duplicate-name" then return false, reason end
    if type(document.templates) ~= "table" then return false, "templates-invalid" end
    return ns.LayoutTransfer.ValidateEntityPayload(document.payload)
end

local function ValidateGraph(document, result)
    local valid, reason = ValidateHeader(document)
    if not valid then Diagnose(result, reason); return false end
    for id, record in pairs(document.templates) do
        if not Library.GetTemplateIdKind(id) or not Library.ValidateTemplateRecord(record) then
            Diagnose(result, "invalid-resource", id)
        end
    end
    local validation = Validation.ValidateEntityResourceGraph(Layouts(document.payload), document.templates)
    for _, issue in ipairs(validation.issues) do
        result.diagnostics[#result.diagnostics + 1] = {errorCode = issue.code,
            unitKey = issue.unitKey, textKey = issue.textKey, stateKey = issue.stateKey, templateId = issue.templateId}
    end
    local needed = {}
    for _, ref in ipairs(Usage.ScanEntities(Layouts(document.payload))) do needed[ref.templateId] = true end
    for id in pairs(document.templates) do
        if not needed[id] then Diagnose(result, "unused-resource", id) end
    end
    return #result.diagnostics == 0
end

function Next.Export(layout, db)
    if type(layout) ~= "table" or type(db) ~= "table" then return nil, "invalid_context" end
    -- The unchanged codec first bounds and copies the selected payload. Neither
    -- recursive validators nor dependency scanners see cycles or metatables.
    local document, reason = Snapshot({transferSchema = Next.SchemaVersion, formatVersion = Next.FormatVersion,
        addonVersion = C_AddOns and C_AddOns.GetAddOnMetadata(addonName, "Version") or "unknown",
        name = layout.name, payload = layout.payload, templates = {}})
    if not document then return nil, reason end
    local valid
    valid, reason = ValidateHeader(document)
    if not valid then return nil, reason end
    local validation = Validation.ValidateEntityLayouts(Layouts(document.payload), db)
    if not validation.valid then return nil, validation.issues[1].code end
    for _, ref in ipairs(Usage.ScanEntities(Layouts(document.payload))) do
        if document.templates[ref.templateId] == nil then
            local entity, err = Library.ResolveTemplateEntity(ref.templateId, db)
            if not entity then return nil, err.errorCode end
            document.templates[ref.templateId] = Record(entity)
        end
    end
    local result = {diagnostics = {}}
    if not ValidateGraph(document, result) then return nil, result.diagnostics[1].errorCode end
    -- Envelope/serialization version stays Codec.SchemaVersion (1). The decoded
    -- resource document has its own schema 2, which legacy Import rejects.
    return Codec.Encode(document)
end

local function PrivateStore(db)
    if type(db) ~= "table" then return nil, "invalid_context" end
    local global = rawget(db, "global")
    if global == nil then
        local saved = rawget(db, "sv")
        global = type(saved) == "table" and rawget(saved, "global") or nil
    end
    if global ~= nil and type(global) ~= "table" then return nil, "invalid-global" end
    local templates = global and rawget(global, "TextTemplates")
    if templates ~= nil and (type(templates) ~= "table" or getmetatable(templates)) then
        return nil, "invalid-template-store"
    end
    local copies = {}
    for id, record in pairs(templates or {}) do
        if Library.GetTemplateIdKind(id) ~= "user" then return nil, "invalid-user-template-id" end
        local copy, reason = Library.CopyTemplateRecord(record)
        if not copy then return nil, reason end
        copies[id] = copy
    end
    local state = global and rawget(global, "TextTemplateIdState")
    local copy, reason
    if state ~= nil then
        if type(state) ~= "table" or getmetatable(state) then return nil, "invalid-id-state" end
        copy, reason = Snapshot(state)
        if not copy then return nil, reason end
    end
    return {global = {TextTemplates = copies, TextTemplateIdState = copy}}
end

-- forks[id] is the explicitly approved incoming {name,content} snapshot, never
-- an implicit policy flag. Changed input invalidates that approval. All generated
-- IDs/namespace changes live in a private store and are returned only if ready.
function Next.PrepareImport(text, db, options)
    local result = {ready = false, conflicts = {}, diagnostics = {}}
    local document, reason = Codec.Decode(text)
    if not document then Diagnose(result, reason); return result end
    if not ValidateGraph(document, result) then return result end
    local private
    private, reason = PrivateStore(db)
    if not private then Diagnose(result, reason); return result end
    options = options or {}
    if type(options) ~= "table" or (options.forks ~= nil and not OnlyKeys(options.forks, document.templates)) then
        Diagnose(result, "invalid-fork-approval"); return result
    end
    local approvals, approved = options.forks or {}, {}
    local create, remappings, reserved = {}, {}, {}
    -- Reserve the whole incoming ID set as well as all existing local IDs, before
    -- any Built-in fork asks E1 for a fresh ID.
    for id in pairs(document.templates) do reserved[id] = true end
    for _, id in ipairs(Keys(document.templates)) do
        local incoming = document.templates[id]
        local kind = Library.GetTemplateIdKind(id)
        local entity, err = Library.ResolveTemplateEntity(id, private)
        local same = entity and Library.TemplateRecordsEqual(Record(entity), incoming)
        if same then
            -- Existing identical resource; no write prepared.
        elseif kind == "user" and not entity and err.errorCode == "user-template-not-found" then
            create[id] = Library.CopyTemplateRecord(incoming)
        elseif kind == "builtin" and (entity or err.errorCode == "builtin-template-not-found") then
            if approvals[id] ~= nil then
                if not Library.TemplateRecordsEqual(approvals[id], incoming) then
                    Diagnose(result, "invalid-fork-approval", id)
                else
                    approved[id] = true
                    local forkId
                    if options.generator then forkId, reason = options.generator:Reserve(private, reserved)
                    else forkId, reason = Library.ReserveUserTemplateId(private, reserved) end
                    if not forkId then Diagnose(result, reason, id)
                    else
                        remappings[id] = forkId
                        create[forkId] = Library.CopyTemplateRecord(incoming)
                    end
                end
            else
                result.conflicts[#result.conflicts + 1] = {kind = kind, templateId = id,
                    incoming = Library.CopyTemplateRecord(incoming), existing = entity and Record(entity) or nil,
                    reason = entity and "resource-differs" or "unknown-builtin"}
            end
        elseif kind == "user" and entity then
            result.conflicts[#result.conflicts + 1] = {kind = kind, templateId = id,
                incoming = Library.CopyTemplateRecord(incoming), existing = Record(entity), reason = "resource-differs"}
        else Diagnose(result, err and err.errorCode or "invalid-resource", id) end
    end
    for id in pairs(approvals) do
        if not approved[id] then Diagnose(result, "invalid-fork-approval", id) end
    end
    if #result.diagnostics > 0 or #result.conflicts > 0 then return result end
    local layout = {name = document.name, formatVersion = Next.FormatVersion, payload = document.payload}
    Usage.VisitEntityTexts(Layouts(layout.payload), function(_, _, _, config)
        if remappings[config.templateId] then config.templateId = remappings[config.templateId] end
        for state, id in pairs(config.stateTemplateIds or {}) do
            if remappings[id] then config.stateTemplateIds[state] = remappings[id] end
        end
    end)
    for id, record in pairs(create) do private.global.TextTemplates[id] = Library.CopyTemplateRecord(record) end
    local validation = Validation.ValidateEntityLayouts(Layouts(layout.payload), private)
    if not validation.valid then
        for _, issue in ipairs(validation.issues) do Diagnose(result, issue.code, issue.templateId) end
        return result
    end
    result.ready, result.preparedLayout, result.recordsToCreate, result.remappings = true, layout, create, remappings
    result.idState = private.global.TextTemplateIdState
    -- E6 must reprepare/revalidate against current storage before an atomic commit.
    -- No commit function exists in E5; returned snapshots are not a second library.
    return result
end

-- E5b accepts only the explicit legacy layout document contract. Profile/preset
-- transfers are unrelated formats. Codec envelope 1 can carry either document
-- schema; this API never guesses from template fields or changes active routing.
function Next.ConvertLegacyDocument(decoded, db, generator)
    local result = {ready = false, diagnostics = {}}
    if type(decoded) ~= "table" then Diagnose(result, "document-invalid"); return result end
    local legacy, reason = Snapshot(decoded)
    if not legacy then Diagnose(result, reason); return result end
    if not OnlyKeys(legacy, {transferSchema=true, formatVersion=true, addonVersion=true,
        name=true, payload=true}) then Diagnose(result, "document-invalid"); return result end
    if legacy.transferSchema ~= 1 then Diagnose(result, "transfer-version"); return result end
    if legacy.formatVersion ~= 1 then Diagnose(result, "layout-version"); return result end
    if not OnlyKeys(legacy.payload, {Units=true, TextTemplates=true}) then
        Diagnose(result, "payload-invalid"); return result
    end
    -- E5b imports a layout's reachable resources, not every record in its old
    -- container. Filter this codec-owned copy BEFORE E3 reserves any IDs. E3's
    -- separate whole-stock migration contract remains unchanged.
    local referenced = {}
    Usage.VisitEntityTexts(Layouts(legacy.payload), function(_, _, _, text)
        local function Add(name)
            if type(name) == "string" and name ~= "" then referenced[name] = true end
        end
        Add(text.templateName)
        if type(text.stateTemplates) == "table" then
            for _, name in pairs(text.stateTemplates) do Add(name) end
        end
    end)
    if type(legacy.payload.TextTemplates) == "table" then
        local dependencies = {}
        for name in pairs(referenced) do dependencies[name] = legacy.payload.TextTemplates[name] end
        legacy.payload.TextTemplates = dependencies
    end
    -- Missing records remain missing: E3 diagnoses the untouched concrete
    -- references, and still rejects malformed Main/State fields and structures.
    -- No legacy ValidatePayload/CopyPayload: the old validator rejects whole-map
    -- false and normalization is not the source contract. E3 already implements
    -- the proven raw name/string/false interpretation and lossless inverse check.
    local private
    private, reason = PrivateStore(db)
    if not private then Diagnose(result, reason); return result end
    local migration = ns.TextTemplateEntityMigration
    if not (migration and migration.Prepare) then Diagnose(result, "service-unavailable"); return result end
    local layoutId = "layout:legacy-transfer"
    private.global.UserLayouts = {[layoutId] = {name = legacy.name, formatVersion = 1, payload = legacy.payload}}
    local prepared = migration.Prepare(private, generator)
    if not prepared.ready then result.diagnostics = prepared.diagnostics; return result end
    local payload, mapping = prepared.layouts[layoutId].payload, prepared.mappings[layoutId]
    local dependencies = {}
    -- Mapping contains only referenced local names. No target-library records
    -- or unreferenced legacy records become resources in the converted graph.
    for _, id in pairs(mapping) do
        dependencies[id] = Library.CopyTemplateRecord(prepared.templates[id])
    end
    local document = {transferSchema = Next.SchemaVersion, formatVersion = Next.FormatVersion,
        addonVersion = legacy.addonVersion, name = legacy.name, payload = payload, templates = dependencies}
    if not ValidateGraph(document, result) then return result end
    -- Bound the exact converted resource graph through the unchanged codec.
    local snapshot
    snapshot, reason = Snapshot(document)
    if not snapshot then Diagnose(result, reason); return result end
    result.ready, result.document = true, snapshot
    result.mappings, result.idState = mapping, prepared.idState
    return result
end

function Next.PrepareLegacyImport(text, db, generator)
    local decoded, reason = Codec.Decode(text)
    if decoded == nil then
        local result = {ready = false, conflicts = {}, diagnostics = {}}
        Diagnose(result, reason); return result
    end
    local converted = Next.ConvertLegacyDocument(decoded, db, generator)
    if not converted.ready then
        return {ready = false, conflicts = {}, diagnostics = converted.diagnostics}
    end
    local encoded
    encoded, reason = Codec.Encode(converted.document)
    if not encoded then
        local result = {ready = false, conflicts = {}, diagnostics = {}}
        Diagnose(result, reason); return result
    end
    local result = Next.PrepareImport(encoded, db)
    if result.ready then
        -- Metadata for E6; recordsToCreate comes solely from ordinary vNext
        -- dependency preparation. No separate legacy library-import channel.
        result.mappings = converted.mappings
        result.idState = converted.idState
    end
    return result
end
