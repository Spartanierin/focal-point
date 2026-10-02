local addonName, ns = ...

-- E5 preparation only. Intentionally absent from Init.xml; no active buttons,
-- store writes, activation, format detection or legacy conversion live here.
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
